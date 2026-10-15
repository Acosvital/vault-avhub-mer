---
tags: [diagramas, casos-de-uso, uml, atividades]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [v1 Diagramas-UML (4a a 4e), 00-Fluxo-Mestre-0b, notas de raia de 02-Fluxo-de-Atividades, api-pcp 579a625, app-pcp 1fca8d3, HUB b55ac55]
---

# Diagramas de casos de uso

Redesenhados por raia do [[00-Fluxo-Mestre-0b]]. O mermaid não tem notação nativa de caso de uso: atores são nós arredondados e casos de uso são elipses dentro de um subgrafo "Sistema". Cada caso de uso leva o ID do nó do Mestre (`V2`, `E3`…) e a tabela abaixo de cada bloco diz o estado no código. Destino de cada diagrama do v1: [[Indice-de-Diagramas]].

## 1. Vendas (V1 a V3)

```mermaid
flowchart LR
    VEN(["Vendedor"])
    AUX(["Auxiliar do titular"])
    GER(["Gerente"])
    subgraph SIS1["Sistema HUB e api-acos-vital"]
        V23(["V2 V3 Marcar se a Qualidade acompanha e liberar o pedido"])
        V2C(["Corrigir a marcacao ate o MES importar"])
        VET(["Acompanhar a etapa de cada item"])
        VGE(["Ver a liberacao da equipe, so leitura"])
    end
    VEN --> V23
    VEN --> V2C
    VEN --> VET
    AUX --> V23
    GER --> VGE
```

| Caso | Estado | Selo |
|---|---|---|
| V2 V3 liberar | Tela `/liberar-pedidos` | ✅ ver [[01-Vendas-Liberacao]] |
| Corrigir a marcação | Trava com 409 `PEDIDO_IMPORTADO_MES` | ✅ |
| Acompanhar a etapa | Cartão "Etapa dos itens" | ✅ ❓ teste ponta a ponta |
| Ver a equipe | `/liberacao-equipe` | ✅ |

## 2. PCP (P1, P2, P6)

```mermaid
flowchart LR
    PCP(["PCP"])
    subgraph SIS2["Sistema app-pcp e api-pcp"]
        P1U(["P1 Abrir o pedido na Triagem do Pedido"])
        P2U(["P2 Fazer a Destinacao do Pedido, destino e quantidade por item"])
        P3U(["P3 Abrir a requisicao de compra do material do pedido"])
        P6U(["P6 Decidir o novo norte, retrabalho ou reabrir compra"])
        DEC(["Decidir divergencia do Recebimento"])
    end
    PCP --> P1U
    PCP --> P2U
    PCP --> P3U
    PCP --> P6U
    PCP --> DEC
    P1U -.->|include| P2U
```

| Caso | Estado | Selo |
|---|---|---|
| P1, P2 | `/carteira` e `/ordens-producao/novo` | ✅ ([[02-PCP-Triagem-e-Destinacao]]) |
| P3 | Setor Requisições, `POST /compras/requisicoes` | ✅ |
| P6 | Decidido, sem tela | 🔴 |
| Decidir divergência | `/decisoes-pcp`, `POST /compras/recebimentos/:id/decidir` | ✅ |

## 3. Estoque (E1 a E6)

```mermaid
flowchart LR
    ALM(["Almoxarife no setor Estoque"])
    RET(["Expedicao ou Producao"])
    subgraph SIS3["Sistema app-pcp e api-pcp"]
        E13(["E1 E3 Ver o saldo e atender pelo saldo, split e reserva"])
        E4A(["E4 Solicitar compra do restante"])
        E4B(["E4 Enviar o restante a producao"])
        E5U(["E5 Dar entrada no Estoque do item aprovado"])
        E6U(["E6 Gerar o documento de retirada e baixar o saldo"])
        CAR(["Carga inicial de lotes"])
    end
    ALM --> E13
    ALM --> E4A
    ALM --> E4B
    ALM --> E5U
    ALM --> CAR
    RET --> E6U
```

As duas opções do nó `E4` (compra ou produção) são alternativas para o restante.

| Caso | Estado | Selo |
|---|---|---|
| E1 a E3 | `/estoque-operacao/atendimento` | ✅ custo do item 🔴 |
| E4 compra | `destinoRestante` igual a `COMPRA` | ✅ |
| E4 produção | `destinoRestante` igual a `ROTEIRO` | ✅ sem baixa de matéria-prima 🔴 |
| E5 compra aprovada | `devolverAoEstoqueParciaisProntas` | ✅ |
| E5 fabricado aprovado | não vira lote | 🔴 |
| E6 retirada | decidido 14/10, sem código | 📝 🔴 |
| Carga inicial | `POST /estoque/lotes/carga-inicial` | ✅ |

## 4. Compras e fornecedor (C0 a C5, FN1)

