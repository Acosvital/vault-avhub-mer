---
tags: [projeto, glossario, termos]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [v1 06-Glossario/Glossario, 00-Fluxo-Mestre-0b, Regras-do-Vault, api-pcp 579a625, api-acos-vital f322dcd, app-pcp 1fca8d3, HUB b55ac55, Cronograma]
---

# Glossário

Termos do projeto em ordem alfabética, com o nome atual primeiro. Nomes de telas seguem a regra de [[Regras-do-Vault]]: o nome novo e, entre parênteses, o antigo que o código ainda usa. Os IDs de nó (`V1`, `E3`…) são os do [[00-Fluxo-Mestre-0b]].

## Telas e nomes que mudaram

| Nome atual | Antigo (ainda no código) | Rota | O que é |
|---|---|---|---|
| **Triagem do Pedido** (rótulo "Triagem dos Pedidos") | Carteira, Carteira de Pedidos | `/carteira` | Tela do PCP no MES que lista os pedidos liberados pelo vendedor (nó `P1`) ✅ |
| **Destinação do Pedido** | Nova Ordem de Produção, Emissão de Ordens | `/ordens-producao/novo` | Abre ao clicar num pedido da Triagem. O PCP define, por item e por rodada, o destino e a quantidade; o Estoque entra como etapa 1; confirma a importação ao av-hub (nó `P2`) ✅ |
| **Acompanhamento dos Pedidos** | Lista de Ordens de Produção | `/ordens-producao` | Lista dos pedidos já destinados ✅ |
| **Recebimento** | Logística de Entrada | `/logistica/logistica-entrada` | Fila do setor tipo `LOGISTICA_ENTRADA`: esperados, chegada com NF e conferência (nós `R0` a `R6`) ✅ |
| **Compras · CCP** | Setor Compras do MES, "registrar compra" | `/compras/pedidos-compra` | Tela só de leitura que espelha os marcos do av-hub (contrato 35) ✅ |
| **Inspeção de entrada** | Qualidade · Entrada | `/qualidade/inspecao-entrada` | Inspeção do lote comprado (nós `Q1` a `Q4`) ✅ |
| **Inspeção de saída** | Setor `QUALIDADE` do roteiro | `/qualidade/inspecao-saida` | Inspeção do fabricado (nós `Q7`, `Q8`) ✅ |
| **Decisões do PCP** | Divergências de Recebimento | `/decisoes-pcp` | O PCP aceita ou reabre o recebimento que continuou divergindo (nó `R6`) ✅ |
| **Etapa dos itens** | Status por item | cartão no HUB | O vendedor vê em que etapa está cada item (contratos 005 e 006) ✅ |

## Termos

