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
| DEC-1  | ~~Vínculo Fábrica ↔ Filial (`codigo_empresa`): 1 fábrica = 1 filial fixa, ou vínculo por pedido?~~ ✅ **DECIDIDO em 21/09/2026** — por pedido (existe fábrica real atendendo matriz + filiais). Ver [[MES-Arquitetura-Decisoes]] item 7 e [[Decisoes-Chave-ERP]]. | Nathan + Robert           | 25/09 | ~~1 fábrica = 1 filial fixa~~ (não se aplica, decidido antes do prazo)    | C2 (destravada)      |
| DEC-2  | Mecanismo da integração av-hub ↔ MES v1: polling REST bidirecional com `x-api-key`, 3 fluxos (requisição, referência da OC, status por item)?                                                                                                                 | Nathan + Robert + Gustavo | 29/09 | Polling REST, sem webhook                                                 | F1, F2, F3, E1       |
| DEC-3  | Aprovação condicional de compra: acima de que valor e quem aprova?                                                                                                                                                                                            | Nathan + Diretoria        | 25/09 | Limite é parâmetro, desligado no v1                                       | E2                   |
| DEC-4  | Lote de carga inicial nasce liberado ou passa pela inspeção de qualidade?                                                                                                                                                                                     | Nathan + Qualidade        | 25/09 | Nasce liberado, com dupla conferência                                     | **D1**, G1, G3       |
| DEC-5  | Balança: digitação manual ou integração automática? (a operação ainda não sabe se a balança tem saída digital)                                                                                                                                                | Nathan + Operação         | 25/09 | Digitação manual                                                          | D6, D7               |
| DEC-6  | Tolerância de peso por categoria de material                                                                                                                                                                                                                  | Nathan + Qualidade        | 25/09 | 5% padrão, ajustável por material                                         | D5                   |
| DEC-7  | ~~Contratos SQL: saldo como foto atual ou série histórica (002)~~ ✅ **já resolvido em produção — ver I-06**; id estável de item de compra (004, 🟡 risco confirmado — ver H); FK de locais para depósito (005, aberto); exclusão no polling (API 001, aberto) | Gustavo                   | 25/09 | Foto atual; id = pedido + sequência; sem FK; aceitar a lacuna de exclusão | **D1**, B3, B5, D3   |
| DEC-8  | Compra do hardware do posto de recebimento (impressora industrial + leitor 2D, ~R$ 5-7 mil)                                                                                                                                                                   | Nathan + Diretoria        | 25/09 | Sem hardware: etiqueta Code128 em impressora comum                        | H2, D11              |
| DEC-9  | Prazo de retenção de auditoria (5 anos é palpite; nunca discutido com contabilidade/fiscal)                                                                                                                                                                   | Nathan                    | 09/10 | 5 anos, sem expurgo automático                                            | nada                 |
| DEC-10 | Devolução de cliente: nasce como decisão no av-hub (Estoque só executa a entrada física) ou o ciclo completo, incluindo capturar o valor da devolução parcial, nasce no Estoque?                                                                              | Nathan                    | 13/11 | sem default                                                               | Fase D               |
| DEC-11 | Módulo financeiro nativo (Passo 15): quem decide e quando? Hoje nenhum dado financeiro é extraído do Omie e não há módulo no roadmap                                                                                                                          | Nathan → diretoria        | 13/11 | sem default                                                               | Desligamento do Omie |

---

## B. Rastreabilidade, custódia e SLA por etapa
Origem: [[Rastreabilidade-e-SLA-de-Eventos]] e [[Campos-e-API-para-Rastreabilidade]] (seção 7). Alimentam a spec F1, que fecha em 29/09.

