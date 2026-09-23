# Contrato — Módulo de Compras: requisição → ordem de compra → sincronização com o Omie

**Criado em:** 21/09/2026, ao implementar a primeira versão do módulo de Compras no av-hub
(`app/(protected)/compras/*`, `components/Compras/`). **É greenfield**: não existe hoje nenhum
endpoint no backend para requisições de compra nem para ordens de compra — a tela roda inteira
sobre dados de exemplo. Cada trecho que depende disso está marcado com `GAMBIARRA(` no código.

## 1. O fluxo (confirmado com o cliente)

1. O PCP, dentro do MES, identifica que falta material e gera uma **requisição de compra**.
2. A requisição chega numa "caixa de entrada" no av-hub (`/compras`, aba **Requisições**).
3. O Comprador escolhe o fornecedor e faz a cotação **fora do sistema** (telefone, e-mail, etc.).
4. O Comprador fecha a compra emitindo uma **Ordem de Compra (OC)** a partir da requisição
   (`/compras/nova/{requisicaoId}`).
5. A OC nasce no av-hub **e** precisa ser espelhada no Omie (`IncluirPedCompra`) — não abandonamos
   o Omie, é dual-write.
6. Se o valor total da OC ultrapassar **R$ 30.000,00**, ela nasce como `aguardando_aprovacao` e só
   é efetivada depois que um Aprovador/Diretor decidir (`/compras/ordem/{id}`). Abaixo disso, segue
   direto como `aprovado`.
7. A OC fica `aprovado` até a chegada física do material — **não existe "em trânsito" verificável**
   hoje (decisão consciente de negócio, não lacuna de implementação).
8. Se o fornecedor nunca entregar, a OC vai para `cancelado`.

## 2. O que existe hoje (nada) e o que a tela faz enquanto isso

| Onde | Gambiarra hoje |
|---|---|
| `app/api/compras/requisicoes/route.ts`, `.../[id]/route.ts` | Tenta `GET {API_URL}/compras/requisicoes[?...]` e `.../[id]`; se falhar (é o caso hoje — endpoint não existe), devolve as requisições de exemplo de `lib/compras/dados.ts` |
| `app/api/compras/ordens/route.ts`, `.../[id]/route.ts` | Idem para ordens de compra: tenta o backend, cai para exemplo. `POST`/`PATCH` gravam **só em memória do processo do servidor** (somem no próximo deploy/restart) |
| `app/api/compras/fornecedores/route.ts` | Fornecedor não tem cadastro próprio (é projeção de `core.parceiros`); a rota tenta `GET {API_URL}/compras/fornecedores` e cai para uma lista de exemplo |
| `app/api/compras/transportadoras/route.ts` | Idem para transportadora (também projeção de `core.parceiros` — `nCodTransp` no Omie é código de parceiro); tenta `GET {API_URL}/compras/transportadoras` e cai para uma lista de exemplo |
| `components/Compras/useCompras.ts` | Baixa **todas** as requisições e ordens (`limit=500`) e filtra/busca/pagina/soma os KPIs no navegador — não existem parâmetros de filtro/paginação/agregação reais no backend ainda |
| `app/api/compras/ordens/route.ts` (POST) | Calcula a régua de R$ 30.000,00 **no BFF**, não no banco — quem chamar a API por fora do av-hub pode criar uma OC acima do limite sem passar por aprovação |
| Sincronização com o Omie | Não existe em lugar nenhum ainda — o campo `status_sincronizacao_omie` fica sempre `pendente` no mock, nunca chama de fato o Omie |

## 3. O que peço para o backend/DBA

### 3.1 Requisições de compra (alimentadas pelo MES)

```
GET /compras/requisicoes?codigo_empresa=&status=&q=&page=&limit=&sort=&order=
GET /compras/requisicoes/{id}
```

Campos esperados (nomes sugeridos, ajustar ao schema real do vault):

| Campo | Tipo | Observação |
|---|---|---|
| `id` | uuid | |
| `numero_requisicao` | text | número gerado pelo MES |
| `codigo_empresa` | text | unidade/filial de origem |
| `material` | text | |
| `descricao` | text? | |
| `quantidade` | numeric | |
| `unidade_medida` | text | KG, UN, M, PC… |
| `prazo_necessidade` | date | |
| `acabado_sugerido` | boolean? | sugestão do MES; comprador confirma/troca na emissão da OC |
| `status` | enum | `aberta` \| `em_cotacao` \| `atendida` \| `cancelada` |
| `solicitante` | text? | |
| `observacao` | text? | |
| `ordem_compra_id` | uuid? | preenchido quando uma OC nasce a partir dela |

