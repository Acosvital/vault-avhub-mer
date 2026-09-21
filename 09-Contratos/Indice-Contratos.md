---
tags: [contrato-sql, contrato-api, indice]
criado: 2026-09-17
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

## Status atual (17/09/2026)

Nenhum dos contratos abaixo foi aplicado ainda — todos têm pelo menos uma
pergunta em aberto documentada no próprio arquivo.

| Contrato | Tipo | Assunto | Status |
|---|---|---|---|
| [[001-Parceiros-Dados-Fiscais]] | SQL | `core.parceiros` + dados fiscais | proposta |
| [[002-Estoque-Saldo]] | SQL | `core.estoque_saldo` (novo) | proposta |
| [[003-Pedidos-Vendas-Frete-Parcelas]] | SQL | `pedidos_vendas` + frete/parcelas | proposta |
| [[004-Pedidos-Compras]] | SQL | `pedidos_compras` (novo) | proposta |
| [[005-Locais-Estoque]] | SQL | `core.locais_estoque` (novo) | proposta |
| [[006-Pedidos-Vendas-Valor-Devolucao]] | SQL | `pedidos_vendas.valor_devolucao` | proposta |
| [[001-Produtos-Parceiros-Filtro-Incremental]] | API | `?alterado_desde=` em produtos/parceiros (av-hub) | proposta |
| [[002-Material-Alias-Omie-MES]] | API | `material_alias_omie` — vínculo de duplicata (destinatário: MES/Estoque) | proposta |

## Ver também
- [[Roteiro-de-Implementacao]]
- [[Decisoes-Chave-ERP]]
- [[Campos-e-API-para-Rastreabilidade]] — lista de tabelas, campos e endpoints novos para rastreabilidade; cada bloco vira contrato SQL ou de API aqui depois que a spec F1 for aprovada.
