---
tags: [fluxo, estados, status, enums, referencia]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [api-pcp 579a625 prisma/models/*.prisma, integracao-avhub.service.ts, requisicao-avhub.eventos.ts, Dump MES 14/10 (CREATE TYPE, linhas 128-424), Dump Avhub 14/10 (CHECK constraints), app-pcp 1fca8d3 movimentacoes/labels.ts e acoes.ts, HUB b55ac55 lib/domain/etapas-item.ts, 00-Fluxo-Mestre-0b]
---

# Estados e status do fluxo

## Em uma frase

Esta nota é o dicionário dos estados que um pedido, uma requisição, uma compra ou um lote pode ter no fluxo de Atividades ([[00-Fluxo-Mestre-0b]]), com o significado de cada um.

## Como usar esta nota

- Viu um estado numa tela ou num relatório e não sabe o que significa? Procure na seção "Os estados mais usados".
- Estados com nome parecido em sistemas diferentes? Veja "Nomes que enganam".
- Precisa do valor exato gravado no banco, do arquivo ou da linha do código? Vá ao "Detalhe técnico", no fim.

Na tela, o rótulo pode ser diferente do valor gravado. Os selos estão em [[Regras-do-Vault]]. Todo valor foi conferido no `schema.prisma` (modelos em `api-pcp/prisma/models/`), nos dumps de 14/10 ou nos arquivos citados.

## Exemplo: como um pedido muda de estado

Um pedido de venda caminha por estados em dois lados, o av-hub e o MES. Este é um caminho possível:

1. O pedido chega do Omie e fica **pendente** de liberação no av-hub.
2. O vendedor libera o pedido. O estado vira **liberado**.
3. O MES importa o pedido. No av-hub ele passa a **importado**. No MES, nasce como **AGUARDANDO**.
4. Cada item (parcial) nasce **CRIADO** (na tela, "Aguardando recebimento"). Depois vai a **RECEBIDO**, **EM_ANDAMENTO** (em produção) e **CONCLUIDO**.
5. Quando as entregas zeram o pendente e não resta parcial ativa, o pedido vira **ENTREGUE** no MES.
6. O faturamento é outro assunto. O **Faturado** vem do Omie e não depende do **ENTREGUE** do MES.

## Os estados mais usados

### Pedido no MES

| Estado | O que significa |
|---|---|
| `AGUARDANDO` | Todo pedido nasce assim. |
| `EM_PRODUCAO`, `BLOQUEADO` | Existem no cadastro, mas o código nunca grava esses valores. |
| `ENTREGUE` | O pedido zerou o pendente e não há parcial ativa. É o único estado que muda sozinho. |

O dashboard conta a produção pela atividade das parciais, não por este campo.

### Item do pedido (parcial)

| Estado | Como aparece na tela | O que significa |
|---|---|---|
| `CRIADO` | Aguardando recebimento | Nasce no primeiro setor. |
| `RECEBIDO` | Recebido | O operador confirmou o recebimento. |
| `EM_ANDAMENTO` | Em produção | O trabalho começou. |
| `EM_TRANSITO` | Em trânsito | Foi para outro setor e espera o recebimento. |
| `PAUSADO` | Pausado | Parou com um motivo. Só sai por "retomar". |
| `REPROVADO` | Reprovado | A Qualidade reprovou. Abre uma divergência. |
| `CONCLUIDO` | Concluído | Passou pelo último setor do roteiro e está pronto para entrega. |
| `RETRABALHO` | Retrabalho | **Legado.** Nenhuma ação chega aqui. |
| `CANCELADO` | Cancelado | Estado final. |

### Requisição de compra

| Estado | O que significa |
|---|---|
| `ABERTA` | Pedido de compra criado, ainda sem andamento. |
| `EM_COMPRA` | O Compras está cuidando. |
| `RECEBIDA_PARCIAL`, `RECEBIDA` | Vêm da conferência do recebimento. |
| `CANCELADA` | Cancelada pelo PCP ou pelo Compras. |

No av-hub, a requisição passa por `aberta`, `em_cotacao`, `atendida` ou `cancelada`. O `atendida` só vem da ordem de compra.

### Etapa de compra de cada material

| Etapa | Quando acontece |
|---|---|
| `AGUARDANDO_COMPRADOR` | A requisição chegou ou foi reaberta, ou a OC foi cancelada. |
| `EM_COTACAO` | O comprador está cotando. |
| `EM_APROVACAO` | A OC foi criada e espera aprovação. |
| `COM_FORNECEDOR` | A OC foi aprovada. O material entra nos esperados do Recebimento. |
| `EM_TRANSITO` | O fornecedor despachou. |
| `CANCELADA` | A requisição foi cancelada. |

### Recebimento

- Se a conferência bate, o recebimento vai a `CONCLUIDO`.
- Se diverge, vai a `AGUARDANDO_RECONTAGEM`.
- Se continua divergindo, vai a `AGUARDANDO_DECISAO` e o PCP decide: `ACEITO` ou `REABERTO`.
- Detalhes em [[05-Recebimento]].

### Lote de estoque

| Estado | O que significa |
|---|---|
| `PENDENTE` | Espera a Qualidade. |
| `LIBERADO` | Pode ser usado. Só ele conta no saldo disponível. |
| `REPROVADO` | A Qualidade reprovou. |
| `QUARENTENA` | É a parte aprovada de uma reprovação parcial. Fica parada até a substituição (EC-07). |

A reserva não expira. Ela nasce `ATIVA`, vira `CONSUMIDA` na saída física e `LIBERADA` ao ser cancelada ([[06-Qualidade-Entrada]], [[03-Estoque-Atendimento-e-Despacho]]).

### Ordem de compra (OC)

| Estado | O que significa |
|---|---|
| `rascunho` | Ainda sendo montada. |
| `aguardando_aprovacao` | Está acima do limite da unidade (padrão R$ 30 mil). O Gerente de Compras decide. |
| `aprovado` | Aprovada. Até o limite, a OC vira `aprovado` sozinha. A Diretoria não aprova (N14-21). |
| `cancelado` | Cancelada. |

Detalhes em [[04-Circuito-de-Compra]].

### Etapa do item vista pelo vendedor

O vendedor vê o item em uma de 11 etapas, do "Requisição de compra" até o "Pronto para expedição". A etapa vem do **tipo do setor atual** mais o status. O vocabulário é provisório ([[API-005-Status-Item-Integracao-MES]], [[API-006-Status-por-Item-Leitura-no-Hub]]). A tabela completa está no Detalhe técnico. Não há etapa "entregue" nem "faturado" 🔴.

### Proposta e pedido do Hub 🟡

Estes estados são **propostos** (26/10/2026) e ainda não estão no banco de produção.

| Assunto | Estados |
|---|---|
| Proposta | `ABERTA`, `APROVADA`, `TRANSFORMADA`, `CANCELADA` |
| Envio do pedido ao Omie | `pendente`, `sincronizado`, `erro` |
| Comissão | `ESTIMADA`, `CONGELADA`, `EM_ACOMPANHAMENTO`, `ENCERRADA`, `CANCELADA` |

Todos os valores das tabelas novas estão no Detalhe técnico.

## Nomes que enganam

- `ENTREGUE` (pedido, MES) não é `Faturado` (pedido, Omie). São assuntos diferentes ([[10-Fiscal-Omie]]).
- `RECEBIDO` (parcial) não é `RECEBIDA` (requisição) nem o recebimento `CONCLUIDO`.
- `REPROVADO` aparece em três lugares: no item (produção), no lote (qualidade de entrada) e na etapa `qualidade.reprovado`.
- `CONCLUIDO` aparece no item (`StatusItemParcial`), no recebimento (`StatusRecebimento`) e no feed do av-hub (`encerramento`).

## O que já existe e o que falta

- ✅ Os valores do MES e do av-hub acima existem e foram conferidos.
- 🟡 Os 9 estados macro do desenho do vendedor não existem no código (detalhe abaixo).
- 🟡 Os estados da proposta, do pedido do Hub, do custo real e da comissão nova estão só em proposta.
- 🔴 O vocabulário de `estado_macro` não foi definido. O MES ainda não publica `/fluxo/eventos`.

## Detalhe técnico

Referência dos valores exatos (enums, `CHECK`, vocabulários). Valores em `código` são literais do banco ou do código.

### 1. MES (`public`, banco Postgres do MES)

Linhas do dump entre parênteses: `Dump MES (Esqueleto).sql`.

#### Pedido

| Enum | Valores | Fonte |
|---|---|---|
| `StatusPedido` | `AGUARDANDO`, `EM_PRODUCAO`, `BLOQUEADO`, `ENTREGUE` | `producao.prisma:11-16` (dump 246) ✅ |
| `Prioridade` | `BAIXA`, `NORMAL`, `ALTA`, `URGENTE` | `producao.prisma:3-8` (168) ✅ |
| `SistemaOrigem` | `OMIE`, `MANUAL` | `producao.prisma:23-26` (183) ✅ |

Uso: `ENTREGUE` é gravado por `EntregasService.create` quando zera o pendente e não resta parcial ativa (`entregas.service.ts:104-130`). `BLOQUEADO` e `EM_PRODUCAO` nunca são gravados por código: todo pedido nasce `AGUARDANDO` e a única transição automática é para `ENTREGUE` (`item-parcial-status.constants.ts:44-50`) ✅. O dashboard conta produção pela atividade das parciais, não por este campo.

#### Parcial do item (`ItemParcial.status`)

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

#### Divergência de produção

| Enum | Valores | Fonte |
|---|---|---|
| `StatusDivergencia` | `ABERTA`, `EM_ANALISE`, `RESOLVIDA`, `CANCELADA` | `producao.prisma:77-82` (dump 196) ✅ |
| `TipoDivergencia` | `QUALIDADE`, `QUANTIDADE`, `PRAZO`, `DANO`, `DOCUMENTACAO`, `OUTRO` | `producao.prisma:67-74` (339) ✅ |

`resolvido` e `cancelada` são terminais, sem reabertura 🔴 (`divergencias.service.ts`, método `resolver`). `reprovar` cria `QUALIDADE`/`ABERTA` (`itens-parciais.service.ts:1048-1058`).

#### Setor e fábrica

| Enum | Valores | Fonte |
|---|---|---|
| `TipoSetor` | `PRODUTIVO`, `ESTOQUE`, `COMPRAS`, `EXPEDICAO`, `REQUISICAO`, `LOGISTICA_ENTRADA`, `QUALIDADE` | `fabricas.prisma:17-32` (424) ✅ |
| `TipoFabrica` | `FABRICACAO`, `REVENDA` | `fabricas.prisma:5-8` (383) ✅ |

Códigos fixos do circuito de compra (`circuito-compra.ts:19-25`): `requisicoes-compra` (`REQUISICAO`), `compras` (`COMPRAS`), `logistica-entrada` (`LOGISTICA_ENTRADA`), `qualidade-entrada` (`QUALIDADE`), `estoque` (`ESTOQUE`, etapa 1 de todo roteiro, `SETOR_ESTOQUE_FIXO_CODIGO`) ✅. Rótulos das telas: Requisições de compras, Compras · CCP, Recebimento, Qualidade · Entrada, Estoque.

#### Requisição de compra (MES)

| Enum | Valores | Fonte |
|---|---|---|
| `StatusRequisicaoCompra` | `ABERTA`, `EM_COMPRA`, `RECEBIDA_PARCIAL`, `RECEBIDA`, `CANCELADA` | `compras.prisma:9-15` (292) ✅ |
| `TipoItemRequisicao` | `PRODUTO_FINAL`, `MATERIA_PRIMA` | `compras.prisma:19-22` (396) ✅ |

Resumo: `ABERTA` e `EM_COMPRA` alternam pelos marcos do av-hub; `RECEBIDA_PARCIAL` e `RECEBIDA` vêm da conferência; `CANCELADA` pelo PCP ou pelo Compras (`canceladaPor`: `mes` ou `compras`) ✅ (`compras.prisma:73-82`).

#### `etapaCompra` (por material da requisição)

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

#### Envio ao av-hub (fila do contrato 34)

| Enum | Valores | Fonte |
|---|---|---|
| `TipoEnvioAvhub` | `REQUISICAO_COMPRA` | `integracao.prisma:13-15` (371) ✅ |
| `StatusEnvioAvhub` | `PENDENTE`, `ENVIADO`, `RECUSADO` (409 `REQUISICAO_COM_OC`), `FALHOU` (400) | `integracao.prisma:24-29` (211) ✅ |

#### Recebimento

| Enum | Valores | Fonte |
|---|---|---|
| `StatusRecebimento` | `AGUARDANDO_RECONTAGEM`, `AGUARDANDO_DECISAO`, `CONCLUIDO`, `ACEITO`, `REABERTO` | `compras.prisma:31-37` (276) ✅ |
| `TipoDivergenciaRecebimento` | `QUANTIDADE`, `DESCRICAO`, `PESO`, `AVARIA` | `compras.prisma:42-47` (356) ✅ |

Regras: bateu vai a `CONCLUIDO`; divergiu vai a `AGUARDANDO_RECONTAGEM`; continuou divergindo vai a `AGUARDANDO_DECISAO` (PCP); decisão `ACEITO` ou `REABERTO`. `QUANTIDADE` e `PESO` são calculados; `DESCRICAO` e `AVARIA` são informados (`AVARIA` exige foto). Etapa da divergência: `conferencia` ou `recontagem` (texto, `compras.prisma:252`). Detalhes em [[05-Recebimento]].

#### Lote, estoque e reserva

| Enum | Valores | Fonte |
|---|---|---|
| `StatusQualidadeLote` | `PENDENTE`, `LIBERADO`, `REPROVADO`, `QUARENTENA` | `estoque.prisma:25-32` (261) ✅ |
| `OrigemLote` | `RECEBIMENTO`, `CARGA_INICIAL` (sem origem de produção 🔴) | `estoque.prisma:17-20` (155) ✅ |
| `NaturezaMaterial` | `MATERIA_PRIMA`, `REVENDA` | `estoque.prisma:12-15` (128) ✅ |
| `TipoMovimentoEstoque` | `ENTRADA`, `SAIDA`, `TRANSFERENCIA`, `AJUSTE` | `estoque.prisma:38-43` (409) ✅ |
| `StatusReserva` | `ATIVA`, `CONSUMIDA`, `LIBERADA` | `estoque.prisma:48-52` (308) ✅ |
| `OrigemCusto` | `CARGA_INICIAL`, `OC`, `MANUAL` | `estoque.prisma:378-382` (141) ✅ |

Saldo disponível conta só lote `LIBERADO` menos reservas `ATIVA` (`estoque-operacao.helpers.ts:165`). `QUARENTENA` é a parte aprovada de uma reprovação parcial até a substituição (EC-07). Reserva sem expiração: nasce `ATIVA`, vira `CONSUMIDA` na saída física e `LIBERADA` ao cancelar ([[06-Qualidade-Entrada]], [[03-Estoque-Atendimento-e-Despacho]]).

#### Anexos

`TipoAnexo`: `NOTA`, `CANHOTO`, `DESENHO`, `PEDIDO`, `ORDEM_PRODUCAO`, `COMPROVANTE_ENTREGA` (`producao.prisma:57-64`, dump 322) ✅.

### 2. Status por item: as 11 etapas (contrato 005)

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

### 3. av-hub (`core_*`, Postgres do av-hub)

#### Pedido de venda e liberação

| Campo | Valores | Fonte |
|---|---|---|
| `pedidos_vendas.situacao` (calculado por trigger) | `Cancelado`, `Denegado`, `Devolvido`, `Dev. Parcial`, `Encerrado`, `Faturado`, `Autorizado`, `Pendente` (ordem de precedência) | `fn_sync_situacao_pv`, Dump Avhub 9804 ✅ |
| `vw_pedidos_liberacao.status_liberacao` | `pendente`, `liberado`, `importado` | Dump Avhub 20870; [[01-Vendas-Liberacao]] ✅ |
| `acompanhamento_qualidade` | `true`, `false`, `null` | idem |
| `pedidos_vendas_liberacao_historico.acao` | `liberado`, `alterado`, `importado_mes` | idem |
| Erros da liberação | 404 `PEDIDO_FORA_DA_LIBERACAO`, 409 `PEDIDO_IMPORTADO_MES`, 409 `PEDIDO_NAO_LIBERADO`, 403 `PEDIDO_FORA_DO_ESCOPO`, 403 `SEM_VENDEDOR_VINCULADO` | `pedidos_liberacao.route.js:187-222`, `pedidos_liberados.route.js:50` ✅ |

#### Requisição de compra do av-hub (`requisicoes_compra`)

`status` (`ck_requisicoes_compra_status`, Dump Avhub 18569): `aberta`, `em_cotacao`, `atendida`, `cancelada`. `atendida` é marcada pela trigger da OC e exige `id_ordem_compra` (`ck_requisicoes_compra_atendida`, 18567); nunca pelo PATCH ✅. `avhubStatus` no MES guarda esse valor (`varchar(20)`).

#### Marcos da requisição (`requisicoes_compra_eventos.tipo`, contrato 35)

`requisicao_recebida`, `em_cotacao`, `oc_criada`, `oc_removida`, `oc_enviada_aprovacao`, `oc_aprovada`, `oc_no_omie`, `fornecedor_confirmou`, `previsao_alterada`, `despachada`, `ocorrencia`, `oc_cancelada`, `requisicao_cancelada`, `requisicao_reaberta` (14 valores, `requisicoes_compra_eventos_tipo_check`, Dump Avhub 18692) ✅. O MES aplica todos ([[Integracao-AvHub-MES]]).

#### Ordem de compra

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

Aprovação (`C3`, N14-21): OC acima do limite da unidade (`parametros_compras.limite_aprovacao`, padrão R$ 30 mil) fica `aguardando_aprovacao` até o Gerente de Compras aprovar; OC até o limite vira `aprovado` sozinha (compradores livres); a Diretoria não aprova ✅. Detalhes em [[04-Circuito-de-Compra]].

#### Torre de Fluxo (`core_fluxo`)

| Campo | Valores | Fonte |
|---|---|---|
| `evento.origem` | `av-hub` (único permitido) | `ck_evento_origem`, Dump Avhub 15649 ✅ |
| `item_estado_projetado.encerramento` | `cancelado`, `concluido` (preenchido junto com `encerrado_em`) | linha 2169 ✅ |
| `item_estado_projetado.estado_macro` | `varchar(40)`, vocabulário não definido 🔴 | linha 2176 |

Os 9 estados macro do desenho do vendedor (`AGUARDANDO_LIBERACAO`, `PENDENTE_PCP`, `EM_ESTOQUE`, `EM_COMPRA`, `EM_PRODUCAO`, `EM_RECEBIMENTO`, `EM_INSPECAO`, `PRONTO_EXPEDICAO`, `FATURADO`) não existem no código 🟡 ([[01-Vendas-Liberacao]]). O MES ainda não publica `/fluxo/eventos` 🔴 ([[Rastreabilidade-e-Torre-de-Fluxo]]).

#### Proposta, pedido de venda do Hub, custo real e comissão nova (proposta 🟡)

Valores dos `CHECK` das migrações propostas em 26/10/2026. Ainda não estão no banco de produção.

| Campo | Valores | Fonte |
|---|---|---|
| `core_comercial.propostas.status` | `ABERTA`, `APROVADA`, `TRANSFORMADA`, `CANCELADA` | N16-02, N16-03 |
| `core_comercial.pedidos.origem` | `PROPOSTA`, `OMIE` | N16-106 |
| `core_comercial.pedidos.status_sincronizacao_omie` | `pendente`, `sincronizado`, `erro` (o pedido do Omie nasce `sincronizado`) | padrão da OC |
| `core_comercial.pedidos_previsoes.tipo` | `INICIAL`, `ENTREGA_COMPRAS`, `ENTREGA_CCP` | N16-88 |
| `core_comercial.pedidos_sequenciais.status` | `ABERTO`, `FATURADO`, `CANCELADO` | N16-92 |
| `core_vendas_faturamento.pedidos_vendas_sequenciais_itens.origem_vinculo` | `HUB`, `PRODUTO`, `AMBIGUO`, `SEM_VINCULO` | N16-99, N16-100 |
| `core_comercial.calendario_excecoes.tipo` | `FERIADO`, `DIA_UTIL` | N16-104 |
| `core_comercial.ofertas.fonte` | `MANUAL`, `MAPA_COTACAO`, `MIGRACAO`, `OC_HUB`, `OC_OMIE` | |
| `core_comercial.custos_eventos.origem` | `OC_MATERIAL`, `LOTE_ESTOQUE`, `MATERIA_PRIMA_FABRICACAO`, `MAO_DE_OBRA_OC_SERVICO`; `status` `VALIDO`, `DESCARTADO`; `sentido` `1` ou `-1` (estorno) | N16-09, N16-20 |
| `core_comercial.divergencias_compra.estado` | `PENDENTE`, `APROVADO`, `REPROVADO`, `RESOLVIDO`; `solucao_tipo` `NOVO_VALOR`, `NOVO_FORNECEDOR`, `MANTIDO`, `PEDIDO_CANCELADO` | N16-60 a N16-73 |
| `core_comissao.comissoes.estado` | `ESTIMADA`, `CONGELADA`, `EM_ACOMPANHAMENTO`, `ENCERRADA`, `CANCELADA`; `origem` `PROPOSTA`, `PEDIDO_OMIE` | N16-10, N16-103 |
| `core_comissao.comissao_calculos.tipo` | `COTADO` (estimada ou simulação do vendedor), `REAL` (custo real) | N16-10 |
| `core_comissao.comissoes_nf.estado` | `AGUARDANDO_DECISAO`, `APROVADA`, `DESAPROVADA`, `BLOQUEADA`, `CORTADA`, `ALTERADA`, `NF_CANCELADA` | N16-43 a N16-46 |
| `core_comissao.comissao_lancamentos.tipo` | `COMPLEMENTO`, `DESCONTO`, `ABATIMENTO` | N16-47, N16-48 |

### 4. Pontes entre os dois lados

| MES | av-hub | Observação |
|---|---|---|
| `StatusRequisicaoCompra` `ABERTA`/`EM_COMPRA` | `aberta`, `em_cotacao`, `atendida` | O MES recalcula o resumo pelos marcos, não copia o status |
| `ItemParcial` + setor | `etapa` (11 valores) | job de 90 s no av-hub |
| `etapaCompra` | marco do evento | tabela da seção 1 |
| `StatusItemParcial.CANCELADO` | `mes_deleted_at` em `itens_pedido_status` | `deleted_at` no feed |
| `Pedidos.importadoAvhubEm` | `status_liberacao = importado` | `POST /pedidos_liberados/:numero/importado` |
