---
tags: [erp-acos-vital, arquitetura, decisoes]
criado: 2026-09-16
---

# Decisões-Chave para o ERP Unificado

Lista viva de decisões que precisam ser tomadas conscientemente para o "ERP de altíssimo nível" — atualizar conforme mais material chegar.

## Em aberto

- [x] **Identidade/autorização será múltipla.** 2 implementações reais: av-hub e MES (Estoque+Fabricação juntos). A proposta de grupos do Azure AD do PRD do Estoque original segue descartada. Ver [[Achado-Duplicacao-RBAC]] e [[MES-Arquitetura-Decisoes]].
- [x] **Login do MES/Estoque** vai suportar **as duas formas**, usuário/senha e e-mail (Azure AD). Resolve a lacuna de [[Estoque-Roadmap]].
- [x] **Vínculo Fábrica ↔ Unidade/Filial (`codigo_empresa`) será criado.** Desenho exato (1 fábrica = 1 filial fixa, ou vínculo por pedido) ainda não definido. Ver [[MES-Arquitetura-Decisoes]].
- [ ] **Conceito de "Orçamento"** — ainda não pensado pelo time; fica para quando entrar em pauta. Ver [[MES-Arquitetura-Decisoes]].
- [ ] **Criação nativa de Pedido de Venda/Ordem de Compra no av-hub com push para o Omie** — visão de futuro confirmada, não ativa hoje. Desenho de outbox/retry/anti-loop já esboçado, falta confirmar se o Omie tem API de criação de Ordem de Compra. Ver [[MES-Arquitetura-Decisoes]].
- [ ] **Nome definitivo do sistema de fábrica** — hoje "MES Aços Vital" é nome de trabalho.
- [ ] **Base única de fornecedores/preços — parcialmente resolvido**: Estoque vai reaproveitar `core.parceiros` do av-hub (via projeção), não criar cadastro próprio. Falta só confirmar se as views de Compras já existentes (`vw_catalogo_de_produtos`, `vw_fornecedores_com_produtos`, `vw_historico_precos`) já cobrem o que o módulo Orçamento do av-hub precisa, ou se ainda falta algo.
- [ ] **Reconciliar iniciativas de comissão.** `core_comissionamento` é só um **experimento de implementação** — não é prioridade imediata. Fica registrado, não ativo.
- [ ] **App-pcp/MES precisa só de frontend para o board de produção, não de backend novo.** `GET /dashboard`/`GET /dashboard/tv` já existem prontos — a lacuna é 100% de UI.
- [ ] **Divergência sem reabertura em `api-pcp`** — `ABERTA→EM_ANALISE→{RESOLVIDA|CANCELADA}` sem caminho de volta. Pode ser repetição do bug de "beco sem saída" que o PRD do Estoque cita como lição aprendida — confirmar com Robert se é intencional. Tratamento adiado, não é prioridade agora.
- [ ] **"Colunas protegidas" como padrão a adotar.** O pipeline ELT documenta explicitamente quais colunas nunca escreve porque pertencem a outro sistema. Qualquer integração nova deveria declarar esse contrato de propriedade de coluna desde o início.
- [ ] **Evitar FK entre entidades sincronizadas independentemente.** Lição documentada e aplicada no pipeline ELT — vale como princípio de design para qualquer sincronização assíncrona no ERP unificado.
- [ ] **2 "extras" do Portal do Vendedor podem já ter suporte de backend** (`usuarios_favoritos`, `clientes_inativos`) — investigar antes de re-priorizar como "caro"/"precisa de contrato novo". `pedidos_vendas_status_historico` fica de fora dessa lista: é histórico vindo do Omie (granularidade grossa), não log de transição interna — ver [[AV-Hub-Bugs-Catalogo]].
- [ ] **"Casamento" av-hub ↔ MES** (termo do usuário) — o fluxo detalhado descrito pelo gerente ([[Fluxo-Detalhado-Pedido-Item]]) pressupõe status por item visível no av-hub alimentado por eventos do PCP/MES; mecanismo exato de integração ainda não desenhado, e "tempo real" não deve ser assumido — o único padrão de sincronização entre sistemas hoje é polling em camadas (pipeline ELT do Omie), sem webhook. Maior item em aberto. **Achado (17/09/2026)**: o PRD do Estoque (`PRD-Estoque-Visao-Geral.md`, `MES-Arquitetura-Decisoes.md`) chegou a afirmar que a projeção de fornecedor/material do av-hub pro Estoque usaria "o mesmo mecanismo de evento que o av-hub já usa pra ler status de produção do MES" — **contradição direta com este item**: esse mecanismo não existe, é justamente o que está em aberto aqui. Ambas as notas já foram corrigidas para não assumir esse mecanismo; a projeção do Estoque deve seguir o mesmo padrão de polling (ex.: consumir `GET /produtos`/`GET /parceiros` de `api-acos-vital`) até este item ser de fato resolvido.
- [x] **Ordem de Serviço (OS) e Ordem de Produção (OP), emitidas pelo PCP:** mapeiam pro mecanismo já existente de `roteiro`/`ItemParcial` (8 estados) do `api-pcp`, não são entidades novas. Ver [[App-PCP-Backend-Producao]].
- [x] **Divisão Compras av-hub × MES.** Requisição nasce no MES (PCP, a partir de saldo/reserva); compra em si (fornecedor, preço, aprovação, flag acabado/não-acabado) é decidida no av-hub; só o necessário pra conferência trafega de volta pro MES. Ver [[Fluxo-Detalhado-Pedido-Item]] e [[MES-Arquitetura-Decisoes]].
- [ ] **Anexo de Ordem de Compra vira dado estruturado, não PDF** — o comprador anexando PDF manualmente (visto nos áudios) é só uma primeira fase; a intenção é trazer os dados da OC diretamente (sem depender de upload/parse de PDF). Ver [[Fluxo-Detalhado-Pedido-Item]].

