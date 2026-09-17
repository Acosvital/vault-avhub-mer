---
tags: [integracao-omie, lacunas]
criado: 2026-09-17
---

# Colunas protegidas — o pipeline nunca escreve nelas

Lista consolidada de `src/db/protectedColumns.ts` no `omie-elt-pipeline`: colunas que pertencem a outro sistema e que o pipeline explicitamente nunca sobrescreve, mesmo fazendo upsert no resto da linha.

| Tabela | Colunas protegidas | Quem preenche (quando conhecido) |
|---|---|---|
| `core.parceiros` | `latitude_y`, `longitude_x` | job de geocodificação à parte (`geocodeParceiros.ts`, Nominatim) |
| `core_vendas_faturamento.vendedores` | `comissao`, `ajuda_custo`, `filial`, `id_usuario`, `id_funcionario` | não confirmado — suspeita de outro sistema, sinalizado como pendente de confirmação |
| `core_vendas_faturamento.pedidos_vendas` | `manual` | não confirmado |
| `core_vendas_faturamento.notas_fiscais` | `descontos`, `manual`, `averbado` | não confirmado |
| `core_vendas_faturamento.produto_vendas` | `codigo_nf_omie`, `numero_nf` | preenchidas só via `UPDATE` direcionado de `notasFiscais.ts`, nunca pelo upsert de pedido |

## Por que isso importa para qualquer módulo novo

Esse é o padrão de design explícito que o vault 01 já registra como lição de arquitetura: quando duas fontes escrevem na mesma tabela, decidir e documentar **quem é dono de qual coluna**, em vez de deixar implícito. Se o Estoque/MES vier a escrever em alguma tabela que o pipeline também sincroniza (por exemplo, se um dia o saldo de estoque for compartilhado), esse mesmo padrão de `protectedColumns` deveria se aplicar.

## Ver também
- [[Parceiros-Clientes-Fornecedores]]
- [[Vendedores]]
- [[Notas-Fiscais-e-Itens]]
