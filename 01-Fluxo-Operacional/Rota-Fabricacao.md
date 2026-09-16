---
tags: [erp-acos-vital, fluxo-operacional]
criado: 2026-09-16
---

# 3c. Rota Fabricação (PCP & Produção Interna/Externa)

Não é uma rota única — são **três subfluxos heterogêneos** com lógicas próprias:

- [[Fabricacao-Flanges|Flanges]] — roteadas para o sistema dedicado de cálculo e parâmetros de flange ([[App-PCP-Visao-Geral|app-pcp]]).
- [[Fabricacao-Chapas|Chapas]] — direcionadas para a esteira de corte e conformação.
- [[Fabricacao-Grades-Piso|Grades de piso]] — compra de matéria-prima específica → recebimento → fabricação → envio para industrialização/galvanização externa → retorno e validação.

## Por que tratar como três subsistemas

Cada subfluxo tem perfil de risco e integração diferente — flanges depende de um sistema de cálculo técnico externo ao Hub; chapas é puramente fabril; grades de piso tem dependência de terceiro **duas vezes** (compra de MP e depois galvanização externa), exigindo rastreamento de lote enviado/lote retornado, diferente estruturalmente das outras duas.

## Ver também
- [[Fluxo-Operacional-Visao-Geral]]
- [[App-PCP-Modelo-Producao]] — modelo de dados real do sistema de flanges.
