---
tags: [erp-acos-vital, av-hub, portal-vendedor, investigacao, achado]
criado: 2026-09-22
---

# `usuarios_favoritos` e `clientes_inativos` — investigação dos 2 "extras" do Portal do Vendedor

> **Pergunta que esta nota fecha**, levantada em [[AV-Hub-Bugs-Catalogo]] e [[Decisoes-Chave-ERP]] ("2 extras do Portal do Vendedor podem já ter suporte de backend — investigar antes de re-priorizar como caro/precisa de contrato novo"): as rotas `usuarios_favoritos` e `clientes_inativos` já existem — mas funcionam de verdade? Testado empiricamente contra o `api-acos-vital` rodando em Docker local (mesma configuração usada em [[AV-Hub-Views-Compras-Investigacao]]) e o Postgres carregado a partir do dump de produção.
>
> **Resultado: um estava pronto para uso; o outro tinha um bug real de backend, já corrigido e testado no mesmo dia.** Os dois merecem re-priorização, mas não do mesmo jeito.

## 1. `GET /clientes_inativos` — funciona, dado real, pronto para o frontend

O texto antigo em [[AV-Hub-Portal-Vendedor-Plano]] ("cliente inativo — caro, exige N chamadas por mês") está **desatualizado**. Não é caro: é uma única chamada `GET /clientes_inativos`, paginada, contra uma view (`core_vendas_faturamento.vw_clientes_inativos`, schema correto — sem o bug de `negocio` que afeta as views de Compras).

Testado ao vivo:
```
$ curl -H "x-api-key: <chave>" "http://localhost:3001/clientes_inativos?limit=5"
HTTP 200
{"total":652,"page":1,"totalPages":131,"limit":5,"data":[
  {"cliente":"POWERCHINA INTERNATIONAL GROUP LIMITED DO BRASIL","vendedor":"RODRIGO MIRANDA","dias_sem_comprar":993,...},
  ...
]}
```

652 clientes com ≥90 dias sem comprar (parâmetro `dias_sem_comprar`, default 90), ordenados por tempo parado — exatamente a ordem de prioridade de contato que a rota documenta. A view tem 1.204 linhas no total (todos os clientes com pelo menos uma compra histórica, qualquer tempo desde a última). Filtros por vendedor, unidade, nome do cliente e paginação já funcionam.

**Conclusão: não precisa de nenhum trabalho de backend.** É "só" plugar no frontend do Portal do Vendedor — o card "Clientes inativos" pode sair da lista de "extras caros" e virar tarefa de frontend puro.

## 2. `usuarios_favoritos` — leitura funcionava, escrita estava quebrada (corrigido)

O texto antigo em [[AV-Hub-Portal-Vendedor-Plano]] ("favoritar cliente/pedido — precisa de tabela nova para sincronizar entre dispositivos") também está **desatualizado**: a tabela já existe (`auth.usuarios_favoritos`) e o endpoint é rico — `GET/POST/DELETE /usuarios/{id_usuario}/favoritos`, com resolução automática de `codigo_empresa` a partir do `referencia_id`, idempotência no POST (favoritar duas vezes não dá erro) e validação de posse no DELETE. Pelo código, parece pronto.

**Mas o `POST` está genuinamente quebrado hoje** — não é hipótese, é reprodução direta:

```
$ curl -X POST -H "x-api-key: <chave>" -H "Content-Type: application/json" \
    -d '{"tipo":"cliente","referencia_id":"11056023395"}' \
    "http://localhost:3001/usuarios/2df66780-7ffc-49a7-a289-9b705a203d66/favoritos"
HTTP 400
{"detail":"Campo obrigatório não informado: id"}
```

`GET` funciona normalmente (`200`, lista vazia — a tabela tem **0 linhas** em produção, confirmado por query direta: `SELECT count(*) FROM auth.usuarios_favoritos` → `0`. Ninguém favoritou nada ainda, provavelmente porque a feature nunca chegou a funcionar).

**Causa raiz, confirmada no código** (`src/models/usuario_favorito.js`):
```js
id: {
  type: DataTypes.UUID,
  primaryKey: true,
  // Sem defaultValue: a tabela tem DEFAULT uuidv7(), ordenável por tempo.
  // Declarar UUIDV4 aqui faria o Sequelize gerar no cliente e anular isso.
},
```

A intenção do comentário é correta (deixar o Postgres gerar o `id` via `DEFAULT uuidv7()`), mas a implementação não funciona: sem `defaultValue`, sem `allowNull: true` e sem `autoIncrement`, o Sequelize valida `id` como obrigatório **antes** de montar o INSERT — o erro acontece na camada de validação do Sequelize, a query nem chega no Postgres. `POST`/`findOrCreate` falha sempre, incondicionalmente, para qualquer usuário/tipo/referência — confirmado passando até `id` manualmente no corpo da requisição (o handler nem lê esse campo do body, então não adianta).

**✅ Corrigido em 22/09/2026** — `src/models/usuario_favorito.js` ganhou `defaultValue: literal("uuidv7()")` no campo `id`, o mesmo padrão já usado em `estoque_saldo.js`/`auxiliar_vendedor.js`/`diligenciador_vendedor.js` (models que já tinham passado pelo mesmo problema e o resolveram assim). Testado de ponta a ponta contra o container Docker local (`api-acos-vital`, dump de 22/09): `POST` cria (`201`), `POST` repetido é idempotente (`200`, mesmo registro), `GET` lista corretamente, `DELETE` remove. Commit na branch `fix/usuario-favorito-id-default` do repositório `api-acos-vital` — **ainda só local, não enviado ao remoto nem mergeado em `develop`** (decisão do Nathan, 22/09: aplicar e validar agora, decidir sobre push depois).

## 3. Conclusão — re-priorização dos 2 extras

| Extra | Status real | O que falta |
|---|---|---|
| Cliente inativo | ✅ Pronto, testado, dado real | Só frontend |
| Favoritar cliente/pedido | ✅ Bug de backend corrigido e testado em 22/09/2026 (branch local `fix/usuario-favorito-id-default`) | Push/PR/merge em `develop` (decisão pendente) + frontend |

Nenhum dos dois precisava do que o vault antigo temia ("caro"/"tabela nova"). O bug de favoritos era uma linha de configuração do model, já corrigida — falta só decidir quando enviar ao remoto e plugar o frontend nos dois.

## Ver também
- [[AV-Hub-Portal-Vendedor-Plano]] — texto desatualizado corrigido
- [[AV-Hub-Bugs-Catalogo]]
- [[Decisoes-Chave-ERP]]
- [[AV-Hub-Views-Compras-Investigacao]] — mesma metodologia de investigação empírica
