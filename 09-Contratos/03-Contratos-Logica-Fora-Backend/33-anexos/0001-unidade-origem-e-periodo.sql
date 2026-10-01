-- Contrato 33: unidade de origem do vendedor + periodo de atividade nos dashboards.
-- Gerado a partir das funcoes do banco de teste (30/09/2026). Rodar numa transacao.
BEGIN;

-- 1) Colunas do periodo (ver apendice B do contrato)
ALTER TABLE core_vendas_faturamento.vendedores
  ADD COLUMN IF NOT EXISTS ativo_desde   date,
  ADD COLUMN IF NOT EXISTS inativo_desde date;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_vendedores_periodo') THEN
    ALTER TABLE core_vendas_faturamento.vendedores ADD CONSTRAINT ck_vendedores_periodo
      CHECK (ativo_desde IS NULL OR inativo_desde IS NULL OR inativo_desde >= ativo_desde);
  END IF;
END $$;

-- 2) View: unidade de origem de cada vendedor (por Omie)
CREATE OR REPLACE VIEW core_vendas_faturamento.vw_vendedor_unidade AS
SELECT
  v.codigo_empresa,
  v.codigo_vendedor_omie,
  v.id_funcionario,
  COALESCE(f.codigo_empresa, v.codigo_empresa) AS unidade_origem,
  CASE WHEN f.codigo_empresa IS NOT NULL THEN 'funcionario' ELSE 'cadastro_omie' END AS origem_da_unidade,
  v.ativo_desde,
  v.inativo_desde
FROM core_vendas_faturamento.vendedores v
LEFT JOIN core.funcionarios f ON f.id = v.id_funcionario
WHERE v.deleted_at IS NULL;

-- 3) Unidade de origem de um (Omie, codigo de vendedor). Se o vendedor nao esta
--    cadastrado, vale o proprio Omie da venda: a venda nunca some do total.
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_unidade_do_vendedor(p_codigo_empresa uuid, p_cod_vendedor text)
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT COALESCE(
    (SELECT vu.unidade_origem FROM core_vendas_faturamento.vw_vendedor_unidade vu
      WHERE vu.codigo_empresa = p_codigo_empresa
        AND vu.codigo_vendedor_omie::text = p_cod_vendedor),
    p_codigo_empresa);
$$;

-- 4) O vendedor valia no periodo [p_ini, p_fim]? Sem cadastro ou sem datas: sim.
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_vendedor_no_periodo(p_codigo_empresa uuid, p_cod_vendedor text, p_ini date, p_fim date)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT COALESCE(
    (SELECT (vd.ativo_desde IS NULL OR vd.ativo_desde <= p_fim)
        AND (vd.inativo_desde IS NULL OR vd.inativo_desde > p_ini)
       FROM core_vendas_faturamento.vendedores vd
      WHERE vd.codigo_empresa = p_codigo_empresa
        AND vd.codigo_vendedor_omie::text = p_cod_vendedor
        AND vd.deleted_at IS NULL),
    true);
$$;

-- 5) Funcoes dos dashboards: o filtro de empresa passa a ser a unidade de origem do vendedor.

-- fn_dashboard_mensal_faturamento: 2 ponto(s) alterado(s)
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_dashboard_mensal_faturamento(p_mes smallint, p_ano smallint, p_is_track_record boolean DEFAULT false, p_codigo_empresa uuid DEFAULT NULL::uuid)
 RETURNS TABLE(mes smallint, ano smallint, faturamento_total numeric, qtd_nfs bigint, fat_mes_anterior numeric, qtd_nfs_mes_anterior bigint, fat_mes_antepassado numeric, qtd_nfs_mes_antepassado bigint, meta numeric, perc_atingimento numeric, fat_hoje numeric, fat_ontem numeric, pedidos_hoje bigint, pedidos_ontem bigint)
 LANGUAGE sql
 STABLE
AS $function$
    WITH alvo AS (
        SELECT make_date(p_ano::integer, p_mes::integer, 1) AS ref_date
    ), fat_mensal AS (
        SELECT EXTRACT(month FROM data_emissao)::smallint AS mes,
            EXTRACT(year FROM data_emissao)::smallint AS ano,
            sum(valor_nf) AS faturamento_total,
            count(DISTINCT numero_nf) AS qtd_nfs
        FROM core_vendas_faturamento.vw_nf_classified, alvo
        WHERE grupo_deducao = 'LIQUIDO'
          AND is_track_record = p_is_track_record
      AND (p_codigo_empresa IS NULL OR core_vendas_faturamento.fn_unidade_do_vendedor(codigo_empresa, cod_vendedor) = p_codigo_empresa)
          AND data_emissao >= (alvo.ref_date - INTERVAL '2 months')
          AND data_emissao <  (alvo.ref_date + INTERVAL '1 month')
        GROUP BY 1, 2
    ), fat_diario AS (
        SELECT
            sum(valor_nf) FILTER (WHERE data_emissao = CURRENT_DATE) AS fat_hoje,
            sum(valor_nf) FILTER (WHERE data_emissao = CURRENT_DATE - 1) AS fat_ontem,
            count(DISTINCT numero_nf) FILTER (WHERE data_emissao = CURRENT_DATE) AS pedidos_hoje,
            count(DISTINCT numero_nf) FILTER (WHERE data_emissao = CURRENT_DATE - 1) AS pedidos_ontem
        FROM core_vendas_faturamento.vw_nf_classified
        WHERE grupo_deducao = 'LIQUIDO'
          AND is_track_record = p_is_track_record
      AND (p_codigo_empresa IS NULL OR core_vendas_faturamento.fn_unidade_do_vendedor(codigo_empresa, cod_vendedor) = p_codigo_empresa)
          AND data_emissao = ANY (ARRAY[CURRENT_DATE, CURRENT_DATE - 1])
    )
    SELECT p_mes, p_ano,
        COALESCE(fm.faturamento_total, 0), COALESCE(fm.qtd_nfs, 0),
        COALESCE(fm_ant.faturamento_total, 0), COALESCE(fm_ant.qtd_nfs, 0),
        COALESCE(fm_ant2.faturamento_total, 0), COALESCE(fm_ant2.qtd_nfs, 0),
        COALESCE(mt.meta, 0),
        CASE WHEN COALESCE(mt.meta, 0) = 0 THEN NULL ELSE round(COALESCE(fm.faturamento_total, 0) / mt.meta * 100, 2) END,
        COALESCE(fd.fat_hoje, 0), COALESCE(fd.fat_ontem, 0),
        COALESCE(fd.pedidos_hoje, 0), COALESCE(fd.pedidos_ontem, 0)
    FROM alvo a
    LEFT JOIN fat_mensal fm ON fm.mes = p_mes AND fm.ano = p_ano
    LEFT JOIN fat_mensal fm_ant ON fm_ant.mes = EXTRACT(month FROM a.ref_date - INTERVAL '1 month')::smallint AND fm_ant.ano = EXTRACT(year FROM a.ref_date - INTERVAL '1 month')::smallint
    LEFT JOIN fat_mensal fm_ant2 ON fm_ant2.mes = EXTRACT(month FROM a.ref_date - INTERVAL '2 months')::smallint AND fm_ant2.ano = EXTRACT(year FROM a.ref_date - INTERVAL '2 months')::smallint
    LEFT JOIN core_vendas_faturamento.metas_mensais mt ON mt.mes = p_mes AND mt.ano = p_ano AND mt.tipo = 'faturamento'
    LEFT JOIN fat_diario fd ON true;
$function$;

-- fn_dashboard_mensal_vendas: 2 ponto(s) alterado(s)
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_dashboard_mensal_vendas(p_mes smallint, p_ano smallint, p_is_track_record boolean DEFAULT false, p_codigo_empresa uuid DEFAULT NULL::uuid)
 RETURNS TABLE(mes smallint, ano smallint, vendas_total numeric, qtd_pedidos bigint, vendas_mes_anterior numeric, qtd_pedidos_mes_anterior bigint, vendas_mes_antepassado numeric, qtd_pedidos_mes_antepassado bigint, meta numeric, perc_atingimento numeric, vendas_hoje numeric, vendas_ontem numeric, pedidos_hoje bigint, pedidos_ontem bigint)
 LANGUAGE sql
 STABLE
