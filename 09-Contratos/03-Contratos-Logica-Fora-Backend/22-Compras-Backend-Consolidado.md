# Contrato — Compras: tudo o que falta no BACKEND (banco + API)

**Criado em:** 23/09/2026 · **Revisado em:** 24/09/2026 · **Para:** DBA e backend (`api-acos-vital`)

**Este documento substitui, como lista de trabalho,** `ENVIAR - compras/01 - DBA - banco.md` e
`ENVIAR - compras/02 - API - backend.md`. Os contratos de detalhe continuam valendo como
referência (de-para campo a campo):
`ENVIAR - contrato-compras-omie-pedidocompra.md`, `ENVIAR - contrato-compras-pendencias-pos-backend.md`,
`ENVIAR - contrato-compradores-funcionario.md`, `ENVIAR - contrato-compras-cotacao-moeda-ptax.md` e
`ENVIAR - contrato-compras-projetos-omie.md`.

O que é da pipeline (extrair do Omie, enviar a OC, job da PTAX) está em
`ENVIAR - contrato-compras-pipeline.md`.

**Todo o SQL deste contrato foi aplicado e testado no banco local em 24/09/2026** (estrutura do
banco de teste de 23/09 + dados de produção), com a pipeline rodando de verdade contra o Omie.
Está pronto para rodar, na ordem, nos **Apêndices A a D**.

---

## Resumo: o que é de quem

| Item | O que é | Banco (DBA) | API (backend) | Testado no local |
|---|---|---|---|---|
| **B0** | Levar tudo para produção | aplicar as migrations do teste + Apêndices A–C | publicar a `develop` | — |
| **B1** | Espelho `pedidos_compras` | teste: 2 colunas (Apêndice B); produção: o B1 inteiro | models `bigint` + colunas novas | ✅ pipeline grava a observação do item |
| **B2** | Comprador em dois campos | depende da decisão | depende da decisão | — |
| **B3** | Número da OC/requisição | ✅ trigger sempre numera (Apêndice B) | tirar `numero_pedido` de `CAMPOS` | ✅ T1, T4, T9 |
| **B4** | Envio da OC ao Omie | colunas já existem | 3 rotas | — |
| **B5** | Nomes e dados na OC | IE da unidade (Apêndice B + C) | JOINs na listagem e no detalhe | IE preenchida do Omie |
| **B6** | Campos do PDF | ✅ colunas + cálculo por trigger (Apêndice B) | aceitar `observacao` do item e `numero_pedido_fornecedor` | ✅ T1 |
| **B7** | Catálogos do Omie | ✅ tabelas (Apêndice A) | 4 rotas de leitura | ✅ pipeline carregou os 4 |
| **B7b** | Parcelas pela condição | ✅ trigger (Apêndice B) | — | ✅ T2, T3, T5 |
| **B8** | Listagem, indicadores, limite | — | rotas `/resumo` e `/parametros` | — |
| **B9** | Permissões e histórico | ✅ histórico, cancelamento, tela (Apêndice B) | usar `pode_aprovar`; mandar `updated_by` | ✅ T6–T8 |
| **B13** | Furos de status (novo) | ✅ fechados na trigger (Apêndice B) | tratar o erro 23514 no PATCH | ✅ T6, T7 |

**Ordem para o banco de TESTE:** Apêndice A → Apêndice B → Apêndice C → rodar o Apêndice D (é só
teste, termina em `ROLLBACK`) e comparar com o resultado esperado. **Produção:** B0 primeiro.

---

## 0. O que já foi entregue (conferido em 23/09/2026, `develop` até o commit `8715549`)

| Item | Onde |
|---|---|
| Tabelas `requisicoes_compra`, `ordens_compra` (+ itens, parcelas), `parametros_compras`, régua de aprovação e valores por trigger | PR #273 |
| Renomes: `numero_pedido`, `id_requisicao`, `id_ordem_compra`; `codigo_comprador` obrigatório; `tipo_frete` com padrão CIF | `7918357` |
| Requisição: `id_origem` (idempotência do MES), `prazo_necessidade` obrigatório | `bf9d86a` |
| Número da OC e da requisição por trigger (contador por unidade), sem o `count + 1` | `8715549` |
| Fornecedor e transportadora só da unidade da OC (400) | `8715549` |
| Tabela `compradores` + `GET/PUT /compras/compradores`, `GET /{id}/sugestoes`; comprador resolvido pela sessão (bloqueio atrás de `COMPRAS_EXIGIR_VINCULO_COMPRADOR`) | `8715549` |
| `core.cotacoes_moeda` + `GET /cotacoes_moeda/atual` e `?data=`; OC guarda `cotacao_data`/`cotacao_origem` e confere a PTAX | `8715549` |
| Aprovar exige `aprovado_por` de usuário existente | `8715549` |
| Colunas do envio ao Omie na OC (`status_sincronizacao_omie`, `erro_sincronizacao_omie`, `codigo_pedido_omie`, `numero_pedido_omie`, `sincronizado_em`) e `auth.permissoes.pode_aprovar` | já no banco (dump de 23/09) |

### 0.1 Situação real dos bancos

Dumps de 23/09/2026 (produção 16:46, teste 16:58) e banco local depois dos Apêndices (24/09).

| Item | Teste | Produção | Local (24/09) |
|---|---|---|---|
| `ordens_compra` (+ itens, parcelas), `requisicoes_compra`, `parametros_compras`, triggers | ✅ | ❌ **nenhuma tabela de compras** | ✅ |
| `compradores`, `core.cotacoes_moeda` | ✅ | ❌ | ✅ |
| **B1** espelho: `bigint`, colunas novas, `pedidos_compras_parcelas` | ✅ **quase**: faltam `pedidos_compras_itens.codigo_item_integracao` e `.observacao` | ❌ ainda `INTEGER` | ✅ |
| **B3** número da OC/requisição | ✅ trigger + `contadores_documento` (`OC-000001` / `REQ-000001` por unidade), **mas aceita o número do corpo** | ❌ | ✅ sempre do contador |
| **B6** colunas do PDF + `core.unidades.inscricao_estadual` | ❌ | ❌ | ✅ |
| **B7** `condicoes_pagamento_compras` | ✅, **mas `descricao` e `lista_dias` em `varchar(30)` são curtas** | ❌ | ✅ `varchar(100)` |
| **B7** `core.projetos`, `core.contas_correntes` | ❌ | ❌ | ✅ |
| **B7** `core.categorias` por unidade, com marcações | ❌ (único pelo código no banco inteiro) | ❌ | ✅ |
| **B9** `ordens_compra_historico`, `cancelado_por/_em`, tela `compradores` | ❌ | ❌ | ✅ |

---

## 1. 🔴 Errado ou bloqueando (fazer primeiro)

### B0. Levar para PRODUÇÃO tudo o que já está no teste

O banco de produção (dump de 23/09/2026, 16:46) **não tem nenhuma tabela nova de compras**. Antes de
o av-hub de compras subir para produção, aplicar lá, na ordem: PR #273 (requisições, OCs, parcelas,
parâmetros, triggers), `7918357` (renomes + `codigo_comprador`), `bf9d86a` (`id_origem`),
`8715549` (compradores, cotações, `cotacao_data`/`cotacao_origem`, contador de números), o **B1
inteiro** (abaixo) e os **Apêndices A, B e C**. **Conferir depois com um dump** (a tabela 0.1 é o
gabarito) e rodar o Apêndice D.

### B1. `pedidos_compras` ainda quebra na primeira carga real (D5)

**No teste** falta só o que está no Apêndice B (duas colunas de item + índice). **Os models** da API
(`src/models/pedido_compra.js`, `pedido_compra_item.js`) continuam com `INTEGER` e sem as colunas
novas: atualizar. **Em produção**, o B1 inteiro abaixo.

