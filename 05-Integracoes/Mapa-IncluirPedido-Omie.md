---
tags: [omie, pedido-de-venda, incluir-pedido, api, mapa-de-campos, pesquisa]
criado: 2026-10-23
atualizado: 2026-10-29
status: proposta
dono: Nathan
fontes: ["Documentação do Omie lida em 23/10/2026: https://app.omie.com.br/api/v1/produtos/pedido/ (serviço PedidoVendaProduto, método IncluirPedido e tipos complexos)", "Exemplo de IncluirPedido enviado pelo Nathan em 23/10/2026", "05-Integracoes/Estudo-Omie-API (estudo de 21/10)", "av-hub components/Propostas/PropostaForm (PedidoOmieModal.tsx, ItemProposta.tsx, PropostaForm.tsx)"]
---

# Mapa do `IncluirPedido` do Omie: o que o hub manda, de onde vem cada campo e o que ainda não sabemos

**Em uma frase:** esta nota lista, campo a campo, o que o hub vai mandar ao Omie quando uma proposta virar pedido de venda, de onde vem cada dado e o que ainda precisa de teste.

**Quando consultar esta nota:** ao desenhar ou revisar o envio do pedido ao Omie (o ERP, sistema fiscal e financeiro), ou ao decidir qual dado da proposta vira campo do pedido. Status: 🟡 proposta. **Nenhuma chamada foi feita ao Omie**; tudo foi lido da documentação dele em 23/10/2026.

## Quem manda dado para quem, quando e por quê

- **Hub para Omie, ao virar pedido.** O vendedor transforma a proposta em pedido no hub. O hub envia o pedido ao Omie pelo método `IncluirPedido` (a chamada do Omie que cria pedido de venda). Por quê: o faturamento acontece no Omie.
- **Uma conta Omie por unidade.** São três contas: Mogi (Aços Vital), Arujá (HRM) e Uberaba (Aços Uberaba). O pedido vai à conta da empresa emissora da proposta (N16-79, N16-80).
- **O hub manda só o necessário para faturar:** cliente, produtos, quantidades, preços, condição de pagamento, vendedor. O que só o hub tem fica no hub: Qualidade, faturamento em partes, previsões, requisitos e moeda de origem (decisão do Nathan, 23/10).
- **Omie para hub, na volta.** O Omie devolve o código e o número do pedido. A pipeline (o programa que copia dados do Omie para o hub) lê o pedido de volta e compara total, itens e códigos. Se algo divergir, o pedido recebe um aviso e **não é liberado**.
- **Moeda.** O Omie não tem campo de moeda. Proposta em dólar ou euro vira reais pela cotação do Banco Central (PTAX) do dia da aprovação (N16-13, N16-27). O pedido do hub e o do Omie ficam em reais.
- **Impostos.** O vendedor digita ICMS, IPI e ST na proposta, e esses valores vão para o pedido (N16-95). O Omie pode recalcular, então o total da proposta e o da nota podem divergir. Isso é ponto de atenção.
- **Quando o pedido não vai:** se o cliente não tem cadastro na conta do Omie, ou se o produto ainda é pendente (N16-28).
- **Condição de pagamento.** Hoje a proposta guarda texto livre, mas o Omie quer um código cadastrado, diferente em cada conta. A proposta é usar o código real e mandar só ele 🟡. A pipeline ainda precisa copiar essas condições 🔴.

## O que ainda não sabemos

Os testes no Omie ficam para depois que as telas estiverem prontas (N16-82). O Omie não tem ambiente de teste, então usa-se cadastros TESTE no ambiente real. Perguntas em aberto: mínimo obrigatório por conta, se o pedido nasce bloqueado, como o Omie trata CFOP e cenário de impostos, e como conta o vencimento das parcelas. A lista de 13 testes está na seção 6 do detalhe (OQ-16).

