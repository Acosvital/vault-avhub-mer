---
tags: [erp-acos-vital, auditoria, producao, dump]
criado: 2026-10-07
atualizado: 2026-10-07
---

# Auditoria dos dumps de produção — 07/10/2026

> Status: em produção (verificado em 07/10/2026) — retrato do dump; o conteúdo abaixo não foi reescrito.
>
> **Atualização de 07/10/2026 (posterior ao dump, [[Registro-de-Decisoes-2026-10-07]]).** (1) **Retenção de logs decidida (✅ item 53):** `auth.logs` passa a ter retenção **curta** (prazo 🔴 pendente com o Gustavo) e `auth.auditoria`, 5 anos; o "sem política de retenção" da seção 3 vale só para o momento do dump. (2) **`PERMISSOES_ROTA_MODO`, `SYNC_ENVIO_OC` e `ENVIO_OC_DRY_RUN` deixam de existir como variáveis** (✅ itens 7 e 8): ficam fixos no código (`exigir`; envio direto ao Omie), alteração de código com o Gustavo. A lista da seção 10 continua como estava no dump; para `ESCOPO_*` e `IDENTIDADE_EXIGIR_TOKEN`, ver o item 9 do Registro e [[Chaves-de-Integracao-AvHub-MES-Pipeline]].

> **Fonte:** dois dumps de cluster do Postgres, entregues pelo Nathan em 07/10/2026: **MES** (banco `pcp_prd_db`, role `pcp_prd_admin`, gerado 11:22) e **av-hub** (banco `avhub_prd_db`, roles `avhub_prd_admin`/`avhub_tst_admin`, gerado 11:24, 383 MB). É o complemento de produção da leitura de código feita no mesmo dia ([[Onde-Estamos]], adendo de 07/10). Segue a regra do Nathan: **vale o que funciona em produção**. Continuam as auditorias anteriores [[Auditoria-Dump-Producao-2026-09-21]] e [[Auditoria-Dump-Producao-2026-09-22]].
>
> **Privacidade:** os dumps têm dados pessoais e credenciais (usuários, funcionários, hashes, chaves, logs). **Nada disso foi copiado para o vault.** Aqui só há estrutura, contagens, agregados, slugs de tela, nomes de perfis (cargos) e datas. Quando um nome de perfil traz o nome de uma pessoa, ele foi omitido.
>
> **Rótulos:** [DDL] estrutura; [D] dado do dump; [LOG] `auth.logs` (rotas chamadas); [RL] `omie_ctl.run_log`. Horários do dump estão em UTC (BRT = UTC−3). **Não se sabe** (o dump não diz) quais variáveis de ambiente estão ligadas em cada serviço; isso é dito onde importa.

## 1. Resumo em dez linhas

