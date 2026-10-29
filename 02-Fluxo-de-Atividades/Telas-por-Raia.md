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

Esta nota lista cada tela do fluxo de Atividades ([[00-Fluxo-Mestre-0b]]), setor por setor, com o nome atual, o nome antigo, o sistema onde ela mora e se já existe.

## Como usar esta nota

- Procure o seu setor (raia) e ache o **nó do fluxo** e a tela que o atende.
- A coluna **Situação** diz em poucas palavras o que a tela faz e se ela existe.
- Rotas, identificadores de permissão e arquivos de código estão em "Detalhe técnico", no fim.

Os nomes novos já estão nos **títulos** do `app-pcp` (`9bb47e4`, #39: só rótulos). **Rotas, slugs, pastas e permissões seguem com os nomes antigos.** O texto do menu vem da tabela `telas` do banco, não do código ❓. A convenção de nomes está em [[Regras-do-Vault]].

Selos: ✅ existe no código · 🟡 parcial · 🔴 não existe · ❓ não conferido.

**Sistemas:** **HUB** é o front do av-hub (`b55ac55`, conferido em disco). **app-pcp** é o front do MES. As rotas do HUB passam pelo BFF (`app/api/...`).

## Vendas (V1 a V3) · [[01-Vendas-Liberacao]]

| Nó | Nome atual | Nome antigo | Sistema | Situação |
|---|---|---|---|---|
| V2, V3 | Liberar Pedidos | Caixa de entrada do vendedor (1.1) | HUB | ✅ O vendedor libera os pedidos. Fica em "Portal do Vendedor" |
| V2 (leitura) | Liberação da Equipe | Visão do gerente da 1.1 | HUB | ✅ Só leitura. Fica em "Portal do Gerente" |
| V1 a O2 | Meus Pedidos, detalhe com cartão Etapa dos itens | Meus Pedidos por etapa (1.2) | HUB | ✅ Já tem o cartão de etapa de cada item. 🟡 Falta linha do tempo, SLA e filtro |
| idem | Pedidos da Equipe, detalhe | idem | HUB | ✅ Mesmo cartão |
| — | Pedidos do PCP | Portal PCP | HUB | ✅ Acompanhamento comercial por diligenciador. **Não é o `app-pcp`** |

## PCP (P1, P2, P6) · [[02-PCP-Triagem-e-Destinacao]]

| Nó | Nome atual | Nome antigo | Sistema | Situação |
|---|---|---|---|---|
| P1 | Triagem dos Pedidos | Carteira (de Pedidos) | app-pcp | ✅ Existe |
| P2 | Destinação do Pedido | Nova Ordem de Produção | app-pcp | ✅ Existe |
| — | Acompanhamento dos Pedidos | Ordens de Produção (lista) | app-pcp | ✅ Existe |
| — | Acompanhamento dos Pedidos, detalhe | Ordem de Produção (detalhe) | app-pcp | ✅ Mostra mini-roteiro, histórico, anexos e embalagens. 🟡 Falta mostrar a parte atendida pelo estoque e a reserva |
| — | Pedidos excluídos | — | app-pcp | ✅ Guarda uma cópia do pedido excluído |
| P6 | Novo norte (retrabalho ou reabrir compra) | Fila "Novo norte" (2.5) | app-pcp | 🔴 Sem tela. A tela de decisões do PCP só trata recebimento |
| P1, P2 | OC do pedido (coluna ou cartão na Triagem e na Destinação) | — | app-pcp | 🔴 Não existe (N14-20, BL-049). O PCP deve ver que já há OC para o pedido |
| P2 | Ordem de Produção (entidade e documento imprimível, só do que será fabricado) | — | app-pcp | 🔴 Não existe (N14-22, BL-052) |

## Estoque (E1 a E6) · [[03-Estoque-Atendimento-e-Despacho]]

| Nó | Nome atual | Nome antigo | Sistema | Situação |
|---|---|---|---|---|
| E1 a E4 | Atendimento | Atendimento / Baixa (8.12) | app-pcp | ✅ Fila do setor Estoque, com a janela de atender |
| E5 (consulta) | Saldo | Consulta de Saldo (8.4) | app-pcp | ✅ Existe |
| E3 | Reservas | Reservas (8.5) | app-pcp | ✅ Existe |
| E6 (parcial) | Movimentação e Ajuste | Movimentação (8.6) | app-pcp | ✅ Entrada, saída, transferência e ajuste |
| E5 | Detalhe do lote | Detalhe do lote (8.7) | app-pcp | ✅ Mostra os movimentos e a etiqueta de código de barras |
| — | Painel do Estoque | Dashboard do Estoque | app-pcp | 🟡 Protótipo com dados de exemplo. Os alertas são reais |
| — | Mapa do Depósito | — | app-pcp | 🟡 Roda sobre dados de exemplo |
| — | Materiais, Depósitos | Cadastro de material, Depósitos (8.1, 8.2) | app-pcp | ✅ Usa a API real |
| E6 | Documento de retirada | — | app-pcp | 🔴 Não existe |
| E1 | Saldo futuro (no Atendimento e no Saldo: saldo atual + OCs em andamento de estoque) | — | app-pcp | 🔴 Não existe (N14-20, BL-050) |

## Compras e fornecedor (P3, C0 a C5, FN1) · [[04-Circuito-de-Compra]]

| Nó | Nome atual | Nome antigo | Sistema | Situação |
|---|---|---|---|---|
| P3 | Requisições de compras | Setor Compras (2.4), fila `requisicoes` | app-pcp | ✅ O "Solicitar compra" do Estoque cai aqui |
| C5 | Compras · CCP | Pedidos de Compra / Compras | app-pcp | ✅ Só leitura. Mostra a linha do tempo por material |
| C0, C1 | Requisições (caixa do Compras), "Nova requisição" | Caixa de entrada de Requisições (3.1) | HUB | ✅ Existe |
| C4 | Nova Ordem de Compra | Emissão da OC (3.2) | HUB | ✅ Existe |
| C4 | Ordens de Compra | Ordens de Compra (3.3) | HUB | ✅ Existe |
| C2, C3 | Aprovações | Fila de Aprovações (3.4) | HUB | ✅ Aprova só a OC acima de R$ 30 mil (Gerência de Compras). A Diretoria não entra (N14-21) |
| C5 | Follow-up | Follow-up do CCP (3.6) | HUB | ✅ Existe |
| — | Dashboard de Compras | (3.5) | HUB | ✅ Existe |
| — | Compradores | — | HUB | ✅ Cadastro de compradores que a OC usa (LOG-18, LOG-28, LOG-36) |
| FN1 | — | — | — | Externo, sem tela |

## Recebimento (R0 a R6) · [[05-Recebimento]]

| Nó | Nome atual | Nome antigo | Sistema | Situação |
|---|---|---|---|---|
| R0 a R4 | Recebimento | Logística de entrada | app-pcp | ✅ Mostra os esperados. Permite receber com NF, conferir e recontar |
| R6 | Divergências de Recebimento | Decisões do PCP | app-pcp | ✅ O PCP decide: aceito ou reaberto |
| R4 | Detalhe do lote, "Imprimir etiqueta" | (6.5) | app-pcp | ✅ Existe |
| — | Logística (índice) | — | app-pcp | ✅ Existe |

## Qualidade de entrada (Q1 a Q4) · [[06-Qualidade-Entrada]]

| Nó | Nome atual | Nome antigo | Sistema | Situação |
|---|---|---|---|---|
| Q1 a Q4 | Inspeção de entrada | Qualidade (mock) | app-pcp | ✅ Existe |
| — | Fila Qualidade · Entrada | — | app-pcp | ✅ Só leitura |

## Produção (F1) · [[07-Producao-e-Roteiro]]

| Nó | Nome atual | Nome antigo | Sistema | Situação |
|---|---|---|---|---|
| F1 | Filas de Produção (setores) | Movimentações | app-pcp | ✅ Existe |
| F1 | Fila do setor | Board do setor (7.1) | app-pcp | ✅ Tem 17 ações |
| — | Dashboard | Dashboard de produção (7.3) | app-pcp | ✅ Existe |
| — | Painel TV | (7.4) | app-pcp | 🔴 A parte do servidor existe, mas não há página |
| — | Fábricas, Setores, Máquinas, Operadores | Cadastros operacionais | app-pcp | ✅ Existe |
| — | Relatórios | — | app-pcp | ✅ Existe |

## Qualidade de saída (Q7, Q8) · [[08-Qualidade-Saida]]

| Nó | Nome atual | Nome antigo | Sistema | Situação |
|---|---|---|---|---|
| Q7, Q8 | Inspeção de saída | Fila do setor Qualidade no roteiro | app-pcp | ✅ Existe |
| Q7 | Qualidade (índice) | — | app-pcp | ✅ Existe |

## Expedição (X1 a X4) · [[09-Expedicao]]

| Nó | Nome atual | Nome antigo | Sistema | Situação |
|---|---|---|---|---|
| X1, X4 | Expedição | Embalagem e Logística de saída (10.1, 10.4) | app-pcp | ✅ Tem pallets e confirmação de entrega |
| X1 | Seção Embalagens do pedido | (10.1) | app-pcp | ✅ Existe |
| X3 | Consolidação de carga | (10.2) | app-pcp | 🔴 Não existe |
| X4 | Transporte e roteiro | (10.3) | app-pcp | 🔴 Não existe |

## Fiscal (O1, O2) · [[10-Fiscal-Omie]]

| Nó | Nome atual | Nome antigo | Sistema | Situação |
|---|---|---|---|---|
| O1 | Fila de sinalização de faturamento | (11.1) | app-pcp | 🔴 Não existe |
| O2 | Notas Fiscais de Saída | — | HUB | ✅ Existe |
| O2 | Minhas Notas, Notas da Equipe, Notas do PCP | — | HUB | ✅ Mostram as notas depois do fato |

## Proposta, Orçamento e comissão nova (`V0`, `B1` a `B4`, `C6` a `C8`, `K1` a `K6`) · [[11-Proposta-e-Pedido-de-Venda]]

Estas são as telas novas do desenho aprovado em 26/10/2026. Ainda **não têm código** 🔴. A auditoria das telas que existem, as conexões e a página de proposta estão em [[14-Telas-e-Experiencia-do-Usuario]]. O menu também está lá.

| Nós | Tela | Quem usa | Situação |
|---|---|---|---|
| `V0.1` a `V0.7`, `V0C` | Proposta (cinco blocos e um botão principal por estado) | Vendedor | 🔴 (`api-comercial` de teste ✅) |
| `V1` a `V3`, `C8`, datas | Meus Pedidos: o pedido das duas origens, a parte de compras, as respostas, as pendências de compra acima do valor e o histórico de datas | Vendedor | 🔴 |
| `B2` | Página do produto | Vendedor, Orçamento, Compras | 🔴 |
| `B3`, `B4` | Orçamento · Pedidos de custo | Setor de Orçamento | 🔴 (`api-comercial` de teste ✅) |
| `C6`, `C7` | Emitir OC com os dados do vendedor e imposto por item | Comprador | 🔴 |
| `C8` | Compras · Reprovados | Comprador | 🔴 |
| `O1` | Faturamento em partes (bloco do pedido) | Fiscal | 🔴 |
| datas | Calendário (exceções de feriado e dia útil por unidade) | Marketing | 🔴 |
| `K1` a `K6` | Comissões novas: estimada, Minhas Comissões, fila e decisão da Controladoria, notas esperando a simulação, devoluções | Vendedor, Controladoria, Gerência, Coordenação, Fiscal | 🔴 |

## Telas que servem a todos

| Nome atual | Nome antigo | Sistema | Situação |
|---|---|---|---|
| Login (Azure AD e usuário e senha) | T.1 | app-pcp | ✅ Existe |
| Cadastros › Acessos: Usuários, Perfis, Permissões, Telas, Usuários por Perfil, Setores por Perfil, Depósitos por Perfil | T.2 | app-pcp | ✅ Veja [[RBAC-e-Permissoes]]. 🔴 `PerfilSetor` ainda não tem filial |
| Torre de Fluxo (mapa, trilha, tempo por etapa, auditoria) | T.3 a T.6 | HUB | 🔴 Sem tela. A API existe ([[Rastreabilidade-e-Torre-de-Fluxo]], [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas]]) |
| Inicial, Blank | — | app-pcp | ✅ Existe |

