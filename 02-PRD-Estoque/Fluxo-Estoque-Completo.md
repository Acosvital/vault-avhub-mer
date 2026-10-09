---
tags: [erp-acos-vital, prd-estoque, estoque, fluxo-detalhado]
criado: 2026-09-16
atualizado: 2026-10-07
---

# Fluxo de Estoque — conversa por conversa

> Status: decidido | no código (develop) | em produção (mes-test; produção real não)

> **Decisões de 07/10/2026 ([[Registro-de-Decisoes-2026-10-07]]):** o **registro de remessa de produtos**, a devolução de cliente e a transferência entre filiais (etapas 2 a 4) vão ao **Ciclo 2** (começa em 04/01/2027). **Saldo zero — ✅ decidido pelo Nathan em 08/10/2026: exige clique** (não passa sozinho). Fecha o EN-01 de [[Encaixe-Estoque-Revenda-no-PCP]] e a contradição que havia com esta nota e com [[Fluxo-Sistema-no-Meio]].

> **Atualização de 07/10/2026 — o setor Estoque já tem código em `develop`** (conferido no código, `api-pcp` `ca3346b` / `app-pcp` `a802a3e`; **só em `develop`, a `main` do MES parou em 28/08; produção não conferida**). **Caso A** (atender pelo saldo: split + reserva): implementado e testado (C6, 25/09; D9, `0fe771f`, 28/09), com `atenderEstoque` em `itens-parcial.service`. **Caso C** (item comprado volta da Qualidade): existe como retorno ao mesmo Estoque único após a aprovação (D8, `898aa54`); a parte reprovada volta a Compras e a aprovada fica em `QUARENTENA` (EC-07). **Caso B** (operação contínua): movimentação/ajuste/saldo reais (D10); **contagem cíclica e ponto de pedido preventivo (EB2–EB5) sem código registrado** na auditoria — só os alertas `GET /estoque/alertas/estoque-minimo` e `/rnc-pendentes` (`bfe5882`, 24/09), com 2 widgets reais no `painel-estoque` e o resto ainda `MOCK_*`. **Transferência entre filiais:** etapa 1 (saldo por filial) concluída em `861c050` (07/10); etapas 2–4 não existem — ver [[Proposta-Transferencia-Estoque-Filiais]]. **Ainda não implementado (decidido em 29/09):** baixa no despacho do Estoque (hoje a baixa ocorre quando a Embalagem recebe), ação de consumo de matéria-prima e `RoteiroItem` — ver [[Encaixe-Estoque-Revenda-no-PCP]]. Estado das tarefas: [[Onde-Estamos]] e [[Cronograma-2-Meses]].
>
> Detalha o setor de **Estoque** em si — a operação contínua de guardar saldo, localizar, reservar e separar material — que até agora só existia como conceito ([[Rota-Estoque]], "pronta entrega") ou como célula da matriz em [[Modelo-Destinacao-Item]], mas nunca como sequência de conversas como os outros subfluxos.
>
> Cobre três casos: **(A)** parcial chegando no setor Estoque (etapa 1 de todo roteiro) e sendo atendido pelo saldo; **(B)** operação contínua do depósito, independente de qualquer pedido específico (movimentação, contagem cíclica, ponto de pedido); **(C)** item comprado voltando da Qualidade para o Estoque (entrada + reserva).
>
> ~~**Confirmado com o usuário (17/09/2026): nada deste fluxo existe em sistema hoje**~~ — **superado em 07/10/2026**, ver bloco acima. *(Em 23/09 as telas de saldo, reservas, movimentação e lote entraram no `app-pcp` `develop` sobre mock; o backend real veio na D9, 28/09.)*
>
> **Atualizado em 24/09/2026 com o encaixe do MES** ([[Encaixe-Estoque-Revenda-no-PCP]]): o Estoque virou **setor tipo `ESTOQUE`, etapa 1 obrigatória de todo roteiro**, e a reserva aponta para **lote + `ItemParcial`** (o split atendido), sem expiração. O Caso A foi reescrito e o Caso C é novo (regra do Nathan: item comprado aprovado vai para o Estoque, não para a Expedição).

## Atores e sistemas

| Ator | Onde vive |
|---|---|
| **PCP** | MES |
| **Almoxarife** | MES — opera o depósito no dia a dia |
| **Gestor de Estoque** | MES — supervisão, não participa das conversas operacionais |
| **Qualidade** | MES |
| **Expedição** | MES |
| **Compras** | av-hub — só entra se o ponto de pedido disparar (volta pro fluxo de [[Fluxo-Compras-Completo]]) |

