---
id: roteiro-proposta-em-diante
tags: [roteiro, proposta, pedido-de-venda, compras, custo-real, comissao, api-acos-vital]
criado: 2026-10-27
atualizado: 2026-10-29
status: proposta
dono: Nathan
fontes: ["LOG-52 (status em 27/10/2026)", "Registro-de-Decisoes N16-110 a N16-112", "Perguntas-Proposta-Pedido-Comissao (OQ-16, OQ-21, OQ-48)", "Dump do Avhub para referência (completo), 26/10/2026", "av-hub branch refactor/menu-enxuto-vendas-orcamento-compras (11844de)", "api-acos-vital 0384e89 src/schemas/core_comercial (28 e 29/10)", "av-hub 758d5f0 app/api/comercial (29/10)", "[[Conexao-das-Telas-do-Pablo-com-a-API-do-Hub]]"]
---

# Roteiro: o que falta para o sistema ficar redondo, da proposta em diante

**Em uma frase:** as regras da proposta ao custo real estão decididas e só a proposta começou a ser construída na API do Hub (28 e 29/10); esta nota lista o que falta, etapa por etapa, e quem faz.

**Quando consultar esta nota:** para saber o que vem a seguir e quem responde por cada parte.

Legenda: ✅ existe · 🟡 existe em parte · 🔴 não existe. Os contratos desta parte foram removidos em 29/10/2026; o Robert cria os novos.

## Quem faz o quê

| Quem | Faz | Decisão |
|---|---|---|
| Robert | Rotas do módulo na `api-acos-vital` e o lote do MES. O Pablo acompanha | N16-117 |
| Nathan | Telas, pipeline, criação da proposta e começo da comissão | N16-115 |
| Gustavo | Banco e revisão | LOG-52 |

Por decisão do Nathan em 29/10, as **telas de propostas são do Robert** e as de **Orçamento são do Pablo, com o Robert**. Onde as linhas abaixo ainda dizem "Nathan (tela)" para proposta ou Orçamento, vale esta frase; o Nathan segue com pipeline, comissão e as telas do que já era dele. A N16-115 e a N16-118 do Registro ainda falam de outra divisão (ver relatório de 29/10).

Não existirá `core_comercial`: a proposta fica em `core_vendas_faturamento` (N16-116).

## Primeira entrega: a proposta (N16-118)

O Robert começa pela proposta. Produtos e histórico de preço vêm depois. As telas do Pablo ficam e o Robert troca só o backend delas (N16-119).

## Etapas

Banco, API e tela aparecem nessa ordem.

