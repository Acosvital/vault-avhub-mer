---
tags: [contrato-sql, contrato-api, compras, omie]
criado: 2026-10-05
status: aplicada
---

# Contrato 36 — Compras: produto obrigatório no item e comprador da OC vindo do Omie

> ✅ **Concluído (06/10/2026, tarde).** O DBA aplicou o patch `36-anexos/0001` na `develop` da API (commit
> `c8f2f5e`): a chave `COMPRAS_EXIGIR_PRODUTO_CADASTRO` saiu e o produto do cadastro vale sempre. Em
> **produção** o P6 responde `origens: av-hub + omie`; o P1 e o histórico do comprador só aparecem
> emitindo OC (não testado em produção, que é só leitura). Na `api-test` a emissão de OC ainda dá **500**
> em qualquer caso (inclusive com produto válido) — problema do ambiente, à parte deste contrato.
>
> **Antes (manhã de 06/10): entregue pelo DBA, com uma pendência.** Conferido na `api-test`: migration 036 aplicada
> (`historico_comprador` no detalhe) e P6 ligado (`origens: av-hub + omie`, também em produção). **Pendência
> no P1:** a validação de produto foi entregue atrás da chave `COMPRAS_EXIGIR_PRODUTO_CADASTRO` (padrão
> `false`) e está **desligada** (na `api-test`, OC sem produto e com produto de outra unidade foram aceitas;
> as OCs de teste OC-000007/8/9 foram canceladas). **Decisão do Nathan: sem variável de ambiente — sempre
> ligado.** Patch pronto em `36-anexos/0001-produto-sempre-obrigatorio.patch` (tira a chave, a validação vale
> sempre; testado na API local: sem produto → 400, produto de Uberaba numa OC de Mogi → 400, produto da
> unidade → 201). O av-hub com a busca de produto (#129) já está na `main`, então pode subir já.


**Para:** DBA (Gustavo) e backend (`api-acos-vital`) · **Decisões do Nathan em 05/10/2026.**

## 1. Por quê

No teste real de 05/10/2026 (conta de Mogi, fornecedor de teste "IGNORAR ESSE CLIENTE TESTE", ver
[[23-Compras-Pipeline-Consolidado]]) o Omie **recusou o pedido de compra com item sem produto
cadastrado**: "Informe a tag [cProduto], [cCodIntProd] ou [nCodProd]", e com `cProduto` livre, "Produto
não cadastrado para o Código". A decisão B12 (24/09) permitia material em texto livre na OC; com ela,
toda OC de estoque emitida pela tela seria recusada. **Decisão: o item da OC passa a ter produto do
cadastro da unidade, sempre** (estoque, uso interno e pedido de venda; o item do PV já vem com o produto,
e dá para trocar por outro do cadastro).

Sobre o comprador: **a OC só vai ao Omie com comprador vinculado; o comprador não se troca no av-hub; se
trocarem o comprador do pedido no Omie, o av-hub acompanha e guarda o histórico.**

## 2. O que já está feito (fora do backend)

| Onde | O quê | Situação |
|---|---|---|
| av-hub | Busca de produto do cadastro da unidade no item da OC (`GET /produtos?codigo_empresa=&q=&ativo=true`, que já existe — B12 do contrato 22); produto obrigatório no formulário; item do PV de **outra** unidade entra sem produto (o código é de outra conta Omie) | branch `feat/compras-produto-comprador-oc`, testado no local |
| av-hub | Seção "Comprador" no detalhe da OC, com o histórico (aparece quando a API mandar `historico_comprador`, P5) | mesma branch |
| pipeline | OC sem comprador do Omie ou com item sem produto **não vai ao Omie**: vira erro na OC com a orientação, sem chamar o Omie | `omie-elt-pipeline` PR #1 (`d11b6d1`, `2ac4921`) |

## 3. O que o backend faz

| # | Onde | O quê |
|---|---|---|
| **P1** | API, `POST /compras/ordens` | Todo item exige `codigo_produto` que exista em `core.produtos` **da unidade da OC** (`codigo_empresa` = o da OC, `codigo_produto_omie` = `codigo_produto`, `deleted_at IS NULL`, `ativo`). Senão **400**: `"Item {ordem}: escolha um produto do cadastro da unidade (o Omie não aceita item sem produto)"`. A descrição continua obrigatória (vem do produto). |
| **P2** | — | **Já garantido no banco:** `fn_ordens_compra_comprador` recusa trocar o comprador depois da emissão ("O comprador da OC é gravado na emissão e não muda depois"). Só conferir que a API não oferece rota para trocar. |
| **P3** | SQL | Tabela `ordens_compra_comprador_historico` e a trigger de emissão (Apêndice A1/A2): grava o comprador inicial com `origem = 'emissao'`. |
| **P4** | SQL | Trigger no espelho `pedidos_compras` (Apêndice A3): quando o pedido do Omie que nasceu de uma OC (`codigo_pedido_integracao = ordens_compra.numero_pedido`, mesma unidade) chega com **outro** comprador (`codigo_comprador`), a OC passa a ter esse comprador (`id_comprador` do cadastro da unidade, ou `NULL` se o Omie tirou) e a troca vai para o histórico com `origem = 'omie'`. A trava do P2 (`fn_ordens_compra_comprador`) passa a deixar **só esta trigger** trocar o comprador (Apêndice A3, `avhub.origem = 'omie'`). |
| **P5** | API, `GET /compras/ordens/{id}` | Devolver `historico_comprador: [{ id, origem, id_comprador_anterior, nome_comprador_anterior, id_comprador_novo, nome_comprador_novo, numero_pedido_omie, created_at }]`, em ordem de `created_at`. Nome = `COALESCE(nome_exibicao, nome)` do comprador. |
| **P6** | API | `COMPRAS_HISTORICO_UNIFICADO` **sempre ligado** (decisão do Nathan: o dashboard é a visão geral do setor). Tirar a chave: sem `?origem=`, o padrão passa a ser av-hub + Omie. Conferido em 05/10: a produção ainda responde `"origens":["av-hub"]`. |

**Ordem de subida:** av-hub (busca de produto) **antes** da API com o P1 — com o P1 antes, ninguém
consegue emitir OC pela tela antiga, que não manda produto.

**Chaves que continuam (configuráveis, decisão do Nathan):** `COMPRAS_EXIGIR_PODE_APROVAR` (só a
Gerência de Compras aprova; o perfil precisa ter `pode_aprovar` em `compras`) e
`COMPRAS_VINCULO_EXIGIR_PV_EXISTENTE=true`. `COMPRAS_EXIGIR_VINCULO_COMPRADOR` pode continuar
desligada: a pipeline já não manda OC sem comprador ao Omie; ligada, barra já na emissão.

## 4. Aceite

- `POST /compras/ordens` com item sem `codigo_produto` → 400 com a mensagem do P1; com o código de um
  produto de **outra** unidade → 400; com produto da unidade → 201.
- `PATCH /compras/ordens/{id}` com `id_comprador` no corpo não muda o comprador.
- Emitir uma OC com comprador → `historico_comprador` com uma linha `origem = 'emissao'`.
- `UPDATE core_vendas_faturamento.pedidos_compras SET codigo_comprador = <outro comprador da unidade>`
  no espelho do pedido de uma OC aprovada e sincronizada → a OC passa a mostrar o novo comprador e o
  histórico ganha a linha `origem = 'omie'` com o número do pedido no Omie. Gravar de novo o mesmo
  comprador não cria linha.
- `GET /compras/ordens` sem `?origem=` devolve `"origens":["av-hub","omie"]`.

---

## Apêndice A — SQL (rodar numa transação; conferir antes no banco de teste)

```sql
BEGIN;

-- A1. Histórico do comprador da OC.
CREATE TABLE core_vendas_faturamento.ordens_compra_comprador_historico (
  id                    uuid PRIMARY KEY DEFAULT uuidv7(),
  id_ordem_compra       uuid NOT NULL REFERENCES core_vendas_faturamento.ordens_compra(id)
                          ON UPDATE CASCADE ON DELETE CASCADE,
  origem                varchar(10) NOT NULL CHECK (origem IN ('emissao', 'omie')),
  id_comprador_anterior uuid REFERENCES core_vendas_faturamento.compradores(id),
  id_comprador_novo     uuid REFERENCES core_vendas_faturamento.compradores(id),
  numero_pedido_omie    varchar(30),
  created_at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_oc_comprador_hist_oc
  ON core_vendas_faturamento.ordens_compra_comprador_historico (id_ordem_compra, created_at);

-- A2. Comprador inicial, na emissão.
CREATE FUNCTION core_vendas_faturamento.fn_oc_comprador_emissao() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.id_comprador IS NOT NULL THEN
    INSERT INTO core_vendas_faturamento.ordens_compra_comprador_historico
      (id_ordem_compra, origem, id_comprador_novo)
    VALUES (NEW.id, 'emissao', NEW.id_comprador);
  END IF;
  RETURN NULL;
END $$;

CREATE TRIGGER trg_oc_comprador_emissao
  AFTER INSERT ON core_vendas_faturamento.ordens_compra
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_oc_comprador_emissao();

-- A3a. A trava do comprador (P2) libera só a troca vinda do Omie (A3b).
--      Igual à função atual, com o IF de cima ganhando a exceção.
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ordens_compra_comprador() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_empresa uuid;
  v_excluido timestamptz;
  v_nome text;
BEGIN
  IF TG_OP = 'UPDATE'
     AND OLD.id_comprador IS NOT NULL
     AND NEW.id_comprador IS DISTINCT FROM OLD.id_comprador
     AND current_setting('avhub.origem', true) IS DISTINCT FROM 'omie' THEN
    RAISE EXCEPTION 'O comprador da OC é gravado na emissão e não muda depois (OC %)', OLD.numero_pedido
      USING ERRCODE = '23514';
  END IF;

  IF NEW.id_comprador IS NOT NULL THEN
    SELECT c.codigo_empresa, c.deleted_at, COALESCE(c.nome_exibicao, c.nome)
      INTO v_empresa, v_excluido, v_nome
      FROM core_vendas_faturamento.compradores c
     WHERE c.id = NEW.id_comprador
       FOR SHARE;
    IF FOUND AND v_empresa IS DISTINCT FROM NEW.codigo_empresa THEN
      RAISE EXCEPTION 'O comprador da OC precisa ser da mesma unidade da OC: o código de comprador só vale na conta Omie dele'
        USING ERRCODE = '23514';
    END IF;
    IF FOUND AND v_excluido IS NOT NULL
       AND (TG_OP = 'INSERT' OR OLD.id_comprador IS NULL) THEN
      RAISE EXCEPTION 'O comprador % foi excluído e não pode emitir OC', v_nome
        USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;

-- A3b. Troca de comprador feita no Omie, trazida pelo espelho (pipeline).
CREATE FUNCTION core_vendas_faturamento.fn_oc_comprador_do_omie() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_oc        core_vendas_faturamento.ordens_compra%ROWTYPE;
  v_comprador uuid;
BEGIN
  IF NEW.codigo_pedido_integracao IS NULL OR NEW.deleted_at IS NOT NULL THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_oc
    FROM core_vendas_faturamento.ordens_compra
   WHERE codigo_empresa = NEW.codigo_empresa
     AND numero_pedido  = NEW.codigo_pedido_integracao
     AND deleted_at IS NULL;
  IF NOT FOUND THEN
    RETURN NULL;  -- pedido feito direto no Omie: não é OC do av-hub
  END IF;

  -- 0/NULL no Omie = sem comprador.
  IF COALESCE(NEW.codigo_comprador, 0) <> 0 THEN
    SELECT id INTO v_comprador
      FROM core_vendas_faturamento.compradores
     WHERE codigo_empresa = NEW.codigo_empresa
       AND codigo_comprador_omie = NEW.codigo_comprador::text
       AND deleted_at IS NULL;
  END IF;

  IF v_comprador IS NOT DISTINCT FROM v_oc.id_comprador THEN
    RETURN NULL;  -- mesmo comprador: nada muda, nada vai ao histórico
  END IF;

  -- Só a coluna id_comprador; a marca libera a trava do A3a e vale só até o
  -- fim deste UPDATE (volta a vazio logo depois).
  PERFORM set_config('avhub.origem', 'omie', true);
  UPDATE core_vendas_faturamento.ordens_compra
     SET id_comprador = v_comprador
   WHERE id = v_oc.id;
  PERFORM set_config('avhub.origem', '', true);

  INSERT INTO core_vendas_faturamento.ordens_compra_comprador_historico
    (id_ordem_compra, origem, id_comprador_anterior, id_comprador_novo, numero_pedido_omie)
  VALUES (v_oc.id, 'omie', v_oc.id_comprador, v_comprador, NEW.numero_pedido);
  RETURN NULL;
END $$;

CREATE TRIGGER trg_pedidos_compras_comprador_para_oc
  AFTER INSERT OR UPDATE OF codigo_comprador ON core_vendas_faturamento.pedidos_compras
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_oc_comprador_do_omie();

-- A4. OCs já emitidas: comprador atual como linha de emissão (uma vez).
INSERT INTO core_vendas_faturamento.ordens_compra_comprador_historico
  (id_ordem_compra, origem, id_comprador_novo, created_at)
SELECT id, 'emissao', id_comprador, created_at
  FROM core_vendas_faturamento.ordens_compra
 WHERE id_comprador IS NOT NULL AND deleted_at IS NULL;

COMMIT;
```

## Ver também
- [[23-Compras-Pipeline-Consolidado]] — teste real no Omie de 05/10/2026.
- [[22-Compras-Backend-Consolidado]] / [[13-Compras-Backend-Consolidado]] — B12 (texto livre, agora
  substituído por este contrato), B13 (trava da OC aprovada).
- [[18-Compradores-Funcionario]] e [[28-Compradores-Criar-Excluir-Sugestao]] — cadastro de compradores.
