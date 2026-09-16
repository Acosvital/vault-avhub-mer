---
tags: [visao-setores, fluxo-operacional]
criado: 2026-09-16
---

# Organização do Pedido pelo PCP

Depois que o pedido é cadastrado por Vendas, ele cai na fila do PCP (Planejamento e Controle de Produção). É aqui que o pedido deixa de ser só "uma venda" e passa a ser organizado de forma detalhada, item por item.

> Atenção: esse PCP é o setor de Planejamento e Controle de Produção, que organiza a fabricação e a compra dos itens. Não confundir com o "Portal PCP" que aparece em outra parte do sistema comercial, que é uma tela diferente, usada por diligenciadores para acompanhamento comercial — são duas coisas com nome parecido, mas funções diferentes.

## O que o PCP faz

O PCP abre o pedido e olha cada item individualmente. Ele monta o que a empresa chama de "carteira" do pedido: a lista organizada de todos os itens, com a classificação de onde cada um vai ser atendido.

Para cada item, o PCP responde a duas perguntas:

1. **De onde esse item vem?** É um item de revenda (comprado de terceiros) ou é um item de uma linha de fabricação própria da empresa (como flange ou grade de piso)?
2. **Esse item já existe fisicamente agora?** Já está pronto no estoque, existe como matéria-prima que precisa de mais um passo antes de ficar pronto, ou não existe nada em estoque e precisa ser originado (comprado ou fabricado do zero)?

A combinação dessas duas respostas decide o caminho que o item vai seguir a partir daí:

| Situação do item | O que acontece |
|---|---|
| Item comprado de terceiro, já pronto em estoque | Vai direto para a conferência e depois para a Qualidade |
| Item comprado de terceiro, em estoque mas ainda como matéria-prima (ex.: chapa inteira) | O PCP encaminha para um corte ou ajuste antes de seguir — veja [[Cortando-Chapas-sob-Medida]] |
| Item comprado de terceiro, sem nada em estoque | O PCP aciona a compra — veja [[Comprando-o-que-Falta]] |
| Item de fabricação própria, sem matéria-prima disponível | O PCP aciona a compra da matéria-prima específica, depois inicia a fabricação |
| Item de fabricação própria, com matéria-prima disponível | O PCP já inicia a fabricação direto — veja [[Fabricando-Produtos-Proprios]] |

## Por que essa classificação é feita item por item

Um mesmo pedido pode ter, ao mesmo tempo, um item pronto em estoque, um item que precisa ser comprado e um item que vai para a fabricação própria. Não existe "um caminho único" para o pedido inteiro — cada item segue seu próprio ritmo, e o PCP é quem decide, individualmente, qual caminho cada um vai seguir.

## Por que "estoque" não é bem um quarto caminho

É tentador pensar em quatro caminhos separados: estoque, revenda, fabricação e... mais alguma coisa. Mas não é assim. "Estoque" é só a resposta para a pergunta "esse item já existe pronto?" — pode acontecer tanto com um item de revenda quanto com um item de fabricação própria. Não é uma origem à parte, é uma situação momentânea que qualquer item pode ter, dependendo do que existe fisicamente no depósito quando o PCP olha.

## O que vem depois

A partir da classificação do PCP, o item segue para um dos caminhos operacionais: [[Controlando-o-Estoque]], [[Comprando-o-que-Falta]], [[Cortando-Chapas-sob-Medida]] ou [[Fabricando-Produtos-Proprios]].

## Ver também
- [[Visao-Geral-do-Processo]]
- [[Vendas-e-Entrada-do-Pedido]]
- [[Controlando-o-Estoque]]
- [[Comprando-o-que-Falta]]
- [[Fabricando-Produtos-Proprios]]
- [[Cortando-Chapas-sob-Medida]]
- [[Quem-Faz-o-Que]]
- [[Ambiguidade-do-Nome-PCP]]
- [[Glossario]]
