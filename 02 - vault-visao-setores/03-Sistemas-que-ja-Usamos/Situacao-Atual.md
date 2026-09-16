---
tags: [visao-setores, sistemas-existentes]
criado: 2026-09-16
---

# Situação Atual do av-hub

Resumo de alto nível do que já está funcionando de forma confiável no av-hub hoje e do que ainda tem alguma pendência conhecida — pensado para quem usa o sistema no dia a dia, não para detalhe técnico.

## O que já está funcionando bem (corrigido e confirmado)

- **Bloqueio de pedidos por empresa**: um problema que fazia o sistema tratar de forma errada pedidos com o mesmo número em empresas diferentes já foi corrigido.
- **Busca por nome de funcionário**: a busca antes ignorava o nome digitado; hoje funciona corretamente, e também passou a permitir busca por e-mail e CPF.
- **Filtros de busca de clientes/parceiros**: os filtros de busca por nome, CPF/CNPJ, razão social e cidade estavam com problema (alguns comparavam de forma errada, outros eram simplesmente ignorados); todos já foram corrigidos e funcionam corretamente hoje (o filtro de estado continua exigindo a sigla exata, por natureza do dado).
- **Ordenação da lista de vendedores**: ordenar a lista por coluna não tinha efeito antes; hoje funciona, com várias colunas disponíveis para ordenação.
- **Cor e foto da unidade**: esses campos, que não existiam antes no cadastro de unidades, já foram adicionados.
- **Identificador único de vendedor**: havia um problema em que o mesmo identificador de vendedor podia colidir entre empresas diferentes (duas pessoas em unidades diferentes ficavam com o mesmo código); isso já foi corrigido com um identificador realmente único.
- **Meta individual inflada**: um problema fazia a meta individual aparecer de 7 a 18 vezes maior do que deveria (por uma divisão duplicada); já foi corrigido.

## Pendências conhecidas

- **Paginação de uma das planilhas de vendas**: hoje é possível ordenar essa planilha, mas a forma como ela é dividida em páginas ainda não agrupa corretamente por pedido (pode mostrar partes de um mesmo pedido em páginas diferentes). Ainda não implementado.
- **Cadastro de fornecedor por produto**: hoje, no módulo de Orçamento, essa relação ainda funciona de forma simplificada (um produto tem só um fornecedor, o da compra mais recente). Já existem, no entanto, indícios de que a estrutura para suportar múltiplos fornecedores por produto já existe por trás — a limitação pode ser só de tela, não de informação disponível. Vale investigar antes de assumir que "não existe" essa funcionalidade.
- **Histórico de status do pedido**: existe um histórico vindo do Omie, mas ele é grosso demais (só reflete o status geral que o Omie manda, atualizado periodicamente) — não é um histórico detalhado de cada etapa do processo interno (produção, ordem de serviço/produção, qualidade). Um histórico mais completo desse tipo ainda precisa ser construído.

## Possíveis "vitórias rápidas" a confirmar

Duas funcionalidades do Portal do Vendedor que antes pareciam custosas de implementar (favoritar cliente/pedido, e mostrar clientes inativos) podem já ter o caminho pronto por trás — indícios apontam que a base para isso já existe, faltando só conectar na tela. Vale investigar antes de descartar ou re-priorizar essas ideias.

## Ver também
- [[av-hub]]
- [[Como-Vendas-e-Faturamento-Funcionam]]
- [[Portal-do-Vendedor]]
- [[Integracao-com-o-Omie]]
