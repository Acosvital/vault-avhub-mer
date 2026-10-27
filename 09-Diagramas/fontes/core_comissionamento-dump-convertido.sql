--
-- PostgreSQL database dump
--

\restrict rJqpbYwJ8v8Tx0XT38lqGIy2BdG7hEw0Pa4TyXfex1MgEv0J6vqItWXM8CX7Ceo

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: core_comissionamento; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA core_comissionamento;


ALTER SCHEMA core_comissionamento OWNER TO postgres;

--
-- Name: fn_comissao_coordenadores_historico(); Type: FUNCTION; Schema: core_comissionamento; Owner: postgres
--

CREATE FUNCTION core_comissionamento.fn_comissao_coordenadores_historico() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO core_comissionamento.comissao_coordenadores_historico (id_coordenador, operacao, dados_depois, feito_por)
    VALUES (NEW.id, TG_OP, to_jsonb(NEW), NEW.created_by);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    IF to_jsonb(NEW) - 'updated_at' IS DISTINCT FROM to_jsonb(OLD) - 'updated_at' THEN
      INSERT INTO core_comissionamento.comissao_coordenadores_historico (id_coordenador, operacao, dados_antes, dados_depois, feito_por)
      VALUES (NEW.id, TG_OP, to_jsonb(OLD), to_jsonb(NEW), COALESCE(NEW.deleted_by, NEW.updated_by));
    END IF;
    RETURN NEW;
  ELSE
    INSERT INTO core_comissionamento.comissao_coordenadores_historico (id_coordenador, operacao, dados_antes, feito_por)
    VALUES (OLD.id, TG_OP, to_jsonb(OLD), COALESCE(OLD.deleted_by, OLD.updated_by));
    RETURN OLD;
  END IF;
END $$;


ALTER FUNCTION core_comissionamento.fn_comissao_coordenadores_historico() OWNER TO postgres;

--
-- Name: FUNCTION fn_comissao_coordenadores_historico(); Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON FUNCTION core_comissionamento.fn_comissao_coordenadores_historico() IS 'Contrato 07: grava cada INSERT/UPDATE/DELETE de comissao_coordenadores no histórico (feito_por = created_by / updated_by / deleted_by da linha).';


--
-- Name: fn_comissao_coordenadores_historico_imutavel(); Type: FUNCTION; Schema: core_comissionamento; Owner: postgres
--

CREATE FUNCTION core_comissionamento.fn_comissao_coordenadores_historico_imutavel() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'O histórico de comissao_coordenadores não pode ser alterado nem apagado.'
    USING ERRCODE = '23514';
END $$;


ALTER FUNCTION core_comissionamento.fn_comissao_coordenadores_historico_imutavel() OWNER TO postgres;

--
-- Name: fn_comissao_coordenadores_mes(date, date); Type: FUNCTION; Schema: core_comissionamento; Owner: postgres
--

CREATE FUNCTION core_comissionamento.fn_comissao_coordenadores_mes(p_ini date, p_fim date) RETURNS TABLE(nome text, tipo text, ajuda_custo numeric, percentual_comissao numeric, ordem_desempate smallint)
    LANGUAGE sql STABLE
    AS $$
  SELECT DISTINCT ON (lower(btrim(cc.nome::text)))
         cc.nome::text, cc.tipo::text, cc.ajuda_custo, cc.percentual_comissao, cc.ordem_desempate
    FROM core_comissionamento.comissao_coordenadores cc
   WHERE cc.deleted_at IS NULL
     AND cc.vigencia_inicio <= p_fim
     AND (cc.vigencia_fim IS NULL OR cc.vigencia_fim >= p_ini)
   ORDER BY lower(btrim(cc.nome::text)), cc.vigencia_inicio DESC
$$;


ALTER FUNCTION core_comissionamento.fn_comissao_coordenadores_mes(p_ini date, p_fim date) OWNER TO postgres;

--
-- Name: FUNCTION fn_comissao_coordenadores_mes(p_ini date, p_fim date); Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON FUNCTION core_comissionamento.fn_comissao_coordenadores_mes(p_ini date, p_fim date) IS 'Contrato 07: parâmetros de coordenador vigentes no período (vigência que cruza [p_ini, p_fim]; se a pessoa tiver duas — troca no meio do mês —, vale a que começou por último).';


--
-- Name: fn_dashboard_comissoes(text, boolean, boolean, boolean); Type: FUNCTION; Schema: core_comissionamento; Owner: postgres
--

CREATE FUNCTION core_comissionamento.fn_dashboard_comissoes(p_ano_mes text, p_is_track_record boolean DEFAULT false, p_aplicar_bloqueio boolean DEFAULT false, p_incluir_pedidos boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
  v_ini        date;
  v_fim        date;
  v_fat        numeric := 0;
  v_fat_bloq   numeric := 0;
  v_prov       jsonb;
  v_prov_res   jsonb;
  v_coord      jsonb;
  v_vend       jsonb;
  v_resumo     jsonb;
  v_ger_com    numeric;
  v_ger_bloq   numeric;
  v_ger_ajuda  numeric;
  v_exc_com    numeric;
  v_exc_bloq   numeric;
  v_exc_ajuda  numeric;
  v_qtd_vend   integer;
  v_qtd_coord  integer;
BEGIN
  IF p_ano_mes IS NULL OR p_ano_mes !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' THEN
    RAISE EXCEPTION 'ano_mes deve estar no formato AAAA-MM (ex.: 2026-09).' USING ERRCODE = '22023';
  END IF;
  v_ini := to_date(p_ano_mes || '-01', 'YYYY-MM-DD');
  v_fim := (v_ini + interval '1 month')::date - 1;

  -- Faturamento total do mês: a mesma função/métrica do dash-faturamento.
  SELECT COALESCE(f.faturamento_total, 0) INTO v_fat
    FROM core_vendas_faturamento.fn_dashboard_mensal_faturamento(
           extract(month FROM v_ini)::smallint, extract(year FROM v_ini)::smallint,
           COALESCE(p_is_track_record, false), NULL) f;
  v_fat := COALESCE(v_fat, 0);

  IF p_aplicar_bloqueio THEN
    SELECT COALESCE(sum(n.valor_nf), 0) INTO v_fat_bloq
      FROM core_vendas_faturamento.vw_nf_classified n
     WHERE n.grupo_deducao = 'LIQUIDO'
       AND n.is_track_record = COALESCE(p_is_track_record, false)
       AND n.data_emissao BETWEEN v_ini AND v_fim
       AND EXISTS (SELECT 1 FROM core_comissionamento.bloqueio_comissoes b
                    WHERE b.codigo_empresa = n.codigo_empresa
                      AND b.numero_nf = n.numero_nf
                      AND b.is_blocked);
  END IF;

  SELECT cp.dados INTO v_prov
    FROM core_vendas_faturamento.comissoes_provisoria cp
   WHERE cp.ano_mes = p_ano_mes;
  v_prov_res := COALESCE(v_prov -> 'resumo', '{}'::jsonb);

  -- Gerência
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'posicao', r.posicao,
           'nome', r.nome,
           'tipo', r.tipo,
           'faturado', 0,
           'a_faturar', 0,
           'ajuda_custo', r.ajuda_custo,
           'percentual_comissao', r.percentual,
           'comissao', r.comissao,
           'bloqueado', r.bloqueado,
           'total', r.total
         ) ORDER BY r.posicao), '[]'::jsonb),
         COALESCE(sum(r.comissao), 0), COALESCE(sum(r.bloqueado), 0), COALESCE(sum(r.ajuda_custo), 0),
         count(*)
    INTO v_coord, v_ger_com, v_ger_bloq, v_ger_ajuda, v_qtd_coord
    FROM (SELECT t.*, row_number() OVER (ORDER BY t.total DESC, t.ordem_desempate, t.nome) AS posicao
            FROM (SELECT c.nome, c.tipo, c.ajuda_custo, c.percentual_comissao AS percentual, c.ordem_desempate,
                 round(c.percentual_comissao / 100 * v_fat, 2) AS comissao,
                 round(c.percentual_comissao / 100 * v_fat_bloq, 2) AS bloqueado,
                 c.ajuda_custo + round(c.percentual_comissao / 100 * v_fat, 2)
                               - round(c.percentual_comissao / 100 * v_fat_bloq, 2) AS total
            FROM core_comissionamento.fn_comissao_coordenadores_mes(v_ini, v_fim) c) t WHERE t.tipo = 'gerencia') r;

  SELECT COALESCE(sum(t.comissao), 0), COALESCE(sum(t.bloqueado), 0), COALESCE(sum(t.ajuda_custo), 0)
    INTO v_exc_com, v_exc_bloq, v_exc_ajuda
    FROM (SELECT c.nome, c.tipo, c.ajuda_custo, c.percentual_comissao AS percentual, c.ordem_desempate,
                 round(c.percentual_comissao / 100 * v_fat, 2) AS comissao,
                 round(c.percentual_comissao / 100 * v_fat_bloq, 2) AS bloqueado,
                 c.ajuda_custo + round(c.percentual_comissao / 100 * v_fat, 2)
                               - round(c.percentual_comissao / 100 * v_fat_bloq, 2) AS total
            FROM core_comissionamento.fn_comissao_coordenadores_mes(v_ini, v_fim) c) t WHERE t.tipo = 'excecao';

  -- Vendedores = relatório provisório do mês + exceções, num ranking só.
  WITH prov AS (
    SELECT e.v ->> 'vendedor' AS nome,
           'vendedor'::text AS tipo,
           core_comissionamento.fn_jsonb_numero(e.v -> 'valorTotalFaturado') AS faturado,
           core_comissionamento.fn_jsonb_numero(e.v -> 'valorTotalPendente') AS a_faturar,
           core_comissionamento.fn_jsonb_numero(e.v -> 'AjudaCusto')         AS ajuda_custo,
           NULL::numeric AS percentual,
           core_comissionamento.fn_jsonb_numero(e.v -> 'valorTotalComissao') AS comissao,
           core_comissionamento.fn_jsonb_numero(e.v -> 'valorBloqueado')     AS bloqueado,
           core_comissionamento.fn_jsonb_numero(e.v -> 'totalPedidos')          AS total_pedidos,
           core_comissionamento.fn_jsonb_numero(e.v -> 'totalPedidosFaturados') AS total_pedidos_faturados,
           core_comissionamento.fn_jsonb_numero(e.v -> 'totalPedidosAFaturar')  AS total_pedidos_a_faturar,
           CASE WHEN jsonb_typeof(e.v -> 'pedidos') = 'array' THEN e.v -> 'pedidos' ELSE '[]'::jsonb END AS pedidos,
           32767::smallint AS ordem_desempate
      FROM jsonb_array_elements(
             CASE WHEN jsonb_typeof(v_prov -> 'vendedores') = 'array' THEN v_prov -> 'vendedores' ELSE '[]'::jsonb END
           ) AS e(v)
     WHERE jsonb_typeof(e.v) = 'object'
  ), exc AS (
    SELECT t.nome, t.tipo, 0::numeric, 0::numeric, t.ajuda_custo, t.percentual, t.comissao, t.bloqueado,
           0::numeric, 0::numeric, 0::numeric, '[]'::jsonb, t.ordem_desempate
      FROM (SELECT c.nome, c.tipo, c.ajuda_custo, c.percentual_comissao AS percentual, c.ordem_desempate,
                 round(c.percentual_comissao / 100 * v_fat, 2) AS comissao,
                 round(c.percentual_comissao / 100 * v_fat_bloq, 2) AS bloqueado,
                 c.ajuda_custo + round(c.percentual_comissao / 100 * v_fat, 2)
                               - round(c.percentual_comissao / 100 * v_fat_bloq, 2) AS total
            FROM core_comissionamento.fn_comissao_coordenadores_mes(v_ini, v_fim) c) t WHERE t.tipo = 'excecao'
  ), todos AS (
    SELECT u.*, u.ajuda_custo + u.comissao - u.bloqueado AS total
      FROM (SELECT * FROM prov UNION ALL SELECT * FROM exc) u
  ), ranking AS (
    SELECT t.*, row_number() OVER (ORDER BY t.total DESC, t.ordem_desempate, t.nome) AS posicao
      FROM todos t
  )
  SELECT COALESCE(jsonb_agg(
           jsonb_build_object(
             'posicao', r.posicao,
             'nome', r.nome,
             'tipo', r.tipo,
             'faturado', r.faturado,
             'a_faturar', r.a_faturar,
             'ajuda_custo', r.ajuda_custo,
             'percentual_comissao', r.percentual,
             'comissao', r.comissao,
             'bloqueado', r.bloqueado,
             'total', r.total,
             'total_pedidos', r.total_pedidos,
             'total_pedidos_faturados', r.total_pedidos_faturados,
             'total_pedidos_a_faturar', r.total_pedidos_a_faturar
           ) || CASE WHEN p_incluir_pedidos THEN jsonb_build_object('pedidos', r.pedidos) ELSE '{}'::jsonb END
           ORDER BY r.posicao), '[]'::jsonb),
         count(*)
    INTO v_vend, v_qtd_vend
    FROM ranking r;

  -- Os 4 cartões e o total geral (mesmas contas da página dash-comissoes).
  v_resumo := jsonb_build_object(
    'comissao_vendedores',
      core_comissionamento.fn_jsonb_numero(v_prov_res -> 'valorTotalComissao') + v_exc_com
      - core_comissionamento.fn_jsonb_numero(v_prov_res -> 'valorTotalBloqueado') - v_exc_bloq,
    'comissoes_bloqueadas',
      core_comissionamento.fn_jsonb_numero(v_prov_res -> 'valorTotalBloqueado') + v_exc_bloq + v_ger_bloq,
    'ajuda_custo',
      core_comissionamento.fn_jsonb_numero(v_prov_res -> 'totalAjudaCusto') + v_ger_ajuda + v_exc_ajuda,
    'comissao_gerencia', v_ger_com - v_ger_bloq
  );
  v_resumo := v_resumo || jsonb_build_object(
    'total_geral',
      (v_resumo ->> 'comissao_vendedores')::numeric + (v_resumo ->> 'comissoes_bloqueadas')::numeric
      + (v_resumo ->> 'ajuda_custo')::numeric + (v_resumo ->> 'comissao_gerencia')::numeric,
    'qtd_vendedores', v_qtd_vend,
    'qtd_coordenadores', v_qtd_coord
  );

  RETURN jsonb_build_object(
    'ano_mes', p_ano_mes,
    'is_track_record', COALESCE(p_is_track_record, false),
    'faturamento_total', v_fat,
    'bloqueio_coordenadores_aplicado', COALESCE(p_aplicar_bloqueio, false),
    'faturamento_bloqueado', CASE WHEN p_aplicar_bloqueio THEN v_fat_bloq ELSE NULL END,
    'resumo', v_resumo,
    'vendedores', v_vend,
    'coordenadores', v_coord,
    'provisoria', jsonb_build_object(
      'disponivel', v_prov IS NOT NULL,
      'mes', v_prov ->> 'mes',
      'gerado_em', v_prov ->> 'gerado_em',
      'resumo', CASE WHEN v_prov IS NULL THEN NULL ELSE v_prov_res END
    )
  );
END $_$;


ALTER FUNCTION core_comissionamento.fn_dashboard_comissoes(p_ano_mes text, p_is_track_record boolean, p_aplicar_bloqueio boolean, p_incluir_pedidos boolean) OWNER TO postgres;

--
-- Name: FUNCTION fn_dashboard_comissoes(p_ano_mes text, p_is_track_record boolean, p_aplicar_bloqueio boolean, p_incluir_pedidos boolean); Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON FUNCTION core_comissionamento.fn_dashboard_comissoes(p_ano_mes text, p_is_track_record boolean, p_aplicar_bloqueio boolean, p_incluir_pedidos boolean) IS 'Contrato 07: dashboard de comissões do mês (AAAA-MM) pronto. vendedores[] = relatório provisório (comissoes_provisoria; comissão e bloqueio como o gerador mandou) + coordenadores tipo excecao; coordenadores[] = tipo gerencia. Coordenador: comissao = round(percentual/100 × faturamento total do mês, 2) — faturamento de fn_dashboard_mensal_faturamento(mes, ano, is_track_record, NULL); bloqueado = round(percentual/100 × valor das NFs do mês com bloqueio_comissoes.is_blocked, 2) só com p_aplicar_bloqueio (senão 0). total = ajuda_custo + comissao − bloqueado; posicao = ordem por total desc, ordem_desempate, nome. resumo = os 4 cartões da página (comissao_vendedores já sem o bloqueado; comissao_gerencia sem o bloqueado da gerência) + total_geral. Parâmetro de coordenador = vigência que cruza o mês (a mais recente, se houver duas). Sem relatório provisório no mês: vendedores = só as exceções e provisoria.disponivel = false. p_incluir_pedidos = devolve pedidos[] de cada vendedor (como veio no relatório).';


--
-- Name: fn_jsonb_numero(jsonb); Type: FUNCTION; Schema: core_comissionamento; Owner: postgres
--

