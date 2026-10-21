---
tags: [diagramas, estados, uml, mes, av-hub]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [v1 Diagramas-UML (5, 6, 7, 8, 20, 24), api-pcp 579a625 prisma/models, api-acos-vital f322dcd, 00-Fluxo-Mestre-0b]
---

# Diagramas de estados

Os enums vêm do Prisma do `api-pcp` (`prisma/models/*.prisma`) e das rotas do `api-acos-vital` em 14/10/2026. Vocabulário completo de status e etapas: [[Estados-e-Status]]. Destino de cada diagrama do v1: [[Indice-de-Diagramas]].

## 1. Parcial do item (`ItemParcial`, enum `StatusItemParcial`)

Motor de estado do chão de fábrica. 9 valores no enum ✅ (`producao.prisma:29-55`): `CRIADO`, `RECEBIDO`, `EM_ANDAMENTO`, `EM_TRANSITO`, `PAUSADO`, `REPROVADO`, `CONCLUIDO`, `RETRABALHO`, `CANCELADO`. Não é entrega ao cliente (isso é `Entrega`).

```mermaid
stateDiagram-v2
    [*] --> CRIADO
    CRIADO --> RECEBIDO : receber
    EM_TRANSITO --> RECEBIDO : chega no proximo setor
    RECEBIDO --> EM_ANDAMENTO : iniciar
    EM_ANDAMENTO --> EM_TRANSITO : mover ou atender pelo estoque
    EM_ANDAMENTO --> PAUSADO : pausar
    PAUSADO --> EM_ANDAMENTO : retomar
    EM_ANDAMENTO --> REPROVADO : reprovar
    REPROVADO --> EM_ANDAMENTO : resolver, falso alarme
    REPROVADO --> CANCELADO : retrabalho, cria nova linha EM_TRANSITO
    EM_ANDAMENTO --> CANCELADO : devolver ao setor anterior
    EM_ANDAMENTO --> CONCLUIDO : concluir no ultimo setor
    RECEBIDO --> EM_TRANSITO : desfazer recebimento
    CONCLUIDO --> [*]
    CANCELADO --> [*]

    note right of CANCELADO
        devolver e retrabalho criam uma NOVA linha
        EM_TRANSITO ligada por idDevolvidoDe.
        A uniao de parciais no retorno de compra
        tambem cancela as de origem.
        RETRABALHO so existe por legado
    end note
```

Selo ✅: ações em `itens-parciais.controller.ts:100-297` (receber, iniciar, mover, concluir, atender-estoque, pausar, reprovar, resolver, retrabalho, retomar, split, devolver, cancelar, desfazer-recebimento, consolidar). Nó do Mestre: F1, Q7, X1. `desfazer-recebimento` ✅ `itens-parciais.controller.ts:285` estorna o consumo da reserva; ❓ o status de destino exato não foi relido nesta rodada (desenhado como `EM_TRANSITO`).

## 2. Lote (`StatusQualidadeLote`)

```mermaid
stateDiagram-v2
    [*] --> PENDENTE : R4 recebimento, lote em quarentena
    [*] --> LIBERADO : carga inicial
    PENDENTE --> LIBERADO : Q2 aprova com laudo
    PENDENTE --> REPROVADO : Q2 reprova tudo
    PENDENTE --> QUARENTENA : Q4 reprova parte e a parcial espera
    QUARENTENA --> LIBERADO : substituicao aprovada
    LIBERADO --> [*]
    REPROVADO --> [*]

    note right of QUARENTENA
        Reprovacao parcial gera um lote filho REPROVADO
        com a quantidade reprovada. O pai fica em
        QUARENTENA se uma parcial ainda espera,
        ou LIBERADO se nao
    end note
```

Selo ✅: enum `estoque.prisma:25-32`; `qualidade.service.ts:83-262` (quarentena em `:243`); carga inicial `OrigemLote.CARGA_INICIAL`. 🔴 Não existe origem de lote para fabricado aprovado (`OrigemLote` só tem `RECEBIMENTO` e `CARGA_INICIAL`).

