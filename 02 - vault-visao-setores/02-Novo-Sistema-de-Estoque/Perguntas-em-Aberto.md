---
tags: [visao-setores, novo-sistema-estoque]
criado: 2026-09-16
---

# Perguntas em Aberto

Antes de avançar com algumas partes do projeto, existem decisões que só o próprio negócio pode tomar. Elas não devem ser assumidas por padrão — precisam ser validadas com as pessoas certas de cada área.

1. **Qual a tolerância aceitável entre o peso teórico e o peso real, por categoria de material?** Hoje o valor usado como referência provisória é 5%, mas isso ainda não foi confirmado e pode variar por tipo de material.

2. **Qual o prazo de guarda de documentos exigido pela contabilidade/fiscal?** Ainda não foi discutido com o time de contabilidade/fiscal. O palpite inicial é 5 anos (prazo comum de retenção fiscal no Brasil), mas isso precisa ser confirmado antes de virar uma regra do sistema.

3. **Pedidos de compra acima de um determinado valor precisam de uma segunda aprovação (por exemplo, da diretoria)?** Ainda em aberto — depende de conversa com a equipe da empresa antes de decidir o valor de corte.

4. **O material do levantamento inicial de estoque entra já liberado, ou precisa passar pela mesma inspeção de qualidade de um material recebido normalmente?**

5. **A balança usada hoje tem alguma forma de conectar direto com o sistema, ou a pesagem precisa continuar sendo lida manualmente e digitada?** Ainda não se sabe — precisa verificar com a operação.

## O que já foi confirmado

- A pesagem já é um processo existente hoje — não é um investimento novo.
- A empresa vai operar com mais de um depósito.
- Não existe estoque consignado (nem com cliente, nem com fornecedor).
- Matéria-prima pode ser comprada em moeda estrangeira (importação).
- Não há duplicidade de cadastro de fornecedor no sistema financeiro atual.
- Separar parte aprovada e parte reprovada de um mesmo lote já é uma prática real da operação hoje.
- Comparação de preço entre fornecedores fica fora do sistema por enquanto.

## Ver também
- [[Regras-de-Negocio]]
- [[Cronograma]]
- [[Riscos-e-Cuidados]]
