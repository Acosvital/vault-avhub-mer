---
tags: [erp-acos-vital, prd-estoque, regras-de-negocio]
criado: 2026-09-16
atualizado: 2026-10-07
---

# PRD Estoque — Regras de Negócio Adicionais

> Status: decidido | no código (develop) | em produção (mes-test; produção real não)

> **Decisões de 07/10/2026 ([[Registro-de-Decisoes-2026-10-07]]):** ✅ **tolerância de peso = 5% para todas as categorias** (pode virar por categoria no futuro; item 26); a **baixa no despacho do Estoque** é do Robert (item 33) e **continua sem código**; **EC-02** (sobras e perdas de matéria-prima) vai ao **Ciclo 2**, que começa em 22/01/2027 (item 27).

> **Atualização de 07/10/2026 — o que do código já aplica estas regras** (conferido no código, `develop`, `api-pcp` `ca3346b`; produção não conferida): o **peso teórico × real** e a tolerância de 5% estão no `RecebimentoService` (desvio acima da tolerância vira divergência `PESO`); a regra **"lote sem laudo não libera"** vale na Qualidade (aprovar exige `laudoUrl`); a **cisão de lote** e a reprovação total/parcial existem (`src/qualidade`, `898aa54` de 24/09); a **requisição de compra** nasce do setor `REQUISICAO`. **Seguem sem código:** a baixa no despacho do Estoque e a Reserva restrita a "separar sem despachar" (EC-05/EC-08) — hoje a baixa ainda ocorre quando a **Embalagem recebe**; a ação de consumo de matéria-prima; e o `RoteiroItem` (C8). Ver [[Encaixe-Estoque-Revenda-no-PCP]] e [[Fluxo-Recebimento-Completo]].

Levantadas em análise de lacunas contra prática padrão de WMS/ERP e distribuição de aço no Brasil (sem pesquisa ao vivo — ver [[Estoque-Perguntas-Abertas]] para o que precisa ser confirmado).

