---
atualizado: 2026-10-07
---

# Contrato — Solicitações de vagas: fila, decisão e permissões no banco

> **✅ Situação em 01/10/2026 — ENTREGUE (conferido na `api-test`).**
>
> O DBA avisou que terminou; conferido em 01/10/2026 na `api-test` (vaga de teste criada e apagada):
>
> | Teste | Esperado | Resultado |
> |---|---|---|
> | `PUT /vagas/{id}` com `situacao: "aprovado"` | 400 `SITUACAO_SO_PELA_DECISAO` | ✅ 400 `SITUACAO_SO_PELA_DECISAO` |
> | `POST /vagas/{id}/decisao` por usuário sem `pode_aprovar` | 403 | ✅ 403 |
> | Decisão por quem tem `pode_aprovar` (RH - Joanes) | 200 | ✅ 200 |
> | Editar o salário de vaga **aprovada** (§3.3.1) | 200, volta para `pendente`, `decidido_*` limpos | ✅ 200, `situacao: pendente`, `decidido_por/em: null`, `custo_total` recalculado |
> | Histórico `GET /vagas/{id}/decisoes` | linha `origem = 'edicao'` com "Dados alterados: salario" | ✅ duas linhas: `decisao` (pendente→aprovado) e `edicao` (aprovado→pendente) |
>
> Falta só do lado do av-hub: já trata os dois comportamentos (409 `VAGA_DECIDIDA` da API antiga e a volta para pendente), e o tratamento do 409 pode ser removido quando todos os ambientes estiverem na regra nova. A trava `VAGAS_TRAVAS_DECISAO` está ligada na `api-test`; **confirmar a mesma variável em produção** na hora de aplicar lá. **(atualizado em 07/10)** A chave `VAGAS_TRAVAS_DECISAO` **saiu do código** no contrato 38 (`c8f2f5e`, #279): a trava vale sempre, não há mais variável a conferir; falta só confirmar em produção que a API está nessa versão.
>
> **Histórico (25/09/2026):** faltavam ligar a trava e a regra da §3.3.1 no backend. Resolvidos pelo DBA.

**Criado em:** 20/09/2026, ao oficializar a tela nova de Solicitações de vagas (`components/Vagas/`).

**Princípio:** listagem, filtro, ordenação, agregação, cálculo de custo **e quem pode decidir** são
responsabilidade do banco/API. Hoje a tela decide tudo isso no navegador. Cada trecho está marcado
com `GAMBIARRA(` no código.

> Nota: o contrato de ordenação (`ENVIAR - contrato-ordenacao-listagens.md`) tirou `/vagas` do escopo
> porque não tinha dado. A tela nova faz a fila de decisão do RH/diretoria, então volta ao escopo.

## 1. O que a API entrega hoje

`GET /vagas` (o BFF só repassa): `page`, `limit`, `solicitante`, `cargo`, `setor`, `situacao`.
`POST /vagas`, `PUT /vagas/{id}` (registro inteiro), `DELETE /vagas/{id}`. Sem ordenação, sem `tipo_vaga`
como filtro, sem busca em vários campos, sem agregação.

## 2. Onde a tela contorna

> V1–V8 abaixo descrevem a tela **em produção** hoje. No front já portado (worktree
> `wt-rh-contratos`, não commitado) V1–V8 já sumiram todos — inclusive V7 (o painel já lê
> `decidido_em`/`decidido_por_nome` do banco, não mais `updated_at`).

| # | Gambiarra hoje | Onde |
|---|---|---|
| V1 | Baixa **todas** as solicitações e filtra no navegador: situação, setor, tipo, busca em cargo+solicitante+setor | `components/Vagas/useVagas.ts` (`filtradas`) |
| V2 | **Ordena** (mais recentes/antigas/maior custo) e **pagina** no navegador | `useVagas.ts` |
| V3 | **Indicadores** (nº de solicitações, nº de vagas e custo por situação; pendentes há mais de 7 dias) somados no navegador | `useVagas.ts` (`resumo`), `helpers.ts` (`resumir`), `VagasLista.tsx` (`pendentesAntigas`) |
| V4 | `custo_total = quantidade × (salário + insalubridade + VR)` **calculado no navegador e enviado** no `POST/PUT` | `helpers.ts` (`calcularCustoTotal`), `acoes.ts` (`payloadDoForm`) |
| V5 | "Quem decide" = quem tem **exatamente** `pode_editar` + `pode_visualizar` (sem criar/deletar). Heurística de permissão no front | `VagaPainel.tsx`, `VagasLista.tsx` (`canOnly`) |
| V6 | A decisão é um `PUT` do **registro inteiro** trocando `situacao` e `observacao_situacao`. Quem tem `pode_editar` consegue alterar salário, quantidade etc. chamando a API direto | `acoes.ts` (`decidirSolicitacao`) |
| V7 | "Decidida em" usa `updated_at` (que muda em qualquer edição) porque não existe data de decisão | `VagaPainel.tsx` |
| V8 | O limite de 7 dias para "pendente há muito tempo" é constante do front | `helpers.ts` (`DIAS_PENDENTE_ATENCAO`) |

## 3. O que peço

### 3.1 Listagem com filtro, busca, ordenação e paginação

`GET /vagas` ganha:

| Parâmetro | Significado |
|---|---|
| `tipo_vaga` | `CLT`, `PJ`, `Estágio`, `Temporário`, `Terceirizado` |
| `q` | Busca sem acento/caixa em `cargo_vaga`, `solicitante` e nome do setor (OU) |
| `sort` / `order` | `data_solicitacao`, `custo_total`, `cargo_vaga`, `situacao`; padrão `data_solicitacao desc`. Para a fila de pendentes a tela pede `asc` (mais antigas primeiro) |

`total`/`totalPages` refletem os filtros. Resposta inclui `dias_pendente` (inteiro, só se pendente,
calculado pelo banco em America/Sao_Paulo) e `atencao boolean` (pendente há mais que o limite — ver 3.4).

### 3.2 `GET /vagas/resumo`

Mesmos filtros de 3.1 (menos `page/limit/sort`):

```json
{
  "pendente":  { "solicitacoes": 0, "vagas": 0, "custo_mensal": 0, "com_atencao": 0 },
  "aprovado":  { "solicitacoes": 0, "vagas": 0, "custo_mensal": 0 },
  "reprovado": { "solicitacoes": 0, "vagas": 0, "custo_mensal": 0 },
  "total": 0
}
```

Alimenta os quatro indicadores e os contadores das abas. `vagas` = soma de `quantidade`.

### 3.2.1 Custo calculado pelo banco

`custo_total` passa a ser **coluna gerada** (`quantidade * (coalesce(salario,0) + coalesce(insalubridade,0)
+ coalesce(vr,0))`). `POST/PUT` **ignoram** `custo_total` se vier no corpo. A tela deixa de enviá-lo e
só exibe uma prévia (o mesmo cálculo, apenas para feedback enquanto digita).

### 3.3.0 Regras de negócio (confirmadas pelo produto em 20/09/2026)

- **O RH cadastra** as solicitações (criar, editar, excluir) e **não decide**.
- **O diretor é o único que aprova ou reprova.** Ao decidir, pode escrever uma observação — **opcional**,
  nunca obrigatória. O diretor não cadastra nem edita os dados da vaga.
- A regra vale no **banco/backend**, não só na tela: hoje quem tem `pode_editar` consegue mudar `situacao`
  chamando `PUT /vagas/{id}` direto (a tela nova já não oferece esse campo ao RH).
- **Editar vaga já decidida — decidido em 25/09/2026: volta para `pendente`.** Ver §3.3.1.

### 3.3 Decisão como operação própria, com permissão própria

`POST /vagas/{id}/decisao` com `{ "situacao": "aprovado|reprovado|pendente", "observacao": "…" }`:

- exige a permissão **`pode_aprovar`** na tela `solicitacoes-de-vagas` (renomeada de `pode_decidir`
  — decisão de 24/09/2026: reaproveita a MESMA flag `pode_aprovar` já criada para Compras/B9, em vez
  de uma ação nova só para Vagas; a matriz de permissões ganha uma coluna, não duas). Quem tem só
  `pode_editar` **não** decide;
- só altera `situacao`, `observacao_situacao`, `decidido_por` (id do usuário autenticado) e
  `decidido_em` (timestamp gravado pelo banco) — nunca outros campos;
- registra histórico (`vagas_decisoes`: vaga, situação anterior/nova, observação, usuário, quando);
- regra opcional a decidir com o negócio: quem **registrou** a solicitação não pode decidi-la.

`PUT /vagas/{id}` passa a **rejeitar** mudança de `situacao`/`observacao_situacao` (ou ignorá-las).

### 3.3.1 Editar dados de uma vaga já decidida devolve para `pendente` (decisão de 25/09/2026)

Hoje (`develop`, `atualizarVaga` em `src/routes/vagas.js`), com `VAGAS_TRAVAS_DECISAO` ligada, `PUT/PATCH`
que altere algum dado de uma vaga `aprovado`/`reprovado` responde **409 `VAGA_DECIDIDA`**. Passa a ser:

- a alteração **é gravada**, e na mesma transação a vaga volta para `situacao = 'pendente'`, com
  `decidido_por` e `decidido_em` limpos (a `observacao_situacao` da decisão anterior fica no histórico, não
  na vaga);
- registra em `vagas_decisoes`: `situacao_anterior` = a decisão que caiu, `situacao_nova = 'pendente'`,
  `origem = 'edicao'`, `decidido_por` = quem editou (`updated_by`/usuário autenticado) e, em `observacao`,
  os campos alterados (ex.: "Dados alterados: salario, quantidade"). Uma linha só (sem a linha "legado" do
  gatilho de mudança de situação);
- reenviar o registro igual (a tela manda o formulário inteiro) continua não mudando nada: só volta para
  `pendente` se algum campo de dados mudou de fato (a comparação `mesmoValor` que já existe);
- `situacao`/`observacao_situacao` no corpo continuam proibidas (400 `SITUACAO_SO_PELA_DECISAO`);
- a resposta é a vaga já em `pendente` (a tela lê a situação dela e avisa o usuário).

**av-hub (feito, branch `fix/vagas-edicao-volta-pendente`):** o formulário de uma vaga decidida avisa que
salvar a devolve para pendente, o botão vira "Salvar e voltar para pendente" e, depois de salvar, a tela
mostra "voltou para pendente". O tratamento do 409 `VAGA_DECIDIDA` fica enquanto a API antiga estiver no ar.
`GET /vagas` devolve `decidido_por_nome` e `decidido_em`.

### 3.4 Parâmetros de negócio no banco

O limite de dias para "pendente com atenção" (hoje 7) vira configuração (`parametros_rh` ou
equivalente), lido pelo banco ao calcular `atencao`/`com_atencao`.

## 4. O que muda na tela quando isto chegar

- `useVagas.ts`: passa a chamar `GET /vagas?…` e `GET /vagas/resumo`; somem `filtradas`, o `sort`, o
  fatiamento e `resumir`.
- `acoes.ts`: `decidirSolicitacao` vira `POST /vagas/{id}/decisao`; `payloadDoForm` deixa de enviar
  `custo_total` e `situacao`.
- `VagaPainel.tsx`/`VagasLista.tsx`: `aprovador = can('pode_aprovar')`; some o `canOnly`.
- `helpers.ts`: some `DIAS_PENDENTE_ATENCAO`; `textoRelativo` fica só para exibir.

## 5. Aceite

- Um usuário com `pode_editar` sem `pode_aprovar` recebe `403` ao chamar `/decisao` e não consegue mudar
  `situacao` via `PUT`.
- Editar salário/quantidade de uma vaga aprovada a devolve para `pendente`, com uma linha `origem = 'edicao'`
  em `vagas_decisoes`.
- `custo_total` nunca diverge de `quantidade × (…)`, mesmo se o cliente mandar outro valor.
- `GET /vagas/resumo` bate com a contagem/soma das listagens filtradas.
- Toda decisão aparece em `vagas_decisoes` com quem e quando.
