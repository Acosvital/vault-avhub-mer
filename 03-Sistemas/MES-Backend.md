---
tags: [sistemas, mes, api-pcp, nestjs, backend]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Robert
fontes: [api-pcp 579a625 (develop), Dump MES (Esqueleto).sql de 14/10, v1 App-PCP-Backend-Producao, App-PCP-Visao-Geral, MES-Arquitetura-Decisoes]
---

# MES Backend (`api-pcp`)

API NestJS do MES: pedidos liberados, produção por setor, Estoque, circuito de compra (lado MES), Recebimento, Qualidade e Expedição. Dono: Robert. Stack: NestJS 11, Prisma 7 com adaptador `pg`, `class-validator`, JWT + `bcrypt`, Swagger/Scalar em `/docs` (✅ `api-pcp/package.json:19-47`, `src/main.ts:56-60`). Banco: [[Banco-MES]]. Telas que a consomem: [[MES-Front]]. Permissões: [[RBAC-e-Permissoes]]. Integração com o av-hub: [[Integracao-AvHub-MES]]. Selos: [[Regras-do-Vault]].

## Como o app sobe

| Item | Valor | Fonte |
|---|---|---|
| Entrada | `NestFactory.create(AppModule)`, `ValidationPipe({ whitelist: true, transform: true })` | ✅ `src/main.ts:96-97` |
| Porta | `PORT` (padrão 3000) | ✅ `src/main.ts:170` |
| Guards globais | `JwtAuthGuard` depois `PermissionsGuard` (APP_GUARD, negam por padrão; só `@Public()` escapa do JWT) | ✅ `src/app.module.ts:94-98` |
| Filtro global | `PrismaExceptionFilter` traduz P2002/P2003/P2039/P2025 em HTTP amigável | ✅ `src/app.module.ts:88` |
| Saúde | `GET /health` público (`@Public()`) | ✅ `src/app.controller.ts:11-12` |
| Docs | `/docs` (Scalar) e `/api-docs-json` com Basic Auth `DOCS_USER`/`DOCS_PASSWORD`; sem senha em produção responde 404 | ✅ `src/main.ts:56-83` |
| Migrations | 55 pastas em `prisma/migrations` (de `20260818164425_init` a `20261014120000_compras_ccp`); schema em 7 arquivos `prisma/models/*.prisma` | ✅ `api-pcp/prisma/` |

192 rotas em 33 módulos (contagem dos decorators `@Get/@Post/@Put/@Patch/@Delete` dos controllers, 14/10). A tabela rota a rota está na seção seguinte.

## Módulos (`src/app.module.ts:36-72`)

| Módulo | Pasta | O que faz | Nós do 0b |
|---|---|---|---|
| Auth | `auth/` | login por usuário/senha, login Azure (via BFF), menu, setores permitidos | todos |
| RBAC | `rbac/{perfis,telas,usuarios-perfis}` | perfis, telas, permissões em lote, setores e depósitos por perfil | todos |
| Usuários, Auditoria | `usuarios/`, `auditoria/` | cadastro de usuário, log de login e de acesso | — |
| Cadastros de produção | `setores/`, `fabricas/` (UI "Destinos"), `maquinas/`, `operadores/`, `roteiros/`, `roteiro-item/` | cadastro de setor (tipos em [[Banco-MES]]), destino FABRICACAO/REVENDA, máquinas, operadores, roteiro | P2, F1 |
| Pedidos | `pedidos/` | Triagem (`/pedidos/carteira`), Destinação (`POST /pedidos/completo/lote`), consulta ao Omie, relatório/PDF, soft delete | P1, P2 |
| Itens e parciais | `itens-pedido/`, `itens-parciais/`, `historico-itens-parciais/`, `item-parcial-anexos/`, `item-parcial-observacoes/` | ciclo de vida da parcial: receber, iniciar, mover, concluir, pausar, reprovar, retrabalho, split, devolver, atender estoque | E3, E4, F1, Q7 |
| Estoque | `estoque/` (`estoque.controller` = depósitos, `materiais/`, `operacao/`, `etiquetas/`, `alertas/`, `produtos-avhub/`) | depósitos e localizações, materiais, saldo, lotes, movimentos, reservas, etiqueta, alertas | E1, E3, E5 |
| Compras (lado MES) | `compras/` | requisição de compra do PCP, Compras · CCP (esperados, chegada, liberação), Recebimento (conferência, recontagem, decisão) | P3, C5, R0 a R6 |
| Qualidade | `qualidade/` | inspeção de entrada por lote (aprovar, reprovar, RNC) | Q1 a Q4 |
| Expedição | `entregas/`, `pedido-embalagens/`, `pedido-embalagem-pallets/`, `pedido-anexos/` | entrega, embalagem, paletes, anexos (canhoto, NF) | X1, X4 |
| Divergências | `divergencias/` | divergência de produção (abrir, analisar, resolver) | R6 (produção) |
| Integração av-hub | `integracao-avhub/` | rotas de serviço para o av-hub (`/requisicoes-compra`, `/itens/status`), envio da requisição (LOG-34), leitura dos marcos (LOG-35) | P3, C1 a C5 |
| Painéis | `dashboard/`, `relatorios/`, `pedidos-excluidos/` | início, TV, relatórios de tempo por setor e de compras, pedidos excluídos | — |

