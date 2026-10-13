---
tags: [contrato-sql, contrato-api, dba, av-hub, clientes, grupos-de-empresa, portal-do-gerente]
criado: 2026-10-13
atualizado: 2026-10-13
status: proposta
---

# Contrato 48 — Acompanhamento de Clientes e grupos de empresa

> Status: proposta | **código escrito, nada testado contra banco** (13/10/2026). Escrito pelo Nathan com apoio do Claude a partir de uma leitura do código (`api-acos-vital` e `00 - HUB`). Produção não foi conferida. As funções e tabelas abaixo **não existem no banco**: a tela só carrega dados depois que o DBA aplicar este contrato.
> Cópia de trabalho no repositório do hub: `docs/ENVIAR - contrato-acompanhamento-clientes.md`.

**Destinatários:** Gustavo (DBA, tabelas, funções, `auth.*`) e Nathan (front, BFF, API).

## 1. Por quê

Hoje não existe uma tela que mostre, por cliente do Omie, o que ele comprou e faturou no mês, os vendedores que o atenderam e se ele está parado. A única visão de inatividade é `vw_clientes_inativos`, que avalia cada `codigo_cliente` sozinho. Um cliente com 50 CNPJs aparece "inativo" em cada CNPJ que não comprou, mesmo com o grupo comprando.

**Pedido do Nathan:** vincular CNPJs em **grupos de empresa**. Se o CNPJ 50 não teve venda, mas outro CNPJ do grupo comprou dentro do prazo, ele **não** é marcado como inativo. Cada CNPJ continua mostrando a própria contagem de vendas.

**Decisões já tomadas (13/10):**
- Grupos ficam em `core_vendas_faturamento`; o DDL vai pelo DBA (a API não tem migrations).
- Vínculo manual, com sugestão pela raiz do CNPJ (8 primeiros dígitos).
- Prazo de inatividade configurável na tela (30/60/90/180 dias, padrão 90).
- Vendedor vê só os próprios clientes; gerência e admin veem tudo (`escopoVendedor`, perfil com escopo "todos").

## 2. Tabelas

```sql
CREATE TABLE core_vendas_faturamento.grupos_clientes (
  id          uuid PRIMARY KEY DEFAULT uuidv7(),
  nome        varchar(150) NOT NULL,
  observacao  text,
  ativo       boolean NOT NULL DEFAULT true,
  created_by  uuid,
  updated_by  uuid,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_grupos_clientes_nome
  ON core_vendas_faturamento.grupos_clientes (lower(nome)) WHERE ativo;

CREATE TABLE core_vendas_faturamento.grupos_clientes_membros (
  id              uuid PRIMARY KEY DEFAULT uuidv7(),
  id_grupo        uuid NOT NULL
                  REFERENCES core_vendas_faturamento.grupos_clientes(id) ON DELETE CASCADE,
  codigo_empresa  uuid NOT NULL REFERENCES core.unidades(id),
  codigo_cliente  varchar(60) NOT NULL,   -- mesmo tipo de pedidos_vendas.codigo_cliente
  created_by      uuid,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ux_grupos_clientes_membros UNIQUE (codigo_empresa, codigo_cliente)
);
CREATE INDEX ix_grupos_clientes_membros_grupo
  ON core_vendas_faturamento.grupos_clientes_membros (id_grupo);
```

- Um CNPJ (cliente de uma unidade) só pode estar em **um** grupo (`UNIQUE`).
- `DELETE` do grupo na API só **desativa** (`ativo = false`); os membros ficam guardados e as funções ignoram grupo inativo. A API remove o vínculo antigo ao pôr o CNPJ em outro grupo.
- 🟡 O `UNIQUE (codigo_empresa, codigo_cliente)` vale também para membros de grupo **inativo**. A API trata isso apagando o vínculo antigo antes de recriar; se o DBA preferir, o índice pode virar parcial por grupo ativo (exigiria coluna `ativo` no membro).

## 3. `fn_acompanhamento_clientes`

```
core_vendas_faturamento.fn_acompanhamento_clientes(
  p_mes int, p_ano int, p_codigo_empresa uuid, p_vendedores text[], p_dias_inativo int)
```

Uma linha por cliente `(codigo_empresa, codigo_cliente)`:

