---
id: API-009
aliases: ["Contrato 009", "009-Referencia-Requisicao-Hub-Integracao-MES"]
tags: [contrato, contrato-api, mes, integracao-av-hub-mes, compras, requisicao, sql]
criado: 2026-10-15
atualizado: 2026-10-19
status: parcial
sistemas: [hub-banco, hub-api, mes-api, mes-front]
dono: "Gustavo"
etapa_0b: [C0, P1, P2, P3, E1]
fontes: ["N14-28, N14-31, N14-32, N14-33 (Registro-de-Decisoes)", "api-acos-vital src/schemas/core_vendas_faturamento/views/vw_ordens_compra_referencia_mes/vw_ordens_compra_referencia_mes.route.js (molde da rota), index.js:190-199 (montagem)", "Dump Avhub (Esqueleto).sql:6129-6174 (fn_oc_referencia_mes_marcar), :17965-17969 e :24219 (marca e índice da OC), :20240-20278 (vw_ordens_compra_referencia_mes), :10181 (set_updated_at), :25898-26280 (triggers de requisicoes_compra)", "Proposta do Robert (15/10/2026) e revisão do API-009 pelo Robert"]
criado_original: 2026-10-15
---

# Contrato de API 009 — Referência da requisição do Compras (av-hub → MES)

> **Onde atua:** av-hub: banco, API · MES: API, front

> [!info] Situação em 21/10/2026
> **Status:** `parcial` · **Pasta:** `Ativos` · **Nós do 0b:** C0, P1, P2, P3, E1 · **Dono:** Gustavo (rota, view, marca); Robert (job e telas no MES, [[API-011-Compra-em-Andamento-Recebimento-por-Item-da-OC-e-Uso-Interno]])
>
> - 📝 **N14-28:** a requisição criada no av-hub pelo Compras **com pedido de venda** aparece no MES **antes de virar OC**, para o PCP saber que o item já está em compra e não requisitar de novo. A OC vinculada já chega pela referência da OC ([[API-004-Referencia-OC-Integracao-MES]]). Este contrato cobre o intervalo **entre a requisição e a OC aprovada**.
> - ✅ **Lado do hub entregue** (conferido na `develop` de `api-acos-vital`, 21/10/2026): `GET /compras/requisicoes/referencia?alterado_desde=&codigo_empresa=&apos_id=&page=&limit=` (`vw_requisicoes_compra_referencia_mes.route.js`, montada em `core_vendas_faturamento/index.js:195`).
> - 🔴 **Lado do MES não existe:** o `api-pcp` não tem job que leia `/compras/requisicoes/referencia` nem a projeção da requisição do hub (busca em `src` sem resultado); falta também a tela do PCP e o aviso de compra duplicada (BL-065). ❓ O banco de produção (migration `api009`) não foi conferido.
> - ✅ **SQL escrito e testado em banco descartável** (PostgreSQL 18, schema restaurado do dump, tabelas vazias): [[0001-requisicoes-referencia-mes.sql]] em `API-009-anexos/`. Testes feitos: requisição do hub com pedido entra na marca e na view; a sem pedido não entra; `codigo_produto_omie` resolvido pelo cadastro da unidade; cancelar e retirar o pedido marcam a saída (`visivel_ao_pcp = false`); a OC emitida marca a requisição `atendida` e a **aprovação da OC avança a marca** (trigger na OC); a OC cancelada devolve a requisição a `aberta`. **Não testado:** a rota (ainda não existe) e o volume real.
> - Migration **`api009`**, depois da `api010`.
>
> Selos em [[Regras-do-Vault]]. A parte de **escrita** (finalidade, pedido, produto no POST) é do API-010.

**Destinatários:** backend do av-hub (`api-acos-vital`, Gustavo) e MES (`api-pcp`, Robert).

## Por quê

Quando o Compras cria a requisição no av-hub ela **não chega ao MES**: só o que tem `id_origem` gera marcos (contrato 35) e `id_origem` é `NOT NULL` em `requisicoes_compra_eventos`. Entre a requisição e a OC aprovada o PCP não sabe que o item já está em compra e pode abrir uma requisição igual. A OC, depois de aprovada, já aparece pela referência da OC (item com `destino[]` de pedido de venda, BL-049); **uma OC `aguardando_aprovacao` não aparece lá** (a view da OC só traz `aprovado` e as canceladas já aprovadas). Esta referência cobre os dois buracos.

**Não muda:** o contrato 34, o contrato 35 e o `id_origem NOT NULL`. A requisição que **veio do MES** (`id_origem` preenchido) fica **fora**: o MES já a conhece. A requisição **sem** pedido de venda (estoque, uso interno) também fica fora.

