---
tags: [erp-acos-vital, moc]
criado: 2026-09-16
atualizado: 2026-09-16
---

# ERP Aços Vital — Mapa de Conhecimento

Vault de análise do projeto de **ERP de altíssimo nível** da Aços Vital: um sistema que acompanha um pedido de venda de 0 a 100%, de A a Z — da entrada comercial até a expedição.

## Como este vault está organizado

- [[Fluxo-Operacional-Visao-Geral|1. Fluxo Operacional]] — o mapa macro do processo: comercial → PCP → estoque/revenda/fabricação → faturamento. Ver também [[Fluxo-Detalhado-Pedido-Item|o mesmo fluxo no nível de item]], [[Modelo-Destinacao-Item|o modelo formal que reconcilia os dois]], [[Setores-Envolvidos-no-Fluxo|todos os setores envolvidos]] os 6 subfluxos conversa-por-conversa (Compras, Recebimento, Qualidade, Produção/OS-OP, Expedição/Faturamento, Estoque) e [[Fluxogramas-Completos|os fluxogramas visuais de tudo isso]].
- [[PRD-Estoque-Visao-Geral|2. PRD do Sistema de Estoque]] — o primeiro módulo novo planejado (compras, recebimento, estoque).
- [[AV-Hub-Visao-Geral|3. Sistemas existentes]] — av-hub, app-pcp e o [[Omie-ELT-Pipeline|pipeline ELT]] — frontends **e** backends reais.
- [[Schema-Postgres-Multi-Dominio|4. Arquitetura transversal]] — ver também [[Diagramas-UML|UML completo]] (classes, casos de uso, estados, componentes, implantação, pacotes) — decisões e padrões que atravessam todos os módulos.
- [[Equipe-Projeto|5. Pessoas e equipe]]
- [[Glossario|6. Glossário]]

## Estado atual do projeto (16/09/2026)

- ✅ Fluxo operacional macro mapeado e analisado.
- ✅ PRD do sistema de Estoque/Recebimento/Compras recebido e analisado (v1.0, ainda não construído).
- ✅ **Frontends** av-hub e app-pcp analisados em profundidade (todos os `docs/*.md`, todos os módulos, fluxos completos de pedido).
- ✅ **Backends reais** recebidos e analisados nesta rodada: `api-acos-vital` (Sequelize, backend do av-hub), `api-pcp` (NestJS+Prisma, backend do app-pcp) e `omie-elt-pipeline` (extrator Omie→Postgres). Isso permitiu **confirmar, corrigir e expandir** boa parte do que antes era inferido só a partir dos frontends e de contratos escritos.
- ✅ Descobertos 2 schemas de backend novos (`core_comissionamento`, `core_aprovacao_de_vagas`).
- ✅ Confirmado que a maioria dos bugs antes catalogados como pendentes **já foi corrigida** no backend real — ver [[AV-Hub-Bugs-Catalogo]].
- ✅ Confirmado que o backend do app-pcp é **muito mais maduro** que o frontend enviado (dashboard de produção, workflow de item por lote, entregas, divergências) — ver [[App-PCP-Backend-Producao]].
- ✅ **Fluxo detalhado item a item registrado** (16/09, transcrição de áudio do gerente): PCP verifica estoque como primeiro passo (não rota isolada), flag acabado/não-acabado do comprador define método de conferência no Recebimento, Ordem de Serviço/Ordem de Produção emitidas pelo PCP, status por item a caminho do av-hub. Ver [[Fluxo-Detalhado-Pedido-Item]].
- ✅ **Reclassificação:** corte de chapa (plasma/laser) é beneficiamento de **Revenda**, não uma linha de Fabricação — corrigido em todo o vault. "Chapa Expandida" (produto de linha própria) é diferente de "chapa cortada sob medida" (beneficiamento).
- ⏳ Próximas etapas: aguardando mais material do usuário sobre o projeto de ERP.

## Achados-chave

Ver [[Decisoes-Chave-ERP]] para a lista completa. Destaques:

- [[Achado-Duplicacao-RBAC|Duplicação de identidade/permissão]] entre av-hub e app-pcp.
- [[Achado-Ambiguidade-PCP|Ambiguidade do nome "PCP"]].
- O módulo de Estoque ainda não foi construído — existe só como PRD.
- O app-pcp tem **backend pronto para um board de produção** (dashboard/TV) que o frontend ainda não construiu — puramente lacuna de UI, não de dado.
- [[AV-Hub-Bugs-Catalogo|Dívida técnica]] — a maior parte já resolvida; poucos itens reais restantes.
- Padrões de engenharia maduros vistos nos dois backends e no pipeline ELT (concorrência via `updateMany`+conflito, colunas protegidas entre sistemas, adiamento deliberado de RBAC até desenhar escopo por instância, rejeição documentada de FK entre entidades sincronizadas independentemente) — candidatos a **princípios de arquitetura** para o ERP unificado, não só curiosidades.

## Visão do "pedido de 0 a 100%"

```
Entrada Comercial → PCP (Carteira) → [Estoque | Revenda | Fabricação] → Faturamento/Expedição
```

| Fase do fluxo                        | Sistema que cobre hoje                                               | Status                                                                                    |
| ------------------------------------ | -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Entrada comercial (venda)            | [[AV-Hub-Visao-Geral\|av-hub]] + [[Omie-ELT-Pipeline\|pipeline ELT]] | ✅ Em produção                                                                             |
| Acompanhamento comercial/financeiro  | [[AV-Hub-Modulos\|Portal PCP, Portal Vendedor, Portal Gerente]]      | ✅ Em produção                                                                             |
| Estoque / Recebimento / Compras      | [[PRD-Estoque-Visao-Geral\|PRD Estoque]]                             | 📋 Só planejado (mas Compras pode já ter views de backend — ver [[AV-Hub-Bugs-Catalogo]]) |
| Fabricação — Flanges                 | [[App-PCP-Visao-Geral\|app-pcp]] / MES Aços Vital                    | 🚧 Backend maduro, frontend em construção (Robert). Única fábrica cadastrada hoje. |
| Fabricação — Grade de Piso, Chapa Expandida, Caldeiraria etc. | MES Aços Vital (mesmo modelo Fábrica/Setor/Roteiro) | 📋 Sistema definido, fábricas/roteiros ainda não cadastrados (lista aberta, não só essas três) |
| Revenda — corte de chapa sob medida (plasma/laser) | [[PRD-Estoque-Visao-Geral\|PRD Estoque]] (beneficiamento) | 📋 Reclassificado 16/09: é Revenda, não Fabricação — ver [[Fabricacao-Chapas]] |
| Faturamento / Expedição              | Omie (nota fiscal) + av-hub (visão)                                  | ✅ Parcial (fiscal fica no Omie)                                                           |
| Comissionamento                      | [[AV-Hub-Comissao-Modulo]]                                           | ✅ Schema de backend em produção, uso ainda a esclarecer                                   |
