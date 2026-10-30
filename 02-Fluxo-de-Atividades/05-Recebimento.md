---
tags: [fluxo, raia, recebimento, doca, nf, conferencia, divergencia, lote, mes, r0, r1, r2, r3, r4, r6]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Robert (MES) · Nathan (decisões)
fontes: [00-Fluxo-Mestre-0b, Integracao-AvHub-MES (INT-03), API-007, API-008, v1 02-PRD-Estoque/Fluxo-Recebimento-Completo, v1 App-PCP-Recebimento-Conferencia, decisões do Nathan de 14/10 (conferência contra a NF), api-pcp 579a625 (recebimento.service.ts, compras.service.ts, compras.prisma, compras-ccp.dto.ts), app-pcp 1fca8d3 (FilaSetor, ConferirRecebimentoModal, decisoes-pcp), api-pcp develop de 27/10/2026 (recebimento por OC e por NF, custo da OC), API-011, N16-134 a N16-137]
---

# Raia Recebimento (R0 a R6)

**Em uma frase:** a doca recebe o material comprado, confere contra a nota fiscal (NF) e transforma o que chegou em lote em quarentena, para a Qualidade inspecionar. Enquanto houver divergência aberta, nada entra no estoque.

Nós do [[00-Fluxo-Mestre-0b]]: `R0`, `R1`, `R2`, `R3`, `R4`, `R6`. Entrada: `FN1` ([[04-Circuito-de-Compra]]). Saída: `Q1` ([[06-Qualidade-Entrada]]) ou `P6` ([[02-PCP-Triagem-e-Destinacao]]). Selos em [[Regras-do-Vault]].

> [!info] Decisões de 29/10/2026 (N16-120 a N16-143)
> - N16-134: tolerância de peso de 5% por padrão, ajustável por material.
> - N16-135: quando houver cruzamento com a OC, divergência contra a OC bloqueia, como a da nota.
> - N16-136: uma nota pode trazer itens de mais de uma OC. A conferência é por item da OC (proposta do Robert). Na `develop` do MES isso já existe: `POST /compras/recebimentos/nf` recebe várias conferências na mesma nota, cada uma de uma requisição do MES ou de uma OC do hub, e a tela "Receber com NF" aceita vários itens (`api-pcp` 19 a 20/10, `app-pcp` `5f50fff`, `9ced089`) ✅.
> - N16-137: a reabertura pelo PCP avisa o av-hub. Exige contrato novo entre MES e hub.
> - Código: o que aparece como ✅ de MES, a partir da conferência por OC e do custo da OC, está na `develop` do `api-pcp` e do `app-pcp`. A `main` do MES parou em 08/10 e só recebe com o merge BL-035.

## Como funciona, passo a passo

1. **A OC é aprovada.** A parcial (a parte do pedido que espera o material) entra na lista de esperados da doca. Compras também pode liberar à mão (`R0`).
2. **A carga chega com a nota.** A doca informa o número ou a chave de 44 dígitos da NF. Sem NF, a parcial não sai de Compras · CCP (`R0`).
3. **A doca confere contra a NF.** Conta o que chegou e compara com a nota, não com a OC. Receber mais do que o pedido é permitido, e a sobra fica livre no estoque (`R1`).
4. **A doca pesa.** Se o material tem peso teórico, o peso real é obrigatório. Desvio acima de 5% vira divergência de peso (`R2`).
5. **O sistema confere.** Se não há divergência, o lote nasce na hora. Se há, nada entra e outra pessoa precisa recontar (`R3`).
6. **Cria o lote em quarentena.** O lote nasce pendente, com entrada no saldo. Segue para a Qualidade (`R4`).
7. **Chegou só uma parte?** Essa parte vai à Qualidade. O restante volta a Compras · CCP, esperando a próxima NF (`R4`).
8. **Divergência: outra pessoa reconta.** Quem conferiu não reconta. A recontagem pede todos os itens (`R6`).
9. **Se a recontagem ainda diverge, o PCP decide.** Aceita (entra o que foi recontado) ou reabre (nada entra e a parcial volta a Compras). O motivo é obrigatório (`R6`).

## Exemplo

