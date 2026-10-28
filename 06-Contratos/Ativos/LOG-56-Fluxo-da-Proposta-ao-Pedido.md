---
id: LOG-56
aliases: ["Contrato 56", "56-Fluxo-da-Proposta-ao-Pedido"]
tags: [contrato, contrato-logica, contrato-api, proposta, pedido-de-venda, compras, comissao, av-hub, fluxo, cancelamento, devolucao]
criado: 2026-10-16
atualizado: 2026-10-28
status: proposta
sistemas: [hub-banco, hub-api, hub-front, pipeline]
dono: "Nathan e Robert"
etapa_0b: [V0.1, V0.2, V0.3, V0.4, V0.5, V0C, V0.6, V0.7, V1, C6, C7, C8, K1, K2, K3, K4, K5, K6]
fontes: ["Registro-de-Decisoes (N16-01 a N16-74)", "Estudo-Omie-API (documentação do Omie lida em 21/10/2026)", "Proposta-Orcamento-Comissao/01-Decisoes/Respostas-da-Controladoria-2026-10-19 (fora do vault)", "Proposta-Orcamento-Comissao/01-Decisoes/Respostas-de-Compras-2026-10-19 (fora do vault)", "09-Diagramas/fontes/tela-simulador-comissao.png", "09-Diagramas/fontes/email-divergencia-margem-pv27824.jpg e pv28204.jpg", "av-hub app/(protected)/comissoes/simulador/page.tsx, lib/simulador/motor.ts", "03-Sistemas/Comissao/01-Motor-Atual-Como-Calcula", "11-Proposta-e-Pedido-de-Venda", "api-comercial 5aa5311: prisma/models/vendas.prisma, enums.prisma, src/modules/propostas/propostas.service.ts, propostas.routes.ts, src/modules/custos/custos.routes.ts, src/domain/permissoes/capacidades.ts, src/domain/numeracao/numeroProposta.ts", "Dump Avhub (Esqueleto).sql: contadores_documento (16552), fn_proximo_numero_documento (8110), pedidos_vendas_liberacao (18285)", "omie-elt-pipeline envioOrdensCompra.ts:18-40", "Proposta-Orcamento-Comissao/08-Reuniao/Proposta-Orcamento-Pedido-Comissao.docx (fora do vault)"]
criado_original: 2026-10-16
---

# Contrato 56 — Fluxo da proposta ao pedido de venda (regras de negócio ponta a ponta)

> **Onde atua:** av-hub: banco, API, front · pipeline Omie

> [!info] Situação em 28/10/2026
> **Status:** `proposta` · **Pasta:** `Ativos` · **Nós do 0b:** `V0.1` a `V0.7`, `V0C`, `V1`, `C6`, `C7`, `C8` e `K1` a `K6` · **Dono:** Nathan (regra, front e começo da comissão) e Robert (rotas, N16-117; o Pablo acompanha)
>
> - 📝 **28/10/2026, quem faz o quê (N16-115, N16-117, N16-118):** a primeira entrega é a **proposta**. O **Nathan** faz a criação e a revisão da proposta (`V0.1`, `V0.2`) e o começo da comissão (`K1`); o **Robert**, as rotas na `api-acos-vital`; o **Gustavo**, o banco. O Pablo acompanha. As telas que o Pablo já fez ficam e trocam de backend (N16-119).
> - 📝 **N16-116:** não existirá `core_comercial`; proposta, itens, revisões e pedido do Hub ficam em `core_vendas_faturamento`.
> - 📝 **N16-113:** e-mail e notificações do Hub ficam para o futuro; a proposta vai ao cliente fora do sistema e o sino não ganha backend agora.
> - 📝 As **regras** vêm das decisões N16-01 a N16-74 do Nathan (16 a 21/10/2026), registradas em [[Registro-de-Decisoes]]. Rotas, nomes de estado e códigos de erro são **propostas 🟡**.
> - ✅ O que existe hoje está só no `api-comercial` (módulo de teste do Pablo, N14-15), não na `api-acos-vital`: proposta, revisão, versões, cálculo, duplicar, custo por item, pedido de custo e média de preços ([[11-Proposta-e-Pedido-de-Venda]]).
> - 🔴 **Nada** de aprovada, incompleta, cancelar com histórico, numeração só numérica, pedido por API, fila, liberação na criação, `C6`, `C7`, `C8`, cancelamento de pedido e devolução existe em código.
> - 📝 **Mudou em 20/10:** se Compras compra por mais que o valor da proposta, **o vendedor é avisado em "Meus Pedidos" e aprova ou reprova** (`C8`, N16-60 a N16-67). Isso **supera** a regra de 16/10 de que o vendedor não recebia aviso (N16-08, N16-18).
> - 📝 **O vendedor não é o dono do dado de custo** (N16-54): o dono é Compras e o Orçamento.
> - ✅ O Omie **tem** cancelar pedido por API (`CancelarPedidoVenda`), e o **vendedor** cancela, edita e exclui (N16-84). 🟡 O pedido criado por API pode nascer **bloqueado** (campo `bloqueado` do cabeçalho): ver [[Estudo-Omie-API]] e [[Mapa-IncluirPedido-Omie]].
> - Contratos irmãos: [[LOG-57-Menu-Vendas-Orcamento-Compras]], [[LOG-58-Liberacao-do-Pedido-Origem-Proposta]]; banco e API em SQL-016, SQL-017, API-019 a API-022.
> - 🧪 **Anexos de banco testados em Postgres 18 (21/10):** SQL-016 `0003` (tabela `divergencia_compra`, funções do aviso ao vendedor, cancelamento do pedido) com teste `0004` (11 erros esperados, todos conferidos); SQL-018 `0004` (pendência de devolução parcial, devolução total) com teste `0005` (7 erros esperados) e o teste anterior `0002` intacto (14 erros). O estado da proposta no banco se chama `TRANSFORMADA` (SQL-016); este contrato usa o mesmo nome.

Selos em [[Regras-do-Vault]].

## 1. Por quê

Hoje o pedido de venda nasce direto no Omie e chega ao av-hub travado. O que vem antes (a proposta ao cliente, o custo e a comissão do vendedor) não tem lugar no fluxo. O contrato fixa as regras de negócio do trecho que vai da proposta até o pedido liberado, da requisição do PCP até a OC (`C6`, `C7`, `C8`) e do cancelamento e da devolução, de modo que o Pablo (módulo), o Gustavo (banco) e o Nathan (telas e pipeline) construam a mesma coisa.

## 2. O que muda e o que não muda

| Muda | Não muda |
|---|---|
| A proposta é o primeiro nó do fluxo (`V0`) | O módulo **Comissões atual** (`core_comissionamento`) |
| O pedido deixa de ser digitado no Omie: botão "Transformar em pedido" cria o pedido por API (fila e pipeline, padrão da OC) | A **aprovação de desconto e margem** é física neste ciclo; no sistema, no próximo (N16-12) |
| Número próprio e só numérico para proposta e pedido, por unidade e tipo | O pedido digitado direto no Omie continua a existir e entra no mesmo fluxo do Hub (N16-106) |
| "A Qualidade acompanha?" obrigatório na proposta | O motor de cálculo da comissão (menor entre o percentual do vendedor e o de compras) |
| Compras confere a proposta (`C6`), usa o valor correto (`C7`) e, se for maior, o vendedor aprova (`C8`) | O preço fechado com o cliente (não muda, N16-17) |
| A tela da proposta ganha o formato do Simulador de Comissão (N16-19) | O Simulador atual e o módulo Comissões atual (seguem como estão) |
| Pedido cancelado avisa a OC e o PCP e manda o comprado ao Estoque | O vendedor cancela, edita e exclui o pedido; o Hub chama o Omie por API (`CancelarPedidoVenda`, `AlterarPedidoVenda`, `ExcluirPedido`) |

