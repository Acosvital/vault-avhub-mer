---
tags: [dados, auditoria, codigo-x-banco, mes, av-hub]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [api-pcp befd973 (develop), app-pcp 93f96de (develop), api-acos-vital 0384e89 (develop), av-hub 758d5f0 (develop), omie-elt-pipeline 0f739f0, Dump MES de 14/10, Dump Avhub de 14/10 e de 29/10, conferência por script em 14/10 e 29/10]
---

# Diferenças entre código e banco

O que existe no banco sem código (ou o código usa só em parte) e o que o código espera e o banco não tem. **Conferido em 14/10 e refeito em 29/10** comparando os models e as rotas dos repositórios com os dumps de esqueleto (do av-hub há um dump novo, de 29/10; do MES só o de 14/10, então as tabelas novas do MES só se conferem pelas migrations). Os dumps não têm dados, então esta nota não diz nada sobre conteúdo (linhas de `telas`, `auth.rotas_telas`, `parametros_*`) ❓. Mapa de bancos: [[Banco-MES]], [[Banco-AvHub]], [[Schemas-Postgres]]. Selos: [[Regras-do-Vault]].

## Placar

| Comparação | Resultado |
|---|---|
| MES: 46 models Prisma x 46 tabelas de negócio do dump de 14/10 | ✅ iguais, nome a nome, em 14/10 |
| MES `develop` (29/10): 54 models x 46 tabelas do dump | 🟡 8 tabelas novas (`consumos_materia_prima`, `entradas_uso_interno`, `fila_setor_ordem`, `lote_custo_historico`, `oc_referencia`, `oc_referencia_itens`, `recebimentos_nf`, `requisicoes_hub_referencia`) e 1 enum novo (`OrigemRequisicao`) nas migrations de 15 a 28/10; sem dump novo do MES para provar o banco ❓ |
| MES: migrations x dump | ✅ até `20261014120000_compras_ccp` o dump reflete; as 11 migrations seguintes (`20261015120000` a `20261028120100`) só existem no repositório (`develop`) |
| av-hub: models Sequelize (tabelas e views) x dump de 29/10 (156 tabelas e 52 views) | ✅ 204 de 205 batem; **1 sem objeto no banco**: `core_vendas_faturamento.pessoa_vendedor` 🔴 |
| av-hub: objetos de banco citados no SQL das rotas x dump | ✅ todos existem, exceto os já listados abaixo |
| av-hub: migrations dos contratos 46/47 x dump | ✅ a **047b** está aplicada no dump de 29/10 (estava 🔴 em 14/10) |
| av-hub: `core_comercial` | ✅ existe no dump de 29/10 (23 tabelas, 3 views, 12 funções) e o código de `/comercial/*` o usa; a decisão N16-116 diz que `core_comercial` não existirá 📝 |

## MES: banco sem código (ou com pouco)

Conferido de novo em 29/10 no código da `develop`.

| Objeto | Situação | Selo | Evidência |
|---|---|---|---|
| Tabela `fornecedores` | existe, tem model, **nenhum código escreve nem lê** (projeção de `core.parceiros` prevista na D3) | 🟡 | dump `:595`; grep `prisma.fornecedor` sem ocorrência |
| `OrigemCusto` `OC` e `MANUAL` | **agora têm escritor**: `OC` no Recebimento (`compra-oc.ts:114`, desde 16/10) e `MANUAL` em `PUT /estoque/lotes/:id/custo` (`estoque-operacao.service.ts:715`, 27/10) | ✅ | `compras.service.ts:1045`, `recebimento.service.ts:1135` |
| `OrigemLote` | ganhou `PRODUCAO` (28/10) e o código a usa para o fabricado aprovado | ✅ | `estoque.prisma:11-17`, `itens-parciais.service.ts:1489,1505` |
| `StatusPedido.BLOQUEADO` | só é lido pelo dashboard; nenhum código o atribui | 🟡 | `dashboard.service.ts` |
| `TipoAnexo` `CANHOTO`, `COMPROVANTE_ENTREGA` | sem referência fora do enum; `DESENHO` é usado | 🟡 | grep |
| `requisicoes_compra.pedido_compra`, `fornecedor`, `previsao_entrega`, `comprado_em` | colunas do "Registrar compra" manual (removido); hoje só recebem o espelho do que o av-hub informa | 🟡 | dump `:1198-1201`; `requisicao-avhub.eventos.ts` |
| `requisicoes_compra_itens.avhub_*` | preenchidas pelo envio (LOG-34); `avhub_status` guarda o status do av-hub | ✅ | `envio-avhub.service.ts` |
| `materiais.estoque_maximo` | só cadastro, sem alerta que o use | 🟡 | grep (1 ocorrência) |
| `lote_custo`: escritor de `OC` e `MANUAL`, snapshot na `SAIDA` (`movimentos_estoque.custo_unitario`) e `itens_pedido.custo_alterado_em` | contrato 008 §3 a §5 com código na `develop` (16 e 27/10) | ✅ | [[API-008-Custo-do-Lote-no-MES]]; `estoque-operacao.helpers.ts:51-62,442` |

