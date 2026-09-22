---
tags: [contrato-sql, dba, integracao-av-hub-mes, compras]
status: proposta
criado: 2026-09-22
atualizado: 2026-09-22
---

# Contrato SQL 007 — `core_vendas_faturamento.ordens_compra` + itens + parcelas (novo)

**Status:** proposta, aprovada por Nathan em 22/09/2026, **reescrita no mesmo dia** para bater exatamente com o contrato já escrito pelo frontend (`docs/ENVIAR - contrato-compras-fluxo-completo.md`, no repositório `av-hub`, criado 21/09/2026 ao construir `app/(protected)/compras/*`) — aquele documento é mais detalhado e vem do código real (domínio TypeScript já implementado, rodando hoje sobre dados de exemplo). Este contrato foi alinhado a ele campo a campo. **Gustavo: aplicar esta versão, não uma anterior.**

**✅ Backend implementado e testado em 22/09/2026** (`POST/GET/PATCH /compras/ordens`, `GET /compras/{fornecedores,transportadoras}`, branch local `feat/compras-requisicoes-e1` em `api-acos-vital`, mesma branch do E1) — DDL abaixo aplicado e validado no ambiente de teste local: régua de R$ 30.000 testada em BRL e em moeda estrangeira (conversão correta), aprovação/cancelamento testados, devolução da requisição de origem à fila ao cancelar testada. **Duas limitações conscientes, documentadas no código, não escondidas:**
- `status_sincronizacao_omie` sempre fica `pendente` — o `IncluirPedCompra` real no Omie **não foi implementado** (fora do escopo desta passada, exige credenciais/acesso ao Omie).
- Cálculo de parcelas usa split igual + vencimento a cada 30 dias como placeholder — não existe catálogo real de condição de pagamento (`codigo_condicao_pagamento` é texto livre, sem formato garantido, confirmado contra `components/Compras/acoes.ts` no av-hub). Ver pergunta aberta nova abaixo.

**Ainda não deployado em produção nem enviado ao remoto.**

> ⚠️ **Não usar `pedidos_compras`/`pedidos_compras_itens` para nada disto.** O próprio `docs/ENVIAR - contrato-compras-fluxo-completo.md` sugeria esse nome ("ou nome equivalente no schema real do vault") sem saber que colide com o contrato SQL [[004-Pedidos-Compras]] (`core_vendas_faturamento.pedidos_compras`), que é o **espelho read-only do histórico de compras do Omie** — propósito totalmente diferente. Os nomes aqui (`ordens_compra`/`ordens_compra_itens`/`ordens_compra_parcelas`) evitam essa colisão de propósito.

## Por quê

A tarefa E2 do [[Cronograma-2-Meses]] precisa de um lugar para a Ordem de Compra nascer no av-hub, decidida pelo comprador. **A tela já existe e já está pronta** (`app/(protected)/compras/nova`, `app/(protected)/compras/ordem/[id]`) — hoje roda 100% sobre dados de exemplo (mock em `lib/compras/dados.ts`), marcado com `GAMBIARRA(...)` em cada ponto de integração. Esta tabela é o que falta para tirar o mock.

**Não confundir com o contrato SQL 004** ([[004-Pedidos-Compras]]) — aquele é espelho read-only do Omie; este é a OC que o **av-hub decide e cria**, com fluxo de aprovação e sincronização de escrita própria com o Omie (`IncluirPedCompra`, dual-write).

## Requisito de leitura antes de aplicar

**Ler `docs/ENVIAR - contrato-compras-fluxo-completo.md` inteiro no repositório `av-hub`** — é a fonte primária, este contrato só traduz para DDL. Ele documenta regras que não cabem em DDL: a conversão de `desconto` (percentual → valor monetário do Omie), a conversão de moeda estrangeira para BRL antes de aplicar a régua de R$ 30.000, o cálculo de parcelas a partir de `codigo_condicao_pagamento`/`quantidade_parcelas`, e o mapeamento `tipo_frete → cTpFrete` do Omie.

## DDL

