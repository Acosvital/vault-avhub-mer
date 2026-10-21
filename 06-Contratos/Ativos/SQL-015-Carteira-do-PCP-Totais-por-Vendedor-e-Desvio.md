---
id: SQL-015
aliases: ["Contrato SQL 015", "015-Carteira-do-PCP"]
tags: [contrato, contrato-sql, dba, pcp, carteira, pedidos, vendas, prazo, desvio, dashboard]
criado: 2026-10-21
atualizado: 2026-10-21
status: proposta
sistemas: [hub-banco, hub-api]
dono: "Gustavo (DBA)"
etapa_0b: []
fontes: ["Dump Avhub (Esqueleto).sql: fn_pedidos_venda (:7373), fn_pedidos_venda_linhas (:7534), fn_pedido_dias_para_prazo (:7282), fn_pedido_prazo (:7311), fn_pedidos_venda_resumo (:7666), pedidos_vendas (:2328)", "api-acos-vital/src/schemas/core_vendas_faturamento/aggregates/pedidos_venda/pedidos_venda.route.js", "av-hub/components/Painel/PainelPcp.tsx, usePainelPcp.ts", "SQL-014 (campos por pedido e regra de encerrado)"]
criado_original: 2026-10-21
---

# Contrato SQL 015 — Carteira do PCP: totais, por vendedor e desvio de previsão

> **Onde atua:** av-hub: banco, API e front (Portal do PCP)

> [!info] Situação em 21/10/2026
> **Status:** `proposta` · **Pasta:** `Ativos` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Gustavo (DBA)
>
> - 📝 **Pedido do Nathan, 21/10/2026:** o PCP (diligenciadores) precisa ver no **Dashboard PCP** o valor total em carteira, o que está dentro do prazo, o que está atrasado, os itens com desvio e a **carteira por vendedor**. O faturamento do mês já existe no dashboard. "Valor em avanço" **entra como marca do diligenciador** (ver "Avanço: marca do diligenciador"). A **previsão atualizada** (CCP) não faz parte deste contrato: a regra ainda não foi decidida, ver "Fora deste contrato".
> - ✅ Os números abaixo foram medidos em 21/10/2026 no preview (perfil admin, pedidos incluídos em 2026, 8.455 pedidos fora da blacklist, 66 vendedores) somando no navegador as parcelas de `GET /pedidos_venda`. Servem de **conferência**: o banco deve chegar nos mesmos valores com a mesma janela.
> - 🔴 Nenhum SQL deste contrato existe. Não montei script: o desenho (funções, nomes e plano de consulta) é do Gustavo. O contrato define **o que significa cada número**.
> - ✅ Decisões Q1 a Q4 do Nathan registradas em 21/10/2026 (seção "Perguntas em aberto"). Falta o Gustavo (G1 a G3).
> - ❓ Desempenho: somar no navegador pede 43 páginas de 200 pedidos (cerca de 100 segundos). Por isso o cálculo tem de ser no banco.
>
> Selos em [[Regras-do-Vault]].

## Por quê

Hoje o Dashboard PCP mostra contagens de pedidos (pedidos, faturados, atrasados, vence hoje) e o faturamento líquido do período, mas **não mostra quanto dinheiro está na carteira**, quanto está no prazo e quanto está atrasado, nem qual vendedor concentra a carteira ou o atraso. O PCP também precisa enxergar os pedidos em que o vendedor colocou uma previsão de faturamento muito curta (desvio), para o PCP e o CCP verificarem se a compra e a produção chegam a tempo.

O front não deve calcular isso: a lista de pedidos é paginada por pedido e somar tudo no navegador é lento e frágil. O banco entrega os totais prontos, como já faz em `fn_pedidos_venda_resumo`.

## Definições (o que cada número significa)

Todas partem da **parcela** (linha de `pedidos_vendas`, sequencial 0 = pedido original, 1, 2… = parciais), porque o valor e a previsão moram nela. As exclusões são as mesmas de `fn_pedidos_venda`: sem orçamento (`etapa = 0`), sem excluídos (`deleted_at`), sem pedido na **blacklist** (`blacklist_pedidos`).

