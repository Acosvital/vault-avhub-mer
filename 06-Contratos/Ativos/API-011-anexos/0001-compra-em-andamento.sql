-- ============================================================================
-- Migration MES (proposta de 15/10/2026): compra em andamento, recebimento por
-- NF e por item da OC, e entrada de uso interno. Contrato API-011.
-- Nome sugerido da migration Prisma: 20261016120000_compra_em_andamento
-- (a última da develop é 20261014120000_compras_ccp; a K4, 20261015120000_oc_referencia,
--  tem de entrar antes: esta depende de "oc_referencia_itens").
--
-- Estilo das migrations do api-pcp: SQL puro, snake_case entre aspas, comentário
-- em português na primeira linha. Os modelos Prisma equivalentes estão no
-- contrato (seção 3). NÃO foi aplicada ao banco real: testada apenas contra um
-- banco descartável com tabelas-esqueleto das tabelas que ela referencia.
-- ============================================================================

-- 1. Origem da requisição: MES (como hoje) ou HUB (parcela coberta por OC já aprovada;
--    nunca vai ao av-hub, fica fora da fila do contrato 34).
CREATE TYPE "OrigemRequisicao" AS ENUM ('MES', 'HUB');

ALTER TABLE "requisicoes_compra"
    ADD COLUMN "origem" "OrigemRequisicao" NOT NULL DEFAULT 'MES';

-- 2. Item da requisição ligado ao item da OC (K4). Sem FK dura para a projeção
--    reescrita pelo job: ON DELETE SET NULL, como o idOrigem da K4 (sem FK).
ALTER TABLE "requisicoes_compra_itens"
    ADD COLUMN "id_oc_item" UUID;

CREATE INDEX "requisicoes_compra_itens_id_oc_item_idx" ON "requisicoes_compra_itens"("id_oc_item");

ALTER TABLE "requisicoes_compra_itens"
    ADD CONSTRAINT "requisicoes_compra_itens_id_oc_item_fkey"
    FOREIGN KEY ("id_oc_item") REFERENCES "oc_referencia_itens"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 3. Projeção da requisição do Compras no av-hub (API-009). Tabela própria, separada
--    da requisição interna "origem HUB".
CREATE TABLE "requisicoes_hub_referencia" (
    "id" UUID NOT NULL,
    "codigo_empresa" UUID NOT NULL,
    "numero_requisicao" VARCHAR(30) NOT NULL,
    "status" VARCHAR(15) NOT NULL,
    "finalidade" VARCHAR(15) NOT NULL,
    "material" VARCHAR(60) NOT NULL,
    "codigo_produto_omie" VARCHAR(40),
    "descricao" TEXT,
    "quantidade" DECIMAL(15,4) NOT NULL,
    "unidade_medida" VARCHAR(10) NOT NULL,
    "prazo_necessidade" DATE NOT NULL,
    "numero_pedido_venda" VARCHAR(30) NOT NULL,
    "id_ordem_compra" UUID,
    "numero_ordem_compra" VARCHAR(30),
    "situacao_ordem_compra" VARCHAR(24),
    "alterado_em_avhub" VARCHAR(40) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "sincronizado_em" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "requisicoes_hub_referencia_pkey" PRIMARY KEY ("id")
);

-- A chave do cruzamento com o pedido: unidade + pedido + código do produto.
CREATE INDEX "requisicoes_hub_referencia_cruzamento_idx"
    ON "requisicoes_hub_referencia"("codigo_empresa", "numero_pedido_venda", "material");

