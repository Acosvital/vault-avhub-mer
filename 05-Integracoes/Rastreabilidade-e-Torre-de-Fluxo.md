---
tags: [rastreabilidade, torre-de-fluxo, sla, integracao, av-hub, mes]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [LOG-46, v1 Rastreabilidade-e-SLA-de-Eventos, v1 Campos-e-API-para-Rastreabilidade, api-acos-vital f322dcd (77223e9, 7c3f57a), api-pcp 579a625, HUB b55ac55, Dump Avhub de 14/10, Registro-de-Decisoes #35 #89 #92]
---

# Rastreabilidade e Torre de Fluxo

**Em uma frase:** a Torre de Fluxo é uma tela de consulta (só leitura) que mostra onde cada item do pedido está, há quanto tempo, com quem e quem autorizou.

**Quando consultar esta nota:** ao trabalhar no histórico de eventos, no prazo por etapa (SLA, a meta de tempo), nas telas T.3 a T.6 ou na troca de eventos entre MES e av-hub. Ela atravessa **todos os nós** do [[00-Fluxo-Mestre-0b]]. Contrato completo: [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas]] (status `parcial`).

## Quem manda dado para quem, quando e por quê

- **Cada sistema registra os próprios eventos** num histórico que nunca é alterado nem apagado. O av-hub registra os dele e o MES, os dele. Nada é copiado entre os bancos.
- **O MES deveria oferecer uma lista de eventos em ordem** (o "feed", rota `/fluxo/eventos`). 🔴 Ele ainda não tem esse módulo (BL-003) e responde "não encontrado" (404). Por isso a Torre está vazia.
- **O av-hub lê essa lista a cada 90 segundos** e calcula o estado atual, o dono atual, o tempo em cada etapa e a contagem por setor. ✅ Banco e job do av-hub estão prontos.
- **Trilha, tempo e SLA** vêm do MES sob demanda, quando alguém abre a tela. Se o MES estiver fora, o av-hub responde com `mes_indisponivel: true`.
- **O vendedor vê só o resumo** no cartão "Etapa dos itens" ([[Integracao-AvHub-MES]], INT-05). A Torre é uma visão interna.

## Decisões em uma olhada

- A meta de cada etapa nasce do tempo médio histórico. Ninguém digita meta; sem histórico, aparece "sem meta ainda".
- O SLA conta em horas corridas, e a pausa interrompe a contagem.
- Cada setor tem um líder responsável. "Fila do setor" e "com uma pessoa" são estados diferentes.
- O histórico fica 5 anos, sem apagar sozinho.

## Estado das peças

- ✅ Banco, job e rotas do av-hub.
- 🔴 Módulo `fluxo` e eventos nas transições do MES (Robert, BL-003).
- 🔴 Perfis de acesso às telas (BL-021) e eventos do lado do av-hub (BL-029).
- 🔴 Telas T.3, T.4, T.5, T.5b no HUB (Nathan, BL-022).

**Regra de ouro:** API e banco antes das telas. Ordem de subida: o Robert publica o feed, o Gustavo liga perfis e job, o Nathan troca os dados de teste pelos reais.

## Detalhe técnico

A Torre de Fluxo responde: onde cada item do pedido está, há quanto tempo, com quem e quem autorizou. Ela atravessa **todos os nós** do [[00-Fluxo-Mestre-0b]]. É só leitura. O contrato completo é [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas]] (status `parcial`). O fluxo de transporte entre os sistemas está em [[Integracao-AvHub-MES]], INT-07.

### Princípio

Um **log de eventos imutável** (append-only, sem `UPDATE` nem `DELETE`) por sistema; estado atual, dono atual, tempo em etapa e contagem por setor são projeções derivadas dele 📝. Cada sistema é dono dos próprios eventos (`origem` = `av-hub` ou `mes`); nenhuma tabela é copiada entre os dois. Transporte: polling REST com cursor `seq`, sem webhook (DEC-2).

### Decisões vigentes

| Decisão | Valor | Selo |
|---|---|---|
| Escopo do Ciclo 1 | rastreabilidade em todas as rotas (sprint S5, 19/11 a 18/12) | 📝 21/09 |
| Meta por etapa | nasce do tempo médio histórico, nunca digitada por setor; sem histórico, "sem meta ainda" | 📝 21/09 |
| Projeção de estouro | fica desligada no v1 até haver amostra mínima (piso a definir); inclinação do Nathan, não decisão fechada | 🟡 |
| SLA | horas corridas, com pausa interrompendo a contagem (`PAUSADO`/`RETOMAR` do `ItemParcial`) | 📝 21/09 |
| Responsável | cada setor tem um líder responsável; "sem dono" (fila do setor) é estado distinto de "com uma pessoa" | 📝 21/09 |
| Quem vê | só o vendedor, só o macro (cartão "Etapa dos itens", INT-05); a Torre é visão interna, sem acesso externo | 📝 21/09 |
| Retenção do log | 5 anos, sem expurgo automático (DEC-9) | 📝 |
| Genealogia de material | necessária (R-12); bloco J da S5; alocação de lote FIFO com escolha manual (DEC-12) | 📝 |
| Ranking de gargalos (T.5b) | proposta de levar ao Ciclo 2 para o Nathan caber na S5 (11,0 pd contra 9,2) | 🟡 #35 |
| Etapas do feed | vocabulário **provisório**; as de fábrica saem do roteiro e do `ItemParcial` | 🟡 |

