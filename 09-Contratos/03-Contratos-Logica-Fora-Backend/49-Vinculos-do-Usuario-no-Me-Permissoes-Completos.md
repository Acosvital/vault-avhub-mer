---
tags: [contrato-api, contrato-sql, dba, escopo, permissoes, gambiarra-s3, me-permissoes]
criado: 2026-10-13
atualizado: 2026-10-13
status: parcial-d2-d3-ja-existem-d1-falta
---

# Contrato 49 — `GET /me/permissoes` com os vínculos de vendedor completos (destrava as marcas S3 do [[40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]])

> Status: proposta | **só leitura de código** (13/10/2026): `api-acos-vital` (`origin/develop` `80581d0`), `00 - HUB` (`lib/api/mePermissoes.ts`) e este vault. Produção e o corpo de `auth.fn_me_permissoes` **não foram vistos** (a função é de banco e não está no repositório). Tudo marcado 🟡 é inferência; 🔴 precisa do DBA.

**Destinatários:** Gustavo (DBA, `auth.fn_me_permissoes`) e Nathan (front, contrato [[50-Tirar-as-Marcas-de-Escopo-de-Vendedores-do-Front]]).

> **(atualizado em 13/10/2026) CONFERIDO NO DUMP DO BANCO DE TESTE** (`Dump avhub teste (Completo).sql`; só li DDL, `auth.rotas_telas`, `auth.telas`, `auth.perfis` e `auth.permissoes`; **não li dados de clientes ou usuários**). `auth.fn_me_permissoes` monta `vendedores` com `to_jsonb(v)` sobre `auth.fn_vendedores_do_usuario(u.id)`: **D2 ✅ já é verdade** (é a mesma fonte que o `escopoVendedor.js` usa). **D3 ✅ confirmado:** `origem` = `proprio` (`vendedores.id_funcionario` = funcionário do usuário), `titular` (via `auxiliar_vendedor`) e `diligenciado` (via `diligenciador_vendedor`, **só** se o escopo for `vinculados` ou `todos`). **D4 ✅ respondido pelo comportamento:** para `todos` a função **não devolve o catálogo**, só os vínculos do próprio usuário ("escopo todos não filtra"); a lista completa de vendedores do PCP continua vindo de `GET /vendedores`. **D1 ❌ NÃO FEITO:** a função devolve só `codigo_empresa`, `codigo_vendedor_omie`, `id_funcionario`, `nome`, `origem`. **Faltam `nome_exibicao` e `ativo`** (e a função também não filtra vendedor inativo: `v.deleted_at IS NULL`, sem `ativo`, o que é o certo para não sumir com histórico). É a única mudança que o DBA ainda precisa fazer neste contrato.

## 1. Por quê

O [[40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]] fixou o escopo de vendedores na API (`fd8c29b`): com token de usuário, a API filtra, preenche o `vendedor` que falta e confere o dono do pedido. **A parte de aplicar a regra está feita.** O que prende **3 marcas** no front é outra coisa: o BFF ainda precisa saber **quem são** os vendedores do usuário para mostrar a tela:

| Para quê | Onde hoje | Quem resolve hoje |
|---|---|---|
| marcar o pedido como **próprio** ou de **titular** (auxiliar só lê) | `pedidosVenda.ts` (`proprio`) | `resolverVendedoresSessao`: 2 a 4 chamadas (`/usuarios/{id}`, `/vendedores`, `/auxiliar_vendedor`, `/vendedores`) |
| "**sem vínculo**" em Meus Pedidos | `pedidosVenda.ts` (`vazio`, `vinculado: false`) | idem |
| a **lista de vendedores** do PCP e o "**focar num vendedor**" | `portalPcp.ts` → `/api/pcp/vendedores` | `resolverVendedoresDiligenciador`: 3 chamadas (`/usuarios/{id}`, `/diligenciador_vendedor`, `/vendedores`) |

**O que a API já tem.** `GET /me/permissoes` (contrato 06) já devolve, no tipo `MePermissoesResponse` do front, `escopo_vendedores` (`todos` | `vinculados` | `proprios`) e `vendedores[]` com `codigo_empresa`, `codigo_vendedor_omie`, `id_funcionario`, `nome` e **`origem`: `proprio` | `titular` | `diligenciado`**. Ou seja: **a Q3 do contrato 40 ("a API devolve a marca de próprio x titular?") já está respondida pelo desenho da API**, só não é usada. O que falta é conferir e completar o conteúdo.

## 2. O que pedir ao DBA

Mudança **só em `auth.fn_me_permissoes`** (nenhuma rota nova; a rota em `src/schemas/auth/aggregates/me/me.route.js` só repassa o JSON da função).

