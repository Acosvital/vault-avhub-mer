---
tags: [erp-acos-vital, pendencias, perguntas, consolidado]
criado: 2026-09-21
atualizado: 2026-09-21
---

# Perguntas em aberto — lista consolidada

> Reúne, num só lugar, as perguntas em aberto espalhadas pelo vault, organizadas por **quem responde**. Levantada em 21/09/2026, um dia antes do início da execução. **A fonte de verdade continua sendo cada nota de origem** (coluna "Origem"); quando uma pergunta for respondida, atualizar lá e riscar aqui.

## Como usar
- **Prazo** e **default** vêm do [[Cronograma-2-Meses]] (seção 7). Se ninguém decidir até o prazo, o default vale e vira registro no vault.
- As perguntas marcadas **[trava D1]** bloqueiam a primeira tarefa de banco que começa em 22/09.

> **Revisão pontual de 21/09/2026** (cruzando o dump de produção, os models reais de `api-acos-vital`/`api-pcp`, e os 5 levantamentos da API do Omie em `08-Integracao-Omie/04-Levantamento-API-Omie/`): nem toda pergunta abaixo ainda precisa de decisão humana. Marcadas com ✅ as que já têm resposta de fato ou são redundantes (movidas para o bloco F); com 🟡 as que ficaram mais concretas mas a decisão em si segue pendente (detalhe no novo bloco H). O resto é genuinamente decisão de negócio, física, ou depende de testar a API real do Omie (não verificável só com os repositórios que temos).

---

## A. Decisões com prazo (DEC-1 a DEC-11)

| ID     | Pergunta                                                                                                                                                                                                                                                      | Quem                      | Prazo | Default se não decidir                                                    | Trava                |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- | ----- | ------------------------------------------------------------------------- | -------------------- |
| DEC-1  | ~~Vínculo Fábrica ↔ Filial (`codigo_empresa`): 1 fábrica = 1 filial fixa, ou vínculo por pedido?~~ ✅ **DECIDIDO em 21/09/2026** — por pedido: 1 fábrica pode atender as 3 filiais (matriz + 2), quando necessário. Ver [[MES-Arquitetura-Decisoes]] item 7 e [[Decisoes-Chave-ERP]]. | Nathan + Robert           | 25/09 | ~~1 fábrica = 1 filial fixa~~ (não se aplica, decidido antes do prazo)    | C2 (destravada)      |
| DEC-2  | ~~Mecanismo da integração av-hub ↔ MES v1: polling REST bidirecional com `x-api-key`, 3 fluxos (requisição, referência da OC, status por item)?~~ ✅ **DECIDIDO em 21/09/2026** — exatamente como proposto. Ver [[MES-Arquitetura-Decisoes]] item 8. | Nathan + Robert + Gustavo | 29/09 | ~~Polling REST, sem webhook~~ (não se aplica, decidido antes do prazo)    | F1, F2, F3, E1 (destravados) |
| DEC-3  | ~~Aprovação condicional de compra: acima de que valor e quem aprova?~~ ✅ **DECIDIDO em 21/09/2026** — acima de R$ 30.000, o **diretor** precisa aprovar. Ver [[Decisoes-Chave-ERP]].                                                                                                                                                                                            | Nathan + Diretoria        | 25/09 | ~~Limite é parâmetro, desligado no v1~~ (não se aplica, decidido)                                       | E2 (destravada)                   |
| DEC-4  | Lote de carga inicial nasce liberado ou passa pela inspeção de qualidade?                                                                                                                                                                                     | Nathan + Qualidade        | 25/09 | Nasce liberado, com dupla conferência                                     | **D1**, G1, G3       |
| DEC-5  | Balança: digitação manual ou integração automática? (a operação ainda não sabe se a balança tem saída digital)                                                                                                                                                | Nathan + Operação         | 25/09 | Digitação manual                                                          | D6, D7               |
| DEC-6  | Tolerância de peso por categoria de material                                                                                                                                                                                                                  | Nathan + Qualidade        | 25/09 | 5% padrão, ajustável por material                                         | D5                   |
| DEC-7  | ~~Contratos SQL: saldo como foto atual ou série histórica (002); id estável de item de compra (004); FK de locais para depósito (005); exclusão no polling (API 001)~~ ✅ **TOTALMENTE RESOLVIDO em 21/09/2026** — os 4 sub-itens têm resposta: saldo = foto atual (I-06); id de item de compra = `(id_pedido_compra, ordem)` (ver G-10); FK de depósito = ainda não, por design, Gustavo adiciona quando `deposito` existir (ver G-11); exclusão no polling = resolvido com `?incluir_deletados=true` (ver G-13). | Gustavo                   | 25/09 | ~~Foto atual; id = pedido + sequência; sem FK; aceitar a lacuna de exclusão~~ (não se aplica, decidido) | **D1**, B3, B5, D3 (destravados) |
| DEC-8  | Compra do hardware do posto de recebimento (impressora industrial + leitor 2D, ~R$ 5-7 mil)                                                                                                                                                                   | Nathan + Diretoria        | 25/09 | Sem hardware: etiqueta Code128 em impressora comum                        | H2, D11              |
| DEC-9  | Prazo de retenção de auditoria (5 anos é palpite; nunca discutido com contabilidade/fiscal)                                                                                                                                                                   | Nathan                    | 09/10 | 5 anos, sem expurgo automático                                            | nada                 |
| DEC-10 | Devolução de cliente: nasce como decisão no av-hub (Estoque só executa a entrada física) ou o ciclo completo, incluindo capturar o valor da devolução parcial, nasce no Estoque?                                                                              | Nathan                    | 13/11 | sem default                                                               | Fase D               |
| DEC-11 | Módulo financeiro nativo (Passo 15): quem decide e quando? Hoje nenhum dado financeiro é extraído do Omie e não há módulo no roadmap                                                                                                                          | Nathan → diretoria        | 13/11 | sem default                                                               | Desligamento do Omie |

