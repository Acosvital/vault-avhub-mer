---
tags: [sistemas, av-hub, api-acos-vital, express, sequelize, compras, torre-de-fluxo, custo]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Gustavo (DBA)
fontes: [api-acos-vital 0384e89 (develop, 29/10), Dump do Avhub para referência (29.10).sql (guardado em api-acos-vital/), Dump Avhub (Esqueleto).sql de 14/10, v1 AV-Hub-API-Estado-Atual, AV-Hub-RBAC, Integracao-AvHub-MES-Especificacao-F1]
---

# AV-Hub API (`api-acos-vital`)

**Em uma frase:** é a API do av-hub. Guarda os dados de vendas e compras, aplica as permissões e conversa com o MES e o Omie. Dono: Gustavo (DBA, quem cuida do banco); o front é do Nathan ([[AV-Hub-Front]]).

## Quem usa e para quê

- **HUB (as telas):** lê e grava pedidos, requisições, ordens de compra e permissões.
- **MES:** lê os pedidos liberados, avisa que importou, envia a requisição de compra e lê o andamento dela ([[MES-Backend]]).
- **Pipeline do Omie:** pega a fila de OCs (ordens de compra) a enviar e devolve o resultado ([[Pipeline-Omie]]).
- **Módulo comercial (`/comercial/*`):** desde 28/10 a API do Hub guarda as rotas de proposta, cadastros e cliente, no lugar da `api-comercial` do Pablo (N16-111, LOG-52). A `api-comercial` virou legado só de leitura ([[API-Comercial]]).

## Como se encaixa no fluxo

- **Vendas (`V1` a `V3`):** guarda a caixa de liberação do vendedor. O MES só enxerga o que está liberado.
- **Compras (`C0` a `C5`):** recebe a requisição e controla cotação, OC, aprovação, envio ao Omie e follow-up do CCP.
- **Etapa dos itens:** a cada 90 segundos lê no MES onde cada item está e mostra ao vendedor.
- **Torre de Fluxo e custo por item:** o código está pronto aqui. O MES já publica o custo por item (`GET /itens/custo`, 27/10, só na `develop` do MES); a Torre ainda não, porque o MES não publica `/fluxo/*`.

## Regras que valem

- OC até R$ 30 mil nasce aprovada. Acima disso, só o Gerente de Compras aprova (N14-21). A Diretoria não aprova.
- Só comprador vinculado à unidade emite OC.
- Pedido já importado pelo MES não aceita mais mudança na marcação (erro 409).
- Cancelar requisição exige motivo de 3 a 500 caracteres.
- Quem age vem sempre do token de login, nunca do corpo do pedido.
- Rota sem mapa de permissão é negada por padrão.
- Marco de compra só nasce para requisição que veio do MES. A requisição criada no Compras não gera marco; o MES a vê pela referência da requisição (API-009) e depois pela referência da OC.
- Jobs novos não guardam regra em variável de ambiente. Só o job de status por item ainda faz isso.

## O que já existe e o que falta

- ✅ Liberação, requisições, OC com aprovação, follow-up e status por item.
- ✅ Custo por item: a rota, o job e o banco estão alinhados (a migration 047b está no dump de 29/10) e o MES publica `GET /itens/custo` na `develop`. O HUB tem a tela de custo por item.
- ✅ Torre de Fluxo: a rota, o job e a tela do HUB existem. 🔴 O MES não publica `/fluxo/*`, então a Torre fica vazia.
- ✅ O MES consome a referência da OC (`GET /ordens-compra/referencia`, desde 15/10, `develop` do MES) e agora a referência da requisição do Compras (API-009).
- ✅ Requisição de compra pode ser excluída (exclusão lógica, 23/10, contrato 55).
- ✅ Rotas do módulo comercial (`/comercial/*`): `me`, empresas emissoras, responsáveis, parâmetros de custo, propostas, clientes e parceiros (28 e 29/10).
- 🟡 O limite de R$ 30 mil é provisório. Endurece depois da conversa com Compras.
- ✅ O filtro `alterado_desde` de produtos e parceiros foi corrigido em 16/10 (`38d2f74`).
- 🔴 `pessoa_vendedor` continua sem tabela (conferido no dump de 29/10).
- ❓ A rota de favoritos já falhou em setembro; não reproduzido em 14/10.
- ❓ Valor do início da liberação em produção e quais perfis abrem a Torre.

