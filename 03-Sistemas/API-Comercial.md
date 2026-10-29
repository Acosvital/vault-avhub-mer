---
tags: [sistemas, api-comercial, comercial, suprimentos, express, prisma]
criado: 2026-10-14
atualizado: 2026-10-29
status: arquivado
dono: Pablo
fontes: [av-hub 758d5f0 (pasta api-comercial/, com LEIA-ME-LEGADO.md; README.md, src/app.ts, src/config/env.ts, src/domain/permissoes/capacidades.ts, prisma/), HUB b55ac55 (estado de 14/10), v1 AV-Hub-Comercial-Suprimentos, N16-111, N16-117]
---

# API Comercial (`api-comercial`)

**Em uma frase:** é o backend de teste que o Pablo fez para o módulo AV Comercial & Suprimentos (propostas, ofertas de fornecedor, custo de referência e sincronização com o Omie). **Saiu de produção e do BFF em 27/10 (N16-111) e ficou no repositório só para leitura (N16-117, 28/10)**: o Robert lê as regras daqui para refazer o módulo dentro da `api-acos-vital`.

> [!info] Decisões do Nathan 📝
> 14/10: a `api-comercial` não será publicada; tudo migra para a `api-acos-vital` ([[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]]).
> 27/10 (N16-111): a `api-comercial` de teste saiu do BFF e de produção. 28/10 (N16-117): a pasta fica só para leitura (`LEIA-ME-LEGADO.md`: não rodar, não publicar, não alterar). Nada novo nasce aqui.
> O BFF do av-hub (`comercialApi.ts`) só fala com a `api-acos-vital`; rota ainda não migrada responde 503 `RECURSO_NAO_MIGRADO`. As primeiras rotas já existem na API do Hub (`/comercial/*`, 28 e 29/10; ver [[AV-Hub-API]]).

## Quem usa e para quê

- **Comercial (vendedor, auxiliar, gestão, diretoria):** monta propostas e consulta clientes.
- **Suprimentos (comprador):** mantém ofertas, fornecedores e responde pedidos de custo.
- **Pablo:** foi o autor desta API de teste e acompanha o módulo; quem conduz o projeto novo é o Robert (N16-117).

## Como se encaixa no fluxo

- Fica **fora do fluxo de Atividades**. O pedido de venda entra no fluxo pelo av-hub ([[AV-Hub-API]]), não por aqui.
- A proposta fechada gera um "pedido a digitar no Omie" (planilha). O pedido só entra no fluxo quando o Omie o cria e a pipeline o traz (`V1`, [[Pipeline-Omie]]).
- Divide com o av-hub as permissões, os usuários e a fonte de dados do Omie. Anexo: [[Comercial-Suprimentos]].

## Regras que valem

- A identidade vem sempre do login do Hub. Não há perfil próprio nesta API.
- As permissões são as do Hub ([[RBAC-e-Permissoes]]).
- Mudar um documento exige a versão atual dele. Versão velha é recusada.
- Dinheiro e quantidade usam números decimais exatos.
- Não confundir as ordens de compra daqui (espelho do Omie, só para análise) com a OC do av-hub, que segue o circuito de compra.

## O que já existe e o que falta

- ✅ (no código legado) Propostas, clientes, catálogo e ofertas, custo, configurador de telha, painéis e e-mail, e sincronização com o Omie a cada 15 minutos. **Nada disto roda mais em produção.**
- ✅ Já migradas para a API do Hub: `me`, empresas emissoras, responsáveis, parâmetros de custo, propostas (criar, listar, revisar, aprovar, cancelar, copiar, transformar), cadastro de cliente no Omie e parceiros.
- 📝 Migração de 22 das 30 tabelas para a API do Hub. 8 são descartadas.
- 🟡 Defeitos deste código de teste que a migração não deve herdar: o filtro `?responsavel=` anula o escopo `proprios`, o escopo `vinculados` não restringe e o CNPJ alfanumérico é rejeitado.
- 🟡 `GET /pedidos_compras` do av-hub vem vazio na api-test, por isso a API lê o Omie direto.
- 🟡 Migração do ERP Comercial antigo por `npm run migrar:erp-antigo`.
- ✅ O schema `core_comercial` já está no banco do av-hub (dump de 29/10: 23 tabelas, 3 views, 12 funções), criado pela migration `2026-10-15_052`, e não pelas 13 migrations Prisma daqui ([[Banco-AvHub]]).