## 1. Banco (migration `api009`): a marca, as triggers e a view

Arquivo: [[0001-requisicoes-referencia-mes.sql]]. Segue o molde da `api004` (tabela da marca + função de marca + view).

### Por que não usar `updated_at` como cursor

`public.set_updated_at()` grava `NOW()`, a hora de **início da transação**. Uma transação longa pode gravar um `updated_at` menor que um já lido pelo cursor do MES, e a linha seria perdida. A marca da OC resolve isso com `clock_timestamp()` e `GREATEST`; esta faz igual.

### Peças

| Peça | O que é |
|---|---|
| Tabela `requisicoes_compra_referencia_mes (id_requisicao PK, alterado_em timestamptz DEFAULT clock_timestamp())` | FK para `requisicoes_compra(id)` com `ON DELETE CASCADE`; índice `(alterado_em, id_requisicao)` para o cursor |
| Função `fn_req_referencia_mes_marcar()` | `SECURITY DEFINER`, marca a requisição (ou, quando a OC muda, as requisições dela). **Só entra** requisição com `id_origem IS NULL` e `numero_pedido_venda` preenchido; **depois de entrar**, qualquer mudança é marcada, inclusive a que a tira da vista |
| Triggers em `requisicoes_compra` | `AFTER INSERT` e `AFTER UPDATE OF status, id_ordem_compra, numero_pedido_venda, finalidade, material, descricao, quantidade, unidade_medida, prazo_necessidade, deleted_at, id_origem` (com `WHEN ... IS DISTINCT FROM`) |
| Trigger em `ordens_compra` | `AFTER UPDATE OF status, numero_pedido, deleted_at, id_requisicao`: a aprovação ou o cancelamento da OC **não altera a linha da requisição**, então sem esta trigger a marca não avançaria |
| Preenchimento inicial | marca as requisições do hub que já têm pedido de venda |
| View `vw_requisicoes_compra_referencia_mes` | a regra mora aqui; a rota só filtra e pagina |

**`visivel_ao_pcp`** (coluna da view): `true` quando a requisição está viva, tem pedido de venda, finalidade `pedidos_venda` ou `recompra` e não está cancelada. Quando fica `false` (cancelada, pedido retirado, finalidade trocada), a linha **continua saindo na referência** com a marca nova, e o MES **apaga** a linha da projeção. É assim que a "saída" chega ao MES sem apagar nada.

## 2. A rota

### `GET /compras/requisicoes/referencia?alterado_desde=&codigo_empresa=&apos_id=&page=&limit=`

Mesmo desenho, mesmos parâmetros, mesmos erros e **mesmo formato de resposta** de `GET /ordens-compra/referencia` (o MES já lê essa e reaproveita o leitor).

| Parâmetro | Regra |
|---|---|
| `alterado_desde` | **obrigatório**, ISO 8601 (mesma regex da referência da OC). Devolve o que tem `alterado_em` maior, em ordem crescente de `(alterado_em, id_requisicao)` |
| `codigo_empresa` | opcional, uuid da unidade |
| `apos_id` | opcional, uuid: desempate do cursor, `(alterado_em, id_requisicao) > (alterado_desde, apos_id)` |
| `page`, `limit` | `limit` padrão 100, máximo 500 |

**Resposta `200`:**
```json
{
  "total": 2, "page": 1, "limit": 100, "total_pages": 1,
  "proximo": { "alterado_desde": "2026-10-15T14:20:01.482913Z", "apos_id": "…uuid da última requisição…" },
  "data": [
    {
      "id_requisicao": "uuid",
      "codigo_empresa": "uuid-da-unidade",
      "numero_requisicao": "REQ-000412",
      "status": "em_cotacao",
      "finalidade": "pedidos_venda",
      "material": "CH45025X6X1K",
      "codigo_produto_omie": "9764577293",
      "descricao": "CHAPA …",
      "quantidade": 8,
      "unidade_medida": "PC",
      "prazo_necessidade": "2026-11-05",
      "numero_pedido_venda": "27605",
      "id_ordem_compra": null,
      "numero_ordem_compra": null,
      "situacao_ordem_compra": null,
      "visivel_ao_pcp": true,
      "alterado_em": "2026-10-15T14:20:01.482913Z"
    }
  ]
}
```

