---
tags: [erp-acos-vital, prd-estoque, pendencias]
criado: 2026-09-16
atualizado: 2026-10-07
---

# PRD Estoque — Perguntas a Validar com o Negócio

> Status: decidido | no código (develop) | em produção (mes-test; produção real não)

> **Atualização de 07/10/2026 (reescrita):** as cinco perguntas abaixo foram **todas respondidas ou fechadas**. A pergunta 1 foi decidida pelo Nathan em 07/10 e a 4 já estava decidida (DEC-4); as perguntas 2, 3 e 5 já tinham resposta em [[Decisoes-Chave-ERP]] (DEC-9, DEC-3, DEC-5) desde 21/09 e só duplicavam aqui. O texto anterior do banner ("nenhuma pergunta foi respondida") estava **errado** e foi substituído. Fonte das decisões desta rodada: [[Registro-de-Decisoes-2026-10-07]].

Pontos que mudavam decisão de arquitetura e **não deviam ser assumidos** (todos resolvidos):

1. ✅ **Tolerância entre peso teórico e peso real: decidido em 07/10/2026 — 5% para todas as categorias de material** (pode virar por categoria no futuro). Registro: [[Registro-de-Decisoes-2026-10-07]] (item 26). *(No código, `RecebimentoItem.toleranciaPeso` tem padrão 5% e o desvio acima dele vira divergência `PESO`; o peso real é obrigatório quando o material tem `pesoTeoricoUnitario`. Conferido em `develop`, `861c050`.)* ~~"5% é default provisório"~~ — superado.
2. ✅ Prazo de retenção de auditoria: ver **DEC-9** em [[Decisoes-Chave-ERP]] (5 anos, sem expurgo automático) e item 53 do [[Registro-de-Decisoes-2026-10-07]].
3. ✅ Aprovação de pedidos acima de certo valor: ver **DEC-3** em [[Decisoes-Chave-ERP]] (acima de R$ 30.000 o diretor aprova). Quem é o diretor aprovador segue 🔴 Nathan (item 50 do [[Registro-de-Decisoes-2026-10-07]]).
4. ✅ **Fechada.** Lote de carga inicial **nasce liberado** (DEC-4), com **dupla conferência (contador + conferente)** e **terceira contagem** em caso de divergência — [[Registro-de-Decisoes-2026-10-07]] (item 25).
5. ✅ Balança: ver **DEC-5** em [[Decisoes-Chave-ERP]] (digitação manual).

## Perguntas já respondidas

Pesagem já existe hoje (não é investimento novo); há múltiplos depósitos; não há consignação; matéria-prima pode ser importada; fornecedor não tem duplicidade no Omie; cisão de lote é prática real; cotação entre fornecedores fica fora do sistema por enquanto.

## Ver também
- [[Registro-de-Decisoes-2026-10-07]]
- [[Estoque-Regras-Negocio]]
- [[Estoque-Roadmap]]

## Custo do lote (decidido em 09/10/2026)

As sete perguntas sobre custo × venda foram **fechadas** em 09/10 (regra A de custo médio; custo da carga inicial pela coluna opcional da G1; composição como no simulador, frete fora; PTAX da OC; sobra segue o lote; Compras só confere; só revenda). Detalhe em [[Estoque-Custo-do-Lote]] e nos itens 93 a 96 de [[Registro-de-Decisoes-2026-10-07]]. **Segue em aberto:** a fonte do imposto por item (ICMS a recuperar, IPI, ST), que a OC não guarda.
