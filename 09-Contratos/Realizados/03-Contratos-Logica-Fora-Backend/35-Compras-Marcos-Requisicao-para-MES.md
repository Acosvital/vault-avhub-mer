---
tags: [contrato-sql, contrato-api, compras, integracao-mes, torre-de-fluxo]
criado: 2026-10-02
status: aplicada
---

# Contrato 35 — Compras: marcos da requisição de compra (av-hub → MES)

> **✅ ENTREGUE (02/10/2026).** O DBA aplicou o apêndice A na `api-test` e o código entrou na `develop` (`0a65491`, a partir do patch `35-anexos/0003`). Conferido na `api-test`: `GET /compras/requisicoes/eventos` sem `alterado_desde` → 400; uma requisição de teste com `id_origem` (REQ-000003, "TESTE CONTRATO 35 - APAGAR", ficou cancelada) gerou `requisicao_recebida`; cancelar sem motivo → 400; com motivo → 200 e evento `requisicao_cancelada` com `origem = compras`. Front: av-hub#117 (verificado na tela no local). Falta: o Robert ligar a leitura no MES. **Antes de produção:** SQL antes da API.

> **Situação em 02/10/2026: implementado e testado no local.** SQL (apêndice A) aplicado no banco local
> (`omie-test-db`) e testado pelo roteiro `35-anexos/0002-roteiro-teste.sql`. API: commit `8eb5dce` na branch
> `feat/contrato-35-marcos-requisicao` (worktree `Desktop/wt-api-contrato-35`, **sem push**), testada por HTTP
> num container local (porta 3005). av-hub: PR Acosvital/av-hub#117 (motivo obrigatório no kanban; compatível
> com o backend atual). Falta: DBA aplicar o apêndice A, subir a API e o Robert ligar a leitura no MES.
> A "migration 034" (`fn_requisicao_mes_aplicar`, contrato 34) não está em nenhum arquivo local: o cancelamento pelo
> MES foi testado por UPDATE direto (sai com `origem = 'mes'`).

**Para:** DBA (Gustavo), backend (`api-acos-vital`) e MES (`api-pcp`, Robert) · **Objetivo:** dar ao MES
os fatos com data e hora de tudo o que acontece em Compras, para medir as sub-etapas de Compras na
**Torre de Fluxo** do sistema.

## 1. Por quê

Hoje o MES manda a requisição ([[34-Requisicoes-MES-Empurra-para-o-Hub]]) e só voltaria a saber dela
quando a OC estivesse aprovada ([[004-Referencia-OC-Integracao-MES]]). O meio do caminho (cotação, OC em
rascunho, aprovação, Omie, confirmação do fornecedor, previsão, despacho, ocorrências — contrato
[[32-Compras-CCP-Acompanhamento-OC]]) e o **cancelamento feito pelo Compras** não chegam ao MES. A parcial
fica parada no setor Compras sem ninguém saber. Não trafega preço, fornecedor nem condição de pagamento.

## 2. Decisões

| # | Pergunta da proposta | Decisão |
|---|---|---|
| 1 | Rota nova ou ampliar o 004? | **Rota nova** (Nathan, 02/10, ao pedir o contrato). O 004 continua só para o Recebimento |
| 2 | Cancelamento pelo Compras devolve a parcial a Requisições? Motivo obrigatório? | **Sim e sim** (Nathan, 02/10, ao mandar aplicar) |
| 3 | Reabrir requisição cancelada continua permitido? | **Sim** (o banco já permite `cancelada → aberta/em_cotacao`); o MES só aceita enquanto a parcial estiver em Requisições |
| 4 | A OC tem reprovação que volta a rascunho? | **Não existe** (conferido no código): reprovar = cancelar com `motivo_reprovacao`. Sai como `oc_cancelada` com `status_anterior = aguardando_aprovacao`; não precisa de `oc_reprovada` |
| 5 | Métrica de Compras na Torre fica no MES? | **Impacto na produção no MES**; produtividade interna no dashboard do av-hub (contrato 31) (Nathan, 02/10) |
| 6 | Leitura a cada 5 min? | Sim, com sobreposição de 2 min no cursor (ver 4) |

## 3. Marcos (`tipo`)

