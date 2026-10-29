---
tags: [sistemas, av-hub, hub, nextjs, frontend, bff]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [av-hub 758d5f0 (develop, 29/10; repositório `av-hub`, antes `00 - HUB`), api-acos-vital 0384e89, v1 AV-Hub-Arquitetura-BFF, AV-Hub-Modulos, AV-Hub-RBAC]
---

# AV-Hub Front (HUB)

**Em uma frase:** é o site do av-hub, com os portais do Vendedor, do Gerente, de Compras, do PCP (só leitura), de Comissões e de RH, mais Propostas e Orçamento. Dono: Nathan; as telas de Propostas são do Robert e as de Orçamento do Pablo com o Robert.

## Quem usa e para quê

- **Vendedor e auxiliar:** liberam pedidos e acompanham a etapa de cada item.
- **Gerente:** libera e acompanha os pedidos da equipe.
- **Compras:** criam requisição, cotam, emitem a OC (ordem de compra) e fazem o follow-up do CCP.
- **Gerência de Compras:** aprova a OC acima do limite.
- **PCP:** consulta pedidos e notas, sem alterar.

## Como se encaixa no fluxo

- **Vendas (`V1` a `V3`):** a tela Liberar Pedidos é o portão do fluxo.
- **Acompanhamento (`V1` a `O2`):** o card "Etapa dos itens" mostra onde cada item está na fábrica.
- **Compras (`C0` a `C5`):** requisição, cotação, aprovação, OC e follow-up.
- **Torre de Fluxo e custo por item:** as telas existem desde 15/10 (`/torre-fluxo` e `/orcamento/custo-itens`) sobre a API ([[AV-Hub-API]]). Elas só mostram dado quando o MES publicar (a Torre ainda não; o custo já está na `develop` do MES).

## Regras que valem

- O navegador só fala com o servidor do próprio site, que repassa à API.
- O servidor confere a permissão antes de chamar a API. O menu da sessão só serve de apresentação.
- Quem age (autor, aprovador) vem da sessão, nunca de um campo do formulário.
- O front não deve guardar regra de negócio. Onde ainda há, o código leva a marca `GAMBIARRA(` (9 ocorrências em 8 arquivos, 29/10).
- A "Nova requisição" do Compras não gera marco no MES. O MES a vê pela referência da requisição (API-009) e depois pela OC.
- Aprovar OC exige a permissão de aprovar. Até R$ 30 mil a OC sai liberada sem aprovação (N14-21).

## O que já existe e o que falta

- ✅ Liberação (vendedor e equipe), requisições, cotação, aprovação, OC, follow-up e compradores.
- ✅ Card "Etapa dos itens" com rótulo para as 11 etapas.
- ✅ Tela da Torre de Fluxo (LOG-46, BL-022, 15/10): mapa por setor, lista, trilha do item, tempo e ranking. Sem o feed do MES a tela mostra "indisponível" (fixtures só em desenvolvimento).
- ✅ Tela de custo real por item com simulador, sem imposto (LOG-47, BL-023, 15/10), em `/orcamento/custo-itens`.
- ✅ Excluir requisição de compra (contrato 55, 23/10).
- ✅ Propostas e Orçamento leem a API do Hub (`/api/comercial/*`, 27 a 29/10). A rota que ainda não foi migrada responde 503 `RECURSO_NAO_MIGRADO`.
- 🟡 Nenhuma tela lista os marcos da requisição. Quem os lê é o MES.
- ✅ O MES lê a OC da "Nova requisição" pela referência da OC (desde 15/10, `develop` do MES) e as requisições do Compras com pedido de venda (API-009, 23/10). Falta só a produção receber a `develop` do MES.
- 📝 Imposto por item decidido em 29/10 (N16-144); falta a tela: campos de imposto e selo de origem na emissão da OC, quando o desenvolvimento começar.
- 🟡 Endurecer a regra de aprovação quando Compras definir.
- ✅ O Orçamento antigo (JSON local) saiu em 16/10 (`c851cda`). As telas novas de Orçamento (Catálogo de produtos, Fornecedores, Painel do comprador, Parâmetros de custo, Custo dos itens) leem a API do Hub ([[12-Orcamento-Base-de-Preco]]).

