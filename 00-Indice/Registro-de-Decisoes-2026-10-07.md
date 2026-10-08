---
tipo: registro
criado: 2026-10-07
atualizado: 2026-10-08
---

# Registro de decisões de 07/10/2026

> Fonte única para as decisões desta rodada. As demais notas apontam para cá em vez de repetir o texto.

**Legenda de status**

- ✅ **Decidido:** respondido pelo Nathan em 07/10/2026.
- 🟡 **Proposta adotada:** resolvida por evidência no vault e no código, sem resposta do Nathan. Vale até alguém contestar. A pessoa entre parênteses valida.
- 🔴 **Pendente:** ninguém respondeu e nenhuma fonte resolve. Tem dono.

Todo fato abaixo vem de leitura de vault e código em 07/10/2026. **Produção só foi conferida pelo dump de 07/10** ([[Auditoria-Dump-Producao-2026-10-07]]).

## 1. Ambientes e produção

| # | Assunto | Status | Registro |
|---|---|---|---|
| 1 | Homologação do MES | ✅ | `https://mes-test.acosvital.com.br/` roda a `develop` e está no ar. Marco M2 cumprido. |
| 2 | Contrato 34 (PUT da requisição) | ✅ | O `PUT` de sucesso do MES já funcionou no ambiente de teste. |
| 3 | `fn_requisicao_mes_aplicar` | ✅ | Existe em produção, completa (dump de 07/10). O SQL ainda não está versionado no vault. |
| 4 | Infraestrutura | ✅ | Pipeline, MES e av-hub (e outros sistemas) na **VPS 1**. Bancos do MES, do av-hub e demais na **VPS 2**. Arquivos na **VPS 3**. |
| 5 | Etapas de faturamento | ✅ | `core.etapas_faturamento` está populada em produção. |
| 6 | Contrato 39 | ✅ | API em produção. O front (`av-hub#155`) está só na `develop`. |

## 2. Pipeline Omie e segurança

