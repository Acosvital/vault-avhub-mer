---
tags: [visao-setores, novo-sistema-estoque]
criado: 2026-09-16
---

# Riscos e Cuidados

Toda mudança de sistema traz riscos. Aqui estão os principais pontos que a equipe do projeto está de olho, e o que está sendo feito para evitar cada um.

| Risco | O que está sendo feito para evitar |
|---|---|
| Um caso de divergência ou reprovação ficar travado sem solução, obrigando alguém a resolver "por fora" do sistema | Todo caso de divergência ou reprovação tem, desde o desenho, um caminho de saída garantido — nunca fica parado sem próximo passo |
| Material ser usado antes de passar pela aprovação da Qualidade | Todo material que chega fica automaticamente bloqueado para uso até a Qualidade aprovar formalmente |
| Investir em identificação por radiofrequência (RFID) sem confirmar que funciona em peça de metal | Um piloto é obrigatório antes de qualquer compra em maior escala |
| O saldo que o sistema mostra ficar diferente do que existe fisicamente no depósito | Rastreabilidade por lote, mais contagens cíclicas periódicas e a exigência de um motivo registrado sempre que alguém faz um ajuste manual de saldo |
| O mesmo material ser comprometido ao mesmo tempo por uma ordem de produção e por uma venda | Toda separação de material exige uma reserva prévia, o que impede a dupla alocação |
| A mesma pessoa criar, aprovar e receber um pedido de compra (risco de fraude) | Segregação de função: cada papel (Comprador, Aprovador, Almoxarife, Qualidade, Gestor de Estoque) só tem acesso ao que precisa fazer |
| O levantamento inicial de estoque sair errado e comprometer a confiança no sistema desde o começo | Levantamento físico conferido em dupla, e nenhuma movimentação de Produção ou Vendas acontece antes dessa etapa inicial estar fechada |
| Cadastrar materiais em cima de um catálogo que ainda tem duplicidade | A limpeza do catálogo acontece antes do cadastro de materiais começar, nunca depois |
| Um pedido aprovado ficar parado pra sempre porque o fornecedor nunca entrega | Existe um status explícito de "cancelado", que reavalia automaticamente qualquer reserva ou destinação que dependia daquele pedido |

## Ver também
- [[Visao-Geral]]
- [[Regras-de-Negocio]]
- [[Perguntas-em-Aberto]]
