# Contrato — Compras: vínculo da ordem de compra com o pedido de venda

**Criado em:** 24/09/2026 · **Para:** DBA, backend (`api-acos-vital`), pipeline e av-hub

Completa `ENVIAR - contrato-compras-backend.md` (item B10) e usa as decisões registradas lá.
**Todo o SQL daqui foi aplicado e testado no banco local, e a API foi implementada e testada na API
local** (branch `feat/compras-contrato`, commit `261b9bc`, 22 testes pela API).

---

## 1. Como é hoje (dados reais, 674 pedidos de compra do espelho)

O comprador liga a compra ao pedido de venda (PV) **à mão**, escrevendo o número no `cNumPedido` do
Omie (que no PDF aparece como "Nº do pedido do fornecedor") e repetindo na observação interna:

| `cNumPedido` | Pedidos | Exemplo |
|---|---|---|
| um PV | 396 (59%) | `28067` |
| vazio (estoque) | 208 | — |
| vários PVs | 41 | `27110/27543/27603/27738/27942` |
| PV + estoque, ou só estoque | 17 | `27769/ESTOQUE` |
| outro texto | 12 | `23966/RECOMPRA`, `27588 (HRM)` |

Dos 396 com um PV, **382 existem na mesma unidade**, 8 são de outra unidade. A observação interna tem
o vendedor em formatos variados ("PV 28204 - LARISSA ALMEIDA", "PEDIDO: 28080 VENDEDOR: YTALLO") e às
vezes divide o valor ("PV 27946 - R$ 25.454,42 ESTOQUE - R$ 10.217,22").

**Como o PV está no banco:** uma linha em `pedidos_vendas` **por parcial**. O sequencial 0 é o resto em
aberto (Pendente) e cada parcial faturada vira um sequencial novo (o 25970 tem 54). Os itens estão em
`produto_vendas`, também por parcial. Por isso o vínculo é por **unidade + número do PV + produto**,
nunca pelo id de uma linha.

## 2. Decisões do Nathan (24/09/2026)

- **A finalidade é escolhida antes de montar a OC:** para **um PV** (digita o número e os itens vêm do
  PV), para **vários PVs** (digita todos, os itens vêm numa lista), **só estoque**, **recompra**
  (reposição de um PV já atendido: material errado, perda, devolução) ou **uso interno**. No modo PV,
  o comprador pode aumentar a quantidade ou pôr itens a mais: **o que não está ligado a PV é estoque.**
- **O item comprado pode ser diferente do vendido.** A linha nasce com o item do PV e o comprador
  troca pelo material que vai comprar; a linha continua ligada ao item do PV. Na fabricação, **vários
  materiais atendem um item vendido**, e **a unidade muda** (vende grade de piso em m², compra barra
  chata em kg e barra redonda em barra).
- **PV de outra unidade pode, escolhendo a unidade.** O da HRM (sem Omie, não está no banco) é aceito
  digitado, marcado como **não conferido**.
- **`cNumPedido` do Omie = número do pedido no fornecedor** (B6). A destinação da OC vai na
  observação interna, no bloco `[AV-HUB]`.
- **Várias requisições do MES numa OC só** (antes, uma por OC).
- **Onde aparece:** no pedido de venda ("Compras deste pedido"), na OC e no PDF interno, e no
  histórico do Omie (compras antigas ligadas pelo `cNumPedido`).

## 3. O modelo

| Onde | O quê |
|---|---|
| `ordens_compra.finalidade` | `pedidos_venda`, `recompra`, `estoque` (padrão), `uso_interno` |
| `ordens_compra_itens_vinculos` (nova) | item da OC → `codigo_empresa_pv` + `numero_pedido_venda` + `codigo_produto_pv` (opcional; `codigo_produto_omie` do item do PV) + `quantidade` **na unidade do item da OC** + `pv_conferido` |
| `ordens_compra_itens.id_requisicao` | a requisição do MES que o item atende (única por item) |
| `vw_pedido_venda_itens_compra` | um item do PV por produto: `quantidade_vendida`, `quantidade_pendente`, `quantidade_em_oc`, `saldo_a_comprar`, `linhas_de_compra` |
| `vw_pedido_venda_compras` | compras de um PV: OCs do av-hub (pelo vínculo) + pedidos de compra antigos do Omie (pelo `cNumPedido`) |

**As contas:**
- vendido = parciais Pendentes + Faturadas (Cancelado, Encerrado e Devolvido ficam fora);
- pendente = parciais ainda não faturadas (**é o que falta entregar**);
- em OC = vínculos de OCs não canceladas **com o mesmo produto** (só aí as unidades batem);
- saldo a comprar = pendente − em OC (nunca negativo);
- linhas de compra = todas as linhas de OC ligadas ao item, de qualquer material (fabricação).

**As travas (triggers, todas testadas):**

