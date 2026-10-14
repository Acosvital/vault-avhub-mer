---
tags: [contrato-sql, contrato-api, dba, av-hub, clientes, grupos-de-empresa, portal-do-gerente]
criado: 2026-10-13
atualizado: 2026-10-14
status: banco-api-ok-pendencias-9-10
---

# Contrato 48 — Acompanhamento de Clientes e grupos de empresa

> Status (14/10/2026): **tabelas, funções, rotas e permissões existem e respondem no `api-test`** (§6). Tela v2 no front (páginas por cliente e por grupo). **Pendências de banco:** NF cancelada nos totais e filtro `codigo_cliente` (§9); venda e faturamento por cliente com deduções separadas, na lógica da Equipe (§10); perfil Gerência `vinculados` × `todos` (§6). Produção não conferida. Revisão de coerência na §11.
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
| `qtd_pedidos_mes`, `valor_pedidos_mes` | `pedidos_vendas` por `data_inclusao` no mês, **sem** cancelado/denegado. Regra própria: **na tela, substituídos pelos campos de venda da §10** (ficam por compatibilidade) |
| `qtd_nfs_mes`, `valor_nfs_mes` | `notas_fiscais` por `data_emissao` no mês. **Hoje soma cancelada (§9.1).** Na tela, substituídos pelos campos de faturamento da §10 |
| `qtd_pedidos_total`, `ultima_compra`, `dias_sem_comprar` | todo o histórico (mesma regra de `vw_clientes_inativos`) |
| `vendedores` (jsonb) | `[{codigo, nome_exibicao, qtd_pedidos, ultima_venda}]` |
| `ultima_compra_grupo`, `dias_sem_comprar_grupo` | máximo/mínimo entre **todos** os membros do grupo |
| `qtd_cnpjs_grupo`, `qtd_cnpjs_com_venda_grupo` | membros do grupo / membros com pedido no mês |
| `inativo_individual` | `dias_sem_comprar >= p_dias_inativo` (ou nunca comprou) |
| `status` | `'ativo'`, `'inativo'` ou `'coberto_grupo'` |

**Regras:**
- 🟡 **Inatividade:** "compra" em `ultima_compra`/`dias_sem_comprar` segue `vw_clientes_inativos`. Falta definir se um pedido que depois foi cancelado (G1) ou refaturado (G6) conta como compra (§8, item 7).
- **Escopo:** os números do grupo que usam todos os vendedores são **só os de status**. Valores de venda e faturamento seguem o escopo do usuário (§10.2).
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

