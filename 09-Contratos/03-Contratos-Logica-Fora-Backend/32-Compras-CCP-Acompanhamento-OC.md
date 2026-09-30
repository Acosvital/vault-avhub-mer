---
tags: [contrato-logica, contrato-sql, contrato-api, compras, ccp]
criado: 2026-09-30
status: proposta
---

# Contrato 32 — Compras: acompanhamento da OC pelo CCP (confirmação, prazo, despacho, renegociação)

**Criado em:** 30/09/2026 · **Para:** DBA (Gustavo) + backend (`api-acos-vital`) · **SQL + API**

Origem: etapa "CCP ↔ Fornecedor" (C5b–C6e) de [[Fluxo-Compras-Completo]]. O CCP acompanha a OC depois que o comprador a emitiu: confirma com o fornecedor, cobra prazo, registra o despacho e leva renegociações ao comprador. O fornecedor **não** acessa o sistema — quem digita é sempre o CCP. Tela prevista: tela própria `/compras/followup` (slug `followup`; tela 3.6 de [[Fluxograma-Telas-por-Bloco]]).

Usa a OC do [[13-Compras-Backend-Consolidado]] (`ordens_compra`, com `data_previsao_chegada`) e a view unificada do [[15-Compras-Historico-Unificado]].

---

## 1. Por quê

Hoje o av-hub só guarda a `data_previsao_chegada` da OC, preenchida na emissão. Não guarda se o fornecedor confirmou o pedido, quando despachou, quem ligou para quem, nem por que a data mudou. O acompanhamento acontece por telefone/e-mail/WhatsApp e some. Sem registro, ninguém vê o que já foi cobrado, e o comprador não sabe que o fornecedor pediu mudança.

**O que o av-hub não vai fazer:** somar, filtrar, ordenar por atraso nem montar o histórico no navegador. O banco entrega a fila pronta e o histórico ordenado.

## 2. Regras de negócio

1. **Quem escreve:** só perfil com a tela `followup` (slug igual ao último segmento da rota `/compras/followup`), **conferido no backend** (não só escondido no menu). `pode_editar` = CCP grava confirmação, despacho, contatos e ocorrências; `pode_aprovar` = decide ocorrência (o comprador da OC ou o admin; o backend ainda confere que é o comprador daquela OC). `pode_visualizar` = lê a fila e o detalhe.
2. **O CCP não altera a OC** (preço, quantidade, fornecedor). Ele só grava acompanhamento, contatos e ocorrências, e **atualiza `ordens_compra.data_previsao_chegada`** ao registrar um contato com previsão nova (na mesma transação, com `previsao_anterior` guardada no contato).
3. **Mudança de preço, quantidade ou condição** é decisão do **comprador** da OC: a ocorrência nasce `aberta` e só o comprador (ou admin) a `aprova`/`recusa`. A correção da OC em si continua pelo fluxo normal de OC; o acompanhamento só registra a decisão.
4. **Contatos são histórico:** só inserir, nunca editar nem apagar (correção = novo contato).
5. **Só OC `aprovada`** entra na fila do CCP (rascunho, aguardando aprovação e cancelada, não).
6. **Atraso** = OC aprovada, com saldo a receber e `data_previsao_chegada` anterior a hoje (fuso de São Paulo). Ver pergunta P1 sobre de onde vem o "saldo a receber".
7. **Confirmação:** `pendente` (padrão) → `confirmada` ou `contraproposta`. Contraproposta obriga a abrir uma ocorrência.

## 3. O contrato de API

Todas com o usuário da sessão como autor (`created_by`), como já é nas OCs.

### 3.1 `GET /compras/acompanhamento` — a fila do CCP

Rota fixa, antes de `/:id`.

| Parâmetro | Regra |
|---|---|
| `codigo_empresa` | uuid, opcional |
| `situacao` | `todas` (padrão), `sem_confirmacao`, `atrasada`, `chega_7_dias`, `no_prazo`, `com_ocorrencia_aberta` |
| `busca` | número da OC, número do pedido no fornecedor ou nome do fornecedor |
| `codigo_comprador` | uuid, opcional |
| `limit`, `offset` | paginação (padrão 50) |

Ordem: **atrasadas primeiro (mais atrasada no topo)**, depois por `data_previsao_chegada` crescente; sem previsão por último.

