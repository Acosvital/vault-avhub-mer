---
tags: [erp-acos-vital, arquitetura, achado, nomenclatura]
criado: 2026-09-16
---

# Achado — Ambiguidade do Nome "PCP"

"PCP" é usado hoje para **duas coisas bem diferentes** dentro da Aços Vital:

## PCP #1 — Portal PCP (av-hub)

Para os **"diligenciadores"** — pessoas do setor de PCP que acompanham pedidos/notas de um grupo de vendedores. É uma função de **acompanhamento comercial/financeiro**: mesma composição Bruto→Deduções→Líquido que o gestor vê, só que escopada aos vendedores daquele diligenciador. Ver [[AV-Hub-Modulos]].

## PCP #2 — app-pcp

O sistema de **Programação e Controle de Produção de chão de fábrica** — fábricas, setores, máquinas, operadores, roteiro de produção. Hoje focado em [[Fabricacao-Flanges|Flanges]]. Ver [[App-PCP-Visao-Geral]].

> ⚠️ **Atualização (16/09):** decisão em andamento — o sistema de fábrica vai se chamar **"MES Aços Vital"** (nome de trabalho, até um nome melhor ser definido) e vai cobrir Estoque + toda a fabricação (Flanges, Chapas, Grades de Piso), não só Flanges. Isso resolve a ambiguidade na prática: "PCP" (a sigla) deixa de ser o nome do sistema; o "Portal PCP" do av-hub continua existindo com esse nome (acompanhamento comercial), sem conflito. Ver [[MES-Arquitetura-Decisoes]].

## Por que isso importa

É o mesmo departamento da empresa (PCP), mas duas ferramentas com propósitos completamente distintos e o mesmo nome de três letras. Isso já causou confusão nesta própria análise (o autor deste vault inicialmente leu `services/pcp/pedidos.ts` no av-hub como se fosse dado de produção fabril, quando na verdade é acompanhamento de pedido/nota comercial). Vale **desambiguar deliberadamente** na nomenclatura do ERP unificado — por exemplo, "PCP Comercial" (diligenciamento) vs. "PCP Produção" (chão de fábrica), ou nomes completamente diferentes.

## Ver também
- [[AV-Hub-Modulos]]
- [[App-PCP-Visao-Geral]]
- [[PCP-Carteira]]