Os códigos reais passam de 2.147.483.647: no pedido 46618, `nCodPed` 10467753709, `nCodFor`
10363934283, `nCodCompr` 10219958954, `nCodCC` 10364415646, `nCodProj` 9779703251, `nCodItem`
10467754866.

```sql
-- B1 inteiro (o que produção precisa; o teste já tem tudo menos as 2 colunas do Apêndice B)
ALTER TABLE core_vendas_faturamento.pedidos_compras
  ALTER COLUMN codigo_pedido_compra_omie TYPE bigint,
  ALTER COLUMN codigo_fornecedor         TYPE bigint,
  ALTER COLUMN codigo_comprador          TYPE bigint,
  ALTER COLUMN codigo_conta_corrente     TYPE bigint,
  ALTER COLUMN codigo_projeto            TYPE bigint,
  ALTER COLUMN contato                   TYPE varchar(100),   -- cContato é string100
  ADD COLUMN numero_pedido_fornecedor    varchar(30),         -- cNumPedido (≠ cNumero)
  ADD COLUMN incluido_em_omie            timestamptz,         -- dIncData + cIncHora
  ADD COLUMN codigo_condicao_pagamento   varchar(3),          -- cCodParc ("U10")
  ADD COLUMN quantidade_parcelas         integer,             -- nQtdeParc
  ADD COLUMN codigo_transportadora       bigint;              -- nCodTransp (código, não nome)

ALTER TABLE core_vendas_faturamento.pedidos_compras_itens
  ALTER COLUMN numero_item_omie     TYPE bigint,
  ALTER COLUMN codigo_local_estoque TYPE bigint,              -- vem como TEXTO no payload real; converter
  ADD COLUMN codigo_item_integracao varchar(20),              -- cCodIntItem: liga o item à OC do av-hub
  ADD COLUMN descricao              varchar(120),
  ADD COLUMN unidade                varchar(6),
  ADD COLUMN valor_desconto         numeric(14,2),            -- nDesconto é VALOR, não %
  ADD COLUMN valor_mercadoria       numeric(14,2),            -- nValMerc
  ADD COLUMN valor_total            numeric(14,2),            -- nValTot = nValMerc - nDesconto + nValorIpi
  ADD COLUMN quantidade_recebida    numeric(14,3),            -- nQtdeRec
  ADD COLUMN observacao             text,                     -- cObs do item (sai impresso)
  ADD COLUMN codigo_categoria       varchar(20);

CREATE INDEX idx_pedidos_compras_itens_cod_integracao
  ON core_vendas_faturamento.pedidos_compras_itens (codigo_item_integracao)
  WHERE codigo_item_integracao IS NOT NULL;

CREATE TABLE core_vendas_faturamento.pedidos_compras_parcelas (
  id               uuid PRIMARY KEY DEFAULT uuidv7(),
  id_pedido_compra uuid NOT NULL REFERENCES core_vendas_faturamento.pedidos_compras(id)
                     ON UPDATE CASCADE ON DELETE CASCADE,
  codigo_empresa   uuid NOT NULL REFERENCES core.unidades(id),
  numero_parcela   integer NOT NULL,        -- nParcela
  data_vencimento  date,                    -- dVencto
  valor            numeric(14,2),           -- nValor
  dias             integer,                 -- nDias
  percentual       numeric(9,5),            -- nPercent (vem 19.99999)
  tipo_documento   varchar(10),             -- cTipoDoc
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_pedidos_compras_parcelas_numero
  ON core_vendas_faturamento.pedidos_compras_parcelas (id_pedido_compra, numero_parcela);
```

`percentual_desconto` do item: remover ou deixar a pipeline calcular. `cfop`: o item do pedido de
compra do Omie não tem, vai ficar sempre nulo.

**Testado:** com as duas colunas, a pipeline grava a observação do item (573 de 1.370 itens têm;
no 46618, "100/ PÇS - ENTREGAR NO DIA 24/09/2026" e "191/ PÇS - …" em duas linhas). O
`codigo_item_integracao` só vem preenchido nos pedidos que o av-hub enviar (B4).

### B2. O comprador está em dois campos — decidir e tirar um

Hoje a OC tem **`codigo_comprador`** (uuid de `auth.usuarios`, **obrigatório** no POST desde
`7918357`) **e** **`id_comprador`** (FK para `compradores`, resolvido pela sessão desde `8715549`).

- O que o Omie precisa é o `nCodCompr`, e ele só sai de `id_comprador` → `compradores.codigo_comprador_omie`.
- O comentário do model diz que `codigo_comprador` existe para "um admin criar a OC em nome de outro
  comprador". **A regra combinada é o contrário: ninguém emite em nome de outro** (A3). O av-hub
  manda `codigo_comprador` = usuário da sessão, que é sempre igual a `created_by`.

**Proposta:** manter só `id_comprador` como "o comprador" e tirar a obrigatoriedade de
`codigo_comprador` (ou remover a coluna; `created_by` já diz quem emitiu). **Decisão do Nathan antes
de mexer.** (Por isso não está em nenhum apêndice.)

### B3. Número da OC e da requisição: sempre do contador, e fixo

- **Banco (Apêndice B):** a trigger passa a numerar **sempre**. O `numero_pedido` que vier no corpo
  é descartado (antes: "número informado explicitamente continua sendo respeitado"). Na requisição, um
  número que vier no corpo é o do MES (D4) e vai para a coluna nova **`numero_requisicao_mes`**; o
  `numero_requisicao` é sempre do contador. Isso mantém compatível quem ainda manda o número do MES
  em `numero_requisicao`. E **o número não muda depois de criado** (é a chave `cCodIntPed` no Omie):
  um UPDATE que tente trocar é ignorado.
- **API:** tirar `numero_pedido` da lista `CAMPOS` (não faz mais efeito, mas não deve parecer que faz)
  e aceitar `numero_requisicao_mes` no POST de requisições.
- **Formato:** `OC-000001` / `REQ-000001`, contador por unidade (`contadores_documento`), 6 dígitos.
  É esse texto que vai no `cCodIntPed` do Omie (até 20 caracteres, único dentro de cada conta).

### B4. Rotas para o envio da OC ao Omie (quem envia é a pipeline)

Toda OC fica `status_sincronizacao_omie = 'pendente'` para sempre. As **colunas já existem**; o envio
em si é da pipeline (contrato da pipeline, L4, **decisão em aberto**). O backend precisa dar a ela:

```
GET   /compras/ordens?status=aprovado&status_sincronizacao_omie=pendente&limit=
        → a fila de envio (com itens, parcelas, nomes e o comprador do Omie resolvido:
          codigo_comprador_omie de compradores)
PATCH /compras/ordens/{id}/sincronizacao
        body sucesso: { status: "sincronizado", codigo_pedido_omie, numero_pedido_omie }
        body falha:   { status: "erro", erro: "<description do omie_fail>" }
        → grava status_sincronizacao_omie, sincronizado_em = now(), erro_sincronizacao_omie
POST  /compras/ordens/{id}/reenviar
        → volta 'erro' para 'pendente' (botão "Reenviar ao Omie" na tela; só pode_editar)
```

O PATCH de sincronização **não pode** mexer em nada além desses campos.

---

## 2. 🟠 Falta para o fluxo fechar

### B5. Nomes e dados completos na OC (A1 + C1 ampliado)

Em `GET /compras/ordens` (listagem) e `GET /compras/ordens/{id}`, sempre com JOIN pelo
**`codigo_empresa` da OC** (o mesmo fornecedor tem código diferente em cada filial):

