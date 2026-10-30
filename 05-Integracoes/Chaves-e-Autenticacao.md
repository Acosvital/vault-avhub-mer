---
tags: [integracao, seguranca, chaves, autenticacao, av-hub, mes, pipeline]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Gustavo (DBA)
fontes: [api-acos-vital develop 0384e89 em 29/10 (apiKeyAuth.js, acessoConfig.js, docs/rotas.js; antes f322dcd), api-pcp develop befd973, app-pcp 1fca8d3, omie-elt-pipeline 0f739f0, av-hub develop 758d5f0 em 29/10 (antes b55ac55), v1 Chaves-de-Integracao-AvHub-MES-Pipeline, Registro-de-Decisoes #8 #9 #10 #11 #12 #87 #88]
---

# Chaves e autenticação

**Em uma frase:** esta nota lista as chaves (senhas de serviço) que os sistemas usam para se identificar entre si, o que cada uma abre e o que falta endurecer. **Só nomes de variáveis, nunca valores.**

**Quando consultar esta nota:** ao configurar um ambiente, trocar uma chave ou investigar erro 401 ("não identificado") ou 403 ("sem permissão") entre sistemas. Quem chama quem: [[Integracao-AvHub-MES]]. Os valores por ambiente não foram conferidos ❓.

## Quem manda dado para quem, quando e por quê

Cada chave serve a uma ligação específica. Todas viajam no cabeçalho `x-api-key` da chamada.

- **Chave A: MES para av-hub.** Serve só para o MES enviar a requisição de compra. Abre uma única rota; qualquer outra dá 403.
- **Chave B: MES para av-hub (leitura e confirmação).** Serve para ler pedidos liberados, eventos de requisição e a referência da OC, e para confirmar o "importado". Se for chave do `.env` (`API_KEYS`), dá acesso total; se for do banco, pode ser presa a uma lista de rotas (veja abaixo). ❓ Não se sabe qual das duas está em produção.
- **Chave C: pipeline para av-hub.** Serve para a fila de ordens de compra que a pipeline envia ao Omie. Mesma situação da chave B.
- **Chave D: av-hub para MES.** Serve para ler etapa e custo dos itens e a Torre de Fluxo.
- **Chave E: tela do MES para a API do MES.** É interna ao MES.
- **Chave F: página de documentação** `/docs` da API. Só vai pré-preenchida se for chave de leitura do banco; além dela, a página sai com o token de 15 minutos do próprio usuário logado no Azure ✅.
- **Chave G: HUB para a API comercial.** Não é mais usada: o código do Hub não lê a `COMERCIAL_API_KEY` (conferido em 29/10/2026) e a `api-comercial` ficou só para leitura (N16-117). Os dados do comercial vêm da API do Hub; sobre o legado, veja [[API-Comercial]]. ✅

## O que ainda não está bom

- **Já existe no código** (desde 15/10, `api-acos-vital` `b02d6c5`, migration 051) a chave do banco presa a rotas: cada chave tem `modo_rotas` (`livre`, `registrar` ou `exigir`) e uma lista de rotas ✅. Falta, para MES e pipeline, **cadastrar a lista e passar a chave para o modo `exigir`**. Em que modo cada chave está em produção ❓ (Gustavo, BL-018 e BL-057). Quando isso for feito, o Robert troca a variável da chave no MES e confere que as rotas que o MES chama estão na lista, senão leva 403.
- A chave do `.env` (`API_KEYS`) sem login de usuário continua dispensando permissão, escopo e identidade enquanto `IDENTIDADE_EXIGIR_TOKEN` for `false` (padrão). Falta ligar e fixar essa variável (LOG-51 S1, parte 2). A API já isenta a chamada do menu do login (`rotaDispensaToken`), então o HUB não precisa mudar nada. Desenho: [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]].
- O BFF do HUB já manda o token do usuário em todos os ajudantes de chamada; só as chamadas do login em `app/api/auth/[...nextauth]/route.ts` vão só com a chave, e é o esperado (conferido em 29/10, veja [[Mapa-Rotas-BFF-Bearer]]). A PS-018 está atendida no código; o Nathan decide encerrá-la.
- Falta conferir valores e presença das variáveis nos ambientes reais (PS-019) e a exposição pública do `api-pcp` (RS-009).

## Como trocar uma chave

O cadastro de chaves no banco é do DBA e não tem tela. Cadastro ou revogação no banco leva até 30 segundos para valer. Troque sempre nos dois lados da ligação. As listas aceitam chave nova e antiga ao mesmo tempo durante a troca.

A tabela de regras que já viraram fixas, o mapa completo das chaves e as rotas de cada chave estão no detalhe.

