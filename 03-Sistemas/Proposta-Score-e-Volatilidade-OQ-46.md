---
tags: [decisoes, orcamento, score, fornecedor, volatilidade, oq-46, staging]
criado: 2026-10-19
atualizado: 2026-10-19
status: proposta
dono: Nathan
fontes: [proposta do Nathan de 19/10/2026 (dados de exemplo), Perguntas-Proposta-Pedido-Comissao OQ-46, Registro-de-Decisoes N16-52, api-comercial suprimentos.prisma (model Oferta), Dump Avhub (Esqueleto) ordens_compra]
---

# Score, top fornecedores, volatilidade e "dado recente" (OQ-46, N16-55)

Responde às perguntas da página do produto do vendedor ([[Registro-de-Decisoes]] N16-52). **É decisão do Nathan de 19/10/2026 (N16-55).** Os valores que estão no SQL (pesos, limite de volatilidade, dias) eram exemplo; a regra vale e a proposta pode melhorar depois. A seção 2 traz ajustes que o Nathan **adotou** (N16-56): custo líquido, prazo em dias, data real de recebimento, mínimo de pontos e pesos com vigência. Os demais pontos continuam como sugestão. Abaixo, as quatro regras como o Nathan mandou, e depois o que conferi no código e no banco.

## 1. As regras propostas

**Score do fornecedor.** Média ponderada de preço, prazo e confiabilidade:

`score = (Nota Preço × 0,5) + (Nota Prazo × 0,3) + (Nota Histórico × 0,2)`

- **Nota Preço** = (menor preço recebido ÷ preço do fornecedor) × 100. O mais barato ganha 100.
- **Nota Prazo** = (menor prazo em dias ÷ prazo do fornecedor) × 100.
- **Nota Histórico** = percentual de entregas no prazo, ou taxa de aprovação das cotações passadas do fornecedor.

**Top fornecedores.** Ranking que junta o score com a **frequência de vitória**, por categoria de material (chapas, tubos), com `RANK()` ou `DENSE_RANK() OVER (ORDER BY score_total DESC)`.

**Volatilidade de preço.** Coeficiente de variação: desvio padrão dos preços dos últimos 30 a 90 dias ÷ preço médio do mesmo período. Se CV passar de 15% ou 20%, o painel mostra "Alta Volatilidade".

**Dado recente.** A última cotação válida: `ROW_NUMBER() OVER (PARTITION BY produto_id ORDER BY data_cotacao DESC)`, fica só a linha 1, e só se a `data_cotacao` tiver menos de X dias (7 ou 15).

## 2. O que conferi no código e no banco 🟡

| Ponto | O que existe hoje | O que a regra precisa |
|---|---|---|
| Oferta (preço de um fornecedor) | A `Oferta` do `api-comercial` já tem `preco`, `dataCotacao`, `validaAte`, `status` (vigente, vencida, histórica), `fonte` (inclusive a OC do Omie), `quantidade` e `custoLiquidoUnit` (`suprimentos.prisma:138-183`) | A "última cotação válida" já tem o campo `valida_ate`. Dá para usar a validade da própria oferta em vez de só contar X dias |
| **Nota Preço** | O `custoLiquidoUnit` (já com imposto e frete) existe na oferta | **Comparar pelo custo líquido, não pelo preço bruto.** Senão uma oferta CIF e outra FOB, ou com IPI e ST diferentes, ficam desiguais. Também é preciso a **mesma unidade** (preço por KG) e a **mesma moeda** (PTAX) |
| **Nota Prazo** | `prazo` na `Oferta` é **texto livre** (`String?`) | Precisa de **prazo de entrega em dias, como número**. Sem isso a nota não calcula. E dizer se é prazo de **entrega** (o que a regra quer) ou de pagamento |
| **Nota Histórico** | A OC do hub tem `data_previsao_chegada` (prevista). Não achei score nem avaliação de fornecedor no modelo | Precisa da **data real do recebimento** para medir "entrega no prazo" (conferir com o contrato do Recebimento). E de um **mínimo de compras**: fornecedor com uma compra só não tem histórico confiável |
| **Frequência de vitória** | Não existe | Precisa de definição: ganhou quando teve o **menor custo líquido** numa cotação ou numa OC? Em cotações ou em compras? |
| **Categoria** | O SQL-017 tem `categoria_suprimento` | O ranking por categoria já tem onde se apoiar |
| **Volatilidade** | O histórico de ofertas e de OC existe | Precisa de um **mínimo de pontos** no período (por exemplo, 3) e a mesma unidade e moeda. Com poucos pontos o CV engana |
| **Dado recente** | A OC efetivada entra como oferta (`fonte` pedido do Omie) | Casa com a N16-41 (vale o mais atualizado) e com a N16-52 (sem dado recente, mostra a média e o botão de pedir cotação) |

## 3. Pontos fechados em 20/10/2026 (N16-72)

- **Dado recente: 7 dias**, como parâmetro por categoria.
- **Frequência de vitória:** Compras efetivamente comprou do fornecedor (aparece numa OC).
- **Falta de prazo ou histórico:** nota neutra e aviso "poucos dados".

## 4. Pontos para ajustar depois, se for o caso

1. **Pesos 50, 30 e 20** e o **limite de volatilidade (15% ou 20%)**: ficam como **parâmetro configurável**, com vigência, e não fixos no código.
2. **X dias de "dado recente"**: 7 ou 15? Pode variar por categoria (chapa oscila mais que flange).
3. **Prazo em dias** passa a ser campo numérico na oferta e na OC? Quem preenche?
4. **Frequência de vitória**: qual é a definição?
5. **Quando faltar um dado** (fornecedor sem prazo ou sem histórico): usar nota neutra e avisar "poucos dados", ou redistribuir o peso das outras notas?
6. **Janela do histórico** do fornecedor (últimos 12 meses?) e o mínimo de compras para ele ter nota.

Ligadas: [[Perguntas-Proposta-Pedido-Comissao]] OQ-46, OQ-34 (unidades) e OQ-35 (base de preço).