1. **O MES de produção é a `main` de 28/08 e está vazio.** 15 migrations (a última, `20260828173037_add_perfil_setor`), idênticas às da `main` do `api-pcp`; **faltam as 36 migrations da `develop`** (Estoque, Qualidade, Recebimento, requisição de compra). Nenhum pedido, fábrica, roteiro, item parcial, perfil, tela ou permissão; 1 usuário. Dos 111.778 acessos auditados, 111.751 são o `GET /health` (a cada ~30 s, desde 26/08); não há uso real registrado. Ver seção 2.
2. **No av-hub, o schema de Compras e dos contratos 26 a 39 está em produção desde 02/10 17:26 UTC, mas está vazio de uso:** `ordens_compra`, `requisicoes_compra` e todas as filhas têm **0 linhas**; nenhum `PUT /compras/requisicoes/origem/*` aparece no log; nenhuma OC foi enviada ao Omie. O que roda de verdade é o espelho do Omie e a pipeline.
3. **A função `fn_requisicao_mes_aplicar` (contrato 34) existe em produção** (completa); o risco "sem ela o PUT dá 500" caiu. Mas ninguém a chamou ainda.
4. **O contrato 07 está aplicado e carregado em produção** (6 tabelas `orc_*` com 13.896 linhas, `fn_dashboard_comissoes`, `comissao_coordenadores`, carga em 02/10), apesar de o vault tê-lo dado como "desconsiderado".
5. **O contrato 006 ("invalidado") está parcialmente aplicado:** `pedidos_vendas` tem `codigo_devolucao_omie`, `valor_devolucao`, `devolucao_consultada_em` e um índice parcial; nenhuma linha preenchida.
6. **Compradores:** 20 de 74 já têm `id_funcionario` (carga em lote em 07/10 09:10 BRT), contra "0 de 74" do vault em 06/10. 32 ativos seguem sem vínculo.
7. **Telas do Comercial & Suprimentos não existem em produção:** só `suprimentos` e `painel-comprador` (criadas 06/10 17:24 UTC), **sem nenhuma permissão** — ninguém as enxerga. O schema `core_comercial` (do `api-comercial`) **não existe** neste banco.
8. **Ninguém pode aprovar OC nem vaga:** nenhum usuário tem os perfis Comprador ou Gerência de Compras (0 usuários), e `pode_aprovar` em `compras`/`aprovacoes` só existe no perfil Gerência de Compras; em `solicitacoes-de-vagas` não existe em nenhum perfil.
9. **Saúde:** o pipeline está sincronizando (dados atualizados no minuto do dump) e o scraping de manifestos roda; mas há 500 erros de `exclusion_sync_curta` (HTTP 500, quase todos em mogi), e o **job de snapshot mensal do pg_cron falhou 5 de 5 vezes (26–30/09)** por chave duplicada, remediado manualmente em 01/10.
10. `auth.chaves_servico` está **vazia**: nenhuma chave de serviço restrita foi cadastrada no banco; as chaves de ambiente (`API_KEYS`) são as que valem.

## 2. MES (`pcp_prd_db`)

| Fato | Evidência |
|---|---|
| Schema = `main` de 28/08 | `public._prisma_migrations` com 15 migrations (de `init` a `add_perfil_setor`); `main` do `api-pcp` tem exatamente essas 15; a `develop` tem 51 |
| 27 tabelas, só `public` | Faltam todas as de Estoque, Qualidade, Recebimento, Compras, Integração e Auditoria novas ([[App-PCP-Recebimento-Conferencia]]); 44 modelos Prisma na `develop` |
| Banco vazio | 0 linhas em `pedidos`, `itens_pedido`, `itens_parciais`, `fabricas`, `fabrica_setores`, `setores`, `roteiros`, `roteiros_item`, `maquinas`, `operadores`, `entregas`, `divergencias`, `perfis`, `permissoes`, `telas`, `perfil_setores`, `usuarios_perfis`; 1 linha em `usuarios` |
| Sem tráfego real | `auditoria_acesso` 111.778 linhas (26/08 a 07/10), 99,98% `GET /health`, todas como `anonimo`; `auditoria_login` 0 |
| Enums de `main` | `StatusItemParcial` com 8 estados, `SistemaOrigem`, `TipoUnidade` (`UN`, `PC`) etc. |

**Consequência para o vault:** a frase "o `app-pcp`/MES em si (execução do roteiro de Flanges) é real e está em produção" (confirmada com o Nathan em 17/09) **não é sustentada por este dump**: o MES está implantado, mas o banco de produção não tem nenhum dado operacional. Ou o uso real acontece em outro banco/ambiente, ou ainda não começou. **Pergunta CC-10** em [[Perguntas-em-Aberto-Consolidadas]]. Tudo que o vault chama de "construído no MES" (Estoque, Recebimento, Qualidade...) está **só na `develop`, e não em produção**.

## 3. av-hub (`avhub_prd_db`) — retrato geral

