---
tags: [erp-acos-vital, arquitetura, decisoes, pendencias, mes]
criado: 2026-09-16
---

# Perguntas Pendentes — MES / Estoque / av-hub

Documento de referência rápida com as perguntas em aberto da conversa de desenho de arquitetura (16/09/2026), pra levar pra reunião com o time (Gustavo/Robert) sem precisar garimpar no histórico de conversa. Contexto completo de cada decisão já tomada está em [[MES-Arquitetura-Decisoes]].

## 1. Material/Produto — mesma pergunta do fornecedor, agora pro catálogo

Ficou decidido que **fornecedor** não tem cadastro próprio no Estoque — reaproveita `core.parceiros` (av-hub) via projeção. A mesma pergunta vale para o catálogo: o PRD original do Estoque propõe `material`/`material_alias_omie` como cadastro próprio, com saneamento do catálogo Omie. O av-hub já tem `core.produtos`, também sincronizado do Omie.

**Pergunta:** `material` deveria ser uma projeção de `core.produtos` (com campos extras só do lado de estoque — peso teórico, tolerância, mínimo/máximo — guardados à parte), ou é um cadastro genuinamente separado, já que nem todo material vira produto vendável e nem todo produto vendável é estocado?

## 2. Achado — existe uma `quality-api` referenciada no código do av-hub

Não é uma dúvida de design, é uma descoberta: ao ler o backend `api-acos-vital` em detalhe, há um comentário no código dizendo que a rota `/quality` **já foi movida para um serviço separado, `quality-api`** (padrão parecido com uma referência a um módulo de "blog" que também foi mencionado como movido para fora, esse aparentando estar abandonado/sem uso).

**Pergunta:** essa `quality-api` está ativa hoje? Ela é relevante para o fluxo de Qualidade que o PRD do Estoque descreve (RNC, inspeção, aprovação de lote), ou é uma iniciativa não relacionada?

## 3. Devolução de cliente — decisão (av-hub) ou execução (Estoque)?

O av-hub já classifica devolução comercialmente (grupos G2 "Devolvido"/G2P "Devolvido Parcial" na cascata de dedução de venda líquida). A entidade `devolucao_cliente` do PRD do Estoque cuida do lado físico (reentrada no estoque, conferência).

**Pergunta:** a devolução também deveria nascer como decisão no av-hub (ligada à classificação G2/G2P já existente), com o Estoque só executando o reingresso físico — mesma fronteira decisão/execução já definida para a Ordem de Compra?

## 4. Depósito está ligado a Fábrica, ou é compartilhado?

O PRD confirma "múltiplos depósitos", mas não ficou claro se cada Fábrica (no MES) tem depósito próprio ou se existe um depósito central servindo várias fábricas.

**Pergunta:** qual é a relação real Depósito↔Fábrica? Isso trava o desenho do escopo por instância (comprador/almoxarife por depósito) já combinado para o RBAC do Estoque.

## 5. Namespacing do schema do Estoque dentro do banco do MES (técnica, menor prioridade)

O MES (Prisma) organiza os models em arquivos separados (`fabricas.prisma`, `producao.prisma`, `auth.prisma`, `auditoria.prisma`), mas isso não necessariamente significa schemas Postgres reais separados — pode estar tudo mapeado pro schema `public` por padrão do Prisma.

**Pergunta:** o Estoque, ao entrar no banco do MES, ganha um schema Postgres de verdade (`estoque`), seguindo a convenção já usada no lado do av-hub (um schema por domínio), ou o MES não segue essa convenção hoje e tudo fica junto?

## Já resolvidas nesta rodada (referência)

- Fornecedor = `core.parceiros` (av-hub), via projeção.
- MES cobre Estoque + toda a fabricação (Flanges, Chapas, Grades de Piso).
- RBAC do Estoque segue o padrão já existente no MES (não nasce compartilhado com av-hub).
- Estoque usa Prisma.
- Ordem de Compra é decidida no av-hub, referenciada no MES quando o material chega.

## Ainda em aberto de rodadas anteriores (não repetidas aqui em detalhe)

- Vínculo Fábrica ↔ Unidade/Filial (`codigo_empresa`).
- Conceito de "Orçamento" (ainda não pensado).
- Nome definitivo do sistema de fábrica (hoje "MES Aços Vital" é nome de trabalho).
- Se o Omie tem API de criação de Ordem de Compra (necessário só quando a criação nativa no av-hub virar prioridade).

## Ver também
- [[MES-Arquitetura-Decisoes]]
- [[Decisoes-Chave-ERP]]
- [[Estoque-Perguntas-Abertas]]
