# Contrato — Ordenação da coluna "Sistema" em GET /vendedores

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
