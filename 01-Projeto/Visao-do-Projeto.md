---
tags: [projeto, visao, erp, principios]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [v1 00-Indice/Comece-Aqui §5, v1 Decisoes-Chave-ERP, decisões do Nathan de 14/10/2026, código de 14/10 (api-pcp 579a625, app-pcp 1fca8d3, api-acos-vital f322dcd, HUB b55ac55, omie-elt-pipeline 0f739f0), dumps de esquema de 14/10]
---

# Visão do projeto

## O que é o ERP

O ERP da Aços Vital é a camada que acompanha **um pedido de venda de 0 a 100%**: do pedido criado no Omie até a nota fiscal emitida pelo Omie, passando por liberação do vendedor, triagem e destinação do PCP, atendimento pelo Estoque, compra, recebimento, qualidade, produção, expedição e baixa. O desenho de referência é o diagrama 0b em [[00-Fluxo-Mestre-0b]]; este vault é o manual para desenvolvê-lo.

Ele é feito de quatro sistemas que se falam por contratos (detalhe em [[Sistemas-e-Responsabilidades]]):

| Sistema | Papel | Onde |
|---|---|---|
| **Omie** (externo) | ERP fiscal. Emite a nota fiscal, guarda pedidos, produtos e parceiros | SaaS |
| **av-hub** | Portal comercial e de compras: HUB (front Next.js), `api-acos-vital` (API do Hub), `api-comercial` (Comercial & Suprimentos) | [[AV-Hub-Front]], [[AV-Hub-API]], [[API-Comercial]] |
| **MES** | Chão de fábrica, Estoque, Recebimento e Qualidade: `api-pcp` (back) e `app-pcp` (front) | [[MES-Backend]], [[MES-Front]] |
| **Pipeline Omie** | Extrai o Omie para o banco do av-hub e envia a OC ao Omie | [[Pipeline-Omie]] |

## O pedido de 0 a 100% em 12 passos

IDs de nó do [[00-Fluxo-Mestre-0b]].

1. **Nasce no Omie** e chega travado ao av-hub pela pipeline (`V1`) ✅.
2. **O vendedor marca** se a Qualidade acompanha desde o início e **libera** o pedido (`V2`, `V3`) ✅. Nota: [[01-Vendas-Liberacao]].
3. **PCP, Triagem do Pedido:** lista só os pedidos liberados (`P1`) ✅.
4. **PCP, Destinação do Pedido:** define destino (`FABRICACAO` ou `REVENDA`) e quantidade de cada item; o backend insere o Estoque como etapa 1 e confirma a importação ao av-hub (`P2`) ✅. Nota: [[02-PCP-Triagem-e-Destinacao]].
5. **Estoque:** confere o saldo na filial do pedido, atende o que puder (split e reserva) e decide o restante: solicitar compra ou enviar à produção (`E1` a `E4`) ✅. Nota: [[03-Estoque-Atendimento-e-Despacho]].
6. **Compra** (se faltou): requisição (origem PCP no MES ou origem Compras no av-hub), cotação, aprovação, OC, envio ao Omie, follow-up (`P3`, `C0` a `C5`) ✅. O MES deve ler as OCs do hub: o PCP vê a OC do pedido e o Estoque vê o saldo futuro 📝 🔴 (N14-20). Nota: [[04-Circuito-de-Compra]].
7. **Recebimento:** a OC aprovada vira esperada; a doca registra a chegada com a NF, confere contra a NF, pesa e cria o lote em quarentena (`R0` a `R4`, `R6`) ✅. Nota: [[05-Recebimento]].
8. **Qualidade de entrada:** inspeciona por lote; aprovado vira saldo no Estoque, reprovado abre RNC (`Q1` a `Q4`, `E5`) ✅. Nota: [[06-Qualidade-Entrada]].
9. **Produção:** o que o Estoque envia à produção passa pelos setores do roteiro (`F1`) ✅. Nota: [[07-Producao-e-Roteiro]].
10. **Qualidade de saída:** inspeção no roteiro; aprovado volta ao Estoque, reprovado vai ao PCP (`Q7`, `Q8`, `P6`) 🟡. Nota: [[08-Qualidade-Saida]].
11. **Despacho e Expedição:** o Estoque despacha com **documento de retirada** e baixa na retirada (`E6`) 🔴; a Expedição embala, paletiza, consolida e cuida do transporte (`X1` a `X4`) 🟡. Notas: [[03-Estoque-Atendimento-e-Despacho]], [[09-Expedicao]].
12. **Fiscal:** o Omie emite a nota e baixa o item no pedido (`O1`, `O2`) ✅ lado Omie; a sinalização do MES ao Omie não existe 🔴. Nota: [[10-Fiscal-Omie]].

