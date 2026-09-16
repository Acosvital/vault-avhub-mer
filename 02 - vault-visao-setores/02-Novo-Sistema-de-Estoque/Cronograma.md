---
tags: [visao-setores, novo-sistema-estoque]
criado: 2026-09-16
---

# Cronograma de Entrega

O projeto vai ser entregue em fases, cada uma construindo em cima da anterior. Não faz sentido começar a controlar estoque num sistema novo antes de arrumar a base — por isso o projeto começa pela limpeza dos dados, não pelas telas mais "visíveis" do dia a dia.

## Fase 0 — Arrumar a casa antes de começar

Antes de qualquer tela de compra ou recebimento entrar em uso, é preciso:
1. Limpar e organizar o catálogo de materiais que hoje tem duplicidades.
2. Cadastrar os materiais e os locais de armazenamento.
3. Fazer um levantamento físico completo do que já existe em estoque hoje, e usar isso como ponto de partida (chamado de carga inicial ou "marco zero").

Essa etapa é o alicerce de tudo — se o levantamento inicial for malfeito, a confiança no sistema fica comprometida desde o primeiro dia.

## Fase A — Pedido de compra

Entra em uso a criação de pedidos de compra, tanto pra matéria-prima quanto pra revenda. O cadastro do fornecedor em si não é feito de novo — ele já vem aproveitado do sistema comercial (av-hub), que já mantém essa informação sincronizada com o Omie.

## Fase B — Recebimento

Entra em uso o processo completo de recebimento: conferência de quantidade, conferência de qualidade, pesagem, tratamento de material reprovado (RNC) e etiquetagem com código de barras.

## Fase C — Estoque

Entra em uso o controle de saldo, localização e movimentação de material dentro do depósito, além da reserva de estoque.

## Fase D — Separação, devolução e contagem

Entram em uso a separação de material para expedição, a devolução de cliente, a contagem cíclica periódica e o alerta automático de ponto de pedido (reposição preventiva).

## Fase E (futura) — Piloto de identificação por rádio (RFID)

Fase futura, ainda sem data definida: um piloto de identificação por radiofrequência, aplicado primeiro no item de maior valor unitário, antes de qualquer decisão de investir nisso em escala.

## Sobre o acesso ao sistema

O sistema vai aceitar dois jeitos de entrar: usuário e senha (pensado pro pessoal de chão de fábrica, que hoje não tem e-mail corporativo) e e-mail corporativo (pensado pros perfis de escritório do Estoque — Almoxarife, Qualidade, Gestor de Estoque). Comprador e Aprovador continuam trabalhando pelo sistema comercial (av-hub), sem precisar acessar este sistema novo.

## Ver também
- [[Visao-Geral]]
- [[Perguntas-em-Aberto]]
- [[Equipe-do-Projeto]]
