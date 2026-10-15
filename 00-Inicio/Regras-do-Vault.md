---
tags: [vault, regras]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [plano de 14/10/2026]
---

# Regras do vault

Este vault é o **manual para desenvolver o fluxo de Atividades** do ERP Aços Vital (diagrama 0b). O vault anterior (`vault-avhub-mer`) está congelado, só para consulta. Aqui vale uma regra: **cada nota diz o estado atual**, sem camadas de histórico.

## Fontes da verdade, em ordem

1. **Código** nos branches atuais: `api-pcp` 579a625, `app-pcp` 1fca8d3, `api-acos-vital` f322dcd, HUB b55ac55 (front av-hub), `omie-elt-pipeline` 0f739f0 (todos de 14/10/2026).
2. **Dumps de esquema** de 14/10/2026 (MES e av-hub).
3. **Decisões** em [[Registro-de-Decisoes]].
4. **O fluxo mestre** em [[00-Fluxo-Mestre-0b]].
5. O vault anterior, só quando não conflita com 1 a 4.

## Selos de confiança (toda afirmação relevante leva um)

| Selo | Significado |
|---|---|
| ✅ | Está no código (cite arquivo:linha ou commit) |
| 📝 | Decidido (cite o ID da decisão) |
| 🟡 | Proposta, ainda sem decisão |
| 🔴 | Aberto ou sem código |
| ❓ | Não conferido em produção |

## Frontmatter obrigatório

```yaml
---
tags: [...]
criado: 2026-10-14
atualizado: AAAA-MM-DD
status: vigente | proposta | arquivado
dono: Nathan | Robert | Gustavo (DBA) | Pablo | Compras | ...
fontes: [notas do v1, arquivo:linha, commits]
---
```

## Regras de escrita

- **Nada de "atualizado em" empilhado, nada de texto riscado (`~~`).** O histórico fica no git do v2 e no vault anterior. Quando algo muda, reescreva a nota.
- Escreva em português, direto. Um fato por frase. Valores de enum, rotas e nomes de tela exatos, em `código`.
- Use `[[links]]` do Obsidian entre notas. Todo link tem de resolver.
- Diagramas em mermaid. Cada diagrama de fluxo usa os mesmos IDs de nó do [[00-Fluxo-Mestre-0b]].
- **Nomes de telas:** Triagem do Pedido (antiga Carteira, rota `/carteira`), Destinação do Pedido (antiga "Nova Ordem de Produção", rota `/ordens-producao/novo`), Acompanhamento dos Pedidos (antiga lista de Ordens de Produção). O código ainda usa os nomes antigos em alguns pontos; registre as duas formas.

## Divisão de trabalho (para as pendências)

- **Gustavo (DBA):** banco e API do av-hub (`api-acos-vital`).
- **Nathan:** front do av-hub (telas e BFF).
- **Robert:** MES (`api-pcp` e `app-pcp`).
- **Pablo:** Comercial & Suprimentos (`api-comercial`).

## Contratos

- IDs únicos: `SQL-007`, `API-004`, `LOG-34`. O número original é preservado; duplicados ganham letra (`LOG-04a`, `LOG-04b`).
- Pastas: `Ativos/` (a fazer ou parcial), `Entregues/` (feito no código ou aplicado), `Arquivados/` (superado, fora de escopo ou histórico) e `Consultas/`.
- **Contrato de Consulta (`CON-NN`):** tipo que pede uma **resposta**, não uma mudança. Dá contexto e um cenário, faz perguntas numeradas a quem conhece o assunto e traz uma mensagem pronta para o WhatsApp; as respostas voltam pelo WhatsApp do Nathan e são registradas na própria nota. Modelo e regras em [[Modelo-de-Consulta]].
- O texto do contrato é copiado inteiro. Só o frontmatter e um bloco "Situação em 14/10" no topo são acrescentados.
- Todo contrato novo ou seção nova entra **completo** em `06-Contratos/` e no [[Painel-de-Contratos]].
- Vocabulário de status: `proposta`, `para-implementar`, `parcial`, `implementado-no-codigo`, `aplicado-em-producao`, `arquivado`.

## Esquemas de banco

- **MES:** tudo no schema `public` (decisão #21).
- **av-hub:** dividido em schemas por domínio: `core_*`, `auth`, `historico`, `omie_*`.
