-- SQL-017 · MIGRAÇÃO do orçamento em core_vendas_faturamento (PROPOSTA, 26/10/2026; schema trocado em 28/10/2026, N16-116) · dono: Gustavo (DBA)
-- Substitui o desenho antigo (schema novo core_orcamento): o banco real JÁ TEM (vindas do core_comercial do Contrato 52, movidas pelo SQL-016 bloco A0), as ofertas (imutáveis, com
-- histórico), categorias de suprimento, fornecedores (perfil, categorias, certificados, apelidos), produtos (perfil e pendentes),
-- parâmetros de custo e tabela da telha com vigência, e as solicitações de custo (Contrato 52). Aqui entra só o que FALTA:
-- ofertas que nascem das OCs, base e estatística de preço (a "bolsa de valores" do vendedor, N16-07, N16-52, N16-55) e o fim do prazo
-- do pedido de custo (N16-58). Rodar DEPOIS do SQL-016 (0001). As tabelas de oferta e de solicitação estão VAZIAS no banco real.
-- Convenções: uuidv7(), CHECK em vez de ENUM, plural.

BEGIN;

-- ───────────────────────── A) ofertas: novas fontes (a OC do Hub e o pedido de compra feito direto no Omie)
ALTER TABLE core_vendas_faturamento.ofertas DROP CONSTRAINT ck_ofertas_fonte;
ALTER TABLE core_vendas_faturamento.ofertas ADD CONSTRAINT ck_ofertas_fonte
  CHECK (fonte IN ('MANUAL','MAPA_COTACAO','MIGRACAO','OC_HUB','OC_OMIE'));

-- ───────────────────────── B) pedido de custo sem prazo fixo (N16-58): o tempo é cronometrado por created_at
ALTER TABLE core_vendas_faturamento.solicitacoes_custo ALTER COLUMN prazo_resposta DROP NOT NULL;
COMMENT ON COLUMN core_vendas_faturamento.solicitacoes_custo.prazo_resposta IS 'N16-58: SEM prazo obrigatório; nulo = sem prazo. O tempo parado é cronometrado desde created_at (ou atribuida_em). O vendedor nunca fica bloqueado.';

-- ───────────────────────── C) base e estatística de preço (derivadas das ofertas)

-- Estado atual por produto × fornecedor × unidade de preço: a oferta vigente, a última, e a janela do histórico.
CREATE TABLE core_vendas_faturamento.produtos_precos_fornecedor (
    id_produto         uuid NOT NULL,
    id_parceiro        uuid NOT NULL,
    unidade_preco      varchar(4) NOT NULL,
    id_oferta_vigente  uuid,
    custo_vigente      numeric(14,4),
    vigente_ate        date,
    id_ultima_oferta   uuid NOT NULL,
    ultimo_custo       numeric(14,4) NOT NULL,
    ultimo_em          date NOT NULL,
    registros_janela   integer NOT NULL,
    media_janela       numeric(14,4),
    tipo_media         varchar(10),
    minimo_janela      numeric(14,4),
    maximo_janela      numeric(14,4),
    janela_dias        integer NOT NULL,
    atualizado_em      timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_produtos_precos_fornecedor PRIMARY KEY (id_produto, id_parceiro, unidade_preco),
    CONSTRAINT ck_produtos_precos_fornecedor_media CHECK (tipo_media IS NULL OR tipo_media IN ('PONDERADA','SIMPLES')),
    CONSTRAINT fk_produtos_precos_fornecedor_produto FOREIGN KEY (id_produto) REFERENCES core.produtos(id) ON DELETE CASCADE,
    CONSTRAINT fk_produtos_precos_fornecedor_parceiro FOREIGN KEY (id_parceiro) REFERENCES core.parceiros(id) ON DELETE CASCADE,
    CONSTRAINT fk_produtos_precos_fornecedor_ultima FOREIGN KEY (id_ultima_oferta) REFERENCES core_vendas_faturamento.ofertas(id)
);
CREATE INDEX ix_produtos_precos_fornecedor_parceiro ON core_vendas_faturamento.produtos_precos_fornecedor (id_parceiro);

