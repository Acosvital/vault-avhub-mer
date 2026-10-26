-- SQL-017 · anexo 0002 · teste funcional da migração 0001 (26/10/2026).
-- Rodar num banco reproduzido do dump de referência, depois do SQL-016 (0001) e do SQL-017 (0001). Termina em ROLLBACK.
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

INSERT INTO core.unidades (id, cnpj, razao_social, nome_fantasia, tipo_unidade, nome_contato, email, logradouro, numero, bairro, cidade, estado, cep)
VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59','11.111.111/0001-11','Acos Vital','Aços Vital','matriz','x','a@a.com','R','1','B','Mogi','SP','08000-000');
INSERT INTO core.parceiros (id, codigo_parceiro_omie, nome_fantasia, razao_social, cpf_cnpj, codigo_empresa) VALUES
  ('50000000-0000-0000-0000-000000000001','F1','Forn A','Forn A','11111111000111','759979bd-2b2d-41f2-b1b7-db6fae89ee59'),
  ('50000000-0000-0000-0000-000000000002','F2','Forn B','Forn B','22222222000122','759979bd-2b2d-41f2-b1b7-db6fae89ee59');
INSERT INTO core.familia_produtos (codigo_fprodutos, nome, codigo_empresa) VALUES ('FLANGE','Flange','759979bd-2b2d-41f2-b1b7-db6fae89ee59');
INSERT INTO core.produtos (id, codigo_produto, codigo_produto_omie, descricao, familias_produtos, codigo_empresa) VALUES
  ('60000000-0000-0000-0000-000000000001','FLG1','9001','Flange 1','FLANGE','759979bd-2b2d-41f2-b1b7-db6fae89ee59');
INSERT INTO core_vendas_faturamento.ordens_compra (id, numero_pedido, codigo_empresa, codigo_fornecedor, tipo_frete, status, aprovado_em)
VALUES ('70000000-0000-0000-0000-000000000001','OC1','759979bd-2b2d-41f2-b1b7-db6fae89ee59','F1','CIF','aprovado', now() - interval '3 days'),
       ('70000000-0000-0000-0000-000000000002','OC2','759979bd-2b2d-41f2-b1b7-db6fae89ee59','F2','CIF','aprovado', now() - interval '2 days');
INSERT INTO core_vendas_faturamento.ordens_compra_itens (id, id_ordem_compra, ordem, codigo_produto, descricao_produto, quantidade, unidade_medida, valor_unitario, desconto, codigo_empresa)
VALUES ('80000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001',1,'FLG1','Flange 1',10,'UN',100,10,'759979bd-2b2d-41f2-b1b7-db6fae89ee59'),
       ('80000000-0000-0000-0000-000000000002','70000000-0000-0000-0000-000000000002',1,'9001','Flange 1',10,'UN',120,0,'759979bd-2b2d-41f2-b1b7-db6fae89ee59');

-- novas fontes e sem prazo
SELECT pg_temp.confere(core_comercial.fn_ofertas_gerar_de_ocs() = 2, 'duas ofertas nasceram das duas OCs aprovadas');
SELECT pg_temp.confere(core_comercial.fn_ofertas_gerar_de_ocs() = 0, 'rodar de novo não duplica (idempotente)');
SELECT pg_temp.confere((SELECT custo_liquido_unit = 90 FROM core_comercial.ofertas WHERE fonte='OC_HUB' AND id_documento_fonte='80000000-0000-0000-0000-000000000001'), 'custo líquido da oferta = preço menos desconto (R$ 90)');
-- base e estatística (o trigger recalcula)
SELECT pg_temp.confere((SELECT count(*) = 2 FROM core_comercial.produtos_precos_fornecedor WHERE id_produto='60000000-0000-0000-0000-000000000001'), 'base de preço com os dois fornecedores');
SELECT pg_temp.confere((SELECT fornecedores = 2 AND registros = 2 AND minimo = 90 AND maximo = 120 AND ultimo > 0 FROM core_comercial.produtos_estatisticas_preco WHERE id_produto='60000000-0000-0000-0000-000000000001'), 'estatística: 2 fornecedores, mínimo 90, máximo 120');
SELECT pg_temp.confere((SELECT count(*) = 2 FROM core_comercial.vw_produtos_serie_preco WHERE id_produto='60000000-0000-0000-0000-000000000001'), 'série de preço com 2 pontos');
SELECT pg_temp.confere((SELECT count(*) = 2 FROM core_comercial.vw_matriz_precos WHERE id_produto='60000000-0000-0000-0000-000000000001'), 'matriz de preços v1 com 2 linhas');
-- oferta é imutável (regra que já existe); OC cancelada invalida
SELECT pg_temp.espera($$UPDATE core_comercial.ofertas SET preco = 1$$, 'Oferta é imutável');
UPDATE core_vendas_faturamento.ordens_compra SET status='cancelado' WHERE id='70000000-0000-0000-0000-000000000002';
SELECT pg_temp.confere(core_comercial.fn_ofertas_gerar_de_ocs() = 1, 'OC cancelada invalidou a oferta dela');
SELECT pg_temp.confere((SELECT status='INVALIDADA' AND motivo_invalidacao='OC cancelada' FROM core_comercial.ofertas WHERE id_documento_fonte='80000000-0000-0000-0000-000000000002'), 'oferta INVALIDADA com motivo, sem apagar');
SELECT pg_temp.confere((SELECT count(*) = 1 FROM core_comercial.produtos_precos_fornecedor WHERE id_produto='60000000-0000-0000-0000-000000000001'), 'a base recalculou sem a oferta invalidada');
SELECT pg_temp.espera($$DELETE FROM core_comercial.ofertas$$, 'Oferta não pode ser apagada');
-- pedido de custo sem prazo
INSERT INTO auth.usuarios (id, email, username) VALUES ('00000000-0000-0000-0000-0000000000a1','v@x.com','v');
INSERT INTO core_comercial.solicitacoes_custo (numero, descricao, quantidade, unidade_medida, id_solicitante)
VALUES ('SC-2026-0001','Flange especial',5,'UN','00000000-0000-0000-0000-0000000000a1');
SELECT pg_temp.confere((SELECT prazo_resposta IS NULL FROM core_comercial.solicitacoes_custo WHERE numero='SC-2026-0001'), 'pedido de custo nasce sem prazo (N16-58)');
SELECT pg_temp.espera($$INSERT INTO core_comercial.ofertas (id_produto, id_parceiro, fonte, preco, unidade_preco, data_cotacao, valida_ate, custo_liquido_unit) VALUES ('60000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','XX',1,'UN',current_date,current_date,1)$$, 'new row for relation');
\echo 'TESTE DA MIGRACAO DO SQL-017: TUDO OK'
ROLLBACK;
