---
tags: [diagramas, indice, uml, mapa]
criado: 2026-10-14
atualizado: 2026-10-26
status: vigente
dono: Nathan
fontes: [v1 04-Arquitetura-Transversal/Diagramas-UML, v1 01-Fluxo-Operacional (Fluxogramas-Completos, Fluxograma-Telas-por-Bloco, Fluxo-Sistema-no-Meio, Fluxo-Operacional-Visao-Geral, Encaixe-Estoque-Revenda-no-PCP), v1 02-PRD-Estoque (Fluxo-*-Completo, Proposta-Transferencia-Estoque-Filiais), 00-Fluxo-Mestre-0b, código de 14/10/2026]
---

# Índice de diagramas

O v1 tinha 31 diagramas na UML e outros espalhados nas pastas de fluxo, quase todos escritos entre 24/09 e 08/10 e nunca refeitos depois que o código mudou. Aqui cada um tem um destino: **mantido** (bate com o código de 14/10), **redesenhado** (o conceito vale, o desenho estava velho ou errado) ou **descartado** (ilustrativo, redundante ou superado), com o motivo. O fluxo de referência é o [[00-Fluxo-Mestre-0b]]; todo diagrama de fluxo usa os IDs de nó dele.

## Os diagramas do v2

| Nota | Conteúdo | Diagramas |
|---|---|---|
| [[00-Fluxo-Mestre-0b]] | Fluxo de atividades de ponta a ponta, com IDs `V0.1` a `O2` e `K1` a `K6` | 1 |
| `artifact-proposta-pedido.html` | Fluxo da proposta ao pedido, aprovado em 26/10/2026: proposta, compra, datas, faturamento em partes, custo real, comissão e cancelamento (página publicada "Fluxo da Proposta ao Pedido") | 1 página |
| `Historia-da-Proposta-ao-Pedido.pdf` | A jornada do usuário de ponta a ponta, num caso só (Mogi: flanges, tubos, flanges cegas e flange sobre desenho) | 3 páginas |
| [[11-Proposta-e-Pedido-de-Venda]], [[12-Orcamento-Base-de-Preco]], [[13-Custo-Real-e-Comissao-no-Fluxo]] | Subfluxos da proposta ao pedido, do Orçamento e do custo real e da comissão | 3 |
| [[Sequencia]] | Pedido ao PCP, atendimento do Estoque, requisição ida e volta, chegada com NF e Recebimento, inspeção de entrada, produção e Expedição, despacho | 8 |
| [[Estados]] | Parcial, lote, reserva, recebimento, divergência, requisição (MES e hub), etapa de compra, OC, envio, liberação, etapa do item | 12 |
| [[Classes]] | Estoque e compras, produção, compras e integração, api-comercial | 4 |
| [[Casos-de-Uso]] | Seis blocos por raia | 6 |
| [[Componentes-e-Implantacao]] | Componentes e integrações, implantação, pacotes de schema, fluxo de dados | 4 |
| [[Modelo-de-Dados]] | PK e FK do MES (estoque e compras, produção), integração, av-hub, mapa dos dois bancos | 4 |

Diagramas de apoio em outras pastas: o grafo do Circuito de Compra em [[04-Circuito-de-Compra]], as sequências de integração em [[Integracao-AvHub-MES]] (INT-01 a INT-07) e a transferência entre filiais em [[Transferencia-entre-Filiais]].

## Destino dos diagramas da UML do v1 (`Diagramas-UML.md`)

