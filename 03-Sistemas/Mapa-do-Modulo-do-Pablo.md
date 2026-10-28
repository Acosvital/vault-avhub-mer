---
tags: [pesquisa, comercial, suprimentos, api-comercial, proposta, orcamento, mapa, staging]
criado: 2026-10-16
atualizado: 2026-10-16
status: proposta
dono: Pablo
fontes: [av-hub 5aa5311 (branch feat/menu-orcamento-vendas-compras) api-comercial/prisma/models e prisma/migrations, api-comercial/src/modules e src/domain, api-comercial/README.md, app/api/comercial/[...rota]/route.ts, app/(protected)/vendas orcamento compras, components/Propostas Suprimentos PainelComprador, lib/domain/fluxo-suprimentos.ts, docs/ENVIAR - contrato-comercial-suprimentos-telas.md, Dump Avhub (Esqueleto).sql, omie-elt-pipeline src/jobs/envioOrdensCompra.ts, 00-Briefing-Decisoes]
---

# Mapa do módulo do Pablo (Comercial e Suprimentos), como está hoje

Este mapa descreve o código de teste `av-hub\api-comercial` (N14-15, N16-15) e o que as decisões N16 mudam nele. Cada fato do código traz arquivo e linha (✅). Decisão traz o ID `N16-xx` (📝). O que é proposta nova leva 🟡. O que não deu para conferir leva ❓ ou 🔴. Os desenhos que nascem daqui estão em [[SQL-016-Proposta-e-Pedido-de-Venda-em-core_vendas_faturamento]], [[SQL-017-Orcamento-em-core_vendas_faturamento-Base-de-Preco-e-Pedido-de-Custo]] e [[SQL-018-Schema-core_comissao-Comissao-da-Proposta]]. Decisões: [[Registro-de-Decisoes]].

