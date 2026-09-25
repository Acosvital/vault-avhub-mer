---
tags: [erp-acos-vital, fluxo-operacional, revenda]
criado: 2026-09-16
---

# Corte de Chapas (Beneficiamento)

Este item **não é uma sub-rota de Fabricação** — é um passo de **beneficiamento dentro da [[Rota-Revenda|Rota Revenda]]**. Ver [[Fluxo-Detalhado-Pedido-Item]] para o fluxo completo.

## O que isso é de fato

Corte a plasma/laser de chapa (cortar sob medida uma chapa comprada inteira) é um **beneficiamento opcional** de um item de Revenda — não exige um sistema de produção dedicado como Flange. O item continua sendo tratado como Revenda. Ver [[Fluxo-Detalhado-Pedido-Item]].

**Como fica no MES (24/09/2026):** o corte é um **setor `PRODUTIVO` opcional no roteiro da fábrica Revenda**, escolhido pelo PCP ao montar a OP: `ESTOQUE` → `COMPRAS` → Recebimento → **Corte** → Qualidade → `ESTOQUE` → entrega. Resolve a "fábrica leve" que ficava em aberto — não é preciso uma fábrica "Beneficiamento" à parte, nem um retorno ao PCP para emitir a OS. Consumo da chapa inteira que já está em estoque (matéria-prima) fica para a J3. Ver [[Encaixe-Estoque-Revenda-no-PCP]].

> **Confirmado com o usuário (17/09/2026): nada disso existe em sistema hoje** — é parte do mesmo fluxograma-alvo do fluxo detalhado (PCP, requisição de compra, OS, Qualidade), 100% a construir.

## Não confundir com "Chapa Expandida"

**"Chapa expandida"** é um produto de linha própria (Fabricação, junto com Flange e Grade de Piso), diferente de "chapa cortada sob medida" (Revenda + beneficiamento). Nomes parecidos, categorias diferentes — vale reforçar essa distinção na nomenclatura do sistema pra não confundir compradores/PCP.

## Ver também
- [[Encaixe-Estoque-Revenda-no-PCP]]
- [[Rota-Revenda]]
- [[Fluxo-Detalhado-Pedido-Item]]
- [[Rota-Fabricacao]] — para a diferença com linhas de produção reais (Flange, Grade de Piso, Chapa Expandida, Caldeiraria etc.)
