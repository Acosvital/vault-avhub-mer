---
tags: [contrato-logica, contrato-api, compras, acessos]
criado: 2026-09-29
status: aplicada
---

# Contrato 28 — Vendedores e Compradores: cadastro do Omie só para leitura, período de atividade e sugestão por semelhança

> **🔄 REVISADO em 02/10/2026 (decisão do Nathan). Substitui o pedido original de criar/excluir comprador.**
>
> **Enquanto o Omie for a origem dos cadastros:**
> 1. **Não se cria nem se exclui** vendedor ou comprador no av-hub. Volta a ser ligado quando o sistema funcionar sem o Omie.
> 2. **Não se edita o que vem do Omie**: código, `nome`, `email` (vendedor) e `ativo`.
> 3. **Os dois têm período de atividade** editável à mão: `ativo_desde` e `inativo_desde` (o de vendedores já existe, contrato 33; o de compradores é novo).
> 4. Continua valendo a **sugestão de vínculo por semelhança** para compradores (C3 abaixo).
>
> **Já feito no av-hub** (branch `feat/vendedores-somente-omie`): a tela de Vendedores perdeu "Novo" e "Excluir", mostra código, nome, e-mail e status só para leitura, e o BFF não tem mais `POST`/`DELETE` e repassa no `PUT` só os campos do av-hub. A de Compradores já não criava nem excluía.
>
> **O que falta no backend** está na seção 2 (R1–R4). C1 e C2 (criar/excluir comprador) e as perguntas antigas da seção 4 estão **cancelados**.

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

### Revisão de 02/10/2026 — o que o backend precisa fazer

| # | Onde | O quê |
|---|---|---|
| **R1** | API, `vendedores` | `POST /vendedores` e `DELETE /vendedores/{id}` **desligados** atrás de uma chave de ambiente (ex.: `CADASTROS_OMIE_SOMENTE_LEITURA=true`, ligada por padrão): respondem **403** `CADASTRO_VEM_DO_OMIE`. Assim dá para religar sem deploy quando o Omie sair. **Conferir antes** se algum processo ainda grava vendedor pelo `POST` (a pipeline grava direto no banco, mas confirmar scripts antigos). |
| **R2** | API, `vendedores` | `PUT /vendedores/{id}` **ignora** `codigo_vendedor_omie`, `codigo_empresa`, `nome`, `email` e `ativo` quando a chave está ligada (ou responde 400 se vierem diferentes do gravado). |
| **R3** | API, `compradores` | Não criar `POST`/`DELETE` (C1/C2 cancelados). `PUT /compras/compradores/{id}` continua ignorando `nome` e `ativo`. |
| **R4** | SQL + API, `compradores` | Colunas `ativo_desde date` e `inativo_desde date` em `core_vendas_faturamento.compradores`, com a mesma CHECK do vendedor (`inativo_desde >= ativo_desde`; comprador `ativo` sem `inativo_desde`), aceitas no `PUT` e devolvidas no `GET`; **protegidas na pipeline** (`protectedColumns`: `id_funcionario`, `nome_exibicao`, `ativo_desde`, `inativo_desde`). Depois, o av-hub ganha os dois campos no painel do comprador. |

### ~~C1. `POST /compras/compradores`~~ (cancelado em 02/10/2026)

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

### ~~C2. `DELETE /compras/compradores/{id}`~~ (cancelado em 02/10/2026)

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

## 3. Pipeline (item P) — **não é mais necessário** (02/10/2026: sem exclusão no av-hub)

Hoje o índice único é parcial (`WHERE deleted_at IS NULL`). Um comprador **excluído no av-hub que ainda
existe no Omie** seria **inserido de novo** pela próxima sincronização (a linha excluída não casa com o
conflito). Precisa de uma das duas saídas (decisão abaixo):

- **(a)** a pipeline não recria código que tem linha com `deleted_at` na mesma unidade; ou
- **(b)** excluir é só para comprador que **não** existe mais no Omie (o que existe, inativa).

## 4. Decisões (Nathan, 02/10/2026)

As três perguntas antigas (código fora do Omie, excluir quem está no Omie, editar `nome`/`ativo`) **deixaram de existir**: não se cria, não se exclui e não se edita o que vem do Omie, em vendedores e compradores, até o sistema funcionar sem o Omie. O item P (pipeline recriar comprador excluído) também deixa de ser necessário, porque não há exclusão.

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