CREATE FUNCTION core_comissionamento.fn_jsonb_numero(p_valor jsonb) RETURNS numeric
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $_$
  SELECT CASE
           WHEN jsonb_typeof(p_valor) = 'number' THEN p_valor::text::numeric
           WHEN jsonb_typeof(p_valor) = 'string'
                AND btrim(p_valor #>> '{}') ~ '^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$'
             THEN btrim(p_valor #>> '{}')::numeric
           ELSE 0
         END
$_$;


ALTER FUNCTION core_comissionamento.fn_jsonb_numero(p_valor jsonb) OWNER TO postgres;

--
-- Name: FUNCTION fn_jsonb_numero(p_valor jsonb); Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON FUNCTION core_comissionamento.fn_jsonb_numero(p_valor jsonb) IS 'Contrato 07: valor numérico de um campo do relatório provisório de comissão (número ou texto numérico; ausente/inválido = 0).';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: blacklist_comissoes_destinatario; Type: TABLE; Schema: core_comissionamento; Owner: postgres
--

CREATE TABLE core_comissionamento.blacklist_comissoes_destinatario (
    codigo_empresa uuid NOT NULL,
    codigo_cliente character varying(60) NOT NULL,
    observacao text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    CONSTRAINT ck_blacklist_comissoes_destinatario_codigo CHECK ((btrim((codigo_cliente)::text) <> ''::text))
);


ALTER TABLE core_comissionamento.blacklist_comissoes_destinatario OWNER TO postgres;

--
-- Name: TABLE blacklist_comissoes_destinatario; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON TABLE core_comissionamento.blacklist_comissoes_destinatario IS 'Clientes excluídos do comissionamento, por código Omie + unidade. Uma linha
por (codigo_empresa, codigo_cliente); a presença da linha é o bloqueio, não há
coluna de estado. Lida por view -- ver comentário de codigo_cliente antes de
escrever o join.';


--
-- Name: COLUMN blacklist_comissoes_destinatario.codigo_cliente; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.blacklist_comissoes_destinatario.codigo_cliente IS 'Mesmo domínio de notas_fiscais.codigo_cliente: varchar(60), código Omie do
parceiro. Só é único DENTRO da mesma conta Omie, por isso compõe a PK com
codigo_empresa. Em core.parceiros a coluna equivalente chama-se
codigo_parceiro_omie e é varchar(15) -- casar os dois exige cast ::text, como
já fazem vw_vendas_base e fn_ranking_clientes_*.';


--
-- Name: blacklist_comissoes_vendedores; Type: TABLE; Schema: core_comissionamento; Owner: postgres
--

CREATE TABLE core_comissionamento.blacklist_comissoes_vendedores (
    codigo_empresa uuid NOT NULL,
    codigo_vendedor_omie character varying(11) NOT NULL,
    observacao text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    CONSTRAINT ck_blacklist_comissoes_vendedores_codigo CHECK ((btrim((codigo_vendedor_omie)::text) <> ''::text))
);


ALTER TABLE core_comissionamento.blacklist_comissoes_vendedores OWNER TO postgres;

--
-- Name: TABLE blacklist_comissoes_vendedores; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON TABLE core_comissionamento.blacklist_comissoes_vendedores IS 'Vendedores excluídos do comissionamento, por código Omie + unidade. Uma linha
por (codigo_empresa, codigo_vendedor_omie); a presença da linha é o bloqueio.
Não confundir com core_vendas_faturamento.blacklist_vendedor_g5, que é outra
coisa: casa por TERMO de texto e alimenta a linha G5 da cascata de deduções do
faturamento.';


--
-- Name: COLUMN blacklist_comissoes_vendedores.codigo_vendedor_omie; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.blacklist_comissoes_vendedores.codigo_vendedor_omie IS 'Mesmo domínio de notas_fiscais.codigo_vendedor_omie: varchar(11). Casa com
core_vendas_faturamento.vendedores(codigo_empresa, codigo_vendedor_omie), que
é a PK daquela tabela.';


--
-- Name: bloqueio_comissoes; Type: TABLE; Schema: core_comissionamento; Owner: postgres
--

CREATE TABLE core_comissionamento.bloqueio_comissoes (
    codigo_empresa uuid NOT NULL,
    numero_nf character varying(10) NOT NULL,
    is_blocked boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    motivo character varying(255),
    CONSTRAINT ck_bloqueio_comissoes_numero_nf CHECK (((numero_nf)::text ~ '^[0-9]+$'::text))
);


ALTER TABLE core_comissionamento.bloqueio_comissoes OWNER TO postgres;

--
-- Name: TABLE bloqueio_comissoes; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON TABLE core_comissionamento.bloqueio_comissoes IS 'Bloqueio de comissão por nota fiscal. Uma linha por (codigo_empresa,
numero_nf). Desbloquear é is_blocked = false, não DELETE -- assim a auditoria
de quem bloqueou fica preservada. Ausência de linha = comissão liberada.';


--
-- Name: COLUMN bloqueio_comissoes.codigo_empresa; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.bloqueio_comissoes.codigo_empresa IS 'UUID da unidade (core.unidades). Compõe a PK junto com numero_nf, porque
número de NF só é único dentro da mesma conta Omie -- mesma razão do UNIQUE
em notas_fiscais.';


--
-- Name: COLUMN bloqueio_comissoes.numero_nf; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.bloqueio_comissoes.numero_nf IS 'Mesmo domínio de core_vendas_faturamento.notas_fiscais.numero_nf: varchar(10)
ZERO-PADDED (''00051698'', não ''51698''). Gravar sem o padding cria um
bloqueio que nunca casa com a NF, e nada no banco avisa -- não há FK para
notas_fiscais de propósito (ver comentário na migration).';


--
-- Name: COLUMN bloqueio_comissoes.is_blocked; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.bloqueio_comissoes.is_blocked IS 'TRUE = comissão bloqueada para esta NF. DEFAULT false (fail-safe: o default
nunca bloqueia dinheiro de vendedor sozinho).';


--
-- Name: COLUMN bloqueio_comissoes.motivo; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.bloqueio_comissoes.motivo IS 'Justificativa do bloqueio, texto livre. NULO é normal: registro criado antes
desta coluna, ou desbloqueio (is_blocked = false) sem observação. Não há
validação de conteúdo -- quem audita comissão lê isto junto com created_by e
updated_at.';


--
-- Name: comissao_coordenadores; Type: TABLE; Schema: core_comissionamento; Owner: postgres
--

CREATE TABLE core_comissionamento.comissao_coordenadores (
    id uuid DEFAULT uuidv7() NOT NULL,
    nome character varying(100) NOT NULL,
    id_funcionario uuid,
    tipo character varying(10) NOT NULL,
    ajuda_custo numeric(14,2) DEFAULT 0 NOT NULL,
    percentual_comissao numeric(7,4) DEFAULT 0 NOT NULL,
    ordem_desempate smallint DEFAULT 0 NOT NULL,
    vigencia_inicio date NOT NULL,
    vigencia_fim date,
    observacao text,
    origem character varying(30) DEFAULT 'manual'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid,
    CONSTRAINT ck_comissao_coord_ajuda CHECK ((ajuda_custo >= (0)::numeric)),
    CONSTRAINT ck_comissao_coord_nome CHECK ((btrim((nome)::text) <> ''::text)),
    CONSTRAINT ck_comissao_coord_percentual CHECK (((percentual_comissao >= (0)::numeric) AND (percentual_comissao <= (100)::numeric))),
    CONSTRAINT ck_comissao_coord_tipo CHECK (((tipo)::text = ANY ((ARRAY['gerencia'::character varying, 'excecao'::character varying])::text[]))),
    CONSTRAINT ck_comissao_coord_vigencia CHECK (((vigencia_fim IS NULL) OR (vigencia_fim >= vigencia_inicio)))
);


ALTER TABLE core_comissionamento.comissao_coordenadores OWNER TO postgres;

--
-- Name: TABLE comissao_coordenadores; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON TABLE core_comissionamento.comissao_coordenadores IS 'Contrato 07: parâmetros de remuneração dos coordenadores do dashboard de comissões (antes lib/comissoes/coordenadores.json do av-hub). tipo gerencia = ranking de gerência (comissão sobre o faturamento total do mês); excecao = entra no ranking de vendedores, com o mesmo cálculo (ex.: Antonio Paiva). Uma linha por pessoa e vigência; mudar valor = fechar a vigência (vigencia_fim) e abrir outra, para os meses passados não mudarem. Toda alteração fica em comissao_coordenadores_historico.';


--
-- Name: COLUMN comissao_coordenadores.nome; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.comissao_coordenadores.nome IS 'Nome como aparece no dashboard. Mesma pessoa = mesmo nome (sem diferenciar maiúsculas); é a chave da vigência.';


--
-- Name: COLUMN comissao_coordenadores.id_funcionario; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.comissao_coordenadores.id_funcionario IS 'Opcional: funcionário (core.funcionarios) da pessoa.';


--
-- Name: COLUMN comissao_coordenadores.percentual_comissao; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.comissao_coordenadores.percentual_comissao IS 'Em PONTOS PERCENTUAIS: 0,35 = 0,35% do faturamento total do mês (era porcentagemComissao do JSON; a comissão é percentual/100 × faturamento).';


--
-- Name: COLUMN comissao_coordenadores.ordem_desempate; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.comissao_coordenadores.ordem_desempate IS 'Desempate do ranking quando o total empata (menor primeiro). Substitui as casas decimais que o JSON somava à ajuda de custo (4500,0005 … 4500,0001) só para fixar a ordem.';


--
-- Name: COLUMN comissao_coordenadores.vigencia_fim; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.comissao_coordenadores.vigencia_fim IS 'NULL = vigente sem data de fim. Vigências da mesma pessoa não podem se sobrepor (ex_comissao_coord_vigencia).';


--
-- Name: comissao_coordenadores_historico; Type: TABLE; Schema: core_comissionamento; Owner: postgres
--

CREATE TABLE core_comissionamento.comissao_coordenadores_historico (
    id bigint NOT NULL,
    id_coordenador uuid NOT NULL,
    operacao character varying(10) NOT NULL,
    dados_antes jsonb,
    dados_depois jsonb,
    feito_por uuid,
    feito_em timestamp with time zone DEFAULT now() NOT NULL,
    usuario_banco text DEFAULT CURRENT_USER NOT NULL,
    CONSTRAINT ck_comissao_coord_hist_operacao CHECK (((operacao)::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying, 'DELETE'::character varying])::text[])))
);


ALTER TABLE core_comissionamento.comissao_coordenadores_historico OWNER TO postgres;

--
-- Name: TABLE comissao_coordenadores_historico; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON TABLE core_comissionamento.comissao_coordenadores_historico IS 'Contrato 07: auditoria de comissao_coordenadores (quem mudou ajuda de custo/percentual/vigência, quando, antes e depois). Só INSERT: UPDATE/DELETE barrados.';


--
-- Name: comissao_coordenadores_historico_id_seq; Type: SEQUENCE; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE core_comissionamento.comissao_coordenadores_historico ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME core_comissionamento.comissao_coordenadores_historico_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: regras_comissoes_fixas; Type: TABLE; Schema: core_comissionamento; Owner: postgres
--

CREATE TABLE core_comissionamento.regras_comissoes_fixas (
    comissao_padrao numeric(10,2) NOT NULL,
    comissao_condicional numeric(10,2) NOT NULL,
    margem numeric(10,2) NOT NULL,
    id uuid DEFAULT uuidv7() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    codigo_empresa uuid NOT NULL,
    codigo_cliente character varying(60) NOT NULL,
    CONSTRAINT ck_regras_comissoes_fixas_codigo_cliente CHECK ((btrim((codigo_cliente)::text) <> ''::text)),
    CONSTRAINT regras_comissoes_fixas_comissao_condicional_check CHECK (((comissao_condicional >= (0)::numeric) AND (comissao_condicional <= (100)::numeric))),
    CONSTRAINT regras_comissoes_fixas_comissao_padrao_check CHECK (((comissao_padrao >= (0)::numeric) AND (comissao_padrao <= (100)::numeric))),
    CONSTRAINT regras_comissoes_fixas_margem_check CHECK (((margem >= (0)::numeric) AND (margem <= (100)::numeric)))
);


ALTER TABLE core_comissionamento.regras_comissoes_fixas OWNER TO postgres;

--
-- Name: TABLE regras_comissoes_fixas; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON TABLE core_comissionamento.regras_comissoes_fixas IS 'Regra de comissão fixa por cliente. Uma linha por (codigo_empresa,
codigo_cliente) vivo. Percentuais em pontos percentuais, 0 a 100 -- NÃO em
fração (12.5 = 12,5%, não 1250%). A regra é POR UNIDADE: o mesmo cliente em
duas unidades precisa de duas linhas.';


--
-- Name: COLUMN regras_comissoes_fixas.comissao_padrao; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.regras_comissoes_fixas.comissao_padrao IS 'Percentual aplicado quando a condição de margem não é atingida. 0 a 100.';


--
-- Name: COLUMN regras_comissoes_fixas.comissao_condicional; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.regras_comissoes_fixas.comissao_condicional IS 'Percentual aplicado quando a margem do negócio atinge a coluna `margem`. 0 a 100.';


--
-- Name: COLUMN regras_comissoes_fixas.margem; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.regras_comissoes_fixas.margem IS 'Margem mínima (%) que dispara comissao_condicional no lugar de comissao_padrao.';


--
-- Name: COLUMN regras_comissoes_fixas.deleted_at; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.regras_comissoes_fixas.deleted_at IS 'Soft delete. A API (paranoid: true) preenche no DELETE e filtra em todo GET.';


--
-- Name: COLUMN regras_comissoes_fixas.codigo_empresa; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.regras_comissoes_fixas.codigo_empresa IS 'UUID da unidade (core.unidades) dona da regra. Compõe o UNIQUE com
codigo_cliente. NÃO é a PK: a PK continua sendo `id` -- ver comentário na
migration.';


--
-- Name: COLUMN regras_comissoes_fixas.codigo_cliente; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.regras_comissoes_fixas.codigo_cliente IS 'Mesmo domínio de core_vendas_faturamento.notas_fiscais.codigo_cliente:
varchar(60), código Omie do parceiro. Só é único DENTRO da mesma conta Omie,
por isso vem sempre acompanhado de codigo_empresa. Em core.parceiros a coluna
equivalente chama-se codigo_parceiro_omie e é varchar(15) -- casar as duas
exige cast ::text, como já fazem vw_vendas_base e fn_ranking_clientes_*.
Substituiu a coluna `cliente` (nome em texto livre), que casava por nome e
sofria com acento, caixa e razão social alterada.';


--
-- Name: simulacao_itens; Type: TABLE; Schema: core_comissionamento; Owner: postgres
--

CREATE TABLE core_comissionamento.simulacao_itens (
    id uuid DEFAULT uuidv7() NOT NULL,
    id_simulacao uuid NOT NULL,
    ordem integer NOT NULL,
    codigo_item_omie bigint,
    codigo_produto_omie character varying(60),
    codigo_produto character varying(60),
    descricao text,
    qtd double precision NOT NULL,
    unidade character varying(20),
    tipo_item character varying(20) DEFAULT 'REVENDA'::character varying NOT NULL,
    preco_unit_compra numeric(15,4) DEFAULT 0 NOT NULL,
    fornecedor character varying(120),
    origem_compra character varying(50),
    pct_ipi numeric(10,4) DEFAULT 0 NOT NULL,
    valor_st numeric(15,2) DEFAULT 0 NOT NULL,
    preco_unit_venda numeric(15,4) DEFAULT 0 NOT NULL,
    custo_liquido numeric(15,2),
    preco_unit_sugerido numeric(15,4),
    icms_efetivo numeric(10,4),
    pct_impostos numeric(10,4),
    margem_item numeric(10,4),
    letra_item character(1),
    pct_comissao numeric(10,4),
    regra_aplicada character varying(24),
    frete_compra_valor numeric(15,2) DEFAULT 0 NOT NULL,
    qtd_compra double precision,
    unidade_compra character varying(20),
    CONSTRAINT simulacao_itens_letra_check CHECK (((letra_item IS NULL) OR (letra_item = ANY (ARRAY['A'::bpchar, 'B'::bpchar, 'C'::bpchar, 'D'::bpchar])))),
    CONSTRAINT simulacao_itens_ordem_check CHECK ((ordem >= 1)),
    CONSTRAINT simulacao_itens_pct_check CHECK (((pct_comissao IS NULL) OR ((pct_comissao >= (0)::numeric) AND (pct_comissao <= (100)::numeric)))),
    CONSTRAINT simulacao_itens_qtd_check CHECK ((qtd > (0)::double precision)),
    CONSTRAINT simulacao_itens_regra_check CHECK (((regra_aplicada IS NULL) OR ((regra_aplicada)::text = ANY (ARRAY[('PREJUIZO'::character varying)::text, ('FABRICACAO_INTERNA'::character varying)::text, ('LETRA'::character varying)::text, ('TETO_PADRAO'::character varying)::text, ('TETO_CONDICIONAL'::character varying)::text])))),
    CONSTRAINT simulacao_itens_tipo_check CHECK (((tipo_item)::text = ANY (ARRAY[('REVENDA'::character varying)::text, ('FABRICACAO_INTERNA'::character varying)::text])))
);


ALTER TABLE core_comissionamento.simulacao_itens OWNER TO postgres;