```json
{
  "itens": [{
    "id_ordem_compra": "…", "numero_pedido": "1234", "codigo_empresa": "…",
    "nome_fornecedor": "BENAFER", "nome_comprador": "LINDAYANE RODRIGUES",
    "valor_total_brl": 48210.5, "tipo_frete": "FOB",
    "data_previsao_chegada": "2026-09-22", "dias_atraso": 8,
    "confirmacao_status": "confirmada", "despachada": false,
    "ocorrencias_abertas": 1,
    "ultimo_contato_em": "2026-09-28T14:10:00-03:00", "ultimo_contato_resumo": "Disse que sai sexta"
  }],
  "total": 87,
  "resumo": { "sem_confirmacao": 12, "atrasadas": 30, "chegam_7_dias": 9, "com_ocorrencia_aberta": 4 }
}
```

`resumo` conta o conjunto filtrado por `codigo_empresa`/`codigo_comprador`, **sem** o filtro de `situacao` (para os cartões da tela não zerarem ao clicar).

### 3.2 `GET /compras/ordens/{id}/acompanhamento` — detalhe

```json
{
  "id_ordem_compra": "…",
  "confirmacao_status": "contraproposta",
  "confirmado_em": "2026-09-24T10:02:00-03:00", "confirmado_por_nome": "…",
  "despacho": { "despachado_em": "2026-09-27", "nf_fornecedor": "45871", "transportadora": "Rodonaves" },
  "contatos": [{ "id": "…", "tipo": "cobranca_prazo", "canal": "telefone", "falou_com": "Sr. Paulo",
                 "resumo": "Disse que sai sexta", "previsao_anterior": "2026-09-22", "previsao_nova": "2026-10-03",
                 "created_at": "…", "nome_criado_por": "…" }],
  "ocorrencias": [{ "id": "…", "tipo": "mudanca_preco", "descricao": "…", "proposta_fornecedor": "…",
                    "status": "aberta", "decidido_por_nome": null, "decidido_em": null, "decisao_observacao": null,
                    "created_at": "…", "nome_criado_por": "…" }]
}
```

`contatos` do mais novo para o mais antigo. Se a OC nunca foi acompanhada, devolve o padrão (`pendente`, listas vazias), **não 404**. OC de outra origem que não `av-hub`, ou inexistente: 404.

### 3.3 `PUT /compras/ordens/{id}/acompanhamento` — confirmação e despacho

Corpo, todos opcionais (só o que veio é alterado):

```json
{ "confirmacao_status": "confirmada", "despachado_em": "2026-09-27", "nf_fornecedor": "45871", "transportadora": "Rodonaves" }
```

- `confirmacao_status` só aceita `confirmada` ou `contraproposta` (voltar a `pendente` = 400).
- `contraproposta` sem ocorrência aberta na OC → 400 (abrir antes, ou mandar no mesmo corpo `ocorrencia` — ver 3.5).
- `despachado_em` não pode ser futuro (fuso SP). `nf_fornecedor` e `transportadora`: texto, até 60 e 120 caracteres.
- OC não aprovada → 409.

### 3.4 `POST /compras/ordens/{id}/contatos` — registrar contato

```json
{ "tipo": "cobranca_prazo", "canal": "telefone", "falou_com": "Sr. Paulo",
  "resumo": "Disse que sai sexta", "previsao_nova": "2026-10-03" }
```

- `tipo`: `confirmacao`, `cobranca_prazo`, `despacho`, `renegociacao`, `outro`. `canal`: `telefone`, `email`, `whatsapp`, `outro`. `resumo` obrigatório (1 a 1000 caracteres).
- `previsao_nova` opcional. Se vier e for diferente da atual: a API grava a atual em `previsao_anterior` e **atualiza `ordens_compra.data_previsao_chegada` na mesma transação**. Data anterior a hoje → 400.
- Resposta: o contato criado, mais `data_previsao_chegada` atual da OC.

### 3.5 `POST /compras/ordens/{id}/ocorrencias` e `PATCH /compras/ocorrencias/{id}`

Criar (CCP):

```json
{ "tipo": "mudanca_preco", "descricao": "Aço subiu 4%", "proposta_fornecedor": "Novo preço R$ 6,15/kg" }
```

`tipo`: `atraso`, `entrega_parcial`, `mudanca_preco`, `mudanca_quantidade`, `mudanca_prazo`, `sem_confirmacao`, `nao_entrega`. Nasce `aberta`.

Decidir (só o comprador da OC ou admin; senão 403):