AS $function$
    WITH alvo AS (
        SELECT make_date(p_ano::integer, p_mes::integer, 1) AS ref_date
    ), vendas_mensal AS (
        SELECT EXTRACT(month FROM data_inclusao)::smallint AS mes,
            EXTRACT(year FROM data_inclusao)::smallint AS ano,
            sum(total_pedido) AS vendas_total,
            count(DISTINCT numero_pedido) AS qtd_pedidos
        FROM core_vendas_faturamento.vw_vendas_base, alvo
        WHERE grupo = 'LIQUIDO'
          AND is_track_record = p_is_track_record
      AND (p_codigo_empresa IS NULL OR core_vendas_faturamento.fn_unidade_do_vendedor(codigo_empresa, cod_vendedor) = p_codigo_empresa)
          AND data_inclusao >= (alvo.ref_date - INTERVAL '2 months')
          AND data_inclusao <  (alvo.ref_date + INTERVAL '1 month')
        GROUP BY 1, 2
    ), vendas_diario AS (
        SELECT
            sum(total_pedido) FILTER (WHERE data_inclusao = CURRENT_DATE) AS vendas_hoje,
            sum(total_pedido) FILTER (WHERE data_inclusao = CURRENT_DATE - 1) AS vendas_ontem,
            count(DISTINCT numero_pedido) FILTER (WHERE data_inclusao = CURRENT_DATE) AS pedidos_hoje,
            count(DISTINCT numero_pedido) FILTER (WHERE data_inclusao = CURRENT_DATE - 1) AS pedidos_ontem
        FROM core_vendas_faturamento.vw_vendas_base
        WHERE grupo = 'LIQUIDO'
          AND is_track_record = p_is_track_record
      AND (p_codigo_empresa IS NULL OR core_vendas_faturamento.fn_unidade_do_vendedor(codigo_empresa, cod_vendedor) = p_codigo_empresa)
          AND data_inclusao = ANY (ARRAY[CURRENT_DATE, CURRENT_DATE - 1])
    )
    SELECT p_mes, p_ano,
        COALESCE(vm.vendas_total, 0), COALESCE(vm.qtd_pedidos, 0),
        COALESCE(vm_ant.vendas_total, 0), COALESCE(vm_ant.qtd_pedidos, 0),
        COALESCE(vm_ant2.vendas_total, 0), COALESCE(vm_ant2.qtd_pedidos, 0),
        COALESCE(mt.meta, 0),
        CASE WHEN COALESCE(mt.meta, 0) = 0 THEN NULL ELSE round(COALESCE(vm.vendas_total, 0) / mt.meta * 100, 2) END,
        COALESCE(vd.vendas_hoje, 0), COALESCE(vd.vendas_ontem, 0),
        COALESCE(vd.pedidos_hoje, 0), COALESCE(vd.pedidos_ontem, 0)
    FROM alvo a
    LEFT JOIN vendas_mensal vm ON vm.mes = p_mes AND vm.ano = p_ano
    LEFT JOIN vendas_mensal vm_ant ON vm_ant.mes = EXTRACT(month FROM a.ref_date - INTERVAL '1 month')::smallint AND vm_ant.ano = EXTRACT(year FROM a.ref_date - INTERVAL '1 month')::smallint
    LEFT JOIN vendas_mensal vm_ant2 ON vm_ant2.mes = EXTRACT(month FROM a.ref_date - INTERVAL '2 months')::smallint AND vm_ant2.ano = EXTRACT(year FROM a.ref_date - INTERVAL '2 months')::smallint
    LEFT JOIN core_vendas_faturamento.metas_mensais mt ON mt.mes = p_mes AND mt.ano = p_ano AND mt.tipo = 'venda'
    LEFT JOIN vendas_diario vd ON true;
$function$;

-- fn_detalhe_vendedor_faturamento: 1 ponto(s) alterado(s)
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_detalhe_vendedor_faturamento(p_mes smallint, p_ano smallint, p_is_track_record boolean DEFAULT false, p_codigo_empresa uuid DEFAULT NULL::uuid)
 RETURNS TABLE(mes smallint, ano smallint, id_pessoa uuid, codigo_empresa uuid, cod_vendedor text, vendedor text, nome_exibicao_vendedor character varying, total_nfs bigint, valor_total numeric, qtd_spot bigint, valor_spot numeric, qtd_contrato bigint, valor_contrato numeric, qtd_sem_classificacao bigint, valor_sem_classificacao numeric, qtd_cancelado bigint, valor_cancelado numeric, qtd_devolvido bigint, valor_devolvido numeric, qtd_recusado bigint, valor_recusado numeric, qtd_refaturamento bigint, valor_refaturamento numeric, numero_pedido character varying, numero_nf character varying, nome_destinatario character varying, data_emissao date, valor_nf numeric, tipo_contrato text, classificacao text, situacao text, previsao_faturamento character varying, faturado boolean)
 LANGUAGE sql
 STABLE
AS $function$
    WITH alvo AS (
        SELECT make_date(p_ano::integer, p_mes::integer, 1) AS ref_date
    ), detalhe AS (
        SELECT p_mes AS mes,
            p_ano AS ano,
            nf.codigo_empresa,
            nf.cod_vendedor,
            COALESCE(vd.id_funcionario::text, (('sem_mapa:'::text || nf.codigo_empresa::text) || ':'::text) || nf.cod_vendedor) AS identidade,
            vd.id_funcionario AS id_pessoa,
            COALESCE(f.nome_completo, nf.vendedor) AS vendedor,
            vd.nome_exibicao AS nome_exibicao_vendedor,
            nf.numero_pedido,
            nf.numero_nf,
            nf.destinatario AS nome_destinatario,
            nf.data_emissao,
            nf.valor_nf,
            COALESCE(nf.tipo_contrato, 'SEM CLASSIFICAÇÃO'::text) AS tipo_contrato,
                CASE nf.grupo_deducao
                    WHEN 'G1'::text THEN 'CANCELADOS'::text
                    WHEN 'G2'::text THEN 'DEVOLVIDOS'::text
                    WHEN 'G3'::text THEN 'RECUSADOS'::text
                    WHEN 'G4'::text THEN 'OUTROS'::text
                    WHEN 'G5'::text THEN 'OUTROS'::text
                    WHEN 'G6'::text THEN 'REFATURAMENTO NÃO RASTREÁVEL'::text
                    WHEN 'LIQUIDO'::text THEN 'LIQUIDO'::text
                    ELSE nf.grupo_deducao
                END AS classificacao,
            nf.situacao,
            pv.data_previsao AS previsao_faturamento,
            pv.faturado
           FROM core_vendas_faturamento.vw_nf_classified nf
             CROSS JOIN alvo
        LEFT JOIN core_vendas_faturamento.vendedores vd
          ON vd.codigo_empresa = nf.codigo_empresa
         AND vd.codigo_vendedor_omie::text = nf.cod_vendedor
         AND vd.deleted_at IS NULL
        LEFT JOIN core.funcionarios f ON f.id = vd.id_funcionario
        -- Previsão e faturado do PEDIDO por trás da NF.
        --
        -- vw_nf_classified não expõe codigo_pedido_omie (só numero_pedido) e não
        -- tem nenhum dos dois campos. A alternativa a alterar a view — que
        -- alimenta dashboard, rankings, planilhas e resumo — é buscar aqui.
        --
        -- LATERAL correlacionado com LIMIT 1: não multiplica a NF, e a NF sem
        -- pedido correspondente sobrevive com os dois campos nulos.
        --
        -- ORDER BY ped.seq pega a CABEÇA da família. numero_pedido NÃO é único
        -- por empresa (o unique é numero_pedido + sequencial); sem a ordem, a
        -- previsão poderia vir de uma parcial, com data diferente da que a
        -- consolidação usa. COALESCE(sequencial, 0) porque sequencial nulo
        -- também é cabeça.
        --
        -- As duas pernas entram filtradas pelo próprio parâmetro da função:
        -- p_is_track_record é constante na chamada, então o planner descarta o
        -- ramo que não vale.
        LEFT JOIN LATERAL (
          SELECT ped.data_previsao, ped.faturado
            FROM (
              SELECT p.data_previsao, p.faturado, COALESCE(p.sequencial, (0)::numeric) AS seq
                FROM core_vendas_faturamento.pedidos_vendas p
               WHERE NOT p_is_track_record
                 AND p.codigo_empresa = nf.codigo_empresa
                 AND (p.numero_pedido)::text = (nf.numero_pedido)::text
                 AND p.deleted_at IS NULL
              UNION ALL
              SELECT h.data_previsao, h.faturado, COALESCE(h.sequencial, (0)::numeric)
                FROM historico.hst_pedidos_vendas h
               WHERE p_is_track_record
                 AND h.codigo_empresa = nf.codigo_empresa
                 AND (h.numero_pedido)::text = (nf.numero_pedido)::text
                 AND h.deleted_at IS NULL
            ) ped
           ORDER BY ped.seq
           LIMIT 1
        ) pv ON true
          WHERE nf.data_emissao IS NOT NULL AND nf.cod_vendedor IS NOT NULL
            AND nf.is_track_record = p_is_track_record
      AND (p_codigo_empresa IS NULL OR core_vendas_faturamento.fn_unidade_do_vendedor(nf.codigo_empresa, nf.cod_vendedor) = p_codigo_empresa)
      AND core_vendas_faturamento.fn_vendedor_no_periodo(nf.codigo_empresa, nf.cod_vendedor, make_date(p_ano::integer, p_mes::integer, 1), (make_date(p_ano::integer, p_mes::integer, 1) + INTERVAL '1 month - 1 day')::date)
            AND nf.data_emissao >= alvo.ref_date
            AND nf.data_emissao <  (alvo.ref_date + INTERVAL '1 month')
        ), resumo AS (
         SELECT detalhe.mes,
            detalhe.ano,
            detalhe.identidade,
            count(*) FILTER (WHERE detalhe.classificacao = 'LIQUIDO'::text) AS total_nfs,
            COALESCE(sum(detalhe.valor_nf) FILTER (WHERE detalhe.classificacao = 'LIQUIDO'::text), 0::numeric) AS valor_total,
            count(*) FILTER (WHERE detalhe.classificacao = 'LIQUIDO'::text AND detalhe.tipo_contrato = 'SPOT'::text) AS qtd_spot,
            COALESCE(sum(detalhe.valor_nf) FILTER (WHERE detalhe.classificacao = 'LIQUIDO'::text AND detalhe.tipo_contrato = 'SPOT'::text), 0::numeric) AS valor_spot,
            count(*) FILTER (WHERE detalhe.classificacao = 'LIQUIDO'::text AND detalhe.tipo_contrato = 'CONTRATO'::text) AS qtd_contrato,
            COALESCE(sum(detalhe.valor_nf) FILTER (WHERE detalhe.classificacao = 'LIQUIDO'::text AND detalhe.tipo_contrato = 'CONTRATO'::text), 0::numeric) AS valor_contrato,
            count(*) FILTER (WHERE detalhe.classificacao = 'LIQUIDO'::text AND detalhe.tipo_contrato = 'SEM CLASSIFICAÇÃO'::text) AS qtd_sem_classificacao,
            COALESCE(sum(detalhe.valor_nf) FILTER (WHERE detalhe.classificacao = 'LIQUIDO'::text AND detalhe.tipo_contrato = 'SEM CLASSIFICAÇÃO'::text), 0::numeric) AS valor_sem_classificacao,
            count(*) FILTER (WHERE detalhe.classificacao = 'CANCELADOS'::text) AS qtd_cancelado,
            COALESCE(sum(detalhe.valor_nf) FILTER (WHERE detalhe.classificacao = 'CANCELADOS'::text), 0::numeric) AS valor_cancelado,
            count(*) FILTER (WHERE detalhe.classificacao = 'DEVOLVIDOS'::text) AS qtd_devolvido,
            COALESCE(sum(detalhe.valor_nf) FILTER (WHERE detalhe.classificacao = 'DEVOLVIDOS'::text), 0::numeric) AS valor_devolvido,
            count(*) FILTER (WHERE detalhe.classificacao = 'RECUSADOS'::text) AS qtd_recusado,
            COALESCE(sum(detalhe.valor_nf) FILTER (WHERE detalhe.classificacao = 'RECUSADOS'::text), 0::numeric) AS valor_recusado,
            count(*) FILTER (WHERE detalhe.classificacao = 'REFATURAMENTO NÃO RASTREÁVEL'::text) AS qtd_refaturamento,
            COALESCE(sum(detalhe.valor_nf) FILTER (WHERE detalhe.classificacao = 'REFATURAMENTO NÃO RASTREÁVEL'::text), 0::numeric) AS valor_refaturamento
           FROM detalhe
          GROUP BY detalhe.mes, detalhe.ano, detalhe.identidade
        )
    SELECT d.mes,
        d.ano,
        d.id_pessoa,
        d.codigo_empresa,
        d.cod_vendedor,
        d.vendedor,
        d.nome_exibicao_vendedor,
        r.total_nfs,
        r.valor_total,
        r.qtd_spot,
        r.valor_spot,
        r.qtd_contrato,
        r.valor_contrato,
        r.qtd_sem_classificacao,
        r.valor_sem_classificacao,
        r.qtd_cancelado,
        r.valor_cancelado,
        r.qtd_devolvido,
        r.valor_devolvido,
        r.qtd_recusado,
        r.valor_recusado,
        r.qtd_refaturamento,
        r.valor_refaturamento,
        d.numero_pedido,
        d.numero_nf,
        d.nome_destinatario,
        d.data_emissao,
        d.valor_nf,
        d.tipo_contrato,
        d.classificacao,
        d.situacao,
        d.previsao_faturamento,
        d.faturado
       FROM detalhe d
         JOIN resumo r ON r.mes = d.mes AND r.ano = d.ano AND r.identidade = d.identidade
      ORDER BY d.ano, d.mes, d.identidade, d.data_emissao DESC;
