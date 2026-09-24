---
tags: [contrato-sql, dba, bug, vendas, faturamento]
status: proposta
criado: 2026-09-24
---

# Contrato SQL 009 — `core.categorias` sem `codigo_empresa` no JOIN de 4 views (bug real, testado)

**Achado em:** 24/09/2026, investigando um "duplicate key" no React da tela de Pedidos. Não é
bug de tela — é bug de dado, nas views.

## Por quê

`core.categorias` tem `codigo_categoria` **repetido entre unidades** (Mogi e Uberaba usam os
mesmos códigos, ex. `1.01.01`, `0.01.01`) — o índice único da tabela já reflete isso corretamente:
`uq_categorias_empresa_codigo (codigo_empresa, codigo_categoria)`.

Só que 4 views fazem `LEFT JOIN core.categorias cat ON cat.codigo_categoria = <código do pedido/nf>`
**sem** `AND cat.codigo_empresa = <empresa do pedido/nf>`. Toda vez que o código da categoria
também existe na OUTRA unidade, o JOIN casa com as duas linhas de `core.categorias` — e o registro
do pedido/nota sai **duplicado** na saída da view (fan-out clássico de LEFT JOIN sem chave
completa).

**Testado e confirmado no banco local (24/09/2026):**
- Pedido de venda **25970**: antes do fix, a tela mostrava **76 registros** (deveria ser 53) e
  "Valor do pedido" somava **R$ 1.409.191,16**. Depois do fix: **53 registros**, **R$ 964.763,88**
  — o valor estava **dobrando parcelas** cujo `codigo_categoria` batia com o código de outra
  unidade.
- **8.747 linhas de `pedidos_vendas`** (banco local, espelho de produção) têm `codigo_categoria`
  em código compartilhado entre unidades — candidatas a sair duplicadas em qualquer uma das 4
  views abaixo.

## As 4 views afetadas

| View | Alias do JOIN | Chave do lado esquerdo | Usada por |
|---|---|---|---|
| `vw_vendas_planilha` | `cat` | `p.codigo_categoria` | `/api/pedidos-equipe`, `/api/vendas/pedidos-de-venda`, `PedidoDetalhe`, `PedidosTable` (av-hub) |
| `vw_vendas_base` | `cat` | `cm.cod_categoria` | Base de `/vendas_base`, `/vendas_classificada`, dashboards de vendas |
| `vw_nf_classified` | `cat` | `a.cod_categoria_raw` | Base de faturamento/notas fiscais classificadas |
| `vw_faturamento_planilha` | `cat_nf` (nota) e `cat_pv` (pedido) | `n.codigo_categoria` / `pv.codigo_categoria` | `/faturamento_planilha`, dashboards de faturamento |

`vw_vendas_classificada`, `vw_vendas_planilha_resumo` e `vw_faturamento_planilha_resumo` **não**
fazem o JOIN diretamente, mas são construídas em cima de views acima — herdam a duplicação sem
repetir o bug (nada a corrigir nelas, corrigir a origem já resolve).

## O contrato em si

Adicionar `AND cat.codigo_empresa = <mesma coluna de empresa do lado esquerdo>` em cada JOIN. Só
isso — nenhuma outra coluna/regra muda. Testado no banco local com `CREATE OR REPLACE VIEW`
(mesma definição de produção, só essa condição a mais); as 4 saíram com **zero grupos duplicados**
depois do fix (verificado agrupando por `(chave do registro, codigo_empresa, is_track_record)`).

```sql
-- vw_vendas_planilha
-- (na definição completa) trocar:
LEFT JOIN core.categorias cat ON cat.codigo_categoria::text = p.codigo_categoria::text AND cat.deleted_at IS NULL
-- por:
LEFT JOIN core.categorias cat ON cat.codigo_categoria::text = p.codigo_categoria::text AND cat.codigo_empresa = p.codigo_empresa AND cat.deleted_at IS NULL

-- vw_vendas_base
LEFT JOIN core.categorias cat ON cat.codigo_categoria::text = cm.cod_categoria::text AND cat.deleted_at IS NULL
-- por:
LEFT JOIN core.categorias cat ON cat.codigo_categoria::text = cm.cod_categoria::text AND cat.codigo_empresa = cm.codigo_empresa AND cat.deleted_at IS NULL

-- vw_nf_classified
LEFT JOIN core.categorias cat ON cat.codigo_categoria::text = a.cod_categoria_raw::text AND cat.deleted_at IS NULL
-- por:
LEFT JOIN core.categorias cat ON cat.codigo_categoria::text = a.cod_categoria_raw::text AND cat.codigo_empresa = a.codigo_empresa AND cat.deleted_at IS NULL

-- vw_faturamento_planilha (duas ocorrências)
LEFT JOIN core.categorias cat_nf ON cat_nf.codigo_categoria::text = n.codigo_categoria::text AND cat_nf.deleted_at IS NULL
LEFT JOIN core.categorias cat_pv ON cat_pv.codigo_categoria::text = pv.codigo_categoria::text AND cat_pv.deleted_at IS NULL
-- por:
LEFT JOIN core.categorias cat_nf ON cat_nf.codigo_categoria::text = n.codigo_categoria::text AND cat_nf.codigo_empresa = n.codigo_empresa AND cat_nf.deleted_at IS NULL
LEFT JOIN core.categorias cat_pv ON cat_pv.codigo_categoria::text = pv.codigo_categoria::text AND cat_pv.codigo_empresa = pv.codigo_empresa AND cat_pv.deleted_at IS NULL
```

O `CREATE OR REPLACE VIEW` completo de cada uma (definição inteira, só essa linha trocada) está
salvo no ambiente local — o Gustavo pode pedir pro Nathan ou tirar de novo com
`pg_get_viewdef('core_vendas_faturamento.<view>'::regclass, true)` direto no banco de teste, já que
a estrutura das 4 é a mesma em teste/produção (mesmo bug, mesmas colunas).

## Perguntas em aberto

- **Isso já afeta relatórios fechados/enviados?** Se algum dashboard de faturamento ou comissão já
  rodou sobre esses números duplicados e o resultado foi usado pra decisão (ex.: comissão paga,
  meta batida), vale conferir period a período depois do fix — o valor pode CAIR quando corrigido
  (como caiu no 25970: R$ 1.409.191 → R$ 964.763).
- **Produção tem a mesma sobreposição de código de categoria entre unidades?** No banco local
  (espelho de produção + catálogos recém-sincronizados pela pipeline) sim, 8.747 linhas expostas.
  Confirmar se o dump de produção mais recente também tem `core.categorias` com códigos repetidos
  entre `codigo_empresa` — se sim, o bug é idêntico lá.

## Depois de aplicado

Nada muda no av-hub nem na API — os 4 endpoints continuam devolvendo o mesmo formato, só sem a
linha fantasma. As telas que já tratavam a chave errada (`key={p.codigo_pedido_omie}` sem
`sequencial`, corrigido no av-hub em 24/09/2026 nos componentes `PedidoDetalhe`, `PedidosTable` e
`pedidos-de-venda/page.tsx`) deixam de logar o warning de key duplicada do React — era sintoma, não
causa.
