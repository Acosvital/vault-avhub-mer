---
tags: [fluxo, estados, status, enums, referencia]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [api-pcp 579a625 prisma/models/*.prisma, integracao-avhub.service.ts, requisicao-avhub.eventos.ts, Dump MES 14/10 (CREATE TYPE, linhas 128-424), Dump Avhub 14/10 (CHECK constraints), app-pcp 1fca8d3 movimentacoes/labels.ts e acoes.ts, HUB b55ac55 lib/domain/etapas-item.ts, 00-Fluxo-Mestre-0b]
---

# Estados e status do fluxo

Referência única dos valores exatos (enums, `CHECK`, vocabulários) usados pelo fluxo de Atividades ([[00-Fluxo-Mestre-0b]]). Valores em `código` são literais do banco ou do código. Selos em [[Regras-do-Vault]]. Todo valor foi conferido no `schema.prisma` (modelos em `api-pcp/prisma/models/`), nos dumps de 14/10 ou nos arquivos citados. Na tela, rótulos podem diferir.

## 1. MES (`public`, banco Postgres do MES)

Linhas do dump entre parênteses: `Dump MES (Esqueleto).sql`.

### Pedido

| Enum | Valores | Fonte |
|---|---|---|
| `StatusPedido` | `AGUARDANDO`, `EM_PRODUCAO`, `BLOQUEADO`, `ENTREGUE` | `producao.prisma:11-16` (dump 246) ✅ |
| `Prioridade` | `BAIXA`, `NORMAL`, `ALTA`, `URGENTE` | `producao.prisma:3-8` (168) ✅ |
| `SistemaOrigem` | `OMIE`, `MANUAL` | `producao.prisma:23-26` (183) ✅ |

Uso: `ENTREGUE` é gravado por `EntregasService.create` quando zera o pendente e não resta parcial ativa (`entregas.service.ts:104-130`). `BLOQUEADO` e `EM_PRODUCAO` nunca são gravados por código: todo pedido nasce `AGUARDANDO` e a única transição automática é para `ENTREGUE` (`item-parcial-status.constants.ts:44-50`) ✅. O dashboard conta produção pela atividade das parciais, não por este campo.

### Parcial do item (`ItemParcial.status`)

`StatusItemParcial` (`producao.prisma:29-54`, dump 226; a ordem do dump difere):

| Valor | Rótulo na tela | Significado |
|---|---|---|
| `CRIADO` | Aguardando recebimento | Nasce no primeiro setor; não gera linha de histórico |
| `RECEBIDO` | Recebido | Operador confirmou o recebimento (`receivedBy`) |
| `EM_ANDAMENTO` | Em produção | Trabalho iniciado, `startedAt` preenchido |
| `EM_TRANSITO` | Em trânsito | Movida para outro setor, aguardando recebimento |
| `PAUSADO` | Pausado | Pausa com motivo; sai só por `retomar` |
| `REPROVADO` | Reprovado | Reprovada na Qualidade (setor tipo `QUALIDADE`); abre `Divergencia` |
| `CONCLUIDO` | Concluído | Último setor do roteiro, pronta para entrega |
| `RETRABALHO` | Retrabalho | **Legado**: nenhuma ação chega aqui; só `retomar` aceita como origem |
| `CANCELADO` | Cancelado | Terminal; origem de `devolver`, `retrabalho` e `cancelar` |

Rótulos: `movimentacoes/labels.ts:7-17`. Ações por status: `movimentacoes/acoes.ts:61-71` (tabela em [[07-Producao-e-Roteiro]]). Estados fora da fila (`STATUS_FILA_MOVIMENTACOES`): `api-pcp/src/common/constants/item-parcial-status.constants.ts:30` ✅.

Flags relacionadas: `atendidoPeloEstoque` (parcial atendida pelo saldo), `retrabalho` (linha de retorno de retrabalho), `idLoteCompra` (lote que espera a Qualidade), `idParcialOrigem` (split), `idDevolvidoDe` (devolução e retrabalho).

### Divergência de produção

| Enum | Valores | Fonte |
|---|---|---|
| `StatusDivergencia` | `ABERTA`, `EM_ANALISE`, `RESOLVIDA`, `CANCELADA` | `producao.prisma:77-82` (dump 196) ✅ |
| `TipoDivergencia` | `QUALIDADE`, `QUANTIDADE`, `PRAZO`, `DANO`, `DOCUMENTACAO`, `OUTRO` | `producao.prisma:67-74` (339) ✅ |

`resolvido` e `cancelada` são terminais, sem reabertura 🔴 (`divergencias.service.ts`, método `resolver`). `reprovar` cria `QUALIDADE`/`ABERTA` (`itens-parciais.service.ts:1048-1058`).

### Setor e fábrica

| Enum | Valores | Fonte |
|---|---|---|
| `TipoSetor` | `PRODUTIVO`, `ESTOQUE`, `COMPRAS`, `EXPEDICAO`, `REQUISICAO`, `LOGISTICA_ENTRADA`, `QUALIDADE` | `fabricas.prisma:17-32` (424) ✅ |
| `TipoFabrica` | `FABRICACAO`, `REVENDA` | `fabricas.prisma:5-8` (383) ✅ |

Códigos fixos do circuito de compra (`circuito-compra.ts:19-25`): `requisicoes-compra` (`REQUISICAO`), `compras` (`COMPRAS`), `logistica-entrada` (`LOGISTICA_ENTRADA`), `qualidade-entrada` (`QUALIDADE`), `estoque` (`ESTOQUE`, etapa 1 de todo roteiro, `SETOR_ESTOQUE_FIXO_CODIGO`) ✅. Rótulos das telas: Requisições de compras, Compras · CCP, Recebimento, Qualidade · Entrada, Estoque.

### Requisição de compra (MES)

| Enum | Valores | Fonte |
|---|---|---|
| `StatusRequisicaoCompra` | `ABERTA`, `EM_COMPRA`, `RECEBIDA_PARCIAL`, `RECEBIDA`, `CANCELADA` | `compras.prisma:9-15` (292) ✅ |
| `TipoItemRequisicao` | `PRODUTO_FINAL`, `MATERIA_PRIMA` | `compras.prisma:19-22` (396) ✅ |

Resumo: `ABERTA` e `EM_COMPRA` alternam pelos marcos do av-hub; `RECEBIDA_PARCIAL` e `RECEBIDA` vêm da conferência; `CANCELADA` pelo PCP ou pelo Compras (`canceladaPor`: `mes` ou `compras`) ✅ (`compras.prisma:73-82`).

### `etapaCompra` (por material da requisição)

`RequisicaoCompraItem.etapaCompra`, texto de até 25 caracteres (`compras.prisma:145-157`). Valores: `AGUARDANDO_COMPRADOR`, `EM_COTACAO`, `EM_APROVACAO`, `COM_FORNECEDOR`, `EM_TRANSITO`, `CANCELADA`. Derivados do marco do av-hub (`requisicao-avhub.eventos.ts:234-245`) ✅:

| Marco (`tipo` do evento) | `etapaCompra` |
|---|---|
| `requisicao_recebida`, `requisicao_reaberta`, `oc_cancelada` | `AGUARDANDO_COMPRADOR` |
| `em_cotacao`, `oc_removida` | `EM_COTACAO` |
| `oc_criada`, `oc_enviada_aprovacao` | `EM_APROVACAO` |
| `oc_aprovada` | `COM_FORNECEDOR` (preenche `ocAprovadaEm`: entra nos esperados do Recebimento) |
| `despachada` | `EM_TRANSITO` |
| `requisicao_cancelada` | `CANCELADA` |
| `oc_no_omie`, `fornecedor_confirmou`, `previsao_alterada`, `ocorrencia` | não mudam a etapa; atualizam previsão, ocorrência ou histórico |

### Envio ao av-hub (fila do contrato 34)

| Enum | Valores | Fonte |
|---|---|---|
| `TipoEnvioAvhub` | `REQUISICAO_COMPRA` | `integracao.prisma:13-15` (371) ✅ |
| `StatusEnvioAvhub` | `PENDENTE`, `ENVIADO`, `RECUSADO` (409 `REQUISICAO_COM_OC`), `FALHOU` (400) | `integracao.prisma:24-29` (211) ✅ |

### Recebimento

| Enum | Valores | Fonte |
|---|---|---|
| `StatusRecebimento` | `AGUARDANDO_RECONTAGEM`, `AGUARDANDO_DECISAO`, `CONCLUIDO`, `ACEITO`, `REABERTO` | `compras.prisma:31-37` (276) ✅ |
| `TipoDivergenciaRecebimento` | `QUANTIDADE`, `DESCRICAO`, `PESO`, `AVARIA` | `compras.prisma:42-47` (356) ✅ |

Regras: bateu vai a `CONCLUIDO`; divergiu vai a `AGUARDANDO_RECONTAGEM`; continuou divergindo vai a `AGUARDANDO_DECISAO` (PCP); decisão `ACEITO` ou `REABERTO`. `QUANTIDADE` e `PESO` são calculados; `DESCRICAO` e `AVARIA` são informados (`AVARIA` exige foto). Etapa da divergência: `conferencia` ou `recontagem` (texto, `compras.prisma:252`). Detalhes em [[05-Recebimento]].

### Lote, estoque e reserva

| Enum | Valores | Fonte |
|---|---|---|
| `StatusQualidadeLote` | `PENDENTE`, `LIBERADO`, `REPROVADO`, `QUARENTENA` | `estoque.prisma:25-32` (261) ✅ |
| `OrigemLote` | `RECEBIMENTO`, `CARGA_INICIAL` (sem origem de produção 🔴) | `estoque.prisma:17-20` (155) ✅ |
| `NaturezaMaterial` | `MATERIA_PRIMA`, `REVENDA` | `estoque.prisma:12-15` (128) ✅ |
| `TipoMovimentoEstoque` | `ENTRADA`, `SAIDA`, `TRANSFERENCIA`, `AJUSTE` | `estoque.prisma:38-43` (409) ✅ |
| `StatusReserva` | `ATIVA`, `CONSUMIDA`, `LIBERADA` | `estoque.prisma:48-52` (308) ✅ |
| `OrigemCusto` | `CARGA_INICIAL`, `OC`, `MANUAL` | `estoque.prisma:378-382` (141) ✅ |

Saldo disponível conta só lote `LIBERADO` menos reservas `ATIVA` (`estoque-operacao.helpers.ts:165`). `QUARENTENA` é a parte aprovada de uma reprovação parcial até a substituição (EC-07). Reserva sem expiração: nasce `ATIVA`, vira `CONSUMIDA` na saída física e `LIBERADA` ao cancelar ([[06-Qualidade-Entrada]], [[03-Estoque-Atendimento-e-Despacho]]).

### Anexos

`TipoAnexo`: `NOTA`, `CANHOTO`, `DESENHO`, `PEDIDO`, `ORDEM_PRODUCAO`, `COMPROVANTE_ENTREGA` (`producao.prisma:57-64`, dump 322) ✅.

## 2. Status por item: as 11 etapas (contrato 005)

Emitidas por `GET /itens/status` do MES (`etapaDoItem`, `integracao-avhub.service.ts:167-192`) ✅ e gravadas em `core_vendas_faturamento.itens_pedido_status.etapa` (`varchar(60)`, Dump Avhub linha 16990). A etapa deriva do **tipo do setor atual** mais o status; o vocabulário é provisório ([[API-005-Status-Item-Integracao-MES]], [[API-006-Status-por-Item-Leitura-no-Hub]]).

| # | `etapa` | Regra (código) | Rótulo no HUB (`lib/domain/etapas-item.ts:34-46`) |
|---|---|---|---|
| 1 | `compras.requisicao` | setor `REQUISICAO` | Requisição de compra |
| 2 | `compras.fechamento` | setor `COMPRAS` (Compras · CCP) | Em compra |
| 3 | `recebimento.conferencia` | setor `LOGISTICA_ENTRADA` | Recebimento |
| 4 | `qualidade.quarentena` | setor `qualidade-entrada` com lote em `QUARENTENA` | Quarentena |
| 5 | `qualidade.inspecao` | setor `QUALIDADE` (entrada ou saída) fora das regras acima | Inspeção de qualidade |
| 6 | `qualidade.reprovado` | **qualquer** setor com status `REPROVADO` (primeiro teste) | Reprovado na qualidade |
| 7 | `estoque.atendimento` | setor `ESTOQUE` | Atendimento do estoque |
| 8 | `fabrica.espera` | setor `PRODUTIVO`, status fora de `EM_ANDAMENTO`, `PAUSADO`, `RETRABALHO` | Aguardando produção |
| 9 | `fabrica.execucao` | setor `PRODUTIVO`, status `EM_ANDAMENTO`, `PAUSADO` ou `RETRABALHO` | Em produção |
| 10 | `expedicao.embalagem` | setor `EXPEDICAO`, status diferente de `CONCLUIDO` | Embalagem |
| 11 | `expedicao.concluido` | setor `EXPEDICAO`, status `CONCLUIDO` | Pronto para expedição |

Etapa desconhecida: a tela mostra o texto cru em tom neutro (`etapas-item.ts:49-51`). Aviso de dado velho após 10 minutos (`ETAPA_ATRASO_MINUTOS`, `:54`). Não há etapa "entregue" nem "faturado" 🔴.

## 3. av-hub (`core_*`, Postgres do av-hub)

### Pedido de venda e liberação

| Campo | Valores | Fonte |
|---|---|---|
| `pedidos_vendas.situacao` (calculado por trigger) | `Cancelado`, `Denegado`, `Devolvido`, `Dev. Parcial`, `Encerrado`, `Faturado`, `Autorizado`, `Pendente` (ordem de precedência) | `fn_sync_situacao_pv`, Dump Avhub 9804 ✅ |
| `vw_pedidos_liberacao.status_liberacao` | `pendente`, `liberado`, `importado` | Dump Avhub 20870; [[01-Vendas-Liberacao]] ✅ |
| `acompanhamento_qualidade` | `true`, `false`, `null` | idem |
| `pedidos_vendas_liberacao_historico.acao` | `liberado`, `alterado`, `importado_mes` | idem |
| Erros da liberação | 404 `PEDIDO_FORA_DA_LIBERACAO`, 409 `PEDIDO_IMPORTADO_MES`, 409 `PEDIDO_NAO_LIBERADO`, 403 `PEDIDO_FORA_DO_ESCOPO`, 403 `SEM_VENDEDOR_VINCULADO` | `pedidos_liberacao.route.js:187-222`, `pedidos_liberados.route.js:50` ✅ |

### Requisição de compra do av-hub (`requisicoes_compra`)

`status` (`ck_requisicoes_compra_status`, Dump Avhub 18569): `aberta`, `em_cotacao`, `atendida`, `cancelada`. `atendida` é marcada pela trigger da OC e exige `id_ordem_compra` (`ck_requisicoes_compra_atendida`, 18567); nunca pelo PATCH ✅. `avhubStatus` no MES guarda esse valor (`varchar(20)`).

### Marcos da requisição (`requisicoes_compra_eventos.tipo`, contrato 35)

`requisicao_recebida`, `em_cotacao`, `oc_criada`, `oc_removida`, `oc_enviada_aprovacao`, `oc_aprovada`, `oc_no_omie`, `fornecedor_confirmou`, `previsao_alterada`, `despachada`, `ocorrencia`, `oc_cancelada`, `requisicao_cancelada`, `requisicao_reaberta` (14 valores, `requisicoes_compra_eventos_tipo_check`, Dump Avhub 18692) ✅. O MES aplica todos ([[Integracao-AvHub-MES]]).

### Ordem de compra

| Campo | Valores | Fonte (Dump Avhub) |
|---|---|---|
| `ordens_compra.status` | `rascunho`, `aguardando_aprovacao`, `aprovado`, `cancelado` | `ck_ordens_compra_status`, 17321 ✅ |
| `ordens_compra.tipo_frete` | `CIF`, `FOB` (ou nulo) | 17317 ✅ |
| `status_sincronizacao_omie` | `pendente`, `sincronizado`, `erro` (erro exige `erro_sincronizacao_omie`) | 17315-17320 ✅ |
| `ordens_compra_itens.tipo_material` | `acabado`, `nao_acabado` | 17761 ✅ |
| `oc_acompanhamento.confirmacao_status` | `pendente`, `confirmada`, `contraproposta` | 17532 ✅ |
| `oc_ocorrencias.status` | `aberta`, `aprovada`, `recusada`, `resolvida` | 17900 ✅ |
| `oc_ocorrencias.tipo` | `atraso`, `entrega_parcial`, `mudanca_preco`, `mudanca_quantidade`, `mudanca_prazo`, `sem_confirmacao`, `nao_entrega` | 17901 ✅ |
| `oc_contatos.tipo` | `confirmacao`, `cobranca_prazo`, `despacho`, `renegociacao`, `outro` | 17679 ✅ |
| `pedidos_compras_etapas.status_equivalente` | `aprovado`, `cancelado` | 18148 ✅ |
| `contadores_documento.tipo` | `ordem_compra`, `requisicao_compra` | 16560 ✅ |

Aprovação: Gerente de Compras sempre; acima de R$ 30 mil, Diretoria também (decisão de 14/10, `C3`). A regra da Diretoria ❓ conferir em `parametros_compras`. Detalhes em [[04-Circuito-de-Compra]].

### Torre de Fluxo (`core_fluxo`)

| Campo | Valores | Fonte |
|---|---|---|
| `evento.origem` | `av-hub` (único permitido) | `ck_evento_origem`, Dump Avhub 15649 ✅ |
| `item_estado_projetado.encerramento` | `cancelado`, `concluido` (preenchido junto com `encerrado_em`) | linha 2169 ✅ |
| `item_estado_projetado.estado_macro` | `varchar(40)`, vocabulário não definido 🔴 | linha 2176 |

Os 8 estados macro do desenho do vendedor (`AGUARDANDO_LIBERACAO`, `PENDENTE_PCP`, `EM_ESTOQUE`, `EM_COMPRA`, `EM_PRODUCAO`, `EM_RECEBIMENTO`, `EM_INSPECAO`, `PRONTO_EXPEDICAO`, `FATURADO`) não existem no código 🟡 ([[01-Vendas-Liberacao]]). O MES ainda não publica `/fluxo/eventos` 🔴 ([[Rastreabilidade-e-Torre-de-Fluxo]]).

## 4. Pontes entre os dois lados

| MES | av-hub | Observação |
|---|---|---|
| `StatusRequisicaoCompra` `ABERTA`/`EM_COMPRA` | `aberta`, `em_cotacao`, `atendida` | O MES recalcula o resumo pelos marcos, não copia o status |
| `ItemParcial` + setor | `etapa` (11 valores) | job de 90 s no av-hub |
| `etapaCompra` | marco do evento | tabela da seção 1 |
| `StatusItemParcial.CANCELADO` | `mes_deleted_at` em `itens_pedido_status` | `deleted_at` no feed |
| `Pedidos.importadoAvhubEm` | `status_liberacao = importado` | `POST /pedidos_liberados/:numero/importado` |

## Conflitos de vocabulário a lembrar

- `ENTREGUE` (pedido, MES) não é `Faturado` (pedido, Omie): são eixos diferentes ([[10-Fiscal-Omie]]).
- `RECEBIDO` (parcial) não é `RECEBIDA` (requisição) nem recebimento `CONCLUIDO`.
- `REPROVADO` aparece em três lugares: parcial (produção), lote (qualidade de entrada) e a etapa `qualidade.reprovado`.
- `CONCLUIDO` aparece na parcial (`StatusItemParcial`), no recebimento (`StatusRecebimento`) e no feed do av-hub (`encerramento`).