## Nomes novos que ainda não chegaram ao código

| Nome novo (título e vault) | Ainda no código |
|---|---|
| Triagem dos Pedidos | Pasta e rota `carteira`; `GET /pedidos/carteira`; `services/carteira.ts` |
| Destinação do Pedido | Rota `/ordens-producao/novo`; campo `ordemProducao`; códigos `OP-` |
| Acompanhamento dos Pedidos | Rota `/ordens-producao`; permissão `ordens-producao` |
| Filas de Produção | Rota `/movimentacoes`; permissão `movimentacoes` (também protege Entrega, Divergência e Recebimento) |
| Divergências de Recebimento | Rota e slug `decisoes-pcp` |
| Compras · CCP | Rota `/compras/pedidos-compra`; slug `pedidos-compra` |

Cabe ao Nathan decidir se rotas e slugs acompanham os títulos. A mudança altera `auth.telas` no av-hub e `telas` no MES, fora do repositório.

## Detalhe técnico

Fontes: `app-pcp` `1fca8d3` (`app/(protected)/**/page.tsx` e títulos dos `PageHeader`), HUB `b55ac55` (`app/(protected)`, `components`), v1 Fluxograma-Telas-por-Bloco, [[00-Fluxo-Mestre-0b]] e [[Regras-do-Vault]]. As colunas "Slug" são os identificadores de `telaId` ou de permissão.