-- 4. Recebimento por NF: um cabeçalho que agrupa as conferências de uma NF.
CREATE TABLE "recebimentos_nf" (
    "id" UUID NOT NULL,
    "codigo" VARCHAR(30) NOT NULL,
    "numero_nf" VARCHAR(60),
    "chave_acesso_nf" VARCHAR(44),
    "fornecedor" VARCHAR(200),
    "observacao" VARCHAR(500),
    "conferido_por_id" UUID NOT NULL,
    "conferido_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recebimentos_nf_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "recebimentos_nf_codigo_key" ON "recebimentos_nf"("codigo");
CREATE INDEX "recebimentos_nf_chave_acesso_nf_idx" ON "recebimentos_nf"("chave_acesso_nf");

ALTER TABLE "recebimentos_nf"
    ADD CONSTRAINT "recebimentos_nf_conferido_por_id_fkey"
    FOREIGN KEY ("conferido_por_id") REFERENCES "usuarios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "recebimentos"
    ADD COLUMN "id_recebimento_nf" UUID,
    ADD COLUMN "id_ordem_compra" UUID;                       -- só no recebimento de OC sem requisição

-- Recebimento de OC sem requisição do MES: não há requisição nem parcela.
ALTER TABLE "recebimentos" ALTER COLUMN "id_requisicao" DROP NOT NULL;
ALTER TABLE "recebimentos" ALTER COLUMN "id_item_parcial" DROP NOT NULL;

-- Ou tem requisição e parcela (como hoje), ou tem a OC (sem as duas).
ALTER TABLE "recebimentos"
    ADD CONSTRAINT "recebimentos_origem_ck"
    CHECK (("id_requisicao" IS NOT NULL AND "id_item_parcial" IS NOT NULL AND "id_ordem_compra" IS NULL)
        OR ("id_requisicao" IS NULL     AND "id_item_parcial" IS NULL     AND "id_ordem_compra" IS NOT NULL));

CREATE INDEX "recebimentos_id_recebimento_nf_idx" ON "recebimentos"("id_recebimento_nf");
CREATE INDEX "recebimentos_id_ordem_compra_idx" ON "recebimentos"("id_ordem_compra");

ALTER TABLE "recebimentos"
    ADD CONSTRAINT "recebimentos_id_recebimento_nf_fkey"
    FOREIGN KEY ("id_recebimento_nf") REFERENCES "recebimentos_nf"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 5. Item do recebimento: de item de requisição (como hoje) OU de item de OC.
ALTER TABLE "recebimentos_itens" ALTER COLUMN "id_requisicao_item" DROP NOT NULL;
ALTER TABLE "recebimentos_itens"
    ADD COLUMN "id_oc_item" UUID,
    ADD COLUMN "uso_interno" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "recebimentos_itens"
    ADD CONSTRAINT "recebimentos_itens_origem_ck"
    CHECK (("id_requisicao_item" IS NOT NULL) <> ("id_oc_item" IS NOT NULL));

CREATE INDEX "recebimentos_itens_id_oc_item_idx" ON "recebimentos_itens"("id_oc_item");

ALTER TABLE "recebimentos_itens"
    ADD CONSTRAINT "recebimentos_itens_id_oc_item_fkey"
    FOREIGN KEY ("id_oc_item") REFERENCES "oc_referencia_itens"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 6. O lote nasce ligado ao item da OC (id_item_oc do custo já existe em lote_custo).
ALTER TABLE "lotes" ADD COLUMN "id_oc_item" UUID;
CREATE INDEX "lotes_id_oc_item_idx" ON "lotes"("id_oc_item");
ALTER TABLE "lotes"
    ADD CONSTRAINT "lotes_id_oc_item_fkey"
    FOREIGN KEY ("id_oc_item") REFERENCES "oc_referencia_itens"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 7. Entrada de uso interno: registrada, sem lote e sem saldo (N14-30).
CREATE TABLE "entradas_uso_interno" (
    "id" UUID NOT NULL,
    "codigo" VARCHAR(30) NOT NULL,
    "id_recebimento_item" UUID NOT NULL,
    "id_oc_item" UUID,
    "id_material" UUID NOT NULL,
    "quantidade" DECIMAL(14,4) NOT NULL,
    "unidade_medida" VARCHAR(20) NOT NULL,
    "setor_solicitante" VARCHAR(100),
    "observacao" VARCHAR(500),
    "recebido_por_id" UUID NOT NULL,
    "recebido_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "entradas_uso_interno_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "entradas_uso_interno_quantidade_ck" CHECK ("quantidade" > 0)
);

CREATE UNIQUE INDEX "entradas_uso_interno_codigo_key" ON "entradas_uso_interno"("codigo");
CREATE UNIQUE INDEX "entradas_uso_interno_id_recebimento_item_key" ON "entradas_uso_interno"("id_recebimento_item");
CREATE INDEX "entradas_uso_interno_id_material_idx" ON "entradas_uso_interno"("id_material");

ALTER TABLE "entradas_uso_interno"
    ADD CONSTRAINT "entradas_uso_interno_id_recebimento_item_fkey"
    FOREIGN KEY ("id_recebimento_item") REFERENCES "recebimentos_itens"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "entradas_uso_interno"
    ADD CONSTRAINT "entradas_uso_interno_id_oc_item_fkey"
    FOREIGN KEY ("id_oc_item") REFERENCES "oc_referencia_itens"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "entradas_uso_interno"
    ADD CONSTRAINT "entradas_uso_interno_id_material_fkey"
    FOREIGN KEY ("id_material") REFERENCES "materiais"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "entradas_uso_interno"
    ADD CONSTRAINT "entradas_uso_interno_recebido_por_id_fkey"
    FOREIGN KEY ("recebido_por_id") REFERENCES "usuarios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