| Campo | Origem |
|---|---|
| `nome_fornecedor`, `cpf_cnpj_fornecedor` | `core.parceiros` (`codigo_parceiro_omie = codigo_fornecedor`) |
| `nome_transportadora` | `core.parceiros` pelo `codigo_transportadora` |
| `nome_comprador` | `compradores`: `COALESCE(nome_exibicao, nome)` pelo `id_comprador` |
| `nome_criado_por`, `nome_aprovado_por`, `nome_cancelado_por` | usuários `created_by`, `aprovado_por`, `cancelado_por` (B9) |
| `nome_projeto` | `core.projetos` pelo `codigo_projeto` |
| `descricao_categoria` | `core.categorias` pelo `codigo_categoria` **e** `codigo_empresa` |
| `descricao_conta_corrente` | `core.contas_correntes` pelo `codigo_conta_corrente` |
| `descricao_condicao_pagamento` | `condicoes_pagamento_compras` pelo `codigo_condicao_pagamento`, ex.: "30/40/50/60/70" |

**Só no detalhe** (para o PDF do fornecedor): `razao_social_fornecedor`,
`inscricao_estadual_fornecedor`, endereço do fornecedor (logradouro, número, complemento, bairro,
cidade, UF, CEP), `email_fornecedor`, `telefone_fornecedor`, e o **histórico** (B9).

E em `GET /unidades/{id}`: **`inscricao_estadual`** (sai no cabeçalho do pedido). A coluna é do
Apêndice B; o valor vem do Omie (`geral/empresas` → `ListarEmpresas` → `inscricao_estadual`) e está
no Apêndice C.

⚠️ Os códigos de catálogo da OC hoje são `varchar(60)` e podem ter **texto livre antigo** (antes dos
selects). O JOIN precisa ser LEFT e a tela mostra o código cru quando não achar.

### B6. Campos da OC para o PDF do fornecedor (D8/A9/C9)

**Banco (Apêndice B):**

- `ordens_compra_itens`: `observacao` (para o fornecedor, vai no `cObs` do item), `valor_desconto` e
  `valor_total_item`, **calculados por trigger** em cada linha e arredondados a centavos (como o
  `nValTot` do Omie).
- `ordens_compra`: `numero_pedido_fornecedor` (`cNumPedido`), `valor_mercadorias` e
  `valor_descontos` (trigger).
- **Mudança de regra no total:** `valor_total` passa a ser a **soma das linhas já arredondadas**. Antes
  era a soma sem arredondar, e o PDF podia mostrar itens que não somam o total por 1 centavo.

**API:** aceitar `observacao` no item (**incluir em `CAMPOS_ITEM`**) e `numero_pedido_fornecedor` no
cabeçalho (`CAMPOS`); o detalhe devolve os campos novos. **Não** aceitar `valor_desconto`,
`valor_total_item`, `valor_mercadorias` nem `valor_descontos` do cliente (são da trigger).

**No av-hub, a observação do item já existe na tela, desabilitada**, esperando esta coluna.

**Testado (T1):** 1.000 kg × R$ 5,04 com 1,5% → desconto 75,60, linha 4.964,40; 3 × R$ 333,333 →
1.000,00; OC: mercadorias 6.040,00, descontos 75,60, total 5.964,40.

### B7. Catálogos do Omie para os selects da OC

Hoje condição de pagamento, conta corrente e projeto são **texto livre**, e a categoria vem de
`/categorias` sem filtro nenhum. O Omie espera **códigos** (`cCodParc` "U10", `nCodCC`,
`nCodProj`, `cCodCateg` "2.01.03"). Todos são **por conta Omie (por unidade)**. A pipeline preenche
(contrato da pipeline, L5–L8); o backend cria as tabelas (**Apêndice A**) e as rotas de leitura.

| Catálogo | Tabela | Rota | Situação |
|---|---|---|---|
| Condição de pagamento | `core_vendas_faturamento.condicoes_pagamento_compras` | `GET /compras/condicoes-pagamento?codigo_empresa=` | tabela no teste (aumentar colunas); rota não existe |
| Projeto | `core.projetos` (nova) | `GET /projetos?codigo_empresa=&ativo=&q=` | não existe |
| Conta corrente | `core.contas_correntes` (nova) | `GET /contas_correntes?codigo_empresa=&ativo=&q=` | não existe |
| Categoria | `core.categorias` (existe, vazia) | `GET /categorias` (existe) | **precisa de unidade e filtro** |
| Local de estoque | `core.locais_estoque` (existe, contrato 005) | `GET /locais_estoque?codigo_empresa=&ativo=` | confirmar se a rota tem filtro por unidade |

Rotas: todas com `codigo_empresa`, `ativo` (padrão `true`), `q` (código ou descrição, sem acento),
ordem por código/descrição. Em `/categorias`, também `tipo=despesa` (só `conta_despesa`, não
`totalizadora`, não `nao_exibir`), que é o que a OC usa.

**Tamanhos conferidos no Omie real (24/09):** condições de pagamento com descrição e lista de dias de
até **71** caracteres (5 de 326 em Mogi; a doc do Omie fala em 30), por isso `varchar(100)`; contas
correntes até 40 (limite do próprio Omie); projetos até 56; categorias até 53; usuário do Omie
(`P000794537`) com 10, por isso `varchar(20)`.

**Testado:** 59 + 47 projetos, 107 + 13 contas correntes, 312 + 262 categorias e 326 + 40 condições
(Mogi + Uberaba), sem erro e sem duplicar ao rodar de novo; a trigger atualiza o `updated_at`. Os
códigos do 46618 viram os nomes do PDF do Omie: projeto 9779703251 = "16 - Revenda", conta
10364415646 = "01 - Boleto/Pix/TED", categoria `2.01.03` = "Compras de Materia Prima" (despesa, não
totalizadora; o grupo `2.01` é totalizador). Categorias de despesa lançáveis e ativas: 123 em Mogi e
120 em Uberaba, que é o que o select da OC deve listar.

### B7b. Parcelas da OC pela condição de pagamento

**Banco (Apêndice B).** Hoje as parcelas são sempre "partes iguais a cada 30 dias" e só são refeitas
quando o total muda. Passa a ser:

- Condição encontrada no catálogo da unidade → **uma parcela por dia de `lista_dias`, contada da data
  de previsão**, `calculo_provisorio = false`, e `quantidade_parcelas` vem do catálogo. É o que o
  Omie faz: no 46618, previsão 24/10 com U10 (30,40,50,60,70) → 23/11, 03/12, 13/12, 23/12, 02/01.
  Condição com lista vazia (`000` "A Vista") = uma parcela na data de previsão.
- Sem condição no catálogo (texto livre antigo) → o provisório de antes.
- As parcelas são refeitas também quando mudam a **condição**, a **data de previsão** ou a
  **quantidade**, não só o total. A última parcela leva o resto do arredondamento.

A API não grava parcelas (conferido na `develop`): nada a mudar lá.

**A confirmar no Omie (L10 da pipeline):** o que significa `nDiasParc` (`dias_deslocamento`); hoje é
ignorado.

### B8. Listagem, indicadores e limite (A5–A7)

```
GET /compras/ordens?q=           → q também busca no NOME do fornecedor (depende do B5)
GET /compras/requisicoes/resumo?codigo_empresa=  → { abertas, em_cotacao, atendidas, canceladas }
GET /compras/ordens/resumo?codigo_empresa=       → { aguardando_aprovacao, valor_aguardando_aprovacao_brl,
                                                     aprovadas, canceladas, pendentes_omie, com_erro_omie }
GET /compras/parametros?codigo_empresa=          → { limite_aprovacao }
```

As rotas `/resumo` **antes** de `/:id` (hoje `/compras/ordens/resumo` cai em `/:id` e responde
`400 "id deve ser um uuid"`). Com isso o av-hub deixa de baixar todas as OCs para somar os
indicadores.

### B9. Permissões e histórico (A8/D7)

**Banco (Apêndice B):**

- **Histórico de decisão:** tabela `ordens_compra_historico`, preenchida **por trigger** a cada
  mudança de status: de → para, valor em R$ no momento, motivo e quem. Aprovação automática (abaixo
  do limite) fica com `alterado_por` nulo e motivo "automática: valor abaixo do limite de aprovação".
