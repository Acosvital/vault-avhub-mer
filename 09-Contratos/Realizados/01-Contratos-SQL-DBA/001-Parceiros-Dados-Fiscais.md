---
tags: [contrato-sql, dba, omie-elt-pipeline]
status: aplicada
criado: 2026-09-17
atualizado: 2026-09-22
---

# Contrato SQL 001 (antes 006 no omie-elt-pipeline) — `core.parceiros` (dados fiscais) + 2 tabelas novas

**Status: aplicada.** Confirmado contra o dump de produção `dump-avhub_prd_db-202609210741.sql` (21/09/2026) — ver [[Auditoria-Dump-Producao-2026-09-21]]. `core.parceiros` já tem todas as colunas propostas; `core.parceiros_dados_bancarios` e `core.parceiros_endereco_entrega` já existem como tabelas 1:1 com FK CASCADE, e os models Sequelize correspondentes já estão em uso. Diferenças confirmadas contra o proposto abaixo: `dadosBancarios`/`enderecoEntrega` são servidos por endpoint próprio (não só embutidos em `ListarClientes` — resolve a pergunta aberta 1 original), e `chave_pix` foi ajustada para `varchar(255)` (não os `varchar(100)` propostos na pergunta aberta 3). Seção original abaixo preservada como histórico de design.

<details>
<summary>Texto original da proposta (17/09/2026), antes da confirmação em produção</summary>

