---
id: API-008
aliases: ["Contrato 008", "008-Custo-do-Lote-no-MES"]
tags: [contrato, contrato-api, mes, estoque, custo, g1, genealogia]
criado: 2026-10-14
atualizado: 2026-10-14
status: parcial
sistemas: [mes-api, hub-api]
dono: "Robert"
etapa_0b: [R4, E3, E5]
fontes: ["api-pcp/prisma/models/estoque.prisma:394-423", "api-pcp/prisma/migrations/20261009140000_lote_custo", "api-pcp/src/estoque/operacao/estoque-operacao.service.ts:403-445", "api-pcp/src/common/constants/estoque-custo.constants.ts:5", "api-acos-vital/src/schemas/core_vendas_faturamento/tables/itens_pedido_custo/itens_pedido_custo.job.js:78"]
criado_original: 2026-10-09
---

# Contrato 008 — Custo do lote no MES (`lote_custo`, G1, recebimento, consumo e `GET /itens/custo`)

> **Onde atua:** av-hub: API · MES: API

> [!info] Situação em 14/10/2026
> **Status:** `parcial` · **Pasta:** `Ativos` · **Nós do 0b:** R4, E3, E5 · **Dono:** Robert
>
> - ✅ **§1 Schema:** tabela `lote_custo` (model `LoteCusto`, `api-pcp/prisma/models/estoque.prisma:394-423`; migration `20261009140000_lote_custo`), com `origem`, `custo_liquido_unitario`, `cotacao_a_conferir`, `id_item_oc`.
> - ✅ **§2 G1, carga inicial:** `POST /estoque/lotes/carga-inicial` aceita `custoUnitario` e grava `lote_custo` (`api-pcp/src/estoque/operacao/estoque-operacao.service.ts:403-445`); vazio ou `0` = lote sem custo. Permissão `estoque-custo` (default-deny; `api-pcp/src/common/constants/estoque-custo.constants.ts:5`) controla quem informa e quem vê o custo (`estoque-operacao.service.ts:65`).
> - ✅ **§6 Telas:** coluna de custo e campo na carga inicial no `app-pcp` (`app-pcp/app/(protected)/estoque-operacao/saldo/EntradaLoteModal.tsx`, `.../lotes/[id]/page.tsx`).
> - 🔴 **§3 Recebimento com custo da OC:** o lote de recebimento nasce sem `lote_custo` (depende da projeção da OC, ver [[API-007-Referencia-OC-Valores-no-MES]]). Rota de custo `MANUAL` (`PUT /estoque/lotes/:id/custo`, decisão D8): não existe no controller de Estoque.
> - 🔴 **§4 Snapshot do custo na `SAIDA`:** não há (o movimento não grava o custo do lote).
> - 🔴 **§5 `GET /itens/custo`:** não existe no `api-pcp` (grep sem resultado). O av-hub já tem o consumidor (`itens_pedido_custo.job.js:78`) e responde 404 "ainda não publicado" no MES: o job só avisa no log.
>
> Conferido em 14/10/2026 contra `api-pcp` 579a625, `app-pcp` 1fca8d3, `api-acos-vital` f322dcd, `omie-elt-pipeline` 0f739f0 e os dumps de 14/10. O front do av-hub (HUB b55ac55) só pelo vault v1 (❓).
> O texto original abaixo está inteiro; os trechos que o estado atual contradiz têm nota de rodapé.


