---
tags: [fluxo, telas, rotas, raias, referencia]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [app-pcp 1fca8d3 (app/(protected)/**/page.tsx, títulos dos PageHeader), HUB b55ac55 em disco (app/(protected), components), v1 Fluxograma-Telas-por-Bloco, 00-Fluxo-Mestre-0b, Regras-do-Vault]
---

# Telas por raia

## Em uma frase

Esta nota lista cada tela do fluxo de Atividades ([[00-Fluxo-Mestre-0b]]), setor por setor: o que ela faz, quem usa e se já existe.

## Como usar esta nota

- Ache o seu setor no **Mapa rápido** logo abaixo e vá à seção dele.
- O nó do fluxo vai entre parênteses. Rotas, slugs, arquivos, nomes antigos e o sistema (HUB ou app-pcp) estão em "Detalhe técnico", no fim.

Os nomes novos já estão nos títulos do `app-pcp`; rotas, slugs e permissões seguem com os nomes antigos (ver "Detalhe técnico"). Convenção de nomes: [[Regras-do-Vault]].

Selos: ✅ existe · 🟡 parcial · 🔴 não existe · ❓ não conferido.

## Mapa rápido por setor

| Setor (nós) | O que as telas fazem | Situação |
|---|---|---|
| Vendas · V1 a V3 | Liberar e acompanhar pedido e etapa dos itens | ✅ 🟡 |
| PCP · P1, P2, P6 | Triar e destinar. Faltam Novo norte, OC do pedido, Ordem de Produção | ✅ 🔴 |
| Estoque · E1 a E6 | Atender, consultar, movimentar. Faltam retirada e saldo futuro | ✅ 🟡 🔴 |
| Compras · P3, C0 a C5 | Da requisição à OC | ✅ |
| Recebimento · R0 a R6 | Receber, conferir, decidir divergência | ✅ |
| Qualidade de entrada · Q1 a Q4 | Inspecionar o que chegou | ✅ |
| Produção · F1 | Tocar a fábrica. Falta o Painel TV | ✅ 🔴 |
| Qualidade de saída · Q7, Q8 | Aprovar o fabricado | ✅ |
| Expedição · X1 a X4 | Pallets e entrega. Faltam carga e transporte | ✅ 🔴 |
| Fiscal · O1, O2 | Ver notas depois do fato. Falta a sinalização | ✅ 🔴 |
| Proposta, Orçamento, comissão | Telas novas de 26/10/2026 | 🔴 |
| Todos | Login, Acessos, Inicial. Falta a Torre de Fluxo | ✅ 🔴 |

## Vendas (V1 a V3) · [[01-Vendas-Liberacao]]

| Tela | Para que serve | Quem usa | Situação |
|---|---|---|---|
| Liberar Pedidos (V2, V3) | O vendedor libera os pedidos. Menu "Portal do Vendedor" | Vendedor | ✅ |
| Liberação da Equipe (V2, leitura) | Só leitura. Menu "Portal do Gerente" | Gerente | ✅ |
| Meus Pedidos, detalhe (V1 a O2) | Cartão Etapa dos itens. 🟡 Falta linha do tempo, SLA e filtro | Vendedor | ✅ |
| Pedidos da Equipe, detalhe | Mesmo cartão de etapa, para a equipe | Gerente | ✅ |
| Pedidos do PCP | Acompanhamento comercial por diligenciador. **Não é o `app-pcp`** | Diligenciador | ✅ |

## PCP (P1, P2, P6) · [[02-PCP-Triagem-e-Destinacao]]

