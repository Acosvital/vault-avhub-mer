---
tags: [contrato-logica, contrato-sql, contrato-api, vendas, integracao-mes]
criado: 2026-09-28
status: proposta
---

# Contrato 26 — Vendas: liberação do pedido pelo vendedor (acompanhamento da Qualidade) + Fluxo 4 para o MES

> **Situação em 28/09/2026 (fim da tarde):** **front mergeado na `develop`** do av-hub
> ([av-hub#103](https://github.com/Acosvital/av-hub/pull/103)). **Backend ainda não aplicado:** na
> `api-test`, `/pedidos_liberacao` e `/pedidos_liberados` respondem "Rota não encontrada". Falta o
> DBA aplicar os Apêndices A e B (sem o B, as telas não aparecem no menu) e o backend aplicar o patch
> de `26-anexos/`. Até lá, as telas abrem sem dados.

**Criado em:** 28/09/2026 · **Para:** DBA, backend (`api-acos-vital`) e MES (`api-pcp`, Robert)

**Tudo aqui foi aplicado e testado no ambiente local** (banco `omie-test-db`; API da `origin/develop`
de 25/09 + esta feature no container `api-acos-vital-vendas`; av-hub na branch
`feat/vendas-liberacao-pedidos`), com dados reais de produção.

| Parte | Onde | Quem aplica |
|---|---|---|
| Banco — estrutura | [Apêndice A](#apêndice-a--estrutura) | DBA |
| Banco — telas e permissões | [Apêndice B](#apêndice-b--telas-e-permissões) | DBA |
| API | `26-anexos/0001-feat-vendas-liberacao-...patch` (sobre a `develop` em `04de3fe`, aplica limpo; branch local `feat/vendas-liberacao-pedidos` do clone `Desktop/api-acos-vital`) | backend |
| Tela | av-hub, mergeada na `develop` ([av-hub#103](https://github.com/Acosvital/av-hub/pull/103), 28/09/2026) | ✅ feito |

---

## 1. Por quê

Hoje o vendedor lança o pedido no Omie, o pipeline traz o pedido ao av-hub e o MES vê **todos** os
pedidos: a Carteira do PCP lê `GET /vendas_planilha` direto. Ninguém registra se a **Qualidade
acompanha o pedido desde o início** (documentação, validação de entrada) ou só no fim — o nó V2 de
[[Fluxogramas-Completos]] e a tela 1.1 "Caixa de entrada do vendedor" de [[Fluxograma-Telas-por-Bloco]],
que estava **sem tarefa**. O risco de pedido parado já estava apontado em [[Fluxo-Sistema-no-Meio]] (ato 1b).

A regra decidida pelo Nathan (28/09/2026):

- O pedido chega do Omie **travado** numa tela do vendedor.
- O vendedor marca **SIM** ou **NÃO** (Qualidade acompanha desde o início?).
- **Só pedido marcado vai para o MES.** Sem marcação, o MES não consegue puxar.
- O **gerente** tem uma tela para ver todos (só leitura).

## 2. Decisões (Nathan, 28/09/2026)

| Assunto | Decisão |
|---|---|
| Grão | **Por pedido** (unidade + número). As parciais que o pipeline cria depois herdam a marcação |
| Quais pedidos travam | **Só os novos**: incluídos no Omie a partir de `parametros_vendas.data_inicio_liberacao`. A carteira antiga (~2.000 em aberto) não trava |
| Corrigir a marcação | **Pode, até o MES importar.** Depois que o MES confirma a importação, trava (409) |
| Quem envia ao MES | **Ninguém envia: o MES faz GET (polling)** no av-hub — mesmo padrão da DEC-2 e dos Fluxos 1–3 de [[Integracao-AvHub-MES-Especificacao-F1]]. Vira o **Fluxo 4** |
| Quem libera | O vendedor e o auxiliar dos titulares que ele auxilia (mesmo escopo de Meus Pedidos) |
| Gerente | Tela própria no Portal do Gerente, **só visualização**, todos os vendedores |

Quais pedidos entram (mesmos filtros que a Carteira do MES já usa em `/vendas_planilha`):
`sequencial = 0` (o pedido-pai), sem track record, **grupo LÍQUIDO** (sem dedução/blacklist),
`etapa <> 0`, incluído a partir da data de corte e **Pendente** — ou já liberado (esse continua
visível depois de faturado).

## 3. Banco

| Objeto | O que faz |
|---|---|
| `core_vendas_faturamento.parametros_vendas` | linha única; `data_inicio_liberacao` (a data de corte) |
| `core_vendas_faturamento.pedidos_vendas_liberacao` | PK `(codigo_empresa, numero_pedido)`; `acompanhamento_qualidade`, `liberado_por/_em`, `updated_by/_at`, `importado_mes_em`, `importado_mes_referencia`. **Sem FK para `pedidos_vendas`** (o pipeline recria linhas), mesmo raciocínio de `pedido_observacao_pcp` |
| `..._liberacao_historico` | `liberado` / `alterado` (com valor anterior) / `importado_mes` — gravado por trigger |
| `fn_pedidos_vendas_liberacao_regras` (BEFORE) | quem liberou não muda; `updated_at` do servidor; **depois de `importado_mes_em`, trocar a marcação dá `RAISE ... ERRCODE 23514`** e a importação não se desfaz |
| `vw_pedidos_liberacao` | um pedido por linha, com `status_liberacao` = `pendente` / `liberado` / `importado` |
| telas `liberar-pedidos` e `liberacao-equipe` | Apêndice B |

**Desempenho (medido):** a data de corte entra como subconsulta escalar e a view não tem
`DISTINCT ON`, para os filtros descerem até `vw_vendas_planilha`. A lista de um vendedor leva ~0,5 s
pela API (com `CROSS JOIN` + `DISTINCT ON`: 2,7 s). Um pedido por linha é garantido pelo índice
`uq_pedidos_vendas_numero_sequencial` (conferido: 9.869 linhas de sequencial 0 = 9.869 pedidos).

**Valor da data de corte em produção: a definir pelo Nathan** (no local ficou `2026-09-01`, para
ter dado de teste). Recomendação: o dia em que a tela for para produção.

## 4. API

### 4.1 Caixa do vendedor e tela do gerente (o av-hub usa)

| Rota | Faz |
|---|---|
| `GET /pedidos_liberacao?vendedor=EMP:COD,...&codigo_empresa=&status=pendente\|liberado\|importado\|todos&busca=&sort=&order=&page=&limit=` | página + `contagem` por status (números das abas) + `data_inicio_liberacao`. Sem `vendedor` = todos (tela do gerente). `busca` procura número, cliente e vendedor |
| `PUT /pedidos_liberacao/:codigo_empresa/:numero_pedido` `{ acompanhamento_qualidade, updated_by }` | libera (1ª vez) ou troca a marcação; **404** `PEDIDO_FORA_DA_LIBERACAO`, **409** `PEDIDO_IMPORTADO_MES` |

`sort`: `data_inclusao`, `data_previsao`, `total_pedido_venda`, `cliente`, `numero_pedido`, `liberado_em`.
Registrada no `escopoVendedor.js` como `formato: "par"` + `detalhe: "pedido_venda"`: com
`ESCOPO_VENDEDORES_EXIGIR=true` e token, a API preenche/confere o par e o dono do pedido no PUT.

### 4.2 Fluxo 4 — o MES lê daqui (Robert)

| Rota | Faz |
|---|---|
| `GET /pedidos_liberados?codigo_empresa=&alterado_desde=&mes=&ano=&importado=&page=&limit=` | **só pedidos liberados**. Com `alterado_desde` (ISO) ordena por `liberacao_alterada_em` crescente (polling); sem ele, por inclusão, mais recente primeiro |
| `GET /pedidos_liberados/:numero/itens?codigo_empresa=` | mesma resposta de `/pedido_venda_itens/:numero` + objeto `liberacao`; **409** `PEDIDO_NAO_LIBERADO` se o vendedor não marcou |
| `POST /pedidos_liberados/:numero/importado?codigo_empresa=` `{ referencia? }` | o MES confirma que importou; idempotente. A partir daí a marcação trava no av-hub |

Os campos de `GET /pedidos_liberados` têm **os mesmos nomes de `/vendas_planilha`** (`pedido_venda`,
`destinatario`, `codigo_vendedor`, `etapa_descricao`, `total_pedido_venda`…), mais
`acompanhamento_qualidade`, `status_liberacao`, `liberado_em`, `liberacao_alterada_em`,
`importado_mes_em`. **No `api-pcp`, a troca é:**

1. `listarCarteiraIntegracao` (`src/pedidos/omie-integracao.ts`): trocar `GET /vendas_planilha` por
   `GET /pedidos_liberados` (mantém `mes`, `ano`, `codigo_empresa`, `page`, `limit`; os filtros fixos
   `grupo`/`etapa`/`sequencial`/`is_track_record` já são aplicados pela view).
2. `consultarOmieIntegracao`: trocar `/pedido_venda_itens/:numero` por `/pedidos_liberados/:numero/itens`
   (mesma resposta; tratar 409 como "pedido ainda não liberado pelo vendedor").
3. Ao gerar a Ordem de Produção do pedido, chamar `POST /pedidos_liberados/:numero/importado` com o
   id da OP/pedido do MES em `referencia`.
4. Guardar `acompanhamento_qualidade` no pedido do MES: alimenta a fila de inspeção de processo da
   Qualidade (tela 9.5 de [[Fluxograma-Telas-por-Bloco]], fora da Fase B).

## 5. O que muda no av-hub (já feito, mergeado na `develop` pelo av-hub#103)

| Tela | Onde | Quem | Faz |
|---|---|---|---|
| **Liberar pedidos** | Portal do Vendedor, `/liberar-pedidos` | Vendedor (`pode_editar` marca) | abas *Aguardando você / Liberados / No PCP / Todos* com as contagens do backend, busca, ordenação, Sim/Não por linha, aviso da última marcação, cadeado quando o PCP já importou |
| **Liberação da equipe** | Portal do Gerente, `/liberacao-equipe` | Gerência (só `pode_visualizar`) | a mesma tela com todos os vendedores: nome do vendedor na linha, filtro por unidade, busca também por vendedor, marcação como texto ("Sim", "Não", "Não marcado"), pedido abre em Pedidos da Equipe |

BFF `GET /api/liberar-pedidos` (`?fonte=equipe` exige a tela `liberacao-equipe` e não aplica escopo de
vendedor) e `PUT /api/liberar-pedidos/:empresa/:numero` (só a tela `liberar-pedidos`, autor pela
sessão). Testado em tema claro e escuro, desktop e celular, com dados reais (48 pedidos de um vendedor;
507 na visão da equipe).

**Marcas `GAMBIARRA(` deste contrato** (2, em `lib/api/liberacaoPedidos.ts` e no PUT do BFF): o escopo
de vendedores e a conferência do dono no PUT são feitos no BFF enquanto `ESCOPO_VENDEDORES_EXIGIR`
está desligado — ver L5.

## 6. Itens

| Item | O que | Quem | Estado |
|---|---|---|---|
| **L1** | Aplicar os Apêndices A e B em teste e depois em produção; definir a data de corte | DBA + Nathan | pendente |
| **L2** | Aplicar o patch na `develop` e publicar | backend | pendente |
| **L3** | Mapear em `auth.rotas_telas` (para `PERMISSOES_ROTA_MODO=exigir`): `GET /pedidos_liberacao` → `liberar-pedidos` **ou** `liberacao-equipe` `.pode_visualizar`; `PUT /pedidos_liberacao/*` → `liberar-pedidos.pode_editar`. `/pedidos_liberados/*` é rota de **serviço** (MES), fora do mapa de telas | DBA | pendente |
| **L4** | `api-pcp`: as 4 trocas da seção 4.2 | Robert | pendente |
| **L5** | Ligar `ESCOPO_VENDEDORES_EXIGIR`: aí as 2 marcas `GAMBIARRA(` saem do BFF | infra/backend | pendente (mesmo item do contrato de permissões) |
| **L6** | **Chave própria do MES**, restrita a `/pedidos_liberados/*` e ao que o MES já usa. Hoje o MES usa a mesma `x-api-key` genérica e **ainda consegue** ler `/vendas_planilha` e `/pedido_venda_itens` sem passar pelo portão; o bloqueio só é real depois de L4 + L6 | backend + Robert | a decidir |

## 7. Perguntas em aberto

1. **Data de corte em produção** (L1): qual dia?
2. **Correção depois da importação:** hoje ninguém destrava. Precisa de uma ação da Gerência/PCP
   ("reabrir marcação")? Se sim, vira item novo (rota + permissão `pode_aprovar`).
3. **Pedido parado:** pedido que o vendedor nunca libera fica invisível para o PCP. A tela do gerente
   mostra quem está segurando; falta decidir se há alerta depois de N horas e quem recebe.
4. **Auxiliar pode liberar pelo titular?** Implementado que sim (mesmo escopo de Meus Pedidos).
   Confirmar.

## 8. Testes feitos (local, 28/09/2026)

- Banco: liberar → trocar → importar gera 3 linhas de histórico; trocar depois de importado dá 23514;
  `liberado_por` e `importado_mes_em` não mudam por UPDATE.
- API: validação do corpo (400), pedido fora da caixa (404), MES antes de liberar (lista vazia, itens
  **409**), depois de liberar (aparece no polling), importado 2× (idempotente), PUT depois de
  importado (**409**), contagem por status, busca por vendedor.
- Telas: 48 → 47 aguardando + 1 liberado; troca Sim→Não com aviso; "No PCP" com cadeado depois do POST
  do MES; estados "sem acesso" e "sem vínculo"; gerente com 505 + 1 + 1 = 507, filtro de unidade e
  busca por vendedor pela URL.
- `GET /pedidos_liberados/:numero/itens` repassa para o handler de `/pedido_venda_itens`, que **no
  banco local** falha por falta da coluna `item_codigo_pedido_omie` (contrato 11, já aplicado na
  `api-test`). O portão (409/200) foi conferido; a resposta dos itens, conferir na `api-test`.

---

## Apêndice A — estrutura

Rodar uma vez; é idempotente onde dá. Depois, `INSERT INTO core_vendas_faturamento.parametros_vendas (data_inicio_liberacao) VALUES ('<data de corte>');`

```sql
-- Contrato: liberação do pedido de venda pelo vendedor (acompanhamento da Qualidade)
-- Apêndice A — estrutura. Idempotente onde dá.
BEGIN;

-- A1. Parâmetro: a partir de quando o pedido precisa ser liberado.
-- Uma linha só. Pedido incluído antes da data não trava e não vai ao MES.
CREATE TABLE IF NOT EXISTS core_vendas_faturamento.parametros_vendas (
  id                     smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  data_inicio_liberacao  date        NOT NULL,
  updated_at             timestamptz NOT NULL DEFAULT now(),
  updated_by             uuid REFERENCES auth.usuarios(id)
);
COMMENT ON TABLE core_vendas_faturamento.parametros_vendas IS
  'Parâmetros do módulo de Vendas (linha única). data_inicio_liberacao: pedidos incluídos a partir desta data precisam ser liberados pelo vendedor antes de o MES enxergá-los.';

-- A2. A liberação: uma linha por PEDIDO (unidade + número), não por parcial.
-- Sem FK para pedidos_vendas: o pipeline recria linhas numa ressincronização
-- e as parciais novas nascem depois; a liberação vale para todas.
CREATE TABLE IF NOT EXISTS core_vendas_faturamento.pedidos_vendas_liberacao (
  codigo_empresa            uuid        NOT NULL REFERENCES core.unidades(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  numero_pedido             varchar(15) NOT NULL CHECK (length(btrim(numero_pedido)) > 0),
  acompanhamento_qualidade  boolean     NOT NULL,
  liberado_por              uuid        NOT NULL REFERENCES auth.usuarios(id),
  liberado_em               timestamptz NOT NULL DEFAULT now(),
  updated_by                uuid        REFERENCES auth.usuarios(id),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  importado_mes_em          timestamptz,
  importado_mes_referencia  varchar(60),
  PRIMARY KEY (codigo_empresa, numero_pedido)
);
CREATE INDEX IF NOT EXISTS idx_pedidos_vendas_liberacao_updated_at
  ON core_vendas_faturamento.pedidos_vendas_liberacao (updated_at);
COMMENT ON COLUMN core_vendas_faturamento.pedidos_vendas_liberacao.acompanhamento_qualidade IS
  'true = Qualidade acompanha desde o início; false = só inspeção no fim. Sem linha = pedido não liberado (o MES não enxerga).';
COMMENT ON COLUMN core_vendas_faturamento.pedidos_vendas_liberacao.importado_mes_em IS
  'Quando o MES confirmou a importação na Carteira. Preenchido, a marcação não muda mais.';

-- A3. Histórico (quem liberou, quem trocou, quando o MES importou).
CREATE TABLE IF NOT EXISTS core_vendas_faturamento.pedidos_vendas_liberacao_historico (
  id                        uuid        PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa            uuid        NOT NULL,
  numero_pedido             varchar(15) NOT NULL,
  acao                      varchar(20) NOT NULL CHECK (acao IN ('liberado', 'alterado', 'importado_mes')),
  acompanhamento_qualidade  boolean     NOT NULL,
  valor_anterior            boolean,
  usuario                   uuid,
  referencia                varchar(60),
  created_at                timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pedidos_vendas_liberacao_hist_pedido
  ON core_vendas_faturamento.pedidos_vendas_liberacao_historico (codigo_empresa, numero_pedido, created_at);

-- A4. Regras no banco: quem liberou não muda; marcação trava depois do MES;
-- importação não se desfaz; updated_at sempre do servidor.
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_pedidos_vendas_liberacao_regras()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    NEW.liberado_por := OLD.liberado_por;
    NEW.liberado_em  := OLD.liberado_em;
    IF OLD.importado_mes_em IS NOT NULL THEN
      IF NEW.acompanhamento_qualidade IS DISTINCT FROM OLD.acompanhamento_qualidade THEN
        RAISE EXCEPTION 'Pedido % já foi importado pelo PCP (MES) em %: o acompanhamento da Qualidade não pode mais ser alterado pelo vendedor.',
          OLD.numero_pedido, to_char(OLD.importado_mes_em AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI')
          USING ERRCODE = '23514';
      END IF;
      NEW.importado_mes_em := OLD.importado_mes_em;  -- não desfaz nem reescreve
      NEW.importado_mes_referencia := OLD.importado_mes_referencia;
    END IF;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_pedidos_vendas_liberacao_regras ON core_vendas_faturamento.pedidos_vendas_liberacao;
CREATE TRIGGER trg_pedidos_vendas_liberacao_regras
  BEFORE INSERT OR UPDATE ON core_vendas_faturamento.pedidos_vendas_liberacao
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_pedidos_vendas_liberacao_regras();

CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_pedidos_vendas_liberacao_historico()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO core_vendas_faturamento.pedidos_vendas_liberacao_historico
      (codigo_empresa, numero_pedido, acao, acompanhamento_qualidade, usuario)
    VALUES (NEW.codigo_empresa, NEW.numero_pedido, 'liberado', NEW.acompanhamento_qualidade, NEW.liberado_por);
  ELSE
    IF NEW.acompanhamento_qualidade IS DISTINCT FROM OLD.acompanhamento_qualidade THEN
      INSERT INTO core_vendas_faturamento.pedidos_vendas_liberacao_historico
        (codigo_empresa, numero_pedido, acao, acompanhamento_qualidade, valor_anterior, usuario)
      VALUES (NEW.codigo_empresa, NEW.numero_pedido, 'alterado', NEW.acompanhamento_qualidade,
              OLD.acompanhamento_qualidade, NEW.updated_by);
    END IF;
    IF OLD.importado_mes_em IS NULL AND NEW.importado_mes_em IS NOT NULL THEN
      INSERT INTO core_vendas_faturamento.pedidos_vendas_liberacao_historico
        (codigo_empresa, numero_pedido, acao, acompanhamento_qualidade, referencia)
      VALUES (NEW.codigo_empresa, NEW.numero_pedido, 'importado_mes', NEW.acompanhamento_qualidade,
              NEW.importado_mes_referencia);
    END IF;
  END IF;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS trg_pedidos_vendas_liberacao_historico ON core_vendas_faturamento.pedidos_vendas_liberacao;
CREATE TRIGGER trg_pedidos_vendas_liberacao_historico
  AFTER INSERT OR UPDATE ON core_vendas_faturamento.pedidos_vendas_liberacao
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_pedidos_vendas_liberacao_historico();

-- A5. A view: um pedido por linha (o sequencial 0 é o pedido-pai), com os
-- mesmos filtros que a Carteira do MES já usa em /vendas_planilha
-- (grupo LIQUIDO = grupo nulo, etapa <> 0, sem track record).
-- Entra: pedido incluído a partir da data de corte que ainda está Pendente,
-- ou que já foi liberado (esse continua visível depois de faturado).
--
-- Desempenho (medido no banco local, 28/09/2026): a data de corte vai como
-- SUBCONSULTA ESCALAR e a view não tem DISTINCT ON — assim os filtros de
-- unidade/vendedor/data descem para dentro de vw_vendas_planilha (lista de um
-- vendedor: 2,7 s -> ~70 ms). Um pedido por linha já é garantido pelo índice
-- uq_pedidos_vendas_numero_sequencial (sequencial 0, sem track record: 9.869
-- linhas, 9.869 pedidos distintos).
DROP VIEW IF EXISTS core_vendas_faturamento.vw_pedidos_liberacao;
CREATE VIEW core_vendas_faturamento.vw_pedidos_liberacao AS
SELECT p.codigo_empresa,
       u.nome_fantasia                AS filial,
       p.pedido_venda                 AS numero_pedido,
       p.codigo_pedido_omie,
       p.data_inclusao,
       p.hora_inclusao,
       p.data_previsao,
       p.codigo_cliente,
       p.destinatario                 AS cliente,
       p.razao_social_destinatario,
       p.cnpj_cpf_destinatario,
       p.codigo_vendedor,
       p.vendedor,
       p.etapa,
       p.etapa_descricao,
       p.situacao,
       p.total_pedido_venda,
       CASE WHEN l.importado_mes_em IS NOT NULL THEN 'importado'
            WHEN l.numero_pedido    IS NOT NULL THEN 'liberado'
            ELSE 'pendente' END       AS status_liberacao,
       l.acompanhamento_qualidade,
       l.liberado_em,
       l.liberado_por,
       l.updated_by                   AS alterado_por,
       l.updated_at                   AS liberacao_alterada_em,
       l.importado_mes_em
  FROM core_vendas_faturamento.vw_vendas_planilha p
  LEFT JOIN core_vendas_faturamento.pedidos_vendas_liberacao l
         ON l.codigo_empresa = p.codigo_empresa AND l.numero_pedido = p.pedido_venda
  LEFT JOIN core.unidades u ON u.id = p.codigo_empresa
 WHERE p.sequencial = 0
   AND NOT p.is_track_record
   AND p.deleted_at IS NULL
   AND p.grupo IS NULL
   AND p.etapa <> 0
   AND p.pedido_venda IS NOT NULL
   AND p.data_inclusao >= (SELECT data_inicio_liberacao FROM core_vendas_faturamento.parametros_vendas WHERE id = 1)
   AND (l.numero_pedido IS NOT NULL OR p.situacao = 'Pendente');

COMMIT;
```

## Apêndice B — telas e permissões

```sql
-- Apêndice B — tela e permissões
BEGIN;
INSERT INTO auth.telas (nome, id_parent, ordem, ativo, slug)
SELECT 'Liberar Pedidos', NULL, 0, true, 'liberar-pedidos'
 WHERE NOT EXISTS (SELECT 1 FROM auth.telas WHERE slug = 'liberar-pedidos');
-- Vendedor e Admin (Dev) veem e liberam (pode_editar = marcar Sim/Não).
INSERT INTO auth.permissoes (id_perfil, id_tela, pode_visualizar, pode_editar)
SELECT p.id, t.id, true, true
  FROM auth.perfis p CROSS JOIN auth.telas t
 WHERE p.nome IN ('Vendedor', 'Admin (Dev)') AND t.slug = 'liberar-pedidos'
ON CONFLICT (id_perfil, id_tela) DO UPDATE SET pode_visualizar = true, pode_editar = true;
COMMIT;

-- Tela do gerente: todos os pedidos da liberação, SÓ VISUALIZAÇÃO.
-- Mesmos perfis que já veem "Pedidos da Equipe".
BEGIN;
INSERT INTO auth.telas (nome, id_parent, ordem, ativo, slug)
SELECT 'Liberação da Equipe', NULL, 0, true, 'liberacao-equipe'
 WHERE NOT EXISTS (SELECT 1 FROM auth.telas WHERE slug = 'liberacao-equipe');
INSERT INTO auth.permissoes (id_perfil, id_tela, pode_visualizar)
SELECT pe.id_perfil, t.id, true
  FROM auth.permissoes pe
  JOIN auth.telas te ON te.id = pe.id_tela AND te.slug = 'pedidos-equipe'
  CROSS JOIN auth.telas t
 WHERE t.slug = 'liberacao-equipe' AND pe.deleted_at IS NULL AND pe.pode_visualizar
ON CONFLICT (id_perfil, id_tela) DO UPDATE SET pode_visualizar = true;
COMMIT;
```

## Ver também
- [[Indice-Logica-Fora-do-Backend]]
- [[Integracao-AvHub-MES-Especificacao-F1]] — Fluxos 1–3; este contrato é o Fluxo 4
- [[Fluxograma-Telas-por-Bloco]] — tela 1.1
- [[Fluxo-Sistema-no-Meio]] — ato 1b
