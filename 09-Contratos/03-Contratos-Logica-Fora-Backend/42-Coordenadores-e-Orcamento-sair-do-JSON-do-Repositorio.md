---
tags: [contrato-logica, contrato-api, comissoes, orcamento, av-hub]
criado: 2026-10-07
atualizado: 2026-10-07
status: proposta
---

# Contrato 42 — Coordenadores e Orçamento: sair do JSON do repositório

> Status: **proposta** (verificado em 07/10/2026 por leitura de código do av-hub e da `api-acos-vital` `main` = `a6ab058`/`fdafb35`; produção só pelo dump de 07/10, [[Auditoria-Dump-Producao-2026-10-07]]). Fonte das decisões: [[Registro-de-Decisoes-2026-10-07]] (itens 39 e 40). Este contrato **substitui, para os pontos abaixo**, o [[07-Dados-Orcamento-e-Coordenadores-no-Banco]] (histórico).

**Legenda:** ✅ decidido pelo Nathan · 🟡 inferência minha · 🔴 pendente, com dono.

## 1. Status

- **Coordenadores (C1 a C3): volta ao escopo.** 🟡 Inferência da instrução do Nathan em 07/10 ("corrija tudo"): o 07 foi "desconsiderado" em 01/10, e isso muda **só para coordenadores**. Ele não disse isso com essas palavras sobre este contrato; se não era a intenção, 🔴 Nathan contesta.
- **Orçamento (O1 e O2): não migrar o JSON para a API antiga.** ✅ O orçamento é desenvolvido por fora, no módulo Comercial & Suprimentos (item 39). 🟡 Proposta: **remover** a tela e o código legado do av-hub quando o módulo novo a substituir. Até lá, as duas marcas `GAMBIARRA(` ficam apontando para este contrato.
- O contrato 13 (Fornecedores por Produto) segue ✅ desconsiderado (item 40); não é reaberto aqui, mas ver o risco R2.

## 2. Destinatários

| Quem | O que faz |
|---|---|
| **Gustavo** (API/DBA) | Confirma o que a API já entrega (§4), responde as perguntas 🔴 dele (§10) e, se aceitar, ajusta o que faltar para o front consumir. |
| **Nathan** (front av-hub) | Executa o passo a passo do §6 (coordenadores) e decide a data de corte do orçamento (§5.2). |

## 3. Problema (as 4 marcas do front)

Repositório do av-hub, código lido por inteiro em 07/10/2026. Todas as marcas citam o doc `docs/ENVIAR - contrato-dados-orcamento-e-coordenadores-no-banco.md`.

| # | Arquivo:linha | O que faz hoje |
|---|---|---|
| **O1** | `lib/orcamento/dados.ts:60` (`buscarFornecedores`) | Autocomplete de fornecedor: tira acento do termo (80 caracteres), filtra `nome_fantasia` em memória e corta nos **primeiros 20** (`LIMITE_BUSCA_FORNECEDOR`), sobre `data/fornecedores.json` (4,4 MB). Usada por `app/api/orcamento/fornecedores/route.ts`. |
| **O2** | `lib/orcamento/dados.ts:75` (`historicoPrecos`) | Filtra `historicoPrecos.json` por `id_produto` e `id_parceiro` e **ordena por `data_cotacao`** em memória. Usada por `app/api/orcamento/historico-precos/route.ts`, que devolve `total`/`totalPages` calculados em cima do array inteiro. |
| **C1** | `lib/comissoes/coordenadores.ts:10` (`coordenadores()`) | Devolve `lib/comissoes/coordenadores.json` (2,2 KB): 5 em `coordenadores` e 1 em `excessoes`, cada um com `AjudaCusto` e `porcentagemComissao`. Servido por `app/api/dashboard/comissoes/coordenadores/route.ts`. Os valores de remuneração **não são copiados para este contrato**. |
| **C2/C3** | `app/(protected)/dashboards/dash-comissoes/page.tsx:26` (`mapCoordenadorToRow`) | No navegador: `comissao = porcentagemComissao / 100 × faturamentoTotal` (o faturamento vem de `getFaturamentoMensal`, com `mes` e `ano`); `total = AjudaCusto + comissao − (valorBloqueado ?? 0)`; ordena por `total` e numera o `rank`. As exceções (`excessoes`) são somadas ao ranking dos vendedores; os KPI "Comissão Gerência", "Ajuda de Custo" e "Comissão Vendedores" são somados aqui. |

