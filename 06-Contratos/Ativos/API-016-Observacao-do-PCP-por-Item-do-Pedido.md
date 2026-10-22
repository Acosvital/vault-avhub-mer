---
id: API-016
aliases: ["Contrato 016", "016-Observacao-do-PCP-por-Item"]
tags: [contrato, contrato-api, pcp, pedidos, observacao, item, diligenciador, av-hub]
criado: 2026-10-22
atualizado: 2026-10-22
status: proposta
sistemas: [hub-banco, hub-api, hub-front]
dono: "Gustavo"
etapa_0b: []
fontes: ["Pedido do Nathan de 22/10/2026", "api-acos-vital src/schemas/core_vendas_faturamento/tables/pedido_observacao_pcp (model e route)", "Dump do Avhub para referência.sql (core_vendas_faturamento.pedido_observacao_pcp; core_fluxo.item_estado_projetado.codigo_item_omie)", "av-hub components/Pedidos/PedidoDetalhe.tsx, services/pcp/observacoesPedido.ts, app/api/pcp/observacoes", "api-acos-vital src/middlewares/escopoVendedor.js (dono 'observacao')"]
criado_original: 2026-10-22
---

# Contrato de API 016 — Observação do PCP por item (produto) do pedido

> **Onde atua:** av-hub: banco, API, front

> [!info] Situação em 22/10/2026
> **Status:** `proposta` · **Pasta:** `Ativos` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Gustavo (banco e API); Nathan (front)
>
> - 📝 **Pedido do Nathan, 22/10/2026:** a observação que o diligenciador do PCP escreve hoje **por parcial** tem de ser **por linha de item, por produto do pedido**: cada produto pode ter a sua observação.
> - ✅ **Hoje** a observação é **por parcial**: tabela `core_vendas_faturamento.pedido_observacao_pcp`, grão `(codigo_empresa, codigo_pedido_omie)`, rotas `GET/POST /pedido_observacao_pcp`, `GET /pedido_observacao_pcp/contagem` e `DELETE /pedido_observacao_pcp/:id`. No detalhe do pedido (Portal do PCP) o botão "Observações do PCP" fica **abaixo de cada parcela**, não de cada produto.
> - ✅ **Decisão do Nathan (22/10/2026): as observações antigas por parcial são descartadas** (a tela deixa de mostrá-las; não são copiadas para os itens). A tabela antiga **não é apagada** por este contrato (ver "Fora deste contrato").
> - 🔴 **Banco e API não existem** para o item: nenhuma tabela, rota ou `contagem` por item.
> - **MES (Robert): sem trabalho.** O MES não lê esta observação.
>
> Selos em [[Regras-do-Vault]].

## Por quê

Um pedido de venda tem vários produtos e cada um anda no seu ritmo (um já saiu da produção, outro espera matéria-prima). A observação "falta chapa, previsão dia 30" pertence **ao produto**, não à parcela inteira: na parcela, o diligenciador hoje escreve num balde só e o leitor não sabe a qual produto o texto se refere. Com a observação no item, o histórico do produto fica junto dele, e a lista de produtos do pedido mostra de relance **quais têm observação**.

## Chave do item

O item de um pedido é identificado por **`(codigo_empresa, numero_pedido, codigo_item_omie)`**: o mesmo grão que o Fluxo já usa (`core_fluxo.item_estado_projetado`, contrato 46, onde `codigo_item_omie` é o `ide.codigo_item` do Omie, o mesmo de `produto_vendas.codigo_item_omie`, **estável na parcialização**, decisão de 21/09).

> [!tip] Por que `numero_pedido` e não `codigo_pedido_omie`
> `codigo_pedido_omie` identifica **uma parcela**. O pedido (`numero_pedido`) é a família de parcelas. Como o `codigo_item_omie` **não muda quando o pedido é parcializado**, a observação presa a `(empresa, numero_pedido, item)` **acompanha o produto** pelas parcelas e não some quando o pedido se divide, o que a observação por `codigo_pedido_omie` não garantia.

## Regras de negócio

