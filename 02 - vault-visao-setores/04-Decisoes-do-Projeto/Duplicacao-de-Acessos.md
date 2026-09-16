---
tags: [visao-setores, decisoes-projeto]
criado: 2026-09-16
---

# Duplicação de Acessos

## O que foi encontrado

Hoje existem **dois cadastros completamente separados e paralelos de usuários e permissões** na empresa:

1. O cadastro de acesso do **av-hub** — controla quem pode ver o quê, com login pelo e-mail corporativo (a maioria dos casos) ou por usuário e senha.
2. O cadastro de acesso do **sistema de produção** (hoje usado para Flanges) — com seus próprios usuários, perfis e permissões, login só por usuário e senha.

Os dois cadastros têm a mesma estrutura por trás (as mesmas categorias de perfil, tela e permissão), porque os dois sistemas nasceram do mesmo ponto de partida técnico e foram evoluindo em paralelo, cada um por conta própria, desde então.

## Por que isso não é necessariamente um erro

O público de cada sistema é diferente: o av-hub atende principalmente o público corporativo, que tem e-mail da empresa. O sistema de produção atende o chão de fábrica, onde boa parte das pessoas não tem e-mail corporativo. Essa diferença de forma de login tem uma razão de negócio real e não vai deixar de existir.

## Por que isso importa mesmo assim

O problema não é a forma de login — é que a empresa mantém **dois cadastros de usuários, dois cadastros de perfis e duas listas de permissões**, que precisam ser atualizados manualmente em sincronia sempre que alguém entra, sai ou muda de função. Isso é trabalho duplicado e risco de erro (por exemplo, um funcionário que deveria perder acesso em um dos sistemas e continua com acesso no outro).

## O que já foi decidido

Para o novo sistema de Estoque, que vai morar junto do sistema de produção, a decisão já foi tomada: ele **não** vai criar um terceiro cadastro de acesso — vai reaproveitar o cadastro que já existe no sistema de produção. Ou seja, a contagem continua em **dois cadastros independentes** (av-hub de um lado, sistema de fábrica + Estoque juntos do outro), e não passou a três. Ver [[Sistema-de-Fabrica-MES]].

## O que ainda precisa ser decidido

Fica em aberto para a empresa decidir conscientemente: manter os dois cadastros de acesso separados para sempre (aceitando o trabalho manual de manter os dois em sincronia), ou investir em unificar num único controle de acesso corporativo que todos os sistemas passem a consultar. Essa é uma decisão de governança, não só de tecnologia — envolve quem no negócio é responsável por conceder e revogar acessos em cada sistema.

## Ver também
- [[Home]]
- [[Acessos-e-Permissoes]]
- [[Sistema-de-Producao-Flanges]]
- [[Sistema-de-Fabrica-MES]]
- [[Principais-Decisoes]]
