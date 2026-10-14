---
tags: [integracao, av-hub, mes, contratos, sequencia]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [api-pcp 579a625, api-acos-vital f322dcd, app-pcp 1fca8d3, HUB b55ac55, Dump Avhub e Dump MES de 14/10, v1 Chaves-de-Integracao-AvHub-MES-Pipeline, Integracao-AvHub-MES-Especificacao-F1, Integracao-AvHub-MES-Volta-Plano, MES-Arquitetura-Decisoes]
---

# Integração av-hub ↔ MES

Nota canônica das integrações entre o av-hub (`api-acos-vital` + HUB) e o MES (`api-pcp` + `app-pcp`). Uma seção por fluxo, com rota, direção, chave, cursor, idempotência, falha e estado no código. Os IDs dos nós são os do [[00-Fluxo-Mestre-0b]]. Chaves e escopos: [[Chaves-e-Autenticacao]]. Selos: [[Regras-do-Vault]].

## Regras que valem para todos os fluxos

- **Mecanismo:** REST com `x-api-key`. Dois bancos separados, nenhum acesso cruzado. Quem tem o dado expõe, quem precisa lê e grava projeção própria 📝 ([[Registro-de-Decisoes]], DEC-2). O padrão de leitura é polling com cursor, sem webhook.
- **Exceção da ida:** a requisição de compra é **empurrada** pelo MES (`PUT`, fila de saída), não puxada ✅ (`api-pcp` `envio-avhub.service.ts:129-175`). O contrato 003 (hub puxa do MES) ficou sem consumidor (ver INT-08 abaixo).
- **`codigo_empresa` em todo payload** 📝 (DEC-1): a filial vem do pedido, nunca da fábrica.
- **Idempotência por chave natural, não por token:** upsert por id de origem ou por id do evento. Reler uma janela nunca duplica.
- **Fronteira de dado:** o dado comercial (fornecedor, condição de pagamento) fica no av-hub. Para o MES vai o necessário para conferir e, desde o contrato 007, preço, moeda e cotação por item (para o custo do lote).
- **Nenhuma regra em variável de ambiente** para jobs novos (regra do Nathan): intervalo, página e janela são constantes no código; só endereço e segredo ficam em ambiente ✅ (`item_estado_projetado.job.js:44-49`).

## Tabela-resumo

| ID | Fluxo | Contrato | Direção e rota | Nós 0b | Estado |
|---|---|---|---|---|---|
| INT-01 | Liberação do pedido | [[LOG-26-Vendas-Liberacao-Pedido]] | HUB→av-hub `PUT /pedidos_liberacao/:codigo_empresa/:numero_pedido`; MES←av-hub `GET /pedidos_liberados`, `GET /pedidos_liberados/:numero/itens`; MES→av-hub `POST /pedidos_liberados/:numero/importado` | V2 V3 P1 P2 | ✅ ponta a ponta no código; chave de escopo mínimo 🔴 |
| INT-02 | Requisição de compra, ida | [[LOG-34-Requisicoes-MES-Empurra-para-o-Hub]] | MES→av-hub `PUT /compras/requisicoes/origem/:id_origem` | P3 | ✅ |
| INT-03 | Marcos da requisição, volta | [[LOG-35-Compras-Marcos-Requisicao-para-MES]] | MES←av-hub `GET /compras/requisicoes/eventos` | C1 a C5 R0 | ✅ para requisição do MES; 🔴 para requisição só do av-hub |
| INT-04 | Referência da OC | [[API-004-Referencia-OC-Integracao-MES]], [[API-007-Referencia-OC-Valores-no-MES]], [[SQL-011-Ordens-Compra-Referencia-MES]], [[SQL-012-Ordens-Compra-Referencia-Valores]] | MES←av-hub `GET /ordens-compra/referencia` | C4 R0 R1 R4 | ✅ lado do hub; 🔴 MES não consome |
| INT-05 | Status por item | [[API-005-Status-Item-Integracao-MES]], [[API-006-Status-por-Item-Leitura-no-Hub]], [[SQL-010-Itens-Pedido-Status]] | av-hub←MES `GET /itens/status` | todos | ✅ |
| INT-06 | Custo real por item | [[API-008-Custo-do-Lote-no-MES]], [[LOG-47-Custo-Real-por-Item-no-Hub]] | av-hub←MES `GET /itens/custo` | E3 R4 | ✅ lado do hub; 🔴 MES sem a rota |
| INT-07 | Torre de Fluxo | [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas]] | av-hub←MES `GET /fluxo/eventos` e proxy `/fluxo/*` | os 9 setores | ✅ lado do hub; 🔴 MES sem o módulo `fluxo` |
| INT-08 | Requisições lidas do MES | [[API-003-Requisicao-Compra-Integracao-MES]] | MES `GET /requisicoes-compra` | — | legado sem consumidor |

