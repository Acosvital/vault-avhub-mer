---
tags: [integracao-omie, plano-execucao]
criado: 2026-09-17
---

# Roteiro de Implementação — passo a passo com endpoint, método e campo exatos

Este é o resumo acionável de todo o levantamento (seções 1 a 4). Cada passo tem o suficiente para um dev abrir e implementar sem precisar cruzar outras notas — endpoint, método RPC, campos exatos e coluna de destino. Onde o detalhe for grande demais para caber aqui, o passo aponta para a nota de origem com a tabela completa.

Convenção: 🟢 extrair do Omie · 🔵 construir nativo no Estoque/MES · 🔴 decisão de arquitetura antes de codificar.

---

## Fase 1 — Baixo esforço, alto risco se não for feito antes do desligamento

### Passo 1 🟢 — Estender `core.parceiros` com dados fiscais

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

**Não precisa de nova chamada de API** — é o mesmo `ListarClientes` já em produção, só amplia o mapeamento de campos. Ver [[Cadastros-Gerais-Lacunas]].

---

### Passo 2 🟢 — Habilitar saldo de estoque

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

**Bloqueio atual**: código do resource já existe (`estoque.ts`, `enabled: false`) — falta só (a) o DBA criar a tabela de destino, (b) trocar `enabled: true`. **Destino sugerido**: `core.estoque_saldo`, chave `(codigo_empresa, codigo_produto_omie, codigo_local_estoque)`. Ver [[Compras-Estoque-Producao-Lacunas]].

---

### Passo 3 🟢 — Extrair `lead_time` do produto

**Endpoint**: `https://app.omie.com.br/api/v1/geral/produtos/`
**Método**: `ListarProdutos` (mesmo método já usado por `produtos.ts`)
**Campo**: `lead_time` (integer, dias) — adicionar à coluna `especificacoes` (jsonb) já existente em `core.produtos`, junto com `peso_bruto`/`peso_liq`/`marca`/`modelo`.

Mesma chamada já em produção, só mais um campo no objeto mapeado. Ver [[Compras-Estoque-Producao-Lacunas]].

---

### Passo 4 🟢 — Extrair frete e parcelas do Pedido de Venda

**Endpoint**: `https://app.omie.com.br/api/v1/produtos/pedido/`
**Método**: `ListarPedidos` (mesmo método já usado por `pedidosVendas.ts`)

| Bloco/campo | Descrição | Destino sugerido |
|---|---|---|
| `frete.transportadora`, `.modalidade_frete`, `.peso_bruto`, `.valor_frete`, `.valor_seguro`, `.codigo_rastreio` | Dados de frete do pedido | Tabela nova `pedidos_vendas_frete` (1:1 com `pedidos_vendas`) |
| `lista_parcelas[]` (data, valor, forma) | Condição de pagamento detalhada | Tabela nova `pedidos_vendas_parcelas` (1:N) |
| `tipo_desconto_pedido`, `perc_desconto_pedido`, `valor_desconto_pedido` | Desconto no nível do pedido (hoje só por item) | Novas colunas em `pedidos_vendas` |

Ver [[Vendas-NFe-Lacunas]].

---

## Fase 2 — Histórico real que vale migrar, esforço médio

### Passo 5 🟢 — Extrair Pedidos de Compra (histórico)

**Endpoint**: `https://app.omie.com.br/api/v1/produtos/pedidocompra/`
**Método de leitura**: `PesquisarPedCompra` (busca por etapa: pendente/faturado/recebido/cancelado/encerrado/parcial) ou `ConsultarPedCompra` (por ID)
**Método de escrita (confirmado existir, útil se o Estoque for criar pedidos programaticamente no futuro)**: `IncluirPedCompra`/`AlteraPedCompra`/`UpsertPedCompra`

Estrutura principal a mapear:
- **cabecalho**: `nCodPed`, `cNumPedido`, `dDtPrevisao`, `nCodFor` (fornecedor), `nCodCompr` (comprador), `cCodCateg`, `cEtapa`
- **frete**: transportadora, peso, valor frete/seguro
- **produtos[]** (itens): `nCodProd`, quantidade, valor unitário, desconto, ICMS/IPI/PIS/COFINS por item, `codigo_local_estoque`
- **parcelas[]**: condição de pagamento

**Novo resource sugerido**: `pedidosCompra.ts`, tabela nova `core_vendas_faturamento.pedidos_compras` + `pedidos_compras_itens`, chave `(codigo_empresa, codigo_pedido_compra_omie)`. Ver [[Compras-Estoque-Producao-Lacunas]].

---

### Passo 6 🟢 — Extrair Locais de Estoque (carga inicial)

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

Cadastro pequeno (poucos registros) — migrar como carga inicial única, não precisa de sync recorrente. Destino: `core.locais_estoque`.

---

### Passo 7 🟢 — Extrair Remessa de Produtos

