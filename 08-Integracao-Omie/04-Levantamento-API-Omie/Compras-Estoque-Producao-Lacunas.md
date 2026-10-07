---
tags: [integracao-omie, levantamento-api, lacunas]
criado: 2026-09-17
atualizado: 2026-10-07
---

# Compras, Estoque e Produção — o domínio mais crítico

> Status: decidido (saldo de estoque do Omie descartado) | no código (`master` d2886bf) | em produção (verificado em 07/10/2026 só pelo dump, [[Auditoria-Dump-Producao-2026-10-07]]). Decisões em [[Registro-de-Decisoes-2026-10-07]].

> **Decisão de 07/10 (✅, #28): a parte de estoque (saldo) está descartada.** O Omie recebe dados só manualmente e o estoque do Omie é ignorado; `ListarPosEstoque` não será feito e o MES é a referência do saldo físico. As seções (c) e de Locais abaixo ficam como histórico do levantamento (locais continuam: Passo 6, B6).

> **Atualização de 07/10/2026 — o levantamento abaixo (17/09, com acréscimos de 23/09) foi parcialmente executado no pipeline.** Conferido contra o código (`master` d2886bf; leitura de código, não produção): **pedidos de compra** (espelho por `PesquisarPedCompra` + envio por `UpsertPedCompra`/`ExcluirPedCompra`), **compradores** (`ListarCompradores`, vínculo manual) e os catálogos de Compras (condições de pagamento, projetos, categorias, contas correntes) **já são recursos do pipeline**; o saldo de estoque (`ListarPosEstoque`), locais de estoque, `lead_time`, lote, BOM e requisições **não**. Os trechos "Não extraído" dessas entidades foram anotados abaixo. Ver [[Arquitetura-do-Pipeline]].

Este é o domínio direto do PRD de Estoque/MES. Levantamento feito na documentação interativa da API do Omie, endpoint a endpoint.

## Resposta às 3 perguntas que estavam em aberto

### (a) O Omie tem API de criação de Ordem/Pedido de Compra? — **SIM, confirmado**

`produtos/pedidocompra/` tem CRUD completo: `IncluirPedCompra`, `AlteraPedCompra`, `ExcluirPedCompra`, `UpsertPedCompra`, mais `ConsultarPedCompra` e `PesquisarPedCompra`. A pesquisa **não filtra por etapa**: a situação se escolhe por 7 flags `lExibirPedidos*` (pendentes, faturados, recebidos, cancelados, encerrados, recebidos parcialmente, faturados parcialmente) — corrigido em 23/09/2026 contra a doc oficial. Inclui aprovação por e-mail (`cEmailAprovador`, que já grava o pedido como aprovado dentro do Omie), rateio por departamento, parcelamento e frete. **Isso resolve a pergunta 4 de [[Perguntas-em-Aberto]] — atualizar aquela nota.**

### (b) Existem campos de estoque mínimo/máximo/ponto de pedido/tolerância de peso? — **Parcial**

**Existe estoque mínimo**, sempre por **produto × local de estoque** — não é um campo do cadastro de produto (esse é `DEPRECATED`), vive em `estoque/ajuste/` via método dedicado `AlterarEstoqueMinimo` (`quan_min`), e aparece pronto em `estoque/consulta/` (`estoque_minimo`) e `estoque/resumo/` (`nEstoqueMinimo`).

**Não existe em lugar nenhum** (verificado em Produtos, Locais de Estoque, Produto x Fornecedor, Ajuste, Consulta, Resumo): **estoque máximo**, **ponto de pedido/ressuprimento automático** (só um flag genérico `consiSugeCompra` no Local, sem parâmetro nenhum) e **tolerância de peso**. Esses três precisam nascer nativos no Estoque/MES.

### (c) Quais campos a Consulta de Estoque (saldo) retorna? — **descartado em 07/10 (não será sincronizado)**

`estoque/consulta/` → `PosicaoEstoque`/`ListarPosEstoque`: `saldo`, `cmc` (custo médio contábil), `pendente` (em pedidos de venda abertos), `estoque_minimo`, `reservado`, `fisico`, `codigo_local_estoque`, `nPrecoUnitario`. `estoque/resumo/` complementa com `nDisponivel` (calculado), `nPrevisaoEntrada`/`nPrevisaoSaida`, e um dado novo interessante: **`nPrecoUltComp`/`dDtUltComp`** (preço e data da última compra, por local).

Isso é exatamente o formato de dado que faltava para o endpoint de saldo hoje desabilitado no pipeline (ver [[Arquitetura-do-Pipeline]]). **(Atualizado em 07/10: segue desabilitado — `enabled:false`, `table:null` —, embora `core.estoque_saldo`/`core.locais_estoque` já existam no banco, contratos 002 e 005. Decidido: continua desabilitado, não será habilitado.)**

## Entidade por entidade

### Produtos — campos extras não extraídos
`lead_time` (dias de ressuprimento médio — relevante! **atualizado em 07/10: segue não extraído e, por decisão (✅ #29), sai do pipeline: cadastro no MES**), características, kit, imagens, tabelas de preço, bloco fiscal completo (CFOP/CST/alíquotas), `dias_garantia`/`dias_crossdocking`. O cadastro mestre (código, descrição, NCM, peso) deve continuar vindo do Omie enquanto ele for o emissor fiscal; `lead_time` e estoque mínimo real devem nascer nativos no Estoque/MES.

### Produtos - Características
Key-value livre (`cNomeCaract`/`cConteudo`), com flags de exibir em NF/pedido/ordem de produção. Não extraído. Candidato a especificação técnica de aço (bitola, liga, têmpera) — mas recomendação é nascer nativo como atributos estruturados (com validação/unidade), não copiar o modelo livre do Omie.

### Produtos - Estrutura (BOM/ficha técnica)
Tem `percPerdaProdMalha` (**% de perda** — direto relevante para corte de chapa/flange) e custo de produção (mão de obra direta, gastos gerais). Não extraído. Como o roteiro de produção real da Aços Vital deve ser mais rico que esse modelo genérico do Omie, recomenda-se nascer nativo no MES, migrando só dados históricos de estrutura já cadastrada como carga inicial.

### Produtos - Kit / Produtos - Variação
Baixa relevância para o negócio de aço (mais usado em varejo). Avaliar uso real antes de decidir.

### Produtos - Lote
Só leitura (`ConsultarLote`/`ListarLotes`) — datas, quantidades, saldo. **Sem campo de status de qualidade/quarentena.** Confirma que o workflow de quarentena/qualidade que o Estoque/MES precisa é uma exigência nova que o Omie não modela — precisa nascer nativo, sem depender de migrar do Omie.

### Requisições de Compra
Estágio anterior ao Pedido de Compra (sugestão interna). Não extraído. Como o Estoque vai controlar ponto de pedido nativamente, esse fluxo inteiro (a lógica de "quando comprar", que o Omie não modela de forma robusta) deve nascer nativo.

Conferido na doc em 23/09/2026: `produtos/requisicaocompra/` (`IncluirReq`, `AlterarReq`, `UpsertReq`, `ConsultarReq`, `PesquisarReq`, `ExcluirReq`) só guarda categoria, projeto, data sugerida, observações e itens (produto, quantidade, preço sugerido). **Não tem status, fornecedor nem aprovação**, e o pedido de compra do Omie **não tem campo que aponte para a requisição**. A requisição do av-hub ([[008-Requisicoes-Compra]]) segue nativa e não é enviada ao Omie; o número dela vai como texto no `cObsInt` da OC ([[14-Compras-Omie-Pedido-Compra]], §3.8).

### Pedidos de Compra
CRUD completo confirmado (ver pergunta a acima). Estrutura rica: cabeçalho, frete, itens com impostos, parcelas, departamentos, `cEtapa` (código de 2 caracteres; **a doc não lista os valores** — pendente/faturado/recebido/cancelado/encerrado/parcial são os nomes das flags da pesquisa, não os códigos do campo). **Em produção (dump de 07/10) só aparecem as etapas 10, 15 e 20, com 1.186, 20.380 e 1.242 pedidos; os nomes oficiais seguem 🔴 Nathan (olhar um pedido de cada etapa no Omie; [[Registro-de-Decisoes-2026-10-07]] #52).** ~~Não extraído hoje.~~ **Extraído (atualizado em 07/10):** recurso `pedidosCompras` (`PesquisarPedCompra`, `lApenasAlterados=T`) → `pedidos_compras` + `_itens` + `_parcelas`, itens e parcelas em REPLACE-ALL por pedido; e a OC do av-hub é enviada por `UpsertPedCompra`/`ExcluirPedCompra` (única escrita do pipeline no Omie, sem parcelas — só `cCodParc`/`nQtdeParc`). Exclusão de pedido apagado no Omie por fora da OC não é detectada. **Recomendação**: migrar histórico de pedidos já feitos (para rastreabilidade de fornecedor), mas o fluxo de criação de novos pedidos deve nascer nativo no Estoque/MES assim que ele virar sistema de registro — exportando para o Omie via API só enquanto ele continuar ativo para fins fiscais/financeiros.

**Atualização de 23/09/2026:** a OC já nasce no av-hub ([[007-Ordens-Compra-Estruturada]], aplicado) e vai para o Omie por `UpsertPedCompra`. De-para campo a campo, conferido contra a doc oficial, em [[14-Compras-Omie-Pedido-Compra]]. Pontos da doc que pesam nesse envio:
- o Omie **não tem campo de moeda**: valores vão convertidos para R$;
- `nDesconto` do item é **valor**, não percentual;
- `cObs` do cabeçalho não sai impresso para o fornecedor, `cObsInt` é só para quem consulta, e o `cObs` do item é o único que sai impresso;
- a resposta do envio só devolve `nCodPed`/`cNumero`, nenhum código de item. A ligação item a item volta pelo `cCodIntItem` no espelho.

### Ordens de Produção
Modela "produto + quantidade + BOM explodida com reserva de item", mas **sem conceito de roteiro/etapas de operação** (centro de trabalho, tempo padrão, sequência) — mais raso que um MES real. Não extraído. Recomenda-se nascer nativo (roteiro real com apontamento por etapa), não migrar esse modelo simplificado.

### Nota de Entrada / Nota de Entrada - Faturamento
Documento fiscal de entrada (emite NF-e). Deve continuar vindo do Omie (ou de outro emissor fiscal) enquanto existir — não faz sentido reconstruir emissão fiscal no MES.

### Recebimento de Nota Fiscal
O endpoint mais alinhado ao que o PRD de Recebimento precisa: `nQtdeRecebida` (quantidade fisicamente conferida, pode divergir do pedido), link direto ao pedido de compra (`nIdPedido`/`nIdItPedido`), lote na entrada, local de estoque de destino, flags de ciclo completo (recebido/faturado/devolvido/autorizado/bloqueado/cancelado com data/hora/usuário por transição). Não extraído. **Recomendação**: a lógica de negócio (conferência, divergência, quarentena) nasce nativa no MES, mas os campos fiscais (chave NF-e, itens fiscais) devem vir do Omie/futuro emissor via integração, não ser reconstruídos.

### Famílias / Unidades
Já batem com o que é extraído (famílias) ou são tabelas pequenas e estáticas de baixo risco (unidades).

### Compradores
Só leitura, **sem endpoint de criação**. Se esse processo migrar para o MES, o cadastro de compradores precisa nascer nativo — não dá para manter só no Omie sem forma de criar via API. **(Atualizado em 07/10: o pipeline já lê — recurso `compradores` (`ListarCompradores`) → `core_vendas_faturamento.compradores`, `ativo` = `cInativo !== 'S'`, com colunas protegidas `id_funcionario`, `nome_exibicao`, `ativo_desde`, `inativo_desde` para o vínculo manual; sem comprador vinculado, a OC nem é enviada ao Omie.)**

### Produto x Fornecedor
Só um de-para de código de produto por fornecedor — sem preço, prazo de entrega ou quantidade mínima. Não resolve a pergunta (b) sozinho.

### Locais de Estoque
Cadastro pequeno e estrutural (galpões/depósitos), com flags de disponibilidade por finalidade (produção/remessa/venda) e `consiSugeCompra`. Sem mínimo/máximo no local em si. Bom candidato a migrar histórico (poucos registros), mas as regras de disponibilidade podem ser repensadas nativamente. **(Atualizado em 07/10: ainda sem recurso no pipeline; a tabela `core.locais_estoque` existe, contrato 005. Decidido (✅ #29): continua, só com os locais, B6/Passo 6, Gustavo.)**

### Movimento de Estoque
Só leitura, movimentos agregados por dia — reconstituível a partir dos movimentos individuais de Consulta de Estoque.

## Ver também
- [[Sintese-Migrar-vs-Nascer-Nativo]]
- [[Perguntas-em-Aberto]]
- [[Produtos-e-Familias]] (extração atual)
