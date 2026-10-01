---
tags: [contrato-logica, contrato-api, contrato-pipeline, compras]
criado: 2026-09-30
status: aplicada
---

# Contrato 30 — Compras: dados que faltam no PDF do pedido de compra do Omie

> **✅ ENTREGUE na API (01/10/2026).** Conferido no código da `develop` (`src/routes/pedidos_compras.js`, commit `119634a`): o detalhe devolve `inscricao_estadual_fornecedor`, endereço, `email_fornecedor`, `telefone_fornecedor` e `codigo_produto` por item. **Não testado com dado**: `pedidos_compras` está vazio na `api-test`. Falta no av-hub: o `PedidoOmiePdf.tsx` passar a mostrar esses campos. IE vazia em `core.parceiros` (pipeline) e IPI/ICMS ST seguem em aberto.

**Criado em:** 30/09/2026 · **Para:** backend (`api-acos-vital`) e pipeline (`omie-elt-pipeline`)

Complementa o [[19-Compras-Pedido-Omie-Nomes]] (detalhe do pedido do Omie com os nomes).

---

## 1. Por quê

O av-hub passou a gerar o **PDF do pedido de compra emitido direto no Omie** (branch
`feat/pdf-pedido-omie`, rota `/api/compras/pedidos-omie/[id]/pdf`), com o mesmo desenho da Ordem de
Compra do av-hub. O documento vai para o **fornecedor**.

Em 30/09/2026 ele foi conferido contra o PDF que o próprio Omie imprime (pedido **46871**, Mogi): **todo
valor que aparece nos dois bate** (itens, NCM, quantidade, preço, total, parcela, frete FOB, frete e
seguro zerados, datas, comprador, categoria, conta, projeto, observações). Faltam só os dados abaixo,
que `GET /pedidos_compras/{id}` não devolve. **O av-hub não vai deduzir nem buscar sozinho** (seriam
chamadas extras por item e um JOIN pela unidade feito no navegador, o mesmo problema do contrato 19):
enquanto não vierem, o PDF simplesmente não mostra esses campos.

| No PDF do Omie (46871) | No PDF do av-hub hoje | Onde está o dado |
|---|---|---|
| Endereço do fornecedor (RUA ARUTEC, 303 · JARDIM FAZENDA RINCAO · Arujá - SP · CEP 07428-275) | não aparece | `core.parceiros` (preenchido) |
| E-mail e telefone do fornecedor | não aparece | `core.parceiros` (preenchido) |
| **IE do fornecedor** (188.198.930.112) | não aparece | `core.parceiros.inscricao_estadual` **existe, mas está vazia nos 10.223 parceiros** do banco local |
| **Código do produto** (TBA10680114M) | não aparece | `core.produtos.codigo_produto` pelo `codigo_produto_omie` do item (preenchido) |
| IPI e ICMS ST do pedido | não aparece | **não existe** no espelho `pedidos_compras` |

## 2. O contrato

### 2.1 API — `GET /pedidos_compras/{id}` (aditivo, sem SQL novo)

Mesma regra do contrato 19 / B5: o JOIN usa **sempre o `codigo_empresa` do pedido** (o mesmo
fornecedor/produto tem código diferente em cada conta Omie). Código fora do cadastro da unidade
devolve `null`.

**No pedido** — do fornecedor (`core.parceiros` onde `codigo_parceiro_omie = codigo_fornecedor`), com
os **mesmos nomes de campo que o detalhe da OC já usa** (`GET /compras/ordens/{id}`), para o av-hub
reaproveitar o mesmo bloco do PDF:

| Campo novo | Origem |
|---|---|
| `inscricao_estadual_fornecedor` | `core.parceiros.inscricao_estadual` |
| `logradouro_fornecedor`, `numero_fornecedor`, `complemento_fornecedor`, `bairro_fornecedor`, `cidade_fornecedor`, `uf_fornecedor`, `cep_fornecedor` | `core.parceiros` (`logradouro`, `numero`, `complemento`, `bairro`, `cidade`, `estado`, `cep`) |
| `email_fornecedor`, `telefone_fornecedor` | `core.parceiros` (`email`, `telefone`) |

**Em cada item** (`core.produtos` onde `codigo_produto_omie = item.codigo_produto_omie`):

