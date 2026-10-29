---
tags: [contratos, painel, indice]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [LOG-51 e LOG-52 (auditoria de 15/10/2026), 06-Contratos/Ativos, 06-Contratos/Entregues, 06-Contratos/Arquivados, plano de 14/10/2026, código de 14/10 (api-pcp 579a625, app-pcp 1fca8d3, api-acos-vital f322dcd, omie-elt-pipeline 0f739f0)]
---

# Painel de contratos

Uma linha por contrato. O **estado atual** de cada um está no bloco "Situação em 14/10/2026" no topo da própria nota; este painel só resume. Regras de pasta e status em [[Regras-do-Vault]]. Os nós do fluxo (`V1`, `P2`, `E6`…) são os de [[00-Fluxo-Mestre-0b]].

Quando nascer um contrato novo, ele entra **completo** em `06-Contratos/` (nunca só resumo e link) e ganha uma linha aqui.

## Resumo

| Pasta | Contratos (.md) | Anexos (.sql, .patch) | Total de arquivos |
|---|---|---|---|
| `Ativos` (a fazer ou parcial) | 14 | 6 | 20 |
| `Entregues` (feito no código ou aplicado) | 65 | 12 | 77 |
| `Arquivados` (superado, fora de escopo ou histórico) | 11 | 0 | 11 |
| **Total** | **90** | **18** | **108** |

| Status | Contratos |
|---|---|
| `proposta` | 2 |
| `para-implementar` | 0 |
| `parcial` | 13 |
| `implementado-no-codigo` | 46 |
| `aplicado-em-producao` | 18 |
| `arquivado` | 11 |

Vocabulário de status: `proposta` (ainda sem decisão), `para-implementar` (decidido, falta código), `parcial` (parte no código, parte não), `implementado-no-codigo` (conferido no código de 14/10), `aplicado-em-producao` (aplicado no banco, confirmado por dump; produção não reconferida em 14/10 ❓), `arquivado` (superado, rejeitado, fora de escopo ou histórico, com o motivo na nota).

## Consultas abertas (tipo `CON`)

Contrato que pede uma resposta de negócio a quem conhece o assunto, com contexto, cenário e perguntas; a resposta volta pelo WhatsApp do Nathan. Modelo em [[Modelo-de-Consulta]].

| ID | Assunto | Para quem | Prazo | Status | Bloqueia |
|---|---|---|---|---|---|
| [[CON-01-Relatorios-Valores-e-Faturamento-Itens-28-e-29\|CON-01]] | Relatórios de valores por vendedor e de faturamento mensal (itens 28 e 29 do PCP legado) | quem gera e quem lê os relatórios | 20/10/2026 | aguardando-resposta | itens 28 e 29, sem dono e sem data |
| [[CON-02-Rastreabilidade-e-Book-Itens-18-e-20\|CON-02]] | Rastreabilidade por material e ciclo do Book (Caldeiraria HRM, itens 18 e 20) | Qualidade da HRM, quem acompanha o Book, Robert | 20/10/2026 | aguardando-resposta | PS-027, marco M10 |

## Todos os contratos

**Coluna "Onde atua"** (também no campo `sistemas:` e na linha "Onde atua" de cada contrato): quais sistemas o contrato mexe. **av-hub** = banco, API (`api-acos-vital`) e front (HUB, com o BFF); **MES** = banco, API (`api-pcp`) e front (`app-pcp`); **pipeline Omie** = `omie-elt-pipeline`; **consulta** = pede resposta de negócio, sem código. Contrato com av-hub **e** MES é integração: os dois lados têm de entregar para funcionar.

