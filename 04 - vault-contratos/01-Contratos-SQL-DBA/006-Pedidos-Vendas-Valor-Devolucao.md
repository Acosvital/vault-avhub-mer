---
tags: [contrato-sql, dba, omie-elt-pipeline, achado]
status: proposta
criado: 2026-09-17
---

# Contrato 011 — `pedidos_vendas.valor_devolucao`

**Status:** proposta, aguardando revisão e aplicação pelo DBA (Gustavo).
Nada aplicado ainda. Design **não fechado com o usuário** — vem da
documentação pública da API (`developer.omie.com.br`, endpoint "Devolução
de venda - Faturamento"), não de payload real confirmado. Este é o único
contrato desta leva que exige uma chamada de API **fora** do fluxo normal
de sync (ver seção "Como preencher" abaixo) — vale ler com atenção antes
de aplicar.

**Repositório de origem:** `omie-elt-pipeline` (`sql/dba_migrations/011_pedidos_vendas_valor_devolucao_contrato.md`).

## Por quê

Hoje `pedidos_vendas.devolucao_parcial` é só um boolean (`infoCadastro.devolvido_parcial`
convertido via `snParaBool`) — não existe, em nenhuma coluna sincronizada,
o valor monetário da devolução. Isso afeta o cálculo de faturamento líquido
(grupo G2P). Levantamento na API confirmou que existe um campo de valor
(`vTotal`), mas só acessível por uma chamada **individual** por devolução —
não em listagem em massa, diferente de todo o resto do pipeline.

## Payload de referência (documentação pública, não confirmado contra conta real)

```
POST https://app.omie.com.br/api/v1/produtos/devolucaovendafaturamento/
{"call":"StatusDevolucaoVenda","param":[{"nCodDevol": 12345}], ...}
```

```
nCodDevol    integer   -- id da devolução
cNumPed      string(15)
cEtapa       string(2)
cCancelada   string(1)  -- "S"/"N"
cFaturada    string(1)  -- "S"/"N"
vTotal       decimal    -- valor — NÃO CONFIRMADO se é o valor da devolução
                         -- parcial especificamente ou o valor total do
                         -- pedido devolvido (ver "Perguntas em aberto")
ListaNfe[]   -- NFs de devolução geradas
```

`nCodDevol` é obtido via `nfconsultar.pedido.nIdPedDev` (já presente no
payload de `ListarNF`, que `notasFiscais.ts` já consome — não precisa de
chamada nova para descobrir o id, só para consultar o status).

## DDL

```sql
ALTER TABLE core_vendas_faturamento.pedidos_vendas
  ADD COLUMN codigo_devolucao_omie integer,   -- nCodDevol, guardado mesmo
                                               -- sem valor ainda resolvido,
                                               -- serve de fila de trabalho
                                               -- pro job do Passo 8
  ADD COLUMN valor_devolucao        numeric(14,2),
  ADD COLUMN devolucao_consultada_em timestamptz;  -- quando o job de
                                                    -- StatusDevolucaoVenda
                                                    -- rodou pela última vez
                                                    -- pra este pedido
```

## Como preencher (não é sync normal)

Diferente de todo outro campo deste pipeline, `valor_devolucao` **não** vem
do sync padrão de `ListarPedidos`/`ListarNF`. Fluxo proposto:

1. `notasFiscais.ts` (que já lê `pedido.nIdPedDev`) grava
   `codigo_devolucao_omie` no upsert normal do pedido, sem custo de API
   extra.
2. Um **job separado** (novo, ex. `src/jobs/devolucaoStatusSync.ts`) varre
   `pedidos_vendas WHERE devolucao_parcial = true AND codigo_devolucao_omie
   IS NOT NULL AND (devolucao_consultada_em IS NULL OR desatualizado)`,
   chama `StatusDevolucaoVenda` individualmente por linha, grava `vTotal`
   em `valor_devolucao` e atualiza `devolucao_consultada_em`.
3. Cadência sugerida: bem menos frequente que os syncs normais (ex.: 1x/dia)
   — é volume baixo (só pedidos com devolução parcial) e cada chamada é
   individual, então rodar junto com `sync_hoje` (3 em 3 min) desperdiçaria
   rate limit sem necessidade.

## Perguntas em aberto (levar para o Gustavo e para quem decide o produto antes de aplicar)

1. **Crítico**: confirmar em ambiente de teste se `vTotal` é o valor
   específico da devolução parcial ou o valor total do pedido original
   devolvido — muda completamente o que a coluna `valor_devolucao`
   significa. Não aplicar em produção sem essa confirmação.
2. Se `vTotal` acabar sendo o valor total do pedido (não específico da
   devolução), pode ser necessário calcular o valor da devolução parcial
   por diferença (`valor_total_pedido - vTotal`) ou buscar outro campo —
   revisar o payload real de `StatusDevolucaoVenda` contra um caso conhecido
   antes de fechar o design.

## Depois de criada

Avisar o dev para: (a) ampliar `notasFiscais.ts` com o campo
`codigo_devolucao_omie`, (b) criar o job novo `devolucaoStatusSync.ts`,
(c) **validar a pergunta 1 acima contra um caso real conhecido de devolução
parcial** antes de considerar o dado confiável para uso em relatório de
faturamento líquido.

## Ver também
- [[Home]]
- [[003-Pedidos-Vendas-Frete-Parcelas]]
