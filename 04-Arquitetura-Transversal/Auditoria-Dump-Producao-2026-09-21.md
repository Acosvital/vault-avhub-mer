---
tags: [erp-acos-vital, auditoria, banco-de-dados, contratos, status]
criado: 2026-09-21
atualizado: 2026-09-21
---

# Auditoria: dump de produção (21/09) vs. vault vs. código real

> **Pergunta que esta nota responde: "o vault está 100% atualizado?"** Não — achou 1 desatualização importante (contratos aplicados sem o vault saber) e 1 achado de código morto já confirmado e sem urgência (schema `negocio`). O resto do modelo de dados documentado no vault (av-hub e app-pcp) **bate com a realidade**. Esta nota é o depara ponto a ponto; as correções de status já foram aplicadas em [[Indice-Contratos]] e [[Onde-Estamos]].
>
> **Atualização (21/09, mesma tarde):** o achado da seção 4 (`negocio` vs. `core_compras`) foi confirmado pelo Nathan em conversa — o schema `negocio` **não existe mais** de fato, os 8 endpoints que apontam pra ele são código morto conhecido (não removido ainda), sem uso real hoje. Não é bug de produção ativo, é limpeza de dívida técnica pendente, sem urgência. Rebaixado de "risco crítico" para item de backlog — ver seção 4 atualizada.

**Fontes cruzadas:**
- `dump-avhub_prd_db-202609210741.sql` — dump **schema-only** (só DDL, sem `COPY`/dados) do banco `avhub_prd_db`, `pg_dump 18.3`/Postgres 18.6, gerado **21/09/2026 07:41** (mesmo dia desta auditoria).
- `api-acos-vital` (Node/Express + Sequelize) — 82 definições de model lidas por completo (`src/models`, `src/schemas`, `src/services`).
- `api-pcp` (NestJS + Prisma) — schema Prisma completo (22 models, `prisma/models/*.prisma`) + inventário dos ~25 módulos NestJS + últimas 8 migrations.
- Vault: `Indice-Contratos.md` + os 8 arquivos de contrato, `Schema-Postgres-Multi-Dominio.md`, `App-PCP-Modelo-Producao.md`, `App-PCP-Backend-Producao.md`, `Onde-Estamos.md`.

---

## 1. Resumo executivo

1. **Achado crítico — 5 de 6 contratos SQL e o contrato de API 001 já estão aplicados em produção**, mas [[Indice-Contratos]] e [[Onde-Estamos]] diziam "nenhum aplicado ainda". Isso já foi corrigido nas duas notas (ver seção 2). Isso muda o que resta fazer na S1 do cronograma — ver seção 5.
2. **Confirmado (não é mais achado em aberto) — schema `negocio` é código morto.** O código do av-hub declara 8 endpoints GET (`/catalogo_de_produtos`(`/:id`), `/fornecedores_com_produtos`(`/:id`), `/historico_precos`, `/todos_os_fornecedores`(`/:id`)) sobre 4 views no schema Sequelize `"negocio"`, que não existe no dump — só `core_compras` existe, com as mesmas 4 views + `produtos_compras`. **Confirmado pelo Nathan (21/09): `negocio` de fato não existe mais; esses endpoints são código morto conhecido, sem uso real, a ser limpo depois.** Não é bug de produção ativo — é item de backlog de limpeza técnica, sem urgência. Ver seção 4.
3. Fora esses dois pontos, **o modelo de dados que o vault já documenta bate com o código real** — tanto do lado av-hub (schemas, tabelas, colunas, padrões de auditoria/soft-delete) quanto do lado app-pcp/MES (Pedido, ItemParcial, Setor, Fábrica, Roteiro, RBAC, etc.).
4. **O módulo de Estoque continua 100% não construído** — nem no banco do av-hub (schema `core_estoque` existe mas está vazio) nem no `api-pcp` (nenhum model Prisma de material/lote/recebimento/depósito). O vault já dizia isso corretamente.

---

## 2. Contratos — depara completo

