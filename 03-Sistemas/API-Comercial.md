---
tags: [sistemas, api-comercial, comercial, suprimentos, express, prisma]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Pablo
fontes: [HUB b55ac55, pasta C:\Users\nathan.silva\Desktop\TI\NATHAN\00 - HUB\api-comercial (README.md, src/app.ts, src/config/env.ts, src/domain/permissoes/capacidades.ts, prisma/), v1 AV-Hub-Comercial-Suprimentos]
---

# API Comercial (`api-comercial`)

Backend do módulo **AV Comercial & Suprimentos**: propostas, ofertas de fornecedor, custo de referência, configurador de telha, solicitações de custo, dashboards e a sincronização com o Omie (produtos, fornecedores, pedidos de compra). Dono: Pablo. Está **fora do fluxo de Atividades**: o pedido de venda do Omie entra no fluxo pelo av-hub ([[AV-Hub-API]]), e não por aqui. Mesmo assim ele compartilha RBAC, usuários e a fonte Omie com o av-hub. Anexo: [[Comercial-Suprimentos]]. Selos: [[Regras-do-Vault]].

## Onde mora e como roda

- **Repositório:** pasta `api-comercial/` dentro do repositório do HUB (HUB b55ac55, develop) ✅ `00 - HUB/api-comercial`. CI próprio em `.github/workflows/api-comercial.yml`, só quando a pasta muda ✅ README.
- **Stack:** Node 22, Express 5, TypeScript (ESM), Prisma 7, PostgreSQL (schema **`core_comercial`**), zod 4 (mensagens em pt-BR), pino, decimal.js, Vitest + supertest ✅ `package.json`, `src/app.ts:20-22`.
- **Banco:** schema `core_comercial` com 30 models e 13 migrations de `20261001000000_mvp_inicial` a `20261014...usuarios_comerciais_diretorio` ✅ `prisma/schema.prisma:13`, `prisma/migrations/`. Fora do dump do av-hub; o `Dump Avhub (Esqueleto).sql` não contém `core_comercial` ✅ (nenhum `CREATE SCHEMA core_comercial`). Ver [[Schemas-Postgres]].
- **Porta e docs:** 3001; `/docs` (Scalar) e `/api-docs-json` quando `DOCS_ENABLED` não é `false` ✅ `src/app.ts:81-84`, `config/env.ts`.
- **Saúde:** `GET /health` testa o banco (200 `ok` ou 503) ✅ `src/app.ts:73-80`.

## Camadas da requisição (`src/app.ts`)

`helmet` → `pino-http` (aceita `x-request-id` curto) → `express.json` 8 MB → CORS por `CORS_ORIGINS` → tudo em `/v1`: rate limit por IP (limite alto, antes da identidade), **`apiKey`** (`x-api-key` do BFF do HUB), **`autenticacao`** (JWT do Hub), rate limit por usuário (`RATE_LIMIT_MAX`, padrão 300/min) ✅ `app.ts:44-56,90-94`.

- **Identidade:** sempre do JWT emitido pelo `api-acos-vital` (HS256 com `JWT_SECRET` = o `USUARIO_TOKEN_SEGREDO` dela, ou RS256 por `JWT_JWKS_URL`); `exp` é obrigatório; `id_usuario_sessao` em query é ignorado ✅ `middlewares/autenticacao.ts:30-60`, `config/env.ts`.
- **Permissões:** 100% do RBAC do Hub. A API lê `GET /me/permissoes` do av-hub (cache de 15 s) e transforma telas × ações e escopo de vendedores em capacidades ✅ `src/domain/permissoes/capacidades.ts:1-60`, `lib/perfisHub.ts`. Não há tabela de perfil no `core_comercial`. Detalhe em [[RBAC-e-Permissoes]].
- **Bypass de desenvolvimento:** `AUTH_DEV_BYPASS=true` só vale com `NODE_ENV` explícito `development` ou `test`; aceita `x-dev-usuario` e `x-dev-perfis` ✅ `config/env.ts:74-77`, README.
- **Convenções:** envelope de erro `{ detail, codigo?, campos? }`; paginação `{ data, total, page, limit, total_pages }`; dinheiro e quantidade em `Decimal` (strings); comandos que mudam documento exigem `If-Match` com o `ETag` (428 sem, 409 com versão velha); `POST /propostas` e `POST /solicitacoes_custo` aceitam `Idempotency-Key` ✅ README.

