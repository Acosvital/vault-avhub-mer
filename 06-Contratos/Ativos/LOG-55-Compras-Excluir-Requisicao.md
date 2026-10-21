---
id: LOG-55
aliases: ["Contrato 55", "55-Compras-Excluir-Requisicao"]
tags: [contrato, contrato-sql, contrato-api, compras, requisicao]
criado: 2026-10-20
atualizado: 2026-10-20
status: proposta
sistemas: [hub-banco, hub-api, hub-front]
dono: "Nathan"
etapa_0b: [C0, C1]
fontes: ["av-hub: app/api/compras/requisicoes/[id]/route.ts (GET e PATCH, sem DELETE)", "av-hub: components/Compras/Kanban/RequisicoesKanban.tsx:27-48 (matriz de status)", "av-hub: components/Compras/ComprasRequisicoes.tsx (lista)", "LOG-35 (cancelar exige motivo e vai ao MES)", "SQL-008 (requisicoes_compra)"]
criado_original: 2026-10-20
---

# Contrato 55 — Compras: excluir requisição de compra

> **Onde atua:** av-hub: banco, API, front

> [!info] Situação em 20/10/2026
> **Status:** `proposta` · **Pasta:** `Ativos` · **Dono:** Nathan (front); Gustavo (DBA) e a API entregam o resto
>
> - ✅ **Front (av-hub) escrito, ainda não verificado na tela:** botão "Excluir" na lista de Requisições, confirmação, rota `DELETE /api/compras/requisicoes/:id` no BFF. Sem a API, o botão devolve o erro do backend.
> - 🔴 **Banco e API: não existem.** Hoje a requisição só tem `GET`, `PATCH` de status e `POST`. Não há `deleted_at` em `requisicoes_compra` nem rota `DELETE`.
> - ✅ **Q1 decidida (20/10):** só a criada no Hub; a do MES continua cancelada com motivo.
> - 🔴 **Pergunta aberta** (seção 6): o perfil Comprador ter `pode_deletar` em `compras` (Q2).

## 1. Por quê

O comprador não consegue apagar uma requisição. Só existe **cancelar** (kanban: arrastar para "Cancelada" com motivo), que serve para a requisição do MES, porque o motivo volta ao PCP ([[LOG-35-Compras-Marcos-Requisicao-para-MES]]). Para a requisição **criada à mão no Hub** (erro de digitação, duplicada, teste) o cancelamento deixa lixo na fila e na coluna "Cancelada" para sempre.

## 2. Regras

| # | Regra | Selo |
|---|---|---|
| 1 | Excluir é **exclusão lógica** (`deleted_at`, `deleted_by`): a linha fica no banco para auditoria. Nada de `DELETE` físico | 🟡 |
| 2 | Só exclui requisição **sem OC** (`id_ordem_compra IS NULL`) e com status diferente de `atendida` | 🟡 |
| 3 | Só exclui requisição **criada no Hub** (`id_origem IS NULL`). A que veio do MES se **cancela com motivo**; apagar deixaria o MES com a parcial pendurada | 📝 Q1 (Nathan, 20/10) |
| 4 | Requisição excluída some de **todas** as leituras (lista, resumo, kanban, eventos para o MES, `GET /:id` devolve 404) e não conta nos KPIs | 🟡 |
| 5 | Quem exclui precisa de `pode_deletar` na tela `compras` **e** ser comprador da unidade (`codigo_empresa`) da requisição, como já vale para fechar a compra | 🟡 Q2 |
| 6 | Excluir requisição **já vinculada a pedido de venda** (`numero_pedido_venda`) é permitido: o vínculo é só referência. A API recalcula o "saldo a comprar" do pedido | 🟡 |
| 7 | Excluir **não gera evento** para o MES (a regra 3 garante que o MES nunca soube dela) | 🟡 |

## 3. Banco (Gustavo)

