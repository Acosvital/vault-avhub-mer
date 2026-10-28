---
id: LOG-62
aliases: ["Contrato 62", "62-Reescopo-Menu-Enxuto-e-Limpeza-do-Modulo-do-Pablo"]
tags: [contrato, contrato-logica, hub-front, hub-api, menu, telas, vendas, orcamento, compras, limpeza, api-comercial, reescopo]
criado: 2026-10-27
atualizado: 2026-10-28
status: proposta
sistemas: [hub-front, hub-api, hub-banco]
dono: "Nathan (telas e menu) e Robert (o que migra e o que não migra; o Pablo acompanha)"
etapa_0b: [V0.1, V0.2, B1, B2, B3, B4, C6, C7]
fontes: ["pedido do Nathan de 27/10/2026 (enxugar, unir telas, separar por área, 'Histórico de compras nem deveria ter')", "preview do av-hub na porta 3000, logado, em 27/10/2026 (Compras carregou; Vendas e Orçamento deram 500 porque a api-comercial estava fora do ar)", "GET /api/menu do Hub em 27/10/2026 (árvore de Vendas, Orçamento, Compras, Comissões e Dashboards)", "av-hub develop (arquivos de app/(protected)/vendas, orcamento e compras; components/Suprimentos, Propostas, PainelComprador, CustoItens, Relatorios, Configuracoes, DashboardComercial)", "av-hub/api-comercial (src/modules, src/domain, prisma/migrations, scripts)", "git log --author=Pablo do av-hub (504 caminhos tocados, 335 ainda existem)", "LOG-52, LOG-57, 14-Telas-e-Experiencia-do-Usuario, Mapa-do-Modulo-do-Pablo, Registro-de-Decisoes (N16-02, N16-13, N16-27, N16-58)"]
criado_original: 2026-10-27
---

# Contrato 62 — Menu enxuto de Vendas, Orçamento e Compras e limpeza do módulo do Pablo antes da migração

> **Onde atua:** av-hub: front (menu e telas), API (o que o Pablo porta para a `api-acos-vital`) e banco (`auth.telas`)

> [!info] Situação em 28/10/2026
> **Status:** `proposta` · **Pasta:** `Ativos` · **Nós do 0b:** `V0.1`, `V0.2`, `B1` a `B4`, `C6`, `C7` · **Decisões:** N16-107 a N16-110 em [[Registro-de-Decisoes]]
>
> - 📝 **28/10/2026, N16-117 a N16-119:** o **Robert** conduz a migração (o Pablo acompanha) e começa pela **proposta** (N16-118). As telas do Pablo **ficam** e trocam de backend; o agrupamento em abas deste contrato vale para elas. A `api-comercial` fica no repositório só para leitura.
> - 📝 **N16-116:** não existirá `core_comercial`; o que for portado vai para `core_vendas_faturamento`. **N16-112:** um conceito, uma tabela, uma rota, uma tela (cliente no Acompanhamento de Clientes, fornecedor e categoria no Orçamento do Hub). **N16-113:** e-mail e notificações ficam para o futuro.
> - 📝 **Decidido pelo Nathan (27/10):** o menu fica mais curto, com telas unidas por área de operação; o **Histórico de compras sai** (a tela Ordens de compra já mostra o histórico); o que o Pablo criou **é só ambiente de teste e não tem dado**, então a limpeza é escolher o que **não portar** para a `api-acos-vital`, sem migrar dado.
> - 🟡 **Proposta, a validar na tela:** o agrupamento em abas (seção 3), a lista de reaproveitar e não portar (seção 5) e as fases (seção 6).
> - ❓ **Não conferido:** nenhuma tela de Vendas ou de Orçamento foi vista com dado (a `api-comercial` estava fora do ar e responde 500 fora do ambiente de teste); o comportamento foi lido no código. O Relatório Gerencial não foi comparado com o Dashboard da Equipe nem com o Dashboard Comercial.

Selos em [[Regras-do-Vault]]. Este contrato **substitui, no que tem de menu**, a seção "Reorganização proposta em 23/10/2026" do [[LOG-57-Menu-Vendas-Orcamento-Compras]] e a seção 6 de [[14-Telas-e-Experiencia-do-Usuario]] (menu de 6 entradas em Orçamento passa a 4). Para o que o Pablo portar, vale em conjunto com o [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]].

