---
tags: [visao-setores, sistemas-existentes]
criado: 2026-09-16
---

# Integração com o Omie

Grande parte dos dados que aparecem no av-hub (pedidos, notas fiscais, produtos, clientes, vendedores) não é digitada manualmente dentro do av-hub — ela vem automaticamente do Omie, através de uma rotina de atualização automática que roda em segundo plano.

## Como funciona a atualização automática

Diferente de uma atualização instantânea (que avisaria o sistema assim que algo muda no Omie), o que existe hoje é uma atualização automática que roda em ciclos, em diferentes frequências dependendo do tipo de dado:

- O que aconteceu **hoje** é revarrido a cada poucos minutos (cerca de 3 em 3 minutos).
- O mês corrente é revarrido a cada 20 minutos.
- Os últimos 90 dias são revarridos a cada 3 horas.
- Uma varredura completa (todo o catálogo e o último ano) roda uma vez por dia, de madrugada.

Isso significa que a informação no av-hub pode ficar, na pior das hipóteses, alguns minutos ou horas desatualizada em relação ao Omie — nunca é instantânea, mas também nunca demora mais do que isso para se atualizar sozinha.

Essa forma de atualização foi escolhida porque o Omie não oferece um jeito de avisar automaticamente quando algo muda — então o sistema precisa ficar perguntando periodicamente "o que mudou desde a última vez".

## O que é trazido automaticamente

Produtos, clientes e fornecedores, vendedores, pedidos de venda (com os itens de cada pedido), notas fiscais e famílias de produto. O saldo de estoque do Omie **não** é trazido automaticamente hoje — esse é um ponto relevante para o projeto do novo sistema de estoque, já que hoje nada sincroniza saldo do Omie de forma automática.

## A confirmação de recebimento da nota fiscal (manifestação)

Uma informação específica — se o cliente confirmou o recebimento de uma nota fiscal — não está disponível diretamente pelo Omie. Ela existe apenas dentro de um relatório visual do próprio site do Omie. Por isso, existe uma automação separada que entra periodicamente nesse relatório, extrai a informação e atualiza o sistema com ela. Como consequência, o número da nota fiscal associado a esse dado deve ser tratado com uma margem de cautela — é uma informação obtida de um relatório, não um vínculo garantido diretamente pelo sistema.

## Cuidados importantes já aprendidos

- Algumas informações são de "propriedade" de outro sistema e nunca são sobrescritas por essa atualização automática — por exemplo, se alguém ajusta manualmente um valor de desconto de uma nota fiscal dentro do av-hub, essa atualização automática nunca vai sobrescrever esse ajuste manual. Isso evita que a integração "apague" correções feitas manualmente.
- Já aconteceram alguns incidentes no passado (picos de volume de dados represados, travamentos de conexão), todos já identificados e corrigidos, com ajustes para evitar que se repitam.
- Todos os dias roda uma checagem automática que compara o que existe no Omie com o que existe no av-hub, para identificar pedidos que foram apagados do Omie mas continuam aparecendo no av-hub — hoje essa checagem só gera um relatório, não apaga nada sozinha.

## Ver também
- [[av-hub]]
- [[Como-Vendas-e-Faturamento-Funcionam]]
- [[Situacao-Atual]]
