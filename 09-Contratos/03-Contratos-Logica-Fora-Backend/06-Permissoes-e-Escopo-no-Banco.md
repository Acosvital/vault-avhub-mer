# Contrato — Permissão, escopo e identidade aplicados no banco/backend

**Criado em:** 20/09/2026, junto da auditoria de segurança (`docs/seguranca/auditoria-2026-09-19.md`).

**Princípio:** quem pode ver ou fazer o quê **é decidido no banco/backend**, a cada requisição, a
partir da identidade autenticada. O BFF (este repositório) só encaminha a identidade e apresenta
o resultado. Hoje a autorização real acontece **no BFF**, e o backend confia numa chave de serviço.
Cada ponto abaixo está marcado com `GAMBIARRA(` no código.

## 1. Como é hoje

1. O BFF chama o backend com **uma única chave de serviço** (`x-api-key`) que enxerga tudo. Qualquer
   falha no BFF (ou vazamento dessa chave) equivale a acesso total.
2. A permissão do usuário vem de `GET /permissoes_usuario/menu/{id}`, é gravada no **JWT** (cookie) e
   conferida no BFF por `requirePermission` (`lib/api/requirePermission.ts`). É reavaliada a cada
   5 minutos (`app/api/auth/[...nextauth]/route.ts`), então revogar leva até 5 min para valer.
3. O backend não sabe quem está pedindo: cada rota do BFF decide sozinha quais parâmetros repassar.

## 2. Pontos a corrigir

| # | Gambiarra hoje | Onde | O que deve ser |
|---|---|---|---|
| S1 | Autorização por tela/ação só no BFF, com a chave de serviço no meio | `lib/api/requirePermission.ts` e as ~120 rotas de `app/api/**` | O backend valida a permissão do **usuário** em cada rota |
| S2 | **Escopo de unidade** = o BFF acrescenta `id_usuario_sessao` na URL e o backend "confia". Quem chamar o backend com a chave escolhe o usuário | `lib/api/escopoUnidade.ts` | O backend deriva o escopo da identidade autenticada, nunca de parâmetro |
| S3 | **Escopo de vendedores** do Portal do Vendedor e do PCP resolvido no BFF com 3 chamadas por requisição (`usuário → funcionário → vínculos → vendedores`) e injetado como `codigo_vendedor=a,b,c` | `lib/api/portalVendedor.ts`, `lib/api/portalPcp.ts` | O backend aplica o escopo dentro da consulta (predicado/RLS) |
| S4 | Perfil **"Gerencia PCP"** enxerga todos os vendedores — decidido por **nome do perfil** no BFF | `lib/api/portalPcp.ts` (`PERFIS_GERENCIA_PCP`) | Atributo do perfil no banco (ex.: `perfis.escopo_vendedores = 'todos'\|'vinculados'\|'proprios'`) |
| S5 | **Tela inicial por perfil** caindo em regras por nome de perfil ("RH - Joanes", "Vendedor"…) | `app/(protected)/page.tsx` (`*_FALLBACK`) | Somente `perfis.tela_inicial_id` (já existe; remover os fallbacks) |
| S6 | **Quem aprova** solicitação de vaga = "exatamente editar+visualizar" (heurística) | `hooks/usePermission.ts` (`canOnly`), `components/Vagas/*` | Ação explícita `pode_decidir` (ver contrato de vagas) |
| S7 | **Mascaramento** de CPF/RG/CNPJ e **visão enxuta** decididos no BFF | `app/api/funcionarios/**` | Segurança de campo no backend/banco, por permissão do usuário |
| S8 | Blacklist de pedidos consultada e aplicada no navegador | `components/Pedidos/usePedidos.ts` | Coluna `em_blacklist` na listagem e exclusão nos totais no banco |
| S9 | **Rate limit do login** em memória do processo (não vale com várias réplicas) | `lib/auth/loginRateLimiter.ts` | Store compartilhado (Redis/tabela) ou no proxy/WAF |
| S10 | Upload de foto: valida tipo/tamanho/assinatura de bytes no BFF | `app/api/uploads/route.ts`, `lib/s3/fotos.ts` | Política de bucket + varredura no backend; o BFF só entrega o arquivo |
| S11 | Sem trilha de auditoria de quem leu/alterou dado sensível | — | `auditoria` no banco (usuário, ação, entidade, quando) |

## 3. O que peço

### 3.1 Identidade propagada e verificável

O BFF passa a enviar, em **toda** chamada, um token de usuário assinado (JWT curto, emitido pelo
backend no login ou trocado por ele — `Authorization: Bearer …`), **além** da chave de serviço só para
identificar o BFF. O backend:

- valida a assinatura, extrai `id_usuario` e os perfis, e **ignora** qualquer `id_usuario_sessao`,
  `codigo_vendedor` de escopo ou similar vindos na query;
- responde `403` quando o usuário não tem a ação (`pode_visualizar|criar|editar|deletar|decidir`) na tela
  correspondente à rota (mapa `rota → tela` no banco);
- aplica o escopo (unidade e vendedores) **dentro da consulta** — em Postgres, `SET LOCAL app.usuario_id`
  + políticas RLS, ou funções que recebem o usuário.

### 3.2 Permissões como dado

- Nova ação `pode_decidir` na matriz de permissões por tela.
- `perfis.escopo_vendedores` e `perfis.tela_inicial_id` como colunas; o BFF deixa de olhar nome de perfil.
- Revogação imediata: `GET /me/permissoes` (barato, cacheável por segundos) ou versão do token invalidada
  no logout/troca de perfil. Hoje é "até 5 minutos".

### 3.3 Menor privilégio

Separar a chave de serviço em duas: leitura e escrita, sem acesso a tabelas administrativas
(`usuarios`, `perfis`, `permissoes`) exceto nas rotas de cadastro de acesso. Rotacionável sem deploy.

### 3.4 Auditoria

Tabela `auditoria(id, usuario_id, acao, entidade, entidade_id, campos, ip, criado_em)` preenchida pelo
backend em criar/editar/excluir/decidir e em leitura de documento sensível (CPF/RG/CNPJ completos).

## 4. O que muda neste repositório quando isto chegar

- `requirePermission`, `escopoUnidade`, `portalVendedor`, `portalPcp` viram repasse de identidade
  (o BFF deixa de conhecer perfis e escopos).
- Some a revalidação de permissões a cada 5 min no JWT (o backend é a fonte).
- Some o mascaramento no BFF e o rate limit em memória.

## 5. Aceite

- Chamar o backend com a chave de serviço e **sem** token de usuário devolve `401` nas rotas de negócio.
- Trocar o `id_usuario_sessao` na query não muda o resultado.
- Remover uma permissão do usuário bloqueia a próxima requisição (sem esperar minutos).
- Toda alteração de funcionário/vaga/decisão aparece em `auditoria` com quem fez.
