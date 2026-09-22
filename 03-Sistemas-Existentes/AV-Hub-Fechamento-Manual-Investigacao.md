---
tags: [erp-acos-vital, av-hub, fechamento, investigacao, achado]
criado: 2026-09-22
---

# `fechamento_manual` — investigação da regra de negócio

> **Pergunta que esta nota fecha**: [[AV-Hub-Modulos]] descrevia o módulo Fechamento só de passagem ("tabela `fechamento_manual`, confirmada existente no backend real"), sem detalhar a regra de transição manual→automático nem confirmar se ela é real no código. Testado empiricamente contra o `api-acos-vital` rodando em Docker local e o Postgres carregado a partir do dump de produção — mesma metodologia de [[AV-Hub-Views-Compras-Investigacao]] e [[AV-Hub-Favoritos-Clientes-Inativos-Investigacao]].

## 1. O que o código confirma

`src/models/fechamento_manual.js` (schema `core_vendas_faturamento`, sem bug de nome de schema) documenta a própria regra de negócio no comentário do model:

> "Fechamento oficial de Vendas/Faturamento por mês, digitado manualmente pelo admin na tela Fechamento. Existe para os meses em que o total automático dos dashboards divergia (jan-ago/2026); de 09/2026 em diante a tela usa `fn_dashboard_mensal_vendas`/`fn_dashboard_mensal_faturamento`."

CRUD completo em `src/routes/fechamento_manual.js`: `POST` (upsert por `mes+ano+tipo`, `201`/`200` conforme cria ou atualiza), `GET` (lista paginada, filtro por ano/mês/tipo), `GET /:ano/:mes/:tipo` (busca pontual), `DELETE` (remoção física — sem soft delete, decisão documentada de 17/08/2026: "depois de remover, a tela volta a mostrar o mês como 'ainda não preenchido'").

## 2. Confirmado em runtime: a transição jan-ago → automático é real

```
$ curl -H "x-api-key: <chave>" "http://localhost:3001/fechamento_manual?ano=2026"
HTTP 200 — 16 linhas: meses 1 a 8 de 2026, tipos "venda" e "faturamento" (8×2)
```

Todos os 16 registros têm `valor_total` real (ex.: jan/2026 venda = R$ 29.320.774,13; ago/2026 faturamento = R$ 26.089.530,46), `created_at` em 10/09/2026 — o admin digitou tudo de uma vez, retroativamente, no dia em que a divergência foi identificada e corrigida.

```sql
SELECT mes,ano,tipo,valor_total FROM core_vendas_faturamento.fechamento_manual
WHERE ano=2026 AND mes >= 9;
-- 0 rows
```

**Nenhum registro a partir de setembro/2026** — bate exatamente com o que o comentário do código promete. E as duas funções automáticas existem de verdade no banco:

```sql
SELECT proname FROM pg_proc WHERE proname LIKE 'fn_dashboard_mensal%';
-- fn_dashboard_mensal_faturamento
-- fn_dashboard_mensal_faturamento_por_unidade
-- fn_dashboard_mensal_vendas
-- fn_dashboard_mensal_vendas_por_unidade
```

## 3. Achado que a documentação antiga não tinha como confirmar: a "prioridade pontual" do manual sobre o automático não está no backend

[[AV-Hub-Modulos]] afirma: *"a partir de setembro/2026 lê automaticamente dos dashboards, mas um lançamento manual salvo continua tendo prioridade pontual sobre o automático."* Essa segunda parte — manual sobrepondo automático mesmo depois de setembro — **não tem nenhum suporte no backend**, confirmado por busca no código inteiro:

```
$ grep -rn "FechamentoManual\|fechamento_manual" src/routes src/services
# (nenhum resultado fora do próprio routes/fechamento_manual.js e models/fechamento_manual.js)
```

`src/routes/fn_dashboard_mensal_vendas.js` (e o equivalente de faturamento) chama só `fn_dashboard_mensal_vendas(mes, ano, ...)` — nunca consulta `fechamento_manual`. Os dois caminhos são **completamente independentes** no backend: não existe merge, fallback nem override entre eles em nenhum lugar do `api-acos-vital`.

**Não investigado nesta nota** (fora do alcance sem o repositório do frontend av-hub, que não está disponível neste ambiente): se a "prioridade pontual" é implementada no **frontend** — a tela Fechamento chamando os dois endpoints e decidindo qual valor mostrar por mês — é arquiteturalmente possível dado que av-hub é BFF puro ([[AV-Hub-Arquitetura-BFF]]), mas não pode ser confirmado nem descartado a partir do backend sozinho. Fica como pergunta em aberto, não como erro corrigido: a frase do vault antigo pode estar certa (lógica no frontend) ou desatualizada (a "prioridade pontual" nunca chegou a ser implementada) — só dá para saber lendo o código do `av-hub-main`.

## 4. Regra de negócio, como confirmada

1. Jan-ago/2026: valor de Vendas e Faturamento por mês é **100% digitado manualmente** pelo admin, gravado em `fechamento_manual` (upsert por `mes+ano+tipo`).
2. Set/2026 em diante: os totais mensais são calculados automaticamente por `fn_dashboard_mensal_vendas`/`fn_dashboard_mensal_faturamento`, sem depender de `fechamento_manual` — confirmado, nenhum registro manual existe para esses meses e nenhum código do backend cruza as duas fontes.
3. Se algum admin cadastrar manualmente um mês a partir de set/2026, o registro seria aceito pelo `POST` normalmente (não há trava no backend impedindo isso) — mas, pelo que o backend mostra, **nada usaria esse valor** para sobrepor o cálculo automático. Se a UI quiser dar prioridade ao manual mesmo depois de set/2026, isso precisa ser resolvido no frontend, e não está confirmado que exista.
4. Sem soft delete — remoção é física, decisão de 17/08/2026.

## Ver também
- [[AV-Hub-Modulos]] — texto original que motivou esta investigação
- [[AV-Hub-Vendas-Reconciliacao]] — contexto da divergência que originou o fechamento manual
- [[AV-Hub-Arquitetura-BFF]] — por que a lógica de merge, se existir, só pode estar no frontend
- [[AV-Hub-Views-Compras-Investigacao]] e [[AV-Hub-Favoritos-Clientes-Inativos-Investigacao]] — mesma metodologia de investigação empírica