## Detalhe técnico

API do av-hub: Node (ESM) + Express 4 + Sequelize 6 + PostgreSQL (`pg`), sessão em `connect-pg-simple`, docs Scalar em `/docs` atrás de Azure AD ✅ `api-acos-vital/package.json`, `src/app.js`. Dono: Gustavo (DBA faz banco e API); o front é do Nathan ([[AV-Hub-Front]]). Banco: [[Banco-AvHub]]. Schemas: [[Schemas-Postgres]]. Selos: [[Regras-do-Vault]].

### Como a requisição é tratada (ordem do `app.js`)

1. `helmet` (CSP fechada na API, aberta só nas páginas de docs), cache HTTP e CORS por lista (`CORS_ORIGINS`; o curinga `*` só vale fora de produção) ✅ `app.js:56-95`.
2. Sessão no Postgres (`auth.sessions`) só em `/auth`, `/docs`, `/api-docs-json`; limite de 20 logins/min por IP em `/auth/login` ✅ `app.js:107-130`.
3. `requestLogger`, `/docs` (`rotasDocs`), `ipFilter` (regras em `auth.ip_regras`), **`apiKeyAuth`** ✅ `app.js:135-147`.
4. Limite geral de 5 000 requisições por minuto **por chave de serviço**, contado depois da chave validada (LOG-51 S5) ✅ `app.js:155-165`.
5. `express.json` só **depois** da chave (limite `JSON_BODY_LIMIT`, padrão 10 mb; corpo acima de 1 MB vai para o log) ✅ `app.js:171-181`.
6. `registrarAuditoria`, **`identidadeUsuario`** (valida o token do usuário e chama `auth.fn_autorizar`), **`aplicarEscopoVendedor`** ✅ `app.js:187-189`.
7. Routers de todos os schemas na ordem de `schemas/index.js` ✅ `app.js:204-206`. As rotas de `/comercial` e `/suprimentos` passam ainda por `exigirTokenUsuario` (sem Bearer válido, 401 `TOKEN_USUARIO_AUSENTE`, mesmo com `x-api-key` válida) ✅ `core_comercial/index.js`.
8. Na subida a API **não cria** schema nem tabela (roda sem DDL, LOG-51 S8): só confere que os schemas `auth`, `core`, `core_aprovacao_de_vagas`, `core_mapas`, `core_organograma` e `core_vendas_faturamento` existem e inicia **3 jobs** do MES (status, Torre, custo) mais a limpeza das chaves de idempotência ✅ `app.js:236-264`.

Autenticação e permissão em detalhe: [[RBAC-e-Permissoes]] e [[Chaves-e-Autenticacao]].

### Organização do código

`src/schemas/<schema>/{tables,views,aggregates,functions}/<entidade>/<entidade>.{model,route}.js` + `.swagger.json`; `src/schemas/<schema>/index.js` registra models e a lista `rotas` (caminho, router, middlewares); `src/schemas/index.js` junta tudo ✅. Schemas com rotas: `auth`, `core`, `core_aprovacao_de_vagas`, `core_mapas`, `core_organograma`, `core_comissionamento`, `core_compras`, `core_fluxo`, `core_vendas_faturamento` e, desde 28/10, `core_comercial` (rotas `/comercial/*`, sem model Sequelize: SQL direto e funções `fn_*` do banco; ver "Módulo comercial" abaixo). `core_fluxo` não tem model Sequelize: usa SQL direto sobre funções do banco ✅ `core_fluxo/index.js:1-6`.

### Rotas do fluxo de Atividades

