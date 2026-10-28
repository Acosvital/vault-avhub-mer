---
id: SQL-016
aliases: ["Contrato SQL 016", "016-Schema-core_comercial-Proposta-e-Pedido-de-Venda", "SQL-016-Schema-core_comercial-Proposta-e-Pedido-de-Venda"]
tags: [contrato, contrato-sql, dba, migracao, proposta, pedido-de-venda, custo-real, sequencial, previsao-de-faturamento, core_vendas_faturamento]
criado: 2026-10-21
atualizado: 2026-10-28
status: proposta
sistemas: [hub-banco, pipeline]
dono: "Gustavo (DBA)"
etapa_0b: [V0.1, V0.3, V0.5, V0C, V0.6, V0.7, V1, C6, C7, C8, K2]
fontes: ["Dump do Avhub para referência (schema) e Dump completo, 26/10/2026", "Registro-de-Decisoes (N16-01 a N16-100, N16-116)", "SQL-016-anexos/0001-migracao-proposta-em-core_vendas_faturamento.sql, 0002-teste-migracao.sql", "Proposta-Orcamento-Comissao/05-Contratos/SQL-015-anexos/_desenho-antigo-nao-usar (histórico, fora do vault)", "av-hub components/Propostas/PropostaForm", "omie-elt-pipeline src/omie/resources/pedidosVendas.ts, produtoVendas.ts"]
criado_original: 2026-10-16
---

# Contrato SQL 016 — proposta e pedido em `core_vendas_faturamento` (migração do `core_comercial` real): proposta nova, pedido do Hub, custo real, datas, sequenciais e cancelamento

> **Onde atua:** av-hub: banco

> [!info] Situação em 28/10/2026
> **Status:** `proposta` · **Dono:** Gustavo (revisa e aplica) · Regra: [[LOG-56-Fluxo-da-Proposta-ao-Pedido]] · Rotas: [[API-019-Proposta-e-Pedido-de-Venda-na-API-do-Hub]] (Robert, N16-117)
>
> - 📝 **28/10/2026, N16-116: não existirá `core_comercial`.** A proposta, o pedido do Hub e o resto do módulo ficam em **`core_vendas_faturamento`**, junto de `pedidos_vendas`, da OC e da liberação. O anexo `0001` ganhou o **bloco A0**: move as 23 tabelas, as 2 visões e as 9 funções do `core_comercial` para `core_vendas_faturamento` (nenhum nome colide com as 55 tabelas que já estão lá), recria com o nome novo as 6 funções que citam o schema no corpo e apaga o `core_comercial` vazio (`DROP SCHEMA ... RESTRICT`: para se sobrar algo). Todo o resto dos anexos passou a nomear `core_vendas_faturamento`; os arquivos foram renomeados (`0001-migracao-proposta-em-core_vendas_faturamento.sql`).
> - 🧪 **Reteste de 28/10 em Postgres 18** sobre o mesmo dump de referência: `0001` aplica; `0002` dá a **mesma saída** de 26/10 (72 verificações: 32 erros esperados e 40 conferências). Depois do `0001`, nenhuma função ou visão do banco cita `core_comercial` e o schema não existe mais.
> - ❓ **Para o Gustavo conferir em produção:** se há job do `pg_cron` chamando `core_comercial.fn_chaves_idempotencia_limpar` (o dump de referência não tem `pg_cron`) e se os papéis da API já têm `USAGE` em `core_vendas_faturamento`. Os nomes `pedidos`, `pedidos_itens` e `pedidos_envios` ficam ao lado de `pedidos_vendas` no mesmo schema: se ele preferir outro nome (por exemplo `pedidos_hub`), a troca é só de nome.
> - 📝 **Este contrato mudou de natureza em 26/10** (antes da N16-116). O desenho de 16 a 21/10 criava um schema `core_comercial` novo, a partir do dump "Esqueleto". O **banco real já tem `core_comercial`** (Contrato 52) com 25 tabelas, no plural e no modelo antigo de proposta. Agora o contrato é uma **migração por cima do que existe**. O desenho antigo ficou em `Proposta-Orcamento-Comissao/05-Contratos/SQL-015-anexos/_desenho-antigo-nao-usar` (fora do vault) só como histórico.
> - 🧪 **Testado em Postgres 18** sobre o dump de referência (schema): `0001` aplica sem erro; `0002` roda **72 verificações** (erros esperados e conferências), todas ok, incluindo o pedido do Omie trazido ao Hub com a parte de vendas travada (N16-106), o custo real e a divergência num pedido digitado direto no Omie, a OC gerando custo (N16-102), as datas de todo pedido e o calendário (N16-104). Também aplicado sobre uma cópia **com os dados reais** de `pedidos_vendas` (13.924 linhas) e `produto_vendas` (39.060): o preenchimento do histórico funcionou (seção 4). **Nunca rodou no banco de produção.**

