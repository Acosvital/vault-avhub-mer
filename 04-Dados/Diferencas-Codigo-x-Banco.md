---
tags: [dados, auditoria, codigo-x-banco, mes, av-hub]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [api-pcp 579a625, app-pcp 1fca8d3, api-acos-vital f322dcd, HUB b55ac55, omie-elt-pipeline 0f739f0, Dump MES e Dump Avhub de 14/10 (15:00), conferência automática por script em 14/10]
---

# Diferenças entre código e banco

O que existe no banco sem código (ou o código usa só em parte) e o que o código espera e o banco não tem. **Conferido em 14/10** comparando os models e as rotas dos repositórios com os dois dumps de esqueleto. Os dumps não têm dados, então esta nota não diz nada sobre conteúdo (linhas de `telas`, `auth.rotas_telas`, `parametros_*`) ❓. Mapa de bancos: [[Banco-MES]], [[Banco-AvHub]], [[Schemas-Postgres]]. Selos: [[Regras-do-Vault]].

## Placar

| Comparação | Resultado |
|---|---|
| MES: 46 models Prisma x 46 tabelas de negócio do dump | ✅ iguais, nome a nome |
| MES: colunas de cada model x colunas de cada tabela | ✅ iguais em todas as 46 tabelas (nenhuma coluna só de um lado) |
| MES: 21 enums Prisma x 21 `CREATE TYPE` | ✅ mesmos valores |
| MES: migrations x dump | ✅ a última (`20261014120000_compras_ccp`) está refletida: `requisicoes_compra.nf_chegada`, `chave_nf_chegada`, `chegada_em`, `liberada_recebimento_*` e `requisicoes_compra_itens.etapa_compra`, `oc_aprovada_em`… presentes (dump `:1188-1274`) |
| av-hub: 109 models Sequelize x 126 tabelas e 44 views | ✅ 108 batem (todo campo de model existe na tabela); **1 sem tabela**: `core_vendas_faturamento.pessoa_vendedor` 🔴 |
| av-hub: objetos de banco citados no SQL das rotas x dump | ✅ todos existem, exceto os já listados abaixo |
| av-hub: migrations do contrato 46/47 x dump | 🔴 **047b não aplicada** no banco que gerou o dump |

## MES: banco sem código (ou com pouco)

| Objeto | Situação | Selo | Evidência |
|---|---|---|---|
| Tabela `fornecedores` | existe, tem model, **nenhum código escreve nem lê** (projeção de `core.parceiros` prevista na D3) | 🟡 | dump `:595`; grep `prisma.fornecedor` sem ocorrência |
| `OrigemCusto` `OC` e `MANUAL` | valores no enum, nenhum escritor (só `CARGA_INICIAL`) | 🔴 | `estoque-operacao.service.ts:440` |
| `OrigemLote` | sem valor para lote de produção (fabricado) | 🔴 | dump `:155-158` |
| `StatusPedido.BLOQUEADO` | só é lido pelo dashboard; nenhum código o atribui | 🟡 | `dashboard.service.ts` |
| `TipoAnexo` `CANHOTO`, `COMPROVANTE_ENTREGA` | sem referência fora do enum; `DESENHO` é usado | 🟡 | grep |
| `requisicoes_compra.pedido_compra`, `fornecedor`, `previsao_entrega`, `comprado_em` | colunas do "Registrar compra" manual (removido); hoje só recebem o espelho do que o av-hub informa | 🟡 | dump `:1198-1201`; `requisicao-avhub.eventos.ts` |
| `requisicoes_compra_itens.avhub_*` | preenchidas pelo envio (LOG-34); `avhub_status` guarda o status do av-hub | ✅ | `envio-avhub.service.ts` |
| `materiais.estoque_maximo` | só cadastro, sem alerta que o use | 🟡 | grep (1 ocorrência) |
| `lote_custo` sem escritor de `OC` e `MANUAL`, sem snapshot na `SAIDA`, sem `custo_alterado_em` | contrato 008 §3 a §5 sem código | 🔴 | [[API-008-Custo-do-Lote-no-MES]] |

