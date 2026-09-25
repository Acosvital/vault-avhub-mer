---
tags: [erp-acos-vital, arquitetura, estados, revisao, proposta]
criado: 2026-09-21
---

# Revisão dos estados, status e etapas — problemas e correções propostas

> **Status: revisão crítica de 21/09/2026, com propostas. Nada aqui é decisão.** Feita **lendo os documentos**, não o código do MES nem do av-hub; onde a proposta depende de como o código realmente se comporta, está marcado **(confirmar com o Robert)**. Cobre os diagramas de estado de [[Diagramas-UML]] (seções 5 a 8 e 20), os fluxos de [[Fluxogramas-Completos]] e o vocabulário de etapas de [[Rastreabilidade-e-SLA-de-Eventos]], incluindo as falhas do que eu mesmo propus.

## 1. Veredito

O **núcleo do MES está bem construído**: o `ItemParcial` (8 estados) com escrita condicional contra concorrência e histórico imutável, a quarentena por padrão, a cisão de lote e a regra "nenhum estado é beco sem saída". O que **não está** bem construído é o que fica entre os sistemas e o que ainda não tem máquina de estados. Os itens 1 a 3 afetam a D1 e a spec F1 desta semana.

| # | Problema | Gravidade | Afeta |
|---|---|---|---|
| 1 | Status por item não funciona quando o item é dividido em parciais | **Crítica** | F1, Portal, SLA |
| 2 | Lote filho congelado é estado terminal; reprovação total não modelada | **Crítica** | D1, D6–D8 |
| 3 | Seis entidades com `status` e sem máquina de estados | **Crítica** | D1, E1, E2, D6 |
| 4 | Reserva de estoque mistura duas origens e contradiz a quarentena | Alta | D9, C8 |
| 5 | Meu vocabulário de etapas é inventado, misturando tempo interno e de terceiros | Alta | F1, SLA |
| 6 | `EM_DESPACHO` tem dois significados | Média | Portal |
| 7 | `CANCELADO` tem dois significados | Média | Relatórios |
| 8 | Quatro vocabulários de status concorrem; cancelamento do pedido não está modelado | Média | Integração |

---

## 2. Problemas e correções

### 2.1 Status por item com parciais (crítica)
**O problema.** O `ItemParcial` divide o lote (`split`), então um item de 100 un pode ter 60 em produção e 40 em compra. O diagrama de 9 estados do vendedor supõe **um estado por item**, e nenhuma regra diz como juntar os estados das parciais.

**Proposta.**
- **Duas camadas:** o **item** (o que o vendedor vê) e a **parcial** (o lote em trânsito). O estado do item é calculado a partir das parciais.
- **Regra de agregação:** se todas as parciais estão no mesmo estado, o item tem esse estado. Se não, o item mostra a **composição** ("60% em produção, 40% em compra"). Para atraso e SLA vale a **parcial mais atrasada**.
- **Campos:** o evento passa a carregar `quantidade` e `id_item_parcial`; nova tabela filha `fluxo.item_acompanhado_parte` (`id_item_acompanhado`, `etapa_fluxo`, `quantidade`).
- **SLA por parcial.** O item está atrasado se qualquer parcial estiver.
- **Perguntar:** o cliente pode receber entrega parcial (a entidade `Entrega` existe)? Se sim, o item pode estar parcialmente `FATURADO`.

**✅ Resolvido em 21/09/2026 (Nathan) — regra de atraso simplificada.** Em vez de estimar atraso por item/parcial individualmente (o roteiro pode ser dinâmico, não dá pra confiar nisso), o atraso é medido **no nível do pedido**: quando a `data de previsão de produção` do pedido chegar, o sistema verifica quantos itens ainda não estão concluídos e lista esses itens como atrasados, agrupados por setor onde estão parados. Exemplo: pedido com 100 itens, 60 concluídos na data prevista → 40 atrasados, mostrados como "20 no Corte, 20 na Furação". A camada de **composição por parcial** (`fluxo.item_acompanhado_parte`, acima) continua valendo pra descrever *onde* o item está agora — a regra nova é só sobre *quando* considerar algo atrasado, mais simples que rastrear atraso parcial a parcial.

