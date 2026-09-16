---
tags: [erp-acos-vital, fluxo-operacional, fluxogramas, setores]
criado: 2026-09-16
atualizado: 2026-09-16 (corrigido CIF/FOB, cores por setor, texto colado corrigido)
---

# Fluxogramas Completos — Todos os Setores, Todas as Possibilidades

> Visão em fluxograma (decisão/ramificação) de tudo que já foi modelado como sequência de conversas nos arquivos `Fluxo-*-Completo`. Aqui o foco é **quem decide o quê e pra onde o item vai** — os detalhes de payload/gatilho de cada interação continuam nos arquivos de conversa. Ver também a versão publicada como página única: [[Setores-Envolvidos-no-Fluxo]].
>
> 6 diagramas: 1 mestre (fim a fim, todos os setores) + 5 focados (Compras, Recebimento, Qualidade, Produção/OS-OP, Estoque). Cada raia (subgraph) tem uma cor própria por setor, consistente entre os 6 diagramas.
>
> ⚠️ **Correções (16/09):** o par correto de incoterm é **CIF × FOB**, não "coleta própria ou frete CIF" como estava antes (ver conversa C4 em [[Fluxo-Compras-Completo]]). E o `<br/>` usado nos rótulos dos nós não vira quebra de linha em todo renderizador mermaid — trocado por texto corrido, mais robusto entre Obsidian e Artifact.

## Legenda de cores por setor

| Setor | Cor |
|---|---|
| Vendas (av-hub) | 🟢 verde-azulado |
| PCP (MES) | 🔵 azul-aço |
| Compras + CCP (av-hub) | 🟣 índigo |
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
        P1[PCP classifica o item]
        P2{Natureza do item}
        P3{Disponibilidade}
        P4[Gera requisicao de compra]
        P5[Abre OS ou OP]
        P6[Decide o novo norte]
        P1 --> P2
        P2 -->|Revenda| P3
        P2 -->|Fabricacao propria| P3
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
        R5{Item acabado?}
        R1 --> R2 --> R3
        R3 -->|nao| R6[Divergencia]
        R3 -->|sim| R4 --> R5
    end

    subgraph SEC_PROD[Fabrica e Beneficiamento - MES]
        F1[Abre ItemParcial]
        F2[Percorre o roteiro setor a setor]
        F3[Conclui no ultimo setor]
        F1 --> F2 --> F3
    end

    subgraph SEC_ESTOQUE[Estoque - MES]
        E1[Verifica saldo no warehouse]
        E2[Cria reserva]
        E3[Separacao fisica]
        E1 --> E2 --> E3
    end

    subgraph SEC_QUAL[Qualidade - MES]
        Q1[Inspecao]
        Q2{Aprova?}
        Q3[Abre RNC com evidencia]
        Q4[Cisao de lote]
        Q1 --> Q2
        Q2 -->|nao| Q3 --> Q4
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

    V2 -->|sim| Q1
    V2 -->|nao| P1
    P3 -->|pronto em estoque| E1
    P3 -->|materia-prima em estoque| P5
    P3 -->|sem estoque| P4
    P4 --> C1
    C5 --> FN1
    FN1 --> L1
    L4 --> R1
    R6 --> P6
    P6 -->|reabre compra| P4
    R5 -->|sim| Q1
    R5 -->|nao| P5
    P5 --> F1
    F3 --> Q1
    E3 --> Q1
    Q2 -->|sim| X1
    Q3 --> Q4
    Q4 --> P6
    P6 -->|retrabalho ou nova OS/OP| F1
    X4 --> O1

    style SEC_VENDAS fill:#d9f0ec,stroke:#0f7a6b,stroke-width:2px,color:#181c22
    style SEC_PCP fill:#dce8ef,stroke:#2f6f8f,stroke-width:2px,color:#181c22
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
    style P3 fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style P4 fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style P5 fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style P6 fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
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
    style F3 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
    style E1 fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style E2 fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style E3 fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style Q1 fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style Q2 fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style Q3 fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style Q4 fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style X1 fill:#ffffff,stroke:#7a3f9e,stroke-width:1.5px,color:#181c22
    style X2 fill:#ffffff,stroke:#7a3f9e,stroke-width:1.5px,color:#181c22
    style X3 fill:#ffffff,stroke:#7a3f9e,stroke-width:1.5px,color:#181c22
    style X4 fill:#ffffff,stroke:#7a3f9e,stroke-width:1.5px,color:#181c22
    style O1 fill:#ffffff,stroke:#a83f5c,stroke-width:1.5px,color:#181c22
    style O2 fill:#ffffff,stroke:#a83f5c,stroke-width:1.5px,color:#181c22
