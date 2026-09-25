---
tags: [erp-acos-vital, fluxo-operacional, fluxo-detalhado, pcp, compras, qualidade]
criado: 2026-09-16
---

# Fluxo Detalhado do Pedido — Nível de Item

> **Relação com [[Fluxo-Operacional-Visao-Geral]]:** são **dois modelos complementares, não um substituindo o outro**. O macro trata Estoque/Revenda/Fabricação como três categorias de destinação; este arquivo descreve o que acontece de fato, item a item, dentro dessas categorias — inclusive o fato de que "ter em estoque" na prática é uma **checagem** feita pelo PCP dentro de Revenda/Fabricação, não uma quarta rota isolada.
>
> **Confirmado com o usuário (17/09/2026): nada deste fluxo (aceite do pedido pelo PCP, classificação item a item, checagem de saldo, emissão de requisição/OS/OP) existe em sistema nenhum hoje.** Não é o "Portal PCP" do av-hub (que é só acompanhamento comercial por diligenciadores, ver [[Achado-Ambiguidade-PCP]]) nem o `app-pcp`/MES (que só executa a produção depois que um item já foi destinado à Fábrica). Este documento descreve o **processo-alvo** que o projeto precisa construir, derivado de conversas com o gestor sobre como o fluxo deveria/deve funcionar — hoje essa triagem acontece de forma manual/informal, fora de qualquer sistema.
>
> **Atualização (24/09/2026) — encaixe no MES decidido.** A Carteira de Pedidos e a tela Ordem de Produção já existem no `app-pcp` (branch `develop`, 23-24/09). O encaixe do Estoque e da Revenda foi fechado pelo Robert, com uma regra do Nathan para o item comprado — detalhe completo em [[Encaixe-Estoque-Revenda-no-PCP]]. Os passos 2, 3, 5 e 6 abaixo já refletem isso.

## Princípio central

Um item de pedido cruza dois eixos — natureza (Revenda ou Fabricação) × disponibilidade (pronto em estoque, matéria-prima em estoque, ou sem estoque), formalizados em [[Modelo-Destinacao-Item]]. **Desde 24/09/2026** o primeiro eixo é a **fábrica que o PCP escolhe** para o item na rodada (fábrica tipo `FABRICACAO` ou a fábrica `REVENDA`), e o segundo é resolvido no **setor Estoque, etapa 1 obrigatória de todo roteiro**. Os caminhos possíveis:

1. **Tem em estoque, pronto** → o setor Estoque atende o split: reserva no lote + conclusão → entrega.
2. **Tem em estoque, como matéria-prima** → reserva/consumo de MP fica para a J3 (genealogia); por ora o parcial segue o roteiro normal.
3. **Não tem em estoque, fábrica Revenda** → setor Compras (gera a requisição) → Recebimento → (beneficiamento, se o roteiro tiver) → Qualidade → **volta ao setor Estoque** (entrada do lote + reserva + conclusão) → entrega.
4. **Não tem em estoque, fábrica de Fabricação** (Flange hoje; outras linhas conforme cadastradas — ver [[Rota-Fabricacao]]) → setores produtivos da linha → Qualidade → entrega.

Um mesmo item pode seguir mais de um caminho ao mesmo tempo: 30 de 50 unidades atendidas pelo estoque (caminho 1) e 20 seguindo o roteiro (caminho 3 ou 4), como splits do mesmo `ItemParcial` que somam o total.

## Papéis e visão por módulo

| Módulo | O que visualiza | Ações principais |
|---|---|---|
| **Vendas** (av-hub) | Só a própria carteira (pedidos abertos e faturados); por item, a etapa atual do fluxo | Emissão do pedido; checkbox de inspeção de qualidade desde o início ou só no fim; acompanhamento em tempo real por item |
| **PCP** | Carteira de Pedidos (av-hub/Omie) e itens que retornaram de outra área | Escolhe, por rodada, itens, quantidades e **fábrica** (linha de fabricação ou Revenda) e monta o roteiro; cada rodada gera uma **Ordem de Produção por fábrica**. A checagem de saldo, a reserva e a requisição de compra saíram do PCP: acontecem nos setores Estoque e Compras do roteiro |
| **Estoque** (setor tipo `ESTOQUE`, MES) | Parciais na etapa 1 do roteiro e itens comprados que voltam da Qualidade | Atende do saldo (split + reserva + conclusão) e envia o restante; dá entrada do item comprado e o reserva |
| **Compras** (av-hub, com reflexo no MES) | Só os itens com requisição gerada pelo PCP | Fecha a compra; sinaliza se o item chega **acabado** ou **não acabado**; referencia a Ordem de Compra (dado estruturado, não PDF — ver nota abaixo) |
| **Recebimento** | Itens comprados aguardando chegada física | Conferência quantitativa; método de conferência depende da flag acabado/não-acabado (ver abaixo) |
| **Qualidade** | Itens marcados por Vendas pra acompanhamento desde o início + itens acabados liberados por estoque/Recebimento | Inspeciona; aprova ou reprova (motivo + evidência, ex. foto de avaria) |
| **Expedição/Logística** | Itens concluídos: atendidos/reservados no Estoque (inclusive o comprado, que volta ao Estoque depois da Qualidade) ou fabricados e aprovados | Embalagem, consolidação de carga, despacho — fiscal (NF) permanece no Omie, ver [[Faturamento-Expedicao]] |