A OC dos 100 flanges está aprovada, então a parcial aparece na lista da doca. Na chegada, a doca informa a NF e a parcial passa ao Recebimento.

A NF diz 100 flanges e a doca conta 100. O flange tem peso teórico cadastrado, então a doca digita o peso real. Tudo bate, e o lote nasce pendente, com entrada no saldo, rumo à Qualidade.

Se faltassem flanges mesmo depois da recontagem, o PCP decidiria entre aceitar o que chegou ou reabrir a compra.

## Quem atua

| Quem | O que faz |
|---|---|
| Doca (conferente) | Registra a chegada com a NF, conta, pesa e informa avaria e descrição |
| Segunda pessoa | Reconta quando há divergência |
| PCP | Aceita ou reabre quando a recontagem continua divergindo |
| Compras | Libera para o Recebimento sem OC aprovada; em geral só o Administrador |
| Qualidade | Recebe o lote e inspeciona |

## Regras que valem

- A conferência é contra a nota, não contra o pendente nem contra a OC.
- Sem NF, a parcial não sai de Compras · CCP. Assim o tempo do fornecedor não cai no Recebimento.
- Divergência aberta trava a entrada no estoque.
- Quem conferiu não pode recontar.
- Peso real é obrigatório quando há peso teórico. Tolerância padrão de 5%, por material.
- Avaria exige foto.
- O lote sempre nasce em quarentena, mesmo item acabado.
- O Recebimento nunca decide compra. A divergência vai ao PCP, e a reabertura devolve a Compras.
- Só pode haver um recebimento aberto por parcial.
- O custo do lote vem da OC, hoje é opcional e não bloqueia o recebimento. A N16-09 manda que todo lote tenha custo (obrigatório, BL-066), o que ainda não vale no código.
- Divergência contra a OC também bloqueia, quando o cruzamento existir (N16-135).

## O que já existe e o que falta

- ✅ Telas de recebimento, recontagem e decisão do PCP; lote em quarentena com etiqueta em PDF.
- ✅ Recebimento parcial com divisão da parcial.
- ✅ Na `develop` do MES: o custo da OC é gravado no lote (19/10, `97b9adc`; unidade diferente da OC ou OC fora da projeção gera lote sem custo e sinalizado).
- ✅ Na `develop` do MES: entrada de mercadoria de OC sem requisição do MES (OC criada só no av-hub), por OC e por NF, e uso interno sem lote (16 a 20/10).
- 🔴 A conferência ainda não cruza com a OC (preço, quantidade comprada, fornecedor); só compara contado com a NF. O rateio da chegada entre destinos da OC também falta (API-011).
- 🔴 Aviso ao av-hub quando o PCP reabre o recebimento; leitor de código de barras da NF; reabertura de divergência de produção.
- 🟡 Aviso à doca quando uma OC esperada é cancelada.
- 🔴 Alerta de OC que passou da previsão sem chegar.
- ❓ Teste ponta a ponta com OC real.

## Detalhe técnico

### Nós

Nós do [[00-Fluxo-Mestre-0b]]: `R0` esperados e chegada com NF, `R1` conferência contra a NF, `R2` pesagem, `R3` bate com o esperado?, `R4` cria o lote em quarentena, `R6` divergência. (`R5` não existe no 0b.) `FN1` é o fornecedor entregando.

### Quem atua (onde)

| Quem | Papel | Onde |
|---|---|---|
| Doca (conferente) | Registra a chegada com NF, conta, pesa, informa avaria e descrição | MES, `/logistica/logistica-entrada` |
| Segunda pessoa | Reconta quando há divergência (quem conferiu **não** pode recontar) | idem |
| PCP | Decide `ACEITAR` ou `REABRIR` quando a recontagem continua divergindo | MES, `/decisoes-pcp` |
| Compras (`compras-liberar`, em geral só o Administrador) | Libera a requisição para o Recebimento sem OC aprovada | `FilaSetor` / `CompraCcpCard` |
| Qualidade | Recebe o lote | [[06-Qualidade-Entrada]] |