## Rotas por módulo e permissão

`telaSlug, ação` vem do `@RequirePermission` (ver [[RBAC-e-Permissoes]]). Todas exigem Bearer JWT, exceto as marcadas `público` ou `chave`. A lista inteira foi extraída dos controllers de `api-pcp/src` em 14/10 ✅.

### Auth, Auditoria, Saúde

| Rota | Permissão | Código |
|---|---|---|
| `GET /health` | público | ✅ `app.controller.ts:12` |
| `POST /auth/login` | público | ✅ `auth.controller.ts:21` |
| `POST /auth/azure` | `x-api-key` = `MES_INTERNAL_API_KEY` (só o BFF do app-pcp) | ✅ `auth.controller.ts:31`, `guards/api-key.guard.ts:15` |
| `GET /auth/me`, `/auth/menu`, `/auth/setores-permitidos` | só JWT | ✅ `auth.controller.ts:38-60` |
| `GET /auth/dashboard-check` | `dashboard`, visualizar | ✅ `auth.controller.ts:70` |
| `GET /auditoria/login`, `/auditoria/acesso` | `usuarios`, visualizar | ✅ `auditoria.controller.ts:18,24` |

### Pedidos (Triagem e Destinação) — P1, P2

| Rota | Permissão | Código |
|---|---|---|
| `GET /pedidos/carteira` | `carteira`, visualizar | ✅ `pedidos.controller.ts:102` |
| `POST /pedidos` | `ordens-producao`, criar | ✅ `:50` |
| `POST /pedidos/completo/lote` | `ordens-producao`, criar | ✅ `:58` |
| `GET /pedidos/consulta-omie/:numeroPedido`, `/unidades`, `/setor-estoque-fixo`, `/itens-existentes/:pedidoVenda` | `ordens-producao`, criar | ✅ `:70-112` |
| `GET /pedidos`, `/pedidos/:id`, `/:id/relatorio`, `/:id/imprimir` | `ordens-producao`, visualizar | ✅ `:121-141` |
| `PATCH /pedidos/:id` | `ordens-producao`, editar | ✅ `:152` |
| `DELETE /pedidos/:id` | `ordens-producao`, deletar (soft delete, grava em `pedidos_excluidos`) | ✅ `:162` |
| `GET /pedidos-excluidos`, `/pedidos-excluidos/:id` | `pedidos-excluidos`, visualizar | ✅ `pedidos-excluidos.controller.ts:22,28` |
| `/itens-pedido` (POST, GET, GET `:id`, GET `:id/rastreio`, PATCH `:id`, PATCH `:id/desativar`, DELETE `:id`) | `ordens-producao` (criar/editar → editar; ler → visualizar; DELETE → deletar) | ✅ `itens-pedido.controller.ts:33-75` |
| `/pedido-anexos`, `/pedido-embalagens`, `/pedido-embalagem-pallets` (CRUD) | `ordens-producao` (editar/visualizar/deletar) | ✅ controllers respectivos |
| `/roteiro-item` (CRUD) | `ordens-producao` (editar/visualizar) | ✅ `roteiro-item.controller.ts` |
| `GET /historico-itens-parciais`, `/:id` | `ordens-producao`, visualizar | ✅ `historico-itens-parciais.controller.ts:17,23` |

