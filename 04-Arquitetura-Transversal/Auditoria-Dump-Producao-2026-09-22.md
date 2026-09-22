---
tags: [erp-acos-vital, auditoria, banco-de-dados, contratos, status]
criado: 2026-09-22
---

# Auditoria: dump de produção (22/09) — delta contra a auditoria de 21/09

> **Esta nota é um delta, não uma auditoria completa do zero.** Parte do que [[Auditoria-Dump-Producao-2026-09-21]] já confirmou; só documenta o que mudou entre os dois dumps (14 horas de diferença).
>
> **Fora de escopo (confirmado pelo Nathan, 22/09/2026): `core_organograma` e `core_mapas`.** O dump traz esses dois schemas (organograma institucional; views de geolocalização), mas o Nathan confirmou que nenhum dos dois faz parte deste projeto — não são tratados como achado/lacuna aqui nem em [[Schema-Postgres-Multi-Dominio]].

**Fonte:** `dump-avhub_prd_db-202609221142.sql` — dump schema-only, gerado **22/09/2026 11:42** (≈28h depois do dump anterior, 21/09 07:41).

---

## 1. Resumo executivo

1. **Achado principal — o risco pendente do contrato SQL [[004-Pedidos-Compras]] foi resolvido na prática.** A auditoria de 21/09 registrava `numero_item_omie` como nullable e sem índice único, com risco real de duplicação em resync. O dump de 22/09 mostra que isso já foi corrigido: `ordem` (posição do item no array do payload) agora é a identidade oficial, com `CHECK (ordem >= 1)` e índice único `uq_pedidos_compras_itens_ordem (id_pedido_compra, ordem)`. `numero_item_omie` segue nullable, mas agora documentado explicitamente como campo complementar (cruzamento com recebimento/NF de entrada), não como chave de identidade — com seu próprio índice único parcial (`WHERE numero_item_omie IS NOT NULL`) pronto para quando o campo for confirmado contra payload real. Contrato SQL 004 atualizado (ver seção 2).
2. Nenhuma tabela nova de `ordens_compra`/`ordens_compra_itens` no dump — esperado, o contrato SQL [[007-Ordens-Compra-Estruturada]] segue proposta, não aplicado.
3. `core_estoque` continua existindo como schema reservado, **100% vazio** — sem mudança desde 21/09.
4. `core_compras`/`negocio` (código morto, achado da seção 4 de [[Auditoria-Dump-Producao-2026-09-21]]) sem mudança — `core_compras` segue sendo o schema real, `negocio` segue não existindo.
5. **Achado secundário, sem ação recomendada por ora**: o dump mistura objetos de propriedade (`OWNER TO`) entre dois roles, `avhub_prd_admin` e `avhub_tst_admin` — boa parte das tabelas mais antigas (`auth.*`, `core.*` originais, `core_vendas_faturamento` original) pertence a `avhub_tst_admin`; schemas mais novos têm mistura dos dois. Provável resíduo histórico de como os roles foram criados/renomeados, não necessariamente um problema — mas vale confirmar com o Gustavo que não é sintoma de um ambiente errado sendo exportado como "prod".

---

## 2. Contrato SQL 004 — atualização

Ver nota já aplicada diretamente no arquivo do contrato: [[004-Pedidos-Compras]]. Resumo da mudança: risco antes "não resolvido na prática" agora fechado — `ordem` é a identidade real, com índice único aplicado em produção.

---

## Ver também
- [[Auditoria-Dump-Producao-2026-09-21]] — auditoria base, esta nota é o delta
- [[004-Pedidos-Compras]]
- [[Schema-Postgres-Multi-Dominio]]
- [[Indice-Contratos]]
