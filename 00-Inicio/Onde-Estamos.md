---
tags: [inicio, status]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [00-Fluxo-Mestre-0b, notas de raia 02-Fluxo-de-Atividades, Registro-de-Decisoes (N16-01 a N16-144), Painel-de-Contratos de 29/10, develop do api-pcp e do app-pcp (27/10), develop da api-acos-vital (29/10), develop do av-hub (29/10), omie-elt-pipeline 0f739f0]
---

# Onde estamos (estado de 29/10/2026)

**Em uma frase:** o fluxo do pedido já funciona da liberação ao recebimento, e a OP, o lote do fabricado e o custo por item já estão na `develop` do MES; o que falta é, sobretudo, o pedido da proposta no Omie, o Orçamento, a comissão nova e levar o MES para a `main`.

**Quando consultar esta nota:** quando você precisar saber o que está pronto, o que falta e quem toca cada setor.

O estado do código é o de 29/10/2026 (`develop` do MES, da `api-acos-vital` e do av-hub). A `main` do MES parou em 08/10: a OP, o lote do fabricado e o custo por item (26 e 27/10) estão só na `develop` (BL-035). A API da proposta e as telas já existem; o Orçamento, a conferência de Compras (`C6` a `C8`) e a comissão nova ainda não têm código. A fila de trabalho está em [[Backlog-por-Frente]].

## Resumo por setor

| Setor | Como está | Quem toca | O que falta |
|---|---|---|---|
| [[11-Proposta-e-Pedido-de-Venda]] | 🟡 API e telas da proposta existem na `develop`; falta o pedido no Omie | Robert (rotas e telas), Gustavo, Pablo acompanha | Confirmar no banco o "Transformar em pedido"; enviar o pedido ao Omie por fila; motor da comissão na API; decidir o schema (`core_comercial` ou `core_vendas_faturamento`, N16-116) |
| [[12-Orcamento-Base-de-Preco]] | 🟡 Menu e abas no front; o resto sem código | Pablo, Robert, Gustavo | Base de preço gerada das compras; página do produto com score e volatilidade; pedido de custo ao Orçamento |
| [[01-Vendas-Liberacao]] | ✅ Liberação funciona · 🔴 pedido no Hub | Nathan, Gustavo | Pedido do Omie no mesmo fluxo do pedido da proposta; compras e faturamento em partes na tela do pedido |
| [[02-PCP-Triagem-e-Destinacao]] | ✅ Triagem e Destinação · 🔴 volta de reprovado | Robert | Caminho para o item reprovado (retrabalho ou nova compra); mostrar a OC do pedido ao PCP. A Ordem de Produção já é emitida e impressa e a Triagem mostra as requisições do hub (`develop`, 23 e 27/10) |
| [[03-Estoque-Atendimento-e-Despacho]] | ✅ Atendimento · 🔴 despacho | Robert | Documento de retirada com baixa na retirada; saldo futuro. O custo do item e o fabricado virando lote já estão na `develop` (27/10) |
| [[04-Circuito-de-Compra]] | ✅ Compra, aprovação e envio ao Omie · ✅ o MES lê a OC (`develop`) | Robert, Gustavo | Mostrar a OC do pedido ao PCP e o saldo futuro; regra de aprovação definitiva com Compras |
| Conferência de Compras (`C6` a `C8`) | 🔴 Desenhada e aprovada, sem código | Nathan, Gustavo | Conferir a parte do vendedor ao emitir a OC; avisar o vendedor se a compra sair mais cara |
| [[05-Recebimento]] | ✅ Recebimento por OC e por NF na `develop` | Robert | Conferir contra a OC (preço, quantidade, fornecedor, N16-135); rateio da chegada; testar em homologação |
| [[06-Qualidade-Entrada]] | ✅ Pronto | Robert, Gustavo | Recompra por RNC (relatório de não conformidade) ainda sem contrato |
| [[07-Producao-e-Roteiro]] | ✅ Filas · 🔴 consumo | Robert | Baixar a matéria-prima consumida; gravar os status `EM_PRODUCAO` e `BLOQUEADO`; tela de divergência de produção |
| [[08-Qualidade-Saida]] | 🟡 Parcial | Robert | O aprovado já volta ao Estoque como lote `PRODUCAO` (`develop`, 27/10); confirmar se ainda sobra porta direta na Expedição |
| [[09-Expedicao]] | 🟡 Parcial | Robert | Consolidar carga; transporte; resolver o pedido integral travado por item que não chega; confirmar as portas de entrada |
| [[10-Fiscal-Omie]] | ✅ Lado Omie · 🔴 aviso do MES | Robert, Gustavo, Nathan | Ligar a Expedição à nota do Omie; faturamento em partes; testar como o Omie cria o sequencial |
| [[13-Custo-Real-e-Comissao-no-Fluxo]] | 🔴 Desenhado e aprovado, sem código | Gustavo, Nathan, Robert | Schema novo da comissão; motor de cálculo; custo real por evento; decisão da Controladoria; custo obrigatório em todo lote |

