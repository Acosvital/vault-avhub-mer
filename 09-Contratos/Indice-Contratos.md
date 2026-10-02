---
tags: [contrato-sql, contrato-api, indice]
criado: 2026-09-17
atualizado: 2026-10-01
---

# Contratos — ERP Aços Vital

Seção dedicada só a **contratos** — documentos formais de mudança que precisam de aprovação/execução de outra pessoa antes do código poder avançar: contratos de **banco de dados** (para o DBA, Gustavo) e contratos de **API** (para o dev que for implementar). Cada contrato é auto-contido: alguém pode abrir só aquele arquivo, entender o "por quê", o "o quê" exato (schema ou request/response) e o que falta decidir, sem precisar ler o resto do projeto.

## Conferência de 01/10/2026 (DBA: "concluí 26, 28, 29, 30, 31, 32, 33 e 34")

| Contrato | Resultado na `api-test` | Onde ficou |
|---|---|---|
| [[26-Vendas-Liberacao-Pedido]] | ✅ data de corte preenchida (28/07/2026), liberação funcionando (741 pendentes, 16 liberados, 3 importados) | `Realizados/` |
| [[28-Compradores-Criar-Excluir-Sugestao]] | 🔄 **revisado em 02/10/2026**: criar/excluir **cancelados** (os 404 de `POST`/`DELETE` estão certos). Agora pede: vendedor sem criar/excluir/editar o que vem do Omie no backend (R1–R2) e `ativo_desde`/`inativo_desde` em compradores (R4) | aberto, backend |
| [[29-Notas-Fiscais-Manuais-So-Admin]] | 🟡 código pronto, mas `NOTAS_MANUAIS_EXIGIR_PERMISSAO` desligada: um Vendedor passa da checagem | aberto, ligar a trava |
| [[30-Compras-Pedido-Omie-PDF-Completo]] | ✅ campos no código da `develop`; sem dado para testar | `Realizados/` (falta o PDF do av-hub mostrar) |
| [[31-Compras-Dashboard]] | ✅ rota responde (valores zerados, sem pedidos) | `Realizados/` |
| [[32-Compras-CCP-Acompanhamento-OC]] | ✅ fila, detalhe e contatos respondem e validam | `Realizados/` |
| [[33-Dashboards-Unidade-de-Origem-do-Vendedor]] | ✅ `/vendedores` com `ativo_desde`, `inativo_desde`, `unidade_origem` | `Realizados/` (front sem push) |
| [[34-Requisicoes-MES-Empurra-para-o-Hub]] | 🔴 PUT no ar, mas **`GET /compras/requisicoes` dá 500**: SQL do anexo 0001 provavelmente não aplicado | aberto, **urgente** |

## Como está organizado