| ID | Alias | Contrato | Status | Onde atua | Pasta | Nós do 0b | Robert (MES e, desde 28/10, rotas do comercial) | Gustavo (DBA) | Nathan (front) | Pablo (Comercial, acompanha desde 28/10) |
|---|---|---|---|---|---|---|---|---|---|---|
| SQL-001 | Contrato SQL 006 do omie-elt-pipeline | [[SQL-001-Parceiros-Dados-Fiscais\|`core.parceiros`: dados fiscais e 2 tabelas novas]] | `aplicado-em-producao` | av-hub: banco · pipeline Omie | Entregues | V1 | — | — | — | — |
| SQL-002 | Contrato SQL 007 do omie-elt-pipeline | [[SQL-002-Estoque-Saldo\|`core.estoque_saldo`]] | `aplicado-em-producao` | av-hub: banco · pipeline Omie | Entregues | — | — | — | — | — |
| SQL-003 | Contrato SQL 008 do omie-elt-pipeline | [[SQL-003-Pedidos-Vendas-Frete-Parcelas\|`pedidos_vendas` (desconto) e tabelas de frete e parcelas]] | `aplicado-em-producao` | av-hub: banco · pipeline Omie | Entregues | V1 | — | — | — | — |
| SQL-004 | Contrato SQL 009 do omie-elt-pipeline | [[SQL-004-Pedidos-Compras\|`pedidos_compras` e itens]] | `aplicado-em-producao` | av-hub: banco · pipeline Omie | Entregues | C4 | — | — | — | — |
| SQL-005 | Contrato SQL 010 do omie-elt-pipeline | [[SQL-005-Locais-Estoque\|`core.locais_estoque`]] | `aplicado-em-producao` | av-hub: banco · pipeline Omie | Entregues | — | — | — (respondida: sem FK entre bancos) | — | — |
| SQL-006 | — | [[SQL-006-Pedidos-Vendas-Valor-Devolucao\|`pedidos_vendas.valor_devolucao` (invalidado)]] | `arquivado` | av-hub: banco | Arquivados | — | — | — | — | — |
| SQL-007 | Contrato SQL 007 | [[SQL-007-Ordens-Compra-Estruturada\|`ordens_compra`, itens e parcelas]] | `aplicado-em-producao` | av-hub: banco | Entregues | C4 | — | — | — | — |
| SQL-008 | Contrato SQL 008 | [[SQL-008-Requisicoes-Compra\|`requisicoes_compra`]] | `aplicado-em-producao` | av-hub: banco | Entregues | P3, C0 | — | — | — | — |
| SQL-009 | — | [[SQL-009-Categoria-Sem-Escopo-Empresa-Views\|`core.categorias` sem `codigo_empresa` no JOIN de 4 views]] | `aplicado-em-producao` | av-hub: banco | Entregues | — | — | — (respondido: não é divergência) | — | — |
| SQL-010 | Contrato SQL 010 | [[SQL-010-Itens-Pedido-Status\|`itens_pedido_status`]] | `implementado-no-codigo` | av-hub: banco | Entregues | F1, X1, Q7 | — | — | — | — |
| SQL-011 | Contrato SQL 011 | [[SQL-011-Ordens-Compra-Referencia-MES\|`vw_ordens_compra_referencia_mes` e marca por trigger (migration `api004`)]] | `implementado-no-codigo` | av-hub: banco | Entregues | R0 | — | — | — | — |
| SQL-012 | Contrato SQL 012 | [[SQL-012-Ordens-Compra-Referencia-Valores\|Valores da OC na `vw_ordens_compra_referencia_mes`]] | `implementado-no-codigo` | av-hub: banco | Entregues | R0, R4 | — | — | — | — |
| SQL-013 | Contrato SQL 013 | [[SQL-013-Produtos-Provaveis-Duplicatas-Funcoes-e-Uso\|Produtos: prováveis duplicatas (normalização, pares por semelhança e uso)]] | `aplicado-em-producao` | av-hub: banco | Entregues | — | — | Gustavo: informar os ajustes feitos no script | — | — |
| SQL-014 | Contrato SQL 014 | [[SQL-014-Pedido-Encerrado-por-Saldo-Zerado\|Pedido encerrado por saldo zerado ("Faturado, encerrado") e encerrado em atraso]] | `aplicado-em-producao` | av-hub: banco | Entregues | — | — | — | — | — |
| SQL-015 | Contrato SQL 015 | [[SQL-015-Carteira-do-PCP-Totais-por-Vendedor-e-Desvio\|Carteira do PCP: totais, por vendedor e desvio de previsão]] | `aplicado-em-producao` | av-hub: banco, API, front | Entregues | — | — | ✅ banco e API terminados (Gustavo, 29/10) | Nathan: testar `PUT .../marcacao` (marcar e desmarcar) | — |
| API-001 | — | [[API-001-Produtos-Parceiros-Filtro-Incremental\|Filtro incremental `alterado_desde` em produtos e parceiros]] | `implementado-no-codigo` | av-hub: API · pipeline Omie | Entregues | — | — | — (`alterado_desde` corrigido, informado 26/10) | — | — |
| API-002 | — | [[API-002-Material-Alias-Omie-MES\|Alias de material Omie no MES (rejeitado)]] | `arquivado` | MES: API | Arquivados | — | — | — | — | — |
| API-003 | — | [[API-003-Requisicao-Compra-Integracao-MES\|Requisição de compra MES → av-hub (versão polling)]] | `arquivado` | av-hub: API · MES: API | Arquivados | P3 | — | — | — | — |
| API-004 | Contrato 004 | [[API-004-Referencia-OC-Integracao-MES\|Referência da OC (av-hub → MES)]] | `parcial` | av-hub: banco, API · MES: API | Ativos | C4, R0, R4 | K4 (job de leitura e projeção da OC) já na `develop` do `api-pcp` (PR #59); falta OC do pedido para o PCP e saldo futuro do Estoque (N14-20, BL-049, BL-050) e BL-051 | — | — | — |
| API-005 | Contrato 005 | [[API-005-Status-Item-Integracao-MES\|Status por item (MES → av-hub), lado do MES]] | `implementado-no-codigo` | av-hub: API · MES: API | Entregues | F1, X1, Q7 | — | — | — | — |
| API-006 | Contrato 006 | [[API-006-Status-por-Item-Leitura-no-Hub\|Status por item: leitura no hub (job e rota)]] | `implementado-no-codigo` | av-hub: API, front · MES: API | Entregues | F1, X1, Q7 | — | — | — | — |
| API-007 | Contrato 007 (API) | [[API-007-Referencia-OC-Valores-no-MES\|Valores da OC na referência (hub → MES) e projeção no MES]] | `parcial` | av-hub: banco, API · MES: API | Ativos | C4, R4 | Job e projeção com valores já no K4 (PR #59); falta gravar o custo da OC no lote (K5, R4) | — | — | — |
| API-008 | Contrato 008 | [[API-008-Custo-do-Lote-no-MES\|Custo do lote no MES (`lote_custo`, G1, recebimento, consumo, `GET /itens/custo`)]] | `parcial` | av-hub: API · MES: API | Ativos | R4, E3, E5 | §3 custo da OC no Recebimento, rota MANUAL, §4 snapshot na SAIDA, §5 `GET /itens/custo`; cenários com e sem imposto: desenho decidido em 29/10 (N16-144); contrato só quando o desenvolvimento começar (contrato não editado) | — | — | — |
| API-009 | Contrato 009 | [[API-009-Referencia-Requisicao-Hub-Integracao-MES\|Referência da requisição do Compras com pedido de venda (av-hub → MES)]] | `parcial` | av-hub: banco, API · MES: API, front | Ativos | C0, P1, P2, P3, E1 | Job de leitura junto do da referência da OC, projeção, tela do PCP e aviso de compra duplicada (BL-065) | Gustavo: responder Q1 a Q4 (migration `api009` em produção desde 20/10) | Nathan: campo "Pedido de venda" na "Nova requisição" (BL-041); decidir Q5 | — |
| API-010 | Contrato 010 | [[API-010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto\|Requisição do Compras: finalidade, pedido de venda e produto do cadastro]] | `parcial` | av-hub: banco, API, front | Ativos | C0 | — | Gustavo: responder Q1 e Q4 (migration `api010` em produção desde 20/10) | Nathan: tela nova pronta (PR #209); a OC herda a finalidade; decidir Q2 e Q3 | — |
| API-011 | Contrato 011 | [[API-011-Compra-em-Andamento-Recebimento-por-Item-da-OC-e-Uso-Interno\|Compra em andamento, recebimento por item da OC e uso interno (MES)]] | `parcial` | MES: banco, API, front | Ativos | P1, P2, P3, E1, R0, R1, R4 | Teste em homologação, rateio da chegada (Q2), saldo futuro (BL-050) e OC visível ao PCP (BL-049); o resto está na `develop` do MES | ✅ Gustavo: API-009 e API-010 (29/10) | Nathan: Q3 (contabilidade e EPI) e Q5 (BL-049 e BL-050 no Ciclo 1) | — |
| API-012 | Contrato 012 | [[API-012-Produtos-Provaveis-Duplicatas-Rota-e-Tela\|Produtos: prováveis duplicatas (rota `GET /produtos/duplicatas` e nova tela)]] | `implementado-no-codigo` | av-hub: banco, API, front | Entregues | — | — | Gustavo: rota `GET /produtos/duplicatas` antes de `/:id` e cache de 60 s | Nathan: BFF, serviço sem varredura e tela nova | — |
| API-013 | Contrato 013 | [[API-013-Acompanhamento-de-Clientes-So-Cliente-e-Periodo-Total\|Acompanhamento de clientes: só clientes (tag) e período total]] | `aplicado-em-producao` | av-hub: API, front | Entregues | — | — | — | — | — |
| API-014 | Contrato 014 | [[API-014-Setor-do-Cliente-e-do-Grupo-no-Acompanhamento-de-Clientes\|Setor do cliente e do grupo no Acompanhamento de clientes]] | `aplicado-em-producao` | av-hub: banco, API, front | Entregues | — | — | ✅ banco e API terminados (Gustavo, 29/10) | Nathan: testar salvar 2 setores, filtro e Excel; definir perfis e o lote | — |
| API-016 | Contrato 016 | [[API-016-Observacao-do-PCP-por-Item-do-Pedido\|Observação do PCP por item (produto) do pedido, no lugar de por parcial]] | `aplicado-em-producao` | av-hub: banco, API, front | Entregues | — | — | — | — | — |
| API-017 | Contrato 017 | [[API-017-Carteira-do-PCP-por-Periodo-e-Previsao-de-Faturamento-por-Mes\|Carteira do PCP por período do seletor e previsão de faturamento por mês]] | `aplicado-em-producao` | av-hub: banco, API, front | Entregues | — | — | — | — | — |
| API-018 | Contrato 018 | [[API-018-Carteira-do-PCP-Vencem-Hoje-e-Atrasados-Conferidos\|Carteira do PCP: "vencem hoje" em valor e atrasados conferidos com a lista]] | `aplicado-em-producao` | av-hub: banco, API, front | Entregues | — | — | — (feito, conferido em 26/10) | — | — |
| LOG-53 | Contrato 53 | [[LOG-53-Ordem-de-Producao-e-Lote-do-Fabricado\|Ordem de Produção e lote do fabricado (MES)]] | `proposta` | MES: banco, API, front | Ativos | P2, F1, Q7, Q8, E5 | Entidade e PDF da OP, lote `PRODUCAO` por OP e produto, aprovado volta ao Estoque (BL-052, BL-008) | — | Nathan: Q4 (HRM) e conteúdo do PDF | — |
| LOG-55 | Contrato 55 | [[LOG-55-Compras-Excluir-Requisicao\|Compras: excluir requisição de compra (exclusão lógica, só criada no Hub e sem OC)]] | `aplicado-em-producao` | av-hub: banco, API, front | Entregues | C0, C1 | — | — (feito: migration 055 e `DELETE`) | Nathan: Q2 (`pode_deletar` do Comprador); front feito e testado (23/10) | — |
| LOG-54 | Contrato 54 | [[LOG-54-Documento-de-Retirada-e-Baixa-na-Retirada\|Documento de retirada e baixa do saldo na retirada (MES)]] | `proposta` | MES: banco, API, front | Ativos | E6, X1, F1 | Modelo, rotas, telas e baixa na confirmação; tirar a baixa da Embalagem e da entrega (BL-007) | — | Nathan: Q1 e Q2 (quem gera, o que imprime, reserva) e Q3 (entra no Ciclo 1?) | — |
| LOG-01 | Contrato 01 | [[LOG-01-Compras-Fluxo-Completo\|Compras: requisição, ordem de compra e sincronização com o Omie]] | `implementado-no-codigo` | av-hub: banco, API | Entregues | C0, C1, C4 | — | — | — | — |
| LOG-02 | Contrato 02 | [[LOG-02-Funcionarios-Listagem-Filtros-Ordenacao-Resumo\|Funcionários: filtro, ordenação, paginação e resumo no servidor]] | `implementado-no-codigo` | av-hub: banco, API | Entregues | — | — | — | — | — |
| LOG-03 | Contrato 03 | [[LOG-03-Funcionarios-Cadastro-Organograma-Transacional\|Funcionários: salvar e excluir com o organograma numa operação]] | `implementado-no-codigo` | av-hub: banco, API | Entregues | — | — | — | — | — |
| LOG-04a | Contrato 04 (vagas) | [[LOG-04a-Vagas-Fila-Decisao-no-Banco\|Vagas: fila, decisão e permissões no banco]] | `implementado-no-codigo` | av-hub: banco | Entregues | — | — | — | — | — |
| LOG-04b | Contrato 05; 05 P6/P8 | [[LOG-04b-Pedidos-Notas-Dashboards-Agregacao-no-Banco\|Pedidos, notas e dashboards: agregação no banco]] | `implementado-no-codigo` | av-hub: banco, API | Entregues | — | — | — | Nathan: P6 no front (ver LOG-43) | — |
| LOG-05 | Contrato 05 (permissões) | [[LOG-05-Permissoes-e-Escopo-no-Banco\|Permissão, escopo e identidade aplicados no banco/backend]] | `implementado-no-codigo` | av-hub: banco | Entregues | — | — | — | — | — |
| LOG-06 | Contrato 06 | [[LOG-06-Ordenacao-Listagens\|Ordenação (`sort`/`order`) nas listagens]] | `implementado-no-codigo` | av-hub: API | Entregues | — | — | — | — | — |
| LOG-07a | — | [[LOG-07a-Dados-Orcamento-e-Coordenadores-no-Banco\|Orçamento e coordenadores no banco (v1, superado pelo LOG-42)]] | `arquivado` | av-hub: banco, API | Arquivados | — | — | — | — | — |
| LOG-07b | Contrato 07 (blacklist) | [[LOG-07b-Chave-Composta-Blacklist-Pedidos\|`blacklist_pedidos`: chave composta (número + empresa)]] | `implementado-no-codigo` | av-hub: API | Entregues | — | — | — | — | — |
| LOG-08 | Contrato 08 | [[LOG-08-Itens-por-Parcela-Pedidos\|Itens por parcela (`sequencial`) em `vw_pedido_venda_itens`]] | `implementado-no-codigo` | av-hub: banco | Entregues | — | — | — | — | — |
| LOG-09a | Contrato 09 (vendedores) | [[LOG-09a-Ordenacao-Sistema-Vendedores\|Ordenação da coluna "Sistema" em `GET /vendedores`]] | `implementado-no-codigo` | av-hub: API | Entregues | — | — | — | — | — |
| LOG-09b | Contrato 09 (paginação) | [[LOG-09b-Paginacao-por-Pedido-Vendas-Planilha\|Paginar `/vendas_planilha` por pedido]] | `implementado-no-codigo` | av-hub: API | Entregues | — | — | — | — | — |
| LOG-10 | Contrato 15 (numeração antiga) | [[LOG-10-Compras-Pendencias-Pos-Backend\|Compras: pendências depois do backend (C1 a C10)]] | `implementado-no-codigo` | av-hub: API | Entregues | C4 | — | — | — | — |
| LOG-11 | Contrato 20 (numeração antiga) | [[LOG-11-Compras-Cotacao-Moeda-PTAX\|Cotação de moeda automática (PTAX) na OC]] | `implementado-no-codigo` | av-hub: API | Entregues | C4 | — | — | — | — |
| LOG-12 | Contrato 21 (numeração antiga) | [[LOG-12-Compras-Projetos-Omie\|Projetos do Omie no av-hub]] | `implementado-no-codigo` | av-hub: API · pipeline Omie | Entregues | C4 | — | — | — | — |
| LOG-13a | Contrato 22 (numeração antiga) | [[LOG-13a-Compras-Backend-Consolidado\|Compras: backend consolidado (banco e API)]] | `implementado-no-codigo` | av-hub: API | Entregues | C0, C1, C4 | — | — | — | — |
| LOG-13b | Contrato 13 | [[LOG-13b-Fornecedores-por-Produto\|Fornecedores por produto (desconsiderado)]] | `arquivado` | av-hub: API | Arquivados | — | — | — | — | — |
| LOG-14a | Contrato 14 (Omie) | [[LOG-14a-Compras-Omie-Pedido-Compra\|Compras e Omie: puxar pedidos de compra e criar a OC]] | `implementado-no-codigo` | av-hub: banco · pipeline Omie | Entregues | C4 | — | — | — | — |
| LOG-14b | Contrato 14 (vínculo); Contrato 24 (numeração antiga) | [[LOG-14b-Compras-Vinculo-Pedido-Venda\|Compras: vínculo da OC com o pedido de venda]] | `implementado-no-codigo` | av-hub: banco, API | Entregues | C4, P3 | — | — | — | — |
| LOG-15 | Contrato 25 (numeração antiga) | [[LOG-15-Compras-Historico-Unificado\|Compras: histórico único (OC do av-hub e Omie)]] | `implementado-no-codigo` | av-hub: API | Entregues | C4 | — | — | — | — |
| LOG-16 | — | [[LOG-16-Compras-Pedido-DBA-Banco\|Pedido ao DBA de Compras (histórico)]] | `arquivado` | av-hub: banco | Arquivados | C0, C4 | — | — | — | — |
| LOG-17 | — | [[LOG-17-Compras-Pedido-API-Backend\|Pedido à API de Compras (histórico)]] | `arquivado` | av-hub: API | Arquivados | C0, C4 | — | — | — | — |
| LOG-18 | Contrato 16 (numeração antiga) | [[LOG-18-Compradores-Funcionario\|Compradores (Omie) ligados ao funcionário (RH)]] | `implementado-no-codigo` | av-hub: banco, API | Entregues | C4 | — | — | — | — |
| LOG-19a | — | [[LOG-19a-Compras-Pedido-Pipeline-Omie\|Pedido à pipeline de Compras (histórico)]] | `arquivado` | pipeline Omie | Arquivados | C4 | — | — | — | — |
| LOG-19b | Contrato 19 (Nomes); Contrato 27; Contrato 27 (numeração antiga) | [[LOG-19b-Compras-Pedido-Omie-Nomes\|Nomes no detalhe do pedido de compra do Omie]] | `implementado-no-codigo` | av-hub: API | Entregues | C4 | — | — | — | — |
| LOG-23 | Contrato 23 | [[LOG-23-Compras-Pipeline-Consolidado\|Compras: o que faltava na pipeline (envio da OC ao Omie, PTAX, nomes)]] | `implementado-no-codigo` | pipeline Omie | Entregues | C4 | — | — | — | — |
| LOG-26 | Contrato 26 | [[LOG-26-Vendas-Liberacao-Pedido\|Vendas: liberação do pedido pelo vendedor e Fluxo 4 para o MES]] | `implementado-no-codigo` | av-hub: banco, API, front · MES: API | Entregues | V2, V3, P1, P2 | — | — | — | — |
| LOG-28 | Contrato 28 | [[LOG-28-Compradores-Criar-Excluir-Sugestao\|Vendedores e compradores: cadastro só do Omie, período e sugestão]] | `implementado-no-codigo` | av-hub: API | Entregues | — | — | — | — | — |
| LOG-29 | Contrato 29; contrato 28 (nos comentários do código) | [[LOG-29-Notas-Fiscais-Manuais-So-Admin\|Notas fiscais manuais: só administrador cria]] | `implementado-no-codigo` | av-hub: API | Entregues | — | — | — | — | — |
| LOG-30 | Contrato 30 (PDF; não confundir com o "Contrato 30" do código, que é o LOG-45) | [[LOG-30-Compras-Pedido-Omie-PDF-Completo\|Pedido de compra do Omie: dados para o PDF]] | `implementado-no-codigo` | av-hub: API · pipeline Omie | Entregues | C4 | — | — | — | — |
| LOG-31 | Contrato 31 | [[LOG-31-Compras-Dashboard\|Compras: dashboard com valores]] | `implementado-no-codigo` | av-hub: API | Entregues | C4 | — | — | — | — |
| LOG-32 | Contrato 32 | [[LOG-32-Compras-CCP-Acompanhamento-OC\|Compras: acompanhamento da OC pelo CCP (confirmação, prazo, despacho)]] | `implementado-no-codigo` | av-hub: banco, API, front | Entregues | C5 | Perfil CCP: tarefa cadastral simples, em breve (Nathan e Gustavo; N14-24) | — | — | — |
| LOG-33 | Contrato 33 | [[LOG-33-Dashboards-Unidade-de-Origem-do-Vendedor\|Dashboards: unidade de origem e período de atividade do vendedor]] | `implementado-no-codigo` | av-hub: banco, API | Entregues | — | — | — | — | — |
| LOG-34 | Contrato 34 | [[LOG-34-Requisicoes-MES-Empurra-para-o-Hub\|Requisições: o MES empurra para o av-hub (PUT por `id_origem`)]] | `implementado-no-codigo` | av-hub: banco, API · MES: API | Entregues | P3, E4 | — | — | — | — |
| LOG-35 | Contrato 35 | [[LOG-35-Compras-Marcos-Requisicao-para-MES\|Compras: marcos da requisição (av-hub → MES)]] | `implementado-no-codigo` | av-hub: banco, API · MES: API | Entregues | C1, C3, C4, C5, R0, P3 | — | — | — | — |
| LOG-36 | Contrato 36 | [[LOG-36-Compras-Produto-Obrigatorio-e-Comprador-da-OC\|Compras: produto obrigatório no item e comprador da OC vindo do Omie]] | `implementado-no-codigo` | av-hub: banco, API | Entregues | C4 | — | — | — | — |
| LOG-37 | Contrato 37 | [[LOG-37-Dashboard-Mensal-Variacao\|`variacao_pct` nas rotas `/dashboard_mensal_*`]] | `implementado-no-codigo` | av-hub: API | Entregues | — | — | — | — | — |
| LOG-38 | Contrato 38 | [[LOG-38-Regras-Sem-Chave-de-Ambiente\|Regras decididas sem chave de ambiente]] | `implementado-no-codigo` | av-hub: API | Entregues | — | — | — | — | — |
| LOG-39 | Contrato 39 | [[LOG-39-Vendedores-Fila-de-Vinculo\|Vendedores: fila de vínculo com o funcionário]] | `implementado-no-codigo` | av-hub: API | Entregues | — | — | — | — | — |
| LOG-40 | Contrato 40 | [[LOG-40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend\|Escopo de vendedores e permissões pelo token, no backend]] | `implementado-no-codigo` | av-hub: API | Entregues | — | — | — | — | — |
| LOG-41 | Contrato 41 | [[LOG-41-Login-Rate-Limit-no-Backend\|Login: rate limit no backend]] | `implementado-no-codigo` | av-hub: API | Entregues | — | — | — | Nathan: confirmar a remoção do limitador do front (HUB) | — |
| LOG-42 | Contrato 42 | [[LOG-42-Coordenadores-e-Orcamento-sair-do-JSON-do-Repositorio\|Coordenadores e Orçamento: sair do JSON do repositório]] | `parcial` | av-hub: banco, API, front | Ativos | — | Robert: o Orçamento novo substitui o antigo | Gustavo: responder as perguntas do §10 | Nathan: §6 coordenadores no front e decidir corte do orçamento | acompanha |
| LOG-43 | Contrato 43; Contrato 05 (P6) | [[LOG-43-Ordem-das-Etapas-de-Faturamento-no-Cadastro\|Ordem das etapas de faturamento vem do cadastro (marca P6)]] | `parcial` | av-hub: banco, API, front · pipeline Omie | Ativos | — | — | Gustavo: protectedColumns no pipeline, conferir seed e versionar a view | Nathan: apagar a constante do front (passo 3.4) | — |
| LOG-44 | Contrato 44 | [[LOG-44-Upload-de-Fotos-Politica-de-Bucket\|Upload de fotos: política no bucket]] | `aplicado-em-producao` | av-hub: banco | Entregues | — | — | Gustavo: credencial própria do av-hub e teste da seção F | — | — |
| LOG-45 | Contrato 45; Contrato 30 (no código) | [[LOG-45-Pedido-de-Venda-Manual\|Pedido de venda manual (só administrador)]] | `implementado-no-codigo` | av-hub: API | Entregues | V1 | — | — | — | — |
| LOG-46 | Contrato 46 | [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas\|Torre de Fluxo: feed do MES, jobs de projeção e telas (I5 e I6)]] | `parcial` | av-hub: banco, API, front · MES: API | Ativos | F1, X1, Q7 | I2/I3: publicar `GET /fluxo/eventos` e instrumentar os eventos no MES | Gustavo: Q3 proposta (eventos do hub por trigger), aguarda decisão | Nathan: BFF `/api/fluxo/*` e 4 telas | — |
| LOG-47 | Contrato 47 | [[LOG-47-Custo-Real-por-Item-no-Hub\|Custo real por item no hub (simulador, comissão, Compras e Orçamento)]] | `parcial` | av-hub: banco, API, front · MES: API | Ativos | E3, R4 | Publicar `GET /itens/custo` (API-008 §5) | Gustavo: perguntas em aberto 🔴 | Nathan: §2 simulador, §3 comissão, §4 telas | Pablo: dono do Ciclo 2 de Comercial & Suprimentos |
| LOG-48 | Contrato 48 | [[LOG-48-Acompanhamento-de-Clientes-Grupos-de-Empresa\|Acompanhamento de clientes e grupos de empresa]] | `parcial` | av-hub: banco, API, front | Ativos | — | — | — (§13.2 entregue em 19/10) | Nathan: marcas `GAMBIARRA` do detalhe e §12.5 na tela | — |
| LOG-49 | Contrato 49 | [[LOG-49-Vinculos-do-Usuario-no-Me-Permissoes-Completos\|`GET /me/permissoes` com os vínculos de vendedor completos]] | `implementado-no-codigo` | av-hub: banco, API | Entregues | — | — | — | — | — |
| LOG-50 | Contrato 50 | [[LOG-50-Tirar-as-Marcas-de-Escopo-de-Vendedores-do-Front\|Tirar as 2 marcas de escopo de vendedores do front]] | `implementado-no-codigo` | av-hub: front | Entregues | — | — | Gustavo: `SEM_VENDEDOR_VINCULADO` no lugar de `PEDIDO_FORA_DO_ESCOPO` em etapas e itens | Nathan: testes de aceite 2, 3, 6 e 8 a 10 (faltou conta) | — |
| LOG-51 | Contrato 51 | [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub\|Segurança e padrão da API do av-hub (auditoria de 15/10): chave de serviço, Azure, senha, erro, helmet, roles, auditoria, testes]] | `aplicado-em-producao` | av-hub: banco, API, front | Entregues | — | — | Gustavo: S1 a S8 na fase 1 (chave de serviço, Azure, senha, mass assignment, rate limit, erro, helmet, role do banco), S9 a S27 depois | Nathan: H1, H3 a H6 feitos (PR #206); resta H2 (`fetchMenu`, com a API) e H7 (manual), BL-058 | — |
| LOG-52 | Contrato 52 | [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub\|Migrar o módulo Comercial & Suprimentos para a API do hub e aposentar a `api-comercial`]] | `parcial` | av-hub: banco, API, front | Ativos | — | Robert: conduzir o módulo na `api-acos-vital`, começando pela proposta (N16-117, N16-118); `api-comercial` só para leitura | Gustavo: `GRANT`, linhas de `auth.rotas_telas`, revisão; tirar o `core_comercial` (N16-116 bloco A0); Q1 (pedidos de compra na pipeline) e Q2 (telas em produção) | Nathan: corte do HUB (BL-063) e decisões Q3, Q4, Q7, Q8, Q10 | acompanha |
| HIST-Analise-Contratos-vs-Hub-2026-10-01 | — | [[HIST-Analise-Contratos-vs-Hub-2026-10-01\|Análise de contratos x hub (retrato de 01/10)]] | `arquivado` | — | Arquivados | — | — | — | — | — |
| HIST-Indice-Contratos | — | [[HIST-Indice-Contratos\|Índice antigo de contratos (v1)]] | `arquivado` | — | Arquivados | — | — | — | — | — |
| HIST-Indice-Logica-Fora-do-Backend | — | [[HIST-Indice-Logica-Fora-do-Backend\|Índice antigo das gambiarras fora do banco (v1)]] | `arquivado` | — | Arquivados | — | — | — | — | — |

## Tabela de aliases

Números que aparecem no código ou em notas antigas e o contrato a que se referem hoje.

| Alias | Contrato | Observação |
|---|---|---|
| "Contrato 30" nos comentários do código (`pedidos_vendas.route.js`) | [[LOG-45-Pedido-de-Venda-Manual]] | O LOG-30 de verdade é o PDF do pedido de compra do Omie: [[LOG-30-Compras-Pedido-Omie-PDF-Completo]] |
| "contrato 28" nos comentários do código (notas manuais) | [[LOG-29-Notas-Fiscais-Manuais-So-Admin]] | O LOG-28 de verdade é o cadastro de vendedores e compradores: [[LOG-28-Compradores-Criar-Excluir-Sugestao]] |
| "Contrato 05" (P1 a P8) no código e no banco | [[LOG-04b-Pedidos-Notas-Dashboards-Agregacao-no-Banco]] | A marca P6 virou [[LOG-43-Ordem-das-Etapas-de-Faturamento-no-Cadastro]] |
| "19-Nomes" (o título do texto diz "Contrato 27") | [[LOG-19b-Compras-Pedido-Omie-Nomes]] | O LOG-19a é o pedido à pipeline: [[LOG-19a-Compras-Pedido-Pipeline-Omie]] |
| "Contrato 15" (numeração antiga) | [[LOG-10-Compras-Pendencias-Pos-Backend]] | |
| "Contrato 16" (numeração antiga, compradores) | [[LOG-18-Compradores-Funcionario]] | O LOG-16 de hoje é o pedido ao DBA: [[LOG-16-Compras-Pedido-DBA-Banco]] |
| "Contrato 20" (numeração antiga) | [[LOG-11-Compras-Cotacao-Moeda-PTAX]] | |
| "Contrato 21" (numeração antiga) | [[LOG-12-Compras-Projetos-Omie]] | |
| "Contrato 22" (numeração antiga) | [[LOG-13a-Compras-Backend-Consolidado]] | |
| "Contrato 24" (numeração antiga) | [[LOG-14b-Compras-Vinculo-Pedido-Venda]] | |
| "Contrato 25" (numeração antiga) | [[LOG-15-Compras-Historico-Unificado]] | |
| "Contrato 27" (numeração antiga) | [[LOG-19b-Compras-Pedido-Omie-Nomes]] | |
| "Contrato SQL 006 a 011 do omie-elt-pipeline" | [[SQL-001-Parceiros-Dados-Fiscais]] a [[SQL-005-Locais-Estoque]] e [[SQL-006-Pedidos-Vendas-Valor-Devolucao]] | A pipeline numerava 006 a 011; o v1 renumerou para 001 a 006 |
| Duplicados com sufixo | 04: [[LOG-04a-Vagas-Fila-Decisao-no-Banco]] e [[LOG-04b-Pedidos-Notas-Dashboards-Agregacao-no-Banco]]; 07: [[LOG-07a-Dados-Orcamento-e-Coordenadores-no-Banco]] e [[LOG-07b-Chave-Composta-Blacklist-Pedidos]]; 09: [[LOG-09a-Ordenacao-Sistema-Vendedores]] e [[LOG-09b-Paginacao-por-Pedido-Vendas-Planilha]]; 13: [[LOG-13a-Compras-Backend-Consolidado]] e [[LOG-13b-Fornecedores-por-Produto]]; 14: [[LOG-14a-Compras-Omie-Pedido-Compra]] e [[LOG-14b-Compras-Vinculo-Pedido-Venda]]; 19: [[LOG-19a-Compras-Pedido-Pipeline-Omie]] e [[LOG-19b-Compras-Pedido-Omie-Nomes]] | Número original preservado; a letra distingue |

Cada nota de contrato também traz em `aliases` (frontmatter) o nome antigo do arquivo no vault v1 e o "Contrato N".

## Pendências por frente

Só contratos fora de `Arquivados/`. O detalhe e os selos estão na nota de cada contrato.

### Robert (MES: `api-pcp` e `app-pcp`)


- [[API-011-Compra-em-Andamento-Recebimento-por-Item-da-OC-e-Uso-Interno|API-011]]: testar em homologação, rateio da chegada (Q2), saldo futuro (BL-050) e OC visível ao PCP (BL-049); recebimento por OC e NF, uso interno e aviso ao requisitar já estão na `develop`
- [[LOG-53-Ordem-de-Producao-e-Lote-do-Fabricado|LOG-53]]: ✅ OP emitida e impressa e lote `PRODUCAO` por OP e produto feitos em 27/10 (`ab3318d`, na `develop`); falta o custo do fabricado (BL-067) e subir para a `main` (BL-035)
- [[LOG-54-Documento-de-Retirada-e-Baixa-na-Retirada|LOG-54]]: documento de retirada e baixa na retirada (tirar a baixa da Embalagem e da entrega)
- [[API-009-Referencia-Requisicao-Hub-Integracao-MES|API-009]]: ✅ job, projeção e requisições na Triagem feitos em 23/10 (`9e75df5`); falta conferir na tela o aviso de compra duplicada (BL-065)
- [[API-004-Referencia-OC-Integracao-MES|API-004]]: o job de leitura e a projeção da OC já são o K4 (`develop`, PR #59); falta OC do pedido para o PCP (BL-049), saldo futuro do Estoque (BL-050, N14-20) e entrada no Recebimento da OC sem requisição do MES (BL-051)
- [[API-007-Referencia-OC-Valores-no-MES|API-007]]: job e projeção já feitos no K4 (PR #59); falta gravar o custo da OC no lote (K5, `lote_custo` origem OC no Recebimento, R4)
- [[API-008-Custo-do-Lote-no-MES|API-008]]: ✅ §3 custo da OC no Recebimento (19/10), rota MANUAL e §5 `GET /itens/custo` (27/10, `6c11147`, na `develop`); falta conferir §4 snapshot na SAIDA; imposto por item: desenho decidido em 29/10 (N16-144); o contrato só nasce quando o desenvolvimento começar (contrato não editado)
- [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas|LOG-46]]: I2/I3: publicar `GET /fluxo/eventos` e instrumentar os eventos no MES
- [[LOG-47-Custo-Real-por-Item-no-Hub|LOG-47]]: ✅ `GET /itens/custo` publicada na `develop` (27/10); falta subir para a `main` (BL-035)
- [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub|LOG-51]]: S1 vale nos dois lados: quando o Gustavo trocar a chave de serviço, atualizar no MES a variável de ambiente da chave; as rotas que o MES chama (referência da OC, `PUT` de requisições, eventos do LOG-35 e, depois, a referência de requisições do API-009) têm de estar nas `rotas_permitidas` da chave nova, senão o MES recebe 403

### Gustavo (DBA: banco e API do av-hub)

- [[API-012-Produtos-Provaveis-Duplicatas-Rota-e-Tela|API-012]]: Gustavo: rota publicada; falta melhorar a nota (medidas em ordem, unidade, coesão) e informar os ajustes do script do [[SQL-013-Produtos-Provaveis-Duplicatas-Funcoes-e-Uso|SQL-013]]
- [[API-010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto|API-010]]: Gustavo: responder Q1 e Q4 (junto do API-009, BL-064); a migration `api010` está em produção desde 20/10
- [[API-009-Referencia-Requisicao-Hub-Integracao-MES|API-009]]: Gustavo: ✅ rota `GET /compras/requisicoes/referencia` na `main` (BL-064); responder Q1 a Q4; a migration `api009` está em produção desde 20/10
- [[LOG-50-Tirar-as-Marcas-de-Escopo-de-Vendedores-do-Front|LOG-50]]: Gustavo: `GET /itens_pedido_status` e `GET /pedido_venda_itens/{numero}` respondem `SEM_VENDEDOR_VINCULADO` (e não `PEDIDO_FORA_DO_ESCOPO`) para pedido de outro vendedor; conferir o `notas/resumo` do PCP com foco alheio (200 vazio)
- [[LOG-42-Coordenadores-e-Orcamento-sair-do-JSON-do-Repositorio|LOG-42]]: Gustavo: responder as perguntas do §10
- [[LOG-43-Ordem-das-Etapas-de-Faturamento-no-Cadastro|LOG-43]]: Gustavo: protectedColumns no pipeline, conferir seed e versionar a view
- [[LOG-44-Upload-de-Fotos-Politica-de-Bucket|LOG-44]]: Gustavo: credencial própria do av-hub no storage e teste da seção F (o av-hub ainda usa a do Organograma)
- [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas|LOG-46]]: Gustavo: Q3 (proposta: gravar os eventos do hub por trigger no banco), aguarda decisão do Nathan e do Robert
- [[LOG-47-Custo-Real-por-Item-no-Hub|LOG-47]]: Gustavo: perguntas em aberto 🔴
- [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub|LOG-51]]: Gustavo: S1 a S27 em fases; começar pela resposta às perguntas Q1 a Q5 (leitura em produção) e pelos itens sem dependência do HUB (BL-056)
- [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub|LOG-52]]: Gustavo: `GRANT`, linhas de `auth.rotas_telas` e `auth.telas`, revisão do módulo; responder Q1 e Q2 (a fase 1 do banco, `core_comercial`, está em produção desde 20/10 e sai pela N16-116)

