---
tags: [erp-acos-vital, fluxo-operacional, fluxogramas, setores]
criado: 2026-09-16
atualizado: 2026-09-24
---

# Fluxogramas Completos — Todos os Setores, Todas as Possibilidades

> Visão em fluxograma (decisão/ramificação) de tudo que já foi modelado como sequência de conversas nos arquivos `Fluxo-*-Completo`. Aqui o foco é **quem decide o quê e pra onde o item vai** — os detalhes de payload/gatilho de cada interação continuam nos arquivos de conversa. Ver também a versão publicada como página única: [[Setores-Envolvidos-no-Fluxo]].
>
> 6 diagramas: 1 mestre (fim a fim, todos os setores) + 5 focados (Compras, Recebimento, Qualidade, Produção/OS-OP, Estoque). Cada raia (subgraph) tem uma cor própria por setor, consistente entre os 6 diagramas.
>
> O par correto de incoterm é **CIF × FOB** (ver [[Fluxo-Compras-Completo]]). Os rótulos dos nós usam texto corrido em vez de `<br/>`, mais robusto entre Obsidian e Artifact.
>
> **Escopo obrigatório do sistema (confirmado com o usuário, 17/09/2026): o sistema a construir deve implementar TODOS os passos de TODOS os 6 fluxogramas abaixo, sem exceção** — não é um subconjunto ilustrativo nem um "nice to have" além do essencial. Só a primeira caixa do fluxograma mestre (`V1 — Vendedor emite o pedido`, no Omie, sincronizado pro av-hub) é real hoje; cada nó/decisão a partir daí, em qualquer um dos 6 diagramas, é trabalho a fazer. As legendas "MES" nas cores por setor abaixo indicam **onde a funcionalidade vai morar quando construída**, não um sistema já em produção — ver ressalva igual em [[Setores-Envolvidos-no-Fluxo]].
>
> **Redesenhado em 24/09/2026 com o encaixe do Estoque e da Revenda no MES** ([[Encaixe-Estoque-Revenda-no-PCP]]). O que mudou nos diagramas 1, 3, 4, 5 e 6: o PCP escolhe a **fábrica** na Carteira (a Revenda é uma fábrica) e gera a Ordem de Produção; o **Estoque é a etapa 1 de todo roteiro** (atende do saldo com split + reserva, envia o restante); a requisição nasce no **setor Compras** do roteiro da Revenda; o beneficiamento é um setor do próprio roteiro; e o **item comprado aprovado na Qualidade volta ao Estoque** (entrada + reserva) em vez de ir direto para a Expedição. O diagrama 2 (Compras) não mudou, só a origem da requisição.

## Legenda de cores por setor

| Setor | Cor |
|---|---|
| Vendas (av-hub) | 🟢 verde-azulado |
| PCP (MES) | 🔵 azul-aço |
| Setor Compras (MES) e Compras + CCP (av-hub) | 🟣 índigo |
| Fornecedor (externo) | ⚪ cinza-quente |
| Logística de entrada | 🟠 âmbar |
| Recebimento (MES) | 🟢 verde-musgo |
| Fábrica/Beneficiamento (MES) | 🟤 terracota |
| Estoque/Almoxarife (MES) | 🔵 ciano |
| Qualidade (MES) | 🟡 ouro |
| Expedição + Logística de saída (MES) | 🟣 violeta |
| Fiscal (Omie, externo) | 🔴 rosa-queimado |

