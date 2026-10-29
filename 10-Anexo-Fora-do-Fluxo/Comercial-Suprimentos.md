---
tags: [anexo, comercial, suprimentos, api-comercial, fora-do-fluxo]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Robert (migração para a API do Hub, N16-117) · Pablo acompanha · Gustavo (banco)
fontes: [HUB b55ac55 api-comercial/ (prisma, src/modules, Dockerfile, env.ts), app/(protected)/comercial e suprimentos, app/api/comercial, v1 AV-Hub-Comercial-Suprimentos]
---

# Comercial e Suprimentos (`api-comercial`, legado de consulta)

**Em uma frase:** é o serviço de teste que o Pablo criou para propostas, clientes, ofertas de fornecedor, custos e o painel do comprador. Desde 28/10/2026 ele fica no repositório do HUB só para leitura (N16-117), e o que for útil vai para a `api-acos-vital`, conduzido pelo Robert.

**Quando consultar:** quando a dúvida é "o que o módulo do Pablo já faz?". Ele não está publicado e não será (N16-117). Ele fica fora do fluxo 0b e do MES. Também abriga o orçamento ([[12-Orcamento-Base-de-Preco]]; o anexo antigo [[Orcamento]] está arquivado). Mapa do módulo: [[Mapa-do-Modulo-do-Pablo]]. Modelo de classes: [[Classes]], diagrama 4.

Quem cuida hoje: o Robert conduz a migração das rotas para a `api-acos-vital`; o Pablo acompanha e cuida do Orçamento (com supervisão do Robert); o Gustavo revisa o banco; o Nathan faz as telas (N16-117).

> [!info] Migração para a API do hub (15/10/2026)
> O serviço `api-comercial` descrito abaixo é de teste e será absorvido pela `api-acos-vital` (N14-15). O que já existe na API do hub, o que criar e o que descartar está em [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]].

> [!info] Legado só para leitura (28/10/2026, N16-117)
> A pasta `api-comercial/` do HUB é **legado de consulta**, com `LEIA-ME-LEGADO.md`: não se roda, não se publica e não se altera, e fica fora da CI, do lint e do `tsc`. O front fala só com a API do Hub. O que vale portar está em [[Mapa-do-Modulo-do-Pablo]].

> [!info] Proposta e Orçamento no fluxo (26/10/2026)
> A proposta (`V0`) e o Orçamento (`B1` a `B4`) entraram no [[00-Fluxo-Mestre-0b]] (N16-01, N16-07; N14-02 ajustada). O desenho aprovado muda o ciclo da proposta do módulo (sem fechamento parcial, cancelada no lugar de perdida, pedido criado pelo Hub). Os contratos dessa parte foram removidos em 29/10/2026, e o Robert cria os novos.

## O que existe

- ✅ O serviço está dentro do repositório do HUB, com banco no schema `core_comercial`.
- ✅ Tem propostas, clientes, custos, suprimentos, cadastros, relatórios, dashboards, notificações e integração com o Omie (lê pedidos de compra).
- ✅ O acesso é pela chave do HUB mais o login do usuário; o perfil comercial fica em `UsuarioComercial`.
- ✅ Telas em `comercial/` (propostas, clientes, relatórios) e `suprimentos/` (painel do comprador, pedido de cotação, ofertas, histórico de compras, fornecedores, catálogo, pesquisa de materiais, parâmetros de custo, tabela da telha, sincronização com o Omie). Há também o `dashboards/dash-comercial`.
- 📝 Não será publicado: é legado de consulta (N16-117).

## Pendências

- ✅ Decidido: o serviço não será publicado (N16-117) e o schema `core_comercial` não existirá, porque a proposta fica em `core_vendas_faturamento` (N16-116). As pendências abaixo só importam se a lógica for portada para a API do Hub.
- ❓ Token com claim de perfis: o v1 apontava como pendência; a claim não foi relida.
- ❓ Comprador detectado por nome de perfil no v1, frágil; não reconferido.
- ❓ E-mail da proposta: aceita `smtp` ou `memoria`; não se sabe se o SMTP está configurado em produção.

## Detalhe técnico

### O serviço

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
| Publicação | Não será publicada (legado de consulta); o roteiro `docs/ENVIAR - roteiro-publicacao-api-comercial.md` não vale mais | 📝 N16-117 |

### Telas do HUB

- `comercial/`: `propostas` (lista, nova, `[id]`), `clientes` (lista, novo, `[id]`), `relatorio-cotacoes`, `relatorio-gerencial`.
- `suprimentos/`: `painel-comprador`, `pedido-cotacao`, `ofertas-fornecedor`, `historico-compras`, `fornecedores` (e `[id]`), `catalogo-produtos` (e `[id]`), `pesquisa-materiais`, `parametros-custo`, `tabela-telha`, `sincronizacao-omie`.
- `dashboards/dash-comercial`.

✅ `app/(protected)/comercial/**` e `suprimentos/**`. Cadastro de cada slug em `auth.telas` de produção ❓ Gustavo (o contrato de telas `docs/ENVIAR - contrato-comercial-suprimentos-telas.md` lista os slugs; o Dump Avhub de 14/10 é só esquema).

### Pendências (detalhe)

- Publicar o serviço e decidir o cluster do `core_comercial`: **encerrado** pelas N16-116 e N16-117 (não será publicado e o schema não existirá).
- Token com claim de perfis ❓: a v1 apontava como pendência; o `api-comercial` hoje identifica o usuário em `UsuarioComercial`, mas a claim não foi relida.
- Comprador detectado por nome de perfil no v1 (`/compr|suprimento/i`), frágil ❓ não reconferido.
- E-mail da proposta: `EMAIL_TRANSPORTE` aceita `smtp` ou `memoria` (padrão `smtp`) ✅ `env.ts:54`; se o SMTP está configurado em produção ❓.