**Endpoint**: `https://app.omie.com.br/api/v1/produtos/remessa/`
**Método**: `IncluirRemessa`/`ConsultarRemessa` para leitura pontual — **não há método `Listar*` de listagem em massa**, então a extração precisa ser feita cruzando com os pedidos/NFs já conhecidos, ou via `ListarNFeTransp` se aplicável.

Campos principais: `cabec` (`nCodRem`, `nCodCli`, `dPrevisao`, `nCodVend`, `cNumeroRemessa`, `cCancelado`), `frete`, `itens[]` (`nIdProd`, `nQuant`, impostos completos ICMS/IPI/PIS/COFINS), `ListaNfe` (NF de remessa gerada). Ver [[Vendas-NFe-Lacunas]] para o campo a campo completo.

**Ação antes de codificar**: confirmar com o time se a Aços Vital de fato usa Remessa de Produtos (beneficiamento/corte para terceiros) — se o volume for baixo, este passo pode ser adiado.

---

### Passo 8 🟢 — Job dedicado: valor de devolução parcial

**Endpoint**: `https://app.omie.com.br/api/v1/produtos/devolucaovendafaturamento/`
**Método**: `StatusDevolucaoVenda(nCodDevol)` — **chamada individual, não em massa**

Campos retornados: `nCodDevol`, `cNumPed`, `cEtapa`, `cCancelada`, `cFaturada`, **`vTotal`** (valor).

**Implementação sugerida**: job separado do sync padrão — para cada `pedidos_vendas` com `devolucao_parcial = true`, capturar o `nCodDevol` (via `nfconsultar.pedido.nIdPedDev`, já mapeável) e chamar `StatusDevolucaoVenda` para preencher uma nova coluna `pedidos_vendas.valor_devolucao`. **Validar em ambiente de teste** se `vTotal` é o valor da devolução parcial ou o valor total do pedido devolvido antes de confiar no dado. Ver [[Vendas-NFe-Lacunas]].

---

### Passo 9 🟢 — Confirmar sync de Etapas de Faturamento em produção

**Endpoint**: `https://app.omie.com.br/api/v1/produtos/etapafat/`
**Método**: `ListarEtapasFaturamento`

A tabela `core.etapas_faturamento` **já existe** (criada pelo DBA) e o código de extração já está pronto (`etapasFaturamento.ts`). **Ação**: confirmar que o job está de fato habilitado e rodando em produção (não só que a tabela existe) — se sim, ligar ao "dicionário de nomes de etapa" pendente do Portal do Vendedor via `notas_fiscais.oppedido` → `codigo_operacao`. Ver [[Etapas-Faturamento]].

---

## Fase 3 — Nascer nativo no Estoque/MES (não é para extrair do Omie)

### Passo 10 🔵 — Estoque máximo, ponto de pedido, tolerância de peso

**Confirmado que não existe em nenhum endpoint da API do Omie** (verificado em Produtos, Locais de Estoque, Produto x Fornecedor, Ajuste de Estoque, Consulta de Estoque, Resumo do Estoque). Implementar como colunas nativas do módulo de Estoque:
- `material.estoque_maximo` (decimal, por produto × local)
- `material.ponto_pedido` (decimal, por produto × local)
- `material.tolerancia_peso_percentual` (decimal, já citado como "default provisório 5%" no PRD)

Não depende de nenhuma chamada de API — é modelagem pura do lado do Estoque.

### Passo 11 🔵 — Workflow de quarentena/qualidade de lote

Omie (`produtos/produtoslote/`, método `ListarLotes`) só retorna quantidade/data/saldo — **sem campo de status de qualidade**. O workflow completo (`status_qualidade`, `laudo_url`, RNC) precisa ser modelagem nativa do Estoque, já em desenho no PRD (`Estoque-Modelo-Dados.md`).

### Passo 12 🔵 — BOM/roteiro de produção rico

Omie (`geral/malha/`, método `ListarMalha`) modela estrutura de produto simples (componente + quantidade + % perda), sem centro de trabalho/tempo padrão/sequência de operação. Roteiro real de produção nasce nativo no MES; migrar só a BOM já cadastrada no Omie como carga inicial, se existir volume relevante.

### Passo 13 🔵 — Requisição de compra / sugestão automática de compra

Omie tem Requisição de Compra (`produtos/requisicaocompra/`) como estágio manual anterior ao Pedido de Compra, sem lógica de "quando comprar". Essa lógica (baseada em estoque mínimo/ponto de pedido do Passo 10) precisa nascer nativa no Estoque.

### Passo 14 🔵 — Tabela de Preços

Omie tem cadastro completo (`produtos/tabelaprecos/`, método `ListarTabelaPreco`), mas como impacta margem diretamente, recomenda-se nativizar como configuração comercial do sistema novo em vez de depender do Omie continuamente.

---

## Fase 4 — Decisão de arquitetura antes de qualquer código

### Passo 15 🔴 — Módulo financeiro

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
