---
id: conexao-telas-pablo-api-hub
tags: [comercial, suprimentos, api-acos-vital, analise, rascunho]
criado: 2026-10-27
atualizado: 2026-10-27
status: rascunho
fontes: ["Dump do Avhub para referência (completo).sql (avhub_prd_db, gerado em 26/10/2026 08:30)", "av-hub branch refactor/menu-enxuto-vendas-orcamento-compras (3bccfce): app/(protected)/vendas, orcamento, dashboards/dash-comercial, comissoes/simulador; app/api/comercial/**; services/comercial/*", "api-acos-vital origin/develop a7fda49: src/schemas/**", "LOG-52 §0, LOG-56, API-019, API-020, N16-109, N16-111"]
---

# Conexão das telas do Pablo com a API do Hub — análise página a página

> [!info] Para quê
> Rascunho para o Nathan revisar **página a página** antes de qualquer contrato (pedido de 27/10/2026). Depois da `api-comercial` removida (N16-111), toda tela do módulo chama o BFF `/api/comercial`, que só fala com a API do Hub; o que não existe lá responde 503 `RECURSO_NAO_MIGRADO`.
>
> Legenda: ✅ o Hub já tem e dá para ligar · 🟡 o Hub tem parte (dado sim, regra ou rota não) · ❌ não existe: vira contrato · 🚫 sai pelo vault (não migra).
>
> Lido no código em 27/10/2026. **Não rodei** nenhuma rota do Hub listada como ✅ além das já ligadas (empresas, parâmetros de custo, câmbio, `/me/permissoes`); os campos vêm da leitura das rotas em `origin/develop`.

## Andamento da conexão (27/10/2026)

**Ligado ao Hub e testado na API de teste** (av-hub, branch `refactor/menu-enxuto-vendas-orcamento-compras`):
- **Fornecedores** (lista, filtro por categoria e ficha) → `/orcamento/fornecedores`, `/orcamento/vinculos`, `/orcamento/categorias`, `/orcamento/cotacoes`. Perfil de compras, categorias e certificados ficam **só leitura** até o Hub gravar.
- **Produtos** (lista e detalhe) → `/produtos`, `/produtos/:id`, `/produtos/:id/fornecedores`. A família aparece como código: o Hub recusa `/familias_produtos` para o perfil Admin (permissão).
- **Proposta**: busca de produto → `/produtos`; opções da análise de margem → `/simulador_parametros` (só com a tela `custo-item`).
- **Cotação**: fornecedores da categoria com e-mail → `/orcamento/vinculos`.
- **Clientes**: Vendas › Clientes **é** o Acompanhamento de Clientes (`/vendas/acompanhamento-clientes`). A tela Clientes do Pablo saiu do front; na API de teste a tela `acompanhamento-clientes` foi para Vendas com o nome "Clientes" e a tela `clientes` foi desativada.

> [!warning] Revisão completa do Orçamento antigo (Nathan, 27/10/2026)
> O que veio do Orçamento antigo do Hub (`core_compras` `/orcamento/*`, tabelas `orc_*`, contrato 07: fornecedores, categorias, vínculos, produtos e cotações) **passa por revisão completa** para atender **só o que o vault precisa**. As ligações acima usam essas rotas como estão hoje; a revisão decide o que fica, o que muda e o que sai, e pode trocar a fonte de alguma tela. Entra como item dos contratos de Fornecedor, Oferta e Pedido de cotação.

## Princípio: um Hub só (Nathan, 27/10/2026, N16-112)

> "O AVHUB precisa ser inteiramente acoplado e unidos." Cada conceito tem **uma** tabela, **uma** rota e **uma** tela no Hub; o módulo do Pablo entra **dentro** do que já existe, não ao lado. Onde a análise abaixo diz "ligar" ou "contrato", vale esta tabela de unificação.