-- Consulta do vendedor: um quadro por produto × unidade, todos os fornecedores juntos. Volatilidade pelo coeficiente de variação (OQ-46).
CREATE TABLE core_vendas_faturamento.produtos_estatisticas_preco (
    id_produto             uuid NOT NULL,
    unidade_preco          varchar(4) NOT NULL,
    janela_dias            integer NOT NULL,
    registros              integer NOT NULL,
    fornecedores           integer NOT NULL,
    media                  numeric(14,4),
    tipo_media             varchar(10),
    minimo                 numeric(14,4),
    maximo                 numeric(14,4),
    desvio_padrao          numeric(14,4),
    coeficiente_variacao   numeric(9,4),
    ultimo                 numeric(14,4) NOT NULL,
    ultimo_em              date NOT NULL,
    atualizado_em          timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_produtos_estatisticas_preco PRIMARY KEY (id_produto, unidade_preco),
    CONSTRAINT ck_produtos_estatisticas_preco_media CHECK (tipo_media IS NULL OR tipo_media IN ('PONDERADA','SIMPLES')),
    CONSTRAINT fk_produtos_estatisticas_preco_produto FOREIGN KEY (id_produto) REFERENCES core.produtos(id) ON DELETE CASCADE
);
COMMENT ON COLUMN core_vendas_faturamento.produtos_estatisticas_preco.coeficiente_variacao IS 'Desvio padrão / média, em %. É a volatilidade da página do produto; os limites (alta, média, baixa) e o "dado recente" de 7 dias são PARÂMETRO com vigência (Proposta-Score-e-Volatilidade-OQ-46), não ficam no banco.';

-- Janela do histórico: dias_historico da vigência atual de parametros_custo (padrão 90).
CREATE FUNCTION core_vendas_faturamento.fn_janela_historico_dias() RETURNS integer LANGUAGE sql STABLE AS $$
  SELECT coalesce((SELECT dias_historico FROM core_vendas_faturamento.parametros_custo
                    WHERE vigencia_inicio <= current_date AND (vigencia_fim IS NULL OR vigencia_fim >= current_date)
                    ORDER BY vigencia_inicio DESC LIMIT 1), 90)
$$;

