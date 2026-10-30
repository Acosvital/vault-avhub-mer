---
id: API-012
aliases: ["Contrato 012", "012-Produtos-Provaveis-Duplicatas"]
tags: [contrato, contrato-api, produtos, duplicatas, catalogo, av-hub, leitura, sql]
criado: 2026-10-19
atualizado: 2026-10-29
status: implementado-no-codigo
sistemas: [hub-banco, hub-api, hub-front]
dono: "Gustavo"
etapa_0b: []
fontes: ["av-hub/services/cadastros/auxiliares/produtosDuplicados.ts:21-122", "av-hub/app/(protected)/cadastros/auxiliares/produtos-duplicados/page.tsx", "av-hub/app/api/produtos/route.ts (padrão do BFF)", "api-acos-vital src/schemas/core/tables/produtos/produtos.route.js:5-9, :44-60 (list), :83-140 (/:id/fornecedores)", "Dump Avhub (Esqueleto).sql:11648-11666 (core.produtos)", "Decisão do Nathan de 19/10/2026"]
criado_original: 2026-10-19
---

# Contrato de API 012 — Produtos: prováveis duplicatas (rota `GET /produtos/duplicatas` e nova tela)

> **Onde atua:** av-hub: banco, API, front

> [!info] Situação em 21/10/2026
> **Status:** `implementado-no-codigo` · **Pasta:** `Entregues` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Gustavo (banco e API); Nathan (front)
>
> - 🕓 **Antes da entrega (19/10/2026)** a tela só lia, calculava no navegador (descrição normalizada igual + família + unidade) e a `api-acos-vital` não tinha rota de duplicatas. Superado pelos itens abaixo.
> - ✅ **Tela atual** (`/cadastros/auxiliares/produtos-duplicados`): só leitura e sem alias; o botão "Vincular como alias" não existe mais no `page.tsx` (conferido em 29/10/2026). A rota `GET /produtos/duplicatas` está em `produtos.route.js:164`, registrada antes de `/:id` (`:317`).
> - 📝 **Decisão do Nathan, 19/10/2026:** cálculo no banco e na API; **só leitura, sem alias** (mantém a rejeição de 21/09/2026, [[API-002-Material-Alias-Omie-MES]]); **por unidade**; mostrar uso em venda, OC, estoque e fornecedores.
> - ✅ **Rota na `develop` da `api-acos-vital`** (commit `c685571`, 21/10/2026): `GET /produtos/duplicatas` registrada antes de `/:id`, com escopo de unidade (403), 404 para unidade inexistente, cache de 60 s dos pares, swagger e testes unitários (`test/unit/produtosDuplicatas.test.js`). Devolve também `motivo_sugestao` no item sugerido (`unico_ativo`, `mais_usado`, `maior_estoque`, `mais_antigo`, `menor_id`), além do contrato.
> - ✅ **Tela no `av-hub`** (`develop`, PR #223): consome a rota por BFF `GET /api/produtos/duplicatas`, com uma chamada só. Testado em 21/10/2026 contra a API real: 200 nas 3 unidades (Aços Vital 7.079 grupos em 53.515 produtos), 0,9 a 9,6 s sem cache e cerca de 0,45 s com cache.
> - ✅ **Front limpo em 30/10/2026 (Nathan, testado):** o fallback de dados de exemplo, `produtosDuplicadosMock.ts`, o aviso na tela e a marca `GAMBIARRA` saíram, e o motivo da sugestão vem da API (`motivo_sugestao`). Antes: **Ainda no front:** o fallback de dados de exemplo (`produtosDuplicadosMock.ts` e o tratamento de 404/400 em `produtosDuplicados.ts`) segue no código; remover. A tela calcula o texto do motivo da sugestão; trocar por `motivo_sugestao` da API.
> - 🟡 **Qualidade da nota, a melhorar** (ver [[SQL-013-Produtos-Provaveis-Duplicatas-Funcoes-e-Uso]]): medidas em ordem, variações por unidade, grupos em corrente e faixa `alta`.
> - 📝 **Em modelagem (21/10/2026, experimental):** curadoria dos grupos (tirar, incluir, confirmar, salvar, nome do grupo e referência nos pedidos). Mudaria a decisão de "só leitura" e é assunto de contrato novo, ainda não escrito.
> - **MES (Robert): sem trabalho.** Este contrato não toca o MES nem o `api-pcp`.
>
> Selos em [[Regras-do-Vault]].

> [!abstract] Resumo em linguagem natural
> **O que é:** Moveu para o banco e a API o cálculo de produtos que provavelmente são duplicados, em modo só leitura, por unidade, mostrando uso em venda, compra e estoque.
> **Quem é afetado:** Quem cuida do cadastro de produtos usa a tela nova de duplicatas; Gustavo (DBA) fez rota e banco, Nathan fez a tela.
> **Situação:** ✅ Rota e tela entregues em 21/10/2026, testadas na API real. ✅ Os dados de exemplo saíram em 30/10/2026. 🟡 Falta melhorar a nota. 📝 Curadoria dos grupos segue em modelagem, sem contrato.

## Por quê

A tela hoje perde duplicatas com nome escrito de outro jeito, com família errada ou com código parecido, não diz **quão** provável é cada uma e não mostra o uso do produto, então quem decide não sabe qual cadastro manter nem se vale a pena mexer. Este contrato entrega: uma rota única que devolve grupos já calculados, com nota, motivos e uso; e a tela nova que os mostra. Quem **resolve** a duplicata continua sendo o Omie.

## 1. Rota nova: `GET /produtos/duplicatas`

No `api-acos-vital`, no router de `core/tables/produtos`.

- 🔴 **Registrar antes de `/:id`** em `produtos.route.js`, senão `duplicatas` vira um `id` e responde 400 (`id deve ser um uuid`) ou 404.
- Mesma proteção do `GET /produtos` (API Key do hub e escopo de unidade pelo token, [[LOG-40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]] e [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]]). 🟡 O Gustavo confirma que `codigo_empresa` de fora da unidade do usuário responde 403, como as demais rotas.
- Só leitura: nenhuma escrita em lugar nenhum.

