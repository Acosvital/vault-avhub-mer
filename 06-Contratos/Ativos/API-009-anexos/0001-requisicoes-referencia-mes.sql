-- ============================================================================
-- Migration api009 (proposta de 15/10/2026): referência da requisição do
-- Compras para o MES. Contrato API-009. Segue o molde da migration api004
-- (vw_ordens_compra_referencia_mes, ordens_compra_referencia_mes e
-- fn_oc_referencia_mes_marcar, Dump Avhub (Esqueleto).sql:6129-6174 e 20240-20278).
--
-- NÃO foi executado: validar num banco de teste restaurado do dump.
-- Depende da migration api010 (coluna requisicoes_compra.finalidade).
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Tabela da marca: quando a requisição mudou pela última vez.
--    updated_at NÃO serve de cursor: public.set_updated_at() grava NOW() (início
--    da transação) e uma transação longa gravaria um valor menor que um já lido.
--    A marca usa clock_timestamp(), como a da OC.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_vendas_faturamento.requisicoes_compra_referencia_mes (
    id_requisicao uuid NOT NULL,
    alterado_em   timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_requisicoes_compra_referencia_mes') THEN
    ALTER TABLE core_vendas_faturamento.requisicoes_compra_referencia_mes
      ADD CONSTRAINT pk_requisicoes_compra_referencia_mes PRIMARY KEY (id_requisicao);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_requisicoes_compra_referencia_mes_req') THEN
    ALTER TABLE core_vendas_faturamento.requisicoes_compra_referencia_mes
      ADD CONSTRAINT fk_requisicoes_compra_referencia_mes_req
      FOREIGN KEY (id_requisicao) REFERENCES core_vendas_faturamento.requisicoes_compra(id)
      ON UPDATE CASCADE ON DELETE CASCADE;
  END IF;
END $$;

-- Índice do cursor (alterado_em, id), igual ao da OC.
CREATE INDEX IF NOT EXISTS idx_requisicoes_compra_referencia_mes_alterado
  ON core_vendas_faturamento.requisicoes_compra_referencia_mes (alterado_em, id_requisicao);

-- ----------------------------------------------------------------------------
-- 2. Função da marca. Marca a requisição quando ela (ou a OC que a atendeu)
--    muda. Só entra na tabela a requisição do av-hub (id_origem nulo) com pedido
--    de venda; depois de entrar, qualquer mudança é marcada, inclusive a que a
--    tira da vista (pedido removido, cancelada): o MES precisa saber para limpar.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_req_referencia_mes_marcar() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$
DECLARE
  v_ids uuid[] := ARRAY[]::uuid[];
BEGIN
  IF TG_TABLE_NAME = 'requisicoes_compra' THEN
    v_ids := ARRAY[NEW.id];

  ELSIF TG_TABLE_NAME = 'ordens_compra' THEN
    -- A OC mudou (aprovada, cancelada, renumerada): marca as requisições dela
    -- (as do item, via id_ordem_compra da requisição, e a do cabeçalho).
    SELECT COALESCE(array_agg(DISTINCT x.id), ARRAY[]::uuid[]) INTO v_ids
      FROM (
        SELECT r.id
          FROM core_vendas_faturamento.requisicoes_compra r
         WHERE r.id_ordem_compra = NEW.id
        UNION ALL
        SELECT NEW.id_requisicao WHERE NEW.id_requisicao IS NOT NULL
      ) x;
  END IF;

  INSERT INTO core_vendas_faturamento.requisicoes_compra_referencia_mes AS t (id_requisicao, alterado_em)
  SELECT r.id, clock_timestamp()
    FROM core_vendas_faturamento.requisicoes_compra r
   WHERE r.id = ANY (v_ids)
     AND r.id_origem IS NULL                      -- a do MES o MES já conhece
     AND (r.numero_pedido_venda IS NOT NULL       -- entra
          OR EXISTS (SELECT 1 FROM core_vendas_faturamento.requisicoes_compra_referencia_mes m
                      WHERE m.id_requisicao = r.id))   -- já entrou: marca a saída também
  ON CONFLICT (id_requisicao)
  DO UPDATE SET alterado_em = GREATEST(EXCLUDED.alterado_em, t.alterado_em);

  RETURN NULL;
END
$$;

-- Triggers (todas AFTER, FOR EACH ROW; mesmo desenho das trg_oc_referencia_mes).
DROP TRIGGER IF EXISTS trg_req_referencia_mes_ins ON core_vendas_faturamento.requisicoes_compra;
CREATE TRIGGER trg_req_referencia_mes_ins
  AFTER INSERT ON core_vendas_faturamento.requisicoes_compra
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_req_referencia_mes_marcar();

DROP TRIGGER IF EXISTS trg_req_referencia_mes ON core_vendas_faturamento.requisicoes_compra;
CREATE TRIGGER trg_req_referencia_mes
  AFTER UPDATE OF status, id_ordem_compra, numero_pedido_venda, finalidade, material, descricao,
                  quantidade, unidade_medida, prazo_necessidade, deleted_at, id_origem
  ON core_vendas_faturamento.requisicoes_compra
  FOR EACH ROW
  WHEN ((old.status, old.id_ordem_compra, old.numero_pedido_venda, old.finalidade, old.material,
         old.descricao, old.quantidade, old.unidade_medida, old.prazo_necessidade, old.deleted_at,
         old.id_origem)
        IS DISTINCT FROM
        (new.status, new.id_ordem_compra, new.numero_pedido_venda, new.finalidade, new.material,
         new.descricao, new.quantidade, new.unidade_medida, new.prazo_necessidade, new.deleted_at,
         new.id_origem))
  EXECUTE FUNCTION core_vendas_faturamento.fn_req_referencia_mes_marcar();

-- Mudança de situação da OC (aguardando_aprovacao -> aprovado, cancelado...) não
-- altera a linha da requisição: precisa da trigger na OC.
DROP TRIGGER IF EXISTS trg_req_referencia_mes ON core_vendas_faturamento.ordens_compra;
CREATE TRIGGER trg_req_referencia_mes
  AFTER UPDATE OF status, numero_pedido, deleted_at, id_requisicao
  ON core_vendas_faturamento.ordens_compra
  FOR EACH ROW
  WHEN ((old.status, old.numero_pedido, old.deleted_at, old.id_requisicao)
        IS DISTINCT FROM
        (new.status, new.numero_pedido, new.deleted_at, new.id_requisicao))
  EXECUTE FUNCTION core_vendas_faturamento.fn_req_referencia_mes_marcar();

-- ----------------------------------------------------------------------------
-- 3. Preenchimento inicial: requisições do av-hub que já têm pedido de venda.
-- ----------------------------------------------------------------------------
INSERT INTO core_vendas_faturamento.requisicoes_compra_referencia_mes (id_requisicao, alterado_em)
SELECT r.id, clock_timestamp()
  FROM core_vendas_faturamento.requisicoes_compra r
 WHERE r.id_origem IS NULL
   AND r.numero_pedido_venda IS NOT NULL
   AND r.deleted_at IS NULL
ON CONFLICT (id_requisicao) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. A view que a rota lê. Estilo da vw_ordens_compra_referencia_mes: a regra
--    mora no banco; a rota só filtra e pagina.
--    visivel_ao_pcp = false avisa o MES para apagar a linha da projeção
--    (cancelada, pedido de venda retirado, finalidade que não liga a pedido).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW core_vendas_faturamento.vw_requisicoes_compra_referencia_mes AS
 SELECT r.id AS id_requisicao,
        r.codigo_empresa,
        r.numero_requisicao,
        (r.status)::character varying(15) AS status,
        r.finalidade,
        r.material,
        p.codigo_produto_omie,
        COALESCE(NULLIF(btrim(r.descricao), ''), p.descricao) AS descricao,
        trim_scale(r.quantidade) AS quantidade,
        r.unidade_medida,
        r.prazo_necessidade,
        r.numero_pedido_venda,
        r.id_ordem_compra,
        oc.numero_pedido AS numero_ordem_compra,
        oc.status AS situacao_ordem_compra,
        (r.deleted_at IS NULL
          AND r.numero_pedido_venda IS NOT NULL
          AND r.finalidade IN ('pedidos_venda', 'recompra')
          AND r.status <> 'cancelada') AS visivel_ao_pcp,
        m.alterado_em,
        to_char((m.alterado_em AT TIME ZONE 'UTC'::text), 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'::text) AS alterado_em_utc
   FROM core_vendas_faturamento.requisicoes_compra r
   JOIN core_vendas_faturamento.requisicoes_compra_referencia_mes m ON m.id_requisicao = r.id
   LEFT JOIN core.produtos p
          ON p.codigo_empresa = r.codigo_empresa
         AND p.codigo_produto = btrim(r.material)
         AND p.deleted_at IS NULL
   LEFT JOIN core_vendas_faturamento.ordens_compra oc ON oc.id = r.id_ordem_compra
  WHERE r.id_origem IS NULL;

COMMENT ON VIEW core_vendas_faturamento.vw_requisicoes_compra_referencia_mes IS
  'Referência da requisição do Compras para o MES (contrato API-009). GET /compras/requisicoes/referencia lê esta view por (alterado_em, id_requisicao). visivel_ao_pcp = false manda o MES apagar a linha.';

COMMIT;