Permissões: `movimentacoes` (visualizar ou editar) para conferir e recontar; `decisoes-pcp` para listar e decidir; `pode_atuar` no setor Recebimento (`PerfilSetor`) para a chegada e a recontagem (`compras.service.ts:381-382`, `recebimento.service.ts:260`); a decisão do PCP **não** exige setor (`recebimento.service.ts:336`, `registrarRecebimento` com `checarPermissaoSetor: false`).

### Regras decididas

| # | Regra | Selo |
|---|---|---|
| 1 | **Esperados:** só aparece na lista da doca a parcial em Compras · CCP cuja requisição tem **OC aprovada** no av-hub (e não cancelada) ou **liberação manual** | 📝 ✅ `compras.service.ts:305-351`, `:448-456` |
| 2 | **Sem NF a parcial não sai de Compras · CCP**, para o tempo do fornecedor não cair no Recebimento. A doca informa número ou **chave de 44 dígitos** | 📝 ✅ `compras.service.ts:356-370`, `compras-ccp.dto.ts:17-20` |
| 3 | **A conferência é contra a NF**, não contra o pendente nem a OC. Receber mais do que a requisição pede é permitido; a sobra fica livre no estoque | 📝 ✅ `recebimento.service.ts:100-102`, `:176-177`; `compras.service.ts:464` |
| 4 | **Peso:** se o material tem peso teórico, o **peso real é obrigatório**; desvio acima da tolerância (padrão 5%, por material) vira divergência `PESO` | 📝 ✅ `recebimento.service.ts:373-400`, `estoque.prisma:167` |
| 5 | Tudo bate: o lote nasce **na hora**, `PENDENTE`, com `ENTRADA` no saldo na localização da conferência; recebimento `CONCLUIDO` | 📝 ✅ `recebimento.service.ts:200-231`, `compras.service.ts:537-568` |
| 6 | Diverge: **nada entra**; `AGUARDANDO_RECONTAGEM`; outra pessoa reconta | 📝 ✅ `recebimento.service.ts:233-244`, `:254-258` |
| 7 | Recontagem bate: `CONCLUIDO`. Continua divergindo: `AGUARDANDO_DECISAO` do PCP | 📝 ✅ `recebimento.service.ts:315-326` |
| 8 | PCP `ACEITAR` (entra a quantidade recontada) ou `REABRIR` (nada entra; a parcial volta a Compras · CCP); **motivo obrigatório** | 📝 ✅ `recebimento.service.ts:331-368`, `conferir-recebimento.dto.ts:140-143` |
| 9 | **Recebimento parcial faz split:** o que chegou segue para a Qualidade, o **restante volta a Compras · CCP** aguardando a próxima NF | 📝 ✅ `compras.service.ts:506-531`, `:590-611` |
| 10 | Avaria exige foto (URL de evidência); descrição e avaria são informadas pelo conferente; quantidade e peso o sistema calcula | ✅ `recebimento.service.ts:411-413`; `compras.prisma:39-47` |
| 11 | Só um recebimento aberto por parcial (409 se há conferência aguardando recontagem ou decisão) | ✅ `recebimento.service.ts:534-546` |
| 12 | Lote **sempre** nasce `PENDENTE` (quarentena), mesmo item "acabado" | 📝 ✅ `compras.service.ts:545-547` |
| 13 | **Custo do lote vem da OC.** Hoje é opcional e não bloqueia o recebimento; a N16-09 torna o custo obrigatório em todo lote | 📝 ✅ gravado na `develop` (19/10, `97b9adc`; ver R4); 🔴 obrigatório (BL-066) |
| 14 | Recebimento nunca decide compra: a divergência vai ao PCP; o `REABERTO` devolve a Compras | 📝 ✅ `recebimento.service.ts:340-351` |

### Estados

#### `StatusRecebimento` (`compras.prisma:31-37`)

| Valor | Significado | Próximo |
|---|---|---|
| `CONCLUIDO` | Bateu (na conferência ou na recontagem); lotes criados | Qualidade |
| `AGUARDANDO_RECONTAGEM` | Divergiu; nada entrou | recontagem por outra pessoa |
| `AGUARDANDO_DECISAO` | A recontagem continua divergindo | PCP |
| `ACEITO` | PCP aceitou; entrou a quantidade recontada | Qualidade |
| `REABERTO` | PCP reabriu; nada entrou | Compras · CCP |

