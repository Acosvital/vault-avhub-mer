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
| 8 | `PERMISSOES_ROTA_MODO` | ✅ | Fixo em **`exigir`** no código, sem `.env`. **Implementado em 08/10** (`6317d5f`, `acessoConfig.js`: a variável deixou de ser lida). As chamadas de serviço do pipeline e do MES (só `x-api-key`, sem `Bearer`) passam sem mapeamento, porque o modo só confere permissão quando há token. |
| 9 | Chaves restantes do contrato 38 | 🟡 (Gustavo) | O Nathan confirmou que o front do av-hub manda token em todas as chamadas, mas **a auditoria de 08/10 mostra o contrário**: ao menos 38 arquivos do BFF (`compras/*`, `pedidos-venda/[fonte]/**`, `notas-fiscais/[fonte]/**`) mandam só `x-api-key` (ver [[Auditoria-Pente-Fino-2026-10-08]]). Os helpers precisam usar `headersComIdentidade()` antes de fixar a chave. Fixar **só `ESCOPO_VENDEDORES_EXIGIR`**. `IDENTIDADE_EXIGIR_TOKEN`, `ESCOPO_UNIDADE_EXIGIR_SESSAO` e `AUTENTICACAO_AZURE_VALIDAR_ID_TOKEN` quebram MES e pipeline enquanto eles usarem a chave do `.env` sem token, e `VENDAS_PLANILHA_PAGINAR_POR_PEDIDO` corta dados no front. Ficam como chave até separar as chaves de serviço. |
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

