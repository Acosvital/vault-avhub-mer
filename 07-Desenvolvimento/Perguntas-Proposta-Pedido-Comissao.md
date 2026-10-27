---
tags: [decisoes, perguntas, oq, consulta, proposta, orcamento, comissao, staging]
criado: 2026-10-16
atualizado: 2026-10-16
status: proposta
dono: Nathan
fontes: [Proposta-Orcamento-Comissao/00-Briefing-Decisoes (OQ-02 a OQ-12, fora do vault), Proposta-Orcamento-Comissao/08-Reuniao/Proposta-Orcamento-Pedido-Comissao.docx (fora do vault) (perguntas das seções 4 e 5), Modelo-de-Consulta, api-comercial 5aa5311, Dump Avhub 14/10, Registro-de-Decisoes]
---

# Perguntas em aberto: OQ-02 a OQ-48

OQ-02 a OQ-12 são do briefing do Nathan (16/10/2026); a OQ-01 foi respondida em 16/10 (N16-18) e saiu da lista, e o ID não é reaproveitado. OQ-13 a OQ-30 apareceram ao documentar o fluxo, a numeração, o pedido por API, o custo real e a tela da proposta; cada uma diz de onde veio. **Renumeração:** a pergunta "quem marca aprovada" era OQ-11 e a "cancelada é perdida" era OQ-12 na rodada anterior; passaram a **OQ-26** e **OQ-27** porque o briefing usa OQ-11 e OQ-12 para o imposto e o encargo do custo real (N16-20). O que tem **default 🟡** é o que o time adota se ninguém responder. Decisões já tomadas: [[Registro-de-Decisoes]]. **Estudo do Omie (21/10/2026), em [[Estudo-Omie-API]]:** a documentação resolve a OQ-15 (usar `codigo_pedido_integracao` e gravar a liberação na resposta do `IncluirPedido`) e a OQ-16 em parte (etapa `"10"` e campos; obrigatórios, numeração e `bloqueado` só por teste); mostra que **não existe cancelar pedido por API** (OQ-17, OQ-48); que o **imposto da OC existe por item em valor, sem DIFAL** (OQ-37) e vem **com percentual na NF de entrada**; que a documentação lista a ligação da NF de entrada ao item da OC e a quantidade devolvida por item, mas **o Nathan informou que na prática nenhuma das duas existe** (OQ-39, N16-57, OQ-42): o vínculo da NF fica manual com o PCP e a proporção da devolução precisa de outra fonte. **Respondidas pelo Nathan em 16/10/2026 (N16-21 a N16-38):** OQ-06, 09, 10, 11, 12, 13, 14, 17, 19, 20, 22, 24, 26, 27, 29 e 30; texto completo em [[Registro-de-Decisoes]].

Quando a pergunta pede uma **resposta de negócio** de quem opera, ela vira um contrato de Consulta (`CON-NN`, regras em [[Modelo-de-Consulta]]). Os IDs `CON-01` e `CON-02` já existem; os novos são **CON-03, CON-04 e CON-05** (agrupados por destinatário, no máximo cinco perguntas cada, mensagem pronta para o WhatsApp). Perguntas técnicas (Robert, Gustavo, Pablo) não viram Consulta: entram em [[Pontas-Soltas]] com ID `PS-nnn`.

## 1. Quadro geral