| tipo | Quando | Origem no banco | `ocorrido_em` | `dados` |
|---|---|---|---|---|
| `requisicao_recebida` | requisição do MES nasce | INSERT em `requisicoes_compra` com `id_origem` | `created_at` | `numero_requisicao` |
| `em_cotacao` | comprador começa a cotar | status `aberta → em_cotacao` | agora | — |
| `oc_criada` | item entra numa OC | `ordens_compra_itens.id_requisicao` (ou cabeçalho) | agora | `numero_pedido` |
| `oc_removida` | item sai da OC antes de aprovar (**novo**, não estava na proposta) | item apagado/trocado | agora | `numero_pedido` |
| `oc_enviada_aprovacao` | OC vai para aprovação | OC `aguardando_aprovacao` | agora | — |
| `oc_aprovada` | OC aprovada | OC `aprovado` | `aprovado_em` | `data_previsao_chegada` |
| `oc_no_omie` | OC chega ao Omie | `numero_pedido_omie` preenchido | agora | `numero_pedido_omie` |
| `fornecedor_confirmou` | confirmação ou contraproposta | `ordens_compra_acompanhamento.confirmacao_status` | `confirmado_em` | `confirmacao_status` |
| `previsao_alterada` | nova previsão | INSERT em `ordens_compra_contatos` com `previsao_nova` | `created_at` | `previsao_anterior`, `previsao_nova`, `canal`, `tipo_contato` |
| `despachada` | fornecedor despachou | `despachado_em` | `despachado_em` 00:00 (SP) | `nf_fornecedor`, `transportadora` |
| `ocorrencia` | aberta ou decidida | `ordens_compra_ocorrencias` | `created_at` / `decidido_em` | `id_ocorrencia`, `tipo`, `status` |
| `oc_cancelada` | OC cancelada (inclui reprovação) | OC `cancelado` | `cancelado_em` | `motivo`, `status_anterior` |
| `requisicao_cancelada` | cancelada pelo Compras ou pelo MES | status `→ cancelada` | agora | `origem` (`compras`/`mes`), `motivo` |
| `requisicao_reaberta` | cancelada volta a valer | `cancelada → aberta/em_cotacao` | agora | — |

Só entram requisições com `id_origem` (as do MES). As transições `→ atendida` e `atendida → aberta` não
geram marco próprio: já saem como `oc_criada` e `oc_cancelada`.

## 4. A rota

`GET /compras/requisicoes/eventos?alterado_desde=&apos_id=&codigo_empresa=&limit=` (antes de `/:id`).

| Parâmetro | Regra |
|---|---|
| `alterado_desde` | obrigatório, ISO 8601: eventos com `registrado_em` **maior**, em ordem crescente de (`registrado_em`, `id_evento`) |
| `apos_id` | opcional: desempate quando vários eventos têm o mesmo `registrado_em` |
| `codigo_empresa` | opcional (uuid) |
| `limit` | padrão 200, máximo 500 |

Resposta: `{ quantidade, tem_mais, proximo: { alterado_desde, apos_id }, data: [ … ] }`, cada evento como
no PDF (`id_evento`, `id_origem`, `id_requisicao`, `numero_requisicao`, `codigo_empresa`, `tipo`,
`ocorrido_em`, `registrado_em`, `status_requisicao`, `ordem_compra {id, numero_pedido, numero_pedido_omie,
situacao}` ou `null`, `dados`). Erros: 400 sem `alterado_desde` ou com data/uuid inválido.

- **Cursor:** uma transação longa pode gravar evento com `registrado_em` anterior ao último lido. O MES
  relê com **2 min de sobreposição** e grava por `id_evento` (idempotente).
- **Chave:** a chave de leitura do MES (a mesma do 004 e do L6 do [[26-Vendas-Liberacao-Pedido]]), não a
  `MES_INTEGRACAO_KEYS` do 34 (só vale para o PUT).
- **Mudança no PATCH `/compras/requisicoes/{id}`:** cancelar passa a exigir `motivo` (3 a 500 caracteres;
  400 sem ele) e grava `motivo_cancelamento` e `cancelada_por_origem = 'compras'`.

## 5. O que o MES faz (Robert)

| Evento | Ação |
|---|---|
| `requisicao_cancelada` origem `compras`, nada recebido | requisição CANCELADA; parcial volta a Requisições com o motivo; aviso ao PCP |
| `requisicao_cancelada`/`oc_cancelada` com parte recebida | só o que falta receber volta a Requisições (split) |
| `oc_cancelada` com requisição de volta a `aberta` | só registra (o Compras vai comprar de novo) |
| `requisicao_cancelada` origem `mes` | confirmação do 34; só registra |
| `requisicao_reaberta` | se a parcial ainda está em Requisições, volta a valer e segue para Compras; senão só registra e avisa |

