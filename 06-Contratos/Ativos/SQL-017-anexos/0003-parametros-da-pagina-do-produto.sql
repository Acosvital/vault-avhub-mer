-- SQL-017 · anexo 0003 · parâmetros da página do produto com vigência (OQ-46 §4, API-020 §3.3, LOG-60 §3.3)
-- PROPOSTA, 29/10/2026 · dono: Gustavo (DBA) · quem lê: a página do produto da api-acos-vital (branch feat/orcamento-historico-preco)
--
-- Os pesos do score, o limite de volatilidade, o mínimo de pontos e os dias do "dado recente" passam a
-- ser parâmetro com vigência, na mesma tabela versionada dos parâmetros de custo. A janela padrão do
-- histórico já é parâmetro: dias_historico.
--
-- Rodar DEPOIS do SQL-016 bloco A0 (parametros_custo em core_vendas_faturamento). Antes dele, a tabela
-- está em core_comercial: troque o schema nas duas linhas abaixo.
--
-- A API lê a linha vigente por to_jsonb, então funciona antes e depois desta migration: sem a coluna,
-- ou com campo ausente ou inválido, vale o valor de partida do OQ-46 (90 dias, 7 dias, 15%, 3 pontos,
-- pesos 50/30/20) e a resposta traz o aviso em parametros.avisos.
--
-- Trocar um parâmetro = nova versão de parametros_custo (a tabela não aceita UPDATE nem DELETE de versão).

BEGIN;

ALTER TABLE core_vendas_faturamento.parametros_custo
  ADD COLUMN parametros_preco jsonb DEFAULT '{}'::jsonb NOT NULL,
  ADD CONSTRAINT ck_parametros_custo_parametros_preco CHECK (jsonb_typeof(parametros_preco) = 'object');

COMMENT ON COLUMN core_vendas_faturamento.parametros_custo.parametros_preco IS
  'Página do produto (OQ-46 §4). Chaves, todas opcionais: pesos {preco, prazo, historico} (inteiros que somam 100), '
  'limite_volatilidade_pct (número > 0 e <= 100), minimo_pontos_volatilidade (inteiro 2 a 100), dias_recente (inteiro 1 a 365) '
  'e dias_recente_por_categoria {"NOME DA CATEGORIA": dias}. Ausente ou inválido = valor de partida (90 dias, 7 dias, 15%, 3 pontos, 50/30/20). '
  'Exemplo: {"pesos": {"preco": 50, "prazo": 30, "historico": 20}, "limite_volatilidade_pct": 15, "dias_recente": 7, "dias_recente_por_categoria": {"CHAPAS": 15}}.';

COMMIT;
