---
tags: [integracao-omie, lacunas]
criado: 2026-09-17
atualizado: 2026-10-07
---

# Campos que o Estoque/MES precisa e o Omie não fornece

> Status: decidido (saldo do Omie não sincroniza, por decisão; envio de OC fixo no código) | no código (`master` d2886bf) | em produção (verificado em 07/10/2026 só pelo dump). Decisões em [[Registro-de-Decisoes-2026-10-07]].

> **Atualização de 07/10/2026 — conferido contra o código do pipeline (`master` d2886bf; leitura de código, não produção).** (1) O saldo de estoque **continua sem sincronizar** (§1): o recurso segue `enabled:false`, embora as tabelas de destino já existam no banco. (2) A "ressalva" do §2 sobre habilitar o staging raw **ficou obsoleta**: `omie_raw.*`/`RAW_AUDIT_ENABLED` foram removidos em 06/10 (contrato 38). (3) O §4 estava errado: o Omie **tem** API de criação de pedido de compra e o pipeline já a usa. O item 1 (saldo) permanece válido.

Cruzamento entre o que os documentos de PRD/arquitetura da seção de modelagem pedem e o que o `omie-elt-pipeline` de fato extrai hoje (código lido diretamente, não só a nota-resumo).

## 1. Saldo de estoque — ~~lacuna confirmada, sem solução no pipeline~~ decidido: não será sincronizado

> **Fechado em 07/10 (✅, #28):** o `ListarPosEstoque` fica `enabled:false` por **decisão** (não habilitar). O Omie recebe dados só manualmente e o estoque do Omie é ignorado; o MES é a referência do saldo físico (fecha L-03). O saldo que "não sincroniza" deixa de ser lacuna. O texto abaixo é histórico.

O endpoint `ListarPosEstoque` (`/estoque/consulta/`) existe no código (`estoque.ts`) mas está com `enabled: false`, porque **não existe tabela de destino** no schema atual do DBA (só existe cadastro de produto, não saldo). Nada sincroniza saldo do Omie automaticamente hoje. **(Atualizado em 07/10: a tabela de destino já existe no banco — `core.estoque_saldo` e `core.locais_estoque`, contratos 002 e 005 —; o que falta é ligar o recurso `estoque.ts` a ela e trocar `enabled`. O comentário "sem tabela de destino" no próprio arquivo está defasado.)**

**Implicação para o PRD do Estoque**: se a intenção é que o saldo inicial ou de referência venha do Omie, isso exige (a) o DBA criar a tabela de destino e (b) habilitar esse resource no pipeline — não é trabalho do módulo de Estoque, é pré-requisito de infraestrutura.

## 2. Tolerância de peso, estoque mínimo/máximo, ponto de pedido — confirmado que não existem

`core.produtos.especificacoes` (jsonb) traz `altura`, `largura`, `profundidade`, **`peso_bruto`**, **`peso_liq`**, `marca`, `modelo` — e só isso. Não há tolerância de peso, estoque mínimo, estoque máximo nem ponto de pedido em nenhum lugar do schema sincronizado do Omie.

Isso **resolve parcialmente** a pergunta em aberto da seção de modelagem ("campos extras do Estoque podem vir do Omie ou virar colunas novas"): peso bruto/líquido **já vêm** prontos; os quatro campos de controle de estoque **não vêm** e precisam ser criados como colunas próprias do módulo de Estoque, populadas por regra de negócio do Estoque, não por sincronização do Omie.

> Ressalva (histórica; atualizado em 07/10): isso reflete os campos que o pipeline **mapeia para colunas**. A versão de 17/09 sugeria habilitar o staging `omie_raw.produtos` (`RAW_AUDIT_ENABLED`) para inspecionar o JSON bruto — **essa opção não existe mais**: a camada raw foi removida do código em 06/10 (contrato 38). A dúvida já foi respondida de outra forma: o levantamento da documentação oficial da API (ver [[Compras-Estoque-Producao-Lacunas]]) confirmou que o cadastro de produto tem campos não mapeados (`lead_time`, características, kit, tabelas de preço, bloco fiscal) e que estoque máximo, ponto de pedido e tolerância de peso não existem no Omie.

## 3. Devolução parcial — só um boolean, sem valor

`pedidos_vendas.devolucao_parcial` é um boolean puro. Não existe, em nenhuma tabela sincronizada do Omie, o **valor** dessa devolução parcial. Isso já era um ponto conhecido na seção de modelagem (afeta o cálculo de faturamento líquido G2P) — confirmado aqui que o pipeline realmente não traz esse valor, não é uma lacuna de mapeamento, é uma lacuna do próprio dado disponível via API do Omie.

## 4. Ordem de Compra — API de criação (corrigido em 07/10)

> **Corrigido em 07/10.** O texto original (17/09) dizia que todos os endpoints do pipeline eram de leitura e que a API de criação de OC era "não confirmada". Isso foi superado já em 17/09 pelo levantamento da API (o Omie tem CRUD completo em `produtos/pedidocompra/`, ver [[Perguntas-em-Aberto]], item 4) e, desde 23/09, **o pipeline escreve no Omie**: o `envio-oc-worker` chama `UpsertPedCompra` (envio) e `ExcluirPedCompra` (exclusão) — **a única escrita do pipeline no Omie**; todo o resto segue leitura (`Listar*`, `Pesquisar*`, `Consultar*`). **Decidido em 07/10 (✅, #7):** o envio fica **fixo no código** e vai direto ao Omie, sem `SYNC_ENVIO_OC` nem `ENVIO_OC_DRY_RUN`; o Nathan rodou cerca de 4 testes reais e a OC entrou. ~~Só é agendado com `SYNC_ENVIO_OC=true` (default do código: `false`, com `ENVIO_OC_DRY_RUN=true`); se está ligado em produção, é desconhecido.~~ (superado). Ver [[23-Compras-Pipeline-Consolidado]].

## 5. Histórico granular de status do pedido — não é responsabilidade do pipeline

`pedidos_vendas_status_historico` (schema Postgres) não aparece como destino de nenhuma extração do pipeline — o pipeline só grava em `pedidos_vendas` diretamente; `situacao` inclusive é recalculada por **trigger do banco**, não pelo pipeline. Ou seja: a "granularidade insuficiente" desse histórico não é uma limitação do que o Omie oferece — é uma decisão de schema do lado do banco/DBA. Se o Estoque/MES precisar de histórico mais fino, a solução está inteiramente do lado do Postgres (nova tabela/trigger), não depende de trazer mais dado do Omie. A proposta concreta (log de eventos, tabelas e campos) está na seção de modelagem: `04-Arquitetura-Transversal/Rastreabilidade-e-SLA-de-Eventos.md` e [[Campos-e-API-para-Rastreabilidade]] (wikilinks não atravessam vaults).

## Ver também
- [[Produtos-e-Familias]]
- [[Pedidos-de-Venda]]
- [[Perguntas-em-Aberto]]
