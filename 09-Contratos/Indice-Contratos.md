---
tags: [contrato-sql, contrato-api, indice]
criado: 2026-09-17
atualizado: 2026-09-23
---

# Contratos — ERP Aços Vital

Seção dedicada só a **contratos** — documentos formais de mudança que precisam de aprovação/execução de outra pessoa antes do código poder avançar: contratos de **banco de dados** (para o DBA, Gustavo) e contratos de **API** (para o dev que for implementar). Cada contrato é auto-contido: alguém pode abrir só aquele arquivo, entender o "por quê", o "o quê" exato (schema ou request/response) e o que falta decidir, sem precisar ler o resto do projeto.

## Como está organizado

- **[[001-Produtos-Parceiros-Filtro-Incremental|1. Contratos de API]]** — mudanças de contrato de request/response em endpoints REST já existentes, ou endpoints novos. Pasta `02-Contratos-API/` (ainda em aberto) e `Realizados/02-Contratos-API/` (já aplicados).
- **2. Contratos SQL para o DBA** — DDL proposto (CREATE/ALTER TABLE), pronto para o Gustavo revisar e aplicar. Pasta `01-Contratos-SQL-DBA/` (ainda em aberto): [[006-Pedidos-Vendas-Valor-Devolucao]] e **[[009-Categoria-Sem-Escopo-Empresa-Views]]** (24/09/2026 — bug real: 4 views duplicam registro quando o código de categoria existe em mais de uma unidade; testado e corrigido no banco local, valor de um pedido caiu de R$ 1,4M pra R$ 964k depois do fix).
- **3. [[Indice-Logica-Fora-do-Backend|Contratos de lógica fora do backend]]** — importados de `av-hub/docs/` (arquivos marcados `ENVIAR`) em 23/09/2026: filtro/ordenação/paginação/permissão que hoje rodam no navegador em vez do banco/API. Pasta `03-Contratos-Logica-Fora-Backend/`. **Prioridade: Compras.** O fluxo base já foi entregue ([[01-Compras-Fluxo-Completo]], em Realizados). **O que falta está consolidado em dois contratos (23/09/2026): [[22-Compras-Backend-Consolidado]] (banco + API, B0–B9) e [[23-Compras-Pipeline-Consolidado]] (`omie-elt-pipeline`, L1–L10).** Os detalhes continuam em [[15-Compras-Pendencias-Pos-Backend]], [[14-Compras-Omie-Pedido-Compra]] (envio da OC ao Omie, espelho dos pedidos de compra e as três observações), [[16-Compradores-Funcionario]], [[20-Compras-Cotacao-Moeda-PTAX]] (cotação automática do dólar/euro na OC) [[21-Compras-Projetos-Omie]] (projetos do Omie para a OC) e [[24-Compras-Vinculo-Pedido-Venda]] (vínculo da OC com o pedido de venda). **[[25-Compras-Historico-Unificado]]** (24/09/2026) estende o vínculo do 24 para fora do escopo de um PV: Ordens de compra e Dashboard de compras também mostram o histórico do Omie (antes do av-hub) unificado com as OCs do av-hub — pedido do Nathan, para não perder histórico. [[17-Compras-Pedido-DBA-Banco]], [[18-Compras-Pedido-API-Backend]] e [[19-Compras-Pedido-Pipeline-Omie]] foram substituídos pelos consolidados e ficam como histórico.
- **Realizados** — contratos SQL e de API já aplicados em produção (status `aplicada`). Pasta `Realizados/01-Contratos-SQL-DBA/`: [[001-Parceiros-Dados-Fiscais]], [[002-Estoque-Saldo]], [[003-Pedidos-Vendas-Frete-Parcelas]], [[004-Pedidos-Compras]], [[005-Locais-Estoque]], [[007-Ordens-Compra-Estruturada]], [[008-Requisicoes-Compra]]. Pasta `Realizados/02-Contratos-API/`: [[001-Produtos-Parceiros-Filtro-Incremental]]. Pasta `Realizados/03-Contratos-Logica-Fora-Backend/`: [[01-Compras-Fluxo-Completo]].

## Convenção de todo contrato

- **Status** no frontmatter (`proposta` / `aplicada` / `rejeitada`) — atualizar aqui quando o status mudar no mundo real, esta é a fonte de verdade sobre "o que já foi feito".
- **Por quê** — motivação, sem jargão de implementação.
- **O contrato em si** — DDL exato (contratos SQL) ou request/response exato (contratos de API).
- **Perguntas em aberto** — o que precisa de decisão humana antes de aplicar. Nenhum contrato deveria ser aplicado com pergunta em aberto não respondida.
- **Depois de aplicado** — o que o dev precisa fazer no código depois que o outro lado (DBA, ou o próprio dev) aplicar a mudança.

## Origem

Os contratos SQL 001-006 desta seção nasceram como contratos 006-011 no
repositório `omie-elt-pipeline` (`sql/dba_migrations/`), onde os contratos
001-005 daquele repositório já existem com numeração própria (001, 002, 004
e 005 já aplicados; 003 rejeitado e mantido só como histórico). Os arquivos
originais nesse repositório agora apontam pra cá, para não duplicar/
desatualizar duas cópias — esta seção é a versão viva, com numeração
própria (001 em diante) independente da numeração do outro repositório.

