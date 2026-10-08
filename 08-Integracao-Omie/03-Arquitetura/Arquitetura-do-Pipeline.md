---
tags: [integracao-omie, arquitetura]
criado: 2026-09-17
atualizado: 2026-10-07
---

# Arquitetura do `omie-elt-pipeline` (resumo técnico)

> Status: decidido (envio de OC, FAMILIA_PADRAO_POR_FILIAL, estoque do Omie) | no código (leitura de `master` d2886bf) | em produção (verificado em 07/10/2026 só pelo dump; ver [[Auditoria-Dump-Producao-2026-10-07]]). Decisões em [[Registro-de-Decisoes-2026-10-07]].

> **Atualização de 07/10/2026 — camada raw removida, endpoints e processos completados.** Fonte: leitura de código (`master` d2886bf, 06/10), **não** produção/deploy. (1) A camada `omie_raw.*`/`RAW_AUDIT_ENABLED` foi **removida em 06/10 (contrato 38)**; (2) a tabela de endpoints passou de 8 para 16 linhas (Compras, PTAX do BCB, envio de OC, scraping); (3) o pipeline tem **6 processos**, não 3; (4) o pipeline deixou de ser só leitura: **envia OC ao Omie**. Detalhe completo na nota de modelagem [[Omie-ELT-Pipeline]].

Complementa a nota já existente na seção de modelagem ([[Omie-ELT-Pipeline]]) com o essencial para entender de onde vêm os campos listados nos arquivos de dados extraídos ([[Parceiros-Clientes-Fornecedores]], [[Produtos-e-Familias]], [[Vendedores]], [[Pedidos-de-Venda]], [[Notas-Fiscais-e-Itens]], [[Etapas-Faturamento]]).

## EL, não ETL

Node.js/TypeScript. `extract-worker` e `load-worker` (BullMQ + Redis), orquestrados por `scheduler.ts` (node-cron) em camadas de sincronização por janela (hoje `*/3 * * * *` / mês `2,22,42 * * * *` / últimos 90 dias `7 */3 * * *` / full sync diário `17 3 * * *`) mais limpeza por exclusão. Escreve direto nas tabelas de negócio (`core.*`, `core_vendas_faturamento.*`) via upsert idempotente (`pg`, sem ORM) — a transformação/regra de negócio fica deliberadamente do lado do banco (views/triggers), não deste pipeline.

