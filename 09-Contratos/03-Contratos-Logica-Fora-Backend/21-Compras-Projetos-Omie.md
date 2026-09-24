# Contrato — Projetos do Omie no av-hub (banco e pipeline)

**Criado em:** 23/09/2026.

**Objetivo:** o campo **Projeto** da Ordem de Compra deixar de ser texto livre e virar uma lista
com os projetos do Omie da unidade. É o `nCodProj` do pedido de compra: no pedido 46618 ele é
`9779703251` e o PDF do Omie mostra "16 - Revenda". Hoje o comprador teria que saber esse código
de cor.

**Fontes:** documentação oficial do Omie (`https://app.omie.com.br/api/v1/geral/projetos/`, lida
em 23/09/2026) e um retorno real de `ListarProjetos` (página 1 de 2: 50 dos 59 projetos, 23/09/2026).

---

## 1. A API do Omie

`POST https://app.omie.com.br/api/v1/geral/projetos/` · `"call": "ListarProjetos"`.
Também existem `ConsultarProjeto`, `IncluirProjeto`, `AlterarProjeto`, `UpsertProjeto` e
`ExcluirProjeto`. Aqui só se usa o `ListarProjetos` (leitura).

**Requisição** (todos opcionais, exceto a paginação):

| Parâmetro | Uso aqui |
|---|---|
| `pagina`, `registros_por_pagina` | paginação. O retorno real veio com 50 por página (59 projetos em 2 páginas) |
| `apenas_importado_api` | `"N"` (queremos todos, não só os criados por API) |
| `ordenar_por`, `ordem_descrescente` | opcionais |
| `filtrar_por_data_de`, `filtrar_por_data_ate` | `dd/mm/aaaa`. Com `filtrar_apenas_alteracao = "S"`, permite sync incremental (a testar) |
| `filtrar_apenas_inclusao`, `filtrar_apenas_alteracao` | `"S"`/`"N"` |
| `nome_projeto` | busca por nome; não usar no sync |

**Resposta:** `pagina`, `total_de_paginas`, `registros`, `total_de_registros` e `cadastro[]`:

| Campo | Tipo | Exemplo real | Observação |
|---|---|---|---|
| `codigo` | integer | `9779703251` | **passa de INTEGER** (o maior no retorno é `10349730520`, 11 dígitos). Coluna `bigint` |
| `codInt` | string20 | `""` | vazio em todos os 50 da página 1 |
| `nome` | string70 | `"16 - Revenda"` | quase sempre "NN - Nome", mas não sempre: há `"Logística"`, `"37"` e `"INATIVO"`. **Não quebrar o número do nome**: guardar como vem |
| `inativo` | string1 | `"N"` / `"S"` | 6 dos 50 da página 1 estão `"S"` |
| `info.data_inc` / `hora_inc` | `dd/mm/aaaa` / `hh:mm:ss` | `14/02/2024` `21:00:42` | inclusão no Omie |
| `info.data_alt` / `hora_alt` | idem | `27/05/2025` `14:24:15` | última alteração no Omie |
| `info.user_inc` / `user_alt` | string10 | `P000714770` | código do usuário no Omie |

Cada unidade tem a sua conta no Omie, então **cada unidade tem os seus projetos**, com códigos
próprios (mesmo raciocínio de parceiros, compradores e condições de pagamento).

## 2. Banco (DBA)

