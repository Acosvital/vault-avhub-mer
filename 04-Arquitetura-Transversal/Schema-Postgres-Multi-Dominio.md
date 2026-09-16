---
tags: [erp-acos-vital, arquitetura, postgres]
criado: 2026-09-16
atualizado: 2026-09-16
---

# Convenção: Schema Postgres por Domínio

Padrão em produção, confirmado por leitura direta do código-fonte completo de `api-acos-vital`: um único cluster Postgres com **schemas separados por domínio de negócio**.

## Schemas confirmados (inventário completo desta rodada)

- **`core`** — `funcionarios`, `usuarios`(?), `unidades`, `cargos`, `setores`, `categorias`, `cnaes`, `documentos_anexos`, `familias_produtos`, `origem_dados`, `parceiros`, `parceiros_produtos`, `parceiros_tipos`, `produtos`, `tipos_parceiro`. Nota: `usuarios` na verdade vive em `auth`, não em `core` — corrigido nesta rodada.
- **`auth`** — `usuarios`, `perfis`, `telas`, `permissoes`, `usuarios_perfis`, `usuarios_favoritos`, `usuarios_unidades`, `ip_regra`, `log_acesso`. RBAC do av-hub — ver [[AV-Hub-RBAC]].
- **`core_vendas_faturamento`** — `vendedores`, `pedidos_vendas`, `pedidos_vendas_status_historico` (log de status já existe!), `nota_fiscal_saida`, `produto_vendas`, `vw_vendas_base`/`vw_nf_classified` (views curadas), `vw_vendas_planilha`/`vw_faturamento_planilha` + `_resumo` (views cruas), `blacklist_pedidos`, `blacklist_destinatarios`, `blacklist_vendedor_g5` (substituiu `blacklist_vendedores`, removida 09/2026), `refaturamentos`, `diligenciador_vendedor`, `auxiliar_vendedor`, `clientes_inativos`, `metas_mensais`, `fechamento_manual`, `manifestos`, `cfop`, `pessoa_vendedor`, `comissao_provisoria`. Ver [[AV-Hub-Vendas-Reconciliacao]].
- **`core_comissionamento`** — schema **novo, descoberto nesta rodada**: `regra_comissao_fixa`, `blacklist_comissao_vendedor`/`blacklist_comissao_destinatario` (distintas das blacklists G4/G5 — só bloqueiam, não deduzem em cascata), `bloqueio_comissao`, `simulacao`/`simulacao_item`, `simulador_parametro`, `vw_simulacao_resolvida`. Ver [[AV-Hub-Comissao-Modulo]].
- **`core_aprovacao_de_vagas`** — schema **novo, descoberto nesta rodada**: `vaga` — a tela de Solicitações de Vagas do RH tem schema próprio, separado de `core`.
- **`core_organograma`** — `node`, `nivel_hierarquico`, mais **`historia`/`historia_imagem`/`historia_timeline`** (seção institucional "Nossa História") e **`welcome_preset`/`welcome_settings`** (onboarding) — mais amplo do que só a árvore hierárquica. Ver [[Organograma-Visao-Geral]].
- **`omie_ctl`/`omie_raw`** — schemas **próprios do pipeline ELT** (não de negócio): `omie_ctl.run_log` (auditoria de execução por filial/recurso/tier) e `omie_raw.*` (staging jsonb opcional, só se `RAW_AUDIT_ENABLED=true`). Ver [[Omie-ELT-Pipeline]].
- **`estoque`** (proposto, ainda não criado) — schema isolado do [[PRD-Estoque-Visao-Geral|PRD do Estoque]], mesma convenção.

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
- [[Organograma-Visao-Geral]]
- [[RH-Escopo-Row-Level-Security]]
- [[AV-Hub-Comissao-Modulo]]
- [[Omie-ELT-Pipeline]]