> **Status: `para-implementar` (Robert, `api-pcp` / `app-pcp`).**[^c1] Desenho e decisões: [[Modelo-Estoque-e-Custo-do-Lote|Estoque-Custo-do-Lote]]. Fonte do custo da compra: [[API-007-Referencia-OC-Valores-no-MES|007-Referencia-OC-Valores-no-MES]]. O hub consome em [[LOG-47-Custo-Real-por-Item-no-Hub|47-Custo-Real-por-Item-no-Hub]]. Regra de ouro: **o custo é opcional e nunca bloqueia** G1, recebimento, reserva, despacho ou faturamento.

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
- **No Ciclo 1 os impostos ficam vazios** (a OC entregue no [[API-007-Referencia-OC-Valores-no-MES|007-Referencia-OC-Valores-no-MES]] não traz ICMS, IPI, ST nem frete por item). Na prática: `custo_liquido_unitario = valor_unitario × (1 − descontoPct/100) × (cotacao ?? 1)`. A origem dos impostos (NF de entrada, cadastro ou Compras) fica para o Ciclo 2. **D5 decidida por Nathan em 14/10:** o custo do Ciclo 1 é aceito **sem impostos** (pode ficar acima do custo real quando há ICMS recuperável); o [[LOG-47-Custo-Real-por-Item-no-Hub|47-Custo-Real-por-Item-no-Hub]] deve deixar claro que é custo sem impostos.
- Lote sem linha em `lote_custo` = lote sem custo.
- Cisão de lote (`lote_pai_id`): o filho copia o custo do pai. Transferência não mexe no custo. Auditar toda alteração (`AuditLog`, quem e quando).

## 2. G1 — carga inicial

- `POST /estoque/lotes/carga-inicial` (hoje um lote por vez) e a ferramenta de carga em lote da G1 ganham o campo opcional `custoUnitario` (BRL por unidade). Planilha: coluna **opcional** `custo_unitario`; vazia = lote sem custo, sem erro, e o dry-run lista quantos lotes ficaram sem custo.
- Grava `lote_custo` com `origem = CARGA_INICIAL`, `moeda = BRL`, componentes vazios, `custoLiquidoUnitario = custoUnitario`.
- Valor negativo ou não numérico: linha rejeitada no dry-run (mesma regra das demais colunas). **`0` = sem custo** enquanto o custo for opcional (decidido em 09/10; é a regra do código). Vazio e `0` geram lote sem `lote_custo`.
- Dupla conferência (contador + conferente) e terceira contagem não mudam; o custo não entra na contagem.

## 3. Recebimento — lote nascido de OC

- Na entrada do lote vindo de uma requisição/OC, o MES procura o item na projeção da OC ([[API-007-Referencia-OC-Valores-no-MES|007-Referencia-OC-Valores-no-MES]]) por `id_origem` / `id_item_oc` e grava `lote_custo` com `origem = OC`, copiando valor, moeda, cotação, desconto; `frete_unit` e os impostos por item ficam **vazios**: a OC não traz esses dados por item (ver §1).
- **Uma OC para várias requisições (D1, decidido por Nathan em 14/10):** o lote é **por produto dentro da OC**, não por requisição. Exemplo: uma OC agrupa 10 requisições de tubo; 5 são o mesmo produto e 5 são outros modelos. Os 5 iguais chegam juntos e formam **um lote**; cada um dos outros produtos forma **o seu**. Cada lote recebe o valor do **item da OC** correspondente (`id_item_oc`), e esse vínculo fica gravado em `lote_custo` (e a OC de origem no lote) para rastrear depois de onde veio e por quanto foi comprado. O custo vem da OC informada na chegada; se não der para saber, o lote fica sem custo e marcado para Compras.
- **Regras de apoio (Nathan, 14/10):** uma OC é de **um único fornecedor**, então o mesmo produto não tem dois preços na mesma OC (um preço por produto e OC). O mesmo produto em **duas OCs** que chegam juntas gera **lotes separados, um por OC**, cada um com o seu custo.
- **OC não muda depois que o lote chega (D3, decidido por Nathan em 14/10):** a OC emitida só pode ser editada enquanto a negociação com o fornecedor não termina (o fornecedor não aceitou, edita-se e reemite até a versão final); o CCP sinaliza cada mudança. **Chegou o lote, a OC está fechada e não é alterada.** Por isso o custo gravado na entrada **não é atualizado pela OC**: o MES grava o valor da versão final da OC vigente na chegada e pronto. Se mesmo assim o custo estiver errado, a correção é a rota `MANUAL` (D8), com motivo e auditoria, e vale pelas regras da D4.
- **Sobra de compra para estoque (D1):** se vier mais do que as requisições pedem, a sobra **fica no mesmo lote** e herda o mesmo custo e a mesma identificação da OC (`id_item_oc`). A quantidade do lote é a recebida; as requisições consomem dela por reserva.
- **Unidade:** o custo é por unidade do **lote**. **Nunca gravar custo na unidade errada** (D2, decidido por Nathan em 14/10):
  - **Ciclo 1:** unidade da OC igual à do lote grava o custo normalmente. Se for diferente, o lote nasce **sem custo** e aparece sinalizado no Recebimento ("unidade diferente da OC"). Quem tem `estoque-custo` editar informa o custo pela rota `MANUAL` (D8); a tela mostra a unidade da OC, a unidade do lote e o valor da OC para evitar conversão errada. Não há conversão por fator "médio" e o recebimento nunca é bloqueado.
  - **Evolução (Ciclo 2):** cadastro do produto com unidade de compra, unidade de estoque e fator de conversão, mantido por Compras; com o fator, a conversão é automática, sem ele cai no Ciclo 1. Para chapas e barras (compra por peso, estoque por peça), usar o **peso real da conferência** do Recebimento (custo da linha da OC ÷ quantidade na unidade do lote), só quando o item da OC chega inteiro num lote; entrega parcelada exige rateio, a definir com Compras.
  - 🟡 **Perguntas para Compras:** (1) quais categorias são compradas numa unidade e estocadas em outra? (2) o fator é fixo por produto ou varia por lote (peso real da chapa)?
