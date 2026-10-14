---
tags: [anexo, comercial, suprimentos, api-comercial, fora-do-fluxo]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Pablo
fontes: [HUB b55ac55 api-comercial/ (prisma, src/modules, Dockerfile, env.ts), app/(protected)/comercial e suprimentos, app/api/comercial, v1 AV-Hub-Comercial-Suprimentos]
---

# Comercial e Suprimentos (`api-comercial`)

Fora do fluxo 0b e do MES. É o segundo backend do HUB: propostas, clientes, ofertas de fornecedor, custos, painel do comprador e o orçamento ([[Orcamento]]). Dono: Pablo (código e publicação); ambiente e schema: Nathan e Gustavo. Modelo de classes: [[Classes]], diagrama 4.

## O serviço

| Item | Estado | Selo |
|---|---|---|
| Onde está | Pasta `api-comercial/` dentro do repositório do HUB | ✅ |
| Stack | Node 22 (`FROM node:22-slim`), Express 5, Prisma, schema `core_comercial`, porta 3001 (`PORT` padrão em `src/config/env.ts:12`) | ✅ `api-comercial/Dockerfile:2`, `env.ts:12` |
| Migrations | 13 em `prisma/migrations`, de `20261001000000_mvp_inicial` a `20261013140000_usuarios_comerciais_diretorio` | ✅ |
| Módulos | `propostas`, `clientes`, `custos`, `suprimentos`, `cadastros`, `relatorios`, `dashboards`, `notificacoes`, `omie` | ✅ `src/modules/*` |
| Rotas de proposta | `GET /`, `/resumo`, `/:id`, `POST /`, `/calcular`, `/itens/importar`, `PUT /:id`, `POST /:id/perder`, `/reabrir`, `/fechar`, `/duplicar`, `GET /:id/eventos`, `/versoes`, `PUT /:id/pedido_omie` | ✅ `propostas.routes.ts:17-160` |
| Omie | `POST /omie/sincronizar`, `GET /omie/sincronizacoes`; sincroniza produtos e fornecedores do hub e lê pedidos de compra por conta | ✅ `omie.routes.ts:27,55` |
| Acesso | `x-api-key` mais Bearer do hub; perfil comercial em `UsuarioComercial` (tabela `perfis_comerciais`, sem coluna de cargo) | ✅ `lib/api/comercialApi.ts`; `empresas.prisma:61-78` |
| BFF | `app/api/comercial/[...rota]/route.ts` com lista de rota, método, tela e ação (por exemplo `GET /dashboards/comercial` exige `dash-comercial`) | ✅ `route.ts:59` |
| Publicação | Sem ambiente de produção decidido; roteiro em `docs/ENVIAR - roteiro-publicacao-api-comercial.md` | 🔴 Pablo, Nathan |

## Telas do HUB

- `comercial/`: `propostas` (lista, nova, `[id]`), `clientes` (lista, novo, `[id]`), `relatorio-cotacoes`, `relatorio-gerencial`.
- `suprimentos/`: `painel-comprador`, `pedido-cotacao`, `ofertas-fornecedor`, `historico-compras`, `fornecedores` (e `[id]`), `catalogo-produtos` (e `[id]`), `pesquisa-materiais`, `parametros-custo`, `tabela-telha`, `sincronizacao-omie`.
- `dashboards/dash-comercial`.

✅ `app/(protected)/comercial/**` e `suprimentos/**`. Cadastro de cada slug em `auth.telas` de produção ❓ Gustavo (o contrato de telas `docs/ENVIAR - contrato-comercial-suprimentos-telas.md` lista os slugs; o Dump Avhub de 14/10 é só esquema).

## Pendências

- Publicar o serviço, decidir cluster do schema `core_comercial` (o dump do av-hub não o traz) e se a migração roda no Dockerfile ou antes 🔴 Pablo e Nathan.
- Token com claim de perfis ❓: a v1 apontava como pendência; o `api-comercial` hoje identifica o usuário em `UsuarioComercial`, mas a claim não foi relida.
- Comprador detectado por nome de perfil no v1 (`/compr|suprimento/i`), frágil ❓ não reconferido.
- E-mail da proposta: `EMAIL_TRANSPORTE` aceita `smtp` ou `memoria` (padrão `smtp`) ✅ `env.ts:54`; se o SMTP está configurado em produção ❓.
