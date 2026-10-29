---
tags: [anexo, comissoes, av-hub, fora-do-fluxo]
criado: 2026-10-14
atualizado: 2026-10-26
status: vigente
dono: Gustavo (DBA)
fontes: [api-acos-vital f322dcd src/schemas/core_comissionamento, HUB b55ac55 app/(protected)/comissoes, v1 AV-Hub-Comissao-Modulo, AV-Hub-Simulador-Comissao, LOG-42, LOG-47]
---

# Comissões

Fora do fluxo 0b. Banco e API são do Gustavo; as telas são do Nathan. A comissão por faturamento e o custo real por item (Ciclo 2) dependem do `GET /itens/custo`, que o MES ainda não tem ([[Integracao-AvHub-MES]], INT-06).

> [!info] Comissão nova (26/10/2026)
> Este anexo descreve o módulo **atual** (`core_comissionamento`), que **não muda** (N16-11). A **comissão nova** entrou no [[00-Fluxo-Mestre-0b]] como `K1` a `K6`, em schema próprio (`core_comissao`), para o pedido da proposta e para o digitado no Omie: [[13-Custo-Real-e-Comissao-no-Fluxo]]. Como o motor atual calcula: [[01-Motor-Atual-Como-Calcula]]; o modelo novo: [[03-Modelo-Novo-core_comissao]].

## Estado

| Item | Estado | Selo |
|---|---|---|
| Schema `core_comissionamento` na API | Existe, com rotas montadas antes de `/dashboard` (a ordem importa) | ✅ `src/schemas/index.js:3-8`, `core_comissionamento/index.js:44-58` |
| Telas em `comissoes/*` no HUB | 9 páginas: `visao-geral`, `minhas-comissoes`, `simulador`, `analise-simuladores`, `bloqueio-comissoes`, `parametros/blacklist-clientes`, `parametros/blacklist-vendedores`, `parametros/regras-comissoes-fixas`, `parametros/vendedores-comissao` | ✅ `app/(protected)/comissoes/**/page.tsx` |
| Simulador | Persistido: `simulacoes`, `simulador_parametros`, `vw_simulacao_resolvida`. O protótipo `experimental/simulador-comissao` segue no HUB | ✅ |
| Dashboard de comissões (vendedores) | `dash-comissoes` usa `comissoes_provisoria` | ✅ `app/api/dashboard/comissoes/comissoes-provisorias` |
| Coordenadores | API pronta (`GET /dashboard/comissoes`, `fn_dashboard_comissoes` sobre `comissao_coordenadores`), mas o HUB **não a consome**: lê `lib/comissoes/coordenadores.json` e calcula no navegador | ✅ API; 🔴 front (`lib/comissoes/coordenadores.ts:10`, `dash-comissoes/page.tsx:26`) |

## Rotas da API (montagem)

| Caminho | Fonte | Observação |
|---|---|---|
| `/simulador_parametros`, `/simulacoes`, `/simulacao_resolvida` | tabelas e view | `pct_final` = menor entre o percentual do vendedor e o de compras (a view só resolve) |
| `/comissoes_master`, `/comissoes_nf`, `/comissoes_resumo_mensal` | views `vw_comissao_*` | leitura |
| `/blacklist_comissoes_destinatario/:codigo_cliente`, `/blacklist_comissoes_vendedores/:codigo_vendedor_omie` | tabelas | CRUD; presença bloqueia. Não confundir com `blacklist_destinatarios` e `blacklist_vendedor_g5` do schema `core_vendas_faturamento` (cascata de venda líquida, [[Dashboards]]) |
| `/bloqueio_comissoes/:numero_nf` | tabela | bloqueio por NF |
| `/regras_comissoes_fixas` | tabela | regras fixas por id |
| `/dashboard/comissoes?ano_mes=AAAA-MM` | função | permissão `dash-comissoes`; o bloqueio por NF **não** vale para coordenadores (decisão do Nathan de 06/10, contrato 38) |

## O que falta

- Trocar o JSON de coordenadores pelo `GET /dashboard/comissoes` no HUB (Nathan). O contrato [[LOG-42-Coordenadores-e-Orcamento-sair-do-JSON-do-Repositorio]] continua `proposta`; os valores nominais estão no git do HUB 🔴 (dado pessoal no repositório).
- Confirmar em produção que as migrations 007 e 007b do DBA foram aplicadas ❓ (o código as cita; o Dump Avhub de 14/10 tem `comissao_coordenadores` e `comissao_coordenadores_historico`).
- Comissão por faturamento com custo real: Ciclo 2, [[LOG-47-Custo-Real-por-Item-no-Hub]] 🔴.

Ver também: [[12-Orcamento-Base-de-Preco]] (a marca `GAMBIARRA` do LOG-42 saiu do Orçamento em 16/10), [[Dashboards]].
