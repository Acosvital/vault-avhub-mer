-- 16/10/2026 — Contrato 53 (proposta): nova origem de lote, PRODUCAO (fabricado aprovado).
-- Nome sugerido da migration Prisma: 20261016130000_origem_lote_producao
--
-- Fica SOZINHA de propósito: no PostgreSQL o valor novo de um enum não pode ser
-- usado na mesma transação em que foi criado (o índice parcial da migration
-- seguinte filtra por 'PRODUCAO'). NÃO aplicada ao banco real; testada em banco descartável.

ALTER TYPE "OrigemLote" ADD VALUE IF NOT EXISTS 'PRODUCAO';