## 3. Regras de negócio

Cada regra tem a decisão de origem. 🟡 = proposta deste contrato (default de uma pergunta em aberto).

### 3.1 Criar e revisar (`V0.1`, `V0.2`)

| # | Regra | Origem |
|---|---|---|
| R1 | O vendedor cria a proposta com cliente, itens e dados de venda. O número é automático e só numérico (N16-04); a tela e o PDF podem mostrar um prefixo | 📝 N16-01, N16-04 |
| R2 | Proposta e pedido de venda têm sequências **próprias**, **por unidade e tipo** (`contadores_documento`, com `tipo` novo `proposta` e `pedidos`; o `CHECK` atual só aceita `ordem_compra` e `requisicao_compra`, Dump Avhub 16560). O número do Omie continua a chave no MES | 📝 N16-04, N16-26 |
| R3 | A proposta se ajusta e se revisa **até ser aprovada**. Cada mudança do conteúdo comercial gera uma revisão (a revisão guarda um snapshot, como hoje em `propostas_versoes`) | 📝 N16-03 |
| R4 | O vendedor preenche as partes de vendas e de orçamento e compra com o que conseguiu (telefone, e-mail), mas **não é o dono do dado de custo**: o dono é Compras e o Orçamento. Se não tem o dado, **pede uma cotação ao setor orçamentário** (`B3`) ou consulta o histórico de preços das OC. Ele decide o valor que põe | 📝 N16-06, N16-54 |
| R5 | O vendedor tem a **página do produto** (`B2`): histórico, top fornecedores com score, últimos preços, flutuação anual, mensal e total, volatilidade e valor médio. É só consulta | 📝 N16-07, N16-52, N16-55 |
| R6 | O câmbio da proposta em moeda estrangeira vem da PTAX do Hub, **do dia da aprovação** | 📝 N16-13, N16-27 |
| R7 | O cliente é do cadastro comercial; para virar pedido precisa existir no Omie da conta da empresa emissora 🟡 | 🟡 caso de borda 5 |
| R8 | A comissão estimada nasce ao criar e se recalcula a cada revisão (`V0.3`, `K1`). O vendedor vê só a que ele colocou | 📝 N16-10 |
| R8a | O **pedido de custo** não tem prazo fixo: o mais rápido possível, com o **tempo cronometrado**. O vendedor nunca fica bloqueado. O setor orçamentário é **novo** (o Moisés é uma das pessoas, N16-104) e o sistema funciona sem orçamentista | 📝 N16-58, N16-59 |

### 3.2 Incompleta, aprovar, cancelar (`V0.3` a `V0.5`, `V0C`)

| # | Regra | Origem |
|---|---|---|
| R9 | **Proposta incompleta** é a que tem **qualquer item sem custo e sem fornecedor** | 📝 N16-03, N16-31 |
| R10 | A proposta incompleta **não pode ser aprovada**. A tela marca "incompleta" e o botão de aprovar não funciona | 📝 N16-03 |
| R11 | A aprovação de desconto e margem pela Gerência é **física**. O sistema não bloqueia nem pede aprovação neste ciclo | 📝 N16-12 |
| R12 | O sistema registra a aprovação num estado `APROVADA`: **o vendedor marca "aprovada"**, confirmando a aprovação física; o sistema grava quem, quando e **qual revisão** | 📝 N16-02, N16-03, N16-25 |
| R13 | A tela de confirmar mostra o número da revisão, o total e a margem, para ninguém aprovar fisicamente uma revisão e marcar outra 🟡 | 🟡 |
| R14 | **Aprovada, a proposta não se ajusta mais.** Nem preço, nem item, nem custo, nem desconto | 📝 N16-03 |
| R15 | **Cancelada** é um **estado único**, com motivo; nunca vira pedido. A comissão estimada vira histórico e o vendedor pode consultar. O histórico guarda o motivo, quem cancelou e a data (atende a auditoria) | 📝 N16-02, N16-24, N16-42 |
| R16 | A proposta cancelada **não reabre**. Para refazer, o vendedor duplica (a rota de duplicar existe) | 📝 N16-24 |
| R17 | **Não existe fechamento parcial.** Uma proposta equivale a um pedido | 📝 N16-02 |

### 3.3 Transformar em pedido e criar no Omie (`V0.6`, `V0.7`, `V1`)

| # | Regra | Origem |
|---|---|---|
| R18 | O botão "Transformar em pedido de venda" só aparece na proposta `APROVADA` | 📝 N16-02 |
| R19 | Ao transformar é **obrigatório** marcar se **a Qualidade acompanha todo o processo, desde o zero** (Sim ou Não), além da data de previsão de faturamento (R67) e de **faturar em partes ou somente inteiro** (R73). Sem as três, o pedido não é criado. O vendedor pode corrigir a marcação da Qualidade até o MES importar, com histórico `alterado` | 📝 N16-05, N16-29, N16-88, N16-89 |
| R20 | A API grava o pedido numa **fila** e a pipeline o envia ao Omie por API (`IncluirPedido`), pelo mesmo padrão da OC (`GET …/fila-omie`, `PATCH …/sincronizacao`, `POST …/reenviar`) | 📝 N16-02 |
| R21 | O pedido do hub guarda `status_sincronizacao_omie` com `pendente`, `sincronizado`, `erro`. Com `erro` (o Omie recusou), o vendedor vê o **motivo** e o botão **"Tentar novamente"**; a proposta continua `APROVADA` e a marcação da Qualidade não se perde | 📝 N16-36 |
| R22 | Criado o pedido, a proposta passa a `TRANSFORMADA` e fica travada. Um pedido por proposta (vínculo único) | 📝 N16-02; 🟡 estado |
| R23 | O pedido **nasce liberado**, sem `V3`. O histórico de liberação (`liberado`) é gravado **na resposta do `IncluirPedido`**, com a marcação da proposta e `liberado_por` = quem transformou ([[LOG-58-Liberacao-do-Pedido-Origem-Proposta]]) | 📝 N16-05; ✅ OQ-15 pelo [[Estudo-Omie-API]] |
| R24 | O `V1` tem duas origens: a proposta, ou o pedido digitado direto no Omie. Os dois ficam em `core_vendas_faturamento.pedidos` (N16-116) (origem `PROPOSTA` ou `OMIE`) e seguem o mesmo fluxo; o do Omie ainda passa pelo portão `V2`/`V3` (R38) | 📝 N16-05, N16-106 |
| R25 | A proposta com produto pendente (`PEND-xxxx`, sem cadastro no Omie) **não vira pedido** até o cadastro; o Fiscal cria o produto | 📝 N16-28 |
| R26 | O pedido vai ao Omie com o **código de integração** do pedido (`codigo_pedido_integracao`) e o de cada item (`codigo_item_integracao`); a pipeline passa a **gravar** esses códigos no hub. O número do Omie continua a chave do pedido no MES e na liberação. 🟡 Mandar o nosso `numero_pedido` no `IncluirPedido` e a etapa `"10"`: testar | 📝 N16-26; 🟡 [[Estudo-Omie-API]] |
| R26a | O pedido criado por API pode nascer **bloqueado** na tela do Omie; se o Fiscal não conseguir faturar, a pipeline manda `AlterarPedidoVenda` com `bloqueado = "N"` 🟡 | ❓ teste no Omie |

### 3.4 Compras confere e usa o valor correto (`C6`, `C7`)