### Parâmetros (query)

| Parâmetro | Tipo | Padrão | Regra |
|---|---|---|---|
| `codigo_empresa` | uuid | — | **Obrigatório.** Ausente ou inválido: `400 { detail: "codigo_empresa é obrigatório (uuid)" }` |
| `limiar` | inteiro | `70` | 50 a 100; fora da faixa: `400`. Nota mínima do par para entrar |
| `somente_ativos` | booleano | `true` | `false` inclui produtos inativos nos pares |
| `confianca` | `alta` \| `media` \| `baixa` | todas | Filtra os grupos pela confiança (faixas da seção 3) |
| `familia` | texto | — | Mantém grupos em que **algum** item tem esta `familias_produtos` |
| `q` | texto | — | Mantém grupos em que algum item tem o texto no código ou na descrição (`ILIKE`, sem acento) |
| `ordenar` | `confianca` \| `tamanho` \| `uso` \| `nome` | `confianca` | `confianca` = nota máxima do grupo desc; `tamanho` = nº de itens desc; `uso` = uso total desc; `nome` = descrição do item sugerido asc. Empate: `id_grupo` asc |
| `page` | inteiro ≥ 1 | `1` | Paginação **por grupo** |
| `limit` | inteiro 1 a 100 | `20` | Grupos por página |

Parâmetro desconhecido é ignorado. Valor inválido: `400 { detail }` com o nome do parâmetro.

### Como a API monta a resposta

1. Chama `core.fn_produtos_duplicatas_pares(codigo_empresa, limiar, somente_ativos)` ([[SQL-013-Produtos-Provaveis-Duplicatas-Funcoes-e-Uso]], seção 3).
2. Junta os pares em **grupos** (componentes conexos; um produto em A~B e B~C forma um grupo A, B, C).
3. Calcula, por grupo: `nota_max` (maior nota de par), `nota_min` (menor nota de par que existe no grupo) e `coesao` = pares existentes ÷ pares possíveis (`n(n−1)/2`), de 0 a 1.
4. Aplica os filtros `confianca`, `familia` e `q`, ordena e pagina os grupos.
5. Só para os produtos da **página pedida**, busca os cadastros em `core.produtos` e o uso em `core.fn_produtos_uso(codigo_empresa, ids)` (seção 4 do SQL).
6. Marca o item `sugerido_manter` e calcula as `diferencas` do grupo (seção 4).

Cache: 🟡 a API guarda os **pares** por `(codigo_empresa, limiar, somente_ativos)` por **60 s** em memória, para a paginação e a troca de filtro não recalcularem. Sem cache distribuído, sem tabela. Parâmetro `atualizar=true` ignora o cache.

### Resposta `200`

```json
{
  "grupos": [
    {
      "id_grupo": "0199f3a2-7c1e-7b52-9d10-3f6b2a1c8e44",
      "confianca": "alta",
      "nota_max": 96,
      "nota_min": 91,
      "coesao": 1,
      "grupo_grande": false,
      "motivos": ["nome_quase_igual", "codigo_igual_sem_zeros", "mesmo_ncm", "familia_diferente"],
      "diferencas": ["familia", "unidade_medida"],
      "itens": [
        {
          "id": "0199f3a2-7c1e-7b52-9d10-3f6b2a1c8e44",
          "codigo_produto": "FLG-0304-2",
          "codigo_produto_omie": "4821733015",
          "descricao": "FLANGE ACO INOX 304 2\"",
          "familias_produtos": "FLANGES",
          "familia_nome": "Flanges",
          "unidade_medida": "UN",
          "ncm": "73079100",
          "ativo": true,
          "created_at": "2024-03-11T14:02:09.000Z",
          "updated_at": "2026-08-02T10:15:44.000Z",
          "sugerido_manter": true,
          "uso": {
            "vendas": { "itens": 42, "quantidade": 318, "valor_total": 18420.5, "ultima_data": "2026-09-30" },
            "oc": { "itens": 7, "quantidade": 120, "ultima_data": "2026-09-12" },
            "pedidos_compra_omie": { "itens": 9 },
            "requisicoes": 3,
            "estoque": { "saldo": 36, "fisico": 40, "reservado": 4, "data_posicao": "2026-10-18" },
            "fornecedores": {
              "quantidade": 3,
              "ultima_cotacao": { "valor": 189.9, "data": "2026-09-05" },
              "principais": [
                { "codigo_parceiro_omie": "5512", "nome_fantasia": "Aços Norte", "ultimo_valor": 189.9, "ultima_data": "2026-09-05" }
              ]
            },
            "pontos_uso": 61
          }
        },
        {
          "id": "0199f3a9-0b11-7d3e-a0c4-91e7d5b3f210",
          "codigo_produto": "FLG0304-2",
          "codigo_produto_omie": "5530119872",
          "descricao": "Flange aço inox 304 2 pol",
          "familias_produtos": "OUTROS",
          "familia_nome": "Outros",
          "unidade_medida": "PC",
          "ncm": "73079100",
          "ativo": true,
          "created_at": "2025-11-20T09:31:00.000Z",
          "updated_at": "2025-11-20T09:31:00.000Z",
          "sugerido_manter": false,
          "uso": {
            "vendas": { "itens": 0, "quantidade": 0, "valor_total": 0, "ultima_data": null },
            "oc": { "itens": 1, "quantidade": 10, "ultima_data": "2025-12-03" },
            "pedidos_compra_omie": { "itens": 0 },
            "requisicoes": 0,
            "estoque": { "saldo": 0, "fisico": 0, "reservado": 0, "data_posicao": null },
            "fornecedores": { "quantidade": 1, "ultima_cotacao": { "valor": 205, "data": "2025-12-01" }, "principais": [] },
            "pontos_uso": 1
          }
        }
      ],
      "pares": [
        {
          "id_a": "0199f3a2-7c1e-7b52-9d10-3f6b2a1c8e44",
          "id_b": "0199f3a9-0b11-7d3e-a0c4-91e7d5b3f210",
          "nota": 91,
          "nota_nome": 97,
          "nota_codigo": 90,
          "motivos": ["nome_quase_igual", "codigo_igual_sem_zeros", "mesmo_ncm", "unidade_diferente", "familia_diferente"]
        }
      ]
    }
  ],
  "total": 148,
  "page": 1,
  "limit": 20,
  "totalPages": 8,
  "resumo": {
    "produtos_analisados": 35412,
    "grupos": 148,
    "produtos_em_grupos": 331,
    "por_confianca": { "alta": 61, "media": 57, "baixa": 30 }
  },
  "parametros": { "codigo_empresa": "uuid-da-unidade", "limiar": 70, "somente_ativos": true },
  "gerado_em": "2026-10-19T13:20:41.000Z"
}
```

> Os números acima são ilustrativos (🟡). O formato segue o padrão de lista paginada da API (`page`, `limit`, `total`, `totalPages`, como `GET /produtos`), com a chave `grupos`.

### Campos

| Campo | Tipo | Regra |
|---|---|---|
| `id_grupo` | uuid | O menor `id` de produto do grupo; estável enquanto o grupo tiver os mesmos produtos |
| `confianca` | `alta` \| `media` \| `baixa` | pela `nota_max` (seção 3) |
| `nota_max`, `nota_min` | inteiro 0 a 100 | maior e menor nota entre os pares do grupo |
| `coesao` | número 0 a 1 | 1 = todo produto é par de todos os outros; perto de 0 = grupo "em corrente" (A~B, B~C, A≁C), pede conferência |
| `grupo_grande` | booleano | `true` com mais de 10 itens (provável corrente; a tela avisa) |
| `motivos` | `string[]` | união dos motivos dos pares do grupo, sem repetição |
| `diferencas` | `string[]` | campos em que os itens divergem, entre `familia`, `unidade_medida`, `ncm`, `ativo` |
| `itens[].familia_nome` | texto, nulo | `core.familia_produtos.nome` da `(codigo_empresa, familias_produtos)` |
| `itens[].uso.*` | objeto | direto de `fn_produtos_uso`; blocos sem dado vêm com `0`/`null`, nunca omitidos |
| `itens[].uso.fornecedores.principais` | lista (até 5) | `codigo_parceiro_omie`, `nome_fantasia`, `ultimo_valor`, `ultima_data` |
| `itens[].uso.pontos_uso` | inteiro | `vendas.itens + oc.itens + pedidos_compra_omie.itens + requisicoes`; só ordena e ajuda a sugerir |
| `itens[].sugerido_manter` | booleano | exatamente um item por grupo; **sugestão, não decisão** (regra abaixo) |
| `pares[]` | lista | pares com nota ≥ `limiar`, para explicar o grupo |

Números (`numeric`) saem como **número** JSON, não texto (padrão do `/:id/fornecedores`, `numeroOuNull`). Datas como `YYYY-MM-DD` (só data) ou ISO 8601 (data e hora).

### Códigos de `motivos`

| Código | Significado |
|---|---|
| `nome_quase_igual` | semelhança de nome ≥ 90% |
| `nome_parecido` | semelhança de nome entre 45% e 90% |
| `codigo_igual_normalizado` | código igual depois de tirar traço, ponto, espaço e caixa |
| `codigo_igual_sem_zeros` | igual também sem zeros à esquerda (`PAR-0012` × `PAR12`) |
| `codigo_parecido` | código parecido (trigramas ≥ 0,6) |
| `mesmo_ncm` | NCM igual e preenchido |
| `mesma_unidade` / `unidade_diferente` | unidade de medida igual / diferente |
| `mesma_familia` / `familia_diferente` | família igual / diferente |
| `numeros_diferentes` | números do nome diferem (304 × 316, 2" × 3"); a nota cai 40 pontos |

## 2. Regra do `sugerido_manter`

Para cada grupo, ordenar os itens por: (1) `ativo` = `true`; (2) maior `pontos_uso`; (3) maior `estoque.saldo`; (4) `created_at` mais antigo; (5) `id` asc. O primeiro é `sugerido_manter = true`; os demais, `false`. **É só uma sugestão** para quem vai resolver no Omie: a tela mostra o motivo ("mais usado", "mais antigo").

## 3. Faixas de confiança

| Faixa | `nota_max` |
|---|---|
| `alta` | ≥ 90 |
| `media` | 75 a 89 |
| `baixa` | < 75 |

## 4. Erros

| Status | Quando | Corpo |
|---|---|---|
| 400 | `codigo_empresa` ausente ou inválido; `limiar` fora de 50 a 100; `limit` fora de 1 a 100; `ordenar`/`confianca` inválidos | `{ "detail": "..." }` |
| 401/403 | sem API Key; unidade fora do escopo do usuário | como as demais rotas |
| 404 | `codigo_empresa` não existe em `core.unidades` | `{ "detail": "Unidade não encontrada" }` |
| 500 | falha no banco | `{ "detail": "..." }` |

Unidade sem nenhuma duplicata: `200` com `grupos: []`, `total: 0` e o `resumo` preenchido.

## 5. BFF e tela (Nathan)

### BFF

`av-hub/app/api/produtos/duplicatas/route.ts`, mesmo padrão de `app/api/produtos/route.ts`: `requirePermission('produtos', 'pode_visualizar')`, repassa só os parâmetros da tabela da seção 1 (lista fixa), `headersComIdentidade()`, `cache: 'no-store'`. 🟡 A permissão fica em `produtos`/`pode_visualizar` (a página já está em Cadastros → Auxiliares); se o Nathan preferir tela própria, vira migration de permissão.

### Serviço

`services/cadastros/auxiliares/produtosDuplicados.ts` deixa de baixar o catálogo: `buscarGruposDuplicados(params)` faz **uma** chamada a `/api/produtos/duplicatas` e devolve a resposta. Somem `MAX_PAGINAS`, `CONCORRENCIA`, `TAMANHO_PAGINA`, `normalizarDescricao` (e o aviso de "catálogo maior que o teto"). O tipo `GrupoDuplicata` passa a refletir a resposta da seção 1.

### Tela (padrão de [[Regras-do-Vault|interface-hub]], skill `av-hub:interface-hub`)

| Bloco | Conteúdo |
|---|---|
| Cabeçalho | título "Produtos — Prováveis Duplicatas"; seletor de **Unidade** (como hoje); aviso curto: relatório de leitura, a correção é feita no Omie |
| KPIs | produtos analisados · grupos · produtos em grupos · grupos de confiança alta |
| Filtros | confiança (alta/média/baixa), família, só ativos, busca (código ou descrição), sensibilidade (limiar 60/70/80/90), ordenar por |
| Lista de grupos | card por grupo com selo de confiança (cores de status do padrão), nota, nº de itens, chips dos **motivos** em português e aviso de `grupo_grande`/`coesao` baixa |
| Tabela do grupo | uma linha por item: código, código Omie, descrição, família, unidade, NCM, status, criado em, **vendas** (itens, última), **OC** (itens, última), **estoque** (saldo), **fornecedores** (qtd, último preço), marca "Sugerido manter" |
| Diferenças | no grupo, as células que **divergem** entre itens (família, unidade, NCM) ficam destacadas |
| Detalhe do item | expansão da linha com a lista dos fornecedores e as datas de cadastro e alteração |
| Paginação | por grupo (20 por página) |
| Exportar | CSV dos grupos filtrados (cliente, a partir dos grupos já carregados) |
| Vazios e erros | "Nenhuma duplicata provável nesta unidade com este limiar"; erro com `notify.error` |

