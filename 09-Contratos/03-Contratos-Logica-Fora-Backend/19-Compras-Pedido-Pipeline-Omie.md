# Compras — pedido para a pipeline (`omie-elt-pipeline`)

**Data:** 23/09/2026 · **Para:** quem mantém a `omie-elt-pipeline`
**Depende de:** `01 - DBA - banco.md` (D1, D5 e D6 precisam existir antes).
**Contrato completo, só para referência:** `../ENVIAR - contrato-compras-omie-pedidocompra.md`,
com o de-para campo a campo.

**Nada disto foi testado contra uma conta Omie real**, só contra a documentação. Os pontos a
confirmar estão em P6.

---

## P1. Recurso `pedidosCompras` (Omie → `pedidos_compras`)

`src/omie/resources/pedidosCompras.ts`, no molde de `pedidosVendas.ts`, registrado em
`index.ts`:

- `endpointPath: '/produtos/pedidocompra/'`, `listMethod: 'PesquisarPedCompra'`,
  `listResponseKey: 'pedidos_pesquisa'`, `idField: 'cabecalho_consulta.nCodPed'`,
  `getMethod: 'ConsultarPedCompra'`, `getIdParam: 'nCodPed'`.
- Parâmetros: `nPagina`, **`nRegsPorPagina`** (o vault escreveu `nRegPorPagina`, errado) e
  `dDataInicial`/`dDataFinal` em `dd/mm/aaaa`.
- **Todas as 7 flags `lExibirPedidos*` = `"T"`.** Não existe filtro `cEtapa` na pesquisa, como
  o vault dizia.
- Cada pedido já vem com itens, frete, parcelas e departamentos. **Não precisa de um
  `ConsultarPedCompra` por pedido.**
- **Chaves:**
  - pedido: upsert em `(codigo_empresa, codigo_pedido_compra_omie)`;
  - itens: REPLACE-ALL por pedido, com `ordem` = posição no array;
  - parcelas: REPLACE-ALL por pedido, em `pedidos_compras_parcelas`.
- **Conversões:**
  - `nDesconto` do item é **valor em R$** e vai em `valor_desconto`, não em
    `percentual_desconto`;
  - `valor_total_pedido` = soma de `nValTot` dos itens;
  - `cCodIntItem` do item vai em `codigo_item_integracao` (D5). É o que liga o item do espelho
    ao item da OC do av-hub.
- **Onde cada campo vai:** tabelas de-para da §2.2 do contrato completo.

**Teste que vale fazer:** o parâmetro `lApenasAlterados = "T"` ("apenas pedidos alterados no
período"). Se ele filtrar mesmo por data de alteração, compras pode ter sincronização
incremental, sem revarrer as janelas inteiras como em vendas.

## P2. Recurso `compradores` (Omie → `compradores`)

`src/omie/resources/compradores.ts`:
- `'/estoque/comprador/'` · `ListarCompradores`, `cadastros`, 50 por página. É catálogo:
  entra no `full_sync` diário e na carga inicial.
- Upsert em `(codigo_empresa, codigo_comprador_omie)`: `nome ← cDescricao`,
  `ativo ← cInativo = 'N'`.
- **Colunas protegidas** em `protectedColumns.ts`: `compradores.id_funcionario` e
  `compradores.nome_exibicao`. O vínculo é feito à mão no av-hub e o sync não pode apagar.
- Comprador que sumiu do Omie: marcar `ativo = false`, **não apagar**.

## P3. Recurso `condicoesPagamentoCompras` (Omie → `condicoes_pagamento_compras`)

`'/produtos/formaspagcompras/'` · `ListarFormasPagCompras`, `cadastros`, 50 por página,
catálogo diário. Upsert em `(codigo_empresa, codigo_omie)`:

| Coluna | Omie |
|---|---|
| `codigo_omie` | `cCodigo` |
| `descricao` | `cDescricao` |
| `quantidade_parcelas` | `nQtdeParc` |
| `lista_dias` | `cListaParc` |
| `dias_deslocamento` | `nDiasParc` |

## P4. Nomes de parceiro com entidade HTML

`core.parceiros.nome_fantasia` está chegando como `&apos;DALS&apos;-DESTILARIA...`. Decodificar
as entidades HTML no mapper de parceiros (`&apos;`, `&amp;`, `&quot;` etc.) e reprocessar os
registros afetados.

## P5. Envio da OC ao Omie (av-hub → Omie) — **decisão em aberto**

A recomendação é que este envio fique **nesta pipeline**, como um worker de escrita separado:
ela já tem as credenciais das duas contas e o limitador de taxa do Omie. Se a API também
chamasse o Omie, os dois processos disputariam o mesmo limite (o 429 de 21/08). **Só começar
depois de confirmado.** Resumo do que o worker faz (detalhe na §3 do contrato completo):

- **O que envia:** só OC `aprovado` com `status_sincronizacao_omie = 'pendente'`.
- **Como envia:** **`UpsertPedCompra`** com `cCodIntPed = numero_ordem`. Um reenvio altera o
  pedido em vez de duplicar.
- **Conversões:**
  - moeda ≠ BRL: converter os valores para R$ (`× cotacao_moeda`). O Omie não tem moeda;
  - desconto: % → valor (`qtd × unitário × desc / 100`);
  - frete: `CIF → "0"`, `FOB → "1"` (padrão da NF-e, a doc do Omie não lista; confirmar em P6);
    placa sem hífen (`cPlaca` tem 7 caracteres).
- **Comprador:** `nCodCompr` = `compradores.codigo_comprador_omie` do `ordens_compra.id_comprador`.
- **Não mandar `cEmailAprovador`**: ele aprova o pedido dentro do Omie.
- **`cObsInt` (aprovado):** bloco `[AV-HUB]…[/AV-HUB]` com tudo que o Omie não tem campo, seguido
  das duas observações da OC (`observacao` e `observacao_interna`):
  - OC e requisição;
  - quem emitiu e quem aprovou, com data, e o e-mail do aprovador;
  - moeda, cotação e total na moeda;
  - por item: tipo de material, unitário na moeda, desconto % e local de estoque.

  O formato está na §3.8 do contrato completo. As duas observações da OC são **só para o
  pessoal interno**: o `cObs` do cabeçalho vai vazio, e o `cObs` do item não é usado (é o único
  que sai impresso no pedido enviado ao fornecedor).
- **Retorno:**
  - sucesso: `codigo_pedido_omie ← nCodPed`, `numero_pedido_omie ← cNumero`,
    `status_sincronizacao_omie = 'sincronizado'` e `sincronizado_em`;
  - falha: `'erro'` e `erro_sincronizacao_omie ← description`.

## P6. Confirmar com uma chamada real (conta de teste)

1. Os códigos de `cEtapa`.
2. Se `lApenasAlterados` filtra por data de alteração.
3. Quais campos do `UpsertPedCompra` são obrigatórios de fato: mandar um payload mínimo e ler o
   erro.
4. Se o Omie gera as parcelas sozinho com `cCodParc` e sem `parcelas_incluir`.
5. Se `nCodProd` é obrigatório no item, ou se aceita só `cDescricao` + `cUnidade`.
6. Os códigos de `cTpFrete` (`0` = CIF, `1` = FOB).
