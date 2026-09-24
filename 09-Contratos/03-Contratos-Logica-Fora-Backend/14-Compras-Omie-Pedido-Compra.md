# Contrato — Compras ↔ Omie: puxar pedidos de compra e criar a OC lá

**Criado em:** 23/09/2026.

**Fontes:**
- documentação oficial do Omie, `produtos/pedidocompra/`, `produtos/formaspagcompras/` e
  `estoque/comprador/` (lida em 23/09/2026 em
  `https://app.omie.com.br/api/v1/produtos/pedidocompra/`);
- vault `vault-avhub-mer`: contrato SQL 004 (`pedidos_compras`), 007 (`ordens_compra`),
  `Omie-ELT-Pipeline.md` e `Compras-Estoque-Producao-Lacunas.md`;
- as tabelas reais em `api-acos-vital`, `origin/main`.

**Nada disto foi testado contra uma conta Omie real.** Tudo vem da documentação e ainda
precisa ser confirmado com o payload de verdade (ver §5).

São dois fluxos independentes, que não devem ser confundidos:

| | Tabela | Direção | Quem faz |
|---|---|---|---|
| **A. Puxar** | `core_vendas_faturamento.pedidos_compras` (+ `_itens`) | Omie → banco (espelho read-only) | `omie-elt-pipeline`. **Ainda não existe**: não há `src/omie/resources/pedidosCompras.ts` (conferido no `origin/master`, último commit em 18/09) |
| **B. Criar** | `core_vendas_faturamento.ordens_compra` (+ `_itens`, `_parcelas`) | av-hub → Omie (`IncluirPedCompra`) | **Ninguém ainda** (C6 em `ENVIAR - contrato-compras-pendencias-pos-backend.md`) |

---

## 1. A API do Omie para pedido de compra

`POST https://app.omie.com.br/api/v1/produtos/pedidocompra/`, no padrão Omie:
`{ "call": "<Metodo>", "app_key": "...", "app_secret": "...", "param": [ { ... } ] }`.
Cada unidade tem a sua própria conta no Omie. O pipeline já trata as contas `mogi` e
`uberaba`, cada uma com as suas credenciais e o seu `codigo_empresa`.

| Método | Uso aqui |
|---|---|
| `PesquisarPedCompra` | **A** — lista paginada, com itens, frete, parcelas e departamentos aninhados |
| `ConsultarPedCompra` | **A/B** — um pedido por `nCodPed`, `cCodIntPed` ou `cNumero` |
| `IncluirPedCompra` | **B** — cria |
| `UpsertPedCompra` | **B** — cria ou altera pela chave `cCodIntPed`. **Recomendado no lugar do Incluir** (ver §3.1) |
| `AlteraPedCompra` / `ExcluirPedCompra` | **B** — alteração ou cancelamento depois de enviado (fora da v1) |

Catálogos que a OC precisa usar (códigos do Omie, **por conta/unidade**):

| Catálogo | Endpoint / método | Campos |
|---|---|---|
| Condição de pagamento | `produtos/formaspagcompras/` · `ListarFormasPagCompras` | `cCodigo` (3), `cDescricao`, `nQtdeParc`, `cListaParc` (dias de vencimento), `nDiasParc` |
| Comprador | `estoque/comprador/` · `ListarCompradores` | `nCodigo`, `cDescricao`, `cInativo`. **Só leitura, não tem inclusão** |
| Fornecedor / transportadora | já estão em `core.parceiros` (`codigo_parceiro_omie`) | — |
| Produto | já está em `core.produtos` (`codigo_produto_omie`) | — |
| Categoria, conta corrente, projeto, local de estoque, departamento | `geral/categorias`, `geral/contacorrente`, `geral/projetos`, `estoque/local`, `geral/departamentos` | **não conferi os campos destes ainda** |

---

## 2. Fluxo A — puxar para o av-hub (`PesquisarPedCompra`)

### 2.1 Requisição

```json
{
  "nPagina": 1,
  "nRegsPorPagina": 50,
  "lApenasImportadoApi": "F",
  "lExibirPedidosPendentes": "T",
  "lExibirPedidosFaturados": "T",
  "lExibirPedidosRecebidos": "T",
  "lExibirPedidosCancelados": "T",
  "lExibirPedidosEncerrados": "T",
  "lExibirPedidosRecParciais": "T",
  "lExibirPedidosFatParciais": "T",
  "dDataInicial": "01/09/2026",
  "dDataFinal": "30/09/2026",
  "lApenasAlterados": "F"
}
```