A requisição é **criada e mantida pelo MES** (via alguma integração própria — ver 3.5), o av-hub só
lê e muda `status`/`ordem_compra_id` quando uma OC é emitida a partir dela.

#### 3.1.1 `POST /compras/requisicoes` — criação manual (exceção)

O caminho normal continua sendo o MES (ver acima). Adicionamos um botão "Nova requisição" em
`/compras` (`components/Compras/ComprasLista.tsx`) para o caso excepcional de o próprio Comprador
precisar abrir uma requisição direto no av-hub, sem passar pelo PCP. Nasce sempre com
`status = 'aberta'` e `solicitante = null` (quem criou fica implícito na sessão autenticada, mas
hoje não há campo de auditoria — ver "Lista completa de ações que exigem `autorizado_por`" na seção 4).

```json
{
  "codigo_empresa": "text",
  "material": "text",
  "quantidade": "numeric",
  "unidade_medida": "text",
  "prazo_necessidade": "date",
  "acabado_sugerido": "boolean|null",
  "observacao": "text|null"
}
```

Resposta: o registro completo (`id`, `numero_requisicao` gerado pelo backend, `status: 'aberta'`,
`ordem_compra_id: null`, `created_at`/`updated_at`). **Hoje isso não existe no backend**
(`app/api/compras/requisicoes/route.ts`, `criarRequisicaoExemplo` em `lib/compras/dados.ts`) — grava
só em memória do processo do servidor.

#### 3.1.2 `PATCH /compras/requisicoes/{id}` — transição de status pelo kanban

A aba "Visão geral" (`/compras`, `components/Compras/Kanban/RequisicoesKanban.tsx`) deixa arrastar o
card de uma requisição entre colunas, o que muda só `status` — nunca reenvia a requisição inteira
(mesmo padrão de `PATCH /compras/ordens/{id}`, ver 3.2):

```json
{ "status": "aberta" | "em_cotacao" | "cancelada" }
```

Matriz de transição válida (o front já valida antes de mandar o PATCH, mas o backend **precisa**
validar de novo — nunca confiar só no cliente):

| De | Para permitido |
|---|---|
| `aberta` | `em_cotacao`, `cancelada` |
| `em_cotacao` | `aberta`, `cancelada` |
| `cancelada` | `aberta`, `em_cotacao` (reabertura) |
| `atendida` | nenhum — só o backend marca `atendida`, automaticamente, ao emitir uma OC a partir da
  requisição (ver 3.2); nenhum fluxo do av-hub tenta mudar `status` para/de `atendida` via este PATCH |

`PATCH` deve **rejeitar** (400) qualquer tentativa de mudar para/de `atendida` por aqui, e qualquer
transição fora da tabela acima. Exige `pode_editar` da tela `compras` (mesma observação de permissão
registrada em 3.2 para `PATCH /compras/ordens/{id}`).

**Hoje isso não existe no backend** (`app/api/compras/requisicoes/[id]/route.ts`,
`atualizarRequisicaoExemplo` em `lib/compras/dados.ts`) — atualiza só em memória do processo do
servidor, sem validar a matriz de transição no backend (só no cliente,
`components/Compras/Kanban/RequisicoesKanban.tsx`) nem registrar quem mudou o status.

### 3.2 Ordens de compra

```
POST   /compras/ordens
GET    /compras/ordens?codigo_empresa=&status=&q=&page=&limit=&sort=&order=
GET    /compras/ordens/{id}
PATCH  /compras/ordens/{id}
```

**`POST /compras/ordens`** — payload (ver `payloadOrdem` em `components/Compras/acoes.ts` pro
formato exato que o av-hub já envia):

