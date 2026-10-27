---
tags: [inicio, guia]
criado: 2026-10-14
atualizado: 2026-10-26
status: vigente
dono: Nathan
fontes: [plano de 14/10/2026]
---

# Comece aqui

## Em 5 minutos

1. Leia a [[Visao-do-Projeto]]: o que é o ERP Aços Vital e quais princípios o guiam.
2. Abra o [[00-Fluxo-Mestre-0b]]. É o diagrama do pedido de 0 a 100%. Cada nó (`V1`, `P2`, `E6`…) tem raia, tela, endpoint, contrato e **estado no código** (✅ 🟡 🔴).
3. Veja [[Onde-Estamos]]: uma tela com o que está pronto e o que falta, por raia.
4. Para a proposta, o Orçamento, o custo real e a comissão nova (aprovados em 26/10/2026), leia a história de ponta a ponta em `09-Diagramas/Historia-da-Proposta-ao-Pedido.pdf` e depois [[11-Proposta-e-Pedido-de-Venda]].
5. Leia as [[Regras-do-Vault]] antes de escrever qualquer nota.

## Por perfil

| Quem | Vá para |
|---|---|
| Robert (MES) | [[Backlog-por-Frente]] (frente MES), [[MES-Backend]], [[MES-Front]], [[Estados-e-Status]] |
| Gustavo (DBA, API do av-hub) | [[Backlog-por-Frente]] (frente DBA), [[AV-Hub-API]], [[Banco-AvHub]], [[Diferencas-Codigo-x-Banco]] |
| Nathan (front do av-hub) | [[AV-Hub-Front]], [[Telas-por-Raia]], [[Mapa-Rotas-BFF-Bearer]] |
| Pablo (Comercial & Suprimentos) | [[Mapa-do-Modulo-do-Pablo]], [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]], [[API-Comercial]], [[Comercial-Suprimentos]] |
| Controladoria (Michele) | [[13-Custo-Real-e-Comissao-no-Fluxo]], [[04-Regras-e-Estados-da-Comissao-Nova]] |
| Compras e Orçamento | [[04-Circuito-de-Compra]], [[12-Orcamento-Base-de-Preco]], [[11-Proposta-e-Pedido-de-Venda]] (`C6` a `C8`) |

## Como achar as coisas

- **Um contrato:** [[Painel-de-Contratos]] (ID, alias, status, nó do 0b).
- **Uma decisão:** [[Registro-de-Decisoes]].
- **Um termo:** [[Glossario]].
- **Uma nota do vault antigo:** [[Mapa-v1-para-v2]].
- **O que está solto:** [[Pontas-Soltas]], [[Perguntas-Proposta-Pedido-Comissao]] e [[Contradicoes-Resolvidas]].

## Selos

✅ no código · 📝 decidido · 🟡 proposta ou parcial · 🔴 aberto ou sem código · ❓ não conferido em produção.