1. **Uma observação pertence a um item**, nunca a uma parcela nem ao pedido inteiro. Vale a mesma regra do log atual: é **log, não cadastro** (sem UPDATE; corrigir = apagar e escrever outra).
2. **Cada item tem a sua linha do tempo**, em ordem da mais recente para a mais antiga, com texto, tags, autor e data.
3. **Texto** obrigatório (sem só espaços); **tags** livres, como hoje (array, pode ser vazio).
4. **Autor** vem da sessão autenticada (token), **nunca do corpo** (como hoje).
5. **Escopo:** quem escreve, lê ou apaga só mexe em observação de item de **pedido de vendedor do seu escopo** (a mesma conferência de dono que a observação por parcial já tem em `escopoVendedor.js`, agora pelo pedido do item). Fora do escopo: `403 { codigo: "PEDIDO_FORA_DO_ESCOPO" }`.
6. **Permissões** (tela `pcp-pedidos` em `auth.rotas_telas`): ler = `pode_visualizar`, escrever = `pode_criar`, apagar = `pode_deletar`. São as mesmas de hoje; não há perfil novo.
7. **Item precisa existir** no pedido vivo: item que não está em `produto_vendas` daquele `(empresa, numero_pedido)` dá `404`. Se o pipeline do Omie recriar o pedido (delete + insert numa ressincronização), a observação **não cai junto**: sem FK para `produto_vendas`, como a tabela atual (comentário dela: "o pipeline recria pedidos e a observação do PCP não pode cair junto").
8. **Pedido que sai da base** deixa observações órfãs, **escondidas** (a tela só lê por item existente). Não há faxina automática neste contrato.
9. **Observações antigas por parcial:** não aparecem mais em lugar nenhum da tela e **não são migradas**. A rota antiga sai do front; o que fazer com a tabela fica para depois (ver "Fora deste contrato").

## 1. Banco (Gustavo): migration

Schema `core_vendas_faturamento`.

### Tabela `pedido_item_observacao_pcp`

| Coluna | Tipo | Regra |
|---|---|---|
| `id` | uuid, PK, `uuidv7()` | |
| `codigo_empresa` | uuid, NOT NULL, FK para `core.unidades(id)` | unidade do pedido (o `numero_pedido` só é único dentro da unidade) |
| `numero_pedido` | varchar(15), NOT NULL | `CHECK (btrim(numero_pedido) <> '')`, igual a `pedidos_vendas.numero_pedido` |
| `codigo_item_omie` | bigint, NOT NULL | `CHECK (codigo_item_omie > 0)` |
| `texto` | text, NOT NULL | `CHECK (btrim(texto) <> '')` |
| `tags` | text[], NOT NULL, default `'{}'` | índice GIN |
| `created_at` | timestamptz, NOT NULL, default `now()` | |
| `created_by` | uuid, NOT NULL, FK para `auth.usuarios(id)` | da sessão |
| `deleted_at` | timestamptz | exclusão lógica (a de hoje) |
| `deleted_by` | uuid, FK para `auth.usuarios(id)` | |

- **Índice** para a linha do tempo de um item: `(codigo_empresa, numero_pedido, codigo_item_omie, created_at DESC) WHERE deleted_at IS NULL`.
- **Índice** para a contagem do pedido inteiro: `(codigo_empresa, numero_pedido) WHERE deleted_at IS NULL` (o do índice acima já cobre pelo prefixo; 🟡 Gustavo decide se basta um só).
- **Índice GIN** em `tags` (como o atual).
- **Sem FK para `produto_vendas` nem para `pedidos_vendas`**, de propósito (regra 7).
- Comentário da tabela no estilo da atual: log, grão `(empresa, pedido, item)`, não confundir com `obs_venda` do Omie.
- `GRANT` ao papel da API, como as demais tabelas do schema.

## 2. API (Gustavo)

Rotas novas em `/pedido_item_observacao_pcp`, na tela `pcp-pedidos` de `auth.rotas_telas`. Erros no formato da API (`{ codigo?, detail }`). **Rotas de caminho fixo (`/contagem`) antes de `/:id`.**

### 2.1 `GET /pedido_item_observacao_pcp`: linha do tempo de um item

| Parâmetro | Tipo | Regra |
|---|---|---|
| `codigo_empresa` | uuid | **obrigatório** (`400` se faltar ou inválido) |
| `numero_pedido` | string | **obrigatório** |
| `codigo_item_omie` | inteiro > 0 | **obrigatório** |
| `tag` | string | opcional: só observações que têm essa tag |
| `page`, `limit` | inteiros | padrão 1 e 50; `limit` máximo 200 |

