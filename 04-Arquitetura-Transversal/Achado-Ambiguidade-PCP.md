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

O sistema de fábrica se chama **MES** (confirmado pelo Nathan em 22/09/2026 — aceito por ora, com abertura para trocar no futuro) e cobre Estoque + toda a fabricação (linha aberta: Flanges hoje, Grades de Piso/Chapa Expandida/Caldeiraria etc. conforme forem cadastradas — **Chapas não entra aqui**, corte de chapa é beneficiamento de Revenda, ver [[Fabricacao-Chapas]]), não só Flanges. Isso resolve a ambiguidade na prática: "PCP" (a sigla) deixa de ser o nome do sistema; o "Portal PCP" do av-hub continua existindo com esse nome (acompanhamento comercial), sem conflito. Ver [[MES-Arquitetura-Decisoes]].

## Por que isso importa

É o mesmo departamento da empresa (PCP), mas duas ferramentas com propósitos aparentemente distintos e o mesmo nome de três letras. Isso já causou confusão nesta própria análise (o autor deste vault inicialmente leu `services/pcp/pedidos.ts` no av-hub como se fosse dado de produção fabril, quando na verdade é acompanhamento de pedido/nota comercial).

## ✅ Resolvido (22/09/2026): não desambiguar — o nome compartilhado está correto

Decisão do Nathan: **não faz sentido desambiguar o nome "PCP"**, porque não é uma coincidência de nomenclatura a corrigir — é o mesmo setor da empresa de verdade, legitimamente presente nos dois sistemas: o setor de PCP é quem a fábrica **responde**, e o PCP **vê tudo** (produção de chão de fábrica, no app-pcp/MES); o "Portal PCP" do av-hub é a mesma função de PCP, só que a fatia voltada para **diligenciadores** acompanhando pedido/nota comercial. Não são dois departamentos distintos disputando o mesmo nome — é um departamento único com dois pontos de contato diferentes, cada um no sistema certo para aquela parte do trabalho dele. A recomendação anterior desta nota ("PCP Comercial" vs. "PCP Produção" ou nomes diferentes) fica **descartada**.

## Ver também
- [[AV-Hub-Modulos]]
- [[App-PCP-Visao-Geral]]
- [[PCP-Carteira]]
