---
tags: [contrato-logica, contrato-api, orcamento, comissoes, comercial-suprimentos]
status: reescrito
decisao: orçamento desenvolvido por fora, no módulo Comercial & Suprimentos (✅ Nathan, 07/10/2026, Registro item 39). Reescrito em 08/10/2026 pelo Pablo
criado: 2026-09-20
atualizado: 2026-10-08
---

# Contrato 07 — Dados de Orçamento e de coordenadores no banco (reescrito em 08/10/2026)

> **Decisão (✅ Nathan, 07/10/2026, [[Registro-de-Decisoes-2026-10-07]] item 39):** o orçamento foi **desenvolvido por fora, no módulo Comercial & Suprimentos** ([[AV-Hub-Comercial-Suprimentos]]). A API entregue na `api-acos-vital` (`90bdb33`, 01/10, PR #275) existe. Este texto substitui o anterior (o histórico está no fim).

**Conferido no código em 08/10/2026:** `av-hub` `develop` (`4b292fa`) e os PRs abertos do módulo (#171, #173, #174, #175); `api-acos-vital` `develop`. Produção não conferida.

## 1. Orçamento: coberto pelo módulo Comercial & Suprimentos

O problema do contrato original era: dados reais de fornecedores, produtos e cotações em JSON dentro do repositório (`lib/orcamento/data/`, ~4,8 MB), filtrados em memória pelo BFF. O módulo Comercial & Suprimentos resolve isso com banco próprio (`api-comercial`, schema `core_comercial`), dados vindos do Omie e busca, filtro e paginação no servidor.

| Tela antiga (`/orcamento/*`, dados em JSON) | Onde fica no módulo novo | De onde vêm os dados |
|---|---|---|
| Fornecedores (lista inteira de 4,4 MB no navegador) | Suprimentos › Fornecedores e a ficha do fornecedor | Omie, pelo espelho da `api-acos-vital` (6.185 fornecedores, sincronização a cada 15 min) |
| Categorias | Categorias e certificados na ficha do fornecedor (PR #156) | `core_comercial.categorias_suprimento` |
| Vínculos categoria × fornecedor | Ficha do fornecedor (PR #156); exportar e copiar e-mails por categoria (PR #167) | `core_comercial.fornecedores_categorias` |
| Histórico de produtos (`historicoPrecos.json`) | Histórico de compras (PR #162) e Pesquisa de materiais (PR #163) | Pedidos de compra do Omie e cotações (mapa de cotação, lançamento manual) |
| Sem cadastro | Produtos pendentes, com "Ligar ao Omie" (PR #169) | `core_comercial.produtos` com `pendente = true` |
| Famílias | Família do produto no catálogo, na ficha do produto, no histórico de compras e no Painel do Comprador (cobertura de custo por família) | Família do produto no Omie |

Gambiarras do contrato original:

| # | Gambiarra | Situação |
|---|---|---|
| O1 | Busca de fornecedor em memória no BFF | Resolvida no módulo novo (busca no banco) |
| O2 | Histórico de preços filtrado e ordenado em memória | Resolvida (Histórico de compras e Pesquisa de materiais, no banco) |
| O3 | Lista inteira de fornecedores no navegador | Resolvida (paginação no servidor) |
| O4 | Catálogo inteiro no navegador | Resolvida (catálogo paginado no servidor) |
| O5 | JSON no git e no histórico | **Pendente** (§3) |

## 2. API de orçamento da `api-acos-vital` (`90bdb33`)

As rotas `/orcamento/{fornecedores,produtos,cotacoes,vinculos,categorias,familias}` e as tabelas `core_compras.orc_*` existem na `api-acos-vital`, mas **nenhuma tela do av-hub as chama**: as telas antigas de `/orcamento/*` leem os JSON (`lib/orcamento/dados.ts`), e o módulo novo usa o `api-comercial`.

**Decidir (Nathan + Gustavo):** manter a API de orçamento como está (sem uso) ou removê-la depois da publicação do `api-comercial`. Sugestão: remover depois da publicação, junto com as telas antigas, para não ficarem duas fontes para o mesmo dado.

## 3. O que falta (depois da publicação do `api-comercial`)

| # | O que | Quem |
|---|---|---|
| 1 | Publicar o `api-comercial` (K5) | Nathan + DBA + infra; ver [[AV-Hub-Comercial-Suprimentos]] §7 e §8 |
| 2 | Tirar do av-hub as telas `/orcamento/*`, as rotas `app/api/orcamento/*`, `lib/orcamento/` e os JSON de `lib/orcamento/data/` | Pablo |
| 3 | Desativar em `auth.telas` as telas antigas do orçamento (`categorias`, `historico-produtos`, `sem-cadastro`, `vinculos` e o `fornecedores` do orçamento) | DBA |
| 4 | Decidir se os JSON saem também do **histórico** do git (exige reescrever o histórico do repositório) | Nathan |
| 5 | Opcional: importar as cotações antigas de `historicoPrecos.json` como ofertas de origem `MIGRACAO`, para não perder o histórico de preços | Pablo (junto com a migração do ERP Comercial) |

**⚠️ Conflito de slug a conferir:** o orçamento antigo usa a tela `fornecedores` (em `lib/orcamento/dados.ts`, `TELAS_ORCAMENTO`), e o contrato de telas do Comercial também pede `fornecedores` (em `suprimentos`). Como o slug é único em `auth.telas` e o SQL do contrato usa `WHERE NOT EXISTS`, a tela nova **não seria criada** se a antiga existir, e a URL ficaria `/orcamento/fornecedores`. Antes do cadastro, o DBA confere se `fornecedores` já existe e, se existir, **move** a tela para o pai `suprimentos` (em vez de criar outra).

## 4. Coordenadores do dashboard de comissões (fora do módulo Comercial)

Não muda com a decisão 39: é do dashboard de comissões, não do orçamento.

- **API pronta:** `GET /dashboard/comissoes` (`90bdb33`) com `fn_dashboard_comissoes` sobre `comissao_coordenadores`, **sem bloqueio por NF** para os coordenadores ([[38-Regras-Sem-Chave-de-Ambiente]] §5, chave removida no `c8f2f5e`).
- **Pendente no av-hub:** o dashboard ainda lê `lib/comissoes/coordenadores.json` pela rota `app/api/dashboard/comissoes/coordenadores`, e calcula a comissão no navegador (C1 a C3 do contrato original). Falta trocar para a API e tirar o JSON do repositório. Dono: quem cuida do dashboard de comissões (não definido no Registro).

## 5. Aceite

- Nenhum dado de fornecedor, cotação ou remuneração em arquivo do repositório (`lib/orcamento/data/` e `lib/comissoes/coordenadores.json` removidos).
- Fornecedores, categorias, vínculos, histórico de preços e produtos sem cadastro só pelo módulo Comercial & Suprimentos, com busca e paginação no servidor.
- `/orcamento/*` some do menu e do código; a tela `fornecedores` abre em `/suprimentos/fornecedores`.
- O ranking de comissões (vendedores e coordenadores) vem pronto e ordenado do backend.

---

## Histórico (resumo do texto anterior)

- **20/09/2026:** criado a partir da auditoria de segurança (`docs/seguranca/auditoria-2026-09-19.md`): JSON de orçamento (~5 MB) e de coordenadores no repositório, servidos e filtrados em memória. Pedia tabelas `orc_*`, rotas `/orcamento/*` com paginação no servidor, tabela `comissao_coordenadores` e `GET /dashboard/comissoes`.
- **29/09/2026:** conferido como não entregue na `api-test`.
- **01/10/2026:** desconsiderado pelo Nathan. No mesmo dia, o `90bdb33` (PR #275) implementou na API o orçamento inteiro e os coordenadores.
- **06/10/2026:** bloqueio de comissão dos coordenadores retirado ([[38-Regras-Sem-Chave-de-Ambiente]] §5).
- **07/10/2026:** leitura de código mostrou a divergência; decisão do Nathan (item 39): orçamento desenvolvido por fora, no módulo Comercial & Suprimentos, e contrato a reescrever.
- **08/10/2026:** reescrito (este texto).
