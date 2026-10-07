---
tags: [integracao-omie, levantamento-api, achado]
criado: 2026-09-17
atualizado: 2026-10-07
---

# Síntese — o que pegar a mais, o que não, e o que criar do zero

> Status: decidido (saldo, locais, `lead_time`, devolução, remessa, financeiro) | no código (`master` d2886bf) | em produção (verificado em 07/10/2026 só pelo dump). Decisões em [[Registro-de-Decisoes-2026-10-07]].

> **Reclassificação de 07/10/2026 (✅ salvo indicação):** **saldo de estoque do Omie: descartado** (#28, o Omie é manual e o estoque dele é ignorado); **locais de estoque: continuam** (#29, B6, Gustavo); **`lead_time`: sai do pipeline** (#29, cadastro no MES); **devolução: nativa do Estoque** (DEC-10, Ciclo 2; 🟡 #31); **remessa de produtos: Ciclo 2** (#27); **financeiro: fica no Omie** (#30, DEC-11, sem plano de desligar). As linhas 🟢/🔴 correspondentes abaixo ficam como histórico e foram marcadas.

> **Atualização de 07/10/2026 — as classificações (🟢/🔵/⚪/🔴) abaixo continuam valendo como recomendação; o que mudou é o estado de execução.** Conferido contra o código do pipeline (`master` d2886bf; leitura de código, não produção):
>
> | Item da matriz | Estado no pipeline |
> |---|---|
> | Dados fiscais de parceiro | **feito** (66f9a2e) |
> | Endereço de entrega, dados bancários do parceiro | **fora do escopo** (✅ 07/10; tabelas existem e estão vazias) |
> | Parcelas / condições de pagamento (compras) | **feito** (`condicoesPagamentoCompras`) |
> | Pedidos de compra (histórico) | **feito** (`pedidosCompras`) |
> | Pedidos de compra (fluxo de criação) | **feito** no av-hub → Omie por `UpsertPedCompra` (única escrita do pipeline; fixo no código, direto ao Omie, ~4 testes reais do Nathan — ✅ 07/10, #7) |
> | Compradores | **lido** (`ListarCompradores`), vínculo manual |
> | Saldo de estoque | **descartado** (✅ 07/10) — recurso `enabled:false` fica assim; tabela já existe no banco (contratos 002/005) |
> | Locais de estoque | **continua** (B6, Gustavo); sem recurso ainda |
> | `lead_time` | **sai do pipeline** (cadastro no MES) |
> | Estoque mínimo | **aberto** (sem mapeamento) |
> | Frete/parcelas/desconto do pedido de venda | **aberto** (contrato 003 aplicado, pipeline não grava) |
> | Valor da devolução parcial | **nativo do Estoque** (DEC-10, Ciclo 2); contrato 011/006 invalidado |
> | Remessa de produtos | **Ciclo 2** (04/01/2027) |
> | Financeiro | **fica no Omie** (✅ 07/10, DEC-11) |
> | Comissão do vendedor | **aberto** — `comissao` protegida; vendedores relistados por inteiro |

Consolidação do levantamento completo da API do Omie (`developer.omie.com.br/service-list/`), cruzado com o que já é extraído pelo `omie-elt-pipeline` e com o que o PRD do Estoque/MES precisa. Cada linha é uma recomendação objetiva, não uma lista de campos — os detalhes campo a campo estão em [[Cadastros-Gerais-Lacunas]], [[Compras-Estoque-Producao-Lacunas]], [[Vendas-NFe-Lacunas]] e [[Financas-Lacunas]].

## Como ler esta matriz

- 🟢 **Extrair do Omie antes do desligamento** — dado histórico real que só existe lá, sem substituto.
- 🔵 **Nascer nativo no sistema novo** — mesmo que o Omie tenha esse dado, o processo vai mudar ou o modelo do Omie é raso demais; migrar seria copiar uma limitação.
- ⚪ **Deixar no Omie sem urgência** — baixo risco, dado derivado/recalculável, ou dependente de um módulo que ainda nem existe no roadmap.
- 🔴 **Decisão de arquitetura pendente** — não é uma tarefa de extração, é uma lacuna estrutural que precisa de decisão de escopo.

## Cadastros e fiscal

| Item | Classificação | Motivo |
|---|---|---|
| Dados fiscais de parceiro (IE, IM, Suframa, Simples Nacional, CNAE, cidade_ibge) | 🟢 Extrair | Crítico para emitir NF-e sem o Omie no futuro |
| Endereço de entrega separado (`enderecoEntrega`) | 🟢 Extrair — **fora do escopo (✅ 07/10)** | Logística de siderurgia entrega fora do endereço fiscal com frequência |
| Dados bancários do parceiro | 🟢 Extrair — **fora do escopo (✅ 07/10)** | Necessário se o sistema próprio assumir pagamento/cobrança; o Omie segue financeiro |
| Características de cliente (key-value) | 🔵 Nascer nativo (condicional) | Só se houver uso real hoje — checar conteúdo cadastrado antes de decidir; se migrar, estruturar como colunas, não copiar o key-value livre |
| Cadastro da própria empresa (Empresas) | ⚪ Deixar no Omie | É config do emissor fiscal, não dado a migrar em massa |
| Departamentos / Categorias (plano de contas) | ⚪ Deixar no Omie | Config contábil, só relevante se módulo financeiro nascer |
| Parcelas (condições de pagamento) | 🔵 Nascer nativo | Tabela pequena, barata de recriar |
| Documentos Anexos | ⚪ Deixar no Omie | Repositório de arquivo, baixo valor de migração em massa |

## Compras, Estoque e Produção

| Item | Classificação | Motivo |
|---|---|---|
| `lead_time` do produto | ~~🟢 Extrair~~ → **sai do pipeline (✅ 07/10): cadastro no MES** | Já existe pronto no Omie, direto relevante para ressuprimento |
| Estoque mínimo (por produto×local) | 🟢 Extrair | Já existe pronto (`AlterarEstoqueMinimo`), evita recriar do zero |
| Estoque máximo, ponto de pedido, tolerância de peso | 🔵 Nascer nativo | **Confirmado que não existe em lugar nenhum do Omie** — não tem o que migrar |
| Saldo de estoque (`Consulta Estoque`) | ~~🟢 Extrair~~ → **descartado (✅ 07/10)** | Endpoint com código pronto, só desabilitado por falta de tabela — agora sabemos os campos exatos. Decisão: o Omie recebe dados só manualmente e o estoque dele é ignorado; o MES é a referência do saldo físico |
| Características técnicas de produto | 🔵 Nascer nativo | Especificação de aço (bitola/liga/têmpera) merece campos estruturados e validados, não key-value livre do Omie |
| Estrutura/BOM (ficha técnica) | 🔵 Nascer nativo | Roteiro de produção real precisa ser mais rico que o modelo do Omie; migrar só carga inicial se houver BOM já cadastrada |
| % de perda em BOM | 🟢 Extrair (se houver dado histórico) | Relevante para corte de chapa/flange, mas o processo em si nasce nativo |
| Produtos - Lote (quantidade/data, sem status de qualidade) | 🔵 Nascer nativo | Workflow de quarentena é exigência nova que o Omie não modela |
| Requisições de Compra | 🔵 Nascer nativo | A lógica de "quando comprar" que falta hoje deve morar no Estoque, não no Omie |
| Pedidos de Compra (histórico) | 🟢 Extrair | Rastreabilidade de fornecedor — dado histórico real |
| Pedidos de Compra (fluxo de criação) | 🔵 Nascer nativo | Omie tem API de criação (confirmado), mas o processo deve passar a nascer no Estoque assim que ele virar sistema de registro |
| Ordens de Produção | 🔵 Nascer nativo | Omie não tem conceito de roteiro/centro de trabalho — modelo raso demais para copiar |
| Nota de Entrada / emissão fiscal de compra | ⚪ Deixar no Omie (ou futuro emissor) | Documento fiscal real, não é para reconstruir no MES |
| Recebimento de Nota Fiscal (lógica de conferência) | 🔵 Nascer nativo | Mas os campos fiscais (chave NF-e, itens fiscais) devem continuar vindo de fora via integração |
| Compradores (cadastro) | 🔵 Nascer nativo (se processo migrar) | Omie não tem API de criação — não dá pra manter só lá |
| Locais de Estoque | 🟢 Extrair (carga inicial) — **continua (✅ 07/10, B6, Gustavo)** | Cadastro pequeno, poucos registros, barato migrar como base |

## Vendas e NF-e

| Item | Classificação | Motivo |
|---|---|---|
| Frete do pedido (transportadora, valores, rastreio) | 🟢 Extrair | Ausente hoje, dado real de cada pedido |
| Parcelas do pedido (`lista_parcelas`) | 🟢 Extrair | Condição de pagamento detalhada, ausente hoje |
| Valor da devolução parcial (`vTotal`) | ~~🟢 Extrair (com esforço extra)~~ → **🔵 nativo do Estoque (DEC-10, Ciclo 2)** | Só acessível por chamada individual, não em massa; o `StatusDevolucaoVenda` não está disponível no Omie (🟡 #31). Superado o job dedicado sugerido antes |
| Histórico de mudança de etapa do pedido | 🔵 Nascer nativo | Melhor registrar como evento no momento em que acontece do que puxar retroativamente |
| CT-e | 🟢 Extrair (se volume relevante) | Documento fiscal de frete — avaliar volume antes de priorizar |
| Remessa de Produtos | 🟢 Extrair — **Ciclo 2 (04/01/2027, ✅ 07/10)** | Documento fiscal real de movimentação sem venda, relevante para beneficiamento/corte para terceiros |
| Tabela de Preços | 🔵 Nascer nativo | Impacta margem diretamente, faz mais sentido como configuração comercial do sistema novo |
| Comissão do vendedor (segue aberto em 07/10) | 🟢 Extrair (se confirmado que é a fonte) | Hoje é coluna protegida no pipeline por suspeita de vir de outro sistema — verificar se é este campo do Omie |
| Meios de Pagamento / Motivos de Devolução | 🔵 Nascer nativo | Tabelas de lookup triviais, baratas de recriar como enum |

## Financeiro

| Item | Classificação | Motivo |
|---|---|---|
| Contas a Pagar, Contas a Receber, Extrato, Lançamentos de Conta Corrente | ~~🔴 Decisão de arquitetura pendente~~ → **⚪ fica no Omie (✅ 07/10, DEC-11)** | O Omie segue como sistema financeiro e fiscal, sem plano de desligar; não há módulo financeiro a construir. Texto original: não existe módulo financeiro no roadmap — precisaria decidir se nasce um, antes que o desligamento do Omie vire bloqueio |
| Boleto, PIX, Orçamento de Caixa, Pesquisar Títulos, Movimentos Financeiros | ⚪ Deixar no Omie | Derivados/operacionais, sem urgência — mas migram junto com CP/CR quando a decisão acima for tomada |

## Ação recomendada, em ordem

1. ~~**Levar o achado 🔴 (módulo financeiro) para quem decide o roadmap**~~ — **resolvido em 07/10 (✅):** o Omie segue como financeiro; não há bloqueio de desligamento.
2. **Estender a extração de parceiros** com os campos fiscais 🟢 — menor esforço, maior redução de risco para o dia da emissão fiscal própria. **(Atualizado em 07/10: campos fiscais feitos; faltam endereço de entrega e dados bancários.)**
3. ~~**Habilitar o endpoint de saldo de estoque**~~ — **cancelado em 07/10 (✅, #28).** Histórico: código já pronto, só falta a tabela do lado do DBA. **(Atualizado em 07/10: a tabela já existe no banco; falta ligar o recurso `estoque.ts`, hoje `enabled:false`.)**
4. **Confirmar com o time de Estoque** quais itens 🔵 já estão sendo desenhados nativamente (BOM, quarentena, estoque máximo/ponto de pedido) para não duplicar esforço com uma tentativa de "importar" isso do Omie.

## Ver também
- [[Cadastros-Gerais-Lacunas]]
- [[Compras-Estoque-Producao-Lacunas]]
- [[Vendas-NFe-Lacunas]]
- [[Financas-Lacunas]]
- [[Perguntas-em-Aberto]]