-- Recalcula a base e a estatística de um produto (trigger da oferta e job diário). Oferta INVALIDADA e "verificar escala" não entram.
CREATE FUNCTION core_vendas_faturamento.fn_produtos_recalcular_precos(p_produto uuid) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_janela integer := core_vendas_faturamento.fn_janela_historico_dias();
BEGIN
  DELETE FROM core_vendas_faturamento.produtos_precos_fornecedor WHERE id_produto = p_produto;
  DELETE FROM core_vendas_faturamento.produtos_estatisticas_preco WHERE id_produto = p_produto;

  INSERT INTO core_vendas_faturamento.produtos_precos_fornecedor
    (id_produto, id_parceiro, unidade_preco, id_oferta_vigente, custo_vigente, vigente_ate, id_ultima_oferta, ultimo_custo, ultimo_em,
     registros_janela, media_janela, tipo_media, minimo_janela, maximo_janela, janela_dias)
  WITH valida AS (
    SELECT * FROM core_vendas_faturamento.ofertas
     WHERE id_produto = p_produto AND status <> 'INVALIDADA' AND NOT verificar_escala AND custo_liquido_unit > 0
  ), ultima AS (
    SELECT DISTINCT ON (id_parceiro, unidade_preco) id_parceiro, unidade_preco, id AS id_ultima, custo_liquido_unit AS ultimo_custo, data_cotacao AS ultimo_em
      FROM valida ORDER BY id_parceiro, unidade_preco, data_cotacao DESC, created_at DESC
  ), vigente AS (
    SELECT DISTINCT ON (id_parceiro, unidade_preco) id_parceiro, unidade_preco, id AS id_vig, custo_liquido_unit AS custo_vig, valida_ate
      FROM valida WHERE status = 'VIGENTE' AND valida_ate >= current_date
     ORDER BY id_parceiro, unidade_preco, custo_liquido_unit, id
  ), janela AS (
    SELECT id_parceiro, unidade_preco, count(*) AS n, min(custo_liquido_unit) AS mn, max(custo_liquido_unit) AS mx,
           CASE WHEN bool_and(coalesce(quantidade,0) > 0) THEN sum(custo_liquido_unit * quantidade) / sum(quantidade) ELSE avg(custo_liquido_unit) END AS media,
           CASE WHEN bool_and(coalesce(quantidade,0) > 0) THEN 'PONDERADA' ELSE 'SIMPLES' END AS tipo
      FROM valida WHERE data_cotacao >= current_date - v_janela GROUP BY id_parceiro, unidade_preco
  )
  SELECT p_produto, u.id_parceiro, u.unidade_preco, v.id_vig, v.custo_vig, v.valida_ate, u.id_ultima, u.ultimo_custo, u.ultimo_em,
         coalesce(j.n, 0), round(j.media, 4), j.tipo, j.mn, j.mx, v_janela
    FROM ultima u LEFT JOIN vigente v USING (id_parceiro, unidade_preco) LEFT JOIN janela j USING (id_parceiro, unidade_preco);

  INSERT INTO core_vendas_faturamento.produtos_estatisticas_preco
    (id_produto, unidade_preco, janela_dias, registros, fornecedores, media, tipo_media, minimo, maximo, desvio_padrao, coeficiente_variacao, ultimo, ultimo_em)
  WITH valida AS (
    SELECT * FROM core_vendas_faturamento.ofertas
     WHERE id_produto = p_produto AND status <> 'INVALIDADA' AND NOT verificar_escala AND custo_liquido_unit > 0
  ), ultimo AS (
    SELECT DISTINCT ON (unidade_preco) unidade_preco, custo_liquido_unit AS ultimo, data_cotacao AS ultimo_em
      FROM valida ORDER BY unidade_preco, data_cotacao DESC, created_at DESC
  ), janela AS (
    SELECT unidade_preco, count(*) AS n, count(DISTINCT id_parceiro) AS f, min(custo_liquido_unit) AS mn, max(custo_liquido_unit) AS mx,
           stddev_samp(custo_liquido_unit) AS dp,
           CASE WHEN bool_and(coalesce(quantidade,0) > 0) THEN sum(custo_liquido_unit * quantidade) / sum(quantidade) ELSE avg(custo_liquido_unit) END AS media,
           CASE WHEN bool_and(coalesce(quantidade,0) > 0) THEN 'PONDERADA' ELSE 'SIMPLES' END AS tipo
      FROM valida WHERE data_cotacao >= current_date - v_janela GROUP BY unidade_preco
  )
  SELECT p_produto, u.unidade_preco, v_janela, coalesce(j.n, 0), coalesce(j.f, 0), round(j.media, 4), j.tipo, j.mn, j.mx,
         round(j.dp, 4), CASE WHEN j.n >= 3 AND j.media > 0 THEN round(j.dp / j.media * 100, 4) END, u.ultimo, u.ultimo_em
    FROM ultimo u LEFT JOIN janela j USING (unidade_preco);
END $$;

CREATE FUNCTION core_vendas_faturamento.fn_ofertas_recalcular_trg() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.id_produto IS NOT NULL THEN PERFORM core_vendas_faturamento.fn_produtos_recalcular_precos(NEW.id_produto); END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_ofertas_recalcular AFTER INSERT OR UPDATE OF status, id_produto ON core_vendas_faturamento.ofertas
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_ofertas_recalcular_trg();

