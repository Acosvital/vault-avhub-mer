---
tags: [visao-setores, sistemas-existentes]
criado: 2026-09-16
---

# Como Vendas e Faturamento Funcionam

Quando alguém pergunta "quanto vendemos esse mês", a resposta não é simplesmente somar todos os pedidos. Uma parte desses pedidos foi cancelada, devolvida, negada pelo cliente, ou não deveria contar por alguma outra regra do negócio. O av-hub calcula isso automaticamente, numa espécie de "escadinha" que vai descontando cada motivo até chegar no número real — a **venda líquida**.

## A ideia da escadinha (venda bruta → venda líquida)

Partindo do total bruto vendido, o sistema desconta, nesta ordem:

1. **Cancelado** — pedidos cancelados não contam como venda.
2. **Devolvido** — pedidos devolvidos totalmente pelo cliente.
2b. **Devolvido parcialmente** — quando só parte do pedido voltou. Hoje o sistema só sabe dizer *que* houve uma devolução parcial (sim/não), mas não sabe *quanto* foi devolvido em valor — essa informação ainda não é capturada em nenhum lugar. Isso é uma limitação conhecida, relevante inclusive para o desenho do novo sistema de estoque.
3. **Negado/recusado pelo destinatário** — quando o cliente formalmente recusa o recebimento da mercadoria.
4. **Bloqueio por destinatário (cliente na lista de bloqueio)** — clientes que, por algum motivo comercial, entram numa lista de exclusão e têm suas vendas descontadas do total.
5. **Bloqueio por vendedor** — regra parecida, mas aplicada a determinados vendedores.
6. **Refaturamento** — quando uma venda é refaturada (emitida de novo), ela pode ou não contar, dependendo da situação de refaturamento daquele pedido.

O que sobra depois de todos esses descontos é a **venda líquida** — o número real que entra nos painéis, comissões e metas.

Existe uma regra especial: alguns pedidos são marcados manualmente para contar como líquido mesmo assim, independente da escadinha (usado em casos excepcionais).

## Vendas x Faturamento — duas réguas parecidas, não idênticas

O sistema aplica essa mesma lógica de duas formas ligeiramente diferentes: uma olhando para os **pedidos de venda** e outra olhando para as **notas fiscais emitidas**. As duas seguem a mesma ideia geral (cancelado → devolvido → recusado → bloqueios → refaturamento → líquido), mas há uma diferença importante: a regra de refaturamento é mais rígida do lado de faturamento (só desconta quando o refaturamento está marcado como "não permitido") do que do lado de vendas (desconta sempre que há refaturamento, desde 14/09/2026). Essa diferença é proposital, mas pode gerar números que não batem exatamente entre os dois lados — e isso é esperado, não é erro.

## Sobre as listas de bloqueio

Existem duas famílias de "lista de bloqueio" no sistema, e é importante não confundir uma com a outra:

- As listas usadas na escadinha de venda líquida (bloqueio de cliente e de vendedor) afetam o cálculo de quanto a empresa vendeu.
- Existe uma segunda família de listas de bloqueio, usada exclusivamente para **comissão** (ver [[Comissoes]]) — essas não têm nenhuma relação com o cálculo de venda líquida, apesar do nome parecido.

## De onde vêm os números

Os dados brutos de pedidos e notas fiscais vêm do Omie, atualizados automaticamente (ver [[Integracao-com-o-Omie]]). Uma parte da informação — a confirmação de que o destinatário recebeu (manifestou-se sobre) a nota fiscal — não vem de uma integração direta com o Omie, mas sim de uma automação que consulta um relatório específico dentro do próprio sistema do Omie. Por isso, o número da nota fiscal associado a um pedido deve ser tratado como uma referência de apoio, não como um vínculo 100% garantido.

## Ajustes e correções já feitos

Ao longo do desenvolvimento, alguns problemas de cálculo foram identificados e corrigidos — por exemplo, notas fiscais que ficavam "órfãs" (sem vínculo correto) e uma meta individual que aparecia de 7 a 18 vezes maior do que deveria por causa de uma divisão duplicada. Esses pontos já foram resolvidos. Ver [[Situacao-Atual]] para o resumo do que está estável hoje e o que ainda tem pendência.

## Ver também
- [[av-hub]]
- [[Comissoes]]
- [[Portal-do-Vendedor]]
- [[Integracao-com-o-Omie]]
- [[Situacao-Atual]]
