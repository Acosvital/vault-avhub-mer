---
tags: [integracao-omie, dados-extraidos]
criado: 2026-09-17
---

# Pedidos de Venda

## `core_vendas_faturamento.pedidos_vendas`

Fonte: Omie `ListarPedidos` (`/produtos/pedido/`), resource `pedidosVendas.ts`. Chave de conflito: `(codigo_empresa, codigo_pedido_omie)`, com fallback de auto-cura em `(codigo_empresa, numero_pedido, sequencial)`.

| Coluna | Campo/origem Omie |
|---|---|
| codigo_pedido_omie | `cabecalho.codigo_pedido` |
| numero_pedido | `cabecalho.numero_pedido` |
| sequencial | `cabecalho.sequencial` (default 0 quando ausente — 0=guarda-chuva, 1/2/...=parciais) |
| etapa | `cabecalho.etapa` |
| data_inclusao / hora_inclusao | `infoCadastro.dInc` (convertido dd/mm/aaaa→aaaa-mm-dd) / `infoCadastro.hInc` |
| data_previsao | `cabecalho.data_previsao` |
| data_faturamento / hora_faturamento | `infoCadastro.dFat` / `infoCadastro.hFat` |
| data_cancelamento / hora_cancelamento | `infoCadastro.dCan` / `infoCadastro.hCan` |
| data_encerramento / hora_encerramento | `cabecalho.enc_data` / `cabecalho.enc_hora` |
| codigo_empresa | filial |
| codigo_cliente | `cabecalho.codigo_cliente` |
| codigo_vendedor_omie | `informacoes_adicionais.codVend` |
| codigo_categoria | `informacoes_adicionais.codigo_categoria` |
| **codigo_projeto** | `informacoes_adicionais.codProj` — **não documentado na seção de modelagem, disponível sem esforço extra** |
| **numero_contrato** | `informacoes_adicionais.numero_contrato` — **não documentado na seção de modelagem, disponível sem esforço extra** |
| obs_venda | `observacoes.obs_venda` |
| valor_total_pedido | `total_pedido.valor_total_pedido` |
| motivo_encerramento / usuario_encerramento | `cabecalho.enc_motivo` / `cabecalho.enc_user` |
| autorizado, denegado, faturado, cancelado, devolvido, devolucao_parcial, encerrado | flags S/N do Omie convertidos para boolean |
| **situacao** | **não é escrita pelo pipeline** — recalculada por trigger no banco (`trg_sync_situacao_pv`) |
| **manual** | coluna protegida, não escrita pelo pipeline |
| id, created_at/by, updated_at/by, deleted_at/by | gerenciadas pelo banco |

> **`devolucao_parcial` é só um boolean** — não existe em nenhuma coluna o *valor* dessa devolução parcial. Ver [[Campos-Faltantes-para-Estoque-MES]].

## Itens do pedido — `core_vendas_faturamento.produto_vendas`

Não tem endpoint Omie próprio — vem embutido em `pedido.det[]` dentro de `ListarPedidos`, extraído no `afterUpsert` de `pedidosVendas.ts`. Chave de conflito: `(codigo_empresa, codigo_item_omie)` com `deleted_at IS NULL`.

| Coluna | Campo/origem Omie |
|---|---|
| codigo_item_omie | `item.ide.codigo_item` (id estável da linha) |
| codigo_pedido_omie / numero_pedido | do cabeçalho do pedido pai |
| codigo_produto / codigo_produto_omie | `item.produto.codigo` / `item.produto.codigo_produto` |
| unidade_medida | `item.produto.unidade` |
| quantidade | `item.produto.quantidade` |
| **cfop** | `limparCfop(item.produto.cfop)`, validado contra whitelist `core_vendas_faturamento.cfop` (cache, TTL 10 min) — vira `null` com warning se não estiver na lista curada. **Ver [[Contradicao-CFOP]] — isso contradiz a documentação da seção de modelagem.** |
| ncm | `limparNcm(item.produto.ncm)`, sem pontos |
| valor_unitario / valor_total | `item.produto.valor_unitario` / `item.produto.valor_total` |
| codigo_empresa | filial |
| **codigo_nf_omie, numero_nf** | **não vêm do pedido** — só são preenchidos depois, por `notasFiscais.ts` (ver [[Notas-Fiscais-e-Itens]]) |
| id, created_at/by, updated_at/by, deleted_at/by | gerenciadas pelo banco |

## Ver também
- [[Campos-Faltantes-para-Estoque-MES]]
- [[Contradicao-CFOP]]
- [[Notas-Fiscais-e-Itens]]