## 1. Por quê

O menu de 16/10 ([[LOG-57-Menu-Vendas-Orcamento-Compras]]) reagrupou as telas do Pablo, mas manteve 17 entradas (Vendas 7, Orçamento 9 e Histórico de compras em Compras). Três problemas, conferidos em 27/10:

1. **Telas de permissão aparecem como tela.** O `GET /api/menu` devolve `propostas-delegacao`, `propostas-valores`, `solicitacoes-custo` (Vendas) e `custo-item` (Orçamento) como entradas comuns, apesar de o LOG-57 §3 tratá-las como ocultas.
2. **O mesmo dado em várias telas.** Preço de produto e fornecedor aparece em Catálogo, Pesquisa de materiais e Ofertas; a fila de pedidos de custo está em Painel do Comprador (e a lista de solicitações do vendedor é outra rota do mesmo dado); os dois relatórios de Vendas repetem totais.
3. **Histórico de compras duplica Ordens de compra.** O Histórico lê uma **cópia** das ordens do Omie que o Pablo grava em `core_comercial.ordens_compra` e `itens_ordem_compra` (não portadas, N16-109; o schema sai, N16-116); Ordens de compra lê as ordens reais do Hub e do Omie (24.324 em 27/10) e já mostra o histórico (decisão do Nathan).

## 2. Como foi levantado

| Fonte | O que deu |
|---|---|
| Preview do av-hub (porta 3000, sessão do Nathan) | Compras (Ordens, Histórico) abriu e carregou. Vendas e Orçamento abriram a estrutura, mas as chamadas a `/api/comercial/*` voltaram 500 |
| `GET /api/menu` | Árvore real de Vendas (7), Orçamento (9) e Compras (6, com o Histórico), além de Comissões e Dashboards |
| Código do av-hub e da `api-comercial` | Para cada tela: componente, serviço e tabela que ela lê |
| `git log --author=Pablo` | Arquivos que o Pablo criou e ainda existem (335): `api-comercial` (cerca de 12 mil linhas de `src`), `components/Suprimentos` (28 arquivos), `components/Propostas` (16), telas de Vendas e Orçamento, serviços e `lib/domain` |

## 3. Menu final 🟡

A regra de ouro: **mantém o slug da tela principal** de cada grupo, para as permissões (`auth.permissoes`, por `id_tela`) seguirem. As telas que viram aba são desativadas e a aba responde pela permissão da tela principal.

### 3.1 Vendas (de 7 para 4)

| Entrada | Slug | O que reúne | Observação |
|---|---|---|---|
| **Propostas** | `propostas` | lista, nova, detalhe | muda de ciclo: [[11-Proposta-e-Pedido-de-Venda]] |
| **Clientes** | `clientes` | lista, novo, ficha | ver §5.2 (cadastro por conta Omie) |
| **Meus Pedidos** | `meus-pedidos` | já existe fora de Vendas (pedido do vendedor) | passa a ficar no grupo; onde o vendedor responde `C8` |
| **Relatórios** | `relatorio-gerencial` (renomeada) | abas **Gerencial** e **Cotações** | o Relatório de Cotações é subconjunto do Gerencial (totais, valor, fechadas, conversão e a tabela por cliente); `relatorio-cotacoes` é desativada |
| *(oculta)* `propostas-delegacao` | — | libera escolher outro responsável | só permissão |
| *(oculta)* `propostas-valores` | — | libera ver R$ na proposta | só permissão |
| *(oculta)* `solicitacoes-custo` | — | libera o vendedor pedir custo (`B3`) | só permissão; a fila mora em Pedidos de custo |

### 3.2 Orçamento (de 9 para 4)

