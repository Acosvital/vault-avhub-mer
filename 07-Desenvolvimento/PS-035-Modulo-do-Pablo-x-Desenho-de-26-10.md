---
tags: [pesquisa, comercial, proposta, api-comercial, core_comercial, migracao, ps-035]
criado: 2026-10-27
atualizado: 2026-10-28
status: proposta
dono: Pablo
fontes: [av-hub origin/develop de 27/10/2026 (api-comercial/prisma/migrations, src/modules/propostas, src/domain/simulador), api-acos-vital origin/develop (38d2f74 de 16/10, "Dump do Avhub para referência.sql" de a7fda49, 26/10), SQL-016-anexos/0001, SQL-018-anexos/0003, LOG-52, Registro-de-Decisoes N16-02 a N16-106]
---

# PS-035: o módulo do Pablo e o desenho aprovado em 26/10

Resposta do Pablo à [[Pontas-Soltas]] PS-035 ("ciclo da proposta do módulo do Pablo × desenho aprovado"). Compara três lugares: o código de teste `api-comercial` na `develop` do av-hub, o `core_comercial` que já está no banco (migration `052`) e o desenho de 26/10 ([[LOG-56-Fluxo-da-Proposta-ao-Pedido]], [[SQL-016-Schema-core_comercial-Proposta-e-Pedido-de-Venda]], [[SQL-018-Schema-core_comissao-Comissao-da-Proposta]]). Termina com o que o Pablo propõe e o que precisa de resposta antes da fase 2 do [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]].

## 1. Em uma página

- ✅ O desenho de 26/10 é compatível com o módulo: o banco real está vazio de propostas, então a migração troca o ciclo sem converter dado (SQL-016 §1).
- ✅ A fase 1 do LOG-52 está mais adiantada do que o vault registra: além do banco, a API já tem a base do módulo (`38d2f74`, Gustavo, 16/10).
- 🔴 O que o Pablo fez de 16 a 19/10 (análise do Simulador de Comissões na proposta) **não está no banco real** e entra no desenho novo com outros nomes (SQL-018 anexo `0003`). Precisa de um único dono do nome das colunas antes da fase 3.
- 🔴 Um erro no anexo `0003` do SQL-018: ele diz que `propostas_itens.fornecedor_nome` e `id_fornecedor` já existem; no banco real não existem.
- 🔴 Três entregas do Pablo não têm lugar claro no desenho: o PDF de aprovação interna, a tela Simulador de Orçamento e a "emissão só pela auxiliar".
- 🟡 Reestimativa do Pablo: 56,0 pd (eram 59,0), de 28/10/2026 a 19/02/2027; com a alternativa A, até 09/03/2027 (seção 8).
- 🔴 **28/10:** o Pablo começou por produtos (N16-114) num branch da `api-acos-vital`; parte do que fez segue a N16-111 e a N16-112, parte precisa ser refeita (seção 9).

## 2. O que existe hoje em cada lugar

| Item | `api-comercial` (`develop` do av-hub) | `core_comercial` no banco (migration `052`) | `api-acos-vital` (`develop`) |
|---|---|---|---|
| Tabelas | 30 models, 14 migrations, a última `20261016120000_analise_simulador_proposta` ✅ | 23 tabelas, `CHECK` no lugar de enum, `uuidv7()` ✅ dump `a7fda49` | — |
| Ciclo da proposta | `ABERTA`, `PARCIAL`, `FECHADA`, `PERDIDA`; `fechar`, `perder`, `reabrir` ✅ `propostas.routes.ts:143-159`, `propostas.service.ts:614-668` | O mesmo ciclo (`ck_propostas_status`, `valor_fechado`, `perdida_em`) ✅ | — |
| Número | Só empresa, ano, sequencial e revisão; o texto é montado na saída ✅ migration `20261013120000` | Ainda guarda `numero_completo varchar(40)` ✅ | — |
| Pedido no Omie | Resumo "a digitar no Omie" e `PUT /:id/pedido_omie` ✅ `propostas.routes.ts:196-210` | `numero_pedido_omie` na proposta ✅ | — |
| Análise do Simulador de Comissões | 8 colunas em `propostas` e 16 em `propostas_itens` ✅ migration `20261016120000` | **Nenhuma** das 24 colunas ✅ | — |
| Base transversal (Decimal, zod, `If-Match`, idempotência, `asyncHandler`, erro HTTP) | ✅ | — | ✅ `38d2f74`: `src/utils/{decimal,validacao,versaoOtimista,asyncHandler,erroHttp}.js`, testes em `test/unit` |
| Rotas | ~91 handlers | — | ✅ só `/comercial` cadastros (`/me`, emissoras, responsáveis, parâmetros de custo) e `capacidades.js`; `/suprimentos` montado e fechado |