---

## B. Rastreabilidade, custódia e SLA por etapa
Origem: [[Rastreabilidade-e-SLA-de-Eventos]] e [[Campos-e-API-para-Rastreabilidade]] (seção 7). Alimentam a spec F1, que fecha em 29/09.

| ID | Pergunta | Quem |
|---|---|---|
| R-01 | ~~Colunas reais de `HistoricoItemParcial`/`Operador`/`Divergencia`. "Operador é quem está logado ou escolhido na tela?"~~ ✅ **RESPONDIDO em 21/09/2026**: escolhido na tela, apontado pelo **líder do setor** — ainda não implementado (o campo `idOperador` existe no schema, mas nenhuma ação seta hoje; vira item de backlog, não é mais pergunta em aberto). | Robert |
| R-02 | ~~SLA em horas corridas ou úteis?~~ 🟡 **Leaning (21/09), não confirmado**: "acredito que atualmente horas corridas" — falta confirmar oficialmente (e se úteis algum dia, calendário/turnos por setor). | Nathan + setores |
| R-03 | ~~O `codigo_item_omie` continua estável quando o pedido é parcializado?~~ ✅ **RESPONDIDO em 21/09/2026**: sim — no `api-pcp` é o campo `idOmie` da tabela `ItensPedido` (confirmado no Prisma: `ItensPedido.idOmie`, opcional, só quando `sistema = OMIE`). | Gustavo |
| R-04 | ~~Os operadores do chão de fábrica existem em `core.funcionarios`?~~ ✅ **já respondido — ver I-13** | Gustavo |
| R-05 | ~~A previsão de chegada da OC volta ao MES junto da referência mínima? É prazo, não comercial?~~ ✅ **RESPONDIDO em 21/09/2026**: é dado de prazo. Confirma o desenho já esboçado (`PEDIDO_COMPRA.previsao_chegada` no Estoque). | Nathan |
| R-06 | ~~O log guarda o nome do ator (snapshot) e como isso convive com a LGPD?~~ ✅ **RESPONDIDO em 21/09/2026** (escopo do MES/PCP): "sem dados sensíveis, apenas nome do funcionário" — reduz o peso do dilema levantado em H (snapshot de nome, sem outras categorias de dado pessoal sensível), mas não resolve sozinho a política de anonimização (LGPD trata nome como dado pessoal, mesmo não sendo "dado sensível" na definição legal estrita) — ver conversa. | Nathan |
| R-07 | ~~`item_acompanhado` nasce só para Recebimento/Qualidade/Compras (mínimo) ou para todas as rotas?~~ ✅ **RESPONDIDO em 21/09/2026: todas as rotas.** ⚠️ **Atenção**: isso é o mesmo eixo de decisão de R-14, e o [[Cronograma-2-Meses]] avisa explicitamente que "completo" excede a capacidade do plano (só 9% de folga) — precisa reconciliar escopo × capacidade antes de entrar na spec F1, não só registrar a preferência. | Todos |
| R-08 | Volume esperado de eventos por dia? Define partição e retenção do log. | Todos |
| R-09 | ~~Quem define a meta de tempo de cada etapa?~~ 🟡 **Leaning (21/09), não confirmado**: "tempo médio talvez?" — ideia de usar medição histórica em vez de meta definida manualmente por setor; ainda não é decisão fechada (não diz quem calcula/aprova esse tempo médio). | Setores |
| R-10 | ~~"Na mão de quem": pessoa nomeada ou o setor basta?~~ ✅ **RESPONDIDO em 21/09/2026**: cada setor tem 1 líder responsável (custódia por líder de setor, não por indivíduo em toda passagem). | Nathan + Operação |
| R-11 | ~~O vendedor vê só o macro ou também a trilha? Cliente externo vê algo?~~ ✅ **RESPONDIDO em 21/09/2026**: só o vendedor tem acesso, e só ao macro (quais itens em quais setores) — sem trilha completa, sem acesso de cliente externo. | Nathan |
| R-12 | Genealogia de material (lote da matéria-prima → item entregue): é exigência de cliente ou norma? | Nathan + Qualidade |
| R-13 | Quais ações exigem `autorizado_por`? Levantado provisoriamente: compra acima do limite, reprovação com destino do lote, ajuste de saldo, cancelamento e reabertura. Confirmar a lista. | Nathan |
| R-14 | O escopo da rastreabilidade no ciclo 1 é o mínimo (envelope + feed + Recebimento, Qualidade e Compras) ou o completo? **Mesmo eixo de R-07, que já saiu "todas as rotas" — ver aviso de capacidade em R-07.** | Nathan |

