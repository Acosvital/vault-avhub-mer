---
tags: [pesquisa, omie, api, pedido, compra, recebimento, nf, cancelamento, oq-15, oq-16, oq-37, staging]
criado: 2026-10-21
atualizado: 2026-10-21
status: proposta
dono: Nathan
fontes: [documentação pública do Omie lida em 21/10/2026: app.omie.com.br/api/v1/produtos/pedido/ (PedidoVendaProduto), /produtos/pedidocompra/ (PedidoCompra), /produtos/recebimentonfe/ (RecebimentoNFe), /produtos/nfconsultar/ (NFConsultar); vault-avhub-mer-v2 Omie-Integracao-Estado e Omie-Dicionarios/Pedidos-de-Venda; Perguntas-Proposta-Pedido-Comissao OQ-15, OQ-16, OQ-17, OQ-37, OQ-39, OQ-48; Registro-de-Decisoes]
---

# Estudo do Omie para o projeto (21/10/2026)

**O que é esta nota.** Resultado da leitura da documentação da API do Omie, cruzada com o que a pipeline do hub já faz (vault: [[Omie-Integracao-Estado]] e [[Pedidos-de-Venda]]). Marquei ✅ o que a **documentação mostra**, 🟡 o que é **leitura minha** e ❓ o que **só um teste real no Omie resolve**. O Omie **não tem ambiente de teste** (cadastros TESTE no ambiente de verdade): nenhum teste foi feito, só leitura.

## 1. Pedido de venda (`/produtos/pedido/`)

**Métodos do serviço:** `IncluirPedido`, `AlterarPedidoVenda`, `ConsultarPedido`, `ListarPedidos`, `StatusPedido`, `TrocarEtapaPedido`, `ExcluirPedido`, `DevolverPedido`, `AlterarPedFaturado`, `SimularImpostos`. **Não existe** método de cancelar nem de encerrar pedido.