Detalhe da Torre: [[Rastreabilidade-e-Torre-de-Fluxo]].

## INT-01 Liberação do pedido (contrato 26)

**Para quê:** o pedido chega do Omie travado e só vai para o PCP depois que o vendedor marca se a Qualidade acompanha desde o início e libera. Nós V2, V3, P1, P2.

| Passo | Rota | Quem chama | Chave ou auth | Detalhe |
|---|---|---|---|---|
| Libera | `PUT /pedidos_liberacao/:codigo_empresa/:numero_pedido` corpo `{acompanhamento_qualidade, updated_by}` | HUB (BFF) | Bearer do usuário | 404 `PEDIDO_FORA_DA_LIBERACAO`, 409 `PEDIDO_IMPORTADO_MES` ✅ `pedidos_liberacao.route.js:164`, `:194`, `:222` |
| Lista a Triagem | `GET /pedidos_liberados?codigo_empresa=&mes=&ano=&page=&limit=` | MES (Triagem do Pedido, ao abrir) | `API_KEY` do MES | sob demanda, sem job ✅ `omie-integracao.ts:331-338`, `pedidos-carteira.service.ts:65` |
| Itens do pedido | `GET /pedidos_liberados/:numero/itens?codigo_empresa=` | MES (Destinação do Pedido) | `API_KEY` | 409 `PEDIDO_NAO_LIBERADO` barra a criação ✅ `pedidos.service.ts:245-248`, `pedidos_liberados.route.js:53` |
| Confirma | `POST /pedidos_liberados/:numero/importado?codigo_empresa=` corpo `{referencia}` | MES, depois de criar a Destinação | `API_KEY` | idempotente; a partir daí a marcação trava ✅ `omie-integracao.ts:393-425` |

- **Cursor e periodicidade:** não há job. A Triagem e a Destinação leem na hora. `alterado_desde` existe na rota, mas o MES não o usa.
- **Idempotência:** o `importado` vale a primeira `referencia` (número da ordem de produção, campo `Pedidos.ordemProducao`). O MES grava `Pedidos.importadoAvhubEm` ✅ `pedidos.service.ts:133`.
- **Falha e retentativa:** se o `importado` falha, a Destinação já existe e o MES **reenvia a cada 10 min** (`AVHUB_REENVIO_IMPORTADO_MIN`, padrão 10) para pedidos dos últimos 7 dias, 20 por rodada ✅ `pedidos.service.ts:63-81`. Sem o `importado` o vendedor ainda pode mudar a marcação.
- **Se o av-hub cai:** a Triagem responde 422 "Não foi possível carregar a carteira de pedidos" ✅ `omie-integracao.ts:354-360`; a Destinação não cria ordem; nada se perde.
- **Se o MES cai:** o vendedor segue liberando; os pedidos acumulam como `liberado` (status da view `vw_pedidos_liberacao`: `pendente`, `liberado`, `importado`).
- **Pendências:** data de corte `parametros_vendas.data_inicio_liberacao` em produção (01/09 ou 28/07) ❓ Gustavo; `auth.rotas_telas` para as rotas ❓ Gustavo; chave própria do MES com escopo mínimo 🔴 Gustavo ([[Chaves-e-Autenticacao]]).