| Situação | Resultado |
|---|---|
| OC `estoque`/`uso_interno` com vínculo | recusado: "OC com finalidade "estoque" não se liga a pedido de venda" |
| PV que não existe na unidade | recusado: "Pedido de venda 999999 não existe em Aços Vital" |
| PV de unidade sem Omie (HRM) | aceito com `pv_conferido = false` |
| produto que não está no PV | recusado: "O produto X não está no pedido de venda 28067" |
| vínculos somando mais que o item | recusado: "Vínculos somam 31 PC, mais que a quantidade do item (30 PC)" |
| diminuir o item abaixo do vinculado | recusado |
| mudar a finalidade para estoque com vínculos | recusado |
| requisição que não está na fila, ou de outra unidade | recusado (a HRM pode entrar em OC de Mogi) |
| emitir a OC | todas as requisições dos itens viram `atendida` |
| cancelar ou apagar a OC | **todas** as requisições dela voltam para `aberta` (antes: só a do cabeçalho) |

## 4. API (implementada na API local)

```
POST /compras/ordens
  { ..., "finalidade": "pedidos_venda",
    "itens": [
      { "descricao_produto": "FLANGE LISO SOLTO 3\"", "codigo_produto": "<codigo_produto_omie>",
        "quantidade": 30, "unidade_medida": "PC", "valor_unitario": 50,
        "vinculos": [ { "numero_pedido_venda": "25970", "codigo_produto_pv": "<codigo_produto_omie>", "quantidade": 24 },
                      { "numero_pedido_venda": "27588", "codigo_empresa_pv": "<HRM>", "quantidade": 2 } ] },
      { "descricao_produto": "BARRA CHATA 1.1/4 X 3/16", "quantidade": 850, "unidade_medida": "KG",
        "valor_unitario": 7.2, "id_requisicao": "<uuid>",
        "vinculos": [ { "numero_pedido_venda": "25970", "codigo_produto_pv": "<...>", "quantidade": 850 } ] },
      { "descricao_produto": "BARRA REDONDA 5/16", "quantidade": 40, "unidade_medida": "BR", "valor_unitario": 38 }
    ] }
  → tudo numa transação; codigo_empresa_pv padrão = unidade da OC.
    400 se finalidade com PV sem nenhum vínculo, ou estoque/uso interno com vínculo.

GET /compras/ordens/{id}           → itens[].vinculos[] e itens[].id_requisicao
GET /compras/ordens?finalidade=      → filtro

GET /compras/pedidos-venda/{numero}?codigo_empresa=
  → { numero_pedido, filial, nome_cliente, nome_vendedor, data_inclusao, tem_pendente, encontrado,
      itens: [ { codigo_produto_omie, codigo_produto, descricao, unidade_medida, quantidade_vendida,
                 quantidade_pendente, quantidade_em_oc, saldo_a_comprar, linhas_de_compra } ] }
    404 se não existe; unidade sem Omie (HRM) → 200 com encontrado: false e aviso.

GET /compras/pedidos-venda/{numero}/compras?codigo_empresa=
  → { total, data: [ { origem: "av-hub"|"omie", numero_compra, status, nome_fornecedor,
                       data_previsao_chegada, descricao_produto, quantidade_vinculada, unidade_medida, … } ] }
```

`codigo_produto` do item da OC = `codigo_produto_omie` (é o que vai no `nCodProd` do Omie, B12). É
isso que permite o saldo quando o produto comprado é o mesmo do vendido.

## 5. Omie (pipeline, L4)

- `cNumPedido` ← `numero_pedido_fornecedor` (não mais o PV).
- No bloco `[AV-HUB]` do `cObsInt`, uma linha de **destinação**, gerada dos vínculos. Ex.:
  `Destino: PV 25970 (PROSPER MINERACAO · DIEGO JOSE ARANTES): 24 PC flange, 850 KG barra chata · PV
  27588 HRM (não conferido): 2 PC · estoque: 6 PC flange, 40 BR barra redonda`. Para `estoque`,
  `uso_interno` ou `recompra`, a finalidade por extenso ("Recompra do PV 25970").
- As compras antigas continuam ligadas pelo `cNumPedido` (a view ignora as que nasceram de OC do
  av-hub, `codigo_pedido_integracao` "OC-…").

## 6. av-hub (telas)

1. **Emitir OC:** primeiro passo escolhe a finalidade. Em "pedidos de venda", campo para digitar um
   ou mais PVs (com a unidade, padrão = da OC). Cada PV carrega os itens pendentes com o saldo a
   comprar; o comprador marca o que compra, pode trocar o material (a linha fica ligada ao item do
   PV), mudar a quantidade e dividir: "24 para o PV, 6 para estoque". Linha nova sem PV = estoque.
2. **Detalhe da OC e PDF interno:** cada item mostra para qual PV/cliente/vendedor vai. O PDF que vai
   ao **fornecedor** não mostra cliente.
3. **Pedido de venda** (Pedidos, PCP, Meus pedidos): seção "Compras deste pedido", com OC, fornecedor,
   previsão de chegada, situação e o que foi comprado, incluindo as compras antigas do Omie.
4. **Requisições:** marcar várias e "Gerar uma OC com as selecionadas".

## 7. Pendente

- **A requisição do MES já sabe o PV** (pela ordem de produção)? Se souber, a requisição ganha
  `codigo_empresa_pv`/`numero_pedido_venda` e a OC herda o vínculo sozinha. **Perguntar ao Nathan.**
- Aplicar o Apêndice A no teste (DBA) e levar a API (`feat/compras-contrato`) para a `develop`.

---