| Coluna | Significado |
|---|---|
| `codigo_empresa`, `codigo_cliente` | chave |
| `nome_fantasia`, `razao_social`, `cpf_cnpj`, `raiz_cnpj` | de `core.parceiros` (`codigo_parceiro_omie` = `codigo_cliente`, mesma unidade). `cpf_cnpj` vem **mascarado**: `raiz_cnpj` = 8 primeiros dígitos de `regexp_replace(cpf_cnpj,'\D','','g')` |
| `id_grupo`, `nome_grupo` | de `grupos_clientes_membros`, só grupo `ativo` |
| `qtd_pedidos_mes`, `valor_pedidos_mes` | `pedidos_vendas` por `data_inclusao` no mês, **sem** cancelado/denegado |
| `qtd_nfs_mes`, `valor_nfs_mes` | `notas_fiscais` por `data_emissao` no mês |
| `qtd_pedidos_total`, `ultima_compra`, `dias_sem_comprar` | todo o histórico (mesma regra de `vw_clientes_inativos`) |
| `vendedores` (jsonb) | `[{codigo, nome_exibicao, qtd_pedidos, ultima_venda}]` |
| `ultima_compra_grupo`, `dias_sem_comprar_grupo` | máximo/mínimo entre **todos** os membros do grupo |
| `qtd_cnpjs_grupo`, `qtd_cnpjs_com_venda_grupo` | membros do grupo / membros com pedido no mês |
| `inativo_individual` | `dias_sem_comprar >= p_dias_inativo` (ou nunca comprou) |
| `status` | `'ativo'`, `'inativo'` ou `'coberto_grupo'` |

**Regras:**
- `status = 'coberto_grupo'` quando o CNPJ está inativo sozinho, mas o grupo comprou dentro do prazo (`dias_sem_comprar_grupo < p_dias_inativo`). Sem grupo, `status` é `ativo`/`inativo` pelo CNPJ.
- Ler as **tabelas base** (`pedidos_vendas`, `notas_fiscais`, com `deleted_at IS NULL`), não `vw_vendas_base`/`vw_nf_classified`, que devolvem a perna viva e a congelada (soma dobrada).
- `p_vendedores` (`'EMPRESA:CODIGO'` ou só o código; `NULL` = todos): o cliente entra se algum pedido ou NF dele é de um vendedor da lista. Os números do **grupo** consideram todos os membros e todos os vendedores, para o status do grupo ser igual para qualquer usuário.
- `p_codigo_empresa` `NULL` = todas as unidades.
- 🟡 `codigo_cliente` só é único dentro de uma `codigo_empresa`; o mesmo cliente Omie pode existir em mais de uma unidade (ver [[AV-Hub-API-Estado-Atual]]). Grupos cruzam unidades porque o membro guarda a unidade.

## 4. `fn_movimento_cliente_mes`

```
core_vendas_faturamento.fn_movimento_cliente_mes(
  p_mes int, p_ano int, p_codigo_empresa uuid, p_codigo_cliente text, p_id_grupo uuid,
  p_vendedores text[])
```

Pedidos e NFs do mês de **um cliente** (`p_codigo_cliente`) **ou de todo o grupo** (`p_id_grupo`). Colunas: `tipo` (`'pedido'|'nf'`), `numero`, `data`, `codigo_empresa`, `codigo_cliente`, `cliente`, `codigo_vendedor`, `vendedor`, `valor`, `situacao`. `p_vendedores` restringe aos pedidos/NFs do escopo do vendedor (mesma regra da seção 3).

## 5. Acesso (DBA)

- `auth.telas`: slug `acompanhamento-clientes`, no grupo "Portal do Gerente" (o `groupMap` do front já tem a entrada).
- `auth.permissoes`: gerência/admin com `pode_visualizar`, `pode_criar`, `pode_editar`, `pode_deletar`; vendedor com `pode_visualizar`.
- `auth.rotas_telas`, tela `acompanhamento-clientes` (sem isso, quem acessa com token leva `403 ROTA_SEM_PERMISSAO_MAPEADA`):
  - `GET /acompanhamento_clientes` e `GET /acompanhamento_clientes/movimento`
  - `GET|POST /grupos_clientes`, `GET|PUT|DELETE /grupos_clientes/{id}`
  - `GET /grupos_clientes/sugestoes`
  - `POST /grupos_clientes/{id}/membros`, `DELETE /grupos_clientes/{id}/membros/{empresa}/{codigo}`