$function$;

-- fn_detalhe_vendedor_vendas: 1 ponto(s) alterado(s)
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_detalhe_vendedor_vendas(p_mes smallint, p_ano smallint, p_is_track_record boolean DEFAULT false, p_codigo_empresa uuid DEFAULT NULL::uuid)
 RETURNS TABLE(mes smallint, ano smallint, id_pessoa uuid, codigo_empresa uuid, cod_vendedor text, vendedor text, nome_exibicao_vendedor character varying, total_pedidos bigint, valor_total numeric, numero_pedido character varying, numero_nf character varying, nome_cliente character varying, data_pedido date, valor_pedido numeric, qtd_spot bigint, valor_spot numeric, qtd_contrato bigint, valor_contrato numeric, qtd_sem_classificacao bigint, valor_sem_classificacao numeric, tipo_contrato text, situacao text, previsao_faturamento character varying, faturado boolean)
 LANGUAGE sql
 STABLE
AS $function$
    WITH alvo AS (
        SELECT make_date(p_ano::integer, p_mes::integer, 1) AS ref_date
    ), detalhe AS (
        SELECT p_mes AS mes,
            p_ano AS ano,
            vb.codigo_empresa,
            vb.cod_vendedor,
            COALESCE(vd.id_funcionario::text, (('sem_mapa:'::text || vb.codigo_empresa::text) || ':'::text) || vb.cod_vendedor) AS identidade,
            vd.id_funcionario AS id_pessoa,
            COALESCE(f.nome_completo, vb.vendedor) AS vendedor,
            vd.nome_exibicao AS nome_exibicao_vendedor,
            vb.numero_pedido,
            vb.numero_nf,
            COALESCE(vb.razao_social_cliente, vb.nome_cliente) AS nome_cliente,
            vb.data_inclusao AS data_pedido,
            vb.total_pedido AS valor_pedido,
            COALESCE(vb.tipo_contrato, 'SEM CLASSIFICAÇÃO'::text) AS tipo_contrato,
            vb.situacao,
            vb.previsao_faturamento,
            vb.faturado
           FROM core_vendas_faturamento.vw_vendas_base vb
             CROSS JOIN alvo
        LEFT JOIN core_vendas_faturamento.vendedores vd
          ON vd.codigo_empresa = vb.codigo_empresa
         AND vd.codigo_vendedor_omie::text = vb.cod_vendedor
         AND vd.deleted_at IS NULL
        LEFT JOIN core.funcionarios f ON f.id = vd.id_funcionario
          WHERE vb.data_inclusao IS NOT NULL AND vb.cod_vendedor IS NOT NULL AND vb.grupo = 'LIQUIDO'::text
            AND vb.is_track_record = p_is_track_record
      AND (p_codigo_empresa IS NULL OR core_vendas_faturamento.fn_unidade_do_vendedor(vb.codigo_empresa, vb.cod_vendedor) = p_codigo_empresa)
      AND core_vendas_faturamento.fn_vendedor_no_periodo(vb.codigo_empresa, vb.cod_vendedor, make_date(p_ano::integer, p_mes::integer, 1), (make_date(p_ano::integer, p_mes::integer, 1) + INTERVAL '1 month - 1 day')::date)
            AND vb.data_inclusao >= alvo.ref_date
            AND vb.data_inclusao <  (alvo.ref_date + INTERVAL '1 month')
        ), resumo AS (
         SELECT detalhe.mes,
            detalhe.ano,
            detalhe.identidade,
            count(DISTINCT detalhe.codigo_empresa::text || ':' || detalhe.numero_pedido) AS total_pedidos,
            COALESCE(sum(detalhe.valor_pedido), 0::numeric) AS valor_total,
            count(DISTINCT detalhe.codigo_empresa::text || ':' || detalhe.numero_pedido) FILTER (WHERE detalhe.tipo_contrato = 'SPOT'::text) AS qtd_spot,
            COALESCE(sum(detalhe.valor_pedido) FILTER (WHERE detalhe.tipo_contrato = 'SPOT'::text), 0::numeric) AS valor_spot,
            count(DISTINCT detalhe.codigo_empresa::text || ':' || detalhe.numero_pedido) FILTER (WHERE detalhe.tipo_contrato = 'CONTRATO'::text) AS qtd_contrato,
            COALESCE(sum(detalhe.valor_pedido) FILTER (WHERE detalhe.tipo_contrato = 'CONTRATO'::text), 0::numeric) AS valor_contrato,
            count(DISTINCT detalhe.codigo_empresa::text || ':' || detalhe.numero_pedido) FILTER (WHERE detalhe.tipo_contrato = 'SEM CLASSIFICAÇÃO'::text) AS qtd_sem_classificacao,
            COALESCE(sum(detalhe.valor_pedido) FILTER (WHERE detalhe.tipo_contrato = 'SEM CLASSIFICAÇÃO'::text), 0::numeric) AS valor_sem_classificacao
           FROM detalhe
          GROUP BY detalhe.mes, detalhe.ano, detalhe.identidade
        )
    SELECT d.mes,
        d.ano,
        d.id_pessoa,
        d.codigo_empresa,
        d.cod_vendedor,
        d.vendedor,
        d.nome_exibicao_vendedor,
        r.total_pedidos,
        r.valor_total,
        d.numero_pedido,
        d.numero_nf,
        d.nome_cliente,
        d.data_pedido,
        d.valor_pedido,
        r.qtd_spot,
        r.valor_spot,
        r.qtd_contrato,
        r.valor_contrato,
        r.qtd_sem_classificacao,
        r.valor_sem_classificacao,
        d.tipo_contrato,
        d.situacao,
        d.previsao_faturamento,
        d.faturado
       FROM detalhe d
         JOIN resumo r ON r.mes = d.mes AND r.ano = d.ano AND r.identidade = d.identidade
      ORDER BY d.ano, d.mes, d.identidade, d.data_pedido DESC;