### Nathan (front do av-hub)

- [[API-014-Setor-do-Cliente-e-do-Grupo-no-Acompanhamento-de-Clientes|API-014]]: Nathan: testar salvar 2 setores, o filtro e o Excel na tela (o front de vários setores está na `develop`); definir perfis `pode_editar`/`pode_criar` e o lote
- [[SQL-015-Carteira-do-PCP-Totais-por-Vendedor-e-Desvio|SQL-015]]: Nathan: testar `PUT .../marcacao` (marcar e desmarcar, escopo, histórico) e conferir o cartão "Em avanço" do Dashboard
- [[LOG-55-Compras-Excluir-Requisicao|LOG-55]]: Nathan: Q2, dar `pode_deletar` em `compras` ao perfil Comprador (ajuste de perfil no banco)
- [[API-012-Produtos-Provaveis-Duplicatas-Rota-e-Tela|API-012]]: Nathan: BFF `/api/produtos/duplicatas`, serviço sem varredura do catálogo e tela nova (KPIs, filtros, motivos, uso); decidir se vale o "não é duplicata"
- [[API-010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto|API-010]]: Nathan: tela nova pronta (PR #209); a OC herda a finalidade da requisição; decidir Q2 e Q3
- [[API-011-Compra-em-Andamento-Recebimento-por-Item-da-OC-e-Uso-Interno|API-011]]: Nathan: contabilidade do uso interno e EPI (Q3); BL-049 e BL-050 no Ciclo 1 (Q5)
- [[LOG-54-Documento-de-Retirada-e-Baixa-na-Retirada|LOG-54]]: Nathan: quem gera o documento, o que imprime, reserva depois da retirada (Q1, Q2) e se entra no Ciclo 1 (Q3)
- [[API-009-Referencia-Requisicao-Hub-Integracao-MES|API-009]]: Nathan: ✅ campo "Pedido de venda" na "Nova requisição" feito e testado (BL-041); decidir Q5 (avisa ou bloqueia)
- [[LOG-04b-Pedidos-Notas-Dashboards-Agregacao-no-Banco|LOG-04b]]: Nathan: P6 no front (ver LOG-43)
- [[LOG-41-Login-Rate-Limit-no-Backend|LOG-41]]: Nathan: confirmar a remoção do limitador do front (HUB)
- [[LOG-42-Coordenadores-e-Orcamento-sair-do-JSON-do-Repositorio|LOG-42]]: Nathan: §6 coordenadores no front e decidir corte do orçamento
- [[LOG-43-Ordem-das-Etapas-de-Faturamento-no-Cadastro|LOG-43]]: Nathan: apagar a constante do front (passo 3.4)
- [[LOG-46-Torre-de-Fluxo-Feed-Jobs-e-Telas|LOG-46]]: Nathan: BFF `/api/fluxo/*` e 4 telas
- [[LOG-47-Custo-Real-por-Item-no-Hub|LOG-47]]: Nathan: §2 simulador, §3 comissão, §4 telas
- [[LOG-48-Acompanhamento-de-Clientes-Grupos-de-Empresa|LOG-48]]: Nathan: marcas `GAMBIARRA` do detalhe e §12.5 na tela
- [[LOG-50-Tirar-as-Marcas-de-Escopo-de-Vendedores-do-Front|LOG-50]]: Nathan: testes de aceite que faltaram (gerente de equipe, auxiliar, vendedor sem vínculo, token expirado)
- [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub|LOG-51]]: Nathan: H1, H3 a H6 feitos na PR #206 (`d0ef359`); resta H2 (`fetchMenu`: a API isenta a rota do menu) e H7 (rotacionar a chave, manual) para a API ligar `IDENTIDADE_EXIGIR_TOKEN`
- [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub|LOG-52]]: Nathan: ✅ corte do HUB para a API única feito em 27/10 (BL-063); decidir Q3, Q4, Q7, Q8, Q10 e Q11

