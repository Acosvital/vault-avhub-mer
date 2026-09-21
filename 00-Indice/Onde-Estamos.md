---
tags: [erp-acos-vital, status, indice]
criado: 2026-09-21
atualizado: 2026-09-21
---

# Onde estamos

> **Atualizado em 21/09/2026 (segunda-feira), um dia antes do início da execução.** Esta é a nota que responde "em que ponto o projeto está". Se ela estiver desatualizada, o projeto está desatualizado: quem muda o estado de uma tarefa atualiza a linha aqui no mesmo dia. Como manter: seção 7.
>
> **Adendo do mesmo dia (21/09, à tarde):** auditoria de um dump de produção fresco (`dump-avhub_prd_db-202609210741.sql`) contra o código real de `api-acos-vital` e `api-pcp` achou que **5 contratos SQL e 1 contrato de API que este vault marcava como "proposta" já estão aplicados em produção**, e um risco novo (schema `negocio`/`core_compras` — ver abaixo). Detalhe completo em [[Auditoria-Dump-Producao-2026-09-21]]. As seções 3, 5 e 6 abaixo já refletem isso.

## 1. Em uma frase

**O planejamento está feito e a construção começa amanhã.** Nada do que precisa ser construído está pronto; o que existe hoje é a Entrada Comercial (Omie → pipeline → av-hub) e o motor de Flanges no MES.

## 2. Linha do tempo

| Data | Marco | Situação |
|---|---|---|
| 16/09 a 21/09 | Análise, fluxos, PRD, cronograma, contratos e modelo de rastreabilidade | **Concluído** (planejamento) |
| **21/09** | **Hoje** | Vault unificado; auditoria contra dump de produção; **8 das 11 DEC decididas em conversa direta** (DEC-1, 2, 3, 5, 7, 9, 10, 11) + DEC-12 nova (genealogia de material); ~45 das ~60 perguntas da lista consolidada fechadas |
| **22/09** | **Início da execução (S1)**. O cronograma previa S1 desde 18/09, então as janelas estão deslocadas um dia | Próximo |
| 25/09 | **M1** — DEC-1 a DEC-9 respondidas (ou default adotado por escrito), contratos destravados, hardware aprovado | **Quase lá**: 6 das 9 (DEC-1,2,3,5,7,9) já decididas. Restam DEC-4 (a mais urgente — trava D1), DEC-6 e DEC-8 (adiada de propósito) |
| 29/09 | Spec da integração av-hub ↔ MES aprovada (F1) | Não iniciada |
| 02/10 | **M2** — Fundação no ar | Não iniciada |
| 16/10 | **M3** — Fase 0 (sistema) pronta | Não iniciada |
| 30/10 | **M4** — Fases A + B em homologação | Não iniciada |
| 13/11 | **M5** — Fase 0 fechada + Fase C | Não iniciada |
| 18/11 | **M6** — Go/no-go do piloto | Não iniciada |

Detalhes de cada marco em [[Cronograma-2-Meses]].

## 3. O que já está pronto

