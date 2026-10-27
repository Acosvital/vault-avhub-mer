---
id: LOG-57
aliases: ["Contrato 57", "57-Menu-Vendas-Orcamento-Compras"]
tags: [contrato, contrato-logica, hub-front, hub-banco, menu, telas, vendas, orcamento, compras, sql]
criado: 2026-10-16
atualizado: 2026-10-21
status: parcial
sistemas: [hub-front, hub-banco]
dono: "Nathan (front, cadastro na api-test) e Gustavo (SQL em produção)"
etapa_0b: [V0.1, V0.2, V1, B1, B2, B3, B4, C6, C7, C8, K5, K6]
fontes: ["Registro-de-Decisoes (N16-14)", "av-hub branch feat/menu-orcamento-vendas-compras: ededeea, 99d054d, 200e860, 5aa5311 (git log develop..HEAD, 16/10/2026)", "av-hub docs/ENVIAR - telas-vendas-orcamento-compras.sql (idêntico ao anexo deste contrato)", "informação do Nathan de 16/10/2026: telas cadastradas e telas desativadas na api-test", "Dump Avhub (Esqueleto).sql (auth.telas, trg_telas_propagate_ordem)"]
criado_original: 2026-10-16
---

# Contrato 57 — Menu em Vendas, Orçamento e Compras: URLs, páginas, rotas removidas e cadastro das telas

> **Onde atua:** av-hub: front (HUB) e banco (`auth.telas`)

> [!info] Atualização de 21/10/2026
> - 📝 **OQ-29 respondida (N16-33):** as telas **Pedidos de Venda** e **Notas Fiscais de Saída** ficam **inativadas também em produção**; o SQL ganha o passo do `UPDATE auth.telas` descrito na seção 5 (as páginas seguem no código).
> - 🟡 **Telas novas que este menu ainda não cobre** (cada uma ganha o seu cadastro quando existir; OQ-21): em Vendas, a área de pendências em **Meus Pedidos** (aprovar ou reprovar compra acima do valor da proposta, `C8`; N16-64), a **aprovação da proposta** e o **"Transformar em pedido"**; em Compras, a **lista dos casos reprovados pelo vendedor** com o registro da solução (N16-73) e a conferência de impostos da OC (`C6`, `C7`); em Orçamento, a **página do produto** do vendedor (`B2`, N16-55); na comissão, a **decisão** (Controladoria, Gerência, Coordenação), a **consulta do vendedor** com a justificativa (`K5`) e a **informação de devolução parcial** (`K6`, Fiscal e Controladoria). Contratos: [[LOG-56-Fluxo-da-Proposta-ao-Pedido]].
> - 🟡 **Perfil orçamentista** precisa existir (N16-59); o setor orçamentário é novo (o Moisés é uma das pessoas, N16-104).
>
> Situação do front e do SQL abaixo continua a de 16/10/2026.

> [!info] Situação em 16/10/2026
> **Status:** `parcial` · **Pasta:** `Ativos` · **Nós do 0b:** `V0.1`, `V0.2`, `V1`, `B1` a `B4`, `C6`, `C7` (telas) · **Dono:** Nathan (front e api-test) e Gustavo (SQL em produção)
>
> - ✅ **Front: `implementado-no-codigo`** na branch `feat/menu-orcamento-vendas-compras` do av-hub, 4 commits à frente da `develop` (`7a59b09`): `ededeea`, `99d054d`, `200e860`, `5aa5311`. **Branch local; PR e merge ❓** (não conferi no remoto).
> - ✅ **api-test:** o Nathan cadastrou as telas pela tela Telas do Hub e desativou as telas antigas (lista na seção 5).
> - 🟡 **SQL em produção: `proposta`.** O Gustavo roda `telas-vendas-orcamento-compras.sql` ([[telas-vendas-orcamento-compras.sql]] em `LOG-57-anexos/`) **junto** com o deploy do front. Testado em Postgres local e na api-test, idempotente (comentário do commit `200e860`). Produção não rodada ❓.
> - 🟡 **Diferença entre api-test e o SQL:** o Nathan inativou na api-test as telas **Pedidos de Venda** e **Notas Fiscais de Saída**; o SQL **não** as toca. Se a inativação vale em produção, o SQL ganha um passo (OQ-29).
> - O vocabulário de status tem um valor só por contrato; `parcial` quer dizer "parte no código, parte não": o front está feito, a produção não.

Selos em [[Regras-do-Vault]]. Decisão de origem: N16-14 em [[Registro-de-Decisoes]]. Este contrato **substitui, na parte de menu e telas**, o que o [[LOG-42-Coordenadores-e-Orcamento-sair-do-JSON-do-Repositorio]] dizia do Orçamento (o LOG-42 está encerrado, N16-14).

