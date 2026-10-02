---
tags: [contrato-api, contrato-sql, compras, integracao-mes, seguranca]
criado: 2026-10-01
status: proposta
---

# Contrato 34 — Requisições: o MES empurra para o av-hub (PUT por `id_origem`)

> **🔴 QUEBRANDO A `api-test` (01/10/2026).** **Conferência de 01/10/2026 na `api-test`** (o DBA avisou que concluiu): a rota `PUT /compras/requisicoes/origem/{id_origem}` está no ar (valida o corpo; chave falsa dá 401), **mas `GET /compras/requisicoes` responde 500** (com e sem filtro), enquanto `/compras/requisicoes/resumo`, que é SQL cru, responde 200. O model da `develop` já tem `codigo_pedido_omie`/`numero_pedido_venda`: a causa provável é **o SQL do anexo 0001 não aplicado na `api-test`**. A caixa de entrada de Compras do av-hub fica sem lista. **Ação urgente: aplicar `34-anexos/0001-requisicoes-pedido-omie.sql` na `api-test`** (e antes de subir em produção).

**Criado em:** 01/10/2026 · **Para:** backend (`api-acos-vital`), DBA (Gustavo) e MES (`api-pcp`, Robert) · **Substitui a DEC-2** ("o hub busca no MES") para as requisições; revisa os contratos 003/004/005.

Decisões do Nathan (01/10/2026): (1) o MES envia a requisição ao abri-la, para dar sensação de tempo real, com nova tentativa se falhar; (2) requisição **só cancela se não tiver OC**; com OC, requisição e histórico não podem ser apagados.

**Na `develop` da API desde 01/10/2026** (commit `0391b29`, "implement MES integration for purchase requests", de outro desenvolvedor, a partir do nosso desenho). Antes: **implementado e testado na API local** (branch `feat/requisicoes-mes-upsert`, commit `f4380d7`, worktree `Desktop/wt-api-requisicoes-mes`, sem push). Banco: anexo `34-anexos/0001-requisicoes-pedido-omie.sql`.

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

1. **DBA:** aplicar o anexo 0001 (colunas `codigo_pedido_omie` e `numero_pedido_venda`).
2. **Backend:** revisar e levar o commit para a `develop`; definir `MES_INTEGRACAO_KEYS` no ambiente.
3. **MES (Robert):** chamar o PUT ao abrir/alterar/cancelar, com retry; tratar o **409** como "não cancelou" (ele não deve repetir).
4. **Precisão:** o MES guarda 4 casas e o hub 3 (testado: 10,1234 vira 10,123).
5. **Seguem de pé** os contratos 004 e 005 (volta hub → MES) e a chave do MES de escrita (L6).
6. Falta teste com `IDENTIDADE_EXIGIR_TOKEN`/`PERMISSOES_ROTA_MODO=exigir` ligados: a chave do MES não manda token de usuário; hoje passa porque `exigeUsuario` é falso para ela.
