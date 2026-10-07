---
tags: [integracao-omie, plano-execucao]
criado: 2026-09-17
atualizado: 2026-10-07
---

# Roteiro de Implementação — passo a passo com endpoint, método e campo exatos

> Status: decidido (Passos 1, 2, 3, 6, 7, 8, 9, 15) | no código (`master` d2886bf, 06/10) | em produção (verificado em 07/10/2026 só pelo dump). Decisões em [[Registro-de-Decisoes-2026-10-07]].
>
> **Decisões de 07/10 sobre os passos (✅):** Passo 1 parcial (endereço de entrega e dados bancários ficam fora); Passo 2 **cancelado**; Passo 3 `lead_time` **sai do pipeline** (cadastro no MES); Passo 6 **continua** (B6, Gustavo); Passos 7 e 8 vão para o **Ciclo 2 (04/01/2027)**; Passo 9 **feito e populando em produção**; Passo 15 o **Omie segue como financeiro**, sem plano de desligar.
>
> **Atualização de 07/10/2026 — estado de cada passo conferido contra o código do pipeline (`master` d2886bf, 06/10; leitura de código, não produção).**
>
> | Passo | Estado no código |
> |---|---|
> | 1 Parceiros fiscais | **parcial** — dados fiscais gravados; `parceiros_endereco_entrega` e `parceiros_dados_bancarios` **não** (confirmado no `mapRow`) |
> | 2 Saldo de estoque | **não implementado** — `estoque.ts` segue `enabled:false`, `table:null` |
> | 3 `lead_time` | **não implementado** |
> | 4 Frete/parcelas/desconto do PV | **não implementado** (contrato 003 aplicado, pipeline não grava) |
> | 5 Pedidos de compra | **implementado** (`pedidosCompras`, espelho + envio de OC) |
> | 6 Locais de estoque | **não implementado** (sem recurso) |
> | 7 Remessa de produtos | não implementado (a ficha não destaca; segue aberto) |
> | 8 Valor de devolução | **não implementado** |
> | 9 Etapas de faturamento | **implementado** (`enabled:true` no código; populada em produção, ✅ 07/10) |
>
> Os blocos de cada passo abaixo foram anotados com "(atualizado em 07/10)". O texto original foi mantido como histórico do plano.

Este é o resumo acionável de todo o levantamento (seções 1 a 4). Cada passo tem o suficiente para um dev abrir e implementar sem precisar cruzar outras notas — endpoint, método RPC, campos exatos e coluna de destino. Onde o detalhe for grande demais para caber aqui, o passo aponta para a nota de origem com a tabela completa.

Convenção: 🟢 extrair do Omie · 🔵 construir nativo no Estoque/MES · 🔴 decisão de arquitetura antes de codificar.

**Contratos de banco**: todo passo 🟢 que precisa de tabela/coluna nova tem um contrato de migração correspondente na seção [[Indice-Contratos|de contratos]] (pasta `09-Contratos/01-Contratos-SQL-DBA/`, mesmo formato do contrato já usado para `etapas_faturamento`), pronto para o Gustavo (DBA) revisar e aplicar — todos têm pelo menos uma pergunta em aberto documentada no próprio arquivo. Os passos apontam o nome exato do contrato. **(Atualizado em 07/10: "nenhum aplicado ainda" ficou defasado — pela auditoria, `core.estoque_saldo` e `core.locais_estoque` já existem no banco (contratos 002 e 005) e o contrato 003 foi aplicado; o contrato de valor de devolução (006/011) foi invalidado. Status exato por contrato: ver [[Indice-Contratos]].)**

---

## Fase 1 — Baixo esforço, alto risco se não for feito antes do desligamento

### Passo 1 🟢 — Estender `core.parceiros` com dados fiscais

