---
tags: [erp-acos-vital, integracao, omie, pipeline]
criado: 2026-09-16
---

# Pipeline ELT Omie → Postgres (`omie-elt-pipeline`)

O extrator que alimenta o dado cru que sustenta [[AV-Hub-Vendas-Reconciliacao|toda a reconciliação de vendas]]. Node.js/TypeScript, `pg` puro (sem ORM), BullMQ+Redis, `node-cron`, Playwright.

## Filosofia: EL, não ETL

Documentado explicitamente (`ARCHITECTURE.md`): já foi um ETL Python que também aplicava regra de negócio; hoje um DBA dedicado é dono do schema/views/triggers, e este pipeline **só extrai do Omie e faz upsert nas tabelas de negócio reais** (`core.*`, `core_vendas_faturamento.*`) — nunca calcula G1-G6/LÍQUIDO nem qualquer outra regra. Duas contas Omie em paralelo ("filiais"): `mogi` e `uberaba`, cada uma com suas próprias credenciais e seu `codigo_empresa`.

## Sem webhook — 4 camadas de polling

Confirmado impossível para esta conta Omie (20/08/2026). Em vez de watermark incremental, usa **janelas de calendário fixas, sempre re-varridas por inteiro** (porque o Omie só filtra pedidos/NFs por data de inclusão/emissão, nunca por data de alteração):
- `sync_hoje` — hoje 00:00→agora, a cada 3 min.
- `sync_mes` — mês corrente, a cada ~20 min.
- `sync_ultimos_meses` — janela móvel de 90 dias, a cada 3h.
- `full_sync` — catálogo completo + janela de 365 dias, diário às 03:17 + carga inicial manual.

## O que é extraído

Produtos, parceiros (clientes/fornecedores), vendedores, pedidos de venda (com itens embutidos em `pedido.det[]`), notas fiscais, famílias de produto, etapas de faturamento (endpoint pronto, tabela ainda não criada pelo DBA). Estoque (`ListarPosEstoque`) está **desabilitado** — não existe tabela de saldo no dump do DBA ainda, ponto de atenção direto para o [[PRD-Estoque-Visao-Geral|PRD do Estoque]] (hoje nada sincroniza saldo do Omie automaticamente).

## O scraper de manifesto — confirma a suspeita sobre `numero_nf`

Não existe endpoint de API do Omie para "manifestação do destinatário" — só existe na UI do Omie, num relatório específico ("Faturamento por Período - BI Novo"). Processo separado (`scraping-worker`, Playwright/Chromium, cron horário): login com 2FA via polling de caixa de e-mail (Microsoft Graph API), navega até o relatório, exporta Excel, faz parsing e upsert em `core_vendas_faturamento.manifestos`. **Esta é a fonte exata do campo `numero_nf` de `vw_vendas_base` que a doc do Portal do Vendedor já alertava para não usar como "a nota deste pedido"**: é dado raspado de relatório de UI, não um vínculo transacional garantido.

## Padrão importante para qualquer módulo novo: "colunas protegidas"

`src/db/protectedColumns.ts` — lista de colunas que este pipeline **nunca escreve**, mesmo fazendo upsert na mesma linha, porque pertencem a outro sistema: `notas_fiscais.descontos/manual/averbado`, `pedidos_vendas.manual`, `produto_vendas.codigo_nf_omie/numero_nf`, `vendedores.comissao/ajuda_custo/filial/id_usuario/id_funcionario`, `core.parceiros.latitude_y/longitude_x` (owned por um job de geocodificação à parte). **Lição direta para o Estoque/ERP unificado**: quando duas fontes escrevem na mesma tabela, decidir explicitamente e documentar quem é dono de qual coluna, em vez de deixar implícito.

## Decisão de arquitetura rejeitada pelo DBA (lição de design)

Uma proposta de FK entre `produto_vendas`→`pedidos_vendas`/`notas_fiscais` foi **rejeitada e documentada como histórico**: entidades sincronizam independentemente, sem garantia de ordem, então uma FK rígida quebraria upserts legítimos que chegam fora de ordem. Por isso a única FK que atravessa fronteira de sincronização é para `core.unidades` (semeada manualmente, nunca sincronizada do Omie). Mesma lição vale para qualquer integração nova (Estoque↔Omie, por exemplo): não assumir ordem de chegada entre entidades relacionadas.

## Incidentes reais documentados (histórico de decisões, `ARCHITECTURE.md`/`README.md`)

- **21/08** — rate limiter em memória por processo permitiu que dois processos (extractWorker + exclusionSync) juntos estourassem o limite global do Omie → 429. Uma versão com limiter distribuído via Redis foi tentada e **revertida** (locks travados após crash) — fica documentado como "tentado e descartado", não como solução pendente.
- **27/08** — ~270 mil jobs empilhados na fila `omie-load` porque a linha placeholder de `familia_produtos` da unidade Uberaba nunca existia em produção — corrigido com seed manual, não automático.
- **28/08** — autodeadlock em conexões Postgres do pipeline "idle in transaction" → adicionados `connectionTimeoutMillis`/`idle_in_transaction_session_timeout`/`statement_timeout` e um job de monitoramento de pool.
- **09/09** — crash por evento `'error'` não tratado em conexão durante instabilidade de rede → listeners de erro por conexão adicionados.

## Idempotência

Tudo via upsert em chave real (nunca chave inventada), com bisseção de lote em caso de falha (isola linha problemática sem perder o resto do lote), fallback para linhas legadas sem ID do Omie, e reconciliação diária (`exclusionSync`) que detecta pedidos apagados no Omie mas ainda presentes no Postgres (roda em modo dry-run por padrão, com relatório em CSV).

## Ver também
- [[AV-Hub-Vendas-Reconciliacao]]
- [[Schema-Postgres-Multi-Dominio]]
- [[PRD-Estoque-Visao-Geral]]
- [[Decisoes-Chave-ERP]]
