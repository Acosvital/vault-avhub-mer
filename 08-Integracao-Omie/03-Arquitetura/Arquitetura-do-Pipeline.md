---
tags: [integracao-omie, arquitetura]
criado: 2026-09-17
---

# Arquitetura do `omie-elt-pipeline` (resumo técnico)

Complementa a nota já existente na seção de modelagem ([[Omie-ELT-Pipeline]]) com o essencial para entender de onde vêm os campos listados nos arquivos de dados extraídos ([[Parceiros-Clientes-Fornecedores]], [[Produtos-e-Familias]], [[Vendedores]], [[Pedidos-de-Venda]], [[Notas-Fiscais-e-Itens]], [[Etapas-Faturamento]]).

## EL, não ETL

Node.js/TypeScript. `extract-worker` e `load-worker` (BullMQ + Redis), orquestrados por `scheduler.ts` (node-cron) em camadas de sincronização por janela (hoje / mês / últimos 90 dias / full sync diário) mais limpeza por exclusão. Escreve direto nas tabelas de negócio (`core.*`, `core_vendas_faturamento.*`) via upsert idempotente (`pg`, sem ORM) — a transformação/regra de negócio fica deliberadamente do lado do banco (views/triggers), não deste pipeline.

Duas contas/filiais Omie em paralelo: `mogi` e `uberaba`, cada uma com seu próprio `codigo_empresa`.

## Camada de auditoria opcional (raw)

Schema `omie_raw.*` — uma tabela por recurso principal (`produtos`, `parceiros`, `vendedores`, `pedidosVendas`, `notasFiscais`), cada uma guardando o payload JSON bruto e não-tratado, com `omie_id`, `filial`, `payload jsonb`, `ingested_at`, `source`. **Desabilitado por padrão** (`RAW_AUDIT_ENABLED=false`) — existe só para debug/reprocessamento, nada lê dali hoje. Útil para investigar se o Omie manda mais campos do que o pipeline atualmente mapeia (ver [[Perguntas-em-Aberto]]).

## Log de execução (não é dado de negócio)

`omie_ctl.run_log` — uma linha por execução de sync layer/resource/filial, com contagem de registros e erro, só para diagnóstico operacional.

## Endpoints usados

| Endpoint Omie | Resource | Destino |
|---|---|---|
| `ListarClientes` | `parceiros.ts` | `core.parceiros`, `core.tipos_parceiro`, `core.parceiros_tipos` |
| `ListarProdutos` | `produtos.ts` | `core.produtos` |
| `PesquisarFamilias` | `familiaProdutos.ts` | `core.familia_produtos` |
| `ListarVendedores` | `vendedores.ts` | `core_vendas_faturamento.vendedores` |
| `ListarPedidos` | `pedidosVendas.ts` | `core_vendas_faturamento.pedidos_vendas` + `produto_vendas` (itens embutidos) |
| `ListarNF` | `notasFiscais.ts` | `core_vendas_faturamento.notas_fiscais` |
| `ListarEtapasFaturamento` | `etapasFaturamento.ts` | `core.etapas_faturamento` (ver [[Etapas-Faturamento]]) |
| `ListarPosEstoque` | `estoque.ts` | nenhum — desabilitado, sem tabela de destino |

## Ver também
- [[Omie-ELT-Pipeline]] (seção de modelagem — contexto completo: incidentes, decisões rejeitadas, scraper de manifesto)
- [[Etapas-Faturamento]]
- [[Perguntas-em-Aberto]]