**Única escrita no Omie (atualizado em 07/10):** o envio de Ordem de Compra (`UpsertPedCompra`/`ExcluirPedCompra`), pelo `envio-oc-worker`. **Decidido em 07/10 (✅, [[Registro-de-Decisoes-2026-10-07]] #7):** o envio fica **fixo no código** e vai direto ao Omie, sem `SYNC_ENVIO_OC` nem `ENVIO_OC_DRY_RUN`; o Nathan rodou cerca de 4 testes reais e a OC entrou. L10.1, L10.6 (FOB `"1"`) e L10.7 (b) a (d) viram **risco aceito**. Alteração de código: Gustavo. ~~Só é agendado com `SYNC_ENVIO_OC=true`; o default do código é `false`, com `ENVIO_OC_DRY_RUN=true`.~~ (superado: descreve o código de 06/10, antes da mudança.)

**Onde roda:** o pipeline roda na **VPS 1** (o banco fica na VPS 2), conforme #4 do registro.

## Processos (atualizado em 07/10)

A versão original citava só `extract-worker`, `load-worker` e `scheduler`. Hoje o PM2 tem 6 apps (o compose = Redis + os mesmos 6; Postgres de fora):

| App | Papel |
|---|---|
| `extract-worker` | extrai do Omie |
| `load-worker` | grava no Postgres (concorrência 40/10, `PG_POOL_MAX=60`) |
| `scheduler` | crons das camadas e dos jobs avulsos |
| `scraping-worker` | scraping do manifesto (Chromium, `Dockerfile.scraping`) |
| `envio-oc-worker` | envio de OC ao Omie (fila `omie-envio-oc`) |
| `dashboard` | Bull Board, porta 3011, basic auth; 5 filas: `omie-extract`, `omie-load`, `omie-load-realtime`, `omie-query`, `omie-envio-oc` |

Multi-filial: cada filial é uma conta Omie (`FILIAL_<CHAVE>_OMIE_APP_KEY/SECRET/CODIGO_EMPRESA`), `FILIAIS_ATIVAS` roda em paralelo no mesmo processo, com limitador por filial+método. Hoje `mogi` e `uberaba` no `.env.example`; a HRM tem conta própria, mas ligá-la exige uma entrada hardcoded em `FAMILIA_PADRAO_POR_FILIAL` (`produtos.ts`) — contradiz o "nenhum código muda" do `ARCHITECTURE.md` `[inferido]`. **Decidido (✅, #20):** é **tarefa de código** (Gustavo) e o `ARCHITECTURE.md` do pipeline (fora do vault) deve ser corrigido, porque diz que nova filial não muda código. Ver [[Omie-ELT-Pipeline]].

## ~~Camada de auditoria opcional (raw)~~ — removida em 06/10/2026

> **Removida (atualizado em 07/10).** O que esta seção descrevia — schema `omie_raw.*` (uma tabela por recurso principal: `produtos`, `parceiros`, `vendedores`, `pedidosVendas`, `notasFiscais`, com `omie_id`, `filial`, `payload jsonb`, `ingested_at`, `source`), desabilitado por padrão via `RAW_AUDIT_ENABLED=false` — **não existe mais no código**: o contrato 38 (d6abf04) removeu `RAW_AUDIT_ENABLED` e o `upsertRawAudit`. O `sql/002` (as 5 tabelas) ficou como lixo morto. Histórico: a camada servia só para debug/reprocessamento e nada lia dali. A sugestão antiga de "habilitar o staging raw para inspecionar o JSON completo" **deixou de ser possível**; para ver campos não mapeados, a rota é a documentação oficial da API (ver [[Perguntas-em-Aberto]]) ou uma chamada pontual.

## Log de execução (não é dado de negócio)

`omie_ctl.run_log` (`sql/003`) — uma linha por execução de sync layer/resource/filial, com contagem de registros e erro, só para diagnóstico operacional. É **a única tabela própria do pipeline** que continua ativa.

## Endpoints usados (atualizado em 07/10)

Leitura do Omie:

| Endpoint Omie | Resource | Destino |
|---|---|---|
| `ListarClientes` | `parceiros.ts` | `core.parceiros` (agora com dados fiscais), `core.tipos_parceiro`, `core.parceiros_tipos` |
| `ListarProdutos` | `produtos.ts` | `core.produtos` |
| `PesquisarFamilias` | `familiaProdutos.ts` | `core.familia_produtos` |
| `ListarVendedores` | `vendedores.ts` | `core_vendas_faturamento.vendedores` |
| `ListarPedidos` | `pedidosVendas.ts` | `core_vendas_faturamento.pedidos_vendas` + `produto_vendas` (itens embutidos) |
| `ListarNF` | `notasFiscais.ts` | `core_vendas_faturamento.notas_fiscais` (+ UPDATE em `produto_vendas`) |
| `ListarEtapasFaturamento` | `etapasFaturamento.ts` | `core.etapas_faturamento` (ver [[Etapas-Faturamento]]; `enabled:true` no código) |
| `PesquisarPedCompra` (`lApenasAlterados=T`) | `pedidosCompras` | `pedidos_compras` + `_itens` + `_parcelas` (itens/parcelas em REPLACE-ALL por pedido) |
| `ListarCompradores` | `compradores` | `core_vendas_faturamento.compradores` (só camadas lentas) |
| condições de pagamento de compras | `condicoesPagamentoCompras` | `condicoes_pagamento_compras` (só camadas lentas) |
| projetos | `projetos` | `core.projetos` (só camadas lentas) |
| contas correntes | `contasCorrentes` | `core.contas_correntes` (só camadas lentas) |
| categorias | `categorias` | `core.categorias` (só camadas lentas) |
| `ListarPosEstoque` | `estoque.ts` | nenhum — `enabled:false`, `table:null` ("sem tabela de destino" no próprio arquivo). **Decidido: não será feito** (✅, #28: o Omie recebe dados só manualmente e o estoque do Omie é ignorado) |
| PTAX — API de cotações do **BCB** (não é Omie) | `jobs/cotacaoPtax.ts` | `core.cotacoes_moeda` (só boletim Fechamento, fonte `PTAX_BCB`) |
| scraping do relatório de UI do Omie (não é API) | `scraping-worker` | `core_vendas_faturamento.manifestos` |

Escrita no Omie (única):

| Endpoint Omie | Quem chama | Observação |
|---|---|---|
| `UpsertPedCompra` | `jobs/envioOrdensCompra.ts` / `omie/ordemCompraOmie.ts` | `cCodIntPed = numero_pedido`; **sem parcelas** (só `cCodParc`/`nQtdeParc`); não usa `IncluirPedCompra` |
| `ExcluirPedCompra` | idem | "não encontrado" conta como excluído |

Fila e retorno do envio passam pela API do av-hub (`GET /compras/ordens/fila-omie`, `PATCH /compras/ordens/{id}/sincronizacao`) — ver [[Chaves-de-Integracao-AvHub-MES-Pipeline]]. O nome do método de cada catálogo de Compras (exceto `PesquisarPedCompra` e `ListarCompradores`) não consta da ficha de auditoria e não é repetido aqui.

`produtoVendas` é registrado como recurso mas **não tem `listMethod`**: é gravado como efeito colateral de `pedidosVendas`. Total: 15 recursos registrados, 14 ligados.

## Jobs fora dos recursos (novo em 07/10)

| Job | Cron | Observação |
|---|---|---|
| exclusão curta | `12,32,52 * * * *` | 60 dias, só `pedidosVendas`, apaga de verdade. **Risco crítico (🔴 Gustavo, #15):** o `DELETE` por empresa e janela **não filtra `manual`** (`exclusionSync.ts`, consulta de excluídos em ~98-106 e `DELETE` em ~136); pedidos manuais têm `codigo_pedido_omie` negativo, não existem no Omie e entram na lista de excluídos. Confirmar antes de usar pedido manual em produção |
| exclusão ampla | `27 4 * * *` | 180 dias (mesmo risco da exclusão curta quanto a pedidos manuais) |
| geocodificação | `37 5 * * *` | preenche `latitude_y`/`longitude_x` |
| monitor de pool | `*/2 * * * *` | diagnóstico |
| PTAX | `30 13,17 * * 1-5` (America/Sao_Paulo) + ao subir | carga inicial desde 2026-01-01 se a tabela estiver vazia |
| inativar catálogos | `47 4 * * *` | `ativo=false` nos 5 catálogos de Compras que sumiram do Omie; não age se o Omie devolver menos da metade dos ativos |
| envio de OC | `1-59/2 * * * *` | decisão de 07/10 (#7): fixo no código — **no código de 08/10 ainda só agenda com `SYNC_ENVIO_OC=true` (padrão `false`) e começa em dry run (`ENVIO_OC_DRY_RUN=true`)** |
| scraping de manifesto | `setTimeout` auto-reagendado, seg–sex 07–18h, ~1h ±25 min | só Mogi; 2FA por TOTP local |

## Ver também
- [[Omie-ELT-Pipeline]] (seção de modelagem — contexto completo: incidentes, decisões rejeitadas, scraper de manifesto)
- [[Etapas-Faturamento]]
- [[Perguntas-em-Aberto]]
- [[Roteiro-de-Implementacao]]
