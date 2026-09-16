---
tags: [visao-setores, novo-sistema-estoque]
criado: 2026-09-16
---

# Como vai Funcionar no Dia a Dia

Este documento conta a jornada completa de um material — desde o momento em que alguém percebe que precisa comprar algo, até o produto sair pronto pela expedição. É a mesma jornada, contada em ordem, passando por Compras, Recebimento, Qualidade, Produção (quando envolve beneficiamento) e Estoque.

## 1. Tudo começa com uma necessidade de compra

Quando o PCP avalia um pedido e percebe que não há material disponível em estoque, ele dispara um pedido de compra pro setor de Compras, informando o material, a quantidade, o prazo necessário e, se for o caso, se o item precisa vir "acabado" ou "não acabado" (ou seja, se ainda vai passar por beneficiamento na fábrica antes de chegar ao cliente). Essa marcação de acabado/não acabado é um dado crítico — ela decide todo o caminho que o material vai seguir mais adiante.

## 2. Compras negocia e emite o pedido

O Comprador escolhe o fornecedor e negocia preço e condições — isso ainda acontece por fora do sistema (telefone, e-mail, WhatsApp). Se o valor da compra ultrapassar um limite (a definir com o negócio), o pedido passa por uma segunda aprovação antes de seguir. Depois de aprovado, o Comprador emite o pedido de compra oficial, definindo também quem paga o frete:

- **CIF** — o fornecedor paga e organiza o transporte, entregando direto na doca da empresa.
- **FOB** — a empresa assume a responsabilidade assim que o material é despachado, e a própria Logística de Entrada vai buscar no fornecedor.

Enquanto o material não chega, uma pessoa dedicada faz o acompanhamento ativo do prazo com o fornecedor (cobrança de prazo, atualização de previsão de chegada) — hoje isso também é feito manualmente, por fora do sistema, porque o fornecedor não tem acesso a nenhuma ferramenta da empresa. Não existe hoje um status "em trânsito" confiável — o pedido continua marcado como "aprovado" até o material chegar fisicamente.

## 3. O material chega e o Recebimento confere

Quando o material chega na doca (seja porque o fornecedor entregou, ou porque a Logística de Entrada foi buscar), o Recebimento faz duas conferências:

- **Conferência de quantidade**: contagem física contra o que era esperado. Item acabado é conferido contra o pedido de venda original (ou seja, "o que chegou é exatamente o que o vendedor vendeu"); item não acabado é conferido contra o pedido de compra (porque ainda vai passar por beneficiamento antes de virar o produto final).
- **Pesagem**: peso pesado contra o peso teórico esperado, dentro de uma tolerância por categoria de material.

Se a quantidade ou a descrição não baterem, o caso volta pro PCP decidir: aceitar o que chegou como um recebimento parcial, ou rejeitar e reabrir o processo de compra. Esse é um problema diferente de reprovação de qualidade — aqui o item "chegou errado", enquanto a reprovação de qualidade, mais adiante, é sobre "chegou ruim".

Se a conferência bate, o material vira um **lote** dentro do sistema — e todo lote nasce automaticamente bloqueado para uso, aguardando aprovação da Qualidade. O material recebe uma etiqueta com código de barras ou QR Code (RFID só entra num piloto futuro, para itens de maior valor). A nota fiscal de entrada fica apenas referenciada — os dados fiscais continuam só no Omie.

## 4. O caminho se divide: precisa de fábrica ou vai direto pra Qualidade?

Aqui é onde a marcação de "acabado/não acabado" (definida lá no passo 2) decide o rumo:

- **Item não acabado** → o Recebimento avisa o PCP que o material chegou e precisa de beneficiamento. O PCP abre uma Ordem de Serviço (para beneficiamento de revenda, como corte de chapa) ou uma Ordem de Produção (para linha própria de fabricação).
- **Item acabado** → segue direto do Recebimento pra Qualidade, sem passar pelo PCP de novo.

## 5. Quando envolve fábrica: a passagem pelos setores de produção

Quando o material precisa de beneficiamento, ele passa por uma sequência de setores conforme o roteiro de produção definido para aquele tipo de peça. Em cada setor, o material é recebido, o trabalho começa, e ao terminar ele segue para o próximo setor da fila — até chegar ao último passo do roteiro.

Ao longo do caminho, imprevistos são tratados sem travar o processo:
- Se falta insumo ou a máquina quebra, o setor pode pausar o trabalho e retomar depois, sem perder o histórico.
- Se algo precisa ser refeito, o setor pode repetir a etapa (retrabalho).
- Uma peça pode ser dividida em várias (por exemplo, uma chapa que vira várias peças cortadas), e depois reagrupada se fizer sentido.
- Se um setor rejeita o material recebido, ele devolve para o setor anterior decidir — o item nunca fica "devolvido e parado sem solução": um novo registro é sempre criado dando sequência ao processo.