### 2.2 Lote: estado terminal sem saída (crítica)
**O problema.** No diagrama de Lote/Qualidade, `LOTE_FILHO_CONGELADO` é terminal ("aguardando devolução/RNC"). Não diz o que acontece depois da devolução, do descarte ou de um reteste. A reprovação de 100% do lote também não está modelada (a cisão só cobre a reprovação parcial). Isso quebra a regra do próprio projeto. Além disso, `status_qualidade` mistura "o que a qualidade decidiu" com "o que aconteceu fisicamente".

**Proposta.** Dois eixos independentes em `LOTE`:
- `status_qualidade`: `PENDENTE`, `APROVADO`, `REPROVADO` (só o resultado do laudo).
- `situacao_lote`: `EM_QUARENTENA`, `DISPONIVEL`, `CONGELADO`, `DEVOLVIDO`, `DESCARTADO`, `EM_RETRABALHO`, `CONSUMIDO`.
- **Saídas de `CONGELADO`**, cada uma com evento e `autorizado_por`: `DEVOLVIDO` (RNC fechada pela nota de devolução), `DESCARTADO`, `EM_RETRABALHO` (volta a `PENDENTE` para novo laudo) ou **aceite com restrição** (concessão, autorizada por alguém acima da Qualidade).
- **Reprovação total:** o lote inteiro vira `CONGELADO`, sem cisão.
- **Perguntar à Qualidade:** existe concessão (aceitar lote fora de especificação)? Quem autoriza?

### 2.3 Entidades com `status` e sem máquina de estados (crítica)
Só `ItemParcial`, Divergência, Lote, Reserva e o status do vendedor têm diagrama. Faltam as que o ciclo 1 constrói. Proposta mínima, para discutir com Pablo e Robert:

| Entidade | Estados propostos | Saídas que precisam existir |
|---|---|---|
| **Requisição de compra** (av-hub) | `ABERTA` → `ASSUMIDA` → `ATENDIDA` (OC emitida) | `CANCELADA`; `DEVOLVIDA_AO_PCP` (informação insuficiente), que abre nova requisição (C16) |
| **Ordem de Compra** (av-hub) | `RASCUNHO` → `AGUARDANDO_APROVACAO` (só se acima do limite) → `APROVADA` → `EMITIDA` → `PARCIALMENTE_RECEBIDA` → `RECEBIDA` | `REJEITADA` (volta a `RASCUNHO`), `CANCELADA`, `ENCERRADA` (fornecedor não vai entregar o restante) |
| **Recebimento** (MES) | `AGUARDANDO_CONFERENCIA` → `CONFERENCIA_QUANTITATIVA` → `CONFERENCIA_QUALITATIVA` → `CONCLUIDO` | `DIVERGENTE` (aceitar com ressalva, complementar, recusar), `RECUSADO` (devolvido ao fornecedor) |
| **RNC** (MES) | `ABERTA` → `AGUARDANDO_DECISAO_DO_PCP` → `AGUARDANDO_DEVOLUCAO` → `FECHADA` | `FECHADA_MANUALMENTE` (a Qualidade fecha, como no ciclo 1), `CANCELADA` |
| **Ordem de separação, Devolução, Contagem cíclica** | Fase D | Não modelar agora |

Recebimento e Lote precisam estar definidos **antes da D1**; Requisição e OC, antes de E1/E2.

### 2.4 Reserva de estoque (alta)
**O problema.** A reserva nasce de duas origens diferentes, misturadas no mesmo diagrama: (a) o PCP marca "tem em estoque" sobre saldo já aprovado e (b) a **destinação** feita na compra reserva algo que ainda não chegou. O diagrama confirma a reserva "quando a Qualidade aprova o lote", o que só faz sentido em (b), mas as regras do Estoque dizem que lote em quarentena não fica disponível. `RESERVA_ESTOQUE` também não tem coluna `status`, e o timeout de expiração está "não definido".

