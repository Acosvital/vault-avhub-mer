---
tags: [erp-acos-vital, arquitetura, rastreabilidade, banco, api, proposta]
criado: 2026-09-21
---

# Campos, tabelas e API para rastreabilidade — o que criar, modificar e corrigir

> **Status: proposta, resultado de um pente fino no vault em 21/09/2026.** Complementa [[Rastreabilidade-e-SLA-de-Eventos]] (o modelo) com a lista concreta de mudanças de banco e API. Nada aqui foi aplicado. Onde o vault não permite confirmar uma coluna real, está marcado **(confirmar)**; a confirmação é com Robert (MES) ou Gustavo (av-hub/DBA).

## 1. Resultado do pente fino

### O que já estava conectado
- **Princípio do histórico imutável** já existe no MES (`HistoricoItemParcial`, [[App-PCP-Backend-Producao]]).
- **Fronteira av-hub decide / MES executa**, polling como único transporte e "colunas protegidas" ([[MES-Arquitetura-Decisoes]], [[Omie-ELT-Pipeline]]).
- **SLA do pedido** (`data_previsao`) no Portal do Vendedor ([[AV-Hub-Portal-Vendedor-Plano]]).
- **Reserva de estoque com estados** ([[Diagramas-UML]], seção 20) e cisão de lote (seção 7).

### O que estava solto (nenhuma nota apontava para o modelo de rastreabilidade)
Corrigido nesta mesma rodada com links: Home da seção de modelagem, [[Decisoes-Chave-ERP]], [[Cronograma-2-Meses]], [[Fluxo-Detalhado-Pedido-Item]], [[Diagramas-UML]] (seções 8 e 16), [[App-PCP-Backend-Producao]], [[Estoque-Modelo-Dados]], [[Glossario]], [[Campos-Faltantes-para-Estoque-MES]] e o [[Indice-Contratos]].

### Inconsistências encontradas (não corrigidas, precisam de decisão)
| # | Onde | O que está inconsistente |
|---|---|---|
| 1 | [[Estoque-Modelo-Dados]] × [[Diagramas-UML]] seção 17 | O texto lista `item_pedido` e `destinacao_item_pedido`; o diagrama de dados do Estoque não os tem. |
| 2 | Seção 20 × seção 17 | A reserva tem 5 estados (CRIADA, CONFIRMADA, EXPIRADA, CONSUMIDA, LIBERADA), mas `RESERVA_ESTOQUE` não tem coluna `status`. |
| 3 | [[Modelo-Destinacao-Item]] × seção 17 | O modelo exige um campo separado para o eixo 2 (disponibilidade no momento da checagem). Não existe em nenhum diagrama. |
| 4 | [[Fluxo-Detalhado-Pedido-Item]] | O vendedor escolhe se a Qualidade acompanha "desde o início" ou "só no fim". **Nenhum diagrama de dados tem esse campo.** |
| 5 | [[Fluxo-Compras-Completo]] (C1) × modelos | A requisição de compra é o ponto de integração MES → av-hub, mas **não há tabela de requisição** em lugar nenhum. A OC nativa do av-hub também não tem tabela: o contrato SQL 004 é só o espelho do Omie. |
| 6 | Seção 8 (9 estados macro do vendedor) × etapas do fluxo | O vendedor vê 9 estados; o fluxo tem cerca de 20 etapas. Falta a tabela de tradução entre eles. |
| 7 | Nomes | **"etapa"** já significa outra coisa (`pedidos_vendas.etapa` e `core.etapas_faturamento`, do Omie). **"setor"** já significa 3 coisas: `core.setores` (RH), `Setor` do MES (produção) e o setor do fluxo (PCP, Compras...). **"status"** e **"situacao"** também estão ocupados. |
| 8 | Seção 18 (`HISTORICO_ITEM_PARCIAL`) | O diagrama mostra só `status_anterior` e `status_novo`; o texto diz que registra setor e operador/máquina. **(confirmar colunas reais)** |
| 9 | [[Estoque-Roadmap]] | Lista a equipe sem o Pablo, que consta em [[Equipe-Projeto]] e no cronograma. |
| 10 | MES `Operador` | É um "cadastro simples (nome)" ([[App-PCP-Modelo-Producao]]), sem vínculo com usuário nem com `core.funcionarios`. |