### Envelope do evento (feed do MES)

`GET /fluxo/eventos?apos_seq=&limite=` (limite máximo previsto 1000), ordem crescente por `seq`, `x-api-key` entre serviços (chave D em [[Chaves-e-Autenticacao]]).

| Campo | Significado |
|---|---|
| `seq` | cursor monotônico (bigserial), nunca data |
| `id` | uuid gerado na origem; base da idempotência |
| `origem` | `av-hub` ou `mes` |
| `codigo_empresa`, `numero_pedido`, `codigo_item_omie` | chave de correlação (a filial vem do pedido, DEC-1); opcionais `id_lote`, `id_oc`, `id_item_parcial` |
| `tipo` | transição, autorização, passagem, anexo, cancelamento, reabertura (lista fechada: 🔴 pergunta 2 do contrato) |
| `etapa_de`, `etapa_para`, `setor_fluxo` | vocabulário comum, provisório |
| `ator_id`, `ator_nome`, `ator_setor` | quem fez, com snapshot; ator nulo = "Sistema" |
| `autorizado_por_id`, `autorizado_por_nome` | só quando a ação exige aprovação; sempre diferente do ator |
| `passou_para_id`, `passou_para_fila` | destino da passagem |
| `id_responsavel_depois` | pessoa, ou a fila do setor se ninguém assumiu |
| `motivo`, `anexo_ref` | obrigatórios em reprovação, divergência, ajuste e cancelamento |
| `ocorrido_em` | hora do fato, relógio da origem; manda no SLA |
| `registrado_em` | só para auditar atraso de integração |

Ações que exigem `autorizado_por` (provisório, R-13): compra acima do limite, reprovação com destino do lote, ajuste de saldo, cancelamento, reabertura.

Idempotência: o hub só aplica o evento se for mais novo que o último aplicado ao item (compara `seq`); a janela de 200 `seq` relidos cobre confirmação fora de ordem entre transações ✅ (`item_estado_projetado.job.js:44-49`).

### Estado de cada peça (14/10)

| Peça | Dono | Estado | Selo |
|---|---|---|---|
| `HistoricoItemParcial` (trilha do `ItemParcial`) | Robert | existe no MES, `idUsuario` pode ser nulo | ✅ |
| Módulo `fluxo` do `api-pcp`: `fluxo.evento`, `/fluxo/eventos`, trilha, tempo, SLA | Robert | **não existe**: nenhuma pasta `fluxo` em `api-pcp/src` e nenhuma ocorrência de `fluxo/eventos` | 🔴 BL-003 |
| Instrumentação dos eventos nas transições (ItemParcial, Recebimento, Qualidade, Estoque, Compras·CCP) | Robert | não existe | 🔴 BL-003 |
| Regra de autorização e SLA por etapa no MES | Robert | não existe | 🔴 BL-003 |
| `core_fluxo.item_estado_projetado`, `evento`, `feed_cursor`, `vw_item_estado_atual`, `fn_feed_aplicar`, `fn_torre_*` | Gustavo | entregues (77223e9, 7c3f57a, migration 046b); a Torre está vazia: o MES responde 404 ❓ conferido na `api-test` em 13/10 | ✅ |
| Job de projeção `item_estado_projetado.job.js`, iniciado em `app.js:208` | Gustavo | roda a cada 90 s; 404 do MES avisa e repete a cada 10 min; trava `pg_try_advisory_xact_lock` por fonte | ✅ |
| Rotas do hub: `GET /fluxo/torre` (`item_estado_projetado.route.js:185`), `/fluxo/sla-etapas` (`:262`), `/fluxo/itens/:id/tempo` (`:281`), `/fluxo/itens/:id` (`:302`) | Gustavo | no ar; MES fora do ar devolve 200 com `mes_indisponivel: true` | ✅ |
| Perfis com `torre-fluxo` e `torre-fluxo-trilha` | Gustavo e Nathan | só o perfil de testes do time de TI recebeu (046b); sem perfil de negócio, ninguém abre a Torre com login | 🔴 BL-021 |
| Eventos do **lado do hub** (liberação, aprovação, fechamento de compra) em `core_fluxo.evento` | Gustavo | nada instrumenta; a Torre começaria no PCP | 🔴 BL-029 |
| BFF `/api/fluxo/*` e as telas T.3, T.4, T.5, T.5b no HUB | Nathan | **não existem**: nenhuma ocorrência de `fluxo/torre` ou `torre-fluxo` em `app`, `lib`, `components`, `services` do HUB b55ac55 | 🔴 BL-022 |
| `GET /itens/status` (005) e cartão "Etapa dos itens" | Robert, Gustavo, Nathan | no ar; HUB `components/Pedidos/EtapaDosItens.tsx`, `PedidoDetalhe.tsx` | ✅ |

