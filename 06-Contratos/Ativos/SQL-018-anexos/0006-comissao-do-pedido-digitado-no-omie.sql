-- SQL-018 · anexo 0006 · a comissão NOVA também para o pedido digitado direto no Omie (PROPOSTA, 26/10/2026) · dono: Gustavo (DBA)
-- Aplicar DEPOIS do 0001 (e do 0004). Decisões: N16-102 (item do pedido = empresa + número do pedido + produto do Omie), N16-103 (a
-- comissão nova vale para os dois tipos de pedido) e N16-104 (no pedido do Omie o vendedor preenche os dados como hoje no Simulador de
-- Comissão: há estimativa, e o percentual final é o menor entre o do vendedor e o do custo real, como na proposta) e N16-105.
--
-- O que muda:
--   1. comissoes ganha origem (PROPOSTA ou PEDIDO_OMIE); a do Omie não tem proposta e se liga ao pedido do Hub de origem OMIE
--      (N16-106). Ela nasce ESTIMADA: a simulação é a parte de compras que o vendedor preenche no próprio pedido (o motor lê
--      vw_pedido_item_motor e grava o cálculo COTADO); confirmada (CONGELADA), o dossiê passa a EM_ACOMPANHAMENTO.
--   2. fn_comissao_abrir_pedido_omie abre o dossiê a partir de pedidos_vendas (o job chama quando o pedido chega pela pipeline).
--   3. comissao_calculo_itens: no pedido do Omie o item é o PRODUTO (codigo_produto = código do Omie), sem id_item_proposta.
--   4. comissoes_nf_itens guarda o produto do Omie da linha faturada.
--   5. fn_comissao_nf_fechar refeita para as duas origens e para os sequenciais (N16-100): a linha de um sequencial tem código de
--      linha NOVO no Omie; no pedido da proposta ela volta à linha do original pela terceira tabela; no do Omie casa pelo produto;
--      a quantidade já comissionada passa a ser somada por ITEM (proposta) ou por PRODUTO (Omie), não mais por linha, para não
--      pagar duas vezes a mesma peça.
--   6. Visões: a do vendedor diz SIMULACAO_PENDENTE enquanto ele não preencheu; a fila, os itens e a visão geral mostram a origem.
--
--   7. A NF que sai antes da simulação ESPERA (N16-105): o cálculo real já pode ser gravado e a Controladoria vê a margem real
--      em vw_comissao_nf_aguardando_simulacao; com as duas, a NF fecha pelo menor percentual.

BEGIN;

-- ───────────────────────── 1. Dossiê com duas origens
ALTER TABLE core_comissao.comissoes
  ADD COLUMN origem varchar(12) NOT NULL DEFAULT 'PROPOSTA',
  ALTER COLUMN id_proposta DROP NOT NULL,
  ALTER COLUMN numero_proposta DROP NOT NULL,
  DROP CONSTRAINT ck_comissoes_pedido;
ALTER TABLE core_comissao.comissoes
  ADD CONSTRAINT ck_comissoes_origem CHECK (origem IN ('PROPOSTA','PEDIDO_OMIE')),
  ADD CONSTRAINT ck_comissoes_origem_proposta CHECK ((origem = 'PROPOSTA') = (id_proposta IS NOT NULL AND numero_proposta IS NOT NULL)),
  ADD CONSTRAINT ck_comissoes_origem_omie CHECK (origem <> 'PEDIDO_OMIE' OR numero_pedido IS NOT NULL),
  ADD CONSTRAINT ck_comissoes_pedido CHECK (estado NOT IN ('EM_ACOMPANHAMENTO','ENCERRADA')
        OR id_pedido_venda IS NOT NULL OR origem = 'PEDIDO_OMIE');
-- Um dossiê vivo por pedido (empresa + número do Omie), qualquer que seja a origem.
CREATE UNIQUE INDEX uq_comissoes_numero_pedido ON core_comissao.comissoes (codigo_empresa, numero_pedido)
  WHERE numero_pedido IS NOT NULL AND estado <> 'CANCELADA';
COMMENT ON COLUMN core_comissao.comissoes.origem IS 'PROPOSTA = nasceu da proposta do Hub. PEDIDO_OMIE = pedido digitado direto no Omie (N16-103, N16-104): sem proposta; o vendedor preenche a simulação como hoje no Simulador de Comissão. Os dois seguem ESTIMADA > CONGELADA > EM_ACOMPANHAMENTO.';
COMMENT ON COLUMN core_comissao.comissoes.numero_pedido IS 'Número do pedido NO OMIE (pedidos_vendas.numero_pedido). No pedido da proposta, a API grava ao passar para EM_ACOMPANHAMENTO (o Omie aceita o número do Hub, N16-82).';

ALTER TABLE core_comissao.comissao_eventos DROP CONSTRAINT ck_eventos_tipo;
ALTER TABLE core_comissao.comissao_eventos ADD CONSTRAINT ck_eventos_tipo CHECK (tipo IN ('ESTIMATIVA_CALCULADA','PROPOSTA_APROVADA',
  'PEDIDO_CRIADO','PEDIDO_OMIE_ABERTO','CUSTO_REAL_RECALCULADO','NF_FECHADA','NF_RECALCULADA','DECISAO','CANCELADA','ENCERRADA',
  'ESTADO_ALTERADO','CONFERENCIA_COMPRAS','LANCAMENTO'));

