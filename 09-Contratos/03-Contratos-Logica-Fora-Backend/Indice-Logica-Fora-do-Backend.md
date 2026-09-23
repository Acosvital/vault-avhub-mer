---
tags: [contrato-logica, av-hub, indice]
origem: "av-hub docs/ (arquivos marcados ENVIAR)"
importado: 2026-09-23
---

# Índice — lógica que ainda está fora do banco (gambiarras marcadas no av-hub)

**Criado em:** 20/09/2026, no repositório `av-hub`. **Importado para este vault em 23/09/2026** —
só os contratos marcados `ENVIAR` (ainda pendentes) foram trazidos; os já resolvidos (`OK -`)
continuam só no repositório `av-hub`, pasta `docs/implementados/`.

**Regra do projeto:** filtro, busca, ordenação, paginação, agregação, regra de negócio e
**permissão/escopo** pertencem ao banco/API. O navegador só exibe; o BFF só encaminha a identidade.

Enquanto o backend não entrega, o que estiver fora do lugar fica **marcado no código** assim:

```ts
// GAMBIARRA(docs/ENVIAR - contrato-….md): o que é e como o backend resolve (código do item)
```

Para listar tudo no repositório `av-hub`: `grep -rn "GAMBIARRA(" app components lib services utils hooks`
(hoje são 46 marcas). Quando um contrato for entregue: aplicar a seção "O que muda na tela" do
contrato, apagar a marca no `av-hub` e marcar aqui o arquivo correspondente como `aplicada`.

## Prioridade: módulo de Compras

- **[[01-Compras-Fluxo-Completo]]** — requisição (MES) → Ordem de Compra → sincronização com o Omie.
  Greenfield: hoje não existe nenhum endpoint no backend, a tela roda toda sobre dados de exemplo.
  Depende do contrato SQL [[007-Ordens-Compra-Estruturada]] e [[008-Requisicoes-Compra]] (pasta
  `01-Contratos-SQL-DBA/`) e dos contratos de API [[003-Requisicao-Compra-Integracao-MES]] e
  [[004-Referencia-OC-Integracao-MES]] (pasta `02-Contratos-API/`).
- **[[13-Fornecedores-por-Produto]]** — fornecedor por produto (relacionado a Compras/Comissão).

## Contratos abertos criados no ciclo de 20/09/2026

| Contrato | Cobre | Itens |
|---|---|---|
| [[02-Funcionarios-Listagem-Filtros-Ordenacao-Resumo]] | Funcionários: busca/filtros/ordenação/paginação/resumo, situação e pendências no banco, projeção de campos | F1–F7 |
| [[03-Funcionarios-Cadastro-Organograma-Transacional]] | Salvar/excluir funcionário com o organograma numa transação; ciclo validado no backend | — |
| [[04-Vagas-Fila-Decisao-no-Banco]] | Solicitações de vagas: filtros/ordem/resumo, custo gerado, decisão com `pode_decidir` e histórico | V1–V8 |
| [[05-Pedidos-Notas-Dashboards-Agregacao-no-Banco]] | Pedidos, Notas e Dashboards: agrupamento por pedido, prazo, blacklist, indicadores e agregados no banco | P1–P8, N1–N3, D1–D3 |
| [[06-Permissoes-e-Escopo-no-Banco]] | Identidade propagada, permissão por ação, escopos, perfis como dado, auditoria, rate limit | S1–S11 |
| [[07-Dados-Orcamento-e-Coordenadores-no-Banco]] | Orçamento e coordenadores fora do repositório, com filtro/paginação/ordem no servidor | O1–O5, C1–C3 |

## Contratos anteriores que continuam abertos e se relacionam

- [[08-Ordenacao-Listagens]] — `sort/order` nas demais listagens (agora inclui `/funcionarios` e `/vagas`, ver os contratos acima).
- [[09-Paginacao-por-Pedido-Vendas-Planilha]] — paginar por pedido.
- [[10-Chave-Composta-Blacklist-Pedidos]] — blacklist por chave composta.
- [[11-Itens-por-Parcela-Pedidos]] — itens por parcela.
- [[12-Ordenacao-Sistema-Vendedores]] — ordenação em Vendedores.

## Onde estão as marcas, por assunto (no repositório `av-hub`)

| Assunto | Arquivos com `GAMBIARRA(` |
|---|---|
| Funcionários (lista, resumo, regras) | `components/Funcionarios/{useFuncionarios,helpers,acoes,FuncionarioPainel}` |
| Funcionários (organograma) | `services/rh/organogramaNodes.ts` |
| Funcionários (BFF) | `app/api/funcionarios/route.ts`, `app/api/funcionarios/[id]/route.ts` |
| Vagas | `components/Vagas/{useVagas,helpers,acoes,VagaPainel,VagasLista}` |
| Pedidos | `components/Pedidos/{usePedidos,PedidoDetalhe}`, `utils/etapasFluxo.ts` |
| Notas | `components/Notas/{useNotas,helpers}` |
| Dashboards | `components/Painel/{usePainelPcp,PainelPartes}`, `lib/api/{meuDashboardDomain,dashboardEquipeDomain}.ts` |
| Permissão e escopo | `lib/api/{requirePermission,escopoUnidade,portalPcp}.ts`, `hooks/usePermission.ts`, `app/(protected)/page.tsx`, `app/api/auth/[...nextauth]/route.ts` |
| Segurança de borda | `lib/auth/loginRateLimiter.ts`, `lib/s3/fotos.ts` |
| Dados em arquivo | `lib/orcamento/dados.ts`, `lib/comissoes/coordenadores.ts`, `app/(protected)/dashboards/dash-comissoes/page.tsx` |
| Compras (módulo inteiro, greenfield) | `lib/compras/dados.ts`, `app/api/compras/{requisicoes,ordens,fornecedores,transportadoras}/**`, `components/Compras/{useCompras,acoes}.ts`, `components/Compras/Kanban/**` (inclui `POST /compras/requisicoes` — criação manual, `POST /compras/ordens` sem requisição de origem, `PATCH /compras/requisicoes/{id}` — transição de status via kanban da aba "Visão geral", e `GET /compras/transportadoras` — transportadora é projeção de `core.parceiros`, igual fornecedor) |

## Fora deste ciclo (levantar antes de mexer)

Telas mais antigas (Cadastros, Comissões, Vendas, RH restante, Organograma) **não foram inventariadas**
linha a linha: elas seguem o padrão antigo (`SearchFilterBar` + paginação do servidor onde a API
suporta, ordenação ausente — ver [[08-Ordenacao-Listagens]]). Ao migrar cada uma para o padrão
novo, aplicar a mesma regra e marcar o que sobrar.

## Ver também
- [[Indice-Contratos]] — índice geral dos contratos SQL/API deste vault.
