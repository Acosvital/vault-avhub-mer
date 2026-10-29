---
tags: [telas, menu, experiencia-do-usuario, proposta, vendas, orcamento, compras, comissao, redundancia, auditoria-de-telas]
criado: 2026-10-23
atualizado: 2026-10-29
status: proposta
dono: Nathan
fontes: ["av-hub develop (23/10/2026): lidos os 47 arquivos page.tsx de app/(protected)/vendas, orcamento e compras e os componentes que cada um abre (components/Propostas, Clientes, Relatorios, Suprimentos, PainelComprador, CustoItens, Configuracoes, Compras, Painel, Orcamento)", "lib/auth/devSemLogin.ts (MENU_DEV)", "av-hub docs/ENVIAR - contrato-comercial-suprimentos-telas.md", "Registro-de-Decisoes (N16-01 a N16-78)", "11-Proposta-e-Pedido-de-Venda, 12-Orcamento-Base-de-Preco, 13-Custo-Real-e-Comissao-no-Fluxo", "05-Integracoes/Mapa-IncluirPedido-Omie"]
---

# Telas de Vendas, Orçamento e Compras no modelo novo

## Em uma frase

Esta nota mostra o que cada tela de Vendas, Orçamento e Compras faz hoje, como elas se ligam, onde se repetem e como deve ficar a nova página de proposta.

## Como usar esta nota

- Quer saber **o que uma tela faz e se ela muda**? Veja a seção 1.
- Quer saber **o que está desconectado**? Veja a seção 2.
- Quer saber **o que está repetido ou confuso**? Veja a seção 3.
- Quer saber **quais telas ainda faltam e como será a proposta**? Veja as seções 4 e 5.
- Nomes de arquivos, colunas e filtros de cada tela estão em "Detalhe técnico", no fim.

Esta nota substitui a primeira versão de 23/10. Agora **todas as páginas foram lidas**. O que não foi lido por dentro está marcado ❓: o que cada botão faz no servidor, as telas de Cadastros, e as de PCP e Meus Pedidos, que só foram vistas por fora.

Selos: ✅ existe e foi lido · 🔴 não existe · 🟡 proposta · ❓ não conferido.

## 1. O que cada tela faz hoje

### 1.1 Vendas

| Tela | O que faz | No modelo novo |
|---|---|---|
| **Propostas, lista** | Mostra o resumo das propostas, com filtros por empresa, status, período, unidade e responsável. Daqui o vendedor abre uma nova proposta. | ✅ Muda: estados e rótulos (seção 4) |
| **Proposta, formulário** | Reúne emissão, cliente, itens, condições e análise de margem. Na lateral ficam os totais e as ações. | 🔴 Será reescrita (seção 5) |
| **Proposta, "Pedido no Omie"** | Monta os dados para o vendedor **digitar no Omie à mão** e pede de volta o número do pedido. | 🔴 **Sai.** O pedido vai por API, com fila e pipeline |
| **Clientes, lista** | Mostra cards de clientes, propostas dos últimos 90 dias e contatos atrasados. Permite exportar contatos. | ✅ Mantém |
| **Cliente, ficha** | Mostra dados, compradores, relacionamento e estatísticas de propostas. | ✅ Mantém. "Total fechado" e "Conversão" passam a contar **propostas aprovadas** |
| **Relatório de Cotações** | Mostra totais de propostas, valor acumulado, fechadas e conversão, com Excel. | ✅ Mantém, com os novos estados |
| **Relatório Gerencial** | Mostra o resumo, a divisão por responsável, empresa e unidade, os motivos de perda e a carteira. | ✅ Mantém. "Perdidas" vira **Canceladas**. Os motivos de perda viram **motivos de cancelamento** |
| **Pedidos de Venda** (inativa no menu, N16-33) | Lista os pedidos **sincronizados do Omie**. O detalhe mostra a situação e as datas de cada pedido. | ✅ Continua inativa, mas **é valiosa**: já mostra os **sinalizadores do Omie** que a comissão precisa (cancelado, devolvido, devolvido parcial). É a base da fila do Fiscal (seção 4) |
| **Notas Fiscais de Saída** (inativa) | Lista as notas de saída com valores e se foi averbada. | ✅ Continua inativa |

### 1.2 Orçamento

