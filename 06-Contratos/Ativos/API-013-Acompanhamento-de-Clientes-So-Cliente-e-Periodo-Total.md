---
id: API-013
aliases: ["Contrato 013", "013-Acompanhamento-Clientes-So-Cliente-Periodo-Total"]
tags: [contrato, contrato-api, acompanhamento-clientes, clientes, tag-cliente, periodo, exportacao, av-hub, leitura]
criado: 2026-10-19
atualizado: 2026-10-19
status: proposta
sistemas: [hub-banco, hub-api, hub-front]
dono: "Gustavo"
etapa_0b: []
fontes: ["av-hub/components/AcompanhamentoClientes/AcompanhamentoClientes.tsx", "av-hub/lib/api/acompanhamentoClientesApi.ts:62-80 (lista fixa de parâmetros)", "av-hub/lib/api/acompanhamentoClientesExportar.ts", "av-hub/app/api/acompanhamento-clientes/exportar/route.ts", "api-acos-vital src/schemas/core_vendas_faturamento/functions/fn_acompanhamento_clientes/fn_acompanhamento_clientes.route.js", "Dump do Avhub para referência.sql:3376-3705 (fn_acompanhamento_clientes: CTE cadastro, clientes, visiveis; coluna cliente_cadastro)", "LOG-48 §12.2 (base = cadastro + quem comprou)", "Pedido do Nathan de 19/10/2026"]
criado_original: 2026-10-19
---

# Contrato de API 013 — Acompanhamento de clientes: só clientes (tag) e período total

> **Onde atua:** av-hub: API (rota e função), front

> [!info] Situação em 19/10/2026
> **Status:** `proposta` · **Pasta:** `Ativos` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Gustavo (API e banco); Nathan (front)
>
> - ✅ **Hoje a tela não filtra por tag.** Nem a tela, nem o BFF, nem a rota `GET /acompanhamento_clientes` filtram por `core.tipos_parceiro`. A **base** da função `fn_acompanhamento_clientes` é a união (`UNION`) de: parceiros com o tipo `CLIENTE` (CTE `cadastro`, `upper(tp.tipo) = 'CLIENTE'`) **mais** quem tem pedido ou NF **mais** membros de grupo **mais** quem tem venda/faturamento no mês ([[LOG-48-Acompanhamento-de-Clientes-Grupos-de-Empresa]] §12.2). Quem compra e não tem a tag (fornecedor, sem tipo, "Setor - *") aparece na tela. Em 13/10 eram **122** clientes sem a tag, de 3.964.
> - ✅ A função já devolve a coluna `cliente_cadastro` (boolean) em cada linha: é `true` quando o parceiro tem a tag. O front só a usa na aba "Clientes" da planilha ("Cliente no cadastro: Sim/Não").
> - ✅ **Exportação** (`GET /api/acompanhamento-clientes/exportar`) pede à API todos os recortes **sem** filtro de tag: sai a base inteira, com a tag ou sem.
> - ✅ **Período:** a função, a rota e a tela trabalham sempre **um mês** (`mes`, `ano`). Os campos `*_mes` (venda, faturamento, pedidos, NFs) são só desse mês. Não há como ver nem exportar o histórico inteiro.
> - 📝 **Pedido do Nathan, 19/10/2026:** (1) exportar já filtrado só com clientes (tag CLIENTE); (2) opção de ver **todo o período**, sem limite de datas, na tela e na exportação.
> - 🔴 Nada deste contrato está codificado. O front (Nathan) sai pronto **esperando** a API: o BFF repassa os parâmetros novos e a API atual os ignora; por isso a tela avisa quando o eco do filtro/período não vem na resposta (seção 4).
> - **MES (Robert): sem trabalho.**
>
> Selos em [[Regras-do-Vault]].

## Por quê

O time comercial quer ver, e levar para o Excel, a lista de **clientes** (parceiros com a etiqueta Cliente no Omie), não a mistura de clientes com quem só aparece em pedido ou NF por cadastro errado. E quer olhar o **histórico inteiro** de venda e faturamento de cada cliente, sem escolher mês a mês. As duas regras são de dados (tag no cadastro; soma por intervalo de datas), então ficam no banco e na API, como pede a regra de lógica no backend; o navegador só manda a escolha e exibe.

## 1. Pedido 1 — parâmetro `so_cliente`

### Rota `GET /acompanhamento_clientes`

| Parâmetro | Tipo | Padrão | Regra |
|---|---|---|---|
| `so_cliente` | booleano (`true`/`false`) | `false` | `true` devolve só as linhas com `cliente_cadastro = true` (parceiro com o tipo `CLIENTE` em `core.parceiros_tipos` / `core.tipos_parceiro`, a mesma regra da CTE `cadastro` e de `core_mapas.vw_todos_os_clientes`). Valor diferente de `true`/`false`: `400 { detail: "so_cliente deve ser true ou false." }` |

