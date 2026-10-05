---
tags: [contrato-api, dashboards, vendas]
criado: 2026-10-05
status: proposta
---

# Contrato 37 — `variacao_pct` nas rotas `/dashboard_mensal_*`

**Para:** backend (`api-acos-vital`) · **Pequeno e aditivo.**

## 1. Por quê

O **Dashboard da Equipe** (Portal do Gerente) ganhou os blocos de participação por empresa e top 10 de
vendedores, como o relatório mensal "Resultados de Vendas" (av-hub `components/Painel/ResultadosEquipe.tsx`,
av-hub#131). Eles leem `GET /dashboard_mensal_vendas` e `GET /dashboard_mensal_faturamento`, que sem
`codigo_empresa` já devolvem o **consolidado** e **uma linha por unidade, com `participacao_perc`**
calculado no banco — rápidas (0,3 s).

A `GET /dashboard/equipe` traz a variação pronta (`fn_variacao_pct`), mas carrega blocos que esta tela
não usa; só `fn_painel_clientes_inativos` passou de 40 s no banco local (cópia de produção de
05/10/2026). Por isso o bloco não repete essa rota por unidade, e hoje o BFF calcula a variação a partir de
`vendas_mes_anterior`/`fat_mes_anterior` (marca `GAMBIARRA(` em `app/api/dashboard-equipe/resultados/route.ts`).

## 2. O que muda

Em `GET /dashboard_mensal_vendas` e `GET /dashboard_mensal_faturamento`, no `consolidado` **e** em
cada linha de `data`, acrescentar (com a mesma `fn_variacao_pct` da `/dashboard/equipe`):

| Campo | Vendas | Faturamento |
|---|---|---|
| `variacao_pct` | `fn_variacao_pct(vendas_total, vendas_mes_anterior)` | `fn_variacao_pct(faturamento_total, fat_mes_anterior)` |
| `variacao_quantidade_pct` | `fn_variacao_pct(qtd_pedidos, qtd_pedidos_mes_anterior)` | `fn_variacao_pct(qtd_nfs, qtd_nfs_mes_anterior)` |

`null` quando o mês anterior é zero (mesma regra da função). Nenhum campo existente muda.

## 3. Depois de aplicado (av-hub)

`app/api/dashboard-equipe/resultados/route.ts`: tirar a função `variacao()` e a marca `GAMBIARRA(`, e ler os
dois campos novos.

## 4. Aceite

- `GET /dashboard_mensal_vendas?mes=9&ano=2026`: `consolidado.variacao_pct` igual ao
  `vendas.variacao_pct` de `GET /dashboard/equipe?mes=9&ano=2026` (56,11 em 05/10/2026).
- Cada linha de unidade traz a sua variação (Aços Vital 42,2; Aços Uberaba 64,3; HRM 265,6 em
  set/2026).

## Observação (não é deste contrato)

Em set/2026 a classificação por tipo de contrato (`fn_painel_classificacao` e
`/vendas_por_tipo_contrato`) soma **855** pedidos e o total do mês (`fn_dashboard_mensal_vendas`)
**854**. O Dashboard da Equipe mostra a mesma diferença; vale o DBA conferir se um pedido entra em
dois tipos.
