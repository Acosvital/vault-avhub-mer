---
tags: [contrato-api, configuracao, seguranca, compras]
criado: 2026-10-06
atualizado: 2026-10-08
status: aplicada
---

# Contrato 38 — Regras decididas sem chave de ambiente

> **Atualização de 07/10/2026 — conferido no código (`main` = `develop` da `api-acos-vital`, `c8f2f5e` no PR #279; pipeline `master` `d2886bf`; produção não conferida no código; produção só pelo dump de 07/10, que cobre schema e dados, não o comportamento da API em produção; [[Auditoria-Dump-Producao-2026-10-07]]):**
> - **Saíram 13 chaves, não 11** (o §2 já tem 13 linhas): as 11 do texto + `BLACKLIST_PEDIDOS_CHAVE_LEGADA` + `COMISSOES_COORDENADORES_BLOQUEIO`; também saiu `COMPRAS_HISTORICO_UNIFICADO` (do 36 P6). **Nenhuma chave removida é lida por `process.env`.**
> - **(atualizado em 07/10, [[Registro-de-Decisoes-2026-10-07]] itens 7 a 10) Estado final das chaves:** `PERMISSOES_ROTA_MODO` passa a regra **fixa `exigir`** (✅, não é mais chave; Gustavo altera o código); `SYNC_ENVIO_OC` e `ENVIO_OC_DRY_RUN` **saem** (✅, envio fixo, direto ao Omie); das 5 chaves que restam, só `ESCOPO_VENDEDORES_EXIGIR` será fixada (✅ o front manda token; 🟡 Gustavo); `IDENTIDADE_EXIGIR_TOKEN`, `ESCOPO_UNIDADE_EXIGIR_SESSAO` e `AUTENTICACAO_AZURE_VALIDAR_ID_TOKEN` **quebram o MES e o pipeline** (que usam a chave do `.env` sem token) e ficam como chave até separar as chaves de serviço (L6, 🔴 Gustavo); `VENDAS_PLANILHA_PAGINAR_POR_PEDIDO` **corta dados no front** e fica como chave. A lista "6" abaixo é o retrato de 07/10 de manhã.
> - **Sobram exatamente as 6 do §3:** `IDENTIDADE_EXIGIR_TOKEN`, `PERMISSOES_ROTA_MODO` (padrão `desligado`), `ESCOPO_VENDEDORES_EXIGIR`, `ESCOPO_UNIDADE_EXIGIR_SESSAO`, `AUTENTICACAO_AZURE_VALIDAR_ID_TOKEN`, `VENDAS_PLANILHA_PAGINAR_POR_PEDIDO`.
> - **Segredos que também existem e não são "regra de negócio" (fora da lista do §3):** `MES_INTEGRACAO_KEYS` (nova, só abre o PUT do 34) e `DOCS_API_KEY` (pré-preenche a chave do `/docs`), além de `API_KEYS`, `USUARIO_TOKEN_SEGREDO`, `SESSION_SECRET` etc. Ver [[Chaves-de-Integracao-AvHub-MES-Pipeline]].
> - **Pipeline (§6):** além das chaves citadas, o diff da pipeline removeu `SYNC_COMPRADORES`, `SYNC_COTACAO_PTAX`, `SYNC_PEDIDOS_COMPRAS`, `SYNC_CONDICOES_PAGAMENTO_COMPRAS`, `SYNC_PROJETOS`, `SYNC_CONTAS_CORRENTES`, `SYNC_CATEGORIAS`, `EXCLUSION_SYNC_DRY_RUN` e `RAW_AUDIT_ENABLED` (com `upsertRawAudit`, `d6abf04`); ficavam `SYNC_ENVIO_OC` (padrão `false`) e `ENVIO_OC_DRY_RUN` (padrão `true`; **atualizado em 07/10: ambas saem, o envio fica fixo e direto ao Omie, ✅**). O `exclusionSync` agora apaga de verdade (o CSV é só relatório).
> - **§5 (orçamento × coordenadores), reescrito em 08/10/2026:** este contrato trata só das chaves; do orçamento, só a comissão dos coordenadores (sem bloqueio) é dele. O orçamento foi desenvolvido **por fora**, no módulo Comercial & Suprimentos (✅ Nathan, [[Registro-de-Decisoes-2026-10-07]] item 39), e o que falta dele está no [[07-Dados-Orcamento-e-Coordenadores-no-Banco]] reescrito.

> ✅ **Concluído no código (06/10/2026).** O DBA aplicou os patches `38-anexos/0001` e `0002` na `develop`
> da API (commit `c8f2f5e`): nenhuma das 11 chaves é mais lida do ambiente (**atualizado em 07/10:** foram 13, ver acima), `BLACKLIST_PEDIDOS_CHAVE_LEGADA`
> saiu e a comissão dos coordenadores roda sempre **sem** bloqueio por NF. Continuam com chave, de propósito,
> as do §3 (segurança e `VENDAS_PLANILHA_PAGINAR_POR_PEDIDO`), até o pré-requisito de cada uma.
> **Ordem de subida (§4) ainda vale:** em 06/10 nenhum dos 74 compradores de produção estava ligado a um
> funcionário (**atualizado em 07/10:** carga de 07/10 deixou **20 de 74** vinculados; só importam os 32 ativos; ver [[Registro-de-Decisoes-2026-10-07]] item 51) — sem isso ninguém emite OC (a tela de Compradores em Cadastros › Acessos foi liberada para o
> Admin (Dev) em produção no mesmo dia). As regras de Compras não foram testadas em produção (só leitura; **o schema de Compras já existe em produção desde 02/10, conferido no dump de 07/10**).

**Para:** backend (`api-acos-vital`) e quem faz o deploy · **Decisão do Nathan (06/10/2026):** "Não
quero variáveis de ambiente, por padrão deve ser true".

## 1. Por quê

Cada regra nova que podia travar alguém entrou atrás de uma chave **desligada** no ambiente, para
"ligar depois". O "depois" não acontece: a regra existe no código e não vale (foi o caso do P1 do
[[36-Compras-Produto-Obrigatorio-e-Comprador-da-OC]]). **Regra decidida é fixa no código.** Quando a
ordem de subida importa, ela vai escrita no contrato (§4), não numa variável.

Levantamento de 06/10/2026 na `develop`: 15 chaves de regra na API (além das de infraestrutura).

## 2. O que muda (patch pronto)

Patches, nesta ordem: `36-anexos/0001-produto-sempre-obrigatorio.patch`, depois
`38-anexos/0001-regras-sem-chave-de-ambiente.patch` e `38-anexos/0002-sem-bloqueio-comissao-coordenadores.patch`
(o 36 e o 0001 mexem no mesmo arquivo). Troca a leitura da variável
pelo valor da regra; a lógica não muda.

| Chave | Era | Passa a | Regra |
|---|---|---|---|
| `COMPRAS_EXIGIR_PRODUTO_CADASTRO` | false | **sempre** | item da OC com produto do cadastro da unidade (patch do contrato 36) |
| `COMPRAS_VINCULO_EXIGIR_PV_EXISTENTE` | false | **sempre** | PV digitado na OC precisa existir no espelho (decisão do Nathan) |
| `COMPRAS_EXIGIR_VINCULO_COMPRADOR` | false | **sempre** | só emite OC quem é comprador vinculado na unidade |
| `COMPRAS_EXIGIR_PODE_APROVAR` | false | **sempre** | só quem tem `pode_aprovar` em `compras` aprova/cancela (OC e compradores) |
| `COMPRAS_ACOMPANHAMENTO_EXIGIR_PERMISSAO` | false | **sempre** | follow-up do CCP confere a tela `followup` (contrato 32) |
| `NOTAS_MANUAIS_EXIGIR_PERMISSAO` | false | **sempre** | NF manual só o administrador (contrato 29) |
| `PEDIDOS_MANUAIS_EXIGIR_PERMISSAO` | false | **sempre** | o mesmo para pedido manual |
| `CADASTROS_OMIE_SOMENTE_LEITURA` | true | **sempre** | vendedor/comprador do Omie não se cria, exclui nem edita (contrato 28) |
| `VAGAS_TRAVAS_DECISAO` | true | **sempre** | travas de decisão das vagas (contrato 04) |
| `VENDAS_PLANILHA_VIEW_LEVE` | true | **sempre** | planilha de vendas pela view rápida |
| `AUDITORIA_ATIVA` | true | **sempre** | grava `auth.auditoria` |
| `BLACKLIST_PEDIDOS_CHAVE_LEGADA` | false | **removida** | modo de transição; o av-hub já manda `codigo_empresa` em todo PUT/DELETE |
| `COMISSOES_COORDENADORES_BLOQUEIO` | false | **removida, sem bloqueio** | decisão do Nathan (06/10): o bloqueio por NF **não** se aplica à comissão dos coordenadores; a rota manda sempre `p_aplicar_bloqueio = false` (patch 0002) |

Testado na API local (banco = cópia de produção de 05/10), **sem nenhuma dessas variáveis**: blacklist
sem `codigo_empresa` → 400; OC por quem não é comprador vinculado → 400 ("Você não está vinculado como
comprador em Aços Vital…"); `POST /vendedores` → 403 (cadastro vem do Omie); item sem produto ou com
produto de outra unidade → 400; produto da unidade → 201.

Depois de aplicado, **apagar essas variáveis** do ambiente (`.env`/painel) da API de teste e de produção.

## 3. O que ainda depende de um passo (fixar depois)

Mesma regra (vai ficar fixa, sem chave), mas só depois de conferir o pré-requisito (**conferido em 07/10: são exatamente estas 6 que sobram no código**; `MES_INTEGRACAO_KEYS` e `DOCS_API_KEY` são segredos e ficam fora da lista):

| Chave | Pré-requisito |
|---|---|
| `IDENTIDADE_EXIGIR_TOKEN` | o av-hub manda `Authorization: Bearer` (token do usuário) em **toda** chamada de negócio. **(07/10)** O front manda (✅), mas MES e pipeline usam a chave do `.env` sem token: fixar quebra os dois. Fica como chave até separar as chaves de serviço (L6, 🔴 Gustavo) |
| `PERMISSOES_ROTA_MODO` (`desligado`/`observar`/`exigir`) | rodar em `observar` e ver no log que nada que deveria passar daria 403; depois fixar `exigir`. **(07/10, ✅)** Decidido: **fixo em `exigir`**, deixa de ser chave. Chamadas de serviço só com `x-api-key` passam sem mapeamento (o modo só confere com token) |
| `ESCOPO_VENDEDORES_EXIGIR` | mesmo do token acima. **(07/10)** ✅ o front manda token; 🟡 Gustavo: **será fixada** (a única das 5 restantes) |
| `ESCOPO_UNIDADE_EXIGIR_SESSAO` | o av-hub manda `id_usuario_sessao` em toda leitura com escopo (hoje, sem ele, o usuário vê **tudo**). **(07/10)** Quebra MES e pipeline (chave do `.env` sem token); fica como chave até separar as chaves de serviço (L6, 🔴 Gustavo) |
| `AUTENTICACAO_AZURE_VALIDAR_ID_TOKEN` | o BFF repassa o `id_token` do Azure no login. **(07/10)** Idem: quebra MES e pipeline; fica como chave até L6 (🔴 Gustavo) |
| `VENDAS_PLANILHA_PAGINAR_POR_PEDIDO` | o av-hub pagina por `total_pages` (não por "linhas ≥ total"). **(07/10)** Fixar **corta dados no front**: fica como chave |

## 4. Ordem de subida (o que antes era feito ligando a chave)

1. **Antes da API:** perfil **Gerência de Compras** com `pode_aprovar` em `compras` e as pessoas nele
   (sem isso ninguém aprova OC); **compradores vinculados aos funcionários** em Cadastros › Acessos ›
   Compradores (sem isso ninguém emite OC — em 05/10 não havia nenhum vínculo; **atualizado em 07/10:** 20 de 74 vinculados); permissão da tela
   `followup` para quem acompanha OC; `notas-fiscais-manuais` só no perfil do administrador.
2. **API** com os patches dos contratos 36 e 38.
3. **Apagar** as variáveis da §2 do ambiente.

## 5. Decidido: sem bloqueio na comissão dos coordenadores (06/10/2026)

`COMISSOES_COORDENADORES_BLOQUEIO` vinha do [[07-Dados-Orcamento-e-Coordenadores-no-Banco]] ("coordenadores … com o mesmo bloqueio de comissão que os vendedores"). A parte dos coordenadores foi implementada na `api-acos-vital` (`90bdb33`, 01/10: `GET /dashboard/comissoes` + `fn_dashboard_comissoes`), com o bloqueio atrás da chave por mudar o valor pago. **Decisão do Nathan: não aplica.** O patch 0002 tira a chave e fixa `false` (é o que já rodava). Testado na API local: `GET /dashboard/comissoes?ano_mes=2026-09` → 5 coordenadores, 44 vendedores, `bloqueio_coordenadores_aplicado: false`. Limpeza opcional para o DBA: tirar o parâmetro `p_aplicar_bloqueio` (e o cálculo) de `fn_dashboard_comissoes`.

**Orçamento (atualizado em 08/10/2026):** não é deste contrato. O `90bdb33` também implementou na API as rotas `/orcamento/*`, mas o orçamento foi desenvolvido **por fora**, no módulo Comercial & Suprimentos (✅ Nathan, [[Registro-de-Decisoes-2026-10-07]] item 39). O que falta (tirar as telas e os JSON antigos do av-hub, decidir o destino das rotas `/orcamento/*`, conferir o slug `fornecedores`) está no [[07-Dados-Orcamento-e-Coordenadores-no-Banco]] reescrito em 08/10.

## 6. Pipeline e av-hub (já feito)

- `omie-elt-pipeline` PR #2 (mergeado em 06/10/2026): saíram os `SYNC_*` de leitura de Compras,
  `EXCLUSION_SYNC_DRY_RUN` (produção já rodava de verdade: run_log `ok`, nenhum `dry_run` em 30 dias) e
  `RAW_AUDIT_ENABLED`. Ficam só `SYNC_ENVIO_OC` e `ENVIO_OC_DRY_RUN` (escrita no Omie), até o passo 2 da
  §4 e os compradores vinculados. **(08/10/2026: também saíram, na `master` da pipeline, PR #3, `0f739f0`; o envio é fixo. Este parágrafo é histórico de 06/10.)**
- av-hub: só `NEXT_PUBLIC_DEV_SEM_LOGIN` (modo de desenvolvimento, bloqueado em produção pelo código).

## 7. Aceite

- `git grep` na `develop` não acha mais `process.env` nem `bool("…")` para as chaves da §2.
- Na `api-test`, sem as variáveis: os 400/403 da §2 acontecem.
- Aprovar OC com usuário da Gerência de Compras → 200; com usuário sem `pode_aprovar` → 403.
