---
tags: [erp-acos-vital, av-hub, arquitetura]
criado: 2026-09-16
---

# av-hub — Arquitetura BFF

Documentado explicitamente num contrato interno: **"este repo é um BFF puro — `app/api/**` só faz proxy pra `${API_URL}/<recurso>`, sem acesso a banco"**.

## Como funciona

- Todo `app/api/**/route.ts` chama `${process.env.API_URL}/<recurso>` com header `x-api-key` (server-to-server) ou `Authorization: Bearer <session.accessToken>` (por sessão).
- **Backend: `api-acos-vital`** (produção em `https://api.acosvital.com.br`, Express + Sequelize) — nome visto direto no código-fonte da API, citado em vários contratos (`src/routes/*.js`, `src/models/*.js`, `src/middlewares/*.js`). Tem acesso direto ao Postgres multi-schema (ver [[Schema-Postgres-Multi-Dominio]]) e serve **múltiplos frontends**: av-hub e, presumivelmente, telas administrativas próprias.
- A causa raiz exata de bugs (ex.: `pick(FIELDS)` descartando um campo antes do INSERT) é confirmável direto no código-fonte da API (commit `fa27d00`, branch `develop`). Ver [[AV-Hub-Bugs-Catalogo]].
- `services/*.ts` no frontend são wrappers de `fetch` para as rotas internas do próprio Next.js (`/api/...`), não para o backend externo diretamente.

## Autenticação (NextAuth)

- **Azure AD** (SSO corporativo) — login silencioso via Seamless SSO quando possível.
- **Credentials** (fallback) — com rate limiting de tentativas (`lib/auth/loginRateLimiter.ts`), usando o último IP da cadeia `x-forwarded-for` (o único não-spoofável quando há proxy de confiança).
- Sessão JWT carrega: `id_usuario`, `menu` (árvore de telas+permissões), `perfis`, `telaInicialId`.
- Endpoints de auth no backend: `/autenticacao/azure`, `/autenticacao/login`, `/permissoes_usuario/menu/:id`.

⚠️ Contraste: o [[App-PCP-Visao-Geral|app-pcp]] usa um backend **completamente separado** (`api-pcp`), com JWT Bearer por usuário e login só por usuário/senha (sem Azure AD — "o pessoal da fábrica não tem e-mail corporativo").

## Ver também
- [[AV-Hub-Visao-Geral]]
- [[AV-Hub-RBAC]]
- [[Achado-Duplicacao-RBAC]]
- [[AV-Hub-Bugs-Catalogo]]
