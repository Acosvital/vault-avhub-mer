---
tags: [contrato-api, mes, integracao-av-hub-mes, rastreabilidade, portal-vendedor]
status: proposta
criado: 2026-10-08
atualizado: 2026-10-08
---

# Contrato de API 006 — Leitura do status por item no hub (job + rota)

> Status: **proposta (08/10/2026), para o Gustavo (`api-acos-vital`).** Complementa o [[005-Status-Item-Integracao-MES]] (que descreve a rota do MES) com as duas peças que faltam **no hub**: o **job que lê o MES** e a **rota que o av-hub chama** para a tela 1.2. Depende do [[010-Itens-Pedido-Status]] (tabela). Nada disto existe.

## Peça 1 — job de leitura do MES (api-acos-vital)

- Chama `GET {MES_API_URL}/itens/status?alterado_desde=&codigo_empresa=&limit=1000` a cada **1 a 2 minutos**, **uma unidade por vez** (`core.unidades` ativas). Header `x-api-key: {MES_API_KEY}`.
- **Cursor** em `itens_pedido_status_cursor`: o maior `updated_at` já gravado com sucesso por unidade. Primeira leitura da unidade: `alterado_desde` = data de corte decidida pelo Nathan (sugestão: 30 dias).
- **Paginação:** enquanto a resposta vier com `limit` linhas, repetir com `alterado_desde` = `updated_at` da última linha (o MES ordena por `updated_at` crescente; `>=`, então tratar duplicata pela chave única). Parar quando vier menos que `limit`.
- **Gravação:** `INSERT ... ON CONFLICT (codigo_empresa, id_item_parcial, etapa, ocorrido_em) DO NOTHING`, tudo da página numa transação, depois avança o cursor. Falha do MES (rede, 5xx, 401): loga, **não avança o cursor** e tenta na próxima rodada. 401 repetido deve alertar (chave errada).
- **Parcial cancelada:** o job chama também com `incluir_deletados=true` uma vez por rodada longa (sugestão: a cada 15 min) para registrar `mes_deleted_at`.
- **Variáveis:** `MES_API_URL`, `MES_API_KEY`, `MES_STATUS_INTERVALO_SEG` (padrão 90), `MES_STATUS_CORTE_INICIAL_DIAS` (padrão 30). **Sem chave de ligar/desligar** (decisão de 07/10, item 9 do [[Registro-de-Decisoes-2026-10-07]]); sem `MES_API_URL` o job não sobe e avisa no log.
- Onde roda: mesmo processo da API ou worker próprio (decisão do Gustavo; a pipeline já usa worker próprio).

## Peça 2 — rota de leitura para o av-hub

### `GET /itens_pedido_status?codigo_empresa=&pedido_venda=&historico=`

| Parâmetro | Regra |
|---|---|
| `codigo_empresa` | obrigatório (uuid da unidade) |
| `pedido_venda` | obrigatório (número do pedido de venda) |
| `historico` | opcional, `true` devolve também as linhas anteriores de cada parcial; padrão `false` (só a atual) |

**Response (200)**, ordenada por `codigo_produto`, `id_item_parcial`, `ocorrido_em` decrescente:
```json
{
  "pedido_venda": "25970",
  "codigo_empresa": "uuid",
  "lido_em": "2026-10-08T15:20:11Z",
  "itens": [
    {
      "id_item_parcial": "uuid",
      "codigo_produto_omie": "9764577293",
      "codigo_produto": "FLG-CEGO-6-150",
      "ordem_producao": "OP-000123",
      "etapa": "fabrica.execucao",
      "setor": { "codigo": "FURACAO", "nome": "Furação", "tipo": "PRODUTIVO" },
      "status": "EM_ANDAMENTO",
      "quantidade_na_etapa": 4.0,
      "atendido_pelo_estoque": false,
      "ocorrido_em": "2026-10-08T14:02:00Z"
    }
  ]
}
```

- `lido_em` = quando o job gravou a linha mais recente do pedido; o BFF mostra "atualizado há N min" e avisa se passou de 10 minutos (o job parou).
- Pedido sem nenhuma linha: **200 com `itens: []`** (o pedido ainda não chegou ao MES). Não é 404.
- **Escopo de segurança (obrigatório):** a rota deve respeitar o escopo do vendedor como as demais rotas de vendas (`ESCOPO_VENDEDORES_EXIGIR` com token de usuário): vendedor só vê pedidos dele ou da equipe; gestor e diligenciador seguem a regra de [[AV-Hub-RBAC]]. **O hub aplica o filtro; o BFF não confia no `pedido_venda` recebido do navegador.**
- **Tela de permissão:** `meus-pedidos` (visualizar); `pedidos-equipe` e `pcp-pedidos` para as visões de equipe. Mapear em `auth.rotas_telas`: o modo `exigir` recusa rota sem mapa.
- **Erros:** 400 se `codigo_empresa` não for uuid ou `pedido_venda` faltar; 403 pelo escopo.

## O que o av-hub faz com isso

A tela 1.2 mostra, por item do pedido, a etapa atual da(s) parcial(is), a quantidade em cada etapa e a hora da última mudança. **Vocabulário provisório:** o BFF traduz `etapa` para rótulo com uma tabela no código (`lib/domain/etapasItem.ts`), com um rótulo genérico para etapa desconhecida. Item dividido em parciais em etapas diferentes aparece como várias linhas, uma por parcial, até a pergunta 3 do contrato 005 ser decidida.

## Perguntas em aberto

1. **Data de corte da primeira leitura** (Nathan): 30 dias ou outro.
2. **Agregação por pedido** (Nathan e Robert): etapa mais atrasada, ou lista de parciais? Esta versão devolve a lista.
3. **Onde roda o job** (Gustavo): no processo da API ou em worker próprio.
4. **Chave do MES:** o job usa a `MES_API_KEY` que o MES aceita hoje para o av-hub; a restrição por rota é a pendência L6 ([[Chaves-de-Integracao-AvHub-MES-Pipeline]]).

## Ver também
- [[005-Status-Item-Integracao-MES]]
- [[010-Itens-Pedido-Status]]
- [[Integracao-AvHub-MES-Volta-Plano]]
- [[AV-Hub-Portal-Vendedor-Plano]]
- [[Indice-Contratos]]
