---
tags: [erp-acos-vital, arquitetura, decisoes]
criado: 2026-09-16
atualizado: 2026-09-16
---

# Decisões-Chave para o ERP Unificado

Lista viva de decisões que precisam ser tomadas conscientemente para o "ERP de altíssimo nível" — atualizar conforme mais material chegar.

## Em aberto

- [x] **Identidade/autorização — decidido que será múltipla (16/09).** 2 implementações reais: av-hub e MES (Estoque+Fabricação juntos). O Organograma **usa a mesma autenticação do av-hub** (não é uma terceira identidade — era uma lacuna de mapeamento, não de fato; Organograma é essencialmente um totem que mostra dados de RH do av-hub). A proposta de grupos do Azure AD do PRD do Estoque original segue descartada. Ver [[Achado-Duplicacao-RBAC]] e [[MES-Arquitetura-Decisoes]].
- [x] **Login do MES/Estoque** — confirmado (16/09): vai suportar **as duas formas**, usuário/senha e e-mail (Azure AD). Resolve a lacuna de [[Estoque-Roadmap]].
- [x] **Vínculo Fábrica ↔ Unidade/Filial (`codigo_empresa`)** — confirmado (16/09): **será criado**. Desenho exato (1 fábrica = 1 filial fixa, ou vínculo por pedido) ainda não definido. Ver [[MES-Arquitetura-Decisoes]].
- [ ] **Conceito de "Orçamento"** — ainda não pensado pelo time; fica para quando entrar em pauta. Ver [[MES-Arquitetura-Decisoes]].
- [ ] **Criação nativa de Pedido de Venda/Ordem de Compra no av-hub com push para o Omie** — visão de futuro confirmada, não ativa hoje. Desenho de outbox/retry/anti-loop já esboçado, falta confirmar se o Omie tem API de criação de Ordem de Compra. Ver [[MES-Arquitetura-Decisoes]].
- [ ] **Nome definitivo do sistema de fábrica** — hoje "MES Aços Vital" é nome de trabalho.
- [ ] **Base única de fornecedores/preços — parcialmente resolvido**: Estoque vai reaproveitar `core.parceiros` do av-hub (via projeção), não criar cadastro próprio. Falta só confirmar se as views de Compras já existentes (`vw_catalogo_de_produtos`, `vw_fornecedores_com_produtos`, `vw_historico_precos`) já cobrem o que o módulo Orçamento do av-hub precisa, ou se ainda falta algo.
- [ ] **Reconciliar iniciativas de comissão.** `core_comissionamento` é só um **experimento de implementação**, confirmado pelo usuário — não é prioridade imediata. Fica registrado, não ativo.
- [ ] **App-pcp/MES precisa só de frontend para o board de produção, não de backend novo.** `GET /dashboard`/`GET /dashboard/tv` já existem prontos — a lacuna é 100% de UI.
- [ ] **Convenções de escopo "vazio" inconsistentes dentro do próprio av-hub.** Escopo por unidade usa "sem vínculo = irrestrito"; escopo por setor usa "sem vínculo = vazio" (oposto). Ver [[RH-Escopo-Row-Level-Security]].
- [ ] **Divergência sem reabertura em `api-pcp`** — `ABERTA→EM_ANALISE→{RESOLVIDA|CANCELADA}` sem caminho de volta. Pode ser repetição do bug de "beco sem saída" que o PRD do Estoque cita como lição aprendida — confirmar com Robert se é intencional. **Adiado (16/09)** — usuário vai tratar depois, não é prioridade agora.
- [ ] **"Colunas protegidas" como padrão a adotar.** O pipeline ELT documenta explicitamente quais colunas nunca escreve porque pertencem a outro sistema. Qualquer integração nova deveria declarar esse contrato de propriedade de coluna desde o início.
- [ ] **Evitar FK entre entidades sincronizadas independentemente.** Lição documentada e aplicada no pipeline ELT — vale como princípio de design para qualquer sincronização assíncrona no ERP unificado.
- [ ] **3 "extras" do Portal do Vendedor podem já ter suporte de backend** (`usuarios_favoritos`, `pedidos_vendas_status_historico`, `clientes_inativos`) — investigar antes de re-priorizar como "caro"/"precisa de contrato novo".
- [ ] **"Casamento" av-hub ↔ MES** (termo do usuário) — o fluxo detalhado descrito pelo gerente ([[Fluxo-Detalhado-Pedido-Item]]) pressupõe status por item visível no av-hub alimentado por eventos do PCP/MES; mecanismo exato de integração ainda não desenhado, e "tempo real" não deve ser assumido — o único padrão de sincronização entre sistemas hoje é polling em camadas (pipeline ELT do Omie), sem webhook. Maior item em aberto desta rodada.
- [x] **Ordem de Serviço (OS) e Ordem de Produção (OP), emitidas pelo PCP — decidido (16/09):** mapeiam pro mecanismo já existente de `roteiro`/`ItemParcial` (8 estados) do `api-pcp`, não são entidades novas. Ver [[App-PCP-Backend-Producao]].
- [x] **Divisão Compras av-hub × MES — decidida (16/09).** Requisição nasce no MES (PCP, a partir de saldo/reserva); compra em si (fornecedor, preço, aprovação, flag acabado/não-acabado) é decidida no av-hub; só o necessário pra conferência trafega de volta pro MES. Ver [[Fluxo-Detalhado-Pedido-Item]] e [[MES-Arquitetura-Decisoes]].
- [ ] **Anexo de Ordem de Compra vira dado estruturado, não PDF** — o comprador anexando PDF manualmente (visto nos áudios) é só uma primeira fase; a intenção é trazer os dados da OC diretamente (sem depender de upload/parse de PDF). Ver [[Fluxo-Detalhado-Pedido-Item]].

