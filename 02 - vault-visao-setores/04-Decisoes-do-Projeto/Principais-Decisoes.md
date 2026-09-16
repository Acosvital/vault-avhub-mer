---
tags: [visao-setores, decisoes-projeto]
criado: 2026-09-16
---

# Principais Decisões do Projeto

Lista viva com as decisões estratégicas já tomadas para o ERP unificado da Aços Vital, e o que ainda precisa ser decidido pelo negócio. Para o "como" cada sistema funciona hoje, veja [[av-hub]] e [[Sistema-de-Producao-Flanges]]; para o contexto completo do processo, veja [[Visao-Geral-do-Processo]].

## Já decidido

- **Cada sistema mantém seu próprio cadastro de usuários e permissões.** O av-hub e o sistema de fábrica (MES) continuam com controles de acesso separados — não vão ser unificados agora. Essa duplicação já existia e foi mantida conscientemente por velocidade de entrega. Ver [[Duplicacao-de-Acessos]] e [[Sistema-de-Fabrica-MES]].
- **O login do sistema de Estoque/Fábrica vai aceitar dois formatos:** usuário e senha (para quem trabalha no chão de fábrica, sem e-mail corporativo) e login pelo e-mail corporativo (para os perfis de escritório).
- **Vai existir um vínculo entre cada fábrica e a unidade/filial da empresa** (por exemplo, Mogi ou Uberaba) — isso vai permitir cruzar o dado comercial de uma unidade com o andamento da produção daquela mesma unidade. O desenho exato de como esse vínculo vai funcionar (uma fábrica presa a uma filial fixa, ou o vínculo variando por pedido) ainda não foi fechado.
- **Ordem de Serviço (OS) e Ordem de Produção (OP), emitidas pelo setor de PCP de produção**, não são conceitos novos a criar do zero — elas vão usar o mecanismo de acompanhamento de etapas que o sistema de produção de Flanges já tem hoje.
- **Divisão clara entre Compras feita no av-hub e Compras solicitada pelo chão de fábrica:** a necessidade de compra nasce na fábrica (quando falta material), mas a negociação em si — escolher fornecedor, definir preço, aprovar — é decidida no av-hub. Só o necessário para conferência do que chegou volta para o sistema de fábrica. Ver [[Sistema-de-Fabrica-MES]].

## Ainda em aberto

- **Se cada sistema vai continuar com seu próprio cadastro de acesso para sempre, ou se em algum momento a empresa vai unificar tudo em um único controle de acesso.** É a maior decisão pendente de governança do projeto. Ver [[Duplicacao-de-Acessos]].
- **O conceito de "Orçamento" dentro do ERP novo ainda não foi definido pelo time** — não é sobre verba/budget, é um conceito de negócio que ainda precisa ser desenhado.
- **Permitir que o av-hub crie diretamente Pedido de Venda e Ordem de Compra**, empurrando essa informação para o sistema fiscal (Omie), é uma visão de futuro confirmada — mas não está ativa hoje. Falta ainda confirmar se o sistema fiscal aceita receber Ordens de Compra criadas por fora dele.
- **O nome definitivo do sistema de fábrica** — hoje ele é chamado de "MES Aços Vital" apenas como nome de trabalho, até a empresa definir um nome próprio.
- **Se a base única de fornecedores e preços já cobre tudo que o futuro módulo de Orçamento vai precisar**, ou se ainda falta alguma informação — a base em si já foi definida (ver [[Sistema-de-Fabrica-MES]]), falta só confirmar a cobertura completa.
- **Reconciliar as iniciativas de comissão** que hoje existem em paralelo — não é prioridade imediata, mas fica registrado como pendência.
- **O quadro de produção do sistema de fábrica** só precisa de uma tela nova — as informações que alimentam esse quadro já existem prontas no sistema, falta só construir a visualização.
- **Divergências de pedido sem caminho de reabertura**: hoje, quando uma divergência é registrada, resolvida ou cancelada, não existe caminho de volta caso seja necessário reabrir. Precisa confirmar com o time de produção se isso é intencional.
- **Adotar como padrão a regra de "não mexer no que é de outro sistema"** — ou seja, quando um sistema recebe dado de outro por integração automática, ele nunca deveria sobrescrever aquele dado por conta própria. Essa prática já existe na integração com o sistema fiscal e deveria virar regra para qualquer integração nova.
- **Investigar dois recursos do Portal do Vendedor** (marcar vendedores favoritos e sinalizar clientes inativos) que podem já estar prontos por trás das telas, antes de tratá-los como desenvolvimento novo e caro.
- **O "casamento" entre av-hub e o sistema de fábrica** — a ideia de que o status de cada item de um pedido apareça no av-hub, alimentado automaticamente pelo andamento da produção. O mecanismo exato de como essa informação vai trafegar entre os dois sistemas ainda não foi desenhado, e não se pode assumir que essa atualização vai acontecer "na hora" — hoje a única forma de sincronização entre sistemas é por consultas periódicas, não por aviso automático instantâneo. É o maior item em aberto do projeto.
- **Anexo de Ordem de Compra como documento estruturado, não como PDF anexado manualmente** — hoje o comprador anexa um PDF à mão; a intenção de longo prazo é que os dados da Ordem de Compra entrem diretamente no sistema, sem depender de anexar e ler um PDF.

## Ver também
- [[Home]]
- [[Duplicacao-de-Acessos]]
- [[Ambiguidade-do-Nome-PCP]]
- [[Sistema-de-Fabrica-MES]]
- [[Onde-os-Sistemas-Rodam]]
- [[Perguntas-Pendentes]]
