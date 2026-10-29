---
tags: [inicio, status]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [00-Fluxo-Mestre-0b, notas de raia 02-Fluxo-de-Atividades, Registro-de-Decisoes (N16-01 a N16-106), Painel-de-Contratos de 26/10, api-pcp 579a625, app-pcp 1fca8d3, api-acos-vital f322dcd, HUB b55ac55, omie-elt-pipeline 0f739f0]
---

# Onde estamos (estado de 26/10/2026)

**Em uma frase:** o fluxo do pedido já funciona da liberação ao recebimento; o que falta é, sobretudo, a proposta, o Orçamento, a comissão nova e alguns elos entre o MES e o Hub.

**Quando consultar esta nota:** quando você precisar saber o que está pronto, o que falta e quem toca cada setor.

O estado do código é o de 14/10/2026. A proposta, o Orçamento, a conferência de Compras (`C6` a `C8`) e a comissão nova foram desenhados e aprovados em 26/10/2026. Ainda não têm código na `api-acos-vital`, a API do Hub. A fila de trabalho está em [[Backlog-por-Frente]].

## Resumo por setor

| Setor | Como está | Quem toca | O que falta |
|---|---|---|---|
| [[11-Proposta-e-Pedido-de-Venda]] | 🔴 Desenhado e aprovado, sem código | Pablo, Gustavo, Nathan | Levar o módulo do Pablo para a API do Hub; criar a tela da proposta; o botão "Transformar em pedido"; enviar o pedido ao Omie por fila |
| [[12-Orcamento-Base-de-Preco]] | 🔴 Desenhado e aprovado, sem código | Pablo, Gustavo, Nathan | Base de preço gerada das compras; página do produto com score e volatilidade; pedido de custo ao Orçamento |
| [[01-Vendas-Liberacao]] | ✅ Liberação funciona · 🔴 pedido no Hub | Nathan, Gustavo | Pedido do Omie no mesmo fluxo do pedido da proposta; compras e faturamento em partes na tela do pedido |
| [[02-PCP-Triagem-e-Destinacao]] | ✅ Triagem e Destinação · 🔴 volta de reprovado | Robert | Caminho para o item reprovado (retrabalho ou nova compra); mostrar a OC do pedido ao PCP; criar a Ordem de Produção (entidade e documento impresso) |
| [[03-Estoque-Atendimento-e-Despacho]] | ✅ Atendimento · 🔴 despacho | Robert | Documento de retirada com baixa na retirada; custo do item; fabricado virar lote; saldo futuro |
| [[04-Circuito-de-Compra]] | ✅ Compra, aprovação e envio ao Omie · 🔴 MES ler a OC | Robert, Gustavo | O MES ler as OCs do Hub; regra de aprovação definitiva com Compras |
| Conferência de Compras (`C6` a `C8`) | 🔴 Desenhada e aprovada, sem código | Nathan, Gustavo | Conferir a parte do vendedor ao emitir a OC; avisar o vendedor se a compra sair mais cara |
| [[05-Recebimento]] | ✅ Pronto | Robert | Gravar o custo da OC no lote; cruzar com a OC |
| [[06-Qualidade-Entrada]] | ✅ Pronto | Robert, Gustavo | Recompra por RNC (relatório de não conformidade) ainda sem contrato |
| [[07-Producao-e-Roteiro]] | ✅ Filas · 🔴 consumo | Robert | Baixar a matéria-prima consumida; gravar os status `EM_PRODUCAO` e `BLOQUEADO`; tela de divergência de produção |
| [[08-Qualidade-Saida]] | 🟡 Parcial | Robert | O item aprovado deve voltar ao Estoque (hoje vai à Expedição) |
| [[09-Expedicao]] | 🟡 Parcial | Robert | Consolidar carga; transporte; resolver o pedido integral travado por item que não chega |
| [[10-Fiscal-Omie]] | ✅ Lado Omie · 🔴 aviso do MES | Robert, Gustavo, Nathan | Ligar a Expedição à nota do Omie; faturamento em partes; testar como o Omie cria o sequencial |
| [[13-Custo-Real-e-Comissao-no-Fluxo]] | 🔴 Desenhado e aprovado, sem código | Gustavo, Nathan, Robert | Schema novo da comissão; motor de cálculo; custo real por evento; decisão da Controladoria; custo obrigatório em todo lote |

## Assuntos que cruzam os setores

| Tema | Como está |
|---|---|
| Requisição MES ↔ av-hub | ✅ Funciona nos dois sentidos, por pedido imediato e por consulta a cada 5 minutos |
| Status por item | ✅ Pronto |
| Torre de Fluxo (painel de acompanhamento) | 🟡 API e rotinas prontas no av-hub; o MES não envia os eventos e o HUB não tem a tela |
| Custo por item | 🟡 O custo do lote existe, mas faltam o custo da OC e a consulta `GET /itens/custo`. O Ciclo 1 segue sem imposto; o modelo com impostos precisa ser desenhado já |
| Cadastros TESTE no Omie | 🟡 O Omie não tem ambiente de teste. Os cadastros TESTE do Nathan entram nos relatórios: filtre ao conferir |
| Pendências de cadastro | O perfil CCP e o vínculo de usuários à Gerência de Compras saem em breve. É cadastro simples e não trava o desenho |

## Próximos passos

A ordem por nó do 0b está em [[Backlog-por-Frente]]. As pontas soltas estão em [[Pontas-Soltas]] e os riscos em [[Riscos]].

## Detalhe técnico

Versão completa da tabela por setor, com os nós do [[00-Fluxo-Mestre-0b]] e o dono de cada pendência.

