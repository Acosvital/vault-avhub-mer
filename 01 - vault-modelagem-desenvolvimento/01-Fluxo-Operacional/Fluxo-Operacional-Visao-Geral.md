---
tags: [erp-acos-vital, fluxo-operacional]
criado: 2026-09-16
---

# Fluxo Operacional — Visão Geral

Mapa macro do processo operacional da Aços Vital, da venda até a expedição. Estrutura-se em **quatro fases principais**: [[Entrada-Comercial|entrada comercial]], [[PCP-Carteira|triagem no PCP]], rotas de atendimento ([[Rota-Estoque|estoque]], [[Rota-Revenda|revenda]] ou [[Rota-Fabricacao|fabricação]]) e [[Faturamento-Expedicao|faturamento/expedição]].

> **Confirmado com o usuário (17/09/2026):** só a fase 1 (entrada comercial — pedido no Omie, sincronizado pro av-hub) está em produção hoje. A partir da fase 2 (triagem no PCP) em diante, **nada existe em sistema nenhum** — é o processo-alvo que o projeto de ERP unificado precisa construir. Ver ressalva igual, com mais detalhe, em [[Fluxo-Detalhado-Pedido-Item]].

## Diagrama (visão macro/conceitual)

> Este diagrama é a visão **macro/conceitual** do fluxo — três categorias de destinação de item. Existe uma segunda visão, **operacional/detalhada, item a item** (com PCP verificando estoque como primeiro passo dentro de Revenda/Fabricação, emissão de OS/OP, fluxo de Compras/Recebimento/Qualidade passo a passo) em [[Fluxo-Detalhado-Pedido-Item]] — as duas coexistem deliberadamente como modelos complementares, não uma substitui a outra. Chapas **não** é Fabricação, é beneficiamento de Revenda — ver [[Fabricacao-Chapas]].
>
> **Reconciliação formal dos dois modelos:** ver [[Modelo-Destinacao-Item]] — "Estoque" aqui não é um quarto ramo do mesmo tipo que Revenda/Fabricação; é o cruzamento "pronto em estoque" dentro de qualquer uma das duas outras categorias.

```
[Vendas: Pedido no Omie]
          │
          ▼
[Hub / Tela de Pedidos]
          │
          ▼
[PCP: Geração da Carteira]
          │
   ┌──────┴──────────────────────┬────────────────────────┐
   ▼                             ▼                        ▼
[ESTOQUE]                    [REVENDA]              [FABRICAÇÃO]
Conferência                  Compras (OC)           Linhas de produção próprias
Separação                    Follow-up (CCP)        (Flanges hoje; Grade de Piso,
Identificação                Recebimento/Quarentena  Chapa Expandida, Caldeiraria
                             Inspeção de Qualidade    etc. conforme cadastradas —
                             Beneficiamento (corte     ver Rota-Fabricacao)
                             de chapa sob medida,
                             quando aplicável)
   │                             │                        │
   └──────────────────────┬──────┴────────────────────────┘
                          ▼
            [Faturamento: Parcial ou Integral]
                          │
                          ▼
                     [Logística]
```

## As quatro fases

1. **[[Entrada-Comercial|Entrada e Triagem Comercial]]** — vendedor cadastra no Omie, o Hub captura via API.
2. **[[PCP-Carteira|Gestão de Carteira (PCP)]]** — abertura dos itens e classificação por rota operacional.
3. **Roteamento e processamento por categoria** — [[Rota-Estoque]], [[Rota-Revenda]], [[Rota-Fabricacao]].
4. **[[Faturamento-Expedicao|Faturamento e Expedição]]** — parcial ou integral, depois logística.

## Observação estrutural central

A entidade central do fluxo não é "o pedido" como bloco monolítico, mas o **item do pedido dentro da carteira**: é ele quem carrega a classificação de rota e o status individual — a agregação desses status por pedido é que decide entre faturamento parcial ou integral. Essa mesma lógica de consolidação bottom-up aparece em outro contexto no [[AV-Hub-Vendas-Reconciliacao|Waterfall de dedução da Venda Líquida]].

## Ver também
- [[Modelo-Destinacao-Item]] — reconciliação formal entre este diagrama e o fluxo detalhado.
- [[Fluxo-Detalhado-Pedido-Item]] — o mesmo fluxo, no nível operacional de item.
- [[PRD-Estoque-Visao-Geral]] — cobre os ramos Estoque e Revenda deste fluxo.
- [[App-PCP-Visao-Geral]] — cobre o ramo Fabricação → Flanges.
- [[Decisoes-Chave-ERP]]
