---
tags: [erp-acos-vital, av-hub, comercial, suprimentos, api-comercial]
criado: 2026-10-07
atualizado: 2026-10-08
---

# av-hub — AV Comercial & Suprimentos e o serviço `api-comercial`

> Status: decidido | no código | em produção (verificado em 07/10/2026 pelo dump, onde indicado). Decisões da rodada em [[Registro-de-Decisoes-2026-10-07]].

**Decidido (✅ Nathan, 07/10):** o **orçamento é desenvolvido por fora, neste módulo** (Comercial & Suprimentos); a API entregue (`90bdb33`) existe e os contratos 07 e 38 precisam ser reescritos (item 39). **O Pablo atua aqui** (`api-comercial` e `av-hub`); o MES fica com o Robert (item 32).

> **Rótulos de confiança.** Tudo aqui vem de **leitura de código** no repositório do av-hub (`origin/develop` bd1ae48, 07/10 (reconferido em 08/10; era 996e320); `origin/main` cfed113, #153, 06/10 14:39), na auditoria de 07/10/2026. **Produção e banco não foram conferidos.** "Em `main`" = provável produção, **não verificado**. `[C]` = confirmado no código; `[I]` = inferido.

Este módulo era o maior buraco do vault: o av-hub deixou de ser "só BFF para a `api-acos-vital`" e passou a ter um **segundo backend**, o `api-comercial`, dentro do mesmo repositório. Ver [[AV-Hub-Arquitetura-BFF]] e [[AV-Hub-Visao-Geral]].

## 1. O serviço `api-comercial/` (pasta dentro do repo av-hub)

| Item | Estado (conferido no código) |
|---|---|
| Onde está | Pasta `api-comercial/` do repo av-hub; importada no commit 6a914a0 (05/10). **Só em `develop` — 0 arquivos em `main`.** |
| Stack | Node 22, Express 5, TypeScript ESM, Prisma 7 + PostgreSQL, zod 4, pino, decimal.js, Vitest + supertest. (O Dockerfile do Hub é Node 20; o do `api-comercial` é Node 22.) |
| Container | Dockerfile próprio (porta 3001) e CI própria `.github/workflows/api-comercial.yml`. |
| Banco | Schema **`core_comercial`**, 10 migrations (de `20261001…` a `20261007160000_evento_email_enviado`; em 06/10 eram 9, até `travas_tarefa`). Mesmo cluster do Hub: **[I]** (só se vê `DATABASE_URL`). |
| Migração ao subir | O README diz que o Dockerfile roda `prisma migrate deploy`; o contrato de telas diz para rodar **antes**. **Divergem** — decidir na publicação. |
| Convenções | `If-Match`/ETag em PUT/DELETE/fechar/perder/reabrir (428 sem o header, 409 com versão velha); `Idempotency-Key` em POST de proposta e de solicitação de custo; erro `{detail, codigo, campos}`; valores monetários como `Decimal` em string. |

### Modelos de `core_comercial`

`EmpresaEmissora`, `Proposta` (+ `PropostaItem`, `PropostaEvento`, `PropostaVersao`), `Cliente` (+ `ClienteContato`), `Produto`, `Fornecedor` (+ `ApelidoFornecedor`, `FornecedorCategoria`), `Certificado`, `Oferta`, `ParametroCusto`, `TabelaCustoTelha`, `SolicitacaoCusto`, `OrdemCompra`/`ItemOrdemCompra`, `OmieRegistroBruto`, `SincronizacaoOmie`, `Notificacao`, `Auditoria`, `ChaveIdempotencia`, `TravaTarefa`, `PerfilComercial`.

- Empresas emissoras: **AV, AU, HRM**. Unidades: **MOGI, UBERABA, ARUJA** (como no código). Contas Omie **só MOGI e UBERABA**.

## 2. Autenticação em duas camadas

| Camada | Como funciona |
|---|---|
| 1ª — identidade do Hub | O BFF do av-hub manda `x-api-key` + o **`backendToken`** emitido pela `api-acos-vital` (JWT HS256 com `JWT_SECRET`, ou JWKS; `exp` obrigatório; claim `perfis`). Ver [[AV-Hub-API-Estado-Atual]] e [[AV-Hub-RBAC]]. |
| 2ª — `PerfilComercial` | Dentro do `api-comercial`: o perfil define o **cargo** (vendedor, auxiliar, supervisor, gerente, gerente geral, diretor) e as **capacidades** (escopo das propostas, ver valores, ver custo, excluir, relatório gerencial). |

- Comprador é detectado por regex `/compr|suprimento/i` no **nome do perfil do Hub** — frágil **[I]**: renomear o perfil muda o acesso.
- Pendência declarada no contrato de telas: o token precisa carregar o claim `perfis`.

## 3. Ligação com o resto

| Dado | De onde vem |
|---|---|
| Produtos e fornecedores | Espelho do Omie na `api-acos-vital` (`HUB_API_URL`, rotas `/produtos` e `/parceiros`). Teste de volume com 88.457 produtos. |
| Pedidos de compra | Lidos **direto da API do Omie**, uma app key por conta (MOGI/UBERABA, 06/10) — porque `GET /pedidos_compras` do Hub está vazio na api-test. |
| Sincronização Omie | Automática a cada 15 min (`OMIE_SYNC_INTERVALO_MIN`), com trava no banco (`travas_tarefa`); manual por `npm run omie:sincronizar`. |
| BFF no front | `app/api/comercial/[...rota]/route.ts`; variáveis `COMERCIAL_API_URL` e `COMERCIAL_API_KEY`; cliente em `lib/api/comercialApi.ts` (manda `x-api-key` + Bearer). |

`COMERCIAL_API_KEY` é a chave Hub↔`api-comercial` — **outra** integração, sem relação com as chaves do MES/pipeline (ver [[Chaves-de-Integracao-AvHub-MES-Pipeline]]).

## 4. Rotas do `api-comercial`

| Grupo | Rotas |
|---|---|
| Propostas | CRUD, `calcular`, `resumo`, `fechar` / `perder` / `reabrir`, `duplicar`, `eventos`, `versoes` |
| Clientes | `receita/:cnpj`, `por_documento`, `exportar` |
| Custos | `custos/sugerir`; `solicitacoes_custo` (assumir, liberar, cancelar, responder); `parametros_custo`; `telha/tabela` e `telha/calcular` |
| Ofertas e fornecedores | `ofertas` (invalidar, exportar), `fornecedores` (apelidos, `:id/perfil`), `categorias`, `produtos` (`:id/precos`) |
| Relatórios e painéis | `relatorios/cotacoes`, `relatorios/gerencial`, `dashboards/comercial` |
| Operação | `notificacoes`, `omie/sincronizar` e `omie/sincronizacoes`, `empresas_emissoras`, `responsaveis`, `me` |

## 5. Telas e slugs de `auth.telas`

O BFF aplica uma **allowlist rota × tela × ação** em `auth.telas`: sem a tela cadastrada o resultado é **403** e o item some do menu. O contrato `docs/ENVIAR - contrato-comercial-suprimentos-telas.md` (#138) lista **22 slugs** (reconferido em 08/10 no `develop` `bd1ae48`; eram 18 em 07/10): 2 grupos, 17 telas com página ou bastidor e `matriz-precos` sem tela. Entraram `pedido-cotacao`, `historico-compras`, `pesquisa-materiais` e `tabela-telha`:

| Tipo | Slugs |
|---|---|
| Grupos de menu | `comercial`, `suprimentos` (o `groupMap.ts` coloca os dois em Operações) |
| Telas com página | `propostas`, `clientes`, `relatorio-cotacoes`, `relatorio-gerencial`, `painel-comprador`, `pedido-cotacao`, `ofertas-fornecedor`, `historico-compras`, `fornecedores`, `catalogo-produtos`, `pesquisa-materiais`, `sincronizacao-omie`, `parametros-custo`, `tabela-telha`, `dash-comercial`, `empresas-emissoras` |
| Bastidor (sem página) | `propostas-delegacao`, `custo-item`, `solicitacoes-custo` |
| Sem tela | `matriz-precos` |

Perfis sugeridos: Comercial (Vendedor / Auxiliar / Gestão / Diretoria), Suprimentos (Comprador / Gestão), Qualidade.

**Em produção só constam criadas `suprimentos` e `painel-comprador`** (segundo o vault de 06/10) — **não verificado** contra o banco.

## 6. O que está onde

| Onde | O que |
|---|---|
| **`main`** (PR #116/#120, 02/10) | Propostas (lista, nova, edição), Painel do Comprador, Dashboard Comercial, o BFF e os grupos de menu. **Sem o serviço `api-comercial`** (a pasta não existe em `main`). |
| **Só `develop`** (mergeado em 06/10, 15:53–15:57) | #123 base; #128 telas MVP (Clientes, Relatórios de Cotações e Gerencial com PDF/XLSX, Catálogo, Fornecedores, Ofertas, Sincronização Omie); #133 mapa de fornecedor (importa `MAPA_COTACAO.xlsx`, apelidos); #134 solicitações de custo; #135 duplicar / copiar para outra empresa / revisões; #139 e #140 paridade da proposta (fechar por itens, emitir em nome de outro, especificação técnica, cliente cadastrado, CNPJ na Receita); #143 filtros do histórico; #144 linha do tempo; #145 solicitações no formulário; #146 replicar impostos do 1º item; #147 excluir em lote; #148 exportar contatos; #149 exportar ofertas; #136 sininho de notificações (poll de 60 s); #137 Omie agendada; #150 perfil de compras do fornecedor; #152 configurações (Empresas emissoras, Parâmetros de custo com vigência); #138 documento do contrato de telas. |
| **Branches abertas, não mergeadas** (todas partem de 27fed68, #152) | ver tabela abaixo |

### Branches da rodada de 06–07/10 (reconferido em 08/10)

Todas as 9 branches que o vault listava como abertas em 07/10 **já foram mergeadas na `develop`** (`bd1ae48`): `feat/comercial-cambio`, `feat/comercial-imprimir-lote`, `feat/comercial-itens-planilha`, `feat/suprimentos-categorias-certificados`, `feat/suprimentos-painel-comprador`, `feat/suprimentos-tabela-telha`, `feat/suprimentos-historico-compras`, `feat/suprimentos-pesquisa-materiais` e `test/comercial-e2e`. Também entraram em 07/10:

| Branch / PR | O que traz |
|---|---|
| `feat/comercial-pdf-aprovacao` (#168) | PDF interno de aprovação com custo e margem real por item |
| `feat/comercial-emails` (#170) | envio da proposta e do pedido de cotação por e-mail; SMTP **desligado até configurar**; evento `email_enviado` |
| `feat/suprimentos-produtos-pendentes` (#169) | fila de produtos pendentes e "Ligar ao Omie" no catálogo |
| `feat/suprimentos-exportar-fornecedores` (#167) | exportar fornecedores e copiar e-mails por categoria |
| `feat/suprimentos-historico-mapas` (#166) | histórico de importações do mapa de cotação |
| `perf/comercial-proposta-muitos-itens` (#165) | formulário da proposta rápido com milhares de itens |
| tela de pedido de cotação (`95f24e7`) | nova tela, já no contrato de telas do DBA |
| CI Playwright (`98096b8`, `46146ff`) | e2e do Comercial no GitHub Actions |

O repositório ainda lista dezenas de branches `feat/*` remotas (ex.: `feat/comercial-configuracoes`, `feat/comercial-notificacoes`, `feat/suprimentos-perfil-fornecedor`, `feat/suprimentos-exportar-ofertas`); **não conferi uma a uma se já estão na `develop`**.

## 7. Pendências de publicação

1. **Publicar o `api-comercial`** (nada dele está em `main`; o front de `develop` chama rotas que só existem nele).
2. **Cadastrar as telas** em `auth.telas` (hoje, no vault, só `suprimentos` e `painel-comprador`).
3. **Token com claim `perfis`** na `api-acos-vital`.
4. Resolver a divergência `prisma migrate deploy` no Dockerfile × "rodar antes".

As três primeiras são as pendências **declaradas** no contrato de telas (cadastro das telas, token com `perfis`, publicação do serviço); a quarta foi achada na auditoria.

## 8. CC-08 revisada (ambiente e telas da `api-comercial`)

Pergunta original: em que ambiente vai rodar, em que cluster, com quais perfis/telas e a claim `perfis` ([[Perguntas-em-Aberto-Consolidadas]]). Estado de 07/10 pelo vault e pelo código:
- **Ambiente:** a `api-comercial` existe **só em `develop`**, sem publicação; nenhum ambiente de produção foi decidido (o Registro de 07/10 não trata disso). Cluster Postgres: continua **[I]**.
- **Telas:** dos 22 slugs do contrato (08/10), **20 estão sem cadastro em `auth.telas`** (o dump de 07/10 só tem `suprimentos` e `painel-comprador`; as demais telas novas entraram na `develop` depois ou no mesmo dia do dump); só `suprimentos` e `painel-comprador` constam criadas (vault de 06/10; o dump de 07/10 não foi reconferido aqui para este ponto).
- **Claim `perfis`** no token da `api-acos-vital`: pendente (seção 7).
- Dono da decisão de ambiente: não definido no Registro; segue com Nathan + DBA, como na CC-08.

## Ver também
- [[AV-Hub-Modulos]]
- [[AV-Hub-Arquitetura-BFF]]
- [[AV-Hub-RBAC]]
- [[AV-Hub-API-Estado-Atual]]
- [[Chaves-de-Integracao-AvHub-MES-Pipeline]]
- [[Onde-Estamos]]
- [[Indice-Contratos]]
