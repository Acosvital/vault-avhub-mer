---
tags: [contrato-sql, contrato-api, indice]
criado: 2026-09-17
atualizado: 2026-10-07
---

# Contratos — ERP Aços Vital

> Status: decidido | no código | em produção (verificado em 07/10/2026, só pelo dump). Decisões desta rodada: [[Registro-de-Decisoes-2026-10-07]].

Seção dedicada só a **contratos** — documentos formais de mudança que precisam de aprovação/execução de outra pessoa antes do código poder avançar: contratos de **banco de dados** (para o DBA, Gustavo) e contratos de **API** (para o dev que for implementar). Cada contrato é auto-contido: alguém pode abrir só aquele arquivo, entender o "por quê", o "o quê" exato (schema ou request/response) e o que falta decidir, sem precisar ler o resto do projeto.

## Conferência de 07/10/2026 (código em `main` = `develop` da api-acos-vital, `a6ab058`/`fdafb35`)

**Confiança:** tudo abaixo vem de **leitura de código** (`origin/main` e `origin/develop` da `api-acos-vital`; `develop` do `api-pcp`, do `app-pcp` e `master` da `omie-elt-pipeline`). **Produção e banco só foram conferidos pelo dump de 07/10** ([[Auditoria-Dump-Producao-2026-10-07]]); para o contrato 34 isso está resolvido (função de banco em produção, ✅ [[Registro-de-Decisoes-2026-10-07]]); para os demais, a produção não foi conferida. Regra do Nathan: vale o que funciona em **produção**; por isso, onde o código comprova mas a produção não foi vista, o estado é `implementada-no-codigo` e **falta conferir em produção/`api-test`**. Nada foi movido para `Realizados/` nem marcado `aplicada` por causa desta leitura. Notas relacionadas: [[AV-Hub-API-Estado-Atual]], [[Chaves-de-Integracao-AvHub-MES-Pipeline]], [[App-PCP-Recebimento-Conferencia]], [[Onde-Estamos]].

