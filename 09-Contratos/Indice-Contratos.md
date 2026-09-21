---
tags: [contrato-sql, contrato-api, indice]
criado: 2026-09-17
atualizado: 2026-09-21
---

# Contratos — ERP Aços Vital

Seção dedicada só a **contratos** — documentos formais de mudança que precisam de aprovação/execução de outra pessoa antes do código poder avançar: contratos de **banco de dados** (para o DBA, Gustavo) e contratos de **API** (para o dev que for implementar). Cada contrato é auto-contido: alguém pode abrir só aquele arquivo, entender o "por quê", o "o quê" exato (schema ou request/response) e o que falta decidir, sem precisar ler o resto do projeto.

## Como está organizado

- **[[001-Produtos-Parceiros-Filtro-Incremental|1. Contratos de API]]** — mudanças de contrato de request/response em endpoints REST já existentes, ou endpoints novos. Pasta `02-Contratos-API/`.
- **2. Contratos SQL para o DBA** — DDL proposto (CREATE/ALTER TABLE), pronto para o Gustavo revisar e aplicar. Pasta `01-Contratos-SQL-DBA/`: [[001-Parceiros-Dados-Fiscais]], [[002-Estoque-Saldo]], [[003-Pedidos-Vendas-Frete-Parcelas]], [[004-Pedidos-Compras]], [[005-Locais-Estoque]], [[006-Pedidos-Vendas-Valor-Devolucao]].

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
| [[004-Pedidos-Compras]] | SQL | `pedidos_compras` (novo) | **aplicada** (confirmado no dump 21/09) — risco do `numero_item_omie` **resolvido em 21/09**: identidade do item passou a ser `(id_pedido_compra, ordem)` |
| [[005-Locais-Estoque]] | SQL | `core.locais_estoque` (novo) | **aplicada** (confirmado no dump 21/09) — sem FK para `deposito` por decisão (tabela ainda não existe); Gustavo adiciona quando ela existir |
| [[006-Pedidos-Vendas-Valor-Devolucao]] | SQL | `pedidos_vendas.valor_devolucao` | **invalidado** (frontmatter do arquivo já dizia isso desde 17/09; este índice estava com a inconsistência I-02, agora corrigida) |
| [[001-Produtos-Parceiros-Filtro-Incremental]] | API | `?alterado_desde=` em produtos/parceiros (av-hub) | **aplicada** (confirmado em `src/routes/produtos.js`/`parceiros.js`) |
| [[002-Material-Alias-Omie-MES]] | API | `material_alias_omie` — vínculo de duplicata (destinatário: MES/Estoque) | proposta (confirmado: segue não implementada, `api-pcp` não tem essa tabela/endpoint) |

## Ver também
- [[Roteiro-de-Implementacao]]
- [[Decisoes-Chave-ERP]]
- [[Campos-e-API-para-Rastreabilidade]] — lista de tabelas, campos e endpoints novos para rastreabilidade; cada bloco vira contrato SQL ou de API aqui depois que a spec F1 for aprovada.
