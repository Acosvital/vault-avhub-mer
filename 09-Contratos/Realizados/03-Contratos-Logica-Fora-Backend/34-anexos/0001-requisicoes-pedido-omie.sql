-- Contrato 34 — requisições vindas do MES: pedido de origem (Omie).
-- O MES já manda codigo_pedido_omie e o número do pedido de venda; a tabela não tinha onde gravar.
-- Aditivo e idempotente: pode rodar mais de uma vez. Sem FK (o pedido pode não estar no banco ainda).
ALTER TABLE core_vendas_faturamento.requisicoes_compra
  ADD COLUMN IF NOT EXISTS codigo_pedido_omie  bigint,
  ADD COLUMN IF NOT EXISTS numero_pedido_venda varchar(30);

COMMENT ON COLUMN core_vendas_faturamento.requisicoes_compra.codigo_pedido_omie  IS 'Pedido de venda de origem no Omie, enviado pelo MES (informativo).';
COMMENT ON COLUMN core_vendas_faturamento.requisicoes_compra.numero_pedido_venda IS 'Número do pedido de venda de origem, enviado pelo MES (informativo).';

CREATE INDEX IF NOT EXISTS idx_requisicoes_compra_pedido_omie
  ON core_vendas_faturamento.requisicoes_compra (codigo_pedido_omie)
  WHERE codigo_pedido_omie IS NOT NULL AND deleted_at IS NULL;
