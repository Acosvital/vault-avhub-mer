---
id: SQL-008
aliases: ["Contrato SQL 008", "008-Requisicoes-Compra"]
tags: [contrato, contrato-sql, dba, integracao-av-hub-mes, compras]
criado: 2026-10-14
atualizado: 2026-10-14
status: aplicado-em-producao
dono: "Gustavo (DBA)"
etapa_0b: [P3, C0]
fontes: ["Dump Avhub (Esqueleto).sql:8680", "api-acos-vital/src/schemas/core_vendas_faturamento/tables/requisicoes_compra/requisicoes_compra.route.js:148-413"]
criado_original: 2026-09-22
---

# Contrato SQL 008 — `core_vendas_faturamento.requisicoes_compra` (novo)

> [!info] Situação em 14/10/2026
> **Status:** `aplicado-em-producao` · **Pasta:** `Entregues` · **Nós do 0b:** P3, C0 · **Dono:** Gustavo (DBA)
>
> - ✅ Tabela `requisicoes_compra` e `fn_requisicao_mes_aplicar` (`Dump Avhub (Esqueleto).sql:8680`) existem; rotas em `requisicoes_compra.route.js:148-413`. Entregue em `ec2a42b` (PR #273); a coluna `id_origem` e os eventos vieram com [[LOG-34-Requisicoes-MES-Empurra-para-o-Hub]] e [[LOG-35-Compras-Marcos-Requisicao-para-MES]].
> - Status da requisição: `aberta`, `em_cotacao`, `atendida`, `cancelada`; `atendida` é marcada pela trigger da OC, nunca pelo PATCH.
> - ❓ Produção: confirmado em 23/09 (vault v1); não reconferido.
>
> Conferido em 14/10/2026 contra `api-pcp` 579a625, `app-pcp` 1fca8d3, `api-acos-vital` f322dcd, `omie-elt-pipeline` 0f739f0 e os dumps de 14/10. O front do av-hub (HUB b55ac55) só pelo vault v1 (❓).
> O texto original abaixo está inteiro; os trechos que o estado atual contradiz têm nota de rodapé.


**Status: aplicada — confirmado em 23/09/2026.** Entregue em `api-acos-vital` (commit `ec2a42b`, PR #273, mergeado em `main` em 22/09) junto com o [[SQL-007-Ordens-Compra-Estruturada|007-Ordens-Compra-Estruturada]]. O av-hub já está ligado nele (branch `feat/compras-integracao-backend`), e as leituras e a validação de status foram confirmadas ao vivo em `api-test`. Produção não foi conferida.

**O que foi aplicado difere do DDL abaixo** (o DDL fica como histórico; vale o que está no banco):

| No DDL deste contrato | Como ficou aplicado |
|---|---|
| `id_ordem_compra` | `ordem_compra_id` |
| `material varchar(60)` nullable | `text NOT NULL` |
| `prazo_necessidade date NOT NULL` | **nullable**; sem prazo vai para o fim da fila |
| `solicitante varchar(100)` | `text` |
| `quantidade numeric(14,3)` | `numeric(15,4)` |
| `id_origem` (id do lado do MES) | **não está no model da API**: conferir se existe no banco antes da integração com o MES ([[API-003-Requisicao-Compra-Integracao-MES|003-Requisicao-Compra-Integracao-MES]]) |
| transições validadas "no backend" | validadas **por trigger no banco**: `aberta ↔ em_cotacao ↔ cancelada`; `atendida` só pela trigger da OC (emitir marca `atendida`, cancelar a OC devolve para `aberta`) |
| `numero_requisicao` sempre do MES | na criação manual, a API gera `REQ-000001` por unidade quando não vem no corpo |

**Correção de 30/09/2026** (conferido na `develop` da API, `36940ed`): duas linhas da tabela acima ficaram velhas depois do [[LOG-13a-Compras-Backend-Consolidado|13-Compras-Backend-Consolidado]] (`bf9d86a`). O **`id_origem` está no model** e o `POST /compras/requisicoes` o aceita (é a chave de idempotência do job do MES), e o **`prazo_necessidade` voltou a ser obrigatório**. Também existe `numero_requisicao_mes` (índice não único). Formato do número do MES: `RC-AAAAMMDD-NNNN`, repetido nos itens da mesma requisição (pergunta 1 respondida, ver [[API-003-Requisicao-Compra-Integracao-MES|003-Requisicao-Compra-Integracao-MES]]).

**Reconferência de 08/10/2026 (model da API na `develop` `0557871`, `requisicoes_compra.model.js`):** o model declara `id_ordem_compra` (não `ordem_compra_id`), `quantidade` `DECIMAL(14,3)` (não `numeric(15,4)`), `solicitante` `STRING(100)` (não `text`) e `prazo_necessidade` `NOT NULL`; `id_origem`, `numero_requisicao_mes`, `motivo_cancelamento` e `cancelada_por_origem` existem. A tabela acima (23/09) diverge do model em três pontos (nome da coluna da OC, precisão da quantidade, tipo do solicitante). Como as migrations não estão no repositório da API, **a divergência só se resolve conferindo o banco**: ou a tabela de 23/09 está velha, ou o model não reflete o DDL.

**Pergunta 2 (ordem de aplicação com o 007):** resolvida, porque os dois foram aplicados juntos. A **pergunta 1** (formato do número vindo do MES) foi respondida em 30/09 (acima).

**Status original:** proposta, aprovada por Nathan em 22/09/2026,[^c1] alinhada campo a campo com `docs/ENVIAR - contrato-compras-fluxo-completo.md` (repositório `av-hub`, 21/09/2026) e com `lib/domain/compras-requisicao.ts` (domínio TypeScript já implementado no frontend, hoje rodando sobre dados de exemplo).

**✅ Backend implementado e testado em 22/09/2026** (`GET/POST/PATCH /compras/requisicoes`, `.../requisicoes/{id}`, branch local `feat/compras-requisicoes-e1` em `api-acos-vital`) — DDL abaixo aplicado e validado no ambiente de teste local. **Ainda não deployado em produção nem enviado ao remoto** — aguardando o Gustavo aplicar este contrato de fato em produção.

## Por quê

`app/(protected)/compras/requisicoes` (caixa de entrada do comprador) e `app/(protected)/compras/requisicoes/kanban` já estão prontos no frontend, junto com `GET/POST/PATCH /compras/requisicoes` no BFF (`app/api/compras/requisicoes/route.ts`, `.../[id]/route.ts`) — hoje toda a tela roda sobre `REQUISICOES_EXEMPLO` (`lib/compras/dados.ts`) porque este endpoint não existe no backend real. Esta tabela é o que falta.

**Relação com o "casamento av-hub↔MES"** ([[Integracao-AvHub-MES|Integracao-AvHub-MES-Especificacao-F1]], contrato de API [[API-003-Requisicao-Compra-Integracao-MES|003-Requisicao-Compra-Integracao-MES]]): a requisição nasce de verdade no MES; esta tabela é a **projeção local no av-hub** que o job de polling do contrato 003 mantém atualizada — o mesmo papel que o contrato 003 já previa ("tabela local de projeção... a definir em contrato SQL próprio"), agora definido. O `POST`/`PATCH` diretos nesta tabela (seções abaixo) cobrem só os casos excepcionais em que o próprio av-hub cria ou transiciona uma requisição sem que o MES tenha feito isso primeiro.

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

1. **`numero_requisicao` gerado pelo MES** — formato exato ainda não especificado pelo lado do MES (contrato de API [[API-003-Requisicao-Compra-Integracao-MES|003-Requisicao-Compra-Integracao-MES]], pergunta aberta 2 daquele contrato). Este campo aqui é só `varchar(30)`, sem assumir formato.
2. **Ordem de aplicação**: este contrato (008) e o [[SQL-007-Ordens-Compra-Estruturada|007-Ordens-Compra-Estruturada]] têm uma referência cruzada (`ordens_compra.id_requisicao` → `requisicoes_compra.id`, e `requisicoes_compra.id_ordem_compra` → `ordens_compra.id`) — **aplicar os dois na mesma migration/transação**, ou criar as FKs em uma segunda `ALTER TABLE` depois que ambas existirem, para não travar por ordem de criação.

## Depois de criada

- Os 3 endpoints do contrato do frontend (`GET/POST/PATCH /compras/requisicoes`, `.../requisicoes/{id}`) passam a gravar/ler daqui, removendo a `GAMBIARRA` de `app/api/compras/requisicoes/route.ts` e `.../[id]/route.ts` no repositório `av-hub`.
- Desbloqueia a implementação real do contrato de API [[API-003-Requisicao-Compra-Integracao-MES|003-Requisicao-Compra-Integracao-MES]] (job de polling que projeta as requisições do MES para esta tabela).

## Ver também
- [[HIST-Indice-Contratos|Indice-Contratos]]
- [[SQL-007-Ordens-Compra-Estruturada|007-Ordens-Compra-Estruturada]]
- [[API-003-Requisicao-Compra-Integracao-MES|003-Requisicao-Compra-Integracao-MES]]
- [[04-Circuito-de-Compra|Fluxo-Compras-Completo]]

[^c1]: Nota de 14/10/2026: Superado: aplicada, ver a Situação em 14/10 no topo.
