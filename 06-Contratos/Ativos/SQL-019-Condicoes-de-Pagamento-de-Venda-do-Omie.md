---
id: SQL-019
aliases: ["Contrato SQL 018", "018-Condicoes-de-Pagamento-de-Venda-do-Omie"]
tags: [contrato, contrato-sql, dba, pipeline, omie, condicao-de-pagamento, pedido-de-venda, catalogo]
criado: 2026-10-23
atualizado: 2026-10-23
status: proposta
sistemas: [hub-banco, pipeline]
dono: "Gustavo (tabela) e Nathan (recurso da pipeline)"
etapa_0b: [V0.2, V0.6, V0.7]
fontes: ["Resposta real do ListarParcelas colada pelo Nathan em 23/10/2026 (página 1 de 7: 50 de 330 condições)", "Documentação do Omie: https://app.omie.com.br/api/v1/geral/parcelas/ (ListarParcelas, IncluirParcela)", "omie-elt-pipeline src/omie/resources/condicoesPagamentoCompras.ts, contasCorrentes.ts, index.ts, jobs/inativarCatalogos.ts", "omie-elt-pipeline src/omie/ordemCompraOmie.ts:305-326 (teste de 05/10/2026: mandar parcelas troca a condição para 999)", "api-acos-vital core_vendas_faturamento/tables/condicoes_pagamento_compras (modelo)", "06-Pesquisa/Mapa-IncluirPedido-Omie (§5.1)"]
criado_original: 2026-10-23
---

# Contrato SQL 018 — catálogo de condições de pagamento de **venda** do Omie (`ListarParcelas`) na pipeline e no banco

> **Onde atua:** pipeline Omie · av-hub: banco

> [!info] Situação em 23/10/2026
> **Status:** `proposta`, **só desenho**. Nada foi implementado nem aplicado: o Nathan pediu que se planeje e desenhe tudo, e que o vault só seja atualizado depois da aprovação.
>
> - 📝 Decisão do Nathan (23/10): a pipeline precisa **puxar o `ListarParcelas` e salvar no banco**.
> - ✅ Existe o molde: o catálogo de condições de **compra** (`ListarFormasPagCompras` → `core_vendas_faturamento.condicoes_pagamento_compras`).
> - 🔴 Não existe nada para a **venda**: nenhum recurso na pipeline, nenhuma tabela.
> - Quem usa: a proposta (lista de condições da conta da emissora), a criação do pedido por API (`codigo_parcela`) e o de-para com a tabela de encargos do motor de comissão. Ver [[Mapa-IncluirPedido-Omie]] e [[API-019-Proposta-e-Pedido-de-Venda-na-API-do-Hub]].

## 1. Por quê

O pedido de venda criado por API precisa levar o **código real** da condição (`codigo_parcela`, 3 caracteres). Mandar parcelas à mão faz o Omie trocar a condição para `999` ("Informar o número de parcelas"), como o teste de 05/10/2026 mostrou na compra. O vendedor só pode escolher uma condição **que existe na conta Omie da empresa emissora**, e o código pode mudar de conta para conta. Por isso o hub precisa de uma cópia do catálogo, por conta, mantida pela pipeline.

## 2. O que o Omie devolve (dado real)

Resposta colada pelo Nathan: `pagina 1, total_de_paginas 7, registros 50, total_de_registros 330`. Cada item: `nCodigo` (3 caracteres), `cDescricao`, `nParcelas`. Lições dessa amostra:

| Observação | Exemplos reais | Consequência |
|---|---|---|
| O código é **alfanumérico** e não segue ordem lógica | `000`, `001`, `00V`, `07I`, `1E8`, `22B`, `63A`, `94F`, `A01`, `A50` | Guardar como **texto**; nunca converter em número |
| A descrição **passa de 30 caracteres** (a documentação diz `string30`) | `A Vista/15/30/45/60/75/90/105/120/135/150` (41), `180/210/240/…/690` (71) | **Nenhum corte**; coluna de 200 caracteres (a da compra usa 100 e já avisou o mesmo) |
| Muitas descrições **são a lista de dias** | `45/55/65/80`, `1/30/45`, `28/42/56/74`, `16/20/24` | Dá para **inferir os dias** (seção 4) e casar com a tabela de encargos |
| Outras descrevem a quantidade | `1 Parcela`, `24 Parcelas`, `28 Parcelas` (código `07I`) | **Não dizem o intervalo**: dias = desconhecido |
| Outras dizem um prazo único | `Para 30 dias (C)`, `Para 1 dia`, `A Vista` (código `000`) | Prazo único: 30, 1, 0 |
| Existe uma condição **especial** | `999` = "Informar o número de parcelas", `nParcelas = 999` | Marcar; **fora da lista** da proposta (seção 6) |
| O mesmo número de parcelas aparece em condições diferentes | várias com `nParcelas = 1` | O catálogo **não** é único por quantidade |
| Sem campo de inativo | só `nCodigo`, `cDescricao`, `nParcelas` | Toda condição listada é ativa; a que sumir vira inativa (seção 5) |

