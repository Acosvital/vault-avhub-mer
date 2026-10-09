---
tags: [erp-acos-vital, prd-estoque, estoque, mes, comissao, custo, compras, orcamento]
criado: 2026-10-09
atualizado: 2026-10-09
status: decidido
---

# Estoque — Custo do lote, custo × venda por item e comissão por faturamento

> Status: decidido (09/10/2026) | no código: **nada ainda** | em produção: não. Origem: nota e PDF do Robert Wilson de 09/10 (`PCP/Claude outputs/Proposta-Custo-x-Venda-Comissao.pdf`), incorporados ao vault por determinação de 09/10. **Isto deixou de ser proposta:** o custo do lote faz parte do modelo do Estoque e tem contratos para implementação (ver "Contratos" abaixo). O que continua **fora de escopo agora** é só a comissão automática no av-hub (Ciclo 2), coerente com o item 90 de [[Registro-de-Decisoes-2026-10-07]].

## Para que serve

1. **Custo × venda por item:** amarrar o que foi comprado (lote, custo) ao que foi vendido (item do pedido, NF).
2. **Comissão** (futuro): o av-hub calcula margem → letra → % a cada faturamento, sem a correção manual de Compras no [[AV-Hub-Simulador-Comissao|simulador]].
3. **Compras e Orçamento** (futuro, mesmo dado): o valor unitário, a moeda, a cotação, o desconto e o frete da OC e o **custo real do lote** ficam guardados no MES e no hub para comparar "orçado × comprado × custo real", alimentar o histórico de preços (`vw_historico_precos`, hoje só cotações do Omie) e o módulo de Orçamento do Comercial & Suprimentos. Por isso o contrato 004 passa a devolver os valores (ver [[007-Referencia-OC-Valores-no-MES]]) e o custo é gravado com **todos os componentes**, não só o total.

## Como funciona hoje (antes deste desenho)

- **Etapa 1, vendedor:** preenche o simulador com os custos que orçou e o valor de venda do pedido inteiro; sai margem → letra → % de comissão.
- **Etapa 2, Compras:** corrige o simulador com o valor real pago.
- **Pagamento:** conforme o faturamento, muitas vezes por parciais do Omie (30 vendidos, 10 faturados no mês: paga sobre os 10).
- **Fabricação:** 2% fixos, a comissão máxima.

O estoque do MES começa no **marco zero**: a carga inicial (G1) é o primeiro estoque; depois todo lote nasce de uma compra.

## O que já existe e o que falta (conferido em 09/10: `api-pcp` `e8f951e`, `api-acos-vital` `dee35b0`, `av-hub` `111f605`)

| Elo | Situação | Onde |
|---|---|---|
| Preço de venda por item | Existe | av-hub (pedido Omie / NF), ligado ao MES por filial + pedido + item |
| Item do pedido → parcial | Existe | `ItensPedido` → `ItemParcial` |
| Parcial → requisição de compra | Existe | `RequisicaoCompra` (contrato 34) |
| Valor da OC (unitário, desconto, moeda, cotação, frete) | **Existe no hub, não sai** | `ordens_compra_itens.valor_unitario`, `desconto`, `valor_desconto`, `valor_total_item`; `ordens_compra.moeda`, `cotacao_moeda`, `cotacao_data`, `cotacao_origem`, `valor_frete`, `valor_seguro`, `valor_total_brl`. A rota do contrato 004 hoje **omite o preço de propósito** (comentário em `vw_ordens_compra_referencia_mes.route.js`) |
| Imposto por item (ICMS a recuperar, IPI, ST) | **Não existe na OC** | o simulador usa esses valores, mas a OC não os guarda por item (🟡 origem a definir: cadastro do produto, NF de entrada ou digitação em Compras) |
| OC → lote recebido | Existe, **sem custo** | `Lote` guarda requisição, NF e fornecedor, não o custo |
| Revenda: lote → item entregue | Existe | `Reserva` (lote × `ItemParcial` × quantidade) |
| Fabricação: lote de MP → item fabricado | **Não existe** | consumo de MP (J2/J3) e genealogia (J4) |

Na revenda falta só o custo no lote. Na fabricação falta registrar o consumo de matéria-prima.

## Modelo (decidido)

### Custo do lote — `lote_custo` (1:1 com `lote`)

O custo mora numa tabela própria, para não engordar `lote` e para guardar os componentes. Contrato: [[008-Custo-do-Lote-no-MES]].

| Campo | Significado |
|---|---|
| `custo_liquido_unitario` (BRL) | o que a comissão usa: `valor_unitario × (1 − desconto) × cotação − ICMS a recuperar + IPI + ST`, por unidade do lote |
| `origem` | `CARGA_INICIAL`, `OC` ou `MANUAL` |
| `valor_unitario`, `moeda`, `cotacao`, `desconto_pct` | componentes copiados da OC (ou da planilha da G1) |
| `icms_recuperar_unit`, `ipi_unit`, `st_unit` | opcionais; vazios contam como 0 |
| `frete_unit` | **gravado, mas fora do custo líquido** (decisão 3) |
| `id_item_oc` | liga ao item da OC de origem (rastreabilidade para Compras/Orçamento) |

Regras: o custo é **opcional** (vazio nunca bloqueia G1, recebimento, reserva nem despacho); o lote filho de cisão herda o custo do pai; transferência entre depósitos não muda o custo; **a sobra de compra mínima mantém o custo do próprio lote** quando usada em outro pedido.

### Custo do item do pedido

Soma de `quantidade × custo_liquido_unitario` dos lotes ligados às `Reserva` do item, dividida pela quantidade. Exemplo (20 flanges, 3 lotes):

