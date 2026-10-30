---
tags: [projeto, visao, erp, principios]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [v1 00-Indice/Comece-Aqui §5, v1 Decisoes-Chave-ERP, decisões do Nathan de 14/10/2026, código de 14/10 (api-pcp 579a625, app-pcp 1fca8d3, api-acos-vital f322dcd, HUB b55ac55, omie-elt-pipeline 0f739f0), dumps de esquema de 14/10 e de 29/10, conferência de 29/10 na `develop` do MES (befd973) e da API (f2fa237)]
---

# Visão do projeto

**Em uma frase:** o projeto cria o ERP (sistema de gestão) que acompanha cada pedido de venda da Aços Vital de 0 a 100%, da proposta à nota fiscal.

**Quando consultar esta nota:** quando você quiser entender o projeto inteiro em poucos minutos, ou conferir as regras que valem para todos os setores.

## O que é o ERP

O ERP acompanha **um pedido de venda de 0 a 100%**. O pedido nasce no Omie e termina na nota fiscal que o Omie emite. No meio passam estas etapas:

- liberação pelo vendedor;
- triagem e destinação do PCP (planejamento e controle da produção);
- atendimento pelo Estoque;
- compra, recebimento e qualidade;
- produção, expedição e baixa.

O desenho de referência é o diagrama 0b, em [[00-Fluxo-Mestre-0b]]. Este vault é o manual para desenvolvê-lo.

O ERP reúne quatro sistemas que se falam por contratos (mais a `api-comercial`, que ficou só como legado de leitura). Detalhe em [[Sistemas-e-Responsabilidades]].

| Sistema | Para que serve | Onde |
|---|---|---|
| **Omie** (externo) | ERP fiscal. Emite a nota fiscal e guarda pedidos, produtos e parceiros | SaaS (serviço na nuvem) |
| **av-hub** | Portal comercial e de compras. Tem o HUB (as telas, em Next.js) e a `api-acos-vital` (API do Hub, que também abriga o módulo comercial). A `api-comercial` do Pablo é só legado de consulta (N16-117) | [[AV-Hub-Front]], [[AV-Hub-API]], [[API-Comercial]] |
| **MES** | O sistema do chão de fábrica, do Estoque, do Recebimento e da Qualidade. Tem o `api-pcp` (back) e o `app-pcp` (front) | [[MES-Backend]], [[MES-Front]] |
| **Pipeline Omie** | Copia os dados do Omie para o banco do av-hub e envia a ordem de compra ao Omie | [[Pipeline-Omie]] |

## O pedido de 0 a 100% em 12 passos

Os IDs entre parênteses são os nós do [[00-Fluxo-Mestre-0b]].

1. **O pedido nasce no Omie** e chega travado ao av-hub pela pipeline (`V1`) ✅.
2. **O vendedor libera o pedido.** Ele marca se a Qualidade acompanha desde o início (`V2`, `V3`) ✅. Nota: [[01-Vendas-Liberacao]].
3. **PCP, Triagem do Pedido.** A tela lista só os pedidos liberados (`P1`) ✅.
4. **PCP, Destinação do Pedido.** O PCP define o destino de cada item (`FABRICACAO` ou `REVENDA`) e a quantidade. O backend insere o Estoque como etapa 1 e confirma a importação ao av-hub (`P2`) ✅. Nota: [[02-PCP-Triagem-e-Destinacao]].
5. **Estoque.** Confere o saldo na filial do pedido e atende o que puder (divide a parcial e reserva). Para o resto, pede compra ou envia à produção (`E1` a `E4`) ✅. Nota: [[03-Estoque-Atendimento-e-Despacho]].
6. **Compra, se faltou material.** O fluxo é requisição, cotação, aprovação, ordem de compra (OC), envio ao Omie e acompanhamento (`P3`, `C0` a `C5`) ✅. A requisição nasce no PCP (no MES) ou no Compras (no av-hub). O MES já lê as OCs do Hub (job K4, na `develop` desde 15/10); falta usar essa leitura para o PCP ver a OC do pedido e o Estoque ver o saldo futuro 📝 🔴 (N14-20, BL-049, BL-050). Nota: [[04-Circuito-de-Compra]].
7. **Recebimento.** A OC aprovada vira "esperada". A doca registra a chegada com a nota fiscal (NF), confere, pesa e cria o lote em quarentena (`R0` a `R4`, `R6`) ✅. Nota: [[05-Recebimento]].
8. **Qualidade de entrada.** Inspeciona por lote. O aprovado vira saldo no Estoque. O reprovado abre uma RNC, o relatório de não conformidade (`Q1` a `Q4`, `E5`) ✅. Nota: [[06-Qualidade-Entrada]].
9. **Produção.** O que o Estoque envia à produção passa pelos setores do roteiro (`F1`) ✅. Nota: [[07-Producao-e-Roteiro]].
10. **Qualidade de saída.** Inspeciona no roteiro. O aprovado deve voltar ao Estoque. O reprovado vai ao PCP (`Q7`, `Q8`, `P6`) 🟡. Nota: [[08-Qualidade-Saida]].
11. **Despacho e Expedição.** O Estoque despacha com um **documento de retirada** e baixa o saldo na retirada (`E6`): decidido em 29/10 (N16-120 a N16-122), sem código 🔴. A Expedição embala, paletiza, consolida a carga e cuida do transporte (`X1` a `X4`) 🟡. Notas: [[03-Estoque-Atendimento-e-Despacho]], [[09-Expedicao]].
12. **Fiscal.** O Omie emite a nota e baixa o item no pedido (`O1`, `O2`) ✅ no lado do Omie. O MES ainda não avisa o Omie 🔴. Nota: [[10-Fiscal-Omie]].

