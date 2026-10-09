---
tags: [contrato-logica, contrato-api, vendas, permissoes, pipeline]
criado: 2026-10-09
atualizado: 2026-10-09
status: implementada-no-codigo
---

# Contrato 45 — Pedido de venda manual (só administrador; convivência com o pipeline)

> **Status: `implementada-no-codigo`. Produção NÃO verificada.** Lido em 09/10/2026 na `develop` da `api-acos-vital` (`origin/develop` = `dee35b0`; a cópia local está 2 commits atrás, por isso tudo abaixo vem de `git show origin/develop:…`), no pipeline `omie-elt-pipeline` (`master` `d2886bf`) e no front `00 - HUB` (`996e320`). Produção só pelo dump de 07/10 ([[Auditoria-Dump-Producao-2026-10-07]]), que **não** traz o corpo de triggers nem o mapa de rotas deste assunto. Decisões da rodada: [[Registro-de-Decisoes-2026-10-07]]. Origem deste contrato: item "Contrato novo para pedido de venda manual" da [[Auditoria-Pente-Fino-2026-10-08]].
>
> **Por que existe.** O pedido de venda manual está no código da API e na tabela de telas, mas **não tinha contrato no vault**. É o contrato irmão do [[29-Notas-Fiscais-Manuais-So-Admin]] (mesmo desenho) e da regra "sem chave de ambiente" do [[38-Regras-Sem-Chave-de-Ambiente]].
>
> **🔴 Divergência de numeração.** Os comentários do código chamam este assunto de "**Contrato 30**" (`pedidos_vendas.route.js:29,135,237,245,345,576,642,730`; `pedidoVendaManual.js:5`; `pedidos_vendas.model.js:4,181`; `acessoConfig.js:33`; swagger de pedidos_vendas e de notas_fiscais; `notas_fiscais.route.js:262`). **O 30 do vault é outro**: [[30-Compras-Pedido-Omie-PDF-Completo]] (PDF do pedido de compra do Omie), que o próprio código também chama de "Contrato 30" em `pedidos_compras.route.js:97,185,305`. O mesmo número tem dois assuntos no código. A auditoria do dump já avisava que a numeração do DBA nos DDL não coincide com a do vault. **Proposta (🟡, Gustavo/DBA aplicam):** os comentários, o swagger e a migration 030 passam a citar "contrato 45 do vault" para o pedido manual e deixam o "contrato 30" só para o PDF do pedido de compra. Esta nota registra o vínculo para quem cruzar código e vault.

## 1. Finalidade e quem pode usar