| Tela | O que faz | No modelo novo |
|---|---|---|
| **Painel do Comprador** | Organiza a fila de pedidos de custo. O comprador assume, libera, responde, diz "sem fornecedor" ou cancela. | ✅ Mantém, mas **tira "Vencem hoje" e "Atrasadas"**, porque não há prazo (N16-58). Fica o tempo cronometrado |
| **Responder solicitação** | O comprador escolhe a **oferta vigente** que vira o custo do item. O vendedor é avisado. | ✅ Mantém |
| **Pedido de cotação** | Envia um e-mail por fornecedor da categoria, com os itens e a data de resposta. | ✅ Mantém |
| **Ofertas de fornecedor** | Lista as ofertas e deixa lançar, importar o mapa de Compras, invalidar e exportar. | ✅ Mantém. As ofertas das OCs (ordens de compra) entram sozinhas |
| **Fornecedores, lista e ficha** | Mostra o perfil de compras, as categorias, os certificados e as ofertas de cada fornecedor. | ✅ Mantém |
| **Catálogo de produtos, lista e ficha** | Lista os produtos e mostra preços e a média geral de 90 dias. Permite ligar produtos pendentes ao Omie. | ✅ Vira a **página do produto** (`B2`) |
| **Pesquisa de materiais** | Mostra o menor custo e o fornecedor vencedor de cada material. Gera o PDF "Cotação de Materiais". | ✅ Mantém. **Repete** parte do catálogo (seção 3) |
| **Parâmetros de custo** | Guarda ICMS a recuperar, validade da oferta e janela do histórico. Salvar abre uma nova vigência. | ✅ Mantém |
| **Tabela da telha** | Guarda o custo por classe e espessura, com vigência. Telhas já orçadas mantêm o custo da época. | ✅ Mantém |
| **Custo por item** (`custo-itens`) | Mostra itens, lotes e custo médio de um pedido. | ✅ Vira "Custo real do pedido". O aviso de exemplo precisa sair quando houver dado real |
| **Simulador de Orçamento** | Calcula custo, preço sugerido, margem e letra sem pedido. **Não grava.** | ✅ Existe. **Repete** a análise da proposta (seção 3) |
| **Sincronização Omie** | Mostra a sincronização rodando. A automática está desligada: só roda pelo botão. | ✅ Existe na `develop`. É ferramenta de TI, **não** de usuário final ❓ |
| **Guia do fluxo do custo** | Páginas explicativas "Para que serve". | 🔴 Descrevem o fluxo **antigo**. Precisam ser reescritas |

### 1.3 Compras

| Tela | O que faz | No modelo novo |
|---|---|---|
| **Dashboard de compras** | Mostra a fila de compras, o valor comprado em 12 meses, os atrasos e o que há a receber. | ✅ Mantém |
| **Requisições** (lista e kanban) | Lista as requisições do PCP ou manuais. Permite fechar a compra, ver a OC e cancelar com motivo. | ✅ Mantém e **ganha a tarja de pedido cancelado** |
| **Nova requisição** | É o "pedido de compra interno": unidade, número do pedido de venda, produto, quantidade, prazo e finalidade. | ✅ Mantém. Com a proposta, o pedido de venda vem do hub, não do Omie |
| **Emitir OC** | Monta a ordem de compra com fornecedor, pagamento, itens, frete e observações. O Omie só aceita item com produto cadastrado na unidade. | 🔴 **Não tem imposto por item e não conhece a proposta.** Precisa de `C6` e `C7` (puxar da proposta, conferir e editar impostos) |
| **Pedidos de venda da OC** | Responde "Para que é esta compra". O comprador **digita um pedido de venda de cada vez** e marca o que falta comprar. | ✅ Mantém. 🟡 Com a proposta, a ligação PV ↔ item de compra deixa de ser digitada |
| **Ordens** (lista, kanban, detalhe) | Mostra as OCs por status e origem, com Aprovar, Reprovar e Cancelar OC. | ✅ Mantém. O detalhe ganha "compra acima do valor" (`C8`) |
| **Aprovações** | Mostra as OCs **acima do limite da unidade** que esperam o aprovador. | ✅ Mantém. ⚠️ **Nome igual a outra coisa**: não é a aprovação do vendedor (`C8`) |
| **Follow-up (CCP)** | Acompanha as OCs aprovadas: confirmação do fornecedor, despacho, contatos e ocorrências. | ✅ Mantém. 📝 **CCP é parte do PCP e cuida do follow-up das compras** (N14-24) |
| **Pedido Omie (detalhe)** | Mostra, só para leitura, o pedido de compra **feito direto no Omie**. | ✅ Mantém |
| **Histórico de compras** | Mostra as compras por conta, período, produto e fornecedor, com gráfico por mês. | ✅ Mantém. Vira aba da página do produto |
| **Compradores** | Liga os compradores do Omie por unidade ao funcionário que emite a OC por eles. | ✅ Mantém (Cadastros/Acessos) |

