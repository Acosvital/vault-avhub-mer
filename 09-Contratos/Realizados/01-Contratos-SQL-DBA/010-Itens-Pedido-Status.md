---
tags: [contrato-sql, dba, integracao-av-hub-mes, rastreabilidade]
status: implementada-no-codigo
criado: 2026-10-08
atualizado: 2026-10-09
---

# Contrato SQL 010 — `core_vendas_faturamento.itens_pedido_status` (novo)

> **(atualizado em 09/10/2026)** Este texto é a **especificação de 08/10** que o DBA recebeu; o que ela descrevia como "não existe" **já foi implementado** (`dee35b0`, 08/10, `api-acos-vital`; `fe55923` para a rota da referência da OC). A seção **Implementação conferida no código (09/10/2026)**, ao final, descreve o que o código faz hoje, com arquivo e linha. Produção não verificada.

> Status: **proposta (08/10/2026), para o Gustavo (DBA) aplicar.** Nada disto existe no banco nem no código. É o "contrato SQL próprio" que o [[005-Status-Item-Integracao-MES]] previa ("`itens_pedido_status` ou nome a definir") e a base da tela 1.2 (Meus Pedidos por etapa, tarefa E3). Dono da decisão do desenho: Nathan; aplicação: Gustavo. **O consumidor (job) e a rota de leitura estão no [[006-Status-por-Item-Leitura-no-Hub]].**

## Por quê

O MES já expõe `GET /itens/status` (foto atual de cada parcial alterada desde um cursor). O av-hub não deve consultar o MES a cada carregamento de tela do Portal do Vendedor: um job do hub lê o MES a cada 1 a 2 minutos e grava aqui. A tela lê só esta tabela.

## DDL

```sql
CREATE TABLE core_vendas_faturamento.itens_pedido_status (
  id                    uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa        uuid NOT NULL REFERENCES core.unidades(id)
                          ON UPDATE CASCADE ON DELETE RESTRICT,
  id_item_parcial       uuid NOT NULL,            -- id da ItemParcial no MES (sem FK: outro banco)
  pedido_venda          varchar(40) NOT NULL,     -- mesmo número de /pedidos_liberados
  ordem_producao        varchar(40),              -- número da OP no MES (hoje OP-000123)
  codigo_produto_omie   varchar(40),
  codigo_produto        varchar(100),
  etapa                 varchar(60) NOT NULL,     -- vocabulário PROVISÓRIO: sem CHECK nem enum
  setor_codigo          varchar(60),
  setor_nome            varchar(200),
  setor_tipo            varchar(30),
  status                varchar(30) NOT NULL,     -- status da parcial no MES, cru
  quantidade_na_etapa   numeric(14,3) NOT NULL,
  atendido_pelo_estoque boolean NOT NULL DEFAULT false,
  ocorrido_em           timestamptz NOT NULL,     -- = updated_at da parcial no MES
  mes_updated_at        timestamptz NOT NULL,
  mes_deleted_at        timestamptz,              -- parcial cancelada no MES
  lido_em               timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_itens_pedido_status
    UNIQUE (codigo_empresa, id_item_parcial, etapa, ocorrido_em)
);

-- tela: todas as parciais de um pedido, a mais recente primeiro
CREATE INDEX ix_itens_pedido_status_pedido
  ON core_vendas_faturamento.itens_pedido_status
  (codigo_empresa, pedido_venda, id_item_parcial, ocorrido_em DESC);

-- job: maior updated_at lido, por unidade (cursor derivável, mas o índice evita varredura)
CREATE INDEX ix_itens_pedido_status_cursor
  ON core_vendas_faturamento.itens_pedido_status (codigo_empresa, mes_updated_at DESC);

CREATE TABLE core_vendas_faturamento.itens_pedido_status_cursor (
  codigo_empresa   uuid PRIMARY KEY REFERENCES core.unidades(id)
                     ON UPDATE CASCADE ON DELETE CASCADE,
  alterado_desde   timestamptz NOT NULL,          -- maior updated_at processado com sucesso
  atualizado_em    timestamptz NOT NULL DEFAULT now()
);

-- estado atual: uma linha por parcial viva, a de maior ocorrido_em
CREATE VIEW core_vendas_faturamento.vw_itens_pedido_status_atual AS
SELECT DISTINCT ON (codigo_empresa, id_item_parcial) *
  FROM core_vendas_faturamento.itens_pedido_status
 WHERE mes_deleted_at IS NULL
 ORDER BY codigo_empresa, id_item_parcial, ocorrido_em DESC, lido_em DESC;
```

