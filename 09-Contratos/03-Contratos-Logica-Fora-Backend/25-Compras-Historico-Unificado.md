# Contrato — Compras: histórico único (OC do av-hub + pedido de compra antigo do Omie)

**Criado em:** 24/09/2026 · **Para:** DBA, backend (`api-acos-vital`), pipeline e av-hub

Estende a decisão do [[24-Compras-Vinculo-Pedido-Venda]] (que já resolve isso só dentro do card
"Compras deste pedido") para as telas **Ordens de compra**, **Dashboard de compras** e
**Requisições**. Depende do **B4**/**L4** ([[22-Compras-Backend-Consolidado]] /
[[23-Compras-Pipeline-Consolidado]] — envio da OC ao Omie) e do **C4**
([[15-Compras-Pendencias-Pos-Backend]] — `GET /compras/ordens/resumo`).

---

## 1. Por quê

Hoje existem **duas fontes de compra** que não se falam fora do card de PV:

- `ordens_compra` (+ itens/parcelas) — a OC que o **av-hub cria**. É a única coisa que
  `GET /compras/ordens` e o painel (`PainelCompras`) enxergam.
- `pedidos_compras` (+ itens/parcelas) — o **espelho só-leitura** do Omie, com **674+ pedidos**
  (crescendo: 5.434 no teste local de 24/09/2026), a maioria criada **antes** do av-hub existir e
  fora dele.

O Nathan: *"é melhor o pedido de venda estar mesclado com a ordem de compra criada no AV-Hub, por
mais que seja sistemas diferentes a base é praticamente a mesma. Senão eu perco meu histórico."* —
e confirmou que isso vale também para o **Dashboard de compras** e as **Requisições**, não só
para o pedido de venda.

**O mecanismo de unificação já existe e já está decidido** (contrato 24, §5): quando uma OC do
av-hub é enviada ao Omie (`cCodIntPed = numero_pedido`, ex. `"OC-000123"`), a pipeline lê esse
mesmo pedido de volta e grava `pedidos_compras.codigo_pedido_integracao = "OC-000123"`. A
`vw_pedido_venda_compras` já ignora a linha do espelho quando isso acontece, mostrando só a linha
`ordens_compra` no lugar dela — uma identidade só, sem duplicar. **Este contrato só pede para
reaproveitar esse mesmo mecanismo fora do escopo de um PV.**

## 2. O que falta (as 3 telas)

### H1. `GET /compras/ordens` — histórico completo, não só o que nasceu no av-hub

Hoje só lê `ordens_compra`. Precisa virar uma **view unificada** (nome sugerido
`vw_ordens_compra_historico`), no mesmo espírito de `vw_pedido_venda_compras`:

```sql
-- Rascunho — a base de cada lado, colunas normalizadas para o mínimo que a
-- listagem usa hoje (numero, fornecedor, unidade, valor, previsão, status,
-- sincronização, origem). Ajustar contra o schema real na hora de aplicar.
CREATE VIEW core_vendas_faturamento.vw_ordens_compra_historico AS
SELECT
  'av-hub'::text                       AS origem,
  oc.id                                 AS id,
  oc.numero_pedido                      AS numero,
  oc.codigo_empresa,
  oc.codigo_fornecedor,
  oc.valor_total_brl,
  oc.data_previsao_chegada,
  oc.status,                           -- status do av-hub (régua de aprovação)
  oc.status_sincronizacao_omie,
  oc.created_at
FROM core_vendas_faturamento.ordens_compra oc
WHERE oc.deleted_at IS NULL

UNION ALL

SELECT
  'omie'::text                         AS origem,
  pc.id,
  pc.numero_pedido,
  pc.codigo_empresa,
  pc.codigo_fornecedor,
  NULL::numeric                        AS valor_total_brl,  -- ver H4: converter moeda/soma dos itens
  pc.data_previsao,
  pc.etapa,                            -- cEtapa do Omie ("10"/"15"/"20"...) — NÃO é o status do av-hub
  NULL::text                           AS status_sincronizacao_omie,  -- não se aplica: já está no Omie
  pc.incluido_em_omie                  AS created_at
FROM core_vendas_faturamento.pedidos_compras pc
WHERE pc.deleted_at IS NULL
  AND pc.codigo_pedido_integracao IS NULL;  -- é o que já bate a OC do av-hub: não duplica
```

`GET /compras/ordens` (e o `q`/`sort`/`order`/paginação de C3) passam a ler daqui. **Sem `page`**
continua juntando tudo (BFF), mas ver H3 abaixo — com 5000+ linhas do espelho isso deixa de ser
seguro.

### H2. Dashboard de compras — KPIs sobre o histórico unificado

`PainelCompras`/`GET /compras/ordens/resumo` (C4) somam hoje só `ordens_compra`. Os cards
"Ordens aprovadas" e "Requisições e ordens" devem contar sobre `vw_ordens_compra_historico`
inteira (av-hub + Omie-só), não só o que o av-hub criou. **"Aguardando aprovação" continua só
av-hub** — um pedido puramente do Omie não passa pela régua de aprovação daqui, não faz sentido
aparecer nesse card.

### H3. Requisições — não é a listagem em si, é o link que ela gera

`requisicoes_compra` **não tem equivalente no Omie** (é conceito só do av-hub, nasceu com ele) —
não há o que unificar na listagem de Requisições em si. O que muda: quando uma requisição gera
uma OC (`POST /compras/requisicoes/{id}/gerar-oc` ou o fluxo equivalente) e essa OC depois é
sincronizada e unificada (H1), o link "Ver ordem de compra" da requisição **continua batendo direto
no `id` de `ordens_compra`** (a origem "av-hub" da view usa o mesmo `id`) — nada quebra, só
confirmar no código que ninguém assume que todo item de `vw_ordens_compra_historico` tem
`status_sincronizacao_omie`/régua de aprovação preenchidos (H1 já cobre isso com `NULL`).

### H4. Valor em R$ dos pedidos do Omie-só

`pedidos_compras` não tem uma coluna equivalente a `ordens_compra.valor_total_brl` — só os itens
(`pedidos_compras_itens.valor_total`, já em R$ pelo de-para do [[14-Compras-Omie-Pedido-Compra]]).
A view (H1) precisa somar os itens por pedido (`SUM(pci.valor_total) GROUP BY id_pedido_compra`),
não inventar uma coluna nova em `pedidos_compras`.

## 3. Perguntas em aberto

- **Status amigável para o Omie-só.** `pedidos_compras.etapa` é o código cru do Omie ("10", "15",
  "20"...). A tela de Ordens de compra mostra `STATUS_ORDEM_LABEL` (rascunho/aguardando
  aprovação/aprovado/cancelado) — precisa de um de-para de `etapa` pra alguma coisa exibível
  (ex.: "10" → "Incluído", sem inventar que passou pela aprovação do av-hub). Confirmar o de-para
  completo dos códigos de `cEtapa` (o [[23-Compras-Pipeline-Consolidado]], L10, já lista isso como
  pendente de confirmar na conta de teste).
- **Paginação de verdade antes de ligar.** Com 5000+ linhas de espelho, a gambiarra atual do
  `useCompras.ts` (baixa tudo, pagina no navegador) não aguenta — H1 só devia ir para a tela depois
  do C3 (paginação/filtro no servidor) estar pronto, senão o navegador trava.
- **Filtro "só o que eu emiti pelo av-hub"** ainda faz sentido pra alguém (ex.: auditoria)? Se sim,
  a origem (`av-hub`/`omie`) vira um filtro na tela, não só uma coluna.

## 4. Depois de aplicado

- `/compras/ordens`: nova coluna/badge de origem (`av-hub` vs `Omie`, antes do av-hub existir);
  pedidos Omie-só abrem num detalhe **somente leitura** (sem os botões de aprovar/reprovar/PDF
  interno, que são do fluxo av-hub).
- `PainelCompras`: KPIs "Ordens aprovadas" e "Requisições e ordens" sobem de valor imediatamente ao
  ligar (histórico de meses vira visível de uma vez) — avisar antes de ligar em produção, pra não
  parecer um pico de compras do dia.
- Nada muda em `Requisições` além de confirmar o link (H3).

## Ver também

- [[24-Compras-Vinculo-Pedido-Venda]] — o mecanismo original (`codigo_pedido_integracao`),
  escopado por pedido de venda.
- [[22-Compras-Backend-Consolidado]] (B4) e [[23-Compras-Pipeline-Consolidado]] (L4) — pré-requisito:
  sem o envio da OC ao Omie, `codigo_pedido_integracao` nunca é preenchido pelo lado do av-hub.
- [[15-Compras-Pendencias-Pos-Backend]] (C3, C4) — paginação/filtro no servidor e os endpoints de
  resumo que H2 estende.
