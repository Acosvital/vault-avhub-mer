---
tags: [erp-acos-vital, prd-estoque, riscos]
criado: 2026-09-16
atualizado: 2026-10-07
---

# PRD Estoque — Riscos e Mitigação

> Status: decidido | no código (develop) | em produção (mes-test; produção real não)

> **Decisões de 07/10/2026 ([[Registro-de-Decisoes-2026-10-07]]):** a `main` do MES será atualizada por merge `develop` → `main` **antes do piloto** (CC-04 fechado; data e responsável 🔴 Robert); a carga inicial ganha **terceira contagem** na divergência; os guards do `api-pcp` seguem com a proposta 🟡 do item 12; **baixa/saldo no despacho do Estoque é do Robert** (ainda sem código).

> **Atualização de 07/10/2026 — dois riscos novos da auditoria código × vault** (no fim da tabela; nenhum risco anterior foi removido). Ambos vêm de leitura de código em `develop` — **produção, banco e exposição de rede não foram conferidos**: (1) controllers do `api-pcp` sem guard de permissão, **a confirmar com o Robert**; (2) `main` do MES parada desde 28/08 enquanto todo o Estoque está só em `develop`.

| Risco | Mitigação |
|---|---|
| Divergência sem estado terminal (repetir bug do PCP) | Todo estado de divergência/reprovação sempre com saída explícita. O backend real do app-pcp (`api-pcp`) tem um estado de Divergência (`ABERTA→EM_ANALISE→{RESOLVIDA\|CANCELADA}`) sem endpoint de reabertura — pode ser exatamente esse tipo de "beco sem saída", reintroduzido na versão nova do PCP; falta confirmar com o Robert. Ver [[App-PCP-Backend-Producao]] |
| Material usado antes da aprovação da qualidade | Lote nasce em quarentena; saldo só disponível após aprovação |
| Prisma travando build (já ocorreu no Backlog Ágil) | O Estoque vai usar Prisma (mora no banco do MES, que já roda Prisma em produção há cerca de 1 mês sem repetir o problema do Backlog Ágil). O risco não está descartado por princípio, mas é considerado de baixa probabilidade dado o histórico do MES. Ver [[Estoque-Modelo-Dados]] e [[MES-Arquitetura-Decisoes]] |
| Investir em RFID sem validar leitura em metal | Piloto obrigatório antes de qualquer compra em escala |
| Descolamento entre saldo do sistema e saldo físico | Rastreabilidade por lote + motivo obrigatório em ajuste + contagem cíclica |
| Mesmo lote comprometido por PCP e por uma venda ao mesmo tempo | Reserva de estoque obrigatória antes de qualquer separação |
| Quem cria o pedido também aprova ou recebe (risco de fraude) | Segregação de função por perfil de acesso |
| Carga inicial malfeita compromete confiança no sistema desde o dia um | Levantamento físico conferido em dupla (**contador + conferente**; **divergência = terceira contagem**, decidido em 07/10); nenhum consumo por PCP/Comercial antes da Fase 0 fechar *(atualizado em 07/10: conferido no código, só existe `POST /estoque/lotes/carga-inicial`, um lote por vez — **sem** importação em lote, dry-run ou folhas de contagem, tarefa G1)* |
| Cadastrar material em cima de catálogo Omie ainda duplicado | Saneamento roda antes do cadastro de material — nunca depois |
| Pedido aprovado travado para sempre porque fornecedor não entrega | Status CANCELADO explícito, com destinação/reserva reavaliada *(atualizado em 07/10: `RequisicaoCompra` já tem `CANCELADA`, cancelamento pelo MES em `POST /compras/requisicoes/:id/cancelar` (`e7ce2c9`) e reação a `requisicao_cancelada`/`requisicao_reaberta` vindos do Compras — conferido no código, `develop`)* |
| **(07/10/2026) Controllers do `api-pcp` sem guard de permissão** — conferido no código (`develop`, `ca3346b`): `UsuariosController` (POST/GET/PATCH/DELETE) e `SetoresController` (CRUD) **não têm guard algum**; só `:id/senha` e `:id/painel` têm JWT. Pedidos, itens-pedido, divergências, anexos, observações, roteiro-item, dashboard, relatórios e auditoria têm só JWT, sem `RequirePermission`. Não há `APP_GUARD` global. **A confirmar com o Robert** — hoje a barreira parece ser o BFF do `app-pcp`; a exposição de rede do `api-pcp` não foi verificada | Confirmar com o Robert se a API é alcançável fora do BFF; se for, guard global (`APP_GUARD`) ou `RequirePermission` nesses controllers antes de qualquer teste com dado real. Relacionado à tarefa C5 do [[Cronograma-2-Meses]] (parcial, não global). **🟡 Proposta adotada em 07/10 (Robert valida):** `JwtAuthGuard` + `PermissionsGuard` com `@RequirePermission` em `UsuariosController` e `SetoresController`, como em `perfis.controller.ts`; `GET /setores` fica só com sessão e o login Azure não pode ser bloqueado ([[Registro-de-Decisoes-2026-10-07]], item 12). Exposição pública da `api-pcp`: 🔴 Gustavo (item 13) |
| **(07/10/2026) `main` do MES parada desde 28/08** — api (`be076b2`) e app (`be847ac`) não receberam nada depois; o Estoque inteiro (D1 a D11, recebimento, qualidade, contratos 34/35) está só em `develop`, com 54 commits à frente da `main` na api. Se produção sobe da `main`, o que o vault descreve como pronto não está lá. Telas do menu também são criadas por SQL fora do repo (`modulos-telas.sql`) | Confirmar com o Robert de qual branch sobe produção/homologação e fechar um merge para `main` com janela e migrations revisadas (são 50 migrations, de 18/08 a 06/10). Até lá, nenhuma nota deve afirmar "em produção". **✅ Decidido em 07/10: merge `develop` → `main` antes do piloto (CC-04 fechado).** Data e responsável: 🔴 Robert. O `develop` já roda em `mes-test.acosvital.com.br` (homologação no ar) |
| **(07/10/2026) Baixa de saldo no despacho do Estoque ainda sem código** — a baixa continua ocorrendo quando a Embalagem recebe (`receber()` → `consumirReservasDaParcial`); a regra decidida em 29/09 (EC-05/EC-08) não foi implementada | **Robert assume** a baixa no despacho do Estoque ([[Registro-de-Decisoes-2026-10-07]], item 33). Capacidade dele estoura e precisa ser recalculada ([[Cronograma-2-Meses]]); sem a mudança, o saldo baixa cedo demais ou fora do despacho |

## Ver também
- [[PRD-Estoque-Visao-Geral]]
- [[Estoque-Modelo-Dados]]
- [[App-PCP-Backend-Producao]]