| Tela | Para que serve | Quem usa | Situação |
|---|---|---|---|
| Triagem dos Pedidos (P1) | Primeira análise do pedido liberado | PCP | ✅ |
| Destinação do Pedido (P2) | Define a destinação do pedido | PCP | ✅ |
| Acompanhamento dos Pedidos | Lista dos pedidos em andamento | PCP | ✅ |
| Acompanhamento dos Pedidos, detalhe | Mini-roteiro, histórico, anexos, embalagens. 🟡 Falta a parte atendida pelo estoque e a reserva | PCP | ✅ |
| Pedidos excluídos | Guarda uma cópia do pedido excluído | PCP | ✅ |
| Novo norte (P6) | Retrabalho ou reabrir compra; a tela de decisões só trata recebimento | PCP | 🔴 |
| OC do pedido (P1, P2) | Mostrar na Triagem e na Destinação que já há OC (N14-20, BL-049) | PCP | 🔴 |
| Ordem de Produção (P2) | Documento imprimível do que será fabricado (N14-22, BL-052) | PCP | 🔴 |

## Estoque (E1 a E6) · [[03-Estoque-Atendimento-e-Despacho]]

| Tela | Para que serve | Quem usa | Situação |
|---|---|---|---|
| Atendimento (E1 a E4) | Fila do setor, com a janela de atender | Estoque | ✅ |
| Saldo (E5, consulta) | Consulta de saldo | Estoque | ✅ |
| Reservas (E3) | Consulta das reservas | Estoque | ✅ |
| Movimentação e Ajuste (E6, parcial) | Entrada, saída, transferência e ajuste | Estoque | ✅ |
| Detalhe do lote (E5) | Movimentos do lote e etiqueta de código de barras | Estoque | ✅ |
| Painel do Estoque | Protótipo com dados de exemplo. Os alertas são reais | Estoque | 🟡 |
| Mapa do Depósito | Roda sobre dados de exemplo | Estoque | 🟡 |
| Materiais, Depósitos | Cadastros, com a API real | Estoque | ✅ |
| Documento de retirada (E6) | Não existe | Estoque | 🔴 |
| Saldo futuro (E1) | Saldo atual + OCs em andamento (N14-20, BL-050) | Estoque | 🔴 |

## Compras e fornecedor (P3, C0 a C5, FN1) · [[04-Circuito-de-Compra]]

| Tela | Para que serve | Quem usa | Situação |
|---|---|---|---|
| Requisições de compras (P3) | O "Solicitar compra" do Estoque cai aqui | Compras | ✅ |
| Compras · CCP (C5) | Só leitura. Linha do tempo por material | Compras | ✅ |
| Requisições, "Nova requisição" (C0, C1) | Caixa de entrada do Compras | Comprador | ✅ |
| Nova Ordem de Compra (C4) | Emissão da OC | Comprador | ✅ |
| Ordens de Compra (C4) | Lista das OC | Comprador | ✅ |
| Aprovações (C2, C3) | Só OC acima de R$ 30 mil; sem Diretoria (N14-21) | Gerência de Compras | ✅ |
| Follow-up (C5) | Follow-up do CCP | Comprador | ✅ |
| Dashboard de Compras | Painel de Compras | Compras | ✅ |
| Compradores | Cadastro usado pela OC (LOG-18, LOG-28, LOG-36) | Compras | ✅ |
| Fornecedor (FN1) | Externo, sem tela | Fornecedor | — |

## Recebimento (R0 a R6) · [[05-Recebimento]]

| Tela | Para que serve | Quem usa | Situação |
|---|---|---|---|
| Recebimento (R0 a R4) | Mostra os esperados. Recebe com NF, confere e reconta | Operador do Recebimento | ✅ |
| Divergências de Recebimento (R6) | O PCP decide: aceito ou reaberto | PCP | ✅ |
| Detalhe do lote, "Imprimir etiqueta" (R4) | Imprime a etiqueta do lote | Operador do Recebimento | ✅ |
| Logística (índice) | Índice da área | Operador do Recebimento | ✅ |

## Qualidade de entrada (Q1 a Q4) · [[06-Qualidade-Entrada]]

| Tela | Para que serve | Quem usa | Situação |
|---|---|---|---|
| Inspeção de entrada (Q1 a Q4) | Inspeção do material recebido | Qualidade | ✅ |
| Fila Qualidade · Entrada | Só leitura | Qualidade | ✅ |

