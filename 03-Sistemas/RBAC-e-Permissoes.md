---
tags: [sistemas, rbac, permissoes, mes, av-hub, seguranca]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Gustavo (DBA)
fontes: [api-pcp 579a625, app-pcp 1fca8d3, api-acos-vital f322dcd, HUB b55ac55, Dump MES e Dump Avhub de 14/10, v1 AV-Hub-RBAC, Achado-Duplicacao-RBAC]
---

# RBAC e permissões

**Em uma frase:** é o controle de quem pode ver e fazer o quê. Existem **dois sistemas de permissão separados**, um no MES e outro no av-hub, sem sincronização entre eles. Dono: Gustavo (DBA).

## Quem usa e para quê

- **Administrador:** cadastra usuários e perfis.
- **Qualquer usuário:** só vê as telas e faz as ações que o perfil permite.
- **Sistemas entre si:** usam chaves de serviço ([[Chaves-e-Autenticacao]]).
- **Quem decide fluxo (Nathan, Gustavo):** monta os perfis, como a Gerência de Compras.

## Como se encaixa no fluxo

- **MES:** permissão por tela e por setor. O Estoque ainda separa por depósito.
- **av-hub:** permissão por tela e por rota. A liberação, a Torre de Fluxo e o custo por item têm a sua.
- **Compras:** a aprovação da OC acima de R$ 30 mil depende da permissão "aprovar" do av-hub (N14-21).
- **Comercial:** a API Comercial usa as permissões do av-hub ([[API-Comercial]]).
- Um perfil do MES não existe no av-hub e vice-versa. O usuário tem um cadastro em cada um ([[Schemas-Postgres]]).

## Regras que valem

- Rota sem mapa de permissão é negada por padrão.
- Basta **um** perfil do usuário permitir.
- No MES, ter a tela não basta: é preciso "pode atuar" no setor ou no depósito.
- No av-hub, o vendedor só vê pedidos e notas dos vendedores do seu escopo (`proprios`, `vinculados` ou `todos`).
- O que o usuário faz é sempre registrado em nome do token de login, nunca de um campo enviado.
- O menu da tela é só apresentação. Quem nega é o servidor.
- Dois acessos especiais no MES: o custo do lote e a liberação de recebimento sem OC.
- A tela de custo por item do av-hub nasce sem permissão para nenhum perfil (decisão de 13/10).

## O que já existe e o que falta

- ✅ Regras do MES e do av-hub, com checagem na tela, no BFF e na API.
- ✅ Aprovação da OC com uma permissão só, sem segunda alçada nem Diretoria. 🟡 Endurece depois da conversa com Compras.
- 🟡 A Gerência de Compras ainda não tem usuários vinculados (tarefa de cadastro, Nathan e Gustavo).
- 🟡 Perfil CCP no MES (N14-24): hoje é só leitura, sem perfil próprio. Criar é tarefa de cadastro.
- 🟡 Alinhar os perfis das duas permissões de custo: `estoque-custo` (MES) e `custo-itens` (av-hub).
- 🔴 Permissão do documento de retirada (`E6`): a tela e a rota também não existem.
- 🔴 Chave do MES com acesso mínimo ao av-hub (hoje lê e escreve). Gustavo.
- ❓ As linhas de `auth.rotas_telas` das rotas novas e o que existe em produção. Gustavo.
- ❓ O cadastro das telas `movimentacao` e `movimentacoes` e o do `compras-liberar` (a seed não está nos repositórios).

## Detalhe técnico

São **dois RBACs separados**, em dois bancos, sem sincronização: o do MES (`api-pcp`, schema `public`) e o do av-hub (`api-acos-vital`, schema `auth`). Um perfil do MES não existe no av-hub e vice-versa; o usuário tem um cadastro em cada um. Isso não é contradição: ver [[Schemas-Postgres]]. Chaves de serviço entre sistemas: [[Chaves-e-Autenticacao]]. Selos: [[Regras-do-Vault]].

### 1. RBAC do MES

#### Modelo ✅ ([[Banco-MES]])