**JSONs existentes (`lib/orcamento/data/`):** `fornecedores.json` (4,4 MB), `historicoPrecos.json` (270 KB), `produtos.json` (217 KB), `vinculos.json` (78 KB), `categorias.json` e `familias.json` (< 2 KB), mais `lib/comissoes/coordenadores.json`. Todos estão no git.

**Quem consome além das telas de orçamento** (achado de `grep`, ver R2): `app/(protected)/experimental/simulador-comissao/page.tsx` (`getProdutos`, `getTodosFornecedores`) e `app/(protected)/cadastros/auxiliares/produtos/page.tsx` (`getFamilias`).

## 4. Estado da API (o que já existe)

### 4.1 Coordenadores

| Item | Onde (`api-acos-vital/src/schemas/`) | Estado |
|---|---|---|
| `GET /dashboard/comissoes?ano_mes=AAAA-MM&is_track_record=&incluir_pedidos=` | `core_comissionamento/functions/fn_dashboard_comissoes/fn_dashboard_comissoes.route.js`; montada em `core_comissionamento/index.js:58` | **Existe.** Chama `core_comissionamento.fn_dashboard_comissoes($1,$2,$3,$4)` com `p_aplicar_bloqueio` **sempre `false`** (decisão de 06/10, [[38-Regras-Sem-Chave-de-Ambiente]] §5). Erro `400` se `ano_mes` não for `AAAA-MM`; `500` com a mensagem "exige a migration 007" se a função não existir. |
| Resposta | `fn_dashboard_comissoes.swagger.json` | `faturamento_total` (de `fn_dashboard_mensal_faturamento`, todas as unidades), `resumo` com os 4 cartões e `total_geral`, `vendedores[]` (relatório provisório **mais** as exceções, já ordenado), `coordenadores[]` (gerência, ordenado), `provisoria.disponivel`. Cada linha: `posicao`, `nome`, `tipo` (`vendedor`/`excecao`/`gerencia`), `faturado`, `a_faturar`, `ajuda_custo`, `percentual_comissao`, `comissao`, `bloqueado`, `total`. Desempate: `ordem_desempate` do coordenador, depois nome. |
| Tabela de parâmetros | `core_comissionamento.comissao_coordenadores` (citada no swagger e no comentário da rota) | **Existe em produção** pelo dump de 07/10: 6 linhas (5 `gerencia` + 1 `excecao`, origem `carga_json_2026_10`) mais 6 de histórico; **nenhum com `id_funcionario`**; `GET /dashboard/comissoes` respondeu 200 em 02/10. |
| DDL e corpo da função | — | **Não está no repositório da API** (não há pasta de SQL; [[AV-Hub-API-Estado-Atual]]). Os nomes de coluna da tabela **não foram verificados**; o swagger só fala em pessoa, ajuda de custo, percentual, tipo, vigência e `ordem_desempate`. |
| Permissão | swagger: `dash-comissoes` em `auth.rotas_telas` (migration 007) | Não conferido o mapeamento dessa rota no dump. |

### 4.2 Orçamento

`orcamento.route.js` (`core_compras/aggregates/orcamento/`, montada em `core_compras/index.js:37` como `/orcamento`) **existe** e cobre O1 e O2 no servidor:

| Marca | Rota da API | Parâmetros |
|---|---|---|
| O1 | `GET /orcamento/fornecedores` | `q` (sem acento, `strpos` em `texto_busca`), `estado`, `cidade`, `vinculado`, `resumido=true` (devolve só `codigo_parceiro_omie, nome_fantasia, email, telefone, estado`, os mesmos 5 campos do `buscarFornecedores`), `sort`, `order`, `page`, `limit` (padrão 20, máximo 100). |
| O2 | `GET /orcamento/cotacoes` | `produto` e/ou `fornecedor` (um dos dois é obrigatório, senão `400`), `data_inicio`, `data_fim`, `sort`/`order` (padrão `data_cotacao` ASC), `limit` padrão 100, máximo 500. |

