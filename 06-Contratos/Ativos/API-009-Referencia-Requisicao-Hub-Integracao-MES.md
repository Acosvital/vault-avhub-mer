---
id: API-009
aliases: ["Contrato 009", "009-Referencia-Requisicao-Hub-Integracao-MES"]
tags: [contrato, contrato-api, mes, integracao-av-hub-mes, compras, requisicao]
criado: 2026-10-15
atualizado: 2026-10-15
status: proposta
dono: "Gustavo"
etapa_0b: [C0, P1, P2, P3, E1]
fontes: ["N14-28 (Registro-de-Decisoes)", "api-acos-vital/src/schemas/core_vendas_faturamento/tables/requisicoes_compra/requisicoes_compra.route.js:34-47,383-408", "api-acos-vital/src/schemas/core_vendas_faturamento/views/vw_ordens_compra_referencia_mes/vw_ordens_compra_referencia_mes.route.js:70-100", "Dump Avhub (Esqueleto).sql:18541-18571 (requisicoes_compra), :17804-17817 (ordens_compra_itens_vinculos)", "proposta do Robert (BL-051, 15/10/2026)", "resposta do Gustavo (BL-002, BL-019, BL-028, 15/10/2026)"]
criado_original: 2026-10-15
---

# Contrato de API 009 — Referência da requisição do Compras (av-hub → MES)

> [!info] Situação em 15/10/2026
> **Status:** `proposta` · **Pasta:** `Ativos` · **Nós do 0b:** C0, P1, P2, P3, E1 · **Dono:** Gustavo (rota), Robert (job e telas do MES), Nathan (campo na tela do HUB)
>
> - 📝 **Decisão N14-28 (Nathan, 15/10/2026):** a requisição criada no av-hub pelo Compras **com vínculo a pedido de venda** deve aparecer no MES **antes de virar OC**, para o PCP saber que o item já está em compra e não requisitar duas vezes. A OC vinculada já chega pela referência ([[API-004-Referencia-OC-Integracao-MES]]); este contrato cobre o intervalo **entre a requisição e a OC**.
> - 🔴 **Nada existe ainda:** nem a rota, nem o job do MES, nem o campo na tela. Este texto é a proposta para o Gustavo e o Robert aprovarem.
> - ✅ **O banco já guarda o vínculo:** `requisicoes_compra.numero_pedido_venda` e `codigo_pedido_omie` existem (`Dump Avhub:18563-18564`), mas **só o PUT do MES grava** (`fn_requisicao_mes_aplicar`, [[LOG-34-Requisicoes-MES-Empurra-para-o-Hub]]). O `POST /compras/requisicoes` (a "Nova requisição" do HUB) **não aceita** esses campos: a lista `CAMPOS` do `requisicoes_compra.route.js:34-47` não os traz. **Sem a parte 1 deste contrato, o Compras não consegue informar o pedido de venda**.
> - ✅ **Conferência do BL-028 (Gustavo, 15/10) vale só para a OC**: a referência da OC basta para o saldo futuro e para a OC do pedido. A rota deste contrato é nova e não está coberta por aquela resposta.
>
> Conferido contra `api-acos-vital` 276dab8 e o Dump Avhub de 14/10. Selos em [[Regras-do-Vault]].

**Destinatários:** backend do av-hub (`api-acos-vital`, Gustavo: rota e validação), MES (`api-pcp`, Robert: job, projeção e telas), front do av-hub (Nathan: campo de pedido de venda).

## Por quê

O PCP decide o que comprar na Triagem, na Destinação e no Atendimento do Estoque. Quando o **Compras** cria a requisição no av-hub, ela **não chega ao MES**: só o que tem `id_origem` gera marcos (contrato 35) e `id_origem` é `NOT NULL` em `requisicoes_compra_eventos`. Resultado: entre a requisição do Compras e a emissão da OC, o PCP não sabe que o item já está em compra e pode abrir uma requisição igual (**compra duplicada**).

A OC, depois de aprovada, já aparece no MES pela referência (item com `destino[]` de pedido de venda, BL-049). Falta o intervalo anterior. Este contrato cria uma leitura **só de leitura**, espelho da referência da OC, para esse intervalo.

**Não muda:** o contrato 34 (a ida do MES), o contrato 35 (os marcos), o `id_origem NOT NULL` e a regra "requisição sem pedido de venda não chega ao MES" (continua valendo, N14-20). A requisição que **já veio do MES** (`id_origem` preenchido) também fica **fora**: o MES já a conhece.