--
-- Name: TABLE simulacao_itens; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON TABLE core_comissionamento.simulacao_itens IS 'Itens de uma versão de simulação. A comissão é decidida AQUI, item a item —
simulacoes.letra_equivalente é só informativa. Sem soft delete próprio: o ciclo de
vida é o da simulação pai (ON DELETE CASCADE), e como versão enviada é imutável,
item não é apagado isolado.';


--
-- Name: COLUMN simulacao_itens.codigo_item_omie; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulacao_itens.codigo_item_omie IS 'ide.codigo_item do Omie — identidade da LINHA do pedido, igual a
core_vendas_faturamento.produto_vendas.codigo_item_omie. É por aqui que se cruza a
simulação do vendedor com a de Compras e com o item faturado. NULL só em item
adicionado à mão, que não existe no pedido — esses ficam fora do casamento.
ÚNICO dentro da simulação quando não nulo (uq_simulacao_itens_codigo_item).';


--
-- Name: COLUMN simulacao_itens.preco_unit_compra; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulacao_itens.preco_unit_compra IS 'Preço unitário NA UNIDADE DE COMPRA (ver qtd_compra/unidade_compra).
Até 2026-09 era na unidade de VENDA, com a conversão feita à mão pelo vendedor
(ex.: 2.022 ÷ 4,5 = 449,33 R$/m² em vez de 2.022 R$/PÇ).';


--
-- Name: COLUMN simulacao_itens.margem_item; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulacao_itens.margem_item IS 'Margem LÍQUIDA do item, em pontos percentuais. (venda - custo - venda*opex -
venda*impostos - venda*provisao) / venda. É ela que decide a letra. Não confundir com
simulacoes.markup_bruto, que é outra coisa.';


--
-- Name: COLUMN simulacao_itens.regra_aplicada; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulacao_itens.regra_aplicada IS 'POR QUE este item pagou o que pagou. PREJUIZO (margem<=0, pct=0) | FABRICACAO_INTERNA
(2%) | LETRA (faixa da margem do item) | TETO_PADRAO / TETO_CONDICIONAL (regra fixa do
cliente limitou a letra). Existe para a analista não precisar reabrir o cálculo.';


--
-- Name: COLUMN simulacao_itens.qtd_compra; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulacao_itens.qtd_compra IS 'Quantidade na unidade de COMPRA. Base de compra_bruta
(qtd_compra × preco_unit_compra). NULL em linha gravada antes de 2026-09,
quando a compra era derivada de qtd (a quantidade VENDIDA). NÃO fazer
backfill: o front faz qtd_compra ?? qtd.';


--
-- Name: COLUMN simulacao_itens.unidade_compra; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulacao_itens.unidade_compra IS 'Unidade da compra (PÇ, KG, M2...). Rótulo e auditoria — não entra em cálculo.';


--
-- Name: simulacoes; Type: TABLE; Schema: core_comissionamento; Owner: postgres
--

CREATE TABLE core_comissionamento.simulacoes (
    id uuid DEFAULT uuidv7() NOT NULL,
    codigo_empresa uuid NOT NULL,
    numero_pedido character varying(15) NOT NULL,
    sequencial numeric(4,0),
    codigo_pedido_omie bigint,
    origem character varying(10) NOT NULL,
    versao integer DEFAULT 1 NOT NULL,
    id_simulacao_contestada uuid,
    status character varying(12) DEFAULT 'RASCUNHO'::character varying NOT NULL,
    codigo_vendedor_omie character varying(11),
    codigo_cliente character varying(60),
    data_pedido date,
    estado_destino character varying(40),
    condicao_pagamento character varying(40),
    isento_imposto boolean DEFAULT false NOT NULL,
    frete_compra_tipo character varying(10) DEFAULT 'RATEIO'::character varying NOT NULL,
    frete_compra_valor numeric(15,2) DEFAULT 0 NOT NULL,
    valor_st_venda numeric(15,2) DEFAULT 0 NOT NULL,
    imposto_retido_difal numeric(15,2) DEFAULT 0 NOT NULL,
    frete_venda numeric(15,2) DEFAULT 0 NOT NULL,
    id_parametros uuid NOT NULL,
    custo_total numeric(15,2),
    venda_sugerida numeric(15,2),
    total_nf numeric(15,2),
    valor_liquido numeric(15,2),
    markup_projetado numeric(10,4),
    markup_real numeric(10,4),
    markup_bruto numeric(10,4),
    pct_opex numeric(10,6),
    lucro numeric(15,2),
    margem_liquida numeric(10,4),
    letra_equivalente character(1),
    pct_comissao_efetivo numeric(10,4),
    valor_comissao_total numeric(15,2),
    qtd_itens integer DEFAULT 0 NOT NULL,
    qtd_itens_prejuizo integer DEFAULT 0 NOT NULL,
    observacao text,
    motivo_devolucao text,
    submitted_at timestamp with time zone,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT simulacoes_contestada_check CHECK ((((origem)::text <> 'COMPRAS'::text) OR (id_simulacao_contestada IS NOT NULL))),
    CONSTRAINT simulacoes_devolucao_check CHECK ((((status)::text <> 'DEVOLVIDO'::text) OR (motivo_devolucao IS NOT NULL))),
    CONSTRAINT simulacoes_frete_tipo_check CHECK (((frete_compra_tipo)::text = ANY (ARRAY[('RATEIO'::character varying)::text, ('VALOR'::character varying)::text]))),
    CONSTRAINT simulacoes_letra_check CHECK (((letra_equivalente IS NULL) OR (letra_equivalente = ANY (ARRAY['A'::bpchar, 'B'::bpchar, 'C'::bpchar, 'D'::bpchar])))),
    CONSTRAINT simulacoes_origem_check CHECK (((origem)::text = ANY (ARRAY[('VENDEDOR'::character varying)::text, ('COMPRAS'::character varying)::text]))),
    CONSTRAINT simulacoes_pct_check CHECK (((pct_comissao_efetivo IS NULL) OR ((pct_comissao_efetivo >= (0)::numeric) AND (pct_comissao_efetivo <= (100)::numeric)))),
    CONSTRAINT simulacoes_status_check CHECK (((status)::text = ANY (ARRAY[('RASCUNHO'::character varying)::text, ('ENVIADO'::character varying)::text, ('APROVADO'::character varying)::text, ('CONTESTADO'::character varying)::text, ('DEVOLVIDO'::character varying)::text]))),
    CONSTRAINT simulacoes_submitted_check CHECK ((((status)::text = 'RASCUNHO'::text) OR (submitted_at IS NOT NULL))),
    CONSTRAINT simulacoes_versao_check CHECK ((versao >= 1))
);


ALTER TABLE core_comissionamento.simulacoes OWNER TO postgres;

--
-- Name: TABLE simulacoes; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON TABLE core_comissionamento.simulacoes IS 'Uma linha por VERSÃO de simulação de um pedido. Substitui os arquivos .xlsx que os
vendedores mantinham em pastas de rede. Versão enviada é IMUTÁVEL: correção é versão nova.
A economia de Compras é sempre medida contra a PRIMEIRA versão do vendedor (versao=1,
origem=VENDEDOR), nunca contra a última.';


--
-- Name: COLUMN simulacoes.numero_pedido; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulacoes.numero_pedido IS 'Chave de negócio junto com codigo_empresa e sequencial. NÃO usar codigo_pedido_omie
como identidade: o Omie recria pedidos (delete+insert) com código novo mantendo
numero_pedido+sequencial — ver o comentário de pedidos_vendas.';


--
-- Name: COLUMN simulacoes.codigo_pedido_omie; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulacoes.codigo_pedido_omie IS 'INFORMATIVO. Instável por natureza (o Omie recria pedidos com código novo) e nullable,
por isso NÃO é usado como chave de junção em lugar nenhum — vw_simulacao_resolvida liga
o faturado por (codigo_empresa, codigo_item_omie) do item, que é chave única de verdade.';


--
-- Name: COLUMN simulacoes.status; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulacoes.status IS 'RASCUNHO -> ENVIADO -> {APROVADO | CONTESTADO | DEVOLVIDO}.
Os TRÊS finais são TERMINAIS. Devolvida pelo Compras, a simulação NÃO volta para
RASCUNHO: o vendedor manda uma VERSÃO NOVA (POST, versao = max+1), porque versão
enviada é imutável. Isso também evita colidir com uq_simulacoes_rascunho, que só
admite um rascunho vivo por (pedido, origem).';


--
-- Name: COLUMN simulacoes.id_parametros; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulacoes.id_parametros IS 'Congela qual versão de parâmetros gerou estes números. Obrigatório: sem ele não há
como reproduzir o cálculo depois que os percentuais mudarem.';


--
-- Name: COLUMN simulacoes.markup_bruto; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulacoes.markup_bruto IS 'O "AC8" da planilha: (total_nf - compra_bruta_total) / compra_bruta_total, em pontos
percentuais. É o gatilho do condicional de regras_comissoes_fixas.margem — e NÃO é a
mesma métrica de margem_liquida, que decide a letra. No pedido 26616: markup_bruto
115,24 e margem_liquida 16,37. Não confundir.';


--
-- Name: COLUMN simulacoes.letra_equivalente; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulacoes.letra_equivalente IS 'Letra da margem líquida do pedido inteiro. INFORMATIVA — a comissão é decidida item a
item em simulacao_itens. Existe porque vendedor e Compras raciocinam em letra.';


--
-- Name: simulador_parametros; Type: TABLE; Schema: core_comissionamento; Owner: postgres
--

CREATE TABLE core_comissionamento.simulador_parametros (
    id uuid DEFAULT uuidv7() NOT NULL,
    codigo_empresa uuid NOT NULL,
    vigencia_inicio date NOT NULL,
    vigencia_fim date,
    descricao character varying(60) NOT NULL,
    margem_desejada numeric(10,4) NOT NULL,
    pct_despesas_operacionais numeric(10,6) NOT NULL,
    detalhe_despesas jsonb DEFAULT '{}'::jsonb NOT NULL,
    pct_rateio_logistica numeric(10,6) NOT NULL,
    pct_comissao_provisao numeric(10,4) NOT NULL,
    pct_pis numeric(10,4) NOT NULL,
    pct_cofins numeric(10,4) NOT NULL,
    pct_irpj_base numeric(10,4) NOT NULL,
    pct_irpj numeric(10,4) NOT NULL,
    pct_csll_base numeric(10,4) NOT NULL,
    pct_csll numeric(10,4) NOT NULL,
    pct_adicional_ir numeric(10,4) NOT NULL,
    icms_saida jsonb NOT NULL,
    icms_entrada jsonb NOT NULL,
    encargos_pagamento jsonb NOT NULL,
    faixas_comissao jsonb NOT NULL,
    pct_fabricacao_interna numeric(10,4) NOT NULL,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT simulador_parametros_adir_check CHECK (((pct_adicional_ir >= (0)::numeric) AND (pct_adicional_ir <= (100)::numeric))),
    CONSTRAINT simulador_parametros_cofins_check CHECK (((pct_cofins >= (0)::numeric) AND (pct_cofins <= (100)::numeric))),
    CONSTRAINT simulador_parametros_csll_check CHECK (((pct_csll >= (0)::numeric) AND (pct_csll <= (100)::numeric))),
    CONSTRAINT simulador_parametros_csllb_check CHECK (((pct_csll_base >= (0)::numeric) AND (pct_csll_base <= (100)::numeric))),
    CONSTRAINT simulador_parametros_fabint_check CHECK (((pct_fabricacao_interna >= (0)::numeric) AND (pct_fabricacao_interna <= (100)::numeric))),
    CONSTRAINT simulador_parametros_irpj_check CHECK (((pct_irpj >= (0)::numeric) AND (pct_irpj <= (100)::numeric))),
    CONSTRAINT simulador_parametros_irpjb_check CHECK (((pct_irpj_base >= (0)::numeric) AND (pct_irpj_base <= (100)::numeric))),
    CONSTRAINT simulador_parametros_json_tipos_check CHECK (((jsonb_typeof(detalhe_despesas) = 'object'::text) AND (jsonb_typeof(icms_saida) = 'object'::text) AND (jsonb_typeof(icms_entrada) = 'object'::text) AND (jsonb_typeof(encargos_pagamento) = 'object'::text) AND (jsonb_typeof(faixas_comissao) = 'array'::text) AND (jsonb_array_length(faixas_comissao) > 0))),
    CONSTRAINT simulador_parametros_margem_check CHECK (((margem_desejada >= (0)::numeric) AND (margem_desejada <= (100)::numeric))),
    CONSTRAINT simulador_parametros_opex_check CHECK (((pct_despesas_operacionais >= (0)::numeric) AND (pct_despesas_operacionais <= (100)::numeric))),
    CONSTRAINT simulador_parametros_pis_check CHECK (((pct_pis >= (0)::numeric) AND (pct_pis <= (100)::numeric))),
    CONSTRAINT simulador_parametros_provisao_check CHECK (((pct_comissao_provisao >= (0)::numeric) AND (pct_comissao_provisao <= (100)::numeric))),
    CONSTRAINT simulador_parametros_rateio_check CHECK (((pct_rateio_logistica >= (0)::numeric) AND (pct_rateio_logistica <= (100)::numeric))),
    CONSTRAINT simulador_parametros_vigencia_check CHECK (((vigencia_fim IS NULL) OR (vigencia_fim >= vigencia_inicio)))
);


ALTER TABLE core_comissionamento.simulador_parametros OWNER TO postgres;

--
-- Name: TABLE simulador_parametros; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON TABLE core_comissionamento.simulador_parametros IS 'Parâmetros do simulador de comissões, versionados por vigência. Uma simulação
guarda id_parametros e fica amarrada a essa linha para sempre — é o que garante
que um pedido antigo continue recalculável com os percentuais da época.
NUNCA editar uma linha vigente para mudar valores: feche a vigência (vigencia_fim)
e crie outra, senão o histórico muda retroativamente.';


--
-- Name: COLUMN simulador_parametros.vigencia_fim; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulador_parametros.vigencia_fim IS 'NULL = vigência aberta. Só pode haver uma aberta por unidade
(uq_simulador_parametros_vigente). Fechar a vigência e abrir outra é o
procedimento correto para mudar percentual — editar a linha aberta reescreve o
passado de toda simulação que aponta para ela.';


--
-- Name: COLUMN simulador_parametros.pct_despesas_operacionais; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulador_parametros.pct_despesas_operacionais IS 'Soma das 9 categorias de despesa operacional, em pontos percentuais (11.451734 = 11,451734%).
O detalhe por categoria fica em detalhe_despesas, só para auditoria — o cálculo usa este agregado.';


--
-- Name: COLUMN simulador_parametros.pct_comissao_provisao; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulador_parametros.pct_comissao_provisao IS 'Comissão máxima provisionada DENTRO do mark-up (a linha "COMISSÃO VENDEDOR - MÁXIMA" da planilha).
Hoje 2,0 — igual à comissão da letra A, de propósito: o preço sugerido já cobre o pior caso.';


--
-- Name: COLUMN simulador_parametros.faixas_comissao; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.simulador_parametros.faixas_comissao IS 'Array ordenado do maior para o menor: [{"letra":"A","margem_min":15,"pct":2.0}, ...].
margem_min em pontos percentuais, comparada com simulacao_itens.margem_item.
Intervalos semiabertos [margem_min, proxima_margem_min).';


--
-- Name: vw_simulacao_resolvida; Type: VIEW; Schema: core_comissionamento; Owner: postgres
--

