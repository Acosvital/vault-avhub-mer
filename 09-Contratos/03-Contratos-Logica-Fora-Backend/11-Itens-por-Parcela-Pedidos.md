# Pedido de melhoria — dizer a que PARCELA (sequencial) cada item de `vw_pedido_venda_itens` pertence

**Criado em:** 19/09/2026, a partir da página do pedido em Pedidos da Equipe
(`/pedidos-equipe-v2/pedido/{empresa}/{pedido}`), que precisa mostrar os produtos de cada parcela.

**Não é bug — é uma melhoria de API/view.** Hoje a view de itens só sabe responder "quais
são os produtos do PEDIDO INTEIRO". Não existe jeito, nem no banco nem na API, de saber quais
desses produtos são de qual parcela. Não dá pra resolver no frontend sem chutar (seção 3).

---

## 1. O que existe hoje

`GET /pedido_venda_itens/{numero_pedido}?codigo_empresa=…&is_track_record=false`
(view `core_vendas_faturamento.vw_pedido_venda_itens`) devolve o cabeçalho + os itens
aninhados em `produtos`, no **grão de família**: um cabeçalho por (empresa, numero_pedido) com
os itens de TODOS os sequenciais misturados (a própria rota documenta isso).

Já o `GET /vendas_planilha` devolve **uma linha por parcela** (`sequencial` 0, 1, 2…), cada uma
com seu `codigo_pedido_omie` e seu `total_pedido_venda`. É assim que a tela lista parcelas
(cabeçalho + entregas) e mostra situação/etapa/valor de cada uma.

O que falta é a ponte entre as duas coisas: **item → parcela**.

## 2. Evidência (produção, pedido 27645, empresa `759979bd-2b2d-41f2-b1b7-db6fae89ee59`)

**Parcelas** (`GET /vendas_planilha?pedido_venda=27645`):

| sequencial | `total_pedido_venda` | etapa | `nota_fiscal` |
|---|---|---|---|
| 0 | 1.226.900,00 | Liberado Compras | 00052396 |
| 1 | 193.200,00 | Faturado | 00052396 |
| 2 | 177.744,00 | Faturado | 00052396 |
| 3 | 112.056,00 | Separar Estoque | 00052396 |
| 4 | 187.500,00 | Separar Estoque | 00052396 |
| **soma** | **1.897.400,00** | | |

**Itens** (`GET /pedido_venda_itens/27645?codigo_empresa=…&is_track_record=false`):
`total_produtos: 10`, `soma_valor_itens: "1897400.00"` — bate exato com a soma das parcelas, o
que confirma que os itens de TODAS as parcelas estão ali, só que sem identificação:

```
codigo_item_omie  descricao                      qtd    valor_total  numero_nf
10465100408       CHAPA A/C 1000MM X 2000MM …    20000  193200.00    00052213
10467014723       CHAPA A/C 1000MM X 2000MM …    18400  177744.00    00052396
10453620571       CHAPA A/C 1000MM X 2000MM …    30000  289800.00    null
10453622401       CHAPA A/C 1000MM X 2000MM …    30000  289800.00    null
10467222221       CHAPA A/C 1000MM X 2000MM …    11600  112056.00    null
10453640478       KIT CHAPA AC SAE1020 …            10   14000.00    null
10453639377       KIT CHAPA AC SAE1020 …             5  187500.00    null   ← mesmo valor…
10467222684       KIT CHAPA AC SAE1020 …             5  187500.00    null   ← …que este
10453630672       CHAPA A/C 1020 1000MM X 20…    30000  222900.00    null
10453625135       CHAPA A/C 1020 1000MM X 20…    30000  222900.00    null
```

Consultando por parcela:

```
GET /pedido_venda_itens/27645?codigo_empresa=…&sequencial=0  → 200, os MESMOS 10 itens (família)
GET /pedido_venda_itens/27645?codigo_empresa=…&sequencial=1  → 404 "sem itens sincronizados"
GET /pedido_venda_itens/27645?codigo_empresa=…&sequencial=2  → 404
GET /pedido_venda_itens/27645?codigo_empresa=…&sequencial=3  → 404
```

Ou seja: o parâmetro `sequencial` existe mas não separa nada (o 0 devolve a família toda e os
demais dão 404). E os campos disponíveis não resolvem:

- `numero_nf` só vem preenchido em 2 dos 10 itens (só os já faturados).
- `nota_fiscal` em `/vendas_planilha` repete o mesmo número (`00052396`) nas 5 parcelas,
  inclusive nas ainda não faturadas — não identifica a parcela.
- O item não traz `codigo_pedido_omie` nem `sequencial` de origem.

## 3. Por que não dá pra resolver no frontend

