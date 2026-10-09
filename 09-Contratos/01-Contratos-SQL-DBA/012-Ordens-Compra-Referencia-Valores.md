---
tags: [contrato-sql, dba, integracao-av-hub-mes, compras, custo, api004]
status: para-implementar
criado: 2026-10-09
atualizado: 2026-10-09
---

# Contrato SQL 012 — valores da OC na `vw_ordens_compra_referencia_mes` e na marca `alterado_em`

> **Status: `para-implementar` (Gustavo, DBA).** Estende a migration `api004` do [[011-Ordens-Compra-Referencia-MES]], que o DBA informou em 09/10/2026 ter **entregue e aplicado**. Este contrato só **acrescenta** colunas e eventos: nada que a rota ou o MES leem hoje muda de nome, tipo ou significado. Contrato de API que o consome: [[007-Referencia-OC-Valores-no-MES]]. Desenho de negócio: [[Estoque-Custo-do-Lote]].

## Por quê

O lote recebido precisa nascer com custo (e Compras/Orçamento precisam do valor real da compra no MES). Os valores já existem no hub (`ordens_compra_itens.valor_unitario`, `desconto`, `valor_desconto`, `valor_total_item`; `ordens_compra.moeda`, `cotacao_moeda`, `cotacao_data`, `cotacao_origem`, `valor_frete`, `valor_seguro`, conferidos em `ordens_compra*.model.js`, `api-acos-vital` `dee35b0`), mas a view os omite de propósito. Passam a sair.

## 1. Colunas novas

### No item (dentro de `itens`, ao lado de `quantidade`)

| Campo no JSON do item | Origem | Tipo | Regra |
|---|---|---|---|
| `valor_unitario` | `ordens_compra_itens.valor_unitario` | `numeric(15,4)` | na **moeda da OC**, antes do desconto |
| `desconto_pct` | `ordens_compra_itens.desconto` | `numeric(6,3)` | percentual (ex.: `5.000` = 5%); 0 quando sem desconto |
| `valor_desconto` | `ordens_compra_itens.valor_desconto` | `numeric(15,2)` | em valor, na moeda da OC |
| `valor_total_item` | `ordens_compra_itens.valor_total_item` | `numeric(15,2)` | na moeda da OC |

### Na OC (nível da `data[]`)

| Campo | Origem | Tipo | Regra |
|---|---|---|---|
| `moeda` | `ordens_compra.moeda` | `varchar(3)` | `BRL`, `USD`, `EUR`… |
| `cotacao_moeda` | `ordens_compra.cotacao_moeda` | `numeric(15,6)`, nulo | nulo em BRL |
| `cotacao_data` | `ordens_compra.cotacao_data` | `date`, nulo | dia da PTAX usada (nulo se digitada) |
| `cotacao_origem` | `ordens_compra.cotacao_origem` | `varchar(10)`, nulo | `ptax` ou `manual` (decisão 46 do Registro: a API reclassifica para `manual` ao receber outra cotação) |
| `valor_frete` | `ordens_compra.valor_frete` | `numeric(15,2)`, nulo | na moeda da OC |
| `valor_seguro` | `ordens_compra.valor_seguro` | `numeric(15,2)`, nulo | idem |

🟡 Os nomes exatos das colunas em `ordens_compra*` vêm dos models Sequelize; o DBA confirma no banco (checklist abaixo). Imposto por item (ICMS a recuperar, IPI, ST) **não existe** na OC e **não entra neste contrato**: ver "Fora deste contrato".

## 2. A marca `alterado_em` passa a reagir a preço

Hoje o swagger do 004 diz que "mudanças que não aparecem aqui (preço…) não fazem a OC voltar". Com os valores na resposta, a trigger de `ordens_compra_referencia_mes` precisa também marcar a OC quando mudar, **em OC aprovada** (ou cancelada depois de aprovada, as únicas que a view mostra):

- `ordens_compra_itens`: `valor_unitario`, `desconto`, `valor_desconto`, `valor_total_item`;
- `ordens_compra`: `moeda`, `cotacao_moeda`, `cotacao_data`, `cotacao_origem`, `valor_frete`, `valor_seguro`.

Mudança de preço em OC **rascunho ou aguardando aprovação** não faz a OC aparecer (a regra de quais OCs entram não muda).

## 3. Compatibilidade

- Somente `ADD`/`CREATE OR REPLACE VIEW` com as colunas antigas **na mesma ordem e com os mesmos tipos**; as novas no fim.
- A rota hoje usa lista fixa de colunas (`COLUNAS`, `route.js:39-42`): a coluna nova só sai quando o contrato de API 007 mudar a rota. O DBA pode aplicar este contrato **antes** da rota sem quebrar nada.
- Sem recarga: a trigger só marca OCs a partir da aplicação; para o MES receber os valores de OCs já aprovadas, rodar uma vez `UPDATE ordens_compra_referencia_mes SET alterado_em = now()` para as OCs aprovadas dos últimos N dias (🔴 N: Compras/Robert dizem, só para OC com recebimento pendente).

## Fora deste contrato

- **Imposto por item:** fonte a definir (cadastro do produto, NF de entrada do Omie ou digitação em Compras). Enquanto não houver, o custo líquido do lote sai sem ICMS a recuperar, IPI e ST ([[Estoque-Custo-do-Lote]]).
- **Frete rateado por item:** o MES rateia `valor_frete` pelo valor ou peso dos itens, se um dia entrar no custo (hoje fica fora, decisão 3).

## Checklist do DBA

- [ ] `\d+ core_vendas_faturamento.ordens_compra_itens` e `ordens_compra`: nomes e tipos reais das colunas da seção 1.
- [ ] Definição atual da view e da trigger (`pg_get_viewdef`, `pg_get_functiondef`) para o diff, e versionar o script da `api004` junto (pendente no [[011-Ordens-Compra-Referencia-MES]]).
- [ ] Aplicar a seção 2 e testar: mudar `valor_unitario` de um item de OC aprovada e ver `alterado_em` avançar; mudar numa OC rascunho e ver que nada aparece.
- [ ] Avisar o Gustavo/Robert da data de aplicação para ligar a rota (contrato 007).

## Aceite

1. `SELECT valor_unitario, desconto_pct, moeda, cotacao_moeda FROM …vw_ordens_compra_referencia_mes` (ou o `jsonb` equivalente) devolve os valores de uma OC aprovada em USD com cotação PTAX.
2. Alterar o preço de um item de OC aprovada faz a OC reaparecer em `alterado_desde` anterior.
3. As colunas antigas continuam idênticas (diff da view só acrescenta).

## Ver também
[[011-Ordens-Compra-Referencia-MES]] · [[007-Ordens-Compra-Estruturada]] · [[007-Referencia-OC-Valores-no-MES]] · [[Estoque-Custo-do-Lote]]
