---
id: SQL-020
aliases: ["Contrato SQL 020", "020-Imposto-por-Item-da-OC"]
tags: [contrato, contrato-sql, dba, compras, oc, imposto, custo, lote]
criado: 2026-10-29
atualizado: 2026-10-29
status: proposta
sistemas: [hub-banco, hub-api, hub-front, mes-api]
dono: "Gustavo (DBA); Robert no MES; Nathan no front"
etapa_0b: [C4, R4, E3]
fontes: ["Dump Avhub (Esqueleto).sql: core_vendas_faturamento.ordens_compra (:17257), ordens_compra_itens (:17737)", "api-pcp/prisma/models/estoque.prisma:390-423 (lote_custo)", "Registro-de-Decisoes: N14-23, N14-33, N16-20, N16-22, N16-38, N16-94, N16-106, N16-144", "API-007, API-008, API-010"]
criado_original: 2026-10-29
---

# Contrato SQL 020 — Imposto por item da OC

> **Onde atua:** av-hub: banco, API e front (emissão da OC) · MES: API (custo do lote no Recebimento)

> [!abstract] Resumo em linguagem natural
> **O que é:** Cada linha da ordem de compra passa a guardar o seu imposto (IPI, ICMS a recuperar, ST e DIFAL), de onde ele veio e a parte do frete que lhe cabe. Quando a OC é de um pedido de venda, o imposto vem preenchido da parte de compras do pedido. Quando é para estoque ou uso interno, o Comprador digita.
> **Quem é afetado:** Compras, que confere o imposto antes de comprar; o Estoque e a Controladoria, que passam a ver o custo do lote com e sem imposto.
> **Situação:** Proposta (29/10/2026). Nada existe no banco. Depende da parte de compras do pedido existir no banco.
> **Exemplo:** Uma OC de 100 peças a R$ 50,00 para dois pedidos vira duas linhas, uma de 60 peças com ICMS de 12% e outra de 40 peças com ICMS de 18%.

> [!info] Situação em 29/10/2026
> **Status:** `proposta` · **Pasta:** `Ativos` · **Nós do 0b:** C4, R4, E3 · **Dono:** Gustavo (banco e API), Robert (MES), Nathan (front)
>
> - 📝 **Decidido pelo Nathan em 29/10/2026 (N16-144, complementa a N16-38):** a fonte do imposto depende da finalidade da requisição; uma linha por pedido; pedido sem parte de compras não trava a OC; frete rateado pelo valor.
> - 🔴 **Sem código.** `ordens_compra_itens` não tem coluna de imposto (conferido no dump de 14/10); `lote_custo` tem `icms_recuperar_unit`, `ipi_unit`, `st_unit` e `frete_unit`, sempre vazios, e não tem DIFAL.
> - 🔴 **Depende** da parte de compras do pedido (imposto de compra preenchido pelo vendedor, N16-38 e N16-106), que ainda não existe no banco. Até lá, toda OC entra com imposto digitado.
> - ❓ A fórmula do custo com imposto precisa do aval da Controladoria (Michele). Ver "Perguntas em aberto".
>
> Selos em [[Regras-do-Vault]].

## Por quê

Hoje a OC do hub guarda preço, desconto e, no cabeçalho, frete, seguro, moeda e condição de pagamento. Não guarda imposto por item (N14-23). Por isso o custo do lote no MES nasce sem imposto e o custo real de cada evento sai incompleto (N16-20). O Ciclo 1 aceitou isso. Para ter os cenários com e sem imposto (PS-014, BL-053), o imposto tem de nascer na linha da OC, que é o que o Comprador aprova e o que vira o imposto real do evento de custo (N16-38).

## Regras (N16-144)

1. **A fonte do imposto depende da finalidade da requisição** de cada linha (`requisicoes_compra.finalidade`, N14-33; a linha chega à requisição por `ordens_compra_itens.id_requisicao`):
   - `pedidos_venda` ou `recompra`: o imposto vem da **parte de compras** do item do pedido (`numero_pedido_venda` da requisição). Nunca o imposto de venda.
   - `estoque` ou `uso_interno`: o Comprador digita.
