---
tags: [contrato-logica, contrato-api, seguranca, escopo, permissoes, gambiarra-s1, gambiarra-s2, gambiarra-s3]
criado: 2026-10-07
atualizado: 2026-10-07
status: proposta
---

# Contrato 40 — Escopo de vendedores e permissões pelo token, no backend (fecha as GAMBIARRAS S1, S2 e S3)

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
2. 🟡 **Ajustar `env.js`:** a guarda de `USUARIO_TOKEN_SEGREDO` lê a variável; com a regra fixa, ela deixa de disparar. Passar a exigir o segredo sempre, para a trava não falhar em silêncio com 401.
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
| Q2 | 🔴 Aceitar que desligar a trava exija novo deploy (sem chave de emergência)? | Nathan / Gustavo |
| Q3 | 🔴 A API devolve os vínculos com a marca de **próprio x titular** (por exemplo em `/me/permissoes`), ou o BFF continua resolvendo só isso para "Meus Pedidos"? | Nathan / Gustavo |
| Q4 | 🔴 Reclassificar a marca de `nextauth` (cache de UI) ou remover o polling do JWT? | Nathan |
| Q5 | 🔴 Em produção, os perfis têm `escopo_vendedores` preenchido em `auth.fn_autorizar`? Perfil sem valor cai em "sem escopo" ou em "todos"? | Gustavo |

## 9. Efeito no cadastro de gambiarras

Quando o passo 5 for aceito: somem as marcas de `portalPcp.ts`, `pedidosVenda.ts`, `liberacaoPedidos.ts` e `liberar-pedidos/.../route.ts`, e a de `nextauth/route.ts` é reclassificada (Q4). Queda de **5** marcas no item 58 do [[Registro-de-Decisoes-2026-10-07]]. Nenhuma foi removida ainda.