| Campo | Observação |
|---|---|
| `status` | `aberta`, `em_cotacao`, `atendida`, `cancelada` |
| `material` | `codigo_produto` do cadastro (com o API-010 é sempre do cadastro para requisição nova) |
| `codigo_produto_omie` | **Resolvido pela view** em `core.produtos` por `codigo_empresa` + `codigo_produto = material`; **`null`** quando o texto não casa (requisição antiga). O MES casa por unidade + `codigo_produto` e usa o `codigo_produto_omie` para ligar à OC |
| `situacao_ordem_compra` | `rascunho`, `aguardando_aprovacao`, `aprovado`, `cancelado`. Preenchida quando `atendida`. **Existe para fechar o buraco entre emitir e aprovar a OC** |
| `alterado_em` | texto UTC com microssegundos (`alterado_em_utc` da view): um `Date` do JS cortaria em milissegundos |
| `quantidade` | número (`trim_scale` na view); `numeric(15,4)` no banco, o model do hub declara `DECIMAL(14,3)`; o MES aceita os dois |

**Não trafega:** solicitante, observação, fornecedor, preço, condição (minimização de dados, como a referência da OC).

### Erros

`400 { detail }` para `alterado_desde` ausente ou inválido, `codigo_empresa` ou `apos_id` que não são uuid (e erros `22007`/`22008` do banco). `500 { detail: "GET /compras/requisicoes/referencia exige a migration api009 no banco." }` quando a view não existe (`42P01`), como a rota da OC faz com a `api004`. `401` e `403` pela chave.

### Montagem (importante)

A rota `GET /compras/requisicoes/referencia` **tem de ser montada antes de** `{ path: "/compras/requisicoes", router: requisicoes_compra }` (`index.js:191`). Esse router tem `GET /:id`, e "referencia" seria lido como id e daria `400 "id deve ser um uuid"`. Proposta: arquivo `views/vw_requisicoes_compra_referencia_mes/vw_requisicoes_compra_referencia_mes.route.js` e swagger ao lado, montado em `index.js` logo acima da linha de `/compras/requisicoes`. Contagem e página separadas, como na rota da OC.

### Chave

Rota de serviço, sem token de usuário e sem linha em `auth.rotas_telas`. O MES lê com a **chave de serviço de escrita** que o Gustavo confirmou em 15/10 (cobre a referência da OC e o resto). Com a restrição de rotas por chave (commit `b02d6c5`, [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] S1), a lista da chave do MES precisa **incluir** `GET /compras/requisicoes/referencia`. A chave do contrato 34 (`MES_INTEGRACAO_KEYS`) continua só para o PUT: aqui dá `403 CHAVE_MES_ROTA_NAO_PERMITIDA`.

## 3. O que o MES faz (Robert, [[API-011-Compra-em-Andamento-Recebimento-por-Item-da-OC-e-Uso-Interno]])

1. **Job:** o mesmo ciclo de 5 min do K4 (`oc-referencia-avhub.service.ts`), com **cursor próprio** (`IntegracaoAvhubCursor` com `chave = 'requisicoes-referencia'`), sobreposição de 5 min, `limite 500`, `apos_id`. UPSERT por `(codigo_empresa, id_requisicao)`. Falha de uma das leituras (OC ou requisição) não derruba a outra.
2. **Projeção local** em tabela **própria** (`RequisicaoHubReferencia`), separada da requisição interna "origem hub" do BL-051. `visivel_ao_pcp = false` apaga a linha.
3. **Cruzamento** com o pedido por **unidade + número do pedido + `material`** (o `codigo_produto`): o item de pedido do MES só tem esse código humano. O `codigo_produto_omie` serve para ligar à OC, ao cadastro e ao saldo do Estoque.
4. **O que o PCP vê**, na Triagem, na Destinação e no Atendimento:
   - `aberta` ou `em_cotacao`: "**Requisição aberta no Compras:** nº, N un, necessidade dd/mm";
   - `atendida` com OC `rascunho` ou `aguardando_aprovacao`: continua visível como "**OC X aguardando aprovação**";
   - `atendida` com OC `aprovado`: some daqui e passa a valer a OC da referência da OC ("Compra em andamento: OC X, N un, previsão dd/mm", BL-049), ligada por `id_requisicao` do item;
   - `cancelada` ou OC `cancelado` (a requisição volta a `aberta` e reaparece): a linha acompanha.
5. **Aviso ao requisitar (P3):** só avisa (decisão do PCP registrada). A requisição do hub **não abate nem vincula**; só a OC aprovada abate (N14-29).
6. Se a unidade de medida da requisição difere da do material no MES, o MES avisa (regra de 13/10).
7. **Torre de Fluxo:** esta projeção **não gera evento** de fluxo (N14-28).

