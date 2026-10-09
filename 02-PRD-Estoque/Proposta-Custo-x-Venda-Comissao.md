---
tags: [erp-acos-vital, prd-estoque, estoque, mes, comissao, custo, proposta]
criado: 2026-10-09
status: proposta
atualizado: 2026-10-09
---

# Proposta — Custo × venda por item e comissão automática

> Status: proposta, **sem prazo** | no código: nada (exceto a G1, que passa a aceitar custo opcional) | em produção: não.
>
> **Prioridade: futuro.** Robert (09/10/2026): o foco agora é PCP e Estoque; comissões ficam para bem mais tarde, e o Registro ([[Registro-de-Decisoes-2026-10-07]], item 90) mantém comissões fora de escopo. Esta nota guarda a ideia. **Única coisa que entra agora:** o lote aceita um **custo unitário opcional** na carga inicial (G1); vazio não bloqueia nada. Autor da proposta: Robert Wilson, para o Nathan. O PDF original é `PCP/Claude outputs/Proposta-Custo-x-Venda-Comissao.pdf`.

## Objetivo

Amarrar o que foi comprado (lote, custo) ao que foi vendido (item do pedido, NF) para ter "quanto custou × quanto vendeu" por item. Com a amarração completa, o av-hub calcularia a comissão sozinho a cada faturamento, sem a correção manual de Compras no simulador.

## Como funciona hoje

- **Etapa 1, vendedor:** preenche o [[AV-Hub-Simulador-Comissao|simulador]] com os custos que orçou e o valor de venda do pedido inteiro; sai margem → letra → % de comissão.
- **Etapa 2, Compras:** corrige o simulador com o valor real pago.
- **Pagamento:** conforme o faturamento, muitas vezes por parciais do Omie (30 produtos vendidos, 10 faturados no mês: paga sobre os 10).
- **Fabricação:** 2% fixos, a comissão máxima.
- O estoque do MES começa no **marco zero**: a carga inicial (G1) é o primeiro estoque; depois todo lote nasce de uma compra.

## O que já existe e o que falta (conferido em 09/10, `api-pcp` `e8f951e`)

| Elo | Situação | Onde |
|---|---|---|
| Preço de venda por item | Existe | av-hub (pedido Omie / NF), ligado ao MES por filial + pedido + item |
| Item do pedido → parcial | Existe | `ItensPedido` → `ItemParcial` |
| Parcial → requisição de compra | Existe | `RequisicaoCompra` |
| Requisição → OC (preço, fornecedor, PTAX) | **Só a ida** | contrato 34 envia a requisição; a volta, [[004-Referencia-OC-Integracao-MES]], não tem consumidor no MES e **não traz valor unitário, moeda, PTAX nem impostos** |
| OC → lote recebido | Existe, **sem custo** | `Lote` guarda requisição, NF e fornecedor |
| Revenda: lote → item entregue | Existe | `Reserva` (lote × parcial × quantidade) |
| Fabricação: lote de MP → item fabricado | **Não existe** | consumo de MP (J2/J3) e genealogia (J4) |

Na revenda falta só o custo no lote. Na fabricação falta registrar o consumo de matéria-prima.

## Exemplo: 20 flanges atendidas por 3 lotes

| Lote | Qtd | Custo unit. | Custo |
|---|---|---|---|
| L1 | 10 | R$ 10,00 | R$ 100,00 |
| L2 | 5 | R$ 12,00 | R$ 60,00 |
| L3 | 5 | R$ 15,00 | R$ 75,00 |
| **Item do pedido** | 20 | **R$ 11,75 (médio)** | **R$ 235,00** |

O almoxarife informa de quais lotes sai a quantidade, ou o sistema sugere por FIFO com troca manual. O MES já grava uma linha por lote ligada à parcial.

> Correção de referência: o PDF atribui o FIFO a "DEC-12". No vault, a DEC-12 é a **genealogia de material**; o consumo FIFO por OS-OP é a tarefa **J3** ([[Cronograma-2-Meses]]).

