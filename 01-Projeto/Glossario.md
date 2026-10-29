---
tags: [projeto, glossario, termos]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [v1 06-Glossario/Glossario, 00-Fluxo-Mestre-0b, Regras-do-Vault, api-pcp 579a625, api-acos-vital f322dcd, app-pcp 1fca8d3, HUB b55ac55, Cronograma]
---

# Glossário

**Em uma frase:** explica, em uma frase cada, os termos e as siglas que aparecem no projeto.

**Quando consultar esta nota:** sempre que você topar com uma palavra, sigla ou nome de tela que não conhece.

Os termos estão em ordem alfabética. Os nomes de tela seguem a regra de [[Regras-do-Vault]]: o nome novo primeiro e, entre parênteses, o antigo que o código ainda usa. Os IDs de nó (`V1`, `E3`…) são os do [[00-Fluxo-Mestre-0b]]. Os termos muito técnicos têm o detalhe em "Detalhe técnico", no fim.

## Telas e nomes que mudaram

| Nome atual | Antigo (ainda no código) | Rota | O que é |
|---|---|---|---|
| **Triagem do Pedido** (rótulo "Triagem dos Pedidos") | Carteira, Carteira de Pedidos | `/carteira` | Tela do PCP, no MES, que lista os pedidos liberados pelo vendedor (nó `P1`) ✅ |
| **Destinação do Pedido** | Nova Ordem de Produção, Emissão de Ordens | `/ordens-producao/novo` | Abre ao clicar num pedido da Triagem. O PCP define o destino e a quantidade de cada item, por rodada. O Estoque entra como etapa 1. A tela confirma a importação ao av-hub (nó `P2`) ✅ |
| **Acompanhamento dos Pedidos** | Lista de Ordens de Produção | `/ordens-producao` | Lista os pedidos já destinados ✅ |
| **Recebimento** | Logística de Entrada | `/logistica/logistica-entrada` | Fila do setor de entrada. Mostra os esperados, a chegada com NF e a conferência (nós `R0` a `R6`) ✅ |
| **Compras · CCP** | Setor Compras do MES, "registrar compra" | `/compras/pedidos-compra` | Tela só de leitura. Espelha os marcos do av-hub (contrato 35) ✅ |
| **Inspeção de entrada** | Qualidade · Entrada | `/qualidade/inspecao-entrada` | Inspeção do lote comprado (nós `Q1` a `Q4`) ✅ |
| **Inspeção de saída** | Setor `QUALIDADE` do roteiro | `/qualidade/inspecao-saida` | Inspeção do item fabricado (nós `Q7`, `Q8`) ✅ |
| **Decisões do PCP** | Divergências de Recebimento | `/decisoes-pcp` | O PCP aceita ou reabre o recebimento que continuou divergindo (nó `R6`) ✅ |
| **Etapa dos itens** | Status por item | cartão no HUB | O vendedor vê em que etapa está cada item (contratos 005 e 006) ✅ |

## Termos