### Robert (módulo comercial na `api-acos-vital`, desde 28/10/2026)

- [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub|LOG-52]]: Robert: trocar o backend das telas do Pablo, sem refazê-las (N16-119), portando só o que a N16-109 manda; a `api-comercial` fica só para leitura (N16-117)

### Pablo (Comercial & Suprimentos)

- Desde 28/10/2026 **acompanha** o Robert (N16-117). As pendências que eram dele (ciclo da proposta, módulo na `api-acos-vital`, Ciclo 2 do LOG-47, substituir o orçamento do LOG-42) passaram ao Robert.

## O que mudou de pasta em 29/10/2026

O Gustavo terminou o banco e a API destes contratos (informado pelo Nathan em 29/10). O que sobra é front ou MES e continua em "Pendências por frente".

| Contrato | De | Para | Motivo |
|---|---|---|---|
| [[SQL-015-Carteira-do-PCP-Totais-por-Vendedor-e-Desvio\|SQL-015]] | Ativos | Entregues | Banco e API terminados; falta o Nathan testar a marcação de avanço na tela |
| [[API-014-Setor-do-Cliente-e-do-Grupo-no-Acompanhamento-de-Clientes\|API-014]] | Ativos | Entregues | Banco e API terminados (`api014b`); falta o Nathan testar 2 setores, o filtro e o Excel e definir os perfis |