| Conceito | Fica (fonte única no Hub) | Sai ou se funde |
|---|---|---|
| Empresa que emite | `core.unidades` (+ extensão do PDF: logo, CRC, textos, se o Gustavo mantiver) | `core_comercial.unidades_emissoras` como cadastro próprio |
| Quem vende e em nome de quem | `auth.usuarios`, `vendedores`, `auxiliar_vendedor`, `/me/permissoes` | `perfis_comerciais`, `fn_responsaveis_proposta` |
| Permissão | `auth.telas`, `auth.rotas_telas` | capacidades próprias do módulo |
| Cliente | `core.parceiros` (tipo cliente), grupos e setores; **uma tela**: Acompanhamento de Clientes, que ganha a ficha e o que o comercial acrescentar | `core_comercial.clientes`, `clientes_contatos` e a tela Clientes paralela |
| Fornecedor | `core.parceiros` (tipo fornecedor) + o Orçamento antigo (`orc_fornecedores`, vínculos) | `fornecedores_perfil` como cadastro próprio (vira extensão, se precisar) |
| Categoria de fornecimento | **uma lista**: `orc_categorias` (16) | `core_comercial.categorias_suprimento` (17, repetida) |
| Produto | `core.produtos` / catálogo (+ extensão técnica) | `produtos_perfil` como cadastro próprio; `produtos_pendentes` vira extensão |
| Cotação / oferta de fornecedor | **uma tabela**: `orc_cotacoes` ou `parceiros_produtos` (decidir qual absorve a outra) | `core_comercial.ofertas` |
| Preço de compra real | `pedidos_compras_itens` (Omie) | cópias do módulo |
| Câmbio | `core.cotacoes_moeda` | câmbio próprio |
| Motor de margem e comissão | **um** motor na API, com `simulador_parametros` | cópias no front e no módulo |
| E-mail e notificações | serviço **do Hub inteiro** (qualquer módulo usa) | `core_comercial.notificacoes` e envio próprio |

## Conferência com o banco de produção (dump de 26/10/2026)

Contagem de linhas por tabela no dump completo de `avhub_prd_db`. Muda dois pontos da análise (marcados ⚠️ abaixo).

| O que | Linhas | O que isso diz |
|---|---|---|
| `core_comercial` (schema do Pablo) | 23 tabelas | **Está em produção, vazio.** Só têm dado `categorias_suprimento` (17), `parametros_custo` (1) e `unidades_emissoras` (3). Propostas, clientes, ofertas, notificações, solicitações de custo, telha, perfis: **0**. Tirar a `api-comercial` de produção inclui decidir o que fazer com esse schema (Gustavo) |
| ⚠️ `core.parceiros_produtos` (cotação por produto) | **0** | A tabela existe, mas **não tem cotação nenhuma**. `/parceiros_produtos` e a parte "cotação" de `/produtos/:id/fornecedores` voltam vazias |
| `core_compras.orc_cotacoes` / `orc_fornecedores` / `orc_produtos` / `orc_categorias` / `orc_vinculos` | 2.697 / 10.524 / 400 / 16 / 234 | **É aqui que estão as cotações** (carga do Orçamento antigo, contrato 07). Categorias de fornecimento: 16 no Hub contra 17 em `core_comercial.categorias_suprimento` (lista repetida) |
| `pedidos_compras` / `pedidos_compras_itens` (Omie) | 24.171 / 47.125 | Histórico real de **preço de compra** por produto e fornecedor: a melhor fonte para "Sugerir custo" e para a página do produto |
| `ordens_compra` (OC do Hub) | 0 | O circuito de compra do Hub ainda não emitiu OC em produção |
| ⚠️ `core.produtos.especificacoes` | 125.852 com jsonb | Todos com os campos genéricos do Omie (marca, modelo, peso, medidas), **125.806 zerados**. Não há norma, material nem kg/m: o perfil técnico (`produtos_perfil`) é mesmo novo |
| `core.parceiros` / `parceiros_tipos` | 23.138 / 28.899 | Clientes e fornecedores juntos; o tipo existe e dá para filtrar cliente |
| `grupos_clientes` / `setores_clientes` / `clientes_setor` | 33 / 13 / 5 | O Acompanhamento de Clientes já tem grupos e setores em uso |
| `auxiliar_vendedor` / `diligenciador_vendedor` | 2 / 47 | Só **2 auxiliares** cadastrados: o "Emitir em nome de" aparece para eles |
| `vendedores` | 125 | — |
| `core_comissionamento.simulador_parametros` | 3 | Uma vigência por unidade: a análise de margem tem os parâmetros |
| `core.cotacoes_moeda` | 406 | PTAX para o câmbio |
| `core.categorias` | 787 | Plano de contas do Omie, não categoria de produto |
| `auth.telas` / `auth.rotas_telas` | 102 / 415 | — |

