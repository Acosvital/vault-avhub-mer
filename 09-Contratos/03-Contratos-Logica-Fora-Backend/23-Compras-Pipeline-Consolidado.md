# Contrato — Compras: tudo o que falta na PIPELINE (`omie-elt-pipeline`)

**Criado em:** 23/09/2026 · **Para:** quem mantém a `omie-elt-pipeline`

**Este documento substitui, como lista de trabalho,** `ENVIAR - compras/03 - PIPELINE - omie-elt-pipeline.md`.
De-para campo a campo e o porquê de cada regra: `ENVIAR - contrato-compras-omie-pedidocompra.md`,
`ENVIAR - contrato-compras-cotacao-moeda-ptax.md` e `ENVIAR - contrato-compras-projetos-omie.md`.
O que é banco e API está em `ENVIAR - contrato-compras-backend.md`.

**Situação em 23/09/2026:** o último commit na `master` é de **18/09/2026**. Em
`src/omie/resources/` existem só `estoque`, `etapasFaturamento`, `familiaProdutos`,
`notasFiscais`, `parceiros`, `pedidosVendas`, `produtoVendas`, `produtos` e `vendedores`.
**Nenhum recurso de compras existe ainda.** Por isso, na API de teste,
`/compras/compradores`, `/cotacoes_moeda/atual` e `/categorias` respondem vazios.

> **Atualização (23/09/2026, fim do dia): L1, L2, L3, L5, L6, L7, L8 e L9 estão implementados** na
> branch `feat/compras-omie` da pipeline (commits `95c2db4`, `3f16868`, `ae919fd` e `229a419`, ainda sem push). **Todos
> nascem desligados** e são ligados pelo `.env` (`SYNC_COMPRADORES`, `SYNC_COTACAO_PTAX`,
> `SYNC_PEDIDOS_COMPRAS`, `SYNC_CONDICOES_PAGAMENTO_COMPRAS`, `SYNC_PROJETOS`,
> `SYNC_CONTAS_CORRENTES`, `SYNC_CATEGORIAS`) depois que o banco do ambiente tiver as tabelas.
> Testados contra o Omie real (só leitura, conta de Mogi) e contra a API do Banco Central; a
> gravação no banco não foi testada, porque as tabelas ainda não existem em produção.
> O commit `95c2db4` corrige também um erro que quebrava o build da pipeline desde 18/09.
>
> **Conferido nos dumps de 23/09 (fim do dia):** no banco de **teste** já dá para ligar
> `SYNC_COMPRADORES`, `SYNC_COTACAO_PTAX`, `SYNC_PEDIDOS_COMPRAS` e
> `SYNC_CONDICOES_PAGAMENTO_COMPRAS`; em **produção**, nenhum. Como os itens do espelho no teste
> ainda não têm `codigo_item_integracao` nem `observacao`, a pipeline grava só as colunas que
> existem e avisa no log (commit `229a419`). Commits na branch: `95c2db4`, `3f16868`, `ae919fd`,
> `229a419`.
>
> **Continua pendente:** L4 (envio da OC, espera decisão), L10 (testes de `lApenasAlterados`,
> campos obrigatórios e FOB) e marcar como inativo o que sumir do Omie nos catálogos.
>
> **Dados reais vistos no teste (Mogi):** etapas do pedido de compra `10`, `15` e `20`; ~57
> compradores, **~325 condições de pagamento** (`000`, `A05`, `A15`, `U10`…), ~108 contas
> correntes, ~312 categorias e 60 projetos; ~1.230 pedidos de compra nos últimos 20 dias. Por
> isso os catálogos rodam só na camada de "últimos meses" (a cada ~3h) e no full sync.

**Regras que valem para todos os recursos abaixo** (confirmadas no payload real do pedido 46618):

- Cada unidade é uma conta Omie. Todo registro grava o `codigo_empresa` da conta de onde veio.
- **Códigos do Omie passam de INTEGER** (ex.: 10467753709). Tratar como `bigint`/texto, nunca int4.
- **Texto do Omie vem com entidades HTML** (`&quot;`, `&apos;`, `&amp;`): decodificar ao gravar.
- **Quebra de linha nos textos do Omie é `|`**: ao gravar, `|` vira `\n`; ao enviar, `\n` vira `|`.
- **Nada de "•" nem aspas tipográficas no que for enviado ao Omie**: no PDF do Omie viram "¿¿¿".
- Datas do Omie em `dd/mm/aaaa` (+ `hh:mm:ss`), fuso `America/Sao_Paulo`.
- Registro que sumiu do Omie num `full_sync` de catálogo: marcar `ativo = false` ou `deleted_at`,
  **nunca apagar a linha** (OCs e pedidos antigos apontam para o código).

---

## 1. 🔴 Primeiro

