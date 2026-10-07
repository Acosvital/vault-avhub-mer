---
tags: [contrato-api, mes, estoque, integracao-av-hub-mes]
status: substituida
criado: 2026-09-22
atualizado: 2026-10-07
---

# Contrato de API 003 — Requisição de compra (MES → av-hub)

> **Atualização de 07/10/2026 — conferido no código:** a rota `GET /requisicoes-compra` **existe no MES** no formato do hub (`901f9bb`, `5c1316f`, `develop` do `api-pcp`) e está **substituída pelo 34**: nenhum job da `api-acos-vital` a consome (e não será feito). O MES chama o PUT do 34 desde `e7ce2c9` (02/10). Status `substituida` confere.

> **✅ ATENDIDO PELO CONTRATO 34 (06/10/2026).** O objetivo deste contrato (a requisição do MES chegar ao av-hub) foi entregue pelo [[34-Requisicoes-MES-Empurra-para-o-Hub]], em que o MES **empurra** a requisição (`PUT /compras/requisicoes/origem/{id_origem}`) em vez de o av-hub buscar (DEC-2 revista em 01/10/2026). O job de polling descrito abaixo **não será feito**; o texto fica como histórico. Os contratos da volta, [[004-Referencia-OC-Integracao-MES]] e [[005-Status-Item-Integracao-MES]], continuam abertos.

> **Revisado em 01/10/2026:** o Nathan decidiu que o **MES empurra** a requisição para o av-hub (e não o hub busca no MES, DEC-2). Rota, regras e segurança em [[34-Requisicoes-MES-Empurra-para-o-Hub]]. Onde este contrato fala em "job de polling" do hub, vale o 34.

**Status:** proposta. Aprovada por Nathan em 22/09/2026 a partir do rascunho consolidado em
[[Integracao-AvHub-MES-Especificacao-F1]] (Fluxo 1) e **aprovada pelo Robert em 30/09/2026, com ajustes de
formato** (abaixo). **Falta:** o Nathan fechar as perguntas 1 a 3 e a aprovação do Gustavo (condição de
pronto da F1 no [[Cronograma-2-Meses]]).
**Destinatários:** MES (`api-pcp`, Robert: expõe a rota, **já feita**) e av-hub (job de leitura periódica,
**ainda não existe**; ver pergunta 3).

> **O que mudou na revisão de 30/09/2026** (retorno do Robert, conferido no código: `api-pcp` commit
> `901f9bb`, já na `develop`; `api-acos-vital` `develop` em `36940ed`):
> - **a rota existe no MES**: `GET /requisicoes-compra`, com chave própria e paginação por `limit`;
> - **uma linha por item da requisição**, não por requisição: no MES uma requisição pode ter mais de um
>   material; no av-hub uma requisição é um material só, então cada item do MES vira uma requisição no av-hub;
> - a chave de idempotência é o **id do item** (`id_requisicao_item`), que o av-hub grava em `id_origem`;
> - o status do MES mudou de vocabulário e é **só informação**. A regra "o MES marca `ATENDIDA` ao
>   reconhecer a OC" (antiga pergunta 1) saiu: o status da fila do comprador é o do av-hub;
> - paginação e chave de acesso (antigas perguntas 2 e 3) resolvidas.

## Por quê

Corresponde à conversa **C1** de [[Fluxo-Compras-Completo]]: o PCP, ao classificar um item pelo [[Modelo-Destinacao-Item]], conclui que não tem estoque e precisa comprar. **Gatilho decidido em 24/09/2026** ([[Encaixe-Estoque-Revenda-no-PCP]]): a requisição nasce da **entrada do parcial no setor Compras** do roteiro da fábrica Revenda, então `origem.id_item_parcial` vem sempre preenchido na requisição reativa (`null` só na preventiva, Fase D). É o primeiro dos fluxos que resolvem o "casamento av-hub↔MES" (DEC-2, [[MES-Arquitetura-Decisoes]]). Sem este contrato, a caixa de entrada de requisições (E1) só tem o que o comprador digitar à mão.

## Onde isso mora

