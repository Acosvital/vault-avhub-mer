---
tags: [erp-acos-vital, av-hub, rbac]
criado: 2026-09-16
atualizado: 2026-09-16
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
- ~~`usuarios.anonymizedAt` — suporte a anonimização estilo LGPD~~ ⚠️ **Corrigido (16/09):** essa coluna **não existe** em `auth.usuarios` no dump real — a tabela tem `ativo`, `deleted_at`/`deleted_by`, mas nenhum campo de anonimização dedicado. Documentação anterior estava incorreta/antecipada; não há suporte a anonimização LGPD confirmado hoje.

## Camada adicional: escopo por linha (row-level security)

O RBAC acima decide **quais telas/ações** um usuário pode usar; **quais linhas** ele vê dentro dessas telas é resolvido por uma camada separada de escopo por unidade/setor — ver [[RH-Escopo-Row-Level-Security]] para o detalhamento completo (inclui a convenção "sem vínculo = irrestrito" vs. "sem vínculo = vazio", o override `setor_irrestrito`, e o padrão de "papel implícito por combinação de permissões" achado na tela de Solicitações de Vagas).

## Por que isso importa para o ERP unificado

O [[PRD-Estoque-Visao-Geral|PRD do Estoque]] **propunha originalmente** autorização via **grupos do Azure AD** para segregação de função (comprador/aprovador/almoxarife/qualidade/gestor) — modelo diferente do que já está em produção aqui. Essa proposta foi **descartada** na conversa de arquitetura do MES (16/09): como o Estoque passa a morar no mesmo banco do MES, ele **reaproveita** o RBAC que já existe lá (telas/perfis/permissões do `api-pcp`), não cria uma terceira implementação — continuam sendo só 2 implementações independentes no total (av-hub e MES), não grupos do Azure AD. Ver [[Estoque-Regras-Negocio]] e [[MES-Arquitetura-Decisoes]] (decisão 3), e a discussão histórica completa em [[Achado-Duplicacao-RBAC]].

O [[App-PCP-Visao-Geral|app-pcp]] tem sua **própria** implementação paralela e independente deste mesmo padrão (perfis/telas/permissões/usuários), num backend Prisma separado — confirmado em detalhe: `telas`/`perfis`/`permissoes` (com `BulkPermissaoModal` próprio) e `usuarios`/`usuarios-perfis`, estruturalmente idêntico ao av-hub mas com dado e backend 100% separados.

## Ver também
- [[AV-Hub-Arquitetura-BFF]]
- [[Achado-Duplicacao-RBAC]]
- [[Estoque-Regras-Negocio]]
- [[RH-Escopo-Row-Level-Security]]
