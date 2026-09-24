# Contrato — Compras: tudo o que falta no BACKEND (banco + API)

**Criado em:** 23/09/2026 · **Para:** DBA e backend (`api-acos-vital`)

**Este documento substitui, como lista de trabalho,** `ENVIAR - compras/01 - DBA - banco.md` e
`ENVIAR - compras/02 - API - backend.md`. Os contratos de detalhe continuam valendo como
referência (de-para campo a campo):
`ENVIAR - contrato-compras-omie-pedidocompra.md`, `ENVIAR - contrato-compras-pendencias-pos-backend.md`,
`ENVIAR - contrato-compradores-funcionario.md`, `ENVIAR - contrato-compras-cotacao-moeda-ptax.md` e
`ENVIAR - contrato-compras-projetos-omie.md`.

O que é da pipeline (extrair do Omie, enviar a OC, job da PTAX) está em
`ENVIAR - contrato-compras-pipeline.md`.

---

## 0. O que já foi entregue (conferido em 23/09/2026, `develop` até o commit `8715549`)

| Item | Onde |
|---|---|
| Tabelas `requisicoes_compra`, `ordens_compra` (+ itens, parcelas), `parametros_compras`, régua de aprovação e valores por trigger | PR #273 |
| Renomes: `numero_pedido`, `id_requisicao`, `id_ordem_compra`; `codigo_comprador` obrigatório; `tipo_frete` com padrão CIF | `7918357` |
| Requisição: `id_origem` (idempotência do MES), `prazo_necessidade` obrigatório | `bf9d86a` |
| Número da OC e da requisição por trigger (contador por unidade), sem o `count + 1` | `8715549` |
| Fornecedor e transportadora só da unidade da OC (400) | `8715549` |
| Tabela `compradores` + `GET/PUT /compras/compradores`, `GET /{id}/sugestoes`; comprador resolvido pela sessão (bloqueio atrás de `COMPRAS_EXIGIR_VINCULO_COMPRADOR`) | `8715549` |
| `core.cotacoes_moeda` + `GET /cotacoes_moeda/atual` e `?data=`; OC guarda `cotacao_data`/`cotacao_origem` e confere a PTAX | `8715549` |
| Aprovar exige `aprovado_por` de usuário existente | `8715549` |

---

### 0.1 Situação real dos bancos (dumps de 23/09/2026: produção 16:46, teste 16:58)

| Item | Teste | Produção |
|---|---|---|
| `ordens_compra` (+ itens, parcelas), `requisicoes_compra`, `parametros_compras`, triggers | ✅ | ❌ **nenhuma tabela de compras** |
| `compradores`, `core.cotacoes_moeda` | ✅ | ❌ |
| **B1** espelho `pedidos_compras`: `bigint`, colunas novas, `pedidos_compras_parcelas` | ✅ **quase**: faltam `pedidos_compras_itens.codigo_item_integracao` e `.observacao` | ❌ ainda `INTEGER` |
| **B3** número da OC/requisição | ✅ trigger + `contadores_documento`: **`OC-000001` / `REQ-000001` por unidade** (6 dígitos) — o formato está definido. Falta só a API parar de aceitar `numero_pedido` no corpo | ❌ |
| **B6** colunas do PDF (`ordens_compra_itens.observacao`, `valor_desconto`, `valor_total_item`; `ordens_compra.numero_pedido_fornecedor`, `valor_mercadorias`, `valor_descontos`; `core.unidades.inscricao_estadual`) | ❌ | ❌ |
| **B7** `condicoes_pagamento_compras` | ✅ (índice `(codigo_empresa, codigo_omie)`), **mas `descricao` e `lista_dias` em `varchar(30)` são curtas**: aumentar para `varchar(100)` (ver o B7) | ❌ |
| **B7** `core.projetos`, `core.contas_correntes` | ❌ | ❌ |
| **B7** `core.categorias` com `codigo_empresa` e marcações | ❌ (ainda único pelo código no banco inteiro) | ❌ |

**Antes de subir compras para produção**, todas as migrations do teste (PR #273, `7918357`,
`bf9d86a`, `8715549` e as do B1/D6) precisam ser aplicadas lá.

## 1. 🔴 Errado ou bloqueando (fazer primeiro)

### B0. Levar para PRODUÇÃO tudo o que já está no teste

