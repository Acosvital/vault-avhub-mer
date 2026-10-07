---
tags: [erp-acos-vital, av-hub, modulos]
criado: 2026-09-16
atualizado: 2026-10-07
---

# av-hub — Mapa de Módulos

> Status: decidido | no código | em produção (verificado em 07/10/2026 pelo dump, onde indicado). Decisões da rodada em [[Registro-de-Decisoes-2026-10-07]].

> **Atualização de 07/10/2026 — auditoria código × vault** (leitura de código: front `develop` 996e320 e `main` cfed113 [#153]; **produção não conferida**; "só `develop`" = ainda não em `main`). Reescritos: **Orçamento** (a pasta `_data` foi removida), **Compras** (a nota estava parada em 22/09), **Fechamento** (a pergunta da "prioridade pontual" foi respondida), **Cadastros** (Vendedores e Compradores com vínculo) e **Menu**. Acrescentados: **Comercial & Suprimentos** (nota própria: [[AV-Hub-Comercial-Suprimentos]]), **RH**, **Liberação de pedido**, **Notas Fiscais Manuais**, **Comissões** e telas menores. Contagem: 92 `page.tsx` em `develop` contra 79 em `main`; 183 handlers `route.ts` em `app/api`. O que é só de `develop` vem marcado.

## Vendas
Pedidos de venda, notas fiscais de saída — a captura direta do Omie (ver [[Entrada-Comercial]]). Fonte real de reconciliação é a dupla `vw_vendas_base`/`vw_nf_classified` — ver [[AV-Hub-Vendas-Reconciliacao]].

Requisito: mostrar, por **item** do pedido (não só o pedido como bloco), a etapa em que ele está de acordo com o fluxo seguido (ex.: "em compra", "em fabricação/OS", "em inspeção", "pronto/expedição") — isso depende de status vindo do PCP/MES; o mecanismo ("casamento av-hub ↔ MES") **foi resolvido na DEC-2** (polling REST bidirecional por `x-api-key`; ver [[Decisoes-Chave-ERP]]), mas o consumidor do status por item (contrato 005) ainda não existe no lado do av-hub — e "tempo real" não pode ser assumido como dado: o único padrão de sincronização entre sistemas hoje é o [[Omie-ELT-Pipeline|pipeline ELT]] (polling em camadas, 3min–diário, sem webhook), não um mecanismo de evento. Ver ressalva completa em [[Fluxo-Detalhado-Pedido-Item]] e [[AV-Hub-Portal-Vendedor-Plano]] para o que já existe hoje no Portal do Vendedor (hoje é status agregado por pedido, não por item/etapa de produção).

## Portal do Vendedor (autoatendimento)
Ver [[AV-Hub-Portal-Vendedor-Plano]] para o plano completo (Meu Dashboard, Meus Pedidos, Minhas Notas). Cada vendedor vê só os próprios dados, com contagem de SLA até a previsão de faturamento. Escopo de segurança resolvido **no servidor** (nunca aceita `codigo_vendedor` vindo do request). Suporta multi-vínculo (um vendedor pode ter várias linhas, uma por filial/conta Omie) via `vendedores.id_funcionario`.

Extensão: **Auxiliar de vendedor** — um vendedor pode enxergar (só leitura) os dados de outro vendedor titular que ele auxilia.

## Portal do Gerente / Equipe
Visão do gestor sobre todo o time: Dashboard Equipe, Pedidos/Notas da Equipe. Componente próprio: `ClienteDetalhesModalEquipe` (detalhe de cliente escopado à equipe do gerente). **(atualizado em 07/10)** O Dashboard Equipe ganhou participação por empresa, top 10 e variação por empresa (#131, contrato 37 — a API calcula `variacao_pct` e `variacao_quantidade_pct` via `fn_variacao_pct`; conferido no código).

## Portal do PCP ⚠️
Ver [[Achado-Ambiguidade-PCP]] — **não é produção**, é acompanhamento comercial. Pessoas chamadas "diligenciadores" (do setor de PCP) acompanham pedidos/notas de um grupo de vendedores, com paridade de dados com o gestor (visão financeira completa Bruto→Deduções→Líquido).

## Dashboards
Comissões, Faturamento (geral e por tipo), Vendas (geral e por tipo) — com rankings de clientes/vendedores, ritmo de meta.

## Orçamento
**(decidido em 07/10, ✅)** O orçamento é desenvolvido **por fora**, no módulo Comercial & Suprimentos ([[AV-Hub-Comercial-Suprimentos]]); a API entregue (`90bdb33`) existe, e os contratos 07 e 38 precisam ser reescritos ([[Registro-de-Decisoes-2026-10-07]], item 39). As telas de Orçamento descritas abaixo são o estado do front antigo.

**(atualizado em 07/10 — reescrito)** O texto de setembro dizia "100% JSON local (`app/(protected)/orcamento/_data/*.json`), sem API própria". **Isso deixou de ser verdade**: a pasta `_data` foi **removida** (commit 491bb31, 19/09) e as telas usam `/api/orcamento/*`, que fazem proxy para `/catalogo_de_produtos`, `/historico_precos`, `/todos_os_fornecedores`, `/fornecedores_com_produtos`, `/familias_produtos` e `/categorias`.
- **Categorias** — agrega vínculos por categoria de compra, separando "com cadastro"/"sem cadastro".
- **Fornecedores** — cadastro de parceiros Omie (dados fiscais completos).
- **Histórico de Produtos** — catálogo + histórico de preço por fornecedor, com gráfico de evolução. *(Histórico de setembro, quando era JSON: 400 itens e só 1 fornecedor por produto, o da compra mais recente — não é relação N:N. Não reconferido com a fonte nova.)*
- **Vínculos** — produto/categoria↔fornecedor, com flag `sem_cadastro`.
- **Sem Cadastro** — fila de pendência (fornecedores de vínculo sem cadastro em Parceiros).
- **API nova (conferido no código, `main` = `develop`):** a `api-acos-vital` tem `/orcamento/{fornecedores,produtos,cotacoes,vinculos,categorias,familias}` lendo `core_compras.orc_*` e `orc_vw_*` (contrato [[07-Dados-Orcamento-e-Coordenadores-no-Banco]], commit 90bdb33, 01/10; o vault dizia "desconsiderado/não entregue"). Que o DBA tenha aplicado o SQL é **[I]**. **Não conferido:** se o front já consome essas rotas novas — o proxy `/api/orcamento/*` conferido aponta para as rotas antigas listadas acima.
- ⚠️ **Ainda válido:** as rotas antigas (`/api/orcamento/*`, `/api/historicoProdutos`) apontam para views que o vault registra como removidas do `core_compras` — ver [[AV-Hub-Bugs-Catalogo]] e [[AV-Hub-Views-Compras-Investigacao]].
- Possível ponto de integração com o módulo de Compras do [[PRD-Estoque-Visao-Geral|PRD do Estoque]], que deixou "cotação entre fornecedores" fora do escopo v1 (ver [[AV-Hub-Bugs-Catalogo]]). O Comercial & Suprimentos tem o seu próprio fluxo de ofertas/cotações — ver [[AV-Hub-Comercial-Suprimentos]].

## Compras
**(atualizado em 07/10 — reescrito)** O texto de 22/09 descrevia um backend em "branch local `feat/compras-requisicoes-e1`, sem push" — **obsoleto**: backend e front passaram de longe, hoje cobertos pelos contratos 16 a 38 (ver [[Indice-Contratos]]). O módulo existe no front em `app/(protected)/compras/*` e `components/Compras/`: **Requisições** (caixa de entrada + Kanban), **Ordens** (fechamento de compra + Kanban), **Aprovações**, **Dashboard de Compras** e o fluxo de emissão (`/compras/nova`, `/compras/nova/{requisicaoId}`). Contrato do próprio front: `docs/ENVIAR - contrato-compras-fluxo-completo.md` (usado para escrever [[007-Ordens-Compra-Estruturada]] e [[008-Requisicoes-Compra]]).

| Tema | Estado (conferido no código) | Onde |
|---|---|---|
| OC a partir de requisições do MES (#151) | a OC traz PV, produto do cadastro e destino; fica **presa aos itens** das requisições; o destino vem do PV e **não é editável**; rota `/api/compras/minhas-unidades` | `main` |
| Comprador só emite OC na filial a que pertence (#151) | sem vínculo, o select fica vazio e o item vira pendência; o **backend também recusa** (contrato [[38-Regras-Sem-Chave-de-Ambiente]]; a chave `COMPRAS_EXIGIR_VINCULO_COMPRADOR` saiu depois). Registro de 06/10: 0 dos 74 compradores de produção tinham vínculo (não reconferido) | `main` |
| Compradores — vínculo (#154) | vínculo lado a lado, candidatos prontos, gravação otimista, Trocar/Desvincular | **só `develop`** |
| Follow-up CCP | tela de acompanhamento (contrato 32) | `main` |
| Dashboard com valores | contrato 31 | `main` |
| PDF do pedido emitido no Omie | contrato 30 | `main` |
| Detalhe do pedido Omie com nomes | fornecedor e código do produto (contrato 27 do repo do Hub) | `main` |
| Motivo obrigatório ao cancelar requisição | #117, contrato [[35-Compras-Marcos-Requisicao-para-MES]] (a API exige 3–500 caracteres) | `main` |
| Produto do cadastro e histórico do comprador | #129 (05/10), contrato 36 | `main` |
| Vínculo OC↔PV | #104 | `main` |
| Categoria da OC por unidade | — | `main` |
| HRM | compra pela própria conta Omie (comentário de código em d1f87c8) | `main` |

Régua de aprovação de R$ 30.000 (BRL e moeda estrangeira, conversão via `cotacao_moeda`) — registrada em 22/09; hoje, **só quem tem `pode_aprovar` aprova/cancela OC** (ver [[AV-Hub-RBAC]]). **Duas lacunas de 22/09 — atualizado em 07/10:** (1) a sincronização com o Omie deixou de ser "sempre `pendente`" no desenho: a API expõe `GET /compras/ordens/fila-omie`, `PATCH /compras/ordens/:id/sincronizacao` e `POST /:id/reenviar` para a pipeline (lado da API conferido; o lado da pipeline **não foi conferido aqui** — ver [[Omie-ELT-Pipeline]]); (2) o cálculo de parcelas "placeholder" **não foi reconferido**.

Integração com o MES: o MES empurra requisições com `PUT /compras/requisicoes/origem/{id}` (contrato [[34-Requisicoes-MES-Empurra-para-o-Hub]]) e lê os marcos em `/compras/requisicoes/eventos` — chaves em [[Chaves-de-Integracao-AvHub-MES-Pipeline]]. Ver também [[AV-Hub-Views-Compras-Investigacao]] e [[Decisoes-Chave-ERP]].

## Comercial & Suprimentos (novo)
Módulo **AV Comercial & Suprimentos** e o serviço `api-comercial` (Node 22, Prisma, schema `core_comercial`, dentro do repo): propostas, clientes, relatórios de cotações e gerencial, painel do comprador, ofertas, fornecedores, catálogo, sincronização Omie, parâmetros de custo, empresas emissoras. **Em `main`:** Propostas, Painel do Comprador, Dashboard Comercial e o BFF (#116/#120, 02/10) — **sem** o serviço. **Só `develop`:** o serviço e as telas MVP (#123 a #152, mergeados em 06/10). **9 branches abertas.** Detalhe, rotas, slugs e pendências de publicação em [[AV-Hub-Comercial-Suprimentos]].

## RH (novo — conferido no código)
`rh/funcionarios` e `rh/solicitacoes-de-vagas`, no grupo de menu "Gestão de Pessoas". Na API, funcionários têm validação/normalização de CPF (POST/PUT) e vagas têm fila de decisão no banco (contrato [[04-Vagas-Fila-Decisao-no-Banco]]). Slugs de tela configuráveis na API: `FUNCIONARIOS_TELA_SLUG` e `VAGAS_TELA_SLUG`.

## Liberação de pedido (novo — conferido no código)
`liberar-pedidos` (vendedor) e `liberacao-equipe` (gerente), #103. Fonte na API: `pedidos_liberacao`/`pedidos_liberados` (contrato [[26-Vendas-Liberacao-Pedido]]). O MES consome `/pedidos_liberados` — a restrição de chave por rota (L6) segue aberta ([[Chaves-de-Integracao-AvHub-MES-Pipeline]]).

## Notas Fiscais Manuais (novo)
Tela só para admin (contrato [[29-Notas-Fiscais-Manuais-So-Admin]]), conferida no código. Detalhe de uso não levantado na auditoria.

## Comissões (novo — front)
8 telas em `comissoes/*` no front (conferido no código); o schema `core_comissionamento` do backend está em [[AV-Hub-Comissao-Modulo]]. Na API, `GET /dashboard/comissoes` usa `fn_dashboard_comissoes` sobre `comissao_coordenadores`. O [[AV-Hub-Simulador-Comissao|Simulador]] continua sendo o protótipo de `experimental/`. O que cada uma das 8 telas faz **não foi levantado** nesta auditoria.

## Fechamento
Fechamento manual por mês/tipo, com regra de transição confirmada em runtime ([[AV-Hub-Fechamento-Manual-Investigacao]], 22/09/2026): até agosto/2026 é 100% manual (16 registros reais confirmados no banco, totais automáticos "não confiáveis" até então — ver divergências em [[AV-Hub-Vendas-Reconciliacao]]); a partir de setembro/2026 lê automaticamente de `fn_dashboard_mensal_vendas`/`fn_dashboard_mensal_faturamento` (confirmado em 22/09: zero registros manuais desde set/2026).

**(atualizado em 07/10 — a pergunta da "prioridade pontual" foi respondida no front.)** Em 22/09 o vault concluiu que a prioridade do manual sobre o automático "não tem suporte no backend" e que só poderia estar no front. Lendo o front (`develop`): **não existe prioridade por mês**. `ehAutomatico(mes, ano)` (`lib/domain/fechamento.ts`) usa um **limiar fixo** `INICIO_AUTOMATICO = {mes: 9, ano: 2026}`: **antes** dele só o manual vale; **a partir** dele só o automático; um lançamento manual de mês automático é **ignorado**. A frase antiga ("um lançamento manual salvo continua tendo prioridade pontual") estava errada. Confirmado no código; produção não conferida.

## Cadastros
- **Acessos**: Usuários (sem anonimização LGPD — a coluna `anonymizedAt` não existe no schema real, só `ativo`/`deleted_at` — ver [[AV-Hub-RBAC]]), Perfis (com `tela_inicial_id`), Permissões (com `BulkPermissaoModal` para edição em lote), Telas (árvore via `id_parent`+`ordem`), Usuários×Perfis, Vendedores, Compradores, Diligenciadores, Auxiliares de vendedor.
  - **(atualizado em 07/10) Vendedores e Compradores** usam o mesmo padrão de vínculo com funcionário, com peças comuns em `components/Acessos/*`. **Compradores** (#154): vínculo lado a lado, candidatos prontos, gravação otimista, Trocar/Desvincular — **só `develop`**. **Vendedores** (#155, contrato [[39-Vendedores-Fila-de-Vinculo]]): o `id_funcionario` **agora é exposto na UI** (o texto antigo dizia "ainda não exposto") e há a fila "sem funcionário" (`sem_vinculo`, `nome_funcionario`, `nome_usuario`) — mergeado na `develop` em **07/10 10:01** (996e320), **só `develop`**. Na API (`main`): `POST /vendedores` é bloqueado com 403 `CADASTRO_VEM_DO_OMIE` e o PUT ignora `codigo_vendedor_omie`/`codigo_empresa`/`nome`/`email`/`ativo` (header `X-Campos-Ignorados`); compradores têm só GET, sugestões, GET `:id` e PUT. Detalhes em [[AV-Hub-API-Estado-Atual]].
- **Auxiliares**: Blacklist de pedidos (PK composta `numero_pedido`+`codigo_empresa` — bug de backend antigo já corrigido, ver [[AV-Hub-Bugs-Catalogo]]), Blacklist de vendedores (PK `termo`, `escopo: 'faturamento'|'vendas'|'ambos'`, usada no grupo G5 de dedução), Cargos (`nvl_permissao` + `sub_nivel` opcional de desempate), Metas mensais, Parceiros (10.065 registros, filtros de busca com bugs confirmados), Produtos, Setores, Unidades (3 registros hoje). **(atualizado em 07/10)** A tela `/cadastros/auxiliares/produtos` tem **criar/editar/excluir quebrados no BFF** (`app/api/produtos/route.ts` só exporta GET; não existe `[id]`) — ver [[AV-Hub-Bugs-Catalogo]]. Existe também a tela `produtos-duplicados`.

## Experimental
[[AV-Hub-Simulador-Comissao|Simulador de Comissão]] — protótipo local, 100% frontend, ainda sem gravar em banco. Fica em `app/(protected)/experimental/`, não em `orcamento/`, apesar de consumir os services de Orçamento para produtos/fornecedores. **(atualizado em 07/10)** O grupo Experimental tem também a tela `financeiro` e um dashboard com flange 3D (conferido no código; sem detalhe levantado).

## Layout/navegação compartilhados
Menu lateral dinâmico (`Menu.tsx`) monta a árvore a partir de `telas`+permissões do usuário via `GET /api/menu`, com agrupamento visual próprio do frontend (não vindo da API): **Operações** (crm/vendas/serviços/compras/orçamento/pcp **e, desde o módulo novo, `comercial` e `suprimentos`** — `groupMap.ts`), **Configurações** (admin), **Gestão de Pessoas** (RH), mais os grupos dos três portais. `cadastros` e `fechamento` ficam deliberadamente fora de qualquer grupo; `experimental` sempre por último. Tem busca full-text (Ctrl+K), itens recentes e grupos colapsáveis persistidos em `localStorage`. **(atualizado em 07/10)** O menu que vai no JWT é **compacto** (f875e5b, 02/10; evita HTTP 431) e as rotas verificam permissão ao vivo em `GET /me/permissoes` — ver [[AV-Hub-RBAC]]. Telas do Comercial/Suprimentos **somem do menu** (e dão 403 no BFF) enquanto a tela não estiver cadastrada em `auth.telas` — ver [[AV-Hub-Comercial-Suprimentos]]. *(Descrição de agrupamento de setembro; `cadastros`/`fechamento` fora de grupo não foi reconferido.)*

## Ver também
- [[AV-Hub-Visao-Geral]]
- [[AV-Hub-Comercial-Suprimentos]]
- [[AV-Hub-API-Estado-Atual]]
- [[AV-Hub-Vendas-Reconciliacao]]
- [[AV-Hub-Bugs-Catalogo]]
- [[AV-Hub-Portal-Vendedor-Plano]]
- [[AV-Hub-Fechamento-Manual-Investigacao]]
- [[AV-Hub-Views-Compras-Investigacao]]
- [[007-Ordens-Compra-Estruturada]]
- [[008-Requisicoes-Compra]]