Complementa o [[Estudo-Omie-API]]. Selos: ✅ está na documentação ou no código · 📝 decisão do Nathan · 🟡 proposta · 🔴 não existe · ❓ não conferido.

## Detalhe técnico

Complementa o [[Estudo-Omie-API]]. Aqui a documentação do `IncluirPedido` foi lida campo a campo e cruzada com a proposta do hub. **Nenhuma chamada foi feita ao Omie**: tudo o que depende de comportamento real está marcado ❓ e entra na lista de testes da seção 6.

Selos: ✅ está na documentação ou no código · 📝 decisão do Nathan · 🟡 proposta · 🔴 não existe · ❓ não conferido.

### 1. O método em uma tela

- **Endpoint:** `https://app.omie.com.br/api/v1/produtos/pedido/`, método `IncluirPedido` ("Inclui um pedido de venda de produto"). ✅
- **Entrada e saída:** recebe `pedido_venda_produto` e devolve `codigo_pedido`, `codigo_pedido_integracao`, `numero_pedido`, `codigo_status` e `descricao_status`. ✅ Erro vem no formato `omie_fail` (`code`, `description`, `referer`, `fatal`). ✅
- **Mesma estrutura para incluir, alterar e consultar:** o `AlterarPedidoVenda` e o `ConsultarPedido` usam o mesmo objeto. ✅ Isso permite ler de volta o que o Omie gravou e comparar com o que enviamos.
- **Outros métodos do serviço:** `ListarPedidos`, `ConsultarPedido`, `StatusPedido`, `TrocarEtapaPedido`, `AlterarPedFaturado`, `SimularImpostos`, `DevolverPedido` e `ExcluirPedido`. ✅ **Não existe** método de cancelar pedido. ✅
- **Cada conta Omie é uma unidade — são três:** Mogi (Aços Vital), Arujá (HRM) e Uberaba (Aços Uberaba), no mesmo sistema do Hub (N16-79). O pedido vai à conta da empresa emissora da proposta (a unidade da proposta, `core.unidades`; N16-80). ✅

### 2. Cabeçalho (`cabecalho`)

| Campo do Omie | Tipo | O que o hub manda | Origem no hub | Situação |
|---|---|---|---|---|
| `codigo_cliente` | inteiro | ID do cliente **na conta Omie da emissora** | `cliente_unidade_omie` | ✅ obrigatório no exemplo. Cliente sem cadastro na conta **não vira pedido** (`CLIENTE_SEM_CADASTRO_OMIE`) |
| `codigo_cliente_integracao` | texto 60 | alternativa ao ID | — | 🟡 não usar: o ID é mais direto |
| `codigo_pedido_integracao` | texto 60 | o **nosso código** do pedido | `pedido_venda.codigo_pedido_integracao` (= número do hub) | ✅ chave de idempotência; a pipeline consulta por ele antes de recriar |
| `numero_pedido` | texto 15 | o número do pedido que **nós** geramos | `pedido_venda.numero` | ✅ o campo existe e o exemplo o manda. ❓ O Omie aceita o número nosso ou renumera? Se renumerar, o número do Omie continua a chave no MES |
| `data_previsao` | texto 10 (`dd/mm/aaaa`) | previsão de **faturamento** | **a data que o vendedor informa, obrigatória**, ao transformar em pedido; depois passa a ser a **vigente** (entrega do fornecedor mais recente + 1; N16-88) | ✅ o Omie chama de "Data de Previsão de Faturamento". A previsão vigente (entrega + 1 dia útil) **não volta ao Omie** (N16-91); o Omie guarda a inicial |
| `etapa` | texto 2 | `"10"` | fixo | ✅ exemplo; ❓ o nome das etapas 10, 15, 20 da conta (`ListarEtapasFaturamento`) |
| `codigo_parcela` | texto 3 | `"999"` quando mandamos `lista_parcelas`; ou o código da condição cadastrada | `proposta.codigo_parcela_omie` | ✅ exemplo; ❓ ver seção 5 (condição de pagamento) |
| `qtde_parcelas` | inteiro | — | — | 🟡 deixar o Omie deduzir de `lista_parcelas` |
| `quantidade_itens` | inteiro | número de linhas de `det` | contagem | ✅ exemplo |
| `origem_pedido` | texto 3 | — | — | ❓ para que serve (ex.: marcar "API"); o Omie já marca `importado_api`/`cImpAPI` sozinho |
| `bloqueado` | texto 1 | `"N"` | fixo | ✅ campo existe ("Pedido Bloqueado pela API"). ❓ **O pedido nasce bloqueado por padrão?** Se nascer, o Fiscal não fatura sem desbloquear (`AlterarPedidoVenda` com `bloqueado = "N"`) |
| `codigo_cenario_impostos` | inteiro | cenário de impostos da conta | cadastro | 🔴 hoje o hub não guarda; ❓ é obrigatório? |
| `tipo_desconto_pedido`, `perc_desconto_pedido`, `valor_desconto_pedido` | — | — | — | 🟡 não usar: o desconto vai por item |
| `encerrado`, `enc_motivo`, `enc_data`, `enc_hora`, `enc_user` | — | — | — | ✅ existem na resposta; relacionam com o **encerramento por saldo zerado** de "Meus Pedidos" (outra frente) |
| `nao_gerar_boleto` | texto 1 | — | — | 🟡 decidir com o Financeiro |
| `cbs`, `ibs` | — | — | — | ✅ já existem no tipo (reforma tributária); não enviar, o Omie calcula |