- Sem OC projetada (job ainda não existe, OC sem preço, compra sem requisição): lote sem custo; Compras/Gestor de Estoque pode informar `MANUAL` (`PUT /estoque/lotes/:id/custo`, permissão própria `estoque-custo`, **default-deny** com níveis visualizar e editar; decidido em 09/10, já está no código e no `01-base.sql`). **D8 (decidido por Nathan em 14/10):** só quem tem `estoque-custo` **editar** informa ou corrige o custo `MANUAL`; **motivo obrigatório** e auditoria de quem e quando (`AuditLog`).
- `cotacaoAConferir = true` quando `cotacao_origem = manual` na OC.

## 4. Consumo (revenda; fabricação J2/J3 depois)

O movimento `SAIDA` que consome a `Reserva` (tem `id_reserva`) grava o `custo_liquido_unitario` do lote **no momento do movimento** (snapshot). O tipo `CONSUMO` não existe: a revenda baixa por `SAIDA`. O consumo de MP da fabricação (J2/J3) só entra quando existir. O snapshot existe para o custo do item não mudar se o custo do lote for corrigido depois sem auditoria. **Correção de custo depois da baixa (D4, decidido por Nathan em 14/10):** a correção (carga inicial errada, custo `MANUAL`, cotação conferida, unidade errada) vale para o **saldo e para as reservas abertas**. A parte já baixada **mantém o snapshot** da saída; não há movimento de ajuste de custo e não se reabrem faturamentos já calculados (na etapa 3 o av-hub guarda o cálculo por NF). Toda correção é auditada (quem, quando e motivo).

## 5. `GET /itens/custo?alterado_desde=&codigo_empresa=&apos_id=&limit=`

Irmã de `GET /itens/status` (005): mesma chave de serviço. A resposta é um **array puro** (como o `/itens/status`), com **uma linha por filial + pedido + produto** (`codigo_produto_omie`). **O item do pedido é o produto.** No Omie um pedido pode ter o mesmo produto em duas linhas (linha 3 com 12 flanges e linha 7 com 8 flanges da mesma flange). O MES não guarda o número da linha do Omie, só o produto; por isso soma as linhas repetidas num item só (20 flanges, uma linha na resposta). A chave de casamento com o hub é filial + pedido + `codigo_produto_omie`, nunca o número da linha. O cursor é `alterado_desde` + `apos_id` (uuid do item no MES).

