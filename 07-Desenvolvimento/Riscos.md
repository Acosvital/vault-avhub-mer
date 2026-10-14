---
tags: [desenvolvimento, riscos]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [Registro-de-Decisoes #13 #15 #22 #33b #75 #92 #96, api-pcp 579a625, api-acos-vital f322dcd, omie-elt-pipeline 0f739f0, LOG-46, Equipe-e-Divisao]
---

# Riscos

Ameaças ao prazo, aos dados ou à segurança do fluxo de Atividades. Probabilidade (P) e impacto (I) em alta, média ou baixa, avaliação minha 🟡. Tarefas que mitigam: [[Backlog-por-Frente]]. Dúvidas: [[Pontas-Soltas]].

| ID | Risco | P | I | Dono | Mitigação | Selo |
|---|---|---|---|---|---|---|
| RS-001 | **`exclusionSync` apaga pedido manual.** O job apaga `pedidos_vendas` por empresa e janela sem filtrar `manual`; pedido manual tem `codigo_pedido_omie` negativo e não existe no Omie | alta | alta | Gustavo | Filtrar `manual` no `SELECT` e no `DELETE`; não usar pedido manual em produção antes (BL-027) | 🔴 `omie-elt-pipeline/src/jobs/exclusionSync.ts:103,136` |
| RS-002 | **`main` do MES parada em 28/08:** o banco de produção não tem as migrations da `develop`; subir sem o merge quebra o piloto | alta | alta | Robert (data), Gustavo (deploy) | Merge `develop` para `main` com data e responsável antes do piloto (BL-035); testar `migrate deploy` num banco limpo | 📝 #22, 🔴 data; última migration `20261014120000_compras_ccp` |
| RS-003 | **Chaves de serviço com acesso admin** para MES e pipeline: vazamento de uma chave abre a API inteira; as quatro chaves de ambiente restantes não podem ser fixadas | média | alta | Gustavo | Chave restrita por rota (BL-018); rotação documentada | 🔴 `apiKeyAuth.js:159-165` |
| RS-004 | **Capacidade do Robert:** déficit de 16,1 pd no Ciclo 1 (64,85 contra 48,75 pd), sem contar a baixa no despacho do Estoque; atrasa retirada, fabricado no Estoque, custo, job da OC e módulo `fluxo` | alta | alta | Nathan | Estender a janela (regra escrita: não cortar), levar J5 ao Ciclo 2 ou devolver parte do backend ao Gustavo; dimensionar BL-007 | 🟡 estimativas ±30%, Robert valida |
| RS-005 | **Torre sem dado:** o hub está pronto, o MES responde 404 em `/fluxo/*`; sem `fluxo.evento` a tela nasce vazia, e o hub não instrumenta os próprios eventos | alta | média | Robert, Gustavo | BL-003, BL-029; telas sobre fixtures (BL-022) | 🔴 `api-test` 13/10 |
| RS-006 | **Envio real de OC ao Omie** passou a ser fixo: um erro de payload vira pedido de compra errado no Omie (risco aceito L10.1, L10.6 FOB, L10.7 b a d); pedido apagado por fora não é detectado | média | média | Gustavo, Nathan | Checklist de subida (PS-009); conferir 1 a 2 OCs reais; acompanhar `fila-omie` | 📝 risco aceito #7, #17 |
| RS-007 | **Lote sem custo no Recebimento:** sem BL-001 e BL-005, o custo real por item é calculado só sobre lotes da carga inicial; o simulador e a comissão do Ciclo 2 recebem custo incompleto | alta | média | Robert | `completo: false` no `GET /itens/custo`; sinalizar lote sem custo; BL-001, BL-005 | 🔴 `compras.service.ts:545` |
| RS-008 | **Material comprado pelo Compras sem requisição do MES não tem entrada:** não chega ao MES (sem esperado, sem NF) e só entraria por carga inicial | média | média | Nathan | PS-003; BL-006 e BL-028 | 🔴 `Dump Avhub (Esqueleto).sql:8587` |
| RS-009 | **Exposição pública do `api-pcp`** (escuta em todas as interfaces, sem restrição de origem); mitigado pelo guard global deny-by-default | baixa | alta | Gustavo | Confirmar domínio no Coolify; restringir origem | 🔴 #13; guard ✅ `app.module.ts:90-91` |
| RS-010 | **Baixa na Embalagem × retirada:** enquanto o documento de retirada não existe, o saldo baixa quando a parcial é recebida na Expedição, mesmo que a mercadoria só saia depois; inventário físico e saldo divergem | média | média | Robert | BL-007; até lá, conferir saldo no levantamento físico de 26 a 30/10 | 🔴 `itens-parciais.service.ts:279` |
| RS-011 | **Fabricado nunca vira saldo:** peças fabricadas e aprovadas não entram no Estoque; o saldo de produto acabado não reflete a produção | alta | média | Robert | BL-008 | 🔴 `estoque.prisma:17-20` |
| RS-012 | **SQL e migrations do av-hub fora do repositório:** `fn_requisicao_mes_aplicar`, `api004`, `api005`, `api007`, 035b, 046b, 047b; sem versão, não há como reconstruir o banco nem auditar | média | alta | Gustavo | Versionar (BL-024); conferir o que está aplicado | ❓ |
| RS-013 | **LGPD na trilha:** o snapshot de nome e setor do ator fica no log por 5 anos; anonimizar funcionário não pode quebrar a trilha; o hub não tem `anonymizedAt` | baixa | média | Nathan | Política de anonimização antes do go-live da Torre; restringir `torre-fluxo-trilha` | 🔴 #92 |
| RS-014 | **Token expirado vira furo de acesso** quando o BFF parar de filtrar por vendedor (escopo de vendedores já fixo na API); `/pedido_venda_itens/{numero}` sem regra de dono | média | alta | Gustavo, Nathan | Renovar token antes de remover os filtros do BFF (BL-043) | 🔴 #92 |
| RS-015 | **Aprovação da OC não reflete a regra decidida:** Gerente aprova sempre e Diretoria acima de R$ 30 mil, mas o código só aprova acima do limite e só pela Gerência; sem usuários vinculados à Gerência, ninguém aprova | média | média | Nathan, Gustavo | BL-038, BL-040, PS-008 | 🔴 `ordens_compra.route.js:1235` |
| RS-016 | **Migrations do hub não conferidas em produção** (`api004`, `api005`, `api007`, 046b, 047b): rotas respondem 500 sem elas, ou o job nem chama o MES | média | média | Gustavo | Checklist de `\d` e `\df+` por contrato | ❓ |
| RS-017 | **Retentativa do `importado` termina em 7 dias** sem alerta; pedido liberado fica editável pelo vendedor e fora do MES | baixa | média | Robert | BL-034 | 🔴 `pedidos.service.ts:64-67` |
| RS-018 | **Prazo da Torre (S5 até 18/12):** depende de I2 e I3 do Robert; se deslizarem, I5 e I6 deslizam | média | média | Nathan | Fixtures e fonte por constante (seção 8 do LOG-46) | 🟡 |

## O que já deixou de ser risco

- Guards do `api-pcp` (usuários e setores sem permissão): resolvido no PR #51 (e8f951e) ✅.
- `PERMISSOES_ROTA_MODO`, escopo de vendedores e limite de login como chaves de ambiente: fixos no código ✅ ([[Chaves-e-Autenticacao]]).
- Envio de OC desligado por padrão: o envio é fixo ✅ ([[Omie-Integracao-Estado]]).

Ver também: [[Equipe-e-Divisao]], [[Cronograma]].