O banco de produção (dump de 23/09/2026, 16:46) **não tem nenhuma tabela nova de compras**. Antes de
o av-hub de compras subir para produção, aplicar lá, na ordem: PR #273 (requisições, OCs, parcelas,
parâmetros, triggers), `7918357` (renomes + `codigo_comprador`), `bf9d86a` (`id_origem`),
`8715549` (compradores, cotações, `cotacao_data`/`cotacao_origem`, contador de números), o B1 e
`condicoes_pagamento_compras`. **Conferir depois com um dump** (a tabela 0.1 é o gabarito).

### B1. `pedidos_compras` ainda quebra na primeira carga real (D5)

**Situação em 23/09 (dumps):** no **teste** o B1 está aplicado, **menos duas colunas** de
`pedidos_compras_itens`: `codigo_item_integracao` e `observacao` (criar). Os **models** da API
(`pedido_compra.js`, `pedido_compra_item.js`) continuam com `INTEGER` e sem as colunas novas
(atualizar). Em **produção**, nada (B0). A pipeline já grava só as colunas que existem, então pode
ser ligada no teste mesmo sem as duas.

O model `src/models/pedido_compra.js` e `pedido_compra_item.js` continuam com **`INTEGER`** nos
códigos do Omie. Os códigos reais passam de 2.147.483.647: no pedido 46618, `nCodPed`
10467753709, `nCodFor` 10363934283, `nCodCompr` 10219958954, `nCodCC` 10364415646, `nCodProj`
9779703251, `nCodItem` 10467754866. **Se o DBA já aplicou o ALTER no banco, falta o model; se não
aplicou, falta os dois.**

```sql
ALTER TABLE core_vendas_faturamento.pedidos_compras
  ALTER COLUMN codigo_pedido_compra_omie TYPE bigint,
  ALTER COLUMN codigo_fornecedor         TYPE bigint,
  ALTER COLUMN codigo_comprador          TYPE bigint,
  ALTER COLUMN codigo_conta_corrente     TYPE bigint,
  ALTER COLUMN codigo_projeto            TYPE bigint,
  ALTER COLUMN contato                   TYPE varchar(100),   -- cContato é string100
  ADD COLUMN numero_pedido_fornecedor    varchar(30),         -- cNumPedido (≠ cNumero)
  ADD COLUMN incluido_em_omie            timestamptz,         -- dIncData + cIncHora
  ADD COLUMN codigo_condicao_pagamento   varchar(3),          -- cCodParc ("U10")
  ADD COLUMN quantidade_parcelas         integer,             -- nQtdeParc
  ADD COLUMN codigo_transportadora       bigint;              -- nCodTransp (código, não nome)

ALTER TABLE core_vendas_faturamento.pedidos_compras_itens
  ALTER COLUMN numero_item_omie     TYPE bigint,
  ALTER COLUMN codigo_local_estoque TYPE bigint,              -- vem como TEXTO no payload real; converter
  ADD COLUMN codigo_item_integracao varchar(20),              -- cCodIntItem: liga o item à OC do av-hub
  ADD COLUMN descricao              varchar(120),
  ADD COLUMN unidade                varchar(6),
  ADD COLUMN valor_desconto         numeric(14,2),            -- nDesconto é VALOR, não %
  ADD COLUMN valor_mercadoria       numeric(14,2),            -- nValMerc
  ADD COLUMN valor_total            numeric(14,2),            -- nValTot = nValMerc - nDesconto + nValorIpi
  ADD COLUMN quantidade_recebida    numeric(14,3),            -- nQtdeRec
  ADD COLUMN observacao             text,                     -- cObs do item (sai impresso)
  ADD COLUMN codigo_categoria       varchar(20);

CREATE INDEX idx_pedidos_compras_itens_cod_integracao
  ON core_vendas_faturamento.pedidos_compras_itens (codigo_item_integracao)
  WHERE codigo_item_integracao IS NOT NULL;

CREATE TABLE core_vendas_faturamento.pedidos_compras_parcelas (
  id               uuid PRIMARY KEY DEFAULT uuidv7(),
  id_pedido_compra uuid NOT NULL REFERENCES core_vendas_faturamento.pedidos_compras(id)
                     ON UPDATE CASCADE ON DELETE CASCADE,
  codigo_empresa   uuid NOT NULL REFERENCES core.unidades(id),
  numero_parcela   integer NOT NULL,        -- nParcela
  data_vencimento  date,                    -- dVencto
  valor            numeric(14,2),           -- nValor
  dias             integer,                 -- nDias
  percentual       numeric(9,5),            -- nPercent (vem 19.99999)
  tipo_documento   varchar(10),             -- cTipoDoc
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_pedidos_compras_parcelas_numero
  ON core_vendas_faturamento.pedidos_compras_parcelas (id_pedido_compra, numero_parcela);
```

