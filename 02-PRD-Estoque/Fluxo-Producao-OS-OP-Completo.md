---
tags: [erp-acos-vital, app-pcp, producao, fluxo-detalhado]
criado: 2026-09-16
---

# Fluxo de Produção (OS/OP) — conversa por conversa

> Detalha a execução de uma Ordem de Serviço (beneficiamento de Revenda) ou Ordem de Produção (linha própria de Fabricação), a partir do mecanismo já decidido: OS/OP = `ItemParcial`/roteiro, já implementado no `api-pcp` (ver [[App-PCP-Backend-Producao]]).
>
> ⚠️ Diferente dos outros fluxos deste conjunto ([[Fluxo-Compras-Completo]], [[Fluxo-Recebimento-Completo]], [[Fluxo-Qualidade-Completo]]), **este é o único subfluxo que já tem mecanismo de estado implementado em produção** — os outros ainda são desenho, este é tradução de código real pra conversa por conversa.

## Atores e sistemas

| Ator | Onde vive |
|---|---|
| **PCP** | MES |
| **Setor** (cada etapa do roteiro) | MES, operado por Operador/Máquina |
| **Qualidade** | MES — destino final |

## Diagrama

```mermaid
sequenceDiagram
    participant PCP
    participant SetorN as Setor N (roteiro)
    participant SetorN1 as Setor N+1
    participant Qual as Qualidade

    PCP->>SetorN: OS1 · abre OS/OP (cria ItemParcial em CRIADO, associa ao roteiro)
    SetorN->>SetorN: OS2 · receber (CRIADO→RECEBIDO)
    SetorN->>SetorN: OS3 · inicia trabalho (RECEBIDO→EM_ANDAMENTO)
    alt fluxo normal
        SetorN->>SetorN1: OS4 · mover (EM_ANDAMENTO→EM_TRANSITO→próximo setor RECEBIDO)
    else exceção
        SetorN->>SetorN: OS5a · pausar (aguardando insumo/máquina)
        SetorN->>SetorN: OS5b · retomar (volta ao fluxo normal)
        SetorN->>SetorN: OS5c · retrabalho (repete a etapa)
        SetorN->>SetorN: OS5d · split (divide o lote em múltiplos ItemParcial)
        SetorN->>SetorN: OS5e · devolver (rejeita pro setor anterior — atual CANCELADO, novo EM_TRANSITO linkado)
    end
    SetorN1->>SetorN1: OS6 · concluir (só no último passo do roteiro)
    SetorN1->>Qual: OS7 · libera pra inspeção
    opt lotes divididos
        SetorN1->>SetorN1: OS8 · consolidar (junta parciais de volta)
    end
```

## Conversa por conversa

**OS1 — PCP abre a OS/OP**
Cria o `ItemParcial` em `CRIADO`, associado ao roteiro (sequência ordenada de setores) da fábrica correspondente. Pra beneficiamento de Revenda (ex.: corte de chapa), pressupõe uma fábrica/setor "leve" cadastrada só pra isso — item ainda em aberto, ver [[App-PCP-Backend-Producao]].

**OS2 — Setor recebe**
`receber`: `CRIADO → RECEBIDO`.

**OS3 — Setor inicia**
`RECEBIDO → EM_ANDAMENTO`.

**OS4 — Fluxo normal: move pro próximo setor**
`mover`: `EM_ANDAMENTO → EM_TRANSITO`, e o próximo setor do roteiro recebe (volta pra OS2). Repete até o último setor.

**OS5a/b — Pausa e retomada**
`pausar` (aguardando insumo, quebra de máquina etc.) e `retomar` — garante que pausa nunca é estado terminal.

**OS5c — Retrabalho**
Repete a etapa atual sem avançar no roteiro.

**OS5d — Split**
Divide o lote em múltiplos `ItemParcial` — cenário natural de corte (uma chapa vira várias peças).

**OS5e — Devolver**
Rejeita de volta pro setor anterior: a linha atual vira `CANCELADO` **permanentemente**, e nasce uma **nova** linha `EM_TRANSITO` ligada por `idDevolvidoDe`. Não edita o registro antigo — cria um novo linkado. ⚠️ Esse é o padrão que sustenta a hipótese sobre a Divergência sem reabertura (ver [[Decisoes-Chave-ERP]], item adiado) — se o mesmo princípio se aplicar lá, "reabrir" também deveria ser "criar novo linkado ao antigo", não editar o antigo.

**OS6 — Concluir**
Só permitido no último passo do roteiro — `concluir` fecha o `ItemParcial` como pronto.

**OS7 — Libera pra Qualidade**
Mesmo ponto de entrada Q2 de [[Fluxo-Qualidade-Completo]].

**OS8 — Consolidar (condicional)**
Se o lote foi dividido (OS5d), pode ser reagrupado de volta antes ou depois da inspeção.

## Nenhum estado é beco sem saída

| Estado problemático | Saída garantida |
|---|---|
| Pausado | `retomar` (OS5b) sempre disponível |
| Devolvido pro setor anterior | Nova linha `EM_TRANSITO` nasce automaticamente (OS5e) — o item nunca fica "devolvido e parado" |
| Dividido em múltiplos lotes | `consolidar` (OS8) disponível quando fizer sentido reagrupar |

Toda transição usa `updateMany({where:{id, status: ESPERADO}}) + count===0 → erro de conflito` — concorrência resolvida por escrita condicional, não leitura-depois-escrita (retrofit de 24/08, ver [[App-PCP-Backend-Producao]]).

## O que este modelo deixa explícito

- **Este é o único dos quatro subfluxos que não precisa de desenho novo** — só precisa confirmar se o mecanismo de fábrica/setor "leve" pra beneficiamento de Revenda é viável, ou se exige ajuste no modelo.
- **`HistoricoItemParcial` já dá a trilha de auditoria completa de toda essa sequência** — é candidato natural a alimentar o "histórico muito mais robusto" que ficou pendente pro status por item no av-hub (ver [[AV-Hub-Bugs-Catalogo]]).
- **O padrão `devolver` (cria novo linkado, nunca edita o antigo) é uma pista de design pra resolver a Divergência sem reabertura** — mesma filosofia aplicada a uma entidade diferente do mesmo backend.

## Ver também
- [[App-PCP-Backend-Producao]]
- [[Fluxo-Qualidade-Completo]]
- [[Fluxo-Recebimento-Completo]]
- [[Decisoes-Chave-ERP]]
