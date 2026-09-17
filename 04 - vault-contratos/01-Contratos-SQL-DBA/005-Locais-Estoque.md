---
tags: [contrato-sql, dba, omie-elt-pipeline]
status: proposta
criado: 2026-09-17
---

# Contrato 010 — `core.locais_estoque`

**Status:** proposta, aguardando criação pelo DBA (Gustavo). Nada aplicado
ainda. Design **não fechado com o usuário** — vem da documentação pública
da API (`developer.omie.com.br`, endpoint "Locais de Estoque"), não de
payload real confirmado.

**Repositório de origem:** `omie-elt-pipeline` (`sql/dba_migrations/010_locais_estoque_contrato.md`).

## Por quê

Recurso novo, sem endpoint hoje no pipeline. Cadastro pequeno e
estrutural (galpões/depósitos) — poucos registros esperados, candidato a
migrar como carga inicial única (full sync simples, sem janela de data,
mesmo padrão de `familiaProdutos.ts`). Pré-requisito para `estoque_saldo`
([[002-Estoque-Saldo|contrato 007]]) e para qualquer FK/lookup futuro por
`codigo_local_estoque`.

## Payload de referência (documentação pública, não confirmado contra conta real)

```
POST https://app.omie.com.br/api/v1/estoque/local/
{"call":"ListarLocalEstoque","param":[{"nPagina":1,"nRegPorPagina":50}], ...}
```

```
codigo_local_estoque   integer
codigo                 string(50)
descricao              string(250)
tipo                   string(1)
padrao                 string(1)   -- "S"/"N"
inativo                string(1)   -- "S"/"N"
codigo_cliente         integer      -- vínculo com cliente (estoque de terceiros)
dispOrdemProducao      string(1)   -- "S"/"N"
dispConsumoOP          string(1)   -- "S"/"N"
dispRemessa            string(1)   -- "S"/"N"
dispVenda              string(1)   -- "S"/"N"
consiSugeCompra        string(1)   -- "S"/"N", considerado em sugestão de compra
```

## DDL

```sql
CREATE TABLE core.locais_estoque (
  id                    uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa        uuid NOT NULL REFERENCES core.unidades(id)
                          ON UPDATE CASCADE ON DELETE RESTRICT,
  codigo_local_estoque_omie integer NOT NULL,
  codigo                varchar(50),
  descricao             varchar(250) NOT NULL,
  tipo                  varchar(1),
  padrao                boolean NOT NULL DEFAULT false,
  ativo                 boolean NOT NULL DEFAULT true,   -- inverso de "inativo"
  codigo_cliente_omie   integer,   -- estoque de terceiros, sem FK (mesmo motivo de sempre)
  disponivel_ordem_producao boolean NOT NULL DEFAULT false,
  disponivel_consumo_op     boolean NOT NULL DEFAULT false,
  disponivel_remessa        boolean NOT NULL DEFAULT false,
  disponivel_venda          boolean NOT NULL DEFAULT false,
  considera_sugestao_compra boolean NOT NULL DEFAULT false,
  id_origem             uuid,
  created_at            timestamptz NOT NULL DEFAULT now(),
  created_by            uuid,
  updated_at            timestamptz NOT NULL DEFAULT now(),
  updated_by            uuid,
  deleted_at            timestamptz,
  deleted_by            uuid
);

CREATE UNIQUE INDEX uq_locais_estoque_codigo_omie
  ON core.locais_estoque (codigo_empresa, codigo_local_estoque_omie)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_locais_estoque_ativo
  ON core.locais_estoque (ativo);

CREATE TRIGGER trg_locais_estoque_updated_at
  BEFORE UPDATE ON core.locais_estoque
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

## Perguntas em aberto (levar para o Gustavo antes de aplicar)

1. Se o Estoque/MES vier a ter seu próprio conceito de "depósito"
   (`deposito`/`warehouse`, já mencionado no PRD do vault 01 como "central
   compartilhado, múltiplos warehouses"), esta tabela pode acabar servindo
   só como espelho de referência do Omie, com o Estoque tendo sua própria
   tabela de depósito. Confirmar se `core.locais_estoque` deve ganhar uma FK
   opcional para o futuro `deposito` do Estoque, ou ficar isolada.

## Depois de criada

Avisar o dev para criar `src/omie/resources/locaisEstoque.ts` (novo
resource, full sync simples sem janela de data) e registrar em
`src/omie/resources/index.ts`. É pré-requisito para o contrato
[[002-Estoque-Saldo|007]] (`core.estoque_saldo`) se `estoque_saldo` vier a
ganhar FK para esta tabela no futuro (hoje o contrato 007 não tem essa FK,
por consistência com o padrão "sem FK entre recursos sincronizados de
forma independente").

## Ver também
- [[Home]]
- [[002-Estoque-Saldo]]
- [[004-Pedidos-Compras]]
