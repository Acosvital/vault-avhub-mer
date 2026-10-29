---
tags: [omie, dicionario, pipeline, faturamento]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Gustavo (DBA)
fontes: [v1 08-Integracao-Omie/01-Dados-Extraidos/Etapas-Faturamento, omie-elt-pipeline 0f739f0, Registro-de-Decisoes #5, #43 do contrato 43]
---

# Dicionário Omie: Etapas de faturamento

**Em uma frase:** tabela com os nomes das etapas de faturamento do Omie, por tipo de operação.

**Quando consultar esta nota:** ao traduzir o código de etapa de um pedido em um nome legível, ou ao cruzar a nota fiscal com a operação.

Fonte: Omie `ListarEtapasFaturamento` (`/produtos/etapafat/`), resource `etapasFaturamento.ts`. Destino: `core.etapas_faturamento`. Visão geral do pipeline: [[Omie-Integracao-Estado]] e [[Pipeline-Omie]].

## Estado

| Item | Estado | Selo |
|---|---|---|
| Recurso `etapasFaturamento` ligado (`enabled:true`), nas 4 camadas (hoje, mês, últimos meses, full) | no código | ✅ |
| Tabela `core.etapas_faturamento` populada em produção | confirmada pelo Nathan em 07/10 ([[Registro-de-Decisoes]] #5) | 📝 |
| Ligação ao dicionário de nomes de etapa do Portal do Vendedor | falta; a ordem das etapas no cadastro é o contrato [[LOG-43-Ordem-das-Etapas-de-Faturamento-no-Cadastro]] (seed de `ordem_fluxo`, Gustavo) | 🔴 |

A resposta do Omie vem aninhada (`cadastros[].etapas[]`) e é achatado antes do mapeamento. Chave de conflito (o conjunto que identifica a linha e evita duplicar): `(codigo_empresa, codigo_operacao, codigo_etapa)`.

## Colunas

| Coluna | Campo ou origem Omie |
|---|---|
| `codigo_empresa` | filial |
| `codigo_operacao` | `cCodOperacao` |
| `descricao_operacao` | `cDescOperacao` |
| `codigo_etapa` | `Number(etapa.cCodigo)` (smallint) |
| `descricao_padrao` | `etapa.cDescrPadrao` |
| `descricao` | `etapa.cDescricao` (opcional) |
| `ativo` | `etapa.cInativo !== 'S'` |
| `id`, `id_origem`, `created_at/by`, `updated_at/by`, `deleted_at/by` | controle do banco (identificador, autoria e datas de criação, alteração e exclusão) |

## Por que importa

A NF cruza com esta tabela por `notas_fiscais.oppedido` = `codigo_operacao` (ver [[Notas-Fiscais-e-Itens]]). É a candidata natural para o dicionário de etapas do pedido (nó V1 do [[00-Fluxo-Mestre-0b]], etapa do pedido do Omie).

Ver também: [[Notas-Fiscais-e-Itens]], [[Pedidos-de-Venda]].
