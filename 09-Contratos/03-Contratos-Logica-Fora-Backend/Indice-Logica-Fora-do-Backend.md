---
tags: [contrato-logica, av-hub, indice]
origem: "av-hub docs/ (arquivos marcados ENVIAR)"
importado: 2026-09-23
---

# Índice — lógica que ainda está fora do banco (gambiarras marcadas no av-hub)

**Criado em:** 20/09/2026, no repositório `av-hub`. **Importado para este vault em 23/09/2026** —
só os contratos marcados `ENVIAR` (ainda pendentes) foram trazidos; os já resolvidos (`OK -`)
continuam só no repositório `av-hub`, pasta `docs/implementados/`.

**Regra do projeto:** filtro, busca, ordenação, paginação, agregação, regra de negócio e
**permissão/escopo** pertencem ao banco/API. O navegador só exibe; o BFF só encaminha a identidade.

Enquanto o backend não entrega, o que estiver fora do lugar fica **marcado no código** assim:

```ts
// GAMBIARRA(docs/ENVIAR - contrato-….md): o que é e como o backend resolve (código do item)
```

Para listar tudo no repositório `av-hub`: `grep -rn "GAMBIARRA(" app components lib services utils hooks`
(hoje são 57 marcas). Quando um contrato for entregue: aplicar a seção "O que muda na tela" do
contrato, apagar a marca no `av-hub` e mover o arquivo para `Realizados/03-Contratos-Logica-Fora-Backend/`.

## Novo: Compradores igual a Vendedores (29/09/2026)

- **[[28-Compradores-Criar-Excluir-Sugestao]]** — criar e excluir comprador (reabre a decisão do contrato 16) e
  sugestão de vínculo por semelhança com `min_score`, como em Vendedores. A ordenação por coluna já foi feita
  no av-hub (av-hub#106). Tem 3 perguntas em aberto para o Nathan (código que não existe no Omie, excluir o
  que ainda está no Omie, editar nome/ativo à mão).

## Conferência de 29/09/2026 (DBA: "terminei todos, menos 04 e 09; 13 desconsiderar")

Conferido ao vivo na `api-test` e no código da API (`develop` até `163b58b`):