## MES: código sem banco (precisaria de tabela ou coluna)

| O código ou o contrato quer | O banco não tem | Selo |
|---|---|---|
| Documento de retirada (E6) | nenhuma tabela `documentos_retirada` | 🔴 |
| Feed de eventos para a Torre (`/fluxo/eventos`, `seq` global) | nenhuma tabela de evento | 🔴 |

Resolvidos desde 14/10 (só na `develop`): `GET /itens/custo` com `alterado_desde` (coluna `itens_pedido.custo_alterado_em`, 27/10); lote de fabricado aprovado (`OrigemLote.PRODUCAO`, `lotes.id_pedido_op`, `itens_parciais.id_lote_fabricado`, 28/10).

## av-hub: banco sem código

| Objeto | Situação | Selo | Evidência |
|---|---|---|---|
| `core_fluxo.evento` | tabela e imutabilidade prontas, **nenhum código a escreve** (a instrumentação do hub é a pergunta 3 do contrato 46); só é lida em `GET /fluxo/itens/:id` | 🔴 | dump `:15649`, comentário `:15690`; grep sem `INSERT` |
| `core_fluxo.item_estado_projetado` e `feed_cursor` | só o job escreve; o MES não publica o feed, então ficam vazias | 🔴 | [[AV-Hub-API]] |
| `itens_pedido_custo` e cursor | só o job escreve; o MES tem `/itens/custo` só na `develop` (27/10); enquanto a `main` do MES não o tiver, ficam vazias | 🟡 | idem |
| Schema `core_estoque` | criado, **sem nenhum objeto** | 🟡 | dump `:163` |
| `core.estoque_saldo` e `core.locais_estoque` | tabelas, model e rotas existem; o sync do Omie está desligado (`enabled: false`, `table: null`) | 🟡 | `omie-elt-pipeline/src/omie/resources/estoque.ts:16,32` |
| `omie_raw.*` (5 tabelas de staging: `notasFiscais`, `parceiros`, `pedidosVendas`, `produtos`, `vendedores`) | **obsoleto** (N14-27): `sql/002_staging_tables.sql` era opcional (só para `RAW_AUDIT_ENABLED=true`); a auditoria saiu do código no contrato 38 (`ARCHITECTURE.md:41`, `:256-257`); o README manda rodar só `001` e `003` (`README.md:66-67`); nada lê nem escreve. Resta o `DROP` das tabelas e do schema (Gustavo, BL-054) | 🟡 | grep `omie_raw` em `omie-elt-pipeline/src` sem ocorrência |
| `omie_ctl.run_log` | usado pela pipeline (`logRun`) | ✅ | `src/db/upsert.ts` |
| `historico.hst_*` | lidas pela API (escopo e planilha de faturamento); **a pipeline não as escreve** (carga congelada) | 🟡 | `escopoVendedor.js`, `vw_faturamento_planilha.model.js` |
| `core_vendas_faturamento.pedidos_compras_etapas` | de-para de etapa do Omie, lido pelo dashboard de OC; nenhum código escreve | 🟡 | `ordens_compra.dashboard.js:316` |
| `ordens_compra_referencia_mes` e a view `vw_ordens_compra_referencia_mes` | prontas e servidas por `GET /ordens-compra/referencia`; **o MES consome desde 15/10** (`develop`) | ✅ | [[Integracao-AvHub-MES]] INT-04 |
| `requisicoes_compra_eventos` para requisição do Compras | `fn_req_evento` ignora requisição sem `id_origem`: o marco nunca nasce. **Não é a lacuna:** o MES vê a requisição pela referência da requisição (API-009) e a OC pela referência da OC (N14-20); os dois leitores existem na `develop` do MES | ✅ | dump de 14/10 `:8580` |

## av-hub: código sem banco, ou banco antigo