## Detalhe técnico

Front do av-hub: Portal do Vendedor, Portal do Gerente, Compras, Comercial & Suprimentos, PCP (portal de leitura), Comissões, RH. Dono: Nathan. Next.js 16 (App Router), React, MUI 9, NextAuth 4, `@react-pdf/renderer`, S3 ✅ `av-hub/package.json`. Repositório: `av-hub` (develop, 758d5f0). A pasta `api-comercial/` continua nele, mas como legado só de leitura, com `LEIA-ME-LEGADO.md` (28/10, `a90d306`; [[API-Comercial]]). Esta nota cobre o que o fluxo de Atividades usa; o resto vai em [[Comissoes]], [[Dashboards]] e afins (anexo fora do fluxo).

### Como funciona

- **BFF.** O navegador só fala com `app/api/**` (202 `route.ts`); o BFF chama a `api-acos-vital` com `process.env.API_URL` e `x-api-key` (`API_KEY`) ✅ grep em `app lib services`. O módulo Comercial & Suprimentos passa por `app/api/comercial/[...rota]/route.ts`, que tem uma lista de rotas permitidas (72 padrões, cada um com tela e ação de `auth.telas`). Só 21 estão marcadas `api: 'hub'` e falam com a `api-acos-vital`; as demais respondem **503 `RECURSO_NAO_MIGRADO`** até a rota existir lá. A `api-comercial` do Pablo saiu do BFF (N16-111): `COMERCIAL_API_URL` e `COMERCIAL_API_KEY` não são mais usadas ✅ `lib/api/comercialApi.ts:15-21,83`. O mapa completo de rotas e do que cada uma exige: [[Mapa-Rotas-BFF-Bearer]].
- **Identidade.** `headersComIdentidade()` (via `headersDaApi()`) soma `x-api-key` e `Authorization: Bearer <token do usuário>` emitido por `POST /autenticacao/*` da API `lib/api/escopoUnidade.ts`. O token do usuário é lido do cookie httpOnly no servidor (`lib/auth/backendToken.ts`) e **não** vai na `session` que o navegador lê: a sessão só informa `sessaoExpirada`, e `providers/SessaoExpiradaGuard.tsx` leva ao login ✅ HUB `d0ef359`. Com o token, a API aplica a permissão por rota (`auth.fn_autorizar`) e o escopo de vendedor ([[RBAC-e-Permissoes]]). Autoria (`created_by`, `aprovado_por`…) sai da sessão, nunca do corpo ✅ `lib/compras/api.ts:42-45`.
- **Login.** NextAuth com Azure AD (o `id_token` vai ao `/autenticacao/azure`, que é a prova de identidade; perfis e tela inicial vêm de `GET /me/permissoes`) (`AZURE_AD_CLIENT_ID`, `_SECRET`, `_TENANT_ID`) ✅; `NEXT_PUBLIC_DEV_SEM_LOGIN` liga o modo de desenvolvimento sem login (tudo liberado) ✅ `lib/auth/devSemLogin.ts`, `lib/api/requirePermission.ts:25`.
- **Permissão no BFF.** `requirePermission(telaSlug | [slugs], acao)` confere primeiro `GET /me/permissoes` (cache 5 s) e responde 401 sem o token do usuário, 503 se `/me/permissoes` estiver fora do ar e 403 para tela fora de `auth.telas`; o menu preso no JWT é só apresentação e não autoriza nada ✅ `lib/api/requirePermission.ts`. Ações: `pode_visualizar`, `pode_criar`, `pode_editar`, `pode_deletar`, `pode_aprovar` ✅ `lib/permissions.ts:7-12`.
- **Permissão na tela.** `can('pode_x', 'slug')` lê o menu da sessão; botões e abas dependem disso ✅ ex.: `components/Compras/ComprasRequisicoes.tsx:92,186`.
- **Sem camada de dados no cliente.** Hooks por módulo (`components/Compras/useCompras.ts`, `Followup/useFollowup.ts`) chamam o BFF; sem regra de negócio no front ("GAMBIARRA(" marca onde ainda há: 9 ocorrências em 8 arquivos de `app`, `components`, `lib`, `services`) ✅ grep de 29/10.