```sql
CREATE TABLE core_vendas_faturamento.ordens_compra (
  id                        uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa            uuid NOT NULL REFERENCES core.unidades(id)
                              ON UPDATE CASCADE ON DELETE RESTRICT,
  numero_pedido             varchar(30) NOT NULL,   -- gerado pelo av-hub, não pelo Omie
  id_requisicao             uuid REFERENCES core_vendas_faturamento.requisicoes_compra(id)
                              ON UPDATE CASCADE ON DELETE SET NULL,
                              -- null quando a OC nasce sem requisição de origem
                              -- (botão "Nova ordem de compra", ver contrato SQL 008)

  codigo_fornecedor         varchar(40) NOT NULL,  -- espelha codigo_parceiro_omie, sem FK
  codigo_comprador          uuid NOT NULL REFERENCES auth.usuarios(id),

  data_previsao_chegada     date,
  codigo_condicao_pagamento varchar(60),
  quantidade_parcelas       integer NOT NULL DEFAULT 1,
  contato                   varchar(60),
  contrato                  varchar(20),
  codigo_categoria          varchar(20),
  codigo_conta_corrente     varchar(20),   -- nCodCC no Omie, texto livre
  codigo_projeto            varchar(20),   -- nCodProj no Omie, texto livre

  moeda                     varchar(3) NOT NULL DEFAULT 'BRL',
  cotacao_moeda             numeric(14,6),  -- obrigatório quando moeda != 'BRL'
  observacao                text,
  observacao_interna        text,
  email_aprovador           varchar(100),

  tipo_frete                varchar(3) NOT NULL,  -- 'CIF' | 'FOB'
  codigo_transportadora     varchar(40),          -- espelha codigo_parceiro_omie, sem FK
  placa_veiculo             varchar(10),
  uf_veiculo                varchar(2),
  peso_liquido              numeric(12,3),
  peso_bruto                numeric(12,3),
  valor_frete               numeric(14,2),
  valor_seguro              numeric(14,2),
  volumes                   integer,

  valor_total               numeric(14,2) NOT NULL,      -- na moeda de origem
  valor_total_brl           numeric(14,2) NOT NULL,      -- = valor_total × cotacao_moeda
                                                           -- quando moeda != 'BRL'; senão = valor_total.
                                                           -- É ESTE campo que a régua de R$ 30.000 usa.
                                                           -- Calculado pelo backend, nunca recebido do cliente.

  status                    varchar(20) NOT NULL DEFAULT 'rascunho',
                              -- 'rascunho' | 'aguardando_aprovacao' | 'aprovado' | 'cancelado'
                              -- (ver STATUS_ORDEM em lib/domain/compras-ordem.ts do av-hub)
  motivo_reprovacao         text,
  aprovado_por              uuid REFERENCES auth.usuarios(id),
  aprovado_em               timestamptz,

  status_sincronizacao_omie varchar(20) NOT NULL DEFAULT 'pendente',
                              -- 'pendente' | 'sincronizado' | 'erro'
  codigo_pedido_omie        integer,       -- nCodPed devolvido pelo Omie
  numero_pedido_omie        varchar(20),   -- cNumero devolvido pelo Omie
  erro_sincronizacao_omie   text,

  id_origem                 uuid,
  created_at                timestamptz NOT NULL DEFAULT now(),
  created_by                uuid,
  updated_at                timestamptz NOT NULL DEFAULT now(),
  updated_by                uuid,
  deleted_at                timestamptz,
  deleted_by                uuid,

  CONSTRAINT ck_ordens_compra_tipo_frete CHECK (tipo_frete IN ('CIF','FOB')),
  CONSTRAINT ck_ordens_compra_status CHECK (status IN ('rascunho','aguardando_aprovacao','aprovado','cancelado')),
  CONSTRAINT ck_ordens_compra_status_sync CHECK (status_sincronizacao_omie IN ('pendente','sincronizado','erro')),
  CONSTRAINT ck_ordens_compra_cotacao_moeda CHECK (moeda = 'BRL' OR cotacao_moeda IS NOT NULL)
);

CREATE UNIQUE INDEX uq_ordens_compra_numero
  ON core_vendas_faturamento.ordens_compra (codigo_empresa, numero_pedido)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_ordens_compra_status
  ON core_vendas_faturamento.ordens_compra (codigo_empresa, status);

CREATE INDEX idx_ordens_compra_requisicao
  ON core_vendas_faturamento.ordens_compra (id_requisicao);

CREATE TRIGGER trg_ordens_compra_updated_at
  BEFORE UPDATE ON core_vendas_faturamento.ordens_compra
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Itens (1:N)
CREATE TABLE core_vendas_faturamento.ordens_compra_itens (
  id                    uuid PRIMARY KEY DEFAULT uuidv7(),
  id_ordem_compra       uuid NOT NULL REFERENCES core_vendas_faturamento.ordens_compra(id)
                          ON UPDATE CASCADE ON DELETE CASCADE,
  codigo_empresa        uuid NOT NULL REFERENCES core.unidades(id)
                          ON UPDATE CASCADE ON DELETE RESTRICT,
  codigo_produto        varchar(60),         -- espelha core.produtos.codigo_produto_omie, sem FK
  descricao_produto     text NOT NULL,
  quantidade            numeric(14,3) NOT NULL,
  unidade_medida        varchar(10) NOT NULL,  -- cUnidade obrigatório no IncluirPedCompra
  valor_unitario        numeric(14,4) NOT NULL,
  desconto              numeric(6,3) NOT NULL DEFAULT 0,  -- PERCENTUAL, não valor — conversão pro
                                                            -- Omie (nDesconto monetário) é responsabilidade
                                                            -- do backend no momento do IncluirPedCompra
  tipo_material         varchar(15) NOT NULL,  -- 'acabado' | 'nao_acabado' — decide contra o que o
                                                 -- Recebimento confere (ver Fluxo-Compras-Completo, C9)
  local_estoque         varchar(60),
  ordem                 integer NOT NULL,      -- posição no array, identidade estável (mesmo padrão
                                                 -- já corrigido no contrato SQL 004 em 22/09)
  created_at            timestamptz NOT NULL DEFAULT now(),
  created_by            uuid,
  updated_at            timestamptz NOT NULL DEFAULT now(),
  updated_by            uuid,

  CONSTRAINT ck_ordens_compra_itens_tipo_material CHECK (tipo_material IN ('acabado','nao_acabado')),
  CONSTRAINT ck_ordens_compra_itens_ordem CHECK (ordem >= 1)
);

CREATE UNIQUE INDEX uq_ordens_compra_itens_ordem
  ON core_vendas_faturamento.ordens_compra_itens (id_ordem_compra, ordem);

CREATE TRIGGER trg_ordens_compra_itens_updated_at
  BEFORE UPDATE ON core_vendas_faturamento.ordens_compra_itens
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Parcelas (1:N) — calculadas pelo backend a partir de codigo_condicao_pagamento/
-- quantidade_parcelas + valor_total_brl + data_previsao_chegada; nunca digitadas
-- pelo usuário (ver docs/ENVIAR - contrato-compras-fluxo-completo.md, 3.2)
CREATE TABLE core_vendas_faturamento.ordens_compra_parcelas (
  id                uuid PRIMARY KEY DEFAULT uuidv7(),
  id_ordem_compra   uuid NOT NULL REFERENCES core_vendas_faturamento.ordens_compra(id)
                      ON UPDATE CASCADE ON DELETE CASCADE,
  numero_parcela    integer NOT NULL,
  data_vencimento   date NOT NULL,
  valor             numeric(14,2) NOT NULL,   -- última parcela absorve diferença de arredondamento
  created_at        timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT ck_ordens_compra_parcelas_numero CHECK (numero_parcela >= 1)
);

CREATE UNIQUE INDEX uq_ordens_compra_parcelas_numero
  ON core_vendas_faturamento.ordens_compra_parcelas (id_ordem_compra, numero_parcela);
```

