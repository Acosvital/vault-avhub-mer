---
id: API-018
aliases: ["Contrato 018", "018-Carteira-Vencem-Hoje"]
tags: [contrato, contrato-api, pcp, carteira, dashboard, vence-hoje, atrasados, av-hub]
criado: 2026-10-22
atualizado: 2026-10-26
status: aplicado-em-producao
sistemas: [hub-banco, hub-api, hub-front]
dono: "Gustavo"
etapa_0b: []
fontes: ["Pedido do Nathan de 22/10/2026 (valor em Vencem hoje)", "API-017 (carteira por período e previsão)", "conferência na API normal em 22/10/2026 (carteira atrasados_pedidos 353 x lista prazo=atrasado 358)", "av-hub PR do Dashboard PCP com a carteira inteira"]
criado_original: 2026-10-22
---

# Contrato de API 018 — Carteira do PCP: "vencem hoje" em valor e atrasados conferidos com a lista

> **Onde atua:** av-hub: banco, API, front

> [!info] Situação em 26/10/2026
> **Status:** `aplicado-em-producao` · **Pasta:** `Entregues` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Gustavo (banco e API); Nathan (front)
>
> - ✅ **Implementado e aplicado (26/10/2026), informado pelo Gustavo** (dump de produção de 26/10): API no commit `b1bc564` e migration `api018` em produção. O 353 x 358 era o **pedido original zerado com previsão vencida** entrando como atrasado na lista; corrigido em `fn_pedidos_venda`. "Vence hoje" ficou como os pedidos cuja **parcela mais urgente** vence hoje, igual à lista `prazo=vence-hoje`.
> - ✅ **Conferido por mim em 26/10/2026** na API em uso pelo av-hub (perfil admin): `/carteira` traz `vence_hoje_pedidos` = 59 e `vence_hoje_valor` = R$ 1.087.534,20, iguais ao `total` e à soma do `valor_carteira` da lista `prazo=vence-hoje` (aceite 1) e abaixo de `no_prazo_valor` (aceite 2); `atrasados_pedidos` = 390 = `total` da lista `prazo=atrasado` (aceite 3), e com filtro de vendedor (Tiago Viana) 1 = 1 em atrasados e em vence hoje; `/carteira/vendedores` traz os campos e a soma por vendedor dá 59 e o mesmo valor. 🟡 Não olhei o cartão "Vencem hoje" na tela do Dashboard (aceite 4).
> - 📝 **Pedido do Nathan, 22/10/2026:** o cartão "Vencem hoje" do Dashboard PCP precisa mostrar **valor** (como "Atrasados" e "A faturar"), não só a quantidade.
> - 🕓 Registro de 22/10 (superado): **hoje** `GET /pedidos_venda/carteira` traz `atrasados_valor`/`atrasados_pedidos` e `no_prazo_*` (que **inclui** o que vence hoje), mas **nada separado para "vence hoje"**. O front só consegue a **quantidade** (pela lista, `GET /pedidos_venda?carteira=true&prazo=vence-hoje`, 20 pedidos em 22/10/2026) e **não** o valor: o `valor_carteira` de cada pedido da lista é o saldo do **pedido inteiro**, que superestima quando o pedido tem parcelas em outros dias (soma de 20 pedidos: R$ 420.417,73, sem saber quanto é da parcela que vence hoje).
> - ✅ **Diferença explicada e corrigida (26/10):** `/carteira` dizia **353** atrasados e a lista `prazo=atrasado` dizia **358** em 22/10; a causa era o pedido original zerado entrando como atrasado na lista (ver o primeiro item acima). Hoje os dois dão 390.
> - **MES (Robert): sem trabalho.**
>
> Selos em [[Regras-do-Vault]].

## Por quê

O Dashboard PCP mostra a carteira inteira ([[API-017-Carteira-do-PCP-por-Periodo-e-Previsao-de-Faturamento-por-Mes]]) e cada cartão leva à lista que o explica. Dois pontos quebram a leitura: "Vencem hoje" não tem valor (só quantidade), e a quantidade de atrasados do cartão (353) não é a que a lista mostra ao clicar (358).

## Regras de negócio

