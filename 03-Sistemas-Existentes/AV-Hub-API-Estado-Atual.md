---
tags: [erp-acos-vital, av-hub, api, api-acos-vital, arquitetura]
criado: 2026-10-07
atualizado: 2026-10-08
---

# av-hub — `api-acos-vital` hoje (estado do código em 07/10/2026)

> Status: decidido | no código | em produção (verificado em 07/10/2026 pelo dump). Decisões da rodada em [[Registro-de-Decisoes-2026-10-07]].

> **Atualização de 08/10/2026 (reconferido no código):** `main` agora é `9b9b578` (#282) e `develop` `0557871`. `PERMISSOES_ROTA_MODO` é **`exigir` por padrão** (variável ausente ou inválida vira `exigir`), mas **ainda é lida do `.env`** — não está "fixa" como na decisão 8; sem `USUARIO_TOKEN_SEGREDO` (≥ 32 caracteres) o processo encerra na subida. `contrato_tipo` do funcionário aceita CLT, PJ, Freelancer, Estágio, Temporário e Terceirizado.

> **Rótulos de confiança.** Leitura de `origin/main` e `origin/develop` do repositório da API, na auditoria de 07/10/2026. **`main` = `develop` em conteúdo**: tip da `develop` a6ab058 (06/10 16:05), que entrou em `main` pelo PR #280 (fdafb35, 06/10 16:12). **Produção só foi conferida pelo dump de 07/10** ([[Auditoria-Dump-Producao-2026-10-07]]). Fora o que o dump cobre (ex.: a função da migration 034), nada aqui afirma "em produção"; onde a chave de ambiente decide, está marcado "não verificado".

Esta nota é a foto atual do backend que o av-hub consome via `API_URL`. As notas mais antigas ([[AV-Hub-Arquitetura-BFF]], [[AV-Hub-Bugs-Catalogo]] e as `*-Investigacao`) descrevem a estrutura de setembro (`src/routes`, `src/models`), que **não existe mais**. O segundo backend do Hub (`api-comercial`) está em [[AV-Hub-Comercial-Suprimentos]].

## 1. Stack e reestruturação

| Item | Estado |
|---|---|
| Stack | **Express 4 + Sequelize** (não é Fastify). |
| Estrutura | `src/routes`, `src/models`, `src/services` **não existem mais**. Tudo em `src/schemas/<schema>/{tables,views,aggregates,functions}/<entidade>/` com `model`, `route` e `swagger.json`: **108 models, 119 routes, 118 `swagger.json`**; rotas montadas por `schemas/*/index.js` (commits 821d653, 6646efe, 9444565; PR #276). Só `src/middlewares` ficou na estrutura antiga. |
| Documentação | `/docs` e `/api-docs-json`: **Scalar** com tema por ambiente (production/homolog/test, deduzido de `AZURE_AD_REDIRECT_URI`) e dark mode, **atrás de login Azure AD** com sessão no Postgres. OpenAPI "5.0.0" com `x-tagGroups` (`src/docs/grupos.js`). `DOCS_API_KEY` pré-preenche a chave na interface (e4236ec, ab2560a, f0f99d1, 14e4930). |
| Defasagens no próprio repo | Limite real: **max 10000 por minuto**. O `src/docs/descricao.md` do repo ainda diz "200 req/min" (defasagem do repo, a corrigir lá) e o README cita `src/routes/*`, que não existe mais. |

## 2. Autenticação em camadas

| Camada | O que é |
|---|---|
| Chave do tipo (a) | `API_KEYS` (variável de ambiente) — **admin**. |
| Chave do tipo (b) | `auth.chaves_servico` (banco) — nível leitura / escrita / admin, cache de 30 s, **sem restrição por rota**. |
| Chave do tipo (c) | `MES_INTEGRACAO_KEYS` — abre **só** `PUT /compras/requisicoes/origem/{id}`; qualquer outra rota dá 403 `CHAVE_MES_ROTA_NAO_PERMITIDA`. Ver [[Chaves-de-Integracao-AvHub-MES-Pipeline]]. |
| Token de usuário | `Authorization: Bearer`, HMAC com `USUARIO_TOKEN_SEGREDO`. A identidade do token **sobrescreve** `id_usuario_sessao` e `created_by`/`updated_by`/`deleted_by`/`aprovado_por`/`decidido_por`/`cancelado_por`. |
| Autorização por rota | `auth.fn_autorizar` com a tabela `auth.rotas_telas`. `PERMISSOES_ROTA_MODO` fica **fixo em `exigir` no código**, sem `.env` (✅ Nathan, 07/10; alteração de código: Gustavo; antes o padrão era `desligado`). Ver [[AV-Hub-RBAC]] e [[Registro-de-Decisoes-2026-10-07]] (item 8). |
| Endpoints | `/me/permissoes`, `/autenticacao/{azure,login,renovar,logout}` (fb593b9, 25/09). |
| Auditoria | Sempre ligada (`auth.auditoria`). |
| Erros com código | `TOKEN_REVOGADO`, `CHAVE_SOMENTE_LEITURA`, `CHAVE_SEM_ACESSO_ADMINISTRATIVO`, `TOKEN_USUARIO_AUSENTE`. |

**Se isso está ligado em produção: não verificado** — depende das chaves de ambiente (seção 3).

## 3. Variáveis de ambiente

**As 6 chaves de regra de negócio que sobraram** (contrato [[38-Regras-Sem-Chave-de-Ambiente]], `c8f2f5e`/#279; conferido: nenhuma chave removida ainda é lida por `process.env`):

| Chave | Observação |
|---|---|
| `IDENTIDADE_EXIGIR_TOKEN` | exige o token de usuário |
| `PERMISSOES_ROTA_MODO` | decidido: fixo em `exigir` no código (deixa de ser chave; alteração do Gustavo). **No código de 08/10: padrão `exigir`, mas a variável ainda é aceita (`observar`/`desligado`)** |
| `ESCOPO_VENDEDORES_EXIGIR` | escopo por vendedor |
| `ESCOPO_UNIDADE_EXIGIR_SESSAO` | escopo por unidade |
| `AUTENTICACAO_AZURE_VALIDAR_ID_TOKEN` | validação do id_token do Azure |
| `VENDAS_PLANILHA_PAGINAR_POR_PEDIDO` | paginação por pedido da planilha de vendas |

O diff do #279 mostra **13** chaves saindo, não 11: as 11 do contrato mais `BLACKLIST_PEDIDOS_CHAVE_LEGADA` e `COMISSOES_COORDENADORES_BLOQUEIO`; também saiu `COMPRAS_HISTORICO_UNIFICADO` (do contrato 36 P6). (O contrato 38 §2 diz "11" e a tabela tem 13 linhas; o §3 não lista `MES_INTEGRACAO_KEYS` nem `DOCS_API_KEY`.) As regras que viraram fixas estão em [[38-Regras-Sem-Chave-de-Ambiente]].

**Outras variáveis restantes** (não são regra de negócio): `API_KEYS`, `MES_INTEGRACAO_KEYS` (nova), `USUARIO_TOKEN_SEGREDO` / `_TTL_SEGUNDOS`, `LOGIN_LIMITE_TENTATIVAS` / `_JANELA_SEGUNDOS`, `SESSION_SECRET`, `DOCS_API_KEY`, `AZURE_AD_*`, `CORS_ORIGINS`, `DB_*` (`DB_POOL_MAX`, `DB_STATEMENT_TIMEOUT_MS`), `PORT`, `NODE_ENV`, `JSON_BODY_LIMIT`, `FUNCIONARIOS_TELA_SLUG`, `VAGAS_TELA_SLUG`.

## 4. Migrations de que o código depende (o repo não versiona SQL)

O repo da API **não tem pasta de SQL**. O código depende das migrations **006, 007/007b, 009, 012, 013, 015, 022, 024, 025, 032, 034, 035, 036** e do SQL do 33. Só parte está nos anexos do vault. Quando faltam, alguns pontos degradam (via `to_regclass`) e outros dão **500**. Pontos de atenção:

| Migration | Efeito de faltar |
|---|---|
| **034** (`core_vendas_faturamento.fn_requisicao_mes_aplicar`) | Sem a função, o `PUT /compras/requisicoes/origem/{id}` devolve **500**. **A função existe em produção, completa (dump de 07/10, ✅)** e o `PUT` de sucesso já foi validado no `mes-test` (✅). Falta só **versionar o SQL**: o anexo `34-anexos/0001` do vault só cria 2 colunas e a função não está em nenhum SQL do vault. Ver [[34-Requisicoes-MES-Empurra-para-o-Hub]]. |
| **007 / 007b** | `/orcamento/*` leem `core_compras.orc_*` e `orc_vw_*`; `GET /dashboard/comissoes` usa `fn_dashboard_comissoes` sobre `comissao_coordenadores`. Que o DBA tenha aplicado o SQL é **[I]**. Ver [[07-Dados-Orcamento-e-Coordenadores-no-Banco]]. |
| **009** (2026-09-29_009) | `vw_vendas_planilha_leve`; com fallback para a view original via `to_regclass`. |
| **013** | `GET /produtos/:id/fornecedores` sobre `core_compras.vw_produto_fornecedores`. |
| **036** | `historico_comprador` no detalhe da OC é `null` sem a tabela `ordens_compra_comprador_historico` (via `to_regclass`). |

## 5. Estado dos contratos (código, `main` = `develop`)

| Contrato | Código mostra |
|---|---|
| 004 `GET /ordens-compra/referencia` | **não existe** (nem rota, nem a palavra "referencia"); os pré-requisitos de dados existem (`ordens_compra_itens_vinculos`, `requisicoes_compra.id_origem`, `status`) |
| 005 (lado hub) | nada na API; job/tela seria do av-hub. No MES a rota `GET /itens/status` existe |
| 26 liberação | `pedidos_liberacao`/`pedidos_liberados` (GET, `/:n/itens` com 409 `PEDIDO_NAO_LIBERADO`, `POST /:n/importado`) existem (4bf36d9, #275); **falta só L6** — ver [[Chaves-de-Integracao-AvHub-MES-Pipeline]] e [[26-Vendas-Liberacao-Pedido]] |
| 34 PUT por `id_origem` | existe (`validarCorpoMes`; 201/200/409 `REQUISICAO_COM_OC`) — 0391b29 (#275); a branch `feat/requisicoes-mes-upsert` é versão antiga, **não mergeada, obsoleta** |
| 35 `/compras/requisicoes/eventos` | existe: `alterado_desde`, `apos_id`, `codigo_empresa`, `limit`; resposta `{quantidade, tem_mais, proximo, data}`; PATCH de cancelar exige motivo de 3–500 caracteres e grava `cancelada_por_origem='compras'` — 0a65491 (#275). Ver [[35-Compras-Marcos-Requisicao-para-MES]] |
| 36 | validação de produto incondicional; `historico_comprador`; histórico unificado fixo (5491037 #277, c8f2f5e #279) |
| 37 | `variacao_pct` e `variacao_quantidade_pct` via `fn_variacao_pct` em `/dashboard_mensal_{vendas,faturamento}` (47a5aad #278) |
| 39 vínculo dos vendedores | `?sem_vinculo=true` (ignorado com `id_funcionario`/`_in`), `nome_funcionario`, `nome_usuario`, `/vendedores/{id}/sugestoes` com `nome_setor`, `nome_unidade`, `desligado` (desligados por último) — a6ab058 |
| 07 orçamento/coordenadores | API **implementada** (o vault dizia "desconsiderado"): 90bdb33 (01/10, #275). Decidido: o orçamento é desenvolvido **por fora**, no módulo Comercial & Suprimentos ([[AV-Hub-Comercial-Suprimentos]]); o contrato 07 precisa ser reescrito |
| 13 fornecedores por produto | existe (31e26a6, 25/09, #275) |
| 19 / 23 (lado API) | a API expõe o que a pipeline consome: `GET /compras/ordens/fila-omie`, `PATCH /compras/ordens/:id/sincronizacao`, `POST /:id/reenviar`, `GET /compras/compradores`, `/cotacoes_moeda` (ec2a42b, #273) |
| 006 SQL | coerente com o invalidado: `pedidos_vendas` só tem o boolean `devolucao_parcial` |

## 6. Outras novidades da API

1. **Planilha de vendas**: `vw_vendas_planilha_leve` (mesmas colunas), lida só no modo por pedido, com fallback; `vw_vendas_planilha_resumo` aceita intervalo de datas (contrato 05 P8).
2. **Vendedores/compradores**: `POST /vendedores` é upsert por `(codigo_empresa, codigo_vendedor_omie)` mas **bloqueado com 403 `CADASTRO_VEM_DO_OMIE`** (contrato 28); o PUT ignora `codigo_vendedor_omie`, `codigo_empresa`, `nome`, `email`, `ativo` e devolve o header `X-Campos-Ignorados`; `ativo_desde`/`inativo_desde` validados; `sort=nome_unidade`. Compradores: só `GET`, `GET` sugestões, `GET :id` e `PUT` (exige edição em "compradores").
3. **Compras**: `GET /compras/ordens/dashboard` (ca899f9), acompanhamento CCP (7faf6a7), `/compras/pedidos-venda`, detalhe do pedido Omie com fornecedor e código do produto (119634a). Regras fixas sem chave: só comprador **vinculado** emite OC; só `pode_aprovar` aprova/cancela; o pedido de venda precisa existir; produto do cadastro é obrigatório.
4. **Funcionários**: validação/normalização de CPF no POST/PUT (81b2a9a, aa89bc0); JSON malformado devolve 400 explicativo (0ab77fc).

## 7. Branches abertas

| Branch | Estado |
|---|---|
| `origin/feat/migracao-nestjs-prisma` (474ad3b, 25/09) | **Descartada** (✅ Nathan, 07/10; fecha CC-09). Era uma migração das **358 rotas Express para NestJS + Prisma**, 3 à frente e 61 atrás da base, sem os contratos 34–39. |
| `origin/feat/requisicoes-mes-upsert` | versão antiga do PUT do contrato 34, em `src/routes`; obsoleta, **não mergear** |
| `homolog` (10/06), `subida-API`, `refactor/swagger` | antigas |
| Locais sem push (estrutura antiga; todas superadas pela `develop`) | `contrato-36-produto-sempre`, `contrato-38-sem-chaves`, `contrato-39-vendedores-vinculo`, `feat/contrato-35-marcos-requisicao`, `feat/vendas-liberacao-pedidos`, `feat/compras-dashboard`, `feat/compras-contrato`, `test/merge-compras-contrato` |

**Nota histórica:** hashes de notas anteriores (`f4380d7`, `8eb5dce`, `cba68fa`, `c2b68a9`, `1b6fe6e`) vêm de branches locais re-autoradas a partir de patches; não usar. Os equivalentes mergeados estão nas tabelas acima ([[Registro-de-Decisoes-2026-10-07]], item 55).

## Ver também
- [[AV-Hub-Arquitetura-BFF]]
- [[AV-Hub-RBAC]]
- [[AV-Hub-Bugs-Catalogo]]
- [[AV-Hub-Comercial-Suprimentos]]
- [[Chaves-de-Integracao-AvHub-MES-Pipeline]]
- [[Indice-Contratos]]
- [[Onde-Estamos]]