```

## 2. Compras — cotação até a doca

**Setores:** PCP (MES) · Compras e CCP (av-hub) · Fornecedor (externo) · Logística de entrada

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#ffffff', 'primaryTextColor': '#181c22', 'primaryBorderColor': '#33475a', 'lineColor': '#5c6570', 'fontFamily': 'Source Sans 3, sans-serif', 'fontSize': '14px', 'edgeLabelBackground': '#ffffff', 'textColor': '#181c22'}, 'flowchart': {'nodeSpacing': 40, 'rankSpacing': 55, 'padding': 12}}}%%
flowchart TD
    subgraph SEC_PCP[PCP - MES]
        A[PCP gera requisicao]
    end

    subgraph SEC_COMPRAS[Compras e CCP - av-hub]
        B[Comprador escolhe fornecedor e negocia]
        C{Valor acima do limite definido?}
        D[Aprovacao da diretoria]
        E[Emite Ordem de Compra, define CIF ou FOB]
        H[CCP acompanha prazo]
        I{Fornecedor confirma a chegada?}
        B --> C
        C -->|sim, regra ainda a definir| D
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

    style SEC_PCP fill:#dce8ef,stroke:#2f6f8f,stroke-width:2px,color:#181c22
    style SEC_COMPRAS fill:#e3e0f5,stroke:#5b3fae,stroke-width:2px,color:#181c22
    style SEC_FORN fill:#ece8e3,stroke:#8a7a63,stroke-width:2px,color:#181c22
    style SEC_LOG fill:#fbe8d9,stroke:#c9541a,stroke-width:2px,color:#181c22

    style A fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
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

**Setores:** Recebimento (MES) · PCP (MES)

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
        M{Item acabado?}
        N[Libera para Qualidade]
        A --> B --> C --> D --> E
        E -->|nao| F
        E -->|sim| H
        H --> J --> K --> L --> M
        M -->|sim| N
    end

    subgraph SEC_PCP[PCP - MES]
        Gd{PCP decide}
        I[Nova requisicao de compra]
        O[Volta para o PCP abrir OS ou OP]
    end

    F --> Gd
    Gd -->|aceita parcial| H
    Gd -->|reabre compra| I
    M -->|nao| O

    style SEC_RECEB fill:#e1eede,stroke:#5a7d3a,stroke-width:2px,color:#181c22
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
    style M fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style N fill:#ffffff,stroke:#5a7d3a,stroke-width:1.5px,color:#181c22
    style Gd fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style I fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style O fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
```

## 4. Qualidade — das duas filas até aprovação/reprovação

**Setores:** Vendas (av-hub) · origem interna (MES) · Qualidade (MES) · Fiscal (Omie)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#ffffff', 'primaryTextColor': '#181c22', 'primaryBorderColor': '#33475a', 'lineColor': '#5c6570', 'fontFamily': 'Source Sans 3, sans-serif', 'fontSize': '14px', 'edgeLabelBackground': '#ffffff', 'textColor': '#181c22'}, 'flowchart': {'nodeSpacing': 40, 'rankSpacing': 55, 'padding': 12}}}%%
flowchart TD
    subgraph SEC_VENDAS[Vendas - av-hub]
        A1[Vendedor marca acompanhamento desde o inicio]
    end

    subgraph SEC_ORIGEM[Recebimento, Producao ou Estoque - MES]
        A2[Item liberado para inspecao final]
    end

    subgraph SEC_QUAL[Qualidade - MES]
        B[Fila de inspecao de processo]
        C[Fila de inspecao final]
        D[Executa a inspecao]
        E{Laudo preenchido?}
        F{Aprova?}
        G[Lote sai da quarentena]
        H[Confirma reserva, se houver]
        I[Segue para Expedicao]
        J[Anexa motivo e evidencia]
        K[Cisao de lote: aprovado segue, reprovado congela]
        L[Volta para o PCP decidir novo norte]
        B --> D
        C --> D
        D --> E
        E -->|nao| D
        E -->|sim| F
        F -->|sim| G --> H --> I
        F -->|nao| J --> K --> L
    end

    subgraph SEC_FISCAL[Fiscal - Omie]
        M[Sinaliza RNC para o Omie]
        N[Omie emite nota de devolucao]
        O[Fecha a RNC]
        M --> N --> O
    end

    A1 --> B
    A2 --> C
    K --> M

    style SEC_VENDAS fill:#d9f0ec,stroke:#0f7a6b,stroke-width:2px,color:#181c22
    style SEC_ORIGEM fill:#e7ebee,stroke:#5c6570,stroke-width:2px,color:#181c22
    style SEC_QUAL fill:#f7edd0,stroke:#a8860f,stroke-width:2px,color:#181c22
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
    style I fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style J fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style K fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style L fill:#ffffff,stroke:#a8860f,stroke-width:1.5px,color:#181c22
    style M fill:#ffffff,stroke:#a83f5c,stroke-width:1.5px,color:#181c22
    style N fill:#ffffff,stroke:#a83f5c,stroke-width:1.5px,color:#181c22
    style O fill:#ffffff,stroke:#a83f5c,stroke-width:1.5px,color:#181c22
