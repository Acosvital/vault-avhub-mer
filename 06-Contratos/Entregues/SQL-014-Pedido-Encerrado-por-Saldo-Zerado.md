---
id: SQL-014
aliases: ["Contrato SQL 014", "014-Pedido-Encerrado-por-Saldo-Zerado"]
tags: [contrato, contrato-sql, dba, pedidos, vendas, prazo, situacao]
criado: 2026-10-19
atualizado: 2026-10-21
status: aplicado-em-producao
sistemas: [hub-banco]
dono: "Gustavo (DBA)"
etapa_0b: []
fontes: ["Dump Avhub (Esqueleto).sql: fn_pedidos_venda (:7373), fn_pedidos_venda_linhas (:7534), fn_pedido_dias_para_prazo (:7282), fn_pedido_situacao_parcial (:7340), pedidos_vendas (:2328), pedidos_vendas_status_historico (:18495)", "omie-elt-pipeline/src/omie/resources/pedidosVendas.ts:131 (valor_total_pedido)", "LOG-08-Itens-por-Parcela-Pedidos (pedido 27645)", "av-hub/components/Pedidos/helpers.ts"]
criado_original: 2026-10-19
---

# Contrato SQL 014 — Pedido encerrado por saldo zerado ("Faturado, encerrado") e "encerrado em atraso"

> **Onde atua:** av-hub: banco