### 3. Itens (`det`, uma linha por item)

#### 3.1 Identificação (`ide`)

| Campo | O que mandar | Origem | Situação |
|---|---|---|---|
| `codigo_item_integracao` | código nosso do item, até 30 caracteres | `pedidos_itens.id` ou ordem | ✅ obrigatório no exemplo. A pipeline **grava de volta** o `codigo_item_omie` por item (hoje chega por `ListarPedidos`) |
| `simples_nacional` | `"S"`/`"N"` | emissora | ❓ o Omie deduz da empresa? |
| `acao_item` | só em alteração | — | ✅ |
| `id_ordem_producao` | — | — | ❓ ver se o Omie liga o PV a uma OP dele; não é o nosso PCP |

#### 3.2 Produto (`produto`)

| Campo | Tipo | Origem | Situação |
|---|---|---|---|
| `codigo_produto` | inteiro (ID do Omie) | `core.produtos.codigo_produto_omie` | ✅ exemplo. **Produto pendente (`PEND-xxxx`) não tem ID** → a proposta não vira pedido até o Fiscal cadastrar (N16-28) |
| `codigo_produto_integracao`, `codigo` | texto | — | 🟡 mandar só o ID; manter o código para exibição |
| `descricao` | texto 120 | `proposta_item.descricao` | ✅ exemplo. 🟡 **limite de 120 caracteres**: a descrição técnica da proposta pode passar; cortar com aviso na proposta; o texto inteiro fica no Hub |
| `cfop` | texto 10 | **regra fiscal** (finalidade, UF, tipo) | ✅ exemplo manda `5.102`. ❓ Se não mandar, o Omie deduz pelo cenário? Hoje o hub **não** calcula CFOP |
| `ncm` | texto 13 | `proposta_item.ncm` | ✅ exemplo |
| `unidade` | texto 6 | `unidade_medida` | ✅ exemplo. 🟡 conferir se a UM do hub é a mesma do cadastro Omie do produto |
| `quantidade` | decimal | `quantidade` | ✅ |
| `valor_unitario` | decimal | `preco_unitario` | ✅. ❓ **Preço com ou sem imposto?** A proposta mostra "ICMS (incluso)"; o Omie, pelo exemplo, soma impostos por cima quando há IPI e ST |
| `tipo_desconto`, `valor_desconto`, `percentual_desconto` | `"V"`/`"P"` | `desconto_pct` | ✅ exemplo manda `"V"` e 0. 🟡 enviar **valor** (`V`) para evitar divergência de arredondamento |
| `valor_mercadoria`, `valor_total` | decimal | cálculo | 🟡 não mandar; conferir pela leitura de volta |
| `codigo_tabela_preco` | inteiro | — | 🟡 não usar |
| `reservado` | `"S"`/`"N"` | — | ❓ **reserva estoque no Omie**; o nosso estoque é o MES, então `"N"` |
| `ean`, `cnpj_fabricante`, `indicador_escala`, `kit`, `valor_deducao`, `valor_icms_desonerado` | — | — | 🟡 não usar |

