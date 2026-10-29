---
tags: [comissao, estados, regras, controladoria, proposta]
criado: 2026-10-21
atualizado: 2026-10-29
status: proposta
dono: Nathan
fontes: [ (comissoes, comissoes_nf, comissao_lancamentos, comissao_devolucao_pendencia), N16-10, N16-42 a N16-51, N16-74]
---

# Regras e estados da comissão nova

**Em uma frase:** a comissão nova passa por estados claros, do estimado na proposta até a decisão da Controladoria, e o banco impede que alguém pule uma etapa.

**Quando consultar esta nota:** quando precisar saber em que estado está uma comissão, o que vem depois e quais regras valem. Modelo completo: [[03-Modelo-Novo-core_comissao]].

## O caminho da comissão

1. **Estimada:** a proposta é salva e o vendedor vê a comissão que ele colocou.
2. **Congelada:** a proposta foi aprovada e a estimativa trava.
3. **Em acompanhamento:** o pedido existe, o custo real chega e as notas fiscais (NF) fecham.
4. **Decisão por NF:** a Controladoria aprova, desaprova, corta, altera ou bloqueia, sempre com justificativa.
5. **Encerrada:** tudo foi faturado e decidido.

Se a proposta ou o pedido for cancelado antes de faturar, a comissão vira histórico, com o motivo.

## Exemplo

Venda de R$ 1.000 a 2%, faturada em seis notas (500, 100, 100, 100, 100 e 100). Cada nota fecha com 2% sobre o seu valor e chega à Controladoria já calculada. A comissão total é R$ 20. O banco nunca paga duas vezes a mesma peça. Se uma nota for devolvida, a comissão cai na mesma proporção.

## Regras que valem

- Decidem Controladoria, Gerência e Coordenação, sem teto. Ninguém decide a própria comissão.
- O vendedor só vê o valor real depois da decisão, com a justificativa.
- Com custo parcial, só as peças com custo real entram. A diferença volta na apuração seguinte.
- Cada nota fecha com o percentual vigente naquele momento.
- Nota cancelada ou devolvida abate a comissão. Se já foi paga, o desconto entra na próxima apuração.

## Detalhe técnico

Resumo dos estados e das regras que o banco impõe. Modelo: [[03-Modelo-Novo-core_comissao]].

### 1. Dossiê da proposta (`comissoes`)

| Estado | Quando | Sai para |
|---|---|---|
| `ESTIMADA` | a proposta é salva e revisada (`K1`) | `CONGELADA`, `CANCELADA` |
| `CONGELADA` | a proposta foi aprovada; a estimativa trava | `EM_ACOMPANHAMENTO`, `CANCELADA` |
| `EM_ACOMPANHAMENTO` | o pedido foi criado; custo real chega (`K2`); NFs fecham (`K3`) | `ENCERRADA`, `CANCELADA` (só sem NF faturada) |
| `ENCERRADA` | tudo faturado e decidido | — |
| `CANCELADA` | proposta ou pedido cancelado antes de faturar; vira histórico com motivo | — |

### 2. Comissão da nota fiscal (`comissoes_nf`)

`AGUARDANDO_DECISAO` → `APROVADA`, `DESAPROVADA` (R$ 0, visível), `CORTADA`, `ALTERADA` ou `BLOQUEADA` (retida; `DESBLOQUEAR` devolve à fila com justificativa). `NF_CANCELADA` quando a NF é cancelada por inteiro antes da decisão.

### 3. Lançamentos (`comissao_lancamentos`)

| Tipo | Origem | Decisão |
|---|---|---|
| `COMPLEMENTO` | o custo completou e a comissão sobe | nova decisão |
| `DESCONTO` | o custo completou e a comissão cai | nova decisão |
| `ABATIMENTO` | NF cancelada, devolvida ou recusada | sem decisão; proporcional; soma até 100 |

### 4. Devolução parcial (`comissao_devolucao_pendencia`)

`ABERTA` (marcada no Omie, sem item, quantidade e valor) → `INFORMADA` (Fiscal ou Controladoria informam) ou `DISPENSADA` (a devolução total abateu 100%).

### 5. Regras

1. Decidem Controladoria, Gerência e Coordenação, sem teto, com justificativa e rastro; ninguém decide a própria comissão.
2. O vendedor só vê o valor real depois da decisão, com a justificativa.
3. Custo parcial: só as peças com custo real; a diferença volta na apuração seguinte, para nova decisão.
4. A comissão fecha por NF com o percentual vigente naquele momento, sem pagar duas vezes a mesma quantidade.
5. Abatimento: se a comissão não foi paga, reduz o valor a pagar; se foi, desconta na próxima apuração.

### Ver também

[[01-Motor-Atual-Como-Calcula]] · [[02-Tabelas-Atuais-core_comissionamento]] · [[03-Modelo-Novo-core_comissao]]
