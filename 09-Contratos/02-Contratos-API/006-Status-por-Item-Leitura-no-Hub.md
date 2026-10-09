---
tags: [contrato-api, mes, integracao-av-hub-mes, rastreabilidade, portal-vendedor]
status: implementada-no-codigo
criado: 2026-10-08
atualizado: 2026-10-09
---

# Contrato de API 006 — Leitura do status por item no hub (job + rota)

> **(atualizado em 09/10/2026)** Este texto é a **especificação de 08/10** que o DBA recebeu; o que ela descrevia como "não existe" **já foi implementado** (`dee35b0`, 08/10, `api-acos-vital`; `fe55923` para a rota da referência da OC). A seção **Implementação conferida no código (09/10/2026)**, ao final, descreve o que o código faz hoje, com arquivo e linha. Produção não verificada.

> Status: **proposta (08/10/2026), para o Gustavo (`api-acos-vital`).** Complementa o [[005-Status-Item-Integracao-MES]] (que descreve a rota do MES) com as duas peças que faltam **no hub**: o **job que lê o MES** e a **rota que o av-hub chama** para a tela 1.2. Depende do [[010-Itens-Pedido-Status]] (tabela). Nada disto existe.

## Peça 1 — job de leitura do MES (api-acos-vital)

- Chama `GET {MES_API_URL}/itens/status?alterado_desde=&codigo_empresa=&limit=1000` a cada **1 a 2 minutos**, **uma unidade por vez** (`core.unidades` ativas). Header `x-api-key: {MES_API_KEY}`.
- **Cursor** em `itens_pedido_status_cursor`: o maior `updated_at` já gravado com sucesso por unidade. Primeira leitura da unidade: `alterado_desde` = data de corte decidida pelo Nathan (sugestão: 30 dias).
- **Paginação:** enquanto a resposta vier com `limit` linhas, repetir com `alterado_desde` = `updated_at` da última linha (o MES ordena por `updated_at` crescente; `>=`, então tratar duplicata pela chave única). Parar quando vier menos que `limit`.
- **Gravação:** `INSERT ... ON CONFLICT (codigo_empresa, id_item_parcial, etapa, ocorrido_em) DO NOTHING`, tudo da página numa transação, depois avança o cursor. Falha do MES (rede, 5xx, 401): loga, **não avança o cursor** e tenta na próxima rodada. 401 repetido deve alertar (chave errada).
- **Parcial cancelada:** o job chama também com `incluir_deletados=true` uma vez por rodada longa (sugestão: a cada 15 min) para registrar `mes_deleted_at`.
- **Variáveis:** `MES_API_URL`, `MES_API_KEY`, `MES_STATUS_INTERVALO_SEG` (padrão 90), `MES_STATUS_CORTE_INICIAL_DIAS` (padrão 30). **Sem chave de ligar/desligar** (decisão de 07/10, item 9 do [[Registro-de-Decisoes-2026-10-07]]); sem `MES_API_URL` o job não sobe e avisa no log.
- Onde roda: mesmo processo da API ou worker próprio (decisão do Gustavo; a pipeline já usa worker próprio).

## Peça 2 — rota de leitura para o av-hub

### `GET /itens_pedido_status?codigo_empresa=&pedido_venda=&historico=`

| Parâmetro | Regra |
|---|---|
| `codigo_empresa` | obrigatório (uuid da unidade) |
| `pedido_venda` | obrigatório (número do pedido de venda) |
| `historico` | opcional, `true` devolve também as linhas anteriores de cada parcial; padrão `false` (só a atual) |

**Response (200)**, ordenada por `codigo_produto`, `id_item_parcial`, `ocorrido_em` decrescente:
```json
{
  "pedido_venda": "25970",
  "codigo_empresa": "uuid",
  "lido_em": "2026-10-08T15:20:11Z",
  "itens": [
    {
      "id_item_parcial": "uuid",
      "codigo_produto_omie": "9764577293",
      "codigo_produto": "FLG-CEGO-6-150",
      "ordem_producao": "OP-000123",
      "etapa": "fabrica.execucao",
      "setor": { "codigo": "FURACAO", "nome": "Furação", "tipo": "PRODUTIVO" },
      "status": "EM_ANDAMENTO",
      "quantidade_na_etapa": 4.0,
      "atendido_pelo_estoque": false,
      "ocorrido_em": "2026-10-08T14:02:00Z"
    }
  ]
}
```

