---
tags: [contrato-logica, contrato-api, compras]
criado: 2026-09-30
status: proposta
---

# Contrato 31 — Compras: dashboard com valores (gasto, fornecedores, recebimento, atrasos)

**Criado em:** 30/09/2026 · **Para:** backend (`api-acos-vital`) · **Só API, sem SQL novo**

**Implementado e testado na API local** (branch local `feat/compras-dashboard`, commit `cba68fa`,
arquivos `src/routes/compras_dashboard_sql.js` e a rota em `src/routes/compras_ordens.js`), contra o
banco local com o esqueleto de 29/09. Falta levar para a `develop` compartilhada.

Usa a view do [[15-Compras-Historico-Unificado]] (contrato 25) e os nomes do [[19-Compras-Pedido-Omie-Nomes]].

---

## 1. Por quê

O Dashboard de compras do av-hub só mostra contagens (requisições abertas, em cotação, OCs
aguardando aprovação, aprovadas) e um valor (o total aguardando aprovação). Não mostra **quanto se
compra**, com quem, em que categoria, por qual comprador, nem **o que está atrasado para chegar**.

Tudo isso é soma e agrupamento sobre milhares de pedidos (5.434 pedidos do Omie no banco local,
R$ 147 mi). **O av-hub não vai baixar os pedidos para somar no navegador**: o banco entrega pronto.

## 2. O contrato — `GET /compras/ordens/dashboard`

Rota com caminho fixo, **antes de `/:id`** (como `/resumo`).

| Parâmetro | Regra |
|---|---|
| `data_inicio`, `data_fim` | `AAAA-MM-DD`; padrão = mês corrente (fuso de São Paulo). `data_inicio <= data_fim`, no máximo 2 anos. Senão 400 |
| `codigo_empresa` | uuid, opcional (todas as unidades) |
| `origem` | igual à listagem: `av-hub`, `omie`, `todas`. **Sem o parâmetro vale a flag `COMPRAS_HISTORICO_UNIFICADO`** (desligada = só av-hub). O av-hub manda sempre `todas` |

**Regras de cálculo**

- Base: `vw_ordens_compra_historico` com `status = 'aprovado'` (as linhas do Omie entram todas como
  aprovado). A view já não conta duas vezes a OC do av-hub que foi para o Omie.
- O dia do pedido é o de **São Paulo** (`created_at` da view = inclusão no Omie para linhas do Omie).
- **Período anterior** = mesmo número de dias, terminando na véspera de `data_inicio`.
- Fornecedor, comprador e categoria resolvidos **pela unidade do pedido** (regra B5). No ranking de
  fornecedores, junta pelo **nome** (o mesmo fornecedor tem um código em cada conta Omie); sem nome, o
  código; sem código, "Sem fornecedor informado".
- **Recebimento, atraso e etapas: dos pedidos incluídos no período** (mesmo recorte do resto, dia de
  São Paulo), **a situação de hoje** (atualizado em 30/09/2026, API local `bb5125c`; antes eram uma foto de
  todos os pedidos). Saem do espelho do Omie (`pedidos_compras_itens.quantidade_recebida`), onde o recebimento é lançado. Valor
  pendente do item = parte não recebida do valor do item. Atrasado = tem pendência e `data_previsao`
  antes de hoje.

**Resposta** (setembro/2026, todas as unidades, banco local):