> [!info] Menu enxuto de 27/10/2026
> O menu final de Vendas, Orçamento e Compras está em [[LOG-62-Reescopo-Menu-Enxuto-e-Limpeza-do-Modulo-do-Pablo]] (N16-107 e N16-108): **Vendas com 4 entradas** (Propostas, Clientes, Meus Pedidos, Relatórios), **Orçamento com 4** (Pedidos de custo, Produtos, Fornecedores, Parâmetros) e o **Histórico de compras removido**. Isso **substitui** a proposta de 23/10 da nota [[14-Telas-e-Experiencia-do-Usuario]] (Orçamento com 6) e a tabela de telas das seções 3 e 5 abaixo, que descrevem o menu **de 16/10** (já na `develop`). Compras troca **Aprovações** por **Aprovar OC** e ganha **Reprovados**, e entra uma **Fila do Fiscal**, na rodada das telas novas. Vira SQL novo em `auth.telas`, a escrever depois da validação das telas.
>
> Observação de 27/10: o `GET /api/menu` devolve `propostas-delegacao`, `propostas-valores`, `solicitacoes-custo` e `custo-item` como entradas comuns, mas a seção 3 as trata como ocultas; o LOG-62 §7 pede a conferência de como a tela oculta é marcada.

## 1. Por quê

O menu do HUB tinha **Comercial** e **Suprimentos** (telas do módulo do Pablo) ao lado de um **Orçamento** antigo (5 telas sobre dados em JSON). O Nathan reagrupou em 16/10 pelo que cada setor faz (N16-14, N16-07):

- **Vendas:** a proposta e o que o vendedor usa (propostas, clientes, relatórios, pedidos).
- **Orçamento:** o setor orçamentário (base de preço, ofertas, fornecedores, pedido de custo).
- **Compras:** o que já existe de Compras, mais o histórico de compras.

A URL do HUB é o caminho de slugs de `auth.telas`. Por isso o front e o SQL **precisam entrar juntos**: se só o front entrar, o menu aponta para as URLs antigas; se só o SQL entrar, o menu aponta para páginas que ainda não existem.

## 2. O que foi entregue no front (✅ branch `feat/menu-orcamento-vendas-compras`)

| Commit | Data | O que fez |
|---|---|---|
| `ededeea` | 16/10 | Reagrupa as telas em Vendas, Orçamento e Compras (modo preview) e **remove as 5 telas antigas de `/orcamento`** com services, rotas BFF, tipos e os 3 JSON só delas. 26 arquivos, 38 inclusões e 1.918 exclusões |
| `99d054d` | 16/10 | Completa o menu de desenvolvimento (`lib/auth/devSemLogin.ts`) com os demais módulos do Hub |
| `200e860` | 16/10 | **Move as páginas** (renomeações de pasta): `comercial/*` para `vendas/*`, `suprimentos/*` para `orcamento/*` e `suprimentos/historico-compras` para `compras/historico-compras`. Atualiza links, breadcrumbs, guia do fluxo do custo, dicas do menu, e2e, `groupMap` e `iconMap`. **Remove a tela Sincronização Omie** e os rewrites de preview. Acrescenta `docs/ENVIAR - telas-vendas-orcamento-compras.sql`. 53 arquivos |
| `5aa5311` | 16/10 | Remove as **rotas BFF órfãs** `app/api/historicoProdutos/historico/route.ts` e `app/api/historicoProdutos/route.ts` (48 linhas) |

## 3. URLs: antigas e novas

A pasta `app/(protected)/` do HUB. O slug da tela **não muda**; só o grupo (o pai).

### 3.1 Vendas (antes `comercial`)

| Tela | URL antiga | URL nova | Slug | Nó |
|---|---|---|---|---|
| Propostas (lista) | `/comercial/propostas` | `/vendas/propostas` | `propostas` | `V0.1` |
| Nova proposta | `/comercial/propostas/nova` | `/vendas/propostas/nova` | `propostas` | `V0.1`, `V0.2` |
| Proposta (detalhe) | `/comercial/propostas/[id]` | `/vendas/propostas/[id]` | `propostas` | `V0.1` a `V0.7` |
| Clientes (lista, novo, detalhe) | `/comercial/clientes`, `/novo`, `/[id]` | `/vendas/clientes`, `/novo`, `/[id]` | `clientes` | `V0.1` |
| Relatório de Cotações | `/comercial/relatorio-cotacoes` | `/vendas/relatorio-cotacoes` | `relatorio-cotacoes` | — |
| Relatório Gerencial | `/comercial/relatorio-gerencial` | `/vendas/relatorio-gerencial` | `relatorio-gerencial` | — |
| Delegação de propostas (oculta) | — | — | `propostas-delegacao` | libera escolher outro responsável |
| Valores das propostas (oculta) | — | — | `propostas-valores` | libera ver R$ na proposta |
| Solicitações de custo (oculta) | — | — | `solicitacoes-custo` | o vendedor pede custo pela proposta (`B3`) |

