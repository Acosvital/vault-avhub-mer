---
tags: [erp-acos-vital, integracao, av-hub, mes, contrato-api, plano]
criado: 2026-10-08
atualizado: 2026-10-08
---

# Integração av-hub ↔ MES: o que falta na "volta" (plano de 08/10/2026)

> Status: **plano** | nenhum dos 4 pontos está pronto | conferido no código em 08/10 (`api-acos-vital` `0557871`, `api-pcp` `ca3346b`, `av-hub` `bd1ae48`). Pedido do Nathan: aplicar os 4 pontos. O que depende de decisão de pessoa ficou como pedido formal; o que é código do av-hub foi feito em branch (ver seção 5).

A "ida" (MES → hub) já funciona: o MES empurra a requisição de compra (contrato 34) e lê os eventos dela (contrato 35). Falta a "volta": o hub devolver ao MES a referência da OC (**contrato 004**) e o MES mostrar ao vendedor a etapa de cada item (**contrato 005**).

## 1. Quando nasceram o 004 e o 005

| Data | Fato |
|---|---|
| **22/09/2026** | Os dois nascem como **rascunho** dentro da [[Integracao-AvHub-MES-Especificacao-F1]] (tarefa F1): Fluxo 2 vira o **004** (referência da OC, hub → MES) e Fluxo 3 vira o **005** (status por item, MES → hub). O Nathan os **aprova** no mesmo dia. O Fluxo 1 (requisição) vira o 003. |
| 29/09 | **004** revisado contra o banco real de Compras: a requisição passa a ser **por item** (uma OC pode juntar várias) e os campos ganham os nomes do banco. **005:** o Robert já tinha criado a rota `GET /itens/status` no MES (`901f9bb`), adiantando a F3. |
| 30/09 | O Robert responde. **004:** o formato atende, com um ajuste (`id_origem` em cada item) e a chave do MES precisa ser de escrita. **005:** aprovado **com 3 diferenças** (foto atual em vez de log; `pedido_venda` + `ordem_producao`; etapas a mais e a menos). |
| 01/10 | O 003 (ida) é substituído pelo **contrato 34** (o MES empurra). O 004 e o 005 (volta) não mudam. |
| 07/10 | Registro de Decisões: **#41** (004, 🔴 Gustavo), **#42** (aceite do 005, 🔴 Nathan) e **#43** (consumidor do 005, 🟡 Gustavo). |

## 2. Os 4 pontos

| # | Ponto | Dono | Estado em 08/10 | O que bloqueia |
|---|---|---|---|---|
| 1 | **Meus Pedidos por etapa** (tela 1.2, E3) | Nathan (av-hub) | Tela sem código de etapa; nada no av-hub lê o `/itens/status`. **Branch de implementação no av-hub: seção 5.** | Rota de leitura no hub (contrato 006) e tabela (SQL 010), do Gustavo |
| 2 | **Contrato 005:** aceite das 3 diferenças e consumidor | Nathan decide; Gustavo constrói | Rota do MES existe; consumidor não. Pedido formal em [[010-Itens-Pedido-Status]] e [[006-Status-por-Item-Leitura-no-Hub]] | Aceite do Nathan (abaixo) e a construção do Gustavo |
| 3 | **Contrato 004:** `GET /ordens-compra/referencia` | Gustavo (rota), Robert (job no MES) | **Não existe em nenhum lado.** O registro da compra segue manual (`PATCH /compras/requisicoes/:id/compra`). Pedido na seção 3 | Gustavo; chave do MES (ponto 4) |
| 4 | **L6, chave do MES** | Gustavo | A chave `MES_INTEGRACAO_KEYS` só abre o `PUT` do 34. As leituras do MES (`/pedidos_liberados`, `/unidades`, `/produtos`, eventos) usam chave de outro tipo, sem restrição por rota. Opções na seção 4 | Decisão do Gustavo |

### Aceite do Nathan para o contrato 005 (ponto 2)

O Robert aprovou em 30/09 e pediu o ok do Nathan. **Recomendação: aceitar as 3.** Efeito para o vendedor:

- [ ] **Foto atual, não log:** se o item passar por duas etapas entre duas leituras (1 a 2 min), o vendedor só vê a última. Com leitura a cada 90 s isso quase não acontece. Não há linha do tempo completa até a S5 (rastreabilidade).
- [ ] **`pedido_venda` + `ordem_producao`** no lugar do uuid do pedido do av-hub (o MES não o conhece). A ligação com o pedido do hub é por `codigo_empresa` + número do pedido.
- [ ] **Etapas a mais e a menos:** o MES manda `estoque.atendimento`, `expedicao.embalagem` e `expedicao.concluido`, e não manda `recebimento.pesagem`, `estoque.reservado` e `pcp.retorno`. A tela mostra o que vier; o vocabulário é provisório e não deve virar enum no código.

Perguntas do 005 ainda abertas: vocabulário final de `etapa` ([[Revisao-dos-Estados-e-Status]]) e como mostrar o item dividido em parciais em etapas diferentes (o desenho 010/006 guarda por parcial e deixa a agregação para depois).

