---
tags: [erp-acos-vital, av-hub, comissao]
criado: 2026-09-16
---

# av-hub — Simulador de Comissão (protótipo)

**Onde vive:** menu lateral → Operações → Experimental → Simulador de Comissão.
**Status:** protótipo local, 100% frontend, sem gravar em banco — serve para validar a lógica de negócio antes de virar contrato para o backend.

## De onde veio

Hoje o vendedor tira um pedido no Omie e depois usa uma planilha Excel manual (`CUSTO_<pedido>_desb.xlsx`) para calcular preço de venda e comissão — com uma fórmula quebrada (multiplica letra de classificação como se fosse número, gera `#VALUE!`).

## Cadeia de cálculo

1. Custo líquido do item (compra − ICMS a recuperar + IPI + ST).
2. Multiplicador de markup (embute margem desejada, despesas fixas, impostos sobre venda, provisão de comissão) → preço sugerido.
3. Margem líquida real do pedido inteiro (pós-tributos, pós-overhead) → **letra** (A a D) → **% de comissão**.

| Margem líquida real | Letra | % Comissão |
|---|---|---|
| ≤ 0% | D | 0% (prejuízo sempre zera) |
| 0–8,99% | D | 0,5% |
| 9–11,99% | C | 0,7% |
| 12–14,99% | B | 1,3% |
| ≥ 15% | A | 2% |

Corrige 4 bugs herdados da planilha original (comissão = valor × letra; célula misturando R$ com %; prejuízo não zerava comissão; ICMS do pedido baseado só no primeiro item).

## ⚠️ Ponto a esclarecer com o usuário

Isto parece ser uma frente de trabalho **paralela** à automação de comissão em Python já registrada como projeto separado (integração OMIE + Excel + dashboard Next.js). Vale confirmar se são a mesma iniciativa vista de dois ângulos, ou dois esforços concorrentes que precisam ser reconciliados.

## Ver também
- [[AV-Hub-Modulos]]
