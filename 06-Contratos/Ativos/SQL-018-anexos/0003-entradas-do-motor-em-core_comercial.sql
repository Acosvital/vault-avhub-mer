-- ============================================================================
-- SQL-018, anexo 0003 (proposta de 16/10/2026): colunas que o motor de comissão precisa em core_comercial.
-- NÃO executado em produção. NÃO altera o SQL-016 (migração): é o que o dono do SQL-016 (migração) precisa incorporar (ou recusar) para
-- que a tela da proposta tenha as MESMAS entradas do simulador atual (N16-19), sem coluna paralela em core_comissao.
-- Aplicar depois do SQL-016 (migração) e antes de ligar a API-022.
--
-- Correspondência da tela do simulador (tela-simulador-comissao.png) com o SQL-016 (migração):
--   Unidade                      propostas.codigo_empresa (já existe)
--   Cliente / Vendedor           propostas.id_cliente, propostas.id_responsavel (já existem)
--   Estado de destino com ICMS   FALTA  -> propostas.destino_icms (código de core_comissao.parametros_icms_saida.destino)
--   Condição de pagamento        FALTA  -> propostas.condicao_encargo (chave de parametros_encargos_pagamento); o texto
--                                          propostas.condicao_pagamento (200) continua sendo o da proposta impressa
--   Com ou sem impostos          propostas.isento_impostos (já existe)
--   Frete na compra (tipo)       FALTA  -> propostas.frete_compra_tipo (RATEIO ou VALOR)
--   Valor ST (venda)             propostas.total_st (já existe, soma da ST dos itens)  [OQ-A02: a ST digitada no simulador era do cabeçalho]
--   Imposto retido / DIFAL       FALTA  -> propostas.imposto_retido_difal
--   Frete na venda               propostas.valor_frete (já existe)
--   Item: descrição e código     propostas_itens.descricao, propostas_itens.codigo (já existem)
--   Item: FAB. (fabricação)      propostas_itens.natureza_custo = 'FABRICACAO' (já existe)
--   Item: QTD, UM (compra)       FALTA  -> propostas_itens.qtd_compra, unidade_compra
--   Item: PREÇO (compra)         propostas_itens.custo (já existe; ❓ confirmar que é o unitário na unidade de compra)
--   Item: ORIGEM                 FALTA  -> propostas_itens.origem_compra
--   Item: % IPI, ST, FRETE (compra) FALTA -> propostas_itens.ipi_compra_pct, st_compra_valor, frete_compra_valor
--   Item: FORNECEDOR             propostas_itens.fornecedor_nome / id_fornecedor (já existem)
--   Venda: QTD, PREÇO            propostas_itens.quantidade, preco_unitario_liquido (já existem; OQ-A02: sem IPI e ST)
-- ============================================================================

BEGIN;

ALTER TABLE core_comercial.propostas
  ADD COLUMN destino_icms          varchar(12),
  ADD COLUMN condicao_encargo      varchar(40),
  ADD COLUMN frete_compra_tipo     varchar(6)    NOT NULL DEFAULT 'RATEIO',
  ADD COLUMN imposto_retido_difal  numeric(15,2) NOT NULL DEFAULT 0,
  ADD CONSTRAINT ck_propostas_frete_compra_tipo CHECK (frete_compra_tipo IN ('RATEIO','VALOR')),
  ADD CONSTRAINT ck_propostas_difal CHECK (imposto_retido_difal >= 0);
COMMENT ON COLUMN core_comercial.propostas.destino_icms IS 'Entrada do motor de comissão: destino da venda (SP, MG, PR, RJ, SC, RS, DEMAIS), chave de core_comissao.parametros_icms_saida. Padrão sugerido: a UF do cliente.';
COMMENT ON COLUMN core_comercial.propostas.condicao_encargo IS 'Entrada do motor de comissão: condição de pagamento que tem encargo em core_comissao.parametros_encargos_pagamento (ex.: 28/45). O texto livre da proposta fica em condicao_pagamento.';
COMMENT ON COLUMN core_comercial.propostas.frete_compra_tipo IS 'RATEIO = percentual de logística dos parâmetros; VALOR = frete informado por item (propostas_itens.frete_compra_valor). Vale para o cálculo COTADO; cada evento de custo real traz o seu (N16-20).';