2. **O Comprador pode editar** o que veio do pedido antes de aprovar (N16-38). O valor da OC aprovada é o imposto real. A edição não volta para o pedido.
3. **Uma linha por pedido.** Se a OC atende dois ou mais pedidos com o mesmo produto, cada pedido tem a sua linha, com o seu imposto. Nunca média. Isso segue N16-20 (cada evento com as suas condições) e N16-94 (a OC se liga ao item do pedido).
4. **Pedido sem a parte de compras preenchida** (por exemplo, pedido digitado no Omie em que o vendedor ainda não preencheu nada): os campos vêm vazios, o Comprador digita e a OC sai. A linha fica com `origem_imposto = 'digitado'`.
5. **Frete:** continua só no cabeçalho (`ordens_compra.valor_frete`). O banco rateia o frete pelas linhas na proporção de `valor_total_item` e entrega o frete por unidade de cada linha.

## O que pedir ao banco (Gustavo)

### 1) Colunas novas em `core_vendas_faturamento.ordens_compra_itens`

| Coluna | Tipo | Regra |
|---|---|---|
| `ipi_pct` | `numeric(6,3)` | 0 a 100; nulo = não informado |
| `icms_pct` | `numeric(6,3)` | ICMS a recuperar, 0 a 100 |
| `st_pct` | `numeric(6,3)` | 0 a 100 |
| `difal_pct` | `numeric(6,3)` | 0 a 100 |
| `origem_imposto` | `varchar(16)` | `pedido`, `pedido_editado` ou `digitado`; nulo enquanto nenhum imposto foi informado |

Percentual, como já é o `desconto` da mesma tabela. O valor por unidade é calculado na leitura (seção 3), para não ficar duas fontes do mesmo número.

`origem_imposto` vira `pedido_editado` quando o Comprador muda qualquer um dos quatro campos que vieram do pedido.

### 2) Pré-preenchimento ao montar a OC

Ao criar a linha da OC a partir de uma requisição com `finalidade` em (`pedidos_venda`, `recompra`), a API copia os quatro percentuais da parte de compras do item do pedido (mesmo produto, mesmo pedido) e grava `origem_imposto = 'pedido'`. Se o pedido não tem a parte de compras, os campos ficam nulos. Requisição de `estoque` ou `uso_interno`: campos nulos.

Ao aprovar a OC, a API recusa linha sem os quatro campos preenchidos? **Não**: o Ciclo 1 segue sem imposto (N14-23). Uma linha com imposto nulo é aprovada e o custo dela sai só no cenário sem imposto (pergunta G2 abaixo).

### 3) Valores por unidade na referência da OC para o MES (API-007)

A referência da OC que o MES lê ([[API-007-Referencia-OC-Valores-no-MES]]) ganha, por linha:

- `ipi_unit` = valor unitário líquido do desconto × `ipi_pct` / 100
- `icms_recuperar_unit` = valor unitário líquido × `icms_pct` / 100
- `st_unit` = valor unitário líquido × `st_pct` / 100
- `difal_unit` = valor unitário líquido × `difal_pct` / 100
- `frete_unit` = `valor_frete` do cabeçalho × (`valor_total_item` da linha / soma de `valor_total_item` da OC) / `quantidade` da linha
- `origem_imposto`

Na moeda da OC, como os demais valores da referência. Nulo quando o percentual é nulo.

## O que pedir ao MES (Robert)

- `lote_custo` ganha `difal_unit` (`Decimal(15,6)`, opcional), ao lado das colunas que já existem.
- No Recebimento, quando o lote nasce com origem OC ([[API-008-Custo-do-Lote-no-MES]] §3), copiar da linha da OC `icms_recuperar_unit`, `ipi_unit`, `st_unit`, `difal_unit` e `frete_unit`.
- `GET /itens/custo` passa a devolver os dois cenários. O cenário sem imposto não muda (`custo_sem_impostos: true` continua). O cenário com imposto só é preenchido quando o lote tem imposto.

