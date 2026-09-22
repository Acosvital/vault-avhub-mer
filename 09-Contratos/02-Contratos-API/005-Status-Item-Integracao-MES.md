---
tags: [contrato-api, mes, estoque, integracao-av-hub-mes, rastreabilidade]
status: proposta
criado: 2026-09-22
---

# Contrato de API 005 — Status por item (MES → av-hub)

**Status:** proposta, aprovada por Nathan em 22/09/2026 a partir do rascunho consolidado em [[Integracao-AvHub-MES-Especificacao-F1]] (Fluxo 3). **Aprovação formal de Robert e Gustavo, condição de pronto da tarefa F1 no [[Cronograma-2-Meses]], ainda não registrada neste arquivo.** **Destinatário: time do MES** (expõe o endpoint) e **time do av-hub** (implementa o job de polling em `api-acos-vital`). Endpoint já nomeado no [[Cronograma-2-Meses]] (tarefa F3): `/itens/status?alterado_desde=`.

## Por quê

Corresponde à conversa **C19** de [[Fluxo-Compras-Completo]] e ao ponto de integração citado em [[AV-Hub-Portal-Vendedor-Plano]] (etapa por item, hoje pendente). Alimenta o Portal do Vendedor (tarefa E3) e a Carteira do PCP — sem este contrato, o vendedor não vê em que etapa está cada item do pedido.

## Onde isso mora

Lado que expõe: **MES** (`api-pcp`) — dono do estado de produção/recebimento/qualidade de cada item. Lado que consome: **av-hub** (`api-acos-vital`) — job de polling projeta localmente para o Portal do Vendedor.

## Contrato de request/response

### `GET /itens/status?alterado_desde=&codigo_empresa=&incluir_deletados=`

**Query params:** mesmo padrão dos contratos 003/004.

**Response (200):**
```json
[
  {
    "id_item_parcial": "uuid",
    "codigo_empresa": "uuid-da-unidade",
    "id_pedido_venda_origem": "uuid-ou-null",
    "codigo_produto_omie": "12345678",
    "etapa": "compras.requisicao | compras.fechamento | recebimento.conferencia | recebimento.pesagem | qualidade.quarentena | qualidade.inspecao | fabrica.espera | fabrica.execucao | estoque.reservado | qualidade.reprovado | pcp.retorno",
    "quantidade_na_etapa": 120.000,
    "ocorrido_em": "2026-11-05T16:10:00Z",
    "updated_at": "2026-11-05T16:10:00Z",
    "deleted_at": null
  }
]
```

**Regras:**
- `codigo_empresa` obrigatório (DEC-1).
- `etapa` usa o vocabulário comum provisório definido em [[Rastreabilidade-e-SLA-de-Eventos]] — **provisório**: aquele documento já sinaliza revisão pendente ([[Revisao-dos-Estados-e-Status]]) sobre `vendas.emitido` vs. `pcp.aceite` e sobre etapas de fábrica nascerem do roteiro, não fixas. Este contrato herda essa instabilidade — não travar o enum no código sem revisar antes de implementar.
- Um item pode passar pela mesma etapa mais de uma vez (ex.: `pcp.retorno` após reprovação de qualidade) — a chave de upsert **não pode** ser só `id_item_parcial` (ver Idempotência).

## Idempotência

Chave de upsert no av-hub: `(codigo_empresa, id_item_parcial, etapa, ocorrido_em)` — precisa incluir `ocorrido_em` para não sobrescrever o histórico de transições com a leitura mais recente quando o mesmo item repete etapa. O av-hub deriva a **etapa atual** exibida ao vendedor a partir do maior `ocorrido_em` por item, mas mantém todas as linhas na tabela local (log, não apenas snapshot).

## Autenticação

`x-api-key`, header `MES_API_KEY` — mesma chave da direção av-hub→MES usada no contrato 003 (av-hub é quem chama o MES nos dois casos).

## Polling

Intervalo proposto: **1 a 2 minutos** — é o fluxo com maior valor de frescor; o vendedor olha a etapa do pedido quase em tempo real.

## Relação com a proposta de rastreabilidade completa

[[Rastreabilidade-e-SLA-de-Eventos]] propõe substituir este endpoint por um feed de eventos mais genérico (`origem`, `ator`, `autorizado_por`, `passou_para`, `setor` etc.), cobrindo Compras, Comercial, Recebimento, Qualidade e Estoque — não só Fabricação/Recebimento. **Este contrato não implementa essa versão completa**, que foi conscientemente movida para a S5 (19/11–18/12, ver [[Cronograma-2-Meses]] seção 3.1) para não estourar a folga de 9% do plano de 2 meses. O formato acima nasce compatível por construção: `etapa`/`ocorrido_em`/a chave composta podem crescer para o envelope completo por adição de coluna, sem quebrar o que for implementado agora nem mudar a forma de paginação/cursor.

## Perguntas em aberto

1. Confirmar o vocabulário final de `etapa` com Robert antes de travar o enum — depende da revisão pendente em [[Revisao-dos-Estados-e-Status]].
2. Regra de agregação quando o item é dividido em parciais (`ItemParcial` com quantidade parcial em etapas diferentes simultaneamente) — sinalizada como pendente em [[Revisao-dos-Estados-e-Status]], impacta como o av-hub monta "a etapa do pedido" a partir de múltiplas linhas de item.
3. Paginação não definida (mesma pendência dos contratos 003/004).

## Depois de aplicado

- MES: criar o endpoint `GET /itens/status` em `api-pcp`.
- av-hub: criar job de polling em `api-acos-vital` (intervalo 1-2 min), tabela local de projeção (`core_vendas_faturamento.itens_pedido_status` ou nome equivalente a definir em contrato SQL próprio) e a tela da tarefa E3 (status por item no Portal do Vendedor) consumindo essa tabela.

## Ver também
- [[Integracao-AvHub-MES-Especificacao-F1]]
- [[Rastreabilidade-e-SLA-de-Eventos]]
- [[Revisao-dos-Estados-e-Status]]
- [[003-Requisicao-Compra-Integracao-MES]]
- [[004-Referencia-OC-Integracao-MES]]
- [[Indice-Contratos]]
- [[AV-Hub-Portal-Vendedor-Plano]]
