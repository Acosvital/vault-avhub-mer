---
tags: [projeto, equipe, divisao]
criado: 2026-10-14
atualizado: 2026-10-26
status: vigente
dono: Nathan
fontes: [v1 05-Pessoas-e-Equipe/Equipe-Projeto, v1 Cronograma-2-Meses §3.2 e §3.4, v1 Registro-de-Decisoes #32 #33 #33b, git log dos repositórios em 14/10/2026, Registro-de-Decisoes N16-09 e N16-15]
---

# Equipe e divisão

Nomes completos pelo `git log`.

## Quem faz o quê

| Pessoa | Papel | Frente | Foco no plano | Capacidade S1–FC |
|---|---|---|---|---|
| **Nathan** | Coordenador de TI e arquiteto do ERP; dono deste vault, das decisões e do pipeline Omie 📝 | Front do av-hub (telas e BFF), `omie-elt-pipeline`, contratos, coordenação; telas de Vendas, Orçamento, Compras e Comissão nova e pipeline do pedido de venda (N16-15) | 40% | 16,8 pd |
| **Gustavo M. de Farias** | Colega, DBA | Banco e API do av-hub (`api-acos-vital`): migrations, `auth.*`, funções, envio fixo da OC, chave do MES (L6), `exclusionSync`; revisa e aplica no banco o módulo do Pablo (`core_comercial`, com o Orçamento) e a comissão nova (`core_comissao`) (N16-15) | 60% | 25,2 pd |
| **Robert Wilson** | Colega, fullstack sênior | MES inteiro: `api-pcp` e `app-pcp`, incluindo Recebimento, carga inicial em lote (G1), baixa no despacho, D11 (leitor 2D e posto de recebimento), I1/J2/J5; custo obrigatório em todo lote e `GET /itens/custo` (N16-09) | 75% | 31,5 pd |
| **Pablo Cruz** | Colega, fullstack | Comercial & Suprimentos: módulo de proposta, pedido de venda e Orçamento, migrado para a `api-acos-vital` (N16-15; o `api-comercial` é só de teste). Saiu do MES em 07/10 | 75% | 31,5 pd (hoje fora da conta do plano) |

Foco e capacidade são premissa do plano de 21/09, não alocação registrada em RH 🟡. Fonte: [[Cronograma]]. Atribuições: Pablo no Comercial & Suprimentos e MES com o Robert 📝 (decisões #32 e #33 do Registro do v1); em 14/10 as decisões do Nathan reafirmam a divisão ([[Registro-de-Decisoes]]).

Evidência no git (desde 15/09/2026, 14/10): os commits do MES são do Robert (28 no `api-pcp`, 37 no `app-pcp`); os do Pablo no MES (9 e 17) são anteriores à reatribuição; os do Comercial & Suprimentos no HUB são do Pablo (258) ✅. Detalhe em [[Sistemas-e-Responsabilidades]].

## O que cada pessoa decide e entrega

| Quem | Decide | Entrega neste vault |
|---|---|---|
| Nathan | Regras de negócio e fluxo; nomes de tela; escopo; priorização | Telas do HUB, BFF, [[Backlog-por-Frente]] da frente front, aprovação dos contratos |
| Gustavo | Modelo de banco, funções e rotas da API do av-hub; chaves de serviço | Migrations (`047b`, `046b`, `035b`), mapa de `auth.rotas_telas`, SQL dos contratos |
| Robert | Modelo e regras do MES; telas do `app-pcp` | Documento de retirada, `lote_custo`, feed `/fluxo/eventos`, job do contrato 004 |
| Pablo | Desenho do Comercial & Suprimentos | Publicação do `api-comercial`, telas e perfis do módulo |

## Capacidade do Robert (risco)

Com G1, D11, I1, J2, J5 e D12 no Robert e o custo do lote (K3 a K6) somado, o plano fecha em **déficit de 16,1 pd** no Ciclo 1 (**32,6 pd desde 15/10**, com o N14-29, e o Nathan aceitou deslocar a data: N14-30) (planejado 64,85 pd contra 48,75 pd de capacidade), sem contar a baixa no despacho do Estoque, que não tem pd dimensionado 🟡 (estimativas minhas, ±30%, o Robert valida). Consequência: o Ciclo 1 só fecha em 21/01/2027 e o Ciclo 2 começa em 22/01/2027 (**desde 15/10, 18/02/2027 e 19/02/2027**, N14-30 e N14-32). Conta em [[Cronograma]]; risco em [[Riscos]].

## Outros atores do processo (perfis de uso, não de desenvolvimento)

| Ator | Onde atua | Nota |
|---|---|---|
| Vendedor, Gerente (equipe) | HUB: Liberar Pedidos, Pedidos da equipe | [[01-Vendas-Liberacao]] |
| PCP e Almoxarife (setor Estoque) | `app-pcp`: Triagem, Destinação, Atendimento | [[02-PCP-Triagem-e-Destinacao]], [[03-Estoque-Atendimento-e-Despacho]] |
| Comprador (livre até R$ 30 mil), Gerente de Compras (aprova acima de R$ 30 mil) | HUB: Compras | [[04-Circuito-de-Compra]] |
| CCP (follow-up de compras) | HUB Follow-up; MES Compras · CCP (leitura) | O pessoal do CCP faz parte do PCP e cuida do follow-up das compras; Compras acessa só para ler; havendo ocorrência, o CCP interage aprovando ou não 📝 (Nathan, 14/10). O perfil será criado em breve: tarefa cadastral simples, sem bloqueio de desenho (Nathan, Gustavo; N14-24) |

| Recebimento (doca), Qualidade | `app-pcp` | [[05-Recebimento]], [[06-Qualidade-Entrada]], [[08-Qualidade-Saida]] |
| Operador de fábrica, Expedição | `app-pcp` | [[07-Producao-e-Roteiro]], [[09-Expedicao]] |
| Fiscal | Omie | Emite a nota e separa o pedido em sequenciais para faturar em partes; informa a devolução parcial ([[10-Fiscal-Omie]], N16-92, N16-74) |
| Orçamento (setor orçamentário, novo; o Moisés é uma das pessoas) | HUB: Orçamento | Cota com fornecedores e mantém a base de preço de compra com histórico; o vendedor só consulta ([[12-Orcamento-Base-de-Preco]], N16-104) |
| Gerência (João Vitor, Sérgio Vital) | Fora do sistema neste ciclo | Aprova desconto e margem da proposta fisicamente; recebe de Compras os casos de compra acima do valor reprovados pelo vendedor (N16-12, N16-66) |
| Controladoria (Michele) | HUB: Operações | Decide a comissão ao fim, com o custo real, e tem a visão geral e os relatórios ([[13-Custo-Real-e-Comissao-no-Fluxo]], N16-10, N16-50) |
| Marketing | HUB: calendário | Cadastra as exceções do calendário da unidade (feriados e dias úteis) usadas na previsão de faturamento (N16-104) |

## Tarefas cadastrais (não são desenvolvimento)

Nathan e Gustavo criam em breve, sem bloqueio de desenho 📝 N14-24: o **perfil CCP** (BL-017) e o **vínculo de usuários à Gerência de Compras** (hoje sem usuários, dump de 07/10 ❓ conferir no de 14/10), além do vínculo de compradores a funcionários (BL-045). O perfil **orçamentista** também precisa existir (N16-59).

Permissões por perfil: [[RBAC-e-Permissoes]]. Atores nos casos de uso: [[Casos-de-Uso|Diagrama-Casos-de-Uso]].
