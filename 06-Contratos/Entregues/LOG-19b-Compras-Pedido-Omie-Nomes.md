---
id: LOG-19b
aliases: ["Contrato 19 (Nomes)", "Contrato 27", "19-Compras-Pedido-Omie-Nomes", "Contrato 27 (numeração antiga)"]
tags: [contrato, contrato-logica, contrato-api, compras]
criado: 2026-10-14
atualizado: 2026-10-14
status: implementado-no-codigo
sistemas: [hub-api]
dono: "Gustavo (DBA)"
etapa_0b: [C4]
fontes: ["api-acos-vital/src/schemas/core_vendas_faturamento/tables/pedidos_compras"]
criado_original: 2026-09-28
---

# Contrato 27 — Compras: nomes no detalhe do pedido de compra do Omie

> **Onde atua:** av-hub: API

> [!abstract] Resumo em linguagem natural
> **O que é:** Fez o detalhe do pedido de compra vindo do Omie devolver nomes (fornecedor, comprador, categoria etc.) em vez de só códigos. Pedido só de API, sem SQL novo.
> **Quem é afetado:** Quem abre, na lista de Ordens de compra, um pedido feito direto no Omie: passa a ver o nome do fornecedor, não o código.
> **Situação:** ✅ API entregue e conferida na `api-test` em 29/09. No teste, comprador e descrições de catálogo vieram nulos porque esses cadastros estavam vazios. Front no av-hub#106.

> [!info] Situação em 14/10/2026
> **Status:** `implementado-no-codigo` · **Pasta:** `Entregues` · **Nós do 0b:** C4 · **Dono:** Gustavo (DBA)
>
> - ✅ API `163b58b` entrega os nomes no detalhe do pedido de compra do Omie (conferido na `api-test` em 29/09, vault v1).
> - Alias: o título do texto diz "Contrato 27"; no vault novo é LOG-19b (versão "Nomes" do 19).
>
> Conferido em 14/10/2026 contra `api-pcp` 579a625, `app-pcp` 1fca8d3, `api-acos-vital` f322dcd, `omie-elt-pipeline` 0f739f0 e os dumps de 14/10. O front do av-hub (HUB b55ac55) só pelo vault v1 (❓).
> O texto original abaixo está inteiro; os trechos que o estado atual contradiz têm nota de rodapé.