```mermaid
sequenceDiagram
    participant OM as Omie
    participant PL as Pipeline
    participant HUB as HUB av-hub
    participant API as api-acos-vital
    participant MES as api-pcp MES
    OM->>PL: V1 pedido criado no Omie
    PL->>API: grava pedidos_vendas travado
    HUB->>API: V2 V3 PUT pedidos_liberacao marca e libera
    API-->>HUB: 200 status liberado
    MES->>API: P1 GET pedidos_liberados
    API-->>MES: lista so os liberados
    MES->>API: P2 GET pedidos_liberados numero itens
    API-->>MES: itens e acompanhamento_qualidade, 409 se nao liberado
    MES->>MES: P2 cria a Destinacao com Estoque como etapa 1
    MES->>API: P2 POST pedidos_liberados numero importado
    API-->>MES: 200 marcacao travada
    Note over MES,API: falhou o POST, o MES reenvia a cada 10 min por 7 dias
```

## INT-02 Requisição de compra, ida (contrato 34)

**Para quê:** o PCP pede compra de material de um pedido e o av-hub (Compras) passa a ver a requisição. Nó P3.

- **Rota:** `PUT {API_URL}/compras/requisicoes/origem/{id_origem}` ✅ `envio-avhub.service.ts:130`. `id_origem` = id do `RequisicaoCompraItem`. Uma requisição do MES com N materiais vira N requisições no av-hub.
- **Corpo:** `codigo_empresa`, `material`, `quantidade`, `unidade_medida`, `prazo_necessidade` e opcionais (`numero_requisicao_mes`, `descricao`, `acabado_sugerido`, `solicitante`, `observacao`, `codigo_pedido_omie`, `numero_pedido_venda`, `cancelada`) ✅ `requisicao-avhub.envio.ts:40-62`. O PUT não leva `id_item_parcial`.
- **Chave:** `AVHUB_MES_INTEGRACAO_KEY` no MES = um valor de `MES_INTEGRACAO_KEYS` no hub. Só abre esta rota; qualquer outra dá 403 `CHAVE_MES_ROTA_NAO_PERMITIDA` ✅ `apiKeyAuth.js:94-100`.
- **Respostas do hub** ✅ `requisicoes_compra.route.js:221-260`: 201 criou (nasce `aberta`, número `REQ-…`); 200 atualizou (sem OC); 200 `{aplicado:false, motivo:"com_oc"}` ou `"cancelada"`; 409 `REQUISICAO_COM_OC` ao cancelar requisição com OC; 400 campo inválido; 500 se falta a função de banco `fn_requisicao_mes_aplicar`.
- **Fila de saída (outbox):** a requisição e o envio nascem na mesma transação em `integracao_avhub_envios` (`PENDENTE`, `ENVIADO`, `RECUSADO`, `FALHOU`; `integracao.prisma:290-320`). Dispara logo após criar ou cancelar e a cada `AVHUB_ENVIO_INTERVALO_SEG` (padrão 60 s). Espera crescente 1, 2, 5, 10, 30, 60 min ✅ `envio-avhub.service.ts:21`.
- **Tratamento:** 200/201 vira `ENVIADO` e espelha id, número e status no item; 409 vira `RECUSADO` e não repete (o log avisa Compras) ✅ `:164-169`; 400 vira `FALHOU`; 401, 403, 404 e 5xx reagendam. Sem a chave definida, a fila espera com aviso no log ✅ `:98-102`.
- **Cancelamento** também vai pela fila e só vale sem OC.
- **Se o av-hub cai:** nada se perde; a fila acumula e retoma. **Se o MES cai:** o hub não recebe requisição nova.
- **Precisão:** o MES guarda 4 casas e o hub 3 (10,1234 vira 10,123).
- **Pendência:** o SQL de `fn_requisicao_mes_aplicar` (migration 034) existe em produção, mas não está versionado 🔴 Gustavo.

```mermaid
sequenceDiagram
    participant PCP as PCP no MES
    participant MES as api-pcp
    participant API as api-acos-vital
    participant CMP as Compras no HUB
    PCP->>MES: P3 POST compras requisicoes
    MES->>MES: grava RequisicaoCompra e o envio PENDENTE na mesma transacao
    MES->>API: PUT compras requisicoes origem id_origem
    API-->>MES: 201 nasce aberta com numero REQ
    MES->>MES: envio ENVIADO
    CMP->>API: C1 ve a requisicao na caixa do comprador
    PCP->>MES: cancela a requisicao
    MES->>API: PUT com cancelada true
    API-->>MES: 409 REQUISICAO_COM_OC se ja tem OC
    MES->>MES: envio RECUSADO sem repetir
```