| ID | Pergunta | Quem |
|---|---|---|
| R-01 | Colunas reais de `HistoricoItemParcial`/`Operador`/`Divergencia`: 🟡 **já levantadas — ver H**. "Operador é quem está logado ou escolhido na tela?" segue em aberto, mas por outro motivo: nenhuma ação de `itens-parciais` seta `idOperador` hoje — o campo existe no schema mas não é preenchido em nenhum lugar do código atual. Não é "qual dos dois comportamentos", é "nenhum foi construído ainda". | Robert |
| R-02 | SLA em horas corridas ou úteis? Se úteis, existe calendário e turnos por setor? | Nathan + setores |
| R-03 | O `codigo_item_omie` continua estável quando o pedido é parcializado (`sequencial` 1, 2...)? | Gustavo |
| R-04 | ~~Os operadores do chão de fábrica existem em `core.funcionarios`?~~ ✅ **já respondido — ver I-13** | Gustavo |
| R-05 | A previsão de chegada da OC volta ao MES junto da referência mínima (C7)? Ela é dado de prazo, não comercial. | Nathan |
| R-06 | O log guarda o nome do ator (snapshot) e como isso convive com a anonimização LGPD? 🟡 **já esclarecido em parte — ver H**: decisão em si segue aberta | Nathan |
| R-07 | A projeção `item_acompanhado` nasce só para Recebimento, Qualidade e Compras (mínimo do ciclo 1) ou para todas as rotas desde o início? | Todos |
| R-08 | Volume esperado de eventos por dia? Define partição e retenção do log. | Todos |
| R-09 | Quem define a meta de tempo de cada etapa (quarentena, inspeção, conferência...)? Os números do protótipo são chute. | Setores |
| R-10 | "Na mão de quem": pessoa nomeada em toda passagem, ou o setor basta no chão de fábrica? | Nathan + Operação |
| R-11 | O vendedor vê só o macro dos próprios pedidos ou também a trilha? O cliente externo algum dia vê algo? | Nathan |
| R-12 | Genealogia de material (lote da matéria-prima → item entregue): é exigência de cliente ou norma? | Nathan + Qualidade |
| R-13 | Quais ações exigem `autorizado_por`? Levantado provisoriamente: compra acima do limite, reprovação com destino do lote, ajuste de saldo, cancelamento e reabertura. Confirmar a lista. | Nathan |
| R-14 | O escopo da rastreabilidade no ciclo 1 é o mínimo (envelope + feed + Recebimento, Qualidade e Compras) ou o completo? O completo excede a capacidade do plano (9% de folga). | Nathan |

---

## C. Para o Gustavo (banco, API e pipeline Omie)
Origem: [[Indice-Contratos|os contratos]] (seção "Perguntas em aberto" de cada um). Nenhum contrato foi aplicado.

| ID | Contrato | Pergunta |
|---|---|---|
| G-01 | SQL 001 (parceiros fiscais) | `dadosBancarios` e `enderecoEntrega` vêm sempre em `ListarClientes` ou só em `ConsultarCliente`? Se só no `Consultar`, o custo de rate limit sobe. |
| G-02 | SQL 001 | `contribuinte_icms` bate com a convenção de nomes já usada em `core_vendas_faturamento`? |
| G-03 | SQL 001 | Tamanho de `chave_pix` (`varchar(100)`) é chute; a doc do Omie não define máximo. |
| G-04 | SQL 002 (saldo) | ~~Saldo como foto atual (upsert) ou série histórica por data?~~ ✅ **já resolvido — ver I-06** |
| G-05 | SQL 002 | ~~Escala de `cmc` e `preco_unitario` são chutes: existe convenção?~~ ✅ **já resolvido — ver I-07** |
| G-06 | SQL 003 (frete e parcelas) | `lista_parcelas` vem sempre no payload de `ListarPedidos` ou só em `ConsultarPedido`? — genuinamente aberta, precisa testar a API real do Omie (não coberto pelos levantamentos já feitos) |
| G-07 | SQL 003 | O Omie nunca manda mais de um bloco de frete por pedido (1:1)? Não validado contra payload real — mesma observação de G-06 |
| G-08 | SQL 004 (pedidos de compra) | ~~A criação de pedidos de compra vai nascer no Estoque/MES em vez do Omie?~~ ✅ **duplicata de I-03**, remover daqui |
| G-09 | SQL 004 | `codigo_pedido_compra_omie` como `integer` é id numérico estável no Omie, ou existe identificador mais robusto? — genuinamente aberta |
| G-10 | SQL 004 | Item de compra estável entre resyncs: 🟡 **confirmado como risco real, não hipótese — ver H**. Decisão segue pendente |
| G-11 | SQL 005 (locais) | `core.locais_estoque` ganha FK opcional para o futuro `deposito` do Estoque, ou fica isolada? (= DEC-7) — segue aberta, `deposito` ainda não existe |
| G-12 | SQL 006 (devolução) | ~~`vTotal` é o valor da devolução parcial ou o total do pedido original?~~ ✅ **moot — ver I-09** (contrato 006 já invalidado, esse caminho não será usado) |
| G-13 | API 001 (`alterado_desde`) | Exclusão não aparece no filtro incremental: aceitar a lacuna ou fazer reconciliação por diferença de conjunto? — confirmado como comportamento real (comentário no próprio código), decisão segue aberta |
| G-14 | API 001 | ~~O nome do parâmetro `alterado_desde` está alinhado com o que o time do Estoque espera?~~ ✅ **já decidido na prática — ver I-10** |
| G-15 | API 001 | Autenticação: o Estoque usa a mesma `x-api-key` compartilhada ou cada integração externa tem a sua? — genuinamente aberta |
| G-16 | Omie (pipeline) | Quem preenche as colunas protegidas de `vendedores`/`pedidos_vendas.manual`/`notas_fiscais`? 🟡 **pista concreta encontrada — ver H**. Decisão/confirmação segue pendente |
| G-17 | Portal do Vendedor | ~~As rotas `usuarios_favoritos` e `clientes_inativos` já existem?~~ ✅ **sim, confirmado — ver I-11**. Só falta validar se cobrem funcionalmente o que foi pedido |
| G-18 | `/vendas_planilha` | Paginação por pedido (família) vs. linha crua: 🟡 **confirmado no código que hoje é por linha crua (page/limit/offset) — ver H**. "Entra no plano?" segue sendo decisão de produto |

