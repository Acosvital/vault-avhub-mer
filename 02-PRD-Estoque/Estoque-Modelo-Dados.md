---
tags: [erp-acos-vital, prd-estoque, dados]
criado: 2026-09-16
---

# PRD Estoque — Modelo de Dados

O Estoque mora dentro do **banco do MES** (Prisma, banco separado do cluster do av-hub/`api-acos-vital`) — ver [[MES-Arquitetura-Decisoes]]. Dentro do banco do MES, ganha um schema Postgres próprio (seguindo a convenção de schema-por-domínio já usada no av-hub), não cai em `public`. O WAL de backup da VPS2 (cluster do av-hub, ver [[Infraestrutura-Self-Hosted]]) não cobre automaticamente o banco do MES caso ele seja outra instância/VPS — vale confirmar isso também.

## Entidades principais

- **material** — projeção de `core.produtos` (av-hub), mesmo padrão já decidido pra fornecedor (`core.parceiros`). Campos extras do lado do Estoque (tipo MATÉRIA_PRIMA/REVENDA, categoria, peso teórico unitário, tolerância de peso, estoque mínimo/máximo, ponto de pedido) podem vir do próprio Omie quando o dado já existir lá, ou virar colunas novas só do lado do Estoque quando o Omie não tiver o campo.
- ~~**material_alias_omie** — mapeia códigos duplicados do catálogo Omie para um material canônico~~ ❌ **CANCELADO em 21/09/2026**: decisão do Nathan — "não quero mais tratar isso aqui, se eles quiserem eles tratam lá no Omie". Duplicata de catálogo sai do escopo deste sistema. O contrato de API 002 foi rejeitado e a tarefa D4 removida do [[Cronograma-2-Meses]]. A tela **Produtos — Prováveis Duplicatas** (só leitura, já em produção) continua existindo — só a ação de vincular/resolver é que não será construída.
- **fornecedor** deixa de ser cadastro próprio do Estoque — reaproveita `core.parceiros` (av-hub), já sincronizado do Omie pelo [[Omie-ELT-Pipeline|pipeline ELT]]; o Estoque recebe uma projeção read-only, não um cadastro paralelo.
- **pedido_compra** (Ordem de Compra) é decidido/criado no av-hub, não no Estoque. O Estoque só referencia a Ordem de Compra quando o material chega na doca (recebimento) — o fluxo de decisão de compra (fornecedor, preço, aprovação) fica no av-hub, o fluxo de execução (conferência, saldo) fica no Estoque/MES. Ver [[MES-Arquitetura-Decisoes]] para o racional completo.
- ~~**item_pedido**, **destinacao_item_pedido** — continuam existindo no Estoque como tabela própria~~ ✅ **CORRIGIDO em 21/09/2026 (M-05)**: não viram tabela nova no Estoque. A destinação por item (produção específica / venda específica / estoque geral) já é decidida e guardada pelo PCP (schema de Produção, mesmo banco do MES) — o Estoque **lê direto** via JOIN entre schemas, sem duplicar dado, mesmo princípio já usado pra `fornecedor`. O diagrama de dados ([[Diagramas-UML]] seção 17), que nunca teve essas duas entidades, estava certo; este texto é que estava desatualizado. Decisão confirmada pelo Nathan — ver [[Perguntas-em-Aberto-Consolidadas]] (M-05).
- **nota_fiscal_entrada** — só referencia (`chave_acesso`); nunca captura CFOP/ICMS-ST de entrada (isso fica com o Omie — Nota de Entrada não é sincronizada hoje). **Correção**: o CFOP do lado da venda já é capturado por item em `produto_vendas.cfop`, sincronizado do Omie; é dado diferente do CFOP de entrada aqui referido. ICMS-ST continua não capturado em nenhum dos dois lados.
- **recebimento**, **pesagem**, **item_recebido** — duas etapas sequenciais: conferência quantitativa (almoxarife) → conferência qualitativa (qualidade). **Resolvido em 21/09/2026 (M-07)**: `item_recebido` ganha `tipo_referencia` (`PEDIDO_VENDA`\|`ORDEM_COMPRA`) + `id_referencia` — a flag acabado/não-acabado (decidida em Compras) escolhe automaticamente contra qual dos dois conferir a quantidade recebida, sem precisar de dois fluxos de Recebimento separados. Mesmo padrão polimórfico já em produção no av-hub (`auth.usuarios_favoritos.tipo`+`referencia_id`), com FK real em cada lado aqui (alvos fixos). A conferência qualitativa não muda.
- **lote** — com `origem` (RECEBIMENTO ou CARGA_INICIAL) e `lote_pai_id` (cisão de lote na reprovação parcial).
- **inspecao_qualidade**, **rnc** (relatório de não conformidade).
- **deposito** (`warehouse`), **localizacao_estoque**, **movimento_estoque**. Depósito é **central compartilhado em relação à fábrica** — não vinculado a uma fábrica específica, múltiplos warehouses (Warehouse 01, Warehouse 02...), cada um com saldo próprio; todas as fábricas e a Revenda puxam do mesmo conjunto. **Atualização (21/09/2026, L-09)**: em relação à **filial**, não é incondicional — `deposito.codigo_empresa` existe e é preenchido **quando aquela filial tiver seu próprio setor de compras**; não é regra universal desde o dia 1. Ver [[Perguntas-Pendentes-MES-Estoque]] (pergunta 4) e [[Lacunas-de-Logica-e-Clareza]] (L-09).
- **etiqueta** (código de barras/QR/RFID).
- **reserva_estoque** — impede dupla alocação entre PCP e Comercial.
- **ordem_separacao**, **item_separacao**, **devolucao_cliente**, **contagem_ciclica**.

## Padrões de design notáveis

1. **Quarentena por padrão** — todo lote nasce com `status_qualidade = PENDENTE`; só fica disponível para PCP/Portal Comercial depois da aprovação da qualidade.
2. **Cisão de lote** (`lote_pai_id`) na reprovação parcial — o lote original aprovado segue com o que sobrou; um lote filho congelado nasce com a quantidade reprovada, aguardando devolução.
3. **Nenhum estado é beco sem saída** — regra explícita, herdada de um bug real do PCP (`/divergencias`). Ver [[Estoque-Riscos]].
4. **Destinação por item, não por pedido** — um mesmo pedido de compra pode ter itens destinados a produção, venda e estoque geral simultaneamente.
5. **Fronteira fiscal clara** — o sistema nunca cria/emite/edita nota fiscal; só sinaliza necessidade (ex.: RNC pedindo devolução) e espera a confirmação vir de volta pela sincronização com o Omie.

## Stack técnica

Next.js (App Router) + CSS Modules + PostgreSQL. O Estoque mora dentro do mesmo banco do [[App-PCP-Visao-Geral|MES]] e usa **Prisma**, seguindo a disciplina de migrations que o Prisma já traz em produção lá. A preocupação original com Prisma (problema de binário/rede no ambiente de build da equipe, motivo pelo qual o Backlog Ágil migrou para Sequelize) não se repete no MES em produção — não é um risco ativo. Ver [[MES-Arquitetura-Decisoes]], decisão 4.

O [[App-PCP-Modelo-Producao|app-pcp]] já **usa Prisma** desde o início — o Estoque segue a mesma escolha, compartilhando a mesma stack de dados por decisão consciente, não por coincidência.

## Ver também
- [[Campos-e-API-para-Rastreabilidade]] — campos de autoria, tempo e vínculo com o item do pedido que este modelo ainda não tem (e que devem entrar nas migrations do v1).
- [[PRD-Estoque-Visao-Geral]]
- [[Estoque-Regras-Negocio]]