| Tabela | Chave | Colunas que decidem |
|---|---|---|
| `telas` | `slug` único | `nome`, `ordem`, `ativo`, `id_parent` (árvore do menu) |
| `perfis` | `nome` único | — |
| `permissoes` | `(id_perfil, id_tela)` único | `pode_visualizar`, `pode_criar`, `pode_editar`, `pode_deletar` (4 flags, default `false`) |
| `usuarios_perfis` | `(id_usuario, id_perfil)` | um usuário tem vários perfis |
| `perfil_setores` | `(id_perfil, id_setor)` | `pode_visualizar`, `pode_atuar` |
| `perfil_depositos` | `(id_perfil, id_deposito)` | `pode_visualizar`, `pode_atuar` |

Dump MES `:1046-1113`, `:1396-1440` ✅.

#### Regras no código

- **Guard global.** `JwtAuthGuard` e depois `PermissionsGuard` são `APP_GUARD`. Rota sem `@Public()` exige Bearer; rota com `@RequirePermission(slug, ação)` confere a permissão ✅ `api-pcp/src/app.module.ts:94-98`, `auth/guards/permissions.guard.ts:33-80`. Rota **sem** `@RequirePermission` só exige JWT (ex.: `GET /setores`, `PATCH /usuarios/:id/senha`).
- **OR entre perfis.** Basta **um** perfil do usuário permitir ✅ `permissions.guard.ts:56-70`; mesma regra em `PerfisService.temPermissao` ✅ `rbac/perfis/perfis.service.ts:349-364`.
- **`movimentacoes` é virtual.** Vale "qualquer tela de fila de setor": `movimentacoes`, `atendimento`, `requisicoes`, `pedidos-compra`, `logistica-entrada`, `expedicao`, `inspecao-saida` ✅ `common/constants/telas-fila-setor.constants.ts:7-19`. É o `@RequirePermission('movimentacoes', …)` das rotas de parcial, compras, entregas e divergências.
- **Limite real por setor.** Mesmo com a tela, o service chama `PerfisService.ensurePodeAtuar(userId, idSetor)`: só age quem tem `perfil_setores.pode_atuar` no setor atual da parcial ✅ `perfis.service.ts:278`; `compras.service.ts:356-401` exige `pode_atuar` no **Recebimento** para registrar a chegada.
- **Limite real por depósito.** `ensurePodeAtuarDepositos` (carga inicial, movimento, reserva) e `depositosVisiveis` (Saldo só mostra os depósitos que o perfil vê) ✅ `estoque-operacao.service.ts:61-65,401`.
- **Permissão que muda o conteúdo.** `temPermissao(userId, slug, campo)` decide o que vai na resposta, não a rota: `estoque-custo` e `compras-liberar` ✅ abaixo.
- **Front.** O menu da sessão (`GET /auth/menu`) leva as 4 flags por tela; `usePermission()` usa o último segmento da URL como slug ✅ `app-pcp/hooks/usePermission.ts:8-17`, `lib/permissions.ts:3`. O front esconde botões; quem garante é a API.

#### Telas só de permissão (sem página nem menu) ✅

| Slug | Flag | Efeito | Código |
|---|---|---|---|
| `estoque-custo` | `pode_visualizar` | `GET /estoque/saldo` e `GET /estoque/lotes/:id` incluem o custo do lote (`custoUnitario`, bloco `custo`) | ✅ `estoque-operacao.service.ts:66,546`; `app-pcp/…/saldo/page.tsx:35` |
| `estoque-custo` | `pode_editar` | `POST /estoque/lotes/carga-inicial` aceita `custoUnitario` (sem a flag, 403 "Sem permissão para informar o custo do lote") | ✅ `estoque-operacao.service.ts:406-411`; `EntradaLoteModal.tsx:36` |
| `compras-liberar` | `pode_editar` | `POST /compras/requisicoes/:id/liberar-recebimento` (rede de segurança: esperados do Recebimento sem OC aprovada, com motivo obrigatório) | ✅ `compras.service.ts:404-409`; `FilaSetor.tsx:304` |

Seeds: `estoque-custo` nasce "default-deny, só o Administrador" ✅ `common/constants/estoque-custo.constants.ts:1-5`; `compras-liberar` entra por `01-base.sql`, que **não está nos repositórios** ❓ Robert. A lista de telas só de permissão: `app-pcp/lib/telasSoPermissao.ts:8`.

#### Slugs do MES (extraídos dos controllers) ✅

