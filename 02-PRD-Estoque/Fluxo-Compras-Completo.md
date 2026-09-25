---
tags: [erp-acos-vital, prd-estoque, compras, fluxo-detalhado]
criado: 2026-09-16
---

# Fluxo de Compras — do 0 ao 100%, conversa por conversa

> Detalha a etapa "não tem em estoque → gera requisição de compra" da célula correspondente em [[Modelo-Destinacao-Item]], seguindo a divisão já decidida em [[MES-Arquitetura-Decisoes]] (decisão 5): **PCP (MES) decide que precisa comprar, Compras (av-hub) decide como comprar, MES executa o recebimento**.
>
> Cada "conversa" abaixo é uma interação entre atores/sistemas — quem fala, o que trafega, e o gatilho que a dispara. Numeradas em ordem de acontecimento no caminho feliz, com os desvios (divergência, reprovação) marcados como ramificações, nunca becos sem saída — ver [[Estoque-Riscos]].
>
> **Confirmado com o usuário (17/09/2026): nada deste fluxo existe em sistema hoje** — é escopo obrigatório do sistema a construir, não documentação de processo existente.
>
> **Atualizado em 24/09/2026 com o encaixe do MES** ([[Encaixe-Estoque-Revenda-no-PCP]]): a requisição (C1) passa a nascer da **entrada do parcial no setor Compras** do roteiro da fábrica Revenda, vinculada ao `ItemParcial`; o beneficiamento é um setor do próprio roteiro (C10 não volta mais ao PCP); e o item **aprovado na Qualidade volta ao setor Estoque** (C19), não segue direto pra Expedição.

## Atores e sistemas

| Ator | Onde vive |
|---|---|
| **PCP** | MES — monta a OP da fábrica Revenda na tela Ordem de Produção; decide o novo norte |
| **Setor Compras** (tipo `COMPRAS`) | MES — etapa do roteiro da Revenda: a entrada do parcial gera a requisição; o parcial espera ali até o recebimento |
| **Setor Estoque** (tipo `ESTOQUE`) | MES — recebe de volta o item aprovado (entrada + reserva) |
| **Comprador** | av-hub |
| **CCP** | av-hub (junto de Compras) — follow-up ativo de prazo/trânsito, distinto do Comprador que já fechou a compra |
| **Aprovador** (segunda aprovação, condicional) | av-hub |
| **Fornecedor** | externo, sem acesso ao sistema |
| **Logística de entrada** | MES ou terceirizada — entra em ação só no frete FOB (coleta no fornecedor); no frete CIF é o próprio fornecedor quem entrega |
| **Recebimento** | MES |
| **Qualidade** | MES |
| **Fábrica/Beneficiamento** (execução da OS/OP) | MES |
| **Vendedor** | av-hub (só observa status) |
| **Omie** | externo, sistema fiscal |

## Diagrama — caminho feliz + principais desvios

