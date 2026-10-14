---
id: SQL-002
aliases: ["Contrato SQL 007 do omie-elt-pipeline", "002-Estoque-Saldo"]
tags: [contrato, contrato-sql, dba, omie-elt-pipeline]
criado: 2026-10-14
atualizado: 2026-10-14
status: aplicado-em-producao
dono: "Gustavo (DBA)"
etapa_0b: []
fontes: ["Dump Avhub (Esqueleto).sql (core.estoque_saldo)", "api-acos-vital/src/schemas/core/tables/estoque_saldo"]
criado_original: 2026-09-17
---

# Contrato SQL 002 (antes 007 no omie-elt-pipeline) — `core.estoque_saldo`

> [!info] Situação em 14/10/2026
> **Status:** `aplicado-em-producao` · **Pasta:** `Entregues` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Gustavo (DBA)
>
> - ✅ `core.estoque_saldo` existe no dump de 14/10 e tem rota própria (`api-acos-vital/src/schemas/core/tables/estoque_saldo/estoque_saldo.route.js`).
> - 🟡 O estoque do Omie não alimenta o MES: o saldo do MES é próprio (schema `public` do MES, decisão #21). Esta tabela é só espelho do Omie.
> - ❓ Produção: conferido pelo dump de produção (21/09 e 07/10, vault v1); não reconferido hoje.
>
> Conferido em 14/10/2026 contra `api-pcp` 579a625, `app-pcp` 1fca8d3, `api-acos-vital` f322dcd, `omie-elt-pipeline` 0f739f0 e os dumps de 14/10. O front do av-hub (HUB b55ac55) só pelo vault v1 (❓).
> O texto original abaixo está inteiro; os trechos que o estado atual contradiz têm nota de rodapé.


> Status: decidido | em produção (verificado em 07/10/2026 pelo dump, [[Mapa-v1-para-v2|Auditoria-Dump-Producao-2026-10-07]]). **`core.estoque_saldo` e o recurso `estoque` do pipeline: sem função, o estoque do Omie é ignorado (✅ 07/10).** A tabela existe em produção, vazia; o Omie recebe dados só manualmente, o passo `ListarPosEstoque` não será feito e o MES é a referência do saldo físico. Fonte: [[Registro-de-Decisoes|Registro-de-Decisoes-2026-10-07]] (#28). O texto abaixo, que prevê ligar o recurso `estoque`, fica como histórico.

**Status: aplicada.** Confirmado contra o dump de produção `dump-avhub_prd_db-202609210741.sql` (21/09/2026) — ver [[Mapa-v1-para-v2|Auditoria-Dump-Producao-2026-09-21]]. `core.estoque_saldo` já existe, colunas batem quase exatamente com o DDL proposto abaixo. **Pergunta em aberto 1 resolvida na prática**: o model Sequelize `EstoqueSaldo` confirma que a implementação real é "foto atual" (upsert 1 linha por empresa+produto+local), não série histórica. Pergunta em aberto 2 (`cmc`/`preco_unitario`) segue sem confirmação formal registrada. Seção original abaixo preservada como histórico de design.

<details>
<summary>Texto original da proposta (17/09/2026), antes da confirmação em produção</summary>

**Status:** proposta, aguardando criação pelo DBA (Gustavo). Nada aplicado[^c1]
ainda. Design **não fechado com o usuário** — tipos/campos vêm da
documentação pública da API (`developer.omie.com.br`, endpoint "Consulta
Estoque"), não de um payload real confirmado contra a conta de produção.

</details>

**Repositório de origem:** `omie-elt-pipeline` (`sql/dba_migrations/007_estoque_saldo_contrato.md`).

## Por quê

O resource `estoque.ts` já existe no código com `enabled: false` — motivo
documentado no próprio recurso: não existe tabela de destino no schema do
DBA. Nada sincroniza saldo de estoque do Omie hoje. Esta é a lacuna mais
citada em toda a análise de lacunas do Estoque/MES (ver
[[Modelo-Estoque-e-Custo-do-Lote|Campos-Faltantes-para-Estoque-MES]]).

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
- [[HIST-Indice-Contratos|Indice-Contratos]]
- [[SQL-001-Parceiros-Dados-Fiscais|001-Parceiros-Dados-Fiscais]]
- [[SQL-005-Locais-Estoque|005-Locais-Estoque]]
- [[Mapa-v1-para-v2|Auditoria-Dump-Producao-2026-09-21]]

[^c1]: Nota de 14/10/2026: Superado: aplicado, ver a Situação em 14/10 no topo.
