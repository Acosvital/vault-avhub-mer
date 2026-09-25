---
tags: [erp-acos-vital, pendencias, perguntas, consolidado]
criado: 2026-09-21
atualizado: 2026-09-25
---

# Perguntas em aberto — lista consolidada

> Reúne, num só lugar, as perguntas em aberto espalhadas pelo vault, organizadas por **quem responde**. Levantada em 21/09/2026, um dia antes do início da execução. **A fonte de verdade continua sendo cada nota de origem** (coluna "Origem"); quando uma pergunta for respondida, atualizar lá e riscar aqui.

## Como usar
- **Prazo** e **default** vêm do [[Cronograma-2-Meses]] (seção 7). Se ninguém decidir até o prazo, o default vale e vira registro no vault.
- As perguntas marcadas **[trava D1]** bloqueiam a primeira tarefa de banco que começa em 22/09.

> **Revisão pontual de 21/09/2026** (cruzando o dump de produção, os models reais de `api-acos-vital`/`api-pcp`, e os 5 levantamentos da API do Omie em `08-Integracao-Omie/04-Levantamento-API-Omie/`): nem toda pergunta abaixo ainda precisa de decisão humana. Marcadas com ✅ as que já têm resposta de fato ou são redundantes (movidas para o bloco F); com 🟡 as que ficaram mais concretas mas a decisão em si segue pendente (detalhe no novo bloco H). O resto é genuinamente decisão de negócio, física, ou depende de testar a API real do Omie (não verificável só com os repositórios que temos).

---

## 0. FINALIZADO em 21/09/2026 — pendências reais que restam

> **Atualizado em 22/09/2026**: DEC-4, DEC-6, DEC-8, N-05, N-06 e N-07 foram respondidas hoje — ver seções A e E abaixo para o detalhe de cada uma. **Total caiu de 16 para 9 pendências reais.**
>
> **Atualizado em 25/09/2026**: as 7 perguntas novas do bloco "Encaixe do Estoque e da Revenda" (EN-01 a EN-07, levantadas em 24/09) foram todas respondidas hoje — ver [[Encaixe-Estoque-Revenda-no-PCP]] seção 5. O bloco sai desta lista.

De ~60 perguntas levantadas, **só estas seguem genuinamente sem resposta** (o resto está decidido, aceito ou moot — arquivo completo nas seções abaixo). Nada aqui foi fabricado ou assumido por mim — são fatos de negócio, físicos ou de alocação que só quem está na operação sabe responder.

**Rastreabilidade (R) — 2 restantes** (não existe R-19 — a numeração vai só até R-14, ver seção B)

| ID | Pergunta | Quem |
|---|---|---|
| R-08 | Volume esperado de eventos por dia (define partição/retenção do log `fluxo.evento`) | Todos |
| R-13 | Confirmar a lista de ações que exigem `autorizado_por` (levantamento provisório já existe) | Nathan |

**Estados e status — 6 restantes** (de [[Revisao-dos-Estados-e-Status]] seção 5; o ponto 2.1 já foi respondido, o timeout da reserva é a M-06, **decidida em 24/09/2026: sem expiração**)
1. Cliente pode receber entrega parcial de um item? O item fica parcialmente `FATURADO`?
2. Existe concessão de lote fora de especificação (aceite com restrição)? Quem autoriza?
3. Lote reprovado 100% (não só parcial): devolução, descarte ou retrabalho — quem decide?
4. Cancelar um pedido já em produção: o que acontece com as OS/OP em curso e o material já cortado?
5. `Pedido.status` do MES — alguém escreve isso hoje? `BLOQUEADO` — regra de entrada e de saída?
6. O protótipo Torre de Fluxo deve ser refeito com `tipo_tempo` e composição por parcial, depois de tudo que mudou hoje?

**Domínio — 1 restante**

| ID | Pergunta | Quem |
|---|---|---|
| L-10 | Sobra/retalho de chapa volta ao estoque como material rastreável? Como se pesa o que sobra? Qual a unidade de controle de cada material (kg × peça × metro)? | Nathan + Almoxarifado + Produção |

**Total: 9 pendências reais**, todas fatos de negócio/operação — nenhuma técnica. O resto do documento abaixo é o arquivo completo, com a resposta e a justificativa de cada item já fechado.