- **Peso teórico × peso real**: todo material tem peso de tabela e uma tolerância própria (✅ **decidido em 07/10: 5% para todas as categorias**, ~~default provisório~~; pode virar por categoria depois); a pesagem na entrada é conferida contra peso teórico × quantidade.
- **Lote sem certificado não libera**: `status_qualidade` não pode sair de PENDENTE sem um `laudo_url` preenchido.
- **CFOP de entrada (nota do fornecedor) e ICMS-ST não são capturados por este sistema** — já existem na nota emitida pelo fornecedor; o Omie não sincroniza Nota de Entrada hoje, então ficam só lá. **Correção**: CFOP do lado da *venda* já é capturado e sincronizado por item em `produto_vendas.cfop` (validado contra whitelist) — é um dado diferente do CFOP de entrada aqui referido, mas relevante saber que já existe do lado de vendas.
- **Reprovação de qualidade sinaliza devolução, não a cria** — RNC marcada com `nota_devolucao_pendente = true`; emissão da nota de devolução acontece no Omie; o sistema só fecha a RNC quando essa nota volta pela sincronização.
- **Rastreabilidade para frente** depende de retorno de consumo vindo do PCP — não é algo que este projeto resolve sozinho.
- **Custo do lote (09/10/2026):** opcional, nunca bloqueia G1, recebimento, reserva nem despacho; o filho de cisão herda o custo; transferência não o muda; a sobra mantém o custo do próprio lote; frete é gravado mas fica fora do custo líquido; o custo do item no faturamento parcial é o custo médio do item no pedido (regra A). Ver [[Estoque-Custo-do-Lote]].
- **Carga inicial não é recebimento** — lote com `origem = CARGA_INICIAL` não passa pelos estados de aprovação de pedido nem pela conferência quantitativa/qualitativa normal.
- **Fornecedor não tem acesso ao sistema** — sem estado "em trânsito" verificável; data de entrega é sempre manual.
- **Destinação de item de pedido, não só do pedido inteiro** — decidido pelo comprador ao montar/revisar o pedido; vira sugestão automática de reserva assim que o lote é aprovado. **Como ficou no MES (24/09/2026):** a requisição nasce vinculada ao `ItemParcial` que entrou no setor Compras; aprovado na Qualidade, o item comprado **volta ao setor Estoque**, que dá entrada do lote e cria a reserva para aquele split — a "sugestão automática" virou passo do roteiro. Ver [[Encaixe-Estoque-Revenda-no-PCP]].
- **Reserva sem expiração (24/09/2026, implementada e testada 28/09)** — liberação só explícita, quando o pedido ou a OP é cancelado. Reserva aponta para lote + `ItemParcial` (split atendido) e nasce sempre sobre lote já liberado pela Qualidade. **Resolvido em 29/09/2026 (EC-05, Nathan)**: seguir com a proposta de 28/09 à tarde — a Reserva deixa de ser o mecanismo central de baixa (que passa a acontecer no despacho do Estoque) e fica restrita ao caso de "separar sem despachar". Ainda sem código para essa mudança *(reconferido em 07/10: continua sem código; `receber()` da Embalagem ainda chama `consumirReservasDaParcial`)*. Ver [[Encaixe-Estoque-Revenda-no-PCP]] seção 5.
- **Toda saída de item passa pelo Estoque, comprado OU fabricado (24/09/2026, EN-04)** — o item comprado não vai da Qualidade direto para a Expedição: entra no saldo, é reservado e sai do Estoque, igual ao item que já estava em estoque. Desde 25/09/2026 (EN-04) a mesma regra vale para o **produto fabricado**, não só o comprado. **Reconfirmado pelo Nathan em 29/09/2026: "tudo que é fabricado deve ir para o estoque"** — corrige uma descrição do modelo "Estoque único" que tinha deixado essa regra de fora. **Revisado em 25/09/2026 (em produção hoje)**: a baixa de saldo (reserva `CONSUMIDA`) só acontece quando a **Embalagem recebe** o item, não na saída do Estoque. **Revisado de novo e CONFIRMADO em 29/09/2026 (Nathan, EC-05/EC-08) — ainda sem código**: a baixa passa a ocorrer no **despacho do Estoque**, não no recebimento da Embalagem — ver [[Encaixe-Estoque-Revenda-no-PCP]] seção 5.
- ~~**Saneamento do catálogo Omie é pré-requisito, não opcional** — mapeado numa camada própria (`material_alias_omie`), sem corrigir o catálogo do Omie diretamente.~~ **Superado em 21/09/2026 (atualizado em 07/10):** o alias foi cancelado (contrato 002 rejeitado, D4 removida do cronograma); o código chegou a ter `material_alias_omie` e a removeu em `0ac2596` (29/09). Duplicata de catálogo fica com o Omie. Ver [[Estoque-Modelo-Dados]].
- **Múltiplos depósitos confirmados** — `deposito` é tabela própria; transferência entre depósitos é operação real.
- **Sem consignação** — confirmado que não existe estoque consignado (nem com cliente, nem com fornecedor).
- **Matéria-prima pode ser importada** — `pedido_compra.moeda` cobre isso.
- **Cisão de lote é prática real** — quando a qualidade reprova, a prática existente já é congelar o que foi reprovado e esperar chegar itens novos (valida o desenho de `lote_pai_id`).

## Segregação de função (seção 20 do PRD)

Regra clássica de controle interno: **quem cria o pedido não pode ser quem aprova, nem quem recebe o material**. Perfis: Comprador, Aprovador, Almoxarife, Qualidade, Gestor de estoque.

O RBAC do Estoque segue o mesmo padrão já em produção no backend do MES (`api-pcp`) *(atualizado em 07/10: conferido no código, o `PermissionsGuard`/`@RequirePermission` está por controller em ~20 controllers e o `ensurePodeAtuar` (`PerfilSetor`) nos services de compras e recebimento; **não há guard global** e a parte nova de filial (C3) não foi iniciada — ver [[Estoque-Riscos]])* *(atualizado em 09/10: o guard global existe desde o PR #51, `e8f951e`, com deny-by-default e `@Public()` só em health, login e integração av-hub; e o escopo por depósito entrou como `PerfilDeposito`, default-deny, com `pode_visualizar`/`pode_atuar` — ver [[Estoque-Modelo-Dados]]; a C3 segue não iniciada)*: modelo relacional de telas/perfis/permissões no Postgres + `PerfilSetor` para escopo por instância de setor — não nasce como biblioteca compartilhada com o av-hub, são implementações independentes aceitas conscientemente por velocidade de entrega. Os 5 perfis de segregação de função acima valem como **conceito de negócio**, independente do mecanismo técnico de autorização. Ver [[MES-Arquitetura-Decisoes]] (decisão 3) e [[Decisoes-Chave-ERP]]. A discussão da tensão entre os 3 modelos de RBAC que chegaram a coexistir fica registrada em [[Achado-Duplicacao-RBAC]].

## Ver também
- [[Encaixe-Estoque-Revenda-no-PCP]]
- [[Estoque-Modelo-Dados]]
- [[Estoque-Perguntas-Abertas]]
