-- 16/10/2026 — Contrato 53 (proposta): Ordem de Produção e lote do fabricado (MES).
-- Nome sugerido da migration Prisma: 20261016130100_op_e_lote_fabricado
-- (depois de 20261016130000_origem_lote_producao, que cria o valor PRODUCAO).
--
-- A OP NÃO ganha tabela: ela é o `pedidos` de um destino de FABRICAÇÃO (a "ordem" que
-- a Destinação já cria por destino, numerada `pedidoVenda/N`, com `fabricas.tipo`).
-- Só se guarda a emissão e quantas vezes foi impressa.
-- NÃO aplicada ao banco real; testada em banco descartável com tabelas-esqueleto.

-- 1. Emissão da OP (só tem sentido em pedidos de destino FABRICACAO; o serviço garante).
ALTER TABLE "pedidos"
    ADD COLUMN "op_emitida_em" TIMESTAMP(3),
    ADD COLUMN "op_emitida_por_id" UUID,
    ADD COLUMN "op_impressoes" INTEGER NOT NULL DEFAULT 0;

ALTER TABLE "pedidos"
    ADD CONSTRAINT "pedidos_op_emitida_por_id_fkey"
    FOREIGN KEY ("op_emitida_por_id") REFERENCES "usuarios"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 2. Lote do fabricado: um por OP e produto, ligado à OP (o `pedidos` do destino).
ALTER TABLE "lotes" ADD COLUMN "id_pedido_op" UUID;

ALTER TABLE "lotes"
    ADD CONSTRAINT "lotes_id_pedido_op_fkey"
    FOREIGN KEY ("id_pedido_op") REFERENCES "pedidos"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Um lote por OP e produto (a segunda aprovação soma neste lote). Índice parcial:
-- o Prisma não o expressa no schema, vale só na migration.
CREATE UNIQUE INDEX "lotes_op_material_producao_key"
    ON "lotes"("id_pedido_op", "id_material")
    WHERE "origem" = 'PRODUCAO';

-- O lote de produção sempre tem OP; os demais não.
ALTER TABLE "lotes"
    ADD CONSTRAINT "lotes_origem_producao_ck"
    CHECK (("origem" = 'PRODUCAO') = ("id_pedido_op" IS NOT NULL));

-- 3. A parcela que a Qualidade de saída aprovou e voltou ao Estoque: espera a entrada
--    do fabricado (o Estoque informa a localização). Enquanto id_lote_fabricado for
--    nulo, a parcela não pode ser atendida pelo Estoque.
ALTER TABLE "itens_parciais"
    ADD COLUMN "fabricado_aprovado_em" TIMESTAMP(3),
    ADD COLUMN "id_lote_fabricado" UUID;

ALTER TABLE "itens_parciais"
    ADD CONSTRAINT "itens_parciais_id_lote_fabricado_fkey"
    FOREIGN KEY ("id_lote_fabricado") REFERENCES "lotes"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "itens_parciais_id_lote_fabricado_idx" ON "itens_parciais"("id_lote_fabricado");