## Produção (F1) · [[07-Producao-e-Roteiro]]

| Tela | Para que serve | Quem usa | Situação |
|---|---|---|---|
| Filas de Produção, setores (F1) | Lista dos setores de produção | Operador, PCP | ✅ |
| Fila do setor (F1) | Tela de trabalho do setor, com 17 ações | Operador | ✅ |
| Dashboard | Dashboard de produção | PCP | ✅ |
| Painel TV | A parte do servidor existe, mas não há página | Chão de fábrica | 🔴 |
| Fábricas, Setores, Máquinas, Operadores | Cadastros operacionais | PCP | ✅ |
| Relatórios | Relatórios de produção | PCP | ✅ |

## Qualidade de saída (Q7, Q8) · [[08-Qualidade-Saida]]

| Tela | Para que serve | Quem usa | Situação |
|---|---|---|---|
| Inspeção de saída (Q7, Q8) | Fila do setor Qualidade no roteiro | Qualidade | ✅ |
| Qualidade, índice (Q7) | Índice da área | Qualidade | ✅ |

## Expedição (X1 a X4) · [[09-Expedicao]]

| Tela | Para que serve | Quem usa | Situação |
|---|---|---|---|
| Expedição (X1, X4) | Pallets e confirmação de entrega | Operador da Embalagem e da Logística | ✅ |
| Seção Embalagens do pedido (X1) | Embalagens dentro do detalhe do pedido | PCP | ✅ |
| Consolidação de carga (X3) | Não existe | Logística | 🔴 |
| Transporte e roteiro (X4) | Não existe | Logística | 🔴 |

## Fiscal (O1, O2) · [[10-Fiscal-Omie]]

| Tela | Para que serve | Quem usa | Situação |
|---|---|---|---|
| Fila de sinalização de faturamento (O1) | Não existe | Logística, Faturamento | 🔴 |
| Notas Fiscais de Saída (O2) | Lista das notas emitidas | Vendedor | ✅ |
| Minhas Notas, Notas da Equipe, Notas do PCP (O2) | Mostram as notas depois do fato | Vendedor, gerente, PCP | ✅ |

## Proposta, Orçamento e comissão nova (`V0`, `B1` a `B4`, `C6` a `C8`, `K1` a `K6`) · [[11-Proposta-e-Pedido-de-Venda]]

Desenho aprovado em 26/10/2026, ainda **sem código** 🔴. Auditoria, conexões e menu: [[14-Telas-e-Experiencia-do-Usuario]].

| Tela | Para que serve | Quem usa | Situação |
|---|---|---|---|
| Proposta (`V0.1` a `V0.7`, `V0C`) | Cinco blocos e um botão principal por estado | Vendedor | 🔴 (`api-comercial` de teste ✅) |
| Meus Pedidos (`V1` a `V3`, `C8`, datas) | Pedido das duas origens, parte de compras, respostas, pendências de compra acima do valor, histórico de datas | Vendedor | 🔴 |
| Página do produto (`B2`) | Consulta de preço e fornecedores | Vendedor, Orçamento, Compras | 🔴 |
| Orçamento · Pedidos de custo (`B3`, `B4`) | Fila de pedidos de custo | Setor de Orçamento | 🔴 (`api-comercial` de teste ✅) |
| Emitir OC (`C6`, `C7`) | Com os dados do vendedor e imposto por item | Comprador | 🔴 |
| Compras · Reprovados (`C8`) | Casos reprovados pelo vendedor | Comprador | 🔴 |
| Faturamento em partes (`O1`) | Bloco do pedido | Fiscal | 🔴 |
| Calendário (datas) | Exceções de feriado e dia útil por unidade | Marketing | 🔴 |
| Comissões novas (`K1` a `K6`) | Estimada, Minhas Comissões, fila e decisão da Controladoria, notas esperando a simulação, devoluções | Vendedor, Controladoria, Gerência, Coordenação, Fiscal | 🔴 |