| ID | Pergunta (resumo) | Quem responde | Vira | Bloqueia |
|---|---|---|---|---|
| OQ-02 | ✅ **Respondida (N16-58, N16-59):** sem prazo fixo, com o tempo cronometrado; o setor orçamentário é **novo**; o Moisés é uma das pessoas (N16-104) | Nathan (feito) | CON-03 | `B3`, `B4`, N16-06 |
| OQ-03 | Quem decide o que fazer com o cliente quando o custo real passa do cotado? | João Vitor | CON-03 | processo, não sistema |
| OQ-04 | ✅ **Respondida (N16-75):** tudo fisicamente; não há alçada no sistema. Quem aprova e até quanto fica fora do sistema | João Vitor | CON-03 | contrato do próximo ciclo |
| OQ-05 | ✅ **Respondida pela Michele (N16-50):** lista proposta com exportação para Excel, mais markup real por vendedor e Faturamento × Compras por pedido, separando Revenda, Industrializado e Projeto, com sinal de recompra | Michele (feito) | CON-04 | `K4` |
| OQ-06 | ✅ **Respondida (N16-34 e N16-43):** bloqueio, listas, regras fixas e coordenadores valem todos; a Michele confirmou os detalhes | Nathan e Michele (feito) | CON-04 | SQL-018 |
| OQ-07 | Custo obrigatório em todo lote, inclusive carga inicial de 13/11 | Robert | PS (técnica) | G1, BL-031, `R4`, `E3` |
| OQ-08 | ✅ **Respondida por Compras (19/10):** mão de obra se reconhece pela categoria "Despesas com Industrialização", ou "Serviços Tomados – PJ/PF" com o campo "Nº do Pedido do Fornecedor" apontando um PV | Compras (feito) | CON-05 | custo real de serviço |
| OQ-09 | ✅ **Respondida (N16-36):** erro de sincronia, com o motivo e o botão "Tentar novamente" | Nathan (feito) | PS (técnica) | `V0.7` |
| OQ-10 | ✅ **Respondida (N16-32), confirmada por Compras (19/10):** produto × fornecedor × unidade × vigência | Nathan e Compras (feito) | CON-05 | `B1`, `B2` |
| OQ-11 | ✅ **Respondida (N16-38):** o vendedor preenche na proposta; ao chegar a requisição do PCP, os dados da proposta preenchem os campos novos da OC e Compras confere e edita antes de comprar | Nathan (feito) | PS (técnica, liga PS-014 e BL-053) | campos novos na OC e no item da OC |
| OQ-12 | ✅ **Respondida (N16-22):** o encargo entra no **preço sugerido**, como no motor atual, e não no custo do evento; percentual cadastrado por condição | Nathan (feito) | PS (técnica) | custo líquido real por evento, `K2`, N16-20 |
| OQ-13 | ✅ **Respondida (N16-23 e N16-37):** o custo vem da OC aprovada; o lote só identifica a OC de origem | Nathan (feito) | PS (técnica) | `K2` |
| OQ-14 | ✅ **Respondida (N16-26):** sequência por unidade e tipo; o número do Omie segue a chave no MES | Nathan (feito) | PS (técnica) | N16-04 |
| OQ-15 | ⏳ **Em estudo (Nathan):** como gravar a liberação "na criação" se a chave é o número do Omie? | Nathan, Gustavo | PS (técnica) | [[LOG-58-Liberacao-do-Pedido-Origem-Proposta]] |
| OQ-16 | ⏸ **Testes adiados para depois das telas (N16-82).** Respondido: o Omie aceita o nosso número de pedido; vencimento do faturamento; reutilizar o código de integração depois de apagar é possível. **CFOP e cenário:** N16-83. ⏳ **Em estudo (Nathan):** etapa inicial e campos obrigatórios do pedido criado no Omie | Nathan, Gustavo | PS (técnica) | `V0.7` |
| OQ-17 | ✅ **Quem cancela: o vendedor, por API (`CancelarPedidoVenda`), N16-84.** ✅ **Respondida (N16-30):** só avisa e traz a mudança; o João Vitor pode contestar | Nathan (feito) | CON-03 | `V0.7`, `K3` |
| OQ-19 | ✅ **Respondida e confirmada pela Michele (N16-35, N16-42):** a comissão nasce na NF com o custo real, sem estimativa | Nathan e Michele (feito) | CON-04 | `K2`, `K3` |
| OQ-20 | ✅ **Respondida (N16-31):** qualquer item sem custo e sem fornecedor | Nathan (feito) | CON-03 | N16-03 |
| OQ-21 | ⏸ **Os perfis serão cadastrados depois (N16-85).** Perfis e permissões novos de Vendas, Orçamento, Compras e Comissão | Nathan, Gustavo | PS (técnica) | N16-13 |
| OQ-22 | ✅ **Respondida (N16-27):** PTAX do dia da aprovação | Nathan (feito) | CON-05 | cálculo da proposta |
| OQ-23 | ✅ **Respondida por Compras (19/10):** não há conversão de unidades no sistema; a OC segue a unidade do faturamento do fornecedor. Abre a OQ-34 | Compras (feito) | CON-05 | `K2`, PS-006 |
| OQ-24 | ✅ **Respondida (N16-28):** não vira pedido até o cadastro | Nathan (feito) | PS (técnica) | `V0.7` |
| OQ-25 | ✅ **Respondida pela Michele (N16-48):** comissão só sobre as peças com custo real, sem usar o cotado para o resto; a diferença vem na apuração seguinte, para nova decisão. **Diverge do default** | Michele (feito) | CON-04 | `K2` |
| OQ-26 | ✅ **Respondida (N16-25):** o vendedor marca, confirmando a aprovação física; grava quem, quando e qual revisão. O João Vitor pode contestar | Nathan (feito) | CON-03 | `V0.4`, `V0.5` |
| OQ-27 | ✅ **Respondida (N16-24):** um estado só, `CANCELADA`, que não reabre | Nathan (feito) | CON-03 | `V0C` |
| OQ-28 | ⏳ **Respondida em parte (N16-51):** o passo sai do fluxo e fica desligado; o valor estimado por Compras vem do Omie, sem digitação. **Compras ainda valida** | Compras | CON-04 | tela de Compras, N16-19 |
| OQ-29 | ✅ **Respondida (N16-33):** inativar também em produção, no mesmo SQL | Nathan (feito) | PS (técnica) | [[LOG-57-Menu-Vendas-Orcamento-Compras]] |
| OQ-30 | ✅ **Respondida (N16-29):** pode corrigir, com histórico | Nathan (feito) | PS (técnica) | [[LOG-58-Liberacao-do-Pedido-Origem-Proposta]] |
| OQ-31 | ✅ **Respondida (N16-37):** o custo vem da OC; o lote é o conjunto de material comprado de uma OC específica, então não há soma dupla | Nathan (feito) | PS (técnica) | `K2` |
| OQ-32 | ✅ **Respondida (N16-87):** ao devolver a sobra, calcula-se o peso (ou a quantidade) e ela entra para o estoque. ⏳ **Respondida em parte por Compras (19/10):** aproveitamento é do PCP ou da Engenharia; sem sobra aproveitável o custo todo da chapa vai para o PV; sobra aproveitável vai ao estoque, e Compras só anota na observação da OC. **Falta:** como a sobra ganha custo e como o custo dela entra no pedido que a usa (o simulador do vendedor indica o aproveitamento, mas não há evento de custo). Quem responde: PCP, Engenharia e Recebimento | PCP, Engenharia, Recebimento | CON-05 | `K2`, custo do fabricado (R5) |
| OQ-33 | ✅ **Respondida (N16-40):** o custo real segue o valor efetivamente recebido, pela NF de entrada; a OC aprovada vale só até o recebimento | Nathan (feito) | PS (técnica) | `K2`, N16-23, N16-37 |
| OQ-34 | ✅ **N16-86:** o **CCP** vincula a NF de entrada **à OC**, na tela de Follow-up; o item do pedido de venda vem pelo vínculo da OC. ⏳ **Respondida em parte (N16-57):** o PCP faz o vínculo à mão, então a opção (a) (quem vincula informa a quantidade coberta) é a que combina com o processo. **Falta** confirmar com o Nathan e o Gustavo. A proposta pode estar em PC e a OC em KG, sem conversão no sistema (OQ-23) | Nathan, Gustavo | PS (técnica) | `K2` |
| OQ-35 | ✅ **Respondida (N16-41):** a base de preço vem das OC efetivadas (custo da última compra por item) e o setor orçamentário também pode atualizar os valores. Restam a OQ-40 e a OQ-02 | Nathan (feito) | PS | `B1`, `B2`, N16-07 |
| OQ-36 | **Produto novo e Fiscal.** O vendedor pede ao Fiscal o cadastro do produto antes de emitir o pedido de venda. Quem cadastra no Omie, e em quanto tempo? Origem: B8 de Compras (a resposta passou para o Fiscal) | Fiscal | CON-06 | N16-28, `V0.7` |
| OQ-37 | ✅ **Respondida (N16-53):** o hub não guarda o imposto da OC; o Omie guarda. O Nathan traz esses dados para o hub, Compras os edita no hub, e o que ela editar volta ao Omie pela mesma sincronização da OC | Nathan (feito) | PS (técnica) | N16-38, N16-20 |
| OQ-38 | **Estoque e sobras com PCP e Recebimento.** Compras diz que os dados de movimentação de estoque hoje não são efetivos e corretos e que o estoque precisa ser lapidado com o PCP; o controle da sobra é do Recebimento e do PCP. Como isso afeta "todo lote tem custo" (N16-09) e o marco zero de 13/11 (OQ-07)? Origem: B5, B11 e B12 de Compras | Robert, PCP | PS (técnica) | OQ-07, `R4`, N16-09 |
| OQ-39 | ✅ **Datas fechadas em N16-91** (dia útil; várias OCs; só avisa; não volta ao Omie). 🟡 **Datas corrigidas por N16-88:** a data do CCP não é o campo da previsão de faturamento; a previsão de faturamento é derivada (entrega + 1) e o original fica no histórico. Faltam as quatro perguntas do R72 do LOG-56. ✅ **N16-86:** o vínculo é **NF de entrada ↔ OC**, feito pelo CCP; a data do CCP é a que vale e ele só atualiza, sem sobrescrever a previsão de faturamento do pedido. ⏳ **Respondida em parte (N16-57):** quem faz o vínculo da NF de entrada ao item do pedido é o **PCP** (escrito "CCP"; ❓ confirmar). **Falta** como o sistema guarda esse vínculo (quantidade coberta, ou valor total da NF) e se a NF também traz o imposto real do evento (OQ-37 já fechada: o imposto vem da OC editada por Compras) | Nathan (confirmar a sigla), Gustavo | PS (técnica) | `K2`, OQ-34 |
| OQ-40 | ✅ **Respondida em parte (N16-52):** vale sempre o valor mais atualizado. O setor orçamentário é novo; o Moisés é uma das pessoas (N16-104); o prazo foi decidido em N16-58 | Nathan (feito); João Vitor (prazo) | PS | `B1`, `B2` |
| OQ-41 | ✅ **Respondida (N16-77):** hoje os descontos são feitos à mão, revisados vendedor a vendedor; ficam fora do sistema novo. **Descontos do vendedor (convênio, alimentação).** A "comissão" e a "ajuda de custo" do cadastro servem para descontos (alimentação de Uberaba soma). Como entram no valor a pagar? Em que apuração, com que valor, e quem os mantém? Origem: A12 da Michele | Michele, Gustavo | PS | N16-51, apuração do vendedor |
| OQ-42 | ⏳ (c) ✅ **Apuração (N16-77):** fechamento no dia final do mês e pagamento no dia 10. A recusa pelo cliente vem das 3 unidades; resta a devolução de compra. ⏳ **Respondida em parte (N16-74), para VENDA:** devolução **total** vem do Omie; devolução **parcial** só chega como "houve", sem quantidade. **Quem informa a devolução parcial: o Fiscal ou a Controladoria (N16-74).** **Faltam:** (d) a **devolução de compra** (NF de entrada devolvida ao fornecedor): como aparece no Omie e o que faz com o custo real (N16-40); (b) ✅ a **recusa** pelo cliente ("Operação não realizada" ou "desconhecida") vem da manifestação que a pipeline lê das **3 unidades** (Aços, HRM e Uberaba; Nathan, 22/10): resolvida (c) o **ciclo da apuração** do vendedor (mensal?), quando fecha e quem o fecha. Origem: A16, A18, A21 da Michele | Nathan, Michele, Fiscal | PS (técnica) | N16-47, N16-48, N16-49 |
| OQ-43 | ⏸ **Fica para depois** (N16-77: sem resposta; não trava). **Reforma tributária.** A CBS substitui PIS/Cofins a partir de janeiro/2027: os percentuais de imposto precisam de nova vigência. Quem informa os novos percentuais e quando? Origem: A2 da Michele | Michele | PS | N16-42, parâmetros |
| OQ-44 | 🟡 **Respondida em parte (N16-77):** só Industrializado entra no simulador; Revenda recebe 2%; Projeto sem resposta; recompra sem resposta. ✅ **Conflito resolvido (N16-78):** revenda comissiona por letra pela margem; fabricação recebe 2% fixo; o desenho não muda. **Revenda, Industrializado e Projeto, e recompra.** Como cada pedido ou item é classificado em Revenda, Industrializado ou Projeto? O que é "recompra no mesmo pedido" (mesmo item comprado de novo)? Origem: A22 da Michele | Michele, Nathan | PS | N16-50 |
| OQ-45 | 🟡 **Respondida em parte (N16-77):** fabricação interna 2% fixo (sim); origem do ICMS na mão de obra, DIFAL da compra e passo de Compras sem resposta. **Validações pendentes.** Joanes: fabricação interna com custo real (A4). Compras: origem de compra para o ICMS da mão de obra (A5), DIFAL da compra (A6) e o passo de Compras sobre o percentual (A20) | Joanes, Compras | CON-05 | N16-51 |
| OQ-46 | ✅ **Respondida (N16-55):** score 50/30/20, top fornecedores por categoria, volatilidade pelo coeficiente de variação e dado recente pela última cotação válida. **Os valores do SQL eram exemplo** (pesos, 15% ou 20%, 7 ou 15 dias) e podem ser ajustados depois. Ajustes (custo líquido, prazo em dias, data real de recebimento, mínimo de pontos, pesos com vigência) **adotados em N16-56; os pontos que sobravam (7 dias de dado recente, frequência de vitória pela compra efetiva, nota neutra com "poucos dados") fecharam em N16-72**: [[Proposta-Score-e-Volatilidade-OQ-46]] | Nathan (feito) | CON-05 | `B1`, `B2` |
| OQ-47 | ✅ **Fluxo confirmado em 22/10 (N16-76).** **Respondida (N16-61, N16-62, N16-63):** compra maior que a da proposta pede a aprovação do vendedor, **sem tolerância**, **por produto**, **sem tempo limite** (fica na lista dele); reprovada, a Gerência (João Vitor ou Sérgio Vital) decide; se a Gerência reprova, Compras procura valor melhor ou cancela a venda; vendedor e Compras podem conversar fisicamente. **Canal decidido (N16-64):** a tela "Meus Pedidos" do vendedor, com o andamento da venda e o que está aberto para ele. **Aviso favorável (N16-65):** só informativo. **Faltam:** (e) confirmar que o e-mail de hoje deixa de ser necessário; as demais pontas estão na OQ-48 | Nathan, Compras | CON-03, CON-05 | `C6`, `C7`, OQ-03 |
| OQ-48 | ✅ **Cancelar × excluir (N16-91, N16-92):** cancelar marca cancelado e devolve o valor ao original (sequencial); excluir apaga. **Aberto: criar sequencial pela API do Omie.** ✅ **Cancelar existe por API (N16-84):** `CancelarPedidoVenda`, `ExcluirPedido`, `AlterarPedidoVenda`; o vendedor faz as três antes de faturar. Falta testar cancelar × excluir. ✅ **Respondida em parte (N16-65 a N16-69):** a Gerência não cancela no sistema; a aprovação dela é conversa física; Compras leva o caso à Gerência; o vendedor só vê a notificação e resolve fisicamente; se não resolve ou não aceita, o pedido pode ser cancelado e ele renegocia com o cliente; pedido cancelado avisa a OC; o que já foi comprado vai ao Estoque, **livre**. **Requisição e OC não emitida são canceladas sozinhas, com tarja, e o PCP é avisado (N16-70).** **Pedido já faturado: não desfaz compra nem produção (N16-71).** **Pedido faturado em parte: parte por parte, confirmado.** **Falta:** como o cancelamento funciona no **Omie** (liga com a OQ-17): **o Nathan vai estudar** | Nathan | CON-03 | `V0C`, `C6`, `C7` |