## Caso A — Parcial no setor Estoque (etapa 1), atendido pelo saldo

```mermaid
sequenceDiagram
    participant PCP
    participant Sist as Sistema (MES)
    participant Alm as Almoxarife (setor Estoque)
    participant Prox as Próximo setor do roteiro
    participant Exp as Expedição

    PCP->>Sist: EA1 · faz a Destinação do Pedido (1 por fábrica), com o setor Estoque como etapa 1
    Sist->>Alm: EA2 · parcial chega com o saldo disponível na filial do pedido
    Alm->>Sist: EA3 · "atender X do estoque"
    Sist->>Sist: EA3 · split do ItemParcial + Reserva (lote + split + qtd, ATIVA) + CONCLUIDO
    Alm->>Alm: EA4 · separação física do lote reservado
    Alm->>Exp: EA5 · split concluído segue pra entrega (lote já liberado pela Qualidade)
    Alm->>Prox: EA6 · "enviar restante" (mover): setores produtivos ou setor Compras
```

**EA1 — PCP faz a Destinação do Pedido**
Na tela Ordem de Produção (a partir da Carteira), o PCP escolhe itens, quantidades e fábrica da rodada. O backend insere o setor Estoque como etapa 1 do roteiro — ver [[Encaixe-Estoque-Revenda-no-PCP]].

**EA2 — O parcial chega no setor Estoque**
Corresponde ao eixo 2 de [[Modelo-Destinacao-Item]]. O sistema mostra o **saldo disponível na filial do pedido** (DEC-1) = saldo do lote liberado pela Qualidade − reservas `ATIVAS`. Nesta fase só **produto acabado** é checado; matéria-prima fica para a J3. **Regra do Robert (08/10, 🟡 Nathan valida):** para item de fabricação a consulta tem duas etapas: **1º produto pronto, 2º matéria-prima livre** (não existe amarração produto ↔ matéria-prima, então o operador escolhe a matéria-prima). Material ↔ item do pedido casam por `(codigoEmpresa, idOmie)`.

**EA3 — Atender do estoque: split + reserva + conclusão**
A leitura do saldo e a criação da reserva acontecem **no mesmo passo** — evita a corrida entre pedidos concorrentes disputando o mesmo saldo. A reserva aponta para o **lote e o split atendido** (não mais um `pedidoNumero` em texto) e nasce `ATIVA`, **sem expiração**.

**EA4 — Separação física**
`ordem_separacao`/`item_separacao`, já modelado no PRD (ver [[Estoque-Modelo-Dados]]) — o Almoxarife retira o material do warehouse. A tela de separação segue na Fase D.

**EA5 — Segue pra entrega**
O split atendido não volta à Qualidade: o saldo disponível só conta lote já liberado por ela. Na saída física a reserva vira `CONSUMIDA` (`MovimentoEstoque` `SAIDA` com referência à reserva). *(Atualizado em 07/10, conferido no código: isso acontece quando a **Embalagem recebe** — `receber()` → `consumirReservasDaParcial` —, não na saída do Estoque; a mudança decidida em 29/09 para o despacho do Estoque não foi implementada.)*