```json
{
  "requisicao_id": "uuid|null",
  "codigo_empresa": "text",
  "codigo_fornecedor": "text (projeção de core.parceiros)",
  "data_previsao_chegada": "date",
  "codigo_condicao_pagamento": "text",
  "quantidade_parcelas": "int",
  "contato": "text|null",
  "contrato": "text|null",
  "codigo_categoria": "text|null",
  "codigo_conta_corrente": "text|null (nCodCC no Omie — projeção de conta corrente, sem cadastro próprio no av-hub)",
  "codigo_projeto": "text|null (nCodProj no Omie — projeção de projeto, sem cadastro próprio no av-hub)",
  "moeda": "BRL|USD|EUR|...",
  "cotacao_moeda": "numeric|null (valor de 1 unidade da moeda em R$ no momento da compra; obrigatório quando moeda != BRL, ver conversão abaixo)",
  "observacao": "text|null",
  "observacao_interna": "text|null",
  "email_aprovador": "text|null",
  "tipo_frete": "CIF|FOB",
  "codigo_transportadora": "text|null (projeção de core.parceiros — nCodTransp no Omie é código de parceiro, igual fornecedor; ver 3.4)",
  "placa_veiculo": "text|null",
  "uf_veiculo": "text|null",
  "peso_liquido": "numeric|null",
  "peso_bruto": "numeric|null",
  "valor_frete": "numeric|null",
  "valor_seguro": "numeric|null",
  "volumes": "int|null",
  "itens": [
    {
      "codigo_produto": "text|null (projeção de core.produtos)",
      "descricao_produto": "text",
      "quantidade": "numeric",
      "unidade_medida": "text (KG, UN, M, PC… — cUnidade obrigatório por item no IncluirPedCompra do Omie)",
      "valor_unitario": "numeric",
      "desconto": "numeric (percentual, não valor — ver conversão abaixo)",
      "tipo_material": "acabado|nao_acabado",
      "local_estoque": "text|null"
    }
  ]
}
```

**Conversão de `desconto` (percentual → valor) ao montar o `IncluirPedCompra`:** o av-hub só manda
e só edita `desconto` como **percentual** (rótulo "Desconto (%)" na tela, decisão de negócio — não é
para mudar). O Omie, porém, espera `nDesconto` como **valor monetário** por item, não percentual.
O backend, ao sincronizar a OC com o Omie, precisa calcular:

```
valor_desconto_item = quantidade × valor_unitario × (desconto / 100)
```

e mandar esse valor em `nDesconto`. Essa conversão é responsabilidade exclusiva do backend no
momento do `IncluirPedCompra` — o av-hub nunca calcula nem manda valor monetário de desconto.

**Moeda estrangeira e conversão para R$ (`cotacao_moeda`):** matéria-prima importada é lançada na
moeda de origem (`moeda: 'USD'|'EUR'`) — `valor_unitario` e o `valor_total` calculado dos itens
ficam **nessa moeda**, nunca em R$. `cotacao_moeda` é obrigatório sempre que `moeda != 'BRL'`
(validado em `components/Compras/acoes.ts#validarFormOrdem`) e é o valor de 1 unidade da moeda em R$
no momento da compra (ex.: `5.38` para USD). A régua de aprovação de R$ 30.000 **precisa** ser
aplicada sobre o equivalente em R$ (`valor_total × cotacao_moeda` quando estrangeira), nunca sobre o
número bruto na moeda de origem — um pedido de US$ 6.300 já é R$ 33.894,00 numa cotação de 5,38 e
deve nascer `aguardando_aprovacao`, mesmo que 6.300 < 30.000. Essa conversão está implementada no
mock (`app/api/compras/ordens/route.ts`, `components/Compras/helpers.ts#converterParaBRL`) e
precisa existir igual no backend real — ver passo 3 abaixo.

**Mapeamento de `tipo_frete` para `cTpFrete` (modalidade de frete da NF-e) no Omie:**

| `tipo_frete` (av-hub) | `cTpFrete` (Omie) | Significado |
|---|---|---|
| `CIF` | `"0"` | Contratação do Frete por conta do Remetente (CIF) |
| `FOB` | `"1"` | Contratação do Frete por conta do Destinatário (FOB) |
| — | `2` | Contratação do Frete por conta de Terceiros |
| — | `3` | Transporte Próprio por conta do Remetente |
| — | `4` | Transporte Próprio por conta do Destinatário |
| — | `9` | Sem Ocorrência de Transporte |