## 2. OQ-02 a OQ-12 (do briefing)

### OQ-02 · Prazo de resposta do pedido de custo e o que fazer se vencer

**Contexto.** N16-06 manda ter prazo, sem valor. O código já tem: `SolicitacaoCusto.prazoResposta` é obrigatório e o prazo padrão é de **2 dias úteis** ("SLA padrão", `api-comercial/src/modules/custos/custos.routes.ts:378`); a fila mostra `ATRASADA`, `VENCE_HOJE` ou `NO_PRAZO` (`:338`). Não há regra para o vencimento além do rótulo.

**Opções para o vencimento.** (a) só destacar na fila do Orçamento; (b) avisar o gerente do Orçamento; (c) liberar o vendedor para cotar sozinho (a rota `POST /solicitacoes_custo/:id/liberar` existe, `custos.routes.ts:500`); (d) cancelar a solicitação. **Opções para o prazo:** fixo (2 dias úteis), escolhido pelo vendedor, ou por tipo de produto.

**Quem responde.** João Vitor. **Default 🟡:** 2 dias úteis, rótulo `ATRASADA`, aviso ao gerente do Orçamento, e o vendedor **nunca fica bloqueado** (N16-06): ele pode seguir sozinho. **Vira:** CON-03.

### OQ-03 · Quem decide o que fazer com o cliente quando o custo real passa do cotado?

