---
tags: [desenvolvimento, contradicoes, v1, historico]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [v1 00-Indice/Registro-de-Decisoes-2026-10-07, v1 04-Arquitetura-Transversal (Decisoes-Chave-ERP, Chaves-de-Integracao, Rastreabilidade), v1 08-Integracao-Omie, v1 09-Contratos, código de 14/10 (api-pcp 579a625, app-pcp 1fca8d3, api-acos-vital f322dcd, omie-elt-pipeline 0f739f0, HUB b55ac55), decisões de 14/10]
---

# Contradições resolvidas

O vault anterior (v1, congelado) dizia coisas que se contradiziam entre si, com o código ou com decisões posteriores. Esta nota lista as **19** e a versão que vale hoje. O resto do vault v2 diz só a versão correta. Se uma nota do v1 contradiz uma linha abaixo, vale a coluna "Depois". Numeração `CR-nn` reconstruída na revisão de 14/10 (comparação v1 contra código e decisões).

| ID | Tema | Antes (v1) | Depois (v2) | Evidência | Selo |
|---|---|---|---|---|---|
| CR-01 | **Baixa do saldo** | Baixa quando a Embalagem recebe a parcial (D9, 25/09); depois, "no despacho do Estoque" (29/09) sem documento | O despacho é no Estoque: quem precisa da mercadoria gera um **documento de retirada** e a baixa acontece na retirada. O código ainda baixa na Embalagem | `api-pcp/src/itens-parciais/itens-parciais.service.ts:279`, `entregas/entregas.service.ts:88`; decisão de 14/10; BL-007 | 📝 decidido, 🔴 sem código |
| CR-02 | **Fabricado aprovado** | 25/09: "segue para a Expedição, não fica no Estoque"; 28/09 de manhã: direto à Expedição; 29/09: "tudo que é fabricado deve ir para o estoque" | Tudo que é fabricado ou comprado **vira lote e saldo no Estoque**; só então é retirado. Nós E5, Q8, F1 do 0b | EN-04 (25/09, reconfirmado 29/09 e 14/10); `OrigemLote` só tem RECEBIMENTO e CARGA_INICIAL (`estoque.prisma:17-20`); BL-008 | 📝, 🔴 sem código |
| CR-03 | **Schema do Estoque** | Proposto schema próprio `estoque` | MES usa só `public` (Prisma sem `@@schema`); o av-hub divide em `core_*`, `auth`, `omie_*`, `historico`. Não é contradição, é uma convenção por sistema | #21, CC-06; [[Schemas-Postgres]] | 📝 ✅ |
| CR-04 | **Origem da requisição** | Uma origem: o PCP (MES) ou, noutras notas, só o Compras | **Duas origens:** (1) Compras cria no HUB ("Nova requisição", `POST /compras/requisicoes`, `compras.pode_criar`); (2) o PCP cria no MES a requisição do material do pedido (Estoque, "Solicitar compra", setor `REQUISICAO`). A de origem 1 não chega ao MES (BL-006) | `HUB app/api/compras/requisicoes/route.ts:80`; `api-acos-vital/.../requisicoes_compra.route.js:384`; `api-pcp/src/compras/compras.controller.ts:76` | ✅ |
| CR-05 | **Quem lê a requisição** | Contrato 003: o hub **puxa** `GET /requisicoes-compra` do MES (job de polling); comentário no código "JOB DE POLLING do MES" | O MES **empurra**: `PUT /compras/requisicoes/origem/:id_origem` com fila de saída (LOG-34). O 003 ficou sem consumidor | `api-pcp/src/integracao-avhub/envio-avhub.service.ts:130`; `requisicoes_compra.route.js:31` (comentário velho) | ✅ |
| CR-06 | **Contrato 004 (referência da OC)** | "Não existe no hub" | Existe no hub: `GET /ordens-compra/referencia` (fe55923, 08/10). O MES **não** consome (BL-001) | `api-acos-vital/.../vw_ordens_compra_referencia_mes.route.js:44-89` | ✅ hub, 🔴 MES |
| CR-07 | **Contrato 005 (status por item)** | "Falta construir o consumidor" no hub | Consumidor existe: job de 90 s (dee35b0), rota `GET /itens_pedido_status`, cartão "Etapa dos itens" no HUB (`4869810`, PR #172) | `itens_pedido_status.job.js`; `HUB components/Pedidos/EtapaDosItens.tsx` | ✅ |
| CR-08 | **Duração do cronograma** | Plano de 2 meses (nome `Cronograma-2-Meses`); depois 3 meses (18/09 a 21/12); Ciclo 2 desde 04/01/2027; depois 11/01/2027 | Vale a seção 3.4 de 09/10: **Ciclo 1 fecha em 21/01/2027, Ciclo 2 começa em 22/01/2027**; M8 14/04, M9 04/06, M10 09/09, M11 21/10/2027 | #27, #34, #96; [[Cronograma]] | 📝 |
| CR-09 | **`lote_custo`** | "Não existe, só contrato (008)" | Existe: migration `20261009140000_lote_custo`, modelo `LoteCusto`, permissão `estoque-custo`. Só a carga inicial e a cisão gravam; o Recebimento não (BL-005) | `api-pcp/prisma/models/estoque.prisma:395-423`; `estoque-operacao.service.ts:440`, `:65` | ✅ |
| CR-10 | **`core_fluxo` e Torre no hub** | "Nada da Torre existe em nenhum dos três lados" (09/10) | Banco e API existem (77223e9, 7c3f57a, 046b): `core_fluxo.*`, job e 4 rotas. Falta o módulo `fluxo` do MES e as telas do HUB | `item_estado_projetado.job.js`, `.route.js:185,262,281,302`; `app.js:208` | ✅ hub, 🔴 MES e HUB |
| CR-11 | **Custo por item (`itens_pedido_custo`)** | "Só contrato 47" | Job, tabela e rota existem na API do av-hub (80581d0, f322dcd 047b); o MES não tem `GET /itens/custo` | `itens_pedido_custo.job.js:14-15,51-52`; `app.js:29,209` | ✅ hub, 🔴 MES |
| CR-12 | **Registro manual da compra** | MES registra a compra à mão: `PATCH /compras/requisicoes/:id/compra` | Removido. A compra vem pelos **marcos do contrato 35**; o setor Compras do MES é **Compras · CCP, só leitura**; a parcial só sai dele com a chegada com NF (`POST :id/chegada`); rede de segurança `POST :id/liberar-recebimento` com `compras-liberar` | `api-pcp/src/compras/compras.controller.ts:23-108`; migration `20261014120000_compras_ccp` | ✅ |
| CR-13 | **Aprovação da OC** | DEC-3: acima de R$ 30.000 o diretor aprova; #50b: o Gerente de Compras aprova | **Gerente de Compras aprova sempre; acima de R$ 30 mil a Diretoria também.** O código só exige aprovação acima do limite e só da Gerência (BL-038) | #50, #50b; `ordens_compra.route.js:1235`; `FecharCompra.tsx:605` | 📝, 🔴 sem código |
| CR-14 | **Contra o que o Recebimento confere** | 0b de 09/10: "contra a NF ou o pedido de venda"; v1: contra a OC | Confere **contra a NF** (chave de 44 dígitos), como o código. Cruzamento com a OC entra quando o job do 004 existir | `POST /compras/requisicoes/:id/chegada` exige NF; [[05-Recebimento]] | 📝 ✅ |
| CR-15 | **Escopo de vendedores no backend** | "Desligado; fixar `ESCOPO_VENDEDORES_EXIGIR` é do Gustavo e não foi feito" (#9, 08/10) | **Fixo no código** desde 09/10 (contrato 40): `escopoVendedoresExigir = () => true`. Também fixos: limite de login (contrato 41), `PERMISSOES_ROTA_MODO` `exigir`, auditoria, NF e pedido manual, acompanhamento do CCP | `api-acos-vital/src/utils/acessoConfig.js:68-82` | ✅ |
| CR-16 | **Nome da variável de chave do MES** | `AVHUB_MES_INTEGRACAO_KEYS` no lado do MES (PDF e notas) | `AVHUB_MES_INTEGRACAO_KEY` (singular) no `api-pcp`; `MES_INTEGRACAO_KEYS` (plural, lista) no `api-acos-vital`. Valor do MES = um da lista | `envio-avhub.service.ts:98`; `apiKeyAuth.js:59` | ✅ |
| CR-17 | **Mecanismo da integração (DEC-2)** | "Polling REST bidirecional, sem webhook, 3 fluxos" | Polling continua para marcos, status, custo e Torre; a **ida da requisição é push** com fila (exceção deliberada), e o MES só lê o Omie via av-hub. Hoje são **8 fluxos** (INT-01 a INT-08) | [[Integracao-AvHub-MES]] | ✅ |
| CR-18 | **Eventos do contrato 35 usados pelo MES** | O MES usaria só parte dos eventos (aprovada, cancelada); registro manual cobria o resto | O MES trata **todos** os tipos de marco (14 tipos, de `requisicao_recebida` a `requisicao_cancelada`), mais autor e comprador (migration 035b) | `api-pcp/src/integracao-avhub/requisicao-avhub.eventos.ts:47-48,234-318` | ✅ |
| CR-19 | **CFOP** | A modelagem dizia que CFOP não é capturado por nenhum sistema ("fica 100% com o Omie") | O pipeline captura e valida **CFOP por item** (`produto_vendas.cfop`, whitelist `core_vendas_faturamento.cfop`). Só ICMS-ST não é capturado; não existe CFOP da nota inteira | `omie-elt-pipeline` `produtoVendas.ts`; [[Pedidos-de-Venda]] | ✅ |

## Aliases e numeração (resolvidos, não contradizem)

| Nome no código ou no v1 | Nome no v2 |
|---|---|
| "Contrato 30" (comentários de `pedidoVendaManual.js` e outros) | [[LOG-45-Pedido-de-Venda-Manual]] ([[Pontas-Soltas]] PS-025) |
| "contrato 28" nos comentários do código (NF manual, `notas_fiscais.route.js`) | [[LOG-29-Notas-Fiscais-Manuais-So-Admin]]; o LOG-28 é compradores ([[LOG-28-Compradores-Criar-Excluir-Sugestao]]) |
| "05 P6/P8" | [[LOG-04b-Pedidos-Notas-Dashboards-Agregacao-no-Banco]] |
| `19-Nomes` (título dizia 27) | [[LOG-19b-Compras-Pedido-Omie-Nomes]] |
| Carteira de Pedidos / "Nova Ordem de Produção" / lista de Ordens de Produção | Triagem do Pedido / Destinação do Pedido / Acompanhamento dos Pedidos (#74) |
| "Portal PCP" do av-hub | acompanhamento comercial, não é o `app-pcp` (#54) |

## Como usar

Ao achar no v1 uma frase que contradiz o código, procure o tema aqui. Se não estiver, é uma contradição nova: registre em [[Pontas-Soltas]] com dono e proposta.