| # | Regra | Origem |
|---|---|---|
| R27 | Depois do pedido, o PCP abre as requisições (`P3`). Quando a requisição aparece para o Comprador, o sistema **puxa os dados da proposta** (impostos, frete, fornecedor) para os campos da OC (`C6`) | 📝 N16-08, N16-38 |
| R28 | Compras **confere se os impostos estão corretos**, **edita os campos no hub** e valida se segue ou busca valor ou condição melhor. Pode usar o fornecedor do vendedor (opção de puxar da proposta) ou outro | 📝 N16-08, N16-38, N16-53 |
| R29 | Compras usa o **valor correto** na OC (`C7`). A OC segue as regras de aprovação de sempre (acima de R$ 30 mil, o Gerente de Compras) | 📝 N16-08, N14-21 |
| R30 | **Compras não altera a proposta.** O preço fechado com o cliente não muda; só a margem e a comissão caem | 📝 N16-08, N16-17 |
| R31 | **Imposto da OC:** o hub não guarda IPI, ICMS, ST e DIFAL por item; **o Omie guarda** ICMS, ST, IPI, PIS e COFINS por item do pedido de compra, **em valor e sem DIFAL**. O Nathan traz esses dados do Omie para o hub; o que Compras edita no hub **volta ao Omie pela mesma sincronização da OC** | 📝 N16-53; [[Estudo-Omie-API]] |
| R32 | A Controladoria vê o custo real e a diferença | 📝 N16-18 |

### 3.4a Compra acima do valor da proposta (`C8`)

| # | Regra | Origem |
|---|---|---|
| R50 | Se Compras compra por um valor **maior** que o da proposta (X = 10, Y = 20), o **vendedor é avisado** e **aprova ou reprova** a compra, porque ela muda a margem e a comissão dele. **Supera** a regra antiga de que o vendedor não era avisado | 📝 N16-60, N16-61 |
| R51 | **Sem tolerância:** qualquer valor acima pede a aprovação. **Por produto** (por item do pedido), porque uma OC tem vários produtos e cada um mexe na margem e na comissão de um pedido e de um vendedor. Uma OC com itens de vendedores diferentes avisa cada um dos seus | 📝 N16-63 |
| R52 | O aviso aparece na tela **"Meus Pedidos"** do vendedor, com o andamento da venda e o que está aberto para ele. **Sem tempo limite**: se ele não responde, o pedido fica na lista dele | 📝 N16-63, N16-64 |
| R53 | O aviso traz: **PV e OC**, **margem atual** (a do simulador), **margem considerada** (a da compra real), **motivo da divergência** (escrito por Compras, obrigatório), a **diferença entre o custo considerado e o realizado** e o **fornecedor escolhido com prazo e pagamento** (conteúdo do e-mail de hoje) | 📝 N16-62 |
| R54 | **Aprovada:** o processo continua; a margem e a comissão do vendedor caem; o preço do cliente não muda. **Reprovada:** **Compras leva o caso à Gerência (João Vitor ou Sérgio Vital), fisicamente**, e, se preciso, conversa com o vendedor. A aprovação da Gerência **é uma conversa**, não botão; a Gerência **não cancela** no sistema | 📝 N16-61, N16-65, N16-66 |
| R55 | **Compras resolve e registra a solução** (novo valor, novo fornecedor, mantido ou pedido cancelado) e **notifica o vendedor**. O vendedor só vê a notificação e resolve **fisicamente**; não há botões de corrigir, renegociar ou cancelar | 📝 N16-67, N16-73 |
| R56 | Compras tem uma **lista dos casos reprovados ainda sem solução**, com a idade de cada um (cronometrada) e quem do Compras o assumiu | 📝 N16-73; 🟡 o desenho |
| R57 | Se a compra sai **mais barata** (a margem sobe), o aviso é **só informativo**: o vendedor não precisa aprovar | 📝 N16-65 |
| R57a | Estados do pedido de aprovação 🟡: `PENDENTE`, `APROVADO`, `REPROVADO` (em tratativa), `RESOLVIDO`; cada passo guarda quem e quando | 🟡 N16-66 |

### 3.5 Custo real e comissão (`K1` a `K6`)

| # | Regra | Origem |
|---|---|---|
| R33 | O custo real por item do pedido é gravado **por evento** (OC, lote do Estoque, matéria-prima do fabricado), com data, material, origem, quantidade e valor; o custo do item é a soma das linhas e o do pedido a soma dos itens | 📝 N16-09 |
| R33a | **A linha da OC nasce na aprovação da OC, com o valor da OC (provisório), e vale só até o recebimento: no recebimento, o valor da NF de entrada a substitui.** OC cancelada antes de receber estorna a linha. O **lote** é de uma OC específica e não soma o custo de novo | 📝 N16-23, N16-37, N16-40 |
| R33b | O **CCP** (equipe do PCP que cuida do follow-up das compras, N14-24) **vincula a NF de entrada à OC**, na tela de Follow-up (N16-86); o item do pedido de venda vem do vínculo da OC com a requisição, inclusive com várias NFs por OC e KG contra PC; a ligação automática do Omie **não existe na prática** | 📝 N16-57; ❓ como o sistema guarda o vínculo (OQ-34, OQ-39) |
| R34 | Enquanto a quantidade do item não está coberta, o custo é **parcial** e a comissão é paga **só sobre as peças com custo real**; quando o custo completa, a diferença vai para a apuração seguinte, para nova decisão | 📝 N16-09, N16-48 |
| R35 | A comissão **fecha por nota fiscal** (`K3`), com o **percentual vigente naquele momento**, e chega à Controladoria já calculada. O mesmo item pode sair em várias notas, **sem pagar duas vezes a mesma quantidade** | 📝 N16-10, N16-49 |
| R36 | **Decidem** a Controladoria, a Gerência e a Coordenação, com as mesmas permissões: aprovar, desaprovar, bloquear (e desbloquear), cortar ou alterar, por valor ou percentual, **sem teto**, sempre com justificativa e rastro. **Ninguém decide sobre a própria comissão** | 📝 N16-44, N16-45 |
| R36a | O vendedor só vê a comissão real **depois da decisão**, com a **justificativa** (`K5`); desaprovada aparece com R$ 0 e o motivo | 📝 N16-10, N16-45, N16-46 |
| R37 | Detalhe do fluxo: [[13-Custo-Real-e-Comissao-no-Fluxo]]; modelo da comissão e do custo realizado: SQL-016 e SQL-018 | — |

### 3.6 Pedido digitado direto no Omie

| # | Regra | Origem |
|---|---|---|
| R38 | O pedido digitado direto no Omie entra no **mesmo fluxo e na mesma tela** do pedido da proposta (N16-106): chega travado, com a parte de vendas pronta (só se altera no Omie); o vendedor responde a Qualidade e o faturamento em partes na tela do pedido, o que grava a liberação de sempre (`pedidos_vendas_liberacao`, [[LOG-26-Vendas-Liberacao-Pedido]]), e preenche a parte de compras, que é a simulação da comissão. O job o traz para o Hub (`fn_pedidos_omie_sincronizar`, um item por produto); [[01-Vendas-Liberacao]] | 📝 N16-05, N16-91, N16-106 |
| R39 | Não há `V0`. **Nada trava** por causa da parte de compras: PCP e Compras seguem. Compras confere e avisa o vendedor se comprar mais caro (`C6` a `C8`, comparando com o custo que ele preencheu). A comissão espera a simulação: a nota que sair antes **espera**, a Controladoria já vê a margem real, e com as duas fecha pelo menor percentual | 📝 N16-104, N16-105, N16-106 |

### 3.7 A tela da proposta, a visão de Compras e a da Controladoria (N16-19, N16-20)

Referência: a tela atual do Simulador de Comissão (`09-Diagramas/fontes/tela-simulador-comissao.png`; `av-hub/app/(protected)/comissoes/simulador/page.tsx`). Comparação bloco a bloco, por visão, em [[13-Custo-Real-e-Comissao-no-Fluxo]].