#### Liberação do pedido (LOG-26) — V1 a V3, P1, P2

Os números de linha desta seção são de 14/10 (`f322dcd`); só os da requisição de compra foram refeitos em 29/10. Nos demais arquivos podem ter deslocado poucas linhas.

| Rota | Quem chama | O que faz | Código |
|---|---|---|---|
| `GET /pedidos_liberacao` | HUB | caixa do vendedor (escopo de vendedor do token) | ✅ `aggregates/pedidos_liberacao/pedidos_liberacao.route.js:88` |
| `PUT /pedidos_liberacao/:codigo_empresa/:numero_pedido` corpo `{acompanhamento_qualidade, updated_by}` | HUB | upsert da marcação; 404 `PEDIDO_FORA_DA_LIBERACAO`; 409 `PEDIDO_IMPORTADO_MES` | ✅ `:164-233` |
| `GET /pedidos_liberados` | MES | só `liberado` e `importado` | ✅ `aggregates/pedidos_liberados/pedidos_liberados.route.js:57` |
| `GET /pedidos_liberados/:numero/itens?codigo_empresa=` | MES | itens; 409 `PEDIDO_NAO_LIBERADO` | ✅ `:115`, `:53-56` |
| `POST /pedidos_liberados/:numero/importado?codigo_empresa=` corpo `{referencia}` (até 60 caracteres) | MES | grava `importado_mes_em` e a referência (idempotente) | ✅ `:143-170` |

Trava no banco: `trg_pedidos_vendas_liberacao_regras` e `_historico` (função no dump `:7751`; tabela `:18285`). A caixa só mostra pedidos a partir de `parametros_vendas.data_inicio_liberacao` ✅ tabela no dump `:18031`; o valor em produção ❓ Gustavo.

#### Requisição de compra (LOG-34, LOG-35) — P3, C0, C1

| Rota | Quem chama | O que faz | Código |
|---|---|---|---|
| `GET /compras/requisicoes` (`status`, `codigo_empresa`, `q`, `page`, `limit` até 200) | HUB | lista; fila ordenada por prazo | ✅ `tables/requisicoes_compra/requisicoes_compra.route.js:236` |
| `GET /compras/requisicoes/resumo` | HUB | contadores `abertas`, `em_cotacao`, `atendidas`, `canceladas` | ✅ `:292` |
| `PUT /compras/requisicoes/origem/:id_origem` | **MES** (chave `MES_INTEGRACAO_KEYS`, a única rota que ela abre) | `fn_requisicao_mes_aplicar`: `criada` (201), `atualizada`, `cancelada`, `ignorada_com_oc`, `ignorada_cancelada`, `nao_existe`; 409 `REQUISICAO_COM_OC` ao cancelar com OC | ✅ `:314`; `middlewares/apiKeyAuth.js:59-76` |
| `GET /compras/requisicoes/eventos?alterado_desde=&apos_id=&codigo_empresa=&limit=` (até 500) | **MES** (chave `API_KEYS`) | marcos com `autor` e `comprador` (view `vw_requisicoes_compra_eventos`, migration 035b; sem a view devolve `null`); cursor `(registrado_em, id)` | ✅ `:382` |
| `GET /compras/requisicoes/referencia?alterado_desde=&codigo_empresa=&apos_id=&page=&limit=` | **MES** (chave de serviço, sem token) | API-009: requisição do Compras com pedido de venda, para o PCP saber que o item já está em compra antes da OC aprovada; `visivel_ao_pcp = false` manda o MES apagar a linha; montada **antes** de `/compras/requisicoes/:id` | ✅ `views/vw_requisicoes_compra_referencia_mes/…route.js:59`; `core_vendas_faturamento/index.js:208` |
| `GET /compras/requisicoes/:id` | HUB | detalhe | ✅ `:466` |
| `POST /compras/requisicoes` | HUB (permissão `compras.pode_criar` no BFF) | cria requisição própria do Compras (sem `id_origem`); `status` e `id_ordem_compra` nunca vêm do cliente | ✅ `:479` |
| `PATCH /compras/requisicoes/:id` corpo `{status, motivo?}` | HUB | `aberta` ↔ `em_cotacao` ↔ `cancelada` (cancelar exige `motivo` de 3 a 500 caracteres e grava `cancelada_por_origem = 'compras'`); `atendida` nunca por aqui | ✅ `:586` |
| `DELETE /compras/requisicoes/:id` (contrato 55, 23/10) | HUB | exclusão lógica (`deleted_at`, `deleted_by`) de requisição do Compras; 409 `REQUISICAO_COM_OC` (já tem OC) e 409 `REQUISICAO_DO_MES` (veio do MES); 403 `SEM_PERMISSAO_EXCLUIR`; não gera marco | ✅ `:696-760` |

