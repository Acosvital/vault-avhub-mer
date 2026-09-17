---
tags: [integracao-omie, levantamento-api, lacunas, achado]
criado: 2026-09-17
---

# Finanças — lacuna total, e um problema de arquitetura, não só de extração

Nenhuma das 9 entidades financeiras do Omie é extraída hoje pelo pipeline. Diferente dos outros domínios, aqui a lacuna não é "campo faltando" — é o domínio inteiro.

## O achado que importa mais que qualquer campo

**Não existe, em nenhum lugar do roadmap atual (av-hub, Estoque, MES), um módulo financeiro próprio.** Contas a Pagar, Contas a Receber e Extrato de Conta Corrente são o passivo, o ativo e o caixa reais da empresa — não podem simplesmente desaparecer quando o Omie for desligado. Isso é uma decisão de arquitetura em aberto, não uma tarefa de pipeline: **ou nasce um módulo financeiro nativo, ou esse domínio inteiro fica permanentemente dependente do Omie**, o que contradiz o plano de desligamento.

## Estrutural — precisa de um sistema próprio no futuro

| Entidade | O que é | Por que não pode ficar órfã |
|---|---|---|
| **Contas a Pagar** (`financas/contapagar/`) | Passivo — fornecedores, insumos, serviços, impostos | Tem `numero_pedido` e `chave_nfe` ligando direto ao pedido de compra/nota de entrada — é o gatilho natural de conferência de recebimento |
| **Contas a Receber** (`financas/contareceber/`) | Ativo — recebíveis de venda | Tem `nCodPedido` (pedido de venda) e `nCodOS` (ordem de serviço) — vínculo mais forte de todo o levantamento com o fluxo já documentado |
| **Extrato de Conta Corrente** (`financas/extrato/`) | Extrato bancário oficial, saldo realizado/previsto | Insumo de conciliação e fechamento contábil |
| **Lançamentos de Conta Corrente** (`financas/contacorrentelancamentos/`) | Detalhe de cada lançamento bancário | Liga-se a CP/CR via `nCodLancCP`/`nCodLancCR` |

## Derivado/operacional — pode ficar no Omie sem urgência

| Entidade | Por quê |
|---|---|
| Boleto / PIX | Meios de cobrança derivados do CR, sem valor histórico próprio além do que já está no CR |
| Orçamento de Caixa | Agregado mensal recalculável a partir de CP/CR |
| Pesquisar Títulos / Movimentos Financeiros | Visões de consulta sobre CP/CR — não são fonte primária, mas são as **melhores rotas de extração** no dia de uma migração de histórico (já trazem os vínculos com pedido/OS/NF prontos) |

## Vínculo mais forte com o fluxo pedido→faturamento→estoque

`contareceber.nCodPedido`/`nCodOS`, `contapagar.numero_pedido`/`chave_nfe`, e principalmente os endpoints consolidados `mf` (Movimentos Financeiros) e `pesquisartitulos` — todos expõem o vínculo com pedido/OS diretamente. Isso é o que o Estoque/MES deveria mapear primeiro **mesmo sem se tornar dono do dado financeiro**: cruzar "pedido faturado" com "título pago/recebido" para fechar o ciclo do pedido de 0 a 100%.

## Recomendação

Este achado não tem uma ação de pipeline simples — é uma decisão que precisa subir para quem decide o roadmap: **definir se e quando um módulo financeiro nativo entra no escopo do ERP novo**, antes que o desligamento do Omie vire um bloqueio.

## Ver também
- [[Sintese-Migrar-vs-Nascer-Nativo]]
- [[Vendas-NFe-Lacunas]]