### 1.4 Painéis que a proposta deve respeitar

O **Painel PCP** e o **Dashboard de Vendas** mostram a carteira, o desvio de previsão e o **"Em avanço"**. "Em avanço" é o pedido que o diligenciador marcou como faturamento em etapas. **Meus Pedidos** e **Pedidos da Equipe** são a casa do pedido do vendedor. ❓ Foram lidos só pelo nome dos componentes.

## 2. Como as telas se conectam

```mermaid
flowchart LR
    CLI[Clientes<br/>cadastro Omie por conta] --> PROP[Proposta]
    PROD[Página do produto<br/>catálogo, ofertas, histórico] --> PROP
    PC[Painel do Comprador<br/>pedido de custo] <--> PROP
    PROP -->|aprovada, transformar| PV[Pedido de venda<br/>fila do Omie]
    PV --> MEUS[Meus Pedidos<br/>pendências C8]
    PV --> REQ[Requisição do PCP]
    REQ --> OC[Emitir OC<br/>C6 e C7]
    OC -->|compra acima do valor| MEUS
    OC --> FUP[Follow-up CCP]
    OC --> CUSTO[Custo real do pedido]
    CUSTO --> COM[Comissão nova]
    PV -. Omie: cancelado, devolvido .-> FISCAL[Fila do Fiscal<br/>Pedidos de Venda]
    OFE[Ofertas e Fornecedores] --> PROD
    OC --> OFE
```

**Já está ligado no código** ✅:
- Proposta e Painel do Comprador: o vendedor pede o custo e recebe a resposta.
- Proposta e Simulador de comissão: "simular a comissão deste pedido".
- Catálogo, Ofertas, Fornecedores e Pesquisa conversam entre si.
- Requisição, Emitir OC, Follow-up e Ordens seguem em sequência.
- Pedidos de venda do Omie alimentam o Painel PCP.

**Ainda falta ligar** 🔴:

| Ligação | O que acontece hoje |
|---|---|
| Proposta → Pedido por API | O vendedor digita no Omie e volta para anotar o número. |
| Proposta → Emitir OC (`C6`) | Compras refaz o que o vendedor informou. A OC **não conhece a proposta**. |
| OC → imposto por item | O hub não guarda IPI, ICMS nem ST. |
| OC → custo real → comissão | Não existe. |
| Compra acima do valor → Meus Pedidos (`C8`) | O vendedor não sabe que a margem caiu. |
| Pedido cancelado → requisição, OC, PCP (tarja) | Cada setor descobre sozinho. |
| Pedido do Omie (`devolvido parcial`) → fila do Fiscal | A informação existe na tela inativa e ninguém é avisado. |
| Cliente → cadastro por conta Omie | O erro só aparece ao transformar em pedido. |
| Proposta ↔ Página do produto | O vendedor sai da proposta para consultar preço. |

## 3. Repetições e confusões, com a decisão proposta

