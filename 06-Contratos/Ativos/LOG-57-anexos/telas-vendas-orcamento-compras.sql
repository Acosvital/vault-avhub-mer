-- Reagrupa no menu do Hub as telas do antigo Comercial/Suprimentos e tira as 5 telas do Orçamento antigo.
--
--   Vendas    : Propostas, Clientes, Relatório de Cotações, Relatório Gerencial (+ telas ocultas da proposta)
--   Orçamento : Painel do Comprador, Pedido de cotação, Ofertas de fornecedor, Fornecedores, Catálogo,
--               Pesquisa de materiais, Parâmetros de custo, Tabela da telha (+ Custo do item, oculta)
--   Compras   : Histórico de compras (junto das telas de Compras que já existem)
--
-- Pontos importantes:
--  * A URL é o caminho de slugs, então este script e o front (branch feat/menu-orcamento-vendas-compras)
--    precisam entrar juntos: /comercial/* vira /vendas/*, /suprimentos/* vira /orcamento/* e
--    /suprimentos/historico-compras vira /compras/historico-compras.
--  * O slug da tela não muda; as permissões (auth.permissoes, por id_tela) e o mapa auth.rotas_telas
--    (por slug) acompanham as telas movidas, sem tocar neles.
--  * As 5 telas antigas do Orçamento (categorias, fornecedores, historico-produtos, sem-cadastro e
--    vinculos) são desativadas (deleted_at). As permissões antigas de "fornecedores" NÃO passam para a
--    tela nova de Fornecedores: quem precisa dela recebe a permissão de novo.
--  * Sincronização Omie sai do menu (a tela foi removida do front).
--  * auth.telas.ordem propaga o delta para os filhos (trg_telas_propagate_ordem): a ordem de um filho é
--    a do pai + a posição relativa. Por isso a ordem dos filhos é calculada a partir do pai.
--  * Idempotente: pode rodar duas vezes.
--
-- Rodar primeiro no banco de teste (api-test) e conferir o menu de um perfil de Vendedor e de um de Compras.

BEGIN;

-- 1) Grupos (raiz): reaproveita os que já existem (vendas e compras já existem; orcamento só se o
--    DBA já tiver removido o antigo, senão reaproveita).
INSERT INTO auth.telas (nome, slug, id_parent, ordem, ativo)
SELECT v.nome, v.slug, NULL, v.ordem, true
  FROM (VALUES ('Vendas', 'vendas', 10), ('Orçamento', 'orcamento', 11), ('Compras', 'compras', 12)) AS v(nome, slug, ordem)
 WHERE NOT EXISTS (SELECT 1 FROM auth.telas x WHERE x.slug = v.slug AND x.id_parent IS NULL AND x.deleted_at IS NULL);

UPDATE auth.telas SET nome = 'Orçamento', updated_at = now()
 WHERE slug = 'orcamento' AND id_parent IS NULL AND deleted_at IS NULL AND nome <> 'Orçamento';

-- 2) Telas antigas do Orçamento: fora (as novas entram no passo 3).
UPDATE auth.telas t
   SET ativo = false, deleted_at = now(), updated_at = now()
  FROM auth.telas pai
 WHERE t.id_parent = pai.id
   AND pai.slug = 'orcamento' AND pai.id_parent IS NULL AND pai.deleted_at IS NULL
   AND t.slug IN ('categorias', 'fornecedores', 'historico-produtos', 'sem-cadastro', 'vinculos')
   AND t.deleted_at IS NULL
   -- 'fornecedores' é slug da tela antiga e da nova: só é "a antiga" enquanto o Comercial/Suprimentos
   -- ainda não foi movido. Isso mantém o script seguro numa segunda execução.
   AND (t.slug <> 'fornecedores'
        OR EXISTS (SELECT 1 FROM auth.telas g WHERE g.slug IN ('comercial', 'suprimentos') AND g.id_parent IS NULL AND g.deleted_at IS NULL));

-- 3) Mapa das telas: (slug, nome, grupo, posição relativa). Quem já existe muda de pai; quem não existe é criado.
CREATE TEMP TABLE _mapa_telas (slug text, nome text, pai text, rel smallint) ON COMMIT DROP;
INSERT INTO _mapa_telas VALUES
  ('propostas',            'Propostas',                'vendas',    20),
  ('clientes',             'Clientes',                 'vendas',    21),
  ('relatorio-cotacoes',   'Relatório de Cotações',    'vendas',    22),
  ('relatorio-gerencial',  'Relatório Gerencial',      'vendas',    23),
  ('propostas-delegacao',  'Delegação de propostas',   'vendas',    90),  -- oculta: só libera escolher outro responsável
  ('propostas-valores',    'Valores das propostas',    'vendas',    91),  -- oculta: libera ver R$ na proposta
  ('solicitacoes-custo',   'Solicitações de custo',    'vendas',    92),  -- oculta: o vendedor pede custo pela proposta
  ('painel-comprador',     'Painel do Comprador',      'orcamento',  1),
  ('pedido-cotacao',       'Pedido de cotação',        'orcamento',  2),
  ('ofertas-fornecedor',   'Ofertas de fornecedor',    'orcamento',  3),
  ('fornecedores',         'Fornecedores',             'orcamento',  4),
  ('catalogo-produtos',    'Catálogo',                 'orcamento',  5),
  ('pesquisa-materiais',   'Pesquisa de materiais',    'orcamento',  6),
  ('parametros-custo',     'Parâmetros de custo',      'orcamento',  7),
  ('tabela-telha',         'Tabela da telha',          'orcamento',  8),
  ('custo-item',           'Custo do item',            'orcamento', 90),  -- oculta: libera ver custo, margem e sugestão
  ('historico-compras',    'Histórico de compras',     'compras',   30);

-- 3a) Já existe (qualquer pai antigo): muda de pai, nome e ordem.
UPDATE auth.telas t
   SET id_parent = p.id, nome = m.nome, ordem = p.ordem + m.rel, updated_at = now()
  FROM _mapa_telas m
  JOIN auth.telas p ON p.slug = m.pai AND p.id_parent IS NULL AND p.deleted_at IS NULL
 WHERE t.slug = m.slug AND t.deleted_at IS NULL
   AND (t.id_parent IS DISTINCT FROM p.id OR t.nome <> m.nome OR t.ordem <> p.ordem + m.rel);

-- 3b) Não existe ainda: cria.
INSERT INTO auth.telas (nome, slug, id_parent, ordem, ativo)
SELECT m.nome, m.slug, p.id, p.ordem + m.rel, true
  FROM _mapa_telas m
  JOIN auth.telas p ON p.slug = m.pai AND p.id_parent IS NULL AND p.deleted_at IS NULL
 WHERE NOT EXISTS (SELECT 1 FROM auth.telas x WHERE x.slug = m.slug AND x.deleted_at IS NULL);

-- 4) Sincronização Omie: sai do menu.
UPDATE auth.telas
   SET ativo = false, deleted_at = now(), updated_at = now()
 WHERE slug = 'sincronizacao-omie' AND deleted_at IS NULL;

-- 5) Grupos antigos Comercial e Suprimentos: saem quando não restar nenhuma tela viva dentro deles.
UPDATE auth.telas g
   SET ativo = false, deleted_at = now(), updated_at = now()
 WHERE g.slug IN ('comercial', 'suprimentos') AND g.id_parent IS NULL AND g.deleted_at IS NULL
   AND NOT EXISTS (SELECT 1 FROM auth.telas f WHERE f.id_parent = g.id AND f.deleted_at IS NULL);

-- Conferência: deve listar Vendas, Orçamento e Compras com as telas acima, e nenhum Comercial/Suprimentos.
SELECT COALESCE(p.slug, '(raiz)') AS grupo, t.slug, t.nome, t.ordem, t.ativo
  FROM auth.telas t LEFT JOIN auth.telas p ON p.id = t.id_parent
 WHERE t.deleted_at IS NULL
   AND (t.slug IN ('vendas', 'orcamento', 'compras', 'comercial', 'suprimentos') OR p.slug IN ('vendas', 'orcamento', 'compras', 'comercial', 'suprimentos'))
 ORDER BY COALESCE(p.ordem, t.ordem), t.ordem;

COMMIT;