$function$;

-- fn_faturamento_resumo_mensal: 1 ponto(s) alterado(s)
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_faturamento_resumo_mensal(p_periodo_inicio date DEFAULT NULL::date, p_periodo_fim date DEFAULT NULL::date, p_is_track_record boolean DEFAULT false, p_codigo_empresa uuid DEFAULT NULL::uuid)
 RETURNS TABLE(periodo date, fat_bruto numeric, fat_ypfb numeric, fat_com_ypfb numeric, g1_cancelado numeric, g2_devolvido numeric, g3_recusado numeric, g4_chile numeric, g5_av_vendedor numeric, g6_refaturamento numeric, fat_liquido numeric, batimento numeric, total_nfs bigint, total_nfs_liquidas bigint)
 LANGUAGE sql
 STABLE
AS $function$
    WITH base AS (
        SELECT date_trunc('month', data_emissao)::date AS periodo, valor_nf, grupo_deducao, is_ypfb, numero_nf
        FROM core_vendas_faturamento.vw_nf_classified
        WHERE data_emissao IS NOT NULL
          AND is_track_record = p_is_track_record
      AND (p_codigo_empresa IS NULL OR core_vendas_faturamento.fn_unidade_do_vendedor(codigo_empresa, cod_vendedor) = p_codigo_empresa)
          AND (p_periodo_inicio IS NULL OR data_emissao >= p_periodo_inicio)
          AND (p_periodo_fim    IS NULL OR data_emissao <  (p_periodo_fim + INTERVAL '1 month'))
    )
    SELECT periodo,
        COALESCE(SUM(valor_nf) FILTER (WHERE NOT is_ypfb), 0),
        COALESCE(SUM(valor_nf) FILTER (WHERE is_ypfb), 0),
        COALESCE(SUM(valor_nf), 0),
        COALESCE(SUM(valor_nf) FILTER (WHERE grupo_deducao = 'G1'), 0),
        COALESCE(SUM(valor_nf) FILTER (WHERE grupo_deducao = 'G2'), 0),
        COALESCE(SUM(valor_nf) FILTER (WHERE grupo_deducao = 'G3'), 0),
        COALESCE(SUM(valor_nf) FILTER (WHERE grupo_deducao = 'G4'), 0),
        COALESCE(SUM(valor_nf) FILTER (WHERE grupo_deducao = 'G5'), 0),
        COALESCE(SUM(valor_nf) FILTER (WHERE grupo_deducao = 'G6'), 0),
        COALESCE(SUM(valor_nf) FILTER (WHERE grupo_deducao = 'LIQUIDO'), 0),
        COALESCE(SUM(valor_nf), 0)
            - COALESCE(SUM(valor_nf) FILTER (WHERE grupo_deducao <> 'LIQUIDO'), 0)
            - COALESCE(SUM(valor_nf) FILTER (WHERE grupo_deducao = 'LIQUIDO'), 0),
        count(DISTINCT numero_nf),
        count(DISTINCT numero_nf) FILTER (WHERE grupo_deducao = 'LIQUIDO')
    FROM base
    GROUP BY periodo
    ORDER BY periodo;
$function$;

-- fn_ranking_vendedores_faturamento: 1 ponto(s) alterado(s)
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ranking_vendedores_faturamento(p_mes smallint, p_ano smallint, p_is_track_record boolean DEFAULT false, p_codigo_empresa uuid DEFAULT NULL::uuid)
 RETURNS TABLE(mes smallint, ano smallint, posicao bigint, id_pessoa uuid, cod_vendedor text, codigo_empresa uuid, codigos_vendedor text[], vendedor text, nome_exibicao_vendedor character varying, faturamento numeric, total_nfs bigint, perc_participacao numeric, perc_meta numeric, meta_individual numeric, empresas uuid[])
 LANGUAGE sql
 STABLE
AS $function$
    WITH alvo AS (
        SELECT make_date(p_ano::integer, p_mes::integer, 1) AS ref_date
    ), base AS (
        SELECT nf.codigo_empresa, nf.cod_vendedor, nf.vendedor, nf.valor_nf, nf.numero_pedido
        FROM core_vendas_faturamento.vw_nf_classified nf
        CROSS JOIN alvo
        WHERE nf.grupo_deducao = 'LIQUIDO' AND nf.cod_vendedor IS NOT NULL AND nf.cod_vendedor <> '0'
          AND nf.is_track_record = p_is_track_record
      AND (p_codigo_empresa IS NULL OR core_vendas_faturamento.fn_unidade_do_vendedor(nf.codigo_empresa, nf.cod_vendedor) = p_codigo_empresa)
      AND core_vendas_faturamento.fn_vendedor_no_periodo(nf.codigo_empresa, nf.cod_vendedor, make_date(p_ano::integer, p_mes::integer, 1), (make_date(p_ano::integer, p_mes::integer, 1) + INTERVAL '1 month - 1 day')::date)
          AND nf.data_emissao >= alvo.ref_date
          AND nf.data_emissao <  (alvo.ref_date + INTERVAL '1 month')
    ), base_sub AS (
        SELECT base.*,
            sum(base.valor_nf) OVER (PARTITION BY base.codigo_empresa, base.cod_vendedor) AS sub_faturamento
        FROM base
    ), fat_vendedor AS (
        SELECT
            COALESCE(vd.id_funcionario::text, 'sem_mapa:' || b.codigo_empresa::text || ':' || b.cod_vendedor) AS identidade,
            MIN(vd.id_funcionario::text)::uuid AS id_pessoa,
            COALESCE(MIN(f.nome_completo), MIN(b.vendedor)) AS vendedor,
            MIN(vd.nome_exibicao) AS nome_exibicao_vendedor,
            (array_agg(b.cod_vendedor ORDER BY b.sub_faturamento DESC, b.cod_vendedor))[1] AS cod_vendedor,
            (array_agg(b.codigo_empresa ORDER BY b.sub_faturamento DESC, b.cod_vendedor))[1] AS codigo_empresa,
            array_agg(DISTINCT b.cod_vendedor ORDER BY b.cod_vendedor) AS codigos_vendedor,
            array_agg(DISTINCT b.codigo_empresa) AS empresas,
            sum(b.valor_nf) AS faturamento,
            count(*) AS total_nfs
        FROM base_sub b
        LEFT JOIN core_vendas_faturamento.vendedores vd
          ON vd.codigo_empresa = b.codigo_empresa
         AND vd.codigo_vendedor_omie::text = b.cod_vendedor
         AND vd.deleted_at IS NULL
        LEFT JOIN core.funcionarios f ON f.id = vd.id_funcionario
        GROUP BY COALESCE(vd.id_funcionario::text, 'sem_mapa:' || b.codigo_empresa::text || ':' || b.cod_vendedor)
    ), fat_total_mes AS (
        SELECT sum(faturamento) AS fat_total
        FROM fat_vendedor
    ), vendedores_ativos_mes AS (
        -- HEADCOUNT GLOBAL, e é aqui que morava o bug.
        --
        -- Antes:  SELECT count(*) FROM fat_vendedor
        -- O fat_vendedor herda o WHERE da CTE `base`, que inclui o filtro
        -- (p_codigo_empresa IS NULL OR ... = p_codigo_empresa). Chamando com
        -- codigo_empresa, o divisor virava o headcount DAQUELA unidade — e como
        -- metas_mensais tem PK (mes, ano, tipo) e nenhuma coluna de empresa, a
        -- MESMA meta global era dividida uma vez por unidade. Daí 29M/7 na
        -- satélite e 29M/36 na grande, para a mesma meta de 29M.
        --
        -- Agora lê `vendedores` direto, SEM nenhum filtro de empresa, então o
        -- valor é idêntico para todo vendedor da empresa, seja qual for a
        -- unidade da chamada.
        --
        -- count(DISTINCT id_funcionario), não count(*): quem tem código em mais
        -- de uma unidade tem uma linha por código em `vendedores` (Ana Caroline,
        -- Diego e Joares têm duas cada). Contar linhas dobraria essas pessoas no
        -- divisor — o mesmo erro de dobra, só mudando de lugar. O fallback
        -- 'sem_vinculo:' faz cada código ainda não vinculado contar como uma
        -- pessoa, espelhando o 'sem_mapa:' do ranking.
        SELECT count(DISTINCT COALESCE(
                   vd.id_funcionario::text,
                   'sem_vinculo:' || vd.codigo_empresa::text || ':' || vd.codigo_vendedor_omie
               )) AS qtd_vendedores
        FROM core_vendas_faturamento.vendedores vd
        WHERE vd.ativo = true
          AND vd.deleted_at IS NULL
    )
    SELECT p_mes, p_ano,
        rank() OVER (ORDER BY fv.faturamento DESC),
        fv.id_pessoa, fv.cod_vendedor, fv.codigo_empresa, fv.codigos_vendedor, fv.vendedor, fv.nome_exibicao_vendedor, fv.faturamento, fv.total_nfs,
        CASE WHEN COALESCE(ft.fat_total, 0) = 0 THEN NULL ELSE round(fv.faturamento / ft.fat_total * 100, 2) END,
        CASE WHEN COALESCE(mt.meta, 0) = 0 OR COALESCE(va.qtd_vendedores, 0) = 0 THEN NULL ELSE round(fv.faturamento / (mt.meta / va.qtd_vendedores::numeric) * 100, 2) END,
        CASE WHEN COALESCE(va.qtd_vendedores, 0) = 0 THEN NULL ELSE round(mt.meta / va.qtd_vendedores::numeric, 2) END,
        fv.empresas
    FROM fat_vendedor fv
    CROSS JOIN fat_total_mes ft
    CROSS JOIN vendedores_ativos_mes va
    LEFT JOIN core_vendas_faturamento.metas_mensais mt ON mt.mes = p_mes AND mt.ano = p_ano AND mt.tipo = 'faturamento'
    ORDER BY 3;