1. **Vence hoje** = parcela aberta cuja `data_previsao` é **hoje** (data de São Paulo). O valor é o **saldo dessas parcelas**, não o do pedido inteiro. O pedido que tem parcela vencendo hoje e outras em outros dias entra em "vence hoje" **só com a parte de hoje**.
2. **Vence hoje não soma com atrasados nem com o resto:** `no_prazo_*` continua incluindo o que vence hoje (como hoje: "no prazo = prazo >= 0"); os campos novos são um **recorte de dentro** do no prazo, não uma categoria nova.
3. **Quantidade de pedidos:** pedidos distintos com pelo menos uma parcela vencendo hoje (um pedido com parcelas em dois dias conta em cada um, como já acontece em no prazo e atrasados).
4. **Atrasados batem com a lista:** `atrasados_pedidos` de `/carteira` e o `total` de `GET /pedidos_venda?carteira=true&prazo=atrasado` (mesmo vendedor, mesma empresa, `is_track_record` e escopo) têm de ser o **mesmo número**. Onde a regra de um lado for diferente (ex.: o que a lista considera "atrasado" para o pedido e o que a função considera para a parcela), alinhar a função da carteira e a lista à mesma definição e **registrar a definição** na descrição da rota.
5. Escopo e permissão: os mesmos de `GET /pedidos_venda/carteira` (nenhuma linha nova de `auth.rotas_telas`).

## 1. Banco (Gustavo)

`fn_carteira_pcp_resumo` (e, se for simples, `fn_carteira_pcp_vendedores`) passa a devolver duas colunas a mais:

| Coluna | Regra |
|---|---|
| `vence_hoje_pedidos` | pedidos distintos com parcela aberta com previsão **hoje** |
| `vence_hoje_valor` | saldo dessas parcelas |

Mudar o `RETURNS TABLE` exige `DROP FUNCTION` + `CREATE` (como no API-017). Conferir também a definição de "atrasado" da função contra a da lista (regra 4).

## 2. API (Gustavo)

`GET /pedidos_venda/carteira` acrescenta `vence_hoje_pedidos` e `vence_hoje_valor` na resposta (números, não texto). Nada muda nos parâmetros. Exemplo:

```json
{
  "carteira_valor": 77823600.10, "carteira_pedidos": 887,
  "atrasados_valor": 14630000.00, "atrasados_pedidos": 358,
  "vence_hoje_valor": 215400.00, "vence_hoje_pedidos": 20
}
```

(Os valores do exemplo são ilustrativos.) `/carteira/vendedores` pode trazer os mesmos campos por vendedor, opcional.

## 3. Tela (Nathan)

O cartão "Vencem hoje" do Dashboard PCP já está pronto para os campos novos: com `vence_hoje_valor` mostra **R$ X · N pedidos**; sem eles (API de hoje), mostra só "N pedidos" (a quantidade vem da lista). Nada a mudar no front quando a API entregar.

## Checklist

**Gustavo (banco e API)**
- [x] `fn_carteira_pcp_resumo` com `vence_hoje_pedidos` e `vence_hoje_valor` (`DROP` + `CREATE`, `GRANT`).
- [x] `GET /pedidos_venda/carteira` devolvendo os dois campos; Swagger.
- [x] Conferir `atrasados_pedidos` da carteira contra o `total` da lista `prazo=atrasado` (353 x 358 em 22/10/2026) e alinhar a definição.

**Nathan (front):** nada (pronto para os campos novos).

**Robert (MES):** nada.

## Aceite

1. `vence_hoje_pedidos` de `/carteira` é igual ao `total` de `GET /pedidos_venda?carteira=true&prazo=vence-hoje`, e `vence_hoje_valor` é **menor ou igual** à soma do `valor_carteira` dos pedidos dessa lista (igual quando todo o saldo do pedido vence hoje).
2. `vence_hoje_valor` nunca passa de `no_prazo_valor`.
3. `atrasados_pedidos` de `/carteira` é igual ao `total` de `GET /pedidos_venda?carteira=true&prazo=atrasado`, com e sem filtro de vendedor.
4. No Dashboard PCP, o cartão "Vencem hoje" mostra valor e quantidade, e "Atrasados" mostra a mesma quantidade que a lista aberta pelo cartão.

## Ver também
[[API-017-Carteira-do-PCP-por-Periodo-e-Previsao-de-Faturamento-por-Mes]] · [[API-016-Observacao-do-PCP-por-Item-do-Pedido]]
