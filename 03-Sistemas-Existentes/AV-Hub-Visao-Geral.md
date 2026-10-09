---
tags: [erp-acos-vital, av-hub]
criado: 2026-09-16
atualizado: 2026-10-08
---

# av-hub — Visão Geral

> Status: decidido | no código | em produção (verificado em 07/10/2026 pelo dump, onde indicado). Decisões da rodada em [[Registro-de-Decisoes-2026-10-07]].

> **Atualização de 07/10/2026 — auditoria código × vault** (leitura de código: `develop` 996e320 e `main` cfed113; produção **não** conferida). (1) O Hub **não é mais "BFF puro de um backend só"**: há **dois backends** — `API_URL` (`api-acos-vital`) e `COMERCIAL_API_URL` (`api-comercial`, Node 22, Prisma, dentro do próprio repo; **só em `develop`**) — ver [[AV-Hub-Comercial-Suprimentos]]. (2) O BFF usa o **`backendToken`** (não `session.accessToken`) — ver [[AV-Hub-Arquitetura-BFF]]. (3) A API foi reestruturada e o código passou a ter RBAC por rota (ligado em produção: **não verificado**) — ver [[AV-Hub-API-Estado-Atual]] e [[AV-Hub-RBAC]]. (4) O mapa de módulos ganhou RH, Comercial/Suprimentos, Liberação de pedido, Notas Fiscais Manuais e Comissões — ver [[AV-Hub-Modulos]]. (5) `main` parou em #153; `develop` está à frente (92 `page.tsx` contra 79 em `main`; 183 handlers `route.ts` em `app/api`).

**Repositório:** `av-hub-main` · Next.js 16 (App Router) + MUI + NextAuth.
**Status:** ✅ Em produção, em evolução ativa (produção não conferida na auditoria de 07/10/2026; o que é só de `develop` está marcado nas notas de módulo).
**O que é:** o Hub comercial/administrativo da Aços Vital — o candidato natural a virar o núcleo do [[Home|ERP de altíssimo nível]].

## Papel no fluxo operacional

Cobre a [[Entrada-Comercial|entrada comercial]] (captura pedidos do Omie) e boa parte do acompanhamento comercial/financeiro de um pedido (situação, autorização, faturamento, devolução) — mas **não** cobre execução de produção (isso está, parcialmente, no [[App-PCP-Visao-Geral|app-pcp]]) nem estoque/compras/recebimento (isso é só um PRD, ver [[PRD-Estoque-Visao-Geral]]).

## Principais características técnicas

- **Testes e CI (conferido em 08/10, `develop` `bd1ae48`):** três workflows em `.github/workflows/`. `ci.yml` (PR e `main`): `npm run check`, `npm audit` (nível crítico) e `npm run build`. `api-comercial.yml` (PR, `main` e `develop`): lint, typecheck, testes unitários e de integração e `npm audit`. `e2e-comercial.yml` (PR e `develop`): sobe a stack e roda o Playwright (`npm run test:e2e`, specs `navegacao` e `proposta`, só do Comercial). Não há teste automatizado das telas de Vendas, Compras ou Comissões.
- [[AV-Hub-Arquitetura-BFF|Arquitetura BFF]] — não acessa banco diretamente, só faz proxy para backends externos: `API_URL` (`api-acos-vital`) e, **desde 05/10 só em `develop`**, `COMERCIAL_API_URL` (`api-comercial`, dentro do repo) (atualizado em 07/10). Era "BFF puro, só `API_URL`".
- [[AV-Hub-RBAC|RBAC completo e em produção]] — perfis/telas/permissões relacionais no Postgres; a API também aplica RBAC por rota (`auth.fn_autorizar`), **ligado em produção: não verificado** (atualizado em 07/10).
- Autenticação: Azure AD (SSO corporativo) + fallback de credencial, via NextAuth.
- Deploy: Docker multi-stage (Node 20 alpine, build standalone do Next.js; sobe com `--max-http-header-size=65536` por causa do JWT com menu), rodando em Coolify/Traefik na **VPS 1** (bancos na VPS 2, arquivos na VPS 3; ✅ Nathan, 07/10) — ver [[Infraestrutura-Self-Hosted]]. O `api-comercial` tem Dockerfile próprio, **Node 22**, porta 3001 (conferido no código, atualizado em 07/10).

## Módulos

Ver [[AV-Hub-Modulos]] para o mapa completo: Vendas, Portal do Vendedor, Portal do Gerente/Equipe, Portal do PCP, Dashboards, Orçamento, Compras, Comercial & Suprimentos, Fechamento, Cadastros, RH, Liberação de pedido, Notas Fiscais Manuais, Comissões, Experimental (atualizado em 07/10: incluídos Comercial & Suprimentos, RH, Liberação, NF Manuais e Comissões).

## Cultura de engenharia observada

Documentação extremamente disciplinada: arquivos de "contrato" datados (`OK -`/`ENVIAR -`) documentando decisões e handoffs para o time de backend/DBA externo, changelogs detalhados com auditoria de arquitetura (múltiplos agentes, verificação adversarial), correções sempre por causa raiz. O time de frontend do Hub **não tem acesso direto ao backend/schema** — mudanças viram documentos de contrato entregues a outra ponta.

## Ver também
- [[AV-Hub-Arquitetura-BFF]]
- [[AV-Hub-RBAC]]
- [[AV-Hub-Modulos]]
- [[AV-Hub-Comercial-Suprimentos]]
- [[AV-Hub-API-Estado-Atual]]
- [[Schema-Postgres-Multi-Dominio]]
