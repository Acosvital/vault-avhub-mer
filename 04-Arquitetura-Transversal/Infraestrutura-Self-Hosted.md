---
tags: [erp-acos-vital, arquitetura, infraestrutura]
criado: 2026-09-16
atualizado: 2026-10-07
---

# Infraestrutura Self-Hosted

> Status: decidido (verificado em 07/10/2026) — ver [[Registro-de-Decisoes-2026-10-07]], item 4.

> **Atualização de 07/10/2026 — a nota não citava o `omie-elt-pipeline`; ver a seção "Pipeline Omie" ao final.** Fonte: leitura do código/compose do pipeline (`master` d2886bf). **Decidido pelo Nathan (✅ 07/10):** o pipeline roda na **VPS 1**; se está ligado em produção continua não verificado (o contrato 23 diz "sem deploy nada roda").

Confirmado tanto pelo [[PRD-Estoque-Visao-Geral|PRD do Estoque]] quanto pelo `Dockerfile` do [[AV-Hub-Visao-Geral|av-hub]]:

## Topologia (3 VPS)

- **VPS1** — aplicações no Coolify, atrás do Traefik (mesmo padrão do Backlog Ágil, do blog e do av-hub): **pipeline Omie, MES, av-hub e outros sistemas** (✅ Nathan, 07/10; ver [[Registro-de-Decisoes-2026-10-07]]).
- **VPS2** — Postgres: **bancos do MES, do av-hub e demais** (schema por domínio no cluster do av-hub, ver [[Schema-Postgres-Multi-Dominio]]), com WAL de backup já configurado (cobre automaticamente qualquer schema novo).
- **VPS3** — MinIO (arquivos) (object storage) — recebe laudos/certificados de qualidade, imagens do blog, etc.

## Padrão de deploy (visto no Dockerfile do av-hub)

Build multi-stage: `deps` (npm ci) → `builder` (next build) → `runner` (Node 20 alpine, output standalone do Next.js, usuário não-root `nextjs`, porta 3000). Sem Nginx — o Traefik já faz esse papel na frente.

## Identidade compartilhada

Mesmo App Registration do Azure AD reaproveitado entre Backlog Ágil e av-hub — só adicionar redirect URI/escopo para um app novo. **Exceção:** o [[App-PCP-Visao-Geral|app-pcp]] não usa Azure AD (login só por usuário/senha, público de chão de fábrica sem e-mail corporativo).

## Pipeline Omie (novo em 07/10)

O `omie-elt-pipeline` ([[Omie-ELT-Pipeline]]) não é um app Next.js: é um conjunto de processos Node que precisa de **Redis** e de um **Postgres externo** (o do cluster acima; o compose do pipeline não sobe Postgres). Pelo `docker-compose` e pelo PM2 do repositório:

| Item | Detalhe |
|---|---|
| Processos | 6 apps: `extract-worker`, `load-worker`, `scheduler`, `scraping-worker`, `envio-oc-worker`, `dashboard` |
| Compose | Redis + os mesmos 6 processos (Postgres de fora) |
| Imagem do scraping | `Dockerfile.scraping` (inclui Chromium para o Playwright) |
| Dashboard | Bull Board na porta **3011**, com basic auth; 5 filas (`omie-extract`, `omie-load`, `omie-load-realtime`, `omie-query`, `omie-envio-oc`) |
| Pool de conexões | `PG_POOL_MAX=60` (load-worker com concorrência 40/10) — dimensionar junto com o limite de conexões do Postgres |
| Saída para fora | API do Omie, API do BCB (PTAX) e API do av-hub (`AVHUB_API_URL`, envio de OC) |

O pipeline fica na **VPS 1** (✅ Nathan, 07/10). Se roda no Coolify (como as demais aplicações) ou em outro formato **não consta na ficha de auditoria** `[inferido]` — confirmar com quem faz o deploy.

## Ver também
- [[Schema-Postgres-Multi-Dominio]]
- [[Omie-ELT-Pipeline]]
- [[PRD-Estoque-Visao-Geral]]
