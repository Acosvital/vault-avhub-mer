---
tags: [visao-setores, sistemas-existentes]
criado: 2026-09-16
---

# Portal do Vendedor

O Portal do Vendedor é a área de autoatendimento dentro do av-hub onde cada vendedor acompanha seus próprios pedidos, notas fiscais e desempenho, sem depender de pedir relatório para outra pessoa. Cada vendedor só vê os próprios dados — essa restrição é garantida pelo próprio sistema, nunca depende de o que a tela pede. Um vendedor pode ter mais de um vínculo (por exemplo, atuar em mais de uma filial), e o portal já lida com isso automaticamente, somando os dados de todos os vínculos da pessoa.

Também existe o papel de **auxiliar de vendedor** — uma pessoa que pode enxergar (somente para consulta, sem poder alterar) os dados de outro vendedor titular que ela auxilia.

O portal tem três telas principais: **Meu Dashboard**, **Meus Pedidos** e **Minhas Notas Fiscais**.

## Meu Dashboard

Mostra o resumo do desempenho do vendedor: vendas e faturamento do mês, com indicação visual (cor) de quanto da meta já foi atingida. Essa indicação por cor hoje só aparece no lado de vendas — no lado de faturamento os números aparecem sem essa cor de destaque (isso é intencional, não uma falha).

## Meus Pedidos

Lista os pedidos do vendedor já com a classificação de venda líquida pronta (ver a lógica completa em [[Como-Vendas-e-Faturamento-Funcionam]]), incluindo nome do cliente, categoria e tipo de contrato.

Alguns pontos importantes sobre como os pedidos aparecem:

- **Pedidos faturados em partes**: quando um pedido é faturado em mais de uma etapa, o Omie cria um registro separado para cada parte faturada, mas todas elas continuam vinculadas ao pedido original ("guarda-chuva"). O portal já sabe juntar essas partes visualmente.
- **Situação do pedido**: quando um pedido tem partes já faturadas mas ainda aparece como "não faturado" no resumo geral, o sistema busca também o detalhe de cada parte e calcula a situação real combinando tudo — evitando mostrar uma informação desatualizada.
- **Prazo (SLA)**: cada pedido não faturado tem uma contagem visual de prazo até a data prevista de faturamento — fica normal até 3 dias antes do prazo, depois fica vermelho, depois pisca, e por fim mostra "Atrasado" caso o prazo já tenha passado. Pedidos já faturados não entram nessa contagem.
- Dá para filtrar por período e por cliente.

## Minhas Notas Fiscais

Lista as notas fiscais do vendedor, já classificadas dentro da mesma escadinha de venda líquida, com número da nota, data e hora de emissão, valores e o vínculo com o pedido de origem.

## O que já está pronto e o que ainda falta

A maior parte do portal (vínculo do vendedor, resumo do topo, refaturamento, meta individual, filtros e prazo) já está implementada e em uso. Restam dois ajustes pequenos, nenhum deles travado por falta de informação no sistema: dar nomes mais claros para as etapas do processo, e finalizar a exibição da situação combinada do pedido (a decisão já foi tomada, falta só implementar na tela).

## Melhorias já avaliadas para o futuro

Já foram avaliadas, mas ainda não implementadas, funcionalidades como: aviso de prazo crítico no menu, comparação com o mês anterior, lista dos próximos vencimentos, ranking dos clientes do próprio vendedor, copiar número do pedido com um clique, exportar em Excel, marcar cliente/pedido como favorito, histórico de status do pedido, e lista dos produtos mais vendidos pelo vendedor (essa última já é viável, existe um relatório pronto por trás que pode alimentá-la).

## Ver também
- [[av-hub]]
- [[Como-Vendas-e-Faturamento-Funcionam]]
- [[Comissoes]]
- [[Situacao-Atual]]