$function$;

-- fn_ranking_vendedores_vendas: 1 ponto(s) alterado(s)
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ranking_vendedores_vendas(p_mes smallint, p_ano smallint, p_is_track_record boolean DEFAULT false, p_codigo_empresa uuid DEFAULT NULL::uuid)
 RETURNS TABLE(mes smallint, ano smallint, posicao bigint, id_pessoa uuid, cod_vendedor text, codigo_empresa uuid, codigos_vendedor text[], vendedor text, nome_exibicao_vendedor character varying, vendas numeric, qtd_pedidos bigint, perc_participacao numeric, perc_meta numeric, meta_individual numeric, empresas uuid[])
 LANGUAGE sql
 STABLE
AS $function$
    WITH alvo AS (
        SELECT make_date(p_ano::integer, p_mes::integer, 1) AS ref_date
    ), base AS (
        SELECT vb.codigo_empresa, vb.cod_vendedor, vb.vendedor, vb.total_pedido, vb.numero_pedido
        FROM core_vendas_faturamento.vw_vendas_base vb
        CROSS JOIN alvo
        WHERE vb.grupo = 'LIQUIDO' AND vb.cod_vendedor IS NOT NULL AND vb.cod_vendedor <> '0'
          AND vb.is_track_record = p_is_track_record
      AND (p_codigo_empresa IS NULL OR core_vendas_faturamento.fn_unidade_do_vendedor(vb.codigo_empresa, vb.cod_vendedor) = p_codigo_empresa)
      AND core_vendas_faturamento.fn_vendedor_no_periodo(vb.codigo_empresa, vb.cod_vendedor, make_date(p_ano::integer, p_mes::integer, 1), (make_date(p_ano::integer, p_mes::integer, 1) + INTERVAL '1 month - 1 day')::date)
          AND vb.data_inclusao >= alvo.ref_date
          AND vb.data_inclusao <  (alvo.ref_date + INTERVAL '1 month')
    ), base_sub AS (
        SELECT base.*,
            sum(base.total_pedido) OVER (PARTITION BY base.codigo_empresa, base.cod_vendedor) AS sub_vendas
        FROM base
    ), vendas_vendedor AS (
        SELECT
            COALESCE(vd.id_funcionario::text, 'sem_mapa:' || b.codigo_empresa::text || ':' || b.cod_vendedor) AS identidade,
            MIN(vd.id_funcionario::text)::uuid AS id_pessoa,
            COALESCE(MIN(f.nome_completo), MIN(b.vendedor)) AS vendedor,
            MIN(vd.nome_exibicao) AS nome_exibicao_vendedor,
            (array_agg(b.cod_vendedor ORDER BY b.sub_vendas DESC, b.cod_vendedor))[1] AS cod_vendedor,
            (array_agg(b.codigo_empresa ORDER BY b.sub_vendas DESC, b.cod_vendedor))[1] AS codigo_empresa,
            array_agg(DISTINCT b.cod_vendedor ORDER BY b.cod_vendedor) AS codigos_vendedor,
            array_agg(DISTINCT b.codigo_empresa) AS empresas,
            sum(b.total_pedido) AS vendas,
            count(DISTINCT b.codigo_empresa::text || ':' || b.numero_pedido) AS qtd_pedidos
        FROM base_sub b
        LEFT JOIN core_vendas_faturamento.vendedores vd
          ON vd.codigo_empresa = b.codigo_empresa
         AND vd.codigo_vendedor_omie::text = b.cod_vendedor
         AND vd.deleted_at IS NULL
        LEFT JOIN core.funcionarios f ON f.id = vd.id_funcionario
        GROUP BY COALESCE(vd.id_funcionario::text, 'sem_mapa:' || b.codigo_empresa::text || ':' || b.cod_vendedor)
    ), vendas_total_mes AS (
        SELECT sum(vendas) AS vendas_total
        FROM vendas_vendedor
    ), vendedores_ativos_mes AS (
        -- HEADCOUNT GLOBAL, e é aqui que morava o bug.
        --
        -- Antes:  SELECT count(*) FROM vendas_vendedor
        -- O vendas_vendedor herda o WHERE da CTE `base`, que inclui o filtro
        -- (p_codigo_empresa IS NULL OR ... = p_codigo_empresa). Chamando com
        -- codigo_empresa, o divisor virava o headcount DAQUELA unidade — e como
        -- metas_mensais tem PK (mes, ano, tipo) e nenhuma coluna de empresa, a
        -- MESMA meta global era dividida uma vez por unidade. Daí 29M/7 na
        -- satélite e 29M/36 na grande, para a mesma meta de 29M.
        --
        -- Agora lê `vendedores` direto, SEM nenhum filtro de empresa, então o
        -- valor é idêntico para todo vendedor da empresa, seja qual for a
        -- unidade da chamada.
        --
        -- count(DISTINCT id_funcionario), não count(*): quem tem código em mais
        -- de uma unidade tem uma linha por código em `vendedores` (Ana Caroline,
        -- Diego e Joares têm duas cada). Contar linhas dobraria essas pessoas no
        -- divisor — o mesmo erro de dobra, só mudando de lugar. O fallback
        -- 'sem_vinculo:' faz cada código ainda não vinculado contar como uma
        -- pessoa, espelhando o 'sem_mapa:' do ranking.
        SELECT count(DISTINCT COALESCE(
                   vd.id_funcionario::text,
                   'sem_vinculo:' || vd.codigo_empresa::text || ':' || vd.codigo_vendedor_omie
               )) AS qtd_vendedores
        FROM core_vendas_faturamento.vendedores vd
        WHERE vd.ativo = true
          AND vd.deleted_at IS NULL
    )
    SELECT p_mes, p_ano,
        rank() OVER (ORDER BY vv.vendas DESC),
        vv.id_pessoa, vv.cod_vendedor, vv.codigo_empresa, vv.codigos_vendedor, vv.vendedor, vv.nome_exibicao_vendedor, vv.vendas, vv.qtd_pedidos,
        CASE WHEN COALESCE(vt.vendas_total, 0) = 0 THEN NULL ELSE round(vv.vendas / vt.vendas_total * 100, 2) END,
        CASE WHEN COALESCE(mt.meta, 0) = 0 OR COALESCE(va.qtd_vendedores, 0) = 0 THEN NULL ELSE round(vv.vendas / (mt.meta / va.qtd_vendedores::numeric) * 100, 2) END,
        CASE WHEN COALESCE(va.qtd_vendedores, 0) = 0 THEN NULL ELSE round(mt.meta / va.qtd_vendedores::numeric, 2) END,
        vv.empresas
    FROM vendas_vendedor vv
    CROSS JOIN vendas_total_mes vt
    CROSS JOIN vendedores_ativos_mes va
    LEFT JOIN core_vendas_faturamento.metas_mensais mt ON mt.mes = p_mes AND mt.ano = p_ano AND mt.tipo = 'venda'
    ORDER BY 3;
$function$;

-- fn_ranking_clientes_faturamento: 1 ponto(s) alterado(s)
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ranking_clientes_faturamento(p_mes smallint, p_ano smallint, p_is_track_record boolean DEFAULT false, p_codigo_empresa uuid DEFAULT NULL::uuid, p_cod_vendedor character varying DEFAULT NULL::character varying)
 RETURNS TABLE(mes smallint, ano smallint, tipo_contrato text, posicao bigint, id_parceiro uuid, cpf_cnpj character varying, codigo_cliente character varying, codigo_empresa uuid, codigos_cliente character varying[], cliente character varying, faturamento numeric, total_nfs bigint, perc_participacao numeric, empresas uuid[])
 LANGUAGE sql
 STABLE
