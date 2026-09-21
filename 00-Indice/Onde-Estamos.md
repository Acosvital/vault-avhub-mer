---
tags: [erp-acos-vital, status, indice]
criado: 2026-09-21
atualizado: 2026-09-21
---

# Onde estamos

> **Atualizado em 21/09/2026 (segunda-feira), um dia antes do início da execução.** Esta é a nota que responde "em que ponto o projeto está". Se ela estiver desatualizada, o projeto está desatualizado: quem muda o estado de uma tarefa atualiza a linha aqui no mesmo dia. Como manter: seção 7.

## 1. Em uma frase

**O planejamento está feito e a construção começa amanhã.** Nada do que precisa ser construído está pronto; o que existe hoje é a Entrada Comercial (Omie → pipeline → av-hub) e o motor de Flanges no MES.

## 2. Linha do tempo

| Data | Marco | Situação |
|---|---|---|
| 16/09 a 21/09 | Análise, fluxos, PRD, cronograma, contratos e modelo de rastreabilidade | **Concluído** (planejamento) |
| **21/09** | **Hoje** | Vault unificado, perguntas consolidadas |
| **22/09** | **Início da execução (S1)**. O cronograma previa S1 desde 18/09, então as janelas estão deslocadas um dia | Próximo |
| 25/09 | **M1** — DEC-1 a DEC-9 respondidas (ou default adotado por escrito), contratos destravados, hardware aprovado | Em risco: quatro dias úteis e nenhuma decisão registrada |
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
| Contratos SQL (6) e de API (2) | [[Indice-Contratos]] | **Todos em "proposta"; nenhum aplicado** |
| Modelo de rastreabilidade, custódia e SLA | [[Rastreabilidade-e-SLA-de-Eventos]], [[Campos-e-API-para-Rastreabilidade]] | **Proposta**, para a spec F1 |
| Protótipo de tela (Torre de Fluxo) | [Artifact](https://claude.ai/artifact/SS4C4srRk9cr66UHUS2rE3) | Dados fictícios; não é sistema |
| Perguntas em aberto consolidadas | [[Perguntas-em-Aberto-Consolidadas]] | 11 DEC + dezenas de perguntas por pessoa |
| Vault unificado e nota de entrada | [[Comece-Aqui]] | — |

## 4. O que está construído de verdade

Só o que já existia antes do projeto: a Entrada Comercial (pedido no Omie, sincronizado ao av-hub pelo pipeline), o Portal do Vendedor, os módulos de vendas e faturamento do av-hub, e o motor de execução de roteiro de Flanges do `api-pcp`. **Nenhuma linha de código dos itens do cronograma foi escrita.**

## 5. Quadro de tarefas da S1 (22/09 a 02/10)

Estados: **Não iniciada**, **Em andamento**, **Bloqueada**, **Concluída**, **Cortada**. IDs e critérios de pronto estão na seção 5 do [[Cronograma-2-Meses]]. As janelas abaixo são as planejadas; o início real é 22/09.

| ID | Entrega | Resp. | Janela planejada | Estado | Depende de |
|---|---|---|---|---|---|
| A1 | Workshop de decisões DEC-1 a DEC-9 | Nathan | 18/09–25/09 | Não iniciada | — |
| A2 | Hardware do posto e agenda do levantamento físico | Nathan | 21/09–25/09 | Não iniciada | DEC-8 |
| B1 | Fechar as perguntas dos contratos | Gustavo | 21/09–25/09 | Não iniciada | DEC-7 |
| B2 | Homologação do MES/Estoque e backup do banco do MES | Gustavo | 21/09–25/09 | Não iniciada | — |
| C1 | Login duplo no MES | Robert | 21/09–29/09 | Não iniciada | — |
| C3 | Desenho do RBAC por setor | Robert | 21/09–29/09 | Não iniciada | — |
| D1 | Schema Prisma do Estoque v1 | Pablo | 21/09–29/09 | Não iniciada | **DEC-4, DEC-7** |
| F1 | Spec da integração av-hub ↔ MES | Nathan | 21/09–29/09 | Não iniciada | DEC-2 |
| A3 | Pauta financeira e critérios de aceite | Nathan | 28/09–02/10 | Não iniciada | — |
| B3 | Aplicar contratos SQL 001 e 005 | Gustavo | 28/09–02/10 | Não iniciada | B1 |
| B4 | API `alterado_desde` em produtos e parceiros | Gustavo | 28/09–02/10 | Não iniciada | B1 |
| C4 | Carteira do PCP: importar itens do pedido | Robert | 28/09–02/10 | Não iniciada | — |
| D2 | Módulo base do Estoque e testes e2e | Pablo | 28/09–02/10 | Não iniciada | D1 |
| C2 | Vínculo Fábrica ↔ Filial | Robert | 30/09–02/10 | Não iniciada | **DEC-1** |
| D3 | Projeção read-only de material e parceiro | Pablo | 30/09–02/10 | Não iniciada | B4 |

S2 a S4 e o fechamento seguem o [[Cronograma-2-Meses]]; entram neste quadro quando a sprint começar.

## 6. O que está bloqueando ou em risco agora

1. **Nenhuma das 11 decisões (DEC-1 a DEC-11) está registrada como decidida no vault.** DEC-4 e DEC-7 travam a D1 (início amanhã); DEC-1 trava a C2; DEC-2 trava a integração. Lista com prazo e default em [[Perguntas-em-Aberto-Consolidadas]].
2. **Início um dia depois do previsto.** O marco M1 (25/09) tem um dia útil a menos. Decidir se as janelas da S1 são reajustadas ou se o marco permanece.
3. **Capacidade não confirmada.** O plano assume 40% de foco para o Nathan e 75% para Robert e Pablo, com 9% de folga. O vault não registra a alocação real.
4. **Rastreabilidade amplia o escopo.** A proposta em [[Campos-e-API-para-Rastreabilidade]] é maior do que o "status por item só para Fabricação e Recebimento" do cronograma. Definir se entra o mínimo ou o completo (pergunta R-14).
5. **Estados e status com falhas.** A [[Revisao-dos-Estados-e-Status]] achou 3 problemas críticos: status por item quando o item é dividido em parciais, lote congelado sem saída e entidades sem máquina de estados (Recebimento, Requisição, OC, RNC). Os dois primeiros afetam a D1 e a spec F1.
6. **Lacunas de lógica e de domínio.** A [[Lacunas-de-Logica-e-Clareza]] lista 15 pontos, entre eles: dois prazos para o mesmo pedido, marco zero do estoque sem data de corte, dois donos do saldo (Omie e MES), como o pedido chega à fila do PCP, sobras de chapa e consumo de matéria-prima. Os itens L-06 e L-07 entram na spec F1; L-08 e L-09 precisam ser resolvidos com as DEC-4 e DEC-1.
7. **Dependência de fora do time de dev:** levantamento físico (26–30/10), saneamento do catálogo (13–23/10), hardware e UAT. Todas com data no gantt do cronograma.

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