Existem também `/orcamento/{produtos,vinculos,categorias,familias}`. Os nomes de campo seguem os do JSON antigo. Em produção (dump de 07/10): `orc_*` com 13.896 linhas carregadas em 02/10 (`orc_fornecedores` 10.524, `orc_cotacoes` 2.697, `orc_produtos` 400, `orc_vinculos` 234, `orc_familias` 25, `orc_categorias` 16). **Ou seja, os dados do JSON já foram copiados para a API antiga.** Não conferido: se o JSON no repo é idêntico ao que foi carregado.

### 4.3 O que falta para o front consumir (coordenadores)

1. **Rota no BFF.** O front chama hoje `/comissoes_provisoria` (`app/api/dashboard/comissoes/comissoes-provisorias/route.ts`) e a rota do JSON. Nenhuma chama `/dashboard/comissoes`. Falta criar o proxy (🟡 inferência: no mesmo molde, `requirePermission('dash-comissoes','pode_visualizar')` + `headersComIdentidade()`).
2. **Pedidos por vendedor.** O modal de detalhes (`CommissionDetailsModal`) lê `vendor.pedidos`. A API só devolve `pedidos[]` com `incluir_pedidos=true`, que o swagger chama de pesado e diz que "a página não usa". Isso diverge do código: o modal usa. Ver P-C2.
3. **Nomes de campo diferentes** (`nome`/`ajuda_custo`/`faturado`... contra `vendedor`/`AjudaCusto`/`valorTotalFaturado`...): precisa de um adaptador no front.
4. **Lacuna não resolvida:** o que o `/comissoes_provisoria` entrega e a função não repete (`page`, `limit` e `historico`; a página hoje só passa `ano_mes`) fica fora do uso atual. Sem ação.

## 5. Proposta

### 5.1 Coordenadores (C1 a C3)

A API cobre o que o front precisa, com a ressalva do item 4.3.2. **Nenhum DDL novo é proposto**: a tabela, a função e a rota existem. 🟡 A mudança é só no front:

1. O dashboard passa a consumir `GET /dashboard/comissoes?ano_mes=AAAA-MM` e usa `resumo`, `vendedores[]` e `coordenadores[]` como vêm (posição, total e cartões já calculados).
2. Sai do front: `mapCoordenadorToRow`, o `sort`, o `rank`, a soma dos KPI, `getCoordenadores`, `getFaturamentoMensal` (nesta página), `lib/comissoes/coordenadores.{ts,json}` e a rota `/api/dashboard/comissoes/coordenadores`.
3. Manutenção dos parâmetros (percentual, ajuda de custo, vigência) passa a ser no banco. **Não há tela nem rota de escrita** para `comissao_coordenadores` no código lido; até existir, quem altera é o DBA (🔴 Gustavo, P4).

### 5.2 Orçamento (O1 e O2)

- **Não** trocar `dados.ts` para `/orcamento/*` da API antiga. ✅ (decisão 39).
- 🟡 Remover do av-hub, quando o módulo novo substituir a tela antiga:
  - **Telas:** `app/(protected)/orcamento/{categorias,fornecedores,historico-produtos,sem-cadastro,vinculos}/` (page, styles e `categorias/types.ts`).
  - **Rotas BFF:** `app/api/orcamento/{categorias,familias,fornecedores,historico-precos,produtos,todos-fornecedores,vinculos}/route.ts`.
  - **Lib:** `lib/orcamento/dados.ts` e `lib/orcamento/data/*.json` (6 arquivos).
  - **Services:** `services/orcamento/*` (7 arquivos) **exceto** o que ainda tiver consumidor (ver abaixo).
  - **Tipos:** `lib/domain/orcamento-{fornecedores,historico-produtos,vinculos}.ts`.
  - **Menu e permissão:** as 5 telas (`categorias`, `fornecedores`, `historico-produtos`, `sem-cadastro`, `vinculos`) e os grupos/ícones `orcamento` (`groupMap.ts`, `iconMap.tsx`). 🟡 O menu parece vir de `auth.telas` (banco); não conferido. Mudança do DBA.
