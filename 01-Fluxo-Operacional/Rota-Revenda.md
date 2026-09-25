---
tags: [erp-acos-vital, fluxo-operacional]
criado: 2026-09-16
atualizado: 2026-09-24
---

# 3b. Rota Revenda (CCP & Suprimentos)

> **Atualizado em 24/09/2026:** a Revenda passa a ser uma **fábrica** no MES (`Fabrica.tipo = REVENDA`), com roteiro próprio — deixa de ser "item sem fábrica", que hoje é descartado ao salvar a OP. Ver [[Encaixe-Estoque-Revenda-no-PCP]].

**Roteiro da fábrica Revenda:** `ESTOQUE` → `COMPRAS` → Recebimento → [beneficiamento, opcional] → Qualidade → **`ESTOQUE`** → entrega.

- **Setor Estoque (etapa 1).** O parcial chega e o saldo disponível na filial do pedido é conferido. A parte que o saldo cobre vira um split atendido (reserva + conclusão) e vai para a entrega; o restante segue — ver [[Fluxo-Detalhado-Pedido-Item]].
- **Setor Compras.** A entrada do parcial gera a requisição de compra (vinculada ao parcial); ele fica parado ali até o recebimento liberar.
- Emissão e envio da Ordem de Compra (OC) no av-hub.
- Gestão de entrega via CCP (follow-up ativo de prazos e trânsito).
- Liberação no fornecedor e transporte — depende do incoterm da OC: **FOB** (Logística de entrada da empresa coleta) ou **CIF** (fornecedor paga e entrega direto). Ver [[Fluxo-Compras-Completo]].
- Recebimento físico e alocação preventiva em **quarentena**.
- Inspeção técnica pelo time de Qualidade.
- **Aprovado, volta ao setor Estoque — não vai direto para a Expedição** (regra do Nathan, 24/09/2026): entrada do lote no saldo, reserva para o split e conclusão. Só então segue para a entrega.

## Beneficiamento dentro da Revenda

> Corte a plasma/laser de chapa (cortar sob medida uma chapa comprada inteira) **é um beneficiamento dentro desta rota**, não uma sub-rota de Fabricação — ver [[Fabricacao-Chapas]]. **Desde 24/09/2026 é um setor `PRODUTIVO` opcional no roteiro da fábrica Revenda**, escolhido pelo PCP ao montar a OP — resolve a "fábrica leve" que ficava em aberto. A OS de beneficiamento deixa de ser um retorno ao PCP: o parcial simplesmente passa por esse setor antes da Qualidade.

## Perfil de risco

Introduz dependência de terceiros logo na entrada (fornecedor) e tem os estados intermediários mais numerosos e sensíveis a atraso: emissão de OC, follow-up, coleta/frete, quarentena, inspeção, entrada em estoque. Provavelmente o **gargalo mais monitorável** do fluxo inteiro — cada etapa é candidata natural a virar um status com timestamp e SLA próprio. No MES, o tempo de cada etapa (estoque, compra, recebimento, qualidade) fica medido pelo histórico do `ItemParcial`.

Nota real do [[PRD-Estoque-Visao-Geral|PRD do Estoque]] (seção 18): **não existe um estado "em trânsito" verificável** — o fornecedor não tem acesso ao sistema, a data de entrega é sempre informada por canal externo (telefone/e-mail/WhatsApp) e registrada manualmente pelo comprador. O pedido permanece "Aprovado" até a chegada física.

## Onde isso é implementado (ou planejado)

~~Nada disto existe hoje (17/09/2026).~~ Em 24/09/2026: o motor de roteiro (`ItemParcial`) e a tela Ordem de Produção existem; a fábrica Revenda, os setores tipados Estoque/Compras e a entrada do item comprado no Estoque são a construir (C6, C7, D6, D8, D9 — ver [[Cronograma-2-Meses]]). O lado av-hub de Compras (requisição, OC) tem frontend e backend em andamento. Modelo de dados em [[Estoque-Modelo-Dados]] (recebimento, inspeção, RNC, reserva).

## Ver também
- [[Encaixe-Estoque-Revenda-no-PCP]]
- [[Fluxo-Operacional-Visao-Geral]]
- [[AV-Hub-Modulos]] — o módulo "Orçamento" do av-hub já tem cadastro de fornecedores/histórico de preços, potencial ponto de integração com Compras.