---

## D. Para o Robert (MES / `api-pcp`) e o time do Estoque
| ID | Origem | Pergunta |
|---|---|---|
| M-01 | [[App-PCP-Backend-Producao]] e [[Decisoes-Chave-ERP]] | Divergência sem endpoint de reabertura: 🟡 **confirmado como fato real no Prisma (não é suposição) — ver H**. "Intencional ou bug?" segue sendo decisão do Robert |
| M-02 | [[App-PCP-Backend-Producao]] | OS de beneficiamento de Revenda (ex.: corte de chapa) precisa de uma Fábrica/Setor leve, como "Beneficiamento → Corte", para caber no modelo. Confirmar. |
| M-03 | Contrato API 002 (alias) | Quem chama o endpoint de vínculo de duplicata? 🟡 Já existe recomendação registrada no próprio contrato (tela do Estoque, não o av-hub direto) — falta só formalizar como decisão, não é pergunta nova de verdade |
| M-04 | Contrato API 002 | ~~Alinhar os nomes `codigo_produto_omie_canonico`/`_duplicado` com o Prisma schema de `material`/`material_alias_omie`~~ ✅ **prematura**: confirmado que `material`/`material_alias_omie` não existem no Prisma do `api-pcp` ainda — não há nome nenhum pra alinhar até D1/D2 (schema do Estoque) existir |
| M-05 | [[Estoque-Modelo-Dados]] | Onde entra `destinacao_item_pedido` e `item_pedido` no diagrama de dados do Estoque (texto e diagrama divergem)? |
| M-06 | [[Fluxo-Detalhado-Pedido-Item]] e [[Diagramas-UML]] (seção 20) | Qual é o mecanismo de expiração e liberação da reserva de estoque? O `timeout` da seção 20 está "não definido". |
| M-07 | [[Fluxo-Detalhado-Pedido-Item]] | Como reconciliar a conferência do Recebimento com o modelo genérico `recebimento`/`item_recebido`? 🟡 **campos reais do endpoint de Recebimento do Omie já levantados — ver H** (bom insumo, não resolve a decisão de modelagem interna) |
| M-08 | [[Perguntas-Pendentes-MES-Estoque]] | ~~Devolução de cliente~~ ✅ **duplicata de DEC-10**, remover daqui |

---

