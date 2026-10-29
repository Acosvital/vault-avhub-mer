---
tags: [omie, pipeline, colunas-protegidas, dados]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Gustavo (DBA)
fontes: [omie-elt-pipeline 0f739f0 src/db/protectedColumns.ts, v1 08-Integracao-Omie/02-Analise-de-Lacunas/Colunas-Protegidas, Registro-de-Decisoes #15 #62, contratos 28 29 39 45]
---

# Colunas protegidas

**Em uma frase:** são colunas que existem em tabelas copiadas do Omie, mas que pertencem a outro sistema, e por isso a pipeline nunca as sobrescreve.

**Quando consultar esta nota:** ao fazer o HUB ou o MES escrever numa tabela que a pipeline copia do Omie, ou quando um valor "some" depois de uma sincronização.

## Quem manda dado para quem, quando e por quê

- A pipeline copia dados do Omie para o banco do hub a cada poucos minutos.
- Algumas colunas vêm de outro lugar: do HUB (comissão do vendedor, marca de pedido ou nota manual) ou de um job próprio (coordenadas do parceiro). A pipeline as pula.
- Sem a proteção, cada nova cópia apagaria o valor em silêncio, como aconteceu com `notas_fiscais.descontos`.

**Regra:** quem passar a escrever numa tabela copiada do Omie inclui a coluna na lista de protegidas no mesmo PR. Pontos abertos e a lista completa estão no detalhe.

## Detalhe técnico

Colunas que existem nas tabelas sincronizadas do Omie mas pertencem a **outro sistema**. O pipeline nunca as inclui no `INSERT` nem no `UPDATE` do upsert ✅ (`omie-elt-pipeline/src/db/protectedColumns.ts:60-73`). Sem isso, cada re-sincronização zeraria o valor em silêncio (incidente de `notas_fiscais.descontos`). Padrão a copiar em qualquer integração nova: declarar o dono de cada coluna desde o início (📝 [[Registro-de-Decisoes]], decisões-chave do ERP).

### Lista conferida no código

| Tabela | Colunas protegidas | Quem preenche | Selo |
|---|---|---|---|
| `core.parceiros` | `latitude_y`, `longitude_x` | job `geocodeParceiros.ts` (Nominatim, diário 05:37) | ✅ |
| `core_vendas_faturamento.vendedores` | `comissao`, `ajuda_custo`, `filial`, `id_usuario`, `id_funcionario` | tela de Vendedores do HUB (`PUT`) e [[LOG-39-Vendedores-Fila-de-Vinculo]]. Significado de `comissao` (boolean): 🔴 Nathan | ✅ lista; 🟡 dono |
| `core_vendas_faturamento.pedidos_vendas` | `manual` | pedido de venda manual do HUB ([[LOG-45-Pedido-de-Venda-Manual]], `pedidoVendaManual.js`). Pedido manual tem `codigo_pedido_omie` negativo | ✅ lista; 🟡 dono |
| `core_vendas_faturamento.notas_fiscais` | `descontos`, `manual`, `averbado` | NF manual do HUB, só administrador ([[LOG-29-Notas-Fiscais-Manuais-So-Admin]]) | ✅ lista; 🟡 dono |
| `core_vendas_faturamento.produto_vendas` | `codigo_nf_omie`, `numero_nf` | `UPDATE` direcionado de `notasFiscais.ts`, nunca pelo upsert do pedido | ✅ |
| `core_vendas_faturamento.compradores` | `id_funcionario`, `nome_exibicao`, `ativo_desde`, `inativo_desde` | tela de Compradores do HUB (`PUT /compras/compradores/{id}`); `ativo` vem do Omie (`cInativo !== 'S'`) | ✅ |
| `core.produtos`, `core.familia_produtos` | nenhuma (lista vazia) | | ✅ |

### Pontos abertos

- **O comentário do próprio `protectedColumns.ts` ainda diz** que o dono de `vendedores` é "pendente de confirmação" e que `comissao` pode vir de outro sistema (`protectedColumns.ts:15-24`). Os donos já estão nomeados nesta nota. Atualizar o comentário: Gustavo ([[Pontas-Soltas]] PS-017).
- **Conflito com o `exclusionSync`:** pedido manual (coluna protegida `manual`) entra na lista de apagados porque o job não filtra `manual` (`omie-elt-pipeline/src/jobs/exclusionSync.ts:103` filtra só empresa, `deleted_at` e janela; `DELETE` em `:136`). 🔴 [[Riscos]] RS-001, [[Backlog-por-Frente]] BL-027.
- **Contrato 43** acrescenta a ordem das etapas de faturamento ao cadastro: `protectedColumns.ts` deve proteger a coluna nova (`ordem_fluxo`) quando o seed existir ([[LOG-43-Ordem-das-Etapas-de-Faturamento-no-Cadastro]]).
- **Pedido manual e custo:** o pedido manual nunca entra no custo (D6 do contrato 008) e precisa de marca de origem; a coluna `manual` serve, mas o MES não a recebe hoje 🔴 BL-026.

### Regra para quem escreve em tabela sincronizada

1. Se o MES ou o HUB passar a escrever em tabela que o pipeline sincroniza, a coluna entra em `PROTECTED_COLUMNS` no mesmo PR.
2. Chave de conflito do upsert não pode incluir coluna protegida (a "proteção por omissão" deixa de valer). Foi o motivo da troca para `codigo_item_omie` em `produto_vendas` (26/08).
3. Evite FK entre entidades sincronizadas de forma independente.

Ver também: [[Omie-Integracao-Estado]], [[Pipeline-Omie]], [[Pedidos-de-Venda]].
