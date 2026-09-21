---
tags: [contrato-api, dev, api-acos-vital]
status: proposta
criado: 2026-09-17
---

# Contrato de API 001 — filtro incremental `alterado_desde` em `GET /produtos` e `GET /parceiros`

**Status:** proposta, não implementada. Não depende de DDL — os models
`Produto`/`Parceiro` já têm `updated_at` (Sequelize `timestamps: true`,
`paranoid: true`). É uma mudança só de rota (`src/routes/produtos.js`,
`src/routes/parceiros.js`), sem alteração de schema.

**Repositório de destino:** `api-acos-vital` (`src/routes/produtos.js`, `src/routes/parceiros.js`).

## Por quê

O módulo de Estoque vai consumir `core.produtos`/`core.parceiros` do av-hub
via **polling** — não existe (e não deveria ser assumido) nenhum mecanismo
de evento entre av-hub e MES hoje (achado registrado nas notas de modelagem,
[[Decisoes-Chave-ERP]], item "Casamento av-hub ↔ MES", ainda não
desenhado). Hoje `GET /produtos` e `GET /parceiros` **não têm filtro por
data de alteração** — só suportam filtros de igualdade/`iLike` em campos de
negócio (`codigo_produto`, `descricao`, `nome_fantasia`, etc.) mais
paginação e ordenação. Sem um filtro incremental, qualquer consumidor
externo (Estoque, ou qualquer outro sistema futuro) precisaria puxar o
catálogo inteiro a cada ciclo de polling — caro e desnecessário à medida
que o catálogo cresce.

## Contrato de request/response

### `GET /produtos`

**Novo parâmetro de query:**

| Parâmetro | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `alterado_desde` | string (ISO 8601 datetime) | não | Retorna só produtos com `updated_at >= alterado_desde`. Sem o parâmetro, comportamento atual (sem filtro) é mantido — mudança 100% aditiva/opt-in. |

**Comportamento:**
- Valor inválido (não parseável como data) → **ignorado silenciosamente**, mesma filosofia já usada para `sort` inválido neste mesmo arquivo — não retorna erro, só não aplica o filtro.
- Combina com os filtros já existentes (`codigo_empresa`, `ativo`, etc.) via `AND`.
- **Inclui registros deletados?** Não — `paranoid: true` no model já exclui soft-deleted por padrão em qualquer `findAll`/`findAndCountAll`. Isso é uma limitação real para um consumidor de polling: um produto excluído entre dois ciclos de sync não aparece nem como "alterado" nem como "removido" nesta resposta. Ver "Perguntas em aberto".

**Response:** sem mudança de shape — mesmo array paginado de `ProdutoResponse` já documentado no Swagger da rota.

### `GET /parceiros`

Mesmo contrato, mesmo nome de parâmetro (`alterado_desde`), mesma semântica — consistência entre as duas rotas.

## Implementação sugerida

```js
// src/routes/produtos.js — dentro de buildWhere, mesmo padrão dos filtros existentes
if (query.alterado_desde) {
  const desde = new Date(query.alterado_desde);
  if (!Number.isNaN(desde.getTime())) {
    where.updated_at = { [Op.gte]: desde };
  }
}
```

Mesmo bloco (adaptado) em `src/routes/parceiros.js`.

## Perguntas em aberto (levar para o dev/Nathan antes de implementar)

1. **Exclusão não aparece no filtro incremental** — `paranoid: true` filtra
   soft-deleted por padrão. Se o Estoque precisar saber que um produto foi
   removido (para remover da sua própria projeção), este contrato sozinho
   não resolve. Duas opções a decidir: (a) aceitar a lacuna por ora (baixo
   risco — produto raramente é excluído, mais comum ficar `ativo: false`),
   ou (b) o Estoque faz reconciliação periódica por diferença de conjunto
   (mesmo padrão de `exclusionSync` do `omie-elt-pipeline`), sem depender
   deste filtro para detectar exclusão.
2. Nome do parâmetro (`alterado_desde`) segue a convenção já usada no
   `omie-elt-pipeline` (`filtrar_por_data_de`/`alteradoEmField`) só que em
   português simples — confirmar se esse nome está alinhado com o que o
   time de Estoque vai esperar, já que quem primeiro consome este parâmetro
   é um sistema fora deste repositório.
3. **Autenticação do consumidor**: hoje `x-api-key` é uma chave única
   compartilhada para todo o frontend/integração (`apiKeyAuth.js`). Se o
   Estoque for outro consumidor externo, vale decidir se ele usa a mesma
   chave ou se cada integração externa merece a sua própria (rastreabilidade
   de quem está chamando o quê) — fora do escopo deste contrato específico,
   mas relacionado.

## Ver também
- [[Indice-Contratos]]