### Vendas

| Nome atual | Rota | Slug | Arquivo ou observação |
|---|---|---|---|
| Liberar Pedidos | `/liberar-pedidos` | `liberar-pedidos` | `app/(protected)/liberar-pedidos/page.tsx`; menu em "Portal do Vendedor" (`groupMap.ts:23`) |
| Liberação da Equipe | `/liberacao-equipe` | `liberacao-equipe` | "Portal do Gerente" (`groupMap.ts:27`) |
| Meus Pedidos, detalhe | `/meus-pedidos`, `/meus-pedidos/pedido/[codigoEmpresa]/[pedidoVenda]` | `meus-pedidos` | Cartão `components/Pedidos/EtapaDosItens.tsx`, usado em `PedidoDetalhe.tsx:812` |
| Pedidos da Equipe, detalhe | `/pedidos-equipe`, `/pedidos-equipe/pedido/...` | `pedidos-equipe` | Mesmo cartão |
| Pedidos do PCP | `/pcp-pedidos`, `/pcp-pedidos/pedido/...` | `pcp-pedidos` | Não é o `app-pcp` |

### PCP

| Nome atual | Rota | Slug | Arquivo ou observação |
|---|---|---|---|
| Triagem dos Pedidos | `/carteira` | `carteira` ❓ | Título em `carteira/page.tsx:178`; lê `GET /pedidos/carteira` |
| Destinação do Pedido | `/ordens-producao/novo` | `ordens-producao` | Título em `ordens-producao/novo/page.tsx:517`; `POST /pedidos/completo/lote` |
| Acompanhamento dos Pedidos | `/ordens-producao` | `ordens-producao` | Título em `ordens-producao/page.tsx:144` |
| Acompanhamento dos Pedidos, detalhe | `/ordens-producao/[id]` | `ordens-producao` | Mini-roteiro, histórico, anexos, embalagens; 🟡 falta mostrar o split atendido pelo estoque e a reserva |
| Pedidos excluídos | `/pedidos-excluidos` | ❓ | Snapshot de pedido excluído |
| Novo norte (retrabalho ou reabrir compra) | — | — | 🔴 Sem tela; `/decisoes-pcp` só trata recebimento |
| OC do pedido | `/carteira`, `/ordens-producao/novo` | — | 🔴 N14-20, BL-049 |
| Ordem de Produção (entidade e documento imprimível) | — | — | 🔴 N14-22, BL-052 |