> O bloco "Encaixe do Estoque e da Revenda no MES" (EN-01 a EN-07, levantado em 24/09) teve as 7 perguntas respondidas em 25/09/2026 — ver [[Encaixe-Estoque-Revenda-no-PCP]] seção 5. Não conta mais como pendência.

---

## A. Decisões com prazo (DEC-1 a DEC-11)

| ID     | Pergunta                                                                                                                                                                                                                                                      | Quem                      | Prazo | Default se não decidir                                                    | Trava                |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- | ----- | ------------------------------------------------------------------------- | -------------------- |
| DEC-1  | ~~Vínculo Fábrica ↔ Filial (`codigo_empresa`): 1 fábrica = 1 filial fixa, ou vínculo por pedido?~~ ✅ **DECIDIDO em 21/09/2026** — por pedido: 1 fábrica pode atender as 3 filiais (matriz + 2), quando necessário. Ver [[MES-Arquitetura-Decisoes]] item 7 e [[Decisoes-Chave-ERP]]. | Nathan + Robert           | 25/09 | ~~1 fábrica = 1 filial fixa~~ (não se aplica, decidido antes do prazo)    | C2 (destravada)      |
| DEC-2  | ~~Mecanismo da integração av-hub ↔ MES v1: polling REST bidirecional com `x-api-key`, 3 fluxos (requisição, referência da OC, status por item)?~~ ✅ **DECIDIDO em 21/09/2026** — exatamente como proposto. Ver [[MES-Arquitetura-Decisoes]] item 8. | Nathan + Robert + Gustavo | 29/09 | ~~Polling REST, sem webhook~~ (não se aplica, decidido antes do prazo)    | F1, F2, F3, E1 (destravados) |
| DEC-3  | ~~Aprovação condicional de compra: acima de que valor e quem aprova?~~ ✅ **DECIDIDO em 21/09/2026** — acima de R$ 30.000, o **diretor** precisa aprovar. Ver [[Decisoes-Chave-ERP]].                                                                                                                                                                                            | Nathan + Diretoria        | 25/09 | ~~Limite é parâmetro, desligado no v1~~ (não se aplica, decidido)                                       | E2 (destravada)                   |
| DEC-4  | ~~Lote de carga inicial nasce liberado ou passa pela inspeção de qualidade?~~ ✅ **DECIDIDO em 22/09/2026** — nasce liberado, com dupla conferência (bate com o default).                                                                                                                                                                                     | Nathan + Qualidade        | 25/09 | ~~Nasce liberado, com dupla conferência~~ (confirmado, não é mais default) | **D1**, G1, G3 (destravadas)      |
| DEC-5  | ~~Balança: digitação manual ou integração automática?~~ ✅ **DECIDIDO em 21/09/2026** — manual (bate com o default). Ver [[Decisoes-Chave-ERP]].                                                                                                                                                | Nathan + Operação         | 25/09 | ~~Digitação manual~~ (confirmado, não é mais default) | D6, D7 (destravadas)               |
| DEC-6  | ~~Tolerância de peso por categoria de material~~ ✅ **DECIDIDO em 22/09/2026** — tolerância padrão única de 5% para todo material, sem ajuste por categoria no v1.                                                                                                                  | Nathan + Qualidade        | 25/09 | ~~5% padrão, ajustável por material~~ (confirmado só o padrão, sem ajuste por categoria) | D5 (destravada)                  |
| DEC-7  | ~~Contratos SQL: saldo como foto atual ou série histórica (002); id estável de item de compra (004); FK de locais para depósito (005); exclusão no polling (API 001)~~ ✅ **TOTALMENTE RESOLVIDO em 21/09/2026** — os 4 sub-itens têm resposta: saldo = foto atual (I-06); id de item de compra = `(id_pedido_compra, ordem)` (ver G-10); FK de depósito = ainda não, por design, Gustavo adiciona quando `deposito` existir (ver G-11); exclusão no polling = resolvido com `?incluir_deletados=true` (ver G-13). | Gustavo                   | 25/09 | ~~Foto atual; id = pedido + sequência; sem FK; aceitar a lacuna de exclusão~~ (não se aplica, decidido) | **D1**, B3, B5, D3 (destravados) |
| DEC-8  | ~~Compra do hardware do posto de recebimento (impressora industrial + leitor 2D, ~R$ 5-7 mil)~~ ✅ **DECIDIDO em 22/09/2026** — será comprado (impressora industrial + leitor 2D), ao contrário do default (que previa começar só com Code128 em impressora comum).                                                                                                                                                                   | Nathan + Diretoria        | 25/09 | ~~Sem hardware: etiqueta Code128 em impressora comum~~ (não se aplica, decidido: compra o hardware) | H2, D11 (destravadas)              |
| DEC-9  | ~~Prazo de retenção de auditoria (5 anos é palpite; nunca discutido com contabilidade/fiscal)~~ ✅ **DECIDIDO em 21/09/2026** — fica em 5 anos (bate com o default; validação formal com contabilidade/fiscal ainda não foi feita, mas a equipe optou por seguir com esse valor de trabalho).                                                                                                                                                                   | Nathan                    | 09/10 | ~~5 anos, sem expurgo automático~~ (confirmado)                            | nada                 |
| DEC-10 | ~~Devolução de cliente: decisão no av-hub ou ciclo completo no Estoque?~~ ✅ **DECIDIDO em 21/09/2026** — **ciclo completo nasce no Estoque**, incluindo capturar o valor da devolução parcial (que o Omie não expõe — ver I-09). Quebra o padrão "av-hub decide, MES executa" usado pra OC — aqui o Estoque decide e executa. Ver [[Decisoes-Chave-ERP]].                                                                              | Nathan                    | 13/11 | ~~sem default~~ (decidido antes do prazo)                                                               | Fase D (destravada)               |
| DEC-11 | ~~Módulo financeiro nativo (Passo 15): quem decide e quando?~~ ✅ **DECIDIDO em 21/09/2026** — só no futuro; fica fora do roadmap atual, sem data. Revisitar quando o desligamento do Omie entrar em pauta.                                                                                                                          | Nathan → diretoria        | 13/11 | ~~sem default~~ (decidido: adiado)                                                               | Desligamento do Omie |
| DEC-12 | ~~Estratégia de alocação de lote no consumo de matéria-prima pela OS/OP: qual lote baixar primeiro?~~ ✅ **DECIDIDO em 21/09/2026** — FIFO por `data_posicao` (mais antigo primeiro) como **padrão automático**, mas com **opção de escolher manualmente** o lote na hora do consumo (override do FIFO, não obrigatório usar). Trava a tarefa J3 (genealogia de material, S5). | Robert + Pablo | 20/11 | ~~FIFO por `data_posicao`~~ (confirmado, mais opção de escolha manual) | J3 (destravada) |

