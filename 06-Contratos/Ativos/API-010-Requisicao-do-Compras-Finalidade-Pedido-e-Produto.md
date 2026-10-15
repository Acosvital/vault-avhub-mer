---
id: API-010
aliases: ["Contrato 010", "010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto"]
tags: [contrato, contrato-api, compras, requisicao, av-hub]
criado: 2026-10-15
atualizado: 2026-10-15
status: proposta
dono: "Gustavo"
etapa_0b: [C0]
fontes: ["N14-28, N14-30, N14-31, N14-33 (Registro-de-Decisoes)", "api-acos-vital origin/develop b02d6c5: src/schemas/core_vendas_faturamento/tables/requisicoes_compra/requisicoes_compra.route.js:34-47,383-408; requisicoes_compra.model.js:34,55-56", "Dump Avhub (Esqueleto).sql:18541-18571 (requisicoes_compra), :17804-17817 (ordens_compra_itens_vinculos), core.produtos", "HUB PR #209 (tela própria da Nova requisição)"]
criado_original: 2026-10-15
---

# Contrato de API 010 — Requisição do Compras: finalidade, pedido de venda e produto do cadastro

> [!info] Situação em 15/10/2026
> **Status:** `proposta` · **Pasta:** `Ativos` · **Nó do 0b:** C0 · **Dono:** Gustavo (banco e API); Nathan (front, já pronto)
>
> - ✅ **Front pronto (HUB PR #209):** a "Nova requisição" é uma tela própria (`/compras/requisicoes/nova`), no padrão da OC, e já envia `finalidade`, `numero_pedido_venda` e o `material` igual ao `codigo_produto` do cadastro.
> - 🔴 **A API não atende ainda** (conferido em `api-acos-vital` `origin/develop` `b02d6c5`): não existe `finalidade`; o `POST /compras/requisicoes` descarta `numero_pedido_venda` (a lista `CAMPOS` do `requisicoes_compra.route.js:34-47` não o traz; só o PUT do MES o grava); `material` segue texto livre; nada valida pedido de venda nem produto.
> - Efeito hoje: a tela funciona sem erro, mas a requisição nasce sem finalidade e sem pedido de venda, e o PCP não a vê no MES. **Sem este contrato o API-009 (referência para o MES) não tem o que ler.**
>
> Selos em [[Regras-do-Vault]]. Este contrato **absorve a Parte 1** do [[API-009-Referencia-Requisicao-Hub-Integracao-MES]]; em caso de diferença, vale este.

**Destinatários:** backend do av-hub (`api-acos-vital`, Gustavo) e front do av-hub (Nathan, já feito; resta a tela da OC, abaixo).

## Por quê

Decisões do Nathan (15/10/2026): a requisição do Compras é **para que**: pedido de venda, recompra, estoque ou uso interno (N14-33); o produto é **sempre do cadastro** da unidade (N14-30); e pedido de venda, requisição e ordem de compra ligados entre si são **sempre da mesma unidade** (N14-31). Só a requisição com pedido de venda chega ao MES, para o PCP saber que o item já está em compra (N14-28). Hoje a requisição do hub não carrega nada disso.

## Parte 1: o banco

Migration versionada no repositório (BL-024), na `develop`.

| Mudança | Regra |
|---|---|
| Coluna `core_vendas_faturamento.requisicoes_compra.finalidade` | `varchar(20)`, `NOT NULL`, `CHECK` em `pedidos_venda`, `recompra`, `estoque`, `uso_interno` (a mesma lista de `ordens_compra.finalidade`) |
| Regra de coerência (`CHECK`) | `pedidos_venda` e `recompra` **exigem** `numero_pedido_venda`; `estoque` e `uso_interno` exigem `numero_pedido_venda IS NULL` |
| Preenchimento do que já existe | `pedidos_venda` se `numero_pedido_venda` não é nulo; senão `estoque` (inclui toda requisição que veio do MES sem pedido). Rodar antes de pôr o `NOT NULL` |
| `fn_requisicao_mes_aplicar` (migration 034) | Passa a gravar `finalidade` pelo mesmo critério (pedido de venda → `pedidos_venda`; sem → `estoque`). O PUT do MES não muda de contrato ([[LOG-34-Requisicoes-MES-Empurra-para-o-Hub]]) |
| `ordens_compra_itens_vinculos` | `codigo_empresa_pv` tem de ser igual ao `codigo_empresa` da OC (N14-31): `CHECK` ou trigger. ❓ Gustavo confere se o banco já recusa a diferença |
| Índice | `(codigo_empresa, numero_pedido_venda)` parcial onde `numero_pedido_venda IS NOT NULL` (base da referência do API-009) |

## Parte 2: a API

### `POST /compras/requisicoes`

Corpo (acrescenta aos campos de hoje):

| Campo | Regra |
|---|---|
| `finalidade` | **obrigatório**; um dos quatro valores. Fora da lista: `400 FINALIDADE_INVALIDA` |
| `numero_pedido_venda` | string até 30. **Obrigatório** com `pedidos_venda` ou `recompra`; **proibido** com `estoque` ou `uso_interno` (`400 FINALIDADE_PEDIDO_VENDA`). O pedido tem de existir em `core_vendas_faturamento.pedidos_vendas` na **mesma** `codigo_empresa` da requisição, não excluído (`400 PEDIDO_VENDA_INEXISTENTE`). A API preenche `codigo_pedido_omie` a partir do pedido |
| `material` | **obrigatório**; tem de ser igual a um `core.produtos.codigo_produto` da `codigo_empresa` da requisição (não excluído). Senão `400 PRODUTO_INEXISTENTE`. A API preenche `descricao` do cadastro quando não vier |
| `codigo_empresa`, `quantidade`, `unidade_medida`, `prazo_necessidade`, `acabado_sugerido`, `observacao` | como hoje |

A lista `CAMPOS` da rota passa a incluir `finalidade` e `numero_pedido_venda`. `created_by` da sessão, como hoje. Resposta `201` com a requisição inteira, incluindo `finalidade`.

### `PATCH /compras/requisicoes/:id`

Aceita trocar ou limpar `numero_pedido_venda` e trocar `finalidade` **somente** com `status` `aberta` ou `em_cotacao` e `id_origem` nulo (a requisição do MES não muda pelo Compras). Vale a mesma coerência do POST. O `material` **não** muda depois de criada. `atendida` e `cancelada` não mudam (`409` com mensagem).

### Leitura

`GET /compras/requisicoes` e `GET /compras/requisicoes/:id` devolvem `finalidade`. Filtro opcional `?finalidade=`. O resumo (`/resumo`) não muda.

### Erros

| Código | HTTP | Quando |
|---|---|---|
| `FINALIDADE_INVALIDA` | 400 | valor fora da lista |
| `FINALIDADE_PEDIDO_VENDA` | 400 | pedido ausente onde é exigido, ou presente onde é proibido |
| `PEDIDO_VENDA_INEXISTENTE` | 400 | pedido não existe na unidade |
| `PRODUTO_INEXISTENTE` | 400 | `material` não casa com o cadastro da unidade |
| `REQUISICAO_NAO_EDITAVEL` | 409 | `PATCH` em requisição do MES, atendida ou cancelada |

## Parte 3: a OC herda a finalidade (front, Nathan)

Hoje a tela da OC, quando vem de requisição, só limita a finalidade ("com pedido de venda, só pedidos de venda; sem, estoque ou uso interno", `finalidadesPermitidas` em `FecharCompra.tsx`). Com `finalidade` na requisição, a OC emitida a partir dela **herda a finalidade** (e o pedido de venda) da requisição. Quando junta várias requisições, elas têm de ter a mesma finalidade e as mesmas unidade e (se houver) pedido, senão a tela avisa. Fica como item do front depois da Parte 2.

## O que não muda

O contrato 34 (a ida do MES), o contrato 35 (os marcos), o `id_origem NOT NULL` dos eventos e o circuito do MES. A requisição **sem** pedido de venda continua sem chegar ao MES.

## Critérios de aceite

1. `POST` sem `finalidade` devolve 400. Com `estoque` e `numero_pedido_venda` devolve `FINALIDADE_PEDIDO_VENDA`.
2. `POST` com `pedidos_venda` e um pedido de outra unidade devolve `PEDIDO_VENDA_INEXISTENTE`.
3. `POST` com `material` que não é código do cadastro da unidade devolve `PRODUTO_INEXISTENTE`.
4. `POST` válido grava `finalidade`, `numero_pedido_venda` e `codigo_pedido_omie` e devolve 201 com os três.
5. `PATCH` troca o pedido de venda de requisição `aberta`; em requisição do MES, `atendida` ou `cancelada` devolve 409.
6. A requisição já existente e a que o MES empurra pelo PUT ficam com `finalidade` coerente (`pedidos_venda` com pedido, `estoque` sem).
7. Vínculo de OC com pedido de outra unidade é recusado.
8. Swagger atualizado (corpo do POST e do PATCH, erros, `finalidade` na resposta).
9. Ponta a ponta: a tela nova do HUB cria a requisição de cada finalidade e ela volta com os campos gravados.

## Ordem e rollback

| # | Quem | Passo |
|---|---|---|
| 1 | Gustavo | Migration (Parte 1) na `develop`, com o SQL versionado |
| 2 | Gustavo | POST, PATCH, leituras e swagger (Parte 2) |
| 3 | Nathan | Conferir a tela nova (PR #209) contra a API e a Parte 3 (OC herda a finalidade) |
| 4 | Gustavo | [[API-009-Referencia-Requisicao-Hub-Integracao-MES]] (rota de leitura para o MES) |

**Rollback:** a coluna é nova; reverter o deploy da API devolve ao comportamento de hoje (o HUB segue enviando os campos e a API os ignora). A migration não apaga dado.

## Perguntas em aberto

| # | Pergunta | Dono | Selo |
|---|---|---|---|
| Q1 | O banco já recusa vínculo da OC com pedido de outra unidade? Se não, `CHECK` ou trigger? | Gustavo | ❓ |
| Q2 | `recompra` exige o pedido que está sendo reposto (como a tela da OC)? Proposta: sim, igual a `pedidos_venda` | Nathan | 🟡 |
| Q3 | `uso_interno` precisa de campo "setor que pediu"? O Recebimento entrega ao setor que pediu ([[API-011-Compra-em-Andamento-Recebimento-por-Item-da-OC-e-Uso-Interno]]); hoje a requisição só tem `solicitante` (texto) | Nathan | 🔴 |
| Q4 | Requisição antiga sem `finalidade` e sem produto no cadastro: manter `material` como está (sem `PRODUTO_INEXISTENTE` retroativo)? Proposta: sim, a validação vale só para criação e troca | Gustavo | 🟡 |

Relacionados: [[API-009-Referencia-Requisicao-Hub-Integracao-MES]], [[API-004-Referencia-OC-Integracao-MES]], [[LOG-34-Requisicoes-MES-Empurra-para-o-Hub]], [[LOG-36-Compras-Produto-Obrigatorio-e-Comprador-da-OC]], [[04-Circuito-de-Compra]], [[Backlog-por-Frente]] (BL-041, BL-064), [[Registro-de-Decisoes]] (N14-28 a N14-33).
