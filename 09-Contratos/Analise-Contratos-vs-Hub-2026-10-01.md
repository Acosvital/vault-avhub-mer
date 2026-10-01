---
tags: [contrato, auditoria, indice]
criado: 2026-10-01
---

# Análise: contratos em aberto × código do av-hub (01/10/2026)

Base: `origin/develop` do av-hub (branch `docs/analise-contratos-vault`) + as branches locais. Só o **front** foi conferido: backend, SQL e pipeline moram em outros repositórios e aqui valem o que o contrato diz. O contrato 02 (rejeitado) e o 06 (invalidado) ficaram de fora, e o 19-Pipeline (substituído pelo 23) também.

Legenda: ✅ front pronto na `develop` · 🟡 parcial · ❌ não existe no hub · ➖ não é do hub.

| Contrato | Front (hub) | O que falta |
|---|---|---|
| **009** views sem escopo de empresa (SQL) | ➖ | DBA aplicar na api-test/produção |
| **003** requisição MES→hub (API) | ❌ nenhuma referência no hub. **MES pronto** (`GET /requisicoes-compra`, `MES_API_KEY`, cursor `alterado_desde`+`apos_id`, `deleted_at` com `incluir_deletados=true`) | (Robert, 01/10) **1.** job de busca a cada 5 min não existe em lugar nenhum (F2 do cronograma, Gustavo, 19–30/10, sem confirmação); **2.** falta "insere ou atualiza" por `id_origem` (o `POST /compras/requisicoes` recusa a 2ª gravação, o `PATCH` só muda status, o `GET` não filtra por `id_origem`); **3.** cancelamento: `deleted_at` → `PATCH status=cancelada` só se a requisição **não tem OC**; com OC criada o cancelamento do MES é ignorado e requisição e histórico **nunca são apagados** (decisão do Nathan, 01/10; a checagem vale no backend, sem `DELETE` físico, e falta combinar com o Robert o retorno ao MES); **4.** `requisicoes_compra` sem coluna `codigo_pedido_omie`/nº do pedido de venda (DBA); **5.** URL do `api-pcp` e `MES_API_KEY` no ambiente do job + acesso do servidor à api-pcp de teste (infra); **6.** conferir precisão: MES 4 casas, av-hub 3 |
| **004** referência OC hub→MES (API) | ❌ | `GET /ordens-compra/referencia` não existe: o MES não sabe quando a OC é emitida e o "Registrar compra" manual continua no setor Compras. Falta o Gustavo |
| **005** status por item MES→hub (API) | ❌ | nenhum job do hub lê `GET /itens/status` do MES; aceite do Nathan às diferenças; falta o Gustavo. **L6 (do 26):** a chave do MES no hub precisa ser de escrita (`POST /importado` da carteira) |
| **04** vagas | ✅ lista, resumo, `/decisao`, aviso "volta para pendente" (`fix/vagas-edicao-volta-pendente` já na develop) | ligar `VAGAS_TRAVAS_DECISAO` na API; §3.3.1 no backend (hoje 409 `VAGA_DECIDIDA`; o front trata os dois casos) |
| **07** orçamento e coordenadores no banco | ⛔ **desconsiderado pelo Nathan (01/10)** | nada: não cobrar o DBA, não migrar as telas, os JSON ficam no repositório |
| **09** paginação por pedido em `/vendas_planilha` | ❌ o hub ainda não manda `agrupar_por=pedido_venda` (BFF `pedidos-equipe`, `pcp/pedidos`, `meus-pedidos`) | **backend entregue em 01/10** (conferido na `api-test`); trocar os BFFs e as telas para o modo agrupado (`total` por pedido, `parciais[]` aninhados) e tirar `utils/agruparPedidosPlanilha.ts` quando as 4 telas migrarem |
| **13** fornecedores por produto | ❌ `GET /produtos/:id/fornecedores` não é chamado; `experimental/simulador-comissao` ainda usa o dataset estático (`lib/orcamento/data/produtos.json`) | migrar o simulador para a tabela real `produtos`. Era dependente do 07 (desconsiderado); o próprio 13 já estava marcado para desconsiderar |
| **14** Compras ↔ Omie (puxar/criar pedido) | ➖ | pipeline (ver 23); criar OC no Omie (`IncluirPedCompra`, C6) |
| **23** pipeline consolidado | ➖ | L1–L10: gravação no banco de teste, depois produção; PR da pipeline em draft |
| **26** liberação do pedido | ✅ `liberar-pedidos`, `liberacao-equipe` (+ `lib/api/liberacaoPedidos.ts`) | data de corte (`parametros_vendas.data_inicio_liberacao` vazia); L6 (chave do MES de escrita). Remover o `GAMBIARRA` de escopo no BFF quando `ESCOPO_VENDEDORES_EXIGIR` ligar |
| **28** compradores criar/excluir/sugestão | 🟡 a lista tem edição e `sugestoes`; **não há `POST`/`DELETE`** em `app/api/compras/compradores` nem botão "Novo"/excluir | é proposta: backend (C1–C3) primeiro, depois o front |
| **29** NF manual só admin | ✅ tela e BFF (`lib/api/notasManuais.ts`, `TELA_NOTAS_MANUAIS`); a permissão é conferida só no BFF | backend conferir a permissão (`auth.rotas_telas` + `PERMISSOES_ROTA_MODO`). No hub, as rotas de NF manual mandam só `x-api-key` (`headersCompras`), sem o `backendToken` da sessão: falta mandar. Tela só na api-test, falta produção |
| **30** PDF do pedido Omie completo | 🟡 `PedidoOmiePdf.tsx` existe mas **não lê** endereço, e-mail, telefone, IE nem `codigo_produto` (o comentário do arquivo diz que não vêm); quem já lê esses campos é o `OrdemCompraPdf.tsx`, o PDF da OC do hub | backend devolver os campos no `GET /pedidos_compras/{id}`, depois o hub passar a mostrá-los; IE vazia em `core.parceiros` (pipeline); IPI/ICMS ST |
| **31** dashboard de Compras | ✅ `/api/compras/dashboard` + `lib/domain/compras-dashboard.ts` | levar `cba68fa` da API local para a `develop` da API |
| **32** CCP acompanhamento da OC | 🟡 `/compras/followup`, `services/compras/acompanhamento.ts` e 4 rotas BFF já existem | é proposta no backend (3 tabelas + fila); a tela não funciona sem ele. P1 e P2 em aberto |
| **33** unidade de origem do vendedor | 🟡 commit `397cf81` na `feat/vendedor-periodo-ativo`, **local, sem push, 1 à frente da develop** | push + PR para `develop`; aplicar anexos 0001/0002 na api-test e produção; P1–P6 |