## Onde isso mora

- **av-hub:** `api-acos-vital`, mesma família da referência da OC. Leitura em view (a regra mora no banco, como o [[LOG-38-Regras-Sem-Chave-de-Ambiente]] manda).
- **MES:** o mesmo job de 5 min do contrato 004/007 lê as duas referências (BL-001 e BL-065), grava uma projeção local e as telas do PCP leem a projeção.

## Parte 1 — Pedido de venda na requisição (Gustavo)

> [!note] Detalhe e aceite no API-010
> Esta Parte 1 foi **detalhada e passou a ser o contrato [[API-010-Requisicao-do-Compras-Finalidade-Pedido-e-Produto]]** (inclui a coluna `finalidade`, os erros e a trava da OC na mesma unidade). Em caso de diferença, **vale o API-010**. A rota de leitura (Parte 2) segue neste contrato.

Hoje só o MES grava `numero_pedido_venda` (pelo PUT). A "Nova requisição" precisa gravá-lo.

| Mudança | Regra |
|---|---|
| **`finalidade` na requisição** (N14-33) | Coluna nova `requisicoes_compra.finalidade`: `pedidos_venda`, `recompra`, `estoque` ou `uso_interno` (a mesma lista da OC). **Obrigatória** no `POST /compras/requisicoes`. `pedidos_venda` e `recompra` **exigem** `numero_pedido_venda`; `estoque` e `uso_interno` **não aceitam** (`400 FINALIDADE_PEDIDO_VENDA`). Requisição que já existe ou que vem do MES (`id_origem`): `pedidos_venda` se tem `numero_pedido_venda`, `estoque` se não tem. Migration versionada (BL-024). A OC emitida a partir da requisição herda a finalidade dela (a tela da OC já segue a requisição) |
| `POST /compras/requisicoes` aceita `numero_pedido_venda` (string, até 30) e `codigo_pedido_omie` (inteiro, opcional) | Entram na lista `CAMPOS` do `requisicoes_compra.route.js`. Opcionais: sem pedido de venda a requisição é de estoque ou uso interno e **não aparece no MES** |
| Validação | Se vier `numero_pedido_venda`, o pedido tem de existir em `core_vendas_faturamento.pedidos_vendas` na unidade `codigo_empresa` (não excluído). Senão `400 PEDIDO_VENDA_INEXISTENTE` |
| `PATCH /compras/requisicoes/:id` aceita trocar ou limpar `numero_pedido_venda` | Só enquanto `status` for `aberta` ou `em_cotacao` e `id_origem` for nulo. Requisição do MES não muda pelo Compras. `atendida` e `cancelada` não mudam |
| Auditoria | `updated_by` da sessão, como nas demais rotas |
| **Produto do cadastro obrigatório** (N14-30) | O `POST /compras/requisicoes` passa a exigir `material` igual a um `codigo_produto` existente em `core.produtos` da unidade `codigo_empresa`. Senão `400 PRODUTO_INEXISTENTE`. O PATCH não troca o produto de requisição já criada. O PUT do MES não muda: ele já grava o `codigo_produto`. Requisição antiga sem casamento continua devolvendo `codigo_produto_omie = null` na rota |

**Coerência com a OC:** quando a OC nasce a partir da requisição, o vínculo `ordens_compra_itens_vinculos` (item da OC → pedido de venda) é o que vale daí em diante. 🟡 Se o Compras criar a OC sem vincular o pedido que estava na requisição, o item some do intervalo e não aparece como OC do pedido. Q3 abaixo.

## Parte 2 — A rota (Gustavo)

### `GET /compras/requisicoes/referencia?alterado_desde=&codigo_empresa=&apos_id=&page=&limit=`

Mesmo desenho da referência da OC ([[API-004-Referencia-OC-Integracao-MES]]): cursor por `(alterado_em, id)`, `alterado_desde` obrigatório.

| Parâmetro | Regra |
|---|---|
| `alterado_desde` | **obrigatório**, ISO 8601. Devolve as requisições cujo `alterado_em` é **maior** que ele, em ordem crescente de `alterado_em` e `id` |
| `codigo_empresa` | opcional (uuid da unidade). Sem ele, todas |
| `apos_id` | opcional (uuid): desempate do cursor, como na referência da OC |
| `page`, `limit` | paginação; `limit` padrão 100, máximo 500 |
| Erros | `400` para parâmetro inválido, com `detail`; `401` e `403` pela chave |

**Quais requisições entram** (a regra mora na view, como a `vw_ordens_compra_referencia_mes`):

