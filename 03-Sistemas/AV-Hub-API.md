---
tags: [sistemas, av-hub, api-acos-vital, express, sequelize, compras, torre-de-fluxo, custo]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Gustavo (DBA)
fontes: [api-acos-vital f322dcd (develop), Dump Avhub (Esqueleto).sql de 14/10, v1 AV-Hub-API-Estado-Atual, AV-Hub-RBAC, Integracao-AvHub-MES-Especificacao-F1]
---

# AV-Hub API (`api-acos-vital`)

API do av-hub: Node (ESM) + Express 4 + Sequelize 6 + PostgreSQL (`pg`), sessão em `connect-pg-simple`, docs Scalar em `/docs` atrás de Azure AD ✅ `api-acos-vital/package.json`, `src/app.js`. Dono: Gustavo (DBA faz banco e API); o front é do Nathan ([[AV-Hub-Front]]). Banco: [[Banco-AvHub]]. Schemas: [[Schemas-Postgres]]. Selos: [[Regras-do-Vault]].

## Como a requisição é tratada (ordem do `app.js`)

1. `express.json` (limite `JSON_BODY_LIMIT`, padrão 10 mb), cache HTTP, CORS (`CORS_ORIGINS`, padrão `*`), rate limit global de 10 000 req/min por chave e 20 logins/min por IP ✅ `app.js:46-96` (`express.json` `:46`, rate limit `:74-92`).
2. Sessão no Postgres (`auth.sessions`) só em `/auth`, `/docs`, `/api-docs-json` ✅ `app.js:94-122`.
3. `requestLogger`, `/docs`, `ipFilter` (regras em `auth.ip_regras`), **`apiKeyAuth`** ✅ `app.js:122-134`.
4. `registrarAuditoria`, **`identidadeUsuario`** (valida o token do usuário e chama `auth.fn_autorizar`), **`aplicarEscopoVendedor`** ✅ `app.js:139-141`.
5. Routers de todos os schemas na ordem de `schemas/index.js` ✅ `app.js:161-163`.
6. Na subida: cria os schemas `auth`, `core`, `core_aprovacao_de_vagas`, `core_mapas`, `core_organograma`, `core_vendas_faturamento` se faltarem e inicia **3 jobs** do MES (status, Torre, custo) ✅ `app.js:197-210`.

Autenticação e permissão em detalhe: [[RBAC-e-Permissoes]] e [[Chaves-e-Autenticacao]].

## Organização do código

`src/schemas/<schema>/{tables,views,aggregates,functions}/<entidade>/<entidade>.{model,route}.js` + `.swagger.json`; `src/schemas/<schema>/index.js` registra models e a lista `rotas` (caminho, router, middlewares); `src/schemas/index.js` junta tudo ✅. Schemas com rotas: `auth`, `core`, `core_aprovacao_de_vagas`, `core_mapas`, `core_organograma`, `core_comissionamento`, `core_compras`, `core_fluxo`, `core_vendas_faturamento`. `core_fluxo` não tem model Sequelize: usa SQL direto sobre funções do banco ✅ `core_fluxo/index.js:1-6`.

## Rotas do fluxo de Atividades

### Liberação do pedido (LOG-26) — V1 a V3, P1, P2

| Rota | Quem chama | O que faz | Código |
|---|---|---|---|
| `GET /pedidos_liberacao` | HUB | caixa do vendedor (escopo de vendedor do token) | ✅ `aggregates/pedidos_liberacao/pedidos_liberacao.route.js:88` |
| `PUT /pedidos_liberacao/:codigo_empresa/:numero_pedido` corpo `{acompanhamento_qualidade, updated_by}` | HUB | upsert da marcação; 404 `PEDIDO_FORA_DA_LIBERACAO`; 409 `PEDIDO_IMPORTADO_MES` | ✅ `:164-233` |
| `GET /pedidos_liberados` | MES | só `liberado` e `importado` | ✅ `aggregates/pedidos_liberados/pedidos_liberados.route.js:57` |
| `GET /pedidos_liberados/:numero/itens?codigo_empresa=` | MES | itens; 409 `PEDIDO_NAO_LIBERADO` | ✅ `:115`, `:53-56` |
| `POST /pedidos_liberados/:numero/importado?codigo_empresa=` corpo `{referencia}` (até 60 caracteres) | MES | grava `importado_mes_em` e a referência (idempotente) | ✅ `:143-170` |

