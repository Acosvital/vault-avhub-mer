---
id: SQL-018
aliases: ["Contrato SQL 017", "017-Schema-core_comissao-Comissao-da-Proposta"]
tags: [contrato, contrato-sql, dba, comissao, controladoria, devolucao, core_comissao]
criado: 2026-10-21
atualizado: 2026-10-21
status: proposta
sistemas: [hub-banco]
dono: "Gustavo (DBA)"
etapa_0b: [K1, K2, K3, K4, K5, K6]
fontes: ["Registro-de-Decisoes (N16-10, N16-11, N16-19 a N16-22, N16-39, N16-42 a N16-51, N16-74)", "SQL-018-anexos/0000-stubs-de-teste.sql, 0001-core-comissao.sql (1.831 linhas), 0002-teste-funcional.sql, 0003-entradas-do-motor-em-core_comercial.sql, 0004-devolucao-parcial-pendencia.sql, 0005-teste-devolucao-parcial.sql", "03-Comissao/03-Modelo-Novo-core_comissao", "av-hub lib/simulador/motor.ts", "Respostas-da-Controladoria-2026-10-19"]
criado_original: 2026-10-16
---

# Contrato SQL 017 — schema `core_comissao`: comissão da proposta, custo realizado por evento, decisão e abatimento

> **Onde atua:** av-hub: banco

> [!info] Situação em 21/10/2026
> **Status:** `proposta` · **Nós do 0b:** `K1` a `K6` · **Dono:** Gustavo · Desenho em [[03-Modelo-Novo-core_comissao]]
>
> - 🧪 **Testado em Postgres 18 com stubs (21/10):** `0001` aplica sem erro; `0002` (teste funcional) dá **14 erros esperados**; `0004` aplica; `0005` dá **7 erros esperados**, todos conferidos. Não rodou no banco do Hub ❓.
> - 🧪 **26/10: anexo `0006`** (comissão nova também para o pedido digitado direto no Omie, N16-103, com a simulação do vendedor, N16-104) e teste **`0007`** com **25 verificações**, todas ok. Com o `0006` aplicado, `0002` e `0005` dão a mesma saída de antes (14 e 7 erros esperados).
> - 📝 **O `core_comissionamento` atual não muda** (N16-11). Este schema é novo, isolado.
> - Depende do [[SQL-016-Schema-core_comercial-Proposta-e-Pedido-de-Venda]] (proposta, pedido, eventos de custo). O anexo `0003` lista as colunas que o motor precisa em `core_comercial` (na proposta e, desde a N16-106, também no pedido) e as views `vw_proposta_item_motor` e `vw_pedido_item_motor`; **o dono do SQL-016 as incorpora ou recusa** ❓.

## 1. Por quê

O Simulador de Comissão de hoje calcula no navegador e grava em `core_comissionamento`. A comissão nova nasce na proposta, recalcula com o custo real por evento, fecha por nota fiscal, passa pela decisão da Controladoria, da Gerência ou da Coordenação e abate por nota cancelada, devolvida ou recusada. O **motor é o mesmo** (percentual final = menor entre o do vendedor e o de compras); as **tabelas são novas** (N16-11).

## 2. Objetos (anexo `0001`)

| Grupo | Objetos |
|---|---|
| Parâmetros com vigência | `parametros` (Maio/23 continua, N16-39), `parametros_despesas`, `parametros_icms_saida`, `parametros_icms_entrada`, `parametros_encargos_pagamento`, `parametros_faixas` (A/B/C/D), `fn_parametros_travar`, `fn_parametros_completo`, `fn_parametros_json`, `exige_conferencia_compras` (desligado, N16-51) |
| Regras | `regras_fixas_cliente` (gatilho: markup bruto; com vigência), `exclusoes` (cliente e vendedor; a comissão excluída aparece com R$ 0 e o motivo), `coordenadores`, `coordenadores_regras`, `coordenadores_apuracoes` e as funções de vigência e apuração |
| Dossiê | `comissoes` (estados `ESTIMADA`, `CONGELADA`, `EM_ACOMPANHAMENTO`, `ENCERRADA`, `CANCELADA`; `id_usuario_vendedor`), `comissao_calculos` (tipos `COTADO` e `REAL`, imutáveis), `comissao_calculo_itens`, `comissao_calculo_eventos` (drill-down por evento de custo), `comissao_itens_vinculo`, `fn_calculo_gravar`, `fn_comissao_mudar_estado` |
| NF e decisão | `comissoes_nf` (`valor_calculado`, `valor_pendente_custo`, `paga_em`), `comissoes_nf_itens` (`quantidade_comissionavel`: nunca paga a mesma peça duas vezes), `comissao_conferencias_compras`, `comissao_decisoes` (só `INSERT`; `perfil_decisor`; aprovar, desaprovar, bloquear, desbloquear, cortar, alterar; justificativa 10+), `fn_comissao_nf_fechar`, `fn_comissao_decidir` |
| Lançamentos | `comissao_lancamentos` (`COMPLEMENTO`, `DESCONTO` com nova decisão; `ABATIMENTO` sem decisão), `fn_comissao_lancamento_registrar`, `fn_comissao_lancamento_decidir`, `fn_comissao_nf_abater`, `fn_comissao_nf_marcar_paga`, `fn_comissao_nf_cancelar` |
| Rastro e fila | `comissao_eventos` (só `INSERT`), `comissao_fila_recalculo`, `fn_log_imutavel`, `fn_auditar` |
| Leituras | `vw_comissao_vendedor`, `vw_comissao_nf_vendedor` e `vw_comissao_lancamentos_vendedor` (o vendedor só vê o valor depois da decisão, com a justificativa), `vw_comissao_nf_fila`, `vw_comissao_itens_custo`, `vw_comissao_eventos_custo`, `vw_comissao_visao_geral`, `vw_comissao_resumo_mensal`, `vw_comissao_lancamentos_mes`, `vw_comissao_markup_pedido`, `vw_comissao_markup_vendedor`, `vw_comissao_faturamento_x_compras` |