| # | Pedido | Motivo |
|---|---|---|
| D1 | `vendedores[]` passa a trazer **`nome_exibicao`** (`vendedores.nome_exibicao`) e **`ativo`** (`vendedores.ativo`) | O Portal do PCP mostra o nome de exibição e **filtra vendedor inativo** do "focar" (`/api/pcp/vendedores` usa `ativo`). Hoje o JSON só tem `nome`. Sem isso o front continua precisando de `GET /vendedores` |
| D2 | **Confirmar** que `vendedores[]` é exatamente o conjunto de `auth.fn_vendedores_do_usuario(usuario)` (o mesmo que o `escopoVendedor.js` usa para filtrar), com `origem` correta | O que a tela mostra tem de bater com o que a API deixa passar. Se forem fontes diferentes, o usuário vê um vendedor e leva 403 |
| D3 | **Confirmar** a `origem` por perfil: perfil `proprios` só `proprio`; `vinculados` traz `proprio` + `titular` (auxilia) + `diligenciado` (diligencia); `todos` (Gerência PCP) traz o quê? | Hoje 20 dos 21 perfis são `vinculados` e só "Gerencia PCP" é `todos` ([[Auditoria-Dump-Producao-2026-10-07]]). 🟡 Não sei se `diligenciado` entra para `vinculados` (o contrato 40 diz que sim) |
| D4 | Para `escopo_vendedores = 'todos'`: devolver `vendedores: []` (e o front busca o catálogo em `GET /vendedores`) **ou** todos os vendedores ativos? | Recomendação 🟡: **`[]`**, para a resposta não crescer e o `Cache-Control: private, max-age=5` não carregar 1000 linhas por usuário; o catálogo é dado de cadastro, não escopo |
| D5 | Garantir que o JSON **não muda para quem já consome**: só campos novos | `requirePermission.ts` e `portalPcp.ts` já leem a resposta |

Exemplo do item do `vendedores[]` depois do D1:

```json
{
  "codigo_empresa": "<uuid da unidade>",
  "codigo_vendedor_omie": "1234567",
  "id_funcionario": "<uuid ou null>",
  "nome": "Nome completo",
  "nome_exibicao": "Nome curto",
  "ativo": true,
  "origem": "proprio"
}
```

## 3. Testes de aceite (na `api-test`, com um token de cada perfil)

1. **Vendedor com vendedor próprio** (sem auxílio): `vendedores` tem só itens `proprio`; mesmo conjunto que a API aceita em `GET /pedidos_venda?vendedor=...` (e dá 403 `VENDEDOR_FORA_DO_ESCOPO` para qualquer outro).
2. **Auxiliar** de um titular: itens `proprio` (se for vendedor) **e** `titular`; `PUT /pedidos_liberacao/{empresa}/{pedido_do_titular}` dá 200.
3. **Diligenciador** (perfil PCP): itens `diligenciado`; cada um com `nome_exibicao` e `ativo`.
4. **Gerência PCP** (`todos`): `escopo_vendedores = "todos"` e `vendedores` conforme a decisão do D4.
5. **Usuário sem vendedor vinculado:** `vendedores: []` e, na rota de negócio, 403 `SEM_VENDEDOR_VINCULADO`.
6. **Vendedor inativo** (`ativo_desde`/`inativo_desde` no cadastro): aparece com `ativo: false`, continua no escopo (o histórico dele não some).
7. **Consistência:** para cada usuário de teste, `vendedores[]` ⊆ resultado de `auth.fn_vendedores_do_usuario` e vice-versa.
8. Quem já usa `/me/permissoes` (`requirePermission`) continua passando nos testes de permissão do [[Mapa-Rotas-BFF-API-para-Bearer]].

## 4. Riscos

- **Cache de 5 s** (`Cache-Control: private, max-age=5` e `next.revalidate: 5` no BFF): um vínculo novo demora até ~5 s para aparecer. Aceitável; o escopo da API (não cacheado) vale na hora.
- **Resposta maior** se o D4 for "todos". Por isso a recomendação do `[]`.
- Se o D2 falhar (fontes diferentes), a tela mostraria vendedor que a API barra: **corrigir antes do front**.

## 5. Rollback

Campos novos: quem não os usa ignora. Reverter a função no banco volta ao JSON atual sem tocar na API.

## 6. Perguntas em aberto

| # | Pergunta | Dono |
|---|---|---|
| Q1 | 🔴 `fn_me_permissoes.vendedores` usa `fn_vendedores_do_usuario` (D2)? Qual a `origem` por perfil (D3)? | Gustavo |
| Q2 | 🔴 `todos`: lista vazia ou completa (D4)? | Nathan / Gustavo |
| Q3 | 🟡 O perfil de gerente de equipe (20 dos 21 são `vinculados`) ganha `vendedores` só dos vínculos dele? As telas de **equipe** não são de escopo de vendedor para `fn_autorizar` (o BFF as chama sem filtro): confirmar que nada muda para elas | Gustavo |

Ver também: [[50-Tirar-as-Marcas-de-Escopo-de-Vendedores-do-Front]] (o que o front faz depois), [[05-Permissoes-e-Escopo-no-Banco]], [[Indice-Contratos]].
