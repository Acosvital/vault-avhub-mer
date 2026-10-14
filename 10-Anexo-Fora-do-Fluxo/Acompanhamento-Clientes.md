---
tags: [anexo, clientes, grupos-de-empresa, av-hub, fora-do-fluxo]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Gustavo (DBA)
fontes: [api-acos-vital f322dcd src/schemas/core_vendas_faturamento, HUB b55ac55 app/(protected)/acompanhamento-clientes e lib/domain/acompanhamentoClientes.ts, LOG-48]
---

# Acompanhamento de Clientes e grupos de empresa

Fora do fluxo 0b. Mostra, por cliente do Omie e por grupo de empresa, o que comprou e faturou no mês, os vendedores que o atenderam e se está parado. Contrato: [[LOG-48-Acompanhamento-de-Clientes-Grupos-de-Empresa]] (banco e API existem; pendências de banco abertas).

## Regra de negócio

Vários CNPJs formam um **grupo**. Se um CNPJ não vendeu mas outro do grupo comprou dentro do prazo, ele **não** é marcado como inativo; cada CNPJ mostra a própria contagem. O vínculo é manual, com sugestão pela raiz do CNPJ (8 primeiros dígitos). Prazo de inatividade escolhido na tela: 30, 60, 90 ou 180 dias (padrão 90; a API aceita de 1 a 3650). O vendedor vê só os próprios clientes; gerência e admin veem todos 📝 (decisões de 13/10).

## Estado

| Item | Estado | Selo |
|---|---|---|
| Tabelas | `grupos_clientes` e `grupos_clientes_membros` em `core_vendas_faturamento` | ✅ pastas `tables/grupos_clientes*` |
| Rotas da lista e do movimento | `GET /acompanhamento_clientes`, `GET /acompanhamento_clientes/movimento` (`dias_inativo`, `codigo_cliente`, `id_grupo`) | ✅ `fn_acompanhamento_clientes.route.js:129,195`; montagem `core_vendas_faturamento/index.js:171` |
| Rotas de grupos | `GET /grupos_clientes`, `/sugestoes`, `/:id`, `POST /`, `PUT` e `DELETE /:id`, `POST /:id/membros`, `DELETE /:id/membros/:empresa/:codigo` | ✅ `grupos_clientes.route.js:192-474` |
| Visão antiga | `GET /clientes_inativos` (cada `codigo_cliente` sozinho) | ✅ `index.js:168` |
| Telas | `acompanhamento-clientes` (lista), `cliente/[codigoEmpresa]/[codigoCliente]`, `grupo/[id]`; diálogo `GrupoClientesDialog`; BFF `app/api/acompanhamento-clientes` e `app/api/grupos-clientes` | ✅ |
| Status do cliente na tela | `ativo`, `inativo`, `coberto_grupo`, `sem_compra` | ✅ `lib/domain/acompanhamentoClientes.ts:8` |

## Pendências (ainda marcadas `GAMBIARRA` no HUB)

- A linha do grupo não traz `vendedores`; o front monta (`lib/domain/acompanhamentoClientes.ts:326`) 🔴 Gustavo.
- A API ainda soma NF cancelada nos totais e a lista não filtra por `codigo_cliente` no detalhe (`AcompanhamentoDetalhe.tsx:131,219`) 🔴 Gustavo (contrato 48, §9).
- Venda e faturamento por cliente com deduções separadas, na lógica da Equipe (§10); perfil Gerência `vinculados` ou `todos` (§6) 🔴 Gustavo.
- A lista parte só dos clientes com movimento (1.265 de 3.842), NF não conta como compra e `sem_compra` (§12) ❓ decidir no front com o Nathan.
- Produção não conferida ❓.
