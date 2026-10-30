---
tags: [dados, banco, mes, postgres, prisma]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Robert
fontes: [Dump MES (Esqueleto).sql de 14/10/2026 15:00 (defasado: não há dump mais novo), api-pcp befd973 develop (prisma/models/*.prisma, 66 migrations até 20261028120100), v1 App-PCP-Modelo-Producao, MES-Arquitetura-Decisoes]
---

# Banco do MES

PostgreSQL do MES (`api-pcp`), schema único **`public`** (decisão #21; ver [[Schemas-Postgres]]), migrado pelo Prisma (`_prisma_migrations`). O dump de 14/10 é só esqueleto (nenhuma linha de dado) e traz **47 tabelas** (46 de negócio mais `_prisma_migrations`), **21 enums**, **94 chaves estrangeiras**, 75 índices (únicos incluídos), extensão `pgcrypto`, **nenhuma função, view ou trigger** ✅ `grep` no dump. **Não há dump do MES mais novo.** Os models Prisma da `develop` (29/10) têm **54 tabelas de negócio e 22 enums**: 8 tabelas e 1 enum novos, vindos de 11 migrations de 15 a 28/10 (abaixo) ✅ (`@@map` x `CREATE TABLE`; comparação em [[Diferencas-Codigo-x-Banco]]). Os números de linha `:NNNN` são do dump de 14/10. Essas migrations estão só na `develop` do `api-pcp`; a `main` parou em 08/10. Dono do dado: Robert. Selos: [[Regras-do-Vault]].

Convenções ✅: chave `uuid` (gerada pela aplicação, sem `DEFAULT` no banco); datas `timestamp(3)`; quantidades `numeric(14,4)` desde a migration `20261013120000_quantidade_decimal`; nome de coluna em `snake_case`; soft delete por `deleted_at` em cadastros. O MES não guarda cliente nem fornecedor em tabela própria: `pedidos.cliente` e `vendedor` são texto, `fornecedor` do lote é texto livre.

## Enums (dump de 14/10 `:128-432`, mais as mudanças das migrations até 28/10)

| Enum | Valores | Quem usa |
|---|---|---|
| `NaturezaMaterial` | `MATERIA_PRIMA`, `REVENDA` | `materiais.natureza` |
| `OrigemCusto` | `CARGA_INICIAL`, `OC`, `MANUAL` | `lote_custo.origem` (as três têm escritor desde 16/10 e 27/10 ✅) |
| `OrigemLote` | `RECEBIMENTO`, `CARGA_INICIAL`, `PRODUCAO` | `lotes.origem` (`PRODUCAO` = fabricado aprovado na inspeção de saída, LOG-53, migration `20261028120000`) |
| `OrigemRequisicao` | `MES`, `HUB` | `requisicoes_compra.origem` (migration `20261016120000`) |
| `Prioridade` | `BAIXA`, `NORMAL`, `ALTA`, `URGENTE` | `pedidos`, `divergencias` |
| `SistemaOrigem` | `OMIE`, `MANUAL` | `pedidos.sistema` |
| `StatusDivergencia` | `ABERTA`, `EM_ANALISE`, `RESOLVIDA`, `CANCELADA` | `divergencias` |
| `StatusEnvioAvhub` | `PENDENTE`, `ENVIADO`, `RECUSADO`, `FALHOU` | `integracao_avhub_envios` |
| `StatusItemParcial` | `RECEBIDO`, `EM_ANDAMENTO`, `EM_TRANSITO`, `PAUSADO`, `CONCLUIDO`, `RETRABALHO`, `CANCELADO`, `CRIADO`, `REPROVADO`, `FINALIZADO` (23/10: produção acabou, a peça espera no setor) | `itens_parciais.status` |
| `StatusPedido` | `AGUARDANDO`, `EM_PRODUCAO`, `ENTREGUE`, `BLOQUEADO` | `pedidos.status` (`BLOQUEADO` nunca atribuído) |
| `StatusQualidadeLote` | `PENDENTE`, `LIBERADO`, `REPROVADO`, `QUARENTENA` | `lotes.status_qualidade` |
| `StatusRecebimento` | `AGUARDANDO_RECONTAGEM`, `AGUARDANDO_DECISAO`, `CONCLUIDO`, `ACEITO`, `REABERTO` | `recebimentos.status` |
| `StatusRequisicaoCompra` | `ABERTA`, `EM_COMPRA`, `RECEBIDA_PARCIAL`, `RECEBIDA`, `CANCELADA` | `requisicoes_compra.status` |
| `StatusReserva` | `ATIVA`, `CONSUMIDA`, `LIBERADA` | `reservas_estoque.status` |
| `TipoAnexo` | `NOTA`, `CANHOTO`, `DESENHO`, `PEDIDO`, `ORDEM_PRODUCAO`, `COMPROVANTE_ENTREGA` | `pedido_anexos.tipo` |
| `TipoDivergencia` | `QUALIDADE`, `QUANTIDADE`, `PRAZO`, `DANO`, `DOCUMENTACAO`, `OUTRO` | `divergencias.tipo` |
| `TipoDivergenciaRecebimento` | `QUANTIDADE`, `DESCRICAO`, `PESO`, `AVARIA` | `recebimentos_divergencias.tipo` |
| `TipoEnvioAvhub` | `REQUISICAO_COMPRA` | `integracao_avhub_envios.tipo` |
| `TipoFabrica` | `FABRICACAO`, `REVENDA` | `fabricas.tipo` (UI "Destinos") |
| `TipoItemRequisicao` | `PRODUTO_FINAL`, `MATERIA_PRIMA` | `requisicoes_compra_itens.tipo` |
| `TipoMovimentoEstoque` | `ENTRADA`, `SAIDA`, `TRANSFERENCIA`, `AJUSTE` | `movimentos_estoque.tipo` |
| `TipoSetor` | `PRODUTIVO`, `ESTOQUE`, `COMPRAS`, `EXPEDICAO`, `REQUISICAO`, `LOGISTICA_ENTRADA`, `QUALIDADE` | `setores.tipo` |

Estados do pedido e da parcial: [[Estados-e-Status]].

## Tabelas por domínio

### Pedido e produção (P1, P2, F1, X1)

| Tabela (dump) | Papel | Colunas e regras que importam |
|---|---|---|
| `pedidos` (`:985`) | uma Destinação do Pedido (ordem de produção) | `pedido_venda` (15), `ordem_producao` (20, **único**), `id_fabrica` (FK `RESTRICT`), `prazo_entrega`, `status`, `prioridade`, `sistema`, `id_unidade` (uuid da filial como texto) e `nome_unidade`, **`acompanhamento_qualidade`** (boolean, vem da liberação), **`codigo_pedido_omie`**, **`importado_avhub_em`** (preenchido quando o `importado` foi confirmado); desde 22 e 28/10: `roteiro_liberado_em`, `roteiro_liberado_por_id`, `op_emitida_em`, `op_emitida_por_id`, `op_impressoes` (a OP é emitida na criação) |
| `itens_pedido` (`:740`) | item do pedido | `id_omie`, `codigo`, `descricao`, `quantidade`, `quantidade_pendente`, `quantidade_concluida`, `unidade`, `inativo`, `custo_alterado_em` (27/10, cursor do `GET /itens/custo`); **único `(id_pedido, codigo)`**; `id_item_pai` (auto-FK) |
| `itens_parciais` (`:705`) | **a parcial**: a quantidade de um item que está num setor | `quantidade`, `id_setor_atual` (RESTRICT), `id_setor_origem`, `status`, `id_parcial_origem` (split), `id_devolvido_de`, `retrabalho`, `atendido_pelo_estoque`, **`id_lote_compra`** (FK `lotes`, ligada pelo Recebimento), `fabricado_aprovado_em` e **`id_lote_fabricado`** (28/10: lote `PRODUCAO` em que o fabricado entrou), `nomes_pallets[]`, `pesos_pallets[]`, `unidades_pallets[]`, máquina e operador |
| `historico_itens_parciais` (`:612`) | trilha de cada mudança | `status_anterior`, `status_novo`, setores origem e destino, usuário, máquina, operador, `observacao` |
| `roteiros` (`:1329`) | etapas do pedido (setores em ordem) | único `(id_pedido, ordem)` |
| `roteiros_item` (`:1344`) | etapas por item | único `(id_item_pedido, ordem)` |
| `setores` (`:1376`) | setor/etapa | `codigo` único, `tipo` (`TipoSetor`), `exige_maquina_operador`, `ativo` |
| `fabricas`, `fabrica_setores` (`:577`, `:563`) | destino FABRICACAO ou REVENDA e seus setores | `codigo` único |
| `maquinas`, `operadores` (`:844`, `:918`) | apoio de produção | `maquinas.id_setor` (RESTRICT) |
| `fila_setor_ordem` e `setores.ordem_fila_so_pcp` (26/10) | ordem manual da fila de um setor produtivo; a coluna trava a ordem só para o PCP (`programar-fila`) | `id_setor` (CASCADE) |
| `entregas` (`:544`) | saída ao cliente | `id_item_pedido` (CASCADE), `quantidade`, `numero_nf`, `delivered_by_id` |
| `pedido_embalagens`, `pedido_embalagem_pallets` (`:969`, `:952`) | embalagem e paletização | paletes: `identificacao`, `peso`, `unidades` |
| `pedido_anexos`, `item_parcial_anexos`, `item_parcial_observacoes` | anexos (`TipoAnexo`) e observações | |
| `divergencias` (`:518`) | divergência de produção | `tipo`, `status`, `id_setor_responsavel` |
| `pedidos_excluidos` (`:1018`) | foto do pedido excluído | `motivo_exclusao`, `itens_snapshot` (jsonb) |

### Estoque (E1 a E6) — ver [[Modelo-Estoque-e-Custo-do-Lote]]

| Tabela (dump) | Papel | Colunas e regras |
|---|---|---|
| `depositos` (`:499`) | depósito físico | `codigo` único, **`codigo_empresa`** (uuid da filial), `nome_unidade` |
| `localizacoes_estoque` (`:768`) | localização dentro do depósito | único `(id_deposito, codigo)` |
| `materiais` (`:863`) | snapshot do produto do av-hub | único **`(codigo_empresa, codigo_produto_omie)`**; `codigo_produto` (legível, ex. `015VRDP060`), `id_produto_avhub`, `natureza`, `categoria`, `unidade`, `ncm`, `familia`, `peso_teorico_unitario`, **`tolerancia_peso`** (padrão 0,05), `estoque_minimo`, `estoque_maximo`, `ponto_de_pedido` |
| `lotes` (`:813`) | **lote**: unidade de rastreio | `codigo` único (`LT-AAAAMMDD-NNNN`), `id_material` (RESTRICT), `origem`, `status_qualidade`, `quantidade`, `id_lote_pai` (cisão), `id_requisicao_item` (compra), **`id_pedido_op`** (28/10: OP do lote `PRODUCAO`; único por OP e material), `numero_nf`, `fornecedor` (texto), `laudo_url`, `quarentena_desde`, reprovação (`motivo_reprovacao`, `evidencia_url`, `reprovado_*`), liberação (`liberado_*`) |
| **`lote_custo`** (`:786`) | custo do lote, 1 para 1 | `id_lote` (PK e FK `CASCADE`), `origem`, **`custo_liquido_unitario`** `numeric(15,6)`, `valor_unitario`, `moeda` (padrão `BRL`), `cotacao`, `desconto_pct`, `icms_recuperar_unit`, `ipi_unit`, `st_unit`, `frete_unit`, `id_item_oc`, **`cotacao_a_conferir`**, `atualizado_por_id` |
| `lote_custo_historico` (27/10) | histórico do custo de antes e o motivo, a cada `PUT /estoque/lotes/:id/custo` | `id_lote` (CASCADE), `usuario_id` |
| `consumos_materia_prima` (19/10) | matéria-prima baixada ao atender pelo estoque uma parcial de fabricação (estornável ao devolver); `movimentos_estoque.id_consumo_mp` | `id_lote`, `id_item_parcial` |
| `entradas_uso_interno` (16/10) | item de OC de uso interno: conferido contra a NF e entregue a quem pediu, sem lote nem saldo (custo vai para despesa) | `id_recebimento_item`, `id_oc_item`, `id_material` |
| `saldos_estoque` (`:1359`) | saldo por lote e localização | único `(id_lote, id_localizacao)`; `quantidade` |
| `movimentos_estoque` (`:894`) | razão do estoque (só inserção) | `tipo`, `quantidade`, `motivo`, origem e destino (localização e depósito), `id_reserva`, `usuario_id`, `autorizado_por_id`, `ocorrido_em`; desde 27/10 `custo_unitario` (snapshot do custo na saída) |
| `reservas_estoque` (`:1284`) | reserva de lote para uma parcial | `quantidade`, `quantidade_consumida`, `status`, snapshot (`pedido_venda`, `ordem_producao`, `item_codigo`, `item_descricao`), `liberada_by_id`, `motivo_liberacao` |
| `rncs` (`:1310`) | não conformidade de lote | `quantidade_reprovada`, `evidencia_url`, **`nota_devolucao_pendente`** (padrão `true`) |
| `fornecedores` (`:595`) | projeção de `core.parceiros` | único `(codigo_empresa, codigo_parceiro_omie)`; **sem escritor nem leitor no código** 🟡 |

### Circuito de compra (P3, C5, R0 a R6, Q1 a Q4)

| Tabela (dump) | Papel | Colunas e regras |
|---|---|---|
| `requisicoes_compra` (`:1188`) | cabeçalho da requisição do PCP | `codigo` único (`RC-AAAAMMDD-NNNN` por `prefixoDoDia`, `compras.service.ts:651`), `id_item_parcial`, `id_item_pedido`, `id_pedido`, `status`, `prazo_necessidade`; cancelamento (`motivo_cancelamento`, `cancelada_em`, `cancelada_por` = `mes` ou `compras`); **Origem e agrupador** (16 e 21/10): `origem` (`MES` ou `HUB`), `codigo_agrupador` (requisição de uma OP inteira); **Compras · CCP** (14/10): `liberada_recebimento_em`, `liberada_recebimento_por_id`, `motivo_liberacao`, `nf_chegada`, `chave_nf_chegada` (44), `chegada_em`; legado `pedido_compra`, `fornecedor`, `previsao_entrega`, `comprado_em` |
| `requisicoes_compra_itens` (`:1253`) | **material** da requisição (1 item = 1 `id_origem` no av-hub) | `id_material`, `tipo`, `quantidade`, `quantidade_recebida`; av-hub: `avhub_id_requisicao`, `avhub_numero`, `avhub_status`, `avhub_sincronizado_em`, `avhub_enfileirado_em`; situação do material: **`etapa_compra`** (`AGUARDANDO_COMPRADOR`, `EM_COTACAO`, `EM_APROVACAO`, `COM_FORNECEDOR`, `EM_TRANSITO`, `CANCELADA`), `numero_oc`, `numero_pedido_omie`, `previsao_chegada`, `oc_aprovada_em`, `despachada_em`, `nf_fornecedor`, `transportadora`, `ocorrencia_aberta` |
| `requisicoes_compra_eventos_avhub` (`:1225`) | marcos lidos do av-hub (idempotência por `id`) | `id_origem`, `id_requisicao_avhub`, `tipo`, `registrado_em` (texto com microssegundos), `status_requisicao`, `id_ordem_compra`, `numero_pedido_oc`, `numero_pedido_omie`, `situacao_oc`, `dados` (jsonb), `processado_em`, `acao` |
| `integracao_avhub_envios` (`:650`) | fila de saída (LOG-34) | `tipo`, `id_origem`, `corpo` (jsonb), `status`, `tentativas`, `proxima_tentativa_em`, `http_status`, `resultado`, `ultimo_erro`, `concluido_em` |
| `integracao_avhub_cursores` (`:635`) | cursor do polling | `chave` (`requisicoes-eventos`), `alterado_desde` (texto), `apos_id` |
| `recebimentos_nf` (16/10) | NF recebida na doca, com `codigo` único; `recebimentos.id_recebimento_nf` e `id_ordem_compra` (recebimento por OC, sem requisição) | `recebimentos_nf_codigo_key` |
| `recebimentos` (`:1116`) | conferência da doca | `codigo` único (`RB-AAAAMMDD-NNNN`), `id_requisicao`, `id_item_parcial`, `status`, `numero_nf`, `chave_acesso_nf` (44), `fornecedor`, `conferido_*`, `recontado_*`, `decidido_*`, `motivo_decisao` |
| `recebimentos_itens` (`:1164`) | linha conferida | `quantidade_pendente`, `quantidade_nf`, `quantidade_contada`, `quantidade_recontada`, `peso_teorico`, `peso_real`, `peso_recontado`, `tolerancia_peso`, `id_localizacao` (sem FK), **`id_lote`** (sem FK) |
| `recebimentos_divergencias` (`:1145`) | divergência da conferência | `tipo`, `etapa` (15), `evidencia_url` |

✅ **Projeção da OC e da requisição do Hub no MES** (desde 15/10 e 16/10; N14-20): `oc_referencia` e `oc_referencia_itens` guardam a referência da OC lida do av-hub (`GET /ordens-compra/referencia`: OC por pedido, quantidade, `destino`, `finalidade`, valor, moeda, cotação e, desde 27/10, `codigo_fornecedor`, `nome_fornecedor`, `cnpj_fornecedor`); `requisicoes_hub_referencia` guarda a referência da requisição do Compras (API-009). `requisicoes_compra_itens.id_oc_item` liga a requisição ao item da OC. A tabela do saldo futuro do Estoque (BL-049, BL-050) sai dessa projeção; o que falta é o Estoque usá-la ❓.

### Acesso e auditoria

`usuarios` (`:1415`, `username` e `email` únicos, `senha` bcrypt, `anonymized_at` para LGPD), `perfis`, `telas`, `permissoes`, `usuarios_perfis`, `perfil_setores`, `perfil_depositos`, `auditoria_login`, `auditoria_acesso` ✅ [[RBAC-e-Permissoes]].

## Relações que sustentam o fluxo (FK)

- `pedidos` → `fabricas` (RESTRICT); `itens_pedido` → `pedidos` (CASCADE); `itens_parciais` → `itens_pedido` (CASCADE) e → `setores` (RESTRICT); `roteiros`/`roteiros_item` → `pedidos`/`itens_pedido` (CASCADE), → `setores` (RESTRICT).
- `requisicoes_compra` → `itens_parciais` e `itens_pedido` (CASCADE); `requisicoes_compra_itens` → `requisicoes_compra` (CASCADE) e `materiais` (RESTRICT); `recebimentos` → `requisicoes_compra` e `itens_parciais` (CASCADE); `recebimentos_itens` → `recebimentos` e `requisicoes_compra_itens` (CASCADE).
- `lotes` → `materiais` (RESTRICT), `lotes` (pai, SET NULL), `requisicoes_compra_itens` (SET NULL), `pedidos` (`id_pedido_op`); `lote_custo` e `lote_custo_historico` → `lotes` (CASCADE); `saldos_estoque`, `reservas_estoque`, `movimentos_estoque`, `rncs` → `lotes` (RESTRICT); `itens_parciais.id_lote_compra` → `lotes` (SET NULL).
- Sem FK de propósito: `requisicoes_compra_eventos_avhub` (guarda o que o av-hub mandou), `recebimentos_itens.id_lote` e `.id_localizacao`, `pedidos.id_unidade` (texto), `materiais.id_produto_avhub`, `depositos.codigo_empresa` (os dois últimos apontam para o **outro** banco).

Os 94 FKs estão em `grep "FOREIGN KEY"` do dump de 14/10 ✅ (as tabelas novas trazem as suas nas migrations). Índices únicos que o código assume: `pedidos.ordem_producao`, `itens_pedido(id_pedido, codigo)`, `lotes.codigo`, `requisicoes_compra.codigo`, `recebimentos.codigo`, `materiais(codigo_empresa, codigo_produto_omie)`, `saldos_estoque(id_lote, id_localizacao)` ✅ dump `CREATE UNIQUE INDEX`.

## O que o banco não tem (e o fluxo pede)

| Falta | Nó | Selo |
|---|---|---|
| Tabela de **documento de retirada** do Estoque (`documentos_retirada` + itens, com `id_reserva`, destino Expedição ou Produção) | E6 | 🔴 |
| Tabela de feed de eventos (`fluxo.evento`, `seq` bigserial) para a Torre | LOG-46 | 🔴 |
| Custo do **fabricado** (hoje o lote `PRODUCAO` nasce sem custo e o `GET /itens/custo` deixa o item fabricado de fora) | Q8 → E5, LOG-47 | ❓ regra do custo |
| Registro de P6 (Novo norte) | P6 | 🔴 |

Já resolvido desde 14/10 (só na `develop`): `OrigemLote.PRODUCAO` e vínculo `lotes` ↔ parcial (28/10); escritor de `lote_custo` com `origem = OC` e `MANUAL` (16/10 e 27/10); `custo_alterado_em` e `GET /itens/custo` (27/10).

Mapa conceitual e diagrama de classes: [[Modelo-de-Dados]].
