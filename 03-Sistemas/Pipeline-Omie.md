---
tags: [sistemas, pipeline, omie, elt, bullmq, redis]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Gustavo (DBA)
fontes: [omie-elt-pipeline 0f739f0 (master), README.md, ARCHITECTURE.md, src/config/index.ts, src/jobs/*, src/omie/resources/*, src/workers/*, ecosystem.config.cjs, v1 Omie-ELT-Pipeline]
---

# Pipeline Omie (`omie-elt-pipeline`)

**Em uma frase:** é o serviço que copia os dados do Omie (o ERP, sistema de gestão da empresa) para o banco do av-hub, a cada poucos minutos. Só a ordem de compra faz o caminho contrário, do av-hub para o Omie. Dono: Gustavo (DBA).

## Quem usa e para quê

- **Vendas e Fiscal:** recebem no av-hub os pedidos e as notas fiscais do Omie.
- **Compras:** a OC aprovada vai ao Omie sem digitação.
- **Todo o av-hub:** usa produtos, parceiros, vendedores, projetos e cotação do dólar e do euro.
- **Gustavo:** mantém o serviço no ar.

## Como se encaixa no fluxo

- **`V1`:** o pedido de venda do Omie chega ao av-hub **travado**. A liberação é do vendedor ([[01-Vendas-Liberacao]]).
- **`O1` e `O2` (lado Omie):** a nota fiscal emitida volta para o av-hub.
- **Compras (`C4`):** a OC aprovada é enviada ao Omie e o resultado volta ao av-hub.
- **Estoque:** o saldo da fábrica vive no MES, não no Omie. Por isso esse recurso está desligado.

## Regras que valem

- O Omie não avisa quando algo muda. O serviço consulta por janela de datas, de 3 em 3 minutos o dia atual.
- Ele nunca escreve nas colunas protegidas do banco ([[Colunas-Protegidas]]).
- A única escrita no Omie é enviar ou excluir OC.
- Reenviar uma OC altera a que já existe, sem duplicar.
- Se o Omie recusar a OC, ela fica com erro até alguém clicar em "Reenviar" no HUB. Depois de 3 recusas seguidas, a rodada da unidade para.
- Só a condição de pagamento vai ao Omie, nunca as parcelas.
- O Omie não tem ambiente de teste. Os cadastros TESTE (fornecedor, cliente, transportadora) existem de verdade e chegam às listas e aos relatórios.

## O que já existe e o que falta

- ✅ Extração de pedidos, notas, produtos, parceiros, vendedores, compras e catálogos.
- ✅ Envio da OC testado pelo Nathan em 14/10. Em produção ❓ (checklist PS-009).
- 🔴 Ao subir o worker, a pipeline escreve no Omie de verdade. Antes de publicar: contrato 36 na API e compradores vinculados.
- 🔴 Apagar as 5 tabelas e o schema `omie_raw`, obsoletos desde N14-27 (BL-054). É do Gustavo.
- 🟡 Filtrar os cadastros TESTE em relatórios e conferências (BL-055).
- 🟡 Comentários velhos no repositório dizem que o envio da OC não está feito.
- 🟡 Pedido apagado e recriado com o mesmo sequencial colide no banco. O `pedidoAutoHeal` resolve.
- ❓ A demora real entre criar o pedido no Omie e ele aparecer na caixa de liberação não foi medida.

## Detalhe técnico

Serviço que traz os dados do Omie para o banco do av-hub e, só para a OC, escreve de volta no Omie. Node + TypeScript, BullMQ sobre Redis, `pg` direto no PostgreSQL do av-hub, PM2 em produção ✅ `package.json`, `ecosystem.config.cjs`. Branch de produção: `master` (0f739f0). Dono: Gustavo (DBA). Não há webhook do Omie: tudo é polling por janela de calendário ✅ `src/config/index.ts:81-86`, `ARCHITECTURE.md:60`. Estado da integração Omie como um todo: [[Omie-Integracao-Estado]]. Colunas que o sync nunca escreve: [[Colunas-Protegidas]]. Selos: [[Regras-do-Vault]].

### Processos (PM2, `ecosystem.config.cjs`)

| Processo | Script | Papel | Concorrência |
|---|---|---|---|
| `omie-scheduler` | `dist/jobs/scheduler.js` | só enfileira (crons) | — |
| `omie-extract-worker` | `dist/workers/extractWorker.js` | chama a API do Omie, respeitando o limite por IP+AppKey+método (padrão 3 simultâneas e 200/min por método) | 4 e 2 (duas filas) ✅ `extractWorker.ts:54,114` |
| `omie-load-worker` | `dist/workers/loadWorker.js` | upsert no PostgreSQL | `LOAD_WORKER_CONCURRENCY` (20) e `LOAD_WORKER_REALTIME_CONCURRENCY` (5) ✅ `loadWorker.ts:254,269` |
| `omie-scraping-worker` | `dist/workers/scrapingWorker.js` | Playwright: relatório de manifestação (destinatário) do portal Omie, 1x/dia | próprio |
| `omie-envio-oc-worker` | `dist/workers/envioOcWorker.js` | **única escrita no Omie**: envia e exclui OC | 1 (fila `omie-envio-oc`) ✅ `envioOcWorker.ts:20`, `queue/index.ts:111` |
| `omie-dashboard` | `dist/dashboard/index.js` | Bull Board (HTTP + Redis) | — |

Todos reiniciam sozinhos, com backoff exponencial e `max_restarts` de 1 000 000 ✅ `ecosystem.config.cjs:17-24`. O comentário do `omie-envio-oc-worker` no mesmo arquivo ("ocioso enquanto SYNC_ENVIO_OC=false") está velho: o envio é fixo desde 07/10 ✅ `config/index.ts:154-163`.

### Camadas de sync (todas as filiais, todos os recursos ligados)

| Camada | Cron padrão | Variável | Janela |
|---|---|---|---|
| Hoje | `*/3 * * * *` | `SYNC_HOJE_CRON` | dia atual |
| Mês corrente | `2,22,42 * * * *` | `SYNC_MES_CRON` | dia 01 até hoje |
| Últimos meses | `7 */3 * * *` | `SYNC_ULTIMOS_MESES_CRON`, `SYNC_ULTIMOS_MESES_WINDOW_DAYS` (90) | 90 dias |
| Full sync | `17 3 * * *` | `FULL_SYNC_CRON` | catálogo sem limite; pedidos e NF em 365 dias (`FULL_SYNC_PEDIDOS_WINDOW_DAYS`, `FULL_SYNC_NF_WINDOW_DAYS`) |
| Exclusão curta | `12,32,52 * * * *` | `EXCLUSION_SYNC_CURTA_CRON`, `…_WINDOW_DAYS` (60) | pedidos apagados no Omie |
| Exclusão ampla | `27 4 * * *` | `EXCLUSION_SYNC_CRON`, `…_WINDOW_DAYS` (180) | idem |
| Geocodificação | `37 5 * * *` | `GEOCODE_PARCEIROS_CRON` | parceiros "Cliente" sem coordenada (Nominatim) |
| Monitor de pool | `*/2 * * * *` | `POOL_MONITOR_CRON` | conexões "idle in transaction" |
| PTAX | `30 13,17 * * 1-5` (Brasília) | `COTACAO_PTAX_CRON`, `PTAX_MOEDAS` (USD, EUR), `PTAX_JANELA_DIAS` (7), `PTAX_CARGA_INICIAL_DESDE` (2026-01-01) | boletim de fechamento do Banco Central; carga inicial ao subir se a tabela está vazia |
| Inativar catálogos | `47 4 * * *` | `INATIVAR_CATALOGOS_CRON` | o que sumiu do Omie vira `ativo = false` |
| Envio da OC | `1-59/2 * * * *` | `ENVIO_OC_CRON`, `ENVIO_OC_LOTE` (20 por unidade) | fila de OCs |

Fonte: ✅ `src/config/index.ts:89-159`, `src/jobs/scheduler.ts:25-130`. Por que janela fixa e não watermark: o Omie só filtra pedido e NF por data de inclusão/emissão, nunca por alteração ✅ `config/index.ts:81-88`.

### Recursos extraídos (`src/omie/resources/index.ts`)

| Recurso | Método Omie | Tabela destino | Ligado |
|---|---|---|---|
| `produtos` | `ListarProdutos` | `core.produtos` | ✅ |
| `parceiros` | `ListarClientes` | `core.parceiros` | ✅ |
| `vendedores` | `ListarVendedores` | `core_vendas_faturamento.vendedores` | ✅ |
| `pedidosVendas` | `ListarPedidos` (endpoint `/produtos/pedido/`) | `core_vendas_faturamento.pedidos_vendas` | ✅ **nó V1** |
| `notasFiscais` | `ListarNF` (`/produtos/nfconsultar/`) | `core_vendas_faturamento.notas_fiscais` | ✅ **nó O1/O2 (lado Omie)** |
| `produtoVendas` | sem `listMethod`: sai de dentro de `pedidosVendas`/`notasFiscais` | `core_vendas_faturamento.produto_vendas` | ✅ |
| `familiaProdutos` | `PesquisarFamilias` | `core.familia_produtos` | ✅ |
| `etapasFaturamento` | `ListarEtapasFaturamento` | `core.etapas_faturamento` | ✅ |
| `compradores` | `ListarCompradores` | `core_vendas_faturamento.compradores` | ✅ |
| `pedidosCompras` | `PesquisarPedCompra` (paginação `nPagina`) | `core_vendas_faturamento.pedidos_compras` (+ itens e parcelas em tabelas próprias) | ✅ |
| `condicoesPagamentoCompras` | `ListarFormasPagCompras` | `core_vendas_faturamento.condicoes_pagamento_compras` | ✅ |
| `projetos`, `contasCorrentes`, `categorias` | `ListarProjetos`, `ListarContasCorrentes`, `ListarCategorias` | `core.projetos`, `core.contas_correntes`, `core.categorias` | ✅ |
| `estoque` | `ListarPosEstoque` | nenhuma (`table: null`; a tabela `core.estoque_saldo` existe no banco, sem sync) | **desligado** (`enabled: false`) ✅ `resources/estoque.ts:16,32` |

Os catálogos de Compras (condições, projetos, contas, categorias, compradores) rodam só na camada "últimos meses" e no full sync (`somenteCamadaLenta`) ✅ README `:118-120`. `core.estoque_saldo` fica vazia: **o saldo do Estoque da fábrica vive no MES**, não no Omie ([[Modelo-Estoque-e-Custo-do-Lote]]).

O pedido de venda entra no av-hub **travado** (sem marcação de liberação); a liberação é do vendedor ([[01-Vendas-Liberacao]]). O pipeline nunca escreve em `pedidos_vendas.manual` nem nas outras colunas protegidas ✅ `src/db/protectedColumns.ts:50-58`.

### Envio da OC ao Omie (única escrita)

1. A cada 2 minutos o scheduler enfileira a rodada; o `envio-oc-worker` faz, por unidade, `GET {AVHUB_API_URL}/compras/ordens/fila-omie?codigo_empresa=` ✅ `src/avhub/client.ts:1-13`, `jobs/envioOrdensCompra.ts:17-26`.
2. `acao: "enviar"` (OC `aprovado` com `status_sincronizacao_omie = pendente`) vira `UpsertPedCompra` com `cCodIntPed` = número da OC (reenvio altera, não duplica). `acao: "excluir"` (OC cancelada que já estava no Omie) vira `ExcluirPedCompra` ✅ `envioOrdensCompra.ts:19-26`; a fila vem de `api-acos-vital` `ordens_compra.route.js:857-891`.
3. Resultado em `PATCH {AVHUB_API_URL}/compras/ordens/{id}/sincronizacao` (`nCodPed`, `cNumero` ou erro) ✅ `envioOrdensCompra.ts:27-33`.
4. Recusa do Omie marca `erro` e a OC sai da fila até alguém clicar em "Reenviar" no HUB; rede, 429/425 e "aguarde N segundos" deixam pendente. Depois de 3 recusas seguidas (`MAX_RECUSAS_SEGUIDAS`) a rodada da unidade para ✅ `:41-47`.
5. Só vai a condição de pagamento (`cCodParc`), nunca as parcelas; todo item precisa de produto do cadastro da unidade (`nCodProd`) ✅ README `:153-158`. O bloco `[AV-HUB]` do `cObsInt` leva o "Destino:" por PV (campos separados por ` ; `, porque o `|` é quebra de linha no Omie).
6. Modo de teste: `npm run envio-oc -- --dry-run` (monta o payload e não envia) ✅ README `:143-145`.
7. ✅ **Testado pelo Nathan em 14/10: o envio real funciona em teste;** produção ❓ (checklist de subida: PS-009). O Omie **não tem ambiente de teste**, então o Nathan criou cadastros **TESTE** (fornecedor, cliente e transportadora) no Omie de verdade. A pipeline lê esses cadastros como quaisquer outros e eles chegam ao av-hub, às listas e aos relatórios (por exemplo o CON-01). 🟡 Filtrar ou ignorar os cadastros TESTE em relatórios e conferências (BL-055); a pipeline não os distingue.

### `sql/002` e `omie_raw` (obsoletos)

- `sql/002_staging_tables.sql` cria 5 tabelas de staging `jsonb` em `omie_raw` (`produtos`, `parceiros`, `vendedores`, `"pedidosVendas"`, `"notasFiscais"`) e era **opcional**: só servia a `RAW_AUDIT_ENABLED=true` ✅ `sql/002_staging_tables.sql:1`.
- **Marcado obsoleto pelo Nathan em 14/10 (N14-27).** A auditoria foi removida do código no contrato 38: `ARCHITECTURE.md:41` e `:256-257` dizem que as tabelas de `sql/002` ficam só como histórico. O README manda rodar só `001` e `003` (`README.md:66-67`). Nada lê nem escreve em `omie_raw`: `grep omie_raw` em `src` não acha nada ✅.
- 🟡 Divergências de documentação no repositório: `README.md:32` ainda diz "as duas migrações do DBA (`001` e `002`)"; `sql/001_schemas.sql:13` ainda cria o schema `omie_raw` e `.env.example:41` ainda o cita.
- 🔴 O que sobra: o `DROP` das 5 tabelas e do schema `omie_raw` no banco, que é do Gustavo (BL-054).

Cotação PTAX gravada em `core.cotacoes_moeda` é a base da cotação da OC em moeda estrangeira ([[Rastreabilidade-e-Torre-de-Fluxo]] não depende dela).

### Variáveis de ambiente

| Variável | Uso | Código |
|---|---|---|
| `FILIAIS_ATIVAS` (padrão `mogi,uberaba`), `FILIAL_<CHAVE>_OMIE_APP_KEY`, `_OMIE_APP_SECRET`, `_CODIGO_EMPRESA` (uuid de `core.unidades`) | contas Omie, uma por filial | ✅ `config/index.ts:31-47` |
| `OMIE_BASE_URL`, `OMIE_MAX_CONCURRENT_PER_METHOD` (3), `OMIE_MAX_PER_MINUTE_PER_METHOD` (200) | cliente Omie | ✅ `:61-69` |
| `PGHOST`, `PGPORT`, `PGDATABASE` (`erp`), `PGUSER`, `PGPASSWORD`, `PG_SSL`, `PG_IDLE_IN_TRANSACTION_TIMEOUT_MS` | banco | ✅ `:71-77`, `db/pool.ts:50` |
| `REDIS_URL` | BullMQ | ✅ `:79` |
| `AVHUB_API_URL`, `AVHUB_API_KEY` | envio da OC (obrigatórias para o worker) | ✅ `:164-165`, `avhub/client.ts:13-14` |
| `FILIAL_<CHAVE>_SCRAPING_{EMAIL,SENHA,ERP_URL,REPORT_SLUG,NOME_APLICATIVO,TOTP_SECRET}`, `SCRAPING_STATE_DIR`, `SCRAPING_CRON`, `SCRAPING_TIMEOUT_MIN` | scraping de manifestação | ✅ `:227-268` |
| `LOG_LEVEL`, `NODE_ENV` | log | ✅ |

As chaves `SYNC_*` de ligar/desligar recursos saíram em 06/10 (contrato 38): hoje só há crons e janelas ✅ README `:102-111`. O repositório ainda traz o `dump 2.0.sql` na raiz (esquema antigo do banco); não é fonte de verdade ✅ `ls`.

### Pendências e riscos

- 🔴 A pipeline escreve no Omie de verdade ao subir o worker (decisão de 07/10). Antes de publicar: contrato 36 na API e compradores vinculados ✅ README `:107-110`.
- 🟡 `ecosystem.config.cjs:62` ainda cita `SYNC_ENVIO_OC=false` e o `README.md:169-171` ainda diz "Ainda não feito: o envio da ordem de compra"; o envio é fixo e está feito.
- 🟡 Pedido de venda apagado e recriado com o mesmo sequencial colide em `uq_pedidos_vendas_numero_sequencial`; o `pedidoAutoHeal` confirma no Omie e apaga a linha antiga ✅ `jobs/pedidoAutoHeal.ts:1-25`.
- ❓ Latência real do `ListarPedidos` entre o pedido criado no Omie e a caixa de liberação (camada "hoje" a cada 3 min) não medida.
