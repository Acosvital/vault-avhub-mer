---
tags: [desenvolvimento, backlog, pendencias]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [00-Fluxo-Mestre-0b, Integracao-AvHub-MES, api-pcp 579a625, app-pcp 1fca8d3, api-acos-vital f322dcd, omie-elt-pipeline 0f739f0, HUB b55ac55, Dump Avhub e Dump MES de 14/10, Registro-de-Decisoes]
---

# Backlog por frente

O que **falta desenvolver** no fluxo de Atividades ([[00-Fluxo-Mestre-0b]]), conferido no código em 14/10/2026. Cada item tem ID `BL-nnn` (estável, citado por outras notas), nó do 0b, contrato, selo e evidência. Dentro de cada frente a ordem é a dos nós do 0b (V, P, E, C, FN, R, Q, F, X, O) e depois o transversal. Divisão: Robert = MES (`api-pcp`, `app-pcp`); Gustavo = banco e API do av-hub; Nathan = front do HUB e coordenação; Pablo = Comercial & Suprimentos ([[Equipe-e-Divisao]]). Selos: [[Regras-do-Vault]]. Lacunas de decisão e dúvidas: [[Pontas-Soltas]]; riscos: [[Riscos]].

## Frente Robert (MES: `api-pcp` e `app-pcp`)