| # | Onde | O problema | Proposta 🟡 |
|---|---|---|---|
| 1 | Margem em três lugares | A "Análise de margem" da proposta, o **Simulador de Orçamento** e o **Simulador de comissão** usam o mesmo motor e podem dar resultados diferentes. | Um só cálculo, na API. A proposta é a casa. O Simulador de Orçamento vira "simular sem proposta", com **a mesma tela de custo**. O Simulador de comissão fica (módulo atual). |
| 2 | Preço do produto em quatro telas | Catálogo, Pesquisa de materiais, Ofertas e Histórico de compras mostram recortes diferentes. | Uma **página do produto** com abas: Fornecedores e score, Ofertas, Histórico de compras e Série de preço. Pesquisa e Ofertas ficam como **operação** do Orçamento. |
| 3 | Duas condições de pagamento na proposta | Há um texto livre e uma "Condição (tabela de encargos)". | **Um só campo**, com a lista da conta Omie ([[Mapa-IncluirPedido-Omie]] §5.1). |
| 4 | Estado de destino × UF do cliente | Podem divergir, e o ICMS depende deles. | O destino vem do cliente ou do local de entrega. Editar exige motivo. |
| 5 | ICMS, IPI e ST digitados × cálculo do Omie | O total da proposta pode ficar diferente do total da nota. | ✅ **Decidido (N16-95): o vendedor digita e o valor segue para o pedido.** Compras confere e pode alterar na OC. O Fiscal também pode alterar. Conferir com o Omie é só opcional. |
| 6 | Tipo de item "Revenda" × "Fabricação interna" | O vendedor classifica o que a comissão trata de forma diferente (letra × 2% fixo, N16-78). | Mantém, com um **texto de ajuda** que mostra o efeito na comissão **estimada dele**. |
| 7 | **Dois "Aprovações"** em Compras | Um é a OC acima do limite (aprovador). O outro é a compra acima do valor da proposta (vendedor, `C8`). | Renomear para **"Aprovar OC"** (Compras) e **"Pendências"** (Meus Pedidos). "Aprovações" sozinho não aparece em lugar nenhum. |
| 8 | "Custo" com três sentidos | Há o custo cotado (proposta), o custo da oferta (Orçamento) e o custo real (pedido). | Três rótulos fixos: **Custo cotado**, **Custo da oferta** e **Custo real**. |
| 9 | Painel do Comprador com SLA | "Vencem hoje" e "Atrasadas" contrariam N16-58. | Tira os dois e mostra o **tempo parado**. |
| 10 | Relatórios com "Fechadas/Perdidas" | São estados do modelo antigo. | Usar **Aprovadas/Canceladas**. "Motivos de perda" vira "Motivos de cancelamento". |
| 11 | Guias do fluxo do custo | Descrevem o fluxo antigo. | Reescrever depois que o fluxo novo estiver no ar. |
| 12 | Sincronização Omie no menu de Orçamento | Ferramenta de TI parece tarefa do usuário. | Sair do menu comum e ficar só para TI ❓ |
| 13 | Unidades: **Mogi (Aços Vital), Uberaba (Aços Uberaba) e Arujá (HRM)** | ✅ **Resolvido (N16-79): são três contas Omie e um só sistema.** O Hub mostra a **logo e a identidade da unidade do usuário** e emite pedidos, OCs e propostas com essa identidade. | O catálogo de condições, as categorias e as contas correntes são **por unidade**. A proposta e o relatório escolhem a unidade pela emissora (AV, AU, HRM). |

## 4. Telas que faltam, com dono do dado

| Tela | Onde fica | Quem usa | Nó |
|---|---|---|---|
| Aprovar proposta (revisão e total à vista) | Dentro da proposta | Vendedor | `V0.5` |
| Transformar em pedido (Qualidade, cliente no Omie, produtos cadastrados) | Dentro da proposta | Vendedor | `V0.6` |
| Estado do pedido no Omie (fila, enviado, erro com motivo e "Tentar novamente") | Proposta e Meus Pedidos | Vendedor | `V0.7` |
| Página do produto | Orçamento e dentro da proposta | Vendedor, Orçamento, Compras | `B2` |
| Emitir OC com dados da proposta e imposto por item | Compras | Comprador | `C6`, `C7` |
| Pendências (aprovar ou reprovar compra acima do valor) | Meus Pedidos | Vendedor | `C8` |
| Reprovados sem solução | Compras | Comprador | `C8` |
| Tarja de pedido cancelado | Requisição, OC, PCP | Todos | `V0C` |
| **Fila do Fiscal**: devoluções parciais a informar e pedidos cancelados no Omie. Reaproveita a lista "Pedidos de Venda" | Cadastros ou Fiscal | Fiscal, Controladoria | `K6` |
| Comissão estimada na proposta, Minhas Comissões, Decisão, Drill-down, Devoluções pendentes, Visão Geral, Parâmetros | Comissões (novas) | Vendedor, Controladoria, Gerência, Coordenação, Fiscal | `K1` a `K6` |
| Configuração por conta Omie (categoria, conta corrente, cenário, etapa, condições de pagamento) | Administração | TI | `V0.7` |
| **Calendário**: feriados e dias úteis de exceção por unidade (N16-104) | Cadastros | Marketing | datas |
| **Histórico de datas do pedido**: inicial, entregas de Compras, novas datas do CCP, atraso e a data vigente (N16-104) | Meus Pedidos (vendedor) e Carteira do PCP | Vendedor, PCP | datas |
| **Pedido do Omie na tela do pedido** (N16-106) | Meus Pedidos | Vendedor | `V1`, `K1` |