**Correções em relação ao vault (contrato SQL 004):**
- o parâmetro é `nRegsPorPagina`, não `nRegPorPagina`;
- **não existe filtro `cEtapa`** na pesquisa. O filtro de situação são as 7 flags
  `lExibirPedidos*` (`T`/`F`). Para o espelho, ligar todas;
- **existe `lApenasAlterados`** ("exibir apenas pedidos alterados no período"). O pipeline
  assume que o Omie só filtra por data de inclusão e por isso revarre as janelas inteiras. Neste
  endpoint, a doc sugere que dá para buscar só o que mudou. **Testar antes de confiar**: se
  funcionar, vira uma sincronização incremental de verdade para compras.

A resposta traz `nTotalPaginas`, `nTotalRegistros` e `pedidos_pesquisa[]`. Cada pedido vem
**completo** (`cabecalho_consulta`, `frete_consulta`, `produtos_consulta[]`,
`parcelas_consulta[]`, `departamentos_consulta[]`), então não precisa de um
`ConsultarPedCompra` por pedido.

### 2.2 De-para para a tabela que já existe

#### Cabeçalho: `cabecalho_consulta` → `pedidos_compras`

| Omie | Tipo Omie | Coluna hoje | Observação |
|---|---|---|---|
| `nCodPed` | integer | `codigo_pedido_compra_omie` INTEGER | ⚠️ ver §2.3 (estouro de INTEGER) |
| `cCodIntPed` | string20 | `codigo_pedido_integracao` | Preenchido quando o pedido nasceu no av-hub (fluxo B). **É o que liga o pedido do Omie à `ordens_compra`** |
| `cNumero` | string15 | `numero_pedido` (15) | Número do pedido **no Omie** |
| `cNumPedido` | string30 | ❌ **falta coluna** | Número do pedido **para o fornecedor**, que é outra coisa. Sugestão: `numero_pedido_fornecedor varchar(30)` |
| `dIncData` + `cIncHora` | string10 + string8 | ❌ **falta coluna** | Data e hora de inclusão. Sugestão: `incluido_em_omie timestamptz` |
| `cEtapa` | string2 | `etapa` (2) | **A doc não lista os códigos** (só diz "Etapa atual do pedido de compra"). As palavras pendente/faturado/recebido/cancelado/encerrado/parcial que o vault usava são das 7 flags `lExibirPedidos*` da pesquisa, não valores deste campo. Os códigos reais precisam sair do payload |
| `dDtPrevisao` | string10 `dd/mm/aaaa` | `data_previsao` | converter a data |
| `cCodParc` | string3 | ❌ **falta coluna** | Condição de pagamento. Sugestão: `codigo_condicao_pagamento varchar(3)` |
| `nQtdeParc` | integer | ❌ **falta coluna** | `quantidade_parcelas` |
| `nCodFor` | integer | `codigo_fornecedor` INTEGER | ⚠️ ver §2.3. Códigos reais já passam de 10 dígitos (ex.: `10037044822`) |
| `cCodIntFor` | string20 | — | dispensável |
| `nCodCompr` | integer | `codigo_comprador` INTEGER | |
| `cContato` | string100 | `contato` (60) | ⚠️ coluna menor que o Omie. Ampliar para 100 |
| `cContrato` | string20 | `numero_contrato` | |
| `cCodCateg` | string20 | `codigo_categoria` | |
| `nCodCC` | integer | `codigo_conta_corrente` INTEGER | ⚠️ §2.3 |
| `nCodProj` | integer | `codigo_projeto` INTEGER | ⚠️ §2.3 |
| `cObs` / `cObsInt` | text | `observacao` / `observacao_interna` | `cObs` é a observação **para o fornecedor** (sai impressa no pedido do Omie, apesar do que a doc diz; ver §2.4). `cObsInt` é interna; nos pedidos que nasceram no av-hub, volta com o bloco `[AV-HUB]` em cima (§3.8), e o espelho separa o bloco do texto. Quebra de linha chega como barra vertical e aspas como `&quot;` (§2.4) |
| — | — | `email_aprovador` | **Não vem na consulta.** `cEmailAprovador` só existe no incluir/upsert. A coluna vai ficar sempre nula no espelho |
| — | — | `valor_total_pedido` | **Não existe no cabeçalho.** Calcular como Σ `nValTot` dos itens |
| — | — | `cnpj_cpf_fornecedor` | **Não vem na consulta** (só existe no incluir). Tirar de `core.parceiros`, ou deixar nulo |

