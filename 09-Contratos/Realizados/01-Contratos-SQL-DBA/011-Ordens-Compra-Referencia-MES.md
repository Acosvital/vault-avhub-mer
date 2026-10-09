---
tags: [contrato-sql, dba, integracao-av-hub-mes, compras, api004]
status: implementada
criado: 2026-10-09
atualizado: 2026-10-09
---

# Contrato SQL 011 — `vw_ordens_compra_referencia_mes` + `ordens_compra_referencia_mes` (marca por trigger) + índice (migration `api004`)

> **Status: `implementada`. ✅ Migration `api004` entregue e aplicada pelo DBA (Gustavo afirmou em 09/10/2026).** O vault não a enxerga porque o repositório não versiona SQL; a confirmação é a palavra do DBA, e o que continua pendente é só **o script versionado** (checklist abaixo). A rota `GET /ordens-compra/referencia` existe na `api-acos-vital` (`fe55923`, 08/10/2026; lida em `origin/develop`, `dee35b0`) e lê estes objetos. O repositório da API **não versiona SQL** e o DDL real **não foi achado em lugar nenhum** (nem em `api-acos-vital`, nem em `omie-elt-pipeline\sql`, nem no vault, nem no [[Auditoria-Dump-Producao-2026-10-07]]). Fonte das decisões: [[Registro-de-Decisoes-2026-10-07]] (#41).

> **Este contrato é a INTERFACE EXIGIDA PELO CÓDIGO, não um DDL.** Tudo que é dedução está marcado com 🟡.

Numeração: o 010 é o [[010-Itens-Pedido-Status]]; este é o próximo livre (011). Não confundir com `omie-elt-pipeline\sql\dba_migrations\011_*.md`, que é numeração do repositório do pipeline, não do vault.

Contrato de API: [[004-Referencia-OC-Integracao-MES]] (o MES lê a rota a cada 5 min).

## Por quê

O Recebimento do MES confere o material não acabado contra a OC, que só existe no av-hub. O MES faz polling de `GET /ordens-compra/referencia` e faz UPSERT por `(codigo_empresa, id_ordem_compra)`; itens por `(id_ordem_compra, id_item_oc)`; item que some de uma OC que voltou = item removido. **Quais OCs entram, a situação, os itens e o destino são regra do BANCO** (a view); o `alterado_em` é mantido **por trigger** na tabela da marca. A rota só filtra e pagina (`route.js:16-19`). Sem preço, fornecedor, condição de pagamento, categoria nem conta corrente.

Arquivos citados: `src/schemas/core_vendas_faturamento/views/vw_ordens_compra_referencia_mes/vw_ordens_compra_referencia_mes.route.js` (daqui em diante `route.js`) e o `.swagger.json` ao lado.

## 1. View `core_vendas_faturamento.vw_ordens_compra_referencia_mes`

### Colunas que a rota lê

`route.js:39-42` (`COLUNAS`) e `route.js:72-90` (`WHERE`/`ORDER BY`):

| Coluna da view | Tipo | Uso e evidência |
|---|---|---|
| `id_ordem_compra` | `uuid` | `ordens_compra.id`. Desempate do cursor (`apos_id`, CAST uuid); `ORDER BY` |
| `codigo_empresa` | `uuid` | filtro `v.codigo_empresa = CAST(:empresa AS uuid)` (`route.js:75`) |
| `numero_pedido` | `text` 🟡 | ex.: `OC-000123` (swagger). Corresponde a `ordens_compra.numero_ordem` do [[007-Ordens-Compra-Estruturada]], renomeado na view 🟡 |
| `numero_pedido_omie` | `text` 🟡, nulo | `null` enquanto a OC não chegou ao Omie; "é o número que a NF-e do fornecedor cita" (swagger) |
| `situacao` | `text` | só `'aprovada'` ou `'cancelada'` (swagger enum) |
| `finalidade` | `text` | `pedidos_venda`, `estoque`, `recompra` ou `uso_interno` (swagger enum) |
| `data_previsao_chegada` | `date`, nulo | formatada na rota por `to_char(..., 'YYYY-MM-DD')` (`route.js:41`), então tem de ser `date`/`timestamp`, não texto |
| `alterado_em` | `timestamptz` | a marca do cursor: `v.alterado_em > CAST(:desde AS timestamptz)` e `(v.alterado_em, v.id_ordem_compra) > (...)` (`route.js:72-74`); `ORDER BY v.alterado_em, v.id_ordem_compra` (`route.js:90`) |
| `alterado_em_utc` | `text` | a rota devolve `v.alterado_em_utc AS alterado_em` (`route.js:42`): **texto UTC com microssegundos** (`2026-10-18T09:00:00.123456Z`). Motivo (`route.js:36-38`): um `Date` do JS cortaria em milissegundos e, reenviado em `alterado_desde`, a última OC voltaria a cada leitura. 🟡 Algo como `to_char(alterado_em AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')` |
| `itens` | `jsonb` (array) | montado na view; a rota devolve cru. Estrutura abaixo |

A contagem usa a view sem selecionar `itens` (`SELECT count(*)::int ... FROM view v WHERE ...`, `route.js:79-84`): "não monta o jsonb dos itens de quem não está na página". 🟡 Para isso funcionar, o `jsonb` dos itens precisa ser expressão **calculada por linha** (subconsulta correlata ou `LATERAL`), sem `GROUP BY` que force montar tudo.

### Estrutura de `itens` (swagger, `ReferenciaOcItem`)

| Campo | Tipo | Regra |
|---|---|---|
| `id_item_oc` | uuid | `ordens_compra_itens.id` 🟡 |
| `ordem` | integer | posição |
| `codigo_produto_omie` | string, nulo | do item **quando está em `core.produtos` da unidade da OC**; `null` = material sem cadastro (vale a descrição) |
| `descricao_produto` | string | |
| `quantidade` | number | |
| `unidade_medida` | string | |
| `tipo_material` | `acabado` / `nao_acabado` | **nunca vazio**. Acabado confere contra o PV; não acabado, contra a OC |
| `local_estoque` | string, nulo | |
| `id_requisicao` | uuid, nulo | a do item; sem ela, a do cabeçalho da OC. `null` = compra sem requisição |
| `id_origem` | uuid, nulo | `requisicoes_compra.id_origem` (id do item da requisição no MES); `null` sem requisição ou em requisição criada à mão ([[008-Requisicoes-Compra]]) |
| `numero_requisicao_mes` | string, nulo | `RC-AAAAMMDD-NNNN`, para exibir |
| `destino` | array | `{tipo: "pedido_venda", numero_pedido_venda, codigo_empresa_pv, quantidade}` (vínculos com PV, em ordem de criação) e `{tipo: "estoque", quantidade}` (o resto), "na unidade do item". **Soma = `quantidade`** |

### Quais OCs entram

Documentado em [[004-Referencia-OC-Integracao-MES]] e no swagger:

- OCs com `status = aprovado` → `situacao = 'aprovada'`.
- OCs **canceladas depois de aprovadas** (canceladas ou **excluídas** depois de aprovadas) → `situacao = 'cancelada'`, para o MES tirá-las da fila.
- **Não entram** rascunho nem `aguardando_aprovacao`.

🟡 A view depende, no mínimo, de `ordens_compra`, `ordens_compra_itens`, `requisicoes_compra`, `core.produtos`, de uma fonte de vínculos OC↔pedido de venda (não identificada no vault) e da tabela da marca (seção 2). Os nomes de colunas dessas tabelas estão no [[007-Ordens-Compra-Estruturada]] e no [[008-Requisicoes-Compra]], **com divergência entre o DDL proposto e o aplicado**; só o DBA diz qual vale.

## 2. Tabela da marca `core_vendas_faturamento.ordens_compra_referencia_mes` + trigger

Nome citado só em comentário (`route.js:18`: "o `alterado_em` é mantido por trigger (`ordens_compra_referencia_mes`)"; `route.js:70-71`: "índice `(alterado_em, id_ordem_compra)` da tabela da marca"). **Nenhum código faz `SELECT` nela.**

### Colunas exigidas 🟡

| Coluna | Tipo | Evidência |
|---|---|---|
| `id_ordem_compra` | `uuid` | índice `(alterado_em, id_ordem_compra)` citado em `route.js:71`. Provavelmente PK ou `UNIQUE`, 1 linha por OC 🟡 |
| `codigo_empresa` | `uuid` 🟡 | pode vir só da view, via `ordens_compra` |
| `alterado_em` | `timestamptz` | precisão de **microssegundos** (`timestamptz` guarda em µs; `route.js:36-38` depende disso) |

### Trigger exigida 🟡

O código só diz "o `alterado_em` é mantido por trigger". Comportamento mínimo que a rota exige:

- Toda mudança **relevante para o MES** numa OC aprovada (cabeçalho, situação, finalidade, previsão de chegada, `numero_pedido_omie`, **qualquer** item incluído/alterado/removido e os vínculos de destino) tem de **subir o `alterado_em`** dessa OC. Senão o MES não relê a OC. Isso implica triggers em **mais de uma tabela** (pelo menos `ordens_compra` e `ordens_compra_itens`) 🟡.
- A aprovação e o cancelamento depois de aprovada também sobem a marca (cancelar faz a OC voltar com `situacao: cancelada`, [[004-Referencia-OC-Integracao-MES]]).
- 🟡 Risco de "commit tardio": a marca é gravada na transação, mas só fica visível no `COMMIT`. Uma OC com `alterado_em` menor que o cursor que o MES já passou pode aparecer depois e ser perdida. O `apos_id` resolve empate, **não** esse caso. Se a trigger usa `now()` (hora do início da transação), o risco é maior que com `clock_timestamp()`. A decidir com o DBA.

## 3. Índice

`route.js:70-71`: "Condições montadas aqui (sem `CASE` no `WHERE`) para o banco usar o **índice `(alterado_em, id_ordem_compra)`** da tabela da marca."

Exigido 🟡:

```text
índice btree em ordens_compra_referencia_mes (alterado_em, id_ordem_compra)
```

Nome e se é `UNIQUE` são desconhecidos. A rota usa a comparação de **tupla** `(alterado_em, id_ordem_compra) > (:desde, :apos)`, que só usa o índice se as duas colunas estiverem na mesma ordem e direção.

## 4. A rota, o que ela espera da view

`GET /ordens-compra/referencia?alterado_desde=&codigo_empresa=&apos_id=&page=&limit=`

| Parâmetro | Regra (`route.js`) |
|---|---|
| `alterado_desde` | **obrigatório**, ISO 8601 (regex `ISO` na linha 31; validação nas linhas 48-54); data sozinha vale meia-noite UTC |
| `codigo_empresa` | opcional, uuid |
| `apos_id` | opcional, uuid (`id_ordem_compra` da última OC lida): extensão do contrato, desempate do cursor |
| `page`, `limit` | `limit` padrão 100, máximo 500 |

Resposta: `{ total, page, limit, total_pages, proximo: {alterado_desde, apos_id} | null, data }`. `proximo` vem da última OC da página, para ler sem depender de `page` (que desloca se uma OC mudar no meio).

Rota de **serviço**: sem token de usuário e **sem linha em `auth.rotas_telas`** (`route.js:21-25`). A chave do MES do contrato 34 (`MES_INTEGRACAO_KEYS`) dá **403 `CHAVE_MES_ROTA_NAO_PERMITIDA`** aqui; o MES lê com chave de leitura de `auth.chaves_servico` ou de `API_KEYS` (decisão do Gustavo, 08/10).

### Comportamento de erro

| Situação | Resposta |
|---|---|
| `alterado_desde` ausente ou inválido | 400 |
| `codigo_empresa` / `apos_id` não uuid | 400 |
| SQLSTATE `22008` / `22007` (data inválida no banco) | 400 |
| SQLSTATE `42P01` com `referencia_mes` na mensagem | **500** `"GET /ordens-compra/referencia exige a migration api004 no banco."` (`route.js:107-111`) |
| outros | `handleSequelizeError` |

Atenção: o teste do erro é **só `42P01`** (relação inexistente) com `referencia_mes` no texto. Coluna inexistente (`42703`) **não** cai nesse tratamento: uma view desatualizada vira erro genérico.

## DDL real: a fornecer pelo DBA (Gustavo)

- [ ] Definição da view: `SELECT pg_get_viewdef('core_vendas_faturamento.vw_ordens_compra_referencia_mes'::regclass, true);` e `\d+` dela.
- [ ] `\d+ core_vendas_faturamento.ordens_compra_referencia_mes` (colunas, tipos, PK, índices, triggers).
- [ ] A(s) função(ões) de trigger e os `CREATE TRIGGER`: `\d+ core_vendas_faturamento.ordens_compra`, `ordens_compra_itens` e tabelas de vínculo de destino; `\df+` e `pg_get_functiondef` de cada função que escreve em `ordens_compra_referencia_mes`.
- [ ] Definição do índice `(alterado_em, id_ordem_compra)` (`\di+` / `pg_indexes`) e se é `UNIQUE`.
- [ ] Qual expressão gera `alterado_em_utc` (formato e fuso).
- [ ] De onde vêm os vínculos OC↔pedido de venda (`destino`) e como o resto "estoque" é calculado.
- [x] ~~Se a migration `api004` foi aplicada em produção~~ (✅ DBA, 09/10; conferência opcional por): `SELECT to_regclass('core_vendas_faturamento.vw_ordens_compra_referencia_mes'), to_regclass('core_vendas_faturamento.ordens_compra_referencia_mes');` e `SELECT count(*), max(alterado_em) FROM core_vendas_faturamento.ordens_compra_referencia_mes;`.
- [ ] O script da migration `api004` (origem, quem aplicou, quando), para versioná-lo.
- [ ] Como a marca reage a **exclusão** de OC aprovada (o contrato diz que sai como `cancelada`; uma linha apagada some da view).

Depois da resposta: substituir as seções 1 a 3 pelo DDL real, no formato de [[008-Requisicoes-Compra]], e mover o arquivo para `Realizados\01-Contratos-SQL-DBA`.

## Não verificado (🟡 resumo)

- Tudo o que é DDL: tipos, tabelas de apoio da view, PK, nome e unicidade do índice, funções e eventos da trigger.
- Se a marca cobre mudança de item e de destino, e o risco de commit tardio.
- Se `alterado_em_utc` é coluna da view ou expressão.
- ~~Se a migration `api004` está aplicada em produção~~ ✅ **O DBA afirmou em 09/10/2026 que a entregou e aplicou** (sem ela a rota daria 500). Resta versionar o script e conferir o DDL por `\d`/`pg_get_viewdef`.
- Lado do MES (job de leitura a cada 5 min): fora deste contrato, pendente com o Robert.

## Ver também
- [[004-Referencia-OC-Integracao-MES]]
- [[007-Ordens-Compra-Estruturada]]
- [[008-Requisicoes-Compra]]
- [[010-Itens-Pedido-Status]]
- [[Registro-de-Decisoes-2026-10-07]]
- [[Indice-Contratos]]