## 1. Fluxograma mestre — do pedido ao faturamento, todos os setores

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#ffffff', 'primaryTextColor': '#181c22', 'primaryBorderColor': '#33475a', 'lineColor': '#5c6570', 'fontFamily': 'Source Sans 3, sans-serif', 'fontSize': '14px', 'edgeLabelBackground': '#ffffff', 'textColor': '#181c22'}, 'flowchart': {'nodeSpacing': 45, 'rankSpacing': 60, 'padding': 14}}}%%
flowchart TD
    subgraph SEC_VENDAS[Vendas - av-hub]
        V1[Vendedor emite o pedido]
        V2{Qualidade acompanha desde o inicio?}
        V1 --> V2
    end

    subgraph SEC_PCP[PCP - MES]
        P1[Carteira: escolhe itens, quantidades e fabrica da rodada]
        P2[Ordem de Producao: uma OP por fabrica, Estoque como etapa 1]
        P6[Decide o novo norte]
        P1 --> P2
    end

    subgraph SEC_ESTOQUE[Estoque - MES]
        E1[Saldo disponivel na filial do pedido]
        E2{Saldo cobre o item?}
        E3[Split atendido: reserva no lote e conclui]
        E4{Tipo da fabrica}
        E5[Entrada do item comprado no saldo]
        E1 --> E2
        E2 -->|sim, tudo ou parte| E3
        E2 -->|nao, ou o restante| E4
        E5 --> E3
    end

    subgraph SEC_SCOMP[Setor Compras - MES]
        K1[Parcial aguarda: requisicao enviada ao av-hub]
    end

    subgraph SEC_COMPRAS[Compras e CCP - av-hub]
        C1[Cotacao e negociacao]
        C2{Acima do valor limite?}
        C3[Aprovacao da diretoria]
        C4[Emite Ordem de Compra, define CIF ou FOB]
        C5[CCP: follow-up de prazo]
        C1 --> C2
        C2 -->|sim| C3 --> C4
        C2 -->|nao| C4
        C4 --> C5
    end

    subgraph SEC_FORN[Fornecedor - externo]
        FN1[Recebe a OC]
    end

    subgraph SEC_LOG[Logistica de entrada]
        L1{CIF ou FOB?}
        L2[FOB: coleta no fornecedor]
        L3[CIF: fornecedor entrega direto]
        L4[Chegada fisica na doca]
        L1 -->|FOB| L2 --> L4
        L1 -->|CIF| L3 --> L4
    end

    subgraph SEC_RECEB[Recebimento - MES]
        R1[Confere Pedido de Venda ou Ordem de Compra]
        R2[Pesagem]
        R3{Bate com o esperado?}
        R4[Cria lote em quarentena]
        R5{Roteiro tem beneficiamento?}
        R1 --> R2 --> R3
        R3 -->|nao| R6[Divergencia]
        R3 -->|sim| R4 --> R5
    end

    subgraph SEC_PROD[Fabrica e Beneficiamento - MES]
        F1[Percorre os setores produtivos do roteiro]
        F2[Conclui a etapa produtiva]
        F1 --> F2
    end

    subgraph SEC_QUAL[Qualidade - MES]
        Q1[Inspecao]
        Q2{Aprova?}
        Q3[Abre RNC com evidencia]
        Q4[Cisao de lote]
        Q5{Origem do item}
        Q1 --> Q2
        Q2 -->|nao| Q3 --> Q4
        Q2 -->|sim| Q5
    end

    subgraph SEC_EXP[Expedicao e Logistica de saida - MES]
        X1[Embalagem e paletizacao]
        X2{Parcial ou integral?}
        X3[Consolida a carga]
        X4[Define transporte]
        X1 --> X2
        X2 -->|integral| X3 --> X4
        X2 -->|parcial| X4
    end

    subgraph SEC_FISCAL[Fiscal - Omie]
        O1[Emite nota fiscal]
        O2[Baixa o item no pedido]
        O1 --> O2
    end

    V2 -->|sim, com acompanhamento da qualidade| P1
    V2 -->|nao| P1
    P2 --> E1
    E4 -->|Fabricacao| F1
    E4 -->|Revenda| K1
    K1 --> C1
    C5 --> FN1
    FN1 --> L1
    L4 --> R1
    R6 --> P6
    P6 -->|reabre compra| K1
    R5 -->|sim| F1
    R5 -->|nao| Q1
    F2 --> Q1
    Q5 -->|comprado: volta ao Estoque| E5
    Q5 -->|fabricado| X1
    E3 --> X1
    Q4 --> P6
    P6 -->|retrabalho| F1
    X4 --> O1

    style SEC_VENDAS fill:#d9f0ec,stroke:#0f7a6b,stroke-width:2px,color:#181c22
    style SEC_PCP fill:#dce8ef,stroke:#2f6f8f,stroke-width:2px,color:#181c22
    style SEC_SCOMP fill:#e3e0f5,stroke:#5b3fae,stroke-width:2px,color:#181c22
    style SEC_COMPRAS fill:#e3e0f5,stroke:#5b3fae,stroke-width:2px,color:#181c22
    style SEC_FORN fill:#ece8e3,stroke:#8a7a63,stroke-width:2px,color:#181c22
    style SEC_LOG fill:#fbe8d9,stroke:#c9541a,stroke-width:2px,color:#181c22
    style SEC_RECEB fill:#e1eede,stroke:#5a7d3a,stroke-width:2px,color:#181c22
    style SEC_PROD fill:#f3ddd6,stroke:#a8420f,stroke-width:2px,color:#181c22
    style SEC_ESTOQUE fill:#d9eef2,stroke:#1f7a8c,stroke-width:2px,color:#181c22
    style SEC_QUAL fill:#f7edd0,stroke:#a8860f,stroke-width:2px,color:#181c22
    style SEC_EXP fill:#ece0f0,stroke:#7a3f9e,stroke-width:2px,color:#181c22
    style SEC_FISCAL fill:#f6dde4,stroke:#a83f5c,stroke-width:2px,color:#181c22

    style V1 fill:#ffffff,stroke:#0f7a6b,stroke-width:1.5px,color:#181c22
    style V2 fill:#ffffff,stroke:#0f7a6b,stroke-width:1.5px,color:#181c22
    style P1 fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style P2 fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style P6 fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style E1 fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style E2 fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style E3 fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style E4 fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style E5 fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style K1 fill:#ffffff,stroke:#5b3fae,stroke-width:1.5px,color:#181c22
    style C1 fill:#ffffff,stroke:#5b3fae,stroke-width:1.5px,color:#181c22
    style C2 fill:#ffffff,stroke:#5b3fae,stroke-width:1.5px,color:#181c22
    style C3 fill:#ffffff,stroke:#5b3fae,stroke-width:1.5px,color:#181c22
    style C4 fill:#ffffff,stroke:#5b3fae,stroke-width:1.5px,color:#181c22
    style C5 fill:#ffffff,stroke:#5b3fae,stroke-width:1.5px,color:#181c22
    style FN1 fill:#ffffff,stroke:#8a7a63,stroke-width:1.5px,color:#181c22
    style L1 fill:#ffffff,stroke:#c9541a,stroke-width:1.5px,color:#181c22
    style L2 fill:#ffffff,stroke:#c9541a,stroke-width:1.5px,color:#181c22
    style L3 fill:#ffffff,stroke:#c9541a,stroke-width:1.5px,color:#181c22
    style L4 fill:#ffffff,stroke:#c9541a,stroke-width:1.5px,color:#181c22
    style R1 fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style R2 fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style R3 fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style R4 fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style R5 fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style R6 fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style F1 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
    style F2 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
    style Q1 fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style Q2 fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style Q3 fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style Q4 fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style Q5 fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style X1 fill:#ffffff,stroke:#7a3f9e,stroke-width:1.5px,color:#181c22
    style X2 fill:#ffffff,stroke:#7a3f9e,stroke-width:1.5px,color:#181c22
    style X3 fill:#ffffff,stroke:#7a3f9e,stroke-width:1.5px,color:#181c22
    style X4 fill:#ffffff,stroke:#7a3f9e,stroke-width:1.5px,color:#181c22
    style O1 fill:#ffffff,stroke:#a83f5c,stroke-width:1.5px,color:#181c22
    style O2 fill:#ffffff,stroke:#a83f5c,stroke-width:1.5px,color:#181c22