---

## B. Rastreabilidade, custódia e SLA por etapa
Origem: [[Rastreabilidade-e-SLA-de-Eventos]] e [[Campos-e-API-para-Rastreabilidade]] (seção 7). Alimentam a spec F1, que fecha em 29/09.

| ID | Pergunta | Quem |
|---|---|---|
| R-01 | ~~Colunas reais de `HistoricoItemParcial`/`Operador`/`Divergencia`. "Operador é quem está logado ou escolhido na tela?"~~ ✅ **RESPONDIDO em 21/09/2026**: escolhido na tela, apontado pelo **líder do setor** — ainda não implementado (o campo `idOperador` existe no schema, mas nenhuma ação seta hoje; vira item de backlog, não é mais pergunta em aberto). | Robert |
| R-02 | ~~SLA em horas corridas ou úteis?~~ ✅ **CONFIRMADO em 21/09/2026**: horas corridas, **com pausa explícita interrompendo a contagem** — exemplo dado: pessoa inicia, pausa (ação explícita) e sai, volta e retoma; o relógio só conta enquanto não está pausado. Bate com o mecanismo já existente (`ItemParcial` estado `PAUSADO`/`RETOMAR`) e com a distinção espera×execução já cogitada em [[Rastreabilidade-e-SLA-de-Eventos]]. Parte de "calendário/turnos por setor" fica sem objeto (só valia se fosse horas úteis). | Nathan + setores |
| R-03 | ~~O `codigo_item_omie` continua estável quando o pedido é parcializado?~~ ✅ **RESPONDIDO em 21/09/2026**: sim — no `api-pcp` é o campo `idOmie` da tabela `ItensPedido` (confirmado no Prisma: `ItensPedido.idOmie`, opcional, só quando `sistema = OMIE`). | Gustavo |
| R-04 | ~~Os operadores do chão de fábrica existem em `core.funcionarios`?~~ ✅ **já respondido — ver I-13** | Gustavo |
| R-05 | ~~A previsão de chegada da OC volta ao MES junto da referência mínima? É prazo, não comercial?~~ ✅ **RESPONDIDO em 21/09/2026**: é dado de prazo. Confirma o desenho já esboçado (`PEDIDO_COMPRA.previsao_chegada` no Estoque). | Nathan |
| R-06 | ~~O log guarda o nome do ator (snapshot) e como isso convive com a LGPD?~~ ✅ **RESPONDIDO em 21/09/2026** (escopo do MES/PCP): "sem dados sensíveis, apenas nome do funcionário" — reduz o peso do dilema levantado em H (snapshot de nome, sem outras categorias de dado pessoal sensível), mas não resolve sozinho a política de anonimização (LGPD trata nome como dado pessoal, mesmo não sendo "dado sensível" na definição legal estrita) — ver conversa. | Nathan |
| R-07 | ~~`item_acompanhado` nasce só para Recebimento/Qualidade/Compras (mínimo) ou para todas as rotas?~~ ✅ **RESPONDIDO em 21/09/2026: todas as rotas — é necessário, não preferência.** Já reconciliado com a capacidade: o cronograma foi estendido de 2 para 3 meses especificamente por causa disso (nova sprint **S5**, 19/11-18/12), sem tirar pd de S1-FC. Ver [[Cronograma-2-Meses]] seção 3.1 e 5. | Todos |
| R-08 | Volume esperado de eventos por dia? Define partição e retenção do log. | Todos |
| R-09 | ~~Quem define a meta de tempo de cada etapa?~~ ✅ **RESPONDIDO em 21/09/2026**: ninguém define a dedo — o sistema nunca rodou, não tem como saber hoje. A meta nasce do **tempo médio histórico**, calculado à medida que o sistema é usado (salva métricas/lead time por etapa e recalcula). ⚠️ **Implicação de design**: `fluxo.sla_etapa` nasce **sem meta real no v1** (não dá pra pré-popular com números confiáveis) — funcionalidades que dependem de meta_horas (ex.: "projeção de estouro" em [[Rastreabilidade-e-SLA-de-Eventos]]) não têm base útil até acumular histórico suficiente. 🟡 **Leaning do Nathan ("pode ser", não fechado)**: desligar a projeção de estouro até ter histórico — falta formalizar e definir o piso mínimo de amostras pra religar. | Setores |
| R-10 | ~~"Na mão de quem": pessoa nomeada ou o setor basta?~~ ✅ **RESPONDIDO em 21/09/2026**: cada setor tem 1 líder responsável (custódia por líder de setor, não por indivíduo em toda passagem). | Nathan + Operação |
| R-11 | ~~O vendedor vê só o macro ou também a trilha? Cliente externo vê algo?~~ ✅ **RESPONDIDO em 21/09/2026**: só o vendedor tem acesso, e só ao macro (quais itens em quais setores) — sem trilha completa, sem acesso de cliente externo. | Nathan |
| R-12 | ~~Genealogia de material: é exigência de cliente ou norma?~~ ✅ **DECIDIDO em 21/09/2026**: sim, é necessário — não é preferência. Já dimensionado e encaixado: vira o **bloco J** da S5 (J2-J5, 8,5 pd) em [[Cronograma-2-Meses]], resolve L-11. A estratégia de alocação de lote virou **DEC-12** (FIFO automático + escolha manual). | Nathan + Qualidade |
| R-13 | Quais ações exigem `autorizado_por`? Levantado provisoriamente: compra acima do limite, reprovação com destino do lote, ajuste de saldo, cancelamento e reabertura. Confirmar a lista. | Nathan |
| R-14 | ~~O escopo da rastreabilidade no ciclo 1 é o mínimo ou o completo?~~ ✅ **RESPONDIDO — mesma resposta de R-07: completo, é necessário.** Já encaixado na S5. | Nathan |

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
| M-03 | Contrato API 002 (alias) | ~~Quem chama o endpoint de vínculo de duplicata?~~ ✅ **MOOT em 21/09/2026** — contrato API 002 (`material_alias_omie`) **cancelado**. Nathan: "não quero mais tratar isso aqui, se eles quiserem eles tratam lá no Omie". Duplicata de catálogo sai do escopo deste sistema. |
| M-04 | Contrato API 002 | ~~Alinhar os nomes...~~ ✅ **MOOT em 21/09/2026** — contrato API 002 cancelado (ver M-03), não há mais o que alinhar. |
| M-05 | [[Estoque-Modelo-Dados]] | ~~Onde entra `destinacao_item_pedido` e `item_pedido` no diagrama (texto e diagrama divergem)?~~ ✅ **DECIDIDO e CONFIRMADO em 21/09/2026 pelo Nathan** (não é mais só recomendação pendente): não viram tabela nova no Estoque. Estoque e a classificação do PCP moram no **mesmo banco** (schemas diferentes, mesmo Postgres do MES) — o Estoque **lê direto** do schema de Produção via JOIN entre schemas, sem duplicar. Mesmo princípio já usado pra fornecedor (projeção, não cadastro próprio). O **diagrama está certo**; o **texto do PRD é que estava desatualizado**. |
| M-06 | [[Fluxo-Detalhado-Pedido-Item]] e [[Diagramas-UML]] (seção 20) | Qual é o mecanismo de expiração e liberação da reserva de estoque? O `timeout` da seção 20 está "não definido". ~~🔵 Explicitamente adiada pelo Nathan (21/09/2026).~~ ✅ **Decidida em 24/09/2026 (Robert):** **sem expiração** — a reserva só é liberada explicitamente quando o pedido ou a OP é cancelado. Reserva aponta para lote + `ItemParcial` (split atendido), status `ATIVA`/`CONSUMIDA`/`LIBERADA`. Ver [[Encaixe-Estoque-Revenda-no-PCP]]. |
| M-07 | [[Fluxo-Detalhado-Pedido-Item]] | ~~Como reconciliar a conferência do Recebimento com o modelo genérico `recebimento`/`item_recebido`?~~ ✅ **DECIDIDO em 21/09/2026 (Nathan confirma recomendação)**: não vira dois fluxos separados. `ITEM_RECEBIDO` ganha `tipo_referencia` (`PEDIDO_VENDA`\|`ORDEM_COMPRA`) + `id_referencia` — a flag acabado/não-acabado (já decidida em Compras) escolhe automaticamente contra o quê conferir, sem o almoxarife precisar escolher. Mesmo padrão polimórfico já em produção no av-hub (`auth.usuarios_favoritos.tipo`+`referencia_id`), só que aqui com FK real em cada lado (alvos fixos e conhecidos). Conferência qualitativa (Qualidade/quarentena) não muda, é igual pros dois casos. |
| M-08 | [[Perguntas-Pendentes-MES-Estoque]] | ~~Devolução de cliente~~ ✅ **duplicata de DEC-10**, remover daqui |

