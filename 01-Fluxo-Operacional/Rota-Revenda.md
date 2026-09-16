---
tags: [erp-acos-vital, fluxo-operacional]
criado: 2026-09-16
---

# 3b. Rota Revenda (CCP & Suprimentos)

- Emissão e envio da Ordem de Compra (OC).
- Gestão de entrega via CCP (follow-up ativo de prazos e trânsito).
- Liberação no fornecedor e transporte (coleta pela logística interna ou frete CIF).
- Recebimento físico e alocação preventiva em **quarentena**.
- Inspeção técnica pelo time de Qualidade.
- Entrada no estoque regular e liberação na carteira.

## Perfil de risco

Introduz dependência de terceiros logo na entrada (fornecedor) e tem os estados intermediários mais numerosos e sensíveis a atraso: emissão de OC, follow-up, coleta/frete, quarentena, inspeção, entrada em estoque. Provavelmente o **gargalo mais monitorável** do fluxo inteiro — cada etapa é candidata natural a virar um status com timestamp e SLA próprio.

Nota real do [[PRD-Estoque-Visao-Geral|PRD do Estoque]] (seção 18): **não existe um estado "em trânsito" verificável** — o fornecedor não tem acesso ao sistema, a data de entrega é sempre informada por canal externo (telefone/e-mail/WhatsApp) e registrada manualmente pelo comprador. O pedido permanece "Aprovado" até a chegada física.

## Onde isso é implementado (ou planejado)

Cobertura completa no [[PRD-Estoque-Visao-Geral|PRD do Estoque]] — ver [[Estoque-Modelo-Dados]] (pedido_compra, recebimento, inspecao_qualidade, rnc) e [[Estoque-Regras-Negocio]].

## Ver também
- [[Fluxo-Operacional-Visao-Geral]]
- [[AV-Hub-Modulos]] — o módulo "Orçamento" do av-hub já tem cadastro de fornecedores/histórico de preços, potencial ponto de integração com Compras.
