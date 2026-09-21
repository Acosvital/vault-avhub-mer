---
tags: [contrato-sql, dba, omie-elt-pipeline]
status: proposta
criado: 2026-09-17
---

# Contrato SQL 002 (antes 007 no omie-elt-pipeline) — `core.estoque_saldo`

**Status:** proposta, aguardando criação pelo DBA (Gustavo). Nada aplicado
ainda. Design **não fechado com o usuário** — tipos/campos vêm da
documentação pública da API (`developer.omie.com.br`, endpoint "Consulta
Estoque"), não de um payload real confirmado contra a conta de produção.

**Repositório de origem:** `omie-elt-pipeline` (`sql/dba_migrations/007_estoque_saldo_contrato.md`).

## Por quê

O resource `estoque.ts` já existe no código com `enabled: false` — motivo
documentado no próprio recurso: não existe tabela de destino no schema do
DBA. Nada sincroniza saldo de estoque do Omie hoje. Esta é a lacuna mais
citada em toda a análise de lacunas do Estoque/MES (ver
[[Campos-Faltantes-para-Estoque-MES]]).

## Payload de referência (documentação pública, não confirmado contra conta real)

```
POST https://app.omie.com.br/api/v1/estoque/consulta/
{"call":"ListarPosEstoque","param":[{"nPagina":1,"nRegPorPagina":50,
  "dDataPosicao":"..."}], ...}
```

Campos retornados por produto (`produtos[]`, método `ListarPosEstoque`) ou
por consulta pontual (método `PosicaoEstoque`):

```
codigo_local_estoque   integer
saldo                  decimal   -- saldo de estoque
cmc                     decimal   -- Custo Médio Contábil
pendente                decimal   -- saldo pendente em pedidos de venda abertos
estoque_minimo          decimal   -- estoque mínimo (produto × local)
reservado               decimal   -- quantidade reservada
fisico                  decimal   -- quantidade física
nPrecoUnitario          decimal   -- só na listagem
```

## DDL

```sql
CREATE TABLE core.estoque_saldo (
  id                  uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa      uuid NOT NULL REFERENCES core.unidades(id)
                        ON UPDATE CASCADE ON DELETE RESTRICT,
  codigo_produto_omie varchar(60) NOT NULL,   -- mesmo domínio de
                                               -- core.produtos.codigo_produto_omie
  codigo_local_estoque integer NOT NULL,
  saldo               numeric(14,3) NOT NULL DEFAULT 0,
  fisico              numeric(14,3) NOT NULL DEFAULT 0,
  reservado           numeric(14,3) NOT NULL DEFAULT 0,
  pendente             numeric(14,3) NOT NULL DEFAULT 0,
  estoque_minimo       numeric(14,3),
  cmc                  numeric(14,4),   -- custo médio contábil, 4 casas
                                         -- (padrão contábil, evita
                                         -- arredondamento agressivo)
  preco_unitario       numeric(14,2),
  data_posicao         date NOT NULL,   -- data a que esta posição se refere
  id_origem            uuid,
  created_at           timestamptz NOT NULL DEFAULT now(),
  created_by           uuid,
  updated_at           timestamptz NOT NULL DEFAULT now(),
  updated_by           uuid,
  deleted_at           timestamptz,
  deleted_by           uuid
);

CREATE UNIQUE INDEX uq_estoque_saldo_produto_local
  ON core.estoque_saldo (codigo_empresa, codigo_produto_omie, codigo_local_estoque)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_estoque_saldo_produto
  ON core.estoque_saldo (codigo_empresa, codigo_produto_omie);

CREATE TRIGGER trg_estoque_saldo_updated_at
  BEFORE UPDATE ON core.estoque_saldo
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

**Sem FK para `core.produtos`** — mesmo motivo já documentado no contrato
rejeitado `003_produto_vendas_fks.sql`: saldo pode chegar referenciando um
produto que o pipeline ainda não sincronizou (sync de recursos é
independente e sem ordem garantida entre si).

## Perguntas em aberto (levar para o Gustavo antes de aplicar)

1. **Estratégia de upsert vs. série histórica**: este DDL trata saldo como
   "foto atual" (upsert por produto×local, sobrescreve). Se o time quiser
   manter histórico de saldo por data (série temporal para relatório), o
   design muda — a chave de conflito precisaria incluir `data_posicao`, e o
   volume de linhas cresce muito mais rápido. Confirmar qual dos dois casos
   de uso é o real antes de aplicar.
2. `cmc`/`preco_unitario` como `numeric(14,4)`/`numeric(14,2)` são chutes —
   confirmar contra o padrão já usado em `pedidos_vendas.valor_total_pedido`
   ou equivalente, se existir uma convenção de escala monetária no schema.

## Depois de criada

Avisar o dev para: (a) mudar `enabled: false` → `true` em
`src/omie/resources/estoque.ts`, (b) implementar `mapRow` com os campos
acima, (c) decidir a cadência de sync (saldo muda com frequência alta —
provavelmente merece camada própria em `windowedSync.ts`, não só o full
sync diário).

## Ver também
- [[Indice-Contratos]]
- [[001-Parceiros-Dados-Fiscais]]
- [[005-Locais-Estoque]]