Caminhos abaixo são relativos a `av-hub\api-comercial\` quando não dizem o contrário.

## 1. Em uma página

| Item | Valor | Selo |
|---|---|---|
| O que é | Backend Express 5, TypeScript, Prisma 7, PostgreSQL schema `core_comercial`, porta 3001 | ✅ `README.md:3-7`, `src/app.ts` |
| Tamanho | 30 models, 24 enums, 13 migrations, cerca de 91 handlers | ✅ `prisma/models/*.prisma`, `prisma/migrations/` |
| Situação | API só de teste, não será publicada; o Pablo migra tudo para a `api-acos-vital`; o Gustavo revisa e cria no banco | 📝 N14-15, N16-15 |
| Banco publicado | Não existe `core_comercial` no dump do hub | ✅ `Dump Avhub (Esqueleto).sql` (só há `core_comissionamento`, `core_compras`, `core_vendas_faturamento` e outros; nenhum `CREATE SCHEMA core_comercial`) |
| Permissão | 100% do RBAC do hub: telas × ações e escopo de vendedores viram "capacidades" | ✅ `src/domain/permissoes/capacidades.ts:8-19,64-84` |
| Front | Telas em `app/(protected)/vendas`, `orcamento` e `compras/historico-compras`; BFF em `app/api/comercial/[...rota]/route.ts` | ✅ |
| Cadastro das telas | Feito pelo Nathan na api-test em 16/10; em produção o Gustavo roda o SQL | 📝 N16-14, `06-Contratos/Ativos/LOG-57-anexos/telas-vendas-orcamento-compras.sql` |

> [!info] O que não migra (27/10/2026)
> O módulo é só ambiente de teste e **não tem dado** (Nathan, N16-109). Para a migração, a lista do que **não portar** (sincronização própria do Omie e suas 7 tabelas de cópia, Histórico de compras, planilha do pedido no Omie, migração do ERP antigo, fechamento parcial, autenticação própria) e do que **reaproveitar** (motor na API, ofertas, fornecedores, parâmetros, pedido de custo, notificações) está em [[LOG-62-Reescopo-Menu-Enxuto-e-Limpeza-do-Modulo-do-Pablo]] §5. O menu das telas descritas aqui também foi enxugado nesse contrato.

## 2. Camadas da requisição

`helmet`, `pino-http`, `express.json` (8 MB), CORS, tudo em `/v1`: rate limit por IP, `apiKey` (chave do BFF), `autenticacao` (JWT do hub), rate limit por usuário ✅ `src/app.ts:41-57,94-96`. Os routers entram na ordem de `src/app.ts:97-115`: cadastros, produtos pendentes, simulador, `/propostas`, suprimentos, histórico de compras, custos, dashboards, omie, pesquisa de materiais, clientes, relatórios, e-mail e PDF de proposta, pedido de cotação, notificações e painel do comprador.

Convenções ✅ `README.md:37-44`: envelope de erro `{ detail, codigo?, campos? }`; paginação `{ data, total, page, limit, total_pages }`; dinheiro como `Decimal` em string; `PUT`, `DELETE`, `/fechar`, `/perder`, `/reabrir` exigem `If-Match` (428 sem, 409 desatualizado); `POST /propostas` e `POST /solicitacoes_custo` aceitam `Idempotency-Key`.

## 3. Banco: o que cada migration criou

As 13 migrations em `prisma/migrations/` (ordem de pasta):

| # | Migration | O que faz | Linha |
|---|---|---|---|
| 1 | `20261001000000_mvp_inicial` | Cria o schema `core_comercial`, 24 enums e 22 tabelas: `empresas_emissoras`, `sequencias_proposta`, `sequencias_documento`, `perfis_comerciais`, `notificacoes`, `categorias_suprimento`, `produtos`, `fornecedores`, `fornecedores_categorias`, `certificados`, `ofertas`, `parametros_custo`, `tabelas_custo_telha`, `solicitacoes_custo`, `sincronizacoes_omie`, `clientes`, `clientes_contatos`, `propostas`, `propostas_itens`, `propostas_eventos`, `propostas_versoes`, `auditoria` | ✅ `migration.sql:2,74-494` |
| 2 | `20261002114920_oferta_quantidade` | `ofertas.quantidade` (pondera a média de preço realizado) | ✅ `migration.sql:2` |
| 3 | `20261005111706_solicitacao_resposta_comprador` | `solicitacoes_custo.resposta_comprador` | ✅ `migration.sql:2` |
| 4 | `20261005112201_chaves_idempotencia` | Tabela `chaves_idempotencia` (24 h) | ✅ `migration.sql:2-16` |
| 5 | `20261005120000_omie_chaves_ordens_compra` | `pg_trgm`; `produtos_contas_omie`, `fornecedores_contas_omie`, `ordens_compra`, `itens_ordem_compra`, `omie_registros_brutos`; índices GIN de busca | ✅ `migration.sql:9,15-70,103-106` |
| 6 | `20261005142936_clientes_relacionamento` | `status`, `segmento`, `potencial`, `proximo_contato`, `observacoes`, `versao` em `clientes`; `cargo` em contatos | ✅ `migration.sql:2-22` |
| 7 | `20261006113409_apelidos_fornecedor` | `apelidos_fornecedor` | ✅ `migration.sql:2-20` |
| 8 | `20261006114520_solicitacoes_atribuir_cancelar` | `atribuida_em`, `cancelada_em`, `id_cancelada_por`, `motivo_cancelamento` | ✅ `migration.sql:2-8` |
| 9 | `20261006120642_travas_tarefa` | `travas_tarefa` (uma sincronização do Omie por vez) | ✅ `migration.sql:2-8` |
| 10 | `20261007160000_evento_email_enviado` | Evento `EMAIL_ENVIADO` | ✅ `migration.sql:2` |
| 11 | `20261013120000_numero_proposta_so_digitos` | Tira `numero_completo` e `numero` de versão: o `CO-AV2026-0012-R03` passa a ser montado só na saída | ✅ `migration.sql:5-38` |
| 12 | `20261013130000_pedido_omie_proposta` | `acompanhamento_qualidade` e `numero_pedido_omie` na proposta; evento `PEDIDO_OMIE_ATUALIZADO` | ✅ `migration.sql:2-7` |
| 13 | `20261013140000_usuarios_comerciais_diretorio` | `perfis_comerciais` vira diretório de usuários; sai cargo, empresas e unidades; entra `responsavel_proposta` | ✅ `migration.sql:8-22` |

### 3.1 As 30 tabelas por arquivo do Prisma

| Arquivo | Models (tabela física) | Linhas |
|---|---|---|
| `prisma/models/vendas.prisma` | `Cliente` (`clientes`), `ClienteContato` (`clientes_contatos`), `Proposta` (`propostas`), `PropostaItem` (`propostas_itens`), `PropostaEvento` (`propostas_eventos`), `PropostaVersao` (`propostas_versoes`), `Auditoria` (`auditoria`) | ✅ `:3-212` |
| `prisma/models/empresas.prisma` | `EmpresaEmissora` (`empresas_emissoras`), `SequenciaProposta` (`sequencias_proposta`), `SequenciaDocumento` (`sequencias_documento`), `UsuarioComercial` (`perfis_comerciais`) | ✅ `:2-78` |
| `prisma/models/suprimentos.prisma` | `CategoriaSuprimento`, `Produto`, `Fornecedor`, `ApelidoFornecedor`, `FornecedorCategoria`, `Certificado`, `Oferta`, `ParametroCusto`, `TabelaCustoTelha`, `SolicitacaoCusto`, `SincronizacaoOmie` | ✅ `:4-260` |
| `prisma/models/omie.prisma` | `ProdutoContaOmie`, `FornecedorContaOmie`, `OrdemCompra`, `ItemOrdemCompra`, `OmieRegistroBruto` | ✅ `:8-97` |
| `prisma/models/infra.prisma` | `Notificacao`, `ChaveIdempotencia`, `TravaTarefa` | ✅ `:2-45` |

### 3.2 Enums (24) em `prisma/models/enums.prisma`

| Enum | Valores | Linha |
|---|---|---|
| `CodigoEmpresa` | `AV`, `AU`, `HRM` | `:1-7` |
| `Unidade` | `MOGI`, `UBERABA`, `ARUJA` | `:9-15` |
| `ContaOmie` | `MOGI`, `UBERABA` | `:17-23` |
| `TipoPessoa` | `PJ`, `PF` | `:24-29` |
| `TipoVenda` | `NACIONAL`, `EXPORTACAO` | `:31-36` |
| `Moeda` | `BRL`, `USD`, `EUR` | `:38-44` |
| `Incoterm` | `EXW`, `FCA`, `CPT`, `CIP`, `DAP`, `DPU`, `DDP`, `FOB`, `CFR`, `CIF` | `:46-59` |
| `Finalidade` | `INDUSTRIALIZACAO`, `REVENDA`, `CONSUMO_FINAL` | `:61-67` |
| `StatusProposta` | `ABERTA`, `PARCIAL`, `FECHADA`, `PERDIDA` | `:69-76` |
| `UnidadeMedida` | `PC`, `KG`, `M`, `TN`, `CJ`, `M2`, `UN` | `:78-88` |
| `MotivoPerda` | `PRECO_ALTO`, `PRAZO`, `COMPROU_CONCORRENTE`, `PROJETO_CANCELADO`, `SEM_RETORNO`, `CONDICAO_PAGAMENTO`, `FRETE`, `OUTRO` | `:90-101` |
| `RequisitoQualidade` | `CRC_PETROBRAS`, `ISO_9001` | `:103-108` |
| `OrigemCusto` | `VIGENTE`, `HISTORICO`, `MANUAL`, `SEM_CUSTO` | `:110-117` |
| `TipoEventoProposta` | `CRIADA`, `REVISADA`, `PERDIDA`, `REABERTA`, `FECHAMENTO_PARCIAL`, `FECHAMENTO_TOTAL`, `DUPLICADA`, `COPIADA`, `PDF_GERADO`, `EMAIL_ENVIADO`, `EXCLUIDA`, `CUSTO_ALTERADO`, `MIGRADA`, `PEDIDO_OMIE_ATUALIZADO` | `:119-136` |
| `StatusFornecedorCategoria` | `ATIVO`, `SUSPENSO` | `:138-143` |
| `TipoCertificado` | `ISO_9001`, `CRC_PETROBRAS` | `:145-150` |
| `OrigemIcmsCompra` | `SP`, `SP_REDUZIDA`, `OUTRA_UF`, `IMPORTACAO_SP`, `IMPORTACAO_OUTRA_UF`, `SIMPLES` | `:152-161` |
| `TipoFrete` | `CIF`, `FOB` | `:163-168` |
| `FonteOferta` | `MANUAL`, `MAPA_COTACAO`, `PEDIDO_OMIE`, `MIGRACAO` | `:170-177` |
| `StatusOferta` | `VIGENTE`, `VENCIDA`, `INVALIDADA`, `HISTORICA` | `:179-186` |
| `StatusSolicitacao` | `ABERTA`, `RESPONDIDA`, `SEM_FORNECEDOR`, `CANCELADA` | `:188-195` |
| `StatusRelacionamento` | `ATIVO`, `PROSPECCAO`, `MORNO`, `QUENTE`, `INATIVO` | `:198-206` |
| `SegmentoCliente` | `INDUSTRIA`, `MINERACAO`, `ENGENHARIA`, `CONSTRUTORA`, `MANUTENCAO`, `REVENDA`, `USINA`, `OUTRO` | `:208-219` |
| `PotencialCliente` | `BAIXO`, `MEDIO`, `ALTO`, `ESTRATEGICO` | `:221-228` |

## 4. Regras de negócio no código

### 4.1 Numeração: `CO-AV2026-0012-R03`

- Formato `CO-{AV|AU|HRM}{AAAA}-{NNNN}-R{RR}`, 4 dígitos que viram 5 depois de 9999; o banco guarda só empresa, ano, sequencial e revisão e o texto é montado na saída ✅ `src/domain/numeracao/numeroProposta.ts:1-12`, migration 11.
- Sequência por empresa e ano, atômica por `INSERT … ON CONFLICT DO UPDATE … RETURNING` ✅ `src/modules/propostas/propostas.service.ts:313-322`, `prisma/models/empresas.prisma:32-42`. A proposta é única por `(id_empresa, ano, sequencial)` ✅ `vendas.prisma:103`.
- A proposta técnica usa o mesmo número com prefixo `PT-` ✅ `numeroProposta.ts:22-25`. O antigo prefixo `PC-` ainda é lido na busca e nos eventos ✅ `numeroProposta.ts:35-36`, `propostas.service.ts:754-772`.
- A solicitação de custo usa `SC-AAAA-NNNN` por ano, em `sequencias_documento` ✅ `numeroProposta.ts:61-63`, `src/modules/custos/custos.routes.ts:381-385`.
- A `api-acos-vital` já numera a OC e a requisição por unidade com `contadores_documento (codigo_empresa, tipo)` e prefixo `OC-000001` ✅ `Dump Avhub (Esqueleto).sql:16555-16561,8110-8135`. É o padrão que N16-04 manda seguir.

### 4.2 Cálculo da proposta (função pura, `decimal.js`)

| Regra | Onde |
|---|---|
| Preço automático: `(custo × kg/m × metragem + pintura) × (1 + margem%)`; sem custo e margem vale o preço digitado; pintura soma ao preço base manual | ✅ `src/domain/calculo/linhaItem.ts:20-37` |
| Por linha: subtotal bruto, preço líquido de desconto, base, valor de desconto, ICMS, IPI e ST sobre a base | ✅ `linhaItem.ts:64-88` |
| Total = Σ(base + IPI + ST) + frete; frete só com Incoterm CIF | ✅ `src/domain/calculo/totais.ts:18-30` |
| Exportação ou isento zera ICMS, IPI e ST | ✅ `src/modules/propostas/propostas.calculo.ts:187-207` |
| Margem real = (base − custo total) ÷ base | ✅ `src/domain/custo/custo.ts:119-125`, `propostas.calculo.ts:221-236` |
| Fechamento total ou parcial proporcional à base de cada item | ✅ `src/domain/calculo/fechamento.ts:13-39` |
| ICMS do item só 0, 4, 7, 12 ou 18; PJ exige comprador; exportação exige cotação | ✅ `src/modules/propostas/propostas.schemas.ts:18,30,86-98` |
| A revisão sobe quando a assinatura do conteúdo comercial muda (preço, impressos, fatores da fórmula; o snapshot de custo não entra) | ✅ `propostas.calculo.ts:278-335`, `propostas.service.ts:483-486` |

### 4.3 Custo de referência, ofertas e médias

- Custo líquido = `preço × (1 + IPI) + ST − ICMS a recuperar`; com ST não há crédito ✅ `custo.ts:33-42`. Tabela padrão de ICMS a recuperar por origem em `custo.ts:13-20`, sobrescrita por `parametros_custo` ✅ `prisma/seed.ts:75`.
- Seleção do custo: vigentes elegíveis primeiro (menor custo); sem vigente, o realizado mais recente dentro de `diasHistorico` (90) ✅ `custo.ts:79-117`. Elegível = fornecedor ativo, vinculado à categoria, não suspenso, com certificado exigido e sem "verificar escala" ✅ `src/modules/custos/custos.routes.ts:57-64`.
- Oferta é imutável: corrigir é invalidar com motivo e lançar outra ✅ `suprimentos.prisma:138-139`, `suprimentos.routes.ts:791-806`. Trava de escala: preço fora de 1/3 a 3 vezes a mediana pede confirmação ✅ `suprimentos.routes.ts:697-712`.
- Médias e estatísticas: média ponderada pela quantidade quando todos os registros têm quantidade, senão simples; mínimo, máximo, último; janela de 90 dias; aviso "acima da média" a partir de 15% ✅ `src/domain/custo/medias.ts:161-211`, `custos.routes.ts:84-125`. Rota `GET /produtos/:id/precos` (por produto e por fornecedor) ✅ `suprimentos.routes.ts:823-874`.
- Preço realizado vem do pedido de compra do Omie: cada item vira oferta `PEDIDO_OMIE`; OC cancelada invalida a oferta ✅ `src/modules/omie/sincronizacao.ts:265-380`.
- Análise para o pedido de cotação (última compra, média e mínimo por unidade, por fornecedor) ✅ `src/domain/custo/analiseCompras.ts:242-277`.

### 4.4 Telha TR40

Configurador por classe, espessura, núcleo (EPS ou PIR) e pintura; o custo base já embute EPS 30 mm e troca pelo núcleo escolhido; largura útil de bobina 1,2 m e aço 7,85 ✅ `src/domain/telha/configurador.ts:60-120`. A tabela de custo tem vigência: salvar abre vigência nova a partir de hoje e fecha a anterior; no mesmo dia corrige a do dia ✅ `custos.routes.ts:213-239`. O dado fica em `tabelas_custo_telha` com `base`, `nucleos` e `pinturas` em JSON ✅ `suprimentos.prisma:200-213`.

### 4.5 Fechamento e pedido no Omie (o que N16 troca)

- O vendedor fecha a proposta inteira ou por itens; o fechamento parcial marca itens e calcula `valor_fechado` e `valor_aberto` ✅ `propostas.service.ts:609-647`, `fechamento.ts`. A proposta só é editada com status `ABERTA` ✅ `propostas.service.ts:474-476`.
- Perder (motivo obrigatório, texto de 3 letras ou mais) e reabrir (limpa as marcas de itens fechados) ✅ `propostas.service.ts:555-607`.
- **O av-hub não cria o pedido no Omie.** A API monta um resumo "a digitar no Omie" (campo a campo, com código do produto da conta de Mogi ou de Uberaba) e uma planilha; o vendedor digita no Omie e registra de volta o número do pedido e se a Qualidade acompanha ✅ `src/modules/propostas/pedidoOmie.ts:7-12`, `propostas.service.ts:649-724`, `propostas.routes.ts:144-164`. Depois o pedido volta pela pipeline e é liberado no hub (V3) ✅ `pedidoOmie.ts:7-12`.

### 4.6 Escopo, perfis e telas de permissão

- Escopo por usuário dono (`id_responsavel`): `PROPRIAS`, `COMPARTILHADA` (que não restringe nada) e `TODAS` ✅ `propostas.service.ts:23-34`.
- Slugs que decidem capacidade ✅ `src/domain/permissoes/capacidades.ts:47-56`: `propostas`, `propostas-delegacao`, `propostas-valores`, `custo-item`, `relatorio-gerencial`, `painel-comprador`, `clientes`, `simulador`. Capacidades: `veValores`, `veCusto`, `comprador`, `podeDelegar`, `editaTerceiros`, `exclui`, `escopo`, `escopoClientes`, `relatorioGerencial`, `simulador`.
- Perfis de teste (bypass de desenvolvimento): `Comercial - Vendedor`, `Auxiliar`, `Gestão`, `Diretoria`, `Suprimentos - Comprador`, `Pós-venda`, `Comissões - Simulador` ✅ `perfisDev.ts:12-77`. São fixtures do bypass; não migram.
- Telas cadastradas em 16/10 (nome, slug, pai, ordem relativa) ✅ `06-Contratos/Ativos/LOG-57-anexos/telas-vendas-orcamento-compras.sql:51-70`:

| Grupo | Slugs |
|---|---|
| `vendas` | `propostas` (20), `clientes` (21), `relatorio-cotacoes` (22), `relatorio-gerencial` (23); ocultas: `propostas-delegacao` (90), `propostas-valores` (91), `solicitacoes-custo` (92) |
| `orcamento` | `painel-comprador` (1), `pedido-cotacao` (2), `ofertas-fornecedor` (3), `fornecedores` (4), `catalogo-produtos` (5), `pesquisa-materiais` (6), `parametros-custo` (7), `tabela-telha` (8); oculta: `custo-item` (90) |
| `compras` | `historico-compras` (30) |
| fora do menu | `sincronizacao-omie` sai (passo 4 do SQL); as 5 telas antigas do Orçamento (`categorias`, `fornecedores`, `historico-produtos`, `sem-cadastro`, `vinculos`) saem (passo 2) |

- O BFF ainda cita o slug `matriz-precos` (`app/api/comercial/[...rota]/route.ts:89,104`), que o SQL de 16/10 não cadastra; o contrato de telas diz "tela ainda não construída" ✅ `docs/ENVIAR - contrato-comercial-suprimentos-telas.md:75`. O slug `simulador` (Simulador de Comissões) também é consultado ✅ `capacidades.ts:55`.

## 5. Rotas por módulo (`/v1`)

Prefixo de cada router em `src/app.ts:97-115`. Linha = handler.

| Módulo | Rotas | Arquivo e linhas |
|---|---|---|
| Cadastros | `GET /me`, `/empresas_emissoras`, `/parametros_custo`, `/cambio`, `/responsaveis`; `PUT /parametros_custo` | ✅ `src/modules/cadastros/cadastros.routes.ts:14,38,91,99,123,136` |
| Propostas | `GET /`, `/resumo`, `/:id`, `/:id/eventos`, `/:id/versoes`, `/:id/versoes/:revisao`, `/:id/pedido_omie` (+ `/xlsx`), `/itens/modelo`; `POST /`, `/calcular`, `/itens/importar`, `/:id/duplicar`, `/:id/fechar`, `/:id/perder`, `/:id/reabrir`, `/:id/email`, `/:id/eventos/pdf_gerado`; `PUT /:id`, `/:id/pedido_omie`; `DELETE /:id` | ✅ `src/modules/propostas/propostas.routes.ts:17-164`, `emailProposta.ts:26`, `pdfGerado.ts:17` |
| Clientes | `GET /clientes` (+ `/exportar`, `/resumo`, `/receita/:cnpj`, `/por_documento/:documento`, `/:id/propostas`, `/:id`); `POST /clientes`, `/:id/contatos`; `PUT /clientes/:id`, `/:id/contatos/:idContato`; `DELETE …/contatos/:idContato` | ✅ `src/modules/clientes/clientes.routes.ts:85-487` |
| Custos | `POST /custos/sugerir`; `GET /telha/tabela`, `/telha/tabelas`; `PUT /telha/tabela`; `POST /telha/calcular`; `GET/POST /solicitacoes_custo` e `/:id/responder`, `/assumir`, `/liberar`, `/cancelar` | ✅ `src/modules/custos/custos.routes.ts:30,159,173,213,251,304,367,406,494,500,508` |
| Suprimentos | `GET /produtos` (+ `/:id`, `/:id/precos`), `POST /produtos`; `GET /fornecedores` (+ `/exportar`, `/emails`, `/apelidos`, `/:id`), `PUT /fornecedores/:id/perfil`, categorias e certificados; `GET /categorias`; `GET /ofertas` (+ `/exportar`, `/importacoes`), `POST /ofertas`, `/ofertas/importar_mapa`, `/ofertas/:id/invalidar` | ✅ `src/modules/suprimentos/suprimentos.routes.ts:29,72,106,152,192,202,248,274,291,312,339,375,396,415,433,444,561,597,645,687,757,791,823` |
| Outros de Suprimentos | `GET /historico_compras` (+ `/resumo`); `GET /painel_comprador`; `GET /pedidos_cotacao/fornecedores`, `/analise`, `POST /pedidos_cotacao`; `GET /pesquisa_materiais` (+ `/:id`, `/pesquisa_materiais_cotacao`); `GET /produtos_pendentes`, `POST /produtos_pendentes/:id/vincular` | ✅ `historicoCompras.ts:100,129`, `painelComprador.ts:142`, `pedidoCotacao.ts:34,57,175`, `pesquisaMateriais.ts:55,166,189`, `produtosPendentes.ts:35,63` |
| Simulador | `POST /propostas/por_pedido_omie`, `POST /custos/sugerir_compra` (leitura para o Simulador de Comissões; a regra mora em `src/domain/simulador/ladoCompra.ts`) | ✅ `src/modules/simulador/simulador.routes.ts:125,219` |
| Dashboards e relatórios | `GET /dashboards/comercial`, `/relatorios/cotacoes`, `/relatorios/gerencial` (JSON ou XLSX) | ✅ `dashboards.routes.ts:40`, `relatorios.routes.ts:19,35` |
| Notificações | `GET /notificacoes`, `POST /:id/lida`, `/ler_todas` | ✅ `notificacoes.routes.ts:10,32,39` |
| Omie | `GET /omie/sincronizacoes`, `POST /omie/sincronizar` | ✅ `omie.routes.ts:27,55` |

O BFF tem 84 entradas na allowlist, cada uma com tela e ação ✅ `app/api/comercial/[...rota]/route.ts:10-132`. Rotas dedicadas a arquivo: PDF da proposta, da aprovação interna, do lote e dos relatórios, planilhas de relatório, de clientes, de fornecedores, de ofertas, da importação de itens e do pedido Omie ✅ `find app/api/comercial` (14 arquivos além da allowlist).

## 6. Telas do av-hub

| URL | Componente | Slug | Selo |
|---|---|---|---|
| `/vendas/propostas` | `components/Propostas/PropostasLista.tsx` | `propostas` | ✅ |
| `/vendas/propostas/nova`, `/vendas/propostas/[id]` | `components/Propostas/PropostaForm/PropostaForm.tsx` (897 linhas) com `ItemProposta`, `ConfiguradorTelhaModal`, `FecharItensModal`, `PedidoOmieModal`, `RevisoesModal`, `LinhaDoTempoModal`, `SolicitacoesProposta`, `EnviarEmail`, `AndamentoProposta` | `propostas` | ✅ |
| `/vendas/clientes`, `/novo`, `/[id]` | `components/Comercial` e páginas | `clientes` | ✅ |
| `/vendas/relatorio-cotacoes`, `/vendas/relatorio-gerencial` | páginas | `relatorio-cotacoes`, `relatorio-gerencial` | ✅ |
| `/vendas/pedidos-de-venda` | página da lista de pedidos do Omie (tabela `pedidos_vendas`, contrato 08) | slug ❓ (não consta no SQL de 16/10; é do módulo Vendas já existente) | ✅ `app/(protected)/vendas/pedidos-de-venda/page.tsx:26-32` |
| `/orcamento/painel-comprador` | `components/PainelComprador/PainelComprador.tsx`, `ResponderSolicitacaoModal.tsx` | `painel-comprador` | ✅ |
| `/orcamento/pedido-cotacao` | `components/Suprimentos/PedidoCotacao.tsx`, `AnaliseItemPedidoModal.tsx` | `pedido-cotacao` | ✅ |
| `/orcamento/ofertas-fornecedor` | `OfertasLista.tsx`, `LancarOfertaModal.tsx`, `ImportarMapaModal.tsx`, `LigarFornecedorMapa.tsx` | `ofertas-fornecedor` | ✅ |
| `/orcamento/fornecedores`, `/[id]` | `FornecedoresLista.tsx`, `FornecedorFicha.tsx`, `CategoriasFornecedor.tsx`, `CertificadosFornecedor.tsx`, `EditarPerfilFornecedorModal.tsx` | `fornecedores` | ✅ |
| `/orcamento/catalogo-produtos`, `/[id]` | `CatalogoLista.tsx` (lista de 80 mil produtos com busca por trigramas), `ProdutoDetalhe.tsx` (abas Cadastro, Especificação e Preço por fornecedor; média geral de 90 dias), `ProdutosPendentesModal.tsx` | `catalogo-produtos` | ✅ `CatalogoLista.tsx:23-174`, `ProdutoDetalhe.tsx:204-323` |
| `/orcamento/pesquisa-materiais` | `PesquisaMateriais.tsx`, `ComparativoMaterialModal.tsx` | `pesquisa-materiais` | ✅ |
| `/orcamento/parametros-custo`, `/orcamento/tabela-telha` | páginas | `parametros-custo`, `tabela-telha` | ✅ |
| `/compras/historico-compras` | `HistoricoCompras.tsx`, `GraficoComprasMes.tsx` | `historico-compras` | ✅ |
| `/dashboards/dash-comercial` | página | `dash-comercial` | ✅ |
| Faixa "fluxo do custo" nas telas de Orçamento | `FluxoDoCusto.tsx` e `lib/domain/fluxo-suprimentos.ts:19-56` (5 passos: vendedor pede custo, comprador assume, pedir cotação, registrar preço, custo volta à proposta) | — | ✅ |

Tipos de tela ainda dizem "api-comercial" e `PARCIAL`/`FECHADA` (`lib/domain/comercial-propostas.ts:5`): precisam acompanhar a nova API.

## 7. Integrações com o Omie

| O que | Como é hoje | Selo |
|---|---|---|
| Produtos e fornecedores | Cópia local sincronizada a cada 15 min a partir do espelho do hub (`core.produtos`, `core.parceiros`), com de-para de unidade de medida (cerca de 85 grafias) | ✅ `src/modules/omie/fonteHub.ts:4-10`, `normalizacao.ts`, `agendador.ts:41-` |
| Pedidos de compra | Lidos direto da API do Omie (`PesquisarPedCompra`), pelas chaves do app de Mogi e Uberaba; viram ofertas `PEDIDO_OMIE`; a releitura cobre os últimos 60 dias e os cancelados vêm de uma segunda consulta | ✅ `docs/contrato-pedidos-compra-omie.md:5-9`, `sincronizacao.ts:265-380` |
| Câmbio | AwesomeAPI com fallback para a PTAX do Banco Central; cache de 10 min | ✅ `src/modules/cadastros/cambio.ts:1-59` |
| Pedido de venda | Só o resumo para o vendedor digitar (ver 4.5) | ✅ `pedidoOmie.ts:7-12` |
| Envio de OC (modelo para o pedido de venda) | A API do hub guarda a OC com `status_sincronizacao_omie` e expõe `GET /compras/ordens/fila-omie`; a pipeline lê a fila, chama `UpsertPedCompra` com `cCodIntPed` = número da OC, devolve `nCodPed` e `cNumero` por `PATCH /compras/ordens/{id}/sincronizacao`; recusa vira `erro` e só volta por `POST /:id/reenviar` | ✅ `api-acos-vital/src/schemas/core_vendas_faturamento/tables/ordens_compra/ordens_compra.route.js:857-889,1264-1356`, `omie-elt-pipeline/src/jobs/envioOrdensCompra.ts:16-39,130-167` |
| Pedido de venda por API | A pipeline não tem nenhum método de criação de pedido de venda (grep sem ocorrência de `IncluirPedido`) | ✅ 🔴 `omie-elt-pipeline/src/omie/resources` (só leitura de `pedidosVendas.ts`) |
| Retorno do pedido | O pedido criado no Omie volta pela pipeline para `core_vendas_faturamento.pedidos_vendas` e `produto_vendas` | ✅ `Dump Avhub (Esqueleto).sql:2328,2490` |

## 8. O que serve como está, o que muda e o que fica de fora

### 8.1 Serve como está (porta para a `api-acos-vital` sem mudar a regra)

| Item | Por quê | Selo |
|---|---|---|
| Cálculo de linha, totais, margem real | Regra travada contra o legado; N16-11 manda manter o motor | ✅ `linhaItem.ts`, `totais.ts` 🟡 porta como está |
| Custo líquido, médias, seleção de custo, análise de compras | Servem à base de preço do Orçamento | ✅ `custo.ts`, `medias.ts`, `analiseCompras.ts` |
| Configurador de telha e a ideia da tabela com vigência | N16-15 mantém o módulo; só a tabela vira estruturada | ✅ `configurador.ts` |
| Clientes, contatos, carteira e ficha | Continuam em Vendas | ✅ `clientes.routes.ts` |
| Idempotência, `If-Match`/`ETag`, envelope de erro | Padrão de [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] T3 e T4 | ✅ `README.md:37-44` |
| Empresas emissoras (AV, AU, HRM) com cabeçalho do PDF | Continuam; ganham a unidade do Omie onde o pedido é criado | ✅ `empresas.prisma:2-29` |
| Solicitação de custo (assumir, liberar, responder, cancelar) | Vira o pedido de custo ao Orçamento (N16-06) | ✅ `custos.routes.ts:304-542` |
| Ofertas imutáveis, invalidar com motivo, trava de escala | Base com histórico sempre (N16-07) | ✅ `suprimentos.routes.ts:687-806` |
| Painel do Comprador, pedido de cotação, pesquisa de materiais, fornecedores, catálogo | Telas do Orçamento | ✅ |
| Histórico de compras | Fica em Compras (N14-14, N16-14) | ✅ `historicoCompras.ts` |

### 8.2 Muda por causa das decisões

| Hoje no código | Muda para | Decisão | Onde fica o desenho |
|---|---|---|---|
| Número `CO-AV2026-0012-R03`, com letras, ano e revisão no texto | Número só numérico, em sequência própria; prefixo só na tela e no PDF | 📝 N16-04 | [[SQL-016-Proposta-e-Pedido-de-Venda-em-core_vendas_faturamento]], SQL-016 |
| Status `ABERTA`, `PARCIAL`, `FECHADA`, `PERDIDA` e editar só em `ABERTA` | `ABERTA` (ajusta), `APROVADA` (trava), `TRANSFORMADA`, `CANCELADA` | 📝 N16-02, N16-03 | API-019 |
| `PUT` edita e reabre depois de fechada ou perdida | Depois de aprovada não se ajusta nem se reabre | 📝 N16-03 | API-019 |
| Fechamento parcial por itens, `valor_fechado`, `valor_aberto`, evento `FECHAMENTO_PARCIAL` | Some: uma proposta é um pedido | 📝 N16-02 | API-019 |
| Proposta incompleta (item sem custo) pode ser salva e fechada | Incompleta não aprova (parte de compras vazia) | 📝 N16-03 | SQL-016 (`fn_proposta_travar`) |
| Pedido digitado pelo vendedor no Omie, com `PUT /pedido_omie` registrando número e Qualidade | Botão "Transformar em pedido de venda"; a API grava numa fila e a pipeline cria o pedido por API | 📝 N16-02 | API-020 |
| Qualidade registrada depois, na liberação do hub (V3) | `V2` obrigatório na proposta; o pedido nasce liberado, sem V3; o pedido que chega do Omie sem proposta segue com V2 e V3 | 📝 N16-05 | API-020 |
| Câmbio da AwesomeAPI com fallback PTAX | PTAX do hub (`core.cotacoes_moeda`) | 📝 N16-13 | SQL-016 (`id_cotacao_moeda`) |
| Custo do item só como snapshot da oferta sugerida | Parte de compras do vendedor + pedido de custo ao Orçamento, que preenche | 📝 N16-06 | API-021 |
| Solicitação de custo com prazo fixo de 2 dias úteis no código | Prazo definido pelo negócio (parâmetro) | 📝 N16-06, 🔴 OQ-02 | SQL-017 (`sla_solicitacao_dias_uteis`) |
| Catálogo de produtos é tela de Compras | O vendedor ganha tela de consulta (histórico, fornecedores, preços, média); matriz de preços nova | 📝 N16-07, 🔴 OQ-10 | LOG-60 |
| Ofertas `PEDIDO_OMIE` vêm de sincronização própria que lê o Omie | Derivam das OCs do hub e do espelho `pedidos_compras` (a pipeline é a fonte) | 📝 N16-15 | SQL-017 (`fn_oferta_gerar_de_ocs`) |
| Custo real do pedido não existe (só margem estimada com o custo cotado) | Custo real por evento e por item do pedido, com view `vw_pedido_item_custo` | 📝 N16-09 | LOG-61, [[SQL-016-Proposta-e-Pedido-de-Venda-em-core_vendas_faturamento]] |
| Compras não tem papel sobre a proposta | Compras confere a parte de compras (C6) e usa o valor correto na OC (C7); não altera a proposta; o preço fechado com o cliente não muda | 📝 N16-08, N16-17 | LOG-61 |
| Simulador de Comissões lê a proposta pelo `numero_pedido_omie` | Lê o pedido de venda do hub ligado à proposta (`pedido_venda.id_proposta`) | 📝 N16-11 | [[SQL-016-Proposta-e-Pedido-de-Venda-em-core_vendas_faturamento]] §9 |

### 8.3 Fica de fora da migração

| Item | Motivo | Decisão |
|---|---|---|
| Migração do ERP antigo (`erp_quotations`, `src/domain/migracao/erpAntigo.ts`, `src/modules/propostas/migracao.ts`, `npm run migrar:erp-antigo`), campo `legado` e evento `MIGRADA` | Não há migração do ERP antigo | 📝 N16-13 |
| Sincronização Omie (`src/modules/omie/*`, rotas `/omie/*`, tabelas `sincronizacoes_omie`, `omie_registros_brutos`, `travas_tarefa`, `produtos_contas_omie`, `fornecedores_contas_omie`, `ordens_compra`, `itens_ordem_compra` do comercial, slug `sincronizacao-omie`) | A Sincronização Omie sai do menu e a pipeline é a fonte | 📝 N16-14, N14-15 |
| Câmbio próprio (`cambio.ts`) e rota `GET /cambio` | PTAX do hub | 📝 N16-13 |
| Planilha e resumo "pedido a digitar no Omie" (`pedidoOmie.ts`, `GET/PUT /propostas/:id/pedido_omie`, `…/xlsx`, `PedidoOmieModal.tsx`) | O pedido é criado por API | 📝 N16-02 |
| `Auditoria` própria | Já existe `auth.auditoria` | 🟡 [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] §3.1 |
| `perfisDev.ts` e `AUTH_DEV_BYPASS` | Perfis fictícios, nunca em produção | 🟡 LOG-52 §6 |
| As 5 telas antigas de `/orcamento/*` e as rotas `app/api/historicoProdutos` | Removidas do av-hub em 16/10 | 📝 N16-14 |
| `Unidade` (`MOGI`, `UBERABA`, `ARUJA`) e `ContaOmie` como enums | Viram `core.unidades` (uuid) | 🟡 SQL-016 |
| Faixa "fluxo do custo" que começa em "Vendedor pede custo" | Texto muda: o setor orçamentário preenche | 🟡 LOG-60 |

## 9. Defeitos do código de teste que a migração não pode herdar

A auditoria de 15/10 (24 itens) está em [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] §10. Os que tocam as tabelas e regras da proposta, do Orçamento e da comissão: filtro por responsável que anula o escopo `proprios` (item 1), `vinculados` que não restringe (item 2), CNPJ alfanumérico rejeitado (item 4), cliente criado na proposta que sobrescreve o cadastro de outro vendedor (item 6), custo e margem apagados por `PUT` sem `veCusto` (item 8), `normalizarIpi` na oferta digitada (item 16), sem FK nem `CHECK` (item 17). Os DDL de [[SQL-016-Proposta-e-Pedido-de-Venda-em-core_vendas_faturamento]] e [[SQL-017-Orcamento-em-core_vendas_faturamento-Base-de-Preco-e-Pedido-de-Custo]] já trazem FK, `CHECK` e CNPJ de 14 posições alfanuméricas.

## 10. Perguntas que nascem deste mapa

| # | Pergunta | Quem | Selo |
|---|---|---|---|
| M1 | O slug da tela `/vendas/pedidos-de-venda` e o da `notas-fiscais-saida` são os que a pasta `app/(protected)` usa; confirmar o slug real em `auth.telas` | Nathan | ❓ |
| M2 | O catálogo de condições de pagamento de **venda** do Omie não está espelhado (só `condicoes_pagamento_compras`): como o pedido por API recebe a condição da proposta, que hoje é texto livre? | Gustavo, Nathan | 🔴 |
| M3 | O cadastro do cliente da proposta existe nas duas contas Omie? Se não, o pedido espera o cadastro ou a pipeline cria o cliente? | Nathan, Gustavo | 🔴 |