> **Concluído — movido para `Realizados/`[^c1] em 29/09/2026** (era o contrato 27). Backend na `api-test` e front mergeado na `develop` do av-hub ([av-hub#106](https://github.com/Acosvital/av-hub/pull/106)).

> **Conferido em 29/09/2026: backend entregue** (API `163b58b`). Testado na `api-test` com um pedido de
> teste no espelho (fornecedor GERDAU, Mogi, depois apagado): `nome_fornecedor`, `razao_social_fornecedor`,
> `cpf_cnpj_fornecedor` e `etapa_descricao` ("Incluído") vieram certos; comprador e descrições dos
> catálogos vieram `null` porque esses cadastros estão vazios no teste. **Front** em
> [av-hub#106](https://github.com/Acosvital/av-hub/pull/106) (detalhe do pedido do Omie com os nomes),
> aguardando merge; depois do merge vai para `Realizados/`. No mesmo teste, a listagem unificada do
> [[LOG-15-Compras-Historico-Unificado|15-Compras-Historico-Unificado]] mostrou a linha do Omie e o KPI "0 no av-hub · 1 no Omie".

**Criado em:** 28/09/2026 · **Para:** backend (`api-acos-vital`) · **Só API, sem SQL novo**

Complementa o [[LOG-15-Compras-Historico-Unificado|15-Compras-Historico-Unificado]].

---

## 1. Por quê

A listagem de Ordens de compra passou a mostrar também os pedidos feitos direto no Omie
(contrato 25). Nessas linhas o backend já resolve o fornecedor: `GET /compras/ordens?origem=omie`
devolve `nome_fornecedor`, `cpf_cnpj_fornecedor` e `nome_comprador`.

Ao abrir a linha, o av-hub chama `GET /pedidos_compras/{id}`. Esse detalhe devolve só os
**códigos do Omie**: `codigo_fornecedor` (nCodFor), `codigo_comprador`, `codigo_transportadora`,
`codigo_categoria`, `codigo_conta_corrente`, `codigo_projeto`, `codigo_condicao_pagamento` e
`etapa` ("15"). A tela do pedido mostra "Fornecedor (código Omie): 10363934283", sem o nome de
ninguém.

**A tela não vai montar esses nomes sozinha.** Seriam 5 ou 6 chamadas a mais por pedido (parceiros,
compradores, catálogos), com o JOIN pela unidade feito no navegador. É o mesmo JOIN que o backend
já faz para as OCs do av-hub (`ATRIBUTOS_NOMES` em `src/routes/compras_ordens.js`, B5 do
[[LOG-13a-Compras-Backend-Consolidado|13-Compras-Backend-Consolidado]]).

## 2. O contrato

`GET /pedidos_compras/{id}` passa a devolver, **além** do que já devolve (mudança aditiva), os
campos abaixo. A regra é a mesma de B5: o JOIN usa sempre o **`codigo_empresa` do pedido**, porque o
mesmo fornecedor tem um código diferente em cada conta Omie. Um código que não estiver no cadastro
da unidade devolve `null`, e a tela mostra o código.

| Campo novo | Origem (sempre pela `codigo_empresa` do pedido) |
|---|---|
| `nome_fornecedor` | `core.parceiros.nome_fantasia` onde `codigo_parceiro_omie = codigo_fornecedor` |
| `razao_social_fornecedor` | `core.parceiros.razao_social` (mesmo parceiro) |
| `cpf_cnpj_fornecedor` | `core.parceiros.cpf_cnpj` (mesmo parceiro) |
| `nome_transportadora` | `core.parceiros.nome_fantasia` pelo `codigo_transportadora` |
| `nome_comprador` | `compradores`: `COALESCE(nome_exibicao, nome)` onde `codigo_comprador_omie = codigo_comprador` |
| `etapa_descricao` | `pedidos_compras_etapas`: o mesmo texto que a listagem devolve em `etapa_omie_descricao` |
| `descricao_condicao_pagamento` | `condicoes_pagamento_compras.descricao` onde `codigo_omie = codigo_condicao_pagamento` |
| `descricao_categoria` | `core.categorias.descricao` pelo `codigo_categoria` |
| `descricao_conta_corrente` | `core.contas_correntes.descricao` onde `codigo_conta_omie = codigo_conta_corrente` |
| `nome_projeto` | `core.projetos.nome` onde `codigo_projeto_omie = codigo_projeto`; **inclui projeto com `deleted_at` preenchido**, como no detalhe da OC |

Exemplo (pedido 46618, Mogi):

```json
{
  "id": "…",
  "codigo_empresa": "759979bd-2b2d-41f2-b1b7-db6fae89ee59",
  "numero_pedido": "46618",
  "codigo_fornecedor": "10363934283",
  "nome_fornecedor": "…",
  "razao_social_fornecedor": "…",
  "cpf_cnpj_fornecedor": "…",
  "codigo_comprador": "10219958954",
  "nome_comprador": "…",
  "etapa": "15",
  "etapa_descricao": "Incluído",
  "codigo_condicao_pagamento": "U10",
  "descricao_condicao_pagamento": "30/40/50/60/70",
  "codigo_categoria": "2.01.03",
  "descricao_categoria": "Compras de Materia Prima",
  "codigo_conta_corrente": "10364415646",
  "descricao_conta_corrente": "01 - Boleto/Pix/TED",
  "codigo_projeto": "9779703251",
  "nome_projeto": "16 - Revenda",
  "itens": [ … ],
  "parcelas": [ … ]
}
```

- Sugestão de implementação: os mesmos subselects `literal(...)` de `ATRIBUTOS_NOMES` /
  `ATRIBUTOS_HISTORICO`, trocando o alias pelo do `PedidoCompra`, no `findOne` de
  `src/routes/pedidos_compras.js`.
- **Na listagem `GET /pedidos_compras`: não precisa.** O av-hub lista pedidos por
  `/compras/ordens?origem=omie`, que já resolve os nomes.

## 3. Perguntas em aberto

- `etapa_descricao` depende da de-para `pedidos_compras_etapas`, que o DBA mantém (pergunta em
  aberto do contrato 25). Etapa sem linha na de-para devolve `null`, e a tela mostra "Etapa 15".

## 4. Depois de aplicado (av-hub)

- `components/Compras/PedidoOmieDetalhe.tsx`: o título passa a ser o nome do fornecedor, como no
  detalhe da OC, e os fatos mostram nome e código: fornecedor com CNPJ, comprador, condição,
  categoria, conta, projeto e etapa. Apagar a marca `GAMBIARRA(vault 09-Contratos/27-…)`.
- `PedidoCompraOmieProps` (`lib/domain/compras-ordem.ts`) ganha os campos novos.

## 5. Aceite

- `GET /pedidos_compras/{id}` do 46618 devolve `nome_fornecedor` igual ao da linha dele em
  `GET /compras/ordens?origem=omie`, `nome_projeto = "16 - Revenda"` e
  `descricao_conta_corrente = "01 - Boleto/Pix/TED"`.
- Um pedido de Uberaba com um código de fornecedor que também existe em Mogi resolve o nome **de
  Uberaba**.
- Um código que não está no cadastro da unidade devolve `null`, não quebra a resposta.
- Nenhum campo que já existia muda de nome ou de tipo.

[^c1]: Nota de 14/10/2026: Em 14/10/2026 esta nota está em `06-Contratos/Entregues/`; a pasta `Realizados/` era do vault v1.
