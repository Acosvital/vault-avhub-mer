---
tags: [erp-acos-vital, arquitetura, lacunas, revisao, proposta]
criado: 2026-09-21
---

# Lacunas de lógica, de domínio e de clareza

> **Status: revisão de 21/09/2026, com propostas para discussão. Não são decisões.** Complementa [[Revisao-dos-Estados-e-Status]] (que trata só de estados e status). Os itens 1 a 9 foram conferidos no vault; os 10 e 11 são **ausências** (busquei e não encontrei tratamento nas notas), então precisam de confirmação de quem conhece a operação. Os itens 12 a 14 eram só documentação e **já foram corrigidos**.

## 1. Lógica que não fecha

### L-01. Dois prazos para o mesmo pedido
O Portal do Vendedor mede o SLA por `data_previsao`, que é a **previsão de faturamento** vinda do Omie ([[AV-Hub-Portal-Vendedor-Plano]]). O MES tem `prazoEntrega` ([[App-PCP-Modelo-Producao]]). A requisição de compra leva "prazo (SLA do pedido de origem)" ([[Fluxo-Compras-Completo]]). Não está dito qual delas manda no tempo por etapa.
**Proposta:** eleger uma como prazo do pedido para o SLA (a de faturamento é a que o vendedor já vê) e tratar a outra como derivada. **Decide:** Nathan com PCP e Comercial.

### L-02. O marco zero do estoque não tem data de corte
A contagem física é de 26 a 30/10 (G2), a carga e a reconciliação de 02 a 11/11 (G3) e o fechamento em 13/11 (G4). Nesse intervalo as vendas, recebimentos e expedições continuam manuais. O piloto de recebimento (11 a 18/11) cria lotes durante o fechamento. O cronograma afirma que "recebimento não consome estoque, então não depende do marco zero", mas as **entradas alteram o saldo**.
**Proposta:** definir uma **data e hora de corte** por depósito; movimento manual posterior é lançado como ajuste na carga; o piloto de recebimento só cria lotes com origem `PILOTO` (excluídos do saldo até G4). **Decide:** Nathan com Almoxarifado.

### L-03. Dois donos do saldo
O Omie tem saldo (`ListarPosEstoque`) e custo médio (`cmc`), movidos por nota fiscal. O MES terá o saldo físico. A reconciliação só está prevista na carga inicial (G3); depois disso nada diz quem é a referência, e o custo médio do Omie deixa de enxergar os movimentos do MES.
**Proposta:** decidir explicitamente o período de convivência. Sugestão: o MES é o saldo **físico** oficial; o Omie continua com o **fiscal e o custo**; uma reconciliação periódica (contrato SQL 002) lista divergências, sem corrigir uma fonte pela outra automaticamente. **Decide:** Nathan com Fiscal e Contabilidade.

### L-04. OC no av-hub e OC no Omie
A OC estruturada nasce no av-hub (E2). O envio ao Omie é "visão de futuro, não construir agora" ([[MES-Arquitetura-Decisoes]]). Enquanto isso, o Omie (que lança a NF de entrada e o financeiro) não tem a OC, e o espelho do contrato SQL 004 guarda só as OC criadas no Omie. Há duas OC sem vínculo, e o comprador pode digitar nos dois lugares.
**Proposta:** no ciclo 1, guardar no av-hub o número da OC digitada no Omie (`codigo_pedido_compra_omie`, já previsto) e conciliar por ele; o push automático fica para depois. **Decide:** Nathan com Compras.

### L-05. Fiscal: "sempre Omie" ou "desligar o Omie"?
O princípio é que nenhum módulo emite nota fiscal ([[Decisoes-Chave-ERP]]). Mas o cronograma fala em "antes do desligamento" e a síntese ([[Sintese-Migrar-vs-Nascer-Nativo]]) diz que os dados fiscais do parceiro são "críticos para emitir NF-e sem o Omie no futuro". A DEC-11 cobre só o financeiro.
**Proposta:** registrar o horizonte: "Omie permanece emissor fiscal no ciclo 1; a decisão de emitir NF-e própria é posterior e depende da DEC-11 ampliada". Assim o princípio vale como temporário e explícito. **Decide:** Nathan e diretoria.

### L-06. Como o pedido chega à fila do PCP?
O fluxo diz que o pedido "cai na fila do PCP" ([[Fluxo-Detalhado-Pedido-Item]]). A tarefa C4 importa os itens "por número do pedido" pelo gateway, que é uma busca manual. Não existe contrato de API de pedidos novos ou alterados; os únicos com `alterado_desde` são produtos e parceiros ([[001-Produtos-Parceiros-Filtro-Incremental]]).
**Proposta:** acrescentar um contrato de API `GET /pedidos_vendas?alterado_desde=` (itens incluídos) e um job de polling do MES que cria os itens em `PENDENTE_PCP`. **Decide:** Gustavo e Robert, dentro da spec F1.

### L-07. A F1 cobre 3 fluxos; os cruzamentos são mais
Os três fluxos da DEC-2 são requisição, referência da OC e status por item. Ficam de fora: a escolha de inspeção do vendedor (av-hub → MES), a alteração ou cancelamento do pedido, a mudança da `data_previsao`, a previsão de chegada da OC e o alias de material.
**Proposta:** listar todos os cruzamentos na spec F1 como uma tabela (origem, destino, dado, dono, frequência), mesmo que só três entrem no ciclo 1. **Decide:** Nathan, Robert e Gustavo.

