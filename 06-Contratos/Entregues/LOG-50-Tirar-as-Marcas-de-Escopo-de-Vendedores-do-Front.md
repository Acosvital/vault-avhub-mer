---
id: LOG-50
aliases: ["Contrato 50", "50-Tirar-as-Marcas-de-Escopo-de-Vendedores-do-Front"]
tags: [contrato, contrato-logica, av-hub, bff, escopo, front]
criado: 2026-10-14
atualizado: 2026-10-29
status: implementado-no-codigo
sistemas: [hub-front]
dono: "Nathan"
etapa_0b: []
fontes: ["Dump Avhub (Esqueleto).sql:615-678", "api-acos-vital/src/middlewares/escopoVendedor.js:175"]
criado_original: 2026-10-13
---

# Contrato 50 — Tirar as 2 marcas que restam do [[LOG-40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend|40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]] no front

> **Onde atua:** av-hub: front

> [!info] Situação em 15/10/2026
> **Status:** `implementado-no-codigo` · **Pasta:** `Entregues` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Nathan
>
> - ✅ **Pré-requisito da API pronto:** `GET /me/permissoes` traz `nome_exibicao`, `ativo` e `origem` nos vínculos ([[LOG-49-Vinculos-do-Usuario-no-Me-Permissoes-Completos]]) e a API aplica o escopo pelo token ([[LOG-40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]]).
> - ✅ **Marcas A (`pedidosVenda.ts`) e B (`portalPcp.ts`) removidas** (HUB, `484dea6`, na `develop` pela PR #208): o BFF lê só `GET /me/permissoes` (`lib/api/escopoSessao.ts`); `resolverEscopo` e `resolverEscopoPcp` usam essa chamada; `pedidoNoEscopo`, `resolverVendedoresDiligenciador` e a checagem por nome de perfil saíram; detalhe, etapas, itens e status-historico repassam o 403 da API. A marca C foi reclassificada em 13/10. Não resta `GAMBIARRA(` de escopo de vendedores no front. `resolverPedidoDoEscopoPcp` continua só para ler o `codigo_empresa` que o POST de observação exige; quem confere o dono é a API.
> - 🟡 **Desvio do §3.2:** em Meus Pedidos, perfil `todos` continua mandando os vínculos próprios (a API não filtra `todos`, e a tela mostraria a empresa inteira). Sem vínculo em detalhe, etapas e itens é 403 (era 404).
> - ✅ **Testado na `api-test` em 15/10/2026, com usuário real** (só leitura, HUB local na `develop` + `484dea6`):
>   - **Vendedor** (Joares Alves): Meus Pedidos traz 34 pedidos, todos do código dele e com `proprio: true`; pedido de outro vendedor dá 403 `PEDIDO_FORA_DO_ESCOPO` no detalhe e no status-histórico (etapas e itens também dão 403, com o código errado, ver abaixo); `?vendedor=` alheio é ignorado na fonte `vendedor`; fontes `equipe` e `pcp` dão 403 "Acesso negado"; a tela de pedido alheio mostra "Pedido não encontrado" (Q3 respondida: serve).
>   - **Diligenciador PCP** (`pcp04`): lista e dashboard só com os 34 pedidos do vendedor vinculado; foco em vendedor de fora dá 403 `VENDEDOR_FORA_DO_ESCOPO` (lista, resumo, dashboard, notas); detalhe e status-histórico de pedido alheio dão 403 `PEDIDO_FORA_DO_ESCOPO`; POST de observação em pedido alheio dá 404 e não grava. O "focar" lista só os vendedores ativos (2 de 4 vínculos); o histórico dos inativos continua visível, de propósito.
>   - **Gerência PCP** (`danilo.silva`): `todos: true`, 88 vendedores no catálogo, 339 pedidos de 41 vendedores e 3 unidades; foco, detalhe, histórico e notas de qualquer vendedor abrem; fontes `equipe` e `vendedor` dão 403.
>   - **Sem sessão** (teste 7, parcial): as 8 rotas de pedidos, notas e PCP redirecionam ao login (307), sem dado. Sessão com cookie mas sem `backendToken` não foi reproduzida (o cookie é httpOnly).
> - ❓ **Não testados** (faltou conta): gerente de equipe (6), auxiliar de titular com `proprio: false` (2), vendedor sem vínculo (3), token expirado no meio da sessão (8) e a contagem de chamadas por carga do PCP (10).
> - 🟡 **Achados para o Gustavo (API, sem risco de vazamento, só o código e a mensagem):** `GET /itens_pedido_status` e `GET /pedido_venda_itens/{numero}` respondem 403 `SEM_VENDEDOR_VINCULADO` ("Usuário sem vendedor vinculado") para pedido de outro vendedor, mesmo com vínculo; o certo seria `PEDIDO_FORA_DO_ESCOPO`, como no detalhe. Além disso, o resumo de notas do PCP com foco alheio (`/api/pcp/notas/resumo`) devolve 200 vazio em vez de 403 (talvez só o nome do parâmetro nessa rota; não confirmado).
>
> Conferido em 15/10/2026 no código do HUB (`develop`) e contra a `api-test`.
> O texto original abaixo está inteiro; os trechos que o estado atual contradiz têm nota de rodapé.

> [!abstract] Resumo em linguagem natural
> **O que é:** Tirou do front as duas marcas de remendo que restavam do escopo de vendedores. O front agora só lê as permissões da API e repassa os erros dela.
> **Quem é afetado:** Vendedores, diligenciadores e Gerência do PCP (Planejamento e Controle da Produção), em Meus Pedidos e no Portal do PCP.
> **Situação:** ✅ Marcas removidas e testadas na `api-test` com vendedor, diligenciador PCP e Gerência PCP. ❓ Faltam gerente de equipe, auxiliar, vendedor sem vínculo e token expirado. 🟡 Achados de código de erro 403 para o Gustavo.


> **(atualizado em 13/10/2026)** A **marca C (`nextauth`) foi reclassificada** pelo Nathan na branch `feat/escopo-vendedor-liberacao-no-backend` (comentário normal, sem `GAMBIARRA(`; o menu do JWT é cache de apresentação). **Restam 2 marcas: A e B**, que dependem do contrato 49.
>
> Status: proposta | **só leitura de código** (13/10/2026):[^c1] `00 - HUB` (`develop` `03d62ea` + branch `feat/escopo-vendedor-liberacao-no-backend` `0561bbc`), `api-acos-vital` (`origin/develop` `80581d0`). Nada foi testado com usuário vendedor. Depende do [[LOG-49-Vinculos-do-Usuario-no-Me-Permissoes-Completos|49-Vinculos-do-Usuario-no-Me-Permissoes-Completos]].

**Dono:** Nathan (front/BFF). **Pré-requisito:** o contrato 49 entregue e conferido na `api-test`.

## 1. Estado de hoje

O contrato 40 tinha 5 marcas no front. Em 13/10 a branch `feat/escopo-vendedor-liberacao-no-backend` (`0561bbc`, **sem merge**) tirou 2: a caixa de liberação (`GET` e `PUT /api/liberar-pedidos`) já não resolve vendedor nem confere dono; a API faz as duas coisas. **Restam 3:**

| Marca | Arquivo | O que o BFF ainda faz | Sai quando |
|---|---|---|---|
| **A** | `lib/api/pedidosVenda.ts` | `resolverEscopo` resolve os vendedores (2 a 4 chamadas), manda `?vendedor=`, calcula `proprio`, `permitidos` e o "sem vínculo" | contrato 49 (D1 a D3) + este passo 3 |
| **B** | `lib/api/portalPcp.ts` | `resolverVendedoresDiligenciador` (3 chamadas) e `resolverEscopoPcp` alimentam a lista de vendedores e o "focar num vendedor" do PCP, e validam o foco | contrato 49 + este passo 4 |
| **C** | `app/api/auth/[...nextauth]/route.ts` (l. 192) | revalida o menu/permissões do JWT a cada 5 min (`REVALIDAR_PERMISSOES_MS`) | ✅ **reclassificada em 13/10** (passo 5; Q4 decidida: reclassificar, não remover) |

**O que a API já garante** (`escopoVendedor.js`, `fd8c29b`, regra fixa): com token e perfil que não é `todos`, preenche o `vendedor`/`codigo_vendedor` que falta, devolve `403 VENDEDOR_FORA_DO_ESCOPO` para vendedor de fora, confere o dono de `/pedidos_venda/{empresa}/{numero}`, `/pedido_venda_itens/{numero}`, `/pedidos_vendas/{cod}`, observações do PCP e `PUT /pedidos_liberacao/...` (`403 PEDIDO_FORA_DO_ESCOPO`), e `403 SEM_VENDEDOR_VINCULADO` sem vínculo. **Sem token ela não filtra**: é a chamada do MES e do pipeline.

## 2. Regra de ouro: sem token, a rota para

Quem deixa de filtrar no BFF passa a depender 100% do token. O `backendToken` dura 15 min, é renovado antes de expirar e, se a renovação falhar, é apagado da sessão ([[Mapa-Rotas-BFF-Bearer|Mapa-Rotas-BFF-API-para-Bearer]]: "quem fica ocioso volta a chamar só com a chave"). **Toda rota que parar de filtrar tem de responder 401 quando `session.user.backendToken` falta.** Já existe `temTokenDeUsuario()` em `lib/api/portalVendedor.ts` (branch `0561bbc`); usar o mesmo nas rotas abaixo. Sem isso, um vendedor ocioso passaria a ver pedido de todo mundo.

## 3. Marca A — `pedidosVenda.ts` e as rotas de pedidos e notas

1. **Helper novo** `lib/api/escopoSessao.ts`: `obterEscopoDaSessao()` lê `getMePermissoes()` (já tem `revalidate: 5`) e devolve `{ escopo, vendedores, proprios: Set<'empresa:codigo'> }`, ou `null` sem token (a rota responde 401). `proprios` = itens com `origem === 'proprio'`.
2. `resolverEscopo(fonte, foco)`:
   - `equipe`: igual a hoje (`vendedores: null`).
   - `vendedor` (Meus Pedidos/Minhas Notas): **não manda mais `vendedor=`**; devolve só `proprios` (para o campo `proprio`) e o "sem vínculo" quando `vendedores` vem vazio ou a API responde `SEM_VENDEDOR_VINCULADO`.
   - `pcp`: **sem lista de permitidos**. O "foco" só é repassado como `vendedor=<foco>` (a API valida e devolve 403 para vendedor de fora). Gerência PCP (`todos`) continua sem filtro.
3. **Apagar** `permitidos` e `pedidoNoEscopo` (a API devolve 403 no detalhe); `paramsDoBackend` só põe `vendedor` quando há foco.
4. Rotas a ajustar (mesma troca em todas): `app/api/pedidos-venda/[fonte]/{route, resumo, composicao}`, `.../[codigoEmpresa]/[pedidoVenda]/{route, etapas, itens}`, `app/api/notas-fiscais/[fonte]/{route, composicao}` (+ `lib/api/notasFiscais.ts`), `app/api/meus-pedidos/resumo`, `app/api/meus-pedidos/[codigo_pedido_omie]/status-historico`, `app/api/minhas-notas` e `app/api/minhas-notas/resumo`.
5. Onde a rota hoje devolve "não achei" para pedido fora do escopo (`pedidoNoEscopo`), passa a repassar o 403 da API com `respostaDeErro` (a tela já trata 4xx). 🟡 Conferir se a tela mostra bem o 403 no lugar do "pedido não encontrado".

## 4. Marca B — `portalPcp.ts` e o Portal do PCP

1. **Apagar** `resolverVendedoresDiligenciador`. `resolverEscopoPcp` passa a usar `me.vendedores` (itens `diligenciado`) com `nome`, `nome_exibicao` e `ativo` (**D1 do contrato 49**) e `me.escopo_vendedores === 'todos'` para Gerência PCP. A checagem por **nome do perfil** (`PERFIS_GERENCIA_PCP`, S4) some: vale o `escopo_vendedores`.
2. `GET /api/pcp/vendedores`: diligenciador lê de `me.vendedores`; Gerência PCP (`todos`) lê o catálogo `GET /vendedores?limit=1000` (dado de cadastro, não escopo; D4 do 49).
3. **Apagar** `resolverPedidoDoEscopoPcp` e os `validarCodigoVendedor` de escopo: a API já confere o dono em `/pedidos_vendas/{cod}` e em `pedido_observacao_pcp`. Rotas: `app/api/pcp/{dashboard, notas, notas/resumo, pedidos/resumo, pedidos/[codigo_pedido_omie]/status-historico, observacoes, observacoes/[id], vendedores}`.
4. Sem token: 401, como na seção 2.

## 5. Marca C — `nextauth` (Q4 do contrato 40) ✅ feito em 13/10/2026

**Recomendação: reclassificar, não remover.** O polling de 5 min existe para a **barra lateral e o `usePermission`** (UI), que leem o menu do JWT. A decisão de acesso **no servidor** já vem ao vivo: `requirePermission` lê `/me/permissoes` a cada requisição (cache de 5 s) e a API confere `auth.rotas_telas`. Então o JWT é só **cache de apresentação**.
- Trocar o texto da marca por um comentário normal (sem `GAMBIARRA(`), dizendo que o menu do JWT é cache de UI, que a decisão de acesso é da API e do `requirePermission`, e que `REVALIDAR_PERMISSOES_MS` só limita o atraso do menu.
- 🔴 Se preferir **remover** o polling, a barra lateral passa a depender de uma chamada por navegação; é uma decisão de UX, não de segurança.

## 6. Testes de aceite (na `api-test`, um usuário de cada perfil)

1. Vendedor A: Meus Pedidos só com pedidos de A; `proprio = true` neles. Pedido de B pela URL do detalhe → 403.
2. **Auxiliar** de um titular: vê os pedidos do titular com `proprio = false` e não consegue o que só o titular pode (liberar, favoritar).
3. Usuário **sem vínculo**: "sem vínculo" em Meus Pedidos e Minhas Notas, sem erro genérico.
4. **Diligenciador**: lista do "focar" só com os vendedores dele (ativos); foco em vendedor de fora → 403; observação do PCP em pedido de fora → 403.
5. **Gerência PCP** (`todos`): lista completa do catálogo e pedidos sem filtro.
6. **Gerente de equipe**: Pedidos/Notas da Equipe iguais ao de hoje.
7. **Sem token** (apagar o `backendToken` da sessão): cada rota alterada responde 401 e nenhuma devolve dado.
8. **Token expirado no meio da sessão**: 401 e a tela pede novo login, sem dado vazado.
9. Busca final: `GAMBIARRA(` com o caminho do contrato 40 não acha nada; `resolverVendedoresSessao` e `resolverVendedoresDiligenciador` só nos dashboards (fora deste contrato).
10. Contagem de chamadas por carga de página do PCP cai de até 9 para 1 (`/me/permissoes`).

## 7. Ordem de subida e rollback

| # | Quem | Passo |
|---|---|---|
| 1 | Gustavo | Entregar o [[LOG-49-Vinculos-do-Usuario-no-Me-Permissoes-Completos|49-Vinculos-do-Usuario-no-Me-Permissoes-Completos]] |
| 2 | Nathan | Testar a branch `0561bbc` (liberação) na `api-test` e mesclar |
| 3 | Nathan | PR da marca A, testes 1 a 3, 6 e 7 |
| 4 | Nathan | PR da marca B, testes 4, 5 e 7 |
| 5 | Nathan | ✅ Reclassificar a marca C (feito em 13/10, `feat/escopo-vendedor-liberacao-no-backend`) |
| 6 | Nathan | Testes 8 a 10 e atualizar o item 58 do [[Registro-de-Decisoes|Registro-de-Decisoes-2026-10-07]] |

**Rollback:** reverter o PR do front. A API continua com o escopo fixo e o BFF volta a filtrar por conta própria (sem perda de segurança).

## 8. Fora de escopo e riscos

- **Dashboards** (`meu-dashboard`, `meu-dashboard/cliente`, `dashboard-equipe`) também chamam `resolverVendedoresSessao`, mas não têm marca do contrato 40; usam as rotas `dashboard/...` da API. Ficam para depois.
- **Ambiente sem `USUARIO_TOKEN_SEGREDO`:** sem token as telas respondem 401 (antes funcionavam sem escopo). Só afeta ambiente local.
- **503** da API (`falha ao resolver escopo`): a tela mostra o erro do 5xx genérico; o escopo falha fechado, como desejado.
- **Cache de 5 s** do `/me/permissoes`: vínculo novo demora ~5 s a aparecer na lista; o escopo da API vale na hora.

## 9. Perguntas em aberto

| # | Pergunta | Dono |
|---|---|---|
| Q1 | 🔴 O contrato 49 (D1 a D4) vai ser entregue como está? | Gustavo |
| Q2 | ✅ Marca C: **reclassificada** (decisão do Nathan, 13/10); o polling fica | Nathan |
| Q3 | 🟡 Os 403 que substituem o "não encontrado" no detalhe têm mensagem adequada na tela? | Nathan |
| Q4 | 🟡 Trazer os dashboards para este escopo ou deixar fora? | Nathan |

Ver também: [[LOG-40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend|40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]] (§9, efeito nas marcas), [[HIST-Indice-Logica-Fora-do-Backend|Indice-Logica-Fora-do-Backend]].

[^c1]: Nota de 15/10/2026: Status vigente: `implementado-no-codigo` (marcas A e B removidas; testes de aceite 1, 4, 5 e 7 feitos na `api-test`).
