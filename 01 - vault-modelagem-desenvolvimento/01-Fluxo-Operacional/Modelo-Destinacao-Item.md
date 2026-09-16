---
tags: [erp-acos-vital, fluxo-operacional, modelagem, pcp]
criado: 2026-09-16
---

# Modelo de Destinação do Item — Reconciliando Estoque × Revenda × Fabricação

> Formaliza a relação entre o diagrama macro ([[Fluxo-Operacional-Visao-Geral]]) e o fluxo detalhado item a item ([[Fluxo-Detalhado-Pedido-Item]]), que coexistiam por decisão consciente, mas nunca tinham sido modelados juntos de fato.

## O problema

O diagrama macro trata `[ESTOQUE]`, `[REVENDA]`, `[FABRICAÇÃO]` como três ramos paralelos e mutuamente exclusivos — como se todo item do pedido caísse em exatamente um dos três, de uma vez. Mas o fluxo detalhado mostra que "estoque" não é uma categoria do mesmo tipo que Revenda/Fabricação — é a resposta a uma **pergunta diferente**, feita sobre qualquer item de Revenda ou Fabricação.

## Três eixos independentes, não uma escolha única

**Eixo 1 — Natureza/origem do item.** De onde vem o valor do item:
- **Revenda** — comprado de terceiro, revendido (com ou sem beneficiamento, ex.: corte de chapa — ver [[Fabricacao-Chapas]]).
- **Fabricação** — produzido internamente numa linha própria (Flange hoje; Grade de Piso, Chapa Expandida, Caldeiraria etc. conforme cadastradas — ver [[Rota-Fabricacao]]).

Praticamente fixo por tipo de material/produto — não muda pedido a pedido.

**Eixo 2 — Disponibilidade física no momento em que o PCP avalia.** O que existe fisicamente agora:
- **Pronto em estoque** — já existe como produto acabado.
- **Matéria-prima em estoque** — existe, mas precisa de beneficiamento/produção antes de liberar.
- **Sem estoque** — não existe fisicamente, precisa ser originado (compra, pra Revenda; início de produção, pra Fabricação).

Dinâmico — muda a cada verificação, depende do saldo no momento (e da reserva, ver eixo 3).

**Eixo 3 — Destinação da reserva**, já modelada no PRD como `destinacao_item_pedido` (ver [[Estoque-Regras-Negocio]]). Pra que serve o saldo, uma vez que existe em estoque:
- **Específica pra este pedido** (reservado).
- **Específica pra produção** (reservado pra uma OS/OP em andamento).
- **Estoque geral** (não reservado, disponível pra qualquer demanda futura).

## A matriz resultante (eixo 1 × eixo 2)

| | Pronto em estoque | Matéria-prima em estoque | Sem estoque |
|---|---|---|---|
| **Revenda** | Direto pra conferência → Qualidade → Expedição — é exatamente o que [[Rota-Estoque]] descreve ("pronta entrega") | PCP abre **OS** de beneficiamento antes de Qualidade (ex.: corte de chapa) | PCP gera requisição de compra — fluxo clássico de [[Rota-Revenda]] |
| **Fabricação** | Raro, mas possível — item de linha própria já concluído em estoque → Qualidade → Expedição | PCP inicia produção (**OP**) direto, sem esperar compra de MP | PCP gera requisição de compra de MP específica pra aquela linha, depois OP |

## O que isso resolve

- **`[ESTOQUE]` no diagrama macro não é um quarto ramo** — é o cruzamento "Pronto em estoque" das duas colunas de Revenda e Fabricação. [[Rota-Estoque]] (separação, conferência, liberação imediata) descreve exatamente essa célula da matriz, não uma origem própria de item.
- **`destinacao_item_pedido` (eixo 3) é ortogonal aos outros dois** — um item pode estar "pronto em estoque" (eixo 2) e já reservado pra produção específica (eixo 3) ao mesmo tempo, sem contradição.
- **Reserva de estoque** (já decidida como necessária, ver [[Fluxo-Detalhado-Pedido-Item]]) é o mecanismo que liga o eixo 2 ao eixo 3 no exato momento em que o PCP marca "tenho em estoque" — é aí que a célula da matriz vira uma reserva de verdade, não só uma leitura de saldo.

## Como isso deveria mudar a implementação

- `destinacao_item_pedido` (eixo 3) continua como está no PRD, mas precisa de um campo/consulta **separado** pra representar o eixo 2 (disponibilidade no momento da checagem) — hoje os dois estão implicitamente misturados na descrição do PRD original.
- O diagrama macro em [[Fluxo-Operacional-Visao-Geral]] pode continuar existindo como visão simplificada (ex.: pra relatório gerencial, visão de alto nível pro vendedor) — mas qualquer tela operacional (PCP, Compras, Recebimento) deveria ser desenhada em cima do modelo de 2 eixos (natureza × disponibilidade) descrito aqui, não do modelo de 3 ramos paralelos.
- O eixo 1 (Revenda/Fabricação) é decidido **uma vez**, por tipo de material/produto — não precisa ser reavaliado a cada pedido. O eixo 2 é reavaliado a cada verificação de saldo pelo PCP.

## Ver também
- [[Fluxo-Operacional-Visao-Geral]]
- [[Fluxo-Detalhado-Pedido-Item]]
- [[PCP-Carteira]]
- [[Rota-Estoque]]
- [[Rota-Revenda]]
- [[Rota-Fabricacao]]
- [[Estoque-Regras-Negocio]]