Sobre o **pedido do Omie na tela do pedido** (N16-106):
- A parte de vendas vem do Omie e fica só para leitura ("altere no Omie").
- O vendedor preenche a parte de compras, que é a simulação da comissão.
- O vendedor também responde Qualidade e faturamento em partes.
- A tela e as pendências são as mesmas do pedido que nasceu da proposta.

## 5. A página de proposta

### 5.1 O que está pesado ou errado hoje

- **Ordem confusa.** O vendedor só descobre o que falta depois de rolar a tela toda.
- **Item com cerca de 25 campos.** Venda e compra aparecem misturadas na mesma linha.
- **Botões do modelo antigo.** Há "Fechar itens", "Reabrir", "Perder" e o modal de digitar no Omie.
- **Não mostra o que falta.** "Incompleta" só aparece como erro, depois.
- **Duas condições de pagamento, destino repetido e imposto digitado** (seção 3).
- **Sem o estado do pedido.** Só aparece "Pedido no Omie: nº" depois de digitado à mão.

### 5.2 Como deve ficar 🟡

**Princípio:** uma ação principal por estado, sempre visível. A tela diz o que falta para a próxima etapa.

**Cinco blocos, nesta ordem, mais um resumo fixo:**

1. **Quem e para quem.** Número, revisão, estado, **unidade emissora** (a do usuário; logo e identidade vêm dela, N16-79/N16-80) e responsável. O cliente mostra o selo "cadastrado no Omie de Mogi/Uberaba" ou o aviso "não vira pedido". Também entram comprador, número da requisição do cliente e finalidade.
2. **O que se vende.** Cada item mostra **só o que o cliente vê**: produto (do cadastro do Omie; pendente em destaque), quantidade, UM, preço, desconto e prazo. Os **impostos são digitados pelo vendedor** (ICMS %, IPI %, ST %) e seguem para o pedido (N16-95). O Hub calcula o total. A especificação técnica fica recolhida em "Detalhes técnicos".
3. **Condições.** Frete e valor, **condição de pagamento escolhida da lista da conta**, validade, moeda e câmbio (PTAX do dia da aprovação, visível).
4. **Custo de compra**, só para quem vê custo. Cada item mostra de onde veio o custo (digitado, pedido de custo respondido ou histórico de OC), o fornecedor e o link para a página do produto. O pedido de custo mora aqui.
5. **Resultado**, para vendedor e gerência: margem, letra e **a comissão estimada que ele colocou**. Nunca a comissão real.

**Resumo fixo na lateral:**
- Totais: subtotal, desconto, impostos do Omie, frete e total.
- **Pendências clicáveis**, como "Item 3 sem custo e sem fornecedor", "Cliente sem cadastro no Omie de Mogi", "Produto PEND-0042 sem cadastro" e "Condição de pagamento não existe na conta". Cada uma leva ao campo.
- **Um botão principal por estado:**
  1. `Salvar` (proposta aberta).
  2. `Marcar como aprovada`. Só habilita sem pendência e mostra revisão e total.
  3. `Transformar em pedido`. Pede **três coisas obrigatórias**: a **data de previsão de faturamento**, se **a Qualidade acompanha todo o processo desde o zero** (sim ou não) e se o pedido **pode faturar em partes ou somente inteiro** (N16-88 e N16-89).
  4. Depois disso, só o estado do pedido, com a **previsão de faturamento vigente** e o histórico das datas (inicial, entrega de Compras, entrega do CCP, atraso do fornecedor).
- No menu: Duplicar, Cancelar (com motivo), Revisões, Linha do tempo, PDF e E-mail.
- **Identidade visual da unidade (logo e cores):** por enquanto só no **PDF** (N16-99). Os **textos padrão** ficam para mais para frente.

**Como a proposta aparece em cada estado:**
- **Aprovada:** só leitura, com a faixa "Aprovada em dd/mm por Fulano (revisão R). Para mudar, cancele e duplique."
- **Transformada:** faixa com o número do hub, o número do Omie e o estado (na fila, enviado ou erro com **motivo**). Mostra também a Qualidade marcada e o aviso de compra acima do valor, se existir.
- **Cancelada:** só leitura, com motivo, quem e quando. Só permite **Duplicar**.

### 5.3 Regras de clareza (valem para todas as telas novas)