#### 3.3 Informações adicionais do item (`inf_adic`)

| Campo | O que mandar | Situação |
|---|---|---|
| `peso_bruto`, `peso_liquido` | peso do item (kg) | ✅ exemplo manda 150/150. 🔴 o hub **não guarda peso** na proposta; ❓ o Omie busca do cadastro do produto? |
| `numero_pedido_compra`, `item_pedido_compra` | liga o item de venda a um pedido de compra | ❓ **poderia ligar PV e PC no Omie**; hoje o vínculo é nosso (requisição do PCP). Não usar até testar |
| `nao_movimentar_estoque`, `nao_gerar_financeiro` | `"N"` | 🟡 conferir com o Fiscal |
| `codigo_local_estoque` | local de estoque | ❓ por unidade |
| `dados_adicionais_item` | texto para a NF | 🟡 candidato a levar norma, material e certificados da proposta |
| `codigo_cenario_impostos_item` | cenário por item | ❓ ver seção 4 |

#### 3.4 Observação do item (`observacao.obs_item`)

**Não usamos** (N16-90): a especificação técnica fica só no Hub. A `descricao` do Omie tem limite de 120 caracteres; o excesso é cortado com aviso na tela do Hub, que mantém a descrição inteira.

### 4. Impostos de venda

- **Cenários e CFOP (lidos em 23/10/2026, serviço `/geral/cenarios/`):** `ListarCenarios` lista os cenários da conta (`nCodigo`, `cNome`, `padrao`, tipo de empresa, `inativo`); `ListarImpostosCenario` recebe cliente, produto e cenário e devolve **o CFOP e todas as alíquotas** (ICMS, ST, IPI, PIS, COFINS, IBS, CBS). ✅ O Omie também tem o serviço **CFOP** (`/produtos/cfop/`) e **Origem do Pedido** (`/geral/origempedido/`), ainda não lidos ❓. **Decisão do Nathan (N16-83):** o CFOP e o cenário se escolhem ao cadastrar o produto na proposta; o CFOP já está no banco do Hub e os cenários vêm do Omie. 🔴 Falta o recurso de pipeline que sincroniza os cenários por conta. 🟡 `ListarImpostosCenario` pode ser a fonte das alíquotas **mostradas na proposta**, no lugar do `SimularImpostos`; testar qual bate com o pedido.
- O exemplo de `IncluirPedido` **não manda imposto**: o Omie calcula pelo cenário de impostos da conta. ✅
- Existe `SimularImpostos` (cliente, UF de entrega, frete, itens com cenário) que devolve ICMS, ST, IPI, PIS e COFINS **por item**. ✅
- O hub deixa o vendedor **digitar** ICMS %, IPI % e ST % em cada item e mostra "ICMS (incluso)". **Decisão do Nathan (N16-95): isso continua**: os impostos digitados vão para o pedido e o Hub não os troca pelos do Omie. ⚠️ O risco que eu apontei (o total da proposta pode diferir do que o Omie fatura) fica como **ponto de atenção**, não como regra.
- O imposto **é o que o vendedor digitou** (N16-95); o Omie não o substitui. O `SimularImpostos` e o `ListarImpostosCenario` podem servir só de **conferência opcional**. ❓ Falta definir se o Hub manda os impostos digitados em `det[].imposto` do `IncluirPedido` (o tipo `det` tem o bloco `imposto`) ou se o Omie os calcula pelo cenário; e onde o Fiscal os altera.
- `total_pedido` (`valor_total_pedido`, `valor_mercadorias`, impostos) existe na resposta; 🟡 usar para **conferir** o total depois da inclusão: se divergir da proposta, marcar o pedido com aviso e não liberar.