## Detalhe técnico

**Só nomes de variáveis, nunca valores.** Todas as chaves de serviço viajam no header `x-api-key`. Os valores por ambiente não foram conferidos ❓. Quem chama quem: [[Integracao-AvHub-MES]].

### Mapa das chaves

| Chave | Direção | Variável no emissor | Variável no receptor | Vale para | Selo |
|---|---|---|---|---|---|
| A, requisição | MES para av-hub | `api-pcp`: `AVHUB_MES_INTEGRACAO_KEY` (singular) ✅ `envio-avhub.service.ts:98` | `api-acos-vital`: `MES_INTEGRACAO_KEYS` (lista, plural) ✅ `apiKeyAuth.js` | **só** `PUT /compras/requisicoes/origem/:id`; qualquer outra rota ou método dá 403 `CHAVE_MES_ROTA_NAO_PERMITIDA`. Mínimo de 32 caracteres; as curtas são ignoradas com aviso | ✅ |
| B, leitura e confirmação do MES | MES para av-hub | `api-pcp`: `API_KEY` e `API_URL` ✅ `omie-integracao.ts:149`, `eventos-avhub.service.ts:192`, `produtos-avhub.client.ts:60` | `api-acos-vital`: `API_KEYS` (admin) ou `auth.chaves_servico` | pedidos liberados, `importado`, eventos de requisição (35), referência da OC (004/007) e das requisições (API-009), produtos, unidades. **Acesso total se for chave `API_KEYS`**; com chave do banco em modo `exigir`, só as rotas da lista | ✅ código; modo em produção ❓ (BL-018) |
| C, pipeline | pipeline para av-hub | `omie-elt-pipeline`: `AVHUB_API_URL`, `AVHUB_API_KEY` ✅ `src/config/index.ts:164-165` | `API_KEYS` ou `auth.chaves_servico` | `GET /compras/ordens/fila-omie`, `PATCH /compras/ordens/:id/sincronizacao`, `POST :id/reenviar` | ✅ código; modo em produção ❓ (BL-018) |
| D, av-hub lê o MES | av-hub para MES | `api-acos-vital`: `MES_API_URL`, `MES_API_KEY` ✅ `app.js`, `utils/mesFluxo.js` | `api-pcp`: `MES_API_KEY` (guard fail-closed, 401 sem a variável) ✅ `avhub-api-key.guard.ts:11-23` | `GET /itens/status` (005), `GET /requisicoes-compra` (003, legado), `GET /itens/custo` (008; rota feita só na `develop` do MES, `6c11147` de 27/10), `GET /fluxo/*` (46; o MES ainda não tem o módulo 🔴) | ✅ |
| E, BFF do MES | app-pcp para api-pcp | `app-pcp`: `MES_INTERNAL_API_KEY` ✅ `app/api/auth/[...nextauth]/route.ts:58` | `api-pcp`: `MES_INTERNAL_API_KEY` ✅ `auth/guards/api-key.guard.ts:15-20` | `/auth/azure` e rotas do BFF | ✅ |
| F, documentação | navegador | `api-acos-vital`: `DOCS_API_KEY` (pré-preenche a chave no `/docs` só se for chave de leitura do banco) ✅ `docs/rotas.js`, `docs/pagina.js` | | só a página `/docs` | ✅ |
| G, Comercial | HUB para `api-comercial` | `COMERCIAL_API_KEY` | `api-comercial` | **aposentada**: o código do Hub não lê mais esta chave nem `COMERCIAL_API_URL` (conferido em 29/10/2026; o BFF do comercial chama a API do Hub, `lib/api/comercialApi.ts`, `3bccfce`) e a `api-comercial` é só leitura (N16-117), ver [[API-Comercial]] | ✅ |