**O que muda na análise:**
- **Achado 2 e páginas 7b, 7c, 8 e 11b:** onde a análise diz "cotação por produto em `parceiros_produtos`", ler **`orc_cotacoes`** (2.697 cotações, via `/orcamento/cotacoes` e `/orcamento/produtos`) e o **histórico de compra do Omie** (`pedidos_compras_itens`, 47 mil itens). A decisão da oferta fica mais simples: `parceiros_produtos` está vazia e pode ganhar o formato que o contrato decidir, ou a oferta nasce de `orc_cotacoes`.
- **Página 7a e 8:** dados técnicos do produto confirmados como inexistentes.

## Achados que valem para várias páginas

1. **O Hub já tem um "Orçamento" antigo** (`core_compras /orcamento/*`, contrato 07): fornecedores com **categorias de fornecimento**, vínculos categoria × fornecedor (inclusive sem cadastro), produtos com cotação mais recente e preço médio, e histórico de cotações. É a base natural de Fornecedores, Produtos e Pedido de cotação, no lugar das tabelas do Pablo.
2. **Cotação de fornecedor por produto já existe** em `core.parceiros_produtos` (`/parceiros_produtos`, com valor, IPI, ICMS e data) e há **histórico de preço** (`/historico_precos`, `/orcamento/cotacoes`) e **fornecedores do produto com última cotação e última compra** (`/produtos/:id/fornecedores`). A "oferta" do Pablo (preço com prazo, frete, validade, custo líquido) é uma cotação mais rica: decidir se **estende `parceiros_produtos`** ou cria tabela nova.
3. **O Hub já tem "Acompanhamento de Clientes"** (status, última compra, dias sem comprar, setores, grupos, movimento do mês). A tela Clientes do Pablo é um CRM paralelo sobre outra tabela.
4. **Não há e-mail na API do Hub** (sem biblioteca nem rotina de envio). Proposta por e-mail e pedido de cotação dependem disso: é infraestrutura, um contrato à parte.
5. **Não há notificações (sino)** em nenhum schema. Também é transversal.
6. **Clientes e fornecedores ficam juntos em `core.parceiros`**, e `/parceiros` **não filtra por tipo**. Só `/compras/fornecedores` filtra (fornecedor e transportadora). Falta o equivalente para cliente com CNPJ e unidade (`/todos_os_clientes` não traz nenhum dos dois).
7. **O motor de margem e letra existe no front** (`lib/simulador/motor.ts`) e os parâmetros no Hub (`/simulador_parametros?codigo_empresa=&vigente=true`). O vault manda o cálculo para a API (LOG-56 R42, N16-109 "uma fonte").
8. **Permissões tortas no BFF** (do Pablo): na proposta, "Sugerir custo" exige a tela `custo-item` e "Pedir custo" exige `solicitacoes-custo`; no Painel do Comprador, ofertas, produtos, categorias e fornecedores não aceitam a tela `painel-comprador`. Rever junto com cada contrato.

---

## Vendas

### 1. Propostas — lista (`/vendas/propostas`)
**Hoje:** 5 KPIs (cotado, em aberto, fechadas, perdidas, conversão), busca e filtros (empresa, status, período, unidade, responsável), tabela, imprimir em lote (PDF comercial ou técnico), excluir, nova proposta.

| Precisa | No Hub | |
|---|---|---|
| Lista, busca, filtros e excluir | — | ❌ API-019 §3.1 (só lista e detalhe estão lá; **filtros e KPIs não**) |
| KPIs do topo | — | ❌ falta no API-019; os status mudam para ABERTA, APROVADA, TRANSFORMADA, CANCELADA (KPIs "fechadas/perdidas" deixam de existir) |
| Filtro por responsável | `/vendedores` e o escopo do token | 🟡 trocar "responsável" (usuário do `core_comercial`) por **vendedor** (`codigo_vendedor_omie`), como os outros portais |
| Empresa | `/unidades` | ✅ |
| PDF em lote | o PDF é montado no BFF | 🟡 depende só da proposta existir no Hub |

