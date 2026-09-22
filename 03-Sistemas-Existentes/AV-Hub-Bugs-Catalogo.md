---
tags: [erp-acos-vital, av-hub, bugs, qualidade-de-dados]
criado: 2026-09-16
---

# av-hub — Catálogo de Bugs/Pendências Reais de Backend

Consolidado dos contratos técnicos (`docs/*.md`) do av-hub, verificado direto no código-fonte real de `api-acos-vital`.

## Comportamento atual confirmado no backend ✅

| Item | O que era | Confirmação no código |
|---|---|---|
| `POST/PUT/DELETE /blacklist_pedidos` | `codigo_empresa` ausente do model e da whitelist de campos | `src/models/blacklist_pedido.js` já declara `codigo_empresa` (PK composta com `numero_pedido`); rotas usam `findOne` por chave composta, não mais `findByPk` só por número |
| Filtro de nome em `GET /funcionarios` | `nome_completo` ignorado | `buildWhere` aplica `Op.iLike`; também ganhou filtros novos por `email`/`cpf` |
| Filtros de busca em `GET /parceiros` | `nome_fantasia`/`cpf_cnpj` comparavam errado; `razao_social`/`cidade` eram ignorados | Todos os 4 agora usam `Op.iLike` (exceto `estado`, que continua exato — é `CHAR(2)`) |
| Ordenação em `GET /vendedores` | `sort`/`order` sem efeito | Allowlist real (`VENDEDOR_SORTABLE`, 14 colunas) + `fallback`/`tiebreak` para paginação estável; ganhou de brinde `codigo_vendedor_omie` como filtro `ILIKE` e `id_funcionario_in` (lista, até 200 UUIDs) |
| `cor_unidade`/`foto_url` em `core.unidades` | Não existiam | Ambas presentes em `src/models/unidade.js` — `foto_url` é key de objeto (S3/SeaweedFS), não URL, deliberadamente sem validação de formato |
| PK de `vendedores` colidia entre empresas | PK era `codigo_vendedor_omie` (não único entre unidades) | Trocada para `id` uuid — comentário no model documenta o bug antigo |
| Meta Individual 7-18× maior | Meta global dividida 2× por unidade | Corrigido (contrato específico) |
| Backfill de `vendedores.id_funcionario` | — | Já rodou. |
| Chave composta em `PUT`/`DELETE /blacklist_pedidos` | — | Resolvido junto com o bug de criação em `blacklist_pedidos` (ver acima) |

## Pendentes reais remanescentes

