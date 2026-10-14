---
id: API-004
aliases: ["Contrato 004", "004-Referencia-OC-Integracao-MES"]
tags: [contrato, contrato-api, mes, integracao-av-hub-mes, compras]
criado: 2026-10-14
atualizado: 2026-10-14
status: parcial
dono: "Robert"
etapa_0b: [C4, R0, R4]
fontes: ["api-acos-vital/src/schemas/core_vendas_faturamento/views/vw_ordens_compra_referencia_mes/vw_ordens_compra_referencia_mes.route.js:70", "api-acos-vital/src/schemas/core_vendas_faturamento/index.js:199", "Dump Avhub (Esqueleto).sql:20237", "api-pcp (grep: nenhuma referência à rota)"]
criado_original: 2026-09-22
---

# Contrato de API 004 — Referência da Ordem de Compra (av-hub → MES)

> [!info] Situação em 14/10/2026
> **Status:** `parcial` · **Pasta:** `Ativos` · **Nós do 0b:** C4, R0, R4 · **Dono:** Robert
>
> - ✅ **Lado do av-hub entregue:** `GET /ordens-compra/referencia?alterado_desde=&codigo_empresa=&page=&limit=&apos_id=` (`api-acos-vital/src/schemas/core_vendas_faturamento/views/vw_ordens_compra_referencia_mes/vw_ordens_compra_referencia_mes.route.js:70`, montada em `index.js:199`). `alterado_desde` obrigatório (ISO 8601), `limit` padrão 100 e máximo 500; a regra mora na view `vw_ordens_compra_referencia_mes` (`Dump Avhub (Esqueleto).sql:20237`) e a marca `alterado_em` na tabela `ordens_compra_referencia_mes` (trigger).
> - ✅ Chave: rota de serviço sem token de usuário; a chave `MES_INTEGRACAO_KEYS` do LOG-34 responde `403 CHAVE_MES_ROTA_NAO_PERMITIDA` aqui (`vw_ordens_compra_referencia_mes.route.js:26-30`); o MES lê com chave de leitura de `auth.chaves_servico` ou de `API_KEYS`.
> - 🔴 **Lado do MES não existe:** o `api-pcp` não tem job nem referência a `/ordens-compra/referencia` nem tabela de projeção da OC (grep em `api-pcp/src` e `api-pcp/prisma` sem resultado). Falta o job de leitura a cada 5 min com UPSERT por `(codigo_empresa, id_ordem_compra)` e itens por `(id_ordem_compra, id_item_oc)`, e o ajuste de `id_origem` em cada item (pedido do Robert em 30/09).
> - ✅ Consequência já tratada: o registro manual `PATCH /compras/requisicoes/:id/compra` saiu do MES (não está mais em `api-pcp/src/compras/compras.controller.ts`); o MES hoje usa os marcos do [[LOG-35-Compras-Marcos-Requisicao-para-MES]]. Fornecedor da OC só chegará ao MES com este job.
> - Feito o job, o Recebimento passa a conferir também contra a OC (decisão do Nathan: hoje confere só contra a NF) e a extensão [[API-007-Referencia-OC-Valores-no-MES]] alimenta o custo do lote ([[API-008-Custo-do-Lote-no-MES]]).
>
> Conferido em 14/10/2026 contra `api-pcp` 579a625, `app-pcp` 1fca8d3, `api-acos-vital` f322dcd, `omie-elt-pipeline` 0f739f0 e os dumps de 14/10. O front do av-hub (HUB b55ac55) só pelo vault v1 (❓).
> O texto original abaixo está inteiro; os trechos que o estado atual contradiz têm nota de rodapé.


