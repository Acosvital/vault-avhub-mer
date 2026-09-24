# Compras — pedido para o DBA (banco)

> **⚠️ Substituído em 23/09/2026 por `../ENVIAR - contrato-compras-backend.md`**, que tem a lista atualizada: o que já foi entregue
> (conferido no `develop`), o que falta e o que está errado. Este arquivo fica como histórico.

**Data:** 23/09/2026 · **Para:** DBA
**Contratos completos, só para referência:**
`../ENVIAR - contrato-compradores-funcionario.md`,
`../ENVIAR - contrato-compras-omie-pedidocompra.md` e
`../ENVIAR - contrato-compras-pendencias-pos-backend.md`.

O que está aqui é só **schema, trigger e SQL**. Rotas ficam no arquivo da API, extração do Omie
no da pipeline.

---

## D1. Tabela de compradores (nova)

Mesmo esquema de `vendedores`:
- uma linha por comprador **por conta Omie**;
- ligação com `core.funcionarios`;
- a mesma pessoa pode ser vinculada em várias filiais, mas **no máximo uma vez por filial**.

```sql
CREATE TABLE core_vendas_faturamento.compradores (
  id                    uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa        uuid NOT NULL REFERENCES core.unidades(id)
                          ON UPDATE CASCADE ON DELETE RESTRICT,
  codigo_comprador_omie varchar(20) NOT NULL,   -- nCodigo do ListarCompradores
  nome                  varchar(70) NOT NULL,   -- cDescricao (vem do Omie)
  nome_exibicao         varchar(255),           -- editado no av-hub; NULL = usar nome
  ativo                 boolean NOT NULL DEFAULT true,   -- NOT cInativo
  id_funcionario        uuid REFERENCES core.funcionarios(id)
                          ON UPDATE CASCADE ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  created_by            uuid,
  updated_at            timestamptz NOT NULL DEFAULT now(),
  updated_by            uuid,
  deleted_at            timestamptz,
  deleted_by            uuid
);

CREATE UNIQUE INDEX uq_compradores_empresa_codigo
  ON core_vendas_faturamento.compradores (codigo_empresa, codigo_comprador_omie)
  WHERE deleted_at IS NULL;

-- no máximo um comprador por pessoa DENTRO da mesma filial
CREATE UNIQUE INDEX uq_compradores_funcionario_empresa
  ON core_vendas_faturamento.compradores (id_funcionario, codigo_empresa)
  WHERE id_funcionario IS NOT NULL AND deleted_at IS NULL;

CREATE INDEX idx_compradores_id_funcionario
  ON core_vendas_faturamento.compradores (id_funcionario);

CREATE TRIGGER trg_compradores_updated_at
  BEFORE UPDATE ON core_vendas_faturamento.compradores
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

- **Sem `id_usuario`**: o caminho usuário → funcionário já existe em `usuarios.id_funcionario`.
- **Sem backfill.** O vínculo é manual, feito pelo administrador na tela do av-hub.

## D2. SQL da sugestão de vínculo (igual à de vendedores)

A consulta que a rota `GET /compras/compradores/{id}/sugestoes` vai usar. É a mesma lógica da
sugestão de vendedores: **mesmo nome em outra unidade, já vinculado a um funcionário**. Ela só
sugere; quem grava é o administrador. Ponto de partida:

```sql
SELECT c2.id_funcionario, f.nome_completo AS nome_funcionario,
       c2.codigo_empresa AS codigo_empresa_origem
FROM core_vendas_faturamento.compradores c1
JOIN core_vendas_faturamento.compradores c2
  ON c2.codigo_empresa <> c1.codigo_empresa
 AND unaccent(lower(c2.nome)) = unaccent(lower(c1.nome))
 AND c2.id_funcionario IS NOT NULL
 AND c2.deleted_at IS NULL
JOIN core.funcionarios f ON f.id = c2.id_funcionario
WHERE c1.id = :id AND c1.id_funcionario IS NULL
LIMIT 1;
```

Pode ajustar a regra de compatibilidade (por exemplo `pg_trgm`/`similarity()`) do jeito que
foi feito para vendedores.

## D3. OC guarda o comprador

```sql
ALTER TABLE core_vendas_faturamento.ordens_compra
  ADD COLUMN id_comprador uuid
    REFERENCES core_vendas_faturamento.compradores(id)
    ON UPDATE CASCADE ON DELETE RESTRICT;