**Contexto.** O sistema não avisa o vendedor (N16-18); a Controladoria vê a diferença. Renegociar o preço, absorver a perda ou cancelar é decisão de pessoas.

**Opções.** O vendedor com a Gerência; só a Gerência; o vendedor sozinho dentro de um limite.

**Quem responde.** João Vitor. **Default 🟡:** a decisão fica **fora do sistema** neste ciclo; a Gerência decide com o vendedor. **Vira:** CON-03.

### OQ-04 · Quem aprova desconto e margem, e até quanto cada um aprova?

**Contexto.** A aprovação é física neste ciclo (N16-12) e entra no sistema no próximo. A resposta define a regra desse ciclo.

**Opções.** Alçadas por faixa de desconto, por faixa de margem, por valor total da proposta ou por cliente; um aprovador por faixa.

**Quem responde.** João Vitor. **Default 🟡:** nada a construir neste ciclo; a pergunta fica aberta para o próximo contrato. **Vira:** CON-03.

### OQ-05 · Relatórios da visão geral da Controladoria

**Contexto.** A Controladoria vê tudo até chegar a ela e tem a visão geral de todas as comissões (N16-10). Falta saber quais relatórios entram **no primeiro momento**.

**Candidatos 🟡.** Comissão por vendedor e por mês; estimada × real × final; pendentes de decisão; decididas por ação (aprovada, desaprovada, bloqueada, cortada, alterada); diferença entre custo cotado e custo real por proposta; comissões de propostas canceladas (histórico).

