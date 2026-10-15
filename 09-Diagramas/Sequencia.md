---
tags: [diagramas, sequencia, uml, mes, av-hub]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [v1 04-Arquitetura-Transversal/Diagramas-UML (0a, 12, 15), v1 02-PRD-Estoque/Fluxo-*-Completo, 00-Fluxo-Mestre-0b, api-pcp 579a625, api-acos-vital f322dcd, app-pcp 1fca8d3]
---

# Diagramas de sequência

Redesenhados a partir do [[00-Fluxo-Mestre-0b]] e conferidos no código de 14/10/2026. Cada mensagem começa com o ID do nó do Mestre quando existe. Visão geral e destino de cada diagrama do v1: [[Indice-de-Diagramas]]. Selos: [[Regras-do-Vault]].

Lista:

1. Do pedido liberado à Destinação (V2 a P2)
2. Atendimento do Estoque (E1 a E4)
3. Requisição de compra, ida (P3) e volta (C1 a C5)
4. Chegada com NF e Recebimento (R0 a R6)
5. Inspeção de entrada e volta ao Estoque (Q1 a Q4, E5)
6. Produção, inspeção de saída e Expedição (F1, Q7, X1 a X4, O1)
7. Despacho do Estoque: hoje e decidido (E6)

## 1. Do pedido liberado à Destinação (V2 a P2)

Fluxo 4 da integração ([[Integracao-AvHub-MES]], INT-01). Só pedido liberado atravessa para o MES.

```mermaid
sequenceDiagram
    participant VEN as Vendedor no HUB
    participant API as api-acos-vital
    participant PCP as PCP no app-pcp
    participant MES as api-pcp
    VEN->>API: V2 V3 PUT pedidos_liberacao marca e libera
    API-->>VEN: 200 status liberado
    PCP->>MES: P1 abre a Triagem do Pedido
    MES->>API: GET pedidos_liberados
    API-->>MES: so os liberados
    PCP->>MES: P2 abre o pedido na Destinacao
    MES->>API: GET pedidos_liberados numero itens
    API-->>MES: itens e acompanhamento_qualidade, 409 se nao liberado
    PCP->>MES: P2 POST pedidos completo lote com destino e quantidade por item
    MES->>MES: cria Pedidos e roteiro com Estoque como etapa 1
    MES->>API: POST pedidos_liberados numero importado
    API-->>MES: 200 marcacao travada
    Note over MES,API: se o importado falhar o MES reenvia a cada 10 min por 7 dias
```

Selo ✅: rotas em `api-pcp/src/pedidos/pedidos.controller.ts:58,102` e `omie-integracao.ts:331-425` (conferidas na nota de integração).

## 2. Atendimento do Estoque (E1 a E4)

O almoxarife atende a parcial pelo saldo (split e reserva) e decide o destino do restante.

```mermaid
sequenceDiagram
    participant ALM as Almoxarife no setor Estoque
    participant MES as api-pcp
    participant DB as Banco do MES
    ALM->>MES: E1 GET estoque saldo disponivel-parcial id
    MES-->>ALM: lotes LIBERADO menos reservas ATIVA na filial do pedido
    Note over ALM: E2 saldo zero exige clique, decisao 31b
    ALM->>MES: E3 PATCH itens-parciais id atender-estoque com alocacoes por lote
    MES->>DB: split da parcial e Reserva ATIVA por lote
    MES->>DB: parte atendida segue em transito para a Expedicao
    alt E4 destinoRestante igual a COMPRA
        MES->>DB: restante vai ao setor Requisicoes, ver diagrama 3
    else E4 destinoRestante igual a ROTEIRO
        MES->>DB: restante segue o roteiro de producao
    end
```

Selo ✅: `itens-parciais.service.ts:607-700` (`atenderEstoque`, `destinoRestante` `'ROTEIRO' | 'COMPRA'`); saldo em `estoque-operacao.controller.ts:46`. 🔴 O custo do item (média dos lotes) não é calculado: não existe `GET /itens/custo` no MES.

## 3. Requisição de compra: ida (P3) e volta (C1 a C5)

Duas origens de requisição ([[00-Fluxo-Mestre-0b]], nós P3 e C0). Este diagrama é a origem PCP; a origem Compras (C0) nasce no av-hub e a requisição não chega ao MES; o MES lê a OC dela pela referência (N14-20, 🔴 ainda não lê; ver [[Integracao-AvHub-MES]]).