O backend deve mapear `CIF → "0"` e `FOB → "1"` ao montar o payload do `IncluirPedCompra`. Os
códigos `2`/`3`/`4`/`9` **não têm equivalente** no nosso modelo simplificado (`tipo_frete: 'CIF' |
'FOB'`) hoje — limitação conhecida, não é para ser resolvida agora.

**Parcelas (`parcelas_incluir`) — `data_vencimento`/`valor` são calculados pelo backend:** o Omie
exige `dVencto` (data de vencimento) e `nValor` (valor) por parcela em `IncluirPedCompra`. O
formulário do av-hub **nunca** manda parcela por parcela — só manda `codigo_condicao_pagamento`
(texto livre) e `quantidade_parcelas` (número). É responsabilidade do backend, ao gravar a OC e
montar o `IncluirPedCompra`, calcular por parcela:

```
valor = valor_total_da_OC × (percentual / 100)   // arredondado a centavos; a última parcela
                                                    // absorve a diferença de arredondamento
data_vencimento = data_previsao_chegada + dias     // dias definido pela condição de pagamento
```

`ParcelaCondicaoPagamentoProps` (`lib/domain/compras-ordem.ts`) já tem os campos `data_vencimento`/
`valor` no domínio do av-hub — hoje só são preenchidos nos dados de exemplo (`lib/compras/dados.ts`),
nunca calculados de verdade, porque não existe backend real ainda.

O backend, ao receber o `POST`, precisa fazer **no mesmo fluxo**:

1. Gravar o cabeçalho em `pedidos_compras` e os itens em `pedidos_compras_itens` (ou nome
   equivalente no schema real do vault).
2. Calcular `valor_total = Σ (quantidade × valor_unitario × (1 − desconto/100))` **no banco**, não
   confiar no que o cliente mandar. Se `moeda != 'BRL'`, multiplicar por `cotacao_moeda` para obter
   `valor_total_brl` — é esse valor, nunca o bruto na moeda de origem, que entra no passo 3.
3. Aplicar a régua de aprovação sobre `valor_total_brl`: `> 30000.00` → `status = 'aguardando_aprovacao'`;
   caso contrário → `status = 'aprovado'`. **Hoje isso é calculado no BFF** (`app/api/compras/ordens/route.ts`),
   o que é inseguro — qualquer chamada direta à API contorna a régua.
4. Disparar `IncluirPedCompra` no Omie e gravar o retorno:
   - sucesso → `status_sincronizacao_omie = 'sincronizado'`, `codigo_pedido_omie`/`numero_pedido_omie`
     preenchidos com o que o Omie devolveu (`nCodPed`/`cNumero`);
   - falha → `status_sincronizacao_omie = 'erro'`, `erro_sincronizacao_omie` com a mensagem, e a OC
     continua existindo no av-hub (não é para a falha do Omie impedir a OC de nascer — o negócio
     quer poder investigar e reenviar depois). **Pergunta em aberto:** deve haver reenvio automático
     (retry/fila) ou só manual, com um botão "Reenviar ao Omie" na tela? Hoje a tela não tem esse botão.
5. Responder com o registro completo (incluindo `id`, `numero_pedido`, `status`,
   `status_sincronizacao_omie`).

#### 3.2.1 Ordem de compra sem requisição de origem

O caminho normal é emitir a OC a partir de uma requisição (`requisicao_id` sempre preenchido). O
botão "Nova ordem de compra" em `ComprasLista.tsx` (rota `/compras/nova`, sem `requisicaoId`, ao
lado de `/compras/nova/{requisicaoId}`) cobre o caso de uma compra que não passou pela caixa de
entrada — o comprador escolhe a unidade/filial diretamente no formulário (`FecharCompra.tsx`, campo
"Unidade" que só aparece quando não há requisição de origem) em vez de herdá-la da requisição.

Nesse caso `requisicao_id` vai `null` no payload do `POST /compras/ordens`, e o backend não deve
tentar marcar nenhuma requisição como `atendida` depois de criar a OC (só faz isso quando
`requisicao_id` vem preenchido). Fora isso, o payload e a régua de aprovação de R$ 30.000,00 são
idênticos ao caso com requisição.

**`PATCH /compras/ordens/{id}`** — só para decisão/estado, nunca reenvia cabeçalho/itens inteiros:

```json
{ "status": "aprovado" }
{ "status": "cancelado", "motivo_reprovacao": "texto opcional" }
```