| Slug | Quem usa | Ações |
|---|---|---|
| `dashboard` | `/dashboard`, `/auth/dashboard-check` | visualizar |
| `carteira` | Triagem do Pedido | visualizar |
| `ordens-producao` | Destinação, Acompanhamento, itens, anexos, embalagens, paletes, roteiro-item, histórico | criar (Destinação), editar, visualizar, deletar (cancelar parcial, excluir) |
| `pedidos-excluidos` | pedidos excluídos | visualizar |
| `movimentacoes` (virtual) | parciais, entregas, divergências, anexos e observações de parcial, `/compras/requisicoes/*`, `/compras/recebimentos` (ler, conferir, recontar), `/estoque/saldo/disponivel-parcial/:id` | visualizar, editar |
| `atendimento`, `requisicoes`, `pedidos-compra`, `logistica-entrada`, `expedicao`, `inspecao-saida` | telas de módulo (fila de setor) | as quatro flags, via `movimentacoes` |
| `decisoes-pcp` | Divergências de Recebimento | visualizar (lista), editar (decidir) |
| `inspecao-entrada` | Qualidade de entrada | visualizar, editar (aprovar, reprovar) |
| `saldo`, `reservas`, `movimentacao`, `depositos`, `materiais`, `painel-estoque` | Estoque | conforme tabela de rotas em [[MES-Backend]] |
| `fabricas`, `maquinas`, `operadores`, `roteiros`, `setores` | cadastros de produção | criar, editar, visualizar, deletar |
| `usuarios`, `perfis`, `telas`, `usuarios-perfis` | acessos | idem |
| `relatorios` | relatórios | visualizar |
| `estoque-custo`, `compras-liberar` | só permissão | ver acima |

`movimentacao` (singular, ajuste e carga inicial) e `movimentacoes` (plural, fila) são telas distintas ✅ `estoque-operacao.controller.ts:55-85` e `itens-parciais.controller.ts:57`; conferir o cadastro de ambas em produção ❓.

#### Autenticação do MES

- Login por usuário e senha com `bcrypt`; bloqueio por tentativas: 5 por usuário e 20 por IP em 15 min ✅ `auth/auth.service.ts:8-15,218-232`. Token com `JWT_EXPIRES_IN` (padrão `8h`) ✅ `auth.module.ts:19`.
- Azure AD: o app-pcp valida com o Azure e chama `POST /auth/azure` com `x-api-key: MES_INTERNAL_API_KEY`; o MES **resolve** o e-mail para um usuário já cadastrado (não cria conta) ✅ `auth.service.ts:68`, `api-key.guard.ts:15`.
- Auditoria: `auditoria_login` e `auditoria_acesso` ✅ dump `:465-492`.

### 2. RBAC do av-hub

#### Modelo ✅ ([[Banco-AvHub]], schema `auth`)

| Tabela | Papel |
|---|---|
| `auth.telas` | `slug` (único), `nome`, `id_parent`, `ordem`, `ativo` |
| `auth.perfis` | `nome`, `tela_inicial_id`, **`escopo_vendedores`** (`proprios`, `vinculados`, `todos`; padrão `vinculados`) |
| `auth.permissoes` | `(id_perfil, id_tela)` com `pode_visualizar`, `pode_criar`, `pode_editar`, `pode_deletar`, **`pode_aprovar`** |
| `auth.usuarios`, `usuarios_perfis`, `usuarios_unidades` | usuário, vínculo com perfis, unidades do usuário |
| **`auth.rotas_telas`** | mapa **rota → tela + ação**: `metodo`, `rota` (com curingas), `slug_tela`, `acao` (se nula, deriva do método: GET visualizar, POST criar, DELETE deletar, demais editar), `escopo_vendedor`, `ativo`, `origem` |
| `auth.rotas_administrativas` | rotas que uma chave de escrita só abre com token de usuário |
| `auth.chaves_servico` | chaves de serviço no banco (`hash_sha256`, `acesso` leitura/escrita/admin, `exige_usuario`, `expira_em`, `revogada_em`) |
| `auth.ip_regras`, `logs`, `auditoria`, `login_tentativas`, `sessions`, `usuarios_favoritos` | apoio |

#### Como a API decide ✅

