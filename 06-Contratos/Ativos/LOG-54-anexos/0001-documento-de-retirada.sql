-- 16/10/2026 — Contrato 54 (proposta): documento de retirada e baixa do saldo na retirada (MES).
-- Nome sugerido da migration Prisma: 20261016140000_documento_de_retirada
--
-- A baixa deixa de acontecer em itens-parciais.service.ts:279 (receber() da Embalagem) e em
-- entregas.service.ts:88 e passa a acontecer na confirmação da retirada, reaproveitando
-- consumirReservasDaParcial (estoque-operacao.helpers.ts:208).
-- NÃO aplicada ao banco real; testada em banco descartável com tabelas-esqueleto.

CREATE TYPE "TipoRetirada" AS ENUM ('EXPEDICAO', 'PRODUCAO');
CREATE TYPE "StatusRetirada" AS ENUM ('ABERTA', 'PARCIAL', 'CONFIRMADA', 'CANCELADA');

CREATE TABLE "retiradas" (
    "id" UUID NOT NULL,
    "codigo" VARCHAR(30) NOT NULL,                 -- RT-AAAAMMDD-NNNN
    "tipo" "TipoRetirada" NOT NULL,
    "status" "StatusRetirada" NOT NULL DEFAULT 'ABERTA',
    "id_setor_solicitante" UUID NOT NULL,
    "observacao" VARCHAR(500),
    "motivo_cancelamento" VARCHAR(500),
    "solicitada_por_id" UUID NOT NULL,
    "solicitada_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "confirmada_por_id" UUID,
    "confirmada_em" TIMESTAMP(3),
    "cancelada_por_id" UUID,
    "cancelada_em" TIMESTAMP(3),
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "retiradas_pkey" PRIMARY KEY ("id"),
    -- Cancelar exige quem cancelou e o motivo; confirmar exige quem confirmou.
    CONSTRAINT "retiradas_cancelada_ck" CHECK (("status" <> 'CANCELADA') OR ("cancelada_por_id" IS NOT NULL AND "motivo_cancelamento" IS NOT NULL)),
    CONSTRAINT "retiradas_confirmada_ck" CHECK (("status" NOT IN ('PARCIAL','CONFIRMADA')) OR ("confirmada_por_id" IS NOT NULL))
);

CREATE UNIQUE INDEX "retiradas_codigo_key" ON "retiradas"("codigo");
CREATE INDEX "retiradas_status_idx" ON "retiradas"("status");
CREATE INDEX "retiradas_tipo_status_idx" ON "retiradas"("tipo", "status");

CREATE TABLE "retiradas_itens" (
    "id" UUID NOT NULL,
    "id_retirada" UUID NOT NULL,
    "id_item_parcial" UUID NOT NULL,
    "quantidade_solicitada" DECIMAL(14,4) NOT NULL,
    "quantidade_retirada" DECIMAL(14,4) NOT NULL DEFAULT 0,

    CONSTRAINT "retiradas_itens_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "retiradas_itens_solicitada_ck" CHECK ("quantidade_solicitada" > 0),
    CONSTRAINT "retiradas_itens_retirada_ck" CHECK ("quantidade_retirada" >= 0 AND "quantidade_retirada" <= "quantidade_solicitada")
);

CREATE INDEX "retiradas_itens_id_retirada_idx" ON "retiradas_itens"("id_retirada");
CREATE INDEX "retiradas_itens_id_item_parcial_idx" ON "retiradas_itens"("id_item_parcial");
-- Uma parcela não entra duas vezes na mesma retirada.
CREATE UNIQUE INDEX "retiradas_itens_retirada_parcial_key" ON "retiradas_itens"("id_retirada", "id_item_parcial");

ALTER TABLE "retiradas"
    ADD CONSTRAINT "retiradas_id_setor_solicitante_fkey"
    FOREIGN KEY ("id_setor_solicitante") REFERENCES "setores"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "retiradas"
    ADD CONSTRAINT "retiradas_solicitada_por_id_fkey"
    FOREIGN KEY ("solicitada_por_id") REFERENCES "usuarios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "retiradas"
    ADD CONSTRAINT "retiradas_confirmada_por_id_fkey"
    FOREIGN KEY ("confirmada_por_id") REFERENCES "usuarios"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "retiradas"
    ADD CONSTRAINT "retiradas_cancelada_por_id_fkey"
    FOREIGN KEY ("cancelada_por_id") REFERENCES "usuarios"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "retiradas_itens"
    ADD CONSTRAINT "retiradas_itens_id_retirada_fkey"
    FOREIGN KEY ("id_retirada") REFERENCES "retiradas"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "retiradas_itens"
    ADD CONSTRAINT "retiradas_itens_id_item_parcial_fkey"
    FOREIGN KEY ("id_item_parcial") REFERENCES "itens_parciais"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Rastro: de qual retirada saiu cada movimento de SAIDA.
ALTER TABLE "movimentos_estoque" ADD COLUMN "id_retirada" UUID;
CREATE INDEX "movimentos_estoque_id_retirada_idx" ON "movimentos_estoque"("id_retirada");
ALTER TABLE "movimentos_estoque"
    ADD CONSTRAINT "movimentos_estoque_id_retirada_fkey"
    FOREIGN KEY ("id_retirada") REFERENCES "retiradas"("id") ON DELETE SET NULL ON UPDATE CASCADE;