| # | Regra | Origem |
|---|---|---|
| R40 | A tela da proposta é **semelhante à do Simulador**: bloco **Pedido** (unidade, número da proposta, cliente, vendedor, itens), bloco **Condições comerciais** (estado de destino e ICMS, condição de pagamento e encargo, "com impostos", frete na compra com rateio, valor ST, imposto retido ou DIFAL, frete na venda), bloco **Itens** (Compra, Venda, Resultado) e **rodapé de totais** (custo, venda, total da NF, sugerido, mark-up real, mark-up sobre a compra, margem e letra) | 📝 N16-19 |
| R41 | O **motor é o mesmo** (menor entre o percentual do vendedor e o de compras, regras fixas, bloqueios, blacklists), com as **mesmas entradas** que o atual, em **tabelas novas e isoladas** (`core_comissao`; N16-21). Os parâmetros de **"Maio/23"** continuam, com vigência. O **encargo da condição de pagamento entra no preço sugerido**, não no custo (N16-22) | 📝 N16-11, N16-19, N16-21, N16-22, N16-39 |
| R42 | O cálculo sai do navegador e roda na API (hoje `calcularSimulacao`, `simulador/page.tsx:1053`); os parâmetros vigentes ficam gravados com cada cálculo para a revisão ser reproduzível | 🟡 proposta ([[03-Modelo-Novo-core_comissao]]) |
| R43 | **Visão do vendedor (a):** preenche o bloco Compra e a Venda; vê custo líquido, sugerido, margem, letra e a **comissão estimada que ele colocou** (`K1`). **Não vê** a comissão real antes da decisão. Na aprovação de `C8`, vê o valor da compra do produto dele | 📝 N16-10, N16-60 |
| R44 | **Visão de Compras (b):** a mesma tela em **leitura** na emissão da OC (`C6`): o cotado do vendedor ao lado do valor da OC e do fornecedor. O valor correto entra na **OC** (`C7`); Compras não altera a proposta | 📝 N16-08, N16-19 |
| R45 | O passo do motor atual em que **Compras aprova o percentual de compras** (versão `COMPRAS`, `simulacoes.route.js:233-259`) **sai do fluxo e fica pronto no sistema, desligado**: o cálculo `REAL` gerado pelos eventos de custo o substitui. O valor estimado por Compras vem do Omie, sem digitação. Compras ainda valida | 🟡 N16-51, OQ-28 |
| R46 | **Visão da Controladoria (c):** a mesma tela com a verdade na tabela: custo líquido real, margem real, letra real e comissão real, **lado a lado com os estimados**, por item e no total, com a decisão e a **justificativa obrigatória** | 📝 N16-10, N16-19 |
| R47 | **Cada evento de custo carrega as suas condições** (condição de pagamento, IPI, ICMS, ST, DIFAL, frete, fornecedor). O custo líquido do evento sai da **fórmula do motor** com as condições do próprio evento; o custo líquido do item é a soma dos eventos. **Só a venda** tem um conjunto de condições por pedido | 📝 N16-20 |
| R48 | A Controladoria abre, em cada item, o **drill-down por evento**. O vendedor não vê o drill-down | 📝 N16-19, N16-20; colunas 🟡 |
| R49 | **Imposto real do evento:** vem dos campos de imposto da OC (editados por Compras, vindos do Omie) e da NF de entrada (percentual e valor). Até existirem, o evento calcula **sem imposto** e a linha mostra "sem imposto" para a Controladoria. O **DIFAL da compra** fica fora do custo líquido (provisório) | 📝 N16-20, N16-53; 🟡 N16-51 |

### 3.8 Cancelamento de pedido

| # | Regra | Origem |
|---|---|---|
| R58 | Se o vendedor não resolve ou não aceita o valor de Compras, o pedido pode ser **cancelado**; ele **renegocia fisicamente com o cliente** | 📝 N16-69 |
| R59 | O **vendedor cancela, edita e exclui** o pedido, antes de faturar. O Hub chama o Omie: `CancelarPedidoVenda` (serviço `pedidovendafat`), `AlterarPedidoVenda` e `ExcluirPedido`. O hub guarda o **cancelamento por conta própria** (quem, quando, motivo), porque o `ExcluirPedido` e o `exclusionSync` apagariam o pedido do hub e perderiam a trilha; a pipeline confirma pelo `ListarEtapasPedido` (cancelamento, devolução, faturamento). Reusar o código de integração depois de excluir não é problema: apagar no Hub apaga no Omie | 📝 N16-84; ❓ testar a diferença entre cancelar e excluir (OQ-48) |
| R60 | A **requisição do PCP** e a **OC ainda não emitida** são **canceladas automaticamente**, e a tela mostra uma **tarja** dizendo que o pedido foi cancelado (com motivo e data). A **OC avisa** que o pedido foi cancelado e o **PCP é avisado** | 📝 N16-68, N16-70 |
| R61 | O que **já foi comprado vai ao Estoque, livre**, como lote com o custo da OC, e deixa de ser custo do pedido cancelado. A comissão estimada vira histórico | 📝 N16-68, N16-69 |
| R62 | **Pedido já faturado:** o cancelamento não desfaz compra nem produção. Ficam o **abatimento da comissão** (NF cancelada, devolvida ou recusada) e o **saldo ainda não faturado**, que segue as regras acima. No faturado em parte, vale **parte por parte** | 📝 N16-71 |

### 3.9 Devolução e abatimento da comissão (venda)

| # | Regra | Origem |
|---|---|---|
| R63 | **NF de venda cancelada, devolvida ou recusada** pelo cliente (manifestação "Operação não realizada" ou "Operação desconhecida"), total ou parcial, **abate a comissão na mesma proporção**, **desde a primeira versão**. Se ainda não foi paga, reduz o valor a pagar; se já foi paga, o desconto entra na próxima apuração do vendedor. Cada abatimento guarda a NF de origem e o motivo | 📝 N16-47 |
| R64 | A devolução **total** vem do Omie (marcada "devolvido") e abate 100% sozinha. A devolução **parcial** só chega marcada "devolvido parcialmente": **sem valor, item nem quantidade**. **O Fiscal ou a Controladoria informam** o item, a quantidade e o valor; o sistema guarda quem informou e quando, e então calcula o abatimento proporcional. 🟡 Enquanto não informam, abre-se uma **pendência** e a comissão da nota fica sinalizada | 📝 N16-74; 🟡 a pendência |
| R65 | A **recusa pelo cliente** ("Operação não realizada" ou "Operação desconhecida") vem da manifestação que a pipeline já lê das **3 unidades** (Aços, HRM e Uberaba) | 📝 correção do Nathan, 22/10 |
| R66 | A devolução de **compra** (NF de entrada devolvida ao fornecedor) e o seu efeito na linha de custo **não foram tratados** | ❓ OQ-42, adiado |

### 3.10 As datas do pedido (N16-88)