AS $function$
    WITH alvo AS (
        SELECT make_date(p_ano::integer, p_mes::integer, 1) AS ref_date
    ), nf_cliente AS (
        SELECT n.codigo_empresa, n.numero_nf, n.codigo_cliente
          FROM core_vendas_faturamento.notas_fiscais n
         WHERE n.deleted_at IS NULL
           AND n.codigo_cliente IS NOT NULL
           AND NOT p_is_track_record
        UNION ALL
        SELECT h.codigo_empresa, h.numero_nf, h.codigo_cliente
          FROM historico.hst_notas_fiscais h
         WHERE h.deleted_at IS NULL
           AND h.codigo_cliente IS NOT NULL
           AND p_is_track_record
    ), base AS (
        SELECT nfc.codigo_empresa,
            nf2.codigo_cliente,
            par.id AS id_parceiro,
            par.cpf_cnpj,
            COALESCE(par.razao_social, par.nome_fantasia) AS nome_cliente,
            COALESCE(nfc.tipo_contrato, 'SEM CLASSIFICAÇÃO') AS tipo_contrato,
            nfc.valor_nf,
            nfc.numero_nf
        FROM core_vendas_faturamento.vw_nf_classified nfc
        CROSS JOIN alvo
        JOIN nf_cliente nf2
          ON nf2.codigo_empresa = nfc.codigo_empresa
         AND nf2.numero_nf::text = nfc.numero_nf::text
        JOIN core.parceiros par
          ON par.codigo_parceiro_omie::text = nf2.codigo_cliente::text
         AND par.codigo_empresa = nfc.codigo_empresa
         AND par.deleted_at IS NULL
        WHERE nfc.grupo_deducao = 'LIQUIDO'
          AND nfc.is_track_record = p_is_track_record
      AND (p_codigo_empresa IS NULL OR core_vendas_faturamento.fn_unidade_do_vendedor(nfc.codigo_empresa, nfc.cod_vendedor) = p_codigo_empresa)
      AND (p_cod_vendedor IS NULL OR nfc.cod_vendedor = p_cod_vendedor)
          AND nfc.data_emissao >= alvo.ref_date
          AND nfc.data_emissao <  (alvo.ref_date + INTERVAL '1 month')
          AND EXISTS (
            SELECT 1 FROM core.parceiros_tipos pt
            WHERE pt.id_parceiro = par.id
              AND pt.id_tipo_parceiro = 'ce681889-f58e-4d8a-baed-c9192bb39e6c'::uuid
              AND pt.deleted_at IS NULL
          )
    ), base_sub AS (
        SELECT base.*,
            sum(base.valor_nf) OVER (PARTITION BY base.codigo_empresa, base.codigo_cliente, base.tipo_contrato) AS sub_faturamento
        FROM base
    ), clientes_agg AS (
        SELECT
            b.cpf_cnpj,
            b.tipo_contrato,
            (array_agg(b.nome_cliente ORDER BY b.sub_faturamento DESC, b.codigo_cliente))[1] AS cliente,
            (array_agg(b.id_parceiro ORDER BY b.sub_faturamento DESC, b.codigo_cliente))[1] AS id_parceiro,
            (array_agg(b.codigo_cliente ORDER BY b.sub_faturamento DESC, b.codigo_cliente))[1] AS codigo_cliente,
            (array_agg(b.codigo_empresa ORDER BY b.sub_faturamento DESC, b.codigo_cliente))[1] AS codigo_empresa,
            array_agg(DISTINCT b.codigo_cliente ORDER BY b.codigo_cliente) AS codigos_cliente,
            array_agg(DISTINCT b.codigo_empresa) AS empresas,
            sum(b.valor_nf) AS faturamento,
            count(*) AS total_nfs
        FROM base_sub b
        GROUP BY b.cpf_cnpj, b.tipo_contrato
    ), fat_total_mes AS (
        SELECT tipo_contrato, sum(faturamento) AS fat_total
        FROM clientes_agg
        GROUP BY tipo_contrato
    )
    SELECT p_mes, p_ano,
        ca.tipo_contrato,
        rank() OVER (PARTITION BY ca.tipo_contrato ORDER BY ca.faturamento DESC),
        ca.id_parceiro, ca.cpf_cnpj, ca.codigo_cliente, ca.codigo_empresa, ca.codigos_cliente, ca.cliente, ca.faturamento, ca.total_nfs,
        CASE WHEN COALESCE(ft.fat_total, 0) = 0 THEN NULL ELSE round(ca.faturamento / ft.fat_total * 100, 2) END,
        ca.empresas
    FROM clientes_agg ca
    JOIN fat_total_mes ft ON ft.tipo_contrato = ca.tipo_contrato
    ORDER BY 3, 4;
$function$;

-- fn_ranking_clientes_vendas: 1 ponto(s) alterado(s)
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ranking_clientes_vendas(p_mes smallint, p_ano smallint, p_is_track_record boolean DEFAULT false, p_codigo_empresa uuid DEFAULT NULL::uuid, p_cod_vendedor character varying DEFAULT NULL::character varying)
 RETURNS TABLE(mes smallint, ano smallint, tipo_contrato text, posicao bigint, id_parceiro uuid, cpf_cnpj character varying, codigo_cliente character varying, codigo_empresa uuid, codigos_cliente character varying[], cliente character varying, vendas numeric, qtd_pedidos bigint, perc_participacao numeric, empresas uuid[])
 LANGUAGE sql
 STABLE
AS $function$
    WITH alvo AS (
        SELECT make_date(p_ano::integer, p_mes::integer, 1) AS ref_date
    ), base AS (
        SELECT vb.codigo_empresa,
            vb.codigo_cliente,
            par.id AS id_parceiro,
            par.cpf_cnpj,
            COALESCE(par.razao_social, par.nome_fantasia) AS nome_cliente,
            COALESCE(vb.tipo_contrato, 'SEM CLASSIFICAÇÃO') AS tipo_contrato,
            vb.total_pedido,
            vb.numero_pedido
        FROM core_vendas_faturamento.vw_vendas_base vb
        CROSS JOIN alvo
        JOIN core.parceiros par
          ON par.codigo_parceiro_omie::text = vb.codigo_cliente::text
         AND par.codigo_empresa = vb.codigo_empresa
         AND par.deleted_at IS NULL
        WHERE vb.grupo = 'LIQUIDO' AND vb.codigo_cliente IS NOT NULL
          AND vb.is_track_record = p_is_track_record
      AND (p_codigo_empresa IS NULL OR core_vendas_faturamento.fn_unidade_do_vendedor(vb.codigo_empresa, vb.cod_vendedor) = p_codigo_empresa)
      AND (p_cod_vendedor IS NULL OR vb.cod_vendedor = p_cod_vendedor)
          AND vb.data_inclusao >= alvo.ref_date
          AND vb.data_inclusao <  (alvo.ref_date + INTERVAL '1 month')
          AND EXISTS (
            SELECT 1 FROM core.parceiros_tipos pt
            WHERE pt.id_parceiro = par.id
              AND pt.id_tipo_parceiro = 'ce681889-f58e-4d8a-baed-c9192bb39e6c'::uuid
              AND pt.deleted_at IS NULL
          )
    ), base_sub AS (
        SELECT base.*,
            sum(base.total_pedido) OVER (PARTITION BY base.codigo_empresa, base.codigo_cliente, base.tipo_contrato) AS sub_vendas
        FROM base
    ), clientes_agg AS (
        SELECT
            b.cpf_cnpj,
            b.tipo_contrato,
            (array_agg(b.nome_cliente ORDER BY b.sub_vendas DESC, b.codigo_cliente))[1] AS cliente,
            (array_agg(b.id_parceiro ORDER BY b.sub_vendas DESC, b.codigo_cliente))[1] AS id_parceiro,
            (array_agg(b.codigo_cliente ORDER BY b.sub_vendas DESC, b.codigo_cliente))[1] AS codigo_cliente,
            (array_agg(b.codigo_empresa ORDER BY b.sub_vendas DESC, b.codigo_cliente))[1] AS codigo_empresa,
            array_agg(DISTINCT b.codigo_cliente ORDER BY b.codigo_cliente) AS codigos_cliente,
            array_agg(DISTINCT b.codigo_empresa) AS empresas,
            sum(b.total_pedido) AS vendas,
            count(DISTINCT b.codigo_empresa::text || ':' || b.numero_pedido) AS qtd_pedidos
        FROM base_sub b
        GROUP BY b.cpf_cnpj, b.tipo_contrato
    ), vendas_total_mes AS (
        SELECT tipo_contrato, sum(vendas) AS vendas_total
        FROM clientes_agg
        GROUP BY tipo_contrato
    )
    SELECT p_mes, p_ano,
        ca.tipo_contrato,
        rank() OVER (PARTITION BY ca.tipo_contrato ORDER BY ca.vendas DESC),
        ca.id_parceiro, ca.cpf_cnpj, ca.codigo_cliente, ca.codigo_empresa, ca.codigos_cliente, ca.cliente, ca.vendas, ca.qtd_pedidos,
        CASE WHEN COALESCE(vt.vendas_total, 0) = 0 THEN NULL ELSE round(ca.vendas / vt.vendas_total * 100, 2) END,
        ca.empresas
    FROM clientes_agg ca
    JOIN vendas_total_mes vt ON vt.tipo_contrato = ca.tipo_contrato
    ORDER BY 3, 4;
$function$;

-- fn_situacao_pedidos: 1 ponto(s) alterado(s)
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_situacao_pedidos(p_mes smallint, p_ano smallint, p_is_track_record boolean DEFAULT false, p_codigo_empresa uuid DEFAULT NULL::uuid)
 RETURNS TABLE(mes smallint, ano smallint, grupo_deducao text, label_situacao text, qtd_nfs bigint, valor_total numeric)
 LANGUAGE sql
 STABLE
