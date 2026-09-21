---
tags: [erp-acos-vital, fluxo-operacional]
criado: 2026-09-16
---

# 3c. Rota Fabricação (PCP & Produção Interna)

> Fabricação **não** inclui corte de chapas — isso é beneficiamento dentro da [[Rota-Revenda|Revenda]], ver [[Fabricacao-Chapas]]. Fabricação é lista **aberta** de linhas de produção reais, cada uma com sua própria fábrica/roteiro no MES: hoje só **Flange** está de fato implementada; **Grade de Piso**, **Chapa Expandida**, **Caldeiraria** e outras entram conforme forem cadastradas — não é uma lista fechada de três itens. O modelo Fábrica/Setor/Roteiro do [[App-PCP-Visao-Geral|app-pcp]]/MES já é genérico o suficiente para qualquer linha nova; só falta cadastrar a fábrica e o roteiro quando a linha entrar em uso. Ver [[MES-Arquitetura-Decisoes]].

Duas linhas detalhadas neste vault até agora (as demais ainda não foram mapeadas em detalhe):

- [[Fabricacao-Flanges|Flanges]] — roteadas para o sistema dedicado de cálculo e parâmetros de flange ([[App-PCP-Visao-Geral|app-pcp]]/MES), única fábrica de fato cadastrada hoje.
- [[Fabricacao-Grades-Piso|Grades de piso]] — compra de matéria-prima específica → recebimento → fabricação → envio para industrialização/galvanização externa → retorno e validação.

## Por que tratar cada linha como subsistema próprio

Cada linha de produção tem perfil de risco e integração diferente — flanges depende de um sistema de cálculo técnico próprio; grades de piso tem dependência de terceiro **duas vezes** (compra de MP e depois galvanização externa), exigindo rastreamento de lote enviado/lote retornado. Mas todas compartilham o mesmo modelo de dados (Fábrica/Setor/Roteiro) e o mesmo mecanismo de despacho pelo PCP (emissão de Ordem de Produção) — ver [[Fluxo-Detalhado-Pedido-Item]].

> **Confirmado com o usuário (17/09/2026) — onde termina o que é real:** o `app-pcp`/MES em si (execução do roteiro de produção de Flanges — fábrica/setor/máquina/operador) **é real e está em produção**. O que **não existe** é tudo que vem antes dele neste fluxo: o PCP recebendo o pedido, classificando o item como "Fabricação", e despachando pra dentro do app-pcp emitindo uma Ordem de Produção. Esse encaixe (despacho PCP → app-pcp, e o status voltando) é 100% a construir, junto com o resto do fluxograma.

## Ver também
- [[Fluxo-Operacional-Visao-Geral]]
- [[App-PCP-Modelo-Producao]] — modelo de dados real do sistema de flanges.
