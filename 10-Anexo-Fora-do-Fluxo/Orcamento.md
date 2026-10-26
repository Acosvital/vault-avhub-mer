---
tags: [anexo, orcamento, av-hub, comercial, fora-do-fluxo]
criado: 2026-10-14
atualizado: 2026-10-26
status: arquivado
dono: Pablo
fontes: [api-acos-vital f322dcd src/schemas/core_compras/aggregates/orcamento, HUB b55ac55 lib/orcamento e app/api/orcamento, Dump Avhub 14/10, LOG-42, v1 LOG-07a]
---

# Orçamento

> [!warning] Arquivado em 26/10/2026
> O Orçamento entrou no fluxo mestre (`B1` a `B4`, N16-07, N16-16). A nota vigente é [[12-Orcamento-Base-de-Preco]], que diz o que aconteceu com cada item desta. Esta nota fica só como registro do estado de 14/10.

Fora do fluxo 0b. Decisão do Nathan de 07/10 (item 39 do v1): o orçamento é desenvolvido por fora, no módulo Comercial & Suprimentos ([[Comercial-Suprimentos]]); a tela e o código legado do HUB saem quando o módulo novo a substituir 🟡 ([[LOG-42-Coordenadores-e-Orcamento-sair-do-JSON-do-Repositorio]], proposta).

## Estado

| Item | Estado | Selo |
|---|---|---|
| Tabelas `orc_*` e views `orc_vw_*` no banco | `orc_categorias`, `orc_cotacoes`, `orc_familias`, `orc_fornecedores`, `orc_produtos`, `orc_vinculos` e as views | ✅ Dump Avhub, schema `core_compras` |
| Rotas `/orcamento` na API | `GET /fornecedores`, `/fornecedores/:codigo`, `/produtos`, `/cotacoes`, `/vinculos`, `/categorias`, `/familias` | ✅ `orcamento.route.js:140-328` |
| Telas do HUB | `orcamento/categorias`, `fornecedores`, `historico-produtos`, `sem-cadastro`, `vinculos` | ✅ `app/(protected)/orcamento/**` |
| De onde o HUB lê | **Dos JSON do repositório**, não da API: `lib/orcamento/data/*.json` (fornecedores, histórico de preços, produtos, vínculos, categorias, famílias), com busca e ordenação em memória | ✅ `lib/orcamento/dados.ts:60,75`, `app/api/orcamento/fornecedores/route.ts:3` |
| Marcas `GAMBIARRA` do contrato 42 (O1, O2) | Ainda no código | ✅ `lib/orcamento/dados.ts:60,75` |

## Consequência

A API existe e nada a consome. Os JSON (dados reais de fornecedores com CNPJ, e-mail e telefone, 4,4 MB) seguem versionados no git do HUB 🔴. Decisão pendente: migrar a tela para a API ou removê-la com a chegada do Comercial & Suprimentos; o v1 propôs remover 🟡. Dono da decisão: Nathan; execução do front: Nathan; endpoints de apoio, se migrar: Gustavo.

Mesma pendência dos coordenadores em [[Comissoes]].
