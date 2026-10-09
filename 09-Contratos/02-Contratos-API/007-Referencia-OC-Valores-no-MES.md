---
tags: [contrato-api, mes, estoque, compras, custo, integracao-av-hub-mes]
status: para-implementar
criado: 2026-10-09
atualizado: 2026-10-09
---

# Contrato de API 007 — Valores da OC na referência (hub → MES) e projeção no MES

> **Status: `para-implementar`.** Extensão **compatível** do [[004-Referencia-OC-Integracao-MES]] (o 004 diz "sem preço"; este contrato revoga só essa frase). Depende do SQL [[012-Ordens-Compra-Referencia-Valores]] (Gustavo). Desenho de negócio: [[Estoque-Custo-do-Lote]]. Uso futuro do mesmo dado: Compras e Orçamento.

## Por quê

O lote do MES nasce de uma OC e precisa do custo ([[008-Custo-do-Lote-no-MES]]); Compras e Orçamento (Comercial & Suprimentos) querem comparar orçado × comprado × custo real. O MES já faz polling da OC; falta a rota devolver os valores e o job gravá-los.

## Lado do hub (Gustavo) — `GET /ordens-compra/referencia`

Sem mudar parâmetros, paginação, cursor (`proximo`), autenticação nem quais OCs entram. A resposta ganha:

**Na OC** (ao lado de `situacao`, `finalidade`…): `moeda`, `cotacao_moeda`, `cotacao_data`, `cotacao_origem`, `valor_frete`, `valor_seguro` (tipos no SQL 012).

**Em cada item** (ao lado de `quantidade`, `unidade_medida`…): `valor_unitario`, `desconto_pct`, `valor_desconto`, `valor_total_item`.

```json
{ "id_ordem_compra": "uuid", "numero_pedido": "OC-000123", "situacao": "aprovada",
  "moeda": "USD", "cotacao_moeda": 5.412300, "cotacao_data": "2026-10-16", "cotacao_origem": "ptax",
  "valor_frete": 180.00, "valor_seguro": null,
  "itens": [ { "id_item_oc": "uuid", "quantidade": 10.0, "unidade_medida": "PC",
               "valor_unitario": 12.5000, "desconto_pct": 5.000, "valor_desconto": 6.25, "valor_total_item": 118.75 } ] }
```

Passos: (1) incluir as colunas em `COLUNAS` da rota; (2) campos novos no `.swagger.json` (`ReferenciaOcItem` e o objeto da OC), com a nota "valores na moeda da OC; `cotacao_moeda` nulo em BRL"; (3) trocar a frase "Sem preço, fornecedor…" do cabeçalho da rota por "Sem fornecedor, condição de pagamento, categoria nem conta corrente; preço, moeda e cotação desde o contrato 007"; (4) corrigir no swagger "Mudanças que não aparecem aqui (preço…)". **Continua sem** fornecedor, condição de pagamento, categoria e conta corrente.

Compatibilidade: campos novos são aditivos; o MES antigo ignora o que não conhece.

## Lado do MES (Robert) — job de leitura e projeção

Este job é o **mesmo** pendente do 004 (ver [[Registro-de-Decisoes-2026-10-07]], item 41); o contrato 007 só acrescenta o que ele grava.

- A cada 5 min, `GET /ordens-compra/referencia` com chave de **leitura** (`auth.chaves_servico` ou `API_KEYS`; a `MES_INTEGRACAO_KEYS` do 34 dá 403), cursor `proximo` com alguns minutos de sobreposição.
- UPSERT da OC por `(codigo_empresa, id_ordem_compra)` e dos itens por `(id_ordem_compra, id_item_oc)`; item que some de uma OC que voltou = item removido. Projeção sugerida `oc_referencia` / `oc_referencia_item` 🟡 (nome livre), com os campos acima e `valor_unitario_brl` calculado:

  `valor_unitario_brl = valor_unitario × (1 − desconto_pct/100) × (cotacao_moeda ?? 1)`

- OC com `cotacao_origem = manual` é gravada, com o item marcado `cotacao_a_conferir`.
- Ajuste pendente do 004: `id_origem` em cada item (pedido em 30/09).
- O registro manual `PATCH /compras/requisicoes/:id/compra` segue valendo até o job entrar.

## Aceite

1. Uma OC em USD aprovada aparece no MES com moeda, cotação, valor unitário e `valor_unitario_brl` conferindo com o cálculo acima.
2. Mudar o preço de um item de OC aprovada atualiza a projeção em até 5 min (depende do SQL 012, seção 2).
3. OC cancelada some da fila e a projeção guarda a situação.
4. O MES sem o job continua funcionando (nada do recebimento depende do preço).

## Ver também
[[004-Referencia-OC-Integracao-MES]] · [[012-Ordens-Compra-Referencia-Valores]] · [[008-Custo-do-Lote-no-MES]] · [[Estoque-Custo-do-Lote]] · [[Integracao-AvHub-MES-Volta-Plano]]