- **Escopo de vendedor (a fazer na API):** acrescentar `acompanhamento_clientes: { params: ["codigo_vendedor"], formato: "lista", empresa: true }` em `ROTAS` de `src/middlewares/escopoVendedor.js`. Desde o [[40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]] o escopo é fixo no código: com a rota no mapa, a API preenche os vendedores do usuário quando o parâmetro vem vazio, e o perfil com escopo "todos" (gerência) não é filtrado. 🔴 Conferir com o Gustavo se `grupos_clientes` precisa de regra própria (vendedor lê grupos? só a gerência edita?).

## 6. Estado do código (13/10)

> **(atualizado em 13/10/2026) A API foi escrita pelo dono dela.** Commit `63871f3` na `develop` da `api-acos-vital` (ainda fora da `main`): `GET /acompanhamento_clientes` e `/movimento` sobre as funções da seção 3 e 4, rotas de `grupos_clientes` (CRUD, `sugestoes`, `membros`), models, swagger, erros e a entrada no `escopoVendedor.js` (`acompanhamento_clientes` em formato `lista`; `grupos_clientes` em formato `rota`). Conferido só no código. 🔴 **O DDL da seção 2 e as funções das seções 3 e 4 continuam sem aplicação no banco confirmada.** 🟡 **O BFF do av-hub precisa de ajuste:** a rota da API só devolve o objeto `kpis` com `?kpis=true` (padrão `false`) e aceita `status` em lista separada por vírgula; o BFF `app/api/acompanhamento-clientes` não repassa `kpis`, então os cartões de resumo ficam sem número.

**`api-acos-vital`: nada publicado.** Escrevi as rotas e os models em uma branch local, mas o repositório da API não é do Nathan, e a branch foi apagada a pedido dele (era o commit `f182c9c`, recuperável do reflog por pouco tempo). O que precisa existir na API, para o dono dela:
- `GET /acompanhamento_clientes` (filtros `mes`, `ano`, `codigo_empresa`, `codigo_vendedor`, `dias_inativo`, `status`, `busca`, `id_grupo`, `visao=cnpj|grupo`, paginação, `kpis`) e `GET /acompanhamento_clientes/movimento`, sobre as funções da seção 3 e 4.
- Models e rotas de `grupos_clientes` e `grupos_clientes_membros` (seção 2): CRUD, membros (409 informando em qual grupo o CNPJ já está) e sugestões pela raiz do CNPJ.
- Registro no `index.js` do schema, entrada no `escopoVendedor.js` (seção 5) e os `.swagger.json`.

**`00 - HUB`:** tela `/acompanhamento-clientes` (`components/AcompanhamentoClientes/`), BFF (`app/api/acompanhamento-clientes`, `app/api/grupos-clientes`, `lib/api/acompanhamentoClientesApi.ts`), serviço, tipos e entradas em `groupMap.ts` e `iconMap.tsx`. `tsc` e `eslint` limpos nos arquivos novos; visual conferido no preview com dados simulados no navegador.

## 7. Como conferir depois de aplicado

1. Dois CNPJs no mesmo grupo, um com pedido recente e o outro parado há mais de 90 dias: o parado vem `coberto_grupo`.
2. Com `p_dias_inativo = 1` os dois ficam `inativo`.
3. `valor_nfs_mes` de um cliente bate com a soma de `notas_fiscais` e com a tela Notas da Equipe do mesmo mês.
4. Pôr o mesmo CNPJ em dois grupos ativos: a API devolve 409 com o nome do outro grupo.
5. Token de vendedor: só os clientes dele, `codigo_vendedor` de outro vendedor devolve 403. Token da gerência: tudo.

## 8. Perguntas em aberto

1. 🔴 **Gustavo:** aplicar as seções 2 a 5; a lógica de `status` e do grupo (seção 3) está de acordo?
2. 🔴 **Gustavo:** `grupos_clientes` precisa de escopo de vendedor ou fica só por permissão da tela?
3. 🟡 **Nathan:** `created_by` dos grupos ainda não vem do usuário logado (o BFF não repassa o id); ligar quando o `identidadeUsuario` expuser o id para as rotas de escrita.
4. 🟡 **Nathan:** filtro por vendedor na tela (hoje só se vê os vendedores em cada linha).

Ver também: [[Indice-Contratos]], [[40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]], [[AV-Hub-API-Estado-Atual]].
