---
tags: [sistemas, mes, app-pcp, nextjs, frontend]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Robert
fontes: [app-pcp 1fca8d3 (develop), api-pcp 579a625, v1 App-PCP-Visao-Geral, App-PCP-Modelo-Producao, App-PCP-Recebimento-Conferencia]
---

# MES Front (`app-pcp`)

**Em uma frase:** é o site do MES (sistema de chão de fábrica), onde PCP, Estoque, Qualidade, Produção e Expedição fazem o trabalho do dia. Ele só conversa com a API do MES ([[MES-Backend]]). Dono: Robert.

## Quem usa e para quê

- **PCP:** tria os pedidos, define a Destinação e acompanha tudo.
- **Estoque:** atende as parciais e vê saldo, lotes e reservas.
- **Compras e Recebimento:** pedem compra, acompanham o CCP, recebem com nota e conferem.
- **Qualidade:** inspeciona a entrada e a saída.
- **Produção e Expedição:** trabalham a fila do setor, lançam pallets e confirmam a entrega.
- **Administradores:** cadastram setores, máquinas, usuários e perfis.

## Como se encaixa no fluxo

Cada etapa do fluxo tem a sua tela. A lista completa, por nó, está no Detalhe técnico e em [[Telas-por-Raia]].

- Triagem e Destinação do pedido (`P1`, `P2`) e acompanhamento (`X1`).
- Atendimento do Estoque (`E1` a `E4`).
- Requisição de compra (`P3`) e Compras · CCP (`C5`).
- Recebimento, divergências e inspeção de entrada (`R0` a `R6`, `Q1` a `Q4`).
- Filas de produção (`F1`), inspeção de saída (`Q7`, `Q8`) e Expedição (`X1` a `X4`).

## Regras que valem

- Quem não tem login vai para a tela de entrada.
- Cada tela confere a permissão do usuário. Quem garante de verdade é a API.
- O MES não tem a ação "aprovar". Só ver, criar, editar e excluir.
- Custo do lote só aparece com a permissão de custo.
- O botão "Liberar sem OC" exige a permissão de liberar compra.
- As filas só mostram os setores em que o perfil do usuário atua.
- A tela de Compras · CCP é só leitura.
- O Compras do av-hub usa outro conjunto de permissões.

## O que já existe e o que falta

- ✅ Todas as telas do fluxo acima, Estoque, cadastros e painéis.
- 🔴 Não há tela de Torre de Fluxo.
- 🔴 Não há tela de documento de retirada (`E6`).
- 🔴 Não há tela do `P6` (Novo norte).
- 🟡 Em Compras · CCP a atualização leva até 5 minutos, ou vale o botão "Atualizar".
- ❓ O nome interno de quatro telas (Mapa do Depósito, Permissões, Setores por Perfil e Depósitos por Perfil) não foi conferido no cadastro.

## Detalhe técnico

Front do MES. Next.js 16.3 (App Router) com React 19, MUI 9 e NextAuth 4 (✅ `app-pcp/package.json`). Fala só com o `api-pcp` ([[MES-Backend]]), por um BFF fino em `app/api/**` que repassa o Bearer do usuário (`session.accessToken`). Dono: Robert. Selos: [[Regras-do-Vault]].

### Como funciona

- **Login:** NextAuth com Azure AD ou usuário e senha. O Azure chama `POST /auth/azure` do `api-pcp` com `x-api-key: MES_INTERNAL_API_KEY`; a senha chama `POST /auth/login` ✅ `app/api/auth/[...nextauth]/route.ts:54-60,112`. A sessão guarda `menu` (de `GET /auth/menu`) e `setoresPermitidos` (de `GET /auth/setores-permitidos`) ✅ `:21,37`.
- **Rotas protegidas:** `proxy.ts` (middleware NextAuth) barra tudo menos `/login`, `/api/auth` e estáticos ✅ `proxy.ts:3-18`.
- **Variável do BFF:** `API_URL` aponta para o `api-pcp` (não para o av-hub) ✅ `app/api/**`; mais `MES_INTERNAL_API_KEY` e `AZURE_AD_*`.
- **Permissão na tela:** `usePermission()` pega o último segmento da URL como slug da tela e consulta o menu da sessão ✅ `hooks/usePermission.ts:8-17`. Telas que abrem uma fila de setor passam `telaId` explícito. Ações: `pode_visualizar`, `pode_criar`, `pode_editar`, `pode_deletar` (o MES não tem `pode_aprovar`) ✅ `lib/permissions.ts:3`.
- **Telas "só de permissão":** `estoque-custo` e `compras-liberar` existem em `telas` para o perfil receber a flag, mas não têm página nem item de menu ✅ `lib/telasSoPermissao.ts:8`. Ver [[RBAC-e-Permissoes]].
- **Nomes antigos no código:** a UI já mostra os nomes novos (Triagem dos Pedidos, Destinação do Pedido, Acompanhamento dos Pedidos); as rotas e os arquivos mantêm `carteira`, `ordens-producao`, `ordens-producao/novo` ✅ títulos em `app/(protected)/{carteira,ordens-producao,ordens-producao/novo}/page.tsx`.