| Campo novo | Origem |
|---|---|
| `codigo_produto` | `core.produtos.codigo_produto` (ex.: `TBA10680114M`) |

Exemplo (pedido 46871, Mogi):

```json
{
  "numero_pedido": "46871",
  "codigo_fornecedor": "10181860194",
  "razao_social_fornecedor": "M C COMERCIO DE PRODUTOS SIDERURGICOS LTDA",
  "inscricao_estadual_fornecedor": "188.198.930.112",
  "logradouro_fornecedor": "RUA ARUTEC",
  "numero_fornecedor": "303",
  "bairro_fornecedor": "JARDIM FAZENDA RINCAO",
  "cidade_fornecedor": "ARUJA (SP)",
  "uf_fornecedor": "SP",
  "cep_fornecedor": "07428275",
  "email_fornecedor": "contato@colinascontabil.com",
  "telefone_fornecedor": "(11)2134-0037",
  "itens": [
    { "ordem": 1, "codigo_produto_omie": "9767674227", "codigo_produto": "TBA10680114M", "ncm": "73041900", "…": "…" }
  ]
}
```

- Sugestão: os mesmos subselects `literal(...)` que `src/routes/compras_ordens.js` já usa para o
  fornecedor da OC; para o item, um subselect em `core.produtos` no `include` dos itens.

### 2.2 Pipeline — IE do fornecedor e impostos

1. **`core.parceiros.inscricao_estadual`**: está vazia em todos os parceiros. O Omie tem o dado
   (aparece no PDF dele). Carregar do cadastro de clientes/fornecedores do Omie
   (`inscricao_estadual` em `ListarClientes`). Sem isso, o campo do 2.1 volta sempre `null`.
2. **IPI e ICMS ST do pedido de compra**: o espelho `pedidos_compras` / `pedidos_compras_itens` não
   guarda impostos. Se o PDF precisar mostrá-los (o do Omie mostra "IPI: R$ 0,00 · ICMS ST: R$ 0,00"),
   trazer os totais do pedido (e, se fizer sentido, por item) no `ConsultarPedCompra`, com colunas novas
   no espelho e na API. **Pergunta ao Nathan: é necessário?** Enquanto não vier, o av-hub avisa no PDF
   quando o total do Omie não bate com a soma das linhas ("a diferença corresponde a impostos que o
   Omie não envia ao av-hub").

## 3. Perguntas em aberto

- **E-mail de recebimento de NF-e.** O PDF do Omie pede que o fornecedor inclua
  `acosvital@nfe.omie.com.br` entre os destinatários da NF-e. Esse endereço é da conta Omie; o av-hub
  não o conhece nem deve fixá-lo no código. Se for para constar no PDF, ele precisa vir de algum
  cadastro por unidade (ex.: uma coluna em `core.unidades`). Decidir se entra.
- IPI/ICMS ST (item 2.2.2): entra ou não.

## 4. Depois de aplicado (av-hub)

- `lib/domain/compras-ordem.ts`: `PedidoCompraOmieProps` ganha os campos do fornecedor e
  `codigo_produto` no item.
- `lib/compras/PedidoOmiePdf.tsx`: o quadro do fornecedor passa a mostrar IE, endereço, e-mail e
  telefone (mesmo bloco do `OrdemCompraPdf`), e a tabela ganha a coluna **Código**, como no Omie.
- `components/Compras/PedidoOmieDetalhe.tsx`: pode mostrar o código do produto e o endereço do
  fornecedor também na tela.

## 5. Aceite

- `GET /pedidos_compras/{id}` do 46871 devolve o endereço, e-mail e telefone do fornecedor acima, e
  `itens[0].codigo_produto = "TBA10680114M"`.
- Depois do pipeline, `inscricao_estadual_fornecedor = "188.198.930.112"` para o 46871.
- Um pedido de Uberaba com fornecedor/produto que também existe em Mogi resolve os dados **de Uberaba**.
- Código fora do cadastro da unidade devolve `null`, sem quebrar a resposta. Nenhum campo existente
  muda de nome ou de tipo.
- O PDF do av-hub do 46871, gerado de novo, mostra os mesmos dados de fornecedor e o código do produto
  que o PDF do Omie.