### L-08. DEC-4 contradiz uma regra
O default da DEC-4 é "lote de carga inicial nasce **liberado**". A regra de negócio é que o lote não sai de `PENDENTE` sem `laudo_url` ([[Estoque-Regras-Negocio]]). A carga inicial não tem laudo.
**Proposta:** registrar a exceção: lote com `origem = CARGA_INICIAL` tem `status_qualidade = NAO_APLICAVEL` e `situacao_lote = DISPONIVEL`, sem laudo, com dupla conferência (ver [[Revisao-dos-Estados-e-Status]], seção 2.2). **Decide:** Nathan e Qualidade.

### L-09. Depósito compartilhado entre filiais
O depósito é "central compartilhado, não vinculado a fábrica" ([[Estoque-Modelo-Dados]]), mas `deposito` não tem `codigo_empresa`. O saldo fiscal pertence a um estabelecimento (filial/CNPJ), e a transferência entre estabelecimentos em regra exige nota fiscal de transferência (**confirmar com o Fiscal**). A DEC-1 (Fábrica ↔ Filial) precisa ser decidida junto.
**Proposta:** decidir se cada depósito pertence a uma filial; se sim, `deposito.codigo_empresa` e movimento entre filiais como evento que sinaliza a NF, sem emiti-la. **Decide:** Nathan com Fiscal, junto da DEC-1.

## 2. Lacunas de domínio (ausências)

### L-10. Sobras, perdas e unidade de medida
Não encontrei nas notas nada sobre **sobra ou retalho de chapa**, **perda no corte** ou **conversão de unidade** (kg × peça × metro). Corte de chapa é beneficiamento de Revenda e é o coração do negócio ([[Fabricacao-Chapas]]). O Omie tem `% perda` na estrutura de produto ([[Roteiro-de-Implementacao]], `ListarMalha`), mas o modelo do Estoque não tem.
**Perguntas:** a sobra de um corte volta ao estoque como material (com lote, rastreio, localização)? Como se pesa o que sobra? Qual é a unidade de controle de cada material? **Decide:** Nathan com Almoxarifado e Produção.

### L-11. Consumo de matéria-prima pela OS/OP
Não há fluxo em que a OS ou a OP **baixe o saldo por lote**. As regras dizem que "rastreabilidade para frente depende de retorno de consumo vindo do PCP" ([[Estoque-Regras-Negocio]]), sem dizer como. Sem isso, a matéria-prima nunca baixa e a genealogia lote → item entregue (pergunta R-12) é impossível.
**Proposta:** o início ou a conclusão da OS/OP gera um `MOVIMENTO_ESTOQUE` de consumo, com o lote e a quantidade, ligado ao `ItemParcial`. **Decide:** Robert e Pablo, com o PCP.

**✅ Atualização (21/09/2026): R-12 respondida — a genealogia É necessária, e já foi dimensionada e encaixada.** Vira o **bloco J** dentro da S5 (19/11-18/12) do [[Cronograma-2-Meses]]: J2 (schema `MOVIMENTO_ESTOQUE` tipo `CONSUMO`, Pablo), J3 (backend do consumo no início/conclusão da OS/OP, Robert), J4 (endpoint de genealogia, Gustavo), J5 (tela de consulta, Pablo) — 8 pd ao todo, cabem na reserva da S5 sem tirar de rastreabilidade (I1-I7). A estratégia de alocação de lote (qual baixar primeiro havendo mais de um) virou **DEC-12** — default FIFO por `data_posicao`, prazo 20/11.

## 3. Falta de clareza (corrigida)

| # | O que era | Correção em 21/09/2026 |
|---|---|---|
| L-12 | Os contratos SQL tinham no título o número antigo (006 a 011) e referências cruzadas com ele, enquanto os arquivos são 001 a 006 | Títulos agora dizem "Contrato SQL 00N (antes 0NN no omie-elt-pipeline)"; referências cruzadas atualizadas |
| L-13 | "Parcial" tem 3 sentidos e o glossário cobria só dois | Entrada nova em [[Glossario]]: `sequencial` do Omie, `ItemParcial` do MES e `Entrega` |
| L-14 | A seção "Estado atual" do Home estava desatualizada ("aguardando mais material") e competia com [[Onde-Estamos]] | Renomeada "Histórico da análise", com aviso e link para [[Onde-Estamos]] |

## 4. Risco de cronograma

### L-15. Caminho crítico sem folga
A cadeia DEC-2 → F1 → E1 → F2 → D6 termina em 30/10, que é o marco M4, e F2 e D6 terminam no **mesmo dia**. Qualquer atraso na F1 empurra o M4. O Nathan tem 40% de foco e cinco tarefas de av-hub (E1, E2, E3, F1, A1) além da coordenação, com 1 pd de folga. A ordem de corte do cronograma já prevê o que sai primeiro (seção 9), mas não há gatilho para acionar antes de 30/10.
**Proposta:** adotar um ponto de checagem em 09/10 (F1 aprovada, E1 andando) que decide se a ordem de corte é acionada. **Decide:** Nathan.

---

## 5. Resumo por decisão

| Ponto | Decide | Antes de |
|---|---|---|
| L-06, L-07 | Nathan, Robert, Gustavo | F1 (29/09) |
| L-08, L-09 | Nathan, Qualidade, Fiscal | D1 e DEC-1 (25/09) |
| L-01 | Nathan, PCP, Comercial | F1 |
| L-05 | Nathan e diretoria | DEC-11 (13/11), mas registrar o horizonte já |
| L-04 | Nathan e Compras | E2 (19/10) |
| L-02, L-03 | Nathan, Fiscal, Almoxarifado | G1 (13/10) |
| L-10, L-11 | Nathan, Robert, Pablo | D5/D6 (08/10) |
| L-15 | Nathan | 09/10 |

## Ver também
- [[Revisao-dos-Estados-e-Status]]
- [[Perguntas-em-Aberto-Consolidadas]]
- [[Campos-e-API-para-Rastreabilidade]]
- [[Cronograma-2-Meses]]
- [[Onde-Estamos]]
