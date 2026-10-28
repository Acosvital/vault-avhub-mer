-- ============================================================================
-- Migration sql015 (proposta de 16/10/2026): schema core_comissao, a comissão
-- da proposta. Contrato SQL-018. NÃO executado em produção.
--
-- Estrutura:
--   0. Conferência prévia (só leitura)
--   1. Schema, funções de apoio (histórico imutável, auditoria)
--   2. Parâmetros do motor (com vigência)
--   3. Regras fixas por cliente, exclusões, coordenadores
--   4. Comissão da proposta: dossiê, cálculos, itens, eventos de custo (N16-20)
--   5. Comissão por NF, itens da NF, conferência de Compras, decisões da Controladoria
--   6. Linha do tempo, fila de recálculo, auditoria
--   7. Funções (parâmetros, gravar cálculo, fechar NF, decidir, cancelar)
--   8. Views (vendedor, fila da Controladoria, visão geral, resumo mensal)
--   9. Dependências de core_vendas_faturamento (aplicar DEPOIS do SQL-016/SQL-017)
--
-- Não toca em core_comissionamento. Aditivo e idempotente onde possível.
-- Revisado em 16/10/2026 (N16-18, N16-19, N16-20): colunas da tela do simulador, custo real POR EVENTO com as
-- condições do próprio evento, conferência de Compras, nomes singulares de core_vendas_faturamento no bloco 9.
-- Percentuais em PONTOS PERCENTUAIS (2 = 2%), como no módulo atual.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Conferência prévia (só leitura)
-- ----------------------------------------------------------------------------
--   SELECT extname FROM pg_extension WHERE extname = 'btree_gist';   -- precisa existir
--   SELECT proname FROM pg_proc WHERE proname IN ('uuidv7','set_updated_at');
--   SELECT to_regclass('core.unidades'), to_regclass('core.funcionarios'),
--          to_regclass('auth.usuarios'),
--          to_regclass('core_vendas_faturamento.produto_vendas'),
--          to_regclass('core_vendas_faturamento.notas_fiscais');

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Schema e funções de apoio
-- ----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS core_comissao;
COMMENT ON SCHEMA core_comissao IS 'Contrato SQL-018: comissão da proposta (estimada, recalculada pelo custo real, fechada por NF e decidida pela Controladoria). Substitui, para propostas novas, core_comissionamento, que não é alterado.';

CREATE OR REPLACE FUNCTION core_comissao.fn_log_imutavel() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'O registro de core_comissao.% é histórico: % não é permitido.', TG_TABLE_NAME, TG_OP
    USING ERRCODE = '23514';
END $$;
COMMENT ON FUNCTION core_comissao.fn_log_imutavel() IS 'Trigger BEFORE UPDATE/DELETE das tabelas de histórico (só INSERT).';

CREATE TABLE IF NOT EXISTS core_comissao.auditoria (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tabela       varchar(40) NOT NULL,
  id_registro  uuid NOT NULL,
  operacao     varchar(6)  NOT NULL,
  dados_antes  jsonb,
  dados_depois jsonb,
  feito_por    uuid,
  feito_em     timestamptz NOT NULL DEFAULT now(),
  usuario_banco text NOT NULL DEFAULT CURRENT_USER,
  CONSTRAINT ck_auditoria_operacao CHECK (operacao IN ('INSERT','UPDATE','DELETE'))
);
CREATE INDEX IF NOT EXISTS ix_auditoria_registro ON core_comissao.auditoria (tabela, id_registro, feito_em);
COMMENT ON TABLE core_comissao.auditoria IS 'Quem mudou parâmetro, regra, exclusão ou coordenador, quando, antes e depois. Só INSERT. Alimentada por core_comissao.fn_auditar().';

CREATE OR REPLACE FUNCTION core_comissao.fn_auditar() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_n jsonb; v_o jsonb; v_id uuid; v_quem uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_n := to_jsonb(NEW); v_id := NEW.id;
    v_quem := NULLIF(v_n ->> 'created_by', '')::uuid;
    INSERT INTO core_comissao.auditoria (tabela, id_registro, operacao, dados_depois, feito_por)
    VALUES (TG_TABLE_NAME, v_id, TG_OP, v_n, v_quem);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    v_n := to_jsonb(NEW); v_o := to_jsonb(OLD);
    IF (v_n - 'updated_at') IS DISTINCT FROM (v_o - 'updated_at') THEN
      v_quem := COALESCE(NULLIF(v_n ->> 'deleted_by', ''), NULLIF(v_n ->> 'updated_by', ''))::uuid;
      INSERT INTO core_comissao.auditoria (tabela, id_registro, operacao, dados_antes, dados_depois, feito_por)
      VALUES (TG_TABLE_NAME, NEW.id, TG_OP, v_o, v_n, v_quem);
    END IF;
    RETURN NEW;
  ELSE
    v_o := to_jsonb(OLD);
    v_quem := COALESCE(NULLIF(v_o ->> 'deleted_by', ''), NULLIF(v_o ->> 'updated_by', ''))::uuid;
    INSERT INTO core_comissao.auditoria (tabela, id_registro, operacao, dados_antes, feito_por)
    VALUES (TG_TABLE_NAME, OLD.id, TG_OP, v_o, v_quem);
    RETURN OLD;
  END IF;
END $$;
COMMENT ON FUNCTION core_comissao.fn_auditar() IS 'Trigger AFTER INSERT/UPDATE/DELETE: grava antes e depois em core_comissao.auditoria. Exige coluna id uuid.';

CREATE TRIGGER trg_auditoria_imutavel BEFORE UPDATE OR DELETE ON core_comissao.auditoria
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_log_imutavel();

-- ----------------------------------------------------------------------------
-- 2. Parâmetros do motor (substitui simulador_parametros; JSON vira tabelas)
-- ----------------------------------------------------------------------------
CREATE TABLE core_comissao.parametros (
  id                        uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa            uuid NOT NULL REFERENCES core.unidades(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  vigencia_inicio           date NOT NULL,
  vigencia_fim              date,
  descricao                 varchar(60) NOT NULL,
  margem_desejada_pct       numeric(7,4)  NOT NULL,
  despesas_operacionais_pct numeric(10,6) NOT NULL,
  rateio_logistica_pct      numeric(10,6) NOT NULL,
  provisao_comissao_pct     numeric(7,4)  NOT NULL,
  pis_pct                   numeric(7,4)  NOT NULL,
  cofins_pct                numeric(7,4)  NOT NULL,
  irpj_base_pct             numeric(7,4)  NOT NULL,
  irpj_pct                  numeric(7,4)  NOT NULL,
  csll_base_pct             numeric(7,4)  NOT NULL,
  csll_pct                  numeric(7,4)  NOT NULL,
  adicional_ir_pct          numeric(7,4)  NOT NULL,
  fabricacao_interna_pct    numeric(7,4)  NOT NULL,
  exige_conferencia_compras boolean       NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  CONSTRAINT ck_parametros_vigencia CHECK (vigencia_fim IS NULL OR vigencia_fim >= vigencia_inicio),
  CONSTRAINT ck_parametros_mes CHECK (extract(day FROM vigencia_inicio) = 1),
  CONSTRAINT ck_parametros_pcts CHECK (
        margem_desejada_pct BETWEEN 0 AND 100 AND despesas_operacionais_pct BETWEEN 0 AND 100
    AND rateio_logistica_pct BETWEEN 0 AND 100 AND provisao_comissao_pct BETWEEN 0 AND 100
    AND pis_pct BETWEEN 0 AND 100 AND cofins_pct BETWEEN 0 AND 100
    AND irpj_base_pct BETWEEN 0 AND 100 AND irpj_pct BETWEEN 0 AND 100
    AND csll_base_pct BETWEEN 0 AND 100 AND csll_pct BETWEEN 0 AND 100
    AND adicional_ir_pct BETWEEN 0 AND 100 AND fabricacao_interna_pct BETWEEN 0 AND 100),
  CONSTRAINT ex_parametros_sem_sobreposicao
    EXCLUDE USING gist (codigo_empresa WITH =, daterange(vigencia_inicio, vigencia_fim, '[]') WITH &&)
);
CREATE INDEX ix_parametros_vigencia ON core_comissao.parametros (codigo_empresa, vigencia_inicio DESC);
COMMENT ON TABLE core_comissao.parametros IS 'Parâmetros do motor por unidade e vigência (era simulador_parametros). Linha usada por um cálculo é IMUTÁVEL (só vigencia_fim muda): para mudar percentual, feche a vigência e abra outra. Detalhes em parametros_*.';
COMMENT ON COLUMN core_comissao.parametros.vigencia_inicio IS 'Parâmetros são por MÊS (N16-19): a vigência começa no dia 1 (a tela mostra "Parâmetros: Maio/23"; hoje: 2023-05-01, descricao Maio/23).';
COMMENT ON COLUMN core_comissao.parametros.despesas_operacionais_pct IS 'Soma das despesas operacionais, pontos percentuais. É o valor que o motor usa; parametros_despesas guarda o detalhe (tolerância de 0,00001: na carga atual o detalhe soma 11,451733 e o agregado é 11,451734).';
COMMENT ON COLUMN core_comissao.parametros.provisao_comissao_pct IS 'Comissão máxima provisionada dentro do mark-up e descontada da margem do item (era pct_comissao_provisao).';
COMMENT ON COLUMN core_comissao.parametros.fabricacao_interna_pct IS 'Percentual fixo pago ao item de fabricação interna.';
COMMENT ON COLUMN core_comissao.parametros.exige_conferencia_compras IS '🟡 OQ-28: true = a Controladoria só aprova, corta ou altera a NF depois de Compras confirmar o percentual (o passo "Comissão: após a aprovação de Compras" do simulador atual). Padrão false (o cálculo REAL pelo custo da OC substitui a versão de Compras).';

CREATE TABLE core_comissao.parametros_despesas (
  id            uuid PRIMARY KEY DEFAULT uuidv7(),
  id_parametros uuid NOT NULL REFERENCES core_comissao.parametros(id) ON DELETE RESTRICT,
  categoria     varchar(30) NOT NULL,
  pct           numeric(10,6) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  CONSTRAINT ck_parametros_despesas_categoria CHECK (categoria = upper(btrim(categoria)) AND categoria <> ''),
  CONSTRAINT ck_parametros_despesas_pct CHECK (pct BETWEEN 0 AND 100),
  CONSTRAINT uq_parametros_despesas UNIQUE (id_parametros, categoria)
);
COMMENT ON TABLE core_comissao.parametros_despesas IS 'Detalhe das despesas operacionais (SEDES, PESSOAL, PRODUCAO, LOGISTICA, MARKETING, TERCEIROS, FINANCEIRAS, CONTRIBUICOES, ADMINISTRATIVAS). Só auditoria: o motor usa o agregado de parametros.';

CREATE TABLE core_comissao.parametros_icms_saida (
  id            uuid PRIMARY KEY DEFAULT uuidv7(),
  id_parametros uuid NOT NULL REFERENCES core_comissao.parametros(id) ON DELETE RESTRICT,
  destino       varchar(12) NOT NULL,
  rotulo        varchar(60) NOT NULL,
  aliquota_pct  numeric(7,4) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  CONSTRAINT ck_parametros_icms_saida_destino CHECK (destino = upper(btrim(destino)) AND destino <> ''),
  CONSTRAINT ck_parametros_icms_saida_aliquota CHECK (aliquota_pct BETWEEN 0 AND 100),
  CONSTRAINT uq_parametros_icms_saida UNIQUE (id_parametros, destino)
);
COMMENT ON TABLE core_comissao.parametros_icms_saida IS 'ICMS de saída por destino da venda. destino = UF (SP, MG, PR, RJ, SC, RS), DEMAIS (demais estados) ou IMPORTACAO (alíquota usada no mark-up de importação). Substitui o JSON icms_saida.';

CREATE TABLE core_comissao.parametros_icms_entrada (
  id            uuid PRIMARY KEY DEFAULT uuidv7(),
  id_parametros uuid NOT NULL REFERENCES core_comissao.parametros(id) ON DELETE RESTRICT,
  origem_compra varchar(25) NOT NULL,
  aliquota_pct  numeric(7,4) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  CONSTRAINT ck_parametros_icms_entrada_origem CHECK (origem_compra IN ('SP','SP_REDUZIDA','OUTRA_UF','IMPORTACAO_SP','IMPORTACAO_OUTRA_UF','SIMPLES')),
  CONSTRAINT ck_parametros_icms_entrada_aliquota CHECK (aliquota_pct BETWEEN 0 AND 100),
  CONSTRAINT uq_parametros_icms_entrada UNIQUE (id_parametros, origem_compra)
);
COMMENT ON TABLE core_comissao.parametros_icms_entrada IS 'ICMS recuperável na compra por origem. Códigos iguais aos de OrigemIcmsCompra do Comercial. Substitui o JSON icms_entrada (que casava por texto).';

CREATE TABLE core_comissao.parametros_encargos_pagamento (
  id                 uuid PRIMARY KEY DEFAULT uuidv7(),
  id_parametros      uuid NOT NULL REFERENCES core_comissao.parametros(id) ON DELETE RESTRICT,
  condicao_pagamento varchar(40) NOT NULL,
  encargo_pct        numeric(7,4) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  CONSTRAINT ck_parametros_encargos_pct CHECK (encargo_pct BETWEEN 0 AND 100),
  CONSTRAINT uq_parametros_encargos UNIQUE (id_parametros, condicao_pagamento)
);
COMMENT ON TABLE core_comissao.parametros_encargos_pagamento IS 'Encargo financeiro somado ao preço sugerido por condição de pagamento. Substitui o JSON encargos_pagamento.';

CREATE TABLE core_comissao.parametros_faixas (
  id              uuid PRIMARY KEY DEFAULT uuidv7(),
  id_parametros   uuid NOT NULL REFERENCES core_comissao.parametros(id) ON DELETE RESTRICT,
  letra           char(1) NOT NULL,
  margem_min_pct  numeric(7,4) NOT NULL,
  comissao_pct    numeric(7,4) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  CONSTRAINT ck_parametros_faixas_letra CHECK (letra IN ('A','B','C','D')),
  CONSTRAINT ck_parametros_faixas_comissao CHECK (comissao_pct BETWEEN 0 AND 100),
  CONSTRAINT uq_parametros_faixas_letra UNIQUE (id_parametros, letra),
  CONSTRAINT uq_parametros_faixas_margem UNIQUE (id_parametros, margem_min_pct)
);
COMMENT ON TABLE core_comissao.parametros_faixas IS 'Faixas da letra: margem líquida mínima do item (semiaberto [min, próxima)) e percentual. Hoje A 15/2,0; B 12/1,3; C 9/0,7; D 0/0,5. Substitui o JSON faixas_comissao.';

-- Travas: parâmetro usado por cálculo não muda; parâmetro novo nasce completo.
CREATE OR REPLACE FUNCTION core_comissao.fn_parametros_travar() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_id uuid;
BEGIN
  IF TG_TABLE_NAME = 'parametros' THEN
    v_id := COALESCE(OLD.id, NEW.id);
  ELSE
    v_id := COALESCE(NEW.id_parametros, OLD.id_parametros);
  END IF;
  IF EXISTS (SELECT 1 FROM core_comissao.comissao_calculos c WHERE c.id_parametros = v_id) THEN
    IF TG_TABLE_NAME = 'parametros' AND TG_OP = 'UPDATE'
       AND (to_jsonb(NEW) - 'vigencia_fim' - 'updated_at' - 'updated_by')
           IS NOT DISTINCT FROM (to_jsonb(OLD) - 'vigencia_fim' - 'updated_at' - 'updated_by') THEN
      RETURN NEW;  -- só fechou a vigência
    END IF;
    RAISE EXCEPTION 'Parâmetros já usados por cálculo de comissão não mudam: feche a vigência e abra outra.'
      USING ERRCODE = '23514';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_parametros_travar BEFORE UPDATE OR DELETE ON core_comissao.parametros
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_parametros_travar();
CREATE TRIGGER trg_parametros_despesas_travar BEFORE INSERT OR UPDATE OR DELETE ON core_comissao.parametros_despesas
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_parametros_travar();
CREATE TRIGGER trg_parametros_icms_saida_travar BEFORE INSERT OR UPDATE OR DELETE ON core_comissao.parametros_icms_saida
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_parametros_travar();
CREATE TRIGGER trg_parametros_icms_entrada_travar BEFORE INSERT OR UPDATE OR DELETE ON core_comissao.parametros_icms_entrada
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_parametros_travar();
CREATE TRIGGER trg_parametros_encargos_travar BEFORE INSERT OR UPDATE OR DELETE ON core_comissao.parametros_encargos_pagamento
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_parametros_travar();
CREATE TRIGGER trg_parametros_faixas_travar BEFORE INSERT OR UPDATE OR DELETE ON core_comissao.parametros_faixas
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_parametros_travar();

CREATE OR REPLACE FUNCTION core_comissao.fn_parametros_completo() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM core_comissao.parametros_faixas f WHERE f.id_parametros = NEW.id AND f.margem_min_pct = 0) THEN
    RAISE EXCEPTION 'Parâmetros sem faixa de margem mínima 0: o motor não teria letra para margem baixa.' USING ERRCODE = '23514';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM core_comissao.parametros_icms_saida s WHERE s.id_parametros = NEW.id)
     OR NOT EXISTS (SELECT 1 FROM core_comissao.parametros_icms_entrada e WHERE e.id_parametros = NEW.id)
     OR NOT EXISTS (SELECT 1 FROM core_comissao.parametros_encargos_pagamento p WHERE p.id_parametros = NEW.id) THEN
    RAISE EXCEPTION 'Parâmetros incompletos: faltam ICMS de saída, ICMS de entrada ou encargos de pagamento.' USING ERRCODE = '23514';
  END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER trg_parametros_completo AFTER INSERT ON core_comissao.parametros
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_parametros_completo();

-- ----------------------------------------------------------------------------
-- 3. Regras fixas por cliente, exclusões, coordenadores
-- ----------------------------------------------------------------------------
CREATE TABLE core_comissao.regras_fixas_cliente (
  id                       uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa           uuid NOT NULL REFERENCES core.unidades(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  codigo_cliente           varchar(60) NOT NULL,
  vigencia_inicio          date NOT NULL,
  vigencia_fim             date,
  gatilho_markup_pct       numeric(8,4) NOT NULL,
  comissao_padrao_pct      numeric(7,4) NOT NULL,
  comissao_condicional_pct numeric(7,4) NOT NULL,
  motivo                   text,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  deleted_at timestamptz, deleted_by uuid,
  CONSTRAINT ck_regras_fixas_codigo CHECK (btrim(codigo_cliente) <> ''),
  CONSTRAINT ck_regras_fixas_vigencia CHECK (vigencia_fim IS NULL OR vigencia_fim >= vigencia_inicio),
  CONSTRAINT ck_regras_fixas_pcts CHECK (comissao_padrao_pct BETWEEN 0 AND 100 AND comissao_condicional_pct BETWEEN 0 AND 100 AND gatilho_markup_pct BETWEEN 0 AND 1000),
  CONSTRAINT ck_regras_fixas_ordem CHECK (comissao_condicional_pct >= comissao_padrao_pct),
  CONSTRAINT ex_regras_fixas_sem_sobreposicao
    EXCLUDE USING gist (codigo_empresa WITH =, codigo_cliente WITH =, daterange(vigencia_inicio, vigencia_fim, '[]') WITH &&)
    WHERE (deleted_at IS NULL)
);
COMMENT ON TABLE core_comissao.regras_fixas_cliente IS 'Teto de comissão por cliente e vigência (era regras_comissoes_fixas). Limita só item de REVENDA com regra LETRA. Gatilho: markup bruto do pedido >= gatilho_markup_pct usa a condicional, senão a padrão.';
COMMENT ON COLUMN core_comissao.regras_fixas_cliente.gatilho_markup_pct IS 'Era `margem`. Compara com o MARKUP BRUTO do pedido ((total NF - compra bruta) / compra bruta), não com a margem líquida da letra.';
COMMENT ON COLUMN core_comissao.regras_fixas_cliente.codigo_cliente IS 'Código Omie do parceiro (varchar(60), como notas_fiscais.codigo_cliente). Só é único dentro da unidade.';
COMMENT ON COLUMN core_comissao.regras_fixas_cliente.comissao_condicional_pct IS 'CHECK condicional >= padrão é proposta 🟡 (o módulo atual não impede o contrário).';

CREATE OR REPLACE FUNCTION core_comissao.fn_regra_fixa_travar() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM core_comissao.comissao_calculos c WHERE c.id_regra_fixa = OLD.id)
     AND (to_jsonb(NEW) - 'vigencia_fim' - 'deleted_at' - 'deleted_by' - 'updated_at' - 'updated_by' - 'motivo')
         IS DISTINCT FROM (to_jsonb(OLD) - 'vigencia_fim' - 'deleted_at' - 'deleted_by' - 'updated_at' - 'updated_by' - 'motivo') THEN
    RAISE EXCEPTION 'Regra fixa já usada por cálculo de comissão não muda: feche a vigência e abra outra.' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_regras_fixas_travar BEFORE UPDATE ON core_comissao.regras_fixas_cliente
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_regra_fixa_travar();