1. **Parcela aberta** = `faturado = false`, `cancelado = false`, `denegado = false`, `devolvido = false`, `encerrado = false`, e `valor_total_pedido > 0`. O pedido original zerado (SQL-014) não entra: tem valor 0.
2. **Carteira** = soma de `valor_total_pedido` das parcelas abertas. **Não depende do mês de inclusão do pedido**: pedido incluído há três meses e ainda não faturado está na carteira. Quantidade = pedidos distintos (`codigo_empresa`, `numero_pedido`) com ao menos uma parcela aberta.
3. **No prazo** = parcelas abertas com `dias_para_prazo >= 0` (`fn_pedido_dias_para_prazo`; inclui "vence hoje" e "vai vencer"; é o balde `em_dia` + `vai_vencer` + `vence_hoje` de `fn_pedido_prazo`). **Atrasados** = parcelas abertas com `dias_para_prazo < 0`. Valor = soma das parcelas; quantidade = pedidos distintos. Um mesmo pedido pode ter uma parcela no prazo e outra atrasada: conta nos dois baldes, então **quantidade no prazo + quantidade atrasada pode passar da quantidade da carteira** (medido: 480 + 383 = 863 contra 861).
4. **Parcela aberta sem previsão** (`data_previsao` vazia): entra na carteira e num balde "sem previsão" separado (valor e quantidade), para a soma fechar. Hoje o balde é 0.
5. **Desvio de previsão** = pedido que tem parcela aberta com `data_previsao` **menor ou igual a 10 dias corridos após a `data_inclusao` do pedido** (a do cabeçalho, sequencial 0). Valor do desvio = soma das parcelas abertas nessa condição; quantidade = pedidos distintos. Previsão **anterior** à inclusão (2 casos medidos) conta como desvio e deve ser marcada, porque é dado errado.
6. **Pedidos no mês** (só na carteira por vendedor) = pedidos com `data_inclusao` do cabeçalho dentro do período recebido (`p_inicio`, `p_fim`). Ao contrário dos outros números, este usa o período.

## O que pedir ao banco

### 1) `fn_carteira_pcp_resumo` — totais da carteira (uma linha)

Parâmetros: `p_is_track_record boolean`, `p_codigo_empresa uuid`, `p_codigo_vendedor text[]` (escopo do diligenciador), `p_desvio_dias integer DEFAULT 10`.

Devolve:

| campo | tipo | significado |
|---|---|---|
| `carteira_valor` / `carteira_pedidos` | numeric / bigint | definição 2 |
| `no_prazo_valor` / `no_prazo_pedidos` | numeric / bigint | definição 3 |
| `atrasados_valor` / `atrasados_pedidos` | numeric / bigint | definição 3 |
| `sem_previsao_valor` / `sem_previsao_pedidos` | numeric / bigint | definição 4 |
| `desvio_valor` / `desvio_pedidos` | numeric / bigint | definição 5 |

### 2) `fn_carteira_pcp_vendedores` — carteira por vendedor (uma linha por vendedor)

Parâmetros: os mesmos, mais `p_inicio date` e `p_fim date` (só para `pedidos_mes`).

Devolve, ordenado por `carteira_valor` decrescente:

| campo | significado |
|---|---|
| `codigo_vendedor`, `vendedor` | do cabeçalho do pedido |
| `pedidos_mes` | definição 6 |
| `no_prazo_pedidos`, `no_prazo_valor` | definição 3 |
| `atrasados_pedidos`, `atrasados_valor` | definição 3 |
| `carteira_pedidos`, `carteira_valor` | definição 2 |
| `desvio_pedidos` | definição 5 (para o PCP ver quem concentra) |

Vendedor sem nada em carteira **não aparece** (a lista é só quem tem carteira), exceto se tiver `pedidos_mes > 0`.

### 3) Campos novos por pedido em `fn_pedidos_venda` e filtro

