---
tags: [erp-acos-vital, app-pcp, dados]
criado: 2026-09-16
atualizado: 2026-10-07
---

# api-pcp — Modelo Real de Produção (backend NestJS+Prisma)

> Status: decidido | no código | em produção (verificado em 07/10/2026 pelo dump, onde indicado). Decisões da rodada em [[Registro-de-Decisoes-2026-10-07]]. MES = Robert.

> **Atualização de 07/10/2026 — auditoria código × vault (leitura de `develop`, `ca3346b`; não é produção).**
> - **`main` do api-pcp parou em 28/08 (`be076b2`); tudo abaixo do que é posterior está só em `develop`** (54 commits à frente). **Decidido (✅ Nathan, 07/10):** merge `develop` → `main` **antes do piloto** (fecha CC-04); **data e responsável: 🔴 Robert**. A `develop` roda no ambiente de homologação `https://mes-test.acosvital.com.br/` (`mes-test`, ✅ no ar; marco M2 cumprido); o `main` não foi dado como em produção. Ver [[App-PCP-Visao-Geral]].
> - **"RBAC deliberadamente não aplicado a nenhum dos 16 controllers" é falso desde 04/09** (`e76e929`): `@RequirePermission` por controller (~20), `PerfilSetor` checado no service (`ensurePodeAtuar`). O `TODO.md` do api-pcp (24/08) está desatualizado. **Lacuna de segurança, achado de 07/10 a confirmar com o Robert:** `UsuariosController` e `SetoresController` sem guard; vários controllers só com JWT — detalhes na seção "RBAC" abaixo.
> - **Hoje:** 50 migrations (18/08 a 06/10), 44 modelos Prisma (`producao` 14, `estoque` 9, `fabricas` 6, `auth` 5, `compras` 5, `integracao` 3, `auditoria` 2). Módulos novos: carteira, ordens de produção, estoque (`/estoque/*`), qualidade (`src/qualidade`), requisições de compra, recebimento com conferência e decisões do PCP (ver [[App-PCP-Recebimento-Conferencia]]), fila de envio ao av-hub (outbox) e leitura de eventos. A nota abaixo descreve o núcleo de produção de agosto/setembro; o que mudou está marcado.
> - `HistoricoItemParcial.idUsuario` **aceita nulo** (ação do sistema, sem usuário humano). TOTVS removido do `SistemaOrigem` (09/09).
> - Rotas apagadas no PR #50 (07/10): `POST /pedidos/completo` (resta `/pedidos/completo/lote`) e `POST/DELETE /perfis/:id/permissoes[...]` (resta o `bulk`).

Modelo bem mais rico que o visto pelo frontend `app-pcp` — este é o "motor" real de chão de fábrica. Todas as entidades abaixo já existem e têm services implementados. ~~mesmo sem tela correspondente no frontend enviado~~ **(atualizado em 07/10)** parte já tem tela na `develop` (Movimentações, filas por setor, dashboard); a cobertura exata de telas por entidade não foi levantada.

## `ItemParcial` — o motor de estado real (não é "entrega parcial")

Cada `ItensPedido` nasce com **um** `ItemParcial` cobrindo 100% da quantidade — "parcial" aqui significa **fração/lote de produção em trânsito pelo roteiro**, não entrega parcial ao cliente (isso é a entidade `Entrega`, separada, ver abaixo).

- **Estados**: `CRIADO → RECEBIDO → EM_ANDAMENTO → EM_TRANSITO → PAUSADO/RETRABALHO → CONCLUIDO`, mais `CANCELADO`. *(Em `develop`, 24/09/2026, o front já lista também `REPROVADO` — 9 estados.)*
- **Setor Estoque na etapa 1 (decidido em 24/09/2026):** todo `ItemParcial` nasce no setor Estoque; a parte que o saldo cobre vira um **split** atendido (reserva + `CONCLUIDO`) e o restante é movido. A totalidade continua em `ItensPedido`; os splits somam o total. Ver [[Encaixe-Estoque-Revenda-no-PCP]].
- **Ações do workflow** (`itens-parciais.service.ts`): `receber`, `mover` (avança pro próximo passo do roteiro), `concluir` (só no último passo), `pausar`, `retrabalho`, `retomar`, `split` (divide o lote), `devolver` (rejeita de volta pro setor anterior — a linha atual vira `CANCELADO`, nasce uma nova `EM_TRANSITO` ligada por `idDevolvidoDe`), `cancelar`, `desfazerRecebimento`, `consolidar` (junta parciais divididos de volta), e `acaoLote` (ação em lote sobre múltiplos IDs, sucesso/falha por item).
- **Concorrência**: todas as transições usam `updateMany({where:{id, status: ESPERADO}})` + `count===0 → erro de conflito`, em vez de ler-depois-escrever — retrofit deliberado (24/08/2026) depois de um risco de race condition identificado em 7 ações.
- **`HistoricoItemParcial`** — trilha de auditoria imutável de toda transição (setor, status, operador/máquina no momento), usada só para timeline/relatórios/dashboard — nunca para saber o estado atual (isso é sempre `ItemParcial`). Não guarda autorização, passagem entre pessoas nem "com quem está"; a extensão proposta está em [[Rastreabilidade-e-SLA-de-Eventos]] e [[Campos-e-API-para-Rastreabilidade]].

