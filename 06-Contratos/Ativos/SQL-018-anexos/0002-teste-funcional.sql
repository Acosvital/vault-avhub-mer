-- Teste funcional do SQL-018 em banco descartável (PostgreSQL 18). Rodar 0000-stubs-de-teste.sql, depois 0001-core-comissao.sql, depois este arquivo.
-- Os ERROR que aparecem são os testes negativos esperados (14, 9 do primeiro cenário e 5 do segundo, que começa em "Respostas da Controladoria"): parâmetro fora do dia 1, REAL antes do pedido, COTADO depois de aprovada, UPDATE em evento, APROVAR sem conferência de Compras, CONTESTAR com justificativa curta, segunda decisão, refazer NF decidida, cancelar a comissão com NF, cancelar NF já decidida.
\set ON_ERROR_STOP off
\pset pager off
SET client_min_messages = warning;
-- parâmetros Maio/23 completos
BEGIN;
INSERT INTO core_comissao.parametros (id, codigo_empresa, vigencia_inicio, descricao, margem_desejada_pct, despesas_operacionais_pct, rateio_logistica_pct, provisao_comissao_pct, pis_pct, cofins_pct, irpj_base_pct, irpj_pct, csll_base_pct, csll_pct, adicional_ir_pct, fabricacao_interna_pct, exige_conferencia_compras)
VALUES ('00000000-0000-7000-8000-000000000001','759979bd-2b2d-41f2-b1b7-db6fae89ee59','2023-05-01','Maio/23',10,11.451734,1.438975,2,0.65,3,8,15,12,9,0.76,2,true);
INSERT INTO core_comissao.parametros_faixas (id_parametros,letra,margem_min_pct,comissao_pct) SELECT '00000000-0000-7000-8000-000000000001',l,m,c FROM (VALUES ('A',15,2),('B',12,1.3),('C',9,0.7),('D',0,0.5)) v(l,m,c);
INSERT INTO core_comissao.parametros_icms_saida (id_parametros,destino,rotulo,aliquota_pct) VALUES ('00000000-0000-7000-8000-000000000001','MG','Minas Gerais',12),('00000000-0000-7000-8000-000000000001','SP','São Paulo',18);
INSERT INTO core_comissao.parametros_icms_entrada (id_parametros,origem_compra,aliquota_pct) VALUES ('00000000-0000-7000-8000-000000000001','OUTRA_UF',12),('00000000-0000-7000-8000-000000000001','SIMPLES',0);
INSERT INTO core_comissao.parametros_encargos_pagamento (id_parametros,condicao_pagamento,encargo_pct) VALUES ('00000000-0000-7000-8000-000000000001','28/45',1.5);
COMMIT;
SELECT 'param ok', count(*) FROM core_comissao.parametros;
-- parâmetro em dia que não é 1: deve falhar
INSERT INTO core_comissao.parametros (codigo_empresa, vigencia_inicio, descricao, margem_desejada_pct, despesas_operacionais_pct, rateio_logistica_pct, provisao_comissao_pct, pis_pct, cofins_pct, irpj_base_pct, irpj_pct, csll_base_pct, csll_pct, adicional_ir_pct, fabricacao_interna_pct)
VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59','2023-06-15','Jun',1,1,1,1,1,1,1,1,1,1,1,1);

INSERT INTO core_comissao.comissoes (id,codigo_empresa,id_proposta,numero_proposta,codigo_vendedor_omie,codigo_cliente)
VALUES ('00000000-0000-7000-8000-0000000000c1','759979bd-2b2d-41f2-b1b7-db6fae89ee59','00000000-0000-7000-8000-0000000000b1','1001','V1','CL1');