## INT-03 Marcos da requisição, volta (contrato 35)

**Para quê:** o MES saber em que ponto do circuito de Compras está cada requisição dele, sem receber o dado comercial. Nós C1 a C5 e R0. A tela Compras · CCP do MES é só leitura e espelha esses marcos.

- **Rota:** `GET /compras/requisicoes/eventos?alterado_desde=&apos_id=&codigo_empresa=&limit=` (limite padrão 200, máximo 500). Resposta `{quantidade, tem_mais, proximo:{alterado_desde, apos_id}, data:[…]}` ✅ `requisicoes_compra.route.js:289`.
- **Chave:** `API_KEY` do MES (admin ou de `auth.chaves_servico`). A chave do 34 dá 403 aqui.
- **Cursor:** (`registrado_em`, `id_evento`). O MES guarda o cursor `requisicoes-eventos` em `integracao_avhub_cursores` e relê 2 min para trás a cada rodada ✅ `eventos-avhub.service.ts:25`. Primeira leitura desde `2026-01-01`.
- **Periodicidade:** 5 min (`AVHUB_EVENTOS_INTERVALO_MIN`) e uma rodada 10 s depois de subir; até 50 páginas de 200 por rodada ✅ `:25-27`. **Sob demanda:** `POST /compras/requisicoes/sincronizar` (`compras.controller.ts:57`) — a tela Compras · CCP chama ao abrir e no "Atualizar" (`FilaSetor.tsx:370-396`); pula se a última leitura boa tem menos de 30 s e rodadas simultâneas compartilham a mesma ✅ `eventos-avhub.service.ts:31,80`.
- **Idempotência:** o evento é gravado por `id_evento`; reler não reprocessa.
- **Falha:** evento que não aplica fica gravado com `ERRO:` em `acao`, sem `processadoEm`, e a leitura segue ✅ `eventos-avhub.service.ts:150-181`. Falha de rede reagenda sem mexer no cursor.
- **Só existem eventos de requisição com `id_origem`** (a do MES). Requisição criada só no av-hub não gera evento: `id_origem` é `NOT NULL` em `requisicoes_compra_eventos` (Dump Avhub) 🔴 (ver a seção "Lacuna: requisição só do av-hub").

Tratamento de cada `tipo` pelo MES (`requisicao-avhub.eventos.ts:234-318`, `etapaCompra`):

| `tipo` | Efeito no MES |
|---|---|
| `requisicao_recebida` | `AGUARDANDO_COMPRADOR` |
| `requisicao_reaberta` | `AGUARDANDO_COMPRADOR`; se o Compras cancelou e a parcial ainda está em Requisições, a requisição volta a `ABERTA` e a parcial a Compras; senão só anota |
| `em_cotacao` | `EM_COTACAO` |
| `oc_criada`, `oc_enviada_aprovacao` | `EM_APROVACAO`, grava `numeroOc` |
| `oc_removida` | `EM_COTACAO`, zera OC, aprovação e previsão |
| `oc_aprovada` | `COM_FORNECEDOR`, grava `ocAprovadaEm`, OC e previsão; a parcial vira **esperada** do Recebimento (R0) |
| `oc_no_omie` | grava `numeroPedidoOmie` |
| `fornecedor_confirmou` | só marco |
| `previsao_alterada` | atualiza `previsaoChegada` |
| `despachada` | `EM_TRANSITO`, grava `despachadaEm`, `nfFornecedor`, transportadora |
| `ocorrencia` | `ocorrenciaAberta = (dados.status === 'aberta')` |
| `oc_cancelada` | `AGUARDANDO_COMPRADOR`, limpa OC, Omie, previsão, despacho e NF |
| `requisicao_cancelada` | origem `mes` só confirma; origem `compras` com todos os materiais cancelados vira `CANCELADA` (`canceladaPor='compras'`) e a parcial volta a Requisições; só parte, anota |

Autor e comprador do marco (migration 035b do av-hub) vêm dentro de `dados` ✅ `requisicao-avhub.eventos.ts:47-48`.