- **Para quê.** Cadastrar um pedido de venda que **não está no Omie**. Ele entra em `vw_vendas_base` / `vw_vendas_planilha` e em tudo que lê delas (dashboard mensal, rankings, ritmo da meta, listagem), **classificado como líquido**, sem passar pela blacklist nem pela cascata G1–G6 (`pedidos_vendas.swagger.json:683`). Só o **cabeçalho**: sem parcelas e sem itens (`pedidoVendaManual.js:11`). Uma NF manual pode apontar para ele (`codigo_pedido_omie` negativo: `notas_fiscais.route.js:258-266`).
- **Quem pode.** Só quem tem a permissão na tela **`pedidos-vendas-manuais`** (`TELA_PEDIDOS_MANUAIS`, `pedidoVendaManual.js:18`): `pode_criar` (POST), `pode_editar` (PUT/PATCH), `pode_deletar` (DELETE). O texto da API diz "só o administrador" (`pedidoVendaManual.js:211,219`), mas **quem é administrador é dado de banco** (quais perfis têm a permissão); o código não nomeia o perfil. Produção: **não verificado** quais perfis têm essa tela (🔴, §8).
- **Trava fixa.** `pedidosManuaisExigirPermissao = () => true` (`acessoConfig.js:65`; era `PEDIDOS_MANUAIS_EXIGIR_PERMISSAO`, saiu no [[38-Regras-Sem-Chave-de-Ambiente]]). Não há mais chave: a trava vale em todo ambiente.
- **Como a permissão é conferida** (`barrarSemPermissaoPedidoManual`, `pedidoVendaManual.js:204-225`): o usuário é o do token (`req.usuario.id`) **ou**, sem token, o autor do corpo (`created_by` / `updated_by` / `deleted_by`, só se for UUID). Sem usuário: **403 `USUARIO_NAO_INFORMADO`**. Com usuário sem a ação: **403 `SEM_PERMISSAO`**. Ambos devolvem `exige_uma_de: ["pedidos-vendas-manuais:<flag>"]`. Vale também sem token (mesma regra da nota manual, contrato 29).
- 🟡 **Limite herdado do 29:** sem token, o "autor do corpo" é só um UUID que o chamador diz ser; quem tem a `x-api-key` e conhece o UUID de um admin consegue operar. É a mesma brecha do L6 (separar chaves de serviço, 🔴 Gustavo). Não nova, mas vale aqui.
- O swagger diz que, com token, o mapa `auth.rotas_telas` exige a mesma permissão (`pedidos_vendas.swagger.json:683`). **Se as rotas `/pedidos_vendas/manual*` estão em `auth.rotas_telas` em produção: não verificado** (o dump lista 371 linhas e 58 slugs, sem detalhar estas). Com `PERMISSOES_ROTA_MODO` fixo em `exigir` ([[Registro-de-Decisoes-2026-10-07]] item 8), 🟡 rota sem mapa daria 403 a quem manda token.

## 2. Identidade do pedido

| Item | Regra | Fonte |
|---|---|---|
| `manual` | Sempre `true` no cadastro; o corpo com `manual` diferente de `true` dá 400. Não muda depois de gravado (`trg_pedidos_vendas_manual_imutavel`, citado em comentário) | `pedidoVendaManual.js:101-103`; `pedidos_vendas.route.js:181-182` (model), `:237-243` |
| `codigo_pedido_omie` | **Negativo**, gerado pela sequence `core_vendas_faturamento.seq_pedidos_vendas_manual` (`nextval`): -1, -2… Nunca vem do cliente (400). Cadastro recusado pelo banco consome o código: pode haver buraco | `pedidos_vendas.route.js:404-407,412`; `pedidoVendaManual.js:87-89` |
| `numero_pedido` | `MAN-` + código sem o sinal (-1 → `MAN-000001`), **gerado por trigger do banco** (a rota deixa vazio). Único entre unidades. Nunca vem do cliente (400). Não é reaproveitado | `pedidos_vendas.route.js:409`; `pedidoVendaManual.js:9,90-92`; swagger `:683,850` |
| `sequencial` | `null` (sem parcelas); recusado se vier no corpo | `pedidos_vendas.route.js:413`; `pedidoVendaManual.js:37` |
| `codigo_empresa` | UUID da unidade, **obrigatório** no cadastro, **não muda** depois (400). O código negativo é único entre unidades (uma sequence só), por isso `?codigo_empresa=` é opcional nas rotas `/manual/{codigo}` | `pedidoVendaManual.js:143-145`; `pedidos_vendas.route.js:361-376,435-437` |
| Autoria | `created_by` e `updated_by` = token ou `created_by` do corpo; sem nenhum dos dois, 400 | `pedidos_vendas.route.js:398-417` |
| Exclusão | Lógica (`deleted_at` + `deleted_by` num só `UPDATE`); o pedido continua no banco e sai dos dashboards. NF que apontava para ele continua apontando e **segue contando no faturamento** | `pedidos_vendas.route.js:465-471`; swagger `:850` |