### Parciais (fila de setor) — E3, E4, F1, Q7, X1

Todas com `movimentacoes`, que no guard vale "qualquer tela de fila de setor" (`atendimento`, `requisicoes`, `pedidos-compra`, `logistica-entrada`, `expedicao`, `inspecao-saida`) ✅ `common/constants/telas-fila-setor.constants.ts:7-19`, `auth/guards/permissions.guard.ts:56-58`. Além disso o service confere o `PerfilSetor.podeAtuar` do setor atual (`PerfisService.ensurePodeAtuar`).

| Rota | Ação | Código |
|---|---|---|
| `GET /itens-parciais`, `/contagem-por-setor`, `/:id`, `/:id/setores-percorridos` | visualizar | ✅ `itens-parciais.controller.ts:57,67,94,143` |
| `POST /itens-parciais/lote/:acao` | editar | ✅ `:79` |
| `PATCH /:id/receber`, `/iniciar`, `/mover`, `/concluir`, `/pallets`, `/pausar`, `/reprovar`, `/resolver`, `/retrabalho`, `/retomar`, `/desfazer-recebimento`, `/consolidar`, `/atender-estoque` | editar | ✅ `:100-297` |
| `POST /:id/split`, `/:id/devolver` | editar | ✅ `:249,259` |
| `PATCH /:id/cancelar` | `ordens-producao`, deletar | ✅ `:275` |
| `/item-parcial-anexos`, `/item-parcial-observacoes` (CRUD) | `movimentacoes` editar/visualizar | ✅ controllers respectivos |
| `/divergencias` (POST, GET, GET `:id`, PATCH `:id`, PATCH `:id/resolver`) | `movimentacoes` | ✅ `divergencias.controller.ts:32-56` |
| `POST /entregas`, `GET /entregas`, `GET /entregas/:id` | `movimentacoes` editar/visualizar | ✅ `entregas.controller.ts:35-47` |

### Compras (lado MES) e Recebimento — P3, C5, R0 a R6

| Rota | Permissão | Código |
|---|---|---|
| `GET /compras/requisicoes` | `movimentacoes`, visualizar | ✅ `compras.controller.ts:31` |
| `GET /compras/requisicoes/produtos-avhub` | `movimentacoes`, editar | ✅ `:40` |
| `GET /compras/requisicoes/esperados` | `movimentacoes`, visualizar | ✅ `:48` |
| `POST /compras/requisicoes/sincronizar` | `movimentacoes`, visualizar | ✅ `:57` |
| `GET /compras/requisicoes/:id/eventos`, `/:id` | `movimentacoes`, visualizar | ✅ `:64,70` |
| `POST /compras/requisicoes` | `movimentacoes`, editar | ✅ `:76` |
| `POST /compras/requisicoes/:id/cancelar` | `movimentacoes`, editar | ✅ `:84` |
| `POST /compras/requisicoes/:id/chegada` | `movimentacoes`, editar; o service exige `pode_atuar` no setor Recebimento e NF (número ou chave) | ✅ `:96`, `compras.service.ts:356-401` |
| `POST /compras/requisicoes/:id/liberar-recebimento` | `movimentacoes`, editar; o service exige `compras-liberar` editar | ✅ `:108`, `compras.service.ts:404-445` |
| `GET /compras/recebimentos`, `/:id` | `movimentacoes`, visualizar | ✅ `recebimento.controller.ts:27,40` |
| `GET /compras/recebimentos/decisoes` | `decisoes-pcp`, visualizar | ✅ `:34` |
| `POST /compras/recebimentos`, `/:id/recontar` | `movimentacoes`, editar | ✅ `:46,52` |
| `POST /compras/recebimentos/:id/decidir` | `decisoes-pcp`, editar | ✅ `:62` |
| `GET /relatorios/compras`, `/relatorios/tempos-por-setor` | `relatorios`, visualizar | ✅ `relatorios.controller.ts:19,26` |

