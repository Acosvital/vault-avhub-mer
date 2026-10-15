---
tags: [integracao, seguranca, chaves, autenticacao, av-hub, mes, pipeline]
criado: 2026-10-14
atualizado: 2026-10-15
status: vigente
dono: Gustavo (DBA)
fontes: [api-acos-vital f322dcd (apiKeyAuth.js, acessoConfig.js), api-pcp 579a625, app-pcp 1fca8d3, omie-elt-pipeline 0f739f0, HUB b55ac55, v1 Chaves-de-Integracao-AvHub-MES-Pipeline, Registro-de-Decisoes #8 #9 #10 #11 #12 #87 #88]
---

# Chaves e autenticação

**Só nomes de variáveis, nunca valores.** Todas as chaves de serviço viajam no header `x-api-key`. Os valores por ambiente não foram conferidos ❓. Quem chama quem: [[Integracao-AvHub-MES]].

## Mapa das chaves

| Chave | Direção | Variável no emissor | Variável no receptor | Vale para | Selo |
|---|---|---|---|---|---|
| A, requisição | MES para av-hub | `api-pcp`: `AVHUB_MES_INTEGRACAO_KEY` (singular) ✅ `envio-avhub.service.ts:98` | `api-acos-vital`: `MES_INTEGRACAO_KEYS` (lista, plural) ✅ `apiKeyAuth.js:59` | **só** `PUT /compras/requisicoes/origem/:id`; qualquer outra rota ou método dá 403 `CHAVE_MES_ROTA_NAO_PERMITIDA` (`:143-149`). Mínimo de 32 caracteres; as curtas são ignoradas com aviso (`:57-67`) | ✅ |
| B, leitura e confirmação do MES | MES para av-hub | `api-pcp`: `API_KEY` e `API_URL` ✅ `omie-integracao.ts:149`, `eventos-avhub.service.ts:192`, `produtos-avhub.client.ts:60` | `api-acos-vital`: `API_KEYS` (admin) ou `auth.chaves_servico` | pedidos liberados, `importado`, eventos de requisição (35), produtos, unidades. **Acesso total (admin) hoje** | ✅ ; restrição 🔴 BL-018 |
| C, pipeline | pipeline para av-hub | `omie-elt-pipeline`: `AVHUB_API_URL`, `AVHUB_API_KEY` ✅ `src/config/index.ts:164-165` | `API_KEYS` ou `auth.chaves_servico` | `GET /compras/ordens/fila-omie`, `PATCH /compras/ordens/:id/sincronizacao`, `POST :id/reenviar` | ✅ ; restrição 🔴 BL-018 |
| D, av-hub lê o MES | av-hub para MES | `api-acos-vital`: `MES_API_URL`, `MES_API_KEY` ✅ `app.js:25-29`, `item_estado_projetado.job.js:38` | `api-pcp`: `MES_API_KEY` (guard fail-closed, 401 sem a variável) ✅ `avhub-api-key.guard.ts:11-23` | `GET /itens/status` (005), `GET /requisicoes-compra` (003, legado), `GET /itens/custo` (008, sem rota 🔴), `GET /fluxo/*` (46, sem módulo 🔴) | ✅ |
| E, BFF do MES | app-pcp para api-pcp | `app-pcp`: `MES_INTERNAL_API_KEY` ✅ `app/api/auth/[...nextauth]/route.ts:58` | `api-pcp`: `MES_INTERNAL_API_KEY` ✅ `auth/guards/api-key.guard.ts:15-20` | `/auth/azure` e rotas do BFF | ✅ |
| F, documentação | navegador | `api-acos-vital`: `DOCS_API_KEY` (pré-preenche a chave no `/docs`) ✅ `docs/pagina.js:94` | | só a página `/docs` | ✅ |
| G, Comercial | HUB para `api-comercial` | `COMERCIAL_API_KEY` | `api-comercial` | outra integração: [[API-Comercial]] | ❓ |

O nome do lado do MES na chave A é `AVHUB_MES_INTEGRACAO_KEY` (singular), e o valor é **um** dos valores da lista `MES_INTEGRACAO_KEYS` do hub ✅ (#11). Qualquer nota que diga `...KEYS` no lado do MES está errada.

## Tipos de chave que a API do av-hub reconhece

`apiKeyAuth.js` conhece três tipos ✅:

1. **`API_KEYS` (ambiente)**: admin. Vale como `acesso: "admin"`; `exigeUsuario` depende de `IDENTIDADE_EXIGIR_TOKEN` (`:160-161`).
2. **`auth.chaves_servico` (banco)**: nível `leitura` (só GET, HEAD, OPTIONS; escrita dá 403 `CHAVE_SOMENTE_LEITURA`, `:172-177`), `escrita` ou `admin`. Rota administrativa (`auth.fn_rota_administrativa`) só com chave admin ou token de usuário (403 `CHAVE_SEM_ACESSO_ADMINISTRATIVO`, `:178-184`). Cache de 30 s por hash (`:94`), aceita chave de 16 a 200 caracteres (`:162`). **Não há restrição por rota**.
3. **`MES_INTEGRACAO_KEYS`**: a chave A. Conferida antes de `API_KEYS`; descarta `Authorization`, `id_usuario_sessao` e os campos de autoria do corpo (ninguém forja autoria) (`:150-155`).

Falha de validação no banco responde 503 (`:187-189`). Rotas públicas: `/health`, `/docs`, `/favicon.ico`, `/auth`, `/blog` (`:49`).

## Quais rotas cada chave abre para o MES

| Rota que o MES chama | Chave A | Chave B |
|---|---|---|
| `PUT /compras/requisicoes/origem/:id` (34) | sim, a única | sim |
| `GET /pedidos_liberados`, `/:n/itens`, `POST /:n/importado` (26) | 403 | sim |
| `GET /compras/requisicoes/eventos` (35) | 403 | sim |
| `GET /ordens-compra/referencia` (004, 007) | 403 | sim (o MES não a chama 🔴 BL-001) |
| `GET /unidades`, `GET /produtos` | 403 | sim |

Por isso o MES lê com chave admin ou do banco. **A pendência L6 segue aberta**: não existe chave "de leitura mais confirmação" restrita às rotas do MES, nem para o pipeline. Escrita do MES (`POST /pedidos_liberados/:n/importado`) e do pipeline (`PATCH .../sincronizacao`) obriga nível `escrita` no mínimo; o nível `leitura` não serve ❓. Decisão da chave restrita: 🔴 Gustavo ([[Registro-de-Decisoes]] #10; [[Backlog-por-Frente]] BL-018).

## Token do usuário e regras que viraram fixas

| Regra | Estado no código | Selo |
|---|---|---|
| Permissão por rota (`PERMISSOES_ROTA_MODO`) | fixa em `exigir` desde 08/10: chamada **com** Bearer passa por `auth.rotas_telas`; rota sem linha dá 403 `ROTA_SEM_PERMISSAO_MAPEADA`; sem Bearer nada muda. Exige `USUARIO_TOKEN_SEGREDO` (`acessoConfig.js:13-20`) | ✅ (6317d5f) |
| Escopo de vendedores | **fixo** no código desde 09/10 (contrato 40; a chave `ESCOPO_VENDEDORES_EXIGIR` não é mais lida) (`acessoConfig.js:23-31`, `:74-76`) | ✅ |
| Limite de falhas de login | fixo desde 09/10 (contrato 41): 5 falhas em 900 s por e-mail ou IP+e-mail; a 6ª recebe 429 `LOGIN_LIMITE` (`:78-82`) | ✅ |
| Auditoria, NF manual, pedido manual, acompanhamento do CCP | fixos em `true` (`:68-72`) | ✅ |
| `IDENTIDADE_EXIGIR_TOKEN` | segue chave de ambiente, padrão `false` (`:71`) | ✅ (quebraria MES e pipeline) |
| `ESCOPO_UNIDADE_EXIGIR_SESSAO` | segue chave (`escopoUnidade.js:48`, `escopoSetor.js:65`) | ✅ |
| `AUTENTICACAO_AZURE_VALIDAR_ID_TOKEN` | segue chave, padrão `false` (`azureIdToken.js:27`) | ✅ |
| `VENDAS_PLANILHA_PAGINAR_POR_PEDIDO` | segue chave, padrão `false` (`vw_vendas_planilha.route.js:69`) | ✅ |

As quatro últimas só podem ser fixadas depois de separar as chaves de serviço (BL-018). O registro anterior dizia que `ESCOPO_VENDEDORES_EXIGIR` não estava fixado: o código já o fixou (ver [[Contradicoes-Resolvidas]] CR-15).

## Front do HUB

- Os helpers do BFF (`headersDaApi()` em `HUB lib/api/escopoUnidade.ts:45`; `headersApi = () => headersDaApi()` em `lib/api/pedidosVenda.ts:96`) mandam `x-api-key` e, havendo sessão, `Authorization: Bearer`, sem variável de ambiente ✅ (#88, HUB b55ac55). Sem Bearer a API trata a chamada como serviço, sem escopo nem permissão por tela. Rotas de BFF que ainda mandam só a chave: ❓ não reauditado desde 08/10 (a auditoria de 08/10 achou 38 arquivos; o PR #178 cobriu os helpers) → [[Pontas-Soltas]] PS-018.
- Páginas e permissões: [[RBAC-e-Permissoes]]; rotas do BFF: [[Mapa-Rotas-BFF-Bearer]].

## Guards do MES

`api-pcp` tem `JwtAuthGuard` e `PermissionsGuard` como `APP_GUARD` global (nega por padrão) ✅ `app.module.ts:90-91` (PR #51, e8f951e). Rotas públicas só com `@Public()`: health, login, Azure e as duas de `integracao-avhub` (protegidas por `MES_API_KEY`). Exposição pública do `api-pcp` no Coolify: 🔴 Gustavo (#13, [[Riscos]] RS-009).

## Cadastro e rotação

- Cadastro em `auth.chaves_servico` é do **DBA**; não há tela. Cache de 30 s: cadastro ou revogação leva até 30 s.
- `API_KEYS` e `MES_INTEGRACAO_KEYS` são listas separadas por vírgula, o que permite sobrepor a chave nova e a antiga na troca ✅ (`apiKeyAuth.js:52-68`). O procedimento escrito está no PDF `docs/arquitetura/chaves-integracao-avhub-mes-pipeline.pdf` do repo do HUB (não transcrito).
- Trocar sempre nos dois lados (tabela de mapa acima).
- `MES_INTEGRACAO_KEYS`: mínimo de 32 caracteres.
- Regra do Nathan: nenhuma regra em variável de ambiente nos jobs novos; só endereço e segredo ficam no ambiente ✅ (`item_estado_projetado.job.js:38-49`).

## Pendências

| ID | Pendência | Dono |
|---|---|---|
| BL-018 | chave de serviço com escopo mínimo para MES e pipeline (L6) | Gustavo |
| PS-018 | reauditar BFF do HUB: tudo manda Bearer | Nathan |
| PS-019 | conferir valores e presença das variáveis nos ambientes reais | Gustavo |
| RS-009 | exposição pública do `api-pcp` | Gustavo |

Ver também: [[Registro-de-Decisoes]], [[Infraestrutura]].

## Endurecimento pendente (auditoria de 15/10/2026)

A auditoria da `api-acos-vital` (`276dab8`) achou que a chave de `API_KEYS` sem token **dispensa permissão, escopo e identidade** (`apiKeyAuth.js:160-161`, `exigirToken` com padrão `false` em `acessoConfig.js:71`) e que `POST /autenticacao/azure` emite JWT só com o e-mail enquanto `AUTENTICACAO_AZURE_VALIDAR_ID_TOKEN` está desligado (padrão, `azureIdToken.js:27-28`). Desenho da correção, ordem e testes: [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] (S1 e S2), com o lado do HUB no BL-058.

- **Ordem importa:** ligar `IDENTIDADE_EXIGIR_TOKEN` derruba o login do BFF enquanto as 3 chamadas pré-login (`fetchMenu`, `fetchSlugDaTela`, `fetchInfoPerfisDoUsuario`) seguirem só com a chave, porque só `/autenticacao` e `/me` são isentas (`acessoConfig.js:95`).
- O HUB **não** manda o `id_token` do Azure hoje; sem isso a validação do `id_token` não pode ser fixada.
- Os valores reais dessas variáveis em produção seguem ❓ (Gustavo, perguntas Q1 a Q4 do LOG-51).
