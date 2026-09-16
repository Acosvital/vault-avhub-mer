---
tags: [visao-setores, novo-sistema-estoque]
criado: 2026-09-16
---

# Regras de Negócio do Novo Sistema de Estoque

Estas são as regras que vão orientar como o sistema funciona no dia a dia. Elas existem pra proteger a empresa de erro operacional, fraude e retrabalho.

## Quem faz o quê não pode ser a mesma pessoa

Regra clássica de controle interno, que qualquer empresa séria de distribuição segue: **quem cria o pedido de compra não pode ser a mesma pessoa que aprova o pedido, nem a mesma que recebe o material na doca**. Isso evita que uma única pessoa consiga, sozinha, criar uma compra fictícia e "confirmar" o recebimento dela mesma.

Os papéis previstos são:

| Papel | O que faz |
|---|---|
| **Comprador** | Monta e negocia o pedido de compra |
| **Aprovador** | Aprova pedidos (obrigatório acima de um valor a definir) |
| **Almoxarife** | Recebe e confere o material fisicamente |
| **Qualidade** | Inspeciona e aprova/reprova o material |
| **Gestor de Estoque** | Supervisiona a operação do depósito |

Cada pessoa só vai enxergar e conseguir usar as telas que fazem sentido pro seu papel.

## Material não pode ser usado antes da Qualidade aprovar

Todo material que chega — seja de compra ou de produção — nasce **bloqueado para uso**, numa espécie de "quarentena". Ele só fica disponível pra Produção usar ou pra Vendas oferecer depois que a Qualidade aprova formalmente. Isso vale mesmo pra item que parece "acabado" e passou tranquilo pela conferência de quantidade.

Além disso, a Qualidade **não consegue aprovar um material sem anexar o laudo/certificado correspondente**. Sem laudo, o material fica travado em análise — não existe atalho pra pular essa etapa.

## Peso teórico e tolerância

Todo material tem um peso de referência (peso teórico) e uma tolerância aceitável de variação — hoje o valor provisório usado é 5%, mas isso ainda precisa ser confirmado por categoria de material (ver [[Perguntas-em-Aberto]]). Na pesagem de entrada, o sistema confere o peso pesado contra o peso teórico esperado.

## Quando a Qualidade reprova um material

Quando um material é parcialmente reprovado, o sistema separa (o termo do dia a dia é "cindir") o material aprovado do reprovado: a parte aprovada segue seu caminho normal, e a parte reprovada fica congelada, aguardando devolução ao fornecedor. Essa reprovação nunca gera a nota fiscal de devolução diretamente — o sistema apenas sinaliza que uma devolução é necessária, e a nota é emitida no Omie como sempre. Só depois que essa nota volta é que o caso é encerrado no sistema de Estoque.

## A parte fiscal nunca é responsabilidade deste sistema

Informações fiscais como o tipo de operação da nota e o cálculo de imposto continuam vindo só da nota emitida pelo fornecedor e sincronizada do Omie. O novo sistema nunca cria, edita ou emite nota fiscal — ele só referencia e sinaliza quando algo fiscal precisa acontecer.

## O fornecedor não tem acesso ao sistema

Não existe hoje um jeito de saber, de forma confiável, que o material "está a caminho" — sem confirmação do próprio fornecedor, a data de entrega prevista é sempre uma informação registrada manualmente por quem está acompanhando a compra.

## A destinação é decidida por item, não pelo pedido inteiro

Ao montar ou revisar um pedido de compra, o Comprador decide, item por item, se aquele material vai para uma produção específica, para uma venda específica ou para o estoque geral. Um mesmo pedido pode ter itens com destinos diferentes. Assim que o lote é aprovado pela Qualidade, essa destinação vira automaticamente uma reserva daquele material.

## Catálogo de materiais precisa estar limpo antes de usar

Hoje existem materiais duplicados no catálogo do sistema financeiro (por exemplo, o mesmo produto cadastrado duas vezes porque alguém não encontrou o item já existente numa busca). Antes de começar a usar o novo sistema de Estoque, esse catálogo precisa passar por uma limpeza — sem mexer diretamente no catálogo original, mas criando um vínculo entre os itens duplicados e um item único de referência.

## Múltiplos depósitos, sem estoque de terceiros

A empresa confirma que vai operar com mais de um depósito (warehouse), com transferência de material entre eles sendo uma operação normal do dia a dia. Também foi confirmado que **não existe estoque consignado** — nem material da empresa guardado num cliente, nem material de um fornecedor guardado na empresa.

## Matéria-prima importada

O sistema já prevê que matéria-prima pode ser comprada em moeda estrangeira.

## Ver também
- [[Visao-Geral]]
- [[Como-vai-Funcionar-no-Dia-a-Dia]]
- [[Riscos-e-Cuidados]]
- [[Perguntas-em-Aberto]]
- [[Qualidade-e-Conferencia]]
- [[Quem-Faz-o-Que]]
- [[Glossario]]