| Lote | Qtd | Custo unit. | Custo |
|---|---|---|---|
| L1 | 10 | R$ 10,00 | R$ 100,00 |
| L2 | 5 | R$ 12,00 | R$ 60,00 |
| L3 | 5 | R$ 15,00 | R$ 75,00 |
| **Item do pedido** | 20 | **R$ 11,75 (médio)** | **R$ 235,00** |

O MES expõe isso em `GET /itens/custo` (contrato 008), com `completo = true` só quando **toda** a quantidade do item tem custo. O almoxarife informa de quais lotes sai a quantidade ou o sistema sugere por FIFO com troca manual.

> Correção de referência: o PDF original atribui o FIFO à "DEC-12". No vault, a DEC-12 é a **genealogia de material**; o consumo FIFO por OS-OP é a tarefa **J3** ([[Cronograma-2-Meses]]).

### Faturamento parcial — regra A (decidida)

A NF do Omie não diz de qual lote saiu cada peça. Vale o **custo médio do item no pedido**: se 10 das 20 flanges são faturadas, o custo é 10 × R$ 11,75 = R$ 117,50. Margem igual em todas as parcelas, sem distorção entre meses. Descartadas: B (FIFO dentro do pedido: margem alta no começo, menor depois) e C (exato por lote: exige dividir a parcial por lote e ligar cada parcial à NF).

## Decisões adotadas em 09/10/2026

| # | Pergunta | Decisão |
|---|---|---|
| 1 | Custo no faturamento parcial | **Regra A**, custo médio do item no pedido |
| 2 | Custo da carga inicial (marco zero) | O que vier na **coluna opcional da planilha da G1**; sem valor, o lote fica sem custo (`origem = CARGA_INICIAL`). A fonte do número (custo médio do Omie, última compra) é de quem preenche a planilha: Compras |
| 3 | Composição do custo | Mesma regra do simulador (compra − ICMS a recuperar + IPI + ST), **com os componentes gravados**; **frete gravado, fora do custo líquido** |
| 4 | Moeda estrangeira | **PTAX da OC** (cotação de venda, decisão 46: a cotação já vem com `cotacao_data` e `cotacao_origem`). OC com cotação `manual` entra com o custo, marcado para conferência de Compras |
| 5 | Sobra de compra mínima | O custo **segue o lote** |
| 6 | Etapa 2 da comissão | Compras **só confere** o custo pré-preenchido |
| 7 | Escopo inicial | **Só revenda**; fabricação segue em 2% fixos até existirem consumo de MP e genealogia (J2 a J4) |

Quem quiser mudar uma delas muda o contrato 008 e o item 94 do Registro; nada aqui trava o código antes da etapa 2.

## Evolução da comissão (av-hub)

1. **Etapa 1, sem mudança:** o vendedor continua preenchendo o simulador com custo orçado e valor de venda.
2. **Etapa 2, semiautomática (Ciclo 2):** o simulador já vem com o custo real dos lotes usados em cada item (`GET /itens/custo`); Compras só confere e confirma.
3. **Etapa 3, automática (Ciclo 2):** com custo completo em todos os itens do pedido, a cada faturamento o av-hub calcula margem → letra → % sobre o faturado (itens da NF × custo médio). Sem custo completo, segue a etapa 2.

Contrato do lado do hub: [[47-Custo-Real-por-Item-no-Hub]]. O cálculo moraria em `core_comissionamento` ([[AV-Hub-Comissao-Modulo]]). Nada de comissões é alterado agora (item 90 do Registro).

## Contratos

| Contrato | O que entrega | Dono | Quando |
|---|---|---|---|
| [[012-Ordens-Compra-Referencia-Valores]] (SQL) | a view `vw_ordens_compra_referencia_mes` ganha os valores; a marca `alterado_em` passa a reagir a preço | Gustavo | antes do job do MES |
| [[007-Referencia-OC-Valores-no-MES]] (API) | a rota 004 devolve os valores; o job do MES os grava na projeção da OC | Gustavo (rota), Robert (job) | Ciclo 1 (Onda 0) |
| [[008-Custo-do-Lote-no-MES]] (API/MES) | `lote_custo`, coluna de custo na G1, custo na entrada do recebimento, custo no consumo, `GET /itens/custo` | Robert | G1 já; resto Ciclo 1/2 |
| [[47-Custo-Real-por-Item-no-Hub]] (lógica) | consumo no av-hub: simulador etapa 2, comissão etapa 3, Compras e Orçamento | Comercial & Suprimentos | Ciclo 2 |

## Limites conhecidos

- Fabricação: sem consumo de MP não há custo do item fabricado. Uma chapa vira peças de vários pedidos; o custo exigirá **rateio por peso ou área consumida**.
- Perdas e sobras de corte (EC-02, L-10) estão no Ciclo 2; até lá o custo de fabricação sai subestimado.
- Custo de transformação (hora de máquina, mão de obra) não existe no MES. Não é necessário se a comissão considerar só material e impostos, como o simulador faz hoje.
- O imposto por item não existe na OC hoje (tabela acima): até Compras/NF de entrada o fornecerem, `icms_recuperar_unit`, `ipi_unit` e `st_unit` ficam vazios e o custo líquido sai sem eles.

## Ver também
[[Estoque-Modelo-Dados]] · [[Estoque-Regras-Negocio]] · [[Estoque-Roadmap]] · [[Estoque-Perguntas-Abertas]] · [[004-Referencia-OC-Integracao-MES]] · [[AV-Hub-Simulador-Comissao]] · [[AV-Hub-Comissao-Modulo]] · [[Registro-de-Decisoes-2026-10-07]] · [[Cronograma-2-Meses]]
