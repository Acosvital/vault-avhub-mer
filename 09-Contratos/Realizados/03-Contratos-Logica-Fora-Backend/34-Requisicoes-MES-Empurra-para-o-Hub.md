---
tags: [contrato-api, contrato-sql, compras, integracao-mes, seguranca]
criado: 2026-10-01
atualizado: 2026-10-07
status: aplicada
---

# Contrato 34 — Requisições: o MES empurra para o av-hub (PUT por `id_origem`)

> **Atualização de 07/10/2026 — conferido no código (API: `main` = `develop`, `0391b29` no PR #275; MES: `develop` do `api-pcp`, `ca3346b`; produção não conferida no código; produção só pelo dump de 07/10, que cobre schema e dados, não o comportamento da API em produção; [[Auditoria-Dump-Producao-2026-10-07]]):**
> - **O MES já chama o PUT** desde `e7ce2c9` (02/10, PR #48): a requisição vira uma linha em `integracao_avhub_envios` na mesma transação, **um PUT por item** (`id_origem` = id do `RequisicaoCompraItem`), disparo imediato + timer de 60 s, backoff 1/2/5/10/30/60 min; 200/201 → ENVIADO (espelha id, número e status no item); 409 `REQUISICAO_COM_OC` → RECUSADO (não repete); 400 → FALHOU; 401/403/404/5xx reagenda; **sem chave a fila espera, com aviso no log**. O PUT não leva `id_item_parcial`. O antigo "falta o Robert ligar" **não vale mais**. Se `AVHUB_MES_INTEGRACAO_KEY` tem valor no ambiente real: não verificado. Atenção: no MES isso está **só na `develop`** (a `main` do `api-pcp` parou em 28/08).
> - **(atualizado em 07/10, dump de produção; [[Registro-de-Decisoes-2026-10-07]] itens 2 e 3)** ✅ A função `fn_requisicao_mes_aplicar` **existe em produção, completa**, e o `PUT` de sucesso **já foi validado no mes-test** (✅ Nathan). 🔴 Falta só **versionar o SQL no vault** (Gustavo fornece o DDL). A lacuna descrita abaixo ficou só como histórico.
> - ~~**Lacuna no anexo SQL:** o código da API chama a função de banco `core_vendas_faturamento.fn_requisicao_mes_aplicar` (a "migration 034"); **sem ela o PUT devolve 500**. O `34-anexos/0001-requisicoes-pedido-omie.sql` só cria 2 colunas e **a função não está em nenhum SQL do vault**. O que o vault testou até agora foi só 400 (validação) e 401 (chave inválida) na `api-test`: **falta o teste de sucesso** (201/200/409) na `api-test`/produção.~~ (superado, ver o item acima)
> - O PUT é o que valeu: o `POST /compras/requisicoes` citado em notas de 01/10 (ver [[Analise-Contratos-vs-Hub-2026-10-01]]) **não** foi o caminho implementado.
> - A chave do MES (`MES_INTEGRACAO_KEYS`) **só vale para esse PUT**; ela não abre `/compras/requisicoes/eventos` (35) nem `/pedidos_liberados` (26 L6). Ver [[Chaves-de-Integracao-AvHub-MES-Pipeline]] e [[Indice-Contratos]] (Conferência de 07/10/2026).

> **✅ ENTREGUE (02/10/2026).** O DBA aplicou o anexo 0001 na `api-test`. Conferido: `GET /compras/requisicoes` voltou a responder **200** (com e sem filtro) e devolve `codigo_pedido_omie` e `numero_pedido_venda`; `/resumo` 200; `PUT /compras/requisicoes/origem/{id_origem}` valida o corpo (400) e recusa chave inválida (401). Não testado: o envio real pelo MES com a `MES_INTEGRACAO_KEYS` (~~falta o Robert ligar do lado dele~~ **atualizado em 07/10:** o MES já chama o PUT desde `e7ce2c9`, 02/10; o teste de sucesso já passou no mes-test, ver o aviso do topo). **Antes de produção:** aplicar o anexo 0001 no banco **antes** de subir o código da API, senão a lista de requisições dá 500, como deu na `api-test` em 01/10.

**Criado em:** 01/10/2026 · **Para:** backend (`api-acos-vital`), DBA (Gustavo) e MES (`api-pcp`, Robert) · **Substitui a DEC-2** ("o hub busca no MES") para as requisições; revisa os contratos 003/004/005.

Decisões do Nathan (01/10/2026): (1) o MES envia a requisição ao abri-la, para dar sensação de tempo real, com nova tentativa se falhar; (2) requisição **só cancela se não tiver OC**; com OC, requisição e histórico não podem ser apagados.

**Na `develop` da API desde 01/10/2026** (commit `0391b29`, "implement MES integration for purchase requests", de outro desenvolvedor, a partir do nosso desenho). Antes: **implementado e testado na API local** (nota histórica: `f4380d7` foi uma branch local, re-autorada a partir de patches; o que vale é o `0391b29`; a remota `origin/feat/requisicoes-mes-upsert` é obsoleta e não deve ser mergeada). Banco: anexo `34-anexos/0001-requisicoes-pedido-omie.sql`.

## 1. A rota

`PUT /compras/requisicoes/origem/{id_origem}` (uuid do MES). Idempotente: o MES pode repetir à vontade.

Corpo (JSON): `codigo_empresa` (uuid, obrigatório na criação), `material`, `quantidade` (> 0), `unidade_medida`, `prazo_necessidade` (AAAA-MM-DD), e opcionais `numero_requisicao_mes`, `descricao`, `acabado_sugerido`, `solicitante`, `observacao`, `codigo_pedido_omie`, `numero_pedido_venda`, `cancelada` (true = o `deleted_at` do MES).

| Situação | Resposta |
|---|---|
| não existe | **201** `{aplicado:true, requisicao}` (nasce `aberta`, número REQ-… do contador) |
| existe, sem OC | **200** atualiza os dados; a unidade não muda (400 se tentar) |
| existe, **com OC** (atendida) | **200** `{aplicado:false, motivo:"com_oc"}`, nada alterado |
| existe e já cancelada | **200** `{aplicado:false, motivo:"cancelada"}`, nada alterado |
| `cancelada:true`, sem OC | **200** vira `cancelada` (repetir é seguro) |
| `cancelada:true`, **com OC** | **409** `REQUISICAO_COM_OC`, nada alterado — é o retorno ao MES |
| `cancelada:true`, nunca chegou | **200** `{aplicado:false, motivo:"nao_existe"}` |
| campo inválido | **400** com a mensagem |

`status`, `id_ordem_compra`, `created_by` e qualquer outro campo fora da lista são **ignorados**. Não existe DELETE: cancelar é só mudar o status, e o registro e o histórico ficam.

## 2. Segurança

- **Chave própria** `MES_INTEGRACAO_KEYS` (variável da API, separadas por vírgula, **mínimo 32 caracteres**). Ela **só vale para esse PUT**: qualquer outra rota ou método com ela dá **403** `CHAVE_MES_ROTA_NAO_PERMITIDA`, mesmo `GET`. Não vale como chave admin e não é a chave do BFF.
- Comparação por hash em tempo constante. Sem a variável, a rota fica fechada para o MES.
- O corpo é validado campo a campo (tipos, tamanhos, datas, números) e só os campos da lista entram: não dá para o MES (ou quem roubar a chave) mudar status, ligar OC ou forjar autoria.
- Perda da chave é limitada: o pior que ela faz é criar/alterar requisição **sem OC** (e cancelar). Trocar a chave não exige deploy de código, só a variável; guardar só no ambiente do MES e da API, nunca no git.
- Recomendado em produção: liberar a rota só para o IP do servidor do MES (o `ipFilter` já existe) e usar HTTPS.

## 3. O que falta

1. **DBA:** aplicar o anexo 0001 (colunas `codigo_pedido_omie` e `numero_pedido_venda`). **(07/10)** Aplicado na `api-test` em 02/10; ~~e criar/conferir a função `fn_requisicao_mes_aplicar` ("migration 034"), que o código chama e que não está no anexo — sem ela o PUT dá 500.~~ **(atualizado em 07/10)** A função existe em produção (dump de 07/10, completa); 🔴 falta só **versionar o SQL no vault** (Gustavo fornece o DDL).
2. **Backend:** revisar e levar o commit para a `develop`; definir `MES_INTEGRACAO_KEYS` no ambiente. **(07/10)** Commit na `develop`/`main` (`0391b29`, #275); valor da variável no ambiente real: não verificado.
3. **MES (Robert):** chamar o PUT ao abrir/alterar/cancelar, com retry; tratar o **409** como "não cancelou" (ele não deve repetir). **(07/10)** Feito em `e7ce2c9` (02/10), na `develop` do `api-pcp`: 409 → RECUSADO e não repete.
4. **Precisão:** o MES guarda 4 casas e o hub 3 (testado: 10,1234 vira 10,123).
5. **Seguem de pé** os contratos 004 e 005 (volta hub → MES) e a chave do MES de escrita (L6). **(07/10)** 004 continua inexistente (API e MES); 005 tem a rota no MES e falta o consumidor no hub; a chave desta seção §2 só abre o PUT, então o L6 do [[26-Vendas-Liberacao-Pedido]] segue aberto.
6. Falta teste com `IDENTIDADE_EXIGIR_TOKEN`/`PERMISSOES_ROTA_MODO=exigir` ligados: a chave do MES não manda token de usuário; hoje passa porque `exigeUsuario` é falso para ela. **(atualizado em 07/10)** `PERMISSOES_ROTA_MODO` fica **fixo em `exigir`** no código ([[Registro-de-Decisoes-2026-10-07]] item 8). A leitura do código indica que as chamadas de serviço com só `x-api-key` (sem `Bearer`) passam sem mapeamento, porque o modo só confere permissão quando há token. 🟡 Confirmar em teste (o item "falta teste com `exigir`" do DBA continua aberto até lá).