```sql
ALTER TABLE core_vendas_faturamento.requisicoes_compra
  ADD COLUMN deleted_at timestamptz,
  ADD COLUMN deleted_by uuid REFERENCES auth.usuarios(id);

-- Só pode excluir o que a regra 2 e 3 permitem. A trigger é a rede de segurança
-- (a API valida antes e devolve a mensagem legível).
CREATE OR REPLACE FUNCTION core_vendas_faturamento.fn_requisicao_compra_bloqueia_exclusao()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
    IF OLD.id_ordem_compra IS NOT NULL OR OLD.status = 'atendida' THEN
      RAISE EXCEPTION 'Requisição com OC não pode ser excluída' USING ERRCODE = 'P0001';
    END IF;
    IF OLD.id_origem IS NOT NULL THEN
      RAISE EXCEPTION 'Requisição do MES não pode ser excluída: cancele com motivo' USING ERRCODE = 'P0001';
    END IF;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_requisicao_compra_bloqueia_exclusao
  BEFORE UPDATE OF deleted_at ON core_vendas_faturamento.requisicoes_compra
  FOR EACH ROW EXECUTE FUNCTION core_vendas_faturamento.fn_requisicao_compra_bloqueia_exclusao();
```

- Toda **view e função** que lê `requisicoes_compra` (lista, resumo, eventos, saldo a comprar do pedido de venda) passa a filtrar `deleted_at IS NULL`. O DBA confere a lista e devolve quais mexeu.
- O índice único de `numero_requisicao` não muda: o número excluído **não é reaproveitado**.
- Os nomes do schema, da tabela e de `auth.usuarios` seguem [[SQL-008-Requisicoes-Compra]]; conferir contra o banco antes de aplicar.

## 4. API (`api-acos-vital`)

`DELETE /compras/requisicoes/:id`, corpo `{ "deleted_by": "<uuid do usuário>" }` (o BFF manda o da sessão, nunca o do navegador).

| Resposta | Quando |
|---|---|
| `200 { "success": true }` | Marcou `deleted_at` e `deleted_by` |
| `404` | Não existe ou já excluída |
| `403` | Sem `pode_deletar` em `compras`, ou comprador de outra unidade |
| `409` com `error` legível | Tem OC / está `atendida` (regra 2): "Requisição com OC não pode ser excluída" |
| `409` com `error` legível | Veio do MES (regra 3): "Requisição do MES não pode ser excluída: cancele com motivo" |

O `error` dos 4xx é repassado ao usuário como está (o BFF já faz isso em `respostaDeErro`), então a frase precisa ser clara para o comprador. Seguir o padrão de [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] (autenticação, escopo e erros).

## 5. Front (Nathan) — escrito

- `app/api/compras/requisicoes/[id]/route.ts`: `DELETE`, exige `pode_deletar` em `compras`, repassa para a API.
- `services/compras/requisicoes.ts`: `excluirRequisicaoCompra`.
- `components/Compras/acoes.ts`: `excluirRequisicao`; `helpers.ts`: `podeExcluirRequisicao` (regras 2 e 3, só para esconder o botão).
- `components/Compras/ComprasRequisicoes.tsx`: link "Excluir" na linha (some se faltar permissão, não for comprador da unidade ou a regra 2/3 barrar) e modal de confirmação.

## 6. Perguntas

| # | Pergunta | Para | Padrão adotado |
|---|---|---|---|
| Q1 | O comprador precisa **excluir requisição que veio do MES** (e não só cancelar)? Se sim, o MES precisa ser avisado (novo marco) e o polling por `id_origem` não pode recriá-la | Nathan, Robert | ✅ **Decidido (Nathan, 20/10): não**; só a criada no Hub, a do MES se cancela com motivo |
| Q2 | O perfil **Comprador** recebe `pode_deletar` em `compras`? Sem isso o botão não aparece, mesmo com tudo pronto | Nathan (perfis) | Ajustar o perfil no banco, não no código |

## 7. Como testar

1. Comprador cria uma requisição manual → "Excluir" aparece → confirma → some da lista e dos KPIs.
2. Requisição do MES: botão não aparece; `DELETE` direto na API devolve `409`.
3. Requisição com OC: botão não aparece; `409` pela API.
4. Comprador de outra unidade: botão não aparece; `403` pela API.
5. `GET /compras/requisicoes/:id` da excluída devolve `404`; `GET .../resumo` não a conta.
