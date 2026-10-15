---
tags: [sistemas, bugs, pendencias, mes, av-hub, pipeline]
criado: 2026-10-14
atualizado: 2026-10-15
status: vigente
dono: Nathan
fontes: [api-pcp 579a625, app-pcp 1fca8d3, api-acos-vital f322dcd, HUB b55ac55, omie-elt-pipeline 0f739f0, Dump MES e Dump Avhub de 14/10, v1 AV-Hub-Bugs-Catalogo (revisado item a item)]
---

# Bugs conhecidos

Só entra aqui o que foi **conferido no código ou no dump de 14/10**. Cada linha tem severidade, quem corrige, o selo e a evidência. O que é lacuna de fluxo (falta construir) fica em [[Pontas-Soltas]] e [[Backlog-por-Frente]]; diferença entre código e banco, em [[Diferencas-Codigo-x-Banco]]. Severidade: **alta** = bloqueia o fluxo ou expõe dado; **média** = degrada; **baixa** = cosmético ou dívida. Selos: [[Regras-do-Vault]].

## Bloqueiam o fluxo de Atividades

| # | Severidade | Dono | Bug | Selo e evidência |
|---|---|---|---|---|
| B1 | alta | Gustavo | **Custo por item sem banco compatível.** O código (`f322dcd`, migration 047b) lê `fn_itens_pedido_custo_do_pedido` com `codigo_produto_omie`; o dump de 14/10 ainda tem a versão 047: coluna `item`, `UNIQUE (codigo_empresa, numero_pedido, item)` e a função devolve `item`. `GET /itens_pedido_custo` responde 500 "exige a migration 047b" contra esse banco | ✅ `itens_pedido_custo.route.js:98-103` x dump `:4393`, `:16782`, `:23010` |
| B2 | alta | Robert | **O MES não publica `GET /fluxo/eventos`, `/fluxo/itens/:id(/tempo)`, `/fluxo/sla-etapas` nem `GET /itens/custo`.** Os jobs do av-hub (Torre e custo) recebem 404, avisam uma vez e tentam de novo a cada 10 min; `core_fluxo.item_estado_projetado` e `itens_pedido_custo` ficam vazias | ✅ grep sem ocorrência em `api-pcp/src`; `item_estado_projetado.job.js:41-60`, `itens_pedido_custo.job.js:49-56` |
| B5 | alta | Robert | **Fabricado aprovado nunca vira lote nem saldo.** `OrigemLote` só tem `RECEBIMENTO` e `CARGA_INICIAL` | ✅ dump `:155-158`; `prisma/models/estoque.prisma:17-20` |
| B6 | alta | Robert | **A baixa de saldo acontece na Embalagem/Expedição, não no despacho do Estoque.** `consumirReservasDaParcial` roda no `receber` da parcial atendida pelo estoque e, de novo, na entrega; não há documento de retirada | ✅ `itens-parciais.service.ts:279`, `entregas.service.ts:88`, `estoque-operacao.helpers.ts:208` |
| B7 | média | Robert | **O custo da OC nunca é gravado no lote.** `lote_custo` só é escrito na carga inicial e copiado na cisão (reprovação parcial); as origens `OC` e `MANUAL` de `OrigemCusto` não têm escritor | ✅ `estoque-operacao.service.ts:440`, `estoque-operacao.helpers.ts:432-452`; grep `loteCusto` |
| B8 | média | Robert | **O MES não lê a referência da OC** (`GET /ordens-compra/referencia`, API-004/007): o Recebimento confere só contra a NF, sem cruzar com a OC | ✅ grep em `api-pcp/src` sem ocorrência; rota existe em `vw_ordens_compra_referencia_mes.route.js:70` |
| B9 | média | Robert | **Fornecedor da OC não chega ao MES.** A tabela `fornecedores` (projeção de `core.parceiros`) existe e nenhum código a popula ou lê; o fornecedor do lote vem como texto digitado na conferência | ✅ Dump MES `:595`; `prisma/models/estoque.prisma:183-198`; grep sem uso |

## Defeitos de código