```

Quem preenche é a API no POST (ver o arquivo da API). A coluna fica gravada: se o vínculo mudar
depois, a OC continua com o comprador da época.

## D4. Número da OC e da requisição: automático, só o número

**Regra:** o banco gera o número, **só o número**. O texto "OC-"/"REQ-" e os zeros à esquerda
ficam por conta do av-hub, na tela. Hoje a API monta `OC-000001` com `count(...) + 1` antes do
INSERT. Com duas emissões ao mesmo tempo, as duas pegam o mesmo número e uma falha. A
sequência do banco resolve isso.

```sql
CREATE SEQUENCE core_vendas_faturamento.seq_ordens_compra_numero;
CREATE SEQUENCE core_vendas_faturamento.seq_requisicoes_compra_numero;

ALTER TABLE core_vendas_faturamento.ordens_compra
  ALTER COLUMN numero_ordem TYPE bigint
    USING NULLIF(regexp_replace(numero_ordem, '\D', '', 'g'), '')::bigint,
  ALTER COLUMN numero_ordem SET DEFAULT nextval('core_vendas_faturamento.seq_ordens_compra_numero');

ALTER TABLE core_vendas_faturamento.requisicoes_compra
  ALTER COLUMN numero_requisicao TYPE bigint
    USING NULLIF(regexp_replace(numero_requisicao, '\D', '', 'g'), '')::bigint,
  ALTER COLUMN numero_requisicao SET DEFAULT nextval('core_vendas_faturamento.seq_requisicoes_compra_numero'),
  -- o número que vem do MES é OUTRO dado: não mistura com a numeração do av-hub
  ADD COLUMN numero_requisicao_mes varchar(30);

-- continuar de onde os dados de teste pararam
SELECT setval('core_vendas_faturamento.seq_ordens_compra_numero',
              COALESCE((SELECT max(numero_ordem) FROM core_vendas_faturamento.ordens_compra), 0) + 1, false);
SELECT setval('core_vendas_faturamento.seq_requisicoes_compra_numero',
              COALESCE((SELECT max(numero_requisicao) FROM core_vendas_faturamento.requisicoes_compra), 0) + 1, false);
```

- **Os índices únicos por unidade** (`codigo_empresa` + número) continuam valendo.
- **Uma sequência só**, para todas as unidades: a numeração não é contínua dentro de cada
  filial (Mogi pode ter 1, 2 e 5, e Uberaba 3 e 4), mas nunca repete e não tem disputa. Se
  quiserem numeração contínua por filial, precisa de uma tabela contador por unidade, com
  `UPDATE ... RETURNING` na mesma transação. Me avisem se for o caso.
- **Omie:** o número vai como texto no `cCodIntPed` do Omie, que aceita 20 caracteres. Um
  `bigint` tem no máximo 19 dígitos, então não precisa de CHECK.
- **A API não pode mais gerar nem aceitar o número no corpo** (ver o arquivo da API).

## D5. Corrigir `pedidos_compras` antes de a pipeline começar a gravar

É o espelho dos pedidos de compra do Omie. **Hoje ele quebra no primeiro upsert real:** as
colunas de código do Omie são `INTEGER`, e os códigos reais já passam do limite (fornecedor
`10037044822`, com 11 dígitos). Além disso, faltam campos que o Omie devolve.

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
  ADD COLUMN codigo_condicao_pagamento   varchar(3),          -- cCodParc
  ADD COLUMN quantidade_parcelas         integer,             -- nQtdeParc
  ADD COLUMN codigo_transportadora       bigint;              -- nCodTransp (o Omie manda código,
                                                              -- não nome; `transportadora` varchar
                                                              -- fica sem uso)

ALTER TABLE core_vendas_faturamento.pedidos_compras_itens
  ALTER COLUMN numero_item_omie     TYPE bigint,
  ALTER COLUMN codigo_local_estoque TYPE bigint,
  ADD COLUMN descricao              varchar(120),    -- cDescricao
  ADD COLUMN unidade                varchar(6),      -- cUnidade
  ADD COLUMN valor_desconto         numeric(14,2),   -- nDesconto: o Omie manda VALOR, não %
  ADD COLUMN valor_mercadoria       numeric(14,2),   -- nValMerc
  ADD COLUMN valor_total            numeric(14,2),   -- nValTot
  ADD COLUMN quantidade_recebida    numeric(14,3),   -- nQtdeRec (o Recebimento vai usar)
  ADD COLUMN codigo_categoria       varchar(20),     -- cCodCateg
  ADD COLUMN codigo_item_integracao varchar(20);     -- cCodIntItem: liga o item de volta
                                                     -- ao item da OC do av-hub (ver abaixo)

CREATE INDEX idx_pedidos_compras_itens_cod_integracao
  ON core_vendas_faturamento.pedidos_compras_itens (codigo_item_integracao)
  WHERE codigo_item_integracao IS NOT NULL;

CREATE TABLE core_vendas_faturamento.pedidos_compras_parcelas (
  id               uuid PRIMARY KEY DEFAULT uuidv7(),
  id_pedido_compra uuid NOT NULL REFERENCES core_vendas_faturamento.pedidos_compras(id)
                     ON UPDATE CASCADE ON DELETE CASCADE,
  codigo_empresa   uuid NOT NULL REFERENCES core.unidades(id)
                     ON UPDATE CASCADE ON DELETE RESTRICT,
  numero_parcela   integer NOT NULL,        -- nParcela
  data_vencimento  date,                    -- dVencto
  valor            numeric(14,2),           -- nValor
  dias             integer,                 -- nDias
  percentual       numeric(6,3),            -- nPercent
  tipo_documento   varchar(10),             -- cTipoDoc
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_pedidos_compras_parcelas_numero
  ON core_vendas_faturamento.pedidos_compras_parcelas (id_pedido_compra, numero_parcela);
```