| Item | Onde | Observação |
|---|---|---|
| Fluxo operacional mapeado (macro e item a item, 6 subfluxos) | [[Fluxo-Detalhado-Pedido-Item]], [[Fluxogramas-Completos]] | É o processo-alvo; não está em nenhum sistema ainda |
| PRD do Estoque, Recebimento e Compras | [[PRD-Estoque-Visao-Geral]] | Só planejamento, **não construído** |
| Análise dos backends e do pipeline | [[Omie-ELT-Pipeline]], [[App-PCP-Backend-Producao]] | Leitura de código; sem alterações |
| Levantamento da API do Omie e roteiro de extração | [[Indice-Integracao-Omie]] | Lacunas mapeadas |
| Cronograma de 2 meses | [[Cronograma-2-Meses]] | Plano, com premissas de capacidade que ainda precisam de confirmação |
| Contratos SQL (6) e de API (2) | [[Indice-Contratos]] | **5 SQL + 1 API já aplicados em produção** (confirmado por [[Auditoria-Dump-Producao-2026-09-21]] em 21/09); 1 invalidado (006); só o API 002 (Estoque/MES) segue genuinamente proposta |
| Modelo de rastreabilidade, custódia e SLA | [[Rastreabilidade-e-SLA-de-Eventos]], [[Campos-e-API-para-Rastreabilidade]] | **Proposta**, para a spec F1 |
| Protótipo de tela (Torre de Fluxo) | [Artifact](https://claude.ai/artifact/SS4C4srRk9cr66UHUS2rE3) | Dados fictícios; não é sistema |
| Perguntas em aberto consolidadas | [[Perguntas-em-Aberto-Consolidadas]] | **Finalizada em 21/09**: de ~60 perguntas, só 16 pendências reais restam (seção 0 da nota) — o resto foi decidido, aceito ou ficou moot ao longo do dia |
| Vault unificado e nota de entrada | [[Comece-Aqui]] | — |

## 4. O que está construído de verdade

Só o que já existia antes do projeto: a Entrada Comercial (pedido no Omie, sincronizado ao av-hub pelo pipeline), o Portal do Vendedor, os módulos de vendas e faturamento do av-hub, e o motor de execução de roteiro de Flanges do `api-pcp`. **Nenhuma linha de código dos itens do cronograma foi escrita.**

## 5. Quadro de tarefas da S1 (22/09 a 02/10)

Estados: **Não iniciada**, **Em andamento**, **Bloqueada**, **Concluída**, **Cortada**. IDs e critérios de pronto estão na seção 5 do [[Cronograma-2-Meses]]. As janelas abaixo são as planejadas; o início real é 22/09.

| ID | Entrega | Resp. | Janela planejada | Estado | Depende de |
|---|---|---|---|---|---|
| A1 | Workshop de decisões DEC-1 a DEC-9 | Nathan | 18/09–25/09 | Não iniciada | — |
| A2 | Hardware do posto e agenda do levantamento físico | Nathan | 21/09–25/09 | Não iniciada | DEC-8 |
| B1 | Fechar as perguntas dos contratos | Gustavo | 21/09–25/09 | **Concluída** — G-01 a G-18 todas respondidas em conversa direta com o Gustavo (21/09), ver [[Perguntas-em-Aberto-Consolidadas]] bloco C | DEC-7 |
| B2 | Homologação do MES/Estoque e backup do banco do MES | Gustavo | 21/09–25/09 | Não iniciada | — |
| C1 | Login duplo no MES | Robert | 21/09–29/09 | Não iniciada | — |
| C3 | Desenho do RBAC por setor | Robert | 21/09–29/09 | Não iniciada | — |
| D1 | Schema Prisma do Estoque v1 | Pablo | 21/09–29/09 | Não iniciada | **DEC-4** (DEC-7 já decidida) |
| F1 | Spec da integração av-hub ↔ MES | Nathan | 21/09–29/09 | Não iniciada | DEC-2 |
| A3 | Pauta financeira e critérios de aceite | Nathan | 28/09–02/10 | Não iniciada | — |
| B3 | Aplicar contratos SQL 001 e 005 | Gustavo | 28/09–02/10 | **Concluída** — já aplicado em produção antes do início da S1; confirmado por [[Auditoria-Dump-Producao-2026-09-21]] (21/09). Capacidade do Gustavo nessa janela fica livre | B1 |
| B4 | API `alterado_desde` em produtos e parceiros | Gustavo | 28/09–02/10 | **Concluída** — já implementado em `produtos.js`/`parceiros.js`; confirmado por [[Auditoria-Dump-Producao-2026-09-21]] (21/09) | B1 |
| C4 | Carteira do PCP: importar itens do pedido | Robert | 28/09–02/10 | Não iniciada | — |
| D2 | Módulo base do Estoque e testes e2e | Pablo | 28/09–02/10 | Não iniciada | D1 |
| C2 | Vínculo Fábrica ↔ Filial | Robert | 30/09–02/10 | Não iniciada | **DEC-1** |
| D3 | Projeção read-only de material e parceiro | Pablo | 30/09–02/10 | Não iniciada | B4 |

S2 a S4 e o fechamento seguem o [[Cronograma-2-Meses]]; entram neste quadro quando a sprint começar.

## 6. O que está bloqueando ou em risco agora

> **Reorganizado em 21/09/2026.** A lista completa e atualizada de pendências reais vive só em [[Perguntas-em-Aberto-Consolidadas]] seção 0 (16 itens) — não duplicada aqui, pra não ter duas fontes de verdade desalinhando. Esta seção lista só os riscos de **cronograma/execução**, não as perguntas de negócio em si.

1. **DEC-4 é o único bloqueio real de amanhã.** Trava a D1 (schema Prisma do Estoque), que começa 22/09. DEC-6 e DEC-8 têm prazo 25/09, sem trava imediata. As outras 8 DEC (incluindo a nova DEC-12) já foram decididas — ver [[Decisoes-Chave-ERP]].
2. **Início um dia depois do previsto.** O marco M1 (25/09) tem um dia útil a menos — vira a pergunta N-07, ainda sem resposta.
3. **Capacidade real não confirmada.** Pergunta N-06, ainda sem resposta — o plano segue assumindo 40%/75%/75% de foco sem confirmação.
4. **Rastreabilidade completa decidida, já encaixada.** R-07/R-14: escopo é todas as rotas. Cronograma estendido pra 3 meses (S5, 19/11-18/12) — ver [[Cronograma-2-Meses]] seção 3.1 e 5. Junto entrou o bloco J (genealogia de material, DEC-12).
5. **Estados e status — maioria resolvida em 21/09.** Dos 3 problemas críticos originais de [[Revisao-dos-Estados-e-Status]], o ponto 2.1 (status por item com parciais) já tem resposta (atraso medido no nível do pedido). Seguem 6 perguntas da seção 5 dessa nota sem resposta — listadas em [[Perguntas-em-Aberto-Consolidadas]] seção 0.
6. **Lacunas de lógica — 10 das 11 resolvidas em 21/09.** [[Lacunas-de-Logica-e-Clareza]]: L-01 a L-09 e L-11 têm resposta ou proposta aceita. Só **L-10** (sobras de chapa, perda no corte, conversão de unidade) segue genuinamente sem tratamento.
7. **Dependência de fora do time de dev:** levantamento físico (26–30/10), saneamento do catálogo (removido do escopo — duplicata de catálogo agora se resolve direto no Omie, ver [[Cronograma-2-Meses]]), hardware e UAT. Datas no gantt do cronograma.

## 7. Como manter esta nota

- **Quem:** o responsável pela tarefa muda o estado da própria linha; o Nathan revisa o resto.
- **Quando:** no mesmo dia em que o estado mudar, e uma revisão geral por semana (sugestão: segunda-feira).
- **O que atualizar:** o campo `atualizado` do cabeçalho e a data da primeira linha; o estado da tarefa; a seção 6 quando um bloqueio abrir ou fechar.
- **Quando uma decisão for tomada:** registrar em [[Decisoes-Chave-ERP]] e marcar aqui.
- **Quando um contrato for aplicado:** mudar o status no [[Indice-Contratos]] e citar aqui.
- **Nunca** marcar "Concluída" sem o critério de pronto do cronograma.

## Ver também
- [[Comece-Aqui]]
- [[Home]]
- [[Cronograma-2-Meses]]
- [[Perguntas-em-Aberto-Consolidadas]]
- [[Decisoes-Chave-ERP]]
- [[Auditoria-Dump-Producao-2026-09-21]] — depara completo dump vs. vault vs. código (21/09)
