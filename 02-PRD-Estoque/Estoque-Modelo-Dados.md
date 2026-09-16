---
tags: [erp-acos-vital, prd-estoque, dados]
criado: 2026-09-16
---

# PRD Estoque — Modelo de Dados

Desenho original: schema Postgres próprio `estoque` (isolado, WAL de backup já cobre automaticamente — ver [[Infraestrutura-Self-Hosted]]), dentro do mesmo cluster multi-schema do av-hub.

> ⚠️ **Atualização (16/09) — desenho de localização mudou:** o Estoque passa a morar dentro do **banco do MES** (Prisma, banco separado do cluster do av-hub/`api-acos-vital`), não no cluster Postgres multi-schema descrito acima — ver [[MES-Arquitetura-Decisoes]]. ✅ Confirmado: ganha um schema Postgres próprio dentro do banco do MES (seguindo a convenção de schema-por-domínio já usada no av-hub), não cai em `public`. O WAL de backup da VPS2 (cluster do av-hub) **não** cobre automaticamente o banco do MES caso ele seja outra instância/VPS — vale confirmar isso também.

## Entidades principais

- **material** — ✅ **Confirmado (16/09): projeção de `core.produtos` (av-hub)**, mesmo padrão já decidido pra fornecedor (`core.parceiros`). Campos extras do lado do Estoque (tipo MATÉRIA_PRIMA/REVENDA, categoria, peso teórico unitário, tolerância de peso, estoque mínimo/máximo, ponto de pedido) podem vir do próprio Omie quando o dado já existir lá, ou virar colunas novas só do lado do Estoque quando o Omie não tiver o campo.
- **material_alias_omie** — mapeia códigos duplicados do catálogo Omie para um material canônico (saneamento sem tocar no Omie). ⚠️ **Achado novo (16/09):** precisa de uma **tela dedicada** pra isso, não só a tabela de mapeamento — cenário real: vendedor não encontrou o produto no Omie (ex.: por falta de acento na busca) e cadastrou um novo por engano, gerando duplicidade. Alguém (comprador/PCP) precisa de uma interface pra juntar/vincular os dois materiais num canônico só, depois que a duplicidade é identificada.
- ~~**fornecedor**~~ **(revisto, ver nota abaixo)**, **pedido_compra** (referenciado do av-hub, não criado aqui — ver nota), **item_pedido**, **destinacao_item_pedido** — destinação por item (produção específica / venda específica / estoque geral), não por pedido inteiro.
- **nota_fiscal_entrada** — só referencia (`chave_acesso`); nunca captura CFOP/ICMS-ST (isso fica com o Omie).
- **recebimento**, **pesagem**, **item_recebido** — duas etapas sequenciais: conferência quantitativa (almoxarife) → conferência qualitativa (qualidade).
- **lote** — com `origem` (RECEBIMENTO ou CARGA_INICIAL) e `lote_pai_id` (cisão de lote na reprovação parcial).
- **inspecao_qualidade**, **rnc** (relatório de não conformidade).
- **deposito** (`warehouse`), **localizacao_estoque**, **movimento_estoque**. ⚠️ Confirmado (16/09): depósito é **central compartilhado**, não vinculado a uma fábrica específica — múltiplos warehouses (Warehouse 01, Warehouse 02...), cada um com saldo próprio e relatório geral; todas as fábricas e a Revenda puxam do mesmo conjunto de depósitos. Ver [[Perguntas-Pendentes-MES-Estoque]] (pergunta 4, resolvida).
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

Next.js (App Router) + CSS Modules + PostgreSQL. Recomendação original (agora revertida — ver nota abaixo): evitar Prisma (motivo concreto: já deu problema de binário/rede no ambiente de build da equipe, foi por isso que o Backlog Ágil migrou para Sequelize), preferindo Drizzle ORM ou Kysely sobre o driver `pg` puro.

> ⚠️ **Atualização (conversa de arquitetura, 16/09) — recomendação revertida:** o Estoque passa a morar dentro do mesmo banco do [[App-PCP-Visao-Geral|MES]] (Prisma), seguindo a disciplina de migrations que o Prisma já traz em produção lá. O motivo da recomendação original (problema de build no Backlog Ágil) **não se repetiu em ~1 mês de MES em produção** — deixou de ser um risco ativo. Ver [[MES-Arquitetura-Decisoes]], decisão 4. A nota de "contraste" abaixo, portanto, deixa de ser um contraste: Estoque e app-pcp/MES agora compartilham a mesma stack de dados por decisão consciente, não por coincidência.

O [[App-PCP-Modelo-Producao|app-pcp]] já **usa Prisma** desde o início — o Estoque passa a seguir a mesma escolha.

## Ver também
- [[PRD-Estoque-Visao-Geral]]
- [[Estoque-Regras-Negocio]]