### 2. Proposta — nova e detalhe (`/vendas/propostas/nova`, `/vendas/propostas/[id]`)
**Hoje:** Emissão, Cliente, Condições comerciais, Análise de margem, grade de Itens (catálogo, sugerir custo, pedir custo, telha, planilha), solicitações de custo, totais e ações (salvar, fechar, perder, reabrir, pedido no Omie, PDFs, e-mail, duplicar, revisões, linha do tempo).

| Precisa | No Hub | |
|---|---|---|
| Empresa emissora | `/comercial/empresas_emissoras` (Pablo, `core_comercial`) ou `/unidades` | 🟡 ligado ao do Pablo; pela N16-111 vai para `/unidades` + extensão do PDF (logo, CRC, textos), decisão do Gustavo (N16-80) |
| Emitir em nome de | `/me/permissoes` (vendedores `titular`) | ✅ ligado (27/10). Falta gravar na proposta (API-019) |
| Buscar cliente | `/parceiros` (sem filtro de tipo) | 🟡 falta filtro de **cliente** + busca por CNPJ e nome com unidade |
| Consulta CNPJ na Receita | — | ❌ decidir se fica (prospect, N16-109 em aberto) |
| Compradores do cliente | só e-mail e telefone únicos em `core.parceiros` | ❌ contatos do cliente (ou sai) |
| Câmbio | `/cotacoes_moeda/atual` | ✅ ligado |
| Condições de pagamento de venda | — | ❌ SQL-019 (`condicoes_pagamento_vendas`, a criar) |
| Destino, condição da tabela, origens (análise) | `/simulador_parametros` | ✅ dado existe; falta a rota que entrega as opções à proposta (ou o front lê direto) |
| Cálculo (totais, margem, letra) | motor só no front | ❌ cálculo na API (LOG-56 R42, API-019) |
| Buscar produto | `/produtos?q=&codigo_empresa=` e `/catalogo_de_produtos` | ✅ |
| Sugerir custo do item | `/produtos/:id/fornecedores` (última cotação e compra), `/historico_precos`, `/catalogo_de_produtos` (preço médio) | 🟡 dados existem; a **regra** (menor custo líquido válido, média 90 d, conversão de unidade) ❌ contrato |
| Pedir custo ao Orçamento | — | ❌ API-020 (pedido de custo) |
| Telha (configurador) | só `densidades` em parâmetros de custo | ❌ |
| Importar itens de planilha e baixar modelo | — | ❌ (ou leitura no front, se o Nathan aceitar) |
| Salvar, revisões, eventos, duplicar | — | ❌ API-019 |
| Aprovar, cancelar, transformar em pedido (Qualidade, faturar em partes, data) | — | ❌ API-019 + SQL-016 |
| Fechar, fechar itens, perder, reabrir, planilha do pedido no Omie | — | 🚫 saem (N16-02, N16-109) |
| PDFs comercial, técnico e de aprovação | montados no BFF | 🟡 dependem da proposta no Hub |
| Enviar por e-mail | — | ❌ infraestrutura de e-mail (achado 4) |

### 3. Clientes — lista (`/vendas/clientes`)
**Hoje:** KPIs (clientes, com proposta em 90 d, próximo contato vencido), filtros (status, segmento, contato vencido), tabela, exportar, novo cliente.

| Precisa | No Hub | |
|---|---|---|
| Lista de clientes da carteira | `/acompanhamento_clientes` (status, última compra, dias sem comprar, setor, grupo, escopo do vendedor) e `/parceiros` | ✅ |
| Segmento | setores de cliente (`/setores_clientes`, `/clientes_setor`) | ✅ equivalente |
| Potencial, próximo contato, responsável próprio (CRM) | — | ❌ ou sai (N16-109 deixou o cadastro de clientes em aberto) |
| "Com proposta em 90 d" | — | ❌ depende de propostas (API-019) |
| Exportar | — | ❌ |
| **Pergunta para o Nathan** | Esta tela duplica o Acompanhamento de Clientes. Unir as duas? | ❓ |

### 4. Cliente — ficha (`/vendas/clientes/[id]`, `/novo`)
**Hoje:** cadastro e relacionamento, compradores (contatos), propostas do cliente, estatísticas.

