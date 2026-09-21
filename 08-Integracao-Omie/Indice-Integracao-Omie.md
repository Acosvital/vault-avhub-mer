---
tags: [integracao-omie, indice]
criado: 2026-09-17
---

# Integração Omie — Dicionário de Dados e Lacunas

Seção de apoio, derivado de uma leitura direta do código-fonte do `omie-elt-pipeline` (não apenas da nota-resumo que já existe na seção de modelagem). Objetivo: registrar **campo a campo** tudo que o pipeline extrai do Omie e grava no Postgres, e cruzar isso com o que as notas de modelagem dizem precisar — para achar lacunas reais antes de desenhar o módulo de Estoque/MES em cima de dados que talvez não existam.

Esta seção não substitui a nota [[Omie-ELT-Pipeline]] da seção de modelagem (que cobre arquitetura, incidentes e filosofia do pipeline) — ele complementa com o nível de detalhe de coluna/campo que faltava.

## Como está organizado

- **1. Dados Extraídos** — um arquivo por tabela de destino, com a lista completa de colunas e o campo Omie de origem de cada uma: [[Parceiros-Clientes-Fornecedores]], [[Produtos-e-Familias]], [[Vendedores]], [[Pedidos-de-Venda]], [[Notas-Fiscais-e-Itens]], [[Etapas-Faturamento]].
- **2. Análise de Lacunas** — o que a seção de modelagem diz precisar e não está sendo extraído, contradições encontradas entre a documentação e o código real, colunas que nenhum dos dois lados escreve, e perguntas em aberto: [[Campos-Faltantes-para-Estoque-MES]], [[Contradicao-CFOP]], [[Colunas-Protegidas]], [[Perguntas-em-Aberto]].
- **3. Arquitetura** — visão rápida de como o pipeline funciona (EL, não ETL): [[Arquitetura-do-Pipeline]].
- **4. Levantamento da API do Omie** — auditoria completa de `developer.omie.com.br` (não só do que o pipeline já extrai): tudo que a API oferece, o que vale a pena pegar antes do Omie ser desligado, e o que deve nascer nativo no sistema novo: [[Cadastros-Gerais-Lacunas]], [[Compras-Estoque-Producao-Lacunas]], [[Vendas-NFe-Lacunas]], [[Financas-Lacunas]], e a síntese final [[Sintese-Migrar-vs-Nascer-Nativo]].
- **5. Plano de Execução** — o resumo acionável de tudo isso: passo a passo, priorizado, com endpoint exato, método RPC exato e campo exato para o dev implementar sem precisar cruzar as outras notas: [[Roteiro-de-Implementacao]].

## Achados-chave desta análise

- 🔴 **Contradição encontrada**: a seção de modelagem afirma que CFOP "fica 100% com o Omie" e não é capturado por nenhum sistema — mas o pipeline **captura e valida `cfop` por item** em `produto_vendas` (contra uma whitelist `core_vendas_faturamento.cfop`). Só ICMS-ST continua de fato não capturado. Ver [[Contradicao-CFOP]].
- 🟡 **Parcialmente resolvido**: a dúvida sobre se peso do produto vem do Omie — `especificacoes` (jsonb) em `core.produtos` já traz `peso_bruto` e `peso_liq`. **Estoque mínimo também existe** na API (por produto×local). O que **de fato não existe em lugar nenhum** é tolerância de peso, estoque máximo e ponto de pedido — confirmado via documentação oficial da API, não é falta de extração. Ver [[Campos-Faltantes-para-Estoque-MES]] e [[Compras-Estoque-Producao-Lacunas]].
- 🟢 **Confirmado**: saldo de estoque (`ListarPosEstoque`) está com código pronto mas **desabilitado** no pipeline por falta de tabela — e agora sabemos exatamente os campos que ele traria (`saldo`, `cmc`, `pendente`, `estoque_minimo`, `reservado`, `fisico`).
- 🟢 **Resolvido**: o Omie **tem sim** API de criação de Pedido de Compra (CRUD completo, `produtos/pedidocompra/`) — a dúvida antiga sobre isso está encerrada.
- 🔴 **Novo achado, maior escopo que o pipeline**: **nenhum dado financeiro é extraído** (Contas a Pagar/Receber, extrato bancário) e **não existe módulo financeiro no roadmap** do ERP novo — isso é uma decisão de arquitetura pendente, não uma lacuna de pipeline. Ver [[Financas-Lacunas]].
- 🔴 **Gap fiscal crítico**: dados fiscais completos de cliente/fornecedor (IE, IM, Suframa, Simples Nacional, CNAE, código IBGE da cidade) não são extraídos — serão necessários no dia em que o sistema próprio precisar emitir nota fiscal sem o Omie. Ver [[Cadastros-Gerais-Lacunas]].
- 🟢 **Etapas de faturamento**: endpoint, mapeamento e tabela `core.etapas_faturamento` já implementados (a tabela já foi criada pelo DBA) — candidata a resolver o "dicionário de nomes de etapa" pendente no Portal do Vendedor. Ver [[Etapas-Faturamento]].
- 🟢 **Novo dado não documentado na seção de modelagem**: `pedidos_vendas.codigo_projeto` e `.numero_contrato` são extraídos do Omie e já existem na tabela — podem ser úteis para o MES/Estoque sem esforço extra de integração.

## Ver também
- [[Omie-ELT-Pipeline]]
- [[Estoque-Modelo-Dados]]
- [[Perguntas-Pendentes-MES-Estoque]]
