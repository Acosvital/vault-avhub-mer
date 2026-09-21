---
tags: [erp-acos-vital, arquitetura, infraestrutura]
criado: 2026-09-16
---

# Infraestrutura Self-Hosted

Confirmado tanto pelo [[PRD-Estoque-Visao-Geral|PRD do Estoque]] quanto pelo `Dockerfile` do [[AV-Hub-Visao-Geral|av-hub]]:

## Topologia (3 VPS)

- **VPS1** — aplicações Next.js no Coolify, atrás do Traefik (mesmo padrão do Backlog Ágil, do blog e do av-hub).
- **VPS2** — cluster Postgres (schema por domínio, ver [[Schema-Postgres-Multi-Dominio]]), com WAL de backup já configurado (cobre automaticamente qualquer schema novo).
- **VPS3** — MinIO (object storage) — recebe laudos/certificados de qualidade, imagens do blog, etc.

## Padrão de deploy (visto no Dockerfile do av-hub)

Build multi-stage: `deps` (npm ci) → `builder` (next build) → `runner` (Node 20 alpine, output standalone do Next.js, usuário não-root `nextjs`, porta 3000). Sem Nginx — o Traefik já faz esse papel na frente.

## Identidade compartilhada

Mesmo App Registration do Azure AD reaproveitado entre Backlog Ágil e av-hub — só adicionar redirect URI/escopo para um app novo. **Exceção:** o [[App-PCP-Visao-Geral|app-pcp]] não usa Azure AD (login só por usuário/senha, público de chão de fábrica sem e-mail corporativo).

## Ver também
- [[Schema-Postgres-Multi-Dominio]]
- [[PRD-Estoque-Visao-Geral]]