CREATE VIEW core_comissionamento.vw_simulacao_resolvida AS
 WITH corrente AS (
         SELECT DISTINCT ON (simulacoes.codigo_empresa, simulacoes.numero_pedido, COALESCE(simulacoes.sequencial, ('-1'::integer)::numeric), simulacoes.origem) simulacoes.id,
            simulacoes.codigo_empresa,
            simulacoes.numero_pedido,
            simulacoes.sequencial,
            simulacoes.codigo_pedido_omie,
            simulacoes.origem,
            simulacoes.versao,
            simulacoes.id_simulacao_contestada,
            simulacoes.status,
            simulacoes.codigo_vendedor_omie,
            simulacoes.codigo_cliente,
            simulacoes.data_pedido,
            simulacoes.estado_destino,
            simulacoes.condicao_pagamento,
            simulacoes.isento_imposto,
            simulacoes.frete_compra_tipo,
            simulacoes.frete_compra_valor,
            simulacoes.valor_st_venda,
            simulacoes.imposto_retido_difal,
            simulacoes.frete_venda,
            simulacoes.id_parametros,
            simulacoes.custo_total,
            simulacoes.venda_sugerida,
            simulacoes.total_nf,
            simulacoes.valor_liquido,
            simulacoes.markup_projetado,
            simulacoes.markup_real,
            simulacoes.markup_bruto,
            simulacoes.pct_opex,
            simulacoes.lucro,
            simulacoes.margem_liquida,
            simulacoes.letra_equivalente,
            simulacoes.pct_comissao_efetivo,
            simulacoes.valor_comissao_total,
            simulacoes.qtd_itens,
            simulacoes.qtd_itens_prejuizo,
            simulacoes.observacao,
            simulacoes.motivo_devolucao,
            simulacoes.submitted_at,
            simulacoes.created_by,
            simulacoes.updated_by,
            simulacoes.deleted_by,
            simulacoes.created_at,
            simulacoes.updated_at,
            simulacoes.deleted_at
           FROM core_comissionamento.simulacoes
          WHERE ((simulacoes.deleted_at IS NULL) AND ((simulacoes.status)::text = ANY (ARRAY[('ENVIADO'::character varying)::text, ('APROVADO'::character varying)::text, ('CONTESTADO'::character varying)::text])))
          ORDER BY simulacoes.codigo_empresa, simulacoes.numero_pedido, COALESCE(simulacoes.sequencial, ('-1'::integer)::numeric), simulacoes.origem, simulacoes.versao DESC
        ), primeira_vendedor AS (
         SELECT simulacoes.id,
            simulacoes.codigo_empresa,
            simulacoes.numero_pedido,
            simulacoes.sequencial,
            simulacoes.codigo_pedido_omie,
            simulacoes.origem,
            simulacoes.versao,
            simulacoes.id_simulacao_contestada,
            simulacoes.status,
            simulacoes.codigo_vendedor_omie,
            simulacoes.codigo_cliente,
            simulacoes.data_pedido,
            simulacoes.estado_destino,
            simulacoes.condicao_pagamento,
            simulacoes.isento_imposto,
            simulacoes.frete_compra_tipo,
            simulacoes.frete_compra_valor,
            simulacoes.valor_st_venda,
            simulacoes.imposto_retido_difal,
            simulacoes.frete_venda,
            simulacoes.id_parametros,
            simulacoes.custo_total,
            simulacoes.venda_sugerida,
            simulacoes.total_nf,
            simulacoes.valor_liquido,
            simulacoes.markup_projetado,
            simulacoes.markup_real,
            simulacoes.markup_bruto,
            simulacoes.pct_opex,
            simulacoes.lucro,
            simulacoes.margem_liquida,
            simulacoes.letra_equivalente,
            simulacoes.pct_comissao_efetivo,
            simulacoes.valor_comissao_total,
            simulacoes.qtd_itens,
            simulacoes.qtd_itens_prejuizo,
            simulacoes.observacao,
            simulacoes.motivo_devolucao,
            simulacoes.submitted_at,
            simulacoes.created_by,
            simulacoes.updated_by,
            simulacoes.deleted_by,
            simulacoes.created_at,
            simulacoes.updated_at,
            simulacoes.deleted_at
           FROM core_comissionamento.simulacoes
          WHERE ((simulacoes.deleted_at IS NULL) AND ((simulacoes.origem)::text = 'VENDEDOR'::text) AND (simulacoes.versao = 1))
        ), faturado AS (
         SELECT produto_vendas.codigo_empresa,
            produto_vendas.codigo_item_omie,
            (produto_vendas.numero_nf)::text AS numero_nf,
            sum(produto_vendas.valor_total) AS valor_faturado_item
           FROM core_vendas_faturamento.produto_vendas
          WHERE ((produto_vendas.deleted_at IS NULL) AND (produto_vendas.codigo_nf_omie IS NOT NULL) AND (produto_vendas.codigo_item_omie IS NOT NULL))
          GROUP BY produto_vendas.codigo_empresa, produto_vendas.codigo_item_omie, produto_vendas.numero_nf
        )
 SELECT v.codigo_empresa,
    v.numero_pedido,
    v.sequencial,
    v.codigo_vendedor_omie,
    v.codigo_cliente,
    v.data_pedido,
    f.numero_nf,
    iv.codigo_item_omie,
    iv.letra_item AS letra_vendedor,
    iv.pct_comissao AS pct_vendedor,
    ic.letra_item AS letra_compras,
    ic.pct_comissao AS pct_compras,
    t3.pct_final,
    f.valor_faturado_item,
    round(((f.valor_faturado_item * t3.pct_final) / (100)::numeric), 2) AS valor_comissao,
    round(((f.valor_faturado_item * (t2.pct_p_teto - t3.pct_final)) / (100)::numeric), 2) AS economia_compras,
    iv.regra_aplicada AS regra_vendedor,
    ic.regra_aplicada AS regra_compras,
    c.status AS status_analise,
    v.id AS id_simulacao_vendedor,
    c.id AS id_simulacao_compras,
    t1.pct_teto,
        CASE
            WHEN (r.id IS NULL) THEN NULL::character varying
            WHEN ((t3.pct_final IS NULL) OR (t3.pct_sem_teto IS NULL)) THEN NULL::character varying
            WHEN (t3.pct_final >= t3.pct_sem_teto) THEN NULL::character varying
            WHEN (t3.markup_vencedor >= r.margem) THEN 'TETO_CONDICIONAL'::character varying
            ELSE 'TETO_PADRAO'::character varying
        END AS regra_fixa_aplicada
   FROM ((((((((((corrente v
     JOIN core_comissionamento.simulacao_itens iv ON ((iv.id_simulacao = v.id)))
     LEFT JOIN corrente c ON (((c.codigo_empresa = v.codigo_empresa) AND ((c.numero_pedido)::text = (v.numero_pedido)::text) AND (COALESCE(c.sequencial, ('-1'::integer)::numeric) = COALESCE(v.sequencial, ('-1'::integer)::numeric)) AND ((c.origem)::text = 'COMPRAS'::text))))
     LEFT JOIN core_comissionamento.simulacao_itens ic ON (((ic.id_simulacao = c.id) AND (ic.codigo_item_omie = iv.codigo_item_omie))))
     LEFT JOIN primeira_vendedor pv ON (((pv.codigo_empresa = v.codigo_empresa) AND ((pv.numero_pedido)::text = (v.numero_pedido)::text) AND (COALESCE(pv.sequencial, ('-1'::integer)::numeric) = COALESCE(v.sequencial, ('-1'::integer)::numeric)))))
     LEFT JOIN core_comissionamento.simulacao_itens ip ON (((ip.id_simulacao = pv.id) AND (ip.codigo_item_omie = iv.codigo_item_omie))))
     LEFT JOIN faturado f ON (((f.codigo_empresa = v.codigo_empresa) AND (f.codigo_item_omie = iv.codigo_item_omie))))
     LEFT JOIN core_comissionamento.regras_comissoes_fixas r ON (((r.codigo_empresa = v.codigo_empresa) AND ((r.codigo_cliente)::text = (v.codigo_cliente)::text) AND (r.deleted_at IS NULL))))
     CROSS JOIN LATERAL ( SELECT
                CASE
                    WHEN (r.id IS NULL) THEN NULL::numeric
                    WHEN (v.markup_bruto >= r.margem) THEN r.comissao_condicional
                    ELSE r.comissao_padrao
                END AS teto_v,
                CASE
                    WHEN ((r.id IS NULL) OR (c.id IS NULL)) THEN NULL::numeric
                    WHEN (c.markup_bruto >= r.margem) THEN r.comissao_condicional
                    ELSE r.comissao_padrao
                END AS teto_c,
                CASE
                    WHEN ((r.id IS NULL) OR (pv.id IS NULL)) THEN NULL::numeric
                    WHEN (pv.markup_bruto >= r.margem) THEN r.comissao_condicional
                    ELSE r.comissao_padrao
                END AS teto_p,
                CASE
                    WHEN (r.id IS NULL) THEN NULL::numeric
                    WHEN ((c.id IS NOT NULL) AND (c.markup_bruto < r.margem) AND (v.markup_bruto >= r.margem)) THEN r.comissao_padrao
                    WHEN (v.markup_bruto >= r.margem) THEN r.comissao_condicional
                    ELSE r.comissao_padrao
                END AS pct_teto) t1)
     CROSS JOIN LATERAL ( SELECT
                CASE
                    WHEN ((t1.teto_v IS NOT NULL) AND ((iv.regra_aplicada)::text = 'LETRA'::text)) THEN LEAST(iv.pct_comissao, t1.teto_v)
                    ELSE iv.pct_comissao
                END AS pct_v_teto,
                CASE
                    WHEN ((t1.teto_c IS NOT NULL) AND ((ic.regra_aplicada)::text = 'LETRA'::text)) THEN LEAST(ic.pct_comissao, t1.teto_c)
                    ELSE ic.pct_comissao
                END AS pct_c_teto,
                CASE
                    WHEN ((t1.teto_p IS NOT NULL) AND ((ip.regra_aplicada)::text = 'LETRA'::text)) THEN LEAST(ip.pct_comissao, t1.teto_p)
                    ELSE ip.pct_comissao
                END AS pct_p_teto) t2)
     CROSS JOIN LATERAL ( SELECT
                CASE
                    WHEN (iv.pct_comissao IS NULL) THEN NULL::numeric
                    ELSE LEAST(t2.pct_v_teto, COALESCE(t2.pct_c_teto, t2.pct_v_teto))
                END AS pct_final,
                CASE
                    WHEN (iv.pct_comissao IS NULL) THEN NULL::numeric
                    ELSE LEAST(iv.pct_comissao, COALESCE(ic.pct_comissao, iv.pct_comissao))
                END AS pct_sem_teto,
                CASE
                    WHEN ((t2.pct_c_teto IS NOT NULL) AND (t2.pct_c_teto < t2.pct_v_teto)) THEN c.markup_bruto
                    ELSE v.markup_bruto
                END AS markup_vencedor) t3)
  WHERE ((v.origem)::text = 'VENDEDOR'::text);


ALTER VIEW core_comissionamento.vw_simulacao_resolvida OWNER TO postgres;

--
-- Name: VIEW vw_simulacao_resolvida; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON VIEW core_comissionamento.vw_simulacao_resolvida IS 'Resolve as duas versões correntes (vendedor e Compras) e devolve o que pagar por
ITEM. Grão: um item da versão corrente do VENDEDOR. Única peça do simulador que
"calcula", e ainda assim só faz LEAST() sobre percentuais já gravados.

pct_final = menor entre vendedor e Compras. Compras não analisou -> vale o do
vendedor. valor_faturado_item nulo = item ainda NÃO faturado: comissão fica NULA
(pendente), nunca zero — não confundir os dois na tela.

O faturado é ligado por (codigo_empresa, codigo_item_omie), chave de
uq_produto_vendas_item_linha, e NÃO por codigo_pedido_omie, que é instável.

Esta view NÃO aplica blacklist de cliente/vendedor, bloqueio_comissoes nem
refaturamento — isso é da view master que consome esta.';


--
-- Name: vw_comissao_master; Type: VIEW; Schema: core_comissionamento; Owner: postgres
--

CREATE VIEW core_comissionamento.vw_comissao_master AS
 WITH parametros_vigentes AS (
         SELECT p.codigo_empresa,
            max(((f.value ->> 'pct'::text))::numeric) AS pct_maximo
           FROM core_comissionamento.simulador_parametros p,
            LATERAL jsonb_array_elements(p.faixas_comissao) f(value)
          WHERE ((p.deleted_at IS NULL) AND (p.vigencia_fim IS NULL))
          GROUP BY p.codigo_empresa
        ), comissionavel AS (
         SELECT f.data_emissao,
            f.hora_emissao,
            f.nota_fiscal,
            f.cfop,
            f.destinatario,
            f.cnpj_cpf_destinatario,
            f.codigo_categoria_nf,
            f.categoria_nf,
            f.codigo_categoria_pedido,
            f.categoria_pedido,
            f.codigo_vendedor,
            f.vendedor,
            f.total_mercadoria,
            f.desconto,
            f.valor_icms_st,
            f.frete,
            f.seguro,
            f.outras_despesas,
            f.valor_ipi,
            f.total_nota_fiscal,
            f.impostos_aprox_federais,
            f.impostos_aprox_estaduais,
            f.impostos_aprox_municipais,
            f.valor_icms,
            f.valor_pis,
            f.valor_cofins,
            f.valor_fcp_icms,
            f.valor_fcp_icms_st,
            f.valor_icms_desonerado,
            f.tipo_nf,
            f.manifestacao_destinatario,
            f.pedido,
            f.obs_pedido,
            f.numero_contrato,
            f.refaturamento_tipo_ref,
            f.refaturamento_num_ref,
            f.status_refaturamento,
            f.valor_nao_permitido,
            f.total_nota_fiscal_ajustado,
            f.valor_itens,
            f.nome_fantasia_destinatario,
            f.codigo_nf_omie,
            f.codigo_pedido_omie,
            f.codigo_cliente,
            f.codigo_comprador_omie,
            f.oppedido,
            f.chave_nf,
            f.averbado,
            f.filial_vendedor,
            f.etapa,
            f.autorizado,
            f.cancelado,
            f.devolvido,
            f.devolucao_parcial,
            f.denegado,
            f.faturado,
            f.encerrado,
            f.manual_nf,
            f.manual_pedido,
            f.deleted_at,
            f.created_at,
            f.updated_at,
            f.codigo_empresa,
            f.is_track_record,
            f.etapa_descricao,
            f.grupo,
            f.sequencial,
            f.tipo_contrato
           FROM core_vendas_faturamento.vw_faturamento_planilha f
          WHERE ((f.grupo IS NULL) AND (f.faturado = true) AND (f.deleted_at IS NULL) AND (f.pedido IS NOT NULL) AND (f.vendedor IS NOT NULL) AND (NOT (EXISTS ( SELECT 1
                   FROM core_comissionamento.blacklist_comissoes_destinatario bd
                  WHERE ((bd.codigo_empresa = f.codigo_empresa) AND ((bd.codigo_cliente)::text = (f.codigo_cliente)::text))))) AND (NOT (EXISTS ( SELECT 1
                   FROM core_comissionamento.blacklist_comissoes_vendedores bv
                  WHERE ((bv.codigo_empresa = f.codigo_empresa) AND ((bv.codigo_vendedor_omie)::text = (f.codigo_vendedor)::text))))))
        )
 SELECT c.codigo_empresa,
    c.is_track_record,
    c.codigo_nf_omie,
    c.nota_fiscal AS numero_nf,
    c.data_emissao,
    c.pedido AS numero_pedido,
    c.sequencial,
    c.codigo_pedido_omie,
    c.codigo_cliente,
    c.destinatario AS cliente,
    c.codigo_vendedor AS codigo_vendedor_omie,
    c.vendedor,
    c.total_nota_fiscal_ajustado AS valor_faturado_nf,
    s.codigo_item_omie,
    s.letra_vendedor,
    s.pct_vendedor,
    s.letra_compras,
    s.pct_compras,
    s.pct_final,
    s.pct_teto,
    s.regra_vendedor,
    s.regra_compras,
    s.regra_fixa_aplicada,
    s.valor_faturado_item,
    s.economia_compras,
    s.id_simulacao_vendedor,
    s.id_simulacao_compras,
    COALESCE(b.is_blocked, false) AS is_bloqueada,
    (
        CASE
            WHEN COALESCE(b.is_blocked, false) THEN b.motivo
            ELSE NULL::character varying
        END)::character varying(255) AS motivo_bloqueio,
        CASE
            WHEN COALESCE(b.is_blocked, false) THEN (0)::numeric
            ELSE COALESCE(s.valor_comissao, (0)::numeric)
        END AS valor_comissao,
    (
        CASE
            WHEN COALESCE(b.is_blocked, false) THEN 'BLOQUEADA'::text
            WHEN (sp.tem_simulacao IS NOT TRUE) THEN 'SEM_SIMULADOR'::text
            WHEN sp.tem_aprovado THEN
            CASE
                WHEN (s.codigo_item_omie IS NULL) THEN 'ITENS_FORA_DO_SIMULADOR'::text
                ELSE 'VALIDADO'::text
            END
            WHEN sp.tem_rascunho THEN 'RASCUNHO'::text
            WHEN sp.tem_enviado THEN 'AGUARDANDO_COMPRAS'::text
            ELSE 'SEM_SIMULADOR'::text
        END)::character varying(24) AS situacao,
        CASE
            WHEN COALESCE(b.is_blocked, false) THEN (0)::numeric
            WHEN (sp.tem_aprovado AND (s.codigo_item_omie IS NOT NULL) AND (s.valor_comissao IS NOT NULL)) THEN s.valor_comissao
            ELSE round(((COALESCE(s.valor_faturado_item, c.valor_itens, c.total_nota_fiscal_ajustado) * LEAST(COALESCE(pv.pct_maximo, 2.0), COALESCE(GREATEST(r.comissao_padrao, r.comissao_condicional), COALESCE(pv.pct_maximo, 2.0)))) / (100)::numeric), 2)
        END AS valor_comissao_maximo
   FROM (((((comissionavel c
     LEFT JOIN core_comissionamento.vw_simulacao_resolvida s ON (((s.codigo_empresa = c.codigo_empresa) AND ((s.numero_pedido)::text = (c.pedido)::text) AND (s.numero_nf = (c.nota_fiscal)::text) AND (COALESCE(s.sequencial, '-1'::numeric) = COALESCE(c.sequencial, '-1'::numeric)))))
     LEFT JOIN core_comissionamento.bloqueio_comissoes b ON (((b.codigo_empresa = c.codigo_empresa) AND ((b.numero_nf)::text = (c.nota_fiscal)::text))))
     LEFT JOIN core_comissionamento.regras_comissoes_fixas r ON (((r.codigo_empresa = c.codigo_empresa) AND ((r.codigo_cliente)::text = (c.codigo_cliente)::text) AND (r.deleted_at IS NULL))))
     LEFT JOIN parametros_vigentes pv ON ((pv.codigo_empresa = c.codigo_empresa)))
     LEFT JOIN LATERAL ( SELECT true AS tem_simulacao,
            bool_or(((sim.status)::text = 'APROVADO'::text)) AS tem_aprovado,
            bool_or(((sim.status)::text = 'ENVIADO'::text)) AS tem_enviado,
            bool_or(((sim.status)::text = 'RASCUNHO'::text)) AS tem_rascunho
           FROM core_comissionamento.simulacoes sim
          WHERE ((sim.deleted_at IS NULL) AND (sim.codigo_empresa = c.codigo_empresa) AND ((sim.numero_pedido)::text = (c.pedido)::text))
         HAVING (count(*) > 0)) sp ON (true));


