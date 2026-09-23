# Contrato — Ordenação em outras listagens (além de /vendedores)

**Criado em:** 15/09/2026, horário de Brasília

**Objetivo:** depois de confirmar que `GET /vendedores?sort=<coluna>&order=asc|desc`
já funciona de verdade (ver [`contrato-ordenacao-vendedores.md`](./implementados/OK%20-%20contrato-ordenacao-vendedores.md),
resolvido) e migrar a tela de Vendedores pra usar ordenação real do servidor,
levantei todas as outras telas paginadas do Hub que também não têm ordenação
hoje. Este contrato pede o mesmo padrão (`sort`/`order`) nos endpoints abaixo —
mesma convenção, sem inventar uma nova por tela.

Não testei ao vivo se algum desses endpoints já aceita `sort`/`order` por
coincidência (só confirmei isso pra `/vendedores` no contrato anterior) — vale
reconferir por código ou ao vivo antes de assumir que algum já funciona.

---

## 1. Prioridade alta (volume grande — falta de ordenação já incomoda hoje)

| Tela | Endpoint | Linhas (aprox.) | Colunas candidatas a ordenar |
|---|---|---|---|
| Cadastros → Auxiliares → Parceiros | `GET /parceiros` | ~10.065 | `nome_fantasia`, `cidade`, `uf` |
| Vendas → Pedidos de Venda | `GET /pedidos_vendas` | ~8.095 | `data_inclusao`, `cliente`, `vendedor`, `valor_total`, `situacao` |
| Vendas → Notas Fiscais de Saída | `GET /nota_fiscal_saida` | ~4.359 | `data`, `numero_nf`, `cliente`, `vendedor`, `valor_total` |
| Pedidos da Equipe / Pedidos PCP / Meus Pedidos | `GET /vendas_planilha` | Não medido — pelo menos ~12 mil só pra 1 vendedor num endpoint irmão (`/vendas_base`), e a variante "empresa inteira" (Pedidos da Equipe) não filtra vendedor | `cliente`, `valor_total`, `data_inclusao` |
| Notas da Equipe / Notas PCP / Minhas Notas | `GET /faturamento_planilha` | Mesma ordem de grandeza do item acima | `cliente`, `valor_total`, `data_emissao` |

`/vendas_planilha` e `/faturamento_planilha` alimentam **3-4 telas cada** (a
mesma chamada, só variando o filtro de vendedor/escopo) — uma mudança no
endpoint resolve todas de uma vez, não precisa de 4 contratos separados.

## 2. Prioridade baixa (listas pequenas — ordenação é conveniência, não urgência)

| Tela | Endpoint | Linhas (aprox.) |
|---|---|---|
| RH → Cadastro de funcionários | `GET /funcionarios` | 189 |
| Cadastros → Auxiliares → Cadastro de cargos | `GET /cargos` | ~118 |
| Cadastros → Acessos → Usuários | `GET /usuarios` | não medido |
| Cadastros → Acessos → Usuários × Perfis | `GET /usuarios_perfis` | não medido |
| Cadastros → Acessos → Perfis | `GET /perfis` | não medido, pequeno |
| Cadastros → Acessos → Permissões | `GET /permissoes` | não medido |
| Cadastros → Acessos → Telas | `GET /telas` | dezenas (a árvore do menu tem ~20 telas de topo, mais submenus) |
| Cadastros → Acessos → Diligenciadores | `GET /diligenciador_vendedor` | pequeno (1 diligenciador → N vendedores) |
| Cadastros → Acessos → Auxiliares de Vendedor | `GET /auxiliar_vendedor` | pequeno |
| Cadastros → Auxiliares → Cadastro de setores | `GET /setores` | não medido |
| Cadastros → Auxiliares → Produtos | `GET /produtos` | não medido |
| Cadastros → Auxiliares → Cadastro de metas | `GET /metas_mensais` | pequeno (1 linha por ano/mês/tipo) |
| Cadastros → Auxiliares → Blacklist de vendedores | `GET /blacklist_vendedores` | pequeno |
| Cadastros → Auxiliares → Blacklist de pedidos | `GET /blacklist_pedidos` | pequeno |

## 3. Fora do escopo deste contrato

- **Cadastros → Auxiliares → Cadastro de unidades** (`GET /unidades`) — só 3
  registros hoje. Não faz sentido pedir ordenação pra uma lista desse tamanho.
- **RH → Solicitações de Vagas** (`GET /vagas`) — 0 registros em produção na
  última conferência (04/09). Revisitar se voltar a ter dado real.
- **Orçamento** (Categorias, Fornecedores, Histórico de produtos, Sem
  Cadastro, Vínculos) — todo esse módulo ainda roda sobre JSON mockado local
  (`app/(protected)/orcamento/_data/*.json`), sem API própria. Não tem
  endpoint de verdade pra pedir ordenação ainda — isso já está registrado em
  [`contrato-fornecedores-por-produto.md`](./comissao/ENVIAR%20-%20contrato-fornecedores-por-produto.md)
  (pendência maior, de dados, não só ordenação).

## 4. O que muda no frontend quando isso existir

Pras 5 telas da seção 1 (as de maior volume), a UI ganha cabeçalho de coluna
clicável, igual ao que já existe hoje em Vendedores. Nas telas de layout em
card (Pedidos/Notas da Equipe, PCP, Meus Pedidos/Minhas Notas — não são
tabela linha/coluna) a ordenação vira um seletor "Ordenar por" em vez de
clique no cabeçalho, já que não há cabeçalho de coluna nesse layout.

**Ressalva pra Meus Pedidos/Minhas Notas:** essas duas rotas
(`app/api/meus-pedidos/route.ts`, `app/api/minhas-notas/route.ts`) já fazem
merge de várias chamadas (1 por vínculo do vendedor, pra quem tem mais de uma
empresa) e paginam esse resultado combinado em memória, hoje sempre ordenado
por data. Adicionar `sort`/`order' de verdade aí precisa de um ajuste nesse
merge no BFF também, não é só repassar o parâmetro pro backend — trabalho
adicional no frontend, à parte deste contrato.

Pras telas pequenas da seção 2, o ganho é mais sobre consistência (toda tela
paginada se comporta igual) do que sobre uma dor real de uso hoje.