| campo | tipo | significado |
|---|---|---|
| `desvio_previsao` | boolean | definição 5 |
| `dias_previsao_inclusao` | integer | menor `data_previsao` das parcelas abertas menos `data_inclusao`; `null` se não há parcela aberta com previsão. Negativo = previsão antes da inclusão |

Filtro novo `p_desvio boolean` em `fn_pedidos_venda` e `fn_pedidos_venda_resumo` (`true` = só os pedidos com `desvio_previsao`), para a lista de Pedidos PCP abrir já filtrada a partir do cartão.

### 4) Rotas

- `GET /pedidos_venda/carteira` → `fn_carteira_pcp_resumo`
- `GET /pedidos_venda/carteira/vendedores` → `fn_carteira_pcp_vendedores` (aceita `data_inicio` e `data_fim`)
- `GET /pedidos_venda` aceita `desvio=true`; devolve `desvio_previsao` e `dias_previsao_inclusao` em cada pedido.

Escopo, permissão e `is_track_record` seguem **exatamente** o que `GET /pedidos_venda` já faz (escopo de vendedor pelo token nas telas PCP, contratos 40 e 50; `codigo_vendedor` resolvido no servidor, nunca confiando no front). O Dashboard PCP chama com os vendedores que o diligenciador acompanha; o filtro de vendedor do dashboard restringe mais.

## Conferência (21/10/2026, preview, perfil admin, pedidos incluídos em 2026)

Medido somando no navegador as parcelas abertas de `GET /pedidos_venda` (8.455 pedidos fora da blacklist). Como o cálculo do banco **não** limita o ano de inclusão (definição 2), a carteira dele pode ser maior; para conferir, rode a função com a mesma janela.

| número | valor | pedidos |
|---|---|---|
| Carteira | R$ 77.968.426 | 861 |
| No prazo | R$ 62.724.614 | 480 |
| Atrasados | R$ 15.243.812 | 383 |
| Sem previsão | R$ 0 | 0 |
| Desvio (previsão até 10 dias da inclusão do cabeçalho) | R$ 7.535.181 | 203 |
| Carteira por etapa da parcela | Liberado Compras R$ 61,45 mi · Pedido de Venda R$ 10,75 mi · Separar Estoque R$ 4,76 mi · Faturar R$ 1,01 mi | — |

Exemplos por vendedor (carteira = no prazo + atrasados em valor):

| vendedor | pedidos em carteira | no prazo | atrasados | carteira |
|---|---|---|---|---|
| EUVERALDO OLIVEIRA DE SOUZA | 5 | 5 · R$ 29.712.357 | 0 | R$ 29.712.357 |
| TIAGO VIANA | 9 | 9 · R$ 7.640.565 | 0 | R$ 7.640.565 |
| EBER VIEIRA | 50 | 22 · R$ 3.293.204 | 29 · R$ 2.387.551 | R$ 5.680.754 |
| RAUL MARTINS VENANCIO | 42 | 25 · R$ 3.820.501 | 18 · R$ 202.261 | R$ 4.022.762 |
| LEONARDO MORAES | 40 | 18 · R$ 2.612.571 | 22 · R$ 1.235.649 | R$ 3.848.220 |

(Eber: 22 + 29 = 51 contra 50 pedidos: um pedido tem parcela nos dois baldes, regra da definição 3.)

Observação sobre o desvio: a mediana de `data_previsao − data_inclusao` das parcelas abertas é **16 dias**, então o corte de 10 dias pega cerca de 1 em cada 4 parcelas abertas (208 de 905 entre 0 e 10 dias). O limite é parâmetro (`p_desvio_dias`) para o Nathan e o PCP ajustarem sem mexer em código.

## O que muda na tela (Nathan, depois que o banco entregar)

- **Dashboard PCP** (`PainelPcp.tsx`): cartões **Carteira**, **No prazo**, **Atrasados** e **Desvio** (valor grande, quantidade de pedidos na linha de apoio; clicar abre Pedidos PCP já filtrado). O **Faturamento líquido** do período continua como está. Nova seção **Carteira por vendedor** com a lista do contrato (ordenada pela carteira).
- **Pedidos PCP**: selo **Desvio** na linha do pedido, com os dias entre inclusão e previsão, e filtro **Desvio**.
- **Notas PCP**: sem mudança.
- Padrão visual do projeto (skill `interface-hub`), sem o filtro de mês alterar a carteira (só `pedidos_mes`).

