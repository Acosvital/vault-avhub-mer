---
id: API-002
aliases: ["002-Material-Alias-Omie-MES"]
tags: [contrato, contrato-api, mes, estoque, rejeitado]
criado: 2026-10-14
atualizado: 2026-10-14
status: arquivado
sistemas: [mes-api]
dono: "Robert"
etapa_0b: []
fontes: ["api-pcp/prisma/migrations/20260929170000_remove_material_alias_omie", "v1 09-Contratos/02-Contratos-API/002-Material-Alias-Omie-MES.md"]
criado_original: 2026-09-17
---

# Contrato de API 002 — `material_alias_omie` (a implementar no MES/Estoque)

> **Onde atua:** MES: API

> [!info] Situação em 14/10/2026
> **Status:** `arquivado` · **Pasta:** `Arquivados` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Robert
>
> - 🟡 **Arquivado: rejeitado.** Decisão de 21/09/2026; o alias existiu no MES e foi removido. Motivo do arquivamento: contrato rejeitado, não há o que implementar.
> - ✅ A migration `20260929170000_remove_material_alias_omie` existe no `api-pcp` (`api-pcp/prisma/migrations/20260929170000_remove_material_alias_omie`) e o `material_alias_omie` não está mais nos modelos Prisma.
>
> Conferido em 14/10/2026 contra `api-pcp` 579a625, `app-pcp` 1fca8d3, `api-acos-vital` f322dcd, `omie-elt-pipeline` 0f739f0 e os dumps de 14/10. O front do av-hub (HUB b55ac55) só pelo vault v1 (❓).
> O texto original abaixo está inteiro.


> Status: **rejeitado** (histórico; decisão de 21/09/2026, código removido do MES em 29/09). Verificado em 07/10/2026. Ver [[Registro-de-Decisoes|Registro-de-Decisoes-2026-10-07]] e [[HIST-Indice-Contratos|Indice-Contratos]].

> **Atualização de 07/10/2026 — conferido no código:** coerente com a rejeição. O alias existiu no MES (`cca3803`, 22/09) e foi removido em `0ac2596` (29/09, migration com `DROP TABLE material_alias_omie`), na `develop` do `api-pcp`. O 002 não tem consumidor nem rota na `api-acos-vital`. Nada a fazer; permanece `rejeitada` (a "Fase 0 pendente... contrato 002" do `Estoque-Roadmap` é que está desatualizada).

> **Rejeitado em 21/09/2026.** Decisão do Nathan: "não quero mais tratar isso aqui, se eles quiserem eles tratam lá no Omie" — duplicata de catálogo sai do escopo deste sistema. A tela **Produtos — Prováveis Duplicatas** (só leitura, já em produção no av-hub) **continua existindo** — só o que foi cancelado é a ação de vincular/resolver a duplicata dentro do sistema (este contrato, a tarefa D4 do [[Cronograma|Cronograma-2-Meses]] e a tela p1-4b do fluxo de 127 tarefas). Mantido neste arquivo só como histórico. **30/09/2026:** o código do alias foi removido do MES (`api-pcp` `0ac2596`, 29/09), coerente com a rejeição.

**Status:** ~~proposta, não implementada~~ rejeitada. **Destinatário: time do MES/Estoque**, não o av-hub — `material_alias_omie` é entidade do Estoque (schema Prisma próprio, dentro do banco do MES), conforme já corrigido nas notas de modelagem ([[Modelo-Estoque-e-Custo-do-Lote|Estoque-Modelo-Dados]]). O av-hub não tem acesso a esse banco nem deveria — este contrato é o que falta o MES expor para que a tela de saneamento (hoje só leitura, em `00 - HUB`) ganhe a ação de vincular duplicata.

## Por quê

