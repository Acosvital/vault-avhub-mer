---
tags: [contrato-logica, contrato-api, faturamento, permissoes]
criado: 2026-09-29
atualizado: 2026-10-07
status: aplicada
---

# Contrato 29 — Notas fiscais manuais: só o administrador cria (permissão no backend)

> **✅ ENTREGUE (02/10/2026).** Conferido na `api-test` com a trava ligada (`NOTAS_MANUAIS_EXIGIR_PERMISSAO`): `POST /nota_fiscal_saida/manual` sem usuário → **403 `USUARIO_NAO_INFORMADO`**; com um usuário sem a permissão da tela `notas-fiscais-manuais` → **403 `SEM_PERMISSAO`**. Nada foi gravado. Não testado: o admin criando de verdade (criaria nota). **Antes de produção:** ligar a mesma variável no ambiente e criar a tela e as permissões (P1) lá. **(atualizado em 07/10)** A chave `NOTAS_MANUAIS_EXIGIR_PERMISSAO` **saiu do código** no contrato 38 (`c8f2f5e`, #279): a trava vale sempre, sem variável; resta criar a tela e as permissões em produção.

> **🟡 CÓDIGO PRONTO, TRAVA DESLIGADA (01/10/2026).** **Conferência de 01/10/2026 na `api-test`** (o DBA avisou que concluiu): o código está na `develop` (`NOTAS_MANUAIS_EXIGIR_PERMISSAO`), mas na `api-test` a trava está **desligada**: um `POST /nota_fiscal_saida/manual` com `created_by` de um usuário do perfil **Vendedor** passou da checagem de permissão e só parou na validação do cliente (esperado: 403). Unidade inexistente no teste, nada foi gravado. **Ação:** ligar `NOTAS_MANUAIS_EXIGIR_PERMISSAO=true` no ambiente e repetir.

**Criado em:** 29/09/2026 · **Revisado em:** 29/09/2026 (fim da tarde) · **Para:** DBA e backend (`api-acos-vital`)
**Complementa:** o cadastro manual de NF que o backend entregou em 29/09/2026 (`POST /nota_fiscal_saida/manual`,
commit `13a3691` — no código da API ele aparece como "contrato 28", que **não é** o
[[28-Compradores-Criar-Excluir-Sugestao]] deste vault).

---

## 1. Por quê

A nota manual entra nos dashboards de faturamento como **faturamento líquido do vendedor escolhido**. Nas
mãos de qualquer um, vira um jeito de inflar o número (e a comissão) de alguém com uma nota "por fora".
Decisão do Nathan (29/09/2026): **só o administrador cria** nota manual.

Hoje o `POST /nota_fiscal_saida/manual` só confere a `x-api-key`: qualquer sistema com a chave (pipeline,
MES, outro sistema do mesmo login) consegue criar nota — **conferido na `api-test` com
`PERMISSOES_ROTA_MODO=exigir` ligado** (ver P2; **atualizado em 07/10:** `exigir` passa a ser o modo **fixo** no código, [[Registro-de-Decisoes-2026-10-07]] item 8; a brecha da chamada só com `x-api-key` continua, porque o modo só confere permissão quando há token; a separação das chaves de serviço é o L6, 🔴 Gustavo). O av-hub barra no BFF, mas a regra de verdade precisa
estar no backend.

## 2. O contrato

### P1. Tela e permissões (banco)

**Feito na `api-test` em 29/09/2026; falta em produção.**

- Tela **Notas Fiscais Manuais**, slug **`notas-fiscais-manuais`**, **dentro de Cadastros › Auxiliares**
  (`id_parent` = tela `auxiliares`, filha de `cadastros`). Na `api-test`: id `4a3f264f-d036-40c6-997c-583aa7ebc888`.
  O slug é o que o av-hub usa (`lib/api/notasManuais.ts`, `TELA_NOTAS_MANUAIS`); a página fica em
  `/cadastros/auxiliares/notas-fiscais-manuais`.
- Permissões: **só o perfil de administrador** com `pode_visualizar`, `pode_criar`, `pode_editar` e
  `pode_deletar`. Nenhum outro perfil. Na `api-test`: perfil **Admin (Dev)**.
- O av-hub usa `pode_visualizar` para listar, `pode_criar` para cadastrar, `pode_editar` para alterar e
  `pode_deletar` para excluir.

### P2. O backend confere a permissão — pelo mecanismo que já existe

**Não precisa de chave nova:** é o mecanismo do contrato de permissões (`auth.rotas_telas` + token do
usuário + `PERMISSOES_ROTA_MODO`). Conferido na `api-test`: com `PERMISSOES_ROTA_MODO=exigir`, uma chamada
**só com a `x-api-key`** criou a nota (201; apagada em seguida). É o que `identidadeUsuario.js` faz: **sem
token, a permissão não é conferida**. Para valer, na ordem:

1. **Mapear as rotas** em `auth.rotas_telas`:
   - `POST /nota_fiscal_saida/manual` → `notas-fiscais-manuais.pode_criar`;
   - `GET /nota_fiscal_saida` → `notas-fiscais-manuais.pode_visualizar` **ou** a tela antiga
     `notas-fiscais-saida.pode_visualizar` (a mesma rota serve às duas telas);
   - `PUT`/`PATCH`/`DELETE /nota_fiscal_saida/*` → ver a pergunta 1: o mapa é **por rota**, não sabe se a
     nota é manual.
2. **Ligar em `observar`** e ler no log o que seria 403 — **todas** as rotas que o av-hub usa precisam
   estar mapeadas, porque com `exigir` rota **sem mapa** dá 403 para quem manda token.
3. **O av-hub mandar o token**: hoje a sessão do av-hub está **sem `backendToken`** (a API precisa do
   segredo de token do contrato de permissões configurado).
4. **`exigir`** (**atualizado em 07/10:** já é o modo fixo no código; sobra mapear as rotas e o av-hub mandar o token, ✅ o front manda token).
5. **Exigir token** (`IDENTIDADE_EXIGIR_TOKEN=true` ou a chave do av-hub marcada como "exige usuário").
   **Ligar isto antes do passo 3 derruba o av-hub inteiro** (401 em tudo).

Além do mapa, a própria rota precisa garantir:

- o campo **`manual` sai dos campos editáveis** do `PUT`/`PATCH` (hoje está em `UPDATE_FIELDS`: dá para
  transformar nota do Omie em manual e o contrário);
- **editar nota do Omie continua sendo só da pipeline**.

### P3. Auditoria

- `created_by`, `updated_by` e `deleted_by` **obrigatórios** na nota manual. Hoje quem manda é o BFF do
  av-hub, pelo usuário da sessão; com o token (P2), o backend usa o do token.
- A listagem (`GET /nota_fiscal_saida?manual=true`) devolve também `nome_criado_por`, `nome_alterado_por`
  e o **número** do pedido de venda (`numero_pedido`), além do `codigo_pedido_omie` — a tela mostra
  "cadastrada por … em …" e o pedido pelo número (hoje mostra só "com pedido").
- Nota manual excluída continua no banco (`deleted_at`, `deleted_by`).
- Recomendado: histórico das alterações de valor (valor anterior → novo, quem, quando), no mesmo molde
  do histórico da OC.

### P4. Consistência entre cadastro e edição

- **Hora:** o `POST /manual` aceita `HH:MM` e completa os segundos; o `PUT` recusa
  ("hora_emissao é obrigatória, no formato HH:MM:SS"). O `PUT` de nota manual deve normalizar igual ao
  `POST`. (O av-hub já manda com os segundos, desde o av-hub#108.)

## 3. Perguntas em aberto (Nathan)

1. **Editar e excluir nota do Omie pelas rotas genéricas:** mapear `PUT`/`DELETE /nota_fiscal_saida/*` para
   `notas-fiscais-manuais` passa a exigir essa permissão para mexer em **qualquer** nota. Se ninguém além da
   pipeline edita nota do Omie pela API, tudo bem; senão, o melhor é o backend criar rotas próprias para a
   manual (`PUT`/`DELETE /nota_fiscal_saida/manual/{codigo}`) e mapear só essas.
2. **Número de nota excluída:** hoje o banco recusa um número igual ao de uma nota manual **excluída**
   (409). Uma nota apagada por engano trava o número dela para sempre (na `api-test`, `TST29` e `TST30`
   ficaram ocupados em Mogi pelos testes). Deixar assim, ou permitir reaproveitar o número de nota excluída?

## 4. Depois de aplicado (av-hub)

- Nada muda nas permissões do av-hub (slug `notas-fiscais-manuais`).
- O painel passa a mostrar quem cadastrou/alterou e o número do pedido (P3).
- Se o backend criar rotas próprias de edição/exclusão (pergunta 1), o BFF passa a chamá-las.

## 5. Aceite

- Um usuário sem a permissão recebe 403 no `POST /nota_fiscal_saida/manual`.
- Uma chamada só com a `x-api-key` (sem token) também recebe 403 (depois do passo 5 do P2).
- O administrador cria, edita e exclui pela tela; cada operação grava quem fez.
- `PUT` com `manual: false` numa nota manual (ou `true` numa do Omie) não muda o campo.
- `PUT` de nota manual com hora `HH:MM` é aceito.