Quando o roteiro termina, o material sai da fábrica e segue direto pra Qualidade, exatamente como um item acabado que veio do Recebimento.

## 6. A Qualidade inspeciona e decide

A Qualidade recebe material de três origens possíveis: item acabado vindo direto do Recebimento, item que acabou de sair da fábrica, ou item que já estava pronto em estoque. Existe ainda uma entrada adicional: quando o vendedor marca, já na emissão do pedido, que aquele item precisa de acompanhamento de qualidade desde o início (inspeção de processo), diferente da inspeção final que acontece quando o material está pronto.

A Qualidade executa a inspeção e **não consegue liberar nada sem anexar o laudo/certificado correspondente** — essa é uma trava obrigatória, não uma formalidade opcional. A partir daí:

- **Se aprovado**: o material sai do bloqueio de qualidade e segue pra Expedição. Se já havia uma reserva vinculada a um pedido específico, ela se confirma automaticamente aqui.
- **Se reprovado**: a Qualidade anexa o motivo e uma evidência (como foto da avaria). O material é dividido — a parte aprovada segue seu caminho normal, e a parte reprovada fica congelada aguardando devolução. O caso volta pro PCP decidir o novo rumo (por exemplo, abrir uma nova compra), e a Qualidade sinaliza a necessidade de devolução ao fornecedor — o sistema nunca emite a nota de devolução sozinho, só sinaliza; a nota nasce no Omie e, quando ela volta, o caso é encerrado.

Importante: essa "devolução ao fornecedor" (motivada por reprovação de qualidade na entrada) é um caso diferente de "devolução de cliente" (motivada por insatisfação ou erro pós-venda) — são processos, telas e responsáveis diferentes, mesmo usando uma palavra parecida.

## 7. O papel do Estoque no dia a dia

Nem todo item passa por uma nova compra — muita coisa já está pronta em estoque. Nesse caso, o PCP verifica o saldo disponível junto ao Almoxarife, que confirma a disponibilidade física. Ao verificar o saldo, o sistema já cria a reserva no mesmo momento — isso evita que dois pedidos concorrentes disputem o mesmo material ao mesmo tempo. O Almoxarife então faz a separação física do material, que segue pra Qualidade (se ainda não tiver sido inspecionado) ou direto pra Expedição (se já estava aprovado de um recebimento anterior).

Além de atender pedidos específicos, o Estoque tem uma operação contínua, independente de qualquer pedido:

- **Transferência entre depósitos** — a empresa opera com mais de um depósito compartilhado entre as fábricas e a Revenda, e mover material entre eles é uma operação normal.
- **Contagem cíclica** — conferências periódicas entre o saldo físico e o saldo do sistema; qualquer divergência exige um ajuste com motivo obrigatório registrado, nunca um ajuste silencioso.
- **Ponto de pedido** — quando o saldo de um material cruza um limite mínimo, o sistema avisa o PCP, que dispara uma nova compra de forma preventiva, antes de faltar de verdade. Essa é uma origem diferente de uma compra motivada por um pedido de venda específico, mas as duas seguem para o mesmo processo de compra.

## 8. O material aprovado segue pra Expedição e Faturamento

Não importa se o item veio de uma compra, de um beneficiamento na fábrica ou já estava pronto em estoque — depois de aprovado pela Qualidade, todos os caminhos se encontram na Expedição:

1. A Expedição embala e paletiza o material.
2. Se o pedido exige faturamento integral (todos os itens juntos), a Expedição aguarda os demais itens do mesmo pedido ficarem prontos antes de consolidar a carga.
3. A Logística define o transporte e o roteiro de entrega.
4. A Expedição sinaliza ao Omie que uma nota fiscal de saída precisa ser emitida — o sistema nunca emite a nota diretamente. Quando o número e a chave da nota voltam pela sincronização com o Omie, o item passa de "em aberto" para "faturado", e essa mudança já aparece pro vendedor no acompanhamento do pedido.
5. Por fim, a entrega física acontece, com o comprovante de entrega anexado ao pedido.

## Ver também
- [[Visao-Geral]]
- [[Regras-de-Negocio]]
- [[Riscos-e-Cuidados]]
- [[Quem-Faz-o-Que]]
- [[Comprando-o-que-Falta]]
- [[Qualidade-e-Conferencia]]
- [[Controlando-o-Estoque]]
- [[Fabricando-Produtos-Proprios]]
- [[Cortando-Chapas-sob-Medida]]
- [[Faturamento-e-Entrega]]
- [[Glossario]]