## Pontos que o vault diz e o código contradiz

- **33:** o índice diz "front pronto na branch (sem commit)"; já está commitado (`397cf81`), só falta o push.
- **04:** o cabeçalho cita o front como pendente em `wt-rh-contratos`; as telas já estão na `develop` (PR #90 e a branch `fix/vagas-edicao-volta-pendente`).

## Ordem sugerida

1. Push + PR da `feat/vendedor-periodo-ativo` (33).
2. DBA: 09 entregue; falta só a data de corte do 26 (o 07 foi desconsiderado) e a data de corte do 26.
3. Backend de 28 e 32, que bloqueiam telas que já estão no hub.
4. ~~Simulador (13) e remoção dos JSON~~: dependiam do 07, desconsiderado.

## Decisão do Nathan sobre cancelamento (01/10)

Requisição só pode ser cancelada se **não tiver ordem de compra criada**. Com OC criada, a requisição e o histórico não podem ser apagados: o `deleted_at` do MES é ignorado (e registrado) pelo job/rota de importação, e o backend confere a regra sem permitir exclusão física. Pendente: o que o hub devolve ao MES nesse caso.

## Decisão do Nathan: o MES empurra (01/10)

**Aprovado pelo Nathan (01/10):** o MES envia a requisição ao hub com `POST /compras/requisicoes` quando a abre (sensação de tempo real), com nova tentativa se falhar. Cria e cancela; atualizar só depois do "insere ou atualiza" por `id_origem`. **Isso substitui a DEC-2** (hub busca no MES): atualizar a DEC-2 e os contratos 003/004/005. O job da F2 deixa de ser o caminho principal e pode ficar só como conferência.

## Nota sobre a confiança

Os status de backend (API, `api-test`, banco) vêm do texto dos contratos e da mensagem do Robert, não de consulta direta. Só o front do hub foi lido no código.

## Feito em 01/10: contrato 34

A rota "insere ou atualiza" (`PUT /compras/requisicoes/origem/{id_origem}`), a regra de cancelamento (só sem OC), as colunas do pedido do Omie e a chave de integração restrita foram implementados e testados na API local. Detalhes e pendências em [[34-Requisicoes-MES-Empurra-para-o-Hub]]. Itens 2, 3 e 4 da lista do Robert resolvidos no código local; falta DBA aplicar a coluna, subir para a `develop` e o MES chamar.