---

## C. Para o Gustavo (banco, API e pipeline Omie)
Origem: [[Indice-Contratos|os contratos]] (seção "Perguntas em aberto" de cada um). Nenhum contrato foi aplicado.

| ID   | Contrato                    | Pergunta                                                                                                                                                                                                 |
| ---- | --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| G-01 | SQL 001 (parceiros fiscais) | ~~`dadosBancarios` e `enderecoEntrega` vêm sempre em `ListarClientes` ou só em `ConsultarCliente`?~~ ✅ **RESPONDIDO em 21/09/2026**: vêm por endpoints próprios com filtro por id — `/parceiros/{id}`, `/parceiros_endereco_entrega`, `/parceiros_dados_bancarios`. |
| G-02 | SQL 001                     | ~~`contribuinte_icms` bate com a convenção de nomes já usada em `core_vendas_faturamento`?~~ ✅ **RESPONDIDO em 21/09/2026**: sim, sem conflito. |
| G-03 | SQL 001                     | ~~Tamanho de `chave_pix` é chute.~~ ✅ **RESOLVIDO em 21/09/2026**: alterado para `varchar(255)` — folga suficiente pra qualquer formato de chave PIX (aleatória/e-mail/telefone/CPF-CNPJ). |
| G-04 | SQL 002 (saldo)             | ~~Saldo como foto atual (upsert) ou série histórica por data?~~ ✅ **já resolvido — ver I-06**                                                                                                            |
| G-05 | SQL 002                     | ~~Escala de `cmc` e `preco_unitario` são chutes: existe convenção?~~ ✅ **já resolvido — ver I-07**                                                                                                       |
| G-06 | SQL 003 (frete e parcelas)  | ~~`lista_parcelas` vem sempre no payload de `ListarPedidos` ou só em `ConsultarPedido`?~~ ✅ **RESPONDIDO em 21/09/2026**: vem no `ListarPedidos` também.               |
| G-07 | SQL 003                     | ~~O Omie nunca manda mais de um bloco de frete por pedido (1:1)?~~ ✅ **RESPONDIDO em 21/09/2026, com nuance**: no `ListarPedidos` é 1 frete **por sequencial** (não por pedido-família inteiro) — importante pro contrato SQL 003, que hoje modela `pedidos_vendas_frete` como 1:1 com `pedidos_vendas` por `(codigo_empresa, codigo_pedido_omie)`; como `codigo_pedido_omie` já é por sequencial (cada parcial é uma linha própria em `pedidos_vendas`), a relação 1:1 já esperada parece compatível — vale o Gustavo confirmar. |
| G-08 | SQL 004 (pedidos de compra) | ~~A criação de pedidos de compra vai nascer no Estoque/MES em vez do Omie?~~ ✅ **duplicata de I-03**, remover daqui                                                                                      |
| G-09 | SQL 004                     | ~~`codigo_pedido_compra_omie` como `integer` é id numérico estável no Omie, ou existe identificador mais robusto?~~ ✅ **RESPONDIDO em 21/09/2026, com um risco novo**: é o identificador estável do Omie — **mas vem como `string`**. A coluna real em `core_vendas_faturamento.pedidos_compras.codigo_pedido_compra_omie` é `integer` (e o próprio código já tinha um comentário alertando risco de overflow nela). Se o Omie manda string, guardar como integer pode truncar/quebrar em valores com zero à esquerda ou não-numéricos — **achado de risco técnico real, não só teórico**, vale o Gustavo avaliar antes do próximo sync de compras. |
| G-10 | SQL 004                     | ~~Item de compra estável entre resyncs?~~ ✅ **RESOLVIDO em 21/09/2026**: a identidade do item passou a ser a composta `(id_pedido_compra, ordem)`, não mais `numero_item_omie` — fecha o risco de duplicação em resync que estava documentado no código. |
| G-11 | SQL 005 (locais)            | ~~`core.locais_estoque` ganha FK opcional para o futuro `deposito`?~~ ✅ **RESPONDIDO em 21/09/2026**: ainda não tem FK porque a tabela `deposito` não existe — decisão consciente do Gustavo de adicionar quando ela existir, não esquecimento. |
| G-12 | SQL 006 (devolução)         | ~~`vTotal` é o valor da devolução parcial ou o total do pedido original?~~ ✅ **moot — ver I-09** (contrato 006 já invalidado, esse caminho não será usado)                                               |
| G-13 | API 001 (`alterado_desde`)  | ~~Exclusão não aparece no filtro incremental: aceitar a lacuna ou reconciliar?~~ ✅ **RESOLVIDO em 21/09/2026**: Gustavo implementou `?incluir_deletados=true` em `/produtos` e `/parceiros` — os excluídos voltam no mesmo payload incremental, com `deleted_at` preenchido. |
| G-14 | API 001                     | ~~O nome do parâmetro `alterado_desde` está alinhado com o que o time do Estoque espera?~~ ✅ **já decidido na prática — ver I-10**. Reconfirmado em 21/09: "já está em produção".                        |
| G-15 | API 001                     | ~~Autenticação: mesma `x-api-key` compartilhada ou cada integração tem a sua?~~ ✅ **ESCLARECIDO em 21/09/2026**: hoje a API não distingue qual chave chamou — `apiKeyAuth.js` só valida contra a lista do `.env`, sem registrar qual bateu. O `requestLogger` grava a chave mascarada, então dá pra diferenciar consumidores nos logs, **mas só se cada um tiver chave própria** — decisão de dar uma chave por consumidor ainda não foi tomada, é possibilidade técnica confirmada, não obrigação. |
| G-16 | Omie (pipeline)             | ~~Quem preenche as colunas protegidas de `vendedores`/`pedidos_vendas.manual`/`notas_fiscais`?~~ ✅ **RESPONDIDO em 21/09/2026 — corrige a pista de H**: comissão **não** é calculada no Omie; é calculada **internamente**, de forma manual em algumas partes. A hipótese anterior (extrair `vendedores.comissao` nativo do Omie) estava **errada** — não é questão de ligar um sync que falta, é processo manual mesmo, fora do Omie. |
| G-17 | Portal do Vendedor          | ~~As rotas `usuarios_favoritos` e `clientes_inativos` já existem?~~ ✅ **sim, confirmado — ver I-11**. Só falta validar se cobrem funcionalmente o que foi pedido                                         |
| G-18 | `/vendas_planilha`          | ~~Paginação por pedido (família) vs. linha crua: entra no plano?~~ ✅ **DECIDIDO em 21/09/2026**: continua como está (linha crua) — não entra no plano.                       |