1. **Chave de serviço** (`x-api-key`): `API_KEYS` do `.env` (admin), chaves de `auth.chaves_servico`, ou `MES_INTEGRACAO_KEYS` (só `PUT /compras/requisicoes/origem/:id`; qualquer outra rota dá 403 `CHAVE_MES_ROTA_NAO_PERMITIDA`) ✅ `api-acos-vital/src/middlewares/apiKeyAuth.js:1-76`.
2. **Token de usuário** (`Authorization: Bearer`): `identidadeUsuario` valida o token e chama `auth.fn_autorizar(usuario, versão, método, caminho)` ✅ `middlewares/identidadeUsuario.js:40-100`. A função devolve 401 `usuario_invalido` ou `token_revogado`; 403 `rota_sem_mapa` (rota sem linha em `auth.rotas_telas`: **fail-closed**) ou 403 `sem_permissao` (com a lista `exige_uma_de`); 200 com o escopo de vendedores. A permissão é **OR entre perfis** do usuário ✅ dump `fn_autorizar` `:357` (join `usuarios_perfis → perfis → permissoes → telas`).
3. **Identidade passa a ser a do token.** `id_usuario_sessao` na query e os campos `created_by`, `updated_by`, `deleted_by`, `aprovado_por`, `decidido_por`, `cancelado_por` do corpo são **sobrescritos** pelo id do token ✅ `identidadeUsuario.js:29-37`.
4. **Sem token:** chave de `.env` e chave do MES seguem sem identidade (o MES e a pipeline não são usuários). Chave com `exige_usuario` recebe 401 `TOKEN_USUARIO_AUSENTE` ✅ `:63-69`.
5. **Escopo de vendedor** (contrato 40): perfil que não é `todos` só vê pedidos e notas dos vendedores do usuário (`escopoVendedor.js`); **escopo de unidade** (`auth.usuarios_unidades`) e de setor (`escopoUnidade.js`, `escopoSetor.js`) ✅.
6. **BFF.** `requirePermission(slug, ação)` do HUB lê `GET /me/permissoes` (ao vivo, cache 5 s) e responde 401 sem o token do usuário, 503 se `/me/permissoes` falhar e 403 se a tela não estiver em `auth.telas`: o menu do JWT é só apresentação e não autoriza nada ✅ `HUB/lib/api/requirePermission.ts` (`d0ef359`). Por isso o BFF nega **antes** de chegar à API, e a API nega de novo pelo mapa.
7. Rotas fora do mapa de permissão: `ROTAS_SEM_PERMISSAO_DE_TELA` em `utils/acessoConfig.js` ✅.

Dados em `auth.rotas_telas` e `auth.telas`: **o dump é só esqueleto** (sem `COPY`/`INSERT`), então quais linhas existem em produção ❓ Gustavo (`auth.vw_rotas_telas_conferencia` ajuda a conferir).

#### Permissões do av-hub que o fluxo de Atividades usa

