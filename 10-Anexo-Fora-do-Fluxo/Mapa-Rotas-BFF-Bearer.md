---
tags: [anexo, bff, bearer, permissoes, rotas, av-hub, fora-do-fluxo]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [av-hub develop 758d5f0 em 29/10 (lib/api/comercialApi.ts, lib/api/escopoUnidade.ts, app/api/**/route.ts, conferência em 29/10), HUB b55ac55 app/api/**/route.ts (extração por script em 14/10), api-acos-vital f322dcd middlewares/identidadeUsuario.js e utils/acessoConfig.js, Dump Avhub 14/10 (auth.rotas_telas), v1 Mapa-Rotas-BFF-API-para-Bearer e anexo mapa-rotas.js]
---

# Mapa de rotas do BFF para a API: quem chama com Bearer

**Em uma frase:** lista quais telas do HUB chamam a API levando o login do usuário (o "Bearer"), porque é isso que decide se um usuário comum leva erro 403 (acesso negado).

**Quando consultar:** quando um usuário comum recebe 403 numa tela, ou antes de mexer nas permissões de rota. Fica fora do fluxo 0b. Siglas: **BFF** é a camada do HUB que fala com a API; **Bearer** é o token de login do usuário; **403** é "sem permissão". Regras de chave e token: [[Chaves-e-Autenticacao]]; permissões: [[RBAC-e-Permissoes]].

> **Situação conferida em 29/10/2026 (`av-hub` develop `758d5f0`):** `headersCompras` (`lib/compras/api.ts`) e `headersApi` (`lib/api/pedidosVenda.ts`) são apelidos de `headersComIdentidade` e **mandam o Bearer** (a contagem de 14/10 de "70 sem Bearer" classificava errado). Só `app/api/auth/[...nextauth]/route.ts` chama a API sem o token do usuário, e é o esperado: as chamadas do login (`/autenticacao/azure`, `/autenticacao/login`, `/autenticacao/renovar`) e o `fetchMenu`. Desde a PR #206 (15/10) perfis e tela inicial usam `GET /me/permissoes` com o Bearer, e a API já isenta o `fetchMenu` (`rotaDispensaToken`). Veja BL-042 em [[Backlog-por-Frente]] e PS-018 em [[Pontas-Soltas]].

## A regra em poucas palavras

- **Com** Bearer, a API confere quem é o usuário. Usuário inativo ou token revogado: erro 401. Ação não permitida na tela: 403. Rota sem mapeamento de permissão: 403 (a API nega por padrão).
- **Sem** Bearer, nada muda: vale só a chave `x-api-key` (BFF, MES e pipeline).
- O token dura 15 minutos. O HUB o renova sozinho enquanto a aba está aberta. Quem fica ocioso além disso volta ao login.
- Com token, a API grava o autor da ação pelo token, não pelo que o corpo da chamada informa.

## Onde está hoje

- ✅ A regra na API está conferida.
- ✅ Todas as chamadas do HUB à API (fora o login) já levam o Bearer quando a sessão tem token. Conferido em 29/10: nenhum helper manda só a chave.
- ✅ O BFF do módulo comercial (`app/api/comercial/[...rota]`) também fala com a **API do Hub** (`api-acos-vital`, rotas `/comercial/*`), com Bearer e `requirePermission`; a `api-comercial` saiu do BFF (N16-111, `3bccfce`). Das 72 rotas da lista, 21 já existem no Hub (`api: 'hub'`); as outras respondem 503 `RECURSO_NAO_MIGRADO` até serem criadas lá (N16-117, Robert).
- 🟡 Cobertura em `auth.rotas_telas` dos grupos de rotas de Compras, dos cadastros usados por Compras e do acompanhamento de clientes (listas abaixo): ❓ não conferida em produção (o dump é só o esqueleto, sem as linhas). O Gustavo confirma.
- Risco principal: o BFF confere uma tela e a API mapeia outra para a mesma rota (exemplos em "Detalhe técnico"). Resultado possível: todo comprador comum leva 403.

