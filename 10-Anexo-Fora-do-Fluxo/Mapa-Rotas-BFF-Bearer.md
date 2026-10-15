---
tags: [anexo, bff, bearer, permissoes, rotas, av-hub, fora-do-fluxo]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [HUB b55ac55 app/api/**/route.ts (extração por script em 14/10), api-acos-vital f322dcd middlewares/identidadeUsuario.js e utils/acessoConfig.js, Dump Avhub 14/10 (auth.rotas_telas), v1 Mapa-Rotas-BFF-API-para-Bearer e anexo mapa-rotas.js]
---

# Mapa de rotas do BFF para a API: quem chama com Bearer

> **Correção (reauditoria de 14/10/2026):** a contagem "Sem Bearer (`headersCompras`, `headersApi` ou `x-api-key` inline)" abaixo classifica errado: `headersCompras` (`lib/compras/api.ts:31`) e `headersApi` (`lib/api/pedidosVenda.ts:96`) são apelidos de `headersComIdentidade` e **mandam o Bearer**. Na leitura arquivo a arquivo, só `app/api/auth/[...nextauth]/route.ts` (3 funções do login) chama a API sem o token do usuário ✅. Veja BL-042 em [[Backlog-por-Frente]] e PS-018 em [[Pontas-Soltas]].

Fora do fluxo 0b, mas decide se o usuário comum leva 403. Regras de chave e token: [[Chaves-e-Autenticacao]]; permissões: [[RBAC-e-Permissoes]].

## A regra na API (✅ conferida)

- Chamada **com** `Authorization: Bearer` passa por `auth.fn_autorizar` (`identidadeUsuario.js`): usuário inativo ou token revogado dá 401; ação não permitida na tela que a rota exige dá 403 `SEM_PERMISSAO`; rota sem linha em `auth.rotas_telas` dá 403 `ROTA_SEM_PERMISSAO_MAPEADA` (fail-closed). Fixo desde 08/10: a variável `PERMISSOES_ROTA_MODO` não é mais lida ✅ `acessoConfig.js:10-16`, `identidadeUsuario.js:85-110`.
- **Sem** Bearer nada muda: segue só a `x-api-key` (BFF, MES e pipeline) e os campos de autoria do corpo são os informados.
- Escopo de vendedores: fixo desde 09/10 (contrato 40); só vale com token ✅ `acessoConfig.js:28-35`.
- Com token, a API sobrescreve `id_usuario_sessao` e os campos de autoria (`created_by`, `updated_by`, `deleted_by`, `aprovado_por`, `decidido_por`, `cancelado_por`) pelo id do token ✅ `identidadeUsuario.js:55-64`.
- O `backendToken` dura 15 minutos e não renova depois de expirar; quem fica ocioso volta a chamar só com a chave ❓ (v1, não reconferido no HUB).
- A tabela `auth.rotas_telas` existe no dump, com `acao` entre `pode_visualizar`, `pode_criar`, `pode_editar`, `pode_deletar`, `pode_aprovar` ✅ (`CREATE TABLE auth.rotas_telas`). Quais linhas existem em produção ❓ Gustavo.

## Números no HUB `b55ac55`

Extração por script (regex sobre `app/api/**/route.ts`), refeita em 14/10:

| Medida | Valor |
|---|---|
| Rotas do BFF | 197 |
| Handlers (método por rota) | 275 |
| Handlers que chamam uma API | 237 |
| Com Bearer (`headersComIdentidade`, que cai para só `x-api-key` quando a sessão não tem token) | 167 |
| Sem Bearer (`headersCompras`, `headersApi` ou `x-api-key` inline) | 70 |
| Handlers que não chamam a API (respondem no BFF ou usam helper não resolvido) | 38 |
| Rotas únicas da API a mapear em `auth.rotas_telas` (seção A do script) | 48 |

Em 09/10 eram 189 rotas, 265 handlers, 168 com Bearer e 64 sem. O aumento inclui rotas novas como grupos de clientes e acompanhamento de clientes (não foi feita a comparação rota a rota). As chamadas ao `api-comercial` ficam fora da conta: ele tem controle próprio (`UsuarioComercial`) e não passa por `auth.rotas_telas` ([[Comercial-Suprimentos]]).

Limites: o script erra o método quando o `fetch` está em helper e não resolve caminho montado por função (aparece como `via helper`). Conferir cada linha no arquivo antes de agir.

## Rotas ainda sem Bearer que precisam de linha no mapa

Grupos (a lista completa sai do script):

| Grupo | Rotas da API (exemplos) | Tela exigida no BFF |
|---|---|---|
| Compras | `/compras/ordens` e `/{x}` (`GET`, `POST`, `PATCH`), `/compras/ordens/{x}/acompanhamento`, `/contatos`, `/ocorrencias`, `/reenviar`, `/compras/ocorrencias/{x}`, `/compras/compradores`, `/compras/fornecedores`, `/compras/condicoes-pagamento` | `compras`, `followup`, `compradores` |
| Cadastros usados por Compras | `/categorias`, `/produtos`, `/contas_correntes`, `/projetos`, `/cotacoes_moeda/atual` | `compras (visualizar)` |
| Acompanhamento de clientes | `/acompanhamento_clientes`, `/acompanhamento_clientes/movimento` | sem tela definida no BFF |

Pares de risco (a tela natural da API difere da do BFF), todos **ainda presentes** na extração de 14/10:

- `GET /usuarios/{x}` é chamado por `/api/compras/comprador-sessao` e `/api/compras/minhas-unidades` com a tela `compras`. Se a API mapear `/usuarios/*` só para a tela `usuarios`, todo comprador comum leva 403.
- `GET /produtos`, `/categorias`, `/contas_correntes`, `/projetos` e `/cotacoes_moeda/atual` são chamados com a tela `compras`.
- `GET /compras/pedidos-venda/{x}/compras` aceita as telas de pedidos (`meus-pedidos`, `pedidos-equipe`, `pcp-pedidos`) **ou** `compras`.
- `/pedidos_venda*`, `/pedido_venda_itens/{x}`, `/vendas_planilha_resumo`, `/itens_pedido_status` e `/faturamento_planilha*` mudam de tela conforme a fonte (Meus pedidos, Pedidos da equipe, Pedidos do PCP; Minhas notas, Notas da equipe, Notas do PCP).

## Ordem para trocar o BFF para Bearer

1. O Gustavo cobre a lista acima em `auth.rotas_telas`, aceitando **todas** as telas que o BFF confere para a mesma rota, e confirma o `escopo_vendedores` de cada perfil (20 dos 21 perfis eram `vinculados` no v1: listas de gerente e PCP podem encolher) ❓.
2. O front troca os helpers por área e testa na `api-test` com um usuário de cada perfil (admin, gerente, vendedor, PCP, comprador).
3. A troca de helpers do v1 de 09/10 (PR #178) já ligou o Bearer em parte de Compras e dos pedidos por fonte; o que sobra são os 70 handlers acima 🟡.

## Como refazer

`node mapa-rotas.js <pasta do HUB> <saida.md>`. O script está no anexo do v1 (`vault-avhub-mer/04-Arquitetura-Transversal/Mapa-Rotas-BFF-API-anexos/mapa-rotas.js`); a saída lista as seções A (a mapear), B (sem Bearer), C (com Bearer) e D (sem chamada). Dono: Nathan.