```mermaid
sequenceDiagram
    participant CMP as Compras no HUB
    participant API as api-acos-vital
    participant MES as api-pcp
    participant CCP as Compras CCP no MES
    CMP->>API: C1 cotacao e C4 OC
    API->>API: trigger grava requisicoes_compra_eventos
    MES->>API: GET compras requisicoes eventos a cada 5 min
    API-->>MES: eventos desde o cursor
    MES->>MES: grava por id_evento e aplica etapaCompra
    CCP->>MES: POST compras requisicoes sincronizar ao abrir a tela
    MES->>API: GET eventos se a ultima leitura tem mais de 30 s
    Note over MES,CCP: C5 oc_aprovada faz a parcial entrar nos esperados do Recebimento R0
```

## INT-04 Referência da OC (contratos 004 e 007)

**Para quê:** o Recebimento conferir contra o que foi comprado e o lote nascer com custo (nós C4, R0, R1, R4). Hoje o Recebimento confere contra a **NF** 📝, e o cruzamento com a OC espera o job abaixo.

- **Rota no hub:** `GET /ordens-compra/referencia?alterado_desde=&codigo_empresa=&apos_id=&page=&limit=` (`alterado_desde` obrigatório; limite padrão 100, máximo 500) ✅ `vw_ordens_compra_referencia_mes.route.js:44-89`, montada em `core_vendas_faturamento/index.js:199`. Entram OC `aprovada` e as canceladas depois de aprovadas. `alterado_em` é o maior `updated_at` da OC, dos itens e dos vínculos (trigger da migration `api004`). A regra mora no banco.
- **Valores (contrato 007):** a resposta traz `moeda`, `cotacao_moeda`, `cotacao_data`, `cotacao_origem`, `valor_frete`, `valor_seguro` na OC e `valor_unitario`, `desconto_pct`, `valor_desconto`, `valor_total_item` em cada item ✅ `vw_ordens_compra_referencia_mes.route.js:51-53`. A rota tolera banco sem a migration `api007` (200 sem os campos) e responde 500 sem a `api004` ❓ se aplicadas em produção (Gustavo, SQL em [[SQL-012-Ordens-Compra-Referencia-Valores]]). Ainda sem fornecedor, condição de pagamento, categoria nem conta corrente.
- **Chave de leitura:** `API_KEY` do MES; a chave do 34 dá 403.
- **Cursor e periodicidade propostos:** `proximo` (`alterado_desde` + `apos_id`) com sobreposição de alguns minutos, a cada 5 min. Idempotência no MES por `(codigo_empresa, id_ordem_compra)` e itens por `(id_ordem_compra, id_item_oc)`.
- **MES não consome** 🔴: nada em `api-pcp/src` chama `ordens-compra`. Consequências: o fornecedor da requisição só é digitado na conferência e o custo da OC não entra no lote (ver INT-06). Dono: Robert, backlog [[Backlog-por-Frente]] (BL-001).
- **Ajuste pendente do 004:** `id_origem` em cada item (pedido do Robert em 30/09) 🔴 Gustavo conferir.
- **Se o hub cai:** o job (quando existir) reagenda; o Recebimento segue pela NF. **Se o MES cai:** a OC fica no hub.

```mermaid
sequenceDiagram
    participant API as api-acos-vital
    participant JOB as job no MES a criar
    participant MES as api-pcp
    participant REC as Recebimento
    API->>API: C4 OC aprovada e trigger atualiza alterado_em
    JOB->>API: GET ordens-compra referencia com chave de leitura
    API-->>JOB: OC com itens, id_origem e valores
    JOB->>MES: UPSERT projecao oc_referencia
    REC->>MES: R0 R1 confere contra a NF e cruza com a OC
    REC->>MES: R4 cria o lote com custo da OC
    Note over JOB,MES: nada disso existe no MES hoje
```

## INT-05 Status por item (contratos 005 e 006)

**Para quê:** o vendedor ver a etapa de cada item do pedido. Todos os nós, resumido em 11 etapas.