## 1. Por quê

A proposta, o pedido criado pelo Hub, o custo real por evento, o aviso ao vendedor quando a compra passa do valor, as datas do pedido, os sequenciais e o cancelamento não têm lugar no banco. Há um `core_comercial` com proposta no modelo antigo (aberta, parcial, fechada, perdida) e **vazio**: `propostas`, `propostas_itens`, `clientes`, `ofertas`, `solicitacoes_custo` e as outras têm **0 linhas** no dump completo. Só têm dados `categorias_suprimento` (17), `parametros_custo` (1) e `unidades_emissoras` (3). Por isso a migração **altera no lugar**, sem converter dado. Desde a N16-116 (27/10), o lugar é `core_vendas_faturamento`: o bloco A0 move as tabelas antes de alterá-las.

## 2. O que a migração faz (anexo `0001-migracao-proposta-em-core_vendas_faturamento.sql`)

### 2.1 `propostas` e `propostas_itens`: do modelo antigo ao novo

| Mudança | Para quê |
|---|---|
| `status` passa a `ABERTA`, `APROVADA`, `TRANSFORMADA`, `CANCELADA`; a coluna sobe de `varchar(10)` para `varchar(12)` | N16-02, N16-03. O teste achou que `TRANSFORMADA` não cabia |
| saem `valor_fechado`, `valor_aberto`, `fechada_em`, `numero_pedido_omie`; `perdida_em`, `motivo_perda` e `motivo_perda_texto` viram `cancelada_em`, `motivo_cancelamento`, `motivo_cancelamento_texto` | não existe fechamento parcial; o pedido vive em `pedidos` |
| entram `aprovada_em`, `aprovada_por`, `aprovada_revisao`, `aprovacao_referencia`, `cancelada_por`, `transformada_em`, `transformada_por`, `codigo_parcela_omie` | aprovação marcada pelo vendedor (a da Gerência é física, N16-12); condição de pagamento por conta (SQL-019) |
| `numero_numerico` (gerado: ano × 1.000.000 + sequencial) | 🟡 N16-04 pede número só de dígitos; o `numero_completo` com prefixo continua para a tela e o PDF. A decidir se o formato vale |
| itens: saem `fechado`, `fechado_em`, `id_fechado_por`; entram `natureza_custo`, `cfop`, `codigo_cenario_omie` | N16-83 (CFOP e cenário de impostos na proposta) |
| `propostas_eventos.tipo` ganha aprovada, cancelada, transformada, custo solicitado e respondido, pedido enviado, recusado e número do Omie (`varchar(30)`) | o valor `TRANSFORMADA_EM_PEDIDO` não cabia em 20 caracteres |
| `fn_item_completo`, `vw_propostas_completude` | proposta **incompleta** = item sem custo ou sem fornecedor (N16-31). 🟡 OQ-11 |
| `trg_propostas_travar`, `trg_propostas_itens_travar` | aprovada não se ajusta; aprovar exige proposta completa e a revisão aprovada igual à atual; transições só `ABERTA`→`APROVADA`/`CANCELADA` e `APROVADA`→`TRANSFORMADA`/`CANCELADA` |