| # v1 | Diagrama | Destino | Por quê | Onde está agora |
|---|---|---|---|---|
| 0a | Sequência: Fluxo de Compras | Redesenhado | Mostrava a requisição lida pelo hub (contrato 003, polling 5 min), registro manual da OC no MES e o custo da OC no Recebimento. O código empurra a requisição (LOG-34), lê todos os marcos (LOG-35) e confere contra a NF | [[Sequencia]] 3, 4 e 5 |
| 0b | Atividades: fluxograma mestre | Redesenhado | Aprovação "da diretoria" sem Gerente, uma só origem de requisição, "confere contra a OC", baixa no despacho com código na Embalagem | [[00-Fluxo-Mestre-0b]] |
| 1 | Classes: Estoque | Redesenhado | `Deposito.codigoEmpresa` e `lote_custo` agora existem; classes futuras (`Pesagem`, `OrdemSeparacao`, `DevolucaoCliente`, `ContagemCiclica`) sem schema; entra `RetiradaEstoque` proposta | [[Classes]] 1 |
| 2 | Classes: MES Produção | Redesenhado | Reescrito do Prisma de 14/10, com `importadoAvhubEm` e enums atuais | [[Classes]] 2 |
| 3 | Classes: av-hub comercial e RBAC | Descartado aqui | Não é do fluxo 0b e não foi reconferido contra o dump; o RBAC do av-hub é assunto de [[RBAC-e-Permissoes]] e o banco de [[Banco-AvHub]] | fora |
| 4a a 4e | Casos de uso por raia | Redesenhados | UC13 "registrar compra manualmente" não existe mais; faltavam C0, retirada, liberar sem OC, carga inicial; aprovação mudou | [[Casos-de-Uso]] 1 a 6 |
| 5 | Estados: `ItemParcial` | Mantido, ajustado | Os 9 valores do enum batem; o ajuste foi a lista de ações e o legado `RETRABALHO` | [[Estados]] 1 |
| 6 | Estados: Divergência | Mantido | Enum e falta de reabertura batem | [[Estados]] 5 |
| 7 | Estados: Lote e Qualidade | Mantido | Enum `PENDENTE`, `LIBERADO`, `REPROVADO`, `QUARENTENA` bate; entrou a lacuna do fabricado | [[Estados]] 2 |
| 8 | Estados: status do item (visão do vendedor) | Descartado | Oito estados que nunca existiram no código; o que existe são 11 etapas de `etapaDoItem` | [[Estados]] 12 e [[Estados-e-Status]] |
| 9 | Componentes | Redesenhado | Dizia que o hub não consumia `GET /itens/status` e que o MES reagia só a dois eventos; os jobs existem; `api-comercial` e pipeline mudaram | [[Componentes-e-Implantacao]] 1 |
| 10 | Implantação | Redesenhado | Imagens e portas conferidas nos Dockerfiles; MinIO não aparece no código | [[Componentes-e-Implantacao]] 2 |
| 11 | Pacotes: schemas | Redesenhado | Faltavam `core_fluxo`, `core_mapas`, `core_organograma`, `historico`, `core_estoque` e `core_comercial` | [[Componentes-e-Implantacao]] 3 |
| 12 | Comunicação: rede de objetos | Descartado | Mesma informação do Mestre, com o fluxo anterior (referência da OC, "registro manual") | [[00-Fluxo-Mestre-0b]] |
| 13 | Objetos: item de Revenda comprado | Descartado | Instância ilustrativa com `pedidoCompra` digitado e baixa na Embalagem; não tem valor de referência | — |
| 14 | Estrutura composta: `Pedido` | Descartado | Ilustrativo; redundante com o diagrama de classes | [[Classes]] 2 |
| 15 | Visão geral de interação | Descartado | Substituída pelo Mestre (o `ref:` apontava para fluxos de 24/09) | [[00-Fluxo-Mestre-0b]] |
| 16 | Tempo (Gantt) do item contra o SLA | Descartado | Dados fictícios de exemplo; o SLA real é da Torre de Fluxo | [[Rastreabilidade-e-Torre-de-Fluxo]] |
| 17 | Modelo de dados: Estoque (PK e FK) | Redesenhado | `lote_custo`, `depositos.codigo_empresa`, recebimento e colunas de CCP | [[Modelo-de-Dados]] 1 |
| 18 | Modelo de dados: MES Produção | Redesenhado | Reescrito do Prisma de 14/10 | [[Modelo-de-Dados]] 2 |
| 19 | Objetos: MES, Flange no roteiro | Descartado | Instância ilustrativa de um roteiro | [[07-Producao-e-Roteiro]] |
| 20 | Estados: Reserva | Mantido, ajustado | Enum bate; o v1 já dizia que a baixa passa ao despacho; agora o desenho mostra a retirada decidida como 🔴 | [[Estados]] 3 |
| 21 | Mapa geral dos dois bancos | Redesenhado | Mostrava 4 fluxos; são 7 mais o legado | [[Modelo-de-Dados]] 5 |
| 22 | Fluxo de dados Omie até o Estoque | Redesenhado | "O hub não consome o status" estava errado | [[Componentes-e-Implantacao]] 4 |
| 23 | Classes: Recebimento e integração | Redesenhado | Faltavam os campos de CCP e a chegada com NF | [[Classes]] 3 |
| 24 | Estados: Recebimento | Mantido | Enum e transições batem | [[Estados]] 4 |
| 25 | Classes: `api-comercial` | Redesenhado | `PerfilComercial` virou `UsuarioComercial` e o enum de cargo saiu | [[Classes]] 4 |

