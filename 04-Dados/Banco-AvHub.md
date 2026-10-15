---
tags: [dados, banco, av-hub, postgres]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Gustavo (DBA)
fontes: [Dump Avhub (Esqueleto).sql de 14/10/2026, api-acos-vital f322dcd, omie-elt-pipeline 0f739f0, v1 AV-Hub-API-Estado-Atual, Schema-Postgres-Multi-Dominio]
---

# Banco do av-hub

PostgreSQL do av-hub, de responsabilidade do DBA (Gustavo). Usado pela `api-acos-vital` ([[AV-Hub-API]]) e pela pipeline Omie ([[Pipeline-Omie]], que escreve direto nas tabelas `core*` e `omie_*`). O dump de 14/10 é só esqueleto: **126 tabelas, 44 views, 178 funções, 125 triggers, 13 schemas**, sem nenhuma linha de dado ✅ `grep` do dump. A `api-comercial` usa **outro** schema, `core_comercial`, que não está neste dump ([[API-Comercial]]). Por que o av-hub tem vários schemas e o MES um só: [[Schemas-Postgres]]. Banco do MES: [[Banco-MES]]. Selos: [[Regras-do-Vault]].

## Schemas

| Schema | Tabelas | Views | Conteúdo | Dono do dado |
|---|---|---|---|---|
| `auth` | 15 | 2 | usuários, perfis, telas, permissões, mapa rota → tela, chaves de serviço, sessões, auditoria, favoritos ([[RBAC-e-Permissoes]]) | av-hub |
| `core` | 22 | 1 | cadastros: `unidades`, `parceiros` (+endereço, dados bancários, tipos, produtos), `produtos`, `funcionarios`, `cargos`, `setores`, `familia_produtos`, `categorias`, `cnaes`, `projetos`, `contas_correntes`, `cotacoes_moeda`, `etapas_faturamento`, `locais_estoque`, `estoque_saldo`, `documentos_anexos`, `origem_dados` | Omie (pipeline) e cadastro |
| `core_vendas_faturamento` | 50 | 20 | pedidos de venda, NF, liberação, **requisições e ordens de compra**, follow-up, status e custo por item, comissão provisória, metas, blacklists | Omie + av-hub |
| `core_fluxo` | 3 | 1 | **Torre de Fluxo**: `evento`, `feed_cursor`, `item_estado_projetado` | av-hub (projeção do MES) |
| `core_compras` | 7 | 11 | catálogo/histórico de preços e Orçamento (`orc_*`, `produtos_compras`) | av-hub |
| `core_comissionamento` | 9 | 4 | simulador, regras fixas, bloqueios, coordenadores | av-hub |
| `core_aprovacao_de_vagas` | 4 | 1 | vagas e decisões | av-hub |
| `core_organograma` | 7 | 2 | organograma e "welcome" | av-hub |
| `core_mapas` | 0 | 2 | `mapa_unidades`, `vw_todos_os_clientes` | view |
| `historico` | 3 | 0 | `hst_pedidos_vendas`, `hst_notas_fiscais`, `hst_produto_vendas` (histórico congelado) | pipeline |
| `omie_raw` | 5 | 0 | **obsoleto e vazio** (N14-27): staging bruto `"notasFiscais"`, `"pedidosVendas"`, `parceiros`, `produtos`, `vendedores`, de `sql/002_staging_tables.sql`, que só servia à auditoria opcional `RAW_AUDIT_ENABLED`, removida do código no contrato 38; nada lê nem escreve ([[Pipeline-Omie]]). `DROP` das tabelas e do schema: Gustavo (BL-054) | — |
| `omie_ctl` | 1 | 0 | `run_log` (execuções da pipeline) | pipeline |
| `core_estoque` | 0 | 0 | **vazio** (criado e sem objetos) 🟡 | — |

Contagem por `CREATE TABLE`/`CREATE VIEW` do dump ✅. O estoque físico da fábrica **não** está no av-hub: `core.estoque_saldo` e `core.locais_estoque` são espelho do Omie (a extração `estoque` está desligada) e `core_estoque` não tem nada ✅ `omie-elt-pipeline/src/omie/resources/estoque.ts:16`; o saldo real é o do MES ([[Modelo-Estoque-e-Custo-do-Lote]]).