### 2.2 A unidade é a emissora, com três contas Omie (N16-79, N16-80)

Não se cria `empresa_emissora`: o banco **já tem** `unidades_emissoras`, extensão 1:1 de `core.unidades` (CRC, logo, textos padrão, nome curto). A migração só corrige o **dado**: a HRM apontava para a conta de Mogi (`id_unidade_conta_omie`); passa a apontar para ela mesma, e as três (AV, AU, HRM) têm conta própria.

### 2.3 O pedido do Hub

| Tabela | O que guarda |
|---|---|
| `pedidos` | o pedido de venda no Hub, com **duas origens** (N16-106): `PROPOSTA` (nasce no "Transformar em pedido": número por unidade em `sequencias_documento`, `codigo_pedido_integracao` = número, **as três respostas obrigatórias**, a fila do Omie) e `OMIE` (digitado direto no Omie e trazido pelo job, já sincronizado; o vendedor responde Qualidade e faturamento em partes no Hub, sem travar). Guarda o vendedor (`id_usuario_vendedor`), a previsão vigente e o cancelamento |
| `pedidos_itens` | os itens, com a **quantidade original** (o Omie a zera ao quebrar) e a **parte de compras** (custo, origem do custo, fornecedor, oferta): copiada da proposta, ou preenchida pelo vendedor no pedido do Omie |
| `fn_pedidos_omie_sincronizar`, `trg_pedidos_omie_travar`, `trg_pedidos_itens_omie_travar` | o job traz o pedido do Omie (um item por produto, previsão INICIAL do Omie) e o atualiza a cada carga; **o que veio do Omie só se altera no Omie** (N16-106): a parte de vendas e o cancelamento só mudam pela sincronização |
| `pedidos_envios` | uma linha por tentativa de envio ao Omie |
| `pedidos_previsoes` | **as datas** (inicial, entrega de Compras, entrega do CCP), só `INSERT`, com o atraso do fornecedor. Valem para **todo pedido de venda**, do Hub ou do Omie, pela chave unidade + número do pedido + produto (N16-104) |
| `pedidos_sequenciais`, `pedidos_sequenciais_itens`, `vw_pedidos_saldo` | a quebra criada no Hub e o saldo do original |
| `fn_propostas_transformar_em_pedido` | exige Qualidade, faturamento em partes e data de hoje em diante; recusa produto pendente; copia os itens; grava a previsão inicial; vira a proposta `TRANSFORMADA` |
| `fn_pedidos_registrar_previsao` | grava a entrega (Compras ou CCP) de qualquer pedido, calcula **entrega + 1 dia útil**, o atraso, atualiza a vigente do pedido do Hub e **só avisa** o vendedor quando é o CCP |
| `vw_pedidos_previsoes`, `vw_pedidos_previsao_vigente` | o histórico de datas que o vendedor vê e, por pedido, a inicial (do vendedor ou do Omie), a vigente (a maior entre a inicial e a última de cada item), o maior atraso e quantas datas houve. **É o que a Carteira do PCP passa a ler** (N16-104; muda o [[SQL-015-Carteira-do-PCP-Totais-por-Vendedor-e-Desvio|SQL-015]] e o [[API-017-Carteira-do-PCP-por-Periodo-e-Previsao-de-Faturamento-por-Mes|API-017]] do vault) |
| `calendario_excecoes`, `fn_calendario_feriados` | as exceções que o **marketing** cadastra numa tela de calendário (feriado que a biblioteca não traz, ou dia útil num feriado dela), por unidade ou para todas; a função junta com os feriados da biblioteca |
| `fn_somar_dias_uteis`, `vw_pedidos_itens_previsao` | soma dias úteis com a lista de feriados resolvida e mostra a última data de cada item |
| `fn_pedidos_cancelar` | só o pedido do Hub (o do Omie se cancela no Omie); motivo obrigatório; recusa faturado e repetido; **estorna** o custo real; fecha as divergências abertas; avisa o vendedor |

