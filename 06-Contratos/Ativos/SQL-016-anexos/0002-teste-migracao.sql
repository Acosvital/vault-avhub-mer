-- SQL-016 · anexo 0002 · teste funcional da migração 0001 (26/10/2026).
-- Rodar num banco REPRODUZIDO do dump de referência (schema), depois de aplicar o 0001. Tudo dentro de uma transação que termina em ROLLBACK.
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
  RAISE NOTICE 'OK erro esperado: %', left(SQLERRM, 80);
END $$;
CREATE FUNCTION pg_temp.confere(p_ok boolean, p_msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF p_ok IS NOT TRUE THEN RAISE EXCEPTION 'FALHOU: %', p_msg; END IF; RAISE NOTICE 'OK: %', p_msg; END $$;

-- ── base mínima
INSERT INTO auth.usuarios (id, email, username) VALUES
  ('00000000-0000-0000-0000-0000000000a1','vend@x.com','vend'),('00000000-0000-0000-0000-0000000000a2','comp@x.com','comp'),
  ('00000000-0000-0000-0000-0000000000a3','ccp@x.com','ccp');
INSERT INTO core.unidades (id, cnpj, razao_social, nome_fantasia, tipo_unidade, matriz_id, nome_contato, email, logradouro, numero, bairro, cidade, estado, cep) VALUES
  ('759979bd-2b2d-41f2-b1b7-db6fae89ee59','11.111.111/0001-11','Acos Vital','Aços Vital','matriz',NULL,'x','a@a.com','R','1','B','Mogi','SP','08000-000'),
  ('4ec9f957-73bb-43a1-8435-4e30a97533d6','22.222.222/0001-22','Acos Uberaba','Aços Uberaba','filial','759979bd-2b2d-41f2-b1b7-db6fae89ee59','x','a@a.com','R','1','B','Uberaba','MG','38000-000'),
  ('c84155b6-75cc-4bca-8435-281e846f4039','33.333.333/0001-33','HRM','HRM','filial','759979bd-2b2d-41f2-b1b7-db6fae89ee59','x','a@a.com','R','1','B','Aruja','SP','07400-000');
INSERT INTO core_comercial.unidades_emissoras (codigo, id_unidade, id_unidade_conta_omie, nome_curto) VALUES
  ('AV','759979bd-2b2d-41f2-b1b7-db6fae89ee59','759979bd-2b2d-41f2-b1b7-db6fae89ee59','AÇOS VITAL'),
  ('AU','4ec9f957-73bb-43a1-8435-4e30a97533d6','4ec9f957-73bb-43a1-8435-4e30a97533d6','AÇOS UBERABA'),
  ('HRM','c84155b6-75cc-4bca-8435-281e846f4039','759979bd-2b2d-41f2-b1b7-db6fae89ee59','HRM CALDEIRARIA');   -- HRM na conta de Mogi (como no banco real)
INSERT INTO core_comercial.clientes (id, tipo_pessoa, documento, razao_social) VALUES ('10000000-0000-0000-0000-000000000001','PF','52998224725','Cliente X');
INSERT INTO core_comercial.propostas (id, id_unidade_emissora, codigo_empresa, ano, sequencial, numero_completo, id_cliente, cliente_snapshot, finalidade, incoterm,
    condicao_pagamento, validade, subtotal, total_desconto, total_icms, total_ipi, total_st, total_geral, id_responsavel, responsavel_snapshot, created_by, updated_by)
SELECT '20000000-0000-0000-0000-000000000001', e.id, e.id_unidade_conta_omie, 2026, 1, 'CO-AV2026-0001-R00', '10000000-0000-0000-0000-000000000001', '{}', 'REVENDA', 'FOB',
    '28/45', '10 dias', 1000, 0, 0, 0, 0, 1000, '00000000-0000-0000-0000-0000000000a1', '{}', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1'
  FROM core_comercial.unidades_emissoras e WHERE e.codigo = 'AV';
INSERT INTO core_comercial.propostas_itens (id, id_proposta, ordem, descricao, quantidade, unidade_medida, preco_unitario, icms_pct, ipi_pct, prazo_dias_uteis,
    preco_unitario_liquido, subtotal_bruto, valor_desconto, base, valor_icms, valor_ipi, valor_st) VALUES
  ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',1,'Flange',10,'UN',100,18,0,'10',100,1000,0,1000,180,0,0),
  ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001',2,'Tubo',5,'UN',200,18,0,'10',200,1000,0,1000,180,0,0);

-- ── 1. proposta incompleta não aprova
SELECT pg_temp.espera($$UPDATE core_comercial.propostas SET status='APROVADA', aprovada_revisao=0, aprovada_por='00000000-0000-0000-0000-0000000000a1', updated_by='00000000-0000-0000-0000-0000000000a1' WHERE id='20000000-0000-0000-0000-000000000001'$$, 'PROPOSTA_INCOMPLETA');
UPDATE core_comercial.propostas_itens SET custo=60, origem_custo='MANUAL', fornecedor='Forn A' WHERE id_proposta='20000000-0000-0000-0000-000000000001';
-- 2. revisão desatualizada
SELECT pg_temp.espera($$UPDATE core_comercial.propostas SET status='APROVADA', aprovada_revisao=3, updated_by='00000000-0000-0000-0000-0000000000a1' WHERE id='20000000-0000-0000-0000-000000000001'$$, 'REVISAO_DESATUALIZADA');
UPDATE core_comercial.propostas SET status='APROVADA', aprovada_revisao=0, aprovada_por='00000000-0000-0000-0000-0000000000a1', updated_by='00000000-0000-0000-0000-0000000000a1' WHERE id='20000000-0000-0000-0000-000000000001';
SELECT pg_temp.confere((SELECT status='APROVADA' AND aprovada_em IS NOT NULL FROM core_comercial.propostas WHERE id='20000000-0000-0000-0000-000000000001'), 'proposta aprovada com data da aprovação');
-- 3. aprovada trava
SELECT pg_temp.espera($$UPDATE core_comercial.propostas SET total_geral=999 WHERE id='20000000-0000-0000-0000-000000000001'$$, 'PROPOSTA_TRAVADA');
SELECT pg_temp.espera($$UPDATE core_comercial.propostas_itens SET quantidade=99 WHERE id='30000000-0000-0000-0000-000000000001'$$, 'PROPOSTA_TRAVADA');
SELECT pg_temp.espera($$UPDATE core_comercial.propostas SET status='ABERTA' WHERE id='20000000-0000-0000-0000-000000000001'$$, 'TRANSICAO_INVALIDA');

-- ── 4. transformar: as três respostas são obrigatórias
SELECT pg_temp.espera($$SELECT core_comercial.fn_propostas_transformar_em_pedido('20000000-0000-0000-0000-000000000001', NULL, true, current_date+10, '00000000-0000-0000-0000-0000000000a1')$$, 'QUALIDADE_NAO_INFORMADA');
SELECT pg_temp.espera($$SELECT core_comercial.fn_propostas_transformar_em_pedido('20000000-0000-0000-0000-000000000001', true, NULL, current_date+10, '00000000-0000-0000-0000-0000000000a1')$$, 'FATURAMENTO_NAO_INFORMADO');
SELECT pg_temp.espera($$SELECT core_comercial.fn_propostas_transformar_em_pedido('20000000-0000-0000-0000-000000000001', true, true, NULL, '00000000-0000-0000-0000-0000000000a1')$$, 'PREVISAO_INVALIDA');
SELECT pg_temp.espera($$SELECT core_comercial.fn_propostas_transformar_em_pedido('20000000-0000-0000-0000-000000000001', true, true, current_date-1, '00000000-0000-0000-0000-0000000000a1')$$, 'PREVISAO_INVALIDA');
SELECT core_comercial.fn_propostas_transformar_em_pedido('20000000-0000-0000-0000-000000000001', true, true, current_date+10, '00000000-0000-0000-0000-0000000000a1', 'V1') AS ped \gset
SELECT pg_temp.confere((SELECT numero=1 AND codigo_pedido_integracao='1' AND data_previsao_faturamento_inicial=current_date+10 AND faturamento_parcial AND acompanhamento_qualidade
                          FROM core_comercial.pedidos WHERE id=:'ped'::uuid), 'pedido criado com número 1, previsão inicial e as duas marcações');
SELECT pg_temp.confere((SELECT count(*)=2 FROM core_comercial.pedidos_itens WHERE id_pedido=:'ped'::uuid), 'os dois itens foram copiados');
SELECT pg_temp.confere((SELECT status='TRANSFORMADA' AND transformada_em IS NOT NULL FROM core_comercial.propostas WHERE id='20000000-0000-0000-0000-000000000001'), 'proposta virou TRANSFORMADA');
SELECT pg_temp.confere((SELECT count(*)=1 FROM core_comercial.pedidos_previsoes WHERE id_pedido=:'ped'::uuid AND tipo='INICIAL'), 'previsão INICIAL gravada');
SELECT pg_temp.espera($$SELECT core_comercial.fn_propostas_transformar_em_pedido('20000000-0000-0000-0000-000000000001', true, true, current_date+10, '00000000-0000-0000-0000-0000000000a1')$$, 'PROPOSTA_NAO_APROVADA');

-- O Omie devolveu o número do pedido (fila) e os itens têm o produto do Omie: a partir daqui o item é empresa + pedido + produto (N16-102).
UPDATE core_comercial.pedidos SET status_sincronizacao_omie='sincronizado', codigo_pedido_omie=9001, numero_pedido_omie='9001' WHERE id=:'ped'::uuid;
UPDATE core_comercial.pedidos_itens SET codigo_produto_omie = CASE ordem WHEN 1 THEN 'P-FLANGE' ELSE 'P-TUBO' END WHERE id_pedido=:'ped'::uuid;
SELECT codigo_empresa AS emp FROM core_comercial.pedidos WHERE id=:'ped'::uuid \gset

-- ── 5. datas: Compras e CCP (dia útil, atraso, aviso), pela chave empresa + pedido + produto (N16-104)
SELECT pg_temp.confere(core_comercial.fn_somar_dias_uteis(DATE '2026-10-30', 1) = DATE '2026-11-02', '+1 dia útil de sexta é segunda');
SELECT pg_temp.confere(core_comercial.fn_somar_dias_uteis(DATE '2026-10-30', 1, ARRAY[DATE '2026-11-02']) = DATE '2026-11-03', '+1 dia útil pula o feriado de 02/11');
SELECT id AS item1 FROM core_comercial.pedidos_itens WHERE id_pedido=:'ped'::uuid AND ordem=1 \gset
SELECT id AS item2 FROM core_comercial.pedidos_itens WHERE id_pedido=:'ped'::uuid AND ordem=2 \gset
SELECT core_comercial.fn_pedidos_registrar_previsao(:'emp'::uuid, '9001', 'P-FLANGE', 'ENTREGA_COMPRAS', NULL, DATE '2026-11-01', 'fornecedor só entrega dia 01', 'COMPRAS', '00000000-0000-0000-0000-0000000000a2', ARRAY[DATE '2026-11-02']);
SELECT pg_temp.espera(format($$SELECT core_comercial.fn_pedidos_registrar_previsao(%L, '9001', 'P-FLANGE', 'ENTREGA_CCP', NULL, DATE '2026-11-05', NULL, 'CCP', '00000000-0000-0000-0000-0000000000a3')$$, :'emp'), 'MOTIVO_OBRIGATORIO');
SELECT pg_temp.espera(format($$SELECT core_comercial.fn_pedidos_registrar_previsao(%L, '9001', 'P-NAO-EXISTE', 'ENTREGA_COMPRAS', NULL, DATE '2026-11-05', NULL, 'COMPRAS', NULL)$$, :'emp'), 'ITEM_PEDIDO_NAO_ENCONTRADO');
SELECT core_comercial.fn_pedidos_registrar_previsao(:'emp'::uuid, '9001', 'P-FLANGE', 'ENTREGA_CCP', NULL, DATE '2026-11-05', 'fornecedor atrasou', 'CCP', '00000000-0000-0000-0000-0000000000a3') AS fat \gset
SELECT pg_temp.confere((SELECT atraso_dias=4 FROM core_comercial.pedidos_previsoes WHERE numero_pedido='9001' AND tipo='ENTREGA_CCP'), 'atraso do fornecedor de 4 dias (01/11 para 05/11)');
SELECT pg_temp.confere((SELECT data_previsao_faturamento = greatest(DATE '2026-11-06', current_date+10) FROM core_comercial.pedidos WHERE id=:'ped'::uuid),
                       'previsão vigente = a maior entre a inicial e 05/11 + 1 dia útil');
SELECT pg_temp.confere((SELECT data_previsao_faturamento_inicial=current_date+10 FROM core_comercial.pedidos WHERE id=:'ped'::uuid), 'a previsão inicial nunca se perde');
SELECT pg_temp.confere((SELECT count(*)=1 FROM core_comercial.notificacoes WHERE tipo='PREVISAO_ALTERADA_CCP' AND id_usuario='00000000-0000-0000-0000-0000000000a1'), 'a mudança do CCP só avisa o vendedor');
SELECT pg_temp.confere((SELECT count(*)=3 AND bool_and(numero_pedido='9001') FROM core_comercial.vw_pedidos_previsoes WHERE id_pedido=:'ped'::uuid),
                       'todas as datas ficam registradas (inicial, Compras, CCP), a inicial com o número do Omie resolvido');
SELECT pg_temp.confere((SELECT origem_pedido='PROPOSTA' AND previsao_inicial=current_date+10 AND previsao_vigente=greatest(DATE '2026-11-06', current_date+10)
                               AND maior_atraso=4 AND qtd_datas=3 FROM core_comercial.vw_pedidos_previsao_vigente WHERE numero_pedido='9001'),
                       'a vigente do Hub aparece para o PCP (pedido 9001 do Hub)');
SELECT pg_temp.espera($$UPDATE core_comercial.pedidos_previsoes SET motivo='x'$$, 'pedidos_previsoes só recebe INSERT');

-- ── 5b. calendário: exceções do marketing por unidade e para todas (N16-104)
INSERT INTO core_comercial.calendario_excecoes (id_unidade, data, tipo, descricao) VALUES
  (NULL, DATE '2026-11-20', 'FERIADO', 'Consciência Negra (nacional desde 2024; a biblioteca só traz em MG)'),
  ('759979bd-2b2d-41f2-b1b7-db6fae89ee59', DATE '2026-12-08', 'FERIADO', 'Imaculada Conceição (municipal em Mogi)'),
  ('759979bd-2b2d-41f2-b1b7-db6fae89ee59', DATE '2026-11-02', 'DIA_UTIL', 'Mogi trabalha em Finados (exemplo)');
SELECT pg_temp.confere(core_comercial.fn_calendario_feriados('759979bd-2b2d-41f2-b1b7-db6fae89ee59', ARRAY[DATE '2026-11-02', DATE '2026-11-15'], DATE '2026-11-01', DATE '2026-12-31')
                       = ARRAY[DATE '2026-11-15', DATE '2026-11-20', DATE '2026-12-08'],
                       'Mogi: feriados da biblioteca + os do marketing, menos o dia útil cadastrado');
SELECT pg_temp.confere(core_comercial.fn_calendario_feriados('4ec9f957-73bb-43a1-8435-4e30a97533d6', ARRAY[DATE '2026-11-02'], DATE '2026-11-01', DATE '2026-12-31')
                       = ARRAY[DATE '2026-11-02', DATE '2026-11-20'],
                       'Uberaba: só a exceção de todas as unidades');
SELECT pg_temp.espera($$INSERT INTO core_comercial.calendario_excecoes (id_unidade, data, tipo, descricao) VALUES (NULL, DATE '2026-11-20', 'FERIADO', 'repetido')$$, 'duplicate key');

-- ── 6. compra acima do valor (C8): compara com o CUSTO que o vendedor pôs (60 × 10 = 600), não com o preço de venda (1000)
SELECT pg_temp.espera(format($$SELECT core_comercial.fn_divergencia_registrar(%L, '9001', 'P-FLANGE', NULL, 600, 'igual ao custo', NULL)$$, :'emp'), 'COMPRA_NAO_ESTA_ACIMA');
SELECT core_comercial.fn_divergencia_registrar(:'emp'::uuid, '9001', 'P-FLANGE', NULL, 700, 'fornecedor subiu o preço', '00000000-0000-0000-0000-0000000000a2') AS dv \gset
SELECT pg_temp.confere((SELECT valor_proposta=600 AND diferenca=100 AND id_vendedor='00000000-0000-0000-0000-0000000000a1'
                          FROM core_comercial.divergencias_compra WHERE id=:'dv'::uuid), 'divergência contra o custo do vendedor (600), não contra a venda (1000)');
SELECT pg_temp.espera(format($$SELECT core_comercial.fn_divergencia_decidir(%L, '00000000-0000-0000-0000-0000000000a2', true)$$, :'dv'), 'SO_O_VENDEDOR_DO_ITEM');
SELECT core_comercial.fn_divergencia_decidir(:'dv'::uuid, '00000000-0000-0000-0000-0000000000a1', false);
SELECT core_comercial.fn_divergencia_resolver(:'dv'::uuid, '00000000-0000-0000-0000-0000000000a2', 'NOVO_FORNECEDOR', 'Gerência viu fisicamente; novo fornecedor');
SELECT pg_temp.confere((SELECT estado='RESOLVIDO' FROM core_comercial.divergencias_compra WHERE id=:'dv'::uuid), 'divergência reprovada e resolvida por Compras');
SELECT pg_temp.espera(format($$SELECT core_comercial.fn_divergencia_registrar(%L, '9001', 'P-NAO-EXISTE', NULL, 700, 'x y z', NULL)$$, :'emp'), 'ITEM_NAO_ENCONTRADO');

-- ── 7. sequenciais: um pedido, várias notas; cancelar devolve o valor
INSERT INTO core_comercial.pedidos_sequenciais (id, id_pedido, sequencial) VALUES ('40000000-0000-0000-0000-000000000001', :'ped'::uuid, 1), ('40000000-0000-0000-0000-000000000002', :'ped'::uuid, 2);
INSERT INTO core_comercial.pedidos_sequenciais_itens (id_sequencial, id_pedido_item, quantidade, valor) VALUES
  ('40000000-0000-0000-0000-000000000001', :'item1'::uuid, 4, 400), ('40000000-0000-0000-0000-000000000002', :'item1'::uuid, 6, 600);
SELECT pg_temp.confere((SELECT saldo_original=0 FROM core_comercial.vw_pedidos_saldo WHERE id_pedido=:'ped'::uuid), 'original zerado quando todo o valor foi distribuído');
UPDATE core_comercial.pedidos_sequenciais SET status='CANCELADO', cancelado_em=now(), cancelado_por='00000000-0000-0000-0000-0000000000a1', motivo_cancelamento='refazer' WHERE id='40000000-0000-0000-0000-000000000001';
SELECT pg_temp.confere((SELECT saldo_original=400 FROM core_comercial.vw_pedidos_saldo WHERE id_pedido=:'ped'::uuid), 'cancelar um sequencial devolve o valor ao original');
SELECT pg_temp.espera($$INSERT INTO core_comercial.pedidos_sequenciais (id_pedido, sequencial) VALUES ((SELECT id FROM core_comercial.pedidos LIMIT 1), 1)$$, 'duplicate key');

-- ── 8. custo real por evento e cancelamento do pedido
SELECT core_comercial.fn_custo_evento_registrar(:'emp'::uuid, '9001', 'P-TUBO', 'LOTE_ESTOQUE', 'teste:1', 5, 'UN', 120, 600, 5, '{"codigo_lote":"L-1"}'::jsonb) IS NULL AS _ignora \gset
SELECT pg_temp.confere((SELECT custo_total=600 AND quantidade_coberta=5 AND completo AND origem_pedido='PROPOSTA' AND custo_total_cotado=300 AND id_item_pedido=:'item2'::uuid
                          FROM core_comercial.vw_pedido_item_custo WHERE codigo_empresa=:'emp'::uuid AND numero_pedido='9001' AND codigo_produto_omie='P-TUBO'),
                       'custo real do item do pedido do Hub: R$ 600 cobrindo 5 de 5, contra R$ 300 cotados');
SELECT pg_temp.espera($$SELECT core_comercial.fn_pedidos_cancelar((SELECT id FROM core_comercial.pedidos LIMIT 1), NULL, 'x')$$, 'MOTIVO_OBRIGATORIO');
SELECT pg_temp.espera($$SELECT core_comercial.fn_pedidos_cancelar((SELECT id FROM core_comercial.pedidos LIMIT 1), NULL, 'cliente desistiu', true)$$, 'PEDIDO_FATURADO');
SELECT core_comercial.fn_pedidos_cancelar(:'ped'::uuid, '00000000-0000-0000-0000-0000000000a1', 'cliente desistiu') AS estornados \gset
SELECT pg_temp.confere(:estornados = 1, 'o cancelamento estornou o evento de custo (o comprado vai ao Estoque)');
SELECT pg_temp.confere((SELECT cancelado_em IS NOT NULL FROM core_comercial.pedidos WHERE id=:'ped'::uuid), 'pedido cancelado fica registrado (cancelar marca, não apaga)');
SELECT pg_temp.espera(format($$SELECT core_comercial.fn_pedidos_cancelar(%L, NULL, 'de novo')$$, :'ped'), 'TRANSICAO_INVALIDA');
SELECT pg_temp.espera(format($$SELECT core_comercial.fn_pedidos_registrar_previsao(%L, '9001', NULL, 'ENTREGA_COMPRAS', NULL, current_date, NULL, 'COMPRAS', NULL)$$, :'emp'), 'PEDIDO_CANCELADO');
SELECT pg_temp.espera(format($$SELECT core_comercial.fn_divergencia_registrar(%L, '9001', 'P-FLANGE', NULL, 900, 'depois de cancelar', NULL)$$, :'emp'), 'PEDIDO_CANCELADO');

-- ── 8b. pedido digitado DIRETO no Omie: entra no mesmo fluxo do Hub (N16-106); custo real e divergência também valem (N16-102)
-- Original 5001 quebrado em sequencial: o Omie zera a linha do original (casca) e o sequencial traz linha nova com o mesmo produto.
INSERT INTO core_vendas_faturamento.pedidos_vendas (codigo_pedido_omie, numero_pedido, sequencial, codigo_empresa, codigo_vendedor_omie) VALUES
  (777001, '5001', 0, '759979bd-2b2d-41f2-b1b7-db6fae89ee59', 'V9'), (777002, '5001', 1, '759979bd-2b2d-41f2-b1b7-db6fae89ee59', 'V9');
INSERT INTO core_vendas_faturamento.produto_vendas (codigo_empresa, codigo_pedido_omie, numero_pedido, codigo_item_omie, codigo_produto_omie, quantidade, valor_total, unidade_medida) VALUES
  ('759979bd-2b2d-41f2-b1b7-db6fae89ee59', 777001, '5001', 1, 'P-CHAPA', 0, 0, 'KG'),
  ('759979bd-2b2d-41f2-b1b7-db6fae89ee59', 777002, '5001', 2, 'P-CHAPA', 8, 800, 'KG');
SELECT pg_temp.confere((SELECT origem_pedido='OMIE' AND quantidade=8 AND id_pedido IS NULL AND natureza_custo='MATERIAL'
                          FROM core_comercial.vw_pedido_produtos WHERE codigo_empresa='759979bd-2b2d-41f2-b1b7-db6fae89ee59' AND numero_pedido='5001' AND codigo_produto_omie='P-CHAPA'),
                       'item do pedido do Omie: 8 kg (a casca de quantidade 0 do original não conta)');
SELECT core_comercial.fn_custo_evento_registrar_lotes('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '5001', 'P-CHAPA',
         '[{"codigo_lote":"L-9","quantidade":8,"custo_unitario":50}]'::jsonb) AS lotes \gset
SELECT pg_temp.confere(:lotes = 1, 'o lote do MES gerou um evento no pedido do Omie');
SELECT core_comercial.fn_custo_evento_registrar_lotes('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '5001', 'P-CHAPA',
         '[{"codigo_lote":"L-9","quantidade":8,"custo_unitario":50}]'::jsonb) AS lotes \gset
SELECT pg_temp.confere(:lotes = 0, 'rodar de novo não duplica');
SELECT pg_temp.confere((SELECT custo_total=400 AND completo AND custo_total_cotado IS NULL
                          FROM core_comercial.vw_pedido_item_custo WHERE codigo_empresa='759979bd-2b2d-41f2-b1b7-db6fae89ee59' AND numero_pedido='5001' AND codigo_produto_omie='P-CHAPA'),
                       'custo real do pedido do Omie: R$ 400 cobrindo 8 de 8');
SELECT pg_temp.confere((SELECT unidade_documento='KG' FROM core_comercial.custos_eventos WHERE numero_pedido='5001'), 'a unidade do lote vem do item do Omie');
SELECT pg_temp.espera($$SELECT core_comercial.fn_divergencia_registrar('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '5001', 'P-CHAPA', NULL, 500, 'subiu', NULL)$$, 'PEDIDO_NAO_IMPORTADO');
-- o job traz o pedido para o Hub: mesma tela e mesmo fluxo, parte de vendas pronta (N16-106)
UPDATE core_vendas_faturamento.pedidos_vendas SET data_previsao = '2026-11-05', valor_total_pedido = 800, codigo_cliente = 'CL9'
 WHERE numero_pedido = '5001' AND sequencial = 0;
SELECT core_comercial.fn_pedidos_omie_sincronizar('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '5001', '00000000-0000-0000-0000-0000000000a1') AS p5 \gset
SELECT core_comercial.fn_pedidos_omie_sincronizar('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '5001') AS p5b \gset
SELECT pg_temp.confere((SELECT origem='OMIE' AND id_proposta IS NULL AND numero_pedido_omie='5001' AND codigo_cliente_omie='CL9' AND valor_total=800
                               AND id_usuario_vendedor='00000000-0000-0000-0000-0000000000a1' AND data_previsao_faturamento_inicial=DATE '2026-11-05'
                               AND acompanhamento_qualidade IS NULL AND :'p5' = :'p5b'
                          FROM core_comercial.pedidos WHERE id=:'p5'::uuid),
                       'pedido do Omie trazido ao Hub (origem OMIE, vendedor, previsão do Omie); trazer de novo não duplica');
SELECT pg_temp.confere((SELECT count(*)=1 AND bool_and(codigo_produto_omie='P-CHAPA' AND quantidade=8 AND valor_total=800 AND custo IS NULL)
                          FROM core_comercial.pedidos_itens WHERE id_pedido=:'p5'::uuid),
                       'um item por produto, com a soma da família, e a parte de compras em branco');
-- a parte de vendas só muda no Omie; o cancelamento também
SELECT pg_temp.espera(format($$UPDATE core_comercial.pedidos_itens SET quantidade = 99 WHERE id_pedido = %L$$, :'p5'), 'PEDIDO_DO_OMIE');
SELECT pg_temp.espera(format($$UPDATE core_comercial.pedidos SET valor_total = 1 WHERE id = %L$$, :'p5'), 'PEDIDO_DO_OMIE');
SELECT pg_temp.espera(format($$DELETE FROM core_comercial.pedidos_itens WHERE id_pedido = %L$$, :'p5'), 'PEDIDO_DO_OMIE');
SELECT pg_temp.espera(format($$SELECT core_comercial.fn_pedidos_cancelar(%L, '00000000-0000-0000-0000-0000000000a1', 'cliente desistiu')$$, :'p5'), 'PEDIDO_DO_OMIE');
-- Compras ainda não tem com o que comparar
SELECT pg_temp.espera($$SELECT core_comercial.fn_divergencia_registrar('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '5001', 'P-CHAPA', NULL, 500, 'subiu', NULL)$$, 'SEM_CUSTO_DO_VENDEDOR');
-- o vendedor preenche a parte de compras e responde Qualidade e faturamento em partes no Hub
UPDATE core_comercial.pedidos_itens SET custo = 30, origem_custo = 'MANUAL', fornecedor = 'Forn X' WHERE id_pedido = :'p5'::uuid;
UPDATE core_comercial.pedidos SET acompanhamento_qualidade = true, faturamento_parcial = true WHERE id = :'p5'::uuid;
SELECT pg_temp.confere((SELECT custo_total_cotado=240 AND origem_pedido='OMIE' AND id_pedido=:'p5'::uuid
                          FROM core_comercial.vw_pedido_produtos WHERE numero_pedido='5001' AND codigo_produto_omie='P-CHAPA'),
                       'o vendedor preencheu a parte de compras: custo cotado de R$ 240 (8 x R$ 30)');
SELECT pg_temp.espera($$SELECT core_comercial.fn_divergencia_registrar('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '5001', 'P-CHAPA', NULL, 240, 'igual', NULL)$$, 'COMPRA_NAO_ESTA_ACIMA');
SELECT core_comercial.fn_divergencia_registrar('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '5001', 'P-CHAPA', NULL, 500, 'subiu', '00000000-0000-0000-0000-0000000000a2') AS dv2 \gset
SELECT pg_temp.confere((SELECT valor_proposta=240 AND id_vendedor='00000000-0000-0000-0000-0000000000a1' AND id_pedido=:'p5'::uuid
                          FROM core_comercial.divergencias_compra WHERE id=:'dv2'::uuid),
                       'compra acima do custo do vendedor no pedido do Omie: mesmo fluxo da proposta, aviso ao vendedor do pedido');
SELECT pg_temp.confere((SELECT count(*)>=1 FROM core_comercial.notificacoes WHERE tipo='COMPRA_ACIMA_DO_VALOR' AND id_usuario='00000000-0000-0000-0000-0000000000a1'),
                       'o vendedor do pedido do Omie recebe o aviso');
SELECT core_comercial.fn_pedidos_registrar_previsao('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '5001', 'P-CHAPA', 'ENTREGA_COMPRAS', NULL, DATE '2026-11-10', NULL, 'COMPRAS', '00000000-0000-0000-0000-0000000000a2') AS fat2 \gset
SELECT pg_temp.confere((SELECT origem_pedido='OMIE' AND previsao_inicial=DATE '2026-11-05' AND previsao_vigente=DATE '2026-11-11' AND qtd_datas=2
                          FROM core_comercial.vw_pedidos_previsao_vigente WHERE numero_pedido='5001'),
                       'pedido do Omie: inicial do Omie (05/11, salva como INICIAL) e vigente pela entrega de Compras (10/11 + 1 dia útil)');
SELECT pg_temp.confere((SELECT data_previsao_faturamento=DATE '2026-11-11' FROM core_comercial.pedidos WHERE id=:'p5'::uuid),
                       'a vigente também fica no pedido do Hub');
-- a pipeline traz o pedido cancelado no Omie: o job estorna o custo
UPDATE core_vendas_faturamento.pedidos_vendas SET cancelado = true WHERE numero_pedido = '5001';
SELECT core_comercial.fn_pedidos_omie_sincronizar('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '5001') IS NULL AS _sinc \gset
SELECT pg_temp.confere((SELECT cancelado_em IS NOT NULL AND motivo_cancelamento='Cancelado no Omie' FROM core_comercial.pedidos WHERE id=:'p5'::uuid),
                       'cancelado no Omie, a sincronização cancela no Hub');
SELECT core_comercial.fn_custo_eventos_estornar_pedido('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '5001', 'pedido cancelado no Omie', NULL) AS est2 \gset
SELECT pg_temp.confere(:est2 = 1 AND NOT EXISTS (SELECT 1 FROM core_comercial.vw_pedido_produtos WHERE numero_pedido='5001'),
                       'pedido do Omie cancelado: custo estornado e o item sai da lista');

-- ── 8c. OC do Hub ligada a pedido digitado no Omie: o vínculo (empresa + pedido + produto) gera o custo
INSERT INTO core_vendas_faturamento.pedidos_vendas (codigo_pedido_omie, numero_pedido, sequencial, codigo_empresa, codigo_vendedor_omie) VALUES (888001,'6001',0,'759979bd-2b2d-41f2-b1b7-db6fae89ee59','V9');
INSERT INTO core_vendas_faturamento.produto_vendas (codigo_empresa, codigo_pedido_omie, numero_pedido, codigo_item_omie, codigo_produto_omie, quantidade, valor_total, unidade_medida) VALUES
  ('759979bd-2b2d-41f2-b1b7-db6fae89ee59',888001,'6001',11,'P-BARRA',10,1000,'PC');
INSERT INTO core_vendas_faturamento.ordens_compra (id, numero_pedido, codigo_empresa, codigo_fornecedor, tipo_frete, finalidade, status)
VALUES ('50000000-0000-0000-0000-000000000001','OC-T1','759979bd-2b2d-41f2-b1b7-db6fae89ee59','F1','CIF','pedidos_venda','rascunho');
INSERT INTO core_vendas_faturamento.ordens_compra_itens (id, id_ordem_compra, ordem, descricao_produto, quantidade, unidade_medida, valor_unitario, codigo_empresa, codigo_produto, desconto)
VALUES ('50000000-0000-0000-0000-000000000011','50000000-0000-0000-0000-000000000001',1,'Barra',10,'PC',30,'759979bd-2b2d-41f2-b1b7-db6fae89ee59','P-BARRA',10);
INSERT INTO core_vendas_faturamento.ordens_compra_itens_vinculos (id_ordem_compra_item, id_ordem_compra, codigo_empresa_pv, numero_pedido_venda, codigo_produto_pv, quantidade)
VALUES ('50000000-0000-0000-0000-000000000011','50000000-0000-0000-0000-000000000001','759979bd-2b2d-41f2-b1b7-db6fae89ee59','6001','P-BARRA',10);
UPDATE core_vendas_faturamento.ordens_compra SET status='aprovado' WHERE id='50000000-0000-0000-0000-000000000001';
SELECT core_comercial.fn_custo_evento_sincronizar_oc('50000000-0000-0000-0000-000000000001') AS s1 \gset
SELECT core_comercial.fn_custo_evento_sincronizar_oc('50000000-0000-0000-0000-000000000001') AS s2 \gset
SELECT pg_temp.confere(:s1 = 1 AND :s2 = 0, 'a OC aprovada gera um evento e rodar de novo não duplica');
SELECT pg_temp.confere((SELECT custo_total=270 AND completo AND origem_pedido='OMIE' FROM core_comercial.vw_pedido_item_custo WHERE numero_pedido='6001'),
                       'custo da OC no pedido do Omie: 10 × R$ 30 com 10% de desconto = R$ 270');
UPDATE core_vendas_faturamento.ordens_compra SET status='cancelado' WHERE id='50000000-0000-0000-0000-000000000001';
SELECT core_comercial.fn_custo_evento_sincronizar_oc('50000000-0000-0000-0000-000000000001') AS s3 \gset
SELECT pg_temp.confere(:s3 = 1 AND (SELECT custo_total=0 AND status_custo='SEM_CUSTO' FROM core_comercial.vw_pedido_item_custo WHERE numero_pedido='6001'),
                       'OC cancelada estorna o custo e o item volta a SEM_CUSTO');

-- ── 9. correção do dado: as três unidades têm conta própria (N16-79)
UPDATE core_comercial.unidades_emissoras SET id_unidade_conta_omie = id_unidade WHERE codigo = 'HRM' AND id_unidade_conta_omie <> id_unidade;
SELECT pg_temp.confere((SELECT count(*)=3 FROM core_comercial.unidades_emissoras WHERE id_unidade_conta_omie = id_unidade), 'AV, AU e HRM com conta Omie própria');

-- ── 10. catálogos novos
INSERT INTO core_vendas_faturamento.condicoes_pagamento_vendas (codigo_empresa, codigo_omie, descricao, quantidade_parcelas, informar_parcelas, dias_descricao)
VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59','00V','45/55/65/80',4,false,'45,55,65,80'), ('759979bd-2b2d-41f2-b1b7-db6fae89ee59','999','Informar o número de parcelas',999,true,NULL);
SELECT pg_temp.espera($$INSERT INTO core_vendas_faturamento.condicoes_pagamento_vendas (codigo_empresa, codigo_omie, descricao, informar_parcelas) VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59','A01','x',true)$$, 'new row for relation');
SELECT pg_temp.espera($$INSERT INTO core_vendas_faturamento.condicoes_pagamento_vendas (codigo_empresa, codigo_omie, descricao) VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59','00V','duplicada')$$, 'duplicate key');
\echo 'TESTE DA MIGRACAO DO SQL-016: TUDO OK'
ROLLBACK;