## 2. Decisões de modelagem que vêm antes dos campos

1. **Chave de correlação concreta.** O pipeline usa `(codigo_empresa, codigo_pedido_omie)` para o pedido e `(codigo_empresa, codigo_item_omie)` para o item (seção de integração Omie, `01-Dados-Extraidos/Pedidos-de-Venda.md`); o `sequencial` (0 = guarda-chuva, 1/2/... = parciais) cria uma linha de pedido por parcial. O MES hoje só guarda `pedido_venda` como texto e `ItemPedido.codigo`. Proposta: toda entidade rastreada carrega `codigo_empresa + numero_pedido + codigo_item_omie`. **(confirmar com Gustavo se o `codigo_item_omie` se mantém estável quando o pedido é parcializado.)**
2. **Identidade de pessoa = `core.funcionarios.id`.** `auth.usuarios.id_funcionario` e `vendedores.id_funcionario` já apontam para lá. O MES precisa do mesmo vínculo em `Usuario` e em `Operador`. **(confirmar se os operadores do chão de fábrica existem em `core.funcionarios`, já que muitos não têm e-mail.)**
3. **Snapshot do nome no evento.** `auth.usuarios.id_funcionario` é `ON DELETE CASCADE` ([[Diagramas-UML]], seção 3): apagar o funcionário apaga o usuário. O evento guarda `ator_id` **e** `ator_nome`/`ator_setor` no momento do fato, senão a trilha perde o autor. O MES tem `anonymizedAt` (LGPD) e o av-hub não; a política de anonimização precisa valer para o log sem quebrá-lo.
4. **Onde mora cada dado, sem escrever na tabela do pipeline.** `pedidos_vendas` e `produto_vendas` são do pipeline ELT (colunas protegidas). A escolha de inspeção do vendedor e qualquer dado novo do pedido vão para **tabela lateral do av-hub**, nunca para `pedidos_vendas`.
5. **Onde mora o item que não é de fábrica.** O `Pedido`/`ItemPedido` do MES existe por fábrica. Itens de Revenda e de Estoque não têm linha no MES hoje, então não têm status possível. Precisa de uma projeção do item do pedido de venda, comum a todas as rotas (`item_acompanhado`, abaixo).
6. **Cursor por sequência, não por data.** Um filtro `alterado_desde=<timestamp>` pode perder eventos gravados no mesmo instante ou fora de ordem. O feed usa `seq` monotônico como cursor; `alterado_desde` fica só como conveniência.
7. **Nomes novos sem colisão.** Prefixo `fluxo` para tudo: schema `fluxo`, campo `etapa_fluxo`, `setor_fluxo`, `estado_macro`. Não reutilizar `etapa`, `setor`, `status` ou `situacao` nas tabelas novas.

## 3. Banco — criar

### 3.1 No MES (schema `fluxo`, banco do Prisma; seguindo a convenção schema por domínio)