- **0b, Fluxo mestre** — o diagrama que acompanha um pedido de 0 a 100%, do Omie à nota fiscal. É a referência dos IDs de nó. Ver [[00-Fluxo-Mestre-0b]].
- **Acompanhamento de Clientes** — tela do HUB que mostra, por cliente e por grupo de empresa, compra, faturamento e inatividade. Fora do fluxo 0b: [[Acompanhamento-Clientes]].
- **Atendimento (do Estoque)** — ação de "Atender pelo estoque": split da parcial e reserva de lotes sobre o saldo (nó `E3`). Tela `/estoque-operacao/atendimento`. Rota `PATCH /itens-parciais/:id/atender-estoque` ✅.
- **BFF** — Backend For Frontend: camada que só faz proxy e orquestração, sem banco. O HUB tem um (`app/api/**/route.ts`) e o `app-pcp` também. Ver [[Mapa-Rotas-BFF-Bearer]].
- **Bearer** — token do usuário (`Authorization: Bearer`) emitido pela `api-acos-vital`; com ele a API confere a permissão por rota. Sem ele a chamada é de serviço (só `x-api-key`). Ver [[Chaves-e-Autenticacao]].
- **Carga inicial** — lote criado direto como `LIBERADO` (`OrigemLote.CARGA_INICIAL`), marco zero do saldo. `POST /estoque/lotes/carga-inicial` ✅.
- **Casamento av-hub e MES** — como o pedido ou a requisição de um sistema encontra o do outro. Decidido por REST com polling (DEC-2); a requisição de compra evoluiu para o PUT do MES (contrato 34). Ver [[Integracao-AvHub-MES]].
- **CCP** — acompanhamento de prazo de entrega do fornecedor (nó `C5`). No HUB é o Follow-up; no MES, a tela Compras · CCP, só leitura.
- **Chegada** — registro da doca de que a mercadoria chegou com a NF. A parcial sai de Compras · CCP e vai ao Recebimento. `POST /compras/requisicoes/:id/chegada` exige o número ou a chave da NF ✅ `compras.service.ts:356`.
- **Ciclo 1 e Ciclo 2** — Ciclo 1 fecha em 24/02/2027 (era 21/01; deslocado pelo N14-30); Ciclo 2 começa em 25/02/2027 e leva transferência entre filiais (etapas 2 a 4), `GET /itens/custo`, sobras e perdas, entre outros 📝. Ver [[Cronograma]].
- **CIF e FOB** — quem paga e contrata o frete da compra. CIF: o fornecedor entrega direto. FOB: coleta no fornecedor. Definido na emissão da OC (nó `C4`) ✅.
- **Circuito de compra** — caminho fixo, fora do roteiro do PCP: Estoque, Requisições, Compras, Recebimento, Qualidade de entrada e de volta ao mesmo Estoque. Ver [[04-Circuito-de-Compra]].
- **Compras · CCP** — ver tabela de telas.
- **Conferência** — contagem, peso e divergência na doca, contra a NF (não contra a OC). Peso real obrigatório se o material tem peso teórico; tolerância 5% (`toleranciaPeso` 0,05) ✅ ([[05-Recebimento]]).
- **Custo do lote** — `lote_custo`, 1:1 com `lotes`, opcional e nunca bloqueante. Origens `CARGA_INICIAL`, `OC`, `MANUAL`. Só a carga inicial grava hoje 🔴 ([[Modelo-Estoque-e-Custo-do-Lote]]).
- **Custo médio do item** — soma de quantidade vezes custo unitário dos lotes usados, dividida pela quantidade do item (regra A, decidida em 09/10) 📝. O `GET /itens/custo` ainda não existe no MES 🔴.
- **Destino (de uma fábrica)** — `Fabrica.tipo`: `FABRICACAO` (linha própria) ou `REVENDA`. Na tela, o nome é "Destino" ✅ (`fabricas.prisma:5-8`).
- **Despacho (do Estoque)** — nó `E6`. Decidido em 14/10: quem precisa da mercadoria (Expedição ou Produção) gera um **documento de retirada** e a baixa do saldo acontece na retirada 📝. Hoje o código baixa quando a Embalagem ou a Expedição recebe a parcial (`consumirReservasDaParcial`) 🔴.
- **Diligenciador** — pessoa do PCP que acompanha os pedidos de um grupo de vendedores; vínculo em `diligenciador_vendedor`. Não é perfil RBAC.
- **Divergência** — duas coisas: do **Recebimento** (`QUANTIDADE`, `DESCRICAO`, `PESO`, `AVARIA`) e da **produção** (`Divergencia`: `QUALIDADE`, `QUANTIDADE`, `PRAZO`, `DANO`, `DOCUMENTACAO`, `OUTRO`) ✅.
- **Documento de retirada** — ver Despacho.
- **EL (não ETL)** — filosofia da pipeline: extrai e carrega; a regra de negócio fica nas views e funções do banco. Ver [[Pipeline-Omie]].
- **Entrega** — evento de entrega ao cliente (tabela `entregas`); não confundir com `ItemParcial`.
- **Esperados** — lista do Recebimento com as requisições de OC aprovada (ou liberadas manualmente). `GET /compras/requisicoes/esperados` ✅ (nó `R0`).
- **Etapa (do item)** — um dos 11 valores do contrato 005 (`fabrica.espera`, `qualidade.inspecao`…). Ver [[Estados-e-Status]].
- **Evento (marco)** — registro do av-hub (`requisicoes_compra_eventos`) que o MES lê no contrato 35: `requisicao_recebida`, `oc_aprovada`, `despachada` etc. Ver [[Integracao-AvHub-MES]].
- **Fábrica (tipo)** — ver Destino.
- **Fabricado** — item produzido em linha própria. Pela decisão, volta ao Estoque como lote e saldo 📝; hoje não vira lote (`OrigemLote` só tem `RECEBIMENTO` e `CARGA_INICIAL`) 🔴.
- **Grupo de dedução** — G1 Cancelado, G2 Devolvido, G2P Devolvido Parcial, G3 Recusado ou Denegado, G4 blacklist de destinatário, G5 blacklist de vendedor, G6 Refaturamento, LÍQUIDO o resto. Cascata da venda líquida ([[Dashboards]]).
- **HUB** — front do av-hub (Next.js). O BFF e o repositório do `api-comercial` ficam junto dele.
- **Ida e volta (da requisição)** — ida: o MES empurra a requisição ao hub (contrato 34, `PUT`). Volta: o MES lê os marcos do hub (contrato 35, polling e sob demanda).
- **`id_origem`** — id do `RequisicaoCompraItem` do MES, chave do PUT e dos eventos. Requisição criada só no hub não tem `id_origem` e não chega ao MES; o MES lê a OC dela pela referência (N14-20, 🔴 ainda não lê).
- **Inspeção de entrada e de saída** — ver tabela de telas.
- **`ItemParcial`** — fração de um item percorrendo o roteiro. Status: `CRIADO`, `RECEBIDO`, `EM_ANDAMENTO`, `EM_TRANSITO`, `PAUSADO`, `REPROVADO`, `CONCLUIDO`, `CANCELADO`, mais `RETRABALHO` por legado ✅ ([[Estados]]).
- **Lote** — unidade de saldo, com origem, status de qualidade e, quando é cisão, `idLotePai`. Lote recebido nasce `PENDENTE` (quarentena).
- **Liberação (do pedido)** — o vendedor marca se a Qualidade acompanha e libera numa ação só. Só pedido liberado vai ao MES ([[01-Vendas-Liberacao]]).
- **MES** — o sistema de execução da produção: `api-pcp` (back, NestJS e Prisma) e `app-pcp` (front, Next.js). Dono: Robert.
- **Movimento de estoque** — `ENTRADA`, `SAIDA`, `TRANSFERENCIA` ou `AJUSTE` ✅.
- **OC (Ordem de Compra)** — nasce no HUB (nó `C4`), é aprovada pelo Gerente de Compras se **exceder R$ 30 mil**, e liberada sem aprovação (compradores livres) se for **até** R$ 30 mil ✅ 📝 N14-21 (regra provisória, endurece depois com Compras 🟡), e enviada ao Omie pela pipeline. Status `rascunho`, `aguardando_aprovacao`, `aprovado`, `cancelado` ✅.
- **OP (Ordem de Produção)** — **entidade** do sistema e também **documento para impressão** (formalidade), emitido só para o que será fabricado 📝 N14-22, #74. Ainda não existe 🔴 (BL-052). O termo antigo (campo `ordemProducao`, códigos `OP-`) designava a Destinação do Pedido e hoje é só o texto do pedido no código.
- **Saldo futuro** — o que o Estoque ainda vai receber das **OCs em andamento** de itens de estoque (sem pedido de venda): a parte da OC que preenche o estoque. O Estoque do MES mostra **saldo atual + saldo futuro** 📝 N14-20. A OC vinculada a pedido de venda não entra: o PCP a vê no pedido. Fonte: referência da OC do hub (`destino` `estoque`); 🔴 o MES ainda não lê (BL-050).
- **OS (Ordem de Serviço)** — beneficiamento ou retrabalho de item de Revenda (por exemplo, corte de chapa); setor `PRODUTIVO` opcional no roteiro da Revenda.
- **Parcial** — três sentidos que não se misturam: (1) `sequencial` do Omie, uma linha de pedido por nota fiscal parcial (0 é o guarda-chuva); (2) `ItemParcial` do MES; (3) `Entrega`, entrega parcial ao cliente. Exemplo: pedido 27645, sequenciais 0 a 4, soma igual aos 10 itens ([[LOG-08-Itens-por-Parcela-Pedidos]]).
- **PCP** — o mesmo departamento nos dois sistemas: o Portal PCP do HUB e o MES. Não é ambiguidade a corrigir.
- **`PerfilSetor`** — junção perfil e setor no MES (visualizar, atuar). Conveniência de UI, não fronteira de segurança.
- **Pipeline** — `omie-elt-pipeline`: extrai do Omie para o banco do av-hub e envia a OC (única escrita no Omie).
- **PTAX** — cotação do dólar do Banco Central, usada na cotação por item da OC em moeda estrangeira.
- **Quarentena** — lote visível e indisponível até a aprovação da Qualidade. `QUARENTENA` também é o status da parte aprovada de uma reprovação parcial (EC-07).
- **Reserva** — vínculo de uma quantidade de lote a um `ItemParcial`. `ATIVA`, `CONSUMIDA`, `LIBERADA`, sem expiração ✅.
- **Recontagem** — nova contagem do Recebimento por **outra pessoa**; se ainda diverge, vai à Decisão do PCP (`ACEITO` ou `REABERTO`).
- **Requisição de compra** — pedido de material ao Compras. **Duas origens** 📝: (1) PCP, no MES, material do pedido (nó `P3`); (2) Compras, no HUB, necessidade própria (nó `C0`, "Nova requisição", permissão `compras.pode_criar`). No hub cada requisição tem um material; status `aberta`, `em_cotacao`, `atendida`, `cancelada`.
- **Refaturamento** — reemissão de nota para o mesmo pedido: `Permitido`, `Proibido`, `Sem Referência`.
- **RNC** — Relatório de Não Conformidade, aberto quando a Qualidade reprova um lote (`rncs`, `nota_devolucao_pendente`).
- **Roteiro** — sequência de setores de um item. Em dois níveis: `Roteiros` (pedido) e `RoteiroItem` (item). O setor Estoque é sempre a etapa 1, inserido pelo backend.
- **Setor (tipo)** — `PRODUTIVO`, `ESTOQUE`, `COMPRAS`, `EXPEDICAO`, `REQUISICAO`, `LOGISTICA_ENTRADA`, `QUALIDADE` ✅ (`fabricas.prisma:17-30`).
- **Split atendido** — parte do `ItemParcial` que o Estoque cobriu com saldo; vira parcial própria, com reserva, e segue em trânsito para a Expedição.
- **SLA por etapa** — meta de tempo por etapa do fluxo (proposta, metas por definir). Ver [[Rastreabilidade-e-Torre-de-Fluxo]].
- **Selos** — ✅ no código, 📝 decidido, 🟡 proposta, 🔴 aberto ou sem código, ❓ não conferido em produção ([[Regras-do-Vault]]).
- **Torre de Fluxo** — visualização do 0b: mapa por setor, contagem por etapa, tempo contra SLA e trilha do item. O hub tem feed, job e rotas; o MES não publica `/fluxo/eventos` e o HUB não tem a tela 🔴.
- **Triagem do Pedido** — ver tabela de telas.
- **Prefixos nas notas** — **DEC** decisão-chave; **EC** pergunta do encaixe do Estoque e da Revenda; **EN** decisão do encaixe; **IM** pergunta da integração; **CC** ponto da conferência de código; **T** tela do mapa de telas; **L-nn** lacuna de lógica; **CA** pergunta de Compras e acessos; **R** pergunta de rastreabilidade; **BL**, **PS**, **RS** itens do [[Backlog-por-Frente]], de [[Pontas-Soltas]] e de [[Riscos]].
- **L6** — chave própria do MES para escrever no av-hub, restrita por rota. Hoje a chave do contrato 34 só abre o PUT; as leituras usam outra 🔴 ([[Chaves-e-Autenticacao]]).
- **`vendas_base` e `nf_classified`** — views curadas que entregam o grupo de dedução pronto por nota e pedido ([[Dashboards]]).
- **Waterfall de dedução** — cascata que reconcilia Venda Bruta e Venda Líquida.
