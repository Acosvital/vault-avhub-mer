-- Contrato 35 — roteiro de teste do apêndice A. Termina em ROLLBACK: não deixa nada gravado.
-- Usa a unidade e o fornecedor de uma OC que já exista no banco.
\set ON_ERROR_STOP 1
BEGIN;
CREATE TEMP TABLE t AS
SELECT oc.codigo_empresa AS emp, oc.codigo_fornecedor AS forn,
       (SELECT id FROM auth.usuarios LIMIT 1) AS usu,
       uuidv7() AS origem, uuidv7() AS req, uuidv7() AS req_manual, uuidv7() AS oc1, uuidv7() AS oc2
  FROM core_vendas_faturamento.ordens_compra oc LIMIT 1;

-- 1. requisição do MES chega; requisição manual (sem id_origem) não gera nada
INSERT INTO core_vendas_faturamento.requisicoes_compra (id, codigo_empresa, material, quantidade, unidade_medida, prazo_necessidade, id_origem, created_by)
SELECT req, emp, 'TESTE C35', 10, 'KG', current_date + 10, origem, usu FROM t;
INSERT INTO core_vendas_faturamento.requisicoes_compra (id, codigo_empresa, material, quantidade, unidade_medida, prazo_necessidade)
SELECT req_manual, emp, 'TESTE C35 MANUAL', 1, 'UN', current_date + 10 FROM t;
UPDATE core_vendas_faturamento.requisicoes_compra SET status = 'em_cotacao' WHERE id = (SELECT req_manual FROM t);

-- 2. comprador cota
UPDATE core_vendas_faturamento.requisicoes_compra SET status = 'em_cotacao', updated_by = (SELECT usu FROM t) WHERE id = (SELECT req FROM t);

-- 3. OC 1 em rascunho; item entra, sai e entra de novo (oc_criada, oc_removida, oc_criada)
INSERT INTO core_vendas_faturamento.ordens_compra (id, numero_pedido, codigo_empresa, codigo_fornecedor, tipo_frete, created_by)
SELECT oc1, 'T35-1', emp, forn, 'CIF', usu FROM t;
INSERT INTO core_vendas_faturamento.ordens_compra_itens (id_ordem_compra, ordem, descricao_produto, quantidade, unidade_medida, valor_unitario, codigo_empresa, id_requisicao)
SELECT oc1, 1, 'ITEM', 10, 'KG', 1, emp, req FROM t;
DELETE FROM core_vendas_faturamento.ordens_compra_itens WHERE id_ordem_compra = (SELECT oc1 FROM t);
INSERT INTO core_vendas_faturamento.ordens_compra_itens (id_ordem_compra, ordem, descricao_produto, quantidade, unidade_medida, valor_unitario, codigo_empresa, id_requisicao)
SELECT oc1, 1, 'ITEM', 10, 'KG', 1, emp, req FROM t;

-- 4. aprovação, Omie, fornecedor, previsão, ocorrência, despacho
UPDATE core_vendas_faturamento.ordens_compra SET status = 'aguardando_aprovacao', updated_by = (SELECT usu FROM t) WHERE id = (SELECT oc1 FROM t);
UPDATE core_vendas_faturamento.ordens_compra SET status = 'aprovado', aprovado_por = (SELECT usu FROM t), data_previsao_chegada = current_date + 7 WHERE id = (SELECT oc1 FROM t);
UPDATE core_vendas_faturamento.ordens_compra SET numero_pedido_omie = '999001' WHERE id = (SELECT oc1 FROM t);
INSERT INTO core_vendas_faturamento.ordens_compra_acompanhamento (id_ordem_compra, confirmacao_status, confirmado_em, confirmado_por)
SELECT oc1, 'confirmada', now(), usu FROM t;
INSERT INTO core_vendas_faturamento.ordens_compra_contatos (id_ordem_compra, tipo, canal, resumo, previsao_anterior, previsao_nova, created_by)
SELECT oc1, 'cobranca_prazo', 'telefone', 'atrasou', current_date + 7, current_date + 9, usu FROM t;
INSERT INTO core_vendas_faturamento.ordens_compra_contatos (id_ordem_compra, tipo, canal, resumo, created_by)
SELECT oc1, 'outro', 'email', 'sem previsão nova: não gera evento', usu FROM t;
INSERT INTO core_vendas_faturamento.ordens_compra_ocorrencias (id_ordem_compra, tipo, descricao, created_by)
SELECT oc1, 'atraso', 'atrasou 2 dias', usu FROM t;
UPDATE core_vendas_faturamento.ordens_compra_ocorrencias SET status = 'resolvida', decidido_em = now(), decidido_por = (SELECT usu FROM t)
 WHERE id_ordem_compra = (SELECT oc1 FROM t);
UPDATE core_vendas_faturamento.ordens_compra_acompanhamento SET despachado_em = current_date, nf_fornecedor = '123', transportadora = 'X'
 WHERE id_ordem_compra = (SELECT oc1 FROM t);

-- 5. OC cancelada (reprovação): requisição volta a aberta
UPDATE core_vendas_faturamento.ordens_compra SET status = 'cancelado', motivo_reprovacao = 'preço alto', updated_by = (SELECT usu FROM t) WHERE id = (SELECT oc1 FROM t);

-- 6. Compras cancela sem motivo: tem de falhar
SAVEPOINT s;
\set ON_ERROR_STOP 0
UPDATE core_vendas_faturamento.requisicoes_compra SET status = 'cancelada', cancelada_por_origem = 'compras' WHERE id = (SELECT req FROM t);
\set ON_ERROR_STOP 1
ROLLBACK TO SAVEPOINT s;

-- 7. Compras cancela com motivo; reabre; MES cancela (sem origem => 'mes')
UPDATE core_vendas_faturamento.requisicoes_compra SET status = 'cancelada', cancelada_por_origem = 'compras', motivo_cancelamento = 'material descontinuado', updated_by = (SELECT usu FROM t) WHERE id = (SELECT req FROM t);
UPDATE core_vendas_faturamento.requisicoes_compra SET status = 'aberta' WHERE id = (SELECT req FROM t);
SELECT status, cancelada_por_origem, motivo_cancelamento AS apos_reabrir FROM core_vendas_faturamento.requisicoes_compra WHERE id = (SELECT req FROM t);
UPDATE core_vendas_faturamento.requisicoes_compra SET status = 'cancelada' WHERE id = (SELECT req FROM t);

-- 8. histórico não muda
SAVEPOINT s2;
\set ON_ERROR_STOP 0
UPDATE core_vendas_faturamento.requisicoes_compra_eventos SET dados = '{}' WHERE id_requisicao = (SELECT req FROM t);
\set ON_ERROR_STOP 1
ROLLBACK TO SAVEPOINT s2;

-- Resultado
SELECT row_number() OVER (ORDER BY e.registrado_em, e.id) AS n, e.tipo, e.status_requisicao AS status,
       oc.numero_pedido AS oc, e.dados, (e.criado_por IS NOT NULL) AS tem_autor
  FROM core_vendas_faturamento.requisicoes_compra_eventos e
  LEFT JOIN core_vendas_faturamento.ordens_compra oc ON oc.id = e.id_ordem_compra
 WHERE e.id_requisicao IN (SELECT req FROM t UNION SELECT req_manual FROM t)
 ORDER BY e.registrado_em, e.id;
ROLLBACK;