## Status atual (21/09/2026 — confirmado contra dump de produção)

> **Atualização de 21/09:** o dump `dump-avhub_prd_db-202609210741.sql` (produção, gerado 21/09 07:41) mostra que 5 dos 6 contratos SQL e o contrato de API 001 **já estão aplicados** — este índice estava desatualizado desde 17/09. Ver o depara completo, coluna a coluna, em [[Auditoria-Dump-Producao-2026-09-21]]. Cada arquivo de contrato individual ainda precisa ter o próprio frontmatter `status` atualizado por quem tiver posse dele (não alterado aqui para não sobrescrever perguntas em aberto específicas de cada arquivo).

| Contrato | Tipo | Assunto | Status |
|---|---|---|---|
| [[001-Parceiros-Dados-Fiscais]] | SQL | `core.parceiros` + dados fiscais | **aplicada** (confirmado no dump 21/09; `dadosBancarios`/`enderecoEntrega` vêm por endpoint próprio; `chave_pix` ajustada para `varchar(255)`) |
| [[002-Estoque-Saldo]] | SQL | `core.estoque_saldo` (novo) | **aplicada** (confirmado no dump 21/09; "foto atual" confirmado como a implementação real) |
| [[003-Pedidos-Vendas-Frete-Parcelas]] | SQL | `pedidos_vendas` + frete/parcelas | **aplicada** (confirmado no dump 21/09) |
| [[004-Pedidos-Compras]] | SQL | `pedidos_compras` (novo) | **aplicada** — risco do `numero_item_omie` **resolvido na prática em 22/09** (design decidido em 21/09, migration confirmada no dump de 22/09): identidade do item é `(id_pedido_compra, ordem)`, com índice único aplicado |
| [[005-Locais-Estoque]] | SQL | `core.locais_estoque` (novo) | **aplicada** (confirmado no dump 21/09) — sem FK para `deposito` por decisão (tabela ainda não existe); Gustavo adiciona quando ela existir |
| [[006-Pedidos-Vendas-Valor-Devolucao]] | SQL | `pedidos_vendas.valor_devolucao` | **invalidado** (frontmatter do arquivo já dizia isso desde 17/09; este índice estava com a inconsistência I-02, agora corrigida) |
| [[009-Categoria-Sem-Escopo-Empresa-Views]] | SQL | `vw_vendas_planilha`, `vw_vendas_base`, `vw_nf_classified`, `vw_faturamento_planilha` — JOIN de `core.categorias` sem `codigo_empresa` | **proposta**, testado e corrigido no banco local em 24/09/2026 (achado investigando um bug de tela) — pendente aplicar em teste/produção |
| [[001-Produtos-Parceiros-Filtro-Incremental]] | API | `?alterado_desde=` em produtos/parceiros (av-hub) | **aplicada** (confirmado em `src/routes/produtos.js`/`parceiros.js`) |
| [[002-Material-Alias-Omie-MES]] | API | `material_alias_omie` — vínculo de duplicata (destinatário: MES/Estoque) | **rejeitada em 21/09/2026** — decisão do Nathan: duplicata de catálogo sai do escopo deste sistema, resolve-se direto no Omie |
| [[003-Requisicao-Compra-Integracao-MES]] | API | Requisição de compra, MES → av-hub (Fluxo 1 da spec F1) | **proposta** — aprovada por Nathan em 22/09/2026; aprovação formal de Robert e Gustavo ainda pendente |
| [[004-Referencia-OC-Integracao-MES]] | API | Referência da OC, av-hub → MES (Fluxo 2 da spec F1) | **proposta** — aprovada por Nathan em 22/09/2026; contrato SQL [[007-Ordens-Compra-Estruturada]] já aplicado; aprovação formal de Robert e Gustavo ainda pendente |
| [[005-Status-Item-Integracao-MES]] | API | Status por item, MES → av-hub (Fluxo 3 da spec F1) | **proposta** — aprovada por Nathan em 22/09/2026; aprovação formal de Robert e Gustavo ainda pendente |
| [[007-Ordens-Compra-Estruturada]] | SQL | `core_vendas_faturamento.ordens_compra` + itens + parcelas — OC decidida no av-hub (E2) | **aplicada** — confirmado em 23/09/2026 (`api-acos-vital` PR #273, junto com o 008); o aplicado difere do DDL em nomes e regras (ver o topo do arquivo). Envio ao Omie ainda não existe |
| [[008-Requisicoes-Compra]] | SQL | `core_vendas_faturamento.requisicoes_compra` (novo) — caixa de entrada de Compras (E1) | **aplicada** — confirmado em 23/09/2026 (`api-acos-vital` PR #273, junto com o 007); o aplicado difere do DDL em nomes e nulidade (ver o topo do arquivo) |

## Ver também
- [[Roteiro-de-Implementacao]]
- [[Decisoes-Chave-ERP]]
- [[Campos-e-API-para-Rastreabilidade]] — lista de tabelas, campos e endpoints novos para rastreabilidade; cada bloco vira contrato SQL ou de API aqui depois que a spec F1 for aprovada.
- [[Auditoria-Dump-Producao-2026-09-21]] e [[Auditoria-Dump-Producao-2026-09-22]] — depara completo contra dump de produção
