---
tags: [erp-acos-vital, av-hub]
criado: 2026-09-16
---

# av-hub — Visão Geral

**Repositório:** `av-hub-main` · Next.js 16 (App Router) + MUI + NextAuth.
**Status:** ✅ Em produção, em evolução ativa.
**O que é:** o Hub comercial/administrativo da Aços Vital — o candidato natural a virar o núcleo do [[Home|ERP de altíssimo nível]].

## Papel no fluxo operacional

Cobre a [[Entrada-Comercial|entrada comercial]] (captura pedidos do Omie) e boa parte do acompanhamento comercial/financeiro de um pedido (situação, autorização, faturamento, devolução) — mas **não** cobre execução de produção (isso está, parcialmente, no [[App-PCP-Visao-Geral|app-pcp]]) nem estoque/compras/recebimento (isso é só um PRD, ver [[PRD-Estoque-Visao-Geral]]).

## Principais características técnicas

- [[AV-Hub-Arquitetura-BFF|Arquitetura BFF pura]] — não acessa banco diretamente, só faz proxy para um backend externo via `API_URL`.
- [[AV-Hub-RBAC|RBAC completo e em produção]] — perfis/telas/permissões relacionais no Postgres.
- Autenticação: Azure AD (SSO corporativo) + fallback de credencial, via NextAuth.
- Deploy: Docker multi-stage (Node 20 alpine, build standalone do Next.js), rodando em Coolify/Traefik — ver [[Infraestrutura-Self-Hosted]].

## Módulos

Ver [[AV-Hub-Modulos]] para o mapa completo: RH, Vendas, Portal do Vendedor, Portal do Gerente/Equipe, Portal do PCP, Dashboards, Orçamento, Fechamento, Cadastros, Experimental.

## Cultura de engenharia observada

Documentação extremamente disciplinada: arquivos de "contrato" datados (`OK -`/`ENVIAR -`) documentando decisões e handoffs para o time de backend/DBA externo, changelogs detalhados com auditoria de arquitetura (múltiplos agentes, verificação adversarial), correções sempre por causa raiz. O time de frontend do Hub **não tem acesso direto ao backend/schema** — mudanças viram documentos de contrato entregues a outra ponta.

## Ver também
- [[AV-Hub-Arquitetura-BFF]]
- [[AV-Hub-RBAC]]
- [[AV-Hub-Modulos]]
- [[Schema-Postgres-Multi-Dominio]]