Estados da requisição no av-hub: `aberta`, `em_cotacao`, `atendida`, `cancelada` (CHECK `ck_requisicoes_compra_status`, dump `:18541`). `atendida` só pela trigger da OC (`trg_ordens_compra_requisicao`: OC que nasce com `id_requisicao` marca atendida; OC cancelada devolve todas as requisições a `aberta`) ✅ dump `fn_ordens_compra_requisicao` (dump `:6810`). O banco impõe `atendida ⇔ id_ordem_compra IS NOT NULL` (`ck_requisicoes_compra_atendida`).

**Marcos (14 tipos)** gravados por trigger em `requisicoes_compra_eventos`, só quando a requisição tem `id_origem`, ou seja, veio do MES ✅ `fn_req_evento` (dump `:8580`): `requisicao_recebida`, `em_cotacao`, `oc_criada`, `oc_removida`, `oc_enviada_aprovacao`, `oc_aprovada`, `oc_no_omie`, `fornecedor_confirmou`, `previsao_alterada`, `despachada`, `ocorrencia`, `oc_cancelada`, `requisicao_cancelada`, `requisicao_reaberta` (CHECK `requisicoes_compra_eventos_tipo_check`). Requisição criada pelo Compras não gera marco e não chega ao MES por esse caminho. O MES a enxerga pela referência da requisição (API-009, acima) e, depois da aprovação, pela referência da OC ✅.

#### Ordem de compra e aprovação — C2 a C4

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
| `GET /ordens-compra/referencia?alterado_desde=&codigo_empresa=&page=&limit=` | referência da OC para o MES (API-004/007), limite 100 padrão e 500 máximo; item com `destino[]` (`pedido_venda` ou `estoque`) e OC com `finalidade`; desde 26/10 traz o fornecedor (`codigo_fornecedor`, `nome_fornecedor`, `cnpj_fornecedor`, api007b, `a7fda49`). **O MES consome** a cada 5 min (desde 15/10, `develop` do MES) | ✅ `views/vw_ordens_compra_referencia_mes/…route.js:70`, `:38-39` |

**Regra de aprovação conferida no banco** (a que de fato roda):

- `fn_ordens_compra_nascer` (BEFORE INSERT): toda OC nasce `aguardando_aprovacao` (ou `rascunho`) ✅ dump `:6619`.
- `fn_ordens_compra_recalcular` (itens): depois de somar os itens, a OC com `valor_total_brl` **até** `parametros_compras.limite_aprovacao` (padrão R$ 30 000,00 por unidade) vira **`aprovado` sozinha**; acima do limite fica `aguardando_aprovacao`; uma OC já aprovada que sobe acima do limite volta a `aguardando_aprovacao` ✅ dump `:6750`.
- `fn_ordens_compra_status` (BEFORE UPDATE): `cancelado` é final; aprovar acima do limite exige que a OC tenha passado por `aguardando_aprovacao`; carimba `aprovado_em` e `cancelado_em` ✅ dump `:6851`.
- Quem decide: um usuário com `compras.pode_aprovar` (perfil Gerência de Compras) ✅ `ordens_compra.route.js:1235`.