## Apêndice A — SQL

Depende dos Apêndices A–C de `ENVIAR - contrato-compras-backend.md` (usa `id_unidade_compra`).

```sql
-- =============================================================================
-- Vínculo da OC com o pedido de venda (contrato compras-vinculo-pedido-venda)
-- Pressupõe os Apêndices A–C do contrato compras-backend.
-- Testado no banco local em 24/09/2026. Uma transação só.
-- =============================================================================
BEGIN;

-- -----------------------------------------------------------------------------
-- V1. Finalidade da OC: escolhida ANTES de montar a OC
-- -----------------------------------------------------------------------------
ALTER TABLE core_vendas_faturamento.ordens_compra
  ADD COLUMN finalidade varchar(15) NOT NULL DEFAULT 'estoque'
  CONSTRAINT ck_ordens_compra_finalidade
    CHECK (finalidade IN ('pedidos_venda', 'estoque', 'recompra', 'uso_interno'));
COMMENT ON COLUMN core_vendas_faturamento.ordens_compra.finalidade IS
  'pedidos_venda = compra para um ou mais PVs (o que sobra vai para estoque); recompra = reposição de um PV já atendido; estoque; uso_interno.';

-- -----------------------------------------------------------------------------
-- V2. Vínculo de cada item da OC com o PV (e o item do PV) que ele atende
-- -----------------------------------------------------------------------------
-- A quantidade é SEMPRE na unidade do item da OC: na fabricação, 1 item do PV
-- (grade de piso, m²) é atendido por vários itens de compra (barra chata em kg,
-- barra redonda em barra), e não existe conversão entre eles. O que não está
-- vinculado é estoque.
--
-- O PV é identificado por unidade + número (o mesmo PV tem uma linha por
-- parcial no banco) e, opcionalmente, pelo produto do PV (codigo_produto_omie).
CREATE TABLE core_vendas_faturamento.ordens_compra_itens_vinculos (
  id                    uuid PRIMARY KEY DEFAULT uuidv7(),
  id_ordem_compra_item  uuid NOT NULL REFERENCES core_vendas_faturamento.ordens_compra_itens(id)
                          ON UPDATE CASCADE ON DELETE CASCADE,
  id_ordem_compra       uuid NOT NULL REFERENCES core_vendas_faturamento.ordens_compra(id)
                          ON UPDATE CASCADE ON DELETE CASCADE,   -- preenchido pela trigger
  codigo_empresa_pv     uuid NOT NULL REFERENCES core.unidades(id),  -- pode ser outra unidade
  numero_pedido_venda   varchar(30) NOT NULL,
  codigo_produto_pv     varchar(60),              -- NULL = o PV como um todo
  quantidade            numeric(15,4) NOT NULL
                          CONSTRAINT ck_oc_vinculos_quantidade CHECK (quantidade > 0),
  pv_conferido          boolean NOT NULL DEFAULT false,  -- trigger: o PV existe no banco
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_oc_vinculos_item_pv
  ON core_vendas_faturamento.ordens_compra_itens_vinculos
     (id_ordem_compra_item, codigo_empresa_pv, numero_pedido_venda, COALESCE(codigo_produto_pv, ''));
CREATE INDEX idx_oc_vinculos_pv
  ON core_vendas_faturamento.ordens_compra_itens_vinculos (codigo_empresa_pv, numero_pedido_venda);
CREATE INDEX idx_oc_vinculos_oc
  ON core_vendas_faturamento.ordens_compra_itens_vinculos (id_ordem_compra);
CREATE TRIGGER trg_oc_vinculos_updated_at BEFORE UPDATE
  ON core_vendas_faturamento.ordens_compra_itens_vinculos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_oc_vinculos_validar()
 RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_item       record;
  v_ja         numeric;
  v_unidade    text;
  v_compra_por uuid;
BEGIN
  SELECT i.id_ordem_compra, i.quantidade, i.unidade_medida, o.finalidade
    INTO v_item
    FROM core_vendas_faturamento.ordens_compra_itens i
    JOIN core_vendas_faturamento.ordens_compra o ON o.id = i.id_ordem_compra
   WHERE i.id = NEW.id_ordem_compra_item;

  NEW.id_ordem_compra     := v_item.id_ordem_compra;
  NEW.numero_pedido_venda := btrim(NEW.numero_pedido_venda);

  IF v_item.finalidade NOT IN ('pedidos_venda', 'recompra') THEN
    RAISE EXCEPTION 'OC com finalidade "%" não se liga a pedido de venda', v_item.finalidade
      USING ERRCODE = '23514';
  END IF;

  SELECT u.nome_fantasia, u.id_unidade_compra INTO v_unidade, v_compra_por
    FROM core.unidades u WHERE u.id = NEW.codigo_empresa_pv;

  NEW.pv_conferido := EXISTS (
    SELECT 1 FROM core_vendas_faturamento.pedidos_vendas p
     WHERE p.codigo_empresa = NEW.codigo_empresa_pv
       AND p.numero_pedido = NEW.numero_pedido_venda
       AND p.deleted_at IS NULL);

  -- PV que não existe no banco só é aceito de unidade SEM Omie (compra por
  -- outra: a HRM). Nas demais, é número digitado errado.
  IF NOT NEW.pv_conferido AND v_compra_por IS NULL THEN
    RAISE EXCEPTION 'Pedido de venda % não existe em %', NEW.numero_pedido_venda, v_unidade
      USING ERRCODE = '23514';
  END IF;

  IF NEW.pv_conferido AND NEW.codigo_produto_pv IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM core_vendas_faturamento.produto_vendas pv
        WHERE pv.codigo_empresa = NEW.codigo_empresa_pv
          AND pv.numero_pedido = NEW.numero_pedido_venda
          AND pv.codigo_produto_omie = NEW.codigo_produto_pv
          AND pv.deleted_at IS NULL) THEN
    RAISE EXCEPTION 'O produto % não está no pedido de venda %', NEW.codigo_produto_pv, NEW.numero_pedido_venda
      USING ERRCODE = '23514';
  END IF;

  -- A soma dos vínculos não passa da quantidade do item (o resto é estoque).
  SELECT COALESCE(sum(v.quantidade), 0) INTO v_ja
    FROM core_vendas_faturamento.ordens_compra_itens_vinculos v
   WHERE v.id_ordem_compra_item = NEW.id_ordem_compra_item
     AND v.id <> NEW.id;
  IF v_ja + NEW.quantidade > v_item.quantidade THEN
    RAISE EXCEPTION 'Vínculos somam % %, mais que a quantidade do item (% %)',
      v_ja + NEW.quantidade, v_item.unidade_medida, v_item.quantidade, v_item.unidade_medida
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END $$;
CREATE TRIGGER trg_oc_vinculos_validar
  BEFORE INSERT OR UPDATE ON core_vendas_faturamento.ordens_compra_itens_vinculos
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_oc_vinculos_validar();

-- Reduzir a quantidade do item abaixo do que está vinculado, ou mudar a
-- finalidade da OC para uma que não liga a PV, é recusado.
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_oc_itens_vinculos_guardar()
 RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_ja numeric;
BEGIN
  SELECT COALESCE(sum(quantidade), 0) INTO v_ja
    FROM core_vendas_faturamento.ordens_compra_itens_vinculos
   WHERE id_ordem_compra_item = NEW.id;
  IF NEW.quantidade < v_ja THEN
    RAISE EXCEPTION 'O item tem % % vinculados a pedidos de venda; a quantidade não pode ficar menor',
      v_ja, NEW.unidade_medida USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_oc_itens_vinculos_guardar
  BEFORE UPDATE OF quantidade ON core_vendas_faturamento.ordens_compra_itens
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_oc_itens_vinculos_guardar();

CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ordens_compra_finalidade_guardar()
 RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.finalidade NOT IN ('pedidos_venda', 'recompra') AND EXISTS (
       SELECT 1 FROM core_vendas_faturamento.ordens_compra_itens_vinculos WHERE id_ordem_compra = NEW.id) THEN
    RAISE EXCEPTION 'A OC tem itens vinculados a pedidos de venda; tire os vínculos antes de mudar a finalidade para "%"',
      NEW.finalidade USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_ordens_compra_finalidade_guardar
  BEFORE UPDATE OF finalidade ON core_vendas_faturamento.ordens_compra
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_ordens_compra_finalidade_guardar();

-- -----------------------------------------------------------------------------
-- V3. Várias requisições do MES numa OC: a requisição passa a ser do ITEM
-- -----------------------------------------------------------------------------
ALTER TABLE core_vendas_faturamento.ordens_compra_itens
  ADD COLUMN id_requisicao uuid REFERENCES core_vendas_faturamento.requisicoes_compra(id)
    ON UPDATE CASCADE ON DELETE SET NULL;
CREATE UNIQUE INDEX uq_ordens_compra_itens_requisicao
  ON core_vendas_faturamento.ordens_compra_itens (id_requisicao) WHERE id_requisicao IS NOT NULL;
COMMENT ON COLUMN core_vendas_faturamento.ordens_compra_itens.id_requisicao IS
  'Requisição do MES que este item atende. Várias requisições numa OC = vários itens. (ordens_compra.id_requisicao fica para OC de requisição única, compatível.)';

-- Item com requisição: a requisição precisa estar na fila (aberta/em cotação) e
-- ser da unidade da OC (ou de uma unidade que compra por ela: HRM -> Mogi);
-- ao gravar, ela vira 'atendida' por esta OC.
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_oc_itens_requisicao()
 RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_req record;
  v_oc  uuid;
BEGIN
  IF NEW.id_requisicao IS NULL THEN
    RETURN NULL;
  END IF;
  SELECT r.status, r.numero_requisicao, r.codigo_empresa, u.id_unidade_compra
    INTO v_req
    FROM core_vendas_faturamento.requisicoes_compra r
    JOIN core.unidades u ON u.id = r.codigo_empresa
   WHERE r.id = NEW.id_requisicao;
  SELECT o.codigo_empresa INTO v_oc FROM core_vendas_faturamento.ordens_compra o WHERE o.id = NEW.id_ordem_compra;

  IF v_req.status NOT IN ('aberta', 'em_cotacao') THEN
    RAISE EXCEPTION 'A requisição % está %, não pode entrar numa OC', v_req.numero_requisicao, v_req.status
      USING ERRCODE = '23514';
  END IF;
  IF v_req.codigo_empresa <> v_oc AND v_req.id_unidade_compra IS DISTINCT FROM v_oc THEN
    RAISE EXCEPTION 'A requisição % é de outra unidade', v_req.numero_requisicao USING ERRCODE = '23514';
  END IF;

  UPDATE core_vendas_faturamento.requisicoes_compra
     SET status = 'atendida', id_ordem_compra = NEW.id_ordem_compra
   WHERE id = NEW.id_requisicao;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_oc_itens_requisicao
  AFTER INSERT ON core_vendas_faturamento.ordens_compra_itens
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_oc_itens_requisicao();

-- Cancelar ou apagar a OC devolve TODAS as requisições dela para a fila
-- (antes: só a do cabeçalho).
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ordens_compra_requisicao()
 RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  -- OC nasceu de uma requisição (cabeçalho) -> a requisição sai da fila.
  IF TG_OP = 'INSERT' AND NEW.id_requisicao IS NOT NULL THEN
    UPDATE core_vendas_faturamento.requisicoes_compra
       SET status = 'atendida', id_ordem_compra = NEW.id
     WHERE id = NEW.id_requisicao;
    RETURN NEW;
  END IF;

  -- OC cancelada -> as requisições dela VOLTAM para a fila.
  IF TG_OP = 'UPDATE' AND NEW.status = 'cancelado' AND OLD.status <> 'cancelado' THEN
    UPDATE core_vendas_faturamento.requisicoes_compra
       SET status = 'aberta', id_ordem_compra = NULL
     WHERE id_ordem_compra = NEW.id;
  END IF;

  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ordens_compra_ao_apagar()
 RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE core_vendas_faturamento.requisicoes_compra
     SET status = 'aberta', id_ordem_compra = NULL
   WHERE id_ordem_compra = OLD.id;
  RETURN OLD;
END $$;

-- -----------------------------------------------------------------------------
-- V4. Leitura: itens do PV para comprar, e compras de um PV
-- -----------------------------------------------------------------------------
-- Um item do PV por PRODUTO (somando as parciais). vendido = parciais
-- pendentes + faturadas; pendente = ainda não faturadas (é o que falta
-- entregar). em_oc = vínculos de OCs não canceladas COM O MESMO PRODUTO (só aí
-- as unidades batem); saldo_a_comprar = pendente − em_oc. Com produto
-- diferente (fabricação), conta só as linhas de compra ligadas.
CREATE OR REPLACE VIEW core_vendas_faturamento.vw_pedido_venda_itens_compra AS
WITH itens AS (
  SELECT pv.codigo_empresa, pv.numero_pedido, pv.codigo_produto_omie,
         max(pv.codigo_produto)  AS codigo_produto,
         max(pr.descricao)       AS descricao,
         max(pv.unidade_medida)  AS unidade_medida,
         sum(pv.quantidade) FILTER (WHERE p.situacao IN ('Pendente', 'Faturado')) AS quantidade_vendida,
         COALESCE(sum(pv.quantidade) FILTER (WHERE p.situacao = 'Pendente'), 0)   AS quantidade_pendente
    FROM core_vendas_faturamento.produto_vendas pv
    JOIN core_vendas_faturamento.pedidos_vendas p
      ON p.codigo_pedido_omie = pv.codigo_pedido_omie AND p.deleted_at IS NULL
    LEFT JOIN core.produtos pr
      ON pr.codigo_empresa = pv.codigo_empresa AND pr.codigo_produto_omie = pv.codigo_produto_omie
   WHERE pv.deleted_at IS NULL
   GROUP BY pv.codigo_empresa, pv.numero_pedido, pv.codigo_produto_omie
), compras AS (
  SELECT v.codigo_empresa_pv, v.numero_pedido_venda, v.codigo_produto_pv,
         sum(v.quantidade) FILTER (WHERE i.codigo_produto = v.codigo_produto_pv) AS quantidade_em_oc,
         count(*) AS linhas_de_compra
    FROM core_vendas_faturamento.ordens_compra_itens_vinculos v
    JOIN core_vendas_faturamento.ordens_compra_itens i ON i.id = v.id_ordem_compra_item
    JOIN core_vendas_faturamento.ordens_compra o ON o.id = v.id_ordem_compra
   WHERE o.status <> 'cancelado' AND o.deleted_at IS NULL
   GROUP BY v.codigo_empresa_pv, v.numero_pedido_venda, v.codigo_produto_pv
)
SELECT it.codigo_empresa, it.numero_pedido, it.codigo_produto_omie, it.codigo_produto,
       it.descricao, it.unidade_medida,
       it.quantidade_vendida, it.quantidade_pendente,
       COALESCE(c.quantidade_em_oc, 0) AS quantidade_em_oc,
       GREATEST(it.quantidade_pendente - COALESCE(c.quantidade_em_oc, 0), 0) AS saldo_a_comprar,
       COALESCE(c.linhas_de_compra, 0) AS linhas_de_compra
  FROM itens it
  LEFT JOIN compras c
    ON c.codigo_empresa_pv = it.codigo_empresa
   AND c.numero_pedido_venda = it.numero_pedido
   AND c.codigo_produto_pv = it.codigo_produto_omie;

-- Compras de um PV: as OCs do av-hub (pelo vínculo) e os pedidos de compra
-- antigos do Omie (pelo cNumPedido, onde os compradores escreviam o nº do PV:
-- "28067", "27787/27589", "27769/ESTOQUE"). Os do Omie que nasceram de OC do
-- av-hub (codigo_pedido_integracao 'OC-...') não entram pelo cNumPedido: lá
-- ele passou a ser o nº do fornecedor.
CREATE OR REPLACE VIEW core_vendas_faturamento.vw_pedido_venda_compras AS
SELECT 'av-hub'::text AS origem,
       v.codigo_empresa_pv AS codigo_empresa, v.numero_pedido_venda AS numero_pedido,
       o.id AS id_ordem_compra, o.numero_pedido AS numero_compra, o.codigo_empresa AS codigo_empresa_compra,
       o.finalidade, o.status, o.status_sincronizacao_omie, o.numero_pedido_omie,
       o.codigo_fornecedor, o.data_previsao_chegada,
       i.ordem, i.descricao_produto, i.codigo_produto, i.unidade_medida,
       v.quantidade AS quantidade_vinculada, i.quantidade AS quantidade_item,
       v.codigo_produto_pv, v.pv_conferido, o.created_at
  FROM core_vendas_faturamento.ordens_compra_itens_vinculos v
  JOIN core_vendas_faturamento.ordens_compra_itens i ON i.id = v.id_ordem_compra_item
  JOIN core_vendas_faturamento.ordens_compra o ON o.id = v.id_ordem_compra AND o.deleted_at IS NULL
UNION ALL
SELECT 'omie'::text,
       p.codigo_empresa, n.numero,
       NULL, p.numero_pedido, p.codigo_empresa,
       NULL, p.etapa, NULL, p.numero_pedido,
       p.codigo_fornecedor::text, p.data_previsao,
       NULL, NULL, NULL, NULL,
       NULL, NULL,
       NULL, true, p.incluido_em_omie
  FROM core_vendas_faturamento.pedidos_compras p
  CROSS JOIN LATERAL (
    SELECT DISTINCT m[1] AS numero
      FROM regexp_matches(COALESCE(p.numero_pedido_fornecedor, ''), '(\d{4,6})', 'g') AS m
  ) n
 WHERE p.deleted_at IS NULL
   AND COALESCE(p.codigo_pedido_integracao, '') NOT LIKE 'OC-%'
   AND EXISTS (SELECT 1 FROM core_vendas_faturamento.pedidos_vendas pv
                WHERE pv.codigo_empresa = p.codigo_empresa AND pv.numero_pedido = n.numero
                  AND pv.deleted_at IS NULL);

COMMIT;
```

