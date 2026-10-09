---
tags: [contrato-api, mes, estoque, custo, g1, genealogia]
status: para-implementar
criado: 2026-10-09
atualizado: 2026-10-09
---

# Contrato 008 — Custo do lote no MES (`lote_custo`, G1, recebimento, consumo e `GET /itens/custo`)

> **Status: `para-implementar` (Robert, `api-pcp` / `app-pcp`).** Desenho e decisões: [[Estoque-Custo-do-Lote]]. Fonte do custo da compra: [[007-Referencia-OC-Valores-no-MES]]. O hub consome em [[47-Custo-Real-por-Item-no-Hub]]. Regra de ouro: **o custo é opcional e nunca bloqueia** G1, recebimento, reserva, despacho ou faturamento.

## 1. Schema (migration nova em `estoque.prisma`)

```prisma
model LoteCusto {
  idLote               String   @id @map("id_lote") @db.Uuid
  lote                 Lote     @relation(fields: [idLote], references: [id], onDelete: Cascade)
  origem               OrigemCusto            // CARGA_INICIAL | OC | MANUAL
  custoLiquidoUnitario Decimal  @map("custo_liquido_unitario") @db.Decimal(15, 6)  // BRL por unidade do lote
  valorUnitario        Decimal? @map("valor_unitario") @db.Decimal(15, 4)           // moeda de origem, antes do desconto
  moeda                String   @default("BRL") @db.VarChar(3)
  cotacao              Decimal? @db.Decimal(15, 6)
  descontoPct          Decimal? @map("desconto_pct") @db.Decimal(6, 3)
  icmsRecuperarUnit    Decimal? @map("icms_recuperar_unit") @db.Decimal(15, 6)
  ipiUnit              Decimal? @map("ipi_unit") @db.Decimal(15, 6)
  stUnit               Decimal? @map("st_unit") @db.Decimal(15, 6)
  freteUnit            Decimal? @map("frete_unit") @db.Decimal(15, 6)   // gravado, FORA do custo líquido
  idItemOc             String?  @map("id_item_oc") @db.Uuid
  cotacaoAConferir     Boolean  @default(false) @map("cotacao_a_conferir")
  atualizadoPorId      String   @map("atualizado_por_id") @db.Uuid
  atualizadoEm         DateTime @updatedAt @map("atualizado_em")
  @@map("lote_custo")
}
```

- `custo_liquido_unitario = valor_unitario × (1 − descontoPct/100) × (cotacao ?? 1) − icmsRecuperarUnit + ipiUnit + stUnit` (componente vazio = 0). Calculado **no backend** ao gravar; os componentes ficam para recálculo e auditoria.
- Lote sem linha em `lote_custo` = lote sem custo.
- Cisão de lote (`lote_pai_id`): o filho copia o custo do pai. Transferência não mexe no custo. Auditar toda alteração (`AuditLog`, quem e quando).

## 2. G1 — carga inicial

- `POST /estoque/lotes/carga-inicial` (hoje um lote por vez) e a ferramenta de carga em lote da G1 ganham o campo opcional `custoUnitario` (BRL por unidade). Planilha: coluna **opcional** `custo_unitario`; vazia = lote sem custo, sem erro, e o dry-run lista quantos lotes ficaram sem custo.
- Grava `lote_custo` com `origem = CARGA_INICIAL`, `moeda = BRL`, componentes vazios, `custoLiquidoUnitario = custoUnitario`.
- Valor negativo ou não numérico: linha rejeitada no dry-run (mesma regra das demais colunas). Zero é aceito (🟡 confirmar com Compras se "0" deve valer como "sem custo").
- Dupla conferência (contador + conferente) e terceira contagem não mudam; o custo não entra na contagem.

## 3. Recebimento — lote nascido de OC

