---
id: LOG-59
aliases: ["Contrato 59", "59-Telas-da-Comissao-Nova"]
tags: [contrato, contrato-logica, hub-front, comissao, controladoria, telas, devolucao]
criado: 2026-10-21
atualizado: 2026-10-21
status: proposta
sistemas: [hub-front]
dono: "Nathan"
etapa_0b: [K1, K2, K3, K4, K5, K6]
fontes: ["Registro-de-Decisoes (N16-10, N16-19, N16-44 a N16-51, N16-74)", "09-Diagramas/fontes/tela-simulador-comissao.png", "av-hub app/(protected)/comissoes/simulador/page.tsx, lib/simulador/motor.ts", "API-022-Comissao-da-Proposta-Calculo-e-Decisao-da-Controladoria", "SQL-018-Schema-core_comissao-Comissao-da-Proposta"]
criado_original: 2026-10-21
---

# Contrato 59 — telas da comissão nova (vendedor, Controladoria, Gerência, Coordenação, Fiscal)

> **Onde atua:** av-hub: front (Operações)

> [!info] Situação em 21/10/2026
> **Status:** `proposta` · **Dono:** Nathan · Rotas: [[API-022-Comissao-da-Proposta-Calculo-e-Decisao-da-Controladoria]] · O módulo **Comissões atual não muda**; as telas novas ficam ao lado, em Operações (N16-11).

## 1. Por quê

A comissão nova tem três públicos e uma tela-base: a do Simulador de Comissão (N16-19). O vendedor vê só a estimativa dele; a Controladoria, a Gerência e a Coordenação decidem; o Fiscal informa a devolução parcial.

## 2. Telas 🟡

| Tela | Quem | O que mostra e faz |
|---|---|---|
| **Comissão na proposta** (dentro da proposta, formato do Simulador) | vendedor | blocos Pedido, Condições comerciais (destino e ICMS, condição de pagamento e encargo, "com impostos", frete na compra com rateio, ST, imposto retido ou DIFAL, frete na venda), Itens (Compra, Venda, Resultado) e rodapé de totais (custo, venda, total da NF, sugerido, mark-up real, mark-up sobre a compra, margem e letra). Só a comissão estimada que ele colocou |
| **Minhas Comissões** (nova) | vendedor | só o que foi decidido, com o valor real e a **justificativa**; desaprovada com R$ 0 e o motivo (`K5`); lançamentos (complemento, desconto, abatimento) com o motivo; **nunca** o custo real, o drill-down ou a queda por custo |
| **Decisão da Comissão** | Controladoria, Gerência, Coordenação | fila de NFs (`vw_comissao_nf_fila`) com a mesma tela da proposta em modo leitura e a **verdade na tabela**: custo líquido real, margem real, letra real e comissão real **lado a lado com os estimados**, por item e no total; marca "custo parcial", "sem imposto", "cotação a conferir"; ações aprovar, desaprovar, bloquear, desbloquear, cortar, alterar (valor ou percentual, sem teto) com justificativa obrigatória; esconde a ação quando a comissão é do próprio usuário |
| **Drill-down por evento** | Controladoria, Gerente de Compras, Comprador (das OCs dele) | uma linha por evento: origem, documento, fornecedor, condição de pagamento, imposto, frete, custo líquido |
| **Devoluções pendentes** | Fiscal, Controladoria | fila de devolução parcial marcada no Omie (NF, valor faturado, idade); formulário para informar itens, quantidades e valores; mostra o abatimento proporcional antes de confirmar (`K6`) |
| **Visão Geral** | Controladoria, Gerência | lista por mês, vendedor, unidade e status, com Excel; markup real por vendedor; Faturamento × Compras por pedido (Revenda, Industrializado, Projeto); valor retido separado do valor a pagar |
| **Parâmetros** | Controladoria | parâmetros com vigência (Maio/23 continua), faixas, regras fixas por cliente, listas de bloqueio, coordenadores |

## 3. Regras de tela

1. O botão de decisão é desligado na comissão do próprio usuário; o servidor recusa também (403).
2. Toda ação grava rastro e mostra a justificativa; o vendedor vê depois da decisão.
3. O passo "Comissão: após a aprovação de Compras" do Simulador **não aparece**; fica pronto e desligado (N16-51).
4. A tela da proposta é a única a calcular em tempo real; os valores reais são lidos da API.
5. Comissão excluída por lista de bloqueio aparece com R$ 0 e o motivo, nunca some.

## 4. Fora do contrato

Apuração do vendedor e o dia de pagamento (OQ-41), descontos de convênio (OQ-42), CBS (OQ-44).

## 5. Aceite

1. Com os mesmos dados de um caso do Simulador, a tela da proposta mostra a mesma margem, letra e comissão.
2. O vendedor não vê coluna real antes da decisão; depois vê o valor e a justificativa.
3. A Controladoria vê estimado e real lado a lado e abre o drill-down.
4. Um perfil sem a permissão de decidir não vê as ações; o usuário dono da comissão não decide.
5. O Fiscal informa a devolução parcial e a pendência sai da fila.

## Ver também

[[API-022-Comissao-da-Proposta-Calculo-e-Decisao-da-Controladoria]] · [[SQL-018-Schema-core_comissao-Comissao-da-Proposta]] · [[LOG-56-Fluxo-da-Proposta-ao-Pedido]] · [[13-Custo-Real-e-Comissao-no-Fluxo]] · [[LOG-60-Matriz-de-Precos-e-Consulta-do-Vendedor]] · [[LOG-61-Custo-Real-do-Pedido-Telas]]
