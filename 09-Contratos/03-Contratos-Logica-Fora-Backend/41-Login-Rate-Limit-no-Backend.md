---
tags: [contrato-logica, contrato-api, seguranca, login, gambiarra-s9]
criado: 2026-10-07
atualizado: 2026-10-09
status: proposta
---

# Contrato 41 — Login: rate limit no backend (fecha a GAMBIARRA S9)

> **(atualizado em 09/10/2026)** Pedido do Nathan: contrato do rate limit do login, **sem variável de ambiente**: limite e janela ficam **fixos no código da API** (princípio do [[38-Regras-Sem-Chave-de-Ambiente]]). Conferido em 09/10 na `api-acos-vital` (`develop`, `dee35b0`) e no `av-hub` (branch `feat/bff-bearer-helpers`, commit `564abc8`, PR #178, **ainda não mergeado**). Comissões ficam fora de escopo. Legenda: ✅ verificado no código · 🟡 inferência · 🔴 pendente com dono. As seções 1 a 9 abaixo são o texto de 07/10; onde mudou, vale esta seção 0 (**superado** nos pontos que ela cita: liga/desliga por variável, chave só por IP, BFF sem `x-cliente-ip`, mensagem do 429 opcional).

## 0. Estado de 09/10/2026 e o que falta

**Estado verificado (✅):**

- **API:** `utils/acessoConfig.js` ainda tem `loginLimite()` lendo `LOGIN_LIMITE_TENTATIVAS` (padrão 0 = desligado) e `LOGIN_LIMITE_JANELA_SEGUNDOS` (padrão 900, mínimo 10) do ambiente; o comentário do topo do arquivo ainda documenta as duas variáveis. A rota `POST /autenticacao/login` usa `auth.fn_login_bloqueado`, `auth.fn_login_falha` e `auth.fn_login_sucesso`, devolve **429** com `Retry-After` e `{ codigo: "LOGIN_LIMITE" }`, e monta as chaves `email:<e-mail>` e `ip:<x-cliente-ip>` (o IP **sozinho**, não `ip:email`). `loginOk` zera **só a chave do e-mail**. Como o padrão é 0, **sem a variável setada o limite não existe**.
- **Front (PR #178, não mergeado):** o `authorize` em `app/api/auth/[...nextauth]/route.ts` já manda `x-cliente-ip` (último valor de `x-forwarded-for`, o do proxy mais próximo) e, ao receber 429, lança o erro `LOGIN_LIMITE`; `app/(public)/login/page.tsx` mostra "Muitas tentativas de login. Aguarde alguns minutos e tente de novo." Isso entrega o item 3 e a Q5 da proposta. **O limitador local continua**: `lib/auth/loginRateLimiter.ts` (5 tentativas em 15 min, `Map` no processo, chaves `ip:email` e `email`) segue em uso, com a marca `GAMBIARRA(` na linha 24.
- **Azure AD:** `POST /autenticacao/azure` **não** passa por esse limite (só `/login` chama `limiteExcedido`). 🟡 Faz sentido não passar: a senha é validada pelo Azure, que tem proteção própria, e aqui não há falha de senha para contar. Fica fora.

### (a) O que a API precisa mudar (Gustavo)

1. Em `acessoConfig.js`, `loginLimite()` devolve **valores fixos** `{ max: 5, janela: 900 }` (os mesmos do front). Remover a leitura de `process.env` e as duas linhas `LOGIN_LIMITE_*` do comentário do topo. Nada de `.env`.
2. Com o limite sempre ligado, os `if (!max) return` em `limiteExcedido`, `loginFalhou` e `loginOk` perdem a função (podem ficar ou sair).
3. Atualizar o comentário de `chavesLimite` ("LOGIN_LIMITE_TENTATIVAS=0 desliga") e o `autenticacao.swagger.json`, que cita a variável.
4. **Chave por IP:** ver a recomendação abaixo. 🟡 Trocar `ip:<ip>` por `ip:<ip>:<e-mail>` mexe só em `chavesLimite`, mas `loginOk` usa `chavesLimite(...)[0]` (a do e-mail) e deveria zerar também a chave composta.
5. **Confirmar que as funções existem no banco.** 🔴 O DDL real de `auth.fn_login_bloqueado`, `fn_login_falha`, `fn_login_sucesso` e da tabela `auth.login_tentativas` **não está no repositório da API** (ela não versiona SQL). O dump de 07/10 lista os nomes ([[Auditoria-Dump-Producao-2026-10-07]]), mas o corpo não foi lido. **Pedir ao Gustavo** `\df+ auth.fn_login_*` e `\d auth.login_tentativas`, e conferir: (i) se bloqueia a partir de `>= max` (esperado: a 6ª tentativa recebe 429) ou `> max`; (ii) se a chave é `text` livre (aceita `ip:ip:email`); (iii) se o retorno é em segundos.

**Recomendação de chave (mantida, agora com o dado do código):** bloquear por **e-mail** e por **IP+e-mail**, **não** por IP sozinho. Com `ip:<ip>` sozinho e `max = 5`, cinco erros de pessoas diferentes atrás do mesmo NAT bloqueiam a empresa toda; e, como `loginOk` não zera a chave de IP, os erros acumulam mesmo entre usuários que depois acertam. 🟡 Se o Nathan mantiver o IP sozinho, o limite do IP teria de ser bem maior que o do e-mail, mas a função recebe um único `max` para todas as chaves.

### (b) O que o front já fez (PR #178) e o que falta

- **Já feito:** envia `x-cliente-ip`; trata 429 como `LOGIN_LIMITE`; mensagem própria na tela de login.
- **Falta, só depois de a API estar no ar com o limite fixo:** apagar `lib/auth/loginRateLimiter.ts`; tirar do `authorize` os imports e usos de `chaveRateLimit`, `chaveRateLimitEmail`, `reservarTentativaLogin` e `limparTentativas`; remover a marca `GAMBIARRA(`. Manter o tratamento do 429 e a mensagem. Atualizar a contagem de marcas (item 58 do [[Registro-de-Decisoes-2026-10-07]]).

### (c) Passo a passo e ordem

| # | Quem | Passo |
|---|---|---|
| 1 | Gustavo | Enviar o DDL real das 3 funções e da `auth.login_tentativas`; dizer se `LOGIN_LIMITE_TENTATIVAS` está setada em produção hoje |
| 2 | Gustavo | Na `develop` da API: fixar `max: 5` e `janela: 900`, remover a leitura de ambiente, ajustar `chavesLimite`/`loginOk` conforme a Q2, atualizar swagger e comentários |
| 3 | Gustavo | Subir a API (`develop` para `main`). **A API vai primeiro.** Sem o IP (PR #178 fora), o limite já vale por e-mail |
| 4 | Front | Mergear o PR #178 (manda o IP e trata o 429). O limiter local **fica** |
| 5 | Nathan | Rodar os testes de aceite (d) na homologação, com API e front já no ar |
| 6 | Front | Novo PR: apagar `loginRateLimiter.ts` e as chamadas, **só depois de o passo 5 passar em produção** |

### (d) Testes de aceite

- **N falhas dão 429:** 5 senhas erradas para o mesmo e-mail e a 6ª tentativa devolve **429** com `Retry-After` e `codigo: "LOGIN_LIMITE"`, direto na API e pela tela (mensagem "Muitas tentativas...").
- **Reinício não zera:** redeploy da API no Coolify logo após estourar; continua 429 (contador no banco).
- **Outros não são afetados:** outro e-mail no mesmo IP continua entrando (vale com `ip:email`; com IP sozinho este teste **falha**, e é a prova do risco de NAT); outro IP com o mesmo e-mail continua bloqueado (chave do e-mail).
- **Sucesso zera:** login correto antes da 5ª falha zera o contador (conferir também a chave de IP).
- **Janela:** passados 900 s o login volta.
- **IP gravado:** em `auth.login_tentativas` a chave `ip:` mostra o IP do cliente, não o do Traefik nem o do BFF.
- **Azure:** SSO entra normalmente, sem contar nem sofrer o limite.
- **Sem variável:** com `LOGIN_LIMITE_*` ausente do ambiente, o 429 acontece (prova de que o valor é fixo).

### (e) Riscos e rollback

- **IP atrás do Traefik/Coolify (🟡):** o front usa o **último** valor de `x-forwarded-for`. Havendo mais de um proxy (CDN, balanceador), esse valor é o do proxy e todos caem na mesma chave de IP. Não conferi a configuração do Traefik.
- **NAT:** ver a recomendação acima.
- **Spoof de `x-cliente-ip`:** só o BFF chama a rota (exige `x-api-key`); o cabeçalho é confiável enquanto a chave não vazar.
- **Falha do banco:** `limiteExcedido` não tem `catch`; se a consulta falhar o login devolve 500. 🟡 Decidir falhar aberto ou fechado. `loginFalhou` e `loginOk` já ignoram o erro (só registram).
- **Valor fixo:** mudar o limite exige deploy. Aceito, como no contrato 38.
- **Rollback:** reverter o commit da API (volta ao desligado) e, se o front já removeu o limiter, reverter o PR dele; por isso o limiter local só sai depois da validação (passo 6). Em bloqueio indevido em massa, o DBA limpa `auth.login_tentativas` sem deploy.

### (f) Perguntas

| # | Pergunta | Dono |
|---|---|---|
| Q1 | 🔴 Confirmar 5 tentativas / 900 s fixos no código (os do front). | Nathan |
| Q2 | 🔴 Chave: e-mail + **IP+e-mail** (recomendado) ou e-mail + IP sozinho (como o código está)? | Nathan / Gustavo |
| Q3 | 🔴 Quantos proxies entre o cliente e o BFF? O último valor de `x-forwarded-for` é o IP do cliente? | Gustavo |
| Q4 | 🔴 `LOGIN_LIMITE_TENTATIVAS` está setada em produção? Corpo de `fn_login_*` (`>=` ou `>`, tipo da chave)? Falha aberta ou fechada se o banco falhar? | Gustavo |
| Q5 | Mensagem própria do 429: **feita** no PR #178; falta mergear. | Front |
| Q6 | 🟡 Azure continua fora do limite (proposta acima). | Nathan |

---

> **Status (superado em 09/10/2026 pela seção 0; texto de 07/10 preservado): proposta (07/10/2026).** Fecha a marcação `GAMBIARRA(` de `lib/auth/loginRateLimiter.ts:24` do av-hub ("rate limit em memória do processo (S9): precisa de store compartilhado"). **Achado principal: a API já tem o limite em banco, só que desligado por padrão e sem o BFF mandar o IP.** O trabalho é ligar, fixar valores, mandar o IP e apagar o código do front. Fontes: leitura do av-hub (`lib/auth/loginRateLimiter.ts`, `app/api/auth/[...nextauth]/route.ts`) e da `api-acos-vital` (`utils/acessoConfig.js`, `schemas/auth/aggregates/autenticacao/autenticacao.route.js`), em 07/10/2026. Legenda: ✅ verificado no código · 🟡 inferência · 🔴 pendente com dono. Decisões gerais em [[Registro-de-Decisoes-2026-10-07]]; o método "regra decidida é fixa no código" vem do [[38-Regras-Sem-Chave-de-Ambiente]].

**Para:** backend (`api-acos-vital`, Gustavo) e av-hub (BFF) · **Pequeno.** Sem tabela nova a criar (ver §2).

## 1. Estado atual no front (✅)

`loginRateLimiter.ts` guarda um `Map` em memória do processo Node:

| Constante | Valor |
|---|---|
| `JANELA_MS` | 15 min |
| `LIMITE_TENTATIVAS` | 5 |
| Chaves | `ip:email` e `email:<email>` (as duas precisam ter espaço) |
| O que conta | **toda tentativa**, reservada **antes** de chamar o backend; zera as duas chaves no sucesso |

Quem usa: só o `authorize` do `CredentialsProvider` em `app/api/auth/[...nextauth]/route.ts`. O IP é o **último** item de `x-forwarded-for` (o que o proxy mais próximo anexou). Estourado o limite, o `authorize` devolve `null` sem chamar a API; o usuário vê o mesmo erro de credencial inválida. O login Azure (SSO) não passa por esse limite.

**O problema (S9):** o contador some a cada deploy/reinício e não é compartilhado entre réplicas (o próprio comentário do arquivo assume isso).

## 2. O que a API já faz (✅ no código; 🟡 no banco)

- **Onde:** `POST /autenticacao/login` (`autenticacao.route.js`). `limiteExcedido` roda **antes** de consultar o usuário; `loginFalhou` conta nas duas falhas (usuário inexistente e senha errada); `loginOk` zera a chave do e-mail.
- **Store:** **banco**, não memória. Funções `auth.fn_login_bloqueado`, `auth.fn_login_falha` e `auth.fn_login_sucesso`. O dump de produção de 07/10 lista `fn_login_*` e a tabela `auth.login_tentativas` ([[Auditoria-Dump-Producao-2026-10-07]]). Vale para todas as réplicas e sobrevive a reinício.
- **Resposta:** **429** com `{ codigo: "LOGIN_LIMITE", detail: "Muitas tentativas de login. Tente de novo em N s." }` e cabeçalho `Retry-After`.
- **Chaves:** `email:<e-mail em minúsculas>` e, **só se o BFF mandar o cabeçalho `x-cliente-ip`**, `ip:<ip>`. O código explica: sem o cabeçalho todos os logins chegam do IP do BFF e um bloqueio por IP pararia todo mundo.
- **Liga/desliga:** `acessoConfig.js` → `loginLimite()` lê `LOGIN_LIMITE_TENTATIVAS` (padrão **0 = desligado**) e `LOGIN_LIMITE_JANELA_SEGUNDOS` (padrão 900, mínimo 10).
- **O BFF não manda `x-cliente-ip`** (busca em todo o front: nenhuma ocorrência). Hoje, mesmo ligado, a API só limitaria por e-mail.

**Conclusão:** o store compartilhado **já resolve a S9**. Falta (a) ligar com valores fixos no código, (b) o BFF repassar o IP e (c) apagar o limiter do front. 🟡 **Não verificado:** se `LOGIN_LIMITE_TENTATIVAS` está setada em produção hoje (o dump não mostra variável de ambiente) e o corpo SQL das 3 funções (não está no disco nem no vault; só o nome aparece no dump).

### Diferenças de comportamento (front atual x API)

| Ponto | Front hoje | API |
|---|---|---|
| Conta | toda tentativa | só **falhas** (e-mail errado ou senha errada) |
| Chave por IP | `ip:email` | `ip` **sozinho** (e e-mail sozinho) |
| Zera no sucesso | as duas chaves | só a do e-mail |
| Máximo e janela | 5 / 15 min | um único `max` e `janela` para todas as chaves |
| Usuário inativo | conta | **não** conta (retorna 401 antes) |

🟡 **Consequência a decidir:** com `ip` sozinho e `max = 5`, **cinco senhas erradas de pessoas diferentes atrás do mesmo IP (a empresa toda, se todos saem por um NAT)** bloqueiam todos por 15 min. O front de hoje não tem esse efeito porque a chave de IP inclui o e-mail. Ver pergunta Q2.

## 3. Proposta

1. **Fixar o limite ligado no código** (sem `.env`, como o contrato 38): em `acessoConfig.js`, `loginLimite()` passa a devolver valores fixos, **`max: 5` e `janela: 900`** (os do front atual, para manter o comportamento). As duas variáveis saem da documentação do arquivo e de `AV-Hub-API-Estado-Atual`.
2. **Chave por IP:** manter `ip:<ip>` **só se** a decisão Q2 aceitar o bloqueio por IP; alternativa 🟡 `ip:email` (igual ao front), o que pede mexer em `chavesLimite` e não só nos valores. Padrão proposto: **e-mail + `ip:email`**, que reproduz o front sem o risco do NAT.
3. **BFF repassa o IP:** o `authorize` já calcula o IP (último item de `x-forwarded-for`). Enviá-lo no `fetch` de `/autenticacao/login` como `x-cliente-ip`. 🟡 Se Q3 mostrar que o último item não é o IP do cliente, trocar pela regra do Traefik.
4. **Front remove** `lib/auth/loginRateLimiter.ts` e as chamadas (`reservarTentativaLogin`, `limparTentativas`, `chaveRateLimit*`) do `authorize`.
5. **(Opcional)** hoje qualquer `!res.ok` vira `null`; para mostrar "muitas tentativas" o BFF pode ler o 429 e devolver uma mensagem própria. Não é requisito.
6. Sem tabela nova: `auth.login_tentativas` e as funções já existem em produção (🟡: conferir que as colunas atendem à chave escolhida no item 2).

## 4. Passo a passo e ordem de subida

| # | Quem | Passo | Depende de |
|---|---|---|---|
| 1 | Gustavo | Conferir em produção (leitura) o corpo de `fn_login_*` e se `LOGIN_LIMITE_TENTATIVAS` está setada | — |
| 2 | Gustavo | Decidir Q1/Q2 e ajustar `chavesLimite`/`loginLimite()` na `develop` | 1 |
| 3 | Gustavo | Subir a API (`develop` → `main`). **A API vem primeiro.** Sem o IP, o limite vale só por e-mail (já melhor que hoje) | 2 |
| 4 | Front | PR no av-hub: `authorize` manda `x-cliente-ip` **e já remove** o limiter. Pode ir junto com o passo 3, mas **só depois dele em produção**: remover o limiter antes de a API estar ligada deixa o login sem limite | 3 |
| 5 | Nathan | Rodar os testes da §5 na homologação e depois em produção | 4 |

## 5. Testes de aceite

- 5 senhas erradas para o mesmo e-mail → a 6ª tentativa devolve **429** com `Retry-After` (direto na API, e pela tela do av-hub como falha de login).
- **Reiniciar a API** (redeploy no Coolify) e tentar de novo logo após estourar → **continua 429** (o contador está no banco).
- Outro e-mail, no mesmo IP → **não** é afetado (se Q2 = `ip:email`); outro IP, mesmo e-mail → **bloqueado** (chave de e-mail).
- Login correto antes do 5º erro **zera** o contador do e-mail.
- Passada a janela (15 min), o login volta.
- Com duas réplicas da API, os erros alternados entre elas somam.
- Confirmar nos logs/`auth.login_tentativas` que o IP gravado é o do cliente, não o do Traefik nem o do BFF.
- SSO (Azure) continua entrando sem ser afetado.

## 6. Rollback

- **Front:** reverter o PR do av-hub traz o `loginRateLimiter.ts` de volta (limite em memória, como hoje).
- **API:** como o limite fica fixo no código, desligar exige novo deploy (reverter o commit). 🟡 Em emergência (bloqueio indevido em massa) o DBA pode **limpar `auth.login_tentativas`** sem deploy.

## 7. Riscos

- **IP atrás do Traefik/Coolify (🟡):** o front usa o **último** item de `x-forwarded-for`. Com Traefik na frente do av-hub isso costuma ser o IP do cliente, mas se houver outro proxy (CDN, balanceador) o último item será o do proxy e **todos cairiam na mesma chave de IP**. A API tem `trust proxy = 1` (`app.js`), mas lê o IP só do cabeçalho `x-cliente-ip`, não de `req.ip`. Não conferi a configuração do Traefik.
- **Bloqueio de todos pelo mesmo IP (NAT):** ver Q2.
- **Negação de serviço por e-mail:** quem erra 5 vezes o e-mail de outra pessoa a trava por 15 min. É o comportamento de hoje também.
- **Falha do banco no limite:** `limiteExcedido` não tem `catch` próprio; se a consulta falhar, o login cai no 500 genérico. 🟡 Decidir se o login deve falhar aberto ou fechado.
- **Spoof de `x-cliente-ip`:** a rota exige a `x-api-key` (só o BFF chama), então o cabeçalho só é confiável porque a chave não é pública. Isso reforça a pergunta 13 do registro (exposição de APIs).

## 8. Perguntas em aberto

| # | Pergunta | Dono |
|---|---|---|
| Q1 | 🔴 Valores finais: manter **5 tentativas / 15 min** (do front) ou mudar? | Nathan |
| Q2 | 🔴 Bloquear por **e-mail** e **IP+e-mail** (como o front) ou por e-mail e **IP sozinho** (como a API está)? O IP sozinho pode travar a empresa inteira atrás de um NAT. | Nathan / Gustavo |
| Q3 | 🔴 Quantos proxies existem entre o cliente e o BFF (Traefik só, ou algo mais)? O IP certo é o último item de `x-forwarded-for`? | Gustavo |
| Q4 | 🔴 O limite já está ligado em produção (`LOGIN_LIMITE_TENTATIVAS`)? Falha aberta ou fechada se o banco do limite falhar? | Gustavo |
| Q5 | 🟡 Mostrar mensagem própria para 429 na tela de login (opcional). | Nathan |

## 9. Efeito no cadastro de gambiarras

Quando o front remover `loginRateLimiter.ts`, a marcação `GAMBIARRA(` de `loginRateLimiter.ts:24` some. Atualizar a contagem (item 58 do [[Registro-de-Decisoes-2026-10-07]]).
