---
id: LOG-60
aliases: ["Contrato 60", "60-Matriz-de-Precos-e-Consulta-do-Vendedor"]
tags: [contrato, contrato-logica, hub-front, orcamento, base-de-preco, matriz-de-precos, vendedor]
criado: 2026-10-21
atualizado: 2026-10-29
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
>
> 🟡 **29/10/2026:** a **página do produto** e a **matriz de preços v1** estão desenhadas e construídas no av-hub, na branch local `feat/produtos-precos-vendas` do Pablo (a partir da `develop`, sem merge). As duas telas leem as rotas da [[API-020-Orcamento-Base-de-Preco-e-Pedido-de-Custo]] (branch da `api-acos-vital`, também sem merge). Desenho na §2.1. 🔴 **A alinhar:** o Pablo propõe ficar com produtos e o Robert com o comercial ([[Roteiro-da-Proposta-em-Diante]] §5.2).

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

### 2.1 Desenho da página do produto e da matriz (29/10/2026) 🟡

Segue o guia de interface do av-hub (`docs/design/guia-de-interface.md`): resumo antes do detalhe, cor de status sempre com texto, números tabulares, estados de carregando, vazio, erro e sem permissão.

**Página do produto** (`Orçamento › Produtos › <código>`): a aba **Preços** vem primeiro, antes de Cadastro (Omie), Especificação e Fornecedores.

| Bloco | O que mostra | Regra |
|---|---|---|
| Período | 30, 90, 180 ou 365 dias (padrão 90), guardado na URL (`?dias=`) | Valor fora da lista volta a 90 |
| Dado recente | pílula verde "Preço recente: R$ x há N dias" ou âmbar "Sem preço nos últimos N dias" | N16-72: N é o parâmetro da vigência (o da categoria do produto, quando houver; 7 de partida) |
| Unidade | pílula cinza "N preços em KG fora das contas" quando há preço em outra unidade | Só se compara preço na unidade do produto (OQ-46 §2) |
| Resumo (4 KPIs) | **Último preço** (data, origem e fornecedor); **Média** (de mínimo a máximo, nº de preços; "ponderada" quando todos os pontos têm quantidade); **Volatilidade** (% com "estável, até 15%", "alta, acima de 15%" ou "poucos dados"); **Flutuação no mês** (com a do ano e a total) | Para quem compra, preço subindo pede atenção (âmbar) e caindo é bom (verde) |
| Preço no período | gráfico com eixo de **tempo real**: compras do Omie em linha reta, cotações só como pontos | Sem curva suavizada, que inventaria picos; sem linha entre cotações espaçadas, que sugeriria preços que não existiram |
| Melhores fornecedores | posição, fornecedor, score com barra e as três notas, **custo líquido**, média, prazo médio e nº de compras; avisos ("sem histórico de entrega no prazo"); a legenda diz os pesos e a vigência ("vigência desde 01/10/2026" ou "valores de partida") | Rodapé explica a nota de preço pelo custo líquido sem imposto, a nota de histórico neutra e o desempate; sem categoria, diz que o ranking é só do produto |
| Melhores fornecedores em <categoria> | só quando o produto tem categoria de suprimento: posição, fornecedor, score com as notas, nº de produtos da categoria que ele fornece e nº de compras | Média das notas do fornecedor nos produtos da categoria, na mesma empresa e período (LOG-60 §2: "score por categoria") |
| Últimos preços | os 10 mais recentes: data, fornecedor, origem (Compra com o nº do pedido, ou Cotação), quantidade, preço e custo líquido | Rodapé diz o que é compra, o que é cotação, como sai o custo líquido (sem imposto) e quantos preços ficaram fora por unidade |

Só leitura: não há botão de edição (aceite 1). Enquanto a rota não existe no Hub publicado, a aba mostra "O histórico de preço ainda não está disponível na API do Hub" e o resto da página funciona.

**Matriz de preços** (`Orçamento › Produtos`, aba **Matriz de preços**, entre "Preços e fornecedores" e "Comparar"):

| Bloco | O que mostra |
|---|---|
| Filtros (na URL) | busca por código ou trechos da descrição (`inox%316`), empresa (Todas, AV, AU, HRM) e período |
| Linha | o produto (código com link para a página, descrição, família, unidade, empresa) e os fornecedores **do menor para o maior** último preço, cada um com origem e data; o menor fica realçado em verde |
| Menor preço e Diferença | o menor preço e quanto o maior passa do menor; acima de 15% a diferença ganha a pílula âmbar |

Só entram produtos com compra ou cotação no período; a paginação é por produto. **Ainda não tem:** vigência por oferta e edição por quem tem permissão (a matriz v1 da §2 previa as duas; ficam para quando a tabela de oferta única existir, N16-112).

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

[[API-020-Orcamento-Base-de-Preco-e-Pedido-de-Custo]] · [[SQL-017-Orcamento-em-core_vendas_faturamento-Base-de-Preco-e-Pedido-de-Custo]] · [[12-Orcamento-Base-de-Preco]] · [[LOG-57-Menu-Vendas-Orcamento-Compras]] · [[LOG-56-Fluxo-da-Proposta-ao-Pedido]]