1. `id_origem IS NULL` (nasceu no av-hub; a do MES já é conhecida por lá);
2. `numero_pedido_venda IS NOT NULL` (na prática, finalidade `pedidos_venda` ou `recompra`; `estoque` e `uso_interno` não ligam a pedido de venda e o MES não precisa saber, N14-28 e N14-33);
3. `deleted_at IS NULL`;
4. **em qualquer status** (`aberta`, `em_cotacao`, `atendida`, `cancelada`): o MES precisa ver a **mudança** para tirar a requisição da tela quando ela é cancelada ou vira OC. Quem decide o que mostrar é o MES, pelo `status`.

**`alterado_em`** = o maior entre o `updated_at` da requisição e o `updated_at` da OC que a atendeu (se houver). Mudar o status (inclusive pela trigger da OC, que marca `atendida` ou devolve a `aberta`) precisa fazê-la reaparecer. 🔴 Gustavo confere se a trigger da OC atualiza o `updated_at` da requisição (Q2); se não atualizar, a marca vira trigger própria, como a `alterado_em` da referência da OC (migration `api004`).

**Response (200):**
```json
{
  "total": 1, "page": 1, "limit": 100, "total_pages": 1,
  "data": [
    {
      "id_requisicao": "uuid",
      "codigo_empresa": "uuid-da-unidade",
      "numero_requisicao": "RC-000412",
      "status": "em_cotacao",
      "finalidade": "pedidos_venda",
      "material": "FL-CEGO-6-150",
      "codigo_produto_omie": "9764577293",
      "descricao": "FLANGE CEGO RF B16.5 150LBS AC 6\"",
      "quantidade": 10.0,
      "unidade_medida": "PC",
      "prazo_necessidade": "2026-10-28",
      "numero_pedido_venda": "25970",
      "codigo_pedido_omie": null,
      "id_ordem_compra": null,
      "numero_ordem_compra": null,
      "situacao_ordem_compra": null,
      "alterado_em": "2026-10-15T14:20:00Z"
    }
  ]
}
```

| Campo | Observação |
|---|---|
| `id_requisicao` | uuid da requisição no av-hub; chave da projeção no MES (por `(codigo_empresa, id_requisicao)`) |
| `material` | Texto como o hub guarda (varchar 60, **texto livre**, sem FK com `core.produtos`). Nas requisições que o MES empurra é o código do produto (`codigo_produto`, o humano). Na requisição criada no hub pode ser qualquer texto |
| `codigo_produto_omie` | **Resolvido pela view** em `core.produtos` por `codigo_empresa` + `codigo_produto = material`; **`null` quando o texto não casa** com produto da unidade. Pedido do Robert (15/10): o MES casa por unidade + `codigo_produto_omie`, o mesmo grão da OC (obrigatório na OC desde o [[LOG-36-Compras-Produto-Obrigatorio-e-Comprador-da-OC]]). Requisição com `codigo_produto_omie = null` aparece ao PCP só pelo texto, com aviso "sem cadastro", **sem cruzamento** nem aviso de duplicidade |
| `status` | `aberta`, `em_cotacao`, `atendida`, `cancelada` |
| `finalidade` | `pedidos_venda` ou `recompra` (só essas chegam ao MES). Na `recompra` o pedido de venda é o que está sendo reposto; o PCP vê como "Recompra aberta no Compras" |
| `id_ordem_compra`, `numero_ordem_compra`, `situacao_ordem_compra` | Preenchidos quando `atendida`: ligam a requisição à OC (o item da OC traz `id_requisicao`). `situacao_ordem_compra` é a da OC (`rascunho`, `aguardando_aprovacao`, `aprovado`, `cancelado`). **Existe para fechar o buraco entre emitir e aprovar a OC** (revisão do Robert, 15/10): a referência da OC só traz OC aprovada, então a requisição `atendida` precisa seguir visível como "OC X aguardando aprovação" até a OC chegar aprovada ou ser cancelada |
| `quantidade` | `numeric(15,4)` neste contrato; o model do hub declara `DECIMAL(14,3)`. O MES aceita os dois |

**Não trafega:** solicitante, observação, fornecedor, preço, condição. Só o que o PCP precisa para saber que o item está em compra (minimização de dados, mesma filosofia da referência da OC).

### Autenticação