### Telas (todas em `app/(protected)/`)

A coluna "Slug" é o `telaId` que decide `pode_*` na tela. Nós do 0b: [[00-Fluxo-Mestre-0b]].

#### Fluxo de Atividades

| Tela (nome atual · antigo) | Rota | Slug | Nó | Chama (via BFF) | Código |
|---|---|---|---|---|---|
| Triagem dos Pedidos · Carteira | `/carteira` | `carteira` | P1 | `GET /pedidos/carteira` | ✅ `carteira/page.tsx`, `services/carteira.ts` |
| Destinação do Pedido · Nova Ordem de Produção | `/ordens-producao/novo` | `ordens-producao` (criar) | P2 | `GET /pedidos/consulta-omie/:n`, `POST /pedidos/completo/lote` | ✅ `ordens-producao/novo/page.tsx` |
| Acompanhamento dos Pedidos · lista de Ordens de Produção | `/ordens-producao` e `/ordens-producao/[id]` | `ordens-producao` | P2, X1 | `GET /pedidos`, `/pedidos/:id`, embalagens, anexos, itens | ✅ `ordens-producao/page.tsx`, `[id]/page.tsx` |
| Atendimento (Estoque) | `/estoque-operacao/atendimento` | `atendimento` | E1 a E4 | fila de setor do tipo `ESTOQUE`; `PATCH /itens-parciais/:id/atender-estoque`; `GET /estoque/saldo/disponivel-parcial/:id` | ✅ `estoque-operacao/atendimento/page.tsx` → `ModuloSetores` |
| Requisições de compras | `/compras/requisicoes` | `requisicoes` | P3 | fila de setor tipo `REQUISICAO`; `POST /compras/requisicoes` (modal `RequisitarCompraModal`) | ✅ `compras/requisicoes/page.tsx:13` |
| Compras · CCP | `/compras/pedidos-compra` | `pedidos-compra` | C5 | fila de setor tipo `COMPRAS`, só leitura; `POST /compras/requisicoes/sincronizar`; `GET /compras/requisicoes/:id/eventos` (linha do tempo) | ✅ `compras/pedidos-compra/page.tsx:9-15`, `components/CompraCcpCard.tsx`, `EventosRequisicaoModal.tsx` |
| Recebimento | `/logistica/logistica-entrada` | `logistica-entrada` | R0 a R4 | fila tipo `LOGISTICA_ENTRADA` com "Entregas esperadas": `GET /compras/requisicoes/esperados`, `POST …/:id/chegada` ("Receber com NF"), `POST /compras/recebimentos`, `…/:id/recontar`; botão de liberar sem OC só com `compras-liberar` editar | ✅ `logistica/logistica-entrada/page.tsx`, `components/FilaSetor.tsx:262-304,550`, `ReceberComNfModal.tsx`, `ConferirRecebimentoModal.tsx`, `RecontarRecebimentoModal.tsx` |
| Divergências de Recebimento | `/decisoes-pcp` | `decisoes-pcp` | R6 | `GET /compras/recebimentos/decisoes`, `POST …/:id/decidir` (aceitar ou reabrir) | ✅ `decisoes-pcp/page.tsx` |
| Inspeção de entrada | `/qualidade/inspecao-entrada` | `inspecao-entrada` | Q1 a Q4 | `GET /qualidade/lotes`, `POST /qualidade/lotes/:id/aprovar` e `/reprovar` | ✅ `qualidade/inspecao-entrada/page.tsx`; BFF `app/api/qualidade/[id]/{aprovar,reprovar}` |
| Filas de Produção (Movimentações) | `/movimentacoes`, `/movimentacoes/[setorId]` | `movimentacoes` | F1 | `/itens-parciais/*` (receber, iniciar, mover, concluir, pausar, reprovar, retrabalho, devolver, split) | ✅ `movimentacoes/[setorId]/page.tsx:16` |
| Inspeção de saída | `/qualidade/inspecao-saida` | `inspecao-saida` | Q7, Q8 | fila de setor tipo `QUALIDADE` (exceto `qualidade-entrada`) | ✅ `qualidade/inspecao-saida/page.tsx:14` |
| Expedição | `/logistica/expedicao` | `expedicao` | X1 a X4 | fila tipo `EXPEDICAO`; `POST /entregas`; embalagens e paletes | ✅ `logistica/expedicao/page.tsx:13` |

Todas as telas "módulo" (Atendimento, Requisições, Compras · CCP, Recebimento, Inspeção de saída, Expedição) usam o mesmo componente `ModuloSetores` + `FilaSetor`, que filtra os setores do tipo do módulo pelo `PerfilSetor` do usuário ✅ `movimentacoes/components/ModuloSetores.tsx:12-88`. Compras · CCP é só leitura: as ações da fila de um setor `COMPRAS` em decisão são apenas `requisitar-compra` (para ordem sem setor Requisições) e `devolver` ✅ `movimentacoes/acoes.ts:106-127`. Setor Recebimento: só `registrar-recebimento` (sem "Devolver" desde 14/10) ✅ `:126-128`.