No banco existem (dump de 07/10, [[Auditoria-Dump-Producao-2026-10-07]] §9 e a linha 56): a sequence `seq_pedidos_vendas_manual`, a tabela `pedidos_vendas_manuais_historico` e a tela `pedidos-vendas-manuais`. **Os triggers** `trg_pedidos_vendas_manual_validar`, `_imutavel` e `_sem_delete` (migration 030 do DBA) **não estão em nenhum `.sql` do vault nem do repo da API** (o repo não tem `.sql`); existência e corpo em produção: **não verificados**.

## 3. As rotas (`/pedidos_vendas/manual`)

Todas em `pedidos_vendas.route.js` (`origin/develop`). A validação de formato é de `validarPedidoManual` (`pedidoVendaManual.js:81-194`); as regras de negócio ficam no trigger `trg_pedidos_vendas_manual_validar` (`pedidoVendaManual.js:12-15`).

### 3.1 `POST /pedidos_vendas/manual` (`:391-424`)

- **Permissão:** `pode_criar` (`:393`).
- **Campos aceitos** (`pedidoVendaManual.js:20-24`): `codigo_empresa`, `data_inclusao`, `hora_inclusao`, `data_previsao`, `codigo_cliente`, `codigo_vendedor_omie`, `codigo_categoria`, `codigo_projeto`, `numero_contrato`, `obs_venda`, `valor_total_pedido`, `etapa`, `created_by`.
- **Obrigatórios** (`:25-28`): `codigo_empresa`, `data_inclusao`, `hora_inclusao`, `valor_total_pedido`, `codigo_cliente`, `codigo_vendedor_omie`.
- **Recusados com 400** (`NAO_ACEITOS`, `:36-43`; só se vierem com valor, `:105-110`): `sequencial`, `situacao`, `autorizado`, `denegado`, `faturado`, `cancelado`, `devolvido`, `devolucao_parcial`, `encerrado`, `data/hora_faturamento`, `data/hora_cancelamento`, `data/hora_encerramento`, `motivo_encerramento`, `usuario_encerramento`, `tipo_desconto_pedido`, `perc_desconto_pedido`, `valor_desconto_pedido`, `codigo_devolucao_omie`, `valor_devolucao`. Recusar em vez de ignorar evita a tela achar que gravou "faturado".
- **Normalizações e validações** (400): texto sem espaço nas pontas e tamanhos máximos (`codigo_cliente` 60, `codigo_vendedor_omie` 11, `codigo_categoria` 100, `codigo_projeto` 60, `numero_contrato` 20, `obs_venda` 4000: `:29-32,128-141`); `codigo_empresa` e `created_by` UUID (`:143-145,186-191`); `data_inclusao`/`data_previsao` datas reais `AAAA-MM-DD` (`:147-160`); `hora_inclusao` `HH:MM` ou `HH:MM:SS`, normalizada para `HH:MM:SS` (`:162-166`); `valor_total_pedido` com até 2 casas e **maior que zero** (`:168-173`); `etapa` numérica de 1 a 99, **`0` recusada** ("é orçamento: o pedido não entraria nas vendas", `:175-184`).
- **Regras do banco** (trigger, texto do swagger `:683`; **não verificado em produção**): cliente e vendedor cadastrados na mesma unidade; etapa existente na unidade e diferente de 0; data não futura; valor > 0. 🟡 Como o trigger responde (400? 500?) depende do `handleSequelizeError`, que não li a fundo.
- **Respostas:** **201** com o pedido e `nome_criado_por` / `nome_alterado_por` / `nome_excluido_por` (`buscarPedidoComNomes`, `:385-389`); **400** formato, campo recusado, ou `created_by` ausente sem token (`:399-403`); **403** permissão (§1); **409** número repetido (`SequelizeUniqueConstraintError`, `:352-355`; só se alguém gravou `MAN-xxxxxx` por fora); erro de FK em `codigo_empresa` pelo `handleSequelizeError` (`:357`).

### 3.2 `PUT` e `PATCH /pedidos_vendas/manual/{codigo}` (`:426-455`)

