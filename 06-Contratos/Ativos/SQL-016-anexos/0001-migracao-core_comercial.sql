-- SQL-016 · MIGRAÇÃO do schema core_comercial REAL (PROPOSTA, 26/10/2026) · dono: Gustavo (DBA)
-- Substitui o desenho antigo (CREATE de proposta, empresa_emissora…): o banco já tem core_comercial (Contrato 52).
-- Base: "Dump do Avhub para referência" de 26/10/2026. As tabelas de proposta estão VAZIAS (0 linhas em propostas, propostas_itens,
-- clientes, ofertas, solicitacoes_custo…): não há dado a converter. Rodar DEPOIS de reproduzir o banco com o dump.
-- Convenções do hub: uuidv7(), CHECK no lugar de ENUM, created_*/updated_*/deleted_*, nomes de tabela no plural.
-- Decisões que esta migração implementa: N16-02, 03, 04, 05, 09, 17, 26, 28, 29, 31, 60 a 71, 79 a 100, 102, 104, 106.

BEGIN;

-- ───────────────────────── A) PROPOSTAS: do modelo antigo (ABERTA, PARCIAL, FECHADA, PERDIDA) ao novo

ALTER TABLE core_comercial.propostas
  DROP CONSTRAINT ck_propostas_fechada,
  DROP CONSTRAINT ck_propostas_fechado_ate_total,
  DROP CONSTRAINT ck_propostas_parcial,
  DROP CONSTRAINT ck_propostas_perdida,
  DROP CONSTRAINT ck_propostas_motivo_perda,
  DROP CONSTRAINT ck_propostas_status,
  DROP CONSTRAINT ck_propostas_valores;

-- Não existe mais fechamento parcial (N16-02): uma proposta equivale a um pedido.
ALTER TABLE core_comercial.propostas
  DROP COLUMN valor_fechado,
  DROP COLUMN valor_aberto,
  DROP COLUMN fechada_em,
  DROP COLUMN numero_pedido_omie;   -- o pedido passa a viver em core_comercial.pedidos

-- 'TRANSFORMADA' tem 12 caracteres e a coluna era varchar(10) (achado do teste de 26/10).
ALTER TABLE core_comercial.propostas ALTER COLUMN status TYPE varchar(12);
ALTER TABLE core_comercial.propostas RENAME COLUMN perdida_em TO cancelada_em;
ALTER TABLE core_comercial.propostas RENAME COLUMN motivo_perda TO motivo_cancelamento;
ALTER TABLE core_comercial.propostas RENAME COLUMN motivo_perda_texto TO motivo_cancelamento_texto;

ALTER TABLE core_comercial.propostas
  ADD COLUMN aprovada_em          timestamptz,
  ADD COLUMN aprovada_por         uuid,
  ADD COLUMN aprovada_revisao     integer,
  ADD COLUMN aprovacao_referencia text,
  ADD COLUMN cancelada_por        uuid,
  ADD COLUMN transformada_em      timestamptz,
  ADD COLUMN transformada_por     uuid,
  ADD COLUMN codigo_parcela_omie  varchar(3),
  ADD COLUMN numero_numerico      bigint GENERATED ALWAYS AS ((ano::bigint * 1000000) + sequencial) STORED,
  ADD CONSTRAINT fk_propostas_aprovada_por FOREIGN KEY (aprovada_por) REFERENCES auth.usuarios(id) ON DELETE SET NULL,
  ADD CONSTRAINT fk_propostas_cancelada_por FOREIGN KEY (cancelada_por) REFERENCES auth.usuarios(id) ON DELETE SET NULL,
  ADD CONSTRAINT fk_propostas_transformada_por FOREIGN KEY (transformada_por) REFERENCES auth.usuarios(id) ON DELETE SET NULL,
  ADD CONSTRAINT ck_propostas_status CHECK (status IN ('ABERTA','APROVADA','TRANSFORMADA','CANCELADA')),
  ADD CONSTRAINT ck_propostas_aprovada CHECK (status = 'CANCELADA' OR (status = 'ABERTA') = (aprovada_em IS NULL)),
  ADD CONSTRAINT ck_propostas_cancelada CHECK ((status = 'CANCELADA') = (cancelada_em IS NOT NULL)),
  ADD CONSTRAINT ck_propostas_cancelada_motivo CHECK (status <> 'CANCELADA'
        OR (motivo_cancelamento IS NOT NULL AND length(btrim(coalesce(motivo_cancelamento_texto, ''))) >= 3)),
  ADD CONSTRAINT ck_propostas_transformada CHECK ((status = 'TRANSFORMADA') = (transformada_em IS NOT NULL)),
  ADD CONSTRAINT ck_propostas_motivo_cancelamento CHECK (motivo_cancelamento IS NULL OR motivo_cancelamento IN
        ('PRECO_ALTO','PRAZO','COMPROU_CONCORRENTE','PROJETO_CANCELADO','SEM_RETORNO','CONDICAO_PAGAMENTO','FRETE','OUTRO')),
  ADD CONSTRAINT ck_propostas_valores CHECK (valor_frete >= 0 AND subtotal >= 0 AND total_desconto >= 0 AND total_icms >= 0
        AND total_ipi >= 0 AND total_st >= 0 AND total_geral >= 0);
COMMENT ON COLUMN core_comercial.propostas.numero_numerico IS '🟡 N16-04: número só de dígitos (ano × 1.000.000 + sequencial), único por emissora e ano; a tela e o PDF podem mostrar o prefixo de numero_completo. A decidir com o Nathan se vale este formato.';
COMMENT ON COLUMN core_comercial.propostas.codigo_parcela_omie IS 'Código da condição de pagamento NA CONTA OMIE da unidade (SQL-019, core_vendas_faturamento.condicoes_pagamento_vendas). condicao_pagamento guarda a descrição escolhida da lista.';
COMMENT ON COLUMN core_comercial.propostas.aprovada_revisao IS 'Revisão que o vendedor marcou como aprovada (a aprovação da Gerência é física, N16-12).';

-- Itens: sai o fechamento por item; entram CFOP e cenário de impostos (N16-83) e a natureza do custo.
ALTER TABLE core_comercial.propostas_itens
  DROP CONSTRAINT ck_propostas_itens_fechado,
  DROP COLUMN fechado,
  DROP COLUMN fechado_em,
  DROP COLUMN id_fechado_por;
ALTER TABLE core_comercial.propostas_itens
  ADD COLUMN natureza_custo      varchar(10) DEFAULT 'MATERIAL' NOT NULL,
  ADD COLUMN cfop                varchar(10),
  ADD COLUMN codigo_cenario_omie bigint,
  ADD CONSTRAINT ck_propostas_itens_natureza CHECK (natureza_custo IN ('MATERIAL','FABRICACAO','SERVICO'));
COMMENT ON COLUMN core_comercial.propostas_itens.codigo_cenario_omie IS 'Cenário de impostos da conta Omie escolhido ao cadastrar o produto na proposta (catálogo core_vendas_faturamento.cenarios_impostos, N16-83). O CFOP já está no banco do Hub.';

-- Eventos da proposta: sai PERDIDA/REABERTA/FECHAMENTO_*; entram aprovação, cancelamento e o pedido.
-- 'TRANSFORMADA_EM_PEDIDO' tem 22 caracteres e a coluna era varchar(20) (achado do teste de 26/10).
ALTER TABLE core_comercial.propostas_eventos ALTER COLUMN tipo TYPE varchar(30);
ALTER TABLE core_comercial.propostas_eventos DROP CONSTRAINT ck_propostas_eventos_tipo;
ALTER TABLE core_comercial.propostas_eventos ADD CONSTRAINT ck_propostas_eventos_tipo CHECK (tipo IN (
  'CRIADA','REVISADA','DUPLICADA','COPIADA','PDF_GERADO','EXCLUIDA','CUSTO_ALTERADO','MIGRADA','EMAIL_ENVIADO','REATRIBUIDA',
  'CUSTO_SOLICITADO','CUSTO_RESPONDIDO','APROVADA','CANCELADA','TRANSFORMADA_EM_PEDIDO','PEDIDO_ENVIADO_OMIE',
  'PEDIDO_RECUSADO_OMIE','PEDIDO_NUMERO_OMIE'));

-- Completude (N16-31): o item precisa de custo e de fornecedor para a proposta poder ser aprovada. 🟡 (OQ-11)
CREATE FUNCTION core_comercial.fn_item_completo(i core_comercial.propostas_itens) RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(i.custo, 0) > 0 AND i.origem_custo <> 'SEM_CUSTO'
         AND (i.id_oferta IS NOT NULL OR length(btrim(coalesce(i.fornecedor, ''))) > 0)
$$;

CREATE VIEW core_comercial.vw_propostas_completude AS
SELECT p.id AS id_proposta, count(i.id)::int AS itens,
       count(i.id) FILTER (WHERE core_comercial.fn_item_completo(i))::int AS itens_completos,
       count(i.id) > 0 AND bool_and(core_comercial.fn_item_completo(i)) AS completa
  FROM core_comercial.propostas p
  LEFT JOIN core_comercial.propostas_itens i ON i.id_proposta = p.id
 GROUP BY p.id;

-- Aprovada (ou em qualquer estado depois de ABERTA) não se ajusta (N16-03); aprovar exige a proposta completa.
CREATE FUNCTION core_comercial.fn_propostas_travar() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.status <> 'ABERTA' AND (
       (NEW.id_cliente, NEW.cliente_snapshot, NEW.finalidade, NEW.tipo_venda, NEW.moeda, NEW.cotacao_moeda, NEW.incoterm,
        NEW.valor_frete, NEW.condicao_pagamento, NEW.codigo_parcela_omie, NEW.validade, NEW.observacoes, NEW.subtotal, NEW.total_desconto,
        NEW.total_icms, NEW.total_ipi, NEW.total_st, NEW.total_geral, NEW.revisao, NEW.id_unidade_emissora, NEW.ano, NEW.sequencial)
       IS DISTINCT FROM
       (OLD.id_cliente, OLD.cliente_snapshot, OLD.finalidade, OLD.tipo_venda, OLD.moeda, OLD.cotacao_moeda, OLD.incoterm,
        OLD.valor_frete, OLD.condicao_pagamento, OLD.codigo_parcela_omie, OLD.validade, OLD.observacoes, OLD.subtotal, OLD.total_desconto,
        OLD.total_icms, OLD.total_ipi, OLD.total_st, OLD.total_geral, OLD.revisao, OLD.id_unidade_emissora, OLD.ano, OLD.sequencial)) THEN
    RAISE EXCEPTION 'PROPOSTA_TRAVADA: a proposta % já passou da aprovação e não se ajusta.', OLD.numero_completo USING ERRCODE = '23514';
  END IF;
  IF OLD.status <> NEW.status AND NOT (
       (OLD.status = 'ABERTA' AND NEW.status IN ('APROVADA','CANCELADA')) OR
       (OLD.status = 'APROVADA' AND NEW.status IN ('TRANSFORMADA','CANCELADA'))) THEN
    RAISE EXCEPTION 'TRANSICAO_INVALIDA: de % para % não existe.', OLD.status, NEW.status USING ERRCODE = '23514';
  END IF;
  IF NEW.status = 'APROVADA' AND OLD.status = 'ABERTA' THEN
    IF NOT coalesce((SELECT completa FROM core_comercial.vw_propostas_completude WHERE id_proposta = NEW.id), false) THEN
      RAISE EXCEPTION 'PROPOSTA_INCOMPLETA: preencha custo e fornecedor de todos os itens antes de aprovar.' USING ERRCODE = '23514';
    END IF;
    IF NEW.aprovada_revisao IS DISTINCT FROM NEW.revisao THEN
      RAISE EXCEPTION 'REVISAO_DESATUALIZADA: a revisão aprovada (%) não é a atual (%).', NEW.aprovada_revisao, NEW.revisao USING ERRCODE = '23514';
    END IF;
    NEW.aprovada_em := now();
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_propostas_travar BEFORE UPDATE ON core_comercial.propostas
  FOR EACH ROW EXECUTE FUNCTION core_comercial.fn_propostas_travar();

CREATE FUNCTION core_comercial.fn_propostas_itens_travar() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_status varchar;
BEGIN
  SELECT status INTO v_status FROM core_comercial.propostas WHERE id = coalesce(NEW.id_proposta, OLD.id_proposta);
  IF v_status IS NOT NULL AND v_status <> 'ABERTA' THEN
    RAISE EXCEPTION 'PROPOSTA_TRAVADA: os itens só mudam enquanto a proposta está aberta.' USING ERRCODE = '23514';
  END IF;
  RETURN coalesce(NEW, OLD);
END $$;
CREATE TRIGGER trg_propostas_itens_travar BEFORE INSERT OR UPDATE OR DELETE ON core_comercial.propostas_itens
  FOR EACH ROW EXECUTE FUNCTION core_comercial.fn_propostas_itens_travar();

-- ───────────────────────── B) UNIDADES: as três contas Omie (N16-79) e a unidade como emissora (N16-80)
-- A HRM aponta hoje para a conta de Mogi; cada unidade tem a sua conta. Correção de DADO (3 linhas em unidades_emissoras).
UPDATE core_comercial.unidades_emissoras SET id_unidade_conta_omie = id_unidade, updated_at = now()
 WHERE codigo = 'HRM' AND id_unidade_conta_omie <> id_unidade;

-- ───────────────────────── C) PEDIDO DE VENDA DO HUB e fila do Omie (mesmo padrão da OC)