### 5. Condição de pagamento, frete, informações adicionais

#### 5.1 Parcelas (`lista_parcelas.parcela[]`)

| Campo | Observação |
|---|---|
| `numero_parcela`, `valor`, `percentual`, `data_vencimento` | exemplo manda os quatro. Com `codigo_parcela = "999"` o Omie aceita parcelas à mão |
| `quantidade_dias` | alternativa a `data_vencimento` ("dias até o vencimento") — 🟡 melhor para condição do tipo 28/45: o vencimento real depende da data de **faturamento**, não da inclusão |
| `tipo_documento`, `meio_pagamento`, `nao_gerar_boleto`, `parcela_adiantamento` | 🟡 `meio_pagamento` (campo `tPag` da NF) precisa de decisão do Financeiro |

🔴 **A proposta tem a condição de pagamento como texto livre** (`condicao_pagamento`, 200 caracteres) e **outro campo separado** para a "condição (tabela de encargos)" da análise. O Omie precisa de uma condição **cadastrada** (código) ou de parcelas calculadas.

**Serviço de condições de pagamento do Omie (lido em 23/10/2026):** `https://app.omie.com.br/api/v1/geral/parcelas/`. ✅

| Método | Entrada | Saída |
|---|---|---|
| `ListarParcelas` | `pagina`, `registros_por_pagina`, `filtrar_por_descricao`, `ordenar_por`, `apenas_importado_api` | por condição: `nCodigo` (texto de 3, é o `codigo_parcela` do pedido), `cDescricao` (até 30) e `nParcelas` (quantidade) |
| `IncluirParcela` | `cParcela` (a **descrição** da parcela a criar) | `cCodParcela` (código gerado, 3), `cDesParcela` (descrição, até 200), `cCodStatus` (`"0"` é sucesso) |

**Precedente no nosso código: é o mesmo esquema da ordem de compra.** ✅ (lido em `omie-elt-pipeline/src/omie/ordemCompraOmie.ts:305-326`, `resources/condicoesPagamentoCompras.ts` e `api-acos-vital/.../condicoes_pagamento_compras`)

| | **Ordem de compra** (já em produção) | **Pedido de venda** (a construir) |
|---|---|---|
| Campo do Omie | `cCodParc` (ex.: `"U10"`) | `codigo_parcela` (ex.: `"999"`) |
| Tamanho | código de 3 caracteres | código de 3 caracteres (`string3`) |
| Catálogo | `ListarFormasPagCompras`, serviço `/produtos/formaspagcompras/` | `ListarParcelas`, serviço `/geral/parcelas/` |
| Por conta Omie | sim, tabela `condicoes_pagamento_compras` com `codigo_empresa` + `codigo_omie` | sim, mesma lógica; **a tabela espelho ainda não existe** 🔴 |
| O que o catálogo traz | código, descrição, `nQtdeParc`, **`cListaParc`** (dias, ex. "30,40,50") e `nDiasParc` | código, descrição e `nParcelas`; **não traz a lista de dias** |
| Pipeline sincroniza | sim, "sempre ligado", camada lenta | **não** (nenhum recurso lê o `ListarParcelas`) 🔴 |
| O que a OC/pedido manda | **só o código e a quantidade** (`cCodParc` + `nQtdeParc`), sem parcelas | 🟡 o mesmo: **só `codigo_parcela`**, sem `lista_parcelas` |