AS $function$
    WITH alvo AS (
        SELECT make_date(p_ano::integer, p_mes::integer, 1) AS ref_date
    )
    SELECT p_mes, p_ano, grupo_deducao,
        CASE grupo_deducao
            WHEN 'G1' THEN 'CANCELADOS' WHEN 'G2' THEN 'DEVOLVIDOS' WHEN 'G3' THEN 'RECUSADOS'
            WHEN 'G4' THEN 'AÇOS VITAL CHILE' WHEN 'G5' THEN 'AÇOS VITAL VENDEDOR'
            WHEN 'G6' THEN 'REFATURAMENTO NÃO RASTREÁVEL' ELSE grupo_deducao
        END,
        count(DISTINCT numero_nf), sum(valor_nf)
    FROM core_vendas_faturamento.vw_nf_classified, alvo
    WHERE grupo_deducao <> 'LIQUIDO'
      AND is_track_record = p_is_track_record
      AND (p_codigo_empresa IS NULL OR core_vendas_faturamento.fn_unidade_do_vendedor(codigo_empresa, cod_vendedor) = p_codigo_empresa)
      AND data_emissao >= alvo.ref_date
      AND data_emissao <  (alvo.ref_date + INTERVAL '1 month')
    GROUP BY grupo_deducao
    ORDER BY 3;
$function$;

-- fn_vendas_faturadas_por_tipo: 1 ponto(s) alterado(s)
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_vendas_faturadas_por_tipo(p_mes smallint, p_ano smallint, p_is_track_record boolean DEFAULT false, p_codigo_empresa uuid DEFAULT NULL::uuid)
 RETURNS TABLE(mes smallint, ano smallint, tipo_contrato text, faturamento numeric, qtd_nfs bigint, percentual_faturamento numeric, percentual_qtd_nfs numeric)
 LANGUAGE sql
 STABLE
AS $function$
    WITH alvo AS (
        SELECT make_date(p_ano::integer, p_mes::integer, 1) AS ref_date
    ), base AS (
        SELECT COALESCE(nfc.tipo_contrato, 'SEM CLASSIFICAÇÃO') AS tipo_contrato,
            sum(nfc.valor_nf) AS faturamento,
            count(DISTINCT nfc.codigo_empresa::text || ':' || nfc.numero_nf::text) AS qtd_nfs
        FROM core_vendas_faturamento.vw_nf_classified nfc
        CROSS JOIN alvo
        WHERE nfc.grupo_deducao = 'LIQUIDO' AND nfc.data_emissao IS NOT NULL
          AND nfc.is_track_record = p_is_track_record
      AND (p_codigo_empresa IS NULL OR core_vendas_faturamento.fn_unidade_do_vendedor(nfc.codigo_empresa, nfc.cod_vendedor) = p_codigo_empresa)
          AND nfc.data_emissao >= alvo.ref_date
          AND nfc.data_emissao <  (alvo.ref_date + INTERVAL '1 month')
        GROUP BY COALESCE(nfc.tipo_contrato, 'SEM CLASSIFICAÇÃO')
    )
    SELECT p_mes, p_ano,
        b.tipo_contrato,
        b.faturamento,
        b.qtd_nfs,
        round(b.faturamento / NULLIF(sum(b.faturamento) OVER (), 0) * 100, 2),
        round(b.qtd_nfs::numeric / NULLIF(sum(b.qtd_nfs) OVER (), 0) * 100, 2)
    FROM base b
    ORDER BY b.tipo_contrato;
$function$;

-- fn_vendas_por_tipo_contrato: 1 ponto(s) alterado(s)
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_vendas_por_tipo_contrato(p_mes smallint, p_ano smallint, p_is_track_record boolean DEFAULT false, p_codigo_empresa uuid DEFAULT NULL::uuid)
 RETURNS TABLE(mes smallint, ano smallint, tipo_contrato text, vendas numeric, qtd_pedidos bigint, percentual_vendas numeric, percentual_qtd_pedidos numeric)
 LANGUAGE sql
 STABLE
AS $function$
    WITH alvo AS (
        SELECT make_date(p_ano::integer, p_mes::integer, 1) AS ref_date
    ), base AS (
        SELECT COALESCE(vb.tipo_contrato, 'SEM CLASSIFICAÇÃO') AS tipo_contrato,
            sum(vb.total_pedido) AS vendas,
            count(DISTINCT vb.codigo_empresa::text || ':' || vb.numero_pedido::text) AS qtd_pedidos
        FROM core_vendas_faturamento.vw_vendas_base vb
        CROSS JOIN alvo
        WHERE vb.grupo = 'LIQUIDO' AND vb.data_inclusao IS NOT NULL
          AND vb.is_track_record = p_is_track_record
      AND (p_codigo_empresa IS NULL OR core_vendas_faturamento.fn_unidade_do_vendedor(vb.codigo_empresa, vb.cod_vendedor) = p_codigo_empresa)
          AND vb.data_inclusao >= alvo.ref_date
          AND vb.data_inclusao <  (alvo.ref_date + INTERVAL '1 month')
        GROUP BY COALESCE(vb.tipo_contrato, 'SEM CLASSIFICAÇÃO')
    )
    SELECT p_mes, p_ano,
        b.tipo_contrato,
        b.vendas,
        b.qtd_pedidos,
        round(b.vendas / NULLIF(sum(b.vendas) OVER (), 0) * 100, 2),
        round(b.qtd_pedidos::numeric / NULLIF(sum(b.qtd_pedidos) OVER (), 0) * 100, 2)
    FROM base b
    ORDER BY b.tipo_contrato;
$function$;

-- fn_vendas_realizadas_por_tipo: 1 ponto(s) alterado(s)
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_vendas_realizadas_por_tipo(p_mes smallint, p_ano smallint, p_is_track_record boolean DEFAULT false, p_codigo_empresa uuid DEFAULT NULL::uuid)
 RETURNS TABLE(mes smallint, ano smallint, tipo_contrato text, valor_vendas numeric, qtd_pedidos bigint, percentual_valor_vendas numeric, percentual_qtd_pedidos numeric)
 LANGUAGE sql
 STABLE
AS $function$
    WITH alvo AS (
        SELECT make_date(p_ano::integer, p_mes::integer, 1) AS ref_date
    ),
    base AS (
        SELECT p_mes AS mes, p_ano AS ano, COALESCE(tipo_contrato, 'SEM CLASSIFICAÇÃO') AS tipo_contrato,
            sum(total_pedido) AS valor_vendas, count(DISTINCT numero_pedido) AS qtd_pedidos
        FROM core_vendas_faturamento.vw_vendas_base, alvo
        WHERE grupo = 'LIQUIDO'
          AND is_track_record = p_is_track_record
      AND (p_codigo_empresa IS NULL OR core_vendas_faturamento.fn_unidade_do_vendedor(codigo_empresa, cod_vendedor) = p_codigo_empresa)
          AND data_inclusao >= alvo.ref_date
          AND data_inclusao <  (alvo.ref_date + INTERVAL '1 month')
        GROUP BY 1, 2, COALESCE(tipo_contrato, 'SEM CLASSIFICAÇÃO')
    )
    SELECT mes, ano, tipo_contrato, valor_vendas, qtd_pedidos,
        ROUND(valor_vendas / NULLIF(SUM(valor_vendas) OVER (), 0) * 100, 2) AS percentual_valor_vendas,
        ROUND(qtd_pedidos::numeric / NULLIF(SUM(qtd_pedidos) OVER (), 0)::numeric * 100, 2) AS percentual_qtd_pedidos
    FROM base
    ORDER BY tipo_contrato;
$function$;

-- fn_dashboard_mensal_faturamento_por_unidade: 2 ponto(s) alterado(s)
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_dashboard_mensal_faturamento_por_unidade(p_mes smallint, p_ano smallint, p_is_track_record boolean DEFAULT false)
 RETURNS TABLE(mes smallint, ano smallint, codigo_empresa uuid, faturamento_total numeric, qtd_nfs bigint, fat_mes_anterior numeric, qtd_nfs_mes_anterior bigint, fat_mes_antepassado numeric, qtd_nfs_mes_antepassado bigint, meta numeric, perc_atingimento numeric, fat_hoje numeric, fat_ontem numeric, pedidos_hoje bigint, pedidos_ontem bigint, participacao_perc numeric)
 LANGUAGE sql
 STABLE
