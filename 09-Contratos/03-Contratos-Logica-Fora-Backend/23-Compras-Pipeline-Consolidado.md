---
tags: [contrato-logica, contrato-pipeline, compras, omie]
status: implementada-no-codigo
criado: 2026-09-23
atualizado: 2026-10-07
---

# Contrato — Compras: tudo o que falta na PIPELINE (`omie-elt-pipeline`)

> Status: decidido | no código | em produção (verificado em 07/10/2026 só pelo dump; o deploy da pipeline não foi conferido). Fonte: [[Registro-de-Decisoes-2026-10-07]] (#7, #20, #28).
>
> **✅ Decisão de 07/10/2026 sobre o envio da OC:** fica **fixo no código e vai direto ao Omie, sem `SYNC_ENVIO_OC` nem `ENVIO_OC_DRY_RUN`** (o Nathan rodou cerca de 4 testes reais e a OC entrou). **L10.1, L10.6 (FOB) e L10.7 (b) a (d) viram risco aceito.** Alteração de código: Gustavo. As menções às duas flags e aos "pendentes sem teste" abaixo são histórico.

> **Atualização de 07/10/2026 — conferido no código da pipeline (`master` `d2886bf`, 06/10 07:46; produção/deploy NÃO conferidos).** Status: `implementada-no-codigo`; **falta conferir em produção/`api-test`** (o próprio contrato diz "sem deploy nada roda"). O cabeçalho abaixo (de 23/09 a 05/10) está desatualizado nestes pontos:
> - **L4 não está mais "sem push":** o PR #1 foi **mergeado em 05/10** (14:56, `3233acf`) e o PR #2 em 06/10; `master` = `d2886bf`. O passo 0 da ordem sugerida (§4, "publicar a branch") **está feito**.
> - **As flags `SYNC_*` de leitura saíram em 06/10** (contrato 38, `d6abf04`): `SYNC_COMPRADORES`, `SYNC_COTACAO_PTAX`, `SYNC_PEDIDOS_COMPRAS`, `SYNC_CONDICOES_PAGAMENTO_COMPRAS`, `SYNC_PROJETOS`, `SYNC_CONTAS_CORRENTES`, `SYNC_CATEGORIAS` (além de `EXCLUSION_SYNC_DRY_RUN` e `RAW_AUDIT_ENABLED`). Os recursos de Compras rodam sempre. ~~Só `SYNC_ENVIO_OC` (padrão `false`) e `ENVIO_OC_DRY_RUN` (padrão `true`) continuam, de propósito, como interruptores de escrita no Omie~~ **(decidido em 07/10: as duas flags deixam de existir; envio fixo, direto ao Omie, risco aceito; ver o topo.)**
> - **"Marcar inativo o que sumir do Omie nos catálogos" está feito:** `jobs/inativarCatalogos.ts` (`f4fd02d`), cron `47 4 * * *`, nos 5 catálogos de Compras; não age se o Omie devolver menos da metade dos ativos.
> - **L10.4 está respondido** (`f4fd02d`): sem parcelas o Omie gera pela condição e mantém o código; com `parcelas_upsert` ele troca a condição para `999`.
> - **A decisão "parcelas só quando definitivas" está obsoleta:** o envio **nunca manda parcelas** (só `cCodParc` e `nQtdeParc`).
> - **Sem teste real, hoje risco aceito (✅ 07/10):** **L10.1** (códigos de `cEtapa`; sem evidência no código), **L10.6** (FOB = `"1"`; "a confirmar" no próprio código) e **L10.7 (b)–(d)** (exclusão com recebimento parcial, recebido, aprovado no Omie). L10.2 e L10.5 respondidos; L10.3 parcial (`nValor` obrigatório, `2ac4921`).
> - O teste real de Mogi de 05/10 (OC-000002 virando o pedido 47476, reenvio sem duplicar, exclusão aceita) está registrado aqui e no README da pipeline; o código não o prova e o Omie não foi verificado.
> - Estado geral (código): 15 recursos registrados, 14 ligados; `estoque` está `enabled:false` (✅ 07/10: sem função, o estoque do Omie é ignorado; `core.estoque_saldo` existe vazia). Regras "item sem produto" e "comprador vinculado" valem desde o contrato 36 (`d11b6d1`, `2ac4921`).
> - **HRM:** nenhum código da pipeline menciona a HRM e o `.env.example` só tem Mogi e Uberaba; ligar a HRM é por env, **com uma exceção** (`FAMILIA_PADRAO_POR_FILIAL` em `produtos.ts` é fixo para mogi e uberaba; produto da HRM sem família no Omie seria pulado [I]). ✅ 07/10 (#20): corrigir a doc (`ARCHITECTURE.md` do pipeline, fora do vault) e registrar tarefa de código (Gustavo).
>
> Ver [[Indice-Contratos]] (Conferência de 07/10/2026) e [[Chaves-de-Integracao-AvHub-MES-Pipeline]].

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
> branch `feat/compras-omie` da pipeline (commits `95c2db4`, `3f16868`, `ae919fd`, `229a419` e `c7aba1b`). **Todos
> nascem desligados** (atualizado em 07/10: as flags saíram em 06/10 e os recursos rodam sempre) e eram ligados pelo `.env` (`SYNC_COMPRADORES`, `SYNC_COTACAO_PTAX`,
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
> existem e avisa no log (commit `229a419`). **No local, com as duas colunas criadas (Apêndice B do
> contrato do backend), a pipeline passou a gravar a observação do item sem aviso** (573 de 1.370
> itens; no 46618, as duas linhas de entrega). Commits na branch: `95c2db4`, `3f16868`, `ae919fd`,
> `229a419` e `c7aba1b` (correções do teste local de 24/09).
>
> **Testado no local em 24/09/2026** (banco local com a estrutura do teste e os dados de
> produção; workers e fila de verdade; Omie e Banco Central reais, só leitura):
> - **PTAX:** 5 dias úteis de USD e EUR gravados (USD 23/09 venda 5,1414).
> - **Compradores:** 56 (Mogi) + 8 (Uberaba). Um vínculo feito à mão (`id_funcionario`,
>   `nome_exibicao`) **sobreviveu** à sincronização seguinte.
> - **Condições de pagamento:** 326 + 40, **depois de aumentar as colunas** (ver L8: 5 condições
>   de Mogi não cabiam em `varchar(30)`).
> - **Espelho:** 469 pedidos na janela 20–25/09; o 46618 confere campo a campo com o payload
>   (códigos `bigint`, total 223.030,02, 5 parcelas, observação com aspas e quebras de linha).
>   Rodar de novo não duplica nada, e item/parcela que não existem mais no Omie são apagados.
> - **Dois erros achados e corrigidos na pipeline:** a janela filtrava por previsão (L3) e a
>   descrição da condição era cortada em 30 caracteres sem aviso (L8).
> - **Categorias, contas correntes e projetos:** tabelas criadas no local com o DDL do B7 (e do
>   contrato de projetos). 312 + 262 categorias, 107 + 13 contas e 59 + 47 projetos, sem erro e sem
>   duplicar ao rodar de novo. Os códigos do 46618 viram "16 - Revenda", "01 - Boleto/Pix/TED" e
>   "Compras de Materia Prima", como no PDF do Omie.
>
> **Continua pendente** (texto de 24/09; **atualizado em 07/10:** L4 e a inativação dos catálogos estão feitos, ver o topo): L4 (envio da OC; **decidido em 24/09: pela pipeline, com exclusão no
> Omie ao cancelar**; falta implementar), L10 (campos obrigatórios e FOB) e
> marcar como inativo o que sumir do Omie nos catálogos.
>
> **Atualização (05/10/2026): L4 implementado** na `feat/compras-omie` (commit `66f9a2e`, **sem push**; **atualizado em 07/10:** mergeado em 05/10 pelo PR #1, `3233acf`).
> Processo novo `envio-oc-worker` (fila `omie-envio-oc`, uma rodada por vez): lê `GET
> /compras/ordens/fila-omie`, manda `UpsertPedCompra`/`ExcluirPedCompra` e devolve em `PATCH
> …/sincronizacao`. ~~Ligado por `SYNC_ENVIO_OC` (padrão `false`), começa em `ENVIO_OC_DRY_RUN=true`
> (só mostra o payload no log).~~ **(07/10: sem flags, envio fixo direto ao Omie; ver o topo.)** Testado no local: dry run das OCs OC-000005 (R$, CIF, produto do
> cadastro, desconto 5%, local em texto) e OC-000006 (US$ PTAX, FOB com placa), e o caminho real
> contra um **Omie falso** (sucesso grava `nCodPed`/`cNumero`, recusa vira `erro` com a mensagem do
> Omie, exclusão marca o espelho). **Nenhuma chamada de escrita ao Omie de verdade foi feita.**
> Decisões de implementação:
> - **Separador do bloco `[AV-HUB]`:** ` ; ` entre os campos de uma linha, e não ` | ` como no
>   exemplo do contrato 14 (§3.8): o `|` é a quebra de linha do Omie e cada campo voltaria pelo
>   espelho como uma linha solta.
> - **Parcelas:** ~~só vão em `parcelas_upsert` quando todas são definitivas (`calculo_provisorio =
>   false`, condição achada no catálogo); senão vai só o `cCodParc`.~~ **Obsoleto (atualizado em 07/10, `f4fd02d`):** o envio **nunca manda parcelas**, só `cCodParc` e `nQtdeParc`; o Omie gera as parcelas pela condição.
> - **Produto:** ~~`nCodProd` só se o código existir em `core.produtos` **da unidade da OC**; senão o
>   item vai só com descrição e o bloco avisa.~~ **Obsoleto (atualizado em 07/10, `2ac4921`):** item sem `nCodProd` (produto precisa existir em `core.produtos` da unidade da OC) vira erro na OC antes de chamar o Omie. Local de estoque numérico vai em
>   `codigo_local_estoque`; texto livre vai no bloco.
> - **Erros:** recusa do Omie → `erro` (sai da fila até o "Reenviar"); rede/429/425 → fica
>   pendente para a próxima rodada; 3 recusas seguidas param a rodada da unidade (o Omie bloqueia
>   a chave com 10).
>
> Também em `66f9a2e`: **IE e dados fiscais dos parceiros** (contrato SQL 001 e §2.2 do contrato 30;
> o fornecedor do 46871 ficou com IE `188.198.930.112`) e **`ativo_desde`/`inativo_desde` dos
> compradores protegidos** (R4 do contrato 28, conferido: a data feita à mão sobreviveu ao sync).
>
> **Teste real no Omie (05/10/2026, conta de Mogi, autorizado pelo Nathan só para o fornecedor
> de teste "IGNORAR ESSE CLIENTE TESTE", CNPJ 26.LTC.HSE/0001-94, código 10466053225).** Feito com
> o banco local = cópia de produção de 05/10 e a API local na `develop` (`6646efe`):
> - OC-000001 (emitida pela tela, item em texto livre) — **recusada**: "Item [1]: Informe a tag
>   [cProduto], [cCodIntProd] ou [nCodProd]". Com `cProduto` livre: "Produto não cadastrado para o
>   Código". **O Omie só aceita item com produto cadastrado** (L10.5 respondido).
> - OC-000002 (produto 10203516758 "GRAMPO DE GRADE TESTE") — **aceita: pedido 47476**
>   (`nCodPed` 10473263296), número gravado na OC. Antes, uma recusa: "O preenchimento da tag
>   [nValor] é obrigatório!" (parcela precisa de valor).
> - Reenvio com o mesmo `cCodIntPed`: "alterado com sucesso", mesmo `nCodPed`, sem duplicar item.
> - Com `parcelas_upsert`, o Omie grava a condição como `999` (informar parcelas), mesmo mandando
>   `000`. Alterar sem parcelas mantém as que existiam (L10.4 só parcialmente respondido: falta criar
>   um pedido sem parcelas para ver se o Omie gera pela condição). **(atualizado em 07/10: L10.4 respondido por `f4fd02d` — sem parcelas o Omie gera pela condição e mantém o código.)**
> - Cancelamento → fila `excluir` → `ExcluirPedCompra` **aceito** (pedido sem recebimento, etapa
>   10); a consulta passou a responder "Pedido de compra não cadastrado". L10.7(a) respondido.
> - Correções na pipeline (`2ac4921`): `nValor` nas parcelas; item sem produto vira erro antes de
>   chamar o Omie; `Client-105` também é recusa de validação (não só "não existe").
>
> **Decisão pendente (Nathan):** a decisão de 24/09 (B12) permite material em texto livre na OC, e o
> formulário de OC direta (finalidade Estoque) não tem busca de produto — o código só vem de PV. Com
> o Omie exigindo produto cadastrado, essas OCs nunca entram no Omie.
>
> **Ainda pendente** (texto de 05/10; **atualizado em 07/10:** L10.4 e a inativação dos catálogos estão feitos; sobram L10.1, L10.6 — FOB `"1"` — e L10.7 (b)–(d), **risco aceito em 07/10**): L10.1, L10.3 (FOB `"1"` não testado), L10.4 (criação sem parcelas), L10.7
> (b)–(d), e marcar como inativo o que sumir do Omie nos catálogos.
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
  **`lApenasAlterados = "T"`** e **as 7 flags `lExibirPedidos*` = `"T"`**. Não existe filtro `cEtapa`.
- ⚠️ **`lApenasAlterados` muda o sentido das datas** (conferido em 24/09/2026, Mogi, janela
  20–25/09). Com `"F"`, o período filtra pela **data de previsão** (mais os pendentes já
  atrasados): vieram 452 pedidos e o 46618 (incluído em 21/09, previsão 24/10) **não veio**. Com
  `"T"`, filtra pelo que foi **incluído ou alterado** no período: vieram 455, com ele. O espelho
  usa `"T"` na janela e no full sync; com `"F"`, pedido com previsão futura nunca entraria.
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

### L4. Envio da OC ao Omie (`UpsertPedCompra` / `ExcluirPedCompra`) — **decidido em 24/09**

**Decisão do Nathan: a pipeline envia, por fila.** Um worker de escrita nesta pipeline, com fila
própria e o mesmo limitador de taxa. Ela já tem as credenciais das duas contas; se a API também
chamasse o Omie, os dois processos disputariam o mesmo limite (foi a causa do 429 de 21/08). A OC
aprovada leva até alguns minutos para aparecer no Omie.

- **O que envia:** a fila `GET /compras/ordens/fila-omie` (B4 do backend), que traz a **ação** de
  cada OC:
  - `enviar` — OC `aprovado` + `pendente`. OC `aguardando_aprovacao` **não** vai;
  - `excluir` — OC `cancelado` + `pendente` com `codigo_pedido_omie` (já estava no Omie).
- **HRM Caldeiraria:** ~~não tem conta Omie; por decisão de 24/09, compra pela unidade de Mogi~~
  **Revisto em 06/10/2026:** a HRM tem conta Omie própria e compra por ela (`id_unidade_compra` nulo
  em produção). A OC da HRM vai pela conta da HRM: **conferir que `FILIAIS_ATIVAS` da pipeline em
  produção inclui `hrm`** (com `FILIAL_HRM_OMIE_APP_KEY/SECRET` e `FILIAL_HRM_CODIGO_EMPRESA`); o
  `.env` local só tem Mogi e Uberaba.
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
  o Omie gerar sozinho (a testar, §3). **(atualizado em 07/10)** valeu a segunda opção: o envio nunca manda parcelas (`f4fd02d`).
- **Retorno:** `PATCH /compras/ordens/{id}/sincronizacao` (B4): sucesso → `nCodPed`, `cNumero`;
  falha (`omie_fail`) → `status: "erro"` com a `description`.
- **Cancelamento (decisão 24/09: cancela no Omie também).** A API do Omie **não tem "cancelar"
  pedido de compra** (métodos: Incluir, Altera, Upsert, Consultar, Pesquisar e `ExcluirPedCompra`).
  Ação `excluir` → `ExcluirPedCompra` com `nCodPed = codigo_pedido_omie`:
  - sucesso → `PATCH …/sincronizacao` `{ status: "sincronizado" }` e marcar `deleted_at` no
    `pedidos_compras` do mesmo `codigo_pedido_compra_omie` (o pedido some das pesquisas seguintes);
  - o Omie recusa → `{ status: "erro", erro: "<description>" }`: a OC
    fica cancelada no av-hub e viva no Omie até alguém resolver lá. **Nunca** tentar de novo sozinho
    em loop; só pelo "Reenviar" da tela.
  - A trigger do banco é que devolve a OC cancelada para `pendente` (Apêndice B do contrato do
    backend, testado).

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

⚠️ **Tamanho real maior que a doc** (teste local de 24/09/2026): em Mogi, 5 das 326 condições têm
descrição e lista de dias com até **71** caracteres (ex.: `A08` = "180/210/…/690", 18 parcelas).
Com as colunas em `varchar(30)` esses 5 não entram. A pipeline **não corta** nada (cortar a lista
de dias gravaria um prazo errado): o banco precisa de `varchar(100)` nas duas colunas (B7 do
contrato do backend, com o `ALTER`). Em Uberaba o maior é 29.

---

## 3. 🟡 Correções e testes

### L9. Entidades HTML nos parceiros (C8)

`core.parceiros.nome_fantasia` chega como `&apos;DALS&apos;-DESTILARIA…` e
`&apos;IMPERIUNS…&apos;`. Decodificar no mapper de parceiros (`&apos;`, `&amp;`, `&quot;`…) e
**reprocessar** os registros afetados. A mesma função serve para todos os recursos acima.

### L10. Confirmar com uma chamada real (conta de teste)

1. Os demais códigos de `cEtapa` (vistos até agora: `"10"`, `"15"` e `"20"`).
2. ~~Se `lApenasAlterados` filtra por data de alteração.~~ **Respondido em 24/09/2026**: sim, com
   `"T"` o período é de inclusão/alteração; com `"F"` é de previsão (ver L3). A pipeline usa `"T"`.
3. Quais campos do `UpsertPedCompra` são obrigatórios de fato: mandar um payload mínimo e ler o erro.
4. Se o Omie gera as parcelas sozinho com `cCodParc` e sem `parcelas_incluir`. **(07/10: respondido, `f4fd02d` — gera pela condição e mantém o código.)**
5. Se `nCodProd` é obrigatório no item, ou se aceita só `cDescricao` + `cUnidade`. **(05/10: respondido — o Omie exige produto cadastrado.)**
6. `cTpFrete = "1"` para FOB. **(07/10: não testado; "a confirmar" no próprio código; risco aceito, ✅.)**
7. **Quando o `ExcluirPedCompra` é aceito.** A doc não diz. Testar na conta de teste, com pedidos
   criados só para isso: (a) incluído, sem recebimento; (b) com recebimento parcial; (c) recebido,
   com a nota de entrada; (d) com o pedido aprovado dentro do Omie. Anotar a `description` de cada
   recusa. O esperado é (a) aceita e (c) recusa; (b) e (d) não se sabe. Também testar a exclusão por
   `cCodIntPed` (o número da OC), que evita depender do `nCodPed`.

---

## 4. Ordem sugerida

0. **(atualizado em 07/10: publicar a branch está feito, PR #1 mergeado em 05/10; falta conferir o deploy)** **Publicar a branch `feat/compras-omie`** (PR para `master`) e fazer o deploy: sem ela, nada
   abaixo roda, e o `master` atual nem compila (erro corrigido no `95c2db4`).
1. **L1** (PTAX) e **L2** (compradores): as tabelas já existem **no teste**, dá para ligar hoje lá.
   Em produção, só depois do B0 do contrato do backend.
2. **L9** (entidades HTML): pequeno, e a função é reaproveitada por todos.
3. **L5–L8** (catálogos), assim que o B7 do backend criar as tabelas.
4. **L3** (espelho), depois do B1 do backend.
5. **L4** (envio da OC e exclusão ao cancelar), depois do B4 do backend.

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