-- ───────────────────────── 2. Abrir o dossiê do pedido digitado no Omie
-- Idempotente: se o dossiê do pedido já existe, devolve o mesmo. Recusa pedido que nasceu de proposta (esse tem dossiê próprio),
-- pedido que não existe e pedido cancelado. O vendedor e o cliente vêm do pedido original (sequencial 0).
CREATE OR REPLACE FUNCTION core_comissao.fn_comissao_abrir_pedido_omie(
  p_codigo_empresa uuid, p_numero_pedido varchar, p_usuario uuid DEFAULT NULL, p_id_usuario_vendedor uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid; v_origem text; pv record; v_ped uuid; v_ped_origem text;
BEGIN
  SELECT id, origem INTO v_id, v_origem FROM core_comissao.comissoes
   WHERE codigo_empresa = p_codigo_empresa AND numero_pedido = p_numero_pedido AND estado <> 'CANCELADA';
  IF FOUND THEN
    IF v_origem = 'PEDIDO_OMIE' THEN RETURN v_id; END IF;
    RAISE EXCEPTION 'PEDIDO_TEM_PROPOSTA: o pedido % nasceu de proposta e já tem dossiê de comissão.', p_numero_pedido USING ERRCODE = '23514';
  END IF;
  -- O pedido do Omie também está em core_comercial.pedidos (origem OMIE, N16-106): o dossiê se liga a ele. O que nasceu de proposta
  -- tem o dossiê da proposta.
  IF to_regclass('core_comercial.pedidos') IS NOT NULL THEN
    EXECUTE 'SELECT id, origem FROM core_comercial.pedidos WHERE codigo_empresa = $1 AND numero_pedido_omie = $2'
       INTO v_ped, v_ped_origem USING p_codigo_empresa, p_numero_pedido;
    IF v_ped_origem = 'PROPOSTA' THEN
      RAISE EXCEPTION 'PEDIDO_TEM_PROPOSTA: o pedido % nasceu de proposta; a comissão dele segue o dossiê da proposta.', p_numero_pedido USING ERRCODE = '23514';
    END IF;
  END IF;
  SELECT p.codigo_vendedor_omie, p.codigo_cliente, p.cancelado INTO pv
    FROM core_vendas_faturamento.pedidos_vendas p
   WHERE p.codigo_empresa = p_codigo_empresa AND p.numero_pedido = p_numero_pedido
     AND coalesce(p.sequencial, 0) = 0 AND p.deleted_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'PEDIDO_NAO_ENCONTRADO: pedido % não está em pedidos_vendas.', p_numero_pedido USING ERRCODE = 'P0002'; END IF;
  IF pv.cancelado THEN RAISE EXCEPTION 'PEDIDO_CANCELADO: o pedido % está cancelado no Omie.', p_numero_pedido USING ERRCODE = '23514'; END IF;
  IF pv.codigo_vendedor_omie IS NULL OR pv.codigo_cliente IS NULL THEN
    RAISE EXCEPTION 'PEDIDO_INCOMPLETO: o pedido % não tem vendedor ou cliente.', p_numero_pedido USING ERRCODE = '23514';
  END IF;
  INSERT INTO core_comissao.comissoes (codigo_empresa, origem, numero_pedido, id_pedido_venda, codigo_vendedor_omie, codigo_cliente,
      id_usuario_vendedor, estado, created_by, updated_by)
  VALUES (p_codigo_empresa, 'PEDIDO_OMIE', p_numero_pedido, v_ped, pv.codigo_vendedor_omie, pv.codigo_cliente,
      p_id_usuario_vendedor, 'ESTIMADA', p_usuario, p_usuario)
  RETURNING id INTO v_id;
  INSERT INTO core_comissao.comissao_eventos (id_comissao, tipo, descricao, dados, visivel_vendedor, feito_por)
  VALUES (v_id, 'PEDIDO_OMIE_ABERTO', format('Dossiê aberto para o pedido %s, digitado direto no Omie: preencha a parte de compras do pedido (a simulação da comissão).', p_numero_pedido),
          jsonb_build_object('numero_pedido', p_numero_pedido), true, p_usuario);
  RETURN v_id;
END $$;
COMMENT ON FUNCTION core_comissao.fn_comissao_abrir_pedido_omie(uuid, varchar, uuid, uuid) IS 'Abre (ou devolve) o dossiê da comissão de um pedido digitado direto no Omie (N16-103, N16-104), ESTIMADA, para o vendedor preencher a simulação. O job chama para todo pedido novo de pedidos_vendas que não nasceu de proposta; a API resolve o usuário do vendedor do Omie e manda em p_id_usuario_vendedor (trava N16-44).';

-- ───────────────────────── 3. Item do cálculo: item da proposta OU produto do Omie
ALTER TABLE core_comissao.comissao_calculo_itens
  ALTER COLUMN id_item_proposta DROP NOT NULL;
ALTER TABLE core_comissao.comissao_calculo_itens
  ADD CONSTRAINT ck_calc_itens_chave CHECK (id_item_proposta IS NOT NULL OR codigo_produto IS NOT NULL);
CREATE UNIQUE INDEX uq_calc_itens_produto ON core_comissao.comissao_calculo_itens (id_calculo, codigo_produto) WHERE id_item_proposta IS NULL;
COMMENT ON COLUMN core_comissao.comissao_calculo_itens.codigo_produto IS 'No pedido digitado no Omie é a CHAVE do item: código do produto do Omie (N16-102, item = produto). Na proposta é informativo.';

-- O item tem de combinar com a origem do dossiê: proposta → id_item_proposta; pedido do Omie → só o produto.
CREATE OR REPLACE FUNCTION core_comissao.fn_calc_itens_origem() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_origem text;
BEGIN
  SELECT c.origem INTO v_origem FROM core_comissao.comissao_calculos k JOIN core_comissao.comissoes c ON c.id = k.id_comissao
   WHERE k.id = NEW.id_calculo;
  IF v_origem = 'PEDIDO_OMIE' AND (NEW.id_item_proposta IS NOT NULL OR NEW.codigo_produto IS NULL) THEN
    RAISE EXCEPTION 'ITEM_DO_PEDIDO_OMIE: no pedido sem proposta o item é o produto do Omie (codigo_produto obrigatório, sem id_item_proposta).' USING ERRCODE = '23514';
  END IF;
  IF v_origem = 'PROPOSTA' AND NEW.id_item_proposta IS NULL THEN
    RAISE EXCEPTION 'ITEM_DA_PROPOSTA: no pedido da proposta o item precisa de id_item_proposta.' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_calc_itens_origem BEFORE INSERT ON core_comissao.comissao_calculo_itens
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_calc_itens_origem();

-- ───────────────────────── 4. O produto da linha faturada
ALTER TABLE core_comissao.comissoes_nf_itens ADD COLUMN codigo_produto_omie varchar(60);
COMMENT ON COLUMN core_comissao.comissoes_nf_itens.codigo_produto_omie IS 'Produto do Omie da linha faturada. No pedido do Omie é a chave do item (N16-102) e soma a quantidade já comissionada entre as NFs.';

-- ───────────────────────── 5. Fechar a comissão de uma NF: as duas origens e os sequenciais
-- Proposta: a linha faturada liga ao item da proposta pelo vínculo; a linha de um sequencial (código de linha NOVO no Omie, N16-100)
-- volta à linha do original pela terceira tabela (pedidos_vendas_sequenciais_itens). Percentual final = o MENOR entre o cotado e o real.
-- Pedido do Omie: a linha liga aos itens dos cálculos pelo PRODUTO (N16-102); o cotado é a simulação do vendedor (N16-104).
-- Nas duas: só as peças com custo real são comissionadas (N16-48) e a mesma peça nunca é paga duas vezes (N16-49): a quantidade já
-- comissionada soma por ITEM (todas as linhas e NFs do item, inclusive as dos sequenciais), não por linha.
CREATE OR REPLACE FUNCTION core_comissao.fn_comissao_nf_fechar(p_id_comissao uuid, p_codigo_nf_omie bigint, p_usuario uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
  v_com   core_comissao.comissoes%ROWTYPE;
  v_nf    record;
  v_id    uuid;
  v_est   text;
  v_zero  text;
  v_fat   numeric; v_cot numeric; v_calc numeric; v_pend numeric; v_sem integer; v_n integer; v_compl boolean;
BEGIN
  SELECT * INTO v_com FROM core_comissao.comissoes WHERE id = p_id_comissao FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Comissão % não existe.', p_id_comissao USING ERRCODE = 'P0002'; END IF;
  IF v_com.estado <> 'EM_ACOMPANHAMENTO' THEN
    RAISE EXCEPTION 'Comissão fecha NF só EM_ACOMPANHAMENTO. Estado atual: %.', v_com.estado USING ERRCODE = '23514';
  END IF;
  IF v_com.id_calculo_cotado IS NULL THEN
    RAISE EXCEPTION 'Comissão sem cálculo cotado (no pedido do Omie, a simulação do vendedor, N16-104).' USING ERRCODE = '23514';
  END IF;

  SELECT n.numero_nf, to_date(n.data_emissao, 'YYYY-MM-DD') AS data_emissao INTO v_nf
    FROM core_vendas_faturamento.notas_fiscais n
   WHERE n.codigo_empresa = v_com.codigo_empresa AND n.codigo_nf_omie = p_codigo_nf_omie AND n.deleted_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'NF % não existe na unidade.', p_codigo_nf_omie USING ERRCODE = 'P0002'; END IF;

  SELECT id, estado INTO v_id, v_est FROM core_comissao.comissoes_nf
   WHERE codigo_empresa = v_com.codigo_empresa AND codigo_nf_omie = p_codigo_nf_omie FOR UPDATE;
  IF FOUND AND v_est <> 'AGUARDANDO_DECISAO' THEN
    RAISE EXCEPTION 'A comissão desta NF já foi decidida (%): não é recalculada.', v_est USING ERRCODE = '23514';
  END IF;

  v_zero := CASE
    WHEN core_comissao.fn_excluido(v_com.codigo_empresa, 'CLIENTE',  v_com.codigo_cliente, v_nf.data_emissao) THEN 'CLIENTE_EXCLUIDO'
    WHEN core_comissao.fn_excluido(v_com.codigo_empresa, 'VENDEDOR', v_com.codigo_vendedor_omie, v_nf.data_emissao) THEN 'VENDEDOR_EXCLUIDO'
    ELSE NULL END;

  CREATE TEMP TABLE IF NOT EXISTS tmp_nf_fechar (
    codigo_item_omie bigint, codigo_produto_omie varchar(60), id_item_pedido uuid, id_item_cotado uuid, id_item_real uuid,
    quantidade numeric, valor numeric, pct_cot numeric, pct_real numeric, pct_fin numeric,
    regra text, val_cot numeric, val_calc numeric, completo boolean, qtd_com numeric, pend numeric) ON COMMIT DROP;
  TRUNCATE tmp_nf_fechar;

  INSERT INTO tmp_nf_fechar
  WITH l AS (
    -- pedido da proposta: chave = item da proposta
    SELECT pv.codigo_item_omie, pv.codigo_produto_omie, pv.quantidade::numeric AS qtd, pv.valor_total AS valor,
           vi.id_item_pedido, ic.id AS id_cot, ir.id AS id_real, ic.id_item_proposta::text AS chave,
           ic.comissao_pct AS pct_cot, ir.comissao_pct AS pct_real, ic.tipo_item,
           ic.regra_aplicada AS regra_cot, ir.regra_aplicada AS regra_real, ir.quantidade_coberta AS coberta
      FROM core_vendas_faturamento.produto_vendas pv
      CROSS JOIN LATERAL (
            SELECT coalesce((SELECT s.codigo_item_omie_original FROM core_vendas_faturamento.pedidos_vendas_sequenciais_itens s
                              WHERE s.codigo_empresa = pv.codigo_empresa AND s.codigo_item_omie = pv.codigo_item_omie
                                AND s.codigo_item_omie_original IS NOT NULL), pv.codigo_item_omie) AS cod) m
      JOIN core_comissao.comissao_itens_vinculo vi ON vi.id_comissao = v_com.id AND vi.codigo_item_omie = m.cod
      JOIN core_comissao.comissao_calculo_itens ic ON ic.id_calculo = v_com.id_calculo_cotado AND ic.id_item_proposta = vi.id_item_proposta
      LEFT JOIN core_comissao.comissao_calculo_itens ir ON ir.id_calculo = v_com.id_calculo_real AND ir.id_item_proposta = ic.id_item_proposta
     WHERE v_com.origem = 'PROPOSTA'
       AND pv.codigo_empresa = v_com.codigo_empresa AND pv.codigo_nf_omie = p_codigo_nf_omie
       AND pv.deleted_at IS NULL AND pv.codigo_item_omie IS NOT NULL
    UNION ALL
    -- pedido digitado no Omie: chave = produto do Omie (simulação do vendedor e cálculo real)
    SELECT pv.codigo_item_omie, pv.codigo_produto_omie, pv.quantidade::numeric, pv.valor_total,
           NULL::uuid, ic.id, ir.id, ic.codigo_produto::text,
           ic.comissao_pct, ir.comissao_pct, ic.tipo_item, ic.regra_aplicada, ir.regra_aplicada, ir.quantidade_coberta
      FROM core_vendas_faturamento.produto_vendas pv
      JOIN core_comissao.comissao_calculo_itens ic ON ic.id_calculo = v_com.id_calculo_cotado AND ic.id_item_proposta IS NULL
                                                  AND ic.codigo_produto = pv.codigo_produto_omie
      LEFT JOIN core_comissao.comissao_calculo_itens ir ON ir.id_calculo = v_com.id_calculo_real AND ir.id_item_proposta IS NULL
                                                       AND ir.codigo_produto = ic.codigo_produto
     WHERE v_com.origem = 'PEDIDO_OMIE'
       AND pv.codigo_empresa = v_com.codigo_empresa AND pv.codigo_nf_omie = p_codigo_nf_omie AND pv.numero_pedido = v_com.numero_pedido
       AND pv.deleted_at IS NULL AND pv.codigo_item_omie IS NOT NULL
  ), j AS (
    SELECT l.*,
           -- já comissionado do mesmo item em OUTRAS NFs do pedido
           coalesce((SELECT sum(x.quantidade_comissionavel)
                       FROM core_comissao.comissoes_nf_itens x
                       JOIN core_comissao.comissoes_nf nn ON nn.id = x.id_comissao_nf
                       LEFT JOIN core_comissao.comissao_calculo_itens xc ON xc.id = coalesce(x.id_item_cotado, x.id_item_real)
                      WHERE nn.id_comissao = v_com.id AND nn.estado <> 'NF_CANCELADA' AND nn.codigo_nf_omie <> p_codigo_nf_omie
                        AND coalesce(xc.id_item_proposta::text, x.codigo_produto_omie) = l.chave), 0)
           -- complementos já lançados para o item (a linha do complemento é traduzida para o item pela NF de onde veio)
         + coalesce((SELECT sum((e ->> 'quantidade')::numeric)
                       FROM core_comissao.comissao_lancamentos lc, jsonb_array_elements(lc.itens) e
                      WHERE lc.id_comissao = v_com.id AND lc.tipo = 'COMPLEMENTO'
                        AND ((e ->> 'codigo_item_omie')::bigint = l.codigo_item_omie OR EXISTS (
                              SELECT 1 FROM core_comissao.comissoes_nf_itens x2
                                JOIN core_comissao.comissoes_nf n2 ON n2.id = x2.id_comissao_nf
                                LEFT JOIN core_comissao.comissao_calculo_itens xc2 ON xc2.id = coalesce(x2.id_item_cotado, x2.id_item_real)
                               WHERE n2.id_comissao = v_com.id AND x2.codigo_item_omie = (e ->> 'codigo_item_omie')::bigint
                                 AND coalesce(xc2.id_item_proposta::text, x2.codigo_produto_omie) = l.chave))), 0) AS ja,
           -- linhas anteriores do MESMO item nesta NF (dois sequenciais podem sair na mesma nota)
           coalesce(sum(l.qtd) OVER (PARTITION BY l.chave ORDER BY l.codigo_item_omie
                                     ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0) AS antes
      FROM l
  ), q AS (
    SELECT j.*,
           CASE WHEN j.tipo_item = 'FABRICACAO_INTERNA' THEN j.qtd
                WHEN j.id_real IS NULL THEN 0::numeric
                ELSE GREATEST(0::numeric, LEAST(j.qtd, coalesce(j.coberta, 0) - j.ja - j.antes)) END AS qtd_com,
           LEAST(j.pct_cot, coalesce(j.pct_real, j.pct_cot)) AS pct_fin
      FROM j
  ), f AS (
    SELECT q.*, CASE WHEN q.qtd > 0 THEN LEAST(q.qtd_com / q.qtd, 1) ELSE 0 END AS fator FROM q
  )
  SELECT f.codigo_item_omie, f.codigo_produto_omie, f.id_item_pedido, f.id_cot, f.id_real, f.qtd, f.valor,
         f.pct_cot, f.pct_real, f.pct_fin,
         CASE WHEN f.pct_real IS NOT NULL AND (f.pct_cot IS NULL OR f.pct_real < f.pct_cot) THEN f.regra_real ELSE f.regra_cot END,
         round(f.valor * coalesce(f.pct_cot, f.pct_fin) / 100, 2),
         CASE WHEN v_zero IS NOT NULL THEN 0 ELSE round(f.valor * f.fator * f.pct_fin / 100, 2) END,
         (f.fator >= 1),
         f.qtd_com,
         round(f.valor * (1 - f.fator) * coalesce(f.pct_cot, f.pct_fin) / 100, 2)
    FROM f;

  SELECT count(*), COALESCE(sum(valor), 0), COALESCE(sum(val_cot), 0), COALESCE(sum(val_calc), 0),
         COALESCE(sum(pend), 0), COALESCE(bool_and(completo), false)
    INTO v_n, v_fat, v_cot, v_calc, v_pend, v_compl FROM tmp_nf_fechar;
  IF v_n = 0 THEN
    RAISE EXCEPTION 'Nenhum item da NF % casa com a comissão (vínculo do item da proposta, ou produto do cálculo real no pedido do Omie).', p_codigo_nf_omie USING ERRCODE = '23514';
  END IF;

  SELECT GREATEST(count(DISTINCT pv.codigo_item_omie) - v_n, 0) INTO v_sem
    FROM core_vendas_faturamento.produto_vendas pv
   WHERE pv.codigo_empresa = v_com.codigo_empresa AND pv.codigo_nf_omie = p_codigo_nf_omie AND pv.deleted_at IS NULL;

  IF v_id IS NULL THEN
    v_id := uuidv7();
    INSERT INTO core_comissao.comissoes_nf (
      id, id_comissao, codigo_empresa, codigo_nf_omie, numero_nf, data_emissao, id_calculo_cotado, id_calculo_real,
      valor_faturado, valor_se_cotado, valor_calculado, valor_pendente_custo, comissao_efetiva_pct, custo_completo, qtd_itens,
      qtd_itens_sem_vinculo, motivo_zerado, created_by)
    VALUES (v_id, v_com.id, v_com.codigo_empresa, p_codigo_nf_omie, v_nf.numero_nf, v_nf.data_emissao,
      v_com.id_calculo_cotado, v_com.id_calculo_real, v_fat, v_cot, v_calc, v_pend,
      CASE WHEN v_fat > 0 THEN round(v_calc / v_fat * 100, 4) END, v_compl, v_n, v_sem, v_zero, p_usuario);
    INSERT INTO core_comissao.comissao_eventos (id_comissao, id_comissao_nf, tipo, descricao, dados, feito_por)
    VALUES (v_com.id, v_id, 'NF_FECHADA', format('NF %s fechada: comissão calculada e enviada à Controladoria.', v_nf.numero_nf),
            jsonb_build_object('valor_calculado', v_calc, 'valor_se_cotado', v_cot), p_usuario);
  ELSE
    DELETE FROM core_comissao.comissoes_nf_itens WHERE id_comissao_nf = v_id;
    UPDATE core_comissao.comissoes_nf SET
        id_calculo_cotado = v_com.id_calculo_cotado, id_calculo_real = v_com.id_calculo_real,
        valor_faturado = v_fat, valor_se_cotado = v_cot, valor_calculado = v_calc, valor_pendente_custo = v_pend,
        comissao_efetiva_pct = CASE WHEN v_fat > 0 THEN round(v_calc / v_fat * 100, 4) END,
        custo_completo = v_compl, qtd_itens = v_n, qtd_itens_sem_vinculo = v_sem, motivo_zerado = v_zero,
        recalculada_em = now(), updated_by = p_usuario,
        compras_estado = 'PENDENTE', compras_por = NULL, compras_em = NULL
      WHERE id = v_id;
    INSERT INTO core_comissao.comissao_eventos (id_comissao, id_comissao_nf, tipo, descricao, dados, feito_por)
    VALUES (v_com.id, v_id, 'NF_RECALCULADA', format('NF %s recalculada antes da decisão.', v_nf.numero_nf),
            jsonb_build_object('valor_calculado', v_calc, 'valor_se_cotado', v_cot), p_usuario);
  END IF;

  INSERT INTO core_comissao.comissoes_nf_itens (
    id_comissao_nf, id_item_cotado, id_item_real, id_item_pedido, codigo_item_omie, codigo_produto_omie, quantidade_faturada,
    valor_faturado_item, comissao_cotada_pct, comissao_real_pct, comissao_final_pct, regra_aplicada,
    valor_se_cotado, valor_calculado, quantidade_comissionavel, valor_pendente_custo)
  SELECT v_id, id_item_cotado, id_item_real, id_item_pedido, codigo_item_omie, codigo_produto_omie, quantidade, valor,
         pct_cot, pct_real, pct_fin, regra, val_cot, val_calc, qtd_com, pend FROM tmp_nf_fechar;
  RETURN v_id;
END $$;
COMMENT ON FUNCTION core_comissao.fn_comissao_nf_fechar(uuid, bigint, uuid) IS 'Fecha a comissão de uma NF só sobre as peças que já têm custo real (N16-48) e sem pagar duas vezes a mesma peça quando o item sai em várias NFs ou sequenciais (N16-49, N16-100). Nas duas origens: round(valor x LEAST(percentual cotado, percentual real) / 100, 2); no pedido digitado no Omie o cotado é a simulação do vendedor e o item é o produto (N16-103, N16-104). Aplica exclusão (valor 0 e motivo). Refaz enquanto AGUARDANDO_DECISAO; depois da decisão recusa.';

-- ───────────────────────── 6. Visões
-- Itens: custo cotado × real. No pedido do Omie o par cotado/real se encontra pelo produto.
CREATE OR REPLACE VIEW core_comissao.vw_comissao_itens_custo AS
SELECT c.id AS id_comissao, c.codigo_empresa, ic.ordem, ic.id_item_proposta, ic.id_item_pedido, ic.codigo_item_omie,
       ic.descricao, ic.tipo_item, ic.qtd,
       ic.preco_unit_compra_cotado, ic.compra_bruta AS custo_cotado_bruto,
       ir.quantidade_coberta, ir.custo_real_total, ir.custo_real_unitario_medio, ir.custo_completo,
       ir.compra_bruta AS custo_considerado_bruto,
       (ir.custo_real_total - round(ic.preco_unit_compra_cotado * COALESCE(ic.qtd_compra, ic.qtd) * COALESCE(ir.quantidade_coberta, 0) / NULLIF(ic.qtd, 0), 2)) AS diferenca_coberta,
       ic.margem_item_pct AS margem_cotada_pct, ir.margem_item_pct AS margem_real_pct,
       ic.letra_item AS letra_cotada, ir.letra_item AS letra_real,
       ic.comissao_pct AS comissao_cotada_pct, ir.comissao_pct AS comissao_real_pct,
       LEAST(ic.comissao_pct, COALESCE(ir.comissao_pct, ic.comissao_pct)) AS comissao_final_pct,
       ic.regra_aplicada AS regra_cotada, ir.regra_aplicada AS regra_real, ir.custo_real_acima_cotado,
       c.origem, ic.codigo_produto
  FROM core_comissao.comissoes c
  JOIN core_comissao.comissao_calculo_itens ic ON ic.id_calculo = c.id_calculo_cotado
  LEFT JOIN core_comissao.comissao_calculo_itens ir ON ir.id_calculo = c.id_calculo_real
        AND (ir.id_item_proposta = ic.id_item_proposta
             OR (ic.id_item_proposta IS NULL AND ir.id_item_proposta IS NULL AND ir.codigo_produto = ic.codigo_produto));
COMMENT ON VIEW core_comissao.vw_comissao_itens_custo IS 'Item a item: custo cotado x custo real, margem, letra e percentual nas duas versões e o final (o menor). No pedido digitado no Omie o item é o produto e o cotado é a simulação do vendedor. Para a Controladoria e a Gerência; NUNCA para o vendedor.';

-- Vendedor, fila da Controladoria e visão geral: ganham a origem.
CREATE OR REPLACE VIEW core_comissao.vw_comissao_vendedor AS
SELECT c.id AS id_comissao, c.codigo_empresa, c.codigo_vendedor_omie, c.numero_proposta, c.numero_pedido,
       c.codigo_cliente,
       CASE WHEN c.origem = 'PEDIDO_OMIE' AND c.id_calculo_cotado IS NULL THEN 'SIMULACAO_PENDENTE' ELSE
       CASE c.estado WHEN 'ESTIMADA' THEN 'ESTIMADA' WHEN 'CONGELADA' THEN 'ESTIMADA'
                     WHEN 'EM_ACOMPANHAMENTO' THEN 'ESTIMADA' WHEN 'ENCERRADA' THEN 'DECIDIDA'
                     WHEN 'CANCELADA' THEN 'CANCELADA' END END AS situacao,
       cc.valor_comissao_total AS valor_estimado,
       cc.comissao_efetiva_pct AS comissao_estimada_pct,
       cc.letra_equivalente   AS letra_estimada,
       COALESCE(d.valor_decidido, 0) AS valor_decidido,
       COALESCE(d.qtd_nf_decididas, 0) AS qtd_nf_decididas,
       COALESCE(d.qtd_nf_em_analise, 0) AS qtd_nf_em_analise,
       c.cancelada_em, c.created_at, c.updated_at, c.origem
  FROM core_comissao.comissoes c
  LEFT JOIN core_comissao.comissao_calculos cc ON cc.id = c.id_calculo_cotado
  LEFT JOIN LATERAL (
        SELECT sum(n.valor_final) FILTER (WHERE n.estado IN ('APROVADA','DESAPROVADA','CORTADA','ALTERADA','BLOQUEADA')) AS valor_decidido,
               count(*) FILTER (WHERE n.estado IN ('APROVADA','DESAPROVADA','CORTADA','ALTERADA','BLOQUEADA')) AS qtd_nf_decididas,
               count(*) FILTER (WHERE n.estado = 'AGUARDANDO_DECISAO') AS qtd_nf_em_analise
          FROM core_comissao.comissoes_nf n WHERE n.id_comissao = c.id) d ON true;
COMMENT ON VIEW core_comissao.vw_comissao_vendedor IS 'Visão do vendedor por proposta ou por pedido do Omie: a comissão ESTIMADA que ele pôs (no pedido do Omie, SIMULACAO_PENDENTE até ele preencher a simulação, N16-104), sempre; o valor decidido só das NFs que a Controladoria já decidiu. Não traz custo real, margem, queda nem justificativa. A API filtra pelo escopo do vendedor (token).';

CREATE OR REPLACE VIEW core_comissao.vw_comissao_nf_fila AS
SELECT n.id AS id_comissao_nf, n.id_comissao, n.codigo_empresa, c.codigo_vendedor_omie, c.codigo_cliente,
       c.numero_proposta, c.numero_pedido, n.codigo_nf_omie, n.numero_nf, n.data_emissao,
       n.valor_faturado, n.valor_se_cotado, n.valor_calculado, n.valor_pendente_custo, n.queda_por_custo, n.comissao_efetiva_pct,
       n.custo_completo, n.qtd_itens, n.qtd_itens_sem_vinculo, n.motivo_zerado, n.estado, n.valor_final,
       n.compras_estado, n.compras_em, cr.imposto_completo AS imposto_real_completo,
       c.custo_real_acima_cotado, cr.margem_liquida_pct AS margem_real_pct, cr.letra_equivalente AS letra_real,
       cq.margem_liquida_pct AS margem_cotada_pct, cq.letra_equivalente AS letra_cotada,
       (CURRENT_DATE - n.data_emissao) AS dias_desde_emissao,
       n.decidida_em, n.created_at, c.origem
  FROM core_comissao.comissoes_nf n
  JOIN core_comissao.comissoes c ON c.id = n.id_comissao
  JOIN core_comissao.comissao_calculos cq ON cq.id = n.id_calculo_cotado
  LEFT JOIN core_comissao.comissao_calculos cr ON cr.id = n.id_calculo_real;
COMMENT ON VIEW core_comissao.vw_comissao_nf_fila IS 'Fila e lista da Controladoria: comissão já calculada por NF, com valor cotado, valor calculado e queda por custo. Filtre estado = AGUARDANDO_DECISAO para a fila. Só para perfil com a tela da Controladoria.';

CREATE OR REPLACE VIEW core_comissao.vw_comissao_visao_geral AS
SELECT c.id AS id_comissao, c.codigo_empresa, c.codigo_vendedor_omie, c.codigo_cliente, c.numero_proposta, c.numero_pedido,
       c.estado, c.custo_real_acima_cotado,
       cq.valor_comissao_total AS valor_estimado, cq.margem_liquida_pct AS margem_cotada_pct,
       cr.valor_comissao_total AS valor_com_custo_real, cr.margem_liquida_pct AS margem_real_pct,
       cr.custo_completo AS custo_real_completo,
       COALESCE(n.qtd_nf, 0) AS qtd_nf, COALESCE(n.qtd_aguardando, 0) AS qtd_nf_aguardando,
       COALESCE(n.valor_faturado, 0) AS valor_faturado, COALESCE(n.valor_calculado, 0) AS valor_calculado,
       COALESCE(n.valor_final, 0) AS valor_final, COALESCE(n.valor_retido, 0) AS valor_bloqueado,
       c.created_at, c.updated_at, c.cancelada_em, c.origem
  FROM core_comissao.comissoes c
  LEFT JOIN core_comissao.comissao_calculos cq ON cq.id = c.id_calculo_cotado
  LEFT JOIN core_comissao.comissao_calculos cr ON cr.id = c.id_calculo_real
  LEFT JOIN LATERAL (
       SELECT count(*) AS qtd_nf,
              count(*) FILTER (WHERE x.estado = 'AGUARDANDO_DECISAO') AS qtd_aguardando,
              sum(x.valor_faturado) AS valor_faturado, sum(x.valor_calculado) AS valor_calculado,
              sum(x.valor_final) AS valor_final,
              sum(x.valor_calculado) FILTER (WHERE x.estado = 'BLOQUEADA') AS valor_retido
         FROM core_comissao.comissoes_nf x WHERE x.id_comissao = c.id AND x.estado <> 'NF_CANCELADA') n ON true;
COMMENT ON VIEW core_comissao.vw_comissao_visao_geral IS 'Visão geral da Controladoria: toda comissão, em qualquer estado, da estimada ao encerramento, com valores cotado, real, calculado, final e bloqueado.';

-- ───────────────────────── 7. Nota que sai antes da simulação do vendedor (N16-105)
-- A NF do pedido digitado no Omie ESPERA a simulação para fechar; enquanto isso a Controladoria já vê a margem real. Quando houver
-- as duas, o job fecha a NF com o menor percentual (fn_comissao_nf_fechar), como em qualquer outra.
CREATE OR REPLACE FUNCTION core_comissao.fn_calculo_gravar(p_payload jsonb) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_com     uuid := (p_payload ->> 'id_comissao')::uuid;
  v_tipo    text := p_payload ->> 'tipo';
  v_usuario uuid := NULLIF(p_payload ->> 'usuario', '')::uuid;
  v_cab     jsonb := p_payload -> 'cabecalho';
  v_estado  text;
  v_origem  text;
  v_seq     integer;
  v_id      uuid;
  v_acima   boolean;
  v_item    jsonb;
  v_item_id uuid;
BEGIN
  SELECT estado, origem INTO v_estado, v_origem FROM core_comissao.comissoes WHERE id = v_com FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Comissão % não existe.', v_com USING ERRCODE = 'P0002';
  END IF;
  IF v_tipo = 'COTADO' AND v_estado <> 'ESTIMADA' THEN
    RAISE EXCEPTION 'A estimativa só muda enquanto a proposta não é aprovada (N16-03). Estado atual: %.', v_estado USING ERRCODE = '23514';
  END IF;
  -- No pedido digitado no Omie o pedido já existe: o custo real recalcula mesmo antes de o vendedor preencher a simulação (N16-105).
  IF v_tipo = 'REAL' AND NOT (v_estado = 'EM_ACOMPANHAMENTO' OR (v_origem = 'PEDIDO_OMIE' AND v_estado IN ('ESTIMADA','CONGELADA'))) THEN
    RAISE EXCEPTION 'Cálculo com custo real só em comissão EM_ACOMPANHAMENTO. Estado atual: %.', v_estado USING ERRCODE = '23514';
  END IF;
  IF v_tipo NOT IN ('COTADO','REAL') THEN
    RAISE EXCEPTION 'tipo deve ser COTADO ou REAL.' USING ERRCODE = '22023';
  END IF;
  IF jsonb_typeof(p_payload -> 'itens') <> 'array' OR jsonb_array_length(p_payload -> 'itens') = 0 THEN
    RAISE EXCEPTION 'itens é obrigatório e deve ter ao menos um item.' USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(max(sequencia), 0) + 1 INTO v_seq FROM core_comissao.comissao_calculos WHERE id_comissao = v_com;
  v_id := uuidv7();

  INSERT INTO core_comissao.comissao_calculos (
    id, id_comissao, sequencia, tipo, gatilho, id_parametros, id_regra_fixa, versao_motor,
    estado_destino, icms_destino_pct, condicao_pagamento, encargo_pagamento_pct, isento_imposto, frete_compra_tipo,
    frete_compra_total, valor_st_venda, imposto_retido_difal, frete_venda, custo_total, venda_sugerida, valor_liquido,
    total_nf, markup_projetado, markup_real, markup_bruto_pct, margem_liquida_pct, lucro, letra_equivalente,
    comissao_efetiva_pct, valor_comissao_total, qtd_itens, qtd_itens_prejuizo, custo_completo, imposto_completo,
    avisos, calculado_por)
  SELECT v_id, v_com, v_seq, v_tipo, p_payload ->> 'gatilho', (p_payload ->> 'id_parametros')::uuid,
         NULLIF(p_payload ->> 'id_regra_fixa', '')::uuid, p_payload ->> 'versao_motor',
         c.estado_destino, c.icms_destino_pct, c.condicao_pagamento, c.encargo_pagamento_pct,
         COALESCE(c.isento_imposto, false), COALESCE(c.frete_compra_tipo, 'RATEIO'), COALESCE(c.frete_compra_total, 0),
         COALESCE(c.valor_st_venda, 0), COALESCE(c.imposto_retido_difal, 0), COALESCE(c.frete_venda, 0), c.custo_total,
         c.venda_sugerida, c.valor_liquido, c.total_nf, c.markup_projetado, c.markup_real, c.markup_bruto_pct,
         c.margem_liquida_pct, c.lucro, c.letra_equivalente, c.comissao_efetiva_pct, c.valor_comissao_total,
         c.qtd_itens, COALESCE(c.qtd_itens_prejuizo, 0), COALESCE(c.custo_completo, false),
         COALESCE(c.imposto_completo, true), COALESCE(v_cab -> 'avisos', '[]'::jsonb), v_usuario
    FROM jsonb_to_record(v_cab) AS c(
      estado_destino text, icms_destino_pct numeric, condicao_pagamento text, encargo_pagamento_pct numeric,
      isento_imposto boolean, frete_compra_tipo text, frete_compra_total numeric,
      valor_st_venda numeric, imposto_retido_difal numeric, frete_venda numeric, custo_total numeric,
      venda_sugerida numeric, valor_liquido numeric, total_nf numeric, markup_projetado numeric, markup_real numeric,
      markup_bruto_pct numeric, margem_liquida_pct numeric, lucro numeric, letra_equivalente text,
      comissao_efetiva_pct numeric, valor_comissao_total numeric, qtd_itens integer, qtd_itens_prejuizo integer,
      custo_completo boolean, imposto_completo boolean);

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_payload -> 'itens') LOOP
    v_item_id := uuidv7();
    INSERT INTO core_comissao.comissao_calculo_itens (
      id, id_calculo, ordem, id_item_proposta, id_item_pedido, codigo_item_omie, codigo_produto, descricao, tipo_item,
      qtd, unidade, qtd_compra, unidade_compra, fornecedor, origem_compra, ipi_pct, valor_st,
      frete_compra_valor, preco_unit_compra_cotado, preco_unit_venda, quantidade_coberta,
      custo_real_total, custo_real_unitario_medio, custo_completo, qtd_eventos, qtd_descoberta,
      custo_liquido_descoberto, imposto_completo, custo_real_acima_cotado,
      compra_bruta, icms_entrada_pct, icms_recuperar, valor_ipi, frete_item, custo_liquido,
      preco_unit_sugerido, preco_total_sugerido, venda_item, icms_efetivo_pct, impostos_pct, lucro_item,
      margem_item_pct, letra_item, comissao_letra_pct, teto_regra_pct, comissao_pct, regra_aplicada,
      valor_comissao_estimado)
    SELECT v_item_id, v_id, i.ordem, i.id_item_proposta, i.id_item_pedido, i.codigo_item_omie, i.codigo_produto,
           i.descricao, COALESCE(i.tipo_item, 'REVENDA'), i.qtd, i.unidade, i.qtd_compra, i.unidade_compra,
           i.fornecedor, i.origem_compra, COALESCE(i.ipi_pct, 0), COALESCE(i.valor_st, 0),
           COALESCE(i.frete_compra_valor, 0), COALESCE(i.preco_unit_compra_cotado, 0), i.preco_unit_venda,
           i.quantidade_coberta, i.custo_real_total, i.custo_real_unitario_medio, COALESCE(i.custo_completo, false),
           COALESCE(i.qtd_eventos, 0), i.qtd_descoberta, COALESCE(i.custo_liquido_descoberto, 0),
           COALESCE(i.imposto_completo, true), COALESCE(i.custo_real_acima_cotado, false),
           COALESCE(i.compra_bruta, 0), COALESCE(i.icms_entrada_pct, 0), COALESCE(i.icms_recuperar, 0),
           COALESCE(i.valor_ipi, 0), COALESCE(i.frete_item, 0), COALESCE(i.custo_liquido, 0), i.preco_unit_sugerido,
           i.preco_total_sugerido, i.venda_item, i.icms_efetivo_pct, i.impostos_pct, i.lucro_item, i.margem_item_pct,
           i.letra_item, i.comissao_letra_pct, i.teto_regra_pct, i.comissao_pct, i.regra_aplicada,
           i.valor_comissao_estimado
      FROM jsonb_to_record(v_item) AS i(
        ordem integer, id_item_proposta uuid, id_item_pedido uuid, codigo_item_omie bigint, codigo_produto text,
        descricao text, tipo_item text, qtd numeric, unidade text, qtd_compra numeric, unidade_compra text,
        fornecedor text, origem_compra text, ipi_pct numeric, valor_st numeric, frete_compra_valor numeric,
        preco_unit_compra_cotado numeric, preco_unit_venda numeric, quantidade_coberta numeric,
        custo_real_total numeric, custo_real_unitario_medio numeric, custo_completo boolean, qtd_eventos integer,
        qtd_descoberta numeric, custo_liquido_descoberto numeric, imposto_completo boolean,
        custo_real_acima_cotado boolean, compra_bruta numeric, icms_entrada_pct numeric, icms_recuperar numeric,
        valor_ipi numeric, frete_item numeric, custo_liquido numeric, preco_unit_sugerido numeric,
        preco_total_sugerido numeric, venda_item numeric, icms_efetivo_pct numeric, impostos_pct numeric,
        lucro_item numeric, margem_item_pct numeric, letra_item text, comissao_letra_pct numeric,
        teto_regra_pct numeric, comissao_pct numeric, regra_aplicada text, valor_comissao_estimado numeric);

    IF v_tipo = 'REAL' AND jsonb_typeof(v_item -> 'eventos') = 'array' THEN
      INSERT INTO core_comissao.comissao_calculo_eventos (
        id_calculo_item, ordem, id_custo_evento, codigo_parcial, data_evento, origem, numero_documento, fornecedor,
        quantidade_coberta, valor_unitario, valor_total, moeda, cotacao_moeda, condicao_pagamento,
        encargo_pagamento_pct, frete_tipo, frete_valor, origem_compra, ipi_pct, valor_st, valor_difal, imposto_real,
        compra_bruta, icms_entrada_pct, icms_recuperar, valor_ipi, frete_evento, custo_liquido)
      SELECT v_item_id, e.ordem, e.id_custo_evento, e.codigo_parcial, e.data_evento, e.origem, e.numero_documento,
             e.fornecedor, e.quantidade_coberta, e.valor_unitario, e.valor_total, COALESCE(e.moeda, 'BRL'),
             e.cotacao_moeda, e.condicao_pagamento, e.encargo_pagamento_pct, COALESCE(e.frete_tipo, 'RATEIO'),
             COALESCE(e.frete_valor, 0), e.origem_compra, COALESCE(e.ipi_pct, 0), COALESCE(e.valor_st, 0),
             COALESCE(e.valor_difal, 0), COALESCE(e.imposto_real, false), e.compra_bruta,
             COALESCE(e.icms_entrada_pct, 0), COALESCE(e.icms_recuperar, 0), COALESCE(e.valor_ipi, 0),
             COALESCE(e.frete_evento, 0), e.custo_liquido
        FROM jsonb_to_recordset(v_item -> 'eventos') AS e(
          ordem integer, id_custo_evento uuid, codigo_parcial text, data_evento date, origem text,
          numero_documento text, fornecedor text, quantidade_coberta numeric, valor_unitario numeric,
          valor_total numeric, moeda text, cotacao_moeda numeric, condicao_pagamento text,
          encargo_pagamento_pct numeric, frete_tipo text, frete_valor numeric, origem_compra text,
          ipi_pct numeric, valor_st numeric, valor_difal numeric, imposto_real boolean, compra_bruta numeric,
          icms_entrada_pct numeric, icms_recuperar numeric, valor_ipi numeric, frete_evento numeric,
          custo_liquido numeric);
    END IF;
  END LOOP;

  SELECT COALESCE(bool_or(custo_real_acima_cotado), false) INTO v_acima
    FROM core_comissao.comissao_calculo_itens WHERE id_calculo = v_id;

  IF v_tipo = 'COTADO' THEN
    UPDATE core_comissao.comissoes SET id_calculo_cotado = v_id, updated_by = v_usuario WHERE id = v_com;
  ELSE
    UPDATE core_comissao.comissoes SET id_calculo_real = v_id, custo_real_acima_cotado = v_acima, updated_by = v_usuario WHERE id = v_com;
  END IF;

  INSERT INTO core_comissao.comissao_eventos (id_comissao, tipo, descricao, dados, visivel_vendedor, feito_por)
  VALUES (v_com, CASE WHEN v_tipo = 'COTADO' THEN 'ESTIMATIVA_CALCULADA' ELSE 'CUSTO_REAL_RECALCULADO' END,
          CASE WHEN v_tipo = 'COTADO' THEN 'Comissão estimada calculada com o custo da proposta.'
               ELSE 'Comissão recalculada com o custo real do pedido.' END,
          jsonb_build_object('id_calculo', v_id, 'sequencia', v_seq, 'gatilho', p_payload ->> 'gatilho'),
          v_tipo = 'COTADO', v_usuario);
  RETURN v_id;
END $$;
COMMENT ON FUNCTION core_comissao.fn_calculo_gravar(jsonb) IS 'Grava, numa transação, um cálculo (cabeçalho e itens) já feito pelo motor da API e aponta a comissão para ele. COTADO só com a comissão ESTIMADA; REAL só EM_ACOMPANHAMENTO, ou já na ESTIMADA e na CONGELADA quando o pedido foi digitado no Omie (N16-105).';

CREATE OR REPLACE VIEW core_comissao.vw_comissao_nf_aguardando_simulacao AS
SELECT c.id AS id_comissao, c.codigo_empresa, c.codigo_vendedor_omie, c.codigo_cliente, c.numero_pedido, c.estado,
       n.codigo_nf_omie, n.numero_nf, to_date(n.data_emissao, 'YYYY-MM-DD') AS data_emissao,
       (CURRENT_DATE - to_date(n.data_emissao, 'YYYY-MM-DD')) AS dias_desde_emissao,
       sum(pv.valor_total) AS valor_faturado,
       cr.margem_liquida_pct AS margem_real_pct, cr.letra_equivalente AS letra_real, cr.comissao_efetiva_pct AS comissao_real_pct,
       cr.custo_completo AS custo_real_completo, cr.calculado_em AS custo_real_calculado_em
  FROM core_comissao.comissoes c
  JOIN core_vendas_faturamento.produto_vendas pv
    ON pv.codigo_empresa = c.codigo_empresa AND pv.numero_pedido = c.numero_pedido AND pv.codigo_nf_omie IS NOT NULL AND pv.deleted_at IS NULL
  JOIN core_vendas_faturamento.notas_fiscais n
    ON n.codigo_empresa = pv.codigo_empresa AND n.codigo_nf_omie = pv.codigo_nf_omie AND n.deleted_at IS NULL
  LEFT JOIN core_comissao.comissao_calculos cr ON cr.id = c.id_calculo_real
 WHERE c.origem = 'PEDIDO_OMIE' AND c.id_calculo_cotado IS NULL AND c.estado <> 'CANCELADA'
 GROUP BY c.id, c.codigo_empresa, c.codigo_vendedor_omie, c.codigo_cliente, c.numero_pedido, c.estado,
          n.codigo_nf_omie, n.numero_nf, n.data_emissao, cr.margem_liquida_pct, cr.letra_equivalente, cr.comissao_efetiva_pct,
          cr.custo_completo, cr.calculado_em;
COMMENT ON VIEW core_comissao.vw_comissao_nf_aguardando_simulacao IS 'Controladoria: notas de pedidos digitados no Omie que já saíram e esperam a simulação do vendedor (N16-105), com a margem, a letra e o percentual do custo real já calculados. Some da lista quando o vendedor preenche; aí a NF fecha pelo menor percentual. NUNCA para o vendedor.';

COMMIT;
