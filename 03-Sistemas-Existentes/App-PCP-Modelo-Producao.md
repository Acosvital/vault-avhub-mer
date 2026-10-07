---
tags: [erp-acos-vital, app-pcp, dados]
criado: 2026-09-16
atualizado: 2026-10-07
---

# app-pcp — Modelo de Produção

> Status: decidido | no código | em produção (verificado em 07/10/2026 pelo dump, onde indicado). Decisões da rodada em [[Registro-de-Decisoes-2026-10-07]]. MES = Robert.

> **Atualização de 07/10/2026 — auditoria código × vault (leitura de `develop`, `ca3346b` api / `a802a3e` app; não é produção). `main` dos dois repositórios parou em 28/08: tudo o que é posterior está só em `develop`.** **Decidido (✅ Nathan, 07/10):** merge `develop` → `main` **antes do piloto** (fecha CC-04); **data e responsável: 🔴 Robert**. A `develop` roda no ambiente de homologação `https://mes-test.acosvital.com.br/` (`mes-test`, ✅ no ar; marco M2 cumprido); o `main` não foi dado como em produção.
> - **`SistemaOrigem` hoje é `OMIE` \| `MANUAL`** — o `TOTVS` foi removido em 09/09 (migration `...remove_totvs_sistema_origem`). A "pergunta sobre TOTVS" da seção "Ponto de atenção" está respondida pelo código.
> - **O formulário `pedidos/novo` e o `POST /pedidos/completo` por fábrica foram substituídos:** a criação é Carteira (`/carteira`) → Ordens de Produção, com `POST /pedidos/completo/lote` (01/10). A rota antiga `POST /pedidos/completo` foi **apagada** no PR #50 (07/10). A seção "Fluxo de criação de pedido" abaixo é **histórica** (agosto).
> - **Tipos de setor hoje:** `PRODUTIVO`, `ESTOQUE`, `COMPRAS`, `EXPEDICAO`, `REQUISICAO`, `LOGISTICA_ENTRADA`, `QUALIDADE` (o "a ganhar" de 24/09 virou código: tarefa C6, migration `20260925120000_c6_tipos_fabrica_setor`). Fábricas: Flange (`FABRICACAO`) e Revenda (`REVENDA`). O circuito de compra (Requisições, Compras, Recebimento, Qualidade · Entrada) fica **fora do roteiro** da fábrica (`circuito-compra.ts`). Lista de setores, códigos e telas em [[App-PCP-Recebimento-Conferencia]].
> - A carteira lê `/pedidos_liberados` do av-hub (contrato 26, `901f9bb`/`65df59b`, 24 e 29/09). A tarefa C4 está concluída no código; C8 ("novo norte", `RoteiroItem` lido por mover/concluir/Expedição) **não foi feita**: hoje só existe a tela `/decisoes-pcp`, que trata divergência de recebimento.
> - Panorama do banco: 50 migrations e 44 modelos Prisma (ver [[App-PCP-Visao-Geral]]).

> **Atualização (24/09/2026, branch `develop`).** Parte desta nota descreve a versão de agosto. O que mudou e importa para o fluxo: a criação de pedido virou **Carteira de Pedidos** (`/carteira`) → **Nova Ordem de Produção** (`/ordens-producao/novo`), aberta só a partir da Carteira, **sem digitação manual** (tudo vem do Omie pelo gateway) e com **quantidade parcial por envio** (rodadas); `TOTVS` saiu do enum; existe tela de detalhe da OP (`/ordens-producao/[id]`). E o **encaixe do Estoque e da Revenda** foi decidido — `Fabrica.tipo` (`FABRICACAO`/`REVENDA`), `Setor.tipo` (`PRODUTIVO`/`ESTOQUE`/`COMPRAS`), setor Estoque como etapa 1 de todo roteiro, setor "Emissão de Ordens" fora do roteiro. Ver [[Encaixe-Estoque-Revenda-no-PCP]].

## Entidades

