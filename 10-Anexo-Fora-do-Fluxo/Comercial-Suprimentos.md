---
tags: [anexo, comercial, suprimentos, api-comercial, fora-do-fluxo]
criado: 2026-10-14
atualizado: 2026-10-19
status: vigente
dono: Pablo
fontes: [HUB 9c280c7 (develop de 19/10/2026) api-comercial/ (prisma, src/modules, src/domain/simulador, Dockerfile, env.ts), app/(protected)/vendas, orcamento e compras, app/api/comercial, next.config.ts, PRs #211 a #216 e #219]
---

# Comercial e Suprimentos (`api-comercial`)

Fora do fluxo 0b e do MES. É o segundo backend do HUB: propostas, clientes, ofertas de fornecedor, custos, painel do comprador, Simulador de Orçamento e a análise de margem da proposta. Dono: Pablo (código e publicação); ambiente e schema: Nathan e Gustavo. Modelo de classes: [[Classes]], diagrama 4.

> [!info] Migração para a API do hub
> O serviço `api-comercial` descrito abaixo é de teste e será absorvido pela `api-acos-vital` (N14-15). O que já existe na API do hub, o que criar e o que descartar está em [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]].

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
| BFF | `app/api/comercial/[...rota]/route.ts` com lista de rota, método, tela e ação | ✅ |
| Publicação | Sem ambiente de produção decidido; roteiro em `docs/ENVIAR - roteiro-publicacao-api-comercial.md` | 🔴 Pablo, Nathan |

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

- **Escopo `vinculados`** (RS-021): a regra está definida na Q3 do [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] (os vendedores do próprio usuário, os titulares que ele auxilia e os que diligencia) 📝. Falta implementar: o `api-comercial` não guarda os vendedores do Omie de cada usuário, e aplicar a regra muda o que a auxiliar vê hoje 🔴 Pablo (implementação), Nathan (aceite).
- Publicar o serviço, decidir cluster do schema `core_comercial` e se a migração roda no Dockerfile ou antes 🔴 Pablo e Nathan.
- Proposta de Orçamento (a tela da proposta com as condições e os itens do simulador) e a emissão só pela auxiliar: não começadas 🔴 Pablo.
- E-mail da proposta: `EMAIL_TRANSPORTE` aceita `smtp` ou `memoria` (padrão `smtp`) ✅ `env.ts`; se o SMTP está configurado em produção ❓.