-- COTADO
SELECT core_comissao.fn_calculo_gravar($j${
 "id_comissao":"00000000-0000-7000-8000-0000000000c1","tipo":"COTADO","gatilho":"PROPOSTA_SALVA","id_parametros":"00000000-0000-7000-8000-000000000001","versao_motor":"motor-1.0.0",
 "cabecalho":{"estado_destino":"MG","icms_destino_pct":12,"condicao_pagamento":"28/45","encargo_pagamento_pct":1.5,"custo_total":8273.34,"venda_sugerida":8000,"valor_liquido":13300,"total_nf":13300,"markup_projetado":1,"markup_real":2.5,"markup_bruto_pct":120,"margem_liquida_pct":29.41,"lucro":3382.12,"letra_equivalente":"A","comissao_efetiva_pct":2,"valor_comissao_total":266,"qtd_itens":2},
 "itens":[
  {"ordem":1,"id_item_proposta":"00000000-0000-7000-8000-0000000001a1","codigo_produto":"FLG","descricao":"Flange A","tipo_item":"REVENDA","qtd":50,"qtd_compra":50,"origem_compra":"OUTRA_UF","preco_unit_compra_cotado":100,"preco_unit_venda":230,"compra_bruta":5000,"icms_entrada_pct":12,"icms_recuperar":600,"frete_item":71.95,"custo_liquido":4471.95,"venda_item":11500,"preco_total_sugerido":7800,"lucro_item":3382.12,"margem_item_pct":29.41,"letra_item":"A","comissao_letra_pct":2,"comissao_pct":2,"regra_aplicada":"LETRA","valor_comissao_estimado":230},
  {"ordem":2,"id_item_proposta":"00000000-0000-7000-8000-0000000001a2","descricao":"Flange sobre desenho","tipo_item":"FABRICACAO_INTERNA","qtd":1,"preco_unit_venda":1800,"venda_item":1800,"comissao_letra_pct":2,"comissao_pct":2,"regra_aplicada":"FABRICACAO_INTERNA","valor_comissao_estimado":36}]}$j$::jsonb);
-- REAL antes do pedido: deve falhar
SELECT core_comissao.fn_calculo_gravar('{"id_comissao":"00000000-0000-7000-8000-0000000000c1","tipo":"REAL","itens":[{}]}'::jsonb);
SELECT core_comissao.fn_comissao_mudar_estado('00000000-0000-7000-8000-0000000000c1','CONGELADA','00000000-0000-0000-0000-0000000000a1');
-- COTADO depois de aprovada: deve falhar
SELECT core_comissao.fn_calculo_gravar('{"id_comissao":"00000000-0000-7000-8000-0000000000c1","tipo":"COTADO","itens":[{}]}'::jsonb);
SELECT core_comissao.fn_comissao_mudar_estado('00000000-0000-7000-8000-0000000000c1','EM_ACOMPANHAMENTO','00000000-0000-0000-0000-0000000000a1','00000000-0000-7000-8000-0000000000d1','2001');

