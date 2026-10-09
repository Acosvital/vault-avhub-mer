---
tags: [contrato-api, contrato-sql, etapas-faturamento, pipeline, front]
criado: 2026-10-07
atualizado: 2026-10-07
status: proposta
---

# Contrato 43 — Ordem das etapas de faturamento vem do cadastro (fecha a marca P6)

> Status: proposta (leitura de código e vault em 07/10/2026; **produção só pelo dump de 07/10**, que não mostra colunas de `core.etapas_faturamento`) | fecha o item **P6** de [[04-Pedidos-Notas-Dashboards-Agregacao-no-Banco]] e a marca `GAMBIARRA(` de `utils/etapasFluxo.ts:10` do av-hub. Decisões em [[Registro-de-Decisoes-2026-10-07]].
> Legenda: ✅ verificado no código/vault · 🟡 inferido · 🔴 pendente com dono.

**Para:** DBA/backend (Gustavo), pipeline (Gustavo) e front do av-hub · **Pequeno.** O backend e o front já têm quase tudo; falta dado e limpeza.

## 1. O que a marca diz e o que o código mostra

`utils/etapasFluxo.ts` (av-hub) tem `ORDEM_ETAPAS = [10, 20, 80, 50, 60, 70]` e `posicaoNoFluxo(codigo)`, que devolve o índice na lista ou `ORDEM_ETAPAS.length + codigo` para código fora dela. O comentário do arquivo explica a regra: em set/2026 nenhum pedido em etapa 80 estava faturado, enquanto 60 e 70 estavam 100% faturados; logo o 80 vem **antes** do 50.

Achados que mudam a proposta (todos ✅ salvo indicação):

| # | Achado | Onde |
|---|---|---|
| A1 | **A coluna já existe com outro nome: `ordem_fluxo`** (`smallint`, nula, `min 1`, `max 999`), comentada "Contrato 05 (P6)… NULL = fim do fluxo. Não vem do Omie: é cadastro nosso". **Não se cria coluna `ordem`.** | `api-acos-vital/.../etapas_faturamento.model.js:76-82` |
| A2 | A rota `GET /etapas_faturamento` já devolve `ordem_fluxo`, aceita gravá-lo (`POST`/`PUT`, está em `FIELDS`) e tem `?ordem=fluxo`: ordena por `codigo_empresa`, `codigo_operacao`, `COALESCE(ordem_fluxo, 1000 + codigo_etapa)`, `codigo_etapa`. | `etapas_faturamento.route.js:18-25, 66-77`; swagger `:49-54, 225` |
| A3 | `GET /pedidos_venda/{codigo_empresa}/{pedido_venda}` já devolve `etapas` na ordem do fluxo, lendo `core_vendas_faturamento.vw_etapas_fluxo_pedido` (`codigo_etapa, descricao, ordem_fluxo, posicao, ativo`, `ORDER BY posicao, codigo_etapa`, sem o orçamento). A view **existe em produção** (dump de 07/10, [[Auditoria-Dump-Producao-2026-10-07]] §9), mas o **SQL dela não está no repositório nem no vault**: a regra de `posicao` não foi verificada. | `pedidos_venda.route.js:181-188` |
| A4 | O front de **`PedidoDetalhe.tsx` já usa `pedido.etapas` da API** (linhas 272-278) e **não** `posicaoNoFluxo`. | av-hub |
| A5 | O **único** consumidor de `posicaoNoFluxo` é `services/portalGerente/etapasEmpresa.ts` (`getEtapasDaEmpresa`, ordena na linha 39). **`getEtapasDaEmpresa` não tem nenhum chamador** na pasta do front (busca por `getEtapasDaEmpresa` e `etapasEmpresa`: só o próprio arquivo e `docs/arquitetura/grafo-dependencias.html`). A marca fica sobre **código morto** (🟡: o grafo HTML não foi aberto; confirmar no repositório real, pois a pasta lida pode estar desatualizada). | av-hub |
| A6 | O DDL original do pipeline (`005_etapas_faturamento_contrato.md`) **não** tem `ordem_fluxo`. A coluna foi acrescentada depois, por fora do repositório do pipeline. O doc `docs/ENVIAR - contrato-05-pendencia-ordem-etapas-fluxo.md` do front registra, em 25/09, que a API devolvia `ordem_fluxo` em 68 etapas, **0 preenchidas**. Se continua assim em produção hoje, não foi verificado (o dump de 07/10 não mostra a tabela). | pipeline; front |