| Entrada | Slug | O que reúne | Observação |
|---|---|---|---|
| **Pedidos de custo** | `painel-comprador` (renomeada) | abas **Fila** (solicitações abertas, assumir, responder) e **Cotação** (a tela Pedido de cotação, e-mail por fornecedor) | é o mesmo trabalho do comprador; `pedido-cotacao` é desativada |
| **Produtos** | `catalogo-produtos` (renomeada) | lista e ficha com abas **Preços e fornecedores**, **Comparar** (a Pesquisa de materiais) e **Ofertas** (lançar, importar mapa, invalidar) | as três telas liam a mesma base de ofertas; `pesquisa-materiais` e `ofertas-fornecedor` são desativadas; a **página do produto** (`B2`) nasce aqui ([[LOG-60-Matriz-de-Precos-e-Consulta-do-Vendedor]]) |
| **Fornecedores** | `fornecedores` | lista e ficha | ver §5.2 (fonte do fornecedor) |
| **Parâmetros** | `parametros-custo` (renomeada) | abas **Custo** e **Tabela da telha** | ambos são cadastro com vigência; `tabela-telha` é desativada |
| *(oculta)* `custo-item` | — | libera ver custo, margem e sugestão | a página `/orcamento/custo-itens` mostra **dados de exemplo** ("os números abaixo não são do pedido real"); sai do menu até virar o "Custo real do pedido" com dado real ([[LOG-61-Custo-Real-do-Pedido-Telas]]) |

### 3.3 Compras (de 6 para 5)

| Mudança | Por quê |
|---|---|
| **Histórico de compras sai** (`historico-compras` desativada; página e `components/Suprimentos/HistoricoCompras.tsx` removidas) | Ordens de compra já mostra tudo; o que faltar vira filtro (§4) |
| Fica: Aprovações, Dashboard de compras, Ordens de compra, Requisições, Follow-up (CCP) | sem mudança aqui; "Aprovações" vira "Aprovar OC" na rodada das telas novas ([[14-Telas-e-Experiencia-do-Usuario]] §3, item 7) |

### 3.4 Fora do menu e fora do código

| Item | Onde está | Decisão |
|---|---|---|
| **Simulador de Orçamento** | `/orcamento/simulador-orcamento` (1.101 linhas) e `lib/simulador/orcamento.ts` (439); só no menu de desenvolvimento | **Remover.** A análise de margem da proposta e o Simulador de Comissão cobrem o mesmo cálculo |
| **Sincronização Omie** | `/orcamento/sincronizacao-omie`, `components/Suprimentos/SincronizacaoOmie.tsx` | **Remover.** O LOG-57 já a dava como removida (`200e860`), mas a `develop` ainda a tem; duplica a pipeline |
| **Pedidos de Venda** e **Notas Fiscais de Saída** | `/vendas/pedidos-de-venda`, `/vendas/notas-fiscais-saida` | Seguem **inativas** (N16-33); o Pedidos de Venda é a base da Fila do Fiscal |

**Resultado:** de 17 entradas (7 + 9 + 1) para 4 + 4 + 0 visíveis em Vendas e Orçamento, e Compras com uma a menos.

## 4. O que Ordens de compra precisa para cobrir o Histórico 🟡

Hoje Ordens de compra tem filtros **Unidade**, **Status** e **Origem** e busca por texto (conferido no preview; o que a busca cobre ❓). O Histórico servia para ver, por **produto**, o que foi comprado, de quem e a que preço. Para a tela Ordens substituí-lo:

| O que falta | Onde | Quem |
|---|---|---|
| Filtro por **produto** (item da OC) e por **fornecedor** | Ordens de compra, lendo `core_compras` | Nathan (tela), Gustavo (se a API não filtrar por item) |
| **Série por mês** (valor e quantidade) | já existe em "valor comprado em 12 meses" no Dashboard de compras; o por produto vai para a aba Preços da página do produto (`B2`) | Nathan |

Até isso existir, o Histórico **não precisa** ser religado: a página do produto (`B2`) lê o histórico de preço a partir das ofertas das OCs ([[API-020-Orcamento-Base-de-Preco-e-Pedido-de-Custo]]), não da cópia do Pablo.

## 5. O que o Pablo criou: reaproveitar e não portar

Fato (Nathan, 27/10/2026): **tudo é ambiente de teste e não tem dado**; a `api-comercial` não será publicada (N14-15). Por isso **não há migração de dado nem risco de perda**: o corte é do que entra na `api-acos-vital`. Tamanhos de `api-comercial/src` (✅ lidos em 27/10):

### 5.1 Não portar

