---
tags: [anexo, pedido-manual, vendas, av-hub, fora-do-fluxo]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Gustavo (DBA)
fontes: [api-acos-vital f322dcd pedidos_vendas.route.js e utils/pedidoVendaManual.js, conferência de 29/10/2026 em api-acos-vital develop 0384e89 e av-hub develop 758d5f0, HUB b55ac55, LOG-45, LOG-29]
---

# Pedido de venda manual

**Em uma frase:** cadastra um pedido de venda que não está no Omie, só para a parte comercial (dashboards e rankings).

**Quando consultar:** quando alguém pergunta por que um pedido "MAN-…" aparece nos números de venda mas não na fábrica.

Fora do fluxo 0b. O pedido manual **não percorre o MES**: sem liberação, sem Destinação, sem custo ([[Integracao-AvHub-MES]], "Outras pontes com o MES"). Contrato: [[LOG-45-Pedido-de-Venda-Manual]] (`implementado-no-codigo`). Até 28/10 o código chamava este assunto de "Contrato 30", que no vault é outro ([[LOG-30-Compras-Pedido-Omie-PDF-Completo]]); os comentários e o swagger passaram a citar o contrato 45 em 29/10 (`api-acos-vital` `0384e89`).

## Como funciona

- O pedido tem só o cabeçalho: sem itens e sem parcelas.
- O número é gerado como `MAN-nnnnnn`.
- Entra nos dashboards como venda líquida, sem passar pela cascata de deduções ([[Dashboards]]).
- Uma nota fiscal manual pode apontar para ele ([[LOG-29-Notas-Fiscais-Manuais-So-Admin]]).
- Nunca entra no custo por item.
- A exclusão é lógica: o registro some das telas, mas não é apagado.

## Pendências

- ✅ A API existe. ✅ O HUB **tem a tela** de pedido manual desde 30/10/2026 (N16-147): Cadastros › Auxiliares › Pedidos de venda manuais, no molde da nota manual, testada pelo Nathan.
- ❓ Gustavo confere em produção os gatilhos do banco e o mapa de permissões das rotas manuais.
- 🟡 Sem token, o autor do pedido é só um identificador informado no corpo (brecha herdada do contrato 29).

## Detalhe técnico

### Regras no código

| Regra | Selo |
|---|---|
| Rotas `POST /pedidos_vendas/manual`, `PUT` e `PATCH /manual/:codigo`, `DELETE /manual/:codigo`, `GET /manual/:codigo/historico` | ✅ `pedidos_vendas.route.js` |
| Permissão na tela `pedidos-vendas-manuais` (`pode_criar`, `pode_editar`, `pode_deletar`); trava fixa, sem chave de ambiente | ✅ `utils/pedidoVendaManual.js` |
| `codigo_pedido_omie` negativo por sequence; `numero_pedido` `MAN-nnnnnn` gerado por trigger; `sequencial` nulo; `codigo_empresa` obrigatório e imutável | ✅ `pedidos_vendas.route.js`; triggers do banco ❓ não versionados |
| Só cabeçalho: sem itens e sem parcelas | ✅ `pedidoVendaManual.js` |
| Entra em `vw_vendas_base` como líquido, fora da cascata G1 a G6; exclusão lógica (`deleted_at`) | ✅ `vw_vendas_base.model.js` ([[Dashboards]]) |
| Uma NF manual pode apontar para ele (`codigo_pedido_omie` negativo) | ✅ `notas_fiscais.route.js` ([[LOG-29-Notas-Fiscais-Manuais-So-Admin]]) |
| Nunca participa do custo por item (decisão D6 do contrato 008); falta marca de origem manual no `itens_pedido_custo` | 📝 🔴 BL-026 |

### Pendências (detalhe)

- ✅ **Atualização de 30/10/2026: a tela foi construída (N16-147).** Antes, **o HUB não tinha tela de pedido manual** (em `b55ac55` e de novo em 29/10, `758d5f0`): a busca por `pedidos-vendas-manuais` e `pedidos_vendas/manual` em `app`, `lib` e `components` não achou nada; só existe a de nota manual (`app/api/notas-manuais`, `dashboards/notas-fiscais-manuais`) 🔴 Nathan decide se haverá tela.
- Triggers `trg_pedidos_vendas_manual_*` e o mapa `auth.rotas_telas` das rotas `/pedidos_vendas/manual*` em produção ❓ Gustavo.
- Sem token, o autor do corpo é só um UUID informado (brecha herdada do contrato 29; ligada à separação de chaves L6) 🟡.