**Status:** proposta, aguardando revisão e aplicação pelo DBA (Gustavo).
Nada aplicado ainda — o `omie-elt-pipeline` nunca altera schema sozinho.
Design ainda **não fechado com o usuário** (ao contrário do contrato 005,
já aplicado) — os tipos/tamanhos abaixo vêm da documentação pública da API
(`developer.omie.com.br`, endpoint "Clientes, Fornecedores, Transportadoras,
etc" → `clientes_cadastro`), não de um payload real confirmado contra a
conta de produção. Confirmar contra um payload real antes de aplicar (ver
seção final).

</details>

**Repositório de origem:** `omie-elt-pipeline` (`sql/dba_migrations/006_parceiros_dados_fiscais_contrato.md`).

## Por quê

Hoje `core.parceiros` só grava um subconjunto do que `ListarClientes` já
devolve na mesma chamada que o pipeline já faz (`parceiros.ts`) — dado
fiscal completo (IE, IM, Suframa, regime tributário, CNAE), endereço de
entrega separado do fiscal, e dados bancários ficam de fora hoje. Isso foi
levantado como lacuna crítica: no dia em que o sistema próprio precisar
emitir nota fiscal sem depender do Omie, falta o dado fiscal básico do
parceiro. Nenhuma chamada de API nova — é o mesmo `ListarClientes` já em
produção, só ampliando `mapRow`.

## Campos do Omie envolvidos (referência, de `clientes_cadastro`)

```
inscricao_estadual        string(20)
inscricao_municipal       string(20)
inscricao_suframa         string(20)
optante_simples_nacional  string(1)   -- "S"/"N"
contribuinte               string(1)   -- "S"/"N", contribuinte de ICMS
cnae                       string(7)
tipo_atividade             string(1)
pessoa_fisica              string(1)   -- "S"/"N"
produtor_rural             string(1)   -- "S"/"N"
cidade_ibge                string(7)
valor_limite_credito       decimal
bloquear_faturamento       string(1)   -- "S"/"N"
inativo                    string(1)   -- "S"/"N"
enderecoEntrega { razao_social, cnpj_cpf, endereco, endereco_numero,
                   complemento, bairro, cidade, estado, cep, codigo_pais,
                   inscricao_estadual }
dadosBancarios { codigo_banco, codigo_agencia, conta_corrente,
                  titular_nome, titular_cpf_cnpj, chave_pix, tipo_chave_pix }
```

## DDL

```sql
-- Ampliação de core.parceiros
ALTER TABLE core.parceiros
  ADD COLUMN inscricao_estadual     varchar(20),
  ADD COLUMN inscricao_municipal    varchar(20),
  ADD COLUMN inscricao_suframa      varchar(20),
  ADD COLUMN optante_simples_nacional boolean,
  ADD COLUMN contribuinte_icms      boolean,
  ADD COLUMN cnae                   varchar(7),
  ADD COLUMN tipo_atividade         varchar(1),
  ADD COLUMN pessoa_fisica          boolean,
  ADD COLUMN produtor_rural         boolean,
  ADD COLUMN cidade_ibge            varchar(7),
  ADD COLUMN valor_limite_credito   numeric(14,2),
  ADD COLUMN bloquear_faturamento   boolean NOT NULL DEFAULT false,
  ADD COLUMN inativo                boolean NOT NULL DEFAULT false;

-- Endereço de entrega (1:1 com parceiro — Omie só manda um por cliente)
CREATE TABLE core.parceiros_endereco_entrega (
  id                uuid PRIMARY KEY DEFAULT uuidv7(),
  id_parceiro       uuid NOT NULL REFERENCES core.parceiros(id)
                      ON UPDATE CASCADE ON DELETE CASCADE,
  razao_social      varchar(60),
  cnpj_cpf          varchar(20),
  inscricao_estadual varchar(20),
  logradouro        varchar(60),
  numero            varchar(60),
  complemento       varchar(60),
  bairro            varchar(60),
  cidade            varchar(40),
  estado            varchar(2),
  cep               varchar(10),
  created_at        timestamptz NOT NULL DEFAULT now(),
  created_by        uuid,
  updated_at        timestamptz NOT NULL DEFAULT now(),
  updated_by        uuid
);

CREATE UNIQUE INDEX uq_parceiros_endereco_entrega_parceiro
  ON core.parceiros_endereco_entrega (id_parceiro);

CREATE TRIGGER trg_parceiros_endereco_entrega_updated_at
  BEFORE UPDATE ON core.parceiros_endereco_entrega
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Dados bancários (1:1 com parceiro, mesmo padrão)
CREATE TABLE core.parceiros_dados_bancarios (
  id                uuid PRIMARY KEY DEFAULT uuidv7(),
  id_parceiro       uuid NOT NULL REFERENCES core.parceiros(id)
                      ON UPDATE CASCADE ON DELETE CASCADE,
  codigo_banco      varchar(10),
  codigo_agencia    varchar(15),
  conta_corrente    varchar(20),
  titular_nome      varchar(100),
  titular_cpf_cnpj  varchar(20),
  chave_pix         varchar(100),
  tipo_chave_pix    varchar(20),
  created_at        timestamptz NOT NULL DEFAULT now(),
  created_by        uuid,
  updated_at        timestamptz NOT NULL DEFAULT now(),
  updated_by        uuid
);

CREATE UNIQUE INDEX uq_parceiros_dados_bancarios_parceiro
  ON core.parceiros_dados_bancarios (id_parceiro);

CREATE TRIGGER trg_parceiros_dados_bancarios_updated_at
  BEFORE UPDATE ON core.parceiros_dados_bancarios
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

**Sem FK de `parceiros_endereco_entrega`/`parceiros_dados_bancarios` para
fora de `core.parceiros`** — mesmo princípio do contrato rejeitado
`003_produto_vendas_fks.sql` do próprio pipeline, mas aqui a FK é segura
porque a linha filha só é gravada **depois** do upsert do parceiro pai, na
mesma transação (mesmo padrão de `core.parceiros_tipos`).

## Perguntas em aberto (levar para o Gustavo antes de aplicar)

1. `dadosBancarios`/`enderecoEntrega` no Omie: confirmar se realmente vêm
   sempre no payload de `ListarClientes` ou só em `ConsultarCliente` — a doc
   pública não deixa isso explícito. Se só vier no `Consultar`, o
   `dateWindowParams`/`fullSyncParams` de `parceiros.ts` precisaria de um
   `getMethod` extra por parceiro (custo de rate limit maior).
2. `contribuinte` foi renomeado para `contribuinte_icms` na coluna — confirmar
   se esse nome bate com alguma convenção já usada em `core_vendas_faturamento`
   antes de aplicar (evitar inconsistência com nome já usado em outra tabela).
3. Tamanho de `chave_pix` (`varchar(100)`) é um chute conservador — a doc do
   Omie não documenta tamanho máximo explícito para esse campo.

## Depois de criada

Avisar o dev para ampliar `parceiros.ts` (`mapRow` + `afterUpsert` com um
segundo `insertIfNotExists` para cada tabela filha, mesmo padrão já usado
para `core.parceiros_tipos`).

## Ver também
- [[Indice-Contratos]]
- [[002-Estoque-Saldo]]
- [[Auditoria-Dump-Producao-2026-09-21]]
