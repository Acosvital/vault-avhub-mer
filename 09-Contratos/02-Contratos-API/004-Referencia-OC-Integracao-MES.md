---
tags: [contrato-api, mes, estoque, integracao-av-hub-mes]
status: proposta
criado: 2026-09-22
atualizado: 2026-09-29
---

# Contrato de API 004 — Referência da Ordem de Compra (av-hub → MES)

**Status:** proposta. Aprovada por Nathan em 22/09/2026 a partir do rascunho consolidado em
[[Integracao-AvHub-MES-Especificacao-F1]] (Fluxo 2) e **revisada em 29/09/2026** contra o banco real de
Compras. **Aprovação formal de Robert e Gustavo ainda pendente.**
**Destinatários:** backend do av-hub (`api-acos-vital`, expõe a rota) e MES (`api-pcp`, Robert, lê a rota).

> **O que mudou na revisão de 29/09/2026:**
> - o pré-requisito existe: as OCs estão em `core_vendas_faturamento.ordens_compra` / `_itens`
>   (contrato SQL [[007-Ordens-Compra-Estruturada]] e [[13-Compras-Backend-Consolidado]], na `api-test`);
> - **a requisição agora é por item**, não por OC: desde o [[14-Compras-Vinculo-Pedido-Venda]] uma OC pode
>   juntar várias requisições do MES (`ordens_compra_itens.id_requisicao`). O antigo `id_requisicao_origem`
>   no cabeçalho saiu;
> - nomes de campo iguais aos do banco e da API de hoje (`numero_pedido`, `tipo_material`,
>   `data_previsao_chegada`…);
> - entram o número do pedido no Omie (a NF-e do fornecedor cita ele), o destino de cada item
>   (pedido de venda ou estoque) e a situação da OC (só aprovada vai ao MES; cancelada sai);
> - paginação definida (era pergunta em aberto).

## Por quê

Corresponde à conversa **C7** de [[Fluxo-Compras-Completo]]: quando o material chega na doca, o
Recebimento (tarefas D6/D7) confere contra o que foi comprado. O item **acabado** confere contra o pedido
de venda; o **não acabado** confere contra a OC — que só existe no av-hub. Sem esta rota, o Recebimento do
MES não enxerga as OCs emitidas no av-hub.

**Não trafega preço, fornecedor, condição de pagamento, categoria nem conta corrente:** só o necessário
para a conferência de quantidade, a mesma filosofia de "colunas protegidas" do [[Omie-ELT-Pipeline]].

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
          "numero_requisicao_mes": "12345",
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
  (C9 de [[Fluxo-Compras-Completo]]); **nunca vem vazio**.
- `id_requisicao` / `numero_requisicao_mes`: a requisição do MES que o item atende (a do contrato
  [[003-Requisicao-Compra-Integracao-MES]]); `null` quando o comprador comprou sem requisição (reposição
  de estoque, por exemplo).
- `destino`: para qual pedido de venda vai o item e quanto fica em estoque (vínculos do
  [[14-Compras-Vinculo-Pedido-Venda]]). A quantidade é sempre na unidade do item da OC. Soma = `quantidade`.

**Erros:** 400 se `alterado_desde` faltar ou não for data; 400 se `codigo_empresa` não for uuid.

## Idempotência

`UPSERT` no MES pela chave `(codigo_empresa, id_ordem_compra)`; itens por `(id_ordem_compra, id_item_oc)`.
Item que some da resposta de uma OC que voltou = item removido. O cursor `alterado_desde` é sempre o maior
`alterado_em` já processado com sucesso.

## Autenticação

`x-api-key`, header `AVHUB_API_KEY` — chave **própria do MES** (MES chamando av-hub), no mesmo
`apiKeyAuth.js` que a `api-acos-vital` já usa. É a mesma chave do item L6 do
[[26-Vendas-Liberacao-Pedido]]: restrita às rotas que o MES usa (`/pedidos_liberados/*`,
`/ordens-compra/referencia`, `/unidades`, `/produtos`).

## Polling

Intervalo proposto: **5 minutos**. O gatilho real é a chegada física na doca, detectada no MES — a
latência de 5 min não atrasa o caminho crítico.

## Perguntas em aberto

1. **OC cancelada com recebimento parcial no MES:** o MES só marca, ou avisa o comprador? (O av-hub hoje
   não recebe nada de volta sobre recebimento — isso seria o fluxo 3, [[005-Status-Item-Integracao-MES]].)
2. **Aprovação do Robert:** formato do `destino` e uso do `numero_requisicao_mes` batem com o que o
   Recebimento do MES precisa?
3. Confirmar se o `api-pcp` já tem cliente HTTP para chamar o av-hub com a chave `AVHUB_API_KEY`
   (hoje ele já chama `/pedido_venda_itens`, `/vendas_planilha`, `/unidades` e `/produtos` com a chave
   genérica).

## Depois de aplicado

- av-hub (backend): criar `GET /ordens-compra/referencia` em `api-acos-vital`, lendo de `ordens_compra`,
  `ordens_compra_itens` e `ordens_compra_itens_vinculos`, e a chave `AVHUB_API_KEY` restrita.
- MES (Robert): job de polling em `api-pcp` (5 min) e a fila de Recebimento (D6/D7) usando a projeção.

## Aceite

- Uma OC aprovada aparece na próxima leitura com os itens, o tipo de material e o destino; rascunho e
  aguardando aprovação não aparecem.
- Cancelar uma OC aprovada faz ela voltar com `situacao: cancelada`.
- Mudar o destino de um item (vínculo com PV) faz a OC voltar na leitura seguinte.
- Uma OC com duas requisições do MES traz o `id_requisicao` certo em cada item.
- A resposta não tem preço, fornecedor nem condição de pagamento.

## Ver também
- [[Integracao-AvHub-MES-Especificacao-F1]]
- [[007-Ordens-Compra-Estruturada]]
- [[13-Compras-Backend-Consolidado]]
- [[14-Compras-Vinculo-Pedido-Venda]]
- [[003-Requisicao-Compra-Integracao-MES]]
- [[005-Status-Item-Integracao-MES]]
- [[26-Vendas-Liberacao-Pedido]]
- [[Indice-Contratos]]
- [[Fluxo-Compras-Completo]]