#### `TipoDivergenciaRecebimento` (`compras.prisma:42-47`)

`QUANTIDADE` (contado ≠ NF, calculada), `PESO` (fora da tolerância, calculada), `DESCRICAO` (informada), `AVARIA` (informada, com foto). Cada divergência guarda `etapa`: `conferencia` ou `recontagem`.

#### Parcial e requisição

Parcial no setor `LOGISTICA_ENTRADA` (nome "Recebimento", código `logistica-entrada`) em estado "aguardando": `CRIADO`, `EM_TRANSITO`, `RECEBIDO` ou `EM_ANDAMENTO` (`STATUS_AGUARDANDO`, `circuito-compra.ts:30-35`). `StatusRequisicaoCompra`: `ABERTA`/`EM_COMPRA` → `RECEBIDA_PARCIAL` → `RECEBIDA` (`compras.service.ts:576-579`); `CANCELADA`. Lote: `PENDENTE` ([[06-Qualidade-Entrada]], [[Estados-e-Status]]).

### Telas

| Nome atual | Nome antigo | Rota | Slug | Ações |
|---|---|---|---|---|
| Recebimento | Logística de entrada | `/logistica/logistica-entrada` | `logistica-entrada` | lista de esperados, **Receber com NF** (`FilaSetor.tsx:594`, `ReceberComNfModal.tsx:56`), **Conferir recebimento** (`FilaSetor.tsx:923`, `ConferirRecebimentoModal.tsx:199`), **Recontar** (`FilaSetor.tsx:936`, `RecontarRecebimentoModal.tsx:91`), **Liberar para o Recebimento sem OC** (`FilaSetor.tsx:911`) |
| Divergências de Recebimento | Decisões do PCP | `/decisoes-pcp` | `decisoes-pcp` | Aceitar ou Reabrir com motivo (`decisoes-pcp/page.tsx`) |
| Compras · CCP | Pedidos de Compra | `/compras/pedidos-compra` | `pedidos-compra` | onde a parcial espera até a NF chegar ([[04-Circuito-de-Compra]]) |

`/logistica/logistica-entrada/page.tsx` é só `ModuloSetores` com `tipos=['LOGISTICA_ENTRADA']`. A NF da chegada vem pré-preenchida na conferência (`ConferirRecebimentoModal.tsx:60`). Não há leitor de código de barras: a chave de 44 dígitos é digitada.

### Endpoints e contratos

| Método e rota | Permissão | Efeito | Código |
|---|---|---|---|
| `GET /compras/requisicoes/esperados` | `movimentacoes:visualizar` | R0: lista de esperados | `compras.controller.ts:45-51` ✅ |
| `POST /compras/requisicoes/:id/chegada` `{idItemParcial, numeroNf?, chaveAcessoNf?}` | `movimentacoes:editar` | R0: grava `nfChegada`, `chaveNfChegada`, `chegadaEm`; parcial vai ao Recebimento | `compras.controller.ts:93-103`, `compras.service.ts:356-399` ✅ |
| `POST /compras/requisicoes/:id/liberar-recebimento` `{motivo}` | `movimentacoes:editar` + `compras-liberar` | Rede de segurança (motivo até 500) | `compras.controller.ts:105-115`, `compras.service.ts:404-446` ✅ |
| `GET /compras/recebimentos`, `GET /:id` | `movimentacoes:visualizar` | Lista (até 200) e detalhe | `recebimento.controller.ts:26-43` ✅ |
| `GET /compras/recebimentos/decisoes` | `decisoes-pcp:visualizar` | Fila `AGUARDANDO_DECISAO` | `:32-37` ✅ |
| `POST /compras/recebimentos` | `movimentacoes:editar` | R1 a R4: conferir (`idRequisicao`, `idItemParcial`, itens com `quantidadeNf`, `quantidadeContada`, `pesoReal`, `idLocalizacao`; cabeçalho `numeroNf`, `chaveAcessoNf`, `fornecedor`, `laudoUrl`; divergências informadas) | `:45-49` ✅ |
| `POST /compras/recebimentos/nf` | `movimentacoes:editar` | Conferência de uma NF com várias conferências, cada uma de uma requisição do MES (`itensRequisicao`) ou de uma OC do hub sem requisição (`idOrdemCompra` e `itensOc`); item de uso interno não vira lote | `recebimento.controller.ts`, `recebimento.service.ts` (`ConferirNfDto`) ✅ `develop` |
| `GET /compras/recebimentos/oc-esperadas` | `movimentacoes:visualizar` | Esperados por item de OC aprovada, com ou sem requisição do MES | `recebimento.controller.ts` ✅ `develop` |
| `POST /compras/recebimentos/:id/recontar` | `movimentacoes:editar` | Recontagem por outra pessoa | `:51-59` ✅ |
| `POST /compras/recebimentos/:id/decidir` `{decisao: ACEITAR\|REABRIR, motivo}` | `decisoes-pcp:editar` | Decisão do PCP | `:61-69` ✅ |
| `POST /compras/requisicoes/:id/recebimentos` | — | **Removida**; o registro direto não existe mais | ✅ |
| `GET /estoque/lotes/:id/etiqueta` | Estoque | PDF Code128 do lote | `estoque/etiquetas/etiqueta.controller.ts` ✅ |