### 3.1 Ida (LOG-34)

```mermaid
sequenceDiagram
    participant PCP as PCP no setor Requisicoes
    participant MES as api-pcp
    participant FILA as integracao_avhub_envios
    participant API as api-acos-vital
    participant CMP as Comprador no HUB
    PCP->>MES: P3 POST compras requisicoes
    MES->>FILA: grava RequisicaoCompra e um envio PENDENTE por item na mesma transacao
    MES->>API: PUT compras requisicoes origem id_origem
    API-->>MES: 201 nasce aberta com numero REQ
    MES->>FILA: envio ENVIADO e espelha id e numero no item
    CMP->>API: C1 ve a requisicao na caixa do Compras
    PCP->>MES: cancela a requisicao
    MES->>API: PUT com cancelada true
    API-->>MES: 409 REQUISICAO_COM_OC se ja tem OC
    MES->>FILA: envio RECUSADO sem repetir
    Note over MES,API: rede ou 5xx reagenda com espera 1, 2, 5, 10, 30, 60 min
```

Selo ✅: `envio-avhub.service.ts:21,98-102,129-175`; resposta do hub `requisicoes_compra.route.js:221-265`.

### 3.2 Volta (LOG-35)

```mermaid
sequenceDiagram
    participant CMP as Compras no HUB
    participant API as api-acos-vital
    participant MES as api-pcp
    participant CCP as Compras CCP no app-pcp
    participant FN as Fornecedor
    CMP->>API: C1 cotacao
    CMP->>API: C4 emite a OC
    API->>API: trigger grava requisicoes_compra_eventos
    CMP->>API: C3 aprovacao pelo Gerente de Compras, so OC acima de 30 mil
    API->>API: evento oc_aprovada
    loop a cada 5 min
        MES->>API: GET compras requisicoes eventos desde o cursor
        API-->>MES: eventos novos
        MES->>MES: grava por id_evento e aplica etapaCompra
    end
    CCP->>MES: POST compras requisicoes sincronizar ao abrir e no Atualizar
    MES->>API: GET eventos se a ultima leitura tem mais de 30 s
    Note over MES,CCP: C5 oc_aprovada coloca a parcial nos esperados do Recebimento R0
    CMP->>FN: C5 envia a OC e acompanha o prazo
    API->>API: eventos despachada, previsao_alterada, ocorrencia
    MES->>MES: etapaCompra EM_TRANSITO e previsaoChegada
```

Selo ✅: `eventos-avhub.service.ts:25-27,31,80,150-181`, tratamento por tipo em `requisicao-avhub.eventos.ts:234-318`. 🔴 O MES não recebe fornecedor da OC: falta o job do contrato 004/007.

## 4. Chegada com NF e Recebimento (R0 a R6)

A doca registra a chegada com a NF. A conferência é contra a NF, não contra a OC (decisão do Nathan de 14/10; cruzamento com a OC entra com o job do contrato 004).

```mermaid
sequenceDiagram
    participant DOC as Doca no setor Recebimento
    participant MES as api-pcp
    participant PCP as PCP em Decisoes do PCP
    participant DB as Banco do MES
    DOC->>MES: R0 GET compras requisicoes esperados
    MES-->>DOC: requisicoes com OC aprovada ou liberadas, por previsao
    DOC->>MES: R0 POST compras requisicoes id chegada com numero ou chave da NF
    MES->>DB: parcial sai de Compras CCP para Recebimento
    Note over DOC,MES: sem OC aprovada so a liberacao manual com motivo POST id liberar-recebimento
    DOC->>MES: R1 R2 POST compras recebimentos com contagem, peso e localizacao
    alt R3 bate com a NF e o peso na tolerancia
        MES->>DB: R4 lote PENDENTE em quarentena e ENTRADA no saldo
        MES->>DB: parcial segue para Qualidade Entrada com idLoteCompra
        MES->>DB: chegou so parte, o restante volta a Compras CCP
    else diverge
        MES->>DB: R6 Recebimento AGUARDANDO_RECONTAGEM, nada entra
        DOC->>MES: outra pessoa POST id recontar
        alt recontagem bate
            MES->>DB: CONCLUIDO como no ramo que bate
        else continua divergindo
            MES->>DB: AGUARDANDO_DECISAO
            PCP->>MES: POST id decidir com motivo
            alt aceita
                MES->>DB: ACEITO e entra a quantidade recontada
            else reabre
                MES->>DB: REABERTO, nada entra e a parcial volta a Compras CCP
            end
        end
    end
```

