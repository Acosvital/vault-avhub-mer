---
tags: [contrato-api, vendedores, cadastros, acessos]
criado: 2026-10-06
status: proposta
---

# Contrato 39 — Vendedores: fila de vínculo com o funcionário

**Para:** backend (`api-acos-vital`) · **Pequeno e aditivo** (nenhum campo existente muda).
Patch pronto em `39-anexos/0001-vendedores-fila-de-vinculo.patch`, feito sobre a `develop` em `c8f2f5e` e
testado na API local (banco = cópia de produção).

## 1. Por quê

A tela **Cadastros › Acessos › Vendedores** foi refeita como a de Compradores (av-hub#154): lista e
vínculo lado a lado, candidatos sem digitar, "Vincular" em um clique, sem esperar a lista recarregar.
Para isso, três coisas que hoje o av-hub não tem como pedir à API:

- **Fila de quem falta vincular** e o número do topo ("sem funcionário"): `GET /vendedores` não filtra por
  "sem funcionário". A tela antiga não tinha essa fila.
- **Nome do funcionário e do usuário vinculados**: `GET /vendedores` devolve só os uuids. A tela antiga
  baixava **todos** os funcionários (todas as páginas) e 200 usuários ao abrir, só para traduzir o uuid
  em nome — era parte da lentidão.
- **Setor e unidade dos candidatos**: a sugestão (`/vendedores/{id}/sugestoes`) devolve só o nome; a tela
  antiga filtrava "setor Vendas" no navegador.

## 2. O que muda (patch `0001`)

| # | Rota | O quê |
|---|---|---|
| **V1** | `GET /vendedores` | `?sem_vinculo=true` → só `id_funcionario IS NULL`. Ignorado se vier `id_funcionario` ou `id_funcionario_in`. |
| **V2** | `GET /vendedores` | Cada linha traz `nome_funcionario` (`core.funcionarios.nome_completo`) e `nome_usuario` (`auth.usuarios.username`), por subconsulta. |
| **V3** | `GET /vendedores/{id}/sugestoes` | Cada candidato traz `nome_setor`, `nome_unidade` (lotação no RH) e `desligado`; desligados vêm depois dos ativos. A ordem e o resto da resposta não mudam. |

Swagger atualizado no mesmo patch.

## 3. Depois de aplicado (av-hub)

A tela nova de Vendedores (branch `feat/vendedores-vinculo-rapido`, PR do av-hub) só pode subir
**depois** da API com este contrato: sem o V1 a fila e o número do topo saem errados (a API ignoraria o
filtro e contaria todos), sem o V2 a lista mostra "Funcionário vinculado" no lugar do nome.

Nada muda nos vínculos que já existem: a tela grava **só o campo alterado** (o BFF repassa apenas os
campos editáveis que vieram; a API grava só o que recebe). Conferido na API local: mudar comissão e
filial de um vendedor vinculado manteve funcionário, filial, ajuda de custo e nome de exibição.

## 4. Aceite (API local, 06/10/2026)

- `GET /vendedores?ativo=true&sem_vinculo=true&limit=1` → `total: 28` (de 88 ativos; 60 com funcionário).
- `GET /vendedores?ativo=true` → `ABNER LUIS CARDOSO RODRIGUES` com `nome_funcionario: "Abner Luiz Cardoso Rodrigues"`.
- `GET /vendedores/{id de "AÇOS VITAL"}/sugestoes` → `Amanda Vital` com `nome_setor: "Diretoria"`,
  `nome_unidade: "Aços Vital"`, `desligado: false`.
- Sem `sem_vinculo`, a listagem e a contagem são as de antes.