> Status: decidido | no código | em produção (verificado em 09/10/2026): **✅ lado do hub implementado** (o Nathan informou em 09/10 que o DBA entregou; conferido no código: commit `fe55923` de 08/10, na `develop` e na `main` da `api-acos-vital` pelo PR #284). **🔴 lado do MES não existe**: o `api-pcp` não tem nenhuma referência à rota.[^c3] **Banco: a migration `api004` foi entregue e aplicada pelo DBA (palavra do Gustavo, 09/10).** O registro manual `PATCH /compras/requisicoes/:id/compra` **segue valendo**[^c2] até o MES passar a ler a rota. Fonte: [[Registro-de-Decisoes|Registro-de-Decisoes-2026-10-07]] (#41).

> **Extensão decidida (09/10/2026):** o [[API-007-Referencia-OC-Valores-no-MES|007-Referencia-OC-Valores-no-MES]] (com o SQL [[SQL-012-Ordens-Compra-Referencia-Valores|012-Ordens-Compra-Referencia-Valores]]) faz a rota devolver valor unitário, desconto, moeda, cotação e frete da OC, para o lote comprado nascer com custo ([[Modelo-Estoque-e-Custo-do-Lote|Estoque-Custo-do-Lote]]). A frase "sem preço" deste contrato fica revogada por aquele. Imposto por item não existe na OC.

> **Atualização de 09/10/2026 — conferido no código (`origin/develop` da `api-acos-vital`, `dee35b0`):** `GET /ordens-compra/referencia?alterado_desde=&codigo_empresa=&page=&limit=` existe (`views/vw_ordens_compra_referencia_mes`). `alterado_desde` é obrigatório (ISO 8601); `limit` padrão 100 e máximo 500; aceita `apos_id` como desempate do cursor (extensão do contrato). **A regra fica no banco**: a rota lê a view `vw_ordens_compra_referencia_mes` e o `alterado_em` vem de trigger (migration **`api004`**). Sem a migration a rota responde 500 "exige a migration api004 no banco": **o DBA (Gustavo) afirmou em 09/10 que a entregou e aplicou**; o vault só não a vê porque o repositório não versiona SQL. **Chave:** rota de serviço, sem token de usuário e sem linha em `auth.rotas_telas`. A chave do MES do contrato 34 (`MES_INTEGRACAO_KEYS`) dá **403 `CHAVE_MES_ROTA_NAO_PERMITIDA`** aqui (decisão do Gustavo em 08/10); o MES deve ler com uma chave de **leitura** de `auth.chaves_servico` ou de `API_KEYS`. **Pendente no MES (Robert):** o job de leitura a cada 5 min com UPSERT por `(codigo_empresa, id_ordem_compra)` e itens por `(id_ordem_compra, id_item_oc)`, e o ajuste `id_origem` por item pedido em 30/09. O código do hub é de `HauntedCrusader`.

> **Linha do tempo (08/10/2026):** criado em 22/09/2026 como rascunho da F1 e aprovado pelo Nathan no mesmo dia; revisões de 29/09 e 30/09 (Robert). Plano e pendências em [[Integracao-AvHub-MES|Integracao-AvHub-MES-Volta-Plano]].

> **Atualização de 07/10/2026 — conferido no código (`main` = `develop` da `api-acos-vital`, `a6ab058`/`fdafb35`; `develop` do `api-pcp`):** a rota `GET /ordens-compra/referencia` **continua inexistente na API** (nem rota, nem "referencia" no código) e **no MES não há nada** que a consuma: o registro da compra segue manual (`PATCH /compras/requisicoes/:id/compra`, nº do pedido, fornecedor, previsão) e não existe job de poll de OC. Os pré-requisitos de **dados** existem: `ordens_compra_itens_vinculos`, `requisicoes_compra.id_origem` e `status`. O ajuste do Robert (`id_origem` em cada item) **segue pendente**, assim como a aprovação do Gustavo. Status: `proposta`. Atenção: a chave própria do MES que existe hoje (`MES_INTEGRACAO_KEYS`, do [[LOG-34-Requisicoes-MES-Empurra-para-o-Hub|34-Requisicoes-MES-Empurra-para-o-Hub]]) **só abre o PUT** `/compras/requisicoes/origem/{id}` — não serve para esta rota (ver Autenticação). Nada disto vem de produção. Ver [[HIST-Indice-Contratos|Indice-Contratos]] (Conferência de 07/10/2026) e [[Chaves-e-Autenticacao|Chaves-de-Integracao-AvHub-MES-Pipeline]].

> **01/10/2026:** a requisição (ida, contrato 003) passou a ser empurrada pelo MES, ver [[LOG-34-Requisicoes-MES-Empurra-para-o-Hub|34-Requisicoes-MES-Empurra-para-o-Hub]]. Este contrato (volta) continua como está e ainda não foi implementado.

**Status:** proposta. Aprovada por Nathan em 22/09/2026 a partir do rascunho consolidado em[^c1]
[[Integracao-AvHub-MES|Integracao-AvHub-MES-Especificacao-F1]] (Fluxo 2) e **revisada em 29/09/2026** contra o banco real de
Compras. **Robert respondeu em 30/09/2026:** o formato do `destino` atende o Recebimento, com um ajuste
(cada item traz também o `id_origem`, abaixo). **Aprovação do Gustavo ainda pendente.**
**Destinatários:** backend do av-hub (`api-acos-vital`, expõe a rota) e MES (`api-pcp`, Robert, lê a rota).

> **O que mudou na revisão de 29/09/2026:**
> - o pré-requisito existe: as OCs estão em `core_vendas_faturamento.ordens_compra` / `_itens`
>   (contrato SQL [[SQL-007-Ordens-Compra-Estruturada|007-Ordens-Compra-Estruturada]] e [[LOG-13a-Compras-Backend-Consolidado|13-Compras-Backend-Consolidado]], na `api-test`);
> - **a requisição agora é por item**, não por OC: desde o [[LOG-14b-Compras-Vinculo-Pedido-Venda|14-Compras-Vinculo-Pedido-Venda]] uma OC pode
>   juntar várias requisições do MES (`ordens_compra_itens.id_requisicao`). O antigo `id_requisicao_origem`
>   no cabeçalho saiu;
> - nomes de campo iguais aos do banco e da API de hoje (`numero_pedido`, `tipo_material`,
>   `data_previsao_chegada`…);
> - entram o número do pedido no Omie (a NF-e do fornecedor cita ele), o destino de cada item
>   (pedido de venda ou estoque) e a situação da OC (só aprovada vai ao MES; cancelada sai);
> - paginação definida (era pergunta em aberto).

> **O que mudou em 30/09/2026 (retorno do Robert):**
> - cada item ganha **`id_origem`**: o id do item da requisição no MES, o mesmo que o av-hub recebeu pelo
>   [[API-003-Requisicao-Compra-Integracao-MES|003-Requisicao-Compra-Integracao-MES]]. O `id_requisicao` é o uuid da requisição **no av-hub**, que o
>   MES não conhece; e o `numero_requisicao_mes` sozinho não identifica o item quando a requisição do MES
>   tem mais de um material (o número se repete);
> - a chave do MES precisa ser de **escrita** (seção Autenticação);
> - perguntas 2 e 3 respondidas.
>
> **Enquanto a rota não existe** (conferido na `develop` da API em 30/09: só há `/compras/ordens`, da tela do
> comprador), o setor Compras do MES tem um **registro manual da compra** (nº do pedido, fornecedor,
> previsão). Quando a rota sair, entra o polling de 5 min e o registro manual sai.

## Por quê

Corresponde à conversa **C7** de [[04-Circuito-de-Compra|Fluxo-Compras-Completo]]: quando o material chega na doca, o
Recebimento (tarefas D6/D7) confere contra o que foi comprado. O item **acabado** confere contra o pedido
de venda; o **não acabado** confere contra a OC — que só existe no av-hub. Sem esta rota, o Recebimento do
MES não enxerga as OCs emitidas no av-hub.

**Não trafega preço, fornecedor, condição de pagamento, categoria nem conta corrente:** só o necessário
para a conferência de quantidade, a mesma filosofia de "colunas protegidas" do [[Pipeline-Omie|Omie-ELT-Pipeline]].

## Onde isso mora

Lado que expõe: **av-hub** (`api-acos-vital`), dono da decisão de compra. Lado que consome: **MES**
(`api-pcp`), com um job de leitura periódica (polling) que grava uma projeção local para o Recebimento.

## A rota

### `GET /ordens-compra/referencia?alterado_desde=&codigo_empresa=&page=&limit=`

| Parâmetro | Regra |
|---|---|
| `alterado_desde` | **obrigatório**, ISO 8601. Devolve as OCs cujo `alterado_em` (ver abaixo) é **maior** que ele, em ordem crescente de `alterado_em` (e `id` para desempate) |
| `codigo_empresa` | opcional (uuid da unidade). Sem ele, todas as unidades |
| `page`, `limit` | paginação; `limit` padrão 100, máximo 500 |

**Quais OCs entram:** as que **já foram aprovadas** (`status = aprovado`) e as **canceladas depois de
aprovadas**, para o MES tirá-las da fila. Rascunho e aguardando aprovação **não** entram: o fornecedor
ainda não recebeu o pedido.

**`alterado_em`** = o maior entre o `updated_at` da OC, dos itens e dos vínculos com pedido de venda.
Mudar a quantidade de um item ou o destino dele precisa fazer a OC reaparecer na próxima leitura.

**Response (200):**
```json
{
  "total": 1, "page": 1, "limit": 100, "total_pages": 1,
  "data": [
    {
      "id_ordem_compra": "uuid",
      "codigo_empresa": "uuid-da-unidade",
      "numero_pedido": "OC-000123",
      "numero_pedido_omie": "46618",
      "situacao": "aprovada",
      "finalidade": "pedidos_venda",
      "data_previsao_chegada": "2026-10-20",
      "alterado_em": "2026-10-18T09:00:00Z",
      "itens": [
        {
          "id_item_oc": "uuid",
          "ordem": 1,
          "codigo_produto_omie": "9764577293",
          "descricao_produto": "FLANGE CEGO RF B16.5 150LBS AC 6\"",
          "quantidade": 10.0,
          "unidade_medida": "PC",
          "tipo_material": "acabado",
          "local_estoque": "Galpão 2",
          "id_requisicao": "uuid-ou-null",
          "id_origem": "uuid-ou-null",
          "numero_requisicao_mes": "RC-20261001-0007",
          "destino": [
            { "tipo": "pedido_venda", "numero_pedido_venda": "25970", "codigo_empresa_pv": "uuid", "quantidade": 8.0 },
            { "tipo": "estoque", "quantidade": 2.0 }
          ]
        }
      ]
    }
  ]
}
```

**Regras dos campos:**
- `situacao`: `aprovada` ou `cancelada`. Cancelada = o MES tira a OC da fila de Recebimento (se já houve
  recebimento parcial, é problema a tratar no MES; ver Perguntas).
- `numero_pedido_omie`: `null` enquanto a OC não chegou ao Omie. É o número que a NF-e do fornecedor cita.
- `codigo_produto_omie`: `null` quando o item é material ainda sem cadastro (texto livre); aí vale a
  `descricao_produto`.
- `tipo_material`: `acabado` | `nao_acabado` — decide contra o que o Recebimento confere
  (C9 de [[04-Circuito-de-Compra|Fluxo-Compras-Completo]]); **nunca vem vazio**.
- `id_requisicao` / `id_origem` / `numero_requisicao_mes`: a requisição que o item atende (a do contrato
  [[API-003-Requisicao-Compra-Integracao-MES|003-Requisicao-Compra-Integracao-MES]]). `id_requisicao` é o uuid dela no av-hub; **`id_origem` é o id
  do item da requisição no MES** (`requisicoes_compra.id_origem`) e é por ele que o MES liga o item da OC à
  requisição; `numero_requisicao_mes` é o número `RC-AAAAMMDD-NNNN`, para exibir. Os três vêm `null` quando
  o comprador comprou sem requisição (reposição de estoque, por exemplo); `id_origem` também vem `null` na
  requisição criada à mão no av-hub.
- `destino`: para qual pedido de venda vai o item e quanto fica em estoque (vínculos do
  [[LOG-14b-Compras-Vinculo-Pedido-Venda|14-Compras-Vinculo-Pedido-Venda]]). A quantidade é sempre na unidade do item da OC. Soma = `quantidade`.

**Erros:** 400 se `alterado_desde` faltar ou não for data; 400 se `codigo_empresa` não for uuid.

## Idempotência

`UPSERT` no MES pela chave `(codigo_empresa, id_ordem_compra)`; itens por `(id_ordem_compra, id_item_oc)`.
Item que some da resposta de uma OC que voltou = item removido. O cursor `alterado_desde` é sempre o maior
`alterado_em` já processado com sucesso.

## Autenticação

`x-api-key` com uma chave **própria do MES** (MES chamando av-hub), no mesmo `apiKeyAuth.js` que a
`api-acos-vital` já usa. É a mesma chave do item L6 do [[LOG-26-Vendas-Liberacao-Pedido|26-Vendas-Liberacao-Pedido]]: cadastrada em
`auth.chaves_servico` com nível **escrita** (o `POST /pedidos_liberados/:n/importado` é escrita; com
leitura dá 403) e restrita às rotas que o MES usa (`/pedidos_liberados/*`, `/ordens-compra/referencia`,
`/unidades`, `/produtos`). A restrição por rota ainda não existe na API. No `api-pcp` a chave é a variável
`API_KEY`; quando a chave nova existir, é só trocar o valor.

> **(atualizado em 07/10, conferido no código)** O parágrafo acima descreve a intenção, não o que existe: o `apiKeyAuth.js` tem 3 tipos de chave — `API_KEYS` do ambiente (admin), `auth.chaves_servico` no banco (leitura/escrita/admin, cache de 30 s, **sem restrição por rota**) e `MES_INTEGRACAO_KEYS` (**só o PUT do 34**). A "chave do MES de escrita restrita às rotas que o MES usa" **não existe**: a `MES_INTEGRACAO_KEYS` dá 403 `CHAVE_MES_ROTA_NAO_PERMITIDA` em `/pedidos_liberados`, `/unidades`, `/produtos` e `/compras/requisicoes/eventos` (até em GET), então o MES lê essas rotas com chave admin ou do banco. É o L6 do [[LOG-26-Vendas-Liberacao-Pedido|26-Vendas-Liberacao-Pedido]], ainda aberto.

## Polling

Intervalo proposto: **5 minutos**. O gatilho real é a chegada física na doca, detectada no MES — a
latência de 5 min não atrasa o caminho crítico.

## Perguntas em aberto

1. **OC cancelada com recebimento parcial no MES:** o MES só marca, ou avisa o comprador? (O av-hub hoje
   não recebe nada de volta sobre recebimento — isso seria o fluxo 3, [[API-005-Status-Item-Integracao-MES|005-Status-Item-Integracao-MES]].)
2. ~~Aprovação do Robert: formato do `destino` e uso do `numero_requisicao_mes`.~~ **Respondida em
   30/09:** o `destino` atende; o item precisa do `id_origem` (já no contrato acima).
3. ~~O `api-pcp` já tem cliente HTTP para chamar o av-hub?~~ **Respondida em 30/09:** tem (é o que lê
   `/pedidos_liberados`, `/unidades` e `/produtos`); falta só a chave própria.

## Depois de aplicado

- av-hub (backend): criar `GET /ordens-compra/referencia` em `api-acos-vital`, lendo de `ordens_compra`,
  `ordens_compra_itens` e `ordens_compra_itens_vinculos`, e a chave `AVHUB_API_KEY` restrita.
- MES (Robert): job de polling em `api-pcp` (5 min) e a fila de Recebimento (D6/D7) usando a projeção.

## Aceite

- Uma OC aprovada aparece na próxima leitura com os itens, o tipo de material e o destino; rascunho e
  aguardando aprovação não aparecem.
- Cancelar uma OC aprovada faz ela voltar com `situacao: cancelada`.
- Mudar o destino de um item (vínculo com PV) faz a OC voltar na leitura seguinte.
- Uma OC com duas requisições do MES traz o `id_requisicao` e o `id_origem` certos em cada item.
- A resposta não tem preço, fornecedor nem condição de pagamento.

## Ver também
- [[Integracao-AvHub-MES|Integracao-AvHub-MES-Especificacao-F1]]
- [[SQL-007-Ordens-Compra-Estruturada|007-Ordens-Compra-Estruturada]]
- [[LOG-13a-Compras-Backend-Consolidado|13-Compras-Backend-Consolidado]]
- [[LOG-14b-Compras-Vinculo-Pedido-Venda|14-Compras-Vinculo-Pedido-Venda]]
- [[API-003-Requisicao-Compra-Integracao-MES|003-Requisicao-Compra-Integracao-MES]]
- [[API-005-Status-Item-Integracao-MES|005-Status-Item-Integracao-MES]]
- [[LOG-26-Vendas-Liberacao-Pedido|26-Vendas-Liberacao-Pedido]]
- [[HIST-Indice-Contratos|Indice-Contratos]]
- [[04-Circuito-de-Compra|Fluxo-Compras-Completo]]

[^c1]: Nota de 14/10/2026: Status vigente: `parcial` (hub entregue, MES sem consumo). A frase "proposta" é do texto original.
[^c2]: Nota de 14/10/2026: Superado: o `PATCH /compras/requisicoes/:id/compra` foi removido do MES (Compras·CCP, `api-pcp` 579a625); o MES usa os marcos do LOG-35.
[^c3]: Nota de 14/10/2026: Continua verdadeiro (conferido por grep em `api-pcp/src` e `api-pcp/prisma`).
