---
tags: [erp-acos-vital, prd-estoque]
criado: 2026-09-16
---

# PRD — Sistema de Estoque, Recebimento de Materiais e Compras (MP e Revenda)

**Versão:** 1.0 · Setembro/2026 · Aços Vital
**Status:** 📋 Documento de planejamento — ainda não construído.

## Resumo

Hoje o controle de estoque, recebimento e compras não tem sistema dedicado — depende do que o Omie oferece nativamente, sem rastreabilidade de lote, sem conferência estruturada na doca e sem visibilidade cruzada com PCP (consumo de MP) e Portal Comercial B2B (disponibilidade de revenda).

O projeto entrega um **módulo interno (Next.js/PostgreSQL)** que se conecta ao ERP já existente — cobrindo três frentes: **compras** (MP e revenda), **recebimento** (conferência quantitativa pelo almoxarifado + conferência qualitativa pela Qualidade) e **estoque** (saldo, localização, rastreabilidade por lote, com quarentena até aprovação da qualidade).

> ⚠️ **Atualização (16/09) — onde o módulo mora, na prática, mudou:** a frase original acima ("reaproveitando infraestrutura, Postgres e pipeline Omie já em produção") sugeria viver no mesmo cluster Postgres do av-hub. A decisão de arquitetura mais recente é diferente: o Estoque passa a morar dentro do **banco do MES** (o sistema de fábrica, Prisma, banco separado do av-hub/`api-acos-vital`), consumindo dado de fornecedor/material do av-hub via **projeção read-only** (mesmo mecanismo de evento que o av-hub já usa para ler status de produção do MES, só que na direção contrária) — não por estar no mesmo cluster físico. Reaproveita a infraestrutura self-hosted (VPS/Coolify) no sentido amplo, mas não o cluster Postgres específico do av-hub. Ver [[MES-Arquitetura-Decisoes]] e [[Estoque-Modelo-Dados]].

## Onde isso se encaixa no fluxo operacional

Cobre os ramos [[Rota-Estoque|Estoque]] e [[Rota-Revenda|Revenda]] do [[Fluxo-Operacional-Visao-Geral|fluxo operacional]], mais o cadastro de matéria-prima que alimenta indiretamente a [[Rota-Fabricacao|Fabricação]]. Deixa de fora deliberadamente:
- **Portal Comercial B2B** (av-hub) — projeto vizinho de verdade (banco/sistema separado do MES); consome saldo de revenda via view somente leitura.
- **Fiscal** — permanece 100% no Omie; o sistema nunca emite nota, só referencia e sinaliza.

> ⚠️ **Correção (16/09):** este trecho listava também "PCP" como projeto vizinho que só "consome saldo de MP via view somente leitura" — isso valia no desenho original (Estoque isolado no cluster do av-hub), mas deixou de valer depois da decisão do MES. O PCP de **produção** (execução de fábrica/roteiro, hoje `app-pcp`) e o Estoque agora **compartilham o mesmo sistema/banco** (MES Aços Vital) — não é mais um projeto vizinho consumindo view de fora, é consulta interna dentro do mesmo MES. Ver [[MES-Arquitetura-Decisoes]] e [[PCP-Carteira]] (que continua sendo o conceito de classificação de item, não o sistema de execução).

## Escopo v1 (dentro)

- Carga inicial de estoque (pré-requisito — hoje não existe estoque controlado).
- Cadastro de material (MP e revenda), pedido de compra. ~~fornecedor~~ — sem cadastro próprio, ver nota abaixo.
- Recebimento com conferência (pedido × recebido) e tratamento de divergência.
- Controle de saldo, localização e movimentação de estoque.
- Rastreabilidade por lote/corrida.
- Etiquetagem por código de barras/QR.

> ⚠️ **Atualização (16/09):** o cadastro de `fornecedor` listado acima foi removido do escopo — reaproveita `core.parceiros` (av-hub) via projeção read-only, ver [[Estoque-Modelo-Dados]] e [[MES-Arquitetura-Decisoes]].

## Fora do escopo v1 (candidatos a fase futura)

- RFID em produção (só piloto).
- Marcação direta a laser (DPM) no metal.
- Substituição do Omie como sistema fiscal/financeiro.
- Cotação/comparação entre fornecedores (pedido já nasce com fornecedor escolhido). ⚠️ Ver nota em [[AV-Hub-Modulos]] — o módulo "Orçamento" do av-hub já tem parte disso.

## Investimento inicial estimado

Impressora industrial (Elgin TT042 Plus, ~R$4,1–5,2 mil) + leitor 2D de mão (Honeywell/Zebra, ~R$500–1,5 mil) → **~R$5–7 mil por posto de recebimento**.

## Ver também
- [[Setores-Envolvidos-no-Fluxo]] — todo setor participante, com onde vive e onde aparece em detalhe.
- [[Fluxo-Compras-Completo]], [[Fluxo-Recebimento-Completo]], [[Fluxo-Qualidade-Completo]], [[Fluxo-Producao-OS-OP-Completo]], [[Fluxo-Expedicao-Faturamento-Completo]], [[Fluxo-Estoque-Completo]] — o fluxo completo, do 0 ao 100%, detalhado conversa por conversa em cada subfluxo.
- [[Estoque-Modelo-Dados]]
- [[Estoque-Regras-Negocio]]
- [[Estoque-Riscos]]
- [[Estoque-Perguntas-Abertas]]
- [[Estoque-Roadmap]]
- [[Schema-Postgres-Multi-Dominio]] — desenho original previa o schema `estoque` neste cluster; hoje o Estoque mora no banco separado do MES, com schema próprio lá dentro (confirmado 16/09), ver [[MES-Arquitetura-Decisoes]].