```json
[ { "id": "uuid do item no MES",
    "codigo_empresa": "uuid da unidade", "numero_pedido": "25970",
    "codigo_pedido_omie": "123456", "codigo_produto_omie": "987654", "codigo_produto": "FLG-2-150",
    "quantidade": 20, "quantidade_com_custo": 20, "custo_total": 235.00, "custo_medio": 11.75,
    "completo": true, "cotacao_a_conferir": false,
    "lotes": [ { "codigo_lote": "LT-20261001-0004", "quantidade": 10,
                 "custo_unitario": 10.00, "origem": "OC", "consumido": true } ],
    "alterado_em": "2026-11-20T12:00:00.123456Z" } ]
```

- `custo_total = Σ quantidade × custo_liquido_unitario` dos lotes ligados às `Reserva` do item (reservas ATIVA e CONSUMIDA; liberada não conta). Parte já baixada usa o **snapshot gravado na SAIDA**; parte ainda reservada usa o **custo atual do lote**.
- `completo = true` só quando `quantidade_com_custo = quantidade` do item.
- **Quais itens aparecem:** só os que têm ou já tiveram reserva. Item de **fabricação** não tem reserva e fica de fora (fica em 2% até J2–J4). Item cujas reservas foram todas liberadas continua saindo, com `quantidade_com_custo = 0`, para o hub não guardar um custo velho. **Pedido manual nunca participa do custo (D6, decidido por Nathan em 14/10):** pedido lançado à mão, fora do ERP, não aparece no `GET /itens/custo` e não percorre o processo do pedido normal, nem hoje nem se um dia o Omie deixar de existir. O pedido manual precisa de uma **marca (flag) de origem manual**, usada só para o dashboard de vendas e o faturamento; ele não se mistura com os pedidos criados e lançados no ERP Avhub. **Pedido dividido (D7, confirmado por Nathan em 14/10):** o mesmo produto do pedido pode cair em mais de uma ordem (rodadas diferentes, fábricas ou roteiros diferentes, parte com matéria-prima em estoque e parte esperando compra). O MES **soma numa linha só por filial + pedido + produto**, juntando as reservas e os lotes de todas as ordens.
- **Marca de alteração:** o MES grava `custo_alterado_em` no item, na mesma transação, quando a reserva é criada, baixada, estornada ou liberada, e quando muda o custo de um lote que tem reserva. É o que alimenta `alterado_desde`.
- Rota somente leitura. Entra no **Ciclo 2** (o hub só consome na etapa 2 da comissão), mas o campo `custo_unitario` por lote já aparece em `GET /estoque/saldo` e nas telas do Estoque desde a G1 para quem tem a permissão.

## 6. Telas (`app-pcp`)

Coluna "Custo unit." opcional em Lotes e Saldo (visível só com a permissão de custo); campo no assistente da carga inicial; indicador "sem custo" e "cotação a conferir" no recebimento. Nada disso aparece para quem não tem a permissão.

## Cenário de ponta a ponta (exemplo)

Pedido Omie **25970**, filial F1, flange **FLG-2-150**: linha 3 com 12 un e linha 7 com 8 un. O MES guarda **um item de 20 un**.