## 3. Reserva de estoque (`StatusReserva`)

```mermaid
stateDiagram-v2
    [*] --> ATIVA : E3 atender pelo estoque, so lote LIBERADO
    ATIVA --> CONSUMIDA : baixa do saldo
    CONSUMIDA --> ATIVA : estorno ao desfazer o recebimento
    ATIVA --> LIBERADA : cancelamento do pedido ou liberacao manual com motivo
    CONSUMIDA --> [*]
    LIBERADA --> [*]

    note right of CONSUMIDA
        Hoje a baixa acontece quando a Embalagem
        ou Expedicao recebe a parcial.
        Decidido 14/10: a baixa passa para o
        documento de retirada no Estoque, E6
    end note
```

Selo ✅ enum `estoque.prisma:48-52`, `consumirReservasDaParcial` em `estoque-operacao.helpers.ts:208`; 📝 retirada decidida; 🔴 sem código. Liberação manual: `PATCH /estoque/reservas/:id/liberar` ✅ `estoque-operacao.controller.ts:97`.

## 4. Recebimento (`StatusRecebimento`)

```mermaid
stateDiagram-v2
    [*] --> CONCLUIDO : R3 conferencia sem divergencia, lote nasce
    [*] --> AGUARDANDO_RECONTAGEM : R6 conferencia divergiu, nada entra
    AGUARDANDO_RECONTAGEM --> CONCLUIDO : recontagem bate, outra pessoa
    AGUARDANDO_RECONTAGEM --> AGUARDANDO_DECISAO : recontagem ainda diverge
    AGUARDANDO_DECISAO --> ACEITO : PCP aceita, entra o valor recontado
    AGUARDANDO_DECISAO --> REABERTO : PCP reabre, parcial volta a Compras CCP
    CONCLUIDO --> [*]
    ACEITO --> [*]
    REABERTO --> [*]
```

Selo ✅: enum `compras.prisma:31-37`; `recebimento.service.ts:135,249,331`. Motivo obrigatório em `ACEITO` e `REABERTO`. Tipos de divergência do recebimento: `QUANTIDADE`, `DESCRICAO`, `PESO`, `AVARIA` ✅ `compras.prisma:42-47`.

## 5. Divergência de produção (`StatusDivergencia`)

```mermaid
stateDiagram-v2
    [*] --> ABERTA : reprovar abre divergencia QUALIDADE
    ABERTA --> EM_ANALISE
    EM_ANALISE --> RESOLVIDA : resolver
    EM_ANALISE --> CANCELADA
    RESOLVIDA --> [*]
    CANCELADA --> [*]
```

Selo ✅ enum `producao.prisma:77-82`. 🔴 Não há reabertura de divergência resolvida (sem endpoint; risco catalogado e adiado). Tipos: `QUALIDADE`, `QUANTIDADE`, `PRAZO`, `DANO`, `DOCUMENTACAO`, `OUTRO`.

## 6. Requisição de compra no MES (`StatusRequisicaoCompra`)

Resumo da requisição, recalculado por `resumirRequisicao` a cada marco do av-hub e a cada recebimento.

```mermaid
stateDiagram-v2
    [*] --> ABERTA : P3 requisicao criada
    ABERTA --> EM_COMPRA : OC aprovada ou liberacao manual
    EM_COMPRA --> ABERTA : oc_cancelada ou oc_removida
    EM_COMPRA --> RECEBIDA_PARCIAL : recebeu parte
    RECEBIDA_PARCIAL --> RECEBIDA : recebeu o total
    EM_COMPRA --> RECEBIDA : recebeu o total
    ABERTA --> CANCELADA : MES cancela ou Compras cancela
    CANCELADA --> ABERTA : requisicao_reaberta, so a cancelada pelo Compras
    RECEBIDA --> [*]
```

Selo ✅ enum `compras.prisma:9-15`; cancelamento só em `ABERTA` (`canceladaPor` `mes` ou `compras`, `compras.prisma:84-87`); liberação manual muda `ABERTA` para `EM_COMPRA` (`compras.service.ts:430-436`). 🟡 As arestas `RECEBIDA_PARCIAL` e `RECEBIDA` vêm de `resumirRequisicao`, não relido linha a linha nesta rodada; pendência PS-011 em [[Pontas-Soltas]].

