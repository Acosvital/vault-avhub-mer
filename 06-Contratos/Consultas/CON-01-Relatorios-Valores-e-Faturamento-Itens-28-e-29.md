---
id: CON-01
tipo: Consulta
status: aguardando-resposta
sistemas: [consulta]
tags: [contrato, consulta, relatorios, faturamento, av-hub]
criado: 2026-10-14
atualizado: 2026-10-14
dono: Nathan
destinatarios: [quem gera hoje o relatório de valores por mês e por vendedor, quem gera o faturamento mensal, gestão que lê os relatórios]
prazo: 2026-10-20
canal_resposta: WhatsApp do Nathan
nos_0b: [O1, O2]
bloqueia: [itens 28 e 29 do levantamento do PCP legado]
fontes: [v1 03-Sistemas-Existentes/PCP-Legado-x-MES-Lacunas.md (itens 28 e 29), Robert 08/10/2026]
---

# CON-01 · Relatórios de valores por vendedor e de faturamento mensal (itens 28 e 29)

> **Onde atua:** consulta (sem código)

## Para quem é

1. **Quem gera hoje o relatório "valores por mês e por vendedor"** (item 28), o que usa o Excel "Base Faturamento Fábrica".
2. **Quem gera hoje o faturamento mensal** (item 29), o que sobe o relatório do Omie e gera Excel ou PDF.
3. **Quem lê esses relatórios** (gestão, diretoria, comercial), para dizer o que realmente usa.

> O Nathan completa os nomes antes de enviar. O vault não registra quem gera esses relatórios.

## Contexto

Dois relatórios do PCP atual vão passar para o **av-hub**, porque tratam de dado de faturamento que hoje roda numa planilha **fora do controle da TI**. Eles têm 6 pd de trabalho cada, mas ainda **não têm dono nem data**. Antes de desenhar, precisamos saber o que cada um faz, para quem, e o que pode deixar de existir.

## Cenário

No fim do mês alguém abre a planilha "Base Faturamento Fábrica", cola os dados do faturamento oficial e tira, para a Flange, a Caldeiraria e os dois juntos, o **valor faturado por mês e por vendedor**. Em outro momento, sobe o relatório do Omie para gerar o **faturamento mensal** em Excel ou PDF, e vê as **saídas do estoque em reais**. O novo relatório no av-hub deve fazer o mesmo, com os mesmos números, sem planilha.

## Como funciona hoje (o que já sabemos)

| Item | O que faz | Formato |
|---|---|---|
| 28 | Valores por mês e por vendedor, para Flanges, Caldeiraria e os dois combinados | Excel no modelo "Base Faturamento Fábrica" |
| 29 | Faturamento mensal: sobe o relatório do Omie e gera o resultado; mostra as saídas do estoque em R$ | Excel ou PDF |

O resto precisa ser confirmado por vocês.

## O que o sistema novo precisa saber

1. De onde vêm os números (o relatório do Omie? só notas fiscais emitidas?) e como se calcula "faturado".
2. O que o relatório precisa mostrar, para quem e em qual período.
3. O que pode sair, e o que precisa ficar igual.

## Perguntas

### A. Item 28 · valores por mês e por vendedor

Mande, se possível, **o arquivo do mês passado** (pode ser parcial).

1. **Quem usa esse relatório e para quê?** (por exemplo, comissão, reunião de resultado, meta.)
2. **Que colunas e linhas ele tem?** Se mandar o arquivo, basta. Senão, liste.
3. **"Faturado" é o valor da nota fiscal emitida, do pedido, ou outro?** Considera devolução, desconto ou frete?
4. **Vendedor é o do pedido ou o da nota?** E se o vendedor mudou no meio do caminho?
5. **A divisão Flanges, Caldeiraria e combinado é por fábrica, por produto, ou por unidade (Arujá, Mogi)?** Como se decide o que é de cada uma?
6. **Quantos meses para trás se consulta?** Precisa do histórico de anos anteriores?
7. **Quem pode ver os valores?** Todos os vendedores veem todos, ou cada um vê só o seu?

