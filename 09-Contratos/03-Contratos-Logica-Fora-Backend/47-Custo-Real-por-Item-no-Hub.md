---
tags: [contrato-logica, av-hub, comissao, compras, orcamento, custo]
status: para-implementar
criado: 2026-10-09
atualizado: 2026-10-09
---

# Contrato 47 — Custo real por item no av-hub: simulador (etapa 2), comissão por faturamento (etapa 3), Compras e Orçamento

> **Status: `para-implementar`, Ciclo 2** (dono: Comercial & Suprimentos; quem executa é decisão do Nathan). Depende de [[008-Custo-do-Lote-no-MES]] (`GET /itens/custo`) e de [[007-Referencia-OC-Valores-no-MES]]. Desenho: [[Estoque-Custo-do-Lote]]. **Nada de comissões é alterado antes do Ciclo 2** (item 90 do [[Registro-de-Decisoes-2026-10-07]]); este contrato só fixa o que o hub fará.

## 1. Job de leitura (mesmo molde do [[006-Status-por-Item-Leitura-no-Hub]])

Job do hub lê `GET /itens/custo` do MES (cursor `alterado_desde` + `apos_id`, chave de serviço) e grava em `core_vendas_faturamento.itens_pedido_custo` 🟡 (chave filial + pedido + item; colunas do JSON do contrato 008, `lotes` em `jsonb`) por função de banco, como em `fn_itens_pedido_status_gravar`. Rota `GET /itens_pedido_custo?numero_pedido=` com o escopo "dono" do pedido (mesmo do contrato 40) e permissão de tela própria: **custo é dado sensível; o vendedor não vê o custo, só o resultado (letra e %)**. 🔴 Nathan confirma.

## 2. Etapa 2 — simulador pré-preenchido

No [[AV-Hub-Simulador-Comissao]], o custo líquido do item vem de `itens_pedido_custo.custo_medio` quando `completo = true`; Compras abre a simulação, **confere e confirma** (hoje digita). Item sem custo completo segue digitado. Grava no `simulacao_item` existente (`core_comissionamento`) a origem do custo (`orcado`, `mes`, `compras`).

## 3. Etapa 3 — comissão por faturamento

A cada NF faturada de um pedido cujos itens da NF tenham custo completo: `custo da NF = Σ (qtd faturada do item × custo_medio)` (**regra A**); margem do pedido → letra → % (tabela do simulador) sobre o valor faturado. Guarda o cálculo por NF (`comissao_provisoria`, schema `core_vendas_faturamento`), sem recalcular NF antiga se o custo do lote mudar depois. Pedido sem custo completo segue a etapa 2. Fabricação: 2% fixos. Devolução: Ciclo 2 (item 31 do Registro).

## 4. Compras e Orçamento (mesmo dado)

- Compras: nas telas de OC e requisição, comparar `valor_unitario` da OC com o custo real do lote e com o orçado.
- Orçamento (Comercial & Suprimentos): `vw_historico_precos` (hoje `valor_unidade` de cotações do Omie) ganha a fonte "custo real recebido" (preço pago por produto/fornecedor/data, do lote ou da OC), para sugerir custo nos orçamentos.
- Nada disso exige novo dado no MES: usa os campos do 007 e do 008.

## Aceite

1. Pedido de revenda com custo completo: o simulador abre com o custo e o vendedor não o enxerga.
2. NF parcial de 10 das 20 flanges: custo do faturamento = 10 × 11,75 = 117,50; uma segunda parcial de 10 usa o mesmo custo médio.
3. Pedido com item sem custo: nada é calculado automaticamente.
4. O histórico de preços lista o preço pago em USD já convertido, com a data da PTAX.

## Perguntas em aberto 🔴
Quem executa (Pablo/Comercial & Suprimentos ou outro); permissão de custo; fonte do imposto por item; se a etapa 3 paga a diferença quando o custo do lote for corrigido depois da NF (proposta: não).

## Ver também
[[Estoque-Custo-do-Lote]] · [[AV-Hub-Comissao-Modulo]] · [[AV-Hub-Simulador-Comissao]] · [[008-Custo-do-Lote-no-MES]] · [[40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]]