**Proposta (21/09).**
- Estados: `PREVISTA` (sobre item de OC, lote ainda inexistente) → `ATIVA` (sobre lote aprovado) → `CONSUMIDA`, ou `LIBERADA`.
- A aprovação da Qualidade transforma `PREVISTA` em `ATIVA`. Reserva sobre lote reprovado vira `LIBERADA` e o item volta ao PCP.
- `EXPIRADA` deixa de ser um estado: vira `LIBERADA` com `motivo = EXPIRACAO`.
- **Sugestão sobre o timeout:** não liberar sozinho; após N dias sem consumo, **alertar o PCP**. Liberar em silêncio pode prometer a outro pedido um material que o primeiro ainda espera. **Decisão do Nathan e do PCP.**

**✅ Resolvido em 24/09/2026** ([[Encaixe-Estoque-Revenda-no-PCP]]). As duas origens deixaram de existir como problema: **toda reserva nasce no setor Estoque, sobre lote já liberado** — (a) na etapa 1, quando o saldo existente atende o split; (b) quando o **item comprado, aprovado na Qualidade, volta ao Estoque** (regra do Nathan: comprado vai para o Estoque, não para a Expedição), que dá entrada no lote e reserva. Não há reserva sobre lote que ainda não chegou, então `PREVISTA` não é necessária. Estados finais: **`ATIVA` → `CONSUMIDA` \| `LIBERADA`**, **sem expiração** (liberação explícita no cancelamento do pedido/OP — decisão do Robert). A reserva aponta para **lote + `ItemParcial`** (o split atendido) + quantidade.

### 2.5 Vocabulário de etapas que eu propus (alta)
Falhas do que está em [[Rastreabilidade-e-SLA-de-Eventos]] e no protótipo Torre de Fluxo:
1. **As etapas de fábrica não são fixas.** Vêm do roteiro e dos setores cadastrados (`Setor`, `Roteiro`) e das transições do `ItemParcial`. Um catálogo fixo `fabrica.espera` e `fabrica.execucao` é falso. **Correção:** as etapas de produção são **geradas** a partir de `setor + estado` do `ItemParcial`; só os setores fora do MES (Compras, Qualidade, Expedição) têm catálogo fixo.
2. **`vendas.emitido` é a etapa errada.** Quem espera o aceite é o PCP. **Correção:** `pcp.aceite`, com a fila do PCP.
3. **O SLA mistura tempo interno com tempo de terceiros.** A meta de 96 h em `compras.followup` mede o fornecedor, não a equipe. **Correção:** cada etapa ganha `tipo_tempo`:

| `tipo_tempo` | Significado | Tem meta de SLA? |
|---|---|---|
| `FILA_INTERNA` | Sem dono, no setor | Sim |
| `COM_DONO` | Com uma pessoa, ainda não iniciado | Sim |
| `EXECUCAO` | Em execução | Sim |
| `PARADO` | Pausa, bloqueio ou espera de insumo | Não; exige motivo e gera alerta |
| `TERCEIRO` | Fornecedor, transportadora, Omie | Não; vale o prazo prometido, não uma meta interna |

4. **Correspondência com o `ItemParcial`, que já tem a resposta:** `CRIADO` e `EM_TRANSITO` = `FILA_INTERNA` (sem dono); `RECEBIDO` = `COM_DONO` (a ação `receber` é o "assumir"); `EM_ANDAMENTO` e `RETRABALHO` = `EXECUCAO`; `PAUSADO` = `PARADO`.

### 2.6 `EM_DESPACHO` (média)
É usado para "PCP aceitou, classificando" **e** para "reprovado, volta ao PCP". O vendedor não distingue o item novo do reprovado. **Correção:** dividir em `EM_CLASSIFICACAO` e `EM_REANALISE` (subindo os estados do vendedor de 9 para 11).

