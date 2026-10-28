---
id: API-022
aliases: ["Contrato API 022", "022-Comissao-da-Proposta-Calculo-e-Decisao-da-Controladoria"]
tags: [contrato, contrato-api, comissao, motor, controladoria, devolucao, api-acos-vital]
criado: 2026-10-21
atualizado: 2026-10-28
status: proposta
sistemas: [hub-api, hub-banco]
dono: "Nathan (começo da comissão), Robert (rotas) e Gustavo (revisão)"
etapa_0b: [K1, K2, K3, K4, K5, K6]
fontes: ["SQL-018-Schema-core_comissao-Comissao-da-Proposta", "03-Sistemas/Comissao/03-Modelo-Novo-core_comissao, 01-Motor-Atual-Como-Calcula", "av-hub lib/simulador/motor.ts (calcularSimulacao em app/(protected)/comissoes/simulador/page.tsx:1053)", "Registro-de-Decisoes (N16-10, N16-11, N16-19 a N16-22, N16-39, N16-42 a N16-51, N16-74)", "Proposta-Orcamento-Comissao/01-Decisoes/Respostas-da-Controladoria-2026-10-19 (fora do vault)"]
criado_original: 2026-10-16
---

# Contrato API 022 — comissão da proposta: cálculo, custo real, decisão, abatimento e visão geral (`/comissao`)

> **Onde atua:** av-hub: API (`api-acos-vital`)

> [!info] Situação em 28/10/2026
> **Status:** `proposta` · **Dono:** Nathan cuida do começo da comissão (`K1`, estimada na proposta, N16-115); Robert as rotas (N16-117; o Pablo acompanha); Gustavo revisa · Banco: [[SQL-018-Schema-core_comissao-Comissao-da-Proposta]] · Telas: [[LOG-59-Telas-da-Comissao-Nova]]
>
> - 📝 **28/10/2026, N16-117 a N16-119:** quem faz as rotas na `api-acos-vital` é o **Robert**; o Pablo acompanha. A `api-comercial` fica no repositório do av-hub **só para leitura** (legado de consulta, não roda nem publica; sai de produção). As telas do Pablo **ficam**: o Robert troca o backend delas (o BFF passa a chamar a `api-acos-vital`) e adapta onde divergem do vault, sem refazer do zero.
> - 📝 **28/10/2026, N16-116:** proposta e pedido ficam em `core_vendas_faturamento`; o **schema da comissão continua a decidir** (este contrato segue com `core_comissao`, [[SQL-018-Schema-core_comissao-Comissao-da-Proposta]]) ❓. O prefixo `/comissao/` não é afetado pela troca de schema.
> - 📝 Módulo **isolado**: não toca em Comissões atual nem em `core_comissionamento` (N16-11).

## 1. Por quê

O cálculo da comissão hoje roda no navegador (`calcularSimulacao`). Para a proposta, o motor passa a rodar na **API**, com as **mesmas entradas e regras** do simulador atual (N16-19), e grava em `core_comissao` com os parâmetros vigentes de cada cálculo (revisão reproduzível).

## 2. Rotas 🟡

