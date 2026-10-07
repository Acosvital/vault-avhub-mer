---
tags: [erp-acos-vital, prd-estoque, qualidade, fluxo-detalhado]
criado: 2026-09-16
atualizado: 2026-10-07
---

# Fluxo de Qualidade — conversa por conversa

> Status: decidido | no código (develop) | em produção (mes-test; produção real não)

> **Atualização de 07/10/2026 — a inspeção de entrada já tem código real em `develop`** (conferido no código; **só em `develop`, `main` do MES parada em 28/08; produção não conferida**). D8: backend `898aa54` (24/09, PR #45) e front real `815fef3` (28/09) — `src/qualidade`, `/qualidade/lotes`, permissão `inspecao-entrada`, setor "Qualidade · Entrada" (`qualidade-entrada`, tipo `QUALIDADE`). A inspeção de entrada é **por lote** (EC-01). **Aprovar exige `laudoUrl`** e leva a parcial de volta ao Estoque; **reprovar abre RNC total ou parcial**, com **cisão** e quarentena (EC-07): a parte reprovada volta a Compras, a aprovada fica em `QUARENTENA`, e na reprovação parcial as partes se unem depois (`devolverAoEstoqueParciaisProntas`). Vem da conferência do Recebimento: o lote nasce `PENDENTE` e a parcial chega com `idLoteCompra` ([[Fluxo-Recebimento-Completo]], [[App-PCP-Recebimento-Conferencia]]). **Não conferido:** a **inspeção de saída** (setor `QUALIDADE` no roteiro, EC-06) e a inspeção de processo (9.5); o setor `inspecao_qualidade` (tipo `QUALIDADE`) vem da UI/banco, não conferido.
>
> Detalha a inspeção de qualidade, a partir de qualquer um dos pontos de entrada possíveis (Recebimento, conclusão de OS/OP, ou item já pronto em estoque), até a aprovação/reprovação e seus desdobramentos.
>
> ~~**Confirmado com o usuário (17/09/2026): nada deste fluxo existe em sistema hoje**~~ — **superado em 07/10/2026 para a inspeção de entrada**, ver bloco acima. *(Em 23/09 a fila de inspeção com aprovar/reprovar, laudo, RNC e cisão entrou no `app-pcp` `develop` sobre mock — tarefa D8; o front real veio em 28/09.)*
>
> **Regra de 24/09/2026 (Nathan):** item **comprado** aprovado **vai para o setor Estoque, não para a Expedição** — ver Q6 abaixo e [[Encaixe-Estoque-Revenda-no-PCP]] seção 3.4.

## Atores e sistemas

| Ator | Onde vive |
|---|---|
| **Qualidade** | MES |
| **PCP** | MES |
| **Recebimento** / **Fábrica-Beneficiamento** | MES — origem do item |
| **Vendedor** | av-hub — só define o tipo de acompanhamento na emissão do pedido |
| **Omie** | externo — devolução ao fornecedor |
| **Setor Estoque** | MES — destino do item **comprado** aprovado (entrada + reserva) |
| **Expedição** | MES — destino do item **fabricado** aprovado |

## Duas entradas na fila da Qualidade

1. **Inspeção de processo** — itens marcados pelo vendedor pra acompanhamento desde o início (documentação, validação de entrada). Entrada nasce na emissão do pedido, não depende de Recebimento/Fábrica.
2. **Inspeção final** — itens acabados liberados por [[Fluxo-Recebimento-Completo]] (R10a) ou por conclusão de OS/OP (ver [[Fluxo-Producao-OS-OP-Completo]]). ~~Ou item que já estava pronto em estoque.~~ Desde 24/09/2026 o item atendido pelo saldo não volta à Qualidade: o saldo disponível só conta lote já liberado por ela.

## Diagrama — arquitetura de 29/09/2026

> Redesenhado em 07/10/2026 conforme a arquitetura de 29/09 e o código de `develop` (inspeção de entrada por lote). Fonte: [[Registro-de-Decisoes-2026-10-07]].

```mermaid
graph TD
    REC["Setor LOGISTICA_ENTRADA, Recebimento: conferência contra a NF; lote nasce em quarentena"] --> QUA["Setor QUALIDADE, Qualidade Entrada: inspeção por lote; aprovar exige laudo"]
    QUA -->|"aprovado"| LIB["Lote sai da quarentena, status liberado"]
    LIB --> EST["Setor ESTOQUE: entrada do lote e reserva para a parcial"]
    EST --> EXP["Expedição: baixa no despacho, ainda sem código"]
    QUA -->|"reprovado"| RNC["RNC com evidência e motivo; cisão de lote, total ou parcial"]
    RNC --> COM["Parte reprovada volta a Compras; devolução ao fornecedor sinalizada ao Omie"]
    RNC -->|"parte aprovada"| QUAR["Fica em QUARENTENA até a união das partes"]
    QUAR --> EST
    COM --> REC
```

> [!note]- Histórico 24/09: desenho original (superado)
> O diagrama de 24/09 (Q1 a Q11) mostrava duas entradas na fila (inspeção de processo marcada pelo vendedor e inspeção final), aprovado de item comprado voltando ao Estoque e de item fabricado indo à Expedição, e reprovado voltando ao PCP ("novo norte") com sinalização de RNC ao Omie. Na prática de 29/09 a reprovação devolve a parte reprovada a Compras, e o item fabricado também passa pelo Estoque. As conversas Q1 a Q11 abaixo seguem descrevendo o desenho antigo.

## Conversa por conversa

**Q1 — Vendedor → Qualidade: acompanhamento desde o início**
Nasce na emissão do pedido (checkbox descrito em [[Fluxo-Detalhado-Pedido-Item]]), não na chegada do material. Se o vendedor não marcar, Qualidade só é acionada na inspeção final (Q2) — evita sobrecarregar o setor.

**Q2 — Origem → Qualidade: libera pra inspeção final**
Duas origens, mesmo destino: Recebimento (item acabado comprado) e conclusão de OS/OP (item beneficiado/fabricado). ~~Ou item que já estava pronto em estoque~~ — desde 24/09/2026 esse é atendido no setor Estoque sobre lote já liberado, sem nova inspeção. Ver [[Modelo-Destinacao-Item]].

**Q3 — Execução da inspeção**
Interna à Qualidade — varia conforme o tipo (documental pra inspeção de processo, física pra inspeção final).

**Q4 — Exigência de laudo**
Regra de negócio já fixada: `status_qualidade` **não pode sair de PENDENTE sem `laudo_url` preenchido** (ver [[Estoque-Regras-Negocio]]) — trava antes mesmo de decidir aprovar ou reprovar.

**Q5/Q6 — Aprovado**
Lote sai da quarentena. O destino depende da origem (regra de 24/09/2026):
- **Q6a — Item comprado** (fábrica Revenda, com ou sem beneficiamento): **vai para o setor Estoque, não para a Expedição.** O Estoque dá entrada do lote no saldo, cria a reserva para o split que esperava a compra e o conclui — ver [[Fluxo-Estoque-Completo]] Caso C e [[Fluxo-Compras-Completo]] C19. A reserva não "se confirma" na Qualidade: ela nasce no Estoque, sobre o lote já liberado.
- **Q6b — Item fabricado**: segue pra Expedição — ver [[Fluxo-Expedicao-Faturamento-Completo]].

**Q7 — Reprovado: motivo + evidência**
Campo pra anexar foto da avaria, além do motivo em texto (ver [[Fluxo-Detalhado-Pedido-Item]]).

**Q8 — Cisão de lote**
`lote_pai_id` — o lote original aprovado segue com o que sobrou; um lote filho nasce congelado com a quantidade reprovada, aguardando devolução (padrão já em [[Estoque-Modelo-Dados]]).

**Q9 — Volta pro PCP**
"Reprovado, decide o novo norte" — mesma conversa C15 de [[Fluxo-Compras-Completo]], reafirmada aqui como o ponto de saída da reprovação.

**Q10/Q11 — Devolução via Omie**
⚠️ **Distinção importante a não confundir:** esta é **devolução ao fornecedor** (RNC, motivada por reprovação de qualidade na entrada). É um conceito **diferente** de "devolução de cliente" (motivada por insatisfação/erro pós-venda, ainda em aberto — ver [[Perguntas-Pendentes-MES-Estoque]], pergunta 3). Os dois usam a palavra "devolução", mas são fluxos, atores e telas completamente distintos — vale nomear diferente no sistema pra não confundir operador (ex.: "RNC/Devolução a Fornecedor" vs. "Devolução de Cliente"). RNC sinaliza `nota_devolucao_pendente = true`; o sistema nunca cria a nota, só sinaliza; Omie emite; a sincronização de volta fecha a RNC.

## Nenhum estado é beco sem saída

| Estado problemático | Saída garantida |
|---|---|
| Reprovado sem decisão do PCP | Q9 força a volta pro PCP — não existe "reprovado" como estado final por si só |
| RNC sem nota de devolução do Omie | Fica aberta até a sincronização trazer a nota de volta (Q11) — não é travamento, é espera assíncrona documentada |

## O que este modelo deixa explícito

- **As duas filas de Qualidade (processo vs. final) têm gatilhos completamente diferentes** — uma nasce na emissão do pedido (Q1), a outra na conclusão de uma etapa operacional (Q2) — não são a mesma fila com prioridades diferentes, são entradas de dados distintas que precisam de telas distintas.
- **"Devolução" no sistema precisa de dois nomes, não um** — RNC/devolução a fornecedor (aqui) e devolução de cliente (ainda em aberto) são conceitos irmãos, fáceis de confundir na nomenclatura se não forem batizados diferente desde o início.
- **A exigência de `laudo_url` (Q4) é uma trava dura antes da decisão**, não uma preferência — vale confirmar se isso vale igual pra inspeção de processo (documental) ou só pra inspeção final (física).

## Ver também
- [[App-PCP-Recebimento-Conferencia]] — a conferência que entrega o lote à Qualidade, como está no código (07/10/2026).
- [[Encaixe-Estoque-Revenda-no-PCP]]
- [[Fluxo-Recebimento-Completo]]
- [[Fluxo-Producao-OS-OP-Completo]]
- [[Fluxo-Expedicao-Faturamento-Completo]]
- [[Modelo-Destinacao-Item]]
- [[Estoque-Regras-Negocio]]
- [[Perguntas-Pendentes-MES-Estoque]]
