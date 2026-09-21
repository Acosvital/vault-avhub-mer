---
tags: [erp-acos-vital, fluxo-operacional]
criado: 2026-09-16
---

# 4. Faturamento e Expedição

- **Regra de faturamento**: definição entre faturamento **parcial** (liberando lotes prontos para mitigar gargalos) ou **integral** (após consolidação de todos os itens do pedido).
- **Expedição/Logística**: emissão da documentação fiscal e acionamento do carregamento/transporte final ao cliente.

## Observação sobre "Logística" no fluxo

"Logística" aparece em **dois papéis conceituais distintos**: logística de entrada (coleta em fornecedor, recebimento — dentro de [[Rota-Revenda]]) e logística de saída (expedição/carregamento — aqui). Mesmo termo, responsabilidades opostas (inbound vs. outbound) — pode gerar ambiguidade se modelado como uma única "área" no sistema.

## Onde isso já existe

O [[AV-Hub-Visao-Geral|av-hub]] já tem notas fiscais de saída e dashboards de faturamento — mas a parte fiscal (emissão de NF) permanece sempre no Omie; nenhum sistema analisado até agora emite nota fiscal diretamente. Isso já é real hoje, mas é **visão pós-fato** (a NF que o Omie já emitiu) — não a decisão operacional de "posso faturar agora".

A decisão parcial × integral depende do estado agregado dos itens da carteira — mesmo padrão de consolidação bottom-up do [[AV-Hub-Vendas-Reconciliacao|waterfall de dedução da Venda Líquida]]. **Confirmado com o usuário (17/09/2026): essa "carteira" e o estado agregado por item não existem hoje** (ver [[PCP-Carteira]]) — então a decisão parcial × integral automatizada também não existe; hoje é decisão humana, sem o dado estruturado por trás.

## Ver também
- [[Fluxo-Operacional-Visao-Geral]]
- [[AV-Hub-Modulos]]
