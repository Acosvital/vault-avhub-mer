---
tags: [contrato-api, mes, estoque]
status: proposta
criado: 2026-09-17
---

# Contrato de API 002 — `material_alias_omie` (a implementar no MES/Estoque)

**Status:** proposta, não implementada. **Destinatário: time do MES/Estoque**, não o av-hub — `material_alias_omie` é entidade do Estoque (schema Prisma próprio, dentro do banco do MES), conforme já corrigido no vault de modelagem (`Estoque-Modelo-Dados.md`). O av-hub não tem acesso a esse banco nem deveria — este contrato é o que falta o MES expor para que a tela de saneamento (hoje só leitura, em `00 - HUB`) ganhe a ação de vincular duplicata.

## Por quê

A tela **Produtos — Prováveis Duplicatas** (`app/(protected)/cadastros/auxiliares/produtos-duplicados/` no av-hub) já lista, por unidade, grupos de produtos do catálogo Omie com descrição parecida — candidatos a duplicata (ex.: vendedor não achou o produto e cadastrou de novo). Hoje ela é **só leitura**: não existe, em lugar nenhum, uma tabela ou endpoint para registrar "estes dois códigos são o mesmo material" (`material_alias_omie`, ver `Estoque-Modelo-Dados.md` do vault de modelagem). Sem esse contrato, o comprador/PCP só consegue *ver* a duplicata, não *resolver* — o saneamento continua manual (fora do sistema).

## Onde isso deveria morar

Schema do Estoque, dentro do banco do MES — **não** em `core` do av-hub. Ver correção já registrada em `Decisoes-Chave-ERP.md`/`MES-Arquitetura-Decisoes.md`: o Estoque reaproveita `core.produtos`/`core.parceiros` via projeção read-only, mas dados que o Estoque *cria* (como este vínculo de saneamento) ficam no schema dele, não no av-hub.

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
- [[Home]]
- [[001-Produtos-Parceiros-Filtro-Incremental]]
