---
tipo: mapa
criado: 2026-10-09
atualizado: 2026-10-09
---

# Mapa de rotas do BFF para a API: quem chama com Bearer e quem não

> Status: no código (av-hub `develop` `a402d78`, extração de 09/10/2026) | em produção (não verificado). Pedido do Nathan para o Gustavo mapear em `auth.rotas_telas`. Contexto: [[Auditoria-Pente-Fino-2026-10-08]] (item 10) e [[Registro-de-Decisoes-2026-10-07]].

## Para que serve
A API aplica `PERMISSOES_ROTA_MODO=exigir` (fixo desde 08/10) e `ESCOPO_VENDEDORES_EXIGIR` (a fixar) **só quando a chamada traz Bearer**. Hoje parte do BFF do av-hub chama só com `x-api-key`; quando passar a mandar o token do usuário, cada rota da seção A precisa ter linha em `auth.rotas_telas`, senão o usuário leva 403 `ROTA_SEM_PERMISSAO_MAPEADA`.

## Números
- **189 rotas do BFF** (`app/api/**/route.ts`), **265 handlers** (método por rota).
- **232 handlers chamam uma API**; **168 já com Bearer** (`headersComIdentidade`, que cai para só `x-api-key` quando a sessão não tem token) e **64 sem Bearer** (`headersCompras`, `headersApi` ou `x-api-key` inline).
- Dos 64, **43 são rotas únicas da API do Hub** (seção A). As chamadas ao `api-comercial` ficam fora da seção A: ele tem controle próprio (`PerfilComercial`) e não passa por `auth.rotas_telas`.
- 33 handlers não chamam a API (respondem no próprio BFF ou usam helper que a extração não resolveu): seção D.

## Como ler a seção A
- **Tela(s) e ação exigidas no BFF** é o que o BFF confere hoje com `requirePermission`. A linha de `auth.rotas_telas` deve aceitar **todas as telas listadas** para a mesma rota, senão quem passa no BFF levará 403 na API. Quando a coluna mostra várias telas separadas por `|`, são alternativas por fonte (equipe, PCP, vendedor).
- `{x}` é um parâmetro de caminho.

## Pares de risco (a tela natural da API difere da tela do BFF)
Pontos onde o mapeamento "óbvio" quebraria usuários que hoje funcionam:
- `GET /usuarios/{x}` é chamado por `/api/compras/comprador-sessao` e `/api/compras/minhas-unidades` com a tela **`compras`**. Se a API mapear `/usuarios/*` só para a tela `usuarios`, todo comprador comum leva 403.
- `GET /produtos`, `/categorias`, `/contas_correntes`, `/projetos`, `/cotacoes_moeda/atual` são chamados com a tela **`compras`**; as telas "naturais" desses cadastros são outras.
- `GET /compras/pedidos-venda/{x}/compras` aceita as telas **de pedidos** (`meus-pedidos`, `pedidos-equipe`, `pcp-pedidos`) **ou** `compras`.
- `/pedidos_venda*`, `/pedido_venda_itens/{x}`, `/vendas_planilha_resumo`, `/itens_pedido_status`, `/faturamento_planilha*` mudam de tela conforme a **fonte** (Meus pedidos, Pedidos da equipe, Pedidos do PCP; Minhas notas, Notas da equipe, Notas do PCP).
- `GET /compras/compradores` é chamado com `compras (criar)`, `compradores (visualizar)` e `compras (visualizar)`.

## Antes de trocar o BFF para Bearer (ordem)
1. O Gustavo cobre a seção A em `auth.rotas_telas` (aceitando as telas listadas) e confirma o `escopo_vendedores` de cada perfil: **20 dos 21 perfis são `vinculados`**, então listas de gerente e PCP podem encolher quando o escopo valer.
2. O front troca os helpers por área e testa na `api-test` com um usuário de cada perfil (admin, gerente, vendedor, PCP, comprador).
3. Só então se fixa `ESCOPO_VENDEDORES_EXIGIR`. Atenção: o `backendToken` dura 15 minutos e não renova depois de expirar; quem fica ocioso volta a chamar só com a chave.

## Limites desta extração
Foi feita por regex sobre o código: pode errar o método quando o `fetch` está em helper, não resolve caminhos montados por função (marcados `via helper` ou `dinâmico`) e a tela de rotas com variável aparece como "tela definida em código". **Conferir cada linha no arquivo antes de agir.** Para refazer: `node mapa-rotas.js <pasta do av-hub> <saida.md>` (anexo `Mapa-Rotas-BFF-API-anexos/mapa-rotas.js`).
## A. Rotas da API a mapear em `auth.rotas_telas` (hoje chamadas SEM Bearer)