-- REAL com 3 eventos (dias 01 a 03) + 1 evento
SELECT core_comissao.fn_calculo_gravar($j${
 "id_comissao":"00000000-0000-7000-8000-0000000000c1","tipo":"REAL","gatilho":"CUSTO_REAL","id_parametros":"00000000-0000-7000-8000-000000000001","versao_motor":"motor-1.0.0",
 "cabecalho":{"estado_destino":"MG","icms_destino_pct":12,"condicao_pagamento":"28/45","encargo_pagamento_pct":1.5,"custo_total":6707.92,"venda_sugerida":0,"valor_liquido":13300,"total_nf":13300,"markup_bruto_pct":80,"margem_liquida_pct":9.97,"lucro":1146.15,"letra_equivalente":"C","comissao_efetiva_pct":0.7,"valor_comissao_total":116.5,"qtd_itens":2,"custo_completo":true,"imposto_completo":false},
 "itens":[
  {"ordem":1,"id_item_proposta":"00000000-0000-7000-8000-0000000001a1","id_item_pedido":"00000000-0000-7000-8000-0000000002a1","codigo_item_omie":501,"descricao":"Flange A","tipo_item":"REVENDA","qtd":50,"qtd_compra":50,"preco_unit_compra_cotado":100,"preco_unit_venda":230,"quantidade_coberta":50,"custo_real_total":7500,"custo_real_unitario_medio":150,"custo_completo":true,"qtd_eventos":3,"qtd_descoberta":0,"custo_liquido_descoberto":0,"imposto_completo":false,"custo_real_acima_cotado":true,"compra_bruta":7500,"custo_liquido":6707.92,"venda_item":11500,"lucro_item":1146.15,"margem_item_pct":9.97,"letra_item":"C","comissao_letra_pct":0.7,"comissao_pct":0.7,"regra_aplicada":"LETRA","valor_comissao_estimado":80.5,
   "eventos":[
    {"ordem":1,"id_custo_evento":"00000000-0000-7000-8000-0000000003e1","data_evento":"2026-10-01","origem":"OC_MATERIAL","numero_documento":"OC-000101","fornecedor":"Forn A","quantidade_coberta":10,"valor_unitario":140,"valor_total":1400,"condicao_pagamento":"30 DDL","encargo_pagamento_pct":1,"origem_compra":"OUTRA_UF","compra_bruta":1400,"icms_entrada_pct":12,"icms_recuperar":168,"frete_evento":20.14,"custo_liquido":1252.14},
    {"ordem":2,"id_custo_evento":"00000000-0000-7000-8000-0000000003e2","data_evento":"2026-10-02","origem":"OC_MATERIAL","numero_documento":"OC-000102","fornecedor":"Forn B","quantidade_coberta":20,"valor_unitario":150,"valor_total":3000,"condicao_pagamento":"28/45","encargo_pagamento_pct":1.5,"frete_tipo":"VALOR","frete_valor":90,"origem_compra":"OUTRA_UF","compra_bruta":3000,"icms_entrada_pct":12,"icms_recuperar":360,"frete_evento":90,"custo_liquido":2730},
    {"ordem":3,"id_custo_evento":"00000000-0000-7000-8000-0000000003e3","data_evento":"2026-10-03","origem":"OC_MATERIAL","numero_documento":"OC-000103","fornecedor":"Forn C","quantidade_coberta":20,"valor_unitario":155,"valor_total":3100,"condicao_pagamento":"À Vista","encargo_pagamento_pct":0,"origem_compra":"OUTRA_UF","compra_bruta":3100,"icms_entrada_pct":12,"icms_recuperar":372,"frete_evento":44.6,"custo_liquido":2772.6}]},
  {"ordem":2,"id_item_proposta":"00000000-0000-7000-8000-0000000001a2","id_item_pedido":"00000000-0000-7000-8000-0000000002a2","codigo_item_omie":502,"descricao":"Flange sobre desenho","tipo_item":"FABRICACAO_INTERNA","qtd":1,"preco_unit_venda":1800,"venda_item":1800,"comissao_letra_pct":2,"comissao_pct":2,"regra_aplicada":"FABRICACAO_INTERNA","valor_comissao_estimado":36}]}$j$::jsonb);
SELECT count(*) AS eventos_gravados FROM core_comissao.comissao_calculo_eventos;
SELECT ordem_item, ordem_evento, fornecedor, condicao_pagamento, custo_liquido FROM core_comissao.vw_comissao_eventos_custo ORDER BY 2;
-- imutabilidade do evento
UPDATE core_comissao.comissao_calculo_eventos SET custo_liquido = 1;