Selo ✅: `compras.service.ts:356-402` (chegada exige NF, parcial em `COMPRAS`), `:404-455` (liberar), `recebimento.service.ts:135,249,331`; rotas `recebimento.controller.ts:46,52,62`. 🔴 O custo da OC não é gravado no lote (R4).

## 5. Inspeção de entrada e volta ao Estoque (Q1 a Q4, E5)

```mermaid
sequenceDiagram
    participant QUA as Qualidade Entrada
    participant MES as api-pcp
    participant DB as Banco do MES
    participant CMP as Compras CCP
    QUA->>MES: Q1 GET qualidade lotes pendentes
    alt Q2 aprova com laudo
        QUA->>MES: POST qualidade lotes id aprovar
        MES->>DB: lote LIBERADO
        MES->>DB: E5 devolverAoEstoqueParciaisProntas, parcial volta ao Estoque
    else reprova total ou parcial
        QUA->>MES: POST qualidade lotes id reprovar com motivo, evidencia e quantidade
        MES->>DB: Q3 Rnc com nota_devolucao_pendente
        MES->>DB: reprovacao parcial cria lote filho REPROVADO
        MES->>DB: Q4 pai fica em QUARENTENA se a parcial ainda espera
        MES->>CMP: parte reprovada volta a Compras CCP para recompra
        Note over MES,CMP: substituicao aprovada une as parciais e libera a quarentena
    end
```

Selo ✅: `qualidade.service.ts:83-100` (aprovar), `:102-262` (reprovar, quarentena em `:243`), `circuito-compra.ts:166-` (união e volta ao Estoque). 🟡 A recompra por RNC não tem contrato com o av-hub.

## 6. Produção, inspeção de saída e Expedição (F1, Q7, X1 a X4, O1)

```mermaid
sequenceDiagram
    participant OPE as Operador na fabrica
    participant QUA as Qualidade de saida
    participant PCP as PCP
    participant EXP as Expedicao
    participant MES as api-pcp
    participant OM as Omie
    OPE->>MES: F1 receber, iniciar, mover e concluir nos setores do roteiro
    MES->>QUA: Q7 parcial chega ao setor QUALIDADE do roteiro
    alt Q8 aprova
        QUA->>MES: mover para o proximo setor
        Note over MES: o nó Q8 do Mestre manda o aprovado ao Estoque E5, o codigo manda a Expedicao
    else reprova
        QUA->>MES: PATCH itens-parciais id reprovar abre Divergencia QUALIDADE
        PCP->>MES: P6 resolver, ou retrabalho cria nova parcial EM_TRANSITO
    end
    EXP->>MES: X1 PATCH itens-parciais id receber e pallets
    MES->>MES: consumirReservasDaParcial, baixa do saldo ao receber
    EXP->>MES: X4 POST entregas com NF e comprovante
    MES-->>EXP: entrega registrada
    Note over MES,OM: O1 O2 o Omie emite a nota. A sinalizacao do MES ao Omie nao existe
```

Selo ✅: `itens-parciais.controller.ts:206-229` (reprovar, resolver, retrabalho), `itens-parciais.service.ts:279` e `entregas.service.ts:88` (baixa). 🟡 Q8 (aprovado volta ao Estoque) e X3 (consolidar carga) sem código. 🔴 Sinalização de faturamento (11.1).

## 7. Despacho do Estoque: hoje e decidido (E6)

```mermaid
sequenceDiagram
    participant REQ as Expedicao ou Producao
    participant EST as Setor Estoque
    participant MES as api-pcp
    participant DB as Banco do MES
    Note over REQ,DB: Decidido 14/10, sem codigo
    REQ->>EST: E6 precisa da mercadoria e gera o documento de retirada
    EST->>MES: confirma a retirada do lote reservado
    MES->>DB: Reserva CONSUMIDA e Movimento SAIDA do lote
    Note over REQ,DB: Hoje no codigo
    REQ->>MES: receber a parcial na Embalagem ou Expedicao
    MES->>DB: consumirReservasDaParcial, Reserva CONSUMIDA e SAIDA
```

📝 Decisão do Nathan de 14/10. 🔴 Não existe documento de retirada nem tela; hoje a baixa é na Embalagem/Expedição (`itens-parciais.service.ts:274-282`). Dono: Robert ([[03-Estoque-Atendimento-e-Despacho]]).
