---
tags: [erp-acos-vital, arquitetura, decisoes, pendencias, mes]
criado: 2026-09-16
---

# Perguntas Pendentes — MES / Estoque / av-hub

Documento de referência rápida com as perguntas em aberto do desenho de arquitetura, pra levar pra reunião com o time (Gustavo/Robert) sem precisar garimpar no histórico de conversa. Contexto completo de cada decisão já tomada está em [[MES-Arquitetura-Decisoes]].

## Material/Produto

Ficou decidido que **fornecedor** não tem cadastro próprio no Estoque — reaproveita `core.parceiros` (av-hub) via projeção. Mesma lógica vale pro catálogo: **`material` é projeção de `core.produtos`**, com campos extras do lado do Estoque (peso teórico, tolerância, mínimo/máximo etc.) — esses extras podem vir do próprio Omie (se o dado existir lá) ou ser colunas novas, criadas só no lado do Estoque, quando o Omie não tiver o campo.

## `quality-api`

É um sistema **não relacionado** — publica PDF com dados de qualidade pra o cliente baixar e inspecionar. Fora de escopo do Estoque/MES.

## Devolução de cliente

O av-hub já classifica devolução comercialmente (grupos G2 "Devolvido"/G2P "Devolvido Parcial" na cascata de dedução de venda líquida). A entidade `devolucao_cliente` do PRD do Estoque cuida do lado físico (reentrada no estoque, conferência).

A devolução precisa do **ciclo de vida completo tratado** (não só sinalizar e esperar o Omie) — incluindo a volta física pro estoque. `pedidos_vendas.devolucao_parcial` é só um **boolean**, sem campo de valor nenhum — não é que o dado vem errado, é que **não existe valor capturado**. Isso afeta diretamente a cascata G2/G2P (hoje calculada sem ter de onde tirar o valor da devolução parcial, ver [[AV-Hub-Vendas-Reconciliacao]]).

> **Resolvido em parte (confirmado com o usuário, 17/09/2026): o Omie não tem endpoint pra esse valor.** A hipótese do [[006-Pedidos-Vendas-Valor-Devolucao|contrato SQL 006]] (chamar `StatusDevolucaoVenda` individualmente por devolução) foi investigada e **invalidada** — o endpoint não está disponível. Isso fecha a pergunta "dá pra sincronizar do Omie?" com **não**: o valor da devolução parcial vai ter que ser **capturado nativamente** no sistema da Aços Vital, não sincronizado. Não resolve sozinho a pergunta de fundo (abaixo) — só elimina uma das duas opções que ela cogitava.

Ainda em aberto: a devolução nasce como decisão no av-hub (ligada à classificação G2/G2P) com o Estoque só executando o reingresso físico — mesma fronteira decisão/execução já usada pra Ordem de Compra? Ou o ciclo de vida completo (incluindo capturar o valor da devolução parcial, hoje inexistente) precisa nascer no próprio Estoque/MES?

## Depósito × Fábrica

Decidido: **depósito central compartilhado em relação à fábrica**, não um depósito por fábrica. Modelado como múltiplos *warehouses* (Warehouse 01, Warehouse 02...), cada um com seu próprio conteúdo/saldo rastreado e relatório geral por warehouse. Todas as fábricas e a Revenda puxam desse conjunto de depósitos compartilhados — não há vínculo fixo 1:1 fábrica↔depósito. Isso simplifica o RBAC por instância: escopo é por warehouse, não por fábrica. **Atualização (21/09/2026, L-09)**: em relação à **filial**, o compartilhamento não é incondicional — `deposito.codigo_empresa` passa a existir quando a filial tiver seu próprio setor de compras. Ver [[Estoque-Modelo-Dados]] e [[Lacunas-de-Logica-e-Clareza]] (L-09).

## Login do Estoque

O MES vai suportar **as duas formas** (usuário/senha pro chão de fábrica, e-mail/Azure AD pros perfis de escritório do Estoque). Ver [[Estoque-Roadmap]] e [[Decisoes-Chave-ERP]].

## Namespacing do schema do Estoque dentro do banco do MES

**Estoque terá schema especial próprio** dentro do banco do MES, seguindo a mesma convenção de schema-por-domínio já usada no lado do av-hub.

## Já resolvidas (referência)

- Fornecedor = `core.parceiros` (av-hub), via projeção. **Mecanismo dessa projeção ainda em aberto** — ver seção abaixo.
- Material = projeção de `core.produtos`, com campos extras (peso teórico, tolerância, mínimo/máximo) vindos do Omie quando existirem, ou como colunas novas do lado do Estoque quando não existirem.
- MES cobre Estoque + toda a fabricação — **lista aberta** (Flanges hoje; Grades de Piso/Chapa Expandida/Caldeiraria etc. conforme cadastradas). Chapas **não** entra — é beneficiamento de Revenda, ver [[Fabricacao-Chapas]].
- RBAC do Estoque segue o padrão já existente no MES (não nasce compartilhado com av-hub).
- Estoque usa Prisma, com schema Postgres próprio dentro do banco do MES.
- Ordem de Compra é decidida no av-hub, referenciada no MES quando o material chega — divisão exata de telas decidida em [[Fluxo-Detalhado-Pedido-Item]].
- Depósito é central compartilhado (múltiplos warehouses), não vinculado a fábrica.
- Login do MES/Estoque suporta usuário/senha e Azure AD.
- Vínculo Fábrica ↔ Unidade/Filial (`codigo_empresa`) será criado (desenho exato ainda em aberto, ver abaixo).
- Omie tem API de criação de Ordem de Compra, mas fica pro futuro.
- OS/OP = mecanismo `roteiro`/`ItemParcial` já existente no `api-pcp`.

## Ainda em aberto

- **Desenho exato do vínculo Fábrica ↔ Unidade/Filial** — confirmado que será criado, mas ainda não definido *como* (1 fábrica = 1 filial fixa? vínculo por pedido?).
- **Conceito de "Orçamento"** (ainda não pensado, entra depois).
- ~~**Nome definitivo do sistema de fábrica**~~ ✅ **Resolvido em 22/09/2026**: é **MES**, confirmado pelo Nathan — aceito por ora, com abertura para trocar no futuro.
- **Devolução de cliente**: mecanismo exato (decisão no av-hub vs. nascer no Estoque) ainda em aberto (ver seção acima).
- **Mecanismo real da projeção read-only de fornecedor/material (av-hub → Estoque)** — não é "o mesmo mecanismo de evento" que outras notas chegaram a citar (esse mecanismo não existe, ver [[Decisoes-Chave-ERP]], item "Casamento av-hub ↔ MES"). Hoje não há webhook nem infraestrutura de evento entre av-hub e MES — o padrão único de sincronização entre sistemas é polling. Candidato mais simples: Estoque consome por polling os endpoints REST já existentes de `api-acos-vital` (`GET /produtos`, `GET /parceiros`), que hoje não têm filtro incremental por data de alteração (`updated_at`) — precisaria ser adicionado para um polling eficiente.

## Ver também
- [[MES-Arquitetura-Decisoes]]
- [[Decisoes-Chave-ERP]]
- [[Estoque-Perguntas-Abertas]]
