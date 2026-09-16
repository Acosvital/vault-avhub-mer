---
tags: [erp-acos-vital, prd-estoque]
criado: 2026-09-16
---

# PRD — Sistema de Estoque, Recebimento de Materiais e Compras (MP e Revenda)

**Versão:** 1.0 · Setembro/2026 · Aços Vital
**Status:** 📋 Documento de planejamento — ainda não construído.

## Resumo

Hoje o controle de estoque, recebimento e compras não tem sistema dedicado — depende do que o Omie oferece nativamente, sem rastreabilidade de lote, sem conferência estruturada na doca e sem visibilidade cruzada com PCP (consumo de MP) e Portal Comercial B2B (disponibilidade de revenda).

O projeto entrega um **módulo interno (Next.js/PostgreSQL)** que se conecta ao ERP já existente — reaproveitando infraestrutura, Postgres e o pipeline de sincronização com o Omie já em produção — cobrindo três frentes: **compras** (MP e revenda), **recebimento** (conferência quantitativa pelo almoxarifado + conferência qualitativa pela Qualidade) e **estoque** (saldo, localização, rastreabilidade por lote, com quarentena até aprovação da qualidade).

## Onde isso se encaixa no fluxo operacional

Cobre os ramos [[Rota-Estoque|Estoque]] e [[Rota-Revenda|Revenda]] do [[Fluxo-Operacional-Visao-Geral|fluxo operacional]], mais o cadastro de matéria-prima que alimenta indiretamente a [[Rota-Fabricacao|Fabricação]]. Deixa de fora deliberadamente:
- **PCP** ([[PCP-Carteira]]) — projeto vizinho, consome saldo de MP via view somente leitura.
- **Portal Comercial B2B** — projeto vizinho, consome saldo de revenda do mesmo jeito.
- **Fiscal** — permanece 100% no Omie; o sistema nunca emite nota, só referencia e sinaliza.

## Escopo v1 (dentro)

- Carga inicial de estoque (pré-requisito — hoje não existe estoque controlado).
- Cadastro de material (MP e revenda), fornecedor, pedido de compra.
- Recebimento com conferência (pedido × recebido) e tratamento de divergência.
- Controle de saldo, localização e movimentação de estoque.
- Rastreabilidade por lote/corrida.
- Etiquetagem por código de barras/QR.

## Fora do escopo v1 (candidatos a fase futura)

- RFID em produção (só piloto).
- Marcação direta a laser (DPM) no metal.
- Substituição do Omie como sistema fiscal/financeiro.
- Cotação/comparação entre fornecedores (pedido já nasce com fornecedor escolhido). ⚠️ Ver nota em [[AV-Hub-Modulos]] — o módulo "Orçamento" do av-hub já tem parte disso.

## Investimento inicial estimado

Impressora industrial (Elgin TT042 Plus, ~R$4,1–5,2 mil) + leitor 2D de mão (Honeywell/Zebra, ~R$500–1,5 mil) → **~R$5–7 mil por posto de recebimento**.

## Ver também
- [[Estoque-Modelo-Dados]]
- [[Estoque-Regras-Negocio]]
- [[Estoque-Riscos]]
- [[Estoque-Perguntas-Abertas]]
- [[Estoque-Roadmap]]
- [[Schema-Postgres-Multi-Dominio]] — o schema `estoque` proposto segue a mesma convenção multi-schema já usada em produção.
