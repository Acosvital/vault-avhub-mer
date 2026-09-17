---
tags: [integracao-omie, lacunas]
criado: 2026-09-17
---

# Campos que o Estoque/MES precisa e o Omie não fornece

Cruzamento entre o que os documentos de PRD/arquitetura do vault 01 pedem e o que o `omie-elt-pipeline` de fato extrai hoje (código lido diretamente, não só a nota-resumo).

## 1. Saldo de estoque — lacuna confirmada, sem solução no pipeline

O endpoint `ListarPosEstoque` (`/estoque/consulta/`) existe no código (`estoque.ts`) mas está com `enabled: false`, porque **não existe tabela de destino** no schema atual do DBA (só existe cadastro de produto, não saldo). Nada sincroniza saldo do Omie automaticamente hoje.

**Implicação para o PRD do Estoque**: se a intenção é que o saldo inicial ou de referência venha do Omie, isso exige (a) o DBA criar a tabela de destino e (b) habilitar esse resource no pipeline — não é trabalho do módulo de Estoque, é pré-requisito de infraestrutura.

## 2. Tolerância de peso, estoque mínimo/máximo, ponto de pedido — confirmado que não existem

`core.produtos.especificacoes` (jsonb) traz `altura`, `largura`, `profundidade`, **`peso_bruto`**, **`peso_liq`**, `marca`, `modelo` — e só isso. Não há tolerância de peso, estoque mínimo, estoque máximo nem ponto de pedido em nenhum lugar do schema sincronizado do Omie.

Isso **resolve parcialmente** a pergunta em aberto do vault 01 ("campos extras do Estoque podem vir do Omie ou virar colunas novas"): peso bruto/líquido **já vêm** prontos; os quatro campos de controle de estoque **não vêm** e precisam ser criados como colunas próprias do módulo de Estoque, populadas por regra de negócio do Estoque, não por sincronização do Omie.

> Ressalva: isso reflete os campos que o pipeline **mapeia para colunas**. Não foi possível confirmar se o payload bruto da API `ListarProdutos` do Omie contém mais campos que simplesmente não foram mapeados ainda (o pipeline tem um schema de staging `omie_raw.produtos` para isso, mas vem **desabilitado por padrão** — `RAW_AUDIT_ENABLED=false`). Se a equipe quiser ter certeza absoluta antes de desenhar as colunas do Estoque, vale habilitar temporariamente esse staging raw e inspecionar o JSON completo de um produto.

## 3. Devolução parcial — só um boolean, sem valor

`pedidos_vendas.devolucao_parcial` é um boolean puro. Não existe, em nenhuma tabela sincronizada do Omie, o **valor** dessa devolução parcial. Isso já era um ponto conhecido no vault 01 (afeta o cálculo de faturamento líquido G2P) — confirmado aqui que o pipeline realmente não traz esse valor, não é uma lacuna de mapeamento, é uma lacuna do próprio dado disponível via API do Omie.

## 4. Ordem de Compra — API de criação não confirmada

Todos os endpoints usados pelo pipeline são de leitura (`Listar*`, `Pesquisar*`, `Consultar*`). Não há nenhum endpoint de escrita/criação usado em lugar nenhum do código — o que é consistente com a suspeita já registrada no vault 01, mas não prova nem desmente que o Omie tenha uma API de criação de Ordem de Compra. Seguir como pergunta em aberto (ver [[Perguntas-em-Aberto]]).

## 5. Histórico granular de status do pedido — não é responsabilidade do pipeline

`pedidos_vendas_status_historico` (schema Postgres) não aparece como destino de nenhuma extração do pipeline — o pipeline só grava em `pedidos_vendas` diretamente; `situacao` inclusive é recalculada por **trigger do banco**, não pelo pipeline. Ou seja: a "granularidade insuficiente" desse histórico não é uma limitação do que o Omie oferece — é uma decisão de schema do lado do banco/DBA. Se o Estoque/MES precisar de histórico mais fino, a solução está inteiramente do lado do Postgres (nova tabela/trigger), não depende de trazer mais dado do Omie.

## Ver também
- [[Produtos-e-Familias]]
- [[Pedidos-de-Venda]]
- [[Perguntas-em-Aberto]]