| # | Assunto | Status | Registro |
|---|---|---|---|
| 7 | Envio de OC ao Omie | ✅ | Fica **fixo no código** e vai direto ao Omie, sem `SYNC_ENVIO_OC` nem `ENVIO_OC_DRY_RUN`. O Nathan rodou cerca de 4 testes reais e a OC entrou. L10.1, L10.6 (FOB) e L10.7 (b) a (d) viram **risco aceito**. Alteração de código: Gustavo. |
| 8 | `PERMISSOES_ROTA_MODO` | ✅ | Fixo em **`exigir`** no código, sem `.env`. Alteração de código: Gustavo. As chamadas de serviço do pipeline e do MES (só `x-api-key`, sem `Bearer`) passam sem mapeamento, porque o modo só confere permissão quando há token. |
| 9 | Chaves restantes do contrato 38 | 🟡 (Gustavo) | O front do av-hub manda token em todas as chamadas (✅ Nathan). Fixar **só `ESCOPO_VENDEDORES_EXIGIR`**. `IDENTIDADE_EXIGIR_TOKEN`, `ESCOPO_UNIDADE_EXIGIR_SESSAO` e `AUTENTICACAO_AZURE_VALIDAR_ID_TOKEN` quebram MES e pipeline enquanto eles usarem a chave do `.env` sem token, e `VENDAS_PLANILHA_PAGINAR_POR_PEDIDO` corta dados no front. Ficam como chave até separar as chaves de serviço. |
| 10 | Chave do MES (L6) | 🔴 (Gustavo) | Chave restrita para MES e pipeline, ou continuar com a chave admin? Nathan deixou com o Gustavo. O MES precisa de escrita (`POST /pedidos_liberados/:n/importado`), o pipeline também (`PATCH /compras/ordens/:id/sincronizacao`). |
| 11 | Nome da variável do MES | 🟡 | O `api-pcp` usa `AVHUB_MES_INTEGRACAO_KEY` (singular). A `api-acos-vital` lê `MES_INTEGRACAO_KEYS` (plural, lista). O PDF e as notas que dizem `...KEYS` no lado do MES estão errados. |
| 12 | Guards do `api-pcp` | 🟡 (Robert) | Adicionar `JwtAuthGuard` + `PermissionsGuard` com `@RequirePermission` em `UsuariosController` e `SetoresController`, como em `perfis.controller.ts`. `GET /setores` fica só com sessão e o login Azure não pode ser bloqueado. |
| 13 | Exposição da `api-pcp` | 🔴 (Gustavo) | Há domínio público no Coolify? O código escuta em todas as interfaces e não restringe origem. |
| 14 | PR #50 | 🟡 | Nenhum consumidor das rotas apagadas foi achado em `api-pcp`, `app-pcp`, pipeline e `api-acos-vital`. O front do av-hub não estava no disco. |
| 15 | `exclusionSync` | 🔴 (Gustavo) | **Risco crítico.** O job apaga `pedidos_vendas` por empresa e janela **sem filtrar `manual`**. Pedidos manuais têm `codigo_pedido_omie` negativo, não existem no Omie e entram na lista de excluídos (`exclusionSync.ts:98-106,136`). Confirmar antes de usar pedido manual em produção. |
| 16 | 500 em `exclusion_sync_curta` | 🔴 (Gustavo) | 497 erros em Mogi (490 HTTP 500). Causa não documentada. Ler `error_message` e `faultstring` em `omie_ctl.run_log`. |
| 17 | Pedido de compra apagado por fora | 🟡 (Nathan) | O `exclusionSync` não detecta. Aceito como limitação conhecida. |
| 18 | `omie_raw` e `sql/002` | 🟡 | Mortos. Marcar `sql/002` como obsoleto (Nathan). `DROP` das 5 tabelas vazias: Gustavo. |
| 19 | Manifesto (scraping) | 🟡 (Gustavo) | Não precisa de plano para Uberaba: o login de Mogi traz as duas empresas. Confirmar por consulta que `manifestos` tem linhas de Uberaba. HRM não está coberta. |
| 20 | `FAMILIA_PADRAO_POR_FILIAL` | ✅ | Corrigir a doc (`ARCHITECTURE.md` do pipeline, fora do vault) e registrar tarefa de código (Gustavo). |

## 3. Estoque e MES

| # | Assunto | Status | Registro |
|---|---|---|---|
| 21 | Schema do Estoque | ✅ | Fica em **`public`**. Fecha CC-06. |
| 22 | `main` do MES | ✅ | Merge `develop` → `main` **antes do piloto**. Fecha CC-04. Data e responsável: 🔴 Robert. |
| 23 | Branch `feat/migracao-nestjs-prisma` | ✅ | Descartada. Fecha CC-09. |
| 24 | Transferência entre filiais | ✅ | Quem envia **aprova na origem** e só então gera a NF. O número da NF chega ao MES **via av-hub**. |
| 25 | Carga inicial do estoque | ✅ | Dupla conferência = **contador + conferente**. Divergência = **terceira contagem**. Lote nasce liberado (DEC-4). |
| 26 | Tolerância de peso | ✅ | **5% para todas** as categorias. Pode virar por categoria no futuro. |
| 27 | Ciclo 2 | ✅ | Começa em **04/01/2027**. Entram EC-02 (sobras e perdas de matéria-prima), L-10 (sobras de chapa, perda no corte, unidade), remessa de produtos, Fase D e transferência etapas 2 a 4. |
| 28 | Saldo do Omie | ✅ | O Omie recebe dados **só manualmente**; o estoque do Omie é ignorado. Passo 2 (`ListarPosEstoque`) **não será feito**. O MES é a referência do saldo físico (fecha L-03). |
| 29 | Locais e `lead_time` (B6) | ✅ | B6 continua **só com os locais** (Passo 6). `lead_time` (Passo 3) sai do pipeline. |
| 30 | Financeiro | ✅ | O **Omie segue como sistema financeiro e fiscal** (DEC-11). Não há plano de desligar. Dados bancários e endereço de entrega de parceiro ficam fora; as tabelas existem e estão vazias. |
| 31 | Devolução e `valor_devolucao` | 🟡 | O `StatusDevolucaoVenda` não está disponível no Omie. Devolução é nativa do Estoque (DEC-10), Ciclo 2. As colunas `valor_devolucao` em produção estão vazias (limpeza: Gustavo). |

