-- Contrato 33, alternativa ao 0001 para quem NAO quer sobrescrever o corpo das funcoes.
--
-- O 0001 traz o corpo completo das 15 funcoes de dashboard, copiado do banco de teste
-- (esqueleto de 29/09/2026). Se a producao tiver funcoes com ajustes mais novos, o 0001
-- as sobrescreve. Este script faz a MESMA mudanca lendo a definicao que esta no banco
-- agora (pg_get_functiondef) e trocando so o trecho do filtro de empresa, entao preserva
-- o resto de cada funcao.
--
-- Pre-requisito: o 0001 ate o item 4 (colunas, view e as duas funcoes auxiliares
-- fn_unidade_do_vendedor e fn_vendedor_no_periodo). Pode rodar de novo sem efeito.
-- Falha (e desfaz tudo) se uma funcao nao tiver o trecho esperado: nada fica pela metade.

BEGIN;

DO $patch$
DECLARE
  S           constant text := 'core_vendas_faturamento';
  filtradas   constant text[] := ARRAY[
    'fn_dashboard_mensal_faturamento','fn_dashboard_mensal_vendas',
    'fn_detalhe_vendedor_faturamento','fn_detalhe_vendedor_vendas',
    'fn_faturamento_resumo_mensal','fn_situacao_pedidos',
    'fn_ranking_vendedores_faturamento','fn_ranking_vendedores_vendas',
    'fn_ranking_clientes_faturamento','fn_ranking_clientes_vendas',
    'fn_vendas_faturadas_por_tipo','fn_vendas_por_tipo_contrato','fn_vendas_realizadas_por_tipo'];
  com_periodo constant text[] := ARRAY[
    'fn_detalhe_vendedor_faturamento','fn_detalhe_vendedor_vendas',
    'fn_ranking_vendedores_faturamento','fn_ranking_vendedores_vendas'];
  por_unidade constant text[] := ARRAY[
    'fn_dashboard_mensal_faturamento_por_unidade','fn_dashboard_mensal_vendas_por_unidade'];
  nome text;
  oid_f oid;
  def  text;
  novo text;
BEGIN
  FOREACH nome IN ARRAY filtradas || por_unidade LOOP
    SELECT p.oid INTO oid_f FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = S AND p.proname = nome;
    IF oid_f IS NULL THEN RAISE EXCEPTION 'funcao % nao encontrada', nome; END IF;
    def := pg_get_functiondef(oid_f);
    novo := def;

    IF nome = ANY (por_unidade) THEN
      -- agrupa pela unidade de origem do vendedor, nao pelo Omie da venda
      novo := regexp_replace(novo,
        'SELECT (?!u\.)(\w+)\.codigo_empresa,',
        'SELECT ' || S || '.fn_unidade_do_vendedor(\1.codigo_empresa, \1.cod_vendedor) AS codigo_empresa,', 'g');
    ELSE
      -- o filtro de empresa passa a ser a unidade de origem do vendedor
      novo := regexp_replace(novo,
        '\(p_codigo_empresa IS NULL OR (\w+\.)?codigo_empresa = p_codigo_empresa\)',
        '(p_codigo_empresa IS NULL OR ' || S || '.fn_unidade_do_vendedor(\1codigo_empresa, \1cod_vendedor) = p_codigo_empresa)', 'g');
      -- listas de vendedor: so quem valia no mes
      IF nome = ANY (com_periodo) AND position('fn_vendedor_no_periodo' IN novo) = 0 THEN
        novo := regexp_replace(novo,
          '(fn_unidade_do_vendedor\((\w+\.)?codigo_empresa, (\w+\.)?cod_vendedor\) = p_codigo_empresa\))',
          E'\\1\n      AND ' || S || '.fn_vendedor_no_periodo(\2codigo_empresa, \2cod_vendedor, make_date(p_ano::integer, p_mes::integer, 1), (make_date(p_ano::integer, p_mes::integer, 1) + INTERVAL ''1 month - 1 day'')::date)', 'g');
      END IF;
    END IF;

    IF novo = def AND position('fn_unidade_do_vendedor' IN def) = 0 THEN
      RAISE EXCEPTION 'funcao %: o trecho esperado do filtro nao foi encontrado', nome;
    END IF;
    IF novo <> def THEN EXECUTE novo; END IF;
  END LOOP;
END
$patch$;

COMMIT;
