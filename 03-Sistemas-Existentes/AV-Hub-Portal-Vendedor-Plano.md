---
tags: [erp-acos-vital, av-hub, portal-vendedor, planejamento]
criado: 2026-09-16
---

# av-hub — Plano do Portal do Vendedor (Autoatendimento)

Plano de produto vivo (`docs/portal-vendedor/plano-portal-vendedor.md`), evoluído ao longo de setembro/2026 com decisões do Nathan e achados técnicos sucessivos. Três telas: **Meu Dashboard**, **Meus Pedidos**, **Minhas Notas Fiscais**.

## Status geral (04/09)
Vínculo, escopo, resumo do topo, refaturamento (vendas e faturamento), meta individual, filtro por período/cliente e SLA (`data_previsao`) já fechados — os 3 contratos de DBA necessários (`001` data_previsao, `002`, `003`) foram implementados e confirmados ao vivo. Restam 2 pendências, nenhuma bloqueada em backend: dicionário de nomes para `etapa` (em andamento) e status agregado da família de pedido (decisão já tomada, falta implementar).

## Meu Dashboard
Reaproveita os endpoints que hoje só o admin usa (`dashboard/vendas|faturamento/detalhe-vendedor`), travados no(s) código(s) de vendedor do usuário logado. Cor por faixa de meta batida (tiers) aplicada só do lado de Vendas — Faturamento mostra os mesmos números com cor fixa (confirmado como intencional, não lacuna). Seletor de mês compartilhado com as outras duas telas.

## Meus Pedidos
- Fonte principal: `GET /vendas_base` (não `pedidos_vendas` cru) — já vem com `nome_cliente`, `categoria`, `tipo_contrato`, os booleanos de status e `grupo` (classificação G1-G6/LÍQUIDO) prontos, e 1 linha por família de pedido (não por parcial). Ver mecânica completa em [[AV-Hub-Vendas-Reconciliacao]].
- **Notas fiscais parciais de um pedido**: quando um pedido é faturado em partes, o Omie cria uma linha nova por parcial (mesmo `numero_pedido`, `codigo_pedido_omie` diferente); o campo `sequencial` (0 = guarda-chuva, 1/2/... = parciais em ordem) identifica cada uma. Cada parcial faturada tem exatamente 1 NF vinculada (1:1 via `codigo_pedido_omie`).
- **Status agregado da família**: `vendas_base` só reflete o booleano do guarda-chuva (`sequencial=0`), que pode ficar `faturado=false` mesmo com as parciais já faturadas — decisão tomada de buscar também `pedidos_vendas` bruto (todos os sequenciais) e calcular o agregado no frontend.
- **SLA** — calculado sobre `data_previsao − hoje`, só para pedidos não faturados: normal (>3 dias) → vermelho sólido (3 dias) → piscando (2 dias) → piscando mais rápido + ícone (1 dia) → **Atrasado** (estado próprio, <0 dias). Pedido já faturado não entra na régua. Implementação via CSS puro respeitando `prefers-reduced-motion`.
- Filtro por período (reaproveita `useDashboardDate`) e por cliente (busca em memória sobre o que já foi carregado — volume pequeno por vendedor/mês) confirmados para a v1.

## Minhas Notas Fiscais
Fonte principal: `GET /nf_classified` (não `nota_fiscal_saida` cru) — já vem com `grupo_deducao` pronto por nota. Campos mostrados: `numero_nf`, `data_emissao`/`hora_emissao`, `valor_nf`/`valor_mercadorias`/`valor_ipi`, vínculo com o pedido de origem. Removido a pedido do Nathan: `averbado`.

## Rotas Next.js novas
```
GET /api/meu-dashboard   → resolve vendedor(es), chama dashboard_mensal_vendas/faturamento + ranking travado
GET /api/meus-pedidos    → resolve vendedor(es), chama /vendas_base travado, agrega multi-código
GET /api/minhas-notas    → mesma lógica, /nf_classified
```
Todas com `requirePermission` própria e resolução de vínculo via `getServerSession` — nenhuma aceita filtro de vendedor vindo do cliente.

## Extras validados (não implementados ainda, sem bloqueio técnico)
Estados vazios/erro, badge de SLA crítico no menu lateral, comparação com mês anterior, "próximos vencimentos" ranqueado, top clientes do vendedor (via agregação de `detalhe_vendedor_vendas` no cliente — `ranking_clientes_vendas` não filtra por vendedor), copiar nº com 1 clique, "dados atualizados às HH:MM" honesto (usar o `updated_at` mais recente entre os registros carregados, nunca a hora do navegador), exportar CSV/Excel, cliente inativo (caro — exige N chamadas por mês), favoritar cliente/pedido (precisa de tabela nova para sincronizar entre dispositivos), histórico de status do pedido (parcial — só os marcos que já existem como datas), **top produtos vendidos** (✅ viável via `GET /pedido_venda_itens`, view dedicada `vw_pedido_venda_itens` com item a item por pedido/vendedor), ritmo de meta por semana, filtro por status, SLA agregado por cliente.

## Ver também
- [[AV-Hub-Modulos]]
- [[AV-Hub-Vendas-Reconciliacao]]
- [[RH-Escopo-Row-Level-Security]]
