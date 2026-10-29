---
id: API-010
aliases: ["Contrato 010", "010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto"]
tags: [contrato, contrato-api, compras, requisicao, av-hub, sql]
criado: 2026-10-15
atualizado: 2026-10-29
status: parcial
sistemas: [hub-banco, hub-api, hub-front]
dono: "Gustavo"
etapa_0b: [C0]
fontes: ["N14-28, N14-30, N14-31, N14-33 (Registro-de-Decisoes)", "api-acos-vital src/schemas/core_vendas_faturamento/tables/requisicoes_compra/requisicoes_compra.route.js:30-45 (CAMPOS), :384-411 (POST), :413-466 (PATCH), requisicoes_compra.model.js, requisicoes_compra.swagger.json", "Dump Avhub (Esqueleto).sql:18541-18572 (requisicoes_compra), :8680-8826 (fn_requisicao_mes_aplicar), :6319-6394 (fn_oc_vinculos_validar), :11648-11666 (core.produtos), :2328-2377 (pedidos_vendas)", "HUB PR #209 (tela própria da Nova requisição)"]
criado_original: 2026-10-15
---

# Contrato de API 010 — Requisição do Compras: finalidade, pedido de venda e produto do cadastro

> **Onde atua:** av-hub: banco, API, front

> [!abstract] Resumo em linguagem natural
> **O que é:** Muda a requisição de compra do av-hub: ela passa a dizer para que se compra (pedido de venda, recompra, estoque ou uso interno), com produto sempre do cadastro e tudo na mesma unidade.
> **Quem é afetado:** Compras, que cria a requisição com mais regras. Só a requisição com pedido de venda (PV) chega ao MES (sistema de produção).
> **Situação:** Parcial. Banco e API em produção desde 20/10, segundo o Gustavo (não conferido); front do Nathan pronto e API testada ponta a ponta na api-test em 29/10 (✅). Perguntas sobre a HRM e o setor do uso interno seguem abertas (🟡 🔴).
> **Exemplo:** Finalidade "pedidos_venda" sem número de pedido de venda é recusada com erro 400.

