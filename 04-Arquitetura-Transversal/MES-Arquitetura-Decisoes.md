---
tags: [erp-acos-vital, arquitetura, decisoes, mes]
criado: 2026-09-16
---

# MES Aços Vital — Arquitetura e Decisões

Registro do desenho de arquitetura entre av-hub e o sistema de fábrica (nome de trabalho: **MES Aços Vital**, até um nome melhor ser definido). Complementa [[Decisoes-Chave-ERP]] e [[Achado-Ambiguidade-PCP]] — este arquivo é o detalhe, aqueles continuam sendo o resumo executivo.

## Visão geral

- **av-hub** = o ERP de altíssimo nível: origina Orçamento, Pedido de Venda e Ordem de Compra (Orçamento e a criação nativa de Pedido de Venda/Ordem de Compra ainda **não são ativos hoje** — são visão de futuro, não construir agora). Também é onde dado do MES é lido/apresentado.
- **MES Aços Vital** = gestão de **Estoque + toda a fabricação** (não só Flanges — "toda a fabricação entra no MES, só falta criar as fábricas e roteiros fabris" das outras linhas, o modelo já é genérico o suficiente). Fronteira clara: **av-hub decide (Compras/Vendas), MES executa (produção, recebimento, saldo)**.
- Dois bancos separados (já é a realidade hoje entre av-hub/`api-acos-vital` e app-pcp/`api-pcp`) — nenhuma mudança nisso.

## Decisões tomadas

1. **Fornecedor não tem cadastro próprio no Estoque.** Reaproveita `core.parceiros` (av-hub) com `tipo_parceiro`, que já é sincronizado do Omie pelo pipeline ELT existente. O Estoque recebe uma **projeção read-only** desse dado — evita um 3º cadastro de fornecedor. **Correção (17/09/2026)**: essa projeção não pode ser "o mesmo mecanismo de evento que o av-hub usa pra ler status de produção do MES", porque esse mecanismo **não existe** ainda — ver [[Decisoes-Chave-ERP]] ("casamento av-hub ↔ MES", não desenhado, maior item em aberto) e [[AV-Hub-Modulos]]. Hoje o único padrão de sincronização entre sistemas é polling (sem webhook); a forma mais simples de fazer essa projeção é o Estoque consumir por polling os endpoints REST que `api-acos-vital` já expõe (`GET /produtos`, `GET /parceiros`), sem depender de infraestrutura de evento que ainda não foi construída. Isso corrige o PRD original do Estoque, que propunha uma tabela `fornecedor` própria dentro do schema `estoque` — ver nota em [[Estoque-Modelo-Dados]].
2. **Toda a fabricação entra no MES desde já**, não só Flanges — lista **aberta** de linhas de produção (Grades de Piso, Chapa Expandida, Caldeiraria etc., conforme forem cadastradas), não uma lista fechada de três. Não precisa de sistema novo por linha de produção — o modelo de Fábrica/Setor/Roteiro já é genérico o suficiente; só falta cadastrar a fábrica/roteiro de cada linha nova quando chegar a hora. **Chapas não é uma linha de fabricação** — corte de chapa a plasma/laser é beneficiamento dentro da Revenda, não do MES-fabricação. Ver [[Fabricacao-Chapas]] e [[Fluxo-Detalhado-Pedido-Item]].
3. **RBAC do Estoque segue o padrão já existente no backend do MES** (o mesmo modelo de telas/perfis/permissões + `PerfilSetor` que o `api-pcp` já tem) — não nasce como biblioteca compartilhada com o av-hub agora. Duas implementações independentes, aceitas conscientemente por velocidade de entrega.
4. **Estoque usa Prisma**, morando dentro do mesmo banco do MES, seguindo a disciplina de migrations que o Prisma já traz em produção — reverte a recomendação original do PRD do Estoque de evitar Prisma (o motivo daquela recomendação, um problema real de build no Backlog Ágil, não se repetiu em ~1 mês de MES em produção). **Ganha schema Postgres próprio** dentro desse banco, seguindo a mesma convenção de schema-por-domínio do av-hub — não cai em `public`.
5. **Ordem de Compra é decidida no av-hub, referenciada no MES/Estoque** quando o material chega na doca — mesmo padrão que já existe entre av-hub (Pedido de Venda) e MES (execução da produção). O anexo manual de PDF da OC descrito nos áudios do gerente é só a primeira fase — a intenção é trazer os **dados estruturados da própria Ordem de Compra**, sem depender de upload/parse de PDF.

   **Divisão exata:** PCP (MES) gera a requisição a partir de saldo/reserva → comprador (av-hub) fecha a compra (fornecedor, preço, aprovação, flag acabado/não-acabado) → só o necessário pra conferência (itens, quantidade, flag) trafega de volta pro MES, não o dado comercial completo — mesma filosofia de "colunas protegidas" do pipeline ELT. Recebimento/conferência/OS/OP seguem 100% no MES. Ver [[Fluxo-Detalhado-Pedido-Item]] e o detalhamento completo em [[Fluxo-Compras-Completo]].