## Telas que servem a todos

| Tela | Para que serve | Quem usa | Situação |
|---|---|---|---|
| Login (T.1) | Azure AD e usuário e senha | Todos | ✅ |
| Cadastros › Acessos (T.2) | Usuários, Perfis, Permissões, Telas e vínculos ([[RBAC-e-Permissoes]]). 🔴 `PerfilSetor` sem filial | Administrador | ✅ |
| Torre de Fluxo (T.3 a T.6) | Mapa, trilha, tempo, auditoria. Sem tela; API existe ([[Rastreabilidade-e-Torre-de-Fluxo]], [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas]]) | Gestão | 🔴 |
| Inicial, Blank | Páginas básicas | Todos | ✅ |

## Detalhe técnico

Fontes: `app-pcp` `1fca8d3` (`app/(protected)/**/page.tsx` e títulos dos `PageHeader`), HUB `b55ac55` (`app/(protected)`, `components`), v1 Fluxograma-Telas-por-Bloco, [[00-Fluxo-Mestre-0b]] e [[Regras-do-Vault]]. As colunas "Slug" são os identificadores de `telaId` ou de permissão. Nó, nome antigo e sistema vêm das tabelas por setor da versão anterior desta nota.

Os nomes novos já estão nos **títulos** do `app-pcp` (`9bb47e4`, #39: só rótulos). **Rotas, slugs, pastas e permissões seguem com os nomes antigos.** O texto do menu vem da tabela `telas` do banco, não do código ❓. A convenção de nomes está em [[Regras-do-Vault]]. Cabe ao Nathan decidir se rotas e slugs acompanham os títulos; isso altera `auth.telas` no av-hub e `telas` no MES, fora do repositório.

**Sistemas:** **HUB** é o front do av-hub (`b55ac55`, conferido em disco). **app-pcp** é o front do MES. As rotas do HUB passam pelo BFF (`app/api/...`).

### Vendas

| Nó | Nome atual | Nome antigo | Sistema | Rota | Slug | Arquivo ou observação |
|---|---|---|---|---|---|---|
| V2, V3 | Liberar Pedidos | Caixa de entrada do vendedor (1.1) | HUB | `/liberar-pedidos` | `liberar-pedidos` | `app/(protected)/liberar-pedidos/page.tsx`; menu em "Portal do Vendedor" (`groupMap.ts:23`) |
| V2 (leitura) | Liberação da Equipe | Visão do gerente da 1.1 | HUB | `/liberacao-equipe` | `liberacao-equipe` | "Portal do Gerente" (`groupMap.ts:27`) |
| V1 a O2 | Meus Pedidos, detalhe com cartão Etapa dos itens | Meus Pedidos por etapa (1.2) | HUB | `/meus-pedidos`, `/meus-pedidos/pedido/[codigoEmpresa]/[pedidoVenda]` | `meus-pedidos` | Cartão `components/Pedidos/EtapaDosItens.tsx`, usado em `PedidoDetalhe.tsx:812` |
| idem | Pedidos da Equipe, detalhe | idem | HUB | `/pedidos-equipe`, `/pedidos-equipe/pedido/...` | `pedidos-equipe` | Mesmo cartão |
| — | Pedidos do PCP | Portal PCP | HUB | `/pcp-pedidos`, `/pcp-pedidos/pedido/...` | `pcp-pedidos` | Não é o `app-pcp` |

### PCP

| Nó | Nome atual | Nome antigo | Sistema | Rota | Slug | Arquivo ou observação |
|---|---|---|---|---|---|---|
| P1 | Triagem dos Pedidos | Carteira (de Pedidos) | app-pcp | `/carteira` | `carteira` ❓ | Título em `carteira/page.tsx:178`; lê `GET /pedidos/carteira` |
| P2 | Destinação do Pedido | Nova Ordem de Produção | app-pcp | `/ordens-producao/novo` | `ordens-producao` | Título em `ordens-producao/novo/page.tsx:517`; `POST /pedidos/completo/lote` |
| — | Acompanhamento dos Pedidos | Ordens de Produção (lista) | app-pcp | `/ordens-producao` | `ordens-producao` | Título em `ordens-producao/page.tsx:144` |
| — | Acompanhamento dos Pedidos, detalhe | Ordem de Produção (detalhe) | app-pcp | `/ordens-producao/[id]` | `ordens-producao` | Mini-roteiro, histórico, anexos, embalagens; 🟡 falta mostrar o split atendido pelo estoque e a reserva |
| — | Pedidos excluídos | — | app-pcp | `/pedidos-excluidos` | ❓ | Snapshot de pedido excluído |
| P6 | Novo norte (retrabalho ou reabrir compra) | Fila "Novo norte" (2.5) | app-pcp | — | — | 🔴 Sem tela; `/decisoes-pcp` só trata recebimento |
| P1, P2 | OC do pedido (coluna ou cartão na Triagem e na Destinação) | — | app-pcp | `/carteira`, `/ordens-producao/novo` | — | 🔴 N14-20, BL-049 |
| P2 | Ordem de Produção (entidade e documento imprimível, só do que será fabricado) | — | app-pcp | — | — | 🔴 N14-22, BL-052 |

### Estoque

| Nó | Nome atual | Nome antigo | Sistema | Rota | Slug | Arquivo ou observação |
|---|---|---|---|---|---|---|
| E1 a E4 | Atendimento | Atendimento / Baixa (8.12) | app-pcp | `/estoque-operacao/atendimento` | `atendimento` | `AtenderEstoqueModal` (título `atendimento/page.tsx:10`) |
| E5 (consulta) | Saldo | Consulta de Saldo (8.4) | app-pcp | `/estoque-operacao/saldo` | ❓ | Título `saldo/page.tsx:73` |
| E3 | Reservas | Reservas (8.5) | app-pcp | `/estoque-operacao/reservas` | ❓ |  |
| E6 (parcial) | Movimentação e Ajuste | Movimentação (8.6) | app-pcp | `/estoque-operacao/movimentacao` | ❓ | `ENTRADA`, `SAIDA`, `TRANSFERENCIA`, `AJUSTE` |
| E5 | Detalhe do lote | Detalhe do lote (8.7) | app-pcp | `/estoque-operacao/lotes/[id]` | ❓ | Movimentos, etiqueta Code128 |
| — | Painel do Estoque | Dashboard do Estoque | app-pcp | `/estoque-operacao/painel-estoque` | `painel-estoque` | Protótipo com dados de exemplo; alertas reais |
| — | Mapa do Depósito | — | app-pcp | `/estoque-operacao/mapa-deposito` | ❓ | Sobre `MOCK_DEPOSITOS` |
| — | Materiais, Depósitos | Cadastro de material, Depósitos (8.1, 8.2) | app-pcp | `/cadastros/estoque/materiais`, `/cadastros/estoque/depositos` | ❓ | API real |
| E6 | Documento de retirada | — | app-pcp | — | — | 🔴 |
| E1 | Saldo futuro (no Atendimento e no Saldo: saldo atual + OCs em andamento de estoque) | — | app-pcp | `/estoque-operacao/atendimento`, `/estoque-operacao/saldo` | — | 🔴 N14-20, BL-050 |

### Compras e fornecedor

| Nó | Nome atual | Nome antigo | Sistema | Rota | Slug | Arquivo ou observação |
|---|---|---|---|---|---|---|
| P3 | Requisições de compras | Setor Compras (2.4), fila `requisicoes` | app-pcp | `/compras/requisicoes` | `requisicoes` | `RequisitarCompraModal` ("Solicitar compra" do Estoque cai aqui); título `requisicoes/page.tsx:10` |
| C5 | Compras · CCP | Pedidos de Compra / Compras | app-pcp | `/compras/pedidos-compra` (e `/compras`) | `pedidos-compra` | Só leitura; título `pedidos-compra/page.tsx:11`; linha do tempo por material, `EventosRequisicaoModal` |
| C0, C1 | Requisições (caixa do Compras), "Nova requisição" | Caixa de entrada de Requisições (3.1) | HUB | `/compras/requisicoes`, `/compras/requisicoes/kanban` | ❓ | `components/Compras/ComprasRequisicoes.tsx:188`, `:426` |
| C4 | Nova Ordem de Compra | Emissão da OC (3.2) | HUB | `/compras/nova`, `/compras/nova/[requisicaoId]` | ❓ |  |
| C4 | Ordens de Compra | Ordens de Compra (3.3) | HUB | `/compras/ordens`, `/compras/ordens/kanban`, `/compras/ordem/[id]`, `/compras/pedido-omie/[id]` | ❓ |  |
| C2, C3 | Aprovações | Fila de Aprovações (3.4) | HUB | `/compras/aprovacoes` | ❓ | Aprova só OC acima de R$ 30 mil (Gerência de Compras); sem Diretoria (N14-21) |
| C5 | Follow-up | Follow-up do CCP (3.6) | HUB | `/compras/followup` | ❓ |  |
| — | Dashboard de Compras | (3.5) | HUB | `/compras/dashboard-compras` | ❓ |  |
| — | Compradores | — | HUB | `/compras/compradores` | ❓ | Cadastro usado pela OC (LOG-18, LOG-28, LOG-36) |
| FN1 | — | — | — | — | — | — |

### Recebimento

| Nó | Nome atual | Nome antigo | Sistema | Rota | Slug | Arquivo ou observação |
|---|---|---|---|---|---|---|
| R0 a R4 | Recebimento | Logística de entrada | app-pcp | `/logistica/logistica-entrada` | `logistica-entrada` | Título `logistica-entrada/page.tsx:10`; esperados, "Receber com NF" (`ReceberComNfModal`), conferência (`ConferirRecebimentoModal`), recontagem (`RecontarRecebimentoModal`) |
| R6 | Divergências de Recebimento | Decisões do PCP | app-pcp | `/decisoes-pcp` | `decisoes-pcp` | Título `decisoes-pcp/page.tsx:74`; `ACEITO` ou `REABERTO` |
| R4 | Detalhe do lote, "Imprimir etiqueta" | (6.5) | app-pcp | `/estoque-operacao/lotes/[id]` | ❓ |  |
| — | Logística (índice) | — | app-pcp | `/logistica` | ❓ |  |

### Qualidade de entrada

| Nó | Nome atual | Nome antigo | Sistema | Rota | Slug | Arquivo ou observação |
|---|---|---|---|---|---|---|
| Q1 a Q4 | Inspeção de entrada | Qualidade (mock) | app-pcp | `/qualidade/inspecao-entrada` | `inspecao-entrada` | Título `inspecao-entrada/page.tsx:117` |
| — | Fila Qualidade · Entrada | — | app-pcp | `/movimentacoes/[setorId]` (setor `qualidade-entrada`) | `movimentacoes` | Só leitura (`acoes.ts:98-100`) |

### Produção

| Nó | Nome atual | Nome antigo | Sistema | Rota | Slug | Arquivo ou observação |
|---|---|---|---|---|---|---|
| F1 | Filas de Produção (setores) | Movimentações | app-pcp | `/movimentacoes` | `movimentacoes` | Título `movimentacoes/page.tsx:121` |
| F1 | Fila do setor | Board do setor (7.1) | app-pcp | `/movimentacoes/[setorId]` | `movimentacoes` | `FilaSetor.tsx`, 17 ações |
| — | Dashboard | Dashboard de produção (7.3) | app-pcp | `/dashboard` | ❓ |  |
| — | Painel TV | (7.4) | app-pcp | — | — | 🔴 Backend `GET /dashboard/tv` sem página |
| — | Fábricas, Setores, Máquinas, Operadores | Cadastros operacionais | app-pcp | `/cadastros/operacional/fabricas`, `setores`, `maquinas`, `operadores` | ❓ |  |
| — | Relatórios | — | app-pcp | `/relatorios` | ❓ |  |

### Qualidade de saída

| Nó | Nome atual | Nome antigo | Sistema | Rota | Slug | Arquivo ou observação |
|---|---|---|---|---|---|---|
| Q7, Q8 | Inspeção de saída | Fila do setor Qualidade no roteiro | app-pcp | `/qualidade/inspecao-saida` | `inspecao-saida` | `inspecao-saida/page.tsx:1-18` |
| Q7 | Qualidade (índice) | — | app-pcp | `/qualidade` | ❓ |  |

### Expedição

| Nó | Nome atual | Nome antigo | Sistema | Rota | Slug | Arquivo ou observação |
|---|---|---|---|---|---|---|
| X1, X4 | Expedição | Embalagem e Logística de saída (10.1, 10.4) | app-pcp | `/logistica/expedicao` | `expedicao` | `expedicao/page.tsx:1-16`; pallets (`PalletsModal`), `ConfirmarEntregaModal` |
| X1 | Seção Embalagens do pedido | (10.1) | app-pcp | `/ordens-producao/[id]` | `ordens-producao` | `EmbalagensSection.tsx` |
| X3 | Consolidação de carga | (10.2) | app-pcp | — | — | 🔴 |
| X4 | Transporte e roteiro | (10.3) | app-pcp | — | — | 🔴 |

### Fiscal

| Nó | Nome atual | Nome antigo | Sistema | Rota | Slug | Arquivo ou observação |
|---|---|---|---|---|---|---|
| O1 | Fila de sinalização de faturamento | (11.1) | app-pcp | — | — | 🔴 |
| O2 | Notas Fiscais de Saída | — | HUB | `/vendas/notas-fiscais-saida` | ❓ | Título `page.tsx:98` |
| O2 | Minhas Notas, Notas da Equipe, Notas do PCP | — | HUB | `/minhas-notas`, `/notas-equipe`, `/pcp-notas` | ❓ | Pós-fato |

### Telas que servem a todos

| Nome atual | Nome antigo | Sistema | Rota | Observação |
|---|---|---|---|---|
| Login (Azure AD e usuário e senha) | T.1 | app-pcp | `/login` | `(public)/login/page.tsx` |
| Cadastros › Acessos: Usuários, Perfis, Permissões, Telas, Usuários por Perfil, Setores por Perfil, Depósitos por Perfil | T.2 | app-pcp | `/cadastros/acessos/usuarios`, `perfis`, `permissoes`, `telas`, `usuarios-perfis`, `setores-perfil`, `depositos-perfil` | `PerfilSetor` sem filial 🔴 |
| Torre de Fluxo (mapa, trilha, tempo por etapa, auditoria) | T.3 a T.6 | HUB | — | Nenhuma ocorrência de "torre" em `app`, `components` ou `lib` do HUB |
| Inicial, Blank | — | app-pcp | `/`, `/blank` |  |

### Nomes novos que ainda não chegaram ao código

| Nome novo (título e vault) | Ainda no código |
|---|---|
| Triagem dos Pedidos | Pasta e rota `carteira`; `GET /pedidos/carteira`; `services/carteira.ts` |
| Destinação do Pedido | Rota `/ordens-producao/novo`; campo `ordemProducao`; códigos `OP-` |
| Acompanhamento dos Pedidos | Rota `/ordens-producao`; permissão `ordens-producao` |
| Filas de Produção | Rota `/movimentacoes`; permissão `movimentacoes` (também protege Entrega, Divergência e Recebimento) |
| Divergências de Recebimento | Rota e slug `decisoes-pcp` |
| Compras · CCP | Rota `/compras/pedidos-compra`; slug `pedidos-compra` |