## Assuntos que cruzam os setores

| Tema | Como está |
|---|---|
| Requisição MES ↔ av-hub | ✅ Funciona nos dois sentidos, por pedido imediato e por consulta a cada 5 minutos |
| Status por item | ✅ Pronto |
| Torre de Fluxo (painel de acompanhamento) | 🟡 API, rotinas e telas prontas no av-hub (telas sobre dados de exemplo, desde 15/10); o MES não envia os eventos; nenhum perfil de negócio recebe as telas ainda |
| Custo por item | 🟡 O lote nasce com o custo da OC e o MES publica `GET /itens/custo` (27/10, na `develop`); falta o hub ler. O Ciclo 1 segue sem imposto; o modelo com impostos foi desenhado em 29/10 (N16-144) |
| Cadastros TESTE no Omie | 🟡 O Omie não tem ambiente de teste. Os cadastros TESTE do Nathan entram nos relatórios: filtre ao conferir |
| Pendências de cadastro | O perfil CCP e o vínculo de usuários à Gerência de Compras saem em breve. É cadastro simples e não trava o desenho |

## Próximos passos

A ordem por nó do 0b está em [[Backlog-por-Frente]]. As pontas soltas estão em [[Pontas-Soltas]] e os riscos em [[Riscos]].

## Detalhe técnico

Versão completa da tabela por setor, com os nós do [[00-Fluxo-Mestre-0b]] e o dono de cada pendência.