```

## 5. Produção — OS/OP como máquina de estados (`ItemParcial`)

**Setor:** Fábrica e Beneficiamento (MES) — único subfluxo já implementado em produção, não apenas desenhado.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#ffffff', 'primaryTextColor': '#181c22', 'primaryBorderColor': '#33475a', 'lineColor': '#5c6570', 'fontFamily': 'Source Sans 3, sans-serif', 'fontSize': '14px', 'edgeLabelBackground': '#ffffff', 'textColor': '#181c22'}, 'flowchart': {'nodeSpacing': 40, 'rankSpacing': 55, 'padding': 12}}}%%
flowchart TD
    subgraph SEC_PROD[Fabrica e Beneficiamento - MES]
        S0([CRIADO]) --> S1[RECEBIDO]
        S1 --> S2[EM_ANDAMENTO]
        S2 --> S3{Acao do setor}
        S3 -->|mover para o proximo setor| S4[EM_TRANSITO]
        S4 --> S1
        S3 -->|pausar| S5[PAUSADO]
        S5 -->|retomar| S2
        S3 -->|retrabalho| S6[RETRABALHO]
        S6 --> S2
        S3 -->|split| S7[Divide em multiplos ItemParcial]
        S7 --> S1
        S3 -->|devolver ao setor anterior| S8[Linha atual: CANCELADO definitivo]
        S8 --> S9[Nasce nova linha EM_TRANSITO, ligada por idDevolvidoDe]
        S9 --> S1
        S3 -->|concluir, so no ultimo setor| S10([CONCLUIDO])
        S10 --> S11[Libera para Qualidade]
        S7 -.depois, se fizer sentido.-> S12[Consolidar de volta]
    end

    style SEC_PROD fill:#f3ddd6,stroke:#a8420f,stroke-width:2px,color:#181c22

    style S0 fill:#ffffff,stroke:#a8420f,stroke-width:1.5px,color:#181c22
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

## 6. Estoque — matriz de destinação + operação contínua

**Setores:** PCP (MES) · Estoque/Almoxarife (MES)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#ffffff', 'primaryTextColor': '#181c22', 'primaryBorderColor': '#33475a', 'lineColor': '#5c6570', 'fontFamily': 'Source Sans 3, sans-serif', 'fontSize': '14px', 'edgeLabelBackground': '#ffffff', 'textColor': '#181c22'}, 'flowchart': {'nodeSpacing': 40, 'rankSpacing': 55, 'padding': 12}}}%%
flowchart TD
    subgraph SEC_PCP[PCP - MES]
        A[PCP avalia o item]
        B{Natureza: Revenda ou Fabricacao}
        C{Disponibilidade no warehouse}
        H[PCP abre OS/OP direto]
        I[PCP gera requisicao de compra]
        A --> B --> C
    end

    subgraph SEC_ESTOQUE[Estoque / Almoxarife - MES]
        D[Verifica saldo]
        E[Cria reserva]
        F[Separacao fisica]
        G[Segue para Qualidade]
        D --> E --> F --> G

        subgraph OPERACAO[Operacao continua do deposito]
            J[Movimentacao entre warehouses]
            K[Contagem ciclica]
            K --> L{Diverge do sistema?}
            L -->|sim| M[Ajuste de saldo com motivo obrigatorio]
            K --> N{Saldo cruza o ponto de pedido?}
        end
    end

    C -->|pronto em estoque| D
    C -->|materia-prima em estoque| H
    C -->|sem estoque| I
    N -->|sim| I

    style SEC_PCP fill:#dce8ef,stroke:#2f6f8f,stroke-width:2px,color:#181c22
    style SEC_ESTOQUE fill:#d9eef2,stroke:#1f7a8c,stroke-width:2px,color:#181c22
    style OPERACAO fill:#eef0f2,stroke:#8d95a1,stroke-width:1.5px,color:#181c22

    style A fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style B fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style C fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style H fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style I fill:#ffffff,stroke:#2f6f8f,stroke-width:1.5px,color:#181c22
    style D fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style E fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style F fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style G fill:#ffffff,stroke:#1f7a8c,stroke-width:1.5px,color:#181c22
    style J fill:#ffffff,stroke:#8d95a1,stroke-width:1.5px,color:#181c22
    style K fill:#ffffff,stroke:#8d95a1,stroke-width:1.5px,color:#181c22
    style L fill:#ffffff,stroke:#8d95a1,stroke-width:1.5px,color:#181c22
    style M fill:#ffffff,stroke:#8d95a1,stroke-width:1.5px,color:#181c22
    style N fill:#ffffff,stroke:#8d95a1,stroke-width:1.5px,color:#181c22
```

## Ver também
- [[Setores-Envolvidos-no-Fluxo]]
- [[Modelo-Destinacao-Item]]
- [[Fluxo-Detalhado-Pedido-Item]]
- [[Fluxo-Compras-Completo]], [[Fluxo-Recebimento-Completo]], [[Fluxo-Qualidade-Completo]], [[Fluxo-Producao-OS-OP-Completo]], [[Fluxo-Expedicao-Faturamento-Completo]], [[Fluxo-Estoque-Completo]] — a versão conversa-por-conversa de cada um destes fluxogramas.
