---
tags: [integracao-omie, dados-extraidos]
criado: 2026-09-17
atualizado: 2026-10-07
---

# Etapas de Faturamento

> Status: em produção (verificado em 07/10/2026 pelo dump e pelo [[Registro-de-Decisoes-2026-10-07]] #5: `core.etapas_faturamento` populada) | no código (`enabled:true`).

> **Atualização de 07/10/2026 — a ação "confirmar se está habilitado" foi respondida no código.** O recurso `etapasFaturamento` está com `enabled:true` (desde f753982) e roda nas 4 camadas (hoje/mês/últimos meses/full), destino `core.etapas_faturamento`. Fonte: leitura de código (`master` d2886bf); ~~se está de fato rodando em produção e populando a tabela não foi verificado~~ — **superado (✅ 07/10, #5): a tabela está populada em produção.** A parte restante é ligar a tabela ao dicionário de etapas do Portal do Vendedor.

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

**Ação recomendada (atualizado em 07/10)**: o código já está habilitado (`enabled:true`); a confirmação em produção está feita (tabela populada, ✅ 07/10); falta ligar isso ao dicionário de etapas do Portal do Vendedor.

## Ver também
- [[Notas-Fiscais-e-Itens]]
- [[Perguntas-em-Aberto]]
