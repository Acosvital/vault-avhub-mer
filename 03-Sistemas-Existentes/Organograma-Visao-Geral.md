---
tags: [erp-acos-vital, organograma, rh]
criado: 2026-09-16
atualizado: 2026-09-16 (mecânica exata do campo "Reporta a" confirmada)
---

# Organograma — Terceiro Sistema

Descoberto indiretamente (via contratos de RH do av-hub) e agora **confirmado por leitura direta do schema real** em `api-acos-vital` (schema `core_organograma`). O av-hub só grava/lê os dados que alimentam esse organograma — não tem tela própria de árvore/visualização.

## Schema `core_organograma` — mais do que só a árvore

- **`node`** (model `organograma_node`) — `{id, parent_id, is_sector, id_ent}`, ambos `id`/`parent_id` como TEXT (não uuid puro), `is_sector` calculado por trigger a partir de `id_ent`, soft-delete (paranoid).
- **`nivel_hierarquico`** — PK é o próprio `nivel` (inteiro, não uuid), `cor`, `categoria` (`estrutural`|`pessoa`), sem timestamps, só 13 linhas — dicionário compartilhado com a tela de Cargos do av-hub (`cargos.nvl_permissao`).
- **`historia`, `historia_imagem`, `historia_timeline`** — **achado novo**: o Organograma não é só árvore hierárquica, tem uma seção de "**Nossa História**" (linha do tempo institucional da empresa, com imagens) — confirma o nome do documento `contrato-nossa-historia.md` visto nos docs do av-hub, que eu já tinha lido mas não tinha conectado à existência de um schema de suporte real.
- **`welcome_preset`, `welcome_settings`** — **achado novo**: alguma tela de "boas-vindas"/onboarding, com presets configuráveis — propósito exato não confirmado (não temos o frontend deste app), mas sugere que o Organograma é também uma espécie de portal de cultura/onboarding institucional, não só um visualizador de hierarquia.
- View de leitura **`vw_org_nodes`** (`vw_organograma_nodes.js`) — enriquece cada nó com `name/role/level/photo_url/sector_color/sector_director_of`, já pronta para consumo por um frontend de árvore.

## Regras de negócio confirmadas

- `NIVEL_MINIMO_HIERARQUIA = 4` — níveis 0-1 são raízes globais; 2-3 são só estruturais (setor); nenhum cargo de pessoa usa nível abaixo de 4.
- `reporta_a_id` no formulário de Funcionário (av-hub) vira `parent_id` do nó da pessoa — só deve ser gravado quando o usuário escolhe manualmente (override permanente); nunca para persistir o cálculo automático do backend (`fn_default_parent_pessoa`), sob risco de "travar" a pessoa e impedir redistribuição automática futura.
- Ao excluir um funcionário, overrides órfãos de colegas que apontavam pra ele são limpos (`limparOverridesApontandoPara`).

### "Reporta a" — mecânica exata confirmada (16/09)

O campo **"Reporta a"** na tela de Cadastro de Funcionários **não vai pro endpoint de funcionários** — é uma chamada separada, pro Organograma:

- **Backend real**: `POST /organograma_nodes` (cria) e `PUT /organograma_nodes/:id` (atualiza), consumidos via BFF em `app/api/organograma_nodes/route.ts` e `app/api/organograma_nodes/[id]/route.ts`.
- **Payload**: `{ id, id_ent, parent_id }` — `id`/`id_ent` = o próprio funcionário, `parent_id` = quem ele reporta.
- **Service que orquestra**: `definirReportaA`, chamado em `funcionarios/page.tsx:382` **só quando o campo muda** (`reportaAMudou`) — não dispara em toda edição de funcionário, só quando esse campo específico é alterado.
- **Confirmado no código** (`organogramaNodes.ts:63-71`): o banco já calcula um "pai" padrão sozinho quando não existe nó (`fn_default_parent_pessoa`). Uma linha em `organograma.node` é tratada como **override manual permanente** — por isso só se grava aqui quando o usuário escolhe alguém manualmente na tela, nunca o resultado do cálculo automático (o código evita ativamente persistir o valor calculado de volta, exatamente pra não "travar" a redistribuição automática quando o setor muda).

## O que ainda não sabemos

- Qual é o frontend real do Organograma (nome do repositório, stack) — não foi enviado nesta análise.
- Se ele tem autenticação/RBAC próprios (um quarto/quinto sistema de identidade?) ou reaproveita `auth.*` do av-hub.

## Por que isso importa para o ERP unificado

Evidência clara de que a Aços Vital já roda **múltiplos** apps ao redor do mesmo backend/Postgres, incluindo funcionalidades de cultura/onboarding (história institucional, welcome) que não têm relação direta com o fluxo operacional do pedido — mas competem pelo mesmo backend e pela mesma decisão de identidade/autorização unificada (ver [[Decisoes-Chave-ERP]]).

## Ver também
- [[AV-Hub-Arquitetura-BFF]]
- [[Schema-Postgres-Multi-Dominio]]
- [[RH-Escopo-Row-Level-Security]]
- [[AV-Hub-Modulos]]