Isto **é** a regra decidida em 14/10 (N14-21): a OC que excede R$ 30 mil é aprovada pelo Gerente de Compras; até R$ 30 mil os compradores ficam livres (o banco aprova sozinho); a Diretoria não aprova ✅ (`ordens_compra.route.js:1230-1240`; função `fn_ordens_compra_recalcular` em `docs/ENVIAR - contrato-compras-backend.md:649-694` do HUB). 🟡 A regra é provisória: endurece depois da conversa com Compras. Ver [[Contradicoes-Resolvidas]] CR-13.

#### Status por item (API-005/006) — todos os nós

| Rota | Faz | Código |
|---|---|---|
| `GET /itens_pedido_status?codigo_empresa=&pedido_venda=` | etapa dos itens do pedido, com escopo de vendedor | ✅ `tables/itens_pedido_status/itens_pedido_status.route.js:54` |
| Job | a cada `MES_STATUS_INTERVALO_SEG` (padrão 90 s) por unidade ativa: `GET {MES_API_URL}/itens/status?alterado_desde=&codigo_empresa=&incluir_deletados=true&limit=1000`; grava com `fn_itens_pedido_status_gravar`; trava `avhub.mes_status_itens`; corte inicial `MES_STATUS_CORTE_INICIAL_DIAS` (30) | ✅ `itens_pedido_status.job.js:3-60` |

#### Torre de Fluxo (LOG-46) — os 9 setores

| Rota | Permissão (migration 046/046b em `auth.rotas_telas`) | Faz | Código |
|---|---|---|---|
| `GET /fluxo/torre?codigo_empresa=&setor=&etapa=&situacao=&q=&page=&limit=` (`situacao` = `no_prazo`, `fora_do_prazo`, `sem_dono`; até 500 por página) | `torre-fluxo` | mapa por setor e lista de itens (`fn_torre_setores`, `fn_torre_itens`) | ✅ `core_fluxo/tables/item_estado_projetado/item_estado_projetado.route.js:185` |
| `GET /fluxo/itens/:id` | `torre-fluxo-trilha` (mostra nomes de pessoas) | item + trilha (MES + eventos do hub) + tempo | ✅ `:302` |
| `GET /fluxo/itens/:id/tempo` | `torre-fluxo` | tempo por etapa (proxy do MES) | ✅ `:281` |
| `GET /fluxo/sla-etapas` | `torre-fluxo` | meta por etapa (proxy do MES) | ✅ `:262` |

- **Projeção:** `core_fluxo.item_estado_projetado`, uma linha por `(codigo_empresa, numero_pedido, codigo_item_omie)`, escrita **só** por `core_fluxo.fn_feed_aplicar` ✅ dump `:2169`. Também existem `core_fluxo.evento` (eventos do hub, append-only, nasce vazia) e `core_fluxo.feed_cursor` (`fonte = 'mes'`).
- **Job:** `item_estado_projetado.job.js` a cada 90 s (`INTERVALO_MS`), primeira rodada aos 5 s, `GET {MES_API_URL}/fluxo/eventos?apos_seq=<cursor - 200>&limite=1000`, até 50 páginas por rodada, trava `avhub.fluxo_feed`; 404 do MES = "feed ainda não publicado": avisa uma vez e espera 10 min ✅ `:46-60`.
- **Escopo:** por unidade (`auth.usuarios_unidades`); fora do escopo, 403 na lista e 404 no item; MES fora do ar devolve 200 com `mes_indisponivel = true` ✅ `:16-33`.
- **Estado hoje:** o MES **não publica** `/fluxo/*` 🔴 (Robert); o job está dando 404. O HUB já tem a tela da Torre (15/10, BL-022; ver [[AV-Hub-Front]]). A 046b concede as duas telas só ao perfil de testes do time de TI ✅ comentário `:22-25`, então nenhum perfil de negócio abre a Torre; a concessão real ❓ Gustavo.

#### Custo real por item (LOG-47 §1, API-008) — E3, R4