---

## D. Para o Robert (MES / `api-pcp`) e o time do Estoque
| ID | Origem | Pergunta |
|---|---|---|
| M-01 | [[App-PCP-Backend-Producao]] e [[Decisoes-Chave-ERP]] | ~~Divergência sem endpoint de reabertura: intencional ou bug?~~ ✅ **RESPONDIDO em 21/09/2026**: nem um nem outro — a funcionalidade de reabertura **ainda não foi definida** (não é bug nem decisão consciente de "beco sem saída", é escopo que ainda não chegou a esse ponto). Vira item de backlog de design, não mais dúvida de intenção. |
| M-02 | [[App-PCP-Backend-Producao]] | ~~OS de beneficiamento de Revenda precisa de Fábrica/Setor leve "Beneficiamento → Corte"?~~ ✅ **RESPONDIDO em 21/09/2026, com contexto histórico**: funcionalidade ainda não definida. No sistema antigo o beneficiamento era **generalizado** — não registrava o tipo específico de beneficiamento. Isso libera o time pra desenhar do zero, sem precisar replicar essa limitação do sistema legado. |
| M-03 | Contrato API 002 (alias) | Quem chama o endpoint de vínculo de duplicata? 🟡 Já existe recomendação registrada no próprio contrato (tela do Estoque, não o av-hub direto) — falta só formalizar como decisão, não é pergunta nova de verdade |
| M-04 | Contrato API 002 | ~~Alinhar os nomes `codigo_produto_omie_canonico`/`_duplicado` com o Prisma schema de `material`/`material_alias_omie`~~ ✅ **prematura**: confirmado que `material`/`material_alias_omie` não existem no Prisma do `api-pcp` ainda — não há nome nenhum pra alinhar até D1/D2 (schema do Estoque) existir |
| M-05 | [[Estoque-Modelo-Dados]] | Onde entra `destinacao_item_pedido` e `item_pedido` no diagrama de dados do Estoque (texto e diagrama divergem)? |
| M-06 | [[Fluxo-Detalhado-Pedido-Item]] e [[Diagramas-UML]] (seção 20) | Qual é o mecanismo de expiração e liberação da reserva de estoque? O `timeout` da seção 20 está "não definido". |
| M-07 | [[Fluxo-Detalhado-Pedido-Item]] | Como reconciliar a conferência do Recebimento com o modelo genérico `recebimento`/`item_recebido`? 🟡 **campos reais do endpoint de Recebimento do Omie já levantados — ver H** (bom insumo, não resolve a decisão de modelagem interna) |
| M-08 | [[Perguntas-Pendentes-MES-Estoque]] | ~~Devolução de cliente~~ ✅ **duplicata de DEC-10**, remover daqui |