-- vínculo e NF
SELECT core_comissao.fn_comissao_vincular_itens('00000000-0000-7000-8000-0000000000c1','[{"id_item_proposta":"00000000-0000-7000-8000-0000000001a1","id_item_pedido":"00000000-0000-7000-8000-0000000002a1","codigo_item_omie":501},{"id_item_proposta":"00000000-0000-7000-8000-0000000001a2","id_item_pedido":"00000000-0000-7000-8000-0000000002a2","codigo_item_omie":502}]'::jsonb);
INSERT INTO core_vendas_faturamento.notas_fiscais VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59',9001,'00051698','2026-10-20',NULL);
INSERT INTO core_vendas_faturamento.produto_vendas VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59',9001,501,50,11500,NULL),('759979bd-2b2d-41f2-b1b7-db6fae89ee59',9001,502,1,1800,NULL);
SELECT core_comissao.fn_comissao_nf_fechar('00000000-0000-7000-8000-0000000000c1',9001) AS id_nf \gset
SELECT valor_faturado, valor_se_cotado, valor_calculado, queda_por_custo, compras_estado, estado FROM core_comissao.comissoes_nf;
SELECT codigo_item_omie, comissao_cotada_pct, comissao_real_pct, comissao_final_pct, valor_calculado FROM core_comissao.comissoes_nf_itens ORDER BY 1;
-- decidir sem Compras: APROVAR deve falhar
SELECT core_comissao.fn_comissao_decidir(:'id_nf','APROVAR','Aprovada conforme o cálculo','00000000-0000-0000-0000-0000000000a2');
-- contestar sem justificativa curta
SELECT core_comissao.fn_comissao_conferir_compras(:'id_nf','CONTESTAR','curta','00000000-0000-0000-0000-0000000000a1');
SELECT core_comissao.fn_comissao_conferir_compras(:'id_nf','CONFIRMAR',NULL,'00000000-0000-0000-0000-0000000000a1');
SELECT compras_estado FROM core_comissao.comissoes_nf;
-- cortar 50% com justificativa
SELECT core_comissao.fn_comissao_decidir(:'id_nf','CORTAR','Cortada pela metade: custo real acima do cotado','00000000-0000-0000-0000-0000000000a2', 50);
SELECT estado, valor_calculado, valor_final FROM core_comissao.comissoes_nf;
-- segunda decisão: deve falhar
SELECT core_comissao.fn_comissao_decidir(:'id_nf','DESAPROVAR','Tentando de novo depois','00000000-0000-0000-0000-0000000000a2');
-- refazer NF decidida: deve falhar
SELECT core_comissao.fn_comissao_nf_fechar('00000000-0000-7000-8000-0000000000c1',9001);
-- visão do vendedor
SELECT situacao, valor_estimado, valor_decidido, qtd_nf_decididas FROM core_comissao.vw_comissao_vendedor;
SELECT situacao, valor_final, decisao, justificativa FROM core_comissao.vw_comissao_nf_vendedor;
SELECT estado, valor_se_cotado, valor_calculado, queda_por_custo, compras_estado, imposto_real_completo FROM core_comissao.vw_comissao_nf_fila;
SELECT valor_bloqueado, valor_a_pagar FROM core_comissao.vw_comissao_resumo_mensal WHERE is_total;
-- cancelar com NF: deve falhar
SELECT core_comissao.fn_comissao_mudar_estado('00000000-0000-7000-8000-0000000000c1','CANCELADA','00000000-0000-0000-0000-0000000000a1',NULL,NULL,'teste');

-- NF cancelada: segunda NF de teste, antes da decisão
INSERT INTO core_vendas_faturamento.notas_fiscais VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59',9002,'00051699','2026-10-21',NULL);
INSERT INTO core_vendas_faturamento.produto_vendas VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59',9002,502,1,10,NULL);
SELECT core_comissao.fn_comissao_nf_fechar('00000000-0000-7000-8000-0000000000c1',9002) AS id_nf2 \gset
SELECT core_comissao.fn_comissao_nf_cancelar(:'id_nf2');
SELECT estado FROM core_comissao.comissoes_nf WHERE codigo_nf_omie = 9002;
SELECT core_comissao.fn_comissao_nf_cancelar(:'id_nf');

-- ============================================================================
-- Respostas da Controladoria de 19/10/2026 (N16-42 a N16-51): um segundo pedido (comissão c2)
-- Pedido de 50 flanges a R$ 230 (venda 11.500); custo real de só 20 peças; duas NFs; complemento; abatimento;
-- decisão por Gerência e Coordenação; trava "ninguém decide sobre a própria comissão"; bloquear e desbloquear;
-- alterar por percentual; relatórios.
-- Erros esperados neste bloco (5): o dono decide a própria NF, perfil inválido, o dono decide o próprio complemento,
-- complemento em NF ainda não decidida, abatimento que passa de 100%.
-- ============================================================================
INSERT INTO auth.usuarios VALUES ('00000000-0000-0000-0000-0000000000a3'), ('00000000-0000-0000-0000-0000000000a4');