**Quem responde.** Michele. **Default 🟡:** lista filtrável por mês, vendedor, unidade e status, com totais e exportação em planilha. **Vira:** CON-04.

### OQ-06 · Bloqueio, blacklists e coordenadores no módulo novo

**Contexto.** N16-11 traz o motor atual para a proposta: percentual final = menor entre o do vendedor e o de compras, regras fixas, bloqueios e blacklists. Falta confirmar com a Michele se **todos** valem no módulo novo e como ficam os coordenadores (hoje `comissao_coordenadores`, ainda lidos de JSON no front, LOG-42).

**Opções.** (a) Copiar tudo (bloqueio por NF, blacklist de clientes, blacklist de vendedores, regras fixas) e manter as listas separadas do módulo atual; (b) as listas passam a ser uma só, compartilhada; (c) coordenadores ficam no módulo atual até uma decisão própria.

**Quem responde.** Michele. **Default 🟡:** (a) e (c). **Vira:** CON-04.

### OQ-07 · Custo obrigatório em todo lote, inclusive carga inicial de 13/11

**Contexto.** N16-09 torna o custo obrigatório em todo lote e supera o #93. A carga inicial em lote (G1, BL-031) está em desenvolvimento pelo Robert para 23/10, com custo **opcional**, antes do levantamento físico de 26 a 30/10 e do marco zero de 13/11. Exigir custo de todo o saldo inicial é trabalho de Compras e Controladoria, não só de código.

**Opções.** (a) Obrigatório já na G1: sem custo, a linha não entra; (b) obrigatório no Recebimento (`R4`) e, na carga inicial, custo informado ou custo estimado com origem `MANUAL`, motivo obrigatório e auditoria (a origem `MANUAL` já existe, `estoque.prisma:378-382`); (c) obrigatório só depois do marco zero.

**Quem responde.** Robert (escopo e data), com o Nathan. **Default 🟡:** (b). **Impacto:** muda a G1 e o K5 do Robert; ver a proposta de cronograma (`Proposta-Orcamento-Comissao/07-Cronograma/Proposta-de-Cronograma.md`, fora do vault, a validar). **Vira:** ponta solta técnica.

### OQ-08 · OC de serviço (mão de obra) existe no Compras?

**Contexto.** N16-09 diz que a mão de obra também é gerada na OC e entra no custo. No exemplo do Nathan, o item B é "1 Mão de obra". No código do av-hub, o item da OC exige produto do cadastro (LOG-36) e só tem `tipo_material` `acabado` ou `nao_acabado` ([[Estados-e-Status]]); não conferi se há produto do tipo serviço em `core.produtos` ❓.

