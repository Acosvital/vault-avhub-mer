---
tags: [visao-setores, sistemas-existentes]
criado: 2026-09-16
---

# Acessos e Permissões

## Como funciona hoje no av-hub

Cada pessoa que usa o av-hub tem um **perfil de acesso** (por exemplo: vendedor, gerente, diligenciador, administrador). Cada perfil tem acesso a um conjunto de telas, e para cada tela existe um controle fino do que a pessoa pode fazer: visualizar, criar, editar ou excluir.

Esse controle é resolvido inteiramente dentro do sistema — não depende de grupos configurados no login corporativo (Azure AD). O login corporativo só serve para confirmar quem é a pessoa; o que ela pode ver e fazer depois de entrar é definido pelo perfil cadastrado no av-hub.

Alguns detalhes já disponíveis:
- Cada perfil pode ter uma **tela inicial** própria — a pessoa já cai direto na tela mais relevante para o seu trabalho assim que faz login, em vez de ter que navegar até lá.
- Existe uma tela de edição em massa de permissões, para ajustar várias permissões de um perfil de uma vez.
- O cadastro de usuário guarda se a pessoa está ativa ou não, e a data de desligamento quando aplicável. Hoje o sistema não tem um recurso dedicado de anonimização de dados pessoais (LGPD) — os dados do usuário desligado continuam registrados, só marcados como inativos.

## Como as pessoas entram no sistema (login)

O av-hub aceita duas formas de entrada:

- **Login corporativo** (mesmo e-mail e senha do restante da empresa) — é a forma principal, com entrada automática quando possível.
- **Usuário e senha próprios do av-hub** — usado como alternativa, com um limite de tentativas para evitar tentativas indevidas de acesso.

## E no sistema de produção (fábrica de flanges)?

O [[Sistema-de-Producao-Flanges]] tem seu próprio cadastro de perfis, telas e permissões, totalmente separado do av-hub — mesmo modelo de ideia (perfil → tela → permissão), mas outro sistema, com outro banco de dados e outros usuários cadastrados. Isso existe porque quem trabalha na fábrica geralmente não tem e-mail corporativo, então o login lá é feito só por usuário e senha, sem a opção de login corporativo.

Hoje o controle fino de permissão do sistema de produção ainda **não está totalmente ativo** — qualquer pessoa logada consegue acessar as funções, sem uma segunda camada de restrição por tela ainda ligada. A equipe está esperando desenhar um modelo de permissão que leve em conta o setor de cada pessoa (por exemplo, um líder de setor só deveria ver o que acontece no seu próprio setor) antes de ativar esse controle de forma completa. Existe hoje uma restrição mais simples, usada só numa tela específica (Movimentações), que já leva em conta o setor da pessoa — mas essa restrição é tratada como uma conveniência de navegação, não como uma proteção de segurança definitiva.

O novo sistema de estoque que está sendo desenhado vai reaproveitar o controle de acesso que já existe no sistema de produção, em vez de criar um terceiro modelo de permissões do zero. Ver `Duplicacao-de-Acessos` na pasta `04-Decisoes-do-Projeto` para mais detalhes sobre por que existem hoje dois modelos de acesso separados (um no av-hub, outro no sistema de produção) em vez de um só.

## Ver também
- [[av-hub]]
- [[Sistema-de-Producao-Flanges]]
- [[Glossario]]