- **0b, Fluxo mestre** — o diagrama que acompanha um pedido de 0 a 100%, da proposta (ou do pedido digitado no Omie) à nota fiscal e à comissão. É a referência dos IDs de nó. Ver [[00-Fluxo-Mestre-0b]].
- **Acompanhamento de Clientes** — tela do HUB que mostra compra, faturamento e inatividade por cliente e por grupo de empresa. Fica fora do fluxo 0b: [[Acompanhamento-Clientes]].
- **Atendimento (do Estoque)** — a ação "Atender pelo estoque": divide a parcial e reserva lotes sobre o saldo (nó `E3`) ✅.
- **BFF** — Backend For Frontend: camada que só repassa e organiza as chamadas, sem acessar banco. O HUB e o `app-pcp` têm um cada. Ver [[Mapa-Rotas-BFF-Bearer]].
- **Bearer** — o token do usuário, emitido pela `api-acos-vital`. Com ele a API confere a permissão da rota. Sem ele, a chamada é de serviço (só `x-api-key`). Ver [[Chaves-e-Autenticacao]].
- **Carga inicial** — lote criado direto como `LIBERADO`, que marca o ponto de partida do saldo ✅.
- **Casamento av-hub e MES** — o modo como o pedido ou a requisição de um sistema encontra o do outro. Foi decidido por REST com consulta periódica (DEC-2); a requisição de compra evoluiu para o PUT do MES (contrato 34). Ver [[Integracao-AvHub-MES]].
- **CCP** — equipe do PCP que acompanha o prazo de entrega do fornecedor (nó `C5`). Registra a nova data com o motivo e vincula a NF de entrada à OC (N16-86, N16-88). No HUB é o Follow-up; no MES, a tela Compras · CCP, só de leitura.
- **Chegada** — o registro da doca de que a mercadoria chegou com a NF. A parcial sai de Compras · CCP e vai ao Recebimento ✅.
- **Ciclo 1 e Ciclo 2** — o Ciclo 1 fecha em 18/02/2027 (era 21/01; deslocado pelo N14-30 e abatido pelo K4, N14-32). O Ciclo 2 começa em 19/02/2027 e leva transferência entre filiais (etapas 2 a 4), `GET /itens/custo`, sobras e perdas, entre outros 📝. Ver [[Cronograma]].
- **CIF e FOB** — quem paga e contrata o frete da compra. No CIF, o fornecedor entrega direto. No FOB, a Aços Vital coleta no fornecedor. A escolha é feita na emissão da OC (nó `C4`) ✅.
- **Circuito de compra** — o caminho fixo, fora do roteiro do PCP: Estoque, Requisições, Compras, Recebimento, Qualidade de entrada e volta ao mesmo Estoque. Ver [[04-Circuito-de-Compra]].
- **Compras · CCP** — ver a tabela de telas.
- **Conferência** — contagem, peso e divergência na doca, feitas contra a NF e não contra a OC. Ver [[05-Recebimento]].
- **Custo do lote** — o custo de cada lote do Estoque, sempre opcional e nunca bloqueante. Hoje só a carga inicial o grava 🔴. Ver [[Modelo-Estoque-e-Custo-do-Lote]].
- **Custo médio do item** — soma de quantidade vezes custo unitário dos lotes usados, dividida pela quantidade do item (regra A, decidida em 09/10) 📝. O `GET /itens/custo` ainda não existe no MES 🔴.
- **Destino (de uma fábrica)** — diz se a fábrica é de produção própria (`FABRICACAO`) ou de revenda (`REVENDA`). Na tela, o nome é "Destino" ✅.
- **Despacho (do Estoque)** — a saída da mercadoria do Estoque (nó `E6`). Decidido em 14/10: quem precisa da mercadoria (Expedição ou Produção) gera um **documento de retirada**, e o saldo baixa na retirada 📝. Hoje o código baixa quando a Embalagem ou a Expedição recebe a parcial 🔴.
- **Diligenciador** — pessoa do PCP que acompanha os pedidos de um grupo de vendedores. Não é um perfil de permissão (RBAC).
- **Divergência** — tem dois sentidos: a do **Recebimento** (quantidade, descrição, peso ou avaria) e a da **produção** (qualidade, quantidade, prazo, dano, documentação ou outro) ✅.
- **Documento de retirada** — ver Despacho.
- **EL (não ETL)** — a filosofia da pipeline: só extrai e carrega. A regra de negócio fica nas views e funções do banco. Ver [[Pipeline-Omie]].
- **Entrega** — o evento de entrega ao cliente. Não se confunde com `ItemParcial`.
- **Esperados** — a lista do Recebimento com as requisições de OC aprovada (ou liberadas manualmente) (nó `R0`) ✅.
- **Etapa (do item)** — um dos 11 valores do contrato 005, como `fabrica.espera` e `qualidade.inspecao`. Ver [[Estados-e-Status]].
- **Evento (marco)** — o registro do av-hub que o MES lê no contrato 35. Exemplos: `requisicao_recebida`, `oc_aprovada` e `despachada`. Ver [[Integracao-AvHub-MES]].
- **Fábrica (tipo)** — ver Destino.
- **Fabricado** — item produzido em linha própria. Pela decisão, volta ao Estoque como lote e saldo 📝. Hoje não vira lote 🔴.
- **Grupo de dedução** — a classe que tira uma venda do total líquido: G1 Cancelado, G2 Devolvido, G2P Devolvido Parcial, G3 Recusado ou Denegado, G4 blacklist de destinatário, G5 blacklist de vendedor, G6 Refaturamento. O que sobra é LÍQUIDO ([[Dashboards]]).
- **HUB** — o front do av-hub (Next.js). O BFF e o repositório do `api-comercial` ficam junto dele.
- **Ida e volta (da requisição)** — na ida, o MES empurra a requisição ao hub (contrato 34, `PUT`). Na volta, o MES lê os marcos do hub (contrato 35, por consulta periódica e sob demanda).
- **`id_origem`** — o id do `RequisicaoCompraItem` do MES, chave do PUT e dos eventos. A requisição criada só no hub não tem `id_origem` e não chega ao MES. O MES lê a OC dela pela referência (N14-20), mas ainda não lê 🔴.
- **Inspeção de entrada e de saída** — ver a tabela de telas.
- **`ItemParcial`** — uma fração de um item percorrendo o roteiro ✅ ([[Estados]]).
- **Lote** — a unidade de saldo, com origem e status de qualidade. O lote recebido nasce `PENDENTE` (quarentena). Quando é cisão, aponta para o lote de origem.
- **Liberação (do pedido)** — o vendedor marca se a Qualidade acompanha e libera, numa ação só. Só pedido liberado vai ao MES ([[01-Vendas-Liberacao]]).
- **MES** — o sistema de execução da produção. Tem o `api-pcp` (back, NestJS e Prisma) e o `app-pcp` (front, Next.js). Dono: Robert.
- **Movimento de estoque** — a entrada, a saída, a transferência ou o ajuste de saldo ✅.
- **OC (Ordem de Compra)** — nasce no HUB (nó `C4`) e é enviada ao Omie pela pipeline. Se **exceder R$ 30 mil**, o Gerente de Compras aprova. Se for **até** R$ 30 mil, sai sem aprovação, com os compradores livres ✅ 📝 N14-21. A regra é provisória e endurece depois com Compras 🟡.
- **OP (Ordem de Produção)** — uma **entidade** do sistema e também um **documento para impressão** (formalidade), emitido só para o que será fabricado 📝 N14-22, #74. Ainda não existe 🔴 (BL-052). O termo antigo designava a Destinação do Pedido e hoje é só o texto do pedido no código.
- **Saldo futuro** — o que o Estoque ainda vai receber das **OCs em andamento** de itens de estoque (sem pedido de venda). O Estoque do MES mostra **saldo atual + saldo futuro** 📝 N14-20. A OC ligada a pedido de venda não entra: o PCP a vê no pedido. O MES ainda não lê essa informação 🔴 (BL-050).
- **OS (Ordem de Serviço)** — o beneficiamento ou retrabalho de item de Revenda, como o corte de chapa. O setor `PRODUTIVO` é opcional no roteiro da Revenda.
- **Parcial** — tem três sentidos que não se misturam: (1) o `sequencial` do Omie, uma linha de pedido por nota fiscal parcial (o 0 é o guarda-chuva); (2) o `ItemParcial` do MES; (3) a `Entrega`, entrega parcial ao cliente. Exemplo: o pedido 27645 tem sequenciais 0 a 4, e a soma bate com os 10 itens ([[LOG-08-Itens-por-Parcela-Pedidos]]).
- **PCP** — planejamento e controle da produção. É o mesmo departamento nos dois sistemas: o Portal PCP do HUB e o MES. Não é ambiguidade a corrigir.
- **`PerfilSetor`** — a ligação entre perfil e setor no MES (visualizar, atuar). É conveniência de tela, não barreira de segurança.
- **Pipeline** — o `omie-elt-pipeline`: extrai dados do Omie para o banco do av-hub e envia a OC. Essa é a única escrita no Omie.
- **PTAX** — a cotação do dólar do Banco Central, usada na cotação por item da OC em moeda estrangeira.
- **Quarentena** — o estado do lote visível e indisponível até a Qualidade aprovar. `QUARENTENA` também é o status da parte aprovada de uma reprovação parcial (EC-07).
- **Reserva** — o vínculo de uma quantidade de lote a um `ItemParcial`. Não expira ✅.
- **Recontagem** — a nova contagem do Recebimento, feita por **outra pessoa**. Se ainda diverge, vai à Decisão do PCP (`ACEITO` ou `REABERTO`).
- **Requisição de compra** — o pedido de material ao Compras. Tem **duas origens** 📝: (1) o PCP, no MES, para o material do pedido (nó `P3`); (2) o Compras, no HUB, para necessidade própria (nó `C0`, "Nova requisição", permissão `compras.pode_criar`). No hub cada requisição tem um material.
- **Refaturamento** — a reemissão de nota para o mesmo pedido. Pode ser `Permitido`, `Proibido` ou `Sem Referência`.
- **RNC** — Relatório de Não Conformidade, aberto quando a Qualidade reprova um lote.
- **Roteiro** — a sequência de setores de um item. Tem dois níveis: `Roteiros` (do pedido) e `RoteiroItem` (do item). O setor Estoque é sempre a etapa 1, inserido pelo backend.
- **Setor (tipo)** — a classe do setor no MES: `PRODUTIVO`, `ESTOQUE`, `COMPRAS`, `EXPEDICAO`, `REQUISICAO`, `LOGISTICA_ENTRADA` ou `QUALIDADE` ✅.
- **Split atendido** — a parte do `ItemParcial` que o Estoque cobriu com saldo. Vira parcial própria, com reserva, e segue em trânsito para a Expedição.
- **SLA por etapa** — a meta de tempo de cada etapa do fluxo. É proposta, com metas por definir. Ver [[Rastreabilidade-e-Torre-de-Fluxo]].
- **Selos** — ✅ no código, 📝 decidido, 🟡 proposta, 🔴 aberto ou sem código, ❓ não conferido em produção ([[Regras-do-Vault]]).
- **Torre de Fluxo** — a visualização do 0b: mapa por setor, contagem por etapa, tempo contra o SLA e trilha do item. O hub tem feed, rotina e rotas. O MES não publica `/fluxo/eventos` e o HUB não tem a tela 🔴.
- **Triagem do Pedido** — ver a tabela de telas.
- **Prefixos nas notas** — **DEC** decisão-chave; **EC** pergunta do encaixe do Estoque e da Revenda; **EN** decisão do encaixe; **IM** pergunta da integração; **CC** ponto da conferência de código; **T** tela do mapa de telas; **L-nn** lacuna de lógica; **CA** pergunta de Compras e acessos; **R** pergunta de rastreabilidade; **BL**, **PS**, **RS** itens do [[Backlog-por-Frente]], de [[Pontas-Soltas]] e de [[Riscos]].
- **L6** — a chave própria do MES para escrever no av-hub, restrita por rota. Hoje a chave do contrato 34 só abre o PUT, e as leituras usam outra 🔴 ([[Chaves-e-Autenticacao]]).
- **`vendas_base` e `nf_classified`** — views (consultas prontas do banco) que entregam o grupo de dedução pronto por nota e por pedido ([[Dashboards]]).
- **Waterfall de dedução** — a cascata que reconcilia a Venda Bruta e a Venda Líquida.