### 2.1 Anexo `0004-devolucao-parcial-pendencia.sql` (novo em 21/10, N16-74)

| Objeto | O que faz |
|---|---|
| `comissao_devolucao_pendencia` | Devolução **parcial** marcada no Omie sem item, quantidade e valor. Estados `ABERTA`, `INFORMADA`, `DISPENSADA`. Uma aberta por NF (índice único). Guarda perfil (`FISCAL` ou `CONTROLADORIA`), quem e quando, itens, valor, proporção e o lançamento gerado |
| `fn_comissao_devolucao_total` | Devolução **total** marcada no Omie: abate o que resta (100% menos o já abatido) e **dispensa** a pendência aberta |
| `fn_comissao_devolucao_pendencia_abrir` | Abre a pendência; idempotente |
| `fn_comissao_devolucao_informar` | Fiscal ou Controladoria informam `[{codigo_item_omie, quantidade, valor}]`. Recusa perfil errado, item fora da NF, quantidade ou valor acima do faturado do item, soma acima do valor da NF (descontadas as já informadas), pendência já informada. Calcula a proporção e chama `fn_comissao_nf_abater` com a origem `DEVOLUCAO` |
| `vw_comissao_devolucao_pendente` | Fila do Fiscal e da Controladoria, com a idade em horas. O vendedor nunca vê |

### 2.2 Anexo `0006-comissao-do-pedido-digitado-no-omie.sql` (novo em 26/10, N16-103)

A comissão nova vale para **os dois tipos de pedido**. No pedido digitado direto no Omie, **o vendedor preenche a simulação como faz hoje no Simulador de Comissão** (N16-104): há estimativa, e o percentual final é o menor entre o dele e o do custo real, como na proposta.

| Objeto | O que muda |
|---|---|
| `comissoes.origem` | `PROPOSTA` ou `PEDIDO_OMIE`. O do Omie não tem `id_proposta` e se liga ao pedido do Hub de origem `OMIE` (`id_pedido_venda`, N16-106); nasce `ESTIMADA`. A simulação é a **parte de compras que o vendedor preenche no próprio pedido**: o motor lê `vw_pedido_item_motor` (anexo `0003`) e grava o `COTADO`, item = produto; confirmada (`CONGELADA`), passa a `EM_ACOMPANHAMENTO`. Um dossiê vivo por pedido (empresa + número do Omie) |
| `fn_comissao_abrir_pedido_omie` | o job abre o dossiê quando a pipeline traz o pedido. Vendedor e cliente vêm do original; idempotente; recusa pedido inexistente, cancelado ou que nasceu de proposta (`PEDIDO_TEM_PROPOSTA`) |
| `comissao_calculo_itens` | no pedido do Omie o item é o **produto** (`codigo_produto`, N16-102), sem `id_item_proposta`, na simulação e no cálculo real; o gatilho `trg_calc_itens_origem` não deixa misturar |
| `comissoes_nf_itens` | ganha `codigo_produto_omie`. A NF do pedido do Omie só fecha depois da simulação, como a da proposta só fecha com o cotado |
| Nota antes da simulação (N16-105) | a NF **espera**. O cálculo real do pedido do Omie já pode ser gravado na `ESTIMADA` e na `CONGELADA` (`fn_calculo_gravar`), e `vw_comissao_nf_aguardando_simulacao` mostra à Controladoria essas notas com a margem real. Com as duas, fecha pelo menor |
| `fn_comissao_nf_fechar` | refeita para as duas origens e para os **sequenciais** (abaixo) |
| Visões | `vw_comissao_nf_fila`, `vw_comissao_itens_custo` (simulação e real casados pelo produto) e `vw_comissao_visao_geral` ganham a coluna `origem`. Em `vw_comissao_vendedor` o pedido do Omie aparece `SIMULACAO_PENDENTE` até o vendedor preencher |

**Regra do motor (API):** a mesma nas duas origens. A simulação do pedido do Omie é a tela de hoje do Simulador de Comissão, gravando no dossiê novo; só as peças com custo real são pagas (N16-48).

