---
tags: [erp-acos-vital, arquitetura, integracao, av-hub, mes, contrato-api, f1]
criado: 2026-09-22
atualizado: 2026-10-07
status: rascunho
---

# Integração av-hub ↔ MES — Especificação técnica v1 (F1)

> Status: decidido | no código (verificado em 07/10/2026) — decisões em [[Registro-de-Decisoes-2026-10-07]], itens 1, 2, 42 a 45.
>
> **Decisões de 07/10/2026 sobre esta nota.** O `PUT` de sucesso do contrato 34 **já foi validado no `mes-test`** (✅ Nathan, itens 1 e 2). **IM-01 e o IM-03 antigo estão superados** pelo contrato 34 (🟡). **IM-02 (pedido sem prazo) está resolvida pelo código** (🟡): o MES cai para `pedido.prazoEntrega` e recusa se ainda não houver prazo. **Contrato 005:** o consumidor roda na `api-acos-vital` (🟡 Gustavo, F2, 19 a 30/10, com tabela local do status por item); o aceite das 3 diferenças é 🔴 do Nathan (Robert já aprovou em 30/09). Onde o texto abaixo diz "sem consumidor" ou "faltam perguntas do 003", vale este parágrafo.

> **Atualização de 07/10/2026 — estado real por contrato (auditoria código × vault).** Fonte: leitura de código, **não** produção/homologação — MES na branch `develop` (api-pcp `ca3346b`, 07/10; **`main` do MES parou em 28/08, nada abaixo está nela**) e API do av-hub em `main`=`develop` (`a6ab058`, 06/10). O desenho original abaixo (3 fluxos só por polling GET) **mudou na prática**: o MES passou a **empurrar** (PUT) as requisições de compra e a **ler** os marcos de compra. Texto antigo preservado; correções marcadas "(atualizado em 07/10)".
>
> | Contrato | Estado real (conferido no código) |
> |---|---|
> | **34** PUT `/compras/requisicoes/origem/{id_origem}` (MES → hub) | **Implementado e ligado no MES** (`e7ce2c9`, 02/10, PR #48, `EnvioAvhubService`). A requisição vira uma linha da fila `integracao_avhub_envios` na mesma transação; um PUT por item (`id_origem` = id do `RequisicaoCompraItem`); disparo imediato + timer de 60 s; retentativa com espera crescente (1/2/5/10/30/60 min). 200/201 → `ENVIADO` (espelha id, número e status no item); 409 `REQUISICAO_COM_OC` → `RECUSADO` (não repete); 400 → `FALHOU`; 401/403/404/5xx reagenda; **sem chave definida a fila espera com aviso no log**. O PUT não leva `id_item_parcial`. Lado hub: rota existe em `main` (`0391b29`, #275), mas depende da função de banco `core_vendas_faturamento.fn_requisicao_mes_aplicar` (migration 034, **não está em nenhum SQL do vault**; sem ela o PUT devolve 500). Se a chave está definida e a função aplicada no ambiente real: **não verificado**. **(atualizado em 07/10)** ✅ O `PUT` de sucesso já funcionou no `mes-test` (homologação, `develop`) e `fn_requisicao_mes_aplicar` existe em produção, completa (dump de 07/10), mas seu SQL ainda não está versionado no vault. |
> | **35** GET `/compras/requisicoes/eventos` (hub → MES, marcos) | **Implementado e ligado no MES** (`41bf4a6`, 05/10, PR #49, `EventosAvhubService`): cursor `requisicoes-eventos`, sobreposição de 2 min, até 50 páginas × 200, idempotente por `id_evento`. O MES **só reage** a `requisicao_cancelada` e `requisicao_reaberta`; os demais marcos (`oc_aprovada`, `oc_no_omie`, `despachada`...) são só gravados e espelham `avhubStatus` / alimentam métricas — **não** preenchem pedido de compra nem previsão e **não** avançam a parcial. Lado hub: rota em `main` (`0a65491`, #275). Ver [[App-PCP-Recebimento-Conferencia]]. |
> | **26 / L4** `/pedidos_liberados` (hub → MES) | **Ok**: o MES lê carteira, `/:n/itens` e confirma por `POST /:n/importado` com `referencia` (`65df59b`, 24/09; `901f9bb`, 29/09). Lado hub em `main` (`4bf36d9`). **L6 segue aberto** (ver abaixo). |
> | **003** `GET /requisicoes-compra` (hub puxa do MES) | **Substituído pelo 34.** A rota ainda existe no MES no formato do hub (`901f9bb`, `5c1316f`), mas **nenhum job do `api-acos-vital` a consome**. |
> | **005** `GET /itens/status` (hub puxa do MES) | **A rota existe no MES** (`901f9bb`; `etapa` derivada do tipo do setor; foto atual da parcial). **Não há consumidor no hub** (sem rota/tabela de status por item na API). **(atualizado em 07/10)** 🟡 O consumidor será da `api-acos-vital` (Gustavo, F2), com tabela local; 🔴 aceite do Nathan às 3 diferenças pendente. |
> | **004** `GET /ordens-compra/referencia` (MES puxa do hub) | **Inexistente nos dois lados.** No hub só existem os pré-requisitos de dados (`ordens_compra_itens_vinculos`, `requisicoes_compra.id_origem`, `status`). Substituto operacional: **registro manual** no MES, `PATCH /compras/requisicoes/:id/compra` (número do pedido, fornecedor, previsão), que move a parcial para o Recebimento; não há job de leitura de OC. |
>
> **Chaves (atualizado em 07/10).** O tema está em [[Chaves-de-Integracao-AvHub-MES-Pipeline]]; aqui só o essencial. **A chave própria do MES para o 34 (`MES_INTEGRACAO_KEYS` no hub, `AVHUB_MES_INTEGRACAO_KEY` no MES) só abre o `PUT /compras/requisicoes/origem/{id}`.** Com ela, `/pedidos_liberados`, `/unidades`, `/produtos` e `/compras/requisicoes/eventos` respondem 403 `CHAVE_MES_ROTA_NAO_PERMITIDA`, até em GET. Por isso **o MES lê o hub com uma chave de outro tipo** (`API_KEY` do MES: tem de ser uma chave admin ou uma chave de serviço do banco, que **não têm restrição por rota**; qual delas está em uso no ambiente real: **não verificado**). **Pendência L6 do contrato 26 (chave do MES restrita às rotas que ele usa): segue aberta.** Os contratos 004 e 005 falam em "chave do MES de escrita restrita às rotas que o MES usa" como se viesse da chave do 34 — não vem.

> **Tarefa F1 do [[Cronograma-2-Meses]]** (responsável Nathan, janela 21/09–29/09, depende de DEC-2). Critério de pronto: *"spec aprovada por Robert e Gustavo; polling, idempotência e dono de cada coluna definidos"*. Este documento é esse detalhamento — a decisão de **mecanismo** (polling REST bidirecional, `x-api-key`, 3 fluxos) já foi tomada como **DEC-2** em [[MES-Arquitetura-Decisoes]] (21/09/2026); o que faltava, e que este arquivo resolve, é o contrato exato de cada um dos 3 fluxos.
>
> **Atualização de 30/09/2026 — retorno do Robert.** O Robert comparou os contratos com o código e **aprovou o 003 e o 005 com ajustes, e o 004 com um ajuste no item** (`id_origem` por item). As rotas dos Fluxos 1 e 3 **já existem no MES** (`api-pcp` `901f9bb`), e o Fluxo 4 está implementado dos dois lados. Os payloads abaixo são os do rascunho de 22/09: **vale o que está em cada contrato** ([[003-Requisicao-Compra-Integracao-MES]], [[004-Referencia-OC-Integracao-MES]], [[005-Status-Item-Integracao-MES]]). Para a F1 fechar faltam o aceite do Nathan aos ajustes, as três perguntas novas do 003 (nomes dos campos, pedido sem prazo, onde fica o job) e a aprovação do Gustavo. Das perguntas da seção 7: a 1 está resolvida (o `api-pcp` tem a guarda de `x-api-key`), a 2 saiu (o status do MES é só informação; `atendida` é do av-hub), a 3 foi resolvida pelo [[007-Ordens-Compra-Estruturada]] e a 5 está resolvida (`limit` no MES, `page`/`limit` no av-hub).
>
> **Status: aprovado por Nathan em 22/09/2026.** Aprovação formal de Robert e Gustavo (condição de pronto do F1 no cronograma) ainda não registrada — os contratos abaixo nascem como `proposta`, não `aplicada`, até esse sinal chegar. Os 3 fluxos já viraram contratos de API formais em [[Indice-Contratos]]: [[003-Requisicao-Compra-Integracao-MES]], [[004-Referencia-OC-Integracao-MES]] e [[005-Status-Item-Integracao-MES]]; a tabela nova do lado av-hub (seção 5) virou o contrato SQL [[007-Ordens-Compra-Estruturada]]. Este documento continua sendo a referência de arquitetura/racional — os contratos são a versão formal, auto-contida, para quem for implementar cada lado.

## 1. Princípios gerais (valem para os 3 fluxos)

1. **Polling REST, sem webhook, sem tempo real** — mesmo padrão já provado em produção no pipeline ELT Omie→av-hub. Intervalo de 1 a 5 minutos (faixa definida na DEC-2; o valor exato por fluxo fica na seção de cada um).
2. **Cada sistema é dono dos próprios dados, e só expõe leitura por polling** — nenhum dos 3 fluxos é um POST de um sistema para o outro. Quem tem o dado expõe um endpoint `GET .../?alterado_desde=&codigo_empresa=`; quem precisa do dado faz o polling e projeta localmente. **(atualizado em 07/10, conferido no código)** Esse princípio **não vale mais para a requisição de compra**: o contrato 34 é um **`PUT` do MES para o av-hub** (`/compras/requisicoes/origem/{id_origem}`), enviado por uma fila de saída (outbox) do MES com retentativa — o MES **empurra**, o hub não puxa (o 003 foi substituído). Idempotência do PUT: por `id_origem` (id do item da requisição). Os demais fluxos seguem leitura (GET) por polling, mais o `POST /pedidos_liberados/{n}/importado` do contrato 26 (confirmação de importação). Mesma filosofia de "colunas protegidas" já usada no [[Omie-ELT-Pipeline]] e no contrato de API 001.
3. **`codigo_empresa` é obrigatório em todo payload dos 3 fluxos** — implicação direta da DEC-1 (vínculo Fábrica↔Filial por pedido, não fixo): nenhum dos dois lados pode inferir a filial a partir da Fábrica, o `codigo_empresa` do `Pedido`/requisição de origem precisa viajar explícito em cada evento.
4. **Autenticação por `x-api-key`**, reaproveitando o mesmo mecanismo que `api-acos-vital` já usa (`apiKeyAuth.js`, chave validada contra lista no `.env`). **Recomendação para resolver G-15** (ver [[Perguntas-em-Aberto-Consolidadas]]): cada direção ganha sua própria chave —
   - `MES_API_KEY` (usada pelo job do av-hub para chamar o MES — fluxos 1 e 3)
   - `AVHUB_API_KEY` (usada pelo job do MES para chamar o av-hub — fluxo 2)

   **(atualizado em 07/10, conferido no código do MES)** Os nomes reais são outros e há uma terceira chave: `MES_API_KEY` (hub → MES, rotas 003/005 do MES — confere); **`API_KEY`** (no lugar de `AVHUB_API_KEY`: o MES lê o hub — carteira, `/pedido_venda_itens`, `/pedidos_liberados`, `/produtos`, `/unidades` e `/compras/requisicoes/eventos`, com `API_URL`); **`AVHUB_MES_INTEGRACAO_KEY`** (só o `PUT` do 34; no hub é a lista `MES_INTEGRACAO_KEYS`). Há ainda `MES_INTERNAL_API_KEY` (BFF do app-pcp → `/auth/azure`, sem relação com o av-hub). Variáveis de ritmo: `AVHUB_ENVIO_INTERVALO_SEG` (60), `AVHUB_EVENTOS_INTERVALO_MIN` (5), `AVHUB_REENVIO_IMPORTADO_MIN` (10, reenvio automático do "importado" do 26). **A chave do 34 só abre o PUT**, então o MES lê com chave de outro tipo (pendência L6). Os valores/ligação no ambiente real: **não verificados**.

   Chave por consumidor já é possibilidade técnica confirmada do lado av-hub (o `requestLogger` grava a chave mascarada); falta confirmar que `api-pcp` (MES) tem o mesmo tipo de middleware do lado dele — ver pergunta aberta 1 na seção 7.
5. **Idempotência por cursor + upsert, não por chave de idempotência em POST.** Como os 3 fluxos são só leitura (`GET`), a idempotência não depende de nenhum token especial: cada consumidor faz `UPSERT` (`INSERT ... ON CONFLICT DO UPDATE`) pela chave natural do registro (definida em cada fluxo abaixo), então reler a mesma janela de `alterado_desde` duas vezes (por retry, por relógio dessincronizado, por reprocessamento manual) nunca duplica linha — só reescreve o mesmo valor. O cursor salvo pelo consumidor é sempre o maior `updated_at`/`ocorrido_em` já visto com sucesso, nunca o horário local do job (evita perder eventos se o job atrasar).
6. **Exclusão** segue o mesmo padrão já resolvido no contrato de API 001 (G-13): `?incluir_deletados=true` traz de volta os registros removidos, com `deleted_at` preenchido, dentro do mesmo payload incremental — nenhum fluxo aqui precisa de um mecanismo de exclusão à parte.
7. **Nenhum dado comercial sensível cruza a fronteira sem necessidade.** Preço, condição de pagamento e fornecedor nascem e ficam no av-hub; o MES só recebe o mínimo para conferência (mesma filosofia já descrita em [[Fluxo-Compras-Completo]], C7).

## 2. Fluxo 1 — Requisição de compra (MES → av-hub)

> **(atualizado em 07/10)** Fluxo 1 **substituído pelo contrato 34** ([[34-Requisicoes-MES-Empurra-para-o-Hub]]): o MES empurra por `PUT`, não é puxado por polling. O `GET /requisicoes-compra` abaixo ainda existe no MES, sem consumidor. Os marcos de volta vêm pelo 35 ([[35-Compras-Marcos-Requisicao-para-MES]]). Tabela de estado no topo desta nota.

**Quem expõe:** MES (`api-pcp`). **Quem consome:** av-hub (job de polling em `api-acos-vital`), alimenta a tarefa E1 (caixa de entrada de requisições).

Corresponde à conversa **C1** de [[Fluxo-Compras-Completo]]: o PCP conclui, pelo [[Modelo-Destinacao-Item]], que um item não tem estoque e precisa de compra.

> **Gatilho decidido em 24/09/2026** ([[Encaixe-Estoque-Revenda-no-PCP]]): a requisição nasce **automaticamente quando o parcial entra no setor Compras** do roteiro da fábrica Revenda. Por isso `origem.id_item_parcial` passa a vir **sempre preenchido** na requisição reativa (só fica `null` na preventiva, de ponto de pedido — Fase D). O parcial fica parado no setor Compras até o recebimento (Fluxo 2 + D6) liberar.

### `GET /requisicoes-compra?alterado_desde=&codigo_empresa=&incluir_deletados=`

**Response 200** (array):
```json
[
  {
    "id_requisicao": "uuid",
    "codigo_empresa": "uuid-da-unidade",
    "origem": { "id_pedido": "uuid-ou-null", "id_item_parcial": "uuid-ou-null" },
    "codigo_produto_omie": "12345678",
    "descricao_material": "Chapa xadrez 1/8 1200x3000",
    "quantidade": 500.000,
    "unidade": "KG",
    "prazo_necessario": "2026-10-15",
    "restricao_acabado": "ACABADO | NAO_ACABADO | null",
    "observacao": "texto livre do PCP, opcional",
    "status": "ABERTA | EM_COTACAO | ATENDIDA | CANCELADA",
    "ocorrido_em": "2026-10-01T14:32:00Z",
    "updated_at": "2026-10-01T14:32:00Z",
    "deleted_at": null
  }
]
```

**Intervalo de polling:** 5 min (fluxo não é urgente — o comprador trabalha em lote, não item a item).

**Chave natural (upsert no av-hub):** `(codigo_empresa, id_requisicao)`.

**Status da requisição** é escrito só pelo MES (coluna 100% dele — ver dono de cada coluna, seção 4); quando o comprador do av-hub fecha a compra (E2), isso não altera o `status` desta requisição diretamente — o av-hub sinaliza atendimento pelo Fluxo 2 (referência da OC), e cabe ao MES marcar `ATENDIDA` ao reconhecer a OC referenciada. **Isso é uma decisão nova deste documento, não estava fechada antes — ver pergunta aberta 2.**

## 3. Fluxo 2 — Referência da Ordem de Compra (av-hub → MES)

> **(atualizado em 07/10)** Contrato **004 inexistente nos dois lados** (conferido no código). Hoje o pedido de compra entra no MES por registro manual (`PATCH /compras/requisicoes/:id/compra`), e o Recebimento confere contra a **NF**, não contra uma OC do hub ([[App-PCP-Recebimento-Conferencia]]).

**Quem expõe:** av-hub (`api-acos-vital`). **Quem consome:** MES (`api-pcp`), alimenta o Recebimento (tarefa D6/D7).

Corresponde à conversa **C7** de [[Fluxo-Compras-Completo]]: dispara só quando o material chega fisicamente na doca — não antes, e não no momento em que a OC é fechada. **Não trafega preço, fornecedor, condição de pagamento nem `codigo_categoria`/`codigo_conta_corrente`** — só o necessário para a conferência.

### `GET /ordens-compra/referencia?alterado_desde=&codigo_empresa=&incluir_deletados=`

**Response 200** (array):
```json
[
  {
    "id_ordem_compra": "uuid",
    "codigo_empresa": "uuid-da-unidade",
    "numero_oc": "OC-2026-000123",
    "id_requisicao_origem": "uuid-ou-null",
    "itens": [
      {
        "id_item_oc": "uuid",
        "codigo_produto_omie": "12345678",
        "quantidade_esperada": 500.000,
        "unidade": "KG",
        "flag_acabado": "ACABADO | NAO_ACABADO"
      }
    ],
    "previsao_chegada": "2026-10-20",
    "updated_at": "2026-10-18T09:00:00Z",
    "deleted_at": null
  }
]
```

**Intervalo de polling:** 5 min (o gatilho real é a chegada física na doca, detectada pelo Recebimento no MES, não pela leitura em si — a latência de 5 min não atrasa nada no caminho crítico).

**Chave natural (upsert no MES):** `(codigo_empresa, id_ordem_compra)`; itens por `(id_ordem_compra, id_item_oc)`.

**Pré-requisito ainda não resolvido:** este endpoint pressupõe que o av-hub já tem uma tabela própria para a OC estruturada (fechada pelo comprador na tarefa E2) — **essa tabela ainda não tem contrato SQL escrito**. Não confundir com o contrato SQL 004 (`core_vendas_faturamento.pedidos_compras`), que é um espelho read-only do histórico de pedidos de compra do **Omie** (extração do pipeline ELT) — propósito diferente: aquele é leitura de dado fiscal já existente lá fora, este é a OC que o **próprio av-hub decide e cria** (E2), ainda sem lugar para morar no schema. Ver pergunta aberta 3.

## 4. Fluxo 3 — Status por item (MES → av-hub)

> **(atualizado em 07/10)** A rota `GET /itens/status` **existe no MES** (`901f9bb`), mas **não há consumidor no hub** (nem tabela de projeção). O vocabulário `etapa` abaixo é o do rascunho; no código é derivado do tipo do setor.

**Quem expõe:** MES (`api-pcp`). **Quem consome:** av-hub (job de polling), alimenta o Portal do Vendedor (tarefa E3) e a Carteira do PCP.

Corresponde à conversa **C19** de [[Fluxo-Compras-Completo]] e ao ponto de integração citado em [[AV-Hub-Portal-Vendedor-Plano]] (etapa por item, hoje pendente). Endpoint já nomeado no [[Cronograma-2-Meses]] (tarefa F3): `/itens/status?alterado_desde=`.

### `GET /itens/status?alterado_desde=&codigo_empresa=&incluir_deletados=`

**Response 200** (array):
```json
[
  {
    "id_item_parcial": "uuid",
    "codigo_empresa": "uuid-da-unidade",
    "id_pedido_venda_origem": "uuid-ou-null",
    "codigo_produto_omie": "12345678",
    "etapa": "compras.requisicao | compras.fechamento | recebimento.conferencia | recebimento.pesagem | qualidade.quarentena | qualidade.inspecao | fabrica.espera | fabrica.execucao | estoque.reservado | qualidade.reprovado | pcp.retorno",
    "quantidade_na_etapa": 120.000,
    "ocorrido_em": "2026-11-05T16:10:00Z",
    "updated_at": "2026-11-05T16:10:00Z",
    "deleted_at": null
  }
]
```

**Intervalo de polling:** 1 a 2 min (é o fluxo com maior valor de frescor — o vendedor olha a etapa do pedido em tempo quase real).

**Chave natural (upsert no av-hub):** `(codigo_empresa, id_item_parcial, etapa, ocorrido_em)` — um item pode passar pela mesma etapa mais de uma vez (ex.: `pcp.retorno` depois de reprovação), então a chave de upsert **não pode** ser só `(id_item_parcial)`; precisa incluir `ocorrido_em` para não sobrescrever o histórico de transições com a leitura mais recente. O av-hub guarda a **etapa atual** derivada do maior `ocorrido_em` por item, mas a tabela local mantém todas as linhas (mesmo princípio de log imutável do [[Rastreabilidade-e-SLA-de-Eventos]] — ver observação abaixo).

> **Relação com a proposta de rastreabilidade completa ([[Rastreabilidade-e-SLA-de-Eventos]]):** aquele documento propõe substituir este endpoint por um feed de eventos mais genérico (`origem`, `ator`, `autorizado_por`, `passou_para` etc.), cobrindo Compras, Comercial, Recebimento, Qualidade e Estoque, não só Fabricação/Recebimento. Este documento **não implementa essa versão completa** — ela foi conscientemente movida para a S5 (19/11–18/12, ver [[Cronograma-2-Meses]] seção 3.1), para não estourar a folga de 9% do plano de 2 meses. O formato de `/itens/status` acima já nasce **compatível por construção** com essa evolução: `etapa`, `ocorrido_em` e a chave composta acima podem crescer para o envelope completo de evento (`ator`, `autorizado_por`, `setor`, `passou_para`) por adição de coluna, sem mudar a forma de paginação/cursor nem quebrar o que for implementado agora. Isso é a leitura do "mínimo recomendado" da seção "Impacto no cronograma" daquele documento.

## 4b. Fluxo 4 — Pedidos liberados pelo vendedor (av-hub → MES) — acrescentado em 28/09/2026

Mesmo princípio 2 (quem tem o dado expõe, quem precisa faz polling): o av-hub expõe
`GET /pedidos_liberados?alterado_desde=&codigo_empresa=` com **só** os pedidos em que o vendedor já
marcou o acompanhamento da Qualidade; o MES troca a origem da Carteira (hoje `/vendas_planilha`) por
ele, lê os itens em `/pedidos_liberados/{numero}/itens` (409 se não liberado) e confirma a
importação em `POST /pedidos_liberados/{numero}/importado`. Contrato completo:
[[26-Vendas-Liberacao-Pedido]].

## 5. Tabelas novas necessárias no av-hub (ainda sem contrato SQL)

| Tabela proposta | Motivo | Bloqueia |
|---|---|---|
| `core_vendas_faturamento.ordens_compra_v1` (nome provisório) + itens | Suporte à OC estruturada fechada pelo comprador (E2) e ao Fluxo 2 deste documento. **Não é o mesmo dado do contrato SQL 004** (aquele é espelho read-only do Omie) — precisa de contrato SQL próprio, a escrever depois que este F1 for aprovado. | E2, Fluxo 2 |
| `core_vendas_faturamento.itens_pedido_status` (nome provisório) | Projeção local do Fluxo 3, para o Portal do Vendedor ler sem re-pollar o MES a cada carregamento de tela. | E3, Fluxo 3 |

## 6. Numeração de contrato (para depois da aprovação)

Quando este rascunho for aprovado por Robert e Gustavo, os 3 fluxos viram contratos de API formais em [[Indice-Contratos]] (a numeração de contrato de API está em `003` — o `001` é o filtro incremental já aplicado, o `002` foi rejeitado):

- **003 — Requisição de compra** (MES expõe, av-hub consome)
- **004 — Referência da OC** (av-hub expõe, MES consome) — também precisa do contrato SQL das tabelas da seção 5
- **005 — Status por item** (MES expõe, av-hub consome)

## 7. Perguntas em aberto (bloqueiam a aprovação final do F1)

1. **`api-pcp` (MES) tem hoje um middleware equivalente a `apiKeyAuth.js`?** Hoje não existe nenhuma integração de escrita ou leitura entre av-hub e MES em nenhuma direção (confirmado em [[MES-Arquitetura-Decisoes]] e no contrato de API 002 rejeitado) — então os endpoints dos Fluxos 1 e 3 (expostos pelo MES) provavelmente precisam desse middleware **criado do zero**. Levar para o Robert. **(atualizado em 07/10)** Resolvida: o `api-pcp` tem guarda de chave nas rotas 003/005 (`MES_API_KEY`), e o MES já usa chaves nos dois sentidos (`API_KEY`, `AVHUB_MES_INTEGRACAO_KEY`); a restrição por rota da chave que o MES usa para ler segue aberta (L6).
2. **Quem marca a requisição como `ATENDIDA`, e quando?** Proposta deste documento (seção 2): o MES marca, ao reconhecer no Fluxo 2 que `id_requisicao_origem` de uma OC referenciada aponta para ela. Isso ainda não foi validado com Robert/Gustavo — é a única regra de negócio nova introduzida por esta spec, não uma decisão já tomada em outro lugar do vault.
3. **Nome e schema definitivos da tabela de OC estruturada (seção 5)** — este documento propõe `ordens_compra_v1` só como placeholder; precisa virar contrato SQL formal, dono Nathan/Gustavo, antes de F2 (19/10) começar, já que F2 depende do Fluxo 2 estar com tabela real.
4. **Intervalo exato de polling por fluxo** (5 min / 5 min / 1-2 min, propostos acima) — DEC-2 só fixou a faixa (1 a 5 min), não o valor por fluxo; confirmar com Gustavo se a infraestrutura de jobs aguenta o fluxo 3 no piso da faixa.
5. **Paginação:** nenhum payload acima define tamanho de página. Mesmo padrão do pipeline ELT (`nPagina`/`nRegPorPagina`) deveria se aplicar aqui também, mas não foi especificado — confirmar convenção de paginação com Gustavo antes de implementar F2/F3.

## Ver também
- [[Chaves-de-Integracao-AvHub-MES-Pipeline]]
- [[App-PCP-Recebimento-Conferencia]]
- [[34-Requisicoes-MES-Empurra-para-o-Hub]] e [[35-Compras-Marcos-Requisicao-para-MES]]
- [[MES-Arquitetura-Decisoes]] — DEC-2, a decisão de mecanismo que esta spec detalha
- [[Decisoes-Chave-ERP]]
- [[Fluxo-Compras-Completo]] — conversas C1, C7, C19, de onde os 3 fluxos vêm
- [[Rastreabilidade-e-SLA-de-Eventos]] e [[Campos-e-API-para-Rastreabilidade]]
- [[Perguntas-em-Aberto-Consolidadas]] (G-15)
- [[Cronograma-2-Meses]] (F1, F2, F3, E1, E2, E3)
- [[Indice-Contratos]]
- [[Estoque-Modelo-Dados]]