## Proposta, Orçamento, custo real e comissão nova (desenho aprovado em 26/10/2026)

- **Proposta** — o documento do vendedor no Hub, antes do pedido (nós `V0.1` a `V0.7`). Só a aprovada vira pedido, e uma proposta vira um pedido só (N16-02). Estados: `ABERTA`, `APROVADA`, `TRANSFORMADA`, `CANCELADA`. Ver [[11-Proposta-e-Pedido-de-Venda]].
- **Proposta incompleta** — a que tem item sem custo e sem fornecedor. Não é um estado, é um campo calculado. Ela impede a aprovação (N16-03, N16-31).
- **Transformar em pedido** — o botão da proposta aprovada (`V0.6`). Pede a previsão de faturamento, se a Qualidade acompanha e se o pedido pode faturar em partes. Depois o Hub cria o pedido no Omie, por fila e pipeline (`V0.7`).
- **Pedido do Hub** — o pedido de venda em `core_comercial.pedidos`, com origem `PROPOSTA` ou `OMIE`. Os dois seguem o mesmo fluxo e a mesma tela. O do Omie chega com a parte de vendas pronta, que só se altera no Omie (N16-106).
- **Parte de vendas e parte de compras** — as duas metades do item da proposta ou do pedido. A de vendas tem cliente, itens, valores, impostos e previsão. A de compras tem custo, fornecedor, origem e frete: o vendedor a preenche, e ela é a simulação da comissão (N16-104, N16-106).
- **Orçamento (setor)** — o setor novo que cota com fornecedores e mantém a base de preço de compra, sempre com histórico (`B1` a `B4`). O Moisés é uma das pessoas (N16-104). Ver [[12-Orcamento-Base-de-Preco]].
- **Orçamentista** — o perfil de quem atende o pedido de custo no setor de Orçamento (N16-59).
- **Pedido de custo** — o pedido do vendedor ao Orçamento para cotar um item de que ele não tem o dado (`B3`). Não tem prazo fixo, e o tempo é cronometrado. O vendedor nunca fica bloqueado (N16-58).
- **Página do produto** — a consulta do vendedor (`B2`) com histórico de preço, top fornecedores com score, flutuação, volatilidade e média. É só de leitura.
- **Compra acima do valor** — o caso em que Compras comprou por mais que o custo que o vendedor pôs (`C8`). O vendedor é avisado em Meus Pedidos e aprova ou reprova, por produto e sem tolerância (N16-60 a N16-67). Fica na tabela `divergencias_compra`.
- **Previsão vigente** — a data de faturamento que vale agora: a maior entre a inicial e a última de cada item, mais 1 dia útil pelo calendário da unidade. Fica só no Hub; o Omie guarda a inicial (N16-88, N16-96, N16-97).
- **Sequencial** — o agrupamento que o Fiscal cria para faturar o mesmo pedido em várias notas, por item e quantidade. Não é outro pedido nem parcela de pagamento (N16-92 a N16-94).
- **Custo real (por evento)** — o custo do item do pedido, somado das linhas de cada evento: OC (com o valor da NF de entrada no recebimento), lote do Estoque ou matéria-prima do fabricado (`K2`, N16-09, N16-40). Ver [[13-Custo-Real-e-Comissao-no-Fluxo]].
- **Comissão estimada e comissão real** — a estimada nasce na proposta ou na parte de compras do pedido do Omie (`K1`) e é a única que o vendedor vê antes da decisão. A real fecha por nota fiscal, com o custo real (`K3`), e só aparece ao vendedor depois da decisão (`K5`).
- **Apuração seguinte** — quando o custo completa depois da decisão, a diferença (complemento ou desconto) vai para a próxima apuração, para nova decisão (N16-49).
- **Abatimento** — a redução da comissão na mesma proporção da nota cancelada, devolvida ou recusada (`K6`, N16-47).
- **`core_comissao`** — o schema novo da comissão, em Operações. O `core_comissionamento` atual não muda (N16-11).

