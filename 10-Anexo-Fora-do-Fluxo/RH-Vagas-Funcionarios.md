---
tags: [anexo, rh, vagas, funcionarios, organograma, av-hub, fora-do-fluxo]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Gustavo (DBA)
fontes: [api-acos-vital f322dcd src/schemas/core_aprovacao_de_vagas e core_organograma, HUB b55ac55 app/(protected)/rh e app/api/vagas, LOG-02, LOG-03, LOG-04a]
---

# RH: vagas, funcionários e organograma

**Em uma frase:** o RH do HUB cuida de três coisas: pedidos de vaga (com aprovação), cadastro de funcionários e organograma.

**Quando consultar:** quando a dúvida é "quem decide uma vaga?" ou "o que existe de RH no sistema?". Esta nota fica fora do fluxo 0b. Os contratos [[LOG-02-Funcionarios-Listagem-Filtros-Ordenacao-Resumo]], [[LOG-03-Funcionarios-Cadastro-Organograma-Transacional]] e [[LOG-04a-Vagas-Fila-Decisao-no-Banco]] estão arquivados: o que vale é o código.

## Vagas

- A vaga nasce **pendente**. Só quem tem permissão de aprovar decide, pela rota de decisão; o histórico de decisões fica guardado.
- Editar a vaga não muda a situação. Se a vaga já foi decidida e alguém a edita, ela volta a **pendente**.
- A situação pode ser `aprovado`, `pendente` ou `reprovado`.
- A tela é `rh/solicitacoes-de-vagas`.
- ✅ Tudo isso existe no código.

## Funcionários e organograma

- ✅ Funcionários, cargos, setores e unidades existem, com escopo de unidade e de setor.
- ✅ O organograma tem rotas no banco e a tela de funcionários existe no HUB.
- ❓ A página do organograma no HUB não foi localizada.
- ❓ O vínculo do usuário com o funcionário apaga o usuário se o funcionário for apagado (era assim no v1; não relido no dump). Confirmar com o Gustavo.

## Pendências

- ❓ Gustavo confere em produção as migrations de vagas.
- ❓ Datas de admissão e desligamento quase vazias no RH (9 de 199 com admissão em 30/09, segundo o v1). Quem define a unidade do vendedor é o RH ([[Dashboards]]).

## Detalhe técnico

### Vagas

| Item | Estado | Selo |
|---|---|---|
| Rotas `/vagas` | `POST /`, `GET /`, `GET /resumo`, `GET /:id`, `GET /:id/decisoes`, `POST /:id/decisao`, `PUT` e `PATCH /:id`, `DELETE /:id` | ✅ `vaga.route.js:218-485` |
| Leitura | Sai da view `vw_vagas` (`custo_total` gerado pelo banco; `dias_pendente` e atenção a partir de `parametros_rh`) | ✅ `vaga.route.js` (cabeçalho) |
| Decisão | Só por `POST /vagas/:id/decisao` (função `fn_decidir_vaga`); exige `pode_aprovar` na tela `solicitacoes-de-vagas`; histórico em `vagas_decisoes` | ✅ `vaga.route.js:338` |
| Edição | `POST`, `PUT` e `PATCH` não mudam `situacao` (400 `SITUACAO_SO_PELA_DECISAO`); editar vaga já decidida a devolve a `pendente` e grava origem `edicao` em `vagas_decisoes` | ✅ regra fixa desde o contrato 38 |
| `situacao` | `aprovado`, `pendente`, `reprovado` (default `pendente`) | ✅ `vaga.model.js` |
| Tabelas no dump | `vaga`, `vagas_decisoes`, `parametros_rh`, `vaga_custo_total_legado` | ✅ Dump Avhub |
| Tela HUB | `rh/solicitacoes-de-vagas`; BFF `app/api/vagas` (`pode_visualizar`, `pode_criar`, `pode_editar`, `pode_deletar`, mais `[id]/decisao` e `[id]/decisoes`) | ✅ `app/api/vagas/route.ts:10,34`, `[id]/route.ts:9,32,68` |

### Funcionários e organograma

| Item | Estado | Selo |
|---|---|---|
| `/funcionarios`, `/cargos`, `/setores`, `/unidades` | Com escopo de unidade e de setor (`resolverEscopoUnidade`, `resolverEscopoSetor`, subárvore para cargos e setores) | ✅ `core/index.js:69-85` |
| Organograma | `/organograma_nodes`, `/vw_organograma_nodes`, `/niveis_hierarquicos`, `/historia`, `/welcome-presets`, `/welcome-settings` no schema `core_organograma` | ✅ `core_aprovacao_de_vagas/index.js` e `core_organograma/index.js` |
| Tela HUB de funcionários | `rh/funcionarios`; BFF `app/api/funcionarios` e `app/api/organograma_nodes` | ✅ |
| Tela de organograma no HUB | Só o BFF `organograma_nodes` e a tela de cargos foram achados; página do organograma não localizada | ❓ |
| Vínculo `auth.usuarios.id_funcionario` | `ON DELETE CASCADE` no v1: apagar o funcionário apagaria o usuário | ❓ não relido no dump; confirmar com o Gustavo |

### Pendências (detalhe)

- Conferir em produção as migrations de vagas (004 e a de 29/09, `fn_vaga_reabrir_por_edicao`) ❓ Gustavo.
- Dado de `data_admissao` e `data_desligamento` quase vazio no RH (9 de 199 com admissão em 30/09 segundo o v1); quem define a unidade do vendedor é o RH ([[Dashboards]]) ❓ Gustavo.
