---
tags: [visao-setores, decisoes-projeto]
criado: 2026-09-16
---

# Perguntas Pendentes

Lista de referência rápida com as perguntas que ainda precisam de uma decisão de negócio antes do sistema de Estoque e Fábrica (MES) avançar. Contexto completo de cada tema já decidido está em [[Sistema-de-Fabrica-MES]] e [[Principais-Decisoes]].

## Devolução de cliente

Hoje o av-hub já classifica comercialmente uma devolução (como devolução total ou parcial, para efeito de cálculo de faturamento). O que ainda falta é tratar **o ciclo completo da devolução física** — o material realmente voltando para o estoque e sendo conferido, não só a sinalização comercial.

Além disso, hoje o sistema só registra "houve devolução parcial" como uma marcação simples, sem guardar o valor exato dessa devolução — isso afeta diretamente o cálculo do faturamento líquido e precisa ser resolvido antes ou junto com o desenho da devolução no Estoque.

**Pergunta em aberto**: a devolução deve nascer como decisão comercial no av-hub (com o Estoque só executando a entrada física de volta), seguindo a mesma lógica já usada para Ordem de Compra? Ou o processo completo (incluindo capturar o valor da devolução parcial, que hoje não existe) deveria nascer diretamente no sistema de Estoque?

## Vínculo entre fábrica e unidade/filial

Já foi confirmado que esse vínculo vai existir, mas o desenho exato ainda não foi definido: uma fábrica fica presa a uma única filial (por exemplo, Mogi ou Uberaba), ou o vínculo pode variar pedido a pedido? Sem essa definição, não é possível cruzar o dado comercial de uma unidade com o andamento da produção daquela mesma unidade.

## Conceito de "Orçamento"

Ainda não foi pensado pelo time de negócio — não é sobre verba ou budget, é um conceito que precisa ser definido antes de entrar em pauta no ERP novo.

## Nome definitivo do sistema de fábrica

Hoje "MES Aços Vital" é apenas um nome de trabalho, usado até a empresa definir um nome próprio e definitivo.

## Já resolvidas (referência)

- Fornecedor e material do Estoque não têm cadastro próprio — reaproveitam o cadastro já existente no av-hub.
- O sistema de fábrica cobre Estoque e toda a fabricação (lista aberta de linhas de produção; corte de chapa fica de fora, é tratado como serviço de Revenda).
- O controle de acesso do Estoque segue o padrão já existente no sistema de fábrica, sem criar um cadastro novo.
- Ordem de Compra é decidida no av-hub e só referenciada no sistema de fábrica quando o material chega para conferência.
- O depósito é central e compartilhado entre todas as fábricas e a Revenda (não existe um depósito fixo por fábrica).
- O login do sistema de Estoque/Fábrica aceita tanto usuário e senha quanto login pelo e-mail corporativo.
- O vínculo entre fábrica e unidade/filial será criado (mas o desenho exato ainda está em aberto, ver acima).
- OS/OP usam o mecanismo de acompanhamento de etapas que já existe no sistema de produção de Flanges.

## Ver também
- [[Home]]
- [[Sistema-de-Fabrica-MES]]
- [[Principais-Decisoes]]
- [[Controlando-o-Estoque]]
- [[Perguntas-em-Aberto]]
