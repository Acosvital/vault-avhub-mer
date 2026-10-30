---
tags: [sistemas, bugs, pendencias, mes, av-hub, pipeline]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [api-pcp befd973 (develop), app-pcp 93f96de (develop), api-acos-vital 0384e89 (develop), av-hub 758d5f0 (develop), omie-elt-pipeline 0f739f0, Dump MES de 14/10, Dump do Avhub de 29/10, v1 AV-Hub-Bugs-Catalogo (revisado item a item)]
---

# Bugs conhecidos

**Em uma frase:** é a lista de defeitos já conferidos no código ou no banco (revisão de 29/10), com gravidade e quem corrige. Falta de funcionalidade fica em [[Pontas-Soltas]] e [[Backlog-por-Frente]].

## Quem usa e para quê

- **Gustavo, Robert e Nathan:** cada um vê o que é seu para corrigir.
- **Quem planeja:** vê o que ainda trava o fluxo.

## Como se encaixa no fluxo

Os defeitos graves que restam travam a Torre de Fluxo e a baixa do Estoque no despacho.

- Banco e API do av-hub: Gustavo.
- MES: Robert.
- Telas do av-hub: Nathan.

## Regras que valem

- Só entra aqui o que foi conferido. Cada linha tem gravidade (alta, média ou baixa), dono, selo e evidência.
- Ao corrigir, apague a linha. A nota mostra só o estado atual.
- Diferença entre código e banco fica em [[Diferencas-Codigo-x-Banco]].

## O que já existe e o que falta

**Graves (alta), travam o fluxo:**

- 🔴 B2 (Robert): o MES não publica a Torre de Fluxo (`/fluxo/*`). O job da Torre do av-hub recebe 404. O custo por item (`GET /itens/custo`) já existe, mas só na `develop` do MES.
- 🔴 B6 (Robert): a baixa do saldo acontece na Embalagem, não no despacho do Estoque.

**Médios:**

- 🔴 B12 (Gustavo): rota de `pessoa_vendedor` sem tabela.
- 🟡 B9 (Robert): a tabela `fornecedores` do MES continua sem uso (o fornecedor da OC já chega pela referência da OC).

**Baixos (B13 a B21):** favoritos sem `id` ❓, regras em variável de ambiente 🟡, rota antiga sem consumidor 🟡, `BLOQUEADO` nunca usado, rota de demonstração exposta, 9 marcas `GAMBIARRA(`, comentários velhos na API e no pipeline.

**Corrigidos em relação à revisão de 14/10:** B1 (custo por item sem a migration 047b), B5 (fabricado vira lote), B7 (custo da OC no lote), B8 (MES lê a referência da OC), B10 (filtro `alterado_desde`), B20 (Orçamento em JSON local). Detalhe em "Fechados" abaixo. A aprovação da OC (N14-21) e a requisição que não chega ao MES (N14-20) não são bugs.

## Detalhe técnico

Só entra aqui o que foi **conferido no código ou nos dumps**. Cada linha tem severidade, quem corrige, o selo e a evidência. O que é lacuna de fluxo (falta construir) fica em [[Pontas-Soltas]] e [[Backlog-por-Frente]]; diferença entre código e banco, em [[Diferencas-Codigo-x-Banco]]. Severidade: **alta** = bloqueia o fluxo ou expõe dado; **média** = degrada; **baixa** = cosmético ou dívida. Selos: [[Regras-do-Vault]].

### Bloqueiam o fluxo de Atividades

