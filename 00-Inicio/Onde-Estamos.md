---
tags: [inicio, status]
criado: 2026-10-14
atualizado: 2026-10-26
status: vigente
dono: Nathan
fontes: [00-Fluxo-Mestre-0b, notas de raia 02-Fluxo-de-Atividades, Registro-de-Decisoes (N16-01 a N16-106), Painel-de-Contratos de 26/10, api-pcp 579a625, app-pcp 1fca8d3, api-acos-vital f322dcd, HUB b55ac55, omie-elt-pipeline 0f739f0]
---

# Onde estamos (26/10/2026)

Estado do fluxo 0b por raia. O estado no código é o de 14/10/2026; a proposta, o Orçamento, a conferência de Compras (`C6` a `C8`) e a comissão nova foram desenhados e aprovados em 26/10/2026 e ainda não têm código na `api-acos-vital`. Detalhe e evidência em cada nota de raia; fila de trabalho em [[Backlog-por-Frente]].

| Raia | Nós | Estado | O que falta | Dono |
|---|---|---|---|---|
| [[11-Proposta-e-Pedido-de-Venda]] | V0.1–V0.7, V0C | 🔴 (desenho aprovado em 26/10) | Migrar o módulo do Pablo para a `api-acos-vital` (LOG-52); migração do `core_comercial` (SQL-016, testada em Postgres 18); tela da proposta no formato do Simulador; "Transformar em pedido"; pedido por API no Omie, por fila e pipeline (API-019, LOG-56) | Pablo, Gustavo, Nathan |
| [[12-Orcamento-Base-de-Preco]] | B1–B4 | 🔴 (desenho aprovado em 26/10) | Base de preço gerada das OCs (SQL-017); página do produto com score e volatilidade (LOG-60); pedido de custo sem prazo, com o tempo cronometrado (API-020) | Pablo, Gustavo, Nathan |
| [[01-Vendas-Liberacao]] | V1–V3 | ✅ liberação · 🔴 pedido no Hub | Pedido do Omie no mesmo fluxo do pedido da proposta (`core_comercial.pedidos`, N16-106); parte de compras e faturamento em partes na tela do pedido (LOG-58) | Nathan, Gustavo |
| [[02-PCP-Triagem-e-Destinacao]] | P1, P2, P6 | ✅ P1/P2 · 🔴 P6 | Novo norte (retrabalho ou reabre compra): `RoteiroItem` tem CRUD, mas nenhuma movimentação o lê; renomear rotas antigas; **OC do pedido** visível ao PCP; **Ordem de Produção** como entidade e documento imprimível (só para o que será fabricado) | Robert |
| [[03-Estoque-Atendimento-e-Despacho]] | E1–E6 | ✅ E1–E5 · 🔴 E6 | **Documento de retirada com baixa na retirada** (hoje baixa em `receber()`); custo do item (`GET /itens/custo`); fabricado virar lote; **saldo futuro** (saldo atual + OCs em andamento de estoque) | Robert |
| [[04-Circuito-de-Compra]] | P3, C0–C5, FN1 | ✅ ida e volta e aprovação (C3) · 🔴 MES ler a OC do hub (C0) | Aprovação já funciona (OC acima de R$ 30 mil: Gerente de Compras; até R$ 30 mil: compradores livres) e endurece depois com Compras 🟡; **o MES precisa ler as OCs do hub** (PCP vê a OC do pedido; Estoque vê o saldo futuro): job do contrato 004/007, telas e caminho de entrada no Recebimento; envio real da OC ao Omie testado em 14/10, produção ❓ | Robert, Gustavo |
| [[04-Circuito-de-Compra]] e [[11-Proposta-e-Pedido-de-Venda]] | C6–C8 | 🔴 (desenho aprovado em 26/10) | Conferência da parte de compras na emissão da OC; aviso de compra acima do custo do vendedor em Meus Pedidos e lista de reprovados de Compras (`divergencias_compra`, SQL-016, API-021) | Nathan, Gustavo |
| [[05-Recebimento]] | R0–R6 | ✅ | Gravar custo da OC no lote (`lote_custo`); cruzar com a OC quando existir o job do contrato 004 | Robert |
| [[06-Qualidade-Entrada]] | Q1–Q4 | ✅ | Recompra por RNC sem contrato | Robert, Gustavo |
| [[07-Producao-e-Roteiro]] | F1 | ✅ filas · 🔴 consumo | Consumo de matéria-prima; `EM_PRODUCAO` e `BLOQUEADO` nunca são gravados; divergência de produção sem tela | Robert |
| [[08-Qualidade-Saida]] | Q7, Q8 | 🟡 | Aprovado deve voltar ao Estoque (hoje vai à Expedição) | Robert |
| [[09-Expedicao]] | X1–X4 | 🟡 | Consolidar carga (10.2), transporte (10.3); integral travado por item que não chega (T-06) | Robert |
| [[10-Fiscal-Omie]] | O1, O2 | ✅ lado Omie · 🔴 sinalização | Contrato que ligue a Expedição à NF do Omie (11.1); faturamento em partes (sequenciais ligados ao item do pedido, SQL-016) e teste de como o Omie cria o sequencial (PS-037) | Robert, Gustavo, Nathan |
| [[13-Custo-Real-e-Comissao-no-Fluxo]] | K1–K6 | 🔴 (desenho aprovado em 26/10; SQL-018 testado em Postgres 18) | Schema `core_comissao` (SQL-018); motor na API; custo real por evento (API-021); fila e decisão da Controladoria (API-022, LOG-59); custo obrigatório em todo lote no MES | Gustavo, Nathan, Robert |

## Transversais

| Tema | Estado |
|---|---|
| Integração requisição MES ↔ av-hub (LOG-34, LOG-35) | ✅ ida e volta; sob demanda e polling de 5 min ([[Integracao-AvHub-MES]]) |
| Status por item (API-005, API-006) | ✅ |
| Torre de Fluxo (LOG-46) | 🟡 API e jobs no av-hub; o MES não publica `/fluxo/eventos`; o HUB não tem tela |
| Custo por item (API-008, LOG-47) | 🟡 `lote_custo` existe; faltam `GET /itens/custo` e custo da OC; a migration 047b não está no dump. O Ciclo 1 segue sem imposto; o modelo com impostos (ICMS, IPI, ST, frete) precisa ser desenhado já (PS-014, BL-053) |
| Cadastros TESTE no Omie | 🟡 O Omie não tem ambiente de teste; os cadastros TESTE do Nathan entram na pipeline e nos relatórios: filtrar ao conferir (BL-055) |
| Pendências cadastrais | Perfil CCP e vínculo de usuários à Gerência de Compras: serão criados em breve, assunto cadastral simples (Nathan e Gustavo), sem bloqueio de desenho |

## Próximos passos

Ordem por nó do 0b em [[Backlog-por-Frente]]. Pontas soltas em [[Pontas-Soltas]]; riscos em [[Riscos]].