1. **Um número, um nome, uma origem visível.** Use "Custo cotado", "Custo da oferta", "Custo real", "Preço de venda" e "Preço sugerido".
2. **O que é calculado fica só para leitura e diz quem calculou** ("Omie", "motor", "média das OCs").
3. **O que o perfil não pode ver some.** Não vira "—". Comissão real e custo real nunca aparecem vazios para o vendedor.
4. **O imposto é digitado pelo vendedor** e segue para o pedido (N16-95). O Omie não o substitui.
5. **O erro diz o que fazer.** Exemplo: "O Omie recusou: falta a conta corrente da unidade. Fale com a TI."
6. **Sem dado, sem inventar.** Sem OC no histórico, a página do produto diz "sem compras registradas" e não mostra média zero.
7. **Uma pergunta por decisão.** Aprovar ou reprovar, informar a devolução, decidir a comissão.
8. **Nenhum nome repetido para coisas diferentes** (ver "Aprovações", seção 3, item 7).

### 5.4 O pedido em partes (sequenciais) 🟡

O vendedor pode marcar "pode faturar em partes" (N16-89). Nesse caso a tela do **pedido**, dentro de Meus Pedidos, ganha o bloco **Sequenciais**.

- Cada linha é um sequencial, com número, valor, estado (aberto, faturado ou cancelado) e nota fiscal. Abaixo fica o **saldo do original**.
- Quem age, normalmente, é o **Fiscal**.
- **Quebrar:** escolhe **itens e quantidades**, e o valor sai deles.
- **Cancelar:** o valor volta ao saldo e o número não se reusa.
- **Excluir:** só vale para sequencial aberto.
- Pedido "somente inteiro" não mostra o bloco.
- O nome na tela é **"Faturamento em partes"**. Assim não se confunde com a **divisão da triagem do PCP** (fabricação, revenda…), que é outra coisa (N16-93).
- Tela e API dependem de descobrir como o Omie cria o sequencial.

## 6. Organização do menu 🟡

> [!info] Menu de Vendas e Orçamento revisto em 27/10/2026
> As decisões N16-107 e N16-108 enxugaram o menu. Vendas fica com 4 entradas. Orçamento também fica com 4: Pedidos de custo (abas Fila e Cotação), Produtos (abas Preços, Comparar e Ofertas), Fornecedores e Parâmetros (abas Custo e Telha). O **Histórico de compras sai**, porque a tela Ordens de compra já mostra o histórico. As linhas de Vendas, Orçamento e Compras abaixo já refletem isso.

| Menu | Entradas | Observação |
|---|---|---|
| **Vendas** | Propostas · Clientes · **Meus Pedidos** · Relatórios (Gerencial, com a aba Cotações) | Meus Pedidos entra no grupo: é onde o vendedor responde `C8`. |
| **Orçamento** | **Pedidos de custo** (Painel do Comprador + Pedido de cotação) · **Produtos** (Catálogo + Pesquisa de materiais + Ofertas, com a página do produto) · Fornecedores · **Parâmetros** (custo e telha) | De 9 entradas para 4. |
| **Compras** | Requisições · Ordens · **Aprovar OC** · Follow-up (CCP) · **Reprovados** · Dashboard | "Aprovações" vira "Aprovar OC". **Sem Histórico**: vira filtro por produto em Ordens. |
| **Comissões** | O módulo atual (não muda) + Comissões da proposta (novas) | Nada do módulo atual é tocado. |
| **Cadastros ou Fiscal** | Compradores · **Fila do Fiscal** · Sincronização Omie (TI) | |
| **Ocultas** | `propostas-delegacao`, `propostas-valores`, `custo-item`, `solicitacoes-custo` | Liberam capacidade e não aparecem no menu. |

## 7. Ordem de construção

1. **Proposta nova** (seção 5). É a tela de uso diário e a que mais muda. Depende de uma decisão: a condição de pagamento vira lista da conta. O imposto continua digitado pelo vendedor (N16-95).
2. **Meus Pedidos com pendência `C8`.** Combinar com a frente "encerrar pedido zerado", que mexe na mesma tela.
3. **Página do produto.** Reaproveita Catálogo e Histórico.
4. **Emitir OC com dados da proposta e imposto por item.**
5. **Fila do Fiscal.** Reaproveita Pedidos de Venda.
6. Comissões novas.

## Ver também

[[11-Proposta-e-Pedido-de-Venda]] · [[12-Orcamento-Base-de-Preco]] · [[13-Custo-Real-e-Comissao-no-Fluxo]] · [[Mapa-IncluirPedido-Omie]]

## Detalhe técnico

Para quem mexe no código. Tudo o que saiu do texto principal está aqui.

### Como a auditoria foi feita