- Exige uma permissão própria para aprovar/reprovar — **hoje a tela usa `pode_editar` da tela
  `compras`** porque a matriz de permissões não tem uma ação `pode_aprovar` (mesmo caso já registrado
  em `ENVIAR - contrato-vagas-fila-decisao-no-banco.md`, V5). Recomendo o mesmo caminho: uma ação
  `pode_aprovar` explícita, e reprovar/cancelar continuam em `pode_editar`.
- Deve gravar `aprovado_por` (usuário autenticado) e `aprovado_em` (timestamp do banco) ao aprovar —
  **hoje esses campos existem no domínio (`lib/domain/compras-ordem.ts`) mas o mock nunca os
  preenche**, porque não há como capturar a identidade de quem decide fora de uma rota real com
  sessão.
- Deve registrar histórico de decisão (quem, quando, de/para) — não existe hoje nem no mock.
- `PATCH` deve **rejeitar** tentativa de mudar `status` para `aprovado` se o valor total não bateu
  com a régua (ex.: tentar aprovar uma OC de R$ 40.000 sem estar `aguardando_aprovacao` primeiro).
- **Reprovar/cancelar uma OC com `requisicao_id` preenchido precisa devolver a requisição pra fila**:
  se ela estava `atendida` apontando pra essa OC, volta para `status: 'aberta'` e `ordem_compra_id:
  null` — senão a requisição fica presa em `atendida`, apontando pra uma OC morta, sem poder ser
  cotada de novo (mesmo princípio de "nenhum estado é beco sem saída" da reprovação de qualidade no
  vault). Implementado no mock em `atualizarOrdemExemplo` (`lib/compras/dados.ts`).

### 3.3 Fornecedores (projeção de `core.parceiros`)

```
GET /compras/fornecedores?q=
```

Resposta: `{ "codigo_fornecedor": "...", "nome_fantasia": "...", "cnpj_cpf": "..." }[]`. Não existe
(nem deve existir) cadastro de fornecedor próprio do módulo de Compras — é sempre a mesma base de
parceiros usada no resto do Hub.

### 3.4 Transportadoras (projeção de `core.parceiros`)

No Omie, `nCodTransp` (campo de cabeçalho do `IncluirPedCompra`) é o código de uma transportadora
cadastrada como **parceiro** — exatamente como o fornecedor, não é texto livre. Por isso a tela
(`components/Compras/FecharCompra.tsx`) troca o campo "Transportadora" de um input de texto para um
`<select>`, só relevante quando `tipo_frete === 'FOB'` (no CIF quem entrega e paga o frete é o
fornecedor).

```
GET /compras/transportadoras?q=
```

Resposta: `{ "codigo_transportadora": "...", "nome_fantasia": "...", "cnpj_cpf": "..." }[]`. Mesmo
formato de `GET /compras/fornecedores` — não existe (nem deve existir) cadastro de transportadora
próprio do módulo de Compras, é sempre a mesma base de parceiros usada no resto do Hub, só filtrada
pelo papel de transportadora.

**Hoje isso não existe no backend** — `app/api/compras/transportadoras/route.ts` tenta
`GET {API_URL}/compras/transportadoras` e cai para `TRANSPORTADORAS_EXEMPLO` em
`lib/compras/dados.ts`, igual ao padrão já usado em `app/api/compras/fornecedores/route.ts`.

### 3.5 Régua de aprovação de R$ 30.000,00

Confirmada pelo cliente para o cronograma E1/E2. Peço que o valor vire **parâmetro configurável no
banco** (ex.: `parametros_compras.limite_aprovacao`), não uma constante — hoje é
`LIMITE_APROVACAO_OC` fixo em `lib/domain/compras-ordem.ts`, igual ao caso já registrado para o
limite de dias de vagas pendentes (`ENVIAR - contrato-vagas-fila-decisao-no-banco.md`, V8).

### 3.6 Integração av-hub ↔ MES (spec técnica pendente)

Este contrato assume que o MES entrega requisições prontas para o backend do av-hub consumir, mas
**não existe ainda uma especificação técnica de como isso acontece** (webhook do MES para o backend?
fila? tabela compartilhada? polling?). Preciso que o time do MES e o Gustavo/DBA alinhem:

- Formato exato do payload que o MES manda (nomes de campo, tipos, encoding).
- Quem é o dono da idempotência (o MES pode reenviar a mesma requisição duas vezes?).
- O que acontece se o MES cancelar uma requisição que já virou uma OC no av-hub (hoje **não há
  regra** — a tela não trata este caso, ordem_compra_id continua apontando pra uma OC que já foi
  emitida).

## 4. Pendências reais em aberto (não tratar como decidido)

- **Tolerância de peso**: o formulário de emissão de OC (`components/Compras/FecharCompra.tsx`)
  aceita peso líquido/bruto livre, sem validar contra o peso esperado do item nem contra uma
  tolerância percentual de divergência para o Recebimento conferir depois. Ninguém definiu ainda
  qual é essa tolerância (ex.: ±5%?) nem se ela é por produto ou global.
- **Lista completa de ações que exigem `autorizado_por`**: hoje só a aprovação de OC acima de
  R$ 30.000 tem essa exigência clara. Não ficou definido se cancelar uma OC já aprovada, reprovar,
  ou editar itens de uma OC `aguardando_aprovacao` também precisam registrar quem autorizou — o
  campo `aprovado_por` em `lib/domain/compras-ordem.ts` só cobre o caso de aprovação.
- **Spec técnica exata do payload de integração av-hub ↔ MES** — ver 3.5, é o maior buraco: sem ela,
  os campos de requisição em `lib/domain/compras-requisicao.ts` são a melhor suposição a partir do
  que o cronograma descreve, não um contrato validado com o time do MES.
- **Reenvio ao Omie em caso de erro** — ver 3.2, item 4: retry automático ou botão manual?
- **Requisição cancelada pelo MES depois de virar OC** — ver 3.5: sem regra definida hoje.
- **Rateio por departamento (`departamentos_incluir` no Omie)**: o `IncluirPedCompra` aceita dividir
  a OC entre departamentos (`cCodDepto`, `nPerc`, `nValor`), e o contrato SQL do vault também
  reserva espaço pra isso. **Não modelamos nada disso** — nem no domínio (`lib/domain/compras-ordem.ts`)
  nem na tela. Se a Aços Vital precisar de rateio por departamento na v1, é feature nova, não um
  ajuste pequeno.
- **Status `rascunho` (`StatusOrdemCompra`)**: existe no enum mas nenhum fluxo hoje chega nele — toda
  OC emitida nasce direto `aprovado` ou `aguardando_aprovacao`. Reservado para uma eventual feature de
  "salvar rascunho" (editar aos poucos antes de emitir), que não foi pedida ainda. Não é bug, mas
  também não é uma decisão confirmada — se ninguém pedir essa feature, o valor pode ser removido do
  enum no futuro.

## 5. O que muda na tela quando isto chegar

- `services/compras/requisicoes.ts` e `services/compras/ordens.ts`: os `GET` ganham os parâmetros
  de 3.1/3.2; `useCompras.ts` deixa de baixar tudo e filtrar/paginar/somar no navegador.
- `app/api/compras/*/route.ts`: o `catch` com fallback para `lib/compras/dados.ts` é removido —
  nesse ponto `lib/compras/dados.ts` também pode sair do repositório.
- `components/Compras/acoes.ts`: `emitirOrdemCompra` para de precisar calcular a régua de R$ 30.000
  só para decidir a mensagem de sucesso (o banco já decide o `status` de verdade).
- `OrdemDetalhe.tsx`: passa a mostrar `aprovado_por`/`aprovado_em` de verdade e um histórico de
  decisão, se o backend gravar um.

## 6. Aceite

- `POST /compras/ordens` com itens somando mais de R$ 30.000,00 sempre volta com
  `status = 'aguardando_aprovacao'`, mesmo que o cliente tente mandar `status` diferente no corpo.
- `PATCH /compras/ordens/{id}` para `aprovado` falha (400/403) se a OC não estiver
  `aguardando_aprovacao` ou se quem chama não tiver a permissão de aprovar.
- Toda OC criada aparece no Omie (`IncluirPedCompra`) ou, se falhar, fica registrada com
  `status_sincronizacao_omie = 'erro'` e a mensagem do erro — nunca silenciosamente `pendente` para
  sempre sem explicação.
- Uma requisição atendida (`ordem_compra_id` preenchido) não aparece mais na fila de "abertas"/"em
  cotação" da caixa de entrada.
