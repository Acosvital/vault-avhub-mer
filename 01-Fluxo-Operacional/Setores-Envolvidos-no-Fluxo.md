---
tags: [erp-acos-vital, fluxo-operacional, setores, referencia]
criado: 2026-09-16
---

# Setores Envolvidos no Fluxo do Pedido — Referência Completa

> Lista de todo setor/função que participa do ciclo de vida do pedido, do 0 ao 100%. Cada linha diz onde o setor vive (sistema), o que ele faz, e em qual dos fluxos detalhados ele aparece como ator.

| Setor | Sistema | O que faz no fluxo | Onde aparece em detalhe |
|---|---|---|---|
| **Vendas** (Vendedor) | av-hub | Emite o pedido, decide acompanhamento de qualidade (início/fim), observa status por item | [[Fluxo-Detalhado-Pedido-Item]], [[Fluxo-Qualidade-Completo]] (Q1) |
| **PCP** (produção) | MES | Classifica cada item (natureza × disponibilidade), gera requisição de compra, emite OS/OP, resolve divergência e reprovação | [[Modelo-Destinacao-Item]], todos os fluxos `*-Completo` |
| **Compras** (Comprador) | av-hub | Escolhe fornecedor, negocia, emite a Ordem de Compra, define flag acabado/não-acabado | [[Fluxo-Compras-Completo]] |
| **CCP** | av-hub (junto de Compras) | Follow-up ativo de prazos/trânsito da Ordem de Compra já emitida — cobra o fornecedor, atualiza previsão de chegada | [[Fluxo-Compras-Completo]] ⚠️ estava faltando como ator distinto, corrigido nesta rodada |
| **Aprovador / Diretoria** | av-hub | Segunda aprovação condicional, se o valor da compra passar do limiar (ainda não definido) | [[Fluxo-Compras-Completo]] |
| **Fornecedor** | externo | Entrega o material comprado; sem acesso ao sistema — todo contato é por canal externo | [[Fluxo-Compras-Completo]], [[Fluxo-Recebimento-Completo]] |
| **Logística de entrada** | MES (ou terceirizada) | Só entra em ação no frete **FOB** (coleta no fornecedor, comprador assume desde o despacho); no **CIF** o fornecedor paga e entrega direto, sem esse setor participar | [[Fluxo-Compras-Completo]], [[Fluxo-Recebimento-Completo]] |
| **Recebimento** (Almoxarifado) | MES | Conferência quantitativa, pesagem, cria o lote, etiquetagem | [[Fluxo-Recebimento-Completo]] |
| **Qualidade** | MES | Inspeção (de processo ou final), aprova/reprova, RNC | [[Fluxo-Qualidade-Completo]] |
| **Fábrica / Setores de produção** | MES | Executa OS (beneficiamento) ou OP (produção própria) — corte, usinagem, furação, acabamento, embalagem | [[Fluxo-Producao-OS-OP-Completo]] |
| **Estoque** (Almoxarife, saldo geral) | MES | Guarda saldo, localização, reserva, separação de item já pronto, movimentação entre depósitos, contagem cíclica | [[Fluxo-Estoque-Completo]] |
| **Expedição** | MES | Embalagem, paletização, consolidação de carga (parcial × integral) | [[Fluxo-Expedicao-Faturamento-Completo]] |
| **Logística de saída** | MES | Define transporte, roteiro de entrega, comprovante de entrega ao cliente | [[Fluxo-Expedicao-Faturamento-Completo]] |
| **Fiscal** | Omie (externo) | Emite nota fiscal (entrada e saída) — sistema nunca emite, só sinaliza e referencia | Todos os fluxos, como fronteira — nunca como ator interno |
| **Financeiro** | — | Deliberadamente fora de escopo por agora (ver [[PRD-Estoque-Visao-Geral]]) | Não modelado — fase futura |

## Nota sobre papéis vs. setores

Alguns nomes acima são **setor/função no fluxo**, outros são **perfil de acesso** (RBAC) — não são a mesma coisa. Ex.: "Almoxarife" é o perfil que opera tanto Recebimento quanto Estoque; "Gestor de Estoque" é perfil de supervisão sobre o mesmo setor, sem ser um passo distinto do fluxo. Ver segregação de função completa em [[Estoque-Regras-Negocio]] (Comprador, Aprovador, Almoxarife, Qualidade, Gestor de estoque).

## Lacunas identificadas e já corrigidas nesta rodada

1. **CCP não aparecia como ator distinto** — a "conversa" de follow-up de prazo estava atribuída direto ao Comprador em [[Fluxo-Compras-Completo]]. Corrigido: CCP é quem faz esse acompanhamento ativo.
2. **Logística de entrada não estava modelada, e o termo estava errado** — a menção original em [[Rota-Revenda]] usava "coleta própria ou frete CIF" como se fossem duas opções equivalentes; o par correto é **CIF × FOB** (incoterms que definem quem paga/é responsável pelo transporte, não "quem busca"). Corrigido em [[Fluxo-Compras-Completo]] e [[Fluxo-Recebimento-Completo]].
3. **Estoque (operação geral) não estava modelado como sequência de conversas** — só como conceito em [[Rota-Estoque]] ou célula da matriz em [[Modelo-Destinacao-Item]]. Corrigido em [[Fluxo-Estoque-Completo]], que também revelou uma segunda origem de requisição de compra (ponto de pedido, preventiva) além da já modelada (reativa, vinda de pedido de venda).

## Ver também
- [[Fluxogramas-Completos]] — os fluxogramas visuais (mermaid) de tudo que está nesta tabela.
- [[Fluxo-Operacional-Visao-Geral]]
- [[Modelo-Destinacao-Item]]
- [[Fluxo-Detalhado-Pedido-Item]]
- [[Estoque-Regras-Negocio]]
