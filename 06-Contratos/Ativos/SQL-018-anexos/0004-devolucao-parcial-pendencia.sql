-- SQL-018 · anexo 0004 (PROPOSTA, 21/10/2026) · dono: Gustavo (DBA)
-- Devolução de venda e abatimento da comissão (K6, N16-47, N16-74). Rodar DEPOIS do 0001. Aditivo.
-- O Omie marca a NF como "devolvido" (total) ou "devolvido parcialmente", SEM item, quantidade nem valor da devolução.
-- Total: abate 100% sozinho. Parcial: abre uma PENDÊNCIA; o Fiscal ou a Controladoria informam item, quantidade e valor;
-- só então o abatimento proporcional é calculado (fn_comissao_nf_abater, já existente). Devolução de COMPRA fica de fora (OQ-42).

BEGIN;

CREATE TABLE core_comissao.comissao_devolucao_pendencia (
  id                uuid PRIMARY KEY DEFAULT uuidv7(),
  id_comissao_nf    uuid NOT NULL REFERENCES core_comissao.comissoes_nf(id) ON DELETE RESTRICT,
  estado            varchar(10) NOT NULL DEFAULT 'ABERTA',
  aberta_em         timestamptz NOT NULL DEFAULT now(),
  aberta_por        uuid REFERENCES auth.usuarios(id),
  perfil_informante varchar(12),
  informada_por     uuid REFERENCES auth.usuarios(id),
  informada_em      timestamptz,
  itens             jsonb,
  valor_devolvido   numeric(15,2),
  proporcao_pct     numeric(9,4),
  id_lancamento     uuid REFERENCES core_comissao.comissao_lancamentos(id),
  CONSTRAINT ck_devolucao_pend_estado CHECK (estado IN ('ABERTA','INFORMADA','DISPENSADA')),
  CONSTRAINT ck_devolucao_pend_perfil CHECK (perfil_informante IS NULL OR perfil_informante IN ('FISCAL','CONTROLADORIA')),
  CONSTRAINT ck_devolucao_pend_informada CHECK ((estado = 'INFORMADA') = (informada_em IS NOT NULL AND informada_por IS NOT NULL
        AND perfil_informante IS NOT NULL AND valor_devolvido IS NOT NULL AND itens IS NOT NULL)),
  CONSTRAINT ck_devolucao_pend_itens CHECK (itens IS NULL OR jsonb_typeof(itens) = 'array')
);
-- Uma pendência aberta por NF; depois de informada, uma nova devolução parcial abre outra.
CREATE UNIQUE INDEX uq_devolucao_pend_aberta ON core_comissao.comissao_devolucao_pendencia (id_comissao_nf) WHERE estado = 'ABERTA';
CREATE INDEX ix_devolucao_pend_nf ON core_comissao.comissao_devolucao_pendencia (id_comissao_nf);
COMMENT ON TABLE core_comissao.comissao_devolucao_pendencia IS 'Devolução PARCIAL de uma NF de venda marcada no Omie sem item, quantidade nem valor (N16-74). Fica ABERTA até o Fiscal ou a Controladoria informarem o que voltou; então vira INFORMADA e gera o lançamento de abatimento proporcional. Enquanto aberta, a comissão da NF fica sinalizada na visão da Controladoria. Devolução TOTAL não passa por aqui (abate 100% sozinha e dispensa a pendência que ainda estiver aberta: DISPENSADA).';
COMMENT ON COLUMN core_comissao.comissao_devolucao_pendencia.itens IS 'Quando informada: [{"codigo_item_omie": 501, "quantidade": 10, "valor": 2300.00}]. Nenhum item passa da quantidade faturada nem a soma passa do valor faturado da NF, descontadas as devoluções já informadas.';
COMMENT ON COLUMN core_comissao.comissao_devolucao_pendencia.proporcao_pct IS 'valor devolvido / valor faturado da NF x 100. É o que se abate da comissão da NF.';

