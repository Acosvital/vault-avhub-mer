---
id: API-017
aliases: ["Contrato 017", "017-Carteira-do-PCP-Periodo-e-Previsao"]
tags: [contrato, contrato-api, pcp, carteira, dashboard, previsao, faturamento, av-hub]
criado: 2026-10-22
atualizado: 2026-10-22
status: aplicado-em-producao
sistemas: [hub-banco, hub-api, hub-front]
dono: "Gustavo"
etapa_0b: []
fontes: ["Pedido do Nathan de 22/10/2026", "api-acos-vital commit 115e9b8 (Contrato SQL 015: /pedidos_venda/carteira, /carteira/vendedores, marcacao)", "api-acos-vital src/schemas/core_vendas_faturamento/aggregates/pedidos_venda/pedidos_venda.route.js", "api-acos-vital src/middlewares/escopoVendedor.js (ehCarteira)", "av-hub PR #238 (front da carteira, mergeado em 22/10/2026)", "conferência na API normal em 22/10/2026 (carteira 875 pedidos x 720 pedidos do mês x 479 abertos do mês)"]
criado_original: 2026-10-22
---

# Contrato de API 017 — Carteira do PCP por período e previsão de faturamento por mês

> **Onde atua:** av-hub: banco, API, front

> [!info] Situação em 22/10/2026
> **Status:** `aplicado-em-producao` · **Pasta:** `Entregues` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Gustavo (banco e API); Nathan (front)
>
> - 📝 **Pedido do Nathan, 22/10/2026:** (1) os números da **Carteira** do Dashboard PCP mudam conforme a data do seletor (mês ou "todo o período"); (2) mostrar o que há para faturar até o fim do mês e, depois, todos os meses que tiverem algo a faturar.
> - ✅ **Banco e API (Gustavo)**, `api-acos-vital` commit `8aa3ca6` (22/10/2026): `por_periodo`, `data_inicio` e `data_fim` em `/pedidos_venda/carteira` e `/carteira/vendedores`, e a rota `GET /pedidos_venda/carteira/previsao` (`fn_carteira_pcp_previsao`, migration api017).
> - ✅ **Front no `av-hub`** (`develop`): a carteira manda o período do seletor (PR #240), cartão "A faturar até o fim do mês" e bloco "Previsão de faturamento" (PRs #241 e #244) e a rota do BFF da previsão (PR #245).
> - ✅ **Aceite conferido na produção em 22/10/2026** (outubro, só leitura): sem `por_periodo` a carteira segue inteira (890 pedidos, R$ 77.911.980,65); com `por_periodo`, `carteira_pedidos` = 498 = `total` de `GET /pedidos_venda?carteira=true` no mesmo período, e `desvio_pedidos` = 156 = o da lista com `desvio=true`; a soma por vendedor bate (498 pedidos, R$ 17.899.962,22, 91 atrasados, 156 em desvio); `/carteira/previsao` tem `total_valor` igual a `carteira_valor` (com e sem `por_periodo`) e só traz meses com saldo.
> - **MES (Robert): sem trabalho.**
>
> Selos em [[Regras-do-Vault]].

## Por quê

O Dashboard PCP mostra o mês no topo e uma carteira sem mês embaixo, e os números não conversam (875 contra 720). O diligenciador também precisa responder "quanto vou faturar este mês e nos próximos?", que a carteira de hoje não separa: tudo que tem saldo aberto está num número só, sem dizer **quando** deve ser faturado. Este contrato resolve as duas coisas com a mesma base: a carteira (saldo das parcelas abertas) **recortada pelo período do seletor** e **aberta por mês de previsão**.

## Regras de negócio

1. **Carteira** continua sendo o **saldo das parcelas abertas** de pedidos de vendedor do escopo, como no Contrato SQL 015 (mesmas definições de no prazo, atrasados, sem previsão, desvio e avanço). Nada disso muda.
2. **Recorte por período (novo, opcional):** quando o chamador manda `por_periodo=true`, só entram pedidos cuja **data de inclusão** está entre `data_inicio` e `data_fim` (inclusive), **a mesma regra da lista** (`GET /pedidos_venda?carteira=true&data_inicio=…`). Sem `por_periodo`, o comportamento é o de hoje: carteira inteira. Ninguém que já usa as rotas é afetado.
3. **O recorte vale para tudo:** os totais da carteira, a carteira por vendedor e a previsão por mês usam **o mesmo filtro**, para que **a soma de uma bata com a outra** (ver Aceite).
4. **Previsão de faturamento por mês (novo):** o saldo de cada parcela aberta cai no **mês da sua `data_previsao`**. Parcela sem previsão vai para um grupo à parte (`sem_previsao`). Meses **passados** (previsão antes do mês corrente) aparecem como qualquer outro mês, e o que está **atrasado** é dito em cada linha (`atrasados_*`), porque no mês corrente há parcelas no prazo e atrasadas ao mesmo tempo.
5. **Só aparecem meses com saldo** a faturar (valor maior que zero); mês sem nada não vem na resposta.
6. **Quantidade de pedidos não soma entre meses:** um pedido com parcelas em dois meses conta em **cada** um deles (como "no prazo" e "atrasados" já funcionam na carteira). O **valor** soma exatamente a `carteira_valor`.
7. **Escopo e permissão:** iguais aos de `GET /pedidos_venda/carteira`: filtro por vendedor do token (middleware `escopoVendedor`, que já trata `/pedidos_venda/carteira/*` como lista pelo parâmetro de vendedor) e `is_track_record` como nas demais rotas. Nenhuma linha nova de `auth.rotas_telas` se a tela já cobre `/pedidos_venda/carteira*`; 🟡 Gustavo confirma se o mapa de rotas usa prefixo ou rota exata.

## 1. Banco (Gustavo): migration

Schema `core_vendas_faturamento`.

### Funções existentes: parâmetros novos

`fn_carteira_pcp_resumo` e `fn_carteira_pcp_vendedores` ganham **`p_inclusao_inicio date`** e **`p_inclusao_fim date`**, ambos com `DEFAULT NULL` (nulo = sem recorte, igual a hoje). Quando não nulos, a função só considera pedidos cuja `data_inclusao` (🟡 hoje `varchar(10)` em `pedidos_vendas`; converter com o mesmo cast que `fn_pedidos_venda` usa) está entre os dois.

> [!warning] Mudar a assinatura exige `DROP FUNCTION` + `CREATE`
> Acrescentar parâmetros a uma função cria uma **segunda** função com outra assinatura e deixa a chamada antiga ambígua. Fazer `DROP` da assinatura antiga e `CREATE` da nova na mesma migration, como no LOG-48 §12.2, e conferir o `GRANT`.

### Função nova `fn_carteira_pcp_previsao`

Mesmos parâmetros da `fn_carteira_pcp_resumo` (`is_track_record`, empresa, vendedores, `desvio_dias`, `p_inclusao_inicio`, `p_inclusao_fim`). Devolve **uma linha por mês de previsão** (`date_trunc('month', data_previsao)`) com saldo aberto, mais **uma linha** para `sem previsão` (`mes` nulo):

| Coluna | Regra |
|---|---|
| `mes` | primeiro dia do mês da previsão (`date`); nulo = sem previsão |
| `valor`, `pedidos` | saldo das parcelas abertas com previsão nesse mês; pedidos distintos |
| `atrasados_valor`, `atrasados_pedidos` | a parte desse mês com previsão **anterior a hoje** (zero nos meses futuros) |

Ordenada por `mes` crescente, `sem previsão` por último.

## 2. API (Gustavo)

### 2.1 `GET /pedidos_venda/carteira` e `GET /pedidos_venda/carteira/vendedores`: recorte por período

Parâmetros novos (os demais ficam como estão):

| Parâmetro | Tipo | Regra |
|---|---|---|
| `por_periodo` | booleano | `true` liga o recorte por data de inclusão. Padrão `false` (carteira inteira) |
| `data_inicio`, `data_fim` | data `AAAA-MM-DD` | o intervalo da inclusão; com `por_periodo=true` e sem datas, vale o **mês corrente** (como `parsePeriodo` na lista); `data_fim` antes de `data_inicio`: `400` |

- `/carteira/vendedores` já lê `data_inicio`/`data_fim` para `pedidos_mes`. Isso **continua igual**, mesmo sem `por_periodo`. Só com `por_periodo=true` as colunas da carteira (`carteira_*`, `no_prazo_*`, `atrasados_*`, `desvio_*`, `avanco_*`) passam a considerar o recorte; vendedor sem saldo no recorte **não** vem.
- A resposta de `/carteira` passa a trazer `por_periodo` (booleano), `data_inicio` e `data_fim` (nulos quando não há recorte). A de `/carteira/vendedores` já traz as datas e ganha `por_periodo`.

```json
{
  "carteira_valor": 31204511.90, "carteira_pedidos": 479,
  "no_prazo_valor": 26880100.10, "no_prazo_pedidos": 301,
  "atrasados_valor": 4324411.80, "atrasados_pedidos": 190,
  "sem_previsao_valor": 0, "sem_previsao_pedidos": 0,
  "desvio_valor": 6927562.04, "desvio_pedidos": 198,
  "avanco_valor": 0, "avanco_pedidos": 0, "avanco_faturado_valor": 0,
  "desvio_dias": 10, "is_track_record": false,
  "por_periodo": true, "data_inicio": "2026-10-01", "data_fim": "2026-10-31"
}
```

(Os valores do exemplo são ilustrativos.)

### 2.2 `GET /pedidos_venda/carteira/previsao`: previsão de faturamento por mês

Parâmetros: os mesmos de `/carteira` (`codigo_empresa`, `vendedor`/`codigo_vendedor`, `is_track_record`, `desvio_dias`, `por_periodo`, `data_inicio`, `data_fim`). Rota de **caminho fixo**, declarada antes de `/:codigo_empresa/:pedido_venda`. Resposta `200`:

```json
{
  "meses": [
    { "mes": "2026-09", "valor": 3120400.00, "pedidos": 41, "atrasados_valor": 3120400.00, "atrasados_pedidos": 41 },
    { "mes": "2026-10", "valor": 18450210.55, "pedidos": 212, "atrasados_valor": 1204411.80, "atrasados_pedidos": 23 },
    { "mes": "2026-11", "valor": 9033100.20, "pedidos": 118, "atrasados_valor": 0, "atrasados_pedidos": 0 }
  ],
  "sem_previsao": { "valor": 0, "pedidos": 0 },
  "total_valor": 30603710.75,
  "por_periodo": true,
  "data_inicio": "2026-10-01",
  "data_fim": "2026-10-31",
  "is_track_record": false
}
```

- `mes` no formato `AAAA-MM`, em ordem crescente; só meses com saldo (regra 5).
- `total_valor` = soma de `meses[].valor` + `sem_previsao.valor` = `carteira_valor` de `/carteira` com os **mesmos** parâmetros.
- Valores como número (não texto), como as demais rotas da carteira; erros de parâmetro `400 { detail }`.

### 2.3 Escopo do vendedor (`escopoVendedor.js`)

Nada novo: o desvio `ehCarteira` (`segs[1] === "carteira"`) já cobre `/pedidos_venda/carteira/previsao` como lista filtrada pelo parâmetro de vendedor. 🟡 Gustavo confere que a rota nova **não** cai na conferência de dono do detalhe (3 segmentos), como já foi tratado para `/carteira/vendedores`.

## 3. Tela (Nathan)

Dashboard PCP, bloco **Carteira**:

| Bloco | O que muda |
|---|---|
| Totais e tabela por vendedor | passam `por_periodo=true` com o período do seletor (mês escolhido ou "todo o período"). O subtítulo diz o recorte ("pedidos incluídos em outubro de 2026"), e volta ao texto atual quando a API ainda não devolve `por_periodo` |
| **A faturar até o fim do mês** | cartão novo: soma de **todos os meses até o mês do seletor** (inclusive os atrasados de meses anteriores) e quantos estão atrasados |
| **Previsão por mês** | lista/gráfico de barras novo com **todos os meses que têm algo a faturar**, valor e pedidos por mês, a parte atrasada destacada e uma linha "Sem previsão" quando houver (sem link por mês: a lista de pedidos ainda não filtra por mês de previsão) |
| Sem a rota nova | o bloco de previsão some (sem erro na tela), como a carteira some quando a API não tem as rotas |
| Links dos cartões | passam a levar o **mesmo recorte** (período) para a lista de Pedidos PCP, para o número do cartão bater com o total da lista |

## Fora deste contrato

- **Previsão por semana ou por dia.**
- **Previsão por vendedor** (matriz vendedor x mês): a primeira entrega é o total.
- **Recorte por data de previsão** em vez de data de inclusão nos totais da carteira (o seletor filtra a **inclusão**, como a lista).
- **Meta de faturamento por mês** e comparação com o realizado.
- **Exportar** a previsão para Excel.

## Checklist

**Gustavo (banco e API)**
- [x] Migration: `DROP` + `CREATE` de `fn_carteira_pcp_resumo` e `fn_carteira_pcp_vendedores` com `p_inclusao_inicio`/`p_inclusao_fim` (`DEFAULT NULL`), e `GRANT`.
- [x] Função nova `fn_carteira_pcp_previsao` (uma linha por mês e uma sem previsão).
- [x] Rotas: `por_periodo`, `data_inicio` e `data_fim` em `/carteira` e `/carteira/vendedores` (com `por_periodo`/datas ecoados na resposta) e a rota `GET /carteira/previsao` antes de `/:codigo_empresa/:pedido_venda`.
- [x] Conferir `escopoVendedor.js` e o mapa de rotas (`auth.rotas_telas`) para `/carteira/previsao`.
- [x] Swagger das rotas e dos parâmetros novos.

**Nathan (front)**
- [x] BFF e serviço mandam `por_periodo` e o período; subtítulo conforme `por_periodo` da resposta.
- [x] Cartão "A faturar até o fim do mês" e bloco "Previsão por mês" (some sem a rota).
- [x] Cartões e meses levam o mesmo recorte à lista de Pedidos PCP.

**Robert (MES):** nada.

## Aceite

1. **Sem `por_periodo`**, `/carteira` e `/carteira/vendedores` respondem exatamente como hoje (em outubro: 875 pedidos na carteira inteira).
2. **Com `por_periodo=true` e outubro**, `/carteira` devolve `carteira_pedidos` igual ao `total` de `GET /pedidos_venda?carteira=true&data_inicio=2026-10-01&data_fim=2026-10-31` (479 na conferência de 22/10), e `desvio_pedidos` igual ao da lista com `desvio=true` no mesmo período.
3. **A soma por vendedor bate com o total** com o mesmo recorte: `carteira_pedidos`, `carteira_valor`, `atrasados_pedidos` e `desvio_pedidos` (como já bate na carteira inteira).
4. **`/carteira/previsao`:** `total_valor` é igual a `carteira_valor` de `/carteira` com os mesmos parâmetros, com e sem `por_periodo`.
5. **Meses:** só vêm meses com saldo; em ordem crescente; um mês sem nada não aparece; parcela sem previsão vai para `sem_previsao`.
6. **Atrasados:** `atrasados_valor` do mês corrente é só a parte com previsão anterior a hoje, e os meses futuros trazem zero.
7. **Pedido com parcelas em dois meses** conta em ambos (`pedidos` não soma entre meses; `valor` soma).
8. **Vendedor de escopo menor** vê só os seus pedidos nas três rotas; `is_track_record` e `codigo_empresa` filtram igual ao resto da carteira.
9. **Na tela:** trocar o mês do seletor muda os totais, a tabela por vendedor e a previsão; "A faturar até o fim do mês" mostra a soma dos meses até o escolhido; sem a rota nova, o bloco de previsão some e o resto continua.

## Ver também
[[API-016-Observacao-do-PCP-por-Item-do-Pedido]] · [[LOG-40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]] · [[LOG-48-Acompanhamento-de-Clientes-Grupos-de-Empresa]]