```json
{ "status": "aprovada", "decisao_observacao": "Aceito, abrir correção da OC" }
```

`status`: `aprovada`, `recusada`, `resolvida`. Só ocorrência `aberta` muda (senão 409). `nao_entrega` aprovada **não cancela a OC sozinha**: o cancelamento continua sendo a ação normal de OC (evita cancelamento por engano vindo de uma tela de follow-up).

### 3.6 Onde mais aparece (leitura, sem endpoint novo)

- `GET /compras/ordens/{id}` (detalhe da OC) ganha `acompanhamento`: `confirmacao_status`, `despachado_em`, `ocorrencias_abertas`, `ultimo_contato_em`.
- `GET /compras/ordens` (lista) ganha `confirmacao_status` e `ocorrencias_abertas` por linha.

## 4. SQL (para o DBA) — resumo

DDL completo no **apêndice A**. Três tabelas novas em `core_vendas_faturamento`, sem tocar nas existentes:

| Tabela | Papel |
|---|---|
| `ordens_compra_acompanhamento` | 1 linha por OC: confirmação e despacho |
| `ordens_compra_contatos` | histórico só de inserção dos contatos com o fornecedor |
| `ordens_compra_ocorrencias` | atraso, parcial, mudança e não-entrega, com a decisão do comprador |

Além disso: cadastro da tela `followup` em `auth.telas` (e permissão para o perfil do CCP) e uma view `vw_compras_acompanhamento` para a fila (3.1), que o DBA/backend montam sobre `vw_ordens_compra_historico` (contrato 25) restrita a `origem = 'av-hub'` e `status = 'aprovado'`.

## 5. Perguntas em aberto

| # | Pergunta | Quem responde |
|---|---|---|
| **P1** | **Saldo a receber:** para OC do av-hub, de onde vem "chegou ou não"? O recebimento hoje é lançado no Omie (`pedidos_compras_itens.quantidade_recebida`, do espelho). Se a OC do av-hub já espelha no Omie, o backend liga as duas pelo `numero_pedido_omie`? Sem essa ligação a fila não sabe tirar da lista a OC que já chegou. | Gustavo / backend |
| **P2** | O CCP acompanha só OC criada no av-hub, ou também o **pedido feito direto no Omie** (5.434 no espelho)? Proposta: **só av-hub** nesta versão (o histórico do Omie continua só leitura). | Nathan |
| **P3** | Prazo para destacar OC **sem confirmação** do fornecedor (ex.: 2 dias úteis depois da emissão). Parâmetro em `parametros_compras`? | Nathan / CCP |
| **P4** | Quando a previsão nova atrasa um pedido de venda ligado à OC (vínculo do contrato 14): quem é avisado, PCP ou vendedor, e como? Fora deste contrato, mas define se o registro precisa de um campo a mais. | Nathan / Robert |
| **P5** | Quem é o "perfil CCP" hoje em `auth.perfis`? Existe ou é criado? | Nathan |
| **P6** | Transportadora do despacho é texto livre ou vem de `core.parceiros` (como a da OC)? Proposta: texto livre, porque muitas vezes é a do fornecedor (CIF). | Nathan |

## 6. Depois de aplicado (av-hub)

1. **Front construído em 30/09/2026** (av-hub, branch `feat/compras-ccp-followup`, ainda não mergeada): tela **Follow-up (CCP)** em `/compras/followup` com cartões do `resumo`, fila (3.1) com filtros e busca, painel lateral da OC com contatos, confirmação/despacho e ocorrências (3.2 a 3.5). Padrão da skill `interface-hub`.
2. Menu e permissão: tela `followup` em `auth.telas` (pai: Compras); botões de escrita escondidos para quem só lê (o backend continua sendo quem decide).
3. Detalhe da OC (`OrdemDetalhe`) passa a mostrar o bloco de acompanhamento em leitura.
4. Rotas do BFF (`app/api/compras/acompanhamento/…`) repassam ao backend com o token da sessão, como as demais de Compras.

## 7. Aceite

- [ ] DBA revisou e aplicou o apêndice A (teste, depois produção).
- [ ] Backend implementou 3.1 a 3.6 e testou as regras (permissão, previsão na mesma transação, 403 na decisão, 404/409).
- [ ] Perguntas P1 e P2 respondidas (definem o escopo da fila).
- [ ] Front construído sobre o que existir.

---

## Apêndice A — SQL proposto (DBA)