#### Frete: `frete_consulta` → `pedidos_compras`

| Omie | Coluna hoje | Observação |
|---|---|---|
| `nCodTransp` integer | `transportadora` varchar(100) | ⚠️ O Omie manda **código**, não nome. Sugestão: `codigo_transportadora` com tipo numérico adequado (§2.3) |
| `cTpFrete` string1 | `tipo_frete` (1) | `0` CIF · `1` FOB · `2` terceiros · `3` próprio remetente · `4` próprio destinatário · `9` sem frete. ⚠️ **Estes códigos não estão na doc do Omie** (ela só diz "Modalidade do frete no pedido"): são o padrão `modFrete` da NF-e. Confirmar com payload real (§5) |
| `cPlaca` string7 / `cUF` | `placa_transporte` / `uf_transporte` | |
| `nQtdVol` | `qtde_volumes` | `cEspVol`, `cMarVol`, `cNumVol` e `cLacre` não têm coluna (dispensáveis) |
| `nPesoLiq` / `nPesoBruto` | `peso_liquido` / `peso_bruto` | |
| `nValFrete` / `nValSeguro` / `nValOutras` | `valor_frete` / `valor_seguro` / `valor_despesas` | |

#### Itens: `produtos_consulta[]` → `pedidos_compras_itens`

| Omie | Coluna hoje | Observação |
|---|---|---|
| posição no array | `ordem` | chave estável (já decidida em 21/09) |
| `nCodItem` integer | `numero_item_omie` INTEGER | ⚠️ §2.3 (na doc de requisição de compra o exemplo é `200000003040063`, com 15 dígitos) |
| `cCodIntItem` string20 | ❌ **falta coluna** | Sugestão: `codigo_item_integracao varchar(20)`. Nos pedidos que nasceram no av-hub, vem com o `cCodIntItem` que o fluxo B mandou (§3.5). **É o único jeito de ligar um item do espelho ao item da OC** (`ordens_compra_itens`): a resposta do `UpsertPedCompra` só devolve o `nCodPed` e o `cNumero`, nenhum código de item. Sem essa coluna, o `nQtdeRec` (logo abaixo) não tem como chegar ao item certo da OC |
| `nCodProd` integer | `codigo_produto_omie` varchar(60) | ok |
| `cDescricao` (120) | ❌ **falta coluna** | sem ela, a tela não mostra o que foi comprado sem JOIN em `core.produtos` |
| `cUnidade` (6) | ❌ **falta coluna** | |
| `nQtde` | `quantidade` | |
| `nValUnit` | `valor_unitario` | |
| `nDesconto` | `percentual_desconto` | ⚠️ **O Omie manda VALOR (R$), não percentual.** Ou a coluna vira `valor_desconto`, ou o pipeline converte: `nDesconto / (nQtde × nValUnit) × 100` |
| `nValMerc` / `nValTot` | ❌ **faltam colunas** | total da mercadoria e total do item (com desconto, despesas e impostos) |
| `nQtdeRec` | ❌ **falta coluna** | **Quantidade já recebida.** É o dado mais útil para o Recebimento e o que diferencia "parcialmente recebido" |
| `cNCM` | `ncm` | |
| — | `cfop` | **Não existe** no item do pedido de compra. A coluna vai ficar sempre nula |
| `codigo_local_estoque` | `codigo_local_estoque` | |
| `cCodCateg` | ❌ falta coluna | categoria por item (opcional) |
| `nValorIcms`/`St`/`Ipi`/`Pis`/`Cofins`, `nFrete`, `nSeguro`, `nDespesas` | ❌ | impostos e rateios por item. Só guardar se alguém for usar |

#### Parcelas e departamentos: **não existem tabelas**

