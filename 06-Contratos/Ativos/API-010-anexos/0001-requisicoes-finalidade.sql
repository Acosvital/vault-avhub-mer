-- ============================================================================
-- Migration api010 (proposta de 15/10/2026): finalidade, pedido de venda e
-- produto na requisição do Compras. Contrato API-010.
--
-- Aditivo e idempotente, no estilo das migrations 034 e 035 (BEGIN/COMMIT,
-- IF NOT EXISTS, DO $$ ... pg_constraint). NÃO foi executado: validar primeiro
-- num banco de teste restaurado do dump, rodar o bloco 0 (conferência) e só
-- depois aplicar. Aplicar ANTES de subir a API nova e ANTES da migration api009.
--
-- Fontes (literais) usadas como base:
--   Dump Avhub (Esqueleto).sql:8680-8826   fn_requisicao_mes_aplicar
--   Dump Avhub (Esqueleto).sql:6319-6394   fn_oc_vinculos_validar
--   Dump Avhub (Esqueleto).sql:18541-18572 requisicoes_compra
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Conferência prévia (só leitura). Rodar e resolver o que aparecer.
-- ----------------------------------------------------------------------------
-- 0.1 Requisição com codigo_pedido_omie mas sem numero_pedido_venda: o backfill
--     a marcaria como 'estoque' mesmo ligada a um pedido.
--   SELECT id, numero_requisicao, codigo_empresa, codigo_pedido_omie
--     FROM core_vendas_faturamento.requisicoes_compra
--    WHERE codigo_pedido_omie IS NOT NULL AND numero_pedido_venda IS NULL AND deleted_at IS NULL;
--
-- 0.2 Vínculos de OC com pedido de venda de OUTRA unidade que a da OC (a trava
--     nova só vale para linhas novas; as antigas ficam como estão):
--   SELECT v.id, v.id_ordem_compra, v.codigo_empresa_pv, o.codigo_empresa AS empresa_oc
--     FROM core_vendas_faturamento.ordens_compra_itens_vinculos v
--     JOIN core_vendas_faturamento.ordens_compra o ON o.id = v.id_ordem_compra
--    WHERE v.codigo_empresa_pv <> o.codigo_empresa;

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Coluna e preenchimento
-- ----------------------------------------------------------------------------
ALTER TABLE core_vendas_faturamento.requisicoes_compra
  ADD COLUMN IF NOT EXISTS finalidade character varying(15);

-- O backfill não deve mexer em updated_at (a trigger genérica o atualiza em
-- todo UPDATE): desliga só durante o preenchimento.
ALTER TABLE core_vendas_faturamento.requisicoes_compra DISABLE TRIGGER trg_requisicoes_compra_updated_at;

UPDATE core_vendas_faturamento.requisicoes_compra
   SET finalidade = CASE WHEN numero_pedido_venda IS NOT NULL THEN 'pedidos_venda' ELSE 'estoque' END
 WHERE finalidade IS NULL;

ALTER TABLE core_vendas_faturamento.requisicoes_compra ENABLE TRIGGER trg_requisicoes_compra_updated_at;

-- DEFAULT 'estoque': a API antiga (que ainda não manda finalidade) e qualquer
-- INSERT que não a informe continuam funcionando, sem pedido de venda. A API nova
-- exige a finalidade no POST (400 FINALIDADE_INVALIDA), então o default só
-- protege a janela entre a migration e o deploy.
ALTER TABLE core_vendas_faturamento.requisicoes_compra
  ALTER COLUMN finalidade SET DEFAULT 'estoque';