## 4. Critérios de aceite

1. A requisição do Compras com pedido de venda aparece na rota; a sem pedido e a do MES não.
2. `codigo_produto_omie` vem preenchido quando `material` é `codigo_produto` da unidade; `null` quando não casa; `material` de outra unidade não casa.
3. Emitir a OC marca a requisição `atendida` e ela **reaparece** na leitura seguinte com `id_ordem_compra`, `numero_ordem_compra` e `situacao_ordem_compra = aguardando_aprovacao` (✅ testado no banco de teste).
4. A aprovação da OC faz a requisição reaparecer com `situacao_ordem_compra = aprovado` (✅ testado).
5. Cancelar a OC devolve a requisição a `aberta` e ela reaparece com `visivel_ao_pcp = true` (✅ testado).
6. Cancelar a requisição, ou tirar o pedido de venda, faz ela reaparecer com `visivel_ao_pcp = false` (✅ testado).
7. Cursor `(alterado_em, id)` com `apos_id` não repete nem perde linha entre páginas (mesmo teste da referência da OC).
8. A chave de serviço do MES lê a rota; a chave do contrato 34 recebe `403 CHAVE_MES_ROTA_NAO_PERMITIDA`.
9. `GET /compras/requisicoes/referencia` não é capturada por `/compras/requisicoes/:id`.
10. No MES: a requisição aparece ao PCP em até 5 min; vira OC e a tela passa a mostrar "OC X aguardando aprovação" e depois a OC aprovada; o aviso de duplicidade aparece ao requisitar o mesmo pedido e produto.
11. Requisição do hub **sem** pedido de venda não aparece no MES e não entra na Torre.

## 5. Ordem e rollback

| # | Quem | Passo |
|---|---|---|
| 1 | Gustavo | [[API-010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto]] (`api010`, POST e PATCH) |
| 2 | Gustavo | `api009` (marca, triggers e view), depois a rota, o swagger e a chave do MES |
| 3 | Robert | Job e projeção ([[API-011-Compra-em-Andamento-Recebimento-por-Item-da-OC-e-Uso-Interno]]) |
| 4 | Robert, Nathan | Telas do PCP e aviso ao requisitar |

**Rollback:** a rota e a view são só de leitura. Desligar o job do MES apaga a tela, sem efeito em Compras. Reverter a migration: `DROP TRIGGER`, `DROP VIEW`, `DROP FUNCTION fn_req_referencia_mes_marcar`, `DROP TABLE requisicoes_compra_referencia_mes`.

## 6. Perguntas em aberto

| #   | Pergunta                                                                                                                                        | Dono    | Selo |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ---- |
| Q1  | ✅ Respondida pelo Robert (15/10): `material` não é `codigo_produto_omie`; a rota devolve os dois                                                | Robert  | ✅    |
| Q2  | ✅ A trigger da OC atualiza o `updated_at` da requisição (existe `trg_requisicoes_compra_updated_at`), mas com `NOW()`; por isso a marca própria | Gustavo | ✅    |
| Q3  | Unidade do pedido de venda: ✅ sempre a da requisição (N14-31); a rota não precisa devolver `codigo_empresa_pv`                                  | Nathan  | ✅ 📝 |
| Q4  | O aviso de compra duplicada só avisa ✅ (N14-29)                                                                                                 | Nathan  | ✅ 📝 |
| Q5  | ✅ 500 por página basta (Robert, 15/10)                                                                                                          | Robert  | ✅    |
| Q6  | A transação do `POST /compras/requisicoes` e a marca: o `INSERT` já dispara a trigger; nenhum ajuste na API                                     | Gustavo | ✅    |
| Q7  | ✅ O banco de teste tem 1 requisição com pedido de venda (e 1 OC vinculada). Usando o Omie como teto: ~76 pedidos de compra por dia útil (pico 144); o limite de 500 por página a cada 5 minutos dá conta com folga. | Gustavo | ✅    |

Relacionados: [[API-004-Referencia-OC-Integracao-MES]], [[API-007-Referencia-OC-Valores-no-MES]], [[API-010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto]], [[API-011-Compra-em-Andamento-Recebimento-por-Item-da-OC-e-Uso-Interno]], [[LOG-34-Requisicoes-MES-Empurra-para-o-Hub]], [[LOG-35-Compras-Marcos-Requisicao-para-MES]], [[04-Circuito-de-Compra]], [[02-PCP-Triagem-e-Destinacao]], [[Backlog-por-Frente]] (BL-064, BL-065), [[Registro-de-Decisoes]] (N14-28 a N14-33).
