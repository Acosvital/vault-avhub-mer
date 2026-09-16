---
tags: [erp-acos-vital, app-pcp, dados]
criado: 2026-09-16
atualizado: 2026-09-16 (v2 - confrontado com backend real)
---

# app-pcp — Modelo de Produção

## Entidades

- **Pedido** — `sistema` (OMIE | TOTVS | MANUAL), `pedidoVenda`, `ordemProducao`, cliente, vendedor, `prazoEntrega`, `prioridade` (BAIXA/NORMAL/ALTA/URGENTE), `status` (AGUARDANDO/EM_PRODUCAO/BLOQUEADO/ENTREGUE), `idFabrica`, `anexoOrdemProducaoUrl`, `anexoPendente`. "Atrasado" (destaque visual vermelho na lista) = `prazoEntrega < hoje && status !== 'ENTREGUE'`.
- **Item** — pode vir do Omie (`idOmie` preenchido, `bloqueado = true`, conteúdo não editável) ou ser manual; cada item é atribuído a uma **fábrica**. Item sem fábrica atribuída = tratado como **revenda**, excluído do payload de salvamento e nunca entra na produção/PCP.
- **Fábrica** — código, nome; tem N **setores** vinculados (tabela de junção FabricaSetor).
- **Setor** — código, nome, `exigeMaquinaOperador` (existe no schema, sem formulário ainda).
- **Máquina** — vinculada a um setor, com foto.
- **Operador** — cadastro simples (nome).
- **Roteiro** — lista ordenada de `{ idSetor, ordem }` por pedido/fábrica — o caminho que o item percorre pelas etapas de produção. Conceito clássico de *routing* de PCP/MRP. Submetido como array 0-indexado, onde a ordem do array = ordem de clique na UI.

## Fluxo de criação de pedido (visto no código — completo, não mais "próxima etapa")

`app/(protected)/pedidos/novo/page.tsx` é um formulário único e longo com seções progressivas, não um wizard/stepper:

1. **Origem do Pedido** — seletor `SistemaOrigem`. Se OMIE: botão "Buscar no Omie" (`consultarOmie`) traz cliente/vendedor (travados) + itens (`bloqueado: true`); se não encontrado, cai automaticamente para MANUAL. TOTVS/MANUAL: tudo digitado à mão, com campo opcional de anexo de Ordem de Produção (só TOTVS — se vazio, fica marcado como pendente de anexo).
2. **Dados do Pedido** — cliente/vendedor/prazo/prioridade.
3. **Itens** — tabela editável (código, descrição, quantidade, unidade, valor unitário, fábrica por item); linha de adição manual só aparece quando `sistema !== 'OMIE'`.
4. **Roteiro de Produção** — para cada fábrica em uso (uma aba por fábrica, com badge de pendência se 0 etapas), carrega os setores daquela fábrica e monta a sequência por **clique-para-ordenar**: clicar num setor não selecionado o acrescenta ao fim da fila (mostra a posição numérica); clicar de novo remove. Uma faixa "Fluxo" mostra o resultado como `Setor A → Setor B → Setor C`.
5. **Validação antes de salvar**: pedido/cliente/vendedor/prazo obrigatórios; ≥1 item; ≥1 item com fábrica atribuída; **toda** fábrica em uso precisa ter roteiro não vazio.
6. **Salvamento**: como cada "pedido" no backend é por grupo de fábrica, o formulário chama `POST /pedidos/completo` **uma vez por fábrica em uso**, sequencialmente, com barra de progresso e tratamento de falha parcial (relata quais grupos já foram criados antes de uma falha no meio do caminho).

## Backend real é bem mais rico que este modelo (visto pelo frontend)

O backend real (`api-pcp`, NestJS+Prisma) modela produção com muito mais detalhe do que o roteiro simples descrito acima: estado por item (`ItemParcial`, 8 estados, com split/consolidação/devolução entre setores), entregas parciais ao cliente como entidade própria, embalagem/paletização, anexos por etapa e histórico imutável de movimentação. Ver [[App-PCP-Backend-Producao]] para o modelo completo — este arquivo documenta só o que o frontend enviado usa hoje.

## Ponto de atenção: `SistemaOrigem`

O enum inclui `TOTVS` além de `OMIE` e `MANUAL` — vale confirmar com o usuário se há uso real ou planejado de TOTVS na Aços Vital, ou se é só um placeholder genérico.

## Lacunas confirmadas (não hipóteses)

- **Sem página de detalhe/edição de pedido** (`/pedidos/[id]` não existe) — depois de criado, um pedido só aparece na lista; não há forma de reabrir, editar itens/roteiro ou avançar status pela UI.
- **Sem transição de status visível** — `status` (AGUARDANDO/EM_PRODUCAO/BLOQUEADO/ENTREGUE) é só exibido como chip; nenhum botão de ação existe hoje para mudá-lo.
- **Sem board de produção** (kanban por setor/status) — ver [[App-PCP-Visao-Geral]]. O modelo de dados (roteiro = setor + ordem) já sustentaria uma visão assim, mas ela não existe no frontend hoje.

## Relação com o restante do fluxo

Este é o sistema que hoje executa a sub-rota [[Fabricacao-Flanges|Flanges]] de [[Rota-Fabricacao]]. Não cobre [[Fabricacao-Chapas|Chapas]] nem [[Fabricacao-Grades-Piso|Grades de Piso]] — não há evidência, até agora, de sistema dedicado para essas duas.

## Ver também
- [[App-PCP-Visao-Geral]]
- [[App-PCP-Backend-Producao]]
- [[Fabricacao-Flanges]]
