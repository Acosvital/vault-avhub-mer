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
(hoje são 52 marcas). Quando um contrato for entregue: aplicar a seção "O que muda na tela" do
contrato, apagar a marca no `av-hub` e mover o arquivo para `Realizados/03-Contratos-Logica-Fora-Backend/`.

## Prioridade: módulo de Compras

**Já entregue:** [[01-Compras-Fluxo-Completo]] (requisição → OC → régua de aprovação), backend
em 22/09/2026 (`api-acos-vital` PR #273) e front ligado em 23/09/2026. Movido para
`Realizados/03-Contratos-Logica-Fora-Backend/`. Os contratos SQL [[007-Ordens-Compra-Estruturada]]
e [[008-Requisicoes-Compra]] também já estão aplicados.

**Em aberto (importados em 23/09/2026):**

- **[[15-Compras-Pendencias-Pos-Backend]]** — o que faltou depois da entrega: nomes na OC, filtro
  por unidade, busca, resumo, limite de aprovação, envio ao Omie, `pode_aprovar` (C1–C8).
- **[[14-Compras-Omie-Pedido-Compra]]** — de-para completo com a API do Omie: puxar os pedidos de
  compra para o espelho `pedidos_compras` e enviar a OC com `UpsertPedCompra`. Conferido campo a
  campo contra a doc oficial do Omie em 23/09/2026.
- **[[16-Compradores-Funcionario]]** — cadastro de compradores por filial, ligado ao funcionário
  (resolve o `nCodCompr` do Omie).
- **[[20-Compras-Cotacao-Moeda-PTAX]]** — cotação de USD/EUR preenchida sozinha na OC: job
  diário da PTAX do Banco Central → `core.cotacoes_moeda` → `GET /cotacoes_moeda/atual`, com a
  origem da cotação (`ptax`/`manual`) gravada na OC.
- Os mesmos pedidos, separados por destinatário: [[17-Compras-Pedido-DBA-Banco]] (DBA),
  [[18-Compras-Pedido-API-Backend]] (backend) e [[19-Compras-Pedido-Pipeline-Omie]]
  (`omie-elt-pipeline`).
- Contratos de API da integração com o MES, ainda em proposta:
  [[003-Requisicao-Compra-Integracao-MES]] e [[004-Referencia-OC-Integracao-MES]].
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
| Compras (pendências depois da entrega do backend, [[15-Compras-Pendencias-Pos-Backend]]) | `app/api/compras/ordens/[id]/route.ts`, `components/Compras/{useCompras,helpers}.ts`, `lib/domain/compras-ordem.ts` |

## Fora deste ciclo (levantar antes de mexer)

Telas mais antigas (Cadastros, Comissões, Vendas, RH restante, Organograma) **não foram inventariadas**
linha a linha: elas seguem o padrão antigo (`SearchFilterBar` + paginação do servidor onde a API
suporta, ordenação ausente — ver [[08-Ordenacao-Listagens]]). Ao migrar cada uma para o padrão
novo, aplicar a mesma regra e marcar o que sobrar.

## Ver também
- [[Indice-Contratos]] — índice geral dos contratos SQL/API deste vault.