> [!info] Situação em 21/10/2026
> **Status:** `aplicado-em-producao` · **Pasta:** `Entregues` · **Nós do 0b:** — (fora do fluxo de Atividades) · **Dono:** Gustavo (DBA)
>
> - ✅ **Banco e API:** o Gustavo implementou (migrations 014 e 014b, `api-acos-vital` commits `2d5ff24` e `d989de2`). A chave `PEDIDOS_ENCERRADO_POR_SALDO` foi **removida** a pedido do Nathan: a regra vale sempre. `GET /pedidos_venda` devolve `saldo_zerado`, `encerrado_por_saldo`, `data_encerramento_calculada`, `encerrado_em_atraso`, `dias_atraso_no_encerramento`; `situacao = 'faturado_encerrado'` (aceita no filtro); prazo `null` e fora de atrasados/atenção; `etapa_atual` é a última do fluxo; o resumo traz `faturados_encerrados` e `encerrados_em_atraso`.
> - ✅ **Atraso pela previsão mais antiga** (Q7 revisada, 21/10): 27762 vem com 10 dias e 23966 com 1 dia.
> - ✅ **Front** (av-hub, PR #230 e #233 em `develop`): pílula "Faturado, encerrado", "Em atraso · N dias" na coluna Previsão, alerta amarelo na página do pedido, etapa final no Andamento e filtro de situação. Vale para Meus Pedidos, Pedidos da Equipe e Pedidos do PCP.
> - ✅ **Conferido em 21/10/2026** no preview (Portal do PCP, vendedora SARALIGIA SIMÕES, 2026 inteiro): 145 pedidos `encerrado_por_saldo`, todos com a situação nova, nenhum com prazo aberto nem com a etapa antiga; resumo com 181 faturados encerrados e 3 em atraso.
> - ✅ **Produção:** o Nathan confirmou em 21/10/2026 que foi aplicado em produção (informação dele; não conferi no banco de produção).
> - ❓ O script da seção "Script proposto" abaixo era a proposta de 19/10, não o SQL aplicado; o que vale é o das migrations 014 e 014b (não lidas aqui).
> - 📝 Perguntas G1 a G4 ao Gustavo: não respondidas por escrito; a implementação entregue as resolveu na prática (campo calculado dentro de `fn_pedidos_venda`, sem chave).
>
> Selos em [[Regras-do-Vault]].

> [!abstract] Resumo em linguagem natural
> **O que é:** Pedido cujo valor foi todo para parciais ficava "em andamento" e, passada a previsão, atrasado para sempre. Agora aparece como "Faturado, encerrado", com "Em atraso · N dias" quando passou do prazo.
> **Quem é afetado:** Vendedores e PCP (Planejamento e Controle da Produção): Meus Pedidos, Pedidos da Equipe e Pedidos do PCP.
> **Situação:** ✅ Banco, API e front entregues. ✅ Nathan confirmou produção em 21/10, sem conferência no banco. 🟡 Vale o SQL das migrations 014 e 014b, não o script do texto.

## Por quê

No Omie existe a ação de encerrar o pedido, mas ninguém a executa. Pedido terminado continua "em andamento" no hub e, passada a previsão, aparece como atrasado para sempre.

Causa nos dados: `fn_pedido_dias_para_prazo` só zera o prazo quando **a própria parcial** tem a flag faturado, cancelado, denegado, devolvido ou encerrado. O pedido original (`sequencial = 0`) cujo valor foi todo transferido para parciais não tem nenhuma dessas flags. Fica com `data_previsao` aberta, situação `aberto`/`autorizado` e prazo `atrasado`. Isso também infla `precisa_atencao`, o contador de atrasados do resumo e o filtro de prazo.

## O que significa "pedido original zerado" nos dados

- **Original** = linha de `core_vendas_faturamento.pedidos_vendas` com `COALESCE(sequencial, 0) = 0`. As parciais têm `sequencial` 1, 2… e cada uma é um pedido próprio no Omie (`codigo_pedido_omie` próprio).
- **Valor** do original = `pedidos_vendas.valor_total_pedido` (vem do Omie `total_pedido.valor_total_pedido`, `pedidosVendas.ts:131`). Na API é o `total_pedido_venda` da parcial 0.
- **Evidência (LOG-08, pedido 27645):** original R$ 1.226.900,00 + parciais 193.200,00 + 177.744,00 + 112.056,00 + 187.500,00 = R$ 1.897.400,00 = soma dos itens do pedido. A cada faturamento parcial o valor sai do original e vai para a parcial. Quando tudo foi para parciais, o original fica com valor 0.
- Não existe campo de "quantidade pendente" por item: `produto_vendas` só tem `quantidade`, `valor_total` e o pedido de origem. O saldo é o **valor** do sequencial 0.
- Cuidado: valor 0 no original também ocorre em **rascunho sem preço**. A regra abaixo exige que o pedido tenha valor (soma das parciais) maior que 0.

## O que pedir ao banco

### 1) Campos novos em `fn_pedidos_venda` (e nas parciais de `fn_pedidos_venda_linhas`)

| campo | tipo | regra |
|---|---|---|
| `saldo_zerado` | `boolean` | o original (`sequencial` 0 ou nulo, não excluído) tem `total_pedido_venda = 0` **e** `valor_total` do pedido > 0 **e** existe ao menos uma parcial (`sequencial` > 0) |
| `encerrado_por_saldo` | `boolean` | `saldo_zerado` **e** nenhuma parcial com valor > 0 está aberta (toda parcial com valor está faturada; cancelada/devolvida/denegada não contam como aberta, Q2) |
| `data_encerramento_calculada` | `text` (AAAA-MM-DD, como o resto) | `max(data_faturamento)` das parciais faturadas. Só preenchida quando `encerrado_por_saldo` |
| `encerrado_em_atraso` | `boolean` | `encerrado_por_saldo` **e** `data_encerramento_calculada` > a **previsão mais antiga** (Q7, revisada em 21/10/2026) |
| `dias_atraso_no_encerramento` | `integer` | dias entre a previsão de referência e `data_encerramento_calculada`, só quando `encerrado_em_atraso` |

**Caso extra (Q4):** `encerrado_por_saldo` também é `true` quando o original tem a flag `faturado` e não há parcial aberta com valor (pedido faturado inteiro sem dividir). Nesse caso `data_encerramento_calculada` é a `data_faturamento` do original.

### 2) Situação nova

Quando `encerrado_por_saldo`, `situacao` do pedido passa a ser `faturado_encerrado` (novo valor de `SituacaoPedido`; filtro `p_situacao = 'faturado_encerrado'`). Precedência: `cancelado`, `devolvido`, `devolucao_parcial` e `denegado` continuam acima (decisão de borda Q2).

### 3) Prazo

Pedido com `encerrado_por_saldo` tem `prazo` e `dias_para_prazo` **NULL** (fechado) e `precisa_atencao = false`. Sai dos contadores `atrasados`, `vence_hoje`, `vai_vencer` e `em_dia` de `fn_pedidos_venda_resumo`. Entra em `faturados` (Q10). `etapa_atual` fica na última etapa, como já faz quando não há parcial aberta.

### 4) Propagação

Rota `GET /pedidos_venda` e `GET /pedidos_venda/{pedido}` devolvem os campos novos; `GET /pedidos_venda/resumo` ganha `faturados_encerrados` e `encerrados_em_atraso` (contagens). Atualizar o swagger de `pedidos_venda`.

## Script proposto (não testado)

Ideia: calcular na CTE `agg` de `fn_pedidos_venda`, sem mudar `fn_pedidos_venda_linhas`.

```sql
-- dentro da CTE agg (por codigo_empresa, pedido_venda):
bool_or(l.eh_cabecalho AND COALESCE(l.total_pedido_venda, 0) = 0)            AS original_zerado,
count(*) FILTER (WHERE NOT l.eh_cabecalho)                                    AS qtd_parciais_reais,
count(*) FILTER (WHERE NOT l.eh_cabecalho
                   AND COALESCE(l.total_pedido_venda, 0) > 0
                   AND NOT COALESCE(l.faturado, false)
                   AND NOT COALESCE(l.cancelado, false)
                   AND NOT COALESCE(l.denegado, false)
                   AND NOT COALESCE(l.devolvido, false))                      AS parciais_abertas_com_valor,
max(l.data_faturamento) FILTER (WHERE l.faturado)                             AS ultimo_faturamento

-- depois, na CTE ped:
(a.original_zerado AND a.valor_total > 0 AND a.qtd_parciais_reais > 0
   AND a.parciais_abertas_com_valor = 0)                                      AS encerrado_por_saldo
```

Depois, `situacao`, `prazo`, `dias_para_prazo` e `precisa_atencao` consultam `encerrado_por_saldo` primeiro. `fn_pedidos_venda_resumo` já chama `fn_pedidos_venda`, então herda.

Ponto de atenção: `l.eh_cabecalho` é o `sequencial` 0 ou nulo; o cabeçalho excluído não entra (`deleted_at IS NULL` já está no filtro).

## Sem chave: a regra vale sempre (decisão do Nathan, 21/10/2026)

A API entregue (`api-acos-vital` 2d5ff24) só aplica a regra com `PEDIDOS_ENCERRADO_POR_SALDO=true` (padrão desligada). O Nathan decidiu que **não quer essa chave**: a regra vale sempre.

Pedido ao Gustavo:

1. Remover `PEDIDOS_ENCERRADO_POR_SALDO`, `encerrarPorSaldoLigado()` e `argEncerrarPorSaldo()` de `src/utils/pedidoEncerradoPorSaldo.js`; passar `p_encerrar_por_saldo => true` fixo (ou tornar `true` o padrão da função no banco e tirar o argumento).
2. `faturado_encerrado` sempre aceito em `situacao` (rota e swagger); tirar as frases "com PEDIDOS_ENCERRADO_POR_SALDO ligada" do swagger.
3. Ajustar o teste `test/unit/pedidoEncerradoPorSaldo.test.js`.
4. Conferir no preview: o pedido 27762 (original 0, parciais 1 e 2 faturadas) passa a vir com `situacao = 'faturado_encerrado'` e `prazo = null`.

Evidência de 21/10/2026 (preview, PCP): os campos novos já vinham na resposta e `faturados_encerrados` = 181, mas nenhum pedido vinha com `situacao = 'faturado_encerrado'` e os de original zerado seguiam "atrasado".

## Revisão da regra de atraso (21/10/2026)

Pedido ao Gustavo: em `encerrado_em_atraso` e `dias_atraso_no_encerramento`, trocar a previsão de referência da "linha faturada por último" para **`MIN(data_previsao)` entre todas as linhas do pedido** (original e parciais, não excluídas, com previsão preenchida). Ajustar o swagger (`encerrado_em_atraso`, `dias_atraso_no_encerramento`) e o teste.

Casos para conferir (dados do preview de 21/10/2026):

| pedido | previsão mais antiga | último faturamento | esperado |
|---|---|---|---|
| 27762 | 18/09/2026 (original) | 28/09/2026 | `encerrado_em_atraso = true`, 10 dias |
| 23966 | 14/10/2026 (original) | 15/10/2026 | `encerrado_em_atraso = true`, 1 dia |

Hoje a API devolve `false` nos dois, porque compara com a previsão da parcela (28/09 e 15/10).

## Etapa do pedido encerrado (21/10/2026)

Com a regra ligada, o pedido 27762 (encerrado) ainda vem com `etapa_atual_descricao = 'Liberado Compras'` e a página mostra "Etapa 2 de 6", porque `etapa_atual` é a primeira parcial não faturada e o original zerado (valor 0, sem flag `faturado`) conta como aberto.

Pedido ao Gustavo: quando `encerrado_por_saldo`, `etapa_atual` e `etapa_atual_descricao` devem ser os da **última etapa do fluxo** (a da última parcial faturada, "Faturado"/"Despachado"), e a parcial 0 de valor 0 não deve contar como "não faturada" nessa escolha. Conferir no 27762 e no 23966.

## Dá para saber a data em que zerou?

Sim, de forma aproximada e sem tabela nova: `max(data_faturamento)` das parciais faturadas. `pedidos_vendas_status_historico` guarda só mudanças de `situacao` e `data_previsao` (com `detectado_em`); **não** guarda mudança de valor, então não dá o instante exato em que o original zerou. Se o Nathan quiser o instante exato, o caminho é gravar a mudança de `valor_total_pedido` do original no sync (fora do escopo desta proposta).

## Consulta de validação (rodar antes de implementar)

```sql
SELECT p0.codigo_empresa, p0.numero_pedido, p0.valor_total_pedido AS original,
       (SELECT count(*) FROM core_vendas_faturamento.pedidos_vendas p
         WHERE p.codigo_empresa = p0.codigo_empresa AND p.numero_pedido = p0.numero_pedido
           AND COALESCE(p.sequencial, 0) > 0 AND p.deleted_at IS NULL)          AS qtd_parciais,
       (SELECT bool_and(p.faturado) FROM core_vendas_faturamento.pedidos_vendas p
         WHERE p.codigo_empresa = p0.codigo_empresa AND p.numero_pedido = p0.numero_pedido
           AND COALESCE(p.sequencial, 0) > 0 AND p.deleted_at IS NULL)          AS todas_faturadas,
       p0.faturado, p0.encerrado, p0.data_previsao
  FROM core_vendas_faturamento.pedidos_vendas p0
 WHERE COALESCE(p0.sequencial, 0) = 0 AND p0.deleted_at IS NULL
   AND p0.valor_total_pedido = 0;
```

O que conferir: (a) quantos têm `qtd_parciais = 0` (rascunho, não entram); (b) quantos têm `todas_faturadas = false` (parcial aberta com valor, não entram); (c) o pedido 27645 e o 27787 do LOG-08 aparecem como esperado.

## O que muda na tela (Nathan, depois que o banco entregar)

- Rótulo `Faturado, encerrado` (tom `success`) no lugar de "Em aberto"/"Autorizado" nas três listas e na página do pedido.
- Se `encerrado_em_atraso`: o mesmo rótulo com a marca `Encerrado em atraso · N dias` (tom `warning`), nunca tratado como pontual.
- Coluna Previsão: pedido encerrado mostra a data de encerramento no lugar de "N dias de atraso".
- Filtro de situação ganha "Faturado, encerrado"; KPIs de atrasados e atenção deixam de contar esses pedidos.
- Arquivos: `components/Pedidos/helpers.ts`, `PedidosTable.tsx`, `PedidoDetalhe.tsx`, `lib/domain/pedidos-venda.ts`.

## Como conferir que ficou certo

1. Pedido 27645 (empresa `759979bd-2b2d-41f2-b1b7-db6fae89ee59`): enquanto as parciais 3 e 4 estiverem em "Separar Estoque" e o original com valor, `encerrado_por_saldo = false`.
2. Pedido com original 0, ao menos uma parcial e todas faturadas: `encerrado_por_saldo = true`, `situacao = 'faturado_encerrado'`, `prazo` NULL, fora de `atrasados` no resumo.
3. Mesmo pedido com última NF depois da previsão: `encerrado_em_atraso = true` e `dias_atraso_no_encerramento` correto.
4. Pedido em rascunho (valor 0, sem parcial): continua como hoje.
5. Item adicionado ao original depois: o valor volta a ser > 0 e o pedido deixa de ser encerrado sozinho (cálculo ao vivo).
6. `fn_pedidos_venda_resumo`: `pedidos` total não muda; só mudam a distribuição de prazo e `faturados`.

## Perguntas em aberto

Decididas pelo **Nathan** em 19/10/2026 (aceitou as sugestões):

1. **Q1.** Exige ao menos uma parcial; original 0 sem parcial (rascunho) não é encerrado.
2. **Q2.** Entra como encerrado se nenhuma parcial com valor está aberta. `cancelado`, `devolvido`, `devolucao_parcial` e `denegado` seguem com a situação própria, por precedência.
3. **Q4.** Pedido faturado inteiro sem dividir (original com a flag `faturado`) também vira "Faturado, encerrado". Sem nota de atraso quando a NF saiu até a previsão.
4. **Q5.** Pedido manual (`MAN-…`) segue a mesma regra dos demais; sem tratamento à parte.
5. **Q7 (revisada em 21/10/2026).** A previsão de referência é a **mais antiga** entre o original (`sequencial` 0) e as parciais, vigente de cada uma (`MIN(data_previsao)` das linhas do pedido). "Encerrado em atraso" = o último faturamento (`data_encerramento_calculada`) é depois dessa data; `dias_atraso_no_encerramento` = diferença em dias. Motivo: a parcial é só o desdobramento do original, e a previsão da parcial costuma ser remarcada para o dia em que fatura, o que escondia o atraso. Antes valia a previsão da parcial faturada por último.
6. **Q8.** Pedido com a flag `encerrado` do Omie mantém o rótulo "Encerrado"; "Faturado, encerrado" é só o calculado por saldo.
7. **Q9.** As três telas (Meus Pedidos, Pedidos da Equipe, Pedidos do PCP) mudam juntas.
8. **Q10.** Pedido encerrado sai de "atrasados"/"atenção" e entra em "Faturados".

Para o **Gustavo**:

1. **G1.** A consulta de validação confirma que o original vai a 0 quando tudo é faturado em parcelas? Quantos pedidos caem em cada caso (a, b, c)?
2. **G2.** O sync atualiza o `valor_total_pedido` do original a cada faturamento parcial, ou só no próximo ciclo do pipeline? (muda o atraso entre faturar e aparecer como encerrado.)
3. **G3.** Custo: a agregação extra em `fn_pedidos_venda` pesa para "Todo o período" da equipe?
4. **G4.** Prefere campo calculado na função (proposto) ou uma view/coluna materializada?