> [!info] Situação em 29/10/2026
> **Status:** `parcial` · **Pasta:** `Ativos` · **Nó do 0b:** C0 · **Dono:** Gustavo (banco e API); Nathan (front, já pronto)
>
> - ✅ Banco, API e front estão feitos e testados (itens abaixo). O que mantém o contrato em `parcial` são só as perguntas Q1 (exceção da HRM) e Q3 (setor que pediu o uso interno), do Nathan, na seção 10; se elas forem respondidas sem mudança de código, o contrato pode ir para `Entregues`.
>
> - ✅ **Migration `api010` em produção desde 20/10/2026** (entrou na MEGA de 19/10), informado pelo Gustavo em 26/10; não conferi no banco.
> - ✅ **Front pronto (HUB PR #209):** a "Nova requisição" é uma tela própria (`/compras/requisicoes/nova`) e já envia `finalidade`, `numero_pedido_venda` e `material` = `codigo_produto` do cadastro.
> - ✅ **A API atende** (conferido na `develop` de `api-acos-vital`, 21/10/2026): `requisicoes_compra.model.js` tem `finalidade` e `numero_pedido_venda`; a rota valida e responde `FINALIDADE_INVALIDA`, `PEDIDO_VENDA_INEXISTENTE` e `PRODUTO_INEXISTENTE` (`requisicoes_compra.route.js:82,124,500,511`).
> - ✅ **Testado na `api-test` (29/10/2026, Nathan):** a "Nova requisição" criou a REQ-000040 com `finalidade = pedidos_venda` e `numero_pedido_venda = 27605`, e a API devolveu os dois campos gravados. Era uma requisição de teste e foi cancelada em seguida.
> - ✅ (26/10) A migration `api010` e a trava de unidade estão em produção desde 20/10, segundo o Gustavo.
> - ✅ **SQL escrito e testado em banco descartável** (PostgreSQL 18, schema restaurado de `Dump Avhub (Esqueleto).sql`, tabelas vazias): [[0001-requisicoes-finalidade.sql]] em `API-010-anexos/`. Testes feitos: o PUT do MES grava a finalidade (`pedidos_venda` com pedido, `estoque` sem); os dois `CHECK` recusam `estoque` com pedido, `pedidos_venda` sem pedido e finalidade inválida; a trava do vínculo da OC aceita a mesma unidade e a unidade que compra por ela, e recusa outra. **Não testado nesse banco descartável:** o código da rota e uma carga real. O código da rota existe na `develop` e foi testado ponta a ponta na `api-test` em 29/10/2026 (ver o item abaixo).
> - A migration se chama **`api010`** (padrão `apiNNN`, como `api004` e `api007`).
>
> Este contrato **absorve a Parte 1** do [[API-009-Referencia-Requisicao-Hub-Integracao-MES]]; em caso de diferença, vale este. Selos em [[Regras-do-Vault]].

## Por quê

Decisões do Nathan (15/10/2026): a requisição do Compras é **para que** (pedido de venda, recompra, estoque ou uso interno, N14-33); o produto é **sempre do cadastro** (N14-30); pedido de venda, requisição e ordem de compra são **da mesma unidade** (N14-31); e só a requisição com pedido de venda chega ao MES (N14-28). O banco já tem as colunas `numero_pedido_venda` e `codigo_pedido_omie`, mas **só o PUT do MES as grava**. Este contrato abre o POST e o PATCH do Compras para elas e cria a `finalidade`.

## 1. Banco (migration `api010`)

Arquivo: [[0001-requisicoes-finalidade.sql]]. Aditivo e idempotente; rodar antes de subir a API nova e antes da `api009`.

| Mudança | SQL (resumo) | Observação |
|---|---|---|
| Coluna | `ALTER TABLE core_vendas_faturamento.requisicoes_compra ADD COLUMN IF NOT EXISTS finalidade varchar(15)` | `NOT NULL`, `DEFAULT 'estoque'` |
| Preenchimento | `finalidade = CASE WHEN numero_pedido_venda IS NOT NULL THEN 'pedidos_venda' ELSE 'estoque' END` | Desliga `trg_requisicoes_compra_updated_at` só durante o backfill, para não mexer em `updated_at` |
| `CHECK ck_requisicoes_compra_finalidade` | `finalidade IN ('pedidos_venda','recompra','estoque','uso_interno')` | Mesma lista de `ordens_compra.finalidade` |
| `CHECK ck_requisicoes_compra_finalidade_pv` | `(finalidade IN ('pedidos_venda','recompra')) = (numero_pedido_venda IS NOT NULL)` | Pedido de venda e recompra exigem o pedido; estoque e uso interno não o aceitam |
| Índice | `ix_requisicoes_compra_pedido (codigo_empresa, numero_pedido_venda) WHERE numero_pedido_venda IS NOT NULL AND deleted_at IS NULL` | Base da referência do API-009 |
| `fn_requisicao_mes_aplicar` | substituída (mesmo texto da 034, só com a `finalidade` derivada do pedido de venda) | O PUT do MES não muda de contrato; sem isso o `CHECK` quebraria o PUT |
| `fn_oc_vinculos_validar` | substituída (mesmo texto atual, com a trava de unidade) | N14-31; ver seção 4 |

**Conferência prévia (bloco 0 do SQL):** requisição com `codigo_pedido_omie` mas sem `numero_pedido_venda` (ficaria `estoque` sem ser); e vínculos de OC com pedido de outra unidade que a da OC. Resolver antes de aplicar.

## 2. API: `POST /compras/requisicoes`

Hoje `CAMPOS` aceita `numero_requisicao, codigo_empresa, material, descricao, quantidade, unidade_medida, prazo_necessidade, acabado_sugerido, solicitante, observacao, created_by, id_origem, numero_requisicao_mes`. Acrescentar `finalidade` e `numero_pedido_venda`. `codigo_pedido_omie` **não** entra no POST (fica nulo; só o PUT do MES o usa).

### Validações (na rota, antes do `create`; todas devolvem `400 { detail, codigo }`)

| Ordem | Regra | `codigo` |
|---|---|---|
| 1 | `finalidade` obrigatória e em `pedidos_venda`, `recompra`, `estoque`, `uso_interno` | `FINALIDADE_INVALIDA` |
| 2 | `pedidos_venda` e `recompra` exigem `numero_pedido_venda`; `estoque` e `uso_interno` não o aceitam | `FINALIDADE_PEDIDO_VENDA` |
| 3 | `material` (texto, até 60) tem de ser um `core.produtos.codigo_produto` da **mesma** `codigo_empresa`, não excluído e ativo | `PRODUTO_INEXISTENTE` |
| 4 | Pedido de venda existe na mesma unidade (abaixo) | `PEDIDO_VENDA_INEXISTENTE` |
| 5 | Os campos de hoje (`codigo_empresa` uuid, `quantidade > 0`, obrigatórios) | como hoje |

**Produto (regra 3), SQL de referência:**
```sql
SELECT p.descricao
  FROM core.produtos p
 WHERE p.codigo_empresa = :empresa
   AND p.codigo_produto = btrim(:material)
   AND p.deleted_at IS NULL AND p.ativo;
```
A API preenche `descricao` com o do cadastro quando o corpo não trouxer. `uq_produtos_codigo (codigo_empresa, codigo_produto)` garante no máximo um.

**Pedido de venda (regra 4), mesmo critério que o banco já usa em `fn_oc_vinculos_validar`:**
```sql
SELECT EXISTS (
  SELECT 1 FROM core_vendas_faturamento.pedidos_vendas p
   WHERE p.codigo_empresa = :empresa
     AND p.numero_pedido = btrim(:numero_pedido_venda)
     AND p.deleted_at IS NULL);
```
`numero_pedido` pode ter várias linhas (parcelas, `sequencial` diferente): por isso `EXISTS`. **Exceção que o banco já conhece:** unidade **sem Omie** (`core.unidades.id_unidade_compra IS NOT NULL`, caso da HRM) não tem o pedido no banco; para ela o pedido é aceito sem conferência, como a OC faz (`pv_conferido = false`).

Resposta `201`: a requisição inteira (instância Sequelize do model `RequisicaoCompra`), agora com `finalidade`. Erros do banco continuam passando por `handleSequelizeError`.

**Model:** `requisicoes_compra.model.js` ganha `finalidade: { type: DataTypes.STRING(15), allowNull: false, defaultValue: "estoque" }`.

### Exemplo

```http
POST /compras/requisicoes
{ "finalidade": "pedidos_venda", "codigo_empresa": "759979bd-2b2d-41f2-b1b7-db6fae89ee59",
  "numero_pedido_venda": "27605", "material": "CH45025X6X1K", "quantidade": 8,
  "unidade_medida": "PC", "prazo_necessidade": "2026-11-05", "acabado_sugerido": false,
  "observacao": "Cliente pediu entrega fracionada", "created_by": "<uuid do usuário>" }
```
```json
{ "id": "…", "numero_requisicao": "REQ-000412", "status": "aberta", "finalidade": "pedidos_venda",
  "numero_pedido_venda": "27605", "codigo_pedido_omie": null, "material": "CH45025X6X1K",
  "descricao": "CHAPA …", "quantidade": "8.0000", "unidade_medida": "PC", "prazo_necessidade": "2026-11-05" }
```

## 3. API: `PATCH /compras/requisicoes/:id`

Hoje só aceita `status` (e `motivo` ao cancelar); qualquer outro campo é ignorado. Passa a aceitar, **além** do `status`, `numero_pedido_venda` e `finalidade` (trocados juntos, pela mesma coerência da seção 2) e `quantidade`, `unidade_medida`, `prazo_necessidade`, `observacao`. Regras:

- Só com `status` `aberta` ou `em_cotacao` e `id_origem` nulo. Requisição do MES, `atendida` ou `cancelada` devolve `409 REQUISICAO_NAO_EDITAVEL`.
- O `material` e a `codigo_empresa` **não** mudam.
- `updated_by` do token (`req.usuario.id`), como o PATCH de status já faz.
- Sem `status` no corpo, o PATCH deixa de devolver `400 "status é obrigatório"` quando vier algum dos campos acima.

## 4. A OC na mesma unidade (N14-31)

**Estado verificado:** o banco **não** obriga o pedido do vínculo a ser da unidade da OC. `fn_oc_vinculos_validar` só confere que a unidade do pedido existe, e a tabela `ordens_compra_itens_vinculos` nem tem `codigo_empresa` (só `codigo_empresa_pv`). A trava nova (no SQL, seção 3 do anexo):

> O `codigo_empresa_pv` do vínculo é igual ao `codigo_empresa` da OC, **ou** a unidade do pedido compra pela unidade da OC (`core.unidades.id_unidade_compra`).

A segunda parte preserva a HRM (sem Omie, compra pela unidade X). Mesma lógica que o banco já usa em `fn_oc_itens_requisicao` para aceitar a requisição de uma unidade em OC de outra. 🟡 **Nathan confirma** que a HRM continua podendo (Q1). Vale só para linhas novas; as antigas ficam.

**A OC herda a finalidade da requisição.** Hoje a tela da OC, vindo de requisição, só restringe a finalidade (`finalidadesPermitidas` em `FecharCompra.tsx`). Com `finalidade` na requisição, a OC emitida a partir dela usa a mesma finalidade e o mesmo pedido; várias requisições na mesma OC têm de ter a mesma finalidade, unidade e pedido (a tela avisa). A trigger `trg_ordens_compra_finalidade_guardar` já protege a finalidade da OC depois de criada. Item do front (Nathan), depois da seção 2.

## 5. Leituras

`GET /compras/requisicoes` e `GET /compras/requisicoes/:id` devolvem `finalidade`; `GET /compras/requisicoes?finalidade=` filtra. O `/resumo` não muda. A rota `GET /compras/requisicoes/referencia` (MES) é do [[API-009-Referencia-Requisicao-Hub-Integracao-MES]].

## 6. Swagger

`requisicoes_compra.swagger.json` é mantido à mão. Hoje o POST não tem `requestBody` (só `description`). Acrescentar: `requestBody` do POST com os campos acima e `required: [finalidade, codigo_empresa, material, quantidade, unidade_medida, prazo_necessidade]`; `requestBody` do PATCH com os campos novos; a lista de erros da seção 2; `finalidade` na resposta e no filtro de `GET /`. Corrigir de passagem a chave solta `"tentativa de mexer em \"atendida\" ..."` dentro da resposta 400 do PATCH.

## 7. O que não muda

Os contratos 34 e 35, o `id_origem NOT NULL` dos eventos, o circuito do MES e o PUT `/compras/requisicoes/origem/:id_origem` (mesmo corpo, mesma resposta). A requisição **sem** pedido de venda segue sem chegar ao MES.

## 8. Critérios de aceite

1. `POST` sem `finalidade` ou com valor fora da lista devolve `400 FINALIDADE_INVALIDA`.
2. `estoque` com `numero_pedido_venda`, ou `pedidos_venda` sem ele, devolve `400 FINALIDADE_PEDIDO_VENDA`.
3. `material` que não é `codigo_produto` do cadastro da unidade devolve `400 PRODUTO_INEXISTENTE`; o de outra unidade também.
4. Pedido inexistente na unidade devolve `400 PEDIDO_VENDA_INEXISTENTE`; em unidade sem Omie é aceito.
5. `POST` válido devolve 201 com `finalidade`, `numero_pedido_venda` e `codigo_pedido_omie = null`.
6. `PATCH` troca o pedido e a finalidade juntos em requisição `aberta`; em requisição do MES, `atendida` ou `cancelada` devolve `409 REQUISICAO_NAO_EDITAVEL`.
7. O PUT do MES continua igual e grava `finalidade` (✅ testado no banco de teste).
8. Vínculo de OC com pedido de outra unidade é recusado, e o da unidade que compra por ela é aceito (✅ testado no banco de teste).
9. Swagger atualizado.
10. Ponta a ponta: a tela nova do HUB cria uma requisição de cada finalidade e ela volta com os campos gravados.

## 9. Ordem e rollback

| # | Quem | Passo |
|---|---|---|
| 1 | Gustavo | Resolver o bloco 0 e aplicar `api010` num banco de teste, depois em produção, **antes** da API |
| 2 | Gustavo | `POST`, `PATCH`, model, leituras e swagger (seções 2, 3, 5 e 6) |
| 3 | Nathan | Conferir a tela (PR #209) contra a API; a OC herda a finalidade (seção 4) |
| 4 | Gustavo | [[API-009-Referencia-Requisicao-Hub-Integracao-MES]] |

**Rollback:** a coluna é nova e tem `DEFAULT`. Reverter o deploy da API devolve ao comportamento de hoje (o HUB segue enviando os campos e a API os ignora). Reverter a migration: `ALTER TABLE ... DROP COLUMN finalidade` (e as duas constraints) e restaurar `fn_requisicao_mes_aplicar` e `fn_oc_vinculos_validar` pelo texto do dump.

## 10. Perguntas em aberto

| # | Pergunta | Dono | Selo |
|---|---|---|---|
| Q1 | A exceção da unidade que compra por outra (HRM) continua valendo na trava de unidade da OC? | Nathan | 🟡 |
| Q2 | `recompra` exige o pedido que está sendo reposto (como a tela da OC)? Proposta: sim, igual a `pedidos_venda` (já é o que o `CHECK` faz) | Nathan | 🟡 |
| Q3 | `uso_interno` precisa de "setor que pediu"? O Recebimento entrega ao setor que pediu ([[API-011-Compra-em-Andamento-Recebimento-por-Item-da-OC-e-Uso-Interno]]); hoje só há `solicitante` (texto, 100) | Nathan | 🔴 |
| Q4 | Requisição antiga cujo `material` não casa com o cadastro: manter como está (a validação vale só para criação)? Proposta: sim | Gustavo | 🟡 |
| Q5 | `descricao` vem do cadastro quando o corpo não trouxer, ou sempre do cadastro? Proposta: só quando não vier | Gustavo | 🟡 |

Relacionados: [[API-009-Referencia-Requisicao-Hub-Integracao-MES]], [[API-004-Referencia-OC-Integracao-MES]], [[LOG-34-Requisicoes-MES-Empurra-para-o-Hub]], [[LOG-36-Compras-Produto-Obrigatorio-e-Comprador-da-OC]], [[SQL-008-Requisicoes-Compra]], [[04-Circuito-de-Compra]], [[Backlog-por-Frente]] (BL-041, BL-064), [[Registro-de-Decisoes]] (N14-28 a N14-33).
