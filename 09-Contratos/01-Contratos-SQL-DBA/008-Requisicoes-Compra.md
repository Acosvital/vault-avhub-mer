---
tags: [contrato-sql, dba, integracao-av-hub-mes, compras]
status: proposta
criado: 2026-09-22
---

# Contrato SQL 008 — `core_vendas_faturamento.requisicoes_compra` (novo)

**Status:** proposta, aprovada por Nathan em 22/09/2026, alinhada campo a campo com `docs/ENVIAR - contrato-compras-fluxo-completo.md` (repositório `av-hub`, 21/09/2026) e com `lib/domain/compras-requisicao.ts` (domínio TypeScript já implementado no frontend, hoje rodando sobre dados de exemplo).

**✅ Backend implementado e testado em 22/09/2026** (`GET/POST/PATCH /compras/requisicoes`, `.../requisicoes/{id}`, branch local `feat/compras-requisicoes-e1` em `api-acos-vital`) — DDL abaixo aplicado e validado no ambiente de teste local. **Ainda não deployado em produção nem enviado ao remoto** — aguardando o Gustavo aplicar este contrato de fato em produção.

## Por quê

`app/(protected)/compras/requisicoes` (caixa de entrada do comprador) e `app/(protected)/compras/requisicoes/kanban` já estão prontos no frontend, junto com `GET/POST/PATCH /compras/requisicoes` no BFF (`app/api/compras/requisicoes/route.ts`, `.../[id]/route.ts`) — hoje toda a tela roda sobre `REQUISICOES_EXEMPLO` (`lib/compras/dados.ts`) porque este endpoint não existe no backend real. Esta tabela é o que falta.

**Relação com o "casamento av-hub↔MES"** ([[Integracao-AvHub-MES-Especificacao-F1]], contrato de API [[003-Requisicao-Compra-Integracao-MES]]): a requisição nasce de verdade no MES; esta tabela é a **projeção local no av-hub** que o job de polling do contrato 003 mantém atualizada — o mesmo papel que o contrato 003 já previa ("tabela local de projeção... a definir em contrato SQL próprio"), agora definido. O `POST`/`PATCH` diretos nesta tabela (seções abaixo) cobrem só os casos excepcionais em que o próprio av-hub cria ou transiciona uma requisição sem que o MES tenha feito isso primeiro.

## DDL

```sql
CREATE TABLE core_vendas_faturamento.requisicoes_compra (
  id                    uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa        uuid NOT NULL REFERENCES core.unidades(id)
                          ON UPDATE CASCADE ON DELETE RESTRICT,
  numero_requisicao     varchar(30) NOT NULL,   -- gerado pelo MES quando a origem é lá;
                                                  -- gerado pelo av-hub no caso excepcional de
                                                  -- criação manual (POST direto, sem MES)
  material              varchar(60),             -- projeção de core.produtos, sem FK
  descricao             text,
  quantidade            numeric(14,3) NOT NULL,
  unidade_medida        varchar(10) NOT NULL,
  prazo_necessidade     date NOT NULL,
  acabado_sugerido      boolean,                 -- null = MES não informou; comprador confirma/troca
                                                   -- ao emitir a OC (não altera este campo)
  status                varchar(15) NOT NULL DEFAULT 'aberta',
                          -- 'aberta' | 'em_cotacao' | 'atendida' | 'cancelada'
  solicitante           varchar(100),
  observacao            text,
  id_ordem_compra       uuid REFERENCES core_vendas_faturamento.ordens_compra(id)
                          ON UPDATE CASCADE ON DELETE SET NULL,
                          -- preenchido só quando uma OC nasce a partir desta requisição;
                          -- o backend marca isso automaticamente ao criar a OC (nunca via
                          -- PATCH direto do frontend), e desfaz (volta a null) se a OC for
                          -- reprovada/cancelada — "nenhum estado é beco sem saída"
  id_origem             uuid,     -- id_requisicao do lado do MES, referência lógica sem FK
                                   -- (banco separado — mesmo princípio de sempre)
  created_at            timestamptz NOT NULL DEFAULT now(),
  created_by            uuid,
  updated_at            timestamptz NOT NULL DEFAULT now(),
  updated_by            uuid,
  deleted_at            timestamptz,
  deleted_by            uuid,

  CONSTRAINT ck_requisicoes_compra_status
    CHECK (status IN ('aberta','em_cotacao','atendida','cancelada'))
);

CREATE UNIQUE INDEX uq_requisicoes_compra_numero
  ON core_vendas_faturamento.requisicoes_compra (codigo_empresa, numero_requisicao)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_requisicoes_compra_status
  ON core_vendas_faturamento.requisicoes_compra (codigo_empresa, status);

CREATE INDEX idx_requisicoes_compra_origem
  ON core_vendas_faturamento.requisicoes_compra (id_origem);

CREATE TRIGGER trg_requisicoes_compra_updated_at
  BEFORE UPDATE ON core_vendas_faturamento.requisicoes_compra
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

**Matriz de transição de `status`** (a validar no backend, não só no frontend — o Kanban já valida no cliente, mas o `PATCH /compras/requisicoes/{id}` precisa repetir a validação):

| De | Para permitido |
|---|---|
| `aberta` | `em_cotacao`, `cancelada` |
| `em_cotacao` | `aberta`, `cancelada` |
| `cancelada` | `aberta`, `em_cotacao` (reabertura) |
| `atendida` | nenhum via `PATCH` — só o backend marca, automaticamente, ao criar uma OC a partir da requisição |

## Perguntas em aberto (levar para o Gustavo antes de aplicar)

1. **`numero_requisicao` gerado pelo MES** — formato exato ainda não especificado pelo lado do MES (contrato de API [[003-Requisicao-Compra-Integracao-MES]], pergunta aberta 2 daquele contrato). Este campo aqui é só `varchar(30)`, sem assumir formato.
2. **Ordem de aplicação**: este contrato (008) e o [[007-Ordens-Compra-Estruturada]] têm uma referência cruzada (`ordens_compra.id_requisicao` → `requisicoes_compra.id`, e `requisicoes_compra.id_ordem_compra` → `ordens_compra.id`) — **aplicar os dois na mesma migration/transação**, ou criar as FKs em uma segunda `ALTER TABLE` depois que ambas existirem, para não travar por ordem de criação.

## Depois de criada

- Os 3 endpoints do contrato do frontend (`GET/POST/PATCH /compras/requisicoes`, `.../requisicoes/{id}`) passam a gravar/ler daqui, removendo a `GAMBIARRA` de `app/api/compras/requisicoes/route.ts` e `.../[id]/route.ts` no repositório `av-hub`.
- Desbloqueia a implementação real do contrato de API [[003-Requisicao-Compra-Integracao-MES]] (job de polling que projeta as requisições do MES para esta tabela).

## Ver também
- [[Indice-Contratos]]
- [[007-Ordens-Compra-Estruturada]]
- [[003-Requisicao-Compra-Integracao-MES]]
- [[Fluxo-Compras-Completo]]
