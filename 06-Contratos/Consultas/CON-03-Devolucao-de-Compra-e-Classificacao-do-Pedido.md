---
id: CON-03
tipo: Consulta
status: aguardando-resposta
dono: Nathan
destinatarios: [Michele (Controladoria), Fiscal]
prazo: a combinar
canal_resposta: WhatsApp do Nathan
nos_0b: [K1, K2, K6]
bloqueia: [OQ-42, OQ-44]
criado: 2026-10-30
atualizado: 2026-10-30
---

# CON-03 · Devolução de compra e classificação do pedido

**Em uma frase:** duas perguntas de negócio que o time não consegue adivinhar: como classificar cada pedido para a comissão, e o que fazer com a devolução de uma compra ao fornecedor.

## Para quem é

- **Michele (Controladoria):** perguntas 1 e 2.
- **Fiscal:** pergunta 3, junto com a Michele.

## Contexto

Estamos desenhando o cálculo da comissão do vendedor com o custo real de cada pedido. Para fechar o desenho, faltam duas regras que só a Controladoria e o Fiscal conhecem. Sem elas, parte dos pedidos fica sem regra de comissão e o custo real pode sair errado.

## Cenário

Um pedido de 100 flanges chega de um cliente. Parte do material vem do Estoque, parte é comprada de um fornecedor. Depois da compra chegar, o fornecedor recebe de volta 10 flanges com defeito (devolução de compra). Hoje o time não sabe como isso aparece no Omie nem o que fazer com o custo do pedido.

## Como funciona hoje (o que já sabemos)

- A **revenda** comissiona por letra, pela margem, e a **fabricação** recebe 2% fixo (decisão N16-78).
- Só o Industrializado entra no simulador (N16-77).
- Para a **venda**, a devolução total vem do Omie e a parcial só chega como "houve", sem quantidade; quem informa a devolução parcial é o Fiscal ou a Controladoria (N16-74).

## O que o sistema novo precisa saber

1. Como cada pedido ou item é classificado.
2. O que é "recompra no mesmo pedido".
3. Como a devolução de compra aparece no Omie e o que ela faz com o custo.

## Perguntas

**Para a Michele**

1. Como se decide se um pedido, ou um item dele, é **Revenda**, **Industrializado** ou **Projeto**? (Resposta: uma regra em poucas linhas, ou uma lista de exemplos.)
2. O que é **recompra no mesmo pedido**: o mesmo item comprado de novo para o mesmo pedido? Como a comissão trata isso? (Resposta: uma frase e um exemplo.)

**Para a Michele e o Fiscal**

3. Quando uma **nota de entrada é devolvida ao fornecedor**, como isso aparece no Omie (que tipo de nota ou operação) e o que muda no **custo** do pedido? (Resposta: o nome da operação no Omie e uma frase sobre o custo; se puder, uma foto ou arquivo de um caso real.)

## Se ninguém responder

O desenho segue com revenda por letra e fabricação com 2% fixo (N16-78). Projeto, recompra e devolução de compra ficam sem regra no cálculo até a resposta. 🟡 Proposta do time; o Nathan confirma.

## Como responder

Pelo WhatsApp do Nathan, em texto curto. Pode responder só as perguntas que souber.

## Mensagem pronta para o WhatsApp

> Oi, Michele! Estamos fechando o cálculo da comissão com o custo real de cada pedido e faltam duas respostas que só vocês sabem.
>
> Exemplo: um pedido de 100 flanges, parte vem do Estoque e parte é comprada. Depois, 10 flanges da compra voltam ao fornecedor com defeito.
>
> 1) Como vocês decidem se um pedido (ou um item) é Revenda, Industrializado ou Projeto? Pode ser uma regra curta ou exemplos.
>
> 2) O que é "recompra no mesmo pedido"? É o mesmo item comprado de novo para o mesmo pedido? Como a comissão trata isso?
>
> 3) (com o Fiscal) Quando a nota de entrada é devolvida ao fornecedor, como isso aparece no Omie e o que muda no custo do pedido? Se tiver um caso real, manda uma foto ou o arquivo.
>
> Pode responder só o que souber. Sem resposta, o sistema segue com revenda por letra e fabricação com 2% fixo, e deixa Projeto, recompra e devolução de compra sem regra por enquanto. Obrigado!

## Respostas recebidas

(vazio até responder)

## Depois da resposta

As regras vão para o Registro de Decisões (nova decisão), para a nota [[13-Custo-Real-e-Comissao-no-Fluxo]] e para as perguntas OQ-42 e OQ-44 em [[Perguntas-Proposta-Pedido-Comissao]].
