---
id: LOG-61
aliases: ["Contrato 61", "61-Custo-Real-do-Pedido-Telas"]
tags: [contrato, contrato-logica, hub-front, compras, custo-real, meus-pedidos, divergencia]
criado: 2026-10-21
atualizado: 2026-10-21
status: proposta
sistemas: [hub-front]
dono: "Nathan"
etapa_0b: [C6, C7, C8, K2]
fontes: ["Registro-de-Decisoes (N16-60 a N16-73)", "API-019-Proposta-e-Pedido-de-Venda-na-API-do-Hub (§3.3, §3.4)", "API-021-Custo-Real-por-Evento-e-Conferencia-de-Compras", "13-Custo-Real-e-Comissao-no-Fluxo", "LOG-47-Custo-Real-por-Item-no-Hub"]
criado_original: 2026-10-21
---

# Contrato 61 — telas do custo real: conferência de Compras, Meus Pedidos (aprovação do vendedor) e lista de reprovados

> **Onde atua:** av-hub: front (Compras e Vendas)

> [!info] Situação em 21/10/2026
> **Status:** `proposta` · **Dono:** Nathan · Rotas: [[API-019-Proposta-e-Pedido-de-Venda-na-API-do-Hub]] e [[API-021-Custo-Real-por-Evento-e-Conferencia-de-Compras]]. A tela **Meus Pedidos** já existe e outra frente a evolui (encerramento por saldo zerado, PR em andamento): a área de pendências é nova e **não** deve colidir com ela.

## 1. Por quê

Quando Compras compra por mais que o valor da proposta, o vendedor aprova ou reprova, porque a margem e a comissão dele caem (N16-60, N16-61). Compras também precisa conferir e editar impostos antes de emitir a OC e ver os casos reprovados sem solução.

## 2. Telas 🟡

| Tela | Quem | Conteúdo |
|---|---|---|
| **Emitir OC com dados da proposta** (`C6`, `C7`) | Comprador | o sistema puxa impostos, frete e fornecedor da proposta; o Comprador confere, **edita os campos de imposto** (voltam ao Omie na sincronização da OC), valida se segue ou busca valor ou condição melhor; leitura da proposta, **sem poder alterá-la** |
| **Meus Pedidos, área de pendências** (`C8`) | vendedor | por **produto**: PV e OC, **margem atual** (do simulador), **margem considerada** (da compra real), **motivo da divergência** escrito por Compras, **diferença** entre custo considerado e realizado, **fornecedor** com prazo e pagamento; botões **Aprovar** e **Reprovar**; sem tempo limite; compra mais barata aparece só como informação |
| **Reprovados sem solução** | Comprador, Gerente de Compras, Controladoria (vê) | lista com a **idade** de cada caso, quem assumiu, ação **Assumir** e **Resolver** (novo valor, novo fornecedor, mantido ou pedido cancelado, com texto); ao resolver, o vendedor é notificado |
| **Tarja de pedido cancelado** | requisição do PCP, OC, PCP | a tela mostra uma tarja "pedido cancelado" com motivo e data; a requisição e a OC não emitida estão canceladas |
| **Custo real do pedido** | Compras, Controladoria | custo por item e por evento; parcial até cobrir a quantidade; **o vendedor não vê** |
| **Aprovar OC** (hoje "Aprovações" em Compras) | aprovador da unidade | só renomeia: OCs acima do limite da unidade. Evita confundir com a pendência do vendedor (`C8`), que fica em **Meus Pedidos** |
| **Fila do Fiscal** | Fiscal, Controladoria | devoluções parciais marcadas no Omie e pedidos cancelados; reaproveita a lista "Pedidos de Venda" (que já traz Cancelado, Devolvido e Devolução Parcial do Omie) |

## 3. Regras de tela

1. A Gerência **não tem botão**: a aprovação dela é conversa física com Compras (N16-66); a tela só mostra que o caso está reprovado e em tratativa.
2. O vendedor só vê a notificação da solução e resolve fisicamente; **sem botões** de corrigir, renegociar ou cancelar (N16-67).
3. Uma OC com itens de vendedores diferentes mostra a cada um só os produtos dele.
4. Pedido cancelado: botão de nova divergência desaparece.

## 4. Aceite

1. Compras registra uma compra acima: o vendedor dono vê a pendência com todos os campos; outro vendedor não vê.
2. Aprovar a leva a `APROVADO` e a margem e a comissão recalculam; reprovar a leva à lista de Compras.
3. Compras resolve com texto e o vendedor recebe a notificação.
4. Compra mais barata não cria pendência.
5. Pedido cancelado mostra a tarja na requisição e na OC.

## Ver também

[[API-019-Proposta-e-Pedido-de-Venda-na-API-do-Hub]] · [[API-021-Custo-Real-por-Evento-e-Conferencia-de-Compras]] · [[SQL-016-Proposta-e-Pedido-de-Venda-em-core_vendas_faturamento]] · [[LOG-56-Fluxo-da-Proposta-ao-Pedido]] · [[LOG-59-Telas-da-Comissao-Nova]] · [[13-Custo-Real-e-Comissao-no-Fluxo]]