| # | Regra | Origem |
|---|---|---|
| R67 | **Previsão de faturamento inicial:** ao transformar a proposta em pedido, o vendedor **é obrigado a informar** a data (é a data em que o pedido deve estar sendo entregue ao cliente). **Não se calcula** mais pelo maior prazo dos itens. Sem a data, o pedido não é criado. Esta data **nunca se apaga** | 📝 N16-88 |
| R68 | **Entrega do fornecedor (Compras):** ao emitir a OC, Compras registra a previsão de entrega do fornecedor. Se for **depois** da previsão de faturamento vigente, Compras **conversa fisicamente com o vendedor**; combinado, registra a data e o sistema gera a **nova previsão de faturamento = previsão de entrega + 1** | 📝 N16-88 |
| R69 | **Nova data do CCP:** no Follow-up, quando o fornecedor não cumpre e passa uma nova data, o CCP registra **a nova previsão de entrega**; a **previsão de faturamento vira essa data + 1**. O follow-up já tem "Nova previsão de chegada" no registro de contato; falta ligar essa data à previsão de faturamento | 📝 N16-88; ✅ a tela existe |
| R70 | **Histórico completo:** cada data fica registrada (tipo, valor, quem, quando, motivo) e **a quantidade de atraso do fornecedor** é calculada (dias entre a data prometida e a nova). Nada é sobrescrito | 📝 N16-88 |
| R71 | **A previsão vigente** é a maior entre a inicial e a última data de cada item (a entrega mais recente registrada por Compras ou pelo CCP, + 1 dia útil); enquanto um item não tem OC, vale a inicial. Todas as datas ficam salvas, e o vendedor e o PCP veem o histórico | 📝 N16-88, N16-97, N16-104 |
| R72 | ✅ **Respondidas (N16-91):** o "+1" é **dia útil**; com várias OCs, **pedido inteiro = a última data**, **pedido que pode faturar em partes = uma previsão por item** (N16-97); a mudança do CCP **só avisa** o vendedor; a previsão vigente **não volta ao Omie**; as datas são **internas** e **não alteram os valores** da proposta nem do pedido | 📝 N16-91 |
| R75 | **Dia útil:** o cálculo pula sábado, domingo e feriado. Usa uma **biblioteca de calendário e feriados** por estado (`date-holidays`: Mogi e Arujá = SP, Uberaba = MG) mais uma **tabela de exceções por unidade** (feriado municipal, ponte, recesso), que a biblioteca não traz. **O marketing cadastra as exceções** (N16-99). Só contam os feriados do tipo público | 📝 N16-96 |
| R76 | **Pedido digitado no Omie:** o vendedor responde **a Qualidade e o faturamento em partes** na tela do pedido (portão `V2`/`V3`); a **previsão inicial vem do Omie** (`data_previsao`) e fica salva como `INICIAL`. Depois disso a mesma regra das datas vale (Compras e CCP registram a entrega, e a previsão vigente é derivada no Hub) | 📝 N16-91, N16-104, N16-106 |
| R77 | **Faturamento fora da regra:** pedido "somente inteiro" faturado em parte **sempre gera aviso** (Fiscal e vendedor), nunca bloqueio | 📝 N16-91 |
| R78 | **Cancelar e excluir (pedido):** **cancelar** mantém o pedido marcado como **cancelado** (com motivo, quem e quando) e continua a aparecer; **excluir** apaga de verdade. O vendedor pode editar, cancelar e excluir antes de faturar (N16-84). Excluir no Omie apaga o pedido do Omie; o Hub mantém só o registro do que for cancelado | 📝 N16-91 |
| R73 | **Faturamento em partes ou inteiro:** ao transformar em pedido, o vendedor **é obrigado a dizer** se o pedido **pode faturar em partes** ou **somente inteiro**. O dado fica no pedido (`faturamento_parcial`), vai para o Fiscal e para o PCP **pelo Hub** (nada disso vai ao Omie, N16-90) e muda como o **Em avanço** e a comissão (várias NFs por pedido) são lidos. Uma proposta continua a ser um pedido: a pergunta é sobre o **faturamento**, não sobre dividir a proposta (N16-02) | 📝 N16-89 |
| R74 | ✅ **Respondida (R77):** o sistema **só avisa**, sempre. O Omie não tem campo para isso e a pipeline só vê a NF depois de emitida | 📝 N16-91 |

### 3.11 Pedido sequencial: faturar em partes (N16-92)

| # | Regra | Origem |
|---|---|---|
| R79 | **Sequencial não é parcela de pagamento.** É a **quebra do pedido** para faturar em partes. O **original** (sequencial 0) guarda o valor cheio; cada sequencial (1, 2, 3…) leva uma parte, **escolhida por quem separa**. Original **zerado** = todo o valor distribuído | 📝 N16-92 |
| R80 | **O Hub cria, mostra e cancela sequenciais** quando o pedido **pode faturar em partes** (R73). Quem normalmente separa é o **Fiscal**; a quebra é **por item e por quantidade**. Pedido "somente inteiro" não tem sequencial (R77 só avisa se for faturado em parte) | 📝 N16-92, N16-93 |
| R81 | **Cancelar um sequencial devolve o valor ao original.** O **número cancelado não se reusa**: o próximo sequencial é o seguinte (3 e 4 depois de cancelar 1 e 2). **Excluir** apaga de verdade e só vale para sequencial **ainda não faturado** (R78) | 📝 N16-92 |
| R82 | **Comissão:** sequencial cancelado **antes de faturar** não tem efeito. **Depois de faturado**, cancelar quer dizer **nota cancelada** e vale o abatimento (R63) | 📝 N16-92, N16-47 |
| R84 | **Sequencial (faturamento) ≠ divisão da triagem do PCP** (fabricação, revenda…): conceitos separados, com nomes diferentes nas telas. **O Hub não guarda a divisão da triagem do PCP e ela não tem relação com o sequencial** (o Nathan confirmou em 26/10); está fora deste projeto | 📝 N16-93 |
| R83 | ✅ **Respondida (N16-94):** o sequencial **não é outro pedido**, é um agrupamento para o Fiscal faturar em partes (**um pedido, várias notas**). Resta saber **só** como criá-lo pela API do Omie, a testar com a tela (N16-82) | 📝 N16-94 |
| R85 | **A OC se liga ao pedido e aos itens, nunca ao sequencial.** Comprar para o PV 27859 vincula a OC ao pedido e aos itens escolhidos; quebrar o pedido depois (em 2 ou mais sequenciais) **não muda o vínculo nem o custo** dos itens. O custo real continua sendo do **item do pedido**: empresa + número do pedido + produto (`custos_eventos`), no pedido do Hub e no digitado no Omie | 📝 N16-94, N16-102 |
| R86 | **Previsão de faturamento (N16-97):** (a) a de **partida** é a que o **vendedor** colocou; item sem OC vale essa; (b) **"tudo junto"**: a previsão do pedido é a **última** data de entrega entre **todos os itens** + 1 dia útil; (c) **"em partes"**: **a data por item** (entrega da OC do item + 1 dia útil). O sequencial **mostra** a maior data entre os itens que leva, mas o dado é **do item** | 📝 N16-97 |
| R87 | **Código do item (N16-100, dados do banco):** o sequencial **não é um pedido novo**, mas cada sequencial recebe **códigos de linha de item novos**; o que se repete é o **produto**. O original zerado fica com linhas de **quantidade 0**. A ligação item × sequencial vive numa **terceira tabela** (SQL-016, seção 2.7), que liga a linha do sequencial à do original; o Hub guarda a **quantidade original** | 📝 N16-99; ✅ N16-100 |

## 4. Estados

Enum de hoje (`StatusProposta`): `ABERTA`, `PARCIAL`, `FECHADA`, `PERDIDA` (`api-comercial/prisma/models/enums.prisma:69-76`). Proposta de enum novo:

| De | Para | Ação | Quem | Condição | Erro se falhar |
|---|---|---|---|---|---|
| — | `ABERTA` | criar | vendedor | cliente e itens válidos | 422 |
| `ABERTA` | `ABERTA` | revisar (`PUT`, `If-Match`) | responsável ou quem edita terceiros | conteúdo mudou ⇒ `revisao + 1` | 409 `TRANSICAO_INVALIDA` se não está `ABERTA`; 409 de versão |
| `ABERTA` | `APROVADA` | aprovar | vendedor | **completa**; revisão informada é a atual | 422 `PROPOSTA_INCOMPLETA`; 409 `REVISAO_DESATUALIZADA` |
| `ABERTA` | `CANCELADA` | cancelar | responsável | motivo (3 a 500 caracteres) | 422 `MOTIVO_OBRIGATORIO` |
| `APROVADA` | `TRANSFORMADA` | transformar | vendedor | marcação da Qualidade presente; sem produto pendente | 422 `QUALIDADE_OBRIGATORIA`; 422 `PRODUTO_PENDENTE`; 409 `PEDIDO_JA_CRIADO` |
| `APROVADA` | `CANCELADA` | cancelar | responsável | ainda sem pedido | 409 se já `TRANSFORMADA` |
| `TRANSFORMADA` | — | nenhuma | — | travada | 409 `PROPOSTA_TRAVADA` |
| `CANCELADA` | — | nenhuma (duplicar gera outra) | — | — | 409 `PROPOSTA_TRAVADA` |

