---
tags: [erp-acos-vital, av-hub, rbac]
criado: 2026-09-16
atualizado: 2026-10-08
---

# av-hub — RBAC (Perfis, Telas, Permissões)

> Status: decidido | no código | em produção (verificado em 07/10/2026 pelo dump, onde indicado). Decisões da rodada em [[Registro-de-Decisoes-2026-10-07]].

> **Atualização de 07/10/2026 — auditoria código × vault** (leitura de código: front `develop` 996e320 / `main` cfed113; API `main` = `develop` a6ab058; produção **não** conferida). Esta nota só descrevia o guard do front. Mudou: (1) existe uma **5ª ação, `pode_aprovar`**; (2) `requirePermission` aceita **lista de telas** e consulta **ao vivo** `GET /me/permissoes`; (3) o **menu no JWT é compacto**; (4) a **API também aplica RBAC** (`auth.fn_autorizar`, escopo de vendedor/unidade) — **ligado em produção: não verificado**; (5) o `api-comercial` tem uma **2ª camada** (`PerfilComercial`). Texto abaixo corrigido no lugar.

Sistema de autorização completo e **já em produção**, resolvido inteiramente no Postgres (schema `auth`), não via grupos do Azure AD.

## Estrutura

- **usuarios** ↔ **perfis** ↔ **telas** ↔ **permissões** (ação: `pode_visualizar`/`pode_criar`/`pode_editar`/`pode_deletar` e, **(atualizado em 07/10)**, a **5ª ação `pode_aprovar`** — usada em Compras para aprovar/cancelar OC e em Vagas; na API, só quem tem `pode_aprovar` aprova/cancela OC).
- O menu do usuário (árvore de telas + permissões efetivas) é resolvido uma vez no login e embutido no JWT da sessão (`session.user.menu`). **(atualizado em 07/10)** O menu no JWT é **compacto** (f875e5b, 02/10, para evitar HTTP 431) e o Docker do Hub sobe com `--max-http-header-size=65536` (0f9f067).
- `hasPermission(menu, telaId, acao)` — busca recursiva na árvore de menu.
- `requirePermission(telaId, acao)` — guard usado em toda rota de API (`app/api/**/route.ts`). **(atualizado em 07/10)** Aceita **uma lista de telas** e consulta **ao vivo** `GET /me/permissoes` (cache de 5 s; contrato 06); só cai no menu do JWT se essa consulta falhar. `/me/permissoes` traz também `escopo_vendedores` (`todos`/`vinculados`/`proprios`), `unidades`, `setor_irrestrito` e `token_versao`.
- Telas de cadastro próprias: Perfis, Telas, Permissões (com edição em massa via `BulkPermissaoModal`), Usuários, Usuários×Perfis.
- Campo "Tela inicial por perfil" (`perfis.tela_inicial_id`) — redireciona o usuário pós-login para a tela certa (substituindo uma lógica antiga hardcoded por nome de perfil).
- A coluna `usuarios.anonymizedAt` **não existe** em `auth.usuarios` — a tabela tem `ativo`, `deleted_at`/`deleted_by`, mas nenhum campo de anonimização dedicado. Não há suporte a anonimização LGPD nesta tabela.

## RBAC também na API (novo — conferido no código, ligado em produção: não verificado)

A `api-acos-vital` deixou de confiar só no guard do front ([[AV-Hub-API-Estado-Atual]]):

| Peça | Estado no código |
|---|---|
| Token de usuário | `Authorization: Bearer` (HMAC, `USUARIO_TOKEN_SEGREDO`); a identidade do token sobrescreve `id_usuario_sessao` e os campos `created_by`/`updated_by`/`deleted_by`/`aprovado_por`/`decidido_por`/`cancelado_por` |
| `auth.fn_autorizar` + `auth.rotas_telas` | autorização por rota, `PERMISSOES_ROTA_MODO` **fixo em `exigir`, sem `.env`** (✅ Nathan, 07/10; alteração de código: Gustavo). **No código de 08/10 (`0557871`) o padrão é `exigir`, mas a variável ainda é lida** (`observar`/`desligado` valem; valor inválido vira `exigir`) e o servidor só sobe com `USUARIO_TOKEN_SEGREDO` ≥ 32 caracteres; antes o padrão era `desligado` |
| Escopo | `ESCOPO_VENDEDORES_EXIGIR`, `ESCOPO_UNIDADE_EXIGIR_SESSAO`, `IDENTIDADE_EXIGIR_TOKEN` (das 6 chaves que sobraram do contrato [[38-Regras-Sem-Chave-de-Ambiente]]; 🟡 Gustavo: fixar só `ESCOPO_VENDEDORES_EXIGIR`, as demais seguem como chave até separar as chaves de serviço) |
| Auditoria | sempre ligada (`auth.auditoria`) |
| Erros | `TOKEN_REVOGADO`, `CHAVE_SOMENTE_LEITURA`, `CHAVE_SEM_ACESSO_ADMINISTRATIVO`, `TOKEN_USUARIO_AUSENTE` |