-- O pedido de venda no Hub, com DUAS origens (N16-106): o que nasce de proposta (PROPOSTA) e o digitado direto no Omie (OMIE), que o
-- job traz para cá quando a pipeline o lê. Os dois seguem o MESMO fluxo e a mesma tela; o do Omie chega com a parte de vendas pronta
-- (só se altera no Omie) e o vendedor preenche aqui a parte de compras, que é a simulação da comissão (N16-104).
CREATE TABLE core_comercial.pedidos (
    id                                uuid DEFAULT uuidv7() NOT NULL,
    origem                            varchar(8) DEFAULT 'PROPOSTA' NOT NULL,
    numero                            bigint,
    codigo_empresa                    uuid NOT NULL,
    id_proposta                       uuid,
    id_unidade_emissora               uuid NOT NULL,
    id_cliente                        uuid,
    codigo_cliente_omie               varchar(60),
    codigo_vendedor_omie              varchar(11),
    id_usuario_vendedor               uuid,
    finalidade                        varchar(20),
    moeda                             varchar(3) DEFAULT 'BRL' NOT NULL,
    cotacao_moeda                     numeric(14,6),
    incoterm                          varchar(3),
    valor_frete                       numeric(14,2) DEFAULT 0 NOT NULL,
    condicao_pagamento                text,
    codigo_parcela_omie               varchar(3),
    numero_requisicao_cliente         varchar(120),
    observacoes                       text,
    valor_total                       numeric(14,2) DEFAULT 0 NOT NULL,
    -- as três respostas (N16-88, N16-89): obrigatórias ao transformar a proposta; no pedido do Omie o vendedor responde aqui, sem travar o fluxo
    acompanhamento_qualidade          boolean,
    faturamento_parcial               boolean,
    data_previsao_faturamento_inicial date,
    data_previsao_faturamento         date,
    liberado_em                       timestamptz DEFAULT now() NOT NULL,
    liberado_por                      uuid,
    -- fila do Omie (padrão da OC); o pedido do Omie já nasce sincronizado
    status_sincronizacao_omie         varchar(12) DEFAULT 'pendente' NOT NULL,
    erro_sincronizacao_omie           text,
    tentativas_envio                  integer DEFAULT 0 NOT NULL,
    codigo_pedido_integracao          varchar(20),
    codigo_pedido_omie                bigint,
    numero_pedido_omie                varchar(15),
    enviado_em                        timestamptz,
    sincronizado_em                   timestamptz,
    -- cancelamento (N16-84, N16-91): cancelar marca; excluir apaga. O do Omie só se cancela no Omie (N16-106)
    cancelado_em                      timestamptz,
    cancelado_por                     uuid,
    motivo_cancelamento               text,
    created_at                        timestamptz DEFAULT now() NOT NULL,
    created_by                        uuid,
    updated_at                        timestamptz DEFAULT now() NOT NULL,
    updated_by                        uuid,
    CONSTRAINT pk_pedidos PRIMARY KEY (id),
    CONSTRAINT uq_pedidos_proposta UNIQUE (id_proposta),
    CONSTRAINT uq_pedidos_numero UNIQUE (codigo_empresa, numero),
    CONSTRAINT ck_pedidos_origem CHECK (origem IN ('PROPOSTA','OMIE')),
    CONSTRAINT ck_pedidos_origem_proposta CHECK ((origem = 'PROPOSTA') = (id_proposta IS NOT NULL)),
    CONSTRAINT ck_pedidos_da_proposta CHECK (origem <> 'PROPOSTA' OR (numero IS NOT NULL AND id_cliente IS NOT NULL AND finalidade IS NOT NULL
        AND acompanhamento_qualidade IS NOT NULL AND faturamento_parcial IS NOT NULL AND data_previsao_faturamento_inicial IS NOT NULL
        AND data_previsao_faturamento IS NOT NULL AND codigo_pedido_integracao IS NOT NULL)),
    CONSTRAINT ck_pedidos_do_omie CHECK (origem <> 'OMIE' OR (numero_pedido_omie IS NOT NULL AND codigo_pedido_omie IS NOT NULL
        AND status_sincronizacao_omie = 'sincronizado')),
    CONSTRAINT ck_pedidos_sinc CHECK (status_sincronizacao_omie IN ('pendente','sincronizado','erro')),
    CONSTRAINT ck_pedidos_erro CHECK (status_sincronizacao_omie <> 'erro' OR erro_sincronizacao_omie IS NOT NULL),
    CONSTRAINT ck_pedidos_omie CHECK (status_sincronizacao_omie <> 'sincronizado' OR (codigo_pedido_omie IS NOT NULL AND numero_pedido_omie IS NOT NULL)),
    CONSTRAINT ck_pedidos_integracao CHECK (codigo_pedido_integracao IS NULL OR codigo_pedido_integracao = numero::text),
    CONSTRAINT ck_pedidos_cancelamento CHECK ((cancelado_em IS NULL) = (motivo_cancelamento IS NULL)
        AND (cancelado_em IS NULL OR length(btrim(motivo_cancelamento)) >= 3)),
    CONSTRAINT fk_pedidos_unidade FOREIGN KEY (codigo_empresa) REFERENCES core.unidades(id),
    CONSTRAINT fk_pedidos_proposta FOREIGN KEY (id_proposta) REFERENCES core_comercial.propostas(id),
    CONSTRAINT fk_pedidos_emissora FOREIGN KEY (id_unidade_emissora) REFERENCES core_comercial.unidades_emissoras(id),
    CONSTRAINT fk_pedidos_cliente FOREIGN KEY (id_cliente) REFERENCES core_comercial.clientes(id),
    CONSTRAINT fk_pedidos_vendedor FOREIGN KEY (id_usuario_vendedor) REFERENCES auth.usuarios(id) ON DELETE SET NULL,
    CONSTRAINT fk_pedidos_liberado_por FOREIGN KEY (liberado_por) REFERENCES auth.usuarios(id) ON DELETE SET NULL,
    CONSTRAINT fk_pedidos_cancelado_por FOREIGN KEY (cancelado_por) REFERENCES auth.usuarios(id) ON DELETE SET NULL
);
CREATE UNIQUE INDEX uq_pedidos_omie ON core_comercial.pedidos (codigo_empresa, numero_pedido_omie) WHERE numero_pedido_omie IS NOT NULL;
CREATE INDEX ix_pedidos_fila ON core_comercial.pedidos (updated_at, id) WHERE status_sincronizacao_omie = 'pendente';
CREATE INDEX ix_pedidos_vendedor ON core_comercial.pedidos (id_usuario_vendedor) WHERE id_usuario_vendedor IS NOT NULL;
CREATE TRIGGER trg_pedidos_updated_at BEFORE UPDATE ON core_comercial.pedidos FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TABLE core_comercial.pedidos IS 'Pedido de venda no Hub, das duas origens (N16-106). PROPOSTA: nasce da proposta aprovada (N16-02), vive só no Hub até o botão "Transformar em pedido" e vai ao Omie por fila (N16-90). OMIE: digitado direto no Omie, trazido pelo job (fn_pedidos_omie_sincronizar) com a parte de vendas travada; o vendedor preenche a parte de compras. Dados que o Omie não tem (Qualidade, faturamento em partes, previsões) ficam só aqui.';
COMMENT ON COLUMN core_comercial.pedidos.data_previsao_faturamento IS 'Vigente: entrega do fornecedor mais recente + 1 dia útil (N16-88, N16-91, N16-97). Não volta ao Omie; o Omie guarda a inicial.';
COMMENT ON COLUMN core_comercial.pedidos.faturamento_parcial IS 'true = pode faturar em partes (sequenciais); false = somente inteiro. Faturar em parte quando false só gera aviso (N16-91). No pedido do Omie o vendedor responde no Hub (N16-106).';
COMMENT ON COLUMN core_comercial.pedidos.id_usuario_vendedor IS 'Usuário do Hub que é o vendedor: o responsável da proposta, ou, no pedido do Omie, o usuário do vendedor do Omie que a API resolve. Recebe os avisos de compra acima do valor e de data do CCP.';

CREATE TABLE core_comercial.pedidos_itens (
    id                  uuid DEFAULT uuidv7() NOT NULL,
    id_pedido           uuid NOT NULL,
    ordem               integer NOT NULL,
    id_proposta_item    uuid,
    codigo_item_omie    bigint,
    natureza_custo      varchar(10) DEFAULT 'MATERIAL' NOT NULL,
    id_produto          uuid,
    codigo_produto      varchar(60),
    codigo_produto_omie varchar(60),
    descricao           text NOT NULL,
    ncm                 varchar(10),
    cfop                varchar(10),
    codigo_cenario_omie bigint,
    quantidade          numeric(14,4) NOT NULL,
    unidade_medida      varchar(4) NOT NULL,
    valor_unitario      numeric(14,2) NOT NULL,
    desconto_pct        numeric(7,4) DEFAULT 0 NOT NULL,
    icms_pct            numeric(7,4) DEFAULT 0 NOT NULL,
    ipi_pct             numeric(7,4) DEFAULT 0 NOT NULL,
    st_pct              numeric(7,4) DEFAULT 0 NOT NULL,
    valor_total         numeric(14,2) NOT NULL,
    prazo_dias_uteis    text,
    -- parte de compras (N16-106): copiada da proposta; no pedido do Omie, preenchida pelo vendedor no Hub
    custo               numeric(14,4),
    origem_custo        varchar(10),
    fornecedor          varchar(200),
    id_oferta           uuid,
    CONSTRAINT pk_pedidos_itens PRIMARY KEY (id),
    CONSTRAINT uq_pedidos_itens_ordem UNIQUE (id_pedido, ordem),
    CONSTRAINT uq_pedidos_itens_proposta UNIQUE (id_proposta_item),
    CONSTRAINT ck_pedidos_itens_natureza CHECK (natureza_custo IN ('MATERIAL','FABRICACAO','SERVICO')),
    CONSTRAINT ck_pedidos_itens_qtd CHECK (quantidade > 0),
    CONSTRAINT ck_pedidos_itens_custo CHECK (custo IS NULL OR custo >= 0),
    CONSTRAINT ck_pedidos_itens_origem_custo CHECK (origem_custo IS NULL OR origem_custo IN ('VIGENTE','HISTORICO','MANUAL','SEM_CUSTO')),
    CONSTRAINT fk_pedidos_itens_pedido FOREIGN KEY (id_pedido) REFERENCES core_comercial.pedidos(id) ON DELETE CASCADE,
    CONSTRAINT fk_pedidos_itens_proposta FOREIGN KEY (id_proposta_item) REFERENCES core_comercial.propostas_itens(id),
    CONSTRAINT fk_pedidos_itens_produto FOREIGN KEY (id_produto) REFERENCES core.produtos(id),
    CONSTRAINT fk_pedidos_itens_oferta FOREIGN KEY (id_oferta) REFERENCES core_comercial.ofertas(id)
);
CREATE INDEX ix_pedidos_itens_produto ON core_comercial.pedidos_itens (id_pedido, codigo_produto_omie);
CREATE UNIQUE INDEX uq_pedidos_itens_omie ON core_comercial.pedidos_itens (codigo_item_omie) WHERE codigo_item_omie IS NOT NULL;
COMMENT ON COLUMN core_comercial.pedidos_itens.quantidade IS 'Quantidade ORIGINAL do item no pedido. O Omie zera a linha do original quando o pedido é quebrado em sequenciais (N16-100); aqui ela se preserva.';
COMMENT ON COLUMN core_comercial.pedidos_itens.custo IS 'Custo de compra unitário que o vendedor pôs (o mesmo da proposta, N16-60). No pedido do Omie, o vendedor preenche no Hub (N16-106): é a base da compra acima do valor e da simulação da comissão.';

-- O que veio do Omie só se altera no Omie (N16-106): no pedido de origem OMIE, a parte de vendas (cabeçalho e itens) só muda pela
-- sincronização (fn_pedidos_omie_sincronizar). O vendedor altera a parte de compras e as respostas (Qualidade, faturamento em partes).
CREATE FUNCTION core_comercial.fn_pedidos_omie_travar() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.origem = 'OMIE' AND current_setting('core_comercial.sincronizando_omie', true) IS DISTINCT FROM 'on' AND (
       (NEW.codigo_empresa, NEW.numero_pedido_omie, NEW.codigo_pedido_omie, NEW.codigo_cliente_omie, NEW.codigo_vendedor_omie, NEW.moeda,
        NEW.valor_frete, NEW.condicao_pagamento, NEW.codigo_parcela_omie, NEW.valor_total, NEW.data_previsao_faturamento_inicial,
        NEW.cancelado_em, NEW.origem)
       IS DISTINCT FROM
       (OLD.codigo_empresa, OLD.numero_pedido_omie, OLD.codigo_pedido_omie, OLD.codigo_cliente_omie, OLD.codigo_vendedor_omie, OLD.moeda,
        OLD.valor_frete, OLD.condicao_pagamento, OLD.codigo_parcela_omie, OLD.valor_total, OLD.data_previsao_faturamento_inicial,
        OLD.cancelado_em, OLD.origem)) THEN
    RAISE EXCEPTION 'PEDIDO_DO_OMIE: o que veio do Omie só se altera no Omie (pedido %).', OLD.numero_pedido_omie USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_pedidos_omie_travar BEFORE UPDATE ON core_comercial.pedidos
  FOR EACH ROW EXECUTE FUNCTION core_comercial.fn_pedidos_omie_travar();

CREATE FUNCTION core_comercial.fn_pedidos_itens_omie_travar() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_origem varchar;
BEGIN
  SELECT origem INTO v_origem FROM core_comercial.pedidos WHERE id = coalesce(NEW.id_pedido, OLD.id_pedido);
  IF v_origem = 'OMIE' AND current_setting('core_comercial.sincronizando_omie', true) IS DISTINCT FROM 'on' THEN
    IF TG_OP <> 'UPDATE' OR
       (NEW.id_pedido, NEW.ordem, NEW.codigo_item_omie, NEW.id_produto, NEW.codigo_produto, NEW.codigo_produto_omie, NEW.descricao, NEW.ncm,
        NEW.cfop, NEW.quantidade, NEW.unidade_medida, NEW.valor_unitario, NEW.desconto_pct, NEW.icms_pct, NEW.ipi_pct, NEW.st_pct, NEW.valor_total)
       IS DISTINCT FROM
       (OLD.id_pedido, OLD.ordem, OLD.codigo_item_omie, OLD.id_produto, OLD.codigo_produto, OLD.codigo_produto_omie, OLD.descricao, OLD.ncm,
        OLD.cfop, OLD.quantidade, OLD.unidade_medida, OLD.valor_unitario, OLD.desconto_pct, OLD.icms_pct, OLD.ipi_pct, OLD.st_pct, OLD.valor_total) THEN
      RAISE EXCEPTION 'PEDIDO_DO_OMIE: itens e valores do pedido do Omie só se alteram no Omie; no Hub o vendedor preenche a parte de compras.' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN coalesce(NEW, OLD);
END $$;
CREATE TRIGGER trg_pedidos_itens_omie_travar BEFORE INSERT OR UPDATE OR DELETE ON core_comercial.pedidos_itens
  FOR EACH ROW EXECUTE FUNCTION core_comercial.fn_pedidos_itens_omie_travar();

-- Uma linha por tentativa de envio ao Omie (erro, reenvio e auditoria).
CREATE TABLE core_comercial.pedidos_envios (
    id                 uuid DEFAULT uuidv7() NOT NULL,
    id_pedido          uuid NOT NULL,
    tentativa          integer NOT NULL,
    resultado          varchar(10) NOT NULL,
    codigo_erro        varchar(40),
    mensagem           text,
    codigo_pedido_omie bigint,
    numero_pedido_omie varchar(15),
    id_usuario         uuid,
    ocorrido_em        timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_pedidos_envios PRIMARY KEY (id),
    CONSTRAINT uq_pedidos_envios UNIQUE (id_pedido, tentativa),
    CONSTRAINT ck_pedidos_envios_res CHECK (resultado IN ('ENVIADO','RECUSADO','REENVIO')),
    CONSTRAINT fk_pedidos_envios_pedido FOREIGN KEY (id_pedido) REFERENCES core_comercial.pedidos(id)
);