| Etapa | Situação | O que falta | Quem faz |
|---|---|---|---|
| `V0` Criar e revisar a proposta | 🟡 🟡 🟡 | A API do Hub já cria, lista, abre, revisa (`PUT`, com `If-Match`) e dá a linha do tempo (`/comercial/propostas`, 28 e 29/10); o banco é o `core_comercial` existente. A tela já lista, cria e abre pelo Hub; faltam ligar revisar, resumo e eventos no BFF e o cálculo de margem na API | Robert, Gustavo |
| Escolher cliente | 🟡 🟡 🔴 | Busca na carteira. Decidir prospect, Receita e compradores | Robert, Nathan |
| Condições de venda | 🔴 🔴 🟡 | Condição de pagamento do Omie, CFOP e cenário de imposto | Gustavo, Nathan, Robert |
| `V0.3`–`V0.5` Aprovar | 🟡 🟡 🔴 | `POST /comercial/propostas/:id/aprovar` existe (29/10); falta ligar no BFF e na tela, e conferir "incompleta" | Robert, Gustavo |
| `V0C` Cancelar proposta | 🟡 🟡 🔴 | `POST …/cancelar` e `…/copiar` existem (29/10); falta ligar no BFF e na tela | Robert, Gustavo |
| `B3`/`B4` Pedido de custo | 🔴 🔴 🔴 | Fila do Orçamento, sem prazo e cronometrada | Robert, Gustavo, Nathan |
| `B2` Página do produto | 🟡 🟡 🟡 | Estatística de 90 dias, score, volatilidade e matriz de preços | Robert, Nathan |
| Ofertas e cotação | 🟡 🔴 🟡 | Tabela de oferta, importar mapa e enviar cotação por e-mail | Robert, Gustavo, Nathan |
| `V0.6`–`V0.7` Transformar em pedido | 🟡 🟡 🔴 | `POST …/transformar` existe (29/10): cria o pedido no Hub com a simulação v1, sem escrever no Omie; faltam as 3 respostas obrigatórias, a fila para o Omie e a tela | Robert, Gustavo, Nathan (pipeline) |
| `V1`–`V3` Liberação | 🟡 🟡 ✅ | Gravar a liberação na resposta do `IncluirPedido` | Gustavo, Nathan |
| Pedido digitado no Omie | 🔴 🔴 🟡 | Trazer o pedido e o vendedor preencher a parte de compras (N16-106) | Robert, Gustavo, Nathan |
| `C6`/`C7` Compras usa a proposta | 🔴 🔴 🔴 | A OC puxar impostos, frete e fornecedor. Nenhuma OC emitida em produção | Robert, Nathan |
| `C8` Compra acima do valor | 🔴 🔴 🔴 | Aviso, aprovar ou reprovar e lista de reprovados | Robert, Gustavo, Nathan |
| `K1`–`K6` Custo real e comissão | 🔴 🔴 🔴 | Custo por evento, comissão estimada e real, decisão da Controladoria | Nathan (`K1`), Robert, Gustavo |
| Cancelar pedido | 🔴 🔴 🔴 | Cancelar no Omie, requisição e OC, tarja e comprado ao Estoque | Robert, Gustavo, Nathan |
| Datas e previsão de faturamento | 🔴 🔴 🔴 | Previsões, +1 dia útil e calendário com exceções | Gustavo, Robert, Nathan |
| Faturar em partes | 🔴 🔴 🔴 | Criar, mostrar e cancelar sequenciais | Gustavo, Robert, Nathan |

## O que vale para tudo e pendências

E-mail, notificações, perfis, testes no Omie e as pendências de 27/10 estão em "Detalhe técnico", seções 3 e 4.

## Ordem sugerida (N16-110, sem confirmação)

1. Fase 1: proposta nova, pedido pela fila do Omie, condições de pagamento, liberação, imposto por item na OC e comissão estimada.
2. Fase 2: compra acima do valor (`C8`), cancelamento com tarja e custo real por evento.
3. Fase 3: comissão real, faturar em partes, datas, fila do Fiscal, score e matriz de preços.

Em seguida à proposta vêm produtos e histórico de preço (seção 5.2 abaixo). A regra do score está em [[Proposta-Score-e-Volatilidade-OQ-46]].

## Detalhe técnico

Tudo abaixo é o conteúdo completo da nota original, sem cortes.


> [!info] Situação em 27/10/2026
> Levantamento pedido pelo Nathan. As **regras** estão decididas nas N16; **quase nada** desta parte está construído (em 29/10 existem as rotas `/comercial/propostas` da API do Hub e a lista, criar e abrir da tela; ver as linhas `V0` acima). Os contratos desta parte foram removidos em 29/10/2026 (o Robert cria os novos).
>
> Legenda: ✅ existe · 🟡 existe em parte · 🔴 não existe.
>
> **N16-117 (28/10/2026): o Robert conduz as rotas do módulo na `api-acos-vital` e o Pablo só acompanha.** As linhas abaixo já trazem o **Robert** como quem faz a API. A `api-comercial` fica no av-hub só para leitura.
>
> **Nathan cuida da criação da proposta e do começo da comissão** (N16-115, 27/10/2026); fora isso, **Quem faz** segue os donos dos contratos: **Robert** faz as rotas do módulo na `api-acos-vital` (LOG-52) e o lote do MES, com o Pablo acompanhando; Gustavo o banco e a revisão; Nathan as telas e a pipeline.

### 1. Antes de construir: realinhar os contratos à N16-111, N16-112 e N16-116