| Método | Caminho na API | Tela(s) e ação exigidas no BFF | Rotas do BFF que chamam |
|---|---|---|---|
| GET | `/categorias` (api-acos-vital) | compras (visualizar) | `/api/compras/categorias` |
| GET | `/compras/acompanhamento` (api-acos-vital) | followup (visualizar) | `/api/compras/acompanhamento` |
| GET | `/compras/compradores` (api-acos-vital) | compras (criar); compradores (visualizar); compras (visualizar) | `/api/compras/comprador-sessao`, `/api/compras/compradores`, `/api/compras/minhas-unidades` |
| GET | `/compras/compradores/{x}` (api-acos-vital) | compradores (visualizar) | `/api/compras/compradores/{id}` |
| PUT | `/compras/compradores/{x}` (api-acos-vital) | compradores (editar) | `/api/compras/compradores/{id}` |
| GET | `/compras/compradores/{x}/sugestoes` (api-acos-vital) | compradores (editar) | `/api/compras/compradores/{id}/sugestoes` |
| GET | `/compras/condicoes-pagamento  (via helper)` (api-acos-vital) | compras (visualizar) | `/api/compras/condicoes-pagamento` |
| GET | `/compras/fornecedores` (api-acos-vital) | compras (visualizar) | `/api/compras/fornecedores` |
| PATCH | `/compras/ocorrencias/{x}` (api-acos-vital) | followup (aprovar) | `/api/compras/ocorrencias/{id}` |
| GET | `/compras/ordens` (api-acos-vital) | compras (visualizar) | `/api/compras/ordens` |
| POST | `/compras/ordens` (api-acos-vital) | compras (criar) | `/api/compras/ordens` |
| GET | `/compras/ordens/{x}` (api-acos-vital) | compras (visualizar) | `/api/compras/ordens/{id}/pdf`, `/api/compras/ordens/{id}` |
| PATCH | `/compras/ordens/{x}` (api-acos-vital) | compras (aprovar) | `/api/compras/ordens/{id}` |
| GET | `/compras/ordens/{x}/acompanhamento` (api-acos-vital) | followup (visualizar) | `/api/compras/ordens/{id}/acompanhamento` |
| PUT | `/compras/ordens/{x}/acompanhamento` (api-acos-vital) | followup (editar) | `/api/compras/ordens/{id}/acompanhamento` |
| POST | `/compras/ordens/{x}/contatos` (api-acos-vital) | followup (editar) | `/api/compras/ordens/{id}/contatos` |
| POST | `/compras/ordens/{x}/ocorrencias` (api-acos-vital) | followup (editar) | `/api/compras/ordens/{id}/ocorrencias` |
| POST | `/compras/ordens/{x}/reenviar` (api-acos-vital) | compras (editar) | `/api/compras/ordens/{id}/reenviar` |
| GET | `/compras/ordens/dashboard` (api-acos-vital) | compras (visualizar) | `/api/compras/dashboard` |
| GET | `/compras/ordens/resumo` (api-acos-vital) | compras (visualizar) | `/api/compras/ordens/resumo` |
| GET | `/compras/parametros` (api-acos-vital) | compras (visualizar) | `/api/compras/parametros` |
| GET | `/compras/pedidos-venda/{x}` (api-acos-vital) | compras (visualizar) | `/api/compras/pedidos-venda/{numero}` |
| GET | `/compras/pedidos-venda/{x}/compras` (api-acos-vital) | meus-pedidos \| pedidos-equipe \| pcp-pedidos \| compras (visualizar) | `/api/compras/pedidos-venda/{numero}/compras` |
| GET | `/compras/requisicoes` (api-acos-vital) | compras (visualizar) | `/api/compras/requisicoes` |
| POST | `/compras/requisicoes` (api-acos-vital) | compras (criar) | `/api/compras/requisicoes` |
| GET | `/compras/requisicoes/{x}` (api-acos-vital) | compras (visualizar) | `/api/compras/requisicoes/{id}` |
| PATCH | `/compras/requisicoes/{x}` (api-acos-vital) | compras (editar) | `/api/compras/requisicoes/{id}` |
| GET | `/compras/requisicoes/resumo{x}` (api-acos-vital) | compras (visualizar) | `/api/compras/requisicoes/resumo` |
| GET | `/compras/transportadoras` (api-acos-vital) | compras (visualizar) | `/api/compras/transportadoras` |
| GET | `/contas_correntes  (via helper)` (api-acos-vital) | compras (visualizar) | `/api/compras/contas-correntes` |
| GET | `/cotacoes_moeda/atual` (api-acos-vital) | compras (visualizar) | `/api/compras/cotacao` |
| GET | `/faturamento_planilha` (api-acos-vital) | notas-equipe \| pcp-notas \| minhas-notas (visualizar) | `/api/notas-fiscais/{fonte}` |
| GET | `/faturamento_planilha_resumo` (api-acos-vital) | notas-equipe \| pcp-notas \| minhas-notas (visualizar) | `/api/notas-fiscais/{fonte}/composicao` |
| GET | `/itens_pedido_status` (api-acos-vital) | pedidos-equipe \| pcp-pedidos \| meus-pedidos (visualizar) | `/api/pedidos-venda/{fonte}/{codigoEmpresa}/{pedidoVenda}/etapas` |
| GET | `/pedido_venda_itens/{x}` (api-acos-vital) | pedidos-equipe \| pcp-pedidos \| meus-pedidos (visualizar) | `/api/pedidos-venda/{fonte}/{codigoEmpresa}/{pedidoVenda}/itens` |
| GET | `/pedidos_compras/{x}` (api-acos-vital) | compras (visualizar) | `/api/compras/pedidos-omie/{id}/pdf`, `/api/compras/pedidos-omie/{id}` |
| GET | `/pedidos_venda` (api-acos-vital) | pedidos-equipe \| pcp-pedidos \| meus-pedidos (visualizar) | `/api/pedidos-venda/{fonte}` |
| GET | `/pedidos_venda/{x}/{x}` (api-acos-vital) | pedidos-equipe \| pcp-pedidos \| meus-pedidos (visualizar) | `/api/pedidos-venda/{fonte}/{codigoEmpresa}/{pedidoVenda}/etapas`, `/api/pedidos-venda/{fonte}/{codigoEmpresa}/{pedidoVenda}/itens`, `/api/pedidos-venda/{fonte}/{codigoEmpresa}/{pedidoVenda}` |
| GET | `/pedidos_venda/resumo` (api-acos-vital) | pedidos-equipe \| pcp-pedidos \| meus-pedidos (visualizar) | `/api/pedidos-venda/{fonte}/resumo` |
| GET | `/produtos` (api-acos-vital) | compras (visualizar) | `/api/compras/produtos` |
| GET | `/projetos  (via helper)` (api-acos-vital) | compras (visualizar) | `/api/compras/projetos` |
| GET | `/usuarios/{x}` (api-acos-vital) | compras (criar); compras (visualizar) | `/api/compras/comprador-sessao`, `/api/compras/minhas-unidades` |
| GET | `/vendas_planilha_resumo` (api-acos-vital) | pedidos-equipe \| pcp-pedidos \| meus-pedidos (visualizar) | `/api/pedidos-venda/{fonte}/composicao` |

## B. Detalhe por rota do BFF: SEM Bearer hoje