- Mesma função para os dois: **alteram só os campos enviados** (`parcial: true`). Permissão `pode_editar` (`:429`).
- `{codigo}` precisa ser inteiro negativo (`/^-\d{1,18}$/`), senão **400** (`:365-368`); `?codigo_empresa=` se vier tem de ser UUID, senão **400** (`:370-374`); não achou pedido manual ativo: **404** "Pedido de venda manual não encontrado" (`:378-380`). Pedido já excluído também dá 404 aqui (`paranoid: true`).
- **400:** corpo não objeto (`:430`); `codigo_empresa` diferente do gravado (`:435-437`); `numero_pedido` ou `codigo_pedido_omie` diferente do gravado (iguais passam, porque a tela reenvia o objeto inteiro: `pedidoVendaManual.js:94-99`); campo da lista de recusados; obrigatório enviado vazio (`:116-118`); opcional vazio vira `null` e limpa o campo (`:126`); nenhum campo para alterar (`:441-443`); `updated_by` ausente sem token (`autorDaOperacao`, `:229-236`).
- **200** com o pedido e os nomes. **403** permissão. **409** unicidade (`:352`).

### 3.3 `DELETE /pedidos_vendas/manual/{codigo}` (`:457-489`)

- Permissão `pode_deletar` (`:459`); `deleted_by` obrigatório sem token (**400**, `:462-463`); **404** se não achou (`:466`, `:477-479`). **200** `{ detail: "Pedido de venda manual excluído", codigo_pedido_omie, numero_pedido, codigo_empresa }`.
- Exclusão **lógica** num `UPDATE` só (`deleted_at = now(), deleted_by`), porque o trigger de autoria exige `deleted_by` e o histórico registra quem excluiu (`:465-471`).

### 3.4 `GET /pedidos_vendas/manual/{codigo}/historico` — ver §4.

### 3.5 Rotas genéricas e a sincronização

- `PUT`, `PATCH` e `DELETE /pedidos_vendas/{codigo_pedido_omie}` **recusam pedido manual com 403 `PEDIDO_MANUAL_ROTA_PROPRIA`** (`recusarManualNaGenerica`, `:266-273`; chamadas em `:690,708,732`), porque a trava é fixa. Antes da regra fixa havia um caminho sem trava (`ajustarEdicaoManual`, `:259-264`), hoje **código morto** (🟡: o `if (pedidosManuaisExigirPermissao())` é sempre verdadeiro; limpeza do código é do Gustavo).
- As genéricas ignoram `manual` no corpo (`pickEdicao`, `:239-243`).
- **A API barra `manual = true` vindo da sincronização:** `POST` e `PUT /pedidos_vendas` (upsert da pipeline) dão **400** se `codigo_pedido_omie` não for inteiro positivo ("use POST /pedidos_vendas/manual") ou se `manual` vier `true`/`"true"` (`recusaUpsertManual`, `:249-257`; usada em `:305,333`). O upsert nunca "captura" um manual: se o payload cair num manual existente (mesmo `codigo_empresa` + `numero_pedido` + `sequencial`), é **409** (`ConflitoPedidoManual`, `:140-147,310,338`).
- `DELETE /pedidos_vendas/lote` **nunca apaga manual**: separa os manuais e os devolve em `codigos_manuais_ignorados`; o `destroy` ainda filtra `manual: false` (`:642-660,667`). Isso protege a rota da API, **não** o SQL direto do pipeline (§5).
- `GET /pedidos_vendas`: `?manual=true|false` (outro valor: 400, `:528-530,562`); `?com_deletados=true` traz os excluídos (`:577`); `?numero_pedido=` é **busca por trecho** (`iLike %…%`, `:546`); `?codigo_cliente=` também por trecho (`:551`); ordenação também por `nome_criado_por`, `nome_alterado_por`, `nome_excluido_por` (`:34-40`). 🟡 Uma busca por `MAN-0000` traz vários; quem precisa de um pedido exato deve conferir igualdade (mesmo risco que o item 12 da [[Auditoria-Pente-Fino-2026-10-08]] aponta na NF).