## Rotas (`/v1`)

Extraídas dos routers de `src/modules/**` em 14/10 ✅.

| Módulo | Rotas | Para quê |
|---|---|---|
| `cadastros` | `GET /me`, `/empresas_emissoras`, `/responsaveis`, `/cambio`, `/parametros_custo`; `PUT /parametros_custo` | usuário e capacidades, 3 empresas emissoras (AV, AU, HRM), câmbio, parâmetros de custo |
| `propostas` | `GET /propostas`, `/resumo`, `/:id`, `/:id/eventos`, `/:id/versoes`, `/:id/versoes/:revisao`, `/:id/pedido_omie` (+ `/xlsx`), `/itens/modelo`; `POST /propostas`, `/calcular`, `/itens/importar`, `/:id/duplicar`, `/:id/fechar`, `/:id/perder`, `/:id/reabrir`, `/:id/email`; `PUT /:id`, `/:id/pedido_omie`; `DELETE /:id` | ciclo da proposta, versões, e-mail ao cliente, pedido a ser digitado no Omie |
| `clientes` | `GET /clientes`, `/resumo`, `/exportar`, `/:id`, `/:id/propostas`, `/por_documento/:doc`, `/receita/:cnpj`; `POST /clientes`, `/:id/contatos`; `PUT /clientes/:id`, `/:id/contatos/:idContato`; `DELETE …/contatos/:idContato` | carteira, ficha, consulta à Receita |
| `suprimentos` | `GET /produtos`, `/produtos/:id`, `/produtos/:id/precos`, `/fornecedores` (+ `/:id`, `/exportar`, `/emails`, `/apelidos`), `/categorias`, `/ofertas` (+ `/exportar`, `/importacoes`), `/pesquisa_materiais` (+ `/:id`, `/pesquisa_materiais_cotacao`), `/historico_compras` (+ `/resumo`), `/painel_comprador`, `/pedidos_cotacao/analise`, `/pedidos_cotacao/fornecedores`, `/produtos_pendentes`; `POST /produtos`, `/ofertas`, `/ofertas/:id/invalidar`, `/pedidos_cotacao`, `/produtos_pendentes/:id/vincular`, `/fornecedores/:id/certificados`; `PUT /fornecedores/:id/perfil`, `/:id/categorias/:idCategoria`, `/fornecedores/apelidos`; `DELETE` de certificado, categoria e apelido | catálogo, ofertas, pedido de cotação, painel do comprador |
| `custos` | `GET /solicitacoes_custo`, `/telha/tabela`, `/telha/tabelas`; `POST /custos/sugerir`, `/solicitacoes_custo` (+ `/:id/assumir`, `/cancelar`, `/liberar`, `/responder`), `/telha/calcular`; `PUT /telha/tabela` | custo sugerido, solicitação ao comprador, configurador de telha |
| `dashboards`, `relatorios` | `GET /dashboards/comercial`, `/relatorios/cotacoes`, `/relatorios/gerencial` | KPIs e relatórios |
| `notificacoes` | `GET /notificacoes`; `POST /:id/lida`, `/ler_todas` | avisos in-app |
| `omie` | `GET /omie/sincronizacoes`; `POST /omie/sincronizar` | motor de sincronização |

## Sincronização com o Omie