| Rota do BFF | Método do BFF | Chamada à API | Tela exigida no BFF | Cabeçalho |
|---|---|---|---|---|
| `/api/comercial/propostas/{id}/aprovacao` | GET | GET `/propostas/{x}  (via helper)` (api-comercial) | propostas (visualizar) | ? |
| `/api/comercial/propostas/{id}/email` | POST | POST `/propostas/{x}  (via helper)` (api-comercial) | propostas (visualizar) | ? |
| `/api/comercial/propostas/{id}/email` | POST | POST `/empresas_emissoras  (via helper)` (api-comercial) | propostas (visualizar) | ? |
| `/api/comercial/propostas/{id}/email` | POST | POST `/propostas/{x}/email  (via helper)` (api-comercial) | propostas (visualizar) | ? |
| `/api/comercial/propostas/{id}/pdf` | GET | GET `/comercial/propostas/{x}  (via helper)` (api-comercial) | propostas (visualizar) | ? |
| `/api/comercial/propostas/{id}/pdf` | GET | GET `/comercial/propostas  (via helper)` (api-comercial) | propostas (visualizar) | ? |
| `/api/comercial/propostas/{id}/pdf` | GET | GET `/propostas/{x}  (via helper)` (api-comercial) | propostas (visualizar) | ? |
| `/api/comercial/propostas/{id}/pdf` | GET | GET `/empresas_emissoras  (via helper)` (api-comercial) | propostas (visualizar) | ? |
| `/api/comercial/propostas/itens/exportar` | POST | POST `/propostas/itens/exportar  (via helper)` (api-comercial) | propostas (visualizar) | ? |
| `/api/comercial/propostas/itens/importar` | POST | POST `/propostas/itens/importar  (via helper)` (api-comercial) | propostas (visualizar) | ? |
| `/api/comercial/propostas/lote/pdf` | GET | GET `/comercial/propostas  (via helper)` (api-comercial) | propostas (visualizar) | ? |
| `/api/comercial/propostas/lote/pdf` | GET | GET `/propostas/{x}  (via helper)` (api-comercial) | propostas (visualizar) | ? |
| `/api/comercial/propostas/lote/pdf` | GET | GET `/empresas_emissoras  (via helper)` (api-comercial) | propostas (visualizar) | ? |
| `/api/comercial/relatorios/{tipo}/pdf` | GET | GET `/comercial/relatorio-{x}  (via helper)` (api-comercial) | (teladefinidaemcódigo) (visualizar) | ? |
| `/api/compras/acompanhamento` | GET | GET `/compras/acompanhamento` (api-acos-vital) | followup (visualizar) | só x-api-key |
| `/api/compras/categorias` | GET | GET `/categorias` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/comprador-sessao` | GET | GET `/usuarios/{x}` (api-acos-vital) | compras (criar) | só x-api-key |
| `/api/compras/comprador-sessao` | GET | GET `/compras/compradores` (api-acos-vital) | compras (criar) | só x-api-key |
| `/api/compras/compradores` | GET | GET `/compras/compradores` (api-acos-vital) | compradores (visualizar) | só x-api-key |
| `/api/compras/compradores/{id}` | GET | GET `/compras/compradores/{x}` (api-acos-vital) | compradores (visualizar) | só x-api-key |
| `/api/compras/compradores/{id}` | PUT | PUT `/compras/compradores/{x}` (api-acos-vital) | compradores (editar) | só x-api-key |
| `/api/compras/compradores/{id}/sugestoes` | GET | GET `/compras/compradores/{x}/sugestoes` (api-acos-vital) | compradores (editar) | só x-api-key |
| `/api/compras/condicoes-pagamento` | GET | GET `/compras/condicoes-pagamento  (via helper)` (api-acos-vital) | compras (visualizar) | ? |
| `/api/compras/contas-correntes` | GET | GET `/contas_correntes  (via helper)` (api-acos-vital) | compras (visualizar) | ? |
| `/api/compras/cotacao` | GET | GET `/cotacoes_moeda/atual` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/dashboard` | GET | GET `/compras/ordens/dashboard` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/fornecedores` | GET | GET `/compras/fornecedores` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/minhas-unidades` | GET | GET `/usuarios/{x}` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/minhas-unidades` | GET | GET `/compras/compradores` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/ocorrencias/{id}` | PATCH | PATCH `/compras/ocorrencias/{x}` (api-acos-vital) | followup (aprovar) | só x-api-key |
| `/api/compras/ordens` | GET | GET `/compras/ordens` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/ordens` | POST | POST `/compras/ordens` (api-acos-vital) | compras (criar) | só x-api-key |
| `/api/compras/ordens/{id}` | GET | GET `/compras/ordens/{x}` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/ordens/{id}` | PATCH | PATCH `/compras/ordens/{x}` (api-acos-vital) | compras (aprovar) | só x-api-key |
| `/api/compras/ordens/{id}/acompanhamento` | GET | GET `/compras/ordens/{x}/acompanhamento` (api-acos-vital) | followup (visualizar) | só x-api-key |
| `/api/compras/ordens/{id}/acompanhamento` | PUT | PUT `/compras/ordens/{x}/acompanhamento` (api-acos-vital) | followup (editar) | só x-api-key |
| `/api/compras/ordens/{id}/contatos` | POST | POST `/compras/ordens/{x}/contatos` (api-acos-vital) | followup (editar) | só x-api-key |
| `/api/compras/ordens/{id}/ocorrencias` | POST | POST `/compras/ordens/{x}/ocorrencias` (api-acos-vital) | followup (editar) | só x-api-key |
| `/api/compras/ordens/{id}/pdf` | GET | GET `/compras/ordens/{x}` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/ordens/{id}/reenviar` | POST | POST `/compras/ordens/{x}/reenviar` (api-acos-vital) | compras (editar) | só x-api-key |
| `/api/compras/ordens/resumo` | GET | GET `/compras/ordens/resumo` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/parametros` | GET | GET `/compras/parametros` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/pedidos-omie/{id}` | GET | GET `/pedidos_compras/{x}` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/pedidos-omie/{id}/pdf` | GET | GET `/pedidos_compras/{x}` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/pedidos-venda/{numero}` | GET | GET `/compras/pedidos-venda/{x}` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/pedidos-venda/{numero}/compras` | GET | GET `/compras/pedidos-venda/{x}/compras` (api-acos-vital) | meus-pedidos \| pedidos-equipe \| pcp-pedidos \| compras (visualizar) | só x-api-key |
| `/api/compras/produtos` | GET | GET `/produtos` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/projetos` | GET | GET `/projetos  (via helper)` (api-acos-vital) | compras (visualizar) | ? |
| `/api/compras/requisicoes` | GET | GET `/compras/requisicoes` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/requisicoes` | POST | POST `/compras/requisicoes` (api-acos-vital) | compras (criar) | só x-api-key |
| `/api/compras/requisicoes/{id}` | GET | GET `/compras/requisicoes/{x}` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/requisicoes/{id}` | PATCH | PATCH `/compras/requisicoes/{x}` (api-acos-vital) | compras (editar) | só x-api-key |
| `/api/compras/requisicoes/resumo` | GET | GET `/compras/requisicoes/resumo{x}` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/compras/transportadoras` | GET | GET `/compras/transportadoras` (api-acos-vital) | compras (visualizar) | só x-api-key |
| `/api/notas-fiscais/{fonte}` | GET | GET `/faturamento_planilha` (api-acos-vital) | notas-equipe \| pcp-notas \| minhas-notas (visualizar) | só x-api-key |
| `/api/notas-fiscais/{fonte}/composicao` | GET | GET `/faturamento_planilha_resumo` (api-acos-vital) | notas-equipe \| pcp-notas \| minhas-notas (visualizar) | só x-api-key |
| `/api/pedidos-venda/{fonte}` | GET | GET `/pedidos_venda` (api-acos-vital) | pedidos-equipe \| pcp-pedidos \| meus-pedidos (visualizar) | só x-api-key |
| `/api/pedidos-venda/{fonte}/{codigoEmpresa}/{pedidoVenda}` | GET | GET `/pedidos_venda/{x}/{x}` (api-acos-vital) | pedidos-equipe \| pcp-pedidos \| meus-pedidos (visualizar) | só x-api-key |
| `/api/pedidos-venda/{fonte}/{codigoEmpresa}/{pedidoVenda}/etapas` | GET | GET `/pedidos_venda/{x}/{x}` (api-acos-vital) | pedidos-equipe \| pcp-pedidos \| meus-pedidos (visualizar) | só x-api-key |
| `/api/pedidos-venda/{fonte}/{codigoEmpresa}/{pedidoVenda}/etapas` | GET | GET `/itens_pedido_status` (api-acos-vital) | pedidos-equipe \| pcp-pedidos \| meus-pedidos (visualizar) | só x-api-key |
| `/api/pedidos-venda/{fonte}/{codigoEmpresa}/{pedidoVenda}/itens` | GET | GET `/pedidos_venda/{x}/{x}` (api-acos-vital) | pedidos-equipe \| pcp-pedidos \| meus-pedidos (visualizar) | só x-api-key |
| `/api/pedidos-venda/{fonte}/{codigoEmpresa}/{pedidoVenda}/itens` | GET | GET `/pedido_venda_itens/{x}` (api-acos-vital) | pedidos-equipe \| pcp-pedidos \| meus-pedidos (visualizar) | só x-api-key |
| `/api/pedidos-venda/{fonte}/composicao` | GET | GET `/vendas_planilha_resumo` (api-acos-vital) | pedidos-equipe \| pcp-pedidos \| meus-pedidos (visualizar) | só x-api-key |
| `/api/pedidos-venda/{fonte}/resumo` | GET | GET `/pedidos_venda/resumo` (api-acos-vital) | pedidos-equipe \| pcp-pedidos \| meus-pedidos (visualizar) | só x-api-key |