ALTER VIEW core_comissionamento.vw_comissao_master OWNER TO postgres;

--
-- Name: VIEW vw_comissao_master; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON VIEW core_comissionamento.vw_comissao_master IS '... (texto atual) ...

REFATURAMENTO QUE CRUZA O MÊS: medido em 23/09/2026 sobre 6 meses de base —
ZERO casos de refaturamento Permitido emitido em mês diferente da nota
original. O risco teórico (original de setembro paga em 10/out, refaturamento
sai em outubro e paga de novo) não se materializa na operação atual.
Reconferir se a política de refaturamento mudar.';


--
-- Name: COLUMN vw_comissao_master.situacao; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.vw_comissao_master.situacao IS 'BLOQUEADA > SEM_SIMULADOR > RASCUNHO > AGUARDANDO_COMPRAS >
ITENS_FORA_DO_SIMULADOR > VALIDADO, nessa ordem de precedência.

A validação é do PEDIDO, não da nota: aprovado uma vez, vale para todos os
sequenciais, inclusive os que faturarem meses depois.';


--
-- Name: COLUMN vw_comissao_master.valor_comissao_maximo; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.vw_comissao_master.valor_comissao_maximo IS 'Pior caso, para a gerência planejar o mês antes de os simuladores existirem.

Base: valor do ITEM (valor_faturado_item ou valor_itens), NÃO
total_nota_fiscal_ajustado -- aquele carrega IPI, ST, frete e seguro, e a
comissão é paga sobre o item. Com o total, o card saía sistematicamente alto e
não era comparável com o realizado ao lado.

Percentual: LEAST(maior faixa vigente, GREATEST(padrão, condicional) do
cliente). GREATEST porque nada no schema impede um cadastro com padrão maior
que condicional, e o pior caso não pode ficar menor que o caso normal.';


--
-- Name: vw_comissao_nf; Type: VIEW; Schema: core_comissionamento; Owner: postgres
--

CREATE VIEW core_comissionamento.vw_comissao_nf AS
 SELECT codigo_empresa,
    is_track_record,
    codigo_nf_omie,
    (numero_nf)::text AS numero_nf,
    data_emissao,
    (numero_pedido)::text AS numero_pedido,
    (sequencial)::numeric AS sequencial,
    codigo_pedido_omie,
    (codigo_cliente)::text AS codigo_cliente,
    (cliente)::text AS cliente,
    (codigo_vendedor_omie)::text AS codigo_vendedor_omie,
    (vendedor)::text AS vendedor,
    (valor_faturado_nf)::numeric AS valor_faturado_nf,
    sum(valor_comissao) AS valor_comissao,
    sum(valor_comissao_maximo) AS valor_comissao_maximo,
    sum(economia_compras) AS economia_compras,
        CASE
            WHEN (sum(valor_faturado_item) > (0)::numeric) THEN round((sum((pct_final * valor_faturado_item)) / sum(valor_faturado_item)), 4)
            ELSE NULL::numeric
        END AS pct_comissao_efetivo,
    min(letra_vendedor) AS letra_vendedor,
    min(letra_compras) AS letra_compras,
    bool_or(is_bloqueada) AS is_bloqueada,
    min((motivo_bloqueio)::text) AS motivo_bloqueio,
    ((ARRAY['BLOQUEADA'::text, 'SEM_SIMULADOR'::text, 'RASCUNHO'::text, 'AGUARDANDO_COMPRAS'::text, 'ITENS_FORA_DO_SIMULADOR'::text, 'VALIDADO'::text])[min(
        CASE (situacao)::text
            WHEN 'BLOQUEADA'::text THEN 1
            WHEN 'SEM_SIMULADOR'::text THEN 2
            WHEN 'RASCUNHO'::text THEN 3
            WHEN 'AGUARDANDO_COMPRAS'::text THEN 4
            WHEN 'ITENS_FORA_DO_SIMULADOR'::text THEN 5
            ELSE 6
        END)])::character varying(24) AS situacao,
    count(*) AS qtd_itens,
    GREATEST((( SELECT count(DISTINCT pv.codigo_item_omie) AS count
           FROM core_vendas_faturamento.produto_vendas pv
          WHERE ((pv.codigo_empresa = vw_comissao_master.codigo_empresa) AND ((pv.numero_nf)::text = (vw_comissao_master.numero_nf)::text) AND (pv.deleted_at IS NULL))) - count(DISTINCT codigo_item_omie)), (0)::bigint) AS qtd_itens_sem_vinculo
   FROM core_comissionamento.vw_comissao_master
  GROUP BY codigo_empresa, is_track_record, codigo_nf_omie, numero_nf, data_emissao, numero_pedido, sequencial, codigo_pedido_omie, codigo_cliente, cliente, codigo_vendedor_omie, vendedor, valor_faturado_nf;


ALTER VIEW core_comissionamento.vw_comissao_nf OWNER TO postgres;

--
-- Name: VIEW vw_comissao_nf; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON VIEW core_comissionamento.vw_comissao_nf IS 'Agregação de vw_comissao_master por nota fiscal. É o que as listas paginam.

Apaga o N+1: Minhas Comissões fazia duas leituras POR PEDIDO e a Visão Geral
uma POR LINHA. Aqui cada tela vira uma leitura paginada.

pct_comissao_efetivo é PONDERADO pelo valor de venda do item, não média
simples. situacao é a MAIS SEVERA entre os itens da nota.';


--
-- Name: COLUMN vw_comissao_nf.qtd_itens_sem_vinculo; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON COLUMN core_comissionamento.vw_comissao_nf.qtd_itens_sem_vinculo IS 'Itens FATURADOS (produto_vendas) que não casaram com nenhum item de simulação.

Medido contra produto_vendas, NÃO contra a própria master: a master só tem
linhas que vieram de vw_simulacao_resolvida, então item fora do simulador não
gera linha e a contagem anterior respondia zero sempre -- inclusive quando
havia itens fora.

É o número que denuncia o caso PARCIAL (simulou 8, faturou 10), em que a nota
fica VALIDADO pagando menos e nada em tela avisa.';


--
-- Name: vw_comissao_resumo_mensal; Type: VIEW; Schema: core_comissionamento; Owner: postgres
--

CREATE VIEW core_comissionamento.vw_comissao_resumo_mensal AS
 SELECT codigo_empresa,
    is_track_record,
    (date_trunc('month'::text, (data_emissao)::timestamp with time zone))::date AS mes,
    codigo_vendedor_omie,
    (GROUPING(codigo_vendedor_omie) = 1) AS is_total,
        CASE
            WHEN (GROUPING(codigo_vendedor_omie) = 1) THEN NULL::text
            ELSE max(vendedor)
        END AS vendedor,
    count(*) AS qtd_notas,
    count(*) FILTER (WHERE ((situacao)::text = 'SEM_SIMULADOR'::text)) AS qtd_sem_simulador,
    count(*) FILTER (WHERE ((situacao)::text = 'RASCUNHO'::text)) AS qtd_rascunho,
    count(*) FILTER (WHERE ((situacao)::text = 'AGUARDANDO_COMPRAS'::text)) AS qtd_aguardando_compras,
    count(*) FILTER (WHERE ((situacao)::text = 'ITENS_FORA_DO_SIMULADOR'::text)) AS qtd_itens_fora,
    count(*) FILTER (WHERE ((situacao)::text = 'VALIDADO'::text)) AS qtd_validado,
    count(*) FILTER (WHERE ((situacao)::text = 'BLOQUEADA'::text)) AS qtd_bloqueada,
    sum(valor_faturado_nf) AS valor_faturado,
    COALESCE(sum(valor_comissao) FILTER (WHERE ((situacao)::text = 'VALIDADO'::text)), (0)::numeric) AS valor_comissao_a_pagar,
    COALESCE(sum(valor_comissao_maximo), (0)::numeric) AS valor_comissao_maximo,
    COALESCE(sum((valor_faturado_nf * (0)::numeric)) FILTER (WHERE ((situacao)::text = 'BLOQUEADA'::text)), (0)::numeric) AS valor_comissao_bloqueado,
    COALESCE(sum(economia_compras), (0)::numeric) AS economia_compras
   FROM core_comissionamento.vw_comissao_nf n
  GROUP BY GROUPING SETS ((codigo_empresa, is_track_record, (date_trunc('month'::text, (data_emissao)::timestamp with time zone))), (codigo_empresa, is_track_record, (date_trunc('month'::text, (data_emissao)::timestamp with time zone)), codigo_vendedor_omie));


ALTER VIEW core_comissionamento.vw_comissao_resumo_mensal OWNER TO postgres;

--
-- Name: VIEW vw_comissao_resumo_mensal; Type: COMMENT; Schema: core_comissionamento; Owner: postgres
--

COMMENT ON VIEW core_comissionamento.vw_comissao_resumo_mensal IS 'Resumo mensal por vendedor para o card da tela e o dashboard.

GROUPING SETS: devolve DOIS níveis.
  is_total = true  -> consolidado da empresa/mês (codigo_vendedor_omie NULO)
  is_total = false -> uma linha por vendedor
A soma das linhas por vendedor bate com a linha de total.

⚠️ SEM FILTRAR is_total os dois níveis vêm juntos e somar DUPLICA. Mesma
armadilha de vw_faturamento_planilha_resumo.';


--
-- Data for Name: blacklist_comissoes_destinatario; Type: TABLE DATA; Schema: core_comissionamento; Owner: postgres
--

INSERT INTO core_comissionamento.blacklist_comissoes_destinatario VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '10366744391', NULL, '2026-09-18 12:57:42.462+00', NULL, '2026-09-18 12:57:42.462+00', NULL);


--
-- Data for Name: blacklist_comissoes_vendedores; Type: TABLE DATA; Schema: core_comissionamento; Owner: postgres
--

INSERT INTO core_comissionamento.blacklist_comissoes_vendedores VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '9797133033', NULL, '2026-09-18 13:29:58.111+00', NULL, '2026-09-18 13:29:58.111+00', NULL);
INSERT INTO core_comissionamento.blacklist_comissoes_vendedores VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '10169070809', NULL, '2026-09-18 13:30:07.56+00', NULL, '2026-09-18 13:30:07.56+00', NULL);
INSERT INTO core_comissionamento.blacklist_comissoes_vendedores VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '9899059381', NULL, '2026-09-18 13:30:37.734+00', NULL, '2026-09-18 13:30:37.734+00', NULL);
INSERT INTO core_comissionamento.blacklist_comissoes_vendedores VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '9765168963', NULL, '2026-09-18 13:30:52.741+00', NULL, '2026-09-18 13:30:52.741+00', NULL);
INSERT INTO core_comissionamento.blacklist_comissoes_vendedores VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '9765164763', NULL, '2026-09-18 13:31:04.78+00', NULL, '2026-09-18 13:31:04.78+00', NULL);
INSERT INTO core_comissionamento.blacklist_comissoes_vendedores VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '9765164722', NULL, '2026-09-18 13:31:14.296+00', NULL, '2026-09-18 13:31:14.296+00', NULL);
INSERT INTO core_comissionamento.blacklist_comissoes_vendedores VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '9764300458', NULL, '2026-09-18 13:31:59.323+00', NULL, '2026-09-18 13:31:59.323+00', NULL);
INSERT INTO core_comissionamento.blacklist_comissoes_vendedores VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '9764300611', NULL, '2026-09-18 18:17:01.431+00', NULL, '2026-09-18 18:17:01.431+00', NULL);


--
-- Data for Name: bloqueio_comissoes; Type: TABLE DATA; Schema: core_comissionamento; Owner: postgres
--

INSERT INTO core_comissionamento.bloqueio_comissoes VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '00052457', false, '2026-09-22 16:02:43.23+00', NULL, '2026-09-22 16:05:04.780512+00', NULL, NULL);
INSERT INTO core_comissionamento.bloqueio_comissoes VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59', '00052480', false, '2026-09-23 13:16:06.65+00', NULL, '2026-09-23 13:16:06.65+00', NULL, NULL);


--
-- Data for Name: comissao_coordenadores; Type: TABLE DATA; Schema: core_comissionamento; Owner: postgres
--

INSERT INTO core_comissionamento.comissao_coordenadores VALUES ('01a0fda7-8dcf-77d6-ab12-3b202dcae3e8', 'SERGIO VITAL', NULL, 'gerencia', 4500.00, 0.3500, 1, '2000-01-01', NULL, 'Carga inicial do coordenadores.json do av-hub (sem data de vigência no JSON).', 'carga_json_2026_10', '2026-10-02 17:26:48.359251+00', NULL, '2026-10-02 17:26:48.359251+00', NULL, NULL, NULL);
INSERT INTO core_comissionamento.comissao_coordenadores VALUES ('01a0fda7-8dd0-73fb-9b9d-a859cc7376ed', 'JOÃO VITOR', NULL, 'gerencia', 4500.00, 0.3500, 2, '2000-01-01', NULL, 'Carga inicial do coordenadores.json do av-hub (sem data de vigência no JSON).', 'carga_json_2026_10', '2026-10-02 17:26:48.359251+00', NULL, '2026-10-02 17:26:48.359251+00', NULL, NULL, NULL);
INSERT INTO core_comissionamento.comissao_coordenadores VALUES ('01a0fda7-8dd0-7561-996a-b51ffaa753bf', 'PEDRO HENRIQUE', NULL, 'gerencia', 4500.00, 0.3500, 3, '2000-01-01', NULL, 'Carga inicial do coordenadores.json do av-hub (sem data de vigência no JSON).', 'carga_json_2026_10', '2026-10-02 17:26:48.359251+00', NULL, '2026-10-02 17:26:48.359251+00', NULL, NULL, NULL);
INSERT INTO core_comissionamento.comissao_coordenadores VALUES ('01a0fda7-8dd0-76aa-9844-eca9ee77c3a8', 'JOÃO PEDRO', NULL, 'gerencia', 4500.00, 0.3500, 4, '2000-01-01', NULL, 'Carga inicial do coordenadores.json do av-hub (sem data de vigência no JSON).', 'carga_json_2026_10', '2026-10-02 17:26:48.359251+00', NULL, '2026-10-02 17:26:48.359251+00', NULL, NULL, NULL);
INSERT INTO core_comissionamento.comissao_coordenadores VALUES ('01a0fda7-8dd0-791d-b08b-41142794781f', 'EUVERALDO OLIVEIRA', NULL, 'gerencia', 4500.00, 0.3500, 5, '2000-01-01', NULL, 'Carga inicial do coordenadores.json do av-hub (sem data de vigência no JSON).', 'carga_json_2026_10', '2026-10-02 17:26:48.359251+00', NULL, '2026-10-02 17:26:48.359251+00', NULL, NULL, NULL);
INSERT INTO core_comissionamento.comissao_coordenadores VALUES ('01a0fda7-8dd0-7a72-ba71-99357176180d', 'ANTONIO PAIVA', NULL, 'excecao', 3500.00, 0.1000, 0, '2000-01-01', NULL, 'Carga inicial do coordenadores.json do av-hub (sem data de vigência no JSON).', 'carga_json_2026_10', '2026-10-02 17:26:48.359251+00', NULL, '2026-10-02 17:26:48.359251+00', NULL, NULL, NULL);


--
-- Data for Name: comissao_coordenadores_historico; Type: TABLE DATA; Schema: core_comissionamento; Owner: postgres
--

