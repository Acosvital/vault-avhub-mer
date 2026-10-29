---
tags: [fluxo, raia, producao, roteiro, f1, p6, mes]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Robert (MES) · Nathan (decisões)
fontes: [api-pcp 579a625 (itens-parciais.service.ts, pedidos.service.ts, divergencias, roteiro-item, prisma/models/producao.prisma e fabricas.prisma), app-pcp 1fca8d3 (movimentacoes), v1 02-PRD-Estoque/Fluxo-Producao-OS-OP-Completo, v1 01-Fluxo-Operacional/Fluxograma-Telas-por-Bloco bloco 7, Dump MES 14/10]
---

# Produção e roteiro (F1, P6)

Nós do [[00-Fluxo-Mestre-0b]]: `F1` setores produtivos do roteiro de cada fábrica e `P6` novo norte (retrabalho ou reabre compra). A entrada vem do despacho do Estoque (`E6`, [[03-Estoque-Atendimento-e-Despacho]]); a saída vai para a inspeção de saída `Q7` ([[08-Qualidade-Saida]]). Selos em [[Regras-do-Vault]].

> [!info] Decisões de 29/10/2026 (N16-120 a N16-143)
> - N16-140: a matéria-prima é baixada na retirada do Estoque, pela quantidade pedida, no mesmo documento de retirada da Expedição. O operador não lança consumo ao concluir a etapa.
> - N16-141: no retrabalho, o PCP escolhe o setor de volta; a regra 8 abaixo (volta ao setor anterior) vale só até isso ter código.
> - Fabricado: [[LOG-53-Ordem-de-Producao-e-Lote-do-Fabricado]] desenha a volta ao Estoque como lote de origem Produção (proposta aceita em 15/10, sem código).

## Objetivo

Levar cada parcial do item pelos setores do roteiro do pedido, na ordem, até o último setor. O motor é o `ItemParcial` (fração de um item) com histórico imutável em `HistoricoItemParcial`. Toda transição usa escrita condicional (`updateMany` com o status esperado e `count === 0` vira 409), sem leitura seguida de escrita (`itens-parciais.service.ts:245-257`, `:324-337`). É o único subfluxo com motor completo no código desde o início do projeto ✅.

Produção só recebe o que o Estoque não atendeu e que não foi para compra. Revenda não produz: a fábrica `REVENDA` só envia o restante para compra (`itens-parciais.service.ts:722-730`).

## Quem atua

| Quem | Papel | Onde |
|---|---|---|
| PCP | Monta o roteiro na Destinação do Pedido, decide o novo norte (P6) | MES, `/ordens-producao/novo`, `/ordens-producao/[id]` |
| Operador de setor | Recebe, inicia, move, pausa, retoma, conclui | MES, Filas de Produção `/movimentacoes/[setorId]` |
| Máquina e operador | Cadastros exigidos por setor com `exigeMaquinaOperador` | `/cadastros/operacional/maquinas`, `operadores` |
| Quem cancela | Permissão `ordens-producao:deletar` (não a de setor) | detalhe do pedido |
| Robert | Dono do código MES | `api-pcp`, `app-pcp` |

O acesso a cada fila depende de `PerfilSetor` (`podeVisualizar`, `podeAtuar`), default-deny (`fabricas.prisma:162-185`, `itens-parciais.service.ts:52-54`). A rota exige a tela `movimentacoes` (`itens-parciais.controller.ts:56`, `:99`).

## Regras decididas