Contratos de apoio: [[LOG-35-Compras-Marcos-Requisicao-para-MES]] (marco `oc_aprovada` põe a parcial nos esperados), [[API-004-Referencia-OC-Integracao-MES]] e [[API-007-Referencia-OC-Valores-no-MES]] (referência e valores da OC; o MES consome na `develop`, K4 de 15/10), [[API-008-Custo-do-Lote-no-MES]] (custo no lote).

### Como está no código

#### R0: esperados e chegada com NF

✅ O marco `oc_aprovada` grava `ocAprovadaEm` no item da requisição (`requisicao-avhub.eventos.ts:275-280`). `podeReceber` = `liberadaRecebimentoEm` preenchido **ou** algum item com `ocAprovadaEm` e `etapaCompra ≠ CANCELADA` (`compras.service.ts:448-456`). Os esperados saem ordenados por `previsaoEntrega` (`:346-350`). Na chegada, o service exige: requisição não cancelada, `podeReceber`, parcial do mesmo item do pedido, parcial **em Compras · CCP** e aguardando, e `pode_atuar` no setor Recebimento (`:362-382`). A parcial vai `EM_TRANSITO` ao Recebimento com a observação "Chegou a NF … aguardando a conferência" (`:386-398`). `oc_cancelada` tira dos esperados e devolve ao comprador (`requisicao-avhub.eventos.ts:300-307`).

#### R1: conferência contra a NF

✅ `RecebimentoService.conferir` valida que cada item pertence à requisição e entra uma vez só, que a localização existe, e que algo foi contado (`recebimento.service.ts:147-162`). Para cada item calcula `pendente = max(quantidade − quantidadeRecebida, 0)` e avalia **contado × NF** (`:164-171`, `:373-381`). Grava `Recebimento` (`RB-AAAAMMDD-NNNN`), `RecebimentoItem` e `RecebimentoDivergencia` (`:452-504`, `:548-552`).

#### R2: pesagem

✅ Peso teórico = `Material.pesoTeoricoUnitario × contado`; sem peso teórico o item não é pesado; com ele, o peso real digitado é obrigatório (400 se falta) e o desvio acima de `toleranciaPeso` vira `PESO` (`recebimento.service.ts:382-398`). Balança sem saída digital: o peso é digitado.

#### R3: bate com o esperado?

✅ "Bate" = nenhuma divergência calculada nem informada. Não bate: `AGUARDANDO_RECONTAGEM`. A recontagem exige **todos** os itens (`:263-265`), mantém `DESCRICAO` e `AVARIA` já apontadas (`:275-277`) e reavalia quantidade e peso. Se ainda diverge: `AGUARDANDO_DECISAO`.

#### R4: cria o lote em quarentena

