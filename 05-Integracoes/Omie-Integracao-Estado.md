---
tags: [omie, pipeline, integracao, estado]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Gustavo (DBA)
fontes: [omie-elt-pipeline 0f739f0, v1 08-Integracao-Omie (Indice, Arquitetura-do-Pipeline, Contradicao-CFOP, Colunas-Protegidas), Registro-de-Decisoes #5 #7 #15 #16 #17 #18 #19 #20 #28 #29 #30 #31 #63, api-acos-vital f322dcd]
---

# Omie: estado da integração

O Omie é o sistema **fiscal e financeiro** e segue assim, sem plano de desligar 📝 ([[Registro-de-Decisoes]] #30, DEC-11). O sistema nunca emite nota fiscal. O MES nunca fala com o Omie. O pipeline (`omie-elt-pipeline`) é **EL, não ETL**: extrai do Omie e grava no Postgres do av-hub; a regra de negócio fica em views e triggers do banco. Dicionário campo a campo de cada tabela: [[Pedidos-de-Venda]], [[Notas-Fiscais-e-Itens]], [[Parceiros-Clientes-Fornecedores]], [[Produtos-e-Familias]], [[Vendedores]], [[Etapas-Faturamento]]. Detalhe técnico do código: [[Pipeline-Omie]]. Colunas que o pipeline não escreve: [[Colunas-Protegidas]].

## Onde o Omie aparece no fluxo 0b

| Nó | O que | Direção | Estado |
|---|---|---|---|
| V1 | Pedido criado no Omie chega ao av-hub travado | Omie para pipeline para `pedidos_vendas` | ✅ `ListarPedidos`, a cada 3 min para o dia |
| C4 | OC emitida no av-hub é enviada ao Omie | av-hub para pipeline para Omie | ✅ `UpsertPedCompra` |
| C4 | Pedidos de compra do Omie voltam como espelho | Omie para `pedidos_compras` | ✅ `PesquisarPedCompra` |
| O1 | Omie emite a NF | Omie para `notas_fiscais` | ✅ lado Omie; sinalização do MES ao Omie (tela 11.1) 🔴 |
| O2 | Omie baixa o item no pedido | Omie para `pedidos_vendas`, `produto_vendas` | ✅ lado Omie |

## Recursos de leitura (todos conferidos em `omie/resources/*.ts`, 0f739f0)

| Recurso | Método Omie | Destino | `enabled` |
|---|---|---|---|
| `parceiros` | `ListarClientes` | `core.parceiros`, `core.tipos_parceiro`, `core.parceiros_tipos` | true |
| `produtos` | `ListarProdutos` | `core.produtos` | true |
| `familiaProdutos` | `PesquisarFamilias` | `core.familia_produtos` | true |
| `vendedores` | `ListarVendedores` | `core_vendas_faturamento.vendedores` | true |
| `pedidosVendas` | `ListarPedidos` | `pedidos_vendas` e itens em `produto_vendas` | true |
| `produtoVendas` | (sem `listMethod`) | gravado como efeito de `pedidosVendas` | true |
| `notasFiscais` | `ListarNF` | `core_vendas_faturamento.notas_fiscais` | true |
| `etapasFaturamento` | `ListarEtapasFaturamento` | `core.etapas_faturamento` | true |
| `pedidosCompras` | `PesquisarPedCompra` (`lApenasAlterados=T`) | `pedidos_compras`, `_itens`, `_parcelas` (REPLACE-ALL por pedido) | true |
| `compradores` | `ListarCompradores` | `core_vendas_faturamento.compradores` | true |
| `condicoesPagamentoCompras`, `projetos`, `contasCorrentes`, `categorias` | catálogos | `condicoes_pagamento_compras`, `core.projetos`, `core.contas_correntes`, `core.categorias` | true (camadas lentas) |
| `estoque` | `ListarPosEstoque` | nenhum | **false** |

Não são Omie: PTAX (API do BCB, `core.cotacoes_moeda`, 13:30 e 17:30 seg a sex, só boletim Fechamento) e o scraping do relatório de manifestação do destinatário (`core_vendas_faturamento.manifestos`).

**Decisões que fecham escopo:** saldo do Omie não será habilitado, o estoque dele é ignorado e o MES é a referência do saldo físico 📝 #28; `lead_time` sai do pipeline 📝 #29; B6 segue só com **locais de estoque**, sem recurso no pipeline ainda 🔴 BL-030 (#63); remessa e devolução são do Ciclo 2 (22/01/2027) 📝 #27, #31; endereço de entrega e dados bancários de parceiro ficam fora 📝 #30.

## Única escrita no Omie: envio da OC

- `UpsertPedCompra` (reenvio altera, não duplica: `cCodIntPed` = número da OC) e `ExcluirPedCompra` ✅ `omie-elt-pipeline/src/jobs/envioOrdensCompra.ts:25-26,132`. Sem parcelas (só `cCodParc`/`nQtdeParc`).
- Fixo no código, sem `SYNC_ENVIO_OC` nem `ENVIO_OC_DRY_RUN` ✅ (`src/config/index.ts:155-156`; PR #3, 0f739f0) 📝 #7. Cron `1-59/2 * * * *` (`config/index.ts:159`). Riscos L10.1, L10.6 (FOB) e L10.7 (b) a (d): aceitos 📝.
- A fila e o retorno passam pela API do av-hub: `GET /compras/ordens/fila-omie`, `PATCH /compras/ordens/:id/sincronizacao`, `POST /compras/ordens/:id/reenviar` ([[Chaves-e-Autenticacao]], chave C).
- Falta antes do uso real: deploy da API com o contrato 36 e compradores vinculados (20 de 74 vinculados em 07/10; só importam os 32 ativos) 🔴 Nathan ([[Pontas-Soltas]] PS-009).

## Processos e jobs

6 processos PM2: `extract-worker`, `load-worker`, `scheduler`, `scraping-worker`, `envio-oc-worker`, `dashboard` (Bull Board, porta 3011). Roda na VPS 1; o banco, na VPS 2 📝 #4 ([[Infraestrutura]]). Cada filial é uma conta Omie (`FILIAL_<CHAVE>_OMIE_APP_KEY/SECRET/CODIGO_EMPRESA`, `FILIAIS_ATIVAS`).

| Job | Cron ou regra | Selo |
|---|---|---|
| sync de hoje | `*/3 * * * *` (`config/index.ts:89`) | ✅ |
| sync do mês | `2,22,42 * * * *` (`:94`) | ✅ |
| sync dos últimos meses | `7 */3 * * *` (90 dias) | ✅ |
| full sync | `17 3 * * *` | ✅ |
| exclusão curta | `12,32,52 * * * *` (`:110`), 60 dias, só `pedidosVendas`, apaga de verdade | ✅ risco RS-001 |
| exclusão ampla | `27 4 * * *`, 180 dias | ✅ |
| geocodificação | `37 5 * * *` | ✅ |
| monitor de pool | `*/2 * * * *` (`:132`) | ✅ |
| PTAX | `30 13,17 * * 1-5` (America/Sao_Paulo), carga desde 2026-01-01 se vazio | ✅ |
| inativar catálogos | `47 4 * * *`; não age se o Omie devolver menos da metade dos ativos | ✅ |
| envio de OC | `1-59/2 * * * *` | ✅ |
| scraping do manifesto | seg a sex 07h às 18h, cerca de 1 h ± 25 min, só Mogi | ✅ ❓ produção |

Os crons dos jobs mais antigos ainda lêem variável de ambiente com padrão no código (`config/index.ts`). A regra do Nathan de nada em variável de ambiente vale para jobs novos.

## O que está aberto

| Item | Dono | Ref |
|---|---|---|
| `exclusionSync` apaga pedido manual (`manual` não filtrado) | Gustavo | RS-001, BL-027, #15 |
| 500 em `exclusion_sync_curta` (497 erros em Mogi, 490 HTTP 500): causa em `omie_ctl.run_log` | Gustavo | PS-020, #16 |
| Pedido de compra apagado por fora no Omie não é detectado: limitação aceita | Nathan | #17 🟡 |
| Camada raw removida em 06/10 (contrato 38); `sql/002` obsoleto, `DROP` das 5 tabelas `omie_raw.*` | Nathan marca, Gustavo apaga | PS-021, #18 |
| Manifesto: o login de Mogi traz as duas empresas; confirmar linhas de Uberaba; HRM não coberta | Gustavo | PS-022, #19 |
| `FAMILIA_PADRAO_POR_FILIAL` hardcoded para mogi e uberaba; corrigir `ARCHITECTURE.md` | Gustavo | PS-016, #20 |
| Locais de estoque (B6) sem recurso | Gustavo | BL-030, #63 |
| Frete, parcelas e desconto do PV no pipeline | Gustavo | 🔴 sem decisão |
| BENAFER (pedidos 44333 e 44568, R$ 82,7 mi) e nomes das etapas 10, 15, 20 de `pedidos_compras` | Nathan | #52, adiado |
| Dump de 07/10: 22.808 pedidos de compra, etapas 10/15/20 = 1.186, 20.380 e 1.242 | | ❓ produção |

## Contradição CFOP (resolvida)

A modelagem anterior afirmava que CFOP e ICMS-ST não eram capturados. O pipeline **captura CFOP por item** em `produto_vendas.cfop`, validado contra a whitelist `core_vendas_faturamento.cfop` (cache de 10 min) ✅ ([[Pedidos-de-Venda]]). Só o ICMS-ST segue sem captura. Não existe CFOP da nota inteira. Registro em [[Contradicoes-Resolvidas]] CR-19.

## Dados que o MES recebe do Omie

O MES não lê o Omie. O que ele precisa do Omie chega pelo av-hub: pedido liberado, produtos e unidades ([[Integracao-AvHub-MES]]). `codigo_projeto` e `numero_contrato` do pedido estão no av-hub sem uso no MES.

Ver também: [[Sistemas-e-Responsabilidades]], [[10-Fiscal-Omie]].
