---
tags: [desenvolvimento, riscos]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [Registro-de-Decisoes #13 #15 #22 #33b #75 #92 #96, api-pcp 579a625, api-acos-vital f322dcd, omie-elt-pipeline 0f739f0, LOG-46, Equipe-e-Divisao]
---

# Riscos

**Em uma frase:** esta nota lista o que pode atrasar o fluxo de Atividades, estragar dados ou expor a segurança, e quem cuida de cada ponto.

## Como ler esta lista

- Cada risco tem um ID `RS-nnn` (RS = risco).
- Colunas: **Risco**, **P** (probabilidade) e **I** (impacto), ambos em alta, média ou baixa (avaliação do autor 🟡), **Dono**, **Mitigação** (o que reduz o risco, com os BL de [[Backlog-por-Frente]]) e **Selo** com a evidência.
- Selos: ✅ resolvido, 📝 decidido ou aceito, 🟡 estimativa, 🔴 confirmado no código, ❓ não conferido em produção.
- Para achar o que é seu, procure seu nome na coluna **Dono**. Dúvidas sem dono estão em [[Pontas-Soltas]].
- Linhas longas começam com uma **frase em negrito** que resume o risco. O texto original vem logo depois, completo.
- Os textos citam datas de quando cada situação foi conferida. O RS-014 e o RS-020 citam o BL-043 e o BL-058: o estado atual deles está no Backlog (BL-043 fechado em 29/10; BL-058 com o que faltava conferido em 28/10).

## Resumo por frente

- **Gustavo (banco e API).** Os mais graves: `exclusionSync` apaga pedido manual (RS-001), chaves com acesso total e login Azure sem validação (RS-003, RS-020), SQL fora do repositório e migrations sem conferir em produção (RS-012, RS-016), exposição do `api-pcp` (RS-009) e Gerência de Compras sem usuários (RS-015).
- **Robert (MES).** A `main` do MES está parada em 28/08 e subir sem o merge quebra o piloto (RS-002). A capacidade dele não cobre o Ciclo 1 (RS-004). Também aparecem saldo que não reflete a produção e a baixa na hora errada (RS-010, RS-011), custo ausente no lote (RS-007), OC do hub que o MES não vê (RS-008) e retentativa que termina em 7 dias (RS-017).
- **Nathan (front e decisões).** Prazo da Torre (RS-018), LGPD na trilha (RS-013), imposto por item sem modelo (RS-019) e token expirado nos filtros do BFF (RS-014).
- **Compartilhados.** Torre sem dado (RS-005), envio real de OC ao Omie (RS-006) e o módulo Comercial numa API sem teste (RS-021).
- **Já deixaram de ser risco:** veja a lista no fim da nota.

## Lista completa

Ameaças ao prazo, aos dados ou à segurança do fluxo de Atividades. Probabilidade (P) e impacto (I) em alta, média ou baixa, avaliação minha 🟡. Tarefas que mitigam: [[Backlog-por-Frente]]. Dúvidas: [[Pontas-Soltas]].

| ID | Risco | P | I | Dono | Mitigação | Selo |
|---|---|---|---|---|---|---|
| RS-001 | **`exclusionSync` apaga pedido manual.** O job apaga `pedidos_vendas` por empresa e janela sem filtrar `manual`; pedido manual tem `codigo_pedido_omie` negativo e não existe no Omie | alta | alta | Gustavo | Filtrar `manual` no `SELECT` e no `DELETE`; não usar pedido manual em produção antes (BL-027) | 🔴 `omie-elt-pipeline/src/jobs/exclusionSync.ts:103,136` |
| RS-002 | **`main` do MES parada em 28/08:** o banco de produção não tem as migrations da `develop`; subir sem o merge quebra o piloto | alta | alta | Robert (data), Gustavo (deploy) | Merge `develop` para `main` com data e responsável antes do piloto (BL-035); testar `migrate deploy` num banco limpo | 📝 #22, 🔴 data; última migration `20261014120000_compras_ccp` |
| RS-003 | **Chaves de serviço com acesso admin** para MES e pipeline: vazamento de uma chave abre a API inteira; as quatro chaves de ambiente restantes não podem ser fixadas | média | alta | Gustavo | Chave restrita por rota (BL-018; desenho completo no [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] S1, BL-057); rotação documentada | 🔴 `apiKeyAuth.js:159-165` |
| RS-004 | **Capacidade do Robert:** déficit de 16,1 pd no Ciclo 1 (64,85 contra 48,75 pd), sem contar a baixa no despacho do Estoque; atrasa retirada, fabricado no Estoque, custo, job da OC e módulo `fluxo` | alta | alta | Nathan | **O Robert tem trabalho demais para o Ciclo 1 (déficit de 29,6 pd, pessoa-dia); o Nathan aceitou deslocar a data.** Estender a janela (regra escrita: não cortar), levar J5 ao Ciclo 2 ou devolver parte do backend ao Gustavo; dimensionar BL-007; **o escopo cresceu em 15/10 (N14-29: BL-052, BL-008, BL-051, recebimento por NF e requisição do hub, BL-065): o Robert estimou (15/10, ±30%) +16,5 pd: BL-052 3,0, BL-008 4,0, BL-051 4,0, API-009 no MES 1,0, recebimento por NF 4,0, uso interno 0,5; déficit de 16,1 para 32,6 pd e, **abatido o K4 (3,0 pd, na `develop` pela PR #59 do `api-pcp`, 15/10; N14-32), para 29,6 pd**; a 75% de foco a W0 vai de 21/01 para 18/02/2027 (a 100%, 02/02), e W1 a W4 deslocam o mesmo tanto; BL-007 (3,5 pd), BL-049 (1,5 pd) e BL-050 (1,5 pd) foram estimados pelo Robert em 15/10 (6,5 pd, ±30%) e **ficam fora da conta**; se entrarem no Ciclo 1, o déficit vai a 36,1 pd e a W0 termina em 03/03/2027 a 75% (15/02 a 100%). **Decisão do Nathan (15/10, N14-30): aceita deslocar a data**; escopo mantido** | 🟡 estimativas ±30%, Robert valida |
| RS-005 | **Torre sem dado:** o hub está pronto, o MES responde 404 em `/fluxo/*`; sem `fluxo.evento` a tela nasce vazia, e o hub não instrumenta os próprios eventos | alta | média | Robert, Gustavo | BL-003, BL-029; telas sobre fixtures (BL-022) | 🔴 `api-test` 13/10 |
| RS-006 | **O envio de OC ao Omie é real e o Omie não tem ambiente de teste: um erro vira pedido de compra errado.** **Envio real de OC ao Omie** passou a ser fixo: um erro de payload vira pedido de compra errado no Omie (risco aceito L10.1, L10.6 FOB, L10.7 b a d); pedido apagado por fora não é detectado. O envio funciona em teste (Nathan, 14/10), produção ❓. O Omie não tem ambiente de teste: os cadastros TESTE (fornecedor, cliente, transportadora) são reais, entram na pipeline e nos relatórios (CON-01) e podem ser usados por engano ou poluir conferências | média | média | Gustavo, Nathan | Checklist de subida (PS-009); conferir 1 a 2 OCs reais; acompanhar `fila-omie`; filtrar ou ignorar os cadastros TESTE em relatórios e conferências (BL-055) | 📝 risco aceito #7, #17; ✅ teste N14-25; 🟡 cadastros TESTE |
| RS-007 | **Lote sem custo no Recebimento:** sem BL-001 e BL-005, o custo real por item é calculado só sobre lotes da carga inicial; o simulador e a comissão do Ciclo 2 recebem custo incompleto | alta | média | Robert | `completo: false` no `GET /itens/custo`; sinalizar lote sem custo; BL-001, BL-005 | 🔴 `compras.service.ts:545` |
| RS-008 | **OC do hub sem requisição do MES não é vista nem recebida pelo MES:** sem o job da referência, o PCP não vê a OC do pedido, o Estoque não tem saldo futuro (pode comprar de novo o que já está comprado) e o Recebimento, que exige requisição do MES, não tem caminho de entrada para a mercadoria (N14-20) | média | média | Robert, Gustavo | BL-001, BL-006, BL-049, BL-050, BL-051; BL-028 no hub | 🔴 `api-pcp/src/compras/compras.service.ts:362-382` |
| RS-009 | **Exposição pública do `api-pcp`** (escuta em todas as interfaces, sem restrição de origem); mitigado pelo guard global deny-by-default | baixa | alta | Gustavo | Confirmar domínio no Coolify; restringir origem | 🔴 #13; guard ✅ `app.module.ts:90-91` |
| RS-010 | **Baixa na Embalagem × retirada:** enquanto o documento de retirada não existe, o saldo baixa quando a parcial é recebida na Expedição, mesmo que a mercadoria só saia depois; inventário físico e saldo divergem | média | média | Robert | BL-007; até lá, conferir saldo no levantamento físico de 26 a 30/10 | 🔴 `itens-parciais.service.ts:279` |
| RS-011 | **Fabricado nunca vira saldo:** peças fabricadas e aprovadas não entram no Estoque; o saldo de produto acabado não reflete a produção | alta | média | Robert | BL-008 | 🔴 `estoque.prisma:17-20` |
| RS-012 | **SQL e migrations do av-hub fora do repositório:** `fn_requisicao_mes_aplicar`, `api004`, `api005`, `api007`, 035b, 046b, 047b; sem versão, não há como reconstruir o banco nem auditar | média | alta | Gustavo | Versionar (BL-024); conferir o que está aplicado | ❓ |
| RS-013 | **LGPD na trilha:** o snapshot de nome e setor do ator fica no log por 5 anos; anonimizar funcionário não pode quebrar a trilha; o hub não tem `anonymizedAt` | baixa | média | Nathan | Política de anonimização antes do go-live da Torre; restringir `torre-fluxo-trilha` | 🔴 #92 |
| RS-014 | **Token expirado vira furo de acesso** quando o BFF parar de filtrar por vendedor (escopo de vendedores já fixo na API); `/pedido_venda_itens/{numero}` sem regra de dono | média | alta | Gustavo, Nathan | Renovar token antes de remover os filtros do BFF (BL-043). Desde a PR #206 o BFF falha fechado sem token (401) e renova antes de vencer; resta tirar os filtros (BL-043) e a regra de dono de `/pedido_venda_itens` | 🟡 #92 |
| RS-015 | **Gerência de Compras sem usuários vinculados:** a OC acima de R$ 30 mil só é aprovada por quem tem `compras.pode_aprovar` (perfil Gerência de Compras), que tinha 0 usuários no dump de 07/10 (❓ conferir no de 14/10); sem vínculo, ninguém aprova e a OC fica `aguardando_aprovacao`. A regra em si é a decidida (N14-21) | média | média | Nathan, Gustavo | Vincular os usuários (tarefa cadastral simples, N14-24) antes da primeira OC acima do limite | ❓ `ordens_compra.route.js:1230-1240` |
| RS-016 | **Migrations do hub não conferidas em produção** (`api004`, `api005`, `api007`, 046b, 047b): rotas respondem 500 sem elas, ou o job nem chama o MES | média | média | Gustavo | Checklist de `\d` e `\df+` por contrato | ❓ |
| RS-017 | **Retentativa do `importado` termina em 7 dias** sem alerta; pedido liberado fica editável pelo vendedor e fora do MES | baixa | média | Robert | BL-034 | 🔴 `pedidos.service.ts:64-67` |
| RS-018 | **Prazo da Torre (S5 até 18/12):** depende de I2 e I3 do Robert; se deslizarem, I5 e I6 deslizam | média | média | Nathan | Fixtures e fonte por constante (seção 8 do LOG-46) | 🟡 |
| RS-019 | **Imposto por item sem modelo:** o Ciclo 1 é sem imposto, mas em breve serão precisos os cenários com impostos (ICMS, IPI, ST, frete); sem desenho antecipado, a OC, o `lote_custo` e o contrato 008 podem exigir retrabalho | média | média | Nathan, Gustavo | Desenhar o modelo já (BL-053, PS-014) | 🟡 N14-23 |
| RS-020 | **Uma chave admin ou um e-mail dá acesso total à API; o plano de correção está no LOG-51.** **Controle total da API por uma chave ou por um e-mail:** a chave admin sem token dispensa permissão e escopo (S1); `/autenticacao/azure` emite JWT de qualquer usuário ativo só com o e-mail enquanto a validação do `id_token` está desligada, que é o padrão (S2); os roles do banco são `SUPERUSER` e a API faz DDL no boot (S8). Um vazamento ou uma falha na API vira acesso total ao banco. Valores de produção ❓ | média | alta | Gustavo, Nathan | [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] fases 1 e 2; o HUB foi primeiro (BL-058, PR #206, resta só `fetchMenu` e H7), depois BL-057 e BL-059; ligar a chave em modo só registro antes de negar | 🔴 `apiKeyAuth.js:160-161`, `azureIdToken.js:27-28`, dump `:19-23` |
| RS-021 | **O módulo Comercial entra numa API sem teste e com escopo de vendedor mal definido, com risco de vazamento entre vendedores.** **Módulo Comercial entra numa API sem teste e com escopo mal definido:** 22 tabelas e ~91 rotas novas na `api-acos-vital`, que não tem teste nem CI; no `api-comercial` o escopo `vinculados` não restringe nada e `?responsavel=` anula o escopo `proprios` (vazamento da carteira e de valores entre vendedores, LGPD); o preço vindo de OC do Omie depende da pipeline carregar `pedidos_compras` com IPI, ST, desconto e cancelado (Q1) | média | alta | Pablo, Gustavo | [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]]: BL-060 antes das rotas, Q3 (`vinculados`) respondida antes da fase 3, teste de isolamento entre vendedores como aceite (M1), Q1 antes da fase 5 | 🔴 `propostas.service.ts:148,152`, `clientes.routes.ts:69,73` |

## O que já deixou de ser risco

- Guards do `api-pcp` (usuários e setores sem permissão): resolvido no PR #51 (e8f951e) ✅.
- `PERMISSOES_ROTA_MODO`, escopo de vendedores e limite de login como chaves de ambiente: fixos no código ✅ ([[Chaves-e-Autenticacao]]).
- Envio de OC desligado por padrão: o envio é fixo ✅ ([[Omie-Integracao-Estado]]).
- Aprovação da OC "diferente da decisão": a regra decidida (N14-21) é a que o código faz ✅.
- `omie_raw` e `sql/002`: obsoletos, sem uso (N14-27); resta só o `DROP` (BL-054).

Ver também: [[Equipe-e-Divisao]], [[Cronograma]].
