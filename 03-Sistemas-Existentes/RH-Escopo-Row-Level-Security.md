---
tags: [erp-acos-vital, av-hub, rh, seguranca, rbac]
criado: 2026-09-16
---

# av-hub — Escopo por Setor/Unidade (Row-Level Security sobre o RBAC)

Camada de segurança **adicional** ao RBAC de telas/permissões (ver [[AV-Hub-RBAC]]): mesmo com permissão de tela concedida, o **conjunto de linhas** que um usuário vê/edita é restrito por vínculo organizacional. Já implementada e confirmada por leitura de código no backend `api-acos-vital` (commit `fa27d00`).

## Escopo por unidade (empresa)

- `usuarios_unidades` — vínculo N:N usuário↔unidade.
- **Convenção: "sem vínculo = irrestrito"** — usuário sem nenhuma linha em `usuarios_unidades` enxerga todas as unidades.

## Escopo por setor (RH)

- Resolução: `auth.usuarios.id_funcionario → core.funcionarios.id_setor`.
- **Convenção oposta à de unidade: "sem vínculo = vazio"** — usuário sem `id_funcionario` vinculado vê **zero** funcionários em `GET /funcionarios` (não todos). Implementado em `src/middlewares/escopoSetor.js` (`buscarSetores`), aplicado via `resolverEscopoSetor` em `/funcionarios` (GET lista, GET por id, POST, PUT, DELETE) — deliberadamente **não** aplicado em `/setores`, `/cargos` ou `/unidades` (esses dropdowns continuam abertos para todos).
- **Override `setor_irrestrito`** — coluna booleana em `auth.usuarios` (default `false`). Quando `true`, ignora a checagem de setor **antes** de qualquer outra regra (`if (usuario.setor_irrestrito === true) return null`) — precedência clara mesmo para um usuário que também tem `id_funcionario` vinculado.
- Ambas as regras (`escopoSetor` + `setor_irrestrito`) foram resolvidas no mesmo commit (`fa27d00`, mensagem: *"add setor_irrestrito field for enhanced access control..."*), e ainda precisam de reteste ao vivo (não só verificação de código) antes de serem consideradas 100% fechadas em produção.
- Contraste com escopo de unidade: duas convenções de "vazio" **opostas** dentro do mesmo sistema (irrestrito vs. vazio) — vale documentar isso explicitamente para quem for implementar escopo em módulos novos (Estoque, por exemplo), para não replicar a inconsistência sem perceber.

## Papel implícito derivado de combinação de permissões

Achado na tela de RH → Solicitações de Vagas (workflow de aprovação de headcount): não existe uma flag "é aprovador" — o frontend infere isso a partir da combinação exata de permissões do usuário na tela: `isApprover = canOnly('pode_editar', 'pode_visualizar')` (tem editar+visualizar, mas não criar/deletar). Quem se qualifica só vê os botões de decisão (aprovar/reprovar); quem tem o CRUD completo vê a tela cheia. É um padrão de "papel por composição de permissões" em vez de papel nomeado — funciona, mas é implícito e frágil a mudanças futuras na matriz de permissões.

## Vínculo Vendedor ↔ Funcionário (RH) — migração em andamento

Contrato documentado para ligar cada linha de `core_vendas_faturamento.vendedores` (uma por conta Omie — Mogi/Uberaba) ao `core.funcionarios` correspondente via `vendedores.id_funcionario` (FK já existe), substituindo a tabela antiga `pessoa_vendedor` (solta, mantida por texto, sem ligação com RH). Isso passa a dar ao módulo comercial acesso a cargo/setor/unidade "de casa" de cada vendedor, via `JOIN` direto em vez de casar array de texto.

- **Backfill** (SQL de referência documentado) popula `id_funcionario` a partir do nome já mapeado em `pessoa_vendedor`; o que sobrar sem match automático vira fila de decisão humana direto na tela de Vendedores já existente (não é uma tela nova).
- **Endpoint de sugestão** (`GET /vendedores/:id/sugestoes`) detectaria o caso concreto de ~5 vendedores com o mesmo nome nas duas contas Omie (Mogi + Uberaba) — **hoje devolve 500**, e uma verificação por código (commit `fa27d00`) não encontrou sequer essa rota no arquivo de rotas atual (`src/routes/vendedores.js` só tem POST/GET/GET-by-id/PUT/DELETE) — ou foi removida, ou mudou de nome/serviço; precisa reconfirmar a referência antes de tratar como bug a corrigir.
- **Rollout planejado**: rodar a view antiga (`pessoa_vendedor`) e a nova (`id_funcionario`) em paralelo por um mês fechado, comparar totais, só então trocar as 4 funções de ranking/detalhe (`fn_ranking_vendedores_vendas/faturamento`, `fn_detalhe_vendedor_vendas/faturamento`) de vez.
- **Status real (03/09):** backfill **não rodou ainda** (testado ao vivo: vendedores reais seguem com `id_funcionario: null`) — é estado de dado, não de código, então não dá para confirmar/negar por leitura do backend.

## Por que isso importa para o ERP unificado

Este é o modelo de row-level security mais maduro entre os sistemas analisados — mais sofisticado que uma simples checagem de perfil. Um módulo de Estoque (ou qualquer módulo novo) que precise de escopo por unidade/setor/depósito deveria reaproveitar este padrão (com convenções de "vazio" explicitamente decididas, não herdadas por acidente) em vez do modelo de grupos do Azure AD proposto no PRD do Estoque — ver [[Achado-Duplicacao-RBAC]].

## Ver também
- [[AV-Hub-RBAC]]
- [[Achado-Duplicacao-RBAC]]
- [[AV-Hub-Bugs-Catalogo]]
- [[Organograma-Visao-Geral]]