| 31b | Saldo zero: o item passa pelo Estoque sozinho ou exige clique? | 🔴 (Nathan / Robert) | O vault se contradiz. `Fluxo-Estoque-Completo` (EA6) e `Fluxo-Sistema-no-Meio` (L~415) dizem **automático**. `Encaixe-Estoque-Revenda-no-PCP` (seção 5, EN-01) diz que **exige clique**. Em `Perguntas-em-Aberto-Consolidadas`, o EN-01 aparece como respondido em 25/09 (L~38) e também como pendente (L~115). Como o Pablo foi para o Comercial, o dono é o Robert ou o Nathan. |
| 31c | Vínculo Fábrica ↔ Filial | ✅ | Já decidido na DEC-1: a filial vem do pedido (`codigo_empresa`), nunca da Fábrica. `Perguntas-Pendentes-MES-Estoque` ainda a lista como aberta e precisa ser corrigida. |

## 4. Equipe e cronograma

| # | Assunto | Status | Registro |
|---|---|---|---|
| 32 | Pablo | ✅ | Atua no **Comercial & Suprimentos**. O MES fica com o **Robert**. |
| 33 | Tarefas do MES | ✅ | **Robert assume** G1 (carga em lote), baixa no despacho do Estoque, D11 (leitor 2D e posto de recebimento) e I1/J2/J5. A capacidade dele estoura e precisa ser recalculada (ver [[Cronograma-2-Meses]]). |
| 33b | Capacidade do Robert depois da reatribuição | 🔴 (Nathan) | Com G1, D11, I1, J2, J5 (e D12, atribuída por coerência) no Robert, o cálculo do [[Cronograma-2-Meses]] (seção 3.2) fecha em **−5,85 pd na S1–FC e −4,25 pd na S5, −10,1 pd no total**. A ordem de corte da seção 9 alivia no máximo ~4,0 pd. A baixa no despacho do Estoque não tem pd dimensionado, então o déficit real é maior. Falta decidir como cobrir: estender a janela, levar a J5 ao Ciclo 2 ou devolver parte do backend ao Gustavo. Os resíduos de D2 e D3 ficaram sem dono. A reserva real da S5 é **21,0 pd** (não 22,0), e **3,75 pd** depois da reatribuição. |
| 34 | Plano | 🟡 | Vale o plano de **3 meses** (18/09 a 21/12). M7 e S5 terminam em 18/12; 21/12 só fecha a conta de capacidade. |
| 35 | Déficit de 1,8 pd do Nathan na S5 | 🟡 (Nathan) | 11,0 pd (I5 4 + I6 7) contra 9,2 pd (23 dias úteis × 40%). Proposta: tirar a tela de ranking de gargalos da S5 e levar ao Ciclo 2 (a numeração T.5 ou T.6 precisa ser conferida em [[Fluxograma-Telas-por-Bloco]]: o agente de edição viu "tempo por etapa e ranking" em T.5 e Auditoria em T.6). Como o Pablo está no Comercial, não há quem receba essas horas. |
| 36 | Datas de marcos | 🟡 (Nathan) | M2 cumprido. M3 (16/10) mantido. M4 (30/10) só antecipa se a homologação estiver estável até 16/10. M5, M6 e M7 mantidos. |
| 37 | Equipe | 🟡 | Robert Wilson, Pablo Cruz e Gustavo M. de Farias (pelo `git log`; cargo formal de RH não está no vault). |
| 38 | Tarefas B6, G3, D1 | 🟡 | G3 deixa de reconciliar com o saldo do Omie. D1 deixa de dizer "a confirmar com o Robert". |