### Telas (numeração reconciliada)

| Número | Tela | Origem dos dados | Permissão | Na S5 |
|---|---|---|---|---|
| T.3 | Mapa por setor | projeção do hub (`/api/fluxo/torre`) | `torre-fluxo` | sim |
| T.4 | Trilha do item (ator, autorizado por, passou para, responsável depois, motivo) | proxy do MES + eventos do hub (`/api/fluxo/itens/{id}`) | `torre-fluxo-trilha` (mostra nomes: LGPD) | sim |
| T.5 | Tempo por etapa (fila e execução separadas, meta, prazo) | MES sob demanda (`/tempo`, `/sla-etapas`) via API | `torre-fluxo` | sim |
| T.5b | Ranking de gargalos | agregação da projeção mais MES | `torre-fluxo` | candidata ao Ciclo 2 🟡 |
| T.6 | Auditoria (log imutável) | `fluxo.evento` | `torre-fluxo-auditoria` | **sem tarefa nem pd** 🔴 |

Estados comuns das telas: carregando (esqueleto), vazio ("Nenhum item acompanhado ainda"), indisponível (`disponivel: false`, quando a rota do hub responde 404), dado velho (faixa se `lido_em` passar de 10 min), erro genérico, etapa desconhecida (mostra o código cru). A trilha mostra o selo "autorização não registrada" quando a ação exige `autorizado_por` e ele falta, e o selo de inconsistência quando autorizador = ator. Fixtures nunca vão a produção.

### Como o front avança sem esperar o MES

Tipos em `lib/domain/fluxo-torre.ts` (modelo `lib/domain/etapas-item.ts`), interface `FonteTorre { listar(filtros); item(id) }`, fixtures com os casos de borda, fonte HTTP começando em `disponivel: false`, BFF com `requirePermission`, `headersDaApi()` (Bearer) e filtros em lista fechada (`HUB lib/api/escopoUnidade.ts:45`). A fonte é escolhida por constante no código, nunca por variável de ambiente. Plano completo na seção 8 do [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas]].

### Ordem de subida

1. Robert publica o contrato do feed e o módulo `fluxo` em homologação.
2. Gustavo: banco (feito), perfis das telas, job contra o MES de homologação.
3. Nathan troca a fonte de fixture para HTTP e testa ponta a ponta.
4. Só então as telas vão à `main` do HUB, com o slug já em `auth.telas`.

Regra de ouro: **API e banco antes do front**; rota sem linha em `auth.rotas_telas` devolve 403 `ROTA_SEM_PERMISSAO_MAPEADA` a todo usuário com token.

### Rollback

Front: reverter o PR. Job: sem chave de ligar e desligar (regra do Nathan); desligar é retirar `iniciarJobFluxoTorre()` do `app.js` ou tirar `MES_API_KEY` do ambiente 🟡 (Gustavo escolhe). Dados: a projeção é derivável; `TRUNCATE`, zerar o cursor e reprocessar.

### Riscos e perguntas abertas

| Item | Dono | Selo |
|---|---|---|
| R-08: volume de eventos por dia sem estimativa (define página, janela, partição do log) | Robert | 🔴 |
| R-13: lista de ações que exigem `autorizado_por` | Nathan | 🔴 |
| `{id}` de `/fluxo/itens/{id}` não está definido (id do `item_acompanhado` ou chave composta) | Robert e Gustavo | 🔴 #92 |
| LGPD do snapshot do ator no log e direito ao esquecimento | Nathan | 🔴 |
| Token expirado vira furo de acesso quando o BFF parar de filtrar por vendedor | Gustavo | 🔴 #92 |
| O 005 e a tela de etapa dos itens migram para o feed geral ou ficam em paralelo | Nathan e Robert | 🔴, sem pressa |
| Robert estoura a capacidade na S5: regra é estender a janela | Nathan | 🔴 ([[Riscos]] RS-004) |

Ver também: [[Estados-e-Status]], [[Backlog-por-Frente]] (BL-003, BL-021, BL-022, BL-029), [[AV-Hub-API]], [[MES-Backend]].
