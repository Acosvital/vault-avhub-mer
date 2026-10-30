---
tags: [vault, regras]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [plano de 14/10/2026]
---

# Regras do vault

**Em uma frase:** são as regras para escrever e manter as notas, para o vault continuar curto, correto e fácil de ler.

**Quando consultar esta nota:** antes de criar ou editar qualquer nota.

Este vault é o **manual para desenvolver o fluxo de Atividades** do ERP Aços Vital (diagrama 0b). O vault anterior (`vault-avhub-mer`) está congelado e serve só para consulta. Aqui vale uma regra central: **cada nota diz o estado atual**, sem camadas de histórico.

## Como escrever

- Escreva em português, direto. Uma ideia por frase.
- Abra a nota com "**Em uma frase:**". Quando fizer sentido, acrescente "**Quando consultar esta nota**".
- Não empilhe "atualizado em" e não use texto riscado (`~~`). O histórico fica no git do v2 e no vault anterior. Quando algo muda, reescreva a nota.
- Valores de enum, rotas e nomes de tela vão exatos, em `código`.
- Ligue as notas com `[[links]]` do Obsidian. Todo link tem de resolver.
- Faça os diagramas em mermaid. Cada diagrama de fluxo usa os mesmos IDs de nó do [[00-Fluxo-Mestre-0b]].
- Em nota longa, o resumo vem no topo. Caminhos de código, colunas, rotas e contas ficam numa seção "Detalhe técnico" no fim (pedido do Nathan, 29/10/2026).

## Selos de confiança

Toda afirmação relevante leva um selo.

| Selo | Significado |
|---|---|
| ✅ | Está no código (cite arquivo:linha ou commit) |
| 📝 | Decidido (cite o ID da decisão) |
| 🟡 | Proposta, ainda sem decisão |
| 🔴 | Aberto ou sem código |
| ❓ | Não conferido em produção (no av-hub, só dashboards, aprovação de vagas e telas da gerência estão em produção; o resto está em teste) |

## Nomes de telas

Use o nome novo. O código ainda usa o antigo em alguns pontos, então registre as duas formas.

| Nome novo | Nome antigo | Rota |
|---|---|---|
| Triagem do Pedido | Carteira | `/carteira` |
| Destinação do Pedido | Nova Ordem de Produção | `/ordens-producao/novo` |
| Acompanhamento dos Pedidos | Lista de Ordens de Produção | |

## O perfil `Admin (Dev)` não é ator

`Admin (Dev)` é um perfil de **teste** do time de TI (Nathan, Robert, Pablo e Gustavo), com permissão a tudo. Quem o tem não atua no sistema.

**Não liste esse perfil como ator** em "Quem atua", em diagramas ou em tabelas de papéis. Ele só aparece onde o fato é técnico. Exemplo: "a migration concede a tela só ao perfil de testes", o que mostra que nenhum perfil de negócio recebeu a permissão.

## Divisão de trabalho (para as pendências)

- **Gustavo (DBA):** banco e API do av-hub (`api-acos-vital`).
- **Nathan:** front do av-hub (telas e BFF, a camada que liga o front à API).
- **Robert:** MES (`api-pcp` e `app-pcp`) e, desde 28/10/2026, as rotas do módulo comercial na `api-acos-vital` (N16-117).
- **Pablo:** acompanha o módulo comercial e cuida do Orçamento, com a supervisão do Robert. A `api-comercial` dele é só legado de consulta.

## Contratos

Contrato é o combinado por escrito entre dois sistemas ou entre duas pessoas sobre uma entrega.

- Todo contrato novo ou seção nova entra **completo** em `06-Contratos/` e no [[Painel-de-Contratos]].
- O texto do contrato é copiado inteiro. Só o frontmatter, um bloco "Resumo em linguagem natural" (o que é, quem é afetado, situação) e um bloco "Situação em DD/MM" no topo são acrescentados.
- Os IDs são únicos: `SQL-007`, `API-004`, `LOG-34`. O número original é preservado. Os duplicados ganham letra (`LOG-04a`, `LOG-04b`).
- Os contratos de **Consulta** (`CON-NN`) pedem uma **resposta**, não uma mudança. Dão o contexto e um cenário, fazem perguntas numeradas e trazem uma mensagem pronta para o WhatsApp. As respostas voltam pelo WhatsApp do Nathan e são registradas na própria nota. Modelo e regras em [[Modelo-de-Consulta]].

## Detalhe técnico

### Fontes da verdade, em ordem

1. **Código** nos branches atuais. Os commits da auditoria de 14/10/2026 foram: `api-pcp` 579a625, `app-pcp` 1fca8d3, `api-acos-vital` f322dcd, HUB b55ac55 (front av-hub), `omie-elt-pipeline` 0f739f0. Na dúvida, vale o branch atual, não esses commits.
2. **Dumps de esquema** de 14/10/2026 (MES e av-hub).
3. **Decisões** em [[Registro-de-Decisoes]].
4. **O fluxo mestre** em [[00-Fluxo-Mestre-0b]].
5. O vault anterior, só quando não conflita com 1 a 4.

### Frontmatter obrigatório

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

### Contratos: pastas e status

- Pastas: `Ativos/` (a fazer ou parcial), `Entregues/` (feito no código ou aplicado), `Arquivados/` (superado, fora de escopo ou histórico) e `Consultas/`.
- Vocabulário de status: `proposta`, `para-implementar`, `parcial`, `implementado-no-codigo`, `aplicado-em-producao`, `arquivado`.

### Esquemas de banco

- **MES:** tudo no schema `public` (decisão #21).
- **av-hub:** dividido em schemas por domínio: `core_*`, `auth`, `historico`, `omie_*`.