| # | Severidade | Dono | Bug | Selo e evidência |
|---|---|---|---|---|
| B2 | alta | Robert | **O MES não publica `GET /fluxo/eventos`, `/fluxo/itens/:id(/tempo)` nem `/fluxo/sla-etapas`.** O job da Torre do av-hub recebe 404, avisa uma vez e tenta de novo a cada 10 min; `core_fluxo.item_estado_projetado` fica vazia. O `GET /itens/custo` passou a existir em 27/10 (`6c11147`), só na `develop`; na `main` do MES (parada em 08/10) o job de custo ainda recebe 404 | ✅ grep sem `fluxo/` em `api-pcp/src`; `item_estado_projetado.job.js:41-60`; `integracao-avhub.controller.ts:29` |
| B6 | alta | Robert | **A baixa de saldo acontece na Embalagem/Expedição, não no despacho do Estoque.** `consumirReservasDaParcial` roda no `receber` da parcial atendida pelo estoque e, de novo, na entrega; não há documento de retirada | ✅ `itens-parciais.service.ts:318`, `entregas.service.ts:72`, `estoque-operacao.helpers.ts` |

### Defeitos de código

| # | Severidade | Dono | Bug | Selo e evidência |
|---|---|---|---|---|
| B9 | baixa | Robert | **Tabela `fornecedores` do MES sem uso.** Nenhum código a popula ou lê. O fornecedor da OC chega ao MES desde 26/10 pela referência da OC (`oc_referencia.nome_fornecedor`, api007b) e preenche o espelho da requisição; o fornecedor do lote da conferência ainda é texto digitado | ✅ `prisma/models/estoque.prisma`; `compra-oc.ts:12-23`; grep `prisma.fornecedor` sem ocorrência |
| B12 | média | Gustavo | **`pessoa_vendedor` tem model e rota (`/pessoa_vendedor`) e não existe tabela nem view nos dumps de 14/10 e de 29/10** | ✅ `schemas/core_vendas_faturamento/index.js` (import e rota) x dumps sem `pessoa_vendedor` |
| B13 | baixa | Gustavo | `POST /usuarios/:id/favoritos`: `usuarios_favoritos.model.js` declara `id` como PK sem `defaultValue`/`allowNull` (de propósito: o banco tem `DEFAULT uuidv7()`); em setembro dava `400 "Campo obrigatório não informado: id"`. Não reproduzido em 14/10 e não reconferido em 29/10 | ❓ `auth/tables/usuarios_favoritos/usuarios_favoritos.model.js:10-14` |
| B14 | baixa | Gustavo | O job do status por item ainda lê regra de ambiente (`MES_STATUS_INTERVALO_SEG`, `MES_STATUS_CORTE_INICIAL_DIAS`), contra a regra do Nathan; Torre e custo já são constantes | ✅ `itens_pedido_status.job.js:30-52` x `item_estado_projetado.job.js:41-46` |
| B15 | baixa | Robert | Os cinco timers do MES (`AVHUB_ENVIO_INTERVALO_SEG`, `AVHUB_EVENTOS_INTERVALO_MIN`, `AVHUB_REENVIO_IMPORTADO_MIN`, `AVHUB_OC_INTERVALO_MIN`, `AVHUB_REQ_HUB_INTERVALO_MIN`) são regra em ambiente | ✅ `envio-avhub.service.ts:40`, `eventos-avhub.service.ts:56`, `pedidos.service.ts:81`, `oc-referencia-avhub.service.ts:105`, `requisicao-hub-referencia-avhub.service.ts:87` |
| B16 | baixa | Robert | `GET /requisicoes-compra` (contrato 003) continua exposto e sem consumidor; o comentário "JOB DE POLLING do MES" em `requisicoes_compra.route.js` está velho (o MES empurra por `PUT`) | ✅ `integracao-avhub.controller.ts:18`; `requisicoes_compra.route.js:31-34` |
| B17 | baixa | Robert | `StatusPedido.BLOQUEADO` nunca é atribuído (só o dashboard o lê); o `ENTREGUE` sobrescreve qualquer status | ✅ `dashboard.service.ts:86`; `entregas.service.ts:81` |
| B18 | baixa | Robert | Rota de demonstração `GET /auth/dashboard-check` ainda exposta | ✅ `auth.controller.ts:57` |
| B19 | baixa | Nathan | 9 marcas `GAMBIARRA(` no HUB (regra de negócio no front), em 8 arquivos: `dashboards/dash-comissoes/page.tsx`, `AcompanhamentoClientes.tsx`, `PedidosLista.tsx`, `PropostaForm.tsx`, `lib/api/acompanhamentoClientesPlanilha.ts`, `lib/comissoes/coordenadores.ts`, `lib/domain/acompanhamentoClientes.ts`, `services/cadastros/auxiliares/produtosDuplicadosMock.ts` | ✅ grep de 29/10 |
| B21 | baixa | Gustavo | Comentários velhos no pipeline: `ecosystem.config.cjs` fala em `SYNC_ENVIO_OC=false` e o `README.md` termina com "Ainda não feito: o envio da OC"; o envio é fixo e está feito | ✅ `ecosystem.config.cjs:62`, `README.md:169` (pipeline sem commits desde 08/10) |

