---
tags: [inicio, status]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [00-Fluxo-Mestre-0b, notas de raia 02-Fluxo-de-Atividades, api-pcp 579a625, app-pcp 1fca8d3, api-acos-vital f322dcd, HUB b55ac55, omie-elt-pipeline 0f739f0]
---

# Onde estamos (14/10/2026)

Estado do fluxo 0b por raia. Detalhe e evidência em cada nota de raia; fila de trabalho em [[Backlog-por-Frente]].

| Raia | Nós | Estado | O que falta | Dono |
|---|---|---|---|---|
| [[01-Vendas-Liberacao]] | V1–V3 | ✅ | — | Nathan |
| [[02-PCP-Triagem-e-Destinacao]] | P1, P2, P6 | ✅ P1/P2 · 🔴 P6 | Novo norte (retrabalho ou reabre compra): `RoteiroItem` tem CRUD, mas nenhuma movimentação o lê; renomear rotas antigas | Robert |
| [[03-Estoque-Atendimento-e-Despacho]] | E1–E6 | ✅ E1–E5 · 🔴 E6 | **Documento de retirada com baixa na retirada** (hoje baixa em `receber()`); custo do item (`GET /itens/custo`); fabricado virar lote | Robert |
| [[04-Circuito-de-Compra]] | P3, C0–C5, FN1 | ✅ ida e volta · 🟡 C3 · 🔴 C0→MES | Aprovação em dois níveis (Gerente sempre; Diretoria acima de R$ 30 mil) não existe no código; requisição criada no av-hub não chega ao MES; job do contrato 004 | Gustavo, Robert |
| [[05-Recebimento]] | R0–R6 | ✅ | Gravar custo da OC no lote (`lote_custo`); cruzar com a OC quando existir o job do contrato 004 | Robert |
| [[06-Qualidade-Entrada]] | Q1–Q4 | ✅ | Recompra por RNC sem contrato | Robert, Gustavo |
| [[07-Producao-e-Roteiro]] | F1 | ✅ filas · 🔴 consumo | Consumo de matéria-prima; `EM_PRODUCAO` e `BLOQUEADO` nunca são gravados; divergência de produção sem tela | Robert |
| [[08-Qualidade-Saida]] | Q7, Q8 | 🟡 | Aprovado deve voltar ao Estoque (hoje vai à Expedição) | Robert |
| [[09-Expedicao]] | X1–X4 | 🟡 | Consolidar carga (10.2), transporte (10.3); integral travado por item que não chega (T-06) | Robert |
| [[10-Fiscal-Omie]] | O1, O2 | ✅ lado Omie · 🔴 sinalização | Contrato que ligue a Expedição à NF do Omie (11.1) | Robert, Gustavo |

## Transversais

| Tema | Estado |
|---|---|
| Integração requisição MES ↔ av-hub (LOG-34, LOG-35) | ✅ ida e volta; sob demanda e polling de 5 min ([[Integracao-AvHub-MES]]) |
| Status por item (API-005, API-006) | ✅ |
| Torre de Fluxo (LOG-46) | 🟡 API e jobs no av-hub; o MES não publica `/fluxo/eventos`; o HUB não tem tela |
| Custo por item (API-008, LOG-47) | 🟡 `lote_custo` existe; faltam `GET /itens/custo` e custo da OC; a migration 047b não está no dump |

## Próximos passos

Ordem por nó do 0b em [[Backlog-por-Frente]]. Pontas soltas em [[Pontas-Soltas]]; riscos em [[Riscos]].
