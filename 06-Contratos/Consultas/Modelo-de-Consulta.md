---
tags: [contrato, consulta, modelo]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [pedido do Nathan de 14/10/2026]
---

# Contrato de Consulta (tipo `CON`)

Os outros contratos pedem uma **mudança** (banco, API, lógica fora do backend). O contrato de Consulta pede uma **resposta**. Serve para tirar dúvida de negócio com quem conhece o assunto, quando o time não pode adivinhar a regra: damos o contexto, descrevemos um cenário, explicamos o que o sistema precisa e perguntamos. A resposta volta pelo **WhatsApp do Nathan** e é registrada no vault.

## Quando abrir uma Consulta

- A regra de negócio não está em código nem em documento, só na cabeça de quem opera.
- Duas pessoas do time dependem da resposta (por exemplo, o Robert não consegue modelar sem ela).
- A pergunta cabe em respostas curtas. Se for preciso uma reunião, a Consulta serve só para preparar a pauta.

## Regras de escrita

1. **Quem lê não conhece o sistema.** Escreva para o operador, o líder ou o gestor, não para o dev. Nada de nome de tabela ou de endpoint na parte que a pessoa lê.
2. **Contexto em poucas linhas:** o que estamos fazendo e por que a resposta importa.
3. **Cenário com exemplo concreto,** com números e nomes de coisas reais (pedido, peça, material). Pessoas respondem melhor a "uma peça de 12 kg chega com certificado da usina" do que a "como funciona a rastreabilidade?".
4. **Perguntas numeradas, uma ideia por pergunta,** agrupadas por destinatário. Cada pergunta diz **como responder** (sim ou não, um número, uma lista, uma foto ou arquivo).
5. **Sempre inclua o que acontece sem resposta** (o default que o time vai adotar) para a pessoa saber o custo de não responder.
6. **Mensagem pronta para WhatsApp** no fim: texto completo e autossuficiente, para colar e enviar. A pessoa não precisa abrir o vault.

## Estrutura da nota

```
---
id: CON-NN
tipo: Consulta
status: aguardando-resposta | respondida | arquivada
dono: Nathan            (quem recebe as respostas)
destinatarios: [papel ou nome]
prazo: AAAA-MM-DD
canal_resposta: WhatsApp do Nathan
nos_0b: [IDs dos nós do fluxo afetados]
bloqueia: [BL-NNN, PS-NNN]
---
# CON-NN · título
## Para quem é
## Contexto
## Cenário
## Como funciona hoje (o que já sabemos)
## O que o sistema novo precisa saber
## Perguntas        (numeradas, por destinatário, com formato da resposta)
## Se ninguém responder    (default adotado)
## Como responder
## Mensagem pronta para o WhatsApp
## Respostas recebidas    (data, quem, texto; vazio até responder)
## Depois da resposta     (o que vira regra, em qual nota, em qual contrato)
```

## Ciclo de vida

1. **Aguardando resposta:** o Nathan envia a mensagem pronta. Marque a data de envio.
2. **Respondida:** cole as respostas em "Respostas recebidas", com data e nome. Atualize "Depois da resposta".
3. **Aplicada:** a regra foi para a nota de raia, o Registro de Decisões (nova decisão `N<dia>-NN`) e, se houver desenvolvimento, para o Backlog. Mude o status para `arquivada` e mova a nota para `Arquivados/`.

O [[Painel-de-Contratos]] lista as Consultas abertas. O ID usa o prefixo `CON-` e a numeração é própria, sem relação com os outros tipos.

## Consultas abertas

- [[CON-01-Relatorios-Valores-e-Faturamento-Itens-28-e-29]]
- [[CON-02-Rastreabilidade-e-Book-Itens-18-e-20]]
- [[CON-03-Devolucao-de-Compra-e-Classificacao-do-Pedido]]