## 5. Compras, CCP e contratos

| # | Assunto | Status | Registro |
|---|---|---|---|
| 39 | Orçamento (contratos 07 e 38) | ✅ | Desenvolvido **por fora**, no módulo Comercial & Suprimentos. A API entregue (`90bdb33`) existe. Os contratos 07 e 38 precisam ser reescritos. |
| 40 | Contrato 13 | ✅ | Desconsiderado. |
| 41 | Contrato 004-API | 🔴 (Gustavo) | `GET /ordens-compra/referencia` não existe em nenhum dos lados. O registro manual (`PATCH /compras/requisicoes/:id/compra`) segue valendo. |
| 42 | Contrato 005 | 🔴 (Nathan) | Aceite das 3 diferenças, aprovadas pelo Robert em 30/09. Recomendação do MES (texto enviado pelo Nathan): **aceitar as 3**, porque nenhuma impede o que o av-hub mostra ao vendedor. (1) **Foto atual em vez de log:** a rota devolve o estado atual de cada parcial alterada desde a última leitura, que é o que o MES guarda no `ItemParcial`. Se a parcial passar por duas etapas entre duas leituras, o av-hub só vê a última; com leitura a cada 1 ou 2 minutos isso quase não acontece. O histórico completo existe no MES (`HistoricoItemParcial`) e pode virar feed de eventos na S5. (2) **`pedido_venda` + `ordem_producao` em vez do uuid:** o MES não conhece o uuid do pedido no av-hub; o pedido é identificado por `codigo_empresa` + `pedido_venda`, a mesma chave de `/pedidos_liberados`. O `codigo_pedido_omie` entra depois. (3) **Etapas a mais e a menos:** o MES manda `estoque.atendimento`, `expedicao.embalagem` e `expedicao.concluido`, e não manda `recebimento.pesagem`, `estoque.reservado` e `pcp.retorno`, porque não existem como setor. O vocabulário é provisório e a resposta traz setor e status crus, então o av-hub não deve travar a lista no código. **Aguardando a confirmação "Aceito as 3".** |
| 43 | Consumidor do 005 | 🟡 (Gustavo) | Roda na `api-acos-vital` (F2, 19 a 30/10), com tabela local do status por item. |
| 44 | IM-02 (pedido sem prazo) | 🟡 | Resolvida pelo código: o MES cai para `pedido.prazoEntrega` e recusa se ainda não houver prazo. |
| 45 | IM-01 e IM-03 antigo | 🟡 | Superados pelo contrato 34. |
| 46 | PTAX | 🟡 | É a cotação de **venda** (a API recusa OC com cotação diferente de `cotacao_venda`). |
| 47 | IPI e ICMS-ST no PDF da OC | ✅ | **Não incluir.** O Omie é o fiscal; o PDF já avisa quando o total não bate. |
| 48 | CCP (contrato 32) | 🟡 | P2: só OC criada no av-hub. P6: transportadora em texto livre. P3: 2 dias úteis como padrão, em `parametros_compras`. P4 e P5: 🔴 Nathan. P1: 🔴 Gustavo. |
| 49 | Dashboards por unidade (contrato 33) | 🟡 | P4 (lotação do RH) e P5 (histórico muda se o RH transferir) ficam como estão implementados. P1, P2, P3, P6 e P7: 🔴 Nathan. |
| 50 | Aprovador de OC | ✅ | O aprovador é o **Gerente de Compras** (perfil Gerência de Compras, `pode_aprovar` em `compras`, `aprovacoes` e `followup`). O perfil existe e tem 0 usuários no dump de 07/10: falta vincular a pessoa. |
| 50b | Aprovador acima de R$ 30.000 e de vagas | 🔴 (Nathan) | A DEC-3 diz que acima de R$ 30.000 quem aprova é o **diretor**. Falta confirmar se o Gerente de Compras passa a aprovar todos os valores ou se o diretor continua acima do limite. O aprovador de vagas (`solicitacoes-de-vagas`) continua sem nome. |
| 51 | Compradores | 🟡 | Mecanismo existe (tela de Compras, Cadastros, Acessos). Já há **20 de 74** vinculados (carga de 07/10); só importam os **32 ativos**. Vincular antes da primeira OC real. |
| 52 | BENAFER e etapas 10/15/20 | 🔴 (Nathan) | Pedidos 44333 e 44568 (R$ 82,7 mi) a conferir no Omie. Nome das etapas 10, 15 e 20: olhar um pedido de cada no Omie. |
| 53 | Retenção de logs | ✅ | `auth.logs` com prazo curto, `auth.auditoria` com 5 anos. Prazo do `auth.logs`: 🔴 Gustavo. |

