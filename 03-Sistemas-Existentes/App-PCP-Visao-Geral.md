---
tags: [erp-acos-vital, app-pcp]
criado: 2026-09-16
atualizado: 2026-09-16
---

# app-pcp — Visão Geral

**Frontend:** `app-pcp-main` (nome interno: `controle-pcp`) · Next.js 16 + MUI + NextAuth.
**Backend real:** `api-pcp` — **NestJS + Prisma** (não Express simples), analisado em detalhe nesta rodada.
**Status:** 🚧 Em construção ativa por Robert — o **backend está bem mais maduro que o frontend enviado** (ver [[App-PCP-Backend-Producao]]). Todo o backend (schema + módulos) foi construído em ~10 dias corridos (18-28/08/2026), confirmado pela timeline de migrations do Prisma.
**O que é:** o sistema de **Programação e Controle de Produção de chão de fábrica**, hoje focado em **Flanges** (ver [[Fabricacao-Flanges]]).

> ⚠️ Não confundir com o "[[Achado-Ambiguidade-PCP|Portal PCP]]" do [[AV-Hub-Visao-Geral|av-hub]] — mesmo nome, propósito completamente diferente.

## Backend separado, mas não isolado do av-hub

`api-pcp` tem banco/schema Prisma próprio, fora do cluster multi-schema do av-hub — mas **não é isolado operacionalmente**: a consulta de pedido ao Omie (`src/pedidos/omie-integracao.ts`) não fala com o Omie diretamente — faz `fetch` contra o **gateway `api.acosvital.com.br`** (a mesma API `api-acos-vital` do av-hub), autenticado por `x-api-key`, na rota `GET /pedido_venda_itens/{numero}` (a mesma `vw_pedido_venda_itens` que o Portal do Vendedor usa para "produtos mais vendidos" — ver [[AV-Hub-Portal-Vendedor-Plano]]). **Dependência cruzada real entre os dois sistemas**, não só semelhança de padrão.

## Autenticação e RBAC

Só usuário/senha (sem Azure AD) — "o pessoal da fábrica não tem e-mail corporativo". Login simples, sem SSO, sem "esqueci a senha". Backend usa `bcrypt` + JWT (`@nestjs/jwt`, payload `{sub, username}`).

**Achado importante: o RBAC (perfis/telas/permissões) está totalmente implementado no backend, mas deliberadamente NÃO aplicado a nenhum dos 16 controllers de domínio ainda** — decisão documentada no próprio `TODO.md` do projeto: a equipe está esperando desenhar um modelo de permissão **por instância de setor** (um líder de setor só devendo enxergar seu próprio setor) antes de ligar o guard globalmente, porque o RBAC genérico de tela/CRUD não expressa isso sozinho. Hoje só existe `JwtAuthGuard` (autenticado, mas sem controle fino) em produção — **ver [[Achado-Duplicacao-RBAC]] e [[Decisoes-Chave-ERP]] para o porquê isso é relevante para o ERP unificado.**

Existe também um **RBAC paralelo específico**, `PerfilSetor` (`podeVisualizar`/`podeAtuar` por perfil×setor) — não é o mesmo mecanismo do RBAC de telas; gate hoje só a tela de "Movimentações" e é explicitamente documentado como **conveniência de UI, não fronteira de segurança** (a checagem de verdade fica no service).

## Modelo de domínio

Ver [[App-PCP-Modelo-Producao]] (visão frontend/roteiro) e [[App-PCP-Backend-Producao]] (modelo real de produção: ItemParcial, Entregas, Embalagens, Divergências, Dashboard).

## Estado de maturidade — corrigido nesta rodada

- Cadastros operacionais, consulta Omie, listagem e criação completa de pedidos (com roteiro) já funcionam no frontend.
- **O backend já tem endpoints prontos de dashboard de produção (`GET /dashboard`, `GET /dashboard/tv`) com contagem por status, atrasados, urgentes, breakdown por setor e últimas movimentações** — a home vazia do frontend é puramente uma lacuna de UI, não de dado. Ver [[App-PCP-Backend-Producao]].
- **O backend já modela um workflow de produção muito mais rico que o roteiro simples visto no frontend**: estado por item de produção (`ItemParcial`, 8 estados), divisão/consolidação de lote, devolução entre setores, entregas parciais ao cliente, embalagem/paletização, anexos por etapa, histórico imutável de movimentação. Nada disso tem tela no frontend enviado ainda.
- **Divergências têm estado terminal sem reabertura** (`RESOLVIDA`/`CANCELADA` não voltam) — potencial repetição do "bug de beco sem saída" que o [[Estoque-Riscos|PRD do Estoque]] cita como lição aprendida de uma versão anterior do PCP. Vale confirmar com Robert se isso é intencional ou um gap real.

## Ver também
- [[App-PCP-Modelo-Producao]]
- [[App-PCP-Backend-Producao]]
- [[Fabricacao-Flanges]]
- [[Achado-Ambiguidade-PCP]]
- [[Decisoes-Chave-ERP]]
