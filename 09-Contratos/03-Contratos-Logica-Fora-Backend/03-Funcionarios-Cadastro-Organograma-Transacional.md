# Contrato — Funcionários: salvar/excluir com o organograma numa operação só

**Criado em:** 20/09/2026, ao oficializar a tela nova de Funcionários.

**Problema:** hoje, salvar um funcionário é uma **sequência de chamadas feitas pelo navegador**, sem
transação. Regras de integridade (não formar ciclo na hierarquia, não deixar "reporta a" órfão) vivem
no front. Cada trecho está marcado com `GAMBIARRA(` em `components/Funcionarios/acoes.ts` e
`services/rh/organogramaNodes.ts`.

## 1. O que acontece hoje

**Salvar** (`salvarFuncionario`):
1. Se o "reporta a" mudou, `reportaACriaCiclo` sobe a cadeia de superiores **uma chamada por nível**
   (`GET /organograma_nodes/{id}`, até 50) para ver se fecharia ciclo. Só enxerga overrides manuais
   (o pai automático é calculado pelo banco e não é consultável).
2. `PUT`/`POST /funcionarios`.
3. Se o "reporta a" mudou, `POST`/`PUT`/`DELETE /organograma_nodes` — **em best-effort**: se falhar,
   o funcionário já foi salvo e a hierarquia fica divergente, sem aviso ao usuário.

**Excluir** (`excluirFuncionario`): `DELETE /funcionarios/{id}`, depois `DELETE /organograma_nodes/{id}`
e `limparOverridesApontandoPara`, que baixa todos os funcionários do setor e chama
`GET /organograma_nodes/{id}` **para cada um** (N+1) para apagar quem apontava manualmente para a pessoa.

Riscos: estados intermediários visíveis a outros usuários, ciclo criado por corrida entre dois
usuários, N+1 no navegador, e a regra de integridade duplicada em cada tela que mexer nisso.

## 2. O que peço

### 2.1 `reporta_a_id` como campo do próprio funcionário

`POST`/`PUT /funcionarios` aceita `reporta_a_id` (uuid do superior ou `null` = automático pelo
setor). O backend, **na mesma transação**:

- valida que o superior é do mesmo setor e não está desligado;
- rejeita se formar ciclo (considerando o pai **efetivo**, manual ou automático) com `409` e corpo
  `{ "codigo": "CICLO_HIERARQUIA", "mensagem": "…" }`;
- cria/atualiza/remove o nó do organograma conforme o valor (só grava override quando é escolha
  manual — regra atual de `definirReportaA`, ver `docs/organograma-hierarquia-schema.md`).

`GET /funcionarios/{id}` devolve `reporta_a_id` (override manual) e `reporta_a_efetivo_id` (o pai
que vale hoje) — a tela hoje só sabe o manual.

### 2.2 Exclusão em cascata

`DELETE /funcionarios/{id}` remove o nó da pessoa e limpa, na mesma transação, todo override que
apontava para ela (quem reportava manualmente volta ao cálculo automático). Sem chamada extra do
navegador.

### 2.3 Consulta de hierarquia

`GET /funcionarios/{id}/equipe` — subordinados diretos **efetivos** (manuais + automáticos) — hoje
impossível de montar no front, e a tela de Funcionários não consegue mostrar "equipe direta".

## 3. O que muda na tela

- `acoes.ts`: `salvarFuncionario` vira um único `POST/PUT` com `reporta_a_id`; some
  `reportaACriaCiclo`, `definirReportaA`, `deletarOrganogramaNode`, `limparOverridesApontandoPara`.
- `FuncionarioPainel.tsx`: o aviso de ciclo passa a vir do `409`; ganha a aba "Equipe".
- `services/rh/organogramaNodes.ts` deixa de ser usado por esta tela.

## 4. Aceite

- Dois usuários criando ciclo ao mesmo tempo: exatamente um recebe `409`.
- Falha ao gravar o organograma desfaz o cadastro (nada fica pela metade).
- Excluir um superior com 30 subordinados manuais é uma chamada e todos voltam ao automático.