- `lido_em` = quando o job gravou a linha mais recente do pedido; o BFF mostra "atualizado há N min" e avisa se passou de 10 minutos (o job parou).
- Pedido sem nenhuma linha: **200 com `itens: []`** (o pedido ainda não chegou ao MES). Não é 404.
- **Escopo de segurança (obrigatório):** a rota deve respeitar o escopo do vendedor como as demais rotas de vendas (`ESCOPO_VENDEDORES_EXIGIR` com token de usuário): vendedor só vê pedidos dele ou da equipe; gestor e diligenciador seguem a regra de [[AV-Hub-RBAC]]. **O hub aplica o filtro; o BFF não confia no `pedido_venda` recebido do navegador.**
- **Tela de permissão:** `meus-pedidos` (visualizar); `pedidos-equipe` e `pcp-pedidos` para as visões de equipe. Mapear em `auth.rotas_telas`: o modo `exigir` recusa rota sem mapa.
- **Erros:** 400 se `codigo_empresa` não for uuid ou `pedido_venda` faltar; 403 pelo escopo.

## O que o av-hub faz com isso

A tela 1.2 mostra, por item do pedido, a etapa atual da(s) parcial(is), a quantidade em cada etapa e a hora da última mudança. **Vocabulário provisório:** o BFF traduz `etapa` para rótulo com uma tabela no código (`lib/domain/etapasItem.ts`), com um rótulo genérico para etapa desconhecida. Item dividido em parciais em etapas diferentes aparece como várias linhas, uma por parcial, até a pergunta 3 do contrato 005 ser decidida.

## Perguntas em aberto

1. **Data de corte da primeira leitura** (Nathan): 30 dias ou outro.
2. **Agregação por pedido** (Nathan e Robert): etapa mais atrasada, ou lista de parciais? Esta versão devolve a lista.
3. **Onde roda o job** (Gustavo): no processo da API ou em worker próprio.
4. **Chave do MES:** o job usa a `MES_API_KEY` que o MES aceita hoje para o av-hub; a restrição por rota é a pendência L6 ([[Chaves-de-Integracao-AvHub-MES-Pipeline]]).

## Ver também
- [[005-Status-Item-Integracao-MES]]
- [[010-Itens-Pedido-Status]]
- [[Integracao-AvHub-MES-Volta-Plano]]
- [[AV-Hub-Portal-Vendedor-Plano]]
- [[Indice-Contratos]]


## Implementação conferida no código (09/10/2026)

