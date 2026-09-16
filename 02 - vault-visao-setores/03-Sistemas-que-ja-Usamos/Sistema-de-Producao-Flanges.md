---
tags: [visao-setores, sistemas-existentes]
criado: 2026-09-16
---

# Sistema de Produção de Flanges

Este é o sistema que controla o chão de fábrica — hoje focado na produção de **flanges**. Ele é conhecido internamente como "PCP" (Programação e Controle de Produção), mas é importante não confundir com o "Portal do PCP" que existe dentro do av-hub: são coisas completamente diferentes com o mesmo apelido. O Portal do PCP do av-hub é acompanhamento comercial de pedidos; este aqui é o sistema que efetivamente acompanha a fabricação na fábrica. Ver `Ambiguidade-do-Nome-PCP` na pasta `04-Decisoes-do-Projeto` para o detalhamento dessa confusão de nome.

Este sistema está em construção ativa. A parte de "motor" (tudo que guarda e movimenta os dados de produção) já está bem mais avançada do que as telas disponíveis hoje — ou seja, o sistema já sabe fazer muito mais coisa do que ainda dá para ver na tela.

## Como um pedido de produção é criado

Um pedido de produção pode vir de três origens: puxado automaticamente do Omie, digitado manualmente, ou (previsto, mas ainda sem uso confirmado) de outro sistema de terceiros. Quando vem do Omie, os dados do cliente e os itens já vêm travados (não editáveis) — o formulário só permite adicionar itens à mão quando a origem não é o Omie.

Cada item de um pedido é associado a uma fábrica. Um item sem fábrica atribuída é tratado como revenda simples e não entra no fluxo de produção.

## Roteiro de produção

Para cada fábrica envolvida em um pedido, é montado um **roteiro**: a sequência de setores pelos quais aquele item vai passar durante a fabricação (por exemplo, Corte → Solda → Pintura → Inspeção). Essa sequência é montada clicando nos setores na ordem desejada, e o sistema exige que todo pedido tenho pelo menos um roteiro definido antes de ser salvo.

## Acompanhamento do item durante a produção

Por trás das telas já disponíveis, o sistema já controla, para cada fração de um pedido em produção, um estado bem detalhado — algo como: criado, recebido pelo setor, em andamento, em trânsito para o próximo setor, pausado, em retrabalho, concluído (ou cancelado). Isso permite, por exemplo, dividir um lote em partes que seguem caminhos diferentes, ou devolver um item para o setor anterior quando algo precisa ser refeito. Toda essa movimentação fica registrada num histórico permanente, para consulta e relatórios.

Isso é distinto de **entrega ao cliente** — que é registrada separadamente, mostrando quanto do pedido já foi efetivamente entregue, mesmo que a entrega tenha acontecido em mais de uma etapa.

O sistema também já controla embalagem e paletização (quantas unidades, peso por palete) e anexos por pedido ou por etapa (nota, canhoto, desenho, ordem de produção, comprovante de entrega) — inclusive já existe a função de juntar vários desses documentos num único PDF para impressão.

## Divergências

Quando algo sai errado num pedido (uma divergência), ela é registrada, analisada e depois marcada como resolvida ou cancelada. Um ponto de atenção: hoje não existe uma forma de reabrir uma divergência que já foi marcada como resolvida ou cancelada por engano — vale confirmar com a equipe técnica se isso é intencional ou se precisa de ajuste, já que travar um caso sem volta já causou problema numa versão anterior deste mesmo sistema.

## Painel de acompanhamento (dashboard)

O sistema já tem prontos, por trás das telas, os dados para um painel de acompanhamento de produção: contagem de pedidos por situação, pedidos atrasados e urgentes, distribuição por setor e as últimas movimentações registradas — incluindo uma versão simplificada pensada para ficar exibida numa TV dentro da fábrica. A tela inicial do sistema hoje ainda aparece vazia, mas isso é só porque a tela ainda não foi construída para mostrar esses dados — a informação já existe.

## O que ainda não existe hoje

- Não é possível ainda abrir um pedido já criado para editá-lo ou avançar sua situação diretamente pela tela.
- Não existe ainda uma visão tipo "quadro" (por setor/situação) mostrando o andamento visual de todos os pedidos.
- O sistema hoje cobre a fabricação de flanges. Não há, até o momento, evidência de um sistema equivalente dedicado a chapas ou grades de piso.

## Ver também
- [[av-hub]]
- [[Acessos-e-Permissoes]]
- [[Situacao-Atual]]