## 2. De onde vem a ordem: Omie ou nós?

- **Código da etapa (10, 20, 80, 50, 60, 70): é do Omie.** Vem de `etapa.cCodigo` em `ListarEtapasFaturamento` (`etapasFaturamento.ts:89`). ✅
- **A tabela é espelho do Omie, mas o Omie não manda ordem.** O payload documentado em `005_...md` traz só `cCodigo`, `cDescrPadrao`, `cDescricao`, `cInativo` por etapa, agrupadas por operação, e `mapRow` só grava `codigo_empresa`, `codigo_operacao`, `descricao_operacao`, `codigo_etapa`, `descricao_padrao`, `descricao`, `ativo`. ✅ (Não há `ListarEtapasFaturamento` real executado nesta leitura: a ausência de campo de ordem vem do exemplo documentado, 🟡 para qualquer campo que o Omie mande e o pipeline ignore.)
- **A ordem `[10, 20, 80, 50, 60, 70]` é regra de negócio nossa**, deduzida da observação de dados de set/2026 (texto do comentário do front). Não é do Omie. 🟡 (não há decisão do Nathan registrada; o contrato 04 e o pedido de 25/09 só a tomam "como referência").
- **Consequência:** a ordem **não pode ser populada pelo pipeline**; é coluna **mantida pela nossa aplicação** e precisa ficar a salvo do upsert.

### Hoje o upsert já não a sobrescreve, mas por acaso

`upsert.ts` monta as colunas do `INSERT`/`UPDATE` a partir das chaves da linha que o `mapRow` devolve (`colunasGravaveis`, `upsert.ts:30-36`), menos as protegidas. Como `mapRow` não emite `ordem_fluxo`, ela não é tocada. ✅ Basta alguém acrescentar a coluna ao `mapRow` (ou o Omie passar a mandar algo mapeado) para a ordem ser apagada em silêncio, a mesma classe de bug de `notas_fiscais.descontos` descrita em `protectedColumns.ts`. A proteção formal é barata e segue o padrão de [[Colunas-Protegidas]].

## 3. O que se propõe

### 3.1 Banco: reutilizar `ordem_fluxo`

- **Nome e tipo:** `core.etapas_faturamento.ordem_fluxo`, `smallint NULL`, intervalo 1..999 (já no model). **Não criar `ordem`.** Se produção **não** tiver a coluna (A6, não verificado), o DDL é `ALTER TABLE core.etapas_faturamento ADD COLUMN IF NOT EXISTS ordem_fluxo smallint NULL CHECK (ordem_fluxo BETWEEN 1 AND 999);` 🟡 (o `CHECK` só espelha a validação do model; o do banco real é desconhecido).
- **Escopo da ordem:** por linha, ou seja por `(codigo_empresa, codigo_operacao, codigo_etapa)`, como a chave única. O front de hoje usa uma ordem só para todas as unidades. O mesmo código tem **descrição diferente por unidade** (etapa 20 é "Liberado Compras" numa e "Separar Estoque" noutra; 80 é "Separar Estoque" na empresa principal, ver comentários do front e de `etapasFaturamento.ts`), então **não está provado que a ordem é igual em todas**. Ver pergunta Q1.
- **Etapa sem ordem:** `ordem_fluxo NULL` vai para o fim, em ordem do código. A API já faz isso (`COALESCE(ordem_fluxo, 1000 + codigo_etapa)`), equivalente ao `ORDEM_ETAPAS.length + codigo` do front: os ordenados (1..999) sempre antes dos sem ordem em ambos. ✅
- **Valores iniciais (operação `11`, todas as unidades, 🟡 até a Q1):**

| codigo_etapa | 10 | 20 | 80 | 50 | 60 | 70 |
|---|---|---|---|---|---|---|
| ordem_fluxo | 1 | 2 | 3 | 4 | 5 | 6 |

  Seed idempotente, só onde está nulo (não pisa em ordem já ajustada à mão):

```sql
UPDATE core.etapas_faturamento e
   SET ordem_fluxo = v.ordem
  FROM (VALUES (10,1),(20,2),(80,3),(50,4),(60,5),(70,6)) AS v(codigo, ordem)
 WHERE e.codigo_operacao = '11'
   AND e.codigo_etapa = v.codigo
   AND e.ordem_fluxo IS NULL
   AND e.deleted_at IS NULL;
```

  A etapa `0` (orçamento) fica sem ordem (a view e o front já a excluem). Etapas de outras operações (`01`, `21`, `22`, `28`...) ficam nulas: o front só consulta a `11`.