## Avanço: marca do diligenciador (acréscimo de 21/10/2026)

**Faturar em avanço** (faturamento progressivo) é a cobrança dividida em etapas: a empresa fatura conforme o percentual concluído, e não só no fim da entrega. O Omie não diz isso de forma que o hub consiga ler, então **quem diz é o diligenciador**. Decisão do Nathan: ele abre um **dropdown** no pedido e escolhe se aquele pedido é "Avanço". **Por padrão não é marcado.**

### Regras

1. A marca é **por pedido** (`codigo_empresa` + `numero_pedido`), não por parcela. Vale para todas as parcelas do pedido.
2. Valores do dropdown: **"—" (sem marca, padrão)** e **"Avanço"**. A coluna aceita novos valores no futuro (ex.: outros tipos de acompanhamento) sem mudar a tela de desenho.
3. Quem marca e desmarca: usuário com a tela **Pedidos PCP** (`pcp-pedidos`) com `pode_editar`, **só em pedido de vendedor do seu escopo** (o mesmo escopo de `GET /pedidos_venda`; conferido no backend, não só escondido na tela).
4. Guardar **quem marcou e quando**. Desmarcar grava quem e quando; o histórico fica (não apagar), como nas observações do PCP (`pedido_observacao_pcp`).
5. O pedido **encerrado** (SQL-014) pode continuar marcado, mas sai dos totais de carteira e de avanço (não tem parcela aberta).

### O que pedir ao banco

- **Tabela nova** `core_vendas_faturamento.pedido_marcacao_pcp` (nome a critério do Gustavo): `id`, `codigo_empresa`, `numero_pedido`, `marcacao` (texto, `'avanco'`), `marcada_por` (uuid do usuário), `marcada_em`, `removida_por`, `removida_em`. Marca **vigente** = linha sem `removida_em`. No máximo uma vigente por pedido e valor.
- **Campos por pedido** em `fn_pedidos_venda` (e na lista): `avanco` (boolean, marca vigente), `avanco_marcado_por`, `avanco_marcado_em`.
- **Filtro** `p_avanco boolean` em `fn_pedidos_venda` e `fn_pedidos_venda_resumo`.
- **Totais** em `fn_carteira_pcp_resumo`: `avanco_valor` (soma das parcelas **abertas** dos pedidos marcados) e `avanco_pedidos`; mais `avanco_faturado_valor` (soma das parcelas já faturadas dos pedidos marcados, para mostrar quanto da obra já foi cobrado). Na `fn_carteira_pcp_vendedores`: `avanco_pedidos` e `avanco_valor`.
- **Rotas:** `PUT /pedidos_venda/{codigo_empresa}/{numero_pedido}/marcacao` (corpo `{ "marcacao": "avanco" | null }`; `null` desmarca) e `GET` dos totais com os campos acima. Validar escopo e permissão no servidor.

### O que muda na tela

- **Página do pedido (Pedidos PCP):** dropdown **"Classificação"** ao lado das pílulas do resumo, com "—" e "Avanço". Quem marcou e quando aparece no apoio do dropdown. Só habilita para quem pode editar; os demais veem só a pílula "Avanço".
- **Lista de Pedidos PCP:** selo **Avanço** na linha e filtro **Avanço**.
- **Dashboard PCP:** cartão **Em avanço**, que mostra a **quantidade de pedidos e o valor** (valor = saldo em carteira dos pedidos marcados; na linha de apoio, quanto já foi faturado) e a coluna correspondente na carteira por vendedor.

### Conferência