## Detalhe técnico

> **Decisão do Nathan, 14/10/2026 📝:** a `api-comercial` é só uma API de teste do Pablo, não será publicada, e o que está descrito abaixo é o estado do código de teste (como estava em 14/10, HUB b55ac55), não um serviço de produção. Desde 27/10 ela está fora do BFF e desde 28/10 é só leitura.

**Como a migração será feita:** [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] (proposta de 15/10/2026). Das 30 tabelas, 22 migram e 8 são descartadas (espelhos do Omie e do hub); a sincronização própria some e a pipeline é a fonte; o domínio de cálculo é portado como está. A auditoria de 15/10 achou defeitos **neste** código de teste (o filtro `?responsavel=` anula o escopo `proprios`, o escopo `vinculados` não restringe, CNPJ alfanumérico rejeitado, entre outros) que o LOG-52 lista como critérios de aceite para **não** serem herdados.

Backend (legado) do módulo **AV Comercial & Suprimentos**: propostas, ofertas de fornecedor, custo de referência, configurador de telha, solicitações de custo, dashboards e a sincronização com o Omie (produtos, fornecedores, pedidos de compra). Autor: Pablo. Está **fora do fluxo de Atividades**: o pedido de venda do Omie entra no fluxo pelo av-hub ([[AV-Hub-API]]), e não por aqui. Mesmo assim ele compartilha RBAC, usuários e a fonte Omie com o av-hub. Anexo: [[Comercial-Suprimentos]]. Selos: [[Regras-do-Vault]].

### Onde mora e como roda

- **Repositório:** pasta `api-comercial/` dentro do repositório `av-hub` ✅. **Fora da CI, do lint e do `tsc` do av-hub** e sem workflow próprio (o `api-comercial.yml` que existia em 14/10 saiu) ✅ `api-comercial/LEIA-ME-LEGADO.md`; só `.github/workflows/ci.yml` resta.
- **Stack:** Node 22, Express 5, TypeScript (ESM), Prisma 7, PostgreSQL (schema **`core_comercial`**), zod 4 (mensagens em pt-BR), pino, decimal.js, Vitest + supertest ✅ `package.json`, `src/app.ts:20-22`.
- **Banco:** schema `core_comercial` com 30 models e 13 migrations de `20261001000000_mvp_inicial` a `20261014...usuarios_comerciais_diretorio` ✅ `prisma/schema.prisma:13`, `prisma/migrations/`. O `Dump Avhub (Esqueleto).sql` de 14/10 não continha `core_comercial`; o dump de 29/10 contém, com 23 tabelas (o legado tinha 30 models) ✅. Ver [[Schemas-Postgres]].
- **Porta e docs:** 3001; `/docs` (Scalar) e `/api-docs-json` quando `DOCS_ENABLED` não é `false` ✅ `src/app.ts:81-84`, `config/env.ts`.
- **Saúde:** `GET /health` testa o banco (200 `ok` ou 503) ✅ `src/app.ts:73-80`.

### Camadas da requisição (`src/app.ts`)

`helmet` → `pino-http` (aceita `x-request-id` curto) → `express.json` 8 MB → CORS por `CORS_ORIGINS` → tudo em `/v1`: rate limit por IP (limite alto, antes da identidade), **`apiKey`** (`x-api-key` do BFF do HUB), **`autenticacao`** (JWT do Hub), rate limit por usuário (`RATE_LIMIT_MAX`, padrão 300/min) ✅ `app.ts:44-56,90-94`.