-- Devolução TOTAL marcada no Omie: abate o que ainda resta da comissão da NF (100% menos o já abatido).
CREATE OR REPLACE FUNCTION core_comissao.fn_comissao_devolucao_total(p_id_comissao_nf uuid, p_usuario uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_ja numeric;
BEGIN
  PERFORM 1 FROM core_comissao.comissoes_nf WHERE id = p_id_comissao_nf FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Comissão da NF % não existe.', p_id_comissao_nf USING ERRCODE = 'P0002'; END IF;
  SELECT COALESCE(sum(proporcao_pct), 0) INTO v_ja FROM core_comissao.comissao_lancamentos
   WHERE id_comissao_nf = p_id_comissao_nf AND tipo = 'ABATIMENTO';
  IF v_ja >= 100 THEN
    RAISE EXCEPTION 'Esta NF já teve 100%% da comissão abatida.' USING ERRCODE = '23514';
  END IF;
  -- Devolução total fecha qualquer pendência parcial ainda aberta (nada mais a informar).
  UPDATE core_comissao.comissao_devolucao_pendencia SET estado = 'DISPENSADA' WHERE id_comissao_nf = p_id_comissao_nf AND estado = 'ABERTA';
  RETURN core_comissao.fn_comissao_nf_abater(p_id_comissao_nf, 'DEVOLUCAO', 100 - v_ja, 'Devolução total marcada no Omie', p_usuario);
END $$;
COMMENT ON FUNCTION core_comissao.fn_comissao_devolucao_total(uuid, uuid) IS 'O Omie marcou a NF como devolvida (total): a comissão é abatida por inteiro, sem informação do Fiscal (N16-74). Se a NF ainda aguardava decisão, sai da fila.';

-- Devolução PARCIAL marcada no Omie: abre a pendência (idempotente: devolve a que já está aberta).
CREATE OR REPLACE FUNCTION core_comissao.fn_comissao_devolucao_pendencia_abrir(p_id_comissao_nf uuid, p_usuario uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE n core_comissao.comissoes_nf%ROWTYPE; v_id uuid;
BEGIN
  SELECT * INTO n FROM core_comissao.comissoes_nf WHERE id = p_id_comissao_nf FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Comissão da NF % não existe.', p_id_comissao_nf USING ERRCODE = 'P0002'; END IF;
  IF n.estado = 'NF_CANCELADA' THEN
    RAISE EXCEPTION 'Esta NF já foi cancelada.' USING ERRCODE = '23514';
  END IF;
  SELECT id INTO v_id FROM core_comissao.comissao_devolucao_pendencia WHERE id_comissao_nf = n.id AND estado = 'ABERTA';
  IF FOUND THEN RETURN v_id; END IF;
  INSERT INTO core_comissao.comissao_devolucao_pendencia (id_comissao_nf, aberta_por) VALUES (n.id, p_usuario) RETURNING id INTO v_id;
  INSERT INTO core_comissao.comissao_eventos (id_comissao, id_comissao_nf, tipo, descricao, dados, visivel_vendedor, feito_por)
  VALUES (n.id_comissao, n.id, 'LANCAMENTO', format('NF %s marcada como devolvida parcialmente no Omie: pendência para o Fiscal ou a Controladoria informarem item, quantidade e valor.', n.numero_nf),
          jsonb_build_object('pendencia', v_id), false, p_usuario);
  RETURN v_id;
END $$;

-- O Fiscal ou a Controladoria informam o que voltou. Calcula a proporção e abate a comissão.
CREATE OR REPLACE FUNCTION core_comissao.fn_comissao_devolucao_informar(
  p_id_pendencia uuid, p_itens jsonb, p_perfil text, p_usuario uuid) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  d core_comissao.comissao_devolucao_pendencia%ROWTYPE; n core_comissao.comissoes_nf%ROWTYPE; e jsonb; v_cod bigint; v_qtd numeric; v_val numeric;
  v_total numeric := 0; v_ja_valor numeric; v_item core_comissao.comissoes_nf_itens%ROWTYPE; v_prop numeric; v_lanc uuid;
BEGIN
  SELECT * INTO d FROM core_comissao.comissao_devolucao_pendencia WHERE id = p_id_pendencia FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pendência % não existe.', p_id_pendencia USING ERRCODE = 'P0002'; END IF;
  IF d.estado <> 'ABERTA' THEN RAISE EXCEPTION 'Esta devolução já foi informada.' USING ERRCODE = '23514'; END IF;
  IF p_perfil NOT IN ('FISCAL','CONTROLADORIA') THEN
    RAISE EXCEPTION 'Só o Fiscal ou a Controladoria informam a devolução parcial (perfil %).', p_perfil USING ERRCODE = '42501';
  END IF;
  IF p_usuario IS NULL THEN RAISE EXCEPTION 'Informe quem está informando a devolução.' USING ERRCODE = '23514'; END IF;
  IF p_itens IS NULL OR jsonb_typeof(p_itens) <> 'array' OR jsonb_array_length(p_itens) = 0 THEN
    RAISE EXCEPTION 'Informe ao menos um item devolvido.' USING ERRCODE = '23514';
  END IF;
  SELECT * INTO n FROM core_comissao.comissoes_nf WHERE id = d.id_comissao_nf FOR UPDATE;
  FOR e IN SELECT * FROM jsonb_array_elements(p_itens) LOOP
    v_cod := (e ->> 'codigo_item_omie')::bigint; v_qtd := (e ->> 'quantidade')::numeric; v_val := (e ->> 'valor')::numeric;
    IF v_cod IS NULL OR v_qtd IS NULL OR v_qtd <= 0 OR v_val IS NULL OR v_val <= 0 THEN
      RAISE EXCEPTION 'Cada item precisa de codigo_item_omie, quantidade e valor maiores que zero.' USING ERRCODE = '23514';
    END IF;
    SELECT * INTO v_item FROM core_comissao.comissoes_nf_itens WHERE id_comissao_nf = n.id AND codigo_item_omie = v_cod;
    IF NOT FOUND THEN RAISE EXCEPTION 'O item % não está na NF %.', v_cod, n.numero_nf USING ERRCODE = '23514'; END IF;
    IF v_item.quantidade_faturada IS NOT NULL AND v_qtd > v_item.quantidade_faturada THEN
      RAISE EXCEPTION 'DEVOLUCAO_ACIMA_DO_FATURADO: o item % tem % faturado e foram informados %.', v_cod, v_item.quantidade_faturada, v_qtd USING ERRCODE = '23514';
    END IF;
    IF v_val > v_item.valor_faturado_item THEN
      RAISE EXCEPTION 'DEVOLUCAO_ACIMA_DO_FATURADO: o item % tem R$ % faturado e foram informados R$ %.', v_cod, v_item.valor_faturado_item, v_val USING ERRCODE = '23514';
    END IF;
    v_total := v_total + v_val;
  END LOOP;
  SELECT COALESCE(sum(valor_devolvido), 0) INTO v_ja_valor FROM core_comissao.comissao_devolucao_pendencia
   WHERE id_comissao_nf = n.id AND estado = 'INFORMADA';
  IF v_ja_valor + v_total > n.valor_faturado THEN
    RAISE EXCEPTION 'DEVOLUCAO_ACIMA_DO_FATURADO: a NF faturou R$ %, já houve R$ % de devolução informada e agora R$ %.', n.valor_faturado, v_ja_valor, v_total USING ERRCODE = '23514';
  END IF;
  v_prop := round(v_total / n.valor_faturado * 100, 4);
  v_lanc := core_comissao.fn_comissao_nf_abater(n.id, 'DEVOLUCAO', v_prop,
              format('Devolução parcial de R$ %s informada por %s', v_total, p_perfil), p_usuario);
  UPDATE core_comissao.comissao_devolucao_pendencia SET
      estado = 'INFORMADA', perfil_informante = p_perfil, informada_por = p_usuario, informada_em = now(),
      itens = p_itens, valor_devolvido = v_total, proporcao_pct = v_prop, id_lancamento = v_lanc
    WHERE id = d.id;
  RETURN v_lanc;
END $$;
COMMENT ON FUNCTION core_comissao.fn_comissao_devolucao_informar(uuid, jsonb, text, uuid) IS 'Fiscal ou Controladoria informam item, quantidade e valor da devolução parcial (N16-74). Nenhum item passa do faturado e a soma não passa do valor da NF, descontadas as devoluções já informadas. O abatimento é proporcional ao valor devolvido (fn_comissao_nf_abater). Devolve o id do lançamento (nulo se a comissão a abater for R$ 0).';

-- Fila do Fiscal e da Controladoria: pendências abertas com a idade de cada uma.
CREATE OR REPLACE VIEW core_comissao.vw_comissao_devolucao_pendente AS
SELECT p.id AS id_pendencia, p.id_comissao_nf, n.id_comissao, n.numero_nf, n.codigo_nf_omie, n.valor_faturado, n.estado AS estado_nf,
       p.aberta_em, round(extract(epoch FROM (now() - p.aberta_em)) / 3600, 1) AS idade_horas
  FROM core_comissao.comissao_devolucao_pendencia p
  JOIN core_comissao.comissoes_nf n ON n.id = p.id_comissao_nf
 WHERE p.estado = 'ABERTA';
COMMENT ON VIEW core_comissao.vw_comissao_devolucao_pendente IS 'Devoluções parciais marcadas no Omie e ainda não informadas, com a idade (horas). Só para o Fiscal e a Controladoria; o vendedor nunca vê.';

COMMIT;