**O que precisa responder.** Como Compras emite hoje a OC de mão de obra (produto de serviço no Omie, texto livre, outra rotina)? Que campos o item de serviço precisa (quantidade, valor, descrição, vínculo ao pedido) para gerar uma linha de custo por item e parcial?

**Quem responde.** Gustavo (cadastro) e Compras (processo). **Default 🟡:** item de serviço como produto do cadastro, vinculado ao pedido (`ordens_compra_itens_vinculos`), igual a qualquer item. **Vira:** CON-05.

### OQ-09 · Se o Omie recusar o pedido criado no hub

**Contexto.** O pedido segue o padrão da OC: a API grava numa fila e a pipeline envia. Na OC, o retorno do Omie vai por `PATCH /compras/ordens/:id/sincronizacao`; OC com erro **sai** da fila e só volta por "Reenviar" (`omie-elt-pipeline` `envioOrdensCompra.ts:18-40`; [[04-Circuito-de-Compra]]).

**Proposta 🟡.** O pedido do hub guarda `status_sincronizacao_omie` com `pendente`, `sincronizado` e `erro` (mesmo vocabulário da OC) e o texto do erro. O vendedor vê "Pedido não criado no Omie: <motivo>" e o botão "Tentar de novo". A proposta continua `APROVADA`; a marcação da Qualidade não se perde.

**Quem responde.** Nathan e Gustavo. **Vira:** ponta solta técnica.

### OQ-10 · Matriz de preços: dimensões

**Contexto.** N16-07 diz que a matriz será criada. Hoje existe só a oferta por produto e fornecedor, com histórico e média (`Oferta`, `suprimentos.prisma:138-183`).

**Candidatos 🟡.** Por unidade (Mogi, Uberaba, Aruja); por período de vigência; por condição de compra (CIF ou FOB, mínimo, prazo, origem do ICMS); por quantidade (faixas de escala); por moeda.

**Quem responde.** Nathan e Compras (o setor que vai usar). **Default 🟡:** produto × fornecedor × unidade × vigência até a resposta. **Vira:** CON-05.

### OQ-11 · De onde vêm o IPI, o ICMS, a ST e o DIFAL reais de cada evento de custo

**Contexto.** N16-20: cada evento de custo carrega as suas condições (condição de pagamento, encargo, impostos, frete, fornecedor) e o custo líquido do evento sai da fórmula do motor. A OC do hub **não guarda** IPI, ICMS, ST nem DIFAL por item (só preço, desconto e, no cabeçalho, frete, seguro, moeda e condição de pagamento; N14-23 deixou o Ciclo 1 sem imposto). O desenho do imposto por item já era a PS-014 e o BL-053.

**Opções.** (a) campos novos na OC e no item da OC, preenchidos por Compras; (b) a nota fiscal de entrada (chave de 44 dígitos que o Recebimento já confere; `ListarNF` da pipeline); (c) as duas, com a NF como verdade.

**Quem responde.** Nathan, Gustavo e Compras. **Default 🟡:** (c). **Impacto:** sem a resposta, o custo real por evento sai **sem imposto** (como o Ciclo 1), e o cenário com imposto do motor não fecha; ver a proposta de cronograma (`Proposta-Orcamento-Comissao/07-Cronograma/Proposta-de-Cronograma.md`, fora do vault, a validar) (dependência 🔴). **Vira:** ponta solta técnica ligada à PS-014 e ao BL-053.

### OQ-12 · Encargo financeiro do evento

**Contexto.** O encargo do evento vem da condição de pagamento da OC (código e parcelas). Hoje a OC não guarda o percentual de encargo; o Simulador usa o encargo cadastrado por condição (ex.: 28/45, 1,5%).

**Opções.** (a) calcular das parcelas (vencimento e valor) da OC; (b) cadastrar o percentual por condição de pagamento.

**Quem responde.** Gustavo e Compras. **Default 🟡:** (b), reaproveitando o cadastro de condições do motor. **Vira:** ponta solta técnica.

## 3. OQ-13 a OQ-30 (descobertas ao documentar)

