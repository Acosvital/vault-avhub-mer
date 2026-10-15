---
id: SQL-005
aliases: ["Contrato SQL 010 do omie-elt-pipeline", "005-Locais-Estoque"]
tags: [contrato, contrato-sql, dba, omie-elt-pipeline]
criado: 2026-10-14
atualizado: 2026-10-14
status: aplicado-em-producao
sistemas: [hub-banco, pipeline-omie]
dono: "Gustavo (DBA)"
etapa_0b: []
fontes: ["Dump Avhub (Esqueleto).sql (core.locais_estoque)", "api-acos-vital/src/schemas/core/tables/locais_estoque"]
criado_original: 2026-09-17
---

# Contrato SQL 005 (antes 010 no omie-elt-pipeline) — `core.locais_estoque`

> **Onde atua:** av-hub: banco · pipeline Omie

> [!info] Situação em 14/10/2026
> **Status:** `aplicado-em-producao` · **Pasta:** `Entregues` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Gustavo (DBA)
>
> - ✅ `core.locais_estoque` existe no dump de 14/10 e tem rota própria (`api-acos-vital/src/schemas/core/tables/locais_estoque/locais_estoque.route.js`).
> - 🔴 Pergunta sobre FK opcional continua sem resposta (texto original).
> - ❓ Produção: aplicado segundo o dump de 21/09 (vault v1); não reconferido.
>
> Conferido em 14/10/2026 contra `api-pcp` 579a625, `app-pcp` 1fca8d3, `api-acos-vital` f322dcd, `omie-elt-pipeline` 0f739f0 e os dumps de 14/10. O front do av-hub (HUB b55ac55) só pelo vault v1 (❓).
> O texto original abaixo está inteiro.


**Status: aplicada — pergunta em aberto sobre FK opcional segue sem resposta.** Confirmado contra o dump de produção `dump-avhub_prd_db-202609210741.sql` (21/09/2026) — ver [[Mapa-v1-para-v2|Auditoria-Dump-Producao-2026-09-21]]. `core.locais_estoque` já existe, campos batem com o DDL proposto abaixo. **Sem FK para `deposito`** (tabela `deposito` ainda não existe do lado do Estoque/MES) — Gustavo adiciona quando ela existir; a pergunta em aberto 1 abaixo não é respondível por dump, é decisão de arquitetura ainda pendente.

**Repositório de origem:** `omie-elt-pipeline` (`sql/dba_migrations/010_locais_estoque_contrato.md`).

## Por quê

Recurso novo, sem endpoint hoje no pipeline. Cadastro pequeno e
estrutural (galpões/depósitos) — poucos registros esperados, candidato a
migrar como carga inicial única (full sync simples, sem janela de data,
mesmo padrão de `familiaProdutos.ts`). Pré-requisito para `estoque_saldo`
([[SQL-002-Estoque-Saldo|contrato SQL 002]]) e para qualquer FK/lookup futuro por
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
   (`deposito`/`warehouse`, já mencionado no PRD da seção de modelagem como "central
   compartilhado, múltiplos warehouses"), esta tabela pode acabar servindo
   só como espelho de referência do Omie, com o Estoque tendo sua própria
   tabela de depósito. Confirmar se `core.locais_estoque` deve ganhar uma FK
   opcional para o futuro `deposito` do Estoque, ou ficar isolada.

## Depois de criada

Avisar o dev para criar `src/omie/resources/locaisEstoque.ts` (novo
resource, full sync simples sem janela de data) e registrar em
`src/omie/resources/index.ts`. É pré-requisito para o contrato
[[SQL-002-Estoque-Saldo|SQL 002]] (`core.estoque_saldo`) se `estoque_saldo` vier a
ganhar FK para esta tabela no futuro (hoje o contrato SQL 002 não tem essa FK,
por consistência com o padrão "sem FK entre recursos sincronizados de
forma independente").

## Ver também
- [[HIST-Indice-Contratos|Indice-Contratos]]
- [[SQL-002-Estoque-Saldo|002-Estoque-Saldo]]
- [[SQL-004-Pedidos-Compras|004-Pedidos-Compras]]
- [[Mapa-v1-para-v2|Auditoria-Dump-Producao-2026-09-21]]