INSERT INTO core_comissionamento.comissao_coordenadores_historico OVERRIDING SYSTEM VALUE VALUES (1, '01a0fda7-8dcf-77d6-ab12-3b202dcae3e8', 'INSERT', NULL, '{"id": "01a0fda7-8dcf-77d6-ab12-3b202dcae3e8", "nome": "SERGIO VITAL", "tipo": "gerencia", "origem": "carga_json_2026_10", "created_at": "2026-10-02T14:26:48.359251-03:00", "created_by": null, "deleted_at": null, "deleted_by": null, "observacao": "Carga inicial do coordenadores.json do av-hub (sem data de vigência no JSON).", "updated_at": "2026-10-02T14:26:48.359251-03:00", "updated_by": null, "ajuda_custo": 4500.00, "vigencia_fim": null, "id_funcionario": null, "ordem_desempate": 1, "vigencia_inicio": "2000-01-01", "percentual_comissao": 0.3500}', NULL, '2026-10-02 17:26:48.359251+00', 'avhub_prd_admin');
INSERT INTO core_comissionamento.comissao_coordenadores_historico OVERRIDING SYSTEM VALUE VALUES (2, '01a0fda7-8dd0-73fb-9b9d-a859cc7376ed', 'INSERT', NULL, '{"id": "01a0fda7-8dd0-73fb-9b9d-a859cc7376ed", "nome": "JOÃO VITOR", "tipo": "gerencia", "origem": "carga_json_2026_10", "created_at": "2026-10-02T14:26:48.359251-03:00", "created_by": null, "deleted_at": null, "deleted_by": null, "observacao": "Carga inicial do coordenadores.json do av-hub (sem data de vigência no JSON).", "updated_at": "2026-10-02T14:26:48.359251-03:00", "updated_by": null, "ajuda_custo": 4500.00, "vigencia_fim": null, "id_funcionario": null, "ordem_desempate": 2, "vigencia_inicio": "2000-01-01", "percentual_comissao": 0.3500}', NULL, '2026-10-02 17:26:48.359251+00', 'avhub_prd_admin');
INSERT INTO core_comissionamento.comissao_coordenadores_historico OVERRIDING SYSTEM VALUE VALUES (3, '01a0fda7-8dd0-7561-996a-b51ffaa753bf', 'INSERT', NULL, '{"id": "01a0fda7-8dd0-7561-996a-b51ffaa753bf", "nome": "PEDRO HENRIQUE", "tipo": "gerencia", "origem": "carga_json_2026_10", "created_at": "2026-10-02T14:26:48.359251-03:00", "created_by": null, "deleted_at": null, "deleted_by": null, "observacao": "Carga inicial do coordenadores.json do av-hub (sem data de vigência no JSON).", "updated_at": "2026-10-02T14:26:48.359251-03:00", "updated_by": null, "ajuda_custo": 4500.00, "vigencia_fim": null, "id_funcionario": null, "ordem_desempate": 3, "vigencia_inicio": "2000-01-01", "percentual_comissao": 0.3500}', NULL, '2026-10-02 17:26:48.359251+00', 'avhub_prd_admin');
INSERT INTO core_comissionamento.comissao_coordenadores_historico OVERRIDING SYSTEM VALUE VALUES (4, '01a0fda7-8dd0-76aa-9844-eca9ee77c3a8', 'INSERT', NULL, '{"id": "01a0fda7-8dd0-76aa-9844-eca9ee77c3a8", "nome": "JOÃO PEDRO", "tipo": "gerencia", "origem": "carga_json_2026_10", "created_at": "2026-10-02T14:26:48.359251-03:00", "created_by": null, "deleted_at": null, "deleted_by": null, "observacao": "Carga inicial do coordenadores.json do av-hub (sem data de vigência no JSON).", "updated_at": "2026-10-02T14:26:48.359251-03:00", "updated_by": null, "ajuda_custo": 4500.00, "vigencia_fim": null, "id_funcionario": null, "ordem_desempate": 4, "vigencia_inicio": "2000-01-01", "percentual_comissao": 0.3500}', NULL, '2026-10-02 17:26:48.359251+00', 'avhub_prd_admin');
INSERT INTO core_comissionamento.comissao_coordenadores_historico OVERRIDING SYSTEM VALUE VALUES (5, '01a0fda7-8dd0-791d-b08b-41142794781f', 'INSERT', NULL, '{"id": "01a0fda7-8dd0-791d-b08b-41142794781f", "nome": "EUVERALDO OLIVEIRA", "tipo": "gerencia", "origem": "carga_json_2026_10", "created_at": "2026-10-02T14:26:48.359251-03:00", "created_by": null, "deleted_at": null, "deleted_by": null, "observacao": "Carga inicial do coordenadores.json do av-hub (sem data de vigência no JSON).", "updated_at": "2026-10-02T14:26:48.359251-03:00", "updated_by": null, "ajuda_custo": 4500.00, "vigencia_fim": null, "id_funcionario": null, "ordem_desempate": 5, "vigencia_inicio": "2000-01-01", "percentual_comissao": 0.3500}', NULL, '2026-10-02 17:26:48.359251+00', 'avhub_prd_admin');
INSERT INTO core_comissionamento.comissao_coordenadores_historico OVERRIDING SYSTEM VALUE VALUES (6, '01a0fda7-8dd0-7a72-ba71-99357176180d', 'INSERT', NULL, '{"id": "01a0fda7-8dd0-7a72-ba71-99357176180d", "nome": "ANTONIO PAIVA", "tipo": "excecao", "origem": "carga_json_2026_10", "created_at": "2026-10-02T14:26:48.359251-03:00", "created_by": null, "deleted_at": null, "deleted_by": null, "observacao": "Carga inicial do coordenadores.json do av-hub (sem data de vigência no JSON).", "updated_at": "2026-10-02T14:26:48.359251-03:00", "updated_by": null, "ajuda_custo": 3500.00, "vigencia_fim": null, "id_funcionario": null, "ordem_desempate": 0, "vigencia_inicio": "2000-01-01", "percentual_comissao": 0.1000}', NULL, '2026-10-02 17:26:48.359251+00', 'avhub_prd_admin');


--
-- Data for Name: regras_comissoes_fixas; Type: TABLE DATA; Schema: core_comissionamento; Owner: postgres
--

INSERT INTO core_comissionamento.regras_comissoes_fixas VALUES (0.50, 0.50, 100.00, '01a0b4ca-52fc-7c9f-8c98-713e2bfcf6cd', '2026-09-18 13:52:33.469+00', '2026-09-18 13:52:33.469+00', NULL, '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '9765166690');
INSERT INTO core_comissionamento.regras_comissoes_fixas VALUES (0.50, 0.50, 100.00, '01a0b4ca-bdc5-72b3-9f23-c21ed72c9690', '2026-09-18 13:53:00.808+00', '2026-09-18 13:53:00.808+00', NULL, '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '9765165032');
INSERT INTO core_comissionamento.regras_comissoes_fixas VALUES (0.70, 2.00, 100.00, '01a0b4cc-0018-7cb2-a52e-ae268310ccb7', '2026-09-18 13:54:23.324+00', '2026-09-18 13:54:23.324+00', NULL, '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '10331198821');
INSERT INTO core_comissionamento.regras_comissoes_fixas VALUES (0.50, 0.70, 100.00, '01a0c89c-e04a-7fcf-bebd-4467e20526ec', '2026-09-22 10:15:19.31+00', '2026-09-22 10:19:55.078844+00', '2026-09-22 10:19:55.02+00', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '10309519209');
INSERT INTO core_comissionamento.regras_comissoes_fixas VALUES (0.50, 1.30, 100.00, '01a0c8ab-9982-7105-bd74-c85a5a975dfb', '2026-09-22 10:31:24.231+00', '2026-09-22 10:31:24.231+00', NULL, '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '9821667784');


--
-- Data for Name: simulacao_itens; Type: TABLE DATA; Schema: core_comissionamento; Owner: postgres
--

INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0aa80-61c7-75ed-8342-7be50f6e73b2', '01a0aa7f-bdd6-71fe-87c1-3be33cc4a9a8', 1, 10412968691, '9780749371', 'CH1X2X38K', 'CHAPA A/C ASTM A36 1000MM X 2000MM X 3/8" K', 20000, 'KG', 'REVENDA', 5.3000, 'BENAFER', 'DEMAIS ESTADOS', 3.2500, 0.00, 7.4300, 96725.00, 7.7669, 7.0000, 13.4345, 8.0229, 'D', 0.5000, 'LETRA', 0.00, NULL, NULL);
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0aa80-61c7-79d0-b7c3-cd3e43a19550', '01a0aa7f-bdd6-71fe-87c1-3be33cc4a9a8', 2, 10434336005, '9780749371', 'CH1X2X38K', 'CHAPA A/C ASTM A36 1000MM X 2000MM X 3/8" K', 20000, 'KG', 'REVENDA', 5.3000, 'BENAFER', 'DEMAIS ESTADOS', 3.2500, 0.00, 7.4300, 96725.00, 7.7669, 7.0000, 13.4345, 8.0229, 'D', 0.5000, 'LETRA', 0.00, NULL, NULL);
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0aa80-61c7-7a16-8934-63cde8df049c', '01a0aa7f-bdd6-71fe-87c1-3be33cc4a9a8', 3, 10445392340, '9780749371', 'CH1X2X38K', 'CHAPA A/C ASTM A36 1000MM X 2000MM X 3/8" K', 20000, 'KG', 'REVENDA', 5.3000, 'BENAFER', 'DEMAIS ESTADOS', 3.2500, 0.00, 7.4300, 96725.00, 7.7669, 7.0000, 13.4345, 8.0229, 'D', 0.5000, 'LETRA', 0.00, NULL, NULL);
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0aa80-61c7-7a37-b96e-c1f76c9e6551', '01a0aa7f-bdd6-71fe-87c1-3be33cc4a9a8', 4, 10461306585, '9780749371', 'CH1X2X38K', 'CHAPA A/C ASTM A36 1000MM X 2000MM X 3/8" K', 20000, 'KG', 'REVENDA', 5.3000, 'BENAFER', 'DEMAIS ESTADOS', 3.2500, 0.00, 7.4300, 96725.00, 7.7669, 7.0000, 13.4345, 8.0229, 'D', 0.5000, 'LETRA', 0.00, NULL, NULL);
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0af8b-e626-7260-a1dc-fc867d3739e4', '01a0af8b-e5a3-7692-b17e-7f6c2ed2e56b', 1, 10431580116, '10349677802', 'CHDESM2', 'CHAPA CONFORME DESENHO	M2', 4, 'M2', 'REVENDA', 240.0000, 'LAPEFER / MOGIAÇO', 'SÃO PAULO', 3.2500, 0.00, 200.0000, 416.33, 180.8203, 12.0000, 18.2520, 16.2548, 'A', 2.0000, 'LETRA', 0.00, 2, 'PC');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0af8b-e626-7e66-9d08-cb64b24f1bd2', '01a0af8b-e5a3-7692-b17e-7f6c2ed2e56b', 2, 10431579850, '9821640845', 'CH38M2', 'CHAPA A/C ASTM A36 3/8" M2', 4.5, 'M2', 'REVENDA', 2022.0000, 'BENAFER', 'DEMAIS ESTADOS', 3.2500, 0.00, 900.0000, 1875.12, 723.8872, 12.0000, 18.2520, 21.9971, 'A', 2.0000, 'LETRA', 0.00, 1, 'PC');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0b42a-25f6-70e6-8288-0ebb9553c06f', '01a0b42a-2576-7fc8-8e8f-9cf241963dbb', 1, 10436469203, '10436467047', 'BADUS', 'BALANÇA DIGITAL USB COM LED PARA BANHEIRO - 180KG', 1, 'PÇ', 'REVENDA', 46.7400, NULL, 'OPTANTE SIMPLES', 0.0000, 0.00, 77.5000, 47.41, 82.3655, 12.0000, 18.2520, 7.1187, 'D', 0.5000, 'LETRA', 0.00, 1, 'PÇ');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0b5b8-afa7-74a5-85df-2c540ab6c6c9', '01a0b5b8-af23-7ea2-ada1-1e7203a94405', 1, 10426726866, '9764606628', 'CLPN20DE250', 'COLARINHO PEAD PE100 PN20 SDR 9 DE250', 10, 'PC', 'REVENDA', 550.3200, NULL, 'SÃO PAULO', 0.0000, 0.00, 691.7800, 4591.81, 730.1000, 7.0000, 13.4345, 6.7370, 'D', 0.5000, 'LETRA', 0.00, 10, 'PC');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0c442-e59b-7e9c-9473-3bd35ac3fb15', '01a0c442-e515-76a8-ba54-278dadb6fe25', 1, 10392477779, '10321348417', 'CH12X2X05Z', 'CHAPA 2000X1200MM 0,5MM AC ZINCADO', 143, 'PÇ', 'REVENDA', 115.6800, NULL, 'SÃO PAULO', 0.0000, 0.00, 152.0500, 13802.68, 167.6802, 12.0000, 18.2520, 4.8157, 'D', 0.5000, 'LETRA', 0.00, 143, 'PÇ');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0c450-a979-7507-ac82-06d9d7db2ef1', '01a0c450-a8f9-7ef7-ae05-762cced54bfb', 1, 10453324105, '10381581551', 'CHU400250X6X12', 'CHAPA USIAR 400  2500MM X 6000MM X 1/2"', 1496, 'KG', 'REVENDA', 20182.5000, 'PCP STEEL', 'DEMAIS ESTADOS - IMPORTAÇÃO', 3.2500, 0.00, 17.9400, 20330.99, 21.0732, 4.0000, 10.5440, 0.2504, 'D', 0.5000, 'LETRA', 0.00, 1, 'PC');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0c89e-0faa-7cbd-b85d-317c305a64bf', '01a0c89e-0f28-7c24-b5f6-77bd56a65d68', 1, 10431311249, '9764581580', 'P16CF040', 'FLANGE CEGO FF EN1092-1 PN16 AC 4"', 14, 'PC', 'REVENDA', 250.0000, NULL, 'SÃO PAULO', 0.0000, 0.00, 417.4000, 2920.36, 362.3779, 12.0000, 18.2520, 18.3208, 'A', 2.0000, 'LETRA', 0.00, 14, 'PC');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0c89f-e4f1-7515-9c37-2a681f0827bd', '01a0c89f-e471-780d-bbee-1fd5feba9ea2', 1, 10449644444, '9764580649', 'P10LR140', 'FLANGE SOBREPOSTO RF EN1092-1 PN10 AC 14"', 4, 'PÇ', 'REVENDA', 120.0000, NULL, 'SÃO PAULO', 0.0000, 0.00, 327.4700, 400.51, 173.9422, 12.0000, 18.2520, 37.7204, 'A', 2.0000, 'LETRA', 0.00, 4, 'PÇ');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0c89f-e4f2-71ec-98d0-9d70a73871f2', '01a0c89f-e471-780d-bbee-1fd5feba9ea2', 2, 10449644448, '9764582111', 'P25LR100', 'FLANGE SOBREPOSTO RF EN1092-1 PN25 AC 10"', 1, 'PÇ', 'REVENDA', 200.0000, NULL, 'SÃO PAULO', 0.0000, 0.00, 255.4800, 166.88, 289.9104, 12.0000, 18.2520, 2.9769, 'D', 0.5000, 'LETRA', 0.00, 1, 'PÇ');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0c8ad-15b5-7597-80ac-160b832586bb', '01a0c8ad-1535-7eb7-901f-be464c5c6a76', 1, 10464313637, '10463665465', 'TQA50012X95', 'TUBO QUADRADO A/C ASTM A500 120 X 120 X 9,50MM', 401.76, 'KG', 'REVENDA', 5.0000, NULL, 'SÃO PAULO', 0.0000, 0.00, 14.2100, 1676.12, 7.2518, 12.0000, 18.2520, 38.9370, 'A', 2.0000, 'LETRA', 0.00, 401.76, 'KG');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0c8ad-15b6-722e-b679-c7ab3ddf19c5', '01a0c8ad-1535-7eb7-901f-be464c5c6a76', 2, 10464314472, '10463666391', 'TUB40114', 'TUBO S/C API 5L GR.B SCH40 X 1.1/4"', 183.06, 'KG', 'REVENDA', 15.0000, NULL, 'SÃO PAULO', 0.0000, 0.00, 28.0000, 2291.15, 21.7453, 12.0000, 18.2520, 23.5968, 'A', 2.0000, 'LETRA', 0.00, 183.06, 'KG');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0c8ad-a3cc-7689-bdbd-f5d51f7dd0f0', '01a0c8ad-a351-7660-a0ab-34c9226e1190', 1, 10464313637, '10463665465', 'TQA50012X95', 'TUBO QUADRADO A/C ASTM A500 120 X 120 X 9,50MM', 401.76, 'KG', 'REVENDA', 10.0000, NULL, 'SÃO PAULO', 0.0000, 0.00, 14.2100, 3352.24, 14.5036, 12.0000, 18.2520, 9.5778, 'C', 0.7000, 'LETRA', 0.00, 401.76, 'KG');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0c8ad-a3cd-72eb-a911-b4ba76ac790c', '01a0c8ad-a351-7660-a0ab-34c9226e1190', 2, 10464314472, '10463666391', 'TUB40114', 'TUBO S/C API 5L GR.B SCH40 X 1.1/4"', 183.06, 'KG', 'REVENDA', 15.0000, NULL, 'SÃO PAULO', 0.0000, 0.00, 28.0000, 2291.15, 21.7453, 12.0000, 18.2520, 23.5968, 'A', 2.0000, 'LETRA', 0.00, 183.06, 'KG');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0c8ae-ba82-713b-9bbe-f5ad73a69f76', '01a0c8ae-ba08-731f-80d5-484cca4fc0e8', 1, 10467704353, '10170541208', 'CH131361K', 'CHAPA A/C 2440 X 6000 MM A131 AH36 1"', 2919.07, 'KG', 'REVENDA', 7.0000, NULL, 'SÃO PAULO', 0.0000, 0.00, 15.3900, 17049.49, 10.1505, 12.0000, 18.2520, 30.3448, 'A', 2.0000, 'LETRA', 0.00, 2919.07, 'KG');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0c8af-3319-722f-8c07-c36fcdaac84b', '01a0c8af-329c-7c6d-afc9-a2e32be248dc', 1, 10467704353, '10170541208', 'CH131361K', 'CHAPA A/C 2440 X 6000 MM A131 AH36 1"', 2919.07, 'KG', 'REVENDA', 7.5000, NULL, 'SÃO PAULO', 0.0000, 0.00, 15.3900, 18267.32, 10.8777, 12.0000, 18.2520, 27.6340, 'A', 2.0000, 'LETRA', 0.00, 2919.07, 'KG');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0c8b2-482f-73f3-9788-2731212f2a95', '01a0c8b2-47b3-7a12-bc0f-7064fb2af3c3', 1, 10467701884, '10224493962', 'CHAH3612K', 'CHAPA NAVAL A-131 AH36 1/2" X 2440 X 6000 K', 1460.53, 'KG', 'REVENDA', 10.0000, NULL, 'SÃO PAULO', 0.0000, 0.00, 15.3900, 12186.51, 13.4027, 7.0000, 13.4345, 18.8974, 'A', 2.0000, 'LETRA', 0.00, 1460.53, 'KG');
INSERT INTO core_comissionamento.simulacao_itens VALUES ('01a0c8b2-cf5c-7fcd-aece-978588341bdf', '01a0c8b2-cee2-7e6e-a686-fc5b49cc2482', 1, 10467701884, '10224493962', 'CHAH3612K', 'CHAPA NAVAL A-131 AH36 1/2" X 2440 X 6000 K', 1460.53, 'KG', 'REVENDA', 7.0000, NULL, 'SÃO PAULO', 0.0000, 0.00, 15.3900, 8530.56, 9.3829, 7.0000, 13.4345, 35.1623, 'A', 2.0000, 'LETRA', 0.00, 1460.53, 'KG');


