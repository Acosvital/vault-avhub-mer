---
tags: [erp-acos-vital, glossario]
criado: 2026-09-16
atualizado: 2026-10-07
---

# Glossário

- **BFF** — Backend For Frontend; camada que só faz proxy/orquestração para um backend real, sem acesso direto a banco. É o que o [[AV-Hub-Arquitetura-BFF|av-hub]] e o `app-pcp` são (backends reais: `api-acos-vital` e `api-pcp`).
- **Carteira (de Pedidos)** — tela do MES que lista os pedidos de venda do av-hub/Omie; dela o PCP abre a Ordem de Produção e escolhe, por rodada, itens, quantidades e fábrica. Ver [[PCP-Carteira]].
- **Fábrica (tipo)** — `Fabrica.tipo` = `FABRICACAO` (linha de produção própria) ou `REVENDA` (a "fábrica" da revenda, com roteiro Estoque → Compras → Recebimento → [beneficiamento] → Qualidade → Estoque). A natureza do item é o tipo da fábrica escolhida na rodada. Ver [[Encaixe-Estoque-Revenda-no-PCP]].
- **CCP** — Follow-up/acompanhamento de prazos de entrega de fornecedor, dentro da [[Rota-Revenda]].
- **Custódia** — "com quem o item está agora": uma pessoa nomeada ou a fila de um setor (sem dono). Só muda por passagem explícita ou ao assumir. Ver [[Rastreabilidade-e-SLA-de-Eventos]].
- **Diligenciador** — pessoa do setor de PCP que acompanha os pedidos de um grupo de vendedores; o vínculo fica na tabela `diligenciador_vendedor`. **Não é um perfil RBAC** (é um vínculo de dados, não uma permissão). Ver [[Achado-Ambiguidade-PCP]].
- **EL (não ETL)** — filosofia do [[Omie-ELT-Pipeline|pipeline de integração Omie]]: só extrai e carrega, nunca aplica regra de negócio (isso fica 100% nas views/functions do banco).
- **Evento (log de eventos)** — registro imutável de um fato do pedido (quem fez, quando, de qual etapa para qual, quem autorizou, para quem passou). Estado atual, tempo e contagens são leituras derivadas dele. Ver [[Rastreabilidade-e-SLA-de-Eventos]].
- **Fila sem dono** — item que chegou a um setor e ainda não foi assumido por ninguém; o tempo parado assim é medido à parte do tempo de execução.
- **Grupo de dedução (G1-G2P-G6/LÍQUIDO)** — classificação mutuamente exclusiva de um pedido/nota na cascata de waterfall: G1 Cancelado, G2 Devolvido, G2P Devolvido Parcial, G3 Recusado/Denegado, G4 blacklist de destinatário, G5 blacklist de vendedor, G6 Refaturamento, LÍQUIDO = resto. Ver [[AV-Hub-Vendas-Reconciliacao]].
- **`ItemParcial`** — no backend do app-pcp, é o **estado de produção de um lote/fração de item** percorrendo o roteiro (9 estados no front de `develop`: CRIADO...CONCLUIDO/CANCELADO, com REPROVADO) — não é entrega parcial ao cliente (isso é a entidade `Entrega`, separada). Desde 24/09/2026 todo parcial nasce no setor Estoque; a parte atendida pelo saldo vira um split próprio. Ver [[App-PCP-Backend-Producao]].
- **`nf_classified`/`vendas_base`** — views curadas que já entregam o grupo de dedução pronto por nota/pedido. Ver [[AV-Hub-Vendas-Reconciliacao]].
- **OS (Ordem de Serviço)** — beneficiamento/retrabalho de um item de Revenda (ex.: corte de chapa) fora de uma linha de fabricação própria. Desde 24/09/2026 é um setor `PRODUTIVO` opcional no roteiro da fábrica Revenda. Ver [[Fluxo-Detalhado-Pedido-Item]].
- **OP (Ordem de Produção)** — gerada pela tela Ordem de Produção a partir da Carteira: uma por fábrica em cada rodada (inclusive a Revenda). Substituiu o antigo setor "Emissão de Ordens". Ver [[Fluxo-Detalhado-Pedido-Item]].
- **Parcial** — a palavra tem **três sentidos diferentes**, que não devem ser confundidos: (1) `sequencial` do Omie, uma linha de pedido criada a cada **nota fiscal parcial** (0 = guarda-chuva, 1/2/... = parciais); (2) [[App-PCP-Backend-Producao|`ItemParcial`]] do MES, uma **fração de lote em produção** percorrendo o roteiro; (3) `Entrega`, um evento de **entrega parcial ao cliente**. Um mesmo item pode ter os três ao mesmo tempo.
- **PCP** — mesmo nome usado em dois pontos de contato do mesmo setor: o "Portal PCP" do av-hub (diligenciadores, acompanhamento comercial) e o app-pcp/MES (produção de chão de fábrica). **Não é ambiguidade a corrigir** — é o mesmo departamento nos dois sistemas, deliberadamente sem renomear. Ver [[Achado-Ambiguidade-PCP]].
- **`PerfilSetor`** — RBAC paralelo (visualizar/atuar por perfil×setor) no app-pcp, usado só como conveniência de UI na tela de Movimentações — não é fronteira de segurança real.
- **Quarentena** — estado de um lote de material, visível no sistema mas indisponível para uso, até a aprovação da Qualidade.
- **Reserva** — vínculo de uma quantidade de um lote a um `ItemParcial` (o split atendido pelo estoque). Status `ATIVA`/`CONSUMIDA`/`LIBERADA`, sem expiração; nasce sempre no setor Estoque, sobre lote liberado. Ver [[Encaixe-Estoque-Revenda-no-PCP]].
- **Refaturamento** — reemissão de nota fiscal para o mesmo pedido; `Permitido`/`Proibido`/`Sem Referência`. Semântica de dedução (G6) difere entre vendas (sempre deduz) e faturamento (só deduz se não-Permitido).
- **RNC** — Relatório de Não Conformidade, aberto quando a Qualidade reprova um lote.
- **Roteiro** — sequência ordenada de setores pelos quais um item de produção passa. Desde 24/09/2026 o setor Estoque é sempre a etapa 1, inserida pelo backend. Ver [[App-PCP-Modelo-Producao]].
- **Setor (tipo)** — `Setor.tipo` = `PRODUTIVO` (padrão: receber, iniciar, mover), `ESTOQUE` (atende do saldo, reserva, dá entrada do comprado) ou `COMPRAS` (gera a requisição e espera o recebimento). Ver [[Encaixe-Estoque-Revenda-no-PCP]].
- **Split atendido** — parte de um `ItemParcial` que o setor Estoque cobriu com saldo: vira um parcial próprio, com reserva, e termina `CONCLUIDO` no próprio setor Estoque.
- **SLA por etapa** — meta de tempo de cada etapa do fluxo (ex.: quarentena, inspeção), além do prazo do pedido (`data_previsao`). Proposta; as metas ainda precisam ser definidas com os setores. Ver [[Rastreabilidade-e-SLA-de-Eventos]].
- **Torre de Fluxo** — protótipo de tela com o mapa do fluxo por setor, contagem por etapa, tempo contra SLA e trilha do item. Ver [[Rastreabilidade-e-SLA-de-Eventos]].
- **Waterfall de dedução** — metodologia de cascata usada para reconciliar Venda Bruta → Venda Líquida. Ver [[AV-Hub-Vendas-Reconciliacao]].

