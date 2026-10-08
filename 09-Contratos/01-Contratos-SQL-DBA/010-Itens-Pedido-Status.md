---
tags: [contrato-sql, dba, integracao-av-hub-mes, rastreabilidade]
status: proposta
criado: 2026-10-08
atualizado: 2026-10-08
---

# Contrato SQL 010 — `core_vendas_faturamento.itens_pedido_status` (novo)

> Status: **proposta (08/10/2026), para o Gustavo (DBA) aplicar.** Nada disto existe no banco nem no código. É o "contrato SQL próprio" que o [[005-Status-Item-Integracao-MES]] previa ("`itens_pedido_status` ou nome a definir") e a base da tela 1.2 (Meus Pedidos por etapa, tarefa E3). Dono da decisão do desenho: Nathan; aplicação: Gustavo. **O consumidor (job) e a rota de leitura estão no [[006-Status-por-Item-Leitura-no-Hub]].**

## Por quê

O MES já expõe `GET /itens/status` (foto atual de cada parcial alterada desde um cursor). O av-hub não deve consultar o MES a cada carregamento de tela do Portal do Vendedor: um job do hub lê o MES a cada 1 a 2 minutos e grava aqui. A tela lê só esta tabela.

## DDL

```sql
CREATE TABLE core_vendas_faturamento.itens_pedido_status (
  id                    uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa        uuid NOT NULL REFERENCES core.unidades(id)
                          ON UPDATE CASCADE ON DELETE RESTRICT,
  id_item_parcial       uuid NOT NULL,            -- id da ItemParcial no MES (sem FK: outro banco)
  pedido_venda          varchar(40) NOT NULL,     -- mesmo número de /pedidos_liberados
  ordem_producao        varchar(40),              -- número da OP no MES (hoje OP-000123)
  codigo_produto_omie   varchar(40),
  codigo_produto        varchar(100),
  etapa                 varchar(60) NOT NULL,     -- vocabulário PROVISÓRIO: sem CHECK nem enum
  setor_codigo          varchar(60),
  setor_nome            varchar(200),
  setor_tipo            varchar(30),
  status                varchar(30) NOT NULL,     -- status da parcial no MES, cru
  quantidade_na_etapa   numeric(14,3) NOT NULL,
  atendido_pelo_estoque boolean NOT NULL DEFAULT false,
  ocorrido_em           timestamptz NOT NULL,     -- = updated_at da parcial no MES
  mes_updated_at        timestamptz NOT NULL,
  mes_deleted_at        timestamptz,              -- parcial cancelada no MES
  lido_em               timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_itens_pedido_status
    UNIQUE (codigo_empresa, id_item_parcial, etapa, ocorrido_em)
);

-- tela: todas as parciais de um pedido, a mais recente primeiro
CREATE INDEX ix_itens_pedido_status_pedido
  ON core_vendas_faturamento.itens_pedido_status
  (codigo_empresa, pedido_venda, id_item_parcial, ocorrido_em DESC);

-- job: maior updated_at lido, por unidade (cursor derivável, mas o índice evita varredura)
CREATE INDEX ix_itens_pedido_status_cursor
  ON core_vendas_faturamento.itens_pedido_status (codigo_empresa, mes_updated_at DESC);

CREATE TABLE core_vendas_faturamento.itens_pedido_status_cursor (
  codigo_empresa   uuid PRIMARY KEY REFERENCES core.unidades(id)
                     ON UPDATE CASCADE ON DELETE CASCADE,
  alterado_desde   timestamptz NOT NULL,          -- maior updated_at processado com sucesso
  atualizado_em    timestamptz NOT NULL DEFAULT now()
);

-- estado atual: uma linha por parcial viva, a de maior ocorrido_em
CREATE VIEW core_vendas_faturamento.vw_itens_pedido_status_atual AS
SELECT DISTINCT ON (codigo_empresa, id_item_parcial) *
  FROM core_vendas_faturamento.itens_pedido_status
 WHERE mes_deleted_at IS NULL
 ORDER BY codigo_empresa, id_item_parcial, ocorrido_em DESC, lido_em DESC;
```

## Regras

- **Chave de gravação** `(codigo_empresa, id_item_parcial, etapa, ocorrido_em)`, como no contrato 005: uma parcial pode passar duas vezes pela mesma etapa (reprovação e retorno). O job faz `INSERT ... ON CONFLICT DO NOTHING`; uma parcial cancelada no MES gera uma linha com `mes_deleted_at` preenchido e some da view.
- **Histórico:** as linhas anteriores ficam. Como o MES manda a foto (e não um log), o histórico só tem a precisão do intervalo de leitura.
- **`etapa`, `setor_*` e `status` entram crus**, sem enum, para o av-hub não depender do vocabulário ([[Revisao-dos-Estados-e-Status]]).
- **Permissão:** a tabela é lida só pela API (`GET` do contrato 006), que aplica o escopo do vendedor; nada de leitura direta pelo BFF.
- **Retenção:** sem prazo definido. Sugestão: manter 24 meses e arquivar depois, junto com a decisão de retenção de logs (item 53 do [[Registro-de-Decisoes-2026-10-07]]).

## Perguntas

1. **Nome da tabela e do schema** (Gustavo): `core_vendas_faturamento` por ser onde estão pedidos e requisições; trocar se preferir um schema próprio da integração.
2. **Pedido que o vendedor vê:** uma parcial por linha, ou o hub agrega por pedido (etapa mais atrasada)? Depende da pergunta 3 do contrato 005 (item dividido em parciais em etapas diferentes). **O desenho acima guarda por parcial e deixa a agregação para a rota.**

## Depois de aplicado

- Gustavo: job de leitura e rota, no [[006-Status-por-Item-Leitura-no-Hub]].
- av-hub: a tela 1.2 (Meus Pedidos por etapa) passa a mostrar a etapa de cada item.

## Ver também
- [[005-Status-Item-Integracao-MES]]
- [[Integracao-AvHub-MES-Volta-Plano]]
- [[Integracao-AvHub-MES-Especificacao-F1]]
- [[Indice-Contratos]]