✅ `ComprasService.registrarRecebimento` (`compras.service.ts:472-616`), numa transação com retry de código (`LT-AAAAMMDD-NNNN`):
1. Lote `PENDENTE`, `origem RECEBIMENTO`, `quarentenaDesde`, com `idRequisicaoItem`, NF, fornecedor (`:541-554`).
2. `SaldoEstoque` (`aplicarDeltaSaldo`) e `MovimentoEstoque` `ENTRADA` na localização (`:557-568`).
3. `quantidadeRecebida` do item incrementa; a requisição vira `RECEBIDA` (todos os itens cobertos) ou `RECEBIDA_PARCIAL` (`:569-579`).
4. A parcela que o recebimento cobre avança: na revenda, o que chegou do **produto final**, `min(parcial, produtoFinal)`; só com matéria-prima, a parcial inteira quando tudo chegou (`:508-526`). Se é a parcial toda, `moverParcial`; se é parte, `splitParaDestino` (nasce parcial nova) para o setor `QUALIDADE` com `idLoteCompra` apontando o lote (`:590-601`).
5. O restante volta a **Compras · CCP** `EM_TRANSITO`, com "falta N" (`:604-611`).

✅ **Custo da OC gravado (na `develop`, 19/10, `97b9adc`).** O lote do Recebimento nasce com `idOcItem` e com `lote_custo` de `origem = OC` (`compras.service.ts` e `recebimento.service.ts` chamam `loteCusto.create` com o custo calculado de `compra-oc.ts`). Unidade diferente da OC ou OC fora da projeção gera lote sem custo e sinalizado (D2). Registro de 14/10 (superado): não havia `loteCusto.create` no recebimento. 🔴 Falta o custo obrigatório em todo lote (BL-066, N16-09).

#### R6: divergência e decisão do PCP

✅ `REABRIR`: recebimento `REABERTO`; a parcial volta ao setor Compras com "reaberto pelo PCP: motivo — volta a Compras (devolução ao fornecedor / nova compra)" (`recebimento.service.ts:340-351`). `ACEITAR`: entra a quantidade recontada (ou a contada); se nada foi contado, 400 "use Reabrir compra" (`:354-360`). 🔴 Não existe "reabrir divergência de produção" (o 0b prevê o vazio de P6) e a reabertura não avisa o av-hub: a OC segue `atendida` ([[04-Circuito-de-Compra]], ponta solta 7).

### Dados

| Tabela (`public`, MES) | Campos que importam |
|---|---|
| `requisicoes_compra` | `pedido_compra`, `fornecedor`, `previsao_entrega`, `comprado_em`, `liberada_recebimento_*`, `motivo_liberacao`, `nf_chegada`, `chave_nf_chegada`, `chegada_em` (`compras.prisma:84-104`) |
| `requisicoes_compra_itens` | `quantidade`, `quantidade_recebida`, `etapa_compra`, `numero_oc`, `oc_aprovada_em`, `previsao_chegada`, `despachada_em`, `nf_fornecedor`, `transportadora`, `ocorrencia_aberta` (`:119-164`) |
| `recebimentos` | `codigo`, `status`, `numero_nf`, `chave_acesso_nf`, `fornecedor`, `laudo_url`, `conferido_por_id`, `recontado_por_id`, `decidido_por_id`, `motivo_decisao` (`:168-210`) |
| `recebimentos_itens` | `quantidade_pendente`, `_nf`, `_contada`, `_recontada`, `peso_teorico`, `_real`, `_recontado`, `tolerancia_peso`, `id_localizacao`, `id_lote` (`:212-240`) |
| `recebimentos_divergencias` | `tipo`, `descricao`, `evidencia_url`, `etapa` (`:242-257`) |
| `lotes` | `PENDENTE`, `id_requisicao_item`, `numero_nf`, `fornecedor` ([[03-Estoque-Atendimento-e-Despacho]]) |

Migrations: `20261006140000_recebimento_conferencia`, `20261014120000_compras_ccp`. Modelo geral em [[Banco-MES]].

### Mercadoria de OC sem requisição do MES (C0)

