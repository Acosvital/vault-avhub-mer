---
tags: [contrato-logica, contrato-sql, contrato-api, vendas, integracao-mes]
criado: 2026-09-28
status: proposta
---

# Contrato 26 — Vendas: liberação do pedido pelo vendedor (acompanhamento da Qualidade) + Fluxo 4 para o MES

> **Situação em 29/09/2026:** **backend entregue** (API `4bf36d9`) e **front mergeado na `develop`**
> ([av-hub#103](https://github.com/Acosvital/av-hub/pull/103)). Na `api-test`, `GET /pedidos_liberacao`,
> `GET /pedidos_liberados` e `PUT /pedidos_liberacao/{empresa}/{numero}` respondem e validam a entrada, e as
> telas estão no menu ("Liberar Pedidos": Vendedor e Admin (Dev); "Liberação da Equipe": Gerência e Admin (Dev)).
> **Falta:** (1) **a data de corte** — `parametros_vendas.data_inicio_liberacao` está vazia, então nenhum
> pedido entra na liberação (decisão do Nathan, depois `INSERT` do DBA); (2) L4, o `api-pcp` (Robert) passar a
> Carteira para o `/pedidos_liberados`. Telas ainda não testadas com pedidos reais.