AS $function$
  WITH alvo AS (
    SELECT make_date(p_ano::integer, p_mes::integer, 1) AS ref_date
  ), fat_mensal AS (
    SELECT core_vendas_faturamento.fn_unidade_do_vendedor(n.codigo_empresa, n.cod_vendedor) AS codigo_empresa,
           EXTRACT(month FROM n.data_emissao)::smallint AS mes,
           EXTRACT(year  FROM n.data_emissao)::smallint AS ano,
           sum(n.valor_nf)             AS faturamento_total,
           count(DISTINCT n.numero_nf) AS qtd_nfs
      FROM core_vendas_faturamento.vw_nf_classified n, alvo
     WHERE n.grupo_deducao = 'LIQUIDO'
       AND n.is_track_record = p_is_track_record
       AND n.data_emissao >= (alvo.ref_date - INTERVAL '2 months')
       AND n.data_emissao <  (alvo.ref_date + INTERVAL '1 month')
     GROUP BY 1, 2, 3
  ), fat_diario AS (
    SELECT core_vendas_faturamento.fn_unidade_do_vendedor(n.codigo_empresa, n.cod_vendedor) AS codigo_empresa,
           sum(n.valor_nf)             FILTER (WHERE n.data_emissao = CURRENT_DATE)     AS fat_hoje,
           sum(n.valor_nf)             FILTER (WHERE n.data_emissao = CURRENT_DATE - 1) AS fat_ontem,
           count(DISTINCT n.numero_nf) FILTER (WHERE n.data_emissao = CURRENT_DATE)     AS pedidos_hoje,
           count(DISTINCT n.numero_nf) FILTER (WHERE n.data_emissao = CURRENT_DATE - 1) AS pedidos_ontem
      FROM core_vendas_faturamento.vw_nf_classified n
     WHERE n.grupo_deducao = 'LIQUIDO'
       AND n.is_track_record = p_is_track_record
       AND n.data_emissao = ANY (ARRAY[CURRENT_DATE, CURRENT_DATE - 1])
     GROUP BY 1
  ), unidades_com_movimento AS (
    SELECT codigo_empresa FROM fat_mensal
    UNION
    SELECT codigo_empresa FROM fat_diario
  ), base AS (
    SELECT u.codigo_empresa,
           COALESCE(fm.faturamento_total, 0)  AS faturamento_total,
           COALESCE(fm.qtd_nfs, 0)            AS qtd_nfs,
           COALESCE(fm_ant.faturamento_total, 0)  AS fat_mes_anterior,
           COALESCE(fm_ant.qtd_nfs, 0)            AS qtd_nfs_mes_anterior,
           COALESCE(fm_ant2.faturamento_total, 0) AS fat_mes_antepassado,
           COALESCE(fm_ant2.qtd_nfs, 0)           AS qtd_nfs_mes_antepassado,
           COALESCE(fd.fat_hoje, 0)      AS fat_hoje,
           COALESCE(fd.fat_ontem, 0)     AS fat_ontem,
           COALESCE(fd.pedidos_hoje, 0)  AS pedidos_hoje,
           COALESCE(fd.pedidos_ontem, 0) AS pedidos_ontem
      FROM unidades_com_movimento u
      CROSS JOIN alvo a
      LEFT JOIN fat_mensal fm
             ON fm.codigo_empresa = u.codigo_empresa
            AND fm.mes = p_mes AND fm.ano = p_ano
      LEFT JOIN fat_mensal fm_ant
             ON fm_ant.codigo_empresa = u.codigo_empresa
            AND fm_ant.mes = EXTRACT(month FROM a.ref_date - INTERVAL '1 month')::smallint
            AND fm_ant.ano = EXTRACT(year  FROM a.ref_date - INTERVAL '1 month')::smallint
      LEFT JOIN fat_mensal fm_ant2
             ON fm_ant2.codigo_empresa = u.codigo_empresa
            AND fm_ant2.mes = EXTRACT(month FROM a.ref_date - INTERVAL '2 months')::smallint
            AND fm_ant2.ano = EXTRACT(year  FROM a.ref_date - INTERVAL '2 months')::smallint
      LEFT JOIN fat_diario fd
             ON fd.codigo_empresa = u.codigo_empresa
  )
  SELECT p_mes, p_ano,
         b.codigo_empresa,
         b.faturamento_total, b.qtd_nfs,
         b.fat_mes_anterior, b.qtd_nfs_mes_anterior,
         b.fat_mes_antepassado, b.qtd_nfs_mes_antepassado,
         NULL::numeric AS meta,
         NULL::numeric AS perc_atingimento,
         b.fat_hoje, b.fat_ontem,
         b.pedidos_hoje, b.pedidos_ontem,
         CASE
           WHEN sum(b.faturamento_total) OVER () = 0 THEN 0
           ELSE round(b.faturamento_total / sum(b.faturamento_total) OVER () * 100, 2)
         END AS participacao_perc
    FROM base b
   ORDER BY b.faturamento_total DESC;
$function$;

-- fn_dashboard_mensal_vendas_por_unidade: 2 ponto(s) alterado(s)
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_dashboard_mensal_vendas_por_unidade(p_mes smallint, p_ano smallint, p_is_track_record boolean DEFAULT false)
 RETURNS TABLE(mes smallint, ano smallint, codigo_empresa uuid, vendas_total numeric, qtd_pedidos bigint, vendas_mes_anterior numeric, qtd_pedidos_mes_anterior bigint, vendas_mes_antepassado numeric, qtd_pedidos_mes_antepassado bigint, meta numeric, perc_atingimento numeric, vendas_hoje numeric, vendas_ontem numeric, pedidos_hoje bigint, pedidos_ontem bigint, participacao_perc numeric)
 LANGUAGE sql
 STABLE
AS $function$
  WITH alvo AS (
    SELECT make_date(p_ano::integer, p_mes::integer, 1) AS ref_date
  ), vendas_mensal AS (
    SELECT core_vendas_faturamento.fn_unidade_do_vendedor(v.codigo_empresa, v.cod_vendedor) AS codigo_empresa,
           EXTRACT(month FROM v.data_inclusao)::smallint AS mes,
           EXTRACT(year  FROM v.data_inclusao)::smallint AS ano,
           sum(v.total_pedido)             AS vendas_total,
           count(DISTINCT v.numero_pedido) AS qtd_pedidos
      FROM core_vendas_faturamento.vw_vendas_base v, alvo
     WHERE v.grupo = 'LIQUIDO'
       AND v.is_track_record = p_is_track_record
       AND v.data_inclusao >= (alvo.ref_date - INTERVAL '2 months')
       AND v.data_inclusao <  (alvo.ref_date + INTERVAL '1 month')
     GROUP BY 1, 2, 3
  ), vendas_diario AS (
    SELECT core_vendas_faturamento.fn_unidade_do_vendedor(v.codigo_empresa, v.cod_vendedor) AS codigo_empresa,
           sum(v.total_pedido)             FILTER (WHERE v.data_inclusao = CURRENT_DATE)     AS vendas_hoje,
           sum(v.total_pedido)             FILTER (WHERE v.data_inclusao = CURRENT_DATE - 1) AS vendas_ontem,
           count(DISTINCT v.numero_pedido) FILTER (WHERE v.data_inclusao = CURRENT_DATE)     AS pedidos_hoje,
           count(DISTINCT v.numero_pedido) FILTER (WHERE v.data_inclusao = CURRENT_DATE - 1) AS pedidos_ontem
      FROM core_vendas_faturamento.vw_vendas_base v
     WHERE v.grupo = 'LIQUIDO'
       AND v.is_track_record = p_is_track_record
       AND v.data_inclusao = ANY (ARRAY[CURRENT_DATE, CURRENT_DATE - 1])
     GROUP BY 1
  ), unidades_com_movimento AS (
    -- Uma unidade entra na resposta se teve movimento em qualquer um dos 3
    -- meses da janela, ou hoje/ontem. Unidade sem nada no período fica fora —
    -- não faz sentido desenhar uma fatia de 0%.
    SELECT codigo_empresa FROM vendas_mensal
    UNION
    SELECT codigo_empresa FROM vendas_diario
  ), base AS (
    SELECT u.codigo_empresa,
           COALESCE(vm.vendas_total, 0)      AS vendas_total,
           COALESCE(vm.qtd_pedidos, 0)       AS qtd_pedidos,
           COALESCE(vm_ant.vendas_total, 0)  AS vendas_mes_anterior,
           COALESCE(vm_ant.qtd_pedidos, 0)   AS qtd_pedidos_mes_anterior,
           COALESCE(vm_ant2.vendas_total, 0) AS vendas_mes_antepassado,
           COALESCE(vm_ant2.qtd_pedidos, 0)  AS qtd_pedidos_mes_antepassado,
           COALESCE(vd.vendas_hoje, 0)       AS vendas_hoje,
           COALESCE(vd.vendas_ontem, 0)      AS vendas_ontem,
           COALESCE(vd.pedidos_hoje, 0)      AS pedidos_hoje,
           COALESCE(vd.pedidos_ontem, 0)     AS pedidos_ontem
      FROM unidades_com_movimento u
      CROSS JOIN alvo a
      LEFT JOIN vendas_mensal vm
             ON vm.codigo_empresa = u.codigo_empresa
            AND vm.mes = p_mes AND vm.ano = p_ano
      LEFT JOIN vendas_mensal vm_ant
             ON vm_ant.codigo_empresa = u.codigo_empresa
            AND vm_ant.mes = EXTRACT(month FROM a.ref_date - INTERVAL '1 month')::smallint
            AND vm_ant.ano = EXTRACT(year  FROM a.ref_date - INTERVAL '1 month')::smallint
      LEFT JOIN vendas_mensal vm_ant2
             ON vm_ant2.codigo_empresa = u.codigo_empresa
            AND vm_ant2.mes = EXTRACT(month FROM a.ref_date - INTERVAL '2 months')::smallint
            AND vm_ant2.ano = EXTRACT(year  FROM a.ref_date - INTERVAL '2 months')::smallint
      LEFT JOIN vendas_diario vd
             ON vd.codigo_empresa = u.codigo_empresa
  )
  SELECT p_mes, p_ano,
         b.codigo_empresa,
         b.vendas_total, b.qtd_pedidos,
         b.vendas_mes_anterior, b.qtd_pedidos_mes_anterior,
         b.vendas_mes_antepassado, b.qtd_pedidos_mes_antepassado,
         NULL::numeric AS meta,
         NULL::numeric AS perc_atingimento,
         b.vendas_hoje, b.vendas_ontem,
         b.pedidos_hoje, b.pedidos_ontem,
         CASE
           WHEN sum(b.vendas_total) OVER () = 0 THEN 0
           ELSE round(b.vendas_total / sum(b.vendas_total) OVER () * 100, 2)
         END AS participacao_perc
    FROM base b
   ORDER BY b.vendas_total DESC;
$function$;

COMMIT;
