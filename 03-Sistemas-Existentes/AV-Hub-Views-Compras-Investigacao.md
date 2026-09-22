---
tags: [erp-acos-vital, av-hub, compras, investigacao, achado]
criado: 2026-09-22
---

# Views de Compras (`core_compras`) — investigação: cobrem o futuro módulo de Compras?

> **Pergunta que esta nota fecha**, levantada em [[AV-Hub-Bugs-Catalogo]] ("vale investigar essas views antes de assumir que não existe API própria de compras ainda") e em [[Auditoria-Dump-Producao-2026-09-21]] (seção 4, achado de código morto): as 4 views de `core_compras` (`vw_catalogo_de_produtos`, `vw_fornecedores_com_produtos`, `vw_historico_precos`, `vw_todos_os_fornecedores`) já cobrem, ainda que parcialmente, o que o futuro módulo de Compras (tarefas E1/E2 do [[Cronograma-2-Meses]]) precisa?
>
> **Resposta: não.** Testado empiricamente contra o `api-acos-vital` rodando em Docker local (imagem `api-acos-vital:local`) e um Postgres carregado a partir do dump de produção mais recente (`dump-avhub_prd_db-202609221142.sql`, 22/09/2026, container `omie-test-db`) — não é só leitura de código, é comportamento real observado. Dois motivos independentes, nenhum dos dois é "só falta plugar no frontend":

## 1. As 3 views de catálogo/fornecedor estão genuinely quebradas em runtime

Confirma e vai além do achado de código morto já registrado em [[Auditoria-Dump-Producao-2026-09-21]] (seção 4) — aquele era só leitura de código-fonte; aqui é o erro real, reproduzido chamando a API rodando:

```
$ curl -H "x-api-key: <chave de .env>" "http://localhost:3001/catalogo_de_produtos?limit=5"
HTTP 500 — {"detail":"relation \"negocio.vw_catalogo_de_produtos\" does not exist"}

$ curl -H "x-api-key: <chave de .env>" "http://localhost:3001/fornecedores_com_produtos?limit=5"
HTTP 500 — {"detail":"relation \"negocio.vw_fornecedores_com_produtos\" does not exist"}

$ curl -H "x-api-key: <chave de .env>" "http://localhost:3001/todos_os_fornecedores?limit=5"
HTTP 500 — {"detail":"relation \"negocio.vw_todos_os_fornecedores\" does not exist"}
```

Causa confirmada no código (`src/services/vw_catalogo_de_produtos.js:38`, `vw_fornecedores_com_produtos.js:28`, `vw_todos_os_fornecedores.js:19`): os 3 models Sequelize declaram `schema: "negocio"`, mas o dump de produção confirma que as views moram em `core_compras` — schema `negocio` não existe em lugar nenhum do banco. Nenhum consumidor conseguiria usar essas 3 rotas hoje, em nenhuma circunstância — não é caso de faltar dado, é erro de SQL em toda chamada.

`GET /historico_precos` não expõe o mesmo erro na chamada sem parâmetros — responde `400 {"detail":"Os parâmetros id_produto e id_parceiro são obrigatórios"}` antes de tentar a query — mas usa o mesmo model (`vw_historico_precos.js:16`, também `schema: "negocio"`), então quebraria da mesma forma com parâmetros válidos. As 4 rotas estão na mesma condição.

**Correção, se algum dia isso for revivido**: trocar `schema: "negocio"` por `schema: "core_compras"` nos 4 arquivos de model — mudança de uma linha por arquivo. Não fiz a correção (fora do escopo desta investigação, que é só levantar se a hipótese "views cobrem Compras" se sustenta — não sustenta, então o motivo prático de consertar agora não é forte); mantém o registro em [[AV-Hub-Bugs-Catalogo]] como item de backlog sem urgência, igual já estava.

## 2. Mesmo corrigido o bug, a tabela-fonte não tem nenhum dado

As 4 views são todas derivadas, direta ou indiretamente, de **`core.parceiros_produtos`** — tabela real (`id_parceiro`, `id_produto`, `valor_unidade`, `valor_ipi`, `valor_icms`, `data_cotacao`, `codigo_empresa`, auditoria completa) com **CRUD funcionando de verdade**: `POST/GET/PUT/DELETE /parceiros_produtos` (`src/routes/parceiros_produtos.js`), registrado e ativo, sem o bug de schema dos outros 4 endpoints.

Consultado diretamente no banco carregado a partir do dump de 22/09:

```sql
SELECT (SELECT count(*) FROM core.parceiros_produtos)              AS parceiros_produtos,
       (SELECT count(*) FROM core.produtos)                        AS produtos,
       (SELECT count(*) FROM core.parceiros)                       AS parceiros,
       (SELECT count(*) FROM core_vendas_faturamento.pedidos_compras) AS pedidos_compras;

 parceiros_produtos | produtos | parceiros | pedidos_compras
---------------------+----------+-----------+-----------------
                   0 |    88418 |     10207 |               0
```

`core.parceiros_produtos` — a tabela de cotação de preço fornecedor↔produto, a única fonte real de dado das 4 views — **tem zero linhas**, apesar do catálogo de produtos (88.418) e o cadastro de parceiros (10.207) estarem cheios de dado real sincronizado do Omie. Ninguém está usando o endpoint de cotação manual hoje. Mesmo com o bug de schema corrigido, as 4 views voltariam vazias.