Trava no banco: `trg_pedidos_vendas_liberacao_regras` e `_historico` (função no dump `:7751`; tabela `:18285`). A caixa só mostra pedidos a partir de `parametros_vendas.data_inicio_liberacao` ✅ tabela no dump `:18031`; o valor em produção ❓ Gustavo.

### Requisição de compra (LOG-34, LOG-35) — P3, C0, C1

| Rota | Quem chama | O que faz | Código |
|---|---|---|---|
| `GET /compras/requisicoes` (`status`, `codigo_empresa`, `q`, `page`, `limit` até 200) | HUB | lista; fila ordenada por prazo | ✅ `tables/requisicoes_compra/requisicoes_compra.route.js:148` |
| `GET /compras/requisicoes/resumo` | HUB | contadores `abertas`, `em_cotacao`, `atendidas`, `canceladas` | ✅ `:199` |
| `PUT /compras/requisicoes/origem/:id_origem` | **MES** (chave `MES_INTEGRACAO_KEYS`, a única rota que ela abre) | `fn_requisicao_mes_aplicar`: `criada` (201), `atualizada`, `cancelada`, `ignorada_com_oc`, `ignorada_cancelada`, `nao_existe`; 409 `REQUISICAO_COM_OC` ao cancelar com OC | ✅ `:221-265`; `middlewares/apiKeyAuth.js:59-76` |
| `GET /compras/requisicoes/eventos?alterado_desde=&apos_id=&codigo_empresa=&limit=` (até 500) | **MES** (chave `API_KEYS`) | marcos com `autor` e `comprador` (view `vw_requisicoes_compra_eventos`, migration 035b; sem a view devolve `null`); cursor `(registrado_em, id)` | ✅ `:289-369` |
| `GET /compras/requisicoes/:id` | HUB | detalhe | ✅ `:371` |
| `POST /compras/requisicoes` | HUB (permissão `compras.pode_criar` no BFF) | cria requisição própria do Compras (sem `id_origem`); `status` e `id_ordem_compra` nunca vêm do cliente | ✅ `:384-411` |
| `PATCH /compras/requisicoes/:id` corpo `{status, motivo?}` | HUB | `aberta` ↔ `em_cotacao` ↔ `cancelada` (cancelar exige `motivo` de 3 a 500 caracteres e grava `cancelada_por_origem = 'compras'`); `atendida` nunca por aqui | ✅ `:413-466` |

Estados da requisição no av-hub: `aberta`, `em_cotacao`, `atendida`, `cancelada` (CHECK `ck_requisicoes_compra_status`, dump `:18541`). `atendida` só pela trigger da OC (`trg_ordens_compra_requisicao`: OC que nasce com `id_requisicao` marca atendida; OC cancelada devolve todas as requisições a `aberta`) ✅ dump `fn_ordens_compra_requisicao` (dump `:6810`). O banco impõe `atendida ⇔ id_ordem_compra IS NOT NULL` (`ck_requisicoes_compra_atendida`).

**Marcos (14 tipos)** gravados por trigger em `requisicoes_compra_eventos`, só quando a requisição tem `id_origem`, ou seja, veio do MES ✅ `fn_req_evento` (dump `:8580`): `requisicao_recebida`, `em_cotacao`, `oc_criada`, `oc_removida`, `oc_enviada_aprovacao`, `oc_aprovada`, `oc_no_omie`, `fornecedor_confirmou`, `previsao_alterada`, `despachada`, `ocorrencia`, `oc_cancelada`, `requisicao_cancelada`, `requisicao_reaberta` (CHECK `requisicoes_compra_eventos_tipo_check`). Requisição criada pelo Compras não gera marco: **não chega ao MES** 🔴.

### Ordem de compra e aprovação — C2 a C4

