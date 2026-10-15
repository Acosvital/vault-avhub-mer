---
id: LOG-52
aliases: ["Contrato 52", "52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub"]
tags: [contrato, contrato-logica, contrato-api, contrato-sql, comercial, suprimentos, api-acos-vital, api-comercial, migracao]
criado: 2026-10-15
atualizado: 2026-10-15
status: proposta
sistemas: [hub-banco, hub-api, hub-front]
dono: "Pablo"
etapa_0b: []
fontes: ["api-comercial (HUB b55ac55, pasta 00 - HUB/api-comercial: README, prisma/models/*.prisma, prisma/migrations, src/**, test/**)", "api-acos-vital 276dab8 (schemas/**, middlewares/**, utils/**)", "Dump Avhub (Esqueleto).sql", "HUB app/api/comercial/[...rota]/route.ts, lib/api/comercialApi.ts, services/comercial/*", "Registro-de-Decisoes N14-15", "auditoria de 15/10/2026"]
criado_original: 2026-10-15
---

# Contrato 52 — Migrar o módulo Comercial & Suprimentos para a API do av-hub e aposentar a `api-comercial`

> **Onde atua:** av-hub: banco, API, front

> [!info] Situação em 15/10/2026
> **Status:** `proposta` · **Pasta:** `Ativos` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Pablo (módulo) · **Banco e API:** Gustavo (DBA), dono da `api-acos-vital`
>
> - 📝 **A decisão já existe:** [[Registro-de-Decisoes]] N14-15 (14/10/2026): a `api-comercial` é uma API de teste do Pablo, **não será publicada**, e ele migra tudo para a `api-acos-vital`. Este contrato não decide *se* migra; propõe **como**, separando o que a API do hub já tem, o que precisa ser criado e o que deve ser descartado.
> - ✅ **Inventário feito em 15/10/2026** nos dois lados, por leitura de código: `api-comercial` (30 tabelas, 24 enums, 13 migrations, ~91 handlers, cerca de 300 testes) e `api-acos-vital` `276dab8` (124 tabelas, rotas por schema).
> - 🔴 Nada migrado. Nenhuma linha escrita na `api-acos-vital`.
> - 🟡 O desenho das seções 3 a 9 é **proposta**; as decisões que dependem do Nathan, do Pablo e do Gustavo estão na seção 13.
> - ❓ Não conferi: `auth.rotas_telas` e `auth.telas` em produção, o que a pipeline carrega de pedidos de compra, e nada foi executado.
>
> **Não confundir** com [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]]: aquele corrige a API que já existe; este traz o módulo novo para dentro dela. O módulo **tem de entrar já seguindo o LOG-51**, para não herdar o problema.

## 1. O que muda e o que fica

**Meta:** existir **uma só API** (`api-acos-vital`), um só banco (schemas por domínio, [[Schemas-Postgres]]), um só RBAC (`auth.rotas_telas` e `auth.telas`), um só envelope de erro e de paginação, uma só chave de serviço por sistema. A pasta `api-comercial/` do repositório do HUB sai, junto com `COMERCIAL_API_URL` e `COMERCIAL_API_KEY`. O Dockerfile, o CI próprio (`api-comercial.yml`) e a porta 3001 deixam de existir ([[Infraestrutura]]).

**O que não muda:** o front (`app/(protected)/comercial/*`, `suprimentos/*`), o BFF `app/api/comercial/[...rota]/route.ts` com a lista de rotas permitidas e os PDFs gerados no HUB. O BFF passa a apontar para a API do hub.

## 2. Princípios (valem para tudo abaixo)

1. **Não recriar o que a API do hub já tem.** Produtos, parceiros, pedidos de compra do Omie, PTAX, usuários, perfis, permissões, unidades e auditoria já existem; o módulo **usa** essas tabelas e rotas.
2. **O espelho some.** O que a `api-comercial` copiava do Omie ou do hub (produtos, fornecedores, pedidos de compra, usuários) é descartado; o que ela **acrescentava** (categoria, dimensões, perfil de compras, carteira, ofertas) vira tabela de extensão ligada à tabela do hub.
3. **Sem sincronização própria com o Omie.** Quem puxa do Omie é a `omie-elt-pipeline` ([[Pipeline-Omie]]). O módulo lê o banco.
4. **Token do usuário sempre.** Toda rota do módulo exige o token do usuário e passa por `auth.fn_autorizar`. Nunca "só chave de serviço" (esse é o furo S1 do LOG-51).
5. **Segurança de entrada.** O módulo entra **sem** os defeitos achados na auditoria do `api-comercial` (seção 10). Cada um vira critério de aceite.
6. **Tudo versionado.** O SQL do módulo (DDL, `GRANT`, linhas de `auth.rotas_telas` e `auth.telas`) entra no repositório, não "na mão" ([[Backlog-por-Frente]] BL-024).
7. **Regra de negócio no backend** (decisão do vault). O cálculo de preço, margem e custo, que hoje está em `src/domain/` do `api-comercial`, é portado como está, com os mesmos testes.

## 3. Tabelas: o que existe, o que criar, o que descartar

Das 30 tabelas do `core_comercial`: **22 migram** (criar na API do hub) e **8 são descartadas**. Na API do hub nascem **23 tabelas**: as 22 que migram mais `produtos_pendentes`, que hoje é uma marca (`pendente`) dentro de `produtos` e passa a ter tabela própria.

### 3.1 Descartar (8): o hub já tem ou não faz mais sentido