Sem mudar a função: a rota já filtra a saída dela (busca, `status`, `id_grupo`); `so_cliente` é mais um filtro do mesmo tipo (`AND cliente_cadastro IS TRUE`), aplicado **antes** de paginar e de calcular os KPIs.

### O que muda com `so_cliente=true`

| Ponto | Regra |
|---|---|
| Lista (`visao=cnpj`) | só CNPJs com a tag. `total`, `page`, `totalPages` contam só eles |
| KPIs (`kpis=true`) | calculados **sobre as linhas filtradas**: `total_clientes`, ativos, inativos, `sem_compra`, venda e faturamento do mês, etc. Fecham com a lista |
| Visão por grupo (`visao=grupo`) | 🟡 **Gustavo confirma.** Proposta: o grupo aparece se **algum** membro tem a tag; a linha do grupo conta **todos** os membros no status (`coberto_grupo` depende de todos), mas `qtd_cnpjs` e as somas de valor contam só os membros com a tag. Se preferir simplificar: o grupo conta só membros com a tag em tudo. Decidir e escrever aqui |
| `status`, `busca`, `id_grupo`, `codigo_empresa`, ordenação, escopo de vendedor | continuam valendo e combinam com `so_cliente` |
| Detalhe do cliente (`/movimento`) | não muda |

### Resposta

Mesmo formato de hoje. Acrescentar em `parametros` (🟡 se a resposta já tiver esse objeto) ou na raiz o eco do filtro aplicado, para o front conferir: `"so_cliente": true`.

## 2. Pedido 2 — período total

### Parâmetro novo na rota `GET /acompanhamento_clientes`

| Parâmetro | Tipo | Padrão | Regra |
|---|---|---|---|
| `periodo` | `mes` \| `total` | `mes` | `mes` = comportamento de hoje (`mes`/`ano`). `total` = **sem limite de datas**: todos os pedidos e NFs, desde o primeiro até hoje. Com `periodo=total`, `mes` e `ano` são ignorados. Outro valor: `400 { detail: "periodo deve ser mes ou total." }` |

### Função `fn_acompanhamento_clientes`

Nova assinatura, mantendo as anteriores funcionando (parâmetros novos com `DEFAULT NULL`, no fim):

```
fn_acompanhamento_clientes(
  p_mes integer, p_ano integer, p_codigo_empresa uuid DEFAULT NULL,
  p_vendedores text[] DEFAULT NULL, p_dias_inativo integer DEFAULT 90,
  p_inicio date DEFAULT NULL, p_fim date DEFAULT NULL)
```

- `p_inicio`/`p_fim` nulos: o intervalo é o mês de `p_mes`/`p_ano` (hoje: `v_ini`, `v_fim`, `v_ultimo`).
- `p_inicio`/`p_fim` informados: o intervalo do período é `[p_inicio, p_fim]` (inclusive) e **substitui** o mês em tudo que hoje é "do mês": `qtd/valor_pedidos_mes`, `qtd/valor_nfs_mes`, `venda_*`, `faturamento_*`, `qtd_pedidos_venda_mes`, `qtd_nfs_faturamento_mes`, `composicao_mes`, `comprou_mes` (grupo: `qtd_cnpjs_com_venda_grupo`). Para o total, a rota passa `p_inicio = '2000-01-01'` e `p_fim = hoje (America/Sao_Paulo)`. 🟡 Gustavo pode trocar `2000-01-01` por `NULL = sem limite inferior` se a função ficar mais simples; o efeito para o front é o mesmo.
- **Não muda** com o período: `ultima_compra`, `ultimo_pedido`, `ultima_nf`, `dias_sem_comprar`, `qtd_pedidos_total`, `qtd_nfs_total` e o **status** (já olham o histórico inteiro).
- A regra de venda e faturamento (pedidos/NFs classificados da Equipe, deduções, YPFB `fora_dos_numeros`) é a mesma, só com intervalo maior. Atenção ao tempo: 🔴 **medir** a consulta no período total na unidade maior.

Os nomes das colunas `*_mes` ficam (compatibilidade). No período total, **significam "no período"**: o front troca o rótulo.

### Resposta: eco do período

Acrescentar, na raiz da resposta da lista, o intervalo realmente usado:

```json
"periodo": { "tipo": "total", "inicio": "2000-01-01", "fim": "2026-10-19" }
```

ou, no modo mês, `{ "tipo": "mes", "mes": 10, "ano": 2026, "inicio": "2026-10-01", "fim": "2026-10-31" }`. O front usa isso para os rótulos e para conferir que o dado é do período pedido.

### Detalhe e `/movimento`

Fora deste contrato: o detalhe do cliente e `GET /acompanhamento_clientes/movimento` continuam **por mês** (a lista de pedidos/NFs de um cliente no histórico inteiro pode ter milhares de linhas e pede paginação). Se for desejado, vira contrato próprio.

## 3. Exportação