## 6. Nomes e documentação

| # | Assunto | Status | Registro |
|---|---|---|---|
| 54 | Nomes MES e PCP | ✅ | Ficam como estão. O "Portal PCP" do av-hub é acompanhamento comercial, não é o `app-pcp`. |
| 55 | Hashes de branches locais | 🟡 | `f4380d7`, `8eb5dce`, `cba68fa`, `c2b68a9` e `1b6fe6e` foram re-autorados a partir de patches. Ficam só como nota histórica de uma linha. |
| 56 | Contratos com número duplicado | 🟡 | Os arquivos **não são renomeados**. Há 04, 07, 09, 13, 14 e 19 duplicados e 20, 21, 22, 24, 25 e 27 sumiram. A tabela de equivalência fica em [[Indice-Contratos]]. |
| 57 | Convenção de status | 🟡 | Nota alterada ganha o cabeçalho `Status: decidido \| no código \| em produção (verificado em data)`. |
| 58 | Nomes das telas do PCP no início do fluxo | ✅ (nome) / 🟡 (código) | **Triagem do Pedido** = antiga Carteira de Pedidos (lista os pedidos liberados). **Destinação do Pedido** = tela que abre ao clicar no pedido (antiga "Ordem de Produção"), onde se define o destino e a quantidade de cada item. Nomes escolhidos em 08/10/2026. "Ordem de Produção" fica só para a ordem emitida ao que vai ser fabricado (entidade que ainda não existe no código). **No código as telas seguem com os nomes antigos** (`/carteira`, `/ordens-producao/novo`, `ordemProducao`, `OP-`); o rótulo e a eventual entidade nova dependem do Robert. Ver [[Glossario]]. |
| 59 | PCP legado × MES: 29 lacunas e a Caldeiraria HRM | ✅ escopo (Nathan, 08/10) / 🟡 estimativas / 🔴 pontos abertos | O Nathan **aprovou os 29 itens** do levantamento do Robert ([[PCP-Legado-x-MES-Lacunas]]) e o recálculo **estendendo a data**. Itens 28 e 29 vão para o **av-hub** (sem dono). A **Caldeiraria HRM** entra como mais uma fábrica `FABRICACAO` dentro dos setores produtivos do roteiro. O recálculo ([[Cronograma-2-Meses]], seção 3.3) usa estimativas **minhas** (141 pd no MES, 12 no av-hub): com o Robert sozinho a 75%, o MES passa de 18/12/2026 para cerca de **08/10/2027**. O Robert valida as estimativas. Seguem 🔴: destino × filial da Caldeiraria, componente repetido no pedido, campos dos itens 18 a 20 e congelar o sistema atual durante a migração. |
| 60 | Volta da integração av-hub ↔ MES: contratos 004 e 005, L6 e tela 1.2 | 🔴 (Gustavo e Nathan) / 🟡 (Claude) | Plano em [[Integracao-AvHub-MES-Volta-Plano]]. **Nathan:** aceitar as 3 diferenças do 005 (recomendado aceitar). **Gustavo:** aplicar o SQL [[010-Itens-Pedido-Status]], construir o job e a rota do [[006-Status-por-Item-Leitura-no-Hub]], criar `GET /ordens-compra/referencia` (004) e decidir a chave L6 (opções A, B, C no plano). **Feito:** cartão "Etapa dos itens" na página do pedido, em branch `claude/etapa-dos-itens` do av-hub (`48698105`), **sem merge**; mostra "não disponível" até o hub ter a rota. |