- **Quem altera depois:** `PUT /etapas_faturamento/{id}` com `ordem_fluxo` (já existe). Não há tela de edição conhecida no front (🟡, não encontrada na leitura); até existir, o ajuste é por `PUT`/SQL do DBA.

### 3.2 Pipeline (tarefa: Gustavo)

Em `omie-elt-pipeline/src/db/protectedColumns.ts` acrescentar:

```ts
'core.etapas_faturamento': ['ordem_fluxo'],
```

com o mesmo tipo de comentário das outras entradas ("cadastro nosso, o Omie não manda ordem"). Atualizar também a tabela de [[Colunas-Protegidas]] (nota do vault) e a de [[Etapas-Faturamento]] (listar `ordem_fluxo` como coluna **fora** do mapeamento Omie). **Não** mapear `ordem_fluxo` no `mapRow`.

### 3.3 API

Nada novo na rota: `ordem_fluxo` já sai em `GET /etapas_faturamento` e `?ordem=fluxo` já ordena. Duas verificações (Gustavo): (a) conferir no banco real que a coluna existe e o seed rodou; (b) abrir a definição de `vw_etapas_fluxo_pedido` e conferir que `posicao` vem de `ordem_fluxo` com a mesma regra do fim da fila, e **versionar o SQL da view** no vault ou no repositório da API.

### 3.4 Front (passo a passo)

1. Confirmar no repositório real do av-hub que `getEtapasDaEmpresa` não tem chamador (A5).
2. **Se não tiver (o provável):** apagar `utils/etapasFluxo.ts` e `services/portalGerente/etapasEmpresa.ts` (e o rastro no grafo de dependências). A marca `GAMBIARRA(` some com o arquivo.
3. **Se tiver chamador:** em `etapasEmpresa.ts`, pedir `?ordem=fluxo` à rota (passar o parâmetro pelo BFF `app/api/etapas_faturamento/route.ts`, que hoje repassa só `codigo_operacao`, `codigo_empresa` e `limit`), **remover o `.sort(...)` local** e `posicaoNoFluxo`; o resultado já vem na ordem. Cache: o catálogo muda raramente; manter a consulta cacheada por empresa durante a sessão (revalidação curta no BFF, valor 🟡 a combinar com o dono do front).
4. **Fallback:** enquanto a coluna estiver toda nula, a API devolve na ordem numérica (10, 20, 50, 60, 70, 80), **não** na ordem real. Por isso a ordem de subida abaixo: seed **antes** de o front deixar de usar a constante. Se for preciso manter rede de proteção por um ciclo, deixar a constante só como fallback **quando todas as etapas voltarem com `ordem_fluxo` nulo** e com um aviso no console; remover no ciclo seguinte.
5. (Opcional, fora do P6) `getOpcoesFiltroEtapa` (`etapasFaturamento.ts:45`) ordena o filtro de Etapa por código numérico; passar a ordenar pelo fluxo é melhoria separada, e muda a ordem que o usuário vê hoje (decisão do dono da tela).

## 4. Ordem de subida

1. **DBA:** conferir/criar `ordem_fluxo` em produção (ver 3.1) e rodar o seed. Nada quebra: o campo é nulo-tolerante.
2. **Pipeline:** `protectedColumns.ts` (3.2). Pode subir junto ou logo após o seed; **antes de qualquer mudança futura em `mapRow`**.
3. **API:** só verificação e versionamento da view (3.3); sem deploy esperado.
4. **Front:** remover/trocar (3.4) depois de conferir que o seed está em produção (teste de aceite 1).

## 5. Testes de aceite

