---
tags: [erp-acos-vital, onboarding, indice]
criado: 2026-09-21
atualizado: 2026-10-07
---

# Comece aqui

> Para quem entra no projeto (ou volta depois de um tempo). Em 30 minutos você sabe **o que existe, o que falta construir, o que ler primeiro e o que fazer na primeira semana**. O mapa completo está em [[Home]].
>
> **Atualização de 07/10/2026:** esta nota foi escrita em 21/09, antes da execução. A seção 1 abaixo foi reescrita; as seções 3 e 4 (tarefas da "primeira semana" e decisões que destravam) são **o plano de 21/09, hoje histórico**: o estado real de cada tarefa está em [[Onde-Estamos]] e as decisões de 07/10 em [[Registro-de-Decisoes-2026-10-07]].

> Status: decidido | no código | em produção (verificado em 07/10 pelo dump)

## 1. O que existe hoje e o que é para construir

- **Existe e roda:** a Entrada Comercial. O pedido é criado no Omie, o pipeline ([[Omie-ELT-Pipeline]]) o leva ao av-hub, e o Portal do Vendedor o mostra. Existe também o motor de execução de roteiro de Flanges (`api-pcp`), mas só depois que uma Ordem de Produção chega até ele.
- **Já tem código (desde 22/09), mas só na `develop` e sem conferência de produção** (conferido em 07/10): no av-hub, Compras (requisição, OC, follow-up, envio ao Omie pela pipeline) e o módulo Comercial & Suprimentos ([[AV-Hub-Comercial-Suprimentos]]); no MES, requisição de compra, Estoque, Qualidade de entrada e Recebimento com conferência ([[App-PCP-Recebimento-Conferencia]]). Cuidado: a `main` do MES parou em 28/08.
- **Ainda 100% manual ou sem código:** triagem completa do PCP com roteiro item a item (C8), Expedição e faturamento operacional, transferência entre filiais (só a etapa 1 existe), rastreabilidade de eventos (`fluxo.*`), carga inicial em lote. **Continua valendo: o sistema a construir deve cobrir todos os passos dos 6 fluxogramas de [[Fluxogramas-Completos]].**
- **A execução começou em 22/09/2026.**
- **Para saber o ponto exato em que o projeto está** (marcos, quadro de tarefas, bloqueios), abra [[Onde-Estamos]], que é atualizada durante a execução.

## 2. Leitura comum (todos, nesta ordem)

1. [[Setores-Envolvidos-no-Fluxo]] — quem participa do pedido e onde cada setor vai viver (av-hub, MES ou Omie).
2. [[Fluxo-Detalhado-Pedido-Item]] — o fluxo item a item, que é a espinha do sistema.
3. [[Modelo-Destinacao-Item]] — como cada item é classificado (Revenda ou Fabricação × pronto, matéria-prima ou sem estoque) e [[Encaixe-Estoque-Revenda-no-PCP]] — como isso virou roteiro no MES (24/09/2026): a fábrica escolhida define a natureza e o setor Estoque, etapa 1 de todo roteiro, resolve a disponibilidade.
4. [[Fluxogramas-Completos]] — os 6 fluxos visuais.
5. [[Cronograma-2-Meses]] — o plano de 3 meses (18/09 a 18/12): marcos, quem faz o quê, o que entra e o que não entra.
6. [[Perguntas-em-Aberto-Consolidadas]] — o que ainda não está decidido e quem responde.

## 3. Por pessoa: o que ler e o que fazer na primeira semana (histórico, plano de 21/09)

> **(atualizado em 07/10)** Esta seção é o **plano de 21/09**, mantida como histórico. Para o estado real, veja [[Onde-Estamos]] e [[Registro-de-Decisoes-2026-10-07]]. Mudanças relevantes: o **Pablo** atua agora no Comercial & Suprimentos e o **MES inteiro fica com o Robert**; a C2 foi cortada; a D1 (schema do Estoque) está concluída em `public`; a C1 está concluída.

As tarefas vêm da seção S1 do [[Cronograma-2-Meses]] (os IDs são os de lá). Com o início em 22/09, as janelas de S1 estão deslocadas um dia.

| Pessoa | Primeiras tarefas | Leitura específica |
|---|---|---|
| **Nathan** (coordenação, av-hub) | A1 decisões DEC-1 a DEC-9 · A2 hardware e agenda do levantamento físico · F1 spec da integração av-hub ↔ MES | [[Decisoes-Chave-ERP]], [[MES-Arquitetura-Decisoes]], [[Rastreabilidade-e-SLA-de-Eventos]] |
| **Gustavo** (banco, API, pipeline) | B1 fechar as perguntas dos contratos · B2 homologação e backup do banco do MES (**homologação feita em 07/10**, `mes-test.acosvital.com.br`; **backup segue pendente**) · depois B3 (contratos SQL 001 e 005) e B4 (`alterado_desde`) | [[Indice-Contratos]], [[Schema-Postgres-Multi-Dominio]], [[Indice-Integracao-Omie]], [[Roteiro-de-Implementacao]] |
| **Robert** (MES, PCP) | C1 login duplo · C3 desenho do RBAC por setor · C2 vínculo Fábrica ↔ Filial · C4 Carteira do PCP | [[App-PCP-Backend-Producao]], [[App-PCP-Modelo-Producao]], [[Fluxo-Producao-OS-OP-Completo]], [[Achado-Duplicacao-RBAC]] |
| **Pablo** (MES, Estoque) | D1 schema Prisma do Estoque · D2 módulo base · D3 projeção de material e parceiro | [[PRD-Estoque-Visao-Geral]], [[Estoque-Modelo-Dados]], [[Estoque-Regras-Negocio]], [[Estoque-Riscos]], [[Fluxo-Recebimento-Completo]], [[Fluxo-Qualidade-Completo]] |

