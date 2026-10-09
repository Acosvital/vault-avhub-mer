---
tipo: auditoria
criado: 2026-10-08
atualizado: 2026-10-08
---

# Auditoria "pente fino" das 9 juntas (08/10/2026)

> Status: leitura de código (somente leitura) | repos: api-acos-vital `a6ab058`, pipeline `d2886bf`, api-pcp `ca3346b`, app-pcp `a802a3e`, front av-hub `develop` `996e320` | **produção não foi conferida**, só o dump de 07/10 ([[Auditoria-Dump-Producao-2026-10-07]]).
> Decisões da rodada anterior: [[Registro-de-Decisoes-2026-10-07]]. Achados abaixo **não** são decisões; cada um tem dono.

Nove auditores, um por junta: front↔API vendas (V), front↔API compras/RH/auth (C), MES↔hub (M), pipeline↔banco (P), contratos↔código (K), vault↔vault (VV), arquitetura do vault↔código (AR), chaves/configuração/segurança (S), modelo de dados↔SQL (D). O auditor C foi **rodado de novo em duas partes completas**: C1 (compras e Comercial & Suprimentos) e C2 (cadastros, RH, autenticação e permissões, lidos campo a campo). Os achados novos estão na seção 2b.

## 1. Premissas do vault que a auditoria desmentiu

| Premissa registrada | O que o código mostra | Fonte |
|---|---|---|
| "O front manda token (Bearer) em todas as chamadas" (Registro item 9, ✅ Nathan) | Pelo menos **38 arquivos** do BFF mandam só `x-api-key`: `app/api/compras/*`, `pedidos-venda/[fonte]/**` (5 rotas) e `notas-fiscais/[fonte]/**` (2). `headersCompras()` e `headersApi()` não levam Bearer. Outros 127 arquivos levam. | S, V |
| "O BFF repassa o `id_token` do Azure" (contrato 38 §3) | O BFF manda só o e-mail. Quem tem a `API_KEY` obtém token de qualquer usuário. | S, C |
| "A API recusa OC com cotação diferente da PTAX de venda" | A API **reclassifica** a origem para `manual` e zera `cotacao_data`; não recusa. | K |
| "0 de 74 compradores vinculados" | 20 de 74 em 07/10 (32 ativos ainda sem vínculo). | VV |
| Orçamento do av-hub faz proxy para a API | Os handlers `/api/orcamento/*` leem JSON local em `lib/orcamento/data`. | AR |
| Hub lê as requisições do MES (diagramas, contrato 003) | O MES empurra com `PUT` (contrato 34) e lê eventos a cada 5 min (35). | AR, VV |
| `GAMBIARRA(`: 24 ou 57 | 14 no front (12 arquivos). Há uma 15ª **sem marcação** (`comissoes/minhas-comissoes`). Na branch `fix/gambiarras-bff` restam 11 marcadas. | V |

## 2. Bloqueantes e críticos