## Apêndice B — Roteiro de teste (termina em ROLLBACK)

```sql
-- Roteiro de teste do vínculo OC ↔ pedido de venda. Termina em ROLLBACK.
-- Usa o PV 25970 de Mogi (revenda: flanges, curvas) como exemplo real.
\set ON_ERROR_STOP 1
\pset footer off
BEGIN;

CREATE TEMP TABLE ctx AS
SELECT (SELECT id FROM core.unidades WHERE cnpj = '23.440.235/0001-08') AS mogi,
       (SELECT id FROM core.unidades WHERE cnpj = '62.270.345/0001-12') AS uberaba,
       (SELECT id FROM core.unidades WHERE cnpj = '04.394.837/0001-13') AS hrm,
       (SELECT id FROM auth.usuarios WHERE deleted_at IS NULL ORDER BY created_at LIMIT 1) AS usuario,
       (SELECT codigo_produto_omie FROM core_vendas_faturamento.vw_pedido_venda_itens_compra
         WHERE numero_pedido = '25970' AND codigo_produto = '015LT030') AS flange;

\echo '== V1: antes — PV 25970, flange liso 3" (015LT030)'
SELECT codigo_produto, unidade_medida, quantidade_vendida, quantidade_pendente, quantidade_em_oc, saldo_a_comprar
  FROM core_vendas_faturamento.vw_pedido_venda_itens_compra WHERE numero_pedido = '25970' AND codigo_produto = '015LT030';

-- OC para pedidos de venda: 30 flanges (24 para o PV, 6 para estoque) e 2
-- itens de matéria-prima ligados ao MESMO item do PV (fabricação).
INSERT INTO core_vendas_faturamento.ordens_compra
  (codigo_empresa, codigo_fornecedor, tipo_frete, finalidade, contato, created_by)
SELECT mogi, '1', 'CIF', 'pedidos_venda', 'V-TESTE', usuario FROM ctx;
CREATE TEMP TABLE oc AS SELECT id FROM core_vendas_faturamento.ordens_compra WHERE contato = 'V-TESTE';
INSERT INTO core_vendas_faturamento.ordens_compra_itens
  (id_ordem_compra, codigo_empresa, ordem, codigo_produto, descricao_produto, quantidade, unidade_medida, valor_unitario)
SELECT oc.id, ctx.mogi, 1, ctx.flange, 'FLANGE LISO SOLTO 3"', 30, 'PC', 50 FROM oc, ctx UNION ALL
SELECT oc.id, ctx.mogi, 2, NULL, 'BARRA CHATA 1.1/4 X 3/16', 850, 'KG', 7.2 FROM oc, ctx UNION ALL
SELECT oc.id, ctx.mogi, 3, NULL, 'BARRA REDONDA 5/16', 40, 'BR', 38 FROM oc, ctx;
CREATE TEMP TABLE it AS
SELECT ordem, id FROM core_vendas_faturamento.ordens_compra_itens WHERE id_ordem_compra = (SELECT id FROM oc);

INSERT INTO core_vendas_faturamento.ordens_compra_itens_vinculos
  (id_ordem_compra_item, codigo_empresa_pv, numero_pedido_venda, codigo_produto_pv, quantidade)
SELECT (SELECT id FROM it WHERE ordem = 1), mogi, '25970', flange, 24 FROM ctx UNION ALL
SELECT (SELECT id FROM it WHERE ordem = 2), mogi, '25970', flange, 850 FROM ctx UNION ALL
SELECT (SELECT id FROM it WHERE ordem = 3), mogi, ' 25970 ', flange, 40 FROM ctx;

\echo '== V2: depois — saldo zera (mesmo produto: 24 em OC) e a fabricação conta como linhas de compra'
SELECT codigo_produto, quantidade_pendente, quantidade_em_oc, saldo_a_comprar, linhas_de_compra
  FROM core_vendas_faturamento.vw_pedido_venda_itens_compra WHERE numero_pedido = '25970' AND codigo_produto = '015LT030';
SELECT v.numero_pedido_venda, i.ordem, i.unidade_medida, v.quantidade, v.pv_conferido
  FROM core_vendas_faturamento.ordens_compra_itens_vinculos v
  JOIN core_vendas_faturamento.ordens_compra_itens i ON i.id = v.id_ordem_compra_item
 WHERE v.id_ordem_compra = (SELECT id FROM oc) ORDER BY i.ordem;

\echo '== V3: compras do PV 25970 (o que a página do PV vai mostrar)'
SELECT origem, ordem, descricao_produto, quantidade_vinculada, unidade_medida, status
  FROM core_vendas_faturamento.vw_pedido_venda_compras
 WHERE numero_pedido = '25970' AND origem = 'av-hub' ORDER BY ordem;

\echo '== V4: erros esperados (cada um desfeito com SAVEPOINT)'
\set ON_ERROR_STOP 0
SAVEPOINT s;
-- (a) vínculos passam da quantidade do item (30 PC: já tem 24)
INSERT INTO core_vendas_faturamento.ordens_compra_itens_vinculos
  (id_ordem_compra_item, codigo_empresa_pv, numero_pedido_venda, quantidade)
SELECT (SELECT id FROM it WHERE ordem = 1), mogi, '28067', 7 FROM ctx;
ROLLBACK TO SAVEPOINT s;
-- (b) PV que não existe em Mogi
INSERT INTO core_vendas_faturamento.ordens_compra_itens_vinculos
  (id_ordem_compra_item, codigo_empresa_pv, numero_pedido_venda, quantidade)
SELECT (SELECT id FROM it WHERE ordem = 1), mogi, '999999', 1 FROM ctx;
ROLLBACK TO SAVEPOINT s;
-- (c) produto que não está no PV
INSERT INTO core_vendas_faturamento.ordens_compra_itens_vinculos
  (id_ordem_compra_item, codigo_empresa_pv, numero_pedido_venda, codigo_produto_pv, quantidade)
SELECT (SELECT id FROM it WHERE ordem = 1), mogi, '28067', '1', 1 FROM ctx;
ROLLBACK TO SAVEPOINT s;
-- (d) diminuir o item abaixo do vinculado
UPDATE core_vendas_faturamento.ordens_compra_itens SET quantidade = 20 WHERE id = (SELECT id FROM it WHERE ordem = 1);
ROLLBACK TO SAVEPOINT s;
-- (e) mudar a finalidade para estoque com vínculos
UPDATE core_vendas_faturamento.ordens_compra SET finalidade = 'estoque' WHERE id = (SELECT id FROM oc);
ROLLBACK TO SAVEPOINT s;
\set ON_ERROR_STOP 1

\echo '== V5: PV da HRM (sem Omie, não está no banco) é aceito, marcado como não conferido'
INSERT INTO core_vendas_faturamento.ordens_compra_itens_vinculos
  (id_ordem_compra_item, codigo_empresa_pv, numero_pedido_venda, quantidade)
SELECT (SELECT id FROM it WHERE ordem = 1), hrm, '27588', 2 FROM ctx
RETURNING numero_pedido_venda, quantidade, pv_conferido;

\echo '== V6: OC de estoque não aceita vínculo'
INSERT INTO core_vendas_faturamento.ordens_compra
  (codigo_empresa, codigo_fornecedor, tipo_frete, finalidade, contato, created_by)
SELECT mogi, '1', 'CIF', 'estoque', 'V-ESTOQUE', usuario FROM ctx;
INSERT INTO core_vendas_faturamento.ordens_compra_itens
  (id_ordem_compra, codigo_empresa, ordem, descricao_produto, quantidade, unidade_medida, valor_unitario)
SELECT o.id, ctx.mogi, 1, 'TUBO', 5, 'PC', 10 FROM core_vendas_faturamento.ordens_compra o, ctx WHERE o.contato = 'V-ESTOQUE';
SAVEPOINT s2;
\set ON_ERROR_STOP 0
INSERT INTO core_vendas_faturamento.ordens_compra_itens_vinculos
  (id_ordem_compra_item, codigo_empresa_pv, numero_pedido_venda, quantidade)
SELECT i.id, ctx.mogi, '28067', 1
  FROM core_vendas_faturamento.ordens_compra_itens i JOIN core_vendas_faturamento.ordens_compra o ON o.id = i.id_ordem_compra, ctx
 WHERE o.contato = 'V-ESTOQUE';
\set ON_ERROR_STOP 1
ROLLBACK TO SAVEPOINT s2;

\echo '== V7: duas requisições do MES numa OC só; cancelar devolve as duas para a fila'
INSERT INTO core_vendas_faturamento.requisicoes_compra
  (codigo_empresa, material, quantidade, unidade_medida, prazo_necessidade, observacao)
SELECT mogi, 'CHAPA 3/8', 10, 'PC', DATE '2026-10-30', 'V-REQ' FROM ctx UNION ALL
SELECT mogi, 'CHAPA 1/2', 4, 'PC', DATE '2026-10-30', 'V-REQ' FROM ctx UNION ALL
SELECT hrm,  'TINTA',     2, 'GL', DATE '2026-10-30', 'V-REQ' FROM ctx;
INSERT INTO core_vendas_faturamento.ordens_compra
  (codigo_empresa, codigo_fornecedor, tipo_frete, finalidade, contato, created_by)
SELECT mogi, '1', 'CIF', 'estoque', 'V-REQS', usuario FROM ctx;
INSERT INTO core_vendas_faturamento.ordens_compra_itens
  (id_ordem_compra, codigo_empresa, ordem, descricao_produto, quantidade, unidade_medida, valor_unitario, id_requisicao)
SELECT o.id, ctx.mogi, row_number() OVER (ORDER BY r.material), r.material, r.quantidade, r.unidade_medida, 100, r.id
  FROM core_vendas_faturamento.requisicoes_compra r, core_vendas_faturamento.ordens_compra o, ctx
 WHERE r.observacao = 'V-REQ' AND o.contato = 'V-REQS';
SELECT r.material, u.nome_fantasia AS unidade_req, r.status, o.numero_pedido AS oc
  FROM core_vendas_faturamento.requisicoes_compra r
  JOIN core.unidades u ON u.id = r.codigo_empresa
  LEFT JOIN core_vendas_faturamento.ordens_compra o ON o.id = r.id_ordem_compra
 WHERE r.observacao = 'V-REQ' ORDER BY r.material;
UPDATE core_vendas_faturamento.ordens_compra SET status = 'cancelado' WHERE contato = 'V-REQS';
SELECT r.material, r.status, r.id_ordem_compra IS NULL AS voltou_para_fila
  FROM core_vendas_faturamento.requisicoes_compra r WHERE r.observacao = 'V-REQ' ORDER BY r.material;

\echo '== V8: requisição de outra unidade (Uberaba) numa OC de Mogi é recusada'
INSERT INTO core_vendas_faturamento.requisicoes_compra
  (codigo_empresa, material, quantidade, unidade_medida, prazo_necessidade, observacao)
SELECT uberaba, 'TUBO', 1, 'PC', DATE '2026-10-30', 'V-REQ-UBE' FROM ctx;
SAVEPOINT s3;
\set ON_ERROR_STOP 0
INSERT INTO core_vendas_faturamento.ordens_compra_itens
  (id_ordem_compra, codigo_empresa, ordem, descricao_produto, quantidade, unidade_medida, valor_unitario, id_requisicao)
SELECT (SELECT id FROM oc), ctx.mogi, 9, 'TUBO', 1, 'PC', 1, r.id
  FROM core_vendas_faturamento.requisicoes_compra r, ctx WHERE r.observacao = 'V-REQ-UBE';
\set ON_ERROR_STOP 1
ROLLBACK TO SAVEPOINT s3;

ROLLBACK;
```

Resultado esperado (obtido no local em 24/09/2026):

| Teste | Resultado |
|---|---|
| V1 | flange 3" (015LT030) do PV 25970: vendido 26, pendente 24, em OC 0, saldo 24 |
| V2 | depois da OC: em OC 24, saldo 0, linhas de compra 3; os 3 vínculos (24 PC, 850 KG, 40 BR) conferidos |
| V3 | "compras do PV 25970": as 3 linhas da OC, cada uma na sua unidade |
| V4 | 5 erros: vínculos 31 > 30 PC; PV 999999 não existe em Aços Vital; produto fora do PV; item abaixo do vinculado; finalidade para estoque com vínculos |
| V5 | PV 27588 da HRM aceito, `pv_conferido = false` |
| V6 | OC de estoque com vínculo: recusado |
| V7 | 3 requisições (2 de Mogi, 1 da HRM) atendidas pela mesma OC; ao cancelar, as 3 voltam para `aberta` |
| V8 | requisição de Uberaba numa OC de Mogi: "A requisição REQ-… é de outra unidade" |