| O que | Tamanho e onde | Motivo |
|---|---|---|
| **Sincronização própria do Omie** | `src/modules/omie/*` (1.028 linhas), `scripts/sincronizar-omie.ts`; tabelas `produtos_contas_omie`, `fornecedores_contas_omie`, `ordens_compra`, `itens_ordem_compra`, `omie_registros_brutos`, `sincronizacoes_omie`, `travas_tarefa` (migrations `20261005120000` e `20261006120642`) | O Hub já tem `core.produtos`, `core.parceiros` e `core_compras`, alimentados pela pipeline (LOG-52 §2 e §3.4: a pipeline é a fonte do Omie, e a sincronização própria "some"). A cópia só existe para alimentar o Histórico e as ofertas `PEDIDO_OMIE`; estas passam a vir das OCs da pipeline ([[SQL-017-Orcamento-em-core_vendas_faturamento-Base-de-Preco-e-Pedido-de-Custo]]) |
| **Histórico de compras** | `src/modules/suprimentos/historicoCompras.ts` (160), rota `/historico-compras`, `components/Suprimentos/HistoricoCompras.tsx` (278), `GraficoComprasMes.tsx` | Lê a cópia acima; sai por §3.3 |
| **Planilha "pedido a digitar no Omie"** | `src/modules/propostas/pedidoOmie.ts` (388), rotas `GET/PUT /propostas/:id/pedido_omie`, `PedidoOmieModal` | O pedido vai por API e fila (N16-02) |
| **Migração do ERP antigo** | `scripts/migrar-erp-antigo.ts`, `src/domain/migracao/erpAntigo.ts` (323), `src/modules/propostas/migracao.ts` (192) | Não há migração de propostas antigas (N16-13, N16-27) |
| **Fechamento parcial, perdida e reabrir** | `StatusProposta.PARCIAL`, `fechar`, `perder`, `reabrir` em `propostas.service.ts` | Substituídos por `APROVADA`, `TRANSFORMADA` e `CANCELADA` (N16-02, N16-03) |
| **Autenticação e perfis próprios** | `src/middlewares/autenticacao.ts`, `src/lib/perfisHub.ts`, `src/domain/permissoes/perfisDev.ts`; `lib/auth/devSemLogin.ts` no front | RBAC único na `api-acos-vital` (LOG-52 §1) |
| **Terceira cópia do motor, no front** | `lib/simulador/orcamento.ts` (439) e `app/(protected)/orcamento/simulador-orcamento/page.tsx` (1.101) | §3.4 |
| **Câmbio pela AwesomeAPI** | `src/modules/cadastros/cambio.ts` | A PTAX vem do Hub (`cotacoes_moeda`, N16-13); troca a fonte, a rota fica |
| **Documentos `ENVIAR - …` do repositório** | `av-hub/docs/` (contratos de telas, roteiro de publicação, índice de lógica fora do backend, contrato de dados do orçamento) | O que vale está nos contratos do vault; apagar do repositório depois de conferir que cada um é coberto ❓ |
| **Cadastro de clientes próprio** | `core_comercial.clientes` e `clientes_contatos`, `src/modules/clientes/clientes.routes.ts` (503) | 🟡 Duplica os clientes do Omie (`core.parceiros`) e o menu **Acompanhamento de Clientes** (segmento, grupos). A proposta precisa do cadastro **por conta Omie** (N16-80); ver §5.2 |
| **Dashboard Comercial** | `components/DashboardComercial/*`, `src/modules/dashboards/dashboards.routes.ts` (195), tela em Dashboards | 🟡 Decidir com o Nathan: usa "Fechadas/Perdidas" do modelo antigo e convive com Dashboard Vendas, Meu Dashboard e Dashboard da Equipe |

### 5.2 Reaproveitar, com ajuste

| O que | Ajuste |
|---|---|
| **Motor de margem e comissão na API** (`src/domain/simulador/motor.ts` 548, `ladoCompra.ts` 453, `tipos.ts` 248, `daProposta.ts` 134, `src/lib/parametrosSimuladorHub.ts`) | É o "motor na API" que a [[11-Proposta-e-Pedido-de-Venda]] pede (porta do `lib/simulador/motor.ts`). **Uma única fonte da verdade:** o teste de equivalência com o motor do Hub continua (CI `api-comercial.yml`); a cópia do front em `lib/simulador/orcamento.ts` sai (§5.1) |
| **Tela da proposta, PDFs de proposta e de aprovação** (`components/Propostas`, `lib/comercial/PropostaPdf.tsx`, `AprovacaoPropostaPdf.tsx`) | Reescrita pelo fluxo novo ([[14-Telas-e-Experiencia-do-Usuario]] §5); o PDF segue |
| **Ofertas, Fornecedores, Certificados, Parâmetros, Tabela da telha, Pedido de cotação, Painel do Comprador, Pesquisa de materiais** (`components/Suprimentos`, `src/modules/suprimentos`) | Mantêm a lógica; as telas se reagrupam (§3). O fornecedor passa a poder ser ligado a `core.parceiros` em vez de ficar só na tabela própria 🟡 (o SQL-017 já guarda o preço por fornecedor) |
| **Sino de notificações** (`SinoNotificacoes.tsx`, `notificacoes.routes.ts`) | Serve ao aviso de compra acima do valor (`C8`) e à resposta do pedido de custo |
| **Importar mapa de cotação** (`importarMapa.ts` 305, `mapaCotacao.ts` 189) | Mantém: é como o Orçamento lança ofertas de Compras em lote |
| **Revisões da proposta, numeração, idempotência, `If-Match`** | Seguem o contrato ([[API-019-Proposta-e-Pedido-de-Venda-na-API-do-Hub]]); a numeração passa a só dígitos (N16-04) |

