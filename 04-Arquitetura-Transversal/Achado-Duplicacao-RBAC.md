---
tags: [erp-acos-vital, arquitetura, achado, governanca]
criado: 2026-09-16
atualizado: 2026-10-07
---

# Achado — Duplicação de Identidade/Permissão

> **Atualização de 07/10/2026 — a conclusão continua valendo (2 implementações independentes de identidade: av-hub e MES), com duas observações.** (1) O `api-comercial` do av-hub (só em `develop`) **não cria cadastro de usuários**: valida o `backendToken` da `api-acos-vital` e acrescenta um **modelo de permissão próprio** (`PerfilComercial`: cargo e capacidades) — uma 2ª camada sobre o RBAC do Hub, ver [[AV-Hub-RBAC]] e [[AV-Hub-Comercial-Suprimentos]]. (2) A `api-acos-vital` passou a aplicar RBAC no servidor (`auth.fn_autorizar`; ligado em produção: **não verificado**), enquanto no MES o `UsuariosController` e o `SetoresController` do `api-pcp` seguem **sem guard** (lacuna de segurança conferida no código `develop` do MES). Leitura de código, produção não conferida.
## O problema

Existem hoje **dois sistemas de identidade e permissão completamente paralelos e redundantes**:

1. Backend do [[AV-Hub-Visao-Geral|av-hub]] — perfis/telas/permissões/usuários, Azure AD + credenciais, `x-api-key` server-to-server.
2. Backend do [[App-PCP-Visao-Geral|app-pcp]] (`api-pcp`, Prisma) — perfis/telas/permissões/usuários **próprios**, só usuário/senha, JWT Bearer.

Evidência concreta: as pastas `cadastros/acessos/{perfis,permissoes,telas,usuarios,usuarios-perfis}` existem **idênticas** nos dois repositórios, assim como `lib/permissions.ts`, `requirePermission.ts`, `usePermission.ts` — os dois partiram do mesmo `next-boilerplate` e divergiram depois, mantendo a cópia da tela de administração de RBAC em cada um.

## Por que isso não é (necessariamente) um erro

Os públicos são diferentes: corporativo com e-mail (Azure AD) vs. chão de fábrica sem e-mail. Essa divergência de método de login tem justificativa real.

## Por que isso importa mesmo assim

A **duplicação do modelo relacional de autorização em si** (não o método de login) é redundante — dois cadastros de usuários, dois cadastros de perfis, duas matrizes de permissão para manter em sincronia manualmente. Some a isso que o [[PRD-Estoque-Visao-Geral|PRD do Estoque]] propõe um **terceiro modelo**, via grupos do Azure AD — o que criaria três abordagens de autorização coexistindo no mesmo "ERP".

## Decisão a considerar (parcialmente resolvida)

Se o objetivo é um ERP de altíssimo nível unificado, vale decidir conscientemente: manter N silos de identidade (um por app, com alguma ponte) ou convergir para um serviço de identidade/autorização único que todo módulo consome.

Para o Estoque, a decisão já foi tomada — **não** vai usar grupos do Azure AD (proposta original do PRD, descartada) nem vira biblioteca compartilhada com o av-hub. Como o Estoque passa a morar dentro do **mesmo banco do MES**, ele **reaproveita** o RBAC que já existe ali (telas/perfis/permissões + `PerfilSetor` do `api-pcp`) — não é uma implementação nova, é reuso direto da que já existe. Ou seja: a contagem continua em **2 implementações independentes** (av-hub e MES, este último agora servindo produção **e** Estoque juntos), não 3 — a duplicação descrita neste arquivo **não foi resolvida por convergência entre av-hub e MES**, mas também não piorou. Ver [[MES-Arquitetura-Decisoes]] (decisão 3) e [[Decisoes-Chave-ERP]] para o estado atual da pergunta "identidade única ou múltipla?", que segue em aberto para o restante do ERP.

## Decisão de 07/10/2026

✅ Os nomes **MES** e **PCP** ficam como estão (Nathan). Ver [[Registro-de-Decisoes-2026-10-07]], item 54. Sobre os guards do `api-pcp`, a proposta 🟡 (Robert) está no item 12 do mesmo Registro.

## Ver também
- [[AV-Hub-RBAC]]
- [[App-PCP-Visao-Geral]]
- [[Estoque-Regras-Negocio]]
- [[Decisoes-Chave-ERP]]