### 3.2 Orçamento (antes `suprimentos`)

| Tela | URL antiga | URL nova | Slug | Nó |
|---|---|---|---|---|
| Painel do Comprador | `/suprimentos/painel-comprador` | `/orcamento/painel-comprador` | `painel-comprador` | `B3`, `B4` |
| Pedido de cotação | `/suprimentos/pedido-cotacao` | `/orcamento/pedido-cotacao` | `pedido-cotacao` | `B4` |
| Ofertas de fornecedor | `/suprimentos/ofertas-fornecedor` | `/orcamento/ofertas-fornecedor` | `ofertas-fornecedor` | `B1`, `B4` |
| Fornecedores (lista e ficha) | `/suprimentos/fornecedores`, `/[id]` | `/orcamento/fornecedores`, `/[id]` | `fornecedores` | `B1` |
| Catálogo (lista e produto) | `/suprimentos/catalogo-produtos`, `/[id]` | `/orcamento/catalogo-produtos`, `/[id]` | `catalogo-produtos` | `B2` |
| Pesquisa de materiais | `/suprimentos/pesquisa-materiais` | `/orcamento/pesquisa-materiais` | `pesquisa-materiais` | `B2` |
| Parâmetros de custo | `/suprimentos/parametros-custo` | `/orcamento/parametros-custo` | `parametros-custo` | `B1` |
| Tabela da telha | `/suprimentos/tabela-telha` | `/orcamento/tabela-telha` | `tabela-telha` | `B1` |
| Custo do item (oculta) | — | — | `custo-item` | libera ver custo, margem e sugestão |

### 3.3 Compras

| Tela | URL antiga | URL nova | Slug | Nó |
|---|---|---|---|---|
| Histórico de compras | `/suprimentos/historico-compras` | `/compras/historico-compras` | `historico-compras` | `B1` |

### 3.4 O que saiu

| O que | Onde estava | Observação |
|---|---|---|
| Categorias | `/orcamento/categorias` | removida (`ededeea`) |
| Fornecedores (antiga do Orçamento) | `/orcamento/fornecedores` | removida; **a mesma URL agora é a tela nova de Fornecedores** (era `/suprimentos/fornecedores`) |
| Histórico de produtos | `/orcamento/historico-produtos` | removida |
| Sem cadastro | `/orcamento/sem-cadastro` | removida |
| Vínculos | `/orcamento/vinculos` | removida |
| Sincronização Omie | `/suprimentos/sincronizacao-omie` | removida (`200e860`: página e `components/Suprimentos/SincronizacaoOmie.tsx`) |

## 4. O que foi removido do código

Em `ededeea` (as 5 telas antigas de `/orcamento`):

- páginas e estilos: `app/(protected)/orcamento/{categorias,fornecedores,historico-produtos,sem-cadastro,vinculos}` (`page.tsx`, `styles.module.css`, `types.ts`);
- **rotas BFF** `app/api/orcamento/categorias`, `app/api/orcamento/fornecedores`, `app/api/orcamento/historico-precos`, `app/api/orcamento/vinculos`;
- services `services/orcamento/{categoriasOrcamento,fornecedores,historicoPrecos,vinculosOrcamento}.ts` e `lib/domain/orcamento-vinculos.ts`;
- dados: `lib/orcamento/data/{categorias,historicoPrecos,vinculos}.json`;
- as funções de `lib/orcamento/dados.ts` que serviam só a essas telas (a marca `GAMBIARRA` O1 e O2 saiu junto).

**Ficam** (usados por Cadastros › Auxiliares › Produtos e pelo Simulador de Comissão): `lib/orcamento/data/{familias,fornecedores,produtos}.json`, `lib/orcamento/dados.ts` e as rotas `app/api/orcamento/{familias,produtos,todos-fornecedores}`. **`fornecedores.json` (CNPJ, e-mail e telefone) segue versionado no git** 🔴 (resíduo do LOG-42, PS-043).

Em `200e860`: a tela Sincronização Omie e o bloco `rewrites()` de `next.config.ts` (só valia no modo dev sem login).