## C. Detalhe por rota do BFF: COM Bearer hoje

| Rota do BFF | Método do BFF | Chamada à API | Tela exigida no BFF | Cabeçalho |
|---|---|---|---|---|
| `/api/auxiliarVendedor` | GET | GET `/auxiliar_vendedor` (api-acos-vital) | auxiliares-vendedor (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/auxiliarVendedor` | POST | POST `/auxiliar_vendedor` (api-acos-vital) | auxiliares-vendedor (criar) | Bearer (cai para x-api-key sem token) |
| `/api/auxiliarVendedor/{id}` | DELETE | DELETE `/auxiliar_vendedor/{x}` (api-acos-vital) | auxiliares-vendedor (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/blacklist_pedidos` | GET | GET `/blacklist_pedidos` (api-acos-vital) | blacklist_pedidos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/blacklist_pedidos` | POST | POST `/blacklist_pedidos` (api-acos-vital) | blacklist_pedidos (criar) | Bearer (cai para x-api-key sem token) |
| `/api/blacklist_pedidos/{numero}` | PUT | PUT `/blacklist_pedidos/{x}{x}` (api-acos-vital) | blacklist_pedidos (editar) | Bearer (cai para x-api-key sem token) |
| `/api/blacklist_pedidos/{numero}` | DELETE | DELETE `/blacklist_pedidos/{x}{x}` (api-acos-vital) | blacklist_pedidos (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/blacklist_vendedores` | GET | GET `/blacklist_vendedores_g5` (api-acos-vital) | blacklist_vendedores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/blacklist_vendedores` | POST | POST `/blacklist_vendedores_g5` (api-acos-vital) | blacklist_vendedores (criar) | Bearer (cai para x-api-key sem token) |
| `/api/blacklist_vendedores/{termo}` | PUT | PUT `/blacklist_vendedores_g5/{x}` (api-acos-vital) | blacklist_vendedores (editar) | Bearer (cai para x-api-key sem token) |
| `/api/blacklist_vendedores/{termo}` | DELETE | DELETE `/blacklist_vendedores_g5/{x}` (api-acos-vital) | blacklist_vendedores (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/cargos` | GET | GET `/cargos` (api-acos-vital) | cargos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/cargos` | POST | POST `/cargos` (api-acos-vital) | cargos (criar) | Bearer (cai para x-api-key sem token) |
| `/api/cargos/{id}` | PUT | PUT `/cargos/{x}` (api-acos-vital) | cargos (editar) | Bearer (cai para x-api-key sem token) |
| `/api/cargos/{id}` | DELETE | DELETE `/cargos/{x}` (api-acos-vital) | cargos (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/blacklist-clientes` | GET | GET `/blacklist_comissoes_destinatario` (api-acos-vital) | blacklist-clientes (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/blacklist-clientes` | POST | POST `/blacklist_comissoes_destinatario` (api-acos-vital) | blacklist-clientes (criar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/blacklist-clientes/{codigoCliente}` | PUT | PUT `/blacklist_comissoes_destinatario/{x}` (api-acos-vital) | blacklist-clientes (editar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/blacklist-clientes/{codigoCliente}` | DELETE | DELETE `/blacklist_comissoes_destinatario/{x}` (api-acos-vital) | blacklist-clientes (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/blacklist-vendedores` | GET | GET `/blacklist_comissoes_vendedores` (api-acos-vital) | blacklist-vendedores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/blacklist-vendedores` | POST | POST `/blacklist_comissoes_vendedores` (api-acos-vital) | blacklist-vendedores (criar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/blacklist-vendedores/{codigoVendedorOmie}` | PUT | PUT `/blacklist_comissoes_vendedores/{x}` (api-acos-vital) | blacklist-vendedores (editar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/blacklist-vendedores/{codigoVendedorOmie}` | DELETE | DELETE `/blacklist_comissoes_vendedores/{x}` (api-acos-vital) | blacklist-vendedores (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/bloqueio-comissoes` | GET | GET `/bloqueio_comissoes` (api-acos-vital) | bloqueio-comissoes (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/bloqueio-comissoes/{numeroNf}` | PUT | PUT `/bloqueio_comissoes/{x}` (api-acos-vital) | bloqueio-comissoes (editar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/bloqueio-comissoes/{numeroNf}` | DELETE | DELETE `/bloqueio_comissoes/{x}` (api-acos-vital) | bloqueio-comissoes (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/minhas-comissoes` | GET | GET `/faturamento_planilha` (api-acos-vital) | minhas-comissoes (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/minhas-comissoes` | GET | GET `/simulacao_resolvida` (api-acos-vital) | minhas-comissoes (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/minhas-comissoes` | GET | GET `/simulacoes` (api-acos-vital) | minhas-comissoes (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/regras-comissoes-fixas` | GET | GET `/regras_comissoes_fixas` (api-acos-vital) | regras-comissoes-fixas (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/regras-comissoes-fixas` | POST | POST `/regras_comissoes_fixas` (api-acos-vital) | regras-comissoes-fixas (criar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/regras-comissoes-fixas/{id}` | PUT | PUT `/regras_comissoes_fixas/{x}` (api-acos-vital) | regras-comissoes-fixas (editar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/regras-comissoes-fixas/{id}` | DELETE | DELETE `/regras_comissoes_fixas/{x}` (api-acos-vital) | regras-comissoes-fixas (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/simulacoes` | GET | GET `/simulacoes` (api-acos-vital) | simulador \| analise-simuladores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/simulacoes` | POST | POST `/simulacoes` (api-acos-vital) | simulador \| analise-simuladores (criar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/simulador/itens` | GET | GET `/pedido_venda_itens/{x}` (api-acos-vital) | simulador \| analise-simuladores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/simulador/parametros` | GET | GET `/simulador_parametros` (api-acos-vital) | simulador (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/simulador/parametros/{id}` | GET | GET `/simulador_parametros/{x}` (api-acos-vital) | simulador \| analise-simuladores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/simulador/pedidos` | GET | GET `/pedidos_vendas` (api-acos-vital) | simulador (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/simulador/unidades` | GET | GET `/unidades` (api-acos-vital) | simulador \| analise-simuladores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/vendedores-comissao` | GET | GET `/vendedores` (api-acos-vital) | vendedores-comissao (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/vendedores-comissao/{id}` | PUT | PUT `/vendedores/{x}` (api-acos-vital) | vendedores-comissao (editar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/visao-geral` | GET | GET `/comissoes_nf` (api-acos-vital) | visao-geral (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/visao-geral` | GET | GET `/comissoes_resumo_mensal` (api-acos-vital) | visao-geral (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/visao-geral/itens` | GET | GET `/comissoes_master` (api-acos-vital) | visao-geral (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/comissoes/visao-geral/itens` | GET | GET `/simulacoes/{x}` (api-acos-vital) | visao-geral (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/compras/unidades` | GET | GET `/unidades` (api-acos-vital) | compras \| compradores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard-equipe` | GET | GET `/dashboard/equipe` (api-acos-vital) | dashboard-equipe (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/comissoes/comissoes-provisorias` | GET | GET `/comissoes_provisoria` (api-acos-vital) | dash-comissoes (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/faturamento` | GET | GET `/dashboard_mensal_faturamento` (api-acos-vital) | dash-faturamento \| fechamento (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/faturamento/detalhe-vendedor` | GET | GET `/detalhe_vendedor_faturamento` (api-acos-vital) | dash-faturamento (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/faturamento/faturamento-por-tipo` | GET | GET `/vendas_faturadas_por_tipo` (api-acos-vital) | dash-faturamento-por-tipo \| dash-faturamento (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/faturamento/ranking-clientes` | GET | GET `/ranking_clientes_faturamento` (api-acos-vital) | dash-faturamento (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/faturamento/ranking-vendedores` | GET | GET `/ranking_vendedores_faturamento` (api-acos-vital) | dash-faturamento (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/faturamento/resumo-mensal` | GET | GET `/faturamento_resumo_mensal` (api-acos-vital) | dash-faturamento (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/faturamento/ritmo-de-meta` | GET | GET `/ritmo_meta_faturamento` (api-acos-vital) | dash-faturamento (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/faturamento/situacao-pedidos` | GET | GET `/situacao_pedidos` (api-acos-vital) | dash-faturamento (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/unidades` | GET | GET `/unidades` (api-acos-vital) | — | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/vendas` | GET | GET `/dashboard_mensal_vendas` (api-acos-vital) | dash-vendas \| fechamento (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/vendas/detalhe-vendedor` | GET | GET `/detalhe_vendedor_vendas` (api-acos-vital) | dash-vendas (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/vendas/ranking-clientes` | GET | GET `/ranking_clientes_vendas` (api-acos-vital) | dash-vendas (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/vendas/ranking-vendedores` | GET | GET `/ranking_vendedores_vendas` (api-acos-vital) | dash-vendas (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/vendas/ritmo-de-meta` | GET | GET `/ritmo_meta_vendas` (api-acos-vital) | dash-vendas (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/dashboard/vendas/vendas-por-tipo` | GET | GET `/vendas_por_tipo_contrato` (api-acos-vital) | dash-vendas-por-tipo \| dash-vendas (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/diligenciadores/referencias` | GET | GET `/funcionarios` (api-acos-vital) | diligenciadores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/diligenciadores/referencias` | GET | GET `/vendedores` (api-acos-vital) | diligenciadores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/diligenciadorVendedor` | GET | GET `/diligenciador_vendedor` (api-acos-vital) | diligenciadores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/diligenciadorVendedor` | POST | POST `/diligenciador_vendedor` (api-acos-vital) | diligenciadores (criar) | Bearer (cai para x-api-key sem token) |
| `/api/diligenciadorVendedor/{id}` | DELETE | DELETE `/diligenciador_vendedor/{x}` (api-acos-vital) | diligenciadores (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/etapas_faturamento` | GET | GET `/etapas_faturamento` (api-acos-vital) | pedidos-equipe \| notas-equipe \| meus-pedidos \| pcp-pedidos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/familias` | GET | GET `/familias_produtos` (api-acos-vital) | historico-produtos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/fechamento-manual` | GET | GET `/fechamento_manual` (api-acos-vital) | fechamento (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/fechamento-manual` | POST | POST `/fechamento_manual` (api-acos-vital) | fechamento (criar) | Bearer (cai para x-api-key sem token) |
| `/api/fechamento-manual/{ano}/{mes}/{tipo}` | DELETE | DELETE `/fechamento_manual/{x}/{x}/{x}` (api-acos-vital) | fechamento (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/funcionarios` | GET | GET `/funcionarios` (api-acos-vital) | funcionarios (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/funcionarios` | POST | POST `/funcionarios` (api-acos-vital) | funcionarios (criar) | Bearer (cai para x-api-key sem token) |
| `/api/funcionarios/{id}` | GET | GET `/funcionarios/{x}` (api-acos-vital) | funcionarios (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/funcionarios/{id}` | PUT | PUT `/funcionarios/{x}` (api-acos-vital) | funcionarios (editar) | Bearer (cai para x-api-key sem token) |
| `/api/funcionarios/{id}` | DELETE | DELETE `/funcionarios/{x}` (api-acos-vital) | funcionarios (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/funcionarios/{id}/equipe` | GET | GET `/funcionarios/{x}/equipe` (api-acos-vital) | funcionarios (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/funcionarios/resumo` | GET | GET `/funcionarios/resumo` (api-acos-vital) | funcionarios (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/historicoProdutos` | GET | GET `/catalogo_de_produtos` (api-acos-vital) | historico-produtos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/historicoProdutos/historico` | GET | GET `/historico_precos` (api-acos-vital) | historico-produtos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/liberar-pedidos` | GET | GET `/pedidos_liberacao` (api-acos-vital) | — | Bearer (cai para x-api-key sem token) |
| `/api/liberar-pedidos/{codigoEmpresa}/{numeroPedido}` | PUT | PUT `/pedidos_liberacao` (api-acos-vital) | liberar-pedidos (editar) | Bearer (cai para x-api-key sem token) |
| `/api/liberar-pedidos/{codigoEmpresa}/{numeroPedido}` | PUT | PUT `/pedidos_liberacao/{x}/{x}` (api-acos-vital) | liberar-pedidos (editar) | Bearer (cai para x-api-key sem token) |
| `/api/menu` | GET | GET `/permissoes_usuario/menu/{x}` (api-acos-vital) | — | Bearer (cai para x-api-key sem token) |
| `/api/metas-mensais` | GET | GET `/metas_mensais` (api-acos-vital) | metas-mensais \| fechamento (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/metas-mensais` | POST | POST `/metas_mensais` (api-acos-vital) | metas-mensais (criar) | Bearer (cai para x-api-key sem token) |
| `/api/metas-mensais/{ano}/{mes}/{tipo}` | PUT | POST `/metas_mensais` (api-acos-vital) | metas-mensais (editar) | Bearer (cai para x-api-key sem token) |
| `/api/metas-mensais/{ano}/{mes}/{tipo}` | DELETE | DELETE `/metas_mensais/{x}/{x}/{x}` (api-acos-vital) | metas-mensais (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/meu-dashboard` | GET | GET `/dashboard/vendedor` (api-acos-vital) | meu-dashboard (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/meus-favoritos` | GET | GET `/usuarios/{x}/favoritos` (api-acos-vital) | meus-pedidos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/meus-favoritos` | POST | POST `/usuarios/{x}/favoritos` (api-acos-vital) | meus-pedidos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/meus-favoritos/{id}` | DELETE | DELETE `/usuarios/{x}/favoritos/{x}` (api-acos-vital) | meus-pedidos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/meus-pedidos/{codigo_pedido_omie}/status-historico` | GET | GET `/pedidos_vendas/{x}` (api-acos-vital) | meus-pedidos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/meus-pedidos/{codigo_pedido_omie}/status-historico` | GET | GET `/pedidos_vendas/{x}/status-historico` (api-acos-vital) | meus-pedidos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/minhas-notas` | GET | GET `/faturamento_planilha` (api-acos-vital) | minhas-notas (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/niveis-hierarquicos` | GET | GET `/niveis_hierarquicos` (api-acos-vital) | cargos \| funcionarios \| organograma (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/notas-equipe` | GET | GET `/faturamento_planilha` (api-acos-vital) | notas-equipe (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/notas-fiscais-saida` | GET | GET `/nota_fiscal_saida` (api-acos-vital) | notas-fiscais-saida (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/notas-manuais` | GET | GET `/nota_fiscal_saida` (api-acos-vital) | notas-fiscais-manuais (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/notas-manuais` | POST | POST `/nota_fiscal_saida/manual` (api-acos-vital) | notas-fiscais-manuais (criar) | Bearer (cai para x-api-key sem token) |
| `/api/organograma_nodes` | POST | POST `/organograma_nodes` (api-acos-vital) | funcionarios (criar) | Bearer (cai para x-api-key sem token) |
| `/api/organograma_nodes/{id}` | GET | GET `/organograma_nodes/{x}` (api-acos-vital) | funcionarios (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/organograma_nodes/{id}` | PUT | PUT `/organograma_nodes/{x}` (api-acos-vital) | funcionarios (editar) | Bearer (cai para x-api-key sem token) |
| `/api/organograma_nodes/{id}` | DELETE | DELETE `/organograma_nodes/{x}` (api-acos-vital) | funcionarios (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/parceiros` | GET | GET `/parceiros` (api-acos-vital) | parceiros (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/parceiros` | POST | POST `/parceiros` (api-acos-vital) | parceiros (criar) | Bearer (cai para x-api-key sem token) |
| `/api/parceiros/{id}` | PUT | PUT `/parceiros/{x}` (api-acos-vital) | parceiros (editar) | Bearer (cai para x-api-key sem token) |
| `/api/parceiros/{id}` | DELETE | DELETE `/parceiros/{x}` (api-acos-vital) | parceiros (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/parceiros/fornecedores` | GET | GET `/fornecedores_com_produtos` (api-acos-vital) | fornecedores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/parceiros/todosFornecedores` | GET | GET `/todos_os_fornecedores` (api-acos-vital) | fornecedores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/pcp/dashboard` | GET | GET `/dashboard/pcp` (api-acos-vital) | pcp-dashboard (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/pcp/notas` | GET | GET `/faturamento_planilha` (api-acos-vital) | pcp-notas (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/pcp/observacoes` | GET | GET `/pedido_observacao_pcp` (api-acos-vital) | pcp-pedidos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/pcp/observacoes` | POST | POST `/pedido_observacao_pcp` (api-acos-vital) | pcp-pedidos (criar) | Bearer (cai para x-api-key sem token) |
| `/api/pcp/observacoes/{id}` | DELETE | DELETE `/pedido_observacao_pcp/{x}` (api-acos-vital) | pcp-pedidos (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/pcp/pedidos/{codigo_pedido_omie}/status-historico` | GET | GET `/pedidos_vendas/{x}` (api-acos-vital) | pcp-pedidos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/pcp/pedidos/{codigo_pedido_omie}/status-historico` | GET | GET `/pedidos_vendas/{x}/status-historico` (api-acos-vital) | pcp-pedidos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/pedidos-equipe/{codigo_pedido_omie}/status-historico` | GET | GET `/pedidos_vendas/{x}/status-historico` (api-acos-vital) | pedidos-equipe (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/pedidos-venda` | GET | GET `/pedidos_vendas` (api-acos-vital) | pedidos-de-venda (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/pedidos/blacklist` | GET | GET `/blacklist_pedidos` (api-acos-vital) | pedidos-equipe \| pcp-pedidos \| meus-pedidos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/perfis` | GET | GET `/perfis` (api-acos-vital) | perfis (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/perfis` | POST | POST `/perfis` (api-acos-vital) | perfis (criar) | Bearer (cai para x-api-key sem token) |
| `/api/perfis/{id}` | PUT | PUT `/perfis/{x}` (api-acos-vital) | perfis (editar) | Bearer (cai para x-api-key sem token) |
| `/api/perfis/{id}` | DELETE | DELETE `/perfis/{x}` (api-acos-vital) | perfis (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/permissoes` | GET | GET `/permissoes` (api-acos-vital) | permissoes (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/permissoes` | POST | POST `/permissoes` (api-acos-vital) | permissoes (criar) | Bearer (cai para x-api-key sem token) |
| `/api/permissoes/{id}` | PUT | PUT `/permissoes/{x}` (api-acos-vital) | permissoes (editar) | Bearer (cai para x-api-key sem token) |
| `/api/permissoes/{id}` | DELETE | DELETE `/permissoes/{x}` (api-acos-vital) | permissoes (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/permissoes/bulk` | POST | POST `/permissoes/lote` (api-acos-vital) | permissoes (criar) | Bearer (cai para x-api-key sem token) |
| `/api/produtos` | GET | GET `/produtos` (api-acos-vital) | produtos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/setores` | GET | GET `/setores` (api-acos-vital) | setores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/setores` | POST | POST `/setores` (api-acos-vital) | setores (criar) | Bearer (cai para x-api-key sem token) |
| `/api/setores/{id}` | PUT | PUT `/setores/{x}` (api-acos-vital) | setores (editar) | Bearer (cai para x-api-key sem token) |
| `/api/setores/{id}` | DELETE | DELETE `/setores/{x}` (api-acos-vital) | setores (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/telas` | GET | GET `/telas` (api-acos-vital) | telas (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/telas` | POST | POST `/telas` (api-acos-vital) | telas (criar) | Bearer (cai para x-api-key sem token) |
| `/api/telas/{id}` | PUT | PUT `/telas/{x}` (api-acos-vital) | telas (editar) | Bearer (cai para x-api-key sem token) |
| `/api/telas/{id}` | DELETE | DELETE `/telas/{x}` (api-acos-vital) | telas (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/unidades` | GET | GET `/unidades` (api-acos-vital) | unidades \| pcp-pedidos (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/unidades` | POST | POST `/unidades` (api-acos-vital) | unidades (criar) | Bearer (cai para x-api-key sem token) |
| `/api/unidades/{id}` | PUT | PUT `/unidades/{x}` (api-acos-vital) | unidades (editar) | Bearer (cai para x-api-key sem token) |
| `/api/unidades/{id}` | DELETE | DELETE `/unidades/{x}` (api-acos-vital) | unidades (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/usuarios` | GET | GET `/usuarios` (api-acos-vital) | usuarios (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/usuarios` | POST | POST `/usuarios` (api-acos-vital) | usuarios (criar) | Bearer (cai para x-api-key sem token) |
| `/api/usuarios/{id}` | DELETE | DELETE `/usuarios/{x}` (api-acos-vital) | usuarios (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/usuarios/{id}` | PUT | PUT `/usuarios/{x}` (api-acos-vital) | usuarios (editar) | Bearer (cai para x-api-key sem token) |
| `/api/usuarios/{id}` | PATCH | PATCH `/usuarios/{x}/senha` (api-acos-vital) | usuarios (editar) | Bearer (cai para x-api-key sem token) |
| `/api/usuarios/{id}/unidades` | GET | GET `/usuarios/{x}/unidades` (api-acos-vital) | usuarios (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/usuarios/{id}/unidades` | PUT | PUT `/usuarios/{x}/unidades` (api-acos-vital) | usuarios (editar) | Bearer (cai para x-api-key sem token) |
| `/api/usuariosPerfis` | GET | GET `/usuarios_perfis` (api-acos-vital) | usuarios-perfis (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/usuariosPerfis` | POST | POST `/usuarios_perfis` (api-acos-vital) | usuarios-perfis (criar) | Bearer (cai para x-api-key sem token) |
| `/api/usuariosPerfis/{id_usuario}/{id_perfil}` | DELETE | DELETE `/usuarios_perfis/{x}/{x}` (api-acos-vital) | usuarios-perfis (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/vagas` | GET | GET `/vagas` (api-acos-vital) | solicitacoes-de-vagas (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/vagas` | POST | POST `/vagas` (api-acos-vital) | solicitacoes-de-vagas (criar) | Bearer (cai para x-api-key sem token) |
| `/api/vagas/{id}` | GET | GET `/vagas/{x}` (api-acos-vital) | solicitacoes-de-vagas (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/vagas/{id}` | PUT | PUT `/vagas/{x}` (api-acos-vital) | solicitacoes-de-vagas (editar) | Bearer (cai para x-api-key sem token) |
| `/api/vagas/{id}` | DELETE | DELETE `/vagas/{x}` (api-acos-vital) | solicitacoes-de-vagas (deletar) | Bearer (cai para x-api-key sem token) |
| `/api/vagas/{id}/decisao` | POST | POST `/vagas/{x}/decisao` (api-acos-vital) | solicitacoes-de-vagas (aprovar) | Bearer (cai para x-api-key sem token) |
| `/api/vagas/{id}/decisoes` | GET | GET `/vagas/{x}/decisoes` (api-acos-vital) | solicitacoes-de-vagas (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/vagas/resumo` | GET | GET `/vagas/resumo` (api-acos-vital) | solicitacoes-de-vagas (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/vendedores` | GET | GET `/vendedores` (api-acos-vital) | vendedores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/vendedores/{id}` | GET | GET `/vendedores/{x}` (api-acos-vital) | vendedores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/vendedores/{id}` | PUT | PUT `/vendedores/{x}` (api-acos-vital) | vendedores (editar) | Bearer (cai para x-api-key sem token) |
| `/api/vendedores/{id}/sugestoes` | GET | GET `/vendedores/{x}/sugestoes` (api-acos-vital) | vendedores (visualizar) | Bearer (cai para x-api-key sem token) |
| `/api/vendedores/usuarios` | GET | GET `/usuarios` (api-acos-vital) | vendedores (editar) | Bearer (cai para x-api-key sem token) |

## D. Handlers sem chamada identificada à API

| Rota do BFF | Método | Tela exigida no BFF |
|---|---|---|
| `/api/comercial/clientes/exportar` | GET | clientes (visualizar) |
| `/api/comercial/fornecedores/exportar` | GET | fornecedores (visualizar) |
| `/api/comercial/ofertas/exportar` | GET | ofertas-fornecedor (visualizar) |
| `/api/comercial/ofertas/importar-mapa` | POST | ofertas-fornecedor (criar) |
| `/api/comercial/pesquisa-materiais/pdf` | GET | pesquisa-materiais (visualizar) |
| `/api/comercial/relatorios/{tipo}/xlsx` | GET | (teladefinidaemcódigo) (visualizar) |
| `/api/comissoes/simulacoes/{id}` | GET | simulador \| analise-simuladores (visualizar) |
| `/api/comissoes/simulacoes/{id}` | PUT | simulador \| analise-simuladores (editar) |
| `/api/comissoes/simulacoes/{id}` | DELETE | simulador (deletar) |
| `/api/compras/compradores/funcionarios` | GET | compradores (editar) |
| `/api/dashboard-equipe/cliente` | GET | dashboard-equipe (visualizar) |
| `/api/dashboard-equipe/resultados` | GET | dashboard-equipe (visualizar) |
| `/api/dashboard/comissoes/coordenadores` | GET | dash-comissoes (visualizar) |
| `/api/meu-dashboard/cliente` | GET | meu-dashboard (visualizar) |
| `/api/meus-pedidos/resumo` | GET | meus-pedidos (visualizar) |
| `/api/minhas-notas/resumo` | GET | minhas-notas (visualizar) |
| `/api/notas-equipe/resumo` | GET | notas-equipe (visualizar) |
| `/api/notas-manuais/{codigo}` | PUT | notas-fiscais-manuais (editar) |
| `/api/notas-manuais/{codigo}` | DELETE | notas-fiscais-manuais (deletar) |
| `/api/notas-manuais/apoio` | GET | notas-fiscais-manuais (visualizar) |
| `/api/orcamento/categorias` | GET | — |
| `/api/orcamento/familias` | GET | — |
| `/api/orcamento/fornecedores` | GET | — |
| `/api/orcamento/historico-precos` | GET | — |
| `/api/orcamento/produtos` | GET | — |
| `/api/orcamento/todos-fornecedores` | GET | — |
| `/api/orcamento/vinculos` | GET | — |
| `/api/pcp/notas/resumo` | GET | pcp-notas (visualizar) |
| `/api/pcp/pedidos/resumo` | GET | pcp-pedidos (visualizar) |
| `/api/pcp/vendedores` | GET | pcp-dashboard \| pcp-pedidos \| pcp-notas (visualizar) |
| `/api/pedidos-equipe/resumo` | GET | pedidos-equipe (visualizar) |
| `/api/uploads` | POST | — |
| `/api/vendedores/funcionarios` | GET | vendedores (editar) |