- **Rota no MES:** `GET /itens/status?alterado_desde=&codigo_empresa=&incluir_deletados=&limit=` (limite padrão 500, máximo 1000) ✅ `integracao-avhub.controller.ts:26`, `integracao-avhub.service.ts:114-156`. Resposta: foto atual por parcial (`id_item_parcial`, `pedido_venda`, `ordem_producao`, `codigo_produto_omie`, `etapa`, `setor`, `status`, `quantidade_na_etapa`, `atendido_pelo_estoque`, `ocorrido_em`).
- **Chave:** `MES_API_KEY` (AvhubApiKeyGuard, fail-closed: sem a variável responde 401) ✅ `avhub-api-key.guard.ts:14-16`.
- **Job no hub:** `itens_pedido_status.job.js`, a cada 90 s (`MES_STATUS_INTERVALO_SEG`), uma unidade por vez, página de 1000, cursor por unidade, `pg_try_advisory_xact_lock`; falha desfaz a transação e o cursor não anda; 401 ou 403 seguidos viram alerta no log; grava por `fn_itens_pedido_status_gravar` (migration `api005`) ✅ `itens_pedido_status.job.js:9-37`, iniciado em `app.js:207`.
- **Rota de leitura no hub:** `GET /itens_pedido_status?codigo_empresa=&pedido_venda=&historico=`; lê só a tabela local; escopo "dono do pedido", 403 se sem dono (contrato 006).
- **Idempotência:** chave `(codigo_empresa, id_item_parcial, etapa, ocorrido_em)`; o vendedor vê a etapa de maior `ocorrido_em`.
- **Vocabulário `etapa` (11 valores)** ✅ `integracao-avhub.service.ts:167-192`: `qualidade.reprovado`, `estoque.atendimento`, `compras.requisicao`, `compras.fechamento`, `recebimento.conferencia`, `qualidade.quarentena`, `qualidade.inspecao`, `expedicao.concluido`, `expedicao.embalagem`, `fabrica.execucao`, `fabrica.espera`. O HUB traduz em `lib/domain/etapas-item.ts:30-41`; etapa desconhecida aparece com o código cru. Ver [[Estados-e-Status]].
- **Front:** cartão "Etapa dos itens" (`EtapaDosItens`, BFF `app/api/pedidos-venda/[fonte]/…/etapas/route.ts`); avisa se o job parou há mais de 10 min.
- **Se o MES cai:** o job falha e tenta de novo; o cartão mostra a última foto e o aviso de dado velho. **Se o hub cai:** o MES não percebe (só responde a leituras).
- **Pendências:** `compras.fechamento` ainda é "Em compra", sem cotação, aprovação e trânsito 🔴 Robert + Nathan (BL-009); migration `api005` no banco ❓ Gustavo; teste ponta a ponta do cartão ❓ Nathan.

```mermaid
sequenceDiagram
    participant JOB as job no api-acos-vital
    participant MES as api-pcp
    participant DB as itens_pedido_status
    participant HUB as HUB cartao Etapa dos itens
    JOB->>MES: GET itens status a cada 90 s com MES_API_KEY
    MES-->>JOB: foto atual de cada parcial alterada
    JOB->>DB: fn_itens_pedido_status_gravar por unidade
    HUB->>DB: GET itens_pedido_status via API
    DB-->>HUB: etapa por item do pedido
    Note over MES,HUB: F1 E1 Q1 Q7 X1 viram as 11 etapas
```

## INT-06 Custo real por item (contratos 008 e 47)

**Para quê:** o custo do item do pedido = média dos lotes reservados (nó E3), usado pelo hub no Ciclo 2 para o simulador e a comissão ([[LOG-47-Custo-Real-por-Item-no-Hub]]).