INSERT INTO core_comissao.comissoes (id,codigo_empresa,id_proposta,numero_proposta,codigo_vendedor_omie,codigo_cliente,id_usuario_vendedor)
VALUES ('00000000-0000-7000-8000-0000000000c2','759979bd-2b2d-41f2-b1b7-db6fae89ee59','00000000-0000-7000-8000-0000000000b2','1002','V2','CL2','00000000-0000-0000-0000-0000000000a3');

SELECT core_comissao.fn_calculo_gravar($j${
 "id_comissao":"00000000-0000-7000-8000-0000000000c2","tipo":"COTADO","gatilho":"PROPOSTA_SALVA","id_parametros":"00000000-0000-7000-8000-000000000001","versao_motor":"motor-1.0.0",
 "cabecalho":{"estado_destino":"MG","icms_destino_pct":12,"condicao_pagamento":"28/45","encargo_pagamento_pct":1.5,"custo_total":4471.95,"venda_sugerida":7800,"valor_liquido":11500,"total_nf":11500,"markup_projetado":1,"markup_real":2.5,"markup_bruto_pct":120,"margem_liquida_pct":29.41,"lucro":3382.12,"letra_equivalente":"A","comissao_efetiva_pct":2,"valor_comissao_total":230,"qtd_itens":1},
 "itens":[{"ordem":1,"id_item_proposta":"00000000-0000-7000-8000-0000000001b1","codigo_produto":"FLG","descricao":"Flange A","tipo_item":"REVENDA","qtd":50,"qtd_compra":50,"origem_compra":"OUTRA_UF","preco_unit_compra_cotado":100,"preco_unit_venda":230,"compra_bruta":5000,"icms_entrada_pct":12,"icms_recuperar":600,"frete_item":71.95,"custo_liquido":4471.95,"venda_item":11500,"lucro_item":3382.12,"margem_item_pct":29.41,"letra_item":"A","comissao_letra_pct":2,"comissao_pct":2,"regra_aplicada":"LETRA","valor_comissao_estimado":230}]}$j$::jsonb);
SELECT core_comissao.fn_comissao_mudar_estado('00000000-0000-7000-8000-0000000000c2','CONGELADA','00000000-0000-0000-0000-0000000000a1');
SELECT core_comissao.fn_comissao_mudar_estado('00000000-0000-7000-8000-0000000000c2','EM_ACOMPANHAMENTO','00000000-0000-0000-0000-0000000000a1','00000000-0000-7000-8000-0000000000d2','2002');

-- custo real de SÓ 20 das 50 peças (N16-48)
SELECT core_comissao.fn_calculo_gravar($j${
 "id_comissao":"00000000-0000-7000-8000-0000000000c2","tipo":"REAL","gatilho":"CUSTO_REAL","id_parametros":"00000000-0000-7000-8000-000000000001","versao_motor":"motor-1.0.0",
 "cabecalho":{"estado_destino":"MG","icms_destino_pct":12,"condicao_pagamento":"28/45","encargo_pagamento_pct":1.5,"custo_total":3000,"venda_sugerida":0,"valor_liquido":11500,"total_nf":11500,"markup_bruto_pct":80,"margem_liquida_pct":9.97,"lucro":1146.15,"letra_equivalente":"C","comissao_efetiva_pct":0.7,"valor_comissao_total":80.5,"qtd_itens":1,"custo_completo":false,"imposto_completo":false},
 "itens":[{"ordem":1,"id_item_proposta":"00000000-0000-7000-8000-0000000001b1","id_item_pedido":"00000000-0000-7000-8000-0000000002b1","codigo_item_omie":601,"descricao":"Flange A","tipo_item":"REVENDA","qtd":50,"qtd_compra":50,"preco_unit_compra_cotado":100,"preco_unit_venda":230,"quantidade_coberta":20,"custo_real_total":3000,"custo_real_unitario_medio":150,"custo_completo":false,"qtd_eventos":1,"compra_bruta":3000,"custo_liquido":3000,"venda_item":11500,"lucro_item":1146.15,"margem_item_pct":9.97,"letra_item":"C","comissao_letra_pct":0.7,"comissao_pct":0.7,"regra_aplicada":"LETRA","valor_comissao_estimado":80.5}]}$j$::jsonb);