- **Não pode sair junto sem trocar o consumidor:** `experimental/simulador-comissao` usa `getProdutos` e `getTodosFornecedores`; `cadastros/auxiliares/produtos` usa `getFamilias`. Antes de apagar `services/orcamento/{historicoProdutos,todosFornecedores,familias}.ts` e as rotas correspondentes, cada um precisa de outra fonte (🔴 Nathan, P3).
- O JSON sai do **histórico do git** só se o Nathan quiser (reescrita de histórico, risco de repositório; 🔴 Nathan, P5). A remoção do arquivo no HEAD não limpa o histórico.
- Até a remoção: as marcas O1 e O2 permanecem, **sem mudar o comentário** além de apontar para "contrato 42" (edição de código do Nathan; este contrato não edita o front).

## 6. Passo a passo do front (coordenadores)

1. Confirmar com o Gustavo o item 4.1 (colunas, `dash-comissoes` mapeada) e P-C2.
2. Criar `app/api/dashboard/comissoes/route.ts` (proxy de `GET /dashboard/comissoes`; só repassa `ano_mes`; permissão `dash-comissoes`).
3. Criar `getDashboardComissoes({ ano_mes })` em `services/dashboards/dashboardComissoes.ts` e o tipo da resposta em `lib/domain/dashboards-dash-comissoes.ts`.
4. Em `page.tsx`: trocar o `Promise.all` de 3 chamadas por 1; montar `vendors`, `managers`, `kpiCards` e `donutData` direto de `vendedores[]`, `coordenadores[]` e `resumo`, com um adaptador de nomes; remover `mapCoordenadorToRow` e a marca C2/C3.
5. Pedidos do modal: se a API devolver `pedidos` só com `incluir_pedidos=true`, **buscar sob demanda** ao abrir o modal (🟡 proposta) ou manter `/comissoes_provisoria` só para o modal. Decisão com o Gustavo (P-C2).
6. Apagar `lib/comissoes/coordenadores.{ts,json}`, a rota `.../coordenadores/route.ts`, `getCoordenadores` e o tipo `CoordenadoresProps` se ficar sem uso; removida a marca C1.
7. Testar (§8) em `develop` com `api-test`.

## 7. Ordem de subida

1. API/banco: já no ar (02/10); só o Gustavo confirma o §4 e responde as perguntas.
2. Front dos coordenadores (passos 2 a 6) na `develop` do av-hub, conferido na `api-test`.
3. `main` do av-hub.
4. Só depois, apagar `lib/comissoes/coordenadores.*` (um commit à parte, para o rollback ser simples).
5. Orçamento: **sem prazo**, segue a data de corte do módulo novo (P1). Nada de orçamento sobe agora.

## 8. Testes de aceite

**Coordenadores.** Escolher os 6 nomes (5 gerência + 1 exceção) e 2 meses (um fechado, um corrente). Para cada mês, **antes** de mexer no front, guardar o que o navegador calcula hoje (`ajudaCusto`, `comissao`, `total`, `rank` do ranking de gerência e a linha da exceção no ranking de vendedores, mais os 4 cartões) e comparar com `GET /dashboard/comissoes?ano_mes=` da mesma `api-test`:

| Conferência | Esperado |
|---|---|
| `comissao` de cada coordenador | igual a `percentual/100 × faturamento_total` e igual ao valor do navegador (tolerância de centavos) |
| `faturamento_total` da API × `faturamento_total` de `getFaturamentoMensal` (mes/ano) | igual 🟡 (a API usa `fn_dashboard_mensal_faturamento`, todas as unidades; o front envia só `mes` e `ano`; conferir se há outro filtro de empresa) |
| Ordem e `posicao` | igual ao `rank` do navegador; empate: pelo `ordem_desempate` (🔴 P4: os `AjudaCusto` do JSON têm casas decimais a mais que parecem desempate; inferência) |
| Exceção | aparece em `vendedores[]` com `tipo = excecao`, sem aparecer em `coordenadores[]` |
| `bloqueado` dos coordenadores | 0 e `bloqueio_coordenadores_aplicado: false` |
| 4 cartões e `total_geral` | iguais aos do navegador |
| Modal de detalhes de um vendedor | continua mostrando os pedidos com NF |
| Sem o JSON | `grep` de `coordenadores.json` no repo não acha nada; o dashboard abre |

