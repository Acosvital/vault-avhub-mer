---
tags: [erp-acos-vital, app-pcp]
criado: 2026-09-16
atualizado: 2026-10-07
---

# app-pcp — Visão Geral

> Status: decidido | no código | em produção (verificado em 07/10/2026 pelo dump, onde indicado). Decisões da rodada em [[Registro-de-Decisoes-2026-10-07]]. MES = Robert.

> **Atualização de 07/10/2026 — auditoria código × vault (leitura de `develop`, não de produção).**
> - **`main` dos dois repositórios parou em 28/08** (api-pcp `be076b2`, app-pcp `be847ac`). **Decidido (✅ Nathan, 07/10):** merge `develop` → `main` **antes do piloto** (fecha CC-04); **data e responsável: 🔴 Robert**. A `develop` roda no ambiente de homologação `https://mes-test.acosvital.com.br/` (`mes-test`, ✅ no ar; marco M2 cumprido); o `main` não foi dado como em produção. **Tudo o que está descrito abaixo como "novo" existe só na branch `develop`** (api-pcp `ca3346b`, PR #50, 07/10; app-pcp `a802a3e`, PR #34, 07/10; a `develop` do api está 54 commits à frente da `main`). Se `develop` está rodando em produção/homologação: **não verificado** — a nota anterior chamava o MES de "em produção"; isso vale no máximo para o que estava em `main` em 28/08.
> - O "backend em ~10 dias (18-28/08)" é a foto de agosto. Hoje são **50 migrations (18/08 a 06/10) e 44 modelos Prisma**; há dashboard, Movimentações, filas de setor, carteira, ordens de produção, estoque, qualidade, requisições de compra, recebimento com conferência e decisões do PCP (`/decisoes-pcp`). A home deixou de ser vazia.
> - **O RBAC "não aplicado a nenhum controller" é falso desde 04/09** (`e76e929`): `@RequirePermission` por controller (~20) e checagem `PerfilSetor` (`ensurePodeAtuar`) nos services. Mas há uma **lacuna de segurança (achado de 07/10, a confirmar com o Robert)** — ver seção "Autenticação e RBAC".
> - Login duplo (Azure AD + usuário/senha) feito em 22/09 (C1); TOTVS saiu do `SistemaOrigem` (09/09). O setor Recebimento está descrito em [[App-PCP-Recebimento-Conferencia]].

**Frontend:** `app-pcp-main` (nome interno: `controle-pcp`) · Next.js 16 + MUI + NextAuth (AzureAD + Credentials).
**Backend real:** `api-pcp` — **NestJS + Prisma** (não Express simples).
**Status:** 🚧 Em construção ativa por Robert — o **backend está bem mais maduro que o frontend enviado** (ver [[App-PCP-Backend-Producao]]). ~~Todo o backend (schema + módulos) foi construído em ~10 dias corridos (18-28/08/2026)~~ **(atualizado em 07/10)** A base (schema + módulos) nasceu em ~10 dias corridos (18-28/08/2026), pela timeline de migrations; desde então o `develop` chegou a 50 migrations (até 06/10), e o que veio depois de 28/08 está só na branch `develop`.
**O que é:** o sistema de **Programação e Controle de Produção de chão de fábrica**, hoje focado em **Flanges** (ver [[Fabricacao-Flanges]]).

> ⚠️ Não confundir com o "[[Achado-Ambiguidade-PCP|Portal PCP]]" do [[AV-Hub-Visao-Geral|av-hub]] — mesmo nome, propósito completamente diferente.

## Backend separado, mas não isolado do av-hub

`api-pcp` tem banco/schema Prisma próprio, fora do cluster multi-schema do av-hub — mas **não é isolado operacionalmente**: a consulta de pedido ao Omie (`src/pedidos/omie-integracao.ts`) não fala com o Omie diretamente — faz `fetch` contra o **gateway `api.acosvital.com.br`** (a mesma API `api-acos-vital` do av-hub), autenticado por `x-api-key`, na rota `GET /pedido_venda_itens/{numero}` (a mesma `vw_pedido_venda_itens` que o Portal do Vendedor usa para "produtos mais vendidos" — ver [[AV-Hub-Portal-Vendedor-Plano]]). **Dependência cruzada real entre os dois sistemas**, não só semelhança de padrão.

## Autenticação e RBAC

**(atualizado em 07/10)** Hoje há **login duplo** (C1, concluído em 22/09, `11e73e7`, PR #35 api / #16 app): `POST /auth/azure` (protegido pela chave `MES_INTERNAL_API_KEY`, usada pelo BFF do app-pcp) para o pessoal de escritório, e `POST /auth/login` (usuário/senha) para o chão de fábrica; no app, NextAuth com AzureAD + Credentials. ~~Só usuário/senha (sem Azure AD)~~ — o texto original (agosto) dizia "o pessoal da fábrica não tem e-mail corporativo"; isso continua valendo para o chão de fábrica. Backend usa `bcrypt` + JWT (`@nestjs/jwt`, payload `{sub, username}`).

~~O RBAC está totalmente implementado no backend, mas deliberadamente NÃO aplicado a nenhum dos 16 controllers de domínio ainda~~ **(atualizado em 07/10 — falso desde 04/09, `e76e929`).** Estado conferido no código (`develop`): `Usuario → Perfil → Permissao → Tela` (CRUD por tela) com `PermissionsGuard` e `@RequirePermission` **por controller** (~20 controllers); **não há `APP_GUARD` global** (a tarefa C5 do cronograma está parcial). Além disso o `PerfilSetor` (default-deny) é checado **no service** (`ensurePodeAtuar`) em itens-parciais, entregas, compras e recebimento. Menu e permissões vão na sessão NextAuth. O `TODO.md` do api-pcp (24/08), que justificava o adiamento, está **desatualizado**. **Ver [[Achado-Duplicacao-RBAC]] e [[Decisoes-Chave-ERP]] para o porquê isso é relevante para o ERP unificado.**

**Lacuna de segurança — achado de 07/10/2026, a confirmar com o Robert (leitura de código, `develop`):**
- `UsuariosController` (POST/GET/PATCH/DELETE) e `SetoresController` (CRUD) **não têm nenhum guard** no api-pcp; só `:id/senha` e `:id/painel` têm JWT.
- Estes controllers têm **só JWT, sem `@RequirePermission`**: pedidos, itens-pedido, divergencias, anexos, observacoes, roteiro-item, dashboard, relatorios, auditoria.
- Hoje a barreira é o BFF do app-pcp. **Se a api-pcp está exposta na rede, essas rotas ficam abertas ou sem controle fino: a exposição de rede da api-pcp não foi verificada** (🔴 Gustavo, item 13).
- **Guards do `api-pcp`:** 🟡 proposta adotada (Robert valida, item 12 do Registro): `JwtAuthGuard` + `PermissionsGuard` com `@RequirePermission` em `UsuariosController` e `SetoresController`, como em `perfis.controller.ts`; `GET /setores` fica só com sessão e o login Azure não pode ser bloqueado. 🔴 **Exposição de rede da `api-pcp` (há domínio público no Coolify?): Gustavo** (item 13).
- O RBAC por **filial** (C3) **não foi iniciado**: `PerfilSetor` continua `(perfil, setor, podeVisualizar, podeAtuar)`, sem filial; a filial só aparece em `Deposito.codigoEmpresa`. Ver DEC-1 em [[MES-Arquitetura-Decisoes]].

O `PerfilSetor` (`podeVisualizar`/`podeAtuar` por perfil×setor) é um **RBAC paralelo** ao de telas. **(atualizado em 07/10)** Deixou de gatear só "Movimentações": o service o consulta nas ações de itens-parciais, entregas, compras e recebimento. A documentação original o chamava de "conveniência de UI, não fronteira de segurança"; a checagem de verdade fica no service (e é aí que ele vale).

## Modelo de domínio

Ver [[App-PCP-Modelo-Producao]] (visão frontend/roteiro), [[App-PCP-Backend-Producao]] (modelo real de produção: ItemParcial, Entregas, Embalagens, Divergências, Dashboard) e [[App-PCP-Recebimento-Conferencia]] (setor Recebimento, setores do MES e slugs de tela).

**Prisma (conferido no código, `develop`, 07/10):** 44 modelos em 7 arquivos — `producao.prisma` 14, `estoque.prisma` 9 (Deposito, Localizacao, Material, Fornecedor, Lote, Rnc, MovimentoEstoque, SaldoEstoque, Reserva), `fabricas.prisma` 6, `auth.prisma` 5, `compras.prisma` 5, `integracao.prisma` 3 (outbox `IntegracaoAvhubEnvio`, `IntegracaoAvhubCursor`, `RequisicaoCompraEventoAvhub`), `auditoria.prisma` 2. Todos no schema `public` (ver a divergência sobre o schema do Estoque em [[MES-Arquitetura-Decisoes]]).

## Estado de maturidade atual

> **(atualizado em 07/10)** Os itens abaixo descrevem a foto de setembro; o que mudou está marcado. Tudo na `develop`, não na `main`.

- Cadastros operacionais, consulta Omie, listagem e criação completa de pedidos (com roteiro) já funcionavam no frontend. **(atualizado em 07/10)** A criação virou **Carteira** (`/carteira`, lê `/pedidos_liberados` do av-hub desde 29/09) → **Ordens de Produção**; `POST /pedidos/completo` foi substituído por `POST /pedidos/completo/lote` (01/10; a rota antiga foi apagada no PR #50). Telas novas: estoque (saldo, reservas, movimentação, materiais, depósitos), qualidade de entrada, requisições, pedidos de compra, recebimento e decisões do PCP.
- **O backend já tem endpoints prontos de dashboard de produção (`GET /dashboard`, `GET /dashboard/tv`) com contagem por status, atrasados, urgentes, breakdown por setor e últimas movimentações** — ~~a home vazia do frontend é puramente uma lacuna de UI, não de dado~~ **(atualizado em 07/10)** existe tela de dashboard. Ver [[App-PCP-Backend-Producao]].
- **O backend modela um workflow de produção muito mais rico que o roteiro simples**: estado por item de produção (`ItemParcial`), divisão/consolidação de lote, devolução entre setores, entregas parciais ao cliente, embalagem/paletização, anexos por etapa, histórico imutável de movimentação. ~~Nada disso tem tela no frontend enviado ainda.~~ **(atualizado em 07/10)** Há tela de Movimentações e filas por setor (`ModuloSetores`). Algumas telas de estoque ainda citam dados de mock (`painel-estoque` em parte, `mapa-deposito`, `qualidade/route`).
- **Integração com o av-hub (conferido no código, `develop`):** o MES envia requisições de compra por `PUT` (contrato 34, `e7ce2c9`, 02/10) e lê os marcos por polling (contrato 35, `41bf4a6`, 05/10); lê a carteira de `/pedidos_liberados` (contrato 26). Estado por contrato em [[Integracao-AvHub-MES-Especificacao-F1]]; variáveis e chaves em [[Chaves-de-Integracao-AvHub-MES-Pipeline]].
- **Não iniciados (conferido no código):** RBAC por filial (C3); harness de testes (sem `*.spec`/jest/script `test`); `RoteiroItem` lido por mover/concluir/Expedição (regra de 28/09, C8); etapas 2–4 da transferência entre filiais; fluxo de eventos `fluxo.*` (S5).
- **Divergências têm estado terminal sem reabertura** (`RESOLVIDA`/`CANCELADA` não voltam) — potencial repetição do "bug de beco sem saída" que o [[Estoque-Riscos|PRD do Estoque]] cita como lição aprendida de uma versão anterior do PCP. Vale confirmar com Robert se isso é intencional ou um gap real.

## Ver também
- [[App-PCP-Recebimento-Conferencia]]
- [[Integracao-AvHub-MES-Especificacao-F1]]
- [[App-PCP-Modelo-Producao]]
- [[App-PCP-Backend-Producao]]
- [[Fabricacao-Flanges]]
- [[Achado-Ambiguidade-PCP]]
- [[Decisoes-Chave-ERP]]
