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
| `02-Fluxo-de-Atividades` | **Espinha do manual.** [[00-Fluxo-Mestre-0b]] e uma nota por raia, mais [[Estados-e-Status]] e [[Telas-por-Raia]] |
| `03-Sistemas` | [[AV-Hub-Front]] · [[AV-Hub-API]] · [[API-Comercial]] · [[MES-Backend]] · [[MES-Front]] · [[Pipeline-Omie]] · [[RBAC-e-Permissoes]] · [[Bugs-Conhecidos]] |
| `04-Dados` | [[Banco-AvHub]] · [[Banco-MES]] · [[Modelo-Estoque-e-Custo-do-Lote]] · [[Schemas-Postgres]] · [[Diferencas-Codigo-x-Banco]] |
| `05-Integracoes` | [[Integracao-AvHub-MES]] · [[Chaves-e-Autenticacao]] · [[Omie-Integracao-Estado]] · [[Colunas-Protegidas]] · [[Rastreabilidade-e-Torre-de-Fluxo]] |
| `06-Contratos` | [[Painel-de-Contratos]] (todos os contratos, texto integral) · Consultas: [[Modelo-de-Consulta]] |
| `07-Desenvolvimento` | [[Backlog-por-Frente]] · [[Pontas-Soltas]] · [[Contradicoes-Resolvidas]] · [[Riscos]] |
| `08-Decisoes` | [[Registro-de-Decisoes]] |
| `09-Diagramas` | [[Indice-de-Diagramas]] · [[Classes]] · [[Estados]] · [[Casos-de-Uso]] · [[Sequencia]] · [[Componentes-e-Implantacao]] · [[Modelo-de-Dados]] |
| `10-Anexo-Fora-do-Fluxo` | Fora da espinha: [[Comissoes]] · [[RH-Vagas-Funcionarios]] · [[Dashboards]] · [[Orcamento]] · [[Pedido-Manual]] · [[Acompanhamento-Clientes]] · [[Comercial-Suprimentos]] · [[Mapa-Rotas-BFF-Bearer]] · [[Transferencia-entre-Filiais]] |

## As raias do 0b

[[01-Vendas-Liberacao]] → [[02-PCP-Triagem-e-Destinacao]] → [[03-Estoque-Atendimento-e-Despacho]] → [[04-Circuito-de-Compra]] → [[05-Recebimento]] → [[06-Qualidade-Entrada]] → [[07-Producao-e-Roteiro]] → [[08-Qualidade-Saida]] → [[09-Expedicao]] → [[10-Fiscal-Omie]]

## Anexo

O índice do anexo é a linha `10-Anexo-Fora-do-Fluxo` da tabela acima.