## 3. Achado adicional: `core_compras.produtos_compras` também não tem implementação nenhuma

A outra tabela do schema `core_compras` (vínculo simples produto↔fornecedor, `id_produto` + `codigo_empresa`, sem mais nenhuma coluna) também tem **zero linhas** e, diferente de `parceiros_produtos`, **não tem nenhum model nem rota implementados** — a única referência no código inteiro é um comentário:

```js
// src/app.js:94
// fazer futuramente: produtos_compras
```

Confirma o que [[Schema-Postgres-Multi-Dominio]] já registrava ("não existe sistema de compras real hoje no av-hub") — inclusive a estrutura mínima planejada para isso (`produtos_compras`) nunca saiu do estágio de comentário no código.

## 4. Conclusão — a hipótese está fechada

**As views de `core_compras` não cobrem, nem parcialmente, o futuro módulo de Compras.** Três motivos independentes, não um só:

1. 3 das 4 rotas estão genuinamente quebradas (erro de SQL em toda chamada, confirmado em runtime).
2. Mesmo corrigidas, ficariam vazias — a tabela-fonte de cotação não tem nenhum dado real hoje.
3. Mesmo populadas, seriam só **catálogo de referência com preço** (read-only) — nunca cobririam requisição, aprovação ou fechamento de Ordem de Compra, que é o que as tarefas E1/E2 e o contrato SQL [[007-Ordens-Compra-Estruturada]] já endereçam à parte. Não há sobreposição de escopo a resolver entre esta investigação e o trabalho já planejado.

**Achado positivo, não previsto na pergunta original**: `core.parceiros_produtos` + `/parceiros_produtos` (CRUD) já é uma peça real e funcional — cotação manual de preço por fornecedor/produto, schema correto, sem bug. É candidato natural a alimentar o módulo **Orçamento** (hoje 100% em JSON local, sem API própria, ver [[AV-Hub-Modulos]]) sem esperar pelo módulo de Compras novo — só ninguém a usa ainda. Vale uma conversa de produto (fora do escopo desta nota) sobre se o Orçamento deveria passar a gravar cotações reais aqui em vez de manter o JSON mockado.

## 5. Decisão do Nathan (22/09/2026): o conteúdo do `core_compras` foi apagado — o schema fica, os dados de dentro são refeitos

Diante da conclusão da seção 4, o Nathan decidiu apagar o conteúdo do schema `core_compras` (as 4 views quebradas + `produtos_compras`, que nunca teve implementação). **O nome do schema continua sendo `core_compras`** — não é criado um schema novo; o Gustavo vai reconstruir os dados de dentro dele de forma estruturada, formato ainda não definido. **Confirmado pelo Nathan em 22/09/2026 que o Gustavo já executou a remoção em produção.** Isso resolve o achado de código morto de [[Auditoria-Dump-Producao-2026-09-21]] (seção 4) por remoção, não por correção do bug de schema — mais simples, já que as views não tinham consumidor real (seção 2 e 3 acima).

> **Nota de verificação**: o dump/container local usado nesta investigação (`dump-avhub_prd_db-202609221142.sql`, 22/09 11:42) é uma cópia anterior a esta remoção — consultar esse ambiente local ainda mostra o `core_compras` antigo (com `produtos_compras` e as 4 views). Não é contradição com a confirmação acima, é só uma cópia mais antiga que a produção atual; não reflete mais o estado real do banco.

**Não confundir a reconstrução de `core_compras` com nada do que já existe:**
- Não é `core_vendas_faturamento.pedidos_compras` ([[004-Pedidos-Compras]]) — espelho read-only do histórico de pedidos de compra do Omie, schema/tabela diferente, sem relação com esta decisão.
- Não é `core_vendas_faturamento.ordens_compra` ([[007-Ordens-Compra-Estruturada]]) — a OC estruturada que o av-hub decide e cria (tarefa E2), também schema/tabela diferente.

**O que vai entrar no `core_compras` reconstruído ainda não foi definido nesta conversa** — esta nota só registra a decisão de apagar o conteúdo antigo; o desenho das tabelas novas é trabalho à parte, a documentar quando o Gustavo/Nathan fecharem o formato (fica como pendência, não assumir nada sobre suas colunas até então).

**Impacto no código morto confirmado**: agora que o conteúdo antigo do `core_compras` foi apagado, os 4 endpoints GET que quebravam com `relation "negocio.vw_..." does not exist` (`/catalogo_de_produtos`, `/fornecedores_com_produtos`, `/historico_precos`, `/todos_os_fornecedores` — `src/app.js:1665-1668`) apontam para views que **não existem mais de forma alguma** (nem no schema errado `negocio`, nem no `core_compras` certo, que já não as tem) — ainda mais motivo para **remover do código** (rotas + services + imports), não só deixar quebrado. Ver [[AV-Hub-Bugs-Catalogo]].

## Ver também
- [[AV-Hub-Bugs-Catalogo]] — item que motivou esta investigação, atualizado com a conclusão
- [[Auditoria-Dump-Producao-2026-09-21]] — achado original de código morto (leitura de código)
- [[Auditoria-Dump-Producao-2026-09-22]]
- [[Schema-Postgres-Multi-Dominio]]
- [[Fluxo-Compras-Completo]]
- [[007-Ordens-Compra-Estruturada]]
- [[AV-Hub-Modulos]]