Com o modo decidido como `exigir` fixo, a regra passa a valer em qualquer ambiente assim que a alteração do Gustavo entrar; **se já está no ar em produção, não verificado**.

**🟡 Chamadas de serviço (proposta adotada, validar com o Gustavo):** o modo só confere permissão quando há token de usuário. As chamadas de serviço do pipeline e do MES (só `x-api-key`, sem `Bearer`) **passam sem mapeamento** em `auth.rotas_telas`. Ver [[Registro-de-Decisoes-2026-10-07]] (itens 8 e 9).

## Modo de desenvolvimento sem login (conferido no código em 08/10)

- **No Hub:** `NEXT_PUBLIC_DEV_SEM_LOGIN=true` libera todas as telas com um usuário e um menu fixos de desenvolvimento (`lib/auth/devSemLogin.ts`); o `requirePermission` devolve "liberado" sem consultar nada. **Só vale com `NODE_ENV` diferente de `production`.**
- **No `api-comercial`:** `AUTH_DEV_BYPASS=true` aceita o header `x-dev-usuario` no lugar do `Bearer`; o serviço **encerra na subida** se o bypass for ligado sem `NODE_ENV=development` ou `test` declarado.
- Os dois são travas de ambiente: em qualquer deploy, conferir que as variáveis não existem. Não verificado nos ambientes reais.

## `requirePermission` e telas ainda não cadastradas

Se **nenhuma** das telas pedidas existe em `auth.telas` (banco atrasado em relação ao front), o guard **cai no menu do JWT** em vez de negar; se pelo menos uma existe, a resposta ao vivo de `/me/permissoes` manda. Consequência para o Comercial & Suprimentos: enquanto os slugs não são cadastrados, a decisão depende do menu da sessão, que também não os traz, e o resultado é 403 ([[AV-Hub-Comercial-Suprimentos]]).

## 2ª camada no `api-comercial`

O `api-comercial` (só em `develop`) valida o `backendToken` (claim `perfis`, `exp` obrigatório) e, **dentro dele**, aplica o `PerfilComercial`: cargo (vendedor, auxiliar, supervisor, gerente, gerente geral, diretor) e capacidades (escopo de propostas, ver valores, ver custo, excluir, relatório gerencial). Comprador é detectado por regex `/compr|suprimento/i` no nome do perfil do Hub (frágil, **[I]**). Não é um segundo cadastro de usuários — usa a identidade do Hub — mas é um **segundo modelo de permissão**. Ver [[AV-Hub-Comercial-Suprimentos]]. No BFF, as rotas comerciais exigem a tela cadastrada em `auth.telas` (senão 403 e some do menu).

## Por que isso importa para o ERP unificado

O Estoque não usa autorização via grupos do Azure AD para segregação de função (comprador/aprovador/almoxarife/qualidade/gestor) — modelo diferente do que já está em produção aqui. Como o Estoque mora no mesmo banco do MES, ele **reaproveita** o RBAC que já existe lá (telas/perfis/permissões do `api-pcp`), não cria uma terceira implementação — continuam sendo só 2 implementações independentes no total (av-hub e MES). Ver [[Estoque-Regras-Negocio]] e [[MES-Arquitetura-Decisoes]] (decisão 3), e a discussão completa em [[Achado-Duplicacao-RBAC]].

O [[App-PCP-Visao-Geral|app-pcp]] tem sua **própria** implementação paralela e independente deste mesmo padrão (perfis/telas/permissões/usuários), num backend Prisma separado — confirmado em detalhe: `telas`/`perfis`/`permissoes` (com `BulkPermissaoModal` próprio) e `usuarios`/`usuarios-perfis`, estruturalmente idêntico ao av-hub mas com dado e backend 100% separados.

## Ver também
- [[AV-Hub-Arquitetura-BFF]]
- [[AV-Hub-API-Estado-Atual]]
- [[AV-Hub-Comercial-Suprimentos]]
- [[Achado-Duplicacao-RBAC]]
- [[Estoque-Regras-Negocio]]
