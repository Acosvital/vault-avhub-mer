---
id: API-021
aliases: ["Contrato API 017", "017-Custo-Real-por-Evento-e-Conferencia-de-Compras"]
tags: [contrato, contrato-api, custo-real, compras, oc, nf-de-entrada, omie, impostos, api-acos-vital, pipeline]
criado: 2026-10-21
atualizado: 2026-10-21
status: proposta
sistemas: [hub-api, pipeline, mes-api]
dono: "Nathan, Gustavo e Robert"
etapa_0b: [C6, C7, R0, R4, K2]
fontes: ["13-Custo-Real-e-Comissao-no-Fluxo", "SQL-016-Schema-core_comercial-Proposta-e-Pedido-de-Venda (custo_evento, fn_custo_evento_*)", "LOG-56-Fluxo-da-Proposta-ao-Pedido (R27 a R34, R47 a R49)", "Estudo-Omie-API (pedido de compra, RecebimentoNFe, ListarNF)", "Registro-de-Decisoes (N16-09, N16-20, N16-22, N16-23, N16-37, N16-38, N16-40, N16-53, N16-57)", "LOG-47-Custo-Real-por-Item-no-Hub"]
criado_original: 2026-10-21
---

# Contrato API 017 — custo real por evento, impostos da OC vindos do Omie e conferência de Compras

> **Onde atua:** av-hub: API · pipeline Omie · MES (requisição e recebimento)

> [!info] Situação em 21/10/2026
> **Status:** `proposta` · **Donos:** Nathan (pipeline e telas), Gustavo (banco e revisão), Robert (requisição e lote) · Banco: [[SQL-016-Schema-core_comercial-Proposta-e-Pedido-de-Venda]]
>
> - ✅ Existe hoje: `custo-itens` e LOG-47 (custo por item). 🔴 Não existe: eventos por OC e NF de entrada, campos de imposto na OC, vínculo da NF ao item.

## 1. Por quê

O custo real do item é a soma de eventos (OC, lote do Estoque, matéria-prima, mão de obra) e, no recebimento, o valor da **NF de entrada** substitui o da OC. Hoje a OC do hub não guarda IPI, ICMS, ST nem DIFAL por item (N14-23): o **Omie guarda** ICMS, ST, IPI, PIS e COFINS por item do pedido de compra, **em valor e sem DIFAL**. É preciso trazer isso ao hub e levar de volta o que Compras editar.

## 2. O que a API faz

| # | Função | Regra |
|---|---|---|
| 1 | **Eventos de custo**: grava `custos_eventos` por OC aprovada (valor da OC, provisório), lote do Estoque e matéria-prima; mão de obra pela categoria da OC ("Despesas com Industrialização" ou "Serviços Tomados" quando o "Nº do Pedido do Fornecedor" aponta um PV) | Só se insere; OC cancelada antes de receber estorna a linha; o lote é de uma OC específica e **não soma o custo de novo** (N16-37, N16-40) |
| 2 | **NF de entrada substitui a OC** no recebimento, com o valor e os impostos reais da nota (`RecebimentoNFe`, `dRec`, `ListarNF`) | A maioria dos materiais é comprada por KG pelo peso teórico; a NF pode divergir da balança (N16-37) |
| 3 | **Vínculo da NF de entrada à OC**: o **CCP** (equipe do PCP do follow-up) vincula, na tela de Follow-up; o item do pedido vem do vínculo da OC com a requisição; o Omie não liga NF ao item da OC nem informa quantidade devolvida; vale para várias NFs por OC e KG contra PC (N16-57, N16-86). A **data do CCP** é a que vale e ele não sobrescreve a previsão de faturamento do pedido | ✅ OQ-34 e OQ-39 respondidas; 🟡 confirmar o campo da data |
| 4 | **Imposto da OC**: a pipeline traz do Omie os campos de imposto do pedido de compra; o hub ganha campos de ICMS, ST, IPI, PIS, COFINS (valor) por item, pré-preenchidos com os da proposta; Compras confere e edita; **o que edita volta ao Omie pela mesma sincronização da OC** (`envioOrdensCompra.ts`) | N16-38, N16-53 |
| 5 | **Conferência de Compras (`C6`, `C7`)**: `GET /comercial/propostas/:id/compras` puxa impostos, frete e fornecedor da proposta; Compras valida se segue ou busca valor ou condição melhor; **Compras não altera a proposta** | N16-08 |
| 6 | **Aviso `C8`**: quando o valor da OC por produto passa do valor da proposta, a API chama o registro da divergência ([[API-019-Proposta-e-Pedido-de-Venda-na-API-do-Hub]] §3.3) | N16-60 a N16-67 |
| 7 | **Evento com as suas condições** (condição de pagamento, IPI, ICMS, ST, frete, fornecedor); o custo líquido sai da fórmula do motor com as condições do próprio evento; imposto ausente: o evento calcula "sem imposto" e a Controladoria vê a marca; **DIFAL da compra fica fora** do custo líquido (provisório) | N16-20, N16-22, N16-51 |
| 8 | Notifica a comissão ([[API-022-Comissao-da-Proposta-Calculo-e-Decisao-da-Controladoria]]) para recalcular com o novo custo real | enfileira em `comissao_fila_recalculo` |

