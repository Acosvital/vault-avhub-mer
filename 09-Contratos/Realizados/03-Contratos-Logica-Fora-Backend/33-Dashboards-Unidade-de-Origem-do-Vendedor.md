---
tags: [contrato-logica, contrato-sql, contrato-api, dashboards, vendedores]
criado: 2026-09-30
atualizado: 2026-10-07
status: aplicada
---

# Contrato 33 — Dashboards: unidade de origem e período de atividade do vendedor

> **Atualização de 07/10/2026 — conferido no código (`main` = `develop` da `api-acos-vital`; produção não conferida no código; produção só pelo dump de 07/10, que cobre schema e dados, não o comportamento da API em produção; [[Auditoria-Dump-Producao-2026-10-07]]):** o código da API está em `main` com o commit **`5231219`** (PR #275, 02/10). O front (`397cf81`, branch `feat/vendedor-periodo-ativo` do av-hub, **local, sem push** em 01/10) **não foi reconferido** nesta leitura. As perguntas P1–P6 seguiam em aberto; **(atualizado em 07/10, [[Registro-de-Decisoes-2026-10-07]] item 49)** o status de cada uma está na tabela do §7 (P4 e P5 🟡 mantidos como implementado; P1, P2, P3, P6 e P7 🔴 Nathan, sem decisão). Não foi comparado se os números dos dashboards por unidade batem.

> **✅ ENTREGUE (01/10/2026).** **Conferência de 01/10/2026 na `api-test`** (o DBA avisou que concluiu): `GET /vendedores` devolve `ativo_desde`, `inativo_desde`, `unidade_origem`, `nome_unidade_origem` e `origem_da_unidade`. Os números dos dashboards por unidade não foram comparados. Front: commit `397cf81` na branch `feat/vendedor-periodo-ativo` do av-hub, ainda sem push.

**Criado em:** 30/09/2026 · **Para:** DBA (Gustavo) + backend (`api-acos-vital`) · **SQL + API**

**Implementado e testado no banco e na API locais** (esqueleto de 29/09), e o front do av-hub já consome. Falta aplicar na `api-test`/produção: o SQL é o anexo `33-anexos/0001-unidade-origem-e-periodo.sql` (`0003-aplicar-nas-funcoes-existentes.sql` aplica nas funções de dashboard) e o patch da API é `33-anexos/0002-api-vendedores-unidade-e-periodo.patch`.

Decisões do Nathan (30/09/2026): (1) vendedor sem funcionário vinculado usa o Omie em que foi cadastrado; (2) os totais dos dashboards também seguem a unidade do vendedor; (3) quem define a unidade é o RH; (4) **vendedor inativo não aparece depois que saiu**, e o período dele fica em duas datas no cadastro do vendedor.

---

## 1. Por quê

**Unidade.** O vendedor pode vender nos Omies de Mogi, Uberaba e HRM, mas para dashboard e relatório ele **pertence a uma só unidade**. O filtro de empresa do topo dos dashboards de vendas, faturamento e por tipo respondia "em quais Omies houve venda": um vendedor de uma unidade que vendeu no Omie de outra aparecia nas duas, e o total de cada unidade ficava errado. O ranking ainda filtrava por `codigo_empresa = ANY(empresas)` (onde a pessoa faturou).

**Período.** O ranking de um mês soma a venda do mês e **não olhava o cadastro**: vendedor inativo aparecia nos meses em que faturou (na api-test: 7 em jan/2026, 2 em fev e mar, nenhum de abril em diante). Mas o banco não sabe quando o vendedor saiu: `vendedores` só tem o `ativo` de hoje, e o RH quase não tem datas (9 de 199 funcionários com admissão, 0 com desligamento). Decisão: duas datas no próprio vendedor.

## 2. As regras

### 2.1 Unidade de origem

`unidade_origem` do vendedor = `core.funcionarios.codigo_empresa` do funcionário ligado (`vendedores.id_funcionario`), a lotação do RH. **Sem funcionário vinculado**, vale `vendedores.codigo_empresa` (o Omie do cadastro). Venda de código de vendedor que nem está cadastrado fica no Omie onde foi feita: **a venda nunca some do total**.

O filtro `codigo_empresa` dos dashboards passa a significar **"vendedores cuja unidade de origem é X"**, com **todo** o faturamento/venda deles em qualquer Omie. Sem filtro, nada muda. O Omie onde a venda foi feita continua no dado (`codigo_empresa` do pedido/nota).

### 2.2 Período de atividade

| Campo (`vendedores`) | Significado |
|---|---|
| `ativo_desde` (date, nulo) | primeiro dia em que o vendedor vale nos dashboards. Nulo = desde sempre |
| `inativo_desde` (date, nulo) | primeiro dia em que **deixou** de valer. Nulo = sem data de saída |

O vendedor entra na lista de um mês `M` quando `(ativo_desde IS NULL OR ativo_desde <= último dia de M) AND (inativo_desde IS NULL OR inativo_desde > primeiro dia de M)`. `inativo_desde = 2026-03-31` aparece até março e some em abril; `2026-03-15` também aparece em março.

**Onde vale:** nas **listas de vendedor** (ranking e detalhe por vendedor), de vendas e de faturamento. **Os totais e cartões não mudam** (a venda de quem saiu continua somando no total da unidade: opção "A" do Nathan). Efeito colateral aceito: o ranking soma um pouco menos que o total quando algum vendedor é cortado por período.

**Sem data informada, nada some.** Vendedor inativo **sem** `inativo_desde` continua aparecendo nos meses em que faturou, como hoje, até alguém preencher a data.

**`ativo` × datas:** `ativo` continua sendo o estado de hoje. A API recusa `ativo = true` junto com `inativo_desde` (a pipeline do Omie grava `ativo` direto, por isso **não há CHECK** cruzando os dois no banco). A CHECK `ck_vendedores_periodo` só garante `inativo_desde >= ativo_desde`.

## 3. O contrato SQL

Tudo no anexo `0001-unidade-origem-e-periodo.sql` (uma transação):

| Objeto | O que faz |
|---|---|
| colunas `ativo_desde`, `inativo_desde` + CHECK `ck_vendedores_periodo` | período de atividade (2.2) |
| view `vw_vendedor_unidade` | uma linha por vendedor/Omie com `unidade_origem`, `origem_da_unidade` (`funcionario` ou `cadastro_omie`) e as duas datas |
| `fn_unidade_do_vendedor(p_codigo_empresa, p_cod_vendedor)` | unidade de origem; sem cadastro devolve o próprio Omie |
| `fn_vendedor_no_periodo(p_codigo_empresa, p_cod_vendedor, p_ini, p_fim)` | o vendedor valia no período? Sem cadastro ou sem datas: sim |

**Funções de dashboard alteradas** (a assinatura **não muda**, só o corpo; no filtro `p_codigo_empresa` entra `fn_unidade_do_vendedor(codigo_empresa, cod_vendedor)` no lugar de `codigo_empresa`):

| Função | Mudança |
|---|---|
| `fn_dashboard_mensal_faturamento`, `fn_dashboard_mensal_vendas` | filtro pela unidade de origem |
| `fn_faturamento_resumo_mensal`, `fn_situacao_pedidos` | idem |
| `fn_vendas_faturadas_por_tipo`, `fn_vendas_por_tipo_contrato`, `fn_vendas_realizadas_por_tipo` | idem |
| `fn_ranking_clientes_faturamento`, `fn_ranking_clientes_vendas` | idem |
| `fn_ranking_vendedores_faturamento`, `fn_ranking_vendedores_vendas` | filtro pela unidade de origem **+ regra do período** |
| `fn_detalhe_vendedor_faturamento`, `fn_detalhe_vendedor_vendas` | filtro pela unidade de origem **+ regra do período** |
| `fn_dashboard_mensal_faturamento_por_unidade`, `fn_dashboard_mensal_vendas_por_unidade` | **agrupam** pela unidade de origem em vez do Omie (passam a mostrar as 3 unidades) |

**Fora do escopo** (continuam filtrando pelo Omie): `fn_painel_*` (Painel de compras/PCP), `fn_pedidos_venda_linhas`, `fn_faturamento_planilha_resumo_periodo`, `fn_conferencia_itens_parcela`. São outras telas; ver P7.

## 4. O contrato de API

Patch `0002-api-vendedores-unidade-e-periodo.patch` (4 arquivos em `src/`):

- **`GET /vendedores`** devolve, por vendedor, `unidade_origem` (uuid), `nome_unidade_origem` e `origem_da_unidade` (`funcionario` | `cadastro_omie`). Só leitura: a unidade vem do RH, não se edita aqui. (Só a listagem; o `GET /vendedores/{id}` não foi alterado.)
- **`GET`/`POST`/`PUT /vendedores`** aceitam e devolvem `ativo_desde` e `inativo_desde` (`AAAA-MM-DD` ou `null`; string vazia vira `null`). 400 se a data é inválida/impossível, se `inativo_desde < ativo_desde`, ou se `ativo = true` vem com `inativo_desde`. Em PUT parcial a CHECK do banco responde 400. O upsert do sync do Omie **não apaga** as datas (só grava o que vem no corpo).
- **`GET /ranking_vendedores_faturamento` e `_vendas`**: o parâmetro `codigo_empresa` vai direto para a função e **deixa de virar o filtro extra `= ANY(empresas)`** (esse filtro cortaria quem é da unidade mas só vendeu em outro Omie). Cada linha ganha `unidade_origem` e `nome_unidade_origem`. `empresas` (Omies onde faturou) continua na resposta, informativa.
- Os demais endpoints da seção 3 **não mudam de contrato**: mesmo parâmetro `codigo_empresa`, mesmo formato, outro significado.

## 5. O front (av-hub)

Branch `feat/vendedor-periodo-ativo`, ainda **sem commit**; tipos, telas e textos já consomem os campos acima:

- **Seletor de unidade do topo dos dashboards**: textos passam a dizer "unidade do vendedor" / "Todas as unidades". A busca de pedido/NF do topo agora ajusta o filtro para a unidade **do vendedor** (antes ia para o Omie do pedido).
- **Cartão de vendedor do ranking** (faturamento e vendas): dica com a unidade de origem.
- **Cadastros > Acessos > Vendedores**: coluna **Unidade** (com aviso "Omie do cadastro" quando não há funcionário) e a seção **Período nos dashboards** (`Ativo desde` / `Inativo desde`, o segundo só habilita com o vendedor inativo).
- **Pedidos de venda**: o filtro de vendedor só oferece **ativos**; a lista inteira continua carregada porque resolve o nome de pedidos antigos (mesmo padrão da blacklist de vendedores).

## 6. Testes feitos (banco e API locais, esqueleto de 29/09/2026)

| Teste | Resultado |
|---|---|
| Sem filtro, jan–set/2026, 15 funções × 9 meses (135 consultas), antes × depois | **117 idênticas**; as 18 diferentes são só as `_por_unidade` (agora com 3 unidades), como previsto |
| Com filtro por unidade, soma das 3 unidades × total, em 6 funções (dashboards, rankings, por tipo, situação) × 3 meses | **18/18 fecham ao centavo** |
| API: ranking de vendedores por unidade (faturamento e vendas, set e jan/2026) | soma das unidades = total; `unidade_origem` de todo vendedor = unidade filtrada |
| `GET /vendedores` | 79 ativos: **60 por lotação do RH, 19 por Omie do cadastro**; Diego Arantes (Omies Vital/Uberaba) sai como HRM |
| Período: saída em 14/02, 31/01 e entrada em 01/03 num inativo real | some e volta nos meses certos, na lista e no detalhe; restaurado ao fim |
| Validações do `PUT /vendedores` | 9 casos (válido, saída < entrada, formato, 31/02, ativo+saída, vazio, PUT parcial) respondem 200/400 como o contrato |
| Front | `tsc` e ESLint passam; **não visto no navegador** (servidor da :3000 é de outra conversa e aponta para a api-test) |

## 7. Pendências e perguntas

> **(atualizado em 07/10)** Coluna de status acrescentada; o texto das perguntas não mudou. Fonte: [[Registro-de-Decisoes-2026-10-07]] item 49.

| # | Pergunta | Quem responde | Status (07/10) |
|---|---|---|---|
| **P1** | **Quatro pessoas aparecem nos DOIS Omies, sem vínculo nos dois:** DAYANE SILVA, EDUARDO VITAL, FERNANDA LESSA e JORGE LUIZ (uma linha em Uberaba, outra em Vital). Com "usa o Omie do cadastro", cada uma conta em duas unidades. Precisam ser vinculadas a um funcionário (ou decidir a unidade de cada uma). | Nathan / RH | 🔴 Nathan (os 4 seguem sem vínculo) |
| **P2** | "AÇOS VITAL" (genérico) e os dois "- Dev" (Nathan e Robert) ficam fora dos dashboards ou entram em Vital? | Nathan | 🔴 Nathan |
| **P3** | Comissões (`comissoes_provisoria`): o seletor de unidade também vale? Pela lógica, sim; **não foi alterado**. | Nathan | 🔴 Nathan |
| **P4** | Quando o funcionário é de uma unidade e os vendedores estão em Omies de outras (21 casos, ex.: DIEGO ARANTES, funcionário da HRM), vale a lotação do RH. **Implementado assim**: confirmar. | Nathan | 🟡 mantido como implementado (lotação do RH) |
| **P5** | Quando o RH transferir alguém de unidade, o histórico dos dashboards **muda retroativamente** (a unidade é a de hoje). Aceitável? | Nathan | 🟡 mantido como implementado (histórico muda retroativamente) |
| **P6** | **Preencher `inativo_desde` dos 35 vendedores inativos.** Sem a data, continuam aparecendo nos meses em que faturaram. Ponto de partida: o último dia do último mês em que cada um faturou (os 7 de jan–mar/2026: Priscila Yumi Samezima Marc de Moura e Weresley de Moura em mar/2026; Mateus Araújo, Jéssica Souza, Agnaldo Barbosa, Thales Costa e Renan Guimarães em jan/2026). É palpite: quem confirma é vendas/RH. | Nathan / Vendas | 🔴 Nathan (os 35 inativos seguem sem `inativo_desde`) |
| **P7** | As telas que usam `fn_painel_*`, `fn_pedidos_venda_linhas` e a planilha ainda filtram pelo Omie. Mudam para a unidade do vendedor também? | Nathan | 🔴 Nathan |

**Vendedores ativos sem funcionário vinculado (19, banco local):** Omie Aços Uberaba: DAYANE SILVA, EDUARDO VITAL, FERNANDA LESSA, JORGE LUIZ, MARIA EDUARDA. Omie Aços Vital: AÇOS VITAL, DANIEL SOUZA DA SILVA, DAYANE SILVA, DIEGO FERNANDES, EDUARDO VITAL, FERNANDA LESSA, FLÁVIO COUTINHO, JAMES MADSON OLIVEIRA DE SOUZA, JORGE LUIZ, LEONARDO MARQUES DIAS, MOISES MENEZES, Nathan Lucca - Dev, PAULO SOCORRO, Robert Wilson - Dev.

## 8. Aceite

- [ ] DBA aplicou o anexo `0001` em teste e, depois, em produção.
- [ ] API aplicou o patch `0002`.
- [ ] Sem filtro, os totais dos 3 dashboards batem com os de hoje, ao centavo.
- [ ] Com filtro, cada vendedor aparece em **uma** unidade só, e a soma das unidades é igual ao total "todas".
- [ ] Preencheu `inativo_desde` dos inativos (P6) e conferiu o ranking de jan–mar/2026.
- [ ] P1 a P7 respondidas.

## 9. Depois de aplicado

1. av-hub: mergear a branch `feat/vendedor-periodo-ativo` (o front funciona com o backend antigo, sem os campos novos, mas sem o efeito).
2. Conferir no navegador, nos dois temas, o seletor de unidade, o cartão do ranking e o cadastro de vendedores com dado real.
3. Se P7 for sim, repetir a troca de filtro nas funções `fn_painel_*` etc., pelo mesmo anexo.