| Item | Status |
|---|---|
| Paginação por pedido (não por linha crua) em `/vendas_planilha` | Ainda não implementado — só ordenação foi endereçada, não a paginação por família |
| `fechamento_manual` | ✅ **Investigado e fechado em 22/09/2026 — ver [[AV-Hub-Fechamento-Manual-Investigacao]]**: CRUD completo funcionando, confirmado em runtime (16 registros reais, jan-ago/2026, zero registros desde set/2026 — bate com a regra documentada no código). Achado: a "prioridade pontual do manual sobre o automático" que [[AV-Hub-Modulos]] descrevia **não existe no backend** — os dois caminhos (`fechamento_manual` e `fn_dashboard_mensal_*`) são independentes no código; se essa prioridade existe, só pode estar no frontend. |
| Relação produto↔fornecedor N:N | ✅ **Investigado e fechado em 22/09/2026 — ver [[AV-Hub-Views-Compras-Investigacao]]**: as views de Compras (`vw_catalogo_de_produtos`, `vw_fornecedores_com_produtos`, `vw_historico_precos`, `vw_todos_os_fornecedores`) **não cobrem** o futuro módulo de Compras — confirmado em runtime (3 das 4 rotas retornam 500, bug de schema `negocio` vs. `core_compras`) e a tabela-fonte (`core.parceiros_produtos`) tem zero linhas mesmo com o bug corrigido. **Decisão do Nathan (22/09): o conteúdo do schema `core_compras` foi apagado pelo Gustavo** — confirmado o mesmo dia. O schema continua se chamando `core_compras`; só as tabelas/views de dentro dele vão ser refeitas de forma estruturada (formato ainda não definido). Os 4 endpoints GET abaixo agora apontam para um `core_compras` que não tem mais as views antigas (nem tem `negocio`, que nunca existiu) — precisam ser removidos do código, não só deixados quebrados. Achado à parte: `core.parceiros_produtos`/`POST /parceiros_produtos` (CRUD de cotação manual, schema `core`, não afetado por esta decisão) já existe e funciona, sem bug — candidato a alimentar o Orçamento no lugar do JSON mockado, mas ninguém usa ainda. |
| **`codigo_pedido_compra_omie` como `integer` — risco de tipo (achado 21/09)** | Confirmado com o Nathan: o Omie manda esse identificador como **string**, não como número. A coluna real em `core_vendas_faturamento.pedidos_compras.codigo_pedido_compra_omie` é `integer` (o próprio comentário no model já alertava sobre risco de overflow). Guardar um valor que a fonte trata como string numa coluna `integer` pode truncar/quebrar em zero à esquerda ou valores não-numéricos — risco real, não hipotético. Avaliar antes de habilitar sync de compras (contrato SQL 004, ver G-09 em [[Perguntas-em-Aberto-Consolidadas]]). |
| **`POST /usuarios/{id}/favoritos` quebrado — bug confirmado e corrigido (achado + fix 22/09)** | Reproduzido em runtime: `400 {"detail":"Campo obrigatório não informado: id"}` em toda tentativa de favoritar. Causa: `src/models/usuario_favorito.js` declarava `id` como `primaryKey` sem `defaultValue` nem `allowNull: true` — o Sequelize validava o campo como obrigatório antes de deixar o Postgres gerar o `DEFAULT uuidv7()`. **Corrigido em 22/09/2026** com `defaultValue: literal("uuidv7()")` (mesmo padrão de `estoque_saldo.js`), testado (`POST`/`GET`/`DELETE`, idempotência) — commit na branch local `fix/usuario-favorito-id-default`, ainda não enviado ao remoto. Ver [[AV-Hub-Favoritos-Clientes-Inativos-Investigacao]]. |

## Pontos a considerar no roadmap do Portal do Vendedor

✅ **Investigado e fechado em 22/09/2026 — ver [[AV-Hub-Favoritos-Clientes-Inativos-Investigacao]]**, testado em runtime contra a API e o dump de produção:
- **`clientes_inativos`** — funciona de ponta a ponta (`200`, 652 clientes com ≥90 dias sem comprar, dado real). "Cliente inativo" (extra 8.9), antes avaliado como caro (N chamadas por mês), **não é**: é uma única rota paginada, já pronta. Só falta frontend.
- **`usuarios_favoritos`** — `GET`/`DELETE` prontos, mas **`POST` está genuinamente quebrado**: `400 {"detail":"Campo obrigatório não informado: id"}` em toda tentativa, confirmado por teste direto. Causa raiz no model (`src/models/usuario_favorito.js`): o campo `id` não tem `defaultValue` nem `allowNull: true`, e o Sequelize barra a criação antes de deixar o Postgres gerar o `uuidv7()` (que é a intenção documentada no próprio comentário do código). Não é mais "precisa de tabela nova" (extra 8.10) — é um bug pequeno e pontual, tabela e escrita conceitual já prontas.

Ressalva importante: `pedidos_vendas_status_historico` **não** entra nessa lista de "baixo custo, já existe" — é o **histórico vindo do Omie via pipeline** (polling, granularidade grossa dos status do Omie), não um log de transições internas. Não satisfaz o requisito de "histórico de status do pedido" no nível granular que o fluxo detalhado item a item exige (ver [[Fluxo-Detalhado-Pedido-Item]]) — é necessário um histórico muito mais robusto, mostrando toda transição real (PCP, OS/OP, qualidade), que essa tabela não cobre.

## Ver também
- [[AV-Hub-Vendas-Reconciliacao]]
- [[AV-Hub-Arquitetura-BFF]]
- [[AV-Hub-Portal-Vendedor-Plano]]
- [[AV-Hub-Comissao-Modulo]]
- [[Decisoes-Chave-ERP]]
- [[AV-Hub-Views-Compras-Investigacao]]
- [[AV-Hub-Fechamento-Manual-Investigacao]]
- [[AV-Hub-Favoritos-Clientes-Inativos-Investigacao]]