## 7. Achados da revisão final (07/10/2026)

> Itens que surgiram depois das edições. Nenhum foi decidido pelo Nathan.

| # | Assunto | Status | Registro |
|---|---|---|---|
| 58 | Contagem de `GAMBIARRA(` | 🔴 (Nathan / dono do front) | Três valores no vault: 14 (`AV-Hub-Bugs-Catalogo`, conferido em 07/10), 24 (índice antigo) e 57 (nota de contrato). O código do av-hub não estava no disco. Recontar no front e manter um valor só. |
| 59 | Contrato 009: 53 contra 311 | 🔴 (Gustavo) | A nota diz 53 registros em `/vendas_planilha`; o dump de 07/10 mostra 311 linhas em `produto_vendas`. O total em R$ bate e nada explica a diferença. |
| 60 | Contrato 38 | 🔴 (Nathan) | Está em `Realizados`, mas foi declarado a reescrever junto com o 07 (orçamento por fora). O §6 ainda diz que `SYNC_ENVIO_OC` e `ENVIO_OC_DRY_RUN` ficam de propósito; a decisão 7 os remove. |
| 61 | Dois contratos 13 | 🟡 | `13-Fornecedores-por-Produto` está **desconsiderado** (item 40). `13-Compras-Backend-Consolidado` é outro contrato, entregue, e foi editado. O item 40 vale só para o primeiro. |
| 62 | `protectedColumns.ts` | 🔴 (Gustavo) | No repositório do pipeline (fora do vault) ainda diz que o dono de `vendedores` é "pendente" e que `comissao` pode vir de outro sistema. O vault já nomeia os donos. |
| 63 | Passo 6 (locais) | 🟡 (Gustavo) | Decidido, mas o pipeline não tem recurso para ele. É trabalho a fazer (B6), não erro de documentação. |
| 64 | Data do C6 | 🟡 | O Nathan indicou 25/09; `Onde-Estamos` diz "confirmada no código em 28/09". As duas datas ficaram escritas. |
| 65 | `Perguntas-Pendentes-MES-Estoque` | 🟡 | Ainda lista o vínculo Fábrica↔Filial como aberto, contra a DEC-1 (item 31c). **Correção não aplicada.** |
| 66 | `Fluxo-Compras-Completo` | 🟡 | Os textos C0, C3 e C9 ainda descrevem o desenho antigo (de 24/09). Só C1 e a tabela de atores foram corrigidos. |
| 67 | `Auditoria-Dump-Producao-2026-10-07`, linha 72 | 🟡 | Diz "sem recurso na pipeline" para saldo e locais. É retrato de 07/10, não foi editada; vale a nota de atualização. |
| 68 | Cabeçalho `Status:` | 🟡 | Aplicado na maioria das notas editadas, mas não em `01-Fluxo-Operacional`. |
| 69 | Prefixos do glossário | 🟡 (Nathan) | Os significados de EC, IM, CA, T e L foram inferidos do uso nas notas, sem definição formal. |
| 70 | Diagramas mermaid | 🟡 | Redesenhados por agentes e **não renderizados**. Abrir no Obsidian e conferir. |
| 71 | `SYNC_ENVIO_OC` e `ENVIO_OC_DRY_RUN` | 🟡 | Ainda aparecem 23 vezes em 14 notas. Pela amostra são notas históricas, mas nem todas foram revisadas. |
| 72 | Links | 🟡 | Um alvo suspeito entre todos os wikilinks ("FORA DO SISTEMA - telefone, e-mail, WhatsApp" em `Fluxo-Sistema-no-Meio`), provavelmente nó de diagrama. Não confirmado. |
| 73 | Reserva da S5 | 🟡 | Corrigida para **21,0 pd** (a tabela dizia 22,0). Com as tarefas no Robert fica em **3,75 pd** (item 33b). |

