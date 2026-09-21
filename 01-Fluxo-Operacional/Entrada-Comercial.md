---
tags: [erp-acos-vital, fluxo-operacional]
criado: 2026-09-16
---

# 1. Entrada e Triagem Comercial

- **Vendedor**: emite e cadastra o pedido de venda diretamente no Omie.
- **Hub/Integração**: captura os dados via API e disponibiliza visualização consolidada em tela própria ([[AV-Hub-Visao-Geral|av-hub]]).
- **Vendas**: mantém o acompanhamento através dos status padrão do ERP Omie.

## Ponto de atenção

O Omie é o sistema de registro do pedido (fonte de verdade de status para Vendas); o Hub funciona como camada de leitura/consolidação via API, não como sistema transacional paralelo. Isso significa que existem potencialmente **duas representações de status** — a do Omie (mais grosseira) e a da carteira interna do PCP (item a item) — que precisam ficar sincronizadas ou ao menos rastreáveis uma à outra.

> **Confirmado com o usuário (17/09/2026): esta é a única fase do fluxo inteiro que já é real hoje** (pedido criado no Omie pelo vendedor, sincronizado pro av-hub pelo pipeline ELT). A "carteira interna do PCP item a item" citada acima **não existe** — é o próximo pedaço do fluxo que o projeto precisa construir, a partir daqui. Ver [[PCP-Carteira]] e [[Fluxo-Detalhado-Pedido-Item]].

## Ver também
- [[PCP-Carteira]] — próxima etapa do fluxo.
- [[Fluxo-Operacional-Visao-Geral]]