- **Cancelamento:** `cancelado_por` e `cancelado_em`, carimbados pela trigger (`cancelado_por` =
  `updated_by`, se for um usuário que existe).
- **Tela `compradores`** em `auth.telas`, dentro de Compras.
- `auth.permissoes.pode_aprovar` **já existe** (teste e produção), mas **nenhum perfil tem marcado**.

**API:**

- Usar **`pode_aprovar`** para aprovar e cancelar OC (hoje o av-hub usa `pode_editar`, e quem cadastra
  pode aprovar). Marcar quem aprova é decisão do Nathan (sugestão: "Gerência de Compras").
- Mandar `updated_by` no PATCH de cancelamento (é de onde sai `cancelado_por`).
- Devolver o histórico no detalhe da OC.
- Só o administrador edita o vínculo do comprador (tela `compradores`).
- `aprovado_por`/`created_by`/`updated_by` vêm do corpo porque a API só conhece a `x-api-key`.
  Continua valendo o contrato de identidade propagada (`ENVIAR - contrato-permissoes-e-escopo-no-banco.md`).

### B13. Furos de status encontrados na revisão das triggers (novo, 24/09)

Lendo as triggers do teste e o `PATCH /compras/ordens/{id}` da `develop`:

1. **OC cancelada podia ser aprovada.** O PATCH só barra "já está nesse status", e a trigger só exige
   "passou por aguardando" **acima** do limite. Abaixo do limite, `cancelado → aprovado` passava.
   **Banco:** cancelada agora é final (erro `23514`, "OC cancelada não muda de status"). **API:**
   devolver esse erro como `409`.
2. **OC aprovada continuava aprovada se o valor subisse.** O recálculo mantinha `aprovado` com
   qualquer total. Hoje a API não edita itens depois do POST, então não é alcançável, mas fica
   fechado para quando houver edição: se o valor **subir** para cima do limite, a OC volta para
   `aguardando_aprovacao` e a aprovação é limpa (`aprovado_por`/`aprovado_em`).
3. **Rascunho virava aprovado ao receber itens.** O recálculo tratava `rascunho` como
   `aguardando`. Agora `rascunho` e `cancelado` não mudam com o recálculo. (A API não cria rascunho
   hoje; não muda nada no fluxo atual.)

**Pendente, fora deste contrato:** o que fazer com uma OC **já sincronizada** com o Omie que é
cancelada (hoje só muda no av-hub). Vai junto com o L4.

---

## 3. 🟡 Depois

- **B10. Vínculo OC ↔ pedido de venda** (hoje o comprador escreve "PV 27645 - GABRIEL NICOLAU" no
  `cObsInt` e o número no `cNumPedido`). Vai ter contrato próprio; o Nathan vai detalhar.
- **B11. Impostos na OC** (IPI, ICMS ST): só depois de o item escolher o produto do cadastro
  (`core.produtos`, com NCM). Até lá o PDF mostra o total sem impostos.
- **B12. Produto do cadastro no item** (`codigo_produto` hoje vai nulo; o Omie precisa de
  `nCodProd` para vincular ao estoque): busca em `core.produtos` por unidade, como o fornecedor.

---

## 4. Ordem sugerida

1. **Banco do teste:** Apêndices A, B e C, e o D para conferir. É só SQL, já testado.
2. **API do que o banco já resolveu:** B1 (models), B3, B6, B9 e B13 (ajustes pequenos).
3. **B2** (decisão) e **B7** (rotas dos catálogos) — a pipeline liga os catálogos junto.
4. **B5** e **B8** (a tela e o PDF da OC dependem deles).
5. **B4** junto com o L4 da pipeline (envio ao Omie).
6. **B0** (produção) quando o teste estiver fechado.

## 5. Aceite

- O Apêndice D roda no teste e dá o resultado esperado.
- Um pedido de compra real do Omie (ex.: 46618) grava no espelho sem estouro, com itens, parcelas,
  observação do item e `codigo_item_integracao`.
- Uma OC aprovada vai ao Omie e volta `sincronizado` com `numero_pedido_omie`; uma falha fica `erro`
  com a mensagem do Omie e pode ser reenviada.
- A tela e o PDF da OC mostram nome/CNPJ/IE do fornecedor, IE da unidade, nomes do comprador e do
  projeto, a observação do item e o histórico de decisão.
- Condição de pagamento, categoria, conta corrente e projeto são escolhidos de listas da unidade, a
  OC grava os códigos que o Omie aceita e as parcelas saem da condição escolhida.
- `POST /compras/ordens` com `numero_pedido` no corpo é ignorado; o número sai só do contador.
- Só quem tem `pode_aprovar` aprova ou cancela; OC cancelada não volta.

---

## Apêndice A — SQL dos catálogos (B7)

```sql
-- =============================================================================
-- Apêndice A — Catálogos da OC (B7). Pressupõe o banco de TESTE de 23/09/2026.
-- core.categorias precisa estar VAZIA (está, em teste e produção): codigo_empresa
-- já nasce NOT NULL e a unicidade passa a ser por unidade.
-- Testado no banco local em 24/09/2026. Uma transação só.
-- =============================================================================
BEGIN;

-- Condições de pagamento: a tabela do teste tem varchar(30), e o Omie devolve até 71.
ALTER TABLE core_vendas_faturamento.condicoes_pagamento_compras
  ALTER COLUMN descricao  TYPE varchar(100),
  ALTER COLUMN lista_dias TYPE varchar(100);


-- Projetos (ListarProjetos)
CREATE TABLE core.projetos (
  id                  uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa      uuid NOT NULL REFERENCES core.unidades(id)
                        ON UPDATE CASCADE ON DELETE RESTRICT,
  codigo_projeto_omie bigint       NOT NULL,
  codigo_integracao   varchar(20),
  nome                varchar(70)  NOT NULL,
  ativo               boolean      NOT NULL DEFAULT true,
  incluido_em_omie    timestamptz,
  alterado_em_omie    timestamptz,
  usuario_inclusao_omie  varchar(20),
  usuario_alteracao_omie varchar(20),
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  deleted_at          timestamptz
);
CREATE UNIQUE INDEX uq_projetos_empresa_codigo ON core.projetos (codigo_empresa, codigo_projeto_omie);
CREATE INDEX idx_projetos_empresa_ativo ON core.projetos (codigo_empresa, ativo) WHERE deleted_at IS NULL;
CREATE TRIGGER trg_projetos_updated_at BEFORE UPDATE ON core.projetos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Contas correntes (ListarContasCorrentes)
CREATE TABLE core.contas_correntes (
  id                  uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa      uuid NOT NULL REFERENCES core.unidades(id),
  codigo_conta_omie   bigint      NOT NULL,
  codigo_integracao   varchar(20),
  descricao           varchar(40) NOT NULL,
  tipo                varchar(2),
  codigo_banco        varchar(3),
  codigo_agencia      varchar(10),
  numero_conta        varchar(25),
  ativo               boolean NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  deleted_at          timestamptz
);
CREATE UNIQUE INDEX uq_contas_correntes_empresa_codigo ON core.contas_correntes (codigo_empresa, codigo_conta_omie);
CREATE INDEX idx_contas_correntes_empresa_ativo ON core.contas_correntes (codigo_empresa, ativo) WHERE deleted_at IS NULL;
CREATE TRIGGER trg_contas_correntes_updated_at BEFORE UPDATE ON core.contas_correntes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Categorias (ListarCategorias): por conta Omie, com as marcações
ALTER TABLE core.categorias
  ADD COLUMN codigo_empresa      uuid NOT NULL REFERENCES core.unidades(id),
  ADD COLUMN ativo               boolean NOT NULL DEFAULT true,
  ADD COLUMN conta_despesa       boolean,
  ADD COLUMN conta_receita       boolean,
  ADD COLUMN totalizadora        boolean,
  ADD COLUMN nao_exibir          boolean,
  ADD COLUMN categoria_superior  varchar(20),
  ADD COLUMN tipo_categoria      varchar(3);
ALTER TABLE core.categorias DROP CONSTRAINT uq_core_categorias_codigo;
CREATE UNIQUE INDEX uq_categorias_empresa_codigo ON core.categorias (codigo_empresa, codigo_categoria);
CREATE INDEX idx_categorias_empresa_despesa ON core.categorias (codigo_empresa, conta_despesa, ativo) WHERE deleted_at IS NULL;
CREATE TRIGGER trg_categorias_updated_at BEFORE UPDATE ON core.categorias
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
```