Foram lidos os 47 arquivos `page.tsx` de `app/(protected)/vendas`, `orcamento` e `compras` e os componentes que cada um abre: títulos, colunas, filtros, ações e serviços chamados. Os arquivos de PCP e Meus Pedidos foram vistos só pelo nome dos componentes (`CarteiraPrevisao`, `PainelPcp`, `PainelVendas`) ❓.

### Colunas, filtros e campos por tela: Vendas

| Tela | Detalhe lido no código |
|---|---|
| Propostas, lista | Resumo: Total cotado, Em aberto, Fechadas, Perdidas, Conversão. Filtros: Empresa, Status, Período, Unidade (**Mogi, Uberaba, Arujá**), Responsável. Busca por nº e cliente. Botão "Nova proposta". |
| Proposta, formulário | Blocos Emissão, Cliente, Itens, Condições de fornecimento, Análise de margem. Lateral com Totais e ações: Salvar, Fechar itens, Reabrir, Perder, "Pedido no Omie", Duplicar, Revisões, Linha do tempo, PDF, E-mail. |
| Proposta, "Pedido no Omie" | `PedidoOmieModal`: monta o cabeçalho e os itens para **copiar e digitar no Omie à mão**, escolhe a conta (Mogi ou Uberaba) e pede de volta o nº do pedido digitado. |
| Clientes, lista | Cards Clientes, Com proposta em 90 dias, Próximo contato vencido. Filtros Status, Segmento, Próximo contato. Exportar contatos. |
| Cliente, ficha | Dados, compradores, relacionamento (segmento, potencial, próximo contato). Estatísticas: Propostas, Última proposta, Total cotado, **Total fechado**, **Conversão**, Ticket médio. |
| Relatório de Cotações | Totais: Propostas, Valor acumulado, **Fechadas**, Valor fechado, Conversão. Tabela Cliente, Responsável, Valor. Excel. |
| Relatório Gerencial | Resumo (Total cotado, Em aberto, Fechadas, **Perdidas**, Conversão). Por responsável, empresa e unidade (**Mogi, Uberaba, Arujá**). **Motivos de perda**. Status da carteira. Excel. |
| Pedidos de Venda (inativa no menu, N16-33) | Pedidos **sincronizados do Omie**: nº, sequencial, inclusão, etapa, cliente, vendedor, valor, situação. Detalhe com **Autorizado, Denegado, Faturado, Cancelado, Devolvido, Devolução Parcial, Encerrado**. Datas de inclusão, previsão, faturamento, cancelamento e encerramento. Motivo e usuário do encerramento. |
| Notas Fiscais de Saída (inativa) | Data, nº NF, cliente, vendedor, filial, categoria, IPI, mercadorias, total, "Averbada?". |

### Colunas, filtros e campos por tela: Orçamento

| Tela | Detalhe lido no código |
|---|---|
| Painel do Comprador | Cards Fila de hoje, Solicitações abertas, **Vencem hoje, Atrasadas**, Ofertas vencendo em 7 dias. Atribuição: Comigo, Livres na fila. Ações: Assumir, Liberar, Responder, "Sem fornecedor", Cancelar. Avisos de "Sem disputas suficientes" e de certificados vencendo. |
| Responder solicitação (modal) | O Comprador escolhe a **oferta vigente** que vira o custo do item; "o vendedor é avisado"; lança nova oferta ou responde "Sem fornecedor". |
| Pedido de cotação | Um e-mail por fornecedor da categoria, com itens e "Resposta até". Busca no catálogo. Modal de análise do item: última compra, média e mínimo, cotações válidas. |
| Ofertas de fornecedor | Lista: produto, fornecedor, preço, custo líquido, cotação, validade. Ações: Lançar oferta, **Importar mapa** (xlsx de Compras, com produtos pendentes), Importações, Invalidar, Exportar. |
| Fornecedores, lista e ficha | Busca por nome ou CNPJ, categoria. Ficha com perfil de compras (e-mail de cotação, origem do ICMS padrão, entrega certificado), categorias, certificados, ofertas. |
| Catálogo de produtos, lista e ficha | Busca por código ou trechos. **Produtos pendentes** (modal para ligar ao Omie). Ficha com preços, **média geral de 90 dias**, "pendente no Omie". |
| Pesquisa de materiais | Menor custo e fornecedor vencedor por material, prazo e frete, quantos cotaram. Comparativo por quantidade. PDF "Cotação de Materiais". |
| Parâmetros de custo | ICMS a recuperar por origem, validade padrão da oferta, janela do histórico; "salvar abre uma nova vigência". |
| Tabela da telha | Custo por classe × espessura, núcleos, pinturas, com vigência; telhas já orçadas mantêm o custo da época. |
| Custo por item (`custo-itens`) | Resumo do pedido, itens, **lotes**, custo médio, origem, "Cotação a conferir", "Custo completo/incompleto". Avisos **"Dados de exemplo"** e **"Custo sem impostos"**. |
| Simulador de Orçamento | Digita compra e venda sem pedido e vê custo líquido, preço sugerido, margem, letra e status com o motor do Simulador de Comissão. **Não grava.** |
| Sincronização Omie | "Sincronizando agora" e "Automática desligada: só pelo botão". |
| Guia do fluxo do custo | `FluxoDoCusto` e `GuiaSuprimentos`: páginas "Para que serve". |

