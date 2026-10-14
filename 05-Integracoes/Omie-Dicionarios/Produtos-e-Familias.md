---
tags: [omie, dicionario, pipeline, produtos, familias]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Gustavo (DBA)
fontes: [v1 08-Integracao-Omie/01-Dados-Extraidos/Produtos-e-Familias, omie-elt-pipeline 0f739f0, Registro-de-Decisoes #20]
---

# Dicionário Omie: Produtos e famílias

## `core.produtos`

Fonte: `ListarProdutos` (`/geral/produtos/`), resource `produtos.ts`. Chave de conflito: `(codigo_empresa, codigo_produto_omie)`, com fallback legado em `(codigo_empresa, codigo_produto)`.

| Coluna | Campo ou origem Omie |
|---|---|
| `codigo_produto` | `prod.codigo`, entidades HTML decodificadas, até 40 caracteres (`OMIE_<codigo_produto>` se vier vazio) |
| `codigo_produto_omie` | `prod.codigo_produto` |
| `descricao` | `prod.descricao`, decodificada |
| `familias_produtos` | `prod.codigo_familia` se válido (não vazio, não "0"); senão a família padrão da filial; se nem isso existir, a linha é pulada |
| `unidade_medida` | `prod.unidade` (padrão `'PÇ'`) |
| `ncm` | `prod.ncm` sem pontos |
| `especificacoes` (jsonb) | `altura`, `largura`, `profundidade`, `peso_bruto`, `peso_liq`, `marca`, `modelo` (default 0 ou vazio) |
| `ativo` | `prod.inativo === 'N'` |
| `codigo_empresa` | filial |
| `id`, `id_origem`, `created_at/by`, `updated_at/by`, `deleted_at/by` | gerenciadas pelo banco |

`peso_bruto` e `peso_liq` já vêm do Omie. Não existem em lugar nenhum: tolerância de peso (decidida em 5% para todas, no MES: `Material.toleranciaPeso` `@default(0.05)`, 📝 DEC-6 e #26), estoque máximo e ponto de pedido. O estoque mínimo existe na API do Omie (por produto e local), mas o saldo do Omie é ignorado 📝 (#28).

## Ressalva multi-filial

A família padrão por filial vem de `FAMILIA_PADRAO_POR_FILIAL` (`produtos.ts`), com entrada fixa só para `mogi` e `uberaba`. Produto sem família de uma filial nova (HRM) seria pulado. Decidido (📝 #20): é tarefa de código do Gustavo, e o `ARCHITECTURE.md` do pipeline, que diz que nova filial não muda código, deve ser corrigido ([[Pontas-Soltas]] PS-016).

## `core.familia_produtos`

Fonte: `PesquisarFamilias` (`/geral/familias/`), resource `familiaProdutos.ts`. Chave: `(codigo_empresa, codigo_fprodutos)`.

| Coluna | Campo ou origem Omie |
|---|---|
| `codigo_fprodutos` | `familia.codigo` |
| `nome` | `familia.nomeFamilia` |
| `ativo` | `familia.inativo === 'N'` |
| `codigo_empresa` | filial |

## Alias e dedup de catálogo

`material_alias_omie` não é extraído pelo pipeline: é tabela do lado do Estoque (`materialCanonicoId` + `codigoOmie`), pré-requisito de saneamento (produtos duplicados no Omie apontam para um material canônico). O pipeline traz o catálogo bruto, duplicatas incluídas. O `Material` do MES nasce só na primeira entrada de estoque do produto ([[Modelo-Estoque-e-Custo-do-Lote]]).

Ver também: [[Omie-Integracao-Estado]], [[Notas-Fiscais-e-Itens]].
