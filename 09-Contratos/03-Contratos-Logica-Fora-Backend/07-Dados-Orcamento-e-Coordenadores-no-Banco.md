# Contrato — Dados de Orçamento e de coordenadores no banco (fora do repositório)

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

| # | Gambiarra hoje | Onde |
|---|---|---|
| C1 | Parâmetros de remuneração de pessoas nominais em arquivo versionado | `lib/comissoes/coordenadores.json`, `coordenadores.ts` |
| C2 | A comissão dos coordenadores é **calculada no navegador** (`percentual × faturamento total`) e somada ao ranking | `app/(protected)/dashboards/dash-comissoes/page.tsx` (`mapCoordenadorToRow`) |
| C3 | Ranking de gerência (ordem por total) montado no navegador | mesma página |

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