**Antes de escrever a primeira migration (Pablo e Gustavo):** leia a seção 4.1 de [[Campos-e-API-para-Rastreabilidade]]. Há campos de autoria e tempo que precisam entrar já no schema v1.

## 4. As decisões que destravam a primeira semana (histórico, plano de 21/09)

> **(atualizado em 07/10)** Plano de 21/09, mantido como histórico: DEC-1 a DEC-12 já foram decididas ([[Decisoes-Chave-ERP]]) e as decisões de 07/10 estão em [[Registro-de-Decisoes-2026-10-07]]. Estado das tarefas: [[Onde-Estamos]].

DEC-4 (lote de carga inicial) e DEC-7 (contratos SQL) travam a D1. DEC-1 destrava a C2. DEC-2 destrava a integração. Todas têm prazo e um default escrito na seção 7 do [[Cronograma-2-Meses]]; a lista completa por pessoa está em [[Perguntas-em-Aberto-Consolidadas]].

## 5. Princípios que valem para tudo

Já provados nos sistemas atuais; ver [[Decisoes-Chave-ERP]].

- **O sistema nunca emite nem edita nota fiscal.** Isso é sempre do Omie. O sistema só sinaliza e referencia.
- **av-hub decide, MES executa.** Orçamento, pedido de venda e ordem de compra nascem no av-hub; produção, recebimento e saldo, no MES.
- **Só polling entre sistemas.** Não existe webhook nem tempo real; não assumir. (Atualização de 07/10: o MES também **empurra** a requisição de compra ao av-hub por `PUT` — contrato 34 — e lê os eventos da requisição por polling — contrato 35.)
- **Colunas protegidas.** Cada coluna tem um dono; o pipeline do Omie nunca escreve nas que pertencem a outro sistema.
- **Sem FK entre entidades sincronizadas de forma independente.**
- **Nenhum estado é beco sem saída.** Reprovou, divergiu ou devolveu: sempre há um caminho de volta ([[Estoque-Riscos]]).
- **Lote nasce em quarentena** e só libera com laudo e aprovação da Qualidade.
- **Segregação de função:** quem cria o pedido não aprova nem recebe ([[Estoque-Regras-Negocio]]).
- **Um schema Postgres por domínio de negócio.** O Estoque terá o seu, dentro do banco do MES. **(atualizado em 07/10)** Exceção decidida: o Estoque do MES fica no schema `public`, sem schema próprio ([[Registro-de-Decisoes-2026-10-07]], item 21).

## 6. Como ler o vault sem se enganar

- **"Proposta" não é decisão.** Notas marcadas como proposta ou com "(confirmar)" ainda dependem de alguém. As decisões estão em [[Decisoes-Chave-ERP]] (as marcadas `[x]`) e nas DEC do cronograma.
- **Cada contrato tem status** (`proposta`, `aplicada`, `rejeitada`, e desde 07/10 `implementada-no-codigo` quando só o código comprova) no [[Indice-Contratos]]. A maioria já foi entregue e está em `09-Contratos/Realizados/`; o índice diz o que ainda está aberto.
- **Algumas respostas ainda aparecem como perguntas.** A seção F de [[Perguntas-em-Aberto-Consolidadas]] lista as que já foram respondidas mas seguem abertas em alguma nota.
- **O que não foi confirmado com o código real** está dito na própria nota. O vault vem de leitura dos repositórios e de conversas com o Nathan; não substitui olhar o código antes de mudar algo.
- **Em caso de conflito:** o [[Cronograma-2-Meses]] vale para datas e escopo; [[Decisoes-Chave-ERP]] para decisões; o contrato vale para mudança de banco ou API; a nota mais recente vale sobre a mais antiga.

## 7. Onde está o quê

| Pasta | Conteúdo |
|---|---|
| `01-Fluxo-Operacional` | O processo do pedido, macro e por item |
| `02-PRD-Estoque` | O módulo de Estoque, Recebimento e Compras: regras, dados, riscos e os fluxos por conversa |
| `03-Sistemas-Existentes` | av-hub (incl. [[AV-Hub-Comercial-Suprimentos]] e [[AV-Hub-API-Estado-Atual]]), app-pcp (MES, incl. [[App-PCP-Recebimento-Conferencia]]) e o pipeline do Omie, como estão hoje |
| `04-Arquitetura-Transversal` | Decisões, UML, schemas, rastreabilidade e perguntas |
| `05-Pessoas-e-Equipe`, `06-Glossario` | Quem é quem e os termos do projeto |
| `07-Cronograma` | O plano de 3 meses (até 18/12; o arquivo mantém o nome "2-Meses") |
| `08-Integracao-Omie` | O que o pipeline extrai, lacunas e roteiro de implementação |
| `09-Contratos` | Mudanças formais de banco e API, para o DBA e os devs |

## Ver também
- [[Home]]
- [[Glossario]]
- [[Equipe-Projeto]]
- [[Registro-de-Decisoes-2026-10-07]]