- **Os contratos SQL e de API desta parte foram removidos em 29/10/2026.** O Robert cria os novos já sobre `core_vendas_faturamento` e a API do Hub (N16-111, N16-112, N16-116), com o Gustavo revisando o banco.
  - Mapa do que reusar: [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] §0 e a tabela de unificação em [[Conexao-das-Telas-do-Pablo-com-a-API-do-Hub]].
- **Não existirá `core_comercial` (N16-116, 27/10/2026): a proposta fica em `core_vendas_faturamento`.** Os contratos novos nomeiam esse schema, e as rotas `/comercial/*` da fase 1 mudam de prefixo.
- **O `core_comercial` está em produção, vazio** (dump de 26/10: só `categorias_suprimento` 17, `parametros_custo` 1 e `unidades_emissoras` 3; o dump de 29/10 tem as mesmas 23 tabelas). Quem faz: Gustavo e **Robert**. Pela N16-116 ele **sai**: o que for útil (parâmetros de custo, emissoras) migra para o lugar certo. ⚠️ O código de 28 e 29/10 (propostas, transformar em pedido) ainda grava em `core_comercial.*`; isso contradiz a N16-116 e está como dúvida no relatório de 29/10.

### 2. O fluxo, etapa por etapa

| Etapa | Banco | API do Hub | Tela | O que falta | Contratos | Quem faz |
|---|---|---|---|---|---|---|
| **V0 · Criar e revisar a proposta** | 🔴 | 🔴 | 🟡 | **Banco e API:** proposta, itens, revisões e número próprio só com dígitos. **Tela:** já tem o layout novo (padrão do Simulador e da emissão da OC), mas ainda usa o modelo antigo (fechar, perder, reabrir) e não salva. Faltam a lista com filtros e KPIs e o cálculo de margem e letra na API | | **Robert** (API, começa por aqui, N16-118), **Nathan** (tela, N16-115), Gustavo (banco) |
| **Escolher cliente** | 🟡 | 🟡 | 🔴 | Busca de cliente da carteira (`core.parceiros` não filtra por tipo). Decidir prospect, consulta à Receita e compradores | LOG-52 §0 | **Robert** (API), Nathan (tela) |
| **Condições de venda** | 🔴 | 🔴 | 🟡 | Condições de pagamento de venda do Omie (pipeline `ListarParcelas`). CFOP e cenário de impostos por item (N16-83) | | Gustavo (tabela), Nathan (pipeline), **Robert** (CFOP e cenário na API) |
| **V0.3–V0.5 · Incompleta e aprovar** | 🔴 | 🔴 | 🔴 | Aprovar com a revisão atual, travar a aprovada, selo "incompleta" (item sem custo e sem fornecedor) | | **Robert** (API), Gustavo (banco), Nathan (tela) |
| **V0C · Cancelar a proposta** | 🔴 | 🔴 | 🔴 | Cancelar com motivo, duplicar, comissão estimada virando histórico | | **Robert** (API), Gustavo (banco), Nathan (tela) |
| **B3/B4 · Pedido de custo** | 🔴 | 🔴 | 🔴 | Fila do Orçamento, cronometrada e sem prazo (N16-58). A tela atual é a do Pablo, com SLA | | **Robert** (API), Gustavo (banco), Nathan (tela) |
| **B2 · Página do produto e matriz de preços** | 🟡 | 🟡 | 🟡 | Os dados existem (compras do Omie e cotações do Orçamento antigo). Faltam estatística de 90 dias, score e volatilidade do fornecedor e a matriz | | **Robert** (API), Nathan (tela) |
| **Ofertas e cotação a fornecedor** | 🟡 | 🔴 | 🟡 | Uma tabela de oferta (`parceiros_produtos` está vazia), importar mapa, envio do pedido de cotação por e-mail | | **Robert** (API), Gustavo (banco), Nathan (tela) |
| **V0.6–V0.7 · Transformar em pedido** | 🔴 | 🔴 | 🔴 | **Pedido:** `pedidos`, `pedidos_itens` e as 3 respostas obrigatórias (Qualidade, faturar em partes ou inteiro, data de previsão). **Omie:** fila e pipeline com `IncluirPedido`, erro com "Tentar novamente" | | **Robert** (API), Gustavo (banco), Nathan (pipeline e tela) |
| **V1–V3 · Liberação** | 🟡 | 🟡 | ✅ | A liberação do pedido do Omie existe (LOG-26). Falta gravar a liberação na resposta do `IncluirPedido` | | Gustavo (banco e API), Nathan |
| **Pedido digitado no Omie no mesmo fluxo** | 🔴 | 🔴 | 🟡 | Trazer o pedido para `pedidos` e o vendedor preencher a parte de compras em Meus Pedidos | N16-106 | **Robert** (API), Gustavo (banco), Nathan (tela) |
| **C6/C7 · Compras usa os dados da proposta** | 🔴 | 🔴 | 🔴 | A OC puxar impostos, frete e fornecedor da proposta, com os campos de imposto na OC. O circuito de OC do Hub ainda não emitiu nenhuma em produção (`ordens_compra` = 0) | | **Robert** (rota da parte de compras), Nathan (pipeline e tela) |
| **C8 · Compra acima do valor** | 🔴 | 🔴 | 🔴 | Aviso ao vendedor em Meus Pedidos, aprovar ou reprovar, lista de reprovados de Compras | | **Robert** (API), Gustavo (banco), Nathan (tela) |
| **K1–K6 · Custo real e comissão nova** | 🔴 | 🔴 | 🔴 | **Custo e decisão:** custo por evento (OC, NF de entrada, lote), comissão estimada e real, decisão da Controladoria. **Notas:** abatimento por devolução e recusa | | **Nathan** (começo da comissão: K1, a estimada, N16-115), **Robert** (resto da API da comissão e o lote do MES), Gustavo (banco) |
| **Cancelar pedido** | 🔴 | 🔴 | 🔴 | Cancelar no Omie, cancelar a requisição e a OC não emitida, tarja, mandar o comprado ao Estoque | | **Robert** (API), Gustavo (banco), Nathan (pipeline e tela) |
| **Datas e previsão de faturamento** | 🔴 | 🔴 | 🔴 | Previsão inicial, entrega de Compras e do CCP, +1 dia útil, calendário com exceções do marketing | | Gustavo (banco), **Robert** (API), Nathan (tela) |
| **Faturar em partes (sequenciais)** | 🔴 | 🔴 | 🔴 | Criar, mostrar e cancelar sequenciais. A terceira tabela já tem os dados ligados | | Gustavo (banco), **Robert** (API), Nathan (tela) |