**Sem mudança de pasta:** [[API-011-Compra-em-Andamento-Recebimento-por-Item-da-OC-e-Uso-Interno\|API-011]] passa de `proposta` para `parcial`: a parte do hub (Gustavo) está pronta e o MES já tem boa parte na `develop`; o resto é do Robert. Os totais do resumo foram recontados pelos arquivos (antes não descontavam os 15 contratos removidos em 29/10).

## O que mudou de pasta em 26/10/2026

Pela lista do Gustavo (que conferiu o vault com o dump de produção de 26/10) e pela conferência que fiz no mesmo dia pelo av-hub, sem mexer em dados.

| Contrato | De | Para | Motivo |
|---|---|---|---|
| [[API-018-Carteira-do-PCP-Vencem-Hoje-e-Atrasados-Conferidos\|API-018]] | Ativos | Entregues | Migration `api018` em produção; `vence_hoje_*` e atrasados conferidos contra a lista em 26/10 |
| [[LOG-55-Compras-Excluir-Requisicao\|LOG-55]] | Ativos | Entregues | `DELETE` e migration `055` em produção; front feito e exclusão testada em 23/10 (só a Q2 do Nathan segue aberta) |

**Removidos em 29/10/2026 (pedido do Nathan):** os 15 contratos da proposta ao pedido, do Orçamento, do custo real e da comissão nova saíram de `Ativos`, com os anexos, porque o Robert vai criar os contratos dessa parte. As decisões N16 do [[Registro-de-Decisoes]] seguem valendo.