## 4. Histórico

`GET /pedidos_vendas/manual/{codigo}/historico` (`:491-515`) lê `core_vendas_faturamento.pedidos_vendas_manuais_historico`, **uma linha por operação, da mais antiga para a mais nova**, com `id`, `operacao`, `numero_pedido`, `alteracoes`, `alterado_por`, `nome_alterado_por`, `created_at`. `alteracoes` traz cada campo que mudou como `{ "de": …, "para": … }` (no cadastro, `de` é `null`). Funciona também para pedido excluído (`paranoid: false`). **Quem grava é o banco** (migration 030, swagger `:936`), não a API. Resposta: `{ codigo_pedido_omie, numero_pedido, codigo_empresa, historico }`.

- 🟡 Esta rota **não chama** `barrarSemPermissaoPedidoManual`: leitura só depende do mapa `auth.rotas_telas` (se existir) e da `x-api-key`. Decisão pendente (§8, Nathan): ler histórico exige `pode_visualizar`?
- Existência da tabela em produção: **sim** (dump de 07/10, §9). Conteúdo e triggers que a alimentam: **não verificados**.

## 5. Convivência com o pipeline Omie

**Colunas protegidas.** `PROTECTED_COLUMNS['core_vendas_faturamento.pedidos_vendas'] = ['manual']` (`protectedColumns.ts:55`): o upsert da pipeline nunca escreve `manual`. Ver [[Colunas-Protegidas]] e [[Pedidos-de-Venda]]. Consequência: a pipeline não transforma nem desfaz pedido manual por esse caminho. A chave de conflito do upsert é `(codigo_empresa, codigo_pedido_omie)` (`pedidosVendas.ts:74`); como o código do manual é negativo e o do Omie positivo, 🟡 não colidem.

### 🔴 Pendência Gustavo — risco crítico do `exclusionSync`

- `exclusionSync.ts:99-106` lê **todos** os `pedidos_vendas` da filial e da janela com `deleted_at IS NULL`, **sem filtrar `manual`**. Em seguida monta `excluidos` = tudo que não está na lista de códigos ativos do Omie (`:109`). O pedido manual **nunca está no Omie** (código negativo), logo **entra sempre em `excluidos`**.
- O `DELETE` físico seguinte (`:135-139`: `WHERE codigo_empresa = $1 AND codigo_pedido_omie = ANY($2::bigint[])`) também **não filtra `manual`** nem sinal do código. O job "agora apaga de verdade; o CSV é só relatório" ([[38-Regras-Sem-Chave-de-Ambiente]], atualização de 07/10). O relatório CSV (`:127`) lista os manuais como "excluídos no Omie".
- **Única proteção conhecida** é um trigger que o comentário da API cita: `trg_pedidos_vendas_manual_sem_delete` ("o banco ignora DELETE físico de pedido manual", `pedidos_vendas.route.js:642-645`; swagger `:850`). **Esse trigger não está em nenhum `.sql` do vault; existência e corpo em produção: não verificados** ([[Auditoria-Dump-Producao-2026-10-07]], lista "não coberto"). Se não existir, o primeiro `exclusionSync` depois de cadastrar um pedido manual **apaga o pedido** e, pelo trigger `trg_limpa_produto_vendas_orfaos`, os itens. O manual nem tem item, mas o pedido some dos dashboards, e uma NF manual apontando para ele fica com referência órfã (🟡, a trigger da 028 confere a existência só na gravação).
- 🟡 Mesmo que o trigger exista, o `DELETE` "ignorado" faria o job **registrar "excluídos do banco" um número que não foi apagado** (`:142-149`), poluindo o log e o CSV a cada rodada.
- **Correção sugerida (Gustavo):** no `SELECT` (`:99-104`) e no `DELETE` (`:136-137`) acrescentar `AND NOT manual AND codigo_pedido_omie > 0`. **O DBA confirma o trigger** em produção. **Não usar pedido manual em produção antes disso.** Já registrado como risco crítico no [[Registro-de-Decisoes-2026-10-07]] (item 15) e na [[Auditoria-Pente-Fino-2026-10-08]] (item 2 da tabela).
- 🟡 O `pedidoAutoHeal` (apaga e recria pedido do Omie em colisão de `numero_pedido + sequencial`) só age sobre o código que bloqueia; como o número do manual é `MAN-…` e o Omie só usa dígitos (`pedidos_vendas.route.js:135-139`), não deveria alcançar manual. Não li o código a fundo: fica como verificação.