### 3. O que vale para tudo

- **Serviço de e-mail do Hub:** ⏸ **último plano, para o futuro** (Nathan, 27/10/2026, N16-113). A API não envia e-mail; até lá, a proposta vai ao cliente e o pedido de cotação ao fornecedor fora do sistema.
- **Notificações do Hub:** ⏸ **último plano, para o futuro** (N16-113). O sino existe na tela, mas não há nada no Hub.
- **Um motor de margem e comissão na API** (**Robert**): hoje está só no front (`lib/simulador/motor.ts`) e a N16-109 pede uma fonte só.
- **Perfis e permissões novos** de Vendas, Orçamento, Compras e Comissão (OQ-21, adiada; Nathan e Gustavo). Hoje só o Admin (Dev) tem as telas.
- **Testes no Omie** (OQ-16, OQ-48; Nathan, depois das telas, N16-82): pedido que nasce bloqueado, cancelar ou excluir, e como criar sequencial.
- **Revisão completa do Orçamento antigo** do Hub (`/orcamento/*`, `orc_*`), pedida pelo Nathan em 27/10 (**Robert**, com o Pablo acompanhando, e o Gustavo).

### 4. Pendências do que já foi feito (27/10/2026)

- **PR da branch** `refactor/menu-enxuto-vendas-orcamento-compras` do av-hub, que o Nathan ainda vai revisar (Nathan).
- **Telas que hoje mostram "ainda não existe na API do Hub":** propostas, relatórios, Dashboard Comercial, ofertas, pedidos de custo, telha e o sino. Decidir se ficam no menu até existirem (Nathan).
- ✅ **`api-comercial` fora de produção e do BFF** (27/10, N16-111) e só leitura no repositório (28/10, N16-117).
- **Família do produto aparece como código:** o Hub nega `/familias_produtos` ao perfil Admin (Dev), por permissão no Hub (Gustavo).