ALTER TABLE core_vendas_faturamento.requisicoes_compra
  ALTER COLUMN finalidade SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_requisicoes_compra_finalidade') THEN
    ALTER TABLE core_vendas_faturamento.requisicoes_compra
      ADD CONSTRAINT ck_requisicoes_compra_finalidade
      CHECK (finalidade IN ('pedidos_venda', 'recompra', 'estoque', 'uso_interno'));
  END IF;

  -- pedidos_venda e recompra exigem o pedido; estoque e uso_interno não o aceitam.
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_requisicoes_compra_finalidade_pv') THEN
    ALTER TABLE core_vendas_faturamento.requisicoes_compra
      ADD CONSTRAINT ck_requisicoes_compra_finalidade_pv
      CHECK ((finalidade IN ('pedidos_venda', 'recompra')) = (numero_pedido_venda IS NOT NULL));
  END IF;
END $$;

COMMENT ON COLUMN core_vendas_faturamento.requisicoes_compra.finalidade IS
  'Para que é a requisição (contrato API-010): pedidos_venda | recompra | estoque | uso_interno. Com pedido de venda (pedidos_venda, recompra) a requisição aparece no MES pela referência (API-009); estoque e uso_interno não.';

-- Base da referência para o MES (API-009): pedido de venda da unidade.
CREATE INDEX IF NOT EXISTS ix_requisicoes_compra_pedido
  ON core_vendas_faturamento.requisicoes_compra (codigo_empresa, numero_pedido_venda)
  WHERE numero_pedido_venda IS NOT NULL AND deleted_at IS NULL;