- **12 schemas** (`auth`, `core`, `core_aprovacao_de_vagas`, `core_comissionamento`, `core_compras`, `core_estoque`, `core_mapas`, `core_organograma`, `core_vendas_faturamento`, `historico`, `omie_ctl`, `omie_raw`); **116 tabelas, 40 views (nenhuma materializada), 162 funções, 113 triggers, 237 índices, 166 FKs**; extensões `pg_cron`, `btree_gist`, `pg_trgm`, `pgcrypto`, `unaccent`. Não existe o schema `core_comercial` nem o `negocio`.
- **Maiores tabelas:** `auth.logs` 1.673.726; `omie_ctl.run_log` 293.408; `core.produtos` 125.082; `pedidos_compras_itens` 43.973; `produto_vendas` 36.538; `pedidos_compras_parcelas` 31.758; `core.parceiros_tipos` 28.705; `core.parceiros` 22.981 (matriz 10.094, HRM 12.619, Uberaba 268); `pedidos_compras` 22.808; `pedidos_vendas` 13.137; `notas_fiscais` 10.950; `core_compras.orc_fornecedores` 10.524; `manifestos` 8.197.
- **38 tabelas vazias.** As relevantes: `ordens_compra` e as 8 filhas (itens, itens_vinculos, parcelas, acompanhamento, contatos, ocorrencias, historico, comprador_historico), `requisicoes_compra`, `requisicoes_compra_eventos`, `core_compras.produtos_compras`, `core.estoque_saldo`, `core.locais_estoque`, `parceiros_dados_bancarios`, `parceiros_endereco_entrega`, `parceiros_produtos`, `pedidos_vendas_frete`, `pedidos_vendas_parcelas`, `pedidos_vendas_liberacao` (+ histórico), `*_manuais_historico`, `vagas_decisoes`, `auth.chaves_servico`, `ip_regras`, `login_tentativas`, `usuarios_favoritos` e as 5 `omie_raw.*`.
- **`core_estoque`:** só o `CREATE SCHEMA`, sem tabela. **`core_mapas`:** 2 views (`mapa_unidades`, `vw_todos_os_clientes`), sem tabela.
- **`historico`:** `hst_notas_fiscais` 2.518, `hst_pedidos_vendas` 2.689, `hst_produto_vendas` 4.663; snapshots mensais congelados por `fn_snapshot_mensal(motivo, mes)` (agosto marcado `cron_mensal_legado`, setembro `cron_mensal_remediado`, gravado em 01/10); **sem trigger**.
- **`cron.job` (pg_cron), 2 jobs:** `resolver_refaturamento_lote` a cada 4 h (293 execuções, todas ok) e `snapshot_mensal_congelamento` às 20 h dos dias 26 a 31 (**falhou 26–30/09**, erro de chave duplicada no índice único de `hst_pedidos_vendas`). Próxima janela: 26/10.
- **`auth.logs`:** 1,67 milhão de linhas em 48 dias (21/08 a 07/10; 35 mil/dia em média, máximo 149 mil), 99,8% GET, 99,9% por `api_key`; **sem política de retenção** visível.

## 4. Acessos e permissões (`auth`)

