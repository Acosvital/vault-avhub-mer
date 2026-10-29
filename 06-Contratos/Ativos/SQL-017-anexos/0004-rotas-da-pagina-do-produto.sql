-- SQL-017 · anexo 0004 · permissões das rotas da página do produto e da matriz de preços (API-020 §2, LOG-60)
-- PROPOSTA, 29/10/2026 · dono: Gustavo (DBA) · quem usa: a página do produto e a matriz no av-hub
--
-- Sem estas linhas, as rotas novas respondem 403 "rota_sem_mapa" com PERMISSOES_ROTA_MODO=exigir.
-- GET casa por prefixo: /produtos/*/precos cobre também /produtos/:id/precos/serie. O padrão mais
-- específico ganha, então quem lê /produtos por outra tela (o MES, por exemplo) não passa a ver preço.
--
-- Telas:
--   catalogo-produtos  Orçamento › Produtos (página do produto e a aba Matriz de preços)
--   propostas          o vendedor consulta o histórico ao montar a proposta (LOG-60 §3)
--   matriz-precos      slug que o BFF ainda cita; se não estiver em auth.telas, a linha não libera
--                      nada (auth.vw_rotas_telas_conferencia mostra tela_existe = false)
--
-- Pode rodar mais de uma vez: a linha repetida esbarra em ux_rotas_telas_regra e fica como está.

BEGIN;

INSERT INTO auth.rotas_telas (metodo, rota, slug_tela, observacao)
VALUES
  ('GET', '/produtos/*/precos',       'catalogo-produtos', 'API-020: página do produto (preços e série)'),
  ('GET', '/produtos/*/precos',       'propostas',         'API-020: histórico de preço na proposta (LOG-60 §3)'),
  ('GET', '/orcamento/matriz_precos', 'catalogo-produtos', 'API-020: matriz de preços, aba de Orçamento › Produtos'),
  ('GET', '/orcamento/matriz_precos', 'matriz-precos',     'API-020: matriz de preços')
ON CONFLICT DO NOTHING;

COMMIT;

-- Conferência: as quatro linhas e se a tela existe.
-- SELECT metodo, rota, slug_tela, tela_existe FROM auth.vw_rotas_telas_conferencia
--  WHERE rota IN ('/produtos/*/precos', '/orcamento/matriz_precos') ORDER BY rota, slug_tela;