`parcelas_consulta[]` (`nParcela`, `dVencto`, `nValor`, `nDias`, `nPercent`, `cTipoDoc`) e
`departamentos_consulta[]` (`cCodDepto`, `nPerc`, `nValor`) chegam em todo pedido e hoje
seriam descartados. Precisam de `pedidos_compras_parcelas` se o financeiro ou o dashboard for
usar vencimentos.

### 2.4 Conferido com um pedido real (nº 46618, Mogi, 21/09/2026)

Payload de `ConsultarPedCompra` enviado pelo usuário em 23/09/2026. O que ele confirma ou corrige:

- **`cObs` do cabeçalho sai impresso** no pedido do Omie (contradiz a doc). É onde os compradores
  põem o texto "IMPORTANTE…" das instruções ao fornecedor.
- **Quebra de linha é `|`** nos campos de texto (`cObs` do item: `"100/ PÇS - ENTREGAR…|191/ PÇS - ENTREGAR…"`).
  O envio troca cada quebra de linha por `|`; o espelho faz o inverso.
- **Aspas chegam como entidade HTML** (`&quot;`, também em `cDescricao`: `3/8&quot; K`). O
  espelho precisa decodificar, como nos parceiros (C8).
- **`cEtapa` = `"15"`** nesse pedido (incluído, ainda não faturado nem recebido). Primeiro código
  real; os demais continuam a confirmar.
- **Códigos passam de INTEGER** (§2.3, confirmado): `nCodPed` 10467753709, `nCodFor` 10363934283,
  `nCodCompr` 10219958954, `nCodCC` 10364415646, `nCodItem` 10467754866.
- **`codigo_local_estoque` vem como texto** (`"9764544941"`), não integer como diz a doc.
- **`nValTot` = `nValMerc` − `nDesconto` + `nValorIpi`** (218.529,36 − 2.601,54 + 7.102,20 =
  223.030,02). O ICMS (`nValorIcms` 25.911,34) não soma.
- **`cCodParc` = `"U10"`** (código da condição, não os dias; o PDF mostra "30/40/50/60/70") e
  **`cCodCateg` = `"2.01.03"`** (código, o PDF mostra "Compras de Materia Prima"). Confirma que os
  dois precisam de catálogo para virar nome.
- **`nPercent` das parcelas** vem com arredondamento (`19.99999`, `20.00004`).
- **Existe `caracteristicas_consulta[]`**, que a doc não cita.
- **Vínculo com o pedido de venda:** `cNumPedido` = `"27645"` e `cObsInt` = `"PV 27645 - GABRIEL
  NICOLAU"`. O comprador usa esses campos para ligar a compra ao pedido de venda que ela atende
  (apesar de o PDF chamar `cNumPedido` de "Nº do Pedido do Fornecedor"). A OC do av-hub ainda não
  tem esse vínculo; será tratado à parte.

### 2.3 ⚠️ Estouro de INTEGER (corrigir antes de ligar o pipeline)

`pedidos_compras` usa `INTEGER` (int4, máximo 2.147.483.647) para códigos do Omie. Os
códigos reais já passam disso: em `core.parceiros` há fornecedores como `10037044822` e
`10372091516`, com 11 dígitos. O primeiro upsert com um desses valores quebra com
`integer out of range`.

Colunas para `bigint`: `codigo_pedido_compra_omie`, `codigo_fornecedor`, `codigo_comprador`,
`codigo_conta_corrente`, `codigo_projeto`, `pedidos_compras_itens.numero_item_omie`,
`codigo_local_estoque`. Para comparar: `ordens_compra.codigo_pedido_omie` já é `BIGINT`, e
`ordens_compra.codigo_fornecedor` é texto.

### 2.4 O que falta criar no pipeline

`src/omie/resources/pedidosCompras.ts`, no mesmo molde de `pedidosVendas.ts`:
`endpointPath: '/produtos/pedidocompra/'`, `listMethod: 'PesquisarPedCompra'`,
`listResponseKey: 'pedidos_pesquisa'`, `idField: 'cabecalho_consulta.nCodPed'`,
`getMethod: 'ConsultarPedCompra'`, `getIdParam: 'nCodPed'`. Janela por `dDataInicial`/`dDataFinal`
e as flags `lExibirPedidos*` todas em `T`. Conflito em `(codigo_empresa,
codigo_pedido_compra_omie)` e itens em REPLACE-ALL por pedido, como diz o comentário da tabela.
Depois, registrar em `src/omie/resources/index.ts`.

