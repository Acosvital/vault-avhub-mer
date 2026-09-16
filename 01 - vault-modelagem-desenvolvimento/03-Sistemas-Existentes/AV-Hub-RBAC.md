---
tags: [erp-acos-vital, av-hub, rbac]
criado: 2026-09-16
---

# av-hub — RBAC (Perfis, Telas, Permissões)

Sistema de autorização completo e **já em produção**, resolvido inteiramente no Postgres (schema `auth`), não via grupos do Azure AD.

## Estrutura

- **usuarios** ↔ **perfis** ↔ **telas** ↔ **permissões** (ação: `pode_visualizar`/`pode_criar`/`pode_editar`/`pode_deletar`).
- O menu do usuário (árvore de telas + permissões efetivas) é resolvido uma vez no login e embutido no JWT da sessão (`session.user.menu`).
- `hasPermission(menu, telaId, acao)` — busca recursiva na árvore de menu.
- `requirePermission(telaId, acao)` — guard usado em toda rota de API (`app/api/**/route.ts`).
- Telas de cadastro próprias: Perfis, Telas, Permissões (com edição em massa via `BulkPermissaoModal`), Usuários, Usuários×Perfis.
- Campo "Tela inicial por perfil" (`perfis.tela_inicial_id`) — redireciona o usuário pós-login para a tela certa (substituindo uma lógica antiga hardcoded por nome de perfil).
- A coluna `usuarios.anonymizedAt` **não existe** em `auth.usuarios` — a tabela tem `ativo`, `deleted_at`/`deleted_by`, mas nenhum campo de anonimização dedicado. Não há suporte a anonimização LGPD nesta tabela.

## Por que isso importa para o ERP unificado

O Estoque não usa autorização via grupos do Azure AD para segregação de função (comprador/aprovador/almoxarife/qualidade/gestor) — modelo diferente do que já está em produção aqui. Como o Estoque mora no mesmo banco do MES, ele **reaproveita** o RBAC que já existe lá (telas/perfis/permissões do `api-pcp`), não cria uma terceira implementação — continuam sendo só 2 implementações independentes no total (av-hub e MES). Ver [[Estoque-Regras-Negocio]] e [[MES-Arquitetura-Decisoes]] (decisão 3), e a discussão completa em [[Achado-Duplicacao-RBAC]].

O [[App-PCP-Visao-Geral|app-pcp]] tem sua **própria** implementação paralela e independente deste mesmo padrão (perfis/telas/permissões/usuários), num backend Prisma separado — confirmado em detalhe: `telas`/`perfis`/`permissoes` (com `BulkPermissaoModal` próprio) e `usuarios`/`usuarios-perfis`, estruturalmente idêntico ao av-hub mas com dado e backend 100% separados.

## Ver também
- [[AV-Hub-Arquitetura-BFF]]
- [[Achado-Duplicacao-RBAC]]
- [[Estoque-Regras-Negocio]]
