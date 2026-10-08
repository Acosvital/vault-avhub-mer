---
tags: [erp-acos-vital, status, indice]
criado: 2026-09-21
atualizado: 2026-10-08
---

# Onde estamos

> Status: decidido | no código | em produção (verificado em 07/10 pelo dump)

> **(atualizado em 07/10)** **Decisões de 07/10: ver [[Registro-de-Decisoes-2026-10-07]].** Ambiente de homologação no ar (M2 cumprido), envio de OC fixo no código, schema `public` do Estoque, Pablo no Comercial & Suprimentos e **Robert com o MES inteiro** (incluindo G1, baixa no despacho do Estoque, D11, I1/J2/J5; a capacidade dele precisa ser recalculada), plano de **3 meses (até 18/12)**. Onde este texto antigo conflitar com o Registro, vale o Registro.

> **Atualizado em 21/09/2026 (segunda-feira), um dia antes do início da execução** (e revisado a cada adendo abaixo; o último é de 07/10/2026). Esta é a nota que responde "em que ponto o projeto está". Se ela estiver desatualizada, o projeto está desatualizado: quem muda o estado de uma tarefa atualiza a linha aqui no mesmo dia. Como manter: seção 7.
>
> **Adendo de 08/10/2026 — reconferência contra o código dos cinco repositórios (só leitura de código; produção e banco não conferidos).** Heads: `api-acos-vital` `main` `9b9b578` (#282) e `develop` `0557871`; av-hub `main` `cfed113` (inalterada) e `develop` `bd1ae48`; `api-pcp` `develop` `ca3346b` e `omie-elt-pipeline` `master` `d2886bf` (**ambos sem mudança**); `app-pcp` `develop` `2ea3183`. O que mudou:
> - **`api-acos-vital`:** `PERMISSOES_ROTA_MODO` agora é **`exigir` por padrão** no código (`0557871`): sem a variável no `.env` o modo é `exigir`, valor inválido também vira `exigir`, e o servidor **só sobe com `USUARIO_TOKEN_SEGREDO` (mínimo 32 caracteres)**. **Divergência com a decisão 8 de 07/10 ("fixo, sem `.env`"):** a variável ainda é lida, então `observar`/`desligado` continuam possíveis. O tipo de contrato do funcionário passou a aceitar também Estágio, Temporário e Terceirizado (`2bb9ad7`, migration `fix02`). `main` avançou de `a6ab058` para `9b9b578` (#281/#282): `main` = `develop` até `2bb9ad7`; o `0557871` entrou pelo #282.
> - **av-hub `develop`:** de `996e320` para `bd1ae48` (111 arquivos, +7,5 mil linhas, 07/10). Entraram em `develop` as 9 branches que o vault listava como abertas (câmbio, imprimir em lote, itens por planilha, categorias/certificados, painel do comprador, tabela-telha, histórico de compras, pesquisa de materiais, e2e Playwright) e mais: PDF interno de aprovação com margem real, envio de proposta e de cotação por e-mail (SMTP desligado até configurar; migration `evento_email_enviado`), fila de produtos pendentes com "Ligar ao Omie", exportar fornecedores, histórico de importações do mapa de cotação, tela de pedido de cotação, CI do Playwright. Detalhe em [[AV-Hub-Comercial-Suprimentos]]. **`main` do av-hub continua sem o `api-comercial`.**
> - **`app-pcp` `develop`:** `2ea3183` (#35) refez o layout da página de lotes do Estoque (`estoque-operacao/lotes/[id]`); sem efeito nos contratos.
> - **Confirmado sem mudança:** contrato 34 (PUT `/compras/requisicoes/origem/{id_origem}`) e 35 (eventos) no `api-pcp`; `/itens/status` existe no MES e o av-hub não a consome; `/ordens-compra/referencia` não existe; `UsuariosController` e `SetoresController` seguem sem guard na maioria das rotas (só `PATCH usuarios/:id/senha` e `GET setores/:id/painel` têm `JwtAuthGuard`); a `main` do `api-pcp` e do `app-pcp` segue parada em 28/08 (`be076b2`/`be847ac`).
>
> **Adendo de 07/10/2026 — pente fino contra o código dos cinco repositórios.** Os sistemas foram atualizados e o vault foi conferido contra o código (`api-acos-vital` `main`=`develop` `a6ab058`; av-hub `develop` `996e320`; `api-pcp` `develop` `ca3346b`; `app-pcp` `develop` `a802a3e`; `omie-elt-pipeline` `master` `d2886bf`). **Só leitura de código: produção, banco e deploy não foram conferidos.** O que mudou no retrato:
> - **O MES deixou de ser "nada construído".** O Estoque tem código na `develop`: D1 (schema), D2 (módulo, sem e2e), D3 (metade), D5, D6, D7, D8, D9, D10, D11 (parcial) e a **etapa 1 da transferência entre filiais (saldo por filial)**, mais a requisição de compra (C7), a Qualidade de entrada e o **Recebimento com conferência, recontagem e decisão do PCP** (PR #50/#34, hoje 08:29). Detalhe em [[App-PCP-Recebimento-Conferencia]]. **Atenção: a `main` do `api-pcp` e do `app-pcp` parou em 28/08; tudo isso está só na `develop`.**
> - **Integração av-hub ↔ MES:** o MES **já chama** o `PUT /compras/requisicoes/origem/{id_origem}` (contrato 34, `e7ce2c9`, 02/10) e **já lê e reage** aos eventos da requisição (contrato 35, `41bf4a6`, 05/10). A rota `/itens/status` (005) existe no MES, mas o av-hub não tem quem a consuma; a rota `/ordens-compra/referencia` (004) **não existe nos dois lados**. A chave própria do MES (do 34) **só abre o PUT**: as leituras (`/pedidos_liberados`, `/compras/requisicoes/eventos`...) exigem chave de outro tipo — a **L6 segue aberta**. Ver [[Chaves-de-Integracao-AvHub-MES-Pipeline]].
> - **Nasceu o módulo AV Comercial & Suprimentos** no av-hub, com serviço próprio `api-comercial` (Express 5 + Prisma, schema `core_comercial`) — **o vault não tinha nada sobre ele**. Em `main` só a fatia de Propostas/Painel do Comprador/Dashboard; o resto está na `develop` (mergeado em 06/10) e em 9 branches abertas. Ver [[AV-Hub-Comercial-Suprimentos]].
> - **API:** foi reestruturada em `src/schemas/**`, ganhou `/docs` (Scalar) e autenticação em camadas; o contrato **07** (orçamento e coordenadores no banco), que o vault dava como "desconsiderado/não entregue", **existe no código** (`90bdb33`). **(atualizado em 07/10)** O orçamento foi desenvolvido **por fora**, no módulo Comercial & Suprimentos; os contratos 07 e 38 precisam ser reescritos ([[Registro-de-Decisoes-2026-10-07]], item 39). Ver [[AV-Hub-API-Estado-Atual]] e [[Indice-Contratos]].
> - **Pipeline:** Compras inteiro está no código (6 recursos, PTAX, inativação de catálogos e o **envio da OC ao Omie**, única escrita no Omie), com as chaves `SYNC_*` removidas pelo contrato 38. Ver [[Omie-ELT-Pipeline]].
> - **Vendedores (contrato 39):** API na `main` (`a6ab058`, #280) e a tela do av-hub (#155) mergeada na `develop` hoje às 10:01 — só `develop`.
> - **Achado de segurança no MES (a confirmar com o Robert):** no `api-pcp`, `UsuariosController` e `SetoresController` não têm guard e vários controllers só exigem JWT; hoje a barreira é o BFF. Ver [[App-PCP-Visao-Geral]].
>
> **Adendo do mesmo dia (21/09, à tarde):** auditoria de um dump de produção fresco (`dump-avhub_prd_db-202609210741.sql`) contra o código real de `api-acos-vital` e `api-pcp` achou que **5 contratos SQL e 1 contrato de API que este vault marcava como "proposta" já estão aplicados em produção**, e um risco novo (schema `negocio`/`core_compras` — ver abaixo). Detalhe completo em [[Auditoria-Dump-Producao-2026-09-21]]. As seções 3, 5 e 6 abaixo já refletem isso.

> **Adendo de 24/09/2026 — encaixe do Estoque e da Revenda no MES.** O Robert fechou como o Estoque e a Revenda entram no fluxo Carteira → Ordem de Produção → execução, e o Nathan acrescentou a regra do item comprado (aprovado na Qualidade, vai para o Estoque, não para a Expedição). Tudo em [[Encaixe-Estoque-Revenda-no-PCP]]. Efeito no quadro: **C6** muda de conteúdo (tipos de Fábrica/Setor, fábrica Revenda, Estoque como etapa 1), **C7** passa a ser disparada pelo setor Compras, **C8** encolhe para a fila "Novo norte", **D6/D8/D9** ganham o modelo de reserva e a entrada do item comprado. Também registrado: a **Carteira de Pedidos** e a tela **Ordem de Produção** já rodam no `app-pcp` `develop` (23-24/09) — o critério de pronto da **C4** ("itens do pedido de venda disponíveis no MES por número do pedido") parece atendido, falta o Robert confirmar — e as telas de Estoque e Qualidade do Pablo (D5, D8, D10) estão em `develop` sobre mock. 7 perguntas novas (EN-01 a EN-07) em [[Perguntas-em-Aberto-Consolidadas]] — **todas respondidas em 25/09/2026**, ver [[Encaixe-Estoque-Revenda-no-PCP]] seção 5.
>
> **Adendo de 28/09/2026 — C6 e D9 concluídas; novo desenho de Compras em duas rodadas no mesmo dia; verificado direto no código.** Dois PDFs do Robert no mesmo dia: de manhã, **C6 e D9 (implementadas e testadas)**, Material deixa de ser projeção do av-hub (D3 revisada), a parte atendida pelo estoque passa a concluir na **Expedição** (não no Estoque), e um novo setor "Requisições de compras" (ainda não codificado); à tarde, uma segunda proposta **revisa a primeira antes dela virar código** — setor Estoque único, circuito de compra vira desvio fixo do sistema (fora do roteiro do PCP), e a baixa do saldo muda de novo, agora pro despacho do Estoque. **Clonei `api-pcp` e `app-pcp` (branch `develop`) e confirmei**: os itens da manhã batem exatamente com o schema Prisma e os componentes de frontend reais (inclusive comentários no código citando C6/D9/EN-02/EN-03 literalmente); a proposta da tarde não tem nenhum código ainda. Também confirmado em `api-acos-vital`: o bug de `alterado_desde` (filtro nunca aplicado, código depois do `return`) é real, em `produtos.js` e `parceiros.js`. **EN-05 reabriu** — resposta de 25/09 não chegou ao Robert.
>
> **Adendo de 29/09/2026 — a proposta da tarde de 28/09 vira decisão.** O Nathan respondeu as 9 perguntas que a atualização de 28/09 tinha deixado em aberto: EN-05 confirmado de vez (sem conflito), e a arquitetura da tarde de 28/09 (Estoque único, circuito de compra fixo fora do roteiro, baixa no despacho do Estoque, Reserva reduzida a "separar sem despachar", inspeção de entrada por lote e de saída como setor `QUALIDADE` obrigatório no roteiro, C8 respeitando `RoteiroItem`, processo de reprovação total/parcial no recebimento) passa a ser a **arquitetura confirmada**, ainda sem nenhum código. Só fica em aberto a baixa de matéria-prima consumida além do requisitado (sobras/perdas de corte) — o Nathan pediu sugestão em vez de decidir. Tudo em [[Encaixe-Estoque-Revenda-no-PCP]]; pendências reais caem de 18 para 10 em [[Perguntas-em-Aberto-Consolidadas]].
>
> **Adendo de 30/09/2026 — retorno do Robert sobre os contratos de integração (conferido no código).** O Robert comparou o vault com o código dos dois lados. **L4 do contrato 26 concluído**: a Carteira do MES lê `/pedidos_liberados` (falta só a data de corte para o teste de ponta a ponta). **Contratos 003 e 005 aprovados por ele com ajustes**, e as duas rotas do MES (`/requisicoes-compra` e `/itens/status`) **já existem** (F3 adiantada). **Contrato 004**: formato aprovado com um ajuste (`id_origem` em cada item); a rota do av-hub ainda não existe e o MES usa um registro manual da compra até lá. **C1 concluída em 22/09, C4 atendida, C3 atrasada** (começa agora). O setor "Logística de Entrada" do MES virou "Recebimento". **Ficam com o Nathan:** nomes dos campos do 003, regra do pedido sem prazo, onde fica o job de leitura do av-hub (F2) e o aceite das diferenças do 005; **com o backend:** a chave própria do MES, de escrita e restrita por rota (L6). Detalhe em cada contrato e em [[Perguntas-em-Aberto-Consolidadas]] seção 0.
>
> **Adendo de 06/10/2026 — Compras e cadastros de acesso (av-hub, API e contratos).**
> - **Contratos 36, 37 e 38 entregues pelo DBA** e movidos para `Realizados/` (o 37 já em produção; P1 do 36 e o 38 conferidos no código da `develop`, `c8f2f5e`). **Contrato 39 novo** ([[39-Vendedores-Fila-de-Vinculo]]): filtro "sem funcionário" e nomes do vínculo na API de vendedores — patch pronto, falta o DBA.
> - **HRM compra pela própria conta Omie**: o DBA limpou `id_unidade_compra` da HRM em produção (na `api-test` ainda aponta para Mogi). Ver [[Decisoes-Chave-ERP]].
> - **OC a partir de requisição do MES** (av-hub#151, na `main`): já traz PV, produto e destino; a OC leva só os itens das requisições; **comprador só compra da filial a que pertence**.
> - **Telas de Compradores e Vendedores** refeitas como fila de trabalho (vínculo lado a lado, candidatos sem digitar): Compradores na `develop` (av-hub#154); Vendedores aguarda o contrato 39 (av-hub#155). **Em produção, 0 dos 74 compradores estão ligados a funcionários**: sem isso ninguém emite OC (contrato 38).
> - **Produção (`auth.telas`)**: criadas `suprimentos` e `painel-comprador`; `compradores` movida para Cadastros › Acessos com permissão para o Admin (Dev).
> - **Transferência de estoque entre filiais** ([[Proposta-Transferencia-Estoque-Filiais]]): o Nathan decidiu 5 das 7 em 06/10 (todas como propostas); **faltam a 3 e a 6, com o Fiscal** (a 3 trava a etapa 2). A **etapa 1 (saldo por filial) já começou** no MES. **A C2 saiu do cronograma** (a filial vem do pedido; o requisito de permissão por filial vai para a C3).
> - Pendências novas em [[Perguntas-em-Aberto-Consolidadas]] seção 0 (bloco "Compras e acessos, 06/10").

## 1. Em uma frase

**A construção está em andamento, na `develop`.** Escrito em 21/09 como "o planejamento está feito e a construção começa amanhã". **Em 07/10:** a Entrada Comercial (Omie → pipeline → av-hub) e o motor de Flanges seguem sendo o que roda de fato; o Compras do av-hub (requisição, OC, envio ao Omie) e o Estoque/Recebimento/Qualidade do MES já têm código na `develop`, e o módulo Comercial & Suprimentos nasceu no av-hub. O que está em produção de verdade não foi conferido nesta rodada.

## 2. Linha do tempo

| Data | Marco | Situação |
|---|---|---|
| 16/09 a 21/09 | Análise, fluxos, PRD, cronograma, contratos e modelo de rastreabilidade | **Concluído** (planejamento) |
| **21/09** | **Hoje** | Vault unificado; auditoria contra dump de produção; **8 das 11 DEC decididas em conversa direta** (DEC-1, 2, 3, 5, 7, 9, 10, 11) + DEC-12 nova (genealogia de material); ~45 das ~60 perguntas da lista consolidada fechadas |
| **22/09** | **Início da execução (S1)**. O cronograma previa S1 desde 18/09, então as janelas estão deslocadas um dia | Próximo |
| 25/09 | **M1** — DEC-1 a DEC-9 respondidas (ou default adotado por escrito), contratos destravados, hardware aprovado | **Quase lá**: 6 das 9 (DEC-1,2,3,5,7,9) já decididas. Restam DEC-4 (a mais urgente — trava D1), DEC-6 e DEC-8 (adiada de propósito) |
| 29/09 | Spec da integração av-hub ↔ MES aprovada (F1) | **Em andamento**: Robert aprovou com ajustes em 30/09; faltam 4 decisões do Nathan e o Gustavo |
| 02/10 | **M2** — Fundação no ar | **✅ Cumprido (07/10):** `mes-test.acosvital.com.br` (homologação) no ar com a `develop`; o `PUT` do contrato 34 funcionou no teste ([[Registro-de-Decisoes-2026-10-07]], itens 1 e 2). ~~Texto de 07/10 de manhã: "sem homologação nem deploy confirmados... não dá para dizer no ar"~~ (superado). Seguem sem testes e2e (D2) |
| 16/10 | **M3** — Fase 0 (sistema) pronta | **Adiantada no código** (Recebimento, Qualidade, saldo, reservas, etiqueta, transferência etapa 1 já na `develop`); homologação disponível no `mes-test`; faltam carga inicial em lote (G1, do Robert), RBAC por setor/filial (C3) e o roteiro respeitando `RoteiroItem` (C8). Data mantida |
| 30/10 | **M4** — Fases A + B em homologação | Não iniciada como marco (parte do código já existe); homologação disponível no `mes-test`. Só antecipa se a homologação estiver estável até 16/10 |
| 13/11 | **M5** — Fase 0 fechada + Fase C | Não iniciada; homologação disponível no `mes-test` |
| 18/11 | **M6** — Go/no-go do piloto | Não iniciada. Data mantida |

Detalhes de cada marco em [[Cronograma-2-Meses]].

## 3. O que já está pronto

| Item | Onde | Observação |
|---|---|---|
| Fluxo operacional mapeado (macro e item a item, 6 subfluxos) | [[Fluxo-Detalhado-Pedido-Item]], [[Fluxogramas-Completos]] | É o processo-alvo; não está em nenhum sistema ainda. Encaixe do Estoque e da Revenda no MES decidido em 24/09 — [[Encaixe-Estoque-Revenda-no-PCP]] |
| PRD do Estoque, Recebimento e Compras | [[PRD-Estoque-Visao-Geral]] | Só planejamento, **não construído** |
| Análise dos backends e do pipeline | [[Omie-ELT-Pipeline]], [[App-PCP-Backend-Producao]] | Leitura de código; sem alterações |
| Levantamento da API do Omie e roteiro de extração | [[Indice-Integracao-Omie]] | Lacunas mapeadas |
| Cronograma de 3 meses (até 18/12; o arquivo mantém o nome antigo) | [[Cronograma-2-Meses]] | Plano, com premissas de capacidade que ainda precisam de confirmação |
| Contratos (SQL, API e lógica fora do backend) | [[Indice-Contratos]] | **Atualizado em 07/10:** a maior parte está entregue (pasta `Realizados/`). Abertos de fato: **004** (rota inexistente), **005** (rota existe no MES, falta consumidor no av-hub), **23** (pipeline: código pronto, falta conferir deploy), **07** (código existe na API; desenvolvido por fora, no Comercial & Suprimentos, e o contrato precisa ser reescrito — decisão de 07/10; a de 01/10 era "desconsiderado") e a **L6** do 26 (chave do MES restrita só para leitura). 002 rejeitado e 006 invalidado. As entregas dos contratos 21–39 foram conferidas no código em 07/10; produção só onde a nota do contrato diz |
| Modelo de rastreabilidade, custódia e SLA | [[Rastreabilidade-e-SLA-de-Eventos]], [[Campos-e-API-para-Rastreabilidade]] | **Proposta**, para a spec F1 |
| Protótipo de tela (Torre de Fluxo) | [Artifact](https://claude.ai/artifact/SS4C4srRk9cr66UHUS2rE3) | Dados fictícios; não é sistema |
| Perguntas em aberto consolidadas | [[Perguntas-em-Aberto-Consolidadas]] | Atualizada em 29/09: de ~60 perguntas, 10 pendências reais restam (seção 0 da nota) — o resto foi decidido, aceito ou ficou moot |
| Vault unificado e nota de entrada | [[Comece-Aqui]] | — |

## 4. O que está construído de verdade

> **Reescrita em 07/10/2026.** O texto de 21/09 dizia "só o que já existia antes do projeto... nenhuma linha de código dos itens do cronograma foi escrita". Isso deixou de valer.

**Já existia antes do projeto:** a Entrada Comercial (pedido no Omie, sincronizado ao av-hub pelo pipeline), o Portal do Vendedor, os módulos de vendas e faturamento do av-hub, e o motor de execução de roteiro de Flanges do `api-pcp`.

**Construído desde 22/09 (conferido no código; produção não verificada):**

| Onde | O que existe | Em que ramo |
|---|---|---|
| `api-pcp`/`app-pcp` (MES) | Estoque (materiais, depósitos, saldo, reservas, movimentação, lote, etiqueta PDF, alertas), requisição de compra com circuito fora do roteiro, Qualidade de entrada (aprova/reprova por lote, RNC, quarentena), **Recebimento** com conferência contra a NF, recontagem e decisão do PCP, saldo por filial no atendimento, login duplo, carteira lendo `/pedidos_liberados`, envio e leitura de eventos do av-hub (contratos 34 e 35). Ver [[App-PCP-Recebimento-Conferencia]] | **só `develop`** (a `main` parou em 28/08) |
| av-hub (front + BFF) | Compras (requisições, OC das requisições, follow-up CCP, dashboard, compradores e vendedores como fila de vínculo), liberação de pedido, módulo **Comercial & Suprimentos** com `api-comercial` — [[AV-Hub-Comercial-Suprimentos]] | `main` até #153 (06/10); Compradores/Vendedores (#154/#155), grande parte do Comercial e 9 branches abertas só na `develop`/branches |
| `api-acos-vital` | Contratos 26 a 39 no código, `/docs`, autenticação em camadas, orçamento e coordenadores no banco (07) — [[AV-Hub-API-Estado-Atual]] | `main` = `develop` (`a6ab058`) |
| `omie-elt-pipeline` | Compras completo (espelho, PTAX, catálogos, inativação) e envio da OC ao Omie — [[Omie-ELT-Pipeline]] | `master` (`d2886bf`); **(atualizado em 07/10)** envio da OC **fixo no código**, direto ao Omie, sem `SYNC_ENVIO_OC` nem `ENVIO_OC_DRY_RUN` (o texto antigo dizia "desligado por padrão"); roda na VPS 1 ([[Registro-de-Decisoes-2026-10-07]], itens 4 e 7) |

**Ainda não existe em código:** transferência entre filiais etapas 2 a 4 (solicitar, aprovar, expedir, receber), RBAC por setor/filial (C3), roteiro respeitando `RoteiroItem` (C8), importação de carga inicial em lote (G1, a cargo do Robert; carga com **dupla conferência contador + conferente** e **terceira contagem** em caso de divergência — [[Registro-de-Decisoes-2026-10-07]], item 25), rastreabilidade `fluxo.*` (I/J), leitor de código de barras e posto de recebimento, a rota `/ordens-compra/referencia` (004) e o consumidor de `/itens/status` no av-hub (005), harness de testes e2e do Estoque.

## 5. Quadro de tarefas da S1 (22/09 a 05/10)

Estados: **Não iniciada**, **Em andamento**, **Bloqueada**, **Concluída**, **Cortada**. IDs e critérios de pronto estão na seção 5 do [[Cronograma-2-Meses]]. As janelas abaixo são as **reajustadas em 22/09** (N-07: 22/09 a 05/10), iguais às do [[Cronograma-2-Meses]]; as janelas originais (18/09 a 02/10) foram superadas.

| ID | Entrega | Resp. | Janela planejada | Estado | Depende de |
|---|---|---|---|---|---|
| A1 | Workshop de decisões DEC-1 a DEC-9 | Nathan | 22/09–29/09 | Não iniciada | — |
| A2 | Hardware do posto e agenda do levantamento físico | Nathan | 22/09–28/09 | Não iniciada | DEC-8 |
| B1 | Fechar as perguntas dos contratos | Gustavo | 22/09–28/09 | **Concluída** — G-01 a G-18 todas respondidas em conversa direta com o Gustavo (21/09), ver [[Perguntas-em-Aberto-Consolidadas]] bloco C | DEC-7 |
| B2 | Homologação do MES/Estoque e backup do banco do MES | Gustavo | 22/09–28/09 | **Concluída** a parte da homologação (07/10): `mes-test.acosvital.com.br` roda a `develop`. **Backup do banco do MES segue pendente** ([[Registro-de-Decisoes-2026-10-07]], item 1) | — |
| C1 | Login duplo no MES | Robert | 22/09–30/09 | **Concluída** em 22/09 (informado pelo Robert em 30/09) | — |
| C3 | Desenho do RBAC por setor | Robert | 22/09–30/09 | **Atrasada** — conferido em 07/10: parte nova (filial no `PerfilSetor`) **não iniciada**; só existe a base antiga (`PerfilSetor` por perfil×setor, `@RequirePermission` por controller). Ver lacuna de segurança em [[App-PCP-Visao-Geral]] | — |
| D1 | Schema Prisma do Estoque v1 | Pablo | 22/09–30/09 | **Concluída no código** (`f8186cf`, 22/09, `develop`; migration `20260922110000_estoque_v1`). Fica em `public`, **sem schema próprio** — **decidido em 07/10** (fecha CC-06; o vault dizia "schema próprio") | **DEC-4** (decidida 22/09) |
| F1 | Spec da integração av-hub ↔ MES | Nathan | 22/09–30/09 | **Em andamento, mas o desenho mudou** — o 003 foi substituído pelo 34 (o MES **empurra** a requisição, já implementado dos dois lados) e o 35 (eventos) está ligado no MES; **004 continua sem rota** em ambos; **005** tem rota no MES e **falta o consumidor no av-hub**; **IM-01 e IM-03 superados** pelo contrato 34, **IM-02 resolvida pelo código** (o MES cai para `pedido.prazoEntrega` e recusa se ainda não houver prazo) e **IM-04 aguarda o aceite do Nathan** (ver 005 em [[Registro-de-Decisoes-2026-10-07]], item 42); falta a L6 (chave do MES só de leitura/escrita restrita por rota). Ver [[Chaves-de-Integracao-AvHub-MES-Pipeline]] | DEC-2 |
| A3 | Pauta financeira e critérios de aceite | Nathan | 29/09–05/10 | Não iniciada | — |
| B3 | Aplicar contratos SQL 001 e 005 | Gustavo | — | **Concluída** — já aplicado em produção antes do início da S1; confirmado por [[Auditoria-Dump-Producao-2026-09-21]] (21/09). Capacidade do Gustavo nessa janela fica livre | B1 |
| B4 | API `alterado_desde` em produtos e parceiros | Gustavo | — | **Concluída** — já implementado em `produtos.js`/`parceiros.js`; confirmado por [[Auditoria-Dump-Producao-2026-09-21]] (21/09) | B1 |
| C4 | Carteira do PCP: importar itens do pedido | Robert | 29/09–05/10 | **Concluída** — confirmado pelo Robert em 30/09, já lendo `/pedidos_liberados` (L4 do [[26-Vendas-Liberacao-Pedido]]) | — |
| D2 | Módulo base do Estoque e testes e2e | Pablo | 29/09–05/10 | **Módulo em `develop`** (`28f5ca4`, 22/09); **testes e2e não existem** (sem `*.spec`, sem script `test`) — critério de pronto não atendido | D1 |
| C2 | Vínculo Fábrica ↔ Filial | Robert | — (removida) | **Cortada** em 06/10 (Robert propôs, Nathan aprovou): a filial vem do pedido; o vínculo com a filial passa para o depósito. Os 1,5 pd vão para a etapa 1 da transferência | DEC-1 |
| D3 | Projeção read-only de material e parceiro | Pablo | 01/10–05/10 | **Metade** — Material nasce por snapshot do av-hub na entrada (`upsertMaterialDoAvhub`, PR #44); o model `Fornecedor` existe e **nada o popula**; o full sync ficou só na branch `estoque/schema-v1` | B4 |

**Tarefas de S2 em diante que já têm código na `develop` do MES (conferido em 07/10):**

| ID | Entrega | Estado no código |
|---|---|---|
| C5 | Guard de permissão | **Parcial, não global**: `@RequirePermission` por controller (~20) desde 04/09; sem `APP_GUARD`; `UsuariosController` e `SetoresController` sem guard |
| C6 | Tipos de Fábrica/Setor, Estoque como etapa 1 | **Concluída** (28/09 e confirmado no código) |
| C7 | Requisição de compra | **Em `develop`** (`b8dc158`, 29/09; cancelamento e envio ao av-hub `e7ce2c9`, 02/10) |
| C8 | "Novo norte" respeitando `RoteiroItem` | **Parcial**: só a tela `/decisoes-pcp` (divergência de recebimento); `RoteiroItem` **não** é lido pelo mover/concluir/Expedição |
| D4 | Alias de material | **Cortada** (contrato 002 rejeitado); código removido em 29/09 (`0ac2596`) |
| D5 | Cadastros do Estoque (materiais, depósitos, localizações) | **Em `develop`**, API real (`e14ecb2`) |
| D6/D7 | Recebimento (backend e tela) | **Em `develop`** (07/10, `861c050` e `f2c01f1`) — [[App-PCP-Recebimento-Conferencia]] |
| D8 | Qualidade | **Em `develop`**, backend e front reais (`898aa54`, `815fef3`) |
| D9 | Disponibilidade/atendimento pelo estoque | **Concluída** (`0fe771f`, 28/09) |
| D10 | Saldo, reserva, movimentação | **Em `develop`**, API real; `painel-estoque` e `mapa-deposito` ainda com parte mock |
| D11 | Etiquetagem | **Parcial**: etiqueta PDF Code128 (`2e2c18e`); sem leitor 2D nem posto de recebimento |
| — | Transferência entre filiais, etapa 1 (saldo por filial) | **Concluída** em `develop` (07/10, `861c050`); etapas 2–4 não existem |
| G1 | Carga inicial | **Parcial**: só `POST /estoque/lotes/carga-inicial`, um lote por vez |
| I/J | Rastreabilidade `fluxo.*` e genealogia | Nada no Prisma |

Obs.: o quadro de S1 acima mostra "Concluída" onde o critério de pronto do cronograma foi atendido no código; **"Concluída" aqui não significa em produção.** **(atualizado em 07/10)** A homologação agora existe: `mes-test.acosvital.com.br` roda a `develop`, então o que está na `develop` já pode ser homologado lá; "homologada" só vale para o que alguém de fato testou nesse ambiente. Produção só foi conferida pelo dump de 07/10. S2 a S4 e o fechamento seguem o [[Cronograma-2-Meses]].

> **(atualizado em 07/10)** **Responsáveis:** onde a coluna "Resp." diz Pablo (D1 a D3 e as demais tarefas do Estoque), o histórico fica; daqui em diante o Pablo atua no **Comercial & Suprimentos** e o **MES inteiro fica com o Robert** ([[Registro-de-Decisoes-2026-10-07]], itens 32 e 33). Detalhe em [[Equipe-Projeto]].

## 6. O que está bloqueando ou em risco agora

> **Reorganizado em 21/09/2026, contagem atualizada em 29/09.** A lista completa e atualizada de pendências reais vive só em [[Perguntas-em-Aberto-Consolidadas]] seção 0 (29 itens em 07/10, incluindo os 9 CC da conferência de código) — não duplicada aqui, pra não ter duas fontes de verdade desalinhando. Esta seção lista só os riscos de **cronograma/execução**, não as perguntas de negócio em si.

> **Riscos novos de 07/10/2026 (conferido no código; produção não verificada):**
> - **`main` do MES parada em 28/08.** Todo o Estoque/Recebimento/Qualidade/requisição está só na `develop` do `api-pcp` e do `app-pcp`; não há evidência de pipeline de deploy. Quem publica e quando?
> - **L6 aberta:** a chave do MES que o contrato 34 criou só abre o `PUT`; o MES hoje lê o av-hub com chave de outro tipo (admin ou do banco, sem restrição por rota). Ver [[Chaves-de-Integracao-AvHub-MES-Pipeline]].
> - **Migrations que o código exige e o repositório não versiona** (`api-acos-vital`): 006, 007/007b, 009, 012, 013, 015, 022, 024, 025, 032, 034, 035, 036 e o SQL do 33. Em especial `fn_requisicao_mes_aplicar` (contrato 34): **(atualizado em 07/10)** ela **existe em produção**, completa (dump de 07/10), e o `PUT` funcionou no teste; falta só **versionar o SQL no vault** ([[Registro-de-Decisoes-2026-10-07]], item 3). ~~"Sem ela o PUT do MES devolve 500"~~ (superado). O anexo do contrato só cria 2 colunas.
> - **Segurança no `api-pcp`:** controllers de usuários e setores sem guard (ver [[App-PCP-Visao-Geral]]).
> - **`api-comercial` não tem publicação conferida** (nem as 22 telas/slugs em `auth.telas` (eram 18 em 07/10), nem a claim `perfis` no token) — [[AV-Hub-Comercial-Suprimentos]].
> - **Compradores sem vínculo:** 0 de 74 em 06/10 — ninguém emite OC desde o contrato 38 (CA-03).
> - **Envio da OC ao Omie (reescrito em 07/10):** ~~só liga com `SYNC_ENVIO_OC=true` e `ENVIO_OC_DRY_RUN=false`~~ (superado). O envio é **fixo no código** e vai direto ao Omie, sem essas chaves. O Nathan fez cerca de 4 testes reais e a OC entrou. Os pontos L10.1, L10.6 (FOB) e L10.7 (b) a (d) viram **risco aceito**. Mudança de código: Gustavo. **(conferido no código em 08/10: ainda não foi alterado — `SYNC_ENVIO_OC` segue `false` e `ENVIO_OC_DRY_RUN` segue `true` por padrão em `src/config/index.ts`, e o README da pipeline diz que ligar espera o deploy da API com o contrato 36; hoje o envio só acontece se alguém ligar as duas chaves.)** A pipeline roda na VPS 1.
> - **Risco crítico (🔴 Gustavo):** o `exclusionSync` apaga `pedidos_vendas` sem filtrar `manual`; pedido manual não existe no Omie. Confirmar antes de usar pedido manual em produção ([[Registro-de-Decisoes-2026-10-07]], item 15).

1. **~~DEC-4 é o único bloqueio real de amanhã.~~** (texto de 21/09, superado: DEC-4 foi decidida em 22/09 e a D1 já está em `develop`.) DEC-6 e DEC-8 também foram decididas em 22/09. Todas as DEC (1 a 12) estão decididas — ver [[Decisoes-Chave-ERP]].
2. **~~Início um dia depois do previsto.~~** (N-07 respondida em 22/09.)
3. **~~Capacidade real não confirmada.~~** (N-06 respondida em 22/09.) O ritmo observado no código (Estoque, Recebimento e Qualidade adiantados em relação ao cronograma) sugere que S2/S3 estão à frente; os marcos só se movem com homologação.
4. **Rastreabilidade completa decidida, já encaixada.** R-07/R-14: escopo é todas as rotas. Cronograma estendido pra 3 meses (S5, 19/11-18/12) — ver [[Cronograma-2-Meses]] seção 3.1 e 5. Junto entrou o bloco J (genealogia de material, DEC-12).
5. **Estados e status — maioria resolvida em 21/09.** Dos 3 problemas críticos originais de [[Revisao-dos-Estados-e-Status]], o ponto 2.1 (status por item com parciais) já tem resposta (atraso medido no nível do pedido). Seguem 6 perguntas da seção 5 dessa nota sem resposta — listadas em [[Perguntas-em-Aberto-Consolidadas]] seção 0.
6. **Lacunas de lógica — 10 das 11 resolvidas em 21/09.** [[Lacunas-de-Logica-e-Clareza]]: L-01 a L-09 e L-11 têm resposta ou proposta aceita. Só **L-10** (sobras de chapa, perda no corte, conversão de unidade) segue sem tratamento: **(atualizado em 07/10)** foi para o **Ciclo 2** (começa em 04/01/2027), junto com EC-02 ([[Registro-de-Decisoes-2026-10-07]], item 27).
7. **Dependência de fora do time de dev:** levantamento físico (26–30/10), saneamento do catálogo (removido do escopo — duplicata de catálogo agora se resolve direto no Omie, ver [[Cronograma-2-Meses]]), hardware e UAT. Datas no gantt do cronograma.

## 7. Como manter esta nota

- **Quem:** o responsável pela tarefa muda o estado da própria linha; o Nathan revisa o resto.
- **Quando:** no mesmo dia em que o estado mudar, e uma revisão geral por semana (sugestão: segunda-feira).
- **O que atualizar:** o campo `atualizado` do cabeçalho e a data da primeira linha; o estado da tarefa; a seção 6 quando um bloqueio abrir ou fechar.
- **Quando uma decisão for tomada:** registrar em [[Decisoes-Chave-ERP]] e marcar aqui.
- **Quando um contrato for aplicado:** mudar o status no [[Indice-Contratos]] e citar aqui.
- **Nunca** marcar "Concluída" sem o critério de pronto do cronograma.

## Ver também
- [[Comece-Aqui]]
- [[Home]]
- [[Cronograma-2-Meses]]
- [[Perguntas-em-Aberto-Consolidadas]]
- [[Decisoes-Chave-ERP]]
- [[Auditoria-Dump-Producao-2026-09-21]] — depara completo dump vs. vault vs. código (21/09)