## MES: código sem banco (precisaria de tabela ou coluna)

| O código ou o contrato quer | O banco não tem | Selo |
|---|---|---|
| Documento de retirada (E6) | nenhuma tabela `documentos_retirada` | 🔴 |
| Feed de eventos para a Torre (`/fluxo/eventos`, `seq` global) | nenhuma tabela de evento | 🔴 |
| `GET /itens/custo` com `alterado_desde` | nenhuma marca de alteração de custo no item | 🔴 |
| Lote de fabricado aprovado | sem `OrigemLote` e sem vínculo lote ↔ parcial de origem | 🔴 |

## av-hub: banco sem código

| Objeto | Situação | Selo | Evidência |
|---|---|---|---|
| `core_fluxo.evento` | tabela e imutabilidade prontas, **nenhum código a escreve** (a instrumentação do hub é a pergunta 3 do contrato 46); só é lida em `GET /fluxo/itens/:id` | 🔴 | dump `:15649`, comentário `:15690`; grep sem `INSERT` |
| `core_fluxo.item_estado_projetado` e `feed_cursor` | só o job escreve; o MES não publica o feed, então ficam vazias | 🔴 | [[AV-Hub-API]] |
| `itens_pedido_custo` e cursor | só o job escreve; o MES não tem `/itens/custo` | 🔴 | idem |
| Schema `core_estoque` | criado, **sem nenhum objeto** | 🟡 | dump `:163` |
| `core.estoque_saldo` e `core.locais_estoque` | tabelas, model e rotas existem; o sync do Omie está desligado (`enabled: false`, `table: null`) | 🟡 | `omie-elt-pipeline/src/omie/resources/estoque.ts:16,32` |
| `omie_raw.*` (5 tabelas de staging: `notasFiscais`, `parceiros`, `pedidosVendas`, `produtos`, `vendedores`) | **obsoleto** (N14-27): `sql/002_staging_tables.sql` era opcional (só para `RAW_AUDIT_ENABLED=true`); a auditoria saiu do código no contrato 38 (`ARCHITECTURE.md:41`, `:256-257`); o README manda rodar só `001` e `003` (`README.md:66-67`); nada lê nem escreve. Resta o `DROP` das tabelas e do schema (Gustavo, BL-054) | 🟡 | grep `omie_raw` em `omie-elt-pipeline/src` sem ocorrência |
| `omie_ctl.run_log` | usado pela pipeline (`logRun`) | ✅ | `src/db/upsert.ts` |
| `historico.hst_*` | lidas pela API (escopo e planilha de faturamento); **a pipeline não as escreve** (carga congelada) | 🟡 | `escopoVendedor.js`, `vw_faturamento_planilha.model.js` |
| `core_vendas_faturamento.pedidos_compras_etapas` | de-para de etapa do Omie, lido pelo dashboard de OC; nenhum código escreve | 🟡 | `ordens_compra.dashboard.js:316` |
| `ordens_compra_referencia_mes` e a view `vw_ordens_compra_referencia_mes` | prontas e servidas por `GET /ordens-compra/referencia`; **nenhum consumidor** (o MES não chama) | 🔴 | [[Integracao-AvHub-MES]] INT-04 |
| `requisicoes_compra_eventos` para requisição do Compras | `fn_req_evento` ignora requisição sem `id_origem`: o marco nunca nasce. **Não é a lacuna:** o MES vê a OC dessa requisição pela referência (`GET /ordens-compra/referencia`, N14-20); falta o MES lê-la (BL-006, BL-049 a BL-051) | 🔴 | dump `:8580` |

## av-hub: código sem banco, ou banco antigo