```mermaid
sequenceDiagram
    participant PCP
    participant SCom as Setor Compras (MES)
    participant Compras as Comprador (av-hub)
    participant CCP
    participant Aprov as Aprovador (condicional)
    participant Forn as Fornecedor (externo)
    participant LogEnt as Logística de entrada
    participant Receb as Recebimento (MES)
    participant Fab as Fábrica/Beneficiamento
    participant Qual as Qualidade (MES)
    participant Est as Setor Estoque (MES)
    participant Omie

    PCP->>SCom: C0 · OP da fábrica Revenda: restante sem saldo sai do Estoque e entra no setor Compras
    SCom->>Compras: C1 · requisição gerada pela entrada do parcial (material, qtd, prazo, filial, id_item_parcial)
    Compras->>Forn: C2 · cotação/negociação (fora do sistema)
    opt acima do valor X
        Compras->>Aprov: C3 · pedido de aprovação
        Aprov-->>Compras: aprovado/reprovado
    end
    Compras->>Compras: C4 · emite Ordem de Compra (define CIF ou FOB)
    Compras->>Forn: C5 · envia OC
    CCP->>Forn: C6 · follow-up ativo de prazo/trânsito (canal externo, manual)
    Forn-->>CCP: C6b · confirma/atualiza previsão de chegada
    Compras->>Receb: C7 · referência mínima da OC (itens, qtd, flag acabado/não-acabado)
    alt FOB — comprador assume custo/responsabilidade desde o despacho
        LogEnt->>Forn: C7b · coleta no fornecedor
        LogEnt->>Receb: C8 · chegada física na doca
    else CIF — fornecedor paga e organiza o transporte
        Forn->>Receb: C8b · fornecedor entrega direto na doca
    end
    Receb->>Receb: C9 · confere (contra Pedido de Venda OU contra OC) + pesagem
    Receb->>SCom: C9b · recebimento libera o parcial parado no setor Compras
    alt roteiro com beneficiamento (ex.: corte de chapa)
        Receb->>Fab: C10 · parcial segue pro setor de beneficiamento do roteiro
        Fab->>Qual: C13 · conclui, libera pra inspeção
    else sem beneficiamento
        Receb->>Qual: C11 · libera pra inspeção
    end
    Qual->>Qual: C14 · aprova ou reprova
    alt reprovado
        Qual->>PCP: C15 · "reprovado, decide novo norte"
        PCP->>SCom: C16 · parcial volta ao setor Compras, nova requisição (volta pra C1)
        Qual->>Omie: C17 · sinaliza necessidade de devolução (RNC)
        Omie-->>Qual: C18 · nota de devolução (fecha RNC)
    else aprovado
        Qual->>Est: C19 · volta ao setor Estoque: entrada do lote + reserva + CONCLUIDO
    end
```

## Conversa por conversa

**C0 — OP da fábrica Revenda (24/09/2026)**
O PCP envia o item para a fábrica **Revenda** na tela Ordem de Produção. O parcial nasce no setor Estoque (etapa 1); o que o saldo não cobre é movido para o **setor Compras**.

**C1 — Setor Compras → Compras: "preciso comprar X"**
Gatilho (**desde 24/09/2026**): a **entrada do parcial no setor Compras** gera a requisição automaticamente, vinculada ao `ItemParcial` (`origem.id_item_parcial` no Fluxo 1 de [[Integracao-AvHub-MES-Especificacao-F1]]). O parcial fica parado nesse setor até o recebimento liberar (C9b). ~~Gatilho: PCP avalia o item pelo Modelo-Destinacao-Item e conclui "sem estoque".~~ Payload: material (projeção `core.produtos`), quantidade, prazo (SLA do pedido de origem), unidade/filial (`codigo_empresa`, quando o vínculo existir — ver [[MES-Arquitetura-Decisoes]]), restrição de acabado/não-acabado se houver. **Mecanismo de transporte MES→av-hub ainda em aberto** — parte do "casamento av-hub↔MES" (ver [[Decisoes-Chave-ERP]]).

**C2 — Comprador → Fornecedor: cotação/negociação**
Comprador escolhe fornecedor (projeção `core.parceiros`, sem cadastro próprio no Estoque). Negociação de preço/condição acontece **fora do sistema** hoje — canal externo, sem integração.

**C3 — Comprador → Aprovador (condicional)**
Só dispara se o valor da compra estiver acima do limiar que ainda precisa ser definido (ver pendência de negócio em [[Estoque-Perguntas-Abertas]]). Segunda camada além da segregação comprador≠aprovador já prevista.

**C4 — Emissão da Ordem de Compra**
`pedido_compra` criado no av-hub (decidido em [[MES-Arquitetura-Decisoes]]). Campos: fornecedor, itens, preço, condição, moeda (cobre MP importada), flag **acabado/não-acabado** por item — essa flag é o dado mais importante que nasce aqui, decide o resto do fluxo.

**C5 — Comprador → Fornecedor: envio da OC**
Hoje manual (e-mail/PDF). Intenção futura: dado estruturado, sem depender de PDF (ver [[Fluxo-Detalhado-Pedido-Item]]).