Em `5aa5311`: `app/api/historicoProdutos/historico/route.ts` e `app/api/historicoProdutos/route.ts`.

Atualizados (sem mudar de função): `app/api/comercial/propostas/[id]/pdf/route.ts` e `.../lote/pdf/route.ts` (links), `app/(protected)/comissoes/simulador/page.tsx` (link), componentes de Clientes, Propostas, Relatórios, Suprimentos e Painel do Comprador, `lib/domain/fluxo-suprimentos.ts` (`hrefTela`: `/orcamento/<tela>`; o histórico vai a `/compras/historico-compras`), `groupMap.ts` e `iconMap.tsx` (o grupo `orcamento` fica em Operações e ganha o ícone de caixas; `comercial` e `suprimentos` saem) e os testes e2e (`compras.spec.ts`, `navegacao.spec.ts`, `proposta.spec.ts`).

## 5. Cadastro das telas na api-test e telas desativadas

Informação do Nathan (16/10/2026): ele **cadastrou as telas** na api-test pela tela Telas do Hub (Cadastros › Acessos › Telas). O que ele **desativou** lá:

| Tela desativada na api-test | Está no SQL de produção? |
|---|---|
| Categorias (`categorias`) | sim (passo 2) |
| Vínculos (`vinculos`) | sim (passo 2) |
| Histórico de produtos (`historico-produtos`) | sim (passo 2) |
| Sem Cadastro (`sem-cadastro`) | sim (passo 2) |
| Sincronização Omie (`sincronizacao-omie`) | sim (passo 4) |
| Grupo **Comercial** (`comercial`) | sim (passo 5, quando não restar tela viva dentro) |
| Grupo **Suprimentos** (`suprimentos`) | sim (passo 5, idem) |
| **Notas Fiscais de Saída** (`notas-fiscais-saida`) 🟡 | **não** (OQ-29) |
| **Pedidos de Venda** (`pedidos-de-venda`) 🟡 | **não** (OQ-29) |

As páginas `app/(protected)/vendas/pedidos-de-venda` e `.../notas-fiscais-saida` **continuam no código**; só a tela do banco foi inativada na api-test. Os slugs dessas duas telas vêm do caminho de slugs da URL ❓ (não conferi no banco). Decidir se produção as inativa também (OQ-29) e, se sim, o Gustavo acrescenta ao SQL um `UPDATE auth.telas SET ativo = false, deleted_at = now() WHERE slug IN ('pedidos-de-venda','notas-fiscais-saida') AND deleted_at IS NULL`.

**Mapa final do menu** (o que o SQL cria ou move; `ordem` do pai mais a posição relativa, regra do trigger `trg_telas_propagate_ordem`):

| Grupo (ordem) | Telas (posição) |
|---|---|
| **Vendas** (10) | `propostas` (20), `clientes` (21), `relatorio-cotacoes` (22), `relatorio-gerencial` (23); ocultas: `propostas-delegacao` (90), `propostas-valores` (91), `solicitacoes-custo` (92) |
| **Orçamento** (11) | `painel-comprador` (1), `pedido-cotacao` (2), `ofertas-fornecedor` (3), `fornecedores` (4), `catalogo-produtos` (5), `pesquisa-materiais` (6), `parametros-custo` (7), `tabela-telha` (8); oculta: `custo-item` (90) |
| **Compras** (12) | `historico-compras` (30), junto das telas de Compras que já existem |

## 6. O SQL para produção (anexo)

[[telas-vendas-orcamento-compras.sql]] (103 linhas, em `LOG-57-anexos/`; cópia idêntica de `docs/ENVIAR - telas-vendas-orcamento-compras.sql` do HUB, conferida com `diff`). Roda numa transação e é **idempotente**:

| Passo | O que faz |
|---|---|
| 1 | Cria os grupos raiz `vendas` (10), `orcamento` (11) e `compras` (12) se não existirem; renomeia `orcamento` para "Orçamento" |
| 2 | Desativa (`deleted_at`) as 5 telas antigas do Orçamento (`categorias`, `fornecedores`, `historico-produtos`, `sem-cadastro`, `vinculos`). A de `fornecedores` só é desativada enquanto o grupo antigo `comercial` ou `suprimentos` ainda existe: é o que torna o script seguro numa segunda execução |
| 3 | Mapa de 17 telas (slug, nome, grupo, posição): quem já existe **muda de pai, nome e ordem** (3a); quem não existe é **criado** (3b) |
| 4 | Desativa `sincronizacao-omie` |
| 5 | Desativa os grupos `comercial` e `suprimentos` quando não restar tela viva neles |
| — | `SELECT` de conferência: deve listar Vendas, Orçamento e Compras e **nenhum** Comercial ou Suprimentos |

