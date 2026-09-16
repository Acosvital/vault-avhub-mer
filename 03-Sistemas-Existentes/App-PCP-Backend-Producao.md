---
tags: [erp-acos-vital, app-pcp, dados]
criado: 2026-09-16
---

# api-pcp — Modelo Real de Produção (backend NestJS+Prisma)

Modelo bem mais rico que o visto pelo frontend `app-pcp` — este é o "motor" real de chão de fábrica. Todas as entidades abaixo já existem e têm services implementados, mesmo sem tela correspondente no frontend enviado.

## `ItemParcial` — o motor de estado real (não é "entrega parcial")

Cada `ItensPedido` nasce com **um** `ItemParcial` cobrindo 100% da quantidade — "parcial" aqui significa **fração/lote de produção em trânsito pelo roteiro**, não entrega parcial ao cliente (isso é a entidade `Entrega`, separada, ver abaixo).

- **Estados**: `CRIADO → RECEBIDO → EM_ANDAMENTO → EM_TRANSITO → PAUSADO/RETRABALHO → CONCLUIDO`, mais `CANCELADO`.
- **Ações do workflow** (`itens-parciais.service.ts`): `receber`, `mover` (avança pro próximo passo do roteiro), `concluir` (só no último passo), `pausar`, `retrabalho`, `retomar`, `split` (divide o lote), `devolver` (rejeita de volta pro setor anterior — a linha atual vira `CANCELADO`, nasce uma nova `EM_TRANSITO` ligada por `idDevolvidoDe`), `cancelar`, `desfazerRecebimento`, `consolidar` (junta parciais divididos de volta), e `acaoLote` (ação em lote sobre múltiplos IDs, sucesso/falha por item).
- **Concorrência**: todas as transições usam `updateMany({where:{id, status: ESPERADO}})` + `count===0 → erro de conflito`, em vez de ler-depois-escrever — retrofit deliberado (24/08/2026) depois de um risco de race condition identificado em 7 ações.
- **`HistoricoItemParcial`** — trilha de auditoria imutável de toda transição (setor, status, operador/máquina no momento), usada só para timeline/relatórios/dashboard — nunca para saber o estado atual (isso é sempre `ItemParcial`).

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
- Ambos só atrás de `JwtAuthGuard` — sem RBAC ainda, consistente com o adiamento geral do RBAC (ver [[App-PCP-Visao-Geral]]).

**Confirma a hipótese**: a home vazia do frontend `app-pcp` não é falta de dado — é só falta de tela consumindo o que já existe.

## RBAC — `PerfilSetor` e o adiamento deliberado

Além do RBAC de telas idêntico ao padrão do av-hub, existe `PerfilSetor` (visualizar/atuar por perfil×setor), usado só na tela de Movimentações e explicitamente **não** tratado como fronteira de segurança real (é conveniência de UI; a checagem de verdade é no service). O `TODO.md` do projeto documenta a decisão consciente de **adiar a aplicação do RBAC de CRUD a todos os 16 controllers de domínio** até desenhar um modelo de permissão por instância de setor — com um aviso de rollout explícito: ativar o guard sem antes semear Telas/Permissão/perfil admin no mesmo deploy trancaria todos os usuários fora, inclusive a fábrica de Flanges já em produção.

## Auditoria e LGPD

`AuditoriaLogin` (toda tentativa de login, base do rate limiting — 5 falhas/usuário ou 20/IP em 15 min, sem Redis, query de janela deslizante contra a própria tabela) e `AuditoriaAcesso` (toda chamada de API, via interceptor global). `Usuario.anonymizedAt` — suporte a anonimização estilo LGPD (preserva a linha para integridade de FK em auditoria, apaga dado pessoal); diferente do av-hub, que **não** tem esse campo (corrigido 16/09, ver [[AV-Hub-RBAC]]).

## Relação com Ordem de Serviço / Ordem de Produção (achado novo, 16/09)

Os áudios do gerente descrevem o PCP emitindo **Ordem de Serviço (OS)** — pra beneficiamento/retrabalho de um item de Revenda ou Fabricação (ex.: corte de chapa, retrabalho pós-reprovação) — e **Ordem de Produção (OP)** — pra iniciar a fabricação de um item numa linha própria (Flange etc.), conforme a necessidade do fluxo.

**Decidido (16/09): segue a hipótese (a)** — OS e OP são o mesmo mecanismo de `roteiro`/`ItemParcial` (8 estados) já implementado aqui, não entidades novas. Reforça essa escolha o fato de `PedidoAnexo.tipo` **já ter `ORDEM_PRODUCAO`** no enum (ao lado de NOTA/CANHOTO/DESENHO/PEDIDO/COMPROVANTE_ENTREGA) — sugere que o próprio time já modelou "Ordem de Produção" como o **documento** gerado a partir do fluxo do `ItemParcial`, não como uma state machine paralela. OS de beneficiamento de Revenda (ex.: corte de chapa) provavelmente precisa de uma Fábrica/Setor leve cadastrada só pra isso (ex.: "Beneficiamento" → setor "Corte") pra caber no modelo existente — detalhe de modelagem a confirmar com Robert, não decisão de arquitetura.

Ver [[Fluxo-Detalhado-Pedido-Item]] para o fluxo completo descrito pelo gerente.

## Ver também
- [[App-PCP-Visao-Geral]]
- [[App-PCP-Modelo-Producao]]
- [[Estoque-Riscos]]
- [[Achado-Duplicacao-RBAC]]
- [[Fluxo-Detalhado-Pedido-Item]]