Lado que expõe: **MES** (`api-pcp`, `src/integracao-avhub/`), dono do dado. Lado que consome: **av-hub**, com
um job de leitura periódica que grava em `core_vendas_faturamento.requisicoes_compra`
([[008-Requisicoes-Compra]]) pelo `POST /compras/requisicoes`.

## A rota (como está no MES)

### `GET /requisicoes-compra?alterado_desde=&codigo_empresa=&incluir_deletados=&limit=`

| Parâmetro | Regra |
|---|---|
| `alterado_desde` | **obrigatório**, ISO 8601. Devolve as requisições com `updated_at` **maior ou igual** a ele, em ordem crescente de `updated_at` (e `id` para desempate) |
| `codigo_empresa` | opcional (uuid da unidade). Sem ele, todas as unidades |
| `incluir_deletados` | opcional, padrão `false`. **Sem ele a requisição cancelada não vem**: o job precisa mandar `true` para saber do cancelamento |
| `limit` | padrão 500, máximo 1000. Não há `page`: o próximo cursor é o `updated_at` da última linha recebida |

**Response (200)**, uma linha por **item** da requisição:
```json
[
  {
    "id_requisicao": "uuid",
    "id_requisicao_item": "uuid",
    "codigo": "RC-20261001-0007",
    "codigo_empresa": "uuid-da-unidade",
    "origem": {
      "id_pedido": "uuid-ou-null",
      "id_item_parcial": "uuid-ou-null",
      "pedido_venda": "25970",
      "ordem_producao": "OP-000123"
    },
    "codigo_produto_omie": "12345678",
    "codigo_produto": "CHX-18-1200",
    "descricao_material": "Chapa xadrez 1/8 1200x3000",
    "quantidade": 500.000,
    "quantidade_recebida": 0,
    "unidade": "KG",
    "prazo_necessario": "2026-10-15",
    "tipo_item": "PRODUTO_FINAL | MATERIA_PRIMA",
    "restricao_acabado": "ACABADO | NAO_ACABADO",
    "observacao": "texto livre do PCP, opcional",
    "status": "ABERTA | EM_COMPRA | RECEBIDA_PARCIAL | RECEBIDA | CANCELADA",
    "pedido_compra": "46618",
    "fornecedor": "texto",
    "previsao_entrega": "2026-10-20",
    "ocorrido_em": "2026-10-01T14:32:00Z",
    "updated_at": "2026-10-01T14:32:00Z",
    "deleted_at": null
  }
]
```

**Regras:**
- `codigo_empresa` vem em toda linha (DEC-1: nunca inferir a filial pela Fábrica). Sai da unidade do pedido.
- `codigo` é o número da requisição no MES (`RC-AAAAMMDD-NNNN`) e **se repete** nos itens da mesma
  requisição. Vai para `numero_requisicao_mes` no av-hub (o índice dessa coluna não é único, então repetir
  não dá erro).
- `prazo_necessario` é o prazo de entrega do pedido e **hoje pode vir `null`** (pedido sem prazo). No av-hub
  o prazo é obrigatório: ver pergunta 2.
- `status` é escrito só pelo MES e é **informação**. O status da fila do comprador (`aberta`, `em_cotacao`,
  `atendida`, `cancelada`) continua sendo o do av-hub; `atendida` só sai da emissão da OC.
- Requisição cancelada no MES vem com `status = CANCELADA` e `deleted_at` preenchido.
- `pedido_compra`, `fornecedor` e `previsao_entrega` são o registro manual da compra que o MES usa enquanto
  o [[004-Referencia-OC-Integracao-MES]] não existe. O av-hub não lê esses campos.

## De-para com o av-hub

Colunas de `requisicoes_compra` que o job grava, e de onde vêm:

| av-hub | MES hoje | Observação |
|---|---|---|
| `id_origem` | `id_requisicao_item` | chave de idempotência do job |
| `numero_requisicao_mes` (máx. 30) | `codigo` | o `numero_requisicao` do av-hub é sempre do contador (`REQ-000001`) |
| `codigo_empresa` | `codigo_empresa` | |
| `material` (máx. 60, obrigatório) | código do produto | |
| `descricao` | `descricao_material` | |
| `quantidade` | `quantidade` | |
| `unidade_medida` (máx. 10, obrigatório) | `unidade` | |
| `prazo_necessidade` (obrigatório) | `prazo_necessario` | pode vir vazio: pergunta 2 |
| `acabado_sugerido` (boolean) | `restricao_acabado` | `ACABADO` = `true`. No MES sai do `tipo_item`: `PRODUTO_FINAL` = acabado, `MATERIA_PRIMA` = não acabado |
| `solicitante` (máx. 100) | não vem hoje | quem requisitou no MES |
| `observacao` | `observacao` | |

**Proposta do Robert (30/09):** o MES passa a mandar os campos já com os nomes do av-hub
(`unidade_medida`, `prazo_necessidade`, `acabado_sugerido`, `material`, `descricao`, `solicitante`), para o
job não precisar de de-para. Se o av-hub preferir fazer o de-para no job, o MES fica como está. Pergunta 1.

## Idempotência

O job decide entre criar e atualizar pelo `id_origem`. Reler a mesma janela não pode duplicar. O cursor
salvo é sempre o maior `updated_at` já processado com sucesso, nunca o horário local do job.

**Lacuna no av-hub (conferida no código em 30/09):** o `POST /compras/requisicoes` aceita `id_origem` e
recusa um repetido ("o job de polling deve atualizar a existente em vez de inserir"), mas **não existe rota
para atualizar** quantidade, prazo ou descrição de uma requisição já projetada: o `PATCH` só troca o
`status`, e o `GET` não filtra por `id_origem`. Pergunta 4.

## Autenticação

`x-api-key` com a chave `MES_API_KEY`, própria desta direção (av-hub chamando o MES). Já está no `api-pcp`
(`avhub-api-key.guard.ts`): sem a variável configurada, a rota fica bloqueada. É separada da chave que o
MES usa para chamar o av-hub (item L6 do [[26-Vendas-Liberacao-Pedido]]).

## Polling

Intervalo proposto: **5 minutos**. Fluxo não é urgente: o comprador trabalha em lote, não item a item.

## Perguntas em aberto

1. **Nomes dos campos:** o MES muda para os nomes do av-hub (proposta do Robert) ou o job faz o de-para?
   (Nathan)
2. **Pedido sem prazo:** qual regra preenche o `prazo_necessidade`? Sugestões do Robert: data da requisição
   + N dias, ou o MES recusar a requisição até o pedido ter prazo. (Nathan)
3. **Onde fica o job e quem faz:** o Robert não encontrou o job na API, e não há mesmo (conferido). Pelo
   [[Cronograma-2-Meses]] é a tarefa **F2** (Gustavo, 19/10 a 30/10), e este contrato previa o job dentro da
   `api-acos-vital`; nada disso foi confirmado com o Gustavo. (Nathan + Gustavo)
4. **Atualização da requisição já projetada** (lacuna acima): rota de upsert por `id_origem` na API, ou o
   job grava direto no banco? Inclui o cancelamento de uma requisição que já está `atendida` no av-hub.
   (quem fizer o job)
5. **Borda do cursor:** a comparação é `>=` e não há `page`. Se mais linhas que o `limit` tiverem o mesmo
   `updated_at`, o job recebe sempre as mesmas. Risco baixo (precisa de mais de 500 no mesmo instante);
   registrar para quem fizer o job. (Robert)

Fechadas em 30/09: regra do `ATENDIDA` (saiu), paginação (`limit`), chave de acesso no `api-pcp` (existe).

## Depois de aplicado

- MES: ✅ rota criada. Falta o que sair das perguntas 1 e 2 (nomes e prazo sempre preenchido).
- av-hub: o job (5 min) gravando em `requisicoes_compra`; a tela da E1 já lê dessa tabela.

## Ver também
- [[Integracao-AvHub-MES-Especificacao-F1]]
- [[008-Requisicoes-Compra]]
- [[004-Referencia-OC-Integracao-MES]]
- [[005-Status-Item-Integracao-MES]]
- [[Indice-Contratos]]
- [[Fluxo-Compras-Completo]]
