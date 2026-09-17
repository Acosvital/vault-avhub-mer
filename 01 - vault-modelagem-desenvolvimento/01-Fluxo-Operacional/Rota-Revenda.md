---
tags: [erp-acos-vital, fluxo-operacional]
criado: 2026-09-16
---

# 3b. Rota Revenda (CCP & Suprimentos)

- PCP verifica se o item já tem saldo em estoque (pronto ou como matéria-prima) — ver [[Fluxo-Detalhado-Pedido-Item]]. Se tem, pula direto pra conferência/beneficiamento; se não tem, segue o fluxo abaixo.
- Emissão e envio da Ordem de Compra (OC).
- Gestão de entrega via CCP (follow-up ativo de prazos e trânsito).
- Liberação no fornecedor e transporte — depende do incoterm da OC: **FOB** (Logística de entrada da empresa coleta) ou **CIF** (fornecedor paga e entrega direto). Ver [[Fluxo-Compras-Completo]].
- Recebimento físico e alocação preventiva em **quarentena**.
- Inspeção técnica pelo time de Qualidade.
- Entrada no estoque regular e liberação na carteira.

## Beneficiamento dentro da Revenda

> Corte a plasma/laser de chapa (cortar sob medida uma chapa comprada inteira) **é um beneficiamento dentro desta rota**, não uma sub-rota de Fabricação — ver [[Fabricacao-Chapas]]. Quando o material que chega precisa desse tipo de processo antes de ir pra Qualidade/Expedição, o item volta pro PCP, que emite uma **Ordem de Serviço (OS)**. Ver [[Fluxo-Detalhado-Pedido-Item]] para o fluxo completo item a item.

## Perfil de risco

Introduz dependência de terceiros logo na entrada (fornecedor) e tem os estados intermediários mais numerosos e sensíveis a atraso: emissão de OC, follow-up, coleta/frete, quarentena, inspeção, entrada em estoque. Provavelmente o **gargalo mais monitorável** do fluxo inteiro — cada etapa é candidata natural a virar um status com timestamp e SLA próprio.

Nota real do [[PRD-Estoque-Visao-Geral|PRD do Estoque]] (seção 18): **não existe um estado "em trânsito" verificável** — o fornecedor não tem acesso ao sistema, a data de entrega é sempre informada por canal externo (telefone/e-mail/WhatsApp) e registrada manualmente pelo comprador. O pedido permanece "Aprovado" até a chegada física.

## Onde isso é implementado (ou planejado)

**Nada disto existe hoje** (confirmado com o usuário, 17/09/2026) — toda a rota, do PCP emitindo OC até a entrada em estoque, é manual/informal. Cobertura completa (como planejamento, não sistema construído) no [[PRD-Estoque-Visao-Geral|PRD do Estoque]] — ver [[Estoque-Modelo-Dados]] (pedido_compra, recebimento, inspecao_qualidade, rnc) e [[Estoque-Regras-Negocio]].

## Ver também
- [[Fluxo-Operacional-Visao-Geral]]
- [[AV-Hub-Modulos]] — o módulo "Orçamento" do av-hub já tem cadastro de fornecedores/histórico de preços, potencial ponto de integração com Compras.
