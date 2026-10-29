---
tags: [omie, dicionario, pipeline, pedidos, itens]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Gustavo (DBA)
fontes: [v1 08-Integracao-Omie/01-Dados-Extraidos/Pedidos-de-Venda, omie-elt-pipeline 0f739f0]
---

# Dicionário Omie: Pedidos de venda e itens

**Em uma frase:** tabelas dos pedidos de venda e dos itens que a pipeline copia do Omie, com a origem de cada coluna.

**Quando consultar esta nota:** ao procurar o significado de uma coluna do pedido ou do item, ou ao entender como o pedido chega ao hub (nó V1).

Nó V1 do [[00-Fluxo-Mestre-0b]]: o pedido nasce no Omie e chega ao av-hub travado ([[01-Vendas-Liberacao]]).

## `core_vendas_faturamento.pedidos_vendas`

Fonte: `ListarPedidos` (`/produtos/pedido/`), resource `pedidosVendas.ts`. Chave de conflito (identifica a linha e evita duplicar): `(codigo_empresa, codigo_pedido_omie)`, com reencontro automático do pedido em `(codigo_empresa, numero_pedido, sequencial)`.

| Coluna | Campo ou origem Omie |
|---|---|
| `codigo_pedido_omie` | `cabecalho.codigo_pedido` |
| `numero_pedido` | `cabecalho.numero_pedido` |
| `sequencial` | `cabecalho.sequencial` (0 quando ausente: 0 agrupa o pedido; 1, 2... são as partes faturadas) |
| `etapa` | `cabecalho.etapa` |
| `data_inclusao`, `hora_inclusao` | `infoCadastro.dInc`, `hInc` (dd/mm/aaaa vira aaaa-mm-dd) |
| `data_previsao` | `cabecalho.data_previsao` |
| `data_faturamento`, `hora_faturamento` | `infoCadastro.dFat`, `hFat` |
| `data_cancelamento`, `hora_cancelamento` | `infoCadastro.dCan`, `hCan` |
| `data_encerramento`, `hora_encerramento` | `cabecalho.enc_data`, `enc_hora` |
| `codigo_empresa` | filial |
| `codigo_cliente` | `cabecalho.codigo_cliente` |
| `codigo_vendedor_omie` | `informacoes_adicionais.codVend` |
| `codigo_categoria` | `informacoes_adicionais.codigo_categoria` |
| `codigo_projeto` | `informacoes_adicionais.codProj` |
| `numero_contrato` | `informacoes_adicionais.numero_contrato` |
| `obs_venda` | `observacoes.obs_venda` |
| `valor_total_pedido` | `total_pedido.valor_total_pedido` |
| `motivo_encerramento`, `usuario_encerramento` | `cabecalho.enc_motivo`, `enc_user` |
| `autorizado`, `denegado`, `faturado`, `cancelado`, `devolvido`, `devolucao_parcial`, `encerrado` | flags S/N convertidas para boolean |
| `situacao` | **não é escrita pelo pipeline**: recalculada por trigger no banco (`trg_sync_situacao_pv`) |
| `manual` | coluna protegida: pedido manual do av-hub ([[LOG-45-Pedido-de-Venda-Manual]]; [[Colunas-Protegidas]]) |
| `id`, `created_at/by`, `updated_at/by`, `deleted_at/by` | controle do banco (identificador, autoria e datas de criação, alteração e exclusão) |

`devolucao_parcial` é só boolean: o valor da devolução parcial não existe em coluna nenhuma (devolução é nativa do Estoque, Ciclo 2, 📝 DEC-10, [[Registro-de-Decisoes]]).

## Itens: `core_vendas_faturamento.produto_vendas`

Sem endpoint próprio: vem embutido em `pedido.det[]` de `ListarPedidos`, gravado no `afterUpsert` de `pedidosVendas.ts`. Chave de conflito (identifica a linha e evita duplicar): `(codigo_empresa, codigo_item_omie)` com `deleted_at IS NULL` (índice `uq_produto_vendas_item_linha`).

| Coluna | Campo ou origem Omie |
|---|---|
| `codigo_item_omie` | `item.ide.codigo_item` (id estável da linha) |
| `codigo_pedido_omie`, `numero_pedido` | do cabeçalho do pedido pai |
| `codigo_produto`, `codigo_produto_omie` | `item.produto.codigo`, `item.produto.codigo_produto` |
| `unidade_medida` | `item.produto.unidade` |
| `quantidade` | `item.produto.quantidade` |
| `cfop` | `limparCfop(item.produto.cfop)`, conferido contra a lista de CFOPs aceitos `core_vendas_faturamento.cfop` (guardada por 10 min; CFOP é o código fiscal da operação); vira `null` com aviso se não estiver na lista |
| `ncm` | `limparNcm(item.produto.ncm)`, sem pontos (NCM é a classificação fiscal do produto) |
| `valor_unitario`, `valor_total` | `item.produto.valor_unitario`, `valor_total` |
| `codigo_empresa` | filial |
| `codigo_nf_omie`, `numero_nf` | **só preenchidos depois**, por `notasFiscais.ts` ([[Notas-Fiscais-e-Itens]]) |
| `id`, `created_at/by`, `updated_at/by`, `deleted_at/by` | controle do banco (identificador, autoria e datas de criação, alteração e exclusão) |

## Atenção

- O mesmo produto pode aparecer em duas linhas do mesmo pedido (confirmado no Omie); por isso a chave é o `codigo_item_omie`, não o produto. O custo do item no MES soma as linhas por **produto** ([[API-008-Custo-do-Lote-no-MES]], A1).
- O `exclusionSync` apaga pedidos por empresa e janela sem filtrar `manual`: risco 🔴 ([[Riscos]] RS-001).

Ver também: [[Omie-Integracao-Estado]].