## Apêndice B — SQL das regras (B1, B3, B6, B7b, B9, B13)

Troca `fn_ordens_compra_numerar`, `fn_requisicoes_compra_numerar`, `fn_ordens_compra_recalcular`,
`fn_ordens_compra_parcelas` e `fn_ordens_compra_status`, e cria as triggers novas. **Depende do
Apêndice A** (a trigger de parcelas lê `condicoes_pagamento_compras`).

```sql
-- =============================================================================
-- Compras: tudo o que falta no BANCO (contrato compras-backend: B1, B3, B6, B7, B9)
-- Pressupõe o banco de TESTE de 23/09/2026 (PR #273, 7918357, bf9d86a, 8715549)
-- e o B7 dos catálogos (condicoes_pagamento_compras, core.projetos,
-- core.contas_correntes, core.categorias por unidade).
-- Testado no banco local em 24/09/2026. Uma transação só.
-- =============================================================================
BEGIN;

-- -----------------------------------------------------------------------------
-- B1. Espelho: as duas colunas de item que faltam no teste
-- -----------------------------------------------------------------------------
ALTER TABLE core_vendas_faturamento.pedidos_compras_itens
  ADD COLUMN IF NOT EXISTS codigo_item_integracao varchar(20),   -- cCodIntItem: liga o item à OC do av-hub
  ADD COLUMN IF NOT EXISTS observacao             text;          -- cObs do item (sai impresso)
CREATE INDEX IF NOT EXISTS idx_pedidos_compras_itens_cod_integracao
  ON core_vendas_faturamento.pedidos_compras_itens (codigo_item_integracao)
  WHERE codigo_item_integracao IS NOT NULL;

-- -----------------------------------------------------------------------------
-- B3. Número só do contador, e nunca muda
-- -----------------------------------------------------------------------------
-- Requisição: o número do MES (D4) ganha coluna própria.
ALTER TABLE core_vendas_faturamento.requisicoes_compra
  ADD COLUMN numero_requisicao_mes varchar(30);
CREATE INDEX idx_requisicoes_compra_numero_mes
  ON core_vendas_faturamento.requisicoes_compra (codigo_empresa, numero_requisicao_mes)
  WHERE numero_requisicao_mes IS NOT NULL;

-- OC: o número SEMPRE sai do contador. O que vier no corpo é descartado
-- (antes: "número informado explicitamente continua sendo respeitado").
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ordens_compra_numerar()
 RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.numero_pedido := core_vendas_faturamento.fn_proximo_numero_documento(
    NEW.codigo_empresa, 'ordem_compra', 'OC-');
  RETURN NEW;
END $$;

-- Requisição: idem. Se vier um número no corpo, ele é o do MES e vai para
-- numero_requisicao_mes (compatível com quem ainda manda em numero_requisicao).
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_requisicoes_compra_numerar()
 RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NULLIF(btrim(NEW.numero_requisicao), '') IS NOT NULL THEN
    NEW.numero_requisicao_mes := COALESCE(NULLIF(btrim(NEW.numero_requisicao_mes), ''),
                                          btrim(NEW.numero_requisicao));
  END IF;
  NEW.numero_requisicao := core_vendas_faturamento.fn_proximo_numero_documento(
    NEW.codigo_empresa, 'requisicao_compra', 'REQ-');
  RETURN NEW;
END $$;

-- Número não muda depois de criado (é a chave cCodIntPed no Omie).
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ordens_compra_numero_fixo()
 RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.numero_pedido := OLD.numero_pedido;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_ordens_compra_numero_fixo
  BEFORE UPDATE OF numero_pedido ON core_vendas_faturamento.ordens_compra
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_ordens_compra_numero_fixo();

CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_requisicoes_compra_numero_fixo()
 RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.numero_requisicao := OLD.numero_requisicao;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_requisicoes_compra_numero_fixo
  BEFORE UPDATE OF numero_requisicao ON core_vendas_faturamento.requisicoes_compra
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_requisicoes_compra_numero_fixo();

-- -----------------------------------------------------------------------------
-- B6. Campos do PDF: observação do item, valores por linha e totais
-- -----------------------------------------------------------------------------
ALTER TABLE core_vendas_faturamento.ordens_compra_itens
  ADD COLUMN observacao       text,                              -- para o fornecedor (cObs do item)
  ADD COLUMN valor_desconto   numeric(15,2) NOT NULL DEFAULT 0,  -- trigger
  ADD COLUMN valor_total_item numeric(15,2) NOT NULL DEFAULT 0;  -- trigger, já com desconto

ALTER TABLE core_vendas_faturamento.ordens_compra
  ADD COLUMN numero_pedido_fornecedor varchar(30),                -- cNumPedido
  ADD COLUMN valor_mercadorias        numeric(15,2) NOT NULL DEFAULT 0,  -- trigger
  ADD COLUMN valor_descontos          numeric(15,2) NOT NULL DEFAULT 0;  -- trigger

-- Inscrição estadual da unidade (cabeçalho do pedido). Fonte: Omie
-- geral/empresas ListarEmpresas → inscricao_estadual, uma vez por conta.
ALTER TABLE core.unidades ADD COLUMN inscricao_estadual varchar(20);

-- Valores de cada linha, arredondados a centavos (como o nValTot do Omie).
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ordens_compra_itens_valores()
 RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.valor_desconto   := round(NEW.quantidade * NEW.valor_unitario * NEW.desconto / 100, 2);
  NEW.valor_total_item := round(NEW.quantidade * NEW.valor_unitario, 2) - NEW.valor_desconto;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_ordens_compra_itens_valores
  BEFORE INSERT OR UPDATE OF quantidade, valor_unitario, desconto
  ON core_vendas_faturamento.ordens_compra_itens
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_ordens_compra_itens_valores();

-- Recalcular: totais = soma das linhas (o total do PDF bate com a soma dos
-- itens) e, de forma defensiva, OC aprovada cujo valor SUBIU para cima do
-- limite volta para aguardando_aprovacao. Rascunho e cancelada não mudam.
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ordens_compra_recalcular()
 RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_oc      uuid;
  v_merc    numeric(15,2);
  v_desc    numeric(15,2);
  v_total   numeric(15,2);
  v_brl     numeric(15,2);
  v_limite  numeric(15,2);
  v_cotacao numeric(15,6);
  v_empresa uuid;
BEGIN
  v_oc := COALESCE(NEW.id_ordem_compra, OLD.id_ordem_compra);

  SELECT o.codigo_empresa, COALESCE(o.cotacao_moeda, 1)
    INTO v_empresa, v_cotacao
    FROM core_vendas_faturamento.ordens_compra o
   WHERE o.id = v_oc;

  SELECT COALESCE(sum(round(i.quantidade * i.valor_unitario, 2)), 0),
         COALESCE(sum(i.valor_desconto), 0),
         COALESCE(sum(i.valor_total_item), 0)
    INTO v_merc, v_desc, v_total
    FROM core_vendas_faturamento.ordens_compra_itens i
   WHERE i.id_ordem_compra = v_oc;

  v_brl := round(v_total * v_cotacao, 2);

  SELECT COALESCE(max(p.limite_aprovacao), 30000.00)
    INTO v_limite
    FROM core_vendas_faturamento.parametros_compras p
   WHERE p.codigo_empresa = v_empresa;

  UPDATE core_vendas_faturamento.ordens_compra o
     SET valor_mercadorias = v_merc,
         valor_descontos   = v_desc,
         valor_total       = v_total,
         valor_total_brl   = v_brl,
         status = CASE
                    WHEN o.status IN ('cancelado', 'rascunho') THEN o.status
                    WHEN o.status = 'aprovado'
                         AND v_brl > v_limite AND v_brl > o.valor_total_brl THEN 'aguardando_aprovacao'
                    WHEN o.status = 'aprovado' THEN o.status
                    WHEN v_brl > v_limite THEN 'aguardando_aprovacao'
                    ELSE 'aprovado'
                  END
   WHERE o.id = v_oc;

  RETURN NULL;
END $$;

-- -----------------------------------------------------------------------------
-- B7 (depois). Parcelas pela condição de pagamento do catálogo
-- -----------------------------------------------------------------------------
-- Com a condição encontrada no catálogo da unidade: uma parcela por dia de
-- lista_dias, contados da data de previsão (é o que o Omie faz: pedido 46618,
-- previsão 24/10 + 30 = 23/11), calculo_provisorio = false. Sem condição (texto
-- livre antigo ou catálogo vazio): o provisório de antes, partes iguais a cada 30 dias.
-- Roda também quando muda a condição, a data de previsão ou a quantidade.
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ordens_compra_condicao()
 RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_qtd integer;
BEGIN
  SELECT c.quantidade_parcelas INTO v_qtd
    FROM core_vendas_faturamento.condicoes_pagamento_compras c
   WHERE c.codigo_empresa = NEW.codigo_empresa
     AND c.codigo_omie = NEW.codigo_condicao_pagamento
     AND c.ativo;
  IF v_qtd IS NOT NULL AND v_qtd >= 1 THEN
    NEW.quantidade_parcelas := v_qtd;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_ordens_compra_condicao
  BEFORE INSERT OR UPDATE OF codigo_condicao_pagamento, codigo_empresa
  ON core_vendas_faturamento.ordens_compra
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_ordens_compra_condicao();

CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ordens_compra_parcelas()
 RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_lista    text;
  v_condicao boolean;
  v_dias     integer[];
  v_n     integer;
  v_valor numeric(15,2);
  v_resto numeric(15,2);
  v_base  date;
  i       integer;
BEGIN
  DELETE FROM core_vendas_faturamento.ordens_compra_parcelas WHERE id_ordem_compra = NEW.id;

  IF NEW.valor_total IS NULL OR NEW.valor_total = 0 THEN
    RETURN NULL;
  END IF;

  v_base := COALESCE(NEW.data_previsao_chegada, CURRENT_DATE);

  SELECT c.lista_dias INTO v_lista
    FROM core_vendas_faturamento.condicoes_pagamento_compras c
   WHERE c.codigo_empresa = NEW.codigo_empresa
     AND c.codigo_omie = NEW.codigo_condicao_pagamento
     AND c.ativo;
  v_condicao := FOUND;

  IF v_condicao THEN
    -- "30,40,50,60,70"; vazio = à vista na data base ("000" A Vista)
    v_dias := COALESCE(
      (SELECT array_agg(btrim(d)::integer ORDER BY ord)
         FROM unnest(string_to_array(v_lista, ',')) WITH ORDINALITY AS t(d, ord)
        WHERE btrim(d) ~ '^\d+$'),
      ARRAY[0]);
  ELSE
    v_n := GREATEST(COALESCE(NEW.quantidade_parcelas, 1), 1);
    SELECT array_agg(k * 30 ORDER BY k) INTO v_dias FROM generate_series(1, v_n) AS k;
  END IF;

  v_n     := array_length(v_dias, 1);
  v_valor := round(NEW.valor_total / v_n, 2);
  v_resto := NEW.valor_total - (v_valor * v_n);

  FOR i IN 1..v_n LOOP
    INSERT INTO core_vendas_faturamento.ordens_compra_parcelas
      (id_ordem_compra, numero_parcela, data_vencimento, valor, percentual, calculo_provisorio)
    VALUES (NEW.id, i, v_base + v_dias[i],
            CASE WHEN i = v_n THEN v_valor + v_resto ELSE v_valor END,
            round(100.0 / v_n, 3),
            NOT v_condicao);
  END LOOP;

  RETURN NULL;
END $$;

DROP TRIGGER trg_ordens_compra_parcelas_gerar ON core_vendas_faturamento.ordens_compra;
CREATE TRIGGER trg_ordens_compra_parcelas_gerar
  AFTER UPDATE OF valor_total, codigo_condicao_pagamento, quantidade_parcelas, data_previsao_chegada
  ON core_vendas_faturamento.ordens_compra
  FOR EACH ROW
  WHEN (NEW.valor_total IS DISTINCT FROM OLD.valor_total
     OR NEW.codigo_condicao_pagamento IS DISTINCT FROM OLD.codigo_condicao_pagamento
     OR NEW.quantidade_parcelas IS DISTINCT FROM OLD.quantidade_parcelas
     OR NEW.data_previsao_chegada IS DISTINCT FROM OLD.data_previsao_chegada)
  EXECUTE FUNCTION core_vendas_faturamento.fn_ordens_compra_parcelas();

-- -----------------------------------------------------------------------------
-- B9. Cancelamento, status final e histórico de decisão
-- -----------------------------------------------------------------------------
ALTER TABLE core_vendas_faturamento.ordens_compra
  ADD COLUMN cancelado_por uuid REFERENCES auth.usuarios(id) ON DELETE SET NULL,
  ADD COLUMN cancelado_em  timestamptz;

CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ordens_compra_status()
 RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_limite numeric(15,2);
BEGIN
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  -- Cancelada é final: não volta a aguardar nem é aprovada depois.
  IF OLD.status = 'cancelado' THEN
    RAISE EXCEPTION 'OC cancelada não muda de status (tentativa: %)', NEW.status
      USING ERRCODE = '23514';
  END IF;

  SELECT COALESCE(max(p.limite_aprovacao), 30000.00)
    INTO v_limite
    FROM core_vendas_faturamento.parametros_compras p
   WHERE p.codigo_empresa = NEW.codigo_empresa;

  -- Aprovar uma OC acima do limite exige que ela TENHA PASSADO por
  -- aguardando_aprovacao (sem isso, bastaria criar já como 'aprovado').
  IF NEW.status = 'aprovado'
     AND NEW.valor_total_brl > v_limite
     AND OLD.status <> 'aguardando_aprovacao' THEN
    RAISE EXCEPTION
      'OC de % (limite %) só pode ser aprovada a partir de aguardando_aprovacao; status atual: %',
      NEW.valor_total_brl, v_limite, OLD.status
      USING ERRCODE = '23514';
  END IF;

  -- Carimbos vêm do BANCO, não do cliente.
  IF NEW.status = 'aprovado' THEN
    NEW.aprovado_em := now();
  END IF;
  IF NEW.status = 'aguardando_aprovacao' AND OLD.status = 'aprovado' THEN
    NEW.aprovado_por := NULL;       -- voltou a depender de decisão
    NEW.aprovado_em  := NULL;
  END IF;
  IF NEW.status = 'cancelado' THEN
    NEW.cancelado_em  := now();
    -- só se updated_by for um usuário de verdade (senão a FK derrubaria o cancelamento)
    NEW.cancelado_por := COALESCE(NEW.cancelado_por,
      (SELECT u.id FROM auth.usuarios u WHERE u.id = NEW.updated_by));
  END IF;

  RETURN NEW;
END $$;

CREATE TABLE core_vendas_faturamento.ordens_compra_historico (
  id               uuid PRIMARY KEY DEFAULT uuidv7(),
  id_ordem_compra  uuid NOT NULL REFERENCES core_vendas_faturamento.ordens_compra(id)
                     ON UPDATE CASCADE ON DELETE CASCADE,
  codigo_empresa   uuid NOT NULL REFERENCES core.unidades(id),
  status_anterior  varchar(24),                  -- NULL = criação
  status_novo      varchar(24) NOT NULL,
  valor_total_brl  numeric(15,2),               -- valor no momento da decisão
  motivo           text,
  alterado_por     uuid REFERENCES auth.usuarios(id) ON DELETE SET NULL,  -- NULL = automático
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_ordens_compra_historico_oc
  ON core_vendas_faturamento.ordens_compra_historico (id_ordem_compra, created_at);

CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_ordens_compra_historico()
 RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_anterior varchar(24);
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
      RETURN NULL;
    END IF;
    v_anterior := OLD.status;
  END IF;

  INSERT INTO core_vendas_faturamento.ordens_compra_historico
    (id_ordem_compra, codigo_empresa, status_anterior, status_novo, valor_total_brl, motivo, alterado_por)
  VALUES (
    NEW.id, NEW.codigo_empresa, v_anterior, NEW.status, NEW.valor_total_brl,
    CASE
      WHEN NEW.status = 'aprovado' AND NEW.aprovado_por IS NULL
        THEN 'automática: valor abaixo do limite de aprovação'
      WHEN NEW.status = 'aguardando_aprovacao' AND v_anterior = 'aprovado'
        THEN 'valor subiu acima do limite de aprovação'
      WHEN NEW.status = 'cancelado' THEN NEW.motivo_reprovacao
    END,
    (SELECT u.id FROM auth.usuarios u
      WHERE u.id = CASE
                     WHEN TG_OP = 'INSERT'         THEN NEW.created_by
                     WHEN NEW.status = 'aprovado'  THEN NEW.aprovado_por
                     WHEN NEW.status = 'cancelado' THEN NEW.cancelado_por
                   END)
  );
  RETURN NULL;
END $$;
CREATE TRIGGER trg_ordens_compra_historico
  AFTER INSERT OR UPDATE OF status ON core_vendas_faturamento.ordens_compra
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_ordens_compra_historico();

-- Tela "Compradores" na matriz de permissões (B9), dentro de Compras.
INSERT INTO auth.telas (nome, slug, id_parent, ordem, ativo)
SELECT 'Compradores', 'compradores', t.id, 1, true
  FROM auth.telas t
 WHERE t.slug = 'compras' AND t.id_parent IS NULL AND t.deleted_at IS NULL
   AND NOT EXISTS (SELECT 1 FROM auth.telas x WHERE x.slug = 'compradores' AND x.deleted_at IS NULL);

COMMIT;
```