| Raia | Nós | Estado | O que falta | Dono |
|---|---|---|---|---|
| [[11-Proposta-e-Pedido-de-Venda]] | V0.1–V0.7, V0C | 🔴 (desenho aprovado em 26/10) | Migrar o módulo do Pablo para a `api-acos-vital` (LOG-52), **sem a cópia do Omie, o fechamento parcial e o Histórico de compras** e com o menu enxuto (27/10); migração do `core_comercial`; tela da proposta no formato do Simulador; "Transformar em pedido"; pedido por API no Omie, por fila e pipeline | Pablo, Gustavo, Nathan |
| [[12-Orcamento-Base-de-Preco]] | B1–B4 | 🔴 (desenho aprovado em 26/10) | Base de preço gerada das OCs; página do produto com score e volatilidade; pedido de custo sem prazo, com o tempo cronometrado | Pablo, Gustavo, Nathan |
| [[01-Vendas-Liberacao]] | V1–V3 | ✅ liberação · 🔴 pedido no Hub | Pedido do Omie no mesmo fluxo do pedido da proposta (`core_comercial.pedidos`, N16-106); parte de compras e faturamento em partes na tela do pedido | Nathan, Gustavo |
| [[02-PCP-Triagem-e-Destinacao]] | P1, P2, P6 | ✅ P1/P2 · 🔴 P6 | Novo norte (retrabalho ou reabre compra): `RoteiroItem` tem CRUD, mas nenhuma movimentação o lê; renomear rotas antigas; **OC do pedido** visível ao PCP; **Ordem de Produção** como entidade e documento imprimível (só para o que será fabricado) | Robert |
| [[03-Estoque-Atendimento-e-Despacho]] | E1–E6 | ✅ E1–E5 · 🔴 E6 | **Documento de retirada com baixa na retirada** (hoje baixa em `receber()`); custo do item (`GET /itens/custo`); fabricado virar lote; **saldo futuro** (saldo atual + OCs em andamento de estoque) | Robert |
| [[04-Circuito-de-Compra]] | P3, C0–C5, FN1 | ✅ ida e volta e aprovação (C3) · 🔴 MES ler a OC do hub (C0) | Aprovação já funciona (OC acima de R$ 30 mil: Gerente de Compras; até R$ 30 mil: compradores livres) e endurece depois com Compras 🟡; **o MES precisa ler as OCs do hub** (PCP vê a OC do pedido; Estoque vê o saldo futuro): job do contrato 004/007, telas e caminho de entrada no Recebimento; envio real da OC ao Omie testado em 14/10, produção ❓ | Robert, Gustavo |
| [[04-Circuito-de-Compra]] e [[11-Proposta-e-Pedido-de-Venda]] | C6–C8 | 🔴 (desenho aprovado em 26/10) | Conferência da parte de compras na emissão da OC; aviso de compra acima do custo do vendedor em Meus Pedidos e lista de reprovados de Compras (`divergencias_compra`) | Nathan, Gustavo |
| [[05-Recebimento]] | R0–R6 | ✅ | Gravar custo da OC no lote (`lote_custo`); cruzar com a OC quando existir o job do contrato 004 | Robert |
| [[06-Qualidade-Entrada]] | Q1–Q4 | ✅ | Recompra por RNC sem contrato | Robert, Gustavo |
| [[07-Producao-e-Roteiro]] | F1 | ✅ filas · 🔴 consumo | Consumo de matéria-prima; `EM_PRODUCAO` e `BLOQUEADO` nunca são gravados; divergência de produção sem tela | Robert |
| [[08-Qualidade-Saida]] | Q7, Q8 | 🟡 | Aprovado deve voltar ao Estoque (hoje vai à Expedição) | Robert |
| [[09-Expedicao]] | X1–X4 | 🟡 | Consolidar carga (10.2), transporte (10.3); integral travado por item que não chega (T-06) | Robert |
| [[10-Fiscal-Omie]] | O1, O2 | ✅ lado Omie · 🔴 sinalização | Contrato que ligue a Expedição à NF do Omie (11.1); faturamento em partes (sequenciais ligados ao item do pedido) e teste de como o Omie cria o sequencial (PS-037) | Robert, Gustavo, Nathan |
| [[13-Custo-Real-e-Comissao-no-Fluxo]] | K1–K6 | 🔴 (desenho aprovado em 26/10) | Schema `core_comissao`; motor na API; custo real por evento; fila e decisão da Controladoria; custo obrigatório em todo lote no MES | Gustavo, Nathan, Robert |

Transversais, na versão técnica:

| Tema | Estado |
|---|---|
| Integração requisição MES ↔ av-hub (LOG-34, LOG-35) | ✅ ida e volta; sob demanda e polling de 5 min ([[Integracao-AvHub-MES]]) |
| Status por item (API-005, API-006) | ✅ |
| Torre de Fluxo (LOG-46) | 🟡 API e jobs no av-hub; o MES não publica `/fluxo/eventos`; o HUB não tem tela |
| Custo por item (API-008, LOG-47) | 🟡 `lote_custo` existe; faltam `GET /itens/custo` e custo da OC; a migration 047b não está no dump. O Ciclo 1 segue sem imposto; o modelo com impostos (ICMS, IPI, ST, frete) precisa ser desenhado já (PS-014, BL-053) |
| Cadastros TESTE no Omie | 🟡 O Omie não tem ambiente de teste; os cadastros TESTE do Nathan entram na pipeline e nos relatórios: filtrar ao conferir (BL-055) |
| Pendências cadastrais | Perfil CCP e vínculo de usuários à Gerência de Compras: serão criados em breve, assunto cadastral simples (Nathan e Gustavo), sem bloqueio de desenho |