A rota `PATCH /compras/requisicoes/:id/compra` ("Registrar compra" manual) **não existe mais** ✅ (nenhuma ocorrência em `compras.controller.ts`).

### Estoque — E1, E3, E5

| Rota | Permissão | Código |
|---|---|---|
| `GET /estoque/saldo` | `saldo`, visualizar (inclui `custoUnitario` só com `estoque-custo` visualizar) | ✅ `estoque-operacao.controller.ts:40`, `estoque-operacao.service.ts:62-105` |
| `GET /estoque/saldo/disponivel-parcial/:idItemParcial` | `movimentacoes`, visualizar | ✅ `:46` |
| `GET /estoque/lotes/:id` | `saldo`, visualizar | ✅ `:73` |
| `GET /estoque/lotes/:id/etiqueta` | `saldo`, visualizar | ✅ `etiqueta.controller.ts:21` |
| `POST /estoque/lotes/carga-inicial` | `movimentacao`, criar (custo opcional: `estoque-custo` editar) | ✅ `:67`, `service:398-475` |
| `GET /estoque/unidades`, `/estoque/produtos-avhub` | `movimentacao`, criar | ✅ `:55,61` |
| `GET /estoque/movimentos` | `movimentacao`, visualizar | ✅ `:79` |
| `POST /estoque/movimentos` (TRANSFERENCIA ou AJUSTE) | `movimentacao`, criar | ✅ `:85` |
| `GET /estoque/reservas`; `PATCH /estoque/reservas/:id/liberar` | `reservas`, visualizar/editar | ✅ `:91,97` |
| `/estoque/depositos` (POST, GET, GET `unidades`, GET/PATCH/DELETE `:id`), `/:id/localizacoes` (POST, PATCH, DELETE) | `depositos` criar/visualizar/editar/deletar | ✅ `estoque.controller.ts:34-90` |
| `GET/PATCH /estoque/materiais`, `/:id` | `materiais` visualizar/editar | ✅ `materiais.controller.ts:32-44` |
| `GET /estoque/alertas/estoque-minimo`, `/rnc-pendentes` | `painel-estoque`, visualizar | ✅ `alertas.controller.ts:19,25` |

Observação: o controller usa o slug `movimentacao` (singular, ações do Estoque) e `movimentacoes` (plural, fila de setor). São duas telas diferentes em `telas` ✅ `estoque-operacao.controller.ts:55-85` x `itens-parciais.controller.ts:57`. Conferir se as duas existem em produção ❓.

### Qualidade — Q1 a Q4

| Rota | Permissão | Código |
|---|---|---|
| `GET /qualidade/lotes` | `inspecao-entrada`, visualizar | ✅ `qualidade.controller.ts:21` |
| `POST /qualidade/lotes/:id/aprovar`, `/:id/reprovar` | `inspecao-entrada`, editar | ✅ `:27,33` |

A Inspeção de saída (Q7) não tem controller próprio: é uma fila de setor tipo `QUALIDADE` (`/itens-parciais/:id/reprovar`).

### Cadastros de produção, RBAC, Painéis

`/fabricas`, `/maquinas`, `/operadores`, `/roteiros`, `/setores`, `/usuarios`, `/perfis`, `/telas`, `/usuarios-perfis`, `/dashboard`, `/dashboard/tv`: CRUD por tela com o mesmo slug do recurso (`fabricas`, `maquinas`, `operadores`, `roteiros`, `setores`, `usuarios`, `perfis`, `telas`, `dashboard`). Exceções ✅:
- `GET /setores`, `/setores/:id`, `/setores/:id/painel` sem `@RequirePermission` (só JWT) — `setores.controller.ts:42-53`.
- `PATCH /usuarios/:id/senha` sem `@RequirePermission` (a service decide) — `usuarios.controller.ts:63`.
- `POST /perfis/:id/permissoes/bulk`, `/setores/bulk`, `/depositos/bulk`, `/usuarios`: `perfis`, editar — `perfis.controller.ts:66-97`.
- `GET /usuarios-perfis`: `usuarios-perfis`, visualizar — `usuarios-perfis.controller.ts:17`.