6. **Quando (no futuro) o av-hub passar a criar Pedido de Venda/Ordem de Compra nativamente, ele empurra para o Omie** (não o contrário) — Omie continua sendo o sistema fiscal/financeiro de registro. Implicações de design já levantadas para quando isso virar prioridade:
   - Escrita via outbox/fila (não síncrona) — grava local primeiro, sincroniza depois, evita travar o usuário numa instabilidade do Omie.
   - Risco de loop: o próximo ciclo do pipeline ELT vai "ler de volta" um pedido que o av-hub acabou de empurrar — precisa reconhecer pelo `codigo_pedido_omie` já preenchido.
   - Escrita nova disputa a mesma cota de rate limit do Omie que a leitura já usa — definir prioridade entre elas.
   - **Não confirmado ainda**: se o Omie tem endpoint de criação de Ordem de Compra via API (só vi endpoints de leitura no pipeline ELT analisado) — verificar antes de desenhar essa parte a sério.
7. **DEC-1 — Vínculo Fábrica ↔ Unidade/Filial: por pedido, não fixo.** Decidido em 21/09/2026 por Nathan + Robert. Motivo: existe hoje uma Fábrica real que atende matriz **e** filiais — o desenho "1 fábrica = 1 filial fixa" (que era o default do cronograma) não reflete a operação. `Fabrica` **não** ganha um campo `codigo_empresa` fixo; a filial de cada Ordem de Produção é sempre resolvida a partir do `codigo_empresa` do `Pedido` que a originou, nunca cacheada/assumida no nível da Fábrica.
   - **Implicação em RBAC (nova, para C2/C3)**: `PerfilSetor` hoje é só `(perfil, setor)` — não basta mais. Precisa ganhar uma dimensão de filial (`perfil × setor × filial`, ou equivalente) para expressar "esse líder só vê o setor X **da filial Y**", já que o mesmo setor pode atender pedidos de filiais diferentes na mesma Fábrica.
   - **Implicação em relatório**: qualquer agregação "produção por filial" tem que entrar pelo `Pedido`/`ItemParcial`, nunca assumir que a Fábrica sozinha identifica a filial.
   - **Implicação fiscal**: nenhuma regra fiscal pode ser cacheada por Fábrica — sempre resolver pelo `codigo_empresa` do pedido em curso.

## Dúvidas em aberto (perguntadas, ainda não respondidas)

- **Conceito de "Orçamento"**: ainda não foi pensado pelo time — não é budget/verba nem necessariamente a formalização do cálculo de markup/ICMS/margem já visto no protótipo de comissão. Fica em aberto para quando entrar em pauta.
- **Nome definitivo do MES**: "MES Aços Vital" é só nome de trabalho.

## Ver também
- [[Fluxo-Detalhado-Pedido-Item]]
- [[Perguntas-Pendentes-MES-Estoque]]
- [[Decisoes-Chave-ERP]]
- [[Achado-Ambiguidade-PCP]]
- [[App-PCP-Backend-Producao]]
- [[Estoque-Modelo-Dados]]
- [[Schema-Postgres-Multi-Dominio]]
- [[Omie-ELT-Pipeline]]
