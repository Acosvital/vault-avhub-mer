# Contrato — Solicitações de vagas: fila, decisão e permissões no banco

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
- **Pergunta em aberto para o negócio:** se o RH editar salário/quantidade de uma vaga **já decidida**, a
  decisão continua valendo ou a solicitação volta para `pendente`? Hoje a tela só avisa que a decisão não
  muda por ali; o banco precisa de uma regra (recomendação: voltar a `pendente` e registrar no histórico).

### 3.3 Decisão como operação própria, com permissão própria

`POST /vagas/{id}/decisao` com `{ "situacao": "aprovado|reprovado|pendente", "observacao": "…" }`:

- exige a permissão **`pode_decidir`** na tela `solicitacoes-de-vagas` (nova ação na matriz de
  permissões; hoje inferida por combinação de outras). Quem tem só `pode_editar` **não** decide;
- só altera `situacao`, `observacao_situacao`, `decidido_por` (id do usuário autenticado) e
  `decidido_em` (timestamp gravado pelo banco) — nunca outros campos;
- registra histórico (`vagas_decisoes`: vaga, situação anterior/nova, observação, usuário, quando);
- regra opcional a decidir com o negócio: quem **registrou** a solicitação não pode decidi-la.

`PUT /vagas/{id}` passa a **rejeitar** mudança de `situacao`/`observacao_situacao` (ou ignorá-las).
`GET /vagas` devolve `decidido_por_nome` e `decidido_em`.

### 3.4 Parâmetros de negócio no banco

O limite de dias para "pendente com atenção" (hoje 7) vira configuração (`parametros_rh` ou
equivalente), lido pelo banco ao calcular `atencao`/`com_atencao`.

## 4. O que muda na tela quando isto chegar

- `useVagas.ts`: passa a chamar `GET /vagas?…` e `GET /vagas/resumo`; somem `filtradas`, o `sort`, o
  fatiamento e `resumir`.
- `acoes.ts`: `decidirSolicitacao` vira `POST /vagas/{id}/decisao`; `payloadDoForm` deixa de enviar
  `custo_total` e `situacao`.
- `VagaPainel.tsx`/`VagasLista.tsx`: `aprovador = can('pode_decidir')`; some o `canOnly`.
- `helpers.ts`: some `DIAS_PENDENTE_ATENCAO`; `textoRelativo` fica só para exibir.

## 5. Aceite

- Um usuário com `pode_editar` sem `pode_decidir` recebe `403` ao chamar `/decisao` e não consegue mudar
  `situacao` via `PUT`.
- `custo_total` nunca diverge de `quantidade × (…)`, mesmo se o cliente mandar outro valor.
- `GET /vagas/resumo` bate com a contagem/soma das listagens filtradas.
- Toda decisão aparece em `vagas_decisoes` com quem e quando.
