---
id: API-020
aliases: ["Contrato API 020", "020-Orcamento-Base-de-Preco-e-Pedido-de-Custo"]
tags: [contrato, contrato-api, orcamento, base-de-preco, fornecedor, pedido-de-custo, api-acos-vital]
criado: 2026-10-21
atualizado: 2026-10-28
status: proposta
sistemas: [hub-api]
dono: "Robert (rotas) e Gustavo (revisão)"
etapa_0b: [V0.2, B1, B2, B3, B4]
fontes: ["12-Orcamento-Base-de-Preco", "SQL-017-Orcamento-em-core_vendas_faturamento-Base-de-Preco-e-Pedido-de-Custo", "Proposta-Score-e-Volatilidade-OQ-46", "api-comercial 5aa5311: src/modules/custos/custos.routes.ts (pedido de custo, prazo 2 dias úteis em :378, SLA em :338)", "Registro-de-Decisoes (N16-06, N16-07, N16-52 a N16-59)"]
criado_original: 2026-10-16
---

# Contrato API 020 — Orçamento: base de preço, página do produto, fornecedores e pedido de custo (`/orcamento`)

> **Onde atua:** av-hub: API (`api-acos-vital`)

> [!info] Situação em 28/10/2026
> **Status:** `proposta` · **Dono:** Robert (N16-117; o Pablo acompanha); Gustavo revisa · Banco: [[SQL-017-Orcamento-em-core_vendas_faturamento-Base-de-Preco-e-Pedido-de-Custo]] · Regras: [[12-Orcamento-Base-de-Preco]]
>
> - 📝 **28/10/2026, ordem (N16-114 e N16-118):** produtos e histórico de preço vêm **logo depois da proposta**. O histórico de preço lê as compras do Omie e as cotações; a tela Histórico de compras sai (N16-108).
> - 📝 **28/10/2026, N16-117 a N16-119:** quem faz as rotas na `api-acos-vital` é o **Robert**; o Pablo acompanha. A `api-comercial` fica no repositório do av-hub **só para leitura** (legado de consulta, não roda nem publica; sai de produção). As telas do Pablo **ficam**: o Robert troca o backend delas (o BFF passa a chamar a `api-acos-vital`) e adapta onde divergem do vault, sem refazer do zero.
> - 📝 **28/10/2026, N16-116:** não existirá `core_comercial`; as tabelas ficam em **`core_vendas_faturamento`** ([[SQL-016-Proposta-e-Pedido-de-Venda-em-core_vendas_faturamento]], bloco A0). O prefixo `/comercial/` das rotas **sai** (N16-116, efeito 3). No Hub, as rotas de `core_vendas_faturamento` são montadas pelo nome do recurso (`/pedidos_vendas`, `/pedidos_liberacao`), então `/comercial/propostas` tende a virar `/propostas`; o nome final é do Robert com o Gustavo ❓. Nesta nota, leia `/comercial/...` como o recurso sem o prefixo.
> - 📝 **N16-113:** o pedido de cotação ao fornecedor por e-mail fica para o futuro; segue fora do sistema.
> - ✅ Hoje, no `api-comercial` de teste: pedido de custo (com prazo de 2 dias úteis e SLA calculado), média de preços, catálogo. 🔴 O resto não existe.
> - 📝 **Sai** o prazo obrigatório do pedido de custo e o SLA (`ATRASADA`, `VENCE_HOJE`, `NO_PRAZO`): o tempo é só **cronometrado** (N16-58). O setor orçamentário é novo; o Moisés é uma das pessoas (N16-104).

## 1. Por quê

O vendedor consulta a página do produto e pede custo sem bloquear a proposta; o Orçamento (e Compras) mantém a base. A API serve as duas telas sem expor edição ao vendedor.

## 2. Rotas 🟡

| Rota | Quem | Efeito |
|---|---|---|
| `GET /orcamento/produtos`, `/:id` | vendedor, Orçamento, Compras | lista e página do produto (`B2`): histórico, top fornecedores com score por categoria, últimos preços, flutuação (anual, mensal e total), volatilidade, média, dado recente (7 dias). Só leitura |
| `GET /orcamento/produtos/:id/serie` | idem | série do gráfico "bolsa de valores" (`vw_produto_serie_preco`) |
| `GET /orcamento/matriz-precos` | Orçamento, Compras | matriz v1 produto × fornecedor (OQ-10) |
| `GET/POST /orcamento/ofertas`, `POST /:id/invalidar` `{ motivo }` | Orçamento, Compras, Gerente de Compras | oferta nunca se altera; corrigir é invalidar com motivo e lançar outra |
| `GET/POST/PUT /orcamento/fornecedores` e `/:id`, `/certificados`, `/apelidos` | Orçamento, Compras | cadastro; fornecedor pode existir sem Omie; CNPJ alfanumérico |
| `GET/PUT /orcamento/parametros-custo`, `/tabela-telha` | Orçamento | parâmetros com vigência |
| `POST /orcamento/solicitacoes-custo` | vendedor (`solicitacoes-custo`) | pede custo (`B3`); numeração própria; **sem prazo** |
| `GET /orcamento/solicitacoes-custo` | vendedor (as dele), Orçamento, Comprador | lista com o tempo cronometrado |
| `POST /orcamento/solicitacoes-custo/:id/responder`, `/cancelar` | Orçamento, Comprador | resposta (`B4`) com histórico; o vendedor recebe notificação |
| (job) `fn_oferta_gerar_de_ocs` e recálculo da base | sistema | a cada 15 min; diário |

## 3. Regras

1. O vendedor **não edita** oferta nem matriz e **não é dono** do dado de custo (N16-07, N16-54).
2. O vendedor nunca fica bloqueado esperando resposta (N16-59).
3. Pesos do score (preço 50%, prazo 30%, histórico 20%), limites de volatilidade e dias do "dado recente" são parâmetros com vigência, lidos da configuração, não fixos no código ([[Proposta-Score-e-Volatilidade-OQ-46]]).
4. Valor mais atualizado vale; o histórico fica (N16-52).
5. Escopo: perfil **orçamentista** deve existir (OQ-21); `Admin (Dev)` não é ator.

## 4. Fora do contrato

A proposta e o pedido ([[API-019-Proposta-e-Pedido-de-Venda-na-API-do-Hub]]); a matriz com dimensões extras (OQ-10).

## 5. Aceite

1. O vendedor abre a página do produto e vê histórico, fornecedores com score e a série; tentar editar oferta responde 403.
2. Pedido de custo sem prazo: a lista mostra o tempo parado crescendo; nenhuma proposta é bloqueada.
3. Invalidar oferta exige motivo; a oferta continua no histórico.
4. A oferta de uma OC cancelada aparece invalidada.

## 6. Perguntas em aberto

OQ-10, OQ-21, OQ-38.

## Ver também

[[12-Orcamento-Base-de-Preco]] · [[SQL-017-Orcamento-em-core_vendas_faturamento-Base-de-Preco-e-Pedido-de-Custo]] · [[LOG-57-Menu-Vendas-Orcamento-Compras]] · [[API-019-Proposta-e-Pedido-de-Venda-na-API-do-Hub]] · [[Registro-de-Decisoes]]