| Rota | Faz | Código |
|---|---|---|
| `GET /compras/ordens` (+ `/resumo`, `/dashboard`) | histórico unificado: OCs do av-hub e pedidos de compra só do Omie (somente leitura) | ✅ `tables/ordens_compra/ordens_compra.route.js:607,720,810` |
| `GET /compras/ordens/:id` | detalhe; 404 com `origem: "omie"` para pedido só do Omie | ✅ `:893` |
| `POST /compras/ordens` | emite a OC; só comprador vinculado na unidade (400); PV digitado precisa existir no Omie (`EXIGIR_PV_EXISTENTE`); item precisa ser produto do cadastro da unidade | ✅ `:923`, regras fixas `:35-56` |
| `PATCH /compras/ordens/:id` corpo `{status: aprovado|cancelado, aprovado_por, updated_by, motivo_reprovacao}` | decide; exige `compras.pode_aprovar` do usuário (403) | ✅ `:1177-1265`, `EXIGIR_PODE_APROVAR = true` (`:38-42`) |
| `PATCH /compras/ordens/:id/sincronizacao` | retorno do Omie (`nCodPed`, erro) | ✅ `:1267` |
| `POST /compras/ordens/:id/reenviar` | volta a OC à fila do Omie; exige `compras.pode_editar` | ✅ `:1321`, `usuarioTemPermissao(..., "pode_editar")` `:1343` |
| `GET /compras/ordens/fila-omie` | fila para a pipeline (`aprovado` pendente = enviar; `cancelado` com `codigo_pedido_omie` = excluir) | ✅ `:857-891` |
| `GET /compras/acompanhamento`; `GET/PUT /compras/ordens/:id/acompanhamento`; `POST …/contatos`, `…/ocorrencias`; `PATCH /compras/ocorrencias/:id` | follow-up do CCP (LOG-32): `followup.pode_visualizar` lê, `pode_editar` grava, `pode_aprovar` decide ocorrência | ✅ `tables/ordens_compra_acompanhamento/…route.js:298-586`, `:154` |
| `GET /compras/compradores`, `/:id/sugestoes`, `/:id`; `PUT /compras/compradores/:id` | vínculo comprador × funcionário (`compradores.pode_editar`) | ✅ `tables/compradores/compradores.route.js:76-210` |
| `GET /compras/pedidos-venda/:numero` e `/:numero/compras` | itens do PV com saldo a comprar | ✅ `views/vw_pedido_venda_compras/…route.js:52,92` |
| `GET /compras/condicoes-pagamento`, `/compras/parametros` | catálogos e `limite_aprovacao` | ✅ `tables/condicoes_pagamento_compras/…route.js:19,24` |
| `GET /compras/fornecedores`, `/compras/transportadoras` | projeções de `core.parceiros` | ✅ `core/aggregates/compras_parceiros/…route.js:84-85` |
| `GET /ordens-compra/referencia?alterado_desde=&codigo_empresa=&page=&limit=` | referência da OC para o MES (API-004/007), limite 100 padrão e 500 máximo; **o MES não consome** | ✅ `views/vw_ordens_compra_referencia_mes/…route.js:70`, `:38-39` |

**Regra de aprovação conferida no banco** (a que de fato roda):

- `fn_ordens_compra_nascer` (BEFORE INSERT): toda OC nasce `aguardando_aprovacao` (ou `rascunho`) ✅ dump `:6619`.
- `fn_ordens_compra_recalcular` (itens): depois de somar os itens, a OC com `valor_total_brl` **até** `parametros_compras.limite_aprovacao` (padrão R$ 30 000,00 por unidade) vira **`aprovado` sozinha**; acima do limite fica `aguardando_aprovacao`; uma OC já aprovada que sobe acima do limite volta a `aguardando_aprovacao` ✅ dump `:6750`.
- `fn_ordens_compra_status` (BEFORE UPDATE): `cancelado` é final; aprovar acima do limite exige que a OC tenha passado por `aguardando_aprovacao`; carimba `aprovado_em` e `cancelado_em` ✅ dump `:6851`.
- Quem decide: um usuário com `compras.pode_aprovar` (perfil Gerência de Compras) ✅ `ordens_compra.route.js:1235`.

Isto difere do 0b e da decisão de 14/10 ("Gerente aprova sempre; acima de R$ 30 mil a Diretoria também"): no código, abaixo do limite a OC é **auto-aprovada** pelo banco e acima do limite existe **uma única** alçada (Gerência de Compras); não há segunda aprovação da Diretoria 🔴. Entra em [[Pontas-Soltas]] e [[Contradicoes-Resolvidas]].