- **[[001-Produtos-Parceiros-Filtro-Incremental|1. Contratos de API]]** — mudanças de contrato de request/response em endpoints REST já existentes, ou endpoints novos. Pasta `02-Contratos-API/` (ainda em aberto) e `Realizados/02-Contratos-API/` (já aplicados).
- **2. Contratos SQL para o DBA** — DDL proposto (CREATE/ALTER TABLE), pronto para o Gustavo revisar e aplicar. Pasta `01-Contratos-SQL-DBA/` (ainda em aberto): [[006-Pedidos-Vendas-Valor-Devolucao]] e **[[009-Categoria-Sem-Escopo-Empresa-Views]]** (24/09/2026 — bug real: 4 views duplicam registro quando o código de categoria existe em mais de uma unidade; testado e corrigido no banco local, valor de um pedido caiu de R$ 1,4M pra R$ 964k depois do fix).
- **3. [[Indice-Logica-Fora-do-Backend|Contratos de lógica fora do backend]]** — importados de `av-hub/docs/` (arquivos marcados `ENVIAR`) em 23/09/2026: filtro/ordenação/paginação/permissão que hoje rodam no navegador em vez do banco/API. Pasta `03-Contratos-Logica-Fora-Backend/`. **Compras (28/09/2026):** o backend (banco + API) e as telas estão concluídos e foram para Realizados (10 a 15, ver abaixo). **Em aberto:** [[23-Compras-Pipeline-Consolidado]] (`omie-elt-pipeline`, L1–L10: é o que falta para as telas terem dados na `api-test`), [[18-Compradores-Funcionario]] e [[19-Compras-Pedido-Omie-Nomes]] (backend dos dois entregue em 29/09; front em av-hub#106, mergeado em 29/09 → **movido para `Realizados/`**). [[19-Compras-Pedido-Pipeline-Omie]] foi substituído pelo 23 e fica como histórico. **[[07-Dados-Orcamento-e-Coordenadores-no-Banco]] não foi entregue** (conferido em 29/09).
- **Requisições do MES (01/10/2026):** [[34-Requisicoes-MES-Empurra-para-o-Hub]] — o MES empurra a requisição ao hub (`PUT /compras/requisicoes/origem/{id_origem}`), em vez de o hub buscar (substitui a DEC-2; revisa o [[003-Requisicao-Compra-Integracao-MES]]). Cancela só sem OC (409 com OC), chave própria só para essa rota, colunas do pedido do Omie. **Implementado e testado na API local** (`f4380d7`); falta o DBA, a `develop` da API e o MES chamar. Análise geral: [[Analise-Contratos-vs-Hub-2026-10-01]].
- **Dashboards (01/10/2026):** [[33-Dashboards-Unidade-de-Origem-do-Vendedor]] — o filtro de unidade dos dashboards de vendas, faturamento e por tipo passa a ser a **unidade de origem do vendedor** (lotação do funcionário no RH; sem vínculo, o Omie do cadastro), e vendedor que saiu some dos rankings pelo `ativo_desde`/`inativo_desde` no cadastro. SQL (view, 2 funções, 15 funções de dashboard) + API. **Implementado e testado no banco e na API locais; front pronto na branch `feat/vendedor-periodo-ativo` (sem commit).** Anexos: `33-anexos/0001` (SQL) e `0002` (patch da API). Falta aplicar na api-test/produção. Em aberto: 4 pessoas duplicadas sem vínculo (P1), genéricos/Dev (P2), comissões (P3), histórico retroativo (P5), datas dos 35 inativos (P6).
- **Compras (30/09/2026):** [[32-Compras-CCP-Acompanhamento-OC]] — o CCP acompanha a OC com o fornecedor: confirmação, contatos, previsão, despacho e renegociação (3 tabelas novas + fila `GET /compras/acompanhamento` + escrita só para o perfil CCP). SQL + API; **proposta**, sem nada implementado. Bloqueia a tela `/compras/followup` do av-hub. Perguntas P1 (de onde vem o "saldo a receber") e P2 (só OC do av-hub?) definem o escopo.
- **Compras (30/09/2026):** [[31-Compras-Dashboard]] — `GET /compras/ordens/dashboard`: valor comprado (e período anterior), série de 12 meses, top fornecedores/categorias/compradores, maiores pedidos, recebimento e atraso (foto de agora) por faixa. Só API; **implementado e testado na API local** (`cba68fa`), falta ir para a `develop`. Perguntas: pedidos BENAFER de R$ 82,7 mi em agosto e o significado das etapas 10/15/20.
- **Compras (30/09/2026):** [[30-Compras-Pedido-Omie-PDF-Completo]] — o que falta no PDF do pedido feito no Omie (conferido contra o PDF do próprio Omie, pedido 46871): endereço, e-mail, telefone e IE do fornecedor e código do produto no `GET /pedidos_compras/{id}`; IE (vazia em `core.parceiros`) e, se precisar, IPI/ICMS ST pela pipeline. **Proposta.**
- **Faturamento (29/09/2026):** [[29-Notas-Fiscais-Manuais-So-Admin]] — nota fiscal manual só para o admin: permissão da tela `notas-fiscais-manuais` conferida no backend, auditoria de quem cadastrou/alterou. **Proposta.**
- **Acessos (29/09/2026):** [[28-Compradores-Criar-Excluir-Sugestao]] — criar/excluir comprador e sugestão de vínculo por semelhança, para a tela de Compradores ficar igual à de Vendedores. Só API (+ um ajuste na pipeline); **proposta**.
- **Compras (28/09/2026):** [[19-Compras-Pedido-Omie-Nomes]] — nomes (fornecedor, comprador, etapa, catálogos) no `GET /pedidos_compras/{id}`, para o detalhe do pedido feito no Omie. Só API; **backend entregue em 29/09**, front em av-hub#106.
- **Vendas (28/09/2026):** [[26-Vendas-Liberacao-Pedido]] — liberação do pedido pelo vendedor (acompanhamento da Qualidade) e Fluxo 4 av-hub → MES. SQL + API + telas testados no local; telas mergeadas na `develop` do av-hub (#103, 28/09/2026); **backend entregue em 29/09**; **L4 do `api-pcp` concluído em 29/09** (Robert, conferido em 30/09). Falta a data de corte (`parametros_vendas`) e a chave própria do MES (L6).
- **Realizados** — contratos já entregues. Pasta `Realizados/01-Contratos-SQL-DBA/`: [[001-Parceiros-Dados-Fiscais]], [[002-Estoque-Saldo]], [[003-Pedidos-Vendas-Frete-Parcelas]], [[004-Pedidos-Compras]], [[005-Locais-Estoque]], [[007-Ordens-Compra-Estruturada]], [[008-Requisicoes-Compra]]. Pasta `Realizados/02-Contratos-API/`: [[001-Produtos-Parceiros-Filtro-Incremental]]. Pasta `Realizados/03-Contratos-Logica-Fora-Backend/`: [[01-Compras-Fluxo-Completo]], [[02-Funcionarios-Listagem-Filtros-Ordenacao-Resumo]], [[03-Funcionarios-Cadastro-Organograma-Transacional]], [[04-Pedidos-Notas-Dashboards-Agregacao-no-Banco]], [[05-Permissoes-e-Escopo-no-Banco]], [[06-Ordenacao-Listagens]], [[07-Chave-Composta-Blacklist-Pedidos]], [[08-Itens-por-Parcela-Pedidos]], [[09-Ordenacao-Sistema-Vendedores]] e, em 28/09/2026 (Compras, backend na `api-test` + front mergeado no av-hub #104/#105): [[14-Compras-Omie-Pedido-Compra]] (01/10/2026: fluxos A e B testados, falta ligar em produção), [[04-Vagas-Fila-Decisao-no-Banco]] (01/10/2026: entregue, trava e §3.3.1 conferidas na `api-test`), [[09-Paginacao-por-Pedido-Vendas-Planilha]] (01/10/2026: entregue, `agrupar_por=pedido_venda` conferido na `api-test`), [[10-Compras-Pendencias-Pos-Backend]], [[11-Compras-Cotacao-Moeda-PTAX]], [[12-Compras-Projetos-Omie]], [[13-Compras-Backend-Consolidado]], [[14-Compras-Vinculo-Pedido-Venda]] e [[15-Compras-Historico-Unificado]]; em 29/09/2026 (históricos concluídos pelo 13): [[16-Compras-Pedido-DBA-Banco]] e [[17-Compras-Pedido-API-Backend]].

## Convenção de todo contrato

- **Status** no frontmatter (`proposta` / `aplicada` / `rejeitada`) — atualizar aqui quando o status mudar no mundo real, esta é a fonte de verdade sobre "o que já foi feito".
- **Por quê** — motivação, sem jargão de implementação.
- **O contrato em si** — DDL exato (contratos SQL) ou request/response exato (contratos de API).
- **Perguntas em aberto** — o que precisa de decisão humana antes de aplicar. Nenhum contrato deveria ser aplicado com pergunta em aberto não respondida.
- **Depois de aplicado** — o que o dev precisa fazer no código depois que o outro lado (DBA, ou o próprio dev) aplicar a mudança.

## Origem

Os contratos SQL 001-006 desta seção nasceram como contratos 006-011 no
repositório `omie-elt-pipeline` (`sql/dba_migrations/`), onde os contratos
001-005 daquele repositório já existem com numeração própria (001, 002, 004
e 005 já aplicados; 003 rejeitado e mantido só como histórico). Os arquivos
originais nesse repositório agora apontam pra cá, para não duplicar/
desatualizar duas cópias — esta seção é a versão viva, com numeração
própria (001 em diante) independente da numeração do outro repositório.

## Status atual (21/09/2026 — confirmado contra dump de produção)

> **Atualização de 21/09:** o dump `dump-avhub_prd_db-202609210741.sql` (produção, gerado 21/09 07:41) mostra que 5 dos 6 contratos SQL e o contrato de API 001 **já estão aplicados** — este índice estava desatualizado desde 17/09. Ver o depara completo, coluna a coluna, em [[Auditoria-Dump-Producao-2026-09-21]]. Cada arquivo de contrato individual ainda precisa ter o próprio frontmatter `status` atualizado por quem tiver posse dele (não alterado aqui para não sobrescrever perguntas em aberto específicas de cada arquivo).

| Contrato | Tipo | Assunto | Status |
|---|---|---|---|
| [[001-Parceiros-Dados-Fiscais]] | SQL | `core.parceiros` + dados fiscais | **aplicada** (confirmado no dump 21/09; `dadosBancarios`/`enderecoEntrega` vêm por endpoint próprio; `chave_pix` ajustada para `varchar(255)`) |
| [[002-Estoque-Saldo]] | SQL | `core.estoque_saldo` (novo) | **aplicada** (confirmado no dump 21/09; "foto atual" confirmado como a implementação real) |
| [[003-Pedidos-Vendas-Frete-Parcelas]] | SQL | `pedidos_vendas` + frete/parcelas | **aplicada** (confirmado no dump 21/09) |
| [[004-Pedidos-Compras]] | SQL | `pedidos_compras` (novo) | **aplicada** — risco do `numero_item_omie` **resolvido na prática em 22/09** (design decidido em 21/09, migration confirmada no dump de 22/09): identidade do item é `(id_pedido_compra, ordem)`, com índice único aplicado |
| [[005-Locais-Estoque]] | SQL | `core.locais_estoque` (novo) | **aplicada** (confirmado no dump 21/09) — sem FK para `deposito` por decisão (tabela ainda não existe); Gustavo adiciona quando ela existir |
| [[006-Pedidos-Vendas-Valor-Devolucao]] | SQL | `pedidos_vendas.valor_devolucao` | **invalidado** (frontmatter do arquivo já dizia isso desde 17/09; este índice estava com a inconsistência I-02, agora corrigida) |
| [[009-Categoria-Sem-Escopo-Empresa-Views]] | SQL | `vw_vendas_planilha`, `vw_vendas_base`, `vw_nf_classified`, `vw_faturamento_planilha` — JOIN de `core.categorias` sem `codigo_empresa` | **proposta**, testado e corrigido no banco local em 24/09/2026 (achado investigando um bug de tela) — pendente aplicar em teste/produção |
| [[001-Produtos-Parceiros-Filtro-Incremental]] | API | `?alterado_desde=` em produtos/parceiros (av-hub) | **aplicada** (confirmado em `src/routes/produtos.js`/`parceiros.js`) |
| [[002-Material-Alias-Omie-MES]] | API | `material_alias_omie` — vínculo de duplicata (destinatário: MES/Estoque) | **rejeitada em 21/09/2026** — decisão do Nathan: duplicata de catálogo sai do escopo deste sistema, resolve-se direto no Omie. Código removido do MES em 29/09 (`api-pcp` `0ac2596`) |
| [[003-Requisicao-Compra-Integracao-MES]] | API | Requisição de compra, MES → av-hub (Fluxo 1 da spec F1) | **proposta** — aprovada por Nathan em 22/09/2026; **aprovada pelo Robert em 30/09/2026 com ajustes** (uma linha por item, `id_origem` = id do item no MES, status do MES só informativo); rota `GET /requisicoes-compra` **já existe no MES**; o job do av-hub não existe; em aberto: nomes dos campos, pedido sem prazo, dono do job; falta o Gustavo |
| [[004-Referencia-OC-Integracao-MES]] | API | Referência da OC, av-hub → MES (Fluxo 2 da spec F1) | **proposta** — aprovada por Nathan em 22/09/2026; **revisado em 29/09/2026** (requisição por item, destino do item, OC cancelada, paginação); **30/09: Robert aprova o formato com um ajuste** (`id_origem` em cada item); rota `GET /ordens-compra/referencia` **ainda não existe** na API (o MES usa um registro manual da compra até lá); falta o Gustavo |
| [[005-Status-Item-Integracao-MES]] | API | Status por item, MES → av-hub (Fluxo 3 da spec F1) | **proposta** — aprovada por Nathan em 22/09/2026; **aprovada pelo Robert em 30/09/2026 com diferenças** (foto atual, `pedido_venda` + `ordem_producao`, etapas a mais); rota `GET /itens/status` **já existe no MES**; falta o aceite do Nathan às diferenças e o Gustavo |
| [[007-Ordens-Compra-Estruturada]] | SQL | `core_vendas_faturamento.ordens_compra` + itens + parcelas — OC decidida no av-hub (E2) | **aplicada** — confirmado em 23/09/2026 (`api-acos-vital` PR #273, junto com o 008); o aplicado difere do DDL em nomes e regras (ver o topo do arquivo). Envio ao Omie ainda não existe |
| [[008-Requisicoes-Compra]] | SQL | `core_vendas_faturamento.requisicoes_compra` (novo) — caixa de entrada de Compras (E1) | **aplicada** — confirmado em 23/09/2026 (`api-acos-vital` PR #273, junto com o 007); o aplicado difere do DDL em nomes e nulidade (ver o topo do arquivo) |

## Ver também
- [[Roteiro-de-Implementacao]]
- [[Decisoes-Chave-ERP]]
- [[Campos-e-API-para-Rastreabilidade]] — lista de tabelas, campos e endpoints novos para rastreabilidade; cada bloco vira contrato SQL ou de API aqui depois que a spec F1 for aprovada.
- [[Auditoria-Dump-Producao-2026-09-21]] e [[Auditoria-Dump-Producao-2026-09-22]] — depara completo contra dump de produção
