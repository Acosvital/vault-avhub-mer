---
tags: [erp-acos-vital, av-hub, bugs, qualidade-de-dados]
criado: 2026-09-16
atualizado: 2026-09-16
---

# av-hub — Catálogo de Bugs/Pendências Reais de Backend

Consolidado dos contratos técnicos (`docs/*.md`) do av-hub **e agora verificado direto no código-fonte real de `api-acos-vital`** (repositório completo recebido e lido em detalhe). A maioria dos itens antes "pendentes" já foi corrigida — o processo de contrato escrito → correção → reteste está funcionando bem nesta equipe.

## Resolvidos ✅ (confirmado por leitura direta do código-fonte, não só por doc)

| Item | O que era | Confirmação no código |
|---|---|---|
| `POST/PUT/DELETE /blacklist_pedidos` | `codigo_empresa` ausente do model e da whitelist de campos | `src/models/blacklist_pedido.js` já declara `codigo_empresa` (PK composta com `numero_pedido`); rotas usam `findOne` por chave composta, não mais `findByPk` só por número |
| Filtro de nome em `GET /funcionarios` | `nome_completo` ignorado | `buildWhere` aplica `Op.iLike`; também ganhou filtros novos por `email`/`cpf` |
| Filtros de busca em `GET /parceiros` | `nome_fantasia`/`cpf_cnpj` comparavam errado; `razao_social`/`cidade` eram ignorados | Todos os 4 agora usam `Op.iLike` (exceto `estado`, que continua exato — é `CHAR(2)`) |
| Ordenação em `GET /vendedores` | `sort`/`order` sem efeito | Allowlist real (`VENDEDOR_SORTABLE`, 14 colunas) + `fallback`/`tiebreak` para paginação estável; ganhou de brinde `codigo_vendedor_omie` como filtro `ILIKE` e `id_funcionario_in` (lista, até 200 UUIDs) |
| `cor_unidade`/`foto_url` em `core.unidades` | Não existiam | Ambas presentes em `src/models/unidade.js` — `foto_url` é key de objeto (S3/SeaweedFS), não URL, deliberadamente sem validação de formato |
| PK de `vendedores` colidia entre empresas | PK era `codigo_vendedor_omie` (não único entre unidades) | Trocada para `id` uuid — corrigido, comentário no model documenta o bug antigo |
| Meta Individual 7-18× maior | Meta global dividida 2× por unidade | Corrigido (contrato específico) |

## Pendentes reais remanescentes

| Item | Status |
|---|---|
| Backfill de `vendedores.id_funcionario` | ✅ **Já rodou (confirmado 16/09)** — nota anterior ("não rodou ainda", testado ao vivo em 03/09) está desatualizada. |
| Paginação por pedido (não por linha crua) em `/vendas_planilha` | Ainda não implementado — só ordenação foi endereçada, não a paginação por família |
| Chave composta em `PUT`/`DELETE /blacklist_pedidos` | Resolvido junto com o bug de criação (ver acima) |
| `fechamento_manual` | Tabela/rota confirmada existente no inventário de rotas do backend real (`fechamento_manual` está na lista de 65 arquivos de rota) |
| Relação produto↔fornecedor N:N | Descoberta importante: **já existem views de Compras no backend** (`vw_catalogo_de_produtos`, `vw_fornecedores_com_produtos`, `vw_historico_precos`, `vw_todos_os_fornecedores`) — o módulo Orçamento do frontend rodar sobre JSON mockado pode ser só falta de integração, não falta de dado real. Vale investigar essas views antes de assumir que "não existe API própria de compras ainda". |

## ⚠️ Achados que exigem reavaliar suposições anteriores da Portal do Vendedor

Rotas já existem no backend para 2 "extras" que o plano do Portal do Vendedor (ver [[AV-Hub-Portal-Vendedor-Plano]]) tratava como "caro"/"parcial"/"precisa de tabela nova":
- **`usuarios_favoritos`** — rota já existe; "favoritar cliente/pedido" (extra 8.10) pode não precisar de tabela nova.
- **`clientes_inativos`** — rota já existe; "cliente inativo" (extra 8.9), antes avaliado como caro (N chamadas por mês), pode já ter endpoint dedicado.

Essas 2 não foram exploradas em profundidade ainda (não fazia parte do escopo desta rodada de análise) — mas a mera existência da rota já muda o "custo estimado" dessas features de "caro/precisa contrato novo" para "possivelmente só falta plugar no frontend". Vale investigar antes de re-priorizar o roadmap do Portal do Vendedor.

> ⚠️ **Correção (16/09):** `pedidos_vendas_status_historico` **não** entra nessa lista de "baixo custo, já existe" — confirmado que é o **histórico vindo do Omie via pipeline** (polling, granularidade grossa dos status do Omie), não um log de transições internas. Não satisfaz o requisito de "histórico de status do pedido" no nível granular que o fluxo detalhado item a item exige (ver [[Fluxo-Detalhado-Pedido-Item]]) — precisamos de um histórico muito mais robusto, mostrando toda transição real (PCP, OS/OP, qualidade), que essa tabela não cobre.

## Ver também
- [[AV-Hub-Vendas-Reconciliacao]]
- [[AV-Hub-Arquitetura-BFF]]
- [[AV-Hub-Portal-Vendedor-Plano]]
- [[AV-Hub-Comissao-Modulo]]
- [[Decisoes-Chave-ERP]]
