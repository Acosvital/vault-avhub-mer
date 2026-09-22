---
tags: [contrato-api, mes, estoque, integracao-av-hub-mes]
status: proposta
criado: 2026-09-22
---

# Contrato de API 004 — Referência da Ordem de Compra (av-hub → MES)

**Status:** proposta, aprovada por Nathan em 22/09/2026 a partir do rascunho consolidado em [[Integracao-AvHub-MES-Especificacao-F1]] (Fluxo 2). **Aprovação formal de Robert e Gustavo, condição de pronto da tarefa F1 no [[Cronograma-2-Meses]], ainda não registrada neste arquivo.** **Destinatário: time do av-hub** (expõe o endpoint) e **time do MES** (implementa o job de polling em `api-pcp`).

## Por quê

Corresponde à conversa **C7** de [[Fluxo-Compras-Completo]]: dispara só quando o material chega fisicamente na doca — não antes, e não no momento em que a OC é fechada. Sem este contrato, o Recebimento (tarefas D6/D7) não tem contra o que conferir uma compra de item **não acabado** (item acabado confere contra o Pedido de Venda, que já é lido de `core.produtos`/`core.parceiros`; item não acabado confere contra a OC, que só existe no av-hub).

## Onde isso mora

Lado que expõe: **av-hub** (`api-acos-vital`) — dono da decisão de compra (fornecedor, preço, condição), criada pelo comprador na tarefa E2. Lado que consome: **MES** (`api-pcp`) — job de polling projeta localmente para o Recebimento.

**Não trafega preço, fornecedor, condição de pagamento nem `codigo_categoria`/`codigo_conta_corrente`** — só o necessário para a conferência quantitativa, mesma filosofia de "colunas protegidas" já usada no [[Omie-ELT-Pipeline]].

## Contrato de request/response

### `GET /ordens-compra/referencia?alterado_desde=&codigo_empresa=&incluir_deletados=`

**Query params:** mesmo padrão do contrato 003 (`alterado_desde` obrigatório, `codigo_empresa` opcional, `incluir_deletados` opcional).

**Response (200):**
```json
[
  {
    "id_ordem_compra": "uuid",
    "codigo_empresa": "uuid-da-unidade",
    "numero_oc": "OC-2026-000123",
    "id_requisicao_origem": "uuid-ou-null",
    "itens": [
      {
        "id_item_oc": "uuid",
        "codigo_produto_omie": "12345678",
        "quantidade_esperada": 500.000,
        "unidade": "KG",
        "flag_acabado": "ACABADO | NAO_ACABADO"
      }
    ],
    "previsao_chegada": "2026-10-20",
    "updated_at": "2026-10-18T09:00:00Z",
    "deleted_at": null
  }
]
```

**Regras:**
- `codigo_empresa` obrigatório (DEC-1).
- `id_requisicao_origem` referencia a requisição do contrato 003, quando a OC nasceu de uma requisição do PCP (pode ser nulo se o comprador criou a OC por outro motivo, ex.: reposição preventiva sem requisição formal).
- `flag_acabado`/`NAO_ACABADO` é o dado que decide contra o que o Recebimento confere (C9 de [[Fluxo-Compras-Completo]]) — nunca pode vir vazio.

## Idempotência

Mesmo mecanismo do contrato 003: `UPSERT` pela chave natural `(codigo_empresa, id_ordem_compra)` no lado do MES; itens por `(id_ordem_compra, id_item_oc)`. Cursor de `alterado_desde` é sempre o maior `updated_at` já processado com sucesso.

## Autenticação

`x-api-key`, header `AVHUB_API_KEY` — chave própria desta direção (MES chamando av-hub), reaproveitando o mesmo `apiKeyAuth.js` que `api-acos-vital` já usa em produção (lista de chaves no `.env`).

## Polling

Intervalo proposto: **5 minutos**. O gatilho real é a chegada física na doca, detectada pelo Recebimento no MES — a latência de 5 min não atrasa o caminho crítico.

## Pré-requisito bloqueante

Este contrato pressupõe uma tabela própria no av-hub para a OC estruturada (fechada pelo comprador na tarefa E2), que **ainda não existe** — ver contrato SQL [[007-Ordens-Compra-Estruturada]]. Não confundir com o contrato SQL 004 ([[004-Pedidos-Compras]]), que é um espelho read-only do histórico de pedidos de compra do **Omie** — propósito diferente, mesma numeração por coincidência (um é contrato SQL, este é contrato de API, numerações independentes por pasta).

## Perguntas em aberto

1. Nome e schema definitivos da tabela de OC estruturada — proposta em [[007-Ordens-Compra-Estruturada]], ainda sem aprovação do Gustavo.
2. Paginação não definida (mesma pendência do contrato 003).
3. Confirmar se `api-pcp` precisa de outro middleware para *chamar* o av-hub (cliente HTTP com a chave `AVHUB_API_KEY`) ou se reaproveita alguma infraestrutura de chamada externa que já exista no MES.

## Depois de aplicado

- av-hub: criar o endpoint `GET /ordens-compra/referencia` em `api-acos-vital`, lendo da tabela do contrato SQL [[007-Ordens-Compra-Estruturada]].
- MES: criar job de polling em `api-pcp` (intervalo 5 min) e a tela/fila de Recebimento (D6/D7) consumindo essa projeção local.

## Ver também
- [[Integracao-AvHub-MES-Especificacao-F1]]
- [[007-Ordens-Compra-Estruturada]]
- [[003-Requisicao-Compra-Integracao-MES]]
- [[005-Status-Item-Integracao-MES]]
- [[Indice-Contratos]]
- [[Fluxo-Compras-Completo]]
