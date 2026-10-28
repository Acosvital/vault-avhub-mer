---
tags: [anexo, comercial, suprimentos, api-comercial, fora-do-fluxo]
criado: 2026-10-14
atualizado: 2026-10-27
status: vigente
dono: Pablo
fontes: [HUB fd81624 (develop de 20/10/2026) api-comercial/ (prisma, src/modules, src/domain/simulador, Dockerfile, env.ts), app/(protected)/vendas, orcamento e compras, components/Propostas/PropostaForm, lib/comercial/AprovacaoPropostaPdf.tsx, app/api/comercial, next.config.ts, PRs #211 a #216, #219 a #222 e #225, PR #226 (aberto), api-acos-vital 38d2f74]
---

# Comercial e Suprimentos (`api-comercial`)

Fora do fluxo 0b e do MES. É o segundo backend do HUB: propostas, clientes, ofertas de fornecedor, custos, painel do comprador, Simulador de Orçamento, a análise de margem da proposta e o orçamento ([[12-Orcamento-Base-de-Preco]]; o anexo antigo [[Orcamento]] está arquivado). Dono: Pablo (código; o serviço não será publicado, N16-15); ambiente e schema: Nathan e Gustavo. Modelo de classes: [[Classes]], diagrama 4.

> [!info] Migração para a API do hub
> O serviço `api-comercial` descrito abaixo é de teste e será absorvido pela `api-acos-vital` (N14-15). O que já existe na API do hub, o que criar e o que descartar está em [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]]. 📝 N16-15: continua só de teste e não será publicado. A fase 1 já existe: o schema no banco (migration `052`, em produção desde 20/10) e a base do módulo na API (`38d2f74`, Gustavo).

> [!info] Proposta e Orçamento no fluxo (26/10/2026)
> A proposta (`V0`) e o Orçamento (`B1` a `B4`) entraram no [[00-Fluxo-Mestre-0b]] (N16-01, N16-07; N14-02 ajustada). O desenho aprovado muda o ciclo da proposta do módulo (sem fechamento parcial, cancelada no lugar de perdida, pedido criado pelo Hub) e está nos contratos [[SQL-016-Schema-core_comercial-Proposta-e-Pedido-de-Venda]], [[SQL-017-Orcamento-em-core_comercial-Base-de-Preco-e-Pedido-de-Custo]], [[API-019-Proposta-e-Pedido-de-Venda-na-API-do-Hub]] e [[API-020-Orcamento-Base-de-Preco-e-Pedido-de-Custo]]; a análise do Pablo, com o que porta, o que troca e o que sai, está em [[PS-035-Modulo-do-Pablo-x-Desenho-de-26-10]] 🟡. Mapa do módulo: [[Mapa-do-Modulo-do-Pablo]].

## O serviço

| Item | Estado | Selo |
|---|---|---|
| Onde está | Pasta `api-comercial/` dentro do repositório do HUB | ✅ |
| Stack | Node 22 (`FROM node:22-slim`), Express 5, Prisma, schema `core_comercial`, porta 3001 (`PORT` padrão em `src/config/env.ts:12`) | ✅ `api-comercial/Dockerfile:2`, `env.ts:12` |
| Migrations | 14 em `prisma/migrations`, de `20261001000000_mvp_inicial` a `20261016120000_analise_simulador_proposta` | ✅ |
| Módulos | `propostas`, `clientes`, `custos`, `suprimentos`, `cadastros`, `relatorios`, `dashboards`, `notificacoes`, `omie`, `simulador` | ✅ `src/modules/*` |
| Rotas de proposta | `GET /`, `/resumo`, `/:id`, `POST /`, `/calcular`, `/itens/importar`, `PUT /:id`, `POST /:id/perder`, `/reabrir`, `/fechar`, `/duplicar`, `GET /:id/eventos`, `/versoes`, `PUT /:id/pedido_omie` | ✅ `propostas.routes.ts` |
| Omie | `POST /omie/sincronizar`, `GET /omie/sincronizacoes`; sincroniza produtos e fornecedores do hub e lê pedidos de compra por conta | ✅ `omie.routes.ts` |
| Acesso | `x-api-key` mais Bearer do hub. Perfis e telas vêm do `GET /me/permissoes` do hub a cada requisição (cache de 15 s), sem claim no token e sem cadastro paralelo; `UsuarioComercial` (tabela `perfis_comerciais`) é só o diretório de nomes | ✅ `src/lib/perfisHub.ts`, `src/middlewares/autenticacao.ts` |
| Escopo de vendedores | `proprios` restringe ao responsável; `todos` vê tudo; **`vinculados` ainda não restringe nada** (ver Pendências). O filtro `?responsavel=` soma ao escopo e não o substitui mais | ✅ `propostas.service.ts` (`whereEscopo`), `clientes.routes.ts` (`restricaoCarteira`), PR #219 |
| Motor do Simulador de Comissões | Cópia de `lib/simulador/motor.ts` em `src/domain/simulador/`, sem mudança de fórmula, com 47 testes e um teste de paridade que falha se as duas cópias divergirem. Vive até a migração do LOG-52 | ✅ PR #215, `test/unit/simulador-motor.test.ts` |
| Análise da proposta | Ao salvar e no `POST /calcular`, o motor calcula custo líquido, preço sugerido, margem e letra com os parâmetros do simulador da unidade (lidos do hub) e grava na proposta. A proposta salva mesmo sem análise e a resposta lista o que falta (`analise_pendencias`). A comissão prevista é gravada e não é devolvida | ✅ PR #215, `src/modules/propostas/analise.ts` |
| Análise na tela da proposta | Para quem vê custo: seção "Análise de margem" (destino pré-selecionado pela UF do cliente, condição da tabela de encargos, frete na compra e DIFAL) e, em cada item, o lado da compra com custo líquido, preço sugerido (botão "usar"), margem e letra ou o selo FAB. As listas vêm de `GET /propostas/parametros_analise` (só as chaves das tabelas) | ✅ PR #220 |
| "Sugerir custos" | Com as origens da vigência, `POST /custos/sugerir` devolve também o lado da compra da oferta escolhida (preço, quantidade e unidade comprada, origem, IPI e ST), pela mesma decomposição do Simulador de Comissões (`ladoCompra.ts`), e a tela preenche os itens de revenda | ✅ PR #221 |
| Fórmula antiga de preço (RN-020) | Com a análise disponível, sai da tela (custo, kg/m, metragem, margem % e margem real); item ainda na fórmula mostra "Fixar preço". O servidor continua aplicando a fórmula onde ela está preenchida (telha, propostas antigas, carga do ERP antigo) | ✅ PR #222 |
| PDF de aprovação interna | Proposta com análise: custo líquido com o resumo da compra, preço praticado e sugerido, margem e letra (ou FAB) por item; no topo, custo líquido, margem líquida do pedido com a letra e itens no prejuízo. Proposta sem análise: o formato antigo. A comissão não sai | ✅ PR #225 |
| BFF | `app/api/comercial/[...rota]/route.ts` com lista de rota, método, tela e ação | ✅ |
| Contrato OpenAPI | Gerado dos schemas zod e conferido contra as rotas por teste (95 operações em 81 caminhos) | 🟡 PR #226 aberto |
| Publicação | Não será publicado; o roteiro `docs/ENVIAR - roteiro-publicacao-api-comercial.md` fica sem uso | 📝 N16-15 |