**C6/C6b — CCP ↔ Fornecedor: follow-up ativo de prazo/trânsito**
É o **CCP** quem faz esse acompanhamento ativo (cobrar prazo, atualizar previsão), enquanto o comprador já seguiu pra outras compras. Canal externo (telefone/e-mail/WhatsApp), registrado manualmente. **Não existe estado "em trânsito" verificável** — o pedido permanece "Aprovado" até a chegada física (também documentado em [[Rota-Revenda]]).

**C7 — av-hub → MES: referência mínima da OC**
Dispara só quando o material chega na doca — não antes. Payload: itens, quantidade esperada, flag acabado/não-acabado. **Não trafega preço, fornecedor ou condição comercial** — mesma filosofia de "colunas protegidas" do pipeline ELT (ver [[Omie-ELT-Pipeline]]).

**C7b/C8 (FOB) ou C8b (CIF) — Logística de entrada**
O par que define quem paga e quem é responsável pelo transporte é **CIF × FOB**, dois incoterms:
- **CIF** (*Cost, Insurance and Freight*) — o **fornecedor** paga e cuida do transporte até a entrega. Ele mesmo despacha e entrega direto na doca (C8b) — a Logística de entrada da empresa não participa.
- **FOB** (*Free On Board*) — o **comprador** assume custo e responsabilidade assim que a mercadoria é despachada. É aí que a **Logística de entrada** da empresa entra em ação: coleta no fornecedor (C7b) e leva até a doca (C8).

Também referenciado em [[Rota-Revenda]].

**C9 — Recebimento confere**
- **Item acabado** → confere contra o **Pedido de Venda** ("cara-crachá": o que chegou é o que o vendedor vendeu).
- **Item não acabado** → confere contra a **referência da OC** recebida em C7 (o que chegou é o que o comprador comprou, pode ser bem diferente do item final vendido).
- Pesagem: peso teórico × quantidade, dentro da tolerância por categoria (provisório 5%, ver [[Estoque-Perguntas-Abertas]]).
- Cria o **lote**, nascendo em quarentena (`status_qualidade = PENDENTE`, padrão já documentado em [[Estoque-Modelo-Dados]]).

**C9b — Recebimento libera o parcial parado no setor Compras (24/09/2026)**
A conferência bem-sucedida move o parcial para o próximo setor do roteiro da Revenda (tarefa D6).

**C10 — Recebimento → Beneficiamento (condicional, roteiro com beneficiamento)**
~~"Chegou, precisa de beneficiamento." PCP abre OS ou OP.~~ **Desde 24/09/2026** o beneficiamento (ex.: corte de chapa) é um setor `PRODUTIVO` opcional do próprio roteiro da fábrica Revenda, escolhido pelo PCP ao montar a OP — o parcial segue pra ele sem voltar ao PCP. Só volta ao PCP (fila "Novo norte") se o item chegar não acabado e o roteiro não tiver previsto o beneficiamento.

**C11 — Recebimento → Qualidade (condicional, sem beneficiamento)**
Libera direto pra inspeção, sem passar pelo PCP de novo.

**C12 — (absorvida)**
Era "PCP abre a OS/OP" depois do recebimento. Com o beneficiamento dentro do roteiro, não existe mais esse passo.

**C13 — Fábrica/Beneficiamento → Qualidade**
Quando a OS/OP conclui, o item segue pra inspeção — mesmo destino de C11, caminho diferente.

**C14 — Qualidade decide**
Aprova ou reprova. Reprovação exige motivo + evidência (ex.: foto de avaria — ver [[Fluxo-Detalhado-Pedido-Item]]).

**C15 — Qualidade → PCP (condicional, reprovado)**
"Reprovado, decide o novo norte." Cisão de lote (`lote_pai_id`) — o que sobrou aprovado segue, o reprovado congela aguardando devolução (padrão já em [[Estoque-Modelo-Dados]]).

**C16 — PCP → Compras (condicional, reprovado)**
Nova requisição — **volta pra C1** (o parcial volta ao setor Compras), fechando o ciclo sem beco sem saída (princípio de [[Estoque-Riscos]]).