CREATE TABLE core_comissao.exclusoes (
  id              uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa  uuid NOT NULL REFERENCES core.unidades(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  tipo            varchar(10) NOT NULL,
  codigo_omie     varchar(60) NOT NULL,
  vigencia_inicio date NOT NULL DEFAULT CURRENT_DATE,
  vigencia_fim    date,
  motivo          text NOT NULL,
  data_criacao_original date,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  deleted_at timestamptz, deleted_by uuid,
  CONSTRAINT ck_exclusoes_tipo CHECK (tipo IN ('CLIENTE','VENDEDOR')),
  CONSTRAINT ck_exclusoes_codigo CHECK (btrim(codigo_omie) <> '' AND (tipo = 'CLIENTE' OR char_length(codigo_omie) <= 11)),
  CONSTRAINT ck_exclusoes_motivo CHECK (char_length(btrim(motivo)) >= 3),
  CONSTRAINT ck_exclusoes_vigencia CHECK (vigencia_fim IS NULL OR vigencia_fim >= vigencia_inicio),
  CONSTRAINT ex_exclusoes_sem_sobreposicao
    EXCLUDE USING gist (codigo_empresa WITH =, tipo WITH =, codigo_omie WITH =, daterange(vigencia_inicio, vigencia_fim, '[]') WITH &&)
    WHERE (deleted_at IS NULL)
);
COMMENT ON COLUMN core_comissao.exclusoes.data_criacao_original IS 'Data em que o cliente ou vendedor entrou na lista do módulo antigo (A24). Na migração a vigência começa em 2000-01-01 e esta coluna guarda a data original, para rastro.';
COMMENT ON TABLE core_comissao.exclusoes IS 'Cliente ou vendedor fora do comissionamento, com vigência e motivo obrigatório (era blacklist_comissoes_destinatario e blacklist_comissoes_vendedores). A comissão excluída NÃO some: fica com valor 0 e motivo_zerado visível à Controladoria.';

CREATE TABLE core_comissao.coordenadores (
  id             uuid PRIMARY KEY DEFAULT uuidv7(),
  nome           varchar(100) NOT NULL,
  id_funcionario uuid REFERENCES core.funcionarios(id),
  ativo          boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  CONSTRAINT ck_coordenadores_nome CHECK (btrim(nome) <> '')
);
CREATE UNIQUE INDEX uq_coordenadores_nome ON core_comissao.coordenadores (lower(btrim(nome)));
COMMENT ON TABLE core_comissao.coordenadores IS '🟡 Depende da OQ-06. Pessoa que recebe ajuda de custo e comissão sobre o faturamento total do mês (não depende de proposta). Os valores ficam em coordenadores_regras, por vigência.';

CREATE TABLE core_comissao.coordenadores_regras (
  id               uuid PRIMARY KEY DEFAULT uuidv7(),
  id_coordenador   uuid NOT NULL REFERENCES core_comissao.coordenadores(id) ON DELETE RESTRICT,
  tipo             varchar(10) NOT NULL,
  ajuda_custo      numeric(14,2) NOT NULL DEFAULT 0,
  percentual_pct   numeric(7,4)  NOT NULL DEFAULT 0,
  ordem_desempate  smallint NOT NULL DEFAULT 0,
  vigencia_inicio  date NOT NULL,
  vigencia_fim     date,
  observacao       text,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  CONSTRAINT ck_coord_regras_tipo CHECK (tipo IN ('GERENCIA','EXCECAO')),
  CONSTRAINT ck_coord_regras_ajuda CHECK (ajuda_custo >= 0),
  CONSTRAINT ck_coord_regras_pct CHECK (percentual_pct BETWEEN 0 AND 100),
  CONSTRAINT ck_coord_regras_vigencia CHECK (vigencia_fim IS NULL OR vigencia_fim >= vigencia_inicio),
  CONSTRAINT ex_coord_regras_sem_sobreposicao
    EXCLUDE USING gist (id_coordenador WITH =, daterange(vigencia_inicio, vigencia_fim, '[]') WITH &&)
);
COMMENT ON TABLE core_comissao.coordenadores_regras IS 'Ajuda de custo e percentual do coordenador por vigência. GERENCIA = ranking da gerência; EXCECAO = entra no ranking de vendedores com o mesmo cálculo. Mudar valor = fechar a vigência e abrir outra.';
COMMENT ON COLUMN core_comissao.coordenadores_regras.percentual_pct IS 'Pontos percentuais: 0,35 = 0,35% do faturamento total do mês.';
COMMENT ON COLUMN core_comissao.coordenadores_regras.ordem_desempate IS 'Desempate do ranking quando o total empata (menor primeiro).';

CREATE TABLE core_comissao.coordenadores_apuracoes (
  id               uuid PRIMARY KEY DEFAULT uuidv7(),
  competencia      date NOT NULL,
  id_coordenador   uuid NOT NULL REFERENCES core_comissao.coordenadores(id) ON DELETE RESTRICT,
  id_regra         uuid NOT NULL REFERENCES core_comissao.coordenadores_regras(id) ON DELETE RESTRICT,
  tipo             varchar(10) NOT NULL,
  faturamento_base numeric(15,2) NOT NULL,
  percentual_pct   numeric(7,4)  NOT NULL,
  ajuda_custo      numeric(14,2) NOT NULL,
  comissao         numeric(15,2) NOT NULL,
  total            numeric(15,2) NOT NULL,
  ordem_desempate  smallint NOT NULL,
  gerada_em        timestamptz NOT NULL DEFAULT now(),
  gerada_por       uuid,
  fechada_em       timestamptz,
  fechada_por      uuid,
  CONSTRAINT ck_coord_apuracoes_competencia CHECK (competencia = date_trunc('month', competencia)::date),
  CONSTRAINT ck_coord_apuracoes_tipo CHECK (tipo IN ('GERENCIA','EXCECAO')),
  CONSTRAINT uq_coord_apuracoes UNIQUE (competencia, id_coordenador)
);
COMMENT ON TABLE core_comissao.coordenadores_apuracoes IS '🟡 Foto mensal da comissão dos coordenadores: comissao = round(percentual/100 x faturamento_base, 2); total = ajuda_custo + comissao. O bloqueio/decisão por NF NÃO reduz (decisão do Nathan de 06/10/2026, contrato 38). Depois de fechada não muda.';

CREATE OR REPLACE FUNCTION core_comissao.fn_apuracao_travar() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.fechada_em IS NOT NULL AND (TG_OP = 'DELETE' OR (to_jsonb(NEW) IS DISTINCT FROM to_jsonb(OLD))) THEN
    RAISE EXCEPTION 'Apuração de coordenador já fechada não muda.' USING ERRCODE = '23514';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_coord_apuracoes_travar BEFORE UPDATE OR DELETE ON core_comissao.coordenadores_apuracoes
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_apuracao_travar();

-- ----------------------------------------------------------------------------
-- 4. Comissão da proposta: dossiê, cálculos, itens
-- ----------------------------------------------------------------------------
CREATE TABLE core_comissao.comissoes (
  id                   uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa       uuid NOT NULL REFERENCES core.unidades(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  id_proposta          uuid NOT NULL,
  id_pedido_venda      uuid,
  numero_proposta      varchar(20) NOT NULL,
  numero_pedido        varchar(20),
  codigo_vendedor_omie varchar(11) NOT NULL,
  codigo_cliente       varchar(60) NOT NULL,
  id_usuario_vendedor  uuid,
  estado               varchar(20) NOT NULL DEFAULT 'ESTIMADA',
  id_calculo_cotado    uuid,
  id_calculo_real      uuid,
  custo_real_acima_cotado boolean NOT NULL DEFAULT false,
  proposta_aprovada_em timestamptz,
  encerrada_em         timestamptz,
  cancelada_em         timestamptz,
  cancelada_por        uuid,
  motivo_cancelamento  text,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  CONSTRAINT ck_comissoes_estado CHECK (estado IN ('ESTIMADA','CONGELADA','EM_ACOMPANHAMENTO','ENCERRADA','CANCELADA')),
  CONSTRAINT ck_comissoes_cancelada CHECK ((estado = 'CANCELADA') = (cancelada_em IS NOT NULL)),
  CONSTRAINT ck_comissoes_motivo CHECK (estado <> 'CANCELADA' OR char_length(btrim(COALESCE(motivo_cancelamento, ''))) >= 3),
  CONSTRAINT ck_comissoes_pedido CHECK (estado NOT IN ('EM_ACOMPANHAMENTO','ENCERRADA') OR id_pedido_venda IS NOT NULL),
  CONSTRAINT uq_comissoes_proposta UNIQUE (id_proposta),
  CONSTRAINT uq_comissoes_pedido UNIQUE (id_pedido_venda)
);
CREATE INDEX ix_comissoes_vendedor ON core_comissao.comissoes (codigo_empresa, codigo_vendedor_omie, estado);
CREATE INDEX ix_comissoes_estado ON core_comissao.comissoes (estado, updated_at DESC);
COMMENT ON TABLE core_comissao.comissoes IS 'Dossiê da comissão de UMA proposta (uma proposta = um pedido, N16-02). Nasce estimada na V0.3 e acompanha a proposta até o encerramento ou o cancelamento. Cancelada vira histórico consultável.';
COMMENT ON COLUMN core_comissao.comissoes.estado IS 'ESTIMADA (proposta ajustável) > CONGELADA (proposta aprovada, estimativa travada) > EM_ACOMPANHAMENTO (pedido criado, custo real chegando, NFs) > ENCERRADA. CANCELADA = histórico.';
COMMENT ON COLUMN core_comissao.comissoes.id_usuario_vendedor IS 'Usuário do hub que é o vendedor da comissão. Serve à trava "ninguém decide sobre a própria comissão" (N16-44): quem tem esse id não decide a comissão nem os lançamentos dela. A API preenche a partir do vendedor.';
COMMENT ON COLUMN core_comissao.comissoes.id_calculo_cotado IS 'Cálculo do vendedor que vale (o último antes da aprovação da proposta).';
COMMENT ON COLUMN core_comissao.comissoes.id_calculo_real IS 'Último cálculo feito com o custo real.';
COMMENT ON COLUMN core_comissao.comissoes.custo_real_acima_cotado IS 'Só para a Controladoria e a Gerência. NUNCA sai nas telas do vendedor (N16-18).';

CREATE TABLE core_comissao.comissao_calculos (
  id                    uuid PRIMARY KEY DEFAULT uuidv7(),
  id_comissao           uuid NOT NULL REFERENCES core_comissao.comissoes(id) ON DELETE RESTRICT,
  sequencia             integer NOT NULL,
  tipo                  varchar(6) NOT NULL,
  gatilho               varchar(20) NOT NULL,
  id_parametros         uuid NOT NULL REFERENCES core_comissao.parametros(id),
  id_regra_fixa         uuid REFERENCES core_comissao.regras_fixas_cliente(id),
  versao_motor          varchar(20) NOT NULL,
  estado_destino        varchar(12) NOT NULL,
  icms_destino_pct      numeric(7,4) NOT NULL,
  condicao_pagamento    varchar(40) NOT NULL,
  encargo_pagamento_pct numeric(7,4) NOT NULL,
  isento_imposto        boolean NOT NULL DEFAULT false,
  frete_compra_tipo     varchar(6)  NOT NULL DEFAULT 'RATEIO',
  frete_compra_total    numeric(15,2) NOT NULL DEFAULT 0,
  valor_st_venda        numeric(15,2) NOT NULL DEFAULT 0,
  imposto_retido_difal  numeric(15,2) NOT NULL DEFAULT 0,
  frete_venda           numeric(15,2) NOT NULL DEFAULT 0,
  custo_total           numeric(15,2) NOT NULL,
  venda_sugerida        numeric(15,2) NOT NULL,
  valor_liquido         numeric(15,2) NOT NULL,
  total_nf              numeric(15,2) NOT NULL,
  markup_projetado      numeric(10,4),
  markup_real           numeric(10,4),
  markup_bruto_pct      numeric(10,4) NOT NULL,
  margem_liquida_pct    numeric(10,4) NOT NULL,
  lucro                 numeric(15,2) NOT NULL,
  letra_equivalente     char(1),
  comissao_efetiva_pct  numeric(7,4) NOT NULL,
  valor_comissao_total  numeric(15,2) NOT NULL,
  qtd_itens             integer NOT NULL,
  qtd_itens_prejuizo    integer NOT NULL DEFAULT 0,
  custo_completo        boolean NOT NULL DEFAULT false,
  imposto_completo      boolean NOT NULL DEFAULT true,
  avisos                jsonb NOT NULL DEFAULT '[]'::jsonb,
  calculado_em          timestamptz NOT NULL DEFAULT now(),
  calculado_por         uuid,
  CONSTRAINT ck_calculos_tipo CHECK (tipo IN ('COTADO','REAL')),
  CONSTRAINT ck_calculos_gatilho CHECK (gatilho IN ('PROPOSTA_SALVA','CUSTO_REAL','REPROCESSAMENTO')),
  CONSTRAINT ck_calculos_frete_tipo CHECK (frete_compra_tipo IN ('RATEIO','VALOR')),
  CONSTRAINT ck_calculos_letra CHECK (letra_equivalente IS NULL OR letra_equivalente IN ('A','B','C','D')),
  CONSTRAINT ck_calculos_pct CHECK (comissao_efetiva_pct BETWEEN 0 AND 100),
  CONSTRAINT ck_calculos_avisos CHECK (jsonb_typeof(avisos) = 'array'),
  CONSTRAINT uq_calculos_sequencia UNIQUE (id_comissao, sequencia)
);
CREATE INDEX ix_calculos_comissao ON core_comissao.comissao_calculos (id_comissao, tipo, sequencia DESC);
CREATE INDEX ix_calculos_parametros ON core_comissao.comissao_calculos (id_parametros);
CREATE INDEX ix_calculos_regra ON core_comissao.comissao_calculos (id_regra_fixa) WHERE id_regra_fixa IS NOT NULL;
CREATE TRIGGER trg_calculos_imutavel BEFORE UPDATE OR DELETE ON core_comissao.comissao_calculos
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_log_imutavel();
COMMENT ON TABLE core_comissao.comissao_calculos IS 'Cada execução do motor sobre uma comissão. COTADO = com o custo que o vendedor pôs na proposta; REAL = com o custo real do pedido. Só INSERT: cada recálculo é uma linha nova, então o histórico (inclusive de proposta cancelada) nunca se perde.';
COMMENT ON COLUMN core_comissao.comissao_calculos.markup_bruto_pct IS 'O "AC8": (total NF de revenda - compra bruta) / compra bruta. Gatilho da regra fixa. Não é a margem líquida que decide a letra.';
COMMENT ON COLUMN core_comissao.comissao_calculos.custo_completo IS 'REAL: true quando todos os itens de revenda têm a quantidade inteira coberta por custo real.';
COMMENT ON COLUMN core_comissao.comissao_calculos.estado_destino IS 'Código de parametros_icms_saida.destino (SP, MG, PR, RJ, SC, RS, DEMAIS). A tela mostra rotulo e icms_destino_pct (ex.: São Paulo, ICMS 18%).';
COMMENT ON COLUMN core_comissao.comissao_calculos.encargo_pagamento_pct IS 'Encargo da condição de pagamento da VENDA; entra só no preço sugerido (motor.ts:324), não no custo nem na margem.';
COMMENT ON COLUMN core_comissao.comissao_calculos.markup_real IS 'MARK-UP REAL da tela: arredondarParaCima(venda de revenda / custo total, 2) (motor.ts:535).';
COMMENT ON COLUMN core_comissao.comissao_calculos.markup_projetado IS 'Preço sugerido total / custo total (motor.ts:532).';
COMMENT ON COLUMN core_comissao.comissao_calculos.imposto_completo IS 'REAL: false quando algum evento de custo usou o imposto herdado da proposta por falta de imposto real (OQ-11). Cálculo parcial por imposto.';
COMMENT ON COLUMN core_comissao.comissao_calculos.versao_motor IS 'Versão do código do motor que calculou (ex.: motor-1.0.0), para reproduzir e comparar.';

CREATE TABLE core_comissao.comissao_calculo_itens (
  id                      uuid PRIMARY KEY DEFAULT uuidv7(),
  id_calculo              uuid NOT NULL REFERENCES core_comissao.comissao_calculos(id) ON DELETE RESTRICT,
  ordem                   integer NOT NULL,
  id_item_proposta        uuid NOT NULL,
  id_item_pedido          uuid,
  codigo_item_omie        bigint,
  codigo_produto          varchar(60),
  descricao               text,
  tipo_item               varchar(20) NOT NULL DEFAULT 'REVENDA',
  qtd                     numeric(15,4) NOT NULL,
  unidade                 varchar(20),
  qtd_compra              numeric(15,4),
  unidade_compra          varchar(20),
  fornecedor              varchar(120),
  origem_compra           varchar(25),
  ipi_pct                 numeric(7,4)  NOT NULL DEFAULT 0,
  valor_st                numeric(15,2) NOT NULL DEFAULT 0,
  frete_compra_valor      numeric(15,2) NOT NULL DEFAULT 0,
  preco_unit_compra_cotado numeric(15,4) NOT NULL DEFAULT 0,
  preco_unit_venda        numeric(15,4) NOT NULL,
  quantidade_coberta      numeric(15,4),
  custo_real_total        numeric(15,2),
  custo_real_unitario_medio numeric(15,6),
  custo_completo          boolean NOT NULL DEFAULT false,
  qtd_eventos             integer NOT NULL DEFAULT 0,
  qtd_descoberta          numeric(15,4),
  custo_liquido_descoberto numeric(15,2) NOT NULL DEFAULT 0,
  imposto_completo        boolean NOT NULL DEFAULT true,
  custo_real_acima_cotado boolean NOT NULL DEFAULT false,
  compra_bruta            numeric(15,2) NOT NULL DEFAULT 0,
  icms_entrada_pct        numeric(7,4)  NOT NULL DEFAULT 0,
  icms_recuperar          numeric(15,2) NOT NULL DEFAULT 0,
  valor_ipi               numeric(15,2) NOT NULL DEFAULT 0,
  frete_item              numeric(15,2) NOT NULL DEFAULT 0,
  custo_liquido           numeric(15,2) NOT NULL DEFAULT 0,
  preco_unit_sugerido     numeric(15,4),
  preco_total_sugerido    numeric(15,2),
  venda_item              numeric(15,2) NOT NULL,
  icms_efetivo_pct        numeric(7,4),
  impostos_pct            numeric(7,4),
  lucro_item              numeric(15,2),
  margem_item_pct         numeric(10,4),
  letra_item              char(1),
  comissao_letra_pct      numeric(7,4) NOT NULL,
  teto_regra_pct          numeric(7,4),
  comissao_pct            numeric(7,4) NOT NULL,
  regra_aplicada          varchar(20) NOT NULL,
  valor_comissao_estimado numeric(15,2) NOT NULL,
  CONSTRAINT ck_calc_itens_tipo CHECK (tipo_item IN ('REVENDA','FABRICACAO_INTERNA')),
  CONSTRAINT ck_calc_itens_origem CHECK (origem_compra IS NULL OR origem_compra IN ('SP','SP_REDUZIDA','OUTRA_UF','IMPORTACAO_SP','IMPORTACAO_OUTRA_UF','SIMPLES')),
  CONSTRAINT ck_calc_itens_qtd CHECK (qtd > 0),
  CONSTRAINT ck_calc_itens_letra CHECK (letra_item IS NULL OR letra_item IN ('A','B','C','D')),
  CONSTRAINT ck_calc_itens_pct CHECK (comissao_pct BETWEEN 0 AND 100 AND comissao_letra_pct BETWEEN 0 AND 100),
  CONSTRAINT ck_calc_itens_regra CHECK (regra_aplicada IN ('PREJUIZO','FABRICACAO_INTERNA','LETRA','TETO_PADRAO','TETO_CONDICIONAL')),
  CONSTRAINT ck_calc_itens_coberta CHECK (quantidade_coberta IS NULL OR quantidade_coberta >= 0),
  CONSTRAINT uq_calc_itens_ordem UNIQUE (id_calculo, ordem),
  CONSTRAINT uq_calc_itens_proposta UNIQUE (id_calculo, id_item_proposta)
);
CREATE INDEX ix_calc_itens_omie ON core_comissao.comissao_calculo_itens (id_calculo, codigo_item_omie) WHERE codigo_item_omie IS NOT NULL;
CREATE INDEX ix_calc_itens_pedido ON core_comissao.comissao_calculo_itens (id_item_pedido) WHERE id_item_pedido IS NOT NULL;
CREATE TRIGGER trg_calc_itens_imutavel BEFORE UPDATE OR DELETE ON core_comissao.comissao_calculo_itens
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_log_imutavel();
COMMENT ON TABLE core_comissao.comissao_calculo_itens IS 'Item de um cálculo, com TODAS as entradas e saídas do motor (reprodutível). A comissão é decidida item a item. Só INSERT.';
COMMENT ON COLUMN core_comissao.comissao_calculo_itens.preco_unit_compra_cotado IS 'Preço unitário de compra que o vendedor pôs na proposta (na unidade de compra). No cálculo REAL o custo líquido do item é a SOMA do custo líquido de cada evento (comissao_calculo_eventos, com as condições do próprio evento, N16-20) mais a parte ainda não coberta, calculada com o preço e as condições cotados.';
COMMENT ON COLUMN core_comissao.comissao_calculo_itens.custo_liquido_descoberto IS 'REAL: custo líquido da quantidade ainda não coberta por evento = custo líquido cotado x qtd_descoberta / qtd. Zero quando o item está completo.';
COMMENT ON COLUMN core_comissao.comissao_calculo_itens.qtd_eventos IS 'REAL: quantidade de eventos de custo (OC, lote) somados no item.';
COMMENT ON COLUMN core_comissao.comissao_calculo_itens.custo_real_total IS 'custo_total de core_vendas_faturamento.vw_pedido_item_custo, lido pelo item do pedido = empresa + número do pedido + produto do Omie (N16-102; soma das linhas de OC ou lote, sem impostos no Ciclo 1). Nulo no cálculo COTADO.';
COMMENT ON COLUMN core_comissao.comissao_calculo_itens.comissao_letra_pct IS 'Percentual da letra (ou 0 no prejuízo, ou o fixo da fabricação interna) ANTES do teto da regra fixa.';
COMMENT ON COLUMN core_comissao.comissao_calculo_itens.comissao_pct IS 'Percentual do item neste cálculo, já com o teto da regra fixa. É o "percentual do vendedor" (COTADO) ou "percentual de compras" (REAL) do módulo atual.';
COMMENT ON COLUMN core_comissao.comissao_calculo_itens.valor_comissao_estimado IS 'venda_item x comissao_pct / 100, sobre o valor do pedido. O pagamento real usa o faturado da NF (comissoes_nf_itens).';

-- Vínculo entre o item da proposta e o item do pedido/Omie. O cálculo COTADO nasce antes do pedido, então não conhece
-- o codigo_item_omie; o vínculo é gravado quando o pedido existe e o Omie devolveu os códigos dos itens.
CREATE TABLE core_comissao.comissao_itens_vinculo (
  id               uuid PRIMARY KEY DEFAULT uuidv7(),
  id_comissao      uuid NOT NULL REFERENCES core_comissao.comissoes(id) ON DELETE RESTRICT,
  id_item_proposta uuid NOT NULL,
  id_item_pedido   uuid NOT NULL,
  codigo_item_omie bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT uq_itens_vinculo_proposta UNIQUE (id_comissao, id_item_proposta),
  CONSTRAINT uq_itens_vinculo_omie UNIQUE (id_comissao, codigo_item_omie)
);
COMMENT ON TABLE core_comissao.comissao_itens_vinculo IS 'Liga o item da proposta ao item do pedido e ao codigo_item_omie (chave do item faturado em produto_vendas). Preenchido por fn_comissao_vincular_itens quando o pedido é criado no Omie.';
CREATE OR REPLACE FUNCTION core_comissao.fn_comissao_vincular_itens(p_id_comissao uuid, p_itens jsonb, p_usuario uuid DEFAULT NULL)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE v_n integer;
BEGIN
  INSERT INTO core_comissao.comissao_itens_vinculo (id_comissao, id_item_proposta, id_item_pedido, codigo_item_omie, created_by)
  SELECT p_id_comissao, i.id_item_proposta, i.id_item_pedido, i.codigo_item_omie, p_usuario
    FROM jsonb_to_recordset(p_itens) AS i(id_item_proposta uuid, id_item_pedido uuid, codigo_item_omie bigint)
  ON CONFLICT (id_comissao, id_item_proposta) DO UPDATE SET codigo_item_omie = EXCLUDED.codigo_item_omie, id_item_pedido = EXCLUDED.id_item_pedido;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END $$;
COMMENT ON FUNCTION core_comissao.fn_comissao_vincular_itens(uuid, jsonb, uuid) IS 'Grava (ou corrige) o vínculo item da proposta x item do pedido x codigo_item_omie. Chamada pela API quando o Omie devolve os códigos do pedido.';

-- Evento de custo dentro de um item de cálculo REAL (N16-20). Cada evento (uma OC, um lote, uma parcial 5.01...)
-- carrega as SUAS condições; o custo líquido do evento sai da mesma fórmula do motor (motor.ts:277-312) e o item soma.
CREATE TABLE core_comissao.comissao_calculo_eventos (
  id                    uuid PRIMARY KEY DEFAULT uuidv7(),
  id_calculo_item       uuid NOT NULL REFERENCES core_comissao.comissao_calculo_itens(id) ON DELETE RESTRICT,
  ordem                 integer NOT NULL,
  id_custo_evento       uuid NOT NULL,
  codigo_parcial        varchar(20),
  data_evento           date NOT NULL,
  origem                varchar(26) NOT NULL,
  numero_documento      varchar(30),
  fornecedor            varchar(120),
  quantidade_coberta    numeric(15,4) NOT NULL,
  valor_unitario        numeric(15,6) NOT NULL,
  valor_total           numeric(15,2) NOT NULL,
  moeda                 varchar(3) NOT NULL DEFAULT 'BRL',
  cotacao_moeda         numeric(15,6),
  condicao_pagamento    varchar(40),
  encargo_pagamento_pct numeric(7,4),
  frete_tipo            varchar(6) NOT NULL DEFAULT 'RATEIO',
  frete_valor           numeric(15,2) NOT NULL DEFAULT 0,
  origem_compra         varchar(25),
  ipi_pct               numeric(7,4) NOT NULL DEFAULT 0,
  valor_st              numeric(15,2) NOT NULL DEFAULT 0,
  valor_difal           numeric(15,2) NOT NULL DEFAULT 0,
  imposto_real          boolean NOT NULL DEFAULT false,
  compra_bruta          numeric(15,2) NOT NULL,
  icms_entrada_pct      numeric(7,4) NOT NULL DEFAULT 0,
  icms_recuperar        numeric(15,2) NOT NULL DEFAULT 0,
  valor_ipi             numeric(15,2) NOT NULL DEFAULT 0,
  frete_evento          numeric(15,2) NOT NULL DEFAULT 0,
  custo_liquido         numeric(15,2) NOT NULL,
  CONSTRAINT ck_calc_eventos_origem CHECK (origem IN ('OC_MATERIAL','LOTE_ESTOQUE','MATERIA_PRIMA_FABRICACAO','MAO_DE_OBRA_OC_SERVICO')),
  CONSTRAINT ck_calc_eventos_frete CHECK (frete_tipo IN ('RATEIO','VALOR')),
  CONSTRAINT ck_calc_eventos_origem_compra CHECK (origem_compra IS NULL OR origem_compra IN ('SP','SP_REDUZIDA','OUTRA_UF','IMPORTACAO_SP','IMPORTACAO_OUTRA_UF','SIMPLES')),
  CONSTRAINT ck_calc_eventos_qtd CHECK (quantidade_coberta > 0),
  CONSTRAINT uq_calc_eventos_ordem UNIQUE (id_calculo_item, ordem)
);
CREATE INDEX ix_calc_eventos_custo ON core_comissao.comissao_calculo_eventos (id_custo_evento);
CREATE TRIGGER trg_calc_eventos_imutavel BEFORE UPDATE OR DELETE ON core_comissao.comissao_calculo_eventos
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_log_imutavel();
COMMENT ON TABLE core_comissao.comissao_calculo_eventos IS 'Detalhe por evento do custo líquido de um item REAL (N16-20): condições do próprio evento (condição de pagamento, encargo, origem do ICMS, IPI, ST, DIFAL, frete, fornecedor) e o custo líquido pela fórmula do motor. Só INSERT. A soma de custo_liquido dos eventos mais custo_liquido_descoberto do item é o custo_liquido do item.';
COMMENT ON COLUMN core_comissao.comissao_calculo_eventos.id_custo_evento IS 'core_vendas_faturamento.custos_eventos.id (SQL-016). FK entra no bloco 9, depois do SQL-016.';
COMMENT ON COLUMN core_comissao.comissao_calculo_eventos.encargo_pagamento_pct IS 'Encargo da condição de pagamento da OC (OQ-12). Guardado para auditoria; a fórmula atual do custo líquido não o usa (o encargo só entra no preço sugerido).';
COMMENT ON COLUMN core_comissao.comissao_calculo_eventos.imposto_real IS 'true quando IPI, ST, ICMS e DIFAL vieram do documento (OQ-11). false = herdados da proposta (cálculo parcial por imposto): hoje a OC do hub não guarda imposto por item (N14-23).';
COMMENT ON COLUMN core_comissao.comissao_calculo_eventos.frete_tipo IS 'VALOR quando a OC traz o frete do evento; RATEIO usa parametros.rateio_logistica_pct sobre compra + IPI + ST, como motor.ts:307-310.';
COMMENT ON COLUMN core_comissao.comissao_calculo_eventos.custo_liquido IS 'compra_bruta - icms_recuperar + valor_ipi + valor_st + frete_evento (motor.ts:312). icms_recuperar = 0 quando valor_st > 0 (motor.ts:280-283).';

-- ----------------------------------------------------------------------------
-- 5. Comissão por NF, itens da NF, conferência de Compras, decisões da Controladoria
-- ----------------------------------------------------------------------------
CREATE TABLE core_comissao.comissoes_nf (
  id                   uuid PRIMARY KEY DEFAULT uuidv7(),
  id_comissao          uuid NOT NULL REFERENCES core_comissao.comissoes(id) ON DELETE RESTRICT,
  codigo_empresa       uuid NOT NULL REFERENCES core.unidades(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  codigo_nf_omie       bigint NOT NULL,
  numero_nf            varchar(10) NOT NULL,
  data_emissao         date NOT NULL,
  id_calculo_cotado    uuid NOT NULL REFERENCES core_comissao.comissao_calculos(id),
  id_calculo_real      uuid REFERENCES core_comissao.comissao_calculos(id),
  valor_faturado       numeric(15,2) NOT NULL,
  valor_se_cotado      numeric(15,2) NOT NULL,
  valor_calculado      numeric(15,2) NOT NULL,
  valor_pendente_custo numeric(15,2) NOT NULL DEFAULT 0,
  queda_por_custo      numeric(15,2) GENERATED ALWAYS AS (valor_se_cotado - valor_calculado - valor_pendente_custo) STORED,
  comissao_efetiva_pct numeric(7,4),
  custo_completo       boolean NOT NULL DEFAULT false,
  qtd_itens            integer NOT NULL DEFAULT 0,
  qtd_itens_sem_vinculo integer NOT NULL DEFAULT 0,
  motivo_zerado        varchar(20),
  estado               varchar(20) NOT NULL DEFAULT 'AGUARDANDO_DECISAO',
  valor_final          numeric(15,2),
  id_decisao_atual     uuid,
  compras_estado       varchar(10) NOT NULL DEFAULT 'PENDENTE',
  compras_por          uuid,
  compras_em           timestamptz,
  decidida_em          timestamptz,
  paga_em              date,
  recalculada_em       timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  CONSTRAINT ck_comissoes_nf_estado CHECK (estado IN ('AGUARDANDO_DECISAO','APROVADA','DESAPROVADA','BLOQUEADA','CORTADA','ALTERADA','NF_CANCELADA')),
  CONSTRAINT ck_comissoes_nf_motivo CHECK (motivo_zerado IS NULL OR motivo_zerado IN ('CLIENTE_EXCLUIDO','VENDEDOR_EXCLUIDO')),
  CONSTRAINT ck_comissoes_nf_valores CHECK (valor_faturado >= 0 AND valor_calculado >= 0 AND valor_se_cotado >= 0 AND valor_pendente_custo >= 0),
  CONSTRAINT ck_comissoes_nf_final CHECK (
       (estado IN ('AGUARDANDO_DECISAO','NF_CANCELADA') AND valor_final IS NULL)
    OR (estado IN ('APROVADA','DESAPROVADA','BLOQUEADA','CORTADA','ALTERADA') AND valor_final IS NOT NULL AND valor_final >= 0)),
  CONSTRAINT ck_comissoes_nf_compras CHECK (compras_estado IN ('PENDENTE','CONFIRMADA','CONTESTADA')),
  CONSTRAINT uq_comissoes_nf UNIQUE (codigo_empresa, codigo_nf_omie)
);
CREATE INDEX ix_comissoes_nf_fila ON core_comissao.comissoes_nf (codigo_empresa, estado, data_emissao);
CREATE INDEX ix_comissoes_nf_comissao ON core_comissao.comissoes_nf (id_comissao);
CREATE INDEX ix_comissoes_nf_mes ON core_comissao.comissoes_nf (data_emissao, estado);
COMMENT ON TABLE core_comissao.comissoes_nf IS 'Comissão fechada sobre UMA NF faturada. É o que chega à Controladoria já calculada. Enquanto AGUARDANDO_DECISAO o custo real que chegar recalcula; depois da decisão não muda mais.';
COMMENT ON COLUMN core_comissao.comissoes_nf.codigo_nf_omie IS 'Chave estável da NF (PK de notas_fiscais é codigo_empresa + codigo_nf_omie). Corrige o bloqueio atual, que usa o número com zeros à esquerda.';
COMMENT ON COLUMN core_comissao.comissoes_nf.valor_pendente_custo IS 'Comissão (ao percentual cotado) das peças faturadas que ainda NÃO têm custo real (N16-48). Não é paga: vira complemento ou desconto, na apuração seguinte, quando o custo completa. queda_por_custo = valor_se_cotado - valor_calculado - valor_pendente_custo (só a queda das peças com custo real).';
COMMENT ON COLUMN core_comissao.comissoes_nf.paga_em IS '🟡 Data em que a comissão desta NF foi paga ao vendedor (OQ-42: quem informa). Nula = ainda não paga: o abatimento por devolução reduz o valor a pagar; preenchida = o desconto entra na próxima apuração (N16-47).';
COMMENT ON COLUMN core_comissao.comissoes_nf.valor_se_cotado IS 'O que a NF pagaria só com o percentual do vendedor (custo cotado).';
COMMENT ON COLUMN core_comissao.comissoes_nf.valor_calculado IS 'Soma dos itens: round(valor faturado x LEAST(percentual cotado, percentual real) / 100, 2). Zero quando motivo_zerado.';
COMMENT ON COLUMN core_comissao.comissoes_nf.valor_final IS 'Valor decidido pela Controladoria. Nulo até a decisão. BLOQUEADA = 0 (retido; valor_calculado mostra quanto está retido).';
COMMENT ON COLUMN core_comissao.comissoes_nf.compras_estado IS '🟡 Conferência de Compras sobre o percentual de Compras (o passo Comissão: após a aprovação de Compras do simulador atual). PENDENTE > CONFIRMADA ou CONTESTADA. Qualquer recálculo da NF volta a PENDENTE. Interno: o vendedor nunca vê (N16-18).';
COMMENT ON COLUMN core_comissao.comissoes_nf.estado IS 'AGUARDANDO_DECISAO > APROVADA | DESAPROVADA | CORTADA | ALTERADA (finais) ou BLOQUEADA (pode ser liberada por nova decisão). NF_CANCELADA: NF cancelada antes da decisão.';

CREATE TABLE core_comissao.comissoes_nf_itens (
  id                   uuid PRIMARY KEY DEFAULT uuidv7(),
  id_comissao_nf       uuid NOT NULL REFERENCES core_comissao.comissoes_nf(id) ON DELETE RESTRICT,
  id_item_cotado       uuid NOT NULL REFERENCES core_comissao.comissao_calculo_itens(id),
  id_item_real         uuid REFERENCES core_comissao.comissao_calculo_itens(id),
  id_item_pedido       uuid,
  codigo_item_omie     bigint NOT NULL,
  quantidade_faturada  numeric(15,4),
  valor_faturado_item  numeric(15,2) NOT NULL,
  comissao_cotada_pct  numeric(7,4) NOT NULL,
  comissao_real_pct    numeric(7,4),
  comissao_final_pct   numeric(7,4) NOT NULL,
  regra_aplicada       varchar(20) NOT NULL,
  valor_se_cotado      numeric(15,2) NOT NULL,
  valor_calculado      numeric(15,2) NOT NULL,
  quantidade_comissionavel numeric(15,4) NOT NULL DEFAULT 0,
  valor_pendente_custo numeric(15,2) NOT NULL DEFAULT 0,
  CONSTRAINT ck_nf_itens_pct CHECK (comissao_final_pct BETWEEN 0 AND 100),
  CONSTRAINT ck_nf_itens_menor CHECK (comissao_final_pct <= comissao_cotada_pct),
  CONSTRAINT uq_nf_itens UNIQUE (id_comissao_nf, codigo_item_omie)
);
COMMENT ON TABLE core_comissao.comissoes_nf_itens IS 'Quebra da comissão da NF por item faturado: valor faturado x menor percentual entre o cotado e o real. Regenerada enquanto a NF aguarda decisão.';
COMMENT ON COLUMN core_comissao.comissoes_nf_itens.quantidade_comissionavel IS 'Quantidade desta NF que já tem custo real e ainda não foi comissionada em outra NF do pedido (N16-48, N16-49): LEAST(quantidade faturada, quantidade coberta - quantidade já comissionada nas outras NFs). Fabricação interna: toda a quantidade. Garante que a mesma quantidade nunca é paga duas vezes.';
COMMENT ON COLUMN core_comissao.comissoes_nf_itens.comissao_final_pct IS 'LEAST(comissao_cotada_pct, comissao_real_pct); sem cálculo real, vale o cotado. Mesma regra de pct_final do módulo atual.';


CREATE TABLE core_comissao.comissao_conferencias_compras (
  id               uuid PRIMARY KEY DEFAULT uuidv7(),
  id_comissao_nf   uuid NOT NULL REFERENCES core_comissao.comissoes_nf(id) ON DELETE RESTRICT,
  sequencia        integer NOT NULL,
  tipo             varchar(10) NOT NULL,
  id_calculo_real  uuid REFERENCES core_comissao.comissao_calculos(id),
  justificativa    text,
  feito_por        uuid NOT NULL REFERENCES auth.usuarios(id),
  feito_em         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_conferencias_tipo CHECK (tipo IN ('CONFIRMAR','CONTESTAR')),
  CONSTRAINT ck_conferencias_just CHECK (tipo = 'CONFIRMAR' OR char_length(btrim(COALESCE(justificativa, ''))) >= 10),
  CONSTRAINT uq_conferencias_seq UNIQUE (id_comissao_nf, sequencia)
);
CREATE TRIGGER trg_conferencias_imutavel BEFORE UPDATE OR DELETE ON core_comissao.comissao_conferencias_compras
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_log_imutavel();
COMMENT ON TABLE core_comissao.comissao_conferencias_compras IS '🟡 Conferência de Compras sobre o cálculo REAL da NF. CONFIRMAR = Compras concorda com o percentual de Compras; CONTESTAR (justificativa obrigatória) = custo, imposto ou classificação do item errado: Compras corrige na OC ou no lote e o motor recalcula. Compras NÃO altera a proposta (N16-08). Só INSERT.';

-- Lançamentos da apuração: complemento ou desconto por custo que completou depois da decisão (N16-48, N16-49) e
-- abatimento por NF cancelada, devolvida ou recusada (N16-47). Entram na apuração seguinte.
CREATE TABLE core_comissao.comissao_lancamentos (
  id                uuid PRIMARY KEY DEFAULT uuidv7(),
  id_comissao       uuid NOT NULL REFERENCES core_comissao.comissoes(id) ON DELETE RESTRICT,
  id_comissao_nf    uuid NOT NULL REFERENCES core_comissao.comissoes_nf(id) ON DELETE RESTRICT,
  tipo              varchar(11) NOT NULL,
  origem            varchar(20) NOT NULL,
  codigo_nf_origem  bigint,
  proporcao_pct     numeric(7,4),
  itens             jsonb NOT NULL DEFAULT '[]'::jsonb,
  valor_calculado   numeric(15,2) NOT NULL,
  estado            varchar(20) NOT NULL DEFAULT 'AGUARDANDO_DECISAO',
  valor_final       numeric(15,2),
  id_decisao_atual  uuid,
  ja_paga           boolean NOT NULL DEFAULT false,
  competencia       date NOT NULL,
  motivo            text NOT NULL,
  decidido_em       timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  CONSTRAINT ck_lanc_tipo CHECK (tipo IN ('COMPLEMENTO','DESCONTO','ABATIMENTO')),
  CONSTRAINT ck_lanc_origem CHECK (origem IN ('CUSTO_COMPLETO','NF_CANCELADA','DEVOLUCAO','RECUSA_CLIENTE')),
  CONSTRAINT ck_lanc_estado CHECK (estado IN ('AGUARDANDO_DECISAO','APROVADA','DESAPROVADA','BLOQUEADA','CORTADA','ALTERADA','REGISTRADO')),
  CONSTRAINT ck_lanc_valor CHECK (valor_calculado > 0 AND (valor_final IS NULL OR valor_final >= 0)),
  CONSTRAINT ck_lanc_motivo CHECK (char_length(btrim(motivo)) >= 3),
  CONSTRAINT ck_lanc_itens CHECK (jsonb_typeof(itens) = 'array'),
  CONSTRAINT ck_lanc_competencia CHECK (competencia = date_trunc('month', competencia)::date),
  CONSTRAINT ck_lanc_forma CHECK (
       (tipo = 'ABATIMENTO' AND estado = 'REGISTRADO' AND valor_final = valor_calculado
          AND origem IN ('NF_CANCELADA','DEVOLUCAO','RECUSA_CLIENTE') AND codigo_nf_origem IS NOT NULL
          AND proporcao_pct > 0 AND proporcao_pct <= 100)
    OR (tipo IN ('COMPLEMENTO','DESCONTO') AND origem = 'CUSTO_COMPLETO' AND estado <> 'REGISTRADO'
          AND ((estado = 'AGUARDANDO_DECISAO') = (valor_final IS NULL)))
  )
);
CREATE INDEX ix_lanc_comissao ON core_comissao.comissao_lancamentos (id_comissao);
CREATE INDEX ix_lanc_nf ON core_comissao.comissao_lancamentos (id_comissao_nf);
CREATE INDEX ix_lanc_apuracao ON core_comissao.comissao_lancamentos (competencia, estado);
COMMENT ON TABLE core_comissao.comissao_lancamentos IS 'Lançamentos da apuração do vendedor ligados a uma NF: COMPLEMENTO (custo completou e a comissão sobe) ou DESCONTO (custo completou e a comissão cai), ambos com NOVA DECISÃO (N16-48, N16-49); e ABATIMENTO por NF cancelada, devolvida ou recusada pelo cliente (N16-47), registrado sem decisão, proporcional, com a NF de origem e o motivo. Sinal: COMPLEMENTO soma; DESCONTO e ABATIMENTO subtraem.';
COMMENT ON COLUMN core_comissao.comissao_lancamentos.competencia IS '🟡 Primeiro dia do mês da apuração em que o lançamento entra (OQ-42: o ciclo da apuração do vendedor ainda não foi definido; hoje é mensal). Complemento e desconto: mês seguinte. Abatimento: mês corrente se a NF ainda não foi paga; mês seguinte se já foi paga.';
COMMENT ON COLUMN core_comissao.comissao_lancamentos.itens IS 'Só no COMPLEMENTO: as quantidades por item que o complemento passou a comissionar, [{"codigo_item_omie": 501, "quantidade": 10}]. Entram na conta de "quantidade já comissionada" de fn_comissao_nf_fechar, para nunca pagar a mesma peça duas vezes (N16-49).';
COMMENT ON COLUMN core_comissao.comissao_lancamentos.proporcao_pct IS 'Só no ABATIMENTO: parte da comissão da NF que se abate (100 = NF cancelada ou devolvida por inteiro; menos de 100 = devolução parcial). A soma dos abatimentos de uma NF não passa de 100.';

CREATE TABLE core_comissao.comissao_decisoes (
  id                  uuid PRIMARY KEY DEFAULT uuidv7(),
  id_comissao_nf      uuid REFERENCES core_comissao.comissoes_nf(id) ON DELETE RESTRICT,
  id_lancamento       uuid REFERENCES core_comissao.comissao_lancamentos(id) ON DELETE RESTRICT,
  sequencia           integer NOT NULL,
  tipo                varchar(11) NOT NULL,
  perfil_decisor      varchar(14) NOT NULL DEFAULT 'CONTROLADORIA',
  justificativa       text NOT NULL,
  corte_pct           numeric(7,4),
  pct_novo            numeric(7,4),
  pct_antes           numeric(7,4),
  pct_depois          numeric(7,4),
  valor_antes         numeric(15,2) NOT NULL,
  valor_depois        numeric(15,2) NOT NULL,
  estado_antes        varchar(20) NOT NULL,
  estado_depois       varchar(20) NOT NULL,
  decidido_por        uuid NOT NULL REFERENCES auth.usuarios(id),
  decidido_em         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_decisoes_tipo CHECK (tipo IN ('APROVAR','DESAPROVAR','BLOQUEAR','DESBLOQUEAR','CORTAR','ALTERAR')),
  CONSTRAINT ck_decisoes_perfil CHECK (perfil_decisor IN ('CONTROLADORIA','GERENCIA','COORDENACAO')),
  CONSTRAINT ck_decisoes_alvo CHECK ((id_comissao_nf IS NULL) <> (id_lancamento IS NULL)),
  CONSTRAINT ck_decisoes_justificativa CHECK (char_length(btrim(justificativa)) >= 10),
  CONSTRAINT ck_decisoes_valores CHECK (valor_antes >= 0 AND valor_depois >= 0),
  CONSTRAINT ck_decisoes_regra_valor CHECK (
       (tipo = 'APROVAR'    AND valor_depois = valor_antes AND corte_pct IS NULL AND pct_novo IS NULL)
    OR (tipo IN ('DESAPROVAR','BLOQUEAR','DESBLOQUEAR') AND valor_depois = 0 AND corte_pct IS NULL AND pct_novo IS NULL)
    OR (tipo = 'CORTAR'     AND corte_pct IS NOT NULL AND corte_pct > 0 AND corte_pct < 100 AND pct_novo IS NULL
                            AND valor_depois = round(valor_antes * (1 - corte_pct / 100), 2))
    OR (tipo = 'ALTERAR'    AND corte_pct IS NULL)),
  CONSTRAINT uq_decisoes_sequencia UNIQUE (id_comissao_nf, sequencia),
  CONSTRAINT uq_decisoes_sequencia_lanc UNIQUE (id_lancamento, sequencia)
);
CREATE INDEX ix_decisoes_quem ON core_comissao.comissao_decisoes (decidido_por, decidido_em DESC);
CREATE TRIGGER trg_decisoes_imutavel BEFORE UPDATE OR DELETE ON core_comissao.comissao_decisoes
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_log_imutavel();
COMMENT ON TABLE core_comissao.comissao_decisoes IS 'Decisão sobre a comissão de uma NF ou sobre um lançamento (complemento ou desconto): quem decidiu e com que perfil (Controladoria, Gerência ou Coordenação, N16-44), quando, justificativa obrigatória (10+ caracteres), valor e percentual antes e depois. Só INSERT. BLOQUEAR retém e DESBLOQUEAR devolve à fila, sempre com justificativa (N16-43). Quem decide nunca é o dono da comissão (N16-44).';
COMMENT ON COLUMN core_comissao.comissao_decisoes.corte_pct IS 'Só em CORTAR: percentual cortado (50 = pela metade). Vale para valor e percentual, que são proporcionais.';
COMMENT ON COLUMN core_comissao.comissao_decisoes.pct_novo IS 'Só em ALTERAR por percentual: o percentual de comissão que passa a valer sobre o valor faturado da NF (N16-45: alteração vale para percentual e valor, sem teto).';
COMMENT ON COLUMN core_comissao.comissao_decisoes.pct_antes IS 'Percentual efetivo antes (valor_antes / valor faturado da NF). Só em decisão de NF; rastro (N16-45).';

ALTER TABLE core_comissao.comissao_lancamentos
  ADD CONSTRAINT fk_lanc_decisao FOREIGN KEY (id_decisao_atual) REFERENCES core_comissao.comissao_decisoes(id);
ALTER TABLE core_comissao.comissoes_nf
  ADD CONSTRAINT fk_comissoes_nf_decisao FOREIGN KEY (id_decisao_atual) REFERENCES core_comissao.comissao_decisoes(id);
ALTER TABLE core_comissao.comissoes
  ADD CONSTRAINT fk_comissoes_calculo_cotado FOREIGN KEY (id_calculo_cotado) REFERENCES core_comissao.comissao_calculos(id),
  ADD CONSTRAINT fk_comissoes_calculo_real FOREIGN KEY (id_calculo_real) REFERENCES core_comissao.comissao_calculos(id);

-- ----------------------------------------------------------------------------
-- 6. Linha do tempo e fila de recálculo
-- ----------------------------------------------------------------------------
CREATE TABLE core_comissao.comissao_eventos (
  id                uuid PRIMARY KEY DEFAULT uuidv7(),
  id_comissao       uuid NOT NULL REFERENCES core_comissao.comissoes(id) ON DELETE RESTRICT,
  id_comissao_nf    uuid REFERENCES core_comissao.comissoes_nf(id) ON DELETE RESTRICT,
  tipo              varchar(30) NOT NULL,
  descricao         text NOT NULL,
  dados             jsonb NOT NULL DEFAULT '{}'::jsonb,
  visivel_vendedor  boolean NOT NULL DEFAULT false,
  feito_por         uuid,
  feito_em          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_eventos_tipo CHECK (tipo IN ('ESTIMATIVA_CALCULADA','PROPOSTA_APROVADA','PEDIDO_CRIADO','CUSTO_REAL_RECALCULADO','NF_FECHADA','NF_RECALCULADA','DECISAO','CANCELADA','ENCERRADA','ESTADO_ALTERADO','CONFERENCIA_COMPRAS','LANCAMENTO')),
  CONSTRAINT ck_eventos_dados CHECK (jsonb_typeof(dados) = 'object')
);
CREATE INDEX ix_eventos_comissao ON core_comissao.comissao_eventos (id_comissao, feito_em);
CREATE TRIGGER trg_eventos_imutavel BEFORE UPDATE OR DELETE ON core_comissao.comissao_eventos
  FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_log_imutavel();
COMMENT ON TABLE core_comissao.comissao_eventos IS 'Linha do tempo de cada comissão (para a tela de detalhe). Só INSERT. visivel_vendedor marca o que a tela do vendedor pode listar (nunca valor real nem custo antes da decisão).';

CREATE TABLE core_comissao.comissao_fila_recalculo (
  id               uuid PRIMARY KEY DEFAULT uuidv7(),
  id_comissao      uuid NOT NULL REFERENCES core_comissao.comissoes(id) ON DELETE RESTRICT,
  motivo           varchar(12) NOT NULL,
  criado_em        timestamptz NOT NULL DEFAULT now(),
  processado_em    timestamptz,
  id_calculo_gerado uuid REFERENCES core_comissao.comissao_calculos(id),
  tentativas       integer NOT NULL DEFAULT 0,
  erro             text,
  CONSTRAINT ck_fila_motivo CHECK (motivo IN ('CUSTO_REAL','NF','REPROCESSAR'))
);
CREATE UNIQUE INDEX uq_fila_pendente ON core_comissao.comissao_fila_recalculo (id_comissao, motivo) WHERE processado_em IS NULL;
CREATE INDEX ix_fila_pendente ON core_comissao.comissao_fila_recalculo (criado_em) WHERE processado_em IS NULL;
COMMENT ON TABLE core_comissao.comissao_fila_recalculo IS 'Caixa de saída de eventos: um custo real novo (ou NF nova) marca a comissão e o job do motor recalcula. Eventos repetidos enquanto pendentes viram um só.';

-- ----------------------------------------------------------------------------
-- Triggers genéricos (updated_at e auditoria)
-- ----------------------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['parametros','parametros_despesas','parametros_icms_saida','parametros_icms_entrada',
                           'parametros_encargos_pagamento','parametros_faixas','regras_fixas_cliente','exclusoes',
                           'coordenadores','coordenadores_regras','comissoes','comissoes_nf']
  LOOP
    EXECUTE format('CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON core_comissao.%I FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()', t, t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['parametros','parametros_despesas','parametros_icms_saida','parametros_icms_entrada',
                           'parametros_encargos_pagamento','parametros_faixas','regras_fixas_cliente','exclusoes',
                           'coordenadores','coordenadores_regras']
  LOOP
    EXECUTE format('CREATE TRIGGER trg_%s_auditoria AFTER INSERT OR UPDATE OR DELETE ON core_comissao.%I FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_auditar()', t, t);
  END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 7. Funções
-- ----------------------------------------------------------------------------

-- 7.1 Parâmetros vigentes na forma que o motor consome (mesmo desenho de ParametrosSimulador)
CREATE OR REPLACE FUNCTION core_comissao.fn_parametros_json(p_codigo_empresa uuid, p_data date DEFAULT CURRENT_DATE)
RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT jsonb_build_object(
    'id', p.id, 'descricao', p.descricao,
    'margem_desejada', p.margem_desejada_pct,
    'pct_despesas_operacionais', p.despesas_operacionais_pct,
    'pct_rateio_logistica', p.rateio_logistica_pct,
    'pct_comissao_provisao', p.provisao_comissao_pct,
    'pct_pis', p.pis_pct, 'pct_cofins', p.cofins_pct,
    'pct_irpj_base', p.irpj_base_pct, 'pct_irpj', p.irpj_pct,
    'pct_csll_base', p.csll_base_pct, 'pct_csll', p.csll_pct,
    'pct_adicional_ir', p.adicional_ir_pct,
    'pct_fabricacao_interna', p.fabricacao_interna_pct,
    'exige_conferencia_compras', p.exige_conferencia_compras,
    'icms_saida', (SELECT COALESCE(jsonb_object_agg(s.destino, s.aliquota_pct), '{}'::jsonb)
                     FROM core_comissao.parametros_icms_saida s WHERE s.id_parametros = p.id),
    'icms_entrada', (SELECT COALESCE(jsonb_object_agg(e.origem_compra, e.aliquota_pct), '{}'::jsonb)
                       FROM core_comissao.parametros_icms_entrada e WHERE e.id_parametros = p.id),
    'encargos_pagamento', (SELECT COALESCE(jsonb_object_agg(g.condicao_pagamento, g.encargo_pct), '{}'::jsonb)
                             FROM core_comissao.parametros_encargos_pagamento g WHERE g.id_parametros = p.id),
    'faixas_comissao', (SELECT COALESCE(jsonb_agg(jsonb_build_object('letra', f.letra, 'margem_min', f.margem_min_pct, 'pct', f.comissao_pct)
                                                  ORDER BY f.margem_min_pct DESC), '[]'::jsonb)
                          FROM core_comissao.parametros_faixas f WHERE f.id_parametros = p.id))
    FROM core_comissao.parametros p
   WHERE p.codigo_empresa = p_codigo_empresa
     AND p.vigencia_inicio <= p_data
     AND (p.vigencia_fim IS NULL OR p.vigencia_fim >= p_data)
$$;
COMMENT ON FUNCTION core_comissao.fn_parametros_json(uuid, date) IS 'Parâmetros vigentes da unidade na data, no formato de entrada do motor. Sem vigência na data, devolve NULL (o motor não calcula sem parâmetro).';

-- 7.2 Regra fixa vigente do cliente na data
CREATE OR REPLACE FUNCTION core_comissao.fn_regra_fixa_vigente(p_codigo_empresa uuid, p_codigo_cliente text, p_data date DEFAULT CURRENT_DATE)
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT r.id FROM core_comissao.regras_fixas_cliente r
   WHERE r.codigo_empresa = p_codigo_empresa AND r.codigo_cliente = p_codigo_cliente
     AND r.deleted_at IS NULL AND r.vigencia_inicio <= p_data
     AND (r.vigencia_fim IS NULL OR r.vigencia_fim >= p_data)
$$;

-- 7.3 Exclusão vigente (cliente ou vendedor)
CREATE OR REPLACE FUNCTION core_comissao.fn_excluido(p_codigo_empresa uuid, p_tipo text, p_codigo text, p_data date)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM core_comissao.exclusoes x
                  WHERE x.codigo_empresa = p_codigo_empresa AND x.tipo = p_tipo AND x.codigo_omie = p_codigo
                    AND x.deleted_at IS NULL AND x.vigencia_inicio <= p_data
                    AND (x.vigencia_fim IS NULL OR x.vigencia_fim >= p_data))
$$;

-- 7.4 Gravar o resultado do motor (a API calcula; o banco grava tudo ou nada)
CREATE OR REPLACE FUNCTION core_comissao.fn_calculo_gravar(p_payload jsonb) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_com     uuid := (p_payload ->> 'id_comissao')::uuid;
  v_tipo    text := p_payload ->> 'tipo';
  v_usuario uuid := NULLIF(p_payload ->> 'usuario', '')::uuid;
  v_cab     jsonb := p_payload -> 'cabecalho';
  v_estado  text;
  v_seq     integer;
  v_id      uuid;
  v_acima   boolean;
  v_item    jsonb;
  v_item_id uuid;
BEGIN
  SELECT estado INTO v_estado FROM core_comissao.comissoes WHERE id = v_com FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Comissão % não existe.', v_com USING ERRCODE = 'P0002';
  END IF;
  IF v_tipo = 'COTADO' AND v_estado <> 'ESTIMADA' THEN
    RAISE EXCEPTION 'A estimativa só muda enquanto a proposta não é aprovada (N16-03). Estado atual: %.', v_estado USING ERRCODE = '23514';
  END IF;
  IF v_tipo = 'REAL' AND v_estado <> 'EM_ACOMPANHAMENTO' THEN
    RAISE EXCEPTION 'Cálculo com custo real só em comissão EM_ACOMPANHAMENTO. Estado atual: %.', v_estado USING ERRCODE = '23514';
  END IF;
  IF v_tipo NOT IN ('COTADO','REAL') THEN
    RAISE EXCEPTION 'tipo deve ser COTADO ou REAL.' USING ERRCODE = '22023';
  END IF;
  IF jsonb_typeof(p_payload -> 'itens') <> 'array' OR jsonb_array_length(p_payload -> 'itens') = 0 THEN
    RAISE EXCEPTION 'itens é obrigatório e deve ter ao menos um item.' USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(max(sequencia), 0) + 1 INTO v_seq FROM core_comissao.comissao_calculos WHERE id_comissao = v_com;
  v_id := uuidv7();

  INSERT INTO core_comissao.comissao_calculos (
    id, id_comissao, sequencia, tipo, gatilho, id_parametros, id_regra_fixa, versao_motor,
    estado_destino, icms_destino_pct, condicao_pagamento, encargo_pagamento_pct, isento_imposto, frete_compra_tipo,
    frete_compra_total, valor_st_venda, imposto_retido_difal, frete_venda, custo_total, venda_sugerida, valor_liquido,
    total_nf, markup_projetado, markup_real, markup_bruto_pct, margem_liquida_pct, lucro, letra_equivalente,
    comissao_efetiva_pct, valor_comissao_total, qtd_itens, qtd_itens_prejuizo, custo_completo, imposto_completo,
    avisos, calculado_por)
  SELECT v_id, v_com, v_seq, v_tipo, p_payload ->> 'gatilho', (p_payload ->> 'id_parametros')::uuid,
         NULLIF(p_payload ->> 'id_regra_fixa', '')::uuid, p_payload ->> 'versao_motor',
         c.estado_destino, c.icms_destino_pct, c.condicao_pagamento, c.encargo_pagamento_pct,
         COALESCE(c.isento_imposto, false), COALESCE(c.frete_compra_tipo, 'RATEIO'), COALESCE(c.frete_compra_total, 0),
         COALESCE(c.valor_st_venda, 0), COALESCE(c.imposto_retido_difal, 0), COALESCE(c.frete_venda, 0), c.custo_total,
         c.venda_sugerida, c.valor_liquido, c.total_nf, c.markup_projetado, c.markup_real, c.markup_bruto_pct,
         c.margem_liquida_pct, c.lucro, c.letra_equivalente, c.comissao_efetiva_pct, c.valor_comissao_total,
         c.qtd_itens, COALESCE(c.qtd_itens_prejuizo, 0), COALESCE(c.custo_completo, false),
         COALESCE(c.imposto_completo, true), COALESCE(v_cab -> 'avisos', '[]'::jsonb), v_usuario
    FROM jsonb_to_record(v_cab) AS c(
      estado_destino text, icms_destino_pct numeric, condicao_pagamento text, encargo_pagamento_pct numeric,
      isento_imposto boolean, frete_compra_tipo text, frete_compra_total numeric,
      valor_st_venda numeric, imposto_retido_difal numeric, frete_venda numeric, custo_total numeric,
      venda_sugerida numeric, valor_liquido numeric, total_nf numeric, markup_projetado numeric, markup_real numeric,
      markup_bruto_pct numeric, margem_liquida_pct numeric, lucro numeric, letra_equivalente text,
      comissao_efetiva_pct numeric, valor_comissao_total numeric, qtd_itens integer, qtd_itens_prejuizo integer,
      custo_completo boolean, imposto_completo boolean);

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_payload -> 'itens') LOOP
    v_item_id := uuidv7();
    INSERT INTO core_comissao.comissao_calculo_itens (
      id, id_calculo, ordem, id_item_proposta, id_item_pedido, codigo_item_omie, codigo_produto, descricao, tipo_item,
      qtd, unidade, qtd_compra, unidade_compra, fornecedor, origem_compra, ipi_pct, valor_st,
      frete_compra_valor, preco_unit_compra_cotado, preco_unit_venda, quantidade_coberta,
      custo_real_total, custo_real_unitario_medio, custo_completo, qtd_eventos, qtd_descoberta,
      custo_liquido_descoberto, imposto_completo, custo_real_acima_cotado,
      compra_bruta, icms_entrada_pct, icms_recuperar, valor_ipi, frete_item, custo_liquido,
      preco_unit_sugerido, preco_total_sugerido, venda_item, icms_efetivo_pct, impostos_pct, lucro_item,
      margem_item_pct, letra_item, comissao_letra_pct, teto_regra_pct, comissao_pct, regra_aplicada,
      valor_comissao_estimado)
    SELECT v_item_id, v_id, i.ordem, i.id_item_proposta, i.id_item_pedido, i.codigo_item_omie, i.codigo_produto,
           i.descricao, COALESCE(i.tipo_item, 'REVENDA'), i.qtd, i.unidade, i.qtd_compra, i.unidade_compra,
           i.fornecedor, i.origem_compra, COALESCE(i.ipi_pct, 0), COALESCE(i.valor_st, 0),
           COALESCE(i.frete_compra_valor, 0), COALESCE(i.preco_unit_compra_cotado, 0), i.preco_unit_venda,
           i.quantidade_coberta, i.custo_real_total, i.custo_real_unitario_medio, COALESCE(i.custo_completo, false),
           COALESCE(i.qtd_eventos, 0), i.qtd_descoberta, COALESCE(i.custo_liquido_descoberto, 0),
           COALESCE(i.imposto_completo, true), COALESCE(i.custo_real_acima_cotado, false),
           COALESCE(i.compra_bruta, 0), COALESCE(i.icms_entrada_pct, 0), COALESCE(i.icms_recuperar, 0),
           COALESCE(i.valor_ipi, 0), COALESCE(i.frete_item, 0), COALESCE(i.custo_liquido, 0), i.preco_unit_sugerido,
           i.preco_total_sugerido, i.venda_item, i.icms_efetivo_pct, i.impostos_pct, i.lucro_item, i.margem_item_pct,
           i.letra_item, i.comissao_letra_pct, i.teto_regra_pct, i.comissao_pct, i.regra_aplicada,
           i.valor_comissao_estimado
      FROM jsonb_to_record(v_item) AS i(
        ordem integer, id_item_proposta uuid, id_item_pedido uuid, codigo_item_omie bigint, codigo_produto text,
        descricao text, tipo_item text, qtd numeric, unidade text, qtd_compra numeric, unidade_compra text,
        fornecedor text, origem_compra text, ipi_pct numeric, valor_st numeric, frete_compra_valor numeric,
        preco_unit_compra_cotado numeric, preco_unit_venda numeric, quantidade_coberta numeric,
        custo_real_total numeric, custo_real_unitario_medio numeric, custo_completo boolean, qtd_eventos integer,
        qtd_descoberta numeric, custo_liquido_descoberto numeric, imposto_completo boolean,
        custo_real_acima_cotado boolean, compra_bruta numeric, icms_entrada_pct numeric, icms_recuperar numeric,
        valor_ipi numeric, frete_item numeric, custo_liquido numeric, preco_unit_sugerido numeric,
        preco_total_sugerido numeric, venda_item numeric, icms_efetivo_pct numeric, impostos_pct numeric,
        lucro_item numeric, margem_item_pct numeric, letra_item text, comissao_letra_pct numeric,
        teto_regra_pct numeric, comissao_pct numeric, regra_aplicada text, valor_comissao_estimado numeric);

    IF v_tipo = 'REAL' AND jsonb_typeof(v_item -> 'eventos') = 'array' THEN
      INSERT INTO core_comissao.comissao_calculo_eventos (
        id_calculo_item, ordem, id_custo_evento, codigo_parcial, data_evento, origem, numero_documento, fornecedor,
        quantidade_coberta, valor_unitario, valor_total, moeda, cotacao_moeda, condicao_pagamento,
        encargo_pagamento_pct, frete_tipo, frete_valor, origem_compra, ipi_pct, valor_st, valor_difal, imposto_real,
        compra_bruta, icms_entrada_pct, icms_recuperar, valor_ipi, frete_evento, custo_liquido)
      SELECT v_item_id, e.ordem, e.id_custo_evento, e.codigo_parcial, e.data_evento, e.origem, e.numero_documento,
             e.fornecedor, e.quantidade_coberta, e.valor_unitario, e.valor_total, COALESCE(e.moeda, 'BRL'),
             e.cotacao_moeda, e.condicao_pagamento, e.encargo_pagamento_pct, COALESCE(e.frete_tipo, 'RATEIO'),
             COALESCE(e.frete_valor, 0), e.origem_compra, COALESCE(e.ipi_pct, 0), COALESCE(e.valor_st, 0),
             COALESCE(e.valor_difal, 0), COALESCE(e.imposto_real, false), e.compra_bruta,
             COALESCE(e.icms_entrada_pct, 0), COALESCE(e.icms_recuperar, 0), COALESCE(e.valor_ipi, 0),
             COALESCE(e.frete_evento, 0), e.custo_liquido
        FROM jsonb_to_recordset(v_item -> 'eventos') AS e(
          ordem integer, id_custo_evento uuid, codigo_parcial text, data_evento date, origem text,
          numero_documento text, fornecedor text, quantidade_coberta numeric, valor_unitario numeric,
          valor_total numeric, moeda text, cotacao_moeda numeric, condicao_pagamento text,
          encargo_pagamento_pct numeric, frete_tipo text, frete_valor numeric, origem_compra text,
          ipi_pct numeric, valor_st numeric, valor_difal numeric, imposto_real boolean, compra_bruta numeric,
          icms_entrada_pct numeric, icms_recuperar numeric, valor_ipi numeric, frete_evento numeric,
          custo_liquido numeric);
    END IF;
  END LOOP;

  SELECT COALESCE(bool_or(custo_real_acima_cotado), false) INTO v_acima
    FROM core_comissao.comissao_calculo_itens WHERE id_calculo = v_id;

  IF v_tipo = 'COTADO' THEN
    UPDATE core_comissao.comissoes SET id_calculo_cotado = v_id, updated_by = v_usuario WHERE id = v_com;
  ELSE
    UPDATE core_comissao.comissoes SET id_calculo_real = v_id, custo_real_acima_cotado = v_acima, updated_by = v_usuario WHERE id = v_com;
  END IF;

  INSERT INTO core_comissao.comissao_eventos (id_comissao, tipo, descricao, dados, visivel_vendedor, feito_por)
  VALUES (v_com, CASE WHEN v_tipo = 'COTADO' THEN 'ESTIMATIVA_CALCULADA' ELSE 'CUSTO_REAL_RECALCULADO' END,
          CASE WHEN v_tipo = 'COTADO' THEN 'Comissão estimada calculada com o custo da proposta.'
               ELSE 'Comissão recalculada com o custo real do pedido.' END,
          jsonb_build_object('id_calculo', v_id, 'sequencia', v_seq, 'gatilho', p_payload ->> 'gatilho'),
          v_tipo = 'COTADO', v_usuario);
  RETURN v_id;
END $$;
COMMENT ON FUNCTION core_comissao.fn_calculo_gravar(jsonb) IS 'Grava, numa transação, um cálculo (cabeçalho e itens) já feito pelo motor da API e aponta a comissão para ele. COTADO só com a comissão ESTIMADA; REAL só EM_ACOMPANHAMENTO.';

-- 7.5 Mudança de estado do dossiê
CREATE OR REPLACE FUNCTION core_comissao.fn_comissao_mudar_estado(
  p_id_comissao uuid, p_novo text, p_usuario uuid, p_id_pedido_venda uuid DEFAULT NULL,
  p_numero_pedido text DEFAULT NULL, p_motivo text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE v_atual text;
BEGIN
  SELECT estado INTO v_atual FROM core_comissao.comissoes WHERE id = p_id_comissao FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Comissão % não existe.', p_id_comissao USING ERRCODE = 'P0002'; END IF;
  IF NOT ((v_atual = 'ESTIMADA' AND p_novo IN ('CONGELADA','CANCELADA'))
       OR (v_atual = 'CONGELADA' AND p_novo IN ('EM_ACOMPANHAMENTO','CANCELADA'))
       OR (v_atual = 'EM_ACOMPANHAMENTO' AND p_novo IN ('ENCERRADA','CANCELADA'))) THEN
    RAISE EXCEPTION 'Transição % > % não é permitida.', v_atual, p_novo USING ERRCODE = '23514';
  END IF;
  IF p_novo = 'CANCELADA' AND char_length(btrim(COALESCE(p_motivo, ''))) < 3 THEN
    RAISE EXCEPTION 'Cancelar exige motivo.' USING ERRCODE = '23514';
  END IF;
  IF p_novo = 'CANCELADA' AND EXISTS (SELECT 1 FROM core_comissao.comissoes_nf n
                                       WHERE n.id_comissao = p_id_comissao AND n.estado NOT IN ('NF_CANCELADA')) THEN
    RAISE EXCEPTION 'Comissão com NF faturada não se cancela: o caso é de cancelamento ou devolução da NF (fn_comissao_nf_abater).' USING ERRCODE = '23514';
  END IF;
  UPDATE core_comissao.comissoes SET
      estado = p_novo,
      id_pedido_venda = COALESCE(p_id_pedido_venda, id_pedido_venda),
      numero_pedido = COALESCE(p_numero_pedido, numero_pedido),
      proposta_aprovada_em = CASE WHEN p_novo = 'CONGELADA' THEN now() ELSE proposta_aprovada_em END,
      encerrada_em = CASE WHEN p_novo = 'ENCERRADA' THEN now() ELSE encerrada_em END,
      cancelada_em = CASE WHEN p_novo = 'CANCELADA' THEN now() ELSE cancelada_em END,
      cancelada_por = CASE WHEN p_novo = 'CANCELADA' THEN p_usuario ELSE cancelada_por END,
      motivo_cancelamento = CASE WHEN p_novo = 'CANCELADA' THEN p_motivo ELSE motivo_cancelamento END,
      updated_by = p_usuario
    WHERE id = p_id_comissao;
  INSERT INTO core_comissao.comissao_eventos (id_comissao, tipo, descricao, dados, visivel_vendedor, feito_por)
  VALUES (p_id_comissao,
          CASE p_novo WHEN 'CONGELADA' THEN 'PROPOSTA_APROVADA' WHEN 'EM_ACOMPANHAMENTO' THEN 'PEDIDO_CRIADO'
                      WHEN 'CANCELADA' THEN 'CANCELADA' WHEN 'ENCERRADA' THEN 'ENCERRADA' ELSE 'ESTADO_ALTERADO' END,
          format('Estado %s para %s.', v_atual, p_novo),
          jsonb_build_object('de', v_atual, 'para', p_novo, 'motivo', p_motivo), true, p_usuario);
END $$;
COMMENT ON FUNCTION core_comissao.fn_comissao_mudar_estado(uuid, text, uuid, uuid, text, text) IS 'Única porta para mudar o estado do dossiê. Cancelar vira histórico (os cálculos ficam). Com NF faturada não cancela.';

-- 7.6 Fechar (ou refazer, enquanto aguarda decisão) a comissão de uma NF
CREATE OR REPLACE FUNCTION core_comissao.fn_comissao_nf_fechar(p_id_comissao uuid, p_codigo_nf_omie bigint, p_usuario uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
  v_com   core_comissao.comissoes%ROWTYPE;
  v_nf    record;
  v_id    uuid;
  v_est   text;
  v_zero  text;
  v_fat   numeric; v_cot numeric; v_calc numeric; v_pend numeric; v_sem integer; v_n integer; v_compl boolean;
BEGIN
  SELECT * INTO v_com FROM core_comissao.comissoes WHERE id = p_id_comissao FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Comissão % não existe.', p_id_comissao USING ERRCODE = 'P0002'; END IF;
  IF v_com.estado <> 'EM_ACOMPANHAMENTO' THEN
    RAISE EXCEPTION 'Comissão fecha NF só EM_ACOMPANHAMENTO. Estado atual: %.', v_com.estado USING ERRCODE = '23514';
  END IF;
  IF v_com.id_calculo_cotado IS NULL THEN
    RAISE EXCEPTION 'Comissão sem cálculo cotado.' USING ERRCODE = '23514';
  END IF;

  SELECT n.numero_nf, to_date(n.data_emissao, 'YYYY-MM-DD') AS data_emissao INTO v_nf
    FROM core_vendas_faturamento.notas_fiscais n
   WHERE n.codigo_empresa = v_com.codigo_empresa AND n.codigo_nf_omie = p_codigo_nf_omie AND n.deleted_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'NF % não existe na unidade.', p_codigo_nf_omie USING ERRCODE = 'P0002'; END IF;

  SELECT id, estado INTO v_id, v_est FROM core_comissao.comissoes_nf
   WHERE codigo_empresa = v_com.codigo_empresa AND codigo_nf_omie = p_codigo_nf_omie FOR UPDATE;
  IF FOUND AND v_est <> 'AGUARDANDO_DECISAO' THEN
    RAISE EXCEPTION 'A comissão desta NF já foi decidida (%): não é recalculada.', v_est USING ERRCODE = '23514';
  END IF;

  v_zero := CASE
    WHEN core_comissao.fn_excluido(v_com.codigo_empresa, 'CLIENTE',  v_com.codigo_cliente, v_nf.data_emissao) THEN 'CLIENTE_EXCLUIDO'
    WHEN core_comissao.fn_excluido(v_com.codigo_empresa, 'VENDEDOR', v_com.codigo_vendedor_omie, v_nf.data_emissao) THEN 'VENDEDOR_EXCLUIDO'
    ELSE NULL END;

  CREATE TEMP TABLE IF NOT EXISTS tmp_nf_itens (
    codigo_item_omie bigint, id_item_pedido uuid, id_item_cotado uuid, id_item_real uuid,
    quantidade numeric, valor numeric, pct_cot numeric, pct_real numeric, pct_fin numeric,
    regra text, val_cot numeric, val_calc numeric, completo boolean, qtd_com numeric, pend numeric) ON COMMIT DROP;
  TRUNCATE tmp_nf_itens;

  INSERT INTO tmp_nf_itens
  SELECT pv.codigo_item_omie, vi.id_item_pedido, ic.id, ir.id,
         pv.quantidade::numeric, pv.valor_total,
         ic.comissao_pct, ir.comissao_pct,
         LEAST(ic.comissao_pct, COALESCE(ir.comissao_pct, ic.comissao_pct)),
         CASE WHEN ir.comissao_pct IS NOT NULL AND ir.comissao_pct < ic.comissao_pct THEN ir.regra_aplicada ELSE ic.regra_aplicada END,
         round(pv.valor_total * ic.comissao_pct / 100, 2),
         CASE WHEN v_zero IS NOT NULL THEN 0
              ELSE round(pv.valor_total * q.fator * LEAST(ic.comissao_pct, COALESCE(ir.comissao_pct, ic.comissao_pct)) / 100, 2) END,
         (q.fator >= 1),
         q.qtd_com,
         round(pv.valor_total * (1 - q.fator) * ic.comissao_pct / 100, 2)
    FROM core_vendas_faturamento.produto_vendas pv
    JOIN core_comissao.comissao_itens_vinculo vi
      ON vi.id_comissao = v_com.id AND vi.codigo_item_omie = pv.codigo_item_omie
    JOIN core_comissao.comissao_calculo_itens ic
      ON ic.id_calculo = v_com.id_calculo_cotado AND ic.id_item_proposta = vi.id_item_proposta
    LEFT JOIN core_comissao.comissao_calculo_itens ir
      ON ir.id_calculo = v_com.id_calculo_real AND ir.id_item_proposta = ic.id_item_proposta
    CROSS JOIN LATERAL (
         SELECT w.qtd_com,
                CASE WHEN pv.quantidade::numeric > 0 THEN LEAST(w.qtd_com / pv.quantidade::numeric, 1) ELSE 0 END AS fator
           FROM (SELECT CASE
                   WHEN ic.tipo_item = 'FABRICACAO_INTERNA' THEN pv.quantidade::numeric
                   WHEN ir.id IS NULL THEN 0::numeric
                   ELSE GREATEST(0::numeric, LEAST(pv.quantidade::numeric, COALESCE(ir.quantidade_coberta, 0) - COALESCE((
                          SELECT sum(x.quantidade_comissionavel)
                            FROM core_comissao.comissoes_nf_itens x
                            JOIN core_comissao.comissoes_nf nn ON nn.id = x.id_comissao_nf
                           WHERE nn.id_comissao = v_com.id AND x.codigo_item_omie = pv.codigo_item_omie
                             AND nn.estado <> 'NF_CANCELADA' AND nn.codigo_nf_omie <> p_codigo_nf_omie), 0)
                          - COALESCE((SELECT sum((e ->> 'quantidade')::numeric)
                                        FROM core_comissao.comissao_lancamentos l, jsonb_array_elements(l.itens) e
                                       WHERE l.id_comissao = v_com.id AND l.tipo = 'COMPLEMENTO'
                                         AND (e ->> 'codigo_item_omie')::bigint = pv.codigo_item_omie), 0)))
                 END AS qtd_com) w) q
   WHERE pv.codigo_empresa = v_com.codigo_empresa AND pv.codigo_nf_omie = p_codigo_nf_omie
     AND pv.deleted_at IS NULL AND pv.codigo_item_omie IS NOT NULL;

  SELECT count(*), COALESCE(sum(valor), 0), COALESCE(sum(val_cot), 0), COALESCE(sum(val_calc), 0),
         COALESCE(sum(pend), 0), COALESCE(bool_and(completo), false)
    INTO v_n, v_fat, v_cot, v_calc, v_pend, v_compl FROM tmp_nf_itens;
  IF v_n = 0 THEN
    RAISE EXCEPTION 'Nenhum item da NF % casa com a comissão (comissao_itens_vinculo.codigo_item_omie).', p_codigo_nf_omie USING ERRCODE = '23514';
  END IF;

  SELECT GREATEST(count(DISTINCT pv.codigo_item_omie) - v_n, 0) INTO v_sem
    FROM core_vendas_faturamento.produto_vendas pv
   WHERE pv.codigo_empresa = v_com.codigo_empresa AND pv.codigo_nf_omie = p_codigo_nf_omie AND pv.deleted_at IS NULL;

  IF v_id IS NULL THEN
    v_id := uuidv7();
    INSERT INTO core_comissao.comissoes_nf (
      id, id_comissao, codigo_empresa, codigo_nf_omie, numero_nf, data_emissao, id_calculo_cotado, id_calculo_real,
      valor_faturado, valor_se_cotado, valor_calculado, valor_pendente_custo, comissao_efetiva_pct, custo_completo, qtd_itens,
      qtd_itens_sem_vinculo, motivo_zerado, created_by)
    VALUES (v_id, v_com.id, v_com.codigo_empresa, p_codigo_nf_omie, v_nf.numero_nf, v_nf.data_emissao,
      v_com.id_calculo_cotado, v_com.id_calculo_real, v_fat, v_cot, v_calc, v_pend,
      CASE WHEN v_fat > 0 THEN round(v_calc / v_fat * 100, 4) END, v_compl, v_n, v_sem, v_zero, p_usuario);
    INSERT INTO core_comissao.comissao_eventos (id_comissao, id_comissao_nf, tipo, descricao, dados, feito_por)
    VALUES (v_com.id, v_id, 'NF_FECHADA', format('NF %s fechada: comissão calculada e enviada à Controladoria.', v_nf.numero_nf),
            jsonb_build_object('valor_calculado', v_calc, 'valor_se_cotado', v_cot), p_usuario);
  ELSE
    DELETE FROM core_comissao.comissoes_nf_itens WHERE id_comissao_nf = v_id;
    UPDATE core_comissao.comissoes_nf SET
        id_calculo_cotado = v_com.id_calculo_cotado, id_calculo_real = v_com.id_calculo_real,
        valor_faturado = v_fat, valor_se_cotado = v_cot, valor_calculado = v_calc, valor_pendente_custo = v_pend,
        comissao_efetiva_pct = CASE WHEN v_fat > 0 THEN round(v_calc / v_fat * 100, 4) END,
        custo_completo = v_compl, qtd_itens = v_n, qtd_itens_sem_vinculo = v_sem, motivo_zerado = v_zero,
        recalculada_em = now(), updated_by = p_usuario,
        compras_estado = 'PENDENTE', compras_por = NULL, compras_em = NULL
      WHERE id = v_id;
    INSERT INTO core_comissao.comissao_eventos (id_comissao, id_comissao_nf, tipo, descricao, dados, feito_por)
    VALUES (v_com.id, v_id, 'NF_RECALCULADA', format('NF %s recalculada antes da decisão.', v_nf.numero_nf),
            jsonb_build_object('valor_calculado', v_calc, 'valor_se_cotado', v_cot), p_usuario);
  END IF;

  INSERT INTO core_comissao.comissoes_nf_itens (
    id_comissao_nf, id_item_cotado, id_item_real, id_item_pedido, codigo_item_omie, quantidade_faturada,
    valor_faturado_item, comissao_cotada_pct, comissao_real_pct, comissao_final_pct, regra_aplicada,
    valor_se_cotado, valor_calculado, quantidade_comissionavel, valor_pendente_custo)
  SELECT v_id, id_item_cotado, id_item_real, id_item_pedido, codigo_item_omie, quantidade, valor,
         pct_cot, pct_real, pct_fin, regra, val_cot, val_calc, qtd_com, pend FROM tmp_nf_itens;
  RETURN v_id;
END $$;
COMMENT ON FUNCTION core_comissao.fn_comissao_nf_fechar(uuid, bigint, uuid) IS 'Fecha a comissão de uma NF só sobre as peças que já têm custo real (N16-48) e sem pagar duas vezes a mesma quantidade quando o item sai em várias NFs (N16-49): por item faturado, round(valor x LEAST(percentual cotado, percentual real) / 100, 2) (mesma conta de vw_simulacao_resolvida). Aplica exclusão (valor 0 e motivo). Refaz enquanto AGUARDANDO_DECISAO; depois da decisão recusa.';

-- 7.7 Decisão sobre a comissão de uma NF (Controladoria, Gerência ou Coordenação)
CREATE OR REPLACE FUNCTION core_comissao.fn_comissao_decidir(
  p_id_comissao_nf uuid, p_tipo text, p_justificativa text, p_usuario uuid,
  p_corte_pct numeric DEFAULT NULL, p_valor_novo numeric DEFAULT NULL,
  p_perfil text DEFAULT 'CONTROLADORIA', p_pct_novo numeric DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  n core_comissao.comissoes_nf%ROWTYPE;
  v_vend uuid; v_depois numeric; v_novo text; v_seq integer; v_id uuid; v_antes numeric;
BEGIN
  SELECT * INTO n FROM core_comissao.comissoes_nf WHERE id = p_id_comissao_nf FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Comissão da NF % não existe.', p_id_comissao_nf USING ERRCODE = 'P0002'; END IF;
  IF p_perfil NOT IN ('CONTROLADORIA','GERENCIA','COORDENACAO') THEN
    RAISE EXCEPTION 'perfil deve ser CONTROLADORIA, GERENCIA ou COORDENACAO.' USING ERRCODE = '22023';
  END IF;
  SELECT id_usuario_vendedor INTO v_vend FROM core_comissao.comissoes WHERE id = n.id_comissao;
  IF v_vend IS NOT NULL AND v_vend = p_usuario THEN
    RAISE EXCEPTION 'Ninguém decide sobre a própria comissão (N16-44).' USING ERRCODE = '23514';
  END IF;
  IF n.estado NOT IN ('AGUARDANDO_DECISAO','BLOQUEADA') THEN
    RAISE EXCEPTION 'Esta comissão já tem decisão final (%): decide-se uma vez só.', n.estado USING ERRCODE = '23514';
  END IF;
  IF char_length(btrim(COALESCE(p_justificativa, ''))) < 10 THEN
    RAISE EXCEPTION 'Justificativa obrigatória (mínimo de 10 caracteres).' USING ERRCODE = '23514';
  END IF;
  IF p_tipo IN ('APROVAR','CORTAR','ALTERAR') AND n.compras_estado <> 'CONFIRMADA' AND EXISTS (
       SELECT 1 FROM core_comissao.comissao_calculos cq JOIN core_comissao.parametros pa ON pa.id = cq.id_parametros
        WHERE cq.id = n.id_calculo_cotado AND pa.exige_conferencia_compras) THEN
    RAISE EXCEPTION 'Compras ainda não confirmou o percentual desta NF (%): % exige a conferência de Compras (parâmetro exige_conferencia_compras). Desaprovar e bloquear não exigem.', n.compras_estado, p_tipo USING ERRCODE = '23514';
  END IF;
  v_antes := n.valor_calculado;
  CASE p_tipo
    WHEN 'APROVAR'    THEN v_depois := v_antes;                                         v_novo := 'APROVADA';
    WHEN 'DESAPROVAR' THEN v_depois := 0;                                               v_novo := 'DESAPROVADA';
    WHEN 'BLOQUEAR'   THEN
      IF n.estado = 'BLOQUEADA' THEN RAISE EXCEPTION 'A comissão já está bloqueada.' USING ERRCODE = '23514'; END IF;
      v_depois := 0; v_novo := 'BLOQUEADA';
    WHEN 'DESBLOQUEAR' THEN
      IF n.estado <> 'BLOQUEADA' THEN RAISE EXCEPTION 'Só se desbloqueia uma comissão BLOQUEADA.' USING ERRCODE = '23514'; END IF;
      v_depois := 0; v_novo := 'AGUARDANDO_DECISAO';
    WHEN 'CORTAR'     THEN
      IF p_corte_pct IS NULL OR p_corte_pct <= 0 OR p_corte_pct >= 100 THEN
        RAISE EXCEPTION 'CORTAR exige corte_pct entre 0 e 100 (exclusive).' USING ERRCODE = '23514';
      END IF;
      v_depois := round(v_antes * (1 - p_corte_pct / 100), 2);                          v_novo := 'CORTADA';
    WHEN 'ALTERAR'    THEN
      IF (p_valor_novo IS NULL) = (p_pct_novo IS NULL) THEN
        RAISE EXCEPTION 'ALTERAR exige valor_novo OU pct_novo (um dos dois).' USING ERRCODE = '23514';
      END IF;
      IF COALESCE(p_valor_novo, 0) < 0 OR COALESCE(p_pct_novo, 0) < 0 OR COALESCE(p_pct_novo, 0) > 100 THEN
        RAISE EXCEPTION 'ALTERAR exige valor_novo >= 0 ou pct_novo entre 0 e 100.' USING ERRCODE = '23514';
      END IF;
      v_depois := CASE WHEN p_valor_novo IS NOT NULL THEN round(p_valor_novo, 2)
                       ELSE round(n.valor_faturado * p_pct_novo / 100, 2) END;          v_novo := 'ALTERADA';
    ELSE RAISE EXCEPTION 'tipo deve ser APROVAR, DESAPROVAR, BLOQUEAR, DESBLOQUEAR, CORTAR ou ALTERAR.' USING ERRCODE = '22023';
  END CASE;

  SELECT COALESCE(max(sequencia), 0) + 1 INTO v_seq FROM core_comissao.comissao_decisoes WHERE id_comissao_nf = n.id;
  v_id := uuidv7();
  INSERT INTO core_comissao.comissao_decisoes (id, id_comissao_nf, sequencia, tipo, perfil_decisor, justificativa,
      corte_pct, pct_novo, pct_antes, pct_depois, valor_antes, valor_depois, estado_antes, estado_depois, decidido_por)
  VALUES (v_id, n.id, v_seq, p_tipo, p_perfil, btrim(p_justificativa),
      CASE WHEN p_tipo = 'CORTAR' THEN p_corte_pct END, CASE WHEN p_tipo = 'ALTERAR' THEN p_pct_novo END,
      CASE WHEN n.valor_faturado > 0 THEN round(v_antes / n.valor_faturado * 100, 4) END,
      CASE WHEN n.valor_faturado > 0 THEN round(v_depois / n.valor_faturado * 100, 4) END,
      v_antes, v_depois, n.estado, v_novo, p_usuario);
  UPDATE core_comissao.comissoes_nf SET estado = v_novo,
         valor_final = CASE WHEN v_novo = 'AGUARDANDO_DECISAO' THEN NULL ELSE v_depois END,
         id_decisao_atual = v_id,
         decidida_em = CASE WHEN v_novo = 'AGUARDANDO_DECISAO' THEN NULL ELSE now() END,
         updated_by = p_usuario WHERE id = n.id;
  INSERT INTO core_comissao.comissao_eventos (id_comissao, id_comissao_nf, tipo, descricao, dados, visivel_vendedor, feito_por)
  VALUES (n.id_comissao, n.id, 'DECISAO', format('%s: %s (NF %s).', p_perfil, p_tipo, n.numero_nf),
          jsonb_build_object('tipo', p_tipo, 'perfil', p_perfil, 'valor_antes', v_antes, 'valor_depois', v_depois), true, p_usuario);
  RETURN v_id;
END $$;
COMMENT ON FUNCTION core_comissao.fn_comissao_decidir(uuid, text, text, uuid, numeric, numeric, text, numeric) IS 'Decisão sobre a comissão de uma NF, com justificativa obrigatória, por Controladoria, Gerência ou Coordenação (mesmas permissões; quem decide nunca é o dono da comissão, N16-44). APROVAR, DESAPROVAR, CORTAR e ALTERAR (por valor ou por percentual, sem teto) são finais. BLOQUEAR retém (valor_final 0) e DESBLOQUEAR devolve à fila. Grava quem, com que perfil, quando, valor e percentual antes e depois (N16-45).';

-- 7.7a Lançamentos (complemento, desconto e abatimento)
-- Complemento ou desconto: o motor da API vê que o custo completou depois da decisão da NF e calcula a diferença
-- (N16-48, N16-49); o banco registra e a decisão é nova. A competência é a apuração seguinte.
CREATE OR REPLACE FUNCTION core_comissao.fn_comissao_lancamento_registrar(
  p_id_comissao_nf uuid, p_tipo text, p_valor numeric, p_motivo text, p_usuario uuid DEFAULT NULL,
  p_competencia date DEFAULT NULL, p_itens jsonb DEFAULT '[]'::jsonb) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE n core_comissao.comissoes_nf%ROWTYPE; v_id uuid := uuidv7(); v_comp date;
BEGIN
  SELECT * INTO n FROM core_comissao.comissoes_nf WHERE id = p_id_comissao_nf FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Comissão da NF % não existe.', p_id_comissao_nf USING ERRCODE = 'P0002'; END IF;
  IF p_tipo NOT IN ('COMPLEMENTO','DESCONTO') THEN
    RAISE EXCEPTION 'tipo deve ser COMPLEMENTO ou DESCONTO (abatimento usa fn_comissao_nf_abater).' USING ERRCODE = '22023';
  END IF;
  IF n.estado NOT IN ('APROVADA','DESAPROVADA','CORTADA','ALTERADA') THEN
    RAISE EXCEPTION 'Complemento ou desconto só vale para NF já decidida (estado %).', n.estado USING ERRCODE = '23514';
  END IF;
  IF p_valor IS NULL OR p_valor <= 0 THEN
    RAISE EXCEPTION 'valor deve ser maior que zero (o tipo dá o sinal).' USING ERRCODE = '23514';
  END IF;
  v_comp := COALESCE(p_competencia, (date_trunc('month', now()) + interval '1 month')::date);
  INSERT INTO core_comissao.comissao_lancamentos (id, id_comissao, id_comissao_nf, tipo, origem, codigo_nf_origem,
      valor_calculado, competencia, motivo, itens, created_by)
  VALUES (v_id, n.id_comissao, n.id, p_tipo, 'CUSTO_COMPLETO', n.codigo_nf_omie, round(p_valor, 2), v_comp, btrim(p_motivo), COALESCE(p_itens, '[]'::jsonb), p_usuario);
  INSERT INTO core_comissao.comissao_eventos (id_comissao, id_comissao_nf, tipo, descricao, dados, visivel_vendedor, feito_por)
  VALUES (n.id_comissao, n.id, 'LANCAMENTO', format('%s de R$ %s lançado para a apuração de %s (NF %s).', p_tipo, round(p_valor, 2), v_comp, n.numero_nf),
          jsonb_build_object('lancamento', v_id, 'tipo', p_tipo, 'valor', round(p_valor, 2)), false, p_usuario);
  RETURN v_id;
END $$;
COMMENT ON FUNCTION core_comissao.fn_comissao_lancamento_registrar(uuid, text, numeric, text, uuid, date, jsonb) IS 'Registra complemento ou desconto de uma NF já decidida, quando o custo completa (N16-48, N16-49). Entra na apuração seguinte e aguarda nova decisão.';

CREATE OR REPLACE FUNCTION core_comissao.fn_comissao_lancamento_decidir(
  p_id_lancamento uuid, p_tipo text, p_justificativa text, p_usuario uuid,
  p_corte_pct numeric DEFAULT NULL, p_valor_novo numeric DEFAULT NULL, p_perfil text DEFAULT 'CONTROLADORIA') RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  l core_comissao.comissao_lancamentos%ROWTYPE; v_vend uuid; v_depois numeric; v_novo text; v_seq integer; v_id uuid := uuidv7();
BEGIN
  SELECT * INTO l FROM core_comissao.comissao_lancamentos WHERE id = p_id_lancamento FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Lançamento % não existe.', p_id_lancamento USING ERRCODE = 'P0002'; END IF;
  IF l.tipo = 'ABATIMENTO' THEN
    RAISE EXCEPTION 'Abatimento por NF cancelada ou devolvida não se decide: é automático e proporcional (N16-47).' USING ERRCODE = '23514';
  END IF;
  IF p_perfil NOT IN ('CONTROLADORIA','GERENCIA','COORDENACAO') THEN
    RAISE EXCEPTION 'perfil deve ser CONTROLADORIA, GERENCIA ou COORDENACAO.' USING ERRCODE = '22023';
  END IF;
  SELECT id_usuario_vendedor INTO v_vend FROM core_comissao.comissoes WHERE id = l.id_comissao;
  IF v_vend IS NOT NULL AND v_vend = p_usuario THEN
    RAISE EXCEPTION 'Ninguém decide sobre a própria comissão (N16-44).' USING ERRCODE = '23514';
  END IF;
  IF l.estado NOT IN ('AGUARDANDO_DECISAO','BLOQUEADA') THEN
    RAISE EXCEPTION 'Este lançamento já tem decisão final (%).', l.estado USING ERRCODE = '23514';
  END IF;
  IF char_length(btrim(COALESCE(p_justificativa, ''))) < 10 THEN
    RAISE EXCEPTION 'Justificativa obrigatória (mínimo de 10 caracteres).' USING ERRCODE = '23514';
  END IF;
  CASE p_tipo
    WHEN 'APROVAR'     THEN v_depois := l.valor_calculado; v_novo := 'APROVADA';
    WHEN 'DESAPROVAR'  THEN v_depois := 0;                 v_novo := 'DESAPROVADA';
    WHEN 'BLOQUEAR'    THEN
      IF l.estado = 'BLOQUEADA' THEN RAISE EXCEPTION 'O lançamento já está bloqueado.' USING ERRCODE = '23514'; END IF;
      v_depois := 0; v_novo := 'BLOQUEADA';
    WHEN 'DESBLOQUEAR' THEN
      IF l.estado <> 'BLOQUEADA' THEN RAISE EXCEPTION 'Só se desbloqueia um lançamento BLOQUEADO.' USING ERRCODE = '23514'; END IF;
      v_depois := 0; v_novo := 'AGUARDANDO_DECISAO';
    WHEN 'CORTAR'      THEN
      IF p_corte_pct IS NULL OR p_corte_pct <= 0 OR p_corte_pct >= 100 THEN
        RAISE EXCEPTION 'CORTAR exige corte_pct entre 0 e 100 (exclusive).' USING ERRCODE = '23514';
      END IF;
      v_depois := round(l.valor_calculado * (1 - p_corte_pct / 100), 2); v_novo := 'CORTADA';
    WHEN 'ALTERAR'     THEN
      IF p_valor_novo IS NULL OR p_valor_novo < 0 THEN RAISE EXCEPTION 'ALTERAR exige valor_novo >= 0.' USING ERRCODE = '23514'; END IF;
      v_depois := round(p_valor_novo, 2); v_novo := 'ALTERADA';
    ELSE RAISE EXCEPTION 'tipo deve ser APROVAR, DESAPROVAR, BLOQUEAR, DESBLOQUEAR, CORTAR ou ALTERAR.' USING ERRCODE = '22023';
  END CASE;
  SELECT COALESCE(max(sequencia), 0) + 1 INTO v_seq FROM core_comissao.comissao_decisoes WHERE id_lancamento = l.id;
  INSERT INTO core_comissao.comissao_decisoes (id, id_lancamento, sequencia, tipo, perfil_decisor, justificativa, corte_pct,
      valor_antes, valor_depois, estado_antes, estado_depois, decidido_por)
  VALUES (v_id, l.id, v_seq, p_tipo, p_perfil, btrim(p_justificativa), CASE WHEN p_tipo = 'CORTAR' THEN p_corte_pct END,
      l.valor_calculado, v_depois, l.estado, v_novo, p_usuario);
  UPDATE core_comissao.comissao_lancamentos SET estado = v_novo,
         valor_final = CASE WHEN v_novo = 'AGUARDANDO_DECISAO' THEN NULL ELSE v_depois END,
         id_decisao_atual = v_id, decidido_em = CASE WHEN v_novo = 'AGUARDANDO_DECISAO' THEN NULL ELSE now() END,
         updated_by = p_usuario WHERE id = l.id;
  INSERT INTO core_comissao.comissao_eventos (id_comissao, id_comissao_nf, tipo, descricao, dados, visivel_vendedor, feito_por)
  VALUES (l.id_comissao, l.id_comissao_nf, 'DECISAO', format('%s: %s (%s).', p_perfil, p_tipo, l.tipo),
          jsonb_build_object('lancamento', l.id, 'tipo', p_tipo, 'valor_antes', l.valor_calculado, 'valor_depois', v_depois), true, p_usuario);
  RETURN v_id;
END $$;
COMMENT ON FUNCTION core_comissao.fn_comissao_lancamento_decidir(uuid, text, text, uuid, numeric, numeric, text) IS 'Nova decisão sobre um complemento ou desconto (N16-48, N16-49). Mesmas regras da decisão da NF: perfil, justificativa, rastro, ninguém decide sobre a própria comissão.';

-- 7.7d NF cancelada, devolvida ou recusada pelo cliente: abatimento proporcional (N16-47)
CREATE OR REPLACE FUNCTION core_comissao.fn_comissao_nf_abater(
  p_id_comissao_nf uuid, p_origem text, p_proporcao_pct numeric, p_motivo text,
  p_usuario uuid DEFAULT NULL, p_competencia date DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  n core_comissao.comissoes_nf%ROWTYPE; v_id uuid := uuidv7(); v_base numeric; v_valor numeric; v_ja numeric; v_comp date;
BEGIN
  SELECT * INTO n FROM core_comissao.comissoes_nf WHERE id = p_id_comissao_nf FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Comissão da NF % não existe.', p_id_comissao_nf USING ERRCODE = 'P0002'; END IF;
  IF p_origem NOT IN ('NF_CANCELADA','DEVOLUCAO','RECUSA_CLIENTE') THEN
    RAISE EXCEPTION 'origem deve ser NF_CANCELADA, DEVOLUCAO ou RECUSA_CLIENTE.' USING ERRCODE = '22023';
  END IF;
  IF p_proporcao_pct IS NULL OR p_proporcao_pct <= 0 OR p_proporcao_pct > 100 THEN
    RAISE EXCEPTION 'proporcao_pct deve estar entre 0 (exclusive) e 100.' USING ERRCODE = '23514';
  END IF;
  IF char_length(btrim(COALESCE(p_motivo, ''))) < 3 THEN
    RAISE EXCEPTION 'Motivo obrigatório.' USING ERRCODE = '23514';
  END IF;
  IF n.estado = 'NF_CANCELADA' THEN
    RAISE EXCEPTION 'Esta NF já foi cancelada.' USING ERRCODE = '23514';
  END IF;
  IF n.estado = 'AGUARDANDO_DECISAO' AND p_proporcao_pct = 100 THEN
    UPDATE core_comissao.comissoes_nf SET estado = 'NF_CANCELADA', updated_by = p_usuario WHERE id = n.id;
    INSERT INTO core_comissao.comissao_eventos (id_comissao, id_comissao_nf, tipo, descricao, visivel_vendedor, feito_por)
    VALUES (n.id_comissao, n.id, 'ESTADO_ALTERADO', format('NF %s cancelada antes da decisão (%s): %s', n.numero_nf, p_origem, btrim(p_motivo)), false, p_usuario);
    RETURN NULL;
  END IF;
  SELECT COALESCE(sum(proporcao_pct), 0) INTO v_ja FROM core_comissao.comissao_lancamentos
   WHERE id_comissao_nf = n.id AND tipo = 'ABATIMENTO';
  IF v_ja + p_proporcao_pct > 100 THEN
    RAISE EXCEPTION 'Os abatimentos desta NF passariam de 100%% (já abatido: % %%).', v_ja USING ERRCODE = '23514';
  END IF;
  v_base := COALESCE(n.valor_final, n.valor_calculado);
  v_valor := round(v_base * p_proporcao_pct / 100, 2);
  IF v_valor <= 0 THEN
    INSERT INTO core_comissao.comissao_eventos (id_comissao, id_comissao_nf, tipo, descricao, visivel_vendedor, feito_por)
    VALUES (n.id_comissao, n.id, 'LANCAMENTO', format('NF %s: %s sem comissão a abater (valor R$ 0).', n.numero_nf, p_origem), false, p_usuario);
    RETURN NULL;
  END IF;
  v_comp := COALESCE(p_competencia,
            CASE WHEN n.paga_em IS NULL THEN date_trunc('month', now())::date
                 ELSE (date_trunc('month', now()) + interval '1 month')::date END);
  INSERT INTO core_comissao.comissao_lancamentos (id, id_comissao, id_comissao_nf, tipo, origem, codigo_nf_origem, proporcao_pct,
      valor_calculado, estado, valor_final, ja_paga, competencia, motivo, created_by)
  VALUES (v_id, n.id_comissao, n.id, 'ABATIMENTO', p_origem, n.codigo_nf_omie, p_proporcao_pct,
      v_valor, 'REGISTRADO', v_valor, n.paga_em IS NOT NULL, v_comp, btrim(p_motivo), p_usuario);
  INSERT INTO core_comissao.comissao_eventos (id_comissao, id_comissao_nf, tipo, descricao, dados, visivel_vendedor, feito_por)
  VALUES (n.id_comissao, n.id, 'LANCAMENTO', format('Abatimento de R$ %s (%s%% da NF %s, %s) na apuração de %s.', v_valor, p_proporcao_pct, n.numero_nf, p_origem, v_comp),
          jsonb_build_object('lancamento', v_id, 'origem', p_origem, 'proporcao_pct', p_proporcao_pct, 'valor', v_valor, 'ja_paga', n.paga_em IS NOT NULL), true, p_usuario);
  RETURN v_id;
END $$;
COMMENT ON FUNCTION core_comissao.fn_comissao_nf_abater(uuid, text, numeric, text, uuid, date) IS 'NF cancelada, devolvida ou recusada pelo cliente (Operação não realizada ou desconhecida), total ou parcial: abate a comissão na mesma proporção (N16-47). Se a NF ainda não foi paga, reduz o valor a pagar do mês; se já foi paga, o desconto entra na próxima apuração. Registra a NF de origem e o motivo; não exige decisão. NF cancelada por inteiro antes da decisão só sai da fila.';

CREATE OR REPLACE FUNCTION core_comissao.fn_comissao_nf_marcar_paga(p_id_comissao_nf uuid, p_data date, p_usuario uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE n core_comissao.comissoes_nf%ROWTYPE;
BEGIN
  SELECT * INTO n FROM core_comissao.comissoes_nf WHERE id = p_id_comissao_nf FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Comissão da NF % não existe.', p_id_comissao_nf USING ERRCODE = 'P0002'; END IF;
  IF n.estado NOT IN ('APROVADA','CORTADA','ALTERADA') THEN
    RAISE EXCEPTION 'Só se marca como paga uma comissão aprovada, cortada ou alterada (estado %).', n.estado USING ERRCODE = '23514';
  END IF;
  UPDATE core_comissao.comissoes_nf SET paga_em = p_data, updated_by = p_usuario WHERE id = n.id;
END $$;
COMMENT ON FUNCTION core_comissao.fn_comissao_nf_marcar_paga(uuid, date, uuid) IS '🟡 Marca a data de pagamento da comissão da NF (OQ-42 define quem informa). Define se um abatimento posterior reduz o valor a pagar ou vira desconto na próxima apuração.';


-- 7.7b Conferência de Compras (o passo "Comissão: após a aprovação de Compras" do simulador atual) 🟡
CREATE OR REPLACE FUNCTION core_comissao.fn_comissao_conferir_compras(
  p_id_comissao_nf uuid, p_tipo text, p_justificativa text, p_usuario uuid) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE n core_comissao.comissoes_nf%ROWTYPE; v_seq integer; v_id uuid := uuidv7();
BEGIN
  SELECT * INTO n FROM core_comissao.comissoes_nf WHERE id = p_id_comissao_nf FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Comissão da NF % não existe.', p_id_comissao_nf USING ERRCODE = 'P0002'; END IF;
  IF n.estado <> 'AGUARDANDO_DECISAO' THEN
    RAISE EXCEPTION 'A conferência de Compras só vale antes da decisão da Controladoria (estado %).', n.estado USING ERRCODE = '23514';
  END IF;
  IF p_tipo NOT IN ('CONFIRMAR','CONTESTAR') THEN
    RAISE EXCEPTION 'tipo deve ser CONFIRMAR ou CONTESTAR.' USING ERRCODE = '22023';
  END IF;
  IF n.id_calculo_real IS NULL THEN
    RAISE EXCEPTION 'NF sem cálculo com custo real: não há percentual de Compras para conferir.' USING ERRCODE = '23514';
  END IF;
  SELECT COALESCE(max(sequencia), 0) + 1 INTO v_seq FROM core_comissao.comissao_conferencias_compras WHERE id_comissao_nf = n.id;
  INSERT INTO core_comissao.comissao_conferencias_compras (id, id_comissao_nf, sequencia, tipo, id_calculo_real, justificativa, feito_por)
  VALUES (v_id, n.id, v_seq, p_tipo, n.id_calculo_real, NULLIF(btrim(COALESCE(p_justificativa, '')), ''), p_usuario);
  UPDATE core_comissao.comissoes_nf SET
      compras_estado = CASE WHEN p_tipo = 'CONFIRMAR' THEN 'CONFIRMADA' ELSE 'CONTESTADA' END,
      compras_por = p_usuario, compras_em = now(), updated_by = p_usuario
    WHERE id = n.id;
  INSERT INTO core_comissao.comissao_eventos (id_comissao, id_comissao_nf, tipo, descricao, dados, visivel_vendedor, feito_por)
  VALUES (n.id_comissao, n.id, 'CONFERENCIA_COMPRAS', format('Compras: %s (NF %s).', p_tipo, n.numero_nf),
          jsonb_build_object('tipo', p_tipo), false, p_usuario);
  RETURN v_id;
END $$;
COMMENT ON FUNCTION core_comissao.fn_comissao_conferir_compras(uuid, text, text, uuid) IS '🟡 Compras confirma ou contesta o cálculo REAL da NF antes da decisão. CONTESTAR exige justificativa (10+). Não altera valores nem a proposta; o evento nunca é visível ao vendedor.';


-- 7.7c NF cancelada no Omie (a pipeline avisa)
CREATE OR REPLACE FUNCTION core_comissao.fn_comissao_nf_cancelar(p_id_comissao_nf uuid, p_usuario uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE n core_comissao.comissoes_nf%ROWTYPE;
BEGIN
  SELECT * INTO n FROM core_comissao.comissoes_nf WHERE id = p_id_comissao_nf FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Comissão da NF % não existe.', p_id_comissao_nf USING ERRCODE = 'P0002'; END IF;
  IF n.estado = 'NF_CANCELADA' THEN
    RAISE EXCEPTION 'Esta NF já foi cancelada.' USING ERRCODE = '23514';
  END IF;
  PERFORM core_comissao.fn_comissao_nf_abater(n.id, 'NF_CANCELADA', 100, 'NF cancelada no Omie', p_usuario);
END $$;
COMMENT ON FUNCTION core_comissao.fn_comissao_nf_cancelar(uuid, uuid) IS 'NF cancelada no Omie. Antes da decisão: sai da fila (NF_CANCELADA). Depois da decisão: abatimento de 100 por cento da comissão (N16-47), por fn_comissao_nf_abater.';

-- 7.8 Coordenadores: vigentes no período e apuração do mês
CREATE OR REPLACE FUNCTION core_comissao.fn_coordenadores_vigentes(p_ini date, p_fim date)
RETURNS TABLE (id_coordenador uuid, id_regra uuid, nome text, tipo text, ajuda_custo numeric, percentual_pct numeric, ordem_desempate smallint)
LANGUAGE sql STABLE AS $$
  SELECT DISTINCT ON (c.id) c.id, r.id, c.nome::text, r.tipo::text, r.ajuda_custo, r.percentual_pct, r.ordem_desempate
    FROM core_comissao.coordenadores c
    JOIN core_comissao.coordenadores_regras r ON r.id_coordenador = c.id
   WHERE c.ativo AND r.vigencia_inicio <= p_fim AND (r.vigencia_fim IS NULL OR r.vigencia_fim >= p_ini)
   ORDER BY c.id, r.vigencia_inicio DESC
$$;
COMMENT ON FUNCTION core_comissao.fn_coordenadores_vigentes(date, date) IS 'Mesma regra de fn_comissao_coordenadores_mes: vigência que cruza o período; se houver duas, vale a que começou por último.';

CREATE OR REPLACE FUNCTION core_comissao.fn_coordenadores_apurar(p_competencia date, p_faturamento_base numeric, p_usuario uuid DEFAULT NULL)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE v_ini date := date_trunc('month', p_competencia)::date; v_n integer;
BEGIN
  IF EXISTS (SELECT 1 FROM core_comissao.coordenadores_apuracoes WHERE competencia = v_ini AND fechada_em IS NOT NULL) THEN
    RAISE EXCEPTION 'A apuração de % já está fechada.', v_ini USING ERRCODE = '23514';
  END IF;
  DELETE FROM core_comissao.coordenadores_apuracoes WHERE competencia = v_ini AND fechada_em IS NULL;
  INSERT INTO core_comissao.coordenadores_apuracoes
    (competencia, id_coordenador, id_regra, tipo, faturamento_base, percentual_pct, ajuda_custo, comissao, total, ordem_desempate, gerada_por)
  SELECT v_ini, v.id_coordenador, v.id_regra, v.tipo, p_faturamento_base, v.percentual_pct, v.ajuda_custo,
         round(v.percentual_pct / 100 * p_faturamento_base, 2),
         v.ajuda_custo + round(v.percentual_pct / 100 * p_faturamento_base, 2), v.ordem_desempate, p_usuario
    FROM core_comissao.fn_coordenadores_vigentes(v_ini, (v_ini + interval '1 month')::date - 1) v;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END $$;
COMMENT ON FUNCTION core_comissao.fn_coordenadores_apurar(date, numeric, uuid) IS '🟡 Gera a foto do mês: comissao = round(percentual/100 x faturamento_base, 2), total = ajuda_custo + comissao. A API passa o faturamento do mês (fn_dashboard_mensal_faturamento). Sem bloqueio por NF.';

-- ----------------------------------------------------------------------------
-- 8. Views
-- ----------------------------------------------------------------------------

-- 8.1 Vendedor: ESTIMADA até a decisão; valor real só depois. Nunca custo, margem nem comparação.
CREATE OR REPLACE VIEW core_comissao.vw_comissao_vendedor AS
SELECT c.id AS id_comissao, c.codigo_empresa, c.codigo_vendedor_omie, c.numero_proposta, c.numero_pedido,
       c.codigo_cliente,
       CASE c.estado WHEN 'ESTIMADA' THEN 'ESTIMADA' WHEN 'CONGELADA' THEN 'ESTIMADA'
                     WHEN 'EM_ACOMPANHAMENTO' THEN 'ESTIMADA' WHEN 'ENCERRADA' THEN 'DECIDIDA'
                     WHEN 'CANCELADA' THEN 'CANCELADA' END AS situacao,
       cc.valor_comissao_total AS valor_estimado,
       cc.comissao_efetiva_pct AS comissao_estimada_pct,
       cc.letra_equivalente   AS letra_estimada,
       COALESCE(d.valor_decidido, 0) AS valor_decidido,
       COALESCE(d.qtd_nf_decididas, 0) AS qtd_nf_decididas,
       COALESCE(d.qtd_nf_em_analise, 0) AS qtd_nf_em_analise,
       c.cancelada_em, c.created_at, c.updated_at
  FROM core_comissao.comissoes c
  LEFT JOIN core_comissao.comissao_calculos cc ON cc.id = c.id_calculo_cotado
  LEFT JOIN LATERAL (
        SELECT sum(n.valor_final) FILTER (WHERE n.estado IN ('APROVADA','DESAPROVADA','CORTADA','ALTERADA','BLOQUEADA')) AS valor_decidido,
               count(*) FILTER (WHERE n.estado IN ('APROVADA','DESAPROVADA','CORTADA','ALTERADA','BLOQUEADA')) AS qtd_nf_decididas,
               count(*) FILTER (WHERE n.estado = 'AGUARDANDO_DECISAO') AS qtd_nf_em_analise
          FROM core_comissao.comissoes_nf n WHERE n.id_comissao = c.id) d ON true;
COMMENT ON VIEW core_comissao.vw_comissao_vendedor IS 'Visão do vendedor por proposta: a comissão ESTIMADA que ele pôs na proposta, sempre; o valor decidido só das NFs que a Controladoria já decidiu. Não traz custo real, margem, queda nem justificativa. A API filtra pelo escopo do vendedor (token).';

CREATE OR REPLACE VIEW core_comissao.vw_comissao_nf_vendedor AS
SELECT n.id AS id_comissao_nf, n.id_comissao, n.codigo_empresa, c.codigo_vendedor_omie, c.numero_proposta, c.numero_pedido,
       n.codigo_nf_omie, n.numero_nf, n.data_emissao, n.valor_faturado,
       CASE WHEN n.estado = 'AGUARDANDO_DECISAO' THEN 'EM_ANALISE' WHEN n.estado = 'NF_CANCELADA' THEN 'NF_CANCELADA' ELSE n.estado END AS situacao,
       CASE WHEN n.estado IN ('AGUARDANDO_DECISAO','NF_CANCELADA') THEN NULL ELSE n.valor_final END AS valor_final,
       CASE WHEN n.estado IN ('AGUARDANDO_DECISAO','NF_CANCELADA') THEN NULL ELSE d.tipo END AS decisao,
       CASE WHEN n.estado IN ('AGUARDANDO_DECISAO','NF_CANCELADA') THEN NULL ELSE d.justificativa END AS justificativa,
       n.decidida_em
  FROM core_comissao.comissoes_nf n
  JOIN core_comissao.comissoes c ON c.id = n.id_comissao
  LEFT JOIN core_comissao.comissao_decisoes d ON d.id = n.id_decisao_atual;
COMMENT ON VIEW core_comissao.vw_comissao_nf_vendedor IS 'Comissão por NF para o vendedor: EM_ANALISE sem valor até a decisão; depois, o valor final, o tipo da decisão e SEMPRE a justificativa (N16-46). Desaprovada aparece com R$ 0 e o motivo (N16-45).';

CREATE OR REPLACE VIEW core_comissao.vw_comissao_lancamentos_vendedor AS
SELECT l.id AS id_lancamento, l.id_comissao, c.codigo_empresa, c.codigo_vendedor_omie, c.numero_proposta, c.numero_pedido,
       n.numero_nf, l.tipo, l.origem, l.competencia,
       CASE WHEN l.estado = 'AGUARDANDO_DECISAO' THEN 'EM_ANALISE' ELSE l.estado END AS situacao,
       CASE WHEN l.estado = 'AGUARDANDO_DECISAO' THEN NULL
            ELSE (CASE WHEN l.tipo = 'COMPLEMENTO' THEN 1 ELSE -1 END) * l.valor_final END AS valor_com_sinal,
       CASE WHEN l.estado = 'AGUARDANDO_DECISAO' THEN NULL ELSE COALESCE(d.justificativa, l.motivo) END AS justificativa
  FROM core_comissao.comissao_lancamentos l
  JOIN core_comissao.comissoes c ON c.id = l.id_comissao
  JOIN core_comissao.comissoes_nf n ON n.id = l.id_comissao_nf
  LEFT JOIN core_comissao.comissao_decisoes d ON d.id = l.id_decisao_atual;
COMMENT ON VIEW core_comissao.vw_comissao_lancamentos_vendedor IS 'Complementos, descontos e abatimentos de uma comissão, para o vendedor: em análise sem valor; depois, o valor com sinal (complemento soma; desconto e abatimento subtraem) e a justificativa ou o motivo.';

-- 8.2 Fila da Controladoria (e detalhe do cabeçalho)
CREATE OR REPLACE VIEW core_comissao.vw_comissao_nf_fila AS
SELECT n.id AS id_comissao_nf, n.id_comissao, n.codigo_empresa, c.codigo_vendedor_omie, c.codigo_cliente,
       c.numero_proposta, c.numero_pedido, n.codigo_nf_omie, n.numero_nf, n.data_emissao,
       n.valor_faturado, n.valor_se_cotado, n.valor_calculado, n.valor_pendente_custo, n.queda_por_custo, n.comissao_efetiva_pct,
       n.custo_completo, n.qtd_itens, n.qtd_itens_sem_vinculo, n.motivo_zerado, n.estado, n.valor_final,
       n.compras_estado, n.compras_em, cr.imposto_completo AS imposto_real_completo,
       c.custo_real_acima_cotado, cr.margem_liquida_pct AS margem_real_pct, cr.letra_equivalente AS letra_real,
       cq.margem_liquida_pct AS margem_cotada_pct, cq.letra_equivalente AS letra_cotada,
       (CURRENT_DATE - n.data_emissao) AS dias_desde_emissao,
       n.decidida_em, n.created_at
  FROM core_comissao.comissoes_nf n
  JOIN core_comissao.comissoes c ON c.id = n.id_comissao
  JOIN core_comissao.comissao_calculos cq ON cq.id = n.id_calculo_cotado
  LEFT JOIN core_comissao.comissao_calculos cr ON cr.id = n.id_calculo_real;
COMMENT ON VIEW core_comissao.vw_comissao_nf_fila IS 'Fila e lista da Controladoria: comissão já calculada por NF, com valor cotado, valor calculado e queda por custo. Filtre estado = AGUARDANDO_DECISAO para a fila. Só para perfil com a tela da Controladoria.';

-- 8.3 Detalhe por item: custo real x cotado (Controladoria e Gerência)
CREATE OR REPLACE VIEW core_comissao.vw_comissao_itens_custo AS
SELECT c.id AS id_comissao, c.codigo_empresa, ic.ordem, ic.id_item_proposta, ic.id_item_pedido, ic.codigo_item_omie,
       ic.descricao, ic.tipo_item, ic.qtd,
       ic.preco_unit_compra_cotado, ic.compra_bruta AS custo_cotado_bruto,
       ir.quantidade_coberta, ir.custo_real_total, ir.custo_real_unitario_medio, ir.custo_completo,
       ir.compra_bruta AS custo_considerado_bruto,
       (ir.custo_real_total - round(ic.preco_unit_compra_cotado * COALESCE(ic.qtd_compra, ic.qtd) * COALESCE(ir.quantidade_coberta, 0) / NULLIF(ic.qtd, 0), 2)) AS diferenca_coberta,
       ic.margem_item_pct AS margem_cotada_pct, ir.margem_item_pct AS margem_real_pct,
       ic.letra_item AS letra_cotada, ir.letra_item AS letra_real,
       ic.comissao_pct AS comissao_cotada_pct, ir.comissao_pct AS comissao_real_pct,
       LEAST(ic.comissao_pct, COALESCE(ir.comissao_pct, ic.comissao_pct)) AS comissao_final_pct,
       ic.regra_aplicada AS regra_cotada, ir.regra_aplicada AS regra_real, ir.custo_real_acima_cotado
  FROM core_comissao.comissoes c
  JOIN core_comissao.comissao_calculo_itens ic ON ic.id_calculo = c.id_calculo_cotado
  LEFT JOIN core_comissao.comissao_calculo_itens ir ON ir.id_calculo = c.id_calculo_real AND ir.id_item_proposta = ic.id_item_proposta;
COMMENT ON VIEW core_comissao.vw_comissao_itens_custo IS 'Item a item: custo cotado x custo real, margem, letra e percentual nas duas versões e o final (o menor). Para a Controladoria e a Gerência; NUNCA para o vendedor.';

-- 8.3b Eventos de custo por item (drill-down da Controladoria, N16-20)
CREATE OR REPLACE VIEW core_comissao.vw_comissao_eventos_custo AS
SELECT c.id AS id_comissao, c.codigo_empresa, ir.ordem AS ordem_item, ir.id_item_proposta, ir.descricao,
       ev.ordem AS ordem_evento, ev.id_custo_evento, ev.codigo_parcial, ev.data_evento, ev.origem, ev.numero_documento,
       ev.fornecedor, ev.quantidade_coberta, ev.valor_unitario, ev.valor_total, ev.moeda, ev.cotacao_moeda,
       ev.condicao_pagamento, ev.encargo_pagamento_pct, ev.frete_tipo, ev.frete_valor, ev.origem_compra,
       ev.ipi_pct, ev.valor_st, ev.valor_difal, ev.imposto_real, ev.compra_bruta, ev.icms_recuperar, ev.valor_ipi,
       ev.frete_evento, ev.custo_liquido
  FROM core_comissao.comissoes c
  JOIN core_comissao.comissao_calculo_itens ir ON ir.id_calculo = c.id_calculo_real
  JOIN core_comissao.comissao_calculo_eventos ev ON ev.id_calculo_item = ir.id;
COMMENT ON VIEW core_comissao.vw_comissao_eventos_custo IS 'Um evento de custo por linha, com as condições do próprio evento, do último cálculo REAL. Só Controladoria e Gerência; NUNCA o vendedor (N16-18).';

-- 8.4 Visão geral (todos os estados)
CREATE OR REPLACE VIEW core_comissao.vw_comissao_visao_geral AS
SELECT c.id AS id_comissao, c.codigo_empresa, c.codigo_vendedor_omie, c.codigo_cliente, c.numero_proposta, c.numero_pedido,
       c.estado, c.custo_real_acima_cotado,
       cq.valor_comissao_total AS valor_estimado, cq.margem_liquida_pct AS margem_cotada_pct,
       cr.valor_comissao_total AS valor_com_custo_real, cr.margem_liquida_pct AS margem_real_pct,
       cr.custo_completo AS custo_real_completo,
       COALESCE(n.qtd_nf, 0) AS qtd_nf, COALESCE(n.qtd_aguardando, 0) AS qtd_nf_aguardando,
       COALESCE(n.valor_faturado, 0) AS valor_faturado, COALESCE(n.valor_calculado, 0) AS valor_calculado,
       COALESCE(n.valor_final, 0) AS valor_final, COALESCE(n.valor_retido, 0) AS valor_bloqueado,
       c.created_at, c.updated_at, c.cancelada_em
  FROM core_comissao.comissoes c
  LEFT JOIN core_comissao.comissao_calculos cq ON cq.id = c.id_calculo_cotado
  LEFT JOIN core_comissao.comissao_calculos cr ON cr.id = c.id_calculo_real
  LEFT JOIN LATERAL (
       SELECT count(*) AS qtd_nf,
              count(*) FILTER (WHERE x.estado = 'AGUARDANDO_DECISAO') AS qtd_aguardando,
              sum(x.valor_faturado) AS valor_faturado, sum(x.valor_calculado) AS valor_calculado,
              sum(x.valor_final) AS valor_final,
              sum(x.valor_calculado) FILTER (WHERE x.estado = 'BLOQUEADA') AS valor_retido
         FROM core_comissao.comissoes_nf x WHERE x.id_comissao = c.id AND x.estado <> 'NF_CANCELADA') n ON true;
COMMENT ON VIEW core_comissao.vw_comissao_visao_geral IS 'Visão geral da Controladoria: toda comissão, em qualquer estado, da estimada ao encerramento, com valores cotado, real, calculado, final e bloqueado.';

-- 8.5 Resumo mensal por vendedor e total (cuidado: dois níveis; filtrar is_total)
CREATE OR REPLACE VIEW core_comissao.vw_comissao_resumo_mensal AS
SELECT n.codigo_empresa, date_trunc('month', n.data_emissao)::date AS mes, c.codigo_vendedor_omie,
       (GROUPING(c.codigo_vendedor_omie) = 1) AS is_total,
       count(*) AS qtd_nf,
       count(*) FILTER (WHERE n.estado = 'AGUARDANDO_DECISAO') AS qtd_aguardando,
       count(*) FILTER (WHERE n.estado IN ('APROVADA','CORTADA','ALTERADA')) AS qtd_aprovadas,
       count(*) FILTER (WHERE n.estado = 'DESAPROVADA') AS qtd_desaprovadas,
       count(*) FILTER (WHERE n.estado = 'BLOQUEADA') AS qtd_bloqueadas,
       sum(n.valor_faturado) AS valor_faturado,
       COALESCE(sum(n.valor_calculado) FILTER (WHERE n.estado = 'AGUARDANDO_DECISAO'), 0) AS valor_a_decidir,
       COALESCE(sum(n.valor_final) FILTER (WHERE n.estado IN ('APROVADA','CORTADA','ALTERADA')), 0) AS valor_a_pagar,
       COALESCE(sum(n.valor_calculado) FILTER (WHERE n.estado = 'BLOQUEADA'), 0) AS valor_bloqueado,
       COALESCE(sum(n.queda_por_custo), 0) AS queda_por_custo
  FROM core_comissao.comissoes_nf n
  JOIN core_comissao.comissoes c ON c.id = n.id_comissao
 WHERE n.estado <> 'NF_CANCELADA'
 GROUP BY GROUPING SETS ((n.codigo_empresa, date_trunc('month', n.data_emissao)),
                         (n.codigo_empresa, date_trunc('month', n.data_emissao), c.codigo_vendedor_omie));
COMMENT ON VIEW core_comissao.vw_comissao_resumo_mensal IS 'Resumo por mês de emissão da NF. DOIS níveis (is_total = true: empresa/mês; false: por vendedor): sem filtrar is_total, somar duplica. valor_bloqueado soma o valor calculado das NFs bloqueadas (no módulo atual essa coluna era sempre 0).';

-- 8.6 Lançamentos do mês (apuração): complementos, descontos e abatimentos, com sinal
CREATE OR REPLACE VIEW core_comissao.vw_comissao_lancamentos_mes AS
SELECT l.competencia, c.codigo_empresa, c.codigo_vendedor_omie,
       sum(CASE WHEN l.tipo = 'COMPLEMENTO' THEN l.valor_final ELSE 0 END) FILTER (WHERE l.estado NOT IN ('AGUARDANDO_DECISAO')) AS complementos,
       sum(CASE WHEN l.tipo = 'DESCONTO'    THEN l.valor_final ELSE 0 END) FILTER (WHERE l.estado NOT IN ('AGUARDANDO_DECISAO')) AS descontos,
       sum(CASE WHEN l.tipo = 'ABATIMENTO'  THEN l.valor_final ELSE 0 END) AS abatimentos,
       count(*) FILTER (WHERE l.estado = 'AGUARDANDO_DECISAO') AS qtd_aguardando_decisao
  FROM core_comissao.comissao_lancamentos l
  JOIN core_comissao.comissoes c ON c.id = l.id_comissao
 GROUP BY l.competencia, c.codigo_empresa, c.codigo_vendedor_omie;
COMMENT ON VIEW core_comissao.vw_comissao_lancamentos_mes IS 'Lançamentos de uma apuração (mês), por vendedor: complementos (+), descontos e abatimentos (-). Para a Controladoria. Complemento e desconto só contam depois de decididos.';

-- 8.7 Relatórios iniciais da Controladoria (N16-50)
-- 🟡 Categoria: hoje só há REVENDA e FABRICACAO_INTERNA (INDUSTRIALIZADO). "Projeto" e "recompra no mesmo pedido" aguardam a OQ-44.
CREATE OR REPLACE VIEW core_comissao.vw_comissao_markup_pedido AS
SELECT c.id AS id_comissao, c.codigo_empresa, c.codigo_vendedor_omie, c.codigo_cliente, c.numero_pedido,
       CASE ir.tipo_item WHEN 'FABRICACAO_INTERNA' THEN 'INDUSTRIALIZADO' ELSE 'REVENDA' END AS categoria,
       sum(COALESCE(ir.venda_item, 0)) AS venda,
       sum(COALESCE(ir.custo_liquido, 0)) AS custo,
       CASE WHEN sum(COALESCE(ir.custo_liquido, 0)) > 0
            THEN round((sum(COALESCE(ir.venda_item, 0)) / sum(ir.custo_liquido) - 1) * 100, 2) END AS markup_real_pct
  FROM core_comissao.comissoes c
  JOIN core_comissao.comissao_calculo_itens ir ON ir.id_calculo = c.id_calculo_real
 WHERE c.estado IN ('EM_ACOMPANHAMENTO','ENCERRADA')
 GROUP BY c.id, c.codigo_empresa, c.codigo_vendedor_omie, c.codigo_cliente, c.numero_pedido, ir.tipo_item;
COMMENT ON VIEW core_comissao.vw_comissao_markup_pedido IS 'Markup real (Venda ÷ Custo - 1) de cada pedido, por categoria (Revenda, Industrializado), com o custo real do último cálculo REAL. Relatório 1 da Michele, parte por pedido.';

CREATE OR REPLACE VIEW core_comissao.vw_comissao_markup_vendedor AS
SELECT m.codigo_empresa, m.codigo_vendedor_omie,
       CASE WHEN GROUPING(m.categoria) = 1 THEN 'CONSOLIDADO' ELSE m.categoria END AS categoria,
       (GROUPING(m.categoria) = 1) AS is_consolidado,
       count(DISTINCT m.id_comissao) AS qtd_pedidos,
       sum(m.venda) AS venda, sum(m.custo) AS custo,
       CASE WHEN sum(m.custo) > 0 THEN round((sum(m.venda) / sum(m.custo) - 1) * 100, 2) END AS markup_real_pct
  FROM core_comissao.vw_comissao_markup_pedido m
 GROUP BY GROUPING SETS ((m.codigo_empresa, m.codigo_vendedor_omie, m.categoria), (m.codigo_empresa, m.codigo_vendedor_omie));
COMMENT ON VIEW core_comissao.vw_comissao_markup_vendedor IS 'Markup real por vendedor, por categoria e consolidado (is_consolidado = true). DOIS níveis: sem filtrar is_consolidado, somar duplica. Relatório 1 da Michele, parte por vendedor.';

CREATE OR REPLACE VIEW core_comissao.vw_comissao_faturamento_x_compras AS
SELECT c.id AS id_comissao, c.codigo_empresa, c.codigo_vendedor_omie, c.numero_pedido, c.estado,
       COALESCE(f.faturado, 0) AS faturamento,
       COALESCE(f.faturado_revenda, 0) AS faturamento_revenda,
       COALESCE(f.faturado_industrializado, 0) AS faturamento_industrializado,
       COALESCE(k.compras, 0) AS compras,
       COALESCE(k.compras_revenda, 0) AS compras_revenda,
       COALESCE(k.compras_industrializado, 0) AS compras_industrializado,
       CASE WHEN COALESCE(k.compras, 0) > 0 THEN round((COALESCE(f.faturado, 0) / k.compras - 1) * 100, 2) END AS markup_real_pct,
       cr.comissao_efetiva_pct,
       COALESCE(f.a_pagar, 0) + COALESCE(l.saldo, 0) AS valor_a_pagar,
       COALESCE(f.retido, 0) AS valor_retido
  FROM core_comissao.comissoes c
  LEFT JOIN core_comissao.comissao_calculos cr ON cr.id = c.id_calculo_real
  LEFT JOIN LATERAL (
       SELECT sum(n.valor_faturado) AS faturado,
              sum(n.valor_final) FILTER (WHERE n.estado IN ('APROVADA','CORTADA','ALTERADA')) AS a_pagar,
              sum(n.valor_calculado) FILTER (WHERE n.estado = 'BLOQUEADA') AS retido,
              (SELECT sum(i.valor_faturado_item) FROM core_comissao.comissoes_nf_itens i
                 JOIN core_comissao.comissao_calculo_itens ci ON ci.id = i.id_item_cotado
                 JOIN core_comissao.comissoes_nf nn ON nn.id = i.id_comissao_nf
                WHERE nn.id_comissao = c.id AND nn.estado <> 'NF_CANCELADA' AND ci.tipo_item <> 'FABRICACAO_INTERNA') AS faturado_revenda,
              (SELECT sum(i.valor_faturado_item) FROM core_comissao.comissoes_nf_itens i
                 JOIN core_comissao.comissao_calculo_itens ci ON ci.id = i.id_item_cotado
                 JOIN core_comissao.comissoes_nf nn ON nn.id = i.id_comissao_nf
                WHERE nn.id_comissao = c.id AND nn.estado <> 'NF_CANCELADA' AND ci.tipo_item = 'FABRICACAO_INTERNA') AS faturado_industrializado
         FROM core_comissao.comissoes_nf n WHERE n.id_comissao = c.id AND n.estado <> 'NF_CANCELADA') f ON true
  LEFT JOIN LATERAL (
       SELECT sum(ir.custo_liquido) AS compras,
              sum(ir.custo_liquido) FILTER (WHERE ir.tipo_item <> 'FABRICACAO_INTERNA') AS compras_revenda,
              sum(ir.custo_liquido) FILTER (WHERE ir.tipo_item = 'FABRICACAO_INTERNA') AS compras_industrializado
         FROM core_comissao.comissao_calculo_itens ir WHERE ir.id_calculo = c.id_calculo_real) k ON true
  LEFT JOIN LATERAL (
       SELECT sum((CASE WHEN x.tipo = 'COMPLEMENTO' THEN 1 ELSE -1 END) * COALESCE(x.valor_final, 0)) AS saldo
         FROM core_comissao.comissao_lancamentos x WHERE x.id_comissao = c.id) l ON true
 WHERE c.estado IN ('EM_ACOMPANHAMENTO','ENCERRADA');
COMMENT ON VIEW core_comissao.vw_comissao_faturamento_x_compras IS 'Faturamento × Compras por pedido, com markup real, percentual de comissão e valor a pagar (NFs decididas mais complementos, descontos e abatimentos), separando Revenda e Industrializado. Relatório 2 da Michele. 🟡 Projeto e recompra no mesmo pedido: OQ-44.';

COMMIT;

-- ----------------------------------------------------------------------------
-- 9. Dependências de core_vendas_faturamento. APLICAR DEPOIS do SQL-016 e do SQL-017.
--    Nomes conferidos contra a migração do SQL-016 de 26/10 (propostas, propostas_itens, pedidos, pedidos_itens, custos_eventos).
--    N16-102: o custo real vale também para o pedido digitado direto no Omie (custos_eventos é por empresa + pedido + produto),
--    mas a comissão NOVA exige proposta (comissoes.id_proposta NOT NULL): o pedido sem proposta segue no motor atual.
-- ----------------------------------------------------------------------------
-- BEGIN;
-- ALTER TABLE core_comissao.comissoes
--   ADD CONSTRAINT fk_comissoes_proposta FOREIGN KEY (id_proposta) REFERENCES core_vendas_faturamento.propostas(id),
--   ADD CONSTRAINT fk_comissoes_pedido   FOREIGN KEY (id_pedido_venda) REFERENCES core_vendas_faturamento.pedidos(id);
-- ALTER TABLE core_comissao.comissao_calculo_itens
--   ADD CONSTRAINT fk_calc_itens_proposta FOREIGN KEY (id_item_proposta) REFERENCES core_vendas_faturamento.propostas_itens(id),
--   ADD CONSTRAINT fk_calc_itens_pedido   FOREIGN KEY (id_item_pedido) REFERENCES core_vendas_faturamento.pedidos_itens(id);
-- ALTER TABLE core_comissao.comissao_calculo_eventos
--   ADD CONSTRAINT fk_calc_eventos_custo FOREIGN KEY (id_custo_evento) REFERENCES core_vendas_faturamento.custos_eventos(id);
-- ALTER TABLE core_comissao.comissoes_nf_itens
--   ADD CONSTRAINT fk_nf_itens_pedido FOREIGN KEY (id_item_pedido) REFERENCES core_vendas_faturamento.pedidos_itens(id);
--
-- -- Evento de custo novo enfileira o recálculo da comissão do pedido (um registro pendente por comissão e motivo).
-- CREATE OR REPLACE FUNCTION core_comissao.fn_custo_evento_enfileirar() RETURNS trigger LANGUAGE plpgsql AS $$
-- BEGIN
--   INSERT INTO core_comissao.comissao_fila_recalculo (id_comissao, motivo)
--   SELECT c.id, 'CUSTO_REAL' FROM core_comissao.comissoes c
--    WHERE c.id_pedido_venda = NEW.id_pedido AND c.estado = 'EM_ACOMPANHAMENTO'
--   ON CONFLICT (id_comissao, motivo) WHERE processado_em IS NULL DO NOTHING;
--   RETURN NULL;
-- END $$;
-- CREATE TRIGGER trg_custo_evento_enfileirar AFTER INSERT ON core_vendas_faturamento.custos_eventos
--   FOR EACH ROW EXECUTE FUNCTION core_comissao.fn_custo_evento_enfileirar();
--
-- -- Rede de segurança: comissões EM_ACOMPANHAMENTO cujo custo real mudou desde o último cálculo REAL
-- -- (colunas de core_vendas_faturamento.vw_pedido_item_custo: id_item_pedido, quantidade_coberta, custo_total, eventos).
-- CREATE OR REPLACE VIEW core_comissao.vw_comissao_custo_divergente AS
-- SELECT c.id AS id_comissao
--   FROM core_comissao.comissoes c
--  WHERE c.estado = 'EM_ACOMPANHAMENTO'
--    AND EXISTS (
--      SELECT 1
--        FROM core_vendas_faturamento.vw_pedido_item_custo v
--        LEFT JOIN core_comissao.comissao_calculo_itens ir
--               ON ir.id_calculo = c.id_calculo_real AND ir.id_item_pedido = v.id_item_pedido
--       WHERE v.id_pedido = c.id_pedido_venda
--         AND (ir.id IS NULL
--              OR ir.quantidade_coberta IS DISTINCT FROM v.quantidade_coberta
--              OR ir.custo_real_total   IS DISTINCT FROM v.custo_total
--              OR ir.qtd_eventos        IS DISTINCT FROM v.eventos));
-- COMMENT ON VIEW core_comissao.vw_comissao_custo_divergente IS 'Comissão com custo real novo desde o último cálculo REAL: o job do motor recalcula estas (e enfileira em comissao_fila_recalculo).';
-- COMMIT;
