# Contrato — Compras: o que ficou faltando depois da entrega do backend

**Criado em:** 23/09/2026, ao ligar o av-hub no backend real de Compras.

**Contexto:** o contrato original
(`docs/implementados/OK - ENVIAR - contrato-compras-fluxo-completo.md`) foi entregue em
22/09/2026 (`api-acos-vital`, commit `ec2a42b`, PR #273: `/compras/requisicoes`,
`/compras/ordens`, `/compras/fornecedores`, `/compras/transportadoras`, tabelas
`core_vendas_faturamento.{requisicoes_compra, ordens_compra, ordens_compra_itens,
ordens_compra_parcelas, parametros_compras}` com a régua, o cálculo de valores e as transições
em trigger). O av-hub já usa tudo isso: os dados de exemplo (`lib/compras/dados.ts`) foram
apagados, e o BFF não cai mais para mock nem calcula a régua.

Abaixo, o que **ainda** está fora do lugar. Cada item está marcado no código com
`GAMBIARRA(docs/ENVIAR - contrato-compras-pendencias-pos-backend.md)`.

## C1. Nomes na ordem de compra (fornecedor, transportadora, quem emitiu e quem aprovou)

`GET /compras/ordens` e `GET /compras/ordens/{id}` só devolvem códigos: `codigo_fornecedor`,
`codigo_transportadora`, `created_by` e `aprovado_por` (uuid). A tela não tem como mostrar o nome
sem um JOIN, e a busca de parceiros não aceita filtro por código. **Hoje a tela mostra
"Fornecedor 10037044822"** e esconde "Emitida por" e "Aprovada por".

Peço estes campos nas duas rotas, na listagem e no detalhe:

| Campo | Origem |
|---|---|
| `nome_fornecedor` | `core.parceiros.nome_fantasia` (mesma `codigo_empresa` da OC + `codigo_parceiro_omie = codigo_fornecedor`) |
| `cpf_cnpj_fornecedor` | `core.parceiros.cpf_cnpj` (mesmo JOIN) |
| `nome_transportadora` | `core.parceiros.nome_fantasia` pelo `codigo_transportadora` |
| `nome_criado_por` | nome do usuário `created_by` |
| `nome_aprovado_por` | nome do usuário `aprovado_por` |

O JOIN precisa usar `codigo_empresa`. Em `api-test`, o mesmo fornecedor aparece com códigos
diferentes em cada unidade (ex.: RUSPRISTEEL, ANANDA METAIS, ALUMIPLAST), porque cada unidade
tem a sua conta no Omie.

Os campos já existem como opcionais em `lib/domain/compras-ordem.ts`. Quando chegarem, a tela
passa a usá-los sozinha.

## C2. A OC deve aceitar só fornecedor/transportadora da própria unidade

Pelo mesmo motivo do C1, `POST /compras/ordens` deveria **rejeitar (400)** um
`codigo_fornecedor`/`codigo_transportadora` que não exista em `core.parceiros` para o
`codigo_empresa` da OC. Senão o `IncluirPedCompra` vai mandar ao Omie de uma unidade o código de
parceiro de outra. O av-hub já filtra a busca pela unidade da OC (`?codigo_empresa=`), mas uma
chamada direta à API ainda passa.

## C3. Busca `q` de OC pelo nome do fornecedor

Hoje `q` em `GET /compras/ordens` procura só em `numero_ordem`, `codigo_fornecedor` e
`contato`. Quem procura uma OC digita o **nome** do fornecedor. Depende do C1.

## C4. Indicadores (resumo)

```
GET /compras/requisicoes/resumo?codigo_empresa=
  → { abertas, em_cotacao, atendidas, canceladas }
GET /compras/ordens/resumo?codigo_empresa=
  → { aguardando_aprovacao, valor_aguardando_aprovacao_brl, aprovadas, canceladas }
```

Sem isso, `components/Compras/useCompras.ts` baixa todas as páginas (o BFF junta as páginas de
200) para somar os KPIs no navegador. Com C3 + C4, a listagem passa a paginar e filtrar no
servidor.

Observação: hoje `/compras/ordens/resumo` cai na rota `/:id` e responde
`400 "id deve ser um uuid"`. A rota nova precisa ser registrada **antes** de `/:id`.

## C5. Ler o limite de aprovação da unidade

`parametros_compras.limite_aprovacao` já é por unidade (e a trigger usa esse valor), mas não
existe rota para ler. O formulário de emissão avisa antes de enviar: "esta OC vai para
aprovação". Esse aviso ainda usa 30.000 fixo (`LIMITE_APROVACAO_OC`), então pode divergir de uma
unidade com limite próprio. O `status` final continua vindo do banco, que é quem decide.

```
GET /compras/parametros?codigo_empresa=   → { limite_aprovacao }
```

## C6. Sincronização com o Omie não existe

De-para completo dos campos (OC → `IncluirPedCompra`/`UpsertPedCompra`, e `PesquisarPedCompra` →
`pedidos_compras`): `docs/ENVIAR - contrato-compras-omie-pedidocompra.md`.

Nenhum job ou rota chama `IncluirPedCompra`. Toda OC fica
`status_sincronizacao_omie = 'pendente'` para sempre, e isso quebra o aceite do contrato
original: "nunca silenciosamente `pendente` para sempre sem explicação". Precisa de:

- o job que envia as OCs `pendente`, grava `codigo_pedido_omie`/`numero_pedido_omie`/
  `sincronizado_em` no sucesso e `erro`/`erro_sincronizacao_omie` na falha. Converter `desconto`
  % → `nDesconto` em valor, mapear `tipo_frete` CIF→"0"/FOB→"1" e mandar as parcelas;
- **resposta à pergunta em aberto**: reenvio automático ou botão "Reenviar ao Omie" na tela?
- a OC em estado `aguardando_aprovacao` deve ir ao Omie antes ou só depois de aprovada?

## C7. Permissão de aprovar e histórico de decisão

- O backend não confere permissão nenhuma nas rotas de Compras (só `x-api-key`). Quem decide
  é o BFF, com `pode_editar` da tela `compras` para aprovar e reprovar. A matriz não tem
  `pode_aprovar` (mesmo caso de `contrato-vagas-fila-decisao-no-banco.md`, V5, e
  `contrato-permissoes-e-escopo-no-banco.md`).
- `aprovado_por`, `created_by` e `updated_by` são aceitos **do corpo** do request. O av-hub
  preenche a partir da sessão, nunca do navegador, mas uma chamada direta pode aprovar "em nome"
  de qualquer uuid.
- Não existe histórico de decisão (quem/quando/de→para). Hoje o cancelamento guarda só o
  `motivo_reprovacao`: não há `cancelado_por`/`cancelado_em`.

## C8. Entidades HTML nos nomes de parceiro

`core.parceiros.nome_fantasia` traz texto como `&apos;DALS&apos;-DESTILARIA DE ALCOOL LOPES DA
SILVA` e `&apos;IMPERIUNS MATERIAIS DE CONSTRUCAO&apos;`: o ELT do Omie grava sem decodificar.
Aparece assim na busca de fornecedor. É correção de dado no pipeline, não na tela.

## Aceite

- A listagem de OCs mostra o nome do fornecedor e aceita busca por ele (C1, C3).
- `POST /compras/ordens` com fornecedor de outra unidade volta 400 (C2).
- Nenhuma OC fica `pendente` sem explicação: ou sincroniza, ou fica `erro` com mensagem (C6).