SELECT core_comissao.fn_comissao_vincular_itens('00000000-0000-7000-8000-0000000000c2','[{"id_item_proposta":"00000000-0000-7000-8000-0000000001b1","id_item_pedido":"00000000-0000-7000-8000-0000000002b1","codigo_item_omie":601}]'::jsonb);

-- NF 9101: 30 peças (R$ 6.900). Só 20 têm custo real: comissão das 20 (0,7%) = 32,20; pendente (10 peças a 2%) = 46,00
INSERT INTO core_vendas_faturamento.notas_fiscais VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59',9101,'00060001','2026-10-22',NULL);
INSERT INTO core_vendas_faturamento.produto_vendas VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59',9101,601,30,6900,NULL);
SELECT core_comissao.fn_comissao_nf_fechar('00000000-0000-7000-8000-0000000000c2',9101) AS nf1 \gset
SELECT 'NF1 parcial' AS cenario, valor_faturado, valor_se_cotado, valor_calculado, valor_pendente_custo, queda_por_custo, custo_completo FROM core_comissao.comissoes_nf WHERE codigo_nf_omie = 9101;
SELECT 'NF1 item' AS cenario, quantidade_faturada, quantidade_comissionavel, ni.valor_calculado, ni.valor_pendente_custo FROM core_comissao.comissoes_nf_itens ni JOIN core_comissao.comissoes_nf n ON n.id = ni.id_comissao_nf WHERE n.codigo_nf_omie = 9101;

-- NF 9102: 20 peças. A cobertura (20) já foi usada pela NF1: comissão 0 e pendente 92,00 (não paga duas vezes a mesma peça, N16-49)
INSERT INTO core_vendas_faturamento.notas_fiscais VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59',9102,'00060002','2026-10-23',NULL);
INSERT INTO core_vendas_faturamento.produto_vendas VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59',9102,601,20,4600,NULL);
SELECT core_comissao.fn_comissao_nf_fechar('00000000-0000-7000-8000-0000000000c2',9102) AS nf2 \gset
SELECT 'NF2 sem pagar de novo' AS cenario, valor_calculado, valor_pendente_custo, queda_por_custo FROM core_comissao.comissoes_nf WHERE codigo_nf_omie = 9102;

-- Compras confirma; o dono da comissão (a3) não decide a própria: deve falhar; perfil inválido: deve falhar; a Gerência aprova
SELECT core_comissao.fn_comissao_conferir_compras(:'nf1','CONFIRMAR',NULL,'00000000-0000-0000-0000-0000000000a1');
SELECT core_comissao.fn_comissao_decidir(:'nf1','APROVAR','Aprovada conforme o custo real já lançado','00000000-0000-0000-0000-0000000000a3');
SELECT core_comissao.fn_comissao_decidir(:'nf1','APROVAR','Aprovada conforme o custo real já lançado','00000000-0000-0000-0000-0000000000a4', NULL, NULL, 'DIRETORIA');
SELECT core_comissao.fn_comissao_decidir(:'nf1','APROVAR','Aprovada conforme o custo real já lançado','00000000-0000-0000-0000-0000000000a4', NULL, NULL, 'GERENCIA');
SELECT 'NF1 decidida' AS cenario, estado, valor_final FROM core_comissao.comissoes_nf WHERE codigo_nf_omie = 9101;
SELECT 'rastro NF1' AS cenario, d.tipo, d.perfil_decisor, d.valor_antes, d.valor_depois, d.pct_antes, d.pct_depois FROM core_comissao.comissao_decisoes d JOIN core_comissao.comissoes_nf n ON n.id = d.id_comissao_nf WHERE n.codigo_nf_omie = 9101;

