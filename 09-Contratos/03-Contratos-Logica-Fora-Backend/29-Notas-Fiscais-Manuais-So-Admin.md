---
tags: [contrato-logica, contrato-api, faturamento, permissoes]
criado: 2026-09-29
status: proposta
---

# Contrato 29 — Notas fiscais manuais: só o administrador cria (permissão no backend)

**Criado em:** 29/09/2026 · **Para:** DBA e backend (`api-acos-vital`)
**Complementa:** o cadastro manual de NF que o backend entregou em 29/09/2026 (`POST /nota_fiscal_saida/manual`,
commit `13a3691` — no código da API ele aparece como "contrato 28", que **não é** o
[[28-Compradores-Criar-Excluir-Sugestao]] deste vault).

---

## 1. Por quê

A nota manual entra nos dashboards de faturamento como **faturamento líquido do vendedor escolhido**. Nas
mãos de qualquer um, vira um jeito de inflar o número (e a comissão) de alguém com uma nota "por fora".
Decisão do Nathan (29/09/2026): **só o administrador cria** nota manual.

Hoje o `POST /nota_fiscal_saida/manual` só confere a `x-api-key`: qualquer sistema com a chave (pipeline,
MES, outro sistema do mesmo login) consegue criar nota. O av-hub barra no BFF, mas a regra de verdade
precisa estar no backend.

## 2. O contrato

### P1. Tela e permissões (DBA) — o DBA já está fazendo (29/09)

- Tela **`notas-fiscais-manuais`** em `auth.telas`, **dentro de Dashboards** (`id_parent` = `dashboards`).
  **Esse slug é o que o av-hub usa** — se o DBA escolher outro nome, avisar para trocar no av-hub
  (`lib/api/notasManuais.ts`, `TELA_NOTAS_MANUAIS`).
- Permissões: **só o perfil de administrador** com `pode_visualizar`, `pode_criar`, `pode_editar` e
  `pode_deletar`. Nenhum outro perfil.
- O av-hub usa: `pode_visualizar` para listar, `pode_criar` para cadastrar, `pode_editar` para alterar,
  `pode_deletar` para excluir.

### P2. O backend confere a permissão (API)

- `POST /nota_fiscal_saida/manual`: exige **usuário identificado** (token) com `pode_criar` na tela
  `notas-fiscais-manuais`. Sem token ou sem a permissão → **403**. A `x-api-key` sozinha não basta.
- `PUT`/`PATCH`/`DELETE /nota_fiscal_saida/{codigo}` **de nota manual** (`manual = true`): exigem
  `pode_editar` / `pode_deletar` na mesma tela.
- As mesmas rotas **não podem transformar nota do Omie em manual nem o contrário** (o campo `manual` fica
  fora do `UPDATE_FIELDS`), e editar nota do Omie continua sendo só da pipeline.
- Se for preciso ligar aos poucos, atrás de uma chave de ambiente (como `COMPRAS_EXIGIR_PODE_APROVAR`),
  mas o padrão em produção é **ligada**.

### P3. Auditoria

- `created_by` e `updated_by` **obrigatórios** na nota manual (sai do token).
- A listagem (`GET /nota_fiscal_saida?manual=true`) devolve também `nome_criado_por`, `nome_alterado_por`
  e o **número** do pedido de venda (`numero_pedido`), além do `codigo_pedido_omie` — a tela mostra
  "cadastrada por … em …" e o pedido pelo número.
- Nota manual excluída continua no banco (`deleted_at`, `deleted_by`).
- Recomendado: histórico das alterações de valor (valor anterior → novo, quem, quando), no mesmo molde
  do histórico da OC.

## 3. Depois de aplicado (av-hub)

- Nada muda nas permissões do av-hub se o slug for `notas-fiscais-manuais`.
- O painel mostra quem cadastrou/alterou e o número do pedido (P3).

## 4. Aceite

- Um usuário sem a permissão recebe 403 no `POST /nota_fiscal_saida/manual`, mesmo com a `x-api-key`.
- Uma chamada só com a `x-api-key` (sem token) também recebe 403.
- O administrador cria, edita e exclui; cada operação grava quem fez.
- `PUT` com `manual: false` numa nota manual (ou `true` numa do Omie) não muda o campo.
