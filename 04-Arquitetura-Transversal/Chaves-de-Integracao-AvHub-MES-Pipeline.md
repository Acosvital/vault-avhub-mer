---
tags: [erp-acos-vital, integracao, seguranca, chaves, av-hub, mes, pipeline]
criado: 2026-10-07
atualizado: 2026-10-07
---

# Chaves de integração — av-hub, MES e pipeline

> Status: no código (verificado em 07/10/2026); decisões em [[Registro-de-Decisoes-2026-10-07]] (itens 8 a 11).

> **Só nomes de variáveis, nunca valores.** Fontes: o PDF `docs/arquitetura/chaves-integracao-avhub-mes-pipeline.pdf` do repo do Hub (06/10, ainda não rastreado no git), conferido contra o código da `api-acos-vital` (`apiKeyAuth.js`, 0391b29 / #275) e do MES (`develop`). **Leitura de código; produção e banco não foram conferidos** — o próprio PDF ressalva que os valores por ambiente não foram checados. `[C]` = conferido no código, `[I]` = inferido.

Todas as chaves viajam no header `x-api-key`. O PDF organiza **uma chave por direção**.

## 1. As três chaves

| | O que faz | Variável no lado do **hub** (`api-acos-vital`) | Variável no lado do **consumidor** |
|---|---|---|---|
| **A** — MES → hub, só escrita | O MES envia a requisição de compra: `PUT /compras/requisicoes/origem/{id}` ([[34-Requisicoes-MES-Empurra-para-o-Hub]]). Mínimo **32 caracteres**. | `MES_INTEGRACAO_KEYS` | `api-pcp`: **`AVHUB_MES_INTEGRACAO_KEY`** (singular, `envio-avhub.service.ts:98`). O PDF e notas que citam `...KEYS` no lado do MES estão errados: o plural `MES_INTEGRACAO_KEYS` (lista) é a variável que a `api-acos-vital` lê (`apiKeyAuth.js:59`) 🟡 |
| **B** — MES lê / confirma | O MES lê eventos, pedidos e produtos e confirma a importação (ver tabela da seção 3). | `API_KEYS` (chave de ambiente = admin) | `api-pcp`: `API_KEY` (com `API_URL`) |
| **C** — pipeline | A pipeline lê a fila de OCs e devolve o resultado do envio ao Omie (`/compras/ordens/fila-omie`, `PATCH /compras/ordens/:id/sincronizacao`, `POST /:id/reenviar`; ver [[Omie-ELT-Pipeline]]). | `API_KEYS` (ou `auth.chaves_servico`) | pipeline: `AVHUB_API_KEY` |

B e C têm **acesso total (admin)** hoje. Para restringir, o DBA cadastra a chave em `auth.chaves_servico` (seção 4).

**Não confundir** com outras variáveis de chave que existem no ecossistema: `MES_API_KEY` (hub → MES, rotas dos contratos 003/005), `MES_INTERNAL_API_KEY` (BFF do app-pcp → `/auth/azure` do `api-pcp`), `DOCS_API_KEY` (pré-preenche a chave no `/docs` da API) e `COMERCIAL_API_KEY` (Hub ↔ `api-comercial`; **[I]** outra integração, ver [[AV-Hub-Comercial-Suprimentos]]).

## 2. Restrição real da chave A (o que o código faz)

`apiKeyAuth.js` tem **3 tipos** de chave `[C]`:

1. `API_KEYS` (ambiente) — **admin**.
2. `auth.chaves_servico` (banco) — nível **leitura / escrita / admin**, cache de **30 s**, **sem restrição por rota**.
3. `MES_INTEGRACAO_KEYS` — só abre o `PUT /compras/requisicoes/origem/{id}`.

Com a chave A, **qualquer outra rota responde 403 `CHAVE_MES_ROTA_NAO_PERMITIDA`**, até em GET.

## 3. Consequência: os GETs do MES exigem chave admin ou do banco (pendência L6)

| Rota que o MES chama | Chave A abre? |
|---|---|
| `PUT /compras/requisicoes/origem/{id}` (34) | **sim** — a única |
| `GET /pedidos_liberados` e `/:n/itens`, `POST /:n/importado` (26) | não — 403 |
| `GET /unidades`, `GET /produtos` | não — 403 |
| `GET /compras/requisicoes/eventos` (35) | não — 403 |

Logo, o MES lê com **chave admin ou do banco** (a chave B). Isso mantém **aberta a pendência L6** do contrato 26 ("chave do MES de escrita restrita por rota"), **ainda aberta no código** (0391b29, #275) e **🔴 pendente com o Gustavo**: chave restrita para MES e pipeline ou continuar com a chave admin? O MES precisa de escrita (`POST /pedidos_liberados/:n/importado`) e o pipeline também (`PATCH /compras/ordens/:id/sincronizacao`) — [[Registro-de-Decisoes-2026-10-07]], item 10. A restrição que existe só vale para a chave do PUT, não existe chave **de leitura+confirmação restrita às rotas do MES**. As notas dos contratos 004, 005 e 26 diziam "chave do MES restrita às rotas que o MES usa" como se isso viesse da chave do 34 — **não vem**. Ver [[26-Vendas-Liberacao-Pedido]] e [[35-Compras-Marcos-Requisicao-para-MES]].

Do lado do MES `[C]`: o envio do 34 usa `AVHUB_MES_INTEGRACAO_KEY`; sem a chave a fila de envio **espera com aviso no log**. A leitura de eventos do 35 usa `API_KEY`. **(conferido em 08/10)** Intervalos do MES: o envio roda a cada `AVHUB_ENVIO_INTERVALO_SEG` (padrão 60 s) e a leitura de eventos a cada `AVHUB_EVENTOS_INTERVALO_MIN` (padrão 5 min); ambos usam `API_URL` (padrão `https://api.acosvital.com.br`). **Se as variáveis têm valor no ambiente real: não verificado.**

## 4. `auth.chaves_servico` — como restringir B e C

- Tabela no banco, lida pela API com **cache de 30 s** (um cadastro ou revogação leva até ~30 s para valer).
- Cada chave tem nível `leitura`, `escrita` ou `admin`; **não há restrição por rota**. Erros: `CHAVE_SOMENTE_LEITURA` (escrita com chave de leitura) e `CHAVE_SEM_ACESSO_ADMINISTRATIVO`.
- **[I]** B e C precisam gravar (confirmar importação, devolver o resultado do envio ao Omie), então o menor nível útil seria `escrita`, não `leitura` — **não verificado**; confirmar com o DBA antes de trocar uma chave admin.
- O cadastro é feito pelo **DBA** (não há tela no Hub citada nas fichas).

## 5. Rotação

- O PDF traz o procedimento de rotação e as credenciais da pipeline; **os passos não foram transcritos para esta nota** — seguir o PDF.
- **[I]** `API_KEYS` e `MES_INTEGRACAO_KEYS` estão no plural, o que sugere lista separada por vírgula e permitiria sobrepor a chave nova e a antiga durante a troca. **Não verificado no código.**
- A chave A tem mínimo de 32 caracteres; uma chave nova mais curta não deve ser aceita.
- Ao trocar uma chave, trocar **nos dois lados** (hub e consumidor) — os nomes estão na tabela da seção 1.

## Pendências

| Pendência | Origem |
|---|---|
| L6: restringir B (e C) às rotas de cada integração; hoje só a chave A é restrita | contrato 26, aberto em 0391b29 |
| ~~Alinhar `AVHUB_MES_INTEGRACAO_KEYS` (PDF) × `AVHUB_MES_INTEGRACAO_KEY` (código do MES)~~ — resolvido 🟡: `api-pcp` usa `AVHUB_MES_INTEGRACAO_KEY` (singular); a `api-acos-vital` lê `MES_INTEGRACAO_KEYS` (plural). Corrigir o PDF | PDF × código |
| Conferir o valor das variáveis nos ambientes reais | ressalva do PDF; não verificado |

## 6. Chaves do contrato 38 (Registro, itens 8 e 9)

| Chave | Decisão | Status |
|---|---|---|
| `PERMISSOES_ROTA_MODO` | Deixa de ser "variável a conferir": fica **fixa em `exigir`** no código, sem `.env`. Chamadas de serviço (só `x-api-key`, sem `Bearer`) passam sem mapeamento, pois o modo só confere permissão quando há token. Alteração de código: Gustavo | ✅ |
| `ESCOPO_VENDEDORES_EXIGIR` | Fixar no código (front do av-hub manda token em todas as chamadas, ✅ Nathan) | 🟡 (Gustavo) |
| `IDENTIDADE_EXIGIR_TOKEN` | Segue como chave: quebra MES e pipeline enquanto usarem a chave do `.env` sem token | 🟡 (Gustavo) |
| `ESCOPO_UNIDADE_EXIGIR_SESSAO` | Segue como chave, pelo mesmo motivo | 🟡 (Gustavo) |
| `AUTENTICACAO_AZURE_VALIDAR_ID_TOKEN` | Segue como chave, pelo mesmo motivo | 🟡 (Gustavo) |
| `VENDAS_PLANILHA_PAGINAR_POR_PEDIDO` | Segue como chave: fixar cortaria dados no front | 🟡 (Gustavo) |

As quatro que seguem como chave só podem ser fixadas depois de separar as chaves de serviço. Ver [[38-Regras-Sem-Chave-de-Ambiente]].

## Ver também
- [[AV-Hub-API-Estado-Atual]]
- [[34-Requisicoes-MES-Empurra-para-o-Hub]]
- [[35-Compras-Marcos-Requisicao-para-MES]]
- [[26-Vendas-Liberacao-Pedido]]
- [[38-Regras-Sem-Chave-de-Ambiente]]
- [[Integracao-AvHub-MES-Especificacao-F1]]
- [[Omie-ELT-Pipeline]]
- [[Indice-Contratos]]
- [[Onde-Estamos]]
