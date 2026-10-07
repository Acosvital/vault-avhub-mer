---
tags: [integracao-omie, lacunas]
criado: 2026-09-17
atualizado: 2026-10-07
---

# Colunas protegidas — o pipeline nunca escreve nelas

> Status: no código (`protectedColumns.ts`, `master` d2886bf) | donos das colunas: levantados em 07/10/2026 no código e no vault (🟡, sem resposta do Nathan) | só o significado de `comissao` segue 🔴 Nathan. Ver [[Registro-de-Decisoes-2026-10-07]].

> **Atualização de 07/10/2026 — faltava `compradores`.** A lista abaixo (de 17/09) foi conferida contra `src/db/protectedColumns.ts` (`master` d2886bf, leitura de código): as cinco tabelas originais batem; entrou a tabela `compradores` (`id_funcionario`, `nome_exibicao`, `ativo_desde`, `inativo_desde` — as duas datas em 66f9a2e, contrato 28 R4), cujo vínculo é manual.

Lista consolidada de `src/db/protectedColumns.ts` no `omie-elt-pipeline`: colunas que pertencem a outro sistema e que o pipeline explicitamente nunca sobrescreve, mesmo fazendo upsert no resto da linha.

| Tabela | Colunas protegidas | Quem preenche (quando conhecido) |
|---|---|---|
| `core.parceiros` | `latitude_y`, `longitude_x` | job de geocodificação à parte (`geocodeParceiros.ts`, Nominatim) |
| `core_vendas_faturamento.vendedores` | `comissao`, `ajuda_custo`, `filial`, `id_usuario`, `id_funcionario` | **(atualizado em 07/10, 🟡)** `id_funcionario`, `id_usuario`, `filial` e `ajuda_custo`: tela de Vendedores do av-hub (`PUT`) e contrato 39. `comissao` (boolean): o significado segue **🔴 Nathan**. ~~não confirmado — suspeita de outro sistema~~ |
| `core_vendas_faturamento.pedidos_vendas` | `manual` | **(atualizado em 07/10, 🟡)** tela `pedidos-vendas-manuais` do av-hub (contrato 30, `pedidoVendaManual.js`). Pedido manual tem `codigo_pedido_omie` negativo e não existe no Omie — ver o risco do `exclusionSync` em [[Arquitetura-do-Pipeline]] (🔴 Gustavo). ~~não confirmado~~ |
| `core_vendas_faturamento.notas_fiscais` | `descontos`, `manual`, `averbado` | **(atualizado em 07/10, 🟡)** NF manual do av-hub (contrato 29), só admin. ~~não confirmado~~ |
| `core_vendas_faturamento.produto_vendas` | `codigo_nf_omie`, `numero_nf` | preenchidas só via `UPDATE` direcionado de `notasFiscais.ts`, nunca pelo upsert de pedido |
| `core_vendas_faturamento.compradores` (novo em 07/10) | `id_funcionario`, `nome_exibicao`, `ativo_desde`, `inativo_desde` | vínculo manual (comprador ↔ funcionário) feito fora do pipeline, na tela de Compradores do av-hub (`PUT /compras/compradores/{id}`); `ativo` vem do Omie (`cInativo !== 'S'`) |

## Por que isso importa para qualquer módulo novo

Esse é o padrão de design explícito que a seção de modelagem já registra como lição de arquitetura: quando duas fontes escrevem na mesma tabela, decidir e documentar **quem é dono de qual coluna**, em vez de deixar implícito. Se o Estoque/MES vier a escrever em alguma tabela que o pipeline também sincroniza (por exemplo, se um dia o saldo de estoque for compartilhado), esse mesmo padrão de `protectedColumns` deveria se aplicar.

## Ver também
- [[Parceiros-Clientes-Fornecedores]]
- [[Vendedores]]
- [[Notas-Fiscais-e-Itens]]