## 3. Rotas 🟡

`GET /compras/ordens-compra/:id/impostos` e `PUT` (Compras edita); `POST /integracao/oc/impostos-omie` (a pipeline entrega os valores lidos do Omie); `POST /comercial/nf-entrada/:id/vinculo` `{ id_item_pedido, quantidade }` (PCP); `GET /comercial/pedidos_venda/:id/custo` (Compras e Controladoria; **o vendedor não recebe o custo real**); `POST /integracao/custo/lotes` (Estoque informa o lote e o custo). Nomes finais são do Gustavo e do Nathan.

## 4. Regras de acesso

O vendedor não vê o custo real nem o drill-down por evento. Compras vê o das OCs dele; o Gerente de Compras e a Controladoria veem tudo.

## 5. Fora do contrato

A devolução de **compra** e o efeito na linha de custo (adiada, OQ-42); as sobras de chapa (OQ-32); a conversão de unidade (Compras segue sem converter no sistema).

## 6. Aceite

1. OC aprovada gera um evento com o valor da OC; ao receber, o evento passa a usar o valor da NF de entrada.
2. OC cancelada antes de receber estorna a linha e o item volta a parcial.
3. O que Compras edita no imposto da OC chega ao Omie na sincronização seguinte.
4. Um item de 50 unidades com 3 OCs de condições diferentes soma 3 eventos, cada um com o seu custo líquido.
5. Compra por valor acima do da proposta gera a divergência `PENDENTE` para o vendedor dono do item.
6. Evento sem imposto aparece "sem imposto" para a Controladoria e não quebra o cálculo.

## 6.1 Testes no Omie pendentes

Sem ambiente de teste, os cadastros TESTE são no ambiente real: campos de imposto na gravação do pedido de compra, `dRec` e o que o `ListarNF` devolve para entrada.

## 7. Perguntas em aberto

OQ-11 (respondida: vem do Omie), OQ-34 e OQ-39 (vínculo e unidade), OQ-32, OQ-42, OQ-38.

## Ver também

[[13-Custo-Real-e-Comissao-no-Fluxo]] · [[SQL-016-Schema-core_comercial-Proposta-e-Pedido-de-Venda]] · [[API-019-Proposta-e-Pedido-de-Venda-na-API-do-Hub]] · [[API-022-Comissao-da-Proposta-Calculo-e-Decisao-da-Controladoria]] · [[LOG-47-Custo-Real-por-Item-no-Hub]] · [[Estudo-Omie-API]]
