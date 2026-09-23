# Contrato — Funcionários: filtro, busca, ordenação, paginação e resumo no servidor

**Criado em:** 20/09/2026, ao oficializar a tela nova de Funcionários (`components/Funcionarios/`).

**Princípio:** filtro, busca, ordenação, paginação e agregação são responsabilidade do **banco/API**.
A tela hoje faz tudo isso no navegador porque a API não entrega. Cada trecho que sai do lugar está
marcado no código com `GAMBIARRA(` — este contrato diz o que o backend precisa entregar para
apagarmos essas marcas.

## 1. O que a API entrega hoje

`GET /funcionarios` (o BFF só repassa estes parâmetros): `page`, `limit`, `nome_completo`, `email`,
`codigo_empresa`, `id_setor`, `id_cargo`. Não há ordenação, busca em mais de um campo, filtro de
contrato/situação/pendência, nem agregação. `GET /funcionarios/{id}` existe.

## 2. Onde a tela contorna (e por quê)

| # | Gambiarra hoje | Onde | Custo |
|---|---|---|---|
| F1 | Baixa **todos** os funcionários (201 hoje; em páginas de 500) e filtra no navegador: busca em nome+e-mail+cargo+setor, unidade, setor, cargo, contrato, situação, pendência | `components/Funcionarios/useFuncionarios.ts` (`filtrados`) | Payload cresce com o quadro; regra de negócio duplicada no front |
| F2 | **Ordena por nome** e **pagina** no navegador | mesmo arquivo | A API não ordena |
| F3 | **Indicadores** (ativos, desligados, cadastros completos, sem e-mail, distribuição por unidade) calculados no navegador | `useFuncionarios.ts` (`resumo`) | Só funciona porque baixa tudo |
| F4 | "Desligado" = `data_desligamento` <= hoje, decidido no front | `components/Funcionarios/helpers.ts` (`estaDesligado`) | A regra deveria ser uma coluna do banco |
| F5 | "Cadastro completo" = e-mail, telefone (fixo ou celular), data de admissão, tipo de contrato e foto — regra definida no front | `helpers.ts` (`PENDENCIAS`) | Idem: regra de negócio fora do banco |
| F6 | **Visão enxuta** (sem CPF/RG/CNPJ/endereço/auditoria) e **mascaramento** de documentos para quem só visualiza são feitos no BFF | `app/api/funcionarios/route.ts` (`visao=lista`), `app/api/funcionarios/[id]/route.ts` (`mascarar`) | Segurança de campo no lugar errado (ver `contrato-permissoes-e-escopo-no-banco`) |
| F7 | Listas encadeadas do formulário (setores da unidade, cargos do setor, candidatos a "reporta a" = colegas do setor) filtradas em memória a partir de listas completas | `FuncionarioPainel.tsx` | Menor, mas é filtro no cliente |

## 3. O que peço

### 3.1 `GET /funcionarios` com filtro, busca, ordenação e paginação de verdade

Parâmetros novos (todos opcionais, combináveis com os atuais):

| Parâmetro | Significado |
|---|---|
| `q` | Busca textual **sem acento e sem diferenciar maiúscula** em `nome_completo`, `email`, nome do cargo e nome do setor (OU entre os campos) |
| `contrato_tipo` | `CLT`, `PJ`… ou `nenhum` (sem contrato) |
| `situacao` | `ativo` \| `desligado` (regra no banco, ver 3.3) |
| `pendencia` | `qualquer` \| `sem_email` \| `sem_telefone` \| `sem_admissao` \| `sem_contrato` \| `sem_foto` |
| `sort` / `order` | Mesma convenção de `/vendedores` (`contrato-ordenacao-vendedores.md`, resolvido). Colunas: `nome_completo`, `data_admissao`, `cargo`, `setor`, `unidade` |
| `campos` | Lista de campos a devolver (`lista`, `completo`). `lista` = `id, nome_completo, id_cargo, id_setor, codigo_empresa, email, foto, contrato_tipo, data_admissao, data_desligamento, telefone, celular, situacao, pendencias`. O padrão passa a ser `lista`; `completo` só em `GET /funcionarios/{id}` |

`total`/`totalPages` devem refletir os filtros. Ordem padrão: `nome_completo asc`.

### 3.2 `GET /funcionarios/resumo`

Mesmos filtros de 3.1 (menos `page/limit/sort`), uma chamada só:

```json
{
  "total": 201,
  "ativos": 201, "desligados": 0,
  "cadastro_completo": 0, "cadastro_incompleto": 201,
  "por_pendencia": { "sem_email": 182, "sem_telefone": 0, "sem_admissao": 0, "sem_contrato": 0, "sem_foto": 0 },
  "por_unidade": [ { "codigo_empresa": "…", "ativos": 176 } ]
}
```

(Valores ilustrativos, exceto `sem_email`, que é o real de 09/2026.) O resumo é o que alimenta os quatro indicadores e a barra "Distribuição por unidade" — e deve
respeitar o **escopo de unidade do usuário** (mesma regra da listagem).

### 3.3 Regras no banco, não no front

Duas colunas derivadas (view/coluna gerada), devolvidas em toda listagem:

- `situacao`: `desligado` se `data_desligamento IS NOT NULL AND data_desligamento <= current_date`
  (fuso America/Sao_Paulo), senão `ativo`. Data futura = desligamento agendado, segue `ativo`.
- `pendencias text[]`: itens de cadastro faltando. Regra atual (mantida): `email` vazio; `telefone`
  **e** `celular` vazios; `data_admissao` nula; `contrato_tipo` nulo; `photo_url` vazio. Se o RH
  mudar o critério, muda no banco — a tela só exibe.

### 3.3.1 Campos sensíveis

`cpf`, `rg`, `cnpj`, `data_nascimento`, endereço e `created_by/updated_by` **não** entram na visão
`lista`. Em `GET /funcionarios/{id}`, CPF/RG/CNPJ vêm **mascarados** (`•••••••123`) para quem não tem
permissão de editar — decidido pelo backend a partir da identidade autenticada (ver contrato de
permissões), não pelo BFF.

## 4. O que muda na tela quando isto chegar

- `useFuncionarios.ts` deixa de baixar tudo: passa a chamar `GET /funcionarios?…` por página e
  `GET /funcionarios/resumo`; some `filtrados`, o `sort`, o fatiamento e o `resumo` local.
- `helpers.ts` perde `estaDesligado` e `PENDENCIAS.falta` (só rótulos e o mapa pendência → aba).
- `app/api/funcionarios/*` perde `visao=lista` e `mascarar` (viram repasse puro).
- `FuncionarioPainel.tsx` passa a pedir `GET /setores?codigo_empresa=`, `GET /cargos?id_setor=` e
  `GET /funcionarios?id_setor=&situacao=ativo` (isto já funciona hoje; só mudamos para usar).

## 5. Aceite

- Buscar "adriano" devolve só quem tem "adriano" em nome/e-mail/cargo/setor, sem trazer o resto.
- `sort=data_admissao&order=desc` ordena de fato, e a paginação respeita a ordenação.
- `GET /funcionarios/resumo` bate com a contagem da lista com os mesmos filtros.
- Uma listagem `campos=lista` nunca contém CPF/RG/CNPJ/endereço, mesmo com permissão total.