| Tabela do `api-comercial` | Por quê | Substituta no hub |
|---|---|---|
| `auditoria` | Já existe auditoria única | `auth.auditoria` ([[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] S17). Ações novas exigem `ALTER` do `CHECK` |
| `produtos_contas_omie` | Vínculo produto × conta Omie | `core.produtos` já é por `codigo_empresa` (`core.unidades`) |
| `fornecedores_contas_omie` | Idem, fornecedor | `core.parceiros` já é por `(codigo_empresa, codigo_parceiro_omie)` |
| `ordens_compra` (do comercial) | Espelho de pedido de compra do Omie | `core_vendas_faturamento.pedidos_compras` (a pipeline alimenta). **Não confundir** com `ordens_compra` do hub (a OC do circuito de compra) |
| `itens_ordem_compra` | Idem, itens | `core_vendas_faturamento.pedidos_compras_itens` |
| `omie_registros_brutos` | Payload cru e hash do motor de sincronização que sai | — |
| `sincronizacoes_omie` | Cursor da sincronização que sai | `omie_ctl.run_log` (log da pipeline) |
| `travas_tarefa` | Trava da sincronização que sai | — |

### 3.2 Reusar a tabela do hub e acrescentar uma extensão 1:1 (3)

| Conceito | Já existe no hub | O que o módulo acrescenta (criar) |
|---|---|---|
| **Usuário** | `auth.usuarios`, `auth.perfis`, `auth.permissoes`, `auth.telas`, `GET /me/permissoes` | `perfis_comerciais` **reduzida** às colunas que são do módulo (`email_av`, `email_au`, `email_hrm`, `celular`, `responsavel_proposta`), ligada por `id_usuario`. Sai o resto (nome, e-mail de login, `ativo`), que já está em `auth.usuarios`. Hoje o middleware copia o usuário do hub a cada acesso; isso acaba |
| **Produto** | `core.produtos` (`descricao`, `familias_produtos`, `ncm`, `especificacoes jsonb`; único por empresa), `core.familia_produtos`, view `vw_catalogo_de_produtos` | `produtos_perfil`: `id_categoria`, `norma`, `material`, `dn_pol`, `diametro_ext_mm`, `espessura_mm`, `kg_por_m`, `kg_por_pc` e as demais dimensões, `vendavel`. **Não** acrescentar colunas em `core.produtos` (a pipeline reescreve a tabela; ver [[Colunas-Protegidas]]) |
| **Fornecedor** | `core.parceiros` + `core.parceiros_tipos` (FORNECEDOR), views `vw_todos_os_fornecedores` e `vw_fornecedores_com_produtos` | `fornecedores_perfil`: `tipo_venda`, `regime_fiscal`, `email_cotacao`, `contato_compras`, `minimo_compra`, `entrega_certificado`, `origem_icms_padrao`, `prazo_padrao`, `provisorio`. Chave por `id_parceiro` do hub. O `api-comercial` unificava as duas contas Omie **por CNPJ**; no hub o parceiro é por empresa, então a visão única por CNPJ vira **view** (`vw_fornecedores_por_cnpj`) |

### 3.3 Criar (original do módulo, não existe no hub) (20: 19 originais e `produtos_pendentes`)

| Tabela | O que é | Observação de desenho |
|---|---|---|
| `clientes` | CRM do comercial: `documento` único (CPF/CNPJ), `id_responsavel`, `status`, `segmento`, `potencial`, `proximo_contato`, `versao` | **Não existe carteira por vendedor no hub** (`core.parceiros` não tem dono). Cliente comercial pode ser prospect sem cadastro no Omie, então a tabela é própria, com `id_parceiro` **opcional**. Ver Q3 |
| `clientes_contatos` | Compradores do cliente | FK com `ON DELETE CASCADE` |
| `propostas` | Núcleo: número por empresa, ano e sequencial, `revisao`, `status`, `cliente_snapshot`, `responsavel_snapshot`, totais `numeric(14,2)`, `valor_fechado`, `numero_pedido_omie`, `legado`, `versao`, `deleted_at` | Índices por responsável e por data (os três do Prisma) |
| `propostas_itens` | Itens com snapshot de custo, `configuracao` JSON (telha), certificados | |
| `propostas_eventos` | Linha do tempo (enum de 14 tipos) | |
| `propostas_versoes` | Histórico de revisões (`snapshot` JSON) | |
| `unidades_emissoras` | Dados do cabeçalho do PDF por empresa (AV, AU, HRM): conta Omie, CNPJ, IE, endereço, CRC e validade, textos padrão | Extensão 1:1 de `core.unidades`; conferir se `core.unidades` já tem IE e endereço (Q6) |
| `sequencias_proposta`, `sequencias_documento` | Numeração atômica (`INSERT … ON CONFLICT DO UPDATE … RETURNING`) | Em SQL cru; manter a atomicidade |
| `notificacoes` | Sino do menu | O hub não tem; o "403 das notificações" do HUB (PS-028) era disso |
| `categorias_suprimento` | 17 categorias (BARRAS, CHAPAS, TUBOS…) | Seed no DDL. **Não é** `core.categorias` (financeira do Omie) nem `core_compras.orc_categorias` (orçamento) |
| `apelidos_fornecedor` | Liga o nome do mapa de cotação ao fornecedor | |
| `fornecedores_categorias` | "Categorias que o fornecedor atende" (ativo ou suspenso) | |
| `certificados` | ISO 9001 e CRC Petrobras, validade, arquivo | `arquivo_key` existe e não achei upload no código ❓ |
| `ofertas` | Preço por fornecedor × produto, imutável, invalidável com motivo | Chave única `(fonte, id_documento_fonte, id_produto, id_fornecedor)`; fontes `MANUAL`, `MAPA_COTACAO`, `MIGRACAO`. As `PEDIDO_OMIE` passam a ser **derivadas** (ver 3.4) |
| `parametros_custo` | ICMS a recuperar, densidades, validade padrão, versionado por vigência | |
| `tabelas_custo_telha` | Custo da telha TR40, versionado por vigência | |
| `solicitacoes_custo` | Vendas pede custo a Compras | |
| `chaves_idempotencia` | `Idempotency-Key` por usuário, 24 h | infraestrutura; ver 7 |
| `produtos_pendentes` | Produto `PEND-xxxx` criado na proposta ou no mapa, ainda sem cadastro no Omie | Fica **fora** de `core.produtos` até o Omie criar o real e a pipeline trazê-lo; aí o vínculo move ofertas, itens de proposta e solicitações (hoje feito numa transação) |

*(Conta: 3.2 traz 3 extensões, que vêm de `perfis_comerciais`, `produtos` e `fornecedores`; 3.3 traz 19 tabelas originais e `produtos_pendentes`. Total 23 a criar; as 22 que migram do `api-comercial` mais a separação dos pendentes.)*

### 3.4 Ofertas vindas de pedidos de compra do Omie

Hoje o `api-comercial` lê **direto a API do Omie** (`PesquisarPedCompra`) e transforma cada item de OC em uma oferta `PEDIDO_OMIE` (IPI % derivado de `nValorIpi/nValMerc`, ST de `nValorSt/qtd`, desconto abatido do unitário). O motivo registrado no vault: o `GET /pedidos_compras` do hub vinha **vazio** na api-test e "não traz o que a tela precisa". A API do hub **já tem** `pedidos_compras`, `pedidos_compras_itens`, `_parcelas` e `_etapas`, alimentadas pela pipeline.

**Proposta:** a oferta `PEDIDO_OMIE` vira uma **view** (ou tabela materializada atualizada por trigger) sobre `pedidos_compras_itens`, com a mesma regra de custo líquido; **não** se escreve outra sincronização. Isso depende de a pipeline carregar os campos que a regra usa (IPI, ST, desconto, etapa, cancelado) e a janela (180 dias na carga, 60 na releitura). 🔴 É a **maior incógnita técnica** deste contrato: ver Q1.

## 4. Rotas: ~91 handlers, o que já existe e o que criar

Prefixo proposto: `/comercial/*` (propostas, clientes, custos, relatórios, dashboards, notificações, cadastros) e `/suprimentos/*` (catálogo, fornecedores, ofertas, pedido de cotação, painel do comprador). Caminhos em `snake_case`, como o resto da API; o BFF já traduz o `kebab-case` do front. Cada rota nova ganha linha em `auth.rotas_telas` (seção 8).

| Grupo (handlers no `api-comercial`) | Já existe na API do hub | Criar | Descartar |
|---|---|---|---|
| **cadastros** (6): `/me`, `/empresas_emissoras`, `/parametros_custo` GET e PUT, `/cambio`, `/responsaveis` | `GET /me/permissoes`; `GET /cotacoes_moeda/atual?moeda=` (PTAX); `GET /unidades` | `/comercial/me` (capacidades derivadas do token, sem chamar o hub por HTTP), `/comercial/empresas_emissoras`, `/comercial/parametros_custo`, `/comercial/responsaveis` | `/cambio` próprio (AwesomeAPI com *fallback* PTAX): usar só a PTAX do hub. Q5 |
| **propostas** (20): lista, resumo, detalhe, eventos, versões, criar, calcular, duplicar, fechar, perder, reabrir, editar, excluir, itens (importar e modelo), pedido Omie (+ xlsx), e-mail | — (o hub não tem proposta; `core_comissionamento.simulacoes` é de **comissão**, confirmado em `simulacoes.model.js`) | todas | — |
| **clientes** (17): lista, resumo, exportar, detalhe, propostas do cliente, por documento, Receita, criar, editar, contatos | `GET /todos_os_clientes` (parceiros tipo CLIENTE, sem dono) | todas | — |
| **suprimentos** (~28): produtos, fornecedores, categorias, ofertas, pesquisa de materiais, histórico de compras, painel do comprador, pedido de cotação, produtos pendentes, certificados, apelidos | `GET /produtos` (+ `/:id/fornecedores`), `/catalogo_de_produtos`, `/historico_precos`, `/todos_os_fornecedores`, `/fornecedores_com_produtos`, `/parceiros_produtos`, `/familias_produtos` | extensões (3.2) expostas, ofertas, pesquisa, painel, pedido de cotação, pendentes, certificados, apelidos | cópias de leitura de produto e fornecedor: servir pelas rotas do hub com `JOIN` na extensão |
| **custos** (12): sugerir, solicitações (listar, criar, assumir, liberar, responder, cancelar), telha (tabela, tabelas, calcular, salvar) | `GET /itens_pedido_custo` (custo **do lote**, vindo do MES, outro assunto: [[LOG-47-Custo-Real-por-Item-no-Hub]]) | todas | — |
| **dashboards, relatórios** (3) | `/dashboard/*` de vendas e comissão (outro domínio) | `/comercial/dashboards/comercial`, `/comercial/relatorios/cotacoes`, `/comercial/relatorios/gerencial` (JSON e XLSX) | — |
| **notificações** (3) | — | todas | — |
| **omie** (2): `/omie/sincronizacoes`, `/omie/sincronizar` | — | — | **ambas**. A tela "Sincronização Omie" (slug `sincronizacao-omie`) passa a mostrar o estado da pipeline (`omie_ctl.run_log`), somente leitura. Q4 |

**Rotas do BFF dedicadas a arquivo** (PDF, XLSX): o HUB continua gerando todos os **PDFs** (`@react-pdf/renderer`: proposta comercial, técnica, lote, aprovação interna, relatórios, cotação de materiais) e manda o PDF em base64 ao `POST /comercial/propostas/:id/email`. A API **lê e gera XLSX** (importar itens, importar mapa de cotação, pedido Omie, exportações); ver 7.

## 5. Integrações e jobs

| O que o `api-comercial` faz hoje | Destino |
|---|---|
| Sincroniza **produtos e fornecedores** do hub a cada 15 min (`fonteHub.ts`), com de-para de unidade de medida (~85 grafias) | **Some.** A pipeline já grava `core.produtos` e `core.parceiros`. O **de-para de unidade de medida** (`normalizacao.ts`) é regra do módulo e vem junto, aplicado na leitura/ao criar oferta |
| Sincroniza **pedidos de compra** direto do Omie | **Some** (ver 3.4). A pipeline é a fonte |
| Agendador, trava de tarefa, cursor, hash | **Somem** |
| **E-mail** (nodemailer): proposta ao cliente e pedido de cotação (1 e-mail por fornecedor) | **Criar** na API (a API do hub não tem e-mail). Variáveis `SMTP_*` novas. Ver Q7 (alternativa: ficar no BFF) |
| **Consulta de CNPJ** (BrasilAPI, fallback ReceitaWS) | **Criar** na API. Existe no servidor porque o CSP do HUB bloqueia o navegador |
| **Câmbio** (AwesomeAPI e PTAX do Banco Central) | **Descartar.** Usar `core.cotacoes_moeda` (PTAX, job da pipeline às 13h e 17h). Muda de "venda comercial" para PTAX: Q5 |
| **XLSX** (SheetJS por tarball) | Reescrever com biblioteca sem as falhas conhecidas. **Não portar o SheetJS 0.18** (falhas de poluição de protótipo e ReDoS afetam justamente a **leitura** de planilha enviada por usuário). Ver 7 |
| **Migração do ERP antigo** (`erp_quotations` do Supabase, `npm run migrar:erp-antigo`) | Script único: portar e rodar **uma vez** depois do corte, se ainda for necessário. Q9 |
| Limpeza de chaves de idempotência (oportunista) | Trocar por rotina agendada simples (ou `DELETE` na própria rota) |

## 6. Regra de negócio e domínio (portar como está)

`src/domain/` (1.218 linhas) é função pura, com `decimal.js`, e é a parte mais valiosa e mais fácil de levar. **Não mudar fórmula na migração**; mudar só o que está marcado.

| Arquivo | Regra | Observação |
|---|---|---|
| `calculo/linhaItem.ts` (88) | preço de venda `(custo × kg/m × metragem + pintura) × (1 + margem)`; subtotal, desconto, base, ICMS, IPI, ST | fórmulas "travadas contra o legado v3.4.41"; as fixtures citadas no código (`test/fixtures`) **não existem** no repositório ❓ |
| `calculo/totais.ts` (30), `calculo/fechamento.ts` (50) | total = Σ(base+IPI+ST) + frete (frete só com CIF); fechamento total e parcial proporcional | |
| `custo/custo.ts` (133) | custo líquido, `normalizarIpi`, seleção do custo vigente, margem real | **corrigir** `normalizarIpi` (ver seção 10, item 16): a heurística "≤ 1 vira × 100" vale **só** na importação do mapa, nunca na oferta digitada |
| `custo/medias.ts` (78), `custo/analiseCompras.ts` (94) | médias por fornecedor, última compra, resumos | |
| `numeracao/numeroProposta.ts` (63) | `CO-{AV\|AU\|HRM}{AAAA}-{NNNN}-R{RR}`, `PT-`, `SC-AAAA-NNNN` | |
| `validacao/documento.ts` (47) | CPF e CNPJ com dígito verificador | **corrigir** para CNPJ **alfanumérico** (seção 10, item 4) |
| `telha/configurador.ts` (120) | custo da telha TR40, núcleo EPS ou PIR, pintura | constantes `LARGURA_BOBINA_M` e `DENSIDADE_ACO` não conferi ❓ |
| `migracao/erpAntigo.ts` (323) | mapeia o ERP antigo para proposta | só se Q9 disser que ainda roda |
| `permissoes/capacidades.ts` (75) | telas × ações do hub → capacidades (`veValores`, `veCusto`, `comprador`, `podeDelegar`…) | **reescrever** sobre `req.autorizacao.telas` e `auth.fn_autorizar` da API (não chamar `/me/permissoes` por HTTP) |
| `permissoes/perfisDev.ts` (117) | 6 perfis fictícios para teste | **não migrar** (nunca existir em produção) |

**Regras que moram nas rotas e precisam de lugar no serviço:** SLA da solicitação de custo (2 dias úteis), trava de escala (preço fora de 1/3 a 3 vezes a mediana pede confirmação), fuso `America/Sao_Paulo`.

## 7. O que a API do hub ainda não tem e precisa ganhar (transversal)

Estes itens beneficiam a API toda, não só o módulo. Eles entram **antes** das rotas.

| # | Item | Hoje na API do hub | Hoje no `api-comercial` | Proposta |
|---|---|---|---|---|
| T1 | **Dinheiro e quantidade exatos** | `numeric` vira `string` no `pg`, e as rotas convertem com `Number()` (perde precisão em `numeric(18,6)`) | `decimal.js`, valores como string | Adicionar `decimal.js`; **nunca** `Number()` em dinheiro do módulo. O domínio portado já usa Decimal |
| T2 | **Validação de entrada por esquema** | manual por rota (`pick`, regex) | `zod` 4 | Adotar `zod` nas rotas **novas** (e, aos poucos, nas antigas: S4 e S22 do LOG-51). Mensagens em pt-BR |
| T3 | **Concorrência otimista** (`versao`, `ETag`, `If-Match`; 428 sem o cabeçalho, 409 `VERSAO_DESATUALIZADA`) | não existe | propostas e clientes | Middleware genérico em `utils/`. O BFF não repassa o `ETag`; o front reenvia `If-Match: "<versao>"` com a `versao` do corpo (já é assim) |
| T4 | **Idempotência** (`Idempotency-Key`, 24 h, por usuário, hash do corpo) | só por chave de negócio (`upsertByKey`) | `POST /propostas`, `duplicar`, `POST /solicitacoes_custo` | Middleware genérico. **Corrigir** o escopo da chave: incluir método e caminho completo, não só o corpo (seção 10, item 14) |
| T5 | **Erro dentro de handler `async`** | Express 4 não encaminha erro assíncrono sozinho | Express 5 encaminha | Wrapper `asyncHandler` (ou `express-async-errors`). Sem isso, um `throw` num handler derruba a requisição sem resposta |
| T6 | **Testes e CI** | nenhum | cerca de 300 casos, Vitest e supertest contra Postgres real | Adicionar Vitest e CI na API ([[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] S9). Os 137 testes unitários de `domain` são reaproveitáveis quase como estão; os 167 de integração precisam de reescrita (Prisma e `criarApp()`) |
| T7 | **XLSX** | nenhuma biblioteca no backend | SheetJS por tarball (lê e escreve) | Escolher biblioteca mantida e sem as falhas (por exemplo `exceljs`, ou SheetJS oficial 0.20 do CDN da fornecedora). Limite de tamanho e de linhas nas rotas que leem planilha |
| T8 | **E-mail** | nenhum | `nodemailer` | `nodemailer` na API, com `EMAIL_TRANSPORTE=memoria` nos testes |
| T9 | **Envelope de paginação** | `{ total, page, totalPages, limit, [chave]: rows }`, limite 200 | `{ data, total, page, limit, total_pages }`, limite 100 | **Proposta:** o módulo adota o do hub (uma convenção só); o BFF e `services/comercial/*` (14 arquivos) adaptam. Ver Q8 |
| T10 | **Logs estruturados** | `console.log` | `pino` com `x-request-id` | Opcional; **mascarar** CPF e CNPJ que hoje vão na URL (seção 10, item 11) |
| T11 | **Esquema novo e DDL versionado** | schemas criados no boot, sem SQL no repositório | 13 migrations Prisma | Schema `core_comercial` criado **por migration** (não no `app.js`), com `GRANT`, e `pg_trgm` e índices GIN para a busca em 88 mil produtos. Converter as 13 migrations do Prisma em SQL numerado entregue ao DBA |

## 8. Permissões, telas e escopo

### 8.1 Como uma rota nova nasce na API do hub

1. Montar o router em `src/schemas/core_comercial/index.js` (e o import em `schemas/index.js`, o `CREATE SCHEMA` por migration, e a linha em `docs/grupos.js`).
2. O DBA insere linhas em `auth.rotas_telas` (`metodo`, `rota`, `slug_tela`, `acao`, `escopo_vendedor`).
3. Cadastrar o slug em `auth.telas` e conceder em `auth.permissoes` aos perfis certos.
4. Sem linha em `auth.rotas_telas`, a rota dá **403** `ROTA_SEM_PERMISSAO_MAPEADA` (a API nega por padrão): é a rede de segurança contra esquecer uma guarda.

### 8.2 Slugs

- **Já consultados pela API hoje (7):** `propostas`, `propostas-delegacao`, `propostas-valores`, `custo-item`, `relatorio-gerencial`, `painel-comprador`, `clientes`.
- **Usados só no BFF, sem guarda na API (13):** `solicitacoes-custo`, `ofertas-fornecedor`, `pedido-cotacao`, `catalogo-produtos`, `fornecedores`, `historico-compras`, `parametros-custo`, `tabela-telha`, `sincronizacao-omie`, `matriz-precos`, `pesquisa-materiais`, `relatorio-cotacoes`, `dash-comercial`. Na API do hub **cada um vira linha em `auth.rotas_telas`**, o que fecha de uma vez as rotas de leitura que no `api-comercial` só pediam estar autenticado (seção 10, item 5).
- Os 20 slugs precisam estar em `auth.telas` de produção. ❓ O vault diz que isso não está cadastrado (Q2).

### 8.3 Escopo de vendedor: o conceito muda

No `api-comercial`, o escopo é por **usuário dono** (`id_responsavel` da proposta e do cliente): `PROPRIAS`, `COMPARTILHADA` (que na prática **não restringe nada**) e `TODAS`. No hub, `escopo_vendedores` (`todos`, `vinculados`, `proprios`) é por **vendedor do Omie** (`auth.fn_vendedores_do_usuario`, via `vendedores.id_funcionario`, `auxiliar_vendedor` e `diligenciador_vendedor`) e só vale em rotas listadas no mapa `ROTAS` de `middlewares/escopoVendedor.js:165`.

**Proposta:** proposta e cliente continuam pertencendo a um **usuário** (`id_responsavel`). `proprios` = o próprio usuário; `todos` = sem filtro; `vinculados` = os usuários cujos vendedores estão no vínculo do usuário logado (auxiliar e gestor), calculado com `auth.fn_vendedores_do_usuario`. O filtro entra **no `WHERE`, por interseção com o escopo**, nunca por sobreposição (é exatamente o bug 1 da auditoria do `api-comercial`, seção 10). Q3 pede a confirmação do significado de `vinculados` ao Nathan, ao Pablo e ao Gustavo.

## 9. Lado do HUB (Nathan): o que muda no front e no BFF

| # | O quê |
|---|---|
| F1 | `lib/api/comercialApi.ts` e `app/api/comercial/[...rota]/route.ts`: trocar o destino para `API_URL` do hub, com os caminhos novos (`/comercial/...`, `/suprimentos/...`). Manter a lista de rotas permitidas, a tradução `kebab` para `snake` e a regra "todo POST devolve 201, salvo `calcular`" (ou alinhar com a API) |
| F2 | Remover `COMERCIAL_API_URL` e `COMERCIAL_API_KEY` do ambiente do HUB |
| F3 | Adaptar `services/comercial/*` (14 arquivos, ~1.100 linhas) ao envelope de paginação do hub (T9) |
| F4 | Tela "Sincronização Omie": passa a ler o estado da pipeline (Q4) |
| F5 | As 13 rotas dedicadas do BFF (PDF e XLSX) continuam; só o destino das chamadas internas muda |
| F6 | Tirar do BFF a guarda que só existia porque a API aceitava "estar logado": com a API fechada (seção 8.2) o BFF deixa de ser a **única** proteção das leituras. Manter a guarda no BFF também (defesa em profundidade) |
| F7 | Apagar a pasta `api-comercial/`, o `api-comercial.yml`, o `e2e-comercial.yml` (ou apontar para a API do hub) e o `docker-compose` da pasta |

## 10. O que **não** pode ser herdado (achados da auditoria do `api-comercial`)

Cada linha é **critério de aceite** do módulo na API do hub. A numeração é a da auditoria de 15/10.

| # | Defeito no `api-comercial` | Regra para o módulo novo |
|---|---|---|
| 1 | **Crítico.** `?responsavel=<outro>` sobrescreve o escopo `proprios` em `propostas.service.ts:148,152`, `clientes.routes.ts:69,73` e `relatorios.service.ts:227`; o vendedor lê propostas, valores e a carteira de colegas (inclusive exporta CNPJ, e-mail e telefone em XLSX). Quebra o RN-090 e a LGPD | Filtro **por interseção** com o escopo; teste de isolamento (vendedor A × B) em lista, resumo, relatório, exportação e clientes |
| 2 | **Crítico.** O escopo `COMPARTILHADA` (`vinculados`) é igual a `TODAS` (`propostas.service.ts:26-28`, `clientes.routes.ts:31-33`) | Implementar `vinculados` de verdade (8.3) |
| 3 | **Alto.** A sincronização grava o hash do registro **antes** de gravar o dado; uma falha perde o registro até o Omie alterá-lo de novo (`sincronizacao.ts`) | Some com a sincronização (a pipeline cuida). Se a regra voltar, gravar o hash **depois** do sucesso e na mesma transação |
| 4 | **Alto.** CNPJ alfanumérico (vigente desde julho/2026) é rejeitado: `somenteDigitos` tira as letras (`documento.ts:234`) e a coluna é `VarChar(14)` "só dígitos" | Normalizar para `[0-9A-Z]` maiúsculo, calcular o dígito verificador com valor ASCII menos 48, manter `VarChar(14)`; ajustar máscara, Receita e a leitura de fornecedor. *Conhecimento geral sobre a IN RFB 2229/2024; a data de vigência não foi conferida na fonte* |
| 5 | **Alto.** Leituras sem guarda de capacidade: `suprimentos.routes.ts:29,72,152,192,202,248,274,444`, `cadastros.routes.ts:37,135`, `produtosPendentes.ts:485`. Qualquer token válido (até de outra área) exporta a base de fornecedores (CNPJ, e-mail, contato, mínimo de compra, certificados) | Toda rota com linha em `auth.rotas_telas` (8.2) |
| 6 | **Alto.** O cliente criado dentro da proposta sobrescreve o cadastro mestre de **outro vendedor**, sem auditoria (`propostas.service.ts:301-305`, `upsertCliente`) | Só criar se não existir; se existir, atualizar só para o dono ou quem edita terceiros; gravar a diferença no snapshot da proposta, sem tocar no mestre |
| 7 | **Alto.** Editar proposta alheia passa a posse para o editor quando ele não pode delegar (`propostas.service.ts:263`) | Manter `id_responsavel` salvo com permissão de delegar; gravar evento de reatribuição |
| 8 | **Médio.** Custo e origem do custo vêm do cliente sem verificação; `PUT` é substituição total e apaga custo e margem quando o corpo veio sem `veCusto` | Ignorar campos de custo sem `veCusto` e **preservar** os gravados; validar oferta e produto contra o banco |
| 9 | **Médio.** `GET /propostas/:id/versoes/:revisao` vaza frete e câmbio a quem não vê valores (`propostas.service.ts:946`) | Aplicar o mesmo corte de `serializar` ao cabeçalho |
| 10 | **Médio.** E-mail da proposta é um *relay* aberto para quem vê a proposta (até 10 destinatários e 10 cópias, assunto, corpo e 2 PDFs livres); sem idempotência; o evento é gravado depois do envio; a mensagem do SMTP volta ao cliente | Capacidade própria de envio; destinatários do cliente da proposta ou lista permitida; limite por usuário; idempotência; gravar o evento **antes** (caixa de saída); não devolver o texto do SMTP |
| 11 | **Médio.** CPF e CNPJ vão para o log pela URL (`app.ts:41`, `clientes.routes.ts:218,232`); o comentário do logger diz o contrário | Mascarar no *serializer*, ou mandar o documento no corpo; rever a retenção dos logs |
| 12 | **Médio.** Padrões inseguros: `DOCS_ENABLED` ligado se não definido; `API_KEYS` com valor de exemplo aceito (`dev-chave-local` no compose); `JWT_ISSUER` e `JWT_AUDIENCE` opcionais, algoritmo não fixado | Documentação desligada em produção; recusar chave curta ou de exemplo; emissor e audiência obrigatórios (a API do hub já fixa `HS256` e `iss`) |
| 13 | **Médio.** Corpo JSON de 8 MB lido antes de autenticar | Limite pequeno por padrão e maior só nas rotas que precisam, depois da chave ([[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] S15) |
| 14 | **Médio.** A chave de idempotência não considera a rota, só o corpo: duas duplicações de propostas diferentes com a mesma chave e corpo vazio devolvem a primeira (`idempotencia.ts:25-26`) | Hash com método e caminho completo; tratar chave presa (`status_http` nulo) |
| 15 | **Médio, confiança média.** `duplicar` provavelmente falha com item de pintura sem custo e margem: o preço vira `null` (`propostas.service.ts:818`) | Guardar o preço-base manual separado do final; só tratar como automático com custo **e** margem |
| 16 | **Médio.** `normalizarIpi` (≤ 1 vira × 100) vale também na oferta digitada: IPI `1` vira 100% e o custo líquido dobra (`suprimentos.routes.ts:694`) | Heurística só na importação do mapa; na oferta digitada, o percentual literal |
| 17 | **Médio.** Sem FK em `id_produto`, `id_oferta`, `id_proposta_origem`, `id_proposta` das solicitações, sem índice em `propostas.id_cliente` e `clientes.id_responsavel`, e **nenhum `CHECK`** | Criar FKs, índices e `CHECK` (valores ≥ 0, `versao ≥ 1`, `valor_fechado ≤ total_geral`, status coerente com datas) no DDL; busca por razão social com `pg_trgm` |
| 18 | **Médio.** Sem auditoria de cliente e contato; contatos apagados de verdade; parâmetros e telha atualizam no mesmo dia sem guardar o valor anterior | `auth.auditoria` com antes e depois ([[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] S17); `deleted_at` em cliente e contato |
| 19 | **Médio.** `id_responsavel` de cliente não é validado | Reaproveitar `resolverResponsavel` |
| 20 | **Médio.** `POST /clientes` devolve o `id` de um cliente fora da carteira do usuário | Não devolver o `id` fora do escopo |
| 21 | **Médio.** A importação do mapa ignora correção de preço: a chave "já importado" não inclui o preço | Incluir o hash do conteúdo, ou avisar "mesma chave, preço diferente" na prévia |
| 22 | **Médio.** `db:mock` faz `TRUNCATE … CASCADE` e só recusa `NODE_ENV=production` | Recusar quando o host do banco não for local; não levar o seed de teste para a API |
| 23 | **Médio.** Pedido de cotação envia até 200 e-mails em sequência dentro da requisição, sem idempotência | Fila de envio assíncrona, ou idempotência |
| 24 | **Médio.** Importação de itens lê `1.234` como 1,234 | Ponto de milhar quando seguido de exatamente 3 dígitos; avisar a ambiguidade |

## 11. Fases, ordem e quem faz

Como a `api-comercial` é API de teste (sem dado de produção), **não há migração de dados**: só seed e, se Q9 mandar, a carga do ERP antigo.

| Fase | O que entra | Quem | Pronto quando |
|---|---|---|---|
| **0** | Responder as perguntas da seção 13, **em especial Q1 (pedidos de compra na pipeline), Q2 (rotas e telas em produção) e Q3 (significado de `vinculados`)**. Corrigir o que o módulo herdaria ([[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] S1 a S6: chave de serviço, Azure, senha, mass assignment, limite, erro) | Gustavo, Nathan | Respostas registradas nesta nota |
| **1** | Base: schema `core_comercial` por migration com `GRANT`; os 11 itens transversais da seção 7 (T1 a T11); `alterado_desde` corrigido (seção 12) | Gustavo (banco e API), Pablo (revisão) | `npm test` verde na API; o módulo cadastros de exemplo responde com token e `403` sem linha em `auth.rotas_telas` |
| **2** | Domínio portado (seção 6) com os 137 testes unitários; `unidades_emissoras`, `parametros_custo`, `tabelas_custo_telha`, rotas de cadastros e de telha | Pablo | Os testes dourados de cálculo passam; o PDF de uma proposta de teste sai igual ao do `api-comercial` |
| **3** | Clientes, propostas (com `If-Match` e idempotência), eventos, versões, e-mail, importar itens, pedido Omie | Pablo | Critérios 1, 2, 4, 6 a 10, 14, 15, 19 a 21 e 24 da seção 10 com teste; ciclo completo no HUB de homologação |
| **4** | Suprimentos: extensões de produto e fornecedor, ofertas, mapa de cotação, certificados, apelidos, pesquisa, painel do comprador, pedido de cotação, solicitações de custo, pendentes | Pablo | Critérios 3, 5, 12, 16, 17, 18 e 23 com teste |
| **5** | Ofertas `PEDIDO_OMIE` sobre `pedidos_compras_itens` (3.4), se a pipeline entregar os campos; senão, ajuste da pipeline (**decidir antes, Q1**) | Gustavo (pipeline e banco), Pablo | O painel do comprador mostra preço vindo de OC do Omie sem sincronização própria |
| **6** | Corte no HUB: `comercialApi.ts` apontando para a API do hub (F1 a F7); desligar e apagar `api-comercial/` | Nathan | A suíte e2e do Comercial e Suprimentos do HUB passa contra a API do hub |
| **7** | Aposentadoria do que fica sem uso: `orc_*` e as rotas `/orcamento/*` (o módulo comercial substitui o orçamento, [[LOG-42-Coordenadores-e-Orcamento-sair-do-JSON-do-Repositorio]]); `core_compras.orc_*` só depois do Nathan confirmar o corte do orçamento (BL-046) | Gustavo, Nathan | Decidido em LOG-42, não aqui |

## 12. Pré-requisito: o filtro incremental da API do hub está quebrado

Achado durante este inventário (✅ relido em 15/10/2026): em `src/schemas/core/tables/parceiros/parceiros.route.js:96` e em `src/schemas/core/tables/produtos/produtos.route.js:51` o filtro `alterado_desde` fica **depois** de `return where;`. Ele **nunca executa**, embora o contrato [[API-001-Produtos-Parceiros-Filtro-Incremental]] esteja como entregue. O `api-comercial` contornava ordenando por `updated_at` e parando na primeira página anterior ao cursor. Nada na migração precisa dele (a sincronização some), mas o contrato 001 está marcado `implementado-no-codigo` e **não está**; corrigir (mover o bloco para antes do `return`) ou rebaixar o status. Também está no [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] (S27).

## 13. Perguntas

| # | Pergunta | Quem | Bloqueia |
|---|---|---|---|
| Q1 | 🔴 A pipeline carrega `pedidos_compras` e `pedidos_compras_itens` em produção com **IPI, ST, desconto, etapa e cancelado** e na janela de 180/60 dias? O `GET /pedidos_compras` vinha vazio na api-test: era dado ausente ou rota que não devolve o que a tela precisa? | Gustavo | 3.4 e fase 5 |
| Q2 | 🔴 Quais dos 20 slugs já existem em `auth.telas` de produção, e quais perfis os têm? (O vault diz que o cadastro está pendente.) | Gustavo | 8.2, fase 1 |
| Q3 | 🔴 `vinculados`, para propostas e clientes: os usuários dos vendedores que o usuário logado acompanha (por `vendedores`, `auxiliar_vendedor` e `diligenciador_vendedor`)? O gestor enxerga o time? Cliente comercial sem pedido no Omie tem dono por `id_responsavel`? | Nathan, Pablo, Gustavo | 8.3, critérios 1 e 2 |
| Q4 | 🟡 A tela "Sincronização Omie" some ou vira leitura do estado da pipeline (`omie_ctl.run_log`)? Alguém dispara sincronização manual hoje? | Nathan, Pablo | F4 |
| Q5 | 🟡 Câmbio: aceitar só a **PTAX** do hub (fechamento do dia, `cotacoes_moeda`) no lugar da cotação de venda (AwesomeAPI) que o vendedor vê hoje? | Pablo, Compras | 5 |
| Q6 | 🟡 `core.unidades` já tem inscrição estadual, endereço e CRC? Ou `unidades_emissoras` guarda tudo? | Gustavo | 3.3 |
| Q7 | 🟡 E-mail e consulta de CNPJ ficam **na API** ou no **BFF** do HUB (que já gera os PDFs e é servidor)? Sugestão: na API, para um só lugar com segredo e registro de evento | Nathan, Gustavo | 5 e 7 |
| Q8 | 🟡 Envelope de paginação: o do hub (`{ total, page, totalPages, limit, [chave] }`, limite 200) ou o atual do módulo? Sugestão: o do hub | Nathan | T9, F3 |
| Q9 | 🟡 A carga do ERP antigo (`erp_quotations`) ainda vai rodar? Se sim, quando e quem tem o JSON? | Pablo | 5 e fase 2 |
| Q10 | 🟡 **Quem escreve o código na `api-acos-vital`?** A decisão N14-15 diz "o Pablo migra". A API é do Gustavo (banco e API). Proposta: o Pablo escreve o módulo num *branch*, o Gustavo revisa e faz o DDL, o `GRANT` e as linhas de permissão | Nathan | todas as fases |
| Q11 | 🟡 Cronograma: CS5 "Publicar o `api-comercial`" ([[Cronograma]]) deixa de existir e vira "migrar para a `api-acos-vital`" (fases acima). Quando? A capacidade do Pablo está fora do plano ([[Equipe-e-Divisao]]) | Nathan | prazo |

## 14. Testes de aceite

| # | Teste | Resultado esperado |
|---|---|---|
| M1 | Vendedor A chama `GET /comercial/propostas?responsavel=<id de B>`, `/resumo`, `/relatorios/cotacoes?formato=xlsx` e `GET /comercial/clientes/exportar?responsavel=<id de B>` | Nenhum dado de B; o filtro vira interseção e devolve vazio |
| M2 | Usuário **sem** perfil comercial, com token válido, chama `GET /suprimentos/fornecedores/exportar` e `/comercial/clientes` | 403 `sem_permissao` (rota mapeada) |
| M3 | Qualquer rota nova **sem linha** em `auth.rotas_telas` | 403 `ROTA_SEM_PERMISSAO_MAPEADA` |
| M4 | Rota do módulo chamada só com a chave do BFF, sem `Authorization` | 401 `TOKEN_USUARIO_AUSENTE` ([[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] S1) |
| M5 | Cadastrar cliente com CNPJ alfanumérico válido (`12ABC34501DE35`, exemplo da regra) | 201; dígito verificador calculado por ASCII menos 48 |
| M6 | `PUT /comercial/propostas/:id` sem `If-Match`, com `If-Match` velho e com o certo | 428; 409 `VERSAO_DESATUALIZADA`; 200 |
| M7 | Duas `POST /comercial/propostas/:id/duplicar` de propostas diferentes com a mesma `Idempotency-Key` e corpo vazio | cada uma cria a sua cópia (a chave inclui o caminho) |
| M8 | `PUT` de proposta por usuário **sem** `veCusto`, com o corpo devolvido pelo `GET` | custo e margem gravados **preservados**, não zerados |
| M9 | Vendedor cria proposta para um CNPJ que está na carteira de outro vendedor | o cadastro do outro vendedor **não muda**; só o snapshot da proposta |
| M10 | Oferta digitada com IPI `1` | grava 1%, não 100% |
| M11 | Duplicar proposta com item de pintura e preço manual | 201, preço do item preservado |
| M12 | Enviar e-mail de proposta duas vezes seguidas (duplo clique) | um só envio, uma só linha de evento |
| M13 | Corpo de 5 MB em rota comum, sem chave | 413 ou 401, sem processar o corpo |
| M14 | Suíte do HUB (e2e Comercial e Suprimentos, 17 testes) apontando para a API do hub | verde |
| M15 | `GET /comercial/produtos_pendentes` e vínculo de pendente com produto real que a pipeline trouxe | ofertas, itens de proposta e solicitações movidos numa transação; o pendente fica inativo |

## 15. Riscos e rollback

- **Pedidos de compra sem os campos que a regra de custo usa (Q1).** Sem eles, o preço vindo de OC do Omie some do painel do comprador. Mitigação: confirmar antes da fase 5; se faltar, ajustar a pipeline (que é do Gustavo) em vez de escrever outra sincronização.
- **A API do hub sem teste hoje.** Entrar com 22 tabelas e ~91 rotas novas numa API sem teste e sem CI é arriscado. Mitigação: fase 1 só termina com os testes rodando (T6).
- **Express 4 e 5 diferem no erro assíncrono.** Código portado do Express 5 sem `asyncHandler` deixa requisição pendurada. Mitigação: T5 na fase 1; teste de `throw` num handler.
- **Conflito de escopo (8.3).** `vinculados` mal definido repete o vazamento. Mitigação: Q3 respondida antes da fase 3; M1 como teste obrigatório.
- **Um schema novo precisa de DBA.** O repositório não versiona SQL e o Sequelize nunca faz `sync`; sem o DDL entregue, nada sobe. Mitigação: converter as 13 migrations do Prisma em SQL logo na fase 1 e deixar o Gustavo aplicar em homologação.
- **Rollback:** enquanto o corte do HUB (fase 6) não acontecer, a `api-comercial` de teste continua funcionando; cada fase é aditiva (rotas novas, tabelas novas). Se o corte der errado, voltar `COMERCIAL_API_URL` e `COMERCIAL_API_KEY` no HUB (por isso apagar a pasta só **depois** da suíte verde em homologação, passo F7).

## 16. O que não foi conferido

- `auth.rotas_telas` e `auth.telas` em produção; o schema `core_comercial` publicado (não existe no dump, a migration inicial faz `CREATE SCHEMA IF NOT EXISTS`).
- O que a pipeline carrega de `pedidos_compras` (conferi o vault, não o código dela).
- O corpo completo de `relatorios.service.ts`, `dashboards.routes.ts` e `pedidoOmie.ts` do `api-comercial` (li guardas e assinaturas); as fixtures "dourados" de cálculo citadas no código; o upload de certificado; as constantes da telha.
- Se `empresas_emissoras`, `notificacoes` e `clientes` duplicam algo que já exista no hub além do que está nesta nota.
- Se o SMTP está configurado em produção (o vault marca ❓).
- Nenhuma rota foi executada; os cerca de 300 testes não foram rodados nesta sessão.

## 17. Ligações

[[API-Comercial]] · [[Comercial-Suprimentos]] · [[AV-Hub-API]] · [[Banco-AvHub]] · [[Schemas-Postgres]] · [[RBAC-e-Permissoes]] · [[Pipeline-Omie]] · [[Colunas-Protegidas]] · [[Mapa-Rotas-BFF-Bearer]] · [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] · [[LOG-42-Coordenadores-e-Orcamento-sair-do-JSON-do-Repositorio]] · [[LOG-47-Custo-Real-por-Item-no-Hub]] · [[Registro-de-Decisoes]] (N14-15) · [[Backlog-por-Frente]] (BL-046, BL-047, BL-062, BL-063) · [[Riscos]] (RS-021)