| Raia | Nós | Estado | O que falta | Dono |
|---|---|---|---|---|
| [[11-Proposta-e-Pedido-de-Venda]] | V0.1–V0.7, V0C | 🟡 API e telas da proposta na `develop` | A rota de proposta (criar, revisar, aprovar, cancelar, copiar, transformar) existe na `api-acos-vital` e as telas, no av-hub, com o Robert; falta confirmar o banco do "Transformar em pedido", o pedido por API no Omie, por fila e pipeline, e decidir o schema (N16-116 diz `core_vendas_faturamento`, o código usa `core_comercial`); estados `ABERTA`, `APROVADA`, `TRANSFORMADA`, `CANCELADA` e `EXPIRADA` (validade sem decisão N16) | Robert, Gustavo, Pablo acompanha |
| [[12-Orcamento-Base-de-Preco]] | B1–B4 | 🟡 menu e abas no front | Base de preço gerada das OCs; página do produto com score e volatilidade; pedido de custo sem prazo, com o tempo cronometrado | Pablo, Robert, Gustavo |
| [[01-Vendas-Liberacao]] | V1–V3 | ✅ liberação · 🔴 pedido no Hub | Pedido do Omie no mesmo fluxo do pedido da proposta (N16-106); parte de compras e faturamento em partes na tela do pedido | Nathan, Gustavo |
| [[02-PCP-Triagem-e-Destinacao]] | P1, P2, P6 | ✅ P1/P2 · 🔴 P6 | Novo norte (retrabalho ou reabre compra): o motor passou a ler o `RoteiroItem`, mas a volta de reprovado segue sem tela; renomear rotas antigas; **OC do pedido** visível ao PCP. ✅ **Ordem de Produção** emitida na criação e imprimível (27/10, `develop`); ✅ requisições do hub na Triagem (23/10) | Robert |
| [[03-Estoque-Atendimento-e-Despacho]] | E1–E6 | ✅ E1–E5 · 🔴 E6 | **Documento de retirada com baixa na retirada** (hoje baixa em `receber()`); ✅ custo do item (`GET /itens/custo`) e fabricado virando lote `PRODUCAO` (27/10, `develop`); **saldo futuro** (saldo atual + OCs em andamento de estoque) | Robert |
| [[04-Circuito-de-Compra]] | P3, C0–C5, FN1 | ✅ ida e volta e aprovação (C3) · ✅ o MES lê a OC do hub (C0, `develop`) | Aprovação já funciona (OC acima de R$ 30 mil: Gerente de Compras; até R$ 30 mil: compradores livres) e endurece depois com Compras 🟡; o MES já lê as OCs (K4, 15/10) e a referência das requisições (23/10); falta mostrar a OC do pedido ao PCP e o saldo futuro ao Estoque; envio real da OC ao Omie testado em 14/10, produção ❓ | Robert, Gustavo |
| [[04-Circuito-de-Compra]] e [[11-Proposta-e-Pedido-de-Venda]] | C6–C8 | 🔴 (desenho aprovado em 26/10) | Conferência da parte de compras na emissão da OC; aviso de compra acima do custo do vendedor em Meus Pedidos e lista de reprovados de Compras (`divergencias_compra`) | Nathan, Gustavo |
| [[05-Recebimento]] | R0–R6 | ✅ | ✅ custo da OC no lote, recebimento por OC e por NF (várias OCs na mesma nota, N16-136) na `develop`; falta a conferência contra a OC (N16-135), o rateio da chegada e testar em homologação | Robert |
| [[06-Qualidade-Entrada]] | Q1–Q4 | ✅ | Recompra por RNC sem contrato | Robert, Gustavo |
| [[07-Producao-e-Roteiro]] | F1 | ✅ filas · 🔴 consumo | Consumo de matéria-prima; `EM_PRODUCAO` e `BLOQUEADO` nunca são gravados; divergência de produção sem tela | Robert |
| [[08-Qualidade-Saida]] | Q7, Q8 | 🟡 | ✅ `aprovar-saida` e `receber-fabricado`: o aprovado volta ao Estoque como lote `PRODUCAO` (`develop`, 27/10); confirmar se ainda sobra porta direta na Expedição | Robert |
| [[09-Expedicao]] | X1–X4 | 🟡 | Consolidar carga (10.2), transporte (10.3); integral travado por item que não chega (T-06); confirmar as portas de entrada depois do fabricado voltar ao Estoque | Robert |
| [[10-Fiscal-Omie]] | O1, O2 | ✅ lado Omie · 🔴 sinalização | Contrato que ligue a Expedição à NF do Omie (11.1); faturamento em partes (sequenciais ligados ao item do pedido) e teste de como o Omie cria o sequencial (PS-037) | Robert, Gustavo, Nathan |
| [[13-Custo-Real-e-Comissao-no-Fluxo]] | K1–K6 | 🔴 (desenho aprovado em 26/10) | Schema `core_comissao`; motor na API; custo real por evento; fila e decisão da Controladoria; custo obrigatório em todo lote no MES | Gustavo, Nathan, Robert |

Transversais, na versão técnica:

| Tema | Estado |
|---|---|
| Integração requisição MES ↔ av-hub (LOG-34, LOG-35) | ✅ ida e volta; sob demanda e polling de 5 min ([[Integracao-AvHub-MES]]) |
| Status por item (API-005, API-006) | ✅ |
| Torre de Fluxo (LOG-46) | 🟡 API e jobs no av-hub; BFF `/api/fluxo/*` e 4 telas no HUB sobre dados de exemplo (15/10); o MES não publica `/fluxo/eventos`; a 046b só deu as telas ao perfil de testes do time de TI (BL-021) |
| Custo por item (API-008, LOG-47) | 🟡 `lote_custo` nasce com o custo da OC (19/10) e `GET /itens/custo` está publicada na `develop` do MES (27/10); falta o hub ler e subir para a `main`. O Ciclo 1 segue sem imposto; o modelo com impostos foi desenhado em 29/10 (N16-144); falta código; a fórmula do custo com imposto segue o motor do comissionamento, e cada setor confere as mudanças na implementação |
| Cadastros TESTE no Omie | 🟡 O Omie não tem ambiente de teste; os cadastros TESTE do Nathan entram na pipeline e nos relatórios: filtrar ao conferir (BL-055) |
| Pendências cadastrais | Perfil CCP e vínculo de usuários à Gerência de Compras: serão criados em breve, assunto cadastral simples (Nathan e Gustavo), sem bloqueio de desenho |
