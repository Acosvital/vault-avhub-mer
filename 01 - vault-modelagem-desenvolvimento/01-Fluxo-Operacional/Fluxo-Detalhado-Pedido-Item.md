---
tags: [erp-acos-vital, fluxo-operacional, fluxo-detalhado, pcp, compras, qualidade]
criado: 2026-09-16
---

# Fluxo Detalhado do Pedido — Nível de Item

> **Relação com [[Fluxo-Operacional-Visao-Geral]]:** são **dois modelos complementares, não um substituindo o outro**. O macro trata Estoque/Revenda/Fabricação como três categorias de destinação; este arquivo descreve o que acontece de fato, item a item, dentro dessas categorias — inclusive o fato de que "ter em estoque" na prática é uma **checagem** feita pelo PCP dentro de Revenda/Fabricação, não uma quarta rota isolada.

## Princípio central

Um item de pedido é classificado em dois eixos independentes pelo PCP — natureza (Revenda ou Fabricação) × disponibilidade (pronto em estoque, matéria-prima em estoque, ou sem estoque) — formalizado em [[Modelo-Destinacao-Item]]. Os caminhos possíveis:

1. **Já tem em estoque, pronto** → vai direto pra conferência/Qualidade → Expedição.
2. **Já tem em estoque, como matéria-prima** → vai pra beneficiamento/produção interna (OS ou OP) antes de Qualidade/Expedição.
3. **Não tem em estoque, é revenda** → gera requisição de Compra → Recebimento → (beneficiamento, se precisar) → Qualidade → Expedição.
4. **É de uma linha de Fabricação própria** (Flange hoje; outras linhas conforme cadastradas — ver [[Rota-Fabricacao]]) → vai direto pro sistema/roteiro daquela fábrica, avaliando disponibilidade de MP do mesmo jeito.

## Papéis e visão por módulo

| Módulo | O que visualiza | Ações principais |
|---|---|---|
| **Vendas** (av-hub) | Só a própria carteira (pedidos abertos e faturados); por item, a etapa atual do fluxo | Emissão do pedido; checkbox de inspeção de qualidade desde o início ou só no fim; acompanhamento em tempo real por item |
| **PCP** | Pedidos recém-chegados (aceite pendente) e itens que retornaram de outra área | Aceite do pedido; classificação do item (Flange/linha de fabricação, Revenda, ou já em estoque); checagem de saldo; emissão de requisição de compra, **Ordem de Serviço (OS)** ou **Ordem de Produção (OP)**, conforme a necessidade |
| **Compras** (av-hub, com reflexo no MES) | Só os itens com requisição gerada pelo PCP | Fecha a compra; sinaliza se o item chega **acabado** ou **não acabado**; referencia a Ordem de Compra (dado estruturado, não PDF — ver nota abaixo) |
| **Recebimento** | Itens comprados aguardando chegada física | Conferência quantitativa; método de conferência depende da flag acabado/não-acabado (ver abaixo) |
| **Qualidade** | Itens marcados por Vendas pra acompanhamento desde o início + itens acabados liberados por estoque/Recebimento | Inspeciona; aprova ou reprova (motivo + evidência, ex. foto de avaria) |
| **Expedição/Logística** | Itens com produção e qualidade 100% aprovadas | Embalagem, consolidação de carga, despacho — fiscal (NF) permanece no Omie, ver [[Faturamento-Expedicao]] |

## Fluxo passo a passo

### 1. Emissão e aceite

- Vendedor emite o pedido e decide, por pedido, se a Qualidade deve acompanhar **desde o início** (ex.: elaborar documento, validar entrada) ou só **no fim** (inspeção do item pronto). Se não marcar nada, Qualidade só é acionada no fim — evita notificar o setor sem necessidade.
- Pedido cai na fila do PCP com status "pendente". PCP dá o aceite ("despachando o pedido") — só então o vendedor vê o pedido avançar de status.

### 2. Classificação item a item (PCP)

Pra cada item do pedido, o PCP decide:

- **É de uma linha de Fabricação própria?** (Flange hoje) → vai pro roteiro daquela fábrica, ver [[Fabricacao-Flanges]] / [[App-PCP-Backend-Producao]].
- **Não é fabricação, é Revenda.** PCP verifica saldo:
  - **Tem em estoque, acabado** → marca "pronto em estoque" → cai automaticamente na fila da Qualidade.
  - **Tem em estoque, matéria-prima** (ex.: chapa inteira que precisa ser cortada) → PCP encaminha pra beneficiamento interno, emitindo **OS**.
  - **Não tem em estoque** → PCP gera requisição de compra; só esse item fica visível pra Compras (não o pedido inteiro).