Tentamos reconstruir por **conciliação de valores** (achar o conjunto de itens cuja soma é o
total de cada parcela, preferindo os `codigo_item_omie` mais altos). Em setembro/2026 conciliou
27 de 28 pedidos parcelados — mas:

- **Ambiguidade real:** no 27645 há dois itens idênticos de R$ 187.500,00 (`10453639377` e
  `10467222684`). Só um é da parcela 4, o outro é do cabeçalho. Escolher pelo id mais alto
  acerta aqui, mas é uma regra inventada, não um dado.
- **Falha em pedido real:** o 27787 (30 itens, 1 parcela de R$ 97.542,62) não concilia.
- Qualquer mudança de arredondamento, desconto ou item cancelado quebra a conta em silêncio, e a
  tela passaria a mostrar produto na parcela errada sem nenhum aviso.

Decidimos **não mostrar produtos por parcela até existir o dado de verdade.**

## 4. O que peço

O dado já existe na origem: no Omie cada parcela é um pedido próprio, com o próprio
`codigo_pedido_omie` e a própria lista `det[]` de itens. A view/sync está juntando tudo no grão
de família e perdendo a origem. Peço **uma** das duas opções (a critério do backend):

**Opção A — aditiva, sem quebrar o simulador (preferida).** Em `vw_pedido_venda_itens`, incluir
em cada linha de `produtos`:

| campo | descrição |
|---|---|
| `codigo_pedido_omie` | do pedido/parcela de ORIGEM do item (o mesmo de `/vendas_planilha`) |
| `sequencial` | sequencial dessa parcela (0 = pedido original) |

O comportamento atual (grão de família, filtro `sequencial`) **não muda** — só ganha as duas
colunas. Quem quiser os itens de uma parcela filtra no cliente por `sequencial`; ou, se preferirem
que o servidor filtre, aceitar `?sequencial=N` devolvendo os itens daquela parcela quando a nova
coluna existir (o 404 de hoje para `sequencial` > 0 deixaria de acontecer).

**Opção B — endpoint por parcela.** `GET /vendas_planilha/{codigo_pedido_omie}/itens` (ou
`GET /pedido_venda_itens?codigo_pedido_omie={id}`), devolvendo só os itens daquela parcela, com os
mesmos campos que a view já expõe hoje (`codigo_item_omie`, `codigo_produto`, `descricao`,
`quantidade`, `unidade_medida`, `valor_unitario`, `valor_total`, `cfop`, `ncm`, `numero_nf`,
`codigo_nf_omie`).

## 5. Como saber que ficou certo (critérios de aceite)

Com o pedido 27645 da empresa `759979bd-2b2d-41f2-b1b7-db6fae89ee59`:

1. Agrupando os itens por `sequencial`, a **soma de `valor_total` de cada grupo é exatamente o
   `total_pedido_venda`** da linha correspondente em `/vendas_planilha`:
   `0 → 1.226.900,00`, `1 → 193.200,00`, `2 → 177.744,00`, `3 → 112.056,00`, `4 → 187.500,00`.
2. Os dois itens de R$ 187.500,00 caem em sequenciais diferentes (`0` e `4`).
3. A soma de todos os itens continua `1.897.400,00` (nada some nem duplica), e o simulador de
   comissão continua funcionando sem alteração.
4. O 27787 (que a conciliação por valor não resolve) também passa na conferência do item 1.
5. Regra geral, vale pra qualquer pedido: para todo par (empresa, pedido) a soma dos itens de um
   `sequencial` = `total_pedido_venda` daquela parcela. Divergência = bug de sync, e é bom o
   backend saber disso.

## 6. O que muda no frontend quando isso existir

- `app/(protected)/pedidos-equipe-v2/pedido/[codigoEmpresa]/[pedidoVenda]/page.tsx`: cada card de
  parcela ganha a lista de produtos (produto, quantidade, unidade, valor unitário, total, NF),
  direto do dado, sem nenhuma conciliação no cliente.
- Mesmo dado alimenta a futura visão de acompanhamento por etapa (o que cada parcela contém e em
  que etapa está).
- Com o `GET /pedidos_venda` agregado por pedido
  ([`05-Pedidos-Notas-Dashboards-Agregacao-no-Banco.md`](./05-Pedidos-Notas-Dashboards-Agregacao-no-Banco.md)),
  a lista traz `parciais[]` sem itens; os itens de um parcial são buscados sob demanda por este
  contrato, usando o `codigo_pedido_omie` de `parciais[]`.

## 7. Não bloqueia

Enquanto isso não existe, a página do pedido mostra o pedido, as parcelas (valor, etapa, situação,
prazo, nota fiscal), o histórico e as observações — sem os produtos. O simulador de comissão segue
funcionando normalmente pelo grão de família.
