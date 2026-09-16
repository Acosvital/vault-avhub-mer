---
tags: [erp-acos-vital, arquitetura, decisoes, mes]
criado: 2026-09-16
---

# MES Aços Vital — Arquitetura e Decisões (conversa de desenho, 16/09)

Registro da conversa de desenho de arquitetura entre av-hub e o sistema de fábrica (nome de trabalho: **MES Aços Vital**, até um nome melhor ser definido). Complementa [[Decisoes-Chave-ERP]] e [[Achado-Ambiguidade-PCP]] — este arquivo é o detalhe da conversa, aqueles continuam sendo o resumo executivo.

## Visão confirmada pelo usuário

- **av-hub** = o ERP de altíssimo nível: origina Orçamento, Pedido de Venda e Ordem de Compra (Orçamento e a criação nativa de Pedido de Venda/Ordem de Compra ainda **não são ativos hoje** — são visão de futuro, não construir agora). Também é onde dado do MES é lido/apresentado.
- **MES Aços Vital** = gestão de **Estoque + toda a fabricação** (não só Flanges — "toda a fabricação entra no MES, só falta criar as fábricas e roteiros fabris" das outras linhas, o modelo já é genérico o suficiente). Fronteira clara: **av-hub decide (Compras/Vendas), MES executa (produção, recebimento, saldo)**.
- Dois bancos separados (já é a realidade hoje entre av-hub/`api-acos-vital` e app-pcp/`api-pcp`) — nenhuma mudança nisso.

## Decisões tomadas nesta conversa

1. **Fornecedor não tem cadastro próprio no Estoque.** Reaproveita `core.parceiros` (av-hub) com `tipo_parceiro`, que já é sincronizado do Omie pelo pipeline ELT existente. O Estoque recebe uma **projeção read-only** desse dado (mesmo mecanismo de evento que o av-hub usa pra ler status de produção do MES, só que na direção contrária) — evita um 3º cadastro de fornecedor. Isso corrige o PRD original do Estoque, que propunha uma tabela `fornecedor` própria dentro do schema `estoque` — ver nota em [[Estoque-Modelo-Dados]].
2. **Toda a fabricação (Flanges, Chapas, Grades de Piso) entra no MES desde já**, não só Flanges. Não precisa de sistema novo por linha de produção — o modelo de Fábrica/Setor/Roteiro já é genérico o suficiente; só falta cadastrar as fábricas/roteiros das outras duas linhas quando chegar a hora.
3. **RBAC do Estoque segue o padrão já existente no backend do MES** (o mesmo modelo de telas/perfis/permissões + `PerfilSetor` que o `api-pcp` já tem) — não nasce como biblioteca compartilhada com o av-hub agora. Duas implementações independentes, aceitas conscientemente por velocidade de entrega.
4. **Estoque usa Prisma**, morando dentro do mesmo banco do MES, seguindo a disciplina de migrations que o Prisma já traz em produção — reverte a recomendação original do PRD do Estoque de evitar Prisma (o motivo daquela recomendação, um problema real de build no Backlog Ágil, não se repetiu em ~1 mês de MES em produção).
5. **Ordem de Compra é decidida no av-hub, referenciada no MES/Estoque** quando o material chega na doca — mesmo padrão que já existe entre av-hub (Pedido de Venda) e MES (execução da produção).
6. **Quando (no futuro) o av-hub passar a criar Pedido de Venda/Ordem de Compra nativamente, ele empurra para o Omie** (não o contrário) — Omie continua sendo o sistema fiscal/financeiro de registro. Implicações de design já levantadas para quando isso virar prioridade:
   - Escrita via outbox/fila (não síncrona) — grava local primeiro, sincroniza depois, evita travar o usuário numa instabilidade do Omie.
   - Risco de loop: o próximo ciclo do pipeline ELT vai "ler de volta" um pedido que o av-hub acabou de empurrar — precisa reconhecer pelo `codigo_pedido_omie` já preenchido.
   - Escrita nova disputa a mesma cota de rate limit do Omie que a leitura já usa — definir prioridade entre elas.
   - **Não confirmado ainda**: se o Omie tem endpoint de criação de Ordem de Compra via API (só vi endpoints de leitura no pipeline ELT analisado) — verificar antes de desenhar essa parte a sério.

## Dúvidas em aberto (perguntadas, ainda não respondidas)

- **Vínculo Fábrica ↔ Unidade/Filial (`codigo_empresa`)**: o `api-pcp` analisado não parece ter esse vínculo explícito hoje. O usuário confirmou que a fábrica **será** vinculada, mas ainda precisa decidir como. Sem isso, não dá para cruzar dado comercial por unidade (Mogi/Uberaba) com status de produção depois — vale resolver antes de generalizar o modelo pras novas linhas de produção (item 2 acima).
- **Conceito de "Orçamento"**: ainda não foi pensado pelo time — não é budget/verba nem necessariamente a formalização do cálculo de markup/ICMS/margem já visto no protótipo de comissão. Fica em aberto para quando entrar em pauta.
- **Nome definitivo do MES**: "MES Aços Vital" é só nome de trabalho.

## Ver também
- [[Perguntas-Pendentes-MES-Estoque]]
- [[Decisoes-Chave-ERP]]
- [[Achado-Ambiguidade-PCP]]
- [[App-PCP-Backend-Producao]]
- [[Estoque-Modelo-Dados]]
- [[Schema-Postgres-Multi-Dominio]]
- [[Omie-ELT-Pipeline]]