---

## E. Para o negócio e a direção (Nathan, setores, contabilidade)
| ID   | Origem                 | Pergunta                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ---- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| N-01 | [[Decisoes-Chave-ERP]] | ~~O conceito de **Orçamento**: o que é, e quando entra em pauta?~~ ✅ **DECIDIDO em 21/09/2026** — não entra neste ciclo nem no próximo horizonte definido, é só futuro, sem data (mesmo padrão de DEC-11 e L-05).                                                                                                                                                                                                                                                                                                                                                 |
| N-02 | [[Decisoes-Chave-ERP]] | ~~**Nome definitivo** do sistema de fábrica ("MES Aços Vital" é nome de trabalho).~~ ✅ **RESPONDIDO em 22/09/2026**: o nome é **MES** — aceito por ora, com abertura para trocar no futuro.                                                                                                                                                                                                                                                                                                                                                   |
| N-03 | [[Decisoes-Chave-ERP]] | ~~Reconciliar as iniciativas de comissão: `core_comissionamento` é só experimento?~~ ✅ **RESPONDIDO em 21/09/2026**: "comissão ainda em fase de implementação/teste" — confirma o reframing (já é tratado como algo real em construção, não um experimento descartável; já teve bug de produção com impacto financeiro real em 18/09). Falta só formalizar prioridade/investimento no roadmap, não mais decidir se "vira produto". |
| N-04 | [[Decisoes-Chave-ERP]] | ~~As views de Compras já cobrem o que o módulo Orçamento precisa?~~ ✅ **MOOT em 21/09/2026** — Orçamento não entra (ver N-01), não há mais o que cobrir por enquanto.                                                                                                                                                                                                                                                                                 |
| N-05 | [[Cronograma-2-Meses]] | ~~Remessa de produtos (Passo 7): a Aços Vital usa? Confirmar antes de decidir se entra.~~ ✅ **RESPONDIDO em 22/09/2026** — sim, usam (candidato forte: envio de material pra galvanização externa da Grade de Piso). Entra no escopo de extração do Omie (Passo 7 / roteiro de implementação), antes tratado como "confirmar antes". |
| N-06 | [[Cronograma-2-Meses]] | ~~Capacidade real: o plano assume 40% de foco para o Nathan e 75% para Robert e Pablo. O vault não registra alocação real. Confirmar ou ajustar.~~ ✅ **CONFIRMADO em 22/09/2026** — os focos assumidos (40% Nathan, 60% Gustavo, 75% Robert e Pablo) batem com a realidade, sem ajuste.                                                                                                                                                                                                                                                                                     |
| N-07 | [[Cronograma-2-Meses]] | ~~Com a execução começando em 22/09 (o plano previa S1 desde 18/09), reajustar as janelas da S1 e o marco M1 de 25/09?~~ ✅ **RESPONDIDO em 22/09/2026** — sim, reajustar. S1 passa a começar 22/09 (hoje); M1 desliza de 25/09 pra **29/09**, mantendo os mesmos 6 dias úteis de A1. Ver [[Cronograma-2-Meses]] seção 1/4/5 — **do S2 em diante o resto do plano ainda não foi recalculado** (ripple de ~1-4 dias úteis a confirmar antes de travar como definitivo).                                                                                                                                                                                                                                                                                                               |