| # | Regra | Selo |
|---|---|---|
| 1 | O setor Estoque (`codigo = 'estoque'`) é a **etapa 1 de todo roteiro** e é inserido pelo backend. O payload não pode trazê-lo (`pedidos.service.ts:459-463`). Decisão EN-03 | ✅ 📝 |
| 2 | Setores de tipo `ESTOQUE`, `REQUISICAO`, `COMPRAS` e `LOGISTICA_ENTRADA` **não entram no roteiro** do PCP: o circuito de compra é fixo (`pedidos.service.ts:500-506`) | ✅ |
| 3 | Roteiro de **fabricação** exige um setor `QUALIDADE` (inspeção de saída) e ele vem antes da primeira `EXPEDICAO` (`pedidos.service.ts:512-525`). Decisão EC-06 | ✅ 📝 |
| 4 | O roteiro só pode usar setores vinculados à fábrica do pedido (`FabricaSetor`), sem repetir setor nem ordem (`pedidos.service.ts:450-474`) | ✅ |
| 5 | `receber` e `iniciar` são obrigatórios em todo setor antes de `mover` ou `concluir`. `iniciar` preenche `startedAt` (cronômetro) e, em setor com `exigeMaquinaOperador`, exige `idMaquina` e `idOperador` (`:299-321`) | ✅ |
| 6 | `concluir` só no **último** setor do roteiro; `mover` só quando existe próximo (`:540-547`, `:426-434`). `mover` aceita `idSetorDestino` livre dentro da fábrica e quantidade parcial (split na passagem) | ✅ |
| 7 | `reprovar` é exclusivo de setor tipo `QUALIDADE` (403 fora dele) e exige `EM_ANDAMENTO` (`:966-989`, `:1011-1021`) | ✅ |
| 8 | `retrabalho` só sai de `REPROVADO`: cancela a linha e cria outra `EM_TRANSITO` no setor anterior com `retrabalho = true` (`:1124-1192`). Não altera a quantidade do `ItensPedido` | ✅; **superada em parte pela N16-141 (29/10): o PCP passa a escolher o setor de volta, ainda sem código** |
| 9 | `devolver` cria linha nova ligada por `idDevolvidoDe`; a antiga vira `CANCELADO` e nunca é editada (`:1387-1488`). Não vale para parcial com requisição de compra viva (`ensureDevolucaoForaDaCompra`, `:1391`) | ✅ |
| 10 | Item de pedido inativo bloqueia toda ação, menos `cancelar` (`:202-208`) | ✅ |
| 11 | **Tudo que é fabricado volta ao Estoque** como lote e saldo, e só sai pelo documento de retirada. Decisão do Nathan de 14/10 | 📝 🔴 |
| 12 | **Matéria-prima é consumida do Estoque** na produção (J2/J3 do v1). **Decidido em 29/10 (N16-140): a baixa é na retirada do Estoque, pela quantidade pedida.** Sem código | 🔴 |
| 13 | Novo norte (P6): o PCP decide entre retrabalho e reabrir a compra. Roteiro individual do item (`RoteiroItem`, C8) é a ferramenta decidida | 📝 🔴 |

## Estados

`StatusItemParcial` (enum exato, `producao.prisma:29-54`; dump MES linha 226): `CRIADO`, `RECEBIDO`, `EM_ANDAMENTO`, `EM_TRANSITO`, `PAUSADO`, `REPROVADO`, `CONCLUIDO`, `RETRABALHO`, `CANCELADO`. Rótulos da tela em `movimentacoes/labels.ts:7-17`: Aguardando recebimento, Recebido, Em produção, Em trânsito, Pausado, Reprovado, Concluído, Retrabalho, Cancelado. `RETRABALHO` não é mais alcançado por nenhuma ação (só compatibilidade, `producao.prisma:47-52`).

Ações por status na fila (`app-pcp/app/(protected)/movimentacoes/acoes.ts:61-71`):

| Status | Ações |
|---|---|
| `CRIADO`, `EM_TRANSITO` | `receber`, `devolver` |
| `RECEBIDO` | `iniciar`, `desfazer-recebimento` |
| `EM_ANDAMENTO` | `mover`, `concluir`, `pausar`, `reprovar`, `devolver` |
| `PAUSADO`, `RETRABALHO` | `retomar` (volta a `EM_ANDAMENTO`) |
| `REPROVADO` | `retrabalho`, `resolver` |
| `CONCLUIDO` | `confirmar-entrega` |
| `CANCELADO` | nenhuma |

A tela filtra: `concluir` só com `ehUltimaEtapa`, `mover` só sem ela, `devolver` e `retrabalho` só com `idSetorOrigem`, `reprovar` só em setor `QUALIDADE` (`FilaSetor.tsx:685-691`). `cancelar` não aparece na fila: vive no detalhe do pedido (`acoes.ts:55-60`).