| Contrato | O vault dizia (17/09) | O dump/código mostram (21/09) | Status corrigido |
|---|---|---|---|
| [[001-Parceiros-Dados-Fiscais]] | proposta | `core.parceiros` **já tem** todas as colunas propostas (`inscricao_estadual/municipal/suframa`, `optante_simples_nacional`, `contribuinte_icms`, `cnae`, `tipo_atividade`, `pessoa_fisica`, `produtor_rural`, `cidade_ibge`, `valor_limite_credito`, `bloquear_faturamento`, `inativo`); `core.parceiros_dados_bancarios` e `core.parceiros_endereco_entrega` **já existem** como tabelas 1:1 (FK CASCADE), com os campos propostos (`chave_pix`, `codigo_banco` etc.) — e os models Sequelize correspondentes (`ParceiroDadosBancarios`, `ParceiroEnderecoEntrega`) já existem e estão em uso | **aplicada** |
| [[002-Estoque-Saldo]] | proposta | `core.estoque_saldo` **já existe**, colunas batem quase exatamente com o DDL proposto (`saldo/fisico/reservado/pendente numeric(14,3)`, `cmc numeric(14,4)`, `preco_unitario numeric(14,2)`, `data_posicao`, auditoria/soft-delete); model Sequelize `EstoqueSaldo` confirma **"foto atual" (upsert 1 linha por empresa+produto+local)** — a pergunta em aberto do contrato ("foto vs. série histórica") já foi resolvida na prática pela implementação | **aplicada** (pergunta "foto vs. série" resolvida = foto) |
| [[003-Pedidos-Vendas-Frete-Parcelas]] | proposta | `core_vendas_faturamento.pedidos_vendas` já tem `tipo_desconto_pedido`/`perc_desconto_pedido`/`valor_desconto_pedido`; `pedidos_vendas_frete` (1:1) e `pedidos_vendas_parcelas` (1:N) já existem com os campos propostos (`modalidade_frete`, `codigo_transportadora`, `numero_parcela`, `data_vencimento`, `valor_parcela` etc.) | **aplicada** |
| [[004-Pedidos-Compras]] | proposta | `core_vendas_faturamento.pedidos_compras` e `pedidos_compras_itens` já existem, campos batem com o proposto | **aplicada — com o risco do contrato ainda não resolvido**: `numero_item_omie` continua nullable e **sem índice único** (o próprio comentário no código alerta para risco de duplicação em resync) — a pergunta "id estável de item de compra" (DEC-7/G-08) segue em aberto |
| [[005-Locais-Estoque]] | proposta | `core.locais_estoque` já existe, campos batem (`disponivel_ordem_producao/consumo_op/remessa/venda`, `codigo_cliente_omie`, `considera_sugestao_compra` etc.) | **aplicada — pergunta em aberto sobre FK opcional para o futuro `deposito` do Estoque segue sem resposta** (não é possível responder por dump, é decisão de arquitetura) |
| [[006-Pedidos-Vendas-Valor-Devolucao]] | frontmatter já dizia `invalidado`, mas o índice ainda listava "proposta" (inconsistência I-02 já registrada pelo próprio vault) | dump confirma: **não existem** as colunas propostas (`codigo_devolucao_omie`, `valor_devolucao`, `devolucao_consultada_em`) em `pedidos_vendas` | **invalidado** (inconsistência do índice corrigida) |
| [[001-Produtos-Parceiros-Filtro-Incremental]] (API) | proposta | `GET /produtos` e `GET /parceiros` **já implementam** `?alterado_desde=` (`src/routes/produtos.js:185-234`, `parceiros.js`), com exatamente o comportamento documentado no contrato (ISO 8601, valor inválido ignorado, soft-delete não detectável — mesma ressalva do contrato) | **aplicada** |
| [[002-Material-Alias-Omie-MES]] (API) | proposta | Nenhuma menção a `material_alias_omie` em `api-pcp` (grep vazio no repo inteiro) — Estoque/MES ainda não tem esse endpoint nem tabela | **segue proposta** (correto, sem mudança) |

**Conclusão da seção:** dos 8 contratos, **6 já estão na prática aplicados** (5 SQL + 1 API), 1 foi formalmente invalidado (006) e só 1 (API 002, que depende do módulo de Estoque ainda não construído) segue genuinamente como proposta. **[[Indice-Contratos]] e [[Onde-Estamos]] foram atualizados para refletir isso** (ver rodapé desta nota para o que mudou).

