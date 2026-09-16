---
tags: [erp-acos-vital, fluxo-operacional, fabricacao]
criado: 2026-09-16
---

# Fabricação — Grades de Piso

Sub-rota da [[Rota-Fabricacao]], a mais longa e a mais arriscada das três:

```
Compra de MP específica → Recebimento → Fabricação da grade → Envio para industrialização/galvanização externa → Retorno e validação
```

## Por que é diferente das outras duas

Tem dependência de terceiro **duas vezes** na cadeia: na compra de matéria-prima (igual à [[Rota-Revenda]]) e no meio do processo produtivo (envio para galvanização externa). Isso exige rastreamento de **lote enviado / lote retornado** — algo estruturalmente diferente de [[Fabricacao-Flanges|Flanges]] e [[Fabricacao-Chapas|Chapas]].

**Status:** não identifiquei ainda um sistema dedicado para este subfluxo. Ponto em aberto.

## Ver também
- [[Rota-Fabricacao]]
- [[Rota-Revenda]] — mesma lógica de quarentena/inspeção poderia se aplicar ao retorno da galvanização.