Três acompanhamentos correm em paralelo: o **status por item** (cartão "Etapa dos itens" no HUB), a **Torre de Fluxo** e o **custo do lote**. Ver [[Rastreabilidade-e-Torre-de-Fluxo]] e [[Modelo-Estoque-e-Custo-do-Lote]].

## Regras que valem para todo o projeto

Cada regra tem o selo de confiança. A evidência de cada uma está em "Detalhe técnico".

1. **O sistema nunca emite nem edita nota fiscal.** Só o Omie emite. O sistema avisa e faz referência 📝 ✅.
2. **O av-hub decide e o MES executa.** Pedido, OC e liberação nascem no av-hub. Produção, recebimento e saldo ficam no MES. A devolução de cliente é a exceção: é decidida no Estoque 📝.
3. **Os sistemas conversam só por consulta periódica (polling), mais o `PUT` do contrato 34.** Não há webhook nem tempo real ✅.
4. **Cada coluna tem um dono.** O carregamento da pipeline nunca escreve em colunas de outro sistema ✅.
5. **Sem FK (vínculo rígido de banco) entre dados que sincronizam sozinhos.** A liberação do pedido e o status por item apontam para o pedido por chave lógica ✅.
6. **Nenhum estado é beco sem saída.** Se algo reprova, diverge ou volta, sempre há caminho de retorno. A reserva não expira e só sai por liberação explícita 📝 🟡. O "novo norte" (`P6`) está decidido e sem código 🔴.
7. **O lote nasce em quarentena** (`PENDENTE`) e só libera com laudo e aprovação da Qualidade. A carga inicial é a exceção: nasce `LIBERADO` ✅.
8. **Segregação de função.** Quem conferiu o recebimento não faz a recontagem. Aprovar ou cancelar OC exige a permissão `pode_aprovar` ✅. A regra antiga "comprador diferente do aprovador" não foi achada no código ❓.
9. **Cada banco tem seu esquema de schemas.** O MES usa só o `public`. O av-hub usa um schema por domínio 📝 ✅. Ver [[Schemas-Postgres]].
10. **Todo item passa pelo Estoque**, seja fabricado ou comprado. Ele vira lote e saldo, e o despacho sai do Estoque com documento de retirada 📝. O fabricado aprovado na inspeção de saída já vira lote de origem `PRODUCAO` na `develop` do MES (LOG-53, 27/10) ✅; o documento de retirada e a baixa na retirada ainda não existem 🔴.
11. **Aprovação da OC.** A OC acima de R$ 30 mil é aprovada pelo Gerente de Compras. Até R$ 30 mil, os compradores ficam livres. A Diretoria não aprova. A regra é provisória e endurece depois da conversa com Compras 🟡 📝 ✅ (N14-21 em [[Registro-de-Decisoes]]). Ver [[04-Circuito-de-Compra]].
12. **O recebimento confere contra a NF** (chave de 44 dígitos), não contra o pedido de venda ✅.

