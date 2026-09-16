---
tags: [erp-acos-vital, fluxo-operacional]
criado: 2026-09-16
---

# Fluxo Operacional — Visão Geral

Mapa macro do processo operacional da Aços Vital, da venda até a expedição. Estrutura-se em **quatro fases principais**: [[Entrada-Comercial|entrada comercial]], [[PCP-Carteira|triagem no PCP]], rotas de atendimento ([[Rota-Estoque|estoque]], [[Rota-Revenda|revenda]] ou [[Rota-Fabricacao|fabricação]]) e [[Faturamento-Expedicao|faturamento/expedição]].

## Diagrama

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
Conferência                  Compras (OC)           ├─ Flanges (Sistema Próprio)
Separação                    Follow-up (CCP)        ├─ Chapas (Corte)
Identificação                Logística/Coleta       └─ Grades de Piso:
                             Recebimento/Quarentena     (MP → Fabr. → Beneficiamento externo)
                             Inspeção de Qualidade
                             Entrada no Estoque
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
- [[PRD-Estoque-Visao-Geral]] — cobre os ramos Estoque e Revenda deste fluxo.
- [[App-PCP-Visao-Geral]] — cobre o ramo Fabricação → Flanges.
- [[Decisoes-Chave-ERP]]