- **77 telas**, todas ativas, árvore de 5 níveis (campo `ordem` não é ordem entre irmãos: 0 raiz, 1 filho, 2 neto, com trigger). Raízes sem filhos: `blog`, `dashboard-equipe`, `fechamento`, `liberacao-equipe`, `liberar-pedidos`, `meu-dashboard`, `meus-pedidos`, `minhas-notas`, `notas-equipe`, `organograma-clientes`, `pcp-dashboard`, `pcp-notas`, `pcp-pedidos`, `pedidos-equipe`. Grupos: `cadastros` (`acessos` com `auxiliares-vendedor`, `compradores`, `diligenciadores`, `perfis`, `permissoes`, `telas`, `usuarios`, `usuarios-perfis`, `vendedores`; `auxiliares` com `blacklist_pedidos`, `blacklist_vendedores`, `cargos`, `metas-mensais`, `parceiros`, `produtos`, `produtos-duplicados`, `setores`, `unidades`, `notas-fiscais-manuais`, `pedidos-vendas-manuais`), `comissoes` (`analise-simuladores`, `bloqueio-comissoes`, `minhas-comissoes`, `simulador`, `visao-geral`, `parametros` com `blacklist-clientes`, `blacklist-vendedores`, `regras-comissoes-fixas`, `vendedores-comissao`), `compras` (`aprovacoes`, `dashboard-compras`, `ordens`, `requisicoes`, `followup`), `dashboards` (`dash-comissoes`, `dash-faturamento`, `dash-faturamento-por-tipo`, `dash-vendas`, `dash-vendas-por-tipo`), `experimental` (`organograma-debug-fatias`, `simulador-comissao`), `orcamento` (`categorias`, `fornecedores`, `historico-produtos`, `sem-cadastro`, `vinculos`), `rh` (`funcionarios`, `solicitacoes-de-vagas`), `suprimentos` (`painel-comprador`), `vendas` (`notas-fiscais-saida`, `pedidos-de-venda`).
- **Contradiz/confirma o vault (Onde-Estamos 06/10):** `suprimentos` e `painel-comprador` foram criadas em 06/10 17:24 UTC (confirmado) **e não têm nenhuma linha em `auth.permissoes`**: nem o Admin (Dev) as enxerga. `compradores` em Cadastros › Acessos, só Admin (Dev) (criada 02/10, movida 06/10 17:30): confirmado. **Os slugs do módulo Comercial (`propostas`, `clientes`, `relatorio-cotacoes`, `relatorio-gerencial`, `ofertas-fornecedor`, `catalogo-produtos`, `sincronizacao-omie`, `parametros-custo`, `dash-comercial`, `empresas-emissoras`, `comercial`, `matriz-precos`, `tabela-telha`, `historico-compras`, `pesquisa-materiais`, `propostas-delegacao`, `custo-item`, `solicitacoes-custo`) não existem em produção.** O slug `fornecedores` existe, mas é o de Orçamento, não o do Comercial.
- **21 perfis**, nenhum apagado; 14 com usuários e 6 sem (Blog Colaborador, Comprador, Gerência de Compras, Globo Clientes - Admin, Orçamentos, Vendas). `escopo_vendedores` = `vinculados` em 20 perfis, `todos` só em Gerencia PCP.
- **`auth.permissoes`:** 194 linhas; colunas `pode_visualizar/criar/editar/deletar/aprovar` (a 5ª existe). Admin (Dev): 74 das 77 telas (sem `blog`, `suprimentos`, `painel-comprador`). **`pode_aprovar` tem só 5 linhas:** Gerência de Compras em `compras`, `aprovacoes`, `followup`; Admin (Dev) e Comprador só em `followup`. **Como Gerência de Compras e Comprador têm 0 usuários, hoje ninguém aprova OC acima de R$ 30.000, e ninguém tem `pode_aprovar` em `solicitacoes-de-vagas`** (a rota `POST /vagas/*/decisao` exige).
- **31 usuários** (todos ativos; 27 com funcionário vinculado; 8 `setor_irrestrito`; `token_versao`=1 em todos; 1 sem perfil; **não existe coluna `anonymized_at`**, como o vault dizia). 41 vínculos usuário↔perfil. `usuarios_unidades`: 11 usuários (o resto é irrestrito).
- **`auth.rotas_telas`:** 371 linhas, todas criadas em 02/10 (origem majoritária `av-hub`, 45–71 `manual`; a contagem varia entre as duas leituras do dump) e 58 slugs distintos. **3 rotas apontam para o slug `organograma`, que não existe** (`/funcionarios/*/equipe`, `/niveis_hierarquicos`, `/vw_organograma_nodes`) — com a autorização ligada cairiam em 403. 21 telas não têm rota mapeada (os pais de menu, `ordens`, `aprovacoes`, `requisicoes`, `dashboard-compras`). As rotas de OC mapeiam para `compras` com criar/editar, não para `aprovacoes`/aprovar. Não mapeiam `/pedidos_liberados`, `/compras/requisicoes/origem/*`, `/produtos/*/fornecedores` nem `/orcamento/*`.
- **Funções de autorização [DDL]:** `fn_autorizar` (fail-closed, valida `token_versao`), `fn_me_permissoes`, `fn_rota_administrativa`, `fn_rota_casa`, `fn_revogar_tokens_usuario`, `fn_criar/validar/revogar_chave_servico`, `fn_login_*`, `fn_registrar_auditoria`, `fn_auditoria_imutavel`, `fn_escopo_vendedores_usuario`, `fn_vendedor_no_escopo`, `fn_vendedores_do_usuario`; views `vw_permissoes_usuario`, `vw_rotas_telas_conferencia`. **`auth.auditoria`:** 128 linhas (02/10 a 07/10; login 62, editar 60, criar 5, excluir 1) — a infraestrutura está pronta e gravando; **se `PERMISSOES_ROTA_MODO` está ligado, o dump não diz.**
- **`auth.chaves_servico`: 0 linhas.** Nenhuma chave de nível leitura/escrita/admin foi cadastrada no banco (relevante para a L6 em [[Chaves-de-Integracao-AvHub-MES-Pipeline]]).