| ID | Nó | O que falta | Contrato | Selo | Evidência |
|---|---|---|---|---|---|
| BL-036 | P1, P2 | Nomes técnicos antigos: rotas `/carteira` e `/ordens-producao/novo`, campo `ordemProducao`, prefixo `OP-`. Rótulos novos (Triagem do Pedido, Destinação do Pedido) já decididos; o código usa os antigos | [[LOG-26-Vendas-Liberacao-Pedido]] | 🔴 (nome 📝 #74) | `app-pcp/app/(protected)/carteira`, `app-pcp/app/(protected)/ordens-producao`, `api-pcp/prisma/models/producao.prisma:97` |
| BL-011 | P6 | **Novo norte:** o `RoteiroItem` não é lido por mover, concluir nem Expedição (C8, EC-03); `/decisoes-pcp` só trata divergência de recebimento. Retrabalho ou reabertura de compra sem tela | [[00-Fluxo-Mestre-0b]] | 🔴 | `api-pcp/src/itens-parciais/itens-parciais.service.ts:366` (`mover`), `:520` (`concluir`) sem referência a `roteiroItem` |
| BL-031 | E1 | G1: carga inicial em lote com custo unitário **opcional**; até 23/10, antes do levantamento físico de 26 a 30/10 | [[API-008-Custo-do-Lote-no-MES]] | 🔴 (custo opcional 📝 #93) | `api-pcp/src/estoque/operacao/estoque-operacao.service.ts:440` grava o custo; lote em lote não existe |
| BL-004 | E3 | `GET /itens/custo` (grão filial + pedido + produto, array puro, cursor `alterado_desde` + `apos_id`) e marca de reserva alterada para o `alterado_em` do custo | [[API-008-Custo-do-Lote-no-MES]], [[LOG-47-Custo-Real-por-Item-no-Hub]] | 🔴 | nenhuma ocorrência de `itens/custo` nem `custoAlteradoEm` em `api-pcp/src`; o job do hub chama e recebe 404 (`itens_pedido_custo.job.js:51-52`) |
| BL-010 | E4, F1 | "Enviar à produção" não baixa matéria-prima; consumo de MP, FIFO com escolha manual (DEC-12) e genealogia (J2, J3, J5). Ciclo 1 | [[00-Fluxo-Mestre-0b]] | 🔴 | `ItensParciaisService.atenderEstoque` (`itens-parciais.service.ts:607`) só trata produto pronto |
| BL-007 | E6 | **Documento de retirada**: quem precisa da mercadoria (Expedição ou Produção) gera o documento; a baixa do saldo é na retirada. Hoje a baixa acontece quando a Embalagem recebe a parcial, e há uma segunda chamada como garantia na entrega | decisão 📝 14/10 | 🔴 | `itens-parciais.service.ts:279` (`consumirReservasDaParcial` ao receber), `entregas/entregas.service.ts:88`, `estoque-operacao.helpers.ts:208`; nenhuma ocorrência de "retirada" em `api-pcp/src` nem em `app-pcp` |
| BL-008 | E5, Q8, F1 | **Fabricado aprovado vira lote e saldo no Estoque** (decidido EN-04, reconfirmado 29/09 e 14/10). Hoje `OrigemLote` só tem RECEBIMENTO e CARGA_INICIAL e o "sim" da inspeção de saída segue ao próximo setor do roteiro (Expedição) | EN-04 📝 | 🔴 | `api-pcp/prisma/models/estoque.prisma:17-20`; `qualidade.service.ts:97` devolve ao Estoque só o comprado (`devolverAoEstoqueParciaisProntas`, `compras/circuito-compra.ts:166`) |
| BL-006 | C0, R0 | Requisição criada só no av-hub (Compras, "Nova requisição") não tem `id_origem`, não gera evento e não chega ao MES: sem esperado, sem NF. Proposta 🟡: o hub gera evento também sem `id_origem` e o MES cria o esperado a partir da OC (BL-001) | [[LOG-35-Compras-Marcos-Requisicao-para-MES]], [[API-004-Referencia-OC-Integracao-MES]] | 🔴 | `Dump Avhub (Esqueleto).sql:8585-8587` (a função de evento retorna se `id_origem` é nulo) |
| BL-009 | C1 a C5 | Etapa de compra mais fina no status por item: `compras.fechamento` ainda é "Em compra", sem cotação, aprovação e trânsito, embora o MES já tenha `etapaCompra` | [[API-005-Status-Item-Integracao-MES]] | 🔴 (com Nathan) | `api-pcp/src/integracao-avhub/integracao-avhub.service.ts:167-192` (11 etapas); `compras.prisma:147` (`etapaCompra`) |
| BL-001 | C4, R0, R1, R4 | **Job do MES que lê `GET /ordens-compra/referencia`** com valores (moeda, cotação, valor unitário, desconto) e grava a projeção de OC por `(codigo_empresa, id_ordem_compra)`; habilita fornecedor, cruzamento com a OC e custo | [[API-004-Referencia-OC-Integracao-MES]], [[API-007-Referencia-OC-Valores-no-MES]] | 🔴 | nenhuma ocorrência de `ordens-compra` em `api-pcp/src`; bloqueado por BL-002 e BL-018 |
| BL-017 | C5 | Perfil **CCP** (trata os "Follow-ups"); Compras · CCP no MES já é só leitura | [[LOG-32-Compras-CCP-Acompanhamento-OC]] | 🔴 (perfil 📝 #48) | `api-pcp/src/compras/compras.controller.ts:23-70` (só `movimentacoes`) |
| BL-005 | R4 | **Gravar o custo da OC no lote** (`lote_custo`, origem `OC`, por item da OC, cotação a conferir quando `manual`). O Recebimento cria o lote RECEBIMENTO sem custo; a unidade de medida diferente gera lote sem custo e sinalizado (D2) | [[API-008-Custo-do-Lote-no-MES]] | 🔴 | `api-pcp/src/compras/compras.service.ts:545` cria o lote; nenhuma outra `loteCusto.create` além da carga inicial (`estoque-operacao.service.ts:440`) e da cisão (`estoque-operacao.helpers.ts:434`) |
| BL-037 | R1 | D11: leitor 2D e posto de recebimento (hardware aprovado, DEC-8). Etiquetas existem no MES | [[05-Recebimento]] | ❓ (etiqueta ✅) | `api-pcp/src/estoque/etiquetas/etiqueta.service.ts`; leitor 2D não conferido |
| BL-012 | R6 | Reabertura de divergência de **produção**: `ABERTA`, `EM_ANALISE`, `RESOLVIDA`, `CANCELADA` sem caminho de volta (a de recebimento tem `REABERTO`) | [[00-Fluxo-Mestre-0b]] | 🔴 | `api-pcp/prisma/models/producao.prisma:77-82` |
| BL-013 | Q3 | **Recompra por RNC**: a parte reprovada volta a Compras; falta contrato e evento do MES para reabrir a compra (`requisicao_reaberta` já é tratado no MES, mas a RNC não o dispara) | sem contrato 🔴 | 🔴 | `qualidade.service.ts:97`; `requisicao-avhub.eventos.ts` trata `requisicao_reaberta` |
| BL-014 | X3 | Consolidar a carga (10.2) | [[09-Expedicao]] | 🔴 | nenhuma tela ou rota de carga em `api-pcp/src/entregas` |
| BL-015 | X4 | Logística de saída: transporte (10.3). O comprovante (10.4) existe | [[09-Expedicao]] | 🔴 | `api-pcp/src/entregas` sem `transportadora` |
| BL-003 | todos | **Módulo `fluxo`**: `fluxo.evento` imutável, `GET /fluxo/eventos`, trilha, tempo, SLA, regra de autorização, instrumentação das transições (I1, I2, I3, I7) | [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas]] | 🔴 | nenhuma pasta `fluxo` em `api-pcp/src`; a `api-test` responde 404 ao job (13/10) |
| BL-032 | transversal | Remover `GET /requisicoes-compra` (003, legado sem consumidor) ou assumir | [[API-003-Requisicao-Compra-Integracao-MES]] | 🔴 | `integracao-avhub.controller.ts:20-24` |
| BL-034 | P2 | Depois de 7 dias o `importado` não é mais reenviado, sem alerta; pedido continua com a marcação editável | [[LOG-26-Vendas-Liberacao-Pedido]] | 🔴 | `api-pcp/src/pedidos/pedidos.service.ts:64-67` |
| BL-035 | transversal | **Merge `develop` para `main`** do `api-pcp` e do `app-pcp` antes do piloto (a `main` parou em 28/08); data e responsável não definidos | 📝 #22 | 🔴 | [[Riscos]] RS-002 |

## Frente Gustavo (banco e API do av-hub)

| ID | Nó | O que falta | Contrato | Selo | Evidência |
|---|---|---|---|---|---|
| BL-025 | V2, V3 | Confirmar em produção `parametros_vendas.data_inicio_liberacao` (01/09 ou 28/07) e as linhas de `auth.rotas_telas` das rotas de liberação | [[LOG-26-Vendas-Liberacao-Pedido]] | ❓ | [[Integracao-AvHub-MES]] INT-01 |
| BL-018 | todos | **Chave de serviço restrita** (L6) para o MES e para o pipeline, no lugar da chave admin; depois fixar as 4 chaves de ambiente restantes | 📝 #10 pendente | 🔴 | `api-acos-vital/src/middlewares/apiKeyAuth.js:52-68,159-165` ([[Chaves-e-Autenticacao]]) |
| BL-002 | C4, R4 | `id_origem` em cada item da `GET /ordens-compra/referencia` (pedido do Robert, 30/09); chave de leitura para o MES (a do 34 dá 403) | [[API-004-Referencia-OC-Integracao-MES]], [[SQL-011-Ordens-Compra-Referencia-MES]] | 🔴 ❓ | rota em `vw_ordens_compra_referencia_mes.route.js:44-89`, sem `id_origem` |
| BL-038 | C2, C3 | **Regra de aprovação da OC:** Gerente de Compras aprova sempre; acima de R$ 30 mil a Diretoria também. Código: abaixo do limite a OC nasce sem aprovação; acima dele, "Aguardando aprovação" por quem tem `pode_aprovar` em `compras` (Gerência); não há degrau da Diretoria nem aprovação do Gerente abaixo do limite | 📝 #50, #50b, DEC-3 | 🔴 | `api-acos-vital/.../ordens_compra.route.js:1235-1238,1252`; `parametros_compras.model.js:16`; `HUB components/Compras/FecharCompra.tsx:605,1652` |
| BL-028 | C0 | Gerar evento do contrato 35 para requisição sem `id_origem` (contraparte de BL-006) | [[LOG-35-Compras-Marcos-Requisicao-para-MES]] | 🔴 | `Dump Avhub (Esqueleto).sql:8587` |
| BL-019 | E3 | **Aplicar a migration 047b**: `fn_itens_pedido_custo_gravar` grava por `item integer` no dump e deve gravar por produto; a API já exige a 047b | [[LOG-47-Custo-Real-por-Item-no-Hub]] | 🔴 | `itens_pedido_custo.job.js:27,157-180` |
| BL-020 | E3 | Perfil com a tela `custo-itens` (a tela nasce sem perfil: 403 a todos) | [[LOG-47-Custo-Real-por-Item-no-Hub]] | 🔴 | `GET /itens_pedido_custo` exige `custo-itens:pode_visualizar` |
| BL-021 | todos | Conceder `torre-fluxo` e `torre-fluxo-trilha` (só o Admin recebeu na 046b) aos perfis certos | [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas]] | 🔴 | migration 046b, `auth.permissoes` |
| BL-029 | todos | Instrumentar eventos do lado do hub (liberação, fechamento de compra, aprovação) em `core_fluxo.evento` | [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas]] | 🔴 | #92 |
| BL-026 | transversal | Marca de origem **manual** do pedido chegar ao MES: pedido manual nunca entra no custo (D6) | [[API-008-Custo-do-Lote-no-MES]] | 🔴 | coluna `manual` protegida ([[Colunas-Protegidas]]) |
| BL-027 | O1 | `exclusionSync` não pode apagar pedido manual (`manual` fora do filtro) | [[LOG-45-Pedido-de-Venda-Manual]] | 🔴 | `omie-elt-pipeline/src/jobs/exclusionSync.ts:103,136` |
| BL-024 | transversal | Versionar o SQL fora do repositório: `fn_requisicao_mes_aplicar` (034), `api004`, `api005`, `api007`, 035b, 046b, 047b; conferir se `api004`, `api005` e `api007` estão no banco de produção | [[SQL-010-Itens-Pedido-Status]], [[SQL-011-Ordens-Compra-Referencia-MES]], [[SQL-012-Ordens-Compra-Referencia-Valores]] | ❓ | repositório `api-acos-vital` não versiona SQL |
| BL-033 | P3 | Comentário "JOB DE POLLING do MES" velho | [[LOG-34-Requisicoes-MES-Empurra-para-o-Hub]] | 🔴 | `requisicoes_compra.route.js:31` |
| BL-030 | transversal | Recurso de **locais de estoque** no pipeline (B6, Passo 6); `lead_time` sai | 📝 #29, #63 | 🔴 | `omie-elt-pipeline/src/omie/resources/estoque.ts:16` (`enabled:false`) |
| BL-039 | transversal | Corrigir `protectedColumns.ts` (comentário de `vendedores` ainda "pendente") e `ARCHITECTURE.md` (nova filial exige `FAMILIA_PADRAO_POR_FILIAL`) | #20, #62 | 🔴 | `protectedColumns.ts:15-24` |