Conclusão: a `052` é uma conversão do `api-comercial` anterior a 13/10 (ainda com `numero_completo` e sem a análise). Pelas rotas e pelos testes, a parte do Gustavo na fase 1 do LOG-52 está feita; a fase 2 (domínio portado) é a próxima e é do Pablo.

## 3. O ciclo da proposta: o que porta, o que troca e o que sai

| Hoje no `api-comercial` | No desenho de 26/10 | Ação na migração | Selo |
|---|---|---|---|
| Cálculo de linha, totais, margem, custo líquido, médias, telha | Igual (N16-11) | Portar como está, com os testes | 📝 |
| `ABERTA` editável; `fechar` total ou por itens; `PARCIAL` | `ABERTA` → `APROVADA` (trava) → `TRANSFORMADA`; sem fechamento parcial | Trocar: `aprovar` no lugar de `fechar`; sai o fechamento por item | 📝 N16-02, N16-03 |
| `perder` com motivo; `reabrir` | `cancelar` com motivo (mesma lista de motivos); não reabre | Trocar `perder` por `cancelar`; apagar `reabrir` | 📝 N16-03 |
| Proposta incompleta salva e fecha | Incompleta (item sem custo ou sem fornecedor) não aprova | Novo: checar antes de aprovar; o banco também barra (`trg_propostas_travar`) | 📝 N16-31 |
| Resumo "a digitar no Omie", planilha e `PUT /pedido_omie` | "Transformar em pedido" com 3 respostas obrigatórias; fila e pipeline | Sai o resumo; entra `POST` que chama `fn_propostas_transformar_em_pedido` | 📝 N16-02, N16-89 |
| `empresas_emissoras` | A unidade é a emissora (`unidades_emissoras`, 1:1 com `core.unidades`) | Trocar o model; não criar tabela | 📝 N16-80, N16-98 |
| Câmbio da AwesomeAPI | PTAX do dia da aprovação | Ler `core.cotacoes_moeda` | 📝 N16-27 |
| Imposto digitado no item | Igual; entram CFOP e cenário do Omie | Portar e acrescentar `cfop`, `codigo_cenario_omie` | 📝 N16-83, N16-95 |
| Sincronização Omie própria, migração do ERP antigo | Saem | Não portar | 📝 N16-13, N16-14 |

## 4. O que o Pablo entregou de 16 a 19/10 e onde fica no desenho novo