## 5. Contratos × produção

Resultado por contrato (`sim` = objetos existem em produção; "sem uso" = 0 linhas). Numeração do vault.

| Contrato | Produção |
|---|---|
| SQL 001 parceiros fiscais | **Aplicado e populado:** IE preenchida em 14.273 de 22.981 parceiros; `inativo`=true em 3.975. `dados_bancarios`, `endereco_entrega`, `cnaes`, `parceiros_produtos`: 0 linhas |
| SQL 002 `estoque_saldo`, 005 `locais_estoque` | Aplicados, **vazios** (sem recurso na pipeline) |
| SQL 003 frete/parcelas | Aplicado, **vazio**; a chave única é `(codigo_empresa, codigo_pedido_omie[, numero_parcela])` |
| SQL 004 `pedidos_compras` | **Aplicado e populado:** 22.808 pedidos (Vital 21.917, Uberaba 456, HRM 435), 43.973 itens, 31.758 parcelas; índice único `(id_pedido_compra, ordem)`; etapas 10/15/20 = 1.186/20.380/1.242; `incluido_em_omie` até 07/10 14:16 UTC |
| SQL 006 `valor_devolucao` ("invalidado") | **Parcialmente aplicado:** colunas `codigo_devolucao_omie`, `valor_devolucao`, `devolucao_consultada_em` e índice `idx_pedidos_vendas_fila_devolucao`; 0 de 13.137 preenchidas; `devolucao_parcial`=true em 599 |
| SQL 007 OC estruturada, 008 requisições | Aplicados, **vazios**; colunas com nomes diferentes do DDL (`numero_pedido`, `numero_requisicao` são varchar) |
| SQL 009 views sem escopo | **Aplicado** (JOIN de categorias com `codigo_empresa` nas 5 views); `uq_categorias_empresa_codigo`. O pedido 25970 soma R$ 964.763,88 em `produto_vendas` (311 linhas, não 53 — o vault falava em "53 registros") |
| API 004 (referência da OC) | Sem objeto novo; pré-requisitos existem (`ordens_compra_itens_vinculos`, `requisicoes_compra.id_origem`); sem rota no log |
| API 005 | Sem objeto; consistente com o vault |
| 04-Vagas | Trava no banco (`fn_decidir_vaga`, `trg_vaga_proteger_decisao`, `vw_vagas`, `parametros_rh`=7 dias); **14 vagas, as 14 com `deleted_at`**; `vagas_decisoes` vazia; ninguém tem `pode_aprovar` em `solicitacoes-de-vagas` |
| 07 orçamento/coordenadores | **Aplicado e carregado em 02/10:** `orc_categorias` 16, `orc_cotacoes` 2.697, `orc_familias` 25, `orc_fornecedores` 10.524, `orc_produtos` 400, `orc_vinculos` 234; `comissao_coordenadores` 6 (5 `gerencia` + 1 `excecao`, origem `carga_json_2026_10`) + histórico 6; nenhum coordenador com `id_funcionario`; `GET /dashboard/comissoes` 200 em 02/10 |
| 13 fornecedores por produto | `vw_produto_fornecedores` existe (lê `pedidos_compras_itens`; `parceiros_produtos` vazio) |
| 13-Backend / 16 / 18 | Tabelas, triggers, `contadores_documento`, `core.projetos` 113, `contas_correntes` 137, `categorias` 782 existem. **Contrato 16 não como escrito:** as sequences `seq_ordens_compra_numero`/`seq_requisicoes_compra_numero` **não existem**; a numeração usa `contadores_documento` + `fn_proximo_numero_documento` ("OC-000001") |
| 14 Omie pedido de compra / vínculo PV | `codigo_pedido_integracao` existe, **nulo em 22.808 de 22.808**; `vw_pedido_venda_compras*`, `uq_oc_vinculos_item_pv`, `trg_pedidos_compras_comprador_para_oc` |
| 26 liberação | `parametros_vendas`, `pedidos_vendas_liberacao`, `_historico`, `vw_pedidos_liberacao`; **`data_inicio_liberacao` = 01/09/2026** em produção (o vault citava 28/07, valor da api-test); **nenhum pedido liberado**; teto de candidatos: 1.172 pedidos; `/pedidos_liberados` 200 só desde 02/10, nenhum `POST /importado` |
| 28 / 33 | `ck_compradores_periodo`, `vw_vendedor_unidade`, `fn_unidade_do_vendedor`, `fn_vendedor_no_periodo` existem; **`ativo_desde`/`inativo_desde` nulos em 123 de 123 vendedores (35 inativos) e 74 de 74 compradores** |
| 29 NF manual só admin | 6 triggers `trg_notas_fiscais_manual_*`, tela só para Admin (Dev); 2 NFs manuais (29 e 30/09) anteriores à trigger, sem histórico |
| 30 PDF pedido Omie | IE em 14.273 parceiros; `numero_pedido_fornecedor` em 11.967 pedidos; `cnpj_cpf_fornecedor` **nulo em 100%** |
| 31 / 32 | Rotas respondem (200) sem dados; sem objeto de banco novo no 31; `ordens_compra_acompanhamento`, `_contatos`, `_ocorrencias`, `vw_compras_acompanhamento` existem e vazios |
| **34 MES empurra** | **`fn_requisicao_mes_aplicar(uuid,jsonb)` existe, completa** (criar/atualizar/cancelar/409 com OC); `uq_requisicoes_compra_id_origem`; `requisicoes_compra` com 0 linhas e **nenhum PUT** no log |
| 35 marcos | `requisicoes_compra_eventos` (14 tipos), `fn_req_evento*`, 6 triggers `*_zz_eventos`, `trg_req_eventos_imutavel`; 0 linhas; 3 `GET …/eventos` em 02/10 |
| 36 | `ordens_compra_comprador_historico`, `trg_oc_comprador_emissao`, `fn_oc_comprador_do_omie`; 0 linhas |
| 37 | `fn_variacao_pct` existe; as `fn_dashboard_mensal_*` **não a chamam no banco** (o cálculo seria na API) |
| 39 | 30 vendedores ativos sem vínculo (igual ao vault); 71 com funcionário; 25 dos 71 têm unidade do funcionário diferente da do Omie |

