---
id: LOG-09a
aliases: ["Contrato 09 (vendedores)", "09-Ordenacao-Sistema-Vendedores"]
tags: [contrato, contrato-api, vendedores, ordenacao, fora-do-fluxo]
criado: 2026-10-14
atualizado: 2026-10-14
status: implementado-no-codigo
sistemas: [hub-api]
dono: "Gustavo (DBA)"
etapa_0b: []
fontes: ["api-acos-vital/src/schemas/core_vendas_faturamento/tables/vendedores/vendedores.route.js:37-46"]
---
# Contrato — Ordenação da coluna "Sistema" em GET /vendedores

> **Onde atua:** av-hub: API

> [!info] Situação em 14/10/2026
> **Status:** `implementado-no-codigo` · **Pasta:** `Entregues` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Gustavo (DBA)
>
> - ✅ `sort=nome_unidade` ordena pelo nome da unidade com `core.fn_nome_unidade` (`vendedores.route.js:37-46`).
>
> Conferido em 14/10/2026 contra `api-pcp` 579a625, `app-pcp` 1fca8d3, `api-acos-vital` f322dcd, `omie-elt-pipeline` 0f739f0 e os dumps de 14/10. O front do av-hub (HUB b55ac55) só pelo vault v1 (❓).
> O texto original abaixo está inteiro.

> [!abstract] Resumo em linguagem natural
> **O que é:** Fez a coluna "Sistema" da tela de Vendedores ordenar pelo nome da unidade, e não pelo código bruto, que não segue a ordem alfabética.
> **Quem é afetado:** Quem usa o cadastro de Vendedores: o cabeçalho "Sistema" volta a ordenar como aparece na tela.
> **Situação:** ✅ Entregue: `sort=nome_unidade` ordena pelo nome da unidade.


**Criado em:** 15/09/2026, horário de Brasília

**Objetivo:** a tela de Cadastro de Vendedores já ordena de verdade no servidor por `nome`,
`nome_exibicao`, `email`, `filial`, `comissao` e `ativo` (ver
[`OK - contrato-ordenacao-vendedores.md`](./implementados/OK%20-%20contrato-ordenacao-vendedores.md), resolvido).
Falta só a coluna "Sistema", que a tela mostra como o **nome da unidade** (ex.: "Aços Vital",
"Aços Uberaba"), resolvido a partir de `codigo_empresa` via lookup em `unidades`.

## 1. O problema

`codigo_empresa` é uma coluna real de `vendedores` e, por isso, ordenável hoje (`sort=codigo_empresa`
já funciona, mesma convenção do contrato anterior). Mas o código não segue necessariamente a
ordem alfabética do nome da unidade — ordenar por `codigo_empresa` produz uma ordem que não bate
com o que a coluna "Sistema" mostra na tela, confundindo quem clica pra ordenar por ali.

## 2. O que peço

Uma forma de `GET /vendedores?sort=...&order=...` ordenar pelo **nome da unidade** (o mesmo valor
que já aparece resolvido como `nome_fantasia` em `unidades`), não pelo código bruto. Não tenho
preferência de nome de parâmetro — pode ser um valor aceito a mais em `sort` (ex.:
`sort=nome_unidade`, resolvendo via join com `unidades.nome_fantasia`) ou qualquer convenção que já
exista no serviço pra ordenar por coluna de tabela relacionada.

## 3. O que muda no frontend quando isso existir

Volto a habilitar a coluna "Sistema" como ordenável em
`app/(protected)/cadastros/acessos/vendedores/page.tsx` (hoje deixada de propósito como
`column: null`, ver comentário em `SortColumn`), apontando pro novo valor de `sort`. Troca
mecânica, sem mudança de UI.

## 4. Não bloqueia

A coluna "Sistema" continua visível e correta na tela, só sem o cabeçalho clicável pra ordenar —
não afeta nenhuma outra funcionalidade.