- **Identidade:** sempre do JWT emitido pelo `api-acos-vital` (HS256 com `JWT_SECRET` = o `USUARIO_TOKEN_SEGREDO` dela, ou RS256 por `JWT_JWKS_URL`); `exp` é obrigatório; `id_usuario_sessao` em query é ignorado ✅ `middlewares/autenticacao.ts:30-60`, `config/env.ts`.
- **Permissões:** 100% do RBAC do Hub. A API lê `GET /me/permissoes` do av-hub (cache de 15 s) e transforma telas × ações e escopo de vendedores em capacidades ✅ `src/domain/permissoes/capacidades.ts:1-60`, `lib/perfisHub.ts`. Não há tabela de perfil no `core_comercial`. Detalhe em [[RBAC-e-Permissoes]].
- **Bypass de desenvolvimento:** `AUTH_DEV_BYPASS=true` só vale com `NODE_ENV` explícito `development` ou `test`; aceita `x-dev-usuario` e `x-dev-perfis` ✅ `config/env.ts:74-77`, README.
- **Convenções:** envelope de erro `{ detail, codigo?, campos? }`; paginação `{ data, total, page, limit, total_pages }`; dinheiro e quantidade em `Decimal` (strings); comandos que mudam documento exigem `If-Match` com o `ETag` (428 sem, 409 com versão velha); `POST /propostas` e `POST /solicitacoes_custo` aceitam `Idempotency-Key` ✅ README.

### Rotas (`/v1`)

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

### Sincronização com o Omie

`src/modules/omie/` trabalha sobre a interface `FonteOmie` (D-30): fonte pelo espelho do av-hub (`fonteHub.ts`, `HUB_API_URL` + `HUB_API_KEY`, produtos e fornecedores) e pedidos de compra direto na API do Omie (`pedidosOmieApi.ts`, `OMIE_MOGI_APP_KEY/SECRET` e `OMIE_UBERABA_APP_KEY/SECRET`, porque `GET /pedidos_compras` do av-hub não traz o que a tela precisa) ✅ `config/env.ts`, README. A sincronização automática roda a cada `OMIE_SYNC_INTERVALO_MIN` (padrão 15; 0 desliga), é idempotente (hash por registro bruto), incremental e em lotes; sem fonte, `POST /omie/sincronizar` responde 503 `OMIE_SEM_FONTE` ✅ `config/env.ts`, README.

**Não confundir** `core_comercial.OrdemCompra`/`ItemOrdemCompra` (espelho de pedidos de compra do Omie para análise) com `core_vendas_faturamento.ordens_compra` (a OC que nasce no av-hub e segue o circuito de compra do fluxo) ✅ `prisma/models/omie.prisma`, [[Banco-AvHub]]. A proposta fechada gera um "pedido a digitar no Omie" (xlsx); o pedido de venda só entra no fluxo quando o Omie o cria e a pipeline o traz ([[Pipeline-Omie]], nó V1).

### Variáveis de ambiente

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

BFF no HUB: `COMERCIAL_API_URL` e `COMERCIAL_API_KEY` **deixaram de ser usadas** (27/10, N16-111): o BFF `app/api/comercial/[...rota]/route.ts` só chama a `api-acos-vital` ✅ `lib/api/comercialApi.ts:15-21`.

### Slugs de permissão que a API consulta

`propostas`, `propostas-delegacao` (criar = pode delegar), `propostas-valores` (visualizar = vê valores), `custo-item` (visualizar = vê custo; ou ser comprador), `relatorio-gerencial`, `painel-comprador` (editar = é comprador), `clientes` ✅ `domain/permissoes/capacidades.ts:44-52`. Os 6 perfis de desenvolvimento (`Comercial - Vendedor`, `Auxiliar`, `Gestão`, `Diretoria`, `Suprimentos - Comprador`, `Pós-venda`) ficam em `domain/permissoes/perfisDev.ts` ✅ README.

### Pontas soltas

- 🟡 `GET /pedidos_compras` do av-hub vem vazio na api-test; por isso a API lê o Omie direto (README e nota v1 `AV-Hub-Comercial-Suprimentos`, resumida em [[Comercial-Suprimentos]]).
- 🟡 Migração do ERP Comercial antigo (Supabase `erp_quotations`) por `npm run migrar:erp-antigo` ✅ README.
