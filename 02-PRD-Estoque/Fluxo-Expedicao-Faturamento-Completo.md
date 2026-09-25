---
tags: [erp-acos-vital, expedicao, faturamento, fluxo-detalhado]
criado: 2026-09-16
---

# Fluxo de Expedição e Faturamento — conversa por conversa

> Ponto de convergência final: qualquer item concluído passa pelo mesmo caminho daqui em diante.
>
> **Atualizado em 24/09/2026** ([[Encaixe-Estoque-Revenda-no-PCP]]): a Expedição recebe de **duas portas**, não de uma. **Setor Estoque** — item atendido pelo saldo (etapa 1) e item comprado que voltou da Qualidade e foi reservado (regra do Nathan: comprado aprovado vai para o Estoque, não para a Expedição). **Qualidade** — só o item fabricado aprovado ([[Fluxo-Qualidade-Completo]] Q6b). Na saída física, a reserva do item de estoque vira `CONSUMIDA`.
>
> **Confirmado com o usuário (17/09/2026): nada deste fluxo existe em sistema hoje** (a parte fiscal no Omie é a única exceção real — ver [[Faturamento-Expedicao]]) — o resto é escopo obrigatório do sistema a construir.

## Atores e sistemas

| Ator | Onde vive |
|---|---|
| **Expedição** | MES |
| **Logística** | MES |
| **Omie** | externo — sistema fiscal |
| **Vendedor** | av-hub — observa o status final |
| **Cliente** | externo — recebe a entrega |

## Diagrama

```mermaid
sequenceDiagram
    participant Est as Setor Estoque
    participant Qual as Qualidade
    participant Exp as Expedição
    participant Log as Logística
    participant Omie
    participant Vend as Vendedor (av-hub)
    participant Cli as Cliente

    alt item de estoque ou comprado (reservado no Estoque)
        Est->>Exp: E1a · split concluído e reservado, na saída a reserva vira CONSUMIDA
    else item fabricado
        Qual->>Exp: E1b · item aprovado, libera pra embalagem
    end
    Exp->>Exp: E2 · embalagem/paletização
    Exp->>Exp: E3 · consolida carga (aguarda outros itens, se faturamento integral)
    Log->>Log: E4 · define transporte e roteiro de entrega
    Exp->>Omie: E5 · sinaliza necessidade de nota fiscal de saída
    Omie-->>Exp: E6 · NF emitida, número/chave volta pela sincronização
    Exp->>Vend: E7 · item dá baixa, migra "em aberto" → "faturado"
    Log->>Cli: E8 · entrega física + comprovante de entrega
```

## Conversa por conversa

**E1a/E1b — Estoque ou Qualidade → Expedição**
~~Ponto de entrada único (Qualidade), independente do caminho.~~ Desde 24/09/2026 são duas entradas: o **setor Estoque** entrega o item atendido pelo saldo e o item comprado (que voltou da Qualidade, entrou no saldo e foi reservado) — E1a, com `MovimentoEstoque` `SAIDA` consumindo a reserva; a **Qualidade** entrega o item fabricado aprovado — E1b. Os eixos de [[Modelo-Destinacao-Item]] continuam convergindo aqui; só a porta mudou.

**E2 — Embalagem/paletização**
`PedidoEmbalagem` (identificação + total de unidades) e `PedidoEmbalagemPallet` (identificação + peso) — entidades já existentes no backend do app-pcp (ver [[App-PCP-Backend-Producao]]), sem campo de código de barras dedicado hoje.

**E3 — Consolidação de carga**
Aqui mora a decisão **parcial × integral**: se o pedido exige faturamento integral, a Expedição espera os outros itens do mesmo pedido concluírem antes de seguir — mesma lógica de consolidação bottom-up do waterfall de dedução de Venda Líquida (ver [[AV-Hub-Vendas-Reconciliacao]]) e já descrita em [[Faturamento-Expedicao]].

**E4 — Logística define transporte**
Frota própria ou terceirizada, roteiro de entrega — fora do escopo detalhado deste vault até agora.

**E5/E6 — Faturamento via Omie**
Fronteira fiscal inegociável: o sistema **nunca emite nota fiscal**, só sinaliza a necessidade; a NF nasce no Omie e volta pela sincronização (pipeline ELT, polling — ver [[Omie-ELT-Pipeline]]). Mesma limitação já documentada: dados de manifestação/nota vindos por scraping, não API, em outras partes do fluxo comercial (ver [[Omie-ELT-Pipeline]]).

**E7 — Baixa e status pro vendedor**
Item migra de "em aberto" pra "faturado" na carteira — depende do mesmo "casamento av-hub↔MES" (ou, neste caso específico, do pipeline Omie já existente, que é mais lento mas já funciona) discutido em [[Decisoes-Chave-ERP]].

**E8 — Entrega física**
`PedidoAnexo` tipo `COMPROVANTE_ENTREGA`, já existente no schema do app-pcp — anexo de nível pedido ou de entrega específica.

## Nenhum estado é beco sem saída

| Estado problemático | Saída garantida |
|---|---|
| Faturamento integral esperando item que nunca chega | Depende do status `CANCELADO` explícito já previsto em [[Estoque-Riscos]] pra reavaliar a consolidação — vale confirmar se isso dispara automaticamente a mudança de integral pra parcial, ou exige decisão manual |

## O que este modelo deixa explícito

- **Este é o único ponto do fluxo inteiro onde todos os caminhos possíveis (Compras, Produção, Estoque-pronto) se encontram de novo** — antes disso, cada item corre isolado dentro do MES; aqui, a decisão parcial×integral exige olhar o pedido como um todo de novo, não item a item.
- **E5/E6 já reaproveita o pipeline ELT existente** (que já sincroniza NF do Omie pro av-hub) — diferente de C1/C19 em [[Fluxo-Compras-Completo]], que dependem de um mecanismo ainda não desenhado entre av-hub e MES. Ou seja, a parte fiscal do fluxo já tem "casamento" resolvido; a parte operacional de status por item, não.
- **Faturamento integral travado por 1 item nunca resolvido** é um risco real que ainda não tem gatilho de decisão explícito (diferente de compra/produção, que já têm `CANCELADO` como saída) — vale desenhar antes de construir.

## Ver também
- [[Encaixe-Estoque-Revenda-no-PCP]]
- [[Fluxo-Estoque-Completo]]
- [[Fluxo-Qualidade-Completo]]
- [[Faturamento-Expedicao]]
- [[AV-Hub-Vendas-Reconciliacao]]
- [[Omie-ELT-Pipeline]]
- [[Modelo-Destinacao-Item]]
