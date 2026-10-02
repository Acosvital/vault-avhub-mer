---
tags: [contrato-logica, contrato-api, compras, acessos]
criado: 2026-09-29
status: aplicada
---

# Contrato 28 — Compradores: criar, excluir e sugestão por semelhança (igual a Vendedores)

> **❌ NÃO ENTREGUE (01/10/2026).** **Conferência de 01/10/2026 na `api-test`** (o DBA avisou que concluiu): `POST /compras/compradores` e `DELETE /compras/compradores/{id}` respondem **404 "Rota não encontrada"** e não existem na `develop` da API. `GET …/sugestoes` existe, mas não deu para testar o `min_score` (0 compradores na `api-test`). **Voltar ao DBA.**

**Criado em:** 29/09/2026 · **Para:** backend (`api-acos-vital`) e, no item P, a pipeline
(`omie-elt-pipeline`) · **Complementa:** [[18-Compradores-Funcionario]]

---

## 1. Por quê

O Nathan pediu que a tela **Cadastros › Acessos › Compradores** tenha as mesmas funcionalidades da tela
de **Vendedores**. Três delas dependem do backend:

1. **Criar** comprador (botão "Novo").
2. **Excluir** comprador.
3. **Sugestão de vínculo por semelhança de nome**, com a sensibilidade ajustável (`min_score`). Hoje a
   sugestão do comprador só casa **nome idêntico** em outra unidade; a do vendedor usa `pg_trgm` e
   também sugere funcionário do RH com nome parecido.

**Isso muda uma decisão do contrato 16** ("sem POST nem DELETE: o comprador nasce e morre no Omie").
O Nathan decidiu reabrir em 29/09/2026.

**Limitação do Omie:** a API do Omie **não tem inclusão de comprador** (`/estoque/comprador/` só tem
`ListarCompradores`). Criar no av-hub **não cria no Omie**. O caso de uso é cadastrar um comprador que
**já existe no Omie** antes de a pipeline sincronizar, com o **mesmo código** (`nCodigo`). Um código que
não existe no Omie faria a OC ir com um `nCodCompr` desconhecido (ver P e Perguntas).

A ordenação por coluna já é feita pelo av-hub: a listagem aceita `sort`/`order`.

## 2. O contrato (API)

### C1. `POST /compras/compradores`

```
POST /compras/compradores
{ "codigo_empresa": "<uuid>", "codigo_comprador_omie": "10219958954", "nome": "FULANO",
  "nome_exibicao": null, "ativo": true, "id_funcionario": null, "created_by": "<uuid>" }
→ 201 com o comprador (mesmo formato do GET /compras/compradores/{id})
```

- Obrigatórios: `codigo_empresa`, `codigo_comprador_omie`, `nome`.
- `codigo_empresa` precisa ser unidade que compra por conta própria (`id_unidade_compra` nulo): 400 para
  a HRM, que compra pela de Mogi.
- **409** `"Já existe o comprador <código> em <unidade>"` quando viola `uq_compradores_empresa_codigo`.
- **409** `"Este funcionário já é comprador nesta unidade (<nome>)"` (mesma regra do PUT).
- Quando a pipeline sincronizar e o código existir no Omie, o upsert atualiza **a mesma linha**
  (`nome` e `ativo` passam a vir do Omie; `nome_exibicao` e `id_funcionario` continuam protegidos).

### C2. `DELETE /compras/compradores/{id}`

- **Soft delete** (`deleted_at`, `deleted_by`), como o resto do banco.
- **409** `"O comprador tem <N> ordens de compra e não pode ser excluído"` quando alguma
  `ordens_compra.id_comprador` aponta para ele. Nesse caso a tela sugere inativar (ver Perguntas).
- 404 se não existe.

### C3. `GET /compras/compradores/{id}/sugestoes?min_score=&limit=`

Mesmo comportamento de `GET /vendedores/{id}/sugestoes`:

- Dois caminhos, nesta ordem:
  1. `comprador_vinculado`: comprador de **nome parecido** (`similarity(unaccent(lower()))`) em **outra
     unidade**, já vinculado a um funcionário (o caso de hoje, mas por semelhança, não igualdade);
  2. `funcionario_similar`: **funcionário do RH** de nome parecido (sem filtro de setor: há compradores
     em Compras, Logística, PCP e Vendas).
- `min_score` (0 a 1, padrão **0.3**) e `limit` (padrão 5).
- Resposta **compatível com a de hoje** (o av-hub já lê `sugestao`), mais `ja_vinculado` e `candidatos`:

```json
{ "ja_vinculado": false,
  "sugestao": { "id_funcionario": "…", "nome_funcionario": "…", "score": 0.55,
                "origem": "comprador_vinculado", "codigo_empresa_origem": "…", "nome_unidade_origem": "…" },
  "candidatos": [ … ] }
```

## 3. Pipeline (item P)

Hoje o índice único é parcial (`WHERE deleted_at IS NULL`). Um comprador **excluído no av-hub que ainda
existe no Omie** seria **inserido de novo** pela próxima sincronização (a linha excluída não casa com o
conflito). Precisa de uma das duas saídas (decisão abaixo):

- **(a)** a pipeline não recria código que tem linha com `deleted_at` na mesma unidade; ou
- **(b)** excluir é só para comprador que **não** existe mais no Omie (o que existe, inativa).

## 4. Perguntas em aberto (Nathan)

1. **Código que não existe no Omie:** o POST deve aceitar? Recomendação: aceitar (não há como a API do
   Omie confirmar sem chamar o Omie), mas a tela avisa que a OC só vai ao Omie se o código existir lá.
2. **Excluir comprador que ainda está no Omie:** (a) ou (b) do item P? Recomendação: **(a)**, para
   "excluir" valer mesmo.
3. **Editar `nome` e `ativo` à mão**, como em Vendedores? Hoje os dois vêm do Omie e o PUT os ignora. Se
   sim, a pipeline sobrescreve na sincronização seguinte (ou esses campos entram nas colunas protegidas).

## 5. Depois de aplicado (av-hub)

- Botão **Novo comprador** (quem tem `pode_criar` em `compradores`): unidade, código do Omie, nome,
  nome de exibição, funcionário.
- **Excluir** no painel (quem tem `pode_deletar`), com confirmação; o 409 aparece como mensagem.
- Sugestão com o **controle de sensibilidade** e a lista de candidatos, como em Vendedores.
- Permissões: hoje só o Admin (Dev) tem `pode_visualizar`/`pode_editar` na `api-test`; `pode_criar` e
  `pode_deletar` a definir.

## 6. Aceite

- POST de um comprador novo aparece na lista; POST repetido (mesma unidade e código) → 409.
- DELETE de comprador sem OC some da lista; com OC → 409 com a quantidade.
- Com a pipeline ligada, o comprador criado à mão e que existe no Omie **não duplica**, e o excluído não
  volta (se a decisão for (a)).
- `GET /sugestoes?min_score=0.2` de um comprador "JOARES ALVES" sugere o funcionário "Joares Alves dos
  Santos" (mesmo exemplo de Vendedores); `min_score=0.9` não sugere.