> **(atualizado em 13/10/2026) O DBA diz que fez o contrato todo (relato do Nathan).** O código da API está na `develop` (`63871f3`); **o DDL e as funções no banco não foram vistos** (não ficam no repositório). Falta do lado do av-hub: o BFF passar `kpis=true` (abaixo) e conferir os formatos de resposta; só depois o contrato vai para `Realizados/`.
>
> **(atualizado em 13/10/2026) CONFERIDO NO DUMP DO BANCO DE TESTE** (`Dump avhub teste (Completo).sql`; só li DDL, `auth.rotas_telas`, `auth.telas`, `auth.perfis` e `auth.permissoes`; **não li dados de clientes ou usuários**). **Banco e API completos para o 48:** tabelas `grupos_clientes` e `grupos_clientes_membros` ✅; tela `acompanhamento-clientes` em `auth.telas` ✅; **todas as rotas mapeadas em `auth.rotas_telas`** (`GET /acompanhamento_clientes` e, por prefixo, `/movimento`; `GET`, `POST`, `PUT`, `DELETE /grupos_clientes` e `/membros`; `GET /grupos_clientes/sugestoes` só para quem edita) ✅; permissões: **Gerência** e **Admin (Dev)** com tudo, **Vendedor** só visualizar ✅. 🔴 **ACHADO: "Gerência vê tudo" NÃO vale hoje.** As rotas de clientes têm `escopo_vendedor = true` e o escopo do usuário é o **mais amplo entre os perfis** (`fn_escopo_vendedores_usuario`). O perfil **Gerência** está como **`vinculados`**; só **"Gerencia PCP"** é `todos`. Resultado: um usuário só com o perfil Gerência vê **apenas os clientes dos vendedores vinculados a ele**, e leva **403 `SEM_VENDEDOR_VINCULADO`** se não tiver nenhum. Para a regra do Nathan (gerência vê tudo, vendedor só os dele) é preciso **mudar `auth.perfis.escopo_vendedores` do perfil Gerência para `todos`** (ou usar outro perfil de gerência com `todos`). **Decisão do Nathan e do DBA:** isso também amplia o que a Gerência vê nas outras telas com escopo de vendedor.
>
> **(atualizado em 13/10/2026) CONFERIDO NA `api-test` (só GET, chave de serviço, sem token).** `GET /acompanhamento_clientes` responde 200 nas duas visões, com `kpis` e `vendedores[]` (as funções e o DDL **existem e funcionam nesse ambiente**: 1265 clientes no mês de outubro, 0 grupos cadastrados, 141 sugestões de raiz de CNPJ em `GET /grupos_clientes/sugestoes`); `GET /grupos_clientes` responde 200 com lista vazia; `GET /acompanhamento_clientes/movimento` valida os parâmetros (400). As chaves da linha batem com os tipos do front (`nome_fantasia`, `razao_social`, `cpf_cnpj`, `qtd_cnpjs_grupo`, `status`, `vendedores[].nome_exibicao`) e com o PR #194. **Não conferi:** produção (só a `api-test`), escrita (`POST` de grupo e de membros, que o diálogo precisa), escopo de vendedor (precisa de token) e o cadastro da tela em `auth.telas`.
>
> **(atualizado em 13/10/2026) AJUSTE DO FRONT, 1ª PARTE:** PR [av-hub#194](https://github.com/Acosvital/av-hub/pull/194) (BFF passa `kpis=true`; chaves dos cartões alinhadas à API). **2ª PARTE, aberta:** o diálogo de grupos do av-hub (`GrupoClientesDialog`, `services/acompanhamentoClientes.ts`, rotas `app/api/grupos-clientes`) foi escrito para o formato do contrato original e **não bate com a API de grupos que o dono escreveu**: `POST /grupos_clientes/{id}/membros` recebe `{ membros, mover, created_by }` (o BFF manda um array) e responde `incluidos/movidos/ja_no_grupo/vinculos/grupo`; o 409 é `CLIENTE_EM_OUTRO_GRUPO` com `conflitos` e a opção `mover`; as sugestões vêm paginadas e agrupadas por raiz (`raiz_cnpj`, `nome_sugerido`, `clientes[]`); a lista usa `qtd_cnpjs` e `unidades`; o membro tem `nome_fantasia`. O contrato 48 só vai para `Realizados/` depois dessa 2ª parte.
>
> **(atualizado em 13/10/2026) A API foi escrita pelo dono dela.** Commit `63871f3` na `develop` da `api-acos-vital` (ainda fora da `main`): `GET /acompanhamento_clientes` e `/movimento` sobre as funções da seção 3 e 4, rotas de `grupos_clientes` (CRUD, `sugestoes`, `membros`), models, swagger, erros e a entrada no `escopoVendedor.js` (`acompanhamento_clientes` em formato `lista`; `grupos_clientes` em formato `rota`). Conferido só no código. 🔴 **O DDL da seção 2 e as funções das seções 3 e 4 continuam sem aplicação no banco confirmada.** 🟡 **O BFF do av-hub precisa de ajuste:** a rota da API só devolve o objeto `kpis` com `?kpis=true` (padrão `false`) e aceita `status` em lista separada por vírgula; o BFF `app/api/acompanhamento-clientes` não repassa `kpis`, então os cartões de resumo ficam sem número.

**`api-acos-vital`: nada publicado.** Escrevi as rotas e os models em uma branch local, mas o repositório da API não é do Nathan, e a branch foi apagada a pedido dele (era o commit `f182c9c`, recuperável do reflog por pouco tempo). O que precisa existir na API, para o dono dela:
- `GET /acompanhamento_clientes` (filtros `mes`, `ano`, `codigo_empresa`, `codigo_vendedor`, `dias_inativo`, `status`, `busca`, `id_grupo`, `visao=cnpj|grupo`, paginação, `kpis`) e `GET /acompanhamento_clientes/movimento`, sobre as funções da seção 3 e 4.
- Models e rotas de `grupos_clientes` e `grupos_clientes_membros` (seção 2): CRUD, membros (409 informando em qual grupo o CNPJ já está) e sugestões pela raiz do CNPJ.
- Registro no `index.js` do schema, entrada no `escopoVendedor.js` (seção 5) e os `.swagger.json`.

**`00 - HUB`:** tela `/acompanhamento-clientes` (`components/AcompanhamentoClientes/`), BFF (`app/api/acompanhamento-clientes`, `app/api/grupos-clientes`, `lib/api/acompanhamentoClientesApi.ts`), serviço, tipos e entradas em `groupMap.ts` e `iconMap.tsx`. `tsc` e `eslint` limpos nos arquivos novos; visual conferido no preview com dados simulados no navegador.

## 7. Como conferir depois de aplicado

1. Dois CNPJs no mesmo grupo, um com pedido recente e o outro parado há mais de 90 dias: o parado vem `coberto_grupo`.
2. Com `p_dias_inativo = 1` os dois ficam `inativo`.
3. `faturamento_liquido_mes` de um cliente bate com Notas da Equipe filtrada pelo mesmo cliente e mês (§10). (`valor_nfs_mes` não bate: soma cancelada, §9.1.)
4. Pôr o mesmo CNPJ em dois grupos ativos: a API devolve 409 com o nome do outro grupo.
5. Token de vendedor: só os clientes dele, `codigo_vendedor` de outro vendedor devolve 403. Token da gerência: tudo.

## 8. Perguntas em aberto

1. 🔴 **Gustavo:** aplicar as seções 2 a 5; a lógica de `status` e do grupo (seção 3) está de acordo?
2. 🔴 **Gustavo:** `grupos_clientes` precisa de escopo de vendedor ou fica só por permissão da tela?
3. 🟡 **Nathan:** `created_by` dos grupos ainda não vem do usuário logado (o BFF não repassa o id); ligar quando o `identidadeUsuario` expuser o id para as rotas de escrita.
4. 🟡 **Nathan:** filtro por vendedor na tela (hoje só se vê os vendedores em cada linha).
5. 🔴 **Gustavo:** NF cancelada fora dos totais e filtro `codigo_cliente` na lista (§9).
6. 🔴 **Gustavo:** venda e faturamento do mês por cliente e por grupo, com deduções separadas e `composicao_mes`, na mesma lógica de Pedidos/Notas da Equipe, no escopo do usuário (§10.2). Filtro de cliente nos resumos é opcional (§10.3).
7. 🟡 **Nathan e Gustavo:** para a inatividade, um pedido depois cancelado (G1) ou refaturado (G6) conta como "compra"? Proposta: só pedido que ficou no líquido conta.
8. 🟡 **Gustavo:** quais clientes o resumo exclui (YPFB, blacklist de pedidos e de vendedores) e com qual texto em `motivo_fora_dos_numeros`.

## 9. Pendências vistas na v2 da tela (14/10/2026, conferido no `api-test`)

A v2 do front trocou o modal de movimento por **páginas com URL própria**: `/acompanhamento-clientes/cliente/{empresa}/{codigo}` e `/acompanhamento-clientes/grupo/{id}`. Duas coisas faltam no backend.

### 9.1 🔴 NF cancelada entra no total do mês

`fn_acompanhamento_clientes` (`qtd_nfs_mes`, `valor_nfs_mes`) e `fn_movimento_cliente_mes` (`totais.qtd_nfs`, `totais.valor_nfs`) **somam notas canceladas**. Os pedidos já excluem cancelado/denegado; as notas não.

Exemplo: ONESUBSEA DO BRASIL (`codigo_cliente` 11797642613, unidade Hrm Caldeiraria, `codigo_empresa` `c84155b6-75cc-4bca-8435-281e846f4039`), 09/2026. A API devolve **7 notas / R$ 1.311.017,05**. Duas são canceladas (00000044 e 00000027, R$ 449.490,53 cada). Sem elas: **5 notas / R$ 412.035,99**. O KPI "Notas em 09/2026", a coluna "NFs do mês" da lista e o total da página mostram o número inflado.

**Pedido:** nos totais e contagens, a mesma regra de exclusão dos pedidos (cancelada, denegada, inutilizada). No `movimento`, a nota cancelada **continua na lista** (com `situacao`) e só sai de `totais`.

**Na tela, enquanto isso:** aviso "N notas canceladas estão somadas no total", sem recalcular nada no navegador (marca `GAMBIARRA` em `components/AcompanhamentoClientes/AcompanhamentoDetalhe.tsx`).

### 9.2 🟡 `GET /acompanhamento_clientes` não filtra por `codigo_cliente`

A página de um CNPJ precisa de uma linha só. Hoje `codigo_cliente` é ignorado: com o `codigo_empresa` da Hrm vêm os 36 clientes da unidade. O front usa `busca={codigo_cliente}` + `codigo_empresa` e confere a igualdade exata (marca `GAMBIARRA`).

**Pedido:** aceitar `codigo_cliente` (igualdade exata, junto com `codigo_empresa`) no `GET /acompanhamento_clientes`, como o `/movimento` já faz.

### 9.3 Como conferir

1. `GET /acompanhamento_clientes/movimento?mes=9&ano=2026&codigo_empresa=c84155b6-75cc-4bca-8435-281e846f4039&codigo_cliente=11797642613`: `totais.qtd_nfs = 5` e `totais.valor_nfs = 412035.99`; a lista `data` continua com as 7 notas.
2. O mesmo cliente em `GET /acompanhamento_clientes?mes=9&ano=2026&codigo_empresa=…&busca=11797642613` traz `qtd_nfs_mes = 5`.
3. `GET /acompanhamento_clientes?mes=10&ano=2026&codigo_empresa=c84155b6-…&codigo_cliente=11797642613` devolve `total = 1`.

## 10. 🔴 Venda e faturamento do mês por cliente, com as deduções separadas (pedido do Nathan, 14/10/2026)

**O que a tela precisa:** para cada cliente (CNPJ) e cada grupo, a **venda do mês** e o **faturamento do mês** com **a mesma lógica** das telas Pedidos da Equipe e Notas da Equipe (`/vendas_planilha_resumo` e `/faturamento_planilha_resumo`): Bruto → deduções G1…G6 → Líquido, com as deduções **separadas**. Na tela, estes campos **substituem** `qtd/valor_pedidos_mes` e `qtd/valor_nfs_mes` da §3 (ver §11).

### 10.1 Por que não dá hoje (conferido no `api-test`, 14/10)

- `fn_acompanhamento_clientes` conta pedidos e NFs com regra própria (`qtd_pedidos_mes`, `valor_pedidos_mes`, `qtd_nfs_mes`, `valor_nfs_mes`), diferente da planilha. Ela não separa deduções e soma NF cancelada (§9.1). Exemplo: ONESUBSEA DO BRASIL, 09/2026. A função dá 6 pedidos / R$ 1.248.480,01. Na `/vendas_planilha`, o mesmo cliente tem 33 linhas (cabeçalhos e parcelas), e o pedido 43 está em G1 (cancelado, R$ 449.490,53).
- `/vendas_planilha_resumo` e `/faturamento_planilha_resumo` **ignoram** `codigo_cliente` e `cnpj_cpf_destinatario`: com qualquer um dos dois, devolvem o total da unidade (09/2026, Hrm: 50 pedidos, bruto R$ 3.527.674,75).
- `/vendas_planilha` filtra por `codigo_cliente` e por `cnpj_cpf_destinatario`. `/faturamento_planilha` só filtra por `cnpj_cpf_destinatario` (com `codigo_cliente` vêm as 46 notas de 22 clientes da unidade; com o CNPJ, as 7 do cliente). Somar essas linhas no navegador repetiria a regra de "o que é um pedido" (cabeçalho + parcelas, sem orçamento) e as deduções, que são do banco.

### 10.2 Na lista (`GET /acompanhamento_clientes`): por linha (CNPJ e grupo)

**Regra:** a mesma de `/vendas_planilha_resumo` e `/faturamento_planilha_resumo` com `data_inicio`/`data_fim` = primeiro e último dia do mês pedido, **inclusive a data que cada resumo usa** e as exclusões dele. A ideia é a função chamar a mesma lógica dos resumos filtrada por cliente, não reescrever a regra.

| Campo | Significado |
|---|---|
| `venda_bruta_mes` | linha `bruto` da composição de vendas do cliente |
| `venda_deducoes_mes` | linha `total_deducoes` (valor positivo) |
| `venda_liquida_mes` | linha `liquido` |
| `qtd_pedidos_venda_mes` | `qtd_pedidos` da linha `bruto` (pedidos, não linhas de parcela) |
| `faturamento_bruto_mes`, `faturamento_deducoes_mes`, `faturamento_liquido_mes` | o mesmo, da composição de faturamento |
| `qtd_nfs_faturamento_mes` | `qtd_nfs` da linha `bruto` do faturamento |
| `composicao_mes` (jsonb) | `{ "venda": [...], "faturamento": [...] }`, cada um com **as 10 linhas** do resumo, nas mesmas chaves dele (`ordem`, `secao`, `tipo`, `rotulo`, `grupo`, `valor`, `qtd_pedidos` ou `qtd_nfs`, `pct_total`). A página do cliente desenha o quadro Bruto → Deduções → Líquido direto disso, sem cálculo no navegador |
| `fora_dos_numeros` (bool), `motivo_fora_dos_numeros` (text) | cliente que o resumo exclui (ex.: YPFB, blacklist): **continua na lista, marcado** e fica fora dos `kpis` (guia de interface §7: o que fica fora do total é marcado, não escondido) |

**Escopo de vendedor:** os campos acima seguem `p_vendedores`. Um vendedor só soma os **próprios** pedidos e notas daquele cliente, como nas telas da Equipe. **Só o status** do grupo (`ultima_compra_grupo`, `dias_sem_comprar_grupo`, `status`) usa todos os vendedores (regra da §3). Valor de venda de outro vendedor nunca aparece.

**Linha de grupo** (`visao=grupo`): soma dos CNPJs do grupo no escopo do usuário, sem dobrar cabeçalho e parcelas do mesmo pedido, e `composicao_mes` do grupo inteiro.

**`kpis`:** `venda_bruta_mes`, `venda_deducoes_mes`, `venda_liquida_mes`, `faturamento_bruto_mes`, `faturamento_deducoes_mes`, `faturamento_liquido_mes`, `com_venda_mes` (clientes com `venda_liquida_mes > 0`) e `com_faturamento_mes`, sem os `fora_dos_numeros`. Têm que **bater** com Pedidos da Equipe e Notas da Equipe no mesmo mês e escopo.

**Ordenação:** aceitar `sort=venda_liquida_mes` e `sort=faturamento_liquido_mes`.

### 10.3 Na página do cliente ou do grupo

A página usa `composicao_mes` da própria linha (§10.2). **Não precisa** de filtro novo nos resumos. 🟡 Opcional: `/vendas_planilha_resumo` e `/faturamento_planilha_resumo` aceitarem `codigo_cliente` (com `codigo_empresa`) e `id_grupo`. Seria útil em outras telas, mas não bloqueia esta.

### 10.4 O que muda na tela (o front já está pronto e liga sozinho quando os campos vierem)

- **Lista:** colunas **Venda do mês** (líquido; embaixo, a quantidade de pedidos e "−R$ Y deduções") e **Faturamento do mês** (idem), no lugar de "Pedidos do mês" e "NFs do mês". Deduções com texto, nunca só pela cor. Cliente `fora_dos_numeros` com etiqueta.
- **KPIs da lista:** Venda líquida e Faturamento líquido do mês (com as deduções no apoio).
- **Página:** KPIs Venda líquida e Faturamento líquido, e dois quadros Bruto → Deduções → Líquido (o mesmo `ComposicaoVendas` das telas da Equipe).
- Enquanto os campos não existirem, a tela continua com os números da §3 e o aviso da §9.1.

### 10.5 Como conferir

1. Gerência, 10/2026, sem filtro: `kpis.venda_liquida_mes` é igual a "Vendas líquidas" de Pedidos da Equipe, e `kpis.faturamento_liquido_mes` é igual a "Faturamento líquido" de Notas da Equipe.
2. ONESUBSEA DO BRASIL (11797642613, Hrm), 09/2026: o pedido 43 (cancelado) aparece no G1 de `composicao_mes.venda` e não entra em `venda_liquida_mes`.
3. Token de vendedor: num cliente atendido por dois vendedores, `venda_liquida_mes` só soma os pedidos dele; o `status` do grupo é o mesmo que a gerência vê.
4. Um cliente YPFB aparece com `fora_dos_numeros = true` e não entra nos `kpis`.

## 11. Revisão de coerência do contrato (14/10/2026)

Lido o contrato inteiro contra o objetivo da §1 (por cliente: o que comprou e faturou no mês, vendedores, se está parado; grupos de empresa). O que foi corrigido:

1. **Cabeçalho:** dizia "nada testado, funções não existem no banco"; a §6 mostra que existem e respondem no `api-test`. Atualizado.
2. **Duas regras de venda:** a §3 define pedidos/NFs do mês por regra própria e a §10 pede a lógica da Equipe. Decidido: na tela vale a §10. Os campos da §3 ficam por compatibilidade e saem da tela quando a §10 chegar.
3. **§7, item 3:** mandava conferir `valor_nfs_mes` com Notas da Equipe, o que não bate (§9.1, §10.1). Trocado por `faturamento_liquido_mes`.
4. **Escopo:** a §3 manda o grupo usar todos os vendedores (para o status). Sem ressalva, isso valeria para os valores de venda e mostraria venda de outro vendedor. A §10.2 agora separa: valores no escopo do usuário, status com todos.
5. **Exclusões:** o resumo da Equipe é "sem YPFB" e sem blacklist. Sem tratar isso, a conciliação da §10.5 não fecharia. Criado `fora_dos_numeros`.
6. **Data:** a versão anterior da §10 afirmava a data de cada resumo sem conferir. Agora diz "a mesma data que o resumo usa".
7. **§10.3 simplificada:** a composição vem na própria linha (`composicao_mes`), então o filtro novo nos resumos ficou opcional.
8. **Pergunta nova:** o que conta como "compra" para a inatividade (§8, item 7).

Ver também: [[Indice-Contratos]], [[40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]], [[AV-Hub-API-Estado-Atual]].