## 6. Lacuna de interface (front)

- A tela **`pedidos-vendas-manuais` existe só em `auth.telas`** (dump de 07/10: filha de `auxiliares`, ao lado de `notas-fiscais-manuais`, [[Auditoria-Dump-Producao-2026-10-07]] linha 56). **No front (`00 - HUB`, `996e320`) conferido por grep: nenhuma ocorrência** de `pedidos-vendas-manuais`, `pedidos_vendas/manual` ou `pedidos-manuais` em `app/`, `components/`, `lib/`, `services/` ou `proxy.ts`. **Sem página e sem BFF.** O único pedido no front é o BFF de leitura `app/api/pedidos-venda`.
- **Referência pronta:** a tela de notas manuais tem página (`app/(protected)/dashboards/notas-fiscais-manuais/page.tsx`), BFF (`app/api/notas-manuais/route.ts`, `[codigo]/route.ts`, `apoio/route.ts`), componentes (`components/NotasManuais/*`), cliente (`lib/api/notasManuais.ts`, `TELA_NOTAS_MANUAIS = 'notas-fiscais-manuais'`) e serviço (`services/vendas/notasManuais.ts`). 🟡 O [[29-Notas-Fiscais-Manuais-So-Admin]] diz que a página fica em `/cadastros/auxiliares/notas-fiscais-manuais`; no front ela está em `dashboards/`. Divergência de caminho, a conferir.
- 🟡 Se o menu é montado a partir de `auth.telas`, um administrador com a permissão veria um item de menu sem página (404). Não verificado.
- **Decisão do Nathan (🔴, §8):** **construir** a tela (seguindo o molde da nota manual) **ou limpar** (remover a tela de `auth.telas` e as permissões). Enquanto não decidir, o pedido manual só se cria chamando a API direto.
- Se construir, os BFFs devem usar `/pedidos_vendas/manual/{codigo}` (**não** a genérica, que dá 403), repassar `respostaDeErro` (409, 403 e 400 não podem virar 500: item "28 BFFs engolem erros" da [[Auditoria-Pente-Fino-2026-10-08]]) e mandar `created_by` / `updated_by` / `deleted_by` da sessão.

## 7. Aceite e testes

Em homologação (`api-test`), com a API em `develop` e **uma unidade de teste**; nada disso foi executado por este contrato.

