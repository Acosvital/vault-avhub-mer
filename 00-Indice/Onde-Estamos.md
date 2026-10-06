---
tags: [erp-acos-vital, status, indice]
criado: 2026-09-21
atualizado: 2026-10-06
---

# Onde estamos

> **Atualizado em 21/09/2026 (segunda-feira), um dia antes do início da execução.** Esta é a nota que responde "em que ponto o projeto está". Se ela estiver desatualizada, o projeto está desatualizado: quem muda o estado de uma tarefa atualiza a linha aqui no mesmo dia. Como manter: seção 7.
>
> **Adendo do mesmo dia (21/09, à tarde):** auditoria de um dump de produção fresco (`dump-avhub_prd_db-202609210741.sql`) contra o código real de `api-acos-vital` e `api-pcp` achou que **5 contratos SQL e 1 contrato de API que este vault marcava como "proposta" já estão aplicados em produção**, e um risco novo (schema `negocio`/`core_compras` — ver abaixo). Detalhe completo em [[Auditoria-Dump-Producao-2026-09-21]]. As seções 3, 5 e 6 abaixo já refletem isso.

> **Adendo de 24/09/2026 — encaixe do Estoque e da Revenda no MES.** O Robert fechou como o Estoque e a Revenda entram no fluxo Carteira → Ordem de Produção → execução, e o Nathan acrescentou a regra do item comprado (aprovado na Qualidade, vai para o Estoque, não para a Expedição). Tudo em [[Encaixe-Estoque-Revenda-no-PCP]]. Efeito no quadro: **C6** muda de conteúdo (tipos de Fábrica/Setor, fábrica Revenda, Estoque como etapa 1), **C7** passa a ser disparada pelo setor Compras, **C8** encolhe para a fila "Novo norte", **D6/D8/D9** ganham o modelo de reserva e a entrada do item comprado. Também registrado: a **Carteira de Pedidos** e a tela **Ordem de Produção** já rodam no `app-pcp` `develop` (23-24/09) — o critério de pronto da **C4** ("itens do pedido de venda disponíveis no MES por número do pedido") parece atendido, falta o Robert confirmar — e as telas de Estoque e Qualidade do Pablo (D5, D8, D10) estão em `develop` sobre mock. 7 perguntas novas (EN-01 a EN-07) em [[Perguntas-em-Aberto-Consolidadas]] — **todas respondidas em 25/09/2026**, ver [[Encaixe-Estoque-Revenda-no-PCP]] seção 5.
>
> **Adendo de 28/09/2026 — C6 e D9 concluídas; novo desenho de Compras em duas rodadas no mesmo dia; verificado direto no código.** Dois PDFs do Robert no mesmo dia: de manhã, **C6 e D9 (implementadas e testadas)**, Material deixa de ser projeção do av-hub (D3 revisada), a parte atendida pelo estoque passa a concluir na **Expedição** (não no Estoque), e um novo setor "Requisições de compras" (ainda não codificado); à tarde, uma segunda proposta **revisa a primeira antes dela virar código** — setor Estoque único, circuito de compra vira desvio fixo do sistema (fora do roteiro do PCP), e a baixa do saldo muda de novo, agora pro despacho do Estoque. **Clonei `api-pcp` e `app-pcp` (branch `develop`) e confirmei**: os itens da manhã batem exatamente com o schema Prisma e os componentes de frontend reais (inclusive comentários no código citando C6/D9/EN-02/EN-03 literalmente); a proposta da tarde não tem nenhum código ainda. Também confirmado em `api-acos-vital`: o bug de `alterado_desde` (filtro nunca aplicado, código depois do `return`) é real, em `produtos.js` e `parceiros.js`. **EN-05 reabriu** — resposta de 25/09 não chegou ao Robert.
>
> **Adendo de 29/09/2026 — a proposta da tarde de 28/09 vira decisão.** O Nathan respondeu as 9 perguntas que a atualização de 28/09 tinha deixado em aberto: EN-05 confirmado de vez (sem conflito), e a arquitetura da tarde de 28/09 (Estoque único, circuito de compra fixo fora do roteiro, baixa no despacho do Estoque, Reserva reduzida a "separar sem despachar", inspeção de entrada por lote e de saída como setor `QUALIDADE` obrigatório no roteiro, C8 respeitando `RoteiroItem`, processo de reprovação total/parcial no recebimento) passa a ser a **arquitetura confirmada**, ainda sem nenhum código. Só fica em aberto a baixa de matéria-prima consumida além do requisitado (sobras/perdas de corte) — o Nathan pediu sugestão em vez de decidir. Tudo em [[Encaixe-Estoque-Revenda-no-PCP]]; pendências reais caem de 18 para 10 em [[Perguntas-em-Aberto-Consolidadas]].
>
> **Adendo de 30/09/2026 — retorno do Robert sobre os contratos de integração (conferido no código).** O Robert comparou o vault com o código dos dois lados. **L4 do contrato 26 concluído**: a Carteira do MES lê `/pedidos_liberados` (falta só a data de corte para o teste de ponta a ponta). **Contratos 003 e 005 aprovados por ele com ajustes**, e as duas rotas do MES (`/requisicoes-compra` e `/itens/status`) **já existem** (F3 adiantada). **Contrato 004**: formato aprovado com um ajuste (`id_origem` em cada item); a rota do av-hub ainda não existe e o MES usa um registro manual da compra até lá. **C1 concluída em 22/09, C4 atendida, C3 atrasada** (começa agora). O setor "Logística de Entrada" do MES virou "Recebimento". **Ficam com o Nathan:** nomes dos campos do 003, regra do pedido sem prazo, onde fica o job de leitura do av-hub (F2) e o aceite das diferenças do 005; **com o backend:** a chave própria do MES, de escrita e restrita por rota (L6). Detalhe em cada contrato e em [[Perguntas-em-Aberto-Consolidadas]] seção 0.
>
> **Adendo de 06/10/2026 — Compras e cadastros de acesso (av-hub, API e contratos).**
> - **Contratos 36, 37 e 38 entregues pelo DBA** e movidos para `Realizados/` (o 37 já em produção; P1 do 36 e o 38 conferidos no código da `develop`, `c8f2f5e`). **Contrato 39 novo** ([[39-Vendedores-Fila-de-Vinculo]]): filtro "sem funcionário" e nomes do vínculo na API de vendedores — patch pronto, falta o DBA.
> - **HRM compra pela própria conta Omie**: o DBA limpou `id_unidade_compra` da HRM em produção (na `api-test` ainda aponta para Mogi). Ver [[Decisoes-Chave-ERP]].
> - **OC a partir de requisição do MES** (av-hub#151, na `main`): já traz PV, produto e destino; a OC leva só os itens das requisições; **comprador só compra da filial a que pertence**.
> - **Telas de Compradores e Vendedores** refeitas como fila de trabalho (vínculo lado a lado, candidatos sem digitar): Compradores na `develop` (av-hub#154); Vendedores aguarda o contrato 39 (av-hub#155). **Em produção, 0 dos 74 compradores estão ligados a funcionários**: sem isso ninguém emite OC (contrato 38).
> - **Produção (`auth.telas`)**: criadas `suprimentos` e `painel-comprador`; `compradores` movida para Cadastros › Acessos com permissão para o Admin (Dev).
> - **Proposta de transferência de estoque entre filiais** registrada: [[Proposta-Transferencia-Estoque-Filiais]] (7 decisões pendentes).
> - Pendências novas em [[Perguntas-em-Aberto-Consolidadas]] seção 0 (bloco "Compras e acessos, 06/10").

## 1. Em uma frase

**O planejamento está feito e a construção começa amanhã.** Nada do que precisa ser construído está pronto; o que existe hoje é a Entrada Comercial (Omie → pipeline → av-hub) e o motor de Flanges no MES.

## 2. Linha do tempo

| Data | Marco | Situação |
|---|---|---|
| 16/09 a 21/09 | Análise, fluxos, PRD, cronograma, contratos e modelo de rastreabilidade | **Concluído** (planejamento) |
| **21/09** | **Hoje** | Vault unificado; auditoria contra dump de produção; **8 das 11 DEC decididas em conversa direta** (DEC-1, 2, 3, 5, 7, 9, 10, 11) + DEC-12 nova (genealogia de material); ~45 das ~60 perguntas da lista consolidada fechadas |
| **22/09** | **Início da execução (S1)**. O cronograma previa S1 desde 18/09, então as janelas estão deslocadas um dia | Próximo |
| 25/09 | **M1** — DEC-1 a DEC-9 respondidas (ou default adotado por escrito), contratos destravados, hardware aprovado | **Quase lá**: 6 das 9 (DEC-1,2,3,5,7,9) já decididas. Restam DEC-4 (a mais urgente — trava D1), DEC-6 e DEC-8 (adiada de propósito) |
| 29/09 | Spec da integração av-hub ↔ MES aprovada (F1) | **Em andamento**: Robert aprovou com ajustes em 30/09; faltam 4 decisões do Nathan e o Gustavo |
| 02/10 | **M2** — Fundação no ar | Não iniciada |
| 16/10 | **M3** — Fase 0 (sistema) pronta | Não iniciada |
| 30/10 | **M4** — Fases A + B em homologação | Não iniciada |
| 13/11 | **M5** — Fase 0 fechada + Fase C | Não iniciada |
| 18/11 | **M6** — Go/no-go do piloto | Não iniciada |

Detalhes de cada marco em [[Cronograma-2-Meses]].

## 3. O que já está pronto

| Item | Onde | Observação |
|---|---|---|
| Fluxo operacional mapeado (macro e item a item, 6 subfluxos) | [[Fluxo-Detalhado-Pedido-Item]], [[Fluxogramas-Completos]] | É o processo-alvo; não está em nenhum sistema ainda. Encaixe do Estoque e da Revenda no MES decidido em 24/09 — [[Encaixe-Estoque-Revenda-no-PCP]] |
| PRD do Estoque, Recebimento e Compras | [[PRD-Estoque-Visao-Geral]] | Só planejamento, **não construído** |
| Análise dos backends e do pipeline | [[Omie-ELT-Pipeline]], [[App-PCP-Backend-Producao]] | Leitura de código; sem alterações |
| Levantamento da API do Omie e roteiro de extração | [[Indice-Integracao-Omie]] | Lacunas mapeadas |
| Cronograma de 2 meses | [[Cronograma-2-Meses]] | Plano, com premissas de capacidade que ainda precisam de confirmação |
| Contratos SQL (6) e de API (2) | [[Indice-Contratos]] | **5 SQL + 1 API já aplicados em produção** (confirmado por [[Auditoria-Dump-Producao-2026-09-21]] em 21/09); 1 invalidado (006); só o API 002 (Estoque/MES) segue genuinamente proposta |
| Modelo de rastreabilidade, custódia e SLA | [[Rastreabilidade-e-SLA-de-Eventos]], [[Campos-e-API-para-Rastreabilidade]] | **Proposta**, para a spec F1 |
| Protótipo de tela (Torre de Fluxo) | [Artifact](https://claude.ai/artifact/SS4C4srRk9cr66UHUS2rE3) | Dados fictícios; não é sistema |
| Perguntas em aberto consolidadas | [[Perguntas-em-Aberto-Consolidadas]] | Atualizada em 29/09: de ~60 perguntas, 10 pendências reais restam (seção 0 da nota) — o resto foi decidido, aceito ou ficou moot |
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
| C1 | Login duplo no MES | Robert | 21/09–29/09 | **Concluída** em 22/09 (informado pelo Robert em 30/09) | — |
| C3 | Desenho do RBAC por setor | Robert | 21/09–29/09 | **Atrasada** — o Robert começa em 30/09 | — |
| D1 | Schema Prisma do Estoque v1 | Pablo | 21/09–29/09 | Não iniciada | **DEC-4** (DEC-7 já decidida) |
| F1 | Spec da integração av-hub ↔ MES | Nathan | 21/09–29/09 | **Em andamento** — contratos 003, 004 e 005 escritos; Robert aprovou com ajustes em 30/09; faltam as decisões do Nathan sobre os ajustes e a aprovação do Gustavo | DEC-2 |
| A3 | Pauta financeira e critérios de aceite | Nathan | 28/09–02/10 | Não iniciada | — |
| B3 | Aplicar contratos SQL 001 e 005 | Gustavo | 28/09–02/10 | **Concluída** — já aplicado em produção antes do início da S1; confirmado por [[Auditoria-Dump-Producao-2026-09-21]] (21/09). Capacidade do Gustavo nessa janela fica livre | B1 |
| B4 | API `alterado_desde` em produtos e parceiros | Gustavo | 28/09–02/10 | **Concluída** — já implementado em `produtos.js`/`parceiros.js`; confirmado por [[Auditoria-Dump-Producao-2026-09-21]] (21/09) | B1 |
| C4 | Carteira do PCP: importar itens do pedido | Robert | 28/09–02/10 | **Concluída** — confirmado pelo Robert em 30/09, já lendo `/pedidos_liberados` (L4 do [[26-Vendas-Liberacao-Pedido]]) | — |
| D2 | Módulo base do Estoque e testes e2e | Pablo | 28/09–02/10 | Não iniciada | D1 |
| C2 | Vínculo Fábrica ↔ Filial | Robert | 30/09–02/10 | Não iniciada | **DEC-1** |
| D3 | Projeção read-only de material e parceiro | Pablo | 30/09–02/10 | Não iniciada | B4 |

S2 a S4 e o fechamento seguem o [[Cronograma-2-Meses]]; entram neste quadro quando a sprint começar.

## 6. O que está bloqueando ou em risco agora

> **Reorganizado em 21/09/2026, contagem atualizada em 29/09.** A lista completa e atualizada de pendências reais vive só em [[Perguntas-em-Aberto-Consolidadas]] seção 0 (10 itens) — não duplicada aqui, pra não ter duas fontes de verdade desalinhando. Esta seção lista só os riscos de **cronograma/execução**, não as perguntas de negócio em si.

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