### Rotas de serviço para o av-hub (sem JWT)

| Rota | Auth | Uso | Código |
|---|---|---|---|
| `GET /requisicoes-compra` | `x-api-key` = `MES_API_KEY` (`AvhubApiKeyGuard`, fail-closed) | contrato 003 (legado, sem consumidor) | ✅ `integracao-avhub.controller.ts:20`, `avhub-api-key.guard.ts:14` |
| `GET /itens/status` | idem | contratos 005/006: job de 90 s do av-hub | ✅ `:26`; `integracao-avhub.service.ts:114-165` |

**Não existem no MES** ✅ (grep em `api-pcp/src` sem ocorrência de `fluxo` nem `itens/custo`): `GET /fluxo/eventos`, `GET /fluxo/itens/:id/(tempo)`, `GET /fluxo/sla-etapas` (Torre de Fluxo, LOG-46) e `GET /itens/custo` (API-008/LOG-47). Os jobs do av-hub recebem 404 e esperam 10 min ([[AV-Hub-API]], [[Rastreabilidade-e-Torre-de-Fluxo]]). Dono: Robert 🔴.

## Serviços que fazem a regra

| Serviço (arquivo) | Responsabilidade | Observações |
|---|---|---|
| `ItensParciaisService` (`itens-parciais/itens-parciais.service.ts`, 1775 linhas) | máquina de estados da parcial; `atenderEstoque` (`:607`) reserva lotes e divide a parcial; `receber` consome a reserva quando a Expedição recebe (`:279`) | ver [[Modelo-Estoque-e-Custo-do-Lote]] |
| `PedidosService` (`pedidos/pedidos.service.ts`) | cria a Destinação, confirma importação no av-hub, reenvia `importado` a cada 10 min (`:63-83`) | exige `PEDIDO_NAO_LIBERADO` do av-hub (`:245-248`) |
| `PedidosCarteiraService` + `omie-integracao.ts` | Triagem lê `GET /pedidos_liberados` do av-hub | `omie-integracao.ts:331-425` |
| `EstoqueOperacaoService` + `estoque-operacao.helpers.ts` | saldo, lote, movimento, reserva, `consumirReservasDaParcial` (`helpers:208`), `estornarConsumosDaParcial`, `copiarCustoParaFilho` (`:432`) | |
| `ComprasService` (`compras/compras.service.ts`, 674 linhas) | `requisitar` (`:135`), `cancelar` (`:228`), `esperados` (`:305`), `registrarChegada` (`:356`), `liberarRecebimento` (`:404`), `registrarRecebimento` (`:472`, chamado pelo Recebimento) | |
| `circuito-compra.ts` | setores fixos do circuito (`requisicoes-compra`, `compras`, `logistica-entrada`, `qualidade-entrada`, Estoque); `moverParcial`, `splitParaDestino`, `devolverAoEstoqueParciaisProntas` (`:166`), `devolverAComprasParteReprovada` (`:256`) | `circuito-compra.ts:19-25` |
| `marcos-compra.ts` | calcula a linha do tempo "Compras · CCP" por requisição | `:70`, `:131` |
| `RecebimentoService` (`compras/recebimento.service.ts`) | `conferir` (`:135`), `recontar` (`:249`), `decidir` (`:331`); tolerância de peso por material (padrão 5%) | `:390-395`; coluna `materiais.tolerancia_peso` (dump `:871`) |
| `QualidadeService` | aprova (lote → `LIBERADO`, devolve parciais prontas ao Estoque) e reprova (cisão do lote, RNC, devolve a parte reprovada a Compras) | `qualidade.service.ts:83-102` |
| `EntregasService` | registra a entrega, decrementa `quantidadePendente`, consome reserva por garantia, fecha o pedido (`ENTREGUE`) | `entregas.service.ts:25-135` |
| `EnvioAvhubService` | fila de saída da requisição (LOG-34) | ver Jobs |
| `EventosAvhubService` + `requisicao-avhub.eventos.ts` | leitura dos marcos (LOG-35) e reação por tipo | ver Jobs |
| `IntegracaoAvhubService` | responde `/requisicoes-compra` e `/itens/status`; `etapaDoItem` gera as 11 etapas | `integracao-avhub.service.ts:167-192` |
| `AuthService` | login com `bcrypt`, rate limit de 5 falhas por usuário e 20 por IP em 15 min, token por `JWT_EXPIRES_IN` (padrão `8h`) | `auth.service.ts:8-15`, `auth.module.ts:19` |
| `PerfisService` | permissão por tela (OR entre perfis), `ensurePodeAtuar` por setor, `ensurePodeAtuarDepositos`, `depositosVisiveis`, `temPermissao` | `perfis.service.ts:349-364` |