---

## E. Para o negócio e a direção (Nathan, setores, contabilidade)
| ID   | Origem                 | Pergunta                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ---- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| N-01 | [[Decisoes-Chave-ERP]] | O conceito de **Orçamento** (ainda não pensado): o que é, e quando entra em pauta?                                                                                                                                                                                                                                                                                                                                                 |
| N-02 | [[Decisoes-Chave-ERP]] | **Nome definitivo** do sistema de fábrica ("MES Aços Vital" é nome de trabalho).                                                                                                                                                                                                                                                                                                                                                   |
| N-03 | [[Decisoes-Chave-ERP]] | ~~Reconciliar as iniciativas de comissão: `core_comissionamento` é só experimento?~~ ✅ **RESPONDIDO em 21/09/2026**: "comissão ainda em fase de implementação/teste" — confirma o reframing (já é tratado como algo real em construção, não um experimento descartável; já teve bug de produção com impacto financeiro real em 18/09). Falta só formalizar prioridade/investimento no roadmap, não mais decidir se "vira produto". |
| N-04 | [[Decisoes-Chave-ERP]] | As views de Compras (`vw_catalogo_de_produtos`, `vw_fornecedores_com_produtos`, `vw_historico_precos`) já cobrem o que o módulo Orçamento precisa?                                                                                                                                                                                                                                                                                 |
| N-05 | [[Cronograma-2-Meses]] | Remessa de produtos (Passo 7): a Aços Vital usa? Confirmar antes de decidir se entra.                                                                                                                                                                                                                                                                                                                                              |
| N-06 | [[Cronograma-2-Meses]] | Capacidade real: o plano assume 40% de foco para o Nathan e 75% para Robert e Pablo. O vault não registra alocação real. Confirmar ou ajustar.                                                                                                                                                                                                                                                                                     |
| N-07 | [[Cronograma-2-Meses]] | Com a execução começando em 22/09 (o plano previa S1 desde 18/09), reajustar as janelas da S1 e o marco M1 de 25/09?                                                                                                                                                                                                                                                                                                               |

