---
tags: [contrato-sql, dba, omie-elt-pipeline]
status: proposta
criado: 2026-09-17
---

# Contrato 009 — `core_vendas_faturamento.pedidos_compras` + itens

**Status:** proposta, aguardando criação pelo DBA (Gustavo). Nada aplicado
ainda. Design **não fechado com o usuário** — vem da documentação pública
da API (`developer.omie.com.br`, endpoint "Pedidos de Compra"), não de
payload real confirmado.

**Repositório de origem:** `omie-elt-pipeline` (`sql/dba_migrations/009_pedidos_compras_contrato.md`).

## Por quê

Recurso novo, sem endpoint hoje no pipeline. `produtos/pedidocompra/` tem
CRUD completo confirmado na documentação (`IncluirPedCompra`,
`AlteraPedCompra`, `ExcluirPedCompra`, `UpsertPedCompra`, além de
`ConsultarPedCompra`/`PesquisarPedCompra`) — resolve a dúvida antiga sobre
se o Omie tem API de criação de Ordem de Compra (tem). Extrair histórico de
pedidos de compra é rastreabilidade de fornecedor real, além de ser
pré-requisito de dado para o módulo de Recebimento do Estoque.

## Payload de referência (documentação pública, não confirmado contra conta real)

```
POST https://app.omie.com.br/api/v1/produtos/pedidocompra/
{"call":"PesquisarPedCompra","param":[{"nPagina":1,"nRegPorPagina":50,
  "cEtapa":"..."}], ...}
```

```
cabecalho {
  nCodPed            integer
  cCodIntPed         string(20)
  cNumPedido         string(15)
  dDtPrevisao        string(10)
  nCodFor            integer   -- fornecedor
  cCnpjCpfFor        string(20)
  nCodCompr          integer   -- comprador
  cContato           string(60)
  cContrato          string(20)
  nCodCC             integer   -- conta corrente
  nCodProj           integer
  cCodCateg          string(20)
  cObs               text
  cObsInt             text
  cEmailAprovador     string(100)
  cEtapa              string(2)  -- pendente/faturado/recebido/cancelado/
                                  -- encerrado/parcial
}
frete { transportadora, tipo_frete, placa, uf, volumes, peso_liquido,
        peso_bruto, valor_frete, valor_seguro, valor_despesas }
produtos[] {
  nCodProd          integer
  nQtde             decimal
  nValUnit          decimal
  nPercDesconto     decimal
  codigo_local_estoque integer
  -- + blocos de ICMS/ICMS-ST/IPI/PIS/COFINS por item
}
parcelas[] { numero_parcela, data_vencimento, valor_parcela }
departamentos[] { codigo_departamento, valor_rateio, percentual_rateio }
```

## DDL

