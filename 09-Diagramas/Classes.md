---
tags: [diagramas, classes, uml, mes, estoque, comercial]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Robert
fontes: [v1 Diagramas-UML (1, 2, 3, 23, 25), api-pcp 579a625 prisma/models/*.prisma, HUB b55ac55 api-comercial/prisma/models/*.prisma]
---

# Diagramas de classes

Redesenhados a partir do Prisma do `api-pcp` (`prisma/models/`) e do Prisma do `api-comercial` (HUB `b55ac55`), ambos de 14/10/2026. Mostram o que importa para o fluxo [[00-Fluxo-Mestre-0b]]: nem todos os campos aparecem. Colunas e tipos exatos: [[Modelo-de-Dados]] e [[Banco-MES]]. Destino de cada diagrama do v1: [[Indice-de-Diagramas]].

## 1. Estoque e compras no MES (E1 a E5, R0 a R4, Q1 a Q4)

```mermaid
classDiagram
    class Material {
        +uuid id
        +uuid codigoEmpresa
        +string codigoProdutoOmie
        +uuid idProdutoAvhub
        +NaturezaMaterial natureza
        +decimal pesoTeoricoUnitario
        +decimal toleranciaPeso
        +decimal pontoDePedido
    }
    class Lote {
        +string codigo
        +OrigemLote origem
        +uuid idLotePai
        +StatusQualidadeLote statusQualidade
        +string laudoUrl
        +string numeroNf
        +datetime quarentenaDesde
        +string motivoReprovacao
    }
    class LoteCusto {
        +OrigemCusto origem
        +decimal custoLiquidoUnitario
        +decimal valorUnitario
        +string moeda
        +decimal cotacao
        +decimal descontoPct
        +decimal freteUnit
        +uuid idItemOc
        +boolean cotacaoAConferir
    }
    class Rnc {
        +string motivo
        +string evidenciaUrl
        +decimal quantidadeReprovada
        +boolean notaDevolucaoPendente
    }
    class Deposito {
        +string codigo
        +string nome
        +uuid codigoEmpresa
    }
    class LocalizacaoEstoque {
        +string codigo
        +string descricao
    }
    class SaldoEstoque {
        +decimal quantidade
    }
    class MovimentoEstoque {
        +TipoMovimentoEstoque tipo
        +string motivo
        +decimal quantidade
        +uuid autorizadoPorId
    }
    class Reserva {
        +StatusReserva status
        +decimal quantidade
        +decimal quantidadeConsumida
        +string pedidoVenda
        +string ordemProducao
    }
    class ItemParcial {
        +decimal quantidade
        +StatusItemParcial status
        +boolean atendidoPeloEstoque
        +uuid idLoteCompra
    }
    class Fornecedor {
        +string codigoParceiroOmie
        +string nomeFantasia
        +string cpfCnpj
    }
    class RetiradaEstoque {
        <<proposta>>
        +string status
        +decimal quantidade
    }

    Material "1" --> "0..*" Lote : origina
    Lote "0..1" --> "0..*" Lote : cisao pai e filho
    Lote "1" --> "0..1" LoteCusto : custo opcional
    Lote "1" --> "0..*" Rnc : reprovacao gera
    Lote "1" --> "0..*" SaldoEstoque
    Lote "1" --> "0..*" MovimentoEstoque
    Deposito "1" --> "0..*" LocalizacaoEstoque
    SaldoEstoque "0..*" --> "1" LocalizacaoEstoque
    Reserva "0..*" --> "1" Lote
    Reserva "0..*" --> "0..1" ItemParcial : split atendido
    MovimentoEstoque "0..*" --> "0..1" Reserva : consumo
    ItemParcial "0..*" --> "0..1" Lote : espera a inspecao
    RetiradaEstoque "0..*" --> "1" Reserva : baixa na retirada E6
```

Selo ✅ para todas as classes exceto `RetiradaEstoque` (📝 decidida em 14/10, 🔴 sem código). Fontes: `estoque.prisma:61-423`. Mudanças em relação ao v1:

- `Deposito` ganhou `codigoEmpresa` e `nomeUnidade` (filial do depósito) ✅ `estoque.prisma:69-70`; o v1 dizia que não tinha.
- `LoteCusto` existe e tem `OrigemCusto` (`CARGA_INICIAL`, `OC`, `MANUAL`); só a carga inicial grava 🔴 (o Recebimento não grava custo).
- `Pesagem` não é classe: peso teórico, real e recontado ficam em `RecebimentoItem` (diagrama 3). Etiqueta é geração sob demanda (`src/estoque/etiquetas`), sem tabela. `OrdemSeparacao`, `ItemSeparacao`, `DevolucaoCliente` e `ContagemCiclica` não existem no schema e saíram deste vault (fora do fluxo 0b).
- `Fornecedor` é projeção local (`fornecedores`) sem ligação com o lote; o lote guarda `numeroNf` e o recebimento guarda o nome do fornecedor.
- `RetiradaEstoque` entra como proposta do nó E6: a baixa sai do recebimento da parcial na Embalagem e passa para a retirada. Nome e campos 🟡 a definir com o Robert.

## 2. Produção no MES (P1, P2, F1, Q7, X1 a X4)

```mermaid
classDiagram
    class Fabrica {
        +string codigo
        +string nome
        +TipoFabrica tipo
    }
    class Setor {
        +string codigo
        +string nome
        +boolean exigeMaquinaOperador
        +TipoSetor tipo
    }
    class Maquina {
        +string codigo
        +string nome
    }
    class Operador {
        +string nome
    }
    class Pedidos {
        +string pedidoVenda
        +string ordemProducao
        +string cliente
        +string idUnidade
        +StatusPedido status
        +Prioridade prioridade
        +SistemaOrigem sistema
        +boolean acompanhamentoQualidade
        +datetime importadoAvhubEm
    }
    class ItensPedido {
        +string codigo
        +decimal quantidade
        +decimal quantidadePendente
        +decimal quantidadeConcluida
        +string unidade
        +boolean inativo
    }
    class Roteiros {
        +int ordem
    }
    class RoteiroItem {
        +int ordem
    }
    class ItemParcial {
        +decimal quantidade
        +StatusItemParcial status
        +boolean retrabalho
        +boolean atendidoPeloEstoque
        +uuid idLoteCompra
    }
    class HistoricoItemParcial {
        +string statusAnterior
        +string statusNovo
        +string observacao
    }
    class Entrega {
        +decimal quantidade
        +string numeroNf
    }
    class PedidoEmbalagem {
        +string identificacao
        +int totalUnidades
    }
    class PedidoEmbalagemPallet {
        +string identificacao
        +decimal peso
    }
    class PedidoAnexo {
        +TipoAnexo tipo
        +string url
    }
    class Divergencia {
        +TipoDivergencia tipo
        +StatusDivergencia status
        +string descricao
    }

    Fabrica "1" --> "0..*" Pedidos
    Fabrica "0..*" --> "0..*" Setor : FabricaSetor
    Setor "1" --> "0..*" Maquina
    Pedidos "1" --> "1..*" ItensPedido
    ItensPedido "0..1" --> "0..*" ItensPedido : idItemPai
    Pedidos "1" --> "0..*" Roteiros
    Roteiros "0..*" --> "1" Setor
    ItensPedido "1" --> "0..*" RoteiroItem : roteiro proprio do item
    RoteiroItem "0..*" --> "1" Setor
    ItensPedido "1" --> "0..*" ItemParcial
    ItemParcial "0..1" --> "0..*" ItemParcial : idParcialOrigem split
    ItemParcial "0..1" --> "0..*" ItemParcial : idDevolvidoDe
    ItemParcial "0..*" --> "1" Setor : setorAtual
    ItemParcial "0..*" --> "0..1" Maquina
    ItemParcial "0..*" --> "0..1" Operador
    ItemParcial "1" --> "0..*" HistoricoItemParcial
    ItensPedido "1" --> "0..*" Entrega
    ItemParcial "0..1" --> "0..*" Entrega
    Pedidos "1" --> "0..*" PedidoEmbalagem
    PedidoEmbalagem "1" --> "0..*" PedidoEmbalagemPallet
    Pedidos "1" --> "0..*" PedidoAnexo
    Pedidos "1" --> "0..*" Divergencia
    ItemParcial "0..1" --> "0..*" Divergencia
```

Selo ✅ `producao.prisma:88-620`, `fabricas.prisma:36-170`. Observações conferidas:

- O roteiro existe em dois níveis: `Roteiros` (por pedido) e `RoteiroItem` (por item) ✅ `producao.prisma:262-292`.
- O setor Estoque é inserido pelo backend como etapa 1 de todo roteiro (`GET /pedidos/setor-estoque-fixo` ✅ `pedidos.controller.ts:92`).
- `Pedidos.importadoAvhubEm` é a marca do `POST /pedidos_liberados/:n/importado` ✅ `pedidos.service.ts:133`.
- Também existem `PedidoExcluido` (snapshot de exclusão), `ItemParcialAnexo`, `ItemParcialObservacao` e `PerfilSetor`; não aparecem para não poluir.
- Tipo de pedido no av-hub: pedido manual (`LOG-45`) não participa deste modelo ([[Pedido-Manual]]).

## 3. Compras, recebimento e integração com o av-hub (P3, R0 a R6)

```mermaid
classDiagram
    class RequisicaoCompra {
        +string codigo
        +StatusRequisicaoCompra status
        +string pedidoVenda
        +date prazoNecessidade
        +string pedidoCompra
        +date previsaoEntrega
        +datetime compradoEm
        +datetime liberadaRecebimentoEm
        +string nfChegada
        +string chaveNfChegada
        +datetime chegadaEm
        +string canceladaPor
    }
    class RequisicaoCompraItem {
        +TipoItemRequisicao tipo
        +decimal quantidade
        +decimal quantidadeRecebida
        +uuid avhubIdRequisicao
        +string avhubNumero
        +string etapaCompra
        +string numeroOc
        +datetime ocAprovadaEm
        +datetime despachadaEm
        +string nfFornecedor
        +boolean ocorrenciaAberta
    }
    class Recebimento {
        +string codigo
        +StatusRecebimento status
        +string numeroNf
        +string chaveAcessoNf
        +string fornecedor
        +string laudoUrl
        +string motivoDecisao
    }
    class RecebimentoItem {
        +decimal quantidadePendente
        +decimal quantidadeNf
        +decimal quantidadeContada
        +decimal quantidadeRecontada
        +decimal pesoTeorico
        +decimal pesoReal
        +decimal toleranciaPeso
        +uuid idLote
    }
    class RecebimentoDivergencia {
        +TipoDivergenciaRecebimento tipo
        +string descricao
        +string etapa
    }
    class IntegracaoAvhubEnvio {
        +TipoEnvioAvhub tipo
        +uuid idOrigem
        +StatusEnvioAvhub status
        +int tentativas
        +datetime proximaTentativaEm
        +int httpStatus
    }
    class RequisicaoCompraEventoAvhub {
        +uuid idOrigem
        +uuid idRequisicaoAvhub
        +string tipo
        +string statusRequisicao
        +string numeroPedidoOmie
        +string acao
    }
    class IntegracaoAvhubCursor {
        +string chave
        +string alteradoDesde
        +uuid aposId
    }
    class ItemParcial
    class Lote
    class Material

    RequisicaoCompra "1" --> "1..*" RequisicaoCompraItem
    RequisicaoCompra "1" --> "0..*" Recebimento
    RequisicaoCompra "0..*" --> "1" ItemParcial : parcial de origem
    RequisicaoCompraItem "0..*" --> "1" Material
    RequisicaoCompraItem "1" --> "0..*" Lote : recebido como
    Recebimento "1" --> "1..*" RecebimentoItem
    Recebimento "1" --> "0..*" RecebimentoDivergencia
    Recebimento "0..*" --> "1" ItemParcial
    RecebimentoItem "0..*" --> "1" RequisicaoCompraItem
    RequisicaoCompraItem ..> IntegracaoAvhubEnvio : PUT LOG-34 por idOrigem
    RequisicaoCompraItem ..> RequisicaoCompraEventoAvhub : eventos LOG-35 por idOrigem
    RequisicaoCompraEventoAvhub ..> IntegracaoAvhubCursor : cursor requisicoes-eventos
```

Selo ✅ `compras.prisma:51-262`, `integracao.prisma:33-120`. Enums: `StatusRequisicaoCompra` (`ABERTA`, `EM_COMPRA`, `RECEBIDA_PARCIAL`, `RECEBIDA`, `CANCELADA`), `TipoItemRequisicao` (`PRODUTO_FINAL`, `MATERIA_PRIMA`), `TipoDivergenciaRecebimento` (`QUANTIDADE`, `DESCRICAO`, `PESO`, `AVARIA`), `StatusEnvioAvhub` (`PENDENTE`, `ENVIADO`, `RECUSADO`, `FALHOU`), `TipoEnvioAvhub` (`REQUISICAO_COMPRA`). Mudanças em relação ao v1 (08/10):

- Entraram os campos de **Compras · CCP** (14/10): `etapaCompra`, `numeroOc`, `numeroPedidoOmie`, `previsaoChegada`, `ocAprovadaEm`, `despachadaEm`, `nfFornecedor`, `transportadora`, `ocorrenciaAberta` no item; `pedidoCompra`, `previsaoEntrega`, `compradoEm`, `liberadaRecebimento*`, `nfChegada`, `chaveNfChegada`, `chegadaEm`, `canceladaPor` na requisição.
- O registro manual da compra (`PATCH :id/compra`) saiu; `pedidoCompra`, `fornecedor` e `previsaoEntrega` agora são espelho do av-hub, nunca digitados ✅ `compras.prisma` (comentário do bloco CCP).
- `idLocalizacao` e `idLote` de `RecebimentoItem` não têm FK no schema; o lote só nasce em `CONCLUIDO` ou `ACEITO`.

## 4. api-comercial (schema `core_comercial`, Comercial e Suprimentos)

Fora do fluxo 0b; ver [[Comercial-Suprimentos]].

```mermaid
classDiagram
    class EmpresaEmissora
    class UsuarioComercial {
        +uuid idUsuario
        +string emailLogin
        +boolean responsavelProposta
        +boolean ativo
    }
    class Cliente
    class ClienteContato
    class Proposta {
        +StatusProposta status
        +int revisao
        +Unidade unidade
    }
    class PropostaItem
    class PropostaEvento {
        +TipoEventoProposta tipo
    }
    class PropostaVersao
    class SolicitacaoCusto {
        +StatusSolicitacao status
    }
    class CategoriaSuprimento
    class Produto
    class Fornecedor
    class ApelidoFornecedor
    class FornecedorCategoria
    class Certificado
    class Oferta {
        +FonteOferta fonte
        +StatusOferta status
    }
    class ParametroCusto
    class TabelaCustoTelha
    class OrdemCompra
    class ItemOrdemCompra
    class SincronizacaoOmie

    EmpresaEmissora "1" --> "0..*" Proposta
    Cliente "1" --> "0..*" Proposta
    Cliente "1" --> "0..*" ClienteContato
    Proposta "1" --> "0..*" PropostaItem
    Proposta "1" --> "0..*" PropostaEvento
    Proposta "1" --> "0..*" PropostaVersao
    CategoriaSuprimento "1" --> "0..*" Produto
    Produto "1" --> "0..*" Oferta
    Fornecedor "1" --> "0..*" Oferta
    Fornecedor "1" --> "0..*" ApelidoFornecedor
    Fornecedor "1" --> "0..*" Certificado
    Fornecedor "1" --> "0..*" FornecedorCategoria
    CategoriaSuprimento "1" --> "0..*" FornecedorCategoria
    Fornecedor "1" --> "0..*" OrdemCompra
    OrdemCompra "1" --> "0..*" ItemOrdemCompra
    Produto "1" --> "0..*" ItemOrdemCompra
```

Selo ✅ `api-comercial/prisma/models/*.prisma` (HUB `b55ac55`). Mudança: `PerfilComercial` (v1) virou `UsuarioComercial`, mapeada para a tabela `perfis_comerciais`, sem coluna de cargo (migration `20261013140000_usuarios_comerciais_diretorio`) ✅ `empresas.prisma:61-78`. `StatusProposta` (`ABERTA`, `PARCIAL`, `FECHADA`, `PERDIDA`), `StatusSolicitacao` (`ABERTA`, `RESPONDIDA`, `SEM_FORNECEDOR`, `CANCELADA`), `StatusOferta` (`VIGENTE`, `VENCIDA`, `INVALIDADA`, `HISTORICA`), `FonteOferta` (`MANUAL`, `MAPA_COTACAO`, `PEDIDO_OMIE`, `MIGRACAO`). O enum `CargoComercial` do v1 não existe mais.

## O que não foi redesenhado

O diagrama 3 do v1 (RBAC e comercial do av-hub: `Usuario`, `Perfil`, `Tela`, `Funcionario`, `Unidade`, `PedidoVenda`…) não foi refeito aqui: pertence ao banco do av-hub e vive em [[Banco-AvHub]] e [[RBAC-e-Permissoes]]. Ver [[Indice-de-Diagramas]].