### L1. Job da cotação PTAX (Banco Central → `core.cotacoes_moeda`)

**A tabela e as rotas já existem** (`8715549`); falta só quem preenche. Não é Omie: é a API Olinda
do Banco Central, pública e sem chave.

```
GET https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/
    CotacaoMoedaPeriodo(moeda=@moeda,dataInicial=@dataInicial,dataFinalCotacao=@dataFinalCotacao)
    ?@moeda='USD'&@dataInicial='MM-DD-AAAA'&@dataFinalCotacao='MM-DD-AAAA'
    &$format=json&$select=cotacaoCompra,cotacaoVenda,dataHoraCotacao,tipoBoletim
```

- **Quando:** dias úteis às 13h30 e de novo às 17h.
- **O quê:** últimos 7 dias, moedas `USD` e `EUR`. Grava **só** `tipoBoletim = 'Fechamento'`,
  upsert em `(moeda, data)`: `cotacao_compra`, `cotacao_venda`, `data_hora_boletim`,
  `fonte = 'PTAX_BCB'`.
- **Carga inicial:** desde 01/01/2026.
- **Falha no BC** não pode derrubar os jobs do Omie: registrar e tentar no próximo horário.

### L2. Compradores (`ListarCompradores` → `compradores`)

**A tabela já existe** (`core_vendas_faturamento.compradores`, `8715549`).

- `'/estoque/comprador/'` · `ListarCompradores` · lista em `cadastros` · 50 por página.
- Catálogo: `full_sync` diário e carga inicial, nas duas contas.
- Upsert em `(codigo_empresa, codigo_comprador_omie)`: `codigo_comprador_omie ← nCodigo` (texto),
  `nome ← cDescricao` (decodificado), `ativo ← cInativo = 'N'`.
- **Colunas protegidas** (`protectedColumns.ts`): `compradores.id_funcionario` e
  `compradores.nome_exibicao`. O vínculo é manual no av-hub; o sync não pode apagar.
- Sumiu do Omie: `ativo = false`.

### L3. Espelho dos pedidos de compra (`PesquisarPedCompra` → `pedidos_compras`)

**Só depois do B1 do contrato do backend** (colunas `bigint` e as novas). Sem ele, o primeiro
pedido real quebra com `integer out of range`.

`src/omie/resources/pedidosCompras.ts`, no molde de `pedidosVendas.ts`:

- `endpointPath: '/produtos/pedidocompra/'`, `listMethod: 'PesquisarPedCompra'`,
  `listResponseKey: 'pedidos_pesquisa'`, `idField: 'cabecalho_consulta.nCodPed'`,
  `getMethod: 'ConsultarPedCompra'`, `getIdParam: 'nCodPed'`.
- Parâmetros: `nPagina`, **`nRegsPorPagina`** (não `nRegPorPagina`), `dDataInicial`/`dDataFinal`,
  e **as 7 flags `lExibirPedidos*` = `"T"`**. Não existe filtro `cEtapa`.
- Cada pedido já vem completo (cabeçalho, frete, itens, parcelas, departamentos): não precisa de
  `ConsultarPedCompra` por pedido.
- **Chaves:** pedido em `(codigo_empresa, codigo_pedido_compra_omie)`; itens e parcelas em
  REPLACE-ALL por pedido, item com `ordem` = posição no array.
- **Conversões:**

  | Omie | Coluna | Regra |
  |---|---|---|
  | `cNumero` | `numero_pedido` | número **no Omie** |
  | `cNumPedido` | `numero_pedido_fornecedor` | hoje os compradores usam para o nº do pedido de venda |
  | `dIncData` + `cIncHora` | `incluido_em_omie` | |
  | `cCodParc`, `nQtdeParc` | `codigo_condicao_pagamento`, `quantidade_parcelas` | |
  | `nCodTransp` | `codigo_transportadora` | código, não nome |
  | `cObs` | `observacao` | observação **para o fornecedor** (sai impressa); barra vertical → `\n` |
  | `cObsInt` | `observacao_interna` | nos pedidos do av-hub, separar o bloco `[AV-HUB]…[/AV-HUB]` do texto |
  | item `cCodIntItem` | `codigo_item_integracao` | liga o item ao item da OC do av-hub |
  | item `nDesconto` | `valor_desconto` | **valor em R$**, não percentual |
  | item `nValMerc`, `nValTot` | `valor_mercadoria`, `valor_total` | `nValTot = nValMerc − nDesconto + nValorIpi` (o ICMS não soma) |
  | item `nQtdeRec` | `quantidade_recebida` | |
  | item `cObs` | `observacao` | barra vertical → `\n` |
  | item `codigo_local_estoque` | `codigo_local_estoque` | **vem como texto** (`"9764544941"`); converter |
  | `valor_total_pedido` | — | Σ `nValTot` dos itens |
  | `parcelas_consulta[]` | `pedidos_compras_parcelas` | `nPercent` vem com arredondamento (19.99999) |