| 31b | Saldo zero: o item passa pelo Estoque sozinho ou exige clique? | ✅ (Nathan, 08/10) | **Exige clique.** O parcial sem saldo não passa sozinho pelo Estoque: alguém confirma na tela. Fecha o EN-01 de [[Encaixe-Estoque-Revenda-no-PCP]]. As notas que sugeriam "automático" ([[Fluxo-Estoque-Completo]] EA6 e [[Fluxo-Sistema-no-Meio]]) foram corrigidas em 08/10. Antes do marco zero (13/11) todo parcial segue tratado como saldo zero. |
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
| 41 | Contrato 004-API | ✅ hub / 🔴 MES (Robert) | **(09/10)** O Nathan informou que o DBA implementou. Conferido: `GET /ordens-compra/referencia` existe na `api-acos-vital` (`fe55923`, 08/10, PR #284). Depende da migration `api004` no banco (não verificada). **O `api-pcp` ainda não lê a rota**, então o registro manual (`PATCH /compras/requisicoes/:id/compra`) segue valendo. O MES deve usar uma chave de leitura, não a chave do contrato 34 (403). |
| 42 | Contrato 005 | ✅ (Nathan, 08/10) | Aceite das 3 diferenças, aprovadas pelo Robert em 30/09. Recomendação do MES (texto enviado pelo Nathan): **aceitar as 3**, porque nenhuma impede o que o av-hub mostra ao vendedor. (1) **Foto atual em vez de log:** a rota devolve o estado atual de cada parcial alterada desde a última leitura, que é o que o MES guarda no `ItemParcial`. Se a parcial passar por duas etapas entre duas leituras, o av-hub só vê a última; com leitura a cada 1 ou 2 minutos isso quase não acontece. O histórico completo existe no MES (`HistoricoItemParcial`) e pode virar feed de eventos na S5. (2) **`pedido_venda` + `ordem_producao` em vez do uuid:** o MES não conhece o uuid do pedido no av-hub; o pedido é identificado por `codigo_empresa` + `pedido_venda`, a mesma chave de `/pedidos_liberados`. O `codigo_pedido_omie` entra depois. (3) **Etapas a mais e a menos:** o MES manda `estoque.atendimento`, `expedicao.embalagem` e `expedicao.concluido`, e não manda `recebimento.pesagem`, `estoque.reservado` e `pcp.retorno`, porque não existem como setor. O vocabulário é provisório e a resposta traz setor e status crus, então o av-hub não deve travar a lista no código. **Aceito pelo Nathan em 08/10/2026 ("aceito os três").** **✅ Nathan aceitou as 3 diferenças em 08/10/2026.** Falta só construir o consumidor (itens 43, SQL 010, API 006). |
| 43 | Consumidor do 005 | ✅ no código (Gustavo) | **(09/10)** Implementado em `dee35b0` (08/10): job no processo da `api-acos-vital` a cada 90 s, por unidade, com migration `api005` (não verificada no banco). Aceite das 3 diferenças: ✅ Nathan, 08/10 (#42). O código cita um contrato 006 que não está no vault. |
| 44 | IM-02 (pedido sem prazo) | 🟡 | Resolvida pelo código: o MES cai para `pedido.prazoEntrega` e recusa se ainda não houver prazo. |
| 45 | IM-01 e IM-03 antigo | 🟡 | Superados pelo contrato 34. |
| 46 | PTAX | 🟡 | É a cotação de **venda**. A API não recusa OC com outra cotação: **reclassifica a origem para `manual`** e zera `cotacao_data` (`ordens_compra.route.js:964-977`, conferido em 08/10). |
| 47 | IPI e ICMS-ST no PDF da OC | ✅ | **Não incluir.** O Omie é o fiscal; o PDF já avisa quando o total não bate. |
| 48 | CCP (contrato 32) | 🟡 | P2: só OC criada no av-hub. P6: transportadora em texto livre. P3: 2 dias úteis como padrão, em `parametros_compras`. P4 e P5: 🔴 Nathan. P1: 🔴 Gustavo. **08/10 (Nathan): P5 ✅ — criar um perfil CCP, que trata os "Follow-ups".** |
| 49 | Dashboards por unidade (contrato 33) | 🟡 | P4 (lotação do RH) e P5 (histórico muda se o RH transferir) ficam como estão implementados. P1, P2, P3, P6 e P7: 🔴 Nathan. **08/10 (Nathan):** P1 fica a cargo dele e dos trabalhadores (uso da tela, não é decisão de projeto); P2 ✅ o "- Dev" **não entra** nos dashboards, e deve existir uma marca que identifique quem tem "- Dev" como desenvolvedor; P3 (comissões por unidade) ✅ "no futuro"; P6 ✅ `inativo_desde` = **último mês de venda**; P7 ✅ as telas `fn_painel_*` passam a **filtrar por unidade do vendedor** (gera trabalho de backend e contrato). |
| 50 | Aprovador de OC | ✅ | O aprovador é o **Gerente de Compras** (perfil Gerência de Compras, `pode_aprovar` em `compras`, `aprovacoes` e `followup`). O perfil existe e tem 0 usuários no dump de 07/10: falta vincular a pessoa. |
| 50b | Aprovador acima de R$ 30.000 e de vagas | 🟡 (Nathan, 08/10) | **Gerente de Compras aprova** (Nathan, 08/10). A DEC-3 (diretor acima de R$ 30.000) precisa ser reconciliada com essa resposta: confirmar se vale para todos os valores. O aprovador de vagas (`solicitacoes-de-vagas`) **continua sem nome**. |
| 51 | Compradores | 🟡 | Mecanismo existe (tela de Compras, Cadastros, Acessos). Já há **20 de 74** vinculados (carga de 07/10); só importam os **32 ativos**. Vincular antes da primeira OC real. **08/10 (Nathan):** ele vincula só o que pode; quem não pode ser vinculado fica fora (regra de negócio dele, não é pendência de sistema). |
| 52 | BENAFER e etapas 10/15/20 | 🔴 (Nathan) | Pedidos 44333 e 44568 (R$ 82,7 mi) a conferir no Omie. Nome das etapas 10, 15 e 20: olhar um pedido de cada no Omie. **08/10 (Nathan): adiado ("depois irei ver").** |
| 53 | Retenção de logs | ✅ | `auth.logs` com prazo curto, `auth.auditoria` com 5 anos. Prazo do `auth.logs`: 🔴 Gustavo. |

## 6. Nomes e documentação

| # | Assunto | Status | Registro |
|---|---|---|---|
| 54 | Nomes MES e PCP | ✅ | Ficam como estão. O "Portal PCP" do av-hub é acompanhamento comercial, não é o `app-pcp`. |
| 55 | Hashes de branches locais | 🟡 | `f4380d7`, `8eb5dce`, `cba68fa`, `c2b68a9` e `1b6fe6e` foram re-autorados a partir de patches. Ficam só como nota histórica de uma linha. |
| 56 | Contratos com número duplicado | 🟡 | Os arquivos **não são renomeados**. Há 04, 07, 09, 13, 14 e 19 duplicados e 20, 21, 22, 24, 25 e 27 sumiram. A tabela de equivalência fica em [[Indice-Contratos]]. |
| 57 | Convenção de status | 🟡 | Nota alterada ganha o cabeçalho `Status: decidido \| no código \| em produção (verificado em data)`. |
| 74 | Nomes das telas do PCP no início do fluxo | ✅ (nome) / 🟡 (código) | **Triagem do Pedido** = antiga Carteira de Pedidos (lista os pedidos liberados). **Destinação do Pedido** = tela que abre ao clicar no pedido (antiga "Ordem de Produção"), onde se define o destino e a quantidade de cada item. Nomes escolhidos em 08/10/2026. "Ordem de Produção" fica só para a ordem emitida ao que vai ser fabricado (entidade que ainda não existe no código). **No código as telas seguem com os nomes antigos** (`/carteira`, `/ordens-producao/novo`, `ordemProducao`, `OP-`); o rótulo e a eventual entidade nova dependem do Robert. Ver [[Glossario]]. |
| 75 | PCP legado × MES: 29 lacunas e a Caldeiraria HRM | ✅ escopo (Nathan, 08/10) / 🟡 estimativas / 🔴 pontos abertos | O Nathan **aprovou os 29 itens** do levantamento do Robert ([[PCP-Legado-x-MES-Lacunas]]) e o recálculo **estendendo a data**. Itens 28 e 29 vão para o **av-hub** (sem dono). A **Caldeiraria HRM** entra como mais uma fábrica `FABRICACAO` dentro dos setores produtivos do roteiro. O recálculo ([[Cronograma-2-Meses]], seção 3.3) usa estimativas **minhas** (141 pd no MES, 12 no av-hub): com o Robert sozinho a 75%, o MES passa de 18/12/2026 para cerca de **08/10/2027**. O Robert valida as estimativas. Respostas do Robert em 08/10 (item 78): destino × filial como a Flange (🟡), componente repetido soma (🟡), itens 18 e 20 sem regra conhecida (🔴 Nathan), congelar o sistema atual **não é possível**. |
| 76 | Volta da integração av-hub ↔ MES: contratos 004 e 005, L6 e tela 1.2 | 🔴 (Gustavo) / ✅ aceite do 005 (Nathan, 08/10) / 🟡 (Claude) | Plano em [[Integracao-AvHub-MES-Volta-Plano]]. **Nathan:** ✅ aceitou as 3 diferenças do 005 em 08/10. **Gustavo:** aplicar o SQL [[010-Itens-Pedido-Status]], construir o job e a rota do [[006-Status-por-Item-Leitura-no-Hub]], criar `GET /ordens-compra/referencia` (004) e decidir a chave L6 (opções A, B, C no plano). **Feito:** cartão "Etapa dos itens" na página do pedido, em branch `claude/etapa-dos-itens` do av-hub (`48698105`), **sem merge**; mostra "não disponível" até o hub ter a rota. |
| 77 | Respostas do Nathan de 08/10/2026 | ✅ (Nathan) | Registradas nos itens que tocam: **42** (aceita as 3 do contrato 005), **31b** (saldo zero exige clique), **50b** (Gerente de Compras aprova), **48** (perfil CCP para os Follow-ups), **49** (dashboards: P2, P3, P6, P7), **51** (vincula só o que pode), **52** (adiado), **60** e **71** (envio da OC fixo), **69** (prefixos confirmados). Também: **data do MES ~08/10/2027 aceita** (item 75; estimativas ainda a validar pelo Robert); **CA-01** o Omie não tem estoque (só uma coluna numa tabela), o estoque real fica no nosso sistema; **CA-02** manter "só setor Vendas" (vira filtro no backend); **GAMBIARRA:** levantar todas as marcas, remover e criar contrato para cada uma. **Sem resposta:** os 4 pontos do PCP legado (destino × filial da Caldeiraria, componente repetido, rastreabilidade/hold points/Book, congelar o sistema atual), dono dos itens 28 e 29, Torre de Fluxo (item 35) e quem reescreve os contratos 07 e 38. |
| 78 | Respostas do Robert de 08/10/2026 | ✅ (saldo zero, nomes) / 🟡 (Caldeiraria) / 🔴 (regras de negócio) | **Saldo zero:** confirma o item 31b, que já estava definido: sempre exige alguém movimentando. **Matéria-prima (ponto novo):** produto de fabricação precisa de matéria-prima, "não dá para produzir do nada". Ao consultar o estoque de um item de fabricação, o sistema busca **primeiro o produto pronto** e **depois a matéria-prima livre**, porque não existe a amarração "este produto consome esta matéria-prima" ([[Fluxo-Estoque-Completo]], EA2). 🟡 Decisão de modelo do Robert; Nathan valida, e a consulta de MP hoje está na J3. **Nomes das telas:** só o título muda: o antigo "criar ordem de produção" vira **Destinação do Pedido** e "Ordens de Produção" vira **Triagem dos Pedidos**, porque "Ordens de Produção" não serve à Revenda (confere com o item 74). **Caldeiraria e plano:** ver [[PCP-Legado-x-MES-Lacunas]]; destino × filial como a Flange, componentes iguais somam, regras dos itens 18 e 20 desconhecidas, poucos setores usados no item 19, congelar o legado impossível, baixa no despacho sem estimativa. |

## 7. Achados da revisão final (07/10/2026)

> Itens que surgiram depois das edições. Nenhum foi decidido pelo Nathan.

| # | Assunto | Status | Registro |
|---|---|---|---|
| 58 | Contagem de `GAMBIARRA(` | 🟡 (Nathan) | Recontada no front (`Desktop\TI\NATHAN\00 - HUB`, branch `fix/gambiarras-bff`, `grep -rn "GAMBIARRA(" app components lib services utils hooks`, 07/10): **12 marcas em código** (4 de escopo/permissão em `lib/api/{portalPcp,pedidosVenda,liberacaoPedidos}.ts` e `app/api/liberar-pedidos/.../route.ts`; `nextauth/route.ts`; `loginRateLimiter.ts`; `fotos.ts`; 4 de orçamento/coordenadores; `utils/etapasFluxo.ts`). Os valores 14, 24 e 57 das notas antigas ficam como histórico. Com a remoção do código morto do contrato 43 (item 75), ficam **11** na árvore de trabalho (sem commit). A marca de `organogramaNodes.ts` já saiu na árvore de trabalho (não commitada). |
| 59 | Contrato 009: 53 contra 311 | 🔴 (Gustavo) | A nota diz 53 registros em `/vendas_planilha`; o dump de 07/10 mostra 311 linhas em `produto_vendas`. O total em R$ bate e nada explica a diferença. |
| 60 | Contrato 38 | 🔴 (Nathan) | Está em `Realizados`, mas foi declarado a reescrever junto com o 07 (orçamento por fora). O §6 ainda diz que `SYNC_ENVIO_OC` e `ENVIO_OC_DRY_RUN` ficam de propósito; a decisão 7 os remove. **08/10 (Nathan):** `SYNC_ENVIO_OC` e `ENVIO_OC_DRY_RUN` devem sair (já saíram da pipeline); resta reescrever o §6 do contrato 38. Quem reescreve segue indefinido. |
| 61 | Dois contratos 13 | 🟡 | `13-Fornecedores-por-Produto` está **desconsiderado** (item 40). `13-Compras-Backend-Consolidado` é outro contrato, entregue, e foi editado. O item 40 vale só para o primeiro. |
| 62 | `protectedColumns.ts` | 🔴 (Gustavo) | No repositório do pipeline (fora do vault) ainda diz que o dono de `vendedores` é "pendente" e que `comissao` pode vir de outro sistema. O vault já nomeia os donos. |
| 63 | Passo 6 (locais) | 🟡 (Gustavo) | Decidido, mas o pipeline não tem recurso para ele. É trabalho a fazer (B6), não erro de documentação. |
| 64 | Data do C6 | 🟡 | O Nathan indicou 25/09; `Onde-Estamos` diz "confirmada no código em 28/09". As duas datas ficaram escritas. |
| 65 | `Perguntas-Pendentes-MES-Estoque` | 🟡 | Ainda lista o vínculo Fábrica↔Filial como aberto, contra a DEC-1 (item 31c). **✅ Corrigido em 08/10.** |
| 66 | `Fluxo-Compras-Completo` | 🟡 | Os textos C0, C3 e C9 ainda descrevem o desenho antigo (de 24/09). Só C1 e a tabela de atores foram corrigidos. **✅ C0, C3 e C9 corrigidos em 08/10.** |
| 67 | `Auditoria-Dump-Producao-2026-10-07`, linha 72 | 🟡 | Diz "sem recurso na pipeline" para saldo e locais. É retrato de 07/10, não foi editada; **✅ Nota de atualização incluída em 08/10.** |
| 68 | Cabeçalho `Status:` | 🟡 | Aplicado na maioria das notas editadas. **✅ `01-Fluxo-Operacional` completo em 08/10.** |
| 69 | Prefixos do glossário | 🟡 (Nathan) | Os significados de EC, IM, CA, T e L foram inferidos do uso nas notas, sem definição formal. **✅ Confirmados por Nathan em 08/10:** EC, IM, CC, CA, T, L (e DEC). |
| 70 | Diagramas mermaid | ✅ | **Validados em 08/10** com o Mermaid 11.4 (o que o Obsidian atual usa): todos os blocos de todas as notas passam. Cinco `classDiagram` de `Diagramas-UML` só dão erro no Mermaid 10.9 (não conhece `classDef` em diagrama de classes). Também em 08/10: títulos de bloco "1. Vendas" viraram "1 - Vendas" (o Mermaid 11 lia "N. " como lista e mostrava "Unsupported markdown: list") e o Estoque e a Qualidade de `Fluxo-Sistema-no-Meio` foram divididos em dois blocos cada. `Fluxogramas-Completos` e `Fluxograma-Telas-por-Bloco` já tinham blocos de 5 nós ou menos e ficaram como estavam. |
| 71 | `SYNC_ENVIO_OC` e `ENVIO_OC_DRY_RUN` | ✅ | As 14 notas foram revisadas em 08/10: as que sobraram são decisão ou histórico, e as três que pareciam descrever o estado atual (contrato 38, auditoria do dump, nota da pipeline) ganharam a data de remoção. |
| 72 | Links | ✅ | Conferidos em 08/10: nenhum wikilink quebrado. O "alvo suspeito" é um nó de diagrama Mermaid (`[["..."]]`, sintaxe de sub-rotina), não um link. |
| 73 | Reserva da S5 | 🟡 | Corrigida para **21,0 pd** (a tabela dizia 22,0). Com as tarefas no Robert fica em **3,75 pd** (item 33b). |
| 79 | Contratos 40 a 44 (marcas `GAMBIARRA(` restantes) | 🟡 (propostas, sem execução) | [[40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]] (escrito em 07/10; a API **já** aplica o escopo pelo token, desligado; ligar `ESCOPO_VENDEDORES_EXIGIR` fixo no código é do Gustavo e **vem antes** de o front tirar o escopo do BFF; Q1 a Q5 abertas), [[41-Login-Rate-Limit-no-Backend]] (Gustavo; Q1 a Q5 abertas; o front só remove o limiter **depois** da API ligada), [[42-Coordenadores-e-Orcamento-sair-do-JSON-do-Repositorio]] (coordenadores voltam ao escopo; orçamento sai com o módulo Comercial & Suprimentos), [[43-Ordem-das-Etapas-de-Faturamento-no-Cadastro]] (seed de `ordem_fluxo` no DBA, `protectedColumns.ts` no pipeline) e [[44-Upload-de-Fotos-Politica-de-Bucket]] (baixa prioridade; a checagem de bytes do BFF **fica**, é defesa legítima; reclassificar a marca: 🔴 Nathan). O contrato 40 não existia: foi escrito em 07/10 a pedido do Nathan, com o escopo de vendedores e permissões (a numeração vinha de um resumo anterior, sem arquivo). |
| 80 | Ponteiros e código morto no front | 🟡 | Em 07/10 as marcas de `loginRateLimiter.ts` (41), `lib/orcamento/dados.ts` (2), `lib/comissoes/coordenadores.ts` e `dash-comissoes/page.tsx` (42) e `lib/s3/fotos.ts` (44) passaram a apontar para o vault (só o caminho mudou; nada foi removido nem reclassificado; **sem commit**). As 5 marcas de escopo e permissões (`portalPcp.ts`, `pedidosVenda.ts`, `liberacaoPedidos.ts`, `liberar-pedidos/.../route.ts` e `nextauth/route.ts`) passaram a apontar para o contrato 40, **sem remover nada**: remover antes de a API aplicar o escopo pelo token abre um furo de acesso e depende do Gustavo. Código morto do 43 (`utils/etapasFluxo.ts` e `services/portalGerente/etapasEmpresa.ts`, sem nenhum chamador ou import no front): ✅ **apagados em 07/10** com autorização do Nathan; `tsc --noEmit` sem erros (excluindo `scratch/`, ignorado pelo git). Sem commit. O seed de `ordem_fluxo` (DBA) segue pendente, mas não bloqueia: o detalhe do pedido já usava `pedido.etapas` da API. |

## 8. Contratos criados a partir do código (09/10/2026)

| # | Assunto | Status | Registro |
|---|---|---|---|
| 81 | Contrato 006, SQL 010, SQL 011 e 45 | 🟡 | Criados em 09/10 a partir do código da `api-acos-vital` (`dee35b0`). O código já os citava sem existirem no vault (006 e "SQL 010") ou os chamava com número errado ("Contrato 30" para o pedido manual). Ver [[Indice-Contratos]]. |
| 82 | DDL de `api004` e `api005` | 🔴 (Gustavo) | O repositório da API não versiona SQL. Os contratos 010 e 011 descrevem só a interface que o código exige e trazem o checklist do DDL real (`\d`, `\df+`, definição da view e do trigger). Confirmar que as duas migrations estão aplicadas. |
| 83 | Front sem a tela de status por item | 🔴 (front) | `PedidoDetalhe.tsx` serve às três telas; falta o BFF e a coluna de etapa por produto da parcela. A rota exige Bearer e responde 200 com `itens` vazio quando o MES não tem dado. |
| 84 | MES não lê a referência da OC | 🔴 (Robert) | O `api-pcp` não consome `GET /ordens-compra/referencia`. Usar chave de leitura, não a do contrato 34. |
| 85 | Numeração de "Contrato 30" nos comentários do código | 🟡 (Gustavo) | Trocar para 45 nos comentários de `pedidoVendaManual.js`, `pedidos_vendas.route.js` e `notas_fiscais.route.js`. |

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
| 41 | `GET /ordens-compra/referencia` (004) | ✅ no hub (09/10): existe em `api-acos-vital` (`fe55923`, 08/10); ❌ o `api-pcp` ainda não a lê. |
| 43 | Consumidor do `/itens/status` (005) | ✅ no hub (09/10): job e rota `GET /itens_pedido_status` em `api-acos-vital` (`dee35b0`, 08/10); ❌ o av-hub (front) não consome. |
| 44 | IM-02: pedido sem prazo | ✅ `prazo_necessidade = prazoNecessidade ?? pedido.prazoEntrega`, e recusa sem prazo. |
| 46 | PTAX é a cotação de venda | ✅ cotação de venda; a API **reclassifica a origem para `manual`**, não recusa (`ordens_compra.route.js:964-977`, conferido em 08/10). |
| 22 | `main` do MES | ❌ Merge `develop` → `main` ainda não feito: `main` do `api-pcp` em `be076b2` e do `app-pcp` em `be847ac` (ambas 27–28/08). |