-- Status efetivo: VIGENTE vence sozinha depois de valida_ate.
CREATE VIEW core_vendas_faturamento.vw_ofertas AS
SELECT o.*, CASE WHEN o.status = 'VIGENTE' AND o.valida_ate < current_date THEN 'VENCIDA' ELSE o.status END AS status_efetivo
  FROM core_vendas_faturamento.ofertas o;

-- Série para o gráfico "bolsa de valores" do vendedor: um ponto por preço visto, sem as invalidadas.
CREATE VIEW core_vendas_faturamento.vw_produtos_serie_preco AS
SELECT o.id_produto, o.data_cotacao, o.unidade_preco, o.custo_liquido_unit, o.id_parceiro, o.fonte, o.quantidade
  FROM core_vendas_faturamento.ofertas o
 WHERE o.id_produto IS NOT NULL AND o.status <> 'INVALIDADA' AND NOT o.verificar_escala AND o.custo_liquido_unit > 0;

-- Matriz de preços v1: produto × fornecedor, derivada da base (as dimensões extras entram com a OQ-10).
CREATE VIEW core_vendas_faturamento.vw_matriz_precos AS
SELECT b.id_produto, b.id_parceiro, pa.nome_fantasia AS fornecedor, b.unidade_preco, b.custo_vigente, b.vigente_ate,
       b.ultimo_custo, b.ultimo_em, b.registros_janela, b.media_janela, b.minimo_janela, b.maximo_janela
  FROM core_vendas_faturamento.produtos_precos_fornecedor b
  JOIN core.parceiros pa ON pa.id = b.id_parceiro;

