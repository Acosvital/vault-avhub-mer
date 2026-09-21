---
tags: [contrato-sql, dba, omie-elt-pipeline]
status: proposta
criado: 2026-09-17
---

# Contrato SQL 003 (antes 008 no omie-elt-pipeline) — `pedidos_vendas` (desconto) + 2 tabelas novas (frete, parcelas)

**Status:** proposta, aguardando revisão e aplicação pelo DBA (Gustavo).
Nada aplicado ainda. Design **não fechado com o usuário** — vem da
documentação pública da API (`developer.omie.com.br`, endpoint "Pedidos de
Venda" → tipo `pedido_venda_produto`), não de payload real confirmado.

**Repositório de origem:** `omie-elt-pipeline` (`sql/dba_migrations/008_pedidos_vendas_frete_parcelas_contrato.md`).

## Por quê

`pedidosVendas.ts` já consome `ListarPedidos` — o mesmo payload já traz
blocos de frete, parcelamento e desconto no nível do pedido que hoje não
são mapeados. Sem chamada de API nova.

## Campos do Omie envolvidos (referência)

```
cabecalho.tipo_desconto_pedido   string(1)
cabecalho.perc_desconto_pedido   decimal
cabecalho.valor_desconto_pedido  decimal

frete {
  modalidade_frete    string(1)
  codigo_transportadora integer
  placa_transporte    string(10)
  uf_transporte       string(2)
  qtde_volumes        integer
  peso_bruto_frete    decimal
  peso_liquido_frete  decimal
  valor_frete         decimal
  valor_seguro        decimal
  valor_despesas      decimal
  codigo_rastreio     string(50)
}

lista_parcelas[] {
  numero_parcela      integer
  data_vencimento     string(10)  -- dd/mm/aaaa
  valor_parcela       decimal
  percentual_parcela  decimal
  codigo_meio_pagamento string(3)
}
```

## DDL

```sql
-- Desconto no nível do pedido (hoje só existe por item, em produto_vendas)
ALTER TABLE core_vendas_faturamento.pedidos_vendas
  ADD COLUMN tipo_desconto_pedido  varchar(1),
  ADD COLUMN perc_desconto_pedido  numeric(6,3),
  ADD COLUMN valor_desconto_pedido numeric(14,2);

-- Frete (1:1 com pedido)
CREATE TABLE core_vendas_faturamento.pedidos_vendas_frete (
  id                    uuid PRIMARY KEY DEFAULT uuidv7(),
  id_pedido_venda       uuid NOT NULL REFERENCES core_vendas_faturamento.pedidos_vendas(id)
                          ON UPDATE CASCADE ON DELETE CASCADE,
  modalidade_frete      varchar(1),
  codigo_transportadora integer,
  placa_transporte      varchar(10),
  uf_transporte         varchar(2),
  qtde_volumes          integer,
  peso_bruto            numeric(12,3),
  peso_liquido          numeric(12,3),
  valor_frete           numeric(14,2),
  valor_seguro          numeric(14,2),
  valor_despesas        numeric(14,2),
  codigo_rastreio       varchar(50),
  created_at            timestamptz NOT NULL DEFAULT now(),
  created_by            uuid,
  updated_at            timestamptz NOT NULL DEFAULT now(),
  updated_by            uuid
);

CREATE UNIQUE INDEX uq_pedidos_vendas_frete_pedido
  ON core_vendas_faturamento.pedidos_vendas_frete (id_pedido_venda);

CREATE TRIGGER trg_pedidos_vendas_frete_updated_at
  BEFORE UPDATE ON core_vendas_faturamento.pedidos_vendas_frete
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Parcelas (1:N com pedido)
CREATE TABLE core_vendas_faturamento.pedidos_vendas_parcelas (
  id                      uuid PRIMARY KEY DEFAULT uuidv7(),
  id_pedido_venda         uuid NOT NULL REFERENCES core_vendas_faturamento.pedidos_vendas(id)
                            ON UPDATE CASCADE ON DELETE CASCADE,
  numero_parcela          integer NOT NULL,
  data_vencimento         date,
  valor_parcela           numeric(14,2),
  percentual_parcela      numeric(6,3),
  codigo_meio_pagamento   varchar(3),
  created_at              timestamptz NOT NULL DEFAULT now(),
  created_by              uuid,
  updated_at              timestamptz NOT NULL DEFAULT now(),
  updated_by              uuid
);

CREATE UNIQUE INDEX uq_pedidos_vendas_parcelas_pedido_num
  ON core_vendas_faturamento.pedidos_vendas_parcelas (id_pedido_venda, numero_parcela);

CREATE TRIGGER trg_pedidos_vendas_parcelas_updated_at
  BEFORE UPDATE ON core_vendas_faturamento.pedidos_vendas_parcelas
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

**FK para `pedidos_vendas` é segura aqui** (diferente do caso rejeitado no
contrato `003_produto_vendas_fks.sql`) porque frete/parcelas só são
gravados **na mesma transação**, logo depois do upsert do pedido pai —
mesmo padrão já usado por `produto_vendas` (que é filho direto do pedido,
não uma entidade sincronizada de forma independente).

## Perguntas em aberto (levar para o Gustavo antes de aplicar)

1. Confirmar se `lista_parcelas` sempre vem dentro do payload de
   `ListarPedidos` ou só em `ConsultarPedido` — mesma dúvida do contrato
   [[001-Parceiros-Dados-Fiscais|contrato SQL 001]] para `dadosBancarios`.
2. `pedidos_vendas_frete` como 1:1 — confirmar que o Omie nunca manda mais
   de um bloco de frete por pedido (parece ser o caso pela doc, mas não
   validado contra payload real).

## Depois de criada

Avisar o dev para ampliar `pedidosVendas.ts`: `mapRow` ganha as 3 colunas
novas de desconto; `afterUpsert` ganha dois upserts filhos (frete 1:1 via
`insertIfNotExists` com `ON CONFLICT ... DO UPDATE`, parcelas 1:N com loop,
mesmo padrão de `produto_vendas`).

## Ver também
- [[Indice-Contratos]]
- [[006-Pedidos-Vendas-Valor-Devolucao]]