Métricas na Torre (MES): tempo por sub-etapa (fila do comprador, cotação, aprovação, fornecedor,
trânsito), chegada antes do `prazo_necessidade`, acerto da previsão, cancelamentos e dias de OP parada.

## Apêndice A — SQL (DBA) — testado no banco local em 02/10

Arquivo: `35-anexos/0001-requisicoes-compra-eventos.sql` (aditivo e idempotente; rodado duas vezes sem erro).
Roteiro de teste: `35-anexos/0002-roteiro-teste.sql` (termina em ROLLBACK). Mudanças em relação ao rascunho:
- a imutabilidade de `requisicoes_compra_eventos` aceita o `SET NULL` da FK quando uma OC é apagada de verdade
  (sem isso o DELETE da OC falharia);
- `oc_criada` volta a sair se o item for removido e depois readicionado na mesma OC;
- `oc_removida` não é gravado quando a OC inteira está sendo apagada (a FK falharia);
- `dados` sem chaves nulas (`jsonb_strip_nulls`); índice `(id_requisicao, id_ordem_compra)`.

Observação do teste: a OC nasce `aguardando_aprovacao` e se aprova sozinha abaixo do limite quando o item entra,
então `oc_enviada_aprovacao` e `oc_aprovada` saem logo depois de `oc_criada` nesse caso (é o fluxo real).

