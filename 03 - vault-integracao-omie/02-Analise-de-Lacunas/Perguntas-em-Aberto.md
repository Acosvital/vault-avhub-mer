---
tags: [integracao-omie, lacunas]
criado: 2026-09-17
---

# Perguntas em aberto sobre a integração Omie

Lista consolidada, cruzando o que o vault 01 já sinalizava com o que a leitura direta do código do pipeline confirmou, refutou ou deixou sem resposta.

## Confirmadas como lacunas reais (não é falta de mapeamento, é o dado não existir)

1. **Saldo de estoque não sincroniza** — endpoint pronto no código, desabilitado por falta de tabela de destino. Ver [[Campos-Faltantes-para-Estoque-MES]] e [[Compras-Estoque-Producao-Lacunas]] (campos completos confirmados na doc da API: `saldo`, `cmc`, `pendente`, `estoque_minimo`, `reservado`, `fisico`).
2. **Devolução parcial não tem valor consultável em massa** — **atualizado**: existe um campo de valor (`vTotal`), mas só via chamada individual `StatusDevolucaoVenda(nCodDevol)`, não em listagem em massa. Ver [[Vendas-NFe-Lacunas]].
3. **Estoque máximo / ponto de pedido / tolerância de peso** — **confirmado que não existem em nenhum endpoint da API** (Produtos, Locais de Estoque, Produto x Fornecedor, Ajuste, Consulta, Resumo, todos verificados). **Estoque mínimo, por outro lado, existe** (por produto×local, via `AlterarEstoqueMinimo`) — ver correção no item 9 abaixo e [[Compras-Estoque-Producao-Lacunas]].

## Respondidas com o levantamento completo da API (2026-09-17)

4. ~~Omie tem API de criação de Ordem de Compra?~~ — **SIM, confirmado**: `produtos/pedidocompra/` tem CRUD completo (`IncluirPedCompra`, `AlteraPedCompra`, `ExcluirPedCompra`, `UpsertPedCompra`), incluindo fluxo de aprovação por e-mail, parcelamento e frete. Ver [[Compras-Estoque-Producao-Lacunas]].
5. **Quem preenche as colunas protegidas de `vendedores`, `pedidos_vendas.manual` e `notas_fiscais`?** — ainda não confirmado. Uma pista nova: `vendedores.comissao` existe como campo nativo do Omie (`geral/vendedores/`) e hoje não é extraído nem por nós nem, aparentemente, por ninguém — vale checar se é essa a fonte antes de assumir que vem de outro sistema. Ver [[Colunas-Protegidas]] e [[Vendas-NFe-Lacunas]].
6. **O payload bruto do Omie (`ListarProdutos`) tem mais campos que o pipeline não mapeia?** — **sim, confirmado diretamente na documentação da API** (não precisou habilitar o staging raw): `lead_time`, características, kit, imagens, tabelas de preço e todo o bloco fiscal existem no cadastro de produto e não são extraídos. Ver [[Compras-Estoque-Producao-Lacunas]].

## Corrigida nesta análise (era um mal-entendido, não uma lacuna)

7. ~~CFOP não é capturado~~ — **falso**: já é capturado por item de venda em `produto_vendas.cfop`. Só ICMS-ST de fato não é capturado. Ver [[Contradicao-CFOP]].
8. ~~Histórico de status do pedido é limitado por causa do Omie~~ — **impreciso**: a granularidade de `pedidos_vendas_status_historico` é uma decisão de schema do banco, o pipeline nem escreve nessa tabela (`situacao` é recalculada por trigger). Resolver isso não depende de trazer mais dado do Omie.

## Parcialmente resolvida

9. **Peso do produto vem do Omie?** — sim, `peso_bruto` e `peso_liq` já vêm prontos em `core.produtos.especificacoes`. **Atualizado**: estoque mínimo também vem pronto (por produto×local, via `estoque/ajuste/`). O que falta de verdade é só tolerância de peso, estoque máximo e ponto de pedido (item 3 acima) — confirmado que não existem na API, não é falta de extração.

## Novo domínio descoberto: Financeiro (não fazia parte do escopo original)

10. **Nenhum dado financeiro (Contas a Pagar/Receber, extrato bancário) é extraído** — e não existe módulo financeiro no roadmap do ERP novo. Não é uma pergunta a responder, é uma decisão de arquitetura pendente. Ver [[Financas-Lacunas]].

## Ver também
- [[Campos-Faltantes-para-Estoque-MES]]
- [[Contradicao-CFOP]]
- [[Colunas-Protegidas]]
- [[Sintese-Migrar-vs-Nascer-Nativo]]