```mermaid
stateDiagram-v2
    [*] --> CRIADO : primeiro setor
    [*] --> EM_TRANSITO : mover, devolver, retrabalho, atender estoque
    CRIADO --> RECEBIDO : receber
    EM_TRANSITO --> RECEBIDO : receber
    RECEBIDO --> EM_ANDAMENTO : iniciar
    RECEBIDO --> EM_TRANSITO : desfazer recebimento (com setor de origem)
    EM_ANDAMENTO --> EM_TRANSITO : mover (para o proximo setor)
    EM_ANDAMENTO --> CONCLUIDO : concluir (ultimo setor)
    EM_ANDAMENTO --> PAUSADO : pausar
    PAUSADO --> EM_ANDAMENTO : retomar
    EM_ANDAMENTO --> REPROVADO : reprovar (so setor QUALIDADE)
    REPROVADO --> EM_ANDAMENTO : resolver (falso alarme)
    REPROVADO --> CANCELADO : retrabalho (nasce linha EM_TRANSITO no setor anterior)
    EM_ANDAMENTO --> CANCELADO : devolver (nasce linha nova)
    CONCLUIDO --> [*] : entrega
```

`StatusPedido` (`AGUARDANDO`, `EM_PRODUCAO`, `BLOQUEADO`, `ENTREGUE`) e `Prioridade` em [[Estados-e-Status]]. Só `AGUARDANDO` (inicial) e `ENTREGUE` são gravados; `EM_PRODUCAO` e `BLOQUEADO` nunca (`item-parcial-status.constants.ts:44-50`).

## Telas

| Nome atual | Nome antigo | Rota | App | Slug | Estado |
|---|---|---|---|---|---|
| Filas de Produção (escolha de setor) | Movimentações | `/movimentacoes` | app-pcp | `movimentacoes` | ✅ `movimentacoes/page.tsx` (177 linhas) |
| Fila do setor | idem | `/movimentacoes/[setorId]` | app-pcp | `movimentacoes` | ✅ `FilaSetor.tsx` (1272 linhas, 17 ações) |
| Destinação do Pedido | Nova Ordem de Produção | `/ordens-producao/novo` | app-pcp | `ordens-producao` | ✅ monta o roteiro (`RoteiroProducaoSection.tsx`) |
| Acompanhamento dos Pedidos | Ordens de Produção | `/ordens-producao`, `/ordens-producao/[id]` | app-pcp | `ordens-producao` | ✅ mini-roteiro por item, histórico, anexos |
| Dashboard | idem | `/dashboard` | app-pcp | ❓ | ✅ `GET /dashboard`; `GET /dashboard/tv` sem página 🔴 |
| Cadastros operacionais | idem | `/cadastros/operacional/fabricas`, `setores`, `maquinas`, `operadores` | app-pcp | ❓ | ✅ |

Os rótulos de menu moram no banco (tabela `telas`); o código ainda usa os nomes antigos em pastas e rotas. Lista geral em [[Telas-por-Raia]].

## Endpoints e contratos

Todos sob `@UseGuards(JwtAuthGuard, PermissionsGuard)`; setor checado por `perfisService.ensurePodeAtuar` (`itens-parciais.service.ts:227`).

| Método e rota | Efeito | Permissão | Código |
|---|---|---|---|
| `GET /itens-parciais?idSetorAtual=&status=&idItemPedido=` | fila do setor, com `ehUltimaEtapa` | `movimentacoes:visualizar` | `controller:56-60`, `service:43-145` ✅ |
| `GET /itens-parciais/contagem-por-setor` | badge por setor | idem | `controller:66-70` ✅ |
| `GET /itens-parciais/:id`, `/:id/setores-percorridos` | detalhe e destinos válidos de devolução | idem | `controller:93-149` ✅ |
| `PATCH /:id/receber` | `CRIADO` ou `EM_TRANSITO` para `RECEBIDO` | `movimentacoes:editar` | `service:224` ✅ |
| `PATCH /:id/iniciar` | `RECEBIDO` para `EM_ANDAMENTO` (máquina e operador) | idem | `service:299` ✅ |
| `PATCH /:id/mover` | `EM_ANDAMENTO` para `EM_TRANSITO` no próximo setor (ou `idSetorDestino`), com quantidade parcial | idem | `service:366` ✅ |
| `PATCH /:id/concluir` | `CONCLUIDO` no último setor | idem | `service:520` ✅ |
| `PATCH /:id/pausar`, `/:id/retomar` | pausa e retomada | idem | `service:881`, `:1199` ✅ |
| `PATCH /:id/reprovar`, `/:id/resolver`, `/:id/retrabalho` | reprovação com `Divergencia`, falso alarme, retrabalho | idem | `service:1011`, `:1067`, `:1124` ✅ |
| `POST /:id/split`, `PATCH /:id/consolidar` | divide e junta parciais `RECEBIDO` | idem | `service:1250`, `:1616` ✅ sem botão na tela |
| `POST /:id/devolver`, `PATCH /:id/desfazer-recebimento` | devolução e desfazer | idem | `service:1387`, `:1557` ✅ |
| `PATCH /:id/cancelar` | cancela de qualquer status não terminal; libera reservas | `ordens-producao:deletar` | `controller:274-282`, `service:1506` ✅ |
| `POST /itens-parciais/lote/:acao` | ação em lote (`ACOES_LOTE_ITEM_PARCIAL`) | `movimentacoes:editar` | `controller:78-91` ✅ sem UI |
| `POST /pedidos/completo/lote` | cria pedido, itens, parciais e roteiro (Estoque etapa 1) | `ordens-producao` | `pedidos.controller.ts:58` ✅ |
| `GET /pedidos/setor-estoque-fixo` | etapa 1 fixa para a tela | idem | `pedidos.controller.ts:92` ✅ |
| `/roteiros` CRUD, `/roteiro-item` CRUD | roteiro do pedido e roteiro individual do item | idem | `roteiros.controller.ts:24`, `roteiro-item.controller.ts:25` ✅ CRUD; `RoteiroItem` não é lido por nada |
| `/divergencias` (`POST`, `GET`, `PATCH :id`, `PATCH :id/resolver`) | divergência de produção | `movimentacoes` | `divergencias.controller.ts:26-63` ✅ |
| `GET /itens/status` | foto de cada parcial para o av-hub, com `etapa` | chave `MES_API_KEY` | `integracao-avhub.service.ts:114`, `etapaDoItem :167` ✅ ([[API-005-Status-Item-Integracao-MES]]) |

