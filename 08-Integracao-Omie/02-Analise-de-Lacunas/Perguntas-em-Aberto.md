---
tags: [integracao-omie, lacunas]
criado: 2026-09-17
atualizado: 2026-10-07
---

# Perguntas em aberto sobre a integração Omie

> Status: decidido (itens 1, 4 e 10 fechados) | no código (`master` d2886bf) | em produção (verificado em 07/10/2026 só pelo dump). Decisões em [[Registro-de-Decisoes-2026-10-07]].

> **Atualização de 07/10/2026 — reconferido contra o código do pipeline (`master` d2886bf; leitura de código, não produção).** O que mudou: o saldo de estoque **continua aberto** (recurso `enabled:false`, embora as tabelas de destino já existam no banco); a pergunta 4 (API de criação de OC) já virou código (`UpsertPedCompra`/`ExcluirPedCompra`); a staging raw citada no item 6 **foi removida em 06/10** (contrato 38) — a resposta por documentação continua válida; a pergunta 5 (`comissao`) segue aberta e os vendedores continuam sendo relistados por inteiro. Fechadas no código desde 17/09: pedidos de compra (espelho + envio), compradores, PTAX, projetos/categorias/contas correntes/condições de pagamento, dados fiscais do parceiro, etapas de faturamento, inativação de catálogos. Ainda abertas: locais de estoque (sem recurso), frete/parcelas/desconto do PV, `valor_devolucao`, `lead_time`, remessa, financeiro, endereço de entrega e dados bancários do parceiro, e exclusão de pedido de compra apagado no Omie por fora da OC.

Lista consolidada, cruzando o que a seção de modelagem já sinalizava com o que a leitura direta do código do pipeline confirmou, refutou ou deixou sem resposta.

## Confirmadas como lacunas reais (não é falta de mapeamento, é o dado não existir)

1. **FECHADA em 07/10 (✅, #28): saldo de estoque não sincroniza por decisão** — o Omie recebe dados só manualmente, o estoque do Omie é ignorado e `ListarPosEstoque` **não será habilitado**; o MES é a referência do saldo físico. Texto original: endpoint pronto no código, desabilitado por falta de tabela de destino. **(Atualizado em 07/10: a tabela agora existe no banco — `core.estoque_saldo`/`core.locais_estoque`, contratos 002 e 005 —, mas `estoque.ts` segue `enabled:false`, `table:null`; continua sem sincronizar.)** Ver [[Campos-Faltantes-para-Estoque-MES]] e [[Compras-Estoque-Producao-Lacunas]] (campos completos confirmados na doc da API: `saldo`, `cmc`, `pendente`, `estoque_minimo`, `reservado`, `fisico`).
2. **Devolução parcial não tem valor consultável em massa** — **atualizado**: existe um campo de valor (`vTotal`), mas só via chamada individual `StatusDevolucaoVenda(nCodDevol)`, não em listagem em massa. Ver [[Vendas-NFe-Lacunas]].
3. **Estoque máximo / ponto de pedido / tolerância de peso** — **confirmado que não existem em nenhum endpoint da API** (Produtos, Locais de Estoque, Produto x Fornecedor, Ajuste, Consulta, Resumo, todos verificados). **Estoque mínimo, por outro lado, existe** (por produto×local, via `AlterarEstoqueMinimo`) — ver correção no item 9 abaixo e [[Compras-Estoque-Producao-Lacunas]].

## Respondidas com o levantamento completo da API (2026-09-17)

4. ~~Omie tem API de criação de Ordem de Compra?~~ — **SIM, confirmado**: `produtos/pedidocompra/` tem CRUD completo (`IncluirPedCompra`, `AlteraPedCompra`, `ExcluirPedCompra`, `UpsertPedCompra`), incluindo fluxo de aprovação por e-mail, parcelamento e frete. Ver [[Compras-Estoque-Producao-Lacunas]]. **(Atualizado em 07/10: implementado no pipeline — o `envio-oc-worker` usa `UpsertPedCompra`/`ExcluirPedCompra`, sem `IncluirPedCompra`, e nunca manda parcelas. Ver [[23-Compras-Pipeline-Consolidado]]. Decidido em 07/10 (✅, #7): o envio fica fixo no código, direto ao Omie, sem `SYNC_ENVIO_OC`/`ENVIO_OC_DRY_RUN`; ~4 testes reais do Nathan.)**
5. **Quem preenche as colunas protegidas de `vendedores`, `pedidos_vendas.manual` e `notas_fiscais`?** — ainda não confirmado. Uma pista nova: `vendedores.comissao` existe como campo nativo do Omie (`geral/vendedores/`) e hoje não é extraído nem por nós nem, aparentemente, por ninguém — vale checar se é essa a fonte antes de assumir que vem de outro sistema. Ver [[Colunas-Protegidas]] e [[Vendas-NFe-Lacunas]]. **(Atualizado em 07/10: `comissao` continua protegida e o `vendedores.ts` relista o catálogo inteiro a cada 3 min sem gravá-la. Os donos das demais colunas foram levantados no código e no vault (🟡; detalhe em [[Colunas-Protegidas]]): `pedidos_vendas.manual` e `notas_fiscais.manual/descontos/averbado` vêm das telas manuais do av-hub (contratos 30 e 29), `vendedores.id_funcionario/id_usuario/filial/ajuda_custo` da tela de Vendedores (contrato 39). Só o significado de `comissao` (boolean) segue 🔴 Nathan.)**
6. **O payload bruto do Omie (`ListarProdutos`) tem mais campos que o pipeline não mapeia?** — **sim, confirmado diretamente na documentação da API** (não precisou habilitar o staging raw — que, aliás, **foi removido do código em 06/10**, contrato 38; atualizado em 07/10): `lead_time`, características, kit, imagens, tabelas de preço e todo o bloco fiscal existem no cadastro de produto e não são extraídos. Ver [[Compras-Estoque-Producao-Lacunas]].

## Corrigida nesta análise (era um mal-entendido, não uma lacuna)

7. ~~CFOP não é capturado~~ — **falso**: já é capturado por item de venda em `produto_vendas.cfop`. Só ICMS-ST de fato não é capturado. Ver [[Contradicao-CFOP]].
8. ~~Histórico de status do pedido é limitado por causa do Omie~~ — **impreciso**: a granularidade de `pedidos_vendas_status_historico` é uma decisão de schema do banco, o pipeline nem escreve nessa tabela (`situacao` é recalculada por trigger). Resolver isso não depende de trazer mais dado do Omie.

## Parcialmente resolvida

9. **Peso do produto vem do Omie?** — sim, `peso_bruto` e `peso_liq` já vêm prontos em `core.produtos.especificacoes`. **Atualizado**: estoque mínimo também vem pronto (por produto×local, via `estoque/ajuste/`). O que falta de verdade é só tolerância de peso, estoque máximo e ponto de pedido (item 3 acima) — confirmado que não existem na API, não é falta de extração.

## Novo domínio descoberto: Financeiro (não fazia parte do escopo original)

10. **Nenhum dado financeiro (Contas a Pagar/Receber, extrato bancário) é extraído** — e não existe módulo financeiro no roadmap do ERP novo. Não é uma pergunta a responder, é uma decisão de arquitetura pendente. Ver [[Financas-Lacunas]]. **FECHADA em 07/10 (✅, #30; DEC-11): o Omie segue como sistema financeiro e fiscal, sem plano de desligar.**

## Ver também
- [[Campos-Faltantes-para-Estoque-MES]]
- [[Contradicao-CFOP]]
- [[Colunas-Protegidas]]
- [[Sintese-Migrar-vs-Nascer-Nativo]]