## Regras

- **Chave de gravação** `(codigo_empresa, id_item_parcial, etapa, ocorrido_em)`, como no contrato 005: uma parcial pode passar duas vezes pela mesma etapa (reprovação e retorno). O job faz `INSERT ... ON CONFLICT DO NOTHING`; uma parcial cancelada no MES gera uma linha com `mes_deleted_at` preenchido e some da view.
- **Histórico:** as linhas anteriores ficam. Como o MES manda a foto (e não um log), o histórico só tem a precisão do intervalo de leitura.
- **`etapa`, `setor_*` e `status` entram crus**, sem enum, para o av-hub não depender do vocabulário ([[Revisao-dos-Estados-e-Status]]).
- **Permissão:** a tabela é lida só pela API (`GET` do contrato 006), que aplica o escopo do vendedor; nada de leitura direta pelo BFF.
- **Retenção:** sem prazo definido. Sugestão: manter 24 meses e arquivar depois, junto com a decisão de retenção de logs (item 53 do [[Registro-de-Decisoes-2026-10-07]]).

## Perguntas

1. **Nome da tabela e do schema** (Gustavo): `core_vendas_faturamento` por ser onde estão pedidos e requisições; trocar se preferir um schema próprio da integração.
2. **Pedido que o vendedor vê:** uma parcial por linha, ou o hub agrega por pedido (etapa mais atrasada)? Depende da pergunta 3 do contrato 005 (item dividido em parciais em etapas diferentes). **O desenho acima guarda por parcial e deixa a agregação para a rota.**

## Depois de aplicado

- Gustavo: job de leitura e rota, no [[006-Status-por-Item-Leitura-no-Hub]].
- av-hub: a tela 1.2 (Meus Pedidos por etapa) passa a mostrar a etapa de cada item.

## Ver também
- [[005-Status-Item-Integracao-MES]]
- [[Integracao-AvHub-MES-Volta-Plano]]
- [[Integracao-AvHub-MES-Especificacao-F1]]
- [[Indice-Contratos]]


## Implementação conferida no código (09/10/2026)

> **Status: `implementada-no-codigo`. Aplicação no banco NÃO verificada.** O código da `api-acos-vital` (`origin/develop`, `dee35b0`, 08/10/2026) chama estes objetos, mas o **repositório da API não versiona SQL** e o DDL real **não foi achado em lugar nenhum** (nem em `api-acos-vital`, nem em `omie-elt-pipeline\sql`, nem no vault, nem no [[Auditoria-Dump-Producao-2026-10-07]], que é anterior ao código). Fonte das decisões: [[Registro-de-Decisoes-2026-10-07]].

> **Este contrato é a INTERFACE EXIGIDA PELO CÓDIGO, não um DDL.** Nada abaixo é o `CREATE TABLE` real. Tudo que é dedução (tipo, nulidade, índice) está marcado com 🟡. Quem escreve o DDL de verdade é o DBA (Gustavo), a partir do banco: ver a seção "DDL real: a fornecer pelo DBA".

Numeração: o código da API cita "SQL 010" para a tabela de status por item (`itens_pedido_status.route.js`, comentário das linhas 7-8). O 010 estava livre no vault (006 em `01-Contratos-SQL-DBA`; 001 a 005 e 007 a 009 em `Realizados`). Não confundir com `omie-elt-pipeline\sql\dba_migrations\011_*.md`, que é numeração do repositório do pipeline.

Contratos de API relacionados: [[005-Status-Item-Integracao-MES]] (o MES expõe `GET /itens/status`) e [[006-Status-por-Item-Leitura-no-Hub]] (a leitura no hub; criado por outro agente).

## Por quê

O MES sabe em que etapa está cada parcial (item) de um pedido de venda. O hub lê isso por polling e guarda numa tabela local, para a tela 1.2 (Meus pedidos / Pedidos da equipe / Pedidos do PCP) **não chamar o MES na hora da consulta**. A regra de "qual foto vale hoje" e a validação das linhas ficam **no banco** (funções), não na rota nem no job.

Fluxo (números de linha de `src/schemas/core_vendas_faturamento/tables/itens_pedido_status/`, daqui em diante `job.js` e `route.js`):

