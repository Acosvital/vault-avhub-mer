---
tags: [erp-acos-vital, fluxo-operacional]
criado: 2026-09-16
---

# 3a. Rota Estoque (Pronta Entrega)

- Separação física dos produtos em almoxarifado.
- Conferência e identificação de lote/etiquetagem.
- Liberação imediata para faturamento.

## Perfil de risco

Rota **linear e curta**, com menor superfície de falha — provavelmente a mais rápida e previsível para SLA, comparada a [[Rota-Revenda]] e [[Rota-Fabricacao]].

## Onde isso é implementado (ou planejado)

O [[PRD-Estoque-Visao-Geral|PRD do Estoque]] cobre exatamente esta rota: separação (`ordem_separacao`/`item_separacao`), conferência e etiquetagem por código de barras/QR. Ver [[Estoque-Modelo-Dados]].

## Ver também
- [[Fluxo-Operacional-Visao-Geral]]
- [[Faturamento-Expedicao]]