---

## E2. Estados e status
Origem: [[Revisao-dos-Estados-e-Status]] (seção 5). Sete perguntas novas: entrega parcial de um item, concessão de lote fora de especificação, destino do lote reprovado por completo, timeout da reserva (alerta ou liberação), cancelamento de pedido em produção, regras de `Pedido.status` e `BLOQUEADO` no MES, e se o protótipo Torre de Fluxo deve ser refeito. Os pontos 2.1 a 2.3 da revisão precisam de resposta **antes da D1 e da spec F1**.

---

## E3. Lacunas de lógica e de domínio
Origem: [[Lacunas-de-Logica-e-Clareza]]. Onze pontos sem decisão: qual prazo manda no SLA (L-01), data de corte do marco zero (L-02), quem é a referência do saldo entre Omie e MES (L-03), OC no av-hub e no Omie (L-04), horizonte fiscal do Omie (L-05), como o pedido chega à fila do PCP (L-06), cruzamentos além dos 3 fluxos da F1 (L-07), exceção da DEC-4 (L-08), depósito por filial (L-09), sobras e unidade de medida (L-10) e consumo de matéria-prima (L-11).

---

## F. Perguntas que já foram respondidas mas ainda aparecem como abertas
Estas geram ruído. **Não são perguntas novas: são notas a corrigir.**