Resposta `200`, mais recente primeiro, sem as apagadas:

```json
{
  "total": 2,
  "page": 1,
  "limit": 50,
  "total_pages": 1,
  "data": [
    {
      "id": "0199f3a2-7c1e-7b52-9d10-3f6b2a1c8e44",
      "codigo_empresa": "759979bd-2b2d-41f2-b1b7-db6fae89ee59",
      "numero_pedido": "29234",
      "codigo_item_omie": 10481738611,
      "texto": "Falta chapa 12mm, previsão do fornecedor dia 30.",
      "tags": ["matéria-prima"],
      "created_at": "2026-10-22T14:03:11.000Z",
      "created_by": "0199f3a2-7c1e-7b52-9d10-3f6b2a1c8e01",
      "nome_autor": "Maria Souza"
    }
  ]
}
```

`nome_autor` como hoje: nome completo do funcionário do usuário, com o `username` de fallback. Permissão `pode_visualizar`.

### 2.2 `POST /pedido_item_observacao_pcp`: escrever

Corpo: `{ "codigo_empresa": "<uuid>", "numero_pedido": "29234", "codigo_item_omie": 10481738611, "texto": "...", "tags": ["..."] }`. Autor = token (o BFF manda `created_by` só enquanto o contrato 06 não vale em todo lugar, como hoje).

- `201` com a observação criada (mesmo formato do `GET`).
- `400` texto vazio, tags que não são lista de texto, `numero_pedido` ou `codigo_item_omie` inválidos.
- `404` item não existe no pedido (regra 7) ou pedido não existe.
- `403 PEDIDO_FORA_DO_ESCOPO` quando o pedido não é de vendedor do escopo.
- Permissão `pode_criar`.

### 2.3 `DELETE /pedido_item_observacao_pcp/:id`: apagar

Exclusão lógica (`deleted_at`, `deleted_by` do token). `404` se o id não existe ou já foi apagado; `403 PEDIDO_FORA_DO_ESCOPO` se o pedido do item não é do escopo (a conferência de dono por observação que já existe, agora lendo a tabela nova). Resposta `204`. Permissão `pode_deletar`.

### 2.4 `GET /pedido_item_observacao_pcp/contagem`: quantas observações cada item tem

Serve à lista de produtos do pedido, para marcar os itens que têm observação **sem** abrir uma por uma.

| Parâmetro | Tipo | Regra |
|---|---|---|
| `codigo_empresa` | uuid | **obrigatório** |
| `numero_pedido` | string | **obrigatório** |

Resposta `200`, **só itens com pelo menos uma observação** (ausência = zero; payload menor):

```json
{
  "data": [
    { "codigo_item_omie": 10481738611, "total": 2 },
    { "codigo_item_omie": 10481738620, "total": 1 }
  ]
}
```

Escopo e permissão como o `GET` (`pode_visualizar`). 🟡 A rota atual `/contagem` aceitava uma **lista de parcelas** (até 200); aqui a unidade é **um pedido**, que é o que a tela de detalhe precisa. Se a **lista de pedidos** quiser o selo "tem observação" no futuro, é outro contrato.

### 2.5 Escopo do vendedor (`escopoVendedor.js`)

O mapa de rotas ganha `pedido_item_observacao_pcp`:

- **Leitura e escrita:** dono = o pedido `(codigo_empresa, numero_pedido)` do corpo ou da query tem de ter alguma parcela de vendedor do escopo (mesma `donosDaFamilia` do detalhe do pedido).
- **`DELETE /:id`:** dono pela observação (`pedido_item_observacao_pcp.id` → `codigo_empresa`, `numero_pedido`), como `cfg.dono === "observacao"` faz hoje para a tabela antiga.
- Sem dono (pedido fora da base): a rota responde `404`, não `403`.

## 3. Tela (Nathan)

No detalhe do pedido (Portal do PCP), a observação sai do **rodapé da parcela** e vai para **dentro de cada linha de produto**:

| Bloco | O que muda |
|---|---|
| Tabela de produtos de cada parcela | nova coluna/ícone **Observações** por linha, com a **contagem** do item (vinda de `/contagem`, carregada junto com a lista de produtos). Clicar abre, **embaixo da linha do produto**, a linha do tempo daquele item e o campo para escrever |
| Escrever e apagar | os mesmos campos de hoje (texto + tags) e a confirmação de exclusão, agora sobre o item; só com `pode_criar` e `pode_deletar` |
| Botão "Observações do PCP" por parcela | **sai** |
| Observações antigas por parcial | **não aparecem** (decisão de 22/10) |
| Mesmo produto em duas parcelas | como o `codigo_item_omie` é o mesmo, **a mesma linha do tempo** aparece nas duas (é o mesmo produto do pedido) |
| BFF | `/api/pcp/observacoes` passa a falar com `/pedido_item_observacao_pcp` com `(empresa, numero_pedido, item)`; sai o `codigo_pedido_omie` |

## Fora deste contrato

- **Migrar ou apagar** as observações antigas por parcial e **dropar** `pedido_observacao_pcp` (e suas rotas): fica para quando o Nathan e o Gustavo confirmarem que ninguém precisa mais do histórico. A tabela e a rota antigas **continuam existindo**, só sem uso na tela.
- **Selo "tem observação" na lista de pedidos** (por pedido ou por item).
- **Editar** observação (continua sendo log).
- **Notificar** o vendedor ou o comprador quando o diligenciador escreve.
- **Observação do pedido inteiro** (sem item): quem precisa escrever algo geral escreve no item mais relevante; 🟡 Nathan avisa se isso fizer falta.
- **Faxina** de observações de pedido que saiu da base (regra 8).

## Checklist

**Gustavo (banco e API)**
- [ ] Migration: tabela `pedido_item_observacao_pcp` com os `CHECK`, as FK de `codigo_empresa` e `created_by`/`deleted_by`, os índices e o `GRANT`.
- [ ] Rotas `GET`, `POST`, `DELETE /:id` e `GET /contagem` em `/pedido_item_observacao_pcp`, com `/contagem` antes de `/:id`, os erros da seção 2 e o item conferido em `produto_vendas`.
- [ ] `escopoVendedor.js`: entrada `pedido_item_observacao_pcp` (dono pelo pedido; `DELETE` pela observação).
- [ ] Linhas de `auth.rotas_telas` (`pcp-pedidos`): `GET` (`pode_visualizar`), `POST` (`pode_criar`), `DELETE` (`pode_deletar`).
- [ ] Swagger das rotas novas.

**Nathan (front)**
- [ ] BFF `/api/pcp/observacoes` (e `[id]`) falando com as rotas novas; serviço `services/pcp/observacoesPedido.ts` por `(empresa, numero_pedido, item)`.
- [ ] Detalhe do pedido: observação dentro da linha de cada produto, com contagem; remover o bloco por parcela.
- [ ] Mensagem clara para `403 PEDIDO_FORA_DO_ESCOPO` e `404` de item inexistente.

**Robert (MES):** nada.

## Aceite

1. `POST` numa observação para o item 10481738611 do pedido 29234 devolve `201`; `GET` do mesmo item a traz com o nome do autor; o `GET` de **outro item** do mesmo pedido volta vazio.
2. `GET /contagem?codigo_empresa=…&numero_pedido=29234` devolve só os itens que têm observação, com o total certo; item sem observação **não** aparece.
3. Item que não existe no pedido: `POST` devolve `404`; `numero_pedido` ou `codigo_item_omie` inválido: `400`.
4. Diligenciador sem o vendedor do pedido no escopo: `GET`, `POST` e `DELETE` respondem `403 PEDIDO_FORA_DO_ESCOPO`.
5. `DELETE /:id` apaga logicamente e a observação some do `GET` e da `contagem`; apagar de novo dá `404`.
6. Pedido parcializado: a observação feita no item aparece também na outra parcela que contém o mesmo `codigo_item_omie`.
7. Ressincronizar o pedido (delete + insert) **não** apaga as observações dos itens.
8. Perfil só com `pode_visualizar` lê e recebe `403` ao escrever; sem `pode_deletar`, `403` ao apagar.
9. Na tela, as observações antigas por parcial não aparecem e o botão por parcela sumiu.

## Ver também
[[LOG-26-Vendas-Liberacao-Pedido]] · [[LOG-40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]] · [[LOG-50-Tirar-as-Marcas-de-Escopo-de-Vendedores-do-Front]] · [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas]]