## Telas do HUB

A URL é a cadeia de slugs do `auth.telas`; as telas seguem a distribuição feita no menu (Vendas, Orçamento e Compras).

| Menu | Telas (pasta em `app/(protected)/`) |
|---|---|
| **Vendas** (`vendas/`) | `propostas` (lista, nova, `[id]`), `clientes` (lista, novo, `[id]`), `relatorio-cotacoes`, `relatorio-gerencial` |
| **Orçamento** (`orcamento/`) | `simulador-orcamento`, `painel-comprador`, `pedido-cotacao`, `ofertas-fornecedor`, `fornecedores` (e `[id]`), `catalogo-produtos` (e `[id]`), `pesquisa-materiais`, `parametros-custo`, `tabela-telha`, `sincronizacao-omie`; mais `custo-itens` (BL-023, Nathan) |
| **Compras** (`compras/`) | `historico-compras` |
| Dashboards | `dashboards/dash-comercial` |

✅ PRs #212 e #216. Os endereços antigos (`/comercial/...`, `/orcamento/propostas`, `/suprimentos/...`, `/custo-itens`) redirecionam com 307 para os novos (`next.config.ts`). O módulo de Orçamento antigo (telas, BFF `/api/orcamento` e os JSON de `lib/orcamento/data/`) saiu do HUB ✅ PR #211 (`c851cda`).

`simulador-orcamento` precisa da linha em `auth.telas` debaixo de `orcamento` 🔴 Gustavo (contrato de telas, §3.6). Cadastro dos demais slugs em produção ❓ Gustavo.

## Pendências

- **Escopo `vinculados`** (RS-021): a regra está definida na Q3 do [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] (os vendedores do próprio usuário, os titulares que ele auxilia e os que diligencia) 📝. Falta implementar: o `api-comercial` não guarda os vendedores do Omie de cada usuário, e aplicar a regra muda o que a auxiliar vê hoje 🔴 Pablo (implementação, já na migração da fase 3, não no `api-comercial`), Nathan (aceite).
- **Emissão só pela auxiliar** (fase 5 da Proposta de Orçamento): rascunho sem número até a auxiliar emitir. 📝 O vendedor pode tirar uma prévia do PDF marcada como rascunho. 🔴 Comercial: a revisão de uma proposta emitida volta para a auxiliar? Item no prejuízo bloqueia a emissão ou só avisa? Pablo (implementação). 🟡 Com o desenho de 26/10 a auxiliar tem o mesmo escopo do vendedor e não há emissão separada: proposta de arquivar ([[PS-035-Modulo-do-Pablo-x-Desenho-de-26-10]] §4).
- **Relatório Gerencial com a margem líquida** (fase 6): misturar a margem bruta das propostas antigas com a líquida das novas na mesma média distorce o número 🔴 gestão comercial (decisão), Pablo (implementação). 🟡 Com a comissão nova a margem vem de `core_comissao`; proposta em [[PS-035-Modulo-do-Pablo-x-Desenho-de-26-10]] §4.
- E-mail da proposta: `EMAIL_TRANSPORTE` aceita `smtp` ou `memoria` (padrão `smtp`) ✅ `env.ts`; se o SMTP está configurado em produção ❓.