## Fluxo passo a passo

### 1. Emissão e aceite

- Vendedor emite o pedido e decide, por pedido, se a Qualidade deve acompanhar **desde o início** (ex.: elaborar documento, validar entrada) ou só **no fim** (inspeção do item pronto). Se não marcar nada, Qualidade só é acionada no fim — evita notificar o setor sem necessidade.
- Pedido cai na fila do PCP com status "pendente". PCP dá o aceite ("despachando o pedido") — só então o vendedor vê o pedido avançar de status.

### 2. Classificação item a item (Carteira + setor Estoque)

> **Reescrito em 24/09/2026** — ver [[Encaixe-Estoque-Revenda-no-PCP]].

A classificação acontece em **dois lugares**, um para cada eixo:

- **Na Carteira / tela Ordem de Produção (eixo 1).** Pra cada item, o PCP escolhe quantas unidades vão nesta rodada e **para qual fábrica**: uma linha de Fabricação própria (Flange hoje — ver [[Fabricacao-Flanges]] / [[App-PCP-Backend-Producao]]) ou a fábrica **Revenda**. A natureza do item é o tipo da fábrica escolhida — por item e por rodada, não fixa por produto. Cada rodada gera uma OP por fábrica, e o backend insere o **setor Estoque como etapa 1** do roteiro.
- **No setor Estoque (eixo 2).** O parcial chega na etapa 1 e o sistema mostra o saldo disponível na filial do pedido:
  - **Tem em estoque, acabado** → ação "atender X do estoque": split + reserva no lote + conclusão do split → entrega.
  - **Não tem, ou tem só parte** → "enviar restante" (mover): na fábrica de Fabricação segue para os setores produtivos; na fábrica Revenda segue para o **setor Compras**, cuja entrada gera a requisição — só esse item fica visível pra Compras (não o pedido inteiro).
  - **Tem em estoque, matéria-prima** (ex.: chapa inteira que precisa ser cortada) → reserva e consumo de MP ficam para a J3; o beneficiamento é um setor `PRODUTIVO` opcional no roteiro da Revenda.

**A reserva nasce no setor Estoque, no mesmo passo em que o saldo é lido** — não é só uma verificação de leitura. Isso evita a corrida entre pedidos concorrentes pelo mesmo lote, risco catalogado em [[Estoque-Riscos]] ("mesmo lote comprometido por PCP e por uma venda ao mesmo tempo"). **Liberação decidida em 24/09/2026:** sem expiração; a reserva é liberada explicitamente quando o pedido ou a OP é cancelado.

### 3. Compras

> Fluxo completo, conversa por conversa (do PCP gerando a requisição até o item virar saldo aprovado), detalhado em [[Fluxo-Compras-Completo]].

- Comprador só vê os itens com requisição gerada **pela entrada do parcial no setor Compras** do roteiro da Revenda (24/09/2026). O parcial fica parado nesse setor até o recebimento liberar.
- Ao fechar a compra, sinaliza se o item vem **acabado** (compra A, vende A — não precisa de trabalho interno) ou **não acabado** (precisa de beneficiamento, ex.: chapa inteira que ainda vai ser cortada).
- Essa flag decide contra o que o Recebimento confere (Pedido de Venda × OC). O beneficiamento em si já está no roteiro da Revenda, como setor `PRODUTIVO` opcional escolhido pelo PCP; se o item vier não acabado e o roteiro não tiver esse setor, o parcial volta pro PCP ajustar (fila "Novo norte").
- Ordem de Compra referenciada aqui (ver [[MES-Arquitetura-Decisoes]], decisão 5) — decidida no av-hub. Anexar PDF manualmente é só a primeira fase; a intenção é trazer os dados da OC de forma estruturada, sem depender de upload/parse de PDF.

