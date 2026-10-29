---
tags: [diagramas, modelo-de-dados, banco, mes, av-hub]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Robert
fontes: [v1 Diagramas-UML (17, 18, 21), api-pcp 579a625 prisma/models/*.prisma, Dump Avhub e Dump MES de 14/10/2026]
---

# Modelos de dados (PK e FK)

**Em uma frase:** mostra as tabelas dos dois bancos (MES e av-hub) e como uma aponta para a outra, com os nomes reais do banco.

**Como ler estes diagramas**

- Cada caixa é uma tabela; cada linha dentro dela é uma coluna. `PK` (chave primária) identifica a linha. `FK` (chave estrangeira) aponta para outra tabela.
- Uma seta liga a tabela que "tem" à tabela que "pertence". `1` e `0..*` dizem quantos: um, ou nenhum ou vários.
- Só aparecem as colunas que ligam as tabelas e as que o fluxo 0b usa.
- O último diagrama (o 5) é o mapa simples dos dois bancos. Se você não é técnico, comece por ele.

Dicionário completo: [[Banco-MES]], [[Banco-AvHub]] e [[Modelo-Estoque-e-Custo-do-Lote]]. Destino de cada diagrama do v1: [[Indice-de-Diagramas]].

## 1. MES: Estoque e Compras

Material gera lote; lote tem saldo, movimento, custo e reserva. A requisição de compra gera o recebimento, e o recebimento gera o lote.

```mermaid
classDiagram
    class materiais {
        +uuid id PK
        +uuid codigo_empresa
        +string codigo_produto_omie
        +uuid id_produto_avhub
        +string natureza
        +decimal peso_teorico_unitario
        +decimal tolerancia_peso
        +decimal ponto_de_pedido
    }
    class lotes {
        +uuid id PK
        +string codigo
        +uuid id_material FK
        +uuid id_lote_pai FK
        +uuid id_requisicao_item FK
        +string origem
        +string status_qualidade
        +string laudo_url
        +string numero_nf
        +datetime quarentena_desde
    }
    class lote_custo {
        +uuid id_lote PK FK
        +string origem
        +decimal custo_liquido_unitario
        +decimal valor_unitario
        +string moeda
        +decimal cotacao
        +decimal desconto_pct
        +decimal frete_unit
        +uuid id_item_oc
        +boolean cotacao_a_conferir
    }
    class rncs {
        +uuid id PK
        +uuid id_lote FK
        +decimal quantidade_reprovada
        +boolean nota_devolucao_pendente
    }
    class depositos {
        +uuid id PK
        +string codigo
        +uuid codigo_empresa
    }
    class localizacoes_estoque {
        +uuid id PK
        +uuid id_deposito FK
        +string codigo
    }
    class saldos_estoque {
        +uuid id PK
        +uuid id_lote FK
        +uuid id_localizacao FK
        +uuid id_deposito FK
        +decimal quantidade
    }
    class movimentos_estoque {
        +uuid id PK
        +uuid id_lote FK
        +uuid id_reserva FK
        +uuid id_localizacao_origem FK
        +uuid id_localizacao_destino FK
        +string tipo
        +decimal quantidade
        +uuid usuario_id
        +uuid autorizado_por_id
    }
    class reservas_estoque {
        +uuid id PK
        +uuid id_lote FK
        +uuid id_item_parcial FK
        +decimal quantidade
        +decimal quantidade_consumida
        +string status
    }
    class requisicoes_compra {
        +uuid id PK
        +string codigo
        +uuid id_item_parcial FK
        +uuid id_item_pedido FK
        +string status
        +string pedido_compra
        +date previsao_entrega
        +string nf_chegada
    }
    class requisicoes_compra_itens {
        +uuid id PK
        +uuid id_requisicao FK
        +uuid id_material FK
        +string tipo
        +decimal quantidade
        +decimal quantidade_recebida
        +uuid avhub_id_requisicao
        +string etapa_compra
        +string numero_oc
    }
    class recebimentos {
        +uuid id PK
        +uuid id_requisicao FK
        +uuid id_item_parcial FK
        +string status
        +string numero_nf
        +string chave_acesso_nf
    }
    class recebimentos_itens {
        +uuid id PK
        +uuid id_recebimento FK
        +uuid id_requisicao_item FK
        +uuid id_localizacao
        +uuid id_lote
        +decimal quantidade_nf
        +decimal quantidade_contada
        +decimal peso_real
    }
    class recebimentos_divergencias {
        +uuid id PK
        +uuid id_recebimento FK
        +uuid id_recebimento_item FK
        +string tipo
        +string etapa
    }
    class itens_parciais {
        +uuid id PK
        +uuid id_lote_compra FK
        +boolean atendido_pelo_estoque
    }

    materiais "1" --> "0..*" lotes
    lotes "0..1" --> "0..*" lotes : id_lote_pai
    lotes "1" --> "0..1" lote_custo
    lotes "1" --> "0..*" rncs
    lotes "1" --> "0..*" saldos_estoque
    lotes "1" --> "0..*" movimentos_estoque
    depositos "1" --> "0..*" localizacoes_estoque
    localizacoes_estoque "1" --> "0..*" saldos_estoque
    reservas_estoque "0..*" --> "1" lotes
    reservas_estoque "0..*" --> "0..1" itens_parciais
    movimentos_estoque "0..*" --> "0..1" reservas_estoque
    requisicoes_compra "0..*" --> "1" itens_parciais
    requisicoes_compra "1" --> "1..*" requisicoes_compra_itens
    requisicoes_compra_itens "0..*" --> "1" materiais
    requisicoes_compra_itens "0..1" --> "0..*" lotes
    requisicoes_compra "1" --> "0..*" recebimentos
    recebimentos "0..*" --> "1" itens_parciais
    recebimentos "1" --> "1..*" recebimentos_itens
    recebimentos "1" --> "0..*" recebimentos_divergencias
    recebimentos_itens "0..*" --> "1" requisicoes_compra_itens
    itens_parciais "0..*" --> "0..1" lotes : id_lote_compra
```
✅ Conferido no código. `depositos.codigo_empresa` e `lote_custo` existem agora. Só a carga inicial grava custo no lote 🔴.

## 2. MES: Produção

Pedido tem itens, roteiro e parciais. A parcial é a parte do item que anda de setor em setor. Entregas e divergências ligam ao item e à parcial.

```mermaid
classDiagram
    class fabricas {
        +uuid id PK
        +string codigo
        +string tipo
    }
    class setores {
        +uuid id PK
        +string codigo
        +string tipo
        +boolean exige_maquina_operador
    }
    class fabrica_setores {
        +uuid id_fabrica PK FK
        +uuid id_setor PK FK
    }
    class maquinas {
        +uuid id PK
        +uuid id_setor FK
    }
    class pedidos {
        +uuid id PK
        +uuid id_fabrica FK
        +string pedido_venda
        +string ordem_producao
        +string status
        +string sistema
        +string id_unidade
        +boolean acompanhamento_qualidade
        +datetime importado_avhub_em
    }
    class itens_pedido {
        +uuid id PK
        +uuid id_pedido FK
        +uuid id_item_pai FK
        +string codigo
        +decimal quantidade
        +decimal quantidade_concluida
        +boolean inativo
    }
    class roteiros {
        +uuid id PK
        +uuid id_pedido FK
        +uuid id_setor FK
        +int ordem
    }
    class roteiros_item {
        +uuid id PK
        +uuid id_item_pedido FK
        +uuid id_setor FK
        +int ordem
    }
    class itens_parciais {
        +uuid id PK
        +uuid id_item_pedido FK
        +uuid id_parcial_origem FK
        +uuid id_devolvido_de FK
        +uuid id_setor_atual FK
        +uuid id_setor_origem FK
        +uuid id_lote_compra FK
        +decimal quantidade
        +string status
        +boolean retrabalho
        +boolean atendido_pelo_estoque
    }
    class historico_itens_parciais {
        +uuid id PK
        +uuid id_item_parcial FK
        +uuid id_pedido FK
        +string status_anterior
        +string status_novo
    }
    class entregas {
        +uuid id PK
        +uuid id_item_pedido FK
        +uuid id_item_parcial FK
        +decimal quantidade
        +string numero_nf
    }
    class divergencias {
        +uuid id PK
        +uuid id_pedido FK
        +uuid id_item_pedido FK
        +uuid id_item_parcial FK
        +string tipo
        +string status
    }

    fabricas "1" --> "0..*" fabrica_setores
    setores "1" --> "0..*" fabrica_setores
    setores "1" --> "0..*" maquinas
    fabricas "1" --> "0..*" pedidos
    pedidos "1" --> "1..*" itens_pedido
    itens_pedido "0..1" --> "0..*" itens_pedido : id_item_pai
    pedidos "1" --> "0..*" roteiros
    roteiros "0..*" --> "1" setores
    itens_pedido "1" --> "0..*" roteiros_item
    roteiros_item "0..*" --> "1" setores
    itens_pedido "1" --> "0..*" itens_parciais
    itens_parciais "0..1" --> "0..*" itens_parciais : id_parcial_origem
    itens_parciais "0..1" --> "0..*" itens_parciais : id_devolvido_de
    itens_parciais "0..*" --> "1" setores : id_setor_atual
    itens_parciais "1" --> "0..*" historico_itens_parciais
    itens_pedido "1" --> "0..*" entregas
    itens_parciais "0..1" --> "0..*" entregas
    pedidos "1" --> "0..*" divergencias
    itens_pedido "0..1" --> "0..*" divergencias
    itens_parciais "0..1" --> "0..*" divergencias
```
✅ Conferido no código.

## 3. MES: tabelas de integração

Três tabelas guardam a conversa com o av-hub: a fila do que o MES envia, os eventos que ele lê e o ponto onde a leitura parou.

| Tabela | Para quê | Selo |
|---|---|---|
| `integracao_avhub_envios` | Fila de saída da requisição de compra | ✅ |
| `requisicoes_compra_eventos_avhub` | Eventos lidos do av-hub, sem repetição | ✅ |
| `integracao_avhub_cursores` | Ponto onde a leitura parou | ✅ |

## 4. av-hub: tabelas do fluxo 0b

Liberação do pedido, requisições e ordens de compra, e as duas projeções que o hub lê do MES (status e custo por item).

```mermaid
classDiagram
    class pedidos_vendas_liberacao {
        +uuid codigo_empresa PK
        +string numero_pedido PK
        +boolean acompanhamento_qualidade
        +uuid liberado_por
        +datetime liberado_em
        +datetime importado_mes_em
        +string importado_mes_referencia
    }
    class requisicoes_compra {
        +uuid id PK
        +string numero_requisicao
        +uuid codigo_empresa
        +string material
        +decimal quantidade
        +date prazo_necessidade
        +string status
        +uuid id_ordem_compra FK
        +uuid id_origem
        +string cancelada_por_origem
    }
    class requisicoes_compra_eventos {
        +uuid id PK
        +uuid id_requisicao FK
        +uuid id_origem
        +string tipo
        +datetime registrado_em
        +string status_requisicao
        +uuid id_ordem_compra
        +json dados
    }
    class ordens_compra {
        +uuid id PK
        +uuid codigo_empresa
        +uuid id_requisicao FK
        +string status
        +string tipo_frete
        +string moeda
        +decimal valor_total_brl
        +uuid aprovado_por
        +string numero_pedido_omie
    }
    class ordens_compra_itens {
        +uuid id PK
        +uuid id_requisicao FK
        +string codigo_produto
        +decimal quantidade
        +decimal valor_unitario
        +string tipo_material
    }
    class ordens_compra_itens_vinculos {
        +uuid id PK
        +uuid id_ordem_compra_item FK
        +uuid id_ordem_compra FK
        +string numero_pedido_venda
        +decimal quantidade
    }
    class itens_pedido_status {
        +uuid id PK
        +uuid codigo_empresa
        +uuid id_item_parcial
        +string pedido_venda
        +string etapa
        +string setor_tipo
        +datetime ocorrido_em
    }
    class itens_pedido_custo {
        +uuid id PK
        +uuid codigo_empresa
        +string numero_pedido
        +int item
        +decimal custo_total
        +decimal custo_medio
        +boolean completo
        +json lotes
    }

    requisicoes_compra "0..*" --> "0..1" ordens_compra : id_ordem_compra
    requisicoes_compra "1" --> "0..*" requisicoes_compra_eventos
    ordens_compra "1" --> "1..*" ordens_compra_itens
    ordens_compra_itens "1" --> "0..*" ordens_compra_itens_vinculos
    ordens_compra "1" --> "0..*" ordens_compra_itens_vinculos
```
✅ Conferido no Dump Avhub de 14/10 (`core_vendas_faturamento.*`).

- O status da liberação não é uma coluna: é calculado a partir de `importado_mes_em`.
- A requisição criada só no av-hub não gera evento 🔴.
- O custo por item ainda grava por número do item; a troca para produto está pendente 🔴 Gustavo (BL-019).

## 5. Mapa dos dois bancos

Cada seta é uma conversa `INT-xx` entre os dois bancos. A seta mostra quem lê de quem.

```mermaid
flowchart LR
    subgraph AVHUB["Banco do av-hub"]
        A_VEN["pedidos_vendas e pedidos_vendas_liberacao"]
        A_REQ["requisicoes_compra e eventos"]
        A_OC["ordens_compra e itens"]
        A_ST["itens_pedido_status e itens_pedido_custo"]
        A_FL["core_fluxo, projecao da Torre"]
    end
    subgraph MES["Banco do MES, schema public"]
        M_PROD["pedidos, itens_pedido, itens_parciais, roteiros"]
        M_EST["materiais, lotes, saldos, reservas, movimentos, rncs, lote_custo"]
        M_CMP["requisicoes_compra, itens, recebimentos"]
        M_INT["integracao_avhub_envios, eventos e cursores"]
    end
    A_VEN -->|"INT-01 o MES le os liberados"| M_PROD
    M_CMP -->|"INT-02 PUT, fila de saida"| A_REQ
    A_REQ -->|"INT-03 o MES le os eventos"| M_INT
    A_OC -.->|"INT-04 referencia da OC, a construir"| M_CMP
    M_PROD -->|"INT-05 status por item, o hub le"| A_ST
    M_EST -->|"INT-06 custo, 404 hoje"| A_ST
    M_PROD -.->|"INT-07 feed da Torre, 404 hoje"| A_FL
    M_PROD <-->|"reserva por parcial"| M_EST
    M_CMP <-->|"lote nasce da requisicao"| M_EST
```
✅ Setas cheias existem. 🔴 Setas tracejadas e `INT-06` ainda não funcionam. Rota, chave e cursor de cada seta: [[Integracao-AvHub-MES]].

## Detalhe técnico

Nomes de tabela e coluna como estão no banco: no MES, o `@map` do Prisma de `api-pcp/prisma/models/`; no av-hub, o Dump Avhub de 14/10. Desenhados como `classDiagram` com `PK` e `FK` nos atributos (o `erDiagram` do mermaid não aceita estilo por tabela).

### 1. MES: Estoque e Compras

Selo ✅ `estoque.prisma`, `compras.prisma`. Conferido: `depositos.codigo_empresa` existe agora (`estoque.prisma:69`; o v1 marcava L-09 como pendente); `lote_custo` existe (`estoque.prisma:394-423`); `recebimentos_itens.id_localizacao` e `id_lote` não têm FK no schema (`compras.prisma:218-240`). Em `lote_custo` só a carga inicial grava 🔴.

### 2. MES: Produção

Selo ✅ `producao.prisma`, `fabricas.prisma`. `fabrica_setores` tem PK composta `(id_fabrica, id_setor)` ✅ `fabricas.prisma:158`. Não aparecem `pedido_embalagens`, `pedido_embalagem_pallets`, `pedido_anexos`, `item_parcial_anexos`, `item_parcial_observacoes`, `pedidos_excluidos`, `perfil_setores`, `operadores`.

### 3. MES: tabelas de integração

| Tabela | Colunas-chave | Para quê | Selo |
|---|---|---|---|
| `integracao_avhub_envios` | `id` PK, `tipo`, `id_origem`, `corpo` json, `status`, `tentativas`, `proxima_tentativa_em`, `http_status`, `ultimo_erro` | Fila de saída do PUT do contrato 34; índice `(status, proxima_tentativa_em)` | ✅ `integracao.prisma:33-60` |
| `requisicoes_compra_eventos_avhub` | `id` PK (id do evento do hub), `id_origem`, `id_requisicao_avhub`, `tipo`, `registrado_em`, `status_requisicao`, `dados` json, `processado_em`, `acao` | Eventos lidos do contrato 35, gravados por `id_evento` | ✅ `integracao.prisma:69-110` |
| `integracao_avhub_cursores` | `chave` PK (`requisicoes-eventos`), `alterado_desde`, `apos_id` | Cursor do polling | ✅ `integracao.prisma:112-120` |

### 4. av-hub: tabelas do fluxo 0b

Selo ✅ Dump Avhub de 14/10 (`core_vendas_faturamento.*`). Observações:

- `pedidos_vendas_liberacao` não tem coluna de status: `pendente`, `liberado` e `importado` são calculados pela view `vw_pedidos_liberacao` a partir de `importado_mes_em`.
- `requisicoes_compra.id_origem` é o id do `requisicoes_compra_itens` do MES; vale só para a origem MES. `requisicoes_compra_eventos.id_origem` é `NOT NULL`, por isso a requisição criada só no av-hub não gera evento 🔴 ([[Integracao-AvHub-MES]]).
- `itens_pedido_custo` ainda grava por `item integer` no dump; a migration 047b troca para produto 🔴 Gustavo (BL-019).
- `itens_pedido_status` e `itens_pedido_custo` são projeções lidas do MES pelos jobs de 90 s; `ordens_compra_itens_vinculos` liga o item da OC ao pedido de venda (contrato [[LOG-14b-Compras-Vinculo-Pedido-Venda]]).

### 5. Mapa dos dois bancos

Selo ✅ nas setas cheias; 🔴 nas tracejadas e em `INT-06`. Ver [[Integracao-AvHub-MES]] para rota, chave e cursor de cada seta.
