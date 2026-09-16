---
tags: [erp-acos-vital, av-hub, modulos]
criado: 2026-09-16
atualizado: 2026-09-16
---

# av-hub — Mapa de Módulos

## RH
- **Funcionários** — cadastro central de pessoas (dados pessoais/contrato completos, foto via S3/SeaweedFS com crop no navegador). Campo de UI `reporta_a_id` alimenta o [[Organograma-Visao-Geral|Organograma]] (sistema externo), não é coluna própria de `funcionarios`.
- **Solicitações de Vagas** — workflow de aprovação de headcount (`tipo_vaga`, custo calculado no cliente, `situacao` pendente/aprovado/reprovado). Papel de "aprovador" é **implícito**, derivado da combinação de permissões do usuário (ver [[RH-Escopo-Row-Level-Security]]), não uma flag própria.
- Escopo por setor com convenção "sem vínculo = vazio" + override `setor_irrestrito` — ver [[RH-Escopo-Row-Level-Security]].

## Vendas
Pedidos de venda, notas fiscais de saída — a captura direta do Omie (ver [[Entrada-Comercial]]). Fonte real de reconciliação é a dupla `vw_vendas_base`/`vw_nf_classified` — ver [[AV-Hub-Vendas-Reconciliacao]].

## Portal do Vendedor (autoatendimento)
Ver [[AV-Hub-Portal-Vendedor-Plano]] para o plano completo (Meu Dashboard, Meus Pedidos, Minhas Notas). Cada vendedor vê só os próprios dados, com contagem de SLA até a previsão de faturamento. Escopo de segurança resolvido **no servidor** (nunca aceita `codigo_vendedor` vindo do request). Suporta multi-vínculo (um funcionário pode ter várias linhas de vendedor, uma por filial/conta Omie) — ver a migração `vendedores.id_funcionario` em [[RH-Escopo-Row-Level-Security]].

Extensão: **Auxiliar de vendedor** — um vendedor pode enxergar (só leitura) os dados de outro vendedor titular que ele auxilia.

## Portal do Gerente / Equipe
Visão do gestor sobre todo o time: Dashboard Equipe, Pedidos/Notas da Equipe. Componente próprio: `ClienteDetalhesModalEquipe` (detalhe de cliente escopado à equipe do gerente).

## Portal do PCP ⚠️
Ver [[Achado-Ambiguidade-PCP]] — **não é produção**, é acompanhamento comercial. Pessoas chamadas "diligenciadores" (do setor de PCP) acompanham pedidos/notas de um grupo de vendedores, com paridade de dados com o gestor (visão financeira completa Bruto→Deduções→Líquido).

## Dashboards
Comissões, Faturamento (geral e por tipo), Vendas (geral e por tipo) — com rankings de clientes/vendedores, ritmo de meta.

## Orçamento
Roda 100% sobre JSON local (`app/(protected)/orcamento/_data/*.json`), sem API própria ainda:
- **Categorias** — agrega vínculos por categoria de compra, separando "com cadastro"/"sem cadastro".
- **Fornecedores** — cadastro de parceiros Omie (dados fiscais completos).
- **Histórico de Produtos** — catálogo (400 itens) + histórico de preço por fornecedor, com gráfico de evolução. Hoje cada produto tem **só 1 fornecedor** (o da compra mais recente) — não é relação N:N.
- **Vínculos** — produto/categoria↔fornecedor, com flag `sem_cadastro`.
- **Sem Cadastro** — fila de pendência (fornecedores de vínculo sem cadastro em Parceiros).
- ⚠️ Possível ponto de integração com o módulo de Compras do [[PRD-Estoque-Visao-Geral|PRD do Estoque]], que deixou "cotação entre fornecedores" fora do escopo v1 — ver pendência de relação produto↔fornecedor real em [[AV-Hub-Bugs-Catalogo]].

## Fechamento
Fechamento manual por mês/tipo, com regra de transição: até agosto/2026 é 100% manual (totais automáticos "não confiáveis" — ver divergências em [[AV-Hub-Vendas-Reconciliacao]]); a partir de setembro/2026 lê automaticamente dos dashboards, mas um lançamento manual salvo continua tendo prioridade pontual sobre o automático. Depende da tabela `fechamento_manual`, ainda não criada no backend (ver [[AV-Hub-Bugs-Catalogo]]).

## Cadastros
- **Acessos**: Usuários (com anonimização LGPD via `anonymizedAt`), Perfis (com `tela_inicial_id`), Permissões (com `BulkPermissaoModal` para edição em lote), Telas (árvore via `id_parent`+`ordem`), Usuários×Perfis, Vendedores (com `id_funcionario` ainda não exposto na UI), Diligenciadores, Auxiliares de vendedor.
- **Auxiliares**: Blacklist de pedidos (PK `numero_pedido`, exige `codigo_empresa` — bug de backend documentado), Blacklist de vendedores (PK `termo`, `escopo: 'faturamento'|'vendas'|'ambos'`, usada no grupo G5 de dedução), Cargos (`nvl_permissao` + `sub_nivel` opcional de desempate, dicionário compartilhado com o Organograma via `niveis_hierarquicos`), Metas mensais, Parceiros (10.065 registros, filtros de busca com bugs confirmados), Produtos, Setores, Unidades (3 registros hoje).

## Experimental
[[AV-Hub-Simulador-Comissao|Simulador de Comissão]] — protótipo local, 100% frontend, ainda sem gravar em banco. Fica em `app/(protected)/experimental/`, não em `orcamento/`, apesar de consumir os services de Orçamento para produtos/fornecedores.

## Layout/navegação compartilhados
Menu lateral dinâmico (`Menu.tsx`) monta a árvore a partir de `telas`+permissões do usuário via `GET /api/menu`, com agrupamento visual próprio do frontend (não vindo da API): **Operações** (crm/vendas/serviços/compras/orçamento/pcp), **Gestão de Pessoas** (RH), **Configurações** (admin), mais os grupos dos três portais. `cadastros` e `fechamento` ficam deliberadamente fora de qualquer grupo; `experimental` sempre por último. Tem busca full-text (Ctrl+K), itens recentes e grupos colapsáveis persistidos em `localStorage`.

## Ver também
- [[AV-Hub-Visao-Geral]]
- [[AV-Hub-Vendas-Reconciliacao]]
- [[AV-Hub-Bugs-Catalogo]]
- [[AV-Hub-Portal-Vendedor-Plano]]
- [[Organograma-Visao-Geral]]
- [[RH-Escopo-Row-Level-Security]]