**Orçamento (na remoção).** `grep` por `lib/orcamento`, `api/orcamento` e `services/orcamento` não acha nada; o simulador e o cadastro de produtos abrem; `npm run build` passa.

## 9. Rollback

- **Coordenadores:** reverter o commit do front restaura a rota do JSON (o arquivo só é apagado em commit separado, §7.4). Os parâmetros no banco não são alterados por este contrato.
- **Orçamento:** nada muda até a remoção; reverter o commit da remoção devolve telas, rotas e JSON (o histórico do git preserva).

## 10. Riscos

| # | Risco |
|---|---|
| R1 | O valor do navegador pode **não bater** com o da API (percentual, vigência, base de faturamento). Por isso a comparação do §8 vem **antes** de apagar o JSON. |
| R2 | Remover `lib/orcamento` quebra `simulador-comissao` e `cadastros/auxiliares/produtos` (dependências fora das telas de orçamento). O contrato 13 foi desconsiderado, mas o simulador ainda usa o dataset estático. |
| R3 | Dados do JSON de orçamento podem ter edições locais que não estão em `orc_*` (carga de 02/10) nem no módulo novo. Não verificado. |
| R4 | Dado de remuneração de pessoas nominais e dados de fornecedor (CNPJ, e-mail, telefone) **continuam no git e no histórico** até alguém decidir limpar. |
| R5 | O DDL de `comissao_coordenadores` e o corpo de `fn_dashboard_comissoes` não estão versionados: sem eles, ninguém consegue reconstruir o banco nem auditar a fórmula. |
| R6 | A API antiga de orçamento fica sem consumidor depois da remoção. Alternativa 🟡 (se a data de corte for distante): fazer o front consumir `/orcamento/*` já existente. Foge da proposta do Nathan; só se ele pedir. |

## 11. Perguntas em aberto

| # | Pergunta | Dono |
|---|---|---|
| P1 | **Data de corte** da tela antiga de orçamento no av-hub. | 🔴 Nathan |
| P2 | Há dado nos JSON que precise migrar para o módulo novo (Comercial & Suprimentos)? O módulo tem `Fornecedor` e `Produto` próprios em `core_comercial`; se o módulo novo reaproveitar `orc_*` ou carregar de outra fonte, não está no vault. (A API antiga já tem os mesmos dados em `orc_*`.) | 🔴 Nathan (com o Pablo, que atua no Comercial) |
| P3 | Quem fornece fornecedores/produtos/famílias ao simulador de comissão e ao cadastro de produtos depois da remoção? | 🔴 Nathan |
| P4 | Mostrar a DDL de `comissao_coordenadores` (colunas, vigência, `ordem_desempate`) e quem edita os parâmetros (tela, rota de escrita ou DBA). | 🔴 Gustavo |
| P-C2 | A página usa `vendedores[].pedidos` no modal; o swagger diz que não. `incluir_pedidos=true` é aceitável por mês, ou o front busca sob demanda? Mapear `GET /dashboard/comissoes` em `auth.rotas_telas` para `dash-comissoes`. | 🔴 Gustavo |
| P5 | Limpar o histórico do git (JSON de fornecedores e de coordenadores), ou só remover do HEAD? | 🔴 Nathan |
| P6 | Confirmar que "corrija tudo" inclui os coordenadores (🟡 inferência deste contrato). | 🔴 Nathan |

## Ver também
- [[07-Dados-Orcamento-e-Coordenadores-no-Banco]] — contrato original (histórico).
- [[38-Regras-Sem-Chave-de-Ambiente]] §5 — bloqueio dos coordenadores.
- [[AV-Hub-Comercial-Suprimentos]] — módulo novo (`api-comercial`).
- [[Auditoria-Dump-Producao-2026-10-07]] — dados em produção.