Rota de serviço, sem token de usuário e sem linha em `auth.rotas_telas`. O MES lê com a **chave de serviço de escrita** que o Gustavo confirmou em 15/10 (cobre a referência da OC e o resto do que o MES chama). Com a chave restrita por `rotas_permitidas` ([[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] S1, BL-057), a lista da chave do MES precisa **incluir esta rota**.

## Parte 3 — O que o MES faz (Robert)

1. **Job** (o mesmo de 5 min do contrato 004/007, BL-001): lê esta rota e a referência da OC, com `alterado_desde` guardado por rota; UPSERT por `(codigo_empresa, id_requisicao)`. Falha de uma das leituras não derruba a outra.
2. **Projeção local** da requisição do hub (nome e desenho do Robert). Não é a `RequisicaoCompra` do MES, que representa o circuito físico (Compras · CCP → Recebimento).
3. **Cruzamento** com o pedido por **unidade do pedido + número do pedido + `material`** (o `codigo_produto`, o código humano, que agora vem sempre do cadastro): o item de pedido do MES só tem esse código (revisão do Robert, 15/10). O `codigo_produto_omie` (por unidade, diferente em cada uma e sem casar entre unidades) serve para ligar à OC, ao cadastro e ao saldo do Estoque. Requisição antiga sem casamento (`codigo_produto_omie = null`) aparece só pelo texto, com aviso "sem cadastro" e sem cruzamento.
4. **O que o PCP vê** (BL-065), na Triagem, na Destinação e no Atendimento:
   - `aberta` ou `em_cotacao`: "**Requisição aberta no Compras:** nº, N un, necessidade dd/mm";
   - `atendida` com OC `rascunho` ou `aguardando_aprovacao`: **continua visível** como "**OC X aguardando aprovação**" (a referência da OC só traz OC aprovada); some quando a OC aparece aprovada na projeção da OC (e passa a valer "Compra em andamento: OC X, N un, previsão dd/mm", BL-049) ou quando a OC é cancelada (a requisição volta a `aberta` e reaparece);
   - `cancelada`: some.
5. **Aviso ao requisitar (P3):** ao abrir uma requisição do MES, se já existe requisição do hub ou OC não cancelada cobrindo o mesmo filial + pedido + produto, o MES avisa e mostra o que existe. ✅ **Só avisa** (Q5, N14-29), com a decisão do PCP registrada; a requisição do hub **não abate nem vincula**, só a OC aprovada abate (proposta do Robert, 15/10). **Deixar claro no modal:** a requisição do hub **só avisa**; quem **abate** a quantidade e vincula a parcial é a **OC aprovada** (BL-051).
5b. **Tabela própria:** a projeção da requisição do hub fica numa tabela separada, distinta da requisição interna "origem hub" do BL-051 (que cobre parcial já coberta por OC e não vai ao av-hub). Se a unidade de medida da requisição for diferente da do material no MES, o MES avisa (mesma regra de 13/10).
6. **Torre de Fluxo:** esta projeção **não gera evento** de fluxo. A Torre só acompanha o item de pedido de venda no seu caminho (regra N14-28).

## Parte 4 — A tela do HUB (Nathan)

BL-041 (N14-33, pronto no HUB, PR #209): a "Nova requisição" deixa de ser modal e vira **tela própria** (`/compras/requisicoes/nova`), no padrão da emissão da OC: **para que é** (pedido de venda, recompra, estoque, uso interno), **unidade**, **pedido de venda** da mesma unidade (só para as finalidades que ligam a PV, com a lista de itens pendentes do pedido e "Usar este item"), **produto do cadastro** da unidade, quantidade, unidade de medida, prazo de necessidade, tipo sugerido e observação. Estoque e uso interno avisam que o PCP não vê a requisição. O HUB já envia `finalidade` e `numero_pedido_venda`; a API só passa a gravar depois da Parte 1.

## Critérios de aceite

1. `POST /compras/requisicoes` com `numero_pedido_venda` de pedido existente na unidade grava e devolve 201; pedido inexistente devolve `400 PEDIDO_VENDA_INEXISTENTE`.
2. `PATCH` troca ou limpa o pedido de venda de requisição `aberta` ou `em_cotacao` sem `id_origem`; em requisição do MES, `atendida` ou `cancelada` devolve 400/409 com mensagem.
3. A rota devolve a requisição do Compras **com** pedido de venda e **não** devolve a sem pedido de venda nem a que veio do MES (`id_origem` preenchido).
4. Emitir a OC marca `atendida` e a requisição **reaparece** na leitura seguinte com `id_ordem_compra` e `numero_ordem_compra`; cancelar a OC devolve a `aberta` e ela reaparece. Com a OC `aguardando_aprovacao`, a linha traz `situacao_ordem_compra = aguardando_aprovacao`, e o MES mostra "OC X aguardando aprovação" até a OC aprovada chegar pela referência da OC.
5. Cancelar a requisição faz ela reaparecer com `status = cancelada`.
6. Cursor `(alterado_em, id)` com `apos_id` não repete nem perde linha entre páginas (mesmo teste da referência da OC).
7. A chave do MES lê a rota; a chave do pipeline e a de usuário comum não (`403`).
7b. A rota devolve `codigo_produto_omie` preenchido quando `material` é um `codigo_produto` da unidade e `null` quando não casa; `material` de outra unidade não casa.
8. No MES: requisição do hub com pedido de venda aparece ao PCP em até 5 min; vira OC e a tela passa a mostrar a OC; o aviso de compra duplicada aparece ao requisitar o mesmo filial + pedido + produto.
9. Requisição do hub **sem** pedido de venda não aparece no MES e não entra na Torre.

## Ordem e rollback

| # | Quem | Passo |
|---|---|---|
| 1 | Gustavo | Parte 1 (POST e PATCH com pedido de venda), na `develop` |
| 2 | Gustavo | View, rota e marca `alterado_em` (Parte 2) e swagger; migration versionada no repositório (BL-024) |
| 3 | Nathan | Campo na "Nova requisição" (BL-041), depois do passo 1 |
| 4 | Robert | Job e projeção (BL-065), junto do job da referência da OC (BL-001) |
| 5 | Robert, Nathan | Telas do PCP e aviso ao requisitar |

**Rollback:** a rota é nova e só de leitura. Desligar o job do MES apaga a tela, sem efeito em Compras. O campo de pedido de venda na requisição fica no banco sem prejuízo (era coluna existente, só sem escrita pelo POST).

## Perguntas em aberto

| # | Pergunta | Dono | Selo |
|---|---|---|---|
| Q1 | ✅ **Respondida pelo Robert (15/10): não é o mesmo código.** `material` é texto livre; a OC traz `codigo_produto_omie` (id do Omie por unidade). A rota devolve `codigo_produto_omie` resolvido na view (ver tabela de campos) | Robert | ✅ |
| Q2 | A trigger da OC (`fn_ordens_compra_requisicao`) atualiza o `updated_at` da requisição? Se não, precisa de marca `alterado_em` própria | Gustavo | 🔴 ❓ |
| Q3 | Se o Compras emite a OC sem repetir o vínculo do pedido de venda, a OC herda o vínculo da requisição? Hoje o vínculo da OC é por item (`ordens_compra_itens_vinculos`) | Gustavo, Nathan | 🔴 |
| Q4 | ✅ **Decidido (15/10, N14-31): pedido de venda, requisição e ordem de compra são sempre da mesma unidade.** A rota não precisa devolver `codigo_empresa_pv`. Para a OC, o vínculo `ordens_compra_itens_vinculos.codigo_empresa_pv` tem de ser igual ao `codigo_empresa` da OC: 🔴 Gustavo confere se o banco já recusa a diferença; se não, entra a trava (erro 400 na API e, se possível, checagem no banco) | Nathan, Gustavo | ✅ 📝, 🔴 trava na OC ❓ |
| Q5 | ✅ O aviso de compra duplicada **só avisa** e a requisição do hub **não abate nem vincula** (só a OC aprovada abate). Decidido em 15/10 (N14-29) | Nathan | ✅ 📝 |
| Q6 | ✅ **Respondida pelo Robert (15/10): 500 basta**; o cursor pagina e o volume é baixo | Robert | ✅ |
| Q7 | ✅ **Decidido (15/10, N14-30): sempre exigir produto do cadastro** na requisição do hub (com ou sem pedido de venda), como o LOG-36 fez na OC. Entra na Parte 1 | Nathan | ✅ 📝 |

Relacionados: [[API-004-Referencia-OC-Integracao-MES]], [[API-007-Referencia-OC-Valores-no-MES]], [[LOG-34-Requisicoes-MES-Empurra-para-o-Hub]], [[LOG-35-Compras-Marcos-Requisicao-para-MES]], [[04-Circuito-de-Compra]], [[05-Recebimento]], [[02-PCP-Triagem-e-Destinacao]], [[Pontas-Soltas]] (PS-034), [[Backlog-por-Frente]] (BL-041, BL-064, BL-065), [[Registro-de-Decisoes]] (N14-28).