## O que existe e o que falta

O quadro por setor, em linguagem simples, está em [[Onde-Estamos]]. A lista por dono está em [[Backlog-por-Frente]] e [[Pontas-Soltas]]. O detalhe de cada setor está na nota dele, em "O que falta desenvolver".

## O que fica fora do fluxo principal

Ficam em notas curtas de anexo: comissões, RH (vagas e funcionários), dashboards, orçamento, pedido manual, acompanhamento de clientes, Comercial & Suprimentos e transferência entre filiais. Índice: [[Home|Indice-do-Anexo]].

## Datas

- **Ciclo 1** vai até 18/02/2027. Era 21/01; mudou por N14-30 e N14-32 (com BL-007, BL-049 e BL-050 (N16-145): 36,1 pd e 03/03/2027 a 75% de foco; o Robert valida).
- **Ciclo 2** começa em 19/02/2027.
- **Marco zero do saldo:** 13/11/2026.

Plano completo em [[Cronograma]].

## Detalhe técnico

### Evidência de cada regra

| # | Regra (resumo) | Selo | Evidência |
|---|---|---|---|
| 1 | O sistema nunca emite nem edita nota fiscal; só o Omie emite | 📝 ✅ | A única escrita da pipeline no Omie é a OC: `omie-elt-pipeline/src/jobs/envioOrdensCompra.ts` (`UpsertPedCompra`/`ExcluirPedCompra`); nenhuma chamada de emissão de NF |
| 2 | av-hub decide, MES executa. Exceção: devolução de cliente é decidida no Estoque | 📝 | v1 Decisoes-Chave-ERP, DEC-10 |
| 3 | Só polling entre sistemas, mais o `PUT` do contrato 34. O MES empurra a requisição (`PUT /compras/requisicoes/origem/{id_origem}`) e lê eventos, status e liberações por polling | ✅ | `api-pcp/src/integracao-avhub/envio-avhub.service.ts` (PUT com fila e retentativa); `api-pcp/src/integracao-avhub/eventos-avhub.service.ts` (polling de 5 min). Contratos [[LOG-34-Requisicoes-MES-Empurra-para-o-Hub]], [[LOG-35-Compras-Marcos-Requisicao-para-MES]] |
| 4 | Colunas protegidas: o upsert da pipeline nunca escreve nas colunas de outro sistema | ✅ | `omie-elt-pipeline/src/db/protectedColumns.ts` (`protectedColumnsFor`). Ver [[Colunas-Protegidas]] |
| 5 | Sem FK entre entidades sincronizadas de forma independente | ✅ | Dump Avhub: `core_vendas_faturamento.pedidos_vendas_liberacao` (linha 18285) e `itens_pedido_status` (16990) só têm FK para `core.unidades` e `auth.usuarios`; o MES não tem FK para o av-hub (bancos separados) |
| 6 | Nenhum estado é beco sem saída. Reserva não expira e só sai por liberação explícita | 📝 🟡 | Registro de decisões; o "novo norte" (`P6`) está decidido e sem código 🔴. Ver [[Estados-e-Status]] |
| 7 | Lote nasce em quarentena (`PENDENTE`); carga inicial nasce `LIBERADO` | ✅ | `api-pcp/src/compras/compras.service.ts` e `recebimento.service.ts` (lote `PENDENTE` com `ENTRADA`); `qualidade.service.ts` (aprovar libera) |
| 8 | Segregação de função: quem conferiu não faz a recontagem; aprovar ou cancelar OC exige `pode_aprovar` na tela `compras` | ✅ | `api-pcp/src/compras/recebimento.service.ts`; `api-acos-vital/src/schemas/core_vendas_faturamento/tables/ordens_compra/ordens_compra.route.js` (contrato 22, B9; [[RBAC-e-Permissoes]]). A regra v1 "comprador diferente do aprovador" não foi achada no código ❓ |
| 9 | Schemas. MES: tudo no `public`. av-hub: `auth`, `core`, `core_vendas_faturamento`, `core_fluxo`, `core_comissionamento`, `core_compras`, `core_estoque` (vazio), `core_organograma`, `core_aprovacao_de_vagas`, `core_mapas`, `historico`, `omie_ctl`, `omie_raw` | 📝 ✅ | Dump MES (sem `CREATE SCHEMA` além de `public`); Dump Avhub linhas 113-242. Ver [[Schemas-Postgres]] |
| 10 | Todo item, fabricado ou comprado, passa pelo Estoque; despacho com documento de retirada | 📝 🔴 | Código ainda baixa na Embalagem (`itens-parciais.service.ts`, nota [[03-Estoque-Atendimento-e-Despacho]]) e não há documento de retirada. O fabricado já vira lote na `develop` (`OrigemLote.PRODUCAO` em `estoque.prisma`, LOG-53); na `main` do MES só existem `RECEBIMENTO` e `CARGA_INICIAL` |
| 11 | Aprovação da OC: acima de R$ 30 mil, Gerente de Compras; até R$ 30 mil, compradores livres; a Diretoria não aprova. Regra provisória | 📝 ✅ | N14-21 em [[Registro-de-Decisoes]]. O limite é parâmetro por unidade (`limite_aprovacao`, padrão `30000.00`: `condicoes_pagamento_compras.route.js`); a trigger `fn_ordens_compra_recalcular` aprova até o limite e a API exige `pode_aprovar` acima dele (`ordens_compra.route.js`). Quem emite pode ser o próprio Gerente que aprova, como o código faz hoje (N16-123) |
| 12 | Recebimento confere contra a NF (chave de 44 dígitos), não contra o pedido de venda | ✅ | `compras.service.ts` (`chegada` exige NF); `app-pcp` tela `/logistica/logistica-entrada` |