-- ----------------------------------------------------------------------------
-- 2. fn_requisicao_mes_aplicar: o PUT do MES passa a gravar a finalidade.
--    Regra: com numero_pedido_venda -> 'pedidos_venda'; sem -> 'estoque'.
--    Só muda o que está marcado com "-- api010"; o resto é o texto da migration 034.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_requisicao_mes_aplicar(p_id_origem uuid, p_dados jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  r          core_vendas_faturamento.requisicoes_compra%ROWTYPE;
  d          jsonb := COALESCE(p_dados, '{}'::jsonb);
  v_cancelar boolean;
  v_id       uuid;
  v_empresa  uuid;
  v_qtd      numeric;
  v_pv       text;     -- api010: numero_pedido_venda resultante, para derivar a finalidade
  c          text;
BEGIN
  IF p_id_origem IS NULL THEN
    RAISE EXCEPTION 'id_origem é obrigatório' USING ERRCODE = '23514';
  END IF;
  IF jsonb_typeof(d) <> 'object' THEN
    RAISE EXCEPTION 'o corpo deve ser um objeto JSON' USING ERRCODE = '23514';
  END IF;

  v_cancelar := COALESCE((d->>'cancelada')::boolean, false);

  PERFORM pg_advisory_xact_lock(hashtextextended('requisicao_mes:' || p_id_origem::text, 34));

  SELECT * INTO r
    FROM core_vendas_faturamento.requisicoes_compra
   WHERE id_origem = p_id_origem AND deleted_at IS NULL
   FOR UPDATE;

  -- ---------------------------------------------------------------- não existe
  IF NOT FOUND THEN
    IF v_cancelar THEN
      RETURN jsonb_build_object('resultado', 'nao_existe', 'id', NULL);
    END IF;

    FOREACH c IN ARRAY ARRAY['codigo_empresa', 'material', 'quantidade', 'unidade_medida', 'prazo_necessidade'] LOOP
      IF NULLIF(btrim(d->>c), '') IS NULL THEN
        RAISE EXCEPTION '% é obrigatório na criação', c USING ERRCODE = '23514';
      END IF;
    END LOOP;
    v_qtd := (d->>'quantidade')::numeric;
    IF v_qtd <= 0 THEN
      RAISE EXCEPTION 'quantidade deve ser maior que zero' USING ERRCODE = '23514';
    END IF;

    v_pv := NULLIF(btrim(d->>'numero_pedido_venda'), '');                          -- api010

    INSERT INTO core_vendas_faturamento.requisicoes_compra (
      codigo_empresa, material, descricao, quantidade, unidade_medida, prazo_necessidade,
      acabado_sugerido, solicitante, observacao, id_origem, numero_requisicao_mes,
      codigo_pedido_omie, numero_pedido_venda, finalidade)                          -- api010
    VALUES (
      (d->>'codigo_empresa')::uuid,
      btrim(d->>'material'),
      d->>'descricao',
      v_qtd,
      btrim(d->>'unidade_medida'),
      (d->>'prazo_necessidade')::date,
      (d->>'acabado_sugerido')::boolean,
      NULLIF(btrim(d->>'solicitante'), ''),
      d->>'observacao',
      p_id_origem,
      NULLIF(btrim(d->>'numero_requisicao_mes'), ''),
      (d->>'codigo_pedido_omie')::bigint,
      v_pv,
      CASE WHEN v_pv IS NOT NULL THEN 'pedidos_venda' ELSE 'estoque' END)           -- api010
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('resultado', 'criada', 'id', v_id);
  END IF;

  -- ------------------------------------------------------------------- com OC
  IF r.id_ordem_compra IS NOT NULL THEN
    RETURN jsonb_build_object(
      'resultado', CASE WHEN v_cancelar THEN 'recusada_com_oc' ELSE 'ignorada_com_oc' END,
      'id', r.id);
  END IF;

  -- --------------------------------------------------------- já cancelada
  IF r.status = 'cancelada' THEN
    RETURN jsonb_build_object('resultado', 'ignorada_cancelada', 'id', r.id);
  END IF;

  -- ---------------------------------------------------------------- cancelar
  IF v_cancelar THEN
    UPDATE core_vendas_faturamento.requisicoes_compra
       SET status = 'cancelada', updated_by = NULL
     WHERE id = r.id;
    RETURN jsonb_build_object('resultado', 'cancelada', 'id', r.id);
  END IF;

  -- --------------------------------------------------------------- atualizar
  IF d ? 'codigo_empresa' THEN
    v_empresa := (d->>'codigo_empresa')::uuid;
    IF v_empresa IS DISTINCT FROM r.codigo_empresa THEN
      RAISE EXCEPTION 'A unidade da requisição não muda (codigo_empresa atual: %)', r.codigo_empresa
        USING ERRCODE = '23514';
    END IF;
  END IF;

  FOREACH c IN ARRAY ARRAY['material', 'quantidade', 'unidade_medida', 'prazo_necessidade'] LOOP
    IF d ? c AND NULLIF(btrim(d->>c), '') IS NULL THEN
      RAISE EXCEPTION '% não pode ficar vazio', c USING ERRCODE = '23514';
    END IF;
  END LOOP;
  IF d ? 'quantidade' AND (d->>'quantidade')::numeric <= 0 THEN
    RAISE EXCEPTION 'quantidade deve ser maior que zero' USING ERRCODE = '23514';
  END IF;

  -- api010: pedido de venda que vai ficar na linha (campo ausente = fica como está).
  v_pv := CASE WHEN d ? 'numero_pedido_venda' THEN NULLIF(btrim(d->>'numero_pedido_venda'), '')
               ELSE r.numero_pedido_venda END;

  -- Campo ausente = fica como está; campo opcional com null = limpa.
  UPDATE core_vendas_faturamento.requisicoes_compra t
     SET material              = CASE WHEN d ? 'material'              THEN btrim(d->>'material')                     ELSE t.material END,
         descricao             = CASE WHEN d ? 'descricao'             THEN d->>'descricao'                           ELSE t.descricao END,
         quantidade            = CASE WHEN d ? 'quantidade'            THEN (d->>'quantidade')::numeric               ELSE t.quantidade END,
         unidade_medida        = CASE WHEN d ? 'unidade_medida'        THEN btrim(d->>'unidade_medida')               ELSE t.unidade_medida END,
         prazo_necessidade     = CASE WHEN d ? 'prazo_necessidade'     THEN (d->>'prazo_necessidade')::date           ELSE t.prazo_necessidade END,
         acabado_sugerido      = CASE WHEN d ? 'acabado_sugerido'      THEN (d->>'acabado_sugerido')::boolean         ELSE t.acabado_sugerido END,
         solicitante           = CASE WHEN d ? 'solicitante'           THEN NULLIF(btrim(d->>'solicitante'), '')      ELSE t.solicitante END,
         observacao            = CASE WHEN d ? 'observacao'            THEN d->>'observacao'                          ELSE t.observacao END,
         numero_requisicao_mes = CASE WHEN d ? 'numero_requisicao_mes' THEN NULLIF(btrim(d->>'numero_requisicao_mes'), '') ELSE t.numero_requisicao_mes END,
         codigo_pedido_omie    = CASE WHEN d ? 'codigo_pedido_omie'    THEN (d->>'codigo_pedido_omie')::bigint        ELSE t.codigo_pedido_omie END,
         numero_pedido_venda   = v_pv,                                                                                 -- api010
         finalidade            = CASE WHEN v_pv IS NOT NULL THEN 'pedidos_venda' ELSE 'estoque' END,                   -- api010
         updated_by            = NULL
   WHERE t.id = r.id
     AND (t.material, t.descricao, t.quantidade, t.unidade_medida, t.prazo_necessidade,
          t.acabado_sugerido, t.solicitante, t.observacao, t.numero_requisicao_mes,
          t.codigo_pedido_omie, t.numero_pedido_venda, t.finalidade)                                                   -- api010
         IS DISTINCT FROM
         (CASE WHEN d ? 'material'              THEN btrim(d->>'material')                     ELSE t.material END,
          CASE WHEN d ? 'descricao'             THEN d->>'descricao'                           ELSE t.descricao END,
          CASE WHEN d ? 'quantidade'            THEN round((d->>'quantidade')::numeric, 4)     ELSE t.quantidade END,
          CASE WHEN d ? 'unidade_medida'        THEN btrim(d->>'unidade_medida')               ELSE t.unidade_medida END,
          CASE WHEN d ? 'prazo_necessidade'     THEN (d->>'prazo_necessidade')::date           ELSE t.prazo_necessidade END,
          CASE WHEN d ? 'acabado_sugerido'      THEN (d->>'acabado_sugerido')::boolean         ELSE t.acabado_sugerido END,
          CASE WHEN d ? 'solicitante'           THEN NULLIF(btrim(d->>'solicitante'), '')      ELSE t.solicitante END,
          CASE WHEN d ? 'observacao'            THEN d->>'observacao'                          ELSE t.observacao END,
          CASE WHEN d ? 'numero_requisicao_mes' THEN NULLIF(btrim(d->>'numero_requisicao_mes'), '') ELSE t.numero_requisicao_mes END,
          CASE WHEN d ? 'codigo_pedido_omie'    THEN (d->>'codigo_pedido_omie')::bigint        ELSE t.codigo_pedido_omie END,
          v_pv,                                                                                                       -- api010
          CASE WHEN v_pv IS NOT NULL THEN 'pedidos_venda' ELSE 'estoque' END);                                        -- api010

  RETURN jsonb_build_object('resultado', CASE WHEN FOUND THEN 'atualizada' ELSE 'sem_mudanca' END,
                            'id', r.id);
END
$$;

-- ----------------------------------------------------------------------------
-- 3. fn_oc_vinculos_validar: o pedido de venda do vínculo é da mesma unidade da OC
--    (decisão N14-31). Exceção que o banco já conhece: a unidade SEM Omie compra
--    por outra (core.unidades.id_unidade_compra, caso da HRM); o pedido dela pode
--    estar na OC da unidade que compra por ela. Só muda o que está marcado com
--    "-- api010"; o resto é o texto atual da função.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_oc_vinculos_validar() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_item       record;
  v_ja         numeric;
  v_unidade    text;
  v_compra_por uuid;
  v_exigir     boolean := COALESCE(current_setting('avhub.compras_exigir_pv_existente', true), '')
                            IN ('on', 'true', '1');
BEGIN
  SELECT i.id_ordem_compra, i.quantidade, i.unidade_medida, o.finalidade,
         o.codigo_empresa AS empresa_oc                                              -- api010
    INTO v_item
    FROM core_vendas_faturamento.ordens_compra_itens i
    JOIN core_vendas_faturamento.ordens_compra o ON o.id = i.id_ordem_compra
   WHERE i.id = NEW.id_ordem_compra_item;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Item da ordem de compra % não existe', NEW.id_ordem_compra_item
      USING ERRCODE = '23514';
  END IF;

  NEW.id_ordem_compra     := v_item.id_ordem_compra;
  NEW.numero_pedido_venda := btrim(NEW.numero_pedido_venda);
  NEW.codigo_produto_pv   := NULLIF(btrim(NEW.codigo_produto_pv), '');

  IF v_item.finalidade NOT IN ('pedidos_venda', 'recompra') THEN
    RAISE EXCEPTION 'OC com finalidade "%" não se liga a pedido de venda', v_item.finalidade
      USING ERRCODE = '23514';
  END IF;

  SELECT u.nome_fantasia, u.id_unidade_compra INTO v_unidade, v_compra_por
    FROM core.unidades u WHERE u.id = NEW.codigo_empresa_pv AND u.deleted_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'A unidade do pedido de venda (%) não existe', NEW.codigo_empresa_pv
      USING ERRCODE = '23514';
  END IF;

  -- api010 (N14-31): pedido de venda e OC são da mesma unidade, ou a unidade do
  -- pedido compra pela unidade da OC (id_unidade_compra).
  IF NEW.codigo_empresa_pv <> v_item.empresa_oc
     AND v_compra_por IS DISTINCT FROM v_item.empresa_oc THEN
    RAISE EXCEPTION 'O pedido de venda % é de outra unidade que a ordem de compra', NEW.numero_pedido_venda
      USING ERRCODE = '23514';
  END IF;

  NEW.pv_conferido := EXISTS (
    SELECT 1 FROM core_vendas_faturamento.pedidos_vendas p
     WHERE p.codigo_empresa = NEW.codigo_empresa_pv
       AND p.numero_pedido = NEW.numero_pedido_venda
       AND p.deleted_at IS NULL);

  IF NOT NEW.pv_conferido AND v_compra_por IS NULL AND v_exigir THEN
    RAISE EXCEPTION 'Pedido de venda % não existe em %', NEW.numero_pedido_venda, v_unidade
      USING ERRCODE = '23514';
  END IF;

  IF NEW.pv_conferido AND NEW.codigo_produto_pv IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM core_vendas_faturamento.produto_vendas pv
        WHERE pv.codigo_empresa = NEW.codigo_empresa_pv
          AND pv.numero_pedido = NEW.numero_pedido_venda
          AND pv.codigo_produto_omie = NEW.codigo_produto_pv
          AND pv.deleted_at IS NULL) THEN
    RAISE EXCEPTION 'O produto % não está no pedido de venda %', NEW.codigo_produto_pv, NEW.numero_pedido_venda
      USING ERRCODE = '23514';
  END IF;

  SELECT COALESCE(sum(v.quantidade), 0) INTO v_ja
    FROM core_vendas_faturamento.ordens_compra_itens_vinculos v
   WHERE v.id_ordem_compra_item = NEW.id_ordem_compra_item
     AND v.id <> NEW.id;
  IF v_ja + NEW.quantidade > v_item.quantidade THEN
    RAISE EXCEPTION 'Vínculos somam % %, mais que a quantidade do item (% %)',
      trim_scale(v_ja + NEW.quantidade), v_item.unidade_medida,
      trim_scale(v_item.quantidade), v_item.unidade_medida
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END $$;

COMMIT;