## Já resolvidas / bem estabelecidas

- Schema Postgres isolado por domínio de negócio — convenção já provada (7 schemas de negócio confirmados: `core`, `auth`, `core_vendas_faturamento`, `core_comissionamento`, `core_aprovacao_de_vagas`, `core_organograma`, mais `estoque` proposto).
- Infraestrutura self-hosted (Coolify/Traefik/Postgres/MinIO em 3 VPS) — reaproveitar, não criar infra nova.
- Fronteira fiscal: nenhum módulo deve emitir/editar nota fiscal — isso é sempre responsabilidade do Omie.
- Azure AD como SSO corporativo (exceto para usuários de chão de fábrica sem e-mail).
- Backend confirmado do av-hub: `api-acos-vital` (Express + Sequelize, sem migrations versionadas, DBA gerencia schema fora do repo) — serve pelo menos 2 frontends (av-hub + Organograma) e é consumido também pelo `api-pcp` como gateway de consulta ao Omie.
- Padrão de row-level security (escopo por unidade/setor, com CTE recursiva para subárvore) já maduro em produção no av-hub — ver [[RH-Escopo-Row-Level-Security]].
- Sincronização com o Omie é EL (não ETL) — toda regra de negócio fica no banco/DBA, nunca no extrator. Ver [[Omie-ELT-Pipeline]]. Sem webhook disponível — polling em camadas é a única opção real.
- Dado de "manifestação do destinatário" (usado em `numero_nf` de várias views) vem de scraping via Playwright de um relatório de UI do Omie, não de API — fonte estruturalmente menos confiável, já documentada como tal nos contratos do av-hub.
- **Material = projeção de `core.produtos`** (av-hub), mesmo padrão do fornecedor — campos extras do Estoque vêm do Omie quando existirem, ou viram colunas novas quando não. Ver [[Estoque-Modelo-Dados]].
- **MES = Estoque + toda a fabricação** (lista aberta de linhas de produção — Flanges hoje, Grades de Piso/Chapa Expandida/Caldeiraria etc. conforme cadastradas), não só Flanges — modelo de Fábrica/Setor/Roteiro já é genérico o suficiente, só falta cadastrar as novas linhas. **Correção (16/09, confirmado pelo gerente): Chapas não entra aqui** — corte de chapa (plasma/laser) é beneficiamento dentro da Revenda, não uma linha de fabricação. Ver [[Fabricacao-Chapas]] e [[Fluxo-Detalhado-Pedido-Item]].
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