| Tabela | Campos principais | Para quê |
|---|---|---|
| `fluxo.etapa_fluxo` (catálogo) | `codigo` (ex.: `qualidade.inspecao`), `setor_fluxo`, `nome`, `estado_macro` (um dos 9 da seção 8), `ordem`, `terminal`, `exige_autorizacao`, `papel_autorizador` | Vocabulário único de etapas e a ponte com os 9 estados do vendedor. |
| `fluxo.setor_fluxo` (catálogo) | `codigo`, `nome`, `sistema` (av-hub/MES/Omie), `id_setor_mes` (nullable), `id_setor_rh` (nullable) | Resolve a colisão das 3 noções de "setor". |
| `fluxo.item_acompanhado` | `id`, `codigo_empresa`, `numero_pedido`, `codigo_item_omie`, `id_material`, `quantidade`, `natureza` (REVENDA/FABRICACAO), `disponibilidade` (PRONTO/MP/SEM_ESTOQUE/NAO_AVALIADO), `inspecao_modo` (SEM/INICIO/FIM, projetado do av-hub), `etapa_fluxo`, `estado_macro`, `id_responsavel_atual` (nulo = fila), `fila_setor_fluxo`, `entrou_etapa_em`, `prazo_pedido`, `id_item_parcial` (nullable), `criado_em`, `atualizado_em` | Estado atual de cada item, para todas as rotas. Tudo derivável do log, mantido por projeção. |
| `fluxo.evento` (append-only) | `seq` (bigserial, cursor), `id` (uuid), `origem`, `codigo_empresa`, `numero_pedido`, `codigo_item_omie`, chaves opcionais (`id_lote`, `id_oc`, `id_item_parcial`), `tipo`, `etapa_de`, `etapa_para`, `setor_fluxo`, `ator_id`, `ator_nome`, `ator_setor`, `autorizado_por_id`, `autorizado_por_nome`, `passou_para_id`, `passou_para_fila`, `id_responsavel_depois`, `motivo`, `anexo_ref`, `ocorrido_em`, `registrado_em` | O log. Sem UPDATE e sem DELETE. |
| `fluxo.sla_etapa` | `etapa_fluxo`, `meta_horas`, `tipo_hora` (CORRIDA/UTIL), `id_fabrica`/`codigo_empresa` (override, nullable), `vigente_de`, `vigente_ate` | Meta por etapa, parametrizável e versionada. |
| `fluxo.regra_autorizacao` | `etapa_fluxo`/`acao`, `papel_exigido`, `valor_limite` (nullable), `ativa` | Quais ações exigem `autorizado_por` (ex.: compra acima do limite, DEC-3, desligada no v1). |
| `fluxo.calendario_util` | `data`, `util`, `hora_inicio`, `hora_fim` | Só se o SLA for em horas úteis. **Depende da pergunta 2 da seção 7.** |

### 3.2 No av-hub (`api-acos-vital`, schemas do cluster; colunas padrão `id uuidv7`, `created_at/by`, `updated_at/by`, `deleted_at/by`, como no contrato SQL 004 da seção de contratos)

| Tabela | Campos principais | Para quê |
|---|---|---|
| `core_compras.requisicao_compra` (+ `_item`) | `id`, `id_origem_mes` (idempotência), `codigo_empresa`, `numero_pedido`, `codigo_item_omie`, `id_produto` (`core.produtos`), `quantidade`, `prazo`, `restricao_acabado`, `status`, `id_comprador`, `assumida_em` | Recebe o C1 do PCP. Hoje não existe. |
| `core_compras.ordem_compra` (+ `_item`) | `id`, `id_requisicao`, `id_fornecedor` (`core.parceiros`), `valor_total`, `moeda`, `incoterm` (CIF/FOB), `acabado` (por item), `previsao_chegada`, `previsao_atualizada_por/em` (CCP), `requer_aprovacao`, `id_aprovador`, `aprovada_em`, `codigo_pedido_compra_omie` (nullable, para o push futuro) | A OC nativa (E2), com dado estruturado e sem PDF. **Não reutilizar** `pedidos_compras` (contrato 004): aquela é o espelho do Omie, protegida do pipeline. |
| `core_vendas_faturamento.pedido_acompanhamento` (lateral) | `codigo_empresa`, `codigo_pedido_omie`, `numero_pedido`, `inspecao_modo` (SEM/INICIO/FIM), `definido_por`, `definido_em` | Guarda a escolha do vendedor sem tocar em `pedidos_vendas`. |
| `core_fluxo.evento` | Mesmo envelope de `fluxo.evento` | Eventos de Comercial e Compras, dono av-hub. |
| `core_fluxo.item_estado_projetado` | `codigo_empresa`, `numero_pedido`, `codigo_item_omie`, `etapa_fluxo`, `estado_macro`, `atualizado_em` | Projeção do feed do MES para o Portal e a Torre de Fluxo. |
| `core_fluxo.feed_cursor` | `fonte`, `ultimo_seq`, `atualizado_em` | Cursor do polling por fonte. |

## 4. Banco — modificar