> Proposta. Nomes e tipos seguem o padrão de `ordens_compra` (contrato 007): `uuid` como chave, `created_by` = `auth.usuarios.id`. O DBA ajusta ao que a tabela real usa (ver topo do 007 sobre diferenças entre DDL e aplicado).

```sql
-- 1) Acompanhamento: uma linha por OC (criada sob demanda no primeiro registro)
CREATE TABLE core_vendas_faturamento.ordens_compra_acompanhamento (
  id_ordem_compra   uuid PRIMARY KEY
                    REFERENCES core_vendas_faturamento.ordens_compra(id) ON DELETE CASCADE,
  confirmacao_status text NOT NULL DEFAULT 'pendente'
                    CHECK (confirmacao_status IN ('pendente','confirmada','contraproposta')),
  confirmado_em     timestamptz,
  confirmado_por    uuid REFERENCES auth.usuarios(id),
  despachado_em     date,
  nf_fornecedor     varchar(60),
  transportadora    varchar(120),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- 2) Contatos com o fornecedor: só inserção
CREATE TABLE core_vendas_faturamento.ordens_compra_contatos (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  id_ordem_compra   uuid NOT NULL
                    REFERENCES core_vendas_faturamento.ordens_compra(id) ON DELETE CASCADE,
  tipo              text NOT NULL
                    CHECK (tipo IN ('confirmacao','cobranca_prazo','despacho','renegociacao','outro')),
  canal             text NOT NULL
                    CHECK (canal IN ('telefone','email','whatsapp','outro')),
  falou_com         varchar(120),
  resumo            text NOT NULL CHECK (char_length(resumo) BETWEEN 1 AND 1000),
  previsao_anterior date,
  previsao_nova     date,
  created_by        uuid REFERENCES auth.usuarios(id),
  created_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_oc_contatos_oc ON core_vendas_faturamento.ordens_compra_contatos
  (id_ordem_compra, created_at DESC);

-- Só inserção: bloqueia UPDATE e DELETE direto (o ON DELETE CASCADE da OC continua valendo)
CREATE FUNCTION core_vendas_faturamento.fn_oc_contatos_imutavel() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'ordens_compra_contatos é histórico: só inserção';
END $$;
CREATE TRIGGER tg_oc_contatos_imutavel
  BEFORE UPDATE ON core_vendas_faturamento.ordens_compra_contatos
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_oc_contatos_imutavel();

-- 3) Ocorrências: atraso, parcial, mudança, não-entrega + decisão do comprador
CREATE TABLE core_vendas_faturamento.ordens_compra_ocorrencias (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  id_ordem_compra     uuid NOT NULL
                      REFERENCES core_vendas_faturamento.ordens_compra(id) ON DELETE CASCADE,
  tipo                text NOT NULL
                      CHECK (tipo IN ('atraso','entrega_parcial','mudanca_preco','mudanca_quantidade',
                                      'mudanca_prazo','sem_confirmacao','nao_entrega')),
  descricao           text NOT NULL CHECK (char_length(descricao) BETWEEN 1 AND 1000),
  proposta_fornecedor text,
  status              text NOT NULL DEFAULT 'aberta'
                      CHECK (status IN ('aberta','aprovada','recusada','resolvida')),
  decidido_por        uuid REFERENCES auth.usuarios(id),
  decidido_em         timestamptz,
  decisao_observacao  text,
  created_by          uuid REFERENCES auth.usuarios(id),
  created_at          timestamptz NOT NULL DEFAULT now(),
  -- decisão só existe junto com status diferente de 'aberta'
  CONSTRAINT ck_oc_ocorrencia_decisao
    CHECK ((status = 'aberta') = (decidido_em IS NULL))
);
CREATE INDEX ix_oc_ocorrencias_oc ON core_vendas_faturamento.ordens_compra_ocorrencias
  (id_ordem_compra, created_at DESC);
CREATE INDEX ix_oc_ocorrencias_abertas ON core_vendas_faturamento.ordens_compra_ocorrencias
  (id_ordem_compra) WHERE status = 'aberta';

-- 4) Tela e permissão (ajustar ao formato real de auth.telas)
-- INSERT INTO auth.telas (...) VALUES (... 'followup', 'Follow-up (CCP)', '/compras/followup' ...);
```

A view `vw_compras_acompanhamento` fica a cargo do DBA/backend porque depende da resposta de **P1** (como o saldo a receber é obtido).