---

## E2. Estados e status
Origem: [[Revisao-dos-Estados-e-Status]] (seção 5). ~~Ponto 2.1 (status por item com parciais)~~ ✅ **respondido em 21/09/2026** — atraso medido no nível do pedido, não por parcial (ver a nota, seção 2.1). Seguem em aberto as demais: entrega parcial de um item, concessão de lote fora de especificação, destino do lote reprovado por completo, timeout da reserva (= M-06, explicitamente adiada), cancelamento de pedido em produção, regras de `Pedido.status` e `BLOQUEADO` no MES, e se o protótipo Torre de Fluxo deve ser refeito.

---

## E3. Lacunas de lógica e de domínio
Origem: [[Lacunas-de-Logica-e-Clareza]]. ✅ **L-01 a L-09 e L-11 resolvidas/aceitas em 21/09/2026** (ver a nota — cada uma tem a resposta do Nathan ou a proposta original aceita como está). Só sobra **L-10** (sobras de chapa, perda no corte, conversão de unidade) genuinamente sem resposta — ninguém tratou ainda.

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
Pesagem já existe hoje; há múltiplos depósitos; não há consignação; matéria-prima pode ser importada; não há duplicidade de fornecedor no Omie; cisão de lote é prática real; cotação entre fornecedores fica fora do sistema; depósito é central e compartilhado entre fábricas (mas não incondicionalmente entre filiais — ver L-09); login do MES aceita usuário/senha e Azure AD; fornecedor e material são projeções do av-hub; OS e OP usam o mecanismo `ItemParcial`; corte de chapa é Revenda, não Fabricação; o Omie não expõe o valor da devolução parcial.

---

## H. Perguntas mais concretas, mas ainda sem decisão (achados de código/pesquisa, 21/09)
Estas **não têm resposta** — continuam precisando de uma pessoa decidir — mas o levantamento contra o dump/código real e os documentos de API do Omie já traz evidência concreta, então a conversa não precisa começar do zero. (R-01, R-06, G-10, G-13, G-16, G-18, M-01, M-07 e N-03 saíram daqui em 21/09 — já respondidas, ver blocos A/B/C/D/E.)

Vazio por ora — todos os itens que estavam aqui já foram resolvidos.

---

## Ver também
- [[Perguntas-Pendentes-MES-Estoque]]
- [[Estoque-Perguntas-Abertas]]
- [[Decisoes-Chave-ERP]]
- [[Cronograma-2-Meses]]
- [[Rastreabilidade-e-SLA-de-Eventos]]
- [[Campos-e-API-para-Rastreabilidade]]
- [[Auditoria-Dump-Producao-2026-09-21]]