### 4.1 MES (Prisma) e Estoque (diagrama 17)
| Tabela | Acrescentar | Motivo |
|---|---|---|
| `Usuario` e `Operador` (MES) | `id_funcionario` (uuid, nullable; referência lógica, sem FK entre bancos) | Identidade comum. Hoje `Operador` é só um nome. |
| `Pedido` / `ItemPedido` (MES) | `codigo_empresa`, `codigo_pedido_omie` / `codigo_item_omie` | Chave de correlação. Também é onde entra o vínculo Fábrica ↔ Filial (DEC-1). |
| `ItemParcial` | `id_responsavel_atual` (nulo = fila do setor), `assumido_em`, `entrou_etapa_em`, `id_item_acompanhado` | Custódia e tempo em etapa. Hoje só há `id_setor_atual`. |
| `HistoricoItemParcial` | `ator_id`, `ator_nome`, `autorizado_por_id`, `passou_para_id`/`passou_para_fila`, `motivo`, `ocorrido_em`, `id_evento` **(confirmar quais já existem)** | Ou emitir o evento na mesma transação (recomendado) e manter este histórico como está. |
| `Divergencia` | `aberta_por`, `resolvida_por`, `resolvida_em`, `motivo_resolucao` **(confirmar)** | Quem tratou. A reabertura segue adiada por decisão anterior. |
| `RECEBIMENTO` | `iniciado_em`, `conferido_quant_por/em`, `conferido_qual_por/em` | As duas etapas de conferência têm pessoas diferentes. |
| `ITEM_RECEBIDO` | `id_item_acompanhado`, `divergencia_tipo`, `divergencia_tratada_por/em` | Liga o físico ao item do pedido; "divergência sempre com saída". |
| `PESAGEM` | `pesado_por`, `pesado_em`, `tolerancia_aplicada`, `dentro_tolerancia` | Trilha da pesagem. |
| `LOTE` | `criado_por`, `criado_em`, `quarentena_desde`, `liberado_por`, `liberado_em` | Tempo em quarentena, que tem SLA próprio. |
| `INSPECAO_QUALIDADE` | `tipo` (PROCESSO/FINAL), `inspetor_id`, `iniciada_em`, `concluida_em`, `motivo_reprovacao`, `evidencia_url`, `destino_reprovacao`, `id_item_acompanhado` | Hoje só há `laudo_url` e `aprovado`; a foto de avaria e o destino são regra do fluxo. |
| `RNC` | `aberta_por/em`, `fechada_por/em`, `evidencia_url`, `nota_devolucao_ref` | Ciclo de vida da RNC. |
| `RESERVA_ESTOQUE` | `status` (**3 estados desde 24/09/2026: `ATIVA`/`CONSUMIDA`/`LIBERADA`**, sem expiração), `criada_por`, `criada_em`, `consumida_em`, `liberada_por`, **`id_item_parcial`** (o split atendido — decidido em 24/09/2026, no lugar do `pedido_origem_id` solto e do `pedidoNumero` em texto do mock), `id_lote`, `quantidade`, `destinacao` | Corrige a inconsistência 2; liga ao item. Ver [[Encaixe-Estoque-Revenda-no-PCP]]. |
| `MOVIMENTO_ESTOQUE` | `usuario_id`, `ocorrido_em`, `localizacao_origem_id`, `localizacao_destino_id`, `autorizado_por` (ajuste), `id_evento` | Quem moveu e quem autorizou o ajuste. |
| ~~`MATERIAL`~~ | ~~`natureza` (REVENDA/FABRICACAO) se `tipo` não cobrir~~ | **Descartado em 24/09/2026:** a natureza do item (eixo 1 do [[Modelo-Destinacao-Item]]) vem de `Pedidos.idFabrica → Fabrica.tipo` (`FABRICACAO`/`REVENDA`), por item e por rodada — não é atributo do material. Ver [[Encaixe-Estoque-Revenda-no-PCP]]. |
| `FABRICA` / `SETOR` | `Fabrica.tipo` (`FABRICACAO`/`REVENDA`); `Setor.tipo` (`PRODUTIVO`/`ESTOQUE`/`COMPRAS`) | Encaixe de 24/09/2026: a etapa do `ItemParcial` passa a dizer em que subsistema o item está (estoque, compra, produção). |
| `MOVIMENTO_ESTOQUE` | `tipo` (`ENTRADA`/`SAIDA`/`TRANSFERENCIA`/`AJUSTE`), destino opcional, referência à origem (reserva, recebimento, OP) | Encaixe de 24/09/2026; a J2 acrescenta `CONSUMO`. |
| `PEDIDO_COMPRA` (referência no Estoque) | `id_oc_av_hub`, `previsao_chegada` | Só a referência mínima; o dado comercial não trafega. A previsão é dado de prazo, não comercial. **(decisão)** |
| Diagrama 17 | Incluir `item_pedido` e `destinacao_item_pedido` | Corrige a inconsistência 1. |