Em paralelo ao 0b correm três fluxos transversais: o **status por item** (cartão "Etapa dos itens" no HUB), a **Torre de Fluxo** e o **custo do lote**. Ver [[Rastreabilidade-e-Torre-de-Fluxo]] e [[Modelo-Estoque-e-Custo-do-Lote]].

## Princípios que valem

| #   | Princípio                                                                                                                                                                                                                                                                                          | Selo  | Evidência                                                                                                                                                                                                                                                                      |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | **O sistema nunca emite nem edita nota fiscal.** Só o Omie emite; o sistema sinaliza e referencia                                                                                                                                                                                                  | 📝 ✅  | A única escrita da pipeline no Omie é a OC: `omie-elt-pipeline/src/jobs/envioOrdensCompra.ts` (`UpsertPedCompra`/`ExcluirPedCompra`); nenhuma chamada de emissão de NF                                                                                                         |
| 2   | **av-hub decide, MES executa.** Pedido, OC e liberação nascem no av-hub; produção, recebimento e saldo no MES. Exceção deliberada: devolução de cliente é decidida no Estoque                                                                                                                      | 📝    | v1 Decisoes-Chave-ERP, DEC-10                                                                                                                                                                                                                                                  |
| 3   | **Só polling entre sistemas, mais o `PUT` do contrato 34.** Sem webhook nem tempo real. O MES empurra a requisição (`PUT /compras/requisicoes/origem/{id_origem}`) e lê eventos, status e liberações por polling                                                                                   | ✅     | `api-pcp/src/integracao-avhub/envio-avhub.service.ts:129-175` (PUT com fila e retentativa); `api-pcp/src/integracao-avhub/eventos-avhub.service.ts` (polling de 5 min). Contratos [[LOG-34-Requisicoes-MES-Empurra-para-o-Hub]], [[LOG-35-Compras-Marcos-Requisicao-para-MES]] |
| 4   | **Colunas protegidas.** Cada coluna tem um dono; o upsert da pipeline nunca escreve nas colunas que pertencem a outro sistema                                                                                                                                                                      | ✅     | `omie-elt-pipeline/src/db/protectedColumns.ts:71` (`protectedColumnsFor`). Ver [[Colunas-Protegidas]]                                                                                                                                                                          |
| 5   | **Sem FK entre entidades sincronizadas de forma independente.** A liberação do pedido e o status por item apontam para o pedido por chave lógica, sem FK                                                                                                                                           | ✅     | Dump Avhub: `core_vendas_faturamento.pedidos_vendas_liberacao` (linha 18285) e `itens_pedido_status` (16990) só têm FK para `core.unidades` e `auth.usuarios`; o MES não tem FK para o av-hub (bancos separados)                                                               |
| 6   | **Nenhum estado é beco sem saída.** Reprovou, divergiu, devolveu: há sempre um caminho de volta. Reserva não expira e só sai por liberação explícita                                                                                                                                               | 📝 🟡 | Registro de decisões; o "novo norte" (`P6`) está decidido e sem código 🔴. Ver [[Estados-e-Status]]                                                                                                                                                                            |
| 7   | **Lote nasce em quarentena** (`PENDENTE`) e só libera com laudo e aprovação da Qualidade. A carga inicial é a exceção: nasce `LIBERADO`                                                                                                                                                            | ✅     | `api-pcp/src/compras/compras.service.ts:541-557` (lote `PENDENTE` com `ENTRADA`); `qualidade.service.ts:82-99` (aprovar libera)                                                                                                                                                |
| 8   | **Segregação de função.** Quem conferiu o recebimento não faz a recontagem (outra pessoa). Aprovar ou cancelar OC exige `pode_aprovar` na tela `compras`                                                                                                                                           | ✅     | `api-pcp/src/compras/recebimento.service.ts:254-256`; `api-acos-vital/src/schemas/core_vendas_faturamento/tables/ordens_compra/ordens_compra.route.js:36,1211` ([[RBAC-e-Permissoes]]). A regra v1 "comprador diferente do aprovador" não foi achada no código ❓               |
| 9   | **Schemas.** MES: tudo no schema `public`. av-hub: um schema por domínio (`auth`, `core`, `core_vendas_faturamento`, `core_fluxo`, `core_comissionamento`, `core_compras`, `core_estoque` vazio, `core_organograma`, `core_aprovacao_de_vagas`, `core_mapas`, `historico`, `omie_ctl`, `omie_raw`) | 📝 ✅  | Dump MES (sem `CREATE SCHEMA` além de `public`); Dump Avhub linhas 113-242. Ver [[Schemas-Postgres]]                                                                                                                                                                           |
| 10  | **Todo item, fabricado ou comprado, passa pelo Estoque** (vira lote e saldo) e o despacho é feito pelo Estoque com documento de retirada                                                                                                                                                           | 📝 🔴 | Código ainda baixa na Embalagem (`itens-parciais.service.ts:279-285`) e fabricado não vira lote (`estoque.prisma:17-20`, `OrigemLote` só tem `RECEBIMENTO` e `CARGA_INICIAL`)                                                                                                  |
| 11  | **Aprovação da OC:** a OC que excede R$ 30 mil é aprovada pelo Gerente de Compras; até R$ 30 mil os compradores ficam livres. A Diretoria não aprova. Regra provisória: endurece depois da conversa com Compras 🟡                                                                                  | 📝 ✅  | N14-21 em [[Registro-de-Decisoes]]. O limite é parâmetro por unidade (`limite_aprovacao`, padrão `30000.00`: `condicoes_pagamento_compras.route.js:17`); a trigger `fn_ordens_compra_recalcular` aprova até o limite e a API exige `pode_aprovar` acima dele (`ordens_compra.route.js:1230-1240`). Ver [[04-Circuito-de-Compra]] |
| 12  | **Recebimento confere contra a NF** (chave de 44 dígitos), não contra o pedido de venda                                                                                                                                                                                                            | ✅     | `compras.service.ts` (`chegada` exige NF); `app-pcp` tela `/logistica/logistica-entrada`                                                                                                                                                                                       |