## `Entrega` — entrega ao cliente, conceito distinto

Evento de entrega (total ou parcial) contra `ItensPedido`, opcionalmente ligado a um `ItemParcial` específico, com `numeroNf`. Reduz `ItensPedido.quantidadePendente`. É essa entidade — não o roteiro — que representa "quanto já foi entregue ao cliente".

## Embalagem/Paletização

`PedidoEmbalagem` (identificação + total de unidades) e `PedidoEmbalagemPallet` (identificação + peso, `Decimal(10,3)`) por pedido — sem campo de código de barras dedicado no schema hoje (só identificadores em texto).

## Anexos

`PedidoAnexo` (nível pedido, opcionalmente ligado a um item ou a uma entrega específica; `tipo`: NOTA/CANHOTO/DESENHO/PEDIDO/ORDEM_PRODUCAO/COMPROVANTE_ENTREGA) e `ItemParcialAnexo` (nível de etapa, ex.: foto de conclusão). Arquivos são só URLs (SeaweedFS presumido, sem client de storage implementado neste repo) — há um merge de PDFs (`pdf-lib`) para "imprimir" nota+canhoto+desenho+OP num PDF único.

## Divergência — estado e um possível "beco sem saída"

`ABERTA → EM_ANALISE → {RESOLVIDA | CANCELADA}` (ambos terminais). O endpoint genérico de atualização **recusa explicitamente** deixar fechar por ali (força o uso de `PATCH /divergencias/:id/resolver`), e `resolver()` dá erro se já estiver fechada. **Não existe endpoint de reabertura.** Sem histórico de git no pacote recebido para confirmar se isso é uma regressão do bug antigo documentado no [[Estoque-Riscos|PRD do Estoque]] ("nenhum estado deve ser beco sem saída", lição de um bug real no `/divergencias` de uma versão anterior do PCP) ou um gap novo — **vale perguntar diretamente ao Robert**.

## Dashboard — já pronto no backend

- `GET /dashboard` — contagem por `StatusPedido`, atrasados, urgentes, breakdown por setor (`itemParcial.groupBy` em `idSetorAtual`), top-10 pedidos atrasados, últimas 15 movimentações, contagem de divergências abertas/urgentes.
- `GET /dashboard/tv` — versão enxuta para TV de chão de fábrica, deliberadamente **sem cache** (comentário rejeita explicitamente um cache anterior como "band-aid de incidente, não decisão de arquitetura").
- Ambos só atrás de `JwtAuthGuard` — sem `@RequirePermission` (**conferido no código em 07/10**: `dashboard` e `relatorios` estão entre os controllers só com JWT; ver seção RBAC).

**(atualizado em 07/10)** A home vazia do frontend deixou de ser vazia: existe a tela de dashboard consumindo esses endpoints.

## RBAC — `PerfilSetor` e o adiamento deliberado (atualizado em 07/10)

> **Corrigido em 07/10 (conferido no código, `develop`).** O texto original (16/09) dizia que o RBAC de CRUD estava "deliberadamente não aplicado a nenhum dos 16 controllers", citando o `TODO.md`. **Isso é falso desde 04/09** (`e76e929`): `PermissionsGuard` + `@RequirePermission` estão por controller em ~20 controllers, e o `PerfilSetor` (default-deny) é checado no service (`ensurePodeAtuar`) em itens-parciais, entregas, compras e recebimento. Não há `APP_GUARD` global (C5 parcial). O `TODO.md` (24/08) está desatualizado. O parágrafo original segue abaixo como histórico.