**Urgente:** a tarefa D1 (schema Prisma do Estoque v1) estava prevista para 21/09 a 29/09 e **começa em 22/09**, então ainda dá tempo de incluir estes campos antes da primeira migration. Campos de autoria e tempo (`criado_por`, `criado_em`, `id_item_acompanhado`) precisam entrar **nas migrations do v1**; acrescentá-los depois, com dados carregados, é bem mais caro. Com o início deslocado um dia, vale rever as janelas de S1 no [[Cronograma-2-Meses]].

### 4.2 av-hub
- **`pedidos_vendas`, `produto_vendas`, `pedidos_vendas_status_historico`: não alterar.** São do pipeline ou refletem o Omie com granularidade grossa ([[Campos-Faltantes-para-Estoque-MES]], item 5). O histórico fino nasce nas tabelas novas.
- **`core.funcionarios`:** confirmar que cobre operadores sem e-mail; se não, criar o cadastro ou uma tabela de identificação de chão de fábrica.
- **`auth`:** novas telas para o RBAC do av-hub (Torre de Fluxo, Trilha do item, SLA por etapa). No MES, o mesmo pelo RBAC próprio.
- **`core.etapas_faturamento`** continua sendo só o dicionário do Omie (Portal do Vendedor); não misturar com `etapa_fluxo`.

## 5. API futura

### 5.1 MES (módulo `fluxo` no `api-pcp`)
| Método e rota | Função |
|---|---|
| `GET /fluxo/eventos?apos_seq=&limite=` | Feed do log para o av-hub (polling). Ordenado por `seq`. |
| `GET /fluxo/itens/status?apos_seq=` | Estado atual por item (substitui F3 como leitura do log). |
| `GET /fluxo/itens/{id}/trilha` | Eventos do item, do mais novo para o mais antigo. |
| `GET /fluxo/itens/{id}/tempo` | Tempo por etapa (fila × execução), meta e projeção de estouro. |
| `GET /fluxo/setores` | Contagem por setor e etapa, com filtros (fora do prazo, em risco, sem dono). Alimenta o mapa. |
| `POST /fluxo/itens/{id}/assumir` | Uma pessoa assume um item da fila. |
| `POST /fluxo/itens/{id}/passar` | Passa para pessoa ou fila; grava a passagem. |
| `POST /fluxo/itens/{id}/autorizar` | Registra `autorizado_por`; recusa se autorizador = ator. |
| `GET/PUT /fluxo/sla-etapas` | Consulta e altera metas (perfil de gestão). |
| `GET /fluxo/etapas` e `/fluxo/setores/catalogo` | Catálogos. |

### 5.2 av-hub (`api-acos-vital` e BFF Next.js)
| Método e rota | Função |
|---|---|
| `POST /requisicoes-compra` | Recebe o C1 do MES (idempotente por `id_origem_mes`). |
| `GET /requisicoes-compra`, `POST .../{id}/assumir` | Caixa do Comprador (E1). |
| `POST /ordens-compra`, `POST .../{id}/aprovar`, `PATCH .../{id}/previsao-chegada` | E2 e o follow-up do CCP. |
| `GET /fluxo/eventos?apos_seq=` | Feed dos eventos de Comercial e Compras (o MES pode consumir). |
| `PUT /pedidos/{id}/acompanhamento` | O vendedor grava `inspecao_modo`. |
| `GET /api/fluxo/torre`, `GET /api/fluxo/itens/{id}` | Rotas do BFF que juntam os dois feeds para a tela, com `requirePermission`. |
| `GET /produtos` e `/parceiros` com `?alterado_desde=` | Já previsto no contrato de API 001 da seção de contratos. |