Convenções ✅: chave `uuid` com `DEFAULT uuidv7()`; colunas de auditoria (`created_at`, `created_by`, `updated_at`, `updated_by`, `deleted_at`, `deleted_by`) com `trg_*_updated_at` (`public.set_updated_at`); quantidades de requisição e OC em `numeric(15,4)`; dinheiro `numeric(15,2)`; empresa por `codigo_empresa uuid` (= `core.unidades.id`).

## Tabelas do fluxo de Atividades (`core_vendas_faturamento`)

### Liberação do pedido (V1 a V3, P1, P2)

| Tabela / view | Colunas e regras | Dump |
|---|---|---|
| `pedidos_vendas` | pedido do Omie, PK `(codigo_empresa, codigo_pedido_omie)`; `numero_pedido`, `sequencial`, `etapa`, `situacao`, `data_inclusao`, `data_previsao`, `codigo_cliente`, `codigo_vendedor_omie`, `valor_total_pedido`, `faturado`, `cancelado`, `devolvido`, `encerrado`, **`manual`** (protegida da pipeline) | `:2328` |
| **`pedidos_vendas_liberacao`** | PK `(codigo_empresa, numero_pedido)`; `acompanhamento_qualidade boolean NOT NULL`, `liberado_por`, `liberado_em`, `updated_by`, `updated_at`, **`importado_mes_em`**, **`importado_mes_referencia`** (60) | `:18285` |
| `pedidos_vendas_liberacao_historico` | `acao` em `liberado`, `alterado`, `importado_mes`; `valor_anterior`, `usuario`, `referencia` | dump |
| `parametros_vendas` | linha única (`id = 1`); **`data_inicio_liberacao`** (corte da caixa) | `:18031` |
| view `vw_pedidos_liberacao` | `status_liberacao` = `importado` (tem `importado_mes_em`), `liberado` (tem linha de liberação) ou `pendente`; só pedidos com `sequencial = 0`, `etapa <> 0`, sem `deleted_at`, `data_inclusao >= data_inicio_liberacao` e (liberado **ou** `situacao = 'Pendente'`) | dump |

### Requisição de compra (P3, C0, C1)

| Tabela | Colunas e regras | Dump |
|---|---|---|
| **`requisicoes_compra`** | `numero_requisicao` (gerado pelo banco, único por unidade), `codigo_empresa`, `material` (60), `descricao`, **`quantidade numeric(15,4) > 0`**, `unidade_medida` (10), `prazo_necessidade date`, `acabado_sugerido`, `solicitante`, `status` (`aberta`, `em_cotacao`, `atendida`, `cancelada`), `id_ordem_compra`, **`id_origem uuid`** (id do item da requisição do MES), `numero_requisicao_mes`, `codigo_pedido_omie bigint`, `numero_pedido_venda`, `motivo_cancelamento`, `cancelada_por_origem` (`compras` ou `mes`). CHECK `atendida ⇔ id_ordem_compra IS NOT NULL` | `:18541` |
| **`requisicoes_compra_eventos`** | só inserção (`trg_req_eventos_imutavel`); `id_requisicao`, `id_origem`, `codigo_empresa`, `tipo` (14 valores), `ocorrido_em`, `registrado_em DEFAULT clock_timestamp()`, `status_requisicao`, `id_ordem_compra`, `dados jsonb`, `criado_por`; índice do cursor `(registrado_em, id)` | `:18680` |
| view `vw_requisicoes_compra_eventos` | acrescenta `autor` (usuário e funcionário) e `comprador` (migration 035b) | dump |
| `contadores_documento` | contador atômico por unidade e tipo (`requisicao`, `ordem_compra`) | `:16555` |

Tipos de marco: `requisicao_recebida`, `em_cotacao`, `oc_criada`, `oc_removida`, `oc_enviada_aprovacao`, `oc_aprovada`, `oc_no_omie`, `fornecedor_confirmou`, `previsao_alterada`, `despachada`, `ocorrencia`, `oc_cancelada`, `requisicao_cancelada`, `requisicao_reaberta` ✅ CHECK `requisicoes_compra_eventos_tipo_check`.

### Ordem de compra, aprovação e follow-up (C2 a C5)