A tela **Produtos — Prováveis Duplicatas** (`app/(protected)/cadastros/auxiliares/produtos-duplicados/` no av-hub) já lista, por unidade, grupos de produtos do catálogo Omie com descrição parecida — candidatos a duplicata (ex.: vendedor não achou o produto e cadastrou de novo). Hoje ela é **só leitura**: não existe, em lugar nenhum, uma tabela ou endpoint para registrar "estes dois códigos são o mesmo material" (`material_alias_omie`, ver [[Modelo-Estoque-e-Custo-do-Lote|Estoque-Modelo-Dados]] do vault de modelagem). Sem esse contrato, o comprador/PCP só consegue *ver* a duplicata, não *resolver* — o saneamento continua manual (fora do sistema).

## Onde isso deveria morar

Schema do Estoque, dentro do banco do MES — **não** em `core` do av-hub. Ver correção já registrada em [[Registro-de-Decisoes|Decisoes-Chave-ERP]]/[[MES-Backend|MES-Arquitetura-Decisoes]]: o Estoque reaproveita `core.produtos`/`core.parceiros` via projeção read-only, mas dados que o Estoque *cria* (como este vínculo de saneamento) ficam no schema dele, não no av-hub.

## Contrato de request/response proposto

### `POST /material-alias-omie` (criar vínculo)

**Request:**
```json
{
  "codigo_empresa": "uuid-da-unidade",
  "codigo_produto_omie_canonico": "12345678",
  "codigo_produto_omie_duplicado": "87654321",
  "observacao": "Duplicata criada por busca sem acento — Vendedor João, 15/09/2026"
}
```

**Response (201):**
```json
{
  "id": "uuid",
  "codigo_empresa": "uuid-da-unidade",
  "codigo_produto_omie_canonico": "12345678",
  "codigo_produto_omie_duplicado": "87654321",
  "observacao": "...",
  "created_at": "2026-09-17T12:00:00Z",
  "created_by": "uuid-do-usuario"
}
```

**Regras:**
- `codigo_produto_omie_duplicado` só pode aparecer **uma vez** por `codigo_empresa` (um produto duplicado só pode apontar para UM canônico) — conflito deveria retornar 409, não sobrescrever silenciosamente.
- `codigo_produto_omie_canonico` **não pode** ser o mesmo que `codigo_produto_omie_duplicado` (validação óbvia, mas vale contrato explícito).
- Sem validação cruzada de existência em `core.produtos` (é projeção read-only, sem FK — mesmo princípio já usado no `omie-elt-pipeline` para não travar por ordem de sincronização).

### `GET /material-alias-omie?codigo_empresa=&codigo_produto_omie=`

Lista vínculos já criados — usado pela tela do av-hub para não sugerir de novo uma duplicata já resolvida (filtrar da lista de "prováveis duplicatas" qualquer código que já tenha alias registrado).

**Response:** array do mesmo shape do POST.

### `DELETE /material-alias-omie/{id}`

Desfazer um vínculo criado por engano.

## Perguntas em aberto (levar para o time do MES/Estoque)

1. **Quem chama esse endpoint?** Duas opções: (a) o av-hub chama a API do MES diretamente (precisa de autenticação cross-sistema — hoje não existe, só a `x-api-key` interna do av-hub), ou (b) o av-hub só *mostra* os grupos, e a ação de vincular acontece de fato numa tela do próprio Estoque/MES (mais alinhado com "Estoque é dono do dado que cria"). **Recomendação**: opção (b) — evita abrir uma porta de escrita cross-sistema só para isso. A tela do av-hub viraria só o "relatório de achados", e o Estoque teria sua própria tela de resolução.
2. Se optar pela (a): que mecanismo de autenticação o MES exige de um chamador externo (av-hub)? Hoje não existe integração de escrita av-hub → MES em nenhuma direção.
3. Nome dos campos (`codigo_produto_omie_canonico`/`_duplicado`) são só sugestão — alinhar com a nomenclatura que o Prisma schema do Estoque já usa ou vai usar para `material`/`material_alias_omie`.

## Ver também
- [[HIST-Indice-Contratos|Indice-Contratos]]
- [[API-001-Produtos-Parceiros-Filtro-Incremental|001-Produtos-Parceiros-Filtro-Incremental]]