## Já resolvidas / bem estabelecidas

- Schema Postgres isolado por domínio de negócio — convenção já provada (schemas de negócio confirmados: `core`, `auth`, `core_vendas_faturamento`, `core_compras`, `core_comissionamento`, `core_aprovacao_de_vagas`, mais `estoque` proposto).
- Infraestrutura self-hosted (Coolify/Traefik/Postgres/MinIO em 3 VPS) — reaproveitar, não criar infra nova.
- Fronteira fiscal: nenhum módulo deve emitir/editar nota fiscal — isso é sempre responsabilidade do Omie.
- Azure AD como SSO corporativo (exceto para usuários de chão de fábrica sem e-mail).
- Backend confirmado do av-hub: `api-acos-vital` (Express + Sequelize, sem migrations versionadas, DBA gerencia schema fora do repo) — é consumido também pelo `api-pcp` como gateway de consulta ao Omie.
- Sincronização com o Omie é EL (não ETL) — toda regra de negócio fica no banco/DBA, nunca no extrator. Ver [[Omie-ELT-Pipeline]]. Sem webhook disponível — polling em camadas é a única opção real.
- Dado de "manifestação do destinatário" (usado em `numero_nf` de várias views) vem de scraping via Playwright de um relatório de UI do Omie, não de API — fonte estruturalmente menos confiável, já documentada como tal nos contratos do av-hub.
- **Material = projeção de `core.produtos`** (av-hub), mesmo padrão do fornecedor — campos extras do Estoque vêm do Omie quando existirem, ou viram colunas novas quando não. Ver [[Estoque-Modelo-Dados]].
- **MES = Estoque + toda a fabricação** (lista aberta de linhas de produção — Flanges hoje, Grades de Piso/Chapa Expandida/Caldeiraria etc. conforme cadastradas), não só Flanges — modelo de Fábrica/Setor/Roteiro já é genérico o suficiente, só falta cadastrar as novas linhas. **Chapas não entra aqui** — corte de chapa (plasma/laser) é beneficiamento dentro da Revenda, não uma linha de fabricação. Ver [[Fabricacao-Chapas]] e [[Fluxo-Detalhado-Pedido-Item]].
- **Fronteira av-hub↔MES**: av-hub decide (Orçamento/Pedido de Venda/Ordem de Compra), MES executa (produção, recebimento, saldo). Ver [[MES-Arquitetura-Decisoes]] para o desenho completo (comunicação por evento+projeção, bancos separados, RBAC independente por sistema, Prisma confirmado para o Estoque).

## Ver também
- [[Home]]
- [[Achado-Duplicacao-RBAC]]
- [[Achado-Ambiguidade-PCP]]
- [[AV-Hub-Bugs-Catalogo]]
- [[Omie-ELT-Pipeline]]
- [[AV-Hub-Comissao-Modulo]]
- [[MES-Arquitetura-Decisoes]]