**O que o SQL não faz (e precisa de atenção do Gustavo):**

1. **Permissões:** as de `auth.permissoes` (por `id_tela`) e o mapa `auth.rotas_telas` (por slug) **acompanham** as telas movidas. Mas as permissões da antiga `fornecedores` do Orçamento **não passam** para a Fornecedores nova: quem precisa dela recebe a permissão de novo (comentário do SQL).
2. **Telas das fases seguintes** (comissão, decisão da Controladoria, consulta do vendedor, matriz de preços, conferência `C6` e `C7`) não estão no SQL; cada uma ganha o seu cadastro quando existir (OQ-21; [[LOG-56-Fluxo-da-Proposta-ao-Pedido]]).
3. **Pedidos de Venda e Notas Fiscais de Saída:** ver a seção 5.
4. O banco de produção **não foi inspecionado** ❓: o Dump Avhub é só esquema; a confirmação de que `vendas` e `compras` já existem como grupo raiz vem do comentário do SQL.

**Ordem de aplicação (🟡):** (1) rodar na api-test, conferir o menu de um perfil de Vendedor e de um de Compras (feito pelo Nathan, que cadastrou as telas por lá); (2) merge da branch na `develop` e deploy do HUB; (3) rodar o SQL em produção **no mesmo momento do deploy**; (4) conferir o `SELECT` do fim; (5) abrir as URLs novas da seção 3 com um perfil de cada módulo.

## 7. Riscos

| # | Risco | Mitigação |
|---|---|---|
| 1 | Front e SQL fora de sincronia: menu aponta para URL que não existe | Deploy e SQL no mesmo momento (seção 6) |
| 2 | **`/orcamento/fornecedores` mudou de sentido:** era a tela antiga do Orçamento e agora é a antiga `/suprimentos/fornecedores`; favoritos e permissões antigas apontam para outra coisa | Reconceder a permissão; avisar quem tinha o favorito |
| 3 | Favoritos e links para `/comercial/*` e `/suprimentos/*` quebram (não há redirecionamento; os rewrites eram só do modo dev) | Aceito 🟡; se o Nathan quiser, `redirects()` em `next.config.ts` |
| 4 | Perfil sem a permissão na tela movida: as permissões vão por `id_tela`, então seguem; mas o escopo do perfil por grupo pode mudar | Conferir o menu de um perfil de cada módulo na api-test e em produção |
| 5 | `fornecedores.json` com CNPJ, e-mail e telefone segue versionado | PS-043 |
| 6 | O módulo do Pablo (`api-comercial`) continua só de teste (N14-15): as telas de Vendas e Orçamento dependem dele até a migração para a `api-acos-vital` | [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] |

## 8. Perguntas em aberto

| # | Pergunta | Quem responde |
|---|---|---|
| 1 | A branch já virou PR e foi mergeada na `develop`? | Nathan ❓ |
| 2 | ✅ Pedidos de Venda e Notas Fiscais de Saída ficam inativas também em produção (OQ-29, N16-33): sim; o Gustavo acrescenta o passo ao SQL | Gustavo executa |
| 3 | Quem recebe de novo a permissão da tela Fornecedores? | Nathan, Gustavo |
| 4 | Haverá redirecionamento das URLs antigas? | Nathan |

## 9. Testes de aceite

1. Na api-test e em produção, o menu mostra **Vendas**, **Orçamento** e **Compras**, e **não** mostra Comercial nem Suprimentos.
2. Um vendedor abre `/vendas/propostas`, `/vendas/clientes` e os dois relatórios; o breadcrumb diz "Vendas".
3. Um comprador abre `/orcamento/painel-comprador`, `/orcamento/catalogo-produtos` e `/compras/historico-compras`.
4. `/orcamento/categorias`, `/orcamento/historico-produtos`, `/orcamento/sem-cadastro`, `/orcamento/vinculos` e `/suprimentos/sincronizacao-omie` não abrem e não aparecem no menu.
5. Rodar o SQL duas vezes: a segunda não altera nada (o `SELECT` de conferência é igual).
6. O guia do fluxo do custo (`lib/domain/fluxo-suprimentos.ts`) leva aos links novos.
7. Os testes e2e `compras`, `navegacao` e `proposta` passam com as URLs novas.

## Ver também

[[Registro-de-Decisoes]] · [[LOG-56-Fluxo-da-Proposta-ao-Pedido]] · [[12-Orcamento-Base-de-Preco]] · [[11-Proposta-e-Pedido-de-Venda]] · [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] · [[Comercial-Suprimentos]]