--
-- Data for Name: simulacoes; Type: TABLE DATA; Schema: core_comissionamento; Owner: postgres
--

INSERT INTO core_comissionamento.simulacoes VALUES ('01a0c450-a8f9-7ef7-ae05-762cced54bfb', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '27616', NULL, 10453324104, 'VENDEDOR', 1, NULL, 'APROVADO', '9764301790', '9784054067', '2026-09-02', 'Demais estados', '30/60', false, 'RATEIO', 0.00, 0.00, 0.00, 0.00, '01a0a538-d3e3-701b-b144-cc233d15ef17', 20330.99, 31525.51, 26838.24, 26838.24, 1.5506, 1.3300, 28.7920, 11.451734, 67.22, 0.2504, 'D', 0.5000, 134.19, 1, 0, NULL, NULL, '2026-09-21 14:13:35.547+00', NULL, NULL, NULL, '2026-09-21 14:13:35.548+00', '2026-09-21 14:14:13.870227+00', NULL);
INSERT INTO core_comissionamento.simulacoes VALUES ('01a0aa7f-bdd6-71fe-87c1-3be33cc4a9a8', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '24547', NULL, 10388620467, 'VENDEDOR', 1, NULL, 'APROVADO', '9796440719', '9765166723', '2026-06-01', 'Demais estados', '30 DDL', false, 'VALOR', 0.00, 0.00, 0.00, 0.00, '01a0a538-d3e3-701b-b144-cc233d15ef17', 386900.00, 621352.00, 594400.00, 594400.00, 1.6060, 1.5400, 35.7760, 11.451734, 47688.23, 8.0229, 'D', 0.5000, 2972.00, 4, 0, NULL, NULL, '2026-09-16 13:55:36.366+00', NULL, NULL, NULL, '2026-09-16 13:54:53.454+00', '2026-09-16 16:49:50.286357+00', NULL);
INSERT INTO core_comissionamento.simulacoes VALUES ('01a0af8b-e5a3-7692-b17e-7f6c2ed2e56b', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '26262', NULL, 10431579613, 'VENDEDOR', 1, NULL, 'APROVADO', '9796457160', '9811520139', '2026-07-21', 'Minas Gerais', '30 DDL', false, 'RATEIO', 0.00, 0.00, 0.00, 0.00, '01a0a538-d3e3-701b-b144-cc233d15ef17', 2291.45, 3980.77, 4850.00, 4850.00, 1.7372, 2.1200, 87.7433, 11.451734, 1020.92, 21.0499, 'A', 2.0000, 97.00, 2, 0, NULL, NULL, '2026-09-17 13:26:16.153+00', NULL, NULL, NULL, '2026-09-17 13:26:16.158+00', '2026-09-17 13:27:11.954869+00', NULL);
INSERT INTO core_comissionamento.simulacoes VALUES ('01a0b42a-2576-7fc8-8e8f-9cf241963dbb', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '26559', NULL, 10436463845, 'VENDEDOR', 1, NULL, 'APROVADO', '9764301580', '10127378620', '2026-07-30', 'Rio de Janeiro', '30 DDL', false, 'RATEIO', 0.00, 0.00, 0.00, 0.00, '01a0a538-d3e3-701b-b144-cc233d15ef17', 47.41, 82.37, 77.50, 77.50, 1.7372, 1.6400, 65.8109, 11.451734, 5.52, 7.1187, 'D', 0.5000, 0.39, 1, 0, NULL, NULL, '2026-09-18 10:57:36.056+00', NULL, NULL, NULL, '2026-09-18 10:57:36.058+00', '2026-09-18 10:58:44.086929+00', NULL);
INSERT INTO core_comissionamento.simulacoes VALUES ('01a0b5b8-af23-7ea2-ada1-1e7203a94405', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '25887', NULL, 10426722776, 'VENDEDOR', 1, NULL, 'APROVADO', '9764301790', '9765168460', '2026-07-08', 'Demais estados', 'À Vista', false, 'RATEIO', 0.00, 0.00, 0.00, 0.00, '01a0a538-d3e3-701b-b144-cc233d15ef17', 4591.81, 7301.00, 6917.80, 6917.80, 1.5900, 1.5100, 25.7050, 11.451734, 466.05, 6.7370, 'D', 0.5000, 34.59, 1, 0, NULL, NULL, '2026-09-18 18:12:54.628+00', NULL, NULL, NULL, '2026-09-18 18:12:54.629+00', '2026-09-18 18:15:11.803159+00', NULL);
INSERT INTO core_comissionamento.simulacoes VALUES ('01a0c442-e515-76a8-ba54-278dadb6fe25', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '24681', NULL, 10392475158, 'VENDEDOR', 1, NULL, 'APROVADO', '9796457160', '10431128445', '2026-06-05', 'Minas Gerais', '30 DDL', false, 'RATEIO', 0.00, 0.00, 0.00, 0.00, '01a0a538-d3e3-701b-b144-cc233d15ef17', 13802.68, 23978.27, 21743.15, 21743.15, 1.7372, 1.5800, 31.4402, 11.451734, 1047.08, 4.8157, 'D', 0.5000, 108.72, 1, 0, NULL, NULL, '2026-09-21 13:58:33.419+00', NULL, NULL, NULL, '2026-09-21 13:58:33.423+00', '2026-09-21 13:59:31.036669+00', NULL);
INSERT INTO core_comissionamento.simulacoes VALUES ('01a0c89e-0f28-7c24-b5f6-77bd56a65d68', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '26242', NULL, 10431311248, 'VENDEDOR', 1, NULL, 'APROVADO', '10168821999', '10309519209', '2026-07-20', 'Minas Gerais', '30 DDL', false, 'RATEIO', 0.00, 0.00, 0.00, 0.00, '01a0a538-d3e3-701b-b144-cc233d15ef17', 2920.36, 5073.29, 5843.60, 5843.60, 1.7372, 2.0100, 66.9600, 11.451734, 1070.60, 18.3208, 'A', 2.0000, 116.87, 1, 0, NULL, NULL, '2026-09-22 10:16:36.842+00', NULL, NULL, NULL, '2026-09-22 10:16:36.843+00', '2026-09-22 10:17:07.293734+00', NULL);
INSERT INTO core_comissionamento.simulacoes VALUES ('01a0c89f-e471-780d-bbee-1fd5feba9ea2', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '27290', NULL, 10449644441, 'VENDEDOR', 1, NULL, 'APROVADO', '10168821999', '10309519209', '2026-08-24', 'Paraná', '30 DDL', false, 'RATEIO', 0.00, 0.00, 0.00, 0.00, '01a0a538-d3e3-701b-b144-cc233d15ef17', 567.39, 985.68, 1565.36, 1565.36, 1.7372, 2.7600, 130.2000, 11.451734, 501.70, 32.0500, 'A', 1.7552, 27.48, 2, 0, NULL, NULL, '2026-09-22 10:18:36.978+00', NULL, NULL, NULL, '2026-09-22 10:18:36.981+00', '2026-09-22 10:18:57.477216+00', NULL);
INSERT INTO core_comissionamento.simulacoes VALUES ('01a0c8ad-1535-7eb7-901f-be464c5c6a76', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '27917', NULL, 10463583937, 'VENDEDOR', 1, NULL, 'CONTESTADO', '10360266886', '9821667784', '2026-09-11', 'Paraná', '30 DDL', false, 'RATEIO', 0.00, 0.00, 0.00, 0.00, '01a0a538-d3e3-701b-b144-cc233d15ef17', 3967.27, 6894.18, 10834.69, 10834.69, 1.7378, 2.7400, 127.8733, 11.451734, 3432.42, 31.6799, 'A', 2.0000, 216.69, 2, 0, NULL, NULL, '2026-09-22 10:33:01.429+00', NULL, NULL, NULL, '2026-09-22 10:33:01.432+00', '2026-09-22 10:33:37.383332+00', NULL);
INSERT INTO core_comissionamento.simulacoes VALUES ('01a0c8ad-a351-7660-a0ab-34c9226e1190', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '27917', NULL, 10463583937, 'COMPRAS', 1, '01a0c8ad-1535-7eb7-901f-be464c5c6a76', 'APROVADO', '10360266886', '9821667784', '2026-09-11', 'Paraná', '30 DDL', false, 'RATEIO', 0.00, 0.00, 0.00, 0.00, '01a0a538-d3e3-701b-b144-cc233d15ef17', 5643.40, 9807.66, 10834.69, 10834.69, 1.7379, 1.9200, 60.1935, 11.451734, 1756.29, 16.2099, 'A', 1.3150, 142.48, 2, 0, NULL, NULL, '2026-09-22 10:33:37.808+00', NULL, NULL, NULL, '2026-09-22 10:33:37.812+00', '2026-09-22 10:33:38.591924+00', NULL);
INSERT INTO core_comissionamento.simulacoes VALUES ('01a0c8ae-ba08-731f-80d5-484cca4fc0e8', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '28195', NULL, 10467704181, 'VENDEDOR', 1, NULL, 'CONTESTADO', '10360266886', '9821667784', '2026-09-21', 'Minas Gerais', '30 DDL', false, 'RATEIO', 0.00, 0.00, 0.00, 0.00, '01a0a538-d3e3-701b-b144-cc233d15ef17', 17049.49, 29630.02, 44924.49, 44924.49, 1.7379, 2.6400, 119.8571, 11.451734, 13632.25, 30.3448, 'A', 2.0000, 898.49, 1, 0, NULL, NULL, '2026-09-22 10:34:49.165+00', NULL, NULL, NULL, '2026-09-22 10:34:49.165+00', '2026-09-22 10:35:19.618237+00', NULL);
INSERT INTO core_comissionamento.simulacoes VALUES ('01a0c8af-329c-7c6d-afc9-a2e32be248dc', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '28195', NULL, 10467704181, 'COMPRAS', 1, '01a0c8ae-ba08-731f-80d5-484cca4fc0e8', 'APROVADO', '10360266886', '9821667784', '2026-09-21', 'Minas Gerais', '30 DDL', false, 'RATEIO', 0.00, 0.00, 0.00, 0.00, '01a0a538-d3e3-701b-b144-cc233d15ef17', 18267.32, 31752.77, 44924.49, 44924.49, 1.7382, 2.4600, 105.2000, 11.451734, 12414.43, 27.6340, 'A', 2.0000, 898.49, 1, 0, NULL, NULL, '2026-09-22 10:35:20.034+00', NULL, NULL, NULL, '2026-09-22 10:35:20.034+00', '2026-09-22 10:35:21.112761+00', NULL);
INSERT INTO core_comissionamento.simulacoes VALUES ('01a0c8b2-47b3-7a12-bc0f-7064fb2af3c3', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '28194', NULL, 10467700746, 'VENDEDOR', 1, NULL, 'CONTESTADO', '10360266886', '9821667784', '2026-09-21', 'Demais estados', '30 DDL', false, 'RATEIO', 0.00, 0.00, 0.00, 0.00, '01a0a538-d3e3-701b-b144-cc233d15ef17', 12186.51, 19575.05, 22477.56, 22477.56, 1.6063, 1.8500, 53.9000, 11.451734, 4247.68, 18.8974, 'A', 2.0000, 449.55, 1, 0, NULL, NULL, '2026-09-22 10:38:42.038+00', NULL, NULL, NULL, '2026-09-22 10:38:42.039+00', '2026-09-22 10:39:16.227973+00', NULL);
INSERT INTO core_comissionamento.simulacoes VALUES ('01a0c8b2-cee2-7e6e-a686-fc5b49cc2482', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '28194', NULL, 10467700746, 'COMPRAS', 1, '01a0c8b2-47b3-7a12-bc0f-7064fb2af3c3', 'APROVADO', '10360266886', '9821667784', '2026-09-21', 'Demais estados', '30 DDL', false, 'RATEIO', 0.00, 0.00, 0.00, 0.00, '01a0a538-d3e3-701b-b144-cc233d15ef17', 8530.56, 13704.01, 22477.56, 22477.56, 1.6065, 2.6400, 119.8571, 11.451734, 7903.63, 35.1623, 'A', 2.0000, 449.55, 1, 0, NULL, NULL, '2026-09-22 10:39:16.646+00', NULL, NULL, NULL, '2026-09-22 10:39:16.647+00', '2026-09-22 10:39:17.361029+00', NULL);


--
-- Data for Name: simulador_parametros; Type: TABLE DATA; Schema: core_comissionamento; Owner: postgres
--