| Precisa | No Hub | |
|---|---|---|
| Dados e endereço de entrega | `/parceiros/:id` | ✅ |
| Criar cliente | `POST /parceiros` (upsert por conta Omie) | 🟡 o Omie é a fonte do cadastro; prospect sem Omie ❓ |
| Compradores | — | ❌ (mesma decisão da proposta) |
| Compras do cliente | `/pedido_venda_itens?codigo_cliente=`, `/acompanhamento_clientes/movimento` | ✅ |
| Propostas do cliente e estatísticas de cotação | — | ❌ API-019 |

### 5. Relatórios (`/vendas/relatorio-gerencial`, abas Gerencial e Cotações)
Ambas leem só propostas (cotado, conversão, motivos de perda, por responsável, empresa e unidade) e geram PDF e planilha.

| Precisa | No Hub | |
|---|---|---|
| Relatório gerencial e de cotações | — | ❌ depende de propostas; motivos de **perda** viram motivos de **cancelamento** |
| PDF | montado no BFF | 🟡 |
| Planilha | — | ❌ |

### 6. Dashboard Comercial (`/dashboards/dash-comercial`)
KPIs cotado, fechado, em aberto, perdido e conversão; evolução diária; ranking de vendedores; status; motivos de perda; top clientes; propostas em risco. **Tudo de propostas: ❌** (contrato junto com o API-019, ou uma rota de resumo).

---

## Orçamento

### 7. Produtos (`/orcamento/catalogo-produtos`)
**7a. Preços e fornecedores**

| Precisa | No Hub | |
|---|---|---|
| Lista e busca | `/produtos`, `/catalogo_de_produtos` (com cotação mais recente e preço médio) | ✅ |
| Dados técnicos (norma, material, kg/m, dimensões) | `core.produtos.especificacoes` (jsonb), sem os campos | ❌ `produtos_perfil` (LOG-52 §3.2) |
| Produtos pendentes (sem cadastro no Omie) e ligar ao Omie | — | ❌ |

**7b. Comparar (pesquisa de materiais)**

| Precisa | No Hub | |
|---|---|---|
| Cotações por material | `/parceiros_produtos`, `/orcamento/cotacoes`, `/historico_precos` | 🟡 |
| Vencedor por custo líquido, validade, prazo e frete | — | ❌ depende da "oferta" (achado 2) |
| PDF da cotação | montado no BFF | 🟡 |

**7c. Ofertas**

| Precisa | No Hub | |
|---|---|---|
| Lista, lançar, invalidar | `/parceiros_produtos` (cotação simples) | 🟡 decidir: estender ou tabela nova (achado 2) |
| Importar mapa de cotação (.xlsx) e histórico de importações | — | ❌ |
| Exportar | — | ❌ |

### 8. Produto — detalhe (`/orcamento/catalogo-produtos/[id]`)

| Precisa | No Hub | |
|---|---|---|
| Cadastro | `/produtos/:id` | ✅ |
| Fornecedores com última cotação e última compra | `/produtos/:id/fornecedores` | ✅ |
| Histórico de preços | `/historico_precos`, `/orcamento/cotacoes` | ✅ |
| Média, mínimo e máximo de 90 d por fornecedor | — | ❌ (rota de resumo; o dado existe) |
| Dados técnicos | — | ❌ `produtos_perfil` |
| É a página do produto `B2` do vault (LOG-56 R5: histórico, top fornecedores, flutuação) | | ❓ alinhar com o contrato do `B2` |

### 9. Fornecedores — lista (`/orcamento/fornecedores`)

| Precisa | No Hub | |
|---|---|---|
| Lista, busca, cidade e UF | `/compras/fornecedores`, `/todos_os_fornecedores`, `/orcamento/fornecedores` | ✅ |
| Categorias de fornecimento e filtro por categoria | `/orcamento/categorias`, `/orcamento/vinculos` | ✅ |
| Copiar e-mails | `email` do parceiro | ✅ |
| Exportar | — | ❌ |

### 10. Fornecedor — ficha (`/orcamento/fornecedores/[id]`)

| Precisa | No Hub | |
|---|---|---|
| Cadastro | `/parceiros/:id` | ✅ |
| Categorias | `/orcamento/fornecedores/:codigo` | ✅ (editar ❌: o `/orcamento` é só leitura) |
| Perfil de compras (tipo de venda, regime, e-mail de cotação, mínimo, prazo, origem do ICMS) | — | ❌ `fornecedores_perfil` (LOG-52 §3.2) |
| Certificados | — | ❌ |
| Cotações recentes | `/parceiros_produtos?id_parceiro=` | ✅ |
| Ordens de compra | `/compras/ordens?q=` | ✅ |