```json
{
  "periodo": { "data_inicio": "2026-09-01", "data_fim": "2026-09-30", "anterior_inicio": "2026-08-02", "anterior_fim": "2026-08-31" },
  "origens": ["av-hub", "omie"],
  "totais": { "valor_comprado": 12280273.43, "pedidos": 1220, "ticket_medio": 10065.8, "fornecedores": 411, "compradores": 23,
              "valor_anterior": 99562709.28, "pedidos_anterior": 1632 },
  "serie_mensal": [ { "mes": "2026-09", "valor": 12280273.43, "pedidos": 1220 } ],
  "por_fornecedor": [ { "nome_fornecedor": "BENAFER", "codigos_fornecedor": "9764283146", "valor": 1424657.01, "pedidos": 35 } ],
  "por_categoria": [ { "codigo_categoria": "2.01.01", "descricao_categoria": "Compras de Material para Revenda", "valor": 8019874.53, "pedidos": 596 } ],
  "por_comprador": [ { "nome_comprador": "LINDAYANE RODRIGUES", "valor": 2240123.11, "pedidos": 90, "fornecedores": 43 } ],
  "maiores_pedidos": [ { "origem": "omie", "id": "…", "numero_pedido": "46471", "data": "2026-09-17", "valor": 409259.6,
                         "nome_comprador": "LINDAYANE RODRIGUES", "codigo_fornecedor": "9764283146", "nome_fornecedor": "BENAFER" } ],
  "recebimento": { "itens": 2485, "pedidos_pendentes": 783, "valor_pendente": 9342496,
                   "pedidos_atrasados": 690, "valor_atrasado": 7294794, "pedidos_chegam_7_dias": 59, "…": "…" },
  "atraso_por_faixa": [ { "faixa": "1-7", "pedidos": 243, "valor": 3070772.37 }, { "faixa": "8-30", "…": "…" }, { "faixa": "31-90" }, { "faixa": "90+" } ],
  "atrasados": [ { "id": "…", "numero_pedido": "44568", "data_previsao": "2026-08-12", "dias_atraso": 49, "valor_pendente": 29993572.14,
                   "itens_pendentes": 1, "codigo_fornecedor": "9764283146", "nome_fornecedor": "BENAFER" } ],
  "por_etapa": [ { "etapa": "15", "etapa_descricao": null, "pedidos": 4758, "pedidos_pendentes": 1654, "valor_pendente": 47348660.13 } ]
}
```

- `serie_mensal`: sempre 12 meses terminando no mês de `data_fim`, mês sem pedido com zero.
- `por_fornecedor` e `por_categoria`: 10 maiores; `por_comprador`: 15; `maiores_pedidos`: 5;
  `atrasados`: 10 (maior valor pendente primeiro). `atraso_por_faixa`: sempre as 4 faixas.
- Valores numéricos como `number` (não string). Tempo medido no local: 0,2–0,4 s.

## 3. Perguntas em aberto

- **Dois pedidos da BENAFER de agosto somam R$ 82,7 mi** (44333 = R$ 52.745.954,19 e 44568 =
  R$ 30.023.595,74), mais da metade de tudo que foi comprado no banco. Parece valor digitado errado no
  Omie; distorce agosto e o "a receber atrasado" (o 44568 sozinho é R$ 30 mi pendente). **Conferir no
  Omie.** O dashboard não esconde: eles aparecem nos "maiores pedidos".
- **Etapas do pedido de compra do Omie (10, 15, 20) sem nome**: `pedidos_compras_etapas` está vazia.
  Pelo recebimento, a 15 é onde o material chega; a 10 e a 20 não têm nada recebido. Se a 20 for
  **cancelado**, ela não deveria contar em "comprado" nem em "atrasado" — confirmar e preencher a
  de-para (o dashboard mostra a etapa pelo código até lá).
- Default de `origem` segue a flag, como a listagem. Se a flag for ligada na api-test/produção, o
  av-hub pode deixar de mandar `todas`.

## 4. Depois de aplicado (av-hub)

- Dashboard de compras (`components/Painel/PainelCompras.tsx`) passa a mostrar os blocos acima, pelo
  BFF `/api/compras/dashboard` (branch `feat/dashboard-compras` do av-hub).

## 5. Aceite

- Setembro/2026, todas as unidades: `valor_comprado` = soma de `valor_total_brl` das linhas `aprovado`
  da view com dia (SP) em setembro (conferido: R$ 12.280.273,43, 1.220 pedidos).
- Filtrar por Uberaba só traz pedidos de Uberaba (conferido: 2026 = R$ 490.158,73, 232 pedidos).
- `data_inicio > data_fim` ou formato errado → 400 com mensagem.
- Nenhuma rota existente muda.
