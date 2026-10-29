---
tags: [projeto, equipe, divisao]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [v1 05-Pessoas-e-Equipe/Equipe-Projeto, v1 Cronograma-2-Meses §3.2 e §3.4, v1 Registro-de-Decisoes #32 #33 #33b, git log dos repositórios em 14/10/2026 e em 29/10/2026, Registro-de-Decisoes N16-09, N16-15, N16-117, N16-118 e N16-119]
---

# Equipe e divisão

**Em uma frase:** são quatro pessoas de TI, cada uma dona de uma parte do sistema: Nathan (telas do Hub), Gustavo (banco e API do Hub), Robert (MES e, desde 28/10, o módulo comercial na API do Hub) e Pablo (acompanha o comercial e cuida do Orçamento).

**Quando consultar esta nota:** quando você precisar saber quem decide, quem constrói e a quem perguntar sobre cada parte.

Os nomes completos vêm do `git log`.

## Quem faz o quê

| Pessoa | Papel | O que toca |
|---|---|---|
| **Nathan** | Coordenador de TI e arquiteto do ERP. É o dono deste vault, das decisões e do pipeline Omie 📝 | Telas do av-hub (o front e o BFF, a camada que liga o front à API), o `omie-elt-pipeline`, os contratos e a coordenação. Faz as telas de Compras, da Comissão nova e do restante do HUB, e o pipeline do pedido de venda (N16-15). **As telas de proposta são do Robert e as de Orçamento são do Pablo com o Robert** (conferido no git em 29/10) |
| **Gustavo M. de Farias** | Colega, DBA (administrador de banco de dados) | Banco e API do av-hub (`api-acos-vital`): migrations, `auth.*`, funções, envio fixo da OC, chaves de serviço do MES e da pipeline (L6) e `exclusionSync`. Revisa e aplica no banco o módulo comercial e o Orçamento e a comissão nova (`core_comissao`, N16-143) (N16-15) |
| **Robert Wilson** | Colega, fullstack sênior | O MES inteiro (`api-pcp` e `app-pcp`): Recebimento, carga inicial em lote (G1), baixa no despacho, D11 (leitor 2D e posto de recebimento) e I1/J2/J5. Também o custo obrigatório em todo lote e o `GET /itens/custo` (N16-09, feito na `develop` em 27/10). **Desde 28/10 conduz o módulo comercial na `api-acos-vital`** (N16-117) e troca o backend das telas de proposta (N16-118, N16-119); já criou as rotas `/comercial/*` de cadastros, clientes, parceiros e propostas |
| **Pablo Cruz** | Colega, fullstack | Criou o módulo Comercial & Suprimentos (a `api-comercial`, hoje só legado de leitura, N16-117). **Desde 28/10 acompanha** o módulo comercial, que o Robert conduz, e cuida do Orçamento, com a supervisão do Robert. Ele saiu do MES em 07/10 |

Atribuições decididas: Pablo no Comercial & Suprimentos e Robert no MES 📝 (decisões #32 e #33 do Registro do v1), reafirmadas em 14/10. Em 28/10 o Nathan passou a condução do módulo comercial para o Robert, com o Pablo acompanhando (N16-117) ([[Registro-de-Decisoes]]). O detalhe de repositórios está em [[Sistemas-e-Responsabilidades]].

## O que cada pessoa decide e entrega

| Quem | Decide | Entrega neste vault |
|---|---|---|
| Nathan | Regras de negócio e fluxo; nomes de tela; escopo; prioridade | Telas do HUB, BFF, [[Backlog-por-Frente]] da frente front, aprovação dos contratos |
| Gustavo | Modelo de banco, funções e rotas da API do av-hub; chaves de serviço | Migrations (`047b`, `046b`, `035b`), mapa de `auth.rotas_telas`, SQL dos contratos |
| Robert | Modelo e regras do MES; telas do `app-pcp`; rotas do módulo comercial na `api-acos-vital` e telas de proposta | Documento de retirada, `lote_custo`, feed `/fluxo/eventos`, job do contrato 004 (feito, K4), rotas e telas da proposta |
| Pablo | Acompanha o módulo comercial; Orçamento (com o Robert) | Regras do legado a portar ([[Mapa-do-Modulo-do-Pablo]]) e as telas de Orçamento |

## Risco: capacidade do Robert

O plano pede mais trabalho do Robert do que ele consegue entregar no prazo. O Ciclo 1 só fecha em 18/02/2027 por causa disso. Ele chegou a ser 21/01/2027, e o Ciclo 2 começa em 19/02/2027 (N14-30 e N14-32). Conta em [[Cronograma]]; risco em [[Riscos]].

## Quem usa o sistema (perfis de uso, não de desenvolvimento)

| Ator | Onde atua | Nota |
|---|---|---|
| Vendedor, Gerente (equipe) | HUB: Liberar Pedidos, Pedidos da equipe | [[01-Vendas-Liberacao]] |
| PCP e Almoxarife (setor Estoque) | `app-pcp`: Triagem, Destinação, Atendimento | [[02-PCP-Triagem-e-Destinacao]], [[03-Estoque-Atendimento-e-Despacho]] |
| Comprador (livre até R$ 30 mil), Gerente de Compras (aprova acima de R$ 30 mil) | HUB: Compras | [[04-Circuito-de-Compra]] |
| CCP (acompanhamento de compras) | HUB Follow-up; MES Compras · CCP (leitura) | O pessoal do CCP faz parte do PCP e acompanha as compras. Compras acessa só para ler. Havendo ocorrência, o CCP interage aprovando ou não 📝 (Nathan, 14/10). O perfil será criado em breve: tarefa cadastral simples, sem bloqueio de desenho (Nathan, Gustavo; N14-24) |
| Recebimento (doca), Qualidade | `app-pcp` | [[05-Recebimento]], [[06-Qualidade-Entrada]], [[08-Qualidade-Saida]] |
| Operador de fábrica, Expedição | `app-pcp` | [[07-Producao-e-Roteiro]], [[09-Expedicao]] |
| Fiscal | Omie | Emite a nota e separa o pedido em sequenciais para faturar em partes. Informa a devolução parcial ([[10-Fiscal-Omie]], N16-92, N16-74) |
| Orçamento (setor orçamentário, novo; o Moisés é uma das pessoas) | HUB: Orçamento | Cota com fornecedores e mantém a base de preço de compra com histórico. O vendedor só consulta ([[12-Orcamento-Base-de-Preco]], N16-104) |
| Gerência (João Vitor, Sérgio Vital) | Fora do sistema neste ciclo | Aprova desconto e margem da proposta fisicamente. Recebe de Compras os casos de compra acima do valor reprovados pelo vendedor (N16-12, N16-66) |
| Controladoria (Michele) | HUB: Operações | Decide a comissão ao fim, com o custo real. Tem a visão geral e os relatórios ([[13-Custo-Real-e-Comissao-no-Fluxo]], N16-10, N16-50) |
| Marketing | HUB: calendário | Cadastra as exceções do calendário da unidade (feriados e dias úteis), usadas na previsão de faturamento (N16-104) |

## Tarefas de cadastro (não são desenvolvimento)

Nathan e Gustavo fazem em breve, sem bloquear o desenho 📝 N14-24:

- o **perfil CCP** (BL-017);
- o **vínculo de usuários à Gerência de Compras** (hoje sem usuários, dump de 07/10 ❓ conferir no de 29/10);
- o vínculo de compradores a funcionários (BL-045);
- o perfil **orçamentista**, que também precisa existir (N16-59).

Permissões por perfil: [[RBAC-e-Permissoes]]. Atores nos casos de uso: [[Casos-de-Uso|Diagrama-Casos-de-Uso]].

## Detalhe técnico

### Foco e capacidade de cada pessoa

Foco e capacidade são premissa do plano de 21/09, não alocação registrada em RH 🟡. Fonte: [[Cronograma]].

| Pessoa | Foco no plano | Capacidade S1–FC |
|---|---|---|
| Nathan | 40% | 16,8 pd |
| Gustavo | 60% | 25,2 pd |
| Robert | 75% | 31,5 pd |
| Pablo | 75% | 31,5 pd (hoje fora da conta do plano) |

### Evidência no git

Desde 15/09/2026, em 14/10: os commits do MES são do Robert (28 no `api-pcp`, 37 no `app-pcp`). Os do Pablo no MES (9 e 17) são anteriores à reatribuição. Os do Comercial & Suprimentos no HUB são do Pablo (258 em 14/10, 348 em 29/10) ✅. Desde 28/10 os commits das telas de proposta no HUB e das rotas `/comercial/*` na API são do Robert ✅ (git, 29/10). Detalhe em [[Sistemas-e-Responsabilidades]].

### Conta da capacidade do Robert

Com G1, D11, I1, J2, J5 e D12 no Robert e o custo do lote (K3 a K6) somado, o plano fecha em **déficit de 16,1 pd** no Ciclo 1 (**32,6 pd desde 15/10**, com o N14-29, e o Nathan aceitou deslocar a data: N14-30). O planejado é 64,85 pd contra 48,75 pd de capacidade. A conta não inclui a baixa no despacho do Estoque, que não tem pd dimensionado 🟡. As estimativas são minhas, ±30%, e o Robert valida.

Consequência: o Ciclo 1 só fecha em 21/01/2027 e o Ciclo 2 começa em 22/01/2027. **Desde 15/10, as datas são 18/02/2027 e 19/02/2027** (N14-30 e N14-32).