### Colunas, filtros e campos por tela: Compras

| Tela | Detalhe lido no código |
|---|---|
| Dashboard de compras | `PainelCompras`, `ComprasDashboard`. Fila de compras: requisições abertas, em cotação, aguardando aprovação, a receber, entregas atrasadas. Valor comprado em 12 meses, por comprador, atraso por tempo, a receber por etapa. |
| Requisições (lista e kanban) | Requisições vindas do PCP ou manuais. Fechar compra, Ver OC. Filtro Unidade, Status, Ação. Arrastar no kanban. Cancelar com motivo. |
| Nova requisição | Unidade, **nº do pedido de venda**, produto, quantidade, prazo, tipo sugerido (acabado ou não), finalidade. |
| Emitir OC | `FecharCompra`, **1.869 linhas**. Campos: unidade, fornecedor, contato, previsão, condição de pagamento e parcelas, moeda, contrato, nº do pedido no fornecedor, itens (produto, qtd, valor, desconto, tipo de material, local de estoque), frete (modalidade, placa), categoria, conta corrente, projeto, observações, resumo. "O Omie só aceita item com produto cadastrado na unidade." |
| Pedidos de venda da OC | `PedidosVendaOC`: "Para que é esta compra". O comprador **digita um pedido de venda de cada vez**, vê o que falta comprar por item e marca. |
| Ordens (lista, kanban, detalhe) | OC por status e origem ("Pedido feito direto no Omie: só leitura"). Detalhe com itens, parcelas, observações, histórico, comprador, PDF, Aprovar, Reprovar, Cancelar OC. |
| Aprovações | OCs **acima do limite da unidade** aguardando o aprovador: Aprovar, Reprovar com motivo. |
| Follow-up (CCP) | OCs aprovadas: confirmação do fornecedor, despacho (data, NF, transportadora), contatos, ocorrências. Cards Sem confirmação, Atrasadas, Chegam em 7 dias, Com ocorrência. |
| Pedido Omie (detalhe) | Pedido de compra **feito direto no Omie**, só leitura, com itens, "Recebido", parcelas. |
| Histórico de compras | Filtro Conta (Mogi, Uberaba), período, produto, fornecedor. Resumo. Gráfico por mês. |
| Compradores | Compradores do Omie por unidade e o funcionário que emite a OC por eles. |

### Itens da proposta e campos do formulário (`PropostaForm.tsx`, `ItemProposta.tsx`)

- Ordem atual da tela: Emissão → Cliente → Itens → Condições → *Análise de margem* (só para quem vê custo) → lateral com Totais e botões.
- Campos da linha do item (~25): descrição, qtd, UM, preço, desconto, ICMS %, IPI %, ST %, prazo, norma, material, certificados, ensaios, tipo, qtd comprada, UM compra, preço compra, origem da compra, IPI compra, ST compra, frete compra, fornecedor, custo, kg/m, metragem, margem.
- Condições: texto livre + "Condição (tabela de encargos)".
- O Painel do Comprador é lido como `PainelComprador`; os cards "Vencem hoje" e "Atrasadas" contrariam N16-58.

### Menu de desenvolvimento e ocultas

- O menu de teste sem login vem de `lib/auth/devSemLogin.ts` (`MENU_DEV`).
- Telas ocultas: `propostas-delegacao`, `propostas-valores`, `custo-item`, `solicitacoes-custo`.
- Fontes da auditoria: `av-hub docs/ENVIAR - contrato-comercial-suprimentos-telas.md`, Registro-de-Decisoes (N16-01 a N16-78) e as notas 11, 12 e 13.