| # | Teste | Esperado |
|---|---|---|
| T1 | `POST /pedidos_vendas/manual` só com `x-api-key`, sem `created_by` | 403 `USUARIO_NAO_INFORMADO` |
| T2 | Mesmo `POST` com `created_by` de usuário sem a permissão | 403 `SEM_PERMISSAO` |
| T3 | `POST` do admin com corpo válido | 201; `manual: true`, `codigo_pedido_omie` negativo, `numero_pedido` `MAN-…`, `sequencial` nulo |
| T4 | `POST` com `numero_pedido`, `codigo_pedido_omie`, `faturado: true` ou `etapa: 0` | 400 em cada um |
| T5 | `POST` com valor 0, data futura, cliente de outra unidade | 400 (formato) ou erro do trigger (confirmar o código) |
| T6 | `PATCH /manual/{codigo}` com `valor_total_pedido`, depois `GET …/historico` | 200; histórico com `de`/`para`, autor e hora |
| T7 | `PATCH` trocando `codigo_empresa` ou `numero_pedido` | 400 |
| T8 | `PUT`, `PATCH` e `DELETE /pedidos_vendas/{código negativo}` | 403 `PEDIDO_MANUAL_ROTA_PROPRIA` |
| T9 | `POST /pedidos_vendas` com `manual: true`, ou `codigo_pedido_omie` negativo | 400 |
| T10 | `DELETE /manual/{codigo}`; `GET ?manual=true&com_deletados=true`; histórico do excluído | 200; pedido some dos dashboards e continua na listagem com `nome_excluido_por` |
| T11 | `DELETE /pedidos_vendas/lote` incluindo o código negativo | manual em `codigos_manuais_ignorados`, nada apagado |
| T12 | **Antes de produção:** com 1 pedido manual no banco de teste, rodar `exclusionSync` (janela que o inclua) | pedido manual **continua** no banco e fora do CSV (depende da correção da §5) |
| T13 | `DELETE FROM … WHERE manual` direto no banco de teste | 0 linhas apagadas se o trigger `_sem_delete` existir |

## 8. Riscos e perguntas

**Riscos**

1. 🔴 **`exclusionSync` apaga pedido manual** se o trigger de proteção não existir (§5). Dono: Gustavo (código) e DBA (trigger).
2. 🟡 **Chave de serviço** (`x-api-key`) sem token + UUID de admin no corpo = operação aceita (herdado do 29; L6, Gustavo).
3. 🟡 **Faturamento inflado:** o manual entra como líquido, sem blacklist nem cascata (swagger `:683`). É a mesma razão do 29: por isso só admin.
4. 🟡 **Excluir pedido com NF apontando:** a NF continua contando no faturamento (swagger `:850`); a tela, se existir, deve avisar.
5. **Buraco de numeração** e número nunca reaproveitado: aceito por desenho.
6. **Dois "contratos 30"** no código: confusão para quem cruza código e vault (cabeçalho).

**Perguntas**

| # | Pergunta | Dono |
|---|---|---|
| 1 | O trigger `trg_pedidos_vendas_manual_sem_delete` (e `_validar`, `_imutavel`) existe em produção? Versionar o SQL da migration 030 no vault. | 🔴 DBA |
| 2 | Aplicar `AND NOT manual AND codigo_pedido_omie > 0` no `exclusionSync` (SELECT e DELETE). | 🔴 Gustavo |
| 3 | Construir a tela `pedidos-vendas-manuais` ou limpar a tela de `auth.telas`? | 🔴 Nathan |
| 4 | Quais perfis têm a permissão em produção (só o admin)? As rotas `/pedidos_vendas/manual*` estão em `auth.rotas_telas`? | 🔴 DBA |
| 5 | Trocar os comentários "Contrato 30" do pedido manual por "contrato 45 do vault" (código, swagger, migration 030). | 🔴 Gustavo / DBA |
| 6 | O histórico (`GET …/historico`) deve exigir `pode_visualizar`? | 🔴 Nathan |
| 7 | Remover o código morto do caminho sem trava (`ajustarEdicaoManual` e os `if` de `:689-692,707-710,732-733`). | 🟡 Gustavo |

## 9. Ver também

[[29-Notas-Fiscais-Manuais-So-Admin]] (contrato irmão) · [[38-Regras-Sem-Chave-de-Ambiente]] · [[Auditoria-Pente-Fino-2026-10-08]] · [[Registro-de-Decisoes-2026-10-07]] · [[Colunas-Protegidas]] · [[Pedidos-de-Venda]] · [[Auditoria-Dump-Producao-2026-10-07]]
