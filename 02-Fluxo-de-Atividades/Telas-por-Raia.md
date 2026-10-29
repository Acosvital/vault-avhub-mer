---
tags: [fluxo, telas, rotas, raias, referencia]
criado: 2026-10-14
atualizado: 2026-10-26
status: vigente
dono: Nathan
fontes: [app-pcp 1fca8d3 (app/(protected)/**/page.tsx, títulos dos PageHeader), HUB b55ac55 em disco (app/(protected), components), v1 Fluxograma-Telas-por-Bloco, 00-Fluxo-Mestre-0b, Regras-do-Vault]
---

# Telas por raia

Cada tela do fluxo de Atividades ([[00-Fluxo-Mestre-0b]]) com nome atual, nome antigo, rota e repositório. Os nomes novos foram aplicados nos **títulos** do `app-pcp` (`9bb47e4`, #39: só rótulos); **rotas, slugs, pastas e permissões seguem com os nomes antigos**. O texto do menu vem da tabela `telas` do banco, não do código ❓. Convenção de nomes em [[Regras-do-Vault]]. Selos: ✅ existe no código, 🟡 parcial, 🔴 não existe.

Repositórios: **HUB** é o front do av-hub (`b55ac55`, conferido em disco), **app-pcp** é o front do MES. Rotas do HUB passam pelo BFF (`app/api/...`). As colunas "Slug" são os identificadores de `telaId` ou de permissão.

## Vendas (V1 a V3) · [[01-Vendas-Liberacao]]

| Nó | Nome atual | Nome antigo | Rota | Repo | Slug | Estado |
|---|---|---|---|---|---|---|
| V2, V3 | Liberar Pedidos | Caixa de entrada do vendedor (1.1) | `/liberar-pedidos` | HUB | `liberar-pedidos` | ✅ `app/(protected)/liberar-pedidos/page.tsx`; menu em "Portal do Vendedor" (`groupMap.ts:23`) |
| V2 (leitura) | Liberação da Equipe | visão do gerente da 1.1 | `/liberacao-equipe` | HUB | `liberacao-equipe` | ✅ só leitura; "Portal do Gerente" (`groupMap.ts:27`) |
| V1 a O2 | Meus Pedidos, detalhe com cartão Etapa dos itens | Meus Pedidos por etapa (1.2) | `/meus-pedidos`, `/meus-pedidos/pedido/[codigoEmpresa]/[pedidoVenda]` | HUB | `meus-pedidos` | ✅ cartão `components/Pedidos/EtapaDosItens.tsx`, usado em `PedidoDetalhe.tsx:812`; 🟡 sem linha do tempo, SLA nem filtro |
| idem | Pedidos da Equipe, detalhe | idem | `/pedidos-equipe`, `/pedidos-equipe/pedido/...` | HUB | `pedidos-equipe` | ✅ mesmo cartão |
| — | Pedidos do PCP | Portal PCP | `/pcp-pedidos`, `/pcp-pedidos/pedido/...` | HUB | `pcp-pedidos` | ✅ acompanhamento comercial por diligenciador; **não é o `app-pcp`** |

## PCP (P1, P2, P6) · [[02-PCP-Triagem-e-Destinacao]]

| Nó | Nome atual | Nome antigo | Rota | Repo | Slug | Estado |
|---|---|---|---|---|---|---|
| P1 | Triagem dos Pedidos | Carteira (de Pedidos) | `/carteira` | app-pcp | `carteira` ❓ | ✅ título `carteira/page.tsx:178`; lê `GET /pedidos/carteira` |
| P2 | Destinação do Pedido | Nova Ordem de Produção | `/ordens-producao/novo` | app-pcp | `ordens-producao` | ✅ título `ordens-producao/novo/page.tsx:517`; `POST /pedidos/completo/lote` |
| — | Acompanhamento dos Pedidos | Ordens de Produção (lista) | `/ordens-producao` | app-pcp | `ordens-producao` | ✅ título `ordens-producao/page.tsx:144` |
| — | Acompanhamento dos Pedidos, detalhe | Ordem de Produção (detalhe) | `/ordens-producao/[id]` | app-pcp | `ordens-producao` | ✅ mini-roteiro, histórico, anexos, embalagens; 🟡 falta mostrar o split atendido pelo estoque e a reserva |
| — | Pedidos excluídos | — | `/pedidos-excluidos` | app-pcp | ❓ | ✅ snapshot de pedido excluído |
| P6 | Novo norte (retrabalho ou reabrir compra) | Fila "Novo norte" (2.5) | — | app-pcp | — | 🔴 sem tela; `/decisoes-pcp` só trata recebimento |
| P1, P2 | OC do pedido (coluna ou cartão na Triagem e na Destinação) | — | `/carteira`, `/ordens-producao/novo` | app-pcp | — | 🔴 não existe (N14-20, BL-049): o PCP deve ver que já há OC para o pedido |
| P2 | Ordem de Produção (entidade e documento imprimível, só do que será fabricado) | — | — | app-pcp | — | 🔴 não existe (N14-22, BL-052) |

## Estoque (E1 a E6) · [[03-Estoque-Atendimento-e-Despacho]]

| Nó | Nome atual | Nome antigo | Rota | Repo | Slug | Estado |
|---|---|---|---|---|---|---|
| E1 a E4 | Atendimento | Atendimento / Baixa (8.12) | `/estoque-operacao/atendimento` | app-pcp | `atendimento` | ✅ fila do setor Estoque com `AtenderEstoqueModal` (título `atendimento/page.tsx:10`) |
| E5 (consulta) | Saldo | Consulta de Saldo (8.4) | `/estoque-operacao/saldo` | app-pcp | ❓ | ✅ título `saldo/page.tsx:73` |
| E3 | Reservas | Reservas (8.5) | `/estoque-operacao/reservas` | app-pcp | ❓ | ✅ |
| E6 (parcial) | Movimentação e Ajuste | Movimentação (8.6) | `/estoque-operacao/movimentacao` | app-pcp | ❓ | ✅ ENTRADA, SAIDA, TRANSFERENCIA, AJUSTE |
| E5 | Detalhe do lote | Detalhe do lote (8.7) | `/estoque-operacao/lotes/[id]` | app-pcp | ❓ | ✅ movimentos, etiqueta Code128 |
| — | Painel do Estoque | Dashboard do Estoque | `/estoque-operacao/painel-estoque` | app-pcp | `painel-estoque` | 🟡 protótipo com dados de exemplo; alertas reais |
| — | Mapa do Depósito | — | `/estoque-operacao/mapa-deposito` | app-pcp | ❓ | 🟡 sobre `MOCK_DEPOSITOS` |
| — | Materiais, Depósitos | Cadastro de material, Depósitos (8.1, 8.2) | `/cadastros/estoque/materiais`, `/cadastros/estoque/depositos` | app-pcp | ❓ | ✅ API real |
| E6 | Documento de retirada | — | — | app-pcp | — | 🔴 não existe |
| E1 | Saldo futuro (no Atendimento e no Saldo: saldo atual + OCs em andamento de estoque) | — | `/estoque-operacao/atendimento`, `/estoque-operacao/saldo` | app-pcp | — | 🔴 não existe (N14-20, BL-050) |

## Compras e fornecedor (P3, C0 a C5, FN1) · [[04-Circuito-de-Compra]]

| Nó | Nome atual | Nome antigo | Rota | Repo | Slug | Estado |
|---|---|---|---|---|---|---|
| P3 | Requisições de compras | Setor Compras (2.4), fila `requisicoes` | `/compras/requisicoes` | app-pcp | `requisicoes` | ✅ `RequisitarCompraModal` ("Solicitar compra" do Estoque cai aqui); título `requisicoes/page.tsx:10` |
| C5 | Compras · CCP | Pedidos de Compra / Compras | `/compras/pedidos-compra` (e `/compras`) | app-pcp | `pedidos-compra` | ✅ só leitura; título `pedidos-compra/page.tsx:11`; linha do tempo por material, `EventosRequisicaoModal` |
| C0, C1 | Requisições (caixa do Compras), "Nova requisição" | Caixa de entrada de Requisições (3.1) | `/compras/requisicoes`, `/compras/requisicoes/kanban` | HUB | ❓ | ✅ `components/Compras/ComprasRequisicoes.tsx:188`, `:426` |
| C4 | Nova Ordem de Compra | Emissão da OC (3.2) | `/compras/nova`, `/compras/nova/[requisicaoId]` | HUB | ❓ | ✅ |
| C4 | Ordens de Compra | Ordens de Compra (3.3) | `/compras/ordens`, `/compras/ordens/kanban`, `/compras/ordem/[id]`, `/compras/pedido-omie/[id]` | HUB | ❓ | ✅ |
| C2, C3 | Aprovações | Fila de Aprovações (3.4) | `/compras/aprovacoes` | HUB | ❓ | ✅ aprova só a OC acima de R$ 30 mil (Gerência de Compras); sem Diretoria (N14-21) |
| C5 | Follow-up | Follow-up do CCP (3.6) | `/compras/followup` | HUB | ❓ | ✅ |
| — | Dashboard de Compras | (3.5) | `/compras/dashboard-compras` | HUB | ❓ | ✅ |
| — | Compradores | — | `/compras/compradores` | HUB | ❓ | ✅ cadastro de compradores usado pela OC (LOG-18, LOG-28, LOG-36) |
| FN1 | — | — | — | — | — | externo, sem tela |

## Recebimento (R0 a R6) · [[05-Recebimento]]

| Nó | Nome atual | Nome antigo | Rota | Repo | Slug | Estado |
|---|---|---|---|---|---|---|
| R0 a R4 | Recebimento | Logística de entrada | `/logistica/logistica-entrada` | app-pcp | `logistica-entrada` | ✅ título `logistica-entrada/page.tsx:10`; esperados, "Receber com NF" (`ReceberComNfModal`), conferência (`ConferirRecebimentoModal`), recontagem (`RecontarRecebimentoModal`) |
| R6 | Divergências de Recebimento | Decisões do PCP | `/decisoes-pcp` | app-pcp | `decisoes-pcp` | ✅ título `decisoes-pcp/page.tsx:74`; `ACEITO` ou `REABERTO` |
| R4 | Detalhe do lote, "Imprimir etiqueta" | (6.5) | `/estoque-operacao/lotes/[id]` | app-pcp | ❓ | ✅ |
| — | Logística (índice) | — | `/logistica` | app-pcp | ❓ | ✅ |

## Qualidade de entrada (Q1 a Q4) · [[06-Qualidade-Entrada]]

| Nó | Nome atual | Nome antigo | Rota | Repo | Slug | Estado |
|---|---|---|---|---|---|---|
| Q1 a Q4 | Inspeção de entrada | Qualidade (mock) | `/qualidade/inspecao-entrada` | app-pcp | `inspecao-entrada` | ✅ título `inspecao-entrada/page.tsx:117` |
| — | Fila Qualidade · Entrada | — | `/movimentacoes/[setorId]` (setor `qualidade-entrada`) | app-pcp | `movimentacoes` | ✅ só leitura (`acoes.ts:98-100`) |

## Produção (F1) · [[07-Producao-e-Roteiro]]

| Nó | Nome atual | Nome antigo | Rota | Repo | Slug | Estado |
|---|---|---|---|---|---|---|
| F1 | Filas de Produção (setores) | Movimentações | `/movimentacoes` | app-pcp | `movimentacoes` | ✅ título `movimentacoes/page.tsx:121` |
| F1 | Fila do setor | Board do setor (7.1) | `/movimentacoes/[setorId]` | app-pcp | `movimentacoes` | ✅ `FilaSetor.tsx`, 17 ações |
| — | Dashboard | Dashboard de produção (7.3) | `/dashboard` | app-pcp | ❓ | ✅ |
| — | Painel TV | (7.4) | — | app-pcp | — | 🔴 backend `GET /dashboard/tv` sem página |
| — | Fábricas, Setores, Máquinas, Operadores | cadastros operacionais | `/cadastros/operacional/fabricas`, `setores`, `maquinas`, `operadores` | app-pcp | ❓ | ✅ |
| — | Relatórios | — | `/relatorios` | app-pcp | ❓ | ✅ |

## Qualidade de saída (Q7, Q8) · [[08-Qualidade-Saida]]

| Nó | Nome atual | Nome antigo | Rota | Repo | Slug | Estado |
|---|---|---|---|---|---|---|
| Q7, Q8 | Inspeção de saída | fila do setor Qualidade no roteiro | `/qualidade/inspecao-saida` | app-pcp | `inspecao-saida` | ✅ `inspecao-saida/page.tsx:1-18` |
| Q7 | Qualidade (índice) | — | `/qualidade` | app-pcp | ❓ | ✅ |

## Expedição (X1 a X4) · [[09-Expedicao]]

| Nó | Nome atual | Nome antigo | Rota | Repo | Slug | Estado |
|---|---|---|---|---|---|---|
| X1, X4 | Expedição | Embalagem e Logística de saída (10.1, 10.4) | `/logistica/expedicao` | app-pcp | `expedicao` | ✅ `expedicao/page.tsx:1-16`; pallets (`PalletsModal`), `ConfirmarEntregaModal` |
| X1 | Seção Embalagens do pedido | (10.1) | `/ordens-producao/[id]` | app-pcp | `ordens-producao` | ✅ `EmbalagensSection.tsx` |
| X3 | Consolidação de carga | (10.2) | — | app-pcp | — | 🔴 |
| X4 | Transporte e roteiro | (10.3) | — | app-pcp | — | 🔴 |

## Fiscal (O1, O2) · [[10-Fiscal-Omie]]

| Nó | Nome atual | Nome antigo | Rota | Repo | Slug | Estado |
|---|---|---|---|---|---|---|
| O1 | Fila de sinalização de faturamento | (11.1) | — | app-pcp | — | 🔴 |
| O2 | Notas Fiscais de Saída | — | `/vendas/notas-fiscais-saida` | HUB | ❓ | ✅ título `page.tsx:98` |
| O2 | Minhas Notas, Notas da Equipe, Notas do PCP | — | `/minhas-notas`, `/notas-equipe`, `/pcp-notas` | HUB | ❓ | ✅ pós-fato |

## Proposta, Orçamento e comissão nova (`V0`, `B1` a `B4`, `C6` a `C8`, `K1` a `K6`) · [[11-Proposta-e-Pedido-de-Venda]]

Telas novas do desenho aprovado em 26/10/2026, ainda sem código 🔴. A auditoria das telas que existem, as conexões e a página de proposta estão em [[14-Telas-e-Experiencia-do-Usuario]]; o menu em.

| Nós | Tela | Quem | Estado |
|---|---|---|---|
| `V0.1` a `V0.7`, `V0C` | Proposta (cinco blocos e um botão principal por estado) | vendedor | 🔴 (`api-comercial` de teste ✅) |
| `V1` a `V3`, `C8`, datas | Meus Pedidos: o pedido das duas origens, a parte de compras, as respostas, as pendências de compra acima do valor e o histórico de datas | vendedor | 🔴 |
| `B2` | Página do produto | vendedor, Orçamento, Compras | 🔴 |
| `B3`, `B4` | Orçamento · Pedidos de custo | setor de Orçamento | 🔴 (`api-comercial` de teste ✅) |
| `C6`, `C7` | Emitir OC com os dados do vendedor e imposto por item | comprador | 🔴 |
| `C8` | Compras · Reprovados | comprador | 🔴 |
| `O1` | Faturamento em partes (bloco do pedido) | Fiscal | 🔴 |
| datas | Calendário (exceções de feriado e dia útil por unidade) | marketing | 🔴 |
| `K1` a `K6` | Comissões novas: estimada, Minhas Comissões, fila e decisão da Controladoria, notas esperando a simulação, devoluções | vendedor, Controladoria, Gerência, Coordenação, Fiscal | 🔴 |

## Transversais

| Nome atual | Nome antigo | Rota | Repo | Estado |
|---|---|---|---|---|
| Login (Azure AD e usuário e senha) | T.1 | `/login` | app-pcp | ✅ `(public)/login/page.tsx` |
| Cadastros › Acessos: Usuários, Perfis, Permissões, Telas, Usuários por Perfil, Setores por Perfil, Depósitos por Perfil | T.2 | `/cadastros/acessos/usuarios`, `perfis`, `permissoes`, `telas`, `usuarios-perfis`, `setores-perfil`, `depositos-perfil` | app-pcp | ✅ ([[RBAC-e-Permissoes]]); `PerfilSetor` sem filial 🔴 |
| Torre de Fluxo (mapa, trilha, tempo por etapa, auditoria) | T.3 a T.6 | — | HUB | 🔴 nenhuma ocorrência de "torre" em `app`, `components` ou `lib` do HUB; API existe ([[Rastreabilidade-e-Torre-de-Fluxo]], [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas]]) |
| Inicial, Blank | — | `/`, `/blank` | app-pcp | ✅ |

## Renomeações pendentes no código

| Nome novo (título e vault) | Ainda no código |
|---|---|
| Triagem dos Pedidos | pasta e rota `carteira`; `GET /pedidos/carteira`; `services/carteira.ts` |
| Destinação do Pedido | rota `/ordens-producao/novo`; campo `ordemProducao`; códigos `OP-` |
| Acompanhamento dos Pedidos | rota `/ordens-producao`; permissão `ordens-producao` |
| Filas de Produção | rota `/movimentacoes`; permissão `movimentacoes` (também protege Entrega, Divergência e Recebimento) |
| Divergências de Recebimento | rota e slug `decisoes-pcp` |
| Compras · CCP | rota `/compras/pedidos-compra`; slug `pedidos-compra` |

Cabe ao Nathan decidir se rotas e slugs acompanham os títulos (muda `auth.telas` no av-hub e `telas` no MES, fora do repositório).
