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

Tem dependência de terceiro **duas vezes** na cadeia: na compra de matéria-prima (igual à [[Rota-Revenda]]) e no meio do processo produtivo (envio para galvanização externa). Isso exige rastreamento de **lote enviado / lote retornado** — algo estruturalmente diferente de [[Fabricacao-Flanges|Flanges]] (a outra linha de fabricação detalhada até agora; corte de chapa **não** é fabricação, é beneficiamento de Revenda — ver [[Fabricacao-Chapas]]).

**Status:** Grades de Piso entra no **MES Aços Vital**, junto com Flanges (Chapas **fica de fora** — corte de chapa é beneficiamento de Revenda, não fabricação, ver [[Fabricacao-Chapas]]). O modelo de dados (Fábrica/Setor/Roteiro) já é genérico o suficiente para cobrir o rastreamento de lote enviado/retornado da galvanização externa; falta cadastrar a fábrica e o roteiro fabril desta linha, não construir sistema novo. Ver [[MES-Arquitetura-Decisoes]] e [[Achado-Ambiguidade-PCP]].

## Ver também
- [[Rota-Fabricacao]]
- [[Rota-Revenda]] — mesma lógica de quarentena/inspeção poderia se aplicar ao retorno da galvanização.