## 7. Etapa de compra de cada material (`RequisicaoCompraItem.etapaCompra`)

Espelho dos marcos do contrato 35 ([[Integracao-AvHub-MES]], INT-03).

```mermaid
stateDiagram-v2
    [*] --> AGUARDANDO_COMPRADOR : requisicao_recebida
    AGUARDANDO_COMPRADOR --> EM_COTACAO : em_cotacao
    EM_COTACAO --> EM_APROVACAO : oc_criada ou oc_enviada_aprovacao
    EM_APROVACAO --> EM_COTACAO : oc_removida
    EM_APROVACAO --> COM_FORNECEDOR : oc_aprovada, entra nos esperados
    COM_FORNECEDOR --> EM_TRANSITO : despachada
    COM_FORNECEDOR --> AGUARDANDO_COMPRADOR : oc_cancelada
    EM_TRANSITO --> AGUARDANDO_COMPRADOR : oc_cancelada
    AGUARDANDO_COMPRADOR --> CANCELADA : requisicao_cancelada
    EM_COTACAO --> CANCELADA : requisicao_cancelada
    CANCELADA --> AGUARDANDO_COMPRADOR : requisicao_reaberta
```

Selo ✅ `requisicao-avhub.eventos.ts:234-318`; valores em `compras.prisma:132-135`. `previsao_alterada`, `fornecedor_confirmou`, `oc_no_omie` e `ocorrencia` não mudam a etapa.

## 8. Requisição no av-hub (`requisicoes_compra.status`)

```mermaid
stateDiagram-v2
    [*] --> aberta
    aberta --> em_cotacao : PATCH
    em_cotacao --> aberta : PATCH
    aberta --> cancelada : PATCH com motivo
    em_cotacao --> cancelada : PATCH com motivo
    cancelada --> aberta : PATCH, reabre
    cancelada --> em_cotacao : PATCH
    aberta --> atendida : trigger da OC
    em_cotacao --> atendida : trigger da OC
    atendida --> [*]
    aberta --> excluida : DELETE, so criada no Hub (LOG-55)
    em_cotacao --> excluida : DELETE, so criada no Hub (LOG-55)
    cancelada --> excluida : DELETE, so criada no Hub (LOG-55)
    excluida --> [*]
```

🔴 `excluida` é 📝 proposta ([[LOG-55-Compras-Excluir-Requisicao]]): exclusão lógica (`deleted_at`), sem OC e sem `id_origem`; a requisição do MES continua só cancelável. Banco e API ainda não existem.

Selo ✅ `requisicoes_compra.route.js:13-22` (`atendida` só pela trigger da OC, nunca pelo PATCH); 409 `REQUISICAO_COM_OC` ao cancelar com OC (`:221-265`).

## 9. Ordem de compra no av-hub (`ordens_compra.status`)

```mermaid
stateDiagram-v2
    [*] --> rascunho
    rascunho --> aguardando_aprovacao : C4 envia
    aguardando_aprovacao --> aprovado : valor ate 30 mil, a trigger aprova sozinha
    aguardando_aprovacao --> aprovado : C3 Gerente de Compras, valor acima de 30 mil
    aguardando_aprovacao --> cancelado : reprovada ou cancelada
    aprovado --> cancelado : oc_cancelada
    aprovado --> [*]
    cancelado --> [*]
```

Selo ✅ valores em `ordens_compra.route.js:91` e no `CHECK` do dump (`ck_ordens_compra_status`); 🟡 as transições exatas são feitas por trigger do banco e não foram relidas; ✅ regra de aprovação N14-21: até o limite da unidade (R$ 30 mil por padrão) a trigger `fn_ordens_compra_recalcular` aprova sozinha; acima dele, só o Gerente de Compras (`ordens_compra.route.js:1230-1240`); a Diretoria não aprova (Mestre, nós C2/C3). Envio ao Omie tem estado próprio (`status_sincronizacao_omie`) fora deste diagrama.

