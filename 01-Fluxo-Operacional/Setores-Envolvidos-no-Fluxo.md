---
tags: [erp-acos-vital, fluxo-operacional, setores, referencia]
criado: 2026-09-16
---

# Setores Envolvidos no Fluxo do Pedido — Referência Completa

> Lista de todo setor/função que participa do ciclo de vida do pedido, do 0 ao 100%. Cada linha diz onde o setor **vai viver** (sistema-alvo), o que ele faz, e em qual dos fluxos detalhados ele aparece como ator.
>
> **Confirmado com o usuário (17/09/2026): a coluna "Sistema" é destino planejado, não sistema em produção.** Só "Vendas → av-hub" já é real hoje (emissão do pedido no Omie, sincronizada pro av-hub). Todas as outras linhas marcadas "MES" — PCP, Compras/CCP/Aprovador (av-hub), Recebimento, Qualidade, Fábrica, Estoque, Expedição, Logística — descrevem **o sistema que o projeto precisa construir**, não algo que já funciona. A única exceção parcial é "Fábrica/Setores de produção": o motor de execução do roteiro já existe e roda em produção pra Flanges (`app-pcp`), mas só a partir do ponto em que uma Ordem de Produção chega até ele — o despacho do PCP pra esse motor não existe.

| Setor | Sistema | O que faz no fluxo | Onde aparece em detalhe |
|---|---|---|---|
| **Vendas** (Vendedor) | av-hub | Emite o pedido, decide acompanhamento de qualidade (início/fim), observa status por item | [[Fluxo-Detalhado-Pedido-Item]], [[Fluxo-Qualidade-Completo]] (Q1) |
| **PCP** (produção) | MES | Na Carteira de Pedidos, escolhe por rodada itens, quantidades e **fábrica** (linha de fabricação ou Revenda) e gera a Ordem de Produção; resolve divergência e reprovação. Desde 24/09/2026 a checagem de saldo e a requisição de compra saíram do PCP e viraram setores do roteiro (Estoque e Compras) | [[Encaixe-Estoque-Revenda-no-PCP]], [[Modelo-Destinacao-Item]], todos os fluxos `*-Completo` |
| **Setor Compras** (tipo `COMPRAS`) | MES | Etapa do roteiro da fábrica Revenda: a entrada do parcial gera a requisição de compra; o parcial espera ali até o recebimento liberar | [[Encaixe-Estoque-Revenda-no-PCP]], [[Fluxo-Compras-Completo]] (C1) |
| **Compras** (Comprador) | av-hub | Escolhe fornecedor, negocia, emite a Ordem de Compra, define flag acabado/não-acabado | [[Fluxo-Compras-Completo]] |
| **CCP** | av-hub (junto de Compras) | Follow-up ativo de prazos/trânsito da Ordem de Compra já emitida — cobra o fornecedor, atualiza previsão de chegada | [[Fluxo-Compras-Completo]] |
| **Aprovador / Diretoria** | av-hub | Segunda aprovação condicional, se o valor da compra passar do limiar (ainda não definido) | [[Fluxo-Compras-Completo]] |
| **Fornecedor** | externo | Entrega o material comprado; sem acesso ao sistema — todo contato é por canal externo | [[Fluxo-Compras-Completo]], [[Fluxo-Recebimento-Completo]] |
| **Logística de entrada** | MES (ou terceirizada) | Só entra em ação no frete **FOB** (coleta no fornecedor, comprador assume desde o despacho); no **CIF** o fornecedor paga e entrega direto, sem esse setor participar | [[Fluxo-Compras-Completo]], [[Fluxo-Recebimento-Completo]] |
| **Recebimento** (Almoxarifado) | MES | Conferência quantitativa, pesagem, cria o lote, etiquetagem | [[Fluxo-Recebimento-Completo]] |
| **Qualidade** | MES | Inspeção (de processo ou final), aprova/reprova, RNC | [[Fluxo-Qualidade-Completo]] |
| **Fábrica / Setores de produção** (tipo `PRODUTIVO`) | MES | Executa OS (beneficiamento, setor opcional no roteiro da fábrica Revenda) ou OP (produção própria) — corte, usinagem, furação, acabamento, embalagem | [[Fluxo-Producao-OS-OP-Completo]] |
| **Estoque** (setor tipo `ESTOQUE`; Almoxarife, saldo geral) | MES | **Etapa 1 de todo roteiro** (24/09/2026): atende do saldo com split + reserva + conclusão e envia o restante. Recebe de volta o item comprado aprovado pela Qualidade (entrada + reserva). Guarda saldo, localização, movimentação entre depósitos, contagem cíclica | [[Encaixe-Estoque-Revenda-no-PCP]], [[Fluxo-Estoque-Completo]] |
| **Expedição** | MES | Embalagem, paletização, consolidação de carga (parcial × integral) | [[Fluxo-Expedicao-Faturamento-Completo]] |
| **Logística de saída** | MES | Define transporte, roteiro de entrega, comprovante de entrega ao cliente | [[Fluxo-Expedicao-Faturamento-Completo]] |
| **Fiscal** | Omie (externo) | Emite nota fiscal (entrada e saída) — sistema nunca emite, só sinaliza e referencia | Todos os fluxos, como fronteira — nunca como ator interno |
| **Financeiro** | — | Deliberadamente fora de escopo por agora (ver [[PRD-Estoque-Visao-Geral]]) | Não modelado — fase futura |

## Setor no fluxo × setor no MES (24/09/2026)

No MES, "setor" é uma entidade (`Setor`) que entra no roteiro de uma fábrica, e ganhou **tipo**: `PRODUTIVO` (padrão, as ações de hoje), `ESTOQUE` e `COMPRAS` (ações próprias de subsistema, mesmo `ItemParcial` contando o tempo). O antigo setor "Emissão de Ordens", que era o 1º de todo roteiro no sistema antigo, saiu: virou a tela Ordem de Produção. Ver [[Encaixe-Estoque-Revenda-no-PCP]].

## Nota sobre papéis vs. setores

Alguns nomes acima são **setor/função no fluxo**, outros são **perfil de acesso** (RBAC) — não são a mesma coisa. Ex.: "Almoxarife" é o perfil que opera tanto Recebimento quanto Estoque; "Gestor de Estoque" é perfil de supervisão sobre o mesmo setor, sem ser um passo distinto do fluxo. Ver segregação de função completa em [[Estoque-Regras-Negocio]] (Comprador, Aprovador, Almoxarife, Qualidade, Gestor de estoque).

## Notas complementares

- **CCP** é quem faz o acompanhamento ativo de follow-up de prazo — ator distinto do Comprador em [[Fluxo-Compras-Completo]].
- **Logística de entrada** só entra no frete **FOB** (coleta no fornecedor); no **CIF** o fornecedor paga e entrega direto. Incoterms que definem quem paga/é responsável pelo transporte, não "quem busca". Ver [[Fluxo-Compras-Completo]] e [[Fluxo-Recebimento-Completo]].
- **Estoque (operação geral)** está modelado como sequência de conversas em [[Fluxo-Estoque-Completo]], que também revela uma segunda origem de requisição de compra (ponto de pedido, preventiva) além da já modelada (reativa, vinda de pedido de venda).

## Ver também
- [[Fluxogramas-Completos]] — os fluxogramas visuais (mermaid) de tudo que está nesta tabela.
- [[Fluxo-Operacional-Visao-Geral]]
- [[Modelo-Destinacao-Item]]
- [[Fluxo-Detalhado-Pedido-Item]]
- [[Estoque-Regras-Negocio]]