-- As datas do pedido (N16-88, N16-91, N16-97, N16-104): só INSERT; atraso do fornecedor calculado. Valem para TODO pedido de venda,
-- o que nasce de proposta e o digitado direto no Omie: a chave é a da N16-102 (unidade + número do pedido no Omie + produto).
-- O PCP e o vendedor veem todas (a do vendedor, as de Compras e as do CCP) e a vigente (N16-104).
CREATE TABLE core_comercial.pedidos_previsoes (
    id                          uuid DEFAULT uuidv7() NOT NULL,
    codigo_empresa              uuid NOT NULL,
    numero_pedido               varchar(15),
    id_pedido                   uuid,
    codigo_produto_omie         varchar(60),
    tipo                        varchar(16) NOT NULL,
    id_ordem_compra             uuid,
    data_entrega                date,
    data_faturamento_resultante date NOT NULL,
    atraso_dias                 integer,
    motivo                      text,
    perfil                      varchar(12),
    registrado_por              uuid,
    registrado_em               timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_pedidos_previsoes PRIMARY KEY (id),
    CONSTRAINT ck_pedidos_previsoes_chave CHECK (numero_pedido IS NOT NULL OR id_pedido IS NOT NULL),
    CONSTRAINT ck_pedidos_previsoes_tipo CHECK (tipo IN ('INICIAL','ENTREGA_COMPRAS','ENTREGA_CCP')),
    CONSTRAINT ck_pedidos_previsoes_data CHECK ((tipo = 'INICIAL') = (data_entrega IS NULL)),
    CONSTRAINT fk_pedidos_previsoes_empresa FOREIGN KEY (codigo_empresa) REFERENCES core.unidades(id),
    CONSTRAINT fk_pedidos_previsoes_pedido FOREIGN KEY (id_pedido) REFERENCES core_comercial.pedidos(id),
    CONSTRAINT fk_pedidos_previsoes_oc FOREIGN KEY (id_ordem_compra) REFERENCES core_vendas_faturamento.ordens_compra(id),
    CONSTRAINT fk_pedidos_previsoes_usuario FOREIGN KEY (registrado_por) REFERENCES auth.usuarios(id) ON DELETE SET NULL
);
CREATE INDEX ix_pedidos_previsoes ON core_comercial.pedidos_previsoes (codigo_empresa, numero_pedido, registrado_em);
CREATE INDEX ix_pedidos_previsoes_hub ON core_comercial.pedidos_previsoes (id_pedido) WHERE id_pedido IS NOT NULL;
COMMENT ON COLUMN core_comercial.pedidos_previsoes.numero_pedido IS 'Número do pedido no Omie. Nulo só na previsão INICIAL do pedido do Hub, gravada antes de o Omie devolver o número; as visões a resolvem pelo pedido.';
COMMENT ON COLUMN core_comercial.pedidos_previsoes.codigo_produto_omie IS 'Item do pedido (produto do Omie, N16-102). Nulo = o pedido inteiro (a INICIAL).';
CREATE FUNCTION core_comercial.fn_pedidos_previsoes_imutavel() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'pedidos_previsoes só recebe INSERT.' USING ERRCODE = '23514'; END $$;
CREATE TRIGGER trg_pedidos_previsoes_imutavel BEFORE UPDATE OR DELETE ON core_comercial.pedidos_previsoes
  FOR EACH ROW EXECUTE FUNCTION core_comercial.fn_pedidos_previsoes_imutavel();

-- Soma n dias úteis (sábado, domingo e feriados da lista). O calendário de feriados por unidade vem da biblioteca de feriados + exceções
-- cadastradas pelo marketing (N16-96, N16-99): aqui a função recebe os feriados já resolvidos, para não prender o banco a uma biblioteca.
CREATE FUNCTION core_comercial.fn_somar_dias_uteis(p_data date, p_dias integer, p_feriados date[] DEFAULT '{}') RETURNS date
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE d date := p_data; n integer := 0;
BEGIN
  WHILE n < p_dias LOOP
    d := d + 1;
    IF extract(isodow FROM d) < 6 AND NOT (d = ANY (p_feriados)) THEN n := n + 1; END IF;
  END LOOP;
  RETURN d;
END $$;

-- Calendário: exceções que o MARKETING cadastra numa tela própria (N16-99, N16-104), por unidade ou para todas. A biblioteca de
-- feriados (date-holidays, por estado, N16-96) roda na API; o banco guarda só o que ela não sabe: feriado municipal, ponte, e o
-- feriado da biblioteca em que a unidade trabalha.
CREATE TABLE core_comercial.calendario_excecoes (
    id          uuid DEFAULT uuidv7() NOT NULL,
    id_unidade  uuid,
    data        date NOT NULL,
    tipo        varchar(10) NOT NULL,
    descricao   varchar(120) NOT NULL,
    ativo       boolean DEFAULT true NOT NULL,
    created_at  timestamptz DEFAULT now() NOT NULL,
    created_by  uuid,
    updated_at  timestamptz DEFAULT now() NOT NULL,
    updated_by  uuid,
    CONSTRAINT pk_calendario_excecoes PRIMARY KEY (id),
    CONSTRAINT ck_calendario_excecoes_tipo CHECK (tipo IN ('FERIADO','DIA_UTIL')),
    CONSTRAINT ck_calendario_excecoes_descricao CHECK (length(btrim(descricao)) >= 3),
    CONSTRAINT fk_calendario_excecoes_unidade FOREIGN KEY (id_unidade) REFERENCES core.unidades(id),
    CONSTRAINT fk_calendario_excecoes_criado FOREIGN KEY (created_by) REFERENCES auth.usuarios(id) ON DELETE SET NULL,
    CONSTRAINT fk_calendario_excecoes_alterado FOREIGN KEY (updated_by) REFERENCES auth.usuarios(id) ON DELETE SET NULL
);
-- Uma exceção ativa por dia e unidade (nula = todas as unidades).
CREATE UNIQUE INDEX uq_calendario_excecoes ON core_comercial.calendario_excecoes
  (coalesce(id_unidade, '00000000-0000-0000-0000-000000000000'::uuid), data) WHERE ativo;
CREATE TRIGGER trg_calendario_excecoes_updated_at BEFORE UPDATE ON core_comercial.calendario_excecoes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TABLE core_comercial.calendario_excecoes IS 'Exceções do calendário de dias úteis, cadastradas pelo marketing (N16-104). FERIADO = dia sem expediente que a biblioteca não traz (municipal, ponte); DIA_UTIL = feriado da biblioteca em que a unidade trabalha. Desativar em vez de apagar.';

-- Feriados de uma unidade num período: os da biblioteca (a API manda) mais os FERIADO cadastrados, menos os DIA_UTIL.
-- Exceção da unidade vence a de todas as unidades no mesmo dia.
CREATE FUNCTION core_comercial.fn_calendario_feriados(p_unidade uuid, p_feriados_biblioteca date[], p_de date, p_ate date)
RETURNS date[] LANGUAGE sql STABLE AS $$
  WITH exc AS (
    SELECT DISTINCT ON (e.data) e.data, e.tipo
      FROM core_comercial.calendario_excecoes e
     WHERE e.ativo AND e.data BETWEEN p_de AND p_ate AND (e.id_unidade = p_unidade OR e.id_unidade IS NULL)
     ORDER BY e.data, (e.id_unidade IS NULL)
  )
  SELECT coalesce(array_agg(d ORDER BY d), '{}') FROM (
    SELECT b AS d FROM unnest(coalesce(p_feriados_biblioteca, '{}')) b WHERE b BETWEEN p_de AND p_ate
    UNION
    SELECT data FROM exc WHERE tipo = 'FERIADO'
    EXCEPT
    SELECT data FROM exc WHERE tipo = 'DIA_UTIL'
  ) x
$$;

-- Quebra do pedido em partes para o Fiscal faturar (N16-92): um pedido, várias notas. O Hub guarda a ligação quando a quebra nasce nele.
CREATE TABLE core_comercial.pedidos_sequenciais (
    id                 uuid DEFAULT uuidv7() NOT NULL,
    id_pedido          uuid NOT NULL,
    sequencial         integer NOT NULL,
    status             varchar(10) DEFAULT 'ABERTO' NOT NULL,
    codigo_pedido_omie bigint,
    separado_por       uuid,
    cancelado_em       timestamptz,
    cancelado_por      uuid,
    motivo_cancelamento text,
    created_at         timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_pedidos_sequenciais PRIMARY KEY (id),
    CONSTRAINT uq_pedidos_sequenciais UNIQUE (id_pedido, sequencial),
    CONSTRAINT ck_pedidos_sequenciais_seq CHECK (sequencial >= 1),
    CONSTRAINT ck_pedidos_sequenciais_status CHECK (status IN ('ABERTO','FATURADO','CANCELADO')),
    CONSTRAINT ck_pedidos_sequenciais_cancelado CHECK ((status = 'CANCELADO') = (cancelado_em IS NOT NULL)),
    CONSTRAINT fk_pedidos_sequenciais_pedido FOREIGN KEY (id_pedido) REFERENCES core_comercial.pedidos(id),
    CONSTRAINT fk_pedidos_sequenciais_separado FOREIGN KEY (separado_por) REFERENCES auth.usuarios(id) ON DELETE SET NULL
);
CREATE TABLE core_comercial.pedidos_sequenciais_itens (
    id                  uuid DEFAULT uuidv7() NOT NULL,
    id_sequencial       uuid NOT NULL,
    id_pedido_item      uuid NOT NULL,
    codigo_item_omie    bigint,
    quantidade          numeric(14,4) NOT NULL,
    valor               numeric(14,2) NOT NULL,
    CONSTRAINT pk_pedidos_sequenciais_itens PRIMARY KEY (id),
    CONSTRAINT uq_pedidos_sequenciais_itens UNIQUE (id_sequencial, id_pedido_item),
    CONSTRAINT ck_pedidos_sequenciais_itens_qtd CHECK (quantidade > 0 AND valor >= 0),
    CONSTRAINT fk_pedidos_sequenciais_itens_seq FOREIGN KEY (id_sequencial) REFERENCES core_comercial.pedidos_sequenciais(id) ON DELETE CASCADE,
    CONSTRAINT fk_pedidos_sequenciais_itens_item FOREIGN KEY (id_pedido_item) REFERENCES core_comercial.pedidos_itens(id)
);
COMMENT ON TABLE core_comercial.pedidos_sequenciais IS 'Sequencial = agrupamento para faturar em partes, NÃO é outro pedido nem parcela de pagamento (N16-92, N16-94). A OC e o custo ficam no item do pedido original. O número cancelado nunca se reusa.';

-- Saldo do original = valor do pedido menos os sequenciais não cancelados.
CREATE VIEW core_comercial.vw_pedidos_saldo AS
SELECT p.id AS id_pedido, p.valor_total,
       coalesce(sum(si.valor) FILTER (WHERE s.status <> 'CANCELADO'), 0) AS valor_em_sequenciais,
       p.valor_total - coalesce(sum(si.valor) FILTER (WHERE s.status <> 'CANCELADO'), 0) AS saldo_original
  FROM core_comercial.pedidos p
  LEFT JOIN core_comercial.pedidos_sequenciais s ON s.id_pedido = p.id
  LEFT JOIN core_comercial.pedidos_sequenciais_itens si ON si.id_sequencial = s.id
 GROUP BY p.id, p.valor_total;

-- ───────────────────────── D) Funções do pedido: transformar, registrar datas, cancelar

-- Transformar proposta aprovada em pedido (V0.6). As TRÊS respostas são obrigatórias (N16-88, N16-89).
-- A numeração do pedido reaproveita sequencias_documento (tipo PV + código da emissora, ano 0), por unidade (N16-04).
CREATE FUNCTION core_comercial.fn_propostas_transformar_em_pedido(
    p_proposta uuid, p_acompanha boolean, p_faturamento_parcial boolean, p_data_previsao date,
    p_usuario uuid, p_codigo_vendedor_omie varchar DEFAULT NULL) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE p core_comercial.propostas%ROWTYPE; e core_comercial.unidades_emissoras%ROWTYPE; v_num bigint; v_ped uuid;
BEGIN
  SELECT * INTO p FROM core_comercial.propostas WHERE id = p_proposta AND deleted_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PROPOSTA_NAO_ENCONTRADA' USING ERRCODE = 'P0002'; END IF;
  IF p.status <> 'APROVADA' THEN
    RAISE EXCEPTION 'PROPOSTA_NAO_APROVADA: só a proposta aprovada vira pedido (status atual %).', p.status USING ERRCODE = '23514';
  END IF;
  IF p_acompanha IS NULL THEN
    RAISE EXCEPTION 'QUALIDADE_NAO_INFORMADA: marque se a Qualidade acompanha todo o processo, desde o zero.' USING ERRCODE = '23514';
  END IF;
  IF p_faturamento_parcial IS NULL THEN
    RAISE EXCEPTION 'FATURAMENTO_NAO_INFORMADO: diga se o pedido pode faturar em partes ou somente inteiro.' USING ERRCODE = '23514';
  END IF;
  IF p_data_previsao IS NULL OR p_data_previsao < current_date THEN
    RAISE EXCEPTION 'PREVISAO_INVALIDA: informe a data de previsão de faturamento (hoje ou depois).' USING ERRCODE = '23514';
  END IF;
  IF EXISTS (SELECT 1 FROM core_comercial.propostas_itens i WHERE i.id_proposta = p.id AND i.id_produto_pendente IS NOT NULL) THEN
    RAISE EXCEPTION 'PRODUTO_PENDENTE: há produto sem cadastro no Omie; peça o cadastro ao Fiscal antes de transformar.' USING ERRCODE = '23514';
  END IF;
  SELECT * INTO e FROM core_comercial.unidades_emissoras WHERE id = p.id_unidade_emissora;
  IF NOT FOUND OR e.id_unidade_conta_omie IS NULL THEN
    RAISE EXCEPTION 'EMISSORA_SEM_CONTA_OMIE: a unidade emissora não tem conta Omie.' USING ERRCODE = '23514';
  END IF;
  v_num := core_comercial.fn_proxima_sequencia_documento('PV' || e.codigo, 0);

  INSERT INTO core_comercial.pedidos
    (origem, id_usuario_vendedor, numero, codigo_empresa, id_proposta, id_unidade_emissora, id_cliente, codigo_vendedor_omie, finalidade, moeda, cotacao_moeda,
     incoterm, valor_frete, condicao_pagamento, codigo_parcela_omie, numero_requisicao_cliente, observacoes, valor_total,
     acompanhamento_qualidade, faturamento_parcial, data_previsao_faturamento_inicial, data_previsao_faturamento,
     liberado_por, codigo_pedido_integracao, created_by, updated_by)
  VALUES ('PROPOSTA', p.id_responsavel, v_num, e.id_unidade_conta_omie, p.id, p.id_unidade_emissora, p.id_cliente, p_codigo_vendedor_omie, p.finalidade, p.moeda,
     p.cotacao_moeda, p.incoterm, p.valor_frete, p.condicao_pagamento, p.codigo_parcela_omie, p.numero_requisicao, p.observacoes,
     p.total_geral, p_acompanha, p_faturamento_parcial, p_data_previsao, p_data_previsao, p_usuario, v_num::text, p_usuario, p_usuario)
  RETURNING id INTO v_ped;

  INSERT INTO core_comercial.pedidos_itens
    (id_pedido, ordem, id_proposta_item, natureza_custo, id_produto, codigo_produto, codigo_produto_omie, descricao, ncm, cfop,
     codigo_cenario_omie, quantidade, unidade_medida, valor_unitario, desconto_pct, icms_pct, ipi_pct, st_pct, valor_total, prazo_dias_uteis,
     custo, origem_custo, fornecedor, id_oferta)
  SELECT v_ped, i.ordem, i.id, i.natureza_custo, i.id_produto, coalesce(i.codigo, pr.codigo_produto), pr.codigo_produto_omie,
         i.descricao, i.ncm, i.cfop, i.codigo_cenario_omie, i.quantidade, i.unidade_medida, i.preco_unitario, i.desconto_pct,
         i.icms_pct, i.ipi_pct, i.st_pct, i.base + i.valor_ipi + i.valor_st, i.prazo_dias_uteis,
         i.custo, i.origem_custo, i.fornecedor, i.id_oferta
    FROM core_comercial.propostas_itens i
    LEFT JOIN core.produtos pr ON pr.id = i.id_produto
   WHERE i.id_proposta = p.id;

  INSERT INTO core_comercial.pedidos_previsoes (codigo_empresa, id_pedido, tipo, data_faturamento_resultante, perfil, registrado_por)
  VALUES (e.id_unidade_conta_omie, v_ped, 'INICIAL', p_data_previsao, 'VENDEDOR', p_usuario);

  UPDATE core_comercial.propostas
     SET status = 'TRANSFORMADA', transformada_em = now(), transformada_por = p_usuario, updated_by = p_usuario, versao = versao + 1
   WHERE id = p.id;
  INSERT INTO core_comercial.propostas_eventos (id_proposta, tipo, dados, id_usuario)
  VALUES (p.id, 'TRANSFORMADA_EM_PEDIDO', jsonb_build_object('id_pedido', v_ped, 'numero_pedido', v_num), p_usuario);
  RETURN v_ped;
END $$;