**Lacuna de segurança — achado de 07/10/2026, a confirmar com o Robert:**
- `UsuariosController` (POST/GET/PATCH/DELETE) e `SetoresController` (CRUD): **sem guard algum**; só `:id/senha` e `:id/painel` têm JWT.
- **Guards do `api-pcp`:** 🟡 proposta adotada (Robert valida, item 12 do Registro): `JwtAuthGuard` + `PermissionsGuard` com `@RequirePermission` em `UsuariosController` e `SetoresController`, como em `perfis.controller.ts`; `GET /setores` fica só com sessão e o login Azure não pode ser bloqueado. 🔴 **Exposição de rede da `api-pcp` (há domínio público no Coolify?): Gustavo** (item 13).
- **Só JWT, sem `@RequirePermission`:** pedidos, itens-pedido, divergencias, anexos, observacoes, roteiro-item, dashboard, relatorios, auditoria.
- A barreira hoje é o BFF do app-pcp. A exposição de rede da api-pcp **não foi verificada**; se ela for acessível diretamente, essas rotas ficam sem controle fino.
- Modelo atual: `Usuario → Perfil → Permissao → Tela` (CRUD por tela) + `PerfilSetor` `(perfil, setor, podeVisualizar, podeAtuar)`. **Sem dimensão de filial** — a C3 (RBAC por filial, DEC-1) não foi iniciada.

*Texto original (16/09, histórico):* Além do RBAC de telas idêntico ao padrão do av-hub, existe `PerfilSetor` (visualizar/atuar por perfil×setor), usado só na tela de Movimentações e explicitamente **não** tratado como fronteira de segurança real (é conveniência de UI; a checagem de verdade é no service). O `TODO.md` do projeto documenta a decisão consciente de **adiar a aplicação do RBAC de CRUD a todos os 16 controllers de domínio** até desenhar um modelo de permissão por instância de setor — com um aviso de rollout explícito: ativar o guard sem antes semear Telas/Permissão/perfil admin no mesmo deploy trancaria todos os usuários fora, inclusive a fábrica de Flanges já em produção.

## Auditoria e LGPD

`AuditoriaLogin` (toda tentativa de login, base do rate limiting — 5 falhas/usuário ou 20/IP em 15 min, sem Redis, query de janela deslizante contra a própria tabela) e `AuditoriaAcesso` (toda chamada de API, via interceptor global). `Usuario.anonymizedAt` — suporte a anonimização estilo LGPD (preserva a linha para integridade de FK em auditoria, apaga dado pessoal); diferente do av-hub, que **não** tem esse campo (ver [[AV-Hub-RBAC]]).

## Relação com Ordem de Serviço / Ordem de Produção

Os áudios do gerente descrevem o PCP emitindo **Ordem de Serviço (OS)** — pra beneficiamento/retrabalho de um item de Revenda ou Fabricação (ex.: corte de chapa, retrabalho pós-reprovação) — e **Ordem de Produção (OP)** — pra iniciar a fabricação de um item numa linha própria (Flange etc.), conforme a necessidade do fluxo.

OS e OP são o mesmo mecanismo de `roteiro`/`ItemParcial` (9 estados na `develop`, 8 na `main`: `REPROVADO` é só da `develop`) já implementado aqui, não entidades novas. Reforça essa leitura o fato de `PedidoAnexo.tipo` **já ter `ORDEM_PRODUCAO`** no enum (ao lado de NOTA/CANHOTO/DESENHO/PEDIDO/COMPROVANTE_ENTREGA) — sugere que o próprio time já modelou "Ordem de Produção" como o **documento** gerado a partir do fluxo do `ItemParcial`, não como uma state machine paralela. ~~OS de beneficiamento de Revenda (ex.: corte de chapa) provavelmente precisa de uma Fábrica/Setor leve cadastrada só pra isso — detalhe de modelagem a confirmar com Robert.~~ **Confirmado com o Robert em 24/09/2026:** a Revenda é uma fábrica (`Fabrica.tipo = REVENDA`) com roteiro `ESTOQUE → COMPRAS → Recebimento → [beneficiamento] → Qualidade → ESTOQUE`, e o beneficiamento é um setor `PRODUTIVO` opcional dentro dela. Ver [[Encaixe-Estoque-Revenda-no-PCP]].

Ver [[Fluxo-Detalhado-Pedido-Item]] para o fluxo completo descrito pelo gerente.

## Ver também
- [[App-PCP-Recebimento-Conferencia]]
- [[App-PCP-Visao-Geral]]
- [[App-PCP-Modelo-Producao]]
- [[Estoque-Riscos]]
- [[Achado-Duplicacao-RBAC]]
- [[Fluxo-Detalhado-Pedido-Item]]