### Status por item (API-005/006) — todos os nós

| Rota | Faz | Código |
|---|---|---|
| `GET /itens_pedido_status?codigo_empresa=&pedido_venda=` | etapa dos itens do pedido, com escopo de vendedor | ✅ `tables/itens_pedido_status/itens_pedido_status.route.js:54` |
| Job | a cada `MES_STATUS_INTERVALO_SEG` (padrão 90 s) por unidade ativa: `GET {MES_API_URL}/itens/status?alterado_desde=&codigo_empresa=&incluir_deletados=true&limit=1000`; grava com `fn_itens_pedido_status_gravar`; trava `avhub.mes_status_itens`; corte inicial `MES_STATUS_CORTE_INICIAL_DIAS` (30) | ✅ `itens_pedido_status.job.js:3-60` |

### Torre de Fluxo (LOG-46) — os 9 setores

| Rota | Permissão (migration 046/046b em `auth.rotas_telas`) | Faz | Código |
|---|---|---|---|
| `GET /fluxo/torre?codigo_empresa=&setor=&etapa=&situacao=&q=&page=&limit=` (`situacao` = `no_prazo`, `fora_do_prazo`, `sem_dono`; até 500 por página) | `torre-fluxo` | mapa por setor e lista de itens (`fn_torre_setores`, `fn_torre_itens`) | ✅ `core_fluxo/tables/item_estado_projetado/item_estado_projetado.route.js:185` |
| `GET /fluxo/itens/:id` | `torre-fluxo-trilha` (mostra nomes de pessoas) | item + trilha (MES + eventos do hub) + tempo | ✅ `:302` |
| `GET /fluxo/itens/:id/tempo` | `torre-fluxo` | tempo por etapa (proxy do MES) | ✅ `:281` |
| `GET /fluxo/sla-etapas` | `torre-fluxo` | meta por etapa (proxy do MES) | ✅ `:262` |

- **Projeção:** `core_fluxo.item_estado_projetado`, uma linha por `(codigo_empresa, numero_pedido, codigo_item_omie)`, escrita **só** por `core_fluxo.fn_feed_aplicar` ✅ dump `:2169`. Também existem `core_fluxo.evento` (eventos do hub, append-only, nasce vazia) e `core_fluxo.feed_cursor` (`fonte = 'mes'`).
- **Job:** `item_estado_projetado.job.js` a cada 90 s (`INTERVALO_MS`), primeira rodada aos 5 s, `GET {MES_API_URL}/fluxo/eventos?apos_seq=<cursor - 200>&limite=1000`, até 50 páginas por rodada, trava `avhub.fluxo_feed`; 404 do MES = "feed ainda não publicado": avisa uma vez e espera 10 min ✅ `:46-60`.
- **Escopo:** por unidade (`auth.usuarios_unidades`); fora do escopo, 403 na lista e 404 no item; MES fora do ar devolve 200 com `mes_indisponivel = true` ✅ `:16-33`.
- **Estado hoje:** o MES **não publica** `/fluxo/*` 🔴 (Robert); o job está dando 404. O HUB não tem a tela 🔴 (Nathan). A 046b concede as duas telas só ao perfil Admin (Dev) ✅ comentário `:22-25`; a concessão real ❓ Gustavo.

### Custo real por item (LOG-47 §1, API-008) — E3, R4

| Rota | Permissão | Faz | Código |
|---|---|---|---|
| `GET /itens_pedido_custo?codigo_empresa=&numero_pedido=` | `custo-itens.pode_visualizar`, **sempre** (também sem token, via `id_usuario_sessao`); 403 `USUARIO_NAO_INFORMADO`/`SEM_PERMISSAO`; `PEDIDO_FORA_DO_ESCOPO` para vendedor sem escopo | custo por produto do pedido: `quantidade`, `quantidade_com_custo`, `custo_total`, `custo_medio`, `completo`, `cotacao_a_conferir`, `lotes`; pedido manual devolve `pedido_manual: true` e itens vazios | ✅ `tables/itens_pedido_custo/itens_pedido_custo.route.js:66-154` |
| Job | a cada 90 s por unidade ativa: `GET {MES_API_URL}/itens/custo?alterado_desde=<cursor>&apos_id=&codigo_empresa=&limit=1000`; grava com `fn_itens_pedido_custo_gravar`; 1ª leitura desde 1970; MES 404 = espera 10 min; trava `avhub.mes_custo_itens` | ✅ `itens_pedido_custo.job.js:51-60` |

