# Contrato — Relação Produto ↔ Fornecedor (pro Simulador de Comissão)

**Criado em:** 10/09/2026, horário de Brasília

**Objetivo:** o "Simulador de Comissão" (protótipo local em
`app/(protected)/orcamento/simulador-comissao`, ainda não conectado a nenhuma API própria)
deixa o vendedor escolher um produto do catálogo e depois buscar um fornecedor pra aquele
item. O pedido original era filtrar essa busca pra mostrar **só os fornecedores que atendem
aquele produto específico** — investiguei os dados disponíveis (mock e reais) e não existe
hoje nenhuma relação que sustente esse filtro com confiança. Este contrato registra o que
falta pro dia em que o módulo de compras/orçamento ganhar uma API própria.

---

## 1. O que existe hoje (e por que não serve)

Todo o módulo `orcamento/*` roda sobre JSON local (`app/(protected)/orcamento/_data/*.json`),
sem API própria — os comentários nos services (`services/orcamento/*.ts`) já deixam isso
explícito ("Dados mockados — sem requisição real até existir uma API própria do módulo de
compras"). Dentro desse mock:

- **`produtos.json`** (catálogo, 400 itens): cada produto tem exatamente **um** fornecedor —
  o da compra mais recente (`nome_fantasia`, `id_parceiro_mais_recente`). Não é uma relação
  1-para-N, é 1-para-1.
- **`historicoPrecos.json`** (2.697 linhas): são pontos no tempo do **mesmo** fornecedor de
  cada produto. Conferi programaticamente — dos 269 produtos com mais de uma cotação no
  histórico, **nenhum** tem mais de um `id_parceiro` distinto.
- **`vinculos.json`** (234 linhas, usado em `orcamento/fornecedores`): liga fornecedor a uma
  **categoria** ampla (16 valores: BARRAS, CHAPAS, CONEXÕES, FIXADORES, GALVANIZAÇÃO,
  INDUSTRIALIZAÇÃO, LAMINADOS, METAIS, PEAD, PINTURA, PLACAS, PLASTICOS, TELAS, TUBOS A/C,
  TUBOS INOX, VALVULAS).
- Produtos, por sua vez, usam **família** (`familia`, 25 valores, mais granular:
  "CONEXÃO TUBULAR CARBONO", "CONEXÃO TUBULAR INOX", "FLANGE CARBONO", "FLANGE INOX", "TUBO
  COM COSTURA", "TUBO SEM COSTURA" etc., além de várias famílias administrativas sem nada a
  ver com produto físico: "ATIVO FIXO", "SERVIÇOS TOMADOS", "Seguros"...).

**Categoria (vínculos) e família (produtos) são taxonomias diferentes, sem mapeamento**
registrado em lugar nenhum. Dava pra tentar aproximar por palavra-chave (ex: familia contendo
"CHAPA" → categoria "CHAPAS"), mas isso quebra em vários casos — não existe categoria
"FLANGES" pra família "FLANGE CARBONO"/"FLANGE INOX", e "TUBO COM/SEM COSTURA" é ambíguo entre
"TUBOS A/C" e "TUBOS INOX" (depende do material, que não está no nome da família). Optei por
não implementar esse match aproximado: numa ferramenta que decide comissão, mostrar um
fornecedor "sugerido" errado é pior do que não sugerir nada.

## 2. O que peço pra quando o módulo de compras ganhar API própria

Uma relação real produto↔fornecedor, N-para-N (o mesmo produto pode ter vários fornecedores
que já o forneceram; o mesmo fornecedor atende vários produtos):

```sql
-- Sugestão de forma, ajustar nomes conforme o schema real do módulo de compras:
CREATE TABLE compras.produto_fornecedor (
  id_produto    uuid NOT NULL REFERENCES compras.produtos(id),
  id_fornecedor uuid NOT NULL REFERENCES compras.fornecedores(id),
  ultima_cotacao       numeric,
  data_ultima_cotacao  date,
  total_cotacoes       integer,
  PRIMARY KEY (id_produto, id_fornecedor)
);
```

Se já existir uma tabela de histórico de compras/cotações granular (nota fiscal de entrada,
pedido de compra etc.) com `id_produto` + `id_fornecedor`, provavelmente dá pra materializar
essa relação a partir dela via `GROUP BY`, sem precisar de tabela nova — nesse caso prefiro que
o DBA aponte a fonte certa em vez de eu propor uma tabela do zero.

### 2.1 Endpoint

```
GET /produtos/:id/fornecedores
→ 200 [{ "id_fornecedor": "uuid", "nome_fantasia": "text", "razao_social": "text",
         "cnpj": "text", "ultima_cotacao": number, "data_ultima_cotacao": "date" }]
```

## 3. O que muda no frontend quando isso existir

No `simulador-comissao`, a busca de fornecedor (hoje um modal de busca livre por nome/CNPJ em
todo o catálogo) passa a abrir já filtrada pelos fornecedores de `GET /produtos/:id/fornecedores`
do produto selecionado no item, com a busca livre continuando disponível como aba/opção
secundária — pro caso de um fornecedor novo, ainda sem histórico pra aquele produto.

## 4. Não bloqueia o protótipo

Isso não impede o simulador de continuar sendo testado — a busca por nome/CNPJ em todo o
catálogo já cobre o uso prático (o vendedor sabe qual fornecedor quer, só não tinha como
digitar/ver o nome completo antes). Este contrato é só a lacuna de dado pra virar um filtro de
verdade, não um bloqueio.