| Rota | Permissão | Faz | Código |
|---|---|---|---|
| `GET /itens_pedido_custo?codigo_empresa=&numero_pedido=` | `custo-itens.pode_visualizar`, **sempre** (também sem token, via `id_usuario_sessao`); 403 `USUARIO_NAO_INFORMADO`/`SEM_PERMISSAO`; `PEDIDO_FORA_DO_ESCOPO` para vendedor sem escopo | custo por produto do pedido: `quantidade`, `quantidade_com_custo`, `custo_total`, `custo_medio`, `completo`, `cotacao_a_conferir`, `lotes`; pedido manual devolve `pedido_manual: true` e itens vazios | ✅ `tables/itens_pedido_custo/itens_pedido_custo.route.js:66-154` |
| Job | chave `MES_API_KEY` | a cada 90 s por unidade ativa: `GET {MES_API_URL}/itens/custo?alterado_desde=<cursor>&apos_id=&codigo_empresa=&limit=1000`; grava com `fn_itens_pedido_custo_gravar`; 1ª leitura desde 1970; MES 404 = espera 10 min; trava `avhub.mes_custo_itens` | ✅ `itens_pedido_custo.job.js:51-60` |

- A migration **047b** troca a chave de `(unidade, pedido, item)` para `(unidade, pedido, codigo_produto_omie)` (o item é o produto) ✅ cabeçalho do job. O dump de 14/10 estava na 047 (rota daria 500); **o dump de 29/10 já está na 047b**: `UNIQUE uq_itens_pedido_custo (codigo_empresa, numero_pedido, codigo_produto_omie)` e `fn_itens_pedido_custo_do_pedido` devolve `codigo_produto_omie` ✅ (dump de 29/10, `:6290`, `:27722`). Ver [[Diferencas-Codigo-x-Banco]].
- O MES tem `GET /itens/custo` desde 27/10 (`6c11147`), só na `develop` do `api-pcp` ✅ ([[Modelo-Estoque-e-Custo-do-Lote]]). Enquanto a `develop` do MES não chega à produção, o job recebe 404.
- Etapas 2 (simulador pré-preenchido) e 3 (comissão por NF) do LOG-47 são Ciclo 2 e não leem a tabela ✅ comentário do job.

### Funções e triggers que carregam a regra

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
| `fn_itens_pedido_custo_gravar`, `_do_pedido` | idem para o custo (versão 047b no dump de 29/10) | dump de 29/10 `:6290`, `:6317` |
| `core_fluxo.fn_feed_aplicar`, `fn_torre_setores`, `fn_torre_itens`, `fn_evento_imutavel` | projeção da Torre | `:1914` |
| `auth.fn_autorizar`, `fn_me_permissoes`, `fn_escopo_vendedores_usuario`, `fn_validar_chave_servico` | permissão por rota, `/me/permissoes`, escopo, chaves de serviço | `:357` |

### Módulo comercial (`core_comercial`, `/comercial/*`) — contrato LOG-52, desde 28/10

Rotas montadas em `core_comercial/index.js`, todas com `exigirTokenUsuario` (token do usuário sempre), `asyncHandler`, `Idempotency-Key` nas escritas e `If-Match`/ETag na revisão da proposta. O código foi feito a pedido do Robert (28 e 29/10; N16-117). A permissão de cada rota sai de `auth.rotas_telas`; as capacidades (`escopo`, `ve_valores`, `ve_custo`…) saem de `core_comercial/capacidades.js` ✅.