**O teste de 05/10/2026 em Mogi (comentário em `ordemCompraOmie.ts`) vale para a venda:** na OC, mandar `parcelas_upsert` fez o Omie **trocar a condição para 999** ("informar parcelas"); sem mandar as parcelas, a condição `S18` ficou `S18` e o Omie gerou 30/60/90 dias pelos prazos dela. Ou seja, o `"999"` com `lista_parcelas` do exemplo da documentação **faz o pedido perder a condição de pagamento**, e o código real é o caminho que o Nathan já escolheu na compra. ❓ Falta confirmar na venda (o comportamento é o do Omie, mas o método é outro).

O que isso resolve e o que não resolve:

- ✅ **A condição é cadastro do Omie, por conta.** O código (`nCodigo`) de "28/45" pode ser **diferente em Mogi e em Uberaba**. O hub não pode gravar um código único: precisa guardar **um código por conta**, lido do `ListarParcelas`.
- ✅ **A lista só traz descrição e número de parcelas**, não os dias nem os percentuais. Então o vínculo entre a condição do hub (a chave da tabela de encargos, ex. `28/45`) e a do Omie é pela **descrição**. 🟡 Se a descrição do Omie for "28/45 DDL" e a do hub "28/45", o casamento falha: é preciso uma tabela de **de-para** (condição do hub × descrição Omie por conta), preenchida uma vez e conferida.
- ✅ **O `IncluirParcela` cria a condição só com a descrição.** ❓ Não sabemos se o Omie **interpreta** o texto (ex.: lê "28/45" como duas parcelas em 28 e 45 dias) ou só guarda o nome; só o teste diz. 🟡 Não criar condição por API sem esse teste: criar duplicada ou errada polui o cadastro da empresa inteira.
- 🟡 **Fluxo proposto:** (1) a pipeline sincroniza o `ListarParcelas` de cada conta para uma tabela do hub; (2) a proposta oferece **apenas** as condições que existem **na conta da empresa emissora** (e têm encargo na tabela do motor); (3) ao transformar em pedido, `codigo_parcela` recebe o `nCodigo` da conta; (4) condição digitada à mão que não existe na lista **não é aceita** ("peça ao Financeiro para cadastrar no Omie").
- ❓ **Condição à vista, "A combinar" e "999":** a lista pode ter códigos especiais; o `"999"` do exemplo é "parcelas informadas no pedido". Conferir no `ListarParcelas` da conta.
- 🔴 **O catálogo de venda não traz os dias de cada condição** (o de compra traz `cListaParc`). Com `codigo_parcela` cadastrado, o Omie calcula os vencimentos sozinho (na OC o prazo contou a partir da data de previsão; ❓ na venda, a partir de quê?). 🟡 O hub **não precisa** dos dias para criar o pedido. Só precisaria para **mostrar o vencimento na proposta ou no PDF**; nesse caso: ou se lê `ConsultarPedido` depois de incluir, ou se cadastra os dias no de-para (condição do hub × código Omie × dias).
- 🟡 **Decisão proposta:** usar o **código real** (`codigo_parcela`) e **não mandar `lista_parcelas`**, igual à OC. `"999"` com parcelas só para condição especial combinada com o cliente que não exista no cadastro, e então a perda da condição é aceita e avisada.

#### 5.2 Frete (`frete`)

| Campo | Observação |
|---|---|
| `modalidade` | `"9"` no exemplo (sem frete). Os valores do Omie seguem a NF-e: 0 emitente, 1 destinatário, 2 terceiros, 3 e 4 próprio, 9 sem frete. 🟡 mapear o incoterm do hub (CIF, FOB, …) para a modalidade; ❓ confirmar a tabela na documentação do campo |
| `valor_frete`, `valor_seguro`, `outras_despesas` | 🟡 o frete da proposta (CIF) vai em `valor_frete` |
| `codigo_transportadora`, `placa`, `peso_*`, `quantidade_volumes` | 🟡 opcionais; transportadora não existe na proposta |

