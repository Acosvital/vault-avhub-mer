---
id: SQL-017
aliases: ["Contrato SQL 017", "017-Orcamento-em-core_comercial"]
tags: [contrato, contrato-sql, dba, migracao, orcamento, base-de-preco, ofertas, pedido-de-custo, core_comercial]
criado: 2026-10-21
atualizado: 2026-10-26
status: proposta
sistemas: [hub-banco]
dono: "Gustavo (DBA)"
etapa_0b: [V0.2, B1, B2, B3, B4]
fontes: ["Dump do Avhub para referência (schema), 26/10/2026", "Registro-de-Decisoes (N16-06, N16-07, N16-52 a N16-59)", "SQL-017-anexos/0001-migracao-orcamento-em-core_comercial.sql, 0002-teste-migracao.sql", "Proposta-Orcamento-Comissao/05-Contratos/SQL-016-anexos/_desenho-antigo-nao-usar (histórico, fora do vault)", "12-Orcamento-Base-de-Preco", "Proposta-Score-e-Volatilidade-OQ-46"]
criado_original: 2026-10-16
---

# Contrato SQL 017 — o Orçamento sobre o `core_comercial` real: ofertas das OCs, base e estatística de preço, pedido de custo sem prazo

> **Onde atua:** av-hub: banco

> [!info] Situação em 26/10/2026
> **Status:** `proposta` · **Dono:** Gustavo · Regra: [[12-Orcamento-Base-de-Preco]] · Rotas: [[API-020-Orcamento-Base-de-Preco-e-Pedido-de-Custo]]
>
> - 📝 **Mudou de natureza em 26/10.** O desenho de 16 a 21/10 propunha um schema novo `core_orcamento`. O banco real **já tem**, em `core_comercial`, as ofertas (imutáveis, com histórico), as categorias de suprimento, os fornecedores (perfil, categorias, certificados, apelidos), os produtos (perfil e pendentes), os parâmetros de custo e a tabela da telha com vigência, e as solicitações de custo. O contrato agora é só o que **falta**. O desenho antigo está em `Proposta-Orcamento-Comissao/05-Contratos/SQL-016-anexos/_desenho-antigo-nao-usar` (fora do vault).
> - 🧪 **Testado em Postgres 18** sobre o dump de referência, depois do SQL-016: a migração aplica sem erro e o teste `0002` passa (14 verificações). Nunca rodou em produção.
> - As tabelas de oferta, solicitação, fornecedor e produto pendente têm **0 linhas** no dump completo: não há dado a converter.

## 1. Por quê

O vendedor precisa de uma página do produto (histórico, fornecedores, volatilidade, média) e o Orçamento precisa de uma base de preço de compra **sempre com histórico** (N16-07). A oferta existe, mas **ninguém a alimenta** com o que Compras realmente pagou, não há base nem estatística derivada, e o pedido de custo ainda exige prazo, contra a N16-58.

## 2. O que a migração faz (anexo `0001-migracao-orcamento-em-core_comercial.sql`)

| Objeto | O que faz |
|---|---|
| `ofertas.fonte` ganha `OC_HUB` e `OC_OMIE` | a oferta passa a nascer da OC do Hub aprovada e do pedido de compra feito direto no Omie |
| `solicitacoes_custo.prazo_resposta` deixa de ser obrigatório | sem prazo fixo; o tempo é cronometrado desde `created_at` (N16-58) |
| `produtos_precos_fornecedor` | estado atual por produto × fornecedor × unidade: oferta vigente, última e janela do histórico (média ponderada pela quantidade quando há, mínimo, máximo) |
| `produtos_estatisticas_preco` | um quadro por produto × unidade: registros, fornecedores, média, mínimo, máximo, **desvio padrão e coeficiente de variação** (a volatilidade, OQ-46) |
| `fn_janela_historico_dias`, `fn_produtos_recalcular_precos`, gatilho `trg_ofertas_recalcular` | recalculam a base e a estatística quando entra oferta ou muda o status; oferta invalidada e "verificar escala" não entram |
| `vw_ofertas` | status efetivo: a vigente vence sozinha depois de `valida_ate` |
| `vw_produtos_serie_preco` | a série do gráfico "bolsa de valores": um ponto por preço visto, sem as invalidadas |
| `vw_matriz_precos` | matriz v1, produto × fornecedor (as dimensões extras entram com a OQ-10) |
| `fn_ofertas_gerar_de_ocs` | gera as ofertas das OCs aprovadas e dos pedidos de compra do Omie que não nasceram no Hub, e **invalida** a oferta de OC cancelada; idempotente; preço líquido de desconto e **sem imposto** (a OC ainda não guarda imposto por item, PS-014). Chamada pelo job a cada 15 minutos |

## 3. Regras

1. **Valor mais atualizado vale** (N16-52): a base reflete a oferta mais recente; o histórico fica.
2. A oferta é **imutável** (regra que já existe): só muda status e invalidação; corrigir é invalidar com motivo e lançar outra. Oferta **não se apaga**.
3. O vendedor consulta; **não edita** oferta nem matriz e **não é dono** do dado de custo (N16-07, N16-54).
4. O pedido de custo **não bloqueia** o vendedor nem tem prazo (N16-58, N16-59).
5. Pesos do score (preço 50%, prazo 30%, histórico 20%), limites de volatilidade e o "dado recente" de 7 dias são **parâmetro com vigência** lido pela API, não ficam no banco ([[Proposta-Score-e-Volatilidade-OQ-46]]).

## 4. Fora do contrato

As telas e as rotas ([[API-020-Orcamento-Base-de-Preco-e-Pedido-de-Custo]], [[LOG-60-Matriz-de-Precos-e-Consulta-do-Vendedor]]); a proposta e o pedido ([[SQL-016-Schema-core_comercial-Proposta-e-Pedido-de-Venda]]); a matriz de preços com dimensões além do produto e do fornecedor (OQ-10); o imposto por item da OC (PS-014).

## 5. Checklist do DBA

1. Aplicar depois do SQL-016 `0001`; rodar `0002` (esperado: 14 verificações, nenhuma exceção inesperada).
2. Agendar `fn_ofertas_gerar_de_ocs` (15 minutos) e o recálculo diário da base.
3. Confirmar o casamento OC × fornecedor (`codigo_fornecedor` = `codigo_parceiro_omie`) e OC × produto (`codigo_produto` = código do Omie ou do Hub) em dados reais: o teste usou dados de exemplo, porque as OCs estão vazias no dump.
4. Decidir os índices das visões pelo volume.

## 6. Aceite

1. Uma OC aprovada gera uma oferta `OC_HUB`; rodar de novo não duplica; OC cancelada invalida a oferta sem apagar.
2. A base recalcula sozinha (fornecedores, mínimo, máximo) e a série e a matriz refletem as ofertas válidas.
3. Pedido de custo nasce sem prazo.

## 7. Perguntas em aberto

OQ-10 (dimensões da matriz), OQ-38 (estoque confiável), PS-014 (imposto por item da OC).

## Ver também

[[12-Orcamento-Base-de-Preco]] · [[SQL-016-Schema-core_comercial-Proposta-e-Pedido-de-Venda]] · [[API-020-Orcamento-Base-de-Preco-e-Pedido-de-Custo]] · [[LOG-57-Menu-Vendas-Orcamento-Compras]] · [[Registro-de-Decisoes]]