- A migration **047b** troca a chave de `(unidade, pedido, item)` para `(unidade, pedido, codigo_produto_omie)` (o item é o produto) ✅ cabeçalho do job. **O dump de 14/10 ainda está na 047**: a tabela `itens_pedido_custo` tem `item integer` e o `UNIQUE uq_itens_pedido_custo (codigo_empresa, numero_pedido, item)` e `fn_itens_pedido_custo_do_pedido` devolve `item` (dump `:4393`, `:23010`). Contra esse banco a rota daria 500 "exige a migration 047b" 🔴 ([[Diferencas-Codigo-x-Banco]]).
- O MES **não** tem `GET /itens/custo` 🔴 (o job recebe 404). O custo do lote existe no MES ([[Modelo-Estoque-e-Custo-do-Lote]]).
- Etapas 2 (simulador pré-preenchido) e 3 (comissão por NF) do LOG-47 são Ciclo 2 e não leem a tabela ✅ comentário do job.

## Funções e triggers que carregam a regra

| Objeto (schema `core_vendas_faturamento`) | Regra | Dump |
|---|---|---|
| `fn_requisicao_mes_aplicar(uuid, jsonb)` | cria, atualiza, cancela ou ignora a requisição do MES; lock advisory por `id_origem` | `:8680` |
| `fn_requisicoes_compra_numerar`, `_numero_fixo` | número gerado pelo banco por unidade (`contadores_documento`); o número do MES vai para `numero_requisicao_mes` | triggers `:26246`, `:26254` |
| `fn_requisicoes_compra_status`, `_cancelamento` | transições `aberta`/`em_cotacao`/`cancelada`; `atendida` só pela trigger da OC | `:8923`; trigger `:26238` |
| `fn_requisicoes_compra_zz_eventos` | marcos `requisicao_recebida`, `em_cotacao`, `requisicao_cancelada`, `requisicao_reaberta` | `:8961` |
| `fn_req_evento`, `fn_req_evento_ligar`, `fn_req_eventos_imutavel` | grava marco só se há `id_origem`; histórico só de inserção | dump |
| `fn_ordens_compra_{nascer,numerar,numero_fixo,recalcular,status,requisicao,comprador,condicao,parcelas,historico,finalidade_guardar,itens_valores,ao_apagar,zz_eventos}` | numeração `OC-`, aprovação por limite, parcelas, requisição atendida, marcos `oc_*` | triggers `:25949-26086` |
| `fn_oc_acompanhamento_*`, `fn_oc_contatos_*`, `fn_oc_ocorrencias_*`, `fn_oc_itens_zz_eventos` | follow-up do CCP e marcos `oc_aprovada`, `fornecedor_confirmou`, `previsao_alterada`, `despachada`, `ocorrencia` | dump |
| `fn_oc_referencia_mes_marcar` | mantém `ordens_compra_referencia_mes.alterado_em` (cursor da API-004) | triggers `:25877,25901,25909` |
| `fn_pedidos_vendas_liberacao_regras`, `_historico` | trava a marcação depois do `importado` e grava `pedidos_vendas_liberacao_historico` (`liberado`, `alterado`, `importado_mes`) | `:18285` |
| `fn_itens_pedido_status_gravar`, `_do_pedido` | grava página do `/itens/status` e lê por pedido | `:4657` |
| `fn_itens_pedido_custo_gravar`, `_do_pedido` | idem para o custo (versão 047 no dump) | `:4393`, `:4421` |
| `core_fluxo.fn_feed_aplicar`, `fn_torre_setores`, `fn_torre_itens`, `fn_evento_imutavel` | projeção da Torre | `:1914` |
| `auth.fn_autorizar`, `fn_me_permissoes`, `fn_escopo_vendedores_usuario`, `fn_validar_chave_servico` | permissão por rota, `/me/permissoes`, escopo, chaves de serviço | `:357` |