### 11. Pedidos de custo (`/orcamento/painel-comprador`)
**11a. Fila**: KPIs, próximas ações (assumir, liberar, responder, cancelar), ofertas vencendo, ranking de fornecedores, certificados vencendo, pedidos sem preço, cobertura por família.

| Precisa | No Hub | |
|---|---|---|
| Fila do pedido de custo e respostas | — | ❌ API-020 |
| Ranking, cobertura, itens sem preço, ofertas vencendo | — | ❌ (dependem de ofertas e do pedido de custo) |
| Certificados vencendo | — | ❌ (dependem dos certificados) |

**11b. Cotação** (pedido de cotação a fornecedores por e-mail)

| Precisa | No Hub | |
|---|---|---|
| Fornecedores por categoria com e-mail | `/orcamento/vinculos?categoria=`, e-mail do parceiro | ✅ |
| Análise do item (última compra, cotações) | `/produtos/:id/fornecedores`, `/historico_precos` | ✅ |
| Enviar o pedido por e-mail | — | ❌ infraestrutura de e-mail (achado 4) |

### 12. Parâmetros (`/orcamento/parametros-custo`)

| Aba | No Hub | |
|---|---|---|
| Custo (ICMS a recuperar, validade, histórico) | `/comercial/parametros_custo` | ✅ ligado e testado (27/10). É do `core_comercial`, mas é conceito novo, não duplicado |
| Tabela da telha | — | ❌ |

---

## Outras

### 13. Simulador de comissões (`/comissoes/simulador`)
A base já é do Hub. Só dois enriquecimentos opcionais vinham do Pablo:

| Precisa | No Hub | |
|---|---|---|
| Proposta ligada ao pedido (pré-preencher a compra) | — | ❌ depende de `pedidos` ↔ proposta (SQL-016) |
| Sugerir compra | — | ❌ mesma regra do "Sugerir custo" da proposta |

### 14. Sino de notificações (menu, todas as telas)
❌ Não existe no Hub (achado 5). Hoje recebe 503 e só guarda o último dado: **esconder até existir**.

---

## Resumo: o que dá para ligar já e o que vira contrato

**Ligar já, sem contrato (o Hub tem a rota):** Fornecedores (lista e ficha, sem perfil e certificados), Produtos (lista, detalhe com fornecedores e histórico), Clientes (lista e ficha pelo Acompanhamento e `/parceiros`, se o Nathan aprovar unir), opções da análise de margem (`/simulador_parametros`), busca de produto na proposta, fornecedores por categoria e análise do item na Cotação.

**Contratos a criar (agrupados):**
1. **Proposta no Hub** — API-019 já cobre o ciclo; falta acrescentar filtros e KPIs da lista, cálculo na API, PDF e relatórios/dashboard de propostas.
2. **Cliente para vendas** — filtro de cliente em `/parceiros` (CNPJ, unidade); compradores; prospect e Receita (se ficarem).
3. **Produto: perfil técnico e pendentes** (`produtos_perfil`, `produtos_pendentes`).
4. **Fornecedor: perfil de compras e certificados** (`fornecedores_perfil`) e edição de categorias.
5. **Oferta de fornecedor** — estender `parceiros_produtos` ou tabela nova; importar mapa; vencedor e resumo de 90 d.
6. **Sugerir custo** (regra no backend, usada pela proposta e pelo simulador).
7. **Pedido de custo** — API-020.
8. **Tabela da telha.**
9. **E-mail** (proposta e pedido de cotação) — infraestrutura.
10. **Notificações** — infraestrutura.
11. **Condições de pagamento de venda** — SQL-019.
12. **Exportar planilhas** (clientes, fornecedores, ofertas, relatórios) — ou decidir que sai.

**Perguntas para a revisão:**
- Clientes do Pablo e Acompanhamento de Clientes: unir numa tela só?
- Oferta: estender `parceiros_produtos` ou tabela própria?
- Receita, prospect e compradores: ficam?
- Importar planilha de itens e exportar planilhas: ficam?
- Telha: continua no escopo?