`PARCIAL` e as ações `fechar` e `reabrir` deixam de existir (N16-02, N16-03). O mapa do enum antigo para o novo: `ABERTA` → `ABERTA`; `FECHADA` → `APROVADA`; `PERDIDA` → `CANCELADA`; `PARCIAL` → sem equivalente (não há dado de produção a migrar: o `api-comercial` é de teste e não há migração do ERP antigo, N16-13).

**Pedido de aprovação do vendedor (`C8`) 🟡:**

| De | Para | Ação | Quem | Condição |
|---|---|---|---|---|
| — | `PENDENTE` | gerado quando a compra por produto passa do valor da proposta | sistema | Y > X, sem tolerância |
| `PENDENTE` | `APROVADO` | aprovar | vendedor | — |
| `PENDENTE` | `REPROVADO` | reprovar | vendedor | entra na lista de Compras |
| `REPROVADO` | `RESOLVIDO` | registrar a solução (novo valor, novo fornecedor, mantido ou cancelado) com o motivo | Compras | notifica o vendedor |

Pedido de venda do hub: `status_sincronizacao_omie` com `pendente`, `sincronizado`, `erro` (🟡) e o cancelamento guardado no hub (`cancelado_em`, `cancelado_por`, `motivo_cancelamento`). Detalhe e diagramas: [[Estados-e-Status]] e [[Estados]] (diagramas 13 a 16, após a promoção).

## 5. Validações

| # | Validação | Quando | Código 🟡 |
|---|---|---|---|
| V1 | Completa: nenhum item sem custo e sem fornecedor (regra R9) | aprovar | `PROPOSTA_INCOMPLETA`, lista os itens |
| V2 | A revisão que o vendedor diz estar aprovando é a revisão atual | aprovar | `REVISAO_DESATUALIZADA` |
| V3 | `acompanhamento_qualidade` é `true` ou `false` (não nulo) | transformar | `QUALIDADE_OBRIGATORIA` |
| V4 | Status `APROVADA` e ainda sem pedido | transformar | `PROPOSTA_NAO_APROVADA`, `PEDIDO_JA_CRIADO` |
| V5 | Sem produto pendente (`PEND-xxxx`) | transformar | `PRODUTO_PENDENTE` |
| V6 | Cliente com cadastro no Omie da conta da empresa emissora | transformar | `CLIENTE_SEM_CADASTRO_OMIE` |
| V7 | Idempotência: o mesmo clique duas vezes cria um pedido só (`Idempotency-Key` por usuário, 24 h, como o módulo já faz em criar e duplicar) | transformar | devolve a primeira resposta |
| V8 | Concorrência: `If-Match` com a versão da proposta | aprovar, cancelar, transformar | 412 ou 409 de versão |
| V9 | Aprovada, qualquer `PUT` é recusado | revisar | `PROPOSTA_TRAVADA` |
| V10 | O pedido não muda o preço, o desconto nem os itens da proposta aprovada: o pedido é gerado do snapshot da revisão aprovada | transformar | — |
| V11 | O **motivo** do pedido de aprovação é obrigatório (Compras) | gerar o aviso `C8` | `MOTIVO_OBRIGATORIO` |
| V12 | Só o vendedor dono do item aprova ou reprova o pedido de aprovação dele | `C8` | 403 |
| V13 | A solução só se registra num pedido de aprovação `REPROVADO` e com motivo | `C8` | `TRANSICAO_INVALIDA`, `MOTIVO_OBRIGATORIO` |
| V14 | Cancelar o pedido: motivo obrigatório; o que já foi faturado não se cancela por esta rota | cancelar pedido | `MOTIVO_OBRIGATORIO`, `PEDIDO_FATURADO` |
| V15 | Devolução parcial: item, quantidade e valor informados não passam do faturado da nota | informar devolução | 422 `DEVOLUCAO_ACIMA_DO_FATURADO` |

O padrão de erro é o do módulo (`{ error, code }`, `regra()` e `AppError`, `api-comercial/src/lib/http/erros.ts`), até a API do hub definir o envelope único (LOG-52 T9).

## 6. Matriz de permissões por perfil 🟡

Proposta de partida; **OQ-21** fecha. Hoje as capacidades derivam de **telas do hub**: `propostas` (ver, editar, deletar), `propostas-valores` (ver R$), `custo-item` (ver custo, margem), `painel-comprador` (comprador), `propostas-delegacao`, `relatorio-gerencial`, `clientes`, `simulador` (`api-comercial/src/domain/permissoes/capacidades.ts:47-56`). Telas novas 🟡: aprovar proposta, transformar em pedido, Meus Pedidos com pendências, lista de reprovados de Compras, comissão do vendedor, decisão da Controladoria, visão geral. O perfil **orçamentista** deve existir (N16-59). `Admin (Dev)` não é ator.

| Ação | Vendedor | Auxiliar do titular | Gerente de equipe | Gerência (João Vitor, Sérgio Vital) | Orçamento | Comprador | Gerente de Compras | PCP | Fiscal | Controladoria |
|---|---|---|---|---|---|---|---|---|---|---|
| Criar e revisar proposta | sim (as dele) | sim (dos titulares) | não | não | não | não | não | não | não | não |
| Ver proposta e preço de venda | as dele | dos titulares | equipe | não (física) | não | só o que a requisição liga | idem | não | não | não |
| Ver custo e margem da proposta | os que ele pôs | idem | equipe | — | custo que preenche | custo e valor correto | idem | não | não | sim |
| Ver comissão estimada | só a que ele pôs | idem | 🟡 | — | não | não | não | não | não | sim |
| Marcar "aprovada" | sim | sim 🟡 | não | no próximo ciclo | não | não | não | não | não | não |
| Cancelar, editar ou excluir pedido (antes de faturar) | sim (as dele) | sim | 🟡 | não | não | não | não | recebe o aviso | não | não |
| Transformar em pedido | sim | sim | não | não | não | não | não | não | não | não |
| Pedir custo (`B3`) | sim | sim | não | não | não | não | não | não | não | não |
| Responder pedido de custo (`B4`) | não | não | não | não | sim | sim (`painel-comprador`) | sim | não | não | não |
| Consultar a página do produto (`B2`) | sim, só leitura | sim | sim | não | sim | sim | sim | não | não | não |
| Editar ofertas e matriz | não | não | não | não | sim | sim | sim | não | não | não |
| `C6`, `C7` na OC (conferir e editar impostos) | não | não | não | não | não | sim | sim | não | não | não |
| **Aprovar ou reprovar compra acima do valor (`C8`)** | **sim (os produtos dele)** | 🟡 | não | não | não | não | não | não | não | não |
| **Lista dos casos reprovados e registrar a solução** | não | não | não | não | não | sim | sim | não | não | vê |
| Ver o custo real do pedido | não | não | não | não | não | sim | sim | não | não | sim |
| Ver a tela da proposta no formato do Simulador com o custo cotado (a) | as dele | dos titulares | equipe | não | só o pedido de custo | em leitura (`C6`) | em leitura | não | não | em leitura, com o real (c) |
| Ver o drill-down por evento de custo e as condições de cada evento | não | não | 🟡 | não | não | só o das OCs dele | sim | não | não | sim |
| Ver a comissão real e a justificativa | só depois da decisão | idem | 🟡 | decide | não | não | não | não | não | sim |
| Decidir a comissão (`K4`) | não | não | não | **sim** | não | não | não | não | não | sim (e a Coordenação) |
| **Informar a devolução parcial (`K6`)** | não | não | não | não | não | não | não | não | **sim** | **sim** |
| Responder Qualidade e faturamento em partes do pedido do Omie (`V2`, `V3`) | sim | sim | só leitura | não | não | não | não | não | não | não |