**C17/C18 — Sinalização de devolução via Omie (condicional, reprovado)**
RNC marca `nota_devolucao_pendente = true`; o sistema nunca cria a nota, só sinaliza. Omie emite a nota de devolução; a sincronização de volta fecha a RNC (ver [[Estoque-Regras-Negocio]]). Limitação de dado: `devolucao_parcial` no av-hub é só um boolean, sem nenhum campo de valor associado (ver [[AV-Hub-Vendas-Reconciliacao]]).

**C19 — Qualidade → setor Estoque (condicional, aprovado) — regra de 24/09/2026**
Item aprovado sai da quarentena e **vai para o setor Estoque, não para a Expedição**: o Estoque dá entrada do lote no saldo (`MovimentoEstoque` `ENTRADA`, referência ao recebimento), cria a **Reserva `ATIVA`** do lote para o split que esperava a compra e conclui o split. Só então o item segue pro fluxo de Expedição/Faturamento, detalhado em [[Fluxo-Expedicao-Faturamento-Completo]] (Expedição embala/consolida, só a Expedição fala com o Omie, e a baixa chega ao Vendedor — não ao Comprador). O status por item chega ao vendedor pelo Fluxo 3 da F1 (polling), como em qualquer etapa. Ver [[Fluxo-Estoque-Completo]] Caso C.

## Nenhum estado é beco sem saída — verificação

| Estado problemático | Saída garantida |
|---|---|
| Reprovação de qualidade | C15→C16, volta pro PCP, novo ciclo de compra ou beneficiamento |
| Divergência de quantidade na conferência (C9) | Mesmo padrão — volta pro PCP/Compras, não fica travado (a modelar em detalhe se divergir do fluxo de reprovação de qualidade) |
| Fornecedor nunca entrega | Status `CANCELADO` explícito já previsto em [[Estoque-Riscos]], com destinação/reserva reavaliada |

## O que este modelo deixa explícito

- **C1 e C19 são os dois pontos que dependem do sentido MES→av-hub do "casamento av-hub↔MES"** (desde 24/09/2026, C19 em si é interno ao MES — Qualidade → setor Estoque — e só o status resultante cruza a fronteira, pelo Fluxo 3 da F1). C7 (av-hub→MES, referência mínima disparada só na chegada física) e C16 (reaproveita o mesmo mecanismo de C1, "volta pra C1") também cruzam a fronteira, mas não introduzem um ponto de integração novo — reduz a superfície do problema à direção MES→av-hub especificamente, em vez de "o sistema inteiro precisa de tempo real".
- **C9 (conferência) tem uma ramificação própria**: divergência de quantidade/descrição na conferência é um caminho diferente de reprovação de qualidade (C14) — os dois merecem tratamento parecido (volta pro PCP), mas são gatilhos diferentes e precisam de telas diferentes.
- **A flag acabado/não-acabado (nasce em C4) decide contra o que o Recebimento confere (C9)** — reforça que ela precisa estar bem visível e não pode ser opcional. Desde 24/09/2026 ela não decide mais se o item passa pelo PCP de novo: o beneficiamento já está no roteiro. A flag vira só um alerta quando contradiz o roteiro (não acabado sem setor de beneficiamento → fila "Novo norte").
- **CCP e Logística de entrada são atores do fluxo** — detalhados em C6/C6b e C7b/C8. Lista completa de setores em [[Setores-Envolvidos-no-Fluxo]].

## Ver também
- [[Encaixe-Estoque-Revenda-no-PCP]] — setor Compras no roteiro da Revenda e a volta do item aprovado ao Estoque.
- [[Integracao-AvHub-MES-Especificacao-F1]] — spec técnica dos 3 fluxos por polling que cruzam a fronteira av-hub↔MES (C1, C7, C19 abaixo)
- [[Setores-Envolvidos-no-Fluxo]]
- [[Fluxo-Detalhado-Pedido-Item]]
- [[Modelo-Destinacao-Item]]
- [[MES-Arquitetura-Decisoes]]
- [[Rota-Revenda]]
- [[Estoque-Modelo-Dados]]
- [[Estoque-Regras-Negocio]]
- [[Estoque-Riscos]]
- [[App-PCP-Backend-Producao]]
- [[Fluxo-Expedicao-Faturamento-Completo]]