### 2.4 Custo real e compra acima do valor

**Vale para os dois tipos de pedido (N16-102):** o que nasce de proposta e o digitado direto no Omie. O **item do pedido** é **empresa + número do pedido + produto do Omie**, a mesma chave do vínculo da OC (`ordens_compra_itens_vinculos`) e do custo do lote do MES (LOG-47: item = produto).

| Objeto | O que faz |
|---|---|
| `vw_pedido_produtos` | a lista dos itens. Pedido do Hub: quantidade original e natureza da proposta, custo cotado. Pedido do Omie: soma da família (original e sequenciais, sem cascas e sem cancelados), natureza `MATERIAL` (serviço vem do tipo do item da OC; fabricação, da requisição de matéria-prima). Nos dados reais: 18.054 itens em 6.831 pedidos |
| `custos_eventos` | um evento por linha de custo, pela chave do item; `id_pedido` e `id_item_pedido` só quando o pedido nasceu no Hub |
| `fn_custo_evento_registrar`, `_estornar`, `_sincronizar_oc`, `_registrar_lotes`, `fn_custo_eventos_estornar_pedido` | gravar, estornar, gerar da OC e do lote do MES, e estornar todo o custo de um pedido cancelado (no Hub ou no Omie) |
| `vw_custo_evento_liquido`, `vw_pedido_item_custo`, `vw_pedido_custo` | custo real por item e por pedido; `SEM_CUSTO`, `PARCIAL` ou `COMPLETO` |
| `divergencias_compra` e `fn_divergencia_registrar`, `_decidir`, `_assumir`, `_resolver` | compra acima do valor (N16-60 a N16-67). Compara com o **custo que o vendedor pôs no item do pedido** (custo × quantidade), não com o preço de venda (corrigido em 26/10). Vale igual para o pedido do Omie (N16-106): sem a parte de compras preenchida, `SEM_CUSTO_DO_VENDEDOR`; o aviso vai ao vendedor do pedido |

A comissão **nova** também vale para o pedido digitado direto no Omie (N16-103, SQL-018 anexo `0006`): ela lê este custo real pelo produto.

### 2.5 `core_vendas_faturamento`: o que a pipeline e o Hub precisam

| Objeto | Para quê |
|---|---|
| `ordens_compra_itens.tipo_item`; `requisicoes_compra` (`codigo_item_omie`, `id_item_parcial`, `codigo_parcial`, `quantidade_item_coberta`) | mão de obra e cobertura do item (antigo anexo `0002`) |
| `condicoes_pagamento_vendas` | [[SQL-019-Condicoes-de-Pagamento-de-Venda-do-Omie]] |
| `cenarios_impostos` | cenários de impostos do Omie por conta (N16-83) |
| `pedidos_vendas_sequenciais_itens` | **a terceira tabela** (seção 4) |
| `vw_pedido_itens_familia` | a família do pedido: papel, sem cascas (quantidade 0) e sem pedido cancelado |

## 3. Regras que o banco impõe

1. Proposta aprovada trava; cancelada e transformada não reabrem.
2. Pedido de origem proposta exige as três respostas; o número do pedido é o `codigo_pedido_integracao`.
3. `custos_eventos` e `pedidos_previsoes` só recebem `INSERT`; o estorno é uma linha de sentido -1.
4. Uma divergência aberta por produto e OC; compra mais barata não gera aviso.
5. A previsão **inicial nunca se perde**; a vigente é derivada (entrega + 1 dia útil) e **não volta ao Omie**.
6. O número de um sequencial cancelado **nunca se reusa**; cancelar devolve o valor ao original.
7. Mudar data não muda valor da proposta nem do pedido.

## 4. Sequenciais: o que os dados do banco mostraram (N16-100)

Medido no dump completo de 26/10/2026:

| Achado | Número |
|---|---|
| Pedidos em `pedidos_vendas` | 13.924 (10.916 originais e 3.008 sequenciais, em **1.003 famílias**) |
| Linhas de item em `produto_vendas` | 39.060 |
| Código de linha de item repetido entre original e sequencial | **nenhum**: o sequencial recebe códigos de linha **novos**; o que se repete é o **produto** (797 famílias) |
| Original zerado | 805; quase todas as linhas ficam com **quantidade 0** (as "cascas"); a quantidade original se perde |
| Sequenciais **sem nenhum item** | **754** (todos em Mogi, 745 de 2026, 750 faturados, R$ 32,9 milhões); 2.597 originais com valor e sem item |
| Pedidos com soma dos itens diferente do valor | 60 |

`produto_vendas` é único por `(empresa, codigo_item_omie)` e não tem `sequencial`; o `codigo_pedido_omie` é instável. A **terceira tabela** `pedidos_vendas_sequenciais_itens` liga cada linha de sequencial à linha do item do original: `HUB` (quebra feita no Hub, exata), `PRODUTO` (o produto aparece em **uma** linha do original), `AMBIGUO` (aparece em mais de uma) ou `SEM_VINCULO`. O preenchimento do histórico, rodado sobre os dados reais, ligou **6.520 linhas**: **5.439 `PRODUTO`** (83%), **1.031 `AMBIGUO`** (16%) e **50 `SEM_VINCULO`**. As listas dos buracos estão em `04-Dados/` (CSV). O Hub só acerta a ligação quando a quebra nasce nele (N16-92, N16-93).

## 5. Fora deste contrato

Telas e rotas ([[LOG-56-Fluxo-da-Proposta-ao-Pedido]], [[API-019-Proposta-e-Pedido-de-Venda-na-API-do-Hub]]); a comissão ([[SQL-018-Schema-core_comissao-Comissao-da-Proposta]]); a base de preço ([[SQL-017-Orcamento-em-core_vendas_faturamento-Base-de-Preco-e-Pedido-de-Custo]]); a carga da pipeline que preenche `pedidos_vendas_sequenciais_itens`, `condicoes_pagamento_vendas` e `cenarios_impostos`; o calendário de feriados (biblioteca + exceções do marketing); a devolução de compra.

## 6. Checklist do DBA

1. Reproduzir o dump de referência e aplicar `0001`; rodar `0002` (esperado: nenhuma exceção inesperada, 72 verificações).
2. Decidir o formato do número da proposta (`numero_numerico`, 🟡 N16-04).
3. Decidir se `unidades_emissoras` continua como extensão ou se os campos (CRC, logo, textos) vão para `core.unidades` (N16-80; hoje já são extensão 1:1).
4. Conferir a normalização `pedidos_vendas.sequencial NULL → 0` (hoje não há nulo).
5. Decidir os índices de leitura das visões de custo pelo volume (`vw_pedido_produtos` soma a família inteira; um pedido leva cerca de 40 ms no dump).
6. Conferir em dados reais que `ordens_compra_itens_vinculos.codigo_produto_pv` é o código do produto **do Omie** (no dump o vínculo está vazio).
6. Confirmar com o Nathan o critério de `fn_item_completo` (custo **e** fornecedor).

## 7. Perguntas em aberto

OQ-16 (testes no Omie, depois das telas), formato do número da proposta, em que tela o marketing cadastra as exceções do calendário, e como criar um sequencial pela API do Omie (provavelmente `IncluirPedido`, a testar com a tela).

## Ver também

[[LOG-56-Fluxo-da-Proposta-ao-Pedido]] · [[LOG-58-Liberacao-do-Pedido-Origem-Proposta]] · [[SQL-017-Orcamento-em-core_vendas_faturamento-Base-de-Preco-e-Pedido-de-Custo]] · [[SQL-018-Schema-core_comissao-Comissao-da-Proposta]] · [[SQL-019-Condicoes-de-Pagamento-de-Venda-do-Omie]] · [[API-019-Proposta-e-Pedido-de-Venda-na-API-do-Hub]] · [[Registro-de-Decisoes]] · [[Mapa-IncluirPedido-Omie]]
