---
tags: [erp-acos-vital, prd-estoque, pendencias]
criado: 2026-09-16
---

# PRD Estoque — Perguntas a Validar com o Negócio

Pontos que mudam decisão de arquitetura e **não devem ser assumidos**:

1. Qual a tolerância aceitável entre peso teórico e peso real, por categoria de material? (5% é default provisório)
2. Qual o prazo de retenção de auditoria exigido pela contabilidade/fiscal? Nunca foi discutido com o time de contabilidade/fiscal ainda — palpite provisório do usuário é 5 anos (padrão comum de retenção fiscal no Brasil), mas **não confirmado**, precisa validar antes de assumir como requisito.
3. Pedidos acima de certo valor precisam de segunda aprovação (ex.: diretoria)? Em aguardo — usuário precisa conversar mais com a equipe da empresa antes de decidir.
4. Lote de carga inicial nasce liberado, ou passa pela mesma inspeção de qualidade que um lote normal?
5. A balança já usada tem saída digital/integração (rede, serial, arquivo exportável), ou a pesagem é lida manualmente e digitada? Em aguardo — usuário não sabe, precisa verificar com a operação.

## Perguntas já respondidas

Pesagem já existe hoje (não é investimento novo); há múltiplos depósitos; não há consignação; matéria-prima pode ser importada; fornecedor não tem duplicidade no Omie; cisão de lote é prática real; cotação entre fornecedores fica fora do sistema por enquanto.

## Ver também
- [[Estoque-Regras-Negocio]]
- [[Estoque-Roadmap]]