### Estoque

| Nome atual | Rota | Slug | Arquivo ou observação |
|---|---|---|---|
| Atendimento | `/estoque-operacao/atendimento` | `atendimento` | `AtenderEstoqueModal` (título `atendimento/page.tsx:10`) |
| Saldo | `/estoque-operacao/saldo` | ❓ | Título `saldo/page.tsx:73` |
| Reservas | `/estoque-operacao/reservas` | ❓ | |
| Movimentação e Ajuste | `/estoque-operacao/movimentacao` | ❓ | `ENTRADA`, `SAIDA`, `TRANSFERENCIA`, `AJUSTE` |
| Detalhe do lote | `/estoque-operacao/lotes/[id]` | ❓ | Movimentos, etiqueta Code128 |
| Painel do Estoque | `/estoque-operacao/painel-estoque` | `painel-estoque` | Protótipo com dados de exemplo; alertas reais |
| Mapa do Depósito | `/estoque-operacao/mapa-deposito` | ❓ | Sobre `MOCK_DEPOSITOS` |
| Materiais, Depósitos | `/cadastros/estoque/materiais`, `/cadastros/estoque/depositos` | ❓ | API real |
| Documento de retirada | — | — | 🔴 |
| Saldo futuro | `/estoque-operacao/atendimento`, `/estoque-operacao/saldo` | — | 🔴 N14-20, BL-050 |

### Compras e fornecedor

