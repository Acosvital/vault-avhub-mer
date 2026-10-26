---
id: LOG-60
aliases: ["Contrato 60", "60-Matriz-de-Precos-e-Consulta-do-Vendedor"]
tags: [contrato, contrato-logica, hub-front, orcamento, base-de-preco, matriz-de-precos, vendedor]
criado: 2026-10-21
atualizado: 2026-10-21
status: proposta
sistemas: [hub-front]
dono: "Nathan"
etapa_0b: [V0.2, B1, B2, B3, B4]
fontes: ["Registro-de-Decisoes (N16-07, N16-52 a N16-59)", "12-Orcamento-Base-de-Preco", "Proposta-Score-e-Volatilidade-OQ-46", "API-020-Orcamento-Base-de-Preco-e-Pedido-de-Custo", "LOG-57-Menu-Vendas-Orcamento-Compras"]
criado_original: 2026-10-21
---

# Contrato 60 — matriz de preços, página do produto e pedido de custo (telas)

> **Onde atua:** av-hub: front (Orçamento e Vendas)

> [!info] Situação em 21/10/2026
> **Status:** `proposta` · **Dono:** Nathan · Rotas: [[API-020-Orcamento-Base-de-Preco-e-Pedido-de-Custo]] · Menu: [[LOG-57-Menu-Vendas-Orcamento-Compras]]. O setor orçamentário é novo; o Moisés é uma das pessoas (N16-104).

## 1. Por quê

O vendedor decide o valor que põe na proposta, mas não é o dono do dado de custo (N16-54). Ele precisa de uma consulta que lembre uma bolsa de valores e de um pedido de custo que não o bloqueie.

## 2. Telas 🟡

| Tela | Quem | Conteúdo |
|---|---|---|
| **Página do produto** (`B2`) | vendedor (só leitura), Orçamento, Compras | histórico de preços das OC, **top fornecedores com score por categoria** (preço 50%, prazo 30%, histórico 20%), últimos preços, flutuação anual, mensal e total, **volatilidade** e valor médio, dado recente (7 dias); gráfico em série |
| **Matriz de preços** (v1) | Orçamento, Compras | produto × fornecedor, vigência; edita quem tem permissão; dimensões extras na OQ-10 |
| **Ofertas e fornecedores** | Orçamento, Compras, Gerente de Compras | ofertas (invalidar com motivo; nunca editar), cadastro de fornecedor (pode não ter Omie), certificados, apelidos |
| **Pedido de custo** (`B3`, `B4`) | vendedor pede; Orçamento e Comprador respondem | lista com o **tempo cronometrado**, sem prazo fixo; o vendedor segue sem bloqueio |
| **Painel do Comprador** | Comprador | pedidos de custo, pedidos de cotação, ofertas |

## 3. Regras de tela

1. O vendedor vê preço e fornecedor como consulta e **escolhe o valor que põe na proposta**; não vê tela de edição de oferta.
2. Quando o vendedor não tem o dado, a tela de proposta oferece "pedir custo" e "ver histórico"; nenhuma das duas bloqueia salvar a proposta.
3. Pesos do score, limites de volatilidade e dias do dado recente vêm da configuração com vigência.
4. Valor mais atualizado vale; o histórico fica visível.

## 4. Aceite

1. O vendedor abre a página de um produto e vê histórico, score e volatilidade; os botões de edição não aparecem.
2. Pedir custo cria a solicitação com cronômetro e não impede aprovar uma proposta completa.
3. O Orçamento invalida uma oferta com motivo e ela segue no histórico.

## Ver também

[[API-020-Orcamento-Base-de-Preco-e-Pedido-de-Custo]] · [[SQL-017-Orcamento-em-core_comercial-Base-de-Preco-e-Pedido-de-Custo]] · [[12-Orcamento-Base-de-Preco]] · [[LOG-57-Menu-Vendas-Orcamento-Compras]] · [[LOG-56-Fluxo-da-Proposta-ao-Pedido]]