| # | Junta | Problema | Evidência | Correção e dono |
|---|---|---|---|---|
| 1 | S | `api-pcp`: `UsuariosController` sem guard (só `:id/senha` tem JWT). Qualquer um na rede cria, edita e anonimiza usuário e recebe JWT. `SetoresController` também aberto; 16 controllers só com JWT, sem `APP_GUARD`. **(atualizado em 09/10/2026: resolvido no PR #51 do `api-pcp`, `e8f951e`, 08/10: guard global com deny-by-default; usuários e setores com `@RequirePermission` nas escritas)** | `usuarios.controller.ts:24-72`, `setores.controller.ts:21-60` | Guards + permissão por rota, ou `APP_GUARD` com deny-by-default. **Robert** |
| 2 | P, S | `exclusionSync` apaga `pedidos_vendas` **sem filtrar `manual`** (pedidos manuais têm `codigo_pedido_omie` negativo). O trigger `trg_limpa_produto_vendas_orfaos` apagaria os itens. Proteção citada (`trg_pedidos_vendas_manual_sem_delete`) não está em nenhum `.sql` do vault. | `exclusionSync.ts:100-106,136` | `AND NOT manual AND codigo_pedido_omie > 0` no SELECT e no DELETE; DBA confirma o trigger. **Gustavo** |
| 3 | P | Sem trava de sanidade: resposta "sem registros" do Omie (`Client-5113`) vira lista vazia e manda a janela inteira ao DELETE. | `exclusionSync.ts:84-97` | Abortar se vier vazio com banco > 0 ou se sumir mais de X%. **Gustavo** |
| 4 | D | Banco de produção do MES está na `main` de 28/08 (15 migrations); faltam 36. A `develop` quebra contra ele. | Dump §2 | `prisma migrate deploy` em ordem; migrations de enum em transações separadas. **Robert / Nathan** |
| 5 | C | CCP: a leitura da fila volta 403 `USUARIO_NAO_INFORMADO` (sem Bearer) e, mesmo sem o 403, a lista vem vazia: o BFF lê `r.data/page/total_pages`, a API devolve `{itens,total,limit,offset,...}`. | `acompanhamento/route.ts:20-37` | `headersComIdentidade()`, ler `itens`, converter `page` em `offset`. **Front** |
| 6 | C | `api-comercial` lê a claim `perfis`, que o token do Hub não emite ("os perfis não vão no token"). `capacidades.comprador` fica `false` e responder/assumir/liberar custo dá 403. | `autenticacao.ts:59` ↔ `tokenUsuario.js:16-17` | Resolver perfis via `/me/permissoes` ou assinar a claim. **api-comercial + API** |
| 7 | C | 16 dos 18 slugs do Comercial/Suprimentos não existem em `auth.telas` (dump 07/10): nega até o Admin. | Dump `:27,57` | Cadastrar telas e permissões. **DBA** |
| 8 | V | Editar/excluir nota manual vai para a rota genérica e leva 403 `NOTA_MANUAL_ROTA_PROPRIA`. | `notas-manuais/[codigo]/route.ts:28,46,64` | Trocar para `/nota_fiscal_saida/manual/{codigo}`. **Front** |
| 9 | V | Criar/editar/excluir produto chama `POST/PUT/DELETE /api/produtos` e o BFF só tem `GET`. | `services/cadastros/auxiliares/produtos.ts:27,35,43` | Criar os handlers ou tirar os botões. **Front** |

## 2b. Achados novos da reauditoria de compras, Comercial, cadastros, RH e autenticação

| Sev. | Junta | Problema | Correção e dono |
|---|---|---|---|
| Bloqueante | C1 | Nenhuma rota ou rotina cria `PerfilComercial` fora dos seeds, e o seed de usuário só roda fora de produção (`seed.ts:117`). Sem perfil o escopo é NENHUM e propostas, clientes e relatórios dão 403 para todos. Nenhum documento diz quem carrega esses perfis. | Endpoint ou carga de perfis, com dono definido. **api-comercial / TI** |
| Bloqueante | C1 | A falta da claim `perfis` (item 6) derruba também ofertas (POST e invalidar), apelidos, perfil de fornecedor, importar mapa, responder/assumir/liberar solicitação de custo, `PUT /parametros_custo` e `/omie/sincronizar`, e zera o `ve_custo` de quem não é vendedor ou gestão. | Hub emite `perfis` ou o api-comercial consulta `auth.fn_autorizar`. **API / api-comercial** |
| Bloqueante | C1 | `casar()` também quebra `/empresas_emissoras/:codigo` (AV, AU, HRM), além dos já listados. | Tipar cada param na tabela de rotas. **Front** |
| Alta | C2 | Azure com usuário inexistente (404) ou inativo (401): a sessão fica sem `id_usuario` nem menu e `authorized: !!token` passa. Na revalidação, usuário desativado nunca é derrubado (só atualiza se há `userSession`). O BFF o aceita por até 12 h. | `signIn` retorna false quando `/azure` falha; 401/404 do `/renovar` ou `/me` invalida a sessão. **Front** |
| Alta | C2 | `backendToken` dura 15 min e `/renovar` não aceita token expirado. Quem fica ocioso perde o token e o BFF cai em `x-api-key` puro: sem escopo nem permissão por rota. Com `ESCOPO_VENDEDORES_EXIGIR` fixo vira lista vazia ou 401. | Janela de tolerância ou refresh token na API; forçar re-login no front. **API + Front** |
| Alta | C2 | Trocar a própria senha chama `PATCH /api/usuarios/{id}`, que exige `pode_editar` em Usuários: usuário comum leva 403. No sentido oposto a API não confere que `:id` é o dono do token: quem edita usuários troca a senha de outro se souber a senha atual. | Rota própria com o id da sessão; a API exige `req.usuario.id === :id`. **Front + API** |
| Alta | C2 | "Novo parceiro" e "novo produto" nunca funcionam: o payload não leva `codigo_empresa` (NOT NULL) e o 400 vira 500. | Decisão do Nathan: enviar a unidade ou remover o botão (o cadastro vem do Omie). **Front** |
| Alta | C1 | Link de "Atrasados" no dashboard de Compras abre `/compras/pedido-omie/${a.id}`; nas linhas `origem='av-hub'` o `id` é o da OC e o certo é `id_pedido_compra`. Dá 404. | **Front** |
| Alta | C1 | O detalhe `/ordens/:id/acompanhamento` tem o mesmo 403 da fila CCP. | `headersComIdentidade()` ou `id_usuario_sessao`. **Front** |
| Média | C1 | O dashboard de Compras tem campos que o front nunca lê: `pedidos_recebidos`, `pedidos_sem_espelho`, `valor_chegam_7_dias`, `pedidos_sem_previsao`, `valor_sem_previsao`. | **Front / API** |
| Média | C1 | `PUT /propostas/:id` pelo auxiliar: o schema exige preço (ou custo e margem), mas o auxiliar carrega a proposta com esses campos nulos. Edita, mas o save dá 400. | Definir se o auxiliar edita. **API** |
| Média | C1 | O api-comercial valida só assinatura e `exp`, sem `typ` nem `ver`: token revogado no logout vale até 15 min. `JWT_ISSUER` opcional; `JWT_AUDIENCE` não deve ser definido (o token do Hub não traz `aud`). | `JWT_ISSUER=api-acos-vital` e conferir `typ`/`ver`. **api-comercial** |
| Média | C1 | Rate limit do api-comercial sem `keyGenerator`: o IP é sempre o do BFF, então os 300 req/min são de todos juntos. | Subir `RATE_LIMIT_MAX` ou chavear por `sub`. **api-comercial** |
| Média | C1 | `respostaDeErro` descarta `campos`: `CLIENTE_DUPLICADO` perde o id do existente e um 502 `RECEITA_INDISPONIVEL` vira 500. `/solicitacoes-custo/:id/responder` não inclui `painel-comprador`. | **Front** |
| Média | C2 | `created_by`/`updated_by` nunca são gravados nos cadastros (perfis, telas, permissões, usuários, vendedores, diligenciador, auxiliar). Em funcionários o BFF manda mas `FIELDS` descarta; `usuarios_unidades` usa `id_usuario_autor`, fora de `CAMPOS_AUTORIA`. | Preencher autoria com `req.usuario`. **API** |
| Média | C2 | Telas de negócio carregam referências por endpoints travados por outra tela (Funcionários, Vagas e Comissões levam 403 em unidades, setores e cargos). No `Promise.all` o erro derruba tudo e os rótulos viram "—". | Aceitar array de slugs nesses GETs ou criar BFF de referência. **Front** |
| Média | C2 | 429 `LOGIN_LIMITE`, 401 de inativo e 401 de "sem login interno" viram `null` no `authorize`; a tela diz sempre "E-mail ou senha incorretos". O limitador local é em memória por instância, só por e-mail (dá para bloquear a conta alheia). | Propagar código e espera. **Front** |
| Média | C2 | No login, `fetchMenu`, `usuarios_perfis`, `perfis` e `telas/:id` vão só com `x-api-key`: com `IDENTIDADE_EXIGIR_TOKEN` dão 401 e o login passa com menu vazio. | Trocar as 4 chamadas por `GET /me/permissoes`. **Front** |
| Média | C2 | `permissoes/page.tsx` pede `limit:1000` e a API corta em 200; `auth.permissoes` tinha 194 linhas em 07/10. Mesmo padrão em diligenciadores (51) e `getVendedores()` (123). | `buscarTodasPaginas`. **Front** |
| Média | C2 | Cargos e setores: o select de unidade é editável, mas `codigo_empresa` é imutável na API (400 vira 500). | Travar o select ao editar e usar `respostaDeErro`. **Front** |
| Baixa | C2 | `avatar_url` versus `photo_url`; tela inicial vem do primeiro vínculo e a API ordena por `created_at DESC`; tipos TS divergem dos models; `code` versus `codigo` em `CADASTRO_VEM_DO_OMIE`; admin não redefine senha; "Anonimizar" não existe no Hub (sem coluna `anonymized_at`). | **Front / API** |

## 3. Altos

| # | Junta | Problema | Correção e dono |
|---|---|---|---|
| 10 | S, V | Rotas do BFF só com `x-api-key` (item 1 da seção 1): permissão e escopo não protegem pedidos, notas e Compras. | Usar `headersComIdentidade()`. **Front** |
| 11 | V | Com `ESCOPO_VENDEDORES_EXIGIR` ligado, `/pedido_venda_itens/{n}` exige `codigo_vendedor_omie` e o front não manda: 403 nos produtos da parcela. | Tratar a rota como "dono por pedido" ou o BFF repassar o vendedor. **Gustavo** |
| 12 | V | Busca de pedido da NF manual é por trecho (`iLike %N%`) e o BFF pega o primeiro: "6261" pode ligar a "16261". | Conferir igualdade no BFF. **Front** |
| 13 | M | Contrato 26: pedido anterior à data de corte (01/09) ou não "Pendente" sem liberação não está na view; o MES recebe 404. A carteira antiga (~2.000) some da Carteira. | Decidir `status_liberacao='legado'` ou outro caminho. **Nathan decide; Gustavo** |
| 14 | S | `/docs` embute `DOCS_API_KEY` e aceita qualquer sessão Azure do tenant; CORS cai em `*` se `CORS_ORIGINS` estiver vazio. | Chave de leitura em `DOCS_API_KEY`; exigir lista de origens. **Gustavo** |
| 15 | P, S | O código ainda tem `SYNC_ENVIO_OC=false` e `ENVIO_OC_DRY_RUN=true` como padrão. Ligar só o envio deixa em dry-run, sem PATCH. A decisão "fixo, direto ao Omie" não está no código. | **Gustavo** |
| 16 | P | `afterUpsert` nunca remove item que saiu do pedido no Omie: linha fantasma infla faturamento e comissão. | Soft-delete dos itens ausentes. **Gustavo** |
| 17 | P | Índice legado `uq_produto_vendas_item` pode existir e proíbe dois itens iguais sem NF; o pipeline os pula como "ambíguos". **A confirmar em produção.** | **DBA** |
| 18 | K | `id_unidade_compra` nulo nas 3 unidades: `/unidades?compra=true` devolve a HRM e `/compras/pedidos-venda/{n}` da HRM dá 404. | Gravar HRM = Mogi ou definir a regra. **Gustavo / Nathan** |
| 19 | C | `casar()` do `comercialApi` converte todo `:param` em uuid: `/clientes/por-documento/:documento` (14 dígitos), `/clientes/receita/:cnpj` e `/propostas/:id/versoes/:revisao` dão 404. | `[^/]+` nos não-uuid. **Front** |
| 20 | C | Dashboard de Compras: `recebimento.itens_recebidos/itens_parciais` não existem na API; os segmentos ficam sempre 0. | Derivar de `itens - itens_pendentes` ou expor na API. **Front + API** |
| 21 | C, S | 3 rotas no slug `organograma` (inexistente): em `exigir`, dão 403 e o BFF mostra 500. Também em risco: `/pedidos_liberacao`, `/permissoes_usuario/menu`, `/produtos`, `/funcionarios/:id/equipe`. | Remapear em `auth.rotas_telas`. **DBA** |
| 22 | S | Não há `.env.example` em api-acos-vital, api-pcp, app-pcp e front; só pipeline e api-comercial. | Criar e referenciar. **Cada dono** |

## 4. Médios

- **MES (M):** `quantidade` exige inteiro 1–32.767 e `codigo` ≤15 caracteres, mas o hub entrega fracionário e até 60 (Robert). Eventos do contrato 35 que falham gravam `ERRO:` e o cursor avança: cancelamento pode se perder, sem reprocessamento (Robert). `codigo_empresa` opcional na query do MES (Robert).
- **Pipeline (P):** manifesto com pedido vazio viola `NOT NULL` e dá rollback do lote da filial; `familiaProdutos` colide com nome vazio; `core.produtos` e `core.familia_produtos` sem colunas protegidas (o upsert sobrescreve `descricao`, `ncm`, `especificacoes`, `ativo`: decisão do Nathan); `ativo_desde/inativo_desde` nulos (123/123 e 74/74); `cnpj_cpf_fornecedor` nulo em 100%; parcelas da OC nunca enviadas; `cotacaoPtax` grava `status 'success'`.
- **Segurança (S):** limite de falhas do login desligado (`LOGIN_LIMITE_TENTATIVAS=0`) e sem `x-cliente-ip`; global de 10.000/min e limiter só em `/auth/login`; sem throttler no `api-pcp`; Redis do pipeline publicado na 6379 sem senha; `USUARIO_TOKEN_SEGREDO` precisa ser obrigatório ao fixar `exigir`; `JWT_SECRET` do api-comercial deve igualar `USUARIO_TOKEN_SEGREDO` do hub (sem registro no vault).
- **Front (V, C):** 28 arquivos de BFF engolem erros como 500 sem `respostaDeErro` (409 e 403 se perdem); ritmo de meta não aplica o filtro de empresa; `metas-mensais` pode dar 403 por `pode_editar` versus `pode_criar`; fechamento manual sem `created_by`; `minhas-comissoes` sem escopo de sessão (15ª gambiarra); PUT de vaga sem `updated_by`; Azure: guardar `id_token` antes de ligar a flag.
- **Modelo (D):** `parceiros.model.js` sem as 13 colunas fiscais; `pedidos_vendas.model.js` sem desconto (003) e com colunas de devolução vazias; contratos 007/008 divergem dos models (`numero_ordem` versus `numero_pedido`, `numeric(15,4)` versus `DECIMAL(14,3)`); vault diz `NAO_APLICAVEL` na carga inicial e o schema grava `LIBERADO`.
- **Contratos (K):** pedido de venda manual (POST/PUT/PATCH/DELETE) sem contrato, com comentários chamando de "Contrato 30"; orçamento (07) diverge do código (`sem_cadastro` dá 400); contrato 38 diz "6 chaves" e a API ainda lê as 2 de login.
- **Vault (VV, AR):** saldo zero contradiz (três notas "exige clique", três "aberto/automático"); T.6 versus T.5 (ranking de gargalos); `Fluxo-Compras-Completo` C3 sem limiar; inventário de schemas "completo" mas defasado; diagramas com setas erradas.

## 5. Baixos

Isenção por `startsWith` em `/auth*` e `/blog*`; `console.log` por requisição com 8 caracteres da chave; Dockerfile do `api-pcp` sobe com `migrate deploy` falho; `alterado_desde` é código morto em `/produtos` e `/parceiros`; `codigoPedidoOmie` tipado `number` no MES; `GET /produtos/:id/fornecedores` existe apesar do contrato 13 desconsiderado; corte do contrato 26 em produção é 01/09 e não 28/07; `sql/001` e `sql/002` criam `omie_raw`; comentários desatualizados; BFFs sem consumidor; 13 contratos realizados sem frontmatter; contagens (9 telas de comissão, 93 `page.tsx`, ItemParcial com 9 estados).

## 6. O que encaixa

Contrato 34 (corpo do PUT, limites, 201/200/409) e 35 (cursor, sobreposição de 2 min, 14 tipos); chaves MES→hub, leitura do MES e pipeline (casam por valor); Prisma do MES contra as migrations (44 modelos, sem divergência); enums (7 setores, 2 fábricas, 9 estados do ItemParcial, 3 de reserva); `estoque_saldo` e `locais_estoque` contra os contratos; contagens (183 `route.ts`, 108 models, 119 rotas, 50 migrations, 15 recursos, 14 ligados); crons do pipeline; fila de OC; PTAX com dados até 06/10; pedidos e notas dos 3 portais; `/me/permissoes`; contratos 01, 04, 05, 08, 11, 12, 14, 18, 19 e 26 a 39 no que a API faz; nenhum segredo literal nem `.env` versionado.

## 7. Decisões que dependem do Nathan

1. **Reabrir o Registro item 9:** o front não manda Bearer em tudo. Corrigir os helpers antes de fixar `ESCOPO_VENDEDORES_EXIGIR` ou `exigir` de verdade.
2. **Carteira antiga (13):** `legado` como liberado implícito, ou outro caminho.
3. **HRM (18):** regra de `id_unidade_compra`.
4. **Campos de `core.produtos` e `core.familia_produtos` (pipeline):** quem manda, o Omie ou o cadastro.
5. **`NAO_APLICAVEL` versus `LIBERADO`** na carga inicial.
6. **Saldo zero:** automático ou clique.
7. **Contrato novo** para pedido de venda manual.

## 8. Não verificado

Produção e banco real (nenhum DDL do Hub está nos repositórios; o `dump 2.0.sql` é de 21/08); `auth.rotas_telas` (371 linhas) e `auth.telas`; valores de variáveis de ambiente; trigger `trg_pedidos_vendas_manual_sem_delete`; índice `uq_produto_vendas_item`; corpo de `fn_requisicao_mes_aplicar`, `fn_autorizar`, `fn_me_permissoes`; mermaid não renderizado. Da reauditoria de compras, cadastros e autenticação: `COMERCIAL_API_URL` (se tem `/v1`), `JWT_SECRET` e `JWT_ISSUER` em produção; se `auth.rotas_telas` mapeia `/compras/*` e `PATCH /usuarios/:id/senha`; se o cookie de sessão renova nos route handlers; se os perfis comerciais são carregados por SQL manual fora do repo; os swaggers de cada entidade (usei os models).