### Existe × falta, por raia

| Raia | Existe no código | Falta (dono) |
|---|---|---|
| Vendas (`V1`-`V3`) | Liberação pelo vendedor e histórico; cartão "Etapa dos itens" ✅ | Reabrir marcação, alerta de pedido parado, L3 de `auth.rotas_telas` (Gustavo, Nathan) 🔴 |
| PCP (`P1`, `P2`, `P6`) | Triagem e Destinação, confirmação de importação ✅ | Novo norte (`P6`, RoteiroItem C8, Robert) 🔴; renomear rota e slug `carteira` e `ordens-producao` (Robert, Nathan) 🔴 |
| Estoque (`E1`-`E6`) | Atendimento, split, reserva, saldo, carga inicial, custo do lote (carga inicial, Recebimento e à mão) e `GET /itens/custo`, estes na `develop` ✅ | Documento de retirada e baixa na retirada (`E6`, N16-120 a N16-122, Robert); baixa de matéria-prima pela retirada (N16-140, Robert); subir a `develop` para a `main` (BL-035) 🔴 |
| Compras (`P3`, `C0`-`C5`) | Requisição, cotação, aprovação, OC, envio ao Omie, follow-up, Compras · CCP no MES; o MES lê a OC do hub (K4, `develop`) ✅ | usar a OC no MES (C0: OC do pedido para o PCP, saldo futuro do Estoque; Robert, BL-049, BL-050); recompra por RNC sem contrato (N16-127, Nathan) 🔴; perfil CCP e vínculo à Gerência de Compras: cadastro simples, em breve (Nathan, Gustavo) |
| Recebimento (`R0`-`R6`) | Esperados, chegada com NF, conferência, recontagem, decisão, lote em quarentena; custo da OC no lote e recebimento por item da OC na `develop` ✅ | Testar o recebimento por OC em homologação e o rateio da chegada (BL-051, Robert); reabertura de divergência de produção (Robert) 🔴 |
| Qualidade (`Q1`-`Q4`, `Q7`, `Q8`) | Inspeção de entrada por lote, RNC, cisão e quarentena; inspeção de saída ✅ | `Q8` "sim" volta ao Estoque (Robert); inspeção de saída nunca conferida em campo ❓ |
| Produção (`F1`) | Roteiro, filas, ItemParcial ✅ | Consumo de matéria-prima J2/J3 (Robert) 🔴 |
| Expedição (`X1`-`X4`) | Embalagem, paletes, comprovante de entrega ✅ | Consolidação de carga, transporte (Robert); integral travado por item que não chega (T-06) 🔴 |
| Fiscal (`O1`, `O2`) | Omie emite e baixa; pipeline lê `ListarNF` ✅ | Sinalização do MES ao Omie (`11.1`, Nathan, Robert) 🔴 |