-- o custo completa (50 peças): a NF1 já decidida não muda; o motor da API lança o complemento das 10 peças (10 x 230 x 0,7% = 16,10)
SELECT core_comissao.fn_calculo_gravar($j${
 "id_comissao":"00000000-0000-7000-8000-0000000000c2","tipo":"REAL","gatilho":"CUSTO_REAL","id_parametros":"00000000-0000-7000-8000-000000000001","versao_motor":"motor-1.0.0",
 "cabecalho":{"estado_destino":"MG","icms_destino_pct":12,"condicao_pagamento":"28/45","encargo_pagamento_pct":1.5,"custo_total":7500,"venda_sugerida":0,"valor_liquido":11500,"total_nf":11500,"markup_bruto_pct":53,"margem_liquida_pct":9.97,"lucro":1146.15,"letra_equivalente":"C","comissao_efetiva_pct":0.7,"valor_comissao_total":80.5,"qtd_itens":1,"custo_completo":true,"imposto_completo":false},
 "itens":[{"ordem":1,"id_item_proposta":"00000000-0000-7000-8000-0000000001b1","id_item_pedido":"00000000-0000-7000-8000-0000000002b1","codigo_item_omie":601,"descricao":"Flange A","tipo_item":"REVENDA","qtd":50,"qtd_compra":50,"preco_unit_compra_cotado":100,"preco_unit_venda":230,"quantidade_coberta":50,"custo_real_total":7500,"custo_real_unitario_medio":150,"custo_completo":true,"qtd_eventos":3,"compra_bruta":7500,"custo_liquido":7500,"venda_item":11500,"lucro_item":1146.15,"margem_item_pct":9.97,"letra_item":"C","comissao_letra_pct":0.7,"comissao_pct":0.7,"regra_aplicada":"LETRA","valor_comissao_estimado":80.5}]}$j$::jsonb);
-- complemento em NF ainda não decidida (NF2): deve falhar
SELECT core_comissao.fn_comissao_lancamento_registrar(:'nf2','COMPLEMENTO',10,'teste em NF não decidida');
SELECT core_comissao.fn_comissao_lancamento_registrar(:'nf1','COMPLEMENTO',16.10,'Custo completou: 50 peças com custo real','00000000-0000-0000-0000-0000000000a1', NULL, '[{"codigo_item_omie":601,"quantidade":10}]'::jsonb) AS lanc \gset
-- o dono (a3) não decide o próprio complemento: deve falhar; a Coordenação decide
SELECT core_comissao.fn_comissao_lancamento_decidir(:'lanc','APROVAR','Complemento das 10 peças com custo real','00000000-0000-0000-0000-0000000000a3');
SELECT core_comissao.fn_comissao_lancamento_decidir(:'lanc','APROVAR','Complemento das 10 peças com custo real','00000000-0000-0000-0000-0000000000a4', NULL, NULL, 'COORDENACAO');
SELECT 'complemento' AS cenario, tipo, estado, valor_calculado, valor_final, competencia FROM core_comissao.comissao_lancamentos WHERE tipo = 'COMPLEMENTO';

-- recalcula a NF2 (ainda aguarda decisão): cobertura 50 - 20 (NF1) - 10 (complemento) = 20 peças => 4600 x 0,7% = 32,20; pendente 0
SELECT core_comissao.fn_comissao_nf_fechar('00000000-0000-7000-8000-0000000000c2',9102) AS nf2b \gset
SELECT 'NF2 completa' AS cenario, valor_calculado, valor_pendente_custo, custo_completo FROM core_comissao.comissoes_nf WHERE codigo_nf_omie = 9102;