A checagem do PCP cria a reserva (`reserva_estoque`) no mesmo passo em que marca um item como "tem em estoque" — não é só uma verificação de saldo de leitura. Isso evita a corrida entre pedidos concorrentes pelo mesmo lote, risco catalogado em [[Estoque-Riscos]] ("mesmo lote comprometido por PCP e por uma venda ao mesmo tempo"). Falta desenhar o mecanismo de expiração/liberação da reserva.

### 3. Compras

> Fluxo completo, conversa por conversa (do PCP gerando a requisição até o item virar saldo aprovado), detalhado em [[Fluxo-Compras-Completo]].

- Comprador só vê os itens com requisição gerada pelo PCP.
- Ao fechar a compra, sinaliza se o item vem **acabado** (compra A, vende A — não precisa de trabalho interno) ou **não acabado** (precisa de beneficiamento, ex.: chapa inteira que ainda vai ser cortada).
- Essa flag decide o resto do fluxo: item acabado vai direto pra conferência-padrão e Qualidade; item não acabado volta pro PCP pra abrir OS depois de conferido.
- Ordem de Compra referenciada aqui (ver [[MES-Arquitetura-Decisoes]], decisão 5) — decidida no av-hub. Anexar PDF manualmente é só a primeira fase; a intenção é trazer os dados da OC de forma estruturada, sem depender de upload/parse de PDF.

### 4. Recebimento

> Fluxo completo, conversa por conversa, em [[Fluxo-Recebimento-Completo]].

Método de conferência depende da flag definida por Compras:

- **Item acabado** → conferência **contra o Pedido de Venda** (o que chegou é literalmente o que o vendedor vendeu — "cara-crachá").
- **Item não acabado** → conferência **contra a Ordem de Compra** (o que chegou é o que o comprador comprou, não necessariamente igual ao que o vendedor vendeu — ex.: comprou chapa, vendeu flange que ainda vai ser fabricada a partir dessa chapa). Ao confirmar a entrada, o item **volta pro PCP** pra abrir a OS correspondente.

Isso é mais granular do que a "conferência quantitativa + qualitativa" genérica hoje em [[Estoque-Modelo-Dados]] — os dois modelos precisam ser reconciliados (ver perguntas em aberto).

### 5. Qualidade

> Fluxo completo, conversa por conversa, em [[Fluxo-Qualidade-Completo]].

Duas filas distintas:

- **Inspeção de processo** — itens marcados pelo vendedor pra acompanhamento desde o início (documentação, validação de entrada).
- **Inspeção final** — itens acabados liberados pelo estoque (rota 1) ou pelo Recebimento (rota 3/4), prontos pra virar carga.

Reprovação: Qualidade registra o motivo e anexa evidência (ex. foto da avaria) — mesmo princípio do `laudo_url`/RNC já em [[Estoque-Regras-Negocio]], mas com anexo de imagem explícito. Item reprovado **sempre volta pro PCP** pra decidir o novo norte (comprar de novo, mandar pra retrabalho) — nunca fica num estado sem saída, mesmo padrão de [[Estoque-Riscos]].

### 6. Expedição, Logística e Faturamento

> Fluxo completo, conversa por conversa, em [[Fluxo-Expedicao-Faturamento-Completo]]. A execução de OS/OP em si (produção/beneficiamento) está detalhada em [[Fluxo-Producao-OS-OP-Completo]].

Item 100% aprovado (produção + qualidade) vai pra embalagem e despacho. Fiscal (nota fiscal) permanece 100% no Omie — ver [[Faturamento-Expedicao]]. Emissão da NF dá baixa no pedido/item, que migra do relatório "em aberto" pro "faturado" na carteira do vendedor.

## Conceitos/entidades novas (ainda não modeladas no PRD)

- **Ordem de Serviço (OS)** — emitida pelo PCP pra beneficiamento/retrabalho de um item de Revenda (corte, ajuste) fora de uma linha de fabricação própria.
- **Ordem de Produção (OP)** — emitida pelo PCP pra iniciar a fabricação de um item numa linha própria (Flange etc.).
- **Flag acabado/não-acabado** — definida pelo comprador no fechamento da compra; determina o método de conferência no Recebimento e se o item volta pro PCP.
- **Checkbox de inspeção "desde o início" vs. "só no fim"** — definida pelo vendedor na emissão do pedido.
- **Status por item visível no av-hub** — granularidade de etapa (não só pedido aberto/faturado), alimentada por eventos do PCP/MES.