O Excel do front (`GET /api/acompanhamento-clientes/exportar`) junta ~30 chamadas a `GET /acompanhamento_clientes` (cada recorte). Com este contrato:

- o BFF passa `so_cliente=true` em **todas** as chamadas quando a pessoa marca "Só clientes" na tela (**padrão da tela: marcado**, ver seção 4);
- passa `periodo=total` em todas quando a pessoa escolhe "Todo o período";
- nenhuma conta nova no front: as abas continuam sendo o que a API devolve.

🟡 No modo total, as abas "Maiores do mês" passam a ser "Maiores do período" (ordenadas por `venda_liquida_mes` / `faturamento_liquido_mes`, que agora são do período). O rótulo é do front.

## 4. Tela (Nathan)

| Bloco | O que muda |
|---|---|
| Filtro "Só clientes" | caixa de seleção na barra de filtros. **Marcada por padrão** (decisão do front; o pedido é "clientes com a tag"); desmarcar mostra a base inteira como hoje. Na URL: `so_cliente=0` só quando desmarcada. Vai para a API como `so_cliente` |
| Período | o seletor de mês ganha a opção **"Todo o período"**. Na URL: `periodo=total`. Vai para a API como `periodo=total` (sem `mes`/`ano`) |
| Rótulos | no total, "Venda do mês" → "Venda no período", "Faturamento do mês" → "Faturamento no período", cartões "Venda líquida 10/2026" → "Venda líquida (todo o período)" |
| Exportação | botão "Exportar Excel" segue "Só clientes" e "Todo o período" da tela; o nome do arquivo vira `acompanhamento-clientes-todo-periodo.xlsx` no total |
| Aviso | enquanto a API não entregar: o front **detecta** (a resposta não traz `periodo.tipo = "total"` / o filtro não foi eco) e mostra "A API ainda não filtra clientes / período total" em vez de números errados sob o rótulo novo |

## 5. Erros

| Status | Quando | Corpo |
|---|---|---|
| 400 | `so_cliente` ou `periodo` inválidos | `{ "detail": "..." }` |
| 401/403 | sem chave; fora do escopo | como hoje |
| 504 | período total estoura o tempo | o front mostra "A API demorou demais" (já tratado no BFF) |

## Fora deste contrato

- Mudar a **base** da função (hoje cadastro + quem comprou): `so_cliente` é um filtro de saída; quem compra sem tag continua existindo na base e na planilha quando desmarcado.
- Intervalo livre de datas (de/até): `periodo=total` cobre o pedido; `p_inicio`/`p_fim` já deixam a função pronta para isso depois.
- Período total no detalhe e em `/movimento`.
- Corrigir o cadastro dos 122 clientes sem tag no Omie (é do cadastro, não da tela).

## Checklist

**Gustavo (API e banco)**
- [ ] `so_cliente` na rota `GET /acompanhamento_clientes` (lista, KPIs, grupo) e no swagger.
- [ ] Decidir o comportamento do grupo com `so_cliente=true` (seção 1) e escrever aqui.
- [ ] `p_inicio`/`p_fim` na `fn_acompanhamento_clientes` (migration) e `periodo=total` na rota; eco `periodo` na resposta.
- [ ] Medir o tempo do período total na unidade maior; se passar de 30 s, avisar o Nathan (o BFF espera até 120 s por chamada).
- [ ] Atualizar o `COMMENT ON FUNCTION` e o [[LOG-48-Acompanhamento-de-Clientes-Grupos-de-Empresa]].

**Nathan (front)**
- [ ] Caixa "Só clientes" e opção "Todo o período" na tela, na URL e na exportação.
- [ ] BFF repassa `so_cliente` e `periodo`; exportação idem.
- [ ] Rótulos do período; aviso quando a API ainda não responde ao novo parâmetro.

**Robert (MES):** nada.

## Aceite

1. `GET /acompanhamento_clientes?so_cliente=true&kpis=true`: toda linha vem com `cliente_cadastro = true`; `kpis.total_clientes` = `total` da lista.
2. `GET /acompanhamento_clientes?so_cliente=false`: igual a hoje (inclui os que compram sem a tag).
3. `GET /acompanhamento_clientes?periodo=total&kpis=true`: resposta traz `periodo.tipo = "total"`; `venda_liquida_mes` de cada cliente = soma da venda líquida de **todos** os meses (conferir um cliente contra a soma de 12+ chamadas mensais) e `kpis.venda_liquida_mes` = soma das linhas (fora YPFB).
4. `status`, `ultima_compra` e `dias_sem_comprar` são iguais com `periodo=mes` e `periodo=total`.
5. Excel com "Só clientes" marcada: nenhuma linha com "Cliente no cadastro = Não" em nenhuma aba. Com "Todo o período": as colunas de venda/faturamento batem com a tela.
6. `so_cliente=talvez` e `periodo=ano` respondem 400.

## Ver também
[[LOG-48-Acompanhamento-de-Clientes-Grupos-de-Empresa]] · [[Acompanhamento-Clientes]]