#### Estoque

| Tela | Rota | Slug | Observação |
|---|---|---|---|
| Saldo | `/estoque-operacao/saldo` | `saldo` | mostra custo do lote só com `estoque-custo` visualizar; modal de entrada (carga inicial) com custo opcional só com `estoque-custo` editar ✅ `saldo/page.tsx:35`, `EntradaLoteModal.tsx:36` |
| Lote | `/estoque-operacao/lotes/[id]` | `saldo` | bloco `custo` só com `estoque-custo` visualizar ✅ `lotes/[id]/page.tsx:140`, `types.ts:40` |
| Reservas | `/estoque-operacao/reservas` | `reservas` | liberar reserva ✅ |
| Movimentação e Ajuste | `/estoque-operacao/movimentacao` | `movimentacao` | transferência e ajuste ✅ |
| Mapa do Depósito | `/estoque-operacao/mapa-deposito` | ❓ | não conferido |
| Painel do Estoque | `/estoque-operacao/painel-estoque` | `painel-estoque` | alertas de mínimo e RNC pendente ✅ |
| Depósitos | `/cadastros/estoque/depositos` | `depositos` | depósitos e localizações |
| Materiais | `/cadastros/estoque/materiais` | `materiais` | natureza, peso teórico, tolerância, mínimos |

#### Cadastros e acessos

| Tela | Rota | Slug |
|---|---|---|
| Destinos (fábricas) | `/cadastros/operacional/fabricas` | `fabricas` |
| Setores | `/cadastros/operacional/setores` | `setores` |
| Máquinas | `/cadastros/operacional/maquinas` | `maquinas` |
| Operadores | `/cadastros/operacional/operadores` | `operadores` |
| Usuários | `/cadastros/acessos/usuarios` | `usuarios` |
| Perfis | `/cadastros/acessos/perfis` | `perfis` |
| Telas | `/cadastros/acessos/telas` | `telas` |
| Permissões | `/cadastros/acessos/permissoes` | `permissoes` ❓ (o endpoint usado é `/perfis/:id/permissoes/bulk`, slug `perfis`) |
| Usuários × Perfis | `/cadastros/acessos/usuarios-perfis` | `usuarios-perfis` |
| Setores por Perfil | `/cadastros/acessos/setores-perfil` | `setores-perfil` ❓ |
| Depósitos por Perfil | `/cadastros/acessos/depositos-perfil` | `depositos-perfil` ❓ |

#### Painéis

`/dashboard` (Início, "Resumo da produção agora"), `/relatorios` (tempo por setor, compras), `/pedidos-excluidos`, `/blank`, `/` ✅ títulos nas páginas.

### Permissões que o front confere

| Onde | Regra | Código |
|---|---|---|
| Entrada de lote (Saldo) | campo de custo só com `estoque-custo` editar | ✅ `saldo/EntradaLoteModal.tsx:36` |
| Saldo e Lote | coluna/bloco de custo só com `estoque-custo` visualizar | ✅ `saldo/page.tsx:35`, `lotes/[id]/page.tsx:140` |
| Fila de Recebimento | botão "Liberar sem OC" só com `compras-liberar` editar | ✅ `components/FilaSetor.tsx:304` |
| Botões das filas | `PermissionButton` + `setoresPermitidos` da sessão (a garantia é o `PerfilSetor` no `api-pcp`) | ✅ `components/Ui/PermissionButton` |
| Rotas de ação (BFF) | `requirePermission(session, 'movimentacoes', 'pode_editar')` e equivalentes | ✅ `app/api/requisicoes-compra/[id]/chegada/route.ts:12` |

O Compras do av-hub (permissões `compras.pode_criar`, `compras.pode_aprovar`, `followup.*`) **não** existe aqui: é outro RBAC ([[RBAC-e-Permissoes]]).

### Diferenças e pontas soltas do front

- 🔴 Não há tela de Torre de Fluxo nem tela de documento de retirada (E6).
- 🔴 Não há tela de P6 (Novo norte).
- 🟡 Em Compras · CCP o front lê o MES, não o av-hub; a lista de esperados e a linha do tempo dependem do polling de 5 min ou do botão "Atualizar" (`POST /compras/requisicoes/sincronizar`, pulado se a leitura tem menos de 30 s) ✅ `services/comprasRequisicoes.ts:52`, `api-pcp/src/integracao-avhub/eventos-avhub.service.ts:25`.
- ❓ Slugs de `Mapa do Depósito`, `Permissões`, `Setores por Perfil` e `Depósitos por Perfil` dependem do cadastro em `telas` (o seed `01-base.sql` citado nos comentários não está nos repositórios).

Fluxograma por raia: [[Telas-por-Raia]].