Escopo: `proprios`, `vinculados` e `todos` do perfil (como em LOG-40); o significado de `vinculados` para proposta e cliente está em PS-032 de [[Pontas-Soltas]].

## 7. Casos de borda

| # | Caso | O que o sistema faz 🟡 |
|---|---|---|
| 1 | **Proposta cancelada** | Não vira pedido. A comissão estimada vira `HISTORICO` e o vendedor consulta. Não reabre; duplica (R15, R16). Se já tinha pedido, não cancela (409) |
| 2 | **Proposta incompleta** | Salva e revisa normalmente. Não aprova (`PROPOSTA_INCOMPLETA`). A lista de propostas mostra o selo "incompleta" |
| 3 | **Revisão antes da aprovação** | Cada mudança de conteúdo comercial gera `R+1` com snapshot. A Gerência aprova fisicamente **uma** revisão; o vendedor marca a mesma revisão no sistema. Se o vendedor editar depois da aprovação física e antes de marcar, o documento físico fica velho: a tela de aprovar mostra o número da revisão e os totais |
| 4 | **Revisão depois de aprovada** | Não existe. Para mudar, cancelar e duplicar (nova proposta, nova aprovação física) |
| 5 | **Cliente sem cadastro no Omie** (prospect) | A proposta vive sem cadastro; transformar em pedido exige o cadastro na conta da empresa emissora (`CLIENTE_SEM_CADASTRO_OMIE`) |
| 6 | **Custo real acima do cotado** | Compras usa o valor correto (`C7`); a proposta não muda; **o vendedor é avisado e aprova ou reprova** (R50 a R55); se aprova, a margem e a comissão caem; a Controladoria vê a diferença |
| 7 | **Custo real abaixo do cotado** | O aviso é só informativo (R57); a comissão cotada vale (a menor das duas) |
| 8 | **Pedido digitado no Omie** | Mesmo fluxo e mesma tela (R38, R39): parte de vendas travada, o vendedor preenche a de compras e responde `V2`/`V3`; a nota espera a simulação |
| 9 | **Omie recusa o pedido** | `erro` com motivo; vendedor vê e usa "Tentar novamente"; proposta segue `APROVADA` (R21) |
| 10 | **Dois cliques em "Transformar"** | Uma única fila e um único pedido (`Idempotency-Key`, vínculo único proposta–pedido) |
| 11 | **Produto pendente** | Não transforma (R25) |
| 12 | **Pedido alterado ou cancelado direto no Omie depois** | A pipeline traz a mudança e o sistema avisa; a proposta não muda (R14); a comissão estimada e o custo seguem o que o pedido do Omie disser |
| 13 | **OC cancelada depois de aprovada** | A linha de custo real dela é estornada; o item volta a parcial (R33a) |
| 14 | **Item parcial do MES (5.01, 5.02…)** | Cada parcial acumula suas linhas; o custo do item soma as parciais (N16-09) |
| 15 | **Empresa emissora × unidade do Omie** | Cada empresa emissora tem a **sua conta Omie**: AV (Aços Vital, Mogi), HRM (Arujá) e AU (Aços Uberaba), três contas diferentes no mesmo sistema (N16-79; `empresa_emissora.id_unidade_omie`); o pedido e a requisição ficam sempre na mesma unidade (N14-31) |
| 16 | **Proposta em moeda estrangeira** | PTAX do dia da aprovação (R6); a OC usa a PTAX da OC |
| 17 | **Delegação** | O responsável pode ser outro usuário (`propostas-delegacao`); quem transforma é o responsável ou quem edita terceiros; `liberado_por` registra quem clicou |
| 18 | **Vendedor sai da empresa com proposta aprovada sem pedido** | O responsável pode ser trocado por quem tem delegação; a revisão aprovada segue igual 🟡 |
| 19 | **Data de corte da liberação** | O pedido da proposta não depende dela: nasce liberado ([[LOG-58-Liberacao-do-Pedido-Origem-Proposta]]) |
| 20 | **Gerência não aprovou** | O sistema não sabe; a aprovação é física e fica por conta do vendedor e da Gerência neste ciclo (N16-12). O risco de marcar "aprovada" sem aprovação física é aceito e fica na auditoria (quem, quando) |
| 21 | **OC com condições diferentes por evento** | O item de 50 unidades com 50 OCs soma 50 eventos, cada um com o seu fornecedor, a sua condição de pagamento e o seu imposto (N16-20); o drill-down da Controladoria lista os 50 |
| 22 | **Vendedor não responde ao aviso `C8`** | Sem tempo limite: fica `PENDENTE` na lista dele e a compra espera; o tempo parado é cronometrado (N16-63) 🟡 |
| 23 | **Uma OC com itens de dois vendedores** | Cada vendedor recebe só o aviso dos produtos dele (R51); a OC espera a decisão dos dois |
| 24 | **Gerência também reprova** | Compras procura um valor melhor ou, dependendo do caso, a venda é cancelada; o vendedor só vê a notificação (R54, R55) |
| 25 | **Pedido cancelado com compra já feita** | O comprado vai ao Estoque, livre, com o custo da OC (R61) |
| 26 | **Pedido faturado em parte e cancelado** | Parte por parte: o faturado fica; o saldo segue as regras de cancelamento (R62) |
| 27 | **`ExcluirPedido` no Omie** | Apagaria o pedido do hub no `exclusionSync`; por isso o hub guarda o cancelamento por conta própria (R59) |
| 28 | **Devolução parcial sem quantidade** | Pendência para o Fiscal ou a Controladoria informar; a comissão da nota fica sinalizada (R64) |

## 8. Rotas (propostas 🟡)

O prefixo `/comercial` do desenho do LOG-52 **sai** (N16-116): as tabelas ficam em `core_vendas_faturamento` e, como no resto desse schema, a rota tende a usar só o nome do recurso. Nomes finais são do Robert e do Gustavo (N16-117).

| Método e rota | Efeito | Permissão | Nó |
|---|---|---|---|
| `POST /comercial/propostas`, `PUT /comercial/propostas/:id` | criar, revisar (só `ABERTA`) | `propostas` criar, editar | `V0.1` |
| `POST /comercial/propostas/:id/aprovar` `{ revisao }` | `ABERTA` → `APROVADA` | tela de aprovar 🟡 | `V0.4`, `V0.5` |
| `POST /comercial/propostas/:id/cancelar` `{ motivo, motivo_texto }` | → `CANCELADA` | `propostas` editar | `V0C` |
| `POST /comercial/propostas/:id/pedido_venda` `{ acompanhamento_qualidade }` | grava o pedido na fila; proposta → `TRANSFORMADA`; idempotente | tela de transformar 🟡 | `V0.6`, `V0.7` |
| `GET /comercial/pedidos_venda/fila-omie` | a pipeline lê os pendentes | chave de serviço | `V0.7` |
| `PATCH /comercial/pedidos_venda/:id/sincronizacao` `{ numero_omie, codigo_pedido_integracao, status, erro }` | a pipeline devolve o resultado | chave de serviço | `V0.7`, `V1` |
| `POST /comercial/pedidos_venda/:id/reenviar` | volta `erro` para `pendente` | `propostas` editar | `V0.7` |
| `POST /comercial/pedidos_venda/:id/cancelar` `{ motivo }` | registra o cancelamento no hub; cancela a requisição e a OC não emitida; avisa a OC e o PCP; manda o comprado ao Estoque | `propostas` editar 🟡 | cancelamento |
| `GET /comercial/propostas/:id/compras` | a parte de compras da proposta ligada ao pedido (para `C6`) | `compras` visualizar | `C6` |
| `GET /comercial/divergencias_compra` (do vendedor), `POST /:id/aprovar`, `/:id/reprovar` | aviso e decisão do vendedor, por produto | tela Meus Pedidos 🟡 | `C8` |
| `GET /comercial/divergencias_compra?estado=REPROVADO`, `POST /:id/resolver` `{ solucao, motivo }` | lista de Compras e registro da solução | `compras` editar | `C8` |
| `POST /comercial/comissoes/nf/:id/devolucao` `{ item, quantidade, valor }` | informa a devolução parcial | Fiscal, Controladoria 🟡 | `K6` |