## Decisões tomadas

- **OS e OP = mesmo mecanismo `roteiro`/`ItemParcial`** já implementado no `api-pcp`, não entidades novas. Ver [[App-PCP-Backend-Producao]].
- **Reserva de estoque** confirmada como necessária no passo em que o PCP marca um item como disponível — evita a condição de corrida entre pedidos concorrentes. Trade-off aceito: checagem de saldo deixa de ser só leitura, precisa também criar/liberar a reserva (com mecanismo de expiração a desenhar).

## Divisão Compras av-hub × MES

- **PCP (MES)** classifica o item, verifica saldo/reserva e gera a **requisição de compra** — decisão operacional que depende de dado físico que só o MES tem.
- **Comprador (av-hub)** processa a requisição: escolhe fornecedor, negocia preço, emite a **Ordem de Compra**, decide segunda aprovação (quando essa regra for definida) e a flag **acabado/não-acabado** — tudo decisão comercial/financeira, no mesmo lugar onde já ficam Orçamento, fornecedor (`core.parceiros`) e aprovação/segregação de função.
- **De volta pro MES** trafega só o necessário pra conferência no Recebimento — itens, quantidade, a flag acabado/não-acabado — não o dado comercial completo (preço, condição, fornecedor). Mesma filosofia de "colunas protegidas" já provada no pipeline ELT: cada lado só recebe o que precisa, dono claro de cada campo.
- **Recebimento, conferência e abertura de OS/OP** seguem 100% no MES — execução pura.

Mecanismo exato de como esse "trafega de volta" acontece na prática (evento, polling, manual) ainda depende do "casamento av-hub↔MES", que segue em aberto — ver [[Decisoes-Chave-ERP]] e a ressalva sobre "tempo real" mais abaixo neste arquivo. Ver [[MES-Arquitetura-Decisoes]].

## Perguntas em aberto

- Mecanismo exato de integração av-hub ↔ MES pro status por item ("casamento dos dois sistemas", termo do usuário) — ainda não desenhado. **Risco de arquitetura a considerar:** nenhum dos sistemas analisados até hoje tem mecanismo de evento/webhook entre bancos separados — o único padrão de sincronização entre sistemas documentado no vault é o [[Omie-ELT-Pipeline|pipeline ELT]], que é **polling em camadas** (3 min a diário), sem webhook. Não assumir "tempo real" como dado disponível — é decisão de arquitetura em aberto. Mesmo mecanismo usado pra "trafegar de volta" o dado da OC do av-hub pro MES.
- Conferência do Recebimento (contra Pedido de Venda vs. contra Ordem de Compra) precisa ser reconciliada com o modelo genérico de `recebimento`/`item_recebido` já em [[Estoque-Modelo-Dados]] — ainda precisa conversar mais e fazer sentido de ponta a ponta.
- **Histórico do pedido precisa ser repensado.** `pedidos_vendas_status_historico` (av-hub) é o histórico vindo do **Omie via pipeline** (polling, granularidade grossa) — não é a mesma coisa que o status granular por item/etapa que este fluxo pressupõe. Precisamos de um histórico muito mais robusto, mostrando tudo (toda transição de `ItemParcial`, OS/OP, aprovação/reprovação de qualidade), não só o que o Omie expõe. Ver [[AV-Hub-Bugs-Catalogo]].

## Ver também
- [[Setores-Envolvidos-no-Fluxo]] — referência completa de todo setor participante.
- [[Fluxo-Compras-Completo]] — o fluxo de Compras detalhado conversa por conversa.
- [[Fluxo-Recebimento-Completo]], [[Fluxo-Qualidade-Completo]], [[Fluxo-Producao-OS-OP-Completo]], [[Fluxo-Expedicao-Faturamento-Completo]], [[Fluxo-Estoque-Completo]] — os demais subfluxos, no mesmo padrão.
- [[Modelo-Destinacao-Item]] — modelo formal dos dois eixos (natureza × disponibilidade) por trás deste fluxo.
- [[Fluxo-Operacional-Visao-Geral]]
- [[Rota-Revenda]]
- [[Rota-Fabricacao]]
- [[Fabricacao-Chapas]]
- [[PCP-Carteira]]
- [[MES-Arquitetura-Decisoes]]
- [[App-PCP-Backend-Producao]]
- [[Estoque-Modelo-Dados]]
- [[Decisoes-Chave-ERP]]