| Rota | Quem | Efeito |
|---|---|---|
| `POST /comissao/calculos` `{ id_proposta, tipo: COTADO }` | sistema, ao salvar a proposta (`V0.3`, `K1`) | roda o motor, grava `fn_calculo_gravar`; **COTADO** só até a aprovação |
| (evento) custo real | sistema (`K2`) | recalcula `tipo: REAL` a cada evento de custo ([[API-021-Custo-Real-por-Evento-e-Conferencia-de-Compras]]); só as peças com custo real entram |
| (evento) NF faturada | sistema (`K3`) | `fn_comissao_nf_fechar`: fecha por NF com o percentual vigente, sem pagar duas vezes a mesma quantidade |
| `GET /comissao/vendedor/...` | vendedor | só a comissão que ele colocou; **depois da decisão**, o valor real com a justificativa (`K5`); desaprovada: R$ 0 e o motivo |
| `GET /comissao/fila` | Controladoria, Gerência, Coordenação | NFs aguardando decisão (`vw_comissao_nf_fila`) |
| `POST /comissao/nf/:id/decisao` `{ tipo, justificativa, valor, pct }` | os três perfis (`K4`) | aprovar, desaprovar, bloquear, desbloquear, cortar, alterar (valor ou percentual, sem teto); justificativa 10+; **ninguém decide sobre a própria comissão** |
| `POST /comissao/lancamentos/:id/decisao` | idem | decide complemento ou desconto |
| `POST /comissao/nf/:id/devolucao-total` | pipeline (marca do Omie) | `fn_comissao_devolucao_total` |
| `POST /comissao/nf/:id/devolucao-pendencia` | pipeline | abre a pendência da devolução parcial (idempotente) |
| `POST /comissao/devolucoes/:id/informar` `{ itens: [{codigo_item_omie, quantidade, valor}] }` | **Fiscal ou Controladoria** (`K6`) | `fn_comissao_devolucao_informar`; recusa acima do faturado |
| `GET /comissao/devolucoes/pendentes` | Fiscal, Controladoria | fila com a idade |
| `POST /comissao/nf/:id/cancelada`, `/paga` | pipeline; Controladoria | `fn_comissao_nf_cancelar`; `fn_comissao_nf_marcar_paga` |
| `GET /comissao/visao-geral`, `/resumo-mensal`, `/markup`, `/faturamento-x-compras` | Controladoria, Gerência | relatórios iniciais (lista por mês, vendedor, unidade e status, com Excel; markup real por vendedor; Faturamento × Compras por pedido, separando Revenda, Industrializado e Projeto; valor retido separado do valor a pagar) |
| `GET/PUT /comissao/parametros`, `/regras-fixas`, `/exclusoes`, `/coordenadores` | Controladoria | com vigência; nada é apagado |

## 3. Regras

1. Três visões da mesma tela: (a) vendedor preenche e vê estimativa; (b) Compras em leitura na OC (o passo em que Compras aprova o percentual de compras **sai do fluxo**, pronto e desligado); (c) Controladoria com o real lado a lado e o drill-down por evento.
2. O vendedor **nunca** recebe o custo real, o drill-down nem o motivo de queda por custo; vê a justificativa depois da decisão.
3. O motor em ponto flutuante da API deve bater com o do Simulador atual até R$ 0,01 por NF (teste de ouro).
4. A comissão do pedido digitado no Omie segue a mesma regra: a estimada nasce da parte de compras que o vendedor preenche no pedido (`vw_pedido_item_motor`, N16-104, N16-106); a nota que sair antes **espera**, e a Controladoria vê a margem real em `vw_comissao_nf_aguardando_simulacao` (N16-105).
5. Compra acima do valor aprovada pelo vendedor derruba a margem e a comissão dele; o preço do cliente não muda (N16-17).

## 4. Fora do contrato

Apuração do vendedor e `paga_em` (OQ-41), descontos de convênio e alimentação (OQ-42), CBS (OQ-44), devolução de compra, alteração do módulo atual.

## 5. Aceite

1. Com os mesmos dados de um caso do Simulador, margem, letra e comissão por item batem.
2. O vendedor, pelas mesmas rotas, não recebe as colunas reais antes da decisão.
3. A decisão de um perfil sobre a própria comissão responde 403.
4. Devolução parcial: pendência aberta, o Fiscal informa 2.300 de 13.300 e a comissão da NF é abatida em 17,2932%; informar acima do faturado responde 422.
5. Devolução total abate o que resta e dispensa a pendência.
6. Peça sem custo real fica fora; quando o custo completa, a diferença vira complemento ou desconto na apuração seguinte e exige nova decisão.

## 6. Perguntas em aberto

OQ-41 a OQ-45, C03 e C11 do modelo.

## Ver também

[[SQL-018-Schema-core_comissao-Comissao-da-Proposta]] · [[03-Modelo-Novo-core_comissao]] · [[01-Motor-Atual-Como-Calcula]] · [[LOG-59-Telas-da-Comissao-Nova]] · [[API-021-Custo-Real-por-Evento-e-Conferencia-de-Compras]] · [[LOG-56-Fluxo-da-Proposta-ao-Pedido]] · [[Registro-de-Decisoes|respostas da Controladoria de 19/10 (N16-42 a N16-51)]]
