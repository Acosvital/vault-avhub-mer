---
tags: [erp-acos-vital, onboarding, indice]
criado: 2026-09-21
---

# Comece aqui

> Para quem entra no projeto (ou volta depois de um tempo). Em 30 minutos você sabe **o que existe, o que falta construir, o que ler primeiro e o que fazer na primeira semana**. O mapa completo está em [[Home]].

## 1. O que existe hoje e o que é para construir

- **Existe e roda:** a Entrada Comercial. O pedido é criado no Omie, o pipeline ([[Omie-ELT-Pipeline]]) o leva ao av-hub, e o Portal do Vendedor o mostra. Existe também o motor de execução de roteiro de Flanges (`api-pcp`), mas só depois que uma Ordem de Produção chega até ele.
- **Não existe, é 100% manual hoje:** triagem do PCP, requisição de compra, Compras no sistema, Recebimento, Qualidade, Estoque, Expedição e faturamento operacional. **Tudo isso é o que vamos construir**, cobrindo todos os passos dos 6 fluxogramas de [[Fluxogramas-Completos]].
- **A execução começa em 22/09/2026.** Até lá o vault é só planejamento; nada do que ele descreve como "a construir" está pronto.
- **Para saber o ponto exato em que o projeto está** (marcos, quadro de tarefas, bloqueios), abra [[Onde-Estamos]], que é atualizada durante a execução.

## 2. Leitura comum (todos, nesta ordem)

1. [[Setores-Envolvidos-no-Fluxo]] — quem participa do pedido e onde cada setor vai viver (av-hub, MES ou Omie).
2. [[Fluxo-Detalhado-Pedido-Item]] — o fluxo item a item, que é a espinha do sistema.
3. [[Modelo-Destinacao-Item]] — como cada item é classificado (Revenda ou Fabricação × pronto, matéria-prima ou sem estoque) e [[Encaixe-Estoque-Revenda-no-PCP]] — como isso virou roteiro no MES (24/09/2026): a fábrica escolhida define a natureza e o setor Estoque, etapa 1 de todo roteiro, resolve a disponibilidade.
4. [[Fluxogramas-Completos]] — os 6 fluxos visuais.
5. [[Cronograma-2-Meses]] — o plano de 18/09 a 18/11: marcos, quem faz o quê, o que entra e o que não entra.
6. [[Perguntas-em-Aberto-Consolidadas]] — o que ainda não está decidido e quem responde.

## 3. Por pessoa: o que ler e o que fazer na primeira semana

As tarefas vêm da seção S1 do [[Cronograma-2-Meses]] (os IDs são os de lá). Com o início em 22/09, as janelas de S1 estão deslocadas um dia.

| Pessoa | Primeiras tarefas | Leitura específica |
|---|---|---|
| **Nathan** (coordenação, av-hub) | A1 decisões DEC-1 a DEC-9 · A2 hardware e agenda do levantamento físico · F1 spec da integração av-hub ↔ MES | [[Decisoes-Chave-ERP]], [[MES-Arquitetura-Decisoes]], [[Rastreabilidade-e-SLA-de-Eventos]] |
| **Gustavo** (banco, API, pipeline) | B1 fechar as perguntas dos contratos · B2 homologação e backup do banco do MES · depois B3 (contratos SQL 001 e 005) e B4 (`alterado_desde`) | [[Indice-Contratos]], [[Schema-Postgres-Multi-Dominio]], [[Indice-Integracao-Omie]], [[Roteiro-de-Implementacao]] |
| **Robert** (MES, PCP) | C1 login duplo · C3 desenho do RBAC por setor · C2 vínculo Fábrica ↔ Filial · C4 Carteira do PCP | [[App-PCP-Backend-Producao]], [[App-PCP-Modelo-Producao]], [[Fluxo-Producao-OS-OP-Completo]], [[Achado-Duplicacao-RBAC]] |
| **Pablo** (MES, Estoque) | D1 schema Prisma do Estoque · D2 módulo base · D3 projeção de material e parceiro | [[PRD-Estoque-Visao-Geral]], [[Estoque-Modelo-Dados]], [[Estoque-Regras-Negocio]], [[Estoque-Riscos]], [[Fluxo-Recebimento-Completo]], [[Fluxo-Qualidade-Completo]] |

