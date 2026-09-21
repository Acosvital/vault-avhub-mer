---
tags: [integracao-omie, levantamento-api, lacunas]
criado: 2026-09-17
---

# Vendas e NF-e — o que falta além do que já sincronizamos

## Valor da devolução parcial — resposta à lacuna conhecida

**Existe um campo de valor** (`vTotal`), mas só é acessível chamando `StatusDevolucaoVenda(nCodDevol)` **individualmente por devolução** — não existe listagem em massa nesse endpoint (`produtos/devolucaovendafaturamento/`). Em todos os outros lugares (pedido, etapas, NF) a devolução continua sendo só um boolean (`devolvido`, `devolvido_parcial`), sem valor.

**Para preencher essa lacuna seria preciso**: capturar o `nCodDevol` (ou `nIdPedDev`, presente em `nfconsultar.pedido`) no momento da devolução, e então consultar `StatusDevolucaoVenda` para cada devolução conhecida — não dá pra trazer isso num sync em massa como o resto do pipeline faz hoje. Também não é claro se `vTotal` é o valor da devolução parcial especificamente ou o valor total do pedido devolvido — precisa validação em ambiente real antes de implementar.

## Pedido de Venda — campos que faltam no que já extraímos

- `tipo_desconto_pedido`/`perc_desconto_pedido`/`valor_desconto_pedido` — desconto no nível do pedido (hoje só temos por item)
- **`frete`** (transportadora, modalidade, peso, valor do frete/seguro, rastreio) — **totalmente ausente**
- **`lista_parcelas`** (condição de pagamento detalhada) — ausente
- Impostos por item (ICMS/ICMS-ST/IPI/PIS/COFINS/IBS/CBS) — ausentes, só relevantes se precisar recompor tributos sem consultar a NF separadamente
- `nfRelacionada`/status_nfe/protocolo/XML — parcialmente coberto (temos a NF em si, não o status de autorização/protocolo)

## Pedido de Venda - Etapas (histórico de mudança de etapa)

Trilha completa de auditoria: quem mudou pra qual etapa, quando, com sub-blocos de faturamento/cancelamento/devolução. Não extraído. **Recomendação**: é dado operacional/log — melhor nascer como evento nativo no sistema próprio (registrado no momento em que a mudança acontece) do que ser puxado retroativamente do Omie.

## CT-e (Conhecimento de Transporte)

Só importador de XML + workflow, sem listagem completa. Documento fiscal de frete/transporte. Se for volume relevante de custo de frete, vale migrar como histórico; se for baixo volume, tratar como referência pontual.

## Remessa de Produtos

Documento fiscal completo (não é write-only): cabeçalho, frete, itens com impostos completos, NF-e de remessa gerada, devolução de remessa. Não extraído. Como a Aços Vital faz beneficiamento/corte (possível envio de material para terceiros), **é candidata forte a migrar como dado histórico real** — é movimentação de mercadoria sem venda, documento fiscal de verdade.

## NF-e Consultas — campos que faltam

- `total.ICMSTot.vFrete/vSeg/vDesc/vOutro/vTotTrib`
- **`titulos`** (parcelas geradas no contas a receber pela própria NF, com vencimento/valor) — relevante para faturamento líquido/inadimplência, cruza com [[Financas-Lacunas]]
- `det.itemPedido.nItemQtdDevolvida` — **quantidade** devolvida por item existe (mas não o valor)
- `ide.finNFe`, `cDeneg`, `dInut`

## Vendedores

Falta `comissao` (percentual), `fatura_pedido`, `visualiza_pedido`. `comissao` é relevante se o sistema próprio for calcular comissionamento nativamente (hoje essa coluna já é protegida no pipeline — ver [[Colunas-Protegidas]] — porque presumidamente vem de outro sistema; vale confirmar se esse "outro sistema" é justamente esse campo do Omie).

## Tabela de Preços

Cadastro completo de precificação (tabelas, filtros por produto/cliente, desconto/acréscimo). Não extraído. Como impacta diretamente o `valor_unitario` usado nos pedidos, faz sentido nativizar — é configuração comercial com impacto direto em margem.

## Meios de Pagamento / Motivos de Devolução

Tabelas de lookup triviais (código + descrição). Baixo custo de nativizar como enum/tabela estática, sem necessidade de sincronização contínua.

## Ver também
- [[Financas-Lacunas]]
- [[Sintese-Migrar-vs-Nascer-Nativo]]
- [[Pedidos-de-Venda]] (extração atual)
- [[Notas-Fiscais-e-Itens]] (extração atual)
