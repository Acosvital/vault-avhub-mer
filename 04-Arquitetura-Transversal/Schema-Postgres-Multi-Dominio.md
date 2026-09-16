---
tags: [erp-acos-vital, arquitetura, postgres]
criado: 2026-09-16
atualizado: 2026-09-16
---

# Convenção: Schema Postgres por Domínio

Padrão em produção, confirmado por leitura direta do código-fonte completo de `api-acos-vital`: um único cluster Postgres com **schemas separados por domínio de negócio**.

## Schemas confirmados (inventário completo desta rodada)

- **`core`** — `funcionarios`, `usuarios`(?), `unidades`, `cargos`, `setores`, `categorias`, `cnaes`, `documentos_anexos`, `familia_produtos`, `origem_dados`, `parceiros`, `parceiros_produtos`, `parceiros_tipos`, `produtos`, `tipos_parceiro`, `etapas_faturamento`. Nota: `usuarios` na verdade vive em `auth`, não em `core`. ✅ **`etapas_faturamento` existe de verdade** (confirmado no dump, 16/09) — a nota anterior ("endpoint pronto, tabela ainda não criada pelo DBA") estava desatualizada; a tabela já tem estrutura real (`codigo_operacao`, `codigo_etapa`, `descricao_padrao`, `descricao`) e é candidata forte a alimentar o "dicionário de nomes para `etapa`" pendente do Portal do Vendedor — ver [[AV-Hub-Portal-Vendedor-Plano]].
- **`auth`** — `usuarios`, `perfis`, `telas`, `permissoes`, `usuarios_perfis`, `usuarios_favoritos`, `usuarios_unidades`, `ip_regras`, `logs`, `sessions`. RBAC do av-hub — ver [[AV-Hub-RBAC]]. ✅ Nomes confirmados por leitura direta do dump real (16/09) — eram `ip_regra`/`log_acesso` (singular) na documentação anterior, corrigido pra `ip_regras`/`logs` (plural, nomes reais das tabelas).
- **`core_vendas_faturamento`** — `vendedores`, `pedidos_vendas`, `pedidos_vendas_status_historico`, `notas_fiscais` (⚠️ nome real confirmado no dump — não `nota_fiscal_saida`), `produto_vendas`, `vw_vendas_base`/`vw_nf_classified` (views curadas), `vw_vendas_planilha`/`vw_faturamento_planilha` + `_resumo` (views cruas), `vw_pedido_venda_itens`, `vw_clientes_inativos`, `blacklist_pedidos`, `blacklist_destinatarios`, `blacklist_vendedor_g5` (substituiu `blacklist_vendedores`, removida 09/2026), `refaturamentos`, `diligenciador_vendedor`, `auxiliar_vendedor`, `metas_mensais`, `fechamento_manual`, `manifestos`, `cfop`, `pessoa_vendedor`, `comissoes_provisoria`. Ver [[AV-Hub-Vendas-Reconciliacao]]. `pedidos_vendas_status_historico` só rastreia 2 campos (`CHECK campo IN ('situacao','data_previsao')`) — log parcial, não histórico completo de toda mudança.
- **`core_compras`** — schema **novo, confirmado no dump (16/09)**: só `produtos_compras` (vínculo produto↔fornecedor: `id_produto` + `codigo_empresa`, nada além disso) + 4 views (`vw_catalogo_de_produtos`, `vw_fornecedores_com_produtos`, `vw_historico_precos`, `vw_todos_os_fornecedores`). Confirma que **não existe sistema de compras real hoje** no av-hub — é só o vínculo que alimenta o módulo Orçamento.
- **`core_comissionamento`** — schema **novo, descoberto nesta rodada**: `regra_comissao_fixa`, `blacklist_comissao_vendedor`/`blacklist_comissao_destinatario` (distintas das blacklists G4/G5 — só bloqueiam, não deduzem em cascata), `bloqueio_comissao`, `simulacao`/`simulacao_item`, `simulador_parametro`, `vw_simulacao_resolvida`. Ver [[AV-Hub-Comissao-Modulo]].
- **`core_aprovacao_de_vagas`** — schema **novo, descoberto nesta rodada**: `vaga` — a tela de Solicitações de Vagas (aprovação de headcount) tem schema próprio, separado de `core`.
- **`omie_ctl`/`omie_raw`** — schemas **próprios do pipeline ELT** (não de negócio): `omie_ctl.run_log` (auditoria de execução por filial/recurso/tier) e `omie_raw.*` (staging jsonb opcional, só se `RAW_AUDIT_ENABLED=true`). Ver [[Omie-ELT-Pipeline]].
- ~~**`estoque`** (proposto, ainda não criado) — schema isolado do [[PRD-Estoque-Visao-Geral|PRD do Estoque]], mesma convenção.~~ ⚠️ **Desatualizado (16/09):** o Estoque não entra mais neste cluster — passa a morar no banco separado do MES (Prisma). ✅ Resolvido: ganha um schema Postgres próprio lá dentro, seguindo esta mesma convenção — não cai em `public`. Ver [[MES-Arquitetura-Decisoes]].

## Como o schema é gerido — achado importante

`api-acos-vital` **não roda `sequelize.sync()` e não tem pasta `migrations/` nem arquivos `.sql`** — o schema é gerido inteiramente por um DBA fora do repositório da API; a evolução fica documentada só em comentários de prosa nos próprios arquivos de model ("coluna adicionada em 09/2026", "corrigido tal bug em tal data"). Isso é bem diferente do `api-pcp` (Prisma, com migrations versionadas no próprio repo) — **duas filosofias de gestão de schema coexistindo no mesmo ERP**, vale decisão consciente para o Estoque.

## Por que isso importa

Qualquer módulo novo do ERP deveria seguir a convenção de schema isolado por domínio — já é o padrão estabelecido. O [[App-PCP-Visao-Geral|app-pcp]] tem seu **próprio banco/schema via Prisma**, completamente fora deste cluster.

## Views curadas vs. projeções cruas

Padrão recorrente: uma tabela/projeção **crua** com flags booleanas independentes e uma **view curada** por cima que classifica em grupos mutuamente exclusivos. Ver [[AV-Hub-Vendas-Reconciliacao]] para o catálogo completo, incluindo a correção da ordem real da cascata (G1>G2>G2P>G3>G4>G5>G6>LÍQUIDO) e a divergência intencional entre views e a função de resumo mensal.

## Ver também
- [[AV-Hub-Arquitetura-BFF]]
- [[Estoque-Modelo-Dados]]
- [[Infraestrutura-Self-Hosted]]
- [[AV-Hub-Comissao-Modulo]]
- [[Omie-ELT-Pipeline]]