- **Testar:** `lApenasAlterados = "T"` ("apenas pedidos alterados no período"). Se filtrar de fato
  por alteração, compras ganha sync incremental.

### L4. Envio da OC ao Omie (`UpsertPedCompra`) — **decisão em aberto**

**Onde fica:** a recomendação é **um worker de escrita nesta pipeline**, com fila própria e o mesmo
limitador de taxa. Ela já tem as credenciais das duas contas; se a API também chamasse o Omie, os
dois processos disputariam o mesmo limite (foi a causa do 429 de 21/08). **Só começar depois de o
Nathan confirmar.**

- **O que envia:** a fila `GET /compras/ordens?status=aprovado&status_sincronizacao_omie=pendente`
  (B4 do backend). OC `aguardando_aprovacao` **não** vai.
- **Como:** `UpsertPedCompra` com `cCodIntPed = numero_pedido` (≤ 20 caracteres). Reenvio altera
  em vez de duplicar.
- **Cabeçalho:** `dDtPrevisao ← data_previsao_chegada` (`dd/mm/aaaa`); `cCodParc ←
  codigo_condicao_pagamento`; `nQtdeParc`; `nCodFor ← codigo_fornecedor`; `nCodCompr ←
  compradores.codigo_comprador_omie` do `id_comprador`; `cCodCateg`, `nCodCC`, `nCodProj`;
  `cContato`, `cContrato`; `cNumPedido ← numero_pedido_fornecedor`. **Não mandar
  `cEmailAprovador`** (ele aprova o pedido dentro do Omie; a aprovação é do av-hub).
- **Frete:** `cTpFrete`: `CIF → "0"` (**confirmado** no pedido 46618), `FOB → "1"` (a confirmar);
  `nCodTransp` só no FOB; `cPlaca` sem hífen (7 caracteres); pesos, volumes, frete e seguro.
- **Itens:** `cCodIntItem = numero_pedido-ordem`; `nCodProd` quando houver produto (hoje vai nulo,
  B12); `cDescricao` (≤ 120), `cUnidade` (≤ 6), `nQtde`; `nValUnit` **em R$** (`× cotacao_moeda`
  se a OC for em outra moeda); `nDesconto` **em valor** (`qtd × unitário × desconto% / 100`, em
  R$); `codigo_local_estoque` vazio enquanto for texto livre; **`cObs ← observacao do item`**
  (para o fornecedor).
- **Observações:**
  - `cObs` do cabeçalho ← `observacao` (observação do pedido, **para o fornecedor**, sai impressa;
    nasce com o texto "IMPORTANTE…");
  - `cObsInt` ← bloco `[AV-HUB]…[/AV-HUB]` **em cima**, seguido da `observacao_interna`. O bloco
    leva o que o Omie não tem campo: OC e requisição; quem emitiu e quem aprovou, com data, e o
    e-mail do aprovador; moeda, cotação (com a origem, "PTAX venda 22/09/2026") e total na moeda;
    por item: tipo de material, unitário na moeda, desconto % e local de estoque em texto.
    Formato exato em `ENVIAR - contrato-compras-omie-pedidocompra.md`, §3.8.
- **Parcelas:** `parcelas_incluir[]` a partir de `ordens_compra_parcelas`, **ou** só `cCodParc` se
  o Omie gerar sozinho (a testar, §3).
- **Retorno:** `PATCH /compras/ordens/{id}/sincronizacao` (B4): sucesso → `nCodPed`, `cNumero`;
  falha (`omie_fail`) → `status: "erro"` com a `description`.

---

## 2. 🟠 Catálogos para os selects da OC

Todos: catálogo diário (`full_sync`) + carga inicial, nas duas contas; upsert por
`(codigo_empresa, código)`; texto decodificado; sumiu do Omie → inativo. **Dependem das tabelas do
B7 do contrato do backend.**

### L5. Categorias (`ListarCategorias` → `core.categorias`)

`'/geral/categorias/'` · `ListarCategorias` · lista em **`categoria_cadastro`** · parâmetros
`pagina`, `registros_por_pagina`. **Hoje `core.categorias` existe, mas ninguém a preenche.**

| Omie | Coluna |
|---|---|
| `codigo` (string20, ex.: `"2.01.03"`) | `codigo_categoria` |
| `descricao` (string50) | `descricao` |
| `conta_inativa` | `ativo` (`"N"` → true) |
| `conta_despesa` / `conta_receita` | `conta_despesa` / `conta_receita` |
| `totalizadora` | `totalizadora` (grupo; não se lança nele) |
| `nao_exibir` | `nao_exibir` |
| `categoria_superior` | `categoria_superior` |
| `tipo_categoria` | `tipo_categoria` |