1. `job.js` (a cada `MES_STATUS_INTERVALO_SEG`, padrão 90 s, por unidade ativa) lê `GET {MES_API_URL}/itens/status?alterado_desde=<cursor>&codigo_empresa=<uuid>&incluir_deletados=true&limit=1000` no MES (`job.js:62-94`).
2. Grava a página com `fn_itens_pedido_status_gravar` (`job.js:122-128`), que valida, insere idempotente e avança o cursor.
3. `route.js` responde `GET /itens_pedido_status` chamando `fn_itens_pedido_status_do_pedido` e lendo o cursor (`route.js:74-95`).

## 1. Tabela `core_vendas_faturamento.itens_pedido_status`

Nome citado em: `route.js:13`, `job.js:15`, regex de erro `/itens_pedido_status/` (`route.js:98`, `job.js:183`), swagger ("tabela local `core_vendas_faturamento.itens_pedido_status`"). **Nenhum arquivo da API faz `SELECT` direto nela**: o job e a rota só passam pelas funções. As colunas abaixo vêm do que as funções recebem (JSON do MES) e devolvem (colunas lidas pela rota).

### Colunas exigidas

Origem do JSON do MES: `api-pcp\src\integracao-avhub\integracao-avhub.service.ts`, método `itensStatus` (contrato 005). Origem das colunas devolvidas: `route.js:30-52` (`montarItem`).

| Coluna | Tipo | Nulo? | Evidência |
|---|---|---|---|
| `codigo_empresa` | `uuid` | não 🟡 | JSON do MES (`codigo_empresa`); cursor e função recebem `uuid` (`job.js:114,126`). FK para `core.unidades(id)` 🟡 (padrão do vault, [[008-Requisicoes-Compra]]) |
| `id_item_parcial` | `uuid` | não 🟡 | `route.js:36`; swagger `format: uuid`, "id da parcial no MES" |
| `pedido_venda` | `text`/`varchar(40)` 🟡 | não 🟡 | MES manda `pedido_venda`; a rota limita a 40 caracteres (`route.js:65`) e o `do_pedido` recebe `text` (`route.js:76`) |
| `codigo_pedido_omie` | `bigint` 🟡 | sim 🟡 | MES manda `codigo_pedido_omie`; a rota **não devolve**. Pode ou não estar guardado |
| `codigo_produto_omie` | `text` 🟡 | sim | `route.js:37`; swagger `string nullable` |
| `codigo_produto` | `text` 🟡 | sim | `route.js:38`; swagger `nullable` |
| `ordem_producao` | `text` 🟡 | sim | `route.js:39`; swagger "OP-000123" |
| `etapa` | `text` 🟡 | não 🟡 | `route.js:40`; swagger: vocabulário **provisório**, "não travar em enum". **Sem `CHECK`** 🟡 |
| `setor_codigo`, `setor_nome`, `setor_tipo` | `text` 🟡 | sim | `route.js:31-33` (a rota monta `setor {codigo,nome,tipo}`; `null` se as três vierem vazias). O MES manda `setor` como objeto; o banco o guarda achatado em 3 colunas |
| `status` | `text` 🟡 | não 🟡 | `route.js:41`; "status da parcial no MES, cru" |
| `quantidade_na_etapa` | `numeric` 🟡 (precisão desconhecida) | sim | `route.js:42` converte com `Number()` e aceita `null` |
| `atendido_pelo_estoque` | `boolean` | sim 🟡 | `route.js:43` |
| `ocorrido_em` | `timestamptz` | não 🟡 | `route.js:44`; swagger "hora da última mudança da parcial no MES (`updated_at`)" |
| `mes_updated_at` | `timestamptz` 🟡 | — | MES manda `updated_at` (igual a `ocorrido_em`); pode ser a mesma coluna |
| `mes_deleted_at` | `timestamptz` | sim | `route.js:49` (`l.mes_deleted_at`): parcial cancelada no MES. Nome **confirmado** pelo código |
| `atual` | `boolean` | — | `route.js:48` (`l.atual`): "true na foto que vale hoje". **Pode ser coluna ou valor calculado pela função**; o código não distingue |
| `id` / `created_at` | — | — | 🟡 nada no código pede; padrão do banco, **a confirmar** |

### Chave de unicidade / idempotência

O job promete: "faz o INSERT idempotente pela chave do contrato" (`job.js:16-17`). A chave do contrato aparece no MES (`integracao-avhub.service.ts`, comentário do `itensStatus`): **`(codigo_empresa, id_item_parcial, etapa, ocorrido_em)`**. O av-hub "guarda o log" por essa chave e "mostra a etapa do maior `ocorrido_em`".