## Jobs e timers (todos dentro do processo da API, sem `@nestjs/schedule`)

Não há `@Cron`; os três timers usam `setInterval` com `unref()` ✅ (grep em `src`).

| Job | Arquivo:linha | Intervalo | Faz | Variável |
|---|---|---|---|---|
| Envio da requisição ao av-hub (LOG-34) | `envio-avhub.service.ts:44-53` | 60 s (`0` desliga); primeira rodada 5 s depois da subida; backoff 1, 2, 5, 10, 30, 60 min (`:23`) | `PUT {API_URL}/compras/requisicoes/origem/{id_origem}`, lote de 100, timeout 15 s | `AVHUB_ENVIO_INTERVALO_SEG` |
| Leitura dos marcos (LOG-35) | `eventos-avhub.service.ts:58-66` | 5 min (`0` desliga); primeira rodada 10 s depois; sob demanda via `POST /compras/requisicoes/sincronizar`, pulada se a última leitura boa tem menos de 30 s (`:25,81-90`) | `GET {API_URL}/compras/requisicoes/eventos`, página de 200, até 50 páginas, relê 2 min para trás; cursor `integracao_avhub_cursores.chave = 'requisicoes-eventos'` | `AVHUB_EVENTOS_INTERVALO_MIN` |
| Reenvio de `importado` (LOG-26) | `pedidos.service.ts:81-83` | 10 min (`0` desliga) | `POST /pedidos_liberados/:numero/importado` para pedidos dos últimos 7 dias, 20 por rodada | `AVHUB_REENVIO_IMPORTADO_MIN` |

Reação por marco (`requisicao-avhub.eventos.ts:234-246`): `requisicao_recebida`, `requisicao_reaberta`, `oc_cancelada` → `AGUARDANDO_COMPRADOR`; `em_cotacao`, `oc_removida` → `EM_COTACAO`; `oc_criada`, `oc_enviada_aprovacao` → `EM_APROVACAO`; `oc_aprovada` → `COM_FORNECEDOR`; `despachada` → `EM_TRANSITO`; `requisicao_cancelada` → `CANCELADA` ✅. `fornecedor_confirmou`, `previsao_alterada`, `ocorrencia` e `oc_no_omie` só atualizam campos da situação (previsão, ocorrência aberta) sem mudar a etapa ❓ (conferir ramo a ramo em `:107-230`).

## Variáveis de ambiente (conferidas no código)

