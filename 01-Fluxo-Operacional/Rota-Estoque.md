---
tags: [erp-acos-vital, fluxo-operacional]
criado: 2026-09-16
atualizado: 2026-10-07
---

# 3a. Rota Estoque (Pronta Entrega)

> Status: decidido (fluxo de negócio). O que já existe no código está em [[Fluxograma-Telas-por-Bloco]] e [[Onde-Estamos]]; produção não verificada (dump de 07/10).

> **Atualização de 07/10/2026 — a rota já tem código em `develop` (não é produção).** Conferido no código (`develop`, `api-pcp` `ca3346b`; a `main` do MES parou em 28/08): atender pelo estoque (split + reserva + conclusão, `atenderEstoque`), saldo/reservas/movimentação/lote reais, cadastros de material e depósito, e o saldo por filial no atendimento (transferência, etapa 1, `861c050`). **A baixa ainda ocorre quando a Embalagem recebe** o item; a mudança decidida em 29/09 (baixa no despacho do Estoque, Reserva só para "separar sem despachar") não foi implementada. Separação (`ordem_separacao`) e o fluxo de transferência (etapas 2–4) não constam no código.

> **Atualizado em 24/09/2026:** a pronta entrega é o **split atendido no setor Estoque**, a etapa 1 que o backend insere em todo roteiro do MES (de Fabricação e de Revenda). Não é uma rota separada escolhida pelo PCP: todo item passa pelo Estoque primeiro, e a parte que o saldo cobre termina ali. Ver [[Encaixe-Estoque-Revenda-no-PCP]].

- O parcial chega no setor Estoque; o sistema mostra o **saldo disponível na filial do pedido** (saldo do lote liberado pela Qualidade − reservas ativas).
- Ação **"atender X do estoque"**: split do `ItemParcial` + **reserva** no lote (lote + split + quantidade) + conclusão do split. O restante é enviado para o próximo setor do roteiro.
- Separação física dos produtos em almoxarifado e conferência/identificação de lote e etiquetagem.
- Liberação para a entrega/faturamento; na saída, a reserva vira consumida.

O **item comprado** também termina aqui: aprovado na Qualidade, ele volta ao setor Estoque, dá entrada no saldo, é reservado e concluído — mesma porta de saída ([[Rota-Revenda]]).

## Perfil de risco

Rota **linear e curta**, com menor superfície de falha — provavelmente a mais rápida e previsível para SLA, comparada a [[Rota-Revenda]] e [[Rota-Fabricacao]]. Antes do marco zero (13/11) o saldo não é confiável e a reserva não liga: até lá o setor Estoque se comporta como saldo zero (ver a decisão em aberto sobre saldo zero em [[Encaixe-Estoque-Revenda-no-PCP]]). *(Conferido no código em 07/10: a carga inicial hoje é só `POST /estoque/lotes/carga-inicial`, um lote por vez; sem importação em lote, dry-run ou folhas de contagem.)*

## Onde isso é implementado (ou planejado)

As telas de saldo, reservas, movimentação e detalhe do lote existem no `app-pcp` (branch `develop`, 23/09) ~~**sobre mock**; o backend real é a D9. A tela operacional do setor Estoque (fila de parciais + "atender do estoque") é a construir (C6).~~ **(Atualizado em 07/10: com backend real — D9, `0fe771f`, 28/09 — via `/estoque/*`; a ação "atender do estoque" existe desde a C6, 25/09; só `painel-estoque` (parte), `mapa-deposito` e `qualidade/route` ainda citam mock.)** Separação (`ordem_separacao`/`item_separacao`) segue na Fase D. Ver [[Estoque-Modelo-Dados]].

## Ver também
- [[Encaixe-Estoque-Revenda-no-PCP]]
- [[Fluxo-Estoque-Completo]] — esta rota, conversa por conversa (separação, reserva, contagem cíclica).
- [[Modelo-Destinacao-Item]] — esta rota é, formalmente, a célula "pronto em estoque" da matriz Revenda×Fabricação, não uma origem própria de item.
- [[Fluxo-Operacional-Visao-Geral]]
- [[Faturamento-Expedicao]]
