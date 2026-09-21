---
tags: [visao-setores, proposta, rastreabilidade]
criado: 2026-09-21
---

# Acompanhamento de cada etapa do pedido

> **Isto é uma proposta em discussão, ainda não existe no sistema.** Serve para o time e os setores dizerem se é isso mesmo que precisam.

## O que se quer poder responder

Para qualquer pedido, ou para cada item dele, em qualquer momento:

- **Onde ele está** e há quanto tempo está nessa etapa.
- **Com quem está agora**: uma pessoa, ou "na fila do setor" quando ninguém assumiu ainda.
- **Quem fez** cada etapa que já passou.
- **Quem autorizou**, quando a etapa exigia aprovação (por exemplo, uma compra de valor alto).
- **Quem passou para a frente**, e para quem.
- **Se vai dar tempo:** o prazo do pedido, o tempo que cada etapa levou e uma previsão de quando termina se nada mudar.

## Como vai funcionar, em linguagem simples

Cada vez que algo acontece com um item (chegou, foi conferido, foi aprovado, foi passado para outro setor), o sistema **anota um registro que nunca é apagado nem alterado**: quem fez, quando, de qual etapa para qual, e se alguém autorizou. Tudo o que se vê na tela (onde está, com quem está, quanto tempo levou, quantos itens tem em cada setor) é calculado a partir desses registros.

## O que cada pessoa vai ver

- **O vendedor** vê, nos próprios pedidos, em que etapa cada item está, e o prazo. Não vê o detalhe interno de quem fez cada tarefa.
- **PCP, Compras, Qualidade e gestão** veem o **mapa do fluxo por setor**: quantos itens há em cada etapa, quais estão atrasados ou em risco e quais estão parados sem dono. Ao clicar num setor, veem as etapas; ao clicar num item, veem o histórico completo.
- **O setor** vê a própria fila e pode assumir um item ou passá-lo adiante.

## O que ainda precisa ser decidido

- **A meta de tempo de cada etapa.** Hoje só existe o prazo do pedido. Quem define quanto tempo é razoável para a quarentena, a inspeção, a conferência? Os números do protótipo são só exemplos.
- **Horas corridas ou horas úteis** para medir o tempo.
- **Precisa aparecer o nome da pessoa** em cada passagem, ou basta o setor? Se for o nome, quem trabalha no chão de fábrica terá que se identificar a cada passagem.
- **O que o vendedor pode ver:** só a etapa, ou mais?
- **Se o cliente de fora algum dia vai ver** alguma parte disso.

## O que isso exige do sistema

Campos novos (quem fez, quando, quem autorizou, com quem está) em várias tabelas dos dois sistemas, e um identificador único de pessoa que funcione nos dois. O detalhe técnico está no vault de modelagem, nas notas `Rastreabilidade-e-SLA-de-Eventos` e `Campos-e-API-para-Rastreabilidade`. Wikilinks não atravessam vaults, então é preciso abri-las manualmente.

## Ver também
- [[Quem-Faz-o-Que]]
- [[Portal-do-Vendedor]]
- [[Sistema-de-Fabrica-MES]]
- [[Principais-Decisoes]]
- [[Perguntas-Pendentes]]