**Antes de escrever a primeira migration (Pablo e Gustavo):** leia a seção 4.1 de [[Campos-e-API-para-Rastreabilidade]]. Há campos de autoria e tempo que precisam entrar já no schema v1.

## 4. As decisões que destravam a primeira semana

DEC-4 (lote de carga inicial) e DEC-7 (contratos SQL) travam a D1. DEC-1 destrava a C2. DEC-2 destrava a integração. Todas têm prazo e um default escrito na seção 7 do [[Cronograma-2-Meses]]; a lista completa por pessoa está em [[Perguntas-em-Aberto-Consolidadas]].

## 5. Princípios que valem para tudo

Já provados nos sistemas atuais; ver [[Decisoes-Chave-ERP]].

- **O sistema nunca emite nem edita nota fiscal.** Isso é sempre do Omie. O sistema só sinaliza e referencia.
- **av-hub decide, MES executa.** Orçamento, pedido de venda e ordem de compra nascem no av-hub; produção, recebimento e saldo, no MES.
- **Só polling entre sistemas.** Não existe webhook nem tempo real; não assumir.
- **Colunas protegidas.** Cada coluna tem um dono; o pipeline do Omie nunca escreve nas que pertencem a outro sistema.
- **Sem FK entre entidades sincronizadas de forma independente.**
- **Nenhum estado é beco sem saída.** Reprovou, divergiu ou devolveu: sempre há um caminho de volta ([[Estoque-Riscos]]).
- **Lote nasce em quarentena** e só libera com laudo e aprovação da Qualidade.
- **Segregação de função:** quem cria o pedido não aprova nem recebe ([[Estoque-Regras-Negocio]]).
- **Um schema Postgres por domínio de negócio.** O Estoque terá o seu, dentro do banco do MES.

## 6. Como ler o vault sem se enganar

- **"Proposta" não é decisão.** Notas marcadas como proposta ou com "(confirmar)" ainda dependem de alguém. As decisões estão em [[Decisoes-Chave-ERP]] (as marcadas `[x]`) e nas DEC do cronograma.
- **Cada contrato tem status** (`proposta`, `aplicada`, `rejeitada`) no [[Indice-Contratos]]. Hoje nenhum foi aplicado.
- **Algumas respostas ainda aparecem como perguntas.** A seção F de [[Perguntas-em-Aberto-Consolidadas]] lista as que já foram respondidas mas seguem abertas em alguma nota.
- **O que não foi confirmado com o código real** está dito na própria nota. O vault vem de leitura dos repositórios e de conversas com o Nathan; não substitui olhar o código antes de mudar algo.
- **Em caso de conflito:** o [[Cronograma-2-Meses]] vale para datas e escopo; [[Decisoes-Chave-ERP]] para decisões; o contrato vale para mudança de banco ou API; a nota mais recente vale sobre a mais antiga.

## 7. Onde está o quê

| Pasta | Conteúdo |
|---|---|
| `01-Fluxo-Operacional` | O processo do pedido, macro e por item |
| `02-PRD-Estoque` | O módulo de Estoque, Recebimento e Compras: regras, dados, riscos e os fluxos por conversa |
| `03-Sistemas-Existentes` | av-hub, app-pcp (MES) e o pipeline do Omie, como estão hoje |
| `04-Arquitetura-Transversal` | Decisões, UML, schemas, rastreabilidade e perguntas |
| `05-Pessoas-e-Equipe`, `06-Glossario` | Quem é quem e os termos do projeto |
| `07-Cronograma` | O plano de 2 meses |
| `08-Integracao-Omie` | O que o pipeline extrai, lacunas e roteiro de implementação |
| `09-Contratos` | Mudanças formais de banco e API, para o DBA e os devs |

## Ver também
- [[Home]]
- [[Glossario]]
- [[Equipe-Projeto]]
