---
id: LOG-51
aliases: ["Contrato 51", "51-Seguranca-e-Padrao-da-API-do-Hub"]
tags: [contrato, contrato-logica, contrato-api, contrato-sql, seguranca, api-acos-vital, dba]
criado: 2026-10-15
atualizado: 2026-10-19
status: aplicado-em-producao
sistemas: [hub-banco, hub-api, hub-front]
dono: "Gustavo (DBA)"
etapa_0b: []
fontes: ["api-acos-vital 276dab8 (app.js, middlewares/apiKeyAuth.js, middlewares/identidadeUsuario.js, utils/acessoConfig.js, utils/azureIdToken.js, utils/crudFactory.js, schemas/auth/**, schemas/core_organograma/tables/node/node.route.js)", "Dump Avhub (Esqueleto).sql:19-23, :519, :2498, :10198-10214, :12465, :12483, :13650", "auditoria de segurança de 15/10/2026 (leitura de código, sem teste dinâmico)"]
criado_original: 2026-10-15
---

# Contrato 51 — Segurança e padrão da API do av-hub (`api-acos-vital`)

> **Onde atua:** av-hub: banco, API, front

> [!info] Situação em 15/10/2026
> **Status:** `proposta` · **Pasta:** `Ativos` · **Nós do 0b:** — (transversal, fora do fluxo de Atividades) · **Dono:** Gustavo (DBA)
>
> - 🔴 Nenhum item **da API** (S1 a S27) está feito. É o resultado de uma auditoria de **leitura de código** da `api-acos-vital` (commit `276dab8`) e do dump de esquema, pedida pelo Nathan para deixar o av-hub seguro e em padrão de ERP.
> - 🟡 **Lado do HUB (seção 7):** H1, H3, H4, H5 e H6 estão no código, e o H2 em parte (resta `fetchMenu`), mesclados na PR #206 (`d0ef359`, 15/10/2026). O CI do HUB (lint, typecheck, madge, build e o e2e do Comercial) passou. H7 é manual e segue aberto. ❓ Não testado na homologação com a API e o Azure.
> - ✅ Os itens S1 a S8, S11 (parte do `/azure`), S12 (`docsAuth.js` e `pagina.js`), S15, S19, S20, S22 (gatilho no dump), S23 (`limit`), S25 e S27 foram **relidos no código ou no dump em 15/10/2026**, depois da auditoria. Os demais (S9, S10, S13, S14, S16, S17, S18, S21, S24 e S26) vêm da auditoria por leitura e o DBA deve reconfirmar ao implementar.
> - ❓ **Nada foi executado.** Não subi a API nem testei requisição. Os valores reais do `.env` e do Coolify, os GRANTs e o conteúdo de `auth.rotas_telas` em produção não foram vistos (o dump não traz GRANT).
> - 🟡 Quem decide o que entra e em que ordem é o Nathan com o Gustavo. A seção 9 lista as perguntas.
>
> Divisão de trabalho ([[Regras-do-Vault]]): **banco e API são do Gustavo**; o que o front/BFF precisa mudar para destravar cada item está na seção 7 e é do Nathan. O S1 (troca da chave de serviço) vale **nos dois lados**, então há uma parte do Robert (MES), na seção 7b.

## 1. Por que este contrato existe

O av-hub vai ser o ERP único da Aços Vital, e a `api-acos-vital` é a única porta de entrada para o banco. A auditoria de 15/10 achou que a base é boa (SQL parametrizado, JWT com algoritmo fixo e revogação por versão, bcrypt cost 12 feito no banco, rota sem mapa de permissão dando 403, dinheiro em `numeric`, todas as 124 tabelas com chave primária), mas o **modelo de confiança gira em volta de uma chave de serviço admin** que dispensa permissão, escopo e identidade, e que o BFF, o MES e o pipeline compartilham. Um vazamento dessa chave é controle total da API. O contrato junta o que falta para fechar isso e para a API seguir o padrão de um sistema de gestão: autenticação forte, menor privilégio, auditoria com valor anterior, erro sem vazamento, teste e CI.

Os contratos [[LOG-40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]] e [[LOG-41-Login-Rate-Limit-no-Backend]] já fecharam o escopo de vendedor e o limite de login. Este contrato continua dali e absorve a pendência BL-018 (chave de serviço restrita) com o desenho completo. Mapa das chaves: [[Chaves-e-Autenticacao]].

## 2. Método e limites

- **O que foi lido:** `app.js`, todos os `middlewares/`, `utils/` de segurança e de erro, a rota `/autenticacao`, `/auth`, `/usuarios`, `/organograma/node`, trechos de `pedidos_vendas`, `pedidos_liberacao`, `orcamento`, `dashboard`; o restante das 124 rotas por busca textual. O dump de esquema por busca (arquivo de 1,2 MB).
- **O que não foi feito:** não rodei a API, não executei exploit, não rodei `npm audit` na API, não li os jobs do MES (`*.job.js`) nem `catalogoOmie.js`. Os cenários abaixo vêm de leitura.
- **Selos nesta nota:** os de [[Regras-do-Vault]]. Onde digo "relido em 15/10" o trecho foi aberto de novo depois da auditoria; sem essa marca, a afirmação vem da auditoria por leitura.

## 3. Resumo dos itens

Prioridade: **P1** corrigir antes de qualquer expansão de uso; **P2** na sequência; **P3** padrão e manutenção.