**Atualizados em 28/10/2026, sem mudança de pasta:** LOG-42, LOG-47, LOG-52 e API-014, com as decisões N16-112 a N16-119 ([[Registro-de-Decisoes]]): não existirá `core_comercial` e tudo vai para `core_vendas_faturamento` (os anexos `.sql` foram trocados e retestados em Postgres 18, com a mesma saída de 26/10); o Robert faz as rotas e começa pela proposta; o Pablo acompanha; a `api-comercial` fica só para leitura; e-mail e notificações ficam para o futuro.

**Entrou em `Ativos` em 27/10/2026:** (`proposta`), menu enxuto de Vendas, Orçamento e Compras e limpeza do módulo do Pablo, com as decisões N16-107 a N16-110 ([[Registro-de-Decisoes]]).

Sem mudança de pasta, mas com status corrigido: [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub\|LOG-51]] (a linha dizia Ativos/proposta; a nota já estava em Entregues/`aplicado-em-producao`) e [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub\|LOG-52]] (`proposta` para `parcial`: a fase 1 do banco está em produção).

## Feito sem contrato no vault

Informado pelo Gustavo em 26/10/2026; não conferi no banco.

| O que | Quando | Observação |
|---|---|---|
| Organograma: coluna `ordem` nos níveis e o nível 13 (Diretoria Executiva) | aplicado em 21/10 | sem contrato |
| 035b: os eventos da requisição trazem quem fez e o comprador | aplicado em 16/10 | extensão do [[LOG-35-Compras-Marcos-Requisicao-para-MES]] |

