---
tags: [erp-acos-vital, prd-estoque, riscos]
criado: 2026-09-16
---

# PRD Estoque — Riscos e Mitigação

| Risco | Mitigação |
|---|---|
| Divergência sem estado terminal (repetir bug do PCP) | Todo estado de divergência/reprovação sempre com saída explícita |
| Material usado antes da aprovação da qualidade | Lote nasce em quarentena; saldo só disponível após aprovação |
| ~~Prisma travando build (já ocorreu no Backlog Ágil)~~ — risco reavaliado, ver nota abaixo | ~~Usar Drizzle/Kysely desde o início~~ |
| Investir em RFID sem validar leitura em metal | Piloto obrigatório antes de qualquer compra em escala |
| Descolamento entre saldo do sistema e saldo físico | Rastreabilidade por lote + motivo obrigatório em ajuste + contagem cíclica |
| Mesmo lote comprometido por PCP e por uma venda ao mesmo tempo | Reserva de estoque obrigatória antes de qualquer separação |
| Quem cria o pedido também aprova ou recebe (risco de fraude) | Segregação de função por perfil de acesso |
| Carga inicial malfeita compromete confiança no sistema desde o dia um | Levantamento físico conferido em dupla; nenhum consumo por PCP/Comercial antes da Fase 0 fechar |
| Cadastrar material em cima de catálogo Omie ainda duplicado | Saneamento roda antes do cadastro de material — nunca depois |
| Pedido aprovado travado para sempre porque fornecedor não entrega | Status CANCELADO explícito, com destinação/reserva reavaliada |

> ⚠️ **Atualização (conversa de arquitetura, 16/09):** o risco de "Prisma travando build" foi **reavaliado e a mitigação revertida** — o Estoque agora vai usar Prisma (mora no banco do MES, que já roda Prisma em produção há ~1 mês sem repetir o problema do Backlog Ágil). Ver [[Estoque-Modelo-Dados]] e [[MES-Arquitetura-Decisoes]]. Risco original não descartado por princípio, só reavaliado como de baixa probabilidade dado o histórico recente do MES.

> ⚠️ **Atualização (pente fino, 16/09):** o backend real do app-pcp (`api-pcp`) tem hoje um estado de Divergência (`ABERTA→EM_ANALISE→{RESOLVIDA|CANCELADA}`) **sem endpoint de reabertura** — pode ser exatamente o tipo de "beco sem saída" citado como lição aprendida aqui, só que reintroduzido na versão nova do PCP. Vale confirmar com o Robert. Ver [[App-PCP-Backend-Producao]].

## Ver também
- [[PRD-Estoque-Visao-Geral]]
- [[Estoque-Modelo-Dados]]
- [[App-PCP-Backend-Producao]]