**Sem FK para `core.produtos`/`core.parceiros`** — mesmo princípio de sempre (sync independente, sem ordem garantida).

**`id_requisicao` tem FK real** (diferente do que o rascunho anterior deste contrato dizia) — como a requisição agora mora na mesma base do av-hub (contrato SQL 008, não mais só projeção do MES), a FK é segura.

## Perguntas em aberto (levar para o Gustavo antes de aplicar)

1. **`valor_total`/`valor_total_brl` — cálculo no banco ou na aplicação?** O contrato do frontend (seção 3.2, passo 2) pede que o cálculo aconteça "no banco, não confiar no que o cliente mandar" — mas não precisa ser um `GENERATED COLUMN`/trigger SQL necessariamente; pode ser a camada de aplicação recalculando antes do INSERT, desde que nunca aceite o valor calculado pelo frontend sem reconferir. Decisão de implementação, não de schema.
2. **`numero_pedido`** — sequência própria do av-hub (`OC-2026-000123` etc.) ou outro formato? Não fechado ainda.
3. **`aprovado_por`/`motivo_reprovacao`** — falta decidir a ação de permissão (`pode_aprovar` dedicado vs. reaproveitar `pode_editar`), ver seção 3.2 do contrato do frontend (mesmo padrão de pendência já registrado em `ENVIAR - contrato-vagas-fila-decisao-no-banco.md`, V5, no repositório av-hub).
4. **Limite de aprovação (R$ 30.000)** — o contrato do frontend pede que vire parâmetro configurável no banco (`parametros_compras.limite_aprovacao`), não constante fixa. Este contrato **não inclui essa tabela ainda** — avaliar se entra na v1 ou fica pro ciclo 2.
5. **Rateio por departamento** (`departamentos_incluir` do Omie) — fora de escopo desta v1, confirmado no contrato do frontend seção 4. Não modelado aqui.
6. **Catálogo real de condição de pagamento** — hoje `codigo_condicao_pagamento` é texto livre sem formato garantido; a implementação atual usa split igual entre parcelas + 30 dias de intervalo como placeholder (ver seção de implementação acima). Se a Aços Vital precisar de dias/percentual reais por parcela, é preciso desenhar uma tabela de condições de pagamento — feature nova, não ajuste pequeno.

## Depois de criada

- Os 3 endpoints do contrato do frontend (`POST/GET/PATCH /compras/ordens`, `.../ordens/{id}`) passam a gravar/ler daqui, removendo a `GAMBIARRA` de `app/api/compras/ordens/route.ts` e `.../[id]/route.ts` no repositório `av-hub`.
- Desbloqueia o contrato de API [[004-Referencia-OC-Integracao-MES]] (`GET /ordens-compra/referencia`, exposto pelo av-hub para o MES conferir no Recebimento) — esse endpoint lê desta tabela **excluindo** as colunas comerciais (preço, fornecedor, condição de pagamento).

## Ver também
- [[Indice-Contratos]]
- [[008-Requisicoes-Compra]]
- [[004-Pedidos-Compras]] — não confundir; propósito diferente (espelho read-only do Omie)
- [[004-Referencia-OC-Integracao-MES]]
- [[Integracao-AvHub-MES-Especificacao-F1]]
- [[Fluxo-Compras-Completo]]
