---
tags: [integracao-omie, indice]
criado: 2026-09-17
atualizado: 2026-10-07
---

# Integração Omie — Dicionário de Dados e Lacunas

> Status: decidido (rodada de 07/10) | no código (`master` d2886bf) | em produção (verificado em 07/10/2026 só pelo dump, [[Auditoria-Dump-Producao-2026-10-07]]). Decisões em [[Registro-de-Decisoes-2026-10-07]].

> **Achado crítico de 07/10 (🔴 Gustavo, #15):** o `exclusionSync` apaga `pedidos_vendas` por empresa e janela **sem filtrar `manual`**; pedidos manuais têm `codigo_pedido_omie` negativo, não existem no Omie e entram na lista de excluídos. Confirmar antes de usar pedido manual em produção. Detalhe em [[Arquitetura-do-Pipeline]] (jobs de exclusão) e [[Colunas-Protegidas]].

> **Atualização de 07/10/2026 — achados e lacunas reconferidos contra o código do pipeline (`master` d2886bf, 06/10; leitura de código, não produção/deploy).** Desde a primeira versão (17/09) o pipeline ganhou o domínio de Compras (espelho de pedidos, compradores, catálogos, PTAX, inativação de catálogos e envio de OC ao Omie), dados fiscais de parceiro e etapas de faturamento ligadas; a camada raw foi removida (06/10). **Continuam abertos**: locais de estoque (continua, B6), frete/parcelas/desconto do PV. **Decididos em 07/10**: saldo de estoque (descartado), `lead_time` (sai do pipeline), remessa e devolução (Ciclo 2, 04/01/2027), financeiro (fica no Omie), endereço de entrega e dados bancários do parceiro (fora do escopo). Cada achado abaixo está anotado com "(atualizado em 07/10)" onde mudou. Ver [[Arquitetura-do-Pipeline]] e [[Roteiro-de-Implementacao]].

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
- 🟢 **Confirmado**: saldo de estoque (`ListarPosEstoque`) está com código pronto mas **desabilitado** no pipeline por falta de tabela — e agora sabemos exatamente os campos que ele traria (`saldo`, `cmc`, `pendente`, `estoque_minimo`, `reservado`, `fisico`). **(Atualizado em 07/10: segue desabilitado — `enabled:false`, `table:null` — mas a tabela de destino já existe no banco, `core.estoque_saldo`/`core.locais_estoque`, contratos 002 e 005; falta ligar o recurso a ela. Saldo NÃO está fechado no pipeline. **Decidido em 07/10 (✅, #28): não será habilitado — o Omie recebe dados só manualmente e o estoque dele é ignorado; o MES é a referência do saldo físico.**)**
- 🟢 **Resolvido**: o Omie **tem sim** API de criação de Pedido de Compra (CRUD completo, `produtos/pedidocompra/`) — a dúvida antiga sobre isso está encerrada. **(Atualizado em 07/10: o pipeline já usa — `UpsertPedCompra`/`ExcluirPedCompra` no `envio-oc-worker`, única escrita do pipeline no Omie. Decidido (✅, #7): envio fixo no código, direto ao Omie, sem `SYNC_ENVIO_OC` nem `ENVIO_OC_DRY_RUN`; ~4 testes reais do Nathan; L10.1, L10.6 (FOB) e L10.7 (b) a (d) = risco aceito. ~~`SYNC_ENVIO_OC=false` por padrão, estado em produção desconhecido~~ superado.)**
- 🔴 **Novo achado, maior escopo que o pipeline**: **nenhum dado financeiro é extraído** (Contas a Pagar/Receber, extrato bancário) e **não existe módulo financeiro no roadmap** do ERP novo — isso é uma decisão de arquitetura pendente, não uma lacuna de pipeline. Ver [[Financas-Lacunas]]. **Decidido em 07/10 (✅, #30; DEC-11): o Omie segue como sistema financeiro e fiscal, sem plano de desligar; não há módulo financeiro a construir.**
- 🔴 **Gap fiscal crítico**: dados fiscais completos de cliente/fornecedor (IE, IM, Suframa, Simples Nacional, CNAE, código IBGE da cidade) não são extraídos — serão necessários no dia em que o sistema próprio precisar emitir nota fiscal sem o Omie. Ver [[Cadastros-Gerais-Lacunas]]. **(Atualizado em 07/10: dados fiscais do parceiro passaram a ser gravados em `core.parceiros` (66f9a2e). Seguem sem escrita `enderecoEntrega` e `dadosBancarios` — as tabelas existem.)**
- 🟢 **Etapas de faturamento**: endpoint, mapeamento e tabela `core.etapas_faturamento` já implementados (a tabela já foi criada pelo DBA) — candidata a resolver o "dicionário de nomes de etapa" pendente no Portal do Vendedor. Ver [[Etapas-Faturamento]]. **(Atualizado em 07/10: `enabled:true` no código e tabela populada em produção, ✅ #5.)**
- 🟢 **Novo dado não documentado na seção de modelagem**: `pedidos_vendas.codigo_projeto` e `.numero_contrato` são extraídos do Omie e já existem na tabela — podem ser úteis para o MES/Estoque sem esforço extra de integração.

## Recursos de Compras (novo em 07/10)

Entre 23/09 e 06/10 o pipeline ganhou o domínio de Compras. Ainda não há uma nota de dicionário campo a campo para cada um (só os resumos abaixo e a tabela de endpoints em [[Arquitetura-do-Pipeline]]); fonte: leitura de código, produção não verificada.

| Recurso | Destino | Nota |
|---|---|---|
| `pedidosCompras` | `pedidos_compras` + `_itens` + `_parcelas` | `PesquisarPedCompra` com `lApenasAlterados=T`; itens/parcelas REPLACE-ALL por pedido. Em produção (dump de 07/10): 22.808 pedidos, etapas 10/15/20 = 1.186/20.380/1.242; nomes oficiais das etapas 🔴 Nathan (olhar um pedido de cada etapa no Omie, #52) |
| `compradores` | `core_vendas_faturamento.compradores` | `ativo` = `cInativo !== 'S'`; colunas protegidas `id_funcionario`, `nome_exibicao`, `ativo_desde`, `inativo_desde` (vínculo manual) |
| `condicoesPagamentoCompras`, `projetos`, `contasCorrentes`, `categorias` | `condicoes_pagamento_compras`, `core.projetos`, `core.contas_correntes`, `core.categorias` | só camadas lentas (3h + full) |
| PTAX (BCB) | `core.cotacoes_moeda` | 13:30 e 17:30 seg–sex; só boletim Fechamento |
| inativar catálogos | `ativo=false` nos 5 catálogos | `47 4 * * *`; não age se o Omie devolver menos da metade dos ativos |
| envio de OC | Omie (`UpsertPedCompra`/`ExcluirPedCompra`) | única escrita no Omie; ver [[23-Compras-Pipeline-Consolidado]] |

## Ver também
- [[Omie-ELT-Pipeline]]
- [[Estoque-Modelo-Dados]]
- [[Perguntas-Pendentes-MES-Estoque]]