```sql
-- Contrato 35 — marcos da requisição de compra (av-hub → MES).
-- Aditivo e idempotente: pode rodar mais de uma vez (CREATE OR REPLACE / IF NOT EXISTS).
-- Testado no banco local (omie-test-db) em 02/10/2026.
BEGIN;

-- A1. Cancelamento com origem e motivo ------------------------------------------------
ALTER TABLE core_vendas_faturamento.requisicoes_compra
  ADD COLUMN IF NOT EXISTS motivo_cancelamento  text,
  ADD COLUMN IF NOT EXISTS cancelada_por_origem varchar(10);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conname = 'requisicoes_compra_cancelada_por_origem_check') THEN
    ALTER TABLE core_vendas_faturamento.requisicoes_compra
      ADD CONSTRAINT requisicoes_compra_cancelada_por_origem_check
      CHECK (cancelada_por_origem IN ('compras','mes'));
  END IF;
END $$;

COMMENT ON COLUMN core_vendas_faturamento.requisicoes_compra.motivo_cancelamento  IS 'Contrato 35: motivo do cancelamento (obrigatório quando o Compras cancela).';
COMMENT ON COLUMN core_vendas_faturamento.requisicoes_compra.cancelada_por_origem IS 'Contrato 35: quem cancelou (compras = PATCH do av-hub; mes = PUT do contrato 34).';

-- Só dois caminhos cancelam: o PATCH do Compras (manda origem 'compras' + motivo) e o PUT
-- do MES (contrato 34, não manda nada => 'mes'). Reabrir limpa os dois campos (o histórico
-- fica nos eventos).
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_requisicoes_compra_cancelamento()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'cancelada' AND OLD.status <> 'cancelada' THEN
    NEW.cancelada_por_origem := COALESCE(NEW.cancelada_por_origem, 'mes');
    IF NEW.cancelada_por_origem = 'compras'
       AND length(btrim(coalesce(NEW.motivo_cancelamento, ''))) < 3 THEN
      RAISE EXCEPTION 'Cancelar a requisição pelo Compras exige motivo' USING ERRCODE = '23514';
    END IF;
  ELSIF OLD.status = 'cancelada' AND NEW.status <> 'cancelada' THEN
    NEW.cancelada_por_origem := NULL;
    NEW.motivo_cancelamento  := NULL;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_requisicoes_compra_cancelamento ON core_vendas_faturamento.requisicoes_compra;
CREATE TRIGGER trg_requisicoes_compra_cancelamento
  BEFORE UPDATE OF status ON core_vendas_faturamento.requisicoes_compra
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_requisicoes_compra_cancelamento();

-- A2. Eventos (só inserção) -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_vendas_faturamento.requisicoes_compra_eventos (
  id                uuid PRIMARY KEY DEFAULT uuidv7(),
  id_requisicao     uuid NOT NULL REFERENCES core_vendas_faturamento.requisicoes_compra(id) ON DELETE CASCADE,
  id_origem         uuid NOT NULL,
  codigo_empresa    uuid NOT NULL,
  tipo              varchar(30) NOT NULL CHECK (tipo IN (
                      'requisicao_recebida','em_cotacao','oc_criada','oc_removida','oc_enviada_aprovacao',
                      'oc_aprovada','oc_no_omie','fornecedor_confirmou','previsao_alterada','despachada',
                      'ocorrencia','oc_cancelada','requisicao_cancelada','requisicao_reaberta')),
  ocorrido_em       timestamptz NOT NULL,
  registrado_em     timestamptz NOT NULL DEFAULT clock_timestamp(),
  status_requisicao varchar(15) NOT NULL,
  id_ordem_compra   uuid REFERENCES core_vendas_faturamento.ordens_compra(id) ON DELETE SET NULL,
  dados             jsonb NOT NULL DEFAULT '{}'::jsonb,
  criado_por        uuid
);
COMMENT ON TABLE core_vendas_faturamento.requisicoes_compra_eventos IS
  'Contrato 35: marcos das requisições vindas do MES, lidos por GET /compras/requisicoes/eventos. Só inserção.';
CREATE INDEX IF NOT EXISTS ix_req_eventos_cursor ON core_vendas_faturamento.requisicoes_compra_eventos (registrado_em, id);
CREATE INDEX IF NOT EXISTS ix_req_eventos_origem ON core_vendas_faturamento.requisicoes_compra_eventos (id_origem, ocorrido_em);
CREATE INDEX IF NOT EXISTS ix_req_eventos_req_oc ON core_vendas_faturamento.requisicoes_compra_eventos (id_requisicao, id_ordem_compra);

-- Histórico: nada muda, exceto o SET NULL da FK quando a OC é apagada de verdade.
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_req_eventos_imutavel()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.id_ordem_compra IS NULL AND OLD.id_ordem_compra IS NOT NULL
     AND (to_jsonb(NEW) - 'id_ordem_compra') = (to_jsonb(OLD) - 'id_ordem_compra') THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'requisicoes_compra_eventos é histórico: só inserção';
END $$;
DROP TRIGGER IF EXISTS trg_req_eventos_imutavel ON core_vendas_faturamento.requisicoes_compra_eventos;
CREATE TRIGGER trg_req_eventos_imutavel BEFORE UPDATE ON core_vendas_faturamento.requisicoes_compra_eventos
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_req_eventos_imutavel();

-- A3. Funções de apoio ------------------------------------------------------------------
-- Grava um evento (ignora requisição sem id_origem); status lido na hora.
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_req_evento(
  p_req uuid, p_tipo text, p_ocorrido timestamptz, p_oc uuid, p_dados jsonb, p_usuario uuid)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE r record;
BEGIN
  SELECT id_origem, codigo_empresa, status INTO r
    FROM core_vendas_faturamento.requisicoes_compra WHERE id = p_req;
  IF NOT FOUND OR r.id_origem IS NULL THEN RETURN; END IF;
  INSERT INTO core_vendas_faturamento.requisicoes_compra_eventos
    (id_requisicao, id_origem, codigo_empresa, tipo, ocorrido_em, status_requisicao, id_ordem_compra, dados, criado_por)
  VALUES (p_req, r.id_origem, r.codigo_empresa, p_tipo, COALESCE(p_ocorrido, now()), r.status, p_oc,
          jsonb_strip_nulls(COALESCE(p_dados, '{}'::jsonb)),
          (SELECT u.id FROM auth.usuarios u WHERE u.id = p_usuario));
END $$;

-- Requisições ligadas a uma OC (itens + cabeçalho).
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_oc_requisicoes(p_oc uuid)
RETURNS SETOF uuid LANGUAGE sql STABLE AS $$
  SELECT id_requisicao FROM core_vendas_faturamento.ordens_compra_itens
   WHERE id_ordem_compra = p_oc AND id_requisicao IS NOT NULL
  UNION
  SELECT id_requisicao FROM core_vendas_faturamento.ordens_compra
   WHERE id = p_oc AND id_requisicao IS NOT NULL
$$;

-- Requisição entrou numa OC: oc_criada + o estado em que a OC já está (a OC nasce antes
-- dos itens). Não repete enquanto a requisição continuar na OC; volta a sair se ela tiver
-- sido removida (oc_removida) e entrar de novo.
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_req_evento_ligar(p_req uuid, p_oc uuid, p_usuario uuid)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE o record;
BEGIN
  IF (SELECT e.tipo FROM core_vendas_faturamento.requisicoes_compra_eventos e
       WHERE e.id_requisicao = p_req AND e.id_ordem_compra = p_oc
         AND e.tipo IN ('oc_criada','oc_removida')
       ORDER BY e.registrado_em DESC, e.id DESC LIMIT 1) = 'oc_criada' THEN
    RETURN;
  END IF;
  SELECT * INTO o FROM core_vendas_faturamento.ordens_compra WHERE id = p_oc;
  PERFORM core_vendas_faturamento.fn_req_evento(p_req, 'oc_criada', NULL, p_oc,
    jsonb_build_object('numero_pedido', o.numero_pedido), p_usuario);
  IF o.status IN ('aguardando_aprovacao','aprovado') THEN
    PERFORM core_vendas_faturamento.fn_req_evento(p_req, 'oc_enviada_aprovacao', NULL, p_oc, NULL, p_usuario);
  END IF;
  IF o.status = 'aprovado' THEN
    PERFORM core_vendas_faturamento.fn_req_evento(p_req, 'oc_aprovada', o.aprovado_em, p_oc,
      jsonb_build_object('data_previsao_chegada', o.data_previsao_chegada), p_usuario);
  END IF;
END $$;

-- A4. Triggers ("zz" no nome: rodam DEPOIS das triggers que já mexem no status) ----------
-- requisicoes_compra: recebida, em_cotacao, cancelada, reaberta
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_requisicoes_compra_zz_eventos()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM core_vendas_faturamento.fn_req_evento(NEW.id, 'requisicao_recebida', NEW.created_at, NULL,
      jsonb_build_object('numero_requisicao', NEW.numero_requisicao), NEW.created_by);
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.status = 'cancelada' THEN
      PERFORM core_vendas_faturamento.fn_req_evento(NEW.id, 'requisicao_cancelada', NULL, NULL,
        jsonb_build_object('origem', NEW.cancelada_por_origem, 'motivo', NEW.motivo_cancelamento), NEW.updated_by);
    ELSIF OLD.status = 'cancelada' THEN
      PERFORM core_vendas_faturamento.fn_req_evento(NEW.id, 'requisicao_reaberta', NULL, NULL, NULL, NEW.updated_by);
    ELSIF OLD.status = 'aberta' AND NEW.status = 'em_cotacao' THEN
      PERFORM core_vendas_faturamento.fn_req_evento(NEW.id, 'em_cotacao', NULL, NULL, NULL, NEW.updated_by);
    END IF;
  END IF;
  RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS trg_requisicoes_compra_zz_eventos ON core_vendas_faturamento.requisicoes_compra;
CREATE TRIGGER trg_requisicoes_compra_zz_eventos AFTER INSERT OR UPDATE OF status
  ON core_vendas_faturamento.requisicoes_compra
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_requisicoes_compra_zz_eventos();

-- ordens_compra_itens: entrou / saiu da OC
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_oc_itens_zz_eventos()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP IN ('DELETE','UPDATE') AND OLD.id_requisicao IS NOT NULL
     AND (TG_OP = 'DELETE' OR OLD.id_requisicao IS DISTINCT FROM NEW.id_requisicao)
     AND OLD.id_requisicao NOT IN (SELECT core_vendas_faturamento.fn_oc_requisicoes(OLD.id_ordem_compra))
     AND EXISTS (SELECT 1 FROM core_vendas_faturamento.ordens_compra WHERE id = OLD.id_ordem_compra) THEN
    PERFORM core_vendas_faturamento.fn_req_evento(OLD.id_requisicao, 'oc_removida', NULL, OLD.id_ordem_compra,
      jsonb_build_object('numero_pedido', (SELECT numero_pedido FROM core_vendas_faturamento.ordens_compra
                                            WHERE id = OLD.id_ordem_compra)), NULL);
  END IF;
  IF TG_OP IN ('INSERT','UPDATE') AND NEW.id_requisicao IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW.id_requisicao IS DISTINCT FROM OLD.id_requisicao) THEN
    PERFORM core_vendas_faturamento.fn_req_evento_ligar(NEW.id_requisicao, NEW.id_ordem_compra, NEW.updated_by);
  END IF;
  RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS trg_oc_itens_zz_eventos ON core_vendas_faturamento.ordens_compra_itens;
CREATE TRIGGER trg_oc_itens_zz_eventos AFTER INSERT OR DELETE OR UPDATE OF id_requisicao
  ON core_vendas_faturamento.ordens_compra_itens
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_oc_itens_zz_eventos();

-- ordens_compra: cabeçalho com requisição, status e chegada no Omie
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ordens_compra_zz_eventos()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_req uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.id_requisicao IS NOT NULL THEN
      PERFORM core_vendas_faturamento.fn_req_evento_ligar(NEW.id_requisicao, NEW.id, NEW.created_by);
    END IF;
    RETURN NULL;
  END IF;
  FOR v_req IN SELECT core_vendas_faturamento.fn_oc_requisicoes(NEW.id) LOOP
    IF NEW.status IS DISTINCT FROM OLD.status THEN
      IF NEW.status = 'aguardando_aprovacao' THEN
        PERFORM core_vendas_faturamento.fn_req_evento(v_req, 'oc_enviada_aprovacao', NULL, NEW.id, NULL, NEW.updated_by);
      ELSIF NEW.status = 'aprovado' THEN
        PERFORM core_vendas_faturamento.fn_req_evento(v_req, 'oc_aprovada', NEW.aprovado_em, NEW.id,
          jsonb_build_object('data_previsao_chegada', NEW.data_previsao_chegada), NEW.aprovado_por);
      ELSIF NEW.status = 'cancelado' THEN
        PERFORM core_vendas_faturamento.fn_req_evento(v_req, 'oc_cancelada', NEW.cancelado_em, NEW.id,
          jsonb_build_object('motivo', NEW.motivo_reprovacao, 'status_anterior', OLD.status), NEW.cancelado_por);
      END IF;
    END IF;
    IF NEW.numero_pedido_omie IS NOT NULL AND OLD.numero_pedido_omie IS NULL THEN
      PERFORM core_vendas_faturamento.fn_req_evento(v_req, 'oc_no_omie', NULL, NEW.id,
        jsonb_build_object('numero_pedido_omie', NEW.numero_pedido_omie), NULL);
    END IF;
  END LOOP;
  RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS trg_ordens_compra_zz_eventos ON core_vendas_faturamento.ordens_compra;
CREATE TRIGGER trg_ordens_compra_zz_eventos AFTER INSERT OR UPDATE OF status, numero_pedido_omie
  ON core_vendas_faturamento.ordens_compra
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_ordens_compra_zz_eventos();

-- Acompanhamento (contrato 32): confirmação e despacho
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_oc_acompanhamento_zz_eventos()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_req uuid;
BEGIN
  FOR v_req IN SELECT core_vendas_faturamento.fn_oc_requisicoes(NEW.id_ordem_compra) LOOP
    IF NEW.confirmacao_status <> 'pendente'
       AND (TG_OP = 'INSERT' OR NEW.confirmacao_status IS DISTINCT FROM OLD.confirmacao_status) THEN
      PERFORM core_vendas_faturamento.fn_req_evento(v_req, 'fornecedor_confirmou', NEW.confirmado_em, NEW.id_ordem_compra,
        jsonb_build_object('confirmacao_status', NEW.confirmacao_status), NEW.confirmado_por);
    END IF;
    IF NEW.despachado_em IS NOT NULL
       AND (TG_OP = 'INSERT' OR NEW.despachado_em IS DISTINCT FROM OLD.despachado_em) THEN
      PERFORM core_vendas_faturamento.fn_req_evento(v_req, 'despachada',
        NEW.despachado_em::timestamp AT TIME ZONE 'America/Sao_Paulo', NEW.id_ordem_compra,
        jsonb_build_object('nf_fornecedor', NEW.nf_fornecedor, 'transportadora', NEW.transportadora), NULL);
    END IF;
  END LOOP;
  RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS trg_oc_acompanhamento_zz_eventos ON core_vendas_faturamento.ordens_compra_acompanhamento;
CREATE TRIGGER trg_oc_acompanhamento_zz_eventos AFTER INSERT OR UPDATE
  ON core_vendas_faturamento.ordens_compra_acompanhamento
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_oc_acompanhamento_zz_eventos();

-- Contatos com o fornecedor (contrato 32): nova previsão
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_oc_contatos_zz_eventos()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_req uuid;
BEGIN
  IF NEW.previsao_nova IS NULL THEN RETURN NULL; END IF;
  FOR v_req IN SELECT core_vendas_faturamento.fn_oc_requisicoes(NEW.id_ordem_compra) LOOP
    PERFORM core_vendas_faturamento.fn_req_evento(v_req, 'previsao_alterada', NEW.created_at, NEW.id_ordem_compra,
      jsonb_build_object('previsao_anterior', NEW.previsao_anterior, 'previsao_nova', NEW.previsao_nova,
                         'canal', NEW.canal, 'tipo_contato', NEW.tipo), NEW.created_by);
  END LOOP;
  RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS trg_oc_contatos_zz_eventos ON core_vendas_faturamento.ordens_compra_contatos;
CREATE TRIGGER trg_oc_contatos_zz_eventos AFTER INSERT ON core_vendas_faturamento.ordens_compra_contatos
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_oc_contatos_zz_eventos();

-- Ocorrências (contrato 32): aberta ou decidida
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_oc_ocorrencias_zz_eventos()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_req uuid;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NULL; END IF;
  FOR v_req IN SELECT core_vendas_faturamento.fn_oc_requisicoes(NEW.id_ordem_compra) LOOP
    PERFORM core_vendas_faturamento.fn_req_evento(v_req, 'ocorrencia',
      CASE WHEN TG_OP = 'INSERT' THEN NEW.created_at ELSE NEW.decidido_em END, NEW.id_ordem_compra,
      jsonb_build_object('id_ocorrencia', NEW.id, 'tipo', NEW.tipo, 'status', NEW.status),
      CASE WHEN TG_OP = 'INSERT' THEN NEW.created_by ELSE NEW.decidido_por END);
  END LOOP;
  RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS trg_oc_ocorrencias_zz_eventos ON core_vendas_faturamento.ordens_compra_ocorrencias;
CREATE TRIGGER trg_oc_ocorrencias_zz_eventos AFTER INSERT OR UPDATE OF status
  ON core_vendas_faturamento.ordens_compra_ocorrencias
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_oc_ocorrencias_zz_eventos();

-- A5. Retroativo: requisições do MES que já existem ganham o marco de chegada ------------
INSERT INTO core_vendas_faturamento.requisicoes_compra_eventos
  (id_requisicao, id_origem, codigo_empresa, tipo, ocorrido_em, status_requisicao, dados)
SELECT r.id, r.id_origem, r.codigo_empresa, 'requisicao_recebida', r.created_at, r.status,
       jsonb_build_object('numero_requisicao', r.numero_requisicao, 'retroativo', true)
  FROM core_vendas_faturamento.requisicoes_compra r
 WHERE r.id_origem IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM core_vendas_faturamento.requisicoes_compra_eventos e
                    WHERE e.id_requisicao = r.id AND e.tipo = 'requisicao_recebida');

COMMIT;
```

**Antes de aplicar:** conferir o papel do banco usado pela API em produção (as funções gravam em
`requisicoes_compra_eventos` dentro das triggers; o papel precisa de INSERT nela, ou as funções viram
`SECURITY DEFINER`). **Ordem de deploy:** SQL antes da API (o model passa a ler `motivo_cancelamento` e
`cancelada_por_origem`).

## Aceite

- [x] Apêndice A aplicado no local e testado: cada marco aparece uma vez, com `ocorrido_em` certo, mesmo
      com dois passos entre duas leituras.
- [x] Rota e mudança no PATCH implementadas e testadas (400 sem `alterado_desde`; cancelar sem motivo = 400).
- [ ] Cancelar no av-hub faz a parcial voltar a Requisições no MES, com o motivo.
- [x] Nenhum evento traz preço, fornecedor ou condição de pagamento; requisição manual (sem `id_origem`)
      não aparece.

## Ver também
- [[34-Requisicoes-MES-Empurra-para-o-Hub]] · [[004-Referencia-OC-Integracao-MES]] ·
  [[32-Compras-CCP-Acompanhamento-OC]] · [[31-Compras-Dashboard]] · [[Indice-Contratos]]
