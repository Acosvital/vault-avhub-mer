---
tags: [visao-setores, sistemas-existentes]
criado: 2026-09-16
---

# Comissões

## Como funciona hoje

O cálculo de comissão hoje depende de uma combinação de dois percentuais: um definido pelo lado do vendedor e outro pelo lado de compras — vale sempre o **menor** dos dois. Esse resultado é o que efetivamente define a comissão de um pedido.

Além disso, existe uma comissão provisória, calculada antes do fechamento oficial do mês, e regras de comissão fixa para casos específicos.

### Listas de bloqueio de comissão

Existe uma lista de bloqueio específica para comissão (por vendedor e por cliente/destinatário) e também um mecanismo mais amplo de bloqueio por pedido ou nota específica, com motivo registrado. **Atenção**: essas listas são diferentes das listas de bloqueio usadas no cálculo de venda líquida (ver [[Como-Vendas-e-Faturamento-Funcionam]]) — apesar do nome parecido, uma bloqueia o valor de venda que entra no relatório de faturamento, a outra bloqueia especificamente o pagamento de comissão. São coisas separadas, com propósitos diferentes.

## O simulador de comissão (em desenvolvimento)

Hoje, na prática, o vendedor tira um pedido no Omie e depois usa uma planilha Excel manual para calcular o preço de venda e a comissão daquele pedido. Essa planilha tem uma fórmula quebrada — ela multiplica uma letra de classificação como se fosse um número, o que gera erro na célula.

Está em construção, dentro do av-hub (menu Operações → Experimental), um **simulador de comissão** que substitui essa planilha manual. Hoje ele é um protótipo — funciona na tela, mas ainda não grava as simulações feitas.

### Como o simulador calcula

1. Calcula o custo líquido do item (o que a empresa pagou, descontando impostos recuperáveis e somando os que incidem na compra).
2. Aplica uma margem/markup (que já embute a margem desejada, despesas fixas, impostos sobre a venda e uma provisão de comissão) para sugerir o preço de venda.
3. Calcula a margem líquida real do pedido inteiro e converte esse número numa letra de classificação (de A a D), que define o percentual de comissão:

| Margem líquida real | Classificação | % de Comissão |
|---|---|---|
| Até 0% (prejuízo) | D | 0% (nunca paga comissão no prejuízo) |
| Acima de 0% até 8,99% | D | 0,5% |
| 9% a 11,99% | C | 0,7% |
| 12% a 14,99% | B | 1,3% |
| 15% ou mais | A | 2% |

O simulador corrige 4 problemas que existiam na planilha antiga: a fórmula que multiplicava letra por valor, uma célula que misturava reais com percentual, o prejuízo que não zerava a comissão corretamente, e um imposto que era calculado olhando só o primeiro item do pedido em vez do pedido inteiro.

## Próximo passo

Já existe, por trás do simulador, uma estrutura pronta para guardar simulações, parâmetros (como percentual de imposto por estado) e regras de comissão de forma permanente — hoje esses parâmetros estão fixos dentro do próprio simulador, mas a ideia é que passem a ser configuráveis. O próximo passo natural do simulador não é "construir do zero", é conectar o que já existe na tela a essa estrutura que já foi preparada.

Vale esclarecer com o time se esse simulador é a mesma iniciativa de uma automação de comissão em Python que já existe como projeto separado, ou se são duas frentes de trabalho paralelas que precisam ser reconciliadas.

## Ver também
- [[av-hub]]
- [[Como-Vendas-e-Faturamento-Funcionam]]
- [[Portal-do-Vendedor]]