Em resumo: **a estrutura está em produção; o uso, não.** Uma OC ou requisição real ainda não passou pelos triggers e funções em produção, então "entregue" vale para o schema, não para o fluxo.

## 6. Compras, pipeline e unidades em produção

- **Espelho do Omie sincronizando:** `pedidos_compras.updated_at` máximo no minuto do dump (07/10 14:24 UTC); `created_at` de 05/10 18:02 a 07/10 (carga em 05 e 06/10). `pedidosCompras`, `compradores`, `categorias`, `condicoesPagamentoCompras`, `projetos` e `contasCorrentes` começaram em **05/10 18:02 UTC** nas 3 filiais (`mogi`, `uberaba`, `hrm`); `*.inativar` com 30 execuções `ok` (06/10 04:47 a 07/10 04:47).
- **`core.cotacoes_moeda`:** USD e EUR, 191 linhas cada, 02/01 a **06/10/2026**; carga em 05/10, PTAX em 06/10 20:30 UTC.
- **Envio da OC ao Omie:** `GET /compras/ordens/fila-omie` uma vez (05/10); **nenhum** `PATCH …/sincronizacao` nem `POST …/reenviar`.
- **Manifestos:** 8.197 linhas (28/11/2025 a 07/10/2026); 604 execuções `ok` do scraping, última 07/10 13:35 UTC; 44 erros, o último em 05/10 (login não confirmado, relatório não carregou, timeout). **O scraping roda.**
- **Erros no `run_log`:** 500 em `exclusion_sync_curta` (497 em mogi, 490 deles HTTP 500, até 07/10; 1 a 25 por dia na última semana); `produtos` 9 erros e nenhuma execução OK nos recursos de ciclo; `sync_*` só registram `enqueued` (a saúde se prova pelos dados). `omie_raw.*`: **as 5 tabelas ainda existem no banco** (vazias), embora o código tenha sido removido.
- **`parametros_compras`:** 2 linhas (Vital e Uberaba, limite R$ 30.000, 02/10) — **sem linha para a HRM**.
- **`core.unidades`:** `id_unidade_compra` **nulo nas 3 unidades**; a HRM tem `codigo_empresa_omie` e IE nulos, mas tem 12.619 parceiros, 9 compradores, 208 categorias, 125 condições de pagamento e 435 pedidos de compra espelhados. A trigger `fn_ordens_compra_nascer` só recusa OC se `id_unidade_compra` estiver preenchido.
- **Compradores:** 74 (52 ativos); **20 com `id_funcionario`** (17 Vital, 2 Uberaba, 1 HRM; todos gravados em 07/10 12:10 UTC); 54 sem vínculo (32 ativos e 22 inativos). Em 3 dos 20 a unidade do funcionário difere do Omie do comprador.
- **Vendedores:** 123 (88 ativos; 71 com funcionário; 30 ativos sem vínculo).