| Entrega (PR) | O que faz | No desenho de 26/10 | Proposta | Selo |
|---|---|---|---|---|
| Motor do Simulador de Comissões copiado para o `api-comercial` (#215) | Mesmo cálculo de `lib/simulador/motor.ts`, 47 testes e teste de paridade | BL-078: portar o motor para a `api-acos-vital` | Portar a cópia já testada (TypeScript para JavaScript) na fase 2, junto do domínio | ✅ 🟡 |
| Análise de margem na proposta (#215, #220) | Grava custo líquido, preço sugerido, margem, letra e comissão prevista na proposta | Entradas em `core_comercial` (anexo `0003`); saídas em `core_comissao.comissao_calculos` e `comissao_calculo_itens` | Seguir o desenho: entradas na proposta, saídas na comissão. As 24 colunas do `api-comercial` não vão para o banco | 📝 N16-19 🟡 |
| "Sugerir custos" com o lado da compra (#221) | Preenche preço, quantidade, unidade, origem, IPI e ST da compra a partir da oferta | É a "parte de compras" do item (N16-38, N16-106) | Portar; grava nas colunas do anexo `0003` | 🟡 |
| Fórmula antiga de preço fora da tela (#222) | Custo × kg/m × metragem sai da tela quando há análise | Sem decisão | Manter só para a telha | 🔴 Nathan |
| PDF de aprovação interna (#225) | Custo, preço praticado e sugerido, margem e letra por item | A aprovação da Gerência é física (N16-12, N16-75) | Manter como apoio para a aprovação física, lendo o cálculo da comissão | 🔴 Nathan |
| Tela Simulador de Orçamento (`/orcamento/simulador-orcamento`, #214) | Simula um orçamento no motor sem criar proposta | A tela da proposta no formato do Simulador é do Nathan (N1, BL-075) | Decidir se a tela fica, vira a base da N1 ou sai | 🔴 Nathan |
| Correção de escopo `?responsavel=` (#219) | O filtro soma ao escopo e não o substitui | Vale igual (M1 do LOG-52) | Portar com o teste | ✅ |

Duas pendências antigas do Pablo perdem o sentido ou mudam com o desenho:

- **Emissão só pela auxiliar** (fase 5 da Proposta de Orçamento): o desenho dá à auxiliar o mesmo escopo do vendedor 🟡 ([[11-Proposta-e-Pedido-de-Venda]]) e não prevê emissão separada. Proposta: arquivar a fase 5.
- **Margem líquida no Relatório Gerencial** (fase 6): com a comissão nova, a margem passa a vir de `core_comissao`. Proposta: o relatório lê de lá, e a mistura de margem bruta com líquida deixa de existir.

## 5. Divergências encontradas nos contratos

| # | Onde | O que está escrito | O que o banco ou o código mostra | Correção proposta |
|---|---|---|---|---|
| D1 | SQL-018 anexo `0003`, linha 24 | `propostas_itens.fornecedor_nome / id_fornecedor (já existem)` | Só existe `fornecedor varchar(200)` e `id_oferta` (dump `a7fda49`); nem o SQL-016 cria `id_fornecedor` | Criar `id_fornecedor uuid` (FK para `core.parceiros`) no SQL-016 ou no `0003`; `fn_item_completo` deve olhar o id, não o texto |
| D2 | SQL-018 anexo `0003` × `api-comercial` | `destino_icms`, `condicao_encargo`, `natureza_custo = 'FABRICACAO'`, custo em `custo` | `estado_destino`, `condicao_pagamento_chave`, `tipo_item = 'FABRICACAO_INTERNA'`, `preco_unit_compra` | Valer o nome do `0003` (é o que vai ao banco); o Pablo troca no código portado |
| D3 | SQL-018 anexo `0003`, linha 21 | `propostas_itens.custo` ❓ é o unitário na unidade de compra? | No `api-comercial`, `custo` é o custo da fórmula antiga de preço (multiplicado por kg/m e metragem); o preço de compra fica em `preco_unit_compra` | Criar `preco_unit_compra` no `0003` em vez de reaproveitar `custo` |
| D4 | LOG-52, Q5 e Q9 | 🟡 abertas | Respondidas: PTAX (N16-27) e sem migração do ERP antigo (N16-13) | Marcar 📝 |
| D5 | LOG-52, situação | "só a fase 1 do banco existe" | A base da API também existe (`38d2f74`) | Registrar a fase 1 da API como feita |

## 6. O que o Pablo propõe

1. Começar a fase 2 do LOG-52 (domínio portado com os testes, incluindo o motor) num branch da `api-acos-vital`. A fase 2 não depende do ciclo da proposta.
2. Fazer a fase 3 já no ciclo novo, sobre o SQL-016 aplicado: não portar `fechar`, `perder`, `reabrir` nem o pedido digitado.
3. Congelar o `api-comercial`: só correção de defeito até o corte no HUB (fase 6). Nenhuma regra nova entra nele.
4. Usar os nomes de coluna do anexo `0003` (D2, D3) e corrigir D1 antes de o Gustavo aplicar o SQL-016.

## 7. Perguntas para fechar antes da fase 3

| # | Pergunta | Quem | Bloqueia |
|---|---|---|---|
| A1 | De acordo com os itens 1 a 4 da seção 6? | Nathan | fase 2 |
| A2 | D1 a D3: o Gustavo incorpora no SQL-016 ou no anexo `0003` do SQL-018? | Gustavo | fase 3 |
| A3 | O PDF de aprovação interna, a tela Simulador de Orçamento e a fórmula antiga ficam? (seção 4) 📝 Em parte respondida pelo LOG-62 (N16-109): o Simulador de Orçamento sai e o PDF segue; a fórmula antiga segue sem resposta | Nathan | fase 3 |
| A4 | Formato do número (PS-038): só dígitos ou com prefixo? | Nathan | fase 3 |
| A5 | O Pablo escreve num branch e o Gustavo revisa (Q10 do LOG-52)? Qual branch base: `develop`? | Nathan, Gustavo | fase 2 |
| A6 | De acordo com a reestimativa da seção 8 e com a alternativa A? | Nathan | [[Cronograma]] |

## 8. Reestimativa do Pablo para P1 a P7

Validação pedida no [[Cronograma]] ("cada pessoa confirma os seus pd e o seu foco livre"). Mesmo método: pd por complexidade, ±30%, dias úteis = pd ÷ foco, foco de 75%, feriados nacionais e Carnaval. Início em 28/10/2026: até 23/10 o Pablo estava nas entregas do `api-comercial` (seção 4), e o P1 não começou em 19/10 como o plano previa.

O que mudou desde a estimativa de 16/10:

- ✅ A base transversal e as capacidades já estão na API (`38d2f74`): saem do P1.
- ✅ O motor da comissão já foi copiado e testado (PR #215, 47 testes de motor e paridade): portar é mecânico e entra no P1. O P6 fica só com a gravação da versão e o recálculo.
- ✅ Tamanho medido na `develop`: domínio com 2.668 linhas em 17 arquivos (3 não portam: `fechamento.ts`, `erpAntigo.ts`, `perfisDev.ts`) e 219 casos de teste unitário; módulos de proposta (2.757 linhas), clientes (585), custos (631) e suprimentos (2.255). A API de destino é JavaScript com Express 4 e `vitest`.
- 🔴 Entrou depois de 16/10 e não tinha pd: o pedido digitado no Omie no mesmo fluxo, com a parte de compras preenchida no Hub (N16-106), e o "+1 dia útil" com a biblioteca de feriados (N16-96). Viram o bloco novo P8.

| Bloco | 16/10 (pd) | Agora (pd) | Por quê | Início | Fim |
|---|---|---|---|---|---|
| P1 Domínio portado e testes, com o motor | 8,0 | 6,0 | Base transversal pronta; motor já testado | 28/10/2026 | 09/11/2026 |
| P2 Clientes e propostas no ciclo novo | 13,0 | 13,0 | Ciclo mais simples, mas entram aprovar, cancelar, PTAX, CFOP, cenário e `vinculados` | 10/11/2026 | 04/12/2026 |
| P3 Pedido por API | 6,0 | 6,0 | As funções do SQL-016 fazem a maior parte | 07/12/2026 | 16/12/2026 |
| P4 Suprimentos e pedido de custo | 8,0 | 8,0 | Sai a sincronização Omie; entra o tempo cronometrado | 17/12/2026 | 04/01/2027 |
| P5 Orçamento | 10,0 | 10,0 | Sem mudança | 05/01/2027 | 22/01/2027 |
| P6 Motor da comissão na API | 8,0 | 3,0 | O porte foi para o P1; fica a versão gravada e o recálculo | 25/01/2027 | 28/01/2027 |
| P7 Custo por evento | 6,0 | 6,0 | Sem mudança | 29/01/2027 | 11/02/2027 |
| P8 Pedido do Omie no fluxo e dias úteis (novo) | — | 4,0 | N16-106, N16-96 | 12/02/2027 | 19/02/2027 |
| **Total** | **59,0** | **56,0 (39,2 a 72,8)** | | **28/10/2026** | **19/02/2027** |

Dependências que podem mover as datas:

- 🔴 P2 começa em 10/11, antes do SQL-016 aplicado (G1 vai até 25/11 na proposta do cronograma). Mitigação: o Pablo desenvolve contra o dump de referência com o SQL-016 aplicado localmente, como o teste `0002` já faz.
- 🔴 P3 depende da liberação do pedido da proposta (G5, até 08/12) e começa em 07/12.

**Alternativa A** (o Pablo faz as telas de Orçamento, N7, 9 pd): 🟡 o Pablo concorda. As telas do Orçamento no HUB hoje são dele (painel do comprador, pedido de cotação, ofertas, catálogo, pesquisa de materiais). Com A, o fim dele vai a **09/03/2027**.

> [!warning] A ordem mudou em 27/10 (N16-114, N16-115)
> O Pablo começa por **produtos e histórico de preço** ([[Roteiro-da-Proposta-em-Diante]] §5), e a criação da proposta (`V0.1`, `V0.2`) e a comissão estimada (`K1`) ficaram com o Nathan. Os blocos P2 e P6 acima encolhem; a reestimativa precisa ser refeita depois que a seção 9 for combinada.

## 9. Andamento de produtos e histórico de preço (N16-114), 28/10/2026

O Pablo começou em 27/10 pela parte de produtos, antes de ler as N16-111 a N16-115, que entraram no vault no mesmo dia. O trabalho está em dois branches **só na máquina dele, sem PR**:

- `api-acos-vital`, `feat/comercial-produtos` (8 commits sobre `a7fda49`): rotas em `/suprimentos`, testes de ponta a ponta contra o dump de referência em Postgres 18 e documentação no Swagger. O push foi recusado: a conta do Pablo não tem escrita no repositório.
- `av-hub`, `feat/orcamento-tela-produtos` (4 commits sobre `a24d187`): a tela Produtos com as abas Produtos, Comparar e Ofertas do LOG-62 §3.2, sobre a `api-comercial` de teste, com e2e.

### 9.1 O que já está alinhado às decisões de 27/10

| Item | Situação | Selo |
|---|---|---|
| Domínio de custo e preço portado do `api-comercial` (custo líquido, custo de referência, validade, médias de 90 dias, trava de escala), com os casos de teste | Serve a qualquer fonte de preço: as médias usam valor, quantidade, data e fornecedor | ✅ `dominio/custo.js`, `dominio/medias.js` (33 casos) |
| `GET /suprimentos/produtos` e `/produtos/:id` sobre `core.produtos`, com busca por termos, escopo por unidade e o perfil técnico como extensão opcional | É o item 2 do Roteiro §5; falta o **nome da família** (`core.familia_produtos`) | ✅ 🟡 |
| Permissão por `auth.rotas_telas`, uma linha por rota (lista no PR) | Segue o LOG-52 §8 | ✅ |
| Documentação no Swagger com teste que falha se uma rota de `/suprimentos` ficar sem ela | Novo | ✅ |

### 9.2 O que vai contra a N16-111 e a N16-112 e precisa ser refeito

| Item no branch | Conflito | Proposta do Pablo |
|---|---|---|
| Preços, ofertas e Comparar leem `core_comercial.ofertas` | A oferta passa a ser **uma tabela**: `orc_cotacoes` ou `parceiros_produtos` (N16-112); o preço real vem de `pedidos_compras_itens` | Trocar a fonte do histórico para `pedidos_compras_itens` (compras reais) e `orc_cotacoes` (cotações), como o Roteiro §5 item 3 pede |
| Custo líquido (IPI, ST, crédito de ICMS) no histórico | `orc_cotacoes` só tem valor, data e origem; `pedidos_compras_itens` não tem imposto por item (PS-014) | O histórico mostra **preço** (com desconto), não custo líquido; o custo líquido volta quando a oferta única tiver os impostos |
| Ofertas: lançar e invalidar em `core_comercial.ofertas`; produtos pendentes em `core_comercial.produtos_pendentes` | Saem como cadastro próprio (N16-112: pendente vira extensão do produto) | Esperar a decisão de qual tabela absorve a oferta; até lá, não publicar essas rotas |
| Prefixo `/suprimentos` | O Hub já tem `/orcamento/*` (`orc_*`) e a API-020 desenha `/orcamento/produtos` | Usar `/orcamento/produtos` |
| Tela Produtos com abas, no av-hub | O Nathan reconectou as telas ao Hub no branch `refactor/menu-enxuto-vendas-orcamento-compras`, que tira a `api-comercial` (N16-111) | Não abrir PR do branch do Pablo; juntar com o do Nathan quando ele subir |

### 9.3 Perguntas

| # | Pergunta | Quem |
|---|---|---|
| A7 | A oferta única fica em `orc_cotacoes` ou em `parceiros_produtos`? Ela ganha IPI, ST, origem do ICMS, frete, validade e prazo em dias (o score precisa do prazo, [[Proposta-Score-e-Volatilidade-OQ-46]])? | Nathan, Gustavo |
| A8 | O histórico de preço junta compras (`pedidos_compras_itens`) e cotações (`orc_cotacoes`) na mesma série, marcando a origem de cada ponto? | Nathan |
| A9 | A tela Produtos com abas (LOG-62 §3.2) fica com quem, já que o branch do Nathan reconecta as mesmas telas? | Nathan |

## Ver também

[[Mapa-do-Modulo-do-Pablo]] · [[Comercial-Suprimentos]] · [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] · [[11-Proposta-e-Pedido-de-Venda]] · [[Backlog-por-Frente]] · [[Cronograma]]