---

## 3. Schema por schema — av-hub (auth/core/core_vendas_faturamento/etc.)

O dump tem **12 schemas de negócio + `public`** (só extensões), 74 tabelas, 18 views. Todos os schemas que o vault já cita (`auth`, `core`, `core_vendas_faturamento`, `core_comissionamento`, `core_aprovacao_de_vagas`) foram confirmados tabela a tabela contra o código Sequelize, sem divergência de estrutura relevante. Achados que valem registrar (nenhum é "vault errado", são reforços/atualizações menores):

- **`core_comissionamento`** (simulador de comissão — blacklist, bloqueio, regra fixa, simulação 5-estados) confirmado igual ao que o vault já descrevia em `AV-Hub-Comissao-Modulo.md`. Achado novo: esse schema **não está** no bloco `CREATE SCHEMA IF NOT EXISTS` de `src/app.js` — os outros 5 schemas usados por models são criados automaticamente no boot, este não. Não é um problema de modelagem, é uma nota de risco operacional (documentar em `AV-Hub-Bugs-Catalogo.md` se ainda não estiver).
- **`core_mapas`** — schema criado no boot mas sem nenhuma tabela própria, só 2 views de geolocalização (`mapa_unidades`, `vw_todos_os_clientes`). Confirmado, sem impacto de modelagem.
- **`core_estoque`** — existe no dump (`CREATE SCHEMA core_estoque`) mas **100% vazio** (zero tabelas/views/functions). É reserva de nome, não uso ativo — o saldo/local de estoque de hoje vive em `core.estoque_saldo`/`core.locais_estoque`. Não confundir com o Estoque do MES (banco separado, ainda não criado).
- **Padrões confirmados e válidos para replicar no Estoque/MES** (reforça [[Decisoes-Chave-ERP]]): `codigo_empresa` uuid como padrão de multi-tenant em quase toda tabela; soft-delete via `deleted_at`/`deleted_by` com índices únicos **parciais** (`WHERE deleted_at IS NULL`) em vez de UNIQUE simples; colunas de auditoria `created_by`/`updated_by`/`deleted_by` como FK `ON DELETE SET NULL` para `auth.usuarios`; ausência deliberada de FK entre dados sincronizados de forma independente (documentada em comentário em pelo menos 6 tabelas diferentes).

---

## 4. `negocio` vs. `core_compras` — código morto confirmado (não é mais achado em aberto)

**Evidência:**
- Dump de produção (21/09/2026 07:41): schema `core_compras` existe, contém `produtos_compras` (1 tabela) + as 4 views `vw_catalogo_de_produtos`, `vw_fornecedores_com_produtos`, `vw_historico_precos`, `vw_todos_os_fornecedores`. **Não existe schema `negocio` em lugar nenhum do dump.**
- Código (`api-acos-vital/src/services/vw_catalogo_de_produtos.js:38`, `vw_historico_precos.js:16`, `vw_fornecedores_com_produtos.js:28`, `vw_todos_os_fornecedores.js:19`): todos os 4 models Sequelize declaram `schema: "negocio"`.
- `src/app.js` agrupa esses 4 imports sob o comentário `// core_compras (refatorar: unir com core_vendas_faturamento...)` — ou seja, **o próprio código já está confuso sobre o nome**: o comentário diz uma coisa, o `schema:` do model diz outra, e nenhum dos dois bate 100% com o dump (o dump tem `core_compras`, não `negocio`).

**Resolução (confirmada pelo Nathan em conversa, 21/09):** o schema `negocio` de fato não existe mais — provavelmente hipótese 1 (produção migrou para `core_compras`, código nunca foi atualizado/removido). Os 8 endpoints GET que dependem dele (`/catalogo_de_produtos`(`/:id`), `/fornecedores_com_produtos`(`/:id`), `/historico_precos`, `/todos_os_fornecedores`(`/:id`) — ver `src/app.js:1665-1668`) são **código morto conhecido, não utilizável hoje, sem uso real** — não é um bug afetando alguém agora, é dívida técnica que "será mexida depois". Sem ação imediata necessária; registrar como item de limpeza (remover as 4 rotas + 4 services + os 4 imports em `app.js`, ou migrar de fato pra `core_compras` se algum consumidor real aparecer) em [[AV-Hub-Bugs-Catalogo]] ou equivalente, sem prioridade no cronograma atual.