## Detalhe técnico

Rotas, colunas, enums e referências de código que ficaram de fora das definições acima.

- **Atendimento (do Estoque):** tela `/estoque-operacao/atendimento`; rota `PATCH /itens-parciais/:id/atender-estoque` ✅.
- **Carga inicial:** `OrigemLote.CARGA_INICIAL`; rota `POST /estoque/lotes/carga-inicial` ✅.
- **Chegada:** `POST /compras/requisicoes/:id/chegada` exige o número ou a chave da NF ✅ `compras.service.ts:356`.
- **Conferência:** peso real obrigatório se o material tem peso teórico; tolerância de 5% (`toleranciaPeso` 0,05) ✅.
- **Custo do lote:** tabela `lote_custo`, 1:1 com `lotes`; origens `CARGA_INICIAL`, `OC`, `MANUAL`.
- **Destino (de uma fábrica):** campo `Fabrica.tipo` (`fabricas.prisma:5-8`).
- **Despacho:** hoje o código baixa o saldo em `consumirReservasDaParcial`.
- **Diligenciador:** vínculo na tabela `diligenciador_vendedor`.
- **Divergência:** a do Recebimento usa `QUANTIDADE`, `DESCRICAO`, `PESO`, `AVARIA`; a da produção (`Divergencia`) usa `QUALIDADE`, `QUANTIDADE`, `PRAZO`, `DANO`, `DOCUMENTACAO`, `OUTRO`.
- **Entrega:** tabela `entregas`.
- **Esperados:** `GET /compras/requisicoes/esperados` ✅.
- **Fabricado:** `OrigemLote` só tem `RECEBIMENTO` e `CARGA_INICIAL`.
- **`ItemParcial`:** status `CRIADO`, `RECEBIDO`, `EM_ANDAMENTO`, `EM_TRANSITO`, `PAUSADO`, `REPROVADO`, `CONCLUIDO`, `CANCELADO`, mais `RETRABALHO` por legado.
- **Lote:** origem, status de qualidade e `idLotePai` (quando é cisão).
- **Movimento de estoque:** tipos `ENTRADA`, `SAIDA`, `TRANSFERENCIA`, `AJUSTE`.
- **OC:** status `rascunho`, `aguardando_aprovacao`, `aprovado`, `cancelado` ✅.
- **OP:** o termo antigo é o campo `ordemProducao` e os códigos `OP-`.
- **Saldo futuro:** a fonte é a referência da OC do hub, com `destino` `estoque`.
- **OS:** setor `PRODUTIVO` opcional no roteiro da Revenda.
- **Reserva:** status `ATIVA`, `CONSUMIDA`, `LIBERADA`, sem expiração ✅.
- **Requisição de compra:** status no hub `aberta`, `em_cotacao`, `atendida`, `cancelada`.
- **RNC:** tabela `rncs`, campo `nota_devolucao_pendente`.
- **Setor (tipo):** `fabricas.prisma:17-30`.
