---
tags: [visao-setores, decisoes-projeto]
criado: 2026-09-16
---

# Sistema de Fábrica (MES Aços Vital)

## O que é

"MES Aços Vital" é o nome de trabalho (ainda não definitivo) do sistema que vai reunir **Estoque e toda a fabricação** da empresa num só lugar. Ele nasce a partir do sistema que hoje controla a produção de Flanges, ampliado para cobrir Estoque e as demais linhas de produção conforme forem sendo cadastradas (Grades de Piso, Chapa Expandida, Caldeiraria, e outras que a empresa vier a ter). Corte de chapa sob medida **não** entra nesse sistema — é tratado como um serviço dentro da Revenda, não como uma linha de fabricação. Ver [[Cortando-Chapas-sob-Medida]].

## O que ele vai cobrir

- **Estoque**: saldo de material, depósitos, entrada e saída de itens.
- **Toda a fabricação**: fábricas, setores, máquinas, operadores e as etapas de produção de cada linha — não fica restrito a Flanges, o modelo já é preparado para receber novas linhas de produção conforme a empresa for cadastrando.
- **Recebimento e conferência** do que chega na empresa (materiais comprados).
- **Ordem de Serviço e Ordem de Produção**, usando o mesmo mecanismo de acompanhamento de etapas que já existe hoje no sistema de Flanges.

## A fronteira entre o av-hub e o sistema de fábrica

A regra combinada é simples: **o av-hub decide, o sistema de fábrica executa.**

- **av-hub decide**: origina o Orçamento (quando esse conceito for definido), o Pedido de Venda e a Ordem de Compra — inclusive quem é o fornecedor, o preço negociado e a aprovação da compra.
- **Sistema de fábrica executa**: produção, recebimento de material, controle de saldo em estoque.

Na prática, para compras isso funciona assim: a necessidade de comprar algo nasce no chão de fábrica (quando falta material), essa necessidade vira uma solicitação que chega ao comprador no av-hub, o comprador fecha a compra (escolhe fornecedor, negocia preço, aprova), e só a informação necessária para conferir o que chegou (itens, quantidade, se é material acabado ou não) volta para o sistema de fábrica — não o valor comercial completo da negociação.

## Como os dois sistemas vão se comunicar

Hoje, av-hub e sistema de fábrica são dois sistemas com bases de dados totalmente separadas — isso não muda. A comunicação entre eles acontece por meio de **avisos automáticos de mudança** que um sistema manda para o outro (por exemplo: quando um material muda de status no fornecedor cadastrado no av-hub, o sistema de fábrica recebe essa atualização). Não é uma cópia manual de dados — é um mecanismo automático, mas também não é necessariamente instantâneo em tempo real; hoje o padrão real de sincronização entre sistemas na empresa (visto na integração com o sistema fiscal) é por consultas periódicas, não por aviso imediato a cada mudança. Isso deve valer também aqui, até que algo diferente seja desenhado.

Alguns exemplos concretos dessa comunicação:

- **Fornecedores**: o sistema de fábrica não vai ter um cadastro de fornecedores próprio — ele recebe essa informação automaticamente do cadastro que já existe no av-hub (que por sua vez já vem do sistema fiscal). Isso evita ter três cadastros de fornecedor diferentes coexistindo.
- **Materiais/produtos**: mesma lógica — o catálogo de materiais do sistema de fábrica é alimentado a partir do catálogo de produtos do av-hub, com campos extras específicos de estoque (peso teórico, tolerância, mínimo e máximo) adicionados só do lado do sistema de fábrica quando necessário.

## O que ainda falta decidir

- Como exatamente vincular cada fábrica à unidade/filial da empresa (Mogi, Uberaba etc.).
- O conceito de "Orçamento" dentro do ERP novo.
- O nome definitivo do sistema (hoje é só "MES Aços Vital", nome de trabalho).
- Se a empresa vai passar a criar Pedido de Venda e Ordem de Compra diretamente no av-hub, empurrando essa informação para o sistema fiscal — é uma visão confirmada de futuro, mas não é prioridade agora, e ainda falta confirmar se o sistema fiscal aceita esse tipo de criação por fora.

Ver [[Perguntas-Pendentes]] para a lista completa de perguntas ainda sem resposta.

## Ver também
- [[Home]]
- [[Sistema-de-Producao-Flanges]]
- [[Controlando-o-Estoque]]
- [[Comprando-o-que-Falta]]
- [[Fabricando-Produtos-Proprios]]
- [[Ambiguidade-do-Nome-PCP]]
- [[Duplicacao-de-Acessos]]
- [[Onde-os-Sistemas-Rodam]]
- [[Principais-Decisoes]]
- [[Perguntas-Pendentes]]