## 10. Envio da requisição ao av-hub (`StatusEnvioAvhub`)

```mermaid
stateDiagram-v2
    [*] --> PENDENTE : criar ou cancelar a requisicao
    PENDENTE --> ENVIADO : 200 ou 201
    PENDENTE --> PENDENTE : rede, 401, 403, 404 ou 5xx, espera crescente
    PENDENTE --> RECUSADO : 409 REQUISICAO_COM_OC
    PENDENTE --> FALHOU : 400 corpo recusado
    FALHOU --> PENDENTE : alguem corrige e volta o status
    ENVIADO --> [*]
    RECUSADO --> [*]
```

Selo ✅ `integracao.prisma:17-29`, `envio-avhub.service.ts:164-169`.

## 11. Liberação do pedido (`status_liberacao`)

```mermaid
stateDiagram-v2
    [*] --> pendente : V1 pedido chega travado
    pendente --> liberado : V2 V3 vendedor marca e libera
    liberado --> liberado : vendedor corrige a marcacao
    liberado --> importado : P2 MES confirma a importacao
    importado --> [*]
```

Selo ✅ valores da view `vw_pedidos_liberacao` e travas: [[01-Vendas-Liberacao]]; importado trava a marcação (409 `PEDIDO_IMPORTADO_MES`).

## 12. Do setor e do status para a etapa do item (contrato 005)

Não é um diagrama de transição: o MES calcula a etapa por regra (`etapaDoItem`). As 11 etapas e a tradução no HUB estão em [[Estados-e-Status]].

```mermaid
flowchart TD
    S0{"Status da parcial e tipo do setor"}
    S0 -->|"REPROVADO"| E_QR["qualidade.reprovado"]
    S0 -->|"ESTOQUE E1 a E4"| E_EA["estoque.atendimento"]
    S0 -->|"REQUISICAO P3"| E_CR["compras.requisicao"]
    S0 -->|"COMPRAS C1 a C5"| E_CF["compras.fechamento"]
    S0 -->|"LOGISTICA_ENTRADA R0 a R6"| E_RC["recebimento.conferencia"]
    S0 -->|"Qualidade Entrada, lote em QUARENTENA Q4"| E_QQ["qualidade.quarentena"]
    S0 -->|"Qualidade Entrada ou QUALIDADE do roteiro Q1 Q7"| E_QI["qualidade.inspecao"]
    S0 -->|"EXPEDICAO e CONCLUIDO X4"| E_XC["expedicao.concluido"]
    S0 -->|"EXPEDICAO X1"| E_XE["expedicao.embalagem"]
    S0 -->|"PRODUTIVO em andamento, pausado ou retrabalho F1"| E_FE["fabrica.execucao"]
    S0 -->|"PRODUTIVO nos demais status F1"| E_FS["fabrica.espera"]
```

Selo ✅ `integracao-avhub.service.ts:160-192`. 🟡 `compras.fechamento` ainda é "Em compra", sem cotação, aprovação e trânsito (BL-009).

## Outros enums de status do MES

| Enum | Valores | Selo |
|---|---|---|
| `StatusPedido` | `AGUARDANDO`, `EM_PRODUCAO`, `BLOQUEADO`, `ENTREGUE` | ✅ `producao.prisma:11-16` |
| `TipoMovimentoEstoque` | `ENTRADA`, `SAIDA`, `TRANSFERENCIA`, `AJUSTE` | ✅ `estoque.prisma:38-43` |
| `OrigemCusto` (`lote_custo`) | `CARGA_INICIAL`, `OC`, `MANUAL` | ✅ `estoque.prisma:378-382`; só a carga inicial grava 🔴 |
| `TipoSetor` | `PRODUTIVO`, `ESTOQUE`, `COMPRAS`, `EXPEDICAO`, `REQUISICAO`, `LOGISTICA_ENTRADA`, `QUALIDADE` | ✅ `fabricas.prisma:17-30` |
| `TipoFabrica` | `FABRICACAO`, `REVENDA` | ✅ `fabricas.prisma:5-8` |
