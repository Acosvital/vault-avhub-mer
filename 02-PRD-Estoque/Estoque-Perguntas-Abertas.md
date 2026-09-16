---
tags: [erp-acos-vital, prd-estoque, pendencias]
criado: 2026-09-16
---

# PRD Estoque — Perguntas a Validar com o Negócio

Pontos que mudam decisão de arquitetura e **não devem ser assumidos**:

1. Qual a tolerância aceitável entre peso teórico e peso real, por categoria de material? (5% é default provisório)
2. Qual o prazo de retenção de auditoria exigido pela contabilidade/fiscal?
3. Pedidos acima de certo valor precisam de segunda aprovação (ex.: diretoria)?
4. Lote de carga inicial nasce liberado, ou passa pela mesma inspeção de qualidade que um lote normal?
5. A balança já usada tem saída digital/integração (rede, serial, arquivo exportável), ou a pesagem é lida manualmente e digitada?

## Já respondidas nesta rodada

Pesagem já existe hoje (não é investimento novo); há múltiplos depósitos; não há consignação; matéria-prima pode ser importada; fornecedor não tem duplicidade no Omie; cisão de lote é prática real; cotação entre fornecedores fica fora do sistema por enquanto.

## Ver também
- [[Estoque-Regras-Negocio]]
- [[Estoque-Roadmap]]
