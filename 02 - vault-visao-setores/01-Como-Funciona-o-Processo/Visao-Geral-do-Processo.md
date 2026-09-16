---
tags: [visao-setores, fluxo-operacional]
criado: 2026-09-16
---

# Visão Geral do Processo

Este texto explica, em linguagem simples, o caminho que um pedido percorre dentro da Aços Vital, do momento em que o cliente compra até o momento em que a mercadoria sai pela porta com a nota fiscal. A ideia é entender o pedido "de 0 a 100%": ele nasce em Vendas, passa pelo PCP, segue por um de três caminhos possíveis (estoque, compra de terceiros ou fabricação própria), passa pela Qualidade e termina no Faturamento e na Expedição.

## O caminho em quatro etapas

1. **Vendas recebe e registra o pedido.** O vendedor cadastra a venda no sistema comercial. Veja [[Vendas-e-Entrada-do-Pedido]].
2. **O PCP organiza o pedido.** O PCP (Planejamento e Controle de Produção) olha item por item do pedido e decide de onde cada item vai sair. Veja [[Organizacao-do-Pedido-PCP]].
3. **Cada item segue seu próprio caminho.** Dependendo do item, ele pode:
   - Já estar pronto no estoque — veja [[Controlando-o-Estoque]];
   - Precisar ser comprado de um fornecedor — veja [[Comprando-o-que-Falta]];
   - Precisar ser cortado sob medida a partir de uma chapa comprada — veja [[Cortando-Chapas-sob-Medida]];
   - Precisar ser fabricado do zero numa das linhas próprias da empresa (flange, grade de piso, entre outras) — veja [[Fabricando-Produtos-Proprios]].
4. **O pedido é fechado.** Depois que os itens passam pela conferência da Qualidade, a nota fiscal é emitida e a mercadoria é despachada. Veja [[Faturamento-e-Entrega]].

Antes de qualquer item virar carga pronta pra embarcar, ele passa por uma conferência de Qualidade — veja [[Qualidade-e-Conferencia]]. E para saber quem faz o quê em cada uma dessas etapas, veja [[Quem-Faz-o-Que]].

## A ideia central: o pedido não anda como um bloco só

O erro mais comum de quem vê o processo de fora é pensar no pedido como uma coisa única, que anda inteira do começo ao fim. Não é assim que funciona. Um mesmo pedido pode ter, ao mesmo tempo:

- um item que já está pronto no estoque e pode ser separado hoje;
- um item que precisa ser comprado de um fornecedor e vai demorar semanas;
- um item que vai ser fabricado do zero na fábrica de flanges.

Cada item do pedido anda no seu próprio ritmo. É por isso que a empresa decide, no fim, se fatura o pedido **parcial** (libera e fatura os itens que já ficaram prontos, sem esperar os outros) ou **integral** (espera todos os itens do pedido ficarem prontos para faturar de uma vez). Essa decisão depende de como está o conjunto dos itens daquele pedido — se a maioria já terminou, faz sentido fechar tudo junto; se só uma parte terminou e o resto vai demorar, faz mais sentido liberar o que já está pronto.

## Três origens possíveis para um item

Todo item de um pedido, olhando com calma, vem de um destes lugares:

| Origem | O que significa | Onde ler mais |
|---|---|---|
| **Estoque** | O item já existe pronto no depósito da empresa | [[Controlando-o-Estoque]] |
| **Revenda** | O item é comprado de um fornecedor externo (com ou sem corte sob medida depois) | [[Comprando-o-que-Falta]], [[Cortando-Chapas-sob-Medida]] |
| **Fabricação própria** | O item é produzido internamente numa linha própria da empresa | [[Fabricando-Produtos-Proprios]] |

Importante: "estoque" não é bem uma quarta origem separada — é só a situação de um item que já está pronto, seja ele de revenda ou de fabricação própria. Quem decide isso, item por item, é o PCP, na etapa descrita em [[Organizacao-do-Pedido-PCP]].

## Ver também
- [[Home]]
- [[Vendas-e-Entrada-do-Pedido]]
- [[Organizacao-do-Pedido-PCP]]
- [[Controlando-o-Estoque]]
- [[Comprando-o-que-Falta]]
- [[Fabricando-Produtos-Proprios]]
- [[Cortando-Chapas-sob-Medida]]
- [[Qualidade-e-Conferencia]]
- [[Faturamento-e-Entrega]]
- [[Quem-Faz-o-Que]]
- [[Glossario]]
