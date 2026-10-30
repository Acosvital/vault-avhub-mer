---
tags: [dados, schemas, postgres, mes, av-hub]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Gustavo (DBA)
fontes: [Dump MES de 14/10, Dump Avhub de 14/10 e de 29/10, prisma/migrations do api-pcp até 28/10, Registro-de-Decisoes #21, v1 Schema-Postgres-Multi-Dominio, Infraestrutura-Self-Hosted]
---

# Schemas do PostgreSQL

**Não é contradição:** o MES usa **um schema só (`public`)** e o av-hub usa **vários schemas por domínio**. São dois bancos diferentes, de times diferentes, com padrões diferentes, e nenhum enxerga o outro. Selos: [[Regras-do-Vault]].

## Os bancos

| Banco | Sistema | Schemas | Quem mantém | Ferramenta de migração |
|---|---|---|---|---|
| **MES** | `api-pcp` ([[MES-Backend]]) | só **`public`** | Robert | Prisma Migrate (66 migrations na `develop`, até `20261028120100`; `_prisma_migrations`) ✅ |
| **av-hub** | `api-acos-vital` e pipeline Omie ([[AV-Hub-API]], [[Pipeline-Omie]]) | `auth`, `core`, `core_aprovacao_de_vagas`, **`core_comercial`**, `core_comissionamento`, `core_compras`, `core_estoque` (vazio), `core_fluxo`, `core_mapas`, `core_organograma`, `core_vendas_faturamento`, `historico`, `omie_ctl`, `omie_raw` | Gustavo (DBA) | migrations SQL numeradas do DBA (034, 035b, 046b, 047b…, citadas no código da API) e contratos SQL-NNN; os arquivos não estão nos repositórios ❓ |
| **api-comercial** (legado, só leitura) | `api-comercial` ([[API-Comercial]]) | `core_comercial`, que **agora está no banco do av-hub** e é usado pelas rotas `/comercial/*` da `api-acos-vital` | Pablo (origem); Robert (rotas) | Prisma Migrate (13 migrations) na origem ✅ `api-comercial/prisma`; no av-hub a migration SQL `2026-10-15_052` (comentário do schema no dump) |

O dump do MES só tem `public` e a extensão `pgcrypto` ✅ `Dump MES (Esqueleto).sql:111`. O dump do av-hub de 14/10 tinha 13 `CREATE SCHEMA` ✅; o de 29/10 tem 14, com `core_comercial` ✅ `Dump do Avhub para referência (29.10).sql`. A decisão N16-116 diz que `core_comercial` não existirá (a proposta iria para `core_vendas_faturamento`); hoje o banco e o código ainda usam `core_comercial` 📝 x ✅.

## Por que o MES usa só `public` 📝 (decisão #21)

O MES nasceu como um serviço NestJS com Prisma, uma base própria e um escopo único (produção, Estoque, circuito de compra). Cada tabela tem nome inequívoco (`lotes`, `pedidos`, `requisicoes_compra`), então não há necessidade de separar por schema. O Estoque do MES, em particular, **fica em `public`** (não em `core_estoque`): a decisão de 07/10 (#21) fecha essa dúvida. O schema `core_estoque` do av-hub existe vazio, sem tabela, e **não deve receber** o estoque da fábrica ✅ dump (`core_estoque` só aparece no `CREATE SCHEMA`).

## Por que o av-hub divide por domínio

O av-hub é um banco corporativo com muitos módulos (vendas, faturamento, comissão, RH, compras, organograma, fluxo). O prefixo `core_*` agrupa o que é do ERP, e os demais schemas isolam:

| Schema | Domínio |
|---|---|
| `auth` | identidade e permissões ([[RBAC-e-Permissoes]]) |
| `core` | cadastros mestres vindos do Omie (unidades, parceiros, produtos, funcionários) |
| `core_vendas_faturamento` | pedidos, NF, liberação, **compras** (requisição, OC, follow-up), status e custo por item |
| `core_fluxo` | Torre de Fluxo (projeção do feed do MES) |
| `core_comercial` | proposta, cliente do CRM, oferta de fornecedor, custo (contrato 52) |
| `core_compras` | catálogo e Orçamento (`orc_*`) |
| `core_comissionamento`, `core_aprovacao_de_vagas`, `core_organograma`, `core_mapas` | módulos de Comissão, RH, organograma e mapa |
| `historico` | cópia congelada (`hst_*`) |
| `omie_raw`, `omie_ctl` | staging bruto e controle da pipeline |

O módulo de Compras do fluxo fica em **`core_vendas_faturamento`** (não em `core_compras`): as tabelas `requisicoes_compra`, `ordens_compra*`, `compradores`, `parametros_compras`, `pedidos_compras*` estão lá ✅ dump. `core_compras` guarda o Orçamento e os catálogos de preço. Há um comentário no código pedindo unir os dois ("refatorar: unir com core_vendas_faturamento") ✅ `schemas/core_compras/index.js:11`.

## Como os dois bancos se falam

Nenhum acesso cruzado: **sem `dblink`, sem `postgres_fdw`, sem view entre bancos**. A conversa é por HTTP com `x-api-key` ([[Integracao-AvHub-MES]], [[Chaves-e-Autenticacao]]). Cada lado guarda uma **projeção própria** do que lê do outro:

| O MES guarda | Vindo do av-hub | Chave |
|---|---|---|
| `materiais` | `core.produtos` (por `GET /produtos`) | `(codigo_empresa, codigo_produto_omie)`; guarda `id_produto_avhub` |
| `depositos.codigo_empresa`, `pedidos.id_unidade`, `fornecedores.codigo_empresa` | `core.unidades.id` | uuid |
| `requisicoes_compra_itens.avhub_*`, `requisicoes_compra_eventos_avhub` | `requisicoes_compra` e `requisicoes_compra_eventos` | `id_origem` = id do item no MES |
| `oc_referencia`, `oc_referencia_itens` (desde 15/10) | `GET /ordens-compra/referencia` (OC aprovada ou cancelada, com fornecedor desde 27/10) | `id_ordem_compra` |
| `requisicoes_hub_referencia` (desde 16/10) | `GET /compras/requisicoes/referencia` (API-009) | `id_requisicao` do Hub |
| `fornecedores` (sem uso) | `core.parceiros` | — |

| O av-hub guarda | Vindo do MES | Chave |
|---|---|---|
| `itens_pedido_status` | `GET /itens/status` | `(codigo_empresa, id_item_parcial, etapa, ocorrido_em)` |
| `itens_pedido_custo` | `GET /itens/custo` (publicado em 27/10, só na `develop` do MES) | `(codigo_empresa, numero_pedido, codigo_produto_omie)` |
| `core_fluxo.item_estado_projetado` | `GET /fluxo/eventos` (não publicado) | `(codigo_empresa, numero_pedido, codigo_item_omie)` |
| `requisicoes_compra` | `PUT /compras/requisicoes/origem/:id` | `id_origem` |
| `pedidos_vendas_liberacao.importado_mes_*` | `POST /pedidos_liberados/:n/importado` | `(codigo_empresa, numero_pedido)` |

A chave de negócio comum é **`codigo_empresa`** (uuid de `core.unidades`) ✅ [[Integracao-AvHub-MES]] (DEC-1): a filial vem do pedido, nunca da fábrica.

## Regras de convivência

1. **Ao citar tabela, sempre com o schema** no av-hub (`core_vendas_faturamento.ordens_compra`) e sem schema no MES (`lotes`).
2. **Nunca criar objeto de Estoque no av-hub.** O saldo real mora no MES ([[Modelo-Estoque-e-Custo-do-Lote]]); `core.estoque_saldo` e `core.locais_estoque` são espelho do Omie, sem sync ligado ✅ `omie-elt-pipeline/src/omie/resources/estoque.ts:16`.
3. **Convenção de chave:** av-hub usa `uuidv7()` no banco; MES gera `uuid` na aplicação (Prisma) e não tem `DEFAULT` ✅ dumps.
4. **Convenção de auditoria:** av-hub tem `created_by`, `updated_by`, `deleted_by` e `deleted_at` em quase toda tabela; MES guarda autor só onde importa (`created_by_id`, `delivered_by_id`) e usa `deleted_at` em cadastros.
5. **Quantidade:** MES `numeric(14,4)`; requisição e OC no av-hub `numeric(15,4)`. O PUT de requisição aceita até 11 dígitos inteiros e arredonda a 5ª casa ✅ `requisicoes_compra.route.js:48-50`.
6. **`core_comercial` está no dump de 29/10** ✅ (23 tabelas); no de 14/10 não estava. É o schema do módulo comercial; ver a decisão N16-116 acima.

Detalhe das tabelas: [[Banco-MES]] e [[Banco-AvHub]]. O que existe em um lado e não no outro: [[Diferencas-Codigo-x-Banco]].
