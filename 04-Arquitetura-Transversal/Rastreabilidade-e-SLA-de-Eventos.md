---
tags: [erp-acos-vital, arquitetura, rastreabilidade, sla, proposta]
criado: 2026-09-21
---

# Rastreabilidade, custódia e SLA por etapa — modelo de eventos

> **Status: proposta para a spec F1 (até 29/09/2026), não decisão.** Nasceu de uma conversa com o Nathan em 21/09/2026 e do protótipo de tela [Torre de Fluxo](https://claude.ai/artifact/SS4C4srRk9cr66UHUS2rE3), que usa dados fictícios. Tudo marcado como **premissa** abaixo precisa de validação antes de virar requisito.

## O que se quer enxergar

Para cada pedido e cada item:

1. **Tempo contra SLA**: quanto tempo em cada estado, contra o prazo do pedido (`data_previsao`) e contra uma meta por etapa. É o diagrama de tempo de [[Diagramas-UML]] (seção 16), só que alimentado por dados reais.
2. **Rastreabilidade**: a linha do tempo completa do pedido, do item e do lote.
3. **Responsabilidade**: quem fez, com quem está agora, quem autorizou e quem passou para frente.
4. **Visão por setor**: um mapa do fluxo (diagrama de atividades) em que cada setor mostra quantos itens tem em cada etapa, e o clique desce até o item.

## Princípio

**Um único log de eventos imutável; todo o resto é leitura derivada dele.** Estado atual, dono atual, tempo em etapa, contagem por setor e atraso são projeções, nunca fonte da verdade. É o mesmo princípio do `HistoricoItemParcial` do MES (ver [[App-PCP-Backend-Producao]]), estendido para cobrir Comercial, Compras, Qualidade e Estoque.

## O que já existe e o que falta

| Já existe | Falta |
|---|---|
| `HistoricoItemParcial` no `api-pcp`: trilha imutável de toda transição do `ItemParcial` (setor, status, operador/máquina) | Eventos de Compras, Comercial, Recebimento, Qualidade e Estoque |
| `data_previsao` e a régua de SLA do pedido no Portal do Vendedor ([[AV-Hub-Portal-Vendedor-Plano]]) | Meta de tempo **por etapa** |
| Motivo obrigatório em movimentação e ajuste de estoque ([[Estoque-Regras-Negocio]]) | Autorização registrada como dado (`autorizado_por`) |
| — | "Com quem está agora" e passagem explícita entre pessoas ou filas |
| — | Identificador de pessoa comum entre av-hub e MES |

`pedidos_vendas_status_historico` **não serve** de base: vem do Omie por polling, com granularidade grossa (ver [[Fluxo-Detalhado-Pedido-Item]]).

## Envelope do evento (proposta)

Todo evento, de qualquer sistema, tem os mesmos campos.

| Campo | Significado |
|---|---|
| `id` | Identificador único e estável do evento. Base da idempotência no polling. |
| `origem` | `av-hub` ou `mes`. Cada sistema é dono dos seus eventos. |
| `pedido`, `item`, e conforme o caso `lote`, `oc`, `os_op` | Chave de correlação. É o que permite juntar eventos de sistemas diferentes. |
| `tipo` | Transição, autorização, passagem, anexo, cancelamento etc. |
| `estado_de` → `estado_para` | Etapa anterior e nova, do vocabulário comum (abaixo). |
| `setor` | Setor onde o evento ocorreu. |
| `ator` | Pessoa que executou. |
| `autorizado_por` | Só quando a ação exige aprovação. **Sempre diferente do `ator`.** |
| `passou_para` | Pessoa ou fila de destino, quando há passagem. |
| `responsavel_depois` | Pessoa, ou `fila:<setor>` quando ninguém assumiu. |
| `motivo`, `anexo_ref` | Obrigatórios em reprovação, divergência, ajuste e cancelamento. |
| `ocorrido_em` | Horário do fato, no sistema de origem. |

**Ações que exigem `autorizado_por`** (levantadas das regras já documentadas, a confirmar): compra acima do limite (DEC-3), reprovação de qualidade com destino do lote, ajuste de saldo, cancelamento e reabertura.

## Custódia: "na mão de quem está"

- `responsavel_atual` é lido do último evento do item. **Só uma passagem explícita ou um "assumir" o altera.**
- Há dois estados distintos: **com uma pessoa** e **na fila do setor, sem dono**. O tempo parado sem dono é o principal indicador de gargalo, então precisa ser medido separadamente.
- O tempo de cada etapa se divide em **espera** (entre o item chegar à fila e alguém assumir) e **execução** (com uma pessoa).

## Vocabulário comum de etapas

Os estados do `ItemParcial` (8 estados) cobrem só a produção. O log precisa de um vocabulário macro que junte os sistemas. Etapas usadas no protótipo, derivadas de [[Fluxogramas-Completos]] e [[Setores-Envolvidos-no-Fluxo]]:

`vendas.emitido` → `pcp.classificacao` → (`compras.requisicao` → `compras.fechamento` → `compras.followup` → `recebimento.conferencia` → `recebimento.pesagem` → `qualidade.quarentena`) ou (`fabrica.espera` → `fabrica.execucao`) ou (`estoque.reservado`) → `qualidade.inspecao` → `expedicao.embalagem` → `expedicao.carga` → `fiscal.nf` → `expedicao.transporte`.

Desvios: `qualidade.reprovado` e `pcp.retorno`, `recebimento.divergencia`, `fabrica.retrabalho`. Nenhum estado fica sem saída, conforme [[Estoque-Riscos]].

> **Atenção: este vocabulário é provisório.** A revisão em [[Revisao-dos-Estados-e-Status]] mostrou que as etapas de fábrica devem ser geradas a partir do roteiro e do `ItemParcial` (não fixas), que `vendas.emitido` deveria ser `pcp.aceite`, que o SLA precisa separar tempo interno de tempo de terceiros (`tipo_tempo`) e que o status por item precisa de uma regra de agregação quando o item é dividido em parciais.

## SLA em dois níveis

1. **Prazo do pedido** (`data_previsao`): já existe.
2. **Meta por etapa**: **premissa nova**, parametrizável por etapa, com valor default por setor. Os números do protótipo (por exemplo, quarentena 24 h, inspeção 6 h, conferência quantitativa 4 h) são **chutes para a demonstração**, não medições. Precisam ser definidos com cada setor.

**Projeção de estouro:** fim previsto = tempo restante na etapa atual + soma das metas das etapas restantes. Se passar do prazo, o item aparece em risco antes de estar atrasado.

## Identidade comum

O MES tem login duplo (usuário/senha no chão de fábrica, e-mail/Azure AD no escritório) e RBAC próprio ([[Achado-Duplicacao-RBAC]], [[MES-Arquitetura-Decisoes]]). Para o av-hub mostrar "quem" da fábrica, e vice-versa, é preciso um **identificador único de pessoa entre os dois sistemas**. O melhor candidato é `core.funcionarios.id`: `auth.usuarios.id_funcionario` e `vendedores.id_funcionario` já apontam para lá. No MES, `Operador` hoje é só um nome, sem vínculo com usuário nem com funcionário, e operador sem e-mail também precisa de identificador. Detalhes e perguntas em [[Campos-e-API-para-Rastreabilidade]].

## Transporte entre sistemas

Segue a decisão vigente da DEC-2 ([[Cronograma-2-Meses]]): **polling REST**, sem webhook e sem tempo real. Proposta: o MES expõe um feed de eventos com filtro `?alterado_desde=` (mesmo padrão do contrato API 001), e o av-hub lê e projeta. Nenhuma tabela é copiada; cada sistema é dono dos próprios eventos, no espírito das "colunas protegidas" de [[Omie-ELT-Pipeline]]. Isso substitui, na prática, o endpoint de "status por item" (F3) por um feed mais geral do qual o status é uma leitura.

## Telas derivadas (protótipo)

- **Mapa de fluxo por setor**, com contagem por etapa e clique até o item.
- **Tempo por etapa contra o prazo**, com fila e execução separadas e projeção de estouro.
- **Trilha do item**: quem fez, quem autorizou, quem passou, com quem está.
- **Ranking de gargalos** por setor.

## Impacto no cronograma

O [[Cronograma-2-Meses]] cobre hoje "status por item" só para Fabricação e Recebimento. Este modelo amplia o escopo. Duas saídas, a decidir com o Nathan:

- **Mínimo (recomendado se a data for fixa):** definir o envelope e o feed na spec F1 e implementar só os eventos de Recebimento, Qualidade e Compras. Mapa e trilha ficam para o ciclo 2.
- **Completo:** exige capacidade além do plano, que já tem só 9% de folga.

## Perguntas em aberto

- SLA por etapa: quem define as metas de cada setor?
- "Na mão de quem": pessoa nomeada em toda passagem, ou o setor basta no chão de fábrica?
- Qual é o identificador único de pessoa entre av-hub e MES?
- Genealogia de material (lote da matéria-prima → item entregue): é exigência de cliente ou norma?
- O vendedor vê só o macro ou também a trilha? Algum dia o cliente externo vê algo?
- Prazo de retenção do log (ver DEC-9, 5 anos por palpite).

## Ver também
- [[Campos-e-API-para-Rastreabilidade]] — tabelas, campos e endpoints que esta proposta exige, e as inconsistências achadas no vault.
- [[Fluxo-Detalhado-Pedido-Item]]
- [[App-PCP-Backend-Producao]]
- [[Diagramas-UML]]
- [[Decisoes-Chave-ERP]]
- [[Cronograma-2-Meses]]
- [[Setores-Envolvidos-no-Fluxo]]