#### 5.3 Informações adicionais (`informacoes_adicionais`)

| Campo | O que mandar | Origem | Situação |
|---|---|---|---|
| `codigo_categoria` | categoria financeira (ex. `1.01.03`) | configuração da conta | 🔴 não existe no hub; ❓ fixa por conta? |
| `codigo_conta_corrente` | conta corrente de recebimento | configuração da conta | 🔴 idem |
| `consumidor_final` | `"S"`/`"N"` | `finalidade = CONSUMO_FINAL` | 🟡 |
| `enviar_email` | `"N"` | fixo | ✅ exemplo (não mandar boleto por e-mail no pedido) |
| `codVend` | ID do vendedor no Omie | `pedido_venda.codigo_vendedor_omie` | ✅ já existe no desenho; **necessário para a comissão e para o relatório por vendedor** |
| `codProj` | projeto | — | 🟡 projeto de venda; ver "Projeto" (OQ-44) |
| `numero_pedido_cliente` | nº da requisição/pedido do cliente | `numero_requisicao_cliente` | ✅ existe na proposta |
| `numero_contrato`, `contato` | — | — | 🟡 `contato` pode levar o comprador |
| `dados_adicionais_nf` | texto da NF | `observacoes`? | ❓ o que da proposta deve sair na NF |
| `meio_pagamento`, `tipo_documento`, `nfRelacionada`, `outros_detalhes` | — | — | 🟡 `outros_detalhes.cNatOperacaoOd` (natureza da operação) e local de retirada/entrega só se necessário |

#### 5.4 Observações (`observacoes.obs_venda`)

**Não usamos** (decisão do Nathan, 23/10): os dados que o Hub tem e o Omie não (Qualidade, faturamento em partes, previsões, requisitos, moeda de origem) **ficam só no Hub**. O Omie recebe o que ele precisa para faturar e nada mais.

### 6. O que a documentação **não** responde (testes no Omie, OQ-16)

**Decisão do Nathan (N16-82): os testes ficam para depois que as telas estiverem prontas**; cadastra-se pelas telas e vão-se cortando as rebarbas ou acrescentando o que falta, como foi feito com a OC. Já respondidos: o Omie **aceita o nosso `numero_pedido`** (item 2); o vencimento conta do **faturamento** (item 9, provisório); o catálogo de condições é **por unidade** (as três contas são puxadas e cada unidade vê a sua); apagar o pedido no Hub apaga no Omie e o código de integração pode ser reutilizado (item 12). Sem ambiente de teste, os testes usam cadastros TESTE no ambiente real e devem ser feitos por quem tem acesso, um por vez:

1. **Mínimo obrigatório:** qual é o menor `IncluirPedido` que o Omie aceita em Mogi, em Arujá e em Uberaba (as três contas podem exigir coisas diferentes).
2. **`numero_pedido` próprio:** o Omie aceita o nosso número ou gera outro?
3. **Bloqueio:** o pedido incluído por API nasce `bloqueado`? O Fiscal consegue faturar sem mexer?
4. **CFOP e cenário:** se não mandarmos `cfop` e `codigo_cenario_impostos`, o Omie preenche certo?
5. **Preço com ou sem imposto:** o `valor_unitario` é a base e o Omie soma IPI e ST por cima? O total do pedido bate com o total da proposta?
6. **`SimularImpostos`** dá o mesmo valor do pedido incluído?
7. **Peso:** o Omie preenche `peso_bruto`/`peso_liquido` do cadastro do produto?
8. **Descrição:** o que acontece com descrição acima de 120 caracteres?
9. **Parcelas:** com `codigo_parcela` cadastrado, o Omie calcula o vencimento a partir do **faturamento**? `quantidade_dias` conta a partir de quê (inclusão ou faturamento)? `"999"` com `lista_parcelas` × condição cadastrada. O `IncluirParcela` interpreta a descrição ("28/45") ou só a guarda? O código de uma mesma condição é diferente em Mogi e em Uberaba?
10. **Moeda:** ver abaixo.
11. **Cancelamento:** `CancelarPedidoVenda` (serviço `pedidovendafat`) e `ExcluirPedido`: o que cada um faz num pedido não faturado e o que o `ListarEtapasPedido` devolve (`cCancelado`, data, usuário).
13. **Sequencial:** criar um sequencial (faturar em partes) por `IncluirPedido` com `cabecalho.sequencial`, com itens e quantidades parciais; ver se o valor sai do original e volta ao cancelar. Testar quando a tela de "Faturamento em partes" existir (N16-92, N16-93).
12. **Reenvio:** repetir o `IncluirPedido` com o mesmo `codigo_pedido_integracao` devolve erro ou o pedido existente?