| O código espera | O dump tem | Selo | Evidência |
|---|---|---|---|
| `fn_itens_pedido_custo_do_pedido` devolvendo `codigo_produto_omie` (migration **047b**) e tabela única por produto | versão **047**: coluna `item`, `UNIQUE (codigo_empresa, numero_pedido, item)`, função devolvendo `item` | 🔴 | `itens_pedido_custo.route.js:98-103` x dump `:4393`, `:16782`, `:23010` |
| model `pessoa_vendedor` e rota `/pessoa_vendedor` | **sem tabela nem view** (as funções `fn_detalhe_vendedor_*` já saíram do JOIN) | 🔴 | `schemas/core_vendas_faturamento/index.js`; `fn_detalhe_vendedor_vendas.route.js:67-70` |
| view `vw_requisicoes_compra_eventos` (035b) | ✅ existe; a rota ainda cai para a tabela sem `autor`/`comprador` se faltar | ✅ | `requisicoes_compra.route.js:341-346` |
| `fn_requisicao_mes_aplicar` (034) | ✅ existe | ✅ | dump `:8680` |
| objetos do contrato 46 (046) | ✅ existem (`core_fluxo.*`, funções da Torre); **a 046b** (zeros no mapa, concessão só ao Admin) não se prova por esqueleto | ❓ | `item_estado_projetado.route.js:16-30` |
| API-004/007 (`moeda`, `cotacao_*`, `valor_frete`, `valor_seguro` na referência) | ✅ colunas na view | ✅ | dump `vw_ordens_compra_referencia_mes` |
| views `vw_ritmo_*_hora`, `vw_volume_pedidos_diario*` | não existem; **só aparecem em comentários** (as rotas foram reconstruídas) | ✅ sem problema | `ritmo_faturamento_hora.route.js:8` |
| `auth.rotas_telas` com `/fluxo/*`, `/itens_pedido_custo`, `/compras/requisicoes/eventos` | tabela existe; linhas ❓ | ❓ | [[RBAC-e-Permissoes]] |

## Entre os sistemas (contrato x código)

| Contrato | Lado que expõe | Lado que consome | Selo |
|---|---|---|---|
| LOG-26 liberação | av-hub ✅ | MES ✅ | ✅ |
| LOG-34 requisição, ida | av-hub ✅ (`PUT`) | MES ✅ (fila) | ✅ |
| LOG-35 marcos, volta | av-hub ✅ (`/eventos`) | MES ✅ (todos os 14 marcos) | ✅ para requisição do MES |
| API-004/007 referência da OC | av-hub ✅ | MES ❌ | 🔴 |
| API-005/006 status por item | MES ✅ (`/itens/status`) | av-hub ✅ (job) + HUB ✅ (card) | ✅ |
| API-008/LOG-47 custo por item | MES ❌ | av-hub ✅ (job e rota) + HUB ❌ (sem tela) | 🔴 |
| LOG-46 Torre | MES ❌ (`/fluxo/*`) | av-hub ✅ (job e rotas) + HUB ❌ (sem tela) | 🔴 |
| API-003 requisições lidas do MES | MES ✅ | ninguém | 🟡 |

## Divergências de regra (documento x código)

| Documento | Código | Selo |
|---|---|---|
| 0b e decisão N14-21 (14/10): "OC acima de R$ 30 mil, o Gerente de Compras aprova; até R$ 30 mil, compradores livres; sem Diretoria" | igual: OC até o limite é **auto-aprovada** pelo banco; acima dele só a alçada `compras.pode_aprovar` decide (`ordens_compra.route.js:1230-1240`) | ✅ [[AV-Hub-API]] |
| 0b: "cotação PTAX por item" | a cotação é **da OC** (`ordens_compra.cotacao_moeda`, `cotacao_data`, `cotacao_origem`); o valor é por item | 🟡 |
| 0b: "despacho no Estoque, baixa na retirada" | baixa na Embalagem/Expedição (`consumirReservasDaParcial`) | 🔴 [[Modelo-Estoque-e-Custo-do-Lote]] |
| 0b: "Q8 sim → Estoque (E5)" | segue para a Expedição | 🔴 |
| Registro de decisões: "nenhuma regra em ambiente para jobs novos" | Torre e custo cumprem; o job do status (005/006) e os timers do MES ainda leem ambiente | 🟡 [[Bugs-Conhecidos]] |