`percentual_desconto` do item: remover ou deixar a pipeline calcular. `cfop`: o item do pedido de
compra do Omie não tem, vai ficar sempre nulo.

### B2. O comprador está em dois campos — decidir e tirar um

Hoje a OC tem **`codigo_comprador`** (uuid de `auth.usuarios`, **obrigatório** no POST desde
`7918357`) **e** **`id_comprador`** (FK para `compradores`, resolvido pela sessão desde `8715549`).

- O que o Omie precisa é o `nCodCompr`, e ele só sai de `id_comprador` → `compradores.codigo_comprador_omie`.
- O comentário do model diz que `codigo_comprador` existe para "um admin criar a OC em nome de outro
  comprador". **A regra combinada é o contrário: ninguém emite em nome de outro** (A3). O av-hub
  manda `codigo_comprador` = usuário da sessão, que é sempre igual a `created_by`.

**Proposta:** manter só `id_comprador` como "o comprador" e tirar a obrigatoriedade de
`codigo_comprador` (ou remover a coluna; `created_by` já diz quem emitiu). **Decisão do Nathan antes
de mexer.**

### B3. Número da OC e da requisição: ainda aceito do corpo (o formato já está definido)

- O POST de ordens **continua respeitando `numero_pedido` enviado no corpo** ("número informado
  explicitamente continua sendo respeitado"). Qualquer chamada pode inventar um número e colidir
  com o contador. **Tirar `numero_pedido` da lista `CAMPOS`.**
- Requisição: o comentário diz que "no caminho normal quem manda o número é o MES". O combinado
  (D4) era **não misturar**: o número do MES vai em `numero_requisicao_mes`, e `numero_requisicao`
  é sempre do contador. Hoje não existe `numero_requisicao_mes`. Criar a coluna e separar.
- **Formato: definido** (dump de teste de 23/09). A trigger grava **`OC-000001`** / **`REQ-000001`**,
  com contador por unidade (`contadores_documento`) e 6 dígitos. O av-hub já mostra assim, e é esse
  texto que vai no `cCodIntPed` do Omie (20 caracteres, único dentro de cada conta).

### B4. Rotas para o envio da OC ao Omie (quem envia é a pipeline)

Toda OC fica `status_sincronizacao_omie = 'pendente'` para sempre. O envio em si é da pipeline
(ver o contrato da pipeline, L4); o backend precisa dar a ela:

```
GET   /compras/ordens?status=aprovado&status_sincronizacao_omie=pendente&limit=
        → a fila de envio (com itens, parcelas, nomes e o comprador do Omie resolvido:
          codigo_comprador_omie de compradores)
PATCH /compras/ordens/{id}/sincronizacao
        body sucesso: { status: "sincronizado", codigo_pedido_omie, numero_pedido_omie }
        body falha:   { status: "erro", erro: "<description do omie_fail>" }
        → grava status_sincronizacao_omie, sincronizado_em = now(), erro_sincronizacao_omie
POST  /compras/ordens/{id}/reenviar
        → volta 'erro' para 'pendente' (botão "Reenviar ao Omie" na tela; só pode_editar)
```

O PATCH de sincronização **não pode** mexer em nada além desses campos.

---

## 2. 🟠 Falta para o fluxo fechar

### B5. Nomes e dados completos na OC (A1 + C1 ampliado)

Em `GET /compras/ordens` (listagem) e `GET /compras/ordens/{id}`, sempre com JOIN pelo
**`codigo_empresa` da OC** (o mesmo fornecedor tem código diferente em cada filial):

| Campo | Origem |
|---|---|
| `nome_fornecedor`, `cpf_cnpj_fornecedor` | `core.parceiros` (`codigo_parceiro_omie = codigo_fornecedor`) |
| `nome_transportadora` | `core.parceiros` pelo `codigo_transportadora` |
| `nome_comprador` | `compradores`: `COALESCE(nome_exibicao, nome)` pelo `id_comprador` |
| `nome_criado_por`, `nome_aprovado_por` | usuários `created_by` e `aprovado_por` |
| `nome_projeto` | `core.projetos` (B7) pelo `codigo_projeto` |
| `descricao_categoria` | `core.categorias` (B7) |
| `descricao_conta_corrente` | `core.contas_correntes` (B7) |
| `descricao_condicao_pagamento` | `condicoes_pagamento_compras` (B7), ex.: "30/40/50/60/70" |

**Só no detalhe** (para o PDF do fornecedor): `razao_social_fornecedor`,
`inscricao_estadual_fornecedor`, endereço do fornecedor (logradouro, número, complemento, bairro,
cidade, UF, CEP), `email_fornecedor`, `telefone_fornecedor`.

E em `core.unidades` + `GET /unidades/{id}`: **`inscricao_estadual`** (sai no cabeçalho do pedido).

### B6. Campos da OC para o PDF do fornecedor (D8/A9/C9)

```sql
ALTER TABLE core_vendas_faturamento.ordens_compra_itens
  ADD COLUMN observacao       text,            -- PARA O FORNECEDOR: cObs do item no Omie, sai impressa
  ADD COLUMN valor_desconto   numeric(15,2),   -- quantidade × unitário × desconto% (trigger)
  ADD COLUMN valor_total_item numeric(15,2);   -- já com desconto (trigger)

ALTER TABLE core_vendas_faturamento.ordens_compra
  ADD COLUMN numero_pedido_fornecedor varchar(30),  -- cNumPedido
  ADD COLUMN valor_mercadorias        numeric(15,2), -- Σ quantidade × unitário (trigger)
  ADD COLUMN valor_descontos          numeric(15,2); -- Σ valor_desconto (trigger)

ALTER TABLE core.unidades ADD COLUMN inscricao_estadual varchar(20);
```

- `POST /compras/ordens`: aceitar `observacao` no item (**incluir em `CAMPOS_ITEM`**) e
  `numero_pedido_fornecedor` no cabeçalho.
- Detalhe devolve os campos novos. A trigger que já calcula `valor_total` grava também os de valor,
  na moeda da OC.
- **No av-hub, a observação do item já existe na tela, desabilitada**, esperando esta coluna.

### B7. Catálogos do Omie para os selects da OC

Hoje condição de pagamento, conta corrente e projeto são **texto livre**, e a categoria vem de
`/categorias` sem filtro nenhum. O Omie espera **códigos** (`cCodParc` "U10", `nCodCC`,
`nCodProj`, `cCodCateg` "2.01.03"). Todos são **por conta Omie (por unidade)**. A pipeline preenche
(contrato da pipeline, L5–L8); o backend cria as tabelas e as rotas de leitura.

| Catálogo | Tabela | Rota | Situação |
|---|---|---|---|
| Condição de pagamento | `core_vendas_faturamento.condicoes_pagamento_compras` (nova, D6) | `GET /compras/condicoes-pagamento?codigo_empresa=` | não existe |
| Projeto | `core.projetos` (nova) | `GET /projetos?codigo_empresa=&ativo=&q=` | não existe; DDL em `ENVIAR - contrato-compras-projetos-omie.md` |
| Conta corrente | `core.contas_correntes` (nova) | `GET /contas_correntes?codigo_empresa=&ativo=&q=` | não existe |
| Categoria | `core.categorias` (existe) | `GET /categorias` (existe) | **precisa de ajuste** |
| Local de estoque | `core.locais_estoque` (existe, contrato 005) | `GET /locais_estoque?codigo_empresa=&ativo=` | confirmar se a rota tem filtro por unidade |

```sql
-- Condições de pagamento de compra (ListarFormasPagCompras)
CREATE TABLE core_vendas_faturamento.condicoes_pagamento_compras (
  id                  uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa      uuid NOT NULL REFERENCES core.unidades(id),
  codigo_omie         varchar(3)  NOT NULL,   -- cCodigo ("U10"; "999" = padrão)
  descricao           varchar(100) NOT NULL,  -- cDescricao ("30/40/50/60/70")
  quantidade_parcelas integer,                -- nQtdeParc
  lista_dias          varchar(100),           -- cListaParc
  dias_deslocamento   integer,                -- nDiasParc
  ativo               boolean NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_condicoes_pagamento_compras
  ON core_vendas_faturamento.condicoes_pagamento_compras (codigo_empresa, codigo_omie);

-- ⚠️ No TESTE a tabela já existe com varchar(30), e isso não basta. No teste local da pipeline
-- (24/09/2026), 5 das 326 condições de Mogi não entraram: o Omie devolve descrição e lista de
-- dias com até 71 caracteres (ex.: "A08" = "180/210/240/.../690", 18 parcelas). A doc do Omie
-- fala em 30, mas o dado real passa. Aplicar no teste (e já nascer assim em produção):
ALTER TABLE core_vendas_faturamento.condicoes_pagamento_compras
  ALTER COLUMN descricao  TYPE varchar(100),
  ALTER COLUMN lista_dias TYPE varchar(100);

-- Contas correntes (ListarContasCorrentes)
CREATE TABLE core.contas_correntes (
  id                  uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa      uuid NOT NULL REFERENCES core.unidades(id),
  codigo_conta_omie   bigint      NOT NULL,   -- nCodCC (10364415646 no pedido 46618)
  codigo_integracao   varchar(20),            -- cCodCCInt
  descricao           varchar(40) NOT NULL,   -- descricao ("01 - Boleto/Pix/TED")
  tipo                varchar(2),             -- tipo_conta_corrente (CC, CX, AC…)
  codigo_banco        varchar(3),
  codigo_agencia      varchar(10),
  numero_conta        varchar(25),
  ativo               boolean NOT NULL DEFAULT true,   -- NOT inativo
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  deleted_at          timestamptz
);
CREATE UNIQUE INDEX uq_contas_correntes_empresa_codigo
  ON core.contas_correntes (codigo_empresa, codigo_conta_omie);
CREATE INDEX idx_contas_correntes_empresa_ativo
  ON core.contas_correntes (codigo_empresa, ativo) WHERE deleted_at IS NULL;
-- A pipeline não mexe no updated_at: quem atualiza é a trigger, como no resto do banco.
CREATE TRIGGER trg_contas_correntes_updated_at BEFORE UPDATE ON core.contas_correntes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Categorias: hoje codigo_categoria é ÚNICO NO BANCO INTEIRO e não há unidade.
-- As categorias são por conta Omie; e a OC só deve listar as de DESPESA ativas.
ALTER TABLE core.categorias
  ADD COLUMN codigo_empresa      uuid REFERENCES core.unidades(id),
  ADD COLUMN ativo               boolean NOT NULL DEFAULT true,   -- NOT conta_inativa
  ADD COLUMN conta_despesa       boolean,                         -- conta_despesa = "S"
  ADD COLUMN conta_receita       boolean,                         -- conta_receita = "S"
  ADD COLUMN totalizadora        boolean,                         -- totalizadora = "S" (grupo, não se lança)
  ADD COLUMN nao_exibir          boolean,                         -- nao_exibir = "S"
  ADD COLUMN categoria_superior  varchar(20),
  ADD COLUMN tipo_categoria      varchar(3);
-- Trocar a unicidade de (codigo_categoria) para (codigo_empresa, codigo_categoria).
-- Se a tabela estiver VAZIA (é o caso do teste/produção em 23/09), dá para fazer tudo de uma vez,
-- com codigo_empresa já NOT NULL:
ALTER TABLE core.categorias ALTER COLUMN codigo_empresa SET NOT NULL;
ALTER TABLE core.categorias DROP CONSTRAINT uq_core_categorias_codigo;
CREATE UNIQUE INDEX uq_categorias_empresa_codigo
  ON core.categorias (codigo_empresa, codigo_categoria);   -- SEM WHERE: é o ON CONFLICT da pipeline
CREATE INDEX idx_categorias_empresa_despesa
  ON core.categorias (codigo_empresa, conta_despesa, ativo) WHERE deleted_at IS NULL;
CREATE TRIGGER trg_categorias_updated_at BEFORE UPDATE ON core.categorias
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

Rotas: todas com `codigo_empresa`, `ativo` (padrão `true`), `q` (código ou descrição, sem acento),
ordem por código/descrição. Em `/categorias`, também `tipo=despesa` (só `conta_despesa`, não
totalizadora, não `nao_exibir`), que é o que a OC usa.

**Testado no banco local em 24/09/2026** (este DDL + o de `core.projetos`, e a pipeline com os
três catálogos ligados): 59 + 47 projetos, 107 + 13 contas correntes e 312 + 262 categorias
(Mogi + Uberaba), nenhum erro; rodar de novo não duplica e a trigger atualiza o `updated_at`. Os
códigos do pedido 46618 viram os nomes do PDF do Omie: projeto 9779703251 = "16 - Revenda", conta
10364415646 = "01 - Boleto/Pix/TED", categoria `2.01.03` = "Compras de Materia Prima" (despesa, não
totalizadora; o grupo `2.01` é totalizador). Categorias de despesa lançáveis e ativas: 123 em Mogi e
120 em Uberaba, que é o que o select da OC deve listar.

**Depois:** a trigger de `ordens_compra_parcelas` usa `condicoes_pagamento_compras.lista_dias` da
condição escolhida e marca `calculo_provisorio = false` (hoje é "partes iguais a cada 30 dias").

### B8. Listagem, indicadores e limite (A5–A7)

```
GET /compras/ordens?q=           → q também busca no NOME do fornecedor (depende do B5)
GET /compras/requisicoes/resumo?codigo_empresa=  → { abertas, em_cotacao, atendidas, canceladas }
GET /compras/ordens/resumo?codigo_empresa=       → { aguardando_aprovacao, valor_aguardando_aprovacao_brl,
                                                     aprovadas, canceladas, pendentes_omie, com_erro_omie }
GET /compras/parametros?codigo_empresa=          → { limite_aprovacao }
```

As rotas `/resumo` **antes** de `/:id` (hoje `/compras/ordens/resumo` cai em `/:id` e responde
`400 "id deve ser um uuid"`). Com isso o av-hub deixa de baixar todas as OCs para somar os
indicadores.

### B9. Permissões e histórico (A8/D7)

- **Ação `pode_aprovar`** na matriz de permissões (aprovar e reprovar OC). Hoje o av-hub usa
  `pode_editar`, e quem cadastra pode aprovar.
- **Tela `compradores`** na matriz (`pode_visualizar`, `pode_editar`) + item de menu. Só o
  administrador edita o vínculo.
- **Histórico de decisão** da OC: tabela `ordens_compra_historico` (quem, quando, de → para,
  motivo). Ao cancelar, hoje só fica `motivo_reprovacao`: faltam `cancelado_por`/`cancelado_em`.
- `aprovado_por`/`created_by`/`updated_by` vêm do corpo porque a API só conhece a `x-api-key`.
  Continua valendo o contrato de identidade propagada (`ENVIAR - contrato-permissoes-e-escopo-no-banco.md`).

---

## 3. 🟡 Depois

- **B10. Vínculo OC ↔ pedido de venda** (hoje o comprador escreve "PV 27645 - GABRIEL NICOLAU" no
  `cObsInt` e o número no `cNumPedido`). Vai ter contrato próprio; o Nathan vai detalhar.
- **B11. Impostos na OC** (IPI, ICMS ST): só depois de o item escolher o produto do cadastro
  (`core.produtos`, com NCM). Até lá o PDF mostra o total sem impostos.
- **B12. Produto do cadastro no item** (`codigo_produto` hoje vai nulo; o Omie precisa de
  `nCodProd` para vincular ao estoque): busca em `core.produtos` por unidade, como o fornecedor.

---

## 4. Ordem sugerida

1. **B1** (antes de a pipeline ligar os pedidos de compra) e **B2/B3** (decisão + ajuste pequeno).
2. **B4** junto com o L4 da pipeline (envio ao Omie).
3. **B5** e **B6** (a tela e o PDF da OC dependem deles).
4. **B7** junto com L5–L8 da pipeline (catálogos).
5. **B8** e **B9**.

## 5. Aceite

- Um pedido de compra real do Omie (ex.: 46618) grava no espelho sem estouro, com itens, parcelas e
  `codigo_item_integracao`.
- Uma OC aprovada vai ao Omie e volta `sincronizado` com `numero_pedido_omie`; uma falha fica `erro`
  com a mensagem do Omie e pode ser reenviada.
- A tela e o PDF da OC mostram nome/CNPJ/IE do fornecedor, nomes do comprador e do projeto, e a
  observação do item.
- Condição de pagamento, categoria, conta corrente e projeto são escolhidos de listas da unidade, e
  a OC grava os códigos que o Omie aceita.
- `POST /compras/ordens` com `numero_pedido` no corpo é ignorado; o número sai só do contador.