### 4. Recebimento

> Fluxo completo, conversa por conversa, em [[Fluxo-Recebimento-Completo]].

Método de conferência depende da flag definida por Compras:

- **Item acabado** → conferência **contra o Pedido de Venda** (o que chegou é literalmente o que o vendedor vendeu — "cara-crachá").
- **Item não acabado** → conferência **contra a Ordem de Compra** (o que chegou é o que o comprador comprou, não necessariamente igual ao que o vendedor vendeu — ex.: comprou chapa, vendeu flange que ainda vai ser fabricada a partir dessa chapa). ~~Ao confirmar a entrada, o item volta pro PCP pra abrir a OS correspondente.~~ Desde 24/09/2026, ao confirmar a entrada o parcial segue para o próximo setor do roteiro da Revenda (o setor de beneficiamento, se houver); só volta pro PCP se o roteiro não previu o beneficiamento.

Isso é mais granular do que a "conferência quantitativa + qualitativa" genérica hoje em [[Estoque-Modelo-Dados]] — os dois modelos precisam ser reconciliados (ver perguntas em aberto).

### 5. Qualidade

> Fluxo completo, conversa por conversa, em [[Fluxo-Qualidade-Completo]].

Duas filas distintas:

- **Inspeção de processo** — itens marcados pelo vendedor pra acompanhamento desde o início (documentação, validação de entrada).
- **Inspeção final** — itens acabados liberados pelo Recebimento (item comprado) ou pela conclusão dos setores produtivos (fabricação/beneficiamento). O item atendido pelo estoque não passa de novo pela Qualidade: o saldo disponível só conta lote já liberado por ela.

**Aprovação (24/09/2026):** item **comprado** aprovado **não vai para a Expedição — vai para o setor Estoque**, que dá entrada do lote, cria a reserva para o split e o conclui; daí segue para a entrega. Item **fabricado** aprovado segue para a entrega. Ver [[Encaixe-Estoque-Revenda-no-PCP]] seção 3.4.

Reprovação: Qualidade registra o motivo e anexa evidência (ex. foto da avaria) — mesmo princípio do `laudo_url`/RNC já em [[Estoque-Regras-Negocio]], mas com anexo de imagem explícito. Item reprovado **sempre volta pro PCP** pra decidir o novo norte (comprar de novo, mandar pra retrabalho) — nunca fica num estado sem saída, mesmo padrão de [[Estoque-Riscos]].

### 6. Expedição, Logística e Faturamento

> Fluxo completo, conversa por conversa, em [[Fluxo-Expedicao-Faturamento-Completo]]. A execução de OS/OP em si (produção/beneficiamento) está detalhada em [[Fluxo-Producao-OS-OP-Completo]].

Item concluído vai pra embalagem e despacho — vindo do setor Estoque (atendido pelo saldo ou comprado e já reservado) ou da Qualidade (fabricado). Na saída, a reserva vira `CONSUMIDA`. Fiscal (nota fiscal) permanece 100% no Omie — ver [[Faturamento-Expedicao]]. Emissão da NF dá baixa no pedido/item, que migra do relatório "em aberto" pro "faturado" na carteira do vendedor.

## Conceitos/entidades novas (ainda não modeladas no PRD)

- **Ordem de Serviço (OS)** — beneficiamento/retrabalho de um item de Revenda (corte, ajuste) fora de uma linha de fabricação própria. Desde 24/09/2026 é um setor `PRODUTIVO` opcional dentro do roteiro da fábrica Revenda, não uma ordem separada.
- **Ordem de Produção (OP)** — gerada pela tela Ordem de Produção a partir da Carteira: uma por fábrica em cada rodada, inclusive para a fábrica Revenda.
- **Flag acabado/não-acabado** — definida pelo comprador no fechamento da compra; determina o método de conferência no Recebimento e se o item volta pro PCP.
- **Checkbox de inspeção "desde o início" vs. "só no fim"** — definida pelo vendedor na emissão do pedido.
- **Status por item visível no av-hub** — granularidade de etapa (não só pedido aberto/faturado), alimentada por eventos do PCP/MES.

## Decisões tomadas