## Frente Nathan (front do av-hub, BFF e coordenação)

| ID | Nó | O que falta | Contrato | Selo | Evidência |
|---|---|---|---|---|---|
| BL-022 | todos | **Telas da Torre** (T.3, T.4, T.5, T.5b) e BFF `/api/fluxo/*`, com fixtures; T.6 Auditoria sem dono | [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas]] | 🔴 | nenhuma ocorrência de `fluxo/torre` ou `torre-fluxo` em HUB b55ac55 |
| BL-023 | E3 | **Tela de custo real por item** (simulador, Ciclo 2) | [[LOG-47-Custo-Real-por-Item-no-Hub]] | 🔴 | nenhuma ocorrência de `custo-itens` ou `itens_pedido_custo` no HUB |
| BL-040 | C2, C3 | Tela de Aprovações da OC: refletir o degrau da Diretoria acima de R$ 30 mil junto com BL-038 | 📝 #50b | 🔴 | `HUB components/Compras/FecharCompra.tsx:1648-1656` |
| BL-041 | C0 | "Nova requisição" cria requisição que não chega ao MES: aviso na tela até BL-006 resolver | [[04-Circuito-de-Compra]] | 🟡 | `HUB app/api/compras/requisicoes/route.ts:80` |
| BL-048 | todos | Teste ponta a ponta do cartão "Etapa dos itens" com a `api005` aplicada (`quantidade_na_etapa` pode vir `null`, tipado `number`) | [[API-006-Status-por-Item-Leitura-no-Hub]] | ❓ | `HUB components/Pedidos/EtapaDosItens.tsx`, `PedidoDetalhe.tsx` |
| BL-042 | transversal | Reauditar BFF: todo helper manda `Authorization: Bearer` (PR #178 cobriu os helpers; o restante não foi reauditado) | #88 | ❓ | `HUB lib/api/escopoUnidade.ts:45` |
| BL-043 | transversal | Remover marcas `GAMBIARRA(` do escopo de vendedores e do login depois que a API fixou as regras (contratos 40, 41, 50); 11 marcas no HUB em 14/10 | [[LOG-50-Tirar-as-Marcas-de-Escopo-de-Vendedores-do-Front]] | 🔴 | `HUB lib/api/pedidosVenda.ts:15`, `lib/api/portalPcp.ts:51`, `lib/auth/loginRateLimiter.ts:24` |
| BL-044 | transversal | Contratos com dono indefinido: reescrever o 38 §6 e o 07 (orçamento por fora) | #60 | 🔴 | [[Pontas-Soltas]] PS-005 |
| BL-045 | transversal | Vincular compradores a funcionários antes da primeira OC real (só importam os 32 ativos; 20 de 74 vinculados em 07/10) | 📝 #51 | ❓ | [[Omie-Integracao-Estado]] |

## Frente Pablo (Comercial & Suprimentos)

O módulo `api-comercial` (Express 5, Prisma, schema `core_comercial`, BFF `app/api/comercial/[...rota]/route.ts`) é independente do fluxo 0b e está no [[Comercial-Suprimentos]]. Pendências ligadas ao fluxo:

| ID | Nó | O que falta | Selo | Evidência |
|---|---|---|---|---|
| BL-046 | C1, C4 | Relação entre o orçamento do módulo comercial e a OC/cotação de Compras (decisão #39: orçamento é por fora) | 🔴 | `HUB api-comercial/README.md` |
| BL-047 | C4 | Sincronização Omie do módulo (produtos, fornecedores, pedidos de compra) coexiste com o pipeline: não duplicar o espelho `pedidos_compras` | ❓ | `HUB api-comercial/README.md` |

## Ordem sugerida (caminho crítico)

1. Gustavo: BL-018 (chave), BL-002 (`id_origem` e chave de leitura), BL-019 (047b), BL-024 (SQL versionado). Destravam o Robert.
2. Robert: BL-001 e BL-005 (OC e custo no recebimento), BL-004 (`itens/custo`), BL-007 e BL-008 (retirada e fabricado no Estoque), BL-003 (fluxo).
3. Nathan: BL-022 e BL-023 sobre fixtures enquanto o MES publica; BL-038 e BL-040 com o Gustavo.
4. Antes do piloto: BL-035 e RS-002.

A capacidade do Robert está em déficit de 16,1 pd no Ciclo 1 ([[Equipe-e-Divisao]], [[Riscos]] RS-004): a baixa no despacho do Estoque (BL-007) não tem pd dimensionado.