---
## O que mudou de pasta em 14/10/2026

Os 85 arquivos chegaram do vault v1 com 51 em `Arquivados/`. A revisão contra o código de 14/10 mostrou que a maior parte já estava **feita**, não superada, e foi para `Entregues/`. Ficam em `Arquivados/` só os rejeitados, substituídos, invalidados, desconsiderados e os índices históricos.

| Contrato | De | Para | Motivo |
|---|---|---|---|
| [[API-001-Produtos-Parceiros-Filtro-Incremental\|API-001]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-01-Compras-Fluxo-Completo\|LOG-01]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-02-Funcionarios-Listagem-Filtros-Ordenacao-Resumo\|LOG-02]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-03-Funcionarios-Cadastro-Organograma-Transacional\|LOG-03]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-04a-Vagas-Fila-Decisao-no-Banco\|LOG-04a]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-04b-Pedidos-Notas-Dashboards-Agregacao-no-Banco\|LOG-04b]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-05-Permissoes-e-Escopo-no-Banco\|LOG-05]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-06-Ordenacao-Listagens\|LOG-06]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-07b-Chave-Composta-Blacklist-Pedidos\|LOG-07b]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-08-Itens-por-Parcela-Pedidos\|LOG-08]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-09a-Ordenacao-Sistema-Vendedores\|LOG-09a]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-09b-Paginacao-por-Pedido-Vendas-Planilha\|LOG-09b]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-10-Compras-Pendencias-Pos-Backend\|LOG-10]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-11-Compras-Cotacao-Moeda-PTAX\|LOG-11]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-12-Compras-Projetos-Omie\|LOG-12]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-13a-Compras-Backend-Consolidado\|LOG-13a]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-14a-Compras-Omie-Pedido-Compra\|LOG-14a]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-15-Compras-Historico-Unificado\|LOG-15]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-18-Compradores-Funcionario\|LOG-18]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-19b-Compras-Pedido-Omie-Nomes\|LOG-19b]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-28-Compradores-Criar-Excluir-Sugestao\|LOG-28]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-29-Notas-Fiscais-Manuais-So-Admin\|LOG-29]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-30-Compras-Pedido-Omie-PDF-Completo\|LOG-30]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-31-Compras-Dashboard\|LOG-31]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-33-Dashboards-Unidade-de-Origem-do-Vendedor\|LOG-33]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-37-Dashboard-Mensal-Variacao\|LOG-37]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-38-Regras-Sem-Chave-de-Ambiente\|LOG-38]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[LOG-39-Vendedores-Fila-de-Vinculo\|LOG-39]] | Arquivados | Entregues | Implementado e conferido no código de 14/10 |
| [[SQL-001-Parceiros-Dados-Fiscais\|SQL-001]] | Arquivados | Entregues | Aplicado no banco (tabela vista no dump de 14/10) |
| [[SQL-002-Estoque-Saldo\|SQL-002]] | Arquivados | Entregues | Aplicado no banco (tabela vista no dump de 14/10) |
| [[SQL-003-Pedidos-Vendas-Frete-Parcelas\|SQL-003]] | Arquivados | Entregues | Aplicado no banco (tabela vista no dump de 14/10) |
| [[SQL-004-Pedidos-Compras\|SQL-004]] | Arquivados | Entregues | Aplicado no banco (tabela vista no dump de 14/10) |
| [[SQL-005-Locais-Estoque\|SQL-005]] | Arquivados | Entregues | Aplicado no banco (tabela vista no dump de 14/10) |
| [[SQL-009-Categoria-Sem-Escopo-Empresa-Views\|SQL-009]] | Arquivados | Entregues | Aplicado no banco (tabela vista no dump de 14/10) |

