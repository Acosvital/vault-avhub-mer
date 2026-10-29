---
tags: [anexo, dashboards, vendas, faturamento, av-hub, fora-do-fluxo]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Gustavo (DBA)
fontes: [api-acos-vital f322dcd src/schemas/core_vendas_faturamento, HUB b55ac55 app/(protected), LOG-31, LOG-33, LOG-37, LOG-04b]
---

# Dashboards

**Em uma frase:** os dashboards mostram vendas, faturamento, compras e comissões; os números saem prontos do banco do av-hub e o HUB só pede e mostra.

**Quando consultar:** quando a dúvida é "de onde vem este número?" ou "que regra define a venda líquida e a unidade do vendedor?".

Fora do fluxo 0b (nota de 09/10: dashboards, comissões, orçamento e pedidos manuais não fazem parte do desenho). Contratos arquivados que descrevem as regras: [[LOG-04b-Pedidos-Notas-Dashboards-Agregacao-no-Banco]], [[LOG-31-Compras-Dashboard]], [[LOG-33-Dashboards-Unidade-de-Origem-do-Vendedor]], [[LOG-37-Dashboard-Mensal-Variacao]].

## Telas do HUB

- Vendas e faturamento, e as versões por tipo.
- Comercial (vem do `api-comercial`).
- Comissões (ver [[Comissoes]]; os coordenadores ainda 🔴 saem de um arquivo).
- Notas fiscais manuais.
- Dashboard do vendedor, da equipe e do PCP.

✅ Todas existem. A tabela de rotas está em "Detalhe técnico".

## Regras que valem

- **Unidade de origem do vendedor** (LOG-33): o filtro por empresa significa "vendedores cuja unidade de origem é X", com todo o faturamento deles. A unidade vem do funcionário vinculado e, sem vínculo, do cadastro no Omie. Vendedor inativo some das listas dos meses depois da saída; totais e cartões não mudam 📝.
- **Venda líquida:** pedido ou nota entra na cascata de deduções (G1 a G6) e o que sobra é líquido. Pedido manual entra sempre como líquido, sem cascata ([[Pedido-Manual]]).
- **Escopo do vendedor:** a API o aplica a partir do token (LOG-40); o BFF (camada do HUB que fala com a API) não filtra mais ✅ ([[Mapa-Rotas-BFF-Bearer]]).

## Pendências

- ❓ Gustavo e Nathan: comparar os números por unidade dos dashboards com o relatório mensal depois do LOG-33.
- ❓ Em produção, `variacao_pct` foi conferida em 06/10 só pelo contrato 37 (set/2026: vendas 55,3); não reconferida em 14/10.

## Detalhe técnico

### Telas do HUB

| Tela | Rota | BFF | Selo |
|---|---|---|---|
| Dashboard de vendas | `dashboards/dash-vendas` | `app/api/dashboard/vendas` | ✅ |
| Dashboard de faturamento | `dashboards/dash-faturamento` | `app/api/dashboard/faturamento` | ✅ |
| Vendas por tipo, faturamento por tipo | `dash-vendas-por-tipo`, `dash-faturamento-por-tipo` | idem | ✅ |
| Dashboard comercial | `dashboards/dash-comercial` | `api-comercial` `GET /dashboards/comercial` (tela `dash-comercial`) | ✅ `app/api/comercial/[...rota]/route.ts:59` |
| Dashboard de comissões | `dashboards/dash-comissoes` | ver [[Comissoes]] | ✅, coordenadores 🔴 |
| Notas fiscais manuais | `dashboards/notas-fiscais-manuais` | `app/api/notas-manuais` | ✅ |
| Dashboard do vendedor, da equipe, do PCP | `meu-dashboard`, `dashboard-equipe`, `pcp-dashboard` | `app/api/meu-dashboard`, `dashboard-equipe`, `pcp/dashboard` | ✅ |

### Rotas da API

| Rota | O que entrega | Selo |
|---|---|---|
| `GET /dashboard/vendedor`, `/dashboard/equipe`, `/dashboard/pcp` | Agregado pronto por perfil (`fn_variacao_pct`, painel de clientes inativos) | ✅ `dashboard.route.js:99,151,217` |
| `GET /dashboard_mensal_vendas`, `/dashboard_mensal_faturamento` | Consolidado e uma linha por unidade, com `participacao_perc`, `variacao_pct` e `variacao_quantidade_pct` | ✅ `core_vendas_faturamento/index.js:208,222`; `fn_dashboard_mensal_faturamento.route.js` cita `variacao_pct` |
| Rankings e detalhe por vendedor e cliente | `fn_ranking_vendedores_*`, `fn_ranking_clientes_*`, `fn_detalhe_vendedor_*` | ✅ pastas `functions/` |
| Ritmo de meta e volume | `fn_ritmo_meta_*`, `ritmo_*_hora`, `volume_pedidos_diario*` | ✅ pastas `functions/` e `aggregates/` |
| `GET /compras/ordens/dashboard` | Gasto, fornecedores, recebimento e atrasos do Compras | ✅ `ordens_compra.route.js:810` |
| `GET /dashboard/comissoes` | Comissão de coordenadores | ✅ API, front 🔴 ([[Comissoes]]) |

### Regras (detalhe)

- **Unidade de origem do vendedor** (LOG-33): o filtro `codigo_empresa` dos dashboards significa "vendedores cuja unidade de origem é X", com todo o faturamento deles. A unidade vem do funcionário vinculado (`vendedores.id_funcionario`) e, sem vínculo, do Omie do cadastro. `GET /vendedores` devolve `ativo_desde`, `inativo_desde`, `unidade_origem`, `nome_unidade_origem` ✅ (`unidade_origem` aparece em `fn_ranking_vendedores_*`). Vendedor inativo some das listas dos meses depois da saída; totais e cartões não mudam 📝.
- **Venda líquida:** pedido ou nota entra na cascata G1 a G6 e o que sobra é líquido. Pedido manual entra sempre como líquido, sem cascata ([[Pedido-Manual]]).
- **Escopo do vendedor** é aplicado pela API a partir do token (LOG-40): o BFF não filtra mais ✅ ([[Mapa-Rotas-BFF-Bearer]]).