---

## 5. app-pcp / api-pcp (MES) — confirmação

Modelo Prisma (22 models) lido por completo e comparado com [[App-PCP-Modelo-Producao]] / [[App-PCP-Backend-Producao]]: **sem divergência relevante**. Confirmações específicas:

- `Pedidos.sistema` (enum `SistemaOrigem`: OMIE/TOTVS/MANUAL) e `ItensPedido.idOmie` opcional — já documentados no vault, confirmados no schema e nas migrations mais recentes (`20260826112507_add_pedido_sistema_origem`, `20260826180141_pedido_itens_omie_fields_optional`).
- `PerfilSetor` (`podeVisualizar`/`podeAtuar`) — peça central do RBAC por setor (trava C2/C3 no cronograma) — confirmado como modelo novo (migration `20260828173037_add_perfil_setor`, a mais recente do repo), ainda sem nenhum controller de domínio aplicando os guards (RBAC "pronto mas não ligado", como o vault já registrava).
- `Fabrica` **sem** vínculo a `codigo_empresa`/filial — confirmado, DEC-1 segue realmente bloqueante, como o vault descreve.
- **`TODO.md` do `api-pcp` não é um roadmap PCP→MES** — é uma lista de revisão de código de 2026-08-21 (race conditions em `ItemParcial` — resolvidas em 24/08; `ItensPedido.inativo` write-only — resolvido em 24/08; RBAC não aplicado — adiado de propósito). Não há nenhuma menção textual a "MES" em `README.md`/`TODO.md`/`src/`. Vale registrar isso em [[MES-Arquitetura-Decisoes]] se essa nota assumir que existe um roadmap formal PCP→MES no repositório — ele não existe ainda como documento, só como direção de produto.
- **Nenhum model de Estoque** (material, lote, recebimento, depósito, movimento_estoque etc.) existe no schema Prisma — confirma que [[PRD-Estoque-Visao-Geral]] segue 100% no papel, como o vault já afirmava.

---

## 6. O que isso muda no roadmap

1. **S1 do cronograma já não precisa da tarefa B3 ("Aplicar contratos SQL 001 e 005")** como estava escrita — 001 e 005 (e também 002, 003, 004) já estão aplicados. A capacidade do Gustavo alocada para B3 fica livre uma semana antes do previsto. Ver ajuste em [[Onde-Estamos]] seção 5.
2. **B4 ("API alterado_desde em produtos e parceiros") também já está pronta** — mesma liberação de capacidade.
3. **O achado da seção 4** (`negocio`/`core_compras`) não muda o roadmap — é código morto confirmado, sem urgência, vira item de backlog de limpeza quando sobrar tempo.
4. **O restante do cronograma (Fase 0 → A → B → C, marcos M2 a M6) continua válido sem alteração** — ele nunca dependeu da aplicação dos contratos SQL do av-hub (isso é infraestrutura de leitura/projeção pro Estoque, não bloqueia a criação do schema Prisma do Estoque em si, que é D1). O trabalho pesado que falta é **inteiramente do lado do MES/Estoque** (`api-pcp`/`app-pcp`), que está exatamente onde o vault dizia: schema Prisma zero, PRD pronto, DEC-1/DEC-4/DEC-7 ainda travando o início.
5. Com B3/B4 liberadas mais cedo, considerar adiantar para a S1 alguma tarefa de S2 que dependia de Gustavo (ver [[Cronograma-2-Meses]] seção 5) — decisão de priorização cabe ao Nathan/Gustavo, não está sendo feita aqui.

---

## Ver também
- [[Indice-Contratos]] — status corrigido nesta auditoria
- [[Onde-Estamos]] — seções 3, 5 e 6 atualizadas com os achados desta auditoria
- [[Schema-Postgres-Multi-Dominio]]
- [[App-PCP-Modelo-Producao]]
- [[Perguntas-em-Aberto-Consolidadas]] — I-02 (inconsistência do contrato 006) resolvida por esta auditoria