### B. Item 29 · faturamento mensal

8. **Qual relatório do Omie é carregado, e com que filtros?** (o nome do relatório e o período.)
9. **Esse relatório é gerado manualmente todo mês?** Quem faz e em que dia?
10. **O resultado é para quê** (fechamento, imposto, diretoria, contador) e em que formato quem recebe (Excel, PDF)?
11. **"Saídas do estoque em R$":** de onde vêm esses valores (nota de saída, movimento de estoque, custo)? Qual valor é somado (preço de venda ou custo)?
12. **Há cálculos ou ajustes manuais** feitos na planilha depois de carregar o relatório (acertos, exclusões)? Quais?

### C. Os dois · quem lê

13. **Se o relatório saísse automático no av-hub,** com período e fábrica como filtro, o que ainda faria falta na planilha atual?
14. **Algo que a planilha faz hoje e que ninguém usa mais?** Pode ser deixado de fora?
15. **Quem precisa receber o relatório** e com que frequência (mensal, semanal, sob demanda)?

## Se ninguém responder

Os itens 28 e 29 ficam sem dono e sem data, e as planilhas continuam rodando fora da TI. O av-hub não terá o relatório, e a diretoria não terá número oficial de faturamento por vendedor.

## Como responder

- Responda direto no **WhatsApp do Nathan**, numerando como as perguntas. Pode ser por áudio.
- Mande **foto ou arquivo** da planilha atual e do relatório do Omie, se puder. O vault não guarda dado de cliente; o Nathan apaga o que for sensível antes de arquivar.

## Mensagem pronta para o WhatsApp

> Oi! Vamos levar dois relatórios do PCP atual para o av-hub, porque hoje rodam em planilha fora do controle da TI. Preciso entender como funcionam hoje, para fazer igual. Pode responder aqui, numerando, ou por áudio. Se puder, manda o arquivo do mês passado.
>
> *Valores por mês e por vendedor (planilha "Base Faturamento Fábrica")*
> 1) Quem usa e para quê (comissão, reunião, meta)?
> 2) Quais colunas e linhas tem? Se mandar o arquivo, já ajuda.
> 3) "Faturado" é valor da nota fiscal, do pedido ou outro? Considera devolução, desconto, frete?
> 4) O vendedor é o do pedido ou o da nota? E se mudou no meio?
> 5) A divisão Flanges, Caldeiraria e combinado é por fábrica, produto ou unidade? Como se decide?
> 6) Quantos meses para trás se consulta?
> 7) Quem pode ver os valores: todos veem tudo ou cada vendedor só o seu?
>
> *Faturamento mensal (relatório do Omie)*
> 8) Qual relatório do Omie você carrega e com quais filtros?
> 9) É gerado todo mês, por quem e em que dia?
> 10) Serve para quê (fechamento, imposto, diretoria, contador) e em qual formato?
> 11) As "saídas do estoque em R$" vêm de onde, e é preço de venda ou custo?
> 12) Faz algum ajuste manual na planilha depois de carregar?
>
> *Para todos*
> 13) Se saísse automático no av-hub, com filtro de período e fábrica, o que ainda faria falta?
> 14) Tem algo que a planilha faz e ninguém usa mais?
> 15) Quem precisa receber e com que frequência?
>
> Se não souber alguma, pula e diz quem sabe. Pode ser até 20/10. Obrigado!

## Respostas recebidas

_Nenhuma ainda._

| Data | Quem respondeu | Perguntas | Resposta |
|---|---|---|---|
| | | | |

## Depois da resposta

- As colunas, a regra de "faturado" e o controle de acesso viram um contrato `LOG-NN` (banco e API: Gustavo; telas: Nathan), com o texto completo no vault.
- Decidir o dono e a data dos itens 28 e 29 em [[Cronograma]] e registrar em [[Registro-de-Decisoes]].
- Atualizar [[10-Fiscal-Omie]] se o relatório depender de leitura de notas além do que o pipeline já extrai (`ListarNF`).
- Fechar a pendência em [[Pontas-Soltas]].
