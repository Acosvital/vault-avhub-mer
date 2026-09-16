---
tags: [visao-setores, novo-sistema-estoque]
criado: 2026-09-16
---

# Visão Geral do Novo Sistema de Estoque

## Por que esse sistema está sendo criado

Hoje a Aços Vital não tem um sistema dedicado pra controlar estoque, recebimento de material e compras. Tudo depende do que o sistema financeiro atual (Omie) oferece de forma nativa, o que traz limitações importantes no dia a dia:

- Não dá pra saber, com segurança, de qual lote ou corrida veio um material específico.
- Não existe um processo estruturado de conferência quando o material chega na doca.
- Falta visibilidade cruzada entre o que está em estoque, o que a fábrica está consumindo e o que está disponível pra venda no Portal do Vendedor.

O novo sistema de Estoque nasce pra resolver exatamente isso: dar à empresa um controle real de compras, recebimento e estoque, com rastreabilidade completa e regras claras de quem faz o quê.

## O que o sistema vai cobrir

O projeto cobre três grandes frentes, que juntas formam a jornada completa do material — da compra até estar disponível pra produção ou venda:

1. **Compras** — matéria-prima e produtos de revenda.
2. **Recebimento** — conferência de quantidade pelo Almoxarifado e conferência de qualidade pelo setor de Qualidade.
3. **Estoque** — saldo, localização de cada material dentro do depósito, rastreabilidade por lote, e um material só fica liberado pra uso depois que a Qualidade aprova (o que chamamos de quarentena).

Esse sistema conversa com o [[av-hub|sistema comercial (av-hub)]] que a empresa já usa: quem decide e negocia a compra continua no av-hub (Comprador, Aprovador); o novo sistema entra em ação quando o material chega fisicamente na empresa — conferência, controle de qualidade e controle de estoque.

## O que fica de fora, por enquanto

- **Portal do Vendedor / Portal Comercial** — continua sendo um sistema à parte, que vai apenas consultar o saldo disponível de revenda.
- **Parte fiscal** — continua 100% no Omie. O novo sistema nunca emite nota fiscal; ele só sinaliza quando uma nota precisa ser emitida (por exemplo, numa devolução) e espera a confirmação voltar do Omie.
- Leitura por RFID em produção — só entra como piloto, numa fase futura.
- Marcação a laser direto na peça de metal.
- Substituir o Omie como sistema fiscal/financeiro.
- Comparação de preços entre fornecedores antes de fechar a compra (o pedido já nasce com o fornecedor escolhido).

## Investimento inicial

Cada posto de recebimento vai precisar de uma impressora de etiquetas e um leitor de código de barras/QR de mão — investimento estimado entre R$ 5 mil e R$ 7 mil por posto.

## Ver também
- [[Como-vai-Funcionar-no-Dia-a-Dia]]
- [[Regras-de-Negocio]]
- [[Cronograma]]
- [[Riscos-e-Cuidados]]
- [[Perguntas-em-Aberto]]
- [[Visao-Geral-do-Processo]]
- [[Controlando-o-Estoque]]
- [[Glossario]]