### Telas do fluxo de Atividades

| Nó | Tela (nome atual · antigo) | Rota | Slug (`auth.telas`) | BFF → API | Código |
|---|---|---|---|---|---|
| V1 a V3 | Liberar Pedidos | `/vendas/liberar-pedidos` (antes `/liberar-pedidos`; o menu foi enxugado em 27/10, LOG-62) | `liberar-pedidos` | `GET /api/liberar-pedidos` → `GET /pedidos_liberacao`; `PUT /api/liberar-pedidos/:empresa/:numero` → `PUT /pedidos_liberacao/:empresa/:numero` | ✅ `app/(protected)/vendas/liberar-pedidos/page.tsx`, `components/LiberarPedidos/`, `app/api/liberar-pedidos/[codigoEmpresa]/[numeroPedido]/route.ts:19` |
| V2, V3 | Liberação da equipe (gerente) | `/liberacao-equipe` | `liberacao-equipe` | mesma rota, `?fonte=equipe` | ✅ `app/api/liberar-pedidos/route.ts:31-36` |
| V1 a O2 | Meus pedidos, Pedidos da equipe, PCP · Pedidos (detalhe com "Etapa dos itens") | `/vendas/meus-pedidos`, `/pedidos-equipe`, `/pcp-pedidos` (+ `…/pedido/[codigoEmpresa]/[pedidoVenda]`) | `meus-pedidos`, `pedidos-equipe`, `pcp-pedidos` | `GET /api/pedidos-venda/[fonte]/…/etapas` → `GET /itens_pedido_status` | ✅ `components/Pedidos/EtapaDosItens.tsx`, `app/api/pedidos-venda/[fonte]/[codigoEmpresa]/[pedidoVenda]/etapas/route.ts:18-60` |
| C0 | Requisições (Nova requisição) | `/compras/requisicoes`, `/compras/requisicoes/kanban` | `compras` | `GET /api/compras/requisicoes` → `GET /compras/requisicoes`; `POST /api/compras/requisicoes` → `POST /compras/requisicoes` (permissão `compras.pode_criar`) | ✅ `components/Compras/ComprasRequisicoes.tsx:186-190`, `app/api/compras/requisicoes/route.ts:80` |
| C1 | Cotação: mudar status da requisição (aberta, em cotação, cancelada com motivo); excluir requisição própria do Compras | idem (kanban e lista) | `compras` (editar) | `PATCH /api/compras/requisicoes/[id]` → `PATCH /compras/requisicoes/:id`; `DELETE /api/compras/requisicoes/[id]` → `DELETE /compras/requisicoes/:id` (contrato 55) | ✅ `app/api/compras/requisicoes/[id]/route.ts:32`, `components/Compras/Kanban/RequisicoesKanban.tsx:77` |
| C4 | Fechar compra / Nova OC (uma ou várias requisições) | `/compras/nova`, `/compras/nova/[requisicaoId]` | `compras` (criar) | `POST /api/compras/ordens` → `POST /compras/ordens` | ✅ `components/Compras/FecharCompra.tsx`, `app/api/compras/ordens/route.ts:111` |
| C2, C3 | Aprovações | `/compras/aprovacoes` | `compras` (`pode_aprovar`) | `PATCH /api/compras/ordens/[id]` (status `aprovado` ou `cancelado`) → `PATCH /compras/ordens/:id` | ✅ `components/Compras/ComprasAprovacoes.tsx:34`, `app/api/compras/ordens/[id]/route.ts:35` |
| C4 | Ordens (lista, kanban, detalhe, PDF, reenviar ao Omie) | `/compras/ordens`, `/compras/ordens/kanban`, `/compras/ordem/[id]`, `/compras/pedido-omie/[id]` | `compras` | `GET/…/api/compras/ordens/*`, `/pdf`, `/reenviar` (editar) | ✅ `components/Compras/ComprasOrdens.tsx`, `OrdemDetalhe.tsx:189-192` |
| C5 | Follow-up do CCP (confirmação, previsão, despacho, contato, ocorrência) | `/compras/followup` | `followup` | `GET /api/compras/acompanhamento`; `GET/PUT /api/compras/ordens/[id]/acompanhamento`; `POST …/contatos`, `…/ocorrencias`; `PATCH /api/compras/ocorrencias/[id]` (decidir: `followup.pode_aprovar`) | ✅ `components/Compras/Followup/FollowupPainel.tsx:106-109`, `app/api/compras/ocorrencias/[id]/route.ts:13` |
| — | Compradores (vínculo comprador × funcionário) | `/compras/compradores` | `compradores` | `GET/PUT /api/compras/compradores` | ✅ `components/Compras/Compradores/CompradorVinculo.tsx:74` |
| — | Painel de compras | `/compras/dashboard-compras`, `/compras` | `compras` | `GET /api/compras/dashboard` | ✅ `app/api/compras/dashboard/route.ts:17` |
| Torre | Torre de Fluxo: mapa por setor, lista, trilha do item, tempo e ranking | `/torre-fluxo`, `/torre-fluxo/item/[id]`, `/torre-fluxo/tempo`, `/torre-fluxo/ranking` | `torre-fluxo`, `torre-fluxo-trilha` | `GET /api/fluxo/torre`, `/api/fluxo/itens/[id]`, `/api/fluxo/sla-etapas` → `GET /fluxo/torre`, `/fluxo/itens/:id`, `/fluxo/sla-etapas`; 404 da API = `disponivel: false` (fixtures só em desenvolvimento) | ✅ `app/(protected)/torre-fluxo/`, `app/api/fluxo/`, `lib/fluxo/bff.ts` |
| E3, R4 | Custo real dos itens do pedido, com simulador (sem imposto) | `/orcamento/custo-itens` | `custo-itens` | `GET /api/custo-itens?numero_pedido=` → `GET /itens_pedido_custo` | ✅ `app/(protected)/orcamento/custo-itens/page.tsx`, `components/CustoItens/CustoItens.tsx`, `app/api/custo-itens/route.ts:10` |

