---
tipo: plano
criado: 2026-10-09
atualizado: 2026-10-09
---

# AV-Hub: o que falta para entregar o desenho

> Status: decidido (Nathan, 09/10/2026) | no código (av-hub `develop` `111f605`, `api-acos-vital` `dee35b0`) | em produção: **não verificado**. **Régua desta nota: o Diagrama de Atividades (aba 0b de [[Diagramas-UML]], mestre fim a fim).** O objetivo do vault é entregar o sistema como o desenho está hoje; o que não aparece nele não conta para "concluir". Não é compromisso de prazo. Legenda: ✅ feito, 🟡 parcial, 🔴 pendente.

## O que o desenho pede do AV-Hub

O diagrama tem duas raias do AV-Hub, **Vendas** e **Compras** (esta compartilhada com o setor Compras do MES), mais quatro pontos de contato com o MES e com o Omie.

| Etapa do diagrama | Estado | O que falta | Quem |
|---|---|---|---|
| **V1** Pedido chega do Omie travado | ✅ [[26-Vendas-Liberacao-Pedido]] | Nada | |
| **V2/V3** Vendedor marca "Qualidade acompanha" e libera numa ação | ✅ tela 1.1 (`liberar-pedidos`, `liberacao-equipe`) | Escopo do vendedor na rota de liberação e em Meus Pedidos: hoje são marcas `GAMBIARRA(`; o escopo vem do token ([[40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]]) | Gustavo |
| **P2 → hub** Destinação confirma a importação | Hub ✅ (`POST /pedidos_liberados/:n/importado`) | Chave restrita L6 do MES e do pipeline, ou seguir com a chave admin; lado do MES a confirmar | Gustavo; Robert |
| **P3** Requisições: PCP abre, o hub recebe | ✅ ([[34-Requisicoes-MES-Empurra-para-o-Hub]], [[35-Compras-Marcos-Requisicao-para-MES]]), tela 3.1 | Nada | |
| **C1 a C4** Cotação, aprovação acima de R$ 30 mil, emissão da OC (CIF/FOB) | ✅ telas 3.2, 3.3, 3.4 | Ter aprovador de fato: o perfil Gerência de Compras tinha 0 usuários no dump de 07/10. Vincular os compradores ativos (20 de 74 em 07/10) | Nathan (nomes) |
| **C5** CCP faz o follow-up | ✅ tela 3.6 | Criar o perfil CCP (decidido em 08/10) | Nathan |
| Envio da OC ao fornecedor/Omie | Código pronto na pipeline | Deploy da API com o [[36-Compras-Produto-Obrigatorio-e-Comprador-da-OC]] | Gustavo |
| **Referência da OC → MES** (004) | Hub ✅, `api004` aplicada (DBA) | Job de leitura no MES (Robert, 3 pd). Estendido com os valores da OC: [[012-Ordens-Compra-Referencia-Valores]] e [[007-Referencia-OC-Valores-no-MES]] | Robert; Gustavo |
| **Status por item → Meus Pedidos** (005) | Consumidor no código (`dee35b0`, job de 90 s) | Teste ponta a ponta do cartão "Etapa dos itens"; fechar a tela 1.2 (`quantidade_na_etapa` pode vir `null`) | Nathan; Gustavo |
| **Recompra por RNC** (`Q3 → C1` e `P6 → P3`: a parte reprovada volta a Compras) | 🔴 **não achei tela nem contrato no hub** | Confirmar se o contrato 35 (eventos da requisição) já cobre; se não, desenhar a entrada de recompra em Compras | Nathan, Robert |
| Fiscal/Omie: NF e baixa do item | Fora do hub (Omie) | Só leitura do status | |

## Pedidos do desenho que dependem de decisão

1. **Aprovador e perfil CCP** (Nathan): sem eles a aprovação acima de R$ 30 mil e o follow-up ficam sem quem aja.
2. **L6** (Gustavo): a chave com que o MES confirma a importação.
3. **Recompra por RNC**: o desenho a exige; o vault não a descreve no hub.