INSERT INTO core_comissionamento.simulador_parametros VALUES ('01a0a538-d3e3-701b-b144-cc233d15ef17', '759979bd-2b2d-41f2-b1b7-db6fae89ee59', '2023-05-01', NULL, 'Maio/23', 10.0000, 11.451734, '{"SEDES": 0.563934, "PESSOAL": 2.008707, "PRODUCAO": 0.146141, "LOGISTICA": 1.438975, "MARKETING": 0.052283, "TERCEIROS": 0.407125, "FINANCEIRAS": 6.350653, "CONTRIBUICOES": 0.016346, "ADMINISTRATIVAS": 0.467569}', 1.438975, 2.0000, 0.6500, 3.0000, 8.0000, 15.0000, 12.0000, 9.0000, 0.7600, '{"Paraná": 12, "São Paulo": 18, "Importação": 4, "Minas Gerais": 12, "Demais estados": 7, "Rio de Janeiro": 12, "Santa Catarina": 12, "Rio Grande do Sul": 12}', '{"SÃO PAULO": 18, "DEMAIS ESTADOS": 12, "OPTANTE SIMPLES": 0, "SÃO PAULO - IMPORTAÇÃO": 18, "DEMAIS ESTADOS - IMPORTAÇÃO": 4, "SÃO PAULO - Base de ICMS Reduzida": 13.3}', '{"0/21": 1, "0/30": 1, "28/35": 1, "28/42": 1.5, "28/45": 1.5, "30/45": 1.5, "30/60": 2, "34/40": 1.5, "30 DDL": 1, "1/30/45": 1.5, "28/35/42": 1.5, "28/42/56": 2, "30/45/60": 2, "30/60/90": 3, "À Vista": 0, "28/35/42/56": 2, "30/45/60/75": 2.5, "30/60/90/120": 4, "30/45/60/75/90": 3}', '[{"pct": 2, "letra": "A", "margem_min": 15}, {"pct": 1.3, "letra": "B", "margem_min": 12}, {"pct": 0.7, "letra": "C", "margem_min": 9}, {"pct": 0.5, "letra": "D", "margem_min": 0}]', 2.0000, NULL, NULL, NULL, '2026-09-15 13:19:19.958+00', '2026-09-15 13:19:19.958+00', NULL);
INSERT INTO core_comissionamento.simulador_parametros VALUES ('01a0a538-d545-7830-b2c8-1b0a0b584d21', 'c84155b6-75cc-4bca-8435-281e846f4039', '2023-05-01', NULL, 'Maio/23', 10.0000, 11.451734, '{"SEDES": 0.563934, "PESSOAL": 2.008707, "PRODUCAO": 0.146141, "LOGISTICA": 1.438975, "MARKETING": 0.052283, "TERCEIROS": 0.407125, "FINANCEIRAS": 6.350653, "CONTRIBUICOES": 0.016346, "ADMINISTRATIVAS": 0.467569}', 1.438975, 2.0000, 0.6500, 3.0000, 8.0000, 15.0000, 12.0000, 9.0000, 0.7600, '{"Paraná": 12, "São Paulo": 18, "Importação": 4, "Minas Gerais": 12, "Demais estados": 7, "Rio de Janeiro": 12, "Santa Catarina": 12, "Rio Grande do Sul": 12}', '{"SÃO PAULO": 18, "DEMAIS ESTADOS": 12, "OPTANTE SIMPLES": 0, "SÃO PAULO - IMPORTAÇÃO": 18, "DEMAIS ESTADOS - IMPORTAÇÃO": 4, "SÃO PAULO - Base de ICMS Reduzida": 13.3}', '{"0/21": 1, "0/30": 1, "28/35": 1, "28/42": 1.5, "28/45": 1.5, "30/45": 1.5, "30/60": 2, "34/40": 1.5, "30 DDL": 1, "1/30/45": 1.5, "28/35/42": 1.5, "28/42/56": 2, "30/45/60": 2, "30/60/90": 3, "À Vista": 0, "28/35/42/56": 2, "30/45/60/75": 2.5, "30/60/90/120": 4, "30/45/60/75/90": 3}', '[{"pct": 2, "letra": "A", "margem_min": 15}, {"pct": 1.3, "letra": "B", "margem_min": 12}, {"pct": 0.7, "letra": "C", "margem_min": 9}, {"pct": 0.5, "letra": "D", "margem_min": 0}]', 2.0000, NULL, NULL, NULL, '2026-09-15 13:19:20.315+00', '2026-09-15 13:19:20.315+00', NULL);
INSERT INTO core_comissionamento.simulador_parametros VALUES ('01a0a538-d665-7682-b5de-3b26525f675e', '4ec9f957-73bb-43a1-8ebe-39fcdd191425', '2023-05-01', NULL, 'Maio/23', 10.0000, 11.451734, '{"SEDES": 0.563934, "PESSOAL": 2.008707, "PRODUCAO": 0.146141, "LOGISTICA": 1.438975, "MARKETING": 0.052283, "TERCEIROS": 0.407125, "FINANCEIRAS": 6.350653, "CONTRIBUICOES": 0.016346, "ADMINISTRATIVAS": 0.467569}', 1.438975, 2.0000, 0.6500, 3.0000, 8.0000, 15.0000, 12.0000, 9.0000, 0.7600, '{"Paraná": 12, "São Paulo": 18, "Importação": 4, "Minas Gerais": 12, "Demais estados": 7, "Rio de Janeiro": 12, "Santa Catarina": 12, "Rio Grande do Sul": 12}', '{"SÃO PAULO": 18, "DEMAIS ESTADOS": 12, "OPTANTE SIMPLES": 0, "SÃO PAULO - IMPORTAÇÃO": 18, "DEMAIS ESTADOS - IMPORTAÇÃO": 4, "SÃO PAULO - Base de ICMS Reduzida": 13.3}', '{"0/21": 1, "0/30": 1, "28/35": 1, "28/42": 1.5, "28/45": 1.5, "30/45": 1.5, "30/60": 2, "34/40": 1.5, "30 DDL": 1, "1/30/45": 1.5, "28/35/42": 1.5, "28/42/56": 2, "30/45/60": 2, "30/60/90": 3, "À Vista": 0, "28/35/42/56": 2, "30/45/60/75": 2.5, "30/60/90/120": 4, "30/45/60/75/90": 3}', '[{"pct": 2, "letra": "A", "margem_min": 15}, {"pct": 1.3, "letra": "B", "margem_min": 12}, {"pct": 0.7, "letra": "C", "margem_min": 9}, {"pct": 0.5, "letra": "D", "margem_min": 0}]', 2.0000, NULL, NULL, NULL, '2026-09-15 13:19:20.616+00', '2026-09-15 13:19:20.616+00', NULL);


--
-- Name: comissao_coordenadores_historico_id_seq; Type: SEQUENCE SET; Schema: core_comissionamento; Owner: postgres
--

SELECT pg_catalog.setval('core_comissionamento.comissao_coordenadores_historico_id_seq', 6, true);


--
-- Name: comissao_coordenadores_historico comissao_coordenadores_historico_pkey; Type: CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.comissao_coordenadores_historico
    ADD CONSTRAINT comissao_coordenadores_historico_pkey PRIMARY KEY (id);


--
-- Name: comissao_coordenadores comissao_coordenadores_pkey; Type: CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.comissao_coordenadores
    ADD CONSTRAINT comissao_coordenadores_pkey PRIMARY KEY (id);


--
-- Name: comissao_coordenadores ex_comissao_coord_vigencia; Type: CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.comissao_coordenadores
    ADD CONSTRAINT ex_comissao_coord_vigencia EXCLUDE USING gist (lower(btrim((nome)::text)) WITH =, daterange(vigencia_inicio, vigencia_fim, '[]'::text) WITH &&) WHERE ((deleted_at IS NULL));


--
-- Name: simulador_parametros ex_simulador_parametros_sem_sobreposicao; Type: CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.simulador_parametros
    ADD CONSTRAINT ex_simulador_parametros_sem_sobreposicao EXCLUDE USING gist (codigo_empresa WITH =, daterange(vigencia_inicio, vigencia_fim, '[]'::text) WITH &&) WHERE ((deleted_at IS NULL));


--
-- Name: blacklist_comissoes_destinatario pk_blacklist_comissoes_destinatario; Type: CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.blacklist_comissoes_destinatario
    ADD CONSTRAINT pk_blacklist_comissoes_destinatario PRIMARY KEY (codigo_empresa, codigo_cliente);


--
-- Name: blacklist_comissoes_vendedores pk_blacklist_comissoes_vendedores; Type: CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.blacklist_comissoes_vendedores
    ADD CONSTRAINT pk_blacklist_comissoes_vendedores PRIMARY KEY (codigo_empresa, codigo_vendedor_omie);


--
-- Name: bloqueio_comissoes pk_bloqueio_comissoes; Type: CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.bloqueio_comissoes
    ADD CONSTRAINT pk_bloqueio_comissoes PRIMARY KEY (codigo_empresa, numero_nf);


--
-- Name: regras_comissoes_fixas pk_regras_comissoes_fixas; Type: CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.regras_comissoes_fixas
    ADD CONSTRAINT pk_regras_comissoes_fixas PRIMARY KEY (id);


--
-- Name: simulacao_itens simulacao_itens_pkey; Type: CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.simulacao_itens
    ADD CONSTRAINT simulacao_itens_pkey PRIMARY KEY (id);


--
-- Name: simulacoes simulacoes_pkey; Type: CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.simulacoes
    ADD CONSTRAINT simulacoes_pkey PRIMARY KEY (id);


--
-- Name: simulador_parametros simulador_parametros_pkey; Type: CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.simulador_parametros
    ADD CONSTRAINT simulador_parametros_pkey PRIMARY KEY (id);


--
-- Name: idx_comissao_coord_hist; Type: INDEX; Schema: core_comissionamento; Owner: postgres
--

CREATE INDEX idx_comissao_coord_hist ON core_comissionamento.comissao_coordenadores_historico USING btree (id_coordenador, feito_em);


--
-- Name: idx_comissao_coord_vigencia; Type: INDEX; Schema: core_comissionamento; Owner: postgres
--

CREATE INDEX idx_comissao_coord_vigencia ON core_comissionamento.comissao_coordenadores USING btree (vigencia_inicio, vigencia_fim) WHERE (deleted_at IS NULL);


--
-- Name: ix_bloqueio_comissoes_bloqueados; Type: INDEX; Schema: core_comissionamento; Owner: postgres
--

CREATE INDEX ix_bloqueio_comissoes_bloqueados ON core_comissionamento.bloqueio_comissoes USING btree (codigo_empresa, numero_nf) WHERE is_blocked;


--
-- Name: ix_simulacao_itens_omie; Type: INDEX; Schema: core_comissionamento; Owner: postgres
--

CREATE INDEX ix_simulacao_itens_omie ON core_comissionamento.simulacao_itens USING btree (id_simulacao, codigo_item_omie);


--
-- Name: ix_simulacoes_fila; Type: INDEX; Schema: core_comissionamento; Owner: postgres
--

CREATE INDEX ix_simulacoes_fila ON core_comissionamento.simulacoes USING btree (codigo_empresa, status, submitted_at) WHERE (deleted_at IS NULL);


--
-- Name: ix_simulacoes_pedido; Type: INDEX; Schema: core_comissionamento; Owner: postgres
--

CREATE INDEX ix_simulacoes_pedido ON core_comissionamento.simulacoes USING btree (codigo_empresa, numero_pedido, sequencial) WHERE (deleted_at IS NULL);


--
-- Name: ix_simulacoes_vendedor; Type: INDEX; Schema: core_comissionamento; Owner: postgres
--

CREATE INDEX ix_simulacoes_vendedor ON core_comissionamento.simulacoes USING btree (codigo_empresa, codigo_vendedor_omie, data_pedido) WHERE (deleted_at IS NULL);


--
-- Name: ix_simulador_parametros_empresa_vigencia; Type: INDEX; Schema: core_comissionamento; Owner: postgres
--

CREATE INDEX ix_simulador_parametros_empresa_vigencia ON core_comissionamento.simulador_parametros USING btree (codigo_empresa, vigencia_inicio DESC) WHERE (deleted_at IS NULL);


--
-- Name: uq_regras_comissoes_fixas_cliente_codigo; Type: INDEX; Schema: core_comissionamento; Owner: postgres
--

CREATE UNIQUE INDEX uq_regras_comissoes_fixas_cliente_codigo ON core_comissionamento.regras_comissoes_fixas USING btree (codigo_empresa, codigo_cliente) WHERE (deleted_at IS NULL);


--
-- Name: uq_simulacao_itens_codigo_item; Type: INDEX; Schema: core_comissionamento; Owner: postgres
--

CREATE UNIQUE INDEX uq_simulacao_itens_codigo_item ON core_comissionamento.simulacao_itens USING btree (id_simulacao, codigo_item_omie) WHERE (codigo_item_omie IS NOT NULL);


--
-- Name: uq_simulacao_itens_ordem; Type: INDEX; Schema: core_comissionamento; Owner: postgres
--

CREATE UNIQUE INDEX uq_simulacao_itens_ordem ON core_comissionamento.simulacao_itens USING btree (id_simulacao, ordem);


--
-- Name: uq_simulacoes_rascunho; Type: INDEX; Schema: core_comissionamento; Owner: postgres
--

CREATE UNIQUE INDEX uq_simulacoes_rascunho ON core_comissionamento.simulacoes USING btree (codigo_empresa, numero_pedido, COALESCE(sequencial, ('-1'::integer)::numeric), origem) WHERE ((deleted_at IS NULL) AND ((status)::text = 'RASCUNHO'::text));


--
-- Name: uq_simulacoes_versao; Type: INDEX; Schema: core_comissionamento; Owner: postgres
--

CREATE UNIQUE INDEX uq_simulacoes_versao ON core_comissionamento.simulacoes USING btree (codigo_empresa, numero_pedido, COALESCE(sequencial, ('-1'::integer)::numeric), origem, versao) WHERE (deleted_at IS NULL);


--
-- Name: uq_simulador_parametros_vigente; Type: INDEX; Schema: core_comissionamento; Owner: postgres
--

CREATE UNIQUE INDEX uq_simulador_parametros_vigente ON core_comissionamento.simulador_parametros USING btree (codigo_empresa) WHERE ((deleted_at IS NULL) AND (vigencia_fim IS NULL));


--
-- Name: blacklist_comissoes_destinatario trg_blacklist_comissoes_destinatario_updated_at; Type: TRIGGER; Schema: core_comissionamento; Owner: postgres
--

CREATE TRIGGER trg_blacklist_comissoes_destinatario_updated_at BEFORE UPDATE ON core_comissionamento.blacklist_comissoes_destinatario FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: blacklist_comissoes_vendedores trg_blacklist_comissoes_vendedores_updated_at; Type: TRIGGER; Schema: core_comissionamento; Owner: postgres
--

CREATE TRIGGER trg_blacklist_comissoes_vendedores_updated_at BEFORE UPDATE ON core_comissionamento.blacklist_comissoes_vendedores FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: bloqueio_comissoes trg_bloqueio_comissoes_updated_at; Type: TRIGGER; Schema: core_comissionamento; Owner: postgres
--

CREATE TRIGGER trg_bloqueio_comissoes_updated_at BEFORE UPDATE ON core_comissionamento.bloqueio_comissoes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: comissao_coordenadores trg_comissao_coordenadores_historico; Type: TRIGGER; Schema: core_comissionamento; Owner: postgres
--

CREATE TRIGGER trg_comissao_coordenadores_historico AFTER INSERT OR DELETE OR UPDATE ON core_comissionamento.comissao_coordenadores FOR EACH ROW EXECUTE FUNCTION core_comissionamento.fn_comissao_coordenadores_historico();


--
-- Name: comissao_coordenadores_historico trg_comissao_coordenadores_historico_imutavel; Type: TRIGGER; Schema: core_comissionamento; Owner: postgres
--

CREATE TRIGGER trg_comissao_coordenadores_historico_imutavel BEFORE DELETE OR UPDATE ON core_comissionamento.comissao_coordenadores_historico FOR EACH ROW EXECUTE FUNCTION core_comissionamento.fn_comissao_coordenadores_historico_imutavel();


--
-- Name: comissao_coordenadores trg_comissao_coordenadores_updated_at; Type: TRIGGER; Schema: core_comissionamento; Owner: postgres
--

CREATE TRIGGER trg_comissao_coordenadores_updated_at BEFORE UPDATE ON core_comissionamento.comissao_coordenadores FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: regras_comissoes_fixas trg_regras_comissoes_fixas_updated_at; Type: TRIGGER; Schema: core_comissionamento; Owner: postgres
--

CREATE TRIGGER trg_regras_comissoes_fixas_updated_at BEFORE UPDATE ON core_comissionamento.regras_comissoes_fixas FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: simulacoes trg_simulacoes_updated_at; Type: TRIGGER; Schema: core_comissionamento; Owner: postgres
--

CREATE TRIGGER trg_simulacoes_updated_at BEFORE UPDATE ON core_comissionamento.simulacoes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: simulador_parametros trg_simulador_parametros_updated_at; Type: TRIGGER; Schema: core_comissionamento; Owner: postgres
--

CREATE TRIGGER trg_simulador_parametros_updated_at BEFORE UPDATE ON core_comissionamento.simulador_parametros FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: comissao_coordenadores comissao_coordenadores_id_funcionario_fkey; Type: FK CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.comissao_coordenadores
    ADD CONSTRAINT comissao_coordenadores_id_funcionario_fkey FOREIGN KEY (id_funcionario) REFERENCES core.funcionarios(id);


--
-- Name: blacklist_comissoes_destinatario fk_blacklist_comissoes_destinatario_codigo_empresa; Type: FK CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.blacklist_comissoes_destinatario
    ADD CONSTRAINT fk_blacklist_comissoes_destinatario_codigo_empresa FOREIGN KEY (codigo_empresa) REFERENCES core.unidades(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: blacklist_comissoes_vendedores fk_blacklist_comissoes_vendedores_codigo_empresa; Type: FK CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.blacklist_comissoes_vendedores
    ADD CONSTRAINT fk_blacklist_comissoes_vendedores_codigo_empresa FOREIGN KEY (codigo_empresa) REFERENCES core.unidades(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: bloqueio_comissoes fk_bloqueio_comissoes_codigo_empresa; Type: FK CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.bloqueio_comissoes
    ADD CONSTRAINT fk_bloqueio_comissoes_codigo_empresa FOREIGN KEY (codigo_empresa) REFERENCES core.unidades(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: regras_comissoes_fixas fk_regras_comissoes_fixas_codigo_empresa; Type: FK CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.regras_comissoes_fixas
    ADD CONSTRAINT fk_regras_comissoes_fixas_codigo_empresa FOREIGN KEY (codigo_empresa) REFERENCES core.unidades(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: simulacao_itens simulacao_itens_id_simulacao_fkey; Type: FK CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.simulacao_itens
    ADD CONSTRAINT simulacao_itens_id_simulacao_fkey FOREIGN KEY (id_simulacao) REFERENCES core_comissionamento.simulacoes(id) ON DELETE CASCADE;


--
-- Name: simulacoes simulacoes_codigo_empresa_fkey; Type: FK CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.simulacoes
    ADD CONSTRAINT simulacoes_codigo_empresa_fkey FOREIGN KEY (codigo_empresa) REFERENCES core.unidades(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: simulacoes simulacoes_id_parametros_fkey; Type: FK CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.simulacoes
    ADD CONSTRAINT simulacoes_id_parametros_fkey FOREIGN KEY (id_parametros) REFERENCES core_comissionamento.simulador_parametros(id);


--
-- Name: simulacoes simulacoes_id_simulacao_contestada_fkey; Type: FK CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.simulacoes
    ADD CONSTRAINT simulacoes_id_simulacao_contestada_fkey FOREIGN KEY (id_simulacao_contestada) REFERENCES core_comissionamento.simulacoes(id);


--
-- Name: simulador_parametros simulador_parametros_codigo_empresa_fkey; Type: FK CONSTRAINT; Schema: core_comissionamento; Owner: postgres
--

ALTER TABLE ONLY core_comissionamento.simulador_parametros
    ADD CONSTRAINT simulador_parametros_codigo_empresa_fkey FOREIGN KEY (codigo_empresa) REFERENCES core.unidades(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict rJqpbYwJ8v8Tx0XT38lqGIy2BdG7hEw0Pa4TyXfex1MgEv0J6vqItWXM8CX7Ceo

