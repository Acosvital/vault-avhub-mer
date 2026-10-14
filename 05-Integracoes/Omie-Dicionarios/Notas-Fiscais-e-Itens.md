---
tags: [omie, dicionario, pipeline, notas-fiscais]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Gustavo (DBA)
fontes: [v1 08-Integracao-Omie/01-Dados-Extraidos/Notas-Fiscais-e-Itens, omie-elt-pipeline 0f739f0 (protectedColumns.ts)]
---

# Dicionário Omie: Notas fiscais

Fonte: Omie `ListarNF` (`/produtos/nfconsultar/`), resource `notasFiscais.ts`. Destino: `core_vendas_faturamento.notas_fiscais`. Chave de conflito: `(codigo_empresa, codigo_nf_omie)`. Nós do fluxo: O1 e O2 ([[10-Fiscal-Omie]]).

| Coluna | Campo ou origem Omie |
|---|---|
| `codigo_nf_omie` | `compl.nIdNF` |
| `numero_nf` | `ide.nNF` |
| `tipo_nf` | `ide.tpNF` |
| `chave_nf` | `compl.cChaveNFe` |
| `data_emissao`, `hora_emissao` | `ide.dEmi`, `ide.hEmi` |
| `codigo_empresa` | filial |
| `codigo_cliente` | `nfDestInt.nCodCli` |
| `codigo_vendedor_omie` | `titulos[0].nCodVendedor` |
| `codigo_comprador_omie` | `titulos[0].nCodComprador` |
| `codigo_categoria` | `compl.cCodCateg` |
| `codigo_pedido_omie` | `compl.nIdPedido` |
| `oppedido` | `nf.pedido.opPedido`: tipo de operação; cruza com `core.etapas_faturamento.codigo_operacao` ([[Etapas-Faturamento]]) |
| `valor_mercadorias`, `valor_nf`, `valor_ipi` | `total.ICMSTot.vProd`, `.vNF`, `.vIPI` |
| `descontos`, `manual`, `averbado` | **não vêm do Omie**: colunas protegidas ([[Colunas-Protegidas]]); `manual` e `descontos` vêm da NF manual do av-hub ([[LOG-29-Notas-Fiscais-Manuais-So-Admin]], só administrador) |
| `id`, `created_at/by`, `updated_at/by`, `deleted_at/by` | gerenciadas pelo banco |

## Vínculo NF → item do pedido

`notasFiscais.ts` faz `UPDATE` direcionado em `produto_vendas.codigo_nf_omie` e `.numero_nf` quando a nota sincroniza. Essas duas colunas nunca são escritas pelo lado do pedido ([[Pedidos-de-Venda]]).

## O que não está nesta tabela

- **CFOP da nota como um todo**: não existe. O único CFOP capturado é por item, em `produto_vendas.cfop` ([[Omie-Integracao-Estado]], seção CFOP).
- **ICMS-ST**: não é capturado em nenhuma tabela.
- **NF de entrada (compras)**: o pipeline não extrai nenhuma. `ListarNF` é só de saída. A NF de entrada do fluxo de compra é digitada na chegada, no MES (`POST /compras/requisicoes/:id/chegada`, [[05-Recebimento]]).

## Confiabilidade de `numero_nf`

Não é vínculo transacional garantido. O `numero_nf` que o Portal do Vendedor usa (`vw_vendas_base.numero_nf`) vem de um scraper Playwright do relatório "manifestação do destinatário" (login com 2FA por TOTP local, seg a sex das 07h às 18h, cerca de 1 h ± 25 min, só Mogi). Ver [[Pipeline-Omie]].

Ver também: [[Pedidos-de-Venda]], [[Colunas-Protegidas]].
