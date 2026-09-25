---
tags: [erp-acos-vital, fluxo-operacional, modelagem, pcp]
criado: 2026-09-16
atualizado: 2026-09-24
---

# Modelo de Destinação do Item — Reconciliando Estoque × Revenda × Fabricação

> Formaliza a relação entre o diagrama macro ([[Fluxo-Operacional-Visao-Geral]]) e o fluxo detalhado item a item ([[Fluxo-Detalhado-Pedido-Item]]), que coexistiam por decisão consciente, mas nunca tinham sido modelados juntos de fato.
>
> **Atualizado em 24/09/2026 com o encaixe do Estoque e da Revenda no MES** ([[Encaixe-Estoque-Revenda-no-PCP]]). Duas mudanças: o **eixo 1 deixa de ser fixo por material** — é escolhido por item, a cada rodada, pela fábrica para onde o PCP manda o item; e o **eixo 2 é resolvido no setor Estoque** (etapa 1 de todo roteiro), com split do `ItemParcial` e reserva, não numa tela de classificação do PCP. A matriz continua válida como mapa dos casos; o que mudou foi **onde** cada eixo é decidido.

## O problema

O diagrama macro trata `[ESTOQUE]`, `[REVENDA]`, `[FABRICAÇÃO]` como três ramos paralelos e mutuamente exclusivos — como se todo item do pedido caísse em exatamente um dos três, de uma vez. Mas o fluxo detalhado mostra que "estoque" não é uma categoria do mesmo tipo que Revenda/Fabricação — é a resposta a uma **pergunta diferente**, feita sobre qualquer item de Revenda ou Fabricação.

## Três eixos independentes, não uma escolha única

**Eixo 1 — Natureza/origem do item.** De onde vem o valor do item:
- **Revenda** — comprado de terceiro, revendido (com ou sem beneficiamento, ex.: corte de chapa — ver [[Fabricacao-Chapas]]).
- **Fabricação** — produzido internamente numa linha própria (Flange hoje; Grade de Piso, Chapa Expandida, Caldeiraria etc. conforme cadastradas — ver [[Rota-Fabricacao]]).

**Decidido por item, a cada rodada, pela fábrica escolhida** (24/09/2026). A natureza é o `Fabrica.tipo` (`FABRICACAO` \| `REVENDA`) da fábrica para onde o PCP manda o item na Carteira — não um atributo fixo do produto. Em emergência, poucas unidades de um produto que normalmente fabricamos podem ser compradas para completar a entrega: essas vão para a fábrica Revenda, o restante para a de fabricação (OPs diferentes, mesmo produto). Não existe campo de natureza no item: ela vem de `Pedidos.idFabrica → Fabrica.tipo`.

~~Praticamente fixo por tipo de material/produto — não muda pedido a pedido.~~ *(substituído em 24/09/2026)*

**Eixo 2 — Disponibilidade física no momento da checagem.** O que existe fisicamente agora:
- **Pronto em estoque** — já existe como produto acabado.
- **Matéria-prima em estoque** — existe, mas precisa de beneficiamento/produção antes de liberar.
- **Sem estoque** — não existe fisicamente, precisa ser originado (compra, pra Revenda; início de produção, pra Fabricação).

Dinâmico — muda a cada verificação. **Resolvido no setor Estoque (etapa 1 de todo roteiro)**: o parcial chega lá, a parte que o saldo disponível cobre vira um split atendido (reserva + conclusão), e o restante segue o roteiro. Nesta fase só **produto acabado** é checado; matéria-prima fica para a J3 (genealogia).

**Eixo 3 — Destinação da reserva**, já modelada no PRD como `destinacao_item_pedido` (ver [[Estoque-Regras-Negocio]]). Pra que serve o saldo, uma vez que existe em estoque:
- **Específica pra este pedido** (reservado).
- **Específica pra produção** (reservado pra uma OS/OP em andamento).
- **Estoque geral** (não reservado, disponível pra qualquer demanda futura).

Desde 24/09/2026 a reserva de um pedido é a tabela `Reserva` (lote + `ItemParcial` do split atendido + quantidade + status `ATIVA`/`CONSUMIDA`/`LIBERADA`, sem expiração).

## A matriz resultante (eixo 1 × eixo 2)

| | Pronto em estoque | Matéria-prima em estoque | Sem estoque |
|---|---|---|---|
| **Revenda** (fábrica Revenda) | Split atendido no setor Estoque (etapa 1): reserva + conclusão → entrega. É o que [[Rota-Estoque]] descreve ("pronta entrega") | Consumo de MP fica para a J3. Até lá o beneficiamento (ex.: corte de chapa) é um setor `PRODUTIVO` opcional no roteiro da Revenda | Split segue para o setor Compras → requisição → Recebimento → (beneficiamento) → Qualidade → **volta ao setor Estoque** (entrada + reserva) → entrega — [[Rota-Revenda]] |
| **Fabricação** (fábrica da linha) | Split atendido no setor Estoque (etapa 1): reserva + conclusão → entrega | Consumo de MP fica para a J3; a OP segue pelos setores produtivos | Split segue pelos setores produtivos da linha → Qualidade → entrega. Compra de MP para a linha fica para a J3 |

## O que isso resolve

- **`[ESTOQUE]` no diagrama macro não é um quarto ramo** — é o cruzamento "Pronto em estoque" das duas colunas de Revenda e Fabricação. No MES isso ganhou forma concreta: é o **setor Estoque, etapa 1 de todo roteiro**, onde o split atendido termina.
- **`destinacao_item_pedido` (eixo 3) é ortogonal aos outros dois** — um item pode estar "pronto em estoque" (eixo 2) e já reservado pra produção específica (eixo 3) ao mesmo tempo, sem contradição.
- **A reserva liga o eixo 2 ao eixo 3** no momento em que o setor Estoque atende o split — e, para o item comprado, no momento em que ele volta da Qualidade para o Estoque. Nos dois casos ela nasce sobre lote já liberado.

## Como isso muda a implementação

- **Não existe tela de "classificação natureza × disponibilidade".** O eixo 1 é a escolha da fábrica na tela Ordem de Produção (a partir da Carteira); o eixo 2 é a ação "atender X do estoque" no setor Estoque. Ver [[Encaixe-Estoque-Revenda-no-PCP]] seção 4.
- `destinacao_item_pedido` (eixo 3) continua como está no PRD; a disponibilidade (eixo 2) é o saldo disponível na filial do pedido = saldo do lote liberado − reservas `ATIVAS`.
- O diagrama macro em [[Fluxo-Operacional-Visao-Geral]] pode continuar existindo como visão simplificada, mas qualquer tela operacional é desenhada em cima do roteiro tipado (Fábrica/Setor com tipo), não do modelo de 3 ramos paralelos.

## Ver também
- [[Encaixe-Estoque-Revenda-no-PCP]] — o encaixe completo, decisões e pendências.
- [[Fluxo-Operacional-Visao-Geral]]
- [[Fluxo-Detalhado-Pedido-Item]]
- [[PCP-Carteira]]
- [[Rota-Estoque]]
- [[Rota-Revenda]]
- [[Rota-Fabricacao]]
- [[Estoque-Regras-Negocio]]