## O que existe × o que falta, por raia

| Raia | Existe no código | Falta (dono) |
|---|---|---|
| Vendas (`V1`-`V3`) | Liberação pelo vendedor e histórico; cartão "Etapa dos itens" ✅ | Reabrir marcação, alerta de pedido parado, L3 de `auth.rotas_telas` (Gustavo, Nathan) 🔴 |
| PCP (`P1`, `P2`, `P6`) | Triagem e Destinação, confirmação de importação ✅ | Novo norte (`P6`, RoteiroItem C8, Robert) 🔴; renomear rota e slug `carteira` e `ordens-producao` (Robert, Nathan) 🔴 |
| Estoque (`E1`-`E6`) | Atendimento, split, reserva, saldo, carga inicial, custo de lote só na carga ✅ | Documento de retirada e baixa na retirada (`E6`, Robert); despacho à produção com baixa de matéria-prima (Robert); `GET /itens/custo` (Robert) 🔴 |
| Compras (`P3`, `C0`-`C5`) | Requisição, cotação, aprovação, OC, envio ao Omie, follow-up, Compras · CCP no MES ✅ | o MES ler a OC do hub (C0: OC do pedido, saldo futuro, entrada no Recebimento; Robert, Gustavo); recompra por RNC sem contrato (Nathan) 🔴; perfil CCP e vínculo à Gerência de Compras: cadastro simples, em breve (Nathan, Gustavo) |
| Recebimento (`R0`-`R6`) | Esperados, chegada com NF, conferência, recontagem, decisão, lote em quarentena ✅ | Custo da OC no lote (contrato 004 sem job no MES, Robert); reabertura de divergência de produção (Robert) 🔴 |
| Qualidade (`Q1`-`Q4`, `Q7`, `Q8`) | Inspeção de entrada por lote, RNC, cisão e quarentena; inspeção de saída ✅ | `Q8` "sim" volta ao Estoque (Robert); inspeção de saída nunca conferida em campo ❓ |
| Produção (`F1`) | Roteiro, filas, ItemParcial ✅ | Consumo de matéria-prima J2/J3 (Robert) 🔴 |
| Expedição (`X1`-`X4`) | Embalagem, paletes, comprovante de entrega ✅ | Consolidação de carga, transporte (Robert); integral travado por item que não chega (T-06) 🔴 |
| Fiscal (`O1`, `O2`) | Omie emite e baixa; pipeline lê `ListarNF` ✅ | Sinalização do MES ao Omie (`11.1`, Nathan, Robert) 🔴 |

O detalhe de cada linha está na nota da raia, em "O que falta desenvolver". A lista por dono está em [[Backlog-por-Frente]] e [[Pontas-Soltas]].

## O que fica fora da espinha

Comissões, RH (vagas e funcionários), dashboards, orçamento, pedido manual, acompanhamento de clientes, Comercial & Suprimentos e transferência entre filiais ficam em notas curtas de anexo: [[Home|Indice-do-Anexo]].

## Datas

Ciclo 1 até 24/02/2027 (era 21/01; N14-30); Ciclo 2 a partir de 25/02/2027; marco zero do saldo em 13/11/2026. Plano completo em [[Cronograma]].
