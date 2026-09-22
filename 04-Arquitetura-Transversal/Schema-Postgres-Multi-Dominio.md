---
tags: [erp-acos-vital, arquitetura, postgres]
criado: 2026-09-16
---

# Convenção: Schema Postgres por Domínio

Padrão em produção, confirmado por leitura direta do código-fonte completo de `api-acos-vital`: um único cluster Postgres com **schemas separados por domínio de negócio**.

## Schemas confirmados (inventário completo)

- **`core`** — `funcionarios`, `usuarios`(?), `unidades`, `cargos`, `setores`, `categorias`, `cnaes`, `documentos_anexos`, `familia_produtos`, `origem_dados`, `parceiros`, `parceiros_produtos`, `parceiros_tipos`, `produtos`, `tipos_parceiro`, `etapas_faturamento`. Nota: `usuarios` na verdade vive em `auth`, não em `core`. **`etapas_faturamento` existe de verdade** — a tabela tem estrutura real (`codigo_operacao`, `codigo_etapa`, `descricao_padrao`, `descricao`) e é candidata forte a alimentar o "dicionário de nomes para `etapa`" pendente do Portal do Vendedor — ver [[AV-Hub-Portal-Vendedor-Plano]].
- **`auth`** — `usuarios`, `perfis`, `telas`, `permissoes`, `usuarios_perfis`, `usuarios_favoritos`, `usuarios_unidades`, `ip_regras`, `logs`, `sessions`. RBAC do av-hub — ver [[AV-Hub-RBAC]].
- **`core_vendas_faturamento`** — `vendedores`, `pedidos_vendas`, `pedidos_vendas_status_historico`, `notas_fiscais`, `produto_vendas`, `vw_vendas_base`/`vw_nf_classified` (views curadas), `vw_vendas_planilha`/`vw_faturamento_planilha` + `_resumo` (views cruas), `vw_pedido_venda_itens`, `vw_clientes_inativos`, `blacklist_pedidos`, `blacklist_destinatarios`, `blacklist_vendedor_g5` (substituiu `blacklist_vendedores`), `refaturamentos`, `diligenciador_vendedor`, `auxiliar_vendedor`, `metas_mensais`, `fechamento_manual`, `manifestos`, `cfop`, `pessoa_vendedor`, `comissoes_provisoria`. Ver [[AV-Hub-Vendas-Reconciliacao]]. `pedidos_vendas_status_historico` só rastreia 2 campos (`CHECK campo IN ('situacao','data_previsao')`) — log parcial, não histórico completo de toda mudança.
- **`core_compras`** — **conteúdo apagado, schema mantido** (confirmado pelo Nathan, 22/09/2026). Tinha só `produtos_compras` (vínculo produto↔fornecedor, sem model/rota implementados, 0 linhas) + 4 views (`vw_catalogo_de_produtos`, `vw_fornecedores_com_produtos`, `vw_historico_precos`, `vw_todos_os_fornecedores`), 3 delas quebradas em runtime (bug de schema `negocio`) — investigado a fundo em [[AV-Hub-Views-Compras-Investigacao]], não cobria nem parcialmente o futuro módulo de Compras. **O nome do schema não muda** — o Gustavo vai reconstruir o conteúdo de dentro dele de forma estruturada, formato ainda não definido. **Nota de verificação**: o dump/container local usado nesta investigação (22/09, 11:42) é anterior a esta remoção — ainda mostra o `core_compras` antigo (com `produtos_compras` e as 4 views); não é contradição, é só uma cópia mais antiga que a produção atual.
- **`core_comissionamento`** — schema novo: `regra_comissao_fixa`, `blacklist_comissao_vendedor`/`blacklist_comissao_destinatario` (distintas das blacklists G4/G5 — só bloqueiam, não deduzem em cascata), `bloqueio_comissao`, `simulacao`/`simulacao_item`, `simulador_parametro`, `vw_simulacao_resolvida`. Ver [[AV-Hub-Comissao-Modulo]].
- **`core_aprovacao_de_vagas`** — schema novo: `vaga` — a tela de Solicitações de Vagas (aprovação de headcount) tem schema próprio, separado de `core`.
- **`omie_ctl`/`omie_raw`** — schemas **próprios do pipeline ELT** (não de negócio): `omie_ctl.run_log` (auditoria de execução por filial/recurso/tier) e `omie_raw.*` (staging jsonb opcional, só se `RAW_AUDIT_ENABLED=true`). Ver [[Omie-ELT-Pipeline]].
- **`core_estoque`** — existe como schema reservado no cluster do av-hub, **100% vazio** (confirmado nas auditorias de 21/09 e 22/09) — não confundir com o Estoque do MES (banco separado, ver linha abaixo).
- **`estoque`** — o Estoque não entra neste cluster: mora no banco separado do MES (Prisma), com schema Postgres próprio lá dentro, seguindo esta mesma convenção — não cai em `public`. Ver [[MES-Arquitetura-Decisoes]].

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
- [[Auditoria-Dump-Producao-2026-09-21]] e [[Auditoria-Dump-Producao-2026-09-22]]
- [[AV-Hub-Views-Compras-Investigacao]] — motivo da decisão de apagar `core_compras`