ALTER TABLE core_comercial.propostas_itens
  ADD COLUMN qtd_compra        numeric(15,4),
  ADD COLUMN unidade_compra    varchar(10),
  ADD COLUMN origem_compra     varchar(25),
  ADD COLUMN ipi_compra_pct    numeric(7,4)  NOT NULL DEFAULT 0,
  ADD COLUMN st_compra_valor   numeric(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN frete_compra_valor numeric(15,2) NOT NULL DEFAULT 0,
  ADD CONSTRAINT ck_propostas_itens_origem_compra CHECK (origem_compra IS NULL OR origem_compra IN
      ('SP','SP_REDUZIDA','OUTRA_UF','IMPORTACAO_SP','IMPORTACAO_OUTRA_UF','SIMPLES')),
  ADD CONSTRAINT ck_propostas_itens_compra CHECK (qtd_compra IS NULL OR qtd_compra > 0),
  ADD CONSTRAINT ck_propostas_itens_frete_compra CHECK (frete_compra_valor >= 0 AND st_compra_valor >= 0 AND ipi_compra_pct BETWEEN 0 AND 100);
COMMENT ON COLUMN core_comercial.propostas_itens.qtd_compra IS 'Quantidade COMPRADA, na unidade de compra (pode diferir da venda: 1 PC comprada, 4,5 M2 vendidos). O motor não converte unidade (motor.ts:273-277).';
COMMENT ON COLUMN core_comercial.propostas_itens.origem_compra IS 'Origem da compra para o crédito de ICMS de entrada. Obrigatória em item de revenda (natureza MATERIAL ou SERVICO) para o motor calcular; fabricação não tem origem.';

-- Completo para o motor (somar à definição de fn_item_completo, OQ-20): revenda exige qtd_compra e origem_compra.
CREATE OR REPLACE VIEW core_comercial.vw_proposta_item_motor AS
SELECT i.id AS id_proposta_item, i.id_proposta, i.ordem,
       i.natureza_custo, CASE WHEN i.natureza_custo = 'FABRICACAO' THEN 'FABRICACAO_INTERNA' ELSE 'REVENDA' END AS tipo_item_motor,
       i.codigo, i.descricao, i.quantidade AS qtd_venda, i.unidade_medida AS unidade_venda, i.preco_unitario_liquido AS preco_unit_venda,
       i.qtd_compra, i.unidade_compra, i.custo AS preco_unit_compra, i.fornecedor AS fornecedor, i.origem_compra,
       i.ipi_compra_pct AS pct_ipi, i.st_compra_valor AS valor_st, i.frete_compra_valor,
       (i.natureza_custo = 'FABRICACAO'
        OR (coalesce(i.qtd_compra, 0) > 0 AND coalesce(i.custo, 0) > 0 AND i.origem_compra IS NOT NULL)) AS pronto_para_motor
  FROM core_comercial.propostas_itens i;
COMMENT ON VIEW core_comercial.vw_proposta_item_motor IS 'Item da proposta nos nomes de entrada do motor (ItemEntrada de lib/simulador/tipos.ts). A API-022 lê esta view para montar a entrada do cálculo COTADO.';

-- N16-106: o pedido digitado no Omie entra no mesmo fluxo do Hub, e a simulação da comissão é a parte de compras que o vendedor
-- preenche no próprio pedido. Por isso o pedido tem as mesmas entradas do motor que a proposta (no pedido da proposta, o motor
-- continua lendo a proposta; estas colunas ficam vazias).
ALTER TABLE core_comercial.pedidos
  ADD COLUMN destino_icms          varchar(12),
  ADD COLUMN condicao_encargo      varchar(40),
  ADD COLUMN frete_compra_tipo     varchar(6)    NOT NULL DEFAULT 'RATEIO',
  ADD COLUMN imposto_retido_difal  numeric(15,2) NOT NULL DEFAULT 0,
  ADD CONSTRAINT ck_pedidos_frete_compra_tipo CHECK (frete_compra_tipo IN ('RATEIO','VALOR')),
  ADD CONSTRAINT ck_pedidos_difal CHECK (imposto_retido_difal >= 0);

ALTER TABLE core_comercial.pedidos_itens
  ADD COLUMN qtd_compra        numeric(15,4),
  ADD COLUMN unidade_compra    varchar(10),
  ADD COLUMN origem_compra     varchar(25),
  ADD COLUMN ipi_compra_pct    numeric(7,4)  NOT NULL DEFAULT 0,
  ADD COLUMN st_compra_valor   numeric(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN frete_compra_valor numeric(15,2) NOT NULL DEFAULT 0,
  ADD CONSTRAINT ck_pedidos_itens_origem_compra CHECK (origem_compra IS NULL OR origem_compra IN
      ('SP','SP_REDUZIDA','OUTRA_UF','IMPORTACAO_SP','IMPORTACAO_OUTRA_UF','SIMPLES')),
  ADD CONSTRAINT ck_pedidos_itens_compra CHECK (qtd_compra IS NULL OR qtd_compra > 0),
  ADD CONSTRAINT ck_pedidos_itens_frete_compra CHECK (frete_compra_valor >= 0 AND st_compra_valor >= 0 AND ipi_compra_pct BETWEEN 0 AND 100);

CREATE OR REPLACE VIEW core_comercial.vw_pedido_item_motor AS
SELECT i.id AS id_pedido_item, i.id_pedido, p.origem, p.codigo_empresa, p.numero_pedido_omie, i.ordem,
       i.natureza_custo, CASE WHEN i.natureza_custo = 'FABRICACAO' THEN 'FABRICACAO_INTERNA' ELSE 'REVENDA' END AS tipo_item_motor,
       i.codigo_produto_omie, i.descricao, i.quantidade AS qtd_venda, i.unidade_medida AS unidade_venda, i.valor_unitario AS preco_unit_venda,
       i.qtd_compra, i.unidade_compra, i.custo AS preco_unit_compra, i.fornecedor, i.origem_compra,
       i.ipi_compra_pct AS pct_ipi, i.st_compra_valor AS valor_st, i.frete_compra_valor,
       (i.natureza_custo = 'FABRICACAO'
        OR (coalesce(i.qtd_compra, 0) > 0 AND coalesce(i.custo, 0) > 0 AND i.origem_compra IS NOT NULL)) AS pronto_para_motor
  FROM core_comercial.pedidos_itens i
  JOIN core_comercial.pedidos p ON p.id = i.id_pedido;
COMMENT ON VIEW core_comercial.vw_pedido_item_motor IS 'Item do pedido nos nomes de entrada do motor. A API-022 lê esta view para a simulação do pedido digitado no Omie (N16-106): a parte de vendas veio do Omie e a de compras o vendedor preencheu. O item é o produto (codigo_produto_omie).';

COMMIT;
