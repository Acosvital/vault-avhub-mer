---
tags: [erp-acos-vital, prd-estoque, roadmap]
criado: 2026-09-16
---

# PRD Estoque — Fases de Entrega

| Fase | Entrega |
|---|---|
| Fase 0 | Saneamento/deduplicação do catálogo Omie → cadastro de material e localização → levantamento físico e carga inicial (marco zero) |
| Fase A | Pedido de compra (MP e revenda) — sem cadastro de fornecedor próprio, ver nota abaixo |
| Fase B | Recebimento em duas etapas (quantitativa + qualitativa), pesagem, RNC, etiquetagem código de barras |
| Fase C | Estoque (saldo, localização, movimento, reserva) — consulta interna dentro do mesmo banco do MES, sem view de integração externa |
| Fase D | Separação/expedição, devolução de cliente, contagem cíclica e ponto de pedido |
| Fase E (futura) | Piloto de RFID em item de maior valor |

## Status da Fase 0 (17/09/2026)

Só a fatia de **saneamento/deduplicação do catálogo** é av-hub — o resto da
Fase 0 (cadastro de material com campos extras, localização, levantamento
físico, carga inicial) é 100% Estoque/MES, fora do av-hub.

- ✅ **Concluído no av-hub**: tela "Produtos — Prováveis Duplicatas"
  (`app/(protected)/cadastros/auxiliares/produtos-duplicados/`, repo
  `00 - HUB`) — agrupa o catálogo por descrição parecida, por unidade,
  só leitura. Corrigido de quebra o bug do campo `codigo_produto_omie`
  (frontend usava `id_produto_omie`, que nunca existiu na API — campo
  "ID Omie" da tela de Cadastro de Produtos nunca funcionou até agora).
- ⏳ **Pendente, fora do av-hub**: a ação de *resolver* a duplicata
  (registrar "este código é alias daquele") depende de um endpoint que o
  Estoque/MES ainda não tem — contrato de API já escrito e endereçado ao
  time do MES, ver [[002-Material-Alias-Omie-MES]].
  Até isso ser respondido, o av-hub não tem mais trabalho de código na
  Fase 0 — o relatório fica como está, servindo de lista de candidatos pro
  comprador/PCP revisar manualmente.

A Fase A não inclui cadastro próprio de fornecedor — o Estoque reaproveita `core.parceiros` (av-hub) via projeção read-only. O Estoque ganha um schema Postgres próprio dentro do banco do MES, seguindo a mesma convenção de schema-por-domínio do av-hub — ver [[Perguntas-Pendentes-MES-Estoque]] e [[MES-Arquitetura-Decisoes]]. Pedido de compra continua na Fase A, mas quem **decide** o pedido de compra é o av-hub — o Estoque só referencia quando o material chega na doca.

**Telas:** ~21 telas (mais login), organizadas em Cadastros, Compras, Recebimento, Estoque e Gestão.

O MES (`api-pcp`) usava só usuário/senha, sem Azure AD — decisão deliberada porque o público original (chão de fábrica) não tem e-mail corporativo (ver [[App-PCP-Visao-Geral]]). O MES passa a suportar os dois métodos de login: usuário/senha (chão de fábrica) e e-mail/Azure AD (perfis de escritório do Estoque: almoxarife, Qualidade, gestor de estoque — Comprador e Aprovador ficam no av-hub, nunca logam no MES, ver [[Fluxo-Compras-Completo]]). Ver [[Decisoes-Chave-ERP]].

**Equipe:** time de desenvolvimento disponível — [[Equipe-Projeto|Gustavo]] (banco de dados/API) e [[Equipe-Projeto|Robert]] (fullstack sênior) — com Nathan coordenando/product owner.

## Ver também
- [[Cronograma-2-Meses]] — as fases 0/A/B/C datadas para 18/09–18/11/2026 (Fase D e E ficam para o ciclo seguinte).
- [[PRD-Estoque-Visao-Geral]]
- [[Estoque-Perguntas-Abertas]]