| Tabela | Colunas e regras | Dump |
|---|---|---|
| **`ordens_compra`** | `numero_pedido` (`OC-` + contador), `codigo_empresa`, `id_requisicao`, `codigo_fornecedor`, `codigo_transportadora`, `tipo_frete` (CIF/FOB), `finalidade` (padrão `estoque`), `moeda` (padrão `BRL`), **`cotacao_moeda`**, `cotacao_data`, `cotacao_origem`, `valor_mercadorias`, `valor_descontos`, `valor_frete`, `valor_seguro`, `valor_total`, **`valor_total_brl`**, **`status`** (`rascunho`, `aguardando_aprovacao`, `aprovado`, `cancelado`), `aprovado_por`, `aprovado_em`, `cancelado_por`, `cancelado_em`, `motivo_reprovacao`, **`status_sincronizacao_omie`** (padrão `pendente`), `erro_sincronizacao_omie`, `codigo_pedido_omie`, `numero_pedido_omie`, `sincronizado_em`, `id_comprador`, `data_previsao_chegada`, `codigo_condicao_pagamento`, `quantidade_parcelas` | `:17257` |
| **`ordens_compra_itens`** | `ordem`, `codigo_produto`, `descricao_produto`, `quantidade numeric(15,4)`, `unidade_medida`, **`valor_unitario numeric(15,4)`**, `desconto` (%), `valor_desconto`, `valor_total_item`, **`tipo_material`** (`nao_acabado` padrão, ou acabado), `local_estoque`, `id_requisicao` | `:17737` |
| `ordens_compra_itens_vinculos` | item da OC → pedido de venda: `numero_pedido_venda`, `codigo_empresa_pv`, `quantidade`, `pv_conferido` | `:17804` |
| `ordens_compra_parcelas`, `ordens_compra_historico`, `ordens_compra_comprador_historico` | parcelas geradas pela condição, histórico de status, histórico de comprador | dump |
| **`ordens_compra_acompanhamento`** | 1 por OC: `confirmacao_status` (padrão `pendente`), `confirmado_em`, `confirmado_por`, `despachado_em`, `nf_fornecedor`, `transportadora` | `:17520` |
| `ordens_compra_contatos`, `ordens_compra_ocorrencias` | contatos (imutáveis) e ocorrências (`tipo`, `descricao`, `proposta_fornecedor`, `status` `aberta`, `decidido_por`, `decidido_em`) | `:17664`, `:17884` |
| **`ordens_compra_referencia_mes`** | `id_ordem_compra`, `alterado_em` (cursor da API-004); mantida por `fn_oc_referencia_mes_marcar` | `:17965` |
| view `vw_ordens_compra_referencia_mes` | OCs `aprovado` (e as canceladas que já foram aprovadas) com `situacao` `aprovada` ou `cancelada`, `itens` em jsonb (`id_item_oc`, `codigo_produto_omie`, `quantidade`, `tipo_material`, `local_estoque`, `id_requisicao`, `id_origem`, `numero_requisicao_mes`, `destino` por pedido de venda ou estoque, `valor_unitario`, `desconto_pct`, `valor_desconto`, `valor_total_item`), `moeda`, `cotacao_moeda`, `cotacao_data`, `cotacao_origem`, `valor_frete`, `valor_seguro` | dump |
| `parametros_compras` | por unidade: **`limite_aprovacao numeric(15,2) DEFAULT 30000.00`** | `:18001` |
| `compradores`, `condicoes_pagamento_compras` | espelho do Omie + vínculo comprador ↔ `core.funcionarios` | `:16375` |
| `pedidos_compras`, `pedidos_compras_itens`, `pedidos_compras_parcelas`, `pedidos_compras_etapas` | espelho dos pedidos de compra do Omie (não é a OC do av-hub) | dump |

Observações ✅: a **cotação da moeda é por OC** (`ordens_compra.cotacao_moeda`); o valor é por item. O 0b diz "valor, moeda e cotação por item": a cotação vale para a OC inteira.

### Status e custo por item (todos os nós, E3, R4)