| ID | Item | Gravidade | Prioridade | Tipo |
|---|---|---|---|---|
| S1 | Chave de serviço admin sem token dispensa permissão, escopo e identidade | Crítico | P1 | API + ambiente |
| S2 | `POST /autenticacao/azure` emite JWT só com o e-mail quando a validação do `id_token` está desligada (padrão) | Crítico | P1 | API + ambiente (+ BFF) |
| S3 | Troca de senha sem limite de tentativas, sem revogar tokens e sem política de senha | Alto | P1 | API |
| S4 | `PUT /organograma/node/:id` faz `node.update(req.body)` (mass assignment) | Alto | P1 | API |
| S5 | Rate limit global contornável pelo header `x-api-key` e com limite incoerente | Alto | P1 | API |
| S6 | Respostas 500 devolvem `err.message` do driver em dezenas de rotas | Alto | P1 | API |
| S7 | Sem `helmet` e CORS `*` por padrão | Alto | P1 | API + ambiente |
| S8 | Roles do banco todos `SUPERUSER` e a API precisa de DDL no boot | Alto | P1 | Banco |
| S9 | Sem testes automatizados e sem CI | Alto | P2 | API |
| S10 | Sessão renovável sem teto absoluto | Médio | P2 | API |
| S11 | Enumeração de usuário e bloqueio induzido no login | Médio | P2 | API |
| S12 | `/docs` entrega a `DOCS_API_KEY` a qualquer conta do tenant | Médio | P2 | API + ambiente |
| S13 | Callback do Azure no `/auth` sem validar assinatura nem `nonce` | Médio | P2 | API |
| S14 | Chaves do `.env` comparadas sem tempo constante | Baixo | P3 | API |
| S15 | Corpo JSON de até 10 MB lido antes da autenticação | Médio | P2 | API |
| S16 | Escritas em lote e multi-tabela sem transação | Médio | P2 | API |
| S17 | Auditoria só com nomes de campos, sem antes e depois, e mutável | Médio | P2 | Banco + API |
| S18 | Colunas de auditoria incompletas e chaves estrangeiras sem índice | Médio | P2 | Banco |
| S19 | `/health` expõe banco e ambiente; 500 fora de produção devolve a mensagem | Baixo | P3 | API |
| S20 | Prefixos públicos por `startsWith` sem fronteira e `/blog` ainda liberado | Baixo | P3 | API |
| S21 | Prefixo da chave nos logs | Baixo | P3 | API |
| S22 | Senha começando com `$2` é gravada em texto puro; `POST /usuarios` pode devolver o hash | Baixo | P3 | Banco + API |
| S23 | `LIKE` sem escape de curinga e `limit` negativo | Baixo | P3 | API |
| S24 | Listagens sem paginação | Baixo | P3 | API |
| S25 | Quantidades em `double precision` | Baixo | P3 | Banco |
| S26 | Duplicação, arquivos grandes e `no-console` desligado | Baixo | P3 | API |
| S27 | Filtro `alterado_desde` de `/parceiros` e `/produtos` fica depois de `return where;` e nunca executa | Baixo | P3 | API |

---

## 4. Fase 1 (P1): o que fecha o risco de controle total

### S1 — Chave de serviço admin sem token dispensa permissão, escopo e identidade

- **Onde (✅ relido em 15/10):** `src/middlewares/apiKeyAuth.js:160-161` monta `{ origem: "env", acesso: "admin", exigeUsuario: exigirToken() }`; `src/utils/acessoConfig.js:71` define `exigirToken = () => bool("IDENTIDADE_EXIGIR_TOKEN", false)`; `src/middlewares/identidadeUsuario.js:67-75` só devolve 401 `TOKEN_USUARIO_AUSENTE` se `exigeUsuario` for verdadeiro.
- **O que acontece.** Quem tem uma chave de `API_KEYS` e não manda `Authorization` nunca passa por `auth.fn_autorizar`. Pode chamar qualquer rota (inclusive `/usuarios`, `/perfis`, `/permissoes`, `/pedidos_vendas/lote`, que apaga de verdade). Pode se passar por qualquer usuário informando `id_usuario_sessao` e os campos `created_by`/`updated_by`; a auditoria grava isso como `identidade_origem = 'informada'`. A mesma chave é usada pelo BFF, pelo MES (chave B) e pelo pipeline (chave C) ([[Chaves-e-Autenticacao]]). Vazar uma é vazar as três.
- **O que fazer (Gustavo).**
  1. Migrar o MES e o pipeline para chaves de `auth.chaves_servico` com o **menor nível** que servem (`escrita` onde precisam escrever, `leitura` onde só leem). Hoje o nível não restringe rota (não há lista de rotas por chave): acrescentar `rotas_permitidas` à chave (lista de métodos e padrões de caminho, como `auth.rotas_telas`) e recusar com 403 o que sai da lista. Fecha BL-018.
  2. Deixar `API_KEYS` do `.env` **só para o BFF** e ligar `IDENTIDADE_EXIGIR_TOKEN=true` para ele. Depois disso, transformar a variável em regra fixa no código (princípio do [[LOG-38-Regras-Sem-Chave-de-Ambiente]]) e apagar o ramo `exigeUsuario: false` das chaves de `API_KEYS`.
  3. Rotacionar a chave de produção que está hoje em texto no `.env.local` da estação do Nathan (ver S12 e a seção 7).
