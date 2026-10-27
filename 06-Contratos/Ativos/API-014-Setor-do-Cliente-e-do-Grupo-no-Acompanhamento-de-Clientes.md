---
id: API-014
aliases: ["Contrato 014", "014-Setor-do-Cliente-e-do-Grupo"]
tags: [contrato, contrato-api, acompanhamento-clientes, clientes, setor, categorizacao, grupos-de-empresa, av-hub]
criado: 2026-10-21
atualizado: 2026-10-26
status: parcial
sistemas: [hub-banco, hub-api, hub-front]
dono: "Gustavo"
etapa_0b: []
fontes: ["Pedido do Nathan de 21/10/2026", "api-acos-vital src/schemas/core_vendas_faturamento/tables/grupos_clientes (grupos e membros)", "Dump do Avhub para referência.sql (core_vendas_faturamento.grupos_clientes e grupos_clientes_membros; core_comercial.clientes.segmento)", "LOG-48 (grupos de empresa)", "API-013 (so_cliente e periodo total)"]
criado_original: 2026-10-21
---

# Contrato de API 014 — Setor do cliente e do grupo no Acompanhamento de clientes

> **Onde atua:** av-hub: banco, API, front

> [!info] Situação em 26/10/2026
> **Status:** `parcial` · **Pasta:** `Ativos` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Gustavo (banco e API); Nathan (front)
>
> - ✅ **Vários setores por cliente: feito no banco e na API, informado pelo Gustavo (26/10/2026):** commit `43dbec3` e migration `api014b` em produção; `kpis.por_setor` existe em `/acompanhamento_clientes` e o cliente conta em cada um dos setores dele.
> - ✅ **Conferido por mim em 26/10/2026 (só leitura, na API em uso pelo av-hub):** cada linha traz `setores` (lista; vem com `setor_ativo` a mais) além de `id_setor`/`setor`; `kpis.por_setor` vem com Construção Civil 1, Farmacêutico 1, Mineração 1, Óleo & Gás 2 e "sem setor" 4.004 (soma 4.009 = `total_clientes`). 🟡 **Ainda não vi nenhum cliente com 2 ou mais setores** (por isso a soma fecha no total), então **salvar 2 setores**, o filtro `id_setor` com 2, o Excel e o `403` do perfil só de leitura **não foram conferidos** (gravam dados reais). O front de vários setores está na `develop` do av-hub (`a24d187`, 23/10).
> - 📝 **Pedido do Nathan, 21/10/2026:** quem cuida dos clientes precisa poder **categorizar o cliente (CNPJ) ou o grupo de empresa por setor**, escolhendo de uma lista e **podendo acrescentar um setor novo** quando o cliente não é de nenhum dos listados. Lista inicial: Agricultura, Arquitetura e Design, Automotivo, Construção Civil, Energia, Indústria Naval, Mineração, Óleo & Gás, Papel & Celulose, Petroquímica, Saneamento e Siderurgia.
> - ✅ **Hoje não existe** setor do cliente na tela nem no banco do Acompanhamento. `core.parceiros` traz só `cnae` e `tipo_atividade` (vêm do Omie e não servem como lista de setores). O campo `segmento` de `core_comercial.clientes` é do CRM do Comercial, tem outra lista (INDUSTRIA, MINERACAO, ENGENHARIA…) e **não** é o setor deste contrato: os dois ficam separados.
> - ✅ **Front no `av-hub`** (`develop`, PR #235, `77ef66f`): campo de setor na tela do Acompanhamento (`SetorCampo.tsx`), serviço, tipos e planilha.
> - ✅ **Conferido em 22/10/2026 no preview** (perfil admin), depois de o Gustavo informar que concluiu: `GET /setores_clientes` responde 200 com os 12 setores iniciais; `GET /acompanhamento_clientes` responde 200 com `id_setor`, `setor` e `setor_origem` em cada linha e aceita `id_setor` e `sem_setor`. Só leitura: o primeiro cliente veio sem setor, como esperado.
> - 🕓 Registro de 22/10 (superado pelo item acima): `kpis.por_setor` não aparecia na resposta; hoje aparece.
> - 🕓 Registro de 21/10 (já superado, mantido como histórico): **Banco e API não existiam** (busca na `develop` da `api-acos-vital`, 21/10/2026): nenhuma rota `/setores_clientes` nem `PUT /clientes_setor`, e `fn_acompanhamento_clientes` não traz `id_setor`. Enquanto isso o front chama algo que a API ainda não oferece.
> - 📝 **Mudança de regra, Nathan, 23/10/2026: um cliente (CNPJ ou grupo) pode ter MAIS DE UM setor.** Substitui a regra 1 ("um setor por alvo"). Decididos na mesma conversa: (a) **herança**: o CNPJ com setor(es) próprio(s) usa **só os dele** e ignora os do grupo (o que o grupo tem só vale para o CNPJ que não tem nenhum); (b) **contagem**: nos totais por setor o cliente conta **em cada um dos seus setores**, então a soma dos setores pode passar do total de clientes. O banco e a API entregues em 22/10 (um setor só) precisam mudar: ver as seções 1 e 2 e o checklist.
> - **MES (Robert): sem trabalho.**
>
> Selos em [[Regras-do-Vault]].

## Por quê

O comercial quer olhar a carteira por **setor de atuação** (quanto vendemos para Mineração, quem são os clientes de Óleo & Gás, quais não têm setor). O Omie não guarda isso do jeito que o negócio usa, então a classificação passa a ser **do Hub**, feita por quem cuida dos clientes. Como o mesmo cliente pode ter vários CNPJs (grupos de empresa, [[LOG-48-Acompanhamento-de-Clientes-Grupos-de-Empresa]]), o setor pode ser dado **ao grupo** (vale para todos os CNPJs dele) ou **a um CNPJ**.

## Regras de negócio

1. **Vários setores por alvo (revisada em 23/10/2026).** Cada CNPJ e cada grupo tem **zero ou mais** setores (zero = "Sem setor"), **sem repetir o mesmo setor** no mesmo alvo. Não há "setor principal". 📝 Decisão do Nathan (a versão de 21/10 era "no máximo um").
2. **Alvo** = um CNPJ (`codigo_empresa` + `codigo_cliente`) **ou** um grupo ativo (`id_grupo`). Nunca os dois no mesmo vínculo.
3. **Herança:** os setores **efetivos** de um CNPJ são **os dele próprios**; se ele não tem **nenhum**, são os do grupo ao qual pertence (grupo **ativo**); se nenhum dos dois, **sem setor**. O CNPJ com setor próprio usa **só os dele**: os do grupo **não somam**. A resposta diz de onde vêm (`setor_origem`, o mesmo para todos os setores da linha). 📝 Decisão do Nathan (23/10).
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
- **Único por alvo e setor (revisado em 23/10):** índice único parcial em `(id_grupo, id_setor)` onde `id_grupo IS NOT NULL` e outro em `(codigo_empresa, codigo_cliente, id_setor)` onde `id_grupo IS NULL`. **Uma linha por setor do alvo.** Os índices únicos por alvo da versão de 21/10 (`(id_grupo)` e `(codigo_empresa, codigo_cliente)`) **saem** (migration nova que os derruba e cria estes).
- **Salvar é trocar o conjunto:** `PUT /clientes_setor` leva a **lista completa** de setores do alvo; a API insere os que faltam e apaga (físico, só na tabela de vínculo) os que saíram, tudo numa transação.
- Sem FK para `core.parceiros` de propósito (o cliente pode vir da base antes do cadastro, como no vínculo de membros de grupo); a API valida só o formato.

### Função `fn_acompanhamento_clientes`

Passa a devolver duas colunas novas (mudar o `RETURNS TABLE` exige `DROP` + `CREATE`, como no LOG-48 §12.2; 🟡 se for mais simples, a **rota** junta os setores depois, em SQL, e a função não muda):

| Coluna | Regra |
|---|---|
| `setores` | **lista** dos setores efetivos do CNPJ (regra 3), ordenada por nome sem acento; `[]` se não tem. Cada item: `{ "id_setor": uuid, "setor": "nome" }` |
| `setor_origem` | `'cliente'` quando vêm do vínculo do CNPJ, `'grupo'` quando herdados do grupo ativo, nulo sem setor |

**Compatibilidade (até a tela migrar):** `id_setor` e `setor` continuam na resposta com o **primeiro** da lista (ordem por nome), para a tela atual não quebrar. A tela nova lê `setores`. Quando a tela migrar, o Nathan avisa e o Gustavo pode tirar os dois.

## 2. API (Gustavo)

Todas na tela `acompanhamento-clientes` de `auth.rotas_telas`. Erros no formato da API (`{ codigo?, detail }`).

### 2.1 `GET /setores_clientes`: catálogo

| Parâmetro | Tipo | Padrão | Regra |
|---|---|---|---|
| `incluir_inativos` | booleano | `false` | `true` traz também os desativados |
| `com_contagem` | booleano | `false` | `true` acrescenta `qtd_clientes` (CNPJs que têm esse setor entre os efetivos, regra 3; um CNPJ com 2 setores conta nos dois) |

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

Corpo (revisado em 23/10/2026: **`id_setores`**, uma lista; o `id_setor` único da versão de 21/10 continua aceito por compatibilidade e vale como lista de um):

```json
{
  "id_setores": [
    "0199f3a2-7c1e-7b52-9d10-3f6b2a1c8e45",
    "0199f3a2-7c1e-7b52-9d10-3f6b2a1c8e46"
  ],
  "alvos": [
    { "id_grupo": "0199f3a2-7c1e-7b52-9d10-3f6b2a1c8e99" },
    { "codigo_empresa": "759979bd-2b2d-41f2-b1b7-db6fae89ee59", "codigo_cliente": "9765166664" }
  ]
}
```

- `id_setores` é o **conjunto final** de cada alvo (substitui o que havia). `[]` ou `null` **remove todos** os setores dos alvos (voltam a herdar do grupo, ou ficam sem setor). Repetido na lista: `400`. De 0 a 20 setores por alvo.
- De 1 a **500** alvos por chamada, numa **transação**: se um alvo for inválido, **nada** é gravado (`400` com o índice do alvo).
- Setor inexistente: `404`; **setor inativo** que o alvo **ainda não tinha**: `409 { codigo: "SETOR_INATIVO" }` (o inativo que o alvo já tem pode ficar); grupo inexistente ou inativo: `404`.
- Troca o conjunto: insere os setores novos e apaga os que saíram, na mesma transação.
- Resposta `200`: `{ "atualizados": 2, "removidos": 0 }` (`atualizados` = alvos cujo conjunto mudou; `removidos` = alvos que ficaram sem setor).
- Permissão `pode_editar`. 🟡 O limite de 500 acompanha o `limit` máximo da lista; serve para classificar de uma vez a página inteira.

### 2.5 `GET /acompanhamento_clientes`: setor na lista, filtro e ordenação

- **Cada linha** (CNPJ) traz `setores`, `setor_origem` e, por compatibilidade, `id_setor`/`setor` do primeiro (seção 1). Na **visão por grupo** (`visao=grupo`), a linha do grupo traz o setor **do grupo**; os CNPJs dentro (`membros`) trazem os setores efetivos de cada um.
- **Filtros novos:**

| Parâmetro | Tipo | Regra |
|---|---|---|
| `id_setor` | uuid | só clientes que **têm** esse setor entre os efetivos. Inválido: `400 { detail: "id_setor deve ser um UUID." }` |
| `sem_setor` | booleano | `true` = só clientes sem nenhum setor efetivo. **Não** pode vir junto com `id_setor` (`400`) |

- **Ordenação:** `sort=setor` pelo **primeiro** setor da lista (nome sem acento; sem setor no fim, nas duas direções).
- **KPIs** (`kpis=true`): acrescentar `por_setor`: lista de `{ id_setor, setor, qtd_clientes, venda_liquida_mes, faturamento_liquido_mes }` (com `id_setor: null` para "Sem setor"), calculada sobre as **mesmas linhas filtradas** da lista, e portanto respeitando `so_cliente`, `periodo` e a unidade ([[API-013-Acompanhamento-de-Clientes-So-Cliente-e-Periodo-Total]]). **O cliente conta em cada um dos seus setores** (decisão do Nathan, 23/10): a soma de `qtd_clientes` e dos valores por setor **pode passar** do total de clientes e do total de vendas, e isso é esperado; a linha "Sem setor" só tem quem não tem nenhum. Cada setor, sozinho, bate com o filtro `id_setor` da lista.
- `GET /acompanhamento_clientes/movimento` e o detalhe do grupo (`/grupos_clientes/{id}`) acrescentam `setores` do alvo (no grupo, os do próprio grupo).
- Todos os filtros **combinam** com busca, status, unidade, `so_cliente`, `periodo` e escopo de vendedor.

## 3. Tela (Nathan)

| Bloco | O que muda |
|---|---|
| Lista | coluna **Setor** (um selo discreto **por setor**, "Sem setor" em tom neutro; os setores herdados do grupo aparecem com a marca "do grupo") e filtro **Setor** (a lista do catálogo + "Sem setor"), na URL (`setor=<id>` ou `setor=sem`) |
| KPIs | quadro "Por setor" (qtd de clientes e venda líquida por setor) que filtra a lista ao clicar, com o aviso de que cliente com mais de um setor conta em cada um |
| Página do cliente e do grupo | campo **Setores** com a lista de **caixas de seleção** (marca um ou mais), a opção **"Adicionar setor…"** (abre um campo de nome; cria e já marca) e "Remover todos"; só aparece editável com `pode_editar` |
| Classificar em lote | caixas de seleção na lista e a ação "Definir setores" para as linhas marcadas (usa `PUT /clientes_setor`; no lote, **substitui** o conjunto de cada linha); 🟡 Nathan decide se entra já ou numa 2ª etapa |
| Excel | coluna **Setor** (os nomes separados por "; ") e **Setor vem de** na aba Clientes e nas de inativos/sem compra; na aba Resumo, um quadro **por setor**; o Dicionário descreve as colunas |
| Erros | 409 de nome repetido seleciona o setor existente; setor inativo some da lista de escolha |

## Fora deste contrato

- **Setor do Omie ou do CRM:** o `segmento` de `core_comercial.clientes` e o `cnae` ficam como estão; nenhum é importado.
- **Hierarquia de setores** (setor e subsetor) e **setor principal** (não há; vários setores valem igual).
- **Apagar** setor de verdade: só desativa.
- **Classificação automática** (por CNAE ou nome): a primeira entrega é manual.
- **Meta ou comissão por setor.**

## Checklist

**Gustavo (banco e API)**
- [x] Migration: `setores_clientes` (com os 12 setores iniciais) e `clientes_setor`, com os `CHECK` e os índices únicos (entregue em 22/10, **um setor por alvo**).
- [x] **Migration nova (23/10): vários setores por alvo**: derrubar os índices únicos por alvo e criar os únicos por `(alvo, id_setor)`.
- [x] `fn_acompanhamento_clientes` (ou a rota) devolvendo `setores` (lista) e `setor_origem` pela regra de herança, mantendo `id_setor`/`setor` do primeiro.
- [ ] Rotas `GET`/`POST`/`PUT /setores_clientes` e `PUT /clientes_setor`, com a transação e os erros da seção 2 (**`id_setores`** em lista; `id_setor` ainda aceito).
- [ ] Filtros `id_setor` e `sem_setor`, `sort=setor` e `kpis.por_setor` em `GET /acompanhamento_clientes` (cliente conta em cada setor).
- [ ] Linhas de `auth.rotas_telas` (`acompanhamento-clientes`): `GET /setores_clientes` (`pode_visualizar`), `POST /setores_clientes` (`pode_criar`), `PUT /setores_clientes/*` e `PUT /clientes_setor` (`pode_editar`).
- [ ] Swagger das rotas novas.

**Nathan (front)**
- [ ] BFF: rotas `/api/setores-clientes` e `/api/clientes-setor` e os parâmetros novos da lista.
- [x] Coluna, filtro e quadro por setor; campo Setor na página do cliente e do grupo; "Adicionar setor…" (um setor, PR #235).
- [ ] **Vários setores (23/10):** selos múltiplos na lista, campo com caixas de seleção, `id_setores` ao salvar, Excel com os nomes juntos e o aviso no quadro "Por setor". Lê `setores` e cai para `id_setor`/`setor` enquanto a API não entrega.
- [ ] Excel com a coluna e o quadro por setor.
- [ ] Definir os perfis com `pode_editar`/`pode_criar` e se o lote entra na 1ª etapa.

**Robert (MES):** nada.

## Aceite

1. `GET /setores_clientes` devolve os 12 setores iniciais, ordenados sem acento; criar "Cimento" devolve `201`, e criar "cimento" devolve `409` com o `id` do existente.
2. Dar os setores "Mineração" e "Energia" a um **grupo** com 3 CNPJs: os 3 passam a vir com `setores = [Energia, Mineração]` e `setor_origem = "grupo"`. Dar "Siderurgia" a um deles: ele vem só com `[Siderurgia]`/`"cliente"` (os do grupo **não somam**) e os outros 2 continuam `[Energia, Mineração]`/`"grupo"`.
2b. Dar 2 setores a um CNPJ: ele vem com os 2 em `setores`; `GET ...?id_setor=<qualquer um dos 2>` o traz; em `kpis.por_setor` ele conta nos dois.
3. Desativar o grupo: os CNPJs que só herdavam os setores dele ficam sem setor; reativar volta.
4. `id_setores = []` em um CNPJ com setores próprios faz ele voltar a herdar os do grupo.
5. `PUT /clientes_setor` com um alvo inválido no meio de 10 não grava nenhum dos 10 e aponta o índice.
6. `GET /acompanhamento_clientes?id_setor=<uuid>` traz só esse setor; `sem_setor=true` traz o resto; os dois juntos respondem `400`.
7. Em `kpis.por_setor`, cada setor tem o mesmo `qtd_clientes` que a lista filtrada por `id_setor` daquele setor; "Sem setor" bate com `sem_setor=true`; os números mudam junto com `so_cliente` e `periodo=total`. A soma por setor pode passar de `total_clientes` (cliente com 2 setores conta 2 vezes).
8. Perfil só com `pode_visualizar` vê o setor e recebe `403` ao tentar `PUT /clientes_setor`.
9. Setor desativado continua aparecendo nos clientes que já o tinham e dá `409` ao ser escolhido de novo.

## Ver também
[[LOG-48-Acompanhamento-de-Clientes-Grupos-de-Empresa]] · [[API-013-Acompanhamento-de-Clientes-So-Cliente-e-Periodo-Total]] · [[Acompanhamento-Clientes]]
