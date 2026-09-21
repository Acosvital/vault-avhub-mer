---
tags: [integracao-omie, dados-extraidos]
criado: 2026-09-17
---

# Vendedores

Fonte: Omie `ListarVendedores` (`/geral/vendedores/`), resource `vendedores.ts` — sem filtro de data, sempre relista o catálogo inteiro. Destino: `core_vendas_faturamento.vendedores`. Chave de conflito: `(codigo_empresa, codigo_vendedor_omie)`.

| Coluna | Campo/origem Omie |
|---|---|
| codigo_vendedor_omie | `String(vendedor.codigo)` |
| codigo_empresa | filial |
| nome | `vendedor.nome` |
| email | `vendedor.email` |
| ativo | `vendedor.inativo !== 'S'` |
| **comissao, ajuda_custo, filial, id_usuario, id_funcionario** | **não vêm do Omie** — colunas protegidas, presumidamente geridas por outro sistema (não confirmado qual). Ver [[Colunas-Protegidas]]. |
| id, id_origem, created_at/by, updated_at/by, deleted_at/by | gerenciadas pelo banco |

Um vendedor pode ter várias linhas na tabela — uma por filial/conta Omie — vinculadas via `id_funcionario` (não gerido pelo pipeline).

## Ver também
- [[Colunas-Protegidas]]
- [[Pedidos-de-Venda]]
