---
id: LOG-04b
aliases: ["Contrato 05", "05 P6/P8", "04-Pedidos-Notas-Dashboards-Agregacao-no-Banco"]
tags: [contrato, contrato-logica, pedidos, dashboards, fora-do-fluxo]
criado: 2026-10-14
atualizado: 2026-10-14
status: implementado-no-codigo
sistemas: [hub-banco, hub-api]
dono: "Gustavo (DBA)"
etapa_0b: []
fontes: ["Dump Avhub (Esqueleto).sql:7526", "api-acos-vital/src/schemas/core_vendas_faturamento/aggregates/pedidos_venda/pedidos_venda.route.js:91-166", "api-acos-vital/src/schemas/core_vendas_faturamento/aggregates/dashboard/dashboard.route.js:99-217"]
---
# Contrato — Pedidos, Notas e Dashboards: agrupamento, filtros e totais no banco

> **Onde atua:** av-hub: banco, API

> [!info] Situação em 14/10/2026
> **Status:** `implementado-no-codigo` · **Pasta:** `Entregues` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Gustavo (DBA)
>
> - ✅ P1 a P5: `fn_pedidos_venda` devolve 1 linha por pedido com `parciais[]`, filtros de situação, etapa, prazo e blacklist (`Dump Avhub (Esqueleto).sql:7526`, comentário "Contrato 05 (P1–P5)"). P7: `GET /pedidos_venda/:codigo_empresa/:pedido_venda` (`pedidos_venda.route.js:166`); resumo: `GET /pedidos_venda/resumo` (`:133`).
> - ✅ Dashboards agregados: `GET /dashboard/vendedor`, `/equipe`, `/pcp` (`api-acos-vital/src/schemas/core_vendas_faturamento/aggregates/dashboard/dashboard.route.js:99,151,217`).
> - 🟡 P6 (ordem das etapas) segue em [[LOG-43-Ordem-das-Etapas-de-Faturamento-no-Cadastro]] (banco tem `ordem_fluxo`; falta o front). N1 a N3 (notas) e P8 não foram conferidos item a item (❓).
> - Alias: o código chama este contrato de "Contrato 05" (P1 a P8).
>
> Conferido em 14/10/2026 contra `api-pcp` 579a625, `app-pcp` 1fca8d3, `api-acos-vital` f322dcd, `omie-elt-pipeline` 0f739f0 e os dumps de 14/10. O front do av-hub (HUB b55ac55) só pelo vault v1 (❓).
> O texto original abaixo está inteiro.

> [!abstract] Resumo em linguagem natural
> **O que é:** Pediu que Pedidos, Notas e os três Dashboards deixem de agrupar e somar no navegador: o banco devolve um registro por pedido, filtros e totais.
> **Quem é afetado:** Vendedores, PCP (Planejamento e Controle da Produção) e gestão: telas mais leves, com a regra de negócio num só lugar.
> **Situação:** ✅ Pedidos (P1 a P5, P7) e dashboards no código. 🟡 A ordem das etapas (P6) segue em outro contrato. ❓ Notas (N1 a N3) e P8 não foram conferidos.


**Criado em:** 20/09/2026, inventário das telas oficializadas neste ciclo (Pedidos, Notas e os três
Dashboards). Complementa — e não repete — estes contratos, que continuam valendo:

- [`09-Paginacao-por-Pedido-Vendas-Planilha.md`](../../03-Contratos-Logica-Fora-Backend/09-Paginacao-por-Pedido-Vendas-Planilha.md) — ainda aberto (backend não implementou, ver nota nele)
- [`06-Ordenacao-Listagens.md`](./06-Ordenacao-Listagens.md) — já entregue
- [`07-Chave-Composta-Blacklist-Pedidos.md`](./07-Chave-Composta-Blacklist-Pedidos.md) — já entregue
- [`08-Itens-por-Parcela-Pedidos.md`](./08-Itens-por-Parcela-Pedidos.md) — já entregue

**Princípio:** o navegador (e o BFF) não devem recalcular o que o banco já sabe. Os pontos abaixo
estão marcados com `GAMBIARRA(` no código.