## Estado no código em 08/10/2026 das decisões que mexem em código

Conferido na `develop` (`api-acos-vital` `0557871`, `api-pcp` `ca3346b`, `app-pcp` `2ea3183`, `av-hub` `bd1ae48`) e no `master` da pipeline (`d2886bf`). Só leitura de código; produção não conferida.

| # | Decisão | No código hoje |
|---|---|---|
| 7 | Envio da OC fixo, sem `SYNC_ENVIO_OC` nem `ENVIO_OC_DRY_RUN` | ✅ **Feito e mergeado** na `master` da pipeline (PR #3, `0f739f0`, 08/10). O worker passa a enviar de verdade quando for publicado; falta o deploy da API com o contrato 36 e os compradores vinculados. |
| 8 | `PERMISSOES_ROTA_MODO` fixo em `exigir` | ✅ **Feito** em 08/10/2026 (`6317d5f`, #283): a variável não é mais lida e o segredo `USUARIO_TOKEN_SEGREDO` é sempre obrigatório. Antes, em 07/10, o padrão tinha virado `exigir` (`0557871`) com a variável ainda lida. |
| 9 | Fixar `ESCOPO_VENDEDORES_EXIGIR` | ❌ Não feito: continua lida do ambiente, padrão `false`. As outras quatro chaves seguem como chave, como decidido. |
| 11 | Nome da variável do MES | ✅ Confere: o `api-pcp` lê `AVHUB_MES_INTEGRACAO_KEY` (singular); a API lê `MES_INTEGRACAO_KEYS`. |
| 12 | Guards em `UsuariosController` e `SetoresController` | ❌ Não feito: só `PATCH usuarios/:id/senha` e `GET setores/:id/painel` têm `JwtAuthGuard`. |
| 15 | `exclusionSync` apaga pedido manual | ⚠️ **Risco confirmado.** A consulta (`exclusionSync.ts`) filtra só empresa, `deleted_at` e janela; o pedido manual (código negativo, `POST /pedidos_vendas/manual`, contrato 30) não existe no Omie e entra na lista de apagados. |
| 26 | Tolerância de peso 5% | ✅ `Material.toleranciaPeso` tem `@default(0.05)`. |
| 25 | Carga inicial: lote nasce liberado | ✅ `origem: 'CARGA_INICIAL'`, `statusQualidade: 'LIBERADO'`. |
| 41 | `GET /ordens-compra/referencia` (004) | ❌ Não existe em `api-acos-vital` nem no `api-pcp`. |
| 43 | Consumidor do `/itens/status` (005) | ❌ Nenhum consumidor em `api-acos-vital` nem no av-hub; a rota existe no MES. |
| 44 | IM-02: pedido sem prazo | ✅ `prazo_necessidade = prazoNecessidade ?? pedido.prazoEntrega`, e recusa sem prazo. |
| 46 | PTAX é a cotação de venda | ✅ A API recusa OC cuja cotação difere de `cotacao_venda`. |
| 22 | `main` do MES | ❌ Merge `develop` → `main` ainda não feito: `main` do `api-pcp` em `be076b2` e do `app-pcp` em `be847ac` (ambas 27–28/08). |