O nome do lado do MES na chave A é `AVHUB_MES_INTEGRACAO_KEY` (singular), e o valor é **um** dos valores da lista `MES_INTEGRACAO_KEYS` do hub ✅ (#11). Qualquer nota que diga `...KEYS` no lado do MES está errada.

### Tipos de chave que a API do av-hub reconhece

`apiKeyAuth.js` conhece três tipos ✅:

1. **`API_KEYS` (ambiente)**: admin. Vale como `acesso: "admin"`; `exigeUsuario` depende de `IDENTIDADE_EXIGIR_TOKEN`. Guardada como hash SHA-256 e comparada em tempo constante (S14).
2. **`auth.chaves_servico` (banco)**: nível `leitura` (só GET, HEAD, OPTIONS; escrita dá 403 `CHAVE_SOMENTE_LEITURA`), `escrita` ou `admin`. Rota administrativa (`auth.fn_rota_administrativa`) só com chave admin ou token de usuário (403 `CHAVE_SEM_ACESSO_ADMINISTRATIVO`). Cache de 30 s por hash, aceita chave de 16 a 200 caracteres. **Restrição por rota ✅ desde a migration 051 (15/10):** `modo_rotas` `livre` (padrão de toda chave), `registrar` (deixa passar e anota o uso em `auth.chaves_servico_uso`) ou `exigir` (rota fora de `auth.chaves_servico_rotas` dá 403 `CHAVE_ROTA_NAO_PERMITIDA`). Não vale para `API_KEYS` nem para a chave do MES.
3. **`MES_INTEGRACAO_KEYS`**: a chave A. Conferida antes de `API_KEYS`; descarta `Authorization`, `id_usuario_sessao` e os campos de autoria do corpo (ninguém forja autoria).

Falha de validação no banco responde 503. Mais de 30 falhas de chave por IP em 60 s dão 429 `MUITAS_FALHAS_DE_CHAVE` (S5). Rotas públicas: `/health`, `/docs`, `/favicon.ico`, `/auth` (`/blog` saiu, S20; `middlewares/_comum.js`).

### Quais rotas cada chave abre para o MES

| Rota que o MES chama | Chave A | Chave B |
|---|---|---|
| `PUT /compras/requisicoes/origem/:id` (34) | sim, a única | sim |
| `GET /pedidos_liberados`, `/:n/itens`, `POST /:n/importado` (26) | 403 | sim |
| `GET /compras/requisicoes/eventos` (35) | 403 | sim |
| `GET /ordens-compra/referencia` (004, 007) | 403 | sim (o MES a lê desde 15/10, job K4 na `develop`, BL-001) |
| `GET /compras/requisicoes/referencia` (API-009) | 403 | sim (o MES a lê desde 23/10, `develop`) |
| `GET /unidades`, `GET /produtos` | 403 | sim |

Por isso o MES lê com chave admin ou do banco. **A pendência L6 segue aberta na produção**: a restrição por rota existe no código, mas falta cadastrar a lista de rotas do MES e do pipeline e ligar o modo `exigir` ❓. Escrita do MES (`POST /pedidos_liberados/:n/importado`) e do pipeline (`PATCH .../sincronizacao`) obriga nível `escrita` no mínimo; o nível `leitura` não serve ❓. Decisão da chave restrita: 🔴 Gustavo ([[Registro-de-Decisoes]] #10; [[Backlog-por-Frente]] BL-018 e BL-057).

### Token do usuário e regras que viraram fixas

| Regra | Estado no código | Selo |
|---|---|---|
| Permissão por rota (`PERMISSOES_ROTA_MODO`) | fixa em `exigir` desde 08/10: chamada **com** Bearer passa por `auth.rotas_telas`; rota sem linha dá 403 `ROTA_SEM_PERMISSAO_MAPEADA`; sem Bearer nada muda. Exige `USUARIO_TOKEN_SEGREDO` (`acessoConfig.js`) | ✅ (6317d5f) |
| Escopo de vendedores | **fixo** no código desde 09/10 (contrato 40; a chave `ESCOPO_VENDEDORES_EXIGIR` não é mais lida) (`acessoConfig.js`) | ✅ |
| Limite de falhas de login | fixo desde 09/10 (contrato 41): 5 falhas em 900 s por e-mail ou IP+e-mail; a 6ª recebe 429 `LOGIN_LIMITE` (`acessoConfig.js`) | ✅ |
| Auditoria, NF manual, pedido manual, acompanhamento do CCP | fixos no código; as funções que devolviam sempre `true` saíram (LOG-51 S26) e a regra é aplicada direto | ✅ |
| `IDENTIDADE_EXIGIR_TOKEN` | segue chave de ambiente, padrão `false` (`acessoConfig.js`) | ✅ (ligar sem separar as chaves de serviço quebraria MES e pipeline) |
| `ESCOPO_UNIDADE_EXIGIR_SESSAO` | segue chave (`escopoUnidade.js`, `escopoSetor.js`) | ✅ |
| Validação do `id_token` do Azure | **fixa** desde 16/10 (LOG-51 S2); a variável `AUTENTICACAO_AZURE_VALIDAR_ID_TOKEN` não é mais lida (`azureIdToken.js`, `acessoConfig.js`) | ✅ |
| `VENDAS_PLANILHA_PAGINAR_POR_PEDIDO` | segue chave, padrão `false` (`vw_vendas_planilha.route.js`) | ✅ |

As três últimas só podem ser fixadas depois de separar as chaves de serviço (BL-018). O registro anterior dizia que `ESCOPO_VENDEDORES_EXIGIR` não estava fixado: o código já o fixou (ver [[Contradicoes-Resolvidas]] CR-15).

### Front do HUB

- Os helpers do BFF (`headersDaApi()` em `HUB lib/api/escopoUnidade.ts:45`; `headersApi = () => headersDaApi()` em `lib/api/pedidosVenda.ts:96`) mandam `x-api-key` e, havendo sessão, `Authorization: Bearer`, sem variável de ambiente ✅ (#88, HUB b55ac55). Sem Bearer a API trata a chamada como serviço, sem escopo nem permissão por tela. Reauditado em 29/10/2026 (`av-hub` develop `758d5f0`): todos os ajudantes (`headersComIdentidade`, `headersDaApi`, `headersCompras`, `headersApi`) mandam o Bearer quando a sessão tem token; a chave sozinha só aparece nas quatro chamadas do login (`/autenticacao/azure`, `/autenticacao/login`, `/autenticacao/renovar` e `fetchMenu`) ✅ → [[Pontas-Soltas]] PS-018. Desde a PR #206 (HUB `d0ef359`) o token é lido do cookie no servidor e não vai na sessão do navegador, e `requirePermission` responde 401 sem ele.
- Páginas e permissões: [[RBAC-e-Permissoes]]; rotas do BFF: [[Mapa-Rotas-BFF-Bearer]].

### Guards do MES

`api-pcp` tem `JwtAuthGuard` e `PermissionsGuard` como `APP_GUARD` global (nega por padrão) ✅ `app.module.ts` (PR #51, e8f951e). Rotas públicas só com `@Public()`: health, login, Azure e as duas de `integracao-avhub` (protegidas por `MES_API_KEY`). Exposição pública do `api-pcp` no Coolify: 🔴 Gustavo (#13, [[Riscos]] RS-009).

### Cadastro e rotação

- Cadastro em `auth.chaves_servico` é do **DBA**; não há tela. Cache de 30 s: cadastro ou revogação leva até 30 s.
- `API_KEYS` e `MES_INTEGRACAO_KEYS` são listas separadas por vírgula, o que permite sobrepor a chave nova e a antiga na troca ✅ (`apiKeyAuth.js`). O procedimento escrito está no PDF `docs/arquitetura/chaves-integracao-avhub-mes-pipeline.pdf` do repo do HUB (não transcrito).
- Trocar sempre nos dois lados (tabela de mapa acima).
- `MES_INTEGRACAO_KEYS`: mínimo de 32 caracteres.
- Regra do Nathan: nenhuma regra em variável de ambiente nos jobs novos; só endereço e segredo ficam no ambiente ✅ (`item_estado_projetado.job.js:38-49`).

### Pendências

| ID | Pendência | Dono |
|---|---|---|
| BL-018 | chave de serviço com escopo mínimo para MES e pipeline (L6) | Gustavo |
| PS-018 | reauditar BFF do HUB: tudo manda Bearer | Nathan |
| PS-019 | conferir valores e presença das variáveis nos ambientes reais | Gustavo |
| RS-009 | exposição pública do `api-pcp` | Gustavo |

Ver também: [[Registro-de-Decisoes]], [[Infraestrutura]].

### Endurecimento (auditoria de 15/10/2026)

A auditoria da `api-acos-vital` (`276dab8`) achou que a chave de `API_KEYS` sem token **dispensa permissão, escopo e identidade** (`exigirToken` com padrão `false`, `acessoConfig.js`) e que `POST /autenticacao/azure` emitia JWT só com o e-mail. Desenho da correção, ordem e testes: [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] (S1 e S2), com o lado do HUB no BL-058. Situação conferida em 29/10/2026:

- **Login Azure:** a validação do `id_token` é fixa desde 16/10 (S2) ✅ e o HUB manda o `id_token` (PR #206). Testado em homologação em 28/10 (Nathan: login Azure, login por senha e sessão ociosa funcionaram, BL-058).
- **`fetchMenu`:** a API já isenta `GET /permissoes_usuario/menu/:id_usuario` quando a chave exige token (`rotaDispensaToken`, S1 parte 2), com o id preso ao do token ✅. Nada a fazer no HUB.
- **Falta:** ligar e fixar `IDENTIDADE_EXIGIR_TOKEN` (depende de separar as chaves de MES e pipeline) e cadastrar as listas de rotas das chaves de serviço; os valores reais em produção seguem ❓ (Gustavo, perguntas Q1 a Q4 do LOG-51).
