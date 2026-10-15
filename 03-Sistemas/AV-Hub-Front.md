---
tags: [sistemas, av-hub, hub, nextjs, frontend, bff]
criado: 2026-10-14
atualizado: 2026-10-15
status: vigente
dono: Nathan
fontes: [HUB d0ef359 (PR #206, sobre b55ac55) em C:\Users\nathan.silva\Desktop\TI\NATHAN\00 - HUB (conferido no código em 14/10), api-acos-vital f322dcd, v1 AV-Hub-Arquitetura-BFF, AV-Hub-Modulos, AV-Hub-RBAC]
---

# AV-Hub Front (HUB)

Front do av-hub: Portal do Vendedor, Portal do Gerente, Compras, Comercial & Suprimentos, PCP (portal de leitura), Comissões, RH. Dono: Nathan. Next.js 16 (App Router), React, MUI 9, NextAuth 4, `@react-pdf/renderer`, S3 ✅ `00 - HUB/package.json`. Repositório: `00 - HUB` (HUB b55ac55, develop), que contém também a pasta `api-comercial/` ([[API-Comercial]]). Esta nota cobre o que o fluxo de Atividades usa; o resto vai em [[Comissoes]], [[Dashboards]] e afins (anexo fora do fluxo).

## Como funciona

- **BFF.** O navegador só fala com `app/api/**` (199 `route.ts`); o BFF chama a `api-acos-vital` com `process.env.API_URL` (251 usos) e `x-api-key` (`API_KEY`, 9 usos) ✅ grep em `app lib services`. O módulo Comercial & Suprimentos passa por `app/api/comercial/[...rota]/route.ts` com `COMERCIAL_API_URL` e `COMERCIAL_API_KEY` ✅. O mapa completo de rotas e do que cada uma exige: [[Mapa-Rotas-BFF-Bearer]].
- **Identidade.** `headersComIdentidade()` (via `headersDaApi()`) soma `x-api-key` e `Authorization: Bearer <token do usuário>` emitido por `POST /autenticacao/*` da API `lib/api/escopoUnidade.ts`. O token do usuário é lido do cookie httpOnly no servidor (`lib/auth/backendToken.ts`) e **não** vai na `session` que o navegador lê: a sessão só informa `sessaoExpirada`, e `providers/SessaoExpiradaGuard.tsx` leva ao login ✅ HUB `d0ef359`. Com o token, a API aplica a permissão por rota (`auth.fn_autorizar`) e o escopo de vendedor ([[RBAC-e-Permissoes]]). Autoria (`created_by`, `aprovado_por`…) sai da sessão, nunca do corpo ✅ `lib/compras/api.ts:42-45`.
- **Login.** NextAuth com Azure AD (o `id_token` vai ao `/autenticacao/azure`, que é a prova de identidade; perfis e tela inicial vêm de `GET /me/permissoes`) (`AZURE_AD_CLIENT_ID`, `_SECRET`, `_TENANT_ID`) ✅; `NEXT_PUBLIC_DEV_SEM_LOGIN` liga o modo de desenvolvimento sem login (tudo liberado) ✅ `lib/auth/devSemLogin.ts`, `lib/api/requirePermission.ts:25`.
- **Permissão no BFF.** `requirePermission(telaSlug | [slugs], acao)` confere primeiro `GET /me/permissoes` (cache 5 s) e responde 401 sem o token do usuário, 503 se `/me/permissoes` estiver fora do ar e 403 para tela fora de `auth.telas`; o menu preso no JWT é só apresentação e não autoriza nada ✅ `lib/api/requirePermission.ts`. Ações: `pode_visualizar`, `pode_criar`, `pode_editar`, `pode_deletar`, `pode_aprovar` ✅ `lib/permissions.ts:7-12`.
- **Permissão na tela.** `can('pode_x', 'slug')` lê o menu da sessão; botões e abas dependem disso ✅ ex.: `components/Compras/ComprasRequisicoes.tsx:92,186`.
- **Sem camada de dados no cliente.** Hooks por módulo (`components/Compras/useCompras.ts`, `Followup/useFollowup.ts`) chamam o BFF; sem regra de negócio no front ("GAMBIARRA(" marca onde ainda há: 11 ocorrências em `app`, `components`, `lib`, `services`) ✅ grep de 14/10.

## Telas do fluxo de Atividades

| Nó | Tela (nome atual · antigo) | Rota | Slug (`auth.telas`) | BFF → API | Código |
|---|---|---|---|---|---|
| V1 a V3 | Liberar Pedidos | `/liberar-pedidos` | `liberar-pedidos` | `GET /api/liberar-pedidos` → `GET /pedidos_liberacao`; `PUT /api/liberar-pedidos/:empresa/:numero` → `PUT /pedidos_liberacao/:empresa/:numero` | ✅ `app/(protected)/liberar-pedidos/page.tsx`, `components/LiberarPedidos/`, `app/api/liberar-pedidos/[codigoEmpresa]/[numeroPedido]/route.ts:19` |
| V2, V3 | Liberação da equipe (gerente) | `/liberacao-equipe` | `liberacao-equipe` | mesma rota, `?fonte=equipe` | ✅ `app/api/liberar-pedidos/route.ts:31-36` |
| V1 a O2 | Meus pedidos, Pedidos da equipe, PCP · Pedidos (detalhe com "Etapa dos itens") | `/meus-pedidos`, `/pedidos-equipe`, `/pcp-pedidos` (+ `…/pedido/[codigoEmpresa]/[pedidoVenda]`) | `meus-pedidos`, `pedidos-equipe`, `pcp-pedidos` | `GET /api/pedidos-venda/[fonte]/…/etapas` → `GET /itens_pedido_status` | ✅ `components/Pedidos/EtapaDosItens.tsx`, `app/api/pedidos-venda/[fonte]/[codigoEmpresa]/[pedidoVenda]/etapas/route.ts:18-60` |
| C0 | Requisições (Nova requisição) | `/compras/requisicoes`, `/compras/requisicoes/kanban` | `compras` | `GET /api/compras/requisicoes` → `GET /compras/requisicoes`; `POST /api/compras/requisicoes` → `POST /compras/requisicoes` (permissão `compras.pode_criar`) | ✅ `components/Compras/ComprasRequisicoes.tsx:186-190`, `app/api/compras/requisicoes/route.ts:80` |
| C1 | Cotação: mudar status da requisição (aberta, em cotação, cancelada com motivo) | idem (kanban e lista) | `compras` (editar) | `PATCH /api/compras/requisicoes/[id]` → `PATCH /compras/requisicoes/:id` | ✅ `app/api/compras/requisicoes/[id]/route.ts:32`, `components/Compras/Kanban/RequisicoesKanban.tsx:77` |
| C4 | Fechar compra / Nova OC (uma ou várias requisições) | `/compras/nova`, `/compras/nova/[requisicaoId]` | `compras` (criar) | `POST /api/compras/ordens` → `POST /compras/ordens` | ✅ `components/Compras/FecharCompra.tsx`, `app/api/compras/ordens/route.ts:111` |
| C2, C3 | Aprovações | `/compras/aprovacoes` | `compras` (`pode_aprovar`) | `PATCH /api/compras/ordens/[id]` (status `aprovado` ou `cancelado`) → `PATCH /compras/ordens/:id` | ✅ `components/Compras/ComprasAprovacoes.tsx:34`, `app/api/compras/ordens/[id]/route.ts:35` |
| C4 | Ordens (lista, kanban, detalhe, PDF, reenviar ao Omie) | `/compras/ordens`, `/compras/ordens/kanban`, `/compras/ordem/[id]`, `/compras/pedido-omie/[id]` | `compras` | `GET/…/api/compras/ordens/*`, `/pdf`, `/reenviar` (editar) | ✅ `components/Compras/ComprasOrdens.tsx`, `OrdemDetalhe.tsx:189-192` |
| C5 | Follow-up do CCP (confirmação, previsão, despacho, contato, ocorrência) | `/compras/followup` | `followup` | `GET /api/compras/acompanhamento`; `GET/PUT /api/compras/ordens/[id]/acompanhamento`; `POST …/contatos`, `…/ocorrencias`; `PATCH /api/compras/ocorrencias/[id]` (decidir: `followup.pode_aprovar`) | ✅ `components/Compras/Followup/FollowupPainel.tsx:106-109`, `app/api/compras/ocorrencias/[id]/route.ts:13` |
| — | Compradores (vínculo comprador × funcionário) | `/compras/compradores` | `compradores` | `GET/PUT /api/compras/compradores` | ✅ `components/Compras/Compradores/CompradorVinculo.tsx:74` |
| — | Painel de compras | `/compras/dashboard-compras`, `/compras` | `compras` | `GET /api/compras/dashboard` | ✅ `app/api/compras/dashboard/route.ts:17` |

As rotas de apoio do BFF de Compras exigem `compras.pode_visualizar`: `condicoes-pagamento`, `contas-correntes`, `fornecedores`, `transportadoras`, `projetos`, `produtos`, `categorias`, `cotacao`, `parametros`, `minhas-unidades` (esta última também aceita `compradores`) ✅ `app/api/compras/*/route.ts`.

## O que existe e o que falta, por nó

| Nó | Estado no HUB | Selo |
|---|---|---|
| V2, V3 | Tela de liberação completa, com as duas fontes (vendedor e equipe) e mapa de unidades | ✅ |
| C0 | "Nova requisição" cria requisição própria do Compras (sem `id_origem`; a requisição não chega ao MES, a **OC** dela chega pela referência, N14-20). Se o Compras vincula a requisição ou a OC a um pedido de venda, o PCP vê a OC no MES; se é de estoque, o Estoque vê o saldo futuro | ✅ tela; 🔴 o MES ler a OC (BL-006); tela no HUB só se o MES precisar (BL-041) 🟡 |
| C1 | Mudança de status da requisição; cancelar exige motivo (3 a 500 caracteres, regra da API) | ✅ `api-acos-vital` `requisicoes_compra.route.js:442-448` |
| C2/C3 | Uma única tela de aprovação, com **uma** permissão (`compras.pode_aprovar`, perfil Gerência de Compras): aprova a OC que excede o limite (R$ 30 mil por padrão); até o limite a OC é liberada sem aprovação e a Diretoria não aprova (N14-21) | ✅ tela e regra (ver [[AV-Hub-API]]); 🟡 endurecer depois com Compras |
| C4 | OC com valor, desconto, moeda, cotação (no cabeçalho da OC), CIF/FOB (`tipo_frete`), flag `tipo_material` por item | ✅ `FecharCompra.tsx` |
| C5 | Follow-up do CCP | ✅ |
| Torre de Fluxo (LOG-46) | **Sem tela**: nenhum arquivo do HUB referencia `fluxo/torre`, `torre-fluxo` | 🔴 front do Nathan |
| Custo por item (LOG-47) | **Sem tela**: nenhuma referência a `itens_pedido_custo` nem a `custo-itens` no HUB | 🔴 front do Nathan |
| Status por item (API-005/006) | Card "Etapa dos itens" lê `GET /itens_pedido_status`; rótulos para as 11 etapas, o que não conhece aparece cru | ✅ `lib/domain/etapas-item.ts:34-47` |
| Marcos da requisição (LOG-35) | Nenhuma tela do HUB lista os marcos (`requisicoes_compra_eventos`); quem os lê é o MES | 🟡 |

## Permissões do HUB que o fluxo toca

Resumo; a tabela completa está em [[RBAC-e-Permissoes]].

| Slug | Ações usadas | Onde |
|---|---|---|
| `liberar-pedidos`, `liberacao-equipe` | visualizar, editar | `app/api/liberar-pedidos/**` |
| `compras` | visualizar, criar (nova requisição e nova OC), editar (status da requisição, reenviar ao Omie), aprovar (aprovar e cancelar OC) | `app/api/compras/**` |
| `followup` | visualizar, editar, aprovar | `app/api/compras/{acompanhamento,ocorrencias,ordens/[id]/(acompanhamento\|contatos\|ocorrencias)}` |
| `compradores` | visualizar, editar | `app/api/compras/compradores/**` |
| `pcp-pedidos`, `pcp-notas`, `pcp-dashboard` | visualizar (criar e deletar nas observações do PCP) | `app/api/pcp/**` |

## Pontas soltas conferidas no código

- ✅ `app/api/orcamento/*` não chama mais as views antigas: lê `lib/orcamento/dados.ts`, que importa JSON local (`lib/orcamento/data/*.json`). Orçamento roda sobre dado estático, não sobre `core_compras.orc_*` ([[Orcamento]]).
- ✅ A aprovação lê `limite_aprovacao` de `GET /compras/parametros` apenas para avisar na tela de OC ("Acima de R$… ela nasce Aguardando aprovação") ✅ `components/Compras/FecharCompra.tsx:604-605,1652`.
- 🟡 `api-comercial` está dentro do mesmo repositório do HUB (pasta `api-comercial/`) e tem CI próprio ([[API-Comercial]]).

## O que o Nathan precisa construir para o fluxo

1. Tela Torre de Fluxo (`/fluxo/torre`, trilha, tempo, SLA) sobre `GET /fluxo/*` da API 🔴.
2. Tela/coluna de custo por item (`custo-itens`) sobre `GET /itens_pedido_custo` 🔴.
3. A aprovação da OC já funciona (N14-21); quando Compras definir a regra mais rígida 🟡, ajustar `ComprasAprovacoes.tsx` e a API junto com o Gustavo. Nada a construir agora.
4. O MES enxergar a OC de "Nova requisição" (N14-20): o trabalho é do Robert (MES) e, se a API precisar expor por produto ou pedido, do Gustavo; o Nathan só faz tela no HUB se o MES precisar (BL-041) 🟡.
5. Desenhar com o Gustavo o modelo do imposto por item, para ter os cenários com e sem imposto (BL-053, PS-014) 🟡.
