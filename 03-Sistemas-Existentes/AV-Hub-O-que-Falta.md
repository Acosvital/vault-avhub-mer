---
tipo: plano
criado: 2026-10-09
atualizado: 2026-10-09
---

# AV-Hub: o que falta para concluir

> Status: decidido (Nathan, até 09/10/2026) | no código (av-hub `develop` `a402d78`, `api-acos-vital` `dee35b0`) | em produção: **não verificado**. Reúne o que o vault e o código dizem estar pendente no **AV-Hub** (front e BFF). Não é um compromisso de prazo. Legenda: ✅ feito, 🟡 proposta ou parcial, 🔴 pendente.

## Onde estamos
O AV-Hub tem os módulos de **pedidos e notas** (portais do vendedor, da equipe e do PCP), **Compras**, **Comercial e Suprimentos**, **Cadastros e RH**, **Comissões**, **Dashboards**, **Fechamento**, **Orçamento** (legado) e o **Simulador** (experimental). A base de vendas e de Compras está entregue. Falta fechar pontas, **publicar o Comercial e Suprimentos**, endurecer a segurança e fazer a Torre de Fluxo.

Já feito nesta rodada: limpeza de código morto e ponteiros das marcas (av-hub #176), correções do BFF de nota manual, follow-up CCP, link de "Atrasados" e rotas do Comercial (#177), cartão "Etapa dos itens" (#172) e a lista de rotas para o Bearer ([[Mapa-Rotas-BFF-API-para-Bearer]]).

## O que falta, por módulo
| Módulo | Falta | Status | Depende de |
|---|---|---|---|
| **Pedidos e notas** | Testar o cartão "Etapa dos itens" ponta a ponta (migration `api005`); `quantidade_na_etapa` tipado `number`, a API pode mandar `null`. Tela de **pedidos de venda manuais** (a API existe, a tela não; [[45-Pedido-de-Venda-Manual]]). Itens do plano do Portal do Vendedor ainda não feitos: estados vazios e de erro, badge de SLA crítico no menu, comparação com o mês anterior, "próximos vencimentos", top clientes, copiar número com um clique, "dados atualizados às HH:MM" ([[AV-Hub-Portal-Vendedor-Plano]]) | 🔴 | Nathan (tela manual); Gustavo (migration) |
| **Compras** | A base está entregue ([[AV-Hub-Modulos]]). Falta: ter o aprovador de fato (o perfil Gerência de Compras tinha 0 usuários no dump de 07/10); vincular os compradores ativos que ainda estão sem vínculo; envio da OC ao Omie em produção (código pronto, falta deploy da API com o contrato 36); campos `itens_recebidos` e `itens_parciais` do dashboard, que a API não manda; rateio por departamento (contrato 01) | 🟡 | Nathan (nomes); Gustavo (deploy) |
| **Comercial e Suprimentos** | O `api-comercial` está **só em `develop` e não foi publicado**; ambiente ainda sem decisão; 20 dos 22 slugs de tela sem cadastro em `auth.telas`; falta a claim `perfis` no token; nada carrega os `PerfilComercial` fora dos seeds; o auxiliar não consegue salvar proposta (o schema exige preço); o token não confere `typ` e `ver`; rate limit compartilhado por IP. Sem isso o módulo dá 403 para todos ([[AV-Hub-Comercial-Suprimentos]]) | 🔴 | Nathan e Gustavo |
| **Cadastros, RH e acesso** | CRUD de produtos (o BFF só tem `GET`; decidir se o hub cria e exclui produto). "Novo parceiro" e "novo produto" nunca funcionam (falta `codigo_empresa`). Troca da própria senha. Login Azure: usuário desativado não é derrubado e o `signIn` falho não bloqueia. Token de 15 minutos sem renovação. 28 BFFs que engolem erros como 500. Tela de permissões que corta em 200 linhas (tinha 194). Select de unidade editável em cargos e setores. Telas de negócio que levam 403 em unidades, setores e cargos por causa do gate da tela | 🔴 | Front, em boa parte sozinho |
| **Comissões e dashboards** | Coordenadores ainda em JSON do repositório; a API já tem `GET /dashboard/comissoes` ([[42-Coordenadores-e-Orcamento-sair-do-JSON-do-Repositorio]]). O simulador é protótipo local sem gravar em banco, e o backend já tem schema para persistir ([[AV-Hub-Comissao-Modulo]]). "Minhas comissões" sem escopo de sessão. Filtro de empresa do ritmo de meta sem efeito. `metas-mensais` pode dar 403 por `pode_editar` contra `pode_criar`. Fechamento manual sem `created_by` | 🔴 | Gustavo (contratos); Nathan (escopo) |
| **Orçamento legado** | Remover telas, rotas, `lib/orcamento` e os JSONs quando o módulo novo o substituir. A data de corte é decisão sua. O simulador e o cadastro de produtos ainda dependem dele | 🔴 | Nathan |
| **Segurança transversal** | Bearer nos helpers do BFF (✅ feito e mergeado no PR #178 de 09/10, ativo no código; eram 64 handlers só com `x-api-key`); fixar `ESCOPO_VENDEDORES_EXIGIR`; rate limit do login ([[41-Login-Rate-Limit-no-Backend]]); política do bucket ([[44-Upload-de-Fotos-Politica-de-Bucket]]); escopo e permissão pelo token ([[40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]]) | 🔴 | Gustavo mapear as rotas primeiro |
| **Torre de Fluxo (S5)** | 4 telas e o BFF (I5 e I6, 11 pd), de 26/11 a 18/12. Hoje só existe o protótipo. Depende do módulo `fluxo` do MES (Robert) ([[Cronograma-2-Meses]]) | 🔴 | Robert |
| **Limpeza** | 10 marcas `GAMBIARRA(` restantes no código do front: 2 de comissões (**fora de escopo**, em desenvolvimento), 2 do orçamento, 5 do escopo de vendedores e 1 do login; mais uma sem marcação (`minhas-comissões`, também fora de escopo). A do upload foi reclassificada como defesa em profundidade ([[44-Upload-de-Fotos-Politica-de-Bucket]]). Somem à medida que saem os contratos 40 e 41 e a decisão do orçamento | 🟡 | Contratos acima |

## Ordem sugerida
1. **Publicar o Comercial e Suprimentos** (ambiente, telas, perfis, claim). É o que mais bloqueia funcionalidade inteira.
2. **Correções do front que não dependem de ninguém**: cadastros, autenticação, tratamento de erros, paginação das permissões.
3. **Bearer e escopo**, depois que o Gustavo mapear as rotas e confirmar o escopo dos perfis (20 dos 21 perfis são `vinculados`).
4. **Telas que sobram**: pedidos manuais e os itens do plano do portal.
5. **Torre de Fluxo**, por último, porque depende do MES.

## Antes de chamar de pronto
Nada disto foi exercitado em produção. Faltam: testar na `api-test` com um usuário de cada perfil (admin, gerente, vendedor, PCP, comprador), aplicar as migrations e subir em ordem (banco, API, BFF) e conferir o `e2e`.

## Fontes
[[Auditoria-Pente-Fino-2026-10-08]] · [[Registro-de-Decisoes-2026-10-07]] · [[AV-Hub-Modulos]] · [[AV-Hub-Portal-Vendedor-Plano]] · [[AV-Hub-Comercial-Suprimentos]] · [[Mapa-Rotas-BFF-API-para-Bearer]] · [[Cronograma-2-Meses]]