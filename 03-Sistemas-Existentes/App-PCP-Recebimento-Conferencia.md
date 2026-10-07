---
tags: [erp-acos-vital, app-pcp, recebimento]
criado: 2026-10-07
atualizado: 2026-10-07
---

# app-pcp — Recebimento e conferência (como está no código em 07/10/2026)

> Status: decidido | no código | em produção (verificado em 07/10/2026 pelo dump, onde indicado). Decisões da rodada em [[Registro-de-Decisoes-2026-10-07]]. MES = Robert.

> **Rótulo de confiança.** Tudo abaixo vem de **leitura de código na branch `develop`** (api-pcp `ca3346b`, PR #50, 07/10 08:31; app-pcp `a802a3e`, PR #34, 07/10 08:32). **Não** foi conferido em produção nem em homologação. `main` dos dois repositórios parou em 28/08 (api `be076b2`, app `be847ac`): **nada disto está em `main`**. **Decidido (✅ Nathan, 07/10):** merge `develop` → `main` **antes do piloto** (fecha CC-04); **data e responsável: 🔴 Robert**. A `develop` roda no ambiente de homologação `https://mes-test.acosvital.com.br/` (`mes-test`, ✅ no ar; marco M2 cumprido); o `main` não foi dado como em produção. Ver [[App-PCP-Visao-Geral]].

O setor **Recebimento** do MES confere o material que chegou contra a **nota fiscal**, registra peso e divergência, exige uma **recontagem por outra pessoa** quando algo não bate e leva ao **PCP** (tela `/decisoes-pcp`) o que continuou divergindo. Quando a conferência fecha sem divergência, o lote nasce em quarentena e a parcial segue para a Qualidade. É o D6 (backend, `861c050`) e o D7 (front, `f2c01f1`) do [[Cronograma-2-Meses]], feitos em 07/10 — a janela prevista era S3 (19/10). Esta nota descreve o que o código faz; o desenho de negócio de origem está em [[Fluxo-Recebimento-Completo]] (que ficou desatualizado em relação ao código — ver seção "Vault diz × código mostra").

## 1. O fluxo

1. A requisição de compra nasce em "Requisições" (`ComprasService.requisitar`) e a parcial vai ao setor Compras. O pedido de compra é registrado **à mão** em `PATCH /compras/requisicoes/:id/compra` (número do pedido, fornecedor, previsão) — isso move a parcial para o **Recebimento**. (Ver [[34-Requisicoes-MES-Empurra-para-o-Hub]] e [[35-Compras-Marcos-Requisicao-para-MES]].)
2. No Recebimento, a ação **"Conferir recebimento"** (`ConferirRecebimentoModal`, que substituiu o antigo `RegistrarRecebimentoModal`) abre o `Recebimento` (código `RB-AAAAMMDD-NNNN`).
3. **A conferência é contra a NF, não contra o pendente do pedido.** Receber **mais** do que o pedido é permitido; a sobra fica livre no estoque.
4. **Peso e tolerância.** Peso teórico = `Material.pesoTeoricoUnitario` × quantidade contada. Se o material tem peso teórico, o **peso real é obrigatório**. Desvio acima de `toleranciaPeso` (padrão 5%) vira divergência do tipo `PESO`.
5. **Tudo bate** → `ComprasService.registrarRecebimento` cria o(s) lote(s) em `PENDENTE` (**quarentena**) com `ENTRADA` no saldo, na localização informada na conferência; a parcial segue para "Qualidade · Entrada" levando `idLoteCompra`; o recebimento fica `CONCLUIDO`.
6. **Algo diverge** → **nada entra no estoque**; o recebimento fica `AGUARDANDO_RECONTAGEM`. **Outra pessoa** reconta (ação "Recontar", `RecontarRecebimentoModal`); **quem conferiu não pode recontar**.
7. Recontagem bate → `CONCLUIDO` (entra e segue para a Qualidade, como no passo 5). Continua divergindo → `AGUARDANDO_DECISAO`.
8. **O PCP decide** em `/decisoes-pcp` (grupo Operações do menu): **`ACEITO`** (entra o valor recontado) ou **`REABERTO`** (nada entra e a parcial volta ao setor Compras). **O motivo é obrigatório nos dois casos** (`motivoDecisao`).

### Estados do recebimento
`AGUARDANDO_RECONTAGEM` → `AGUARDANDO_DECISAO` → `ACEITO` / `REABERTO`; ou `CONCLUIDO` (conferência ou recontagem sem divergência).

## 2. Modelo Prisma (`compras.prisma`)

| Modelo | Campos relevantes |
|---|---|
| `Recebimento` | código `RB-AAAAMMDD-NNNN`; `idRequisicao`; `idItemParcial`; `status`; `numeroNf`; `chaveAcessoNf` (44 dígitos); fornecedor; `laudoUrl`; conferido / recontado / decidido **por** e **em**; `motivoDecisao` |
| `RecebimentoItem` | `quantidadePendente`, `quantidadeNf`, `quantidadeContada`, `quantidadeRecontada`; `pesoTeorico`, `pesoReal`, `pesoRecontado`; `toleranciaPeso`; `idLocalizacao`; `idLote` |
| `RecebimentoDivergencia` | `tipo` (`QUANTIDADE` \| `DESCRICAO` \| `PESO` \| `AVARIA`); `evidenciaUrl`; `etapa` (`conferencia` \| `recontagem`) |

Migration: `20261006140000_recebimento_conferencia`. Os modelos ligam o recebimento à **requisição**, e **não** ao pedido de venda/ordem de compra por um `tipo_referencia` (como [[Estoque-Modelo-Dados]] propunha); a pesagem é campo do item, não tabela própria.

## 3. Rotas e permissões (`compras/recebimentos`)

| Rota | Permissão |
|---|---|
| `GET /` e `GET /:id` | `movimentacoes:visualizar` |
| `GET /decisoes` | `decisoes-pcp:visualizar` |
| `POST /` (conferir) e `POST /:id/recontar` | `movimentacoes:editar` |
| `POST /:id/decidir` | `decisoes-pcp:editar` |

`POST /compras/requisicoes/:id/recebimentos` (registro direto, sem conferência) foi **removido** no PR #50. Além do `@RequirePermission`, o `RecebimentoService` aplica `ensurePodeAtuar` (`PerfilSetor`) — default-deny por setor, checado no service.

## 4. Ligações com os outros subsistemas

- **Compras.** Descrito no passo 1. `registrarRecebimento` atualiza `quantidadeRecebida` da requisição.
- **Eventos do av-hub (contrato 35).** O modal de andamento mostra os marcos recebidos. O MES **só reage** a `requisicao_cancelada` e `requisicao_reaberta`. Os eventos `oc_aprovada`, `oc_no_omie` e `despachada` **só são gravados**: **não** preenchem o pedido de compra, **não** preenchem a previsão e **não** avançam a parcial para o Recebimento. Quem faz isso hoje é o registro manual do passo 1.
- **Qualidade.** `src/qualidade`, rota `/qualidade/lotes`, permissão `inspecao-entrada`. Aprovar exige `laudoUrl` e leva a parcial de volta ao Estoque; reprovar abre RNC total ou parcial; a parte reprovada volta a Compras e a aprovada fica em `QUARENTENA` (EC-07); reprovação parcial reúne as partes depois (`devolverAoEstoqueParciaisProntas`). Ver [[Fluxo-Qualidade-Completo]].
- **Estoque.** O lote nasce na localização da conferência (`SaldoEstoque` + `MovimentoEstoque` do tipo `ENTRADA`). Ver [[Estoque-Modelo-Dados]] e [[Encaixe-Estoque-Revenda-no-PCP]].
- **Filiais.** O PR #50 também fechou a **etapa 1** de [[Proposta-Transferencia-Estoque-Filiais]] (`Deposito.codigoEmpresa`/`nomeUnidade`, `GET /estoque/depositos/unidades`, seletor de filial no cadastro de depósito). As etapas 2 a 4 (solicitar, aprovar, expedir, receber) **não existem**.

## 5. O que NÃO existe (conferido no código em 07/10)

- **Leitor de código de barras / posto de recebimento.** A chave da NF é só **digitada** (44 dígitos). A etiqueta com Code128 (`GET /estoque/lotes/:id/etiqueta`) existe, mas sem leitor 2D.
- **Consumo dos eventos `oc_*`** para preencher pedido, previsão ou avançar a parcial (ver seção 4).
- **Contrato 004** (referência da OC do hub para o MES): não existe nos dois lados. O recebimento não consulta nenhuma OC do hub; confere contra a NF digitada. Ver [[Integracao-AvHub-MES-Especificacao-F1]].
- **Importação de NF-e** (XML) ou consulta da chave: **não verificado** (nada na ficha).
- **Testes automatizados:** sem harness (`*.spec`/jest/script `test` não existem no api-pcp).

## 6. Limpeza de rotas do PR #50 (pode quebrar consumidores antigos)

O mesmo PR apagou:
- `POST /pedidos/completo` (resta só `POST /pedidos/completo/lote`);
- `POST/DELETE /perfis/:id/permissoes[...]` (resta o `bulk`).

Qualquer cliente que ainda use as rotas antigas quebra. O app-pcp já usa as novas; consumidores externos: **não verificado**.

## 7. Setores do MES hoje

**Tipos de setor** (`Setor.tipo`): `PRODUTIVO`, `ESTOQUE`, `COMPRAS`, `EXPEDICAO`, `REQUISICAO`, `LOGISTICA_ENTRADA`, `QUALIDADE`. **Fábricas:** Flange (`FABRICACAO`) e Revenda (`REVENDA`).

| Código | Nome exibido | Tipo | Onde é criado |
|---|---|---|---|
| `estoque` | Estoque | `ESTOQUE` | migration |
| `requisicoes-compra` | Requisições | `REQUISICAO` | migration |
| `compras` | Compras | `COMPRAS` | migration |
| `logistica-entrada` | **Recebimento** | `LOGISTICA_ENTRADA` | migration |
| `qualidade-entrada` | Qualidade · Entrada | `QUALIDADE` | migration |
| `embalagem` | — | `EXPEDICAO` | pela UI (inferido) |
| `inspecao_qualidade` | — | `QUALIDADE` | pela UI (inferido) |
| setores de Flange | — | `PRODUTIVO` | pela UI (inferido) |

O **circuito de compra fica fora do roteiro** da fábrica (`circuito-compra.ts`); a migration `...140100` tirou `requisicoes-compra` e `compras` de `fabrica_setores`. Estado real dos setores `PRODUTIVO` e `EXPEDICAO` depende do banco: **não verificado**.

## 8. Telas e slugs do front

Slugs (cadastro de telas/permissões): `movimentacoes`, `atendimento`, `requisicoes`, `pedidos-compra`, `logistica-entrada`, `expedicao`, `inspecao-saida`, `inspecao-entrada`, `decisoes-pcp`, `painel-estoque`, `saldo`, `reservas`, `movimentacao`, `materiais`, `depositos`, `mapa-deposito`, `carteira`, `ordens-producao`, `pedidos-excluidos`, `relatorios`, `dashboard`, `fabricas`, `setores`, `maquinas`, `operadores`, `perfis`, `telas`, `usuarios`.

**Não há rota Next nova para o Recebimento:** `/logistica/logistica-entrada` é o `ModuloSetores` (fila do setor tipo `LOGISTICA_ENTRADA`). O PR #34 acrescentou nessa tela a ação "Conferir recebimento", "Recontar", o chip de status da conferência no card da parcial, e criou a tela `/decisoes-pcp`. As telas do menu são criadas por SQL fora do repositório (`modulos-telas.sql`) — **não verificado** se estão aplicadas no banco real.

## Vault diz × código mostra

[[Fluxo-Recebimento-Completo]] afirma "nada existe", "acabado confere contra PV, não acabado contra OC", "recebimento nunca fala com Compras" e "peso fora da tolerância sem caminho". O código confere contra a NF, trata peso como divergência, exige recontagem por outra pessoa, e o PCP aceita ou reabre (a parcial volta a Compras). A nota de fluxo é um desenho de negócio; as diferenças acima valem como **estado do código**, não como decisão revista.

## Ver também
- [[App-PCP-Visao-Geral]]
- [[App-PCP-Backend-Producao]]
- [[Fluxo-Recebimento-Completo]]
- [[Fluxo-Qualidade-Completo]]
- [[Encaixe-Estoque-Revenda-no-PCP]]
- [[Estoque-Modelo-Dados]]
- [[Proposta-Transferencia-Estoque-Filiais]]
- [[Integracao-AvHub-MES-Especificacao-F1]]
- [[34-Requisicoes-MES-Empurra-para-o-Hub]]
- [[35-Compras-Marcos-Requisicao-para-MES]]
- [[Chaves-de-Integracao-AvHub-MES-Pipeline]]
- [[Indice-Contratos]]
- [[Onde-Estamos]]
