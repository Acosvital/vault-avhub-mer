---
tags: [contrato-logica, av-hub, indice]
origem: "av-hub docs/ (arquivos marcados ENVIAR)"
importado: 2026-09-23
atualizado: 2026-10-07
---

# Índice — lógica que ainda está fora do banco (gambiarras marcadas no av-hub)

> Status: decidido | no código | em produção (verificado em 07/10/2026 só pelo dump). Decisões desta rodada: [[Registro-de-Decisoes-2026-10-07]]. Resumo: orçamento (07) desenvolvido por fora, contrato a reescrever; 13 desconsiderado; envio da OC fixo no código, sem `SYNC_ENVIO_OC` nem `ENVIO_OC_DRY_RUN`, risco aceito; `PERMISSOES_ROTA_MODO` fixo em `exigir`.

> **Atualização de 07/10/2026 — conferido no código (`main` = `develop` da `api-acos-vital`, `a6ab058`/`fdafb35`; pipeline `master` `d2886bf`).** Produção não foi conferida; "implementada-no-codigo" = o código comprova, **falta conferir em produção/`api-test`**. Mudanças em relação aos blocos abaixo (escritos entre 23/09 e 07/10, mantidos como histórico):
> - **07** (orçamento e coordenadores): ✅ decidido em 07/10: o orçamento foi **desenvolvido por fora, no módulo Comercial & Suprimentos**; a API `90bdb33` (01/10, #275: `/orcamento/*` e `GET /dashboard/comissoes`) existe; o 38 implementou o orçamento embora o vault dissesse "desconsiderado". O contrato 07 (e o 38) **precisam ser reescritos**. Frontmatter do 07: `implementada-no-codigo`.
> - **13**: ✅ contrato **desconsiderado** (07/10). Histórico: `GET /produtos/:id/fornecedores` existe (`31e26a6`, 25/09, #275); o simulador do av-hub segue sem ligar.
> - **23**: implementado no código da pipeline (L4 mergeado em 05/10, `3233acf`; flags `SYNC_*` removidas em 06/10; inativar catálogos feito; L10.4 respondido; nunca manda parcelas). **Envio da OC fixo no código, direto ao Omie, sem `SYNC_ENVIO_OC` nem `ENVIO_OC_DRY_RUN`; L10.1, L10.6 (FOB) e L10.7 (b)–(d) são risco aceito** (✅ 07/10). **19-Pipeline**: histórico, substituído pelo 23, P5 implementado.
> - **38**: saíram **13** chaves (não 11): as 11 + `BLACKLIST_PEDIDOS_CHAVE_LEGADA` + `COMISSOES_COORDENADORES_BLOQUEIO`; também `COMPRAS_HISTORICO_UNIFICADO` (do 36). Sobram exatamente as 6 do §3. Logo, `COMPRAS_VINCULO_EXIGIR_PV_EXISTENTE`, `COMPRAS_EXIGIR_PODE_APROVAR`, `COMPRAS_HISTORICO_UNIFICADO` e `VAGAS_TRAVAS_DECISAO` **não existem mais como chave** (regras fixas).
> - **26**: L6 (chave própria do MES) segue aberto: `MES_INTEGRACAO_KEYS` só abre o PUT do 34. **34 e 35**: o MES chama o PUT (`e7ce2c9`, 02/10) e lê os eventos (`41bf4a6`, 05/10), só na `develop` do `api-pcp`. **39**: API em `a6ab058` (#280), front av-hub#155 na `develop` do av-hub desde 07/10 10:01.
> - Ver o quadro completo em [[Indice-Contratos]] (Conferência de 07/10/2026).

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
(🟡 **recontado em 07/10: 12 marcas em código**, **11** depois de apagar o código morto do contrato 43, no front (`Desktop\TI\NATHAN\00 - HUB`, branch `fix/gambiarras-bff`); os 57 de 23/09, os 24 do índice antigo e os 14 do catálogo de bugs são histórico; ver o item 58 do [[Registro-de-Decisoes-2026-10-07]]). Quando um contrato for entregue: aplicar a seção "O que muda na tela" do
contrato, apagar a marca no `av-hub` e mover o arquivo para `Realizados/03-Contratos-Logica-Fora-Backend/`.

## Novo: contratos 40 a 44 (07/10/2026) — propostas para as marcas restantes

Nenhum está entregue. Detalhe de cada um em [[Indice-Contratos]] e nos itens 74 e 75 do [[Registro-de-Decisoes-2026-10-07]].

- **[[40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]]** — marcas de `lib/api/{portalPcp,pedidosVenda,liberacaoPedidos}.ts`, `app/api/liberar-pedidos/.../route.ts` e `app/api/auth/[...nextauth]/route.ts` (S1 a S3, L5). A API já aplica o escopo pelo token, desligado; o front só tira o escopo do BFF **depois** da API ligada em produção.
- **[[41-Login-Rate-Limit-no-Backend]]** — marca de `lib/auth/loginRateLimiter.ts:24` (S9). O front só remove o limiter depois de a API ligada em produção.
- **[[42-Coordenadores-e-Orcamento-sair-do-JSON-do-Repositorio]]** — marcas de `lib/orcamento/dados.ts` (O1, O2), `lib/comissoes/coordenadores.ts` (C1) e `dash-comissoes/page.tsx` (C2/C3).
- **[[43-Ordem-das-Etapas-de-Faturamento-no-Cadastro]]** — marca de `utils/etapasFluxo.ts:10` (P6). O único consumidor (`services/portalGerente/etapasEmpresa.ts`) não tem chamador: os dois arquivos foram apagados em 07/10 e a marca saiu com eles (sem commit).
- **[[44-Upload-de-Fotos-Politica-de-Bucket]]** — marca de `lib/s3/fotos.ts:19` (S10). A validação do BFF é defesa legítima e fica; reclassificar: 🔴 Nathan.


## Fila de vínculo dos vendedores (06/10/2026) — ✅ entregue 07/10

- **[[39-Vendedores-Fila-de-Vinculo]]** (**entregue e conferido em produção em 07/10/2026**, agora em `Realizados/`; destrava av-hub#155) — `GET /vendedores?sem_vinculo=true`, `nome_funcionario`/`nome_usuario`
  na lista e setor/unidade/desligado nos candidatos da sugestão, para a tela nova de Vendedores (lista e
  vínculo lado a lado, como Compradores). Patch em `39-anexos/`, testado na API local. A tela nova só sobe
  depois da API. **(atualizado em 07/10)** API no código em `a6ab058` (develop 06/10 16:05; `main` pelo #280, `fdafb35`); front av-hub#155 mergeado na `develop` do av-hub em 07/10 10:01 (só `develop`).

## Novo: regras sem chave de ambiente (06/10/2026)

- **[[38-Regras-Sem-Chave-de-Ambiente]]** — decisão do Nathan: regra decidida é fixa no código, sem
  variável. 11 chaves da API passam a valer sempre e `BLACKLIST_PEDIDOS_CHAVE_LEGADA` sai (**atualizado em 07/10:** no diff saíram 13 chaves, as 11 + `BLACKLIST_PEDIDOS_CHAVE_LEGADA` + `COMISSOES_COORDENADORES_BLOQUEIO`; `COMPRAS_HISTORICO_UNIFICADO` também) (patch em
  `38-anexos/`, depois do patch do contrato 36). Ordem de subida no §4 (perfil Gerência de Compras e
  compradores vinculados ANTES da API). Segurança e paginação por pedido: fixar depois do pré-requisito.
  Bloqueio de comissão dos coordenadores: **não aplica** (06/10), a chave sai (patch 0002; vinha do 07).
  Pipeline já limpa (PR #2). **✅ Aplicado pelo DBA em 06/10 (`c8f2f5e`) → movido para `Realizados/`.**

## Novo: variação nas rotas mensais do dashboard (05/10/2026)

- **[[37-Dashboard-Mensal-Variacao]]** — `variacao_pct` e `variacao_quantidade_pct` em
  `/dashboard_mensal_{vendas,faturamento}` (consolidado e por unidade), para o Dashboard da Equipe parar de
  calcular a variação no BFF (participação por empresa, av-hub#131). Registra também a diferença de 1 pedido
  entre a classificação (855) e o total (854) em set/2026. **✅ Em produção em 06/10 → movido para `Realizados/`.**

## Novo: produto obrigatório e comprador da OC (05/10/2026)

- **[[36-Compras-Produto-Obrigatorio-e-Comprador-da-OC]]** — o Omie recusa item sem produto cadastrado
  (teste real de 05/10): o item da OC passa a ter produto do cadastro da unidade (P1). O comprador da OC
  não se troca no av-hub; se trocarem no Omie, o espelho atualiza a OC e grava o histórico (P2–P5).
  Histórico unificado sempre ligado (P6). Front pronto na branch `feat/compras-produto-comprador-oc`.
  **✅ P1 sem chave aplicado pelo DBA em 06/10 (`c8f2f5e`) → movido para `Realizados/`.**

## Pipeline atualizada (05/10/2026)

- **[[23-Compras-Pipeline-Consolidado]]** (**implementado no código; movido para `Realizados/` em 09/10/2026**) — L4 (envio da OC ao Omie e exclusão ao cancelar)
  implementado na `feat/compras-omie` (`66f9a2e`, sem push), desligado e em dry run por padrão.
  **(atualizado em 07/10)** Mergeado em 05/10 (PR #1, `3233acf`); as flags `SYNC_*` saíram em 06/10 (PR #2). ✅ Decidido em 07/10: o envio fica **fixo no código, direto ao Omie, sem `SYNC_ENVIO_OC` nem `ENVIO_OC_DRY_RUN`** (o Nathan rodou cerca de 4 testes reais; **feito em 08/10, pipeline PR #3**); o teste real de 05/10 está registrado no contrato; L10.1, L10.6 e L10.7 (b)–(d) são **risco aceito**.
  Testado no local só contra um Omie falso; falta o L10 numa conta Omie de teste. No mesmo commit:
  IE/dados fiscais dos parceiros ([[30-Compras-Pedido-Omie-PDF-Completo]] §2.2) e as datas do
  comprador protegidas ([[28-Compradores-Criar-Excluir-Sugestao]] R4).

## Novo: notas fiscais manuais só para o admin (29/09/2026)

- **[[29-Notas-Fiscais-Manuais-So-Admin]]** — a tela Cadastros › Auxiliares › Notas fiscais manuais (av-hub) usa a tela
  `notas-fiscais-manuais` (pode_criar/editar/deletar só no perfil admin; o DBA está criando). Pede ao backend
  conferir a permissão pelo token no `POST /nota_fiscal_saida/manual` (hoje basta a x-api-key), tirar `manual`
  dos campos editáveis e devolver quem cadastrou/alterou e o número do pedido.

## Novo: Compradores igual a Vendedores (29/09/2026)

- **[[28-Compradores-Criar-Excluir-Sugestao]]** — criar e excluir comprador (reabre a decisão do contrato 16) e
  sugestão de vínculo por semelhança com `min_score`, como em Vendedores. A ordenação por coluna já foi feita
  no av-hub (av-hub#106). Tem 3 perguntas em aberto para o Nathan (código que não existe no Omie, excluir o
  que ainda está no Omie, editar nome/ativo à mão).

## Conferência de 01/10/2026 (DBA: "concluí 26, 28, 29, 30, 31, 32, 33 e 34")

| Contrato | Resultado na `api-test` | Onde ficou |
|---|---|---|
| [[26-Vendas-Liberacao-Pedido]] | ✅ data de corte preenchida (28/07/2026), liberação funcionando (741 pendentes, 16 liberados, 3 importados) | `Realizados/` |
| [[28-Compradores-Criar-Excluir-Sugestao]] | ✅ **entregue em 02/10/2026** | `Realizados/` |
| [[29-Notas-Fiscais-Manuais-So-Admin]] | ✅ **entregue em 02/10/2026** | `Realizados/` |
| [[30-Compras-Pedido-Omie-PDF-Completo]] | ✅ campos no código da `develop`; sem dado para testar | `Realizados/` (falta o PDF do av-hub mostrar) |
| [[31-Compras-Dashboard]] | ✅ rota responde (valores zerados, sem pedidos) | `Realizados/` |
| [[32-Compras-CCP-Acompanhamento-OC]] | ✅ fila, detalhe e contatos respondem e validam | `Realizados/` |
| [[33-Dashboards-Unidade-de-Origem-do-Vendedor]] | ✅ `/vendedores` com `ativo_desde`, `inativo_desde`, `unidade_origem` (código em `main`, `5231219`, #275) | `Realizados/` (front sem push em 01/10; não reconferido em 07/10) |
| [[34-Requisicoes-MES-Empurra-para-o-Hub]] | ✅ **entregue em 02/10/2026**: SQL aplicado, lista de requisições voltou (200) com as colunas novas. (07/10: o MES já chama o PUT, `e7ce2c9`) | `Realizados/` |

## Conferência de 29/09/2026 (DBA: "terminei todos, menos 04 e 09; 13 desconsiderar")

Conferido ao vivo na `api-test` e no código da API (`develop` até `163b58b`):

| Contrato | Resultado |
|---|---|
| [[26-Vendas-Liberacao-Pedido]] | ✅ backend no ar e telas no menu; **falta a data de corte** (`parametros_vendas` vazia) e o L4 do `api-pcp` (Robert) |
| [[19-Compras-Pedido-Omie-Nomes]] | ✅ backend testado com pedido de teste; front em [av-hub#106](https://github.com/Acosvital/av-hub/pull/106), mergeado em 29/09 → **movido para `Realizados/`** |
| [[18-Compradores-Funcionario]] | ✅ `/funcionarios` devolve setor e unidade; última gambiarra removida em [av-hub#106](https://github.com/Acosvital/av-hub/pull/106), mergeado em 29/09 → **movido para `Realizados/`** |
| [[07-Dados-Orcamento-e-Coordenadores-no-Banco]] | ⛔ **desconsiderado em 01/10/2026** (decisão do Nathan); antes: não entregue. **(atualizado em 07/10)** o código existe em `main` (`90bdb33`); ✅ 07/10: orçamento desenvolvido por fora (Comercial & Suprimentos), contrato a reescrever; o "desconsiderado" de 01/10 está superado |
| [[14-Compras-Omie-Pedido-Compra]] | **fluxos A e B testados (01/10/2026), falta ligar em produção** → **movido para `Realizados/`** |
| [[19-Compras-Pedido-Pipeline-Omie]], [[23-Compras-Pipeline-Consolidado]] | não são do DBA: dependem da `omie-elt-pipeline` (branch `feat/compras-omie`, sem commits novos desde 24/09; L4, envio da OC, ainda não existe) — **(atualizado em 07/10)** L4 foi implementado em 05/10 e mergeado (PR #1); ver o aviso no topo |
| [[16-Compras-Pedido-DBA-Banco]] e [[17-Compras-Pedido-API-Backend]] (eram 17 e 18) | históricos, concluídos pelo [[13-Compras-Backend-Consolidado]] → **movidos para `Realizados/`** |
| [[04-Vagas-Fila-Decisao-no-Banco]] | **entregue e conferido em 01/10/2026** → **movido para `Realizados/`** |
| [[09-Paginacao-por-Pedido-Vendas-Planilha]] | **entregue e conferido em 01/10/2026** (`agrupar_por=pedido_venda`; as telas já listam por `/pedidos_venda`) → **movido para `Realizados/`** |
| [[13-Fornecedores-por-Produto]] | desconsiderar (pedido do Nathan); ✅ **contrato 13 desconsiderado** em 07/10 |

## Novo: módulo de Vendas (28/09/2026)

- **[[26-Vendas-Liberacao-Pedido]]** — o pedido que chega do Omie fica travado até o vendedor marcar
  se a **Qualidade acompanha desde o início** (Sim/Não); só pedido marcado vai ao MES, que faz GET
  (polling) no novo **Fluxo 4** (`/pedidos_liberados`). Tela do vendedor (*Liberar pedidos*) e do
  gerente (*Liberação da equipe*, só leitura). Banco, API e telas testados no local; SQL nos
  apêndices, patch da API em `26-anexos/`. **Telas mergeadas na `develop` em 28/09/2026
  ([av-hub#103](https://github.com/Acosvital/av-hub/pull/103))**, mas sem backend na `api-test` (rotas 404).
  Pendente: DBA/backend aplicarem (L1–L3), `api-pcp` trocar a origem da Carteira (L4). **30/09: L4 concluído pelo Robert** (`api-pcp` `901f9bb`); faltam a data de corte (L1) e a chave própria do MES (L6). **(atualizado em 07/10)** a data de corte foi preenchida em 01/10; só o L6 segue aberto. A partir deste contrato, **o contrato vive no vault** (não mais em
  `av-hub/docs/ENVIAR - *`); as marcas `GAMBIARRA(` apontam para cá (contagem total: 🔴 não conferida em 07/10, ver o topo).

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
histórico do Omie tiver dados. **(atualizado em 07/10)** Essas três chaves **não existem mais** no código: as regras ficaram fixas (contratos 36 e 38, `c8f2f5e`); a pendência que sobra é a ordem de subida (compradores vinculados e perfil Gerência de Compras antes da API).

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
  para as telas de Compras terem dados na `api-test`. **(atualizado em 07/10)** L1–L9 e o L4 estão no `master` da pipeline (`d2886bf`) e rodam sem flag de leitura; falta conferir produção; L10.1, L10.6 e L10.7 (b)–(d) são risco aceito (✅ 07/10).
- **[[19-Compras-Pedido-Omie-Nomes]]** — nomes no detalhe do pedido feito no Omie.

Contratos de detalhe:

- **[[14-Compras-Omie-Pedido-Compra]]** (**entregue em 01/10/2026**, agora em `Realizados/`) — de-para completo com a API do Omie: puxar os pedidos de
  compra para o espelho `pedidos_compras` e enviar a OC com `UpsertPedCompra`. Conferido campo a
  campo contra a doc oficial do Omie em 23/09/2026.
- **[[18-Compradores-Funcionario]]** — cadastro de compradores por filial, ligado ao funcionário
  (resolve o `nCodCompr` do Omie).
- ~~[[16-Compras-Pedido-DBA-Banco]], [[17-Compras-Pedido-API-Backend]] e
  [[19-Compras-Pedido-Pipeline-Omie]]~~ — **substituídos em 23/09/2026** pelos dois consolidados
  (o DBA concluiu a parte deles; o que sobrou foi para o [[13-Compras-Backend-Consolidado]], já
  realizado, e o [[23-Compras-Pipeline-Consolidado]]). Ficam como histórico.
- Contratos de API da integração com o MES, ainda em proposta:
  [[003-Requisicao-Compra-Integracao-MES]] e [[004-Referencia-OC-Integracao-MES]]. **(atualizado em 07/10)** O 003 foi substituído pelo [[34-Requisicoes-MES-Empurra-para-o-Hub]]; o 004 continua inexistente (API e MES) e o [[005-Status-Item-Integracao-MES]] tem a rota só no MES, sem consumidor no hub.
- **[[13-Fornecedores-por-Produto]]** (✅ **desconsiderado** em 07/10; texto abaixo é histórico) — fornecedor por produto (relacionado a Compras/Comissão).
  Endpoint entregue e confirmado (28/09/2026), mas ainda não dá pra ligar: o simulador
  (`experimental/simulador-comissao`) roda sobre dataset legado com IDs incompatíveis com a
  tabela real `produtos` — falta a migração do módulo antes de usar o endpoint.

**Já entregue e confirmado ao vivo em `api-test` (25/09/2026):** [[02-Funcionarios-Listagem-Filtros-Ordenacao-Resumo]]
e [[03-Funcionarios-Cadastro-Organograma-Transacional]] — movidos para
`Realizados/03-Contratos-Logica-Fora-Backend/`. O front (`components/Funcionarios/*`) já foi
adaptado e testado contra o mesmo ambiente, mas **só localmente — ainda não commitado no `av-hub`**;
as marcas `GAMBIARRA(` de F1–F7 continuam no repositório até esse commit acontecer (🔴 situação atual das marcas não conferida em 07/10; ver a contagem no topo).

**Já entregues, front commitado e PRs mergeadas na `develop` do `av-hub` (28/09/2026):**

- [[04-Pedidos-Notas-Dashboards-Agregacao-no-Banco]] — Pedidos, Notas e Dashboards agregados no
  banco (PR #94). Único item pendente: P6 (ordem do fluxo de etapas) — o DBA ainda não preencheu
  `ordem_fluxo` em `etapas_faturamento` (sempre `null`); pedido formalizado em
  `docs/ENVIAR - contrato-05-pendencia-ordem-etapas-fluxo.md` no `av-hub`, que continua fora do
  `Realizados/` até isso ser resolvido.
- [[05-Permissoes-e-Escopo-no-Banco]] — identidade propagada via Bearer token, permissão/escopo
  lidos de `/me/permissoes` (PR #95). As travas do backend (`IDENTIDADE_EXIGIR_TOKEN`,
  `PERMISSOES_ROTA_MODO`, `ESCOPO_VENDEDORES_EXIGIR`) seguem desligadas por padrão — o BFF já manda
  o token, a segurança aperta sozinha quando a infra ligar os flags. **(atualizado em 07/10, [[Registro-de-Decisoes-2026-10-07]] #8 e #9)** ✅ `PERMISSOES_ROTA_MODO` fica **fixo em `exigir`** no código, sem `.env` (alteração: Gustavo); as chamadas de serviço (só `x-api-key`, sem `Bearer`) passam porque o modo só confere permissão quando há token. 🟡 (Gustavo) fixar só `ESCOPO_VENDEDORES_EXIGIR`; as demais seguem como chave até separar as chaves de serviço.
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

- ~~[[09-Paginacao-por-Pedido-Vendas-Planilha]]~~ — **resolvido em 01/10/2026** (o DBA entregou
  `agrupar_por=pedido_venda`; conferido na `api-test`) e movido para `Realizados/`. Em 28/09 o
  backend não tinha implementado de verdade.
- [[13-Fornecedores-por-Produto]] — endpoint existe, mas o frontend que ele alimentaria não pode
  usá-lo ainda (dataset legado com IDs incompatíveis).

## Contratos abertos criados no ciclo de 20/09/2026

| Contrato | Cobre | Itens |
|---|---|---|
| [[04-Vagas-Fila-Decisao-no-Banco]] | Solicitações de vagas: filtros/ordem/resumo, custo gerado, decisão com `pode_aprovar` e histórico. **Entregue e conferido na `api-test` em 01/10/2026** (trava `VAGAS_TRAVAS_DECISAO` ligada, §3.3.1 no backend); movido para `Realizados/`. Falta confirmar a trava em produção | V1–V8 |
| [[07-Dados-Orcamento-e-Coordenadores-no-Banco]] | **⛔ Desconsiderado em 01/10/2026 (superado em 07/10).** Orçamento e coordenadores fora do repositório, com filtro/paginação/ordem no servidor. **(atualizado em 07/10)** ✅ orçamento desenvolvido por fora, no módulo Comercial & Suprimentos; API `90bdb33` existe; contrato a reescrever | O1–O5, C1–C3 |

Pedidos/Notas/Dashboards e Permissões/Escopo (P1–P8/N1–N3/D1–D3 e S1–S11) já saíram desta lista —
ver "Já entregues" acima ([[04-Pedidos-Notas-Dashboards-Agregacao-no-Banco]],
[[05-Permissoes-e-Escopo-no-Banco]]).

## Contratos anteriores que continuam abertos e se relacionam

- [[09-Paginacao-por-Pedido-Vendas-Planilha]] — paginar por pedido. **Entregue em 01/10/2026**,
  agora em `Realizados/` (ver status no arquivo).

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


## Novo em 09/10/2026

- [[47-Custo-Real-por-Item-no-Hub]]: simulador etapa 2, comissão por faturamento, Compras e Orçamento (`para-implementar`, Ciclo 2). Ver [[Estoque-Custo-do-Lote]].

## Movidos para Realizados em 09/10/2026

- [[23-Compras-Pipeline-Consolidado]] e [[45-Pedido-de-Venda-Manual]]: implementados no código (produção não verificada). Ver [[Indice-Contratos]].