✅ **Feito na `develop` do MES (16 a 20/10/2026, BL-051):** a mercadoria de OC sem requisição do MES entra pelos esperados por item de OC (`GET /compras/recebimentos/oc-esperadas`) e pela conferência por OC (`POST /compras/recebimentos/nf`, `itensOc`), com o lote ligado ao item da OC e ao custo; o uso interno vira `EntradaUsoInterno`, sem lote nem saldo (N14-30). Ver [[API-011-Compra-em-Andamento-Recebimento-por-Item-da-OC-e-Uso-Interno]]. O texto abaixo é o registro do desenho e do estado de 14/10.

📝 N14-20: o MES passa a ler as OCs do hub. A mercadoria de uma OC criada a partir de requisição só do av-hub (ou de uma OC de estoque, sem requisição) precisa ter entrada no Estoque, mas o Recebimento do MES, em 14/10, **exigia requisição do MES**: a chegada pede requisição não cancelada, `podeReceber`, parcial do mesmo item do pedido **em Compras · CCP** e `pode_atuar` no Recebimento (`compras.service.ts:362-382`), e a conferência valida que cada item pertence à requisição (`recebimento.service.ts:147-162`). Uma OC sem `id_origem` não tem parcial nem requisição no MES, então não cai nos esperados.

Caminho necessário 🟡 (proposta; o desenho é do Robert):
1. O job do contrato 004/007 (BL-001) grava a projeção da OC aprovada; o item traz `id_requisicao` nulo ou sem `id_origem` e o `destino` (pedido de venda ou estoque) ✅ `vw_ordens_compra_referencia_mes.swagger.json:44-88`.
2. A OC aprovada sem requisição do MES entra nos **esperados** do Recebimento como "esperado por OC", sem parcial, com fornecedor, quantidade, previsão e destino vindos da referência.
3. A doca registra a chegada com a NF e confere contra a NF (regra de hoje, N14-04); o lote nasce `PENDENTE`, em quarentena, e segue para a Qualidade como qualquer outro.
4. O que o `destino` marca como **pedido de venda** reserva o lote para aquele pedido e avisa o PCP; o que é **estoque** vira saldo livre; o que era "saldo futuro" deixa de ser futuro e passa a saldo atual ([[03-Estoque-Atendimento-e-Despacho]]).
5. Receber parte da OC mantém o restante como esperado (como o split de hoje).

📝 **N14-28 (15/10/2026):** o Recebimento recebe produtos para **pedido de venda, estoque e uso interno**, e tudo aparece no Estoque. **Proposta do Robert:** os esperados passam a ser **por item da OC**, com ou sem requisição do MES; o lote nasce ligado à OC (`id_item_oc`) já com o custo (K5), o que também resolve o D1 do 008; se a OC tinha destino em pedido de venda, a parcial daquele item segue o caminho normal. **Torre:** lote de estoque, uso interno ou compra por fora não gera evento de fluxo (só o item de pedido de venda). Perguntas em aberto em [[Pontas-Soltas]] PS-034 (uso interno, chave do cruzamento, rateio entre destinos, reserva).

📝 **Uso interno (N14-30, 15/10/2026):** a OC de uso interno entra nos esperados pelo mesmo caminho da OC sem requisição do MES; a doca confere contra a NF; **não cria lote nem saldo**, é registrada como entrada de uso interno, entregue ao setor que pediu e visível no Estoque como entrada registrada; fica fora do saldo futuro (o MES separa pela `finalidade` da OC, pois o `destino` vem como estoque); o custo vai para despesa; sem quarentena, salvo categoria que o Nathan pedir (EPI). Estimativa do Robert: 0,5 pd.

Pontos a decidir pelo Robert: se o "esperado por OC" é entidade própria ou uma requisição sintética criada pelo job; como evitar entrada duplicada (a mesma OC com requisição do MES e a referência); e a quantidade já recebida por OC, necessária também ao cálculo do saldo futuro (BL-050).

### O que falta desenvolver