-- bloquear, desbloquear e alterar por PERCENTUAL (N16-43, N16-45)
SELECT core_comissao.fn_comissao_conferir_compras(:'nf2','CONFIRMAR',NULL,'00000000-0000-0000-0000-0000000000a1');
SELECT core_comissao.fn_comissao_decidir(:'nf2','BLOQUEAR','Retida até conferir o custo das 20 peças','00000000-0000-0000-0000-0000000000a2');
SELECT 'bloqueada' AS cenario, situacao, valor_final, decisao, justificativa FROM core_comissao.vw_comissao_nf_vendedor WHERE numero_nf = '00060002';
SELECT core_comissao.fn_comissao_decidir(:'nf2','DESBLOQUEAR','Custo conferido, volta para a fila de decisão','00000000-0000-0000-0000-0000000000a2');
SELECT 'desbloqueada' AS cenario, estado, valor_final FROM core_comissao.comissoes_nf WHERE codigo_nf_omie = 9102;
SELECT core_comissao.fn_comissao_decidir(:'nf2','ALTERAR','Ajuste por percentual: 1,0% sobre a NF','00000000-0000-0000-0000-0000000000a2', NULL, NULL, 'CONTROLADORIA', 1.0);
SELECT 'alterada por pct' AS cenario, estado, valor_calculado, valor_final FROM core_comissao.comissoes_nf WHERE codigo_nf_omie = 9102;
SELECT 'rastro NF2' AS cenario, tipo, perfil_decisor, valor_antes, valor_depois, pct_antes, pct_depois, pct_novo FROM core_comissao.comissao_decisoes d JOIN core_comissao.comissoes_nf n ON n.id = d.id_comissao_nf WHERE n.codigo_nf_omie = 9102 ORDER BY d.sequencia;

-- devolução parcial (25%) com a NF2 ainda NÃO paga: reduz o valor a pagar do mês corrente
SELECT core_comissao.fn_comissao_nf_abater(:'nf2','DEVOLUCAO',25,'Devolução parcial de 5 peças','00000000-0000-0000-0000-0000000000a1');
-- depois de paga, a recusa do cliente vira desconto na próxima apuração
SELECT core_comissao.fn_comissao_nf_marcar_paga(:'nf2','2026-10-30','00000000-0000-0000-0000-0000000000a1');
SELECT core_comissao.fn_comissao_nf_abater(:'nf2','RECUSA_CLIENTE',25,'Recusa: Operação não realizada','00000000-0000-0000-0000-0000000000a1');
-- passaria de 100%: deve falhar
SELECT core_comissao.fn_comissao_nf_abater(:'nf2','DEVOLUCAO',60,'excede o que resta','00000000-0000-0000-0000-0000000000a1');
SELECT 'abatimentos' AS cenario, origem, proporcao_pct, valor_final, ja_paga, competencia = date_trunc('month', now())::date AS no_mes_corrente FROM core_comissao.comissao_lancamentos WHERE tipo = 'ABATIMENTO' ORDER BY created_at;

-- o que o vendedor vê (justificativa sempre) e os relatórios da Controladoria
SELECT 'vendedor NFs' AS cenario, numero_nf, situacao, valor_final, decisao, justificativa FROM core_comissao.vw_comissao_nf_vendedor WHERE numero_pedido = '2002' ORDER BY numero_nf;
SELECT 'vendedor lancamentos' AS cenario, tipo, situacao, valor_com_sinal, justificativa FROM core_comissao.vw_comissao_lancamentos_vendedor ORDER BY tipo;
SELECT 'markup vendedor' AS cenario, codigo_vendedor_omie, categoria, is_consolidado, qtd_pedidos, venda, custo, markup_real_pct FROM core_comissao.vw_comissao_markup_vendedor ORDER BY 2, 3;
SELECT 'fat x compras' AS cenario, numero_pedido, faturamento, compras, markup_real_pct, comissao_efetiva_pct, valor_a_pagar, valor_retido FROM core_comissao.vw_comissao_faturamento_x_compras WHERE numero_pedido = '2002';
SELECT 'lancamentos do mes' AS cenario, competencia, complementos, descontos, abatimentos FROM core_comissao.vw_comissao_lancamentos_mes ORDER BY 2;