1. **Marco zero (G1).** A planilha da carga inicial traz o lote **L1** com 10 un e `custo_unitario = 10,00`. Nasce `lote_custo` com `origem = CARGA_INICIAL`. Outro lote da mesma planilha vem sem custo: nasce sem `lote_custo`, sem erro; o dry-run conta quantos ficaram assim.
2. **Compra.** O pedido precisa de mais 10 flanges além do L1. Compras emite a **OC-A** (um só fornecedor) agrupando 2 requisições da mesma flange (3 + 2 = 5 un), a R$ 12,00, e compra 8 para ter sobra de 3. A OC é editada até o fornecedor aceitar; depois da versão final não muda mais.
3. **Chegada (K4 + K5).** O Recebimento confere a NF e a unidade da OC é igual à do lote. Nasce **um lote L2 de 8 un** (as 2 requisições chegaram juntas, mesmo produto), com `origem = OC`, `id_item_oc`, `custo = 12,00`. A sobra de 3 un fica no L2 com o mesmo custo e a mesma identificação da OC.
4. **Outra OC no mesmo dia.** A **OC-B**, de outro fornecedor, traz a mesma flange a R$ 15,00, 5 un. Mesmo produto em outra OC: **lote separado L3**, custo 15,00.
5. **Reserva.** O pedido reserva 10 do L1, 5 do L2 e 5 do L3. O item ganha `custo_alterado_em`.
6. **Saída (K6).** O Estoque despacha. Cada `SAIDA` com `id_reserva` grava o custo do lote naquele momento (snapshot).
7. **`GET /itens/custo`** (hub, a cada ciclo do job): uma linha para F1 + 25970 + FLG-2-150, `quantidade = 20`, `custo_total = 10×10 + 5×12 + 5×15 = 235,00`, `custo_medio = 11,75`, `completo = true`, três lotes com `origem` e `consumido`. O hub grava por filial + pedido + produto.
8. **Faturamento (contrato 47).** NF parcial de 10 flanges: custo = 10 × 11,75 = 117,50.
9. **Erro descoberto depois (D4).** Alguém vê que o custo do L2 era 13,00, e já saíram 4 un. A correção `MANUAL` (permissão `estoque-custo` editar, motivo obrigatório, auditada) vale para o saldo e as reservas abertas; as 4 baixadas mantêm 12,00. O item muda `custo_total` só na parte ainda reservada.
10. **Variações.** Se uma das OCs estivesse em kg e o lote em peças (D2): lote sem custo, sinalizado, custo pela rota `MANUAL`. Se faltasse a chave de leitura da OC (H1): todos os lotes de compra nascem sem custo e `completo = false`, sem bloquear nada.

## Aceite

1. Planilha da G1 com a coluna de custo preenchida em parte das linhas: os lotes com valor nascem com `lote_custo`, os demais sem; o dry-run informa a contagem.
2. Lote recebido de OC em USD: `custo_liquido_unitario` confere com a fórmula; OC com cotação manual vem marcada.
3. Exemplo do vault (20 flanges, 3 lotes: 10×10 + 5×12 + 5×15; uma linha por **produto**): `GET /itens/custo` devolve `custo_total = 235,00`, `custo_medio = 11,75`, `completo = true`; com 1 lote sem custo, `completo = false`.
4. Cisão de lote copia o custo; transferência não altera.
5. Nenhuma operação de estoque falha por falta de custo.
6. Reserva baixada e depois estornada (Embalagem desfaz o recebimento): o item volta a usar o custo atual do lote; nada fica duplicado.
7. Custo do lote corrigido depois de parte baixada: `custo_total` muda só na parte ainda reservada (D4).
8. Lote recebido com unidade diferente da OC: nasce sem custo e aparece sinalizado no Recebimento (🟡 D2).
9. `GET /itens/custo` com `apos_id`: duas leituras seguidas sem mudança não devolvem linhas repetidas.

## Ver também
[[Modelo-Estoque-e-Custo-do-Lote|Estoque-Custo-do-Lote]] · [[Modelo-Estoque-e-Custo-do-Lote|Estoque-Modelo-Dados]] · [[API-007-Referencia-OC-Valores-no-MES|007-Referencia-OC-Valores-no-MES]] · [[API-005-Status-Item-Integracao-MES|005-Status-Item-Integracao-MES]] · [[LOG-47-Custo-Real-por-Item-no-Hub|47-Custo-Real-por-Item-no-Hub]]

[^c1]: Nota de 14/10/2026: Status vigente: `parcial` (§1, §2 e §6 no código desde o PR #53; §3 a §5 sem código).
