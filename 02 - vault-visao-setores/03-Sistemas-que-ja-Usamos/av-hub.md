---
tags: [visao-setores, sistemas-existentes]
criado: 2026-09-16
---

# av-hub

O **av-hub** é o sistema comercial e administrativo da Aços Vital — a "central" onde vendas, gestão e diretoria acompanham pedidos, notas fiscais, comissão e faturamento no dia a dia. Ele já está em uso e continua recebendo melhorias.

## Pra que ele serve

O av-hub reúne, num só lugar, as informações que hoje ficam espalhadas entre o Omie e planilhas manuais:

- Pedidos de venda e notas fiscais, com uma visão organizada de "quanto vendemos de fato" (ver [[Como-Vendas-e-Faturamento-Funcionam]]).
- Um espaço próprio pra cada vendedor acompanhar seus próprios pedidos, notas e comissão (ver [[Portal-do-Vendedor]]).
- Uma visão para gestores acompanharem o desempenho de toda a equipe.
- Cadastros gerais (vendedores, parceiros/clientes, produtos, metas, setores).
- Painéis (dashboards) de comissão, faturamento e vendas, com rankings de clientes e vendedores.

## O que ele cobre hoje — e o que ainda não cobre

O av-hub acompanha bem a parte comercial e financeira de um pedido: a entrada do pedido (vindo do Omie), sua situação, autorização, faturamento e eventual devolução. Ele **não** controla a fabricação em si (isso é papel do [[Sistema-de-Producao-Flanges]]) nem o controle de estoque e compras (que hoje é feito fora de sistema e está sendo desenhado como projeto novo — ver `02-Novo-Sistema-de-Estoque` no índice).

Hoje, ainda não existe uma forma automática de o vendedor ver, item por item de um pedido, em que etapa da fábrica aquele item está (por exemplo, "em compra", "em fabricação", "em inspeção", "pronto para expedição"). Essa integração entre o av-hub e o sistema de produção ainda está sendo desenhada. O que existe hoje é uma atualização automática de dados vinda do Omie a cada poucos minutos (ver [[Integracao-com-o-Omie]]), não uma atualização instantânea.

## Como as pessoas entram no sistema

O login é feito com o mesmo e-mail e senha corporativos usados no resto da empresa (login corporativo único), com uma opção de usuário e senha própria como alternativa. Cada pessoa só vê e faz o que seu perfil de acesso permite — ver [[Acessos-e-Permissoes]].

## Áreas principais do av-hub

- **Vendas** — pedidos e notas fiscais, com a régua de cálculo de venda líquida (ver [[Como-Vendas-e-Faturamento-Funcionam]]).
- **Portal do Vendedor** — autoatendimento, cada vendedor só vê os próprios dados (ver [[Portal-do-Vendedor]]).
- **Portal do Gerente/Equipe** — visão do gestor sobre todo o time.
- **Portal do PCP (diligenciadores)** — atenção: apesar do nome "PCP", esta parte do av-hub **não** acompanha produção — é acompanhamento comercial dos pedidos de um grupo de vendedores, feito por pessoas do setor de PCP chamadas de diligenciadores. Ver a explicação completa dessa ambiguidade de nome em `Ambiguidade-do-Nome-PCP` (pasta `04-Decisoes-do-Projeto`).
- **Dashboards** — painéis de comissão, faturamento e vendas, com rankings.
- **Orçamento** — controle de fornecedores, categorias de compra e histórico de preços de produtos, ainda em formato simples (não é ainda um módulo completo de compras).
- **Fechamento** — hoje é feito manualmente todo mês (os totais automáticos ainda não são totalmente confiáveis); a partir de setembro de 2026 o sistema passa a puxar os números automaticamente dos painéis, mas um lançamento manual sempre pode ser usado para corrigir um caso pontual.
- **Cadastros** — usuários, perfis de acesso, vendedores, diligenciadores, parceiros/clientes, produtos, metas mensais, setores e unidades da empresa.
- **Experimental** — área de testes, hoje com o protótipo do [[Comissoes|simulador de comissão]].

## Ver também
- [[Como-Vendas-e-Faturamento-Funcionam]]
- [[Comissoes]]
- [[Portal-do-Vendedor]]
- [[Acessos-e-Permissoes]]
- [[Situacao-Atual]]
- [[Glossario]]