Depois disso, o av-hub lê por `GET /pedidos_compras` e `GET /pedidos_compras/{id}`, que já
existem na API.

---

## 3. Fluxo B — criar a OC no Omie (`IncluirPedCompra` / `UpsertPedCompra`)

### 3.1 Regras de envio (decisões propostas, confirmar)

1. **Só envia OC `aprovado`.** OC `aguardando_aprovacao` fica no av-hub. Se fosse para o Omie
   antes, uma reprovação exigiria `ExcluirPedCompra` depois.
2. **Usar `UpsertPedCompra` com `cCodIntPed`**, não `IncluirPedCompra`. Se o envio der timeout
   depois de o Omie ter gravado, o reenvio com o mesmo `cCodIntPed` **altera** em vez de
   **duplicar**.
3. **`cCodIntPed` = `numero_pedido`** da OC, como está no banco: `"OC-000123"`. (O campo se
   chamava `numero_ordem` até 23/09/2026.) O banco gera por trigger, com contador por unidade e
   6 dígitos (`fn_proximo_numero_documento`, conferido no dump de teste de 23/09). Cabe nos 20
   caracteres do campo e é único dentro de cada conta Omie. O `id` uuid (36 caracteres) não cabe.
4. A mesma OC volta pelo fluxo A (o espelho), com `codigo_pedido_integracao = numero_pedido`.
   É por esse campo que as duas tabelas se ligam.
5. **Unidade sem conta Omie** (a HRM não tem nenhum parceiro em `core.parceiros`): a OC não
   tem para onde ir. Definir se ela é bloqueada na emissão ou fica sem sincronizar.

### 3.2 Cabeçalho: `ordens_compra` → `cabecalho_incluir`

| Omie | Obrigatório? | Vem de | Situação hoje |
|---|---|---|---|
| `cCodIntPed` string20 | chave do upsert | `numero_pedido` (`OC-000123`) | ok (limitar a 20) |
| `dDtPrevisao` `dd/mm/aaaa` | provavelmente sim | `data_previsao_chegada` | ok (o form exige) |
| `cCodParc` string3 | sim (`"999"` = padrão) | `codigo_condicao_pagamento` | ❌ **hoje é texto livre.** Precisa virar select do `ListarFormasPagCompras` da unidade |
| `nQtdeParc` | sim | `quantidade_parcelas` | ok, mas deveria vir do `nQtdeParc` da condição escolhida |
| `nCodFor` integer (ou `cCnpjCpfFor`) | sim | `codigo_fornecedor` | ok. Já filtrado por unidade no av-hub, falta validar no backend (C2) |
| `nCodCompr` integer | opcional | `compradores.codigo_comprador_omie` do `ordens_compra.id_comprador` | ❌ **ainda não existe.** Desenhado em `ENVIAR - contrato-compradores-funcionario.md`: tabela de compradores por filial, ligada ao funcionário, e a OC grava o comprador na emissão |
| `cCodCateg` string20 | a confirmar | `codigo_categoria` | texto livre. Ideal: select de `geral/categorias` |
| `nCodCC` integer | a confirmar | `codigo_conta_corrente` | texto livre. Ideal: select de `geral/contacorrente` |
| `nCodProj` integer | opcional | `codigo_projeto` | texto livre |
| `cContato` string100 | opcional | `contato` | ok |
| `cContrato` string20 | opcional | `contrato` | ok |
| `cNumPedido` string30 | opcional | `numero_pedido_fornecedor` (nova, C9) | número do pedido no fornecedor |
| `cObs` | opcional | `observacao` (observação do pedido, para o fornecedor) | nasce com o texto padrão "IMPORTANTE…" (`OBSERVACAO_PADRAO_PEDIDO`); quebra de linha vira barra vertical no envio (§2.4) |
| `cObsInt` | opcional | **bloco AV-HUB (§3.8)** + `observacao_interna` | o que o av-hub tem e o Omie não tem campo, **em cima** do texto interno do comprador |
| `cEmailAprovador` string120 | opcional | `email_aprovador` | ⚠️ pela doc, **ao informar este campo o pedido entra na etapa de aprovação do Omie "com status de aprovado"**, e o usuário precisa ter permissão lá. Como a aprovação é feita no av-hub, **não mandar**: o e-mail do aprovador e quem aprovou, com data, vão no bloco AV-HUB de `cObsInt` (§3.8) |

