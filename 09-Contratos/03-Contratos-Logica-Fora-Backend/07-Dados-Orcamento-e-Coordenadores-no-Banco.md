---
tags: [contrato-logica, contrato-api, orcamento, comissoes]
status: implementada-no-codigo
decisao: orçamento desenvolvido por fora, no módulo Comercial & Suprimentos (✅ 07/10/2026); contrato a reescrever. O "desconsiderado" de 01/10 está superado
criado: 2026-09-20
atualizado: 2026-10-07
---

# Contrato — Dados de Orçamento e de coordenadores no banco (fora do repositório)

> Status: decidido | no código | em produção (verificado em 07/10/2026 só quanto ao que o dump mostra). Fonte: [[Registro-de-Decisoes-2026-10-07]] (#39).

> **✅ Decisão de 07/10/2026 (vale sobre tudo abaixo):** o orçamento foi **desenvolvido por fora, no módulo Comercial & Suprimentos**. A API entregue (`90bdb33`, 01/10, #275) **existe**. O [[38-Regras-Sem-Chave-de-Ambiente]] implementou o orçamento, embora o vault dissesse "desconsiderado". **Este contrato (e o 38) precisam ser reescritos** para refletir isso; o texto abaixo é histórico e não deve ser lido como escopo atual.

> **Histórico — atualização de 07/10/2026 (leitura de código), antes da decisão acima — divergência entre a decisão e o código.** O vault dizia "desconsiderado / não entregue / os JSON ficam". A leitura do código (`origin/main` = `origin/develop` da `api-acos-vital`, `a6ab058`/`fdafb35`) mostra o contrário no lado da API: as rotas `/orcamento/{fornecedores,produtos,cotacoes,vinculos,categorias,familias}` **existem** e leem `core_compras.orc_*` e as views `orc_vw_*`; `GET /dashboard/comissoes` **existe** e usa `fn_dashboard_comissoes` sobre `comissao_coordenadores`. Commit `90bdb33` (01/10/2026, entrou na `main` pelo PR #275); o código cita "migration 007 e carga 007b". **Não é só a parte dos coordenadores** (como a nota de 06/10 abaixo dava a entender): o orçamento inteiro está implementado na API. O que **não** foi conferido: se o DBA aplicou o SQL e a carga 007b no banco (inferência) e se o av-hub migrou as telas (os JSON de `lib/orcamento/data/` e `lib/comissoes/coordenadores.json` podem seguir em uso). **A decisão de 01/10 do Nathan ("desconsiderado") não foi revertida aqui:** o texto abaixo continua como histórico, e **cabe ao Nathan decidir se o contrato volta ao escopo** (cobrar migração das telas e remoção dos JSON do git) ou se segue desconsiderado. Status do frontmatter: `implementada-no-codigo` (API); falta conferir em produção/`api-test`. Ver [[Indice-Contratos]] (Conferência de 07/10/2026) e [[38-Regras-Sem-Chave-de-Ambiente]] §5.

> **Nota de 06/10/2026:** apesar de desconsiderado, a parte dos coordenadores foi implementada na API
> (`90bdb33`, `GET /dashboard/comissoes`), com o bloqueio de comissão atrás da chave
> `COMISSOES_COORDENADORES_BLOQUEIO`. O bloqueio **não se aplica** (decisão do Nathan) e a chave sai no
> [[38-Regras-Sem-Chave-de-Ambiente]]. **(atualizado em 07/10)** a chave saiu no `c8f2f5e` (#279).

> **⛔ (superado em 07/10: ver a decisão no topo) DESCONSIDERADO em 01/10/2026 (decisão do Nathan).** Não será implementado: não cobrar o DBA nem o backend, e não migrar as telas de Orçamento nem o dashboard de comissões. Os JSON em `lib/orcamento/data/` e `lib/comissoes/coordenadores.json` ficam como estão. O texto abaixo é só histórico.

> **Conferido em 29/09/2026: não entregue** (histórico; **superado em 07/10**: as rotas aparecem em `main` com o `90bdb33` de 01/10). O DBA avisou que terminou os contratos desta pasta, mas
> na `api-test` nenhuma rota deste existe (`/orcamento/fornecedores`, `/produtos`, `/cotacoes`,
> `/vinculos`, `/categorias`, `/familias` e `/dashboard/comissoes` respondem "Rota não encontrada"),
> e não há nada de orçamento ou coordenadores na `develop` da API (até `163b58b`). **Voltar ao DBA.**

**Criado em:** 20/09/2026, achado da auditoria de segurança (`docs/seguranca/auditoria-2026-09-19.md`).

**Problema:** dois conjuntos de dados **reais** vivem em arquivos JSON dentro do repositório e são
servidos/filtrados pelo BFF em memória. Na auditoria, ambos estavam sendo entregues num arquivo
JavaScript público; foram movidos para o servidor atrás de permissão, mas isso é só contenção — dado de
negócio pertence ao banco, com permissão e auditoria, e **não deve ser versionado no git**.

## 1. Orçamento (`lib/orcamento/data/*.json`, ~5 MB)

| Arquivo | Conteúdo | Tamanho |
|---|---|---|
| `fornecedores.json` | fornecedores: razão social, CNPJ, e-mail, telefone, endereço | 4,4 MB |
| `historicoPrecos.json` | cotações por produto × fornecedor × data | 270 KB |
| `produtos.json` | catálogo com fornecedor/cotação mais recente | 217 KB |
| `vinculos.json` | categoria × fornecedor (com/sem cadastro) | 78 KB |
| `categorias.json`, `familias.json` | domínios pequenos | < 2 KB |

### Gambiarras que decorrem disso

| # | Gambiarra hoje | Onde |
|---|---|---|
| O1 | Busca de fornecedor (sem acento, primeiros 20) feita **em memória no BFF** sobre o JSON | `lib/orcamento/dados.ts` (`buscarFornecedores`) |
| O2 | Histórico de preços filtrado por produto+fornecedor e **ordenado por data em memória** | `dados.ts` (`historicoPrecos`) |
| O3 | Tela de Fornecedores recebe **a lista inteira (4,4 MB)** a cada carga e filtra/pagina no navegador | `app/api/orcamento/todos-fornecedores`, `services/orcamento/todosFornecedores.ts` |
| O4 | Catálogo de produtos entregue inteiro; filtro por fornecedor/família/descrição no navegador | `app/api/orcamento/produtos` |
| O5 | Os JSON estão no git e no histórico | `lib/orcamento/data/` |

### O que peço

Tabelas no banco (`orc_fornecedores`, `orc_produtos`, `orc_cotacoes`, `orc_vinculos`, `orc_categorias`,
`orc_familias`) e endpoints com **filtro, busca, ordenação e paginação no servidor**:

- `GET /orcamento/fornecedores?q=&estado=&cidade=&sem_cadastro=&sort=&order=&page=&limit=`
- `GET /orcamento/produtos?familia=&fornecedor=&q=&sort=&order=&page=&limit=`
- `GET /orcamento/cotacoes?produto=&fornecedor=&data_inicio=&data_fim=&sort=data_cotacao&order=asc`
- `GET /orcamento/vinculos?categoria=&fornecedor=&sem_cadastro=&page=&limit=`
- `GET /orcamento/categorias` e `/familias` (pequenos)

Permissão por tela (`categorias`, `fornecedores`, `historico-produtos`, `sem-cadastro`, `vinculos`), como
no contrato de permissões. Importação inicial a partir dos JSON atuais, depois **remover os arquivos do
repositório e do histórico**.

## 2. Coordenadores do dashboard de comissões (`lib/comissoes/coordenadores.json`)

Ajuda de custo e percentual de comissão de coordenadores **nominais**, importados como constante.

| #   | Gambiarra hoje                                                                                                   | Onde                                                                         |
| --- | ---------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| C1  | Parâmetros de remuneração de pessoas nominais em arquivo versionado                                              | `lib/comissoes/coordenadores.json`, `coordenadores.ts`                       |
| C2  | A comissão dos coordenadores é **calculada no navegador** (`percentual × faturamento total`) e somada ao ranking | `app/(protected)/dashboards/dash-comissoes/page.tsx` (`mapCoordenadorToRow`) |
| C3  | Ranking de gerência (ordem por total) montado no navegador                                                       | mesma página                                                                 |

### O que peço

Tabela de parâmetros (`comissao_coordenadores`: pessoa, ajuda de custo, percentual, tipo `gerencia|excecao`,
vigência) e o endpoint `GET /dashboard/comissoes` devolvendo `vendedores[]` **e** `coordenadores[]` já com
`comissao`, `total` e `posicao` calculados no banco para o mês, com o mesmo bloqueio de comissão que
os vendedores. Permissão `dash-comissoes`. Remover o JSON do repositório.

## 3. Aceite

- Nenhum dado de fornecedor, cotação ou remuneração em arquivo do repositório ou em resposta que
  entregue mais do que a página pediu.
- Buscar fornecedor devolve no máximo `limit` linhas, ordenadas pelo servidor.
- O ranking de comissões (vendedores e coordenadores) vem pronto e ordenado do backend.
