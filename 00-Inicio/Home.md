---
tags: [home, moc]
criado: 2026-10-14
atualizado: 2026-10-26
status: vigente
dono: Nathan
fontes: [plano de 14/10/2026]
---

# Home: manual do fluxo de Atividades (0b)

Este vault é o manual para desenvolver o fluxo de **Atividades** do ERP Aços Vital: um pedido de venda de 0 a 100%, da proposta (ou do pedido digitado no Omie) à nota fiscal e à comissão. Ele substitui o `vault-avhub-mer` (v1, congelado). Novo por aqui? Comece por [[Comece-Aqui]]. Quer saber o que falta fazer? Veja [[Onde-Estamos]].

## Mapa

| Pasta | O que tem |
|---|---|
| `00-Inicio` | [[Comece-Aqui]] · [[Onde-Estamos]] · [[Regras-do-Vault]] · [[Mapa-v1-para-v2]] |
| `01-Projeto` | [[Visao-do-Projeto]] · [[Sistemas-e-Responsabilidades]] · [[Equipe-e-Divisao]] · [[Cronograma]] · [[Infraestrutura]] · [[Glossario]] |
| `02-Fluxo-de-Atividades` | **Espinha do manual.** [[00-Fluxo-Mestre-0b]] e uma nota por raia (lista abaixo), mais [[14-Telas-e-Experiencia-do-Usuario]], [[Estados-e-Status]] e [[Telas-por-Raia]] |
| `03-Sistemas` | [[AV-Hub-Front]] · [[AV-Hub-API]] · [[API-Comercial]] · [[Mapa-do-Modulo-do-Pablo]] · [[MES-Backend]] · [[MES-Front]] · [[Pipeline-Omie]] · [[RBAC-e-Permissoes]] · [[Bugs-Conhecidos]] · [[Proposta-Score-e-Volatilidade-OQ-46]] |
| `03-Sistemas/Comissao` | Comissão atual e nova: [[01-Motor-Atual-Como-Calcula]] · [[02-Tabelas-Atuais-core_comissionamento]] · [[03-Modelo-Novo-core_comissao]] · [[04-Regras-e-Estados-da-Comissao-Nova]] |
| `04-Dados` | [[Banco-AvHub]] · [[Banco-MES]] · [[Modelo-Estoque-e-Custo-do-Lote]] · [[Schemas-Postgres]] · [[Diferencas-Codigo-x-Banco]] |
| `05-Integracoes` | [[Integracao-AvHub-MES]] · [[Chaves-e-Autenticacao]] · [[Omie-Integracao-Estado]] · [[Estudo-Omie-API]] · [[Mapa-IncluirPedido-Omie]] · [[Colunas-Protegidas]] · [[Rastreabilidade-e-Torre-de-Fluxo]] · dicionários do Omie em `05-Integracoes/Omie-Dicionarios` |
| `06-Contratos` | [[Painel-de-Contratos]] (todos os contratos, texto integral) · Consultas: [[Modelo-de-Consulta]] |
| `07-Desenvolvimento` | [[Backlog-por-Frente]] · [[Pontas-Soltas]] · [[Perguntas-Proposta-Pedido-Comissao]] · [[Contradicoes-Resolvidas]] · [[Riscos]] |
| `08-Decisoes` | [[Registro-de-Decisoes]] |
| `09-Diagramas` | [[Indice-de-Diagramas]] (inclui os artifacts do 0b e da proposta ao pedido) · [[Classes]] · [[Estados]] · [[Casos-de-Uso]] · [[Sequencia]] · [[Componentes-e-Implantacao]] · [[Modelo-de-Dados]] |
| `10-Anexo-Fora-do-Fluxo` | Fora da espinha: [[Comissoes]] · [[RH-Vagas-Funcionarios]] · [[Dashboards]] · [[Pedido-Manual]] · [[Acompanhamento-Clientes]] · [[Comercial-Suprimentos]] · [[Mapa-Rotas-BFF-Bearer]] · [[Transferencia-entre-Filiais]] |

## As raias do 0b

[[11-Proposta-e-Pedido-de-Venda]] (com [[12-Orcamento-Base-de-Preco]]) → [[01-Vendas-Liberacao]] → [[02-PCP-Triagem-e-Destinacao]] → [[03-Estoque-Atendimento-e-Despacho]] → [[04-Circuito-de-Compra]] → [[05-Recebimento]] → [[06-Qualidade-Entrada]] → [[07-Producao-e-Roteiro]] → [[08-Qualidade-Saida]] → [[09-Expedicao]] → [[10-Fiscal-Omie]] → [[13-Custo-Real-e-Comissao-no-Fluxo]]

As notas 11 a 14 foram criadas depois das 01 a 10, por isso a numeração não segue a ordem do fluxo.

## Anexo

O índice do anexo é a linha `10-Anexo-Fora-do-Fluxo` da tabela acima. O antigo anexo [[Orcamento]] foi arquivado em 26/10/2026: o Orçamento agora está no fluxo.