`src/modules/omie/` trabalha sobre a interface `FonteOmie` (D-30): fonte pelo espelho do av-hub (`fonteHub.ts`, `HUB_API_URL` + `HUB_API_KEY`, produtos e fornecedores) e pedidos de compra direto na API do Omie (`pedidosOmieApi.ts`, `OMIE_MOGI_APP_KEY/SECRET` e `OMIE_UBERABA_APP_KEY/SECRET`, porque `GET /pedidos_compras` do av-hub não traz o que a tela precisa) ✅ `config/env.ts`, README. A sincronização automática roda a cada `OMIE_SYNC_INTERVALO_MIN` (padrão 15; 0 desliga), é idempotente (hash por registro bruto), incremental e em lotes; sem fonte, `POST /omie/sincronizar` responde 503 `OMIE_SEM_FONTE` ✅ `config/env.ts`, README.

**Não confundir** `core_comercial.OrdemCompra`/`ItemOrdemCompra` (espelho de pedidos de compra do Omie para análise) com `core_vendas_faturamento.ordens_compra` (a OC que nasce no av-hub e segue o circuito de compra do fluxo) ✅ `prisma/models/omie.prisma`, [[Banco-AvHub]]. A proposta fechada gera um "pedido a digitar no Omie" (xlsx); o pedido de venda só entra no fluxo quando o Omie o cria e a pipeline o traz ([[Pipeline-Omie]], nó V1).

## Variáveis de ambiente

| Variável | Uso | Padrão |
|---|---|---|
| `DATABASE_URL`, `PORT`, `NODE_ENV`, `LOG_LEVEL`, `TZ` | base | 3001, `America/Sao_Paulo` |
| `API_KEYS` | chaves aceitas em `x-api-key` (BFF) | obrigatória |
| `JWT_SECRET` ou `JWT_JWKS_URL`, `JWT_ISSUER` (`api-acos-vital`), `JWT_AUDIENCE` | validar o token do Hub | um dos dois |
| `AUTH_DEV_BYPASS` | só desenvolvimento e teste | desligado |
| `HUB_API_URL`, `HUB_API_KEY`, `HUB_UNIDADE_MOGI`, `HUB_UNIDADE_UBERABA` | espelho do Omie e `/me/permissoes`; UUIDs de `core.unidades` (Mogi `759979bd-…`, Uberaba `4ec9f957-…`) | — |
| `OMIE_MOGI_APP_KEY/_SECRET`, `OMIE_UBERABA_APP_KEY/_SECRET` | pedidos de compra direto no Omie | — |
| `OMIE_SYNC_INTERVALO_MIN` | sincronização automática | 15 |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS`, `EMAIL_REMETENTE`, `EMAIL_TRANSPORTE` | e-mail da proposta e do pedido de cotação (sem `SMTP_HOST`: 503 `EMAIL_NAO_CONFIGURADO`) | `smtp` |
| `CORS_ORIGINS`, `RATE_LIMIT_MAX`, `DOCS_ENABLED` | HTTP | vazio, 300, ligado |

BFF no HUB: `COMERCIAL_API_URL` e `COMERCIAL_API_KEY` ✅ `app/api/comercial/[...rota]/route.ts`.

## Slugs de permissão que a API consulta

`propostas`, `propostas-delegacao` (criar = pode delegar), `propostas-valores` (visualizar = vê valores), `custo-item` (visualizar = vê custo; ou ser comprador), `relatorio-gerencial`, `painel-comprador` (editar = é comprador), `clientes` ✅ `domain/permissoes/capacidades.ts:44-52`. Os 6 perfis de desenvolvimento (`Comercial - Vendedor`, `Auxiliar`, `Gestão`, `Diretoria`, `Suprimentos - Comprador`, `Pós-venda`) ficam em `domain/permissoes/perfisDev.ts` ✅ README.

## Pontas soltas

- ❓ O schema `core_comercial` e as 13 migrations não foram conferidos contra um banco publicado (o repositório não traz dump). Quem publica é o Gustavo.
- 🟡 `GET /pedidos_compras` do av-hub vem vazio na api-test; por isso a API lê o Omie direto (README e nota v1 `AV-Hub-Comercial-Suprimentos`, resumida em [[Comercial-Suprimentos]]).
- 🟡 Migração do ERP Comercial antigo (Supabase `erp_quotations`) por `npm run migrar:erp-antigo` ✅ README.
