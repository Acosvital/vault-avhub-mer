---
id: API-001
aliases: ["001-Produtos-Parceiros-Filtro-Incremental"]
tags: [contrato, contrato-api, api-acos-vital, pipeline]
criado: 2026-10-14
atualizado: 2026-10-29
status: implementado-no-codigo
sistemas: [hub-api, pipeline-omie]
dono: "Gustavo (DBA)"
etapa_0b: []
fontes: ["api-acos-vital/src/schemas/core/tables/produtos/produtos.route.js:57-75", "api-acos-vital/src/schemas/core/tables/parceiros/parceiros.route.js:97-114"]
criado_original: 2026-09-17
---

# Contrato de API 001 — filtro incremental `alterado_desde` em `GET /produtos` e `GET /parceiros`

> **Onde atua:** av-hub: API · pipeline Omie

> [!info] Situação em 26/10/2026
> **Status:** `implementado-no-codigo` · **Pasta:** `Entregues` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Gustavo (DBA)
>
> - ✅ **`alterado_desde` de produtos e parceiros corrigido, informado pelo Gustavo (26/10/2026):** fecha a pendência S27 do [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] e PS-033. Não reconferi no código nem na produção.
> - ✅ `GET /produtos` e `GET /parceiros` aceitam `alterado_desde` (`api-acos-vital/src/schemas/core/tables/produtos/produtos.route.js:57-75`; `.../parceiros/parceiros.route.js:97-114`).
> - 🕓 Registro de 15/10 (superado): o bloco `alterado_desde` ficava depois de `return where;` e o filtro nunca executava; corrigido, ver o item acima.
> - 🟡 Os caminhos `src/routes/*.js` citados no texto não existem mais: o código mora em `src/schemas/<schema>/...`.
> - ❓ Produção: o vault v1 registra aplicação confirmada pelo dump de 21/09; não reconferido hoje.
>
> Conferido em 14/10/2026 contra `api-pcp` 579a625, `app-pcp` 1fca8d3, `api-acos-vital` f322dcd, `omie-elt-pipeline` 0f739f0 e os dumps de 14/10. O front do av-hub (HUB b55ac55) só pelo vault v1 (❓).
> O texto original abaixo está inteiro; os trechos que o estado atual contradiz têm nota de rodapé.

> [!abstract] Resumo em linguagem natural
> **O que é:** Definiu o filtro `alterado_desde` nas listas de produtos e parceiros, para quem consome (Estoque e MES, o sistema de produção) buscar só o que mudou desde a última leitura, sem baixar tudo.
> **Quem é afetado:** Estoque e MES, que passam a ler só as mudanças; o Gustavo (DBA) mantém as rotas.
> **Situação:** ✅ No código. A correção do filtro foi informada pelo Gustavo em 26/10/2026. ❓ Produção não foi reconferida.


> **Atualização de 07/10/2026 — conferido no código (`main` = `develop` da `api-acos-vital`):** os caminhos `src/routes/*.js` citados abaixo **não existem mais**; desde o PR #276 o código mora em `src/schemas/<schema>/…`. O `apiKeyAuth.js` hoje tem 3 tipos de chave (`API_KEYS` do ambiente = admin; `auth.chaves_servico` no banco com nível leitura/escrita/admin; `MES_INTEGRACAO_KEYS`, só para o PUT do 34), então a "Pergunta 3" abaixo (chave por consumidor) já tem mecanismo no banco, sem restrição por rota. A **pipeline não usa `alterado_desde`**: produtos e parceiros usam `filtrar_por_data_de/ate` com janela fixa (este contrato é de API, consumido pelo Estoque/MES). Ver [[Chaves-e-Autenticacao|Chaves-de-Integracao-AvHub-MES-Pipeline]].

**Status: aplicada.** Confirmado em `src/routes/produtos.js:185-234`/`parceiros.js` contra o código real (21/09/2026) — ver [[Mapa-v1-para-v2|Auditoria-Dump-Producao-2026-09-21]]. `GET /produtos` e `GET /parceiros` já implementam `?alterado_desde=` exatamente com o comportamento documentado abaixo. As 3 perguntas em aberto já foram todas resolvidas — ver [[Pontas-Soltas|Perguntas-em-Aberto-Consolidadas]] (G-13, G-14, G-15):
- **Pergunta 1 (exclusão não aparece no filtro):** resolvida em 21/09/2026 — Gustavo implementou `?incluir_deletados=true` em ambas as rotas; os excluídos voltam no mesmo payload incremental, com `deleted_at` preenchido.
- **Pergunta 2 (nome do parâmetro):** confirmado — `alterado_desde` já está em produção e é o nome esperado pelo time de Estoque.
- **Pergunta 3 (autenticação do consumidor):** esclarecido, não resolvido — hoje `apiKeyAuth.js` só valida contra a lista do `.env`, sem registrar qual chave bateu; o `requestLogger` grava a chave mascarada, então diferenciar consumidores nos logs é possível **só se cada um tiver chave própria**, decisão ainda não tomada para este contrato. Os contratos [[API-003-Requisicao-Compra-Integracao-MES|003-Requisicao-Compra-Integracao-MES]] e [[API-005-Status-Item-Integracao-MES|005-Status-Item-Integracao-MES]] (integração av-hub↔MES) já adotam chave por direção (`MES_API_KEY`) — mesma recomendação poderia se estender a este contrato quando o Estoque virar consumidor real.

<details>
<summary>Texto original da proposta (17/09/2026), antes da confirmação em produção</summary>

**Status:** proposta, não implementada. Não depende de DDL[^c1] — os models
`Produto`/`Parceiro` já têm `updated_at` (Sequelize `timestamps: true`,
`paranoid: true`). É uma mudança só de rota (`src/routes/produtos.js`,
`src/routes/parceiros.js`), sem alteração de schema.

</details>

**Repositório de destino:** `api-acos-vital` (`src/routes/produtos.js`, `src/routes/parceiros.js`).

## Por quê

O módulo de Estoque vai consumir `core.produtos`/`core.parceiros` do av-hub
via **polling** — não existe (e não deveria ser assumido) nenhum mecanismo
de evento entre av-hub e MES hoje (achado registrado nas notas de modelagem,
[[Registro-de-Decisoes|Decisoes-Chave-ERP]], item "Casamento av-hub ↔ MES", ainda não
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
- [[HIST-Indice-Contratos|Indice-Contratos]]
- [[Mapa-v1-para-v2|Auditoria-Dump-Producao-2026-09-21]]
- [[Pontas-Soltas|Perguntas-em-Aberto-Consolidadas]]

[^c1]: Nota de 14/10/2026: Superado: o contrato está implementado, ver a Situação em 14/10 no topo.