- Na entrada do lote vindo de uma requisição/OC, o MES procura o item na projeção da OC ([[007-Referencia-OC-Valores-no-MES]]) por `id_origem` / `id_item_oc` e grava `lote_custo` com `origem = OC`, copiando valor, moeda, cotação, desconto; frete rateado em `frete_unit` só se um dia houver regra (hoje fica vazio).
- **Unidade:** o custo é por unidade do **lote**. Se a unidade da OC difere da do lote, converter (peso teórico × real vale para chapas; 🟡 regra por categoria a fechar com Compras) ou deixar o lote sem custo e sinalizar; nunca gravar custo na unidade errada.
- Sem OC projetada (job ainda não existe, OC sem preço, compra sem requisição): lote sem custo; Compras/Gestor de Estoque pode informar `MANUAL` (`PUT /estoque/lotes/:id/custo`, permissão própria `estoque-custo` 🟡).
- `cotacaoAConferir = true` quando `cotacao_origem = manual` na OC.

## 4. Consumo (J2/J3)

`MovimentoEstoque` tipo `CONSUMO` e a baixa por `Reserva`/despacho gravam o `custo_liquido_unitario` do lote **no momento do movimento** (snapshot), para o custo do item não mudar se o custo do lote for corrigido depois sem auditoria. Correção posterior gera movimento de ajuste de custo (🟡 definir se reabre faturamentos já calculados: não, na etapa 3 o av-hub guarda o cálculo por NF).

## 5. `GET /itens/custo?alterado_desde=&codigo_empresa=&apos_id=&limit=`

Irmã de `GET /itens/status` (005): mesma chave de serviço, mesmo cursor. Uma linha por item de pedido (filial + pedido + item):

```json
{ "codigo_empresa": "uuid", "numero_pedido": "25970", "item": 3,
  "quantidade": 20, "quantidade_com_custo": 20, "custo_total": 235.00, "custo_medio": 11.75,
  "completo": true, "cotacao_a_conferir": false,
  "lotes": [ { "codigo_lote": "LT-20261001-0004", "quantidade": 10, "custo_unitario": 10.00 } ],
  "alterado_em": "2026-11-20T12:00:00.123456Z" }
```

- `custo_total = Σ quantidade × custo_liquido_unitario` dos lotes ligados às `Reserva` do item (reservas ATIVA e CONSUMIDA; liberada não conta).
- `completo = true` só quando `quantidade_com_custo = quantidade` do item. Item de **fabricação** não aparece (fica em 2% até J2–J4).
- Rota somente leitura. Entra no **Ciclo 2** (o hub só consome na etapa 2 da comissão), mas o campo `custo_unitario` por lote já aparece em `GET /estoque/saldo` e nas telas do Estoque desde a G1 para quem tem a permissão.

## 6. Telas (`app-pcp`)

Coluna "Custo unit." opcional em Lotes e Saldo (visível só com a permissão de custo); campo no assistente da carga inicial; indicador "sem custo" e "cotação a conferir" no recebimento. Nada disso aparece para quem não tem a permissão.

## Aceite

1. Planilha da G1 com a coluna de custo preenchida em parte das linhas: os lotes com valor nascem com `lote_custo`, os demais sem; o dry-run informa a contagem.
2. Lote recebido de OC em USD: `custo_liquido_unitario` confere com a fórmula; OC com cotação manual vem marcada.
3. Exemplo do vault (20 flanges, 3 lotes: 10×10 + 5×12 + 5×15): `GET /itens/custo` devolve `custo_total = 235,00`, `custo_medio = 11,75`, `completo = true`; com 1 lote sem custo, `completo = false`.
4. Cisão de lote copia o custo; transferência não altera.
5. Nenhuma operação de estoque falha por falta de custo.

## Ver também
[[Estoque-Custo-do-Lote]] · [[Estoque-Modelo-Dados]] · [[007-Referencia-OC-Valores-no-MES]] · [[005-Status-Item-Integracao-MES]] · [[47-Custo-Real-por-Item-no-Hub]]
