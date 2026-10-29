---
tags: [anexo, clientes, grupos-de-empresa, av-hub, fora-do-fluxo]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Gustavo (DBA)
fontes: [api-acos-vital f322dcd src/schemas/core_vendas_faturamento, HUB b55ac55 app/(protected)/acompanhamento-clientes e lib/domain/acompanhamentoClientes.ts, LOG-48]
---

# Acompanhamento de Clientes e grupos de empresa

**Em uma frase:** a tela mostra, por cliente e por grupo de empresas, quanto comprou e faturou no mês, quais vendedores o atenderam e se ele está parado.

**Quando consultar:** quando a dúvida é "este cliente está inativo?" ou "como vários CNPJs viram um grupo?". Esta nota fica fora do fluxo 0b. Contrato: [[LOG-48-Acompanhamento-de-Clientes-Grupos-de-Empresa]] (banco e API existem; pendências de banco abertas).

## Como funciona

- Vários CNPJs podem formar um **grupo**. Se um CNPJ não vendeu, mas outro do grupo comprou dentro do prazo, ele **não** é marcado como inativo. Cada CNPJ mostra a própria contagem.
- O vínculo é manual. O sistema sugere grupos pela raiz do CNPJ (os 8 primeiros dígitos).
- Na tela, o prazo de inatividade é de 30, 60, 90 ou 180 dias (padrão: 90). A API aceita de 1 a 3650.
- O vendedor vê só os próprios clientes. Gerência e admin veem todos 📝 (decisões de 13/10).

## Onde está hoje

- ✅ Banco, rotas, telas e diálogo de grupos existem.
- 🔴 Ainda há pendências marcadas `GAMBIARRA` no HUB (lista abaixo).
- ❓ Produção não foi conferida.

## Pendências (ainda marcadas `GAMBIARRA` no HUB)

- A linha do grupo não traz os vendedores; o front os monta 🔴 Gustavo.
- A API ainda soma NF cancelada nos totais, e a lista não filtra por cliente no detalhe 🔴 Gustavo.
- Faltam venda e faturamento por cliente com deduções separadas, e o perfil Gerência `vinculados` ou `todos` 🔴 Gustavo.
- A lista parte só dos clientes com movimento (1.265 de 3.842), NF não conta como compra e `sem_compra` ❓ decidir no front com o Nathan.

## Detalhe técnico

Regra de negócio completa: vários CNPJs formam um **grupo**. Se um CNPJ não vendeu mas outro do grupo comprou dentro do prazo, ele **não** é marcado como inativo; cada CNPJ mostra a própria contagem. O vínculo é manual, com sugestão pela raiz do CNPJ (8 primeiros dígitos). Prazo de inatividade escolhido na tela: 30, 60, 90 ou 180 dias (padrão 90; a API aceita de 1 a 3650). O vendedor vê só os próprios clientes; gerência e admin veem todos 📝 (decisões de 13/10).

### Estado

| Item | Estado | Selo |
|---|---|---|
| Tabelas | `grupos_clientes` e `grupos_clientes_membros` em `core_vendas_faturamento` | ✅ pastas `tables/grupos_clientes*` |
| Rotas da lista e do movimento | `GET /acompanhamento_clientes`, `GET /acompanhamento_clientes/movimento` (`dias_inativo`, `codigo_cliente`, `id_grupo`) | ✅ `fn_acompanhamento_clientes.route.js:129,195`; montagem `core_vendas_faturamento/index.js:171` |
| Rotas de grupos | `GET /grupos_clientes`, `/sugestoes`, `/:id`, `POST /`, `PUT` e `DELETE /:id`, `POST /:id/membros`, `DELETE /:id/membros/:empresa/:codigo` | ✅ `grupos_clientes.route.js:192-474` |
| Visão antiga | `GET /clientes_inativos` (cada `codigo_cliente` sozinho) | ✅ `index.js:168` |
| Telas | `acompanhamento-clientes` (lista), `cliente/[codigoEmpresa]/[codigoCliente]`, `grupo/[id]`; diálogo `GrupoClientesDialog`; BFF `app/api/acompanhamento-clientes` e `app/api/grupos-clientes` | ✅ |
| Status do cliente na tela | `ativo`, `inativo`, `coberto_grupo`, `sem_compra` | ✅ `lib/domain/acompanhamentoClientes.ts:8` |

### Pendências (detalhe)

- A linha do grupo não traz `vendedores`; o front monta (`lib/domain/acompanhamentoClientes.ts:326`) 🔴 Gustavo.
- A API ainda soma NF cancelada nos totais e a lista não filtra por `codigo_cliente` no detalhe (`AcompanhamentoDetalhe.tsx:131,219`) 🔴 Gustavo (contrato 48, §9).
- Venda e faturamento por cliente com deduções separadas, na lógica da Equipe (§10); perfil Gerência `vinculados` ou `todos` (§6) 🔴 Gustavo.
- A lista parte só dos clientes com movimento (1.265 de 3.842), NF não conta como compra e `sem_compra` (§12) ❓ decidir no front com o Nathan.
- Produção não conferida ❓.