As rotas de apoio do BFF de Compras exigem `compras.pode_visualizar`: `condicoes-pagamento`, `contas-correntes`, `fornecedores`, `transportadoras`, `projetos`, `produtos`, `categorias`, `cotacao`, `parametros`, `minhas-unidades` (esta última também aceita `compradores`) ✅ `app/api/compras/*/route.ts`.

### O que existe e o que falta, por nó

| Nó | Estado no HUB | Selo |
|---|---|---|
| V2, V3 | Tela de liberação completa, com as duas fontes (vendedor e equipe) e mapa de unidades | ✅ |
| C0 | "Nova requisição" cria requisição própria do Compras (sem `id_origem`; ela não gera marco no MES, mas o MES a vê pela referência da requisição, API-009, e a **OC** dela chega pela referência da OC, N14-20). Se o Compras vincula a requisição ou a OC a um pedido de venda, o PCP vê no MES; se é de estoque, o Estoque vê o saldo futuro | ✅ tela; ✅ o MES lê as duas referências (`develop` do MES); tela no HUB só se o MES precisar (BL-041) 🟡 |
| C1 | Mudança de status da requisição; cancelar exige motivo (3 a 500 caracteres, regra da API) | ✅ `api-acos-vital` `requisicoes_compra.route.js:442-448` |
| C2/C3 | Uma única tela de aprovação, com **uma** permissão (`compras.pode_aprovar`, perfil Gerência de Compras): aprova a OC que excede o limite (R$ 30 mil por padrão); até o limite a OC é liberada sem aprovação e a Diretoria não aprova (N14-21) | ✅ tela e regra (ver [[AV-Hub-API]]); 🟡 endurecer depois com Compras |
| C4 | OC com valor, desconto, moeda, cotação (no cabeçalho da OC), CIF/FOB (`tipo_frete`), flag `tipo_material` por item | ✅ `FecharCompra.tsx` |
| C5 | Follow-up do CCP | ✅ |
| Torre de Fluxo (LOG-46) | Telas e BFF prontos desde 15/10 (`3cd55de`, BL-022); falta o feed do MES (`/fluxo/*`) e a concessão da tela a um perfil de negócio | ✅ tela; 🔴 dado |
| Custo por item (LOG-47) | Tela e BFF prontos desde 15/10 (`544ee0b`, BL-023), sem imposto; a tela só enche quando o MES de produção publicar `GET /itens/custo` | ✅ tela; 🟡 dado |
| Status por item (API-005/006) | Card "Etapa dos itens" lê `GET /itens_pedido_status`; rótulos para as 11 etapas, o que não conhece aparece cru | ✅ `lib/domain/etapas-item.ts:34-47` |
| Marcos da requisição (LOG-35) | Nenhuma tela do HUB lista os marcos (`requisicoes_compra_eventos`); quem os lê é o MES | 🟡 |