1. `GET /etapas_faturamento?codigo_operacao=11&ordem=fluxo&codigo_empresa={cada unidade}` devolve, filtrando as etapas ativas conhecidas, a sequência de códigos `10, 20, 80, 50, 60, 70`, com as demais depois, por código.
2. `GET /pedidos_venda/{codigo_empresa}/{pedido_venda}` devolve `etapas` na mesma sequência para pedidos de cada unidade.
3. Rodar a sincronização completa do pipeline (full sync) e repetir 1: `ordem_fluxo` **não** volta a nulo. Também após mexer em uma etapa no Omie (renomear a descrição) e sincronizar.
4. Telas de Pedidos (lista, detalhe, filtro de Etapa): mesma ordem de antes nas unidades; detalhe do pedido mostra "Etapa N de M" igual a hoje.
5. Etapa sem ordem (simular: `UPDATE ... SET ordem_fluxo = NULL` numa etapa de teste) aparece no fim, depois das 6.
6. Busca no front por `ORDEM_ETAPAS`, `posicaoNoFluxo` e `GAMBIARRA(docs/ENVIAR - contrato-pedidos-notas-dashboards-agregacao-no-banco.md` não acha o P6.

## 6. Rollback

- **Front:** reverter o commit (volta o arquivo da constante). Sem efeito no banco.
- **Pipeline:** tirar a linha de `protectedColumns.ts` volta ao comportamento de hoje (que já não toca na coluna).
- **Banco:** `UPDATE core.etapas_faturamento SET ordem_fluxo = NULL WHERE codigo_operacao = '11'` desfaz o seed. Guardar antes um `SELECT id, ordem_fluxo` de todas as linhas para restaurar ordens ajustadas à mão. Não apagar a coluna enquanto a API e a view a usarem.

## 7. Riscos

- **R1:** ordem pode ser **diferente por unidade** (Q1). O seed único para todas pode errar numa delas; a coluna por linha permite corrigir sem código.
- **R2:** a regra "80 antes de 50" foi **observação de dados de set/2026**; se o negócio mudar o fluxo ou o Omie renumerar as etapas, a ordem fica velha em silêncio (antes isso exigia mexer no front; agora basta `PUT`).
- **R3:** definição de `vw_etapas_fluxo_pedido` fora do repositório: não foi possível confirmar que `posicao` bate com a regra acima.
- **R4:** se o front atual (`develop`) tiver um chamador de `getEtapasDaEmpresa` que a leitura não achou, remover os arquivos quebra a tela.
- **R5:** produção não confirmada: coluna e dados de `ordem_fluxo` só foram vistos em 25/09 (nulos), via doc do front.

## 8. Alternativa honesta: aceitar a constante

Se a ordem for **estável e igual para todas as unidades**, manter `ORDEM_ETAPAS` no front é defensável: são 6 códigos, o front já ignora a constante na tela que importa (detalhe do pedido) e o único consumidor é código sem chamador. Nesse caso: apagar o código morto (3.4, item 2) em vez de plumbing novo, trocar a marca `GAMBIARRA(` por um comentário de regra de negócio e **reclassificar** o P6 como "regra aceita". **Decisão 🔴 Nathan** (Q2). A proposta deste contrato é fazer o banco ser a fonte (3.1 a 3.4) porque a infraestrutura já existe e custa pouco; a alternativa só vale se a Q1 responder "igual em todas" e ninguém quiser ajustar ordem sem deploy.

## 9. Perguntas em aberto

| # | Pergunta | Dono |
|---|---|---|
| Q1 | A ordem real do fluxo (10, 20, 80, 50, 60, 70) vale para **todas as unidades**, ou o 20/80 mudam de papel por unidade (descrições diferentes)? Quem confere é quem conhece o Omie de cada filial. | 🔴 Nathan |
| Q2 | Ordem pela tabela (este contrato) ou constante aceita e marca reclassificada (seção 8)? | 🔴 Nathan |
| Q3 | Produção tem a coluna `ordem_fluxo`? Está toda nula hoje? Qual o SQL de `vw_etapas_fluxo_pedido`? | 🔴 Gustavo |
| Q4 | Etapas como `15` (item 52 do registro: nome das etapas 10, 15 e 20 a conferir no Omie) entram no fluxo e em que posição? | 🔴 Nathan |
| Q5 | O repositório real do av-hub tem algum chamador de `getEtapasDaEmpresa`? | 🔴 dono do front |
| Q6 | O filtro de Etapa em Pedidos (`getOpcoesFiltroEtapa`) deve passar a seguir o fluxo? | 🟡 dono da tela |

## Ver também

[[Etapas-Faturamento]] · [[Colunas-Protegidas]] · [[04-Pedidos-Notas-Dashboards-Agregacao-no-Banco]] · [[39-Vendedores-Fila-de-Vinculo]] · [[Registro-de-Decisoes-2026-10-07]]