| ID | Onde aparece como aberta | O que diz a resposta |
|---|---|---|
| I-01 | [[MES-Arquitetura-Decisoes]] (decisão 6, "Não confirmado ainda: se o Omie tem endpoint de criação de Ordem de Compra") | Resolvido em 17/09/2026 em [[Decisoes-Chave-ERP]]: o Omie **tem** CRUD de OC (`produtos/pedidocompra/`). |
| I-02 | Contrato SQL 006 (`vTotal`, perguntas 1 e 2) e [[Perguntas-em-Aberto]] (item 2) | Em [[Perguntas-Pendentes-MES-Estoque]], confirmado em 17/09/2026: `StatusDevolucaoVenda` **não está disponível**; o valor da devolução parcial terá de ser capturado nativamente. O contrato 006 e o item 2 da seção de integração Omie partem de uma premissa invalidada, mas o índice da seção de contratos ainda lista o 006 como "proposta". |
| I-03 | Contrato SQL 004, pergunta 1 | Pergunta se a criação de pedidos de compra nascerá no Estoque. A decisão vigente ([[MES-Arquitetura-Decisoes]], decisão 5) é que a OC é **decidida no av-hub** e só referenciada no MES. |
| I-04 | [[Estoque-Perguntas-Abertas]] | Repete as 5 perguntas de negócio (tolerância, retenção, aprovação, carga inicial, balança) que já são DEC-3 a DEC-6 e DEC-9. Uma só lista deveria valer. |
| I-05 | [[Estoque-Roadmap]] | Lista a equipe sem o Pablo, que consta em [[Equipe-Projeto]] e no cronograma. |
| I-06 | DEC-7 / G-04 (saldo foto vs. série) | Confirmado no dump de produção de 21/09: `core.estoque_saldo` já está implementado como "foto atual" (upsert, índice único parcial por empresa+produto+local). Ver [[Auditoria-Dump-Producao-2026-09-21]]. |
| I-07 | DEC-7 / G-05 (escala de `cmc`/`preco_unitario`) | Já não são chutes: `cmc numeric(14,4)` e `preco_unitario numeric(14,2)` já estão em produção, no mesmo dump. |
| I-08 | G-08 (dono da linha de `pedidos_compras`) | Mesma pergunta do I-03: OC é decidida no av-hub, não no Estoque/MES. |
| I-09 | G-12 (`vTotal` é parcial ou total?) | Ficou moot: [[Vendas-NFe-Lacunas]] confirma que `vTotal` só existe via chamada individual (`StatusDevolucaoVenda`), sem listagem em massa — e o contrato SQL 006 que dependia disso já foi invalidado. Não vale mais a pena responder essa pergunta específica; a devolução parcial vai precisar de captura nativa (ver DEC-10). |
| I-10 | G-14 (nome do parâmetro `alterado_desde`) | Já está em produção com esse nome (`src/routes/produtos.js`/`parceiros.js`) — mudar agora quebraria o que já existe. |
| I-11 | G-17 (rotas `usuarios_favoritos`/`clientes_inativos` existem?) | Sim, confirmado no código: `auth.usuarios_favoritos` (tabela) e `vw_clientes_inativos` (view), ambas com rota montada. |
| I-12 | M-08 (devolução de cliente) | Mesma pergunta da DEC-10. |
| I-13 | R-04 (operadores existem em `core.funcionarios`?) | Não: `Operador` no `api-pcp` é um cadastro próprio e mínimo (nome + timestamps + soft delete), sem nenhum vínculo com `core.funcionarios` (tabela de outro sistema/banco). |

---

## G. O que já foi respondido e está em uso (para não perguntar de novo)
Pesagem já existe hoje; há múltiplos depósitos; não há consignação; matéria-prima pode ser importada; não há duplicidade de fornecedor no Omie; cisão de lote é prática real; cotação entre fornecedores fica fora do sistema; depósito é central e compartilhado; login do MES aceita usuário/senha e Azure AD; fornecedor e material são projeções do av-hub; OS e OP usam o mecanismo `ItemParcial`; corte de chapa é Revenda, não Fabricação; o Omie não expõe o valor da devolução parcial.

---

## H. Perguntas mais concretas, mas ainda sem decisão (achados de código/pesquisa, 21/09)
Estas **não têm resposta** — continuam precisando de uma pessoa decidir — mas o levantamento contra o dump/código real e os documentos de API do Omie já traz evidência concreta, então a conversa não precisa começar do zero. (R-01, R-06, G-10, G-13, G-16, G-18, M-01 e N-03 saíram daqui em 21/09 — já respondidas, ver blocos A/B/C/D/E.)

| ID original | O que o levantamento trouxe                                                                                                                                                                                                                                | O que ainda falta decidir                                                                                                                     |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| M-07        | [[Compras-Estoque-Producao-Lacunas]] traz os campos reais do endpoint de Recebimento do Omie (`nQtdeRecebida`, link a pedido de compra, lote na entrada, local de destino, flags de ciclo completo por transição).                                         | A modelagem interna (conferência contra Pedido de Venda × contra Ordem de Compra) continua sendo desenho próprio, o Omie não resolve sozinho. |

---

## Ver também
- [[Perguntas-Pendentes-MES-Estoque]]
- [[Estoque-Perguntas-Abertas]]
- [[Decisoes-Chave-ERP]]
- [[Cronograma-2-Meses]]
- [[Rastreabilidade-e-SLA-de-Eventos]]
- [[Campos-e-API-para-Rastreabilidade]]
- [[Auditoria-Dump-Producao-2026-09-21]]