```mermaid
flowchart LR
    COM(["Comprador no HUB"])
    GCO(["Gerente de Compras"])
    CCP(["CCP"])
    FOR(["Fornecedor"])
    subgraph SIS4["Sistema HUB, api-acos-vital e Compras CCP no MES"]
        C0U(["C0 Criar requisicao de necessidade propria"])
        C1U(["C1 Cotar e negociar"])
        C4U(["C4 Emitir a Ordem de Compra"])
        C3U(["C3 Aprovar a OC"])
        C5U(["C5 Acompanhar o prazo de entrega"])
        CLM(["Ler no MES o andamento da compra, somente leitura"])
    end
    COM --> C0U
    COM --> C1U
    COM --> C4U
    GCO -->|"OC acima de 30 mil"| C3U
    CCP --> C5U
    FOR --> C5U
    CCP --> CLM
```

| Caso | Estado | Selo |
|---|---|---|
| C0 | `POST /compras/requisicoes` no HUB; a requisição não chega ao MES, a OC dela deve chegar pela referência (N14-20) | ✅ 🔴 MES não lê a OC |
| C1, C4 | Requisições e Ordens no HUB; OC até R$ 30 mil sai livre | ✅ |
| C3 | Aprovações: Gerente de Compras aprova a OC acima de R$ 30 mil | ✅ (N14-21) |
| C5 | Follow-up no HUB | ✅ perfil CCP 🔴 |
| Ler no MES | Compras · CCP, só leitura | ✅ |

## 5. Recebimento e Qualidade de entrada (R0 a R6, Q1 a Q4)

```mermaid
flowchart LR
    DOC(["Doca, Recebimento"])
    QUA(["Qualidade"])
    subgraph SIS5["Sistema app-pcp e api-pcp"]
        R0U(["R0 Registrar a chegada com a NF"])
        R0L(["Liberar o recebimento sem OC aprovada, com motivo"])
        R12(["R1 R2 Conferir contra a NF e pesar"])
        R6U(["R6 Registrar divergencia"])
        R6R(["Recontar por outra pessoa"])
        Q1U(["Q1 Q2 Inspecionar o lote com laudo"])
        Q3U(["Q3 Abrir RNC"])
        Q4U(["Q4 Manter a parte aprovada em quarentena"])
        Q7U(["Q7 Q8 Inspecao de saida no roteiro"])
    end
    DOC --> R0U
    DOC --> R12
    DOC --> R6R
    DOC --> R0L
    QUA --> Q1U
    QUA --> Q7U
    R12 -.->|include| R6U
    Q1U -.->|extend| Q3U
    Q3U -.->|include| Q4U
```

| Caso | Estado | Selo |
|---|---|---|
| R0 chegada | `POST /compras/requisicoes/:id/chegada` exige NF | ✅ |
| Liberar sem OC | `POST …/liberar-recebimento`, permissão `compras-liberar` | ✅ |
| R1, R2, R6 | `POST /compras/recebimentos`, `/recontar` | ✅ |
| Q1 a Q4 | `/qualidade/inspecao-entrada` | ✅ ([[06-Qualidade-Entrada]]) |
| Q7, Q8 | `/qualidade/inspecao-saida` | ✅ ❓ ninguém conferiu |

## 6. Produção, Expedição e Fiscal (F1, X1 a X4, O1, O2)

```mermaid
flowchart LR
    OPE(["Operador de fabrica"])
    EXP(["Expedicao e Logistica de saida"])
    OMI(["Omie, fiscal"])
    subgraph SIS6["Sistema app-pcp e api-pcp"]
        F1U(["F1 Executar o roteiro nos setores produtivos"])
        X1U(["X1 Embalar e paletizar"])
        X3U(["X3 Consolidar a carga"])
        X4U(["X4 Registrar transporte e comprovante"])
        O1U(["O1 O2 Emitir a nota e baixar o item no pedido"])
    end
    OPE --> F1U
    EXP --> X1U
    EXP --> X3U
    EXP --> X4U
    OMI --> O1U
```

| Caso | Estado | Selo |
|---|---|---|
| F1 | Filas de Produção `/movimentacoes` | ✅ consumo de matéria-prima 🔴 |
| X1 | Paletes (10.1) | ✅ |
| X3 | Consolidar a carga (10.2) | 🔴 |
| X4 | `POST /entregas` com comprovante | 🟡 transporte 🔴 |
| O1 O2 | Lado Omie; sinalização do MES ao Omie (11.1) | ✅ 🔴 |

## O que mudou em relação ao v1

- Saiu **Registrar a compra no MES manualmente** (UC13 do v1): o `PATCH :id/compra` foi removido; o MES só espelha.
- Saíram **Pesar material**, **Etiquetar lote**, **Separar item para Expedição** e **Contagem cíclica** como casos soltos: peso entra no R2; etiqueta é geração sob demanda; separação e contagem não existem no schema (fora do fluxo 0b).
- Entraram **Criar requisição de necessidade própria** (C0), **Liberar o recebimento sem OC**, **Gerar documento de retirada** (E6) e **Carga inicial**.
- A aprovação é do Gerente de Compras para a OC acima de R$ 30 mil; até esse valor os compradores ficam livres; a Diretoria não é ator (N14-21).
