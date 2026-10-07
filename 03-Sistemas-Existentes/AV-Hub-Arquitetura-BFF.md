---
tags: [erp-acos-vital, av-hub, arquitetura]
criado: 2026-09-16
atualizado: 2026-10-07
---

# av-hub — Arquitetura BFF

> **Atualização de 07/10/2026 — auditoria código × vault** (leitura de código: `develop` 996e320, `main` cfed113; produção não conferida). O que mudou: (1) **dois backends**: `API_URL` (`api-acos-vital`) e `COMERCIAL_API_URL` (`api-comercial`, Prisma, Node 22, pasta dentro do repo; **só em `develop`**) — [[AV-Hub-Comercial-Suprimentos]]; (2) o BFF repassa o **`backendToken`**, não `session.accessToken`; (3) a API foi reestruturada (`src/routes|models` → `src/schemas/**`), tem 3 tipos de chave, token de usuário e `/docs` — [[AV-Hub-API-Estado-Atual]]; (4) o JWT da sessão leva um **menu compacto** e o contêiner sobe com `--max-http-header-size=65536` — [[AV-Hub-RBAC]]. O texto abaixo foi corrigido no lugar; a frase "BFF puro" fica como histórico.

Documentado explicitamente num contrato interno: **"este repo é um BFF puro — `app/api/**` só faz proxy pra `${API_URL}/<recurso>`, sem acesso a banco"** *(era a descrição de setembro; (atualizado em 07/10) continua sem acesso a banco, mas deixou de ter um único destino: ver abaixo)*.

## Como funciona

- Todo `app/api/**/route.ts` chama `${process.env.API_URL}/<recurso>` com header `x-api-key` (server-to-server) e/ou `Authorization: Bearer <backendToken>` (por sessão). **(atualizado em 07/10)** O token repassado é o **`backendToken`** emitido pela `api-acos-vital` (token de usuário, HMAC com `USUARIO_TOKEN_SEGREDO`, contrato 06), **não** `session.accessToken`; é por ele que a identidade do usuário chega à API (que sobrescreve `created_by`/`updated_by`/etc. com a identidade do token).
- **(atualizado em 07/10) Segundo backend.** As rotas `app/api/comercial/[...rota]/route.ts` falam com o **`api-comercial`** (`COMERCIAL_API_URL`, `COMERCIAL_API_KEY`, cliente `lib/api/comercialApi.ts`), mandando `x-api-key` + Bearer com o `backendToken`. Esse BFF aplica uma allowlist rota × tela × ação em `auth.telas`: sem a tela cadastrada, 403. O `api-comercial` está **só em `develop`** (0 arquivos em `main`).
- **Backend: `api-acos-vital`** (produção em `https://api.acosvital.com.br`, Express 4 + Sequelize) — nome visto direto no código-fonte da API, citado em vários contratos. **(atualizado em 07/10)** Os caminhos `src/routes/*.js` e `src/models/*.js` citados nas notas de setembro **não existem mais**: o código está em `src/schemas/<schema>/{tables,views,aggregates,functions}/<entidade>/` (PR #276); só `src/middlewares` ficou. Ver [[AV-Hub-API-Estado-Atual]]. Tem acesso direto ao Postgres multi-schema (ver [[Schema-Postgres-Multi-Dominio]]) e serve **múltiplos frontends**: av-hub e, presumivelmente, telas administrativas próprias.
- A causa raiz exata de bugs (ex.: `pick(FIELDS)` descartando um campo antes do INSERT) é confirmável direto no código-fonte da API (commit `fa27d00`, branch `develop` — histórico de setembro; (atualizado em 07/10) os commits da `develop` foram re-autorados e esse hash pode não existir mais). Ver [[AV-Hub-Bugs-Catalogo]].
- `services/*.ts` no frontend são wrappers de `fetch` para as rotas internas do próprio Next.js (`/api/...`), não para o backend externo diretamente.

## Autenticação (NextAuth)

- **Azure AD** (SSO corporativo) — login silencioso via Seamless SSO quando possível.
- **Credentials** (fallback) — com rate limiting de tentativas (`lib/auth/loginRateLimiter.ts`), usando o último IP da cadeia `x-forwarded-for` (o único não-spoofável quando há proxy de confiança).
- Sessão JWT carrega: `id_usuario`, `menu` (árvore de telas+permissões), `perfis`, `telaInicialId`. **(atualizado em 07/10)** O `menu` no JWT é **compacto** (f875e5b, 02/10, por causa de HTTP 431) e o contêiner sobe com `--max-http-header-size=65536` (0f9f067); a sessão guarda também o `backendToken`. As permissões "ao vivo" vêm de `GET /me/permissoes` — ver [[AV-Hub-RBAC]].
- Endpoints de auth no backend: `/autenticacao/azure`, `/autenticacao/login`, `/permissoes_usuario/menu/:id`. **(atualizado em 07/10)** A API também expõe `/autenticacao/renovar`, `/autenticacao/logout` e `/me/permissoes`, e protege o acesso em camadas: 3 tipos de chave (`API_KEYS`; `auth.chaves_servico`; `MES_INTEGRACAO_KEYS`) + token de usuário + `auth.fn_autorizar` — ver [[AV-Hub-API-Estado-Atual]] e [[Chaves-de-Integracao-AvHub-MES-Pipeline]]. Se está tudo ligado em produção: **não verificado**.
- **(atualizado em 07/10) Node.** O Dockerfile do Hub é Node 20; o do `api-comercial` é **Node 22** (porta 3001, CI própria).

⚠️ Contraste: o [[App-PCP-Visao-Geral|app-pcp]] usa um backend **completamente separado** (`api-pcp`), com JWT Bearer por usuário e login só por usuário/senha (sem Azure AD — "o pessoal da fábrica não tem e-mail corporativo").

## Ver também
- [[AV-Hub-Visao-Geral]]
- [[AV-Hub-Comercial-Suprimentos]]
- [[AV-Hub-API-Estado-Atual]]
- [[AV-Hub-RBAC]]
- [[Achado-Duplicacao-RBAC]]
- [[AV-Hub-Bugs-Catalogo]]