## Verbetes acrescentados em 07/10/2026

> Decisões e status de 07/10: [[Registro-de-Decisoes-2026-10-07]]. Estado do projeto: [[Onde-Estamos]].

- **C6** — tarefa do MES (25/09) que cria os tipos de Fábrica e de Setor: `Fabrica.tipo` e `Setor.tipo`, com a fábrica Revenda e o Estoque como etapa 1. Concluída e conferida no código em 28/09. Ver os verbetes "Fábrica (tipo)" e "Setor (tipo)" acima e [[Encaixe-Estoque-Revenda-no-PCP]].
- **Casamento av-hub ↔ MES** — como o pedido/requisição de um sistema encontra o do outro. Resolvido na **DEC-2** por **polling REST**; evoluiu para o `PUT` do contrato 34, em que o MES empurra a requisição de compra ao av-hub (e lê os eventos por polling, contrato 35). Ver [[Chaves-de-Integracao-AvHub-MES-Pipeline]].
- **Diferença Entrega × `ItemParcial` × `sequencial`** — três coisas distintas que a palavra "parcial" mistura (ver também o verbete **Parcial**). `sequencial` é a linha do pedido no Omie (uma por nota fiscal parcial); `ItemParcial` é a fração de lote em produção no MES; `Entrega` é o evento de entrega parcial ao cliente. **Exemplo, pedido 27645:** sequenciais 0 a 4. O 0 é o guarda-chuva (R$ 1.226.900,00); os parciais 1 a 4 valem R$ 193.200,00, R$ 177.744,00, R$ 112.056,00 e R$ 187.500,00. A soma das cinco linhas é R$ 1.897.400,00, igual à soma dos 10 itens do pedido. Fonte: `09-Contratos/Realizados/03-Contratos-Logica-Fora-Backend/08-Itens-por-Parcela-Pedidos.md`.
- **`fluxo.*`** — schema de rastreabilidade (tarefa I1): 7 tabelas, com o log de eventos **imutável** (`fluxo.evento`). Ver [[Rastreabilidade-e-SLA-de-Eventos]] e [[Campos-e-API-para-Rastreabilidade]]. Em 07/10 ainda não existe no Prisma.
- **Genealogia (J4)** — rastreio do lote de matéria-prima até o item entregue (lote de MP ↔ item entregue). Usa o `MovimentoEstoque` do tipo `CONSUMO`. Nasceu da DEC-12 (genealogia de material).
- **L6** — chave própria do MES para chamar o av-hub, de **escrita e restrita por rota** (hoje o `PUT` do contrato 34 abre só uma rota; as leituras usam outra chave). Pendente de decisão do Gustavo ([[Registro-de-Decisoes-2026-10-07]], item 10).
- **módulo `fluxo` (I2)** — módulo `fluxo` do MES (`api-pcp`), ligado ao schema `fluxo.*`; é a tarefa I2 do cronograma ([[Cronograma-2-Meses]]).
- **Prefixos de identificação nas notas** — **DEC** decisão-chave (cronograma e [[Decisoes-Chave-ERP]]); **EC** pergunta do encaixe do Estoque e da Revenda; **IM** pergunta da integração av-hub ↔ MES (spec F1); **CC** ponto da conferência de código de 07/10; **T** tela do mapa de telas ([[Fluxograma-Telas-por-Bloco]]; T.3 a T.6 são a Torre de Fluxo e a Auditoria); **L** com hífen (L-01...L-11) lacuna de lógica ([[Lacunas-de-Logica-e-Clareza]]) e sem hífen (L4, L6, L10.x) item numerado de contrato; **CA** pergunta de Compras e acessos; **R** pergunta de rastreabilidade. Todas listadas em [[Perguntas-em-Aberto-Consolidadas]].
- **Torre de Fluxo (I5/I6)** — 4 telas mais um BFF (mapa por setor, trilha do item, tempo por etapa e Auditoria). Hoje existe **só o protótipo, com dados fictícios** ([[Rastreabilidade-e-SLA-de-Eventos]]); depende do `fluxo.*` completo, na S5.