### Fechados ou obsoletos

Fechados entre 14 e 29/10 (conferidos no código e no dump de 29/10):

- ✅ **B1, custo por item sem a migration 047b**: o dump de 29/10 já tem `UNIQUE (codigo_empresa, numero_pedido, codigo_produto_omie)` e a função devolvendo `codigo_produto_omie`.
- ✅ **B5, fabricado nunca vira lote**: `OrigemLote.PRODUCAO` e `receberFabricado` (LOG-53, `ab3318d`, 27/10, `develop`).
- ✅ **B7, custo da OC nunca gravado no lote**: `lote_custo` com `origem = OC` (`97b9adc`, 16/10) e `MANUAL` (`PUT /estoque/lotes/:id/custo`), com snapshot na saída (`6c11147`, 27/10).
- ✅ **B8, MES não lê a referência da OC**: `oc-referencia-avhub.service.ts` (`114ba89`, 15/10) e a do Hub (API-009, `9e75df5`, 23/10).
- ✅ **B10, `alterado_desde` morto em produtos e parceiros**: corrigido em `38d2f74` (16/10).
- ✅ **B20, Orçamento em JSON local**: o módulo antigo saiu em 16/10 (`c851cda`); o novo lê a API do Hub.

Itens do catálogo de bugs do v1 (revisão de 07/10) que o código já resolve ou que mudaram:

- ✅ **Paginação por pedido de `/vendas_planilha`**, chave composta da blacklist, filtros e ordenação: corrigidos (a tela usa `GET /pedidos_venda`).
- ✅ **"Rotas de Compras respondendo 500"**: o módulo de Compras foi refeito (contratos 16 a 38); as views antigas `core_compras.vw_*` existem de novo no dump (`vw_catalogo_de_produtos`, `vw_fornecedores_com_produtos`, `vw_historico_precos`, `vw_produto_fornecedores`, `vw_todos_os_fornecedores`) ✅ dump.
- ✅ **"Registrar compra" manual do MES** (`PATCH /compras/requisicoes/:id/compra`): removido.
- ✅ **Contrato 35 incompleto no MES**: o MES agora usa **todos** os 14 marcos ✅ `requisicao-avhub.eventos.ts` (ver [[Integracao-AvHub-MES]]).
- ✅ **`lote_custo`, `core_fluxo` e `itens_pedido_custo` "não existem"**: existem no código e nos dumps.
- ✅ **Aprovação da OC** (antes B3): não é bug. O banco aprova até o limite e a API exige `pode_aprovar` acima dele, que é a regra decidida em 14/10 (N14-21; `ordens_compra.route.js:1230-1240`).
- ✅ **Requisição criada só no av-hub não chega ao MES** (antes B4): a requisição não precisa chegar; o MES lê a **OC** pela referência. Virou requisito de integração (N14-20; BL-006, BL-049 a BL-051), não bug, e hoje o MES lê a referência da requisição e da OC (`develop`).

### Como usar esta lista

- Bug de **banco ou API do av-hub**: abrir com o Gustavo. De **MES**: Robert. De **tela do av-hub**: Nathan.
- Ao corrigir, apague a linha daqui (a nota diz só o estado atual) e registre a mudança no commit.
