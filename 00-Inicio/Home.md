---
tags: [home, moc]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [plano de 14/10/2026]
---

# Home: manual do fluxo de Atividades (0b)

**Em uma frase:** este vault é o manual para construir o fluxo de **Atividades** do ERP (sistema de gestão) da Aços Vital: o caminho de um pedido de venda de 0 a 100%.

**Quando consultar esta nota:** quando você quiser achar qualquer assunto do projeto. Ela é o índice de todas as pastas.

O pedido começa na proposta (ou no pedido digitado no Omie) e termina na nota fiscal e na comissão. Este vault substitui o `vault-avhub-mer` (v1, congelado).

- Chegou agora? Comece por [[Comece-Aqui]].
- Quer saber o que falta fazer? Veja [[Onde-Estamos]].

## Mapa das pastas

| Pasta | O que tem |
|---|---|
| `00-Inicio` | Porta de entrada: [[Comece-Aqui]] · [[Onde-Estamos]] · [[Regras-do-Vault]] · [[Mapa-v1-para-v2]] |
| `01-Projeto` | O projeto em si: [[Visao-do-Projeto]] · [[Sistemas-e-Responsabilidades]] · [[Equipe-e-Divisao]] · [[Cronograma]] · [[Infraestrutura]] · [[Glossario]] |
| `02-Fluxo-de-Atividades` | **O coração do manual.** [[00-Fluxo-Mestre-0b]] e uma nota por setor (lista abaixo), mais [[14-Telas-e-Experiencia-do-Usuario]], [[Estados-e-Status]] e [[Telas-por-Raia]] |
| `03-Sistemas` | Como cada sistema é feito: [[AV-Hub-Front]] · [[AV-Hub-API]] · [[API-Comercial]] · [[Mapa-do-Modulo-do-Pablo]] · [[MES-Backend]] · [[MES-Front]] · [[Pipeline-Omie]] · [[RBAC-e-Permissoes]] · [[Bugs-Conhecidos]] · [[Proposta-Score-e-Volatilidade-OQ-46]] |
| `03-Sistemas/Comissao` | A comissão atual e a nova: [[01-Motor-Atual-Como-Calcula]] · [[02-Tabelas-Atuais-core_comissionamento]] · [[03-Modelo-Novo-core_comissao]] · [[04-Regras-e-Estados-da-Comissao-Nova]] |
| `04-Dados` | Os bancos de dados: [[Banco-AvHub]] · [[Banco-MES]] · [[Modelo-Estoque-e-Custo-do-Lote]] · [[Schemas-Postgres]] · [[Diferencas-Codigo-x-Banco]] |
| `05-Integracoes` | Como os sistemas conversam: [[Integracao-AvHub-MES]] · [[Chaves-e-Autenticacao]] · [[Omie-Integracao-Estado]] · [[Estudo-Omie-API]] · [[Mapa-IncluirPedido-Omie]] · [[Colunas-Protegidas]] · [[Rastreabilidade-e-Torre-de-Fluxo]] · dicionários do Omie em `05-Integracoes/Omie-Dicionarios` |
| `06-Contratos` | [[Painel-de-Contratos]] (todos os contratos, texto integral) · Consultas: [[Modelo-de-Consulta]] |
| `07-Desenvolvimento` | O que falta fazer: [[Backlog-por-Frente]] · [[Pontas-Soltas]] · [[Perguntas-Proposta-Pedido-Comissao]] · [[Contradicoes-Resolvidas]] · [[Riscos]] |
| `08-Decisoes` | [[Registro-de-Decisoes]] |
| `09-Diagramas` | [[Indice-de-Diagramas]] (inclui os artifacts do 0b e da proposta ao pedido) · [[Classes]] · [[Estados]] · [[Casos-de-Uso]] · [[Sequencia]] · [[Componentes-e-Implantacao]] · [[Modelo-de-Dados]] |
| `10-Anexo-Fora-do-Fluxo` | Assuntos fora do fluxo principal: [[Comissoes]] · [[RH-Vagas-Funcionarios]] · [[Dashboards]] · [[Pedido-Manual]] · [[Acompanhamento-Clientes]] · [[Comercial-Suprimentos]] · [[Mapa-Rotas-BFF-Bearer]] · [[Transferencia-entre-Filiais]] |

## Os setores do fluxo, na ordem do pedido

[[11-Proposta-e-Pedido-de-Venda]] (com [[12-Orcamento-Base-de-Preco]]) → [[01-Vendas-Liberacao]] → [[02-PCP-Triagem-e-Destinacao]] → [[03-Estoque-Atendimento-e-Despacho]] → [[04-Circuito-de-Compra]] → [[05-Recebimento]] → [[06-Qualidade-Entrada]] → [[07-Producao-e-Roteiro]] → [[08-Qualidade-Saida]] → [[09-Expedicao]] → [[10-Fiscal-Omie]] → [[13-Custo-Real-e-Comissao-no-Fluxo]]

As notas 11 a 14 vieram depois das 01 a 10. Por isso o número não segue a ordem do fluxo.

## Anexo

O índice do anexo é a linha `10-Anexo-Fora-do-Fluxo` da tabela acima. O antigo anexo [[Orcamento]] foi arquivado em 26/10/2026, porque o Orçamento agora faz parte do fluxo.