| Rota | Faz | Código |
|---|---|---|
| `GET /comercial/me` | capacidades do usuário no módulo | ✅ `aggregates/cadastros/cadastros.route.js:39` |
| `GET /comercial/empresas_emissoras`, `GET /comercial/responsaveis` | empresa que emite a proposta; quem pode emitir em nome de quem | ✅ `:66`, `:107` |
| `GET`/`PUT /comercial/parametros_custo` | parâmetros de custo, com vigência | ✅ `:144`, `:170` |
| `POST /comercial/clientes` | cadastra o cliente no Omie da unidade e grava em `core.parceiros` (upsert por CNPJ) | ✅ `aggregates/clientes/clientes.route.js:120` |
| `GET /comercial/parceiros?tipo=&empresa=` | cadastro de parceiros para a proposta | ✅ `aggregates/parceiros/parceiros.route.js:33` |
| `POST`/`GET /comercial/propostas`, `GET …/resumo`, `GET …/:id`, `GET …/:id/eventos` | cria (status `ABERTA`), lista, KPIs, abre, linha do tempo | ✅ `aggregates/propostas/propostas.route.js:328-478` |
| `PUT …/:id`, `POST …/:id/aprovar`, `…/cancelar`, `…/copiar`, `…/transformar` | revisão na negociação, ciclo de vida até o pedido | ✅ `:495-548` |

⚠️ O código e o dump de 29/10 ainda guardam proposta, itens e eventos em `core_comercial.*` (23 tabelas, herdadas da `api-comercial`), enquanto a decisão N16-116 manda a proposta para `core_vendas_faturamento` e diz que `core_comercial` não existirá. Ver [[Banco-AvHub]] e a dúvida registrada no relatório do dia.

Rotas do `core_vendas_faturamento` acrescentadas depois de 14/10 (resumo):

- Setor do cliente e do grupo (API-014): `GET/POST/PUT /setores_clientes`, `PUT /clientes_setor` (vários setores por cliente desde 23/10) ✅ `tables/setores_clientes`, `tables/clientes_setor`.
- Portal PCP (API-016/017): `GET /pedido_item_observacao_pcp`, `/contagem`, `POST`, `DELETE /:id`; carteira com período e previsão (`GET /pedidos_venda/carteira`, `/carteira/vendedores`, `/carteira/previsao`) ✅. `/pedido_observacao_pcp` (por parcial) continua montada, sem uso na tela.
- Duplicatas prováveis de produto (21/10) em `core/tables/produtos` e `utils/produtosDuplicatas.js` ✅.

### Outros módulos (resumo; detalhe nos anexos)

Vendas e faturamento (`/pedidos_venda`, `/vendas_*`, `/faturamento_*`, `/dashboard*`, `/ranking_*`, `/ritmo_*`, `/nf_classified`), Comissão (`core_comissionamento`), Vagas (`core_aprovacao_de_vagas`), Organograma, Orçamento (`/orcamento/*` sobre `core_compras.orc_*`), cadastros `core.*` (parceiros, produtos, unidades, funcionários), Acompanhamento de Clientes e grupos de clientes (`/acompanhamento_clientes`, `/grupos_clientes`, contrato 48). Ficam em [[Comissoes]], [[Dashboards]], [[Orcamento]], [[RH-Vagas-Funcionarios]], [[Acompanhamento-Clientes]].

### Variáveis de ambiente (conferidas)

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

### Defeitos conhecidos da API

Resumo; lista com severidade em [[Bugs-Conhecidos]].

- ✅ Corrigido em 16/10 (`38d2f74`): `alterado_desde` em `GET /produtos` e `GET /parceiros` agora roda antes do `return where` (`core/tables/produtos/produtos.route.js:51-70`, `core/tables/parceiros/parceiros.route.js:97-110`).
- 🔴 `pessoa_vendedor` tem model e rota (`/pessoa_vendedor`) e a tabela não existe nos dumps de 14/10 e de 29/10 (`schemas/core_vendas_faturamento/index.js` monta o router).
- ✅ A tabela `itens_pedido_custo` do dump de 29/10 já está na versão 047b.
- ❓ `usuarios_favoritos.model.js:13` declara `id` sem `defaultValue` (de propósito, o banco tem `DEFAULT uuidv7()`); o POST de favoritos já deu `400 "Campo obrigatório não informado: id"` em setembro; não reproduzido em 14/10 e não reconferido em 29/10.