## Arquivados: por que cada um está lá

| Contrato | Motivo |
|---|---|
| [[SQL-006-Pedidos-Vendas-Valor-Devolucao\|SQL-006]] | Arquivado: invalidado. `StatusDevolucaoVenda` não está disponível no Omie; devolução é nativa do Estoque (DEC-10, Ciclo 2). |
| [[API-002-Material-Alias-Omie-MES\|API-002]] | Arquivado: rejeitado. Decisão de 21/09/2026; o alias existiu no MES e foi removido. Motivo do arquivamento: contrato rejeitado, não há o que implementar. |
| [[API-003-Requisicao-Compra-Integracao-MES\|API-003]] | Arquivado: substituído pelo [[LOG-34-Requisicoes-MES-Empurra-para-o-Hub]]. O objetivo (a requisição do MES chegar ao av-hub) é cumprido pelo `PUT /compras/requisicoes/origem/:id_origem`, não pelo polling descrito aqui. |
| [[LOG-07a-Dados-Orcamento-e-Coordenadores-no-Banco\|LOG-07a]] | Arquivado: substituído pelo [[LOG-42-Coordenadores-e-Orcamento-sair-do-JSON-do-Repositorio]] (decisão de 07/10: orçamento fica no módulo Comercial & Suprimentos). |
| [[LOG-13b-Fornecedores-por-Produto\|LOG-13b]] | Arquivado: fora de escopo. Desconsiderado por decisão do Nathan (decisão #40 do vault v1). O endpoint foi entregue, mas o front não liga. |
| [[LOG-16-Compras-Pedido-DBA-Banco\|LOG-16]] | Arquivado: histórico, substituído pelo [[LOG-13a-Compras-Backend-Consolidado]]. O que sobrou deste pedido foi consolidado ali. |
| [[LOG-17-Compras-Pedido-API-Backend\|LOG-17]] | Arquivado: histórico, substituído pelo [[LOG-13a-Compras-Backend-Consolidado]]. |
| [[LOG-19a-Compras-Pedido-Pipeline-Omie\|LOG-19a]] | Arquivado: substituído pelo [[LOG-23-Compras-Pipeline-Consolidado]]. |
| [[HIST-Analise-Contratos-vs-Hub-2026-10-01\|HIST-Analise-Contratos-vs-Hub-2026-10-01]] | Arquivado: retrato histórico de 01/10/2026. Não é estado atual; várias linhas mudaram (ver o [[Painel-de-Contratos]] para o estado de cada contrato). |
| [[HIST-Indice-Contratos\|HIST-Indice-Contratos]] | Arquivado: substituído pelo [[Painel-de-Contratos]]. Índice do vault v1, com numeração antiga e estados de 07/10/2026. |
| [[HIST-Indice-Logica-Fora-do-Backend\|HIST-Indice-Logica-Fora-do-Backend]] | Arquivado: substituído pelo [[Painel-de-Contratos]]. Índice das marcas `GAMBIARRA(` do av-hub, com estado de 07/10/2026. |