1. Marcar o pedido 28377 (24% faturado, R$ 343 mil abertos em 21/10) deve levar `avanco_valor` a incluir esses R$ 343 mil abertos e `avanco_faturado_valor` a incluir os R$ 108 mil já faturados.
2. Desmarcar tira o pedido dos totais e grava quem desmarcou.
3. Usuário fora do escopo recebe o mesmo erro que `GET /pedidos_venda` dá hoje.

### Perguntas em aberto

Para o **Nathan:**

1. **Q5 (respondida em 21/10/2026).** O cartão "Em avanço" mostra a **quantidade e o valor**. Valor = saldo em carteira dos pedidos marcados (suposição mantida, o Nathan não pediu outra); o já faturado fica na linha de apoio.
2. **Q6.** A marca é só "Avanço" por enquanto ou já quer outras opções no dropdown?
3. **Q7.** Qualquer diligenciador do vendedor pode marcar/desmarcar, ou só um responsável?

Para o **Gustavo:** a marca é uma tabela de histórico (proposto) ou uma coluna em `pedidos_vendas`? A coluna é mais simples, mas a tabela guarda quem marcou e desmarcou sem perder o passado e não é apagada pelo sync do Omie.

## Fora deste contrato

- **Previsão atualizada pelo CCP** ("a compra chega em N dias, recalcular a previsão de faturamento"): ainda sem regra fechada (hoje + N + 1, previsão atual + N + 1, ou maior chegada das compras ligadas + 1). Medi 90 pedidos em carteira: **44% têm compra ligada**, todas de origem Omie (ligadas lendo o número do pedido dentro de `numero_pedido_fornecedor`), **nenhuma de ordem de compra do hub**; o CCP atualiza a chegada na OC do hub (LOG-32), que hoje não está ligada a pedido de venda, e o perfil CCP ainda não foi criado (N14-24). Vira contrato próprio depois do estudo.

## Como conferir que ficou certo

1. `fn_carteira_pcp_resumo` sem filtro de vendedor, com a janela de inclusão de 2026, bate com a tabela de conferência (diferença só por arredondamento de centavos).
2. `carteira_valor = no_prazo_valor + atrasados_valor + sem_previsao_valor` em qualquer filtro.
3. A soma de `carteira_valor` de `fn_carteira_pcp_vendedores` é igual à `carteira_valor` do resumo, com o mesmo escopo.
4. Pedido na blacklist, orçamento, parcela cancelada/devolvida/denegada/encerrada e pedido encerrado por saldo (SQL-014) **não** entram.
5. Com `p_codigo_vendedor` de um diligenciador, só os vendedores dele aparecem; com um vendedor fora do escopo, a API responde como `GET /pedidos_venda` responde hoje.
6. Pedido 27762 (original zerado, tudo faturado): fora da carteira e fora do desvio.
7. `GET /pedidos_venda?desvio=true` devolve exatamente os pedidos contados em `desvio_pedidos`.

## Perguntas em aberto

Decididas pelo **Nathan** em 21/10/2026:

1. **Q1.** Pedido de cliente YPFB (`eh_ypfb`) **entra** na carteira, como qualquer outro.
2. **Q2.** "No prazo" **inclui** "vence hoje".
3. **Q3.** No prazo e atrasados, na carteira por vendedor, são da **carteira inteira**; só `pedidos_mes` usa o período.
4. **Q4.** O desvio usa **10 dias corridos** a partir da inclusão do cabeçalho.

Para o **Gustavo**:

1. **G1.** Partir de `pedidos_vendas` direto (parcelas abertas, sem período) ou de `fn_pedidos_venda_linhas` com uma janela larga? A função de linhas exige período e traz a família inteira, o que pesa para a carteira de todos os anos.
2. **G2.** Índice parcial em `pedidos_vendas` para parcelas abertas (`faturado = false AND cancelado = false …`) ajuda? Medir o tempo da resposta do resumo (meta: abaixo de 2 segundos para o escopo de um diligenciador).
3. **G3.** O Dashboard PCP chama o resumo e a lista de vendedores ao mesmo tempo: faz sentido uma rota só `GET /pedidos_venda/carteira?por=vendedor`, ou duas rotas como proposto?