## O que muda na tela (Nathan)

Na emissão da OC, cada linha mostra IPI, ICMS, ST e DIFAL em percentual, editáveis, e um selo da origem: "do pedido", "do pedido, editado" ou "digitado". Linha de pedido sem parte de compras mostra os campos vazios com o aviso "o pedido não tem imposto de compra; digite". O frete rateado de cada linha aparece só para leitura.

## Exemplo (números de conferência, inventados)

OC com frete de R$ 300,00 no cabeçalho, sem desconto:

| Linha | Finalidade | Qtd | Valor unit. | Total | IPI | ICMS | Origem | `ipi_unit` | `icms_recuperar_unit` | `frete_unit` |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Pedido A | 60 | 50,00 | 3.000,00 | 5% | 12% | `pedido` | 2,50 | 6,00 | 2,7273 |
| 2 | Pedido B | 40 | 50,00 | 2.000,00 | 5% | 18% | `pedido` | 2,50 | 9,00 | 2,7273 |
| 3 | Estoque | 20 | 25,00 | 500,00 | 0% | 12% | `digitado` | 0,00 | 3,00 | 1,3636 |

Soma do frete: 60 × 2,7273 + 40 × 2,7273 + 20 × 1,3636 = R$ 300,00 (com arredondamento).

Custo por unidade da linha 1 (fórmula a confirmar com a Controladoria, pergunta N1): sem imposto R$ 50,00; com imposto 50,00 + 2,50 (IPI) + 0 (ST) + 0 (DIFAL) − 6,00 (ICMS a recuperar) = R$ 46,50. O frete fica gravado à parte, como hoje (`frete_unit` fora do custo líquido).

## Como conferir

1. Criar uma requisição com `finalidade = pedidos_venda` para um pedido que tenha parte de compras, montar a OC e ver os quatro percentuais preenchidos com `origem_imposto = 'pedido'`.
2. Editar o ICMS da linha e ver `origem_imposto = 'pedido_editado'`; o pedido não muda.
3. Montar uma OC com dois pedidos do mesmo produto e ver duas linhas, cada uma com o seu imposto.
4. Montar uma OC de estoque e ver os campos vazios e `origem_imposto` nulo até o Comprador digitar.
5. Ler a referência da OC no MES e conferir `frete_unit`: a soma de `frete_unit × quantidade` das linhas bate com `valor_frete`.
6. Receber a OC no MES e ver as colunas de imposto preenchidas em `lote_custo`.

## Fora deste contrato

- O imposto de venda do pedido e o encargo da condição de pagamento (este entra no preço sugerido, N16-22).
- A NF de entrada como fonte do imposto: não foi escolhida (N16-38).
- A tabela da parte de compras do pedido: é do fluxo da proposta e do pedido (N16-143, `core_vendas_faturamento`).

## Perguntas em aberto

| ID | Pergunta | Para quem | Situação |
|---|---|---|---|
| N1 | Fórmula do custo com imposto: preço + IPI + ST + DIFAL − ICMS a recuperar? O IPI sai do custo quando é recuperável (industrialização)? O frete entra no custo com imposto ou continua à parte? | Controladoria (Michele) | ❓ aberta |
| G1 | Percentual na linha e valor por unidade calculado na leitura (como o `desconto`), ou gravar também o valor? | Gustavo | ❓ aberta |
| G2 | Linha aprovada sem imposto: o cenário com imposto do lote fica vazio (proposta) ou usa zero? | Gustavo e Nathan | ❓ aberta |
| G3 | Onde a API lê a parte de compras do item do pedido, quando ela existir (N16-143)? | Gustavo | ❓ aberta |
| G4 | O envio da OC ao Omie (`IncluirPedCompra`) passa a mandar os impostos da linha? | Gustavo | ❓ aberta |