### Permissões do HUB que o fluxo toca

Resumo; a tabela completa está em [[RBAC-e-Permissoes]].

| Slug | Ações usadas | Onde |
|---|---|---|
| `liberar-pedidos`, `liberacao-equipe` | visualizar, editar | `app/api/liberar-pedidos/**` |
| `compras` | visualizar, criar (nova requisição e nova OC), editar (status da requisição, reenviar ao Omie), aprovar (aprovar e cancelar OC) | `app/api/compras/**` |
| `followup` | visualizar, editar, aprovar | `app/api/compras/{acompanhamento,ocorrencias,ordens/[id]/(acompanhamento\|contatos\|ocorrencias)}` |
| `compradores` | visualizar, editar | `app/api/compras/compradores/**` |
| `pcp-pedidos`, `pcp-notas`, `pcp-dashboard` | visualizar (criar e deletar nas observações do PCP) | `app/api/pcp/**` |

### Pontas soltas conferidas no código

- ✅ O módulo antigo de Orçamento (JSON local em `lib/orcamento/`, `app/api/orcamento/*`) foi removido em 16/10 (`c851cda`). O Orçamento de hoje são as telas em `app/(protected)/orcamento/` sobre `/api/comercial/*` ([[12-Orcamento-Base-de-Preco]]).
- ✅ A aprovação lê `limite_aprovacao` de `GET /compras/parametros` apenas para avisar na tela de OC ("Acima de R$… ela nasce Aguardando aprovação") ✅ `components/Compras/FecharCompra.tsx:604-605,1652`.
- 🟡 `api-comercial` continua dentro do mesmo repositório (pasta `api-comercial/`), agora como legado só de leitura, fora do BFF ([[API-Comercial]]).

### O que o Nathan precisa construir para o fluxo

1. ✅ Tela Torre de Fluxo (`/torre-fluxo`, trilha, tempo, ranking) feita em 15/10. Falta conceder `torre-fluxo` e `torre-fluxo-trilha` a um perfil de negócio e o MES publicar `/fluxo/*`.
2. ✅ Tela de custo por item feita em 15/10. Falta conferir com dado real quando o MES de produção publicar `GET /itens/custo`.
3. A aprovação da OC já funciona (N14-21); quando Compras definir a regra mais rígida 🟡, ajustar `ComprasAprovacoes.tsx` e a API junto com o Gustavo. Nada a construir agora.
4. O MES enxergar a OC de "Nova requisição" (N14-20): já lê a referência da OC e da requisição (na `develop` do MES); o Nathan só faz tela no HUB se o MES precisar (BL-041) 🟡.
5. Imposto por item: desenho decidido em 29/10 (N16-144). Falta pôr os campos de imposto e o selo de origem na emissão da OC, quando o desenvolvimento começar 🔴.