- **Rota prevista no MES:** `GET /itens/custo?alterado_desde=&codigo_empresa=&apos_id=&limit=`, array puro, uma linha por filial + pedido + **produto** (`codigo_produto_omie`; linhas repetidas do pedido são somadas), com `quantidade`, `quantidade_com_custo`, `custo_total`, `custo_medio`, `completo`, `cotacao_a_conferir`, `lotes[]`, `alterado_em` ([[API-008-Custo-do-Lote-no-MES]]). **O MES não tem a rota** 🔴 Robert (BL-004).
- **Job no hub** ✅ `itens_pedido_custo.job.js`: a cada 90 s por unidade, cursor `alterado_em` + `id`; **404 do MES avisa e tenta a cada 10 min** (`:51-52`, `:193-199`); sem a migration 047b o job nem chama o MES (`:27`, `:157-180`).
- **Rota de leitura no hub:** `GET /itens_pedido_custo?codigo_empresa=&numero_pedido=` exige sempre `custo-itens:pode_visualizar`; a tela nasce sem perfil, então responde 403 a todos 🔴 Gustavo (BL-020). Devolve `custo_sem_impostos: true` (custo do Ciclo 1 não tem ICMS, IPI nem ST).
- **Chave:** `MES_API_KEY` (a mesma do INT-05).
- **Banco:** a função `fn_itens_pedido_custo_gravar` ainda grava por `item integer` no Dump Avhub; a migration 047b troca para produto. 🔴 Gustavo aplicar (BL-019). A API já exige a 047b.
- **Pedido manual nunca participa do custo** 📝 (D6 do contrato 008); precisa de marca de origem manual 🔴 ([[Backlog-por-Frente]] BL-026).
- **Do lado do MES:** `lote_custo` existe, mas só a carga inicial grava; o Recebimento não grava custo ([[Modelo-Estoque-e-Custo-do-Lote]]).

```mermaid
sequenceDiagram
    participant REC as Recebimento no MES
    participant MES as api-pcp
    participant JOB as job no api-acos-vital
    participant HUB as HUB tela de custo
    REC->>MES: R4 grava lote_custo origem OC, sem codigo hoje
    MES->>MES: E3 reserva marca custo_alterado_em, sem codigo hoje
    JOB->>MES: GET itens custo a cada 90 s
    MES-->>JOB: 404 hoje, tenta a cada 10 min
    JOB->>JOB: grava itens_pedido_custo por produto depois da 047b
    HUB->>JOB: GET itens_pedido_custo exige custo-itens
```

## INT-07 Torre de Fluxo (contrato 46)

Resumo; o desenho completo (envelope, projeção, telas) está em [[Rastreabilidade-e-Torre-de-Fluxo]].

- **Feed no MES (a criar):** `GET /fluxo/eventos?apos_seq=&limite=` com cursor `seq` monotônico. O MES não tem módulo `fluxo` nem tabela de eventos 🔴 Robert (BL-003).
- **Job no hub** ✅ `item_estado_projetado.job.js`: lê o feed a cada 90 s, página de 1000, janela de 200 `seq` relidos, trava por fonte; **404 do MES avisa e repete a cada 10 min** (`:44-49`, `:150-154`); aplica por `core_fluxo.fn_feed_aplicar`.
- **Rotas do hub** ✅ `item_estado_projetado.route.js`: `GET /fluxo/torre` (`:185`), `/fluxo/sla-etapas` (`:262`), `/fluxo/itens/:id/tempo` (`:281`), `/fluxo/itens/:id` (`:302`). Trilha, tempo e SLA são proxy do MES (a chave fica na API); MES fora do ar devolve 200 com `mes_indisponivel: true`.
- **Chave:** `MES_API_KEY`, `MES_API_URL` (mesma do INT-05).
- **Permissão:** telas `torre-fluxo` e `torre-fluxo-trilha`, concedidas só ao perfil Admin pela 046b ❓ aplicada; demais perfis 🔴 Gustavo/Nathan (BL-021).
- **Front:** o HUB não tem a tela da Torre 🔴 Nathan (BL-022).

```mermaid
sequenceDiagram
    participant MES as api-pcp modulo fluxo a criar
    participant JOB as job no api-acos-vital
    participant PRJ as core_fluxo projecao
    participant BFF as BFF do HUB
    MES->>MES: instrumenta eventos nas transicoes de todos os setores, sem codigo hoje
    JOB->>MES: GET fluxo eventos apos_seq
    MES-->>JOB: 404 hoje
    JOB->>PRJ: fn_feed_aplicar
    BFF->>PRJ: GET fluxo torre via API
    BFF->>MES: trilha e tempo sob demanda pelo proxy da API
    Note over BFF,MES: mes_indisponivel true se o MES nao responde
```

## INT-08 `GET /requisicoes-compra` (003, legado)