Trazer **todas** (receita e despesa); a rota filtra por tipo. O filtro `filtrar_por_tipo` do Omie
existe, mas não usar no sync.

### L6. Contas correntes (`ListarContasCorrentes` → `core.contas_correntes`)

`'/geral/contacorrente/'` · `ListarContasCorrentes` · lista em **`ListarContasCorrentes`** ·
parâmetros `pagina`, `registros_por_pagina`.

| Omie | Coluna |
|---|---|
| `nCodCC` (ex.: 10364415646) | `codigo_conta_omie` (bigint) |
| `cCodCCInt` | `codigo_integracao` |
| `descricao` (ex.: "01 - Boleto/Pix/TED") | `descricao` |
| `tipo_conta_corrente` | `tipo` |
| `codigo_banco`, `codigo_agencia`, `numero_conta_corrente` | `codigo_banco`, `codigo_agencia`, `numero_conta` |
| `inativo` | `ativo` (`"N"` → true) |

**Não trazer** saldo, limite, dados de cobrança, PDV nem gerente: não são usados e são dados
financeiros sensíveis.

### L7. Projetos (`ListarProjetos` → `core.projetos`)

`'/geral/projetos/'` · `ListarProjetos` · lista em `cadastro` · `registros_por_pagina: 50`,
`apenas_importado_api: "N"`. Mapeamento completo em `ENVIAR - contrato-compras-projetos-omie.md`
§3: `codigo` (bigint) → `codigo_projeto_omie`, `nome` **como vem** ("16 - Revenda"; há nomes sem
número, como "Logística"), `inativo` → `ativo`, `info.*` → datas e usuários do Omie.

### L8. Condições de pagamento (`ListarFormasPagCompras` → `condicoes_pagamento_compras`)

`'/produtos/formaspagcompras/'` · `ListarFormasPagCompras` · lista em `cadastros` · 50 por página.

| Omie | Coluna |
|---|---|
| `cCodigo` (ex.: `"U10"`) | `codigo_omie` |
| `cDescricao` (ex.: "30/40/50/60/70") | `descricao` |
| `nQtdeParc` | `quantidade_parcelas` |
| `cListaParc` | `lista_dias` |
| `nDiasParc` | `dias_deslocamento` |

---

## 3. 🟡 Correções e testes

### L9. Entidades HTML nos parceiros (C8)

`core.parceiros.nome_fantasia` chega como `&apos;DALS&apos;-DESTILARIA…` e
`&apos;IMPERIUNS…&apos;`. Decodificar no mapper de parceiros (`&apos;`, `&amp;`, `&quot;`…) e
**reprocessar** os registros afetados. A mesma função serve para todos os recursos acima.

### L10. Confirmar com uma chamada real (conta de teste)

1. Os demais códigos de `cEtapa` (o `"15"` já foi visto no 46618: incluído, sem faturar).
2. Se `lApenasAlterados` filtra por data de alteração.
3. Quais campos do `UpsertPedCompra` são obrigatórios de fato: mandar um payload mínimo e ler o erro.
4. Se o Omie gera as parcelas sozinho com `cCodParc` e sem `parcelas_incluir`.
5. Se `nCodProd` é obrigatório no item, ou se aceita só `cDescricao` + `cUnidade`.
6. `cTpFrete = "1"` para FOB.

---

## 4. Ordem sugerida

0. **Publicar a branch `feat/compras-omie`** (PR para `master`) e fazer o deploy: sem ela, nada
   abaixo roda, e o `master` atual nem compila (erro corrigido no `95c2db4`).
1. **L1** (PTAX) e **L2** (compradores): as tabelas já existem **no teste**, dá para ligar hoje lá.
   Em produção, só depois do B0 do contrato do backend.
2. **L9** (entidades HTML): pequeno, e a função é reaproveitada por todos.
3. **L5–L8** (catálogos), assim que o B7 do backend criar as tabelas.
4. **L3** (espelho), depois do B1 do backend.
5. **L4** (envio da OC), depois da decisão e do B4 do backend.

## 5. Aceite

- `GET /cotacoes_moeda/atual?moeda=USD` devolve o último fechamento, com a data.
- `GET /compras/compradores?codigo_empresa=<Mogi>` lista os compradores do Omie, e um vínculo feito
  à mão no av-hub sobrevive ao sync seguinte.
- O pedido 46618 aparece em `pedidos_compras` com os códigos corretos, a observação do item em duas
  linhas e as 5 parcelas.
- Categorias, contas correntes, projetos e condições de pagamento das duas contas estão no banco, e
  os inativos aparecem como inativos.
- Uma OC aprovada no av-hub vira pedido no Omie e volta com o número do Omie; o PDF do Omie mostra
  a observação do pedido, a do item e nada do bloco interno.