Saem: `fechar`, `reabrir`, `perder`, `GET/PUT /propostas/:id/pedido_omie` e `.../pedido_omie/xlsx` (`api-comercial/src/modules/propostas/propostas.routes.ts:93-111`, `:146-164`).

## 9. Fora do escopo

- Aprovação de desconto e margem no sistema (próximo ciclo, N16-12 e N16-75: tudo fisicamente, sem alçada no sistema; OQ-04 fechada).
- Aprovação da Gerência como botão no sistema na compra acima do valor (é conversa física, N16-66).
- Migração de propostas do ERP antigo (N16-13).
- Alterar o módulo Comissões atual.
- Matriz de preços (raia do Orçamento, [[12-Orcamento-Base-de-Preco]]).
- Devolução de **compra** (NF de entrada devolvida ao fornecedor): adiada (OQ-42).
- Cancelar pedido **já faturado** por esta rota: fica fora; vale o abatimento da comissão e o saldo (R62).

## 10. Perguntas em aberto

OQ-16 (campos obrigatórios do `IncluirPedido`, `numero_pedido` próprio e pedido bloqueado: **testes no Omie**), OQ-21 (perfis), OQ-32 (sobras de chapa), OQ-34 e OQ-39 (vínculo da NF de entrada e unidade), OQ-36 (Fiscal: produto novo), OQ-38 (estoque confiável), OQ-41 a OQ-45 (apuração, descontos do vendedor, CBS, Projeto e recompra, validações provisórias), OQ-48 (cancelamento no Omie). Respondidas e fora desta lista: OQ-02, 06, 09 a 15, 17 a 20, 22, 24 a 27, 29 a 31, 33, 35, 37, 40, 46, 47. Texto em [[Perguntas-Proposta-Pedido-Comissao]].

## 11. Testes de aceite

1. Criar proposta: o número é só dígitos, vem de uma sequência por unidade e tipo e o prefixo só aparece na tela e no PDF.
2. Revisar duas vezes na `ABERTA`: a revisão sobe a cada mudança de conteúdo e as versões guardam o snapshot.
3. Proposta com um item sem custo e sem fornecedor: `aprovar` responde 422 `PROPOSTA_INCOMPLETA` e lista o item.
4. Aprovar com a revisão desatualizada: 409 `REVISAO_DESATUALIZADA`.
5. Aprovar uma proposta completa: `APROVADA`, com quem, quando e a revisão; qualquer `PUT` depois responde `PROPOSTA_TRAVADA`.
6. Transformar sem a marcação da Qualidade: `QUALIDADE_OBRIGATORIA`, nada na fila.
7. Transformar com a marcação: um registro na fila, proposta `TRANSFORMADA`, e o segundo clique devolve a mesma resposta.
8. A pipeline envia e devolve o número do Omie: o pedido do hub vai a `sincronizado`, a liberação é gravada na resposta do `IncluirPedido`, aparece em `status_liberacao = liberado` com histórico `liberado` e a Triagem do PCP o lista.
9. O Omie recusa: `erro` com o motivo; "Tentar novamente" volta a `pendente`; a proposta continua `APROVADA` e a marcação não se perde.
10. Cancelar uma `APROVADA` sem pedido: `CANCELADA`, comissão estimada em `HISTORICO`, consultável pelo vendedor; transformar depois responde 409; não reabre.
11. Cancelar uma proposta `TRANSFORMADA`: 409.
12. Produto pendente na proposta: `PRODUTO_PENDENTE` ao transformar.
13. Compras usa um valor **maior** na OC de um pedido com proposta: a proposta e o preço fechado ficam idênticos; **nasce um pedido de aprovação `PENDENTE` por produto**, que aparece em Meus Pedidos do vendedor dono do item, com PV, OC, margem atual, margem considerada, motivo, diferença e fornecedor.
14. O vendedor aprova: o pedido de aprovação vai a `APROVADO`, a compra segue; a margem e a comissão recalculam.
15. O vendedor reprova: vai a `REPROVADO` e aparece na lista de Compras; Compras registra a solução com motivo: `RESOLVIDO`, e o vendedor recebe a notificação.
16. Compras usa um valor **menor**: o aviso é só informativo e não pede aprovação.
17. Uma OC com dois produtos de dois vendedores: cada um vê só o seu.
18. O vendedor não vê a comissão real antes da decisão da Controladoria; vê a estimada que ele pôs; depois da decisão, vê a real **e a justificativa**.
19. Pedido digitado no Omie: aparece em Meus Pedidos com a parte de vendas travada; o vendedor responde Qualidade e faturamento em partes (libera) e preenche a parte de compras; a comissão estimada aparece depois disso.
20. Um perfil sem a tela de aprovar não aprova; um sem `propostas-valores` não vê valores; um vendedor não aprova o item de outro (403).
21. A tela da proposta mostra os blocos Pedido, Condições comerciais, Itens (Compra, Venda, Resultado) e totais; com os mesmos dados de entrada de um caso do Simulador atual, a margem, a letra e a comissão por item **batem** com as do Simulador (teste de ouro do motor).
22. Compras abre a visão de leitura da proposta na emissão da OC, vê o cotado ao lado do valor da OC e **não consegue alterar** a proposta; os campos de imposto da OC vêm preenchidos pela proposta e são editáveis.
23. A Controladoria abre a mesma tela com o estimado e o real lado a lado e o drill-down por evento; o vendedor, pelas mesmas rotas, **não recebe** as colunas reais.
24. Item de 50 unidades com 3 OCs de fornecedor, condição de pagamento e frete diferentes: o custo líquido do item é a soma dos 3 eventos; no recebimento, o valor da NF de entrada substitui o da OC.
25. Evento sem imposto real: a linha aparece como "sem imposto" para a Controladoria e o cálculo não falha.
26. Cancelar um pedido sem nada comprado: a requisição do PCP e a OC não emitida são canceladas, com tarja; a OC e o PCP são avisados.
27. Cancelar um pedido com parte já comprada: o comprado entra no Estoque como lote livre, com o custo da OC, e não conta como custo do pedido cancelado.
28. Cancelar um pedido faturado em parte: o faturado e a comissão da nota ficam; só o saldo segue as regras.
29. Devolução total no Omie: abatimento de 100% da comissão da nota, sozinho. Devolução parcial: pendência; o Fiscal informa item, quantidade e valor; o abatimento proporcional é calculado.
30. Ninguém decide sobre a própria comissão; a Gerência e a Coordenação decidem com as mesmas permissões; toda ação guarda quem, quando, valor anterior e novo e justificativa.

## Ver também

[[11-Proposta-e-Pedido-de-Venda]] · [[12-Orcamento-Base-de-Preco]] · [[13-Custo-Real-e-Comissao-no-Fluxo]] · [[00-Fluxo-Mestre-0b]] · [[Estudo-Omie-API]] · [[LOG-57-Menu-Vendas-Orcamento-Compras]] · [[LOG-58-Liberacao-do-Pedido-Origem-Proposta]] · [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] · [[LOG-26-Vendas-Liberacao-Pedido]] · [[LOG-23-Compras-Pipeline-Consolidado]] · [[04-Circuito-de-Compra]]
