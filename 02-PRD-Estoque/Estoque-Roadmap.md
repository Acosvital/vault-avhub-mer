---
tags: [erp-acos-vital, prd-estoque, roadmap]
criado: 2026-09-16
---

# PRD Estoque — Fases de Entrega

| Fase | Entrega |
|---|---|
| Fase 0 | Saneamento/deduplicação do catálogo Omie → cadastro de material e localização → levantamento físico e carga inicial (marco zero) |
| Fase A | ~~Schema Postgres, cadastro de fornecedor~~, pedido de compra (MP e revenda) |
| Fase B | Recebimento em duas etapas (quantitativa + qualitativa), pesagem, RNC, etiquetagem código de barras |
| Fase C | Estoque (saldo, localização, movimento, reserva), views de integração para PCP e Portal Comercial |
| Fase D | Separação/expedição, devolução de cliente, contagem cíclica e ponto de pedido |
| Fase E (futura) | Piloto de RFID em item de maior valor |

> ⚠️ **Atualização (16/09):** "cadastro de fornecedor" na Fase A está riscado porque a decisão de arquitetura mais recente eliminou esse cadastro próprio — Estoque reaproveita `core.parceiros` (av-hub) via projeção read-only. "Schema Postgres" também está riscado porque hoje é pergunta em aberto se o Estoque ganha um schema próprio ou cai em `public` dentro do banco do MES — ver [[Perguntas-Pendentes-MES-Estoque]] (pergunta 5) e [[MES-Arquitetura-Decisoes]]. Pedido de compra continua na Fase A, mas quem **decide** o pedido de compra é o av-hub — o Estoque só referencia quando o material chega na doca.

**Telas:** ~21 telas (mais login), organizadas em Cadastros, Compras, Recebimento, Estoque e Gestão.

> ⚠️ **Lacuna identificada e resolvida (16/09):** o MES (`api-pcp`) hoje só suporta usuário/senha, sem Azure AD — decisão deliberada porque o público original (chão de fábrica) não tem e-mail corporativo (ver [[App-PCP-Visao-Geral]]). Confirmado: o MES **passa a suportar os dois métodos de login** — usuário/senha (chão de fábrica) e e-mail/Azure AD (perfis de escritório do Estoque: almoxarife, Qualidade, gestor de estoque — Comprador e Aprovador ficam no av-hub, nunca logam no MES, ver [[Fluxo-Compras-Completo]]). Ver [[Decisoes-Chave-ERP]].

**Equipe:** time de desenvolvimento disponível — [[Equipe-Projeto|Gustavo]] (banco de dados/API) e [[Equipe-Projeto|Robert]] (fullstack sênior) — com Nathan coordenando/product owner.

## Ver também
- [[PRD-Estoque-Visao-Geral]]
- [[Estoque-Perguntas-Abertas]]
