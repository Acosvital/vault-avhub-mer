---
id: API-011
aliases: ["Contrato 011", "011-Compra-em-Andamento-Recebimento-por-Item-da-OC-e-Uso-Interno"]
tags: [contrato, contrato-api, mes, integracao-av-hub-mes, compras, recebimento, estoque]
criado: 2026-10-15
atualizado: 2026-10-15
status: proposta
dono: "Robert"
etapa_0b: [P1, P2, P3, E1, R0, R1, R4]
fontes: ["N14-20, N14-28, N14-29, N14-30, N14-31, N14-32 (Registro-de-Decisoes)", "Proposta-OP-Lote-Compra-em-Andamento.pdf (Robert, 15/10/2026)", "api-pcp develop 6914fe9: prisma/models/integracao.prisma (OcReferencia, OcReferenciaItem, K4), src/integracao-avhub/oc-referencia-avhub.service.ts, src/compras/compras.service.ts:362-382, recebimento.service.ts:147-162", "API-004, API-007, API-008, API-009, API-010"]
criado_original: 2026-10-15
---

# Contrato de API 011 — Compra em andamento, recebimento por item da OC e uso interno (MES)

> [!info] Situação em 15/10/2026
> **Status:** `proposta` · **Pasta:** `Ativos` · **Nós do 0b:** P1, P2, P3, E1, R0, R1, R4 · **Dono:** Robert (MES). O Gustavo entrega as leituras do hub (API-009 e API-010).
>
> - ✅ **K4 na `develop` do `api-pcp`** (PR #59, `6914fe9`, 15/10): o MES lê `GET /ordens-compra/referencia` e grava `OcReferencia` e `OcReferenciaItem` (`id` do item = `id_item_oc`, `destino` em JSON, `idOrigem`, `finalidade`, valores). É a base deste contrato.
> - 🔴 **Falta o resto:** mostrar a compra em andamento ao PCP (BL-049), o saldo futuro (BL-050), o abate e o aviso ao requisitar, a leitura da requisição do hub (BL-065, [[API-009-Referencia-Requisicao-Hub-Integracao-MES]]), o recebimento por item da OC e por NF com várias requisições (BL-051) e o uso interno.
> - 📝 Decisões do Nathan que este contrato implementa: **N14-29** (proposta do Robert aceita), **N14-30** (uso interno aprovado) e **N14-31** (tudo da mesma unidade). Estimativas do Robert (±30%): BL-051 4,0 pd, API-009 no MES 1,0, recebimento por NF 4,0, uso interno 0,5 (**dentro** da conta do Ciclo 1); BL-049 1,5 e BL-050 1,5 (**fora** da conta, aguardando decisão).
>
> Selos em [[Regras-do-Vault]]. O desenho das tabelas e dos nomes é do Robert; aqui estão as **regras** que ele implementa.

**Destinatários:** MES (`api-pcp`, `app-pcp`, Robert). Leituras do hub: [[API-009-Referencia-Requisicao-Hub-Integracao-MES]] e [[API-010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto]] (Gustavo).

## Por quê

Quando o Compras compra antes de o PCP movimentar o pedido, o MES não sabe e pode requisitar de novo. E a mercadoria dessa compra não tem caminho de entrada: o Recebimento exige requisição do MES. Este contrato fecha os dois buracos e deixa o MES saber, em cada momento, **o que já está em compra** para cada pedido e produto.

## 1. O que o MES enxerga de compra

| Fonte | O que é | Chega por | Estado |
|---|---|---|---|
| OC aprovada (e cancelada depois de aprovada) | `OcReferencia` e itens, com `destino[]` (pedido de venda e quantidade, ou estoque) e `finalidade` | `GET /ordens-compra/referencia` (K4) | ✅ na `develop` |
| Requisição do hub com pedido de venda, sem OC ainda | requisição `aberta` ou `em_cotacao`; e a `atendida` com OC `aguardando_aprovacao` | `GET /compras/requisicoes/referencia` (API-009) | 🔴 |
| Requisição do MES ainda aberta | a do próprio MES | tabela do MES | ✅ |

A OC em `aguardando_aprovacao` **não** vem pela referência da OC (só `aprovada`/`cancelada`); a requisição `atendida` do API-009 cobre esse intervalo, com `situacao_ordem_compra`.

## 2. Compra em andamento por pedido e produto

**Chave do cruzamento:** unidade do pedido + número do pedido + `codigo_produto` (o código humano do cadastro, que é o que o item de pedido do MES tem). O MES resolve o `codigo_produto_omie` do item da OC para o `codigo_produto` do cadastro da unidade antes de cruzar. A mesma regra vale para a requisição do hub (que já traz `material` = `codigo_produto`). Tudo é da **mesma unidade** (N14-31). ❓ Robert confirma a resolução do `codigo_produto_omie` para `codigo_produto`.

**O que conta como compra em andamento para um item de pedido:**

1. Itens de OC **aprovada** com `destino` `pedido_venda` para este pedido e este produto, em quantidade, **menos** o que já foi vinculado a outras parcelas e o que já chegou.
2. Mais as requisições do MES ainda abertas para o mesmo item.
3. **A requisição do hub e a OC aguardando aprovação só aparecem e avisam; não abatem nem vinculam** (N14-29). Quem abate é só a OC aprovada.

A conta roda **numa transação**, para duas parcelas não usarem a mesma OC.

## 3. Requisitar (P3): mostra, abate e pede só o que falta

No modal de requisição do PCP:

- Mostra **"Já em compra para este pedido: OC X, N un, previsão dd/mm"** (e "Requisição aberta no Compras", "OC X aguardando aprovação"), para o PCP ver o motivo.
- Pede só o que falta: preenche a quantidade com a necessidade menos o que a OC aprovada já cobre.
- O aviso de duplicidade **só avisa** (decisão do PCP registrada).

| Item | Precisa | Já em OC aprovada com destino ao pedido | Resultado |
|---|---|---|---|
| A | 5 | 5 (OC-120) | Nada a comprar: a parcela fica vinculada à OC-120 |
| B | 8 | 3 (OC-120) | Vinculada a 3 da OC-120; requisição só dos 5 que faltam |
| E | 2 | 0 | Requisição normal ao av-hub (contrato 34) |

**"Nada a comprar" ainda move a parcela.** A parte coberta vira um **vínculo com o item da OC** (internamente, uma requisição de origem "hub", **que não entra na fila do PUT do contrato 34** e não é enviada ao av-hub). A parcela vai para Compras · CCP como "com o fornecedor", entra nos esperados e é recebida pelo "Receber com NF" como as demais.

**OC cancelada depois:** o K4 vê a OC cancelada, o vínculo se desfaz e a parcela volta a Requisições, com aviso (mesmo comportamento da OC cancelada de requisição do MES).

**Estoque parcial:** o Atendimento usa o que há e só o restante segue para a compra (já é assim).

## 4. Para o PCP e o Estoque (BL-049 e BL-050)

| Onde | O que mostra | Fonte |
|---|---|---|
| Triagem, Destinação, Atendimento | "Compra em andamento: OC X, N un, previsão dd/mm" por pedido e produto; "Requisição aberta no Compras"; "OC X aguardando aprovação" | seção 1 e 2 |
| Atendimento e Saldo | **Saldo futuro**: saldo atual + OCs de **estoque** aprovadas em andamento, menos o já recebido. **Fica fora o uso interno**: o MES separa pela `finalidade` da OC (o `destino` do item vem `estoque`) | `OcReferencia.finalidade` |

A OC com `destino` de estoque **não abate** automaticamente a necessidade de um pedido: aparece como saldo futuro para o PCP escolher (N14-29).

## 5. Recebimento por item da OC e por NF (BL-051)

1. **Esperados por item da OC**, com ou sem requisição do MES: o item de OC aprovada entra nos esperados do Recebimento com fornecedor, quantidade, previsão e destino. Desaparece quando a OC é cancelada.
2. **A doca informa a NF uma vez** e marca os itens que chegaram nela, de uma ou mais OCs e requisições (inclusive as vinculadas da seção 3). O sistema cria **uma conferência com todos os itens**. A conferência continua contra a NF (chave de 44 dígitos, N14-04); o cruzamento com a OC passa a valer.
3. **Um lote por item da OC** (`id_item_oc`, D1 do [[API-008-Custo-do-Lote-no-MES]]), em **quarentena**, já com o **custo da OC** (K5, `lote_custo`, origem `OC`). Unidade de medida diferente da da OC: o lote nasce sem custo e sinalizado (regra do API-008).
4. Cada parcela atendida sai de Compras · CCP. **Recebimento parcial** mantém o restante de cada item como esperado, como hoje.
5. **Evitar entrada duplicada:** o item de OC que já tem requisição do MES entra uma vez só (pelo `id_origem`, ou pelo vínculo da seção 3); a quantidade já recebida por item de OC é do MES.
6. **Se o destino do item era pedido de venda**, a parcela daquele item segue o caminho normal (Qualidade de entrada → Estoque). **O lote que chega antes de o PCP destinar é só sugerido no Atendimento, sem reservar**, no Ciclo 1 (N14-29): não trava estoque.

## 6. Uso interno (N14-30)

| Regra | |
|---|---|
| Entra nos esperados do Recebimento | pelo mesmo caminho da OC sem requisição do MES (seção 5) |
| Conferência | a doca confere contra a NF |
| Estoque | **não cria lote nem saldo**: fica registrada como **entrada de uso interno**, entregue ao setor que pediu e **visível no Estoque como entrada registrada, sem saldo** |
| Saldo futuro | fica fora (seção 4) |
| Custo | vai para **despesa**, fora do custo do lote |
| Quarentena | **sem quarentena**, salvo categoria que o Nathan pedir (por exemplo, EPI) |
| Quem pediu | o setor que pediu vem da requisição (🔴 hoje só existe `solicitante` em texto; ver Q3 do [[API-010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto]]) |

🟡 Confirmar com a contabilidade que o custo de uso interno vai para despesa.

## 7. Torre de Fluxo

Nada do que é **estoque, uso interno ou compra por fora** gera evento de fluxo. A Torre acompanha só o item de pedido de venda no seu caminho (N14-28). A projeção da requisição do hub (API-009) e a entrada de uso interno **não** publicam evento. O lote que nasce da compra para pedido de venda só entra na Torre quando a parcela do item de pedido se move.

## 8. Dados (desenho do Robert)

Já existe: `OcReferencia`, `OcReferenciaItem` (K4). A criar, com nomes a definir: projeção da requisição do hub (tabela **própria**, separada da requisição interna "origem hub"); vínculo parcela ↔ item da OC (quantidade vinculada); esperados por item da OC; entrada de uso interno. `quantidade` com a mesma precisão do hub (`numeric(15,4)`; o model do hub declara `DECIMAL(14,3)` e o MES aceita os dois). Se a unidade de medida da requisição difere da do material, o MES avisa (regra de 13/10).

## 9. Critérios de aceite

1. Com OC aprovada de 5 un para o pedido 27605, a Destinação de 5 un mostra "Compra em andamento: OC-120, 5 un" e abre a parcela vinculada à OC, sem requisição ao hub.
2. Necessidade 8 com 3 em OC: vincula 3 e requisita só 5. Duas parcelas simultâneas não usam as mesmas 3 un.
3. OC de estoque aparece como saldo futuro e **não** abate o pedido.
4. Requisição do hub com pedido de venda aparece como "Requisição aberta no Compras" e **não** abate.
5. OC cancelada depois: o vínculo desfaz e a parcela volta a Requisições com aviso.
6. Recebimento por NF com itens de duas OCs e uma requisição do MES: uma conferência, um lote por item da OC, em quarentena, com custo; sobra de quantidade continua esperada.
7. Item de OC com requisição do MES não entra duas vezes nos esperados.
8. Uso interno: entra nos esperados, confere com a NF, sem lote nem saldo, aparece como entrada registrada, fora do saldo futuro.
9. Nada de estoque, uso interno ou compra por fora aparece na Torre.
10. A requisição interna "origem hub" nunca entra na fila do PUT do contrato 34.

## 10. Ordem

| # | Quem | Passo |
|---|---|---|
| 1 | Gustavo | [[API-010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto]], depois [[API-009-Referencia-Requisicao-Hub-Integracao-MES]] |
| 2 | Robert | Cruzamento, vínculo e abate (seções 2 e 3) sobre a `OcReferencia` do K4 |
| 3 | Robert | Recebimento por item da OC e por NF, e uso interno (seções 5 e 6) |
| 4 | Robert | Telas do PCP e do Estoque, e a leitura do API-009 (seção 4) |

## Perguntas em aberto

| # | Pergunta | Dono | Selo |
|---|---|---|---|
| Q1 | Como o MES resolve `codigo_produto_omie` para `codigo_produto` na unidade (cadastro `Material`)? | Robert | ❓ |
| Q2 | Como ratear a chegada parcial de uma OC que cobre vários pedidos e estoque, e em que ordem atende o pedido? | Robert, Nathan | 🔴 |
| Q3 | O que a contabilidade diz do custo de uso interno ir para despesa? E EPI tem inspeção? | Nathan | 🟡 |
| Q4 | O setor que pediu o uso interno: de onde vem (campo na requisição do hub)? | Nathan, Gustavo | 🔴 |
| Q5 | BL-049 e BL-050 (3,0 pd) entram no Ciclo 1? Aguardando decisão | Nathan | 🟡 |

Relacionados: [[API-004-Referencia-OC-Integracao-MES]], [[API-007-Referencia-OC-Valores-no-MES]], [[API-008-Custo-do-Lote-no-MES]], [[API-009-Referencia-Requisicao-Hub-Integracao-MES]], [[API-010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto]], [[05-Recebimento]], [[02-PCP-Triagem-e-Destinacao]], [[03-Estoque-Atendimento-e-Despacho]], [[04-Circuito-de-Compra]], [[Pontas-Soltas]] (PS-034), [[Backlog-por-Frente]] (BL-049, BL-050, BL-051, BL-065), [[Registro-de-Decisoes]].