```

## 2. Compras — cotação até a doca

**Setores:** Setor Compras (MES) · Compras e CCP (av-hub) · Fornecedor (externo) · Logística de entrada

> Desde 24/09/2026 a requisição (nó A) nasce da **entrada do parcial no setor Compras** do roteiro da fábrica Revenda, não de uma ação manual do PCP. O parcial fica parado ali até o recebimento.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#ffffff', 'primaryTextColor': '#181c22', 'primaryBorderColor': '#33475a', 'lineColor': '#5c6570', 'fontFamily': 'Source Sans 3, sans-serif', 'fontSize': '14px', 'edgeLabelBackground': '#ffffff', 'textColor': '#181c22'}, 'flowchart': {'nodeSpacing': 40, 'rankSpacing': 55, 'padding': 12}}}%%
flowchart TD
    subgraph SEC_PCP[Setor Compras - MES]
        A[Entrada do parcial gera a requisicao]
    end

    subgraph SEC_COMPRAS[Compras e CCP - av-hub]
        B[Comprador escolhe fornecedor e negocia]
        C{Valor acima de R$ 30.000?}
        D[Aprovacao da diretoria]
        E[Emite Ordem de Compra, define CIF ou FOB]
        H[CCP acompanha prazo]
        I{Fornecedor confirma a chegada?}
        B --> C
        C -->|sim| D
        C -->|nao| E
        D -->|aprovado| E
        D -->|reprovado| B
        E --> H
        H --> I
        I -->|atraso, sem estado em transito verificavel| H
    end

    subgraph SEC_FORN[Fornecedor - externo]
        G[Recebe a OC]
    end

    subgraph SEC_LOG[Logistica de entrada]
        J{CIF ou FOB?}
        K[FOB: busca no fornecedor]
        L[CIF: fornecedor despacha e paga o frete]
        M[Chegada fisica na doca]
        J -->|FOB| K --> M
        J -->|CIF| L --> M
    end

    A --> B
    E --> G
    I -->|confirmado| J

    style SEC_PCP fill:#e3e0f5,stroke:#5b3fae,stroke-width:2px,color:#181c22
    style SEC_COMPRAS fill:#e3e0f5,stroke:#5b3fae,stroke-width:2px,color:#181c22
    style SEC_FORN fill:#ece8e3,stroke:#8a7a63,stroke-width:2px,color:#181c22
    style SEC_LOG fill:#fbe8d9,stroke:#c9541a,stroke-width:2px,color:#181c22

    style A fill:#ffffff,stroke:#5b3fae,stroke-width:1.5px,color:#181c22
    style B fill:#ffffff,stroke:#5b3fae,stroke-width:1.5px,color:#181c22
    style C fill:#ffffff,stroke:#5b3fae,stroke-width:1.5px,color:#181c22
    style D fill:#ffffff,stroke:#5b3fae,stroke-width:1.5px,color:#181c22
    style E fill:#ffffff,stroke:#5b3fae,stroke-width:1.5px,color:#181c22
    style H fill:#ffffff,stroke:#5b3fae,stroke-width:1.5px,color:#181c22
    style I fill:#ffffff,stroke:#5b3fae,stroke-width:1.5px,color:#181c22
    style G fill:#ffffff,stroke:#8a7a63,stroke-width:1.5px,color:#181c22
    style J fill:#ffffff,stroke:#c9541a,stroke-width:1.5px,color:#181c22
    style K fill:#ffffff,stroke:#c9541a,stroke-width:1.5px,color:#181c22
    style L fill:#ffffff,stroke:#c9541a,stroke-width:1.5px,color:#181c22
    style M fill:#ffffff,stroke:#c9541a,stroke-width:1.5px,color:#181c22
```