- **Dependência com o front (seção 7):** com a variável ligada, só `/autenticacao` e `/me` ficam isentas (`acessoConfig.js:95`). As três chamadas do BFF feitas **antes** do login (`fetchMenu`, `fetchSlugDaTela`, `fetchInfoPerfisDoUsuario`, `app/api/auth/[...nextauth]/route.ts`) usam só a chave e passariam a receber 401. Ou o BFF passa a mandar o token do usuário nelas, ou o DBA inclui as rotas exatas em `ROTAS_SEM_PERMISSAO_DE_TELA`. **Não ligar a variável antes de resolver isso** (derruba o login). Em 15/10 o HUB já passou perfis e tela inicial para `GET /me/permissoes` com o Bearer (H2, PR #206): **resta só `fetchMenu`**, que a API precisa isentar (`GET /permissoes_usuario/menu/:id_usuario`, conferindo que o id é o do token).
- **Aceite:** ver teste T1 da seção 8.

### S2 — `POST /autenticacao/azure` emite JWT só com o e-mail

- **Onde (✅ relido):** `src/utils/azureIdToken.js:27-28` (`validarIdTokenLigado()` devolve `false` quando `AUTENTICACAO_AZURE_VALIDAR_ID_TOKEN` não existe); `src/schemas/auth/aggregates/autenticacao/autenticacao.route.js:99-135` só valida o `id_token` se a função der `true`, senão usa `req.body.email` e chama `respostaLogin(res, usuario.id, "informada")`.
- **O que acontece.** Com a validação desligada, qualquer chamador com a chave de serviço obtém um JWT válido de **qualquer usuário ativo**, inclusive de um administrador, informando só o e-mail. Junto com S1, o controle da API fica em um segredo só.
- **O que fazer (Gustavo, com o Nathan).**
  1. Tornar a validação do `id_token` **regra fixa** (sempre ligada em produção), sem chave de desligamento. O código de validação já existe e está pronto (`emailDoIdToken`).
  2. O **BFF precisa mandar o `id_token`** do Azure no `POST /autenticacao/azure`. Até 14/10 não mandava (`grep id_token` em `app/api/auth/[...nextauth]/route.ts` não achava ocorrência); **passou a mandar em 15/10 (H1, PR #206)**, então a API já pode fixar a validação. ❓ Testar o login Azure com a validação ligada.
  3. Restringir `/autenticacao/azure` a uma chave de serviço dedicada (a do BFF), nunca à do MES nem à do pipeline.
- **Aceite:** teste T2.

### S3 — Troca de senha sem limite, sem revogação e sem política

- **Onde (✅ relido):** `src/schemas/auth/tables/usuarios/usuarios.route.js:71-95`. `bcrypt.compare(senha_atual, usuario.senha)` seguido de `usuario.update({ senha: senha_nova })`. `auth.fn_revogar_tokens_usuario` só é chamada no logout (`autenticacao.route.js:237`).
- **O que acontece.** (1) A rota não passa por `limiteExcedido`/`loginFalhou`, que só existem no `/autenticacao/login`: quem tem a chave e o `id` de um usuário testa senhas sem limite pelo campo `senha_atual`. (2) Trocar a senha não revoga os tokens já emitidos: um token roubado continua valendo. O comentário da função no dump (linha 790) diz que ela serve para "troca de senha". (3) Não há tamanho mínimo; o bcrypt também corta a senha em 72 bytes.
- **O que fazer.** Aplicar o mesmo limite de falhas do login a essa rota; chamar `auth.fn_revogar_tokens_usuario` depois do `update`; validar de 8 a 72 bytes; exigir que `req.usuario.id === req.params.id` (a troca é do próprio usuário; redefinição por administrador é outra rota, com permissão própria e auditoria).
- **Aceite:** teste T3.

### S4 — Mass assignment em `PUT /organograma/node/:id`

- **Onde (✅ relido):** `src/schemas/core_organograma/tables/node/node.route.js:63` — `await node.update(req.body);`.
- **O que acontece.** O cliente envia qualquer coluna do model (`id`, `deleted_at`, `created_by`, chaves estrangeiras). Todas as outras rotas usam lista de campos permitidos (`pick`); esta é a exceção. As três escritas desse arquivo também não usam transação nem validação.
- **O que fazer.** Trocar por `pick(CAMPOS_EDITAVEIS)` como em `usuarios.route.js:29-39`, ou migrar a rota para `createCrudHandlers`. Envolver as escritas em transação.
- **Aceite:** teste T4.

### S5 — Rate limit global contornável

- **Onde (✅ relido):** `src/app.js:73-82` — `max: 10000` com o comentário "200 req/min" e `keyGenerator: (req) => req.headers["x-api-key"] || ipKeyGenerator(req)`.
- **O que acontece.** O limiter roda antes do `apiKeyAuth` e usa o valor bruto do header como chave: um atacante manda uma `x-api-key` diferente a cada requisição e nunca bate o limite, e cada valor distinto ocupa memória do store. Com 10000/min mesmo a chave legítima tem pouca proteção. O comentário diverge do código.
- **O que fazer.** Chavear por **IP** (`ipKeyGenerator`) antes da autenticação, com um teto apertado, e por chave **depois** que ela for validada. Alinhar valor e comentário. Para atrás de proxy, conferir `trust proxy` (ver Q4 da seção 9).
- **Aceite:** teste T5.

### S6 — `err.message` do driver nas respostas 500

- **Onde (✅ relido):** `autenticacao.route.js:137,184,229,244`; `usuarios.route.js:94`; `permissoes.route.js:84`; `vw_permissoes_usuario.route.js:99,120,145,156`; `mapa_unidades.route.js:27,37`; `vw_todos_os_clientes.route.js:26,36`; `vw_historico_precos.route.js:27`; `vw_todos_os_fornecedores.route.js:24,34`; `vw_catalogo_de_produtos.route.js:65,83`; `vw_fornecedores_com_produtos.route.js:35,55`; `item_estado_projetado.route.js:276` (devolve `mes_motivo: err.message`).
- **O que acontece.** Mensagens do Postgres e do Sequelize (nome de tabela, coluna, constraint, trecho de SQL) vão ao cliente sem passar por `handleError`/`handleSequelizeError`, que já mascaram em produção. Em `item_estado_projetado.route.js:276` vazam até falhas de conexão com o MES.
- **O que fazer.** Trocar todas por `handleError(err, res)` e deixar o tratador global do `app.js` como único ponto de resposta 5xx. Uma regra de lint (`no-restricted-syntax`) proíbe `err.message` dentro de `res.json`/`res.send`.
- **Aceite:** teste T6.

### S7 — Sem `helmet` e CORS `*` por padrão

- **Onde (✅ relido):** `app.js:49-70`; `package.json` não tem `helmet`; não existe `app.disable("x-powered-by")`; `CORS_ORIGINS` vazio vira `"*"`.
- **O que acontece.** Sem HSTS, `X-Content-Type-Options`, CSP e afins; `x-powered-by: Express` exposto. Com `CORS_ORIGINS` indefinido, a API responde `Access-Control-Allow-Origin: *` aceitando `Authorization` e `x-api-key`: qualquer site pode chamá-la a partir do navegador de quem tiver uma chave. `/docs` e a sessão ficam sem CSP.
- **O que fazer.** Adicionar `helmet()` e `app.disable("x-powered-by")`. Tornar `CORS_ORIGINS` **obrigatório em produção**, sem fallback para `*` (o `utils/env.js` já derruba o processo se faltar variável; incluir esta). O BFF chama servidor a servidor, então a lista de origens pode ficar vazia (sem CORS) para a API.
- **Aceite:** teste T7.

### S8 — Roles do banco todos `SUPERUSER`

- **Onde (✅ relido no dump):** `Dump Avhub (Esqueleto).sql:19-23` — `avhub_prd_admin` e `postgres` com `SUPERUSER ... LOGIN`; `avhub_tst_admin` com `SUPERUSER ... REPLICATION BYPASSRLS` (sem login). No código: `app.js:199-204` faz `CREATE SCHEMA IF NOT EXISTS` no boot e `app.js:102` usa `createTableIfMissing: true` para a tabela de sessões, o que exige DDL e empurra a conexão da API para um role privilegiado.
- **O que acontece.** Se a aplicação roda como `avhub_prd_admin` (❓ não sei qual `DB_USER` a API usa em produção), qualquer falha na API, como S1 ou S4, vira acesso total ao banco (`COPY ... TO PROGRAM`, leitura de qualquer schema).
- **O que fazer (Gustavo, é dele).**
  1. Criar o role `avhub_api` **sem** `SUPERUSER`, `CREATEDB` nem `CREATEROLE`, com `GRANT` mínimo por schema (`SELECT/INSERT/UPDATE/DELETE` nas tabelas que a API usa, `EXECUTE` nas `fn_*`).
  2. Tirar o DDL do boot da API: criar os schemas e `auth.sessions` por migration; apagar o `CREATE SCHEMA` de `app.js:199-204` e o `createTableIfMissing`.
  3. Rodar as migrations com um role separado, fora da aplicação.
  4. Versionar o SQL em repositório (BL-024), incluindo os `GRANT` (o dump não traz nenhum: provável `pg_dump -x`).
- **Aceite:** teste T8.

---

## 5. Fase 2 (P2): endurecer

### S9 — Sem testes e sem CI

`package.json` só tem `start`, `dev`, `lint` e `lint:fix`; não existe `*.test.*`/`*.spec.*` nem `.github/`; o README é só um diagrama. Toda a lógica de autorização, escopo e escrita multi-tabela (~75 mil linhas) é validada só em produção. **Fazer:** testes de integração (supertest e um Postgres de teste) cobrindo os testes da seção 8 e mais: token expirado e revogado, 403 por rota sem mapa, escopo de vendedor, mass assignment, paginação com limite. CI com `npm run lint`, os testes e `npm audit`. O módulo comercial que vai entrar na API ([[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]]) já traz cerca de 300 testes escritos em Vitest que podem servir de modelo.

### S10 — Sessão renovável sem teto

`autenticacao.route.js:223-229` e `utils/tokenUsuario.js:47-57`: `/renovar` aceita qualquer token ainda válido (TTL de 15 min) e emite outro, sem vida máxima e sem `jti`. Um token roubado vive enquanto for renovado a cada 15 min, até um logout. `token_versao` é um só por usuário: o logout em um aparelho derruba todos. **Fazer:** claim `auth_time` e vida máxima da sessão (8 a 12 h; o BFF usa 12 h), recusando a renovação acima disso.

### S11 — Enumeração de usuário e bloqueio induzido

`autenticacao.route.js:127-129,167-173`: `/azure` responde 404 "Usuário não encontrado" e `/login` diz "Usuário inativo ou desligado" e "não possui login interno", mensagens diferentes da de credencial inválida. Quem tem a chave descobre quais e-mails existem e quais estão inativos, sem custo no contador. A chave `email:<e-mail>` do limite é global (sem IP), então quem tem a chave também trava o login de qualquer e-mail com 5 senhas erradas (o contrato 41 aceitou esse custo). **Fazer:** resposta uniforme 401 "Credenciais inválidas" nos dois endpoints, com o motivo só no log; avaliar bloqueio progressivo em vez de duro.

### S12 — `/docs` entrega a `DOCS_API_KEY`

`middlewares/docsAuth.js:1-4` só confere `req.session?.user`; `auth.route.js:62-76` cria sessão para **qualquer conta do Azure AD** do tenant sem consultar `auth.usuarios`; `docs/pagina.js:94-98` embute `apiKey: { token: process.env.DOCS_API_KEY }` na página (✅ relido). Qualquer funcionário ou convidado do tenant abre `/docs` com a chave pré-preenchida; se for uma chave admin, o acesso é total (❓ não sei o nível nem o valor em produção). **Fazer:** exigir que o e-mail exista ativo em `auth.usuarios` e tenha o perfil de testes do time de TI; a `DOCS_API_KEY` de produção deve ser de nível `leitura` ou não existir, e a página de produção não deve trazer chave pré-preenchida.

### S13 — Callback do Azure sem validar assinatura e sem `nonce`

`schemas/auth/aggregates/auth/auth.route.js:62-76` lê o payload do `id_token` por `Buffer.from(...split(".")[1], "base64url")`, sem verificar assinatura (comentário: "seguro pois obtido via HTTPS"). Sem `nonce` e sem checar `aud`/`iss`/`tid`. O risco é baixo enquanto o token vier direto do endpoint do Azure, mas o código de validação já existe em `utils/azureIdToken.js`. **Fazer:** reaproveitar `emailDoIdToken` no callback e acrescentar `nonce`. O `GET /auth/logout` também aceita CSRF (efeito mínimo).

### S15 — Corpo JSON de 10 MB antes da autenticação

`app.js:46` (✅ relido) — `express.json({ limit: process.env.JSON_BODY_LIMIT || "10mb" })` roda antes do `ipFilter`/`apiKeyAuth` e o limiter é contornável (S5). Um anônimo faz o servidor processar 10 MB por requisição. **Fazer:** manter um limite pequeno por padrão (100 KB), subir só nas rotas de lote que precisam, e processar o corpo depois da chave validada.

### S16 — Escritas em lote sem transação

`pedidos_vendas.route.js` (17 pontos de escrita, nenhuma transação): upsert com `find`, `create` e nova tentativa, e `DELETE /lote` (linhas 599-668) com `findAll` seguido de `destroy({ force: true })` de até 500 pedidos. O mesmo em `notas_fiscais.route.js`, `utils/upsertByKey.js`, `refaturamentos.route.js` e `produto_vendas.route.js`. Uma queda entre as duas operações, ou uma corrida entre dois upserts, deixa estado parcial. **Fazer:** `sequelize.transaction` ou `INSERT ... ON CONFLICT DO UPDATE ... RETURNING (xmax = 0)`. `ordens_compra`, `simulacoes`, `funcionarios` e `vaga` já usam transação: seguir esse padrão.

### S17 — Auditoria sem antes e depois, e mutável

`middlewares/auditoria.js:92-99` grava `campos: Object.keys(b)` (só os **nomes**); a tabela `auth.auditoria` (dump:10198-10214) não guarda valor anterior nem posterior e não tem gatilho de imutabilidade (só existe `fn_req_eventos_imutavel`, para eventos de requisição). Sem token, a autoria vem do corpo (`origem = 'informada'`). **Fazer:** gravar `antes` e `depois` (jsonb) nas tabelas sensíveis (usuários, perfis, permissões, preço, aprovação) por gatilho ou na rota; bloquear `UPDATE`/`DELETE` em `auth.auditoria` por gatilho e `GRANT`; ações novas exigem `ALTER` do `CHECK` (hoje: `criar`, `editar`, `excluir`, `decidir`, `ler_documento`, `login`, `logout`). O módulo comercial vai precisar de mais ações ([[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]]).

### S18 — Colunas de auditoria e índices de chave estrangeira

Do dump, por script de leitura (estimativa; confirmar no banco): de 124 tabelas, cerca de 60 não têm algum entre `created_at`, `updated_at`, `created_by`, `updated_by`. Sem nenhuma das quatro: `core_vendas_faturamento.refaturamentos`, `itens_pedido_custo`, `itens_pedido_status`, `pedidos_vendas_status_historico`, `core_comissionamento.simulacao_itens`, `core_organograma.nivel_hierarquico`. Sem `created_by`/`updated_by`: `core.contas_correntes`, `core.projetos`, `core_aprovacao_de_vagas.vaga`, `core_comissionamento.regras_comissoes_fixas`. Cerca de 77 de 175 chaves estrangeiras sem índice líder; as relevantes: `ordens_compra(codigo_comprador)` e `(id_comprador)`, `requisicoes_compra(id_ordem_compra)`, `requisicoes_compra_eventos(id_ordem_compra)` (o índice `ix_req_eventos_req_oc` começa por `id_requisicao`), `core.setores(parent_id)`, `core.produtos(codigo_empresa, familias_produtos)`, `core_comissionamento.simulacoes(id_parametros)` e `(id_simulacao_contestada)`, `core_organograma.welcome_settings(active_preset_id)`, e as `created_by`/`updated_by`/`deleted_by` para `auth.usuarios`. Há 33 `ON DELETE CASCADE`, então apagar em `auth.usuarios` ou `core.unidades` varre as filhas. **Fazer:** `CREATE INDEX CONCURRENTLY` nas chaves de negócio; indexar as de autoria só onde há exclusão de usuário ou consulta por autor; padronizar as quatro colunas e o gatilho `set_updated_at` (hoje em 50 tabelas) nas tabelas operacionais.

---

## 6. Fase 3 (P3): padrão e manutenção

| ID | O que fazer |
|---|---|
| S14 | Guardar o `sha256` das chaves de `API_KEYS` e comparar com `crypto.timingSafeEqual`, como já se faz com a chave do MES (`apiKeyAuth.js:52-54,160`). Hoje é `VALID_KEYS.has(...)`. Ataque de timing na rede é impraticável; o ponto é uniformizar. |
| S19 | `app.js:142-152`: `/health` devolve `database: process.env.DB_NAME` e `env`. Devolver só `{ status: "ok" }`. Em `NODE_ENV` diferente de `production`, o 500 devolve `err.message` (`app.js:188`): mascarar sempre, salvo flag explícita de depuração. |
| S20 | `apiKeyAuth.js:49,133` e `ipFilter.js:22` (✅ relido): `url.startsWith("/health" \| "/docs" \| "/auth" \| "/blog")`. Nenhuma rota atual começa com esses prefixos, mas uma futura `/authors` nasceria sem chave e sem filtro de IP. Comparar `url === p \|\| url.startsWith(p + "/")` e **remover `/blog`** (o blog saiu da API, e o comentário do arquivo ainda o libera). |
| S21 | `apiKeyAuth.js:139,167`, `requestLogger.js:19-31`, `auth.logs.identificador`: gravam 8 caracteres da chave, 32 bits do segredo se for UUID. Logar o `id` da chave (hash truncado), não o prefixo. |
| S22 | Dump `:519` (`fn_hash_senha`): `IF NEW.senha NOT LIKE '$2%' THEN crypt(...)`. Quem grava uma senha começando com `$2` por `POST/PUT /usuarios` grava o valor **sem hash**; dá para injetar um hash conhecido. Validar o formato completo de hash bcrypt (`^\$2[aby]\$\d{2}\$.{53}$`) e aceitá-lo só do role de migração. Há também `fn_set_senha` (dump:868 em diante) como caminho paralelo: consolidar em um. Além disso, `POST /usuarios` (`utils/crudFactory.js`, ✅ por leitura) devolve o registro criado e o `RETURNING` do Sequelize traz todas as colunas: o hash gerado pelo gatilho provavelmente volta no 201 (❓ não testei). Remover `senha` do JSON de resposta. |
| S23 | Dezenas de `Op.iLike: %${query.x}%` (ex.: `parceiros.route.js:86-89`) não escapam `%` e `_`: consulta cara com `%%%%`. O padrão correto está em `pedidos_liberacao.route.js:101-104`. `crudFactory.js:246` — `Math.min(200, parseInt(req.query.limit, 10) \|\| 50)` (✅ relido) — não tem piso: `limit=-5` vira `LIMIT` negativo e dá 500. Usar `parsePagination` (`utils/pagination.js`), que já faz certo. |
| S24 | 16 arquivos de rota sem `limit`/`usePaginate`, 4 dos 33 `list()` sem paginar (`itens_pedido_status`, `pedidos_vendas_status_historico`, `contas_correntes`, `projetos`, `ip_regras`). As de itens e de histórico crescem. Teto de 200 em todas. |
| S25 | `double precision` em quantidades: `core_vendas_faturamento.produto_vendas.quantidade` (dump:2498), `historico.hst_produto_vendas.quantidade` (:13650), `core_comissionamento.simulacao_itens.qtd` (:12465) e `qtd_compra` (:12483). Multiplicar por preço perde precisão. Trocar por `numeric(15,4)` (convenção do vault). Migration com cuidado: as views dependentes (por exemplo `quantidade_vendida`, dump:20621) precisam ser recriadas. |
| S27 | ✅ relido em 15/10 (já listado como B10 em [[Bugs-Conhecidos]]): `parceiros.route.js:96` e `produtos.route.js:51` têm `return where;` **antes** do bloco `alterado_desde` (`:97-105` e `:52-60`). O filtro nunca executa, embora o contrato [[API-001-Produtos-Parceiros-Filtro-Incremental]] esteja como entregue. Mover o bloco para antes do `return` e criar teste; ou rebaixar o status do API-001. |
| S26 | `maskKey` duplicada (`apiKeyAuth.js:88`, `requestLogger.js:19`); `CAMPOS_AUTORIA` duplicada (`apiKeyAuth.js:72`, `identidadeUsuario.js:35`); três implementações de paginação; `ordens_compra.route.js` com 1359 linhas e `funcionarios.route.js` com 657, misturando SQL, regra e HTTP; stubs "regra fixa, devolve sempre true" em `acessoConfig.js:75-83`; `no-console` desligado (15 `console.log` fora de `docs/`); sem `eslint-plugin-security`; `package.json` com nome `empresa-api`; `Dockerfile` copia o código inteiro (`COPY . .`) sem `.dockerignore` para `docs`/`public` desnecessários. Extrair `middlewares/_comum.js`, dividir os arquivos grandes em rota, serviço e repositório, apagar os stubs, ligar `no-console`. |

## 7. O que o Nathan (front/BFF do HUB) precisa fazer para destravar

Itens do lado do HUB, que **não** são do DBA. Eles definem a ordem da seção 10.

| # | O quê | Destrava | Estado em 15/10 |
|---|---|---|---|
| H1 | Mandar o `id_token` do Azure no `POST /autenticacao/azure` | S2 (ligar a validação) | ✅ `findUserByEmail` manda `id_token` (PR #206) |
| H2 | As três chamadas pré-login (`fetchMenu`, `fetchSlugDaTela`, `fetchInfoPerfisDoUsuario`) passarem a levar o token do usuário, **ou** combinar com o DBA a lista exata de rotas isentas | S1 (ligar `IDENTIDADE_EXIGIR_TOKEN`) | 🟡 Perfis e tela inicial vêm de `GET /me/permissoes` com o Bearer do próprio usuário; `fetchSlugDaTela` e `/usuarios_perfis` e `/perfis` saíram. **Resta `fetchMenu`**, só com a chave: a API isenta `GET /permissoes_usuario/menu/:id_usuario` |
| H3 | Falhar fechado quando a sessão estiver sem `backendToken` (401 "entre novamente"), em vez de seguir só com a chave de serviço; renovar o token por expiração, não só a cada 5 min | S1, S10 | ✅ `requirePermission`: 401 sem token, 503 se `/me/permissoes` falhar, 403 fora de `auth.telas`, sem fallback para o menu do JWT; renova com menos de 5 min para vencer; sessão relida a cada 4 min; `SessaoExpiradaGuard` leva ao login |
| H4 | Tirar `backendToken` e `backendTokenExpiraEm` da `session` devolvida ao navegador | defesa em profundidade | ✅ O servidor lê do cookie (`lib/auth/backendToken.ts`); a sessão só traz `sessaoExpirada` |
| H5 | Parar de aceitar `codigo_vendedor` do navegador em `comissoes/minhas-comissoes` | escopo | ✅ O escopo vem do token, aplicado pela API (`faturamento_planilha` está no mapa de escopo). `vendedor` segue como filtro de texto que só estreita |
| H6 | Rotas do BFF com `..` no parâmetro (`grupos-clientes`, `blacklist_*`, `comissoes/*`, `compras/pedidos-venda`) passarem por validação | traversal | ✅ `parametrosSeguros` para ids e códigos, `segmentoSeguro` para texto livre, e trava única no `repassar` de `grupos-clientes` |
| H7 | Rotacionar a chave de produção que está em texto no `.env.local` e apagar a linha comentada | S1 | 🔴 Manual (Nathan e Gustavo); o assistente não mexe em segredo |

### 7b. O que o Robert (MES) precisa fazer no S1

- Quando o Gustavo trocar a chave de serviço do MES, **atualizar a variável de ambiente da chave no MES** (`API_KEY` no `api-pcp`, e `AVHUB_MES_INTEGRACAO_KEY` se a chave A também mudar; ver [[Chaves-e-Autenticacao]]).
- Conferir que as rotas que o MES chama estão nas `rotas_permitidas` da chave nova: a referência da OC, o `PUT` de requisições, os eventos do [[LOG-35-Compras-Marcos-Requisicao-para-MES]] e, depois, a referência de requisições do [[API-009-Referencia-Requisicao-Hub-Integracao-MES]]. Rota fora da lista dá 403 no MES (ver o modo só registro na seção de riscos).

Os demais achados de segurança do BFF (IDOR na observação do PCP, e-mail de proposta com só `pode_visualizar`, PATCH de senha com só `pode_editar`, validação de entrada, CSRF, CSP) ficam em nota própria do HUB, não neste contrato.

## 8. Testes de aceite

Todos rodam contra a API de homologação, com a `develop` publicada e o BFF no ar.

| # | Teste | Resultado esperado |
|---|---|---|
| T1 | Chamar `GET /usuarios` só com a chave do **BFF** e sem `Authorization` | 401 `TOKEN_USUARIO_AUSENTE`. Com a chave do **MES** em rota fora da lista dela: 403 |
| T2 | `POST /autenticacao/azure` com `{"email":"<administrador>"}` e sem `id_token` | 401 `ID_TOKEN_INVALIDO`. Com `id_token` de outro e-mail: 401 `ID_TOKEN_EMAIL_DIVERGENTE`. Com a chave do MES: 403 |
| T3 | `PATCH /usuarios/:id/senha` com 6 senhas atuais erradas; depois com senha nova de 5 caracteres; depois uma troca válida | 6ª tentativa 429; senha curta 400; troca válida revoga o token anterior (o token velho passa a dar 401 `token_revogado`) |
| T4 | `PUT /organograma/node/:id` com `{"id":"<outro uuid>","deleted_at":"2026-01-01","created_by":"<outro>"}` | os campos fora da lista são ignorados; o registro mantém `id`, `deleted_at` e `created_by` |
| T5 | 20.000 requisições com `x-api-key` diferente a cada uma | passa a retornar 429 pelo IP; a memória do limiter não cresce por valor distinto |
| T6 | Forçar um erro de SQL (por exemplo, `GET` com id malformado em `/vw_permissoes_usuario/...`) | corpo `{ "detail": "Erro interno do servidor." }`, sem nome de tabela, coluna ou SQL |
| T7 | `OPTIONS` e `GET` com `Origin: https://qualquer.site` | sem `Access-Control-Allow-Origin`; resposta traz `Strict-Transport-Security`, `X-Content-Type-Options` e **não** traz `X-Powered-By` |
| T8 | `SELECT rolsuper FROM pg_roles WHERE rolname = '<DB_USER da API>'` e subir a API num banco sem os schemas | `false`; a API **não** cria schema nem tabela no boot (falha com mensagem clara se faltarem) |
| T9 | Sessão: renovar um token por mais de 12 h seguidas | 401 `SESSAO_EXPIRADA` |
| T10 | `UPDATE auth.auditoria SET acao = 'x'` com o role da aplicação | permissão negada; `INSERT` continua funcionando |
| T11 | `POST /usuarios` com `senha: "$2a$12$abc"` e depois `POST /usuarios` válido | o primeiro 400; o segundo devolve 201 **sem** o campo `senha` |
| T12 | `GET /produtos?limit=-5` | 400 (ou o limite mínimo aplicado), nunca 500 |

## 9. Perguntas para o Gustavo (confirmar em produção)

| # | Pergunta | Por que importa |
|---|---|---|
| Q1 | ✅ **No teste:** `DB_USER=postgres` e `postgres` é `SUPERUSER`. Confirma S8. `DB_HOST` é IP público (porta 3111); porta não aberta para fora (Gustavo). Produção a confirmar. | S8 |
| Q2 | ✅ **No teste:** `IDENTIDADE_EXIGIR_TOKEN=false`; `AUTENTICACAO_AZURE_VALIDAR_ID_TOKEN` não definida → vale `false`; `CORS_ORIGINS` não definida → vale `"*"` (aceita qualquer origem). Produção a confirmar. | S1, S2, S7 |
| Q3 | ✅ **No teste:** `API_KEYS` tem ~5 chaves e toda chave do `API_KEYS` é admin. `DOCS_API_KEY` (`c98390b9`) **não está** no `API_KEYS`; não tem formato `avk_`; no teste não abre nada (botão do `/docs` daria 401). Não houve acesso ao `/docs` nos logs. 💡 Ou remove a `DOCS_API_KEY` do teste, ou cria chave de serviço de leitura para o `/docs`. Produção a confirmar. | S12 |
| Q4 | ✅ **No teste:** 1 proxy (Traefik do Coolify); sem Cloudflare (sem `cf-ray` no `/health`); `trust proxy 1` correto. 🟡 Logs batem: tráfego externo chega com IP público da empresa; interno com `172.16.1.1` (rede docker). **Achado:** resposta traz `X-Powered-By: Express` e sem cabeçalhos de segurança do helmet — confirma S7. | S5 (IP do limiter), S21 |
| Q5 | 🔴 Quais rotas têm linha em `auth.rotas_telas` e quais estão em `auth.rotas_administrativas`? `/usuarios`, `/perfis`, `/permissoes` e `/usuarios_perfis` exigem permissão de tela, ou um usuário comum com token pode editá-las (escalada de privilégio)? O comentário de `usuarios.route.js:23-28` admite que quem edita usuário pode dar `setor_irrestrito` a si mesmo | S1 e todo o RBAC. Maior incógnita desta auditoria |
| Q6 | 🟡 Há `GRANT` por schema hoje, ou todos os acessos são por superusuário? | S8 |
| Q7 | 🟡 O corpo de `public.set_updated_at()` preenche `updated_by`? | S18 |
| Q8 | ✅ **No teste:** `da26afd5` está no `API_KEYS` — é a `API_KEY` do BFF. 🟡 Pelas rotas que chama, pipeline e máquinas da rede também usam a mesma chave. ✅ `e4d2a1b9` = `MES_INTEGRACAO_KEYS` (só o `PUT` da requisição, contrato 34). ✅ **MES já usa a chave nova `avk_` (Robert, 19/10):** chave de `auth.chaves_servico` passada pelo Gustavo já configurada no `api-pcp`; falta só estar nas variáveis dos ambientes publicados (BL-035). A descrição da chave leitora `0192850a` ficou desatualizada. 💡 Uma chave por sistema: `mes-integracao` já existe; falta criar `pipeline-omie` (passo 2 do roteiro) e depois enxugar o `API_KEYS` (passo 5). | S1 |
| Q9 | 🟡 O repositório da API passa a versionar o SQL (migrations e `GRANT`)? Sugestão: sim, numa pasta `sql/` com numeração. Liga com BL-024 | S8, S18 |

## 10. Passo a passo e ordem

A ordem respeita as dependências: o que não depende do HUB vai primeiro, e a chave de serviço só aperta depois que o HUB estiver pronto.

| # | Quem | Passo |
|---|---|---|
| 1 | Gustavo | Responder Q1 a Q5 (só leitura em produção). Define o tamanho real de S1, S8 e S12 |
| 2 | Gustavo | **Sem dependência do HUB:** S4, S6, S7 (com `CORS_ORIGINS` combinado), S5, S15, S3, S10, S19, S20, S21, S22, S23 |
| 3 | Nathan | H1 a H7 no HUB. ✅ H1, H3 a H6 e parte do H2 na PR #206 (`d0ef359`, 15/10/2026); resta `fetchMenu` (com a API) e H7 (manual) |
| 4 | Gustavo | S2: tornar a validação do `id_token` fixa **depois** de H1 em produção |
| 5 | Gustavo (com o Robert) | S1 parte 1: criar chaves em `auth.chaves_servico` para MES e pipeline, com `rotas_permitidas`; trocar nos dois lados (o Robert atualiza a variável da chave no MES); rotacionar a chave antiga |
| 6 | Gustavo | S1 parte 2: ligar `IDENTIDADE_EXIGIR_TOKEN` para o BFF, depois de H2 e H3; tornar a regra fixa e apagar o ramo antigo |
| 7 | Gustavo | S8: novo role `avhub_api`, migrations fora do boot, `GRANT` mínimo. Trocar o `DB_USER` da API numa janela combinada |
| 8 | Gustavo | S17, S18 e S25: auditoria com antes e depois, colunas e índices, `numeric` nas quantidades |
| 9 | Gustavo | S9 e S26: testes, CI e refatoração, em paralelo aos passos acima |
| 10 | Nathan | Rodar os testes T1 a T12 e registrar o resultado nesta nota |

## 11. Riscos e rollback

- **Ligar `IDENTIDADE_EXIGIR_TOKEN` derruba o login do BFF** se o `fetchMenu` (resto do H2) não for isentado ou não mandar o token. Por isso o passo 6 vem depois do 3. Rollback: reverter o commit (a variável volta ao padrão `false`).
- **Tornar a validação do Azure fixa** barra o login de quem estiver com sessão em ponta sem `id_token`; o passo 4 só roda com H1 em produção. Rollback: reverter o commit.
- **Chave do MES e do pipeline restritas a `rotas_permitidas`** podem negar uma rota que eles usam e ninguém lembrou. Fazer primeiro em modo **só registro** (logar o que seria negado por 3 a 5 dias, sem negar) e só então aplicar. Rollback: voltar a chave para `admin` (cadastro em `auth.chaves_servico`, sem deploy; o cache de 30 s limita a demora).
- **Trocar o `DB_USER` da API** pode falhar por `GRANT` faltando (erro 500 em rotas pouco usadas). Rodar a suíte de testes e um passeio nas telas do HUB na homologação antes. Rollback: voltar o `DB_USER` antigo.
- **`CREATE INDEX CONCURRENTLY`** não bloqueia escrita, mas é lento em tabela grande e não roda dentro de transação. Fazer fora do horário de uso.
- **Trocar `double precision` por `numeric`** exige recriar views dependentes; testar em cópia do banco.

## 12. O que a auditoria confirmou como correto (para o contrato)

Para o DBA saber o que **não** mexer:

- **SQL:** sem injeção encontrada; os filtros usam `replacements`/`bind`, e o que é interpolado vem de lista fixa (ordenação por `parseOrder`, `LIMIT` por `parseInteiro` com mínimo e máximo, nomes de view em constantes). Os dois `literal` com texto livre usam `sequelize.escape`.
- **JWT:** `HS256` fixo no `verify`, `issuer`, `typ`, `sub` UUID, `ver` inteiro; segredo de pelo menos 32 caracteres obrigatório no boot; TTL de 15 min; permissões lidas do banco em toda requisição (remover permissão vale na hora); revogação por `token_versao`; falha do banco devolve 503, nunca libera.
- **Senha:** bcrypt de custo 12 feito no banco por gatilho; coluna de senha só em `auth.usuarios`; `auth.chaves_servico` guarda só o `sha256`.
- **Estrutura:** 124 tabelas, todas com chave primária; 175 chaves estrangeiras; 180 `CHECK`; 250 índices; 125 gatilhos; dinheiro em `numeric`.
- **Docker:** usuário sem root, `NODE_ENV=production`, `HEALTHCHECK`; `.env*` fora do git; nenhum segredo no código-fonte.

## 13. O que a auditoria não verificou

- Valores reais de `.env` e do Coolify; `GRANT`s e privilégios por schema; conteúdo de `auth.rotas_telas`, `auth.telas` e `auth.rotas_administrativas`.
- Resultado de `npm audit` da API; versões instaladas de `express-rate-limit`, `jsonwebtoken` e afins (só li o `package.json`).
- Execução real: não subi a API; S22 (hash no 201) e S5 vêm de leitura.
- Todas as 124 rotas uma a uma. Li em profundidade as de autenticação, `usuarios`, `organograma/node`, trechos de `pedidos_vendas`, `pedidos_liberacao`, `orcamento`, `dashboard` e `vw_comissao_nf`; o resto por busca textual, então pode haver outros desvios dos padrões acima.
- A contagem de 77 chaves estrangeiras sem índice é estimativa (compostas cobertas por índices parciais podem ser falsos positivos).
- Os jobs do MES (`*.job.js`), `catalogoOmie.js`, `mesFluxo.js` e `ipRulesCache`.
- O corpo de `public.set_updated_at()`.

## 14. Ligações

[[Chaves-e-Autenticacao]] · [[RBAC-e-Permissoes]] · [[AV-Hub-API]] · [[Banco-AvHub]] · [[Riscos]] (RS-003, RS-020) · [[Backlog-por-Frente]] (BL-018, BL-024, BL-056 a BL-061) · [[LOG-40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]] · [[LOG-41-Login-Rate-Limit-no-Backend]] · [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]]
