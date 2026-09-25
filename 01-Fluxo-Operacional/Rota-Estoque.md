---
tags: [erp-acos-vital, fluxo-operacional]
criado: 2026-09-16
atualizado: 2026-09-24
---

# 3a. Rota Estoque (Pronta Entrega)

> **Atualizado em 24/09/2026:** a pronta entrega é o **split atendido no setor Estoque**, a etapa 1 que o backend insere em todo roteiro do MES (de Fabricação e de Revenda). Não é uma rota separada escolhida pelo PCP: todo item passa pelo Estoque primeiro, e a parte que o saldo cobre termina ali. Ver [[Encaixe-Estoque-Revenda-no-PCP]].

- O parcial chega no setor Estoque; o sistema mostra o **saldo disponível na filial do pedido** (saldo do lote liberado pela Qualidade − reservas ativas).
- Ação **"atender X do estoque"**: split do `ItemParcial` + **reserva** no lote (lote + split + quantidade) + conclusão do split. O restante é enviado para o próximo setor do roteiro.
- Separação física dos produtos em almoxarifado e conferência/identificação de lote e etiquetagem.
- Liberação para a entrega/faturamento; na saída, a reserva vira consumida.

O **item comprado** também termina aqui: aprovado na Qualidade, ele volta ao setor Estoque, dá entrada no saldo, é reservado e concluído — mesma porta de saída ([[Rota-Revenda]]).

## Perfil de risco

Rota **linear e curta**, com menor superfície de falha — provavelmente a mais rápida e previsível para SLA, comparada a [[Rota-Revenda]] e [[Rota-Fabricacao]]. Antes do marco zero (13/11) o saldo não é confiável e a reserva não liga: até lá o setor Estoque se comporta como saldo zero (ver a decisão em aberto sobre saldo zero em [[Encaixe-Estoque-Revenda-no-PCP]]).

## Onde isso é implementado (ou planejado)

As telas de saldo, reservas, movimentação e detalhe do lote existem no `app-pcp` (branch `develop`, 23/09) **sobre mock**; o backend real é a D9. A tela operacional do setor Estoque (fila de parciais + "atender do estoque") é a construir (C6). Separação (`ordem_separacao`/`item_separacao`) segue na Fase D. Ver [[Estoque-Modelo-Dados]].

## Ver também
- [[Encaixe-Estoque-Revenda-no-PCP]]
- [[Fluxo-Estoque-Completo]] — esta rota, conversa por conversa (separação, reserva, contagem cíclica).
- [[Modelo-Destinacao-Item]] — esta rota é, formalmente, a célula "pronto em estoque" da matriz Revenda×Fabricação, não uma origem própria de item.
- [[Fluxo-Operacional-Visao-Geral]]
- [[Faturamento-Expedicao]]