## 7. Outros domínios (agregados)

- **Vendas:** `pedidos_vendas` 13.137 (matriz 12.924, Uberaba 116, HRM 97; faturados 9.892, cancelados 257, devolvidos 559; inclusão de 19/12/2023 a 07/10/2026; 1.713 incluídos desde 01/09); `notas_fiscais` 10.950 (2 manuais); `produto_vendas` 36.538; `refaturamentos` 449; `blacklist_pedidos` 19; `blacklist_vendedor_g5` 8; `metas_mensais` 20; `diligenciador_vendedor` 51 (19 apagadas); `pedido_observacao_pcp` 6.
- **Fechamento manual:** **17 registros** (16 de jan a ago/2026, criados em 10/09; o 17º é o faturamento de set/2026, criado em 01/10). O vault dizia "16 registros, zero desde set/2026".
- **Comissões:** `simulacoes` 14, `simulacao_itens` 21, `comissao_coordenadores` 6, `regras_comissoes_fixas` 5 (1 apagada), `bloqueio_comissoes` 2, `blacklist_comissoes_vendedores` 8; nomes de tabela no plural em produção (o vault usa o singular).
- **RH/organograma:** `core.funcionarios` 202 (matriz 178, Uberaba 15, HRM 9; nenhum com data de desligamento; CPF nulo em 202 de 202, não dá para saber se anonimizado), `core.setores` 58, `core.cargos` 137, `core_organograma.node` 394 nós, `nivel_hierarquico` 13, `historia_timeline` 8.
- **Parceiros:** 22.981 (o vault dizia 10.065, que é o número da matriz hoje: 10.094).
- **`core_compras` antigo:** `produtos_compras` 0 linhas; as 4 views antigas e `vw_produto_fornecedores` presentes; **o conteúdo antigo não foi apagado** — existem as 6 tabelas `orc_*` e 6 views `orc_vw_*`. O `codigo_pedido_compra_omie` é `bigint` (o vault dizia `integer`).

