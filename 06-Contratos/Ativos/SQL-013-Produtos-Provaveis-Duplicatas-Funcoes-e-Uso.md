---
id: SQL-013
aliases: ["Contrato SQL 013", "013-Produtos-Provaveis-Duplicatas"]
tags: [contrato, contrato-sql, dba, produtos, duplicatas, catalogo, leitura]
criado: 2026-10-19
atualizado: 2026-10-19
status: proposta
sistemas: [hub-banco]
dono: "Gustavo (DBA)"
etapa_0b: []
fontes: ["av-hub/services/cadastros/auxiliares/produtosDuplicados.ts (algoritmo atual, no navegador)", "av-hub/app/(protected)/cadastros/auxiliares/produtos-duplicados/page.tsx", "Dump Avhub (Esqueleto).sql:11648-11666 (core.produtos), :11587 (core.parceiros_produtos), :2490 (produto_vendas), :17737 (ordens_compra_itens), :17257 (ordens_compra), :15225 (pedidos_compras_itens), core.estoque_saldo, :275-321 (pg_trgm e unaccent já instaladas)", "Decisão do Nathan de 19/10/2026: reativar a tela, algoritmo no banco e na API, só leitura, sem alias, por unidade"]
criado_original: 2026-10-19
---

# Contrato SQL 013 — Produtos: prováveis duplicatas (normalização, pares por semelhança e uso do produto)

> **Onde atua:** av-hub: banco

> [!info] Situação em 19/10/2026
> **Status:** `proposta` · **Pasta:** `Ativos` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Gustavo (DBA)
>
> - ✅ A tela **Produtos — Prováveis Duplicatas** existe e é só leitura. Hoje baixa o catálogo inteiro da unidade pela API e agrupa **no navegador** por descrição normalizada **igual** + família + unidade (`produtosDuplicados.ts:21-29, 94-115`).
> - 📝 **Decisão do Nathan, 19/10/2026:** melhorar a tela; cálculo no banco e na API; **só leitura** (a rejeição do alias, [[API-002-Material-Alias-Omie-MES]], de 21/09/2026, continua valendo: quem resolve a duplicata é o Omie); escopo **por unidade**; mostrar uso em venda, OC, estoque e fornecedores.
> - ✅ `pg_trgm` e `unaccent` já estão instaladas no schema `public` do banco (`Dump Avhub (Esqueleto).sql:275-321`).
> - 🔴 Nenhum SQL deste contrato foi executado. O script abaixo é proposta de desenho, **não testado**; o Gustavo valida nomes de coluna, desempenho e o formato das datas de venda (checklist).
> - Contrato de API que consome este: [[API-012-Produtos-Provaveis-Duplicatas-Rota-e-Tela]].
>
> Selos em [[Regras-do-Vault]].

## Por quê

Cadastros de produto que são o mesmo item viram duplicatas por falha de cadastro (o vendedor não achou o produto e cadastrou de novo, código digitado de outro jeito, família errada). O algoritmo de hoje só pega a descrição **idêntica** depois de tirar acento e pontuação e ainda exige a **mesma família e unidade**; por isso perde "FLANGE 304 2\"" × "Flange aço inox 304 2 pol" e qualquer duplicata com a família errada, que é justamente o erro mais comum. Também baixa ~35 mil produtos (180 páginas) a cada troca de unidade e não mostra o uso, então o usuário não sabe qual cadastro manter.

Este contrato leva a regra para o banco: normaliza nome e código, acha os **pares** parecidos com nota e motivos, e entrega o **uso** de cada produto. O agrupamento e a paginação ficam na API ([[API-012-Produtos-Provaveis-Duplicatas-Rota-e-Tela]]).

## Regra de semelhança (resumo de negócio)

Dois produtos da **mesma unidade (`codigo_empresa`)** são par candidato quando:

1. o **nome normalizado** é parecido (trigramas ≥ 0,45) **ou**
2. o **código normalizado** é igual (ex.: `PAR-0012` × `PAR0012` × `par 12`).

A nota (0 a 100) combina nome, código, NCM, unidade e família, e **cai forte quando os números do nome diferem** (304 × 316, 2" × 3"), porque medida diferente é produto diferente. Família ou unidade diferentes **não eliminam** o par: só reduzem a nota e entram nos motivos.