| # | Severidade | Dono | Bug | Selo e evidência |
|---|---|---|---|---|
| B10 | média | Gustavo | **`alterado_desde` é código morto em `GET /produtos` e `GET /parceiros`.** O filtro está escrito depois do `return where`, nunca roda. O contrato API-001 diz "aplicado" | ✅ `core/tables/produtos/produtos.route.js:51-62`, `core/tables/parceiros/parceiros.route.js:95-109` |
| B12 | média | Gustavo | **`pessoa_vendedor` tem model e rota (`/pessoa_vendedor`) e não existe tabela nem view no dump** | ✅ `schemas/core_vendas_faturamento/index.js` (import e rota) x dump sem `pessoa_vendedor` |
| B13 | baixa | Gustavo | `POST /usuarios/:id/favoritos`: `usuarios_favoritos.model.js` declara `id` como PK sem `defaultValue`/`allowNull`; em setembro dava `400 "Campo obrigatório não informado: id"`. Não reproduzido em 14/10 | ❓ `auth/tables/usuarios_favoritos/usuarios_favoritos.model.js:10-14` |
| B14 | baixa | Gustavo | O job do status por item ainda lê regra de ambiente (`MES_STATUS_INTERVALO_SEG`, `MES_STATUS_CORTE_INICIAL_DIAS`), contra a regra do Nathan; Torre e custo já são constantes | ✅ `itens_pedido_status.job.js:34-52` x `item_estado_projetado.job.js:41-46` |
| B15 | baixa | Robert | Os três timers do MES (`AVHUB_ENVIO_INTERVALO_SEG`, `AVHUB_EVENTOS_INTERVALO_MIN`, `AVHUB_REENVIO_IMPORTADO_MIN`) são regra em ambiente | ✅ `envio-avhub.service.ts:46`, `eventos-avhub.service.ts:61`, `pedidos.service.ts:81` |
| B16 | baixa | Robert | `GET /requisicoes-compra` (contrato 003) continua exposto e sem consumidor; o comentário "JOB DE POLLING do MES" em `requisicoes_compra.route.js:31` está velho (o MES empurra por `PUT`) | ✅ `integracao-avhub.controller.ts:20`; `requisicoes_compra.route.js:31-34` |
| B17 | baixa | Robert | `StatusPedido.BLOQUEADO` nunca é atribuído (só o dashboard o lê); o `ENTREGUE` sobrescreve qualquer status | ✅ grep `BLOQUEADO`; `entregas.service.ts:100-130` |
| B18 | baixa | Robert | Rota de demonstração `GET /auth/dashboard-check` ainda exposta | ✅ `auth.controller.ts:70` |
| B19 | baixa | Nathan | 11 marcas `GAMBIARRA(` no HUB (regra de negócio no front): `dash-comissoes/page.tsx`, `AcompanhamentoClientes*.tsx`, `lib/api/pedidosVenda.ts`, `portalPcp.ts`, `loginRateLimiter.ts`, `comissoes/coordenadores.ts`, `domain/acompanhamentoClientes.ts`, `orcamento/dados.ts` | ✅ grep de 14/10 |
| B20 | baixa | Nathan | Orçamento roda sobre JSON local (`lib/orcamento/data/*.json`), não sobre `core_compras.orc_*` que a API já expõe | ✅ `HUB lib/orcamento/dados.ts:1-20` |
| B21 | baixa | Gustavo | Comentários velhos no pipeline: `ecosystem.config.cjs` fala em `SYNC_ENVIO_OC=false` e o `README.md` termina com "Ainda não feito: o envio da OC"; o envio é fixo e está feito | ✅ `ecosystem.config.cjs:62`, `README.md:169-171` |

## Fechados ou obsoletos em relação ao v1

Itens do catálogo de bugs do v1 (revisão de 07/10) que o código de 14/10 já resolve ou que mudaram:

- ✅ **Paginação por pedido de `/vendas_planilha`**, chave composta da blacklist, filtros e ordenação: corrigidos (a tela usa `GET /pedidos_venda`).
- ✅ **"Rotas de Compras respondendo 500"**: o módulo de Compras foi refeito (contratos 16 a 38); as views antigas `core_compras.vw_*` existem de novo no dump (`vw_catalogo_de_produtos`, `vw_fornecedores_com_produtos`, `vw_historico_precos`, `vw_produto_fornecedores`, `vw_todos_os_fornecedores`) ✅ dump.
- ✅ **"Registrar compra" manual do MES** (`PATCH /compras/requisicoes/:id/compra`): removido.
- ✅ **Contrato 35 incompleto no MES**: o MES agora usa **todos** os 14 marcos ✅ `requisicao-avhub.eventos.ts:234-246` (ver [[Integracao-AvHub-MES]]).
- ✅ **`lote_custo`, `core_fluxo` e `itens_pedido_custo` "não existem"**: existem no código e no dump (a versão do custo é a do B1).
- ✅ **Aprovação da OC** (antes B3): não é bug. O banco aprova até o limite e a API exige `pode_aprovar` acima dele, que é a regra decidida em 14/10 (N14-21; `ordens_compra.route.js:1230-1240`).
- ✅ **Requisição criada só no av-hub não chega ao MES** (antes B4): a requisição não precisa chegar; o MES lê a **OC** pela referência. Virou requisito de integração (N14-20; BL-006, BL-049 a BL-051), não bug.

## Como usar esta lista

- Bug de **banco ou API do av-hub**: abrir com o Gustavo. De **MES**: Robert. De **tela do av-hub**: Nathan.
- Ao corrigir, apague a linha daqui (a nota diz só o estado atual) e registre a mudança no commit.