## Apêndice C — Dados

```sql
-- =============================================================================
-- Apêndice C — Dados: inscrição estadual das unidades (B5/B6)
-- Fonte: Omie, geral/empresas → ListarEmpresas → inscricao_estadual (lido em 24/09/2026).
-- A HRM não tem conta Omie na pipeline: fica nula até alguém informar.
-- =============================================================================
UPDATE core.unidades
   SET inscricao_estadual = CASE cnpj
         WHEN '23.440.235/0001-08' THEN '454.462.423.112'   -- Aços Vital (Mogi)
         WHEN '62.270.345/0001-12' THEN '52792850060'       -- Aços Uberaba
       END
 WHERE cnpj IN ('23.440.235/0001-08', '62.270.345/0001-12');
```

## Apêndice D — Roteiro de teste (termina em ROLLBACK)

Rodar com `psql -f` depois dos Apêndices A–C. Usa a unidade de Mogi e o primeiro usuário ativo, e
cria (só dentro da transação) as três condições de pagamento que usa, se a pipeline ainda não
carregou o catálogo. **Validado em 24/09/2026 num banco montado do zero com a estrutura do teste +
Apêndices A–C copiados deste arquivo: saída idêntica à do banco local.**

```sql
-- Roteiro de teste das regras de compras no banco. Tudo dentro de uma transação
-- desfeita no final (ROLLBACK): não deixa OC nem requisição de teste.
\set ON_ERROR_STOP 1
\pset footer off
BEGIN;

CREATE TEMP TABLE ctx AS
SELECT (SELECT id FROM core.unidades WHERE cnpj = '23.440.235/0001-08') AS empresa,
       (SELECT id FROM auth.usuarios WHERE deleted_at IS NULL ORDER BY created_at LIMIT 1) AS usuario;

-- As três condições que o teste usa, com os valores reais do Omie (Mogi). Se a
-- pipeline já carregou o catálogo, não mexe; se não, cria só nesta transação.
INSERT INTO core_vendas_faturamento.condicoes_pagamento_compras
  (codigo_empresa, codigo_omie, descricao, quantidade_parcelas, lista_dias, dias_deslocamento)
SELECT ctx.empresa, c.codigo, c.descricao, c.qtd, c.lista, 0
  FROM ctx, (VALUES
    ('U10', '30/40/50/60/70', 5, '30,40,50,60,70'),
    ('A08', '180/210/240/270/300/330/360/390/420/450/480/510/540/570/600/630/660/690', 18,
            '180,210,240,270,300,330,360,390,420,450,480,510,540,570,600,630,660,690'),
    ('000', 'A Vista', 1, NULL)
  ) AS c(codigo, descricao, qtd, lista)
ON CONFLICT (codigo_empresa, codigo_omie) DO NOTHING;

-- T1. Número vindo no corpo é ignorado; valores por linha; aprovação automática abaixo do limite
INSERT INTO core_vendas_faturamento.ordens_compra
  (numero_pedido, codigo_empresa, codigo_fornecedor, codigo_comprador, tipo_frete,
   data_previsao_chegada, codigo_condicao_pagamento, created_by)
SELECT 'INVENTADO-123', empresa, '10363934283', usuario, 'CIF', DATE '2026-10-24', 'U10', usuario FROM ctx;
CREATE TEMP TABLE oc1 AS SELECT id FROM core_vendas_faturamento.ordens_compra ORDER BY created_at DESC LIMIT 1;

INSERT INTO core_vendas_faturamento.ordens_compra_itens
  (id_ordem_compra, codigo_empresa, ordem, descricao_produto, quantidade, unidade_medida, valor_unitario, desconto)
SELECT oc1.id, ctx.empresa, 1, 'CHAPA 3/8', 1000, 'KG', 5.04, 1.5 FROM oc1, ctx
UNION ALL
SELECT oc1.id, ctx.empresa, 2, 'TUBO 2"', 3, 'PC', 333.333, 0 FROM oc1, ctx;

\echo '== T1: número do contador, quantidade de parcelas da condição U10, valores e status'
SELECT numero_pedido, quantidade_parcelas, valor_mercadorias, valor_descontos, valor_total, status,
       aprovado_em IS NOT NULL AS aprovado_em_carimbado
  FROM core_vendas_faturamento.ordens_compra WHERE id = (SELECT id FROM oc1);
SELECT ordem, quantidade, valor_unitario, desconto, valor_desconto, valor_total_item
  FROM core_vendas_faturamento.ordens_compra_itens WHERE id_ordem_compra = (SELECT id FROM oc1) ORDER BY ordem;

\echo '== T2: parcelas pela condição U10 (30,40,50,60,70 da previsão 24/10), não provisórias'
SELECT numero_parcela, data_vencimento, valor, percentual, calculo_provisorio
  FROM core_vendas_faturamento.ordens_compra_parcelas WHERE id_ordem_compra = (SELECT id FROM oc1) ORDER BY 1;
SELECT sum(valor) AS soma_parcelas FROM core_vendas_faturamento.ordens_compra_parcelas
 WHERE id_ordem_compra = (SELECT id FROM oc1);

\echo '== T3: trocar para A08 (18 parcelas) e depois para texto livre com 3 parcelas (provisório, a cada 30 dias)'
UPDATE core_vendas_faturamento.ordens_compra SET codigo_condicao_pagamento = 'A08' WHERE id = (SELECT id FROM oc1);
SELECT count(*) AS parcelas, min(data_vencimento), max(data_vencimento), bool_and(NOT calculo_provisorio) AS da_condicao,
       sum(valor) AS soma
  FROM core_vendas_faturamento.ordens_compra_parcelas WHERE id_ordem_compra = (SELECT id FROM oc1);
UPDATE core_vendas_faturamento.ordens_compra
   SET codigo_condicao_pagamento = '30/60/90 dias', quantidade_parcelas = 3 WHERE id = (SELECT id FROM oc1);
SELECT count(*) AS parcelas, min(data_vencimento), max(data_vencimento), bool_and(calculo_provisorio) AS provisorias
  FROM core_vendas_faturamento.ordens_compra_parcelas WHERE id_ordem_compra = (SELECT id FROM oc1);

\echo '== T4: número não muda depois de criado'
UPDATE core_vendas_faturamento.ordens_compra SET numero_pedido = 'OC-999999' WHERE id = (SELECT id FROM oc1);
SELECT numero_pedido FROM core_vendas_faturamento.ordens_compra WHERE id = (SELECT id FROM oc1);

-- OC acima do limite
INSERT INTO core_vendas_faturamento.ordens_compra
  (codigo_empresa, codigo_fornecedor, codigo_comprador, tipo_frete, data_previsao_chegada,
   codigo_condicao_pagamento, moeda, cotacao_moeda, cotacao_data, cotacao_origem, created_by)
SELECT empresa, '10363934283', usuario, 'CIF', DATE '2026-10-24', '000', 'USD', 5.1414, DATE '2026-09-23', 'ptax', usuario FROM ctx;
CREATE TEMP TABLE oc2 AS SELECT id FROM core_vendas_faturamento.ordens_compra WHERE moeda = 'USD' AND created_at = now();
INSERT INTO core_vendas_faturamento.ordens_compra_itens
  (id_ordem_compra, codigo_empresa, ordem, descricao_produto, quantidade, unidade_medida, valor_unitario)
SELECT oc2.id, ctx.empresa, 1, 'BOBINA', 10000, 'KG', 1.00 FROM oc2, ctx;

\echo '== T5: USD 10.000 x PTAX 5,1414 = R$ 51.414 > limite -> aguardando; condição 000 = 1 parcela à vista na previsão'
SELECT numero_pedido, moeda, valor_total, valor_total_brl, status, quantidade_parcelas
  FROM core_vendas_faturamento.ordens_compra WHERE id = (SELECT id FROM oc2);
SELECT numero_parcela, data_vencimento, valor, calculo_provisorio
  FROM core_vendas_faturamento.ordens_compra_parcelas WHERE id_ordem_compra = (SELECT id FROM oc2);

\echo '== T6: aprovar com aprovado_por; depois o valor SOBE -> volta para aguardando e limpa a aprovação'
UPDATE core_vendas_faturamento.ordens_compra o SET status = 'aprovado', aprovado_por = ctx.usuario, updated_by = ctx.usuario
  FROM ctx WHERE o.id = (SELECT id FROM oc2);
SELECT status, aprovado_por IS NOT NULL AS tem_aprovador FROM core_vendas_faturamento.ordens_compra WHERE id = (SELECT id FROM oc2);
UPDATE core_vendas_faturamento.ordens_compra_itens SET quantidade = 12000 WHERE id_ordem_compra = (SELECT id FROM oc2);
SELECT status, valor_total_brl, aprovado_por IS NULL AS aprovacao_limpa, aprovado_em IS NULL AS carimbo_limpo
  FROM core_vendas_faturamento.ordens_compra WHERE id = (SELECT id FROM oc2);

\echo '== T7: cancelar carimba cancelado_em/cancelado_por; cancelada não pode ser aprovada'
UPDATE core_vendas_faturamento.ordens_compra o SET status = 'cancelado', motivo_reprovacao = 'preço fora', updated_by = ctx.usuario
  FROM ctx WHERE o.id = (SELECT id FROM oc2);
SELECT status, cancelado_em IS NOT NULL AS cancelado_em, cancelado_por IS NOT NULL AS cancelado_por
  FROM core_vendas_faturamento.ordens_compra WHERE id = (SELECT id FROM oc2);
SAVEPOINT antes_de_aprovar_cancelada;
\set ON_ERROR_STOP 0
UPDATE core_vendas_faturamento.ordens_compra o SET status = 'aprovado', aprovado_por = ctx.usuario
  FROM ctx WHERE o.id = (SELECT id FROM oc2);
\set ON_ERROR_STOP 1
ROLLBACK TO SAVEPOINT antes_de_aprovar_cancelada;

\echo '== T8: histórico de decisão das duas OCs'
SELECT o.numero_pedido, h.status_anterior, h.status_novo, h.valor_total_brl, h.motivo, h.alterado_por IS NOT NULL AS tem_usuario
  FROM core_vendas_faturamento.ordens_compra_historico h
  JOIN core_vendas_faturamento.ordens_compra o ON o.id = h.id_ordem_compra
 WHERE h.id_ordem_compra IN (SELECT id FROM oc1 UNION ALL SELECT id FROM oc2)
 ORDER BY o.numero_pedido, h.created_at, h.id;

\echo '== T9: requisição com número do MES no corpo -> número do contador + numero_requisicao_mes'
INSERT INTO core_vendas_faturamento.requisicoes_compra
  (numero_requisicao, codigo_empresa, material, quantidade, unidade_medida, prazo_necessidade)
SELECT 'MES-4471', empresa, 'CHAPA 3/8', 10, 'PC', DATE '2026-10-30' FROM ctx
RETURNING numero_requisicao, numero_requisicao_mes;

ROLLBACK;
```

