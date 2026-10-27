-- SQL-018 · anexo 0005 · teste funcional do 0004 (devolução parcial e total). Rodar depois de 0000, 0001, 0002 e 0004,
-- no mesmo banco (clona a NF 9001 do 0002 como NF 9100). Os ERROR esperados são 7: perfil errado, devolução acima do faturado
-- (quantidade, valor do item e soma), item fora da NF, pendência já informada e devolução total repetida.
\set ON_ERROR_STOP off
\pset pager off
SET client_min_messages = warning;
-- A NF 9001 do 0002 já terminou 100% abatida; clona-se uma NF nova (9100) já aprovada para este teste.
DO $$
DECLARE cols text; icols text;
BEGIN
  SELECT string_agg(quote_ident(column_name), ',') INTO cols FROM information_schema.columns
   WHERE table_schema = 'core_comissao' AND table_name = 'comissoes_nf' AND is_generated = 'NEVER' AND column_name NOT IN ('id','codigo_nf_omie','numero_nf','estado','valor_final','id_decisao_atual','paga_em');
  EXECUTE format($f$INSERT INTO core_comissao.comissoes_nf (id, codigo_nf_omie, numero_nf, estado, valor_final, %1$s)
                    SELECT '00000000-0000-7000-8000-0000000009a1', 9100, '00009100', 'APROVADA', 266, %1$s
                      FROM core_comissao.comissoes_nf WHERE codigo_nf_omie = 9001$f$, cols);
  SELECT string_agg(quote_ident(column_name), ',') INTO icols FROM information_schema.columns
   WHERE table_schema = 'core_comissao' AND table_name = 'comissoes_nf_itens' AND is_generated = 'NEVER' AND column_name NOT IN ('id','id_comissao_nf');
  EXECUTE format($f$INSERT INTO core_comissao.comissoes_nf_itens (id, id_comissao_nf, %1$s)
                    SELECT uuidv7(), '00000000-0000-7000-8000-0000000009a1', %1$s
                      FROM core_comissao.comissoes_nf_itens WHERE id_comissao_nf = (SELECT id FROM core_comissao.comissoes_nf WHERE codigo_nf_omie = 9001)$f$, icols);
END $$;
SELECT id AS id_nf, valor_faturado FROM core_comissao.comissoes_nf WHERE codigo_nf_omie = 9100 \gset
SELECT 'NF', :'id_nf', :valor_faturado AS valor_faturado, (SELECT count(*) FROM core_comissao.comissoes_nf_itens WHERE id_comissao_nf = :'id_nf') AS itens;
SELECT codigo_item_omie, quantidade_faturada, valor_faturado_item FROM core_comissao.comissoes_nf_itens WHERE id_comissao_nf = :'id_nf' ORDER BY 1;

-- 1. abre a pendência (idempotente: a segunda chamada devolve a mesma)
SELECT core_comissao.fn_comissao_devolucao_pendencia_abrir(:'id_nf', '00000000-0000-0000-0000-0000000000a2') AS id_pend \gset
SELECT (core_comissao.fn_comissao_devolucao_pendencia_abrir(:'id_nf') = :'id_pend'::uuid) AS pendencia_idempotente;
SELECT count(*) AS pendentes_na_fila FROM core_comissao.vw_comissao_devolucao_pendente;
-- 2. perfil errado: ERRO esperado
SELECT core_comissao.fn_comissao_devolucao_informar(:'id_pend', '[{"codigo_item_omie":501,"quantidade":5,"valor":1150}]'::jsonb, 'VENDEDOR', '00000000-0000-0000-0000-0000000000a2');
-- 3. quantidade acima do faturado: ERRO esperado
SELECT core_comissao.fn_comissao_devolucao_informar(:'id_pend', '[{"codigo_item_omie":501,"quantidade":51,"valor":1150}]'::jsonb, 'FISCAL', '00000000-0000-0000-0000-0000000000a2');
-- 4. valor acima do faturado do item: ERRO esperado
SELECT core_comissao.fn_comissao_devolucao_informar(:'id_pend', '[{"codigo_item_omie":501,"quantidade":5,"valor":99999}]'::jsonb, 'FISCAL', '00000000-0000-0000-0000-0000000000a2');
-- 5. item fora da NF: ERRO esperado
SELECT core_comissao.fn_comissao_devolucao_informar(:'id_pend', '[{"codigo_item_omie":999,"quantidade":1,"valor":10}]'::jsonb, 'FISCAL', '00000000-0000-0000-0000-0000000000a2');
-- 6. informa 10 de 50 flanges (R$ 2.300 de R$ 13.300): abatimento proporcional de 17,2932% da comissão da NF
SELECT core_comissao.fn_comissao_devolucao_informar(:'id_pend', '[{"codigo_item_omie":501,"quantidade":10,"valor":2300}]'::jsonb, 'FISCAL', '00000000-0000-0000-0000-0000000000a2') AS id_lanc \gset
SELECT estado, perfil_informante, valor_devolvido, proporcao_pct, id_lancamento IS NOT NULL AS gerou_lancamento FROM core_comissao.comissao_devolucao_pendencia WHERE id = :'id_pend';
SELECT tipo, origem, proporcao_pct, valor_calculado, valor_final, estado FROM core_comissao.comissao_lancamentos WHERE id = :'id_lanc'::uuid;
SELECT count(*) AS pendentes_depois FROM core_comissao.vw_comissao_devolucao_pendente;
-- 7. informar de novo a mesma pendência: ERRO esperado
SELECT core_comissao.fn_comissao_devolucao_informar(:'id_pend', '[{"codigo_item_omie":501,"quantidade":1,"valor":10}]'::jsonb, 'CONTROLADORIA', '00000000-0000-0000-0000-0000000000a2');
-- 8. nova devolução parcial: a soma passa do faturado (13.300 - 2.300 = 11.000 restantes): ERRO esperado
SELECT core_comissao.fn_comissao_devolucao_pendencia_abrir(:'id_nf') AS id_pend2 \gset
SELECT core_comissao.fn_comissao_devolucao_informar(:'id_pend2', '[{"codigo_item_omie":501,"quantidade":40,"valor":9200},{"codigo_item_omie":502,"quantidade":1,"valor":1800},{"codigo_item_omie":501,"quantidade":1,"valor":230}]'::jsonb, 'CONTROLADORIA', '00000000-0000-0000-0000-0000000000a2');
-- 9. devolução total: abate o que resta (100 - 17,2932) e fecha a pendência parcial aberta
SELECT core_comissao.fn_comissao_devolucao_total(:'id_nf', '00000000-0000-0000-0000-0000000000a2') AS id_lanc_total \gset
SELECT tipo, origem, proporcao_pct, estado FROM core_comissao.comissao_lancamentos WHERE id = :'id_lanc_total'::uuid;
SELECT sum(proporcao_pct) AS soma_abatida_100, count(*) FILTER (WHERE origem = 'DEVOLUCAO') AS lancamentos_devolucao FROM core_comissao.comissao_lancamentos WHERE id_comissao_nf = :'id_nf' AND tipo = 'ABATIMENTO';
SELECT count(*) AS pendencias_abertas_restantes FROM core_comissao.comissao_devolucao_pendencia WHERE id_comissao_nf = :'id_nf' AND estado = 'ABERTA';
-- 10. devolução total de novo: ERRO esperado
SELECT core_comissao.fn_comissao_devolucao_total(:'id_nf');
