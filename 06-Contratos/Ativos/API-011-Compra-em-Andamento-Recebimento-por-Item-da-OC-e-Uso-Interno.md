---
id: API-011
aliases: ["Contrato 011", "011-Compra-em-Andamento-Recebimento-por-Item-da-OC-e-Uso-Interno"]
tags: [contrato, contrato-api, mes, integracao-av-hub-mes, compras, recebimento, estoque, sql, prisma]
criado: 2026-10-15
atualizado: 2026-10-19
status: parcial
sistemas: [mes-banco, mes-api, mes-front]
dono: "Robert"
etapa_0b: [P1, P2, P3, E1, R0, R1, R4]
fontes: ["N14-20, N14-28, N14-29, N14-30, N14-31, N14-32 (Registro-de-Decisoes)", "Proposta-OP-Lote-Compra-em-Andamento.pdf (Robert, 15/10/2026)", "api-pcp origin/develop 6914fe9 (K4, PR #59): prisma/models/integracao.prisma (OcReferencia, OcReferenciaItem), src/integracao-avhub/oc-referencia-avhub.service.ts", "api-pcp develop: prisma/models/compras.prisma (RequisicaoCompra, RequisicaoCompraItem, Recebimento, RecebimentoItem), prisma/models/estoque.prisma (Material, Lote, LoteCusto, Reserva), src/compras/compras.service.ts:135-218,305-351,356-399, recebimento.service.ts:135,420,452, circuito-compra.ts:62-99,166-250", "API-004, API-007, API-008, API-009, API-010"]
criado_original: 2026-10-15
---

# Contrato de API 011 — Compra em andamento, recebimento por item da OC e uso interno (MES)

> **Onde atua:** MES: banco, API, front

> [!abstract] Resumo em linguagem natural
> **O que é:** Define como o MES (sistema de produção) sabe o que o Compras já está comprando para cada pedido e como dá entrada na mercadoria por item da Ordem de Compra (OC), com ou sem requisição, inclusive uso interno.
> **Quem é afetado:** PCP (aviso ao requisitar, evitando compra duplicada), Recebimento (recebe por NF e por item de OC) e Estoque (saldo futuro e entradas de uso interno).
> **Situação:** Proposta, dono Robert. A leitura da OC (K4) já está na `develop` (✅); o cruzamento, o recebimento por NF e o uso interno não existem (🔴). Nomes de rotas são propostas.
> **Exemplo:** Pedido que precisa de 8 unidades, com 3 já em OC aprovada: 3 ficam vinculadas à OC e 5 são requisitadas ao hub.