## 3. Recebimento — conferência e roteamento

**Setores:** Recebimento (MES) · Fábrica e Beneficiamento (MES) · PCP (MES)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#ffffff', 'primaryTextColor': '#181c22', 'primaryBorderColor': '#33475a', 'lineColor': '#5c6570', 'fontFamily': 'Source Sans 3, sans-serif', 'fontSize': '14px', 'edgeLabelBackground': '#ffffff', 'textColor': '#181c22'}, 'flowchart': {'nodeSpacing': 40, 'rankSpacing': 55, 'padding': 12}}}%%
flowchart TD
    subgraph SEC_RECEB[Recebimento - MES]
        A[Material chega na doca]
        B[Localiza referencia: Pedido de Venda ou Ordem de Compra]
        C[Conferencia quantitativa]
        D[Pesagem: peso teorico x tolerancia]
        E{Confere com o esperado?}
        F[Abre divergencia]
        H[Cria lote com quantidade real]
        J[Lote nasce em quarentena]
        K[Etiquetagem]
        L[Associa nota fiscal de entrada]
        S[Libera o parcial parado no setor Compras]
        M{Roteiro tem beneficiamento?}
        N[Libera para Qualidade]
        A --> B --> C --> D --> E
        E -->|nao| F
        E -->|sim| H
        H --> J --> K --> L --> S --> M
        M -->|nao| N
    end

    subgraph SEC_PROD[Fabrica e Beneficiamento - MES]
        O[Setor de beneficiamento do roteiro da Revenda]
    end

    subgraph SEC_PCP[PCP - MES]
        Gd{PCP decide}
        I[Nova requisicao de compra]
    end

    F --> Gd
    Gd -->|aceita parcial| H
    Gd -->|reabre compra| I
    M -->|sim| O

    style SEC_RECEB fill:#e1eede,stroke:#5a7d3a,stroke-width:2px,color:#181c22
    style SEC_PROD fill:#f3ddd6,stroke:#a8420f,stroke-width:2px,color:#181c22
    style SEC_PCP fill:#dce8ef,stroke:#2f6f8f,stroke-width:2px,color:#181c22

    style A fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style B fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style C fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style D fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style E fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style F fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style H fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style J fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style K fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style L fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style S fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style M fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style N fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style O fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
    style Gd fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style I fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