## Destino dos fluxogramas e sequências das pastas de fluxo do v1

| Origem no v1 | Diagrama | Destino | Por quê |
|---|---|---|---|
| `Fluxogramas-Completos` 1 | Fluxograma mestre (desenho de 24/09) | Descartado | Substituído pelo [[00-Fluxo-Mestre-0b]] |
| `Fluxogramas-Completos` 2 a 4 | Compras, Recebimento, Qualidade (atividades) | Descartados | Cobertos pelas notas de raia [[04-Circuito-de-Compra]], [[05-Recebimento]], [[06-Qualidade-Entrada]] e pelos diagramas [[Sequencia]] 3 a 5; o desenho anterior tinha "confere contra a OC" |
| `Fluxogramas-Completos` 5 | Produção como máquina de estados (`ItemParcial`) | Redesenhado | [[Estados]] 1 |
| `Fluxogramas-Completos` 6 | Estoque (etapa 1, entrada do comprado, operação contínua) | Redesenhado | [[Sequencia]] 2 e 7; a operação contínua do depósito (movimentação e ajuste) é tela de [[03-Estoque-Atendimento-e-Despacho]] |
| `Fluxograma-Telas-por-Bloco` (mestre com contagem de telas) | Mestre com contagem por raia | Descartado | A contagem de telas é de 08/10 e as telas mudaram; a fonte agora é [[Telas-por-Raia]] |
| `Fluxo-Sistema-no-Meio` (3 diagramas) | "O sistema no centro" e mestre com o sistema interposto | Descartados | Desenho conceitual de 29/09 com 19 atos; o que vale está nas notas de raia |
| `Fluxo-Operacional-Visao-Geral` | ASCII macro das quatro fases | Descartado | Superado pelo encaixe de 24/09 e pelo Mestre |
| `Encaixe-Estoque-Revenda-no-PCP` 3.2 | Roteiros por tipo de fábrica | Descartado | Mistura o circuito de compra dentro do roteiro da Revenda; hoje o circuito é fixo e fora do roteiro. Ver [[07-Producao-e-Roteiro]] |
| `Fluxo-Compras-Completo` | Sequência de Compras (29/09) | Redesenhado | [[Sequencia]] 3 |
| `Fluxo-Recebimento-Completo` ("Como é no código") | Sequência do Recebimento com recontagem | Redesenhado | O desenho valia na conferência, mas ainda usava o `PATCH :id/compra`; agora [[Sequencia]] 4 |
| `Fluxo-Recebimento-Completo` ("Desenho original") | Arquitetura de 29/09 | Descartado | Histórico |
| `Fluxo-Qualidade-Completo` | Sequência da Qualidade | Redesenhado | [[Sequencia]] 5 |
| `Fluxo-Producao-OS-OP-Completo` | Sequência da Produção | Redesenhado | [[Sequencia]] 6 |
| `Fluxo-Expedicao-Faturamento-Completo` | Sequência da Expedição e Faturamento | Redesenhado | [[Sequencia]] 6 e 7 |
| `Fluxo-Estoque-Completo` casos A, C e B | Atendimento, retorno do comprado, operação contínua | Redesenhados | Casos A e C em [[Sequencia]] 2, 5 e 7; caso B descartado do diagrama |
| `Proposta-Transferencia-Estoque-Filiais` | Estados da transferência | Mantido no anexo | [[Transferencia-entre-Filiais]] (Ciclo 2) |
| `Mapa-Rotas-BFF-API-para-Bearer` | Tabelas, sem diagrama | n/a | [[Mapa-Rotas-BFF-Bearer]] |

## Limites desta conferência

- Os diagramas de classes, estados e dados foram reescritos do Prisma, dos routers e dos dumps de 14/10. Os diagramas de sequência foram conferidos contra os serviços do `api-pcp` e do `api-acos-vital` citados em cada bloco.
- Os fluxogramas de atividades por raia e as sequências `Fluxo-*-Completo` do v1 foram classificados pelo tema e pela comparação com o 0b e com o código, não relidos linha a linha: a regra foi não manter nenhum que mencione "confere contra a OC", registro manual da compra, baixa só no despacho ou aprovador genérico.
- `Q8` no Mestre manda o aprovado ao Estoque (E5); o código manda à Expedição. O diagrama [[Sequencia]] 6 mostra as duas coisas. Dono: Robert.
