---
tags: [erp-acos-vital, av-hub, comissao]
criado: 2026-09-16
---

# av-hub — Módulo de Comissionamento (backend real, `core_comissionamento`)

No backend `api-acos-vital` existe um schema Postgres inteiro dedicado a comissionamento, com bem mais estrutura do que o protótipo frontend ([[AV-Hub-Simulador-Comissao]]) sugeria. Isso muda a pergunta em aberto de "[[Decisoes-Chave-ERP|Simulador de Comissão é a mesma coisa que o projeto Python de automação, ou são paralelos?]]": existe pelo menos um **terceiro** pedaço da resposta, um schema de produção já em uso.

## Tabelas/views

- **`regra_comissao_fixa`** — regras de comissão fixa (não a fórmula de markup/margem do simulador — outra dimensão).
- **`blacklist_comissao_vendedor`** / **`blacklist_comissao_destinatario`** — bloqueio binário (presença = bloqueia), por código Omie. **Não confundir com `blacklist_vendedor_g5`/`blacklist_destinatarios`** (schema `core_vendas_faturamento`, usadas na cascata G4/G5 de dedução de venda líquida) — são pares paralelos, mesma ideia (bloquear por vendedor/destinatário), propósitos diferentes (comissão vs. classificação de venda líquida).
- **`bloqueio_comissao`** — bloqueio de comissão (motivo mais amplo que blacklist simples, presumivelmente por pedido/nota específica).
- **`simulacao`** / **`simulacao_item`** — simulações salvas (não é só o cálculo client-side do protótipo — há um modelo de persistência).
- **`simulador_parametro`** — parâmetros configuráveis do simulador (ICMS por UF, markup, etc. — o que hoje está hardcoded em `_data/referencia.ts` no frontend pode já ter um lar no backend).
- **`comissao_provisoria`** (schema `core_vendas_faturamento`) — comissão provisória, provavelmente o valor calculado antes do fechamento oficial.
- **`vw_simulacao_resolvida`** — view que resolve o percentual final: `pct_final = LEAST(pct_vendedor, pct_compras)`, documentada explicitamente como "resolução, não cálculo" (ou seja, o cálculo em si acontece em outro lugar; esta view só decide qual das duas partes prevalece).

## Por que isso importa

O [[AV-Hub-Simulador-Comissao|Simulador de Comissão]] no frontend é hoje **100% local/protótipo**, sem gravar em banco. Mas o backend já tem schema pronto para simulação persistida, regras fixas, bloqueios e parâmetros configuráveis — sugere que a evolução natural do protótipo não é "construir uma API do zero", é "conectar o protótipo já validado a uma estrutura que já existe". Vale esclarecer com o time se `core_comissionamento` já é consumido por algum outro cliente (o projeto Python de automação de comissão, talvez?) antes de decidir a próxima etapa do simulador.

## Ver também
- [[AV-Hub-Simulador-Comissao]]
- [[AV-Hub-Vendas-Reconciliacao]]
- [[Decisoes-Chave-ERP]]
- [[Schema-Postgres-Multi-Dominio]]
