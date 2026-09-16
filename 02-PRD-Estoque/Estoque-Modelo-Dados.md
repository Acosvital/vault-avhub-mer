---
tags: [erp-acos-vital, prd-estoque, dados]
criado: 2026-09-16
---

# PRD Estoque — Modelo de Dados

Schema Postgres próprio: `estoque` (isolado, WAL de backup já cobre automaticamente — ver [[Infraestrutura-Self-Hosted]]).

## Entidades principais

- **material** — tipo (MATÉRIA_PRIMA/REVENDA), categoria, peso teórico unitário, tolerância de peso, estoque mínimo/máximo, ponto de pedido.
- **material_alias_omie** — mapeia códigos duplicados do catálogo Omie para um material canônico (saneamento sem tocar no Omie).
- ~~**fornecedor**~~ **(revisto, ver nota abaixo)**, **pedido_compra** (referenciado do av-hub, não criado aqui — ver nota), **item_pedido**, **destinacao_item_pedido** — destinação por item (produção específica / venda específica / estoque geral), não por pedido inteiro.
- **nota_fiscal_entrada** — só referencia (`chave_acesso`); nunca captura CFOP/ICMS-ST (isso fica com o Omie).
- **recebimento**, **pesagem**, **item_recebido** — duas etapas sequenciais: conferência quantitativa (almoxarife) → conferência qualitativa (qualidade).
- **lote** — com `origem` (RECEBIMENTO ou CARGA_INICIAL) e `lote_pai_id` (cisão de lote na reprovação parcial).
- **inspecao_qualidade**, **rnc** (relatório de não conformidade).
- **deposito**, **localizacao_estoque**, **movimento_estoque**.
- **etiqueta** (código de barras/QR/RFID).
- **reserva_estoque** — impede dupla alocação entre PCP e Comercial.
- **ordem_separacao**, **item_separacao**, **devolucao_cliente**, **contagem_ciclica**.

> ⚠️ **Atualização (conversa de arquitetura, 16/09) — muda o desenho original:**
> - **`fornecedor` deixa de ser cadastro próprio do Estoque.** Reaproveita `core.parceiros` (av-hub), já sincronizado do Omie pelo [[Omie-ELT-Pipeline|pipeline ELT]] — o Estoque recebe uma projeção read-only, não um cadastro paralelo.
> - **`pedido_compra` (Ordem de Compra) passa a ser decidido/criado no av-hub, não no Estoque.** O Estoque só referencia a Ordem de Compra quando o material chega na doca (recebimento) — o fluxo de decisão de compra (fornecedor, preço, aprovação) fica no av-hub, o fluxo de execução (conferência, saldo) fica no Estoque/MES. Ver [[MES-Arquitetura-Decisoes]] para o racional completo.
> - Isso não muda `item_pedido`/`destinacao_item_pedido` — eles continuam existindo no Estoque, mas referenciando uma Ordem de Compra que vive fora dele.

## Padrões de design notáveis

1. **Quarentena por padrão** — todo lote nasce com `status_qualidade = PENDENTE`; só fica disponível para PCP/Portal Comercial depois da aprovação da qualidade.
2. **Cisão de lote** (`lote_pai_id`) na reprovação parcial — o lote original aprovado segue com o que sobrou; um lote filho congelado nasce com a quantidade reprovada, aguardando devolução.
3. **Nenhum estado é beco sem saída** — regra explícita, herdada de um bug real do PCP (`/divergencias`). Ver [[Estoque-Riscos]].
4. **Destinação por item, não por pedido** — um mesmo pedido de compra pode ter itens destinados a produção, venda e estoque geral simultaneamente.
5. **Fronteira fiscal clara** — o sistema nunca cria/emite/edita nota fiscal; só sinaliza necessidade (ex.: RNC pedindo devolução) e espera a confirmação vir de volta pela sincronização com o Omie.

## Stack técnica

Next.js (App Router) + CSS Modules + PostgreSQL. **Decisão deliberada de evitar Prisma** (motivo concreto: já deu problema de binário/rede no ambiente de build da equipe, foi por isso que o Backlog Ágil migrou para Sequelize). Recomendação: Drizzle ORM ou Kysely, ambos sobre o driver `pg` puro.

⚠️ Nota de contraste: o [[App-PCP-Modelo-Producao|app-pcp]] **usa Prisma** — decisão de stack diferente, possivelmente anterior a essa lição aprendida, ou escolha consciente do Robert.

## Ver também
- [[PRD-Estoque-Visao-Geral]]
- [[Estoque-Regras-Negocio]]