## Faturamento parcial: qual custo usar

A NF do Omie não diz de qual lote saiu cada peça. Se 10 das 20 flanges forem faturadas:

| Regra | Custo dos 10 | Efeito |
|---|---|---|
| **A. Custo médio do item no pedido (recomendada)** | 10 × 11,75 = R$ 117,50 | margem igual em todas as parcelas; simples e estável |
| B. FIFO dentro do pedido | 10 × 10,00 = R$ 100,00 | margem alta no começo e menor depois |
| C. Exato por lote | depende da parcial que foi na NF | exige dividir a parcial por lote e ligar cada parcial à NF |

## Evolução da comissão

1. **Etapa 1, sem mudança:** vendedor preenche o simulador.
2. **Etapa 2, semiautomática:** o simulador já vem com o custo real dos lotes; Compras só confere.
3. **Etapa 3, automática:** com custo real em todos os itens do pedido, a cada faturamento o av-hub calcula margem → letra → % sobre o faturado (itens da NF × custo médio). Sem custo completo, segue a etapa 2.

**Escopo inicial:** revenda. A fabricação segue com 2% fixos até existirem consumo de MP e genealogia (J2 a J4). O cálculo moraria em `core_comissionamento` ([[AV-Hub-Comissao-Modulo]]).

## O que muda nas tarefas

| Onde | Mudança | Responsável | Quando |
|---|---|---|---|
| MES, G1 (carga inicial) | `Lote` ganha `custo_unitario` opcional; a planilha de carga ganha a coluna de custo | Robert | **agora** (opcional) |
| Contrato 004 | devolver valor unitário, moeda/PTAX e impostos de cada item da OC; job de leitura no MES | Gustavo (rota) / Robert (job) | futuro; o job do MES já está pendente |
| MES, genealogia (J4) | expor por item entregue: lotes, quantidade e custo | Gustavo / Robert | futuro |
| av-hub, comissão | pré-preencher custo real (etapa 2); cálculo por faturamento (etapa 3) | a definir | futuro |

Atenção: o Robert já estoura a capacidade da S5 ([[Cronograma-2-Meses]]); o job do 004 e o J4 com custo somam carga a ele.

## Decisões pedidas ao Nathan (sem urgência) 🔴

1. Regra do custo no faturamento parcial: A, B ou C (recomendado A).
2. Custo da carga inicial: custo médio do Omie, última compra ou outro.
3. Composição do custo: mesma regra do simulador (compra − ICMS a recuperar + IPI + ST)? Frete entra?
4. Moeda estrangeira: PTAX da OC ou da data de recebimento. A PTAX da OC é a cotação de **venda** (decisão 46), mas a API aceita outra cotação e apenas marca a origem como `manual` e zera `cotacao_data`; uma OC manual teria custo sem data de PTAX rastreável.
5. Sobra de compra mínima: o custo segue o próprio lote quando usada em outro pedido (proposta: sim).
6. Etapa 2: Compras passa a só conferir?
7. Escopo inicial só revenda, mantendo os 2% da fabricação?

## Limites conhecidos

- Sem consumo de MP não há custo do item fabricado; uma chapa vira peças de vários pedidos, então o custo exige **rateio por peso ou área consumida**.
- Perdas e sobras de corte (EC-02, L-10) estão no Ciclo 2; até lá o custo de fabricação sai subestimado.
- Custo de transformação (hora de máquina, mão de obra) não existe no MES. Não é necessário se a comissão considerar só material e impostos, como o simulador faz hoje.

## Ver também
[[AV-Hub-Simulador-Comissao]] · [[AV-Hub-Comissao-Modulo]] · [[Estoque-Modelo-Dados]] · [[Estoque-Roadmap]] · [[Estoque-Perguntas-Abertas]] · [[004-Referencia-OC-Integracao-MES]] · [[Registro-de-Decisoes-2026-10-07]]
