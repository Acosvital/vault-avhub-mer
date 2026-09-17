---
tags: [integracao-omie, dados-extraidos]
criado: 2026-09-17
---

# Produtos e Famílias

## `core.produtos`

Fonte: Omie `ListarProdutos` (`/geral/produtos/`), resource `produtos.ts`. Chave de conflito: `(codigo_empresa, codigo_produto_omie)`, com fallback legado em `(codigo_empresa, codigo_produto)`.

| Coluna | Campo/origem Omie |
|---|---|
| codigo_produto | `prod.codigo`, decodificado de entidades HTML, truncado em 40 caracteres (usa `OMIE_<codigo_produto>` se vier vazio) |
| codigo_produto_omie | `prod.codigo_produto` |
| descricao | `prod.descricao`, decodificado de entidades HTML |
| familias_produtos | `prod.codigo_familia` se válido (não vazio, não "0"); senão um código de família padrão por filial; se nem isso existir, a linha é pulada |
| unidade_medida | `prod.unidade` (padrão `'PÇ'`) |
| ncm | `prod.ncm` sem pontos |
| especificacoes (jsonb) | objeto com `altura`, `largura`, `profundidade`, **`peso_bruto`**, **`peso_liq`**, `marca`, `modelo` (todos de campos `prod.*` correspondentes, com default 0/vazio) |
| ativo | `prod.inativo === 'N'` |
| codigo_empresa | filial |
| id, id_origem, created_at/by, updated_at/by, deleted_at/by | gerenciadas pelo banco |

> **Importante para o Estoque**: `peso_bruto` e `peso_liq` **já existem** no Omie e já são extraídos. O que não existe em lugar nenhum é **tolerância de peso**, **estoque mínimo/máximo** e **ponto de pedido** — ver [[Campos-Faltantes-para-Estoque-MES]].

## `core.familia_produtos`

Fonte: Omie `PesquisarFamilias` (`/geral/familias/`), resource `familiaProdutos.ts`. Chave de conflito: `(codigo_empresa, codigo_fprodutos)`.

| Coluna | Campo/origem Omie |
|---|---|
| codigo_fprodutos | `familia.codigo` |
| nome | `familia.nomeFamilia` |
| ativo | `familia.inativo === 'N'` |
| codigo_empresa | filial |
| id, id_origem, created_at/by, updated_at/by, deleted_at/by | gerenciadas pelo banco |

## Alias/dedup de catálogo (`material_alias_omie`)

Não é extraído pelo pipeline — é uma tabela do lado do Estoque (`materialCanonicoId` + `codigoOmie`), documentada no vault 01 como pré-requisito de saneamento do catálogo Omie (produtos duplicados no Omie precisam mapear para um material canônico único). O pipeline não faz esse saneamento — só traz o catálogo bruto do Omie, duplicatas incluídas.

## Ver também
- [[Campos-Faltantes-para-Estoque-MES]]
- [[Notas-Fiscais-e-Itens]]