❓ A amostra é a primeira página. De qual das **três** contas são as 330 só a chamada por conta diz; as outras duas terão listas próprias, com códigos que podem repetir ou diferir.

## 3. A tabela 🟡

`core_vendas_faturamento.condicoes_pagamento_vendas` (mesmo schema da de compras, porque quem a preenche é a pipeline):

| Coluna | Tipo | Observação |
|---|---|---|
| `id` | uuid, `uuidv7()` | PK |
| `codigo_empresa` | uuid, FK `core.unidades` | a conta Omie (uma linha por conta) |
| `codigo_omie` | varchar(3), `NOT NULL` | `nCodigo` |
| `descricao` | varchar(200), `NOT NULL` | `cDescricao`, **sem corte** |
| `quantidade_parcelas` | integer | `nParcelas` (999 no especial) |
| `informar_parcelas` | boolean, `NOT NULL` | `true` só para `999` |
| `dias_descricao` | varchar(100), nulo | dias **inferidos** da descrição ("45,55,65,80"); nulo quando não dá |
| `ativo` | boolean, `NOT NULL`, padrão `true` | sumiu do Omie = `false`; nunca se apaga a linha |
| `created_at`, `updated_at` | timestamptz | |

Chave única `(codigo_empresa, codigo_omie)`. Sem FK para `pedidos`: o pedido guarda o código e a empresa; a pipeline sincroniza em ordem imprevisível (mesma regra do `README` de `dba_migrations`, item 3). `CHECK (char_length(codigo_omie) = 3)` e `CHECK (NOT informar_parcelas OR codigo_omie = '999')`.

## 4. Os dias inferidos (a parte delicada)

Regra de leitura de `descricao` → `dias_descricao`, **só** nestes formatos exatos; o resto fica nulo:

| Formato | Exemplo | Resultado |
|---|---|---|
| números separados por `/` | `45/55/65/80` | `45,55,65,80` |
| `A Vista` no começo e depois números | `A Vista/15/30/45` | `0,15,30,45` |
| só `A Vista` | `A Vista` | `0` |
| `Para N dias` (com sufixo opcional entre parênteses) | `Para 30 dias (C)` | `30` |
| `N Parcelas` / `1 Parcela` | `28 Parcelas` | **nulo** (o intervalo não está dito) |
| `Informar o número de parcelas` | `999` | **nulo** |

Por que só isso: um dia errado vira **informação errada** na proposta. Por isso o campo se chama `dias_descricao`, a tela deve dizer "vencimento: de acordo com a descrição da condição no Omie" e a pipeline **grava a regra aplicada** no log. ❓ A leitura "dias contados a partir de quê" (faturamento ou inclusão) só o teste no Omie responde (OQ-16, Mapa §6 item 9).

**De-para automático com o motor de comissão.** A tabela de encargos do motor usa chaves como `28/45`. Comparando `dias_descricao` (`28,45`) com a chave normalizada, o hub liga as duas **sem digitar nada**; o que não casar entra numa lista "condição sem encargo cadastrado" para a Controladoria. 🟡 Condição com dias nulos (`28 Parcelas`) não casa e não pode ser escolhida na análise de margem até alguém cadastrar o encargo.

## 5. O que a pipeline faz 🟡

Novo recurso `condicoesPagamentoVenda`, no molde de `condicoesPagamentoCompras.ts`:

| Item | Valor |
|---|---|
| Endpoint e método | `/geral/parcelas/`, `ListarParcelas` |
| Chave da resposta | `cadastros` |
| Paginação | `registros_por_pagina: 50` (330 condições = 7 páginas = 7 chamadas por conta) |
| Parâmetros extras | `apenas_importado_api: "N"` (traz tudo, não só o criado por API) |
| Chave do registro | `nCodigo` |
| Conflito no upsert | `(codigo_empresa, codigo_omie)` |
| Camada | lenta (`somenteCamadaLenta`), como os outros catálogos |
| Validação | recusa a linha sem `nCodigo` |
| Mapeamento | `descricao` sem corte, `informar_parcelas = (nCodigo == '999')`, `dias_descricao` pela regra da seção 4 |
| Inativação | entra na lista `CATALOGOS` de `inativarCatalogos.ts`: o que sumir do Omie vira `ativo = false`; **trava**: se o Omie devolver menos da metade dos ativos do banco, nada é inativado |
| **Ligação** | nasce **desligado** (`enabled` por variável de ambiente) até o DBA aplicar a tabela. A tabela precisa existir em **todos os bancos** antes de ligar, senão a carga falha e aparece no log |
| Contas | roda em **cada filial configurada**: `mogi`, `uberaba` e `aruja` (N16-79). 🔴 A filial `aruja` precisa existir no `.env` da pipeline (`FILIAIS_ATIVAS` e as chaves `FILIAL_ARUJA_*`); hoje o padrão é só `mogi,uberaba` |

**Atraso aceito:** o catálogo roda na camada lenta, e uma condição recém-cadastrada no Omie demora a aparecer no Hub. **Sem botão para forçar a atualização** (N16-99): os dados mudam pouco.

## 6. Como o hub usa 🟡

1. A proposta mostra **apenas** condições `ativo` da conta da empresa emissora, **sem** `999`, e que tenham encargo cadastrado no motor (ou mostra a condição com um selo "sem encargo", se a Controladoria decidir assim).
2. O texto exibido no PDF vem da **descrição do Omie**; deixa de existir texto livre (D7).
3. Ao transformar em pedido: `codigo_parcela` = `codigo_omie` da conta; **sem `lista_parcelas`** (como na OC). `proposta.codigo_parcela_omie` (já existe no SQL-016) passa a guardar esse código.
4. `999` só para condição combinada com o cliente que **não exista** no cadastro; o pedido perde a condição de pagamento e o vendedor é avisado antes (decisão do Nathan, D7).
5. A pipeline **não cria** condição por API (`IncluirParcela`): o Financeiro cadastra no Omie.

## 7. Testes de aceite (quando houver implementação)

1. A carga de uma conta grava todas as páginas (330 de 330 no caso da amostra) e uma segunda carga não duplica.
2. `A Vista` → `0`; `1/30/45` → `1,30,45`; `A Vista/15/30` → `0,15,30`; `Para 30 dias (C)` → `30`; `28 Parcelas`, `1 Parcela` e `999` → nulo.
3. Uma descrição com mais de 30 caracteres é gravada inteira.
4. `informar_parcelas` é verdadeiro só para `999`.
5. Uma condição que some do Omie vira `ativo = false`; se o Omie devolver menos da metade, nada é inativado.
6. O mesmo código em contas diferentes gera linhas diferentes (uma por `codigo_empresa`): três contas, três catálogos independentes.
7. A chave `28/45` da tabela de encargos casa com a condição cuja descrição é `28/45`, sem digitação.
8. Com a variável desligada, a pipeline não tenta gravar (tabela inexistente não derruba a carga).

## 8. Fora deste contrato

Criar condição por API, cadastrar o encargo de cada condição (Controladoria), exibir vencimentos calculados, e a leitura do catálogo pela API do hub (rota de leitura, igual à da compra: `GET` do catálogo por unidade, que será definida na [[API-019-Proposta-e-Pedido-de-Venda-na-API-do-Hub]]).

## 9. Perguntas em aberto

1. ✅ **Arujá (HRM) tem conta Omie própria** (N16-79): são três catálogos, um por unidade.
2. As 330 condições da amostra são de qual conta?
3. Os dias da descrição valem a partir do faturamento ou da inclusão? (teste no Omie)
4. A Controladoria cadastra encargo para todas as 330 ou só para as usadas? 🟡 Só as usadas.
5. ✅ **Sem botão "Atualizar condições"** (N16-99): o vendedor só escolhe da lista, que vem do Omie e fica salva no banco; os dados mudam pouco.

## Ver também

[[Mapa-IncluirPedido-Omie]] · [[14-Telas-e-Experiencia-do-Usuario]] · [[SQL-016-Schema-core_comercial-Proposta-e-Pedido-de-Venda]] · [[API-019-Proposta-e-Pedido-de-Venda-na-API-do-Hub]] · [[03-Modelo-Novo-core_comissao]] · a renumeração da promoção (26/10/2026)