## 3. Pedido ao Gustavo: rota do contrato 004

O contrato [[004-Referencia-OC-Integracao-MES]] já tem a rota, os campos e as regras fechadas (revisão de 29/09, ajuste do Robert de 30/09). Pedido formal:

1. Criar `GET /ordens-compra/referencia` em `api-acos-vital`, lendo `ordens_compra`, `ordens_compra_itens` e `ordens_compra_itens_vinculos` (todos já existem; `requisicoes_compra.id_origem` também). Só OC `aprovada` ou `cancelada` depois de aprovada.
2. `alterado_em` = o maior `updated_at` da OC, dos itens e dos vínculos com pedido de venda.
3. Mapear a rota em `auth.rotas_telas` (o modo `exigir` recusa rota sem mapa) e na chave do MES (ponto 4).
4. Robert: job de polling de 5 min no `api-pcp` e fila de Recebimento lendo a projeção; depois disso o registro manual da compra sai.

## 4. Pedido ao Gustavo: L6, chave do MES

Hoje `apiKeyAuth.js` tem 3 tipos de chave: `API_KEYS` do ambiente (admin), `auth.chaves_servico` no banco (leitura, escrita ou admin; cache de 30 s; **sem restrição por rota**) e `MES_INTEGRACAO_KEYS` (só o `PUT` do 34). O MES precisa de **escrita** (`POST /pedidos_liberados/:n/importado`) e a pipeline também (`PATCH /compras/ordens/:id/sincronizacao`). As três chaves de serviço restantes do contrato 38 (`IDENTIDADE_EXIGIR_TOKEN`, `ESCOPO_UNIDADE_EXIGIR_SESSAO`, `AUTENTICACAO_AZURE_VALIDAR_ID_TOKEN`) continuam chaves por causa disto.

| Opção | O que é | Prós | Contras |
|---|---|---|---|
| **A. Padrão do 34, ampliado** | Uma lista de rotas permitidas no código para cada variável (`MES_INTEGRACAO_KEYS` cobrindo as rotas do MES) | Rápido, já existe o padrão | Mudar rota exige deploy |
| **B. Coluna em `auth.chaves_servico`** (🟡 recomendada por mim) | `rotas_permitidas` (lista de padrões) por chave, conferida em `apiKeyAuth.js` | Administrável sem deploy, serve MES e pipeline | Exige SQL e teste de regressão |
| **C. Manter a chave admin** | Nada muda | Zero trabalho | Qualquer vazamento da chave do MES dá acesso total |

Rotas do MES a liberar: `/pedidos_liberados/*`, `/ordens-compra/referencia`, `/unidades`, `/produtos`, `/compras/requisicoes/eventos`. Da pipeline: `/compras/ordens/fila-omie` e `PATCH /compras/ordens/:id/sincronizacao`. **Decisão: Gustavo.**

## 5. O que foi feito no av-hub (branch, sem merge)

**Branch `claude/etapa-dos-itens` do `av-hub`** (commit `48698105`, **sem merge, sem PR**; nada foi publicado):

- **Cartão "Etapa dos itens"** na página do pedido (`components/Pedidos/EtapaDosItens.tsx`), em Meus Pedidos, Pedidos da equipe e Pedidos do PCP. Por item: produto, etapa (com o status em pílula), quantidade, setor, "atendido pelo estoque" e a hora da última mudança. Se o job do hub parou há mais de 10 minutos, avisa.
- **BFF** `GET /api/pedidos-venda/{fonte}/{codigoEmpresa}/{pedidoVenda}/etapas`: confere permissão da fonte e **posse do pedido** (mesma regra da rota irmã `itens`) e repassa para `GET /itens_pedido_status` do hub (contrato 006).
- **Enquanto o hub não tem a rota (404), o cartão diz "ainda não está disponível neste ambiente"** e nada quebra. Etapa que o front não conhece aparece com o código cru.
- **Rótulos das etapas** em `lib/domain/etapas-item.ts` (vocabulário provisório do MES, sem enum travado).
- **Contrato para o Gustavo** dentro do próprio repo: `docs/ENVIAR - contrato-status-por-item.md`.
- **Verificado:** `tsc` e ESLint passam; a página foi renderizada no tema claro e escuro com um servidor de teste imitando o hub (4 itens em 4 etapas) e no caso "rota inexistente". **Não foi testado contra o hub real**, que ainda não tem a rota, e a regra de escopo do vendedor depende do hub.

## Ver também
- [[004-Referencia-OC-Integracao-MES]]
- [[005-Status-Item-Integracao-MES]]
- [[006-Status-por-Item-Leitura-no-Hub]]
- [[010-Itens-Pedido-Status]]
- [[Chaves-de-Integracao-AvHub-MES-Pipeline]]
- [[Registro-de-Decisoes-2026-10-07]]
- [[AV-Hub-Portal-Vendedor-Plano]]