### 5.3 Regras que valem para todos os endpoints
- **Autenticação entre serviços:** `x-api-key`, como já usado. O **ator humano** vai no corpo do evento, não no cabeçalho da chave.
- **Idempotência:** o `id` do evento é gerado na origem; reenviar o mesmo evento não duplica.
- **Tempo:** `ocorrido_em` (relógio da origem) manda no SLA; `registrado_em` só serve para auditar atraso de integração.
- **Visibilidade:** o vendedor vê só o macro dos próprios pedidos (escopo resolvido no servidor, como já é no Portal); a trilha completa é para PCP, Qualidade, Compras e gestão.
- **Versão:** rotas sob `/v1`. Paginação por `apos_seq` + `limite`.

## 6. Visões derivadas (views, não tabelas)
`vw_item_estado_atual`, `vw_item_tempo_por_etapa` (fila × execução), `vw_setor_contagem` (mapa) e `vw_item_projecao_prazo` (fim previsto = restante da etapa atual + soma das metas seguintes). O mesmo padrão de "tabela crua + view curada" já usado no av-hub ([[AV-Hub-Vendas-Reconciliacao]]).

## 7. Perguntas que travam o desenho
1. ~~**Robert:** quais colunas reais tem `HistoricoItemParcial`, `Operador` e `Divergencia`? O operador registrado numa ação é quem está logado ou alguém escolhido na tela?~~ ✅ **Respondido (21/09)**: colunas já catalogadas; operador é escolhido na tela pelo líder do setor (ainda não implementado — `idOperador` existe no schema, nenhuma ação seta hoje).
2. ~~**Nathan / setores:** SLA em horas corridas ou úteis?~~ ✅ **Confirmado (21/09)**: horas corridas, com pausa explícita interrompendo a contagem (bate com `PAUSADO`/`RETOMAR` do `ItemParcial`) — calendário/turnos por setor não se aplica.
3. ~~**Gustavo:** `codigo_item_omie` é estável quando o pedido é parcializado? Os operadores de chão de fábrica existem em `core.funcionarios`?~~ ✅ **Respondido (21/09)**: sim, estável — no `api-pcp` é `ItensPedido.idOmie`. Operadores **não** existem em `core.funcionarios` — cadastro próprio e mínimo no MES.
4. ~~**Nathan:** a previsão de chegada da OC volta ao MES junto da referência mínima (C7)? Ela é prazo, não dado comercial.~~ ✅ **Respondido (21/09)**: é prazo, confirma o desenho da tabela `PEDIDO_COMPRA` (seção 4.1).
5. ~~**Nathan:** o log guarda o nome do ator no evento (snapshot) e como isso convive com anonimização LGPD?~~ 🟡 **Esclarecido em parte (21/09)**: no MES/PCP, sem dados sensíveis, só nome do funcionário — reduz o peso do dilema, mas a política de anonimização em si (reconciliar snapshot × direito ao esquecimento) segue sem decisão.
6. ~~**Todos:** a projeção `item_acompanhado` nasce só para Recebimento, Qualidade e Compras (mínimo do ciclo 1) ou para todas as rotas desde o início?~~ ✅ **Respondido (21/09): todas as rotas.** Resolvido via extensão do cronograma pra 3 meses (S5, 19/11-18/12) — ver [[Cronograma-2-Meses]] seção 3.1 e 5.
7. **Volume:** quantos eventos por dia se espera? Define partição e retenção (DEC-9 fala em 5 anos).

## 8. Encaixe no cronograma
- **Agora (D1, C1, C3, F1):** identidade (`id_funcionario`), autoria e tempo nas migrations do Estoque, e o envelope do evento e o cursor `seq` na spec F1, que fecha em 29/09.
- **Ciclo 1 (mínimo):** `fluxo.evento`, `etapa_fluxo`, `item_acompanhado` para Recebimento, Qualidade e Compras; requisição e OC nativas no av-hub; feed por polling. Isso já cobre "quem fez, quem autorizou, com quem está" nessas etapas.
- **Ciclo 2:** mapa por setor completo, SLA por etapa configurável em tela, calendário útil, demais rotas.

## Ver também
- [[Rastreabilidade-e-SLA-de-Eventos]]
- [[Estoque-Modelo-Dados]]
- [[Diagramas-UML]]
- [[Schema-Postgres-Multi-Dominio]]
- [[Cronograma-2-Meses]]
- [[Decisoes-Chave-ERP]]
- [[Modelo-Destinacao-Item]]
- [[Fluxo-Compras-Completo]]