## Ordem para trocar o BFF para Bearer

1. O Gustavo cobre a lista em `auth.rotas_telas`, aceitando todas as telas que o BFF confere para a mesma rota, e confirma o escopo de vendedores de cada perfil ❓.
2. O front troca os helpers por área e testa na `api-test` com um usuário de cada perfil (admin, gerente, vendedor, PCP, comprador).
3. A troca de 09/10 (PR #178) e o que veio depois ligaram o Bearer em todos os helpers; o que resta é a **cobertura em `auth.rotas_telas`** (passo 1) e o teste por perfil (passo 2) 🟡.

## Detalhe técnico

### A regra na API (✅ conferida)

- Chamada **com** `Authorization: Bearer` passa por `auth.fn_autorizar` (`identidadeUsuario.js`): usuário inativo ou token revogado dá 401; ação não permitida na tela que a rota exige dá 403 `SEM_PERMISSAO`; rota sem linha em `auth.rotas_telas` dá 403 `ROTA_SEM_PERMISSAO_MAPEADA` (fail-closed). Fixo desde 08/10: a variável `PERMISSOES_ROTA_MODO` não é mais lida ✅ `acessoConfig.js:10-16`, `identidadeUsuario.js:85-110`.
- **Sem** Bearer nada muda: segue só a `x-api-key` (BFF, MES e pipeline) e os campos de autoria do corpo são os informados.
- Escopo de vendedores: fixo desde 09/10 (contrato 40); só vale com token ✅ `acessoConfig.js:28-35`.
- Com token, a API sobrescreve `id_usuario_sessao` e os campos de autoria (`created_by`, `updated_by`, `deleted_by`, `aprovado_por`, `decidido_por`, `cancelado_por`) pelo id do token ✅ `identidadeUsuario.js:55-64`.
- O `backendToken` dura 15 minutos. O BFF o renova quando faltam menos de 5 min (a sessão é relida a cada 4 min com a aba aberta); quem fica ocioso além da validade não renova (a API recusa token vencido): a sessão é marcada como expirada e a tela leva ao login. Rota com `requirePermission` responde 401 sem token, em vez de seguir só com a chave ✅ HUB `d0ef359` (`app/api/auth/[...nextauth]/route.ts`, `lib/api/requirePermission.ts`, `providers/SessaoExpiradaGuard.tsx`); ❓ não testado na homologação.
- A tabela `auth.rotas_telas` existe no dump, com `acao` entre `pode_visualizar`, `pode_criar`, `pode_editar`, `pode_deletar`, `pode_aprovar` ✅ (`CREATE TABLE auth.rotas_telas`). Quais linhas existem em produção ❓ Gustavo.

### Números no HUB

**Contagem de 29/10/2026** (`av-hub` develop `758d5f0`, busca por texto, sem o script antigo): **202** arquivos `route.ts` e **264** handlers (métodos exportados). Todos os ajudantes de header (`headersComIdentidade` 311 usos, `headersCompras` 73, `headersApi` 25, `headersDaApi` 9) mandam o Bearer; `x-api-key` escrita à mão só existe em `app/api/auth/[...nextauth]/route.ts` e em `lib/api/mePermissoesApi.ts` (este com Bearer). 35 arquivos `route.ts` não chamam a API por helper (respondem no BFF ou usam serviço próprio). A tabela abaixo é a extração por script de 14/10 e fica como histórico:

Extração por script (regex sobre `app/api/**/route.ts`, HUB `b55ac55`), refeita em 14/10:

| Medida | Valor |
|---|---|
| Rotas do BFF | 197 |
| Handlers (método por rota) | 275 |
| Handlers que chamam uma API | 237 |
| Com Bearer (`headersComIdentidade`, que cai para só `x-api-key` quando a sessão não tem token) | 167 |
| "Sem Bearer" na contagem de 14/10 (`headersCompras`, `headersApi` ou `x-api-key` inline); **errada**: os dois helpers mandam o Bearer | 70 |
| Handlers que não chamam a API (respondem no BFF ou usam helper não resolvido) | 38 |
| Rotas únicas da API a mapear em `auth.rotas_telas` (seção A do script) | 48 |

Em 09/10 eram 189 rotas, 265 handlers, 168 com Bearer e 64 sem. O aumento inclui rotas novas como grupos de clientes e acompanhamento de clientes (não foi feita a comparação rota a rota). Na época, as chamadas à `api-comercial` ficavam fora da conta (controle próprio, `UsuarioComercial`). Hoje o BFF do comercial chama a API do Hub e passa por `auth.rotas_telas` como as demais ([[Comercial-Suprimentos]]).

Limites: o script erra o método quando o `fetch` está em helper e não resolve caminho montado por função (aparece como `via helper`). Conferir cada linha no arquivo antes de agir.

### Rotas que precisam de linha no mapa

O título antigo dizia "sem Bearer", o que não vale mais (todas mandam o Bearer). O que importa é a **linha em `auth.rotas_telas`**. Grupos da extração de 14/10 (a lista completa sai do script):

| Grupo | Rotas da API (exemplos) | Tela exigida no BFF |
|---|---|---|
| Compras | `/compras/ordens` e `/{x}` (`GET`, `POST`, `PATCH`), `/compras/ordens/{x}/acompanhamento`, `/contatos`, `/ocorrencias`, `/reenviar`, `/compras/ocorrencias/{x}`, `/compras/compradores`, `/compras/fornecedores`, `/compras/condicoes-pagamento` | `compras`, `followup`, `compradores` |
| Cadastros usados por Compras | `/categorias`, `/produtos`, `/contas_correntes`, `/projetos`, `/cotacoes_moeda/atual` | `compras (visualizar)` |
| Acompanhamento de clientes | `/acompanhamento_clientes`, `/acompanhamento_clientes/movimento` | sem tela definida no BFF |

Pares de risco (a tela natural da API difere da do BFF), todos **ainda presentes** no código de 29/10 (conferir com o Gustavo se a API aceita as duas telas):

- `GET /usuarios/{x}` é chamado por `/api/compras/comprador-sessao` e `/api/compras/minhas-unidades` com a tela `compras`. Se a API mapear `/usuarios/*` só para a tela `usuarios`, todo comprador comum leva 403.
- `GET /produtos`, `/categorias`, `/contas_correntes`, `/projetos` e `/cotacoes_moeda/atual` são chamados com a tela `compras`.
- `GET /compras/pedidos-venda/{x}/compras` aceita as telas de pedidos (`meus-pedidos`, `pedidos-equipe`, `pcp-pedidos`) **ou** `compras`.
- `/pedidos_venda*`, `/pedido_venda_itens/{x}`, `/vendas_planilha_resumo`, `/itens_pedido_status` e `/faturamento_planilha*` mudam de tela conforme a fonte (Meus pedidos, Pedidos da equipe, Pedidos do PCP; Minhas notas, Notas da equipe, Notas do PCP).

### Ordem para trocar o BFF para Bearer (detalhe)

1. O Gustavo cobre a lista acima em `auth.rotas_telas`, aceitando **todas** as telas que o BFF confere para a mesma rota, e confirma o `escopo_vendedores` de cada perfil (20 dos 21 perfis eram `vinculados` no v1: listas de gerente e PCP podem encolher) ❓.
2. O front troca os helpers por área e testa na `api-test` com um usuário de cada perfil (admin, gerente, vendedor, PCP, comprador).
3. A troca de helpers de 09/10 (PR #178) e as seguintes ligaram o Bearer em todo o BFF; o que sobra é a linha em `auth.rotas_telas` de cada grupo acima 🟡.

### Como refazer

`node mapa-rotas.js <pasta do HUB> <saida.md>`. O script está no anexo do v1 (`vault-avhub-mer/04-Arquitetura-Transversal/Mapa-Rotas-BFF-API-anexos/mapa-rotas.js`); a saída lista as seções A (a mapear), B (sem Bearer), C (com Bearer) e D (sem chamada). Dono: Nathan.