```sql
CREATE TABLE core_vendas_faturamento.pedidos_compras (
  id                    uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa        uuid NOT NULL REFERENCES core.unidades(id)
                          ON UPDATE CASCADE ON DELETE RESTRICT,
  codigo_pedido_compra_omie integer NOT NULL,
  codigo_pedido_integracao  varchar(20),
  numero_pedido         varchar(15),
  data_previsao          date,
  codigo_fornecedor      integer,          -- espelha codigo_parceiro_omie,
                                            -- sem FK (mesmo motivo de sempre)
  cnpj_cpf_fornecedor    varchar(20),
  codigo_comprador       integer,
  contato                varchar(60),
  numero_contrato        varchar(20),
  codigo_conta_corrente  integer,
  codigo_projeto         integer,
  codigo_categoria       varchar(20),
  observacao             text,
  observacao_interna     text,
  email_aprovador        varchar(100),
  etapa                  varchar(2),
  valor_total_pedido     numeric(14,2),
  transportadora         varchar(100),
  tipo_frete             varchar(1),
  placa_transporte       varchar(10),
  uf_transporte          varchar(2),
  qtde_volumes           integer,
  peso_liquido           numeric(12,3),
  peso_bruto             numeric(12,3),
  valor_frete            numeric(14,2),
  valor_seguro            numeric(14,2),
  valor_despesas          numeric(14,2),
  id_origem              uuid,
  created_at             timestamptz NOT NULL DEFAULT now(),
  created_by             uuid,
  updated_at             timestamptz NOT NULL DEFAULT now(),
  updated_by             uuid,
  deleted_at             timestamptz,
  deleted_by             uuid
);

CREATE UNIQUE INDEX uq_pedidos_compras_codigo_omie
  ON core_vendas_faturamento.pedidos_compras (codigo_empresa, codigo_pedido_compra_omie)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_pedidos_compras_fornecedor
  ON core_vendas_faturamento.pedidos_compras (codigo_empresa, codigo_fornecedor);

CREATE TRIGGER trg_pedidos_compras_updated_at
  BEFORE UPDATE ON core_vendas_faturamento.pedidos_compras
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Itens (1:N)
CREATE TABLE core_vendas_faturamento.pedidos_compras_itens (
  id                    uuid PRIMARY KEY DEFAULT uuidv7(),
  id_pedido_compra      uuid NOT NULL REFERENCES core_vendas_faturamento.pedidos_compras(id)
                          ON UPDATE CASCADE ON DELETE CASCADE,
  codigo_empresa        uuid NOT NULL REFERENCES core.unidades(id)
                          ON UPDATE CASCADE ON DELETE RESTRICT,
  codigo_produto_omie   varchar(60),      -- espelha core.produtos.codigo_produto_omie
  quantidade            numeric(14,3),
  valor_unitario         numeric(14,4),
  percentual_desconto    numeric(6,3),
  codigo_local_estoque   integer,
  cfop                   varchar(4),
  ncm                    varchar(10),
  created_at             timestamptz NOT NULL DEFAULT now(),
  created_by             uuid,
  updated_at             timestamptz NOT NULL DEFAULT now(),
  updated_by             uuid
);

CREATE INDEX idx_pedidos_compras_itens_pedido
  ON core_vendas_faturamento.pedidos_compras_itens (id_pedido_compra);

CREATE TRIGGER trg_pedidos_compras_itens_updated_at
  BEFORE UPDATE ON core_vendas_faturamento.pedidos_compras_itens
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

**Sem FK para `core.parceiros`/`core.produtos`** — mesmo princípio do
contrato rejeitado `003_produto_vendas_fks.sql` (sync independente, sem
ordem garantida).

## Perguntas em aberto (levar para o Gustavo antes de aplicar)

1. Este contrato cobre só **extração/leitura** (histórico de pedidos já
   feitos). O roteiro do vault também recomenda, à parte, que a *criação*
   de novos pedidos de compra passe a nascer no Estoque/MES em vez do Omie
   — se isso for decidido, o desenho de schema muda (o Estoque passaria a
   ser dono da linha, não um espelho read-only do Omie). Confirmar com o
   time antes de tratar esta tabela como definitiva.
2. `codigo_pedido_compra_omie` como `integer` — confirmar se o Omie sempre
   devolve um id numérico estável (equivalente ao `codigo_pedido_omie` de
   vendas) ou se existe um identificador mais robusto a usar como chave.
3. Falta identificar item de compra estável entre resyncs (equivalente ao
   `codigo_item_omie` de `produto_vendas`) — sem isso, resync de item pode
   duplicar (mesma classe de bug já corrigida em `produto_vendas`, ver
   README do `omie-elt-pipeline`, seção "Bug real encontrado..."). Confirmar
   na doc/payload real antes de aplicar.

## Depois de criada

Avisar o dev para criar `src/omie/resources/pedidosCompras.ts` (novo
resource) e registrar em `src/omie/resources/index.ts`.

## Ver também
- [[Indice-Contratos]]
- [[005-Locais-Estoque]]