- **OS e OP = mesmo mecanismo `roteiro`/`ItemParcial`** já implementado no `api-pcp`, não entidades novas. Ver [[App-PCP-Backend-Producao]].
- **Reserva de estoque** confirmada como necessária no passo em que o item é atendido pelo saldo — evita a condição de corrida entre pedidos concorrentes. Trade-off aceito: checagem de saldo deixa de ser só leitura, precisa também criar/liberar a reserva. **Fechado em 24/09/2026:** a reserva nasce no setor Estoque (etapa 1, ou na volta do item comprado), aponta para lote + `ItemParcial`, não expira e é liberada explicitamente no cancelamento.
- **Encaixe no MES (24/09/2026):** Revenda é uma fábrica (`Fabrica.tipo = REVENDA`), Estoque e Compras são setores tipados, o Estoque é a etapa 1 de todo roteiro, e o setor "Emissão de Ordens" virou a tela Ordem de Produção. Ver [[Encaixe-Estoque-Revenda-no-PCP]].

## Divisão Compras av-hub × MES

- **PCP (MES)** classifica o item, verifica saldo/reserva e gera a **requisição de compra** — decisão operacional que depende de dado físico que só o MES tem.
- **Comprador (av-hub)** processa a requisição: escolhe fornecedor, negocia preço, emite a **Ordem de Compra**, decide segunda aprovação (quando essa regra for definida) e a flag **acabado/não-acabado** — tudo decisão comercial/financeira, no mesmo lugar onde já ficam Orçamento, fornecedor (`core.parceiros`) e aprovação/segregação de função.
- **De volta pro MES** trafega só o necessário pra conferência no Recebimento — itens, quantidade, a flag acabado/não-acabado — não o dado comercial completo (preço, condição, fornecedor). Mesma filosofia de "colunas protegidas" já provada no pipeline ELT: cada lado só recebe o que precisa, dono claro de cada campo.
- **Recebimento, conferência e abertura de OS/OP** seguem 100% no MES — execução pura.

Mecanismo exato de como esse "trafega de volta" acontece na prática (evento, polling, manual) ainda depende do "casamento av-hub↔MES", que segue em aberto — ver [[Decisoes-Chave-ERP]] e a ressalva sobre "tempo real" mais abaixo neste arquivo. Ver [[MES-Arquitetura-Decisoes]].

## Perguntas em aberto

- Mecanismo exato de integração av-hub ↔ MES pro status por item ("casamento dos dois sistemas", termo do usuário) — ainda não desenhado. **Risco de arquitetura a considerar:** nenhum dos sistemas analisados até hoje tem mecanismo de evento/webhook entre bancos separados — o único padrão de sincronização entre sistemas documentado no vault é o [[Omie-ELT-Pipeline|pipeline ELT]], que é **polling em camadas** (3 min a diário), sem webhook. Não assumir "tempo real" como dado disponível — é decisão de arquitetura em aberto. Mesmo mecanismo usado pra "trafegar de volta" o dado da OC do av-hub pro MES.
- Conferência do Recebimento (contra Pedido de Venda vs. contra Ordem de Compra) precisa ser reconciliada com o modelo genérico de `recebimento`/`item_recebido` já em [[Estoque-Modelo-Dados]] — ainda precisa conversar mais e fazer sentido de ponta a ponta.
- **Histórico do pedido precisa ser repensado.** `pedidos_vendas_status_historico` (av-hub) é o histórico vindo do **Omie via pipeline** (polling, granularidade grossa) — não é a mesma coisa que o status granular por item/etapa que este fluxo pressupõe. Precisamos de um histórico muito mais robusto, mostrando tudo (toda transição de `ItemParcial`, OS/OP, aprovação/reprovação de qualidade), não só o que o Omie expõe. Ver [[AV-Hub-Bugs-Catalogo]]. **Proposta em [[Rastreabilidade-e-SLA-de-Eventos]]** (log de eventos com ator, autorização, passagem e SLA por etapa) e, para campos e API, [[Campos-e-API-para-Rastreabilidade]]. Este fluxo também exige um campo que nenhum diagrama de dados tem hoje: a escolha do vendedor entre acompanhamento de qualidade "desde o início" ou "só no fim".

## Ver também
- [[Encaixe-Estoque-Revenda-no-PCP]] — como Estoque, Compras e Revenda entram no roteiro do MES (24/09/2026).
- [[Setores-Envolvidos-no-Fluxo]] — referência completa de todo setor participante.
- [[Rastreabilidade-e-SLA-de-Eventos]] — como rastrear tempo, responsável e autorização em cada etapa deste fluxo.
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
