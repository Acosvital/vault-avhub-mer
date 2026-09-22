---
tags: [contrato-api, mes, estoque, integracao-av-hub-mes]
status: proposta
criado: 2026-09-22
---

# Contrato de API 003 — Requisição de compra (MES → av-hub)

**Status:** proposta, aprovada por Nathan em 22/09/2026 a partir do rascunho consolidado em [[Integracao-AvHub-MES-Especificacao-F1]] (Fluxo 1). **Aprovação formal de Robert e Gustavo, condição de pronto da tarefa F1 no [[Cronograma-2-Meses]], ainda não registrada neste arquivo** — atualizar este frontmatter quando eles confirmarem. **Destinatário: time do MES** (expõe o endpoint) e **time do av-hub** (implementa o job de polling em `api-acos-vital`).

## Por quê

Corresponde à conversa **C1** de [[Fluxo-Compras-Completo]]: o PCP, ao classificar um item pelo [[Modelo-Destinacao-Item]], conclui que não tem estoque e precisa comprar. Hoje **não existe nenhum mecanismo** para essa requisição chegar ao comprador no av-hub — é o primeiro dos 3 fluxos que resolvem o "casamento av-hub↔MES" (DEC-2, [[MES-Arquitetura-Decisoes]]). Sem este contrato, a tarefa E1 (caixa de entrada de requisições) não tem o que exibir.

## Onde isso mora

Lado que expõe: **MES** (`api-pcp`) — é quem gera a requisição, dona do dado. Lado que consome: **av-hub** (`api-acos-vital`) — job de polling projeta localmente numa tabela própria (ver seção "Depois de aplicado").

## Contrato de request/response

### `GET /requisicoes-compra?alterado_desde=&codigo_empresa=&incluir_deletados=`

**Query params:**
- `alterado_desde` (obrigatório) — ISO 8601, cursor incremental. O av-hub salva o maior `updated_at` já processado com sucesso e reenvia esse valor na próxima chamada.
- `codigo_empresa` (opcional) — filtra por unidade; sem o filtro, retorna todas.
- `incluir_deletados` (opcional, default `false`) — quando `true`, inclui requisições canceladas/removidas (`deleted_at` preenchido), mesmo padrão já resolvido no contrato de API 001 (G-13).

**Response (200):**
```json
[
  {
    "id_requisicao": "uuid",
    "codigo_empresa": "uuid-da-unidade",
    "origem": { "id_pedido": "uuid-ou-null", "id_item_parcial": "uuid-ou-null" },
    "codigo_produto_omie": "12345678",
    "descricao_material": "Chapa xadrez 1/8 1200x3000",
    "quantidade": 500.000,
    "unidade": "KG",
    "prazo_necessario": "2026-10-15",
    "restricao_acabado": "ACABADO | NAO_ACABADO | null",
    "observacao": "texto livre do PCP, opcional",
    "status": "ABERTA | EM_COTACAO | ATENDIDA | CANCELADA",
    "ocorrido_em": "2026-10-01T14:32:00Z",
    "updated_at": "2026-10-01T14:32:00Z",
    "deleted_at": null
  }
]
```

**Regras:**
- `codigo_empresa` é obrigatório em cada item do array (implicação da DEC-1 — nunca inferir filial pela Fábrica).
- `status` é escrito **só pelo MES** — o av-hub nunca faz `PUT`/`PATCH` nesta requisição; é fluxo só de leitura.
- **Regra nova proposta por este contrato** (não fechada em nenhum outro documento do vault antes deste): o MES marca `status = ATENDIDA` ao reconhecer, via Fluxo 2 (contrato 004), que `id_requisicao_origem` de uma OC referenciada aponta para esta requisição. Precisa de confirmação explícita de Robert antes da implementação — ver pergunta aberta 1.
- Sem paginação definida neste contrato — ver pergunta aberta 2.

## Idempotência

Só leitura (`GET`), sem efeito colateral no lado que chama. O av-hub faz `UPSERT` pela chave natural `(codigo_empresa, id_requisicao)` — reler a mesma janela de `alterado_desde` duas vezes nunca duplica linha, só reescreve o mesmo valor. O cursor salvo é sempre o maior `updated_at` já visto com sucesso, nunca o horário local do job.

## Autenticação

`x-api-key`, header `MES_API_KEY` — chave própria para esta direção (av-hub chamando MES), não compartilhada com a chave que o MES eventualmente usar para chamar o av-hub (contrato 004). Resolve G-15 ([[Perguntas-em-Aberto-Consolidadas]]) do lado desta integração. **Pré-requisito: `api-pcp` precisa de um middleware de validação de `x-api-key`, que hoje não existe** — ver pergunta aberta 3.

## Polling

Intervalo proposto: **5 minutos**. Fluxo não é urgente — o comprador trabalha em lote, não item a item.

## Perguntas em aberto

1. **Confirmar com Robert** a regra de `status = ATENDIDA` proposta acima — é a única regra de negócio nova introduzida por este contrato, ainda sem validação formal.
2. **Paginação não definida.** Mesmo padrão do pipeline ELT (`nPagina`/`nRegPorPagina`) deveria se aplicar, mas não foi especificado — confirmar convenção com Gustavo antes de implementar.
3. **`api-pcp` tem middleware de `x-api-key`?** Se não tiver, precisa ser criado antes deste contrato poder ser aplicado — dono provável: Robert.

## Depois de aplicado

- MES: criar o endpoint `GET /requisicoes-compra` em `api-pcp`, com o middleware de `x-api-key` (se ainda não existir).
- av-hub: criar job de polling em `api-acos-vital` (intervalo 5 min), tabela local de projeção (`core_vendas_faturamento.requisicoes_compra_mes` ou nome equivalente a definir em contrato SQL próprio) e a tela da tarefa E1 (caixa de entrada de requisições) consumindo essa tabela.

## Ver também
- [[Integracao-AvHub-MES-Especificacao-F1]]
- [[004-Referencia-OC-Integracao-MES]]
- [[005-Status-Item-Integracao-MES]]
- [[Indice-Contratos]]
- [[Fluxo-Compras-Completo]]