## 1. Funções de normalização

Imutáveis, para poderem ser usadas em coluna gerada e em índice.

```sql
-- unaccent não é IMMUTABLE por padrão; o invólucro com o dicionário explícito é o padrão aceito
CREATE OR REPLACE FUNCTION core.fn_unaccent_imm(texto text)
RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT AS
$$ SELECT public.unaccent('public.unaccent'::regdictionary, texto) $$;

-- Nome: minúsculo, sem acento, símbolos de medida padronizados, sem pontuação,
-- sem palavras vazias, tokens em ordem alfabética (tolera ordem trocada).
CREATE OR REPLACE FUNCTION core.fn_norm_nome(descricao text)
RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT AS
$$
  WITH t AS (
    SELECT regexp_replace(
             regexp_replace(
               regexp_replace(
                 regexp_replace(lower(core.fn_unaccent_imm(descricao)),
                   '(\d)\s*("|''''|pol\M|polegadas?|in\M)', '\1 pol', 'g'),   -- 2" / 2pol / 2 polegadas -> 2 pol
                 '(ø|\mdiam\M|\mdiametro\M|\mdia\M)\.?', ' diam ', 'g'),         -- ø / diam / diametro -> diam
               '(\d)\s*[x×]\s*(\d)', '\1 x \2', 'g'),                            -- 10x20 -> 10 x 20
             '[^a-z0-9.,\s]', ' ', 'g') AS s
  ), tok AS (
    SELECT DISTINCT w
      FROM t, regexp_split_to_table(regexp_replace(t.s, '(\d),(\d)', '\1.\2', 'g'), '[\s]+') AS w
     WHERE w <> ''
       AND w NOT IN ('de','do','da','dos','das','com','para','em','e','a','o','c','p')
  )
  SELECT coalesce(string_agg(w, ' ' ORDER BY w), '') FROM tok
$$;

-- Código: só letras e números, minúsculo.
CREATE OR REPLACE FUNCTION core.fn_norm_codigo(codigo text)
RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT AS
$$ SELECT regexp_replace(lower(core.fn_unaccent_imm(codigo)), '[^a-z0-9]', '', 'g') $$;

-- Código sem zeros à esquerda de cada grupo de dígitos: 'par0012' -> 'par12'; '100' continua '100'.
CREATE OR REPLACE FUNCTION core.fn_norm_codigo_sem_zeros(codigo text)
RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT AS
$$ SELECT regexp_replace(core.fn_norm_codigo(codigo), '(?<![0-9])0+(?=[0-9])', '', 'g') $$;

-- Números do nome (ordenados): é a trava contra juntar 304 com 316 ou 2 pol com 3 pol.
CREATE OR REPLACE FUNCTION core.fn_numeros_nome(descricao text)
RETURNS text[] LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT AS
$$
  SELECT coalesce(array_agg(m[1] ORDER BY m[1]), ARRAY[]::text[])
    FROM regexp_matches(regexp_replace(lower(core.fn_unaccent_imm(descricao)), '(\d),(\d)', '\1.\2', 'g'),
                        '(\d+(?:\.\d+)?)', 'g') AS m
$$;
```

> 🟡 A lista de abreviações (`pol`, `diam`, `x`) e de palavras vazias é o **mínimo**. O Gustavo e o Compras acrescentam as que o catálogo real pedir (inox, aço carbono, SCH, flange, etc.) depois de rodar o relatório uma vez. Mudar a função exige recalcular as colunas geradas (seção 2).

## 2. Colunas geradas e índices em `core.produtos`

Aditivo. Colunas **geradas** (não entram em INSERT/UPDATE), então nenhuma rota, pipeline ou model existente precisa mudar.

```sql
ALTER TABLE core.produtos
  ADD COLUMN IF NOT EXISTS descricao_norm        text   GENERATED ALWAYS AS (core.fn_norm_nome(descricao))               STORED,
  ADD COLUMN IF NOT EXISTS tokens_nome           text[] GENERATED ALWAYS AS (string_to_array(core.fn_norm_nome(descricao), ' ')) STORED,
  ADD COLUMN IF NOT EXISTS numeros_nome          text[] GENERATED ALWAYS AS (core.fn_numeros_nome(descricao))            STORED,
  ADD COLUMN IF NOT EXISTS codigo_norm           text   GENERATED ALWAYS AS (core.fn_norm_codigo(codigo_produto))        STORED,
  ADD COLUMN IF NOT EXISTS codigo_norm_sem_zeros text   GENERATED ALWAYS AS (core.fn_norm_codigo_sem_zeros(codigo_produto)) STORED;

CREATE INDEX IF NOT EXISTS ix_produtos_descricao_norm_trgm
  ON core.produtos USING gin (descricao_norm gin_trgm_ops)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_produtos_codigo_norm
  ON core.produtos (codigo_empresa, codigo_norm_sem_zeros)
  WHERE deleted_at IS NULL AND codigo_norm_sem_zeros <> '';
```

Observações:

- ✅ `core.produtos` tem `codigo_empresa uuid NOT NULL` e `deleted_at` (`Dump Avhub (Esqueleto).sql:11648-11666`); os únicos de código são por `(codigo_empresa, codigo_produto)` e `(codigo_empresa, codigo_produto_omie)`.
- `ADD COLUMN … GENERATED … STORED` reescreve a tabela uma vez. Rodar fora do horário (catálogo de ~35 mil linhas por unidade, deve levar segundos) e avisar o Nathan e o Robert da janela.
- 🔴 Confirmar que **nenhum** `INSERT` do `omie-elt-pipeline` ou de outra rotina usa `INSERT … SELECT *` ou lista as colunas de `core.produtos` por posição (coluna nova gerada quebraria isso). A rota de produtos do `api-acos-vital` usa model Sequelize com lista de atributos; coluna nova não entra sozinha.

## 3. Função de pares: `core.fn_produtos_duplicatas_pares`

Devolve **pares** (não grupos) com nota e motivos. A API junta os pares em grupos.

```sql
CREATE OR REPLACE FUNCTION core.fn_produtos_duplicatas_pares(
  p_empresa         uuid,
  p_limiar          integer DEFAULT 70,      -- 50 a 100
  p_somente_ativos  boolean DEFAULT true
)
RETURNS TABLE (
  id_a         uuid,
  id_b         uuid,
  nota         integer,      -- 0 a 100
  nota_nome    integer,      -- 0 a 100
  nota_codigo  integer,      -- 0 a 100
  motivos      text[]
)
LANGUAGE sql STABLE
SET pg_trgm.similarity_threshold = 0.45
AS $$
  WITH cand AS (
    SELECT a.id AS id_a, b.id AS id_b,
           a.descricao_norm AS an, b.descricao_norm AS bn,
           a.tokens_nome AS at_, b.tokens_nome AS bt,
           a.numeros_nome AS anum, b.numeros_nome AS bnum,
           a.codigo_norm AS ac, b.codigo_norm AS bc,
           a.codigo_norm_sem_zeros AS acz, b.codigo_norm_sem_zeros AS bcz,
           a.ncm AS ancm, b.ncm AS bncm,
           upper(btrim(a.unidade_medida)) AS au, upper(btrim(b.unidade_medida)) AS bu,
           a.familias_produtos AS af, b.familias_produtos AS bf
      FROM core.produtos a
      JOIN core.produtos b
        ON b.codigo_empresa = a.codigo_empresa
       AND b.id > a.id
       AND b.deleted_at IS NULL
       AND (
             (a.descricao_norm <> '' AND a.descricao_norm % b.descricao_norm)
          OR (a.codigo_norm_sem_zeros <> '' AND a.codigo_norm_sem_zeros = b.codigo_norm_sem_zeros)
       )
     WHERE a.codigo_empresa = p_empresa
       AND a.deleted_at IS NULL
       AND (NOT p_somente_ativos OR (a.ativo AND b.ativo))
  ), pont AS (
    SELECT c.*,
      -- nome: o maior entre trigrama e sobreposição de palavras (Jaccard)
      greatest(
        similarity(c.an, c.bn),
        (SELECT count(*)::numeric FROM unnest(c.at_) t WHERE t = ANY (c.bt))
        / NULLIF(cardinality(c.at_) + cardinality(c.bt)
                 - (SELECT count(*) FROM unnest(c.at_) t WHERE t = ANY (c.bt)), 0)
      ) AS sim_nome,
      -- código: igual normalizado = 100; igual sem zeros = 90; parecido (trigrama) = 0..80
      CASE
        WHEN c.ac <> '' AND c.ac = c.bc  THEN 100
        WHEN c.acz <> '' AND c.acz = c.bcz THEN 90
        WHEN length(c.acz) >= 4 AND length(c.bcz) >= 4 AND similarity(c.acz, c.bcz) >= 0.6
             THEN round(similarity(c.acz, c.bcz) * 80)::int
        ELSE 0
      END AS n_codigo,
      (c.anum IS DISTINCT FROM c.bnum) AS numeros_diferentes,
      (c.ancm IS NOT NULL AND c.ancm = c.bncm) AS mesmo_ncm,
      (c.au IS NOT DISTINCT FROM c.bu) AS mesma_unidade,
      (c.af = c.bf) AS mesma_familia
    FROM cand c
  ), calc AS (
    SELECT p.id_a, p.id_b,
           round(p.sim_nome * 100)::int AS nota_nome,
           p.n_codigo AS nota_codigo,
           greatest(0, least(100,
               round(p.sim_nome * 100)::int
             + CASE WHEN p.n_codigo >= 90 THEN 20 WHEN p.n_codigo >= 60 THEN 8 ELSE 0 END
             + CASE WHEN p.mesmo_ncm THEN 5 ELSE 0 END
             - CASE WHEN NOT p.mesma_unidade THEN 10 ELSE 0 END
             - CASE WHEN NOT p.mesma_familia THEN 5 ELSE 0 END
             - CASE WHEN p.numeros_diferentes THEN 40 ELSE 0 END
           )) AS nota,
           array_remove(ARRAY[
             CASE WHEN p.sim_nome >= 0.9 THEN 'nome_quase_igual'
                  WHEN p.sim_nome >= 0.45 THEN 'nome_parecido' END,
             CASE WHEN p.n_codigo = 100 THEN 'codigo_igual_normalizado'
                  WHEN p.n_codigo = 90  THEN 'codigo_igual_sem_zeros'
                  WHEN p.n_codigo >= 60 THEN 'codigo_parecido' END,
             CASE WHEN p.mesmo_ncm THEN 'mesmo_ncm' END,
             CASE WHEN p.mesma_unidade THEN 'mesma_unidade' ELSE 'unidade_diferente' END,
             CASE WHEN p.mesma_familia THEN 'mesma_familia' ELSE 'familia_diferente' END,
             CASE WHEN p.numeros_diferentes THEN 'numeros_diferentes' END
           ], NULL) AS motivos
      FROM pont p
  )
  SELECT id_a, id_b, nota, nota_nome, nota_codigo, motivos
    FROM calc
   WHERE nota >= greatest(50, least(100, p_limiar))
   ORDER BY nota DESC, id_a, id_b
$$;

COMMENT ON FUNCTION core.fn_produtos_duplicatas_pares(uuid, integer, boolean) IS
'Pares de produtos da mesma unidade com nome ou código parecidos (candidatos a duplicata), com nota 0-100 e motivos. Só leitura. Contrato SQL-013.';
```

Regras da nota (documentadas para a tela explicar):

| Componente | Efeito na nota |
|---|---|
| `sim_nome` (0 a 1, o maior entre trigrama e sobreposição de palavras) | base (`nota_nome` = ×100) |
| código igual normalizado ou sem zeros (`n_codigo` ≥ 90) | +20 |
| código parecido (`n_codigo` 60 a 89) | +8 |
| mesmo NCM | +5 |
| unidade diferente | −10 |
| família diferente | −5 |
| **números do nome diferentes** | **−40** |

Faixas de confiança (usadas pela API): **alta** ≥ 90, **média** 75 a 89, **baixa** 70 a 74 com o limiar padrão (abaixo do limiar o par não sai).

## 4. Função de uso: `core.fn_produtos_uso`

Recebe os `id` dos produtos de **uma** unidade e devolve o uso agregado de cada um. Chamada só para os produtos que estão em algum grupo (centenas, não o catálogo inteiro).

```sql
CREATE OR REPLACE FUNCTION core.fn_produtos_uso(p_empresa uuid, p_ids uuid[])
RETURNS TABLE (
  id_produto                  uuid,
  -- vendas (itens de NF/pedido de venda)
  vendas_itens                bigint,
  vendas_quantidade           numeric,
  vendas_valor_total          numeric,
  vendas_ultima_data          date,
  -- OC do hub (ordens_compra_itens, exceto rascunho e cancelada)
  oc_itens                    bigint,
  oc_quantidade               numeric,
  oc_ultima_data              date,
  -- pedidos de compra espelhados do Omie (pedidos_compras_itens)
  pedidos_compra_omie_itens   bigint,
  -- requisições do Compras
  requisicoes                 bigint,
  -- estoque
  estoque_saldo               numeric,
  estoque_fisico              numeric,
  estoque_reservado           numeric,
  estoque_data_posicao        date,
  -- fornecedores (cotações em parceiros_produtos)
  fornecedores_qtd            bigint,
  cotacao_ultima_data         date,
  cotacao_ultimo_valor        numeric,
  fornecedores_top            jsonb      -- até 5: [{codigo_parceiro_omie, nome_fantasia, ultimo_valor, ultima_data}]
)
LANGUAGE sql STABLE
AS $$
  SELECT p.id,
         v.itens, v.qtd, v.valor, v.ultima,
         oc.itens, oc.qtd, oc.ultima,
         pc.itens,
         rq.qtd,
         es.saldo, es.fisico, es.reservado, es.data_pos,
         fo.qtd, fo.ultima_data, fo.ultimo_valor, fo.top
    FROM core.produtos p
    LEFT JOIN LATERAL (
        SELECT count(*) AS itens, sum(pv.quantidade)::numeric AS qtd, sum(pv.valor_total) AS valor,
               max(to_date(NULLIF(pd.data_faturamento, ''), 'DD/MM/YYYY')) AS ultima   -- 🔴 conferir formato
          FROM core_vendas_faturamento.produto_vendas pv
          LEFT JOIN core_vendas_faturamento.pedidos_vendas pd
                 ON pd.codigo_empresa = pv.codigo_empresa AND pd.numero_pedido = pv.numero_pedido
         WHERE pv.codigo_empresa = p.codigo_empresa
           AND pv.deleted_at IS NULL
           AND pv.codigo_produto_omie = p.codigo_produto_omie
    ) v ON true
    LEFT JOIN LATERAL (
        SELECT count(*) AS itens, sum(i.quantidade) AS qtd, max(o.created_at)::date AS ultima
          FROM core_vendas_faturamento.ordens_compra_itens i
          JOIN core_vendas_faturamento.ordens_compra o ON o.id = i.id_ordem_compra
         WHERE i.codigo_empresa = p.codigo_empresa
           AND i.codigo_produto = p.codigo_produto
           AND o.deleted_at IS NULL
           AND o.status IN ('aguardando_aprovacao', 'aprovado')
    ) oc ON true
    LEFT JOIN LATERAL (
        SELECT count(*) AS itens
          FROM core_vendas_faturamento.pedidos_compras_itens i
          JOIN core_vendas_faturamento.pedidos_compras c ON c.id = i.id_pedido_compra
         WHERE i.codigo_empresa = p.codigo_empresa
           AND i.codigo_produto_omie = p.codigo_produto_omie
           AND c.deleted_at IS NULL
    ) pc ON true
    LEFT JOIN LATERAL (
        SELECT count(*) AS qtd
          FROM core_vendas_faturamento.requisicoes_compra r
         WHERE r.codigo_empresa = p.codigo_empresa
           AND r.material = p.codigo_produto
           AND r.deleted_at IS NULL
    ) rq ON true
    LEFT JOIN LATERAL (
        SELECT sum(s.saldo) AS saldo, sum(s.fisico) AS fisico, sum(s.reservado) AS reservado,
               max(s.data_posicao) AS data_pos
          FROM core.estoque_saldo s
         WHERE s.codigo_empresa = p.codigo_empresa
           AND s.codigo_produto_omie = p.codigo_produto_omie
           AND s.deleted_at IS NULL
    ) es ON true
    LEFT JOIN LATERAL (
        WITH ult AS (
          SELECT DISTINCT ON (pp.id_parceiro)
                 pp.id_parceiro, pp.valor_unidade, pp.data_cotacao
            FROM core.parceiros_produtos pp
           WHERE pp.codigo_empresa = p.codigo_empresa
             AND pp.id_produto = p.codigo_produto_omie
             AND pp.deleted_at IS NULL
           ORDER BY pp.id_parceiro, pp.data_cotacao DESC NULLS LAST, pp.created_at DESC
        )
        SELECT count(*) AS qtd,
               max(ult.data_cotacao) AS ultima_data,
               (SELECT u2.valor_unidade FROM ult u2 ORDER BY u2.data_cotacao DESC NULLS LAST LIMIT 1) AS ultimo_valor,
               (SELECT jsonb_agg(jsonb_build_object(
                         'codigo_parceiro_omie', t.id_parceiro,
                         'nome_fantasia', pa.nome_fantasia,
                         'ultimo_valor', t.valor_unidade,
                         'ultima_data', t.data_cotacao))
                  FROM (SELECT * FROM ult ORDER BY data_cotacao DESC NULLS LAST LIMIT 5) t
                  LEFT JOIN core.parceiros pa
                         ON pa.codigo_parceiro_omie = t.id_parceiro AND pa.codigo_empresa = p.codigo_empresa
                        AND pa.deleted_at IS NULL) AS top
          FROM ult
    ) fo ON true
   WHERE p.codigo_empresa = p_empresa
     AND p.id = ANY (p_ids)
     AND p.deleted_at IS NULL
$$;

COMMENT ON FUNCTION core.fn_produtos_uso(uuid, uuid[]) IS
'Uso de produtos (vendas, OC, pedidos Omie, requisições, estoque, fornecedores) para a tela de prováveis duplicatas. Só leitura. Contrato SQL-013.';
```

Pontos de ligação (a conferir pelo DBA, ver checklist):

| Uso | Chave de ligação | Observação |
|---|---|---|
| Vendas | `produto_vendas.codigo_produto_omie = produtos.codigo_produto_omie` (mesma `codigo_empresa`) | ✅ coluna `NOT NULL` em `produto_vendas`; produto sem `codigo_produto_omie` fica com vendas zeradas |
| OC do hub | `ordens_compra_itens.codigo_produto = produtos.codigo_produto` | `codigo_produto` do item é nulo em OC antiga; produto obrigatório desde o [[LOG-36-Compras-Produto-Obrigatorio-e-Comprador-da-OC]] ✅ |
| Pedido de compra Omie | `pedidos_compras_itens.codigo_produto_omie` | espelho do Omie; coexiste com a OC do hub (BL-047) |
| Requisições | `requisicoes_compra.material = produtos.codigo_produto` | `material` passa a ser o código do cadastro (API-010) |
| Estoque | `estoque_saldo.codigo_produto_omie` | soma dos locais; ver checklist |
| Fornecedores | `parceiros_produtos.id_produto = produtos.codigo_produto_omie` e `id_parceiro = parceiros.codigo_parceiro_omie` | mesma ligação do `vw_catalogo_de_produtos` ✅ |

## 5. Desempenho e limites

- O `%` com o índice GIN limita a busca a candidatos; o `JOIN` é por unidade e por `b.id > a.id`, então cada par aparece uma vez.
- 🔴 **Medir** com a unidade maior (≥ 35 mil produtos): meta de **até 5 s** para `fn_produtos_duplicatas_pares` com limiar 70. Se passar, opções (a decidir com o Gustavo, na ordem): subir `pg_trgm.similarity_threshold` para 0,55; exigir mesmo primeiro token; ou materializar o resultado numa tabela `core.produtos_duplicatas_cache` recalculada de hora em hora. **Não criar o cache sem necessidade**: ele é o único ponto que viraria dado persistido.
- `fn_produtos_uso` é chamada só com os produtos dos grupos da página pedida (no máximo ~100 por chamada).
- Sem `SECURITY DEFINER`: roda com o papel da API, que já lê essas tabelas.

## 6. Compatibilidade

- Só `ADD COLUMN IF NOT EXISTS` de colunas **geradas**, `CREATE INDEX IF NOT EXISTS` e `CREATE OR REPLACE FUNCTION`. Nada que existe muda de nome, tipo ou significado.
- Nenhuma escrita em tabela de negócio e nenhuma tabela nova (decisão: sem alias, sem "não é duplicata").
- Reversão: `DROP FUNCTION` das funções, `DROP INDEX` dos dois índices e `DROP COLUMN` das cinco colunas geradas.

## Fora deste contrato

- **Vincular/mesclar duplicatas** no sistema (`material_alias_omie`, botão "Vincular como alias"): rejeitado em 21/09/2026 ([[API-002-Material-Alias-Omie-MES]]). A resolução é feita no Omie por quem cuida do catálogo.
- **Marcar "não é duplicata"** e esconder o grupo: exigiria tabela de decisões; não entra agora (🟡 pergunta ao Nathan no [[API-012-Produtos-Provaveis-Duplicatas-Rota-e-Tela]]).
- **Cruzar Vital e Uberaba:** os catálogos numeram de forma independente (`COMMENT` de `core.produtos.codigo_empresa`); fica por unidade.

## Checklist do DBA

- [ ] `\d+ core.produtos`, `core.estoque_saldo`, `core_vendas_faturamento.produto_vendas`, `ordens_compra_itens`, `pedidos_compras_itens`, `requisicoes_compra`: nomes e tipos das colunas usadas nas seções 3 e 4.
- [ ] **Formato de `pedidos_vendas.data_faturamento`** (hoje `varchar(10)`): `DD/MM/YYYY` ou `YYYY-MM-DD`? Ajustar o `to_date` da seção 4.
- [ ] `core.estoque_saldo`: uma linha por produto e local (a soma de `saldo` está certa) ou histórico por `data_posicao` (então pegar só a posição mais recente por local)?
- [ ] Nenhum `INSERT … SELECT *` ou lista posicional em `core.produtos` (pipeline Omie e rotinas) que quebre com colunas geradas novas.
- [ ] Rodar a seção 2 em cópia do banco, medir o tempo do `ADD COLUMN` e dos índices.
- [ ] Rodar `fn_produtos_duplicatas_pares` na unidade maior e na menor; anotar tempo, número de pares e uma amostra de 20 pares para o Nathan/Compras avaliarem a nota.
- [ ] Ajustar a lista de abreviações e palavras vazias da `fn_norm_nome` com o resultado da amostra.
- [ ] Versionar o script (migration `api012`, padrão `apiNNN`) junto das demais.

## Aceite

1. `SELECT core.fn_norm_nome('FLANGE AÇO INOX 304 2"')` e `SELECT core.fn_norm_nome('Flange aco inox 304 2 pol')` devolvem o **mesmo texto**.
2. `SELECT core.fn_norm_codigo_sem_zeros('PAR-0012')` e `('par12')` devolvem `par12`.
3. Dois produtos de teste com nomes que só diferem em `304` × `316` **não** passam do limiar 70 (nota ≤ 60 por `numeros_diferentes`).
4. Dois produtos de teste com família diferente e o mesmo nome aparecem como par, com `familia_diferente` nos motivos.
5. `fn_produtos_uso` devolve, para um produto com venda, OC, saldo e cotação, todos os blocos preenchidos e `fornecedores_top` com até 5 itens.
6. Nenhuma linha de `core.produtos` mudou em valor (as colunas novas são geradas).

## Ver também
[[API-012-Produtos-Provaveis-Duplicatas-Rota-e-Tela]] · [[API-002-Material-Alias-Omie-MES]] · [[API-001-Produtos-Parceiros-Filtro-Incremental|001-Produtos-Parceiros-Filtro-Incremental]] · [[SQL-009-Categoria-Sem-Escopo-Empresa-Views]] · [[Produtos-e-Familias]]
