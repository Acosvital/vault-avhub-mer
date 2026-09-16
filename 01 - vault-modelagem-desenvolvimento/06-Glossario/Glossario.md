---
tags: [erp-acos-vital, glossario]
criado: 2026-09-16
---

# Glossário

- **BFF** — Backend For Frontend; camada que só faz proxy/orquestração para um backend real, sem acesso direto a banco. É o que o [[AV-Hub-Arquitetura-BFF|av-hub]] e o `app-pcp` são (backends reais: `api-acos-vital` e `api-pcp`).
- **Carteira** — conjunto de itens de um pedido, já classificados por rota operacional (estoque/revenda/fabricação), gerido pelo [[PCP-Carteira|PCP]].
- **CCP** — Follow-up/acompanhamento de prazos de entrega de fornecedor, dentro da [[Rota-Revenda]].
- **Diligenciador** — pessoa do setor de PCP que acompanha pedidos/notas de um grupo de vendedores. Ver [[Achado-Ambiguidade-PCP]].
- **EL (não ETL)** — filosofia do [[Omie-ELT-Pipeline|pipeline de integração Omie]]: só extrai e carrega, nunca aplica regra de negócio (isso fica 100% nas views/functions do banco).
- **Grupo de dedução (G1-G2P-G6/LÍQUIDO)** — classificação mutuamente exclusiva de um pedido/nota na cascata de waterfall: G1 Cancelado, G2 Devolvido, G2P Devolvido Parcial, G3 Recusado/Denegado, G4 blacklist de destinatário, G5 blacklist de vendedor, G6 Refaturamento, LÍQUIDO = resto. Ver [[AV-Hub-Vendas-Reconciliacao]].
- **`ItemParcial`** — no backend do app-pcp, é o **estado de produção de um lote/fração de item** percorrendo o roteiro (8 estados: CRIADO...CONCLUIDO/CANCELADO) — não é entrega parcial ao cliente (isso é a entidade `Entrega`, separada). Ver [[App-PCP-Backend-Producao]].
- **`nf_classified`/`vendas_base`** — views curadas que já entregam o grupo de dedução pronto por nota/pedido. Ver [[AV-Hub-Vendas-Reconciliacao]].
- **OS (Ordem de Serviço)** — emitida pelo PCP pra beneficiamento/retrabalho de um item de Revenda (ex.: corte de chapa) fora de uma linha de fabricação própria. Ver [[Fluxo-Detalhado-Pedido-Item]].
- **OP (Ordem de Produção)** — emitida pelo PCP pra iniciar a fabricação de um item numa linha própria (Flange etc.). Ver [[Fluxo-Detalhado-Pedido-Item]].
- **PCP** — ambíguo neste projeto. Ver [[Achado-Ambiguidade-PCP]].
- **`PerfilSetor`** — RBAC paralelo (visualizar/atuar por perfil×setor) no app-pcp, usado só como conveniência de UI na tela de Movimentações — não é fronteira de segurança real.
- **Quarentena** — estado de um lote de material, visível no sistema mas indisponível para uso, até a aprovação da Qualidade.
- **Refaturamento** — reemissão de nota fiscal para o mesmo pedido; `Permitido`/`Proibido`/`Sem Referência`. Semântica de dedução (G6) difere entre vendas (sempre deduz) e faturamento (só deduz se não-Permitido).
- **RNC** — Relatório de Não Conformidade, aberto quando a Qualidade reprova um lote.
- **Roteiro** — sequência ordenada de setores pelos quais um item de produção passa. Ver [[App-PCP-Modelo-Producao]].
- **Waterfall de dedução** — metodologia de cascata usada para reconciliar Venda Bruta → Venda Líquida. Ver [[AV-Hub-Vendas-Reconciliacao]].