## Ordem sugerida

1. **Fechar as pontas com o MES**: L6, job do 004 no MES, teste do 005 e tela 1.2.
2. **Escopo do vendedor** nas rotas de liberação e de pedidos (contrato 40), com o token renovável antes de o BFF parar de filtrar.
3. **Aprovador, CCP e compradores vinculados**, e o deploy do contrato 36.
4. **Recompra por RNC.**
5. **Torre de Fluxo**, por último, porque depende do feed do MES.

## Fora do desenho: não contam para "concluir"

Estes itens existem no AV-Hub mas **não aparecem no Diagrama de Atividades** e ficam fora desta conta (decisão do Nathan, 09/10/2026):

- Cadastros e RH (CRUD de produtos, troca de senha, login Azure, permissões, unidades/setores/cargos).
- Orçamento legado e o módulo Comercial e Suprimentos.
- Dashboards e Comissões (simulador, coordenadores, "minhas comissões", fechamento). Inclui a comissão por faturamento do [[47-Custo-Real-por-Item-no-Hub]].
- Pedidos de venda manuais ([[45-Pedido-de-Venda-Manual]]): o desenho só tem pedido que chega do Omie.
- Rate limit do login ([[41-Login-Rate-Limit-no-Backend]]), política do bucket ([[44-Upload-de-Fotos-Politica-de-Bucket]]) e as marcas `GAMBIARRA(` que só tocam esses módulos.
- Portal do Vendedor: itens do plano ([[AV-Hub-Portal-Vendedor-Plano]]).


## A Torre de Fluxo faz parte do desenho

A Torre de Fluxo é a **visualização do 0b**: mostra o processo da empresa e onde está cada item. O protótipo (artifact "Torre de Fluxo") tem 9 nós que são as raias do diagrama (Vendas, PCP, Estoque, Fábrica, Qualidade, Expedição, Compras·CCP, Recebimento, Fiscal), com os mesmos caminhos: solicitar compra, enviar à produção, inspeção de entrada e de saída, retorno ao Estoque, despacho, divergência e lote reprovado. Por isso a Torre **conta** para concluir (corrige a versão desta nota de 09/10, que a deixava de fora).

| Item | Estado | Quem |
|---|---|---|
| Protótipo visual com dados de exemplo | ✅ | |
| Feed do MES, tabelas `core_fluxo.*`, job de projeção e BFF ([[46-Torre-de-Fluxo-Feed-Jobs-e-Telas]]) | 🔴 nada em código | Robert (feed), Gustavo (tabelas), Nathan (telas) |
| Telas T.3, T.4, T.5, T.5b (mapa por setor, trilha do item, tempo por etapa) | 🔴 | Nathan (I5 e I6, 11 pd) |
| Ranking de gargalos (T.6) | Ciclo 2 (decidido em 07/10) | Nathan |

A régua é o 0b: a Torre só mostra o que o diagrama tem; qualquer etapa nova no 0b entra nela. Janela: S5 (26/11 a 18/12), depois do que depende do MES.

## Antes de chamar de pronto

Nada disto foi exercitado em produção. Faltam: testar na `api-test` o caminho do desenho (liberar → destinar → requisição → OC → recebimento → status por item) com um usuário de cada perfil envolvido (vendedor, PCP, comprador, aprovador, CCP), aplicar migrations e subir em ordem (banco, API, BFF) e conferir o `e2e`. O 0b ainda não mostra os valores da OC nem o custo do lote ([[Estoque-Custo-do-Lote]]); atualizá-lo é pendência do vault.

## Fontes
[[Diagramas-UML]] · [[Fluxograma-Telas-por-Bloco]] · [[Integracao-AvHub-MES-Volta-Plano]] · [[Registro-de-Decisoes-2026-10-07]] · [[Indice-Contratos]] · [[Cronograma-2-Meses]]