> [!info] Pedido em partes (N16-94, N16-100), corrigido no `0006`
> Um pedido pode ter **várias notas** quando o Fiscal o fatura em sequenciais. A comissão continua **por nota** e o custo continua **do item do pedido**. No Omie a linha do sequencial recebe código **novo** (N16-100), então:
> - no pedido da proposta, a nota volta à linha do original pela **terceira tabela** (`pedidos_vendas_sequenciais_itens`);
> - no pedido do Omie, a nota casa pelo **produto**.
>
> A quantidade já comissionada passa a somar **por item** (proposta) ou **por produto** (Omie), em todas as notas e sequenciais, e não mais por linha. Antes, uma peça podia ser paga duas vezes quando saía em sequenciais diferentes.

## 3. Regras que o banco impõe

1. Ninguém decide sobre a própria comissão (compara `id_usuario_vendedor`); toda decisão guarda quem, perfil, valor e percentual antes e depois, e justificativa (N16-44, N16-45).
2. Custo parcial: só as peças com custo real entram; a diferença vai para a apuração seguinte, para nova decisão (N16-48). O restante **não** usa o cotado.
3. A comissão fecha por NF com o percentual vigente naquele momento; o mesmo item em várias NFs nunca paga a mesma quantidade duas vezes (N16-49).
4. O encargo da condição de pagamento entra no **preço sugerido**, não no custo do evento (N16-22).
5. NF cancelada, devolvida ou recusada abate na mesma proporção; a soma dos abatimentos de uma NF não passa de 100 (N16-47). Se não foi paga, reduz o valor do mês; se foi, entra na próxima apuração.
6. Comissão com NF faturada não se cancela; o caso é de abatimento. Antes de faturar, o pedido cancelado leva a comissão a `CANCELADA` (histórico com motivo).
7. Pedido digitado direto no Omie: dossiê `PEDIDO_OMIE`; o vendedor preenche a simulação e a comissão segue como a da proposta (N16-103, N16-104, anexo `0006`).

## 4. Fora do contrato

O motor em si (roda na API, [[API-022-Comissao-da-Proposta-Calculo-e-Decisao-da-Controladoria]]), as telas ([[LOG-59-Telas-da-Comissao-Nova]]), a apuração do vendedor (OQ-41), descontos de convênio e alimentação (OQ-42), CBS (OQ-44), a devolução de **compra** (OQ-42), o módulo atual.

## 5. Checklist do DBA

1. Aplicar depois do SQL-016 e, se aceitar, do anexo `0003`.
2. Aplicar `0004` e `0006`.
3. Reproduzir os testes: `0002` (14 erros esperados), `0005` (7) e `0007` (25 verificações, termina em "TUDO OK").
4. Agendar o job que chama `fn_comissao_abrir_pedido_omie` para todo pedido novo de `pedidos_vendas` que não nasceu de proposta.
5. Conferir que o `numero_pedido` gravado no dossiê da proposta é o número do **Omie**.
6. Decidir os índices das views de relatório pelo volume.
7. Restringir o acesso à tabela `coordenadores_regras` (dado de remuneração).
8. Decidir quem informa `paga_em` (OQ-41).

## 6. Aceite

Os testes `0002`, `0005` e `0007` rodam em banco vazio com os stubs (`0000`) e terminam nos números acima, sem outro erro. O `0007` cobre: abrir o dossiê do pedido do Omie (idempotente; recusa o inexistente e o que nasceu de proposta), simulação pendente, custo real antes da simulação com as notas na lista de espera da Controladoria, simulação do vendedor pelo produto, NF só depois da simulação, o menor percentual entre simulação e real, dois sequenciais do mesmo produto sem pagar a peça duas vezes (R$ 26,00 e depois R$ 5,20), fila da Controladoria, visão do vendedor, aprovação, e a nota de um sequencial da proposta casando pela terceira tabela. Casos cobertos no `0005`: perfil errado, quantidade e valor acima do faturado, item fora da NF, informar duas vezes, soma acima do faturado, devolução total que dispensa a pendência, devolução total repetida; abatimento proporcional (2.300 de 13.300 = 17,2932%) e soma 100.

## 7. Perguntas em aberto

OQ-41 a OQ-45 (apuração, descontos, Projeto e recompra, CBS, validações provisórias), C03 e C11 do modelo, OQ-34 (vínculo NF de entrada).

## Ver também

[[03-Modelo-Novo-core_comissao]] · [[01-Motor-Atual-Como-Calcula]] · [[SQL-016-Schema-core_comercial-Proposta-e-Pedido-de-Venda]] · [[API-022-Comissao-da-Proposta-Calculo-e-Decisao-da-Controladoria]] · [[LOG-59-Telas-da-Comissao-Nova]] · [[LOG-56-Fluxo-da-Proposta-ao-Pedido]] · [[Registro-de-Decisoes|respostas da Controladoria de 19/10 (N16-42 a N16-51)]]