| Tela (slug) | Ação | Quem decide | Efeito | Código |
|---|---|---|---|---|
| `liberar-pedidos` | `pode_visualizar`, `pode_editar` | BFF + mapa | lista e libera os próprios pedidos (V2, V3) | ✅ `HUB app/api/liberar-pedidos/[codigoEmpresa]/[numeroPedido]/route.ts:19` |
| `liberacao-equipe` | `pode_visualizar` | BFF | caixa da equipe | ✅ `app/api/liberar-pedidos/route.ts:31-36` |
| **`compras`** | **`pode_criar`** | BFF (`requirePermission('compras','pode_criar')`) e tela | **"Nova requisição"** (`POST /compras/requisicoes`, C0) e **emitir OC** (`POST /compras/ordens`, C4); também o botão "Gerar OC" | ✅ `HUB app/api/compras/requisicoes/route.ts:80`, `app/api/compras/ordens/route.ts:111`, `components/Compras/ComprasRequisicoes.tsx:92,186` |
| `compras` | `pode_editar` | BFF e API | mudar status da requisição (cotação, cancelar com motivo); **reenviar OC ao Omie** | ✅ `app/api/compras/requisicoes/[id]/route.ts:32`, `api-acos-vital …/ordens_compra.route.js:1343` |
| **`compras`** | **`pode_aprovar`** | BFF **e** API (regra fixa `EXIGIR_PODE_APROVAR = true`) | **aprovar e cancelar OC** que excede o limite (R$ 30 mil por padrão; perfil Gerência de Compras); até o limite a OC é liberada sem aprovação (N14-21) | ✅ `HUB app/api/compras/ordens/[id]/route.ts:35`, `ordens_compra.route.js:38-42,1235` |
| `compras` | `pode_visualizar` | BFF | listas, detalhes, catálogos de apoio | ✅ `app/api/compras/**` |
| `followup` | `pode_visualizar`, `pode_editar`, `pode_aprovar` | BFF e API | ler a fila do CCP; gravar confirmação, previsão, despacho, contato, ocorrência; **decidir ocorrência** (precisa também ser o comprador da OC ou admin) | ✅ `HUB app/api/compras/ocorrencias/[id]/route.ts:13`, `api-acos-vital …/ordens_compra_acompanhamento.route.js:154`, `utils/acessoConfig.js` |
| `compradores` | `pode_visualizar`, `pode_editar` | BFF e API | vínculo comprador × funcionário; só quem é comprador vinculado na unidade emite OC (regra fixa, `BLOQUEAR_SEM_COMPRADOR = true`) | ✅ `compradores.route.js:210`, `ordens_compra.route.js:35` |
| **`custo-itens`** | `pode_visualizar` | **API, sempre** (também sem token) | `GET /itens_pedido_custo`; **nasce sem permissão para nenhum perfil** (decisão de 13/10) | ✅ `itens_pedido_custo.route.js:41-48,76-85` |
| **`torre-fluxo`** | visualizar | mapa (migration 046/046b) | `GET /fluxo/torre`, `/fluxo/sla-etapas`, `/fluxo/itens/:id/tempo` | ✅ `item_estado_projetado.route.js:16-25` |
| **`torre-fluxo-trilha`** | visualizar | mapa | `GET /fluxo/itens/:id` (mostra nomes de pessoas); 046b concede só ao perfil de testes do time de TI (nenhum perfil de negócio) | ✅ idem |
| `pcp-pedidos`, `pcp-notas`, `pcp-dashboard` | visualizar (+criar e deletar nas observações) | BFF | portal PCP do av-hub (leitura) | ✅ `HUB app/api/pcp/**` |
| `meus-pedidos`, `pedidos-equipe` | visualizar | BFF | card "Etapa dos itens" | ✅ `HUB lib/api/pedidosVenda.ts` |

#### Slugs do Comercial

`propostas`, `propostas-delegacao`, `propostas-valores`, `custo-item` (singular, ≠ `custo-itens`), `relatorio-gerencial`, `painel-comprador`, `clientes` ✅ `api-comercial/src/domain/permissoes/capacidades.ts:44-52`. A API Comercial lê `GET /me/permissoes` do av-hub e não tem tabela de perfil própria ([[API-Comercial]]).

### 3. Lacunas e decisões abertas

| Item | Estado |
|---|---|
| Aprovação da OC (N14-21, 14/10): acima de R$ 30 mil, Gerente de Compras; até R$ 30 mil, compradores livres; sem Diretoria | ✅ Uma permissão (`compras.pode_aprovar`); até o limite o banco aprova sozinho e acima dele só a Gerência decide ([[AV-Hub-API]]). Não há segunda alçada nem papel Diretoria. 🟡 A regra endurece depois da conversa com Compras. A Gerência de Compras ainda não tem usuários vinculados (tarefa cadastral, Nathan e Gustavo) |
| Perfil CCP no MES (C5) | "Compras · CCP" é só leitura, sem perfil próprio; hoje usa `pedidos-compra` + setor `COMPRAS`. Criar o perfil é tarefa cadastral simples, em breve (Nathan, Gustavo; N14-24) |
| Permissão do documento de retirada (E6) | 🔴 não existe (a tela e a rota também não) |
| Quem vê custo no MES e no av-hub | duas permissões distintas: `estoque-custo` (MES, custo do lote) e `custo-itens` (av-hub, custo do pedido) 🟡 alinhar perfis |
| Chave própria do MES com escopo mínimo para ler o av-hub (hoje `API_KEY` de leitura e escrita) | 🔴 Gustavo ([[Chaves-e-Autenticacao]]) |
| Linhas de `auth.rotas_telas` das rotas novas (`/fluxo/*`, `/itens_pedido_custo`, `/compras/requisicoes/eventos`) | ❓ Gustavo |
| Duplicação de RBAC entre MES e av-hub (achado antigo) | por decisão cada sistema mantém o seu; o av-hub é a fonte dos perfis comerciais ([[Registro-de-Decisoes]]) |
