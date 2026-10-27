-- SQL-018 · anexo 0007 · teste do 0006 (comissão do pedido digitado direto no Omie e sequenciais), 26/10/2026.
-- Rodar num banco descartável: 0000-stubs-de-teste.sql, 0001, 0004, 0006 e este arquivo (os testes 0002 e 0005 continuam valendo).
-- Tudo numa transação que termina em ROLLBACK, na unidade de Uberaba (para não cruzar com os parâmetros do teste 0002).
-- Cada ERRO ESPERADO imprime "OK erro esperado: ..."; qualquer exceção inesperada para o script.
\set ON_ERROR_STOP on
BEGIN;
CREATE FUNCTION pg_temp.espera(p_sql text, p_prefixo text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE p_sql;
  RAISE EXCEPTION 'FALHOU: era esperado o erro % mas nada aconteceu', p_prefixo;
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM LIKE 'FALHOU%' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE p_prefixo || '%' THEN RAISE EXCEPTION 'FALHOU: esperado %, veio %', p_prefixo, SQLERRM; END IF;
  RAISE NOTICE 'OK erro esperado: %', left(SQLERRM, 90);
END $$;
CREATE FUNCTION pg_temp.confere(p_ok boolean, p_msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF p_ok IS NOT TRUE THEN RAISE EXCEPTION 'FALHOU: %', p_msg; END IF; RAISE NOTICE 'OK: %', p_msg; END $$;

-- ── base: unidade de Uberaba, usuários e parâmetros sem conferência de Compras
INSERT INTO core.unidades VALUES ('4ec9f957-73bb-43a1-8435-4e30a97533d6','Aços Uberaba') ON CONFLICT DO NOTHING;
INSERT INTO auth.usuarios VALUES ('00000000-0000-0000-0000-0000000000a1'),('00000000-0000-0000-0000-0000000000a2') ON CONFLICT DO NOTHING;
INSERT INTO core_comissao.parametros (id, codigo_empresa, vigencia_inicio, descricao, margem_desejada_pct, despesas_operacionais_pct, rateio_logistica_pct, provisao_comissao_pct, pis_pct, cofins_pct, irpj_base_pct, irpj_pct, csll_base_pct, csll_pct, adicional_ir_pct, fabricacao_interna_pct, exige_conferencia_compras)
VALUES ('00000000-0000-7000-8000-0000000000f1','4ec9f957-73bb-43a1-8435-4e30a97533d6','2026-01-01','Teste 0007',10,11,1.4,2,0.65,3,8,15,12,9,0.76,2,false);
INSERT INTO core_comissao.parametros_faixas (id_parametros,letra,margem_min_pct,comissao_pct) SELECT '00000000-0000-7000-8000-0000000000f1',l,m,c FROM (VALUES ('A',15,2),('B',12,1.3),('C',9,0.7),('D',0,0.5)) v(l,m,c);
INSERT INTO core_comissao.parametros_icms_saida (id_parametros,destino,rotulo,aliquota_pct) VALUES ('00000000-0000-7000-8000-0000000000f1','MG','Minas Gerais',12);
INSERT INTO core_comissao.parametros_icms_entrada (id_parametros,origem_compra,aliquota_pct) VALUES ('00000000-0000-7000-8000-0000000000f1','OUTRA_UF',12);
INSERT INTO core_comissao.parametros_encargos_pagamento (id_parametros,condicao_pagamento,encargo_pct) VALUES ('00000000-0000-7000-8000-0000000000f1','28/45',1.5);

-- ── pedido 7001 digitado no Omie, quebrado em dois sequenciais: o original fica com a casca (quantidade 0) e cada sequencial
--    traz linha NOVA com o mesmo produto (N16-100). NF 9301 = sequencial 1 (10 chapas e 5 tubos); NF 9302 = sequencial 2 (10 chapas).
INSERT INTO core_vendas_faturamento.pedidos_vendas (codigo_empresa, numero_pedido, sequencial, codigo_vendedor_omie, codigo_cliente) VALUES
  ('4ec9f957-73bb-43a1-8435-4e30a97533d6','7001',0,'V7','CL7'), ('4ec9f957-73bb-43a1-8435-4e30a97533d6','7001',1,'V7','CL7'),
  ('4ec9f957-73bb-43a1-8435-4e30a97533d6','7001',2,'V7','CL7');
INSERT INTO core_vendas_faturamento.notas_fiscais VALUES ('4ec9f957-73bb-43a1-8435-4e30a97533d6',9301,'00009301','2026-10-21',NULL),
                                                         ('4ec9f957-73bb-43a1-8435-4e30a97533d6',9302,'00009302','2026-10-22',NULL);
INSERT INTO core_vendas_faturamento.produto_vendas (codigo_empresa, codigo_nf_omie, codigo_item_omie, quantidade, valor_total, numero_pedido, codigo_produto_omie) VALUES
  ('4ec9f957-73bb-43a1-8435-4e30a97533d6',NULL,701,0,0,'7001','P-CHAPA'),
  ('4ec9f957-73bb-43a1-8435-4e30a97533d6',9301,702,10,2000,'7001','P-CHAPA'),
  ('4ec9f957-73bb-43a1-8435-4e30a97533d6',9301,704,5,1000,'7001','P-TUBO'),
  ('4ec9f957-73bb-43a1-8435-4e30a97533d6',9302,703,10,2000,'7001','P-CHAPA');

-- ── 1. abrir o dossiê do pedido do Omie: nasce ESTIMADA, esperando a simulação do vendedor (N16-104)
SELECT pg_temp.espera($$SELECT core_comissao.fn_comissao_abrir_pedido_omie('4ec9f957-73bb-43a1-8435-4e30a97533d6','9999')$$, 'PEDIDO_NAO_ENCONTRADO');
SELECT core_comissao.fn_comissao_abrir_pedido_omie('4ec9f957-73bb-43a1-8435-4e30a97533d6','7001', NULL, '00000000-0000-0000-0000-0000000000a1') AS com \gset
SELECT core_comissao.fn_comissao_abrir_pedido_omie('4ec9f957-73bb-43a1-8435-4e30a97533d6','7001') AS com2 \gset
SELECT pg_temp.confere(:'com' = :'com2', 'abrir de novo devolve o mesmo dossiê');
SELECT pg_temp.confere((SELECT origem='PEDIDO_OMIE' AND estado='ESTIMADA' AND id_proposta IS NULL AND numero_proposta IS NULL
                               AND codigo_vendedor_omie='V7' AND codigo_cliente='CL7' FROM core_comissao.comissoes WHERE id=:'com'),
                       'dossiê do pedido do Omie nasce ESTIMADA, sem proposta, com vendedor e cliente do original');
SELECT pg_temp.confere((SELECT situacao='SIMULACAO_PENDENTE' FROM core_comissao.vw_comissao_vendedor WHERE id_comissao=:'com'),
                       'o vendedor vê que precisa preencher a simulação');
SELECT pg_temp.espera($$INSERT INTO core_comissao.comissoes (codigo_empresa, origem, codigo_vendedor_omie, codigo_cliente)
                        VALUES ('4ec9f957-73bb-43a1-8435-4e30a97533d6','PEDIDO_OMIE','V7','CL7')$$, 'new row for relation "comissoes" violates check constraint "ck_comissoes_origem_omie"');
SELECT pg_temp.espera(format($$SELECT core_comissao.fn_comissao_nf_fechar(%L, 9301)$$, :'com'), 'Comissão fecha NF só EM_ACOMPANHAMENTO');

-- ── 2. o custo real chega ANTES da simulação (N16-105): chapa com 12 de 20 cobertas (letra B, 1,3%); tubo ainda sem custo real
SELECT core_comissao.fn_calculo_gravar(format($j${"id_comissao":"%s","tipo":"REAL","gatilho":"CUSTO_REAL","id_parametros":"00000000-0000-7000-8000-0000000000f1","versao_motor":"motor-1.0.0",
  "cabecalho":{"estado_destino":"MG","icms_destino_pct":12,"condicao_pagamento":"28/45","encargo_pagamento_pct":1.5,"custo_total":3500,"venda_sugerida":0,"valor_liquido":5000,"total_nf":5000,"markup_bruto_pct":60,"margem_liquida_pct":12.5,"lucro":600,"letra_equivalente":"B","comissao_efetiva_pct":1.3,"valor_comissao_total":65,"qtd_itens":2,"custo_completo":false},
  "itens":[
   {"ordem":1,"codigo_produto":"P-CHAPA","descricao":"Chapa","qtd":20,"preco_unit_compra_cotado":100,"preco_unit_venda":200,"quantidade_coberta":12,"custo_real_total":1800,"custo_real_unitario_medio":150,"custo_completo":false,"qtd_eventos":1,"qtd_descoberta":8,"custo_liquido_descoberto":800,"compra_bruta":2600,"custo_liquido":2600,"venda_item":4000,"margem_item_pct":12.5,"letra_item":"B","comissao_letra_pct":1.3,"comissao_pct":1.3,"regra_aplicada":"LETRA","valor_comissao_estimado":52},
   {"ordem":2,"codigo_produto":"P-TUBO","descricao":"Tubo","qtd":5,"preco_unit_compra_cotado":140,"preco_unit_venda":200,"quantidade_coberta":0,"custo_completo":false,"qtd_descoberta":5,"custo_liquido_descoberto":700,"custo_liquido":700,"venda_item":1000,"margem_item_pct":12.5,"letra_item":"B","comissao_letra_pct":1.3,"comissao_pct":1.3,"regra_aplicada":"LETRA","valor_comissao_estimado":13}]}$j$, :'com')::jsonb) AS calc \gset

SELECT pg_temp.espera(format($$SELECT core_comissao.fn_comissao_nf_fechar(%L, 9301)$$, :'com'), 'Comissão fecha NF só EM_ACOMPANHAMENTO');
SELECT pg_temp.confere((SELECT count(*)=2 AND bool_and(margem_real_pct=12.5 AND letra_real='B') AND sum(valor_faturado)=5000
                          FROM core_comissao.vw_comissao_nf_aguardando_simulacao WHERE id_comissao=:'com'),
                       'as duas notas esperam a simulação, e a Controladoria já vê a margem real (12,5%, letra B)');

-- ── 3. a simulação do vendedor (COTADO), item = produto; item com id_item_proposta é recusado
SELECT pg_temp.espera(format($j$SELECT core_comissao.fn_calculo_gravar('{"id_comissao":"%s","tipo":"COTADO","gatilho":"PROPOSTA_SALVA","id_parametros":"00000000-0000-7000-8000-0000000000f1","versao_motor":"motor-1.0.0",
  "cabecalho":{"estado_destino":"MG","icms_destino_pct":12,"condicao_pagamento":"28/45","encargo_pagamento_pct":1.5,"custo_total":1,"venda_sugerida":0,"valor_liquido":1,"total_nf":1,"markup_bruto_pct":1,"margem_liquida_pct":1,"lucro":0,"comissao_efetiva_pct":1,"valor_comissao_total":0,"qtd_itens":1},
  "itens":[{"ordem":1,"id_item_proposta":"00000000-0000-7000-8000-0000000009a1","codigo_produto":"P-CHAPA","qtd":20,"preco_unit_venda":200,"venda_item":4000,"comissao_letra_pct":2,"comissao_pct":2,"regra_aplicada":"LETRA","valor_comissao_estimado":80}]}'::jsonb)$j$, :'com'),
  'ITEM_DO_PEDIDO_OMIE');
SELECT core_comissao.fn_calculo_gravar(format($j${"id_comissao":"%s","tipo":"COTADO","gatilho":"PROPOSTA_SALVA","id_parametros":"00000000-0000-7000-8000-0000000000f1","versao_motor":"motor-1.0.0",
  "cabecalho":{"estado_destino":"MG","icms_destino_pct":12,"condicao_pagamento":"28/45","encargo_pagamento_pct":1.5,"custo_total":2700,"venda_sugerida":0,"valor_liquido":5000,"total_nf":5000,"markup_bruto_pct":85,"margem_liquida_pct":16,"lucro":800,"letra_equivalente":"A","comissao_efetiva_pct":1.86,"valor_comissao_total":93,"qtd_itens":2},
  "itens":[
   {"ordem":1,"codigo_produto":"P-CHAPA","descricao":"Chapa","qtd":20,"preco_unit_compra_cotado":100,"preco_unit_venda":200,"compra_bruta":2000,"custo_liquido":2000,"venda_item":4000,"margem_item_pct":16,"letra_item":"A","comissao_letra_pct":2,"comissao_pct":2,"regra_aplicada":"LETRA","valor_comissao_estimado":80},
   {"ordem":2,"codigo_produto":"P-TUBO","descricao":"Tubo","qtd":5,"preco_unit_compra_cotado":140,"preco_unit_venda":200,"compra_bruta":700,"custo_liquido":700,"venda_item":1000,"margem_item_pct":12.5,"letra_item":"B","comissao_letra_pct":1.3,"comissao_pct":1.3,"regra_aplicada":"LETRA","valor_comissao_estimado":13}]}$j$, :'com')::jsonb) AS cot \gset
SELECT pg_temp.confere((SELECT situacao='ESTIMADA' AND valor_estimado=93 FROM core_comissao.vw_comissao_vendedor WHERE id_comissao=:'com'),
                       'com a simulação preenchida, o vendedor vê a comissão estimada (R$ 93,00)');
-- o vendedor confirma a simulação: CONGELADA e, como o pedido já existe, EM_ACOMPANHAMENTO
SELECT core_comissao.fn_comissao_mudar_estado(:'com','CONGELADA','00000000-0000-0000-0000-0000000000a1');
SELECT core_comissao.fn_comissao_mudar_estado(:'com','EM_ACOMPANHAMENTO','00000000-0000-0000-0000-0000000000a1');
SELECT pg_temp.espera(format($$SELECT core_comissao.fn_calculo_gravar('{"id_comissao":"%s","tipo":"COTADO","itens":[{}]}'::jsonb)$$, :'com'), 'A estimativa só muda');
SELECT pg_temp.confere(NOT EXISTS (SELECT 1 FROM core_comissao.vw_comissao_nf_aguardando_simulacao WHERE id_comissao=:'com'),
                       'com a simulação preenchida, as notas saem da lista de espera');

-- ── 4. NF 9301: 10 chapas comissionadas a 1,3% (o menor entre 2% do vendedor e 1,3% do real); o tubo sem custo fica pendente
SELECT core_comissao.fn_comissao_nf_fechar(:'com', 9301) AS nf1 \gset
SELECT pg_temp.confere((SELECT valor_faturado=3000 AND valor_calculado=26.00 AND valor_pendente_custo=13.00 AND valor_se_cotado=53.00 AND queda_por_custo=14.00
                               AND id_calculo_cotado = :'cot'::uuid AND NOT custo_completo FROM core_comissao.comissoes_nf WHERE id=:'nf1'),
                       'NF 9301: R$ 26,00 calculados, R$ 13,00 pendentes (tubo sem custo), R$ 14,00 de queda contra a simulação de 2%');
SELECT pg_temp.confere((SELECT bool_and(id_item_cotado IS NOT NULL) AND count(*)=2
                               AND sum(quantidade_comissionavel) FILTER (WHERE codigo_produto_omie='P-CHAPA') = 10
                               AND max(comissao_final_pct) FILTER (WHERE codigo_produto_omie='P-CHAPA') = 1.3
                          FROM core_comissao.comissoes_nf_itens WHERE id_comissao_nf=:'nf1'),
                       'itens da NF: chave pelo produto, percentual final = o menor');

-- ── 5. NF 9302 (outro sequencial, outra linha do mesmo produto): só restam 2 chapas cobertas (12 - 10)
SELECT core_comissao.fn_comissao_nf_fechar(:'com', 9302) AS nf2 \gset
SELECT pg_temp.confere((SELECT valor_calculado=5.20 AND valor_pendente_custo=32.00 FROM core_comissao.comissoes_nf WHERE id=:'nf2'),
                       'NF 9302: 2 de 10 chapas comissionadas (R$ 5,20) e 8 pendentes (R$ 32,00 à taxa do vendedor): a mesma peça não é paga duas vezes entre sequenciais');
SELECT core_comissao.fn_comissao_nf_fechar(:'com', 9302) AS nf2b \gset
SELECT pg_temp.confere((SELECT valor_calculado=5.20 FROM core_comissao.comissoes_nf WHERE id=:'nf2b'), 'refazer a NF antes da decisão dá o mesmo valor');

-- ── 6. telas: Controladoria vê o par simulação × real; o vendedor vê a estimada
SELECT pg_temp.confere((SELECT count(*)=2 AND bool_and(origem='PEDIDO_OMIE' AND letra_cotada='A') FROM core_comissao.vw_comissao_nf_fila WHERE id_comissao=:'com'),
                       'as duas NFs estão na fila da Controladoria, com a letra da simulação');
SELECT pg_temp.confere((SELECT count(*)=2 AND bool_and(comissao_real_pct IS NOT NULL AND comissao_final_pct = LEAST(comissao_cotada_pct, comissao_real_pct))
                          FROM core_comissao.vw_comissao_itens_custo WHERE id_comissao=:'com'),
                       'itens: simulação e real casados pelo produto');
SELECT pg_temp.confere((SELECT situacao='ESTIMADA' AND valor_estimado=93 FROM core_comissao.vw_comissao_vendedor WHERE id_comissao=:'com'),
                       'o vendedor continua vendo só a estimada até a decisão');
SELECT pg_temp.confere((SELECT faturamento=5000 AND faturamento_revenda=5000 FROM core_comissao.vw_comissao_faturamento_x_compras WHERE id_comissao=:'com'),
                       'Faturamento x Compras soma o pedido do Omie');

-- ── 7. decisão: ninguém decide a própria comissão; a Controladoria aprova (conferência de Compras desligada nos parâmetros)
SELECT pg_temp.espera(format($$SELECT core_comissao.fn_comissao_decidir(%L,'APROVAR','Aprovada conforme o cálculo','00000000-0000-0000-0000-0000000000a1')$$, :'nf1'), 'Ninguém decide sobre a própria comissão');
SELECT core_comissao.fn_comissao_decidir(:'nf1','APROVAR','Aprovada conforme o cálculo','00000000-0000-0000-0000-0000000000a2');
SELECT pg_temp.confere((SELECT estado='APROVADA' AND valor_final=26.00 FROM core_comissao.comissoes_nf WHERE id=:'nf1'), 'NF do pedido do Omie aprovada');

-- ── 8. pedido que nasceu de proposta não abre dossiê pelo Omie
INSERT INTO core_vendas_faturamento.pedidos_vendas (codigo_empresa, numero_pedido, sequencial, codigo_vendedor_omie, codigo_cliente) VALUES
  ('4ec9f957-73bb-43a1-8435-4e30a97533d6','7002',0,'V8','CL8'), ('4ec9f957-73bb-43a1-8435-4e30a97533d6','7002',1,'V8','CL8');
INSERT INTO core_comissao.comissoes (id, codigo_empresa, id_proposta, numero_proposta, codigo_vendedor_omie, codigo_cliente)
VALUES ('00000000-0000-7000-8000-0000000000c7','4ec9f957-73bb-43a1-8435-4e30a97533d6','00000000-0000-7000-8000-0000000000b7','CO-AU2026-0007','V8','CL8');
SELECT core_comissao.fn_calculo_gravar($j${"id_comissao":"00000000-0000-7000-8000-0000000000c7","tipo":"COTADO","gatilho":"PROPOSTA_SALVA","id_parametros":"00000000-0000-7000-8000-0000000000f1","versao_motor":"motor-1.0.0",
  "cabecalho":{"estado_destino":"MG","icms_destino_pct":12,"condicao_pagamento":"28/45","encargo_pagamento_pct":1.5,"custo_total":700,"venda_sugerida":0,"valor_liquido":1000,"total_nf":1000,"markup_bruto_pct":40,"margem_liquida_pct":16,"lucro":160,"letra_equivalente":"A","comissao_efetiva_pct":2,"valor_comissao_total":20,"qtd_itens":1},
  "itens":[{"ordem":1,"id_item_proposta":"00000000-0000-7000-8000-0000000007a1","codigo_produto":"P-BARRA","qtd":10,"preco_unit_compra_cotado":70,"preco_unit_venda":100,"venda_item":1000,"comissao_letra_pct":2,"comissao_pct":2,"regra_aplicada":"LETRA","valor_comissao_estimado":20}]}$j$::jsonb);
SELECT core_comissao.fn_comissao_mudar_estado('00000000-0000-7000-8000-0000000000c7','CONGELADA','00000000-0000-0000-0000-0000000000a2');
SELECT core_comissao.fn_comissao_mudar_estado('00000000-0000-7000-8000-0000000000c7','EM_ACOMPANHAMENTO','00000000-0000-0000-0000-0000000000a2','00000000-0000-7000-8000-0000000000d7','7002');
SELECT pg_temp.espera($$SELECT core_comissao.fn_comissao_abrir_pedido_omie('4ec9f957-73bb-43a1-8435-4e30a97533d6','7002')$$, 'PEDIDO_TEM_PROPOSTA');
SELECT pg_temp.espera(format($j$SELECT core_comissao.fn_calculo_gravar('{"id_comissao":"00000000-0000-7000-8000-0000000000c7","tipo":"REAL","gatilho":"CUSTO_REAL","id_parametros":"00000000-0000-7000-8000-0000000000f1","versao_motor":"motor-1.0.0",
  "cabecalho":{"estado_destino":"MG","icms_destino_pct":12,"condicao_pagamento":"28/45","encargo_pagamento_pct":1.5,"custo_total":1,"venda_sugerida":0,"valor_liquido":1,"total_nf":1,"markup_bruto_pct":1,"margem_liquida_pct":1,"lucro":0,"comissao_efetiva_pct":1,"valor_comissao_total":0,"qtd_itens":1},
  "itens":[{"ordem":1,"codigo_produto":"P-BARRA","qtd":10,"preco_unit_venda":100,"venda_item":1000,"comissao_letra_pct":1,"comissao_pct":1,"regra_aplicada":"LETRA","valor_comissao_estimado":10}]}'::jsonb)$j$), 'ITEM_DA_PROPOSTA');

-- ── 9. proposta + sequencial: a NF fatura a linha NOVA 802 do sequencial; a terceira tabela a devolve à linha 801 do original
SELECT core_comissao.fn_calculo_gravar($j${"id_comissao":"00000000-0000-7000-8000-0000000000c7","tipo":"REAL","gatilho":"CUSTO_REAL","id_parametros":"00000000-0000-7000-8000-0000000000f1","versao_motor":"motor-1.0.0",
  "cabecalho":{"estado_destino":"MG","icms_destino_pct":12,"condicao_pagamento":"28/45","encargo_pagamento_pct":1.5,"custo_total":800,"venda_sugerida":0,"valor_liquido":1000,"total_nf":1000,"markup_bruto_pct":25,"margem_liquida_pct":10,"lucro":100,"letra_equivalente":"C","comissao_efetiva_pct":0.7,"valor_comissao_total":7,"qtd_itens":1,"custo_completo":true},
  "itens":[{"ordem":1,"id_item_proposta":"00000000-0000-7000-8000-0000000007a1","codigo_produto":"P-BARRA","qtd":10,"preco_unit_compra_cotado":70,"preco_unit_venda":100,"quantidade_coberta":10,"custo_real_total":800,"custo_completo":true,"venda_item":1000,"comissao_letra_pct":0.7,"comissao_pct":0.7,"regra_aplicada":"LETRA","valor_comissao_estimado":7}]}$j$::jsonb);
SELECT core_comissao.fn_comissao_vincular_itens('00000000-0000-7000-8000-0000000000c7','[{"id_item_proposta":"00000000-0000-7000-8000-0000000007a1","id_item_pedido":"00000000-0000-7000-8000-0000000007b1","codigo_item_omie":801}]'::jsonb);
INSERT INTO core_vendas_faturamento.pedidos_vendas_sequenciais_itens VALUES ('4ec9f957-73bb-43a1-8435-4e30a97533d6', 802, 801);
INSERT INTO core_vendas_faturamento.notas_fiscais VALUES ('4ec9f957-73bb-43a1-8435-4e30a97533d6',9401,'00009401','2026-10-23',NULL);
INSERT INTO core_vendas_faturamento.produto_vendas (codigo_empresa, codigo_nf_omie, codigo_item_omie, quantidade, valor_total, numero_pedido, codigo_produto_omie) VALUES
  ('4ec9f957-73bb-43a1-8435-4e30a97533d6',NULL,801,6,600,'7002','P-BARRA'),
  ('4ec9f957-73bb-43a1-8435-4e30a97533d6',9401,802,4,400,'7002','P-BARRA');
SELECT core_comissao.fn_comissao_nf_fechar('00000000-0000-7000-8000-0000000000c7', 9401) AS nf3 \gset
SELECT pg_temp.confere((SELECT qtd_itens=1 AND qtd_itens_sem_vinculo=0 AND valor_calculado=2.80 AND valor_se_cotado=8.00 AND queda_por_custo=5.20
                          FROM core_comissao.comissoes_nf WHERE id=:'nf3'),
                       'linha do sequencial casa com o item da proposta: R$ 2,80 (400 x 0,7%), queda de R$ 5,20 contra o cotado de 2%');

\echo 'TESTE DO 0006 (COMISSAO DO PEDIDO DIGITADO NO OMIE): TUDO OK'
ROLLBACK;
