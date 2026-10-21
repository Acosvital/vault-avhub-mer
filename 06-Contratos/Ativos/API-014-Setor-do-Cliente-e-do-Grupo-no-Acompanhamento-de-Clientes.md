---
id: API-014
aliases: ["Contrato 014", "014-Setor-do-Cliente-e-do-Grupo"]
tags: [contrato, contrato-api, acompanhamento-clientes, clientes, setor, categorizacao, grupos-de-empresa, av-hub]
criado: 2026-10-21
atualizado: 2026-10-21
status: proposta
sistemas: [hub-banco, hub-api, hub-front]
dono: "Gustavo"
etapa_0b: []
fontes: ["Pedido do Nathan de 21/10/2026", "api-acos-vital src/schemas/core_vendas_faturamento/tables/grupos_clientes (grupos e membros)", "Dump do Avhub para referência.sql (core_vendas_faturamento.grupos_clientes e grupos_clientes_membros; core_comercial.clientes.segmento)", "LOG-48 (grupos de empresa)", "API-013 (so_cliente e periodo total)"]
criado_original: 2026-10-21
---

# Contrato de API 014 — Setor do cliente e do grupo no Acompanhamento de clientes

> **Onde atua:** av-hub: banco, API, front

> [!info] Situação em 21/10/2026
> **Status:** `parcial` · **Pasta:** `Ativos` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Gustavo (banco e API); Nathan (front)
>
> - 📝 **Pedido do Nathan, 21/10/2026:** quem cuida dos clientes precisa poder **categorizar o cliente (CNPJ) ou o grupo de empresa por setor**, escolhendo de uma lista e **podendo acrescentar um setor novo** quando o cliente não é de nenhum dos listados. Lista inicial: Agricultura, Arquitetura e Design, Automotivo, Construção Civil, Energia, Indústria Naval, Mineração, Óleo & Gás, Papel & Celulose, Petroquímica, Saneamento e Siderurgia.
> - ✅ **Hoje não existe** setor do cliente na tela nem no banco do Acompanhamento. `core.parceiros` traz só `cnae` e `tipo_atividade` (vêm do Omie e não servem como lista de setores). O campo `segmento` de `core_comercial.clientes` é do CRM do Comercial, tem outra lista (INDUSTRIA, MINERACAO, ENGENHARIA…) e **não** é o setor deste contrato: os dois ficam separados.
> - ✅ **Front no `av-hub`** (`develop`, PR #235, `77ef66f`): campo de setor na tela do Acompanhamento (`SetorCampo.tsx`), serviço, tipos e planilha.
> - 🔴 **Banco e API não existem** (busca na `develop` da `api-acos-vital`, 21/10/2026): nenhuma rota `/setores_clientes` nem `PUT /clientes_setor`, e `fn_acompanhamento_clientes` não traz `id_setor`. Enquanto isso o front chama algo que a API ainda não oferece.
> - **MES (Robert): sem trabalho.**
>
> Selos em [[Regras-do-Vault]].

## Por quê

O comercial quer olhar a carteira por **setor de atuação** (quanto vendemos para Mineração, quem são os clientes de Óleo & Gás, quais não têm setor). O Omie não guarda isso do jeito que o negócio usa, então a classificação passa a ser **do Hub**, feita por quem cuida dos clientes. Como o mesmo cliente pode ter vários CNPJs (grupos de empresa, [[LOG-48-Acompanhamento-de-Clientes-Grupos-de-Empresa]]), o setor pode ser dado **ao grupo** (vale para todos os CNPJs dele) ou **a um CNPJ**.

## Regras de negócio

1. **Um setor por alvo.** Cada CNPJ e cada grupo tem **no máximo um** setor (ou nenhum = "Sem setor"). 🟡 Se o negócio quiser mais de um setor por cliente, vira uma lista; hoje a proposta é um só, porque um valor só permite somar por setor sem contar o mesmo cliente duas vezes.
2. **Alvo** = um CNPJ (`codigo_empresa` + `codigo_cliente`) **ou** um grupo ativo (`id_grupo`). Nunca os dois no mesmo vínculo.
3. **Herança:** o setor **efetivo** de um CNPJ é o dele próprio; se ele não tem, é o do grupo ao qual pertence (grupo **ativo**); se nenhum dos dois, **sem setor**. O CNPJ que tem setor próprio **prevalece** sobre o do grupo. A resposta diz de onde veio (`setor_origem`).
4. **Catálogo de setores gerenciável:** a lista inicial vem de uma migration; quem tem permissão **cria setores novos**, renomeia e desativa. Setor desativado **continua** nos vínculos que já o usam e aparece como "(inativo)", mas **não** pode ser escolhido para novos vínculos.
5. **Nome do setor:** de 2 a 60 caracteres, sem espaço nas pontas, **único sem diferença de maiúscula/minúscula e de acento** ("óleo & gás" = "Óleo & Gás"). Nome repetido: `409`.
6. **Quem pode o quê** (rotas em `auth.rotas_telas` na tela `acompanhamento-clientes`): ver o setor = `pode_visualizar`; **classificar** (vincular e remover setor) e **renomear/desativar** setor = `pode_editar`; **criar setor novo** = `pode_criar`. O vendedor (só `pode_visualizar`) vê o setor dos clientes que já enxerga e **não** altera. 🟡 Nathan confirma quem fica com `pode_editar`/`pode_criar` nos perfis.
7. **Auditoria:** todo vínculo e todo setor guardam quem criou/alterou e quando (`created_by`, `updated_by`, `created_at`, `updated_at`), como as demais tabelas de grupos.
8. Excluir um **grupo** (que só o desativa, LOG-48) **mantém** o vínculo do grupo, mas o setor dele **deixa de valer** para os membros enquanto o grupo estiver inativo (regra 3 usa só grupo ativo). Reativar o grupo volta o setor.

## 1. Banco (Gustavo): migration

Schema `core_vendas_faturamento`, junto das tabelas de grupos.

### Tabela `setores_clientes` (catálogo)

| Coluna | Tipo | Regra |
|---|---|---|
| `id` | uuid, PK, `uuidv7()` | |
| `nome` | varchar(60), NOT NULL | `CHECK (btrim(nome) = nome AND length(nome) >= 2)` |
| `ativo` | boolean, NOT NULL, default `true` | desativar em vez de apagar |
| `created_by`, `updated_by` | uuid | |
| `created_at`, `updated_at` | timestamptz, NOT NULL, default `now()` | |

- **Único por nome normalizado:** índice único em `lower(unaccent(nome))` (a extensão `unaccent` já é usada no banco para a busca sem acento; 🟡 Gustavo confirma, senão usar função própria de normalização).
- **Carga inicial** (idempotente, na própria migration, `ON CONFLICT DO NOTHING`): Agricultura, Arquitetura e Design, Automotivo, Construção Civil, Energia, Indústria Naval, Mineração, Óleo & Gás, Papel & Celulose, Petroquímica, Saneamento, Siderurgia.

### Tabela `clientes_setor` (vínculo)

| Coluna | Tipo | Regra |
|---|---|---|
| `id` | uuid, PK, `uuidv7()` | |
| `id_setor` | uuid, NOT NULL, FK para `setores_clientes(id)` | |
| `id_grupo` | uuid, FK para `grupos_clientes(id)` | preenchido quando o alvo é um grupo |
| `codigo_empresa` | uuid | preenchido quando o alvo é um CNPJ |
| `codigo_cliente` | varchar(60) | idem, `btrim(...) = ...` como em `grupos_clientes_membros` |
| `created_by`, `updated_by` | uuid | |
| `created_at`, `updated_at` | timestamptz, NOT NULL, default `now()` | |

- `CHECK`: **exatamente um** alvo: `(id_grupo IS NOT NULL) <> (codigo_empresa IS NOT NULL AND codigo_cliente IS NOT NULL)`, e `codigo_empresa` e `codigo_cliente` vêm **juntos** ou nenhum.
- **Único por alvo:** índice único parcial em `(id_grupo)` onde `id_grupo IS NOT NULL` e outro em `(codigo_empresa, codigo_cliente)` onde `id_grupo IS NULL`. Trocar o setor é `UPDATE`/upsert, nunca uma segunda linha.
- Sem FK para `core.parceiros` de propósito (o cliente pode vir da base antes do cadastro, como no vínculo de membros de grupo); a API valida só o formato.

### Função `fn_acompanhamento_clientes`

Passa a devolver três colunas novas (mudar o `RETURNS TABLE` exige `DROP` + `CREATE`, como no LOG-48 §12.2; 🟡 se for mais simples, a **rota** junta o setor depois, em SQL, e a função não muda):

| Coluna | Regra |
|---|---|
| `id_setor` | setor efetivo do CNPJ (regra 3), nulo se não tem |
| `setor` | nome do setor efetivo |
| `setor_origem` | `'cliente'` quando vem do vínculo do CNPJ, `'grupo'` quando herdado do grupo ativo, nulo sem setor |

## 2. API (Gustavo)

Todas na tela `acompanhamento-clientes` de `auth.rotas_telas`. Erros no formato da API (`{ codigo?, detail }`).

### 2.1 `GET /setores_clientes`: catálogo

| Parâmetro | Tipo | Padrão | Regra |
|---|---|---|---|
| `incluir_inativos` | booleano | `false` | `true` traz também os desativados |
| `com_contagem` | booleano | `false` | `true` acrescenta `qtd_clientes` (CNPJs com esse setor efetivo, regra 3) |

Resposta `200`, ordenada por nome (sem acento):

```json
{
  "total": 12,
  "data": [
    { "id": "0199f3a2-7c1e-7b52-9d10-3f6b2a1c8e44", "nome": "Agricultura", "ativo": true, "qtd_clientes": 87 },
    { "id": "0199f3a2-7c1e-7b52-9d10-3f6b2a1c8e45", "nome": "Óleo & Gás", "ativo": true, "qtd_clientes": 412 }
  ]
}
```

Permissão `pode_visualizar`.

### 2.2 `POST /setores_clientes`: criar setor novo

Corpo: `{ "nome": "Cimento" }`. Resposta `201` com o setor (`id`, `nome`, `ativo: true`). Nome inválido: `400`; repetido: `409 { codigo: "SETOR_JA_EXISTE", detail }` e, no mesmo corpo, o `id` do setor existente (para a tela já selecioná-lo). Permissão `pode_criar`.

### 2.3 `PUT /setores_clientes/{id}`: renomear ou ativar/desativar

Corpo: `{ "nome"?: "...", "ativo"?: true|false }` (pelo menos um). `404` se o id não existe; `409` se o nome novo já existe. Permissão `pode_editar`.

### 2.4 `PUT /clientes_setor`: classificar (um ou vários alvos)

Corpo:

```json
{
  "id_setor": "0199f3a2-7c1e-7b52-9d10-3f6b2a1c8e45",
  "alvos": [
    { "id_grupo": "0199f3a2-7c1e-7b52-9d10-3f6b2a1c8e99" },
    { "codigo_empresa": "759979bd-2b2d-41f2-b1b7-db6fae89ee59", "codigo_cliente": "9765166664" }
  ]
}
```

- `id_setor = null` **remove** o setor dos alvos (voltam a herdar do grupo, ou ficam sem setor).
- De 1 a **500** alvos por chamada, numa **transação**: se um alvo for inválido, **nada** é gravado (`400` com o índice do alvo).
- Setor inexistente: `404`; **setor inativo**: `409 { codigo: "SETOR_INATIVO" }`; grupo inexistente ou inativo: `404`.
- Faz upsert (um alvo que já tinha setor troca para o novo).
- Resposta `200`: `{ "atualizados": 2, "removidos": 0 }`.
- Permissão `pode_editar`. 🟡 O limite de 500 acompanha o `limit` máximo da lista; serve para classificar de uma vez a página inteira.

### 2.5 `GET /acompanhamento_clientes`: setor na lista, filtro e ordenação

- **Cada linha** (CNPJ) traz `id_setor`, `setor` e `setor_origem` (seção 1). Na **visão por grupo** (`visao=grupo`), a linha do grupo traz o setor **do grupo**; os CNPJs dentro (`membros`) trazem o setor efetivo de cada um.
- **Filtros novos:**

| Parâmetro | Tipo | Regra |
|---|---|---|
| `id_setor` | uuid | só clientes com esse setor efetivo. Inválido: `400 { detail: "id_setor deve ser um UUID." }` |
| `sem_setor` | booleano | `true` = só clientes sem setor efetivo. **Não** pode vir junto com `id_setor` (`400`) |

- **Ordenação:** `sort=setor` (nome sem acento; sem setor no fim, nas duas direções).
- **KPIs** (`kpis=true`): acrescentar `por_setor`: lista de `{ id_setor, setor, qtd_clientes, venda_liquida_mes, faturamento_liquido_mes }` (com `id_setor: null` para "Sem setor"), calculada sobre as **mesmas linhas filtradas** da lista, e portanto respeitando `so_cliente`, `periodo` e a unidade ([[API-013-Acompanhamento-de-Clientes-So-Cliente-e-Periodo-Total]]). Soma das linhas de `por_setor` = `total_clientes`.
- `GET /acompanhamento_clientes/movimento` e o detalhe do grupo (`/grupos_clientes/{id}`) acrescentam `id_setor` e `setor` do alvo (no grupo, o do próprio grupo).
- Todos os filtros **combinam** com busca, status, unidade, `so_cliente`, `periodo` e escopo de vendedor.

## 3. Tela (Nathan)

| Bloco | O que muda |
|---|---|
| Lista | coluna **Setor** (selo discreto, "Sem setor" em tom neutro; o setor herdado do grupo aparece com a marca "do grupo") e filtro **Setor** (a lista do catálogo + "Sem setor"), na URL (`setor=<id>` ou `setor=sem`) |
| KPIs | quadro "Por setor" (qtd de clientes e venda líquida por setor) que filtra a lista ao clicar |
| Página do cliente e do grupo | campo **Setor** com a lista, a opção **"Adicionar setor…"** (abre um campo de nome; cria e já seleciona) e "Remover setor"; só aparece editável com `pode_editar` |
| Classificar em lote | caixas de seleção na lista e a ação "Definir setor" para as linhas marcadas (usa `PUT /clientes_setor`); 🟡 Nathan decide se entra já ou numa 2ª etapa |
| Excel | coluna **Setor** (e **Setor vem de**) na aba Clientes e nas de inativos/sem compra; na aba Resumo, um quadro **por setor**; o Dicionário descreve as colunas |
| Erros | 409 de nome repetido seleciona o setor existente; setor inativo some da lista de escolha |

## Fora deste contrato

- **Setor do Omie ou do CRM:** o `segmento` de `core_comercial.clientes` e o `cnae` ficam como estão; nenhum é importado.
- **Vários setores por cliente** e **hierarquia de setores** (setor e subsetor).
- **Apagar** setor de verdade: só desativa.
- **Classificação automática** (por CNAE ou nome): a primeira entrega é manual.
- **Meta ou comissão por setor.**

## Checklist

**Gustavo (banco e API)**
- [ ] Migration: `setores_clientes` (com os 12 setores iniciais) e `clientes_setor`, com os `CHECK` e os índices únicos.
- [ ] `fn_acompanhamento_clientes` (ou a rota) devolvendo `id_setor`, `setor`, `setor_origem` pela regra de herança.
- [ ] Rotas `GET`/`POST`/`PUT /setores_clientes` e `PUT /clientes_setor`, com a transação e os erros da seção 2.
- [ ] Filtros `id_setor` e `sem_setor`, `sort=setor` e `kpis.por_setor` em `GET /acompanhamento_clientes`.
- [ ] Linhas de `auth.rotas_telas` (`acompanhamento-clientes`): `GET /setores_clientes` (`pode_visualizar`), `POST /setores_clientes` (`pode_criar`), `PUT /setores_clientes/*` e `PUT /clientes_setor` (`pode_editar`).
- [ ] Swagger das rotas novas.

**Nathan (front)**
- [ ] BFF: rotas `/api/setores-clientes` e `/api/clientes-setor` e os parâmetros novos da lista.
- [ ] Coluna, filtro e quadro por setor; campo Setor na página do cliente e do grupo; "Adicionar setor…".
- [ ] Excel com a coluna e o quadro por setor.
- [ ] Definir os perfis com `pode_editar`/`pode_criar` e se o lote entra na 1ª etapa.

**Robert (MES):** nada.

## Aceite

1. `GET /setores_clientes` devolve os 12 setores iniciais, ordenados sem acento; criar "Cimento" devolve `201`, e criar "cimento" devolve `409` com o `id` do existente.
2. Dar o setor "Mineração" a um **grupo** com 3 CNPJs: os 3 passam a vir com `setor = "Mineração"` e `setor_origem = "grupo"`. Dar "Siderurgia" a um deles: ele vem `"Siderurgia"`/`"cliente"` e os outros 2 continuam `"Mineração"`/`"grupo"`.
3. Desativar o grupo: os CNPJs que só herdavam o setor dele ficam sem setor; reativar volta.
4. `id_setor = null` em um CNPJ com setor próprio faz ele voltar a herdar o do grupo.
5. `PUT /clientes_setor` com um alvo inválido no meio de 10 não grava nenhum dos 10 e aponta o índice.
6. `GET /acompanhamento_clientes?id_setor=<uuid>` traz só esse setor; `sem_setor=true` traz o resto; os dois juntos respondem `400`.
7. `kpis.por_setor` soma exatamente `total_clientes` e muda junto com `so_cliente` e `periodo=total`.
8. Perfil só com `pode_visualizar` vê o setor e recebe `403` ao tentar `PUT /clientes_setor`.
9. Setor desativado continua aparecendo nos clientes que já o tinham e dá `409` ao ser escolhido de novo.

## Ver também
[[LOG-48-Acompanhamento-de-Clientes-Grupos-de-Empresa]] · [[API-013-Acompanhamento-de-Clientes-So-Cliente-e-Periodo-Total]] · [[Acompanhamento-Clientes]]
