---
tags: [omie, dicionario, pipeline, vendedores]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Gustavo (DBA)
fontes: [v1 08-Integracao-Omie/01-Dados-Extraidos/Vendedores, omie-elt-pipeline 0f739f0 (protectedColumns.ts), contrato 39]
---

# Dicionário Omie: Vendedores

Fonte: `ListarVendedores` (`/geral/vendedores/`), resource `vendedores.ts`. Sem filtro de data: relista o catálogo inteiro. Destino: `core_vendas_faturamento.vendedores`. Chave de conflito: `(codigo_empresa, codigo_vendedor_omie)`.

| Coluna | Campo ou origem Omie |
|---|---|
| `codigo_vendedor_omie` | `String(vendedor.codigo)` |
| `codigo_empresa` | filial |
| `nome`, `email` | `vendedor.nome`, `vendedor.email` |
| `ativo` | `vendedor.inativo !== 'S'` |
| `comissao`, `ajuda_custo`, `filial`, `id_usuario`, `id_funcionario` | **não vêm do Omie**: colunas protegidas ([[Colunas-Protegidas]]) |
| `id`, `id_origem`, `created_at/by`, `updated_at/by`, `deleted_at/by` | gerenciadas pelo banco |

Um vendedor pode ter várias linhas (uma por filial ou conta Omie), ligadas pelo `id_funcionario`, que o pipeline não gere. O vínculo é feito na tela de Vendedores do HUB ([[LOG-39-Vendedores-Fila-de-Vinculo]]).

O escopo do vendedor (ver só os próprios pedidos) é aplicado pela API a partir do token, fixo no código desde o contrato 40 ✅ (`api-acos-vital/src/utils/acessoConfig.js:75`; [[LOG-40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]]).

Ver também: [[Pedidos-de-Venda]].