**Por que `codigo_item_integracao`:** quando a OC do av-hub vai para o Omie, cada item leva um
`cCodIntItem` (`numero_ordem-ordem`). A resposta do Omie não devolve código de item nenhum, então
a única forma de saber qual item do espelho é qual item da OC (por exemplo, para levar o
`quantidade_recebida` ao item certo) é guardar esse código quando o pedido volta pela pipeline.
Nos pedidos criados direto no Omie, a coluna fica nula.

**A decidir:**
- **`percentual_desconto`:** deixar a pipeline calcular (`valor_desconto / (qtd × unitário)`)
  ou remover.
- **`cfop`:** o item do pedido de compra do Omie não tem CFOP, então essa coluna vai ficar
  sempre nula.

## D6. Catálogo de condições de pagamento (tabela nova)

O Omie tem esse catálogo (`ListarFormasPagCompras`), com os dias de cada parcela. A OC vai
passar a escolher a condição de uma lista em vez de texto livre, e a trigger de
`ordens_compra_parcelas` pode trocar o palpite de "partes iguais a cada 30 dias" pelos dias
reais.

```sql
CREATE TABLE core_vendas_faturamento.condicoes_pagamento_compras (
  id                  uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa      uuid NOT NULL REFERENCES core.unidades(id)
                        ON UPDATE CASCADE ON DELETE RESTRICT,
  codigo_omie         varchar(3)  NOT NULL,   -- cCodigo ("999" = padrão)
  descricao           varchar(30) NOT NULL,   -- cDescricao
  quantidade_parcelas integer,                -- nQtdeParc
  lista_dias          varchar(30),            -- cListaParc (dias de vencimento)
  dias_deslocamento   integer,                -- nDiasParc
  ativo               boolean NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_condicoes_pagamento_compras
  ON core_vendas_faturamento.condicoes_pagamento_compras (codigo_empresa, codigo_omie);
```

Depois de populada pela pipeline:
- `ordens_compra.codigo_condicao_pagamento` passa a guardar o `codigo_omie` da unidade;
- a trigger de parcelas usa `lista_dias` e marca `calculo_provisorio = false`.

**Ainda não levantei** os campos de categoria, conta corrente, projeto e local de estoque no
Omie. Essas tabelas vêm num pedido separado.

## D7. Permissões

- **Tela `compradores`** na matriz de permissões (`pode_visualizar`, `pode_editar`) e item de
  menu. Só o administrador vai editar.
- **Ação `pode_aprovar`** para aprovar e reprovar OC. Hoje o av-hub usa `pode_editar`.

## D8. Campos da OC para o PDF do fornecedor

Vêm do pedido de compra que o Omie imprime (detalhe em
`../ENVIAR - contrato-compras-pendencias-pos-backend.md`, C9):

```sql
ALTER TABLE core_vendas_faturamento.ordens_compra_itens
  ADD COLUMN observacao       text,            -- para o FORNECEDOR (vai no cObs do item no Omie)
  ADD COLUMN valor_desconto   numeric(15,2),   -- quantidade × unitário × desconto% (trigger)
  ADD COLUMN valor_total_item numeric(15,2);   -- já com desconto (trigger)

ALTER TABLE core_vendas_faturamento.ordens_compra
  ADD COLUMN numero_pedido_fornecedor varchar(30),  -- cNumPedido no Omie
  ADD COLUMN valor_mercadorias        numeric(15,2), -- Σ quantidade × unitário (trigger)
  ADD COLUMN valor_descontos          numeric(15,2); -- Σ valor_desconto dos itens (trigger)

-- core.unidades: inscrição estadual da unidade compradora (sai no pedido)
ALTER TABLE core.unidades ADD COLUMN inscricao_estadual varchar(20);
```

A trigger que já calcula `valor_total` passa a gravar também os campos de valor (na moeda da OC).

---

## Ordem

D4 primeiro (corrige a duplicidade de número). D5 **antes** de a pipeline ligar os pedidos de compra. D1–D3 antes das rotas de compradores. D4,
D6 e D7 podem ir juntos com qualquer um deles.
