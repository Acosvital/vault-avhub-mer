---
tags: [erp-acos-vital, integracao, omie, pipeline]
criado: 2026-09-16
atualizado: 2026-10-07
---

# Pipeline ELT Omie → Postgres (`omie-elt-pipeline`)

> Status: decidido | no código | em produção (verificado em 07/10/2026 pelo dump, onde indicado). Decisões da rodada em [[Registro-de-Decisoes-2026-10-07]]. **O pipeline roda na VPS 1** (bancos na VPS 2; ✅ Nathan, 07/10).

> **Atualização de 07/10/2026 — reescrita das seções defasadas, a partir de leitura de código (`master` d2886bf, 06/10 07:46).** A nota original é de 16/09; desde então o pipeline ganhou o domínio de Compras inteiro (6 recursos, PTAX, inativação de catálogos e **envio de OC ao Omie**, 23/09 a 06/10), 4 processos novos, dashboard e multi-filial. **Rótulo de confiança: tudo abaixo vem de leitura de código, não de produção/deploy/banco** — o contrato 23 diz "sem deploy nada roda", e se o envio de OC está ligado em produção é **desconhecido**. O `.env` do pipeline não foi lido (tem segredos); só nomes de variáveis são citados. Ver [[Chaves-de-Integracao-AvHub-MES-Pipeline]], [[23-Compras-Pipeline-Consolidado]] e [[Onde-Estamos]].

O extrator que alimenta o dado cru que sustenta [[AV-Hub-Vendas-Reconciliacao|toda a reconciliação de vendas]]. Node.js/TypeScript, `pg` puro (sem ORM), BullMQ+Redis, `node-cron`, Playwright.

## Filosofia: EL, não ETL

Documentado explicitamente (`ARCHITECTURE.md`): já foi um ETL Python que também aplicava regra de negócio; hoje um DBA dedicado é dono do schema/views/triggers, e este pipeline **só extrai do Omie e faz upsert nas tabelas de negócio reais** (`core.*`, `core_vendas_faturamento.*`) — nunca calcula G1-G6/LÍQUIDO nem qualquer outra regra.

**Exceção desde 23/09 (atualizado em 07/10):** o pipeline também **escreve no Omie** — mas só uma coisa, o envio de Ordem de Compra (`UpsertPedCompra`/`ExcluirPedCompra`), ver seção própria abaixo. Todo o resto continua sendo leitura. Próprio do pipeline no banco: só `omie_ctl.run_log` (log de execução, `sql/003`). O staging `omie_raw.*` (`sql/002`, 5 tabelas) está **morto**: o código que o alimentava (`RAW_AUDIT_ENABLED`, `upsertRawAudit`) foi removido em 06/10 (contrato 38). 🟡 Marcar `sql/002` como **obsoleto** (Nathan); o `DROP` das 5 tabelas vazias é do DBA/Gustavo.

## Multi-filial (atualizado em 07/10)

Antes a nota dizia "duas contas Omie: `mogi` e `uberaba`". Hoje o código aceita **N filiais**: cada filial = uma conta Omie, configurada por variáveis `FILIAL_<CHAVE>_OMIE_APP_KEY/SECRET/CODIGO_EMPRESA`; `FILIAIS_ATIVAS` define quais rodam, **em paralelo no mesmo processo**, com limitador de taxa por filial+método. O `.env.example` só traz mogi e uberaba; **nenhum código menciona a HRM**.

| Ponto | Situação |
|---|---|
| Ligar a HRM | por variáveis de ambiente (nova chave de filial + `FILIAIS_ATIVAS`) |
| Ressalva — `FAMILIA_PADRAO_POR_FILIAL` (`produtos.ts`) | hardcoded só para mogi e uberaba: produto da HRM **sem família no Omie é pulado** (`validate`) `[inferido]` |
| Contradição com `ARCHITECTURE.md` | o texto diz que ligar uma filial nova não muda código; a ressalva acima o contradiz `[inferido]`. **Decidido (✅, 07/10):** manter o código como está e acrescentar: tarefa de código registrada (Gustavo); corrigir o `ARCHITECTURE.md` do pipeline (fora do vault) |
| Scraping de manifesto | só Mogi: 🟡 o login de Mogi traz as duas empresas (consolidado), então não precisa de plano para Uberaba; **falta confirmar por consulta** (Gustavo) que `manifestos` tem linhas de Uberaba. A HRM não está coberta; o mapa por `NOME_APLICATIVO` precisaria de entrada para ela `[inferido]` |

## Sem webhook — camadas de polling

Confirmado impossível para esta conta Omie (20/08/2026). Em vez de watermark incremental, usa **janelas de calendário fixas, sempre re-varridas por inteiro** (porque o Omie só filtra pedidos/NFs por data de inclusão/emissão, nunca por data de alteração). Pedidos de compra são a exceção: `PesquisarPedCompra` com `lApenasAlterados=T`.