| Nome atual | Rota | Slug | Arquivo ou observação |
|---|---|---|---|
| Requisições de compras (app-pcp) | `/compras/requisicoes` | `requisicoes` | `RequisitarCompraModal` ("Solicitar compra" do Estoque cai aqui); título `requisicoes/page.tsx:10` |
| Compras · CCP (app-pcp) | `/compras/pedidos-compra` (e `/compras`) | `pedidos-compra` | Só leitura; título `pedidos-compra/page.tsx:11`; linha do tempo por material, `EventosRequisicaoModal` |
| Requisições, "Nova requisição" (HUB) | `/compras/requisicoes`, `/compras/requisicoes/kanban` | ❓ | `components/Compras/ComprasRequisicoes.tsx:188`, `:426` |
| Nova Ordem de Compra | `/compras/nova`, `/compras/nova/[requisicaoId]` | ❓ | |
| Ordens de Compra | `/compras/ordens`, `/compras/ordens/kanban`, `/compras/ordem/[id]`, `/compras/pedido-omie/[id]` | ❓ | |
| Aprovações | `/compras/aprovacoes` | ❓ | Aprova só OC acima de R$ 30 mil (Gerência de Compras); sem Diretoria (N14-21) |
| Follow-up | `/compras/followup` | ❓ | |
| Dashboard de Compras | `/compras/dashboard-compras` | ❓ | |
| Compradores | `/compras/compradores` | ❓ | Cadastro usado pela OC (LOG-18, LOG-28, LOG-36) |

### Recebimento

| Nome atual | Rota | Slug | Arquivo ou observação |
|---|---|---|---|
| Recebimento | `/logistica/logistica-entrada` | `logistica-entrada` | Título `logistica-entrada/page.tsx:10`; esperados, "Receber com NF" (`ReceberComNfModal`), conferência (`ConferirRecebimentoModal`), recontagem (`RecontarRecebimentoModal`) |
| Divergências de Recebimento | `/decisoes-pcp` | `decisoes-pcp` | Título `decisoes-pcp/page.tsx:74`; `ACEITO` ou `REABERTO` |
| Detalhe do lote, "Imprimir etiqueta" | `/estoque-operacao/lotes/[id]` | ❓ | |
| Logística (índice) | `/logistica` | ❓ | |

### Qualidade de entrada

| Nome atual | Rota | Slug | Arquivo ou observação |
|---|---|---|---|
| Inspeção de entrada | `/qualidade/inspecao-entrada` | `inspecao-entrada` | Título `inspecao-entrada/page.tsx:117` |
| Fila Qualidade · Entrada | `/movimentacoes/[setorId]` (setor `qualidade-entrada`) | `movimentacoes` | Só leitura (`acoes.ts:98-100`) |

### Produção

| Nome atual | Rota | Slug | Arquivo ou observação |
|---|---|---|---|
| Filas de Produção (setores) | `/movimentacoes` | `movimentacoes` | Título `movimentacoes/page.tsx:121` |
| Fila do setor | `/movimentacoes/[setorId]` | `movimentacoes` | `FilaSetor.tsx`, 17 ações |
| Dashboard | `/dashboard` | ❓ | |
| Painel TV | — | — | 🔴 Backend `GET /dashboard/tv` sem página |
| Fábricas, Setores, Máquinas, Operadores | `/cadastros/operacional/fabricas`, `setores`, `maquinas`, `operadores` | ❓ | |
| Relatórios | `/relatorios` | ❓ | |

### Qualidade de saída

| Nome atual | Rota | Slug | Arquivo ou observação |
|---|---|---|---|
| Inspeção de saída | `/qualidade/inspecao-saida` | `inspecao-saida` | `inspecao-saida/page.tsx:1-18` |
| Qualidade (índice) | `/qualidade` | ❓ | |

### Expedição

| Nome atual | Rota | Slug | Arquivo ou observação |
|---|---|---|---|
| Expedição | `/logistica/expedicao` | `expedicao` | `expedicao/page.tsx:1-16`; pallets (`PalletsModal`), `ConfirmarEntregaModal` |
| Seção Embalagens do pedido | `/ordens-producao/[id]` | `ordens-producao` | `EmbalagensSection.tsx` |
| Consolidação de carga | — | — | 🔴 |
| Transporte e roteiro | — | — | 🔴 |

### Fiscal

| Nome atual | Rota | Slug | Arquivo ou observação |
|---|---|---|---|
| Fila de sinalização de faturamento | — | — | 🔴 |
| Notas Fiscais de Saída | `/vendas/notas-fiscais-saida` | ❓ | Título `page.tsx:98` |
| Minhas Notas, Notas da Equipe, Notas do PCP | `/minhas-notas`, `/notas-equipe`, `/pcp-notas` | ❓ | Pós-fato |

### Telas que servem a todos

| Nome atual | Rota | Observação |
|---|---|---|
| Login | `/login` | `(public)/login/page.tsx` |
| Cadastros › Acessos | `/cadastros/acessos/usuarios`, `perfis`, `permissoes`, `telas`, `usuarios-perfis`, `setores-perfil`, `depositos-perfil` | `PerfilSetor` sem filial 🔴 |
| Torre de Fluxo | — | Nenhuma ocorrência de "torre" em `app`, `components` ou `lib` do HUB |
| Inicial, Blank | `/`, `/blank` | |