> [!info] Situação em 15/10/2026
> **Status:** `proposta` · **Pasta:** `Ativos` · **Nós do 0b:** P1, P2, P3, E1, R0, R1, R4 · **Dono:** Robert (MES). O Gustavo entrega as leituras do hub ([[API-009-Referencia-Requisicao-Hub-Integracao-MES]] e [[API-010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto]]).
>
> - ✅ **K4 na `develop`** do `api-pcp` (PR #59, `6914fe9`, 15/10): o MES lê `GET /ordens-compra/referencia` e grava `OcReferencia` e `OcReferenciaItem` (`id` do item = `id_item_oc`, `destino` JSON, `idOrigem`, `finalidade`, valores). É a base deste contrato. (O checkout local de `develop` pode estar atrás do `origin/develop`: conferir com `git fetch`.)
> - 🔴 **Falta o resto:** o cruzamento e o abate, o aviso ao requisitar, a leitura da requisição do hub, o saldo futuro, o recebimento por item da OC e por NF, e o uso interno.
> - 📝 Decisões do Nathan que ele implementa: **N14-29** (proposta do Robert aceita), **N14-30** (uso interno aprovado), **N14-31** (tudo da mesma unidade). Estimativas do Robert (±30%): BL-051 4,0 pd, API-009 no MES 1,0, recebimento por NF 4,0, uso interno 0,5 (**dentro** da conta do Ciclo 1); BL-049 1,5 e BL-050 1,5 (**fora** da conta, aguardando decisão).
> - ✅ **SQL escrito e validado** em banco descartável (PostgreSQL 18, com tabelas-esqueleto das que a migration referencia): [[0001-compra-em-andamento.sql]] em `API-011-anexos/`. Validado: a migration aplica sem erro e os `CHECK` se comportam (recebimento com requisição **ou** com OC, nunca com as duas nem sem nenhuma; item de recebimento de requisição **ou** de OC; uso interno com quantidade positiva). **Não validado:** contra o schema real do MES (o checkout do Prisma gera o SQL final; esta é a proposta de desenho) e nenhum código de rota ou serviço existe ainda.
>
> Selos em [[Regras-do-Vault]]. Nomes de rota, modelo e tela são **propostas** para o Robert ajustar; as **regras** são as decididas.

## Por quê

Quando o Compras compra antes de o PCP movimentar o pedido, o MES não sabe e pode requisitar de novo. E a mercadoria dessa compra não tem caminho de entrada: o `Recebimento` do MES exige requisição e parcela (`Recebimento.idRequisicao` e `idItemParcial` são `NOT NULL`). Este contrato deixa o MES saber **o que já está em compra** para cada pedido e produto, e dá entrada à mercadoria **por item de OC**, com ou sem requisição.

## 1. O que o MES enxerga de compra

| Fonte | O que é | Chega por | Estado |
|---|---|---|---|
| OC aprovada (e cancelada depois de aprovada) | `OcReferencia` e itens, com `destino[]` e `finalidade` | `GET /ordens-compra/referencia` (K4) | ✅ na `develop` |
| Requisição do hub com pedido de venda, sem OC ou com OC ainda em aprovação | `RequisicaoHubReferencia` | `GET /compras/requisicoes/referencia` (API-009) | 🔴 |
| Requisição do MES ainda aberta | `RequisicaoCompra` (origem `MES`) | tabela do MES | ✅ |
| Parcela já coberta por OC | `RequisicaoCompra` de origem `HUB` | criada pelo MES (seção 5, R2) | 🔴 |

A OC em `aguardando_aprovacao` **não** vem pela referência da OC; a requisição `atendida` do API-009 cobre esse intervalo, com `situacao_ordem_compra`.

## 2. Chave do cruzamento

**Unidade do pedido + número do pedido + `codigo_produto`** (o código humano, que é o que o item do pedido do MES guarda em `ItensPedido.codigo`; `@@unique([idPedido, codigo])` garante um item por produto em cada ordem). Tudo da **mesma unidade** (N14-31).

- O item da OC traz `codigo_produto_omie`. O MES o resolve para o `codigo_produto` pelo `Material` da unidade (`@@unique([codigoEmpresa, codigoProdutoOmie])`; o `Material` guarda os dois códigos). ❓ Robert confirma a resolução quando o `Material` ainda não existe (cair no `upsertMaterialDoAvhub`, como a `requisitar` faz hoje).
- A requisição do hub já traz `material` (= `codigo_produto`) e `codigo_produto_omie` resolvido (API-009).
- `destino[]` do item da OC: `{ tipo: "pedido_venda", numero_pedido_venda, codigo_empresa_pv, quantidade }` ou `{ tipo: "estoque", quantidade }`.

## 3. Dados

Migration proposta (nome sugerido `20261016120000_compra_em_andamento`, depois da K4): [[0001-compra-em-andamento.sql]]. Resumo em Prisma:

```prisma
enum OrigemRequisicao { MES HUB }

model RequisicaoCompra {
  // ... campos de hoje ...
  origem OrigemRequisicao @default(MES)   // HUB = parcela coberta por OC; NUNCA vai ao av-hub
}

model RequisicaoCompraItem {
  // ... campos de hoje ...
  idOcItem String?           @map("id_oc_item") @db.Uuid
  ocItem   OcReferenciaItem? @relation(fields: [idOcItem], references: [id], onDelete: SetNull)
  @@index([idOcItem])
}

model RequisicaoHubReferencia {           // projeção do API-009 (tabela própria)
  id                  String   @id @db.Uuid          // id_requisicao do hub
  codigoEmpresa       String   @map("codigo_empresa") @db.Uuid
  numeroRequisicao    String   @map("numero_requisicao") @db.VarChar(30)
  status              String   @db.VarChar(15)
  finalidade          String   @db.VarChar(15)
  material            String   @db.VarChar(60)
  codigoProdutoOmie   String?  @map("codigo_produto_omie") @db.VarChar(40)
  descricao           String?
  quantidade          Decimal  @db.Decimal(15, 4)
  unidadeMedida       String   @map("unidade_medida") @db.VarChar(10)
  prazoNecessidade    DateTime @map("prazo_necessidade") @db.Date
  numeroPedidoVenda   String   @map("numero_pedido_venda") @db.VarChar(30)
  idOrdemCompra       String?  @map("id_ordem_compra") @db.Uuid
  numeroOrdemCompra   String?  @map("numero_ordem_compra") @db.VarChar(30)
  situacaoOrdemCompra String?  @map("situacao_ordem_compra") @db.VarChar(24)
  alteradoEmAvhub     String   @map("alterado_em_avhub") @db.VarChar(40)
  createdAt           DateTime @default(now()) @map("created_at")
  sincronizadoEm      DateTime @updatedAt @map("sincronizado_em")
  @@index([codigoEmpresa, numeroPedidoVenda, material])
  @@map("requisicoes_hub_referencia")
}

model RecebimentoNf {                      // agrupa as conferências de uma NF
  id             String   @id @default(uuid()) @db.Uuid
  codigo         String   @unique @db.VarChar(30)      // RN-AAAAMMDD-NNNN
  numeroNf       String?  @map("numero_nf") @db.VarChar(60)
  chaveAcessoNf  String?  @map("chave_acesso_nf") @db.VarChar(44)
  fornecedor     String?  @db.VarChar(200)
  observacao     String?  @db.VarChar(500)
  conferidoPorId String   @map("conferido_por_id") @db.Uuid
  conferidoEm    DateTime @default(now()) @map("conferido_em")
  recebimentos   Recebimento[]
  @@index([chaveAcessoNf])
  @@map("recebimentos_nf")
}

model Recebimento {
  // idRequisicao e idItemParcial passam a ser opcionais (juntos); novo:
  idRecebimentoNf String? @map("id_recebimento_nf") @db.Uuid
  idOrdemCompra   String? @map("id_ordem_compra") @db.Uuid   // só no recebimento de OC sem requisição
  // CHECK: (requisição E parcela) OU (OC), nunca os dois, nunca nenhum
}

model RecebimentoItem {
  // idRequisicaoItem passa a ser opcional; novo:
  idOcItem   String? @map("id_oc_item") @db.Uuid   // opcional: CHECK exige idRequisicaoItem OU idOcItem (Robert, 19/10)
  usoInterno Boolean @default(false) @map("uso_interno")
  // CHECK: idRequisicaoItem OU idOcItem
}

model Lote {
  // novo: lote ligado ao item da OC (LoteCusto.idItemOc já existe)
  idOcItem String? @map("id_oc_item") @db.Uuid
  @@index([idOcItem])
}

model EntradaUsoInterno {                  // registrada, sem lote e sem saldo (N14-30)
  id                String   @id @default(uuid()) @db.Uuid
  codigo            String   @unique @db.VarChar(30)   // UI-AAAAMMDD-NNNN
  idRecebimentoItem String   @unique @map("id_recebimento_item") @db.Uuid
  idOcItem          String?  @map("id_oc_item") @db.Uuid
  idMaterial        String   @map("id_material") @db.Uuid
  quantidade        Decimal  @db.Decimal(14, 4)
  unidadeMedida     String   @map("unidade_medida") @db.VarChar(20)
  setorSolicitante  String?  @map("setor_solicitante") @db.VarChar(100)   // ver Q4
  observacao        String?  @db.VarChar(500)
  recebidoPorId     String   @map("recebido_por_id") @db.Uuid
  recebidoEm        DateTime @default(now()) @map("recebido_em")
  @@index([idMaterial])
  @@map("entradas_uso_interno")
}
```

**Mudanças no código que isso força** (todas em `api-pcp/src`):
- `ComprasService.enfileirarRequisicao` (fila do contrato 34): **pular** requisição com `origem = HUB`. Critério de aceite 10.
- `ComprasService.esperados()` hoje fica com a requisição **mais recente por `idItemPedido`**; com duas requisições do mesmo item (a coberta pela OC e a que sobra), isso erra. Passa a casar a requisição **pela parcela** (`RequisicaoCompra.idItemParcial`). Sem pd próprio — soma ao BL-051 (Robert, 19/10).
- `Recebimento.requisicao` e `Recebimento.itemParcial` viram relações opcionais: ajustar `RecebimentoService` (`conferir`, `recontar`, `decidir`, `darEntrada`, `criarRecebimento`) para tratar os dois caminhos.

## 4. Jobs

### 4.1 Requisição do hub (novo, API-009)

Serviço novo no módulo `integracao-avhub`, espelho do `oc-referencia-avhub.service.ts` do K4 (mesmas constantes): `AVHUB_REQ_INTERVALO_MIN` (padrão 5), uma rodada 15 s após subir, rodada compartilhada, `IntegracaoAvhubCursor` com `chave = 'requisicoes-referencia'`, `SOBREPOSICAO_MS = 5 min`, `LIMITE = 500`, `INICIO_PADRAO`. Chamada: `GET {API_URL}/compras/requisicoes/referencia?alterado_desde=…&apos_id=…&limit=500` com `x-api-key`. UPSERT por `id`. Linha com `visivel_ao_pcp = false` → **apaga** da projeção. A leitura do `POST /compras/requisicoes/sincronizar` dispara também este job, como já dispara o da OC.

### 4.2 K4: o que falta tratar (OC cancelada e item removido) — sem pd, soma ao BL-051 (Robert, 19/10)

Hoje o K4 grava a OC `cancelada` como qualquer outra e marca `removidoEm` no item que sumiu, **sem efeito nenhum** no resto. Passa a: ao gravar OC `cancelada` ou item `removidoEm`, **desfazer os vínculos** dela: cancelar as `RequisicaoCompra` de origem `HUB` ligadas (`idOcItem`), devolver a parcela a Requisições com aviso (mesmo comportamento da OC cancelada de requisição do MES, `requisicao-avhub.eventos.ts`) e tirar a OC dos esperados.

## 5. Rotas do MES (propostas)

Erro: padrão Nest do MES, `{ statusCode, message, error }` (`message` string em português; array nas validações de DTO). Permissões: as telas e ações que já existem (`movimentacoes`, `logistica-entrada` via `ensurePodeAtuar`).

### R1. `GET /compras/em-andamento` — `movimentacoes:visualizar`

Query: `codigoEmpresa` (uuid), `pedidoVenda` (texto), `codigoProduto` (texto). Devolve o que já cobre aquele pedido e produto:

```json
{
  "codigoEmpresa": "759979bd-2b2d-41f2-b1b7-db6fae89ee59",
  "pedidoVenda": "27605",
  "codigoProduto": "CH45025X6X1K",
  "ocs": [
    { "idOcItem": "uuid", "idOrdemCompra": "uuid", "numeroOc": "OC-000120", "situacao": "aprovada",
      "previsaoChegada": "2026-10-22", "quantidadeDoPedido": 5, "jaVinculada": 0, "jaRecebida": 0, "disponivel": 5 }
  ],
  "requisicoesHub": [
    { "idRequisicao": "uuid", "numero": "REQ-000412", "status": "atendida", "quantidade": 3,
      "prazoNecessidade": "2026-11-05", "situacaoOc": "aguardando_aprovacao", "numeroOc": "OC-000131" }
  ],
  "requisicoesMes": [ { "codigo": "RC-20261014-0007", "status": "ABERTA", "quantidade": 2 } ],
  "totalAbativel": 5
}
```

`totalAbativel` soma só o `disponivel` das OCs **aprovadas** (seção 6). `requisicoesHub` e OC `aguardando_aprovacao` entram só para **mostrar e avisar**.

### R2. `POST /compras/requisicoes` (estendida) — `movimentacoes:editar`

Hoje: `RequisitarCompraDto { idItemParcial, itens[{ idProdutoAvhub, quantidade, tipo }] (mín. 1), prazoNecessidade, observacao? }`. Passa a:

```json
{
  "idItemParcial": "uuid",
  "prazoNecessidade": "2026-11-05",
  "observacao": "…",
  "vinculosOc": [ { "idOcItem": "uuid", "quantidade": 5, "tipo": "PRODUTO_FINAL" } ],
  "itens": [ { "idProdutoAvhub": "uuid", "quantidade": 3, "tipo": "PRODUTO_FINAL" } ]
}
```

- `itens` pode ser vazio **se** houver `vinculosOc` (a parcela está inteira coberta pela OC: caso A do exemplo). Pelo menos um dos dois.
- **Numa transação**: trava os `oc_referencia_itens` envolvidos (`SELECT ... FOR UPDATE`), recalcula o `disponivel` (seção 6) e recusa se a quantidade passar (`409 "A OC OC-000120 só tem 5 un livres para o pedido 27605"`).
- **Divide a parcela** (rota `split` já existe) em duas: a parte **coberta** e a que **sobra**. Cada parcela tem **uma** requisição: a coberta ganha uma `RequisicaoCompra` de `origem = HUB` (`RequisicaoCompraItem.idOcItem`, `etapaCompra = COM_FORNECEDOR`, `numeroOc`, `previsaoChegada` e `ocAprovadaEm` da OC, `status = EM_COMPRA`, `compradoEm`), **não enfileirada**; a que sobra segue o fluxo de hoje (origem `MES`, enfileirada, contrato 34).
- Ambas vão para Compras · CCP (`moverParcial`), a coberta já como "com o fornecedor" e entra nos esperados.
- Resposta: `{ requisicoes: [{ id, codigo, origem, idItemParcial, quantidade }], parciais: [...] }`.

### R3. `GET /compras/oc-esperadas` — `movimentacoes:visualizar`

Query: `codigoEmpresa?`, `q?` (OC, produto, NF do fornecedor). Os itens de OC aprovada que ainda têm **quantidade sem requisição** esperando entrada:

```json
{ "data": [ {
    "idOcItem": "uuid", "idOrdemCompra": "uuid", "numeroOc": "OC-000120", "numeroPedidoOmie": "46618",
    "codigoEmpresa": "…", "finalidade": "estoque", "previsaoChegada": "2026-10-22",
    "codigoProduto": "CH45025X6X1K", "codigoProdutoOmie": "9764577293", "descricao": "CHAPA …",
    "unidadeMedida": "PC", "quantidade": 20,
    "destino": [ { "tipo": "pedido_venda", "numero_pedido_venda": "27605", "quantidade": 5 }, { "tipo": "estoque", "quantidade": 15 } ],
    "quantidadeComRequisicao": 5, "quantidadeRecebida": 0, "quantidadeEsperada": 15, "usoInterno": false } ] }
```

`quantidadeEsperada` = `quantidade` − o que as requisições (MES e HUB) já cobrem − o já recebido. Item `usoInterno = true` quando a `finalidade` da OC é `uso_interno` (o `destino` do hub vem `estoque`; o MES separa pela `finalidade`).

### R4. `POST /compras/recebimentos/nf` — `movimentacoes:editar` + `pode_atuar` na Logística de entrada

A doca informa a NF **uma vez** e marca o que chegou nela, de várias requisições e OCs:

```json
{
  "numeroNf": "123456", "chaveAcessoNf": "35261012345678000190550010001234561000123456",
  "fornecedor": "AÇOS FORNECEDOR LTDA", "observacao": "…",
  "conferencias": [
    { "idRequisicao": "uuid", "idItemParcial": "uuid",
      "itens": [ { "idRequisicaoItem": "uuid", "quantidadeNf": 5, "quantidadeContada": 5, "pesoReal": 120.5, "idLocalizacao": "uuid" } ],
      "divergencias": [] },
    { "idOrdemCompra": "uuid",
      "itens": [ { "idOcItem": "uuid", "quantidadeNf": 15, "quantidadeContada": 15, "pesoReal": 410, "idLocalizacao": "uuid" } ],
      "divergencias": [] }
  ]
}
```

Resposta `201`:
```json
{ "id": "uuid", "codigo": "RN-20261022-0001", "numeroNf": "123456",
  "recebimentos": [
    { "id": "uuid", "codigo": "RB-…", "status": "CONCLUIDO", "idRequisicao": "uuid",
      "lotes": [ { "id": "uuid", "codigo": "LT-…", "quantidade": 5, "statusQualidade": "PENDENTE" } ], "entradasUsoInterno": [] },
    { "id": "uuid", "codigo": "RB-…", "status": "CONCLUIDO", "idOrdemCompra": "uuid",
      "lotes": [ { "id": "uuid", "codigo": "LT-…", "quantidade": 15, "statusQualidade": "PENDENTE" } ], "entradasUsoInterno": [] } ] }
```

- **Uma transação.** Cria o `RecebimentoNf` e **um `Recebimento` por requisição** (o caminho de hoje, `conferir`) e **um por OC** sem requisição (`idOrdemCompra`).
- Mantém tudo que a conferência de hoje faz: confere contra a NF (chave de 44 dígitos, N14-04), peso real contra o teórico (tolerância de 5%), divergências de `QUANTIDADE`, `DESCRICAO`, `PESO`, `AVARIA`, recontagem e decisão do PCP. `recontar` e `decidir` continuam **por `Recebimento`**.
- **Um lote por item da OC** (`Lote.idOcItem`), `origem RECEBIMENTO`, `statusQualidade PENDENTE` (quarentena), com o **custo da OC** (`LoteCusto`, origem `OC`, `idItemOc`, `cotacaoAConferir`; K5, [[API-008-Custo-do-Lote-no-MES]]). Unidade de medida diferente da da OC: o lote nasce sem custo e sinalizado.
- **Recebimento parcial** mantém o restante de cada item como esperado.
- Item com `usoInterno`: **não cria lote nem saldo**; grava `RecebimentoItem.usoInterno = true` e uma `EntradaUsoInterno` (seção 8). Sem quarentena.
- A rota atual `POST /compras/recebimentos` (uma requisição) **continua**.

### R5. `GET /estoque/saldo-futuro` — `saldo:visualizar`

Query: `codigoEmpresa`, `idMaterial?`. Por material, o saldo atual e o que já está comprado para o **estoque** (OC aprovada, parte `destino` `estoque`, menos o recebido), **fora o uso interno**:

```json
{ "data": [ { "idMaterial": "uuid", "codigoProduto": "CH45025X6X1K", "descricao": "CHAPA …",
    "saldoAtual": 12, "saldoFuturo": 27,
    "ocs": [ { "numeroOc": "OC-000120", "previsaoChegada": "2026-10-22", "quantidadeAReceber": 15 } ] } ] }
```

`GET /estoque/saldo/disponivel-parcial/:idItemParcial` (Atendimento) passa a incluir `sugeridos` (lotes recebidos de OC com destino a este pedido, **sem reservar**, N14-29) e `saldoFuturo` do material.

### R6. `GET /estoque/entradas-uso-interno` — `saldo:visualizar`

Query: `de`, `ate`, `codigoEmpresa?`, `setor?`. Lista as entradas de uso interno (a "entrada registrada, sem saldo", visível no Estoque).

## 6. Cálculo da compra em andamento

Para um item de OC `i` e um pedido `P` (unidade `E`):

```
destinoP(i)   = Σ destino[tipo=pedido_venda, numero_pedido_venda=P, codigo_empresa_pv=E].quantidade
vinculado(i)  = Σ RequisicaoCompraItem.quantidade onde idOcItem = i e a requisição (origem HUB) não está CANCELADA
              + a quantidade da requisição do MES ligada a i por idOrigem (K4)
recebido(i,P) = (Σ Lote.quantidade onde idOcItem = i, origem RECEBIMENTO, não reprovado) × destinoP(i) / quantidade(i)   -- 🔴 rateio provisório (Q2)
disponivel(i) = max(0, destinoP(i) − vinculado(i) − recebido(i,P))
```

Só entra OC `aprovada` (a `cancelada` e o item `removidoEm` não contam). **Concorrência:** a rota R2 faz `SELECT ... FOR UPDATE` nas linhas de `oc_referencia_itens` envolvidas antes de recalcular, para duas parcelas simultâneas não usarem as mesmas unidades. A requisição do hub e a OC `aguardando_aprovacao` **não abatem nem vinculam**, só mostram e avisam (N14-29).

**Exemplo (pedido 27605):**

| Item | Precisa | Já em OC aprovada com destino ao pedido | Resultado |
|---|---|---|---|
| A | 5 | 5 (OC-120) | Nada a comprar: a parcela fica vinculada à OC-120 |
| B | 8 | 3 (OC-120) | Parcela dividida: 3 vinculadas à OC-120 e requisição de 5 ao hub |
| E | 2 | 0 | Requisição normal ao av-hub (contrato 34) |

A OC com `destino` **estoque** não abate: aparece como saldo futuro para o PCP escolher (N14-29).

## 7. Telas (Robert, `app-pcp`)

| Onde | O que mostra |
|---|---|
| Modal de requisição (P3) | Chama R1: "Já em compra para este pedido: OC-120, 5 un, previsão 22/10", "Requisição aberta no Compras", "OC X aguardando aprovação"; preenche só o que falta; envia R2. O aviso **só avisa** |
| Triagem, Destinação, Atendimento (BL-049) | O mesmo bloco por pedido e produto |
| Atendimento e Saldo (BL-050) | Saldo futuro (R5) |
| Recebimento | "Receber com NF" (R4) com os esperados por requisição **e** por item de OC (R3); uso interno marcado |
| Estoque | Lista de entradas de uso interno (R6) |

## 8. Uso interno (N14-30)

| Regra | |
|---|---|
| Esperados | A OC de `finalidade = uso_interno` entra em R3 com `usoInterno = true`, pelo mesmo caminho da OC sem requisição |
| Conferência | Contra a NF, como as demais |
| Estoque | **Não cria lote nem saldo**: `EntradaUsoInterno`, entregue ao setor que pediu, **visível no Estoque como entrada registrada, sem saldo** (R6) |
| Saldo futuro | Fica fora (R5) |
| Custo | Vai para **despesa**, fora do custo do lote (nada em `LoteCusto`) |
| Quarentena | **Sem quarentena**, salvo categoria que o Nathan pedir (por exemplo, EPI) |
| Quem pediu | `EntradaUsoInterno.setorSolicitante`; 🔴 hoje a requisição do hub só tem `solicitante` (texto); ver Q3 do [[API-010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto]] |

🟡 Confirmar com a contabilidade que o custo de uso interno vai para despesa.

## 9. Torre de Fluxo

Estoque, uso interno e compra por fora **não geram evento** de fluxo: a Torre acompanha só o item de pedido de venda (N14-28). A projeção da requisição do hub e a `EntradaUsoInterno` não publicam evento. O lote que nasce de compra para pedido de venda só entra na Torre quando a **parcela** do item de pedido se move.

## 10. Critérios de aceite

1. OC aprovada de 5 un com `destino` ao pedido 27605: R1 devolve `disponivel = 5`; R2 com `vinculosOc` de 5 e sem `itens` cria a requisição de origem `HUB`, move a parcela a Compras · CCP "com o fornecedor", **sem** linha em `integracao_avhub_envios`.
2. Necessidade 8 com 3 em OC: a parcela é dividida; 3 vinculadas (origem `HUB`) e 5 requisitadas ao hub (origem `MES`, enfileirada). Duas chamadas simultâneas **não** usam as mesmas unidades.
3. OC de estoque aparece em R5 como saldo futuro e **não** abate o pedido.
4. Requisição do hub com pedido de venda aparece em R1 como "Requisição aberta no Compras" e **não** abate.
5. OC cancelada depois: os vínculos se desfazem e a parcela volta a Requisições com aviso.
6. R4 com itens de duas OCs e uma requisição do MES: uma conferência por NF, **um lote por item da OC** (em quarentena, com custo), restante continua esperado.
7. Item de OC com requisição do MES não entra duas vezes em R3.
8. Uso interno: entra em R3, confere com a NF, sem lote nem saldo, aparece em R6, fora de R5.
9. Nada de estoque, uso interno ou compra por fora aparece na Torre.
10. A requisição de origem `HUB` nunca entra na fila do PUT do contrato 34.
11. `esperados()` casa a requisição pela parcela: duas requisições do mesmo item não se confundem.
12. A migration aplica sem erro e os `CHECK` do recebimento recusam as combinações inválidas (✅ validado no banco descartável).

## 11. Ordem

| # | Quem | Passo |
|---|---|---|
| 1 | Gustavo | [[API-010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto]], depois [[API-009-Referencia-Requisicao-Hub-Integracao-MES]] |
| 2 | Robert | Migration + job da requisição do hub (seção 4.1) + tratamento da OC cancelada no K4 (4.2) |
| 3 | Robert | R1 e R2 (cruzamento, vínculo, divisão da parcela, `esperados()` pela parcela) |
| 4 | Robert | R3 e R4 (recebimento por item da OC e por NF), uso interno |
| 5 | Robert, Nathan | Telas (seção 7), R5 e R6 |

## 12. Perguntas em aberto

| # | Pergunta | Dono | Selo |
|---|---|---|---|
| Q1 | A resolução do `codigo_produto_omie` do item da OC para o `Material` da unidade, quando o `Material` ainda não existe | Robert | ❓ |
| Q2 | O rateio do **recebido** entre os destinos de uma OC que cobre vários pedidos e estoque (a fórmula da seção 6 é proporcional e provisória), e em que ordem atende o pedido. **Decidir antes do R1 (Robert, 19/10).** | Robert, Nathan | 🔴 |
| Q3 | Contabilidade: custo de uso interno vai para despesa? EPI tem inspeção? | Nathan | 🟡 |
| Q4 | De onde vem o setor que pediu o uso interno (campo novo na requisição do hub) | Nathan, Gustavo | 🔴 |
| Q5 | BL-049 e BL-050 (3,0 pd) entram no Ciclo 1? Aguardando decisão | Nathan | 🟡 |
| Q6 | O `Recebimento` sem parcela precisa de setor atual/histórico próprio (hoje o recebimento é um passo da parcela)? | Robert | ❓ |

Relacionados: [[API-004-Referencia-OC-Integracao-MES]], [[API-007-Referencia-OC-Valores-no-MES]], [[API-008-Custo-do-Lote-no-MES]], [[API-009-Referencia-Requisicao-Hub-Integracao-MES]], [[API-010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto]], [[05-Recebimento]], [[02-PCP-Triagem-e-Destinacao]], [[03-Estoque-Atendimento-e-Despacho]], [[04-Circuito-de-Compra]], [[Pontas-Soltas]] (PS-034), [[Backlog-por-Frente]] (BL-049, BL-050, BL-051, BL-065), [[Registro-de-Decisoes]].