| Variável | Uso | Padrão | Código |
|---|---|---|---|
| `DATABASE_URL` | conexão Prisma (adaptador `pg`) | — | ✅ `prisma/prisma.service.ts:9` |
| `PORT` | porta HTTP | 3000 | ✅ `main.ts:170` |
| `NODE_ENV` | produção esconde `/docs` sem senha | — | ✅ `main.ts:59` |
| `JWT_SECRET` | assina e valida o JWT | — | ✅ `auth.module.ts:15`, `strategies/jwt.strategy.ts:15` |
| `JWT_EXPIRES_IN` | validade do token | `8h` | ✅ `auth.module.ts:19` |
| `MES_INTERNAL_API_KEY` | chave do BFF app-pcp para `POST /auth/azure` | — (sem ela a rota fica fechada) | ✅ `auth/guards/api-key.guard.ts:15` |
| `MES_API_KEY` | chave que o av-hub usa para ler `/itens/status` e `/requisicoes-compra` | — (sem ela fecha) | ✅ `integracao-avhub/avhub-api-key.guard.ts:14` |
| `API_URL` | base do av-hub (`api-acos-vital`) | `https://api.acosvital.com.br` | ✅ `envio-avhub.service.ts:17`, `eventos-avhub.service.ts:23`, `omie-integracao.ts:10`, `produtos-avhub.client.ts:24` |
| `API_KEY` | chave de leitura/escrita que o MES usa no av-hub (marcos, Triagem, Destinação, produtos, unidades) | — | ✅ `eventos-avhub.service.ts:192`, `omie-integracao.ts:149,241,349,411`, `produtos-avhub.client.ts:60` |
| `AVHUB_MES_INTEGRACAO_KEY` | chave só do PUT da requisição (um valor de `MES_INTEGRACAO_KEYS` do av-hub, mínimo 32 caracteres) | — (sem ela a fila espera) | ✅ `envio-avhub.service.ts:98` |
| `AVHUB_ENVIO_INTERVALO_SEG`, `AVHUB_EVENTOS_INTERVALO_MIN`, `AVHUB_REENVIO_IMPORTADO_MIN` | intervalos dos três timers | 60, 5, 10 | ✅ acima |
| `DOCS_USER`, `DOCS_PASSWORD`, `DOCS_ENABLED` | Basic Auth do `/docs` e liga/desliga | `docs`, vazio, ligado | ✅ `main.ts:56-58` |

As três variáveis `AVHUB_*_INTERVALO_*`/`_MIN` são regra em ambiente. A regra do Nathan ("nenhuma regra em variável de ambiente para jobs novos") vale para os jobs do av-hub; no MES esses três timers são anteriores à regra 🟡. Chaves e escopos: [[Chaves-e-Autenticacao]].

## O que o MES chama no av-hub

`GET /pedidos_liberados`, `GET /pedidos_liberados/:numero/itens`, `POST /pedidos_liberados/:numero/importado` (LOG-26); `PUT /compras/requisicoes/origem/:id` (LOG-34); `GET /compras/requisicoes/eventos` (LOG-35); `GET /produtos`, `GET /produtos/:id` (snapshot do material); `GET /unidades` (nome da filial, cache de 10 min, `estoque-operacao.service.ts:36`) ✅. **Nunca chama** `GET /ordens-compra/referencia` (API-004/007): o MES não consome a referência da OC 🔴.

## O que falta ou diverge (resumo; detalhe em [[Pontas-Soltas]] e [[Diferencas-Codigo-x-Banco]])

- 🔴 Módulo `fluxo` (Torre) e `GET /itens/custo` não existem.
- 🔴 Fabricado aprovado não vira lote (`OrigemLote` só tem `RECEBIMENTO` e `CARGA_INICIAL`, `lotes` dump `:155-158`).
- 🔴 `lote_custo` só é gravado na carga inicial e na cisão do lote (`estoque-operacao.service.ts:440`, `helpers.ts:434`); o custo da OC nunca é gravado (`OrigemCusto` `OC` e `MANUAL` sem escritor).
- 🔴 Não há documento de retirada; a baixa de saldo acontece quando a Embalagem/Expedição recebe a parcial (`itens-parciais.service.ts:279`) e de novo, por garantia, na entrega (`entregas.service.ts:88`).
- 🟡 Tabela `fornecedores` (projeção de `core.parceiros`) existe e nenhum código a popula nem lê.
- 🟡 `GET /requisicoes-compra` (contrato 003) sem consumidor.