-- ───────────────────────── D) ofertas que vêm das OCs (o setor não digita)
-- OC do Hub aprovada vira oferta OC_HUB; pedido de compra do Omie que NÃO nasceu no Hub vira OC_OMIE; OC cancelada invalida a oferta.
-- O preço é líquido de desconto e sem imposto (a OC ainda não traz ICMS, IPI e ST por item: PS-014, N14-23) e a oferta nasce HISTORICA
-- (preço visto, não cotação a vencer). Idempotente. Chamada pelo job a cada 15 minutos.
CREATE FUNCTION core_vendas_faturamento.fn_ofertas_gerar_de_ocs() RETURNS integer LANGUAGE plpgsql AS $$
DECLARE v_n integer := 0; v_lin integer; v_validade integer;
BEGIN
  SELECT validade_padrao_dias INTO v_validade FROM core_vendas_faturamento.parametros_custo
   WHERE vigencia_inicio <= current_date AND (vigencia_fim IS NULL OR vigencia_fim >= current_date)
   ORDER BY vigencia_inicio DESC LIMIT 1;
  v_validade := coalesce(v_validade, 30);

  INSERT INTO core_vendas_faturamento.ofertas
    (id_produto, id_parceiro, fonte, id_documento_fonte, preco, unidade_preco, quantidade, condicoes_desconhecidas, tipo_frete,
     data_cotacao, valida_ate, status, custo_liquido_unit)
  SELECT p.id, pa.id, 'OC_HUB', i.id::text, i.valor_unitario,
         CASE upper(i.unidade_medida) WHEN 'PÇ' THEN 'PC' WHEN 'MT' THEN 'M' WHEN 'UND' THEN 'UN' ELSE upper(i.unidade_medida) END,
         i.quantidade, true, coalesce(oc.tipo_frete, 'CIF'),
         coalesce(oc.aprovado_em, oc.created_at)::date, coalesce(oc.aprovado_em, oc.created_at)::date + v_validade, 'HISTORICA',
         round(i.valor_unitario * (1 - coalesce(i.desconto, 0) / 100) * coalesce(oc.cotacao_moeda, 1), 4)
    FROM core_vendas_faturamento.ordens_compra_itens i
    JOIN core_vendas_faturamento.ordens_compra oc ON oc.id = i.id_ordem_compra
    JOIN core.parceiros pa ON pa.codigo_empresa = oc.codigo_empresa AND pa.codigo_parceiro_omie = oc.codigo_fornecedor AND pa.deleted_at IS NULL
    JOIN core.produtos p ON p.codigo_empresa = oc.codigo_empresa AND p.deleted_at IS NULL
                        AND (p.codigo_produto_omie = i.codigo_produto OR p.codigo_produto = i.codigo_produto)
   WHERE oc.status = 'aprovado' AND oc.deleted_at IS NULL AND i.valor_unitario > 0
     AND CASE upper(i.unidade_medida) WHEN 'PÇ' THEN 'PC' WHEN 'MT' THEN 'M' WHEN 'UND' THEN 'UN' ELSE upper(i.unidade_medida) END
         IN ('PC','KG','M','TN','CJ','M2','UN')
  ON CONFLICT (fonte, id_documento_fonte, (COALESCE(id_produto, id_produto_pendente)), id_parceiro) DO NOTHING;
  GET DIAGNOSTICS v_lin = ROW_COUNT; v_n := v_n + v_lin;

  INSERT INTO core_vendas_faturamento.ofertas
    (id_produto, id_parceiro, fonte, id_documento_fonte, preco, unidade_preco, quantidade, condicoes_desconhecidas,
     data_cotacao, valida_ate, status, custo_liquido_unit)
  SELECT p.id, pa.id, 'OC_OMIE', ci.id::text, ci.valor_unitario,
         CASE upper(ci.unidade) WHEN 'PÇ' THEN 'PC' WHEN 'MT' THEN 'M' WHEN 'UND' THEN 'UN' ELSE upper(ci.unidade) END,
         ci.quantidade, true, coalesce(pc.incluido_em_omie, pc.created_at)::date,
         coalesce(pc.incluido_em_omie, pc.created_at)::date + v_validade, 'HISTORICA',
         round(ci.valor_unitario * (1 - coalesce(ci.percentual_desconto, 0) / 100), 4)
    FROM core_vendas_faturamento.pedidos_compras_itens ci
    JOIN core_vendas_faturamento.pedidos_compras pc ON pc.id = ci.id_pedido_compra
    JOIN core.parceiros pa ON pa.codigo_empresa = pc.codigo_empresa AND pa.codigo_parceiro_omie = pc.codigo_fornecedor::text AND pa.deleted_at IS NULL
    JOIN core.produtos p ON p.codigo_empresa = pc.codigo_empresa AND p.codigo_produto_omie = ci.codigo_produto_omie AND p.deleted_at IS NULL
   WHERE pc.deleted_at IS NULL AND ci.valor_unitario > 0
     AND CASE upper(ci.unidade) WHEN 'PÇ' THEN 'PC' WHEN 'MT' THEN 'M' WHEN 'UND' THEN 'UN' ELSE upper(ci.unidade) END
         IN ('PC','KG','M','TN','CJ','M2','UN')
     AND NOT EXISTS (SELECT 1 FROM core_vendas_faturamento.ordens_compra oh
                      WHERE oh.codigo_empresa = pc.codigo_empresa AND oh.codigo_pedido_omie = pc.codigo_pedido_compra_omie)
  ON CONFLICT (fonte, id_documento_fonte, (COALESCE(id_produto, id_produto_pendente)), id_parceiro) DO NOTHING;
  GET DIAGNOSTICS v_lin = ROW_COUNT; v_n := v_n + v_lin;

  UPDATE core_vendas_faturamento.ofertas o
     SET status = 'INVALIDADA', motivo_invalidacao = 'OC cancelada', invalidada_em = now()
    FROM core_vendas_faturamento.ordens_compra_itens i
    JOIN core_vendas_faturamento.ordens_compra oc ON oc.id = i.id_ordem_compra
   WHERE o.fonte = 'OC_HUB' AND o.id_documento_fonte = i.id::text AND o.status <> 'INVALIDADA'
     AND (oc.status = 'cancelado' OR oc.deleted_at IS NOT NULL);
  GET DIAGNOSTICS v_lin = ROW_COUNT; v_n := v_n + v_lin;
  RETURN v_n;
END $$;

COMMIT;