| Tabela | Colunas e regras | Dump |
|---|---|---|
| `itens_pedido_status` | foto da parcial do MES: `codigo_empresa`, `id_item_parcial`, `pedido_venda`, `ordem_producao`, `codigo_produto_omie`, `codigo_produto`, **`etapa`** (11 valores, ver [[Estados-e-Status]]), `setor_codigo`, `setor_nome`, `setor_tipo`, `status`, `quantidade_na_etapa`, `atendido_pelo_estoque`, `ocorrido_em`, `mes_updated_at`, `mes_deleted_at`, `lido_em`; histórico (uma linha por foto) | `:16990` |
| `itens_pedido_status_cursor` | cursor por unidade | dump |
| view `vw_itens_pedido_status_atual` | etapa mais recente por item | dump |
| **`itens_pedido_custo`** | `quantidade`, `quantidade_com_custo`, `custo_total numeric(18,6)`, `custo_medio`, `completo`, `cotacao_a_conferir`, `lotes jsonb`, `id_mes`, `mes_alterado_em`; **no dump a chave é `(codigo_empresa, numero_pedido, item)` (migration 047), o código espera `codigo_produto_omie` (047b)** 🔴 | `:16782` |
| `itens_pedido_custo_cursor` | cursor por unidade | dump |

### Torre de Fluxo (`core_fluxo`)

| Objeto | Regra | Dump |
|---|---|---|
| `item_estado_projetado` | estado atual por `(codigo_empresa, numero_pedido, codigo_item_omie)`: `id_item_mes`, `etapa_fluxo`, `estado_macro`, `setor_fluxo`, responsável (`id_responsavel_atual`, nome, setor, `fila_setor_fluxo`), `entrou_etapa_em`, `prazo_pedido`, `encerrado_em` e `encerramento` (`cancelado` ou `concluido`), `ultimo_seq`, `ultimo_evento_*`; escrita só por `fn_feed_aplicar` | `:2169` |
| `evento` | eventos do hub (Comercial e Compras), `seq bigint`, `origem = 'av-hub'`, ator, autorizador (diferente do ator), `passou_para_*`, `motivo`; só inserção; **nasce vazia, a instrumentação do hub é pergunta aberta** | `:15649` |
| `feed_cursor` | `fonte` (`mes`), `ultimo_seq` | dump |
| view `vw_item_estado_atual` e funções `fn_torre_setores`, `fn_torre_itens`, `fn_feed_aplicar` | leitura da Torre | dump |

## Funções e triggers que carregam a regra de compra

Lista, com a regra de aprovação por limite, em [[AV-Hub-API]]. Resumo dos objetos que o MES e o HUB dependem: `fn_requisicao_mes_aplicar` (`:8680`), `fn_req_evento` (`:8580`), `fn_requisicoes_compra_status` (`:8923`) e `_zz_eventos` (`:8961`), `fn_ordens_compra_nascer` (`:6619`), `_recalcular` (`:6750`), `_requisicao` (`:6810`), `_status` (`:6851`), `fn_oc_referencia_mes_marcar`, `fn_pedidos_vendas_liberacao_regras` (`:7751`), `fn_itens_pedido_*_gravar`, `core_fluxo.fn_feed_aplicar` (`:1914`), `auth.fn_autorizar` (`:357`).

## O que falta no banco para o fluxo (DBA)

| Falta | Para | Selo |
|---|---|---|
| Aplicar a migration **047b** na base que gerou o dump | custo por item | 🔴 |
| Nada na aprovação: a trigger `fn_ordens_compra_recalcular` já aprova até o limite e deixa `aguardando_aprovacao` acima dele (N14-21 ✅); só endurecer depois, com Compras 🟡 | C2/C3 | ✅ |
| A referência da OC para o MES (`vw_ordens_compra_referencia_mes`) já traz `destino` por pedido de venda ou estoque e `finalidade`, mas só das OCs `aprovado` e das canceladas que já foram aprovadas: OC `aguardando_aprovacao` não aparece. Conferir se isso basta para o **saldo futuro** do Estoque (N14-20) ou se o MES precisa também das OCs em aprovação e de uma consulta por produto e por pedido (BL-028) | C0 → MES | 🔴 |
| Instrumentar `core_fluxo.evento` com os marcos do hub (Comercial e Compras) | Torre | 🔴 |
| Linhas de `auth.rotas_telas` e `auth.telas` para `torre-fluxo`, `torre-fluxo-trilha`, `custo-itens` | permissões | ❓ |
| Tabela `core_comercial.*` publicada e conferida | Comercial | ❓ |

Diferenças entre código e banco: [[Diferencas-Codigo-x-Banco]].