| Camada | Cron | Janela |
|---|---|---|
| `sync_hoje` | `*/3 * * * *` | hoje 00:00→agora |
| `sync_mes` | `2,22,42 * * * *` | mês corrente |
| `sync_ultimos_meses` | `7 */3 * * *` | 90 dias móveis |
| `full_sync` | `17 3 * * *` | catálogo completo + 365 dias (+ carga inicial manual) |

Catálogos de Compras rodam **só nas camadas lentas** (3h + full), via `somenteCamadaLenta`.

## O que é extraído (atualizado em 07/10)

15 recursos registrados em `src/omie/resources/index.ts`: **14 ligados**, 13 com `listMethod`. `produtoVendas` não tem `listMethod` — é gravado como efeito colateral de `pedidosVendas`.

| Recurso (método Omie) | Camadas | Destino |
|---|---|---|
| produtos (`ListarProdutos`) | hoje/mês/ult.meses/full | `core.produtos` |
| parceiros (`ListarClientes`) | idem | `core.parceiros` (agora com dados fiscais) + `parceiros_tipos`/`tipos_parceiro` |
| vendedores | idem (relista tudo a cada 3 min) | `core_vendas_faturamento.vendedores` |
| pedidosVendas (`ListarPedidos`) | idem | `pedidos_vendas` + `produto_vendas` |
| notasFiscais (`ListarNF`) | idem | `notas_fiscais` + UPDATE em `produto_vendas` |
| familiaProdutos | idem | `core.familia_produtos` |
| etapasFaturamento | idem | `core.etapas_faturamento` (`enabled:true` desde f753982; a tabela existe) |
| pedidosCompras (`PesquisarPedCompra`) | hoje/mês/ult.meses/full (full = 365 dias) | `pedidos_compras` + `_itens` + `_parcelas` |
| compradores | só ult.meses + full | `core_vendas_faturamento.compradores` |
| condicoesPagamentoCompras | idem | `condicoes_pagamento_compras` |
| projetos | idem | `core.projetos` |
| contasCorrentes | idem | `core.contas_correntes` |
| categorias | idem | `core.categorias` |
| estoque (`ListarPosEstoque`) | **desligado** | nenhum |

**Estoque desligado — decidido: não será feito** (✅ Nathan, 07/10): o estoque do Omie é ignorado, o Omie recebe dados só manualmente e o MES é a referência do saldo físico (o Passo 2, `ListarPosEstoque`, não será feito; fecha L-03). No código: `enabled:false`, `table:null`, com o comentário no próprio arquivo "sem tabela de destino". Antes visto como ponto de atenção para o [[PRD-Estoque-Visao-Geral|PRD do Estoque]]. As tabelas de destino existem no banco (`core.estoque_saldo`, `core.locais_estoque`, contratos 002 e 005), mas o recurso do pipeline não está ligado a elas.

**Dados fiscais do parceiro** (novo): IE, IM, Suframa, Simples, `contribuinte_icms`, CNAE, `tipo_atividade`, `pessoa_fisica`, `produtor_rural`, `cidade_ibge`, `valor_limite_credito`, `bloquear_faturamento`, `inativo` (66f9a2e). Entidades HTML são decodificadas (`decodificarEntidadesHtml`). Endereço de entrega e dados bancários do parceiro **não** são gravados.

## Compras: leitura, PTAX e inativação (novo em 07/10)

| Job | Quando | O que faz |
|---|---|---|
| PTAX (`jobs/cotacaoPtax.ts`) | `30 13,17 * * 1-5` (America/Sao_Paulo) + ao subir | busca no BCB (não é Omie) só o boletim Fechamento; grava `core.cotacoes_moeda`, fonte `PTAX_BCB`; com tabela vazia faz carga inicial desde 2026-01-01 |
| Inativar catálogos (`jobs/inativarCatalogos.ts`) | `47 4 * * *` | marca `ativo=false` no que sumiu do Omie nos 5 catálogos de Compras; **não age se o Omie devolver menos da metade dos ativos** |

Itens e parcelas do pedido de compra são **REPLACE-ALL por pedido** (apaga o que mudou de posição) e só colunas existentes são gravadas.

## Envio de OC — a única escrita no Omie (novo em 07/10)