-- Traz para o Hub o pedido digitado direto no Omie, ou atualiza a parte de vendas dele (N16-106). O job chama para cada pedido
-- original novo ou alterado em pedidos_vendas. Pedido que nasceu de proposta já está aqui: devolve o id dele e não mexe.
-- Itens = um por produto (N16-102), com a quantidade da família (original e sequenciais, sem cascas). A parte de compras, a
-- Qualidade e o faturamento em partes que o vendedor preencher no Hub não são tocados. Cancelado no Omie, fica cancelado aqui.
CREATE FUNCTION core_comercial.fn_pedidos_omie_sincronizar(p_empresa uuid, p_numero_pedido varchar, p_id_usuario_vendedor uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_ped uuid; v_origem varchar; pv record; v_emissora uuid; v_prev date; v_novo boolean := false; r record; v_item uuid; v_ordem integer;
BEGIN
  SELECT id, origem INTO v_ped, v_origem FROM core_comercial.pedidos WHERE codigo_empresa = p_empresa AND numero_pedido_omie = p_numero_pedido;
  IF FOUND AND v_origem = 'PROPOSTA' THEN RETURN v_ped; END IF;
  SELECT p.* INTO pv FROM core_vendas_faturamento.pedidos_vendas p
   WHERE p.codigo_empresa = p_empresa AND p.numero_pedido = p_numero_pedido AND coalesce(p.sequencial, 0) = 0 AND p.deleted_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'PEDIDO_NAO_ENCONTRADO: pedido % não está em pedidos_vendas.', p_numero_pedido USING ERRCODE = 'P0002'; END IF;
  SELECT e.id INTO v_emissora FROM core_comercial.unidades_emissoras e
   WHERE e.id_unidade_conta_omie = p_empresa ORDER BY (e.id_unidade = p_empresa) DESC, e.codigo LIMIT 1;
  IF v_emissora IS NULL THEN RAISE EXCEPTION 'EMISSORA_SEM_CONTA_OMIE: nenhuma unidade emissora usa esta conta Omie.' USING ERRCODE = '23514'; END IF;
  v_prev := CASE WHEN pv.data_previsao ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN substr(pv.data_previsao, 1, 10)::date END;
  PERFORM set_config('core_comercial.sincronizando_omie', 'on', true);

  IF v_ped IS NULL THEN
    INSERT INTO core_comercial.pedidos
      (origem, codigo_empresa, id_unidade_emissora, codigo_cliente_omie, codigo_vendedor_omie, id_usuario_vendedor, valor_total,
       data_previsao_faturamento_inicial, data_previsao_faturamento, status_sincronizacao_omie, codigo_pedido_omie, numero_pedido_omie,
       sincronizado_em, cancelado_em, motivo_cancelamento)
    VALUES ('OMIE', p_empresa, v_emissora, pv.codigo_cliente, pv.codigo_vendedor_omie, p_id_usuario_vendedor, coalesce(pv.valor_total_pedido, 0),
       v_prev, v_prev, 'sincronizado', pv.codigo_pedido_omie, pv.numero_pedido, now(),
       CASE WHEN pv.cancelado THEN now() END, CASE WHEN pv.cancelado THEN 'Cancelado no Omie' END)
    RETURNING id INTO v_ped;
    v_novo := true;
    IF v_prev IS NOT NULL THEN
      INSERT INTO core_comercial.pedidos_previsoes (codigo_empresa, numero_pedido, id_pedido, tipo, data_faturamento_resultante, perfil)
      VALUES (p_empresa, p_numero_pedido, v_ped, 'INICIAL', v_prev, 'OMIE');
    END IF;
  ELSE
    UPDATE core_comercial.pedidos
       SET codigo_cliente_omie = pv.codigo_cliente, codigo_vendedor_omie = pv.codigo_vendedor_omie,
           id_usuario_vendedor = coalesce(p_id_usuario_vendedor, id_usuario_vendedor), valor_total = coalesce(pv.valor_total_pedido, 0),
           codigo_pedido_omie = pv.codigo_pedido_omie, sincronizado_em = now(),
           cancelado_em = CASE WHEN pv.cancelado THEN coalesce(cancelado_em, now()) END,
           motivo_cancelamento = CASE WHEN pv.cancelado THEN coalesce(motivo_cancelamento, 'Cancelado no Omie') END
     WHERE id = v_ped;
  END IF;

  -- itens: um por produto, com a soma da família
  FOR r IN
    SELECT it.codigo_produto_omie, min(it.codigo_item_omie) FILTER (WHERE coalesce(f.sequencial, 0) = 0) AS codigo_item_omie,
           max(it.codigo_produto) AS codigo_produto, max(it.unidade_medida) AS unidade_medida, max(it.ncm) AS ncm, max(it.cfop) AS cfop,
           sum(it.quantidade)::numeric(14,4) AS quantidade, sum(it.valor_total) AS valor_total
      FROM core_vendas_faturamento.pedidos_vendas f
      JOIN core_vendas_faturamento.produto_vendas it
        ON it.codigo_empresa = f.codigo_empresa AND it.codigo_pedido_omie = f.codigo_pedido_omie AND it.deleted_at IS NULL
     WHERE f.codigo_empresa = p_empresa AND f.numero_pedido = p_numero_pedido AND f.deleted_at IS NULL AND NOT f.cancelado
       AND coalesce(it.quantidade, 0) > 0
     GROUP BY it.codigo_produto_omie
  LOOP
    SELECT id INTO v_item FROM core_comercial.pedidos_itens WHERE id_pedido = v_ped AND codigo_produto_omie = r.codigo_produto_omie;
    IF v_item IS NULL THEN
      SELECT coalesce(max(ordem), 0) + 1 INTO v_ordem FROM core_comercial.pedidos_itens WHERE id_pedido = v_ped;
      INSERT INTO core_comercial.pedidos_itens
        (id_pedido, ordem, codigo_item_omie, id_produto, codigo_produto, codigo_produto_omie, descricao, ncm, cfop, quantidade,
         unidade_medida, valor_unitario, valor_total)
      SELECT v_ped, v_ordem, r.codigo_item_omie, pr.id, coalesce(r.codigo_produto, pr.codigo_produto), r.codigo_produto_omie,
             coalesce(pr.descricao, r.codigo_produto, r.codigo_produto_omie), r.ncm, r.cfop, r.quantidade,
             left(coalesce(r.unidade_medida, 'UN'), 4), round(r.valor_total / r.quantidade, 2), r.valor_total
        FROM (SELECT 1) x
        LEFT JOIN core.produtos pr ON pr.codigo_empresa = p_empresa AND pr.codigo_produto_omie = r.codigo_produto_omie AND pr.deleted_at IS NULL;
    ELSE
      UPDATE core_comercial.pedidos_itens
         SET quantidade = r.quantidade, valor_total = r.valor_total, valor_unitario = round(r.valor_total / r.quantidade, 2),
             ncm = coalesce(r.ncm, ncm), cfop = coalesce(r.cfop, cfop)
       WHERE id = v_item;
    END IF;
    v_item := NULL;
  END LOOP;
  PERFORM set_config('core_comercial.sincronizando_omie', 'off', true);
  RETURN v_ped;
END $$;
COMMENT ON FUNCTION core_comercial.fn_pedidos_omie_sincronizar(uuid, varchar, uuid) IS 'N16-106: o pedido digitado no Omie entra no mesmo fluxo do Hub. Cria ou atualiza a parte de vendas (cabeçalho e um item por produto) a partir de pedidos_vendas e produto_vendas, e grava a previsão INICIAL do Omie; não toca na parte de compras nem nas respostas que o vendedor preenche. O job chama depois de cada carga da pipeline.';

-- Registra uma data de entrega do fornecedor (Compras na OC ou CCP no follow-up), para qualquer pedido de venda (N16-104).
-- Previsão de faturamento = entrega + 1 dia útil (os feriados chegam resolvidos por fn_calendario_feriados).
-- "Tudo junto": vale a MAIOR entre os itens; "em partes": cada item tem a sua, e a do pedido mostra a maior (N16-97).
-- A mudança do CCP só AVISA o vendedor (N16-91). Os valores da proposta e do pedido nunca mudam por causa das datas.
CREATE FUNCTION core_comercial.fn_pedidos_registrar_previsao(
    p_empresa uuid, p_numero_pedido varchar, p_produto varchar, p_tipo varchar, p_oc uuid, p_data_entrega date, p_motivo text,
    p_perfil varchar, p_usuario uuid, p_feriados date[] DEFAULT '{}') RETURNS date
LANGUAGE plpgsql AS $$
DECLARE v_fat date; v_ant date; v_atraso integer; v_vig date; v_vend uuid; v_hub core_comercial.pedidos%ROWTYPE; v_omie record;
BEGIN
  IF p_tipo NOT IN ('ENTREGA_COMPRAS','ENTREGA_CCP') THEN
    RAISE EXCEPTION 'TIPO_INVALIDO: use ENTREGA_COMPRAS ou ENTREGA_CCP.' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_hub FROM core_comercial.pedidos WHERE codigo_empresa = p_empresa AND numero_pedido_omie = p_numero_pedido FOR UPDATE;
  IF FOUND THEN
    IF v_hub.cancelado_em IS NOT NULL THEN RAISE EXCEPTION 'PEDIDO_CANCELADO' USING ERRCODE = '23514'; END IF;
  ELSE
    SELECT pv.cancelado INTO v_omie FROM core_vendas_faturamento.pedidos_vendas pv
     WHERE pv.codigo_empresa = p_empresa AND pv.numero_pedido = p_numero_pedido AND coalesce(pv.sequencial, 0) = 0 AND pv.deleted_at IS NULL;
    IF NOT FOUND THEN RAISE EXCEPTION 'PEDIDO_NAO_ENCONTRADO' USING ERRCODE = 'P0002'; END IF;
    IF v_omie.cancelado THEN RAISE EXCEPTION 'PEDIDO_CANCELADO' USING ERRCODE = '23514'; END IF;
  END IF;
  IF p_produto IS NOT NULL AND NOT EXISTS (SELECT 1 FROM core_comercial.vw_pedido_produtos
       WHERE codigo_empresa = p_empresa AND numero_pedido = p_numero_pedido AND codigo_produto_omie = p_produto) THEN
    RAISE EXCEPTION 'ITEM_PEDIDO_NAO_ENCONTRADO: o pedido % não tem o produto %.', p_numero_pedido, p_produto USING ERRCODE = 'P0002';
  END IF;
  IF p_data_entrega IS NULL THEN RAISE EXCEPTION 'DATA_OBRIGATORIA' USING ERRCODE = '23514'; END IF;
  IF p_tipo = 'ENTREGA_CCP' AND (p_motivo IS NULL OR length(btrim(p_motivo)) < 3) THEN
    RAISE EXCEPTION 'MOTIVO_OBRIGATORIO: o CCP registra o que o fornecedor disse.' USING ERRCODE = '23514';
  END IF;
  v_fat := core_comercial.fn_somar_dias_uteis(p_data_entrega, 1, p_feriados);
  SELECT data_entrega INTO v_ant FROM core_comercial.pedidos_previsoes
   WHERE codigo_empresa = p_empresa AND numero_pedido = p_numero_pedido AND data_entrega IS NOT NULL
     AND codigo_produto_omie IS NOT DISTINCT FROM p_produto
   ORDER BY registrado_em DESC, id DESC LIMIT 1;
  v_atraso := CASE WHEN v_ant IS NULL THEN NULL ELSE p_data_entrega - v_ant END;
  INSERT INTO core_comercial.pedidos_previsoes
    (codigo_empresa, numero_pedido, id_pedido, codigo_produto_omie, tipo, id_ordem_compra, data_entrega, data_faturamento_resultante,
     atraso_dias, motivo, perfil, registrado_por)
  VALUES (p_empresa, p_numero_pedido, v_hub.id, p_produto, p_tipo, p_oc, p_data_entrega, v_fat, v_atraso, p_motivo, p_perfil, p_usuario);
  IF v_hub.id IS NOT NULL THEN
    SELECT previsao_vigente INTO v_vig FROM core_comercial.vw_pedidos_previsao_vigente
     WHERE codigo_empresa = p_empresa AND numero_pedido = p_numero_pedido;
    UPDATE core_comercial.pedidos SET data_previsao_faturamento = v_vig, updated_by = p_usuario WHERE id = v_hub.id;
  END IF;
  IF p_tipo = 'ENTREGA_CCP' THEN
    v_vend := v_hub.id_usuario_vendedor;
    IF v_vend IS NOT NULL THEN
      INSERT INTO core_comercial.notificacoes (id_usuario, tipo, titulo, link)
      VALUES (v_vend, 'PREVISAO_ALTERADA_CCP', 'O CCP registrou uma nova data de entrega do fornecedor no seu pedido', '/vendas/meus-pedidos');
    END IF;
  END IF;
  RETURN v_fat;
END $$;

-- Todas as datas de um pedido, com o número do Omie resolvido (o histórico que o vendedor e o PCP veem).
CREATE VIEW core_comercial.vw_pedidos_previsoes AS
SELECT r.id, r.codigo_empresa, coalesce(r.numero_pedido, p.numero_pedido_omie) AS numero_pedido, r.id_pedido,
       r.codigo_produto_omie, r.tipo, r.id_ordem_compra, r.data_entrega, r.data_faturamento_resultante, r.atraso_dias,
       r.motivo, r.perfil, r.registrado_por, r.registrado_em
  FROM core_comercial.pedidos_previsoes r
  LEFT JOIN core_comercial.pedidos p ON p.id = r.id_pedido;

-- A última data de cada item (ou do pedido inteiro, na INICIAL).
CREATE VIEW core_comercial.vw_pedidos_itens_previsao AS
SELECT DISTINCT ON (codigo_empresa, coalesce(numero_pedido, id_pedido::text), coalesce(codigo_produto_omie, ''))
       codigo_empresa, numero_pedido, id_pedido, codigo_produto_omie, tipo, data_entrega,
       data_faturamento_resultante AS previsao_faturamento, atraso_dias, registrado_em
  FROM core_comercial.vw_pedidos_previsoes
 ORDER BY codigo_empresa, coalesce(numero_pedido, id_pedido::text), coalesce(codigo_produto_omie, ''), registrado_em DESC, id DESC;

-- A previsão vigente de cada pedido de venda do Omie, para o PCP (Carteira) e para Meus Pedidos (N16-104).
-- Inicial = a do vendedor (pedido do Hub) ou a do Omie (pedido digitado no Omie). Vigente = a maior entre a inicial e a última de
-- cada item (N16-97): enquanto um item não tem OC, vale a inicial.
CREATE VIEW core_comercial.vw_pedidos_previsao_vigente AS
WITH omie AS (
  SELECT pv.codigo_empresa, pv.numero_pedido,
         CASE WHEN pv.data_previsao ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN substr(pv.data_previsao, 1, 10)::date END AS previsao_omie
    FROM core_vendas_faturamento.pedidos_vendas pv
   WHERE coalesce(pv.sequencial, 0) = 0 AND pv.deleted_at IS NULL AND NOT pv.cancelado
), hub AS (
  -- o pedido do Hub entra assim que o Omie devolve o número, mesmo antes de a pipeline trazê-lo
  SELECT h.codigo_empresa, h.numero_pedido_omie AS numero_pedido, h.id AS id_pedido, h.origem, h.data_previsao_faturamento_inicial
    FROM core_comercial.pedidos h
   WHERE h.numero_pedido_omie IS NOT NULL AND h.cancelado_em IS NULL
), base AS (
  SELECT coalesce(h.codigo_empresa, o.codigo_empresa) AS codigo_empresa, coalesce(h.numero_pedido, o.numero_pedido) AS numero_pedido,
         o.previsao_omie, h.id_pedido, h.origem, h.data_previsao_faturamento_inicial AS previsao_inicial_vendedor
    FROM hub h
    FULL JOIN omie o ON o.codigo_empresa = h.codigo_empresa AND o.numero_pedido = h.numero_pedido
), itens AS (
  SELECT codigo_empresa, numero_pedido, max(previsao_faturamento) AS ultima_itens, max(atraso_dias) AS maior_atraso,
         max(registrado_em) AS ultima_alteracao
    FROM core_comercial.vw_pedidos_itens_previsao
   WHERE numero_pedido IS NOT NULL AND tipo <> 'INICIAL'
   GROUP BY codigo_empresa, numero_pedido
)
SELECT b.codigo_empresa, b.numero_pedido, b.id_pedido,
       coalesce(b.origem, 'OMIE') AS origem_pedido,
       coalesce(b.previsao_inicial_vendedor, b.previsao_omie) AS previsao_inicial,
       b.previsao_omie,
       greatest(coalesce(b.previsao_inicial_vendedor, b.previsao_omie), i.ultima_itens) AS previsao_vigente,
       i.maior_atraso, i.ultima_alteracao,
       (SELECT count(*) FROM core_comercial.vw_pedidos_previsoes r
         WHERE r.codigo_empresa = b.codigo_empresa AND r.numero_pedido = b.numero_pedido)::int AS qtd_datas
  FROM base b
  LEFT JOIN itens i ON i.codigo_empresa = b.codigo_empresa AND i.numero_pedido = b.numero_pedido;
COMMENT ON VIEW core_comercial.vw_pedidos_previsao_vigente IS 'Uma linha por pedido de venda (original, não cancelado): previsão inicial (do vendedor ou do Omie), vigente (a maior entre a inicial e a última de cada item), maior atraso do fornecedor e quantas datas foram registradas. É o que a Carteira do PCP passa a ler (N16-104; muda o SQL-015 (Carteira do PCP) e o API-017 (previsão por mês) do vault).';

-- ───────────────────────── custo realizado por item do pedido (N16-09, N16-102)

-- O ITEM do pedido de venda, para o custo real e para a compra acima do valor, é empresa + número do pedido + produto do Omie
-- (N16-102): vale para o pedido que nasce de proposta e para o digitado direto no Omie, com a mesma chave do vínculo da OC
-- (ordens_compra_itens_vinculos: codigo_empresa_pv, numero_pedido_venda, codigo_produto_pv) e do custo do lote (LOG-47, item = produto).
-- Quantidade: a do pedido no Hub (o Omie zera o original ao quebrar em sequenciais e o Hub preserva, N16-100); para o pedido do Omie
-- que o job ainda não trouxe, a soma da família no Omie (original e sequenciais, sem cascas de quantidade 0 e sem pedido cancelado).
-- Custo cotado: o que o vendedor pôs no item do pedido (copiado da proposta, ou preenchido no pedido do Omie, N16-106).
CREATE VIEW core_comercial.vw_pedido_produtos AS
WITH hub AS (
  SELECT p.codigo_empresa, p.numero_pedido_omie AS numero_pedido, i.codigo_produto_omie,
         (array_agg(p.id))[1] AS id_pedido, (array_agg(p.origem))[1] AS origem,
         (array_agg(i.id ORDER BY i.ordem))[1] AS id_item_pedido,
         sum(i.quantidade) AS quantidade,
         CASE WHEN bool_or(i.natureza_custo = 'SERVICO') THEN 'SERVICO'
              WHEN bool_or(i.natureza_custo = 'FABRICACAO') THEN 'FABRICACAO' ELSE 'MATERIAL' END AS natureza_custo,
         CASE WHEN bool_and(i.custo IS NOT NULL) THEN sum(round(i.custo * i.quantidade, 2)) END AS custo_total_cotado,
         sum(i.valor_total) AS valor_venda
    FROM core_comercial.pedidos p
    JOIN core_comercial.pedidos_itens i ON i.id_pedido = p.id
   WHERE p.numero_pedido_omie IS NOT NULL AND p.cancelado_em IS NULL AND i.codigo_produto_omie IS NOT NULL
   GROUP BY p.codigo_empresa, p.numero_pedido_omie, i.codigo_produto_omie
), omie AS (
  SELECT pv.codigo_empresa, pv.numero_pedido, it.codigo_produto_omie,
         sum(it.quantidade)::numeric(15,4) AS quantidade, sum(it.valor_total) AS valor_venda
    FROM core_vendas_faturamento.pedidos_vendas pv
    JOIN core_vendas_faturamento.produto_vendas it
      ON it.codigo_empresa = pv.codigo_empresa AND it.codigo_pedido_omie = pv.codigo_pedido_omie AND it.deleted_at IS NULL
   WHERE pv.deleted_at IS NULL AND NOT pv.cancelado AND coalesce(it.quantidade, 0) > 0
   GROUP BY pv.codigo_empresa, pv.numero_pedido, it.codigo_produto_omie
)
SELECT coalesce(h.codigo_empresa, o.codigo_empresa) AS codigo_empresa,
       coalesce(h.numero_pedido, o.numero_pedido) AS numero_pedido,
       coalesce(h.codigo_produto_omie, o.codigo_produto_omie) AS codigo_produto_omie,
       coalesce(h.origem, 'OMIE') AS origem_pedido,
       h.id_pedido, h.id_item_pedido,
       coalesce(h.quantidade, o.quantidade) AS quantidade,
       coalesce(h.natureza_custo, 'MATERIAL') AS natureza_custo,
       h.custo_total_cotado,
       coalesce(h.valor_venda, o.valor_venda) AS valor_venda
  FROM hub h
  FULL JOIN omie o ON o.codigo_empresa = h.codigo_empresa AND o.numero_pedido = h.numero_pedido
                  AND o.codigo_produto_omie = h.codigo_produto_omie;
COMMENT ON VIEW core_comercial.vw_pedido_produtos IS 'Item do pedido de venda para custo real e divergência (N16-102): um por empresa + número do pedido + produto do Omie. origem_pedido PROPOSTA ou OMIE; id_pedido nulo = pedido do Omie que o job ainda não trouxe (sem custo cotado). custo_total_cotado só quando todas as linhas do produto têm o custo do vendedor.';

-- Um evento por linha de custo (OC, lote do Estoque, matéria-prima, mão de obra). Só se insere: estorno é outra linha.
CREATE TABLE core_comercial.custos_eventos (
    id                       uuid DEFAULT uuidv7() NOT NULL,
    codigo_empresa           uuid NOT NULL,
    numero_pedido            varchar(15) NOT NULL,
    codigo_produto_item      varchar(60) NOT NULL,
    id_pedido                uuid,
    id_item_pedido           uuid,
    id_item_parcial          uuid,
    codigo_parcial           varchar(20),
    origem                   varchar(26) NOT NULL,
    documento_tipo           varchar(20) NOT NULL,
    sentido                  smallint DEFAULT 1 NOT NULL,
    status                   varchar(10) DEFAULT 'VALIDO' NOT NULL,
    data_evento              date NOT NULL,
    ocorrido_em              timestamptz DEFAULT now() NOT NULL,
    codigo_produto           varchar(60),
    descricao_material       text,
    quantidade_documento     numeric(15,4) NOT NULL,
    unidade_documento        varchar(10) NOT NULL,
    quantidade_item_coberta  numeric(15,4) DEFAULT 0 NOT NULL,
    valor_unitario           numeric(15,6) NOT NULL,
    valor_total              numeric(15,2) NOT NULL,
    moeda                    varchar(3) DEFAULT 'BRL' NOT NULL,
    cotacao_moeda            numeric(15,6),
    cotacao_a_conferir       boolean DEFAULT false NOT NULL,
    icms_recuperar_total     numeric(15,2),
    ipi_total                numeric(15,2),
    st_total                 numeric(15,2),
    frete_total              numeric(15,2),
    id_ordem_compra          uuid,
    id_ordem_compra_item     uuid,
    id_vinculo_oc            uuid,
    numero_ordem_compra      varchar(30),
    id_requisicao            uuid,
    numero_requisicao        varchar(30),
    codigo_lote              varchar(40),
    id_lote_mes              uuid,
    id_item_oc_do_lote       uuid,
    id_evento_estornado      uuid,
    motivo                   text,
    chave_idempotencia       varchar(200) NOT NULL,
    id_usuario               uuid,
    created_at               timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_custo_evento PRIMARY KEY (id),
    CONSTRAINT uq_custo_evento_chave UNIQUE (chave_idempotencia),
    CONSTRAINT uq_custo_evento_estorno UNIQUE (id_evento_estornado),
    CONSTRAINT ck_custo_evento_hub CHECK (id_item_pedido IS NULL OR id_pedido IS NOT NULL),
    CONSTRAINT ck_custo_evento_origem CHECK (origem IN ('OC_MATERIAL','LOTE_ESTOQUE','MATERIA_PRIMA_FABRICACAO','MAO_DE_OBRA_OC_SERVICO')),
    CONSTRAINT ck_custo_evento_doc CHECK (documento_tipo IN ('ORDEM_COMPRA_ITEM','LOTE')),
    CONSTRAINT ck_custo_evento_doc_ref CHECK (
        (documento_tipo = 'ORDEM_COMPRA_ITEM') = (id_ordem_compra_item IS NOT NULL)
        AND (documento_tipo = 'LOTE') = (codigo_lote IS NOT NULL)),
    CONSTRAINT ck_custo_evento_origem_doc CHECK (
        (origem = 'LOTE_ESTOQUE' AND documento_tipo = 'LOTE')
        OR (origem = 'MAO_DE_OBRA_OC_SERVICO' AND documento_tipo = 'ORDEM_COMPRA_ITEM')
        OR origem IN ('OC_MATERIAL','MATERIA_PRIMA_FABRICACAO')),
    CONSTRAINT ck_custo_evento_sentido CHECK (sentido IN (1,-1)),
    CONSTRAINT ck_custo_evento_estorno CHECK ((sentido = -1) = (id_evento_estornado IS NOT NULL)
                                              AND (sentido = 1 OR length(btrim(coalesce(motivo,''))) >= 3)),
    CONSTRAINT ck_custo_evento_status CHECK (status IN ('VALIDO','DESCARTADO')),
    CONSTRAINT ck_custo_evento_valores CHECK (quantidade_documento > 0 AND quantidade_item_coberta >= 0
                                              AND valor_unitario >= 0 AND valor_total >= 0),
    CONSTRAINT ck_custo_evento_moeda CHECK (moeda = 'BRL' OR cotacao_moeda IS NOT NULL),
    CONSTRAINT fk_custo_evento_empresa FOREIGN KEY (codigo_empresa) REFERENCES core.unidades(id),
    CONSTRAINT fk_custo_evento_pedido FOREIGN KEY (id_pedido) REFERENCES core_comercial.pedidos(id),
    CONSTRAINT fk_custo_evento_item FOREIGN KEY (id_item_pedido) REFERENCES core_comercial.pedidos_itens(id),
    CONSTRAINT fk_custo_evento_estorno FOREIGN KEY (id_evento_estornado) REFERENCES core_comercial.custos_eventos(id),
    CONSTRAINT fk_custo_evento_oc FOREIGN KEY (id_ordem_compra) REFERENCES core_vendas_faturamento.ordens_compra(id),
    CONSTRAINT fk_custo_evento_oc_item FOREIGN KEY (id_ordem_compra_item) REFERENCES core_vendas_faturamento.ordens_compra_itens(id),
    CONSTRAINT fk_custo_evento_vinculo FOREIGN KEY (id_vinculo_oc) REFERENCES core_vendas_faturamento.ordens_compra_itens_vinculos(id),
    CONSTRAINT fk_custo_evento_requisicao FOREIGN KEY (id_requisicao) REFERENCES core_vendas_faturamento.requisicoes_compra(id)
);
CREATE INDEX ix_custo_evento_item ON core_comercial.custos_eventos (codigo_empresa, numero_pedido, codigo_produto_item, data_evento);
CREATE INDEX ix_custo_evento_hub ON core_comercial.custos_eventos (id_pedido) WHERE id_pedido IS NOT NULL;
CREATE INDEX ix_custo_evento_oc_item ON core_comercial.custos_eventos (id_ordem_compra_item) WHERE id_ordem_compra_item IS NOT NULL;
CREATE INDEX ix_custo_evento_lote ON core_comercial.custos_eventos (codigo_lote) WHERE codigo_lote IS NOT NULL;
CREATE INDEX ix_custo_evento_parcial ON core_comercial.custos_eventos (id_item_parcial) WHERE id_item_parcial IS NOT NULL;
COMMENT ON COLUMN core_comercial.custos_eventos.codigo_produto_item IS 'Produto (código do Omie) do ITEM DO PEDIDO DE VENDA que recebe o custo. Não confundir com codigo_produto, que é o material comprado (pode ser outro, na fabricação).';
COMMENT ON COLUMN core_comercial.custos_eventos.id_pedido IS 'Só quando o pedido nasceu de proposta (core_comercial.pedidos); nulo no pedido digitado direto no Omie (N16-102).';

CREATE FUNCTION core_comercial.fn_custo_evento_imutavel() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'custos_eventos só recebe INSERT: estorne com um evento de sentido -1.' USING ERRCODE = '23514';
END $$;
CREATE TRIGGER trg_custo_evento_imutavel BEFORE UPDATE OR DELETE ON core_comercial.custos_eventos
  FOR EACH ROW EXECUTE FUNCTION core_comercial.fn_custo_evento_imutavel();

-- Registra um evento de forma idempotente para o item (empresa + pedido + produto). p_extra leva as referências (id_ordem_compra,
-- id_ordem_compra_item, id_vinculo_oc, numero_ordem_compra, id_requisicao, numero_requisicao, codigo_lote, id_lote_mes,
-- id_item_oc_do_lote, id_item_parcial, codigo_parcial, codigo_produto, descricao_material, moeda, cotacao_moeda, cotacao_a_conferir,
-- data_evento). Lote que nasceu de uma OC que já gerou evento para o mesmo item é DESCARTADO (evita contar duas vezes).
CREATE FUNCTION core_comercial.fn_custo_evento_registrar(
    p_empresa uuid, p_numero_pedido varchar, p_produto varchar, p_origem varchar, p_chave varchar, p_qtd_doc numeric,
    p_unid_doc varchar, p_valor_unit numeric, p_valor_total numeric, p_qtd_item_coberta numeric, p_extra jsonb)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE it record; v_id uuid; v_status varchar := 'VALIDO'; v_doc varchar; v_oc_do_lote uuid;
BEGIN
  SELECT * INTO it FROM core_comercial.vw_pedido_produtos
   WHERE codigo_empresa = p_empresa AND numero_pedido = p_numero_pedido AND codigo_produto_omie = p_produto;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ITEM_PEDIDO_NAO_ENCONTRADO: o pedido % não tem o produto % (ou está cancelado).', p_numero_pedido, p_produto USING ERRCODE = 'P0002';
  END IF;
  v_doc := CASE WHEN p_origem = 'LOTE_ESTOQUE' THEN 'LOTE' ELSE 'ORDEM_COMPRA_ITEM' END;
  v_oc_do_lote := nullif(p_extra ->> 'id_item_oc_do_lote', '')::uuid;
  IF p_origem = 'LOTE_ESTOQUE' AND v_oc_do_lote IS NOT NULL AND EXISTS (
       SELECT 1 FROM core_comercial.custos_eventos e
        WHERE e.codigo_empresa = p_empresa AND e.numero_pedido = p_numero_pedido AND e.codigo_produto_item = p_produto
          AND e.id_ordem_compra_item = v_oc_do_lote AND e.status = 'VALIDO' AND e.sentido = 1
          AND NOT EXISTS (SELECT 1 FROM core_comercial.custos_eventos x WHERE x.id_evento_estornado = e.id)) THEN
    v_status := 'DESCARTADO';
  END IF;
  INSERT INTO core_comercial.custos_eventos
    (codigo_empresa, numero_pedido, codigo_produto_item, id_pedido, id_item_pedido, id_item_parcial, codigo_parcial, origem,
     documento_tipo, status, data_evento, codigo_produto, descricao_material, quantidade_documento, unidade_documento,
     quantidade_item_coberta, valor_unitario, valor_total, moeda, cotacao_moeda, cotacao_a_conferir, id_ordem_compra,
     id_ordem_compra_item, id_vinculo_oc, numero_ordem_compra, id_requisicao, numero_requisicao, codigo_lote, id_lote_mes,
     id_item_oc_do_lote, chave_idempotencia)
  VALUES (p_empresa, p_numero_pedido, p_produto, it.id_pedido, it.id_item_pedido, nullif(p_extra ->> 'id_item_parcial','')::uuid,
     p_extra ->> 'codigo_parcial', p_origem, v_doc, v_status,
     coalesce(nullif(p_extra ->> 'data_evento','')::date, current_date), p_extra ->> 'codigo_produto', p_extra ->> 'descricao_material',
     p_qtd_doc, p_unid_doc, CASE WHEN v_status = 'VALIDO' THEN p_qtd_item_coberta ELSE 0 END, p_valor_unit, p_valor_total,
     coalesce(p_extra ->> 'moeda','BRL'), nullif(p_extra ->> 'cotacao_moeda','')::numeric,
     coalesce((p_extra ->> 'cotacao_a_conferir')::boolean, false),
     nullif(p_extra ->> 'id_ordem_compra','')::uuid, nullif(p_extra ->> 'id_ordem_compra_item','')::uuid,
     nullif(p_extra ->> 'id_vinculo_oc','')::uuid, p_extra ->> 'numero_ordem_compra', nullif(p_extra ->> 'id_requisicao','')::uuid,
     p_extra ->> 'numero_requisicao', p_extra ->> 'codigo_lote', nullif(p_extra ->> 'id_lote_mes','')::uuid, v_oc_do_lote, p_chave)
  ON CONFLICT (chave_idempotencia) DO NOTHING
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

-- Estorno: nova linha com os mesmos valores e sentido -1 (OC cancelada, devolução, reserva liberada, pedido cancelado).
CREATE FUNCTION core_comercial.fn_custo_evento_estornar(p_evento uuid, p_motivo text, p_usuario uuid) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE e core_comercial.custos_eventos%ROWTYPE; v_id uuid;
BEGIN
  SELECT * INTO e FROM core_comercial.custos_eventos WHERE id = p_evento;
  IF NOT FOUND OR e.sentido <> 1 OR e.status <> 'VALIDO' THEN
    RAISE EXCEPTION 'EVENTO_NAO_ESTORNAVEL' USING ERRCODE = '23514';
  END IF;
  INSERT INTO core_comercial.custos_eventos
    (codigo_empresa, numero_pedido, codigo_produto_item, id_pedido, id_item_pedido, id_item_parcial, codigo_parcial, origem,
     documento_tipo, sentido, status, data_evento, codigo_produto, descricao_material, quantidade_documento, unidade_documento,
     quantidade_item_coberta, valor_unitario, valor_total, moeda, cotacao_moeda, cotacao_a_conferir, id_ordem_compra,
     id_ordem_compra_item, id_vinculo_oc, numero_ordem_compra, id_requisicao, numero_requisicao, codigo_lote, id_lote_mes,
     id_item_oc_do_lote, id_evento_estornado, motivo, chave_idempotencia, id_usuario)
  VALUES (e.codigo_empresa, e.numero_pedido, e.codigo_produto_item, e.id_pedido, e.id_item_pedido, e.id_item_parcial, e.codigo_parcial,
     e.origem, e.documento_tipo, -1, 'VALIDO', current_date, e.codigo_produto, e.descricao_material, e.quantidade_documento,
     e.unidade_documento, e.quantidade_item_coberta, e.valor_unitario, e.valor_total, e.moeda, e.cotacao_moeda, e.cotacao_a_conferir,
     e.id_ordem_compra, e.id_ordem_compra_item, e.id_vinculo_oc, e.numero_ordem_compra, e.id_requisicao, e.numero_requisicao,
     e.codigo_lote, e.id_lote_mes, e.id_item_oc_do_lote, e.id, p_motivo, 'ESTORNO:' || e.id::text, p_usuario)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

-- Estorna todo o custo vivo de um pedido (empresa + número): o comprado vai ao Estoque. Serve ao pedido do Hub (fn_pedidos_cancelar)
-- e ao pedido digitado no Omie que a pipeline trouxe cancelado (o job chama esta função).
CREATE FUNCTION core_comercial.fn_custo_eventos_estornar_pedido(p_empresa uuid, p_numero_pedido varchar, p_motivo text, p_usuario uuid)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE ev uuid; v_n integer := 0;
BEGIN
  FOR ev IN
    SELECT e.id FROM core_comercial.custos_eventos e
     WHERE e.codigo_empresa = p_empresa AND e.numero_pedido = p_numero_pedido AND e.sentido = 1 AND e.status = 'VALIDO'
       AND NOT EXISTS (SELECT 1 FROM core_comercial.custos_eventos x WHERE x.id_evento_estornado = e.id)
  LOOP
    PERFORM core_comercial.fn_custo_evento_estornar(ev, p_motivo, p_usuario);
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END $$;

-- Eventos "vivos": os de entrada válidos que não foram estornados, e os estornos de sentido -1 entram com sinal.
CREATE VIEW core_comercial.vw_custo_evento_liquido AS
SELECT e.*, e.sentido * e.valor_total AS valor_liquido, e.sentido * e.quantidade_item_coberta AS cobertura_liquida
  FROM core_comercial.custos_eventos e
 WHERE e.status = 'VALIDO';

-- Contrato com a Comissão e o simulador: custo real por item do pedido. Total / quantidade coberta = unitário médio.
CREATE VIEW core_comercial.vw_pedido_item_custo AS
WITH soma AS (
  SELECT codigo_empresa, numero_pedido, codigo_produto_item,
         sum(valor_liquido) AS custo_total, sum(cobertura_liquida) AS coberta_bruta,
         count(*) FILTER (WHERE sentido = 1)::int AS eventos, max(data_evento) AS ultimo_evento_em,
         bool_or(cotacao_a_conferir) AS cotacao_a_conferir
    FROM core_comercial.vw_custo_evento_liquido
   GROUP BY codigo_empresa, numero_pedido, codigo_produto_item
)
SELECT i.codigo_empresa, i.numero_pedido, i.codigo_produto_omie, i.origem_pedido, i.id_pedido, i.id_item_pedido,
       i.quantidade AS quantidade_item,
       least(coalesce(s.coberta_bruta, 0), i.quantidade) AS quantidade_coberta,
       coalesce(s.custo_total, 0)::numeric(15,2) AS custo_total,
       CASE WHEN least(coalesce(s.coberta_bruta, 0), i.quantidade) > 0
            THEN round(s.custo_total / least(s.coberta_bruta, i.quantidade), 6) END AS custo_unitario_medio,
       coalesce(s.coberta_bruta, 0) >= i.quantidade AS completo,
       i.natureza_custo,
       CASE WHEN coalesce(s.coberta_bruta, 0) <= 0 THEN 'SEM_CUSTO'
            WHEN coalesce(s.coberta_bruta, 0) >= i.quantidade THEN 'COMPLETO' ELSE 'PARCIAL' END AS status_custo,
       coalesce(s.eventos, 0) AS eventos,
       s.ultimo_evento_em,
       greatest(coalesce(s.coberta_bruta, 0) - i.quantidade, 0) AS excedente,
       coalesce(s.cotacao_a_conferir, false) AS cotacao_a_conferir,
       i.custo_total_cotado
  FROM core_comercial.vw_pedido_produtos i
  LEFT JOIN soma s ON s.codigo_empresa = i.codigo_empresa AND s.numero_pedido = i.numero_pedido
                  AND s.codigo_produto_item = i.codigo_produto_omie;

CREATE VIEW core_comercial.vw_pedido_custo AS
SELECT codigo_empresa, numero_pedido, origem_pedido, id_pedido, count(*)::int AS itens,
       count(*) FILTER (WHERE completo)::int AS itens_completos,
       sum(custo_total)::numeric(15,2) AS custo_total,
       bool_and(completo) AS completo,
       sum(custo_total_cotado)::numeric(15,2) AS custo_total_cotado
  FROM core_comercial.vw_pedido_item_custo
 GROUP BY codigo_empresa, numero_pedido, origem_pedido, id_pedido;

-- Eventos de uma OC do hub (aprovada, com vínculo a pedido de venda). Idempotente: refaz o que a OC é hoje,
-- estorna o que deixou de valer (OC cancelada ou item/vínculo alterado) e grava o que falta.
-- Vale para qualquer pedido de venda (do Hub ou digitado no Omie): o vínculo já guarda empresa, número e produto (N16-102).
-- Coberta: material igual ao do pedido = quantidade do vínculo; serviço = quantidade do vínculo; fabricação = o que a
-- requisição de matéria-prima informa em quantidade_item_coberta, proporcional ao vínculo; sem isso, 0.
-- Natureza: a do item da proposta quando o pedido nasceu no Hub; senão, serviço pelo tipo do item da OC e fabricação quando a
-- requisição de matéria-prima informa a cobertura.
CREATE FUNCTION core_comercial.fn_custo_evento_sincronizar_oc(p_oc uuid) RETURNS integer LANGUAGE plpgsql AS $$
DECLARE r record; v_n integer := 0; v_desejado boolean; v_ev uuid; v_chave varchar; it record; v_rq_cob numeric;
        v_oc core_vendas_faturamento.ordens_compra%ROWTYPE; v_cob numeric; v_liq numeric; v_origem varchar;
BEGIN
  SELECT * INTO v_oc FROM core_vendas_faturamento.ordens_compra WHERE id = p_oc;
  IF NOT FOUND THEN RETURN 0; END IF;
  v_desejado := v_oc.status = 'aprovado' AND v_oc.deleted_at IS NULL;

  FOR r IN
    SELECT v.id AS id_vinculo, v.numero_pedido_venda, v.codigo_empresa_pv, v.codigo_produto_pv, v.quantidade AS qtd_vinculo,
           i.id AS id_item_oc, i.codigo_produto, i.descricao_produto, i.quantidade AS qtd_item, i.unidade_medida, i.valor_unitario,
           i.desconto, i.tipo_item, i.id_requisicao
      FROM core_vendas_faturamento.ordens_compra_itens_vinculos v
      JOIN core_vendas_faturamento.ordens_compra_itens i ON i.id = v.id_ordem_compra_item
     WHERE v.id_ordem_compra = p_oc
  LOOP
    v_liq := round(r.qtd_vinculo * r.valor_unitario * (1 - coalesce(r.desconto, 0) / 100) * coalesce(v_oc.cotacao_moeda, 1), 2);
    v_chave := 'OC:' || r.id_vinculo::text || ':' || v_liq::text || ':' || r.qtd_vinculo::text;
    SELECT * INTO it FROM core_comercial.vw_pedido_produtos
     WHERE codigo_empresa = r.codigo_empresa_pv AND numero_pedido = r.numero_pedido_venda AND codigo_produto_omie = r.codigo_produto_pv;
    IF FOUND AND v_desejado THEN
      SELECT rq.quantidade_item_coberta INTO v_rq_cob FROM core_vendas_faturamento.requisicoes_compra rq WHERE rq.id = r.id_requisicao;
      v_origem := CASE WHEN it.natureza_custo = 'SERVICO' OR r.tipo_item = 'SERVICO' THEN 'MAO_DE_OBRA_OC_SERVICO'
                       WHEN it.natureza_custo = 'FABRICACAO' OR (it.origem_pedido = 'OMIE' AND v_rq_cob IS NOT NULL)
                            THEN 'MATERIA_PRIMA_FABRICACAO'
                       ELSE 'OC_MATERIAL' END;
      v_cob := CASE WHEN v_origem = 'MATERIA_PRIMA_FABRICACAO'
                    THEN coalesce(v_rq_cob * r.qtd_vinculo / nullif(r.qtd_item, 0), 0)
                    ELSE r.qtd_vinculo END;
      v_ev := core_comercial.fn_custo_evento_registrar(
        r.codigo_empresa_pv, r.numero_pedido_venda, r.codigo_produto_pv, v_origem, v_chave,
        r.qtd_vinculo, r.unidade_medida, round(v_liq / r.qtd_vinculo, 6), v_liq, v_cob,
        jsonb_build_object('id_ordem_compra', p_oc, 'id_ordem_compra_item', r.id_item_oc, 'id_vinculo_oc', r.id_vinculo,
          'numero_ordem_compra', v_oc.numero_pedido, 'id_requisicao', r.id_requisicao, 'codigo_produto', r.codigo_produto,
          'descricao_material', r.descricao_produto, 'moeda', v_oc.moeda, 'cotacao_moeda', v_oc.cotacao_moeda,
          'cotacao_a_conferir', coalesce(v_oc.cotacao_origem = 'manual', false),
          'data_evento', coalesce(v_oc.aprovado_em, v_oc.created_at)::date));
      IF v_ev IS NOT NULL THEN v_n := v_n + 1; END IF;
    END IF;
    -- estorna os eventos deste vínculo que já não correspondem à chave de hoje (ou cujo pedido sumiu ou foi cancelado)
    FOR v_ev IN
      SELECT e.id FROM core_comercial.custos_eventos e
       WHERE e.id_vinculo_oc = r.id_vinculo AND e.sentido = 1 AND e.status = 'VALIDO'
         AND NOT EXISTS (SELECT 1 FROM core_comercial.custos_eventos x WHERE x.id_evento_estornado = e.id)
         AND (NOT v_desejado OR it IS NULL OR e.chave_idempotencia <> v_chave)
    LOOP
      PERFORM core_comercial.fn_custo_evento_estornar(v_ev, CASE WHEN v_desejado THEN 'OC alterada' ELSE 'OC cancelada' END, NULL);
      v_n := v_n + 1;
    END LOOP;
  END LOOP;
  RETURN v_n;
END $$;

-- Eventos de lote para um item do pedido, a partir do que o MES informa (lotes[] do GET /itens/custo, LOG-47: item = produto).
-- p_lotes: [{codigo_lote, id_lote_mes, quantidade, custo_unitario, id_item_oc, id_item_parcial, codigo_parcial, data, ativo}]
-- Lote com ativo=false (reserva liberada) estorna o evento que já existia.
CREATE FUNCTION core_comercial.fn_custo_evento_registrar_lotes(p_empresa uuid, p_numero_pedido varchar, p_produto varchar, p_lotes jsonb)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE l jsonb; v_n integer := 0; v_ev uuid; v_chave varchar; v_qtd numeric; v_cu numeric; v_unid varchar;
BEGIN
  SELECT coalesce(
           (SELECT i.unidade_medida FROM core_comercial.vw_pedido_produtos v JOIN core_comercial.pedidos_itens i ON i.id = v.id_item_pedido
             WHERE v.codigo_empresa = p_empresa AND v.numero_pedido = p_numero_pedido AND v.codigo_produto_omie = p_produto),
           (SELECT it.unidade_medida FROM core_vendas_faturamento.pedidos_vendas pv
              JOIN core_vendas_faturamento.produto_vendas it ON it.codigo_empresa = pv.codigo_empresa AND it.codigo_pedido_omie = pv.codigo_pedido_omie
             WHERE pv.codigo_empresa = p_empresa AND pv.numero_pedido = p_numero_pedido AND it.codigo_produto_omie = p_produto
               AND it.unidade_medida IS NOT NULL LIMIT 1),
           'UN') INTO v_unid;
  FOR l IN SELECT * FROM jsonb_array_elements(p_lotes) LOOP
    v_qtd := (l ->> 'quantidade')::numeric; v_cu := (l ->> 'custo_unitario')::numeric;
    CONTINUE WHEN v_qtd IS NULL OR v_qtd <= 0 OR v_cu IS NULL;
    v_chave := 'LOTE:' || p_empresa::text || ':' || p_numero_pedido || ':' || p_produto || ':' || (l ->> 'codigo_lote') || ':'
               || coalesce(l ->> 'id_item_parcial','') || ':' || v_qtd::text || ':' || v_cu::text;
    IF coalesce((l ->> 'ativo')::boolean, true) THEN
      v_ev := core_comercial.fn_custo_evento_registrar(p_empresa, p_numero_pedido, p_produto, 'LOTE_ESTOQUE', v_chave, v_qtd, v_unid,
        v_cu, round(v_qtd * v_cu, 2), v_qtd,
        jsonb_build_object('codigo_lote', l ->> 'codigo_lote', 'id_lote_mes', l ->> 'id_lote_mes', 'id_item_oc_do_lote', l ->> 'id_item_oc',
          'id_item_parcial', l ->> 'id_item_parcial', 'codigo_parcial', l ->> 'codigo_parcial', 'data_evento', l ->> 'data'));
      IF v_ev IS NOT NULL THEN v_n := v_n + 1; END IF;
    END IF;
    FOR v_ev IN
      SELECT e.id FROM core_comercial.custos_eventos e
       WHERE e.codigo_empresa = p_empresa AND e.numero_pedido = p_numero_pedido AND e.codigo_produto_item = p_produto
         AND e.codigo_lote = l ->> 'codigo_lote' AND e.origem = 'LOTE_ESTOQUE'
         AND e.sentido = 1 AND e.status = 'VALIDO' AND coalesce(e.id_item_parcial::text,'') = coalesce(l ->> 'id_item_parcial','')
         AND NOT EXISTS (SELECT 1 FROM core_comercial.custos_eventos x WHERE x.id_evento_estornado = e.id)
         AND (NOT coalesce((l ->> 'ativo')::boolean, true) OR e.chave_idempotencia <> v_chave)
    LOOP
      PERFORM core_comercial.fn_custo_evento_estornar(v_ev, CASE WHEN coalesce((l ->> 'ativo')::boolean, true) THEN 'custo ou quantidade do lote mudou' ELSE 'reserva liberada' END, NULL);
      v_n := v_n + 1;
    END LOOP;
  END LOOP;
  RETURN v_n;
END $$;

-- ───────────────────────── pedido de aprovação do vendedor: compra acima do valor da proposta (C8)

-- Uma linha por produto (item do pedido) e por OC. Sem tolerância: qualquer valor acima gera a linha (N16-63).
-- Compara a COMPRA com o CUSTO que o vendedor pôs (N16-60: "o vendedor pôs 10 e Compras pôs 20"), não com o preço de venda.
-- Vale para o pedido do Hub e para o digitado no Omie (N16-102). Só o vendedor dono do item aprova ou reprova. Reprovada,
-- Compras leva o caso à Gerência FISICAMENTE (N16-66): o sistema não tem botão da Gerência. Compras registra a solução e o
-- vendedor é notificado (N16-67, N16-73).
CREATE TABLE core_comercial.divergencias_compra (
    id                       uuid DEFAULT uuidv7() NOT NULL,
    codigo_empresa           uuid NOT NULL,
    numero_pedido            varchar(15) NOT NULL,
    codigo_produto_item      varchar(60) NOT NULL,
    id_pedido                uuid,
    id_vendedor              uuid NOT NULL,
    id_ordem_compra          uuid,
    numero_ordem_compra      varchar(30),
    valor_proposta           numeric(15,2) NOT NULL,
    valor_compra             numeric(15,2) NOT NULL,
    diferenca                numeric(15,2) GENERATED ALWAYS AS (valor_compra - valor_proposta) STORED,
    margem_atual_pct         numeric(9,4),
    margem_considerada_pct   numeric(9,4),
    fornecedor               varchar(200),
    prazo_entrega            varchar(60),
    condicao_pagamento       varchar(200),
    motivo                   text NOT NULL,
    estado                   varchar(10) DEFAULT 'PENDENTE' NOT NULL,
    criado_por               uuid,
    criado_em                timestamptz DEFAULT now() NOT NULL,
    decidido_por             uuid,
    decidido_em              timestamptz,
    assumido_por             uuid,
    assumido_em              timestamptz,
    solucao_tipo             varchar(20),
    solucao_texto            text,
    resolvido_por            uuid,
    resolvido_em             timestamptz,
    CONSTRAINT pk_divergencia_compra PRIMARY KEY (id),
    CONSTRAINT ck_divergencia_estado CHECK (estado IN ('PENDENTE','APROVADO','REPROVADO','RESOLVIDO')),
    CONSTRAINT ck_divergencia_acima CHECK (valor_compra > valor_proposta),
    CONSTRAINT ck_divergencia_motivo CHECK (length(btrim(motivo)) >= 3),
    CONSTRAINT ck_divergencia_solucao CHECK (solucao_tipo IS NULL OR solucao_tipo IN ('NOVO_VALOR','NOVO_FORNECEDOR','MANTIDO','PEDIDO_CANCELADO')),
    CONSTRAINT ck_divergencia_resolvido CHECK ((estado = 'RESOLVIDO') = (resolvido_em IS NOT NULL AND solucao_tipo IS NOT NULL AND length(btrim(coalesce(solucao_texto,''))) >= 3)),
    CONSTRAINT ck_divergencia_decisao CHECK ((estado = 'PENDENTE') = (decidido_em IS NULL)),
    CONSTRAINT fk_divergencia_empresa FOREIGN KEY (codigo_empresa) REFERENCES core.unidades(id),
    CONSTRAINT fk_divergencia_pedido FOREIGN KEY (id_pedido) REFERENCES core_comercial.pedidos(id),
    CONSTRAINT fk_divergencia_vendedor FOREIGN KEY (id_vendedor) REFERENCES auth.usuarios(id),
    CONSTRAINT fk_divergencia_oc FOREIGN KEY (id_ordem_compra) REFERENCES core_vendas_faturamento.ordens_compra(id)
);
-- Uma divergência em aberto por produto e OC.
CREATE UNIQUE INDEX uq_divergencia_aberta ON core_comercial.divergencias_compra (codigo_empresa, numero_pedido, codigo_produto_item, id_ordem_compra) WHERE estado <> 'RESOLVIDO';
CREATE INDEX ix_divergencia_vendedor ON core_comercial.divergencias_compra (id_vendedor, estado);
CREATE INDEX ix_divergencia_reprovadas ON core_comercial.divergencias_compra (criado_em) WHERE estado = 'REPROVADO';
COMMENT ON TABLE core_comercial.divergencias_compra IS 'Compra por valor acima do custo que o vendedor pôs (nó C8). O vendedor dono do item aprova ou reprova em Meus Pedidos, sem tempo limite; reprovada, Compras leva o caso à Gerência fisicamente, registra a solução e o vendedor é notificado. O preço do cliente não muda (N16-17); aprovada, a margem e a comissão caem.';
COMMENT ON COLUMN core_comercial.divergencias_compra.valor_proposta IS 'Custo que o vendedor pôs para a quantidade do item (custo × quantidade do item do pedido): copiado da proposta, ou preenchido por ele no pedido do Omie (N16-106).';
COMMENT ON COLUMN core_comercial.divergencias_compra.margem_atual_pct IS 'Margem do simulador (a da proposta). Aparece no aviso ao vendedor ao lado da margem considerada.';
COMMENT ON COLUMN core_comercial.divergencias_compra.margem_considerada_pct IS 'Margem recalculada com o valor real da compra.';
COMMENT ON COLUMN core_comercial.divergencias_compra.criado_em IS 'Início do cronômetro da divergência (N16-58, N16-73: o tempo parado é medido, sem prazo fixo).';
COMMENT ON COLUMN core_comercial.divergencias_compra.assumido_por IS 'Quem de Compras assumiu o caso reprovado.';

-- Compras registra a divergência e o vendedor do pedido é notificado. Vale igual para as duas origens (N16-106): o custo do
-- vendedor está no item do pedido. Pedido do Omie que o job ainda não trouxe, ou item sem o custo do vendedor, não dá para comparar.
CREATE FUNCTION core_comercial.fn_divergencia_registrar(
    p_empresa uuid, p_numero_pedido varchar, p_produto varchar, p_oc uuid, p_valor_compra numeric, p_motivo text, p_usuario uuid,
    p_margem_atual numeric DEFAULT NULL, p_margem_considerada numeric DEFAULT NULL,
    p_fornecedor varchar DEFAULT NULL, p_prazo varchar DEFAULT NULL, p_condicao varchar DEFAULT NULL, p_numero_oc varchar DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE it record; v_vend uuid; v_valor numeric; v_id uuid;
BEGIN
  IF p_motivo IS NULL OR length(btrim(p_motivo)) < 3 THEN
    RAISE EXCEPTION 'MOTIVO_OBRIGATORIO: Compras escreve o motivo da divergência.' USING ERRCODE = '23514';
  END IF;
  IF EXISTS (SELECT 1 FROM core_comercial.pedidos WHERE codigo_empresa = p_empresa AND numero_pedido_omie = p_numero_pedido
                AND cancelado_em IS NOT NULL) THEN
    RAISE EXCEPTION 'PEDIDO_CANCELADO' USING ERRCODE = '23514';
  END IF;
  SELECT * INTO it FROM core_comercial.vw_pedido_produtos
   WHERE codigo_empresa = p_empresa AND numero_pedido = p_numero_pedido AND codigo_produto_omie = p_produto;
  IF NOT FOUND THEN RAISE EXCEPTION 'ITEM_NAO_ENCONTRADO' USING ERRCODE = 'P0002'; END IF;
  IF it.id_pedido IS NULL THEN
    RAISE EXCEPTION 'PEDIDO_NAO_IMPORTADO: o pedido % ainda não foi trazido do Omie para o Hub.', p_numero_pedido USING ERRCODE = '23514';
  END IF;
  SELECT id_usuario_vendedor INTO v_vend FROM core_comercial.pedidos WHERE id = it.id_pedido;
  IF v_vend IS NULL THEN RAISE EXCEPTION 'VENDEDOR_NAO_ENCONTRADO' USING ERRCODE = 'P0002'; END IF;
  v_valor := it.custo_total_cotado;
  IF v_valor IS NULL THEN
    RAISE EXCEPTION 'SEM_CUSTO_DO_VENDEDOR: o vendedor ainda não preencheu a parte de compras deste item.' USING ERRCODE = '23514';
  END IF;
  IF p_valor_compra IS NULL OR p_valor_compra <= v_valor THEN
    RAISE EXCEPTION 'COMPRA_NAO_ESTA_ACIMA: o valor da compra (%) não passa do custo do vendedor (%). Compra mais barata é só informativa.', p_valor_compra, v_valor USING ERRCODE = '23514';
  END IF;
  INSERT INTO core_comercial.divergencias_compra
    (codigo_empresa, numero_pedido, codigo_produto_item, id_pedido, id_vendedor, id_ordem_compra, numero_ordem_compra, valor_proposta,
     valor_compra, margem_atual_pct, margem_considerada_pct, fornecedor, prazo_entrega, condicao_pagamento, motivo, criado_por)
  VALUES (p_empresa, p_numero_pedido, p_produto, it.id_pedido, v_vend, p_oc, p_numero_oc, v_valor, p_valor_compra,
     p_margem_atual, p_margem_considerada, p_fornecedor, p_prazo, p_condicao, btrim(p_motivo), p_usuario)
  RETURNING id INTO v_id;
  INSERT INTO core_comercial.notificacoes (id_usuario, tipo, titulo, link)
  VALUES (v_vend, 'COMPRA_ACIMA_DO_VALOR', 'Compra acima do valor da proposta: aprove ou reprove', '/vendas/meus-pedidos');
  RETURN v_id;
END $$;

-- O vendedor dono do item aprova ou reprova (N16-60, N16-61). Aprovada: a compra segue, margem e comissão caem (o recálculo é
-- da comissão, por evento de custo). Reprovada: entra na lista de Compras.
CREATE FUNCTION core_comercial.fn_divergencia_decidir(p_id uuid, p_usuario uuid, p_aprovar boolean)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d core_comercial.divergencias_compra%ROWTYPE;
BEGIN
  SELECT * INTO d FROM core_comercial.divergencias_compra WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'DIVERGENCIA_NAO_ENCONTRADA' USING ERRCODE = 'P0002'; END IF;
  IF d.id_vendedor <> p_usuario THEN
    RAISE EXCEPTION 'SO_O_VENDEDOR_DO_ITEM: só o vendedor dono do produto aprova ou reprova.' USING ERRCODE = '42501';
  END IF;
  IF d.estado <> 'PENDENTE' THEN
    RAISE EXCEPTION 'TRANSICAO_INVALIDA: a divergência está %.', d.estado USING ERRCODE = '23514';
  END IF;
  UPDATE core_comercial.divergencias_compra
     SET estado = CASE WHEN p_aprovar THEN 'APROVADO' ELSE 'REPROVADO' END, decidido_por = p_usuario, decidido_em = now()
   WHERE id = p_id;
END $$;

-- Compras assume um caso reprovado (a lista de reprovados com a idade de cada um, N16-73).
CREATE FUNCTION core_comercial.fn_divergencia_assumir(p_id uuid, p_usuario uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE core_comercial.divergencias_compra SET assumido_por = p_usuario, assumido_em = now()
   WHERE id = p_id AND estado = 'REPROVADO';
  IF NOT FOUND THEN RAISE EXCEPTION 'TRANSICAO_INVALIDA: só se assume uma divergência reprovada.' USING ERRCODE = '23514'; END IF;
END $$;

-- Compras registra a solução (novo valor, novo fornecedor, mantido ou pedido cancelado) e o vendedor é notificado (N16-67).
CREATE FUNCTION core_comercial.fn_divergencia_resolver(p_id uuid, p_usuario uuid, p_solucao_tipo varchar, p_solucao_texto text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d core_comercial.divergencias_compra%ROWTYPE;
BEGIN
  SELECT * INTO d FROM core_comercial.divergencias_compra WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'DIVERGENCIA_NAO_ENCONTRADA' USING ERRCODE = 'P0002'; END IF;
  IF d.estado <> 'REPROVADO' THEN
    RAISE EXCEPTION 'TRANSICAO_INVALIDA: a solução só se registra numa divergência reprovada (estado %).', d.estado USING ERRCODE = '23514';
  END IF;
  IF p_solucao_texto IS NULL OR length(btrim(p_solucao_texto)) < 3 THEN
    RAISE EXCEPTION 'MOTIVO_OBRIGATORIO: Compras escreve a solução.' USING ERRCODE = '23514';
  END IF;
  UPDATE core_comercial.divergencias_compra
     SET estado = 'RESOLVIDO', solucao_tipo = p_solucao_tipo, solucao_texto = btrim(p_solucao_texto),
         resolvido_por = p_usuario, resolvido_em = now()
   WHERE id = p_id;
  INSERT INTO core_comercial.notificacoes (id_usuario, tipo, titulo, link)
  VALUES (d.id_vendedor, 'COMPRA_ACIMA_RESOLVIDA', 'Compras resolveu a compra acima do valor: veja a solução', '/vendas/meus-pedidos');
END $$;

-- Cancela o pedido de venda do Hub (N16-68 a N16-71). Motivo obrigatório; pedido faturado não se cancela por aqui (o abatimento da
-- comissão e o saldo seguem regras próprias: LOG-56 R62). O que já foi comprado vai ao Estoque e deixa de ser custo do pedido:
-- os eventos de custo válidos são estornados. As divergências abertas viram RESOLVIDO com a solução PEDIDO_CANCELADO.
-- A API, na mesma transação, cancela a requisição do PCP e a OC não emitida e avisa o PCP e a OC (outro schema).
-- O pedido digitado direto no Omie é cancelado no Omie; quando a pipeline o traz cancelado, o job chama
-- fn_custo_eventos_estornar_pedido e resolve as divergências abertas do mesmo jeito.
CREATE FUNCTION core_comercial.fn_pedidos_cancelar(p_pedido uuid, p_usuario uuid, p_motivo text, p_faturado boolean DEFAULT false)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE pv core_comercial.pedidos%ROWTYPE; v_n integer := 0; v_vend uuid;
BEGIN
  IF p_motivo IS NULL OR length(btrim(p_motivo)) < 3 THEN
    RAISE EXCEPTION 'MOTIVO_OBRIGATORIO: informe o motivo do cancelamento.' USING ERRCODE = '23514';
  END IF;
  IF p_faturado THEN
    RAISE EXCEPTION 'PEDIDO_FATURADO: pedido faturado não se cancela por esta função; o que vale é o abatimento da comissão e o saldo.' USING ERRCODE = '23514';
  END IF;
  SELECT * INTO pv FROM core_comercial.pedidos WHERE id = p_pedido FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PEDIDO_NAO_ENCONTRADO' USING ERRCODE = 'P0002'; END IF;
  IF pv.origem = 'OMIE' THEN
    RAISE EXCEPTION 'PEDIDO_DO_OMIE: o pedido digitado no Omie se cancela no Omie; a sincronização traz o cancelamento (N16-106).' USING ERRCODE = '23514';
  END IF;
  IF pv.cancelado_em IS NOT NULL THEN
    RAISE EXCEPTION 'TRANSICAO_INVALIDA: o pedido já está cancelado.' USING ERRCODE = '23514';
  END IF;
  UPDATE core_comercial.pedidos
     SET cancelado_em = now(), cancelado_por = p_usuario, motivo_cancelamento = btrim(p_motivo), updated_by = p_usuario, updated_at = now()
   WHERE id = p_pedido;
  -- Comprado vai ao Estoque: deixa de ser custo do pedido (só existe custo depois que o pedido tem número do Omie).
  IF pv.numero_pedido_omie IS NOT NULL THEN
    v_n := core_comercial.fn_custo_eventos_estornar_pedido(pv.codigo_empresa, pv.numero_pedido_omie,
             'pedido cancelado: ' || btrim(p_motivo), p_usuario);
    UPDATE core_comercial.divergencias_compra
       SET estado = 'RESOLVIDO', solucao_tipo = 'PEDIDO_CANCELADO', solucao_texto = 'Pedido cancelado: ' || btrim(p_motivo),
           resolvido_por = p_usuario, resolvido_em = now(), decidido_em = coalesce(decidido_em, now())
     WHERE codigo_empresa = pv.codigo_empresa AND numero_pedido = pv.numero_pedido_omie AND estado <> 'RESOLVIDO';
  END IF;
  IF pv.id_proposta IS NOT NULL THEN
    SELECT id_responsavel INTO v_vend FROM core_comercial.propostas WHERE id = pv.id_proposta;
    IF v_vend IS NOT NULL THEN
      INSERT INTO core_comercial.notificacoes (id_usuario, tipo, titulo, link)
      VALUES (v_vend, 'PEDIDO_CANCELADO', 'Pedido cancelado: ' || btrim(p_motivo), '/vendas/meus-pedidos');
    END IF;
  END IF;
  RETURN v_n;
END $$;
COMMENT ON FUNCTION core_comercial.fn_pedidos_cancelar(uuid, uuid, text, boolean) IS 'Devolve quantos eventos de custo foram estornados. A comissão estimada vira histórico (fn do core_comissao chamada pela API) e a pipeline chama o Omie (CancelarPedidoVenda ou ExcluirPedido, a decidir no teste) depois de gravar o cancelamento; quem cancela é o vendedor.';


-- ───────────────────────── E) core_vendas_faturamento: o que a pipeline e o Hub precisam (tabelas da pipeline)

-- (antigo anexo 0002) Item da OC: mercadoria ou serviço (mão de obra). Não reutiliza tipo_material, que o MES lê.
ALTER TABLE core_vendas_faturamento.ordens_compra_itens
  ADD COLUMN IF NOT EXISTS tipo_item varchar(10) DEFAULT 'MERCADORIA' NOT NULL;
ALTER TABLE core_vendas_faturamento.ordens_compra_itens
  ADD CONSTRAINT ck_ordens_compra_itens_tipo_item CHECK (tipo_item IN ('MERCADORIA','SERVICO'));
-- Requisição de matéria-prima: a que item do pedido e a que parcial (5.01, 5.02…) ela serve e quanto do item cobre.
ALTER TABLE core_vendas_faturamento.requisicoes_compra
  ADD COLUMN IF NOT EXISTS codigo_item_omie bigint,
  ADD COLUMN IF NOT EXISTS id_item_parcial uuid,
  ADD COLUMN IF NOT EXISTS codigo_parcial varchar(20),
  ADD COLUMN IF NOT EXISTS quantidade_item_coberta numeric(15,4);
ALTER TABLE core_vendas_faturamento.requisicoes_compra
  ADD CONSTRAINT ck_requisicoes_compra_cobertura CHECK (quantidade_item_coberta IS NULL OR quantidade_item_coberta >= 0);

-- SQL-019: condições de pagamento de VENDA do Omie (ListarParcelas), uma lista por conta (molde de condicoes_pagamento_compras).
CREATE TABLE core_vendas_faturamento.condicoes_pagamento_vendas (
    id                  uuid DEFAULT uuidv7() NOT NULL,
    codigo_empresa      uuid NOT NULL,
    codigo_omie         varchar(3) NOT NULL,
    descricao           varchar(200) NOT NULL,
    quantidade_parcelas integer,
    informar_parcelas   boolean DEFAULT false NOT NULL,
    dias_descricao      varchar(100),
    ativo               boolean DEFAULT true NOT NULL,
    created_at          timestamptz DEFAULT now() NOT NULL,
    updated_at          timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_condicoes_pagamento_vendas PRIMARY KEY (id),
    CONSTRAINT uq_condicoes_pagamento_vendas UNIQUE (codigo_empresa, codigo_omie),
    CONSTRAINT ck_condicoes_pagamento_vendas_codigo CHECK (char_length(codigo_omie) = 3),
    CONSTRAINT ck_condicoes_pagamento_vendas_999 CHECK (NOT informar_parcelas OR codigo_omie = '999'),
    CONSTRAINT fk_condicoes_pagamento_vendas_unidade FOREIGN KEY (codigo_empresa) REFERENCES core.unidades(id) ON UPDATE CASCADE ON DELETE RESTRICT
);
CREATE TRIGGER trg_condicoes_pagamento_vendas_updated_at BEFORE UPDATE ON core_vendas_faturamento.condicoes_pagamento_vendas
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TABLE core_vendas_faturamento.condicoes_pagamento_vendas IS 'SQL-019. Mantida pela pipeline (ListarParcelas, uma lista por conta Omie). A descrição não é cortada (passa de 30 caracteres). dias_descricao são os dias INFERIDOS da descrição só nos formatos exatos "45/55/65/80", "A Vista/15/30", "Para N dias"; nulo para "N Parcelas" e para 999.';

-- N16-83: cenários de impostos do Omie (ListarCenarios), por conta. O CFOP já está no Hub; o cenário se escolhe na proposta.
CREATE TABLE core_vendas_faturamento.cenarios_impostos (
    id                  uuid DEFAULT uuidv7() NOT NULL,
    codigo_empresa      uuid NOT NULL,
    codigo_omie         bigint NOT NULL,
    nome                varchar(60) NOT NULL,
    padrao              boolean DEFAULT false NOT NULL,
    industria           boolean DEFAULT false NOT NULL,
    comercio_varejista  boolean DEFAULT false NOT NULL,
    comercio_atacadista boolean DEFAULT false NOT NULL,
    prestador_servico   boolean DEFAULT false NOT NULL,
    construcao_civil    boolean DEFAULT false NOT NULL,
    ativo               boolean DEFAULT true NOT NULL,
    created_at          timestamptz DEFAULT now() NOT NULL,
    updated_at          timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_cenarios_impostos PRIMARY KEY (id),
    CONSTRAINT uq_cenarios_impostos UNIQUE (codigo_empresa, codigo_omie),
    CONSTRAINT fk_cenarios_impostos_unidade FOREIGN KEY (codigo_empresa) REFERENCES core.unidades(id) ON UPDATE CASCADE ON DELETE RESTRICT
);
CREATE TRIGGER trg_cenarios_impostos_updated_at BEFORE UPDATE ON core_vendas_faturamento.cenarios_impostos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- N16-99, N16-100: a TERCEIRA TABELA que liga a linha de item de cada sequencial à linha do item do original.
-- Não altera produto_vendas. No Omie o sequencial recebe códigos de linha NOVOS; o original zerado mantém as linhas com quantidade 0.
CREATE TABLE core_vendas_faturamento.pedidos_vendas_sequenciais_itens (
    id                         uuid DEFAULT uuidv7() NOT NULL,
    codigo_empresa             uuid NOT NULL,
    numero_pedido              varchar(15) NOT NULL,
    sequencial                 numeric(4,0) NOT NULL,
    codigo_pedido_omie         bigint NOT NULL,
    codigo_item_omie           bigint NOT NULL,
    codigo_item_omie_original  bigint,
    codigo_produto_omie        varchar(60) NOT NULL,
    quantidade                 numeric(15,4),
    valor_total                numeric(15,2),
    origem_vinculo             varchar(11) NOT NULL,
    created_at                 timestamptz DEFAULT now() NOT NULL,
    updated_at                 timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_pedidos_vendas_sequenciais_itens PRIMARY KEY (id),
    CONSTRAINT uq_pedidos_vendas_sequenciais_itens UNIQUE (codigo_empresa, numero_pedido, sequencial, codigo_item_omie),
    CONSTRAINT ck_pedidos_vendas_sequenciais_itens_seq CHECK (sequencial >= 1),
    CONSTRAINT ck_pedidos_vendas_sequenciais_itens_orig CHECK (origem_vinculo IN ('HUB','PRODUTO','AMBIGUO','SEM_VINCULO')),
    CONSTRAINT ck_pedidos_vendas_sequenciais_itens_vinc CHECK ((origem_vinculo IN ('HUB','PRODUTO')) = (codigo_item_omie_original IS NOT NULL)),
    CONSTRAINT fk_pedidos_vendas_sequenciais_itens_unidade FOREIGN KEY (codigo_empresa) REFERENCES core.unidades(id) ON UPDATE CASCADE ON DELETE RESTRICT
);
CREATE INDEX ix_pedidos_vendas_sequenciais_itens_item ON core_vendas_faturamento.pedidos_vendas_sequenciais_itens (codigo_empresa, codigo_item_omie);
CREATE TRIGGER trg_pedidos_vendas_sequenciais_itens_updated_at BEFORE UPDATE ON core_vendas_faturamento.pedidos_vendas_sequenciais_itens
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON COLUMN core_vendas_faturamento.pedidos_vendas_sequenciais_itens.origem_vinculo IS 'HUB = quebra feita no Hub (ligação exata); PRODUTO = inferida: o produto aparece em UMA linha do original; AMBIGUO = o produto aparece em mais de uma linha do original; SEM_VINCULO = nenhuma linha do original tem o produto.';

-- Preenchimento do histórico (idempotente): liga cada linha de item de sequencial ao original pela família (empresa + numero_pedido) e pelo produto.
INSERT INTO core_vendas_faturamento.pedidos_vendas_sequenciais_itens
  (codigo_empresa, numero_pedido, sequencial, codigo_pedido_omie, codigo_item_omie, codigo_item_omie_original, codigo_produto_omie, quantidade, valor_total, origem_vinculo)
SELECT s.codigo_empresa, s.numero_pedido, s.sequencial, s.codigo_pedido_omie, i.codigo_item_omie,
       CASE WHEN c.n = 1 THEN c.unico END, i.codigo_produto_omie, i.quantidade::numeric(15,4), i.valor_total,
       CASE WHEN c.n = 1 THEN 'PRODUTO' WHEN c.n > 1 THEN 'AMBIGUO' ELSE 'SEM_VINCULO' END
  FROM core_vendas_faturamento.pedidos_vendas s
  JOIN core_vendas_faturamento.produto_vendas i
    ON i.codigo_empresa = s.codigo_empresa AND i.codigo_pedido_omie = s.codigo_pedido_omie AND i.deleted_at IS NULL AND i.codigo_item_omie IS NOT NULL
  LEFT JOIN LATERAL (
        SELECT count(*)::int AS n, min(oi.codigo_item_omie) AS unico
          FROM core_vendas_faturamento.pedidos_vendas o
          JOIN core_vendas_faturamento.produto_vendas oi
            ON oi.codigo_empresa = o.codigo_empresa AND oi.codigo_pedido_omie = o.codigo_pedido_omie AND oi.deleted_at IS NULL
           AND oi.codigo_produto_omie = i.codigo_produto_omie AND oi.codigo_item_omie IS NOT NULL
         WHERE o.codigo_empresa = s.codigo_empresa AND o.numero_pedido = s.numero_pedido
           AND coalesce(o.sequencial, 0) = 0 AND o.deleted_at IS NULL) c ON true
 WHERE coalesce(s.sequencial, 0) > 0 AND s.deleted_at IS NULL
ON CONFLICT (codigo_empresa, numero_pedido, sequencial, codigo_item_omie) DO NOTHING;

-- Normalização: o original com sequencial nulo passa a 0 (hoje não há nulo; o índice único trata NULL e 0 como pedidos diferentes).
UPDATE core_vendas_faturamento.pedidos_vendas SET sequencial = 0 WHERE sequencial IS NULL;

-- A família do pedido: uma linha por item, com o papel (original ou sequencial), sem cascas (quantidade 0) e sem pedido cancelado.
CREATE VIEW core_vendas_faturamento.vw_pedido_itens_familia AS
SELECT p.codigo_empresa, p.numero_pedido, coalesce(p.sequencial, 0)::int AS sequencial,
       CASE WHEN coalesce(p.sequencial, 0) = 0 THEN 'ORIGINAL' ELSE 'SEQUENCIAL' END AS papel,
       p.codigo_pedido_omie, p.faturado, i.codigo_item_omie, i.codigo_produto_omie, i.quantidade, i.valor_total,
       s.codigo_item_omie_original, s.origem_vinculo
  FROM core_vendas_faturamento.pedidos_vendas p
  JOIN core_vendas_faturamento.produto_vendas i
    ON i.codigo_empresa = p.codigo_empresa AND i.codigo_pedido_omie = p.codigo_pedido_omie AND i.deleted_at IS NULL
  LEFT JOIN core_vendas_faturamento.pedidos_vendas_sequenciais_itens s
    ON s.codigo_empresa = i.codigo_empresa AND s.codigo_item_omie = i.codigo_item_omie
 WHERE p.deleted_at IS NULL AND NOT p.cancelado AND coalesce(i.quantidade, 0) > 0;

COMMIT;