### 5. Primeiro do Robert: a proposta (N16-118)

> [!important] Nathan, 28/10/2026: "Robert começará por proposta". Passa a ser a **primeira entrega** do projeto, **antes** de produtos e histórico de preço (que era a N16-114 e vira a seção 5.2). O Pablo acompanha (N16-117).

> **N16-119 (28/10/2026): as telas do Pablo ficam e o Robert troca o backend delas; não se refaz 100%.** O front do módulo não é apagado: o BFF passa a chamar as rotas novas da API do Hub e as telas se adaptam ao vault onde divergem (estados, número, sem fechamento parcial).

**5.1 A proposta na `api-acos-vital`, em `core_vendas_faturamento` (N16-116).** O **Robert** faz as rotas e o **Nathan** a tela e o começo da comissão (N16-115), com o Gustavo no banco. As rotas são as das linhas 1 a 17 da lista de rotas que faltam (criar e revisar, lista com filtros e KPIs, revisões, eventos, cálculo de margem e letra, duplicar, aprovar, cancelar e completude). A discussão da parte E (formato do número, critério de "incompleta", revisão, vendedor do Omie, cliente, condições) vem **antes** de escrever o contrato.

**5.2 Em seguida: produtos e histórico de preço** (era a N16-114).

Entrega depois da proposta, na `api-acos-vital`, sobre o que o Hub já tem (N16-111, N16-112), conforme os contratos que o Robert vai criar:

| # | Entrega | Fonte no Hub | Contrato |
|---|---|---|---|
| 1 | **Revisão completa do Orçamento antigo** (`/orcamento/*`, `orc_*`): o que fica, muda ou sai para atender só o vault | `core_compras` `orc_*` (2.697 cotações, 10.524 fornecedores, 16 categorias) | este roteiro, §3 |
| 2 | **Lista e busca de produtos** com o nome da família | `core.produtos` (125.852), `core.familia_produtos` | |
| 3 | **Histórico de preço do produto**: compras reais do Omie e cotações, por fornecedor e no tempo | `pedidos_compras_itens` (47.125), `orc_cotacoes`, `/produtos/:id/fornecedores` | `GET /orcamento/produtos/:id` |
| 4 | **Página do produto (`B2`)**: últimos preços, média, flutuação anual, mensal e total, volatilidade, dado recente (7 dias) e top fornecedores com score (preço 50%, prazo 30%, histórico 20%, pesos como parâmetro com vigência) | idem | [[Proposta-Score-e-Volatilidade-OQ-46]] |
| 5 | **Série do gráfico** ("bolsa de valores") | idem | `GET /orcamento/produtos/:id/serie` |
| 6 | 🟡 **Perfil técnico do produto** (norma, material, kg/m, dimensões), se couber nesta etapa: o `especificacoes` do Omie não tem esses dados | extensão de `core.produtos` | LOG-52 §3.2 |

**Depois, na mesma linha:** matriz de preços v1 e ofertas (uma tabela só, N16-112). **Tela (Nathan):** Produtos e Página do produto já leem o Hub; ganham o histórico, a série e o score quando as rotas existirem.

### 6. Ordem que o vault sugere (N16-110, sem confirmação)

1. **Fase 1:** proposta nova, pedido pela fila do Omie, condições de pagamento, liberação, imposto por item na OC e comissão estimada.
2. **Fase 2:** compra acima do valor (C8), cancelamento com tarja e custo real por evento.
3. **Fase 3:** comissão real, faturar em partes, datas e calendário, fila do Fiscal, score e matriz de preços.

### Ver também

[[Conexao-das-Telas-do-Pablo-com-a-API-do-Hub]] · [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] · · · · [[Registro-de-Decisoes]] · [[Perguntas-Proposta-Pedido-Comissao]]
