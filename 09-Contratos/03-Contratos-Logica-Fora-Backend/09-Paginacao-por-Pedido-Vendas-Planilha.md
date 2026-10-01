# Contrato — paginar /vendas_planilha por pedido, não por linha crua

**Criado em:** 15/09/2026, achado num review de correção de dados.

**Status (01/10/2026): backend ENTREGUE (Opção B), conferido na `api-test`. Falta o front adotar.**

O DBA avisou que concluiu; conferido em 01/10/2026 em `api-test.acosvital.com.br`:

| Teste | Resultado |
|---|---|
| `GET /vendas_planilha?pedido_venda=27320&agrupar_por=pedido_venda` | ✅ `total: 1`, `total_linhas: 5`, 1 registro com `qtd_parciais: 5` e `parciais[]` aninhados |
| Paginação (`limit=50`, páginas 1, 2 e 3) | ✅ 150 pedidos distintos, nenhum repetido entre páginas; `total: 9845` pedidos (contra 12.422 linhas), `total_pages: 197` |
| Filtros junto (`data_inicio`/`data_fim`; pedido inexistente) | ✅ 816 pedidos em setembro; pedido inexistente dá `total: 0` |
| Valor inválido (`agrupar_por=xyz`) | ✅ 400 "agrupar_por deve ser um de: pedido_venda" |

Forma da resposta agrupada: `{ total, page, limit, total_pages, paginar_por, agrupar_por, total_linhas, data: [{ chave_pedido, codigo_empresa, pedido_venda, codigo_pedido_omie, data_inclusao, codigo_cliente, cliente, codigo_vendedor, vendedor, numero_contrato, codigo_categoria, categoria, valor_total, qtd_parciais, parciais: [...] }] }`. `chave_pedido` = `codigo_empresa:pedido_venda`.

**O modo padrão (sem `agrupar_por`) não mudou:** ainda conta e pagina por linha crua (`pedido_venda=27320` dá `total: 5`). O problema só some **quando o front manda `agrupar_por=pedido_venda`**: o av-hub ainda não manda, então `pedidos-equipe` e `pcp-pedidos` seguem com o grupo cortado na borda da página até a troca (§3).

**Histórico (28/09/2026):** testado ao vivo e não resolvido (`total` por linha, parciais espalhados, `agrupar_por` ignorado).

**Objetivo:** `GET /vendas_planilha` devolve **1 linha por parcial/sequencial**, não 1 linha por
pedido — um `pedido_venda` com 4 parciais gera 4 registros com `codigo_pedido_omie` diferentes
cada (confirmado ao vivo, pedido_venda "27320"). O frontend agrupa essas linhas de volta em 1
card por pedido (`agruparPorPedidoVenda`, `utils/agruparPedidosPlanilha.ts`), mas a **paginação
acontece antes do agrupamento** — `page`/`limit` cortam a lista crua de linhas, não de pedidos.

## 1. O problema

Se os 2 últimos parciais de um pedido caem um na última posição da página N e o outro na primeira
posição da página N+1, a tela mostra **2 cards incompletos/duplicados** pro mesmo pedido em vez de
1 card completo — total e situação errados nos dois. Afeta pelo menos 3 telas que paginam
`/vendas_planilha` direto: `pedidos-equipe` (`app/(protected)/pedidos-equipe/page.tsx`, empresa
inteira, ~8 mil pedidos/mês), `pcp-pedidos` (mesmo padrão, escopado aos vendedores do
diligenciador) e, num grau menor, `meus-pedidos` (escopado a 1 vendedor — já corrigido no
frontend buscando o mês inteiro de uma vez e paginando os grupos no cliente, viável só porque o
volume por vendedor é pequeno).

Pedidos da Equipe e PCP não têm esse luxo — o volume (empresa inteira, às vezes ano inteiro) torna
"buscar tudo e paginar no cliente" caro. Precisa de paginação de verdade por pedido no backend.

## 2. O que peço

Uma das duas (a critério do backend):

**Opção A — `total`/`total_pages` por pedido, ordenação que respeita o grupo.** `GET
/vendas_planilha` já ordenar os resultados por `pedido_venda` (garantindo que os parciais de um
mesmo pedido fiquem sempre adjacentes, nunca espalhados) e calcular `total`/`total_pages` a partir
da contagem de `pedido_venda` **distintos** que batem no filtro, não da contagem de linhas. O
frontend mantém `limit` como "quantos pedidos por página" e o backend garante que nenhuma página
corta um pedido no meio (pode devolver mais ou menos que `limit` LINHAS numa página específica,
desde que nunca corte um grupo).

**Opção B — endpoint/modo agregado.** Um parâmetro tipo `agrupar_por=pedido_venda` que já devolve
1 registro por pedido (com os parciais aninhados, ex.: `{ pedido_venda, parciais: [...] }`),
paginado de verdade por pedido. Mais trabalho de backend, mas tira a agregação do frontend
inteiramente (hoje replicada em `utils/agruparPedidosPlanilha.ts`, consumida por 4 telas).

Qualquer uma resolve — Opção A é a mudança menor.

## 3. O que muda no frontend quando isso existir

- `app/(protected)/pedidos-equipe/page.tsx` e `app/(protected)/pcp-pedidos/page.tsx`: `rowCount`
  volta a vir de `resposta.total` (agora por pedido) em vez de recalculado a partir de linhas
  cruas; `agruparPorPedidoVenda(rows)` continua sendo chamado sobre a página atual, mas sem risco
  de grupo cortado, já que o backend garante os parciais adjacentes.
- `app/(protected)/meus-pedidos/page.tsx`: pode voltar a paginar no servidor (`page`/`limit` reais)
  em vez do contorno atual de buscar o mês inteiro e paginar os grupos no cliente — não bloqueia,
  só deixa de ser necessário.
- Mesma pergunta vale pra `/faturamento_planilha` (`notas-equipe`/`pcp-notas`/`minhas-notas`) se
  esse endpoint também tiver conceito de "parcial" agrupável — não confirmei se tem; se não tiver,
  não se aplica.

## 4. Não bloqueia

Enquanto isso não existir: `meus-pedidos` já está corrigido (busca o mês inteiro, agrupa, pagina
os grupos no cliente — viável pelo volume pequeno por vendedor). `pedidos-equipe` e `pcp-pedidos`
continuam com o bug de grupo cortado na borda da página até a paginação por pedido existir no
backend — não apliquei o mesmo contorno nessas duas por causa do volume (buscar tudo a cada filtro
mudaria de "1 chamada leve" pra "1 chamada pesada" a cada interação).