### 7. Dois achados que mudam o desenho

1. **O `IncluirPedido` não tem campo de moeda.** ✅ (nenhum campo de moeda ou cotação no cabeçalho, no item ou no total, nesta documentação). Proposta em USD ou EUR precisa virar **reais** antes de ir ao Omie, pela PTAX do dia da aprovação (N16-13, N16-27). 🟡 O contrato precisa dizer: a proposta guarda moeda e câmbio; o **pedido do hub e o do Omie ficam em reais**, com o valor convertido congelado e o câmbio gravado. Existe o bloco `exportacao` (`nao_exportacao`, local de embarque, UF, local de despacho) para cliente estrangeiro. ❓ Testar com cliente estrangeiro de teste.
2. **O Omie recalcula impostos.** O total da proposta (digitado) e o total da nota (calculado) podem divergir. A solução proposta é a da seção 4: mostrar e conferir pelo Omie.

### 8. O que isso muda nos contratos

- **Pedido no Hub:** `pedidos` precisa guardar `valor_total_omie` (conferência), `status_etapa_omie`, a resposta de `ConsultarPedido` em JSON para auditoria, o câmbio usado e o `valor_frete`/`modalidade_frete` já mapeados. 🟡
- **Conferência na pipeline:** a pipeline lê o pedido de volta (`ConsultarPedido`) depois de incluir e compara total, itens e `codigo_item_omie`; divergência marca o pedido com aviso e **não libera**.
- **Condições de pagamento de venda por conta:** desenhado (amostra real de 330 condições, dias inferidos da descrição, de-para automático com os encargos). Novo recurso na pipeline (`condicoesPagamentoVenda`, `ListarParcelas`, camada lenta, no molde do `condicoesPagamentoCompras`) e tabela espelho (`codigo_empresa`, `codigo_omie`, `descricao`, `quantidade_parcelas`), mais o de-para com a chave da tabela de encargos do motor. 🔴 não existe
- **Categoria, conta corrente, projeto e etapa já são sincronizados** pela pipeline (`categorias`, `contasCorrentes`, `projetos`, `etapasFaturamento`, `vendedores`). ✅ Não é preciso digitar códigos: a configuração por conta **escolhe** da lista sincronizada. 🟡 O que falta é guardar **qual** categoria, conta corrente e cenário o pedido de venda usa em cada conta.
- **Configuração por conta Omie** (nova tabela ou parâmetros): `codigo_categoria`, `codigo_conta_corrente`, `codigo_cenario_impostos`, etapa inicial e local de estoque, **por conta** (Mogi e Uberaba). 🔴 hoje não existe lugar.
- **Proposta:** ver [[14-Telas-e-Experiencia-do-Usuario]] para o que isso muda na tela (condição de pagamento escolhida de uma lista, imposto vindo do Omie, destino derivado do cliente).

### Ver também

[[Estudo-Omie-API]] · [[11-Proposta-e-Pedido-de-Venda]] · [[14-Telas-e-Experiencia-do-Usuario]]
