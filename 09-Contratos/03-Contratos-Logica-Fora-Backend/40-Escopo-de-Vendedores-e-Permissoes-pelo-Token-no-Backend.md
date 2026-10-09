---
tags: [contrato-logica, contrato-api, seguranca, escopo, permissoes, gambiarra-s1, gambiarra-s2, gambiarra-s3]
criado: 2026-10-07
atualizado: 2026-10-09
status: proposta
---

# Contrato 40 — Escopo de vendedores e permissões pelo token, no backend (fecha as GAMBIARRAS S1, S2 e S3)

> **(atualizado em 09/10/2026) FIXAR O ESCOPO DE VENDEDORES — plano de execução.** Pedido do Nathan. **Regra dele, para o contrato todo: nenhuma variável de ambiente; a regra fica FIXA NO CÓDIGO da API** (princípio do [[38-Regras-Sem-Chave-de-Ambiente]] e item 9 do [[Registro-de-Decisoes-2026-10-07]]). Isto **complementa** as seções 1 a 9 abaixo (texto antigo preservado; onde mudou, está marcado como superado). Fora de escopo: tudo de comissões (coordenadores, dash-comissoes, minhas comissões), em desenvolvimento. Legenda: ✅ verificado no código em 09/10 · 🟡 inferência · 🔴 pendente com dono.
>
> **Estado de hoje (✅ lido no código):**
> - **API** (`api-acos-vital`, `develop`, `dee35b0`): `src/utils/acessoConfig.js` ainda lê `ESCOPO_VENDEDORES_EXIGIR` do ambiente, **padrão `false`** (`escopoVendedoresExigir = () => bool("ESCOPO_VENDEDORES_EXIGIR", false)`). `PERMISSOES_ROTA_MODO` já é fixo em `exigir` (a variável não é mais lida). `src/middlewares/escopoVendedor.js` sai direto (`next()`) quando `escopoVendedoresExigir()` é falso, não há `req.usuario` ou o perfil é `todos`.
> - **Rotas com regra de escopo** (`ROTAS`): `vendas_planilha`, `vendas_planilha_resumo`, `faturamento_planilha(_resumo)`, `pedidos_venda` (lista e detalhe `/{empresa}/{numero}` com dono), `vendas_base`, `nf_classified`, `clientes_inativos`, `ranking_*` (4), `pedido_venda_itens`, `pedidos_vendas` (dono por `codigo_pedido_omie`), `pedido_observacao_pcp`, `itens_pedido_status` (dono: pedido por `codigo_empresa` + `pedido_venda` na query; pedido inexistente em `pedidos_vendas` -> 403), `pedidos_liberacao` (par), `dashboard/vendedor`, `dashboard/pcp` e `compras/pedidos-venda/{n}[/compras]` (dono).
> - **Achado: `/pedido_venda_itens/{numero}` NÃO tem regra de dono.** Está em `ROTAS` como `formato: "unico"` com `codigo_vendedor_omie`. O BFF (`app/api/pedidos-venda/[fonte]/[codigoEmpresa]/[pedidoVenda]/itens/route.ts`) chama com `codigo_empresa`, `sequencial` e `is_track_record`, **sem** `codigo_vendedor_omie`. Com o escopo ligado, a chamada cai em `cfg.formato === "unico"` sem parâmetro e responde **403 `ESCOPO_VENDEDOR_OBRIGATORIO`** (`escopoVendedor.js`, linhas 208-215). Resultado: ligar o escopo sem corrigir isso **quebra a aba de produtos da parcela** de todo usuário com escopo `vinculados`. A rota da API (`vw_pedido_venda_itens.route.js`, `GET /:numero_pedido`) só filtra por `numero_pedido` e `codigo_empresa`.
> - **Front** (`00 - HUB`; a árvore local está em `feat/bff-bearer-helpers`, `564abc8`): o **PR #178** do av-hub (ainda **não mergeado**) faz `headersCompras`/`headersApi` mandarem o Bearer do usuário, sem variável de ambiente. Testado na `api-test` pelo Nathan: 27 rotas de lista e as de detalhe responderam como antes, nenhum 403 de rota não mapeada; **com um usuário só e só leituras** (portanto não prova escopo nem escrita). As 5 marcas `GAMBIARRA(` deste contrato seguem no código: `lib/api/portalPcp.ts:51`, `lib/api/pedidosVenda.ts:15`, `lib/api/liberacaoPedidos.ts:8`, `app/api/liberar-pedidos/[codigoEmpresa]/[numeroPedido]/route.ts:46` e `app/api/auth/[...nextauth]/route.ts:192` (`REVALIDAR_PERMISSOES_MS = 5 min`, permissões no JWT por polling). Os números de linha mudaram desde 07/10.
> - **Perfis:** em produção (dump de 07/10, [[Auditoria-Dump-Producao-2026-10-07]]) são **21 perfis, 20 com `escopo_vendedores = vinculados` e só "Gerencia PCP" com `todos`**. Ou seja: com o escopo valendo, gerente, comprador, diligenciador e todos os demais passam a ver só os vendedores vinculados a eles. Produção atual: **nada em uso fora da gerência** (dashboards e portal do gerente); o trabalho está na `develop`.
> - **Token:** o `backendToken` do Hub dura 15 min e `/autenticacao/renovar` não aceita token expirado ([[Auditoria-Pente-Fino-2026-10-08]], achado C2). Quem fica ocioso volta a chamar só com a chave. Na API isso significa **sem `req.usuario`, logo sem escopo** (✅ `escopoVendedor.js:93`). 🟡 Depois que o BFF parar de filtrar, é um **furo de acesso**, não uma lista vazia (a auditoria diz "lista vazia ou 401"; pelo código da API o resultado é dado sem filtro). Por isso a pré-condição 3 abaixo é obrigatória.
>
> ### (a) O que a API precisa mudar (Gustavo; tudo fixo no código, sem `.env`)
> 1. **`src/utils/acessoConfig.js`:** `escopoVendedoresExigir = () => true;` (mesmo padrão de `auditoriaAtiva`, linhas 61-67). Atualizar o comentário do topo (a linha de `ESCOPO_VENDEDORES_EXIGIR` e a frase "Tudo que BLOQUEIA nasce desligado"). Não ler mais `process.env.ESCOPO_VENDEDORES_EXIGIR`.
> 2. **Limpar a variável de onde ela aparecer:** `grep -rn ESCOPO_VENDEDORES_EXIGIR` no repositório (código, `.env.example`, docker/compose, README/ARCHITECTURE) e no Coolify; apagar a variável dos ambientes (se continuar definida, não faz mal, mas fica enganosa). Atualizar o comentário de `escopoVendedor.js` ("Agora, com ESCOPO_VENDEDORES_EXIGIR=true e token…").
> 3. **Regra `dono` para `/pedido_venda_itens/{numero}`** (o achado acima), em `escopoVendedor.js`: quando o caminho tem 2 segmentos e o segundo não é `conferencia`, conferir o dono em `core_vendas_faturamento.pedidos_vendas` por `numero_pedido` (e `codigo_empresa` da query, quando for UUID válido) e responder **403 `PEDIDO_FORA_DO_ESCOPO`** se nenhum dono estiver nos vínculos (`pertence(donos, todos)`), igual ao ramo `pedido_venda_query`. A lista `GET /pedido_venda_itens` (1 segmento) e `/conferencia` continuam na regra `unico`. 🟡 Detalhes de desenho: (i) sem `codigo_empresa` na query, buscar o número em todas as unidades (a rota já devolve 409 se o número existe em mais de uma); (ii) pedido inexistente: deixar a rota responder 404 (nada vaza) ou 403 como em `itens_pedido_status`. Escolher e testar (Q9).
> 4. **Usuário sem vínculo:** o código já devolve **403 `SEM_VENDEDOR_VINCULADO`** quando `auth.fn_vendedores_do_usuario` volta vazio (✅ linhas 109-111), e **503** se a consulta falhar (fail-closed). Nada a mudar na API; o front tem de tratar (passo F5). 🟡 Conferir se o 403 sai **antes** do ramo `todos`: perfil `todos` nunca chega nele (✅ linha 94).
> 5. **`utils/env.js`:** ✅ a guarda de `USUARIO_TOKEN_SEGREDO` já é incondicional (mínimo 32 caracteres, linha 25; registro item 8). **Superado:** o §3 item 2 abaixo ("ajustar `env.js`") já foi feito pelo commit `6317d5f`. 🟡 Conferir que o segredo está definido no ambiente de cada deploy.
> 6. **Cobertura:** `pedidos_liberados` (`/pedidos_liberados/{n}`) reaproveita o handler de `pedido_venda_itens` (`pedidos_liberados.route.js:124`) mas **não está em `ROTAS`**. É rota do MES (só chave, sem token), então não muda hoje; 🟡 se algum dia o front a chamar com token, entra sem escopo. Registrar como risco aceito ou incluir (Q10).
>
> ### (b) Pré-condições (todas antes de subir a API com o escopo fixo)
> 1. **Rotas em `auth.rotas_telas`** conforme o [[Mapa-Rotas-BFF-API-para-Bearer]] (seção A: 43 rotas únicas hoje chamadas sem Bearer, aceitando **todas** as telas listadas por rota; os "pares de risco" do mapa, como `GET /usuarios/{x}` com a tela `compras`, valem). Sem linha, o usuário leva 403 `ROTA_SEM_PERMISSAO_MAPEADA`. O teste do PR #178 não achou nenhum, mas foi com um usuário só.
> 2. **Perfis que precisam enxergar tudo:** hoje só "Gerencia PCP" é `todos`. O gerente e as telas **de equipe** (`pedidos-equipe`, `notas-equipe`, `dashboard-equipe`: o BFF faz `equipe` sem filtro) e do PCP precisam de escopo `todos`, ou a tela precisa estar fora do escopo de vendedor em `auth.fn_autorizar`. 🔴 Gustavo: quais telas têm o escopo de vendedor ligado em `fn_autorizar` e quais perfis ganham `todos` (Q5 abaixo, ampliada). 🟡 `fn_vendedores_do_usuario` devolve próprios, titulares que o usuário auxilia e (em `vinculados`) os que diligencia; não há, no código lido, "toda a equipe" por hierarquia. **Sem decidir isso, a lista do gerente encolhe para os vendedores dele.**
> 3. **Renovação do token** (achado C2): antes de o BFF parar de filtrar, escolher uma de três: (i) a API aceita token expirado há até N minutos em `/autenticacao/renovar` (janela de tolerância); (ii) refresh token; (iii) o front trata a ausência/expiração do `backendToken` como **sessão inválida** (401 e volta para o login) **em vez de cair para a chave sozinha**. A opção (iii) é o mínimo e é só do front: `headersComIdentidade()` (`lib/api/escopoUnidade.ts:30`) hoje cai para só `x-api-key` quando a sessão não tem token. 🔴 Nathan/Gustavo decidem (Q6).
> 4. **PR #178 mergeado** (Bearer em `headersCompras`/`headersApi`). Sem ele o BFF segue mandando só a chave nas rotas de pedido/nota e a trava da API não atua.
> 5. **Teste de escrita e de mais de um perfil** na `api-test` (o do PR #178 foi com um usuário e só leitura): os testes do item (d).
>
> ### (c) Passo a passo do front (depois que a API subir e os testes (d) passarem; um PR por passo, nesta ordem)
> Regra de ouro: **só começar depois do passo 4 da §4 em produção**; cada passo tira uma marca e preserva o comportamento.
> 1. **F1 — `lib/api/pedidosVenda.ts` (marca da linha 15) e rotas que a usam.** Hoje `resolverEscopo(fonte, vendedor)` calcula `vendedores`/`proprios`/`permitidos` e `pedidoNoEscopo` confere o detalhe. Em `app/api/pedidos-venda/[fonte]/route.ts`, `.../resumo`, `.../composicao` e `app/api/notas-fiscais/[fonte]/route.ts` e `.../composicao`: deixar de montar o `?vendedor=` do escopo; mandar só o foco que o usuário escolheu (a API valida e preenche). Em `.../[codigoEmpresa]/[pedidoVenda]/route.ts`, `.../etapas` e `.../itens`: **apagar** o `resolverEscopo(fonte, null)` e o `pedidoNoEscopo` (a API confere o dono: `pedidos_venda/{e}/{n}`, `itens_pedido_status` e, depois do (a)3, `pedido_venda_itens`). Remover `resolverEscopo`/`pedidoNoEscopo` e a marca.
> 2. **F2 — `lib/api/portalPcp.ts` (linha 51) e rotas `app/api/pcp/*`** (`dashboard`, `notas`, `notas/resumo`, `pedidos/resumo`, `pedidos/[codigo_pedido_omie]/status-historico`, `vendedores`): apagar `resolverVendedoresDiligenciador` e a cadeia de 3 chamadas (`/usuarios/{id}` -> `/diligenciador_vendedor` -> `/vendedores?id_funcionario_in=`); `resolverEscopoPcp` passa a só validar o foco (`validarCodigoVendedor`) ou some. 🟡 `app/api/pcp/vendedores` (lista de vendedores para o seletor de foco) precisa de uma fonte: ou a API devolve os vendedores do escopo, ou o seletor usa `/vendedores` filtrado pela API. Decidir (Q7).
> 3. **F3 — `lib/api/liberacaoPedidos.ts` (linha 8) e `app/api/liberar-pedidos/route.ts`** (linha 44): apagar `paresVendedorSessao`; a lista `GET /pedidos_liberacao` vai sem `?vendedor=` (a API preenche com os pares do usuário).
> 4. **F4 — `app/api/liberar-pedidos/[codigoEmpresa]/[numeroPedido]/route.ts` (linha 46):** **tirar a conferência do dono** (lista da caixa e 404) e chamar direto `PUT /pedidos_liberacao/{empresa}/{numero}`; traduzir **403 `PEDIDO_FORA_DO_ESCOPO`** para a mensagem da tela (hoje 404). Remover os `import` de `paresVendedorSessao` e `obterIdUsuarioSessao` se ficarem sem uso.
> 5. **F5 — tratamento de erro em todas as telas afetadas:** **403 `SEM_VENDEDOR_VINCULADO`** vira o estado vazio "sem vínculo" que as telas já têm para o `null` do BFF; **403 `VENDEDOR_FORA_DO_ESCOPO`/`PEDIDO_FORA_DO_ESCOPO`** vira "sem acesso" ou lista vazia; **503** vira "tente de novo". O `apiFetch` (`lib/api/fetchHelper.ts`) deve repassar o `codigo` do corpo.
> 6. **F6 — `resolverVendedoresSessao`/`obterIdUsuarioSessao` (`lib/api/portalVendedor.ts`, sem marca):** **NÃO apagar junto.** Têm outros chamadores fora desta lista: `meu-dashboard` (+ `/cliente`), `minhas-notas` (+ `/resumo`), `meus-pedidos/resumo`, `meus-pedidos/[codigo_pedido_omie]/status-historico` e `meus-favoritos` (este só usa o id do usuário). Tirar o uso dessas rotas uma a uma (a API já cobre `dashboard/vendedor`, `faturamento_planilha`, `pedidos_venda/resumo`); `obterIdUsuarioSessao` pode ficar para favoritos. Só apagar o arquivo quando o `grep` não achar chamador.
> 7. **F7 — `app/api/auth/[...nextauth]/route.ts` (linha 192, S1/S2):** com a permissão conferida pelo token a cada requisição (`PERMISSOES_ROTA_MODO=exigir`), o polling de 5 min (`REVALIDAR_PERMISSOES_MS`) deixa de ser barreira. 🟡 Trocar a marca por comentário normal ("cache de UI; o backend confere cada requisição") e reclassificar. Remover o polling é decisão separada (Q4); `hooks/useAutoRefresh.ts` depende do intervalo.
> 8. **F8 — conferir:** `grep -rn "GAMBIARRA(" app lib` não deve mais achar as 4 marcas de escopo; `grep` por `resolverVendedoresDiligenciador`, `paresVendedorSessao`, `resolverEscopo`, `pedidoNoEscopo` sem resultado; `npx tsc --noEmit` limpo. Queda de 5 marcas no item 58 do [[Registro-de-Decisoes-2026-10-07]].
>
> ### (d) Testes de aceite por perfil (na `api-test` primeiro, depois produção; contas de teste, nada de usuário real)
> Preparar 6 usuários de teste, um por perfil, com vínculos conhecidos (A e B = dois vendedores distintos; X = um pedido de A; Y = um pedido de B).
>
> | Perfil | Caso | Esperado |
> |---|---|---|
> | **Admin** | Lista de pedidos, notas, `pedido_venda_itens/{X}` e `/{Y}` | Vê tudo (só se o admin tiver escopo `todos`; 🟡 hoje 20 de 21 perfis são `vinculados`, então **confirmar** o escopo do perfil admin: se for `vinculados` o admin também encolhe) |
> | **Gerente** | `GET /pedidos_venda` e `GET /faturamento_planilha` nas telas de equipe | Vê a equipe esperada pelo negócio (comparar a contagem com a de hoje, antes da mudança). Se encolher, é a pré-condição (b)2 |
> | **Vendedor A** | `GET /pedidos_venda?vendedor=<par de B>` | 403 `VENDEDOR_FORA_DO_ESCOPO` |
> | | `GET /pedidos_venda` sem `vendedor` | Só pedidos de A (a API preenche) |
> | | `GET /pedidos_venda/{emp}/{Y}` | 403 `PEDIDO_FORA_DO_ESCOPO` |
> | | `GET /pedido_venda_itens/{X}?codigo_empresa=…` | 200 (hoje daria 403 `ESCOPO_VENDEDOR_OBRIGATORIO`: é o teste do achado) |
> | | `GET /pedido_venda_itens/{Y}?codigo_empresa=…` | 403 `PEDIDO_FORA_DO_ESCOPO` |
> | | `GET /itens_pedido_status?codigo_empresa=…&pedido_venda={Y}` | 403 |
> | | `PUT /pedidos_liberacao/{emp}/{Y}` | 403; com o token do titular ou do auxiliar de Y, 200 (uma escrita real só em pedido de teste) |
> | **Vendedor sem vínculo** | qualquer tela de pedido | 403 `SEM_VENDEDOR_VINCULADO`; a tela mostra "sem vínculo", não erro genérico |
> | **PCP (escopo `todos`, ex.: Gerencia PCP)** | listas, detalhes e `dashboard/pcp` | Vê tudo, sem 403 |
> | **Diligenciador** | `dashboard/pcp?vendedor=` com vendedor do escopo e fora dele | 200 e 403; lista sem foco = só os diligenciados |
> | **Comprador** | "Compras deste pedido" (`GET /compras/pedidos-venda/{n}/compras?codigo_empresa=`) de pedido de A; telas de compras (`/compras/ordens`, `/produtos`, `/usuarios/{id}`) | 🟡 O comprador é `vinculados`: o "compras deste pedido" de pedido fora do escopo dá 403. **Confirmar com o negócio** se o comprador deve ver pedido de qualquer vendedor (o contrato 24 diz que o PV tem de ser de um vendedor do usuário). As telas de compras não mudam |
> | **Qualquer** | Token expirado (esperar 15 min, ou forjar `exp` passado) | O BFF responde 401 e leva ao login; **não** devolve dados (pré-condição (b)3) |
> | **Serviço (MES, pipeline)** | Só `x-api-key`, sem token, nas rotas que usam | Seguem 200 (o escopo só atua com `req.usuario`) |
> | **Reinício** | Reiniciar a API e repetir o caso de A | Mesmo resultado (sem estado em memória) |
>
> ### (e) Ordem de subida e rollback
> 1. API (`develop`): `acessoConfig.js` fixo + regra `dono` de `pedido_venda_itens` + comentários (um commit). Testes (d) na `api-test` **com o BFF antigo/atual** (a API ainda coincide com o filtro do BFF).
> 2. Pré-condições (b)1 a (b)3 resolvidas e o PR #178 mergeado e testado com os 6 usuários.
> 3. API em produção (`develop` -> `main`). Como em produção só a gerência usa, o efeito imediato é nos dashboards e no portal do gerente: conferir a contagem de pedidos/notas do gerente **antes e depois** (pré-condição (b)2).
> 4. Passos F1 a F8 do front, um PR cada, só depois dos testes (d) em produção.
> 5. **Rollback:** como a regra é fixa, **rollback da API = reverter o commit e fazer novo deploy** (não há chave para desligar; é a consequência da regra do Nathan e resolve a Q2 antiga: aceito). Rollback do front = reverter o PR do passo (o BFF volta a filtrar e a API confere por cima). Plano de emergência: ter o commit de reversão **pronto e testado**, e a ordem de subida acima para nunca ficar sem barreira (a API sobe antes de o front tirar o filtro; o front desce antes de a API ser revertida).
>
> ### (f) Perguntas em aberto (as Q1 a Q5 da §8 seguem valendo; estas são novas ou foram reformuladas)
> | # | Pergunta | Dono |
> |---|---|---|
> | Q2' | **Resolvida pela regra do Nathan:** sem chave de emergência; rollback = reverter o commit. Registrar no contrato 38. | Nathan (✅ regra) |
> | Q5' | 🔴 Quais telas têm escopo de vendedor ligado em `auth.fn_autorizar` e quais perfis (gerente, admin, equipe, comprador) devem ter `todos`? Hoje só "Gerencia PCP" é `todos`. | Gustavo / Nathan |
> | Q6 | 🔴 Renovação do token: janela de tolerância, refresh token ou forçar login (mínimo: front trata token ausente como sessão inválida). | Nathan / Gustavo |
> | Q7 | 🔴 De onde vem a lista de vendedores do seletor de foco do PCP depois que o front deixar de resolver? | Nathan / Gustavo |
> | Q8 | 🔴 Comprador ve "compras deste pedido" de qualquer vendedor? (hoje a API exige o PV ser do escopo) | Nathan |
> | Q9 | 🟡 Regra `dono` de `pedido_venda_itens`: pedido inexistente = 404 ou 403; sem `codigo_empresa` = busca em todas as unidades. | Gustavo |
> | Q10 | 🟡 `pedidos_liberados/{n}` fica fora do escopo (rota do MES, só chave) como risco aceito? | Gustavo |
> | Q11 | 🔴 O escopo `vinculados` inclui a equipe do gerente por hierarquia? (no código lido: próprios, titulares que auxilia e diligenciados) | Gustavo |
>
> **Não verificado em 09/10:** produção (perfis, `auth.rotas_telas`, `fn_autorizar`, `fn_vendedores_do_usuario`); `env.js` além da linha 25; o corpo de `pedidos_liberacao` e do `PUT`; se `apiFetch` repassa o `codigo` do erro.

> **Status: proposta (07/10/2026).** Fecha 5 marcações `GAMBIARRA(` do av-hub: `lib/api/portalPcp.ts:51`, `lib/api/pedidosVenda.ts:14`, `lib/api/liberacaoPedidos.ts:8`, `app/api/liberar-pedidos/[codigoEmpresa]/[numeroPedido]/route.ts:46` e `app/api/auth/[...nextauth]/route.ts:188`. **Achado principal: a API já aplica o escopo de vendedores pelo token, só que desligado por padrão (`ESCOPO_VENDEDORES_EXIGIR=false`). O trabalho é ligar, conferir as rotas e só então tirar a resolução do BFF.** Fontes: leitura do av-hub (`Desktop\TI\NATHAN\00 - HUB`, branch `fix/gambiarras-bff`) e da `api-acos-vital` (`middlewares/escopoVendedor.js`, `identidadeUsuario.js`, `utils/acessoConfig.js`, `utils/env.js`), em 07/10/2026. Legenda: ✅ verificado no código · 🟡 inferência · 🔴 pendente com dono. Decisões gerais em [[Registro-de-Decisoes-2026-10-07]] (itens 8 e 9). Substitui, para estes pontos, o S1 a S3 de [[05-Permissoes-e-Escopo-no-Banco]] e o L5 de [[26-Vendas-Liberacao-Pedido]] (históricos).

**Para:** backend (`api-acos-vital`, Gustavo) e av-hub (BFF) · **Médio.** Sem tabela nova; o risco é de ordem de subida.

> ⚠️ **Não remover a resolução de escopo do BFF antes de a API aplicar o escopo em produção.** Hoje o BFF é a única barreira: quem chamar a API só com a `x-api-key` escolhe o vendedor. Tirar o escopo do front antes de ligar a trava abre acesso a pedidos de outros vendedores.

## 1. Estado atual no front (✅)

| Marca | O que o BFF faz hoje |
|---|---|
| `portalPcp.ts:51` (S3) | `resolverVendedoresDiligenciador`: 3 chamadas por requisição (`/usuarios/{id}` → `/diligenciador_vendedor?id_funcionario_diligenciador=` → `/vendedores?id_funcionario_in=`), com `revalidate` curto para colapsar o burst. Até 9 chamadas numa carga de tela. |
| `pedidosVenda.ts:14` (S3) | `resolverEscopo(fonte, vendedorPedido)`: `equipe` sem filtro; `pcp` pelo escopo do diligenciador (foco só em vendedor do escopo); `vendedor` pelos vínculos da sessão. Manda o resultado como `?vendedor=` e guarda `proprios` e `permitidos` para conferir o detalhe. |
| `liberacaoPedidos.ts:8` (L5) | `paresVendedorSessao`: pares `EMPRESA:CODIGO` dos vínculos da sessão (próprios e titulares que auxilia), para o `?vendedor=` da caixa de liberação. |
| `liberar-pedidos/.../route.ts:46` (L5) | No `PUT`, lista a caixa do usuário e confere se o pedido está nela (404 se não). Só então chama `PUT /pedidos_liberacao/{empresa}/{numero}`. |
| `nextauth/route.ts:188` (S1/S2) | Permissões e perfis ficam no JWT e são relidos do backend a cada 5 min (`REVALIDAR_PERMISSOES_MS`); sessão máxima de 12 h. |

O resolvedor em `lib/api/portalVendedor.ts` (`resolverVendedoresSessao`, `obterIdUsuarioSessao`) não tem marca, mas é a mesma lógica e sai junto (§3, item 4).

## 2. O que a API já faz (✅ no código; 🔴 produção não conferida)

- **`middlewares/escopoVendedor.js`** (`aplicarEscopoVendedor`): com `ESCOPO_VENDEDORES_EXIGIR=true` e **token de usuário**, quando `auth.fn_autorizar` diz que a tela tem escopo de vendedor e o perfil não é "todos":
  - formato `lista` (`codigo_vendedor=a,b`) e `par` (`vendedor=EMPRESA:CODIGO`): valor fora do escopo → **403 `VENDEDOR_FORA_DO_ESCOPO`**; sem o parâmetro → a API **preenche** com os vendedores do usuário;
  - formato `unico` (`cod_vendedor=`): fora do escopo → 403; sem o parâmetro → 403 `ESCOPO_VENDEDOR_OBRIGATORIO`;
  - `dono` (detalhe de pedido, observação do PCP, "compras deste pedido"): o pedido tem de ser de um vendedor do escopo → **403 `PEDIDO_FORA_DO_ESCOPO`**;
  - usuário sem vínculo → **403 `SEM_VENDEDOR_VINCULADO`**; falha ao resolver → **503** (falha fechada).
  - Vínculos vêm de `auth.fn_vendedores_do_usuario` (próprios, titulares que auxilia e, no escopo "vinculados", os que diligencia).
- **Rotas cobertas** (`ROTAS`/`ROTAS_DASHBOARD`): `vendas_planilha`, `vendas_planilha_resumo`, `faturamento_planilha(_resumo)`, `pedidos_venda`, `vendas_base`, `nf_classified`, `clientes_inativos`, rankings, `pedido_venda_itens`, `pedidos_vendas`, `pedido_observacao_pcp`, `pedidos_liberacao` (lista e `PUT` com dono), `dashboard/vendedor`, `dashboard/pcp`, `compras/pedidos-venda`.
- **Sem token, nada muda:** a trava só atua se `req.usuario` existe. As chamadas de serviço do MES e do pipeline (só `x-api-key`) passam, como o item 8 do registro já descreve.
- **Permissão por rota (S1/S2):** `identidadeUsuario.js` valida o token, chama `auth.fn_autorizar` a cada requisição e sobrescreve `id_usuario_sessao` e os campos de autoria pelo id do token. Com `PERMISSOES_ROTA_MODO=exigir` (✅ decidido fixo no código, item 8), o 403 do mapa vale.
- **Guarda de inicialização:** `utils/env.js` encerra o processo se `USUARIO_TOKEN_SEGREDO` tiver menos de 32 caracteres **e** alguma trava estiver ligada **por variável**.

## 3. Proposta

1. **Fixar `ESCOPO_VENDEDORES_EXIGIR` ligado no código** (sem `.env`, como o contrato 38 e o item 9 do registro): `escopoVendedoresExigir()` em `acessoConfig.js` passa a devolver `true`. Só essa chave: `IDENTIDADE_EXIGIR_TOKEN`, `ESCOPO_UNIDADE_EXIGIR_SESSAO` e as demais seguem como chave até separar as chaves de serviço (item 9).
2. ~~🟡 **Ajustar `env.js`:**~~ **(superado em 09/10/2026: já feito, `6317d5f`; ver (a)5)** a guarda de `USUARIO_TOKEN_SEGREDO` lê a variável; com a regra fixa, ela deixa de disparar. Passar a exigir o segredo sempre, para a trava não falhar em silêncio com 401.
3. **Conferir a cobertura de rotas** (§5, teste 6): toda rota que o BFF chama com `vendedor`/`codigo_vendedor`/`cod_vendedor` e que devolve dado de vendedor tem de estar em `ROTAS`. Rota fora da lista segue sem escopo e vira furo depois que o BFF parar de filtrar.
4. **Front (só depois do passo 4 da §4):**
   - apagar `resolverVendedoresDiligenciador` e a cadeia de 3 chamadas de `portalPcp.ts`, e `paresVendedorSessao` de `liberacaoPedidos.ts`;
   - em `pedidosVenda.ts`, deixar de calcular `vendedores`; mandar só o foco que o usuário escolheu (a API confere) e tratar 403 como vazio/sem acesso;
   - no `PUT` de `liberar-pedidos`, **tirar a conferência do dono** (a API devolve 403 `PEDIDO_FORA_DO_ESCOPO`) e traduzir o 403 para a mensagem da tela;
   - tratar **403 `SEM_VENDEDOR_VINCULADO`** como o estado vazio de "sem vínculo" que as telas já têm hoje (o `null` do BFF).
5. **S1/S2 (`nextauth`):** com a permissão conferida pelo token a cada requisição, o polling de 5 min no JWT **deixa de ser barreira de segurança** e fica só como cache de **apresentação** (menu, tela inicial). 🟡 Proposta: depois do §4, trocar a marca por um comentário normal ("cache de UI; o backend confere cada requisição") e **reclassificar**. Remover o polling é decisão separada (🔴 Nathan, Q4).
6. **Não está no escopo:** `requirePermission` do BFF continua (defesa em profundidade e resposta rápida); `PERMISSOES_ROTA_MODO` já é do item 8.

## 4. Passo a passo e ordem de subida

| # | Quem | Passo | Depende de |
|---|---|---|---|
| 1 | Gustavo | Conferir em produção que as rotas de `ROTAS` existem e que `auth.fn_autorizar` devolve `escopo_vendedores` para os perfis (Vendedor, Gerência PCP, diligenciador) | — |
| 2 | Gustavo | Decidir Q1 a Q3 e ajustar `acessoConfig.js` e `env.js` na `develop` | 1 |
| 3 | Gustavo | Subir a API (`develop` → `main`). **A API vem primeiro.** Com o BFF ainda filtrando, nada muda para o usuário (o escopo da API coincide com o do BFF) | 2 |
| 4 | Nathan | Rodar os testes da §5 (1 a 6) na homologação e depois em produção, **com o BFF antigo** | 3 |
| 5 | Front | PR no av-hub com a §3 item 4. **Só depois do passo 4 em produção** | 4 |
| 6 | Nathan | Repetir os testes da §5 com o BFF novo e conferir a contagem de marcas (item 58 do registro) | 5 |

## 5. Testes de aceite

1. Vendedor A, `GET /pedidos_venda?vendedor=EMPRESA:CODIGO_DO_B` com o token de A → **403 `VENDEDOR_FORA_DO_ESCOPO`**.
2. Vendedor A, `GET /pedidos_venda` sem `vendedor` → a lista só traz pedidos de A (a API preenche).
3. Vendedor A, `GET /pedidos_venda/{empresa}/{pedido_de_B}` → **403 `PEDIDO_FORA_DO_ESCOPO`**.
4. `PUT /pedidos_liberacao/{empresa}/{pedido_de_B}` com o token de A → 403; com o token do titular ou do auxiliar do pedido → 200.
5. Usuário sem vendedor vinculado → 403 `SEM_VENDEDOR_VINCULADO`; a tela mostra "sem vínculo", não erro genérico.
6. **Cobertura:** listar todas as rotas que o BFF chama com parâmetro de vendedor (`grep` em `app/api` e `lib/api`) e confirmar que cada uma responde 403 para vendedor fora do escopo.
7. Gerência PCP com escopo "todos" e diligenciador com foco em vendedor do escopo/fora dele (403).
8. **Pipeline e MES continuam funcionando** só com `x-api-key` (sem token) nas rotas que eles usam.
9. Reiniciar a API e repetir 1 e 3: o escopo não depende de estado em memória.
10. Depois do passo 5: busca por `resolverVendedoresDiligenciador`, `paresVendedorSessao` e `GAMBIARRA(` nos 4 arquivos não acha nada de escopo.

## 6. Rollback

- **Front:** reverter o PR do av-hub traz a resolução de escopo de volta (o BFF volta a filtrar; a API continua conferindo por cima).
- **API:** como a chave fica fixa no código, desligar exige novo deploy (reverter o commit). 🟡 Em emergência (bloqueio indevido em massa) é preciso novo deploy; não há chave de ambiente para desligar. Decidir se isso é aceitável (Q2).

## 7. Riscos

- **Furo de acesso se o front sair antes da API** (aviso do topo). É por isso que a ordem de subida é rígida.
- **Rota fora de `ROTAS`:** sem escopo na API e, depois do passo 5, sem escopo no BFF. Mitigação: teste 6.
- **Vínculos em várias unidades numa rota que só filtra por código** (limite já documentado no `escopoVendedor.js`): o filtro fica só pelo código Omie, que pode repetir entre unidades. 🟡 Não piora em relação ao BFF de hoje, mas não é fechado.
- **`proprios` x `permitidos`:** "Meus Pedidos" separa vínculos **próprios** (editável) dos de titulares que o usuário auxilia (só leitura) usando `proprios`, que a API não devolve. Se o BFF deixar de resolver os vínculos, essa distinção some. Ver Q3.
- **Mudança de comportamento visível:** o que hoje é 404 do BFF (pedido fora da caixa) passa a ser 403 da API; o que hoje é `null` vira 403 `SEM_VENDEDOR_VINCULADO`. As telas precisam tratar os dois.
- **503 por falha de resolução:** o escopo falha fechado; uma queda de `auth.fn_vendedores_do_usuario` derruba as telas de vendedor, em vez de abrir acesso. É o comportamento desejado, mas é um novo ponto de falha.
- **Guarda do `env.js`:** ver §3 item 2; sem o ajuste, uma falha de configuração aparece como 401 em todas as rotas, não como erro de boot.

## 8. Perguntas em aberto

| # | Pergunta | Dono |
|---|---|---|
| Q1 | 🟡 Confirmar que fixar **só** `ESCOPO_VENDEDORES_EXIGIR` é seguro hoje (item 9 do registro) e que nenhuma chamada de serviço do MES ou do pipeline manda token de usuário nas rotas de `ROTAS`. | Gustavo |
| Q2 | ~~🔴 Aceitar que desligar a trava exija novo deploy (sem chave de emergência)?~~ **Superada em 09/10/2026:** regra do Nathan, sem variável de ambiente; rollback = reverter o commit. | Nathan (✅) |
| Q3 | 🔴 A API devolve os vínculos com a marca de **próprio x titular** (por exemplo em `/me/permissoes`), ou o BFF continua resolvendo só isso para "Meus Pedidos"? | Nathan / Gustavo |
| Q4 | 🔴 Reclassificar a marca de `nextauth` (cache de UI) ou remover o polling do JWT? | Nathan |
| Q5 | 🔴 Em produção, os perfis têm `escopo_vendedores` preenchido em `auth.fn_autorizar`? Perfil sem valor cai em "sem escopo" ou em "todos"? | Gustavo |

## 9. Efeito no cadastro de gambiarras

Quando o passo 5 for aceito: somem as marcas de `portalPcp.ts`, `pedidosVenda.ts`, `liberacaoPedidos.ts` e `liberar-pedidos/.../route.ts`, e a de `nextauth/route.ts` é reclassificada (Q4). Queda de **5** marcas no item 58 do [[Registro-de-Decisoes-2026-10-07]]. Nenhuma foi removida ainda.
