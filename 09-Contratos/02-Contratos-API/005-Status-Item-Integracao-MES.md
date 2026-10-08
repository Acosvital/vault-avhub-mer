---
tags: [contrato-api, mes, estoque, integracao-av-hub-mes, rastreabilidade]
status: proposta
criado: 2026-09-22
atualizado: 2026-10-07
---

# Contrato de API 005 — Status por item (MES → av-hub)

> Status: decidido | no código | em produção (verificado em 07/10/2026). Fonte: [[Registro-de-Decisoes-2026-10-07]] (#42 e #43).
> - **Aceite das 3 diferenças** (foto atual em vez de log; `pedido_venda` + `ordem_producao`; etapas a mais e a menos): 🔴 Nathan. Recomendação: aceitar (o Robert já aprovou em 30/09).
> - **Consumidor no hub:** 🟡 (Gustavo) roda na `api-acos-vital` (F2, 19 a 30/10), com tabela local do status por item.

> **Linha do tempo (08/10/2026):** criado em 22/09/2026 como rascunho da F1 e aprovado pelo Nathan no mesmo dia; revisões de 29/09 e 30/09 (Robert). Plano e pendências em [[Integracao-AvHub-MES-Volta-Plano]].
> **Desenho do lado do hub (08/10):** tabela em [[010-Itens-Pedido-Status]] e job + rota em [[006-Status-por-Item-Leitura-no-Hub]]; tela 1.2 em branch do `av-hub` (ver o plano).

> **Atualização de 07/10/2026 — conferido no código:** do lado do **MES** a rota `GET /itens/status` **existe** (`901f9bb`, na `develop` do `api-pcp`; `etapa` derivada do tipo do setor, foto atual da parcial). Do lado do **hub** **não existe nada**: nem job de leitura, nem rota, nem model/tabela de status por item na `api-acos-vital` (`main` = `develop`, `a6ab058`/`fdafb35`). Falta o **consumidor no hub** (job + tabela local + tela do Portal do Vendedor, tarefa E3), o aceite do Nathan às diferenças e o Gustavo. Status: `proposta`. Observação: a `main` do `api-pcp` parou em 28/08, a rota só está na `develop` do MES; se essa `develop` roda em produção/homologação não foi verificado. Ver [[Indice-Contratos]] (Conferência de 07/10/2026).

> **01/10/2026:** a requisição (ida, contrato 003) passou a ser empurrada pelo MES, ver [[34-Requisicoes-MES-Empurra-para-o-Hub]]. Este contrato (volta) continua como está e ainda não foi implementado.

**Status:** proposta. Aprovada por Nathan em 22/09/2026 a partir do rascunho consolidado em
[[Integracao-AvHub-MES-Especificacao-F1]] (Fluxo 3) e **aprovada pelo Robert em 30/09/2026, com diferenças**
(abaixo). **Falta:** o Nathan aceitar as diferenças e a aprovação do Gustavo (condição de pronto da F1 no
[[Cronograma-2-Meses]]).
**Destinatários:** MES (`api-pcp`, Robert: expõe a rota, **já feita**, adiantando a tarefa F3) e av-hub (job
de leitura periódica, ainda não existe).

> **O que mudou na revisão de 30/09/2026** (retorno do Robert, conferido no código: `api-pcp` commit
> `901f9bb`, já na `develop`):
> - **a rota existe no MES**: `GET /itens/status`, com a mesma chave e a mesma paginação do
>   [[003-Requisicao-Compra-Integracao-MES]];
> - a resposta é a **foto atual** de cada parcial alterada desde o cursor, não um log de eventos: se a
>   parcial passar por duas etapas entre duas leituras, o av-hub só vê a última;
> - `pedido_venda` + `ordem_producao` no lugar de `id_pedido_venda_origem` (o MES não tem o uuid do pedido
>   do av-hub);
> - etapas que o contrato não previa: `estoque.atendimento`, `expedicao.embalagem`, `expedicao.concluido`;
>   e três do contrato que o MES não manda: `recebimento.pesagem`, `estoque.reservado`, `pcp.retorno`;
> - paginação (antiga pergunta 3) resolvida.

## Por quê

Corresponde à conversa **C19** de [[Fluxo-Compras-Completo]] e ao ponto de integração citado em [[AV-Hub-Portal-Vendedor-Plano]] (etapa por item, hoje pendente). Alimenta o Portal do Vendedor (tarefa E3) e a Carteira do PCP — sem este contrato, o vendedor não vê em que etapa está cada item do pedido.

## Onde isso mora

Lado que expõe: **MES** (`api-pcp`, `src/integracao-avhub/`), dono do estado de produção, recebimento e
qualidade de cada item. Lado que consome: **av-hub**, com um job de leitura periódica que grava uma tabela
local para o Portal do Vendedor.

## A rota (como está no MES)

### `GET /itens/status?alterado_desde=&codigo_empresa=&incluir_deletados=&limit=`

Mesmos parâmetros do contrato 003: `alterado_desde` obrigatório (`updated_at` maior ou igual, ordem
crescente), `limit` padrão 500 e máximo 1000, sem `page`. Parcial cancelada só vem com
`incluir_deletados=true`.

**Response (200)**, uma linha por parcial (`ItemParcial`):
```json
[
  {
    "id_item_parcial": "uuid",
    "codigo_empresa": "uuid-da-unidade",
    "pedido_venda": "25970",
    "ordem_producao": "OP-000123",
    "codigo_produto_omie": "12345678",
    "codigo_produto": "FLG-CEGO-6-150",
    "etapa": "compras.requisicao | compras.fechamento | recebimento.conferencia | qualidade.quarentena | qualidade.inspecao | qualidade.reprovado | estoque.atendimento | fabrica.espera | fabrica.execucao | expedicao.embalagem | expedicao.concluido",
    "setor": { "codigo": "texto", "nome": "texto", "tipo": "PRODUTIVO | ESTOQUE | ..." },
    "status": "status da parcial no MES",
    "quantidade_na_etapa": 120.000,
    "atendido_pelo_estoque": false,
    "ocorrido_em": "2026-11-05T16:10:00Z",
    "updated_at": "2026-11-05T16:10:00Z",
    "deleted_at": null
  }
]
```

**Regras:**
- `codigo_empresa` obrigatório (DEC-1).
- O pedido é identificado por `codigo_empresa` + `pedido_venda` (o número do pedido de venda, o mesmo de
  `/pedidos_liberados`); `ordem_producao` é o número da OP no MES.
- `etapa` sai do **tipo do setor** em que a parcial está, mais o status dela. Vocabulário ainda
  **provisório** ([[Rastreabilidade-e-SLA-de-Eventos]], [[Revisao-dos-Estados-e-Status]]): não travar o enum
  no código do av-hub. `setor` e `status` vêm junto, crus, justamente para o av-hub não depender do enum.
- `ocorrido_em` é o `updated_at` da parcial: a hora da última mudança, não a hora de entrada na etapa.
- Um item pode passar pela mesma etapa mais de uma vez (reprovação e retorno), então a chave de gravação
  no av-hub não pode ser só `id_item_parcial` (ver Idempotência).

## Idempotência

Chave de gravação no av-hub: `(codigo_empresa, id_item_parcial, etapa, ocorrido_em)`. O av-hub mostra ao
vendedor a etapa de maior `ocorrido_em` por parcial e mantém as linhas anteriores (histórico do que ele
leu). Como o MES manda a foto, esse histórico tem a precisão do intervalo de leitura.

## Autenticação

`x-api-key` com a chave `MES_API_KEY`, a mesma do contrato 003 (av-hub chamando o MES nos dois casos).

## Polling

Intervalo proposto: **1 a 2 minutos** — é o fluxo com maior valor de frescor; o vendedor olha a etapa do pedido quase em tempo real.

## Relação com a proposta de rastreabilidade completa

[[Rastreabilidade-e-SLA-de-Eventos]] propõe substituir este endpoint por um feed de eventos mais genérico (`origem`, `ator`, `autorizado_por`, `passou_para`, `setor` etc.), cobrindo Compras, Comercial, Recebimento, Qualidade e Estoque — não só Fabricação/Recebimento. **Este contrato não implementa essa versão completa**, que foi conscientemente movida para a S5 (19/11–18/12, ver [[Cronograma-2-Meses]] seção 3.1) para não estourar a folga de 9% do plano de 2 meses. O formato acima nasce compatível por construção: `etapa`/`ocorrido_em`/a chave composta podem crescer para o envelope completo por adição de coluna, sem quebrar o que for implementado agora nem mudar a forma de paginação/cursor.

## Perguntas em aberto

1. **Aceite das diferenças** (foto em vez de log, `pedido_venda` + `ordem_producao`, etapas a mais e a
   menos). O Robert pediu o ok para registrar a aprovação dele na F1. (Nathan)
2. Vocabulário final de `etapa`: depende da revisão em [[Revisao-dos-Estados-e-Status]].
3. Como o av-hub monta "a etapa do pedido" quando o item está dividido em parciais em etapas diferentes
   (pendente em [[Revisao-dos-Estados-e-Status]]).
4. Onde fica o job de leitura e quem faz: mesma pergunta 3 do contrato 003.

Fechada em 30/09: paginação (`limit`, cursor pelo `updated_at` da última linha).

## Depois de aplicado

- MES: ✅ rota criada.
- av-hub: job de leitura (1 a 2 min), tabela local (`core_vendas_faturamento.itens_pedido_status` ou nome a
  definir em contrato SQL próprio) e a tela da tarefa E3 (status por item no Portal do Vendedor).

## Ver também
- [[Integracao-AvHub-MES-Especificacao-F1]]
- [[Rastreabilidade-e-SLA-de-Eventos]]
- [[Revisao-dos-Estados-e-Status]]
- [[003-Requisicao-Compra-Integracao-MES]]
- [[004-Referencia-OC-Integracao-MES]]
- [[Indice-Contratos]]
- [[AV-Hub-Portal-Vendedor-Plano]]