```sql
CREATE TABLE core.projetos (
  id                  uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa      uuid NOT NULL REFERENCES core.unidades(id)
                        ON UPDATE CASCADE ON DELETE RESTRICT,
  codigo_projeto_omie bigint       NOT NULL,   -- codigo (= nCodProj do pedido de compra)
  codigo_integracao   varchar(20),             -- codInt (vazio hoje)
  nome                varchar(70)  NOT NULL,   -- nome, como vem ("16 - Revenda")
  ativo               boolean      NOT NULL DEFAULT true,  -- NOT inativo ("S" -> false)
  incluido_em_omie    timestamptz,             -- info.data_inc + hora_inc (fuso de São Paulo)
  alterado_em_omie    timestamptz,             -- info.data_alt + hora_alt
  usuario_inclusao_omie  varchar(10),          -- info.user_inc
  usuario_alteracao_omie varchar(10),          -- info.user_alt
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  deleted_at          timestamptz
);

CREATE UNIQUE INDEX uq_projetos_empresa_codigo
  ON core.projetos (codigo_empresa, codigo_projeto_omie);

CREATE INDEX idx_projetos_empresa_ativo
  ON core.projetos (codigo_empresa, ativo) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_projetos_updated_at
  BEFORE UPDATE ON core.projetos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

- **`core`, não `core_vendas_faturamento`**: projeto não é só de compras (o pedido de venda do
  Omie também tem `nCodProj`). Mesmo motivo de `core.cotacoes_moeda`.
- **Sem FK na OC por enquanto.** `ordens_compra.codigo_projeto` continua guardando o código do
  Omie (texto), agora escolhido da lista. Se quiserem FK, o caminho é uma coluna
  `id_projeto uuid REFERENCES core.projetos(id)`, mas não é necessário para o envio ao Omie.
- **`pedidos_compras.codigo_projeto`** (espelho do Omie) precisa ser `bigint` para receber o
  `nCodProj`: já está no D5 do pedido ao DBA.

## 3. Pipeline (`omie-elt-pipeline`)

`src/omie/resources/projetos.ts`, no molde dos catálogos (`compradores`,
`condicoesPagamentoCompras`), registrado em `index.ts`:

- `endpointPath: '/geral/projetos/'`, `listMethod: 'ListarProjetos'`,
  `listResponseKey: 'cadastro'`, `idField: 'codigo'`.
- Parâmetros: `pagina`, `registros_por_pagina: 50`, `apenas_importado_api: "N"`.
- **Catálogo:** entra no `full_sync` diário e na carga inicial, nas duas contas (Mogi e Uberaba).
  São dezenas de registros por conta: varrer tudo todo dia é barato.
- **Upsert** em `(codigo_empresa, codigo_projeto_omie)`:

  | Coluna | Omie |
  |---|---|
  | `codigo_projeto_omie` | `codigo` |
  | `codigo_integracao` | `codInt` (vazio → `NULL`) |
  | `nome` | `nome`, **decodificando entidades HTML** (`&quot;`, `&amp;`…: o Omie as manda em texto, ver P4 dos parceiros) |
  | `ativo` | `inativo = "N"` |
  | `incluido_em_omie` | `info.data_inc` + `info.hora_inc`, em `America/Sao_Paulo` |
  | `alterado_em_omie` | `info.data_alt` + `info.hora_alt` |
  | `usuario_inclusao_omie` / `usuario_alteracao_omie` | `info.user_inc` / `info.user_alt` |

- **Projeto que sumiu do Omie** (excluído com `ExcluirProjeto`): no `full_sync`, o que estava no
  banco e não veio marca `deleted_at = now()`. **Não apagar a linha**: OCs e pedidos antigos
  apontam para o código.
- **A testar:** `filtrar_por_data_de` + `filtrar_apenas_alteracao = "S"` para um sync incremental.
  Com tão poucos registros, não é necessário.

## 4. API (`api-acos-vital`) — para a OC usar

```
GET /projetos?codigo_empresa=<uuid>&ativo=true&q=<texto>&page=&limit=
→ 200 { total, page, limit, total_pages,
        data: [ { id, codigo_empresa, codigo_projeto_omie, nome, ativo } ] }
```

- `codigo_empresa` **obrigatório** na prática: a OC só pode usar projeto da própria unidade.
- `ativo=true` por padrão na tela; o filtro existe para quem quiser ver os inativos.
- `q` busca em `nome` (sem acento, sem caixa).
- Ordem padrão por `nome` (o prefixo "NN - " já ordena como o Omie mostra).
- `codigo_projeto_omie` sai como **texto** no JSON (bigint não cabe com segurança em número de
  JavaScript acima de 2^53; aqui não chega lá, mas o padrão da API para códigos do Omie é texto).

## 5. O que muda no av-hub

- BFF `GET /api/compras/projetos?codigo_empresa=` repassando a rota acima.
- Formulário da OC (v2): **Projeto** vira lista dos projetos ativos da unidade, "16 - Revenda",
  guardando o `codigo_projeto_omie` em `ordens_compra.codigo_projeto`. A lista recarrega quando a
  unidade muda (como fornecedor e transportadora).
- PDF da OC e tela de detalhe mostram o **nome** do projeto, não o código. Para isso o detalhe da
  OC (`GET /compras/ordens/{id}`) devolve também `nome_projeto` (JOIN com `core.projetos` pela
  unidade da OC), junto dos outros nomes do C1.
- Envio ao Omie: `nCodProj ← ordens_compra.codigo_projeto` (já estava no de-para, agora com valor
  garantido).

## 6. Aceite

- Depois do `full_sync`, `core.projetos` tem os 59 projetos da conta (o mesmo `total_de_registros`
  do Omie), com o maior código (`10349730520`) gravado sem estouro.
- `GET /projetos?codigo_empresa=<unidade>&ativo=true` devolve só os ativos, em ordem de nome,
  e o total bate com os `inativo = "N"` do Omie.
- Um projeto excluído no Omie aparece com `deleted_at` preenchido e some da lista, mas a OC antiga
  que o usa continua mostrando o nome.
