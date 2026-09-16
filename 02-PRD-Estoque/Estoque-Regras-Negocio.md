---
tags: [erp-acos-vital, prd-estoque, regras-de-negocio]
criado: 2026-09-16
---

# PRD Estoque — Regras de Negócio Adicionais

Levantadas em análise de lacunas contra prática padrão de WMS/ERP e distribuição de aço no Brasil (sem pesquisa ao vivo — ver [[Estoque-Perguntas-Abertas]] para o que precisa ser confirmado).

- **Peso teórico × peso real**: todo material tem peso de tabela e uma tolerância própria (default provisório 5%); a pesagem na entrada é conferida contra peso teórico × quantidade.
- **Lote sem certificado não libera**: `status_qualidade` não pode sair de PENDENTE sem um `laudo_url` preenchido.
- **CFOP e ICMS-ST não são capturados por este sistema** — já existe na nota emitida pelo fornecedor e sincronizada do Omie.
- **Reprovação de qualidade sinaliza devolução, não a cria** — RNC marcada com `nota_devolucao_pendente = true`; emissão da nota de devolução acontece no Omie; o sistema só fecha a RNC quando essa nota volta pela sincronização.
- **Rastreabilidade para frente** depende de retorno de consumo vindo do PCP — não é algo que este projeto resolve sozinho.
- **Carga inicial não é recebimento** — lote com `origem = CARGA_INICIAL` não passa pelos estados de aprovação de pedido nem pela conferência quantitativa/qualitativa normal.
- **Fornecedor não tem acesso ao sistema** — sem estado "em trânsito" verificável; data de entrega é sempre manual.
- **Destinação de item de pedido, não só do pedido inteiro** — decidido pelo comprador ao montar/revisar o pedido; vira sugestão automática de reserva assim que o lote é aprovado.
- **Saneamento do catálogo Omie é pré-requisito, não opcional** — mapeado numa camada própria (`material_alias_omie`), sem corrigir o catálogo do Omie diretamente.
- **Múltiplos depósitos confirmados** — `deposito` é tabela própria; transferência entre depósitos é operação real.
- **Sem consignação** — confirmado que não existe estoque consignado (nem com cliente, nem com fornecedor).
- **Matéria-prima pode ser importada** — `pedido_compra.moeda` cobre isso.
- **Cisão de lote é prática real** — quando a qualidade reprova, a prática existente já é congelar o que foi reprovado e esperar chegar itens novos (valida o desenho de `lote_pai_id`).

## Segregação de função (seção 20 do PRD)

Regra clássica de controle interno: **quem cria o pedido não pode ser quem aprova, nem quem recebe o material**. Perfis: Comprador, Aprovador, Almoxarife, Qualidade, Gestor de estoque — mapeados como grupos no Azure AD já usado no Backlog Ágil.

⚠️ **Tensão arquitetural identificada**: nem o [[AV-Hub-RBAC|av-hub]] nem o [[App-PCP-Visao-Geral|app-pcp]] usam grupos do Azure AD para autorização — os dois usam um modelo relacional próprio de perfis/telas/permissões no Postgres, com tela de administração já pronta. Ver [[Achado-Duplicacao-RBAC]] para a discussão completa.

## Ver também
- [[Estoque-Modelo-Dados]]
- [[Estoque-Perguntas-Abertas]]