### Criar o pedido (V0.7): responde a OQ-15 e a OQ-16
| O que a documentação mostra | Efeito no projeto |
|---|---|
| ✅ `cabecalho.codigo_pedido_integracao` (texto de até 60) é o **nosso código** do pedido. Serve para consultar, alterar e excluir sem conhecer o número do Omie | **Resolve a OQ-15:** o hub sabe a chave **antes** de o Omie responder. A liberação pode ser gravada **na resposta do `IncluirPedido`**, que devolve `codigo_pedido` e `numero_pedido` (a opção (b) que eu já tinha como padrão) |
| 🟡 A tabela `pedidos_vendas` do hub **não guarda** `codigo_pedido_integracao` (não está no dicionário do vault) | A pipeline precisa **gravar esse campo**, para ligar a proposta ao pedido que volta no `ListarPedidos` |
| ✅ `det[].ide.codigo_item_integracao` (texto de até 30) é o código do **item** no nosso sistema. O `ConsultarPedido` devolve o `codigo_item` do Omie na mesma linha | Dá o vínculo **item da proposta ↔ `codigo_item_omie`** que o `comissao_itens_vinculo` precisa. Hoje o vínculo seria montado por casamento; com este código, é direto |
| ✅ `cabecalho.etapa` no exemplo do `IncluirPedido` é `"10"` | **OQ-16:** etapa inicial = `"10"`. 🟡 Confirmar na conta: o nome das etapas 10, 15 e 20 ainda está pendente no vault (#52); a lista vem de `ListarEtapasFaturamento` |
| ✅ Campos do exemplo de inclusão: `codigo_cliente`, `data_previsao`, `codigo_parcela` (`"999"` com `lista_parcelas`), `quantidade_itens`, `frete.modalidade`, `informacoes_adicionais` (`codigo_categoria`, `codigo_conta_corrente`, `consumidor_final`, `codVend`, `codProj`, `numero_pedido_cliente`, `numero_contrato`), `observacoes.obs_venda`, e por item `produto` (`codigo_produto`, `quantidade`, `valor_unitario`, `cfop`, `ncm`, `unidade`, `tipo_desconto`, `valor_desconto`) | É a lista de campos do **contrato do pedido por API**. ❓ Quais são **obrigatórios na conta de vocês** só o teste diz (categoria, conta corrente e vendedor variam por filial) |
| ✅ O exemplo envia `cabecalho.numero_pedido` (`"40451"`) | 🟡 Parece que dá para **mandar o nosso número**, o que simplificaria a numeração própria (N16-26). ❓ Testar se o Omie aceita e se mantém o número sem renumerar |
| ✅ `cabecalho.bloqueado` ("Pedido Bloqueado pela API") e `importado_api` | 🟡 Pedido **criado por API** pode nascer **bloqueado para edição na tela do Omie**. ❓ Testar: se sim, o `AlterarPedidoVenda` com `bloqueado = "N"` pode ser necessário para o Fiscal faturar normalmente |
| ✅ Não há campo de imposto de venda obrigatório no exemplo de inclusão; existe `codigo_cenario_impostos` e o método **`SimularImpostos`** (devolve ICMS, ST, IPI, PIS, COFINS por item) | 🟡 O Omie **calcula** o imposto de venda pelo cenário. O `SimularImpostos` pode alimentar o simulador (ST e DIFAL da venda) **sem digitação** |
| ✅ Itens aceitam `inf_adic.numero_pedido_compra` e `item_pedido_compra` | Existe campo para ligar o item de venda a um pedido de compra no próprio Omie 🟡 |

### Cancelar, devolver e encerrar (OQ-17 e OQ-48)
| O que a documentação mostra | Efeito no projeto |
|---|---|
| ✅ **Existe `CancelarPedidoVenda`** (serviço `/produtos/pedidovendafat/`, entrada `nCodPed` ou `cCodIntPed`). **Correção de 23/10:** a primeira leitura olhou só o serviço `/produtos/pedido/` e concluiu errado que não havia cancelar. Esse serviço (Faturamento) também tem `FaturarPedidoVenda`, `ValidarPedidoVenda`, `DuplicarPedidoVenda`, `AssociarCodIntPedidoVenda` e `ObterPedidosVenda`. O serviço `/produtos/pedidoetapas/` (`ListarEtapasPedido`) devolve por pedido `cancelamento` (`cCancelado`, data, usuário), `devolucao` (`cDevolvido`) e `faturamento` (NF, chave, autorização) | O **vendedor** cancela, edita e exclui o pedido pelo Hub, que chama o Omie (N16-84). O hub registra o cancelamento e confirma lendo o `ListarEtapasPedido`. ❓ Testar a diferença entre `CancelarPedidoVenda` e `ExcluirPedido` |
| ✅ **`ExcluirPedido`** existe (por `codigo_pedido` ou `codigo_pedido_integracao`) | 🟡 Serve para pedido **ainda não faturado**. **Risco:** a pipeline tem o `exclusionSync`, que **apaga do hub** o pedido que sumiu do Omie (janelas de 60 e 180 dias). O pedido excluído **perderia a trilha** no hub: o `core_comercial.pedido_venda` precisa guardar o **cancelamento por conta própria** (a tarja e o histórico da N16-68) |
| ✅ **`DevolverPedido`** (por `itens` com `codigo_produto` e `quantidade`) devolve `nIdDevolucao` | A **devolução parcial por item** existe no Omie. Apoia o abatimento proporcional (N16-47) |
| 🟡 A documentação do `ListarNF` lista, por item, `cItemDevolvido` e `nItemQtdDevolvida`. **O Nathan corrige (21/10): "devolvido" é a devolução total e vem do Omie; a devolução parcial não vem com quantidade.** Tratar a quantidade como **indisponível**. Existem também `cCancelado`, `cDevolvido`, `cDevParcial` e a finalidade da NF (`finNFe`), que são só verdadeiro ou falso | O abatimento proporcional por devolução (N16-47) **não pode contar** com a quantidade devolvida vinda do Omie. Alternativas ❓: (a) **registrar a devolução no hub**, com quantidade e NF de origem (quem registra: Fiscal ou Controladoria?); (b) usar o **valor da NF de devolução** como proporção; (c) ligar a NF de devolução à original pela **chave referenciada** (`nfRelacionada`). Pergunta ao Fiscal: como a devolução é lançada hoje e onde fica a quantidade |
| ✅ O pedido tem `encerrado`, `enc_motivo`, `enc_data`, `enc_hora`, `enc_user`, mas **não há método para encerrar** | Confirma que **"encerrar" só existe na tela** e ninguém a usa. Reforça calcular o encerramento no banco (a frente de "Meus Pedidos: encerrar pedido zerado") |
| ✅ `StatusPedido` devolve `etapa`, `cancelada`, `faturada` e a lista de NF-e (`ListaNfe`: número, chave, status, data) | Consulta barata do estado de **um** pedido, útil para a tela de "Meus Pedidos" sem esperar o sync |
| ❓ "Operação não realizada" e "Operação desconhecida" (manifestação do destinatário) **não estão nestes serviços** | Hoje vêm do **scraping** da pipeline (`manifestos`, das 3 unidades: Aços, HRM e Uberaba; correção do Nathan, 22/10). O abatimento por **recusa** depende dessa cobertura (OQ-42) |

## 2. Pedido de compra (`/produtos/pedidocompra/`): responde a OQ-37 em parte
| O que a documentação mostra | Efeito no projeto |
|---|---|
| ✅ **O item do pedido de compra TEM imposto por valor:** `nValorIcms`, `nValorSt`, `nValorIpi`, `nValorPis`, `nValorCofins`. Na consulta vêm também `nFrete`, `nSeguro`, `nDespesas` e `nValTot` (total do item com descontos, despesas e impostos) | **Confirma Compras:** o Omie guarda IPI, ICMS, ST, PIS e COFINS **por item**, em **valor** (não em percentual) |
| ✅ **Não há DIFAL** em nenhum item do pedido de compra | O **DIFAL da compra** não existe nesse serviço. Reforça deixá-lo **fora do custo** (provisório) |
| ✅ A pipeline do hub **espelha** o pedido de compra (`PesquisarPedCompra`), mas a tabela `pedidos_compras_itens` **só guarda `valor_total`** (com o IPI embutido) e não os impostos | **A carga que você vai fazer é ampliar esse espelho:** gravar `nValorIcms`, `nValorSt`, `nValorIpi`, `nValorPis`, `nValorCofins`, `nFrete`, `nSeguro` e `nDespesas` por item |
| ✅ O hub **envia** a OC com `UpsertPedCompra` (`cCodIntPed` = número da OC; "sem parcelas", só `cCodParc` e `nQtdeParc`). O `IncluirPedCompra` e o `UpsertPedCompra` **aceitam** `nValorIcms` etc. por item | O **caminho de volta** (o que Compras edita no hub voltar ao Omie, N16-53) existe: basta o envio da OC mandar esses campos. Hoje o envio **não os manda** (vault) |
| ✅ **`cNumPedido`** ("Número do pedido para o fornecedor", até 30) existe no cabeçalho | É o campo **"Nº do Pedido do Fornecedor"** que Compras usa para ligar a OC de serviço a um **PV** (mão de obra). O hub precisa lê-lo e gravá-lo |
| ✅ `PesquisarPedCompra` filtra por pendentes, faturados, **recebidos**, **cancelados**, **encerrados**, recebidos parcialmente e faturados parcialmente | O Omie conhece o estado de **recebimento** da OC |
| ✅ `cEmailAprovador` no cabeçalho de inclusão e de upsert | O Omie tem **aprovador** de pedido de compra por e-mail 🟡 |
| ✅ `cMkpAtuPv` e `nMkpPerc` por item | Ao receber, o Omie pode **atualizar o preço de venda** do produto. 🟡 Cuidado para não ligar isso sem querer |

## 3. Recebimento de NF-e (`/produtos/recebimentonfe/`): a **NF de entrada** (N16-40 e N16-57)
| O que a documentação mostra | Efeito no projeto |
|---|---|
| 🟡 A documentação lista, por item da NF de entrada, `nIdPedido`, `nIdItPedido`, `nNumPedCompra` e `cNumItPedCompra`. **O Nathan corrige (21/10): na prática a NF de entrada NÃO vem ligada ao item da OC.** Tratar como **não disponível** | **A tarefa do PCP (N16-57) continua inteira:** ligar a NF de entrada ao item do pedido, além do problema de unidade diferente (KG na nota, PC no pedido). Não dá para contar com a ligação automática. O teste 6 só confirma o que o Omie realmente devolve |
| ✅ Por item: `nQtdeNFe`, `cUnidadeNfe`, `nPrecoUnit`, `vFrete`, `vTotalItem`, `nQtdeRecebida` e blocos `itensICMS`, `itensIPI`, `itensPIS`, `itensCOFINS`, `itensICMSST` com **base, alíquota e valor** | **A NF de entrada traz o imposto real** (percentual e valor). Fonte melhor que o imposto do pedido de compra, **e é a que o N16-40 manda usar como custo real** |
| ✅ `infoCadastro.cRecebido`, **`dRec`** (data do recebimento) e `hRec` | **Resolve a pergunta da "data real de recebimento"** que a nota de histórico do score precisa (N16-56). **O hub não sincroniza** esse serviço hoje (não está nos recursos da pipeline): é **recurso novo** a criar |
| ✅ `cCancelada`, `dCanc`, `cDevolvido`, `cDevolvidoParc`, `cItemDevolvido` | Cobre **NF de entrada cancelada ou devolvida**, que estorna a linha de custo (N16-40). ❓ A regra de devolução total e parcial que o Nathan descreveu (21/10) é para **venda**; **como a devolução de compra aparece** no Omie não foi dita |
| ✅ `itensCustoEstoque`: marca se ICMS, PIS, COFINS, IPI, frete, seguro e outras despesas **entram no custo de estoque** | 🟡 O Omie **já decide** quais impostos são custo e quais são crédito. Pode servir de **referência para o custo líquido** (a conferir com a Controladoria) |
| ✅ `lote_validade` por item (número, quantidade, fabricação e validade) | O Omie guarda lote e validade do que entra |

## 4. O que muda nas perguntas abertas

**Correção do Nathan em 21/10/2026:** a NF de entrada **não** vem ligada ao item da OC e a quantidade devolvida **não** dá para ver. Onde a documentação diz o contrário, vale a prática dele.
| Pergunta | Situação depois do estudo |
|---|---|
| **OQ-15** (liberação na criação) | ✅ **Resolvida pela documentação:** usar `codigo_pedido_integracao` e gravar a liberação na **resposta do `IncluirPedido`**. A pipeline passa a gravar esse código no hub |
| **OQ-16** (etapa e campos) | ✅ Etapa `"10"` e a lista de campos acima. ❓ Obrigatórios da conta, **numeração** (`numero_pedido`) e **`bloqueado`**: só teste |
| **OQ-17 / OQ-48** (cancelamento no Omie) | ✅ **Há cancelar por API** (`CancelarPedidoVenda`); o vendedor cancela, edita e exclui (N16-84). O hub guarda o cancelamento por conta própria e confirma pelo `ListarEtapasPedido`. `ExcluirPedido` só para não faturado e **com o risco** do `exclusionSync`; excluir no Hub apaga no Omie, então reutilizar o código de integração é possível |
| **OQ-37** (imposto da OC) | ✅ O imposto **existe por item, em valor** (sem DIFAL) no pedido de compra, e com **percentual e valor** na NF de entrada. Falta **ampliar o espelho** e o **envio** da OC |
| **OQ-39 / N16-57** (vínculo da NF de entrada) | 🟡 A documentação sugere uma ligação automática, mas **o Nathan informa que ela não existe na prática**. O vínculo **NF de entrada → item do pedido continua manual, com o PCP**. Resta decidir como o sistema o guarda (quantidade coberta ou valor total) |
| **OQ-42** (devolução e recusa) | ❌ A quantidade devolvida **não** vem do Omie (correção do Nathan). Falta definir de onde sai a proporção do abatimento: registro no hub, valor da NF de devolução ou NF referenciada. A **recusa** (manifestação) segue dependendo do scraping |
| **OQ-14** (numeração própria) | 🟡 Possível mandar `numero_pedido` ❓ testar |
| **Data real de recebimento** (N16-56) | ✅ Existe (`dRec`), em serviço **ainda não sincronizado** |

## 5. O que a pipeline do hub precisa ganhar (trabalho, não decisão)
1. **Gravar** `codigo_pedido_integracao` do pedido e `codigo_item_integracao` do item.
2. **Novo recurso:** recebimento de NF-e (`ListarRecebimentos` e `ConsultarRecebimento`), com `dRec`, itens, imposto real, cancelada e devolvida.
3. **Ampliar** o espelho do pedido de compra com os valores de imposto e `cNumPedido`.
4. **Ampliar** o envio da OC (`UpsertPedCompra`) para mandar os impostos que Compras editar.
5. **Devolução:** capturar `cCancelado`, `cDevolvido`, `cDevParcial` e os dados de cancelamento da NF no `ListarNF`; a **quantidade devolvida precisa de outra fonte** (registro no hub, valor da NF de devolução ou NF referenciada).
6. **Novo envio:** `IncluirPedido` por fila, no padrão de `envioOrdensCompra.ts` (com `AlterarPedidoVenda` se o `bloqueado` exigir).
7. **Ajustar o `exclusionSync`** para não apagar do hub o pedido que o sistema cancelou por conta própria.

## 6. Testes que só o Omie responde (checklist)
Todos no Omie de verdade, com **cadastros TESTE** e conferindo que nada vá a cliente, fornecedor ou financeiro reais.
1. `IncluirPedido` mínimo: quais campos o Omie **exige** em cada filial.
2. O Omie aceita o **nosso `numero_pedido`** e o mantém?
3. O pedido criado por API nasce **bloqueado** na tela? O que o Fiscal consegue fazer com ele?
4. `ExcluirPedido` num pedido **sem NF**: o que acontece no `ListarPedidos` seguinte e com o `exclusionSync`?
5. Cancelamento pela API: chamar `CancelarPedidoVenda` num pedido de teste não faturado e conferir que o `ListarEtapasPedido` traz `cCancelado = S`; comparar com `ExcluirPedido`.
6. `ConsultarRecebimento` de uma NF real de entrada: `nIdPedido` e `nIdItPedido` preenchidos? E quando a NF vem **sem** pedido de compra?
7. `ListarNF` de uma NF com **devolução parcial**: `nItemQtdDevolvida` preenchido?
8. `UpsertPedCompra` com `nValorIcms` e `nValorIpi`: o Omie grava e devolve nas consultas?

Ver também: [[Perguntas-Proposta-Pedido-Comissao]], [[Registro-de-Decisoes]], a proposta de cronograma (`Proposta-Orcamento-Comissao/07-Cronograma/Proposta-de-Cronograma.md`, fora do vault, a validar).