| Teste | Resultado esperado (obtido no local em 24/09/2026) |
|---|---|
| T1 | `numero_pedido` = `OC-000001` (o `INVENTADO-123` do corpo é ignorado), `quantidade_parcelas` = 5 (da U10), mercadorias 6.040,00, descontos 75,60, total 5.964,40, `aprovado` com `aprovado_em` carimbado. Linhas: 75,60 / 4.964,40 e 0,00 / 1.000,00 |
| T2 | 5 parcelas de 1.192,88 em 23/11, 03/12, 13/12, 23/12/2026 e 02/01/2027, 20% cada, `calculo_provisorio = false`; soma 5.964,40 |
| T3 | A08 → 18 parcelas de 22/04/2027 a 13/09/2028, todas da condição, soma 5.964,40. Texto livre com 3 → 3 provisórias de 23/11/2026 a 22/01/2027 |
| T4 | continua `OC-000001` |
| T5 | `OC-000002`, USD 10.000,00 → R$ 51.414,00, `aguardando_aprovacao`, 1 parcela de 10.000,00 em 24/10/2026 (condição `000`) |
| T6 | aprova com aprovador; depois de subir para 12.000 → R$ 61.696,80, volta para `aguardando_aprovacao`, `aprovado_por` e `aprovado_em` nulos |
| T7 | `cancelado` com `cancelado_em` e `cancelado_por`; aprovar depois dá `ERROR: OC cancelada não muda de status (tentativa: aprovado)` |
| T8 | histórico: OC-000001 `→ aguardando_aprovacao`, `aguardando_aprovacao → aprovado` (automática, sem usuário); OC-000002 `→ aguardando`, `→ aprovado` (com usuário), `aprovado → aguardando_aprovacao` ("valor subiu acima do limite"), `→ cancelado` ("preço fora", com usuário) |
| T9 | `numero_requisicao` = `REQ-000001`, `numero_requisicao_mes` = `MES-4471` |

Os números `OC-000001`/`REQ-000001` supõem o contador zerado na unidade; num banco com OCs, saem
os próximos. O `ROLLBACK` final desfaz tudo, inclusive o contador.
