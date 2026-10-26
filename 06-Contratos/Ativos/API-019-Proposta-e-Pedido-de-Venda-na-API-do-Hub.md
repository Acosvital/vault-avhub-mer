---
id: API-019
aliases: ["Contrato API 015", "015-Proposta-e-Pedido-de-Venda-na-API-do-Hub"]
tags: [contrato, contrato-api, proposta, pedido-de-venda, omie, fila, compras, cancelamento, api-acos-vital]
criado: 2026-10-21
atualizado: 2026-10-21
status: proposta
sistemas: [hub-api, pipeline]
dono: "Pablo (módulo) e Gustavo (revisão)"
etapa_0b: [V0.1, V0.2, V0.3, V0.5, V0C, V0.6, V0.7, V1, C6, C7, C8]
fontes: ["LOG-56-Fluxo-da-Proposta-ao-Pedido (regras R1 a R66, rotas da seção 8)", "SQL-016-Schema-core_comercial-Proposta-e-Pedido-de-Venda", "api-comercial 5aa5311: src/modules/propostas/propostas.routes.ts, propostas.service.ts, src/domain/permissoes/capacidades.ts, src/lib/http/erros.ts", "omie-elt-pipeline envioOrdensCompra.ts:18-40 (padrão de fila)", "Estudo-Omie-API"]
criado_original: 2026-10-16
---

# Contrato API 015 — proposta, pedido de venda por API no Omie, compra acima do valor e cancelamento (`/comercial`)

> **Onde atua:** av-hub: API (`api-acos-vital`) · pipeline Omie

> [!info] Situação em 21/10/2026
> **Status:** `proposta` · **Dono:** Pablo migra o módulo de `api-comercial` (só de teste, N14-15) para a `api-acos-vital` (N16-15); Gustavo revisa. Regras de negócio: [[LOG-56-Fluxo-da-Proposta-ao-Pedido]]; banco: [[SQL-016-Schema-core_comercial-Proposta-e-Pedido-de-Venda]].
>
> - ✅ Existe hoje no `api-comercial`: proposta, revisão, versões, cálculo, duplicar, custo por item, pedido de custo, média de preços. 🔴 Não existe: aprovar, transformar, fila do Omie, `C8`, cancelamento, numeração só numérica.
> - 🟡 Rotas, códigos de erro e nomes são propostas; o envelope de erro do Hub (LOG-52) vale quando existir.

## 1. Por quê

O pedido deixa de nascer digitado no Omie e passa a nascer de uma proposta aprovada, criado por API pelo mesmo padrão da OC (fila e pipeline). Em volta disso a API precisa expor a revisão e a aprovação da proposta, o aviso ao vendedor quando a compra passa do valor, o cancelamento do pedido e a devolução de dados à pipeline.

## 2. Convenções

Prefixo `/comercial`; autenticação do Hub; `If-Match` com a versão em aprovar, cancelar e transformar; `Idempotency-Key` por usuário (24 h) em criar, duplicar e transformar; erro `{ error, code }` (`regra()` e `AppError`); chave de serviço para as rotas da pipeline. Permissões por tela do Hub (`propostas`, `propostas-valores`, `custo-item`, `painel-comprador`, `propostas-delegacao`, `relatorio-gerencial`, `clientes`) e as telas novas da matriz do LOG-56 §6; `Admin (Dev)` não é ator.

## 3. Rotas 🟡

### 3.1 Proposta (`V0.1` a `V0.5`, `V0C`)

| Rota | Efeito | Erros |
|---|---|---|
| `POST /comercial/propostas` | cria `ABERTA`; número automático e numérico | 422 |
| `PUT /comercial/propostas/:id` | revisa (só `ABERTA`); mudança de conteúdo gera `revisao + 1` com snapshot | 409 `PROPOSTA_TRAVADA`, 409 de versão |
| `GET /comercial/propostas`, `/:id`, `/:id/versoes` | lista, detalhe, revisões | 403 |
| `POST /comercial/propostas/:id/duplicar` | nova proposta; é o caminho depois de cancelar | — |
| `POST /comercial/propostas/:id/aprovar` `{ revisao }` | `ABERTA` → `APROVADA`; grava quem, quando e a revisão; PTAX do dia da aprovação em moeda estrangeira | 422 `PROPOSTA_INCOMPLETA` (lista os itens), 409 `REVISAO_DESATUALIZADA` |
| `POST /comercial/propostas/:id/cancelar` `{ motivo, motivo_texto }` | `ABERTA` ou `APROVADA` → `CANCELADA`; a comissão estimada vira histórico | 422 `MOTIVO_OBRIGATORIO`, 409 se já `TRANSFORMADA` |

### 3.2 Pedido de venda (`V0.6`, `V0.7`, `V1`)

| Rota | Efeito | Erros |
|---|---|---|
| `POST /comercial/propostas/:id/pedido_venda` `{ acompanhamento_qualidade }` | `fn_propostas_transformar_em_pedido`; grava na fila; proposta → `TRANSFORMADA`; idempotente | 422 `QUALIDADE_OBRIGATORIA`, `PRODUTO_PENDENTE`, `CLIENTE_SEM_CADASTRO_OMIE`; 409 `PEDIDO_JA_CRIADO` |
| `GET /comercial/pedidos_venda/fila-omie` | pipeline lê os pendentes | chave de serviço |
| `PATCH /comercial/pedidos_venda/:id/sincronizacao` `{ numero_omie, codigo_pedido_omie, codigo_pedido_integracao, status, erro }` | pipeline devolve o resultado; em `sincronizado`, **na mesma transação**, grava a liberação ([[LOG-58-Liberacao-do-Pedido-Origem-Proposta]]) | 409 se o número do Omie já existe |
| `POST /comercial/pedidos_venda/:id/reenviar` | `erro` → `pendente` ("Tentar novamente") | 409 |
| `GET /comercial/pedidos_venda`, `/:id` | leitura com status de sincronização e cancelamento | — |