- **Pedido** — `sistema` (OMIE | ~~TOTVS~~ *(removido em 09/09)* | MANUAL), `pedidoVenda`, `ordemProducao`, cliente, vendedor, `prazoEntrega`, `prioridade` (BAIXA/NORMAL/ALTA/URGENTE), `status` (AGUARDANDO/EM_PRODUCAO/BLOQUEADO/ENTREGUE), `idFabrica`, `anexoOrdemProducaoUrl`, `anexoPendente`. "Atrasado" (destaque visual vermelho na lista) = `prazoEntrega < hoje && status !== 'ENTREGUE'`.
- **Item** — pode vir do Omie (`idOmie` preenchido, `bloqueado = true`, conteúdo não editável) ou ser manual; cada item é atribuído a uma **fábrica**. Item sem fábrica atribuída = tratado como **revenda**, excluído do payload de salvamento e nunca entra na produção/PCP. **Muda com o encaixe de 24/09/2026:** o item de revenda passa a ser enviado à **fábrica Revenda** (`Fabrica.tipo = REVENDA`) como qualquer outro, com roteiro próprio. A natureza do item é o tipo da fábrica escolhida na rodada, não um campo do item.
- **Fábrica** — código, nome; tem N **setores** vinculados (tabela de junção FabricaSetor). **A ganhar (24/09/2026):** `tipo` = `FABRICACAO` \| `REVENDA`.
- **Setor** — código, nome, `exigeMaquinaOperador`, `ativo`. **A ganhar (24/09/2026) — feito em 25/09, e hoje com mais tipos (ver bloco de 07/10 no topo):** `tipo` = `PRODUTIVO` (padrão) \| `ESTOQUE` \| `COMPRAS` — os dois últimos trocam as ações de receber/iniciar/mover pelas do subsistema. O setor Estoque é inserido pelo backend como etapa 1 de todo roteiro.
- **Máquina** — vinculada a um setor, com foto.
- **Operador** — cadastro simples (nome).
- **Roteiro** — lista ordenada de `{ idSetor, ordem }` por pedido/fábrica — o caminho que o item percorre pelas etapas de produção. Conceito clássico de *routing* de PCP/MRP. Submetido como array 0-indexado, onde a ordem do array = ordem de clique na UI. ⚠️ A UI (`toggleEtapaRoteiro`) não deixa o mesmo setor entrar duas vezes, e `pipeline.ts` indexa a etapa pelo `idSetor`. O roteiro da Revenda decidido em 24/09/2026 tem o setor Estoque no início **e** no fim — ver pendência 3 de [[Encaixe-Estoque-Revenda-no-PCP]].

## Fluxo de criação de pedido (histórico — agosto/setembro; **substituído em 01/10 por Carteira → Ordens de Produção**, ver bloco de 07/10 no topo)

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

~~O enum inclui `TOTVS` além de `OMIE` e `MANUAL` — vale confirmar com o usuário se há uso real ou planejado de TOTVS na Aços Vital, ou se é só um placeholder genérico.~~ **(resolvido em 07/10, conferido no código)** `TOTVS` foi removido do enum em 09/09 (migration `...remove_totvs_sistema_origem`); restam `OMIE` e `MANUAL`.

## Lacunas confirmadas (agosto — não reconferidas uma a uma em 07/10, exceto o que está no bloco do topo)

- **Sem página de detalhe/edição de pedido** (`/pedidos/[id]` não existe) — depois de criado, um pedido só aparece na lista; não há forma de reabrir, editar itens/roteiro ou avançar status pela UI.
- **Sem transição de status visível** — `status` (AGUARDANDO/EM_PRODUCAO/BLOQUEADO/ENTREGUE) é só exibido como chip; nenhum botão de ação existe hoje para mudá-lo.
- **Sem board de produção** (kanban por setor/status) — ver [[App-PCP-Visao-Geral]]. O modelo de dados (roteiro = setor + ordem) já sustentaria uma visão assim, mas ela não existe no frontend hoje.

## Relação com o restante do fluxo

Este é o sistema que hoje executa a sub-rota [[Fabricacao-Flanges|Flanges]] de [[Rota-Fabricacao]]. Não cobre [[Fabricacao-Chapas|Chapas]] nem [[Fabricacao-Grades-Piso|Grades de Piso]] — não há evidência, até agora, de sistema dedicado para essas duas.

## Ver também
- [[App-PCP-Recebimento-Conferencia]]
- [[Encaixe-Estoque-Revenda-no-PCP]]
- [[App-PCP-Visao-Geral]]
- [[App-PCP-Backend-Producao]]
- [[Fabricacao-Flanges]]