> Status: decidido | no código | em produção (verificado em 09/10/2026): **✅ lado do hub implementado no código** (commit `dee35b0`, 08/10/2026, `origin/develop` da `api-acos-vital`; autor `HauntedCrusader`). **Produção não verificada.** **🔴 o front não consome a rota.** Fonte: [[Registro-de-Decisoes-2026-10-07]] (#42 e #43) e [[005-Status-Item-Integracao-MES]].

> **(atualizado em 09/10)** Este contrato descreve o que o hub faz com o que o MES expõe no [[005-Status-Item-Integracao-MES]]. O código do hub já cita "contrato 006" e "SQL 010" (`itens_pedido_status.route.js:6-8`, `.job.js:4-6`), então esta nota existe para fechar essa referência. Tudo abaixo vem da leitura do código em 09/10/2026; o que é dedução vem marcado com 🟡.

**Status:** `implementada-no-codigo` (hub). Rota, job e documentação Swagger existem na `develop`; o objeto de banco (migration `api005`) **não foi verificado**; a tela não existe.
**Destinatários:** backend do av-hub (`api-acos-vital`, Gustavo: opera job e rota), front do av-hub (consome a rota; tela 1.2 e tarefa E3) e MES (`api-pcp`, Robert: só precisa manter o `GET /itens/status` do 005 e a chave igual).

## 1. Finalidade

Mostrar ao vendedor e ao PCP **em que etapa está cada item (parcial) de um pedido de venda**, na tela 1.2 do av-hub: *Meus pedidos*, *Pedidos da equipe* e *Pedidos do PCP* (`itens_pedido_status.route.js:12-13`).

O hub **não chama o MES na hora da consulta**. A rota lê só a tabela local `itens_pedido_status`, que um job enche a partir do `GET /itens/status` do MES (`route.js:13-15`; Swagger, descrição da tag). Consequência: a tela mostra o que o hub leu da última vez, e a resposta traz `lido_em` para o front avisar quando o job está parado (seção 2).

```
MES  GET /itens/status  <──(job, a cada ~90 s)──  api-acos-vital  ──>  tabela local itens_pedido_status
                                                         │
                                  GET /itens_pedido_status (esta rota)
                                                         │
                                                  BFF do av-hub  ──>  tela 1.2
```

## 2. A rota

### `GET /itens_pedido_status?codigo_empresa=&pedido_venda=&historico=`

Montada em `/itens_pedido_status` (`core_vendas_faturamento/index.js`, no commit `dee35b0`). Handler: `itens_pedido_status.route.js:54-104`.

| Parâmetro | Obrigatório | Validação (linha) | Erro |
|---|---|---|---|
| `codigo_empresa` | sim | string e uuid (`route.js:58`) | 400 "codigo_empresa é obrigatório e deve ser um uuid" |
| `pedido_venda` | sim | string não vazia, após `trim()` (`:61`) e no máximo 40 caracteres (`:65`) | 400 "pedido_venda é obrigatório…" / "…mais de 40 caracteres" |
| `historico` | não | se vier, `true` ou `false`, sem diferenciar maiúscula (`:68`); omitido = `false` | 400 "historico deve ser true ou false" |

`codigo_empresa` é gravado em minúsculas na resposta (`:72`).

**Outros códigos** (Swagger e middlewares, não do handler):
- **403** `SEM_PERMISSAO` (sem a ação na tela), `ROTA_SEM_PERMISSAO_MAPEADA`, `PEDIDO_FORA_DO_ESCOPO` ou `SEM_VENDEDOR_VINCULADO` (seção 4).
- **404: não existe.** Pedido que ainda não chegou ao MES devolve **200 com `itens` vazio** (Swagger, descrição da rota).
- **500** "GET /itens_pedido_status exige a migration api005 no banco" quando faltam a função ou a tabela (códigos Postgres `42883`/`42P01`, `route.js:97-101`).

**A regra mora no banco.** O handler chama `core_vendas_faturamento.fn_itens_pedido_status_do_pedido(empresa, numero, historico)` (`route.js:74-78`), que escolhe a foto mais recente de cada parcial viva (ou todas, com `historico=true`) (`route.js:17-18`). Segundo o Swagger, a ordem é `codigo_produto`, `id_item_parcial`, `ocorrido_em` decrescente. O corpo da função **não foi lido** (🟡 vive na migration `api005`, fora do repositório consultado).

### Resposta (200)

Envelope (`route.js:90-95`):

| Campo | Tipo | Observação |
|---|---|---|
| `pedido_venda` | string | o número já com `trim()` |
| `codigo_empresa` | uuid | em minúsculas |
| `lido_em` | data-hora ou `null` | `atualizado_em` do cursor da unidade em `itens_pedido_status_cursor` (`route.js:84-88`): a **última leitura bem-sucedida do MES**, mesmo sem mudança no pedido. Passou de **10 minutos** = job parado ou MES fora (Swagger). `null` = o job ainda não leu a unidade |
| `itens` | array | uma linha por parcial; item dividido em parciais em etapas diferentes aparece em várias linhas |

Cada item (`montarItem`, `route.js:30-52`):

| Campo | Tipo | Observação |
|---|---|---|
| `id_item_parcial` | uuid | id da parcial no MES |
| `codigo_produto_omie` | string ou `null` | |
| `codigo_produto` | string ou `null` | |
| `ordem_producao` | string ou `null` | número da OP no MES (ex.: `OP-000123`) |
| `etapa` | string | vocabulário **provisório**, cru do MES (seção 5) |
| `setor` | objeto `{codigo, nome, tipo}` ou `null` | `null` se os três vierem vazios (`route.js:31-33`); `tipo` é `PRODUTIVO`, `ESTOQUE` etc. |
| `status` | string | status da parcial no MES, cru |
| `quantidade_na_etapa` | número ou `null` | convertido com `Number()` (`:42`) |
| `atendido_pelo_estoque` | boolean | |
| `ocorrido_em` | data-hora | `updated_at` da parcial no MES: a hora da **última mudança**, não a de entrada na etapa |
| `atual` | boolean | **só com `historico=true`**: `true` na foto que vale hoje (a mais recente de uma parcial não cancelada) |
| `cancelado_no_mes_em` | data-hora ou `null` | **só com `historico=true`**: preenchido quando a parcial foi cancelada no MES (vem de `mes_deleted_at`, `:49`) |

**Exemplo ilustrativo** (montado a partir do código; valores inventados), `historico=true`:

```json
{
  "pedido_venda": "25970",
  "codigo_empresa": "00000000-0000-0000-0000-000000000000",
  "lido_em": "2026-11-05T16:12:30.000Z",
  "itens": [
    {
      "id_item_parcial": "11111111-1111-1111-1111-111111111111",
      "codigo_produto_omie": "12345678",
      "codigo_produto": "FLG-CEGO-6-150",
      "ordem_producao": "OP-000123",
      "etapa": "fabrica.execucao",
      "setor": { "codigo": "CORTE", "nome": "Corte", "tipo": "PRODUTIVO" },
      "status": "EM_ANDAMENTO",
      "quantidade_na_etapa": 120,
      "atendido_pelo_estoque": false,
      "ocorrido_em": "2026-11-05T16:10:00.000Z",
      "atual": true,
      "cancelado_no_mes_em": null
    },
    {
      "id_item_parcial": "11111111-1111-1111-1111-111111111111",
      "codigo_produto_omie": "12345678",
      "codigo_produto": "FLG-CEGO-6-150",
      "ordem_producao": "OP-000123",
      "etapa": "fabrica.espera",
      "setor": { "codigo": "CORTE", "nome": "Corte", "tipo": "PRODUTIVO" },
      "status": "PENDENTE",
      "quantidade_na_etapa": 120,
      "atendido_pelo_estoque": false,
      "ocorrido_em": "2026-11-05T09:40:00.000Z",
      "atual": false,
      "cancelado_no_mes_em": null
    }
  ]
}
```

Sem `historico`, a resposta traz só a primeira linha e sem os campos `atual` e `cancelado_no_mes_em`.

## 3. O job de leitura

Arquivo: `itens_pedido_status.job.js`. Roda **no mesmo processo da API** (decisão do Gustavo, 08/10/2026, `job.js:8`), iniciado em `app.js` depois do `listen` (`iniciarJobStatusItensMes()`, `app.js:203`).

| Item | Valor (linha) |
|---|---|
| Intervalo | `MES_STATUS_INTERVALO_SEG`, padrão **90 s**, mínimo 1 (`job.js:217`). A próxima rodada só começa depois que a anterior termina (`setTimeout` encadeado, `:223-231`). Primeira rodada em até 5 s |
| `MES_API_URL` | URL base do `api-pcp`, sem `/itens/status`. Sem ela o job **não sobe** e avisa no log (`:206-209`) |
| `MES_API_KEY` | enviada em `x-api-key`; sem ela o job não sobe (`:210-213`). Comentário do código: "a mesma do contrato 003" (`:35-36`) |
| `MES_STATUS_CORTE_INICIAL_DIAS` | padrão 30: a 1ª leitura de uma unidade, sem cursor, começa N dias atrás (`:38-39`) |
| Chamada | `GET {MES_API_URL}/itens/status?alterado_desde=<cursor>&codigo_empresa=<uuid>&incluir_deletados=true&limit=1000` (`:62-73`); timeout de 30 s (`:43`) |
| Unidades | todas de `core.unidades` com `deleted_at` nulo, **uma por vez** (`:165-171`) |
| Paginação | `limit=1000`. Página cheia = lê de novo a partir do novo cursor; menos que 1000 = acabou (`:148`). No máximo 50 páginas por unidade por rodada (`:42`) |
| Gravação | `fn_itens_pedido_status_gravar(empresa, desde, linhas jsonb)` (migration `api005`): valida as linhas, faz INSERT idempotente pela chave do contrato 005 e avança o cursor. Linhas inválidas voltam em `ignoradas` e vão ao log (`:122-142`) |
| `incluir_deletados=true` | em **toda** leitura. O 006 sugeria uma leitura à parte a cada 15 min; o código preferiu o mesmo cursor, para a parcial cancelada não se perder (`:26-29`) |
| Concorrência | cada página roda numa transação com `pg_try_advisory_xact_lock` por unidade; com mais de uma instância da API só uma lê a unidade, a outra pula (`:20-23`, `:103-107`) |
| Falha | erro de rede, timeout, 5xx ou 401 **desfaz a transação**: o cursor não anda e a página é relida na próxima rodada (`:22-24`) |
| Alerta | **3** respostas 401/403 seguidas do MES geram `ALERTA` no log ("Conferir MES_API_KEY", `:44`, `:173-178`) |
| Alerta de cursor | 1000 parciais com o mesmo `updated_at`: o cursor não avança e o log avisa (`:149-154`) |
| Sem a migration | log "objetos da migration api005 ausentes no banco" e a rodada para (`:182-186`) |

Não há chave de liga/desliga (decisão de 07/10, item 9 do Registro de Decisões, `:30-31`): o job liga se `MES_API_URL` e `MES_API_KEY` existirem.

**Lado do MES** (`api-pcp`, `integracao-avhub.controller.ts:22-25` e `integracao-avhub.service.ts:114`): `GET /itens/status` devolve, por parcial, `id_item_parcial`, `codigo_empresa`, `pedido_venda`, `codigo_pedido_omie`, `ordem_producao`, `codigo_produto_omie`, `codigo_produto`, `etapa`, `setor`, `status`, `quantidade_na_etapa`, `atendido_pelo_estoque`, `ocorrido_em`, `updated_at` e `deleted_at`. Detalhes no [[005-Status-Item-Integracao-MES]].

## 4. Escopo e permissão

- **Regra "dono" por `pedido_venda_query`** (`middlewares/escopoVendedor.js:53` e `:131-142`): com `ESCOPO_VENDEDORES_EXIGIR=true`, token de usuário e escopo diferente de "todos" (`:93-94`), o middleware busca em `core_vendas_faturamento.pedidos_vendas` o par `codigo_empresa` + `numero_pedido` e confere se algum dono está entre os vendedores do usuário. **Se o pedido não existe em `pedidos_vendas`, responde 403 `PEDIDO_FORA_DO_ESCOPO`** (fail-closed). Se faltar unidade válida ou número, o middleware deixa passar e a rota responde 400.
- 🟡 Consequência: um pedido que o MES conhece mas que ainda não está em `pedidos_vendas` do hub dá 403 para o vendedor, não lista vazia.
- Usuário sem vendedor vinculado na unidade: 403 `SEM_VENDEDOR_VINCULADO` (`:110`).
- **Mapa rota → tela** em `auth.rotas_telas`, criado pela migration `api005` (comentário em `route.js:22-23`). Telas, segundo o Swagger: `meus-pedidos` e `pcp-pedidos` (com escopo de vendedor) e `pedidos-equipe`. O conteúdo exato do mapa **não foi verificado** (a migration não está no repositório consultado).
- **Permissão por rota é fixa em `exigir`** (`utils/acessoConfig.js:14-19`, `6317d5f` de 08/10): chamada **com** `Authorization: Bearer` sem a ação na tela dá 403 `SEM_PERMISSAO`; rota sem linha no mapa dá 403 `ROTA_SEM_PERMISSAO_MAPEADA`. Sem token nada muda. Por isso, sem a linha em `auth.rotas_telas`, a rota **nega** para todo usuário com token.
- **O BFF do front precisa mandar `Bearer`** em `GET /itens_pedido_status`. Só com `x-api-key` a rota passa sem escopo e sem permissão por tela, e o vendedor veria pedidos de outros. A auditoria de 08/10 achou BFFs que mandam só `x-api-key` ([[Registro-de-Decisoes-2026-10-07]], #9).
- Segurança do Swagger: `ApiKeyAuth` (`swagger.json`, campo `security`).

## 5. Vocabulário de etapa: provisório

`etapa` é **cru e provisório**; o front não pode travar em enum e deve mostrar um rótulo genérico para etapa desconhecida (Swagger, campo `etapa`). `setor` e `status` vêm junto, também crus, justamente para o hub não depender do vocabulário (`integracao-avhub.service.ts:110-112`).

Valores que o MES produz hoje (`etapaDoItem`, `integracao-avhub.service.ts:167`): `compras.requisicao`, `compras.fechamento`, `recebimento.conferencia`, `qualidade.quarentena`, `qualidade.inspecao`, `qualidade.reprovado`, `estoque.atendimento`, `fabrica.espera`, `fabrica.execucao`, `expedicao.embalagem`, `expedicao.concluido`. Derivam do **tipo do setor atual** mais o status da parcial. O vocabulário final depende de [[Revisao-dos-Estados-e-Status]] e de [[Rastreabilidade-e-SLA-de-Eventos]].

Em aberto ([[005-Status-Item-Integracao-MES]]): como a tela monta "a etapa do pedido" quando as parciais estão em etapas diferentes.

## 6. Pendências

1. 🔴 **Migration `api005` não verificada no banco** (função `fn_itens_pedido_status_do_pedido`, `fn_itens_pedido_status_gravar`, tabela, tabela de cursor e linhas em `auth.rotas_telas`). Sem ela, a rota responde 500 e o job só registra no log. Dono: Gustavo.
2. 🔴 **O front não consome a rota** (nenhuma referência a `itens_pedido_status` ou `itens/status` fora de `node_modules`, conferido em 09/10). A tela 1.2 e a tarefa E3 seguem abertas.
3. 🔴 **Aceite formal do 005 pelo Nathan** (foto atual em vez de log; `pedido_venda` + `ordem_producao`; etapas a mais e a menos). O consumidor já foi construído sobre esse formato, então foi aceito de fato.
4. 🔴 **Contrato SQL 010 (a tabela `itens_pedido_status`)** ainda não está documentado no vault, apesar de o código citá-lo (`route.js:8`).
5. 🔴 **`MES_API_KEY` igual nos dois lados.** O hub envia `MES_API_KEY`; o MES lê a chave do hub em `AVHUB_MES_INTEGRACAO_KEY` ([[Registro-de-Decisoes-2026-10-07]], #11). 🟡 Conferir que a chave configurada é a que o MES aceita nesta rota; o código só mostra o envio.
6. 🟡 Produção: nada deste contrato foi visto rodando. Também não se sabe se `MES_API_URL` e `MES_API_KEY` estão definidas no ambiente do hub.

## Testes sugeridos 🟡

(Dedução do código; não existem testes citados.)

- 400 para: `codigo_empresa` ausente ou não uuid; `pedido_venda` ausente, vazio ou com 41 caracteres; `historico=talvez`.
- Pedido que não existe no MES: 200 com `itens` vazio e `lido_em` preenchido.
- `historico=false` não traz `atual` nem `cancelado_no_mes_em`; `historico=true` traz.
- Usuário com `ESCOPO_VENDEDORES_EXIGIR=true` consultando pedido de outro vendedor: 403 `PEDIDO_FORA_DO_ESCOPO`; pedido inexistente em `pedidos_vendas`: o mesmo 403.
- Banco sem a migration: 500 com a mensagem da `api005`.
- Job: sem `MES_API_URL` ou `MES_API_KEY` não sobe; MES com 401 três vezes seguidas gera `ALERTA`; falha de rede não move o cursor; segunda instância pula a unidade travada.

## Ver também
- [[005-Status-Item-Integracao-MES]]
- [[Registro-de-Decisoes-2026-10-07]]
- [[Integracao-AvHub-MES-Especificacao-F1]] (Fluxo 3)
- [[Revisao-dos-Estados-e-Status]]
- [[Rastreabilidade-e-SLA-de-Eventos]]
- [[003-Requisicao-Compra-Integracao-MES]]
- [[34-Requisicoes-MES-Empurra-para-o-Hub]]
- [[Indice-Contratos]]