---
tags: [contrato-logica, contrato-sql, contrato-api, dashboards, vendedores]
criado: 2026-09-30
status: proposta
---

# Contrato 33 — Dashboards: o filtro de empresa passa a ser a unidade de origem do vendedor

**Criado em:** 30/09/2026 · **Para:** DBA (Gustavo) + backend (`api-acos-vital`) · **SQL + API**

Decisões do Nathan (30/09/2026): (1) vendedor sem funcionário vinculado usa o Omie em que foi cadastrado; (2) os totais dos dashboards também seguem a unidade do vendedor; (3) quem define a unidade é o RH.

---

## 1. Por quê

O vendedor pode vender em vários Omies (Aços Vital, Aços Uberaba, HRM), mas para dashboard e relatório ele **pertence a uma só unidade**. Hoje o filtro "empresa" do topo dos dashboards de **vendas**, **faturamento** e **por tipo** responde "em quais Omies houve venda". O ranking faz `codigo_empresa = ANY(empresas)`, onde `empresas` é a lista de Omies em que a pessoa faturou. Resultado: um vendedor de uma unidade que vendeu no Omie de outra aparece nas duas, e o total de cada unidade fica errado.

## 2. A regra

**Unidade de origem do vendedor** = `core.funcionarios.codigo_empresa` do funcionário ligado ao vendedor (`vendedores.id_funcionario`). É a lotação do RH.

- **Pessoa com vários vendedores** (um por Omie): todos os códigos dela herdam a mesma unidade, a do funcionário.
- **Vendedor sem funcionário vinculado:** usa `vendedores.codigo_empresa` (o Omie do cadastro). Ver o aviso da seção 5.
- **O filtro `codigo_empresa` dos dashboards** passa a significar **"vendedores cuja unidade de origem é X"**, com **todo** o faturamento/venda deles, em **qualquer** Omie. Vale para as linhas, os rankings, os totais e os cartões.
- **Sem filtro:** nada muda (todas as unidades).
- O Omie onde a venda foi feita continua existindo no dado (`codigo_empresa` do pedido/nota) e pode ser mostrado como coluna à parte. Só deixa de ser o critério do filtro.

## 3. O contrato

### 3.1 SQL — view `vw_vendedor_unidade`

Uma linha por vendedor (por Omie), já com a unidade de origem resolvida. As funções `fn_*` dos dashboards juntam por `(codigo_empresa, codigo_vendedor_omie)` do pedido/nota. DDL no **apêndice A**.

| Coluna | Significado |
|---|---|
| `codigo_empresa` | Omie onde o código de vendedor existe |
| `codigo_vendedor_omie` | código do vendedor nesse Omie |
| `id_funcionario` | vínculo com o RH (pode ser nulo) |
| `unidade_origem` | `funcionarios.codigo_empresa` se houver vínculo; senão `vendedores.codigo_empresa` |
| `origem_da_unidade` | `'funcionario'` ou `'cadastro_omie'`, para a tela e a auditoria |

### 3.2 API — o que muda nos endpoints

O parâmetro `codigo_empresa` **continua com o mesmo nome e tipo** (uuid). Só muda o significado, então o front não muda de contrato.

Endpoints afetados (todos recebem o `codigo_empresa` do seletor do topo):

- Faturamento: `dashboard_mensal_faturamento`, `faturamento_resumo_mensal`, `ranking_vendedores_faturamento`, `detalhe_vendedor_faturamento`, `ranking_clientes_faturamento`, `ritmo_meta_faturamento`, `situacao_pedidos`, `vendas_faturadas_por_tipo`.
- Vendas: `dashboard_mensal_vendas`, `ranking_vendedores_vendas`, `detalhe_vendedor_vendas`, `ranking_clientes_vendas`, `ritmo_meta_vendas`, `vendas_por_tipo_contrato`.
- Comissões, se o seletor de empresa também as alcança (`comissoes_provisoria`): confirmar com o Nathan.

**Ranking de vendedores:** o filtro deixa de ser `$n = ANY(empresas)` e passa a comparar com a `unidade_origem` da pessoa. A resposta ganha `unidade_origem` (uuid) e `nome_unidade_origem`. `empresas` (Omies onde faturou) continua na resposta, informativa.

**Nada de valor muda sem filtro:** os totais "todas as unidades" têm que bater, ao centavo, com os de hoje. É o teste de aceite principal.

### 3.3 Cadastro de vendedores (leitura)

`GET /vendedores` e `GET /vendedores/{id}` passam a devolver `unidade_origem`, `nome_unidade_origem` e `origem_da_unidade`. Nenhum campo novo é editável: a unidade vem do RH. Para mudar a unidade de um vendedor, muda-se a lotação do funcionário (ou vincula-se o funcionário).

## 4. Quem fica de fora da regra do RH (vendedores sem funcionário)

Levantamento no banco local de teste (esqueleto de 29/09/2026) — **19 vendedores ativos sem `id_funcionario`**:

**Omie Aços Uberaba (5):** DAYANE SILVA, EDUARDO VITAL, FERNANDA LESSA, JORGE LUIZ, MARIA EDUARDA.

**Omie Aços Vital (14):** AÇOS VITAL, DANIEL SOUZA DA SILVA, DAYANE SILVA, DIEGO FERNANDES, EDUARDO VITAL, FERNANDA LESSA, FLÁVIO COUTINHO, JAMES MADSON OLIVEIRA DE SOUZA, JORGE LUIZ, LEONARDO MARQUES DIAS, MOISES MENEZES, Nathan Lucca - Dev, PAULO SOCORRO, Robert Wilson - Dev.

## 5. Perguntas em aberto

| # | Pergunta | Quem responde |
|---|---|---|
| **P1** | **Quatro pessoas aparecem nos DOIS Omies sem vínculo:** DAYANE SILVA, EDUARDO VITAL, FERNANDA LESSA e JORGE LUIZ (uma linha em Uberaba e outra em Vital). Com a regra "usa o Omie do cadastro", cada uma contaria em duas unidades, o que contraria "pertence a uma só". Precisam ser vinculadas a um funcionário (ou se decide a unidade de cada uma). | Nathan / RH |
| **P2** | "AÇOS VITAL" (vendedor genérico da empresa) e os dois "- Dev" (Nathan e Robert) são vendedores de teste/genéricos: ficam fora dos dashboards ou entram em Vital? | Nathan |
| **P3** | Comissões (`comissoes_provisoria`): o seletor de empresa também vale para elas? Pela lógica do Nathan, sim. | Nathan |
| **P4** | Quando a pessoa tem vendedores em Omies diferentes e o funcionário é de outra unidade (21 casos hoje em que o Omie do cadastro difere da lotação, ex.: DIEGO ARANTES, funcionário da HRM, com vendedores em Uberaba e Vital), confirmar que vale a lotação do RH. | Nathan |
| **P5** | Quando o RH transferir um funcionário de unidade, o histórico dos dashboards **muda retroativamente** (a unidade é a de hoje, não a da época da venda). Aceitável? | Nathan |

## 6. Depois de aplicado (av-hub)

1. Seletor de empresa do topo dos dashboards: o texto passa a dizer que é a **unidade do vendedor**. Nenhuma mudança de parâmetro.
2. Ranking/detalhe: mostrar a unidade de origem do vendedor e, à parte, o Omie onde a venda foi feita.
3. Cadastro de vendedores (`/vendas/vendedores`): coluna "Unidade" com a origem (`funcionário` ou `Omie do cadastro`), e aviso nos que usam o plano B (sem funcionário vinculado).

## 7. Aceite

- [ ] DBA aplicou a view do apêndice A (teste, depois produção).
- [ ] As funções `fn_*` e os endpoints da seção 3.2 usam `unidade_origem`.
- [ ] Sem filtro, os totais dos 3 dashboards batem com os de hoje, ao centavo.
- [ ] Com filtro, cada vendedor aparece em **uma** unidade só, e a soma das unidades é igual ao total "todas".
- [ ] P1 a P5 respondidas.

---

## Apêndice A — SQL proposto (DBA)

> Proposta. Nomes de schema seguem o banco local de teste (`core_vendas_faturamento.vendedores`, `core.funcionarios`). O DBA ajusta ao que a produção usa.

```sql
CREATE OR REPLACE VIEW core_vendas_faturamento.vw_vendedor_unidade AS
SELECT
  v.codigo_empresa,
  v.codigo_vendedor_omie,
  v.id_funcionario,
  COALESCE(f.codigo_empresa, v.codigo_empresa) AS unidade_origem,
  CASE WHEN f.codigo_empresa IS NOT NULL THEN 'funcionario' ELSE 'cadastro_omie' END
    AS origem_da_unidade
FROM core_vendas_faturamento.vendedores v
LEFT JOIN core.funcionarios f
  ON f.id = v.id_funcionario
 AND f.deleted_at IS NULL
WHERE v.deleted_at IS NULL;
```

Exemplo de uso numa função de dashboard (substitui o filtro pela empresa do pedido):

```sql
-- antes:  WHERE p.codigo_empresa = $empresa
-- depois: JOIN core_vendas_faturamento.vw_vendedor_unidade vu
--           ON vu.codigo_empresa = p.codigo_empresa
--          AND vu.codigo_vendedor_omie = p.codigo_vendedor_omie
--         WHERE ($empresa IS NULL OR vu.unidade_origem = $empresa)
```

Teste de conferência (deve retornar zero linhas de diferença):

```sql
-- cada código de vendedor tem exatamente uma unidade de origem
SELECT codigo_empresa, codigo_vendedor_omie, COUNT(*)
FROM core_vendas_faturamento.vw_vendedor_unidade
GROUP BY 1, 2 HAVING COUNT(*) > 1;
```