## Outros módulos (resumo; detalhe nos anexos)

Vendas e faturamento (`/pedidos_venda`, `/vendas_*`, `/faturamento_*`, `/dashboard*`, `/ranking_*`, `/ritmo_*`, `/nf_classified`), Comissão (`core_comissionamento`), Vagas (`core_aprovacao_de_vagas`), Organograma, Orçamento (`/orcamento/*` sobre `core_compras.orc_*`), cadastros `core.*` (parceiros, produtos, unidades, funcionários), Acompanhamento de Clientes e grupos de clientes (`/acompanhamento_clientes`, `/grupos_clientes`, contrato 48). Ficam em [[Comissoes]], [[Dashboards]], [[Orcamento]], [[RH-Vagas-Funcionarios]], [[Acompanhamento-Clientes]].

## Variáveis de ambiente (conferidas)

| Variável | Uso | Código |
|---|---|---|
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_POOL_MAX`, `DB_STATEMENT_TIMEOUT_MS` | banco | ✅ `db.js:6-55` |
| `SESSION_SECRET`, `AZURE_AD_CLIENT_ID`, `_CLIENT_SECRET`, `_TENANT_ID`, `_REDIRECT_URI` | obrigatórias na subida | ✅ `utils/env.js:1-12` |
| `API_KEYS` | chaves de serviço do `.env` (valem como admin) | ✅ `apiKeyAuth.js:53` |
| `MES_INTEGRACAO_KEYS` | chaves do MES (≥ 32 caracteres), só para `PUT /compras/requisicoes/origem/:id` | ✅ `apiKeyAuth.js:59-64` |
| `USUARIO_TOKEN_SEGREDO` (≥ 32), `USUARIO_TOKEN_TTL_SEGUNDOS` | token de usuário; sem o segredo a API não sobe | ✅ `utils/env.js:25-32`, `tokenUsuario.js:30-35` |
| `MES_API_URL`, `MES_API_KEY` | os 3 jobs que leem o MES; sem elas o job não sobe e avisa | ✅ `itens_pedido_status.job.js:204-205`, `utils/mesFluxo.js:21-22` |
| `MES_STATUS_INTERVALO_SEG`, `MES_STATUS_CORTE_INICIAL_DIAS` | só o job do status por item ainda lê regra em ambiente | ✅ `itens_pedido_status.job.js:34-37` |
| `CORS_ORIGINS`, `JSON_BODY_LIMIT`, `PORT`, `NODE_ENV` | HTTP | ✅ `app.js` |
| `IDENTIDADE_EXIGIR_TOKEN`, `AUTENTICACAO_AZURE_VALIDAR_ID_TOKEN`, `ESCOPO_UNIDADE_EXIGIR_SESSAO`, `FUNCIONARIOS_TELA_SLUG`, `VAGAS_TELA_SLUG`, `VENDAS_PLANILHA_PAGINAR_POR_PEDIDO`, `DOCS_API_KEY`, `AZURE_AD_ISSUER`, `AZURE_AD_JWKS_URI` | chaves remanescentes | ✅ `utils/acessoConfig.js`, demais arquivos |

Os jobs de Torre e custo seguem a regra do Nathan: nada de regra em ambiente, só endereço e segredo ✅ cabeçalhos `item_estado_projetado.job.js:41-46`, `itens_pedido_custo.job.js:36-44`.

## Defeitos conhecidos da API

Resumo; lista com severidade em [[Bugs-Conhecidos]].

- ✅ `alterado_desde` é código morto em `GET /produtos` e `GET /parceiros` (escrito depois do `return where`): `core/tables/produtos/produtos.route.js:51-62`, `core/tables/parceiros/parceiros.route.js:95-109`.
- ✅ `pessoa_vendedor` tem model e rota (`/pessoa_vendedor`) e a tabela não existe no dump de 14/10 (`schemas/core_vendas_faturamento/index.js` monta o router).
- 🟡 A tabela `itens_pedido_custo` do dump ainda está na versão 047 (sem 047b).
- ❓ `usuarios_favoritos.model.js:13` declara `id` sem `defaultValue` nem `allowNull`; o POST de favoritos já deu `400 "Campo obrigatório não informado: id"` em setembro; não reproduzido em 14/10.