A pipeline envia `IncluirPedido` com `codigo_pedido_integracao` e `codigo_item_integracao`; antes de recriar consulta pelo código (idempotência); se o Fiscal não consegue faturar um pedido que nasceu bloqueado, a pipeline faz `AlterarPedidoVenda` com `bloqueado = "N"` 🟡 (OQ-16, teste no Omie).

### 3.3 Compra acima do valor (`C8`)

| Rota | Efeito | Erros |
|---|---|---|
| `POST /comercial/divergencias_compra` | Compras registra (empresa, número do pedido, produto, OC, valor, motivo, margens, fornecedor, prazo, pagamento) → `fn_divergencia_registrar`; notifica o vendedor. Vale igual para o pedido do Omie (N16-106): compara com o custo que o vendedor preencheu no pedido | 422 `COMPRA_NAO_ESTA_ACIMA`, `MOTIVO_OBRIGATORIO`, `SEM_CUSTO_DO_VENDEDOR`, `PEDIDO_NAO_IMPORTADO`, `PEDIDO_CANCELADO`; 404 `ITEM_NAO_ENCONTRADO`, `VENDEDOR_NAO_ENCONTRADO` |
| `GET /comercial/divergencias_compra` | do vendedor (Meus Pedidos), por produto | — |
| `POST /comercial/divergencias_compra/:id/aprovar` e `/reprovar` | só o vendedor dono | 403, 409 `TRANSICAO_INVALIDA` |
| `GET /comercial/divergencias_compra?estado=REPROVADO` | lista de Compras com a idade (cronômetro) | — |
| `POST /comercial/divergencias_compra/:id/assumir` | Compras assume o caso | 409 |
| `POST /comercial/divergencias_compra/:id/resolver` `{ solucao_tipo, solucao_texto }` | só de `REPROVADO`; notifica o vendedor | 409, 422 `MOTIVO_OBRIGATORIO` |

A Gerência **não tem rota**: aprova fisicamente, com Compras (N16-66). Aprovada: a margem e a comissão do vendedor caem; o preço do cliente não muda.

### 3.4 Cancelamento (`V0C`)

| Rota | Efeito | Erros |
|---|---|---|
| `POST /comercial/pedidos_venda/:id/cancelar` `{ motivo }` | `fn_pedidos_cancelar`; na mesma transação a API cancela a requisição do PCP e a OC não emitida, avisa o PCP e a OC e leva a comissão a `CANCELADA`; o comprado vai ao Estoque | 422 `MOTIVO_OBRIGATORIO`, 409 `PEDIDO_FATURADO` ou já cancelado |
| (pipeline) chama o Omie | o cancelamento do vendedor vira `CancelarPedidoVenda` (ou `ExcluirPedido`, a decidir no teste) na conta da unidade; a pipeline confirma lendo `ListarEtapasPedido` (`cCancelado`, `dDtCanc`, `cUsCanc`) e marca `cancelado_no_omie = true`. Edição: `AlterarPedidoVenda`; exclusão: `ExcluirPedido`. O **vendedor** faz as três ações, antes do faturamento (N16-84) | 409 `PEDIDO_FATURADO` |

Pedido faturado em parte: cancela-se parte por parte; só o saldo segue as regras (LOG-56 R62).

### 3.5 Compras (`C6`, `C7`)

`GET /comercial/propostas/:id/compras` devolve a parte de compras da proposta ligada ao pedido (impostos, frete, fornecedor) para preencher a OC; o que Compras edita nos campos de imposto da OC volta ao Omie pela sincronização da OC, não por esta API.

## 4. Fora do contrato

Aprovação de desconto e margem no sistema (próximo ciclo); migração de propostas do ERP antigo; a comissão ([[API-022-Comissao-da-Proposta-Calculo-e-Decisao-da-Controladoria]]); o custo real por evento ([[API-021-Custo-Real-por-Evento-e-Conferencia-de-Compras]]); o orçamento ([[API-020-Orcamento-Base-de-Preco-e-Pedido-de-Custo]]).

## 5. Aceite

Os 30 testes de aceite do [[LOG-56-Fluxo-da-Proposta-ao-Pedido]] §11, com ênfase em 3 a 5 (incompleta, desatualizada, aprovada trava), 6 a 9 (Qualidade, fila, sincronização, erro do Omie), 13 a 17 (`C8`) e 26 a 28 (cancelamento).

## 6. Perguntas em aberto

OQ-16, OQ-21 (perfis), OQ-30 (corrigir a marcação da Qualidade até o MES importar), OQ-48.

## Ver também

[[LOG-56-Fluxo-da-Proposta-ao-Pedido]] · [[LOG-58-Liberacao-do-Pedido-Origem-Proposta]] · [[LOG-57-Menu-Vendas-Orcamento-Compras]] · [[SQL-016-Schema-core_comercial-Proposta-e-Pedido-de-Venda]] · [[Estudo-Omie-API]] · [[Registro-de-Decisoes]]
