---
id: API-020
aliases: ["Contrato API 020", "020-Orcamento-Base-de-Preco-e-Pedido-de-Custo"]
tags: [contrato, contrato-api, orcamento, base-de-preco, fornecedor, pedido-de-custo, api-acos-vital]
criado: 2026-10-21
atualizado: 2026-10-29
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
> - 🟡 **29/10/2026, página do produto e matriz (Pablo, branch local `feat/orcamento-historico-preco` da `api-acos-vital`, sem merge):** as três rotas de leitura da §2 estão feitas e testadas sobre o que o Hub já tem, com caminhos ajustados (ver a §2). Servem de base para quem ficar com produtos. 🔴 **A alinhar:** o Pablo propõe ficar com produtos e o Robert com o comercial ([[Roteiro-da-Proposta-em-Diante]] §5.2); até o Robert e o Nathan confirmarem, vale a N16-117.
> - 📝 **N16-113:** o pedido de cotação ao fornecedor por e-mail fica para o futuro; segue fora do sistema.
> - ✅ Hoje, no `api-comercial` de teste: pedido de custo (com prazo de 2 dias úteis e SLA calculado), média de preços, catálogo. 🔴 O resto não existe.
> - 📝 **Sai** o prazo obrigatório do pedido de custo e o SLA (`ATRASADA`, `VENCE_HOJE`, `NO_PRAZO`): o tempo é só **cronometrado** (N16-58). O setor orçamentário é novo; o Moisés é uma das pessoas (N16-104).

## 1. Por quê

O vendedor consulta a página do produto e pede custo sem bloquear a proposta; o Orçamento (e Compras) mantém a base. A API serve as duas telas sem expor edição ao vendedor.

## 2. Rotas 🟡

| Rota | Quem | Efeito |
|---|---|---|
| `GET /produtos/:id/precos?dias=90` (era `/orcamento/produtos/:id`) | vendedor, Orçamento, Compras (`catalogo-produtos`, `propostas`) | página do produto (`B2`): histórico na janela (7 a 1825 dias), média (ponderada pela quantidade quando todos os pontos têm), mínimo, máximo, últimos 10 preços, flutuação (mensal, anual e total), volatilidade (desvio-padrão amostral ÷ média; sem número abaixo de 3 pontos), dado recente (7 dias) e top fornecedores com score. Só leitura. 🟡 feito em branch (29/10) |
| `GET /produtos/:id/precos/serie?dias=365` (era `/orcamento/produtos/:id/serie`) | idem | série do gráfico "bolsa de valores": cada ponto com data, valor, origem (`COMPRA` ou `COTACAO`) e fornecedor. 🟡 feito em branch (29/10) |
| `GET /orcamento/matriz_precos` (era `/orcamento/matriz-precos`) | Orçamento, Compras (`matriz-precos`, `catalogo-produtos`) | matriz v1 produto × fornecedor (OQ-10): o último preço de cada fornecedor na janela, do menor para o maior; busca, família, empresa e período; paginada por produto. 🟡 feito em branch (29/10) |
| `GET/POST /orcamento/ofertas`, `POST /:id/invalidar` `{ motivo }` | Orçamento, Compras, Gerente de Compras | oferta nunca se altera; corrigir é invalidar com motivo e lançar outra |
| `GET/POST/PUT /orcamento/fornecedores` e `/:id`, `/certificados`, `/apelidos` | Orçamento, Compras | cadastro; fornecedor pode existir sem Omie; CNPJ alfanumérico |
| `GET/PUT /orcamento/parametros-custo`, `/tabela-telha` | Orçamento | parâmetros com vigência |
| `POST /orcamento/solicitacoes-custo` | vendedor (`solicitacoes-custo`) | pede custo (`B3`); numeração própria; **sem prazo** |
| `GET /orcamento/solicitacoes-custo` | vendedor (as dele), Orçamento, Comprador | lista com o tempo cronometrado |
| `POST /orcamento/solicitacoes-custo/:id/responder`, `/cancelar` | Orçamento, Comprador | resposta (`B4`) com histórico; o vendedor recebe notificação |
| (job) `fn_oferta_gerar_de_ocs` e recálculo da base | sistema | a cada 15 min; diário |

**Por que os caminhos da página do produto e da matriz mudaram (29/10/2026):** `GET /orcamento/produtos` já existe no Orçamento antigo (`core_compras`, `orcamento.route.js`), e o `/:id` dele entraria em conflito. A página fica junto do produto do Hub (`/produtos/:id`, que já tem `/fornecedores`), e a matriz segue o `snake_case` das rotas do Hub. Como `/produtos` e `/orcamento` têm rotas de outros schemas que aceitam só a chave de serviço (o MES lê `GET /produtos`), o token do usuário é exigido **em cada rota nova**, não na montagem.

**De onde vem o preço (29/10/2026):**
- **Compras do Omie:** `pedidos_compras_itens` de pedido não cancelado (`etapa <> 'CA'`), com o valor unitário já sem o desconto e a data em que o pedido entrou no Omie.
- **Cotações do Hub:** `core.parceiros_produtos`.
- **Fora por enquanto:** `orc_cotacoes`. O fornecedor dessas cotações está com código legado, então a ligação depende da revisão do Orçamento antigo.
- **Sem imposto por item:** nenhuma das duas fontes traz o imposto de cada item, então o valor é **preço**, não custo líquido.

**Score como está (29/10/2026):**
- **Nota de preço:** o menor último preço entre os fornecedores ÷ o último preço deste fornecedor.
- **Nota de prazo:** o menor prazo médio ÷ o prazo médio deste fornecedor. O prazo de cada compra é a previsão de entrega menos a data do pedido.
- **Nota de histórico:** fica **neutra (50)**, porque não há data real de recebimento.
- **Sem dado:** a nota fica neutra e aparece um aviso.
- **Desempate:** pelo número de compras.
- **Ranking:** entre os fornecedores **do produto**. O ranking por categoria espera a lista única de categorias da revisão do Orçamento antigo.
- **Parâmetros:** os pesos, o limite de 15% e os 7 dias são constantes no código até existir a tabela de parâmetros com vigência (regra 3).

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