```

## 4. Qualidade — das duas filas até aprovação/reprovação

**Setores:** Vendas (av-hub) · origem interna (MES) · Qualidade (MES) · Estoque (MES) · Fiscal (Omie)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#ffffff', 'primaryTextColor': '#181c22', 'primaryBorderColor': '#33475a', 'lineColor': '#5c6570', 'fontFamily': 'Source Sans 3, sans-serif', 'fontSize': '14px', 'edgeLabelBackground': '#ffffff', 'textColor': '#181c22'}, 'flowchart': {'nodeSpacing': 40, 'rankSpacing': 55, 'padding': 12}}}%%
flowchart TD
    subgraph SEC_VENDAS[Vendas - av-hub]
        A1[Vendedor marca acompanhamento desde o inicio]
    end

    subgraph SEC_ORIGEM[Recebimento ou Producao - MES]
        A2[Item liberado para inspecao final]
    end

    subgraph SEC_QUAL[Qualidade - MES]
        B[Fila de inspecao de processo]
        C[Fila de inspecao final]
        D[Executa a inspecao]
        E{Laudo preenchido?}
        F{Aprova?}
        G[Lote sai da quarentena]
        H{Origem do item}
        I2[Item fabricado segue para Expedicao]
        J[Anexa motivo e evidencia]
        K[Cisao de lote: aprovado segue, reprovado congela]
        L[Volta para o PCP decidir novo norte]
        B --> D
        C --> D
        D --> E
        E -->|nao| D
        E -->|sim| F
        F -->|sim| G --> H
        H -->|fabricado| I2
        F -->|nao| J --> K --> L
    end

    subgraph SEC_ESTOQUE[Estoque - MES]
        I1[Item comprado volta ao Estoque: entrada, reserva e conclusao]
    end

    subgraph SEC_FISCAL[Fiscal - Omie]
        M[Sinaliza RNC para o Omie]
        N[Omie emite nota de devolucao]
        O[Fecha a RNC]
        M --> N --> O
    end

    A1 --> B
    A2 --> C
    H -->|comprado| I1
    K --> M

    style SEC_VENDAS fill:#d9f0ec,stroke:#0f7a6b,stroke-width:2px,color:#181c22
    style SEC_ORIGEM fill:#e7ebee,stroke:#5c6570,stroke-width:2px,color:#181c22
    style SEC_QUAL fill:#f7edd0,stroke:#a8860f,stroke-width:2px,color:#181c22
    style SEC_ESTOQUE fill:#d9eef2,stroke:#1f7a8c,stroke-width:2px,color:#181c22
    style SEC_FISCAL fill:#f6dde4,stroke:#a83f5c,stroke-width:2px,color:#181c22

    style A1 fill:#ffffff,stroke:#0f7a6b,stroke-width:1.5px,color:#181c22
    style A2 fill:#ffffff,stroke:#5c6570,stroke-width:1.5px,color:#181c22
    style B fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style C fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style D fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style E fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style F fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style G fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style H fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style I2 fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style J fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style K fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style L fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style I1 fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style M fill:#ffffff,stroke:#a83f5c,stroke-width:1.5px,color:#181c22
    style N fill:#ffffff,stroke:#a83f5c,stroke-width:1.5px,color:#181c22
    style O fill:#ffffff,stroke:#a83f5c,stroke-width:1.5px,color:#181c22
```

