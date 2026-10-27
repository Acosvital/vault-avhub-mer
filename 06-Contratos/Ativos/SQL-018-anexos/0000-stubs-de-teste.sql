CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE SCHEMA core; CREATE SCHEMA auth; CREATE SCHEMA core_vendas_faturamento;
CREATE TABLE core.unidades (id uuid PRIMARY KEY, nome text);
CREATE TABLE core.funcionarios (id uuid PRIMARY KEY);
CREATE TABLE auth.usuarios (id uuid PRIMARY KEY);
CREATE FUNCTION public.set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at := now(); RETURN NEW; END $$;
CREATE TABLE core_vendas_faturamento.notas_fiscais (codigo_empresa uuid, codigo_nf_omie bigint, numero_nf varchar(10), data_emissao text, deleted_at timestamptz, PRIMARY KEY (codigo_empresa, codigo_nf_omie));
CREATE TABLE core_vendas_faturamento.produto_vendas (codigo_empresa uuid, codigo_nf_omie bigint, codigo_item_omie bigint, quantidade numeric, valor_total numeric, deleted_at timestamptz,
  numero_pedido varchar(15), codigo_produto_omie varchar(60));   -- as duas últimas colunas existem no banco real; aqui vêm no fim para os INSERT posicionais
CREATE TABLE core_vendas_faturamento.pedidos_vendas (codigo_empresa uuid, numero_pedido varchar(15), sequencial numeric(4,0), codigo_vendedor_omie varchar(11),
  codigo_cliente varchar(60), cancelado boolean DEFAULT false, deleted_at timestamptz);
CREATE TABLE core_vendas_faturamento.pedidos_vendas_sequenciais_itens (codigo_empresa uuid, codigo_item_omie bigint, codigo_item_omie_original bigint);
INSERT INTO core.unidades VALUES ('759979bd-2b2d-41f2-b1b7-db6fae89ee59','Aços Vital');
INSERT INTO auth.usuarios VALUES ('00000000-0000-0000-0000-0000000000a1'),('00000000-0000-0000-0000-0000000000a2');