`GET /requisicoes-compra` e `GET /itens/status` ficam no mesmo controller do MES, protegidos por `MES_API_KEY` ✅ `integracao-avhub.controller.ts:20`. A primeira rota era o antigo desenho "o hub puxa a requisição". Foi substituída pelo INT-02 e **nenhum job do hub a consome** ✅ (nenhuma referência em `api-acos-vital/src`). Fica como código morto 🔴 Robert decidir remover (BL-032). O comentário "JOB DE POLLING do MES" no `api-acos-vital` está velho (Gustavo, BL-033).

## Lacuna: requisição só do av-hub

Compras cria requisição de necessidade própria no HUB (nó C0, `POST /compras/requisicoes`, número por trigger, permissão `compras.pode_criar`) ✅ `requisicoes_compra.route.js:384`. Ela **não chega ao MES**: sem `id_origem` não há evento do contrato 35, e o MES não tem `RequisicaoCompra`, esperado nem NF para ela; a mercadoria só entra no Estoque por carga inicial 🔴. Opções: (a) gerar evento também para requisição sem `id_origem` e o MES criar o esperado a partir da OC (INT-04); (b) o Recebimento aceitar entrada avulsa contra NF. Decisão 🟡 proposta: (a) com (INT-04) como caminho único. Dono: Nathan decide, Robert implementa, Gustavo ajusta o evento. Backlog BL-006 e BL-028, pendência [[Pontas-Soltas]] PS-003.

## Outras pontes com o MES

- **MES→Omie:** o MES nunca fala com o Omie. A sinalização de faturamento (nó O1, tela 11.1) não existe 🔴 ([[10-Fiscal-Omie]]).
- **Pipeline→av-hub→Omie:** a única escrita no Omie é o envio da OC pela pipeline (`GET /compras/ordens/fila-omie`, `PATCH /compras/ordens/:id/sincronizacao`); não passa pelo MES. Ver [[Omie-Integracao-Estado]] e [[Pipeline-Omie]].
- **Pedido manual** ([[LOG-45-Pedido-de-Venda-Manual]]) não percorre o fluxo do MES.

## O que acontece quando o outro lado cai

| Cai | Efeito | Recuperação |
|---|---|---|
| av-hub (`api-acos-vital`) | Triagem e Destinação do Pedido falham com mensagem; a fila de requisição acumula; o polling de marcos reagenda; o "importado" é reenviado a cada 10 min por 7 dias | automática ao voltar; depois de 7 dias o "importado" não é mais reenviado, sem alerta 🔴 BL-034 |
| MES (`api-pcp`) | O vendedor segue liberando; os jobs de status, custo e Torre falham e repetem (90 s; 10 min em 404); o HUB mostra "dado velho" após 10 min | automática ao voltar; cursores não andam em falha |
| Banco do MES vazio ou sem migrations | o `main` do MES parou em 28/08 e o banco de produção não tem as migrations da `develop` | merge `develop`→`main` antes do piloto 📝 ([[Riscos]], RS-002) |

## O que falta desenvolver

| Item | Dono | Nós | Backlog |
|---|---|---|---|
| Job do MES que lê a referência da OC com valores | Robert | R0 R1 R4 | BL-001 |
| `GET /itens/custo` e custo no recebimento | Robert | E3 R4 | BL-004, BL-005 |
| Módulo `fluxo` e feed `GET /fluxo/eventos` | Robert | todos | BL-003 |
| Requisição só do av-hub chegar ao MES | Robert + Gustavo | C0 R0 | BL-006 |
| Etapa de compra mais fina no 005 | Robert | C1 a C5 | BL-009 |
| Chave do MES com escopo mínimo | Gustavo | — | BL-018 |
| Aplicar 047b e conceder `torre-fluxo`, `custo-itens` | Gustavo | — | BL-019 a BL-021 |
| Tela da Torre e tela de custo no HUB | Nathan | — | BL-022, BL-023 |

Lista completa: [[Backlog-por-Frente]].

## Pendências

- Quem marca a requisição como atendida no fluxo do MES: hoje `resumirRequisicao` fecha por OC e recebimento; confirmar regra com o Robert ([[Pontas-Soltas]] PS-011).
- Teste ponta a ponta do cancelamento de requisição (marcos do 35) ❓ Robert (PS-012).
- Retentativa do `importado` depois de 7 dias ❓ (PS-013).