Pontos de contexto:
- `main` = `develop` da API em conteúdo (tip `a6ab058`, 06/10 16:05; entrou na `main` pelo PR #280, `fdafb35`, 06/10 16:12; entradas anteriores: #275 `970b562` em 02/10, #276 `370173b`, #277, #278, #279). Stack real: Express 4 + Sequelize; desde o PR #276 o código mora em `src/schemas/<schema>/…` (não há mais `src/routes`/`src/models`).
- Nota histórica (🟡, [[Registro-de-Decisoes-2026-10-07]]): os hashes de branches locais `f4380d7`, `8eb5dce`, `cba68fa`, `c2b68a9` e `1b6fe6e` foram re-autorados a partir de patches e não existem na `develop`/`main`; equivalentes mergeados confirmados nesta nota: `0391b29` (#275) para o 34, `0a65491` para o 35, `ca899f9` para o 31 (o `a6ab058` é o commit do 39). Para `c2b68a9` e `1b6fe6e` não há equivalente confirmado aqui.
- **MES:** a `main` do `api-pcp` e do `app-pcp` parou em 28/08; tudo o que o MES tem hoje (incluindo o que liga os contratos 34 e 35) está **só na `develop`** (api `ca3346b`, app `a802a3e`, 07/10). Homologação: `https://mes-test.acosvital.com.br/` roda a `develop` (✅ [[Registro-de-Decisoes-2026-10-07]]); merge `develop` → `main` antes do piloto (✅; data e responsável 🔴 Robert).

| Contrato | Código mostra (hash em `main` = `develop`, salvo dito) | O que falta / divergência |
|---|---|---|
| [[004-Referencia-OC-Integracao-MES]] | **(atualizado em 09/10)** `GET /ordens-compra/referencia` **existe no hub** (`fe55923`, 08/10; `develop` e `main` da `api-acos-vital`, PR #284), lendo `vw_ordens_compra_referencia_mes` (migration `api004`; **aplicação no banco não verificada**: sem ela a rota dá 500). **Nada no MES**: o `api-pcp` não tem referência à rota; o registro manual `PATCH /compras/requisicoes/:id/compra` segue valendo | `implementada-no-codigo` (lado do hub). 🔴 **Falta o job de leitura no MES** (Robert, 5 min, UPSERT por `(codigo_empresa, id_ordem_compra)`) e o ajuste `id_origem` por item (30/09). A chave do 34 (`MES_INTEGRACAO_KEYS`) dá 403 aqui; o MES lê com chave de leitura de `auth.chaves_servico` ou de `API_KEYS` (decisão do Gustavo, 08/10). [[Registro-de-Decisoes-2026-10-07]] #41 |
| [[005-Status-Item-Integracao-MES]] | **Hub:** nada (sem rota, model nem tabela de status por item). **MES:** a rota `GET /itens/status` **existe** (`901f9bb`; `etapa` derivada do tipo do setor; foto atual da parcial) | Aceite das 3 diferenças: 🔴 Nathan (recomendado aceitar; Robert aprovou em 30/09; [[Registro-de-Decisoes-2026-10-07]] #42). **(atualizado em 09/10)** o **consumidor no hub existe**: `dee35b0` (08/10) traz o job `itens_pedido_status.job.js`, que roda no processo da `api-acos-vital` a cada `MES_STATUS_INTERVALO_SEG` (padrão 90 s), por unidade, lendo `GET {MES_API_URL}/itens/status` com `MES_API_KEY` e gravando por `fn_itens_pedido_status_gravar` (migration `api005`; **aplicação no banco não verificada**), mais a rota `/itens_pedido_status` (contratos 005 e 006). Nota: o código cita um contrato **006 "Status por item, leitura no hub"** que não está no vault (#43) |
| [[003-Requisicao-Compra-Integracao-MES]] | Rota `GET /requisicoes-compra` existe no MES no formato do hub (`901f9bb`, `5c1316f`), **substituída pelo 34**; nenhum job da `api-acos-vital` a consome | Nada: histórico |
| [[26-Vendas-Liberacao-Pedido]] | `pedidos_liberacao`/`pedidos_liberados` (GET, `/:n/itens` com 409 `PEDIDO_NAO_LIBERADO`, `POST /:n/importado`) existem (`4bf36d9`, 28/09, #275). Data de corte: preenchida em 01/10 (conferido na `api-test`, não no código) | **L6 segue aberto, 🔴 Gustavo** (chave restrita para MES e pipeline ou continuar com a chave admin; [[Registro-de-Decisoes-2026-10-07]] #10): `apiKeyAuth.js` tem 3 tipos de chave: (a) `API_KEYS` do ambiente = admin; (b) `auth.chaves_servico` no banco, nível leitura/escrita/admin, cache de 30 s, **sem restrição por rota**; (c) `MES_INTEGRACAO_KEYS`, que **só abre o PUT** do 34. Com (c), `/pedidos_liberados`, `/unidades`, `/produtos` e `/compras/requisicoes/eventos` dão 403 `CHAVE_MES_ROTA_NAO_PERMITIDA` até em GET: o MES lê essas rotas com chave admin ou do banco |
| [[34-Requisicoes-MES-Empurra-para-o-Hub]] | `PUT /compras/requisicoes/origem/{id_origem}` existe (`0391b29`, #275; `validarCorpoMes`; 201/200/409 `REQUISICAO_COM_OC`). **O MES já chama** o PUT desde `e7ce2c9` (02/10, PR #48, `develop` do `api-pcp`: fila `integracao_avhub_envios`, um PUT por item, backoff 1/2/5/10/30/60 min, 409 → RECUSADO) | O código chama a função de banco `core_vendas_faturamento.fn_requisicao_mes_aplicar` ("migration 034"). **(07/10) ✅ ela existe em produção, completa (dump de 07/10, [[Auditoria-Dump-Producao-2026-10-07]]); o SQL dela ainda não está versionado no vault** (o anexo `34-anexos/0001` só cria 2 colunas). **✅ O PUT de sucesso já funcionou no `mes-test`** ([[Registro-de-Decisoes-2026-10-07]] #2 e #3). Falta conferir se `AVHUB_MES_INTEGRACAO_KEY` tem valor no ambiente real. O `f4380d7` é versão antiga, não mergeada, obsoleta |
| [[35-Compras-Marcos-Requisicao-para-MES]] | `GET /compras/requisicoes/eventos` existe (`0a65491`, #275): `alterado_desde`, `apos_id`, `codigo_empresa`, `limit`; resposta `{quantidade, tem_mais, proximo, data}`; cancelar exige motivo (3–500) e grava `cancelada_por_origem='compras'`. **O MES lê e reage** desde `41bf4a6` (05/10, PR #49, `develop` do `api-pcp`; cursor `requisicoes-eventos`, idempotente por `id_evento`): só reage a `requisicao_cancelada` e `requisicao_reaberta`, os demais marcos só espelham `avhubStatus` e vão para métricas | A chave do 34 **não abre** essa rota (o MES precisa de chave admin/do banco). Hash `0a65491` é o mergeado (o `8eb5dce` é de branch local) |
| [[36-Compras-Produto-Obrigatorio-e-Comprador-da-OC]] | Validação de produto incondicional; `historico_comprador` no detalhe da OC (null sem a tabela `ordens_compra_comprador_historico`, via `to_regclass`); histórico unificado fixo (`5491037` #277, `c8f2f5e` #279). Na pipeline: a OC também **nunca manda parcelas** | Emissão de OC e histórico do comprador só conferidos em produção como "P6 `origens: av-hub + omie`" (06/10) |
| [[37-Dashboard-Mensal-Variacao]] | `variacao_pct` e `variacao_quantidade_pct` via `fn_variacao_pct` em `/dashboard_mensal_{vendas,faturamento}` (`47a5aad`, #278) | Já conferido em produção em 06/10 (ver bloco abaixo) |
| [[38-Regras-Sem-Chave-de-Ambiente]] | Nenhuma chave removida é lida por `process.env` (`c8f2f5e`, #279). **Saíram 13 chaves, não 11:** as 11 + `BLACKLIST_PEDIDOS_CHAVE_LEGADA` + `COMISSOES_COORDENADORES_BLOQUEIO`; também saiu `COMPRAS_HISTORICO_UNIFICADO` (do 36 P6). Sobram **exatamente as 6 do §3**. `MES_INTEGRACAO_KEYS` e `DOCS_API_KEY` são segredos fora da lista | Ligar as 6 do §3 depende dos pré-requisitos do contrato; vincular compradores (0 de 74 em produção em 06/10) |
| [[39-Vendedores-Fila-de-Vinculo]] | `?sem_vinculo=true` (ignorado se vier `id_funcionario`/`_in`), `nome_funcionario`, `nome_usuario`, `/vendedores/{id}/sugestoes` com `nome_setor`, `nome_unidade`, `desligado` (`a6ab058`; #280 `fdafb35`). Front av-hub#155 mergeado na `develop` do av-hub em 07/10 10:01 | ✅ API em produção; front (`av-hub#155`) só na `develop` do av-hub, não na `main` ([[Registro-de-Decisoes-2026-10-07]] #6) |
| [[40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]] | **Proposta.** `middlewares/escopoVendedor.js` e `identidadeUsuario.js` já aplicam escopo e permissão pelo token; `ESCOPO_VENDEDORES_EXIGIR` está desligado por padrão e o BFF resolve o escopo em 3 chamadas por requisição | Gustavo: fixar a chave no código e conferir a cobertura de rotas, **antes** de o front remover as 5 marcas; Q1 a Q5 abertas ([[Registro-de-Decisoes-2026-10-07]] #9 e #74) |
| [[41-Login-Rate-Limit-no-Backend]] | **Proposta.** A API já tem o limite em banco (`auth.login_tentativas`), desligado por padrão e sem o BFF mandar o IP | 🔴 Gustavo/Nathan (Q1 a Q5); depois o front remove `lib/auth/loginRateLimiter.ts`, só com a API já ligada ([[Registro-de-Decisoes-2026-10-07]] #74) |
| [[42-Coordenadores-e-Orcamento-sair-do-JSON-do-Repositorio]] | **Proposta.** Coordenadores e orçamento ainda em JSON no repositório do av-hub; a API `90bdb33` existe | Coordenadores voltam ao escopo (🟡 inferido, Nathan contesta se não era a intenção); orçamento sai quando o módulo Comercial & Suprimentos substituir a tela |
| [[43-Ordem-das-Etapas-de-Faturamento-no-Cadastro]] | **Proposta.** `ordem_fluxo` e `?ordem=fluxo` já existem na API; `utils/etapasFluxo.ts` só tem consumidor morto | DBA: seed de `ordem_fluxo`; pipeline: `protectedColumns.ts`; front: código morto apagado em 07/10 (sem commit) |
| [[44-Upload-de-Fotos-Politica-de-Bucket]] | **Proposta, baixa prioridade.** A validação de bytes do BFF é defesa em profundidade e fica | Política de bucket na VPS 3 (Gustavo); reclassificar a marca `GAMBIARRA(`: 🔴 Nathan |
| [[33-Dashboards-Unidade-de-Origem-do-Vendedor]] | Código na API (`5231219`, #275) | Front `397cf81` não reconferido nesta leitura; P1–P6 em aberto |
| [[31-Compras-Dashboard]] | `GET /compras/ordens/dashboard` em `main` (`ca899f9`; o `cba68fa` era de branch local) | Valores só vistos zerados na `api-test` |
| [[32-Compras-CCP-Acompanhamento-OC]] · [[30-Compras-Pedido-Omie-PDF-Completo]] | Acompanhamento CCP (`7faf6a7`); detalhe do pedido Omie com fornecedor e código do produto (`119634a`); regras fixas: só comprador vinculado emite OC, só `pode_aprovar` aprova/cancela | 30: falta o PDF do av-hub mostrar |
| [[07-Dados-Orcamento-e-Coordenadores-no-Banco]] | **Implementado na API** (o vault dizia "desconsiderado/não entregue"): `/orcamento/{fornecedores,produtos,cotacoes,vinculos,categorias,familias}` leem `core_compras.orc_*`/`orc_vw_*`; `GET /dashboard/comissoes` usa `fn_dashboard_comissoes` sobre `comissao_coordenadores` (`90bdb33`, 01/10, #275; o código cita "migration 007 e carga 007b") | ✅ O orçamento foi **desenvolvido por fora, no módulo Comercial & Suprimentos**; a API entregue (`90bdb33`) existe; o contrato 07 (e o 38) **precisam ser reescritos** ([[Registro-de-Decisoes-2026-10-07]] #39). A decisão de 01/10 ("desconsiderado") ficou superada. DBA ter aplicado o SQL é inferência |
| [[13-Fornecedores-por-Produto]] | `GET /produtos/:id/fornecedores` existe sobre `core_compras.vw_produto_fornecedores` (`31e26a6`, 25/09, #275) | ✅ Contrato 13 **desconsiderado** ([[Registro-de-Decisoes-2026-10-07]] #40). Front não liga (simulador usa dataset legado) |
| [[23-Compras-Pipeline-Consolidado]] · [[19-Compras-Pedido-Pipeline-Omie]] | **Pipeline** (`master` `d2886bf`, 06/10): L1–L9 e L4 (envio da OC) no código; PR #1 mergeado em 05/10 (`3233acf`), PR #2 em 06/10; flags `SYNC_*` de leitura removidas; **envio da OC fixo no código, direto ao Omie, sem `SYNC_ENVIO_OC` nem `ENVIO_OC_DRY_RUN`** (✅ [[Registro-de-Decisoes-2026-10-07]] #7; alteração de código: Gustavo); inativar catálogos feito (`f4fd02d`); L10.4 respondido; nunca manda parcelas. **API** expõe o que a pipeline consome: `GET /compras/ordens/fila-omie`, `PATCH /compras/ordens/:id/sincronizacao`, `POST /:id/reenviar`, `GET /compras/compradores`, `/cotacoes_moeda` (`ec2a42b`, 22/09, #273) | Falta conferir deploy/produção. L10.1, 10.6 (FOB) e 10.7 (b)–(d): **risco aceito** (✅; o Nathan rodou cerca de 4 testes reais e a OC entrou). ~~defaults `SYNC_ENVIO_OC=false` e `ENVIO_OC_DRY_RUN=true`~~ (flags deixam de existir). O 19-Pipeline-Omie é histórico, substituído pelo 23 |
| [[006-Pedidos-Vendas-Valor-Devolucao]] | Coerente com "invalidado": `pedidos_vendas` só tem o boolean `devolucao_parcial`. Colunas `valor_devolucao` em produção vazias; limpeza 🔴 Gustavo ([[Registro-de-Decisoes-2026-10-07]] #31) | — |
| [[002-Material-Alias-Omie-MES]] | Rejeitado em 21/09; o código do alias foi removido do MES (`api-pcp` `0ac2596`, 29/09, migration com DROP TABLE; só na `develop` do `api-pcp`) | — |

**Estado de cada contrato em uma linha (07/10, código):** 004 inexistente (API e MES), 🔴 Gustavo · 005 rota no MES, sem consumidor no hub (aceite 🔴 Nathan) · 003 substituído pelo 34 · 07 orçamento desenvolvido por fora (Comercial & Suprimentos), contrato a reescrever · 13 desconsiderado (✅) · 19 histórico, 23 implementado no código (pipeline `master` `d2886bf`) · 26 L6 aberto (🔴 Gustavo) · 34 PUT na API, chamado pelo MES, função em produção (✅) · 39 API em produção, front só na `develop` · 35 rota na API e lida pelo MES · 36, 37, 38, 39, 33, 31, 32, 30 no código de `main`.

## Conferência de 06/10/2026 (DBA: "implementei o 36, 37 e 38")

Regra do Nathan: vale o que funciona em **produção**.

| Contrato | Resultado | Onde ficou |
|---|---|---|
| [[36-Compras-Produto-Obrigatorio-e-Comprador-da-OC]] | ✅ P1 sem chave na `develop` (`c8f2f5e`); P6 em produção (`av-hub + omie`). P1 e histórico do comprador só aparecem emitindo OC (produção é só leitura). Na `api-test` a emissão de OC dá 500 em qualquer caso — problema à parte | `Realizados/` |
| [[37-Dashboard-Mensal-Variacao]] | ✅ em produção: `variacao_pct` no consolidado (55,3 = `/dashboard/equipe`) e por unidade | `Realizados/` (av-hub#141 pode ir à `main`) |
| [[38-Regras-Sem-Chave-de-Ambiente]] | ✅ na `develop` (`c8f2f5e`): as chaves saíram, comissão dos coordenadores sem bloqueio. **(atualizado em 07/10)** foram **13** chaves, não 11 (as 11 + `BLACKLIST_PEDIDOS_CHAVE_LEGADA` + `COMISSOES_COORDENADORES_BLOQUEIO`; `COMPRAS_HISTORICO_UNIFICADO`, do 36, também saiu). Ficam exatamente as 6 do §3 (segurança, paginação). Falta vincular os compradores (0 de 74 em produção) | `Realizados/` |

## Conferência de 01–02/10/2026 (DBA: "concluí 26, 28, 29, 30, 31, 32, 33 e 34"; em 02/10: "28, 29 e 35")

| Contrato | Resultado na `api-test` | Onde ficou |
|---|---|---|
| [[26-Vendas-Liberacao-Pedido]] | ✅ data de corte preenchida (28/07/2026), liberação funcionando (741 pendentes, 16 liberados, 3 importados). **(atualizado em 07/10)** L6 (chave própria do MES, escrita restrita por rota) **segue aberto** no código: a `MES_INTEGRACAO_KEYS` só abre o PUT do 34 | `Realizados/` |
| [[28-Compradores-Criar-Excluir-Sugestao]] | ✅ **entregue em 02/10/2026**: `POST`/`DELETE /vendedores` = 403 `CADASTRO_VEM_DO_OMIE`, `PUT` não altera nome/ativo; R4 na `develop` (sem comprador na `api-test` para conferir) | `Realizados/` |
| [[29-Notas-Fiscais-Manuais-So-Admin]] | ✅ **entregue em 02/10/2026**: trava ligada, `POST /nota_fiscal_saida/manual` sem usuário ou sem permissão = 403 | `Realizados/` |
| [[30-Compras-Pedido-Omie-PDF-Completo]] | ✅ campos no código da `develop` (`119634a`, hoje também em `main`); sem dado para testar | `Realizados/` (falta o PDF do av-hub mostrar) |
| [[31-Compras-Dashboard]] | ✅ rota responde (valores zerados, sem pedidos) | `Realizados/` |
| [[32-Compras-CCP-Acompanhamento-OC]] | ✅ fila, detalhe e contatos respondem e validam | `Realizados/` |
| [[33-Dashboards-Unidade-de-Origem-do-Vendedor]] | ✅ `/vendedores` com `ativo_desde`, `inativo_desde`, `unidade_origem`. **(atualizado em 07/10)** código na API em `5231219` (#275) | `Realizados/` (front sem push em 01/10; não reconferido em 07/10) |
| [[34-Requisicoes-MES-Empurra-para-o-Hub]] | ✅ **entregue em 02/10/2026**: SQL aplicado, lista de requisições voltou (200) com as colunas novas. **(atualizado em 07/10)** o MES já chama o PUT (`e7ce2c9`, 02/10, só na `develop` do `api-pcp`); `fn_requisicao_mes_aplicar` **existe em produção** (dump de 07/10; SQL ainda fora do vault) e o **PUT de sucesso funcionou no `mes-test`** (✅ [[Registro-de-Decisoes-2026-10-07]]) | `Realizados/` |
| [[35-Compras-Marcos-Requisicao-para-MES]] | ✅ **entregue em 02/10/2026**: rota de eventos e triggers na `api-test`; cancelar sem motivo = 400. **(atualizado em 07/10)** o MES lê e reage desde `41bf4a6` (05/10, `develop` do `api-pcp`); código da API em `main` com o hash `0a65491` | `Realizados/` |

## Equivalência de numeração (🟡, [[Registro-de-Decisoes-2026-10-07]] #56)

Os arquivos **não são renomeados** (os wikilinks quebrariam). Alguns números se repetem entre pastas e outros sumiram; use a tabela abaixo (sufixos a/b só existem aqui, não nos arquivos).

| Nº | Sufixo | Tipo | Arquivo |
|---|---|---|---|
| 04 | a | SQL (Realizados) | [[004-Pedidos-Compras]] |
| 04 | b | API (aberto) | [[004-Referencia-OC-Integracao-MES]] |
| 04 | c | Lógica (Realizados) | [[04-Pedidos-Notas-Dashboards-Agregacao-no-Banco]] |
| 04 | d | Lógica (Realizados) | [[04-Vagas-Fila-Decisao-no-Banco]] |
| 07 | a | Lógica (aberto) | [[07-Dados-Orcamento-e-Coordenadores-no-Banco]] |
| 07 | b | Lógica (Realizados) | [[07-Chave-Composta-Blacklist-Pedidos]] |
| 09 | a | SQL (Realizados) | [[009-Categoria-Sem-Escopo-Empresa-Views]] |
| 09 | b | Lógica (Realizados) | [[09-Ordenacao-Sistema-Vendedores]] |
| 09 | c | Lógica (Realizados) | [[09-Paginacao-por-Pedido-Vendas-Planilha]] |
| 13 | a | Lógica (aberto) | [[13-Fornecedores-por-Produto]] (desconsiderado) |
| 13 | b | Lógica (Realizados) | [[13-Compras-Backend-Consolidado]] |
| 14 | a | Lógica (Realizados) | [[14-Compras-Omie-Pedido-Compra]] |
| 14 | b | Lógica (Realizados) | [[14-Compras-Vinculo-Pedido-Venda]] |
| 19 | a | Lógica (aberto, histórico) | [[19-Compras-Pedido-Pipeline-Omie]] (substituído pelo 23) |
| 19 | b | Lógica (Realizados) | [[19-Compras-Pedido-Omie-Nomes]] |

(No SQL os números têm 3 dígitos, 004 e 009; na API, 004 e 005; na lógica, 2 dígitos.)

**Números que sumiram** (não existe arquivo com eles): 20, 21, 22, 24, 25 e 27.

**Numeração antiga citada em outras notas** (contratos renumerados em 28 e 29/09/2026; os arquivos de 10 a 19 diziam "era o contrato N"):

| Antigo | Atual |
|---|---|
| 15 | [[10-Compras-Pendencias-Pos-Backend]] |
| 20 | [[11-Compras-Cotacao-Moeda-PTAX]] |
| 21 | [[12-Compras-Projetos-Omie]] |
| 22 | [[13-Compras-Backend-Consolidado]] |
| 24 | [[14-Compras-Vinculo-Pedido-Venda]] |
| 25 | [[15-Compras-Historico-Unificado]] |
| 16 | [[18-Compradores-Funcionario]] |
| 27 | [[19-Compras-Pedido-Omie-Nomes]] |

Atenção: o número 16 hoje é [[16-Compras-Pedido-DBA-Banco]], mas o "16" das notas antigas era o de compradores (hoje 18). Ao ler uma nota antiga que cita "16", confira o assunto.

## Como está organizado

- **[[001-Produtos-Parceiros-Filtro-Incremental|1. Contratos de API]]** — mudanças de contrato de request/response em endpoints REST já existentes, ou endpoints novos. Pasta `02-Contratos-API/` (ainda em aberto) e `Realizados/02-Contratos-API/` (já aplicados).
- **2. Contratos SQL para o DBA** — DDL proposto (CREATE/ALTER TABLE), pronto para o Gustavo revisar e aplicar. Pasta `01-Contratos-SQL-DBA/` (ainda em aberto): só o [[006-Pedidos-Vendas-Valor-Devolucao]] (invalidado). O **[[009-Categoria-Sem-Escopo-Empresa-Views]]** foi **aplicado** (conferido em produção em 06/10/2026: o pedido 25970 caiu de R$ 1,4 mi para R$ 964 mil, como previsto) e está em `Realizados/01-Contratos-SQL-DBA/`.
- **3. [[Indice-Logica-Fora-do-Backend|Contratos de lógica fora do backend]]** — importados de `av-hub/docs/` (arquivos marcados `ENVIAR`) em 23/09/2026: filtro/ordenação/paginação/permissão que hoje rodam no navegador em vez do banco/API. Pasta `03-Contratos-Logica-Fora-Backend/`. **Compras (28/09/2026):** o backend (banco + API) e as telas estão concluídos e foram para Realizados (10 a 15, ver abaixo). **Em aberto:** [[23-Compras-Pipeline-Consolidado]] (`omie-elt-pipeline`, L1–L10: é o que falta para as telas terem dados na `api-test`), [[18-Compradores-Funcionario]] e [[19-Compras-Pedido-Omie-Nomes]] (backend dos dois entregue em 29/09; front em av-hub#106, mergeado em 29/09 → **movido para `Realizados/`**). [[19-Compras-Pedido-Pipeline-Omie]] foi substituído pelo 23 e fica como histórico. **[[07-Dados-Orcamento-e-Coordenadores-no-Banco]]:** em 29/09 não estava entregue e em 01/10 o Nathan o desconsiderou; **(atualizado em 07/10)** a leitura do código mostra as rotas `/orcamento/*` e `/dashboard/comissoes` em `main` (`90bdb33`, 01/10, #275). ✅ Decidido em 07/10: o orçamento foi **desenvolvido por fora, no módulo Comercial & Suprimentos**; a API `90bdb33` existe; o contrato 07 (e o 38) precisam ser reescritos; o contrato 13 fica desconsiderado ([[Registro-de-Decisoes-2026-10-07]] #39 e #40). **(atualizado em 07/10)** O [[23-Compras-Pipeline-Consolidado]] está implementado no código da pipeline (`master` `d2886bf`); falta conferir produção. O 18 e o 19-Nomes já estão em `Realizados/`.
- **Requisições do MES (01/10/2026):** [[34-Requisicoes-MES-Empurra-para-o-Hub]] — o MES empurra a requisição ao hub (`PUT /compras/requisicoes/origem/{id_origem}`), em vez de o hub buscar (substitui a DEC-2; revisa o [[003-Requisicao-Compra-Integracao-MES]]). Cancela só sem OC (409 com OC), chave própria só para essa rota, colunas do pedido do Omie. **(atualizado em 07/10)** Foi implementado e testado na API local (`f4380d7`, branch `feat/requisicoes-mes-upsert`, **não mergeada e obsoleta**); o que vale é o `0391b29` (#275, em `develop` e `main`). **Entregue em 02/10** (SQL aplicado na `api-test`) e **o MES já chama** o PUT desde `e7ce2c9` (02/10, `develop` do `api-pcp`). **(07/10, ✅)** a função de banco `fn_requisicao_mes_aplicar` existe em produção (dump de 07/10; o SQL ainda não está no anexo do vault) e o PUT de sucesso já funcionou no `mes-test`. Análise geral (retrato de 01/10): [[Analise-Contratos-vs-Hub-2026-10-01]].
- **Marcos da requisição para o MES (02/10/2026):** [[35-Compras-Marcos-Requisicao-para-MES]] — proposta do Robert: o MES lê por `GET /compras/requisicoes/eventos` (cursor) tudo o que acontece em Compras com as requisições dele (cotação, OC, aprovação, Omie, fornecedor, previsão, despacho, ocorrências, cancelamento e reabertura), para a Torre de Fluxo; cancelar pelo Compras passa a exigir motivo. **Entregue em 02/10/2026** (SQL na `api-test`, API na `develop` `0a65491`, hoje também em `main`, #275); front em av-hub#117. Anexos: `35-anexos/0001` (SQL), `0002` (roteiro de teste), `0003` (patch da API). **(atualizado em 07/10)** O MES **já lê e reage** desde `41bf4a6` (05/10, `develop` do `api-pcp`) — o antigo "falta o MES ler" não vale mais. A chave do 34 não abre essa rota.
- **Dashboards (01/10/2026):** [[33-Dashboards-Unidade-de-Origem-do-Vendedor]] — o filtro de unidade dos dashboards de vendas, faturamento e por tipo passa a ser a **unidade de origem do vendedor** (lotação do funcionário no RH; sem vínculo, o Omie do cadastro), e vendedor que saiu some dos rankings pelo `ativo_desde`/`inativo_desde` no cadastro. SQL (view, 2 funções, 15 funções de dashboard) + API. **Implementado e testado no banco e na API locais; front pronto na branch `feat/vendedor-periodo-ativo` (sem commit).** Anexos: `33-anexos/0001` (SQL) e `0002` (patch da API). **(atualizado em 07/10)** **Entregue em 01/10** (conferido na `api-test`); código da API em `main` (`5231219`, #275); o front (`397cf81`, local, sem push em 01/10) não foi reconferido. Em aberto: 4 pessoas duplicadas sem vínculo (P1), genéricos/Dev (P2), comissões (P3), histórico retroativo (P5), datas dos 35 inativos (P6).
- **Compras (30/09/2026):** [[32-Compras-CCP-Acompanhamento-OC]] — o CCP acompanha a OC com o fornecedor: confirmação, contatos, previsão, despacho e renegociação (3 tabelas novas + fila `GET /compras/acompanhamento` + escrita só para o perfil CCP). SQL + API; era **proposta** em 30/09 — **(atualizado em 07/10)** entregue em 01/10 (fila, detalhe e contatos respondem na `api-test`); código `7faf6a7` em `main`. Alimenta a tela `/compras/followup` do av-hub. Perguntas P1 (de onde vem o "saldo a receber") e P2 (só OC do av-hub?) definem o escopo.
- **Compras (30/09/2026):** [[31-Compras-Dashboard]] — `GET /compras/ordens/dashboard`: valor comprado (e período anterior), série de 12 meses, top fornecedores/categorias/compradores, maiores pedidos, recebimento e atraso (foto de agora) por faixa. Só API; foi **implementado e testado na API local** (`cba68fa`, branch local) — **(atualizado em 07/10)** entregue em 01/10 e já em `main` (`ca899f9`; o `cba68fa` não existe na `develop`/`main`). Perguntas: pedidos BENAFER de R$ 82,7 mi em agosto e o significado das etapas 10/15/20.
- **Compras (30/09/2026):** [[30-Compras-Pedido-Omie-PDF-Completo]] — o que falta no PDF do pedido feito no Omie (conferido contra o PDF do próprio Omie, pedido 46871): endereço, e-mail, telefone e IE do fornecedor e código do produto no `GET /pedidos_compras/{id}`; IE (vazia em `core.parceiros`) e, se precisar, IPI/ICMS ST pela pipeline. Era **proposta** em 30/09; **(atualizado em 07/10)** a API devolve os campos (`119634a`) e a pipeline grava IE e dados fiscais em `core.parceiros` (`66f9a2e`); falta o PDF do av-hub mostrar.
- **Faturamento (29/09/2026):** [[29-Notas-Fiscais-Manuais-So-Admin]] — nota fiscal manual só para o admin: permissão da tela `notas-fiscais-manuais` conferida no backend, auditoria de quem cadastrou/alterou. Era **proposta** em 29/09; **(atualizado em 07/10)** entregue em 02/10 (trava ligada na `api-test`).
- **Acessos (29/09/2026):** [[28-Compradores-Criar-Excluir-Sugestao]] — criar/excluir comprador e sugestão de vínculo por semelhança, para a tela de Compradores ficar igual à de Vendedores. Só API (+ um ajuste na pipeline); era **proposta** em 29/09 — **(atualizado em 07/10)** entregue em 02/10 (`POST`/`DELETE /vendedores` = 403 `CADASTRO_VEM_DO_OMIE`); R4 (datas do comprador protegidas) está na pipeline (`66f9a2e`).
- **Compras (28/09/2026):** [[19-Compras-Pedido-Omie-Nomes]] — nomes (fornecedor, comprador, etapa, catálogos) no `GET /pedidos_compras/{id}`, para o detalhe do pedido feito no Omie. Só API; **backend entregue em 29/09**, front em av-hub#106.
- **Vendas (28/09/2026):** [[26-Vendas-Liberacao-Pedido]] — liberação do pedido pelo vendedor (acompanhamento da Qualidade) e Fluxo 4 av-hub → MES. SQL + API + telas testados no local; telas mergeadas na `develop` do av-hub (#103, 28/09/2026); **backend entregue em 29/09**; **L4 do `api-pcp` concluído em 29/09** (Robert, conferido em 30/09). **(atualizado em 07/10)** A data de corte (`parametros_vendas`) já foi preenchida em 01/10 (28/07/2026); **falta só a chave própria do MES (L6, 🔴 Gustavo)**: a única chave própria que existe (`MES_INTEGRACAO_KEYS`) só abre o PUT do 34, então o MES lê `/pedidos_liberados` com chave admin ou do banco.
- **Realizados** — contratos já entregues. Pasta `Realizados/01-Contratos-SQL-DBA/`: [[001-Parceiros-Dados-Fiscais]], [[002-Estoque-Saldo]], [[003-Pedidos-Vendas-Frete-Parcelas]], [[004-Pedidos-Compras]], [[005-Locais-Estoque]], [[007-Ordens-Compra-Estruturada]], [[008-Requisicoes-Compra]]. Pasta `Realizados/02-Contratos-API/`: [[001-Produtos-Parceiros-Filtro-Incremental]]. Pasta `Realizados/03-Contratos-Logica-Fora-Backend/`: [[01-Compras-Fluxo-Completo]], [[02-Funcionarios-Listagem-Filtros-Ordenacao-Resumo]], [[03-Funcionarios-Cadastro-Organograma-Transacional]], [[04-Pedidos-Notas-Dashboards-Agregacao-no-Banco]], [[05-Permissoes-e-Escopo-no-Banco]], [[06-Ordenacao-Listagens]], [[07-Chave-Composta-Blacklist-Pedidos]], [[08-Itens-por-Parcela-Pedidos]], [[09-Ordenacao-Sistema-Vendedores]] e, em 28/09/2026 (Compras, backend na `api-test` + front mergeado no av-hub #104/#105): [[14-Compras-Omie-Pedido-Compra]] (01/10/2026: fluxos A e B testados, falta ligar em produção), [[04-Vagas-Fila-Decisao-no-Banco]] (01/10/2026: entregue, trava e §3.3.1 conferidas na `api-test`), [[09-Paginacao-por-Pedido-Vendas-Planilha]] (01/10/2026: entregue, `agrupar_por=pedido_venda` conferido na `api-test`), [[10-Compras-Pendencias-Pos-Backend]], [[11-Compras-Cotacao-Moeda-PTAX]], [[12-Compras-Projetos-Omie]], [[13-Compras-Backend-Consolidado]], [[14-Compras-Vinculo-Pedido-Venda]] e [[15-Compras-Historico-Unificado]]; em 29/09/2026 (históricos concluídos pelo 13): [[16-Compras-Pedido-DBA-Banco]] e [[17-Compras-Pedido-API-Backend]]. Em 07/10/2026: [[39-Vendedores-Fila-de-Vinculo]] (fila de vínculo dos vendedores; conferido em produção).

## Convenção de todo contrato

- **Status** no frontmatter (`proposta` / `aplicada` / `rejeitada`; também `substituida` e `invalidado`) — atualizar aqui quando o status mudar no mundo real, esta é a fonte de verdade sobre "o que já foi feito". **(07/10/2026)** `implementada-no-codigo` = o código em `main`/`develop` comprova, mas **falta conferir em produção/`api-test`**; só vira `aplicada` (e vai para `Realizados/`) depois dessa conferência.
- **Por quê** — motivação, sem jargão de implementação.
- **O contrato em si** — DDL exato (contratos SQL) ou request/response exato (contratos de API).
- **Perguntas em aberto** — o que precisa de decisão humana antes de aplicar. Nenhum contrato deveria ser aplicado com pergunta em aberto não respondida.
- **Depois de aplicado** — o que o dev precisa fazer no código depois que o outro lado (DBA, ou o próprio dev) aplicar a mudança.

## Origem

Os contratos SQL 001-006 desta seção nasceram como contratos 006-011 no
repositório `omie-elt-pipeline` (`sql/dba_migrations/`), onde os contratos
001-005 daquele repositório já existem com numeração própria (001, 002, 004
e 005 já aplicados; 003 rejeitado e mantido só como histórico). Os arquivos
originais nesse repositório agora apontam pra cá, para não duplicar/
desatualizar duas cópias — esta seção é a versão viva, com numeração
própria (001 em diante) independente da numeração do outro repositório.

## Status atual (21/09/2026 — confirmado contra dump de produção)

> **Atualização de 21/09:** o dump `dump-avhub_prd_db-202609210741.sql` (produção, gerado 21/09 07:41) mostra que 5 dos 6 contratos SQL e o contrato de API 001 **já estão aplicados** — este índice estava desatualizado desde 17/09. Ver o depara completo, coluna a coluna, em [[Auditoria-Dump-Producao-2026-09-21]]. Cada arquivo de contrato individual ainda precisa ter o próprio frontmatter `status` atualizado por quem tiver posse dele (não alterado aqui para não sobrescrever perguntas em aberto específicas de cada arquivo).

| Contrato | Tipo | Assunto | Status |
|---|---|---|---|
| [[001-Parceiros-Dados-Fiscais]] | SQL | `core.parceiros` + dados fiscais | **aplicada** (confirmado no dump 21/09; `dadosBancarios`/`enderecoEntrega` vêm por endpoint próprio; `chave_pix` ajustada para `varchar(255)`) |
| [[002-Estoque-Saldo]] | SQL | `core.estoque_saldo` (novo) | **aplicada** (confirmado no dump 21/09; "foto atual" confirmado como a implementação real). **(07/10, ✅)** sem função: o estoque do Omie é ignorado, tabela vazia, recurso `estoque` do pipeline não será ligado |
| [[003-Pedidos-Vendas-Frete-Parcelas]] | SQL | `pedidos_vendas` + frete/parcelas | **aplicada** (confirmado no dump 21/09) |
| [[004-Pedidos-Compras]] | SQL | `pedidos_compras` (novo) | **aplicada** — risco do `numero_item_omie` **resolvido na prática em 22/09** (design decidido em 21/09, migration confirmada no dump de 22/09): identidade do item é `(id_pedido_compra, ordem)`, com índice único aplicado |
| [[005-Locais-Estoque]] | SQL | `core.locais_estoque` (novo) | **aplicada** (confirmado no dump 21/09) — sem FK para `deposito` por decisão (tabela ainda não existe); Gustavo adiciona quando ela existir |
| [[006-Pedidos-Vendas-Valor-Devolucao]] | SQL | `pedidos_vendas.valor_devolucao` | **invalidado** (frontmatter do arquivo já dizia isso desde 17/09; este índice estava com a inconsistência I-02, agora corrigida) |
| [[009-Categoria-Sem-Escopo-Empresa-Views]] | SQL | `vw_vendas_planilha`, `vw_vendas_base`, `vw_nf_classified`, `vw_faturamento_planilha` — JOIN de `core.categorias` sem `codigo_empresa` | **aplicada** — conferido em produção em 06/10/2026 (pedido 25970: R$ 964.763,88; a contagem de linhas diverge: 53 na view contra 311 em `produto_vendas` no dump de 07/10, 🔴 ver o contrato) → `Realizados/` |
| [[001-Produtos-Parceiros-Filtro-Incremental]] | API | `?alterado_desde=` em produtos/parceiros (av-hub) | **aplicada** (confirmado em `src/routes/produtos.js`/`parceiros.js` em 21/09; **(atualizado em 07/10)** esses caminhos não existem mais: o código mora em `src/schemas/**` desde o PR #276) |
| [[002-Material-Alias-Omie-MES]] | API | `material_alias_omie` — vínculo de duplicata (destinatário: MES/Estoque) | **rejeitada em 21/09/2026** — decisão do Nathan: duplicata de catálogo sai do escopo deste sistema, resolve-se direto no Omie. Código removido do MES em 29/09 (`api-pcp` `0ac2596`) |
| [[003-Requisicao-Compra-Integracao-MES]] | API | Requisição de compra, MES → av-hub (Fluxo 1 da spec F1) | **atendido pelo [[34-Requisicoes-MES-Empurra-para-o-Hub]]** (06/10/2026): o MES empurra a requisição; o job de polling não será feito → `Realizados/`. (07/10: a rota `GET /requisicoes-compra` existe no MES e nenhum job do hub a consome; o MES chama o PUT do 34 desde `e7ce2c9`) |
| [[004-Referencia-OC-Integracao-MES]] | API | Referência da OC, av-hub → MES (Fluxo 2 da spec F1) | **proposta** — aprovada por Nathan em 22/09/2026; **revisado em 29/09/2026** (requisição por item, destino do item, OC cancelada, paginação); **30/09: Robert aprova o formato com um ajuste** (`id_origem` em cada item); rota `GET /ordens-compra/referencia` **ainda não existe** na API (o MES usa um registro manual da compra até lá); 🔴 com o Gustavo. **(conferido no código em 07/10)** continua inexistente na API **e no MES** (nenhum job de poll de OC); o ajuste `id_origem` por item segue pendente |
| [[005-Status-Item-Integracao-MES]] | API | Status por item, MES → av-hub (Fluxo 3 da spec F1) | **proposta** — aprovada por Nathan em 22/09/2026; **aprovada pelo Robert em 30/09/2026 com diferenças** (foto atual, `pedido_venda` + `ordem_producao`, etapas a mais); rota `GET /itens/status` **já existe no MES**; aceite do Nathan às diferenças: 🔴 (recomendado aceitar); consumidor: 🟡 `api-acos-vital` (Gustavo, F2). **(conferido no código em 07/10)** a rota existe no MES (`901f9bb`, só na `develop` do `api-pcp`); **nada no hub** (nem job, nem rota, nem tabela de status por item) |
| [[007-Ordens-Compra-Estruturada]] | SQL | `core_vendas_faturamento.ordens_compra` + itens + parcelas — OC decidida no av-hub (E2) | **aplicada** — confirmado em 23/09/2026 (`api-acos-vital` PR #273, junto com o 008); o aplicado difere do DDL em nomes e regras (ver o topo do arquivo). ~~Envio ao Omie ainda não existe~~ **(atualizado em 07/10)** o envio existe no código da pipeline (L4, `UpsertPedCompra`/`ExcluirPedCompra`; PR #1 mergeado em 05/10; fixo no código, direto ao Omie, sem flags, ✅ 07/10; falta conferir o deploy em produção) |
| [[008-Requisicoes-Compra]] | SQL | `core_vendas_faturamento.requisicoes_compra` (novo) — caixa de entrada de Compras (E1) | **aplicada** — confirmado em 23/09/2026 (`api-acos-vital` PR #273, junto com o 007); o aplicado difere do DDL em nomes e nulidade (ver o topo do arquivo) |

## Ver também
- [[Roteiro-de-Implementacao]]
- [[Decisoes-Chave-ERP]]
- [[Campos-e-API-para-Rastreabilidade]] — lista de tabelas, campos e endpoints novos para rastreabilidade; cada bloco vira contrato SQL ou de API aqui depois que a spec F1 for aprovada.
- [[Auditoria-Dump-Producao-2026-09-21]] e [[Auditoria-Dump-Producao-2026-09-22]] — depara completo contra dump de produção
- [[Chaves-de-Integracao-AvHub-MES-Pipeline]] — os 3 tipos de chave da API, `MES_INTEGRACAO_KEYS`, `AVHUB_MES_INTEGRACAO_KEY`, `API_KEY`, `MES_API_KEY`
- [[AV-Hub-API-Estado-Atual]] — estrutura atual da API (`src/schemas/**`), autenticação em camadas, `/docs`
- [[App-PCP-Recebimento-Conferencia]] — recebimento com conferência/recontagem/decisão do PCP no MES (07/10)
- [[Onde-Estamos]] — situação geral do projeto


## Contratos criados em 08–09/10/2026

> Todos escritos **a partir do código** (`origin/develop` da `api-acos-vital`, `dee35b0`) ou como proposta de correção da auditoria [[Auditoria-Pente-Fino-2026-10-08]]. Nenhum foi conferido em produção. O repositório da API não versiona SQL; por isso os contratos SQL abaixo descrevem a **interface exigida pelo código** e pedem ao DBA o DDL real.

| Contrato | O que é | Status |
|---|---|---|
| [[006-Status-por-Item-Leitura-no-Hub]] | Rota `GET /itens_pedido_status`, job de 90 s que lê o `GET /itens/status` do MES, escopo "dono" | `implementada-no-codigo` (hub). O front não consome. A rota não devolve 404: pedido sem dados volta 200 com `itens` vazio |
| [[010-Itens-Pedido-Status]] | SQL da migration `api005`: tabela, cursor, funções `fn_itens_pedido_status_gravar` e `_do_pedido`, mapa em `auth.rotas_telas` | `implementada-no-codigo`. 🔴 DDL real a fornecer pelo Gustavo; aplicação no banco não verificada |
| [[011-Ordens-Compra-Referencia-MES]] | SQL da migration `api004`: view `vw_ordens_compra_referencia_mes`, tabela da marca, trigger e índice | `implementada-no-codigo`. 🔴 DDL real a fornecer pelo Gustavo; sem a migration a rota dá 500 |
| [[45-Pedido-de-Venda-Manual]] | Pedido de venda manual (`/pedidos_vendas/manual`): identidade `MAN-`, rotas, convivência com o pipeline | `implementada-no-codigo`. O código o chama de "Contrato 30" (o 30 do vault é o PDF do pedido Omie). 🔴 `exclusionSync` e tela inexistente no front |
| [[40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]] | Escopo de vendedores e permissões pelo token (grupos A e B1 das gambiarras) | `proposta` (Gustavo) |
| [[41-Login-Rate-Limit-no-Backend]] | Limite de login na API, IP repassado pelo BFF | `proposta` |
| [[42-Coordenadores-e-Orcamento-sair-do-JSON-do-Repositorio]] | Coordenadores pela API e fim do orçamento em JSON | `proposta` |
| [[43-Ordem-das-Etapas-de-Faturamento-no-Cadastro]] | Reaproveitar `ordem_fluxo` de `core.etapas_faturamento` | `proposta` |
| [[44-Upload-de-Fotos-Politica-de-Bucket]] | Política de bucket para fotos (a validação do BFF fica) | `proposta` |

Divergência de pasta: a página da nota manual está em `dashboards/`, e o [[29-Notas-Fiscais-Manuais-So-Admin]] diz `cadastros/auxiliares`.