## 8. O que o vault afirmava e a produção contradiz (corrigido nas notas)

1. MES "real e em produção" (Rota-Fabricacao, Fluxogramas-Completos, Home, Comece-Aqui) → implantado, mas banco vazio e na `main` de 28/08.
2. "0 dos 74 compradores ligados" → 20 de 74 em 07/10 (Onde-Estamos, Indice-Contratos, 38, CA-03).
3. "`fn_requisicao_mes_aplicar` não está em nenhum SQL" → existe em produção (contrato 34); o que falta é uso.
4. Contrato 07 "desconsiderado" → aplicado e carregado em produção.
5. Contrato 006 "invalidado" → colunas aplicadas, vazias.
6. Contrato 26 "corte 28/07" → em produção é 01/09/2026 e nenhum pedido foi liberado.
7. Contrato 16 (sequences) e 13-Backend B14 (HRM→Mogi, sem cadastros) → superados pelo banco.
8. Contrato 04-Vagas "entregue" → em produção nenhuma vaga ativa e ninguém pode decidir.
9. Contratos 28/33 (`ativo_desde`/`inativo_desde`) → colunas existem, **sem dado** em todos os vendedores e compradores.
10. Fechamento manual 16 → 17 registros; parceiros 10.065 → 22.981; `core_compras` "apagado" → o conteúdo `orc_*` está lá.
11. A Auditoria de 21/09 dizia 74 tabelas e 18 views; hoje 116 e 40 (crescimento, não erro da época).

## 9. Objetos de produção que nenhuma nota descrevia

Schema `historico` e `pg_cron` (e as funções `fn_snapshot_mensal`, `fn_resolver_refaturamento_lote`); pedidos de venda manuais (`pedidos_vendas_manuais_historico`, `seq_pedidos_vendas_manual`, tela `pedidos-vendas-manuais`); `auth.rotas_administrativas`, `login_tentativas`, `ip_regras`, `sessions`, `usuarios_favoritos`; funções de autorização, de vagas (`fn_decidir_vaga`...), de organograma (`fn_definir_reporta_a`, `fn_travar_hierarquia`), de comissão (`fn_comissao_coordenadores_mes`), de vendas (`fn_pedidos_venda*`, `fn_quadro_deducoes`, `fn_painel_*`); views `vw_comissao_*`, `vw_vagas`, `vw_org_nodes`, `vw_hierarquia_pessoas`, `vw_etapas_fluxo_pedido`, `vw_faturamento_planilha_notas`; tabelas de organograma `historia*` e `welcome_*`. Os comentários de numeração do DBA nos DDL ("Contrato 11, 16, 22, 24, 25, 28, 30, 36") **não coincidem com a numeração deste vault** — cuidado ao cruzar.

## 10. O que o dump não permite verificar

Variáveis de ambiente em produção (`PERMISSOES_ROTA_MODO`, `ESCOPO_*`, `IDENTIDADE_EXIGIR_TOKEN`, `SYNC_ENVIO_OC`, `ENVIO_OC_DRY_RUN`, `FILIAIS_ATIVAS`); se o front já consome `/orcamento/*` e `/dashboard/comissoes`; se a API de produção roda a `main` `fdafb35`; `variacao_pct` (calculada na API); a taxa de sucesso por recurso (o `run_log` só tem `enqueued`); a correspondência filial↔unidade da pipeline (inferida); se o MES real roda em outro banco.

## Ver também
- [[Onde-Estamos]] · [[Indice-Contratos]] · [[Perguntas-em-Aberto-Consolidadas]] (CC-10 a CC-16)
- [[Auditoria-Dump-Producao-2026-09-21]] · [[Auditoria-Dump-Producao-2026-09-22]]
- [[AV-Hub-API-Estado-Atual]] · [[AV-Hub-Comercial-Suprimentos]] · [[App-PCP-Recebimento-Conferencia]] · [[Chaves-de-Integracao-AvHub-MES-Pipeline]]