### 3.3 ⚠️ Moeda estrangeira: o Omie não tem campo de moeda

Nenhum campo de `IncluirPedCompra` recebe moeda ou cotação. Uma OC em USD/EUR precisa ser
**convertida para R$ antes do envio**: `nValUnit = valor_unitario × cotacao_moeda`, o mesmo
para o desconto em valor. Frete e seguro também, se forem lançados na moeda de origem (hoje o
formulário mostra os dois em R$, então confirmar). A moeda e a cotação originais só podem ir
como texto: **vão no bloco AV-HUB de `cObsInt`** (§3.8), com o total e o valor unitário de cada item na moeda original.

A cotação passa a vir preenchida da PTAX do Banco Central, com a origem gravada na OC
(`cotacao_origem` = `ptax` ou `manual`, e `cotacao_data`): ver
`ENVIAR - contrato-compras-cotacao-moeda-ptax.md`.

### 3.4 Frete: `ordens_compra` → `frete_incluir`

| Omie | Vem de | Observação |
|---|---|---|
| `cTpFrete` string1 | `tipo_frete` | `CIF → "0"`, `FOB → "1"` (padrão `modFrete` da NF-e; a doc do Omie não lista os códigos, confirmar — §5) |
| `nCodTransp` integer | `codigo_transportadora` | só no FOB |
| `cPlaca` **string7** | `placa_veiculo` (10) | tirar o hífen (`ABC-1D23` → `ABC1D23`) |
| `cUF` | `uf_veiculo` | |
| `nQtdVol` | `volumes` | |
| `nPesoLiq` / `nPesoBruto` | `peso_liquido` / `peso_bruto` | |
| `nValFrete` / `nValSeguro` | `valor_frete` / `valor_seguro` | |
| `nValOutras` | — | não existe na OC |

### 3.5 Itens: `ordens_compra_itens` → `produtos_incluir[]`

| Omie | Vem de | Situação hoje |
|---|---|---|
| `cCodIntItem` string20 | `numero_pedido` + `-` + `ordem` (`OC-000123-1`) | ok (limitar a 20). Volta no espelho em `pedidos_compras_itens.codigo_item_integracao` (§2.2): é por ele que o item do Omie se liga de novo ao item da OC |
| `nCodProd` integer | `codigo_produto` | ❌ **o formulário não escolhe produto**: `codigo_produto` vai `null` e só há descrição livre. O Omie precisa de `nCodProd` (ou `cCodIntProd`) para vincular ao cadastro e ao estoque. **O item precisa virar busca em `core.produtos` da unidade**, como foi feito com o fornecedor |
| `cDescricao` string120 | `descricao_produto` | ok (cortar em 120) |
| `cUnidade` string6 | `unidade_medida` | ok. Deveria vir do cadastro do produto |
| `cNCM` | — | vem do cadastro do produto no Omie. Não precisa mandar se `nCodProd` for informado (a confirmar) |
| `nQtde` | `quantidade` | ok |
| `nValUnit` | `valor_unitario` | em R$ (§3.3) |
| `nDesconto` | `quantidade × valor_unitario × desconto / 100` | a OC guarda **percentual** e o Omie quer **valor** |
| `codigo_local_estoque` integer | `local_estoque` | ❌ texto livre. Ideal: select de `estoque/local`. Enquanto for texto livre, **manda vazio (local padrão) e o texto vai no bloco AV-HUB** (§3.8) |
| `cCodCateg` | — | opcional por item |
| `cObs` | `ordens_compra_itens.observacao` (nova, C9) | **observação do item para o fornecedor**: sai impressa embaixo do item no pedido do Omie (ex.: entregas parciais, "100/ PÇS - ENTREGAR NO DIA 24/09/2026"). Nunca dado interno (§3.8) |
| impostos (`nValorIcms`...) | — | opcionais. Não mandar na v1 |
| `tipo_material` | — | **sem equivalente no Omie**: vai no bloco AV-HUB de `cObsInt`, por item (§3.8) |

### 3.6 Parcelas: `parcelas_incluir[]`