| O código espera | O dump tem | Selo | Evidência |
|---|---|---|---|
| `fn_itens_pedido_custo_do_pedido` devolvendo `codigo_produto_omie` (migration **047b**) e tabela única por produto | dump de 14/10: versão 047 (coluna `item`). **Dump de 29/10: versão 047b** (`UNIQUE (codigo_empresa, numero_pedido, codigo_produto_omie)`) | ✅ resolvido | `itens_pedido_custo.route.js:98-103` x dump de 29/10 `:6290`, `:27722` |
| model `pessoa_vendedor` e rota `/pessoa_vendedor` | **sem tabela nem view** nos dois dumps (as funções `fn_detalhe_vendedor_*` já saíram do JOIN) | 🔴 | `schemas/core_vendas_faturamento/index.js`; `fn_detalhe_vendedor_vendas.route.js:67-70` |
| view `vw_requisicoes_compra_eventos` (035b) | ✅ existe; a rota ainda cai para a tabela sem `autor`/`comprador` se faltar | ✅ | `requisicoes_compra.route.js:382` |
| `fn_requisicao_mes_aplicar` (034) | ✅ existe | ✅ | dump de 14/10 `:8680` |
| objetos do contrato 46 (046) | ✅ existem (`core_fluxo.*`, funções da Torre); **a 046b** (zeros no mapa, concessão só ao Admin) não se prova por esqueleto | ❓ | `item_estado_projetado.route.js:16-30` |
| API-004/007 (`moeda`, `cotacao_*`, `valor_frete`, `valor_seguro` na referência) e api007b (fornecedor) | ✅ colunas na view (fornecedor no dump de 29/10) | ✅ | dump `vw_ordens_compra_referencia_mes` |
| API-009 (`requisicoes_compra_referencia_mes` e a view) | ✅ existem no dump de 29/10 | ✅ | `vw_requisicoes_compra_referencia_mes.route.js:59` |
| rotas `/comercial/*` (funções `core_comercial.fn_proposta_*`, `fn_cliente_omie_registrar`, `fn_parametros_custo_salvar`, `vw_propostas_lista`) | ✅ existem no dump de 29/10 | ✅ | `core_comercial/aggregates/*` |
| views `vw_ritmo_*_hora`, `vw_volume_pedidos_diario*` | não existem; **só aparecem em comentários** (as rotas foram reconstruídas) | ✅ sem problema | `ritmo_faturamento_hora.route.js:8` |
| `auth.rotas_telas` com `/fluxo/*`, `/itens_pedido_custo`, `/compras/requisicoes/eventos`, `/comercial/*` | tabela existe; linhas ❓ | ❓ | [[RBAC-e-Permissoes]] |

## Entre os sistemas (contrato x código)

| Contrato | Lado que expõe | Lado que consome | Selo |
|---|---|---|---|
| LOG-26 liberação | av-hub ✅ | MES ✅ | ✅ |
| LOG-34 requisição, ida | av-hub ✅ (`PUT`) | MES ✅ (fila) | ✅ |
| LOG-35 marcos, volta | av-hub ✅ (`/eventos`) | MES ✅ (todos os 14 marcos) | ✅ para requisição do MES |
| API-004/007 referência da OC | av-hub ✅ | MES ✅ (`develop`, desde 15/10) | ✅ |
| API-009 referência da requisição do Hub | av-hub ✅ | MES ✅ (`develop`, desde 23/10) | ✅ |
| API-005/006 status por item | MES ✅ (`/itens/status`) | av-hub ✅ (job) + HUB ✅ (card) | ✅ |
| API-008/LOG-47 custo por item | MES ✅ (`/itens/custo`, só `develop`, 27/10) | av-hub ✅ (job e rota) + HUB ✅ (tela, 15/10) | 🟡 falta a `develop` do MES chegar à produção |
| LOG-46 Torre | MES ❌ (`/fluxo/*`) | av-hub ✅ (job e rotas) + HUB ✅ (tela, 15/10) | 🔴 |
| API-003 requisições lidas do MES | MES ✅ | ninguém | 🟡 |

## Divergências de regra (documento x código)

| Documento | Código | Selo |
|---|---|---|
| 0b e decisão N14-21 (14/10): "OC acima de R$ 30 mil, o Gerente de Compras aprova; até R$ 30 mil, compradores livres; sem Diretoria" | igual: OC até o limite é **auto-aprovada** pelo banco; acima dele só a alçada `compras.pode_aprovar` decide (`ordens_compra.route.js:1230-1240`) | ✅ [[AV-Hub-API]] |
| 0b: "cotação PTAX por item" | a cotação é **da OC** (`ordens_compra.cotacao_moeda`, `cotacao_data`, `cotacao_origem`); o valor é por item | 🟡 |
| 0b: "despacho no Estoque, baixa na retirada" | baixa na Embalagem/Expedição (`consumirReservasDaParcial`) | 🔴 [[Modelo-Estoque-e-Custo-do-Lote]] |
| 0b: "Q8 sim → Estoque (E5)" | na fabricação, a inspeção de saída aprovada (`aprovar-saida`) leva o fabricado ao Estoque, que recebe e cria o lote `PRODUCAO` (`receber-fabricado`, LOG-53, `develop`) | ✅ |
| Registro de decisões: "nenhuma regra em ambiente para jobs novos" | Torre e custo cumprem; o job do status (005/006) e os cinco timers do MES ainda leem ambiente | 🟡 [[Bugs-Conhecidos]] |
| N16-116: "não existirá `core_comercial`; a proposta fica em `core_vendas_faturamento`" | o banco real (dump de 29/10) e as rotas `/comercial/*` (28 e 29/10) usam `core_comercial.propostas`, `propostas_itens` e `propostas_eventos` | 🔴 decisão x código ([[Banco-AvHub]]) |