- 🟡 Deve existir um índice `UNIQUE` (ou PK) nessas quatro colunas para o `INSERT ... ON CONFLICT DO NOTHING`. O código não confirma o nome nem se é PK.
- Reenviar a mesma página não duplica. O job se apoia nisso: "cortar para baixo só faz reler a última linha, que não grava de novo" (`job.js:109-110`).
- O contador `atualizadas` do retorno do `gravar` conta "cancelamento(s)/reabertura(s)" (`job.js:145-146`): linha **já existente** em que só muda `mes_deleted_at` (parcial cancelada ou reaberta). 🟡 Isso sugere `ON CONFLICT DO UPDATE SET mes_deleted_at`, mas o corpo da função não é conhecido.
- Cada parcial vira **várias linhas** (uma por mudança de etapa/status). Item dividido em parciais em etapas diferentes aparece em várias linhas (swagger).

### Índices 🟡 (a confirmar)

Não há evidência no código. Pelo uso: o `UNIQUE` da chave acima e um índice por `(codigo_empresa, pedido_venda)` (a consulta do `do_pedido`). Se `pedido_venda` não estiver na tabela, o `do_pedido` resolve o pedido por join com outra tabela (🟡 improvável, porque o MES manda `pedido_venda` e `codigo_pedido_omie` em cada linha).

## 2. Cursor por unidade: `itens_pedido_status_cursor`

Citada em `job.js:113` e `route.js:85`.

| Coluna | Tipo | Evidência |
|---|---|---|
| `codigo_empresa` | `uuid` | `WHERE c.codigo_empresa = CAST(:empresa AS uuid)` (`job.js:114`, `route.js:86`). **Uma linha por unidade** 🟡 (PK ou UNIQUE) |
| `alterado_desde` | `timestamptz` | cursor da leitura: `COALESCE(c.alterado_desde, now() - make_interval(days => :dias))` (`job.js:112-115`). Sem linha = 1ª leitura da unidade: começa `MES_STATUS_CORTE_INICIAL_DIAS` (padrão 30) dias atrás |
| `atualizado_em` | `timestamptz` | `SELECT atualizado_em` (`route.js:85`). Vira `lido_em` na resposta: "última leitura **bem-sucedida** do MES para a unidade, mesmo sem mudança" (swagger). `null` = o job nunca leu a unidade |

Regras que o código exige:

- Quem **avança** o cursor é `fn_itens_pedido_status_gravar` (`job.js:15-17`), **na mesma transação** da gravação. Falha do MES (rede, timeout, 5xx, 401, 403) desfaz a transação: o cursor **não anda** e a página é relida (`job.js:20-24`).
- `atualizado_em` tem de andar **a cada leitura bem-sucedida, mesmo sem linhas novas** (a rota usa isso para avisar "job parado" depois de 10 minutos). 🟡 Logo, a função tem de fazer `UPSERT` do cursor também quando recebe uma página vazia.
- O cursor é lido em texto UTC com milissegundos (`YYYY-MM-DD"T"HH24:MI:SS.MS"Z"`, `job.js:112-116`).
- Página cheia (1000) sem o cursor avançar = mais de 1000 parciais com o mesmo `updated_at`: o job **não pula**, deixa parado e loga ALERTA (`job.js:149-155`). Então `novo_cursor` é o maior `ocorrido_em` da página (🟡), ou o `desde` recebido se a página vier vazia.

## 3. Função `fn_itens_pedido_status_gravar`

Chamada em `job.js:122-128`:

```sql
SELECT recebidas, inseridas, atualizadas, ignoradas,
       to_char(novo_cursor AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS novo_cursor
  FROM core_vendas_faturamento.fn_itens_pedido_status_gravar(
         CAST(:empresa AS uuid), CAST(:desde AS timestamptz), CAST(:linhas AS jsonb));
```

**Assinatura exigida** (tipos dos `CAST` no código; os nomes dos parâmetros não aparecem, a chamada é posicional):

| Argumento | Tipo | Conteúdo |
|---|---|---|
| 1 | `uuid` | unidade (`codigo_empresa`) |
| 2 | `timestamptz` | o `desde` que o job usou na leitura (o cursor lido) |
| 3 | `jsonb` | **array** das linhas do MES, cru (`JSON.stringify(linhas)`) |

**Retorno** (`RETURNS TABLE` ou `OUT`, uma linha; o job lê `[r]`):