### 2.7 `CANCELADO` (média)
No `ItemParcial`, `CANCELADO` vale para cancelar e para "devolvido ao setor anterior" (a linha cancela e nasce outra `EM_TRANSITO`). Um relatório de cancelamentos contaria devoluções internas. **Correção sem mexer no enum**, porque o MES roda em produção com Flanges: uma view que classifica como devolução a linha `CANCELADA` cujo id aparece em `idDevolvidoDe` de outra. Mudar o enum só se o Robert achar que vale o risco.

### 2.8 Vocabulários concorrentes e cancelamento do pedido (média)
Há quatro linguagens de status: `Pedido.status` do MES (`AGUARDANDO`, `EM_PRODUCAO`, `BLOQUEADO`, `ENTREGUE`), o `ItemParcial`, os 9 estados do vendedor e a `etapa`/`situacao` do Omie.
- **Proposta:** três níveis com nomes fixos: `estado_macro` (o que o vendedor vê), `etapa_fluxo` (fina) e `status` técnico de cada entidade, com **uma tabela única de correspondência** (`fluxo.etapa_fluxo.estado_macro`).
- **`Pedido.status` do MES** deve ser derivado dos itens, não escrito à parte. `BLOQUEADO` precisa de regra de entrada e de saída **(confirmar com o Robert)**.
- **Cancelamento do pedido depois de iniciada a produção** não aparece nos estados do vendedor. Proposta: o pipeline já sincroniza a flag `cancelado` do Omie; ela gera um evento `PEDIDO_CANCELADO`, que libera reservas, pausa as OS/OP em curso e avisa o PCP. **Decisão do Nathan.**

---

## 3. Efeito no que começa amanhã

| Onde | O que muda |
|---|---|
| **D1 (Pablo)** | `LOTE` com `status_qualidade` e `situacao_lote`; `RECEBIMENTO` com o enum de estados da seção 2.3; `RESERVA_ESTOQUE` com `status`; coluna `quantidade` nos eventos |
| **F1 (Nathan, Robert, Gustavo)** | O envelope do evento leva `quantidade`, `id_item_parcial` e `tipo_tempo`; o feed traz a composição do item por parcial; os 11 estados macro |
| **E1/E2 (Nathan)** | Máquinas de Requisição e OC antes de modelar as tabelas |
| **C3 (Robert)** | Confirmar as regras de `Pedido.status` e `BLOQUEADO` |

## 4. Ordem e quem confirma

| Ponto | Confirmar com | Antes de |
|---|---|---|
| 2.2 Lote | Qualidade + Pablo | D1 |
| 2.3 Recebimento | Pablo + Almoxarifado | D1 |
| 2.1 Parciais e agregação | Robert | F1 (29/09) |
| 2.5 `tipo_tempo` e etapas geradas | Robert + Nathan | F1 |
| 2.3 Requisição e OC | Nathan + Compras | E1 (05/10) |
| 2.4 Reserva | Nathan + PCP | D9 (02/11) |
| 2.6, 2.7, 2.8 | Robert | Portal E3 (02/11) |

## 5. Perguntas novas
1. O cliente pode receber entrega parcial de um item? O item pode ficar parcialmente faturado?
2. Existe concessão de lote fora de especificação? Quem autoriza?
3. Qual é o destino de um lote reprovado por completo: devolução, descarte ou retrabalho? Quem decide?
4. O timeout da reserva alerta ou libera?
5. Cancelar um pedido em produção: o que acontece com as OS/OP em curso e com o material já cortado?
6. `Pedido.status` do MES é escrito por alguém hoje? Quando um pedido fica `BLOQUEADO`, e quem o desbloqueia?
7. O protótipo Torre de Fluxo deve ser refeito com `tipo_tempo` e a composição por parcial depois destas decisões?

## Ver também
- [[Diagramas-UML]] (seções 5 a 8 e 20)
- [[Rastreabilidade-e-SLA-de-Eventos]]
- [[Campos-e-API-para-Rastreabilidade]]
- [[App-PCP-Backend-Producao]]
- [[Estoque-Riscos]]
- [[Perguntas-em-Aberto-Consolidadas]]