## Como está no código

### Roteiro

- `Roteiros` (`idPedido`, `idSetor`, `ordem`, único por pedido e ordem) é o roteiro do pedido, lido por `mover`, `concluir`, `atenderEstoque` e `findAll` (`producao.prisma:262-275`).
- `RoteiroItem` (roteiro individual do item, ex.: sub-item de composição) tem CRUD e tabela (`producao.prisma:278-291`) mas **nenhum serviço de movimentação o consulta**: `grep roteiroItem` fora do módulo próprio não acha nada ✅. É a lacuna do P6 (EC-03, C8) 🔴.
- Tipos de setor (`TipoSetor`, `fabricas.prisma:17-32`): `PRODUTIVO`, `ESTOQUE`, `COMPRAS`, `EXPEDICAO`, `REQUISICAO`, `LOGISTICA_ENTRADA`, `QUALIDADE`. Códigos fixos do circuito de compra em `circuito-compra.ts:19-25`: `requisicoes-compra`, `compras`, `logistica-entrada`, `qualidade-entrada`, `estoque`.
- Fábrica: `TipoFabrica` `FABRICACAO` ou `REVENDA`, escolhido por rodada na Destinação (`fabricas.prisma:5-8`).

### Filas e setores produtivos

Cada setor produtivo (Flange, Caldeiraria HRM, corte etc.) é um registro da tabela `setores` com tipo `PRODUTIVO`, vinculado às fábricas por `fabrica_setores`. Os nomes e as filas reais vêm do banco do ambiente, não do repositório ❓ (o `seed.ts` não cria setores). A fila lista `RECEBIDO`, `EM_ANDAMENTO` etc. do `STATUS_FILA_MOVIMENTACOES` e esconde `CONCLUIDO` já 100% entregue (`service:158-182`).

### Divergência de produção

`reprovar` grava `HistoricoItemParcial` e abre uma `Divergencia` tipo `QUALIDADE` `ABERTA` na mesma transação (`service:1036-1058`). `resolver` e `retrabalho` fecham a divergência como `RESOLVIDA` (`:1101-1109`, `:1168-1176`). `DivergenciasService.resolver` só aceita `RESOLVIDA` ou `CANCELADA` e recusa divergência já encerrada: **divergência encerrada não reabre** (`divergencias.service.ts:resolver`) 🔴. Não há tela de divergências de produção; `/decisoes-pcp` trata só divergência de recebimento ([[05-Recebimento]]).

### Consumo de matéria-prima 🔴

Não existe no `api-pcp`: nenhuma estrutura de produto, nenhuma baixa de insumo ao iniciar ou concluir etapa. Provas:

- `destinoRestante: 'ROTEIRO'` em `atenderEstoque` só move a parcial para a próxima etapa, sem reservar nem consumir material (`service:722-742`).
- `TipoItemRequisicao.MATERIA_PRIMA` existe só para a compra, com o comentário "ação no Estoque·Entrada na próxima rodada" (`compras.prisma:17-22`).
- Consumo de reserva (`consumirReservasDaParcial`, `estoque-operacao.helpers.ts:208`) só trata a parte "atendida pelo estoque", que é a que vai à Expedição.

O que falta: definir quem informa o material consumido (setor ao concluir etapa, ou Estoque ao despachar para a produção pelo documento de retirada), o vínculo produto acabado x matéria-prima, e a geração de `MovimentoEstoque` `SAIDA` com referência à parcial. Dono: Robert, decisão Nathan.

### Fabricado não vira lote 🔴

`OrigemLote` só tem `RECEBIMENTO` e `CARGA_INICIAL` (`estoque.prisma:17-20`; dump MES linha 155). Ao concluir o último setor, a parcial fica `CONCLUIDO` no setor final e a entrega a baixa por quantidade do `ItensPedido` (`entregas.service.ts:69-80`). Nada cria lote nem `SaldoEstoque` do fabricado.

## O que falta desenvolver

| # | O quê | Dono | Nó | Selo |
|---|---|---|---|---|
| 1 | Consumo de matéria-prima (modelo, tela, `SAIDA` com referência) | Robert | F1 | 🔴 |
| 2 | Fabricado aprovado vira lote e saldo (nova `OrigemLote`, por exemplo `PRODUCAO`) e volta ao Estoque antes da retirada | Robert | F1, `E5` | 🔴 |
| 3 | `RoteiroItem` lido por `mover`, `concluir` e Expedição (hoje todos usam `Roteiros`) | Robert | P6 | 🔴 |
| 4 | Tela do novo norte para divergência de produção (reprovada na inspeção de saída), com retrabalho e reabrir compra; `/decisoes-pcp` só cobre recebimento | Robert, Nathan decide | P6 | 🔴 |
| 5 | Reabertura de divergência (hoje `RESOLVIDA` e `CANCELADA` são terminais) | Robert | P6 | 🔴 |
| 6 | Reabertura de compra a partir da produção (P6 para P3): sem rota; só a divergência de recebimento reabre (`REABERTO`) | Robert | P6 | 🔴 |
| 7 | Botões de `split` e `consolidar` na fila (API existe) | Robert | F1 | 🟡 |
| 8 | Painel TV (`GET /dashboard/tv` sem página) | Robert | F1 | 🔴 |
| 9 | `PerfilSetor` sem dimensão de filial (T.2/C3) | Robert | F1 | 🔴 |
| 10 | Feed `/fluxo/eventos` com ator, autorizador e tempo por etapa ([[Rastreabilidade-e-Torre-de-Fluxo]]) | Robert | todos | 🔴 |

## Pendências

- Nathan: quem informa o consumo de matéria-prima e em que momento (retirada do Estoque ou conclusão da etapa)? **Decidido em 29/10/2026 (N16-140): na retirada do Estoque, pela quantidade pedida.**
- Nathan e Robert: a fábrica com múltiplos setores `PRODUTIVO` consome por etapa ou só no primeiro?
- Nathan: retrabalho volta sempre ao setor imediatamente anterior? Hoje é `idSetorOrigem`, sem escolha (`:1134-1142`). **Decidido em 29/10/2026 (N16-141): não; o PCP escolhe o setor de volta.**
- Robert: confirmar nomes de setores e filas reais do ambiente de produção (código só traz o seed) ❓.

## Subfluxo

```mermaid
flowchart TD
    E6["E6 · Despacho do Estoque<br/>materia-prima ou beneficiamento"] --> F1["F1 · Setores produtivos do roteiro<br/>receber, iniciar, mover, concluir"]
    F1 --> Q7["Q7 · Inspecao de saida<br/>setor QUALIDADE no roteiro"]
    Q7 --> Q8{"Q8 · Aprova?"}
    Q8 -->|sim| E5["E5 · Entrada no Estoque (decidido, sem codigo)"]
    Q8 -->|nao| P6["P6 · Novo norte"]
    P6 -->|retrabalho| F1
    P6 -->|reabre compra| P3["P3 · Requisicao de compra"]
    F1 -.->|"consumo de materia-prima (sem codigo)"| E1["E1 · Estoque"]
```

Raias vizinhas: [[03-Estoque-Atendimento-e-Despacho]], [[08-Qualidade-Saida]].
