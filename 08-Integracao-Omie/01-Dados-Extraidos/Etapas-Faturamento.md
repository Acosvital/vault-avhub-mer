---
tags: [integracao-omie, dados-extraidos]
criado: 2026-09-17
---

# Etapas de Faturamento

Fonte: Omie `ListarEtapasFaturamento` (`/produtos/etapafat/`), resource `etapasFaturamento.ts`. **Status: implementado** — a tabela de destino já existe no banco do DBA (a migration `sql/dba_migrations/005_etapas_faturamento_contrato.md` do próprio pipeline foi aplicada). Payload vem aninhado (`cadastros[].etapas[]`) e é achatado antes do mapeamento.

Destino: `core.etapas_faturamento`. Chave de conflito: `(codigo_empresa, codigo_operacao, codigo_etapa)`.

| Coluna | Campo/origem Omie |
|---|---|
| codigo_empresa | filial |
| codigo_operacao | `cCodOperacao` |
| descricao_operacao | `cDescOperacao` |
| codigo_etapa | `Number(etapa.cCodigo)` (smallint) |
| descricao_padrao | `etapa.cDescrPadrao` |
| descricao | `etapa.cDescricao` (opcional) |
| ativo | `etapa.cInativo !== 'S'` |
| id, id_origem, created_at/by, updated_at/by, deleted_at/by | gerenciadas pelo banco |

## Por que isso importa para a seção de modelagem

O Portal do Vendedor (seção de modelagem, [[AV-Hub-Portal-Vendedor-Plano]]) tem um "dicionário de nomes de etapa" pendente. Essa tabela é a candidata natural para resolver isso, e a NF já tem um cruzamento pronto via `notas_fiscais.oppedido` → `codigo_operacao` (ver [[Notas-Fiscais-e-Itens]]).

**Ação recomendada**: confirmar se o pipeline já está de fato sincronizando essa tabela em produção (a tabela existir no banco não garante que o job de extração esteja ativo) e, se sim, ligar isso ao dicionário de etapas do Portal do Vendedor.

## Ver também
- [[Notas-Fiscais-e-Itens]]
- [[Perguntas-em-Aberto]]