## 6. Escopo da entrega em fases 🟡

Proposta do Nathan e minha, de 27/10, **ainda sem confirmação de cada fase**.

| Fase | Entra | Depende de |
|---|---|---|
| **1. Núcleo** | Proposta nova (aprovar, transformar em pedido pela fila do Omie); tabelas `pedidos`, `pedidos_itens`, `pedidos_envios` ([[SQL-016-Proposta-e-Pedido-de-Venda-em-core_vendas_faturamento]]); condições de pagamento e cenários da conta ([[SQL-019-Condicoes-de-Pagamento-de-Venda-do-Omie]]); liberação ([[LOG-58-Liberacao-do-Pedido-Origem-Proposta]]); imposto por item na OC (`C6`, `C7`); **comissão estimada** na proposta, com o motor da §5.2; o menu enxuto desta nota | Pablo e Gustavo (migração e API), Nathan (telas e pipeline) |
| **2. Depois** | Pendências `C8` em Meus Pedidos (`divergencias_compra`); cancelamento com tarja; custo real por evento (`custos_eventos`, [[API-021-Custo-Real-por-Evento-e-Conferencia-de-Compras]]) | Núcleo no ar |
| **3. Adiar** | Comissão real (decisão, devolução parcial, drill-down, coordenadores, relatórios; [[SQL-018-Schema-core_comissao-Comissao-da-Proposta]], [[LOG-59-Telas-da-Comissao-Nova]]); faturamento em partes (três tabelas de sequenciais); datas vigentes e calendário (`pedidos_previsoes`, `calendario_excecoes`); Fila do Fiscal; score, volatilidade e matriz de preços ([[LOG-60-Matriz-de-Precos-e-Consulta-do-Vendedor]]); reescrever os guias do fluxo do custo | Cada frente tem dono e resposta pendente |

> [!warning] O corte das tabelas é por leitura dos contratos
> Não conferi se as funções da transformação em pedido do SQL-016 (`fn_propostas_transformar_em_pedido` e as 22 funções do anexo `0001`) dependem de `pedidos_previsoes` ou dos sequenciais. É provável que dependam. Se sim, separar as fases pede **ajuste e novo teste da migração** (os anexos `0001` e `0002` de [[SQL-016-Proposta-e-Pedido-de-Venda-em-core_vendas_faturamento]]). A fase 3 **não** tira a regra de que a comissão começa no orçamento ([[11-Proposta-e-Pedido-de-Venda]], regra 13): fica a estimada.

## 7. Cadastro das telas (`auth.telas`) 🟡

Para o Gustavo, quando o front estiver pronto (mesma regra do LOG-57: deploy do front e SQL no mesmo momento):

1. **Renomear** `relatorio-gerencial` (Relatórios), `painel-comprador` (Pedidos de custo), `catalogo-produtos` (Produtos) e `parametros-custo` (Parâmetros). Os slugs e as permissões não mudam.
2. **Mover** `meus-pedidos` para o grupo Vendas (hoje está fora; conferir o grupo atual ❓).
3. **Desativar** (`deleted_at`): `relatorio-cotacoes`, `pedido-cotacao`, `pesquisa-materiais`, `ofertas-fornecedor`, `tabela-telha` e `historico-compras`.
4. **Ocultar do menu** `propostas-delegacao`, `propostas-valores`, `solicitacoes-custo` e `custo-item`, mantendo a permissão. **Conferir como a tela oculta é marcada em `auth.telas`** ❓: hoje o `/api/menu` as devolve como entradas comuns; corrigir no cadastro ou no filtro do menu.
5. **Permissões:** quem tinha só `pedido-cotacao`, `pesquisa-materiais`, `ofertas-fornecedor`, `tabela-telha` ou `relatorio-cotacoes` perde o acesso à aba (a aba responde pela permissão da tela principal). Antes de rodar, listar os perfis nessa situação e conceder a tela principal.
6. **Conferência:** o `SELECT` final deve listar Vendas com 4 entradas visíveis e Orçamento com 4, e não listar as telas desativadas.