## 5. Produção — OS/OP como máquina de estados (`ItemParcial`)

**Setores:** Estoque (etapa 1) e Fábrica e Beneficiamento (MES) — único subfluxo já implementado em produção, não apenas desenhado. A etapa 1 no setor Estoque é o que entra com o encaixe de 24/09/2026.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#ffffff', 'primaryTextColor': '#181c22', 'primaryBorderColor': '#33475a', 'lineColor': '#5c6570', 'fontFamily': 'Source Sans 3, sans-serif', 'fontSize': '14px', 'edgeLabelBackground': '#ffffff', 'textColor': '#181c22'}, 'flowchart': {'nodeSpacing': 40, 'rankSpacing': 55, 'padding': 12}}}%%
flowchart TD
    subgraph SEC_EST[Etapa 1 - setor Estoque - MES]
        S0([CRIADO no setor Estoque])
        SE{Saldo disponivel na filial?}
        SR[Split atendido: Reserva no lote]
        SC([CONCLUIDO: segue para a entrega])
        S0 --> SE
        SE -->|sim, tudo ou parte| SR --> SC
    end

    subgraph SEC_PROD[Setores seguintes do roteiro - MES]
        S4[EM_TRANSITO]
        S1[RECEBIDO]
        S2[EM_ANDAMENTO]
        S3{Acao do setor}
        S5[PAUSADO]
        S6[RETRABALHO]
        S7[Divide em multiplos ItemParcial]
        S8[Linha atual: CANCELADO definitivo]
        S9[Nasce nova linha EM_TRANSITO, ligada por idDevolvidoDe]
        S10([CONCLUIDO])
        S11[Libera para Qualidade]
        S12[Consolidar de volta]
        S4 --> S1
        S1 --> S2
        S2 --> S3
        S3 -->|mover para o proximo setor| S4
        S3 -->|pausar| S5
        S5 -->|retomar| S2
        S3 -->|retrabalho| S6
        S6 --> S2
        S3 -->|split| S7
        S7 --> S1
        S3 -->|devolver ao setor anterior| S8
        S8 --> S9
        S9 --> S1
        S3 -->|concluir, so no ultimo setor| S10
        S10 --> S11
        S7 -.depois, se fizer sentido.-> S12
    end

    SE -->|restante, ou saldo zero| S4

    style SEC_EST fill:#d9eef2,stroke:#1f7a8c,stroke-width:2px,color:#181c22
    style SEC_PROD fill:#f3ddd6,stroke:#a8420f,stroke-width:2px,color:#181c22

    style S0 fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style SE fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style SR fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style SC fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style S1 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
    style S2 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
    style S3 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
    style S4 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
    style S5 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
    style S6 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
    style S7 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
    style S8 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
    style S9 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
    style S10 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
    style S11 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
    style S12 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
