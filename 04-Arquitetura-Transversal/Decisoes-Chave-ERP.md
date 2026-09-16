---
tags: [erp-acos-vital, arquitetura, decisoes]
criado: 2026-09-16
atualizado: 2026-09-16
---

# Decisões-Chave para o ERP Unificado

Lista viva de decisões que precisam ser tomadas conscientemente para o "ERP de altíssimo nível" — atualizar conforme mais material chegar.

## Em aberto

- [ ] **Identidade/autorização única ou múltipla?** Ver [[Achado-Duplicacao-RBAC]] — hoje há **pelo menos 2** sistemas RBAC redundantes em produção (av-hub, MES), um terceiro modelo proposto no PRD do Estoque original (grupos do Azure AD, **já descartado** em favor do padrão do MES — ver [[MES-Arquitetura-Decisoes]]), e um quarto sistema ([[Organograma-Visao-Geral|Organograma]]) cuja identidade ainda não foi mapeada.
- [ ] **Vínculo Fábrica ↔ Unidade/Filial (`codigo_empresa`)** — confirmado como necessário pelo usuário, mas ainda sem desenho de como. Ver [[MES-Arquitetura-Decisoes]].
- [ ] **Conceito de "Orçamento"** — ainda não pensado pelo time; fica para quando entrar em pauta. Ver [[MES-Arquitetura-Decisoes]].
- [ ] **Criação nativa de Pedido de Venda/Ordem de Compra no av-hub com push para o Omie** — visão de futuro confirmada, não ativa hoje. Desenho de outbox/retry/anti-loop já esboçado, falta confirmar se o Omie tem API de criação de Ordem de Compra. Ver [[MES-Arquitetura-Decisoes]].
- [ ] **Nome definitivo do sistema de fábrica** — hoje "MES Aços Vital" é nome de trabalho.
- [ ] **Base única de fornecedores/preços — parcialmente resolvido**: Estoque vai reaproveitar `core.parceiros` do av-hub (via projeção), não criar cadastro próprio. Falta só confirmar se as views de Compras já existentes (`vw_catalogo_de_produtos`, `vw_fornecedores_com_produtos`, `vw_historico_precos`) já cobrem o que o módulo Orçamento do av-hub precisa, ou se ainda falta algo.
- [ ] **Reconciliar iniciativas de comissão.** `core_comissionamento` é só um **experimento de implementação**, confirmado pelo usuário — não é prioridade imediata. Fica registrado, não ativo.
- [ ] **App-pcp/MES precisa só de frontend para o board de produção, não de backend novo.** `GET /dashboard`/`GET /dashboard/tv` já existem prontos — a lacuna é 100% de UI.
- [ ] **Convenções de escopo "vazio" inconsistentes dentro do próprio av-hub.** Escopo por unidade usa "sem vínculo = irrestrito"; escopo por setor usa "sem vínculo = vazio" (oposto). Ver [[RH-Escopo-Row-Level-Security]].
- [ ] **Divergência sem reabertura em `api-pcp`** — `ABERTA→EM_ANALISE→{RESOLVIDA|CANCELADA}` sem caminho de volta. Pode ser repetição do bug de "beco sem saída" que o PRD do Estoque cita como lição aprendida — confirmar com Robert se é intencional.
- [ ] **"Colunas protegidas" como padrão a adotar.** O pipeline ELT documenta explicitamente quais colunas nunca escreve porque pertencem a outro sistema. Qualquer integração nova deveria declarar esse contrato de propriedade de coluna desde o início.
- [ ] **Evitar FK entre entidades sincronizadas independentemente.** Lição documentada e aplicada no pipeline ELT — vale como princípio de design para qualquer sincronização assíncrona no ERP unificado.
- [ ] **3 "extras" do Portal do Vendedor podem já ter suporte de backend** (`usuarios_favoritos`, `pedidos_vendas_status_historico`, `clientes_inativos`) — investigar antes de re-priorizar como "caro"/"precisa de contrato novo".

## Já resolvidas / bem estabelecidas

- Schema Postgres isolado por domínio de negócio — convenção já provada (7 schemas de negócio confirmados: `core`, `auth`, `core_vendas_faturamento`, `core_comissionamento`, `core_aprovacao_de_vagas`, `core_organograma`, mais `estoque` proposto).
- Infraestrutura self-hosted (Coolify/Traefik/Postgres/MinIO em 3 VPS) — reaproveitar, não criar infra nova.
- Fronteira fiscal: nenhum módulo deve emitir/editar nota fiscal — isso é sempre responsabilidade do Omie.
- Azure AD como SSO corporativo (exceto para usuários de chão de fábrica sem e-mail).
- Backend confirmado do av-hub: `api-acos-vital` (Express + Sequelize, sem migrations versionadas, DBA gerencia schema fora do repo) — serve pelo menos 2 frontends (av-hub + Organograma) e é consumido também pelo `api-pcp` como gateway de consulta ao Omie.
- Padrão de row-level security (escopo por unidade/setor, com CTE recursiva para subárvore) já maduro em produção no av-hub — ver [[RH-Escopo-Row-Level-Security]].
- Sincronização com o Omie é EL (não ETL) — toda regra de negócio fica no banco/DBA, nunca no extrator. Ver [[Omie-ELT-Pipeline]]. Sem webhook disponível — polling em camadas é a única opção real.
- Dado de "manifestação do destinatário" (usado em `numero_nf` de várias views) vem de scraping via Playwright de um relatório de UI do Omie, não de API — fonte estruturalmente menos confiável, já documentada como tal nos contratos do av-hub.
- **MES = Estoque + toda a fabricação** (Flanges, Chapas, Grades de Piso), não só Flanges — modelo de Fábrica/Setor/Roteiro já é genérico o suficiente, só falta cadastrar as novas linhas.
- **Fronteira av-hub↔MES**: av-hub decide (Orçamento/Pedido de Venda/Ordem de Compra), MES executa (produção, recebimento, saldo). Ver [[MES-Arquitetura-Decisoes]] para o desenho completo (comunicação por evento+projeção, bancos separados, RBAC independente por sistema, Prisma confirmado para o Estoque).

## Ver também
- [[Home]]
- [[Achado-Duplicacao-RBAC]]
- [[Achado-Ambiguidade-PCP]]
- [[AV-Hub-Bugs-Catalogo]]
- [[Organograma-Visao-Geral]]
- [[Omie-ELT-Pipeline]]
- [[AV-Hub-Comissao-Modulo]]
- [[MES-Arquitetura-Decisoes]]