**Sai da tela:** o botão desabilitado "Vincular como alias" e o texto que fala em contrato com o MES/Estoque (a ideia foi rejeitada).

## Fora deste contrato

- **Alias, mesclagem ou inativação em lote** de duplicatas no sistema: rejeitado (21/09/2026).
- **"Marcar como não é duplicata"** (esconder o grupo): exigiria tabela de decisões e escrita. 🟡 **Pergunta ao Nathan**: vale pagar esse custo? Sem isso, falsos positivos reaparecem a cada abertura; o filtro por confiança e o limiar reduzem o ruído.
- **Cruzar unidades** (Vital × Uberaba): os catálogos numeram de forma independente; fica por unidade.
- **Notificação ou rotina agendada** de duplicatas novas.

## Checklist

**Gustavo (banco e API)**
- [ ] Aplicar e validar o [[SQL-013-Produtos-Provaveis-Duplicatas-Funcoes-e-Uso]] (checklist dele), incluindo o tempo na unidade maior.
- [ ] Implementar a rota `GET /produtos/duplicatas` antes de `/:id`; validar parâmetros; juntar pares em grupos; `coesao`, `grupo_grande`, `sugerido_manter`, `diferencas`.
- [ ] Cache de 60 s dos pares por `(codigo_empresa, limiar, somente_ativos)`.
- [ ] Swagger da rota (`produtos.swagger.json`) com o corpo da seção 1.
- [ ] Escopo de unidade: `codigo_empresa` fora do escopo do usuário responde 403.

**Nathan (front)**
- [ ] BFF `app/api/produtos/duplicatas/route.ts`.
- [ ] Serviço sem varredura do catálogo; tipos novos.
- [ ] Tela nova conforme a seção 5, no padrão `interface-hub`.

**Robert (MES):** nada.

## Aceite

1. `GET /produtos/duplicatas?codigo_empresa=<uuid>` na unidade maior responde em **até 8 s** (primeira chamada, sem cache) e em até 1 s dentro de 60 s.
2. "FLANGE AÇO INOX 304 2\"" e "Flange aco inox 304 2 pol" aparecem no mesmo grupo, mesmo com família e unidade diferentes, com `familia_diferente` e `unidade_diferente` nos motivos.
3. Dois produtos que só diferem em `304` × `316` **não** aparecem no mesmo grupo no limiar 70.
4. Cada item traz `uso` com todos os blocos (vendas, OC, pedidos Omie, requisições, estoque, fornecedores); um produto sem uso vem com zeros e `null`, não com o bloco faltando.
5. Em todo grupo, **exatamente um** item tem `sugerido_manter = true`.
6. `codigo_empresa` ausente responde 400; de outra unidade fora do escopo do usuário, 403; `GET /produtos/<uuid>` continua funcionando (a rota nova não o captura).
7. A tela não faz mais que **uma** chamada a `/api/produtos/duplicatas` por consulta (sem varrer `/api/produtos`).
8. Nenhuma tabela foi escrita por esta funcionalidade.

## Ver também
[[SQL-013-Produtos-Provaveis-Duplicatas-Funcoes-e-Uso]] · [[API-002-Material-Alias-Omie-MES]] · [[API-001-Produtos-Parceiros-Filtro-Incremental|001-Produtos-Parceiros-Filtro-Incremental]] · [[LOG-36-Compras-Produto-Obrigatorio-e-Comprador-da-OC]] · [[Produtos-e-Familias]]
