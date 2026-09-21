---
tags: [integracao-omie, lacunas, achado]
criado: 2026-09-17
---

# Contradição encontrada: CFOP já é capturado, apesar do que a seção de modelagem documenta

## O que a seção de modelagem afirma

Em três lugares diferentes ([[Estoque-Regras-Negocio]], [[Fluxo-Recebimento-Completo]], [[Estoque-Modelo-Dados]]) a seção de modelagem registra que CFOP e ICMS-ST **não são capturados por nenhum sistema** — "fica 100% com o Omie".

## O que o código do pipeline realmente faz

Em `produtoVendas.ts` (mapeamento de `core_vendas_faturamento.produto_vendas`, os itens de pedido/venda), existe:

```
cfop: limparCfop(item.produto.cfop)
```

validado contra uma whitelist cacheada de `core_vendas_faturamento.cfop` (TTL 10 min) — se o CFOP não estiver na lista curada, o valor vira `null` com um warning de log, mas **quando está na lista, o CFOP é capturado e persistido por item de venda**.

## Por que isso é uma contradição real, não só um detalhe

A seção de modelagem usa essa afirmação ("CFOP não é capturado") como base para tratar CFOP como algo puramente do domínio do Omie, fora do escopo de qualquer decisão de modelo de dados do ERP novo. Mas o dado já existe, já está sendo sincronizado, e já está por item — ou seja, ele **está disponível** para qualquer regra de negócio do Estoque/MES que precise dele (por exemplo, cruzar CFOP de venda com uma eventual CFOP de devolução).

O que continua correto na afirmação da seção de modelagem: **ICMS-ST de fato não é capturado** em nenhuma tabela — só o CFOP estava errado.

## Onde isso mora hoje

- Tabela: `core_vendas_faturamento.produto_vendas`, coluna `cfop`.
- Só existe no nível de **item de pedido de venda** — não existe um CFOP "da nota como um todo" em `notas_fiscais`.
- Depende de uma whitelist `core_vendas_faturamento.cfop` já curada e mantida por alguém (não pelo pipeline).

## Ação recomendada

Corrigir a afirmação na seção de modelagem ([[Estoque-Regras-Negocio]], [[Fluxo-Recebimento-Completo]], [[Estoque-Modelo-Dados]]) para refletir que CFOP de venda **já está disponível por item**, mantendo apenas ICMS-ST como de fato não capturado.

## Ver também
- [[Pedidos-de-Venda]]
- [[Notas-Fiscais-e-Itens]]