```

## 6. Estoque — setor da etapa 1, entrada do comprado e operação contínua

**Setores:** PCP (MES) · Qualidade (MES) · Estoque/Almoxarife (MES)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#ffffff', 'primaryTextColor': '#181c22', 'primaryBorderColor': '#33475a', 'lineColor': '#5c6570', 'fontFamily': 'Source Sans 3, sans-serif', 'fontSize': '14px', 'edgeLabelBackground': '#ffffff', 'textColor': '#181c22'}, 'flowchart': {'nodeSpacing': 40, 'rankSpacing': 55, 'padding': 12}}}%%
flowchart TD
    subgraph SEC_PCP[PCP - MES]
        A[Carteira: escolhe fabrica e quantidade da rodada]
        B[Ordem de Producao com Estoque na etapa 1]
        I[Requisicao preventiva de compra]
        A --> B
    end

    subgraph SEC_QUAL[Qualidade - MES]
        Q[Aprova o lote do item comprado]
    end

    subgraph SEC_ESTOQUE[Estoque / Almoxarife - MES]
        D[Parcial chega na etapa 1]
        C{Saldo disponivel na filial do pedido?}
        E[Split atendido: reserva ATIVA no lote]
        F[Conclui o split e separa]
        G[Restante segue o roteiro: setores produtivos ou setor Compras]
        P[Entrada do item comprado no saldo]
        X[Segue para a entrega, reserva vira CONSUMIDA]
        D --> C
        C -->|sim, tudo ou parte| E --> F --> X
        C -->|nao, ou o restante| G
        P --> E

        subgraph OPERACAO[Operacao continua do deposito]
            J[Movimentacao entre warehouses]
            K[Contagem ciclica]
            K --> L{Diverge do sistema?}
            L -->|sim| M[Ajuste de saldo com motivo obrigatorio]
            K --> N{Saldo cruza o ponto de pedido?}
        end
    end

    B --> D
    Q --> P
    N -->|sim| I

    style SEC_PCP fill:#dce8ef,stroke:#2f6f8f,stroke-width:2px,color:#181c22
    style SEC_QUAL fill:#f7edd0,stroke:#a8860f,stroke-width:2px,color:#181c22
    style SEC_ESTOQUE fill:#d9eef2,stroke:#1f7a8c,stroke-width:2px,color:#181c22
    style OPERACAO fill:#eef0f2,stroke:#8d95a1,stroke-width:1.5px,color:#181c22

    style A fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style B fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style I fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style Q fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style D fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style C fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style E fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style F fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style G fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style P fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style X fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style J fill:#ffffff,stroke:#8d95a1,stroke-width:1.5px,color:#181c22
    style K fill:#ffffff,stroke:#8d95a1,stroke-width:1.5px,color:#181c22
    style L fill:#ffffff,stroke:#8d95a1,stroke-width:1.5px,color:#181c22
    style M fill:#ffffff,stroke:#8d95a1,stroke-width:1.5px,color:#181c22
    style N fill:#ffffff,stroke:#8d95a1,stroke-width:1.5px,color:#181c22
```

## Ver também
- [[Encaixe-Estoque-Revenda-no-PCP]] — o encaixe que redesenhou estes fluxogramas em 24/09/2026.
- [[Setores-Envolvidos-no-Fluxo]]
- [[Modelo-Destinacao-Item]]
- [[Fluxo-Detalhado-Pedido-Item]]
- [[Fluxo-Compras-Completo]], [[Fluxo-Recebimento-Completo]], [[Fluxo-Qualidade-Completo]], [[Fluxo-Producao-OS-OP-Completo]], [[Fluxo-Expedicao-Faturamento-Completo]], [[Fluxo-Estoque-Completo]] — a versão conversa-por-conversa de cada um destes fluxogramas.