| ID | Contexto e origem | Opções | Default 🟡 |
|---|---|---|---|
| **OQ-26** Quem marca "aprovada" | A aprovação da Gerência é física (N16-12), mas o sistema precisa de um estado "aprovada" que libere o botão `V0.6` (N16-02) e trave a edição (N16-03). Origem: leitura do `StatusProposta` (`ABERTA`, `PARCIAL`, `FECHADA`, `PERDIDA`, `enums.prisma:69-76`), que não tem esse papel | (a) o vendedor marca "Aprovada pela Gerência" e confirma que tem a aprovação física, o sistema grava quem, quando e **qual revisão**; (b) só perfil da Gerência marca; (c) o vendedor marca e a Gerência confirma depois no sistema (próximo ciclo) | (a), com o número da revisão e os totais na tela de confirmação |
| **OQ-27** "Cancelada" é "perdida"? | O briefing fala em proposta **cancelada**; o código tem `PERDIDA` com motivo obrigatório e `reabrir` (`propostas.service.ts:555-606`) | (a) um só estado `CANCELADA` com o motivo da perda; (b) dois estados: `PERDIDA` (cliente não fechou) e `CANCELADA` (vendedor desistiu); reabertura: (i) nunca, o vendedor duplica (`POST /:id/duplicar` existe, `propostas.routes.ts:125`), (ii) só antes de aprovar | (a) e reabertura (i): cancelada não volta; duplica |
| **OQ-13** Evento do custo real | N16-09 diz "por evento" e "vem da ordem de compra". Não diz em que momento a linha nasce. Origem: exemplo do Nathan (dias 01 a 05) | OC: (a) emitida, (b) aprovada, (c) recebida. Lote do Estoque: (a) reserva (`E3`), (b) saída (`E6`) | OC **aprovada** (valor firme; OC cancelada estorna a linha); lote na **reserva** (`E3`), confirmada na saída (`E6`) |
| **OQ-14** Dois números do pedido | N16-04 diz "só números" e "sincroniza com o Omie". O Omie atribui o próprio número (`numero_pedido`), que é a chave em `pedidos_vendas`, na liberação e no MES; o número próprio iria em `cCodIntPed` (limite de 20 caracteres). A OC usa `OC-000001` por unidade (`fn_proximo_numero_documento`, Dump Avhub 8110-8140) | Sequência: por unidade (como a OC) ou por empresa emissora e ano (como a proposta hoje) | Por **unidade e tipo** (`contadores_documento`, com `CHECK` ampliado para `proposta` e `pedido_venda`); o número do Omie continua a chave no MES |
| **OQ-15** Liberação gravada na criação | `pedidos_vendas_liberacao` tem chave `(codigo_empresa, numero_pedido)` com o número do Omie, `acompanhamento_qualidade` e `liberado_por` obrigatórios (Dump Avhub 18285-18296). O número do Omie só existe depois da resposta da API | (a) a pipeline, ao trazer o pedido (casa por `cCodIntPed`), grava a liberação com o que a proposta guardou; (b) a pipeline grava a liberação na resposta do `IncluirPedido`; (c) trigger no banco | (b): é o momento em que o número do Omie nasce; sem janela em que o pedido existe sem liberação |
| **OQ-16** Etapa e campos do pedido no Omie | A view da liberação só aceita pedido com `etapa <> 0` ([[01-Vendas-Liberacao]] regra 10); etapa 0 é orçamento no Omie. Os nomes das etapas 10, 15 e 20 estão pendentes (#52) | Etapa inicial: a de "Pedido de venda" da conta; campos: vendedor, condição, parcelas, projeto, frete | Etapa de pedido de venda; Gustavo e Nathan conferem no Omie |
| **OQ-17** Pedido mexido no Omie depois | Se alguém altera item ou cancela o pedido direto no Omie, a proposta aprovada e a comissão estimada divergem. Origem: LOG-45 e #15 (o Omie é o sistema fiscal) | (a) só aviso e a pipeline traz o que mudou; (b) pedido cancelado cancela a proposta e a comissão vira histórico | (a); decisão de negócio com João Vitor |
| **OQ-19** Pedido sem proposta | Para o pedido que chega do Omie sem proposta não há `V0.3`, logo não há `K1`. O `V2` e o `V3` seguem como hoje (N16-05) | (a) `K2` e `K3` calculam só na NF com o custo real, sem estimativa; (b) o vendedor preenche uma estimativa no pedido | (a): a comissão nasce na NF; o motor é o mesmo |
| **OQ-20** "Parte de compras vazia" | N16-03 impede aprovar proposta incompleta. O código aceita item sem custo (`origemCusto = SEM_CUSTO`, `vendas.prisma:144`) | (a) qualquer item sem custo e sem fornecedor deixa a proposta incompleta; (b) só quando **todos** os itens estão vazios; (c) item de serviço fica fora | (a), com (c) a confirmar |
| **OQ-21** Perfis e permissões | N16-13: "cada perfil recebe o seu módulo". A capacidade hoje deriva de telas (`propostas`, `propostas-valores`, `custo-item`, `painel-comprador`, `simulador`, `capacidades.ts:47-56`) e o SQL de 16/10 cria `solicitacoes-custo`. Faltam as telas da comissão e da decisão da Controladoria | Lista de perfis por módulo; quem vê custo, margem e comissão estimada | Matriz 🟡 da [[LOG-56-Fluxo-da-Proposta-ao-Pedido]] seção "Permissões"; Gustavo cadastra |
| **OQ-22** PTAX de que dia | N16-13: a PTAX do hub. A proposta em USD ou EUR guarda `cotacaoMoeda` (`vendas.prisma:62`); o `api-comercial` usa AwesomeAPI (`cambio.ts:1-2`) | Dia da criação da revisão, da aprovação ou da criação do pedido | Dia da **aprovação** (congela com o preço fechado); a OC usa a PTAX da OC ([[LOG-11-Compras-Cotacao-Moeda-PTAX]]) |
| **OQ-23** Unidade de medida diferente | Proposta em `PC`, `KG`, `M`, `TN`...; OC e lote em outra unidade. Já era a PS-006 e o D2 do 008, que o N16-09 supera | (a) fator de conversão por produto; (b) bloquear até alguém converter à mão; (c) custo parcial marcado "unidade diferente" | (c) no Ciclo 1; (a) depois. **Pergunta a Compras** |
| **OQ-24** Produto pendente vira pedido? | Produto novo na proposta nasce `PEND-xxxx` sem cadastro no Omie (`produtos_pendentes`, [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] seção 3.3); o Omie recusa item sem cadastro | (a) a proposta com produto pendente não vira pedido até o cadastro; (b) `V0.7` cria o produto no Omie | (a) |
| **OQ-25** Comissão enquanto o custo é parcial | No exemplo do Nathan o item A passa dias com 10, 30 e depois 50 de 50 flanges cobertas. N16-09 diz que o custo é parcial; não diz como `K2` recalcula nesse intervalo ([[13-Custo-Real-e-Comissao-no-Fluxo]]) | (a) custo real do coberto mais cotado do restante; (b) só recalcula quando o item está completo; (c) usa o custo médio já comprado para todo o item | (a). Pergunta à Michele (CON-04) e ao Gustavo |
| **OQ-28** Aprovação de Compras sobre o percentual | O Simulador atual tem um passo de Compras: abre a simulação do vendedor, cria uma versão com os custos corrigidos (origem `COMPRAS`) e aprova; o percentual final é o menor entre o do vendedor e o de Compras (`simulacoes.route.js:30-36`, `:233-259`; `simulador/page.tsx:1192-1234`; chip "Comissão: após a aprovação de Compras" na imagem do Simulador). N16-08 diz que Compras **não altera a proposta**; N16-19 manda usar o mesmo motor | (a) o passo some: o cálculo `REAL` gerado pelos eventos de custo (`C7`, OC, lote) faz o papel da versão de Compras; (b) Compras ainda aprova a comissão estimada antes de a proposta ser aprovada; (c) Compras confere só (`C6`), sem aprovar percentual | (a). Pergunta a Michele e ao Nathan (CON-04) |
| **OQ-29** Pedidos de Venda e NF de Saída | O Nathan inativou as duas telas na api-test (16/10). O SQL de produção não as toca. As páginas seguem no código em `app/(protected)/vendas/pedidos-de-venda` e `.../notas-fiscais-saida` | (a) inativar também em produção, no mesmo SQL; (b) manter só em produção até decidir | (a) se o Nathan confirmar; o Gustavo inclui o passo no SQL |
| **OQ-30** Correção da marcação no pedido da proposta | Hoje o vendedor corrige a marcação até o MES importar (regra 5 de [[01-Vendas-Liberacao]]). A proposta aprovada não muda (N16-03), mas a marcação do pedido sim | (a) manter a correção, com histórico `alterado`; (b) bloquear para o pedido de origem proposta | (a) |

## 4. Consultas que saem daqui

| Consulta | Para quem | Perguntas que entram | Observação |
|---|---|---|---|
| **CON-03** Gerência | João Vitor | OQ-02, OQ-03, OQ-04 | OQ-04 respondida por N16-75 e o fluxo da compra acima do valor confirmado por N16-76: nada mais a perguntar ao João Vitor. OQ-17, 20, 26 e 27 já respondidas pelo Nathan (N16-30, N16-31, N16-25, N16-24); o João Vitor pode contestar |
| **CON-04** Controladoria | Michele | OQ-05, OQ-25, OQ-28 (OQ-06 e OQ-19 já respondidas, N16-34 e N16-35; a Michele confirma), mais as duas perguntas do documento de 16/10 que não viraram OQ: "o que a Controladoria ajusta (percentual, valor ou os dois) e com qual justificativa" (já decidido em N16-10: aprova, desaprova, bloqueia, corta, altera, sempre justifica) e "a estimada da proposta cancelada, guardada como histórico, atende a auditoria?" | Se a Michele confirmar N16-10, essas duas somem |
| **CON-05** Compras e Orçamento | Compras (Gerente de Compras, compradores) e quem vai operar o Orçamento | OQ-32 (parte aberta), OQ-34 (OQ-08, 10, 22, 23 e 33 respondidas) | O setor orçamentário ainda não tem nome de pessoa no vault ❓ |

Perguntas que **não** viram Consulta e vão para [[Pontas-Soltas]] (em 26/10/2026 entraram lá como PS-035 a PS-039; as que seguem abertas estão nesta lista): OQ-07, OQ-15, OQ-16, OQ-21 e os campos novos da OC (N16-38). As OQ-12, 14, 24 e 30 foram respondidas e só viram requisito do contrato.

## 5. Perguntas do documento de 16/10 já respondidas por decisão

| Pergunta do documento | Resposta |
|---|---|
| "Uma proposta marcada como incompleta pode ser aprovada?" (João Vitor) | Não: N16-03 |
| "Até quando uma proposta aprovada pode ser revisada?" (João Vitor) | Não pode: N16-03 (ajuste só até aprovar) |
| "O bloqueio de comissões e as listas de bloqueio valem também no módulo novo?" (Michele) | N16-11 traz bloqueios e blacklists; resta confirmar (OQ-06) |
| "A Controladoria quer ser avisada ou só ver a diferença?" (Michele) | A Controladoria vê o custo real e a diferença (N16-18); o vendedor não recebe aviso |
