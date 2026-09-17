---
tags: [integracao-omie, dados-extraidos]
criado: 2026-09-17
---

# Notas Fiscais

Fonte: Omie `ListarNF` (`/produtos/nfconsultar/`), resource `notasFiscais.ts`. Destino: `core_vendas_faturamento.notas_fiscais`. Chave de conflito (PK): `(codigo_empresa, codigo_nf_omie)`.

| Coluna | Campo/origem Omie |
|---|---|
| codigo_nf_omie | `compl.nIdNF` |
| numero_nf | `ide.nNF` |
| tipo_nf | `ide.tpNF` |
| chave_nf | `compl.cChaveNFe` |
| data_emissao / hora_emissao | `ide.dEmi` / `ide.hEmi` |
| codigo_empresa | filial |
| codigo_cliente | `nfDestInt.nCodCli` |
| codigo_vendedor_omie | `titulos[0].nCodVendedor` |
| codigo_comprador_omie | `titulos[0].nCodComprador` |
| codigo_categoria | `compl.cCodCateg` |
| codigo_pedido_omie | `compl.nIdPedido` |
| oppedido | `nf.pedido.opPedido` — tipo de operação da NF, cruza com `core.etapas_faturamento.codigo_operacao` (ver [[Etapas-Faturamento]]) |
| valor_mercadorias / valor_nf / valor_ipi | `total.ICMSTot.vProd` / `.vNF` / `.vIPI` |
| **descontos, manual, averbado** | **não vêm do Omie** — colunas protegidas, preenchidas por outro sistema. Ver [[Colunas-Protegidas]]. |
| id, created_at/by, updated_at/by, deleted_at/by | gerenciadas pelo banco |

## Vínculo NF → item do pedido

`notasFiscais.ts` faz um `UPDATE` direcionado em `produto_vendas.codigo_nf_omie`/`.numero_nf` assim que a nota correspondente sincroniza — essas duas colunas nunca são escritas pelo lado do pedido (ver [[Pedidos-de-Venda]]).

## O que NÃO está nesta tabela (nem em nenhuma outra)

- **CFOP da nota como um todo** — não existe; o único CFOP capturado é por item, em `produto_vendas.cfop` (ver [[Contradicao-CFOP]]).
- **ICMS-ST** — de fato não é capturado em nenhuma tabela, confirmando o que o vault 01 já documentava.

## Confiabilidade de `numero_nf`

Não é um vínculo transacional garantido — o campo que o Portal do Vendedor usa (`vw_vendas_base.numero_nf`) vem, na origem, de um scraper Playwright de relatório de UI ("manifestação do destinatário"), não de uma API do Omie. Ver nota `Omie-ELT-Pipeline.md` no vault 01 para o processo completo (login 2FA, Microsoft Graph, export Excel).

## Nota Fiscal de Entrada (compras)

O vault 01 documenta que o Estoque só referencia `chave_acesso` de NF de entrada, sem capturar CFOP/ICMS-ST — **o pipeline atual não extrai nenhuma NF de entrada do Omie** (só `ListarNF`, que é de saída/vendas). Esse dado, se vier a existir, precisaria de um endpoint Omie novo, não coberto hoje.

## Ver também
- [[Pedidos-de-Venda]]
- [[Contradicao-CFOP]]
- [[Colunas-Protegidas]]