**EA6 — Enviar o restante**
O que o saldo não cobre segue o roteiro: setores produtivos (fábrica de Fabricação) ou setor Compras (fábrica Revenda). **Saldo zero** — ✅ **exige clique** (Nathan, 08/10/2026, [[Registro-de-Decisoes-2026-10-07]] #31b): o parcial sem saldo não passa sozinho pelo Estoque; alguém confirma na tela e o tempo fica registrado. Antes do marco zero (13/11) todo parcial é tratado como saldo zero.

## Caso C — Item comprado volta da Qualidade para o Estoque (24/09/2026)

```mermaid
sequenceDiagram
    participant Qual as Qualidade
    participant Sist as Sistema (MES)
    participant Alm as Almoxarife (setor Estoque)
    participant Exp as Expedição

    Qual->>Sist: EC1 · aprova o lote do item comprado (sai da quarentena)
    Sist->>Alm: EC2 · parcial volta ao setor Estoque (última etapa do roteiro da Revenda)
    Alm->>Sist: EC3 · entrada do lote na localização de guarda (MovimentoEstoque ENTRADA, ref. recebimento)
    Sist->>Sist: EC4 · Reserva ATIVA do lote para o split + CONCLUIDO
    Alm->>Exp: EC5 · segue pra entrega, igual ao Caso A
```

Regra do Nathan: o item que não tinha em estoque e foi comprado passa por todo o processo (setor Compras, OC, Recebimento, beneficiamento se houver, Qualidade) e, **aprovado, vai para o Estoque, não para a Expedição**. Assim toda entrega de item comprado sai do Estoque com reserva — a mesma porta do Caso A — e o lote comprado entra no saldo antes de sair (genealogia coerente). Reprovação não passa por aqui: volta ao PCP ([[Fluxo-Qualidade-Completo]]).

⚠️ O setor Estoque aparece **duas vezes** no roteiro da Revenda (início e fim). O front de hoje impede setor repetido no roteiro — ver pendência 3 de [[Encaixe-Estoque-Revenda-no-PCP]].

## Caso B — Operação contínua do depósito (independente de pedido)

```mermaid
sequenceDiagram
    participant Alm as Almoxarife
    participant Sist as Sistema (saldo)
    participant PCP
    participant Compras

    Alm->>Sist: EB1 · movimentação entre warehouses (transferência)
    Alm->>Sist: EB2 · contagem cíclica (físico × sistema)
    alt divergência na contagem
        Alm->>Sist: EB3 · ajuste de saldo, motivo obrigatório
    end
    Sist->>PCP: EB4 · saldo cruza o ponto de pedido
    PCP->>Compras: EB5 · dispara requisição preventiva (antes de faltar de verdade)
```

**EB1 — Movimentação entre warehouses**
Transferência entre depósitos compartilhados (Warehouse 01 ↔ Warehouse 02 etc.) — operação real, confirmada no PRD original (múltiplos depósitos).
*Entre filiais (outro CNPJ, com NF de transferência), ver [[Proposta-Transferencia-Estoque-Filiais]] (05/10/2026, proposta com decisões pendentes). **Atualizado em 07/10: só a etapa 1 (saldo por filial) existe no código** — o atendimento mostra o saldo das outras filiais (`outrasFiliais` em `disponiveisParaParcial`); solicitar, aprovar, expedir e receber a transferência não existem.*

**EB2/EB3 — Contagem cíclica**
Mitigação já prevista em [[Estoque-Riscos]] pra "descolamento entre saldo do sistema e saldo físico" — rastreabilidade por lote + **motivo obrigatório** em qualquer ajuste manual.

**EB4/EB5 — Ponto de pedido**
Gatilho de reposição preventiva, **diferente** da requisição reativa do PCP em C1 de [[Fluxo-Compras-Completo]] (que nasce de um pedido de venda específico sem saldo). Esta aqui nasce do próprio saldo cruzando um limiar — sem pedido de origem. Essas são duas origens diferentes pra uma requisição de compra que convergem no mesmo C1 — vale confirmar se merecem o mesmo formulário/tela ou precisam de campos diferentes (uma tem `pedido_venda_origem`, a outra não).

## Nenhum estado é beco sem saída

| Estado problemático | Saída garantida |
|---|---|
| Reserva criada mas pedido cancelado depois | **Decidido em 24/09/2026:** reserva sem expiração, **liberação explícita** (`LIBERADA`) quando o pedido ou a OP é cancelado |
| Item comprado aprovado sem destino | Volta ao setor Estoque (Caso C), que dá entrada e reserva — nunca fica "aprovado e parado" |
| Divergência na contagem cíclica | Ajuste com motivo obrigatório (EB3), nunca silencioso |

## O que este modelo deixa explícito

- **Existem duas origens diferentes de requisição de compra** — reativa (Compras/C1, vem de um pedido de venda sem saldo) e preventiva (Estoque/EB5, vem do ponto de pedido cruzado) — que hoje convergiriam no mesmo C1 de [[Fluxo-Compras-Completo]] sem distinção. Vale decidir se precisam de campos/telas diferentes.
- **Almoxarife e Gestor de Estoque não são o mesmo papel** — Almoxarife opera (separa, confere, movimenta); Gestor de Estoque supervisiona, sem aparecer em nenhuma conversa operacional deste modelo.
- ~~A reserva de estoque (EA3) precisa de liberação explícita quando o pedido de origem é cancelado — gap ainda não resolvido.~~ **Resolvido em 24/09/2026:** sem expiração, liberação explícita no cancelamento do pedido/OP.
- **Toda reserva nasce no setor Estoque sobre lote já liberado** — no Caso A (saldo existente) ou no Caso C (item comprado que voltou). Não existe reserva sobre lote que ainda não chegou.

## Ver também
- [[Encaixe-Estoque-Revenda-no-PCP]]
- [[Setores-Envolvidos-no-Fluxo]]
- [[Rota-Estoque]]
- [[Modelo-Destinacao-Item]]
- [[Fluxo-Compras-Completo]]
- [[Fluxo-Qualidade-Completo]]
- [[Estoque-Modelo-Dados]]
- [[Estoque-Riscos]]
