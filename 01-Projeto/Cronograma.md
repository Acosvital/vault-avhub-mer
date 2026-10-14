---
tags: [projeto, cronograma, marcos, gantt]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [v1 07-Cronograma/Cronograma-2-Meses seções 1, 3.2, 3.3, 3.4, 6, 9, v1 Registro-de-Decisoes #27 #33b #34 #36 #75 #77 #96, código de 14/10 (api-pcp 579a625, app-pcp 1fca8d3, api-acos-vital f322dcd, HUB b55ac55)]
---

# Cronograma

> As estimativas em pd são do Nathan com apoio do Claude, por complexidade (±30%); o Robert as valida item a item antes de a data valer como compromisso 🟡. As datas de marcos M3 a M7 aguardam o aval do Nathan (#36 do Registro do v1) 🟡.

## Regras de datas (únicas)

- A execução do plano vai de **22/09/2026 a 18/12/2026**. S1 a FC terminam em **18/11/2026**; S5 e M7 terminam em **18/12/2026** 📝.
- **Marco zero do saldo: 13/11/2026** (M5): carga inicial conferida em dupla; nenhum consumo por PCP ou Comercial antes disso 📝.
- **Ciclo 1 fecha em 21/01/2027** (o Robert zera o déficit da Onda 0 nessa data). **Ciclo 2 começa em 22/01/2027** 📝 (item 27 do Registro do v1, aceito pelo Nathan em 09/10).
- Feriados considerados: 12/10 e 02/11 de 2026; 25/12, 01/01, Carnaval (08 e 09/02), 26/03, 21/04, 27/05, 07/09, 12/10, 02/11 e 15/11 de 2027.
- O plano de 2 meses (e a duração de 60 dias) não vale mais; esta nota é a única fonte de datas.

## Marcos

| Marco | Data | O que precisa estar pronto | Situação em 14/10 |
|---|---|---|---|
| **M1** Decisões e contratos destravados | 28/09 | DEC-1 a DEC-12 decididas; contratos 001, 002, 004 e 005 fechados | ✅ cumprido |
| **M2** Fundação no ar | 05/10 | Homologação do MES no ar; `PUT` do contrato 34 funcionando; login duplo | ✅ cumprido |
| **M3** Fase 0 (sistema) pronta | 16/10 | Cadastros, RBAC por setor, Triagem e caixa de requisições prontos | 🟡 em curso: `develop` do MES e do av-hub entregaram Compras · CCP e esperados em 14/10 (PRs #55 a #57 do `api-pcp`, #42 e #43 do `app-pcp`) |
| **M4** Fases A + B em homologação | 30/10 | Requisição, OC, referência no MES, recebimento com pesagem, quarentena, inspeção e RNC; levantamento físico (26 a 30/10) | 🟡 recebimento e inspeção no código; referência da OC no MES 🔴 (job do contrato 004 não existe) |
| **M5** Fase 0 fechada + Fase C | 13/11 | Marco zero carregado e conferido em dupla; saldo, movimento e reserva em homologação; status por item no HUB | 🟡 saldo e reserva no código ✅; carga em lote (G1) 🔴 Robert até 23/10 |
| **M6** Go/no-go do piloto de recebimento | 18/11 | Piloto de 11/11 a 18/11 em 1 posto, em paralelo ao processo manual | 🟡 |
| **M7** Rastreabilidade completa | 18/12 | Log de eventos e Torre de Fluxo (mapa, trilha, tempo por etapa) em homologação | 🔴 o MES não publica `/fluxo/eventos` (LOG-46) |
| **Fim do Ciclo 1** | 21/01/2027 | Déficit do Robert (Onda 0) zerado | 🟡 |
| **M8** Flange alta no MES | 14/04/2027 | Itens 1, 2, 4, 5, 6, 7 e 11 do levantamento do PCP legado | 🟡 |
| **M9** Flange completa no MES | 04/06/2027 | Itens 3, 8, 9, 10, 12, 13 e 14; só depois dele se desliga a linha Flange do PCP legado | 🟡 |
| **M10** Caldeiraria HRM no MES | 09/09/2027 | Itens 15 a 22, a Caldeiraria como mais uma fábrica `FABRICACAO` | 🟡 depende de decisões abertas (itens 18 a 20) |
| **M11** Análise e gestão no MES | 21/10/2027 | Itens 23 a 27; os itens 28 e 29 ficam no av-hub, sem dono nem data | 🟡 |

## Janelas

| Janela | Período | Foco |
|---|---|---|
| S1 | 22/09 a 05/10 | Destravar decisões, contratos, homologação |
| S2 | 05/10 a 16/10 | Fase 0 (sistema), núcleo do Estoque, cadastros |
| S3 | 19/10 a 30/10 | Fases A e B (compra até a doca), contagem física |
| S4 | 02/11 a 13/11 | Fase C (saldo, reserva), marco zero, integração |
| FC | 16/11 a 18/11 | Homologação e go/no-go |
| S5 | 19/11 a 18/12 | Rastreabilidade completa e genealogia |
| Ondas W0 a W4 | 21/12/2026 a 21/10/2027 | PCP legado no MES (Robert) |

## Trilhas do Robert depois de 18/12 (W0 a W4)

Equipe igual à atual: só o Robert no MES, 75% de foco (0,75 pd por dia útil). Entra primeiro o déficit.

| Onda | Entra | pd | Acumulado | Fim |
|---|---|---|---|---|
| W0 | Déficit do Ciclo 1 (inclui custo do lote K3 a K6) | 16,1 | 16,1 | 21/01/2027 |
| W1 | Flange, prioridade alta (itens 1, 2, 4, 5, 6, 7, 11) | 42 | 58,1 | 14/04/2027 (M8) |
| W2 | Flange, média e baixa (itens 3, 8, 9, 10, 12, 13, 14) | 26 | 84,1 | 04/06/2027 (M9) |
| W3 | Caldeiraria HRM (itens 15 a 22) | 51 | 135,1 | 09/09/2027 (M10) |
| W4 | Análise e gestão (itens 23 a 27) | 22 | 157,1 | 21/10/2027 (M11) |
| av-hub | Itens 28 e 29 (12 pd) | 12 | fora da conta | sem dono, sem data 🔴 |

Com 100% de foco as ondas terminam em 14/01 (W0), 17/03, 26/04, 07/07 e 06/08/2027. O trabalho que não entra na conta: Ciclo 2 (sobras e perdas de matéria-prima, remessa de produtos, Fase D, transferência etapas 2 a 4, `GET /itens/custo`), baixa no despacho do Estoque (documento de retirada) e fabricado virando lote, ainda sem pd dimensionado 🔴. Levantamento completo em [[Backlog-por-Frente]].

## Capacidade

| Pessoa | Foco | Capacidade S1–FC | Observação |
|---|---|---|---|
| Nathan | 40% | 16,8 pd | S5: 11 pd contra 9,2 pd; propõe-se levar a tela de ranking de gargalos (T.6) ao Ciclo 2 🟡 |
| Gustavo | 60% | 25,2 pd | folga de 11,9 pd na S1–FC e 9,8 pd na S5; pode receber parte do backend do MES 🟡 |
| Robert | 75% | 31,5 pd | S1–FC + S5: capacidade 48,75 pd contra 64,85 planejados, **déficit de 16,1 pd** 🔴 |
| Pablo | 75% | fora da conta | Comercial & Suprimentos |

Custo do lote (09/10) somou ao Robert K3 1,0 + K4 3,0 + K5 1,5 + K6 0,5 pd; ao Gustavo K1, K2 e K7 (1,5 pd); K8 (`GET /itens/custo`) e K9 a K11 vão ao Ciclo 2 🟡. Detalhe em [[Modelo-Estoque-e-Custo-do-Lote]] e [[API-008-Custo-do-Lote-no-MES]]. Equipe em [[Equipe-e-Divisao]].

## Comercial & Suprimentos (Pablo, fora do plano original)

| ID | Entrega | Estado |
|---|---|---|
| CS1 | `api-comercial` e Propostas (CRUD, fechar, perder, reabrir, versões, PDF) | ✅ na `develop` |
| CS2 | Suprimentos: catálogo, fornecedores, ofertas, mapa de cotação, solicitações de custo | ✅ na `develop` |
| CS3 | Painel do Comprador, histórico de compras, produtos pendentes | ✅ na `develop` |
| CS4 | E2E Playwright e CI | ✅ na `develop` |
| CS5 | Publicar o `api-comercial`, cadastrar telas em `auth.telas`, claim `perfis` no token | 🔴 Pablo, sem data. Ver [[Comercial-Suprimentos]] |

## Gantt

Barras concluídas marcam o que está no código, não o que está em produção. As datas finais são inclusivas.

```mermaid
gantt
    title Cronograma de 22/09/2026 a 21/10/2027
    dateFormat YYYY-MM-DD
    axisFormat %d/%m
    inclusiveEndDates
    section Marcos
    M1 Decisoes e contratos destravados :milestone, m1, 2026-09-28, 0d
    M2 Fundacao no ar :milestone, m2, 2026-10-05, 0d
    M3 Fase 0 sistema pronta :milestone, m3, 2026-10-16, 0d
    M4 Fases A e B em homologacao :milestone, m4, 2026-10-30, 0d
    M5 Marco zero e Fase C :milestone, m5, 2026-11-13, 0d
    M6 Go ou no-go do piloto :milestone, m6, 2026-11-18, 0d
    M7 Rastreabilidade completa :milestone, m7, 2026-12-18, 0d
    Fim do Ciclo 1 :milestone, mc1, 2027-01-21, 0d
    Inicio do Ciclo 2 :milestone, mc2, 2027-01-22, 0d
    M8 Flange alta no MES :milestone, m8, 2027-04-14, 0d
    M9 Flange completa no MES :milestone, m9, 2027-06-04, 0d
    M10 Caldeiraria HRM no MES :milestone, m10, 2027-09-09, 0d
    M11 Analise e gestao no MES :milestone, m11, 2027-10-21, 0d
    section Janelas do plano
    S1 Destravar e fundacao :done, s1, 2026-09-22, 2026-10-05
    S2 Fase 0 e nucleo do Estoque :active, s2, 2026-10-05, 2026-10-16
    S3 Fases A e B :s3, 2026-10-19, 2026-10-30
    S4 Fase C e marco zero :s4, 2026-11-02, 2026-11-13
    FC Homologacao e go ou no-go :fc, 2026-11-16, 2026-11-18
    S5 Rastreabilidade completa :s5, 2026-11-19, 2026-12-18
    section Estoque e carga inicial
    G1 Carga inicial em lote :g1, 2026-10-13, 2026-10-23
    G2 Levantamento fisico em dupla :g2, 2026-10-26, 2026-10-30
    G3 Carga e conferencia :g3, 2026-11-02, 2026-11-11
    G4 Conferencia em dupla fecha a Fase 0 :g4, 2026-11-09, 2026-11-13
    H4 Piloto de Recebimento em 1 posto :h4, 2026-11-11, 2026-11-18
    section Integracao e custo
    K1 K2 SQL 012 e rota 004 com valores :k12, 2026-10-19, 2026-10-30
    K4 K5 Job da referencia da OC e custo no recebimento :k45, 2026-12-21, 2027-01-21
    section Ondas do Robert PCP legado
    W0 Deficit do Ciclo 1 :w0, 2026-12-21, 2027-01-21
    W1 Flange prioridade alta :w1, 2027-01-22, 2027-04-14
    W2 Flange media e baixa :w2, 2027-04-15, 2027-06-04
    W3 Caldeiraria HRM :w3, 2027-06-07, 2027-09-09
    W4 Analise e gestao no MES :w4, 2027-09-10, 2027-10-21
```

## Entregas já no código (14/10)

| Frente | Entrega | Evidência |
|---|---|---|
| MES | Compras · CCP só leitura, esperados no Recebimento, chegada só com NF, marcos por etapa | `api-pcp` PRs #55, #56, #57 (`d7e5cf2`, `f5ce799`, `e104236`); `app-pcp` PRs #42, #43 |
| MES | Envio da requisição (contrato 34) e leitura dos eventos (contrato 35) | `integracao-avhub/envio-avhub.service.ts`, `eventos-avhub.service.ts` |
| av-hub | `itens_pedido_custo` por produto (047b), feed da Torre (046b), autor e comprador nos eventos (035b) | `api-acos-vital` `f322dcd`, `7c3f57a`, `2aee636` |
| HUB | Acompanhamento de clientes v2 | `b55ac55` (PR #194) |
| Pipeline | Envio da OC fixo, sem flags `SYNC_ENVIO_OC` e `ENVIO_OC_DRY_RUN` | `omie-elt-pipeline` `0f739f0` (PR #3) |

## Ordem de corte (para manter a data fixa) 🟡

Se algo estourar, o escopo cede, a data não. Cortar nesta ordem: (1) stretch B9 e B10 (histórico de OC, frete e parcelas); (2) C8, fila "Novo norte" do PCP; (3) status por item só para Fabricação e Recebimento; (4) D11 em Code128 em vez de leitor 2D; (5) reserva de estoque na Fase C. **Nunca cortar:** quarentena, inspeção e RNC; dupla conferência da carga; RBAC por setor. A ordem de corte alivia no máximo ~4,0 pd do Robert; os 12 pd restantes do déficit pedem decisão do Nathan (estender a janela, levar a J5 ao Ciclo 2 ou devolver parte do backend ao Gustavo) 🔴 Nathan. Riscos e gatilhos em [[Riscos]].

## Pendências

- 🔴 Robert valida as estimativas de pd das ondas W0 a W4 e de K3 a K6.
- 🔴 Nathan decide como cobrir os 16,1 pd de déficit e confirma M3 a M7.
- 🔴 Robert informa a data do merge `develop` → `main` do MES antes do piloto (a `main` do `api-pcp` está em 08/10, 11 commits atrás da `develop`).
- ❓ Dono do pipeline e dos itens 28 e 29 do levantamento do PCP legado. Ver [[Pontas-Soltas]].
