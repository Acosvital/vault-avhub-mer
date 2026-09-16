---
tags: [erp-acos-vital, arquitetura, achado, governanca]
criado: 2026-09-16
---

# Achado — Duplicação de Identidade/Permissão

## O problema

Existem hoje **dois sistemas de identidade e permissão completamente paralelos e redundantes**:

1. Backend do [[AV-Hub-Visao-Geral|av-hub]] — perfis/telas/permissões/usuários, Azure AD + credenciais, `x-api-key` server-to-server.
2. Backend do [[App-PCP-Visao-Geral|app-pcp]] (`api-pcp`, Prisma) — perfis/telas/permissões/usuários **próprios**, só usuário/senha, JWT Bearer.

Evidência concreta: as pastas `cadastros/acessos/{perfis,permissoes,telas,usuarios,usuarios-perfis}` existem **idênticas** nos dois repositórios, assim como `lib/permissions.ts`, `requirePermission.ts`, `usePermission.ts` — os dois partiram do mesmo `next-boilerplate` e divergiram depois, mantendo a cópia da tela de administração de RBAC em cada um.

## Por que isso não é (necessariamente) um erro

Os públicos são diferentes: corporativo com e-mail (Azure AD) vs. chão de fábrica sem e-mail. Essa divergência de método de login tem justificativa real.

## Por que isso importa mesmo assim

A **duplicação do modelo relacional de autorização em si** (não o método de login) é redundante — dois cadastros de usuários, dois cadastros de perfis, duas matrizes de permissão para manter em sincronia manualmente. Some a isso que o [[PRD-Estoque-Visao-Geral|PRD do Estoque]] propõe um **terceiro modelo**, via grupos do Azure AD — o que criaria três abordagens de autorização coexistindo no mesmo "ERP".

## Decisão a considerar

Se o objetivo é um ERP de altíssimo nível unificado, vale decidir conscientemente: manter N silos de identidade (um por app, com alguma ponte) ou convergir para um serviço de identidade/autorização único que todo módulo consome — Estoque incluso, usando o mesmo padrão perfis/telas/permissões já provado em produção no av-hub, em vez de inventar grupos do Azure AD.

## Ver também
- [[AV-Hub-RBAC]]
- [[App-PCP-Visao-Geral]]
- [[Estoque-Regras-Negocio]]
- [[Decisoes-Chave-ERP]]