## 1. Pedidos (`components/Pedidos/`)

| # | Gambiarra hoje | Onde |
|---|---|---|
| P1 | Baixa **todas as páginas** do período (`/vendas_planilha`) e **agrupa por pedido** no navegador (`agruparPorPedidoVenda`), depois filtra, ordena e pagina os grupos | `usePedidos.ts`, `utils/agruparPedidosPlanilha.ts` |
| P2 | Define no front o que é "pedido": família com `sequencial = 0`, sem orçamento (etapa 0), valor = soma de todos os sequenciais | `usePedidos.ts` (`chavesDosPedidos`), `helpers.ts` (`ehOrcamento`) |
| P3 | **Blacklist**: baixa a lista (`/api/pedidos/blacklist`) e marca/exclui dos números no navegador | `usePedidos.ts` |
| P4 | **Prazo/SLA** (atrasado, vence hoje, vai vencer, em dia) calculado e filtrado no navegador a partir de `data_previsao` | `usePedidos.ts`, `utils/slaPedido.ts` |
| P5 | **Indicadores** (pedidos, faturados, atrasados, valor bruto/líquido) contados no navegador | `usePedidos.ts` |
| P6 | Ordem das etapas do fluxo (`[10,20,80,50,60,70]`) fixa no front | `utils/etapasFluxo.ts` |
| P7 | A página de um pedido busca a **lista** por número (`limit 100`) e filtra pela empresa no navegador; não há `GET` de pedido por chave | `PedidoDetalhe.tsx` |
| P8 | "Todo o período" soma **12 resumos mensais** no navegador e recalcula os percentuais | `usePedidos.ts`, `useNotas.ts`, `usePainelPcp.ts` (`consolidarMeses`) |

**Peço:**

- `GET /pedidos_venda` (novo, agregado por pedido — é a opção B do contrato de paginação): 1 registro
  por `(codigo_empresa, pedido_venda)`, com `parciais[]`, `valor_total` (soma dos sequenciais),
  `situacao`, `etapa_atual`, `data_previsao_mais_urgente`, `prazo` (`atrasado|vence_hoje|vai_vencer|em_dia|null`),
  `dias_para_prazo`, `em_blacklist boolean`. Filtros `situacao`, `etapa`, `prazo`, `q`, `vendedor`,
  `data_inicio/fim`, `excluir_orcamento=true`, `sort/order`, paginado **por pedido**.
- `GET /pedidos_venda/resumo` com os mesmos filtros: `pedidos`, `faturados`, `atrasados`, `vence_hoje`,
  `valor_bruto`, `valor_liquido`, respeitando blacklist (`?incluir_blacklist=false` como padrão dos números).
- `GET /pedidos_venda/{codigo_empresa}/{pedido_venda}`: o pedido completo (parciais, etapas da empresa
  na ordem correta do fluxo, histórico).
- `GET /vendas_planilha_resumo` e `/faturamento_planilha_resumo` aceitam `data_inicio`/`data_fim`
  (intervalo, não só `mes/ano`) e devolvem já consolidado, com `pctTotal` correto.
- A **ordem das etapas** vem do cadastro de etapas (campo `ordem_fluxo`), não de constante do front.

**Formato de `parciais[]`** (em `GET /pedidos_venda` e em `GET /pedidos_venda/{codigo_empresa}/{pedido_venda}`):
agregar por pedido muda só a unidade de contagem/paginação — a tela continua mostrando cada
parcial dentro do card do pedido. Cada item de `parciais[]` é uma linha do que hoje vem de
`/vendas_planilha`, ordenado por `sequencial` (0 = cabeçalho), com no mínimo:

| campo | uso na tela |
|---|---|
| `codigo_pedido_omie` | chave do parcial (histórico de status, observações do PCP, itens) |
| `sequencial` | ordem e rótulo ("Pedido original", "Entrega 1"…) |
| `total_pedido_venda` | valor do parcial (a soma dos parciais = `valor_total` do pedido) |
| `etapa`, `etapa_descricao` | etapa do parcial no fluxo |
| `situacao` + flags `autorizado`, `denegado`, `faturado`, `cancelado`, `devolvido`, `devolucao_parcial`, `encerrado`, `manual` | situação do parcial |
| `data_previsao`, `prazo`, `dias_para_prazo` | prazo/SLA do parcial (mesma regra do pedido, por parcial) |
| `data_faturamento`, `nota_fiscal` | faturamento do parcial |
| `categoria`, `obs_pedido` | detalhe do parcial |

**Itens (produtos) de cada parcial NÃO vêm na listagem** — pesaria demais. A tela busca sob
demanda (página do pedido / ao expandir um parcial) pelo `codigo_pedido_omie` do parcial, o que
dependia do [`08-Itens-por-Parcela-Pedidos.md`](./08-Itens-por-Parcela-Pedidos.md)
(itens com `codigo_pedido_omie`/`sequencial` de origem) — já entregue. Se o backend preferir, o
`GET /pedidos_venda/{codigo_empresa}/{pedido_venda}` pode já devolver `parciais[].itens[]` —
mas só no detalhe, nunca na lista.

## 2. Notas (`components/Notas/`)

| # | Gambiarra hoje | Onde |
|---|---|---|
| N1 | Baixa **todas** as páginas de `/faturamento_planilha`, filtra "com/sem pedido" e pagina no navegador | `useNotas.ts` |
| N2 | "Conta nos números" = tem `pedido` ou é NF manual — regra do front, espelhando o resumo do backend | `components/Notas/helpers.ts` (`contaNosNumeros`) |
| N3 | Nota sem pedido = operação `oppedido` ≠ 11 (conferido em 09/2026); o texto explicativo é montado no front | `helpers.ts` (`explicacaoSemPedido`) |

**Peço:** `GET /faturamento_planilha` com `com_pedido=true|false`, `sort/order` e a coluna
`conta_nos_numeros boolean` + `motivo_fora ('sem_pedido_venda' | …)` calculados no banco; e o resumo
respondendo com a mesma regra.

## 3. Dashboards

| # | Gambiarra hoje | Onde |
|---|---|---|
| D1 | **PCP**: totais (pedidos, faturados, atrasados, vencem hoje) e a lista "Precisam de atenção" saem de baixar todos os pedidos do período e agrupar no navegador | `components/Painel/usePainelPcp.ts` |
| D2 | **Equipe/Vendedor**: o BFF agrega o que o banco deveria entregar — soma classificação SPOT/CONTRATO paginando `vendas_base` **um vendedor por vez**, monta top de produtos somando todas as linhas de `pedido_venda_itens` (até 2.000 por página) e cruza nomes de vendedor/unidade em memória | `lib/api/meuDashboardDomain.ts`, `lib/api/dashboardEquipeDomain.ts` |
| D3 | Variação vs. mês anterior (`▲ 26,8%`) calculada no navegador | `components/Painel/PainelPartes.tsx` |

**Peço:** endpoints agregados prontos, com escopo aplicado pelo backend (ver contrato de permissões):
`GET /dashboard/vendedor` (o vendedor logado), `GET /dashboard/equipe`, `GET /dashboard/pcp`
(`?vendedor=&mes=&ano=|periodo=`), cada um devolvendo os blocos que a tela já usa (metas e progresso,
classificação por tipo, top clientes, top produtos, próximos vencimentos, clientes inativos, e — no
PCP — totais e a lista de atenção) **e** a comparação com o mês anterior (`valor_anterior`,
`variacao_pct`). Sem loop por vendedor e sem paginar tudo no BFF.

## 4. Aceite

- Nenhuma tela baixa mais que uma página de dado bruto para montar número de tela.
- Os números dos Indicadores, do Dashboard e da lista coincidem entre si e com o dashboard financeiro
  (regra de conciliação do `docs/design/guia-de-interface.md`, §7).
- Trocar o critério de "pedido"/"prazo"/"conta nos números" exige mudar só o banco.