| Contrato | Resultado |
|---|---|
| [[26-Vendas-Liberacao-Pedido]] | ✅ backend no ar e telas no menu; **falta a data de corte** (`parametros_vendas` vazia) e o L4 do `api-pcp` (Robert) |
| [[19-Compras-Pedido-Omie-Nomes]] | ✅ backend testado com pedido de teste; front em [av-hub#106](https://github.com/Acosvital/av-hub/pull/106), mergeado em 29/09 → **movido para `Realizados/`** |
| [[18-Compradores-Funcionario]] | ✅ `/funcionarios` devolve setor e unidade; última gambiarra removida em [av-hub#106](https://github.com/Acosvital/av-hub/pull/106), mergeado em 29/09 → **movido para `Realizados/`** |
| [[07-Dados-Orcamento-e-Coordenadores-no-Banco]] | ❌ **não entregue**: nenhuma rota existe — voltar ao DBA |
| [[14-Compras-Omie-Pedido-Compra]], [[19-Compras-Pedido-Pipeline-Omie]], [[23-Compras-Pipeline-Consolidado]] | não são do DBA: dependem da `omie-elt-pipeline` (branch `feat/compras-omie`, sem commits novos desde 24/09; L4, envio da OC, ainda não existe) |
| [[16-Compras-Pedido-DBA-Banco]] e [[17-Compras-Pedido-API-Backend]] (eram 17 e 18) | históricos, concluídos pelo [[13-Compras-Backend-Consolidado]] → **movidos para `Realizados/`** |
| [[04-Vagas-Fila-Decisao-no-Banco]], [[09-Paginacao-por-Pedido-Vendas-Planilha]] | DBA ainda corrigindo |
| [[13-Fornecedores-por-Produto]] | desconsiderar (pedido do Nathan) |

## Novo: módulo de Vendas (28/09/2026)

- **[[26-Vendas-Liberacao-Pedido]]** — o pedido que chega do Omie fica travado até o vendedor marcar
  se a **Qualidade acompanha desde o início** (Sim/Não); só pedido marcado vai ao MES, que faz GET
  (polling) no novo **Fluxo 4** (`/pedidos_liberados`). Tela do vendedor (*Liberar pedidos*) e do
  gerente (*Liberação da equipe*, só leitura). Banco, API e telas testados no local; SQL nos
  apêndices, patch da API em `26-anexos/`. **Telas mergeadas na `develop` em 28/09/2026
  ([av-hub#103](https://github.com/Acosvital/av-hub/pull/103))**, mas sem backend na `api-test` (rotas 404).
  Pendente: DBA/backend aplicarem (L1–L3), `api-pcp` trocar a origem da Carteira (L4). A partir deste contrato, **o contrato vive no vault** (não mais em
  `av-hub/docs/ENVIAR - *`); as marcas `GAMBIARRA(` apontam para cá.

## Novo: Compras — nomes no detalhe do pedido do Omie (28/09/2026)

- **[[19-Compras-Pedido-Omie-Nomes]]** — `GET /pedidos_compras/{id}` passa a devolver nome/CNPJ do
  fornecedor, comprador, etapa e as descrições dos catálogos (mesmo JOIN por unidade das OCs, B5).
  Só API, aditivo. Hoje a tela do pedido feito no Omie (contrato 25) mostra só códigos.

## Compras: concluídos em 28/09/2026 — movidos para `Realizados/` (renumerados 10 a 15)

Backend entregue pelo DBA na `develop` da API (até `04de3fe`, publicado na `api-test`) e front mergeado
na `develop` do av-hub ([av-hub#104](https://github.com/Acosvital/av-hub/pull/104) e
[av-hub#105](https://github.com/Acosvital/av-hub/pull/105)), testado contra a `api-test`:

| Novo nº | Contrato (antes) | O quê |
|---|---|---|
| 10 | [[10-Compras-Pendencias-Pos-Backend]] (15) | pendências pós-backend C1–C10; marcas `GAMBIARRA(` removidas |
| 11 | [[11-Compras-Cotacao-Moeda-PTAX]] (20) | cotação USD/EUR pela PTAX na OC |
| 12 | [[12-Compras-Projetos-Omie]] (21) | projetos do Omie no select da OC |
| 13 | [[13-Compras-Backend-Consolidado]] (22) | banco + API de Compras (B1–B15) |
| 14 | [[14-Compras-Vinculo-Pedido-Venda]] (24) | vínculo da OC com o pedido de venda |
| 15 | [[15-Compras-Historico-Unificado]] (25) | histórico único av-hub + Omie |

**O que ainda depende de outros contratos (não reabre estes):** produção (B0 do 13) e a pipeline
gravar catálogos, PTAX e espelho na `api-test` ([[23-Compras-Pipeline-Consolidado]]) — até lá as listas
do Omie, a cotação automática e o histórico do Omie só foram testados vazios; nomes no detalhe do pedido
do Omie ([[19-Compras-Pedido-Omie-Nomes]]). **Decisões pendentes:** quando ligar as chaves da API
`COMPRAS_VINCULO_EXIGIR_PV_EXISTENTE`, `COMPRAS_EXIGIR_PODE_APROVAR` e `COMPRAS_HISTORICO_UNIFICADO`
(o av-hub já pede `?origem=todas` sozinho); avisar que os KPIs de aprovadas sobem de uma vez quando o
histórico do Omie tiver dados.

## Prioridade: módulo de Compras

**Já entregue:** [[01-Compras-Fluxo-Completo]] (requisição → OC → régua de aprovação), backend
em 22/09/2026 (`api-acos-vital` PR #273) e front ligado em 23/09/2026. Movido para
`Realizados/03-Contratos-Logica-Fora-Backend/`. Os contratos SQL [[007-Ordens-Compra-Estruturada]]
e [[008-Requisicoes-Compra]] também já estão aplicados.

**Também concluídos (28/09/2026):** os seis da tabela acima, em `Realizados/`.

**Em aberto:**

- **[[23-Compras-Pipeline-Consolidado]]** — lista de trabalho da `omie-elt-pipeline`: L1–L10 (PTAX,
  compradores, espelho, envio da OC, catálogos, entidades HTML, testes). L1–L3 e L5–L9 já estão
  implementados na branch `feat/compras-omie` (desligados até o banco ter as tabelas). É o que falta
  para as telas de Compras terem dados na `api-test`.
- **[[19-Compras-Pedido-Omie-Nomes]]** — nomes no detalhe do pedido feito no Omie.

Contratos de detalhe:

- **[[14-Compras-Omie-Pedido-Compra]]** — de-para completo com a API do Omie: puxar os pedidos de
  compra para o espelho `pedidos_compras` e enviar a OC com `UpsertPedCompra`. Conferido campo a
  campo contra a doc oficial do Omie em 23/09/2026.
- **[[18-Compradores-Funcionario]]** — cadastro de compradores por filial, ligado ao funcionário
  (resolve o `nCodCompr` do Omie).
- ~~[[16-Compras-Pedido-DBA-Banco]], [[17-Compras-Pedido-API-Backend]] e
  [[19-Compras-Pedido-Pipeline-Omie]]~~ — **substituídos em 23/09/2026** pelos dois consolidados
  (o DBA concluiu a parte deles; o que sobrou foi para o [[13-Compras-Backend-Consolidado]], já
  realizado, e o [[23-Compras-Pipeline-Consolidado]]). Ficam como histórico.
- Contratos de API da integração com o MES, ainda em proposta:
  [[003-Requisicao-Compra-Integracao-MES]] e [[004-Referencia-OC-Integracao-MES]].
- **[[13-Fornecedores-por-Produto]]** — fornecedor por produto (relacionado a Compras/Comissão).
  Endpoint entregue e confirmado (28/09/2026), mas ainda não dá pra ligar: o simulador
  (`experimental/simulador-comissao`) roda sobre dataset legado com IDs incompatíveis com a
  tabela real `produtos` — falta a migração do módulo antes de usar o endpoint.

**Já entregue e confirmado ao vivo em `api-test` (25/09/2026):** [[02-Funcionarios-Listagem-Filtros-Ordenacao-Resumo]]
e [[03-Funcionarios-Cadastro-Organograma-Transacional]] — movidos para
`Realizados/03-Contratos-Logica-Fora-Backend/`. O front (`components/Funcionarios/*`) já foi
adaptado e testado contra o mesmo ambiente, mas **só localmente — ainda não commitado no `av-hub`**;
as marcas `GAMBIARRA(` de F1–F7 continuam no repositório até esse commit acontecer.

**Já entregues, front commitado e PRs mergeadas na `develop` do `av-hub` (28/09/2026):**

- [[04-Pedidos-Notas-Dashboards-Agregacao-no-Banco]] — Pedidos, Notas e Dashboards agregados no
  banco (PR #94). Único item pendente: P6 (ordem do fluxo de etapas) — o DBA ainda não preencheu
  `ordem_fluxo` em `etapas_faturamento` (sempre `null`); pedido formalizado em
  `docs/ENVIAR - contrato-05-pendencia-ordem-etapas-fluxo.md` no `av-hub`, que continua fora do
  `Realizados/` até isso ser resolvido.
- [[05-Permissoes-e-Escopo-no-Banco]] — identidade propagada via Bearer token, permissão/escopo
  lidos de `/me/permissoes` (PR #95). As travas do backend (`IDENTIDADE_EXIGIR_TOKEN`,
  `PERMISSOES_ROTA_MODO`, `ESCOPO_VENDEDORES_EXIGIR`) seguem desligadas por padrão — o BFF já manda
  o token, a segurança aperta sozinha quando a infra ligar os flags.
- [[06-Ordenacao-Listagens]] — `sort/order` em todas as telas de prioridade alta e baixa (PR #96).
  Permissões (agregado client-side) e Diligenciadores (paginação 100% cliente) ficaram fora de
  propósito, sem headers de tabela pra ordenar.

Movidos para `Realizados/03-Contratos-Logica-Fora-Backend/` (renumerados 04, 05, 06).

**Também já entregues e mergeadas (28/09/2026, mesmo dia — DBA avisou que 09 a 13 estavam prontos;
conferido ao vivo um a um antes de mexer no front):**

- [[07-Chave-Composta-Blacklist-Pedidos]] — `PUT`/`DELETE /blacklist_pedidos/:numero` aceitam
  `codigo_empresa` (404 se não bater), `GET` filtra por ele. PR #97.
- [[08-Itens-por-Parcela-Pedidos]] — `vw_pedido_venda_itens` ganhou `codigo_pedido_omie`/
  `sequencial` por item, aditivo. Bateu todos os critérios de aceite (pedidos 27645 e 27787). PR #98.
- [[09-Ordenacao-Sistema-Vendedores]] — `GET /vendedores?sort=nome_unidade` ordena pelo nome da
  unidade via join, não pelo código bruto. PR #99.

Renumerados 07, 08, 09 em `Realizados/03-Contratos-Logica-Fora-Backend/`.

**Da mesma leva, NÃO entregues apesar do aviso do DBA** (ver os arquivos pra detalhe do teste):

- [[09-Paginacao-por-Pedido-Vendas-Planilha]] — continua aberto, backend não implementou de
  verdade (só simulou não dar erro, mas o comportamento não mudou).
- [[13-Fornecedores-por-Produto]] — endpoint existe, mas o frontend que ele alimentaria não pode
  usá-lo ainda (dataset legado com IDs incompatíveis).

## Contratos abertos criados no ciclo de 20/09/2026

| Contrato | Cobre | Itens |
|---|---|---|
| [[04-Vagas-Fila-Decisao-no-Banco]] | Solicitações de vagas: filtros/ordem/resumo, custo gerado, decisão com `pode_aprovar` e histórico. Backend pronto e confirmado (3 de 4 itens do Aceite); falta ligar `VAGAS_TRAVAS_DECISAO` (depende de conceder `pode_aprovar` e o front usar `/decisao`) e adaptar `components/Vagas/*` | V1–V8 |
| [[07-Dados-Orcamento-e-Coordenadores-no-Banco]] | Orçamento e coordenadores fora do repositório, com filtro/paginação/ordem no servidor | O1–O5, C1–C3 |

Pedidos/Notas/Dashboards e Permissões/Escopo (P1–P8/N1–N3/D1–D3 e S1–S11) já saíram desta lista —
ver "Já entregues" acima ([[04-Pedidos-Notas-Dashboards-Agregacao-no-Banco]],
[[05-Permissoes-e-Escopo-no-Banco]]).

## Contratos anteriores que continuam abertos e se relacionam

- [[09-Paginacao-por-Pedido-Vendas-Planilha]] — paginar por pedido. Backend ainda não entregou de
  verdade (ver status no arquivo, 28/09/2026).

## Onde estão as marcas, por assunto (no repositório `av-hub`)

| Assunto | Arquivos com `GAMBIARRA(` |
|---|---|
| Funcionários (lista, resumo, regras) | `components/Funcionarios/{useFuncionarios,helpers,acoes,FuncionarioPainel}` |
| Funcionários (organograma) | `services/rh/organogramaNodes.ts` |
| Funcionários (BFF) | `app/api/funcionarios/route.ts`, `app/api/funcionarios/[id]/route.ts` |
| Vagas | `components/Vagas/{useVagas,helpers,acoes,VagaPainel,VagasLista}` |
| Pedidos | `components/Pedidos/{usePedidos,PedidoDetalhe}`, `utils/etapasFluxo.ts` |
| Notas | `components/Notas/{useNotas,helpers}` |
| Dashboards | `components/Painel/{usePainelPcp,PainelPartes}`, `lib/api/{meuDashboardDomain,dashboardEquipeDomain}.ts` |
| Permissão e escopo | `lib/api/{requirePermission,escopoUnidade,portalPcp}.ts`, `hooks/usePermission.ts`, `app/(protected)/page.tsx`, `app/api/auth/[...nextauth]/route.ts` |
| Segurança de borda | `lib/auth/loginRateLimiter.ts`, `lib/s3/fotos.ts` |
| Dados em arquivo | `lib/orcamento/dados.ts`, `lib/comissoes/coordenadores.ts`, `app/(protected)/dashboards/dash-comissoes/page.tsx` |
| Compras | nenhuma depois do [av-hub#106](https://github.com/Acosvital/av-hub/pull/106) (27 e 16). As do [[10-Compras-Pendencias-Pos-Backend]] saíram em 28/09/2026 |

## Fora deste ciclo (levantar antes de mexer)

Telas mais antigas (Cadastros, Comissões, Vendas, RH restante, Organograma) **não foram inventariadas**
linha a linha: elas seguem o padrão antigo (`SearchFilterBar` + paginação do servidor onde a API
suporta, ordenação ausente — ver [[06-Ordenacao-Listagens]]). Ao migrar cada uma para o padrão
novo, aplicar a mesma regra e marcar o que sobrar.

## Ver também
- [[Indice-Contratos]] — índice geral dos contratos SQL/API deste vault.