Processo próprio (`envio-oc-worker`) + fila `omie-envio-oc` + `src/avhub/client.ts`. Cron `1-59/2 * * * *`. **Decidido (✅ Nathan, 07/10):** o envio fica **fixo no código** e vai **direto ao Omie**, sem `SYNC_ENVIO_OC` nem `ENVIO_OC_DRY_RUN` (alteração de código: Gustavo). O Nathan rodou cerca de **4 testes reais** e a OC entrou. L10.1, L10.6 (FOB) e L10.7 (b) a (d) viram **risco aceito**. **(08/10: feito e mergeado na `master` da pipeline pelo PR #3, merge `0f739f0`. `SYNC_ENVIO_OC` e `ENVIO_OC_DRY_RUN` não existem mais: o scheduler sempre agenda a rodada e o envio vai de verdade ao Omie assim que o worker for publicado. Rodada manual sem enviar: `npm run envio-oc -- --dry-run`. Antes de publicar, a API precisa estar com o contrato 36 e os compradores vinculados.)** (Texto anterior: só agendado com `SYNC_ENVIO_OC=true`, com dry run por padrão; mantidos como interruptores de propósito no contrato 38 §6, o que a decisão supera.)

| Regra | Detalhe |
|---|---|
| Fila e retorno | `GET /compras/ordens/fila-omie`; retorno por `PATCH /compras/ordens/{id}/sincronizacao` com `x-api-key` (`AVHUB_API_URL`/`AVHUB_API_KEY`) |
| `enviar` | `UpsertPedCompra` com `cCodIntPed = numero_pedido` (≤20 chars); **não** usa `IncluirPedCompra` |
| `excluir` | `ExcluirPedCompra`; "não encontrado" conta como excluído e dá `deleted_at` em `pedidos_compras` |
| Validação prévia | sem comprador vinculado ou item sem `nCodProd` → `OcIncompleta` vira erro na OC **sem chamar o Omie** (produto precisa existir em `core.produtos` da unidade da OC) |
| Parcelas | **nunca manda parcelas**: só `cCodParc` e `nQtdeParc` (f4fd02d); sem parcelas o Omie gera pela condição e mantém o código |
| `cObsInt` | bloco `[AV-HUB]` com separador ` ; ` (em vez de `\|`) |
| Frete | CIF=`0`, FOB=`1` — FOB **sem teste real** ("a confirmar" no código) |
| Falhas | recusa do Omie → erro na OC (só volta pelo "Reenviar"); rede/429/425 → fica pendente; 3 recusas seguidas param a rodada da unidade; retorno que a API não recebeu fica em memória e é reentregue |

O teste real em Mogi (05/10) **não é provado pelo código**: README e contrato 23 registram a OC-000002 virando o pedido 47476, reenvio sem duplicar e exclusão aceita (Omie não verificado). O contrato 23 é a fonte viva; o 19 é histórico.

## Processos e infraestrutura (novo em 07/10)

Antes a nota só citava `extract-worker`/`load-worker`. Hoje, PM2 com **6 apps**; o compose sobe Redis + os mesmos 6 (o Postgres é de fora).

| App | Papel |
|---|---|
| `extract-worker` | extrai do Omie |
| `load-worker` | grava no Postgres; concorrência 40/10, `PG_POOL_MAX=60` |
| `scheduler` | crons das camadas e jobs |
| `scraping-worker` | manifesto (Playwright/Chromium, `Dockerfile.scraping`) |
| `envio-oc-worker` | envio de OC (`omie-envio-oc`) |
| `dashboard` | Bull Board na porta **3011** com basic auth; 5 filas: `omie-extract`, `omie-load`, `omie-load-realtime`, `omie-query`, `omie-envio-oc` |

Ver também [[Infraestrutura-Self-Hosted]].

## O scraper de manifesto — confirma a suspeita sobre `numero_nf`

Não existe endpoint de API do Omie para "manifestação do destinatário" — só existe na UI do Omie, num relatório específico ("Faturamento por Período - BI Novo"). Processo separado (`scraping-worker`, Playwright/Chromium): login com 2FA, navega até o relatório, exporta Excel, faz parsing e upsert em `core_vendas_faturamento.manifestos`. **Esta é a fonte exata do campo `numero_nf` de `vw_vendas_base` que a doc do Portal do Vendedor já alertava para não usar como "a nota deste pedido"**: é dado raspado de relatório de UI, não um vínculo transacional garantido.

**Mudanças (atualizado em 07/10):** a versão original dizia "cron horário e 2FA via polling de caixa de e-mail (Microsoft Graph)". Hoje o agendamento é um `setTimeout` auto-reagendado, **seg–sex 07–18h, ~1h ±25 min** (jitter; `SCRAPING_CRON` foi removido em 1b22ddc, a agenda é hardcoded); o 2FA é por **TOTP local** (e91938d) e Graph/e-mail ficou só como fallback legado. Roda **só para Mogi** (`SCRAPING_FILIAIS_ATIVAS=mogi`).

## Padrão importante para qualquer módulo novo: "colunas protegidas"

`src/db/protectedColumns.ts` — lista de colunas que este pipeline **nunca escreve**, mesmo fazendo upsert na mesma linha, porque pertencem a outro sistema:

| Tabela | Colunas protegidas |
|---|---|
| `notas_fiscais` | `descontos`, `manual`, `averbado` |
| `pedidos_vendas` | `manual` |
| `produto_vendas` | `codigo_nf_omie`, `numero_nf` |
| `vendedores` | `comissao`, `ajuda_custo`, `filial`, `id_usuario`, `id_funcionario` |
| `core.parceiros` | `latitude_y`, `longitude_x` (owned por um job de geocodificação à parte) |
| `compradores` (novo) | `id_funcionario`, `nome_exibicao`, `ativo_desde`, `inativo_desde` |

**Lição direta para o Estoque/ERP unificado**: quando duas fontes escrevem na mesma tabela, decidir explicitamente e documentar quem é dono de qual coluna, em vez de deixar implícito.

## Decisão de arquitetura rejeitada pelo DBA (lição de design)

Uma proposta de FK entre `produto_vendas`→`pedidos_vendas`/`notas_fiscais` foi **rejeitada e documentada como histórico**: entidades sincronizam independentemente, sem garantia de ordem, então uma FK rígida quebraria upserts legítimos que chegam fora de ordem. Por isso a única FK que atravessa fronteira de sincronização é para `core.unidades` (semeada manualmente, nunca sincronizada do Omie). Mesma lição vale para qualquer integração nova (Estoque↔Omie, por exemplo): não assumir ordem de chegada entre entidades relacionadas.

## Incidentes reais documentados (histórico de decisões, `ARCHITECTURE.md`/`README.md`)

- **21/08** — rate limiter em memória por processo permitiu que dois processos (extractWorker + exclusionSync) juntos estourassem o limite global do Omie → 429. Uma versão com limiter distribuído via Redis foi tentada e **revertida** (locks travados após crash) — fica documentado como "tentado e descartado", não como solução pendente.
- **27/08** — ~270 mil jobs empilhados na fila `omie-load` porque a linha placeholder de `familia_produtos` da unidade Uberaba nunca existia em produção — corrigido com seed manual, não automático.
- **28/08** — autodeadlock em conexões Postgres do pipeline "idle in transaction" → adicionados `connectionTimeoutMillis`/`idle_in_transaction_session_timeout`/`statement_timeout` e um job de monitoramento de pool (hoje `*/2 * * * *`).
- **09/09** — crash por evento `'error'` não tratado em conexão durante instabilidade de rede → listeners de erro por conexão adicionados.
- **23/09 a 06/10 (marcos recentes, não incidentes de produção)** — PR #1 do envio de OC mergeado em 05/10 14:56 (3233acf) e PR #2 em 06/10; em 06/10 o contrato 38 (d6abf04) removeu as flags `SYNC_*` de recurso, `EXCLUSION_SYNC_DRY_RUN` e a camada raw. A ficha desta auditoria não registra incidentes operacionais novos além desses — a lista acima não é exaustiva para o período `[inferido]`.

## Idempotência e exclusão

Tudo via upsert em chave real (nunca chave inventada), com bisseção de lote em caso de falha (isola linha problemática sem perder o resto do lote) e fallback para linhas legadas sem ID do Omie.

**Exclusão (atualizado em 07/10)** — a versão original dizia "dry-run por padrão, com relatório em CSV". Hoje `EXCLUSION_SYNC_DRY_RUN` saiu do código e a reconciliação **apaga de verdade**; o CSV é só relatório.

| Job | Cron | Escopo |
|---|---|---|
| `exclusionSync` curto | `12,32,52 * * * *` | 60 dias, **só `pedidosVendas`** |
| `exclusionSync` amplo | `27 4 * * *` | 180 dias |

🔴 **RISCO CRÍTICO (Gustavo):** o `exclusionSync` apaga `pedidos_vendas` por empresa e janela **sem filtrar `manual`**. Pedidos manuais têm `codigo_pedido_omie` **negativo**, não existem no Omie e entram na lista de excluídos (`exclusionSync.ts:98-106,136`). Confirmar com o Gustavo antes de usar pedido manual em produção ([[Registro-de-Decisoes-2026-10-07]], item 15). Também 🔴 Gustavo: 497 erros em `exclusion_sync_curta` em Mogi (490 HTTP 500), causa não documentada (item 16).

Pedido de compra apagado no Omie por fora da OC **não** é detectado (o `exclusionSync` só olha `pedidosVendas`); 🟡 aceito como limitação conhecida (Nathan). Outros jobs fora dos recursos: geocodificação `37 5 * * *`.

## Ver também
- [[AV-Hub-Vendas-Reconciliacao]]
- [[Schema-Postgres-Multi-Dominio]]
- [[PRD-Estoque-Visao-Geral]]
- [[Decisoes-Chave-ERP]]
- [[Chaves-de-Integracao-AvHub-MES-Pipeline]]
- [[23-Compras-Pipeline-Consolidado]]
