---
tags: [erp-acos-vital, av-hub, reconciliacao]
criado: 2026-09-16
---

# av-hub — Reconciliação de Vendas (Waterfall de Dedução)

Implementação confirmada direto no código-fonte real de `api-acos-vital` (models Sequelize das views, com specs em prosa muito detalhadas nos próprios arquivos — embora a SQL `CREATE VIEW` em si não esteja neste repositório, só no banco/DBA).

## As duas famílias de dado — crua vs. curada

- **Projeções cruas** (`vw_vendas_planilha`, `vw_faturamento_planilha` e seus `_resumo`) — "burras" de propósito: sem dedup/filtro, layout de planilha Excel. Adicionadas em 09/2026.
- **Views curadas "clássicas"** (`vw_vendas_base` para pedidos, `vw_nf_classified` para notas) — pré-existentes, classificação mutuamente exclusiva.

## A cascata de classificação

**`vw_vendas_base` (pedidos):** G1 Cancelado → G2 Devolvido → **G2P Devolvido Parcial** (adicionado 14/09/2026 — antes ficava dentro de G2) → G3 Denegado/manifestação negativa → G4 blacklist destinatário → G5 blacklist vendedor → G6 Refaturamento → LÍQUIDO. `is_manual` força LÍQUIDO. Grão: 1 linha por família de pedido (`codigo_pedido_omie`+`codigo_empresa`+`is_track_record`), só `sequencial=0`, filhos somados em `total_pedido`.

**`vw_nf_classified` (notas fiscais):** cascata **paralela mas distinta** — G1>G2>G3>G4>G5>G6>LÍQUIDO, **sem G2P** nesta view especificamente. `valor_nf` já líquido de CFOPs não-whitelistados e descontos, com piso em 0. `is_ypfb` é só informativo, fora da cascata.

**`fn_faturamento_resumo_mensal`** (função, não view): formato largo com colunas `fat_bruto, fat_ypfb, fat_com_ypfb, g1_cancelado, g2_devolvido, g3_recusado, g4_chile, g5_av_vendedor, g6_refaturamento, fat_liquido, batimento` (guarda de reconciliação — `batimento` deve ser sempre 0) — **aqui não há G2P separado**, devolução parcial fica dentro de LÍQUIDO, e isso é documentado como **divergência intencional**, não bug, entre a função e as views `_resumo`.

## Tabelas de blacklist

- **`blacklist_destinatarios`** e **`blacklist_vendedor_g5`** usam **regex** (`~*`), não substring simples — um regex inválido cadastrado quebra toda query de dashboard/ranking que depende dessas tabelas; a rota valida o regex antes de gravar.
- **`blacklist_vendedores` foi removida (09/2026)**, substituída por `blacklist_vendedor_g5` — mudança de semântica, não só de nome: a antiga excluía o vendedor inteiramente; a nova **deduz** (mesmo padrão do G4).
- **G6 (Refaturamento) mudou de semântica recentemente**: do lado de **vendas**, desde 14/09/2026, **todo** refaturamento deduz, independente de `status_refaturamento`; do lado de **faturamento**, só deduz quando o status **não é** `Permitido`. Essa assimetria vendas vs. faturamento é intencional, mas fácil de esquecer ao debugar divergência entre os dois lados.
- **Cuidado de nomenclatura**: existe um segundo par de blacklists, **`blacklist_comissao_vendedor`/`blacklist_comissao_destinatario`** (schema `core_comissionamento`) — parecido no nome, mas **sem nenhuma relação** com G4/G5; usadas só para excluir da comissão (bloqueio binário, sem cascata). Ver [[AV-Hub-Comissao-Modulo]].

## `refaturamentos`
`status_refaturamento`: `Permitido` | `Proibido` | `Sem Referência`, mais `motivo` (texto livre) e `periodo`. PK é `codigo_pedido_omie`.

## Limitação de dado — devolução parcial

`pedidos_vendas.devolucao_parcial` é **só um boolean** (`true`/`false`) — não existe nenhum campo de valor associado na tabela. Ou seja, não é "o Omie mostra o valor errado de devolução parcial", é **não existe valor nenhum capturado**, só a flag de que houve devolução parcial. Isso afeta diretamente a confiabilidade de **G2P** nesta cascata (que precisaria de um valor, não só de um booleano, pra deduzir corretamente). Relevante também pro desenho do ciclo de vida de devolução no Estoque/MES — ver [[Perguntas-Pendentes-MES-Estoque]] (pergunta 3).

## Divergências de dado catalogadas

- **65 notas fiscais órfãs** em `vw_faturamento_planilha_resumo` — corrigidas, motivadaram a tabela `fechamento_manual`.
- **Meta Individual 7-18× maior** — corrigido (divisor de meta global duplicado por unidade).
- **PK de `vendedores` colidia entre empresas** — corrigido (era `codigo_vendedor_omie`, agora `id` uuid).
- Lentidão/timeout no dashboard mensal consolidado — investigado e documentado.
- Gap de SLA no detalhe do vendedor (admin) vs. Portal do Vendedor — documentado.

## Fonte real do dado cru — o pipeline ELT

`vw_vendas_planilha`/`vw_faturamento_planilha` e as tabelas base (`pedidos_vendas`, `notas_fiscais`, `produto_vendas`) são alimentadas por um pipeline **EL (não ETL)** dedicado que só extrai do Omie e faz upsert — nenhuma regra de negócio/classificação roda ali, tudo fica nas views/functions do banco. Ver [[Omie-ELT-Pipeline]] para arquitetura completa, incluindo a origem real do dado de `manifestos` (scraping via Playwright, não API do Omie — o que limita a confiabilidade de `numero_nf` nessas views).

## Ver também
- [[AV-Hub-Modulos]]
- [[Faturamento-Expedicao]]
- [[AV-Hub-Bugs-Catalogo]]
- [[Omie-ELT-Pipeline]]
- [[AV-Hub-Comissao-Modulo]]
