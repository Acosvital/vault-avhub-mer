---
tags: [erp-acos-vital, fluxo-operacional, pcp]
criado: 2026-09-16
---

# 2. Gestão de Carteira (PCP)

> ⚠️ Não confundir com [[Achado-Ambiguidade-PCP|o "Portal PCP" do av-hub]], que é outra coisa (acompanhamento comercial por diligenciadores). Este PCP é o setor de Planejamento e Controle de Produção.
>
> **Confirmado com o usuário (17/09/2026): esta triagem/carteira não existe em nenhum sistema hoje** — nem no Portal PCP (av-hub), nem no app-pcp/MES (que só entra depois que um item já foi destinado à Fábrica). É processo manual/informal hoje, e faz parte do que o projeto precisa construir.

- O pedido entra na fila do PCP com abertura detalhada dos itens.
- Criação da carteira de atendimento e classificação de **cada item** conforme sua origem operacional: [[Rota-Estoque|estoque]], [[Rota-Revenda|revenda]] ou [[Rota-Fabricacao|produção]].

## Por que isso importa para o modelo de dados

A classificação acontece **por item**, não por pedido inteiro — um mesmo pedido pode ter parte destinada a estoque, parte a revenda e parte a fabricação. O [[Estoque-Regras-Negocio|PRD do Estoque]] captura essa mesma necessidade em `destinacao_item_pedido`, e o [[App-PCP-Modelo-Producao|app-pcp]] também trabalha no nível do item (cada item é atribuído a uma fábrica).

## Ver também
- [[Entrada-Comercial]] (fase anterior)
- [[Rota-Estoque]], [[Rota-Revenda]], [[Rota-Fabricacao]] (fases seguintes)
- [[Modelo-Destinacao-Item]] — formaliza que "estoque" não é uma quarta classificação do mesmo tipo, é um eixo de disponibilidade avaliado dentro de Revenda/Fabricação.
