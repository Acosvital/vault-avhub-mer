---
tags: [erp-acos-vital, prd-estoque, roadmap]
criado: 2026-09-16
---

# PRD Estoque — Fases de Entrega

| Fase | Entrega |
|---|---|
| Fase 0 | Saneamento/deduplicação do catálogo Omie → cadastro de material e localização → levantamento físico e carga inicial (marco zero) |
| Fase A | Schema Postgres, cadastro de fornecedor, pedido de compra (MP e revenda) |
| Fase B | Recebimento em duas etapas (quantitativa + qualitativa), pesagem, RNC, etiquetagem código de barras |
| Fase C | Estoque (saldo, localização, movimento, reserva), views de integração para PCP e Portal Comercial |
| Fase D | Separação/expedição, devolução de cliente, contagem cíclica e ponto de pedido |
| Fase E (futura) | Piloto de RFID em item de maior valor |

**Telas:** ~21 telas (mais login via redirect do Azure AD), organizadas em Cadastros, Compras, Recebimento, Estoque e Gestão.

**Equipe:** time de desenvolvimento disponível — [[Equipe-Projeto|Gustavo]] (banco de dados/API) e [[Equipe-Projeto|Robert]] (fullstack sênior) — com Nathan coordenando/product owner.

## Ver também
- [[PRD-Estoque-Visao-Geral]]
- [[Estoque-Perguntas-Abertas]]