| # | O quê | Dono | Nó | Selo |
|---|---|---|---|---|
| 1 | Gravar o custo da OC no lote (`lote_custo`, `origem OC`, `id_item_oc`): feito na `develop` (19/10). Falta o custo obrigatório em todo lote (BL-066) | Robert | R4 | ✅ gravação; 🔴 obrigatório |
| 2 | **Cruzar a conferência com a OC** (quantidade comprada, preço, fornecedor, N16-135): a referência da OC já chega ao MES (K4), mas a divergência contra a OC não existe; hoje só NF | Robert | R1, R3 | 🔴 |
| 3 | Caminho de entrada da mercadoria de OC sem requisição do MES (BL-051): feito na `develop` (16 a 20/10). Falta o rateio da chegada entre destinos da OC e o teste em homologação (API-011); ver "Mercadoria de OC sem requisição do MES" abaixo | Robert | R0 | ✅ entrada; 🔴 rateio |
| 4 | Reabertura de divergência de produção e o `P6` novo norte | Robert | R6, P6 | 🔴 |
| 5 | Leitor de código de barras da chave da NF e posto de recebimento (impressora, leitor) | Robert | R1 | 🔴 |
| 6 | Avisar o av-hub quando o PCP **reabre** o recebimento (devolução ao fornecedor, nova compra) | Nathan, Gustavo, Robert | R6 | 🔴 |
| 7 | Aviso à doca quando uma OC esperada é cancelada no av-hub | Robert | R0 | 🟡 |
| 8 | Teste ponta a ponta de "Receber com NF" e da lista de esperados com OC real | Robert | R0 | ❓ |
| 9 | Alerta de OC esperada que passou da previsão sem chegar | Compras, Robert | R0 | 🔴 |

### Pendências

- Nathan: tolerância de peso de 5% vale para toda categoria (decisão provisória do v1), ou por material? O código guarda por material (`toleranciaPeso`, padrão 0,05). **Decidido em 29/10/2026 (N16-134): 5% por padrão, ajustável por material.**
- Nathan: quando existir o cruzamento com a OC, a divergência de quantidade contra a OC bloqueia (como a da NF) ou só avisa? **Decidido em 29/10/2026 (N16-135): bloqueia.**
- Robert: conferência de NF com **várias OCs** ou várias requisições na mesma nota. **Decidido em 29/10/2026 (N16-136): uma nota pode trazer várias OCs, conferidas por item da OC.** Na `develop` do MES já existe (`POST /compras/recebimentos/nf`, `conferencias[]`).
- Robert: na conferência por OC, o fornecedor digitado vale e, sem ele, fica o da OC (`oc.nomeFornecedor`, `api007b`); confirmar que os dois não conflitam.

### Subfluxo

```mermaid
flowchart TD
    FN1["FN1 · Fornecedor entrega<br/>CIF direto ou coleta FOB"] --> R0["R0 · Esperados: OC aprovada<br/>doca registra a chegada com NF<br/>POST compras requisicoes chegada"]
    C5["C5 · Marco oc_aprovada do av-hub"] -.->|"entra nos esperados"| R0
    C0["C0 · OC de requisição só do av-hub<br/>ou de estoque, lida pela referência"] -.->|"esperado por OC, na develop do MES"| R0
    R0 --> R1["R1 · Confere contra a NF<br/>chave de 44 dígitos, contado x NF"]
    R1 --> R2["R2 · Pesagem<br/>peso real obrigatório se há peso teórico<br/>tolerância 5%"]
    R2 --> R3{"R3 · Bate com o esperado?"}
    R3 -->|sim| R4["R4 · Cria o lote PENDENTE em quarentena<br/>ENTRADA no saldo, split se chegou parte<br/>custo da OC gravado na develop"]
    R3 -->|"não: recontagem por outra pessoa"| R6["R6 · Divergência<br/>QUANTIDADE, DESCRICAO, PESO, AVARIA"]
    R6 -->|"recontagem bate"| R4
    R6 -->|"PCP aceita"| R4
    R6 -->|"PCP reabre: nada entra"| P6["P6 · Novo norte<br/>a parcial volta a Compras · CCP"]
    P6 -->|"reabre compra"| P3["P3 · Requisição de compra"]
    R4 -->|"restante da NF volta a Compras · CCP"| R0
    R4 --> Q1["Q1 · Inspeção de entrada por lote"]
```

Próxima raia: [[06-Qualidade-Entrada]].