## E. Para o negócio e a direção (Nathan, setores, contabilidade)
| ID | Origem | Pergunta |
|---|---|---|
| N-01 | [[Decisoes-Chave-ERP]] | O conceito de **Orçamento** (ainda não pensado): o que é, e quando entra em pauta? |
| N-02 | [[Decisoes-Chave-ERP]] | **Nome definitivo** do sistema de fábrica ("MES Aços Vital" é nome de trabalho). |
| N-03 | [[Decisoes-Chave-ERP]] | Reconciliar as iniciativas de comissão: `core_comissionamento` é só experimento? 🟡 **reframing — ver H**: já está em produção com impacto financeiro real (bug de comissão acima do teto corrigido em 18/09). A pergunta que resta é prioridade/investimento formal, não existência |
| N-04 | [[Decisoes-Chave-ERP]] | As views de Compras (`vw_catalogo_de_produtos`, `vw_fornecedores_com_produtos`, `vw_historico_precos`) já cobrem o que o módulo Orçamento precisa? |
| N-05 | [[Cronograma-2-Meses]] | Remessa de produtos (Passo 7): a Aços Vital usa? Confirmar antes de decidir se entra. |
| N-06 | [[Cronograma-2-Meses]] | Capacidade real: o plano assume 40% de foco para o Nathan e 75% para Robert e Pablo. O vault não registra alocação real. Confirmar ou ajustar. |
| N-07 | [[Cronograma-2-Meses]] | Com a execução começando em 22/09 (o plano previa S1 desde 18/09), reajustar as janelas da S1 e o marco M1 de 25/09? |

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
Estas **não têm resposta** — continuam precisando de uma pessoa decidir — mas o levantamento contra o dump/código real e os documentos de API do Omie já traz evidência concreta, então a conversa não precisa começar do zero.

| ID original | O que o levantamento trouxe                                                                                                                                                                                                                                | O que ainda falta decidir                                                                                                                     |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| R-01        | Colunas reais de `HistoricoItemParcial`/`Operador`/`Divergencia` já catalogadas (Prisma). `idOperador` de `ItemParcial` **não é setado por nenhuma ação hoje** — campo existe, ninguém escreve nele.                                                       | Se/quando construir essa escrita, decidir se vem do usuário logado ou de seleção manual.                                                      |
| R-06        | Hoje o log é **FK viva** (`HistoricoItemParcial.idUsuario`, `onDelete: SetNull`), não snapshot de nome — anonimizar um usuário (`Usuario.anonymizedAt`, LGPD) muda a exibição em **todo** o histórico retroativo de uma vez.                               | Se esse comportamento é aceitável ou se precisa de snapshot do nome no momento do evento.                                                     |
| G-10        | Confirmado no dump/backend: `pedidos_compras_itens.numero_item_omie` é nullable e sem índice único, com comentário explícito no código alertando para risco de duplicação em resync. Não é hipótese, é um bloqueio real e já documentado pelo próprio dev. | Definir o identificador estável antes de habilitar qualquer sync de compras.                                                                  |
| G-16        | [[Vendas-NFe-Lacunas]] (levantamento da API do Omie) acha que `vendedores.comissao` existe nativo no Omie e nunca foi extraído — pista forte de que a coluna protegida só precisa ligar esse sync, em vez de vir de "outro sistema" misterioso.            | Confirmar a hipótese e decidir se liga a extração.                                                                                            |
| G-18        | Testado no código: `/vendas_planilha` pagina hoje por linha crua (`page`/`limit`/`offset`, até 3000), não por pedido/família.                                                                                                                              | Se entra no plano trocar para paginação por família.                                                                                          |
| M-01        | Confirmado no Prisma: `Divergencia` tem `status` `ABERTA → EM_ANALISE → {RESOLVIDA\|CANCELADA}`, ambos terminais, zero endpoint de reabertura. Fato real, não suposição.                                                                                   | Se é intencional ou repete o padrão de "beco sem saída" já visto em outros lugares.                                                           |
| M-07        | [[Compras-Estoque-Producao-Lacunas]] traz os campos reais do endpoint de Recebimento do Omie (`nQtdeRecebida`, link a pedido de compra, lote na entrada, local de destino, flags de ciclo completo por transição).                                         | A modelagem interna (conferência contra Pedido de Venda × contra Ordem de Compra) continua sendo desenho próprio, o Omie não resolve sozinho. |
| N-03        | `core_comissionamento` já está em produção com impacto financeiro real: bug de comissão acima do teto contratado (cliente citado nominalmente no código), corrigido em 18/09; schema com evolução ativa em setembro.                                       | Não é mais "existe ou não" — é prioridade/investimento formal a decidir.                                                                      |

---

## Ver também
- [[Perguntas-Pendentes-MES-Estoque]]
- [[Estoque-Perguntas-Abertas]]
- [[Decisoes-Chave-ERP]]
- [[Cronograma-2-Meses]]
- [[Rastreabilidade-e-SLA-de-Eventos]]
- [[Campos-e-API-para-Rastreabilidade]]
- [[Auditoria-Dump-Producao-2026-09-21]]