> **Decisão de 07/10 (✅, #30):** fica **parcial**. `enderecoEntrega` e `dadosBancarios` ficam **fora** do escopo; as tabelas existem e estão vazias.
>
> **Estado (atualizado em 07/10): PARCIAL.** Gravados em `core.parceiros` (66f9a2e): IE, IM, Suframa, Simples, `contribuinte_icms`, CNAE, `tipo_atividade`, `pessoa_fisica`, `produtor_rural`, `cidade_ibge`, `valor_limite_credito`, `bloquear_faturamento`, `inativo`; IE/dados fiscais já alimentam a IE do PDF da OC (contrato 30). **Não gravados**: `enderecoEntrega` (`parceiros_endereco_entrega`) e `dadosBancarios` (`parceiros_dados_bancarios`) — as tabelas existem, mas o `mapRow` não escreve nelas.

**Endpoint**: `https://app.omie.com.br/api/v1/geral/clientes/`
**Método**: `ListarClientes` (já é o método que o pipeline usa hoje para popular `core.parceiros`)
**Tipo de retorno**: `clientes_listfull_response` → array de `clientes_cadastro`

Campos a adicionar ao mapeamento (`parceiros.ts`), todos já vêm no mesmo payload que já é consumido hoje:

| Campo Omie | Tipo | Nova coluna sugerida |
|---|---|---|
| `inscricao_estadual` | string20 | `inscricao_estadual` |
| `inscricao_municipal` | string20 | `inscricao_municipal` |
| `inscricao_suframa` | string20 | `inscricao_suframa` |
| `optante_simples_nacional` | string1 (S/N) | `optante_simples_nacional` (bool) |
| `contribuinte` | string1 (S/N) | `contribuinte_icms` (bool) |
| `cnae` | string7 | `cnae` |
| `tipo_atividade` | string1 | `tipo_atividade` |
| `pessoa_fisica` | string1 (S/N) | `pessoa_fisica` (bool) |
| `produtor_rural` | string1 (S/N) | `produtor_rural` (bool) |
| `cidade_ibge` | string7 | `cidade_ibge` |
| `valor_limite_credito` | decimal | `valor_limite_credito` |
| `bloquear_faturamento` | string1 (S/N) | `bloquear_faturamento` (bool) |
| `inativo` | string1 (S/N) | `inativo` (bool) |
| `enderecoEntrega` (objeto) | — | tabela nova `parceiros_endereco_entrega` (razao_social, cnpj_cpf, endereço completo, IE do recebedor) |
| `dadosBancarios` (objeto) | — | tabela nova `parceiros_dados_bancarios` (banco, agência, conta, titular, chave PIX) |

**Não precisa de nova chamada de API** — é o mesmo `ListarClientes` já em produção, só amplia o mapeamento de campos. **Contrato de banco**: [[001-Parceiros-Dados-Fiscais]]. Ver [[Cadastros-Gerais-Lacunas]].

---

### Passo 2 🟢 — ~~Habilitar saldo de estoque~~ (cancelado)

> **Cancelado (✅, 07/10, #28):** o Omie recebe dados só manualmente e o estoque do Omie é ignorado; `ListarPosEstoque` **não será feito**. O MES é a referência do saldo físico. O texto abaixo é histórico.

> **Estado (atualizado em 07/10): NÃO IMPLEMENTADO no pipeline.** A tabela de destino já existe no banco (`core.estoque_saldo`, contrato 002), mas `estoque.ts` continua `enabled:false` e `table:null` (comentário no arquivo: "sem tabela de destino" — defasado em relação ao banco). Falta apontar o recurso para a tabela e ligar.

**Endpoint**: `https://app.omie.com.br/api/v1/estoque/consulta/`
**Método**: `ListarPosEstoque` (listagem em massa) ou `PosicaoEstoque` (consulta pontual por produto/local)
**Tipo de retorno**: `posicaoestoque_response` (pontual) / array `produtos` (listagem)

Campos exatos retornados:

| Campo | Tipo | Descrição |
|---|---|---|
| `saldo` | decimal | Saldo de estoque |
| `cmc` | decimal | Custo Médio Contábil |
| `pendente` | decimal | Saldo pendente em pedidos de venda abertos |
| `estoque_minimo` | decimal | Estoque mínimo (produto × local) |
| `reservado` | decimal | Quantidade reservada |
| `fisico` | decimal | Quantidade física |
| `codigo_local_estoque` | integer | Local de estoque |
| `nPrecoUnitario` | decimal | Preço unitário (só na listagem) |

**Bloqueio atual**: código do resource já existe (`estoque.ts`, `enabled: false`) — falta só (a) o DBA criar a tabela de destino, (b) trocar `enabled: true`. **Destino sugerido**: `core.estoque_saldo`, chave `(codigo_empresa, codigo_produto_omie, codigo_local_estoque)`. **Contrato de banco**: [[002-Estoque-Saldo]] (tem uma decisão de design em aberto — foto atual vs. série histórica — resolver antes de aplicar). Ver [[Compras-Estoque-Producao-Lacunas]].

---

### Passo 3 🟢 — ~~Extrair `lead_time` do produto~~ (sai do pipeline)

> **Decisão de 07/10 (✅, #29):** `lead_time` **sai do pipeline**; o cadastro fica no MES. O texto abaixo é histórico.

> **Estado (atualizado em 07/10): NÃO IMPLEMENTADO.**

**Endpoint**: `https://app.omie.com.br/api/v1/geral/produtos/`
**Método**: `ListarProdutos` (mesmo método já usado por `produtos.ts`)
**Campo**: `lead_time` (integer, dias) — adicionar à coluna `especificacoes` (jsonb) já existente em `core.produtos`, junto com `peso_bruto`/`peso_liq`/`marca`/`modelo`.

Mesma chamada já em produção, só mais um campo no objeto mapeado. Ver [[Compras-Estoque-Producao-Lacunas]].

---

### Passo 4 🟢 — Extrair frete e parcelas do Pedido de Venda

> **Estado (atualizado em 07/10): NÃO IMPLEMENTADO no pipeline.** O contrato 003 já foi aplicado no banco, mas o pipeline não grava frete, parcelas nem desconto do pedido de venda.

**Endpoint**: `https://app.omie.com.br/api/v1/produtos/pedido/`
**Método**: `ListarPedidos` (mesmo método já usado por `pedidosVendas.ts`)

| Bloco/campo | Descrição | Destino sugerido |
|---|---|---|
| `frete.transportadora`, `.modalidade_frete`, `.peso_bruto`, `.valor_frete`, `.valor_seguro`, `.codigo_rastreio` | Dados de frete do pedido | Tabela nova `pedidos_vendas_frete` (1:1 com `pedidos_vendas`) |
| `lista_parcelas[]` (data, valor, forma) | Condição de pagamento detalhada | Tabela nova `pedidos_vendas_parcelas` (1:N) |
| `tipo_desconto_pedido`, `perc_desconto_pedido`, `valor_desconto_pedido` | Desconto no nível do pedido (hoje só por item) | Novas colunas em `pedidos_vendas` |

**Contrato de banco**: [[003-Pedidos-Vendas-Frete-Parcelas]]. Ver [[Vendas-NFe-Lacunas]].

---

## Fase 2 — Histórico real que vale migrar, esforço médio

### Passo 5 🟢 — Extrair Pedidos de Compra (histórico)

> **Estado (atualizado em 07/10): IMPLEMENTADO** (leitura de código; produção não verificada). O recurso `pedidosCompras` existe (`PesquisarPedCompra` com `lApenasAlterados=T` desde c7aba1b; camadas hoje/mês/últimos meses/full, full = 365 dias) e grava `pedidos_compras` + `_itens` + `_parcelas` — itens e parcelas em REPLACE-ALL por pedido (ae919fd), só colunas existentes (229a419). O envio de OC (`UpsertPedCompra`/`ExcluirPedCompra`) também está implementado, como única escrita no Omie. Ver [[23-Compras-Pipeline-Consolidado]] e [[Omie-ELT-Pipeline]]. O trecho "novo resource sugerido" abaixo é histórico.

**Endpoint**: `https://app.omie.com.br/api/v1/produtos/pedidocompra/`
**Método de leitura**: `PesquisarPedCompra` (paginada por `nPagina`/`nRegsPorPagina`, janela `dDataInicial`/`dDataFinal`; **não existe filtro por etapa**: a situação se escolhe por 7 flags `lExibirPedidos*` — pendentes, faturados, recebidos, cancelados, encerrados, recebidos parcialmente, faturados parcialmente — e para o espelho vão todas em `T`) ou `ConsultarPedCompra` (por `nCodPed`, `cCodIntPed` ou `cNumero`). A pesquisa já traz cada pedido completo, então não precisa de um `ConsultarPedCompra` por pedido.
**Método de escrita (confirmado existir)**: `IncluirPedCompra`/`AlteraPedCompra`/`UpsertPedCompra`. Já tem uso: é por ele que a OC do av-hub vai para o Omie (ver [[14-Compras-Omie-Pedido-Compra]], §3).

Estrutura principal a mapear (corrigida contra a doc oficial em 23/09/2026):
- **cabecalho_consulta**: `nCodPed`, `cCodIntPed`, `cNumero` (número no Omie; `cNumPedido` é o número **para o fornecedor**), `dIncData`/`cIncHora`, `dDtPrevisao`, `cCodParc`/`nQtdeParc`, `nCodFor` (fornecedor), `nCodCompr` (comprador), `cCodCateg`, `cEtapa` (código de 2 caracteres; a doc não lista os valores)
- **frete_consulta**: `nCodTransp` (código da transportadora), `cTpFrete`, peso, valor frete/seguro/outras
- **produtos_consulta[]** (itens): `cCodIntItem`, `nCodItem`, `nCodProd`, `cDescricao`, `cUnidade`, quantidade, valor unitário, `nDesconto` (**valor** em R$), `nValTot`, `nQtdeRec` (quantidade já recebida), ICMS/IPI/PIS/COFINS por item, `codigo_local_estoque`
- **parcelas_consulta[]**: `nParcela`, `dVencto`, `nValor`, `nDias`, `nPercent`

**Novo resource sugerido**: `pedidosCompras.ts`, tabela `core_vendas_faturamento.pedidos_compras` + `pedidos_compras_itens` (já aplicadas), chave `(codigo_empresa, codigo_pedido_compra_omie)`. **Contrato de banco**: [[004-Pedidos-Compras]] (identidade do item resolvida: `(id_pedido_compra, ordem)`). **Antes de ligar**, aplicar o `ALTER` de [[16-Compras-Pedido-DBA-Banco]] (D5): as colunas `INTEGER` estouram com os códigos reais do Omie. Detalhe do recurso em [[19-Compras-Pedido-Pipeline-Omie]] (P1). Ver [[Compras-Estoque-Producao-Lacunas]].

---

### Passo 6 🟢 — Extrair Locais de Estoque (carga inicial)

> **Decisão de 07/10 (✅, #29):** o Passo 6 **continua** (B6, responsável Gustavo), só com os locais.
>
> **Estado (atualizado em 07/10): NÃO IMPLEMENTADO.** A tabela `core.locais_estoque` existe (contrato 005), mas não há recurso do pipeline para `ListarLocalEstoque`.

**Endpoint**: `https://app.omie.com.br/api/v1/estoque/local/`
**Método**: `ListarLocalEstoque`

| Campo | Tipo | Descrição |
|---|---|---|
| `codigo_local_estoque` | integer | ID (PK) |
| `codigo` | string50 | Código |
| `descricao` | string250 | Nome do local |
| `tipo` | string1 | Tipo |
| `padrao` | string1 (S/N) | É local padrão |
| `inativo` | string1 (S/N) | Inativo |
| `dispOrdemProducao`, `dispConsumoOP`, `dispRemessa`, `dispVenda` | string1 (S/N) | Disponibilidade por finalidade |
| `consiSugeCompra` | string1 (S/N) | Considerado em sugestão de compra |

Cadastro pequeno (poucos registros) — migrar como carga inicial única, não precisa de sync recorrente. Destino: `core.locais_estoque`. **Contrato de banco**: [[005-Locais-Estoque]].

---

### Passo 7 🟢 — Extrair Remessa de Produtos

> **Decisão de 07/10 (✅, #27):** remessa de produtos fica no **Ciclo 2 (começa em 04/01/2027)**.
>
> **Estado (atualizado em 07/10): aberto** — a auditoria lista remessa de produtos entre as lacunas ainda abertas; nenhum recurso no pipeline.

**Endpoint**: `https://app.omie.com.br/api/v1/produtos/remessa/`
**Método**: `IncluirRemessa`/`ConsultarRemessa` para leitura pontual — **não há método `Listar*` de listagem em massa**, então a extração precisa ser feita cruzando com os pedidos/NFs já conhecidos, ou via `ListarNFeTransp` se aplicável.

Campos principais: `cabec` (`nCodRem`, `nCodCli`, `dPrevisao`, `nCodVend`, `cNumeroRemessa`, `cCancelado`), `frete`, `itens[]` (`nIdProd`, `nQuant`, impostos completos ICMS/IPI/PIS/COFINS), `ListaNfe` (NF de remessa gerada). Ver [[Vendas-NFe-Lacunas]] para o campo a campo completo.

**Ação antes de codificar**: confirmar com o time se a Aços Vital de fato usa Remessa de Produtos (beneficiamento/corte para terceiros) — se o volume for baixo, este passo pode ser adiado.

---

### Passo 8 🟢 — Job dedicado: valor de devolução parcial

> **Decisão de 07/10 (✅ #27; 🟡 #31):** a devolução vai para o **Ciclo 2 (04/01/2027)**. O `StatusDevolucaoVenda` não está disponível no Omie; devolução é nativa do Estoque (DEC-10). As colunas `valor_devolucao` em produção estão vazias (limpeza: Gustavo). O desenho abaixo (job com `StatusDevolucaoVenda`) está **superado**.
>
> **Estado (atualizado em 07/10): NÃO IMPLEMENTADO.** O contrato de `valor_devolucao` (006/011) foi invalidado; `valor_devolucao` segue aberto.

**Endpoint**: `https://app.omie.com.br/api/v1/produtos/devolucaovendafaturamento/`
**Método**: `StatusDevolucaoVenda(nCodDevol)` — **chamada individual, não em massa**

Campos retornados: `nCodDevol`, `cNumPed`, `cEtapa`, `cCancelada`, `cFaturada`, **`vTotal`** (valor).

**Implementação sugerida**: job separado do sync padrão — para cada `pedidos_vendas` com `devolucao_parcial = true`, capturar o `nCodDevol` (via `nfconsultar.pedido.nIdPedDev`, já mapeável) e chamar `StatusDevolucaoVenda` para preencher uma nova coluna `pedidos_vendas.valor_devolucao`. **Validar em ambiente de teste** se `vTotal` é o valor da devolução parcial ou o valor total do pedido devolvido antes de confiar no dado. **Contrato de banco**: [[006-Pedidos-Vendas-Valor-Devolucao]] (tem essa mesma validação marcada como pergunta crítica em aberto). Ver [[Vendas-NFe-Lacunas]].

---

### Passo 9 🟢 — Confirmar sync de Etapas de Faturamento em produção

> **Decisão de 07/10 (✅, #5): feito.** `core.etapas_faturamento` está **populada em produção**.
>
> **Estado (atualizado em 07/10): IMPLEMENTADO no código** — `etapasFaturamento` com `enabled:true` desde f753982, nas 4 camadas, destino `core.etapas_faturamento`. ~~A parte "confirmar em produção" continua sem verificação.~~ (superado: confirmada pelo registro de 07/10.)

**Endpoint**: `https://app.omie.com.br/api/v1/produtos/etapafat/`
**Método**: `ListarEtapasFaturamento`

A tabela `core.etapas_faturamento` **já existe** (criada pelo DBA, confirmado — ver `sql/dba_migrations/005_etapas_faturamento_contrato.md`, status atualizado) e o código de extração já está pronto (`etapasFaturamento.ts`). **Ação**: confirmar que o job está de fato habilitado e rodando em produção (não só que a tabela existe) — se sim, ligar ao "dicionário de nomes de etapa" pendente do Portal do Vendedor via `notas_fiscais.oppedido` → `codigo_operacao`. Ver [[Etapas-Faturamento]].

---

## Fase 3 — Nascer nativo no Estoque/MES (não é para extrair do Omie)

### Passo 10 🔵 — Estoque máximo, ponto de pedido, tolerância de peso

**Confirmado que não existe em nenhum endpoint da API do Omie** (verificado em Produtos, Locais de Estoque, Produto x Fornecedor, Ajuste de Estoque, Consulta de Estoque, Resumo do Estoque). Implementar como colunas nativas do módulo de Estoque:
- `material.estoque_maximo` (decimal, por produto × local)
- `material.ponto_pedido` (decimal, por produto × local)
- `material.tolerancia_peso_percentual` (decimal, já citado como "default provisório 5%" no PRD)

Não depende de nenhuma chamada de API — é modelagem pura do lado do Estoque.

### Passo 11 🔵 — Workflow de quarentena/qualidade de lote

Omie (`produtos/produtoslote/`, método `ListarLotes`) só retorna quantidade/data/saldo — **sem campo de status de qualidade**. O workflow completo (`status_qualidade`, `laudo_url`, RNC) precisa ser modelagem nativa do Estoque, já em desenho no PRD ([[Estoque-Modelo-Dados]]).

### Passo 12 🔵 — BOM/roteiro de produção rico

Omie (`geral/malha/`, método `ListarMalha`) modela estrutura de produto simples (componente + quantidade + % perda), sem centro de trabalho/tempo padrão/sequência de operação. Roteiro real de produção nasce nativo no MES; migrar só a BOM já cadastrada no Omie como carga inicial, se existir volume relevante.

### Passo 13 🔵 — Requisição de compra / sugestão automática de compra

Omie tem Requisição de Compra (`produtos/requisicaocompra/`) como estágio manual anterior ao Pedido de Compra, sem lógica de "quando comprar". Essa lógica (baseada em estoque mínimo/ponto de pedido do Passo 10) precisa nascer nativa no Estoque.

### Passo 14 🔵 — Tabela de Preços

Omie tem cadastro completo (`produtos/tabelaprecos/`, método `ListarTabelaPreco`), mas como impacta margem diretamente, recomenda-se nativizar como configuração comercial do sistema novo em vez de depender do Omie continuamente.

---

## Fase 4 — Decisão de arquitetura antes de qualquer código

### Passo 15 🔴 — Módulo financeiro

> **Decidido (✅, 07/10, #30; DEC-11):** o **Omie segue como sistema financeiro e fiscal**, sem plano de desligar. Não há módulo financeiro nativo a construir nem integração de `contapagar`/`contareceber`/`extrato` a decidir. O texto abaixo é histórico.

Antes de escrever qualquer integração com `financas/contapagar/`, `financas/contareceber/` ou `financas/extrato/`, é preciso decidir **se e onde** um módulo financeiro nativo vai existir no ERP novo — sem isso, não há destino de dado para esses endpoints. Ver [[Financas-Lacunas]] para os campos completos e os vínculos (`nCodOS`/`nCodPedido`) que esse módulo precisaria implementar quando a decisão for tomada.

---

## Ordem recomendada de execução

```
Fase 1 (baixo esforço, alto risco se atrasar)
  1. Parceiros — dados fiscais
  2. Saldo de estoque (habilitar endpoint já pronto)
  3. lead_time do produto
  4. Frete/parcelas do pedido

Fase 2 (histórico real, esforço médio)
  5. Pedidos de Compra
  6. Locais de Estoque
  7. Remessa de Produtos (confirmar volume antes)
  8. Valor de devolução parcial (job dedicado)
  9. Confirmar Etapas de Faturamento em produção

Fase 3 (nativo, em paralelo com o desenho do Estoque/MES)
  10. Estoque máximo/ponto de pedido/tolerância
  11. Quarentena/qualidade de lote
  12. BOM/roteiro de produção
  13. Requisição/sugestão de compra
  14. Tabela de preços

Fase 4 (bloqueia decisão, não código)
  15. Módulo financeiro — subir para quem decide o roadmap
```

## Ver também
- [[Sintese-Migrar-vs-Nascer-Nativo]] (a matriz de decisão completa, por domínio)
- [[Cadastros-Gerais-Lacunas]], [[Compras-Estoque-Producao-Lacunas]], [[Vendas-NFe-Lacunas]], [[Financas-Lacunas]]