`nParcela`, `dVencto`, `nValor`, `nDias` (a partir de `dDtPrevisao`), `nPercent`, `cTipoDoc`.

O `ListarFormasPagCompras` devolve `cListaParc` (lista de dias) e `nQtdeParc`. **Esse é o
catálogo de condições de pagamento que o contrato SQL 007 (pergunta 6) achava que não
existia.** Com ele:
- ou só manda `cCodParc` e deixa o Omie gerar as parcelas (confirmar se ele gera sozinho);
- ou a trigger de `ordens_compra_parcelas` passa a usar os dias reais da condição em vez de
  "partes iguais a cada 30 dias", e `calculo_provisorio` vira `false`.

`departamentos_incluir[]` (rateio) fica fora da v1, como já estava decidido.

### 3.7 Retorno → `ordens_compra`

| Omie | Coluna |
|---|---|
| `nCodPed` | `codigo_pedido_omie` |
| `cNumero` | `numero_pedido_omie` |
| `cCodStatus` / `cDescStatus` | sucesso → `status_sincronizacao_omie = 'sincronizado'`, `sincronizado_em = now()` |
| falha (`omie_fail`: `code`, `description`, `fatal`) | `status_sincronizacao_omie = 'erro'`, `erro_sincronizacao_omie = description` |

A resposta **não traz nenhum código de item** (`nCodItem`). A ligação item a item entre a OC e o
pedido no Omie fica pelo `cCodIntItem`, quando o pedido volta pelo espelho (fluxo A,
`pedidos_compras_itens.codigo_item_integracao`). Não precisa de um `ConsultarPedCompra` depois
do envio.

### 3.8 Regra: o que não tem campo no Omie vai nas observações

**Decisão (23/09/2026):** todo dado da OC que o av-hub precisa e o Omie não tem onde guardar vai
no campo de observações do pedido no Omie. Nada é descartado no envio.

**Campo: `cObsInt` (observação interna do cabeçalho). ✅ Aprovado em 23/09/2026.**

**As três observações (decisão de 23/09/2026, revista com o pedido 46618 real):**

| Na OC do av-hub | Quem vê | No PDF da OC | No Omie |
|---|---|---|---|
| `observacao` (do pedido) | fornecedor | sai, no quadro "Observações" | `cObs` do cabeçalho — **sai impresso no pedido do Omie** (o "IMPORTANTE…" do 46618) |
| `ordens_compra_itens.observacao` (do item, C9) | fornecedor | sai embaixo do item | `cObs` do item (sai impresso) |
| `observacao_interna` | só o pessoal interno | não sai | `cObsInt`, **abaixo** do bloco `[AV-HUB]` |

⚠️ A doc do Omie diz que o `cObs` do cabeçalho "não será impresso no pedido enviado ao
fornecedor". **O pedido real diz o contrário** (46618: o `cObs` é o "IMPORTANTE…" da página 2 do
PDF). Vale o comportamento real.

A observação do pedido nasce com o texto padrão que os compradores já usam no Omie
(`OBSERVACAO_PADRAO_PEDIDO` em `lib/domain/compras-ordem.ts`, igual nas três unidades), e o
comprador pode editar. **Sem "•" nem aspas tipográficas**: no PDF do Omie eles viram "¿¿¿".

**Formato do `cObsInt`:** um bloco delimitado, sempre no topo, seguido da observação interna digitada pelo comprador.
O delimitador permite que o fluxo A (o espelho) reconheça e separe o bloco quando o pedido
voltar do Omie. Linhas sem valor são omitidas.

```
[AV-HUB]
OC: OC-000123 | Requisição: REQ-000045
Emitida por: Fulano de Tal em 23/09/2026 14:02
Aprovada por: Beltrano em 23/09/2026 16:40 | E-mail do aprovador: beltrano@acosvital.com.br
Moeda: USD | Cotação: 5,380000 (PTAX venda 22/09/2026) | Total na moeda: US$ 6.300,00 | Total em R$: 33.894,00
Itens:
 1. Não acabado (matéria-prima) | US$ 12,50/KG | Desc. 5% | Local: Galpão 2
 2. Acabado | US$ 40,00/UN
[/AV-HUB]
<observacao_interna digitada pelo comprador>
```