| Coluna | Tipo | Uso no código |
|---|---|---|
| `recebidas` | inteiro | quantas linhas vieram; `< 1000` = acabou a unidade (`job.js:148`) |
| `inseridas` | inteiro | linhas novas (`job.js:144-146`) |
| `atualizadas` | inteiro | cancelamentos/reaberturas (`job.js:144-146`) |
| `ignoradas` | `jsonb` array 🟡 | `Array.isArray(r.ignoradas)`; cada item é logado (até 20) como "linha do MES ignorada (não gravada)" (`job.js:139-143`). Formato dos itens desconhecido |
| `novo_cursor` | `timestamptz` | convertido para texto UTC na própria consulta; comparado com `desde` para detectar cursor parado (`job.js:149`) |

**Comportamento exigido:**

- Valida as linhas (tipos, campos obrigatórios) e **ignora** as inválidas devolvendo-as em `ignoradas`, sem derrubar a página (🟡 deduzido do nome e do log do job).
- `INSERT` idempotente pela chave do contrato (acima).
- Marca `mes_deleted_at` quando a linha vem com `deleted_at` (a parcial cancelada vem no mesmo cursor porque o job sempre manda `incluir_deletados=true`, `job.js:26-29`).
- Avança `itens_pedido_status_cursor` (seção 2).
- Mantém o `atual` (se for coluna): a foto mais recente de uma parcial **não cancelada** (swagger do `historico`). 🟡

### Erro quando a migration não foi aplicada

Job: `SQLSTATE 42883` (função não existe) ou `42P01` (tabela não existe) com `itens_pedido_status` na mensagem → loga "objetos da migration api005 ausentes no banco: aplicar a migration" e **para a rodada** (`job.js:182-186`). Qualquer outro erro: aviso, cursor não avançou, tenta na próxima rodada.

## 4. Função `fn_itens_pedido_status_do_pedido`

Chamada em `route.js:74-78`:

```sql
SELECT * FROM core_vendas_faturamento.fn_itens_pedido_status_do_pedido(
  CAST(:empresa AS uuid), CAST(:numero AS text), CAST(:historico AS boolean));
```

**Assinatura exigida:** `(uuid, text, boolean) RETURNS TABLE(...)`. `empresa` vem em minúsculas; `numero` é o `pedido_venda` com `trim()`, até 40 caracteres.

**Colunas que o `RETURNS TABLE` precisa ter** (a rota lê exatamente estas, `route.js:30-52`):

`id_item_parcial`, `codigo_produto_omie`, `codigo_produto`, `ordem_producao`, `etapa`, `setor_codigo`, `setor_nome`, `setor_tipo`, `status`, `quantidade_na_etapa`, `atendido_pelo_estoque`, `ocorrido_em`, `atual`, `mes_deleted_at`.

`atual` e `mes_deleted_at` só são lidos com `historico=true`, mas a função os devolve sempre.

**Regra de seleção (no banco, `route.js:17-18` e swagger):**

- `historico=false`: **a foto mais recente de cada parcial viva** (não cancelada), ou seja, o maior `ocorrido_em` por `id_item_parcial` com `mes_deleted_at IS NULL`.
- `historico=true`: todas as fotos de cada parcial, inclusive as de parciais canceladas no MES, com `atual` e `mes_deleted_at`.
- Ordem: `codigo_produto`, `id_item_parcial`, `ocorrido_em` decrescente (swagger).
- Pedido que ainda não chegou ao MES: **zero linhas** (a rota responde 200 com `itens: []`, não 404).

## 5. Mapa de rota em `auth.rotas_telas` (parte da migration `api005`)

Comentário do código: "o mapa rota -> tela está em `auth.rotas_telas` (migration api005)" (`route.js:22-23`). Sem linha lá, o middleware de identidade responde `ROTA_SEM_PERMISSAO_MAPEADA` com token de usuário (`identidadeUsuario.js:110`).

Exigido pelo código/swagger (🟡 nomes exatos das colunas de `auth.rotas_telas` não conferidos):

| Rota | Telas que dão acesso | Ação |
|---|---|---|
| `GET /itens_pedido_status` | `meus-pedidos`, `pcp-pedidos`, `pedidos-equipe` | leitura |

Swagger: "Permissão (com token de usuário): telas `meus-pedidos` e `pcp-pedidos` (com escopo de vendedor) e `pedidos-equipe`."