O SQL em si não está neste contrato: é escrito pelo Gustavo depois da validação das telas.

## 8. Riscos

| # | Risco | Mitigação |
|---|---|---|
| 1 | Perfil perde acesso a uma aba que virou parte de outra tela | Passo 5 da §7 |
| 2 | Favoritos e links para `/orcamento/pedido-cotacao`, `/orcamento/pesquisa-materiais`, `/orcamento/ofertas-fornecedor`, `/orcamento/tabela-telha`, `/vendas/relatorio-cotacoes` e `/compras/historico-compras` quebram | `redirects()` em `next.config.ts` (OQ do LOG-57 §8, item 4) |
| 3 | Ordens de compra sem filtro por produto deixa o Nathan sem o que o Histórico dava | §4: fazer o filtro antes de desativar o Histórico em produção |
| 4 | Separar as tabelas da fase 3 do SQL-016 quebra as funções da transformação | Aviso da §6; reteste da migração |
| 5 | Cadastro de clientes próprio some antes de a proposta ter o cadastro por conta Omie | Decidir §5.1 (clientes) junto com a proposta; até lá a proposta usa o que a migração já entrega |
| 6 | Telas de Vendas e Orçamento não foram vistas com dado | Subir a `api-comercial` em teste e percorrer as abas antes de implementar |

## 9. Perguntas em aberto

| # | Pergunta | Quem responde |
|---|---|---|
| 1 | A Ordens de compra já busca por produto na caixa de busca? Se não, o filtro entra na fase 1 | Nathan |
| 2 | O Dashboard Comercial sai ou fica? E o Relatório Gerencial se sobrepõe ao Dashboard da Equipe? | Nathan |
| 3 | O cadastro de clientes próprio sai de vez (ficando só o do Omie por conta e o Acompanhamento de Clientes) ou o relacionamento (status, segmento, próximo contato) é aproveitado? | Nathan, Pablo |
| 4 | Fornecedores: ligar a `core.parceiros` ou manter a tabela própria do Orçamento? | Pablo, Gustavo |
| 5 | Como a tela oculta é marcada em `auth.telas`? | Gustavo |
| 6 | As fases da §6 estão certas? Algum item sobe ou desce? | Nathan |

## 10. Testes de aceite

1. O menu de um vendedor mostra em Vendas só **Propostas, Clientes, Meus Pedidos e Relatórios**.
2. O menu de um comprador ou orçamentista mostra em Orçamento só **Pedidos de custo, Produtos, Fornecedores e Parâmetros**.
3. Nenhum perfil vê `propostas-delegacao`, `propostas-valores`, `solicitacoes-custo` nem `custo-item` como entrada, mas quem tem a permissão continua com a capacidade.
4. As abas Gerencial/Cotações, Fila/Cotação, Preços/Comparar/Ofertas e Custo/Telha mostram o mesmo conteúdo das telas antigas, com os mesmos filtros.
5. Em Compras não existe Histórico de compras, e a Ordens de compra filtra por produto e fornecedor.
6. O código novo da `api-acos-vital` não contém a sincronização própria do Omie, a planilha do pedido, a migração do ERP antigo nem o fechamento parcial.
7. Um perfil que só tinha `pedido-cotacao` abre a aba Cotação depois do ajuste de permissão do passo 5 da §7.

## Ver também

[[LOG-57-Menu-Vendas-Orcamento-Compras]] · [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] · [[Mapa-do-Modulo-do-Pablo]] · [[14-Telas-e-Experiencia-do-Usuario]] · [[11-Proposta-e-Pedido-de-Venda]] · [[12-Orcamento-Base-de-Preco]] · [[Registro-de-Decisoes]]