**O que entra no bloco (lista fechada; um campo novo só entra aqui se não tiver campo no Omie):**

| Dado do av-hub | Por que vai na observação |
|---|---|
| `numero_pedido` | já é o `cCodIntPed`, mas a observação deixa legível para quem abre o pedido no Omie |
| `numero_requisicao` (origem) | o Omie não tem vínculo com requisição |
| quem emitiu e quando (`created_by`/`created_at`) | não há de-para para `nCodCompr` |
| quem aprovou e quando (`aprovado_por`/`aprovado_em`) e `email_aprovador` | a aprovação é do av-hub, e `cEmailAprovador` não é enviado |
| `moeda`, `cotacao_moeda`, `valor_total` na moeda | o Omie não tem moeda; os valores dos campos vão convertidos para R$ |
| por item: `tipo_material` | não existe no Omie |
| por item: valor unitário na moeda original (só se moeda ≠ BRL) | `nValUnit` vai em R$ |
| por item: `desconto` em % | `nDesconto` vai em valor |
| por item: `local_estoque` em texto (enquanto não for código do Omie) | `codigo_local_estoque` é numérico |

**Precisa do C1** (`ENVIAR - contrato-compras-pendencias-pos-backend.md`): sem os nomes de
`created_by` e `aprovado_por`, o bloco só teria uuids. O job de envio precisa resolver os nomes.

**Não entram:** campos que têm equivalente no Omie mas hoje são texto livre no av-hub (condição
de pagamento, categoria, conta corrente, projeto). Esses precisam virar select com o catálogo
Omie (§4). Mandá-los só como observação deixaria o pedido no Omie sem a condição de pagamento
real.

### 3.9 Onde implementar o envio — **decidido em 24/09: opção 1 (pipeline, por fila)**

- **Opção 1: um worker no `omie-elt-pipeline`.** Ele já tem as credenciais das duas contas, o
  limitador de taxa do Omie (incidente de 429 em 21/08) e o BullMQ. Contra: o pipeline foi
  definido como "só extrai" (EL). Escrever no Omie muda esse papel.
- **Opção 2: um job no `api-acos-vital`.** Fica perto de onde a OC nasce, mas duplica as
  credenciais e o limitador de taxa, e as duas contas passam a competir pelo mesmo limite do
  Omie em dois processos (foi exatamente a causa do 429 de 21/08).

**Decisão do Nathan (24/09/2026): opção 1**, como um worker separado de escrita no mesmo
repositório, com uma fila própria e o mesmo limitador de taxa. E **cancelar uma OC já enviada
cancela no Omie também**: como a API do Omie não tem "cancelar" pedido de compra, a pipeline usa
`ExcluirPedCompra` (detalhes no L4 de `ENVIAR - contrato-compras-pipeline.md` e no B4 de
`ENVIAR - contrato-compras-backend.md`).

---

## 4. O que muda no av-hub por causa disso

- Condição de pagamento, categoria, conta corrente, projeto e local de estoque deixam de ser
  texto livre e viram select com o catálogo Omie da unidade. **Depende de o backend expor esses
  catálogos** (projeções, igual `/compras/fornecedores`).
- O item da OC **pode** escolher o **produto** em `core.produtos` (busca por unidade); é opcional, e material não cadastrado continua em texto livre (decisão de 24/09, B12).
- A tela da OC mostra a situação do envio ao Omie com a mensagem de erro real (a tela já está
  pronta, só falta o dado).
- Uma tela nova de **histórico de compras do Omie** (fluxo A), lendo `/pedidos_compras`,
  quando houver dados.

## 5. Precisa confirmar com payload real (1 chamada de cada, numa conta de teste)

1. Os códigos reais de `cEtapa`.
2. Se `lApenasAlterados` filtra de fato por data de alteração.
3. Quais campos do `IncluirPedCompra` são obrigatórios de verdade: a doc não marca, então
   mandar um payload mínimo e ler o erro.
4. Se, com `cCodParc` e sem `parcelas_incluir`, o Omie gera as parcelas sozinho.
5. Se `nCodProd` é obrigatório, ou se aceita item só com `cDescricao` + `cUnidade`.
6. Os códigos de `cTpFrete` (`0` = CIF, `1` = FOB…): a doc do Omie não lista, estão aqui pelo
   padrão da NF-e.