Escopo de vendedor (`src/middlewares/escopoVendedor.js:22-24, 52-53, 131-141`): com token e `ESCOPO_VENDEDORES_EXIGIR=true`, a rota é tratada como `{ formato: "dono", dono: "pedido_venda_query" }`. O middleware consulta a tabela `pedidos_vendas` (não esta):

```sql
SELECT codigo_empresa, codigo_vendedor_omie FROM core_vendas_faturamento.pedidos_vendas
 WHERE codigo_empresa = :emp::uuid AND numero_pedido = :ped
```

Pedido sem dono em `pedidos_vendas` = **403 `PEDIDO_FORA_DO_ESCOPO`** (fail-closed). Logo `itens_pedido_status.pedido_venda` precisa casar com `pedidos_vendas.numero_pedido` (mesmo número, mesma unidade) 🟡.

## 6. Comportamento de erro da rota

| Situação | Resposta |
|---|---|
| `codigo_empresa` ausente ou não uuid | 400 (`route.js:58-60`) |
| `pedido_venda` ausente ou com mais de 40 caracteres | 400 |
| `historico` diferente de `true`/`false` | 400 |
| SQLSTATE `42883` ou `42P01` com `itens_pedido_status` na mensagem | **500** `"GET /itens_pedido_status exige a migration api005 no banco."` (`route.js:97-101`) |
| outros erros do banco | `handleSequelizeError` |

## 7. Concorrência (advisory lock)

`job.js:101-107`: cada página roda numa transação com `pg_try_advisory_xact_lock(hashtext('avhub.mes_status_itens'), hashtext(<codigo_empresa>))`. Com mais de uma instância da API, só uma lê cada unidade por vez; a outra pula (`return null`). O lock é de transação e solta no `COMMIT`/`ROLLBACK`. Nada a criar no banco: é função nativa do Postgres. Dentro do processo, `estado.rodando` impede rodadas sobrepostas.

## DDL real: a fornecer pelo DBA (Gustavo)

O que ele precisa colar do banco (produção e `api-test`) para este contrato virar DDL de verdade e o status passar a `aplicada`:

- [ ] `\d+ core_vendas_faturamento.itens_pedido_status` (colunas, tipos, nulidade, defaults, índices, constraints, FKs, triggers).
- [ ] `\d+ core_vendas_faturamento.itens_pedido_status_cursor`.
- [ ] `\df+ core_vendas_faturamento.fn_itens_pedido_status_gravar` e o corpo completo (`SELECT pg_get_functiondef('core_vendas_faturamento.fn_itens_pedido_status_gravar(uuid,timestamptz,jsonb)'::regprocedure)`).
- [ ] O mesmo para `fn_itens_pedido_status_do_pedido(uuid,text,boolean)`.
- [ ] Linhas de `auth.rotas_telas` para `/itens_pedido_status` (ajustar o nome da coluna da rota ao esquema real).
- [ ] Se a migration `api005` foi aplicada em produção: `SELECT proname FROM pg_proc WHERE proname LIKE 'fn_itens_pedido_status%'` e `SELECT count(*), max(ocorrido_em) FROM core_vendas_faturamento.itens_pedido_status`.
- [ ] Conteúdo de `itens_pedido_status_cursor` (uma linha por unidade? `atualizado_em` recente?).
- [ ] Se a chave de unicidade é mesmo `(codigo_empresa, id_item_parcial, etapa, ocorrido_em)` e o nome do índice.
- [ ] O script da migration `api005` (de onde vem, quem aplicou, quando), para versioná-lo.
- [ ] Formato dos itens de `ignoradas` e quais validações a função aplica.

Depois da resposta: substituir as seções 1 a 5 pelo DDL real, no formato de [[008-Requisicoes-Compra]], e mover o arquivo para `Realizados\01-Contratos-SQL-DBA`.

## Não verificado (🟡 resumo)

- Todos os tipos, nulidades, índices e a PK da tabela e do cursor.
- Se `atual` é coluna ou calculado; se `setor_*` é achatado ou `jsonb`.
- O corpo das duas funções (validação, `ignoradas`, `ON CONFLICT`, UPSERT do cursor com página vazia).
- As linhas exatas de `auth.rotas_telas`.
- Se a migration `api005` está aplicada em produção (nenhuma fonte confirma).

## Ver também
- [[006-Status-por-Item-Leitura-no-Hub]]
- [[005-Status-Item-Integracao-MES]]
- [[011-Ordens-Compra-Referencia-MES]] (migration `api004`, mesma rodada)
- [[Registro-de-Decisoes-2026-10-07]]
- [[Indice-Contratos]]