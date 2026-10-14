---
id: LOG-47
aliases: ["Contrato 47", "47-Custo-Real-por-Item-no-Hub"]
tags: [contrato, contrato-logica, av-hub, comissao, compras, orcamento, custo]
criado: 2026-10-14
atualizado: 2026-10-14
status: parcial
dono: "Gustavo (DBA)"
etapa_0b: [E3, R4]
fontes: ["api-acos-vital/src/schemas/core_vendas_faturamento/tables/itens_pedido_custo/itens_pedido_custo.job.js:14,78", "api-acos-vital/src/schemas/core_vendas_faturamento/tables/itens_pedido_custo/itens_pedido_custo.route.js:66", "api-acos-vital/src/schemas/core_vendas_faturamento/index.js:186", "api-acos-vital/src/app.js:209"]
criado_original: 2026-10-09
---

# Contrato 47 — Custo real por item no av-hub: simulador (etapa 2), comissão por faturamento (etapa 3), Compras e Orçamento

> [!info] Situação em 14/10/2026
> **Status:** `parcial` · **Pasta:** `Ativos` · **Nós do 0b:** E3, R4 · **Dono:** Gustavo (DBA)
>
> - ✅ **§1 Job de leitura:** `itens_pedido_custo.job.js` chama `GET {MES_API_URL}/itens/custo` por unidade ativa (`:78`), grava com `fn_itens_pedido_custo_gravar` (migrations 047 e 047b; item = produto, `80581d0` e `f322dcd`); rota `GET /itens_pedido_custo` (`itens_pedido_custo.route.js:66`, permissão própria, `403 USUARIO_NAO_INFORMADO` sem usuário); iniciado em `app.js:209`.
> - 🔴 **O MES não publica `GET /itens/custo`** (ver [[API-008-Custo-do-Lote-no-MES]], §5): o job recebe 404 "ainda não publicado", avisa uma vez e não grava nada. A tabela `itens_pedido_custo` existe mas está sem dados reais do MES.
> - 🔴 **§2 Simulador pré-preenchido, §3 comissão por faturamento, §4 Compras e Orçamento:** consumo do custo nas telas, sem código conferido (HUB fora da pasta de repos; ❓). Ciclo 2, dono Comercial & Suprimentos.
> - O custo do item = média dos lotes reservados (nó E3 do [[00-Fluxo-Mestre-0b]]).
>
> Conferido em 14/10/2026 contra `api-pcp` 579a625, `app-pcp` 1fca8d3, `api-acos-vital` f322dcd, `omie-elt-pipeline` 0f739f0 e os dumps de 14/10. O front do av-hub (HUB b55ac55) só pelo vault v1 (❓).
> O texto original abaixo está inteiro; os trechos que o estado atual contradiz têm nota de rodapé.


> **(atualizado em 13/10/2026) CONFERIDO NO DUMP DO BANCO DE TESTE** (`Dump avhub teste (Completo).sql`; só li DDL, `auth.rotas_telas`, `auth.telas`, `auth.perfis` e `auth.permissoes`; **não li dados de clientes ou usuários**). **Banco do §1 completo:** `itens_pedido_custo`, `itens_pedido_custo_cursor`, `fn_itens_pedido_custo_gravar` e `fn_itens_pedido_custo_do_pedido` ✅; tela `custo-itens` em `auth.telas` ✅; rota `GET /itens_pedido_custo` em `auth.rotas_telas` com `escopo_vendedor = true` ("perfil com escopo `todos` vê qualquer pedido; os demais só os dos seus vendedores") ✅. 🔴 **Nenhum perfil tem permissão em `custo-itens`:** ninguém lê o custo com login. Decidir quem recebe (o contrato diz que o vendedor **não** recebe). Mesmo achado do 48: como só "Gerencia PCP" é `todos`, o perfil Gerência (`vinculados`) veria só os pedidos dos vendedores vinculados a ele.
>
> **(atualizado em 13/10/2026) CONFERIDO NA `api-test` (só GET).** `GET /itens_pedido_custo` **existe** e responde `403 USUARIO_NAO_INFORMADO` sem usuário ("custo por item é dado sensível"), como o contrato manda. **Não deu para ver a tabela nem se o job já gravou algo**: a rota exige um usuário com a tela `custo-itens`, e a conferência foi com a chave de serviço. O `GET /itens/custo` do MES não foi testado.
>
> **(atualizado em 13/10/2026) §1 ENTREGUE PELO DBA (relato do Nathan); o resto segue como estava.** Commit `80581d0` (13/10) na `develop` da `api-acos-vital` (**fora da `main`**): job `itens_pedido_custo.job.js` (por unidade, cursor `alterado_em` + `id`, `pg_try_advisory_xact_lock`, grava por `fn_itens_pedido_custo_gravar`, "migration 047") e rota `GET /itens_pedido_custo?codigo_empresa=&numero_pedido=`, que **exige sempre** a permissão `custo-itens:pode_visualizar` (também sem token, por `id_usuario_sessao`), porque custo é dado sensível. O mesmo commit acrescentou os valores da OC à rota `/ordens-compra/referencia` ([[API-007-Referencia-OC-Valores-no-MES|007-Referencia-OC-Valores-no-MES]]). Conferido **só no código**. 🔴 **Segue aberto:** (1) o DDL da migration 047 (tabela `itens_pedido_custo`, função, cursor, tela `custo-itens` em `auth.rotas_telas`) não está no repositório: confirmar com o Gustavo que foi aplicado; (2) o **MES** precisa servir `GET /itens/custo` ([[API-008-Custo-do-Lote-no-MES|008-Custo-do-Lote-no-MES]], Robert), senão o job não anda; (3) **§2 simulador, §3 comissão por faturamento e §4 Compras e Orçamento** (front/Comercial & Suprimentos) **não começaram** e seguem fora do desenho, Ciclo 2; (4) as perguntas em aberto abaixo. Por isso o contrato **fica em `03-Contratos-Logica-Fora-Backend/`**.

> **Escopo (09/10/2026, Nathan): fora do desenho.** Comissões, Orçamento e Compras-analítico não aparecem no Diagrama de Atividades e não contam para concluir o AV-Hub ([[Backlog-por-Frente|AV-Hub-O-que-Falta]]). O contrato fica guardado, **depois** da entrega do desenho; o que entra no desenho é o custo no lote do MES ([[API-008-Custo-do-Lote-no-MES|008-Custo-do-Lote-no-MES]]) e os valores da OC ([[API-007-Referencia-OC-Valores-no-MES|007-Referencia-OC-Valores-no-MES]]).
>
> **Status: `para-implementar`, Ciclo 2**[^c1] (dono: Comercial & Suprimentos; quem executa é decisão do Nathan). Depende de [[API-008-Custo-do-Lote-no-MES|008-Custo-do-Lote-no-MES]] (`GET /itens/custo`) e de [[API-007-Referencia-OC-Valores-no-MES|007-Referencia-OC-Valores-no-MES]]. Desenho: [[Modelo-Estoque-e-Custo-do-Lote|Estoque-Custo-do-Lote]]. **Nada de comissões é alterado antes do Ciclo 2** (item 90 do [[Registro-de-Decisoes|Registro-de-Decisoes-2026-10-07]]); este contrato só fixa o que o hub fará.

## 1. Job de leitura (mesmo molde do [[API-006-Status-por-Item-Leitura-no-Hub|006-Status-por-Item-Leitura-no-Hub]])

Job do hub lê `GET /itens/custo` do MES (cursor `alterado_desde` + `apos_id`, chave de serviço) e grava em `core_vendas_faturamento.itens_pedido_custo` 🟡 (chave **filial + pedido + produto** (`codigo_produto_omie`), não "item": no MES o grão é o produto e linhas repetidas do pedido são somadas; colunas do JSON do contrato 008, resposta em array puro, `lotes` em `jsonb`) por função de banco, como em `fn_itens_pedido_status_gravar`. 🔴 O SQL da `fn_itens_pedido_custo_gravar` (migration 047) hoje faz upsert por "unidade, pedido, item" e precisa passar a gravar por produto. **Pedido manual (sem Omie) nunca entra** nesta tabela (decisão de 14/10 no 008).
>
> **Custo sem impostos no Ciclo 1 (14/10, decisão D5 do 008):** a OC não traz ICMS, IPI nem ST por item, então `custo_medio` e `custo_total` vêm sem impostos e podem ficar acima do custo real quando há ICMS recuperável. O simulador e a tela devem deixar isso claro; a origem dos impostos fica para o Ciclo 2. Rota `GET /itens_pedido_custo?numero_pedido=` com o escopo "dono" do pedido (mesmo do contrato 40) e permissão de tela própria: **custo é dado sensível; o vendedor não vê o custo, só o resultado (letra e %)**. 🔴 Nathan confirma.

## 2. Etapa 2 — simulador pré-preenchido

No [[Comissoes|AV-Hub-Simulador-Comissao]], o custo líquido do item vem de `itens_pedido_custo.custo_medio` quando `completo = true`; Compras abre a simulação, **confere e confirma** (hoje digita). Item sem custo completo segue digitado. Grava no `simulacao_item` existente (`core_comissionamento`) a origem do custo (`orcado`, `mes`, `compras`).

## 3. Etapa 3 — comissão por faturamento

A cada NF faturada de um pedido cujos itens da NF tenham custo completo: `custo da NF = Σ (qtd faturada do item × custo_medio)` (**regra A**); margem do pedido → letra → % (tabela do simulador) sobre o valor faturado. Guarda o cálculo por NF (`comissao_provisoria`, schema `core_vendas_faturamento`), sem recalcular NF antiga se o custo do lote mudar depois. Pedido sem custo completo segue a etapa 2. Fabricação: 2% fixos. Devolução: Ciclo 2 (item 31 do Registro).

## 4. Compras e Orçamento (mesmo dado)

- Compras: nas telas de OC e requisição, comparar `valor_unitario` da OC com o custo real do lote e com o orçado.
- Orçamento (Comercial & Suprimentos): `vw_historico_precos` (hoje `valor_unidade` de cotações do Omie) ganha a fonte "custo real recebido" (preço pago por produto/fornecedor/data, do lote ou da OC), para sugerir custo nos orçamentos.
- Nada disso exige novo dado no MES: usa os campos do 007 e do 008.

## Aceite

1. Pedido de revenda com custo completo: o simulador abre com o custo e o vendedor não o enxerga.
2. NF parcial de 10 das 20 flanges: custo do faturamento = 10 × 11,75 = 117,50; uma segunda parcial de 10 usa o mesmo custo médio.
3. Pedido com item sem custo: nada é calculado automaticamente.
4. O histórico de preços lista o preço pago em USD já convertido, com a data da PTAX.

## Perguntas em aberto 🔴
Quem executa (Pablo/Comercial & Suprimentos ou outro); permissão de custo; fonte do imposto por item; se a etapa 3 paga a diferença quando o custo do lote for corrigido depois da NF (**não**: decidido em 14/10, D4 do 008, a parte baixada mantém o custo gravado na saída).

## Ver também
[[Modelo-Estoque-e-Custo-do-Lote|Estoque-Custo-do-Lote]] · [[Comissoes|AV-Hub-Comissao-Modulo]] · [[Comissoes|AV-Hub-Simulador-Comissao]] · [[API-008-Custo-do-Lote-no-MES|008-Custo-do-Lote-no-MES]] · [[LOG-40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend|40-Escopo-de-Vendedores-e-Permissoes-pelo-Token-no-Backend]]

[^c1]: Nota de 14/10/2026: Status vigente: `parcial` (§1 entregue no av-hub; depende de `GET /itens/custo` do MES, que não existe).
