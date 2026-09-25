---
tags: [erp-acos-vital, fluxo-operacional]
criado: 2026-09-16
---

# Fluxo Operacional — Visão Geral

Mapa macro do processo operacional da Aços Vital, da venda até a expedição. Estrutura-se em **quatro fases principais**: [[Entrada-Comercial|entrada comercial]], [[PCP-Carteira|triagem no PCP]], rotas de atendimento ([[Rota-Estoque|estoque]], [[Rota-Revenda|revenda]] ou [[Rota-Fabricacao|fabricação]]) e [[Faturamento-Expedicao|faturamento/expedição]].

> **Confirmado com o usuário (17/09/2026):** só a fase 1 (entrada comercial — pedido no Omie, sincronizado pro av-hub) está em produção hoje. A partir da fase 2 (triagem no PCP) em diante, **nada existe em sistema nenhum** — é o processo-alvo que o projeto de ERP unificado precisa construir. Ver ressalva igual, com mais detalhe, em [[Fluxo-Detalhado-Pedido-Item]].

## Diagrama (visão macro/conceitual)

> Este diagrama é a visão **macro/conceitual** do fluxo — três categorias de destinação de item. Existe uma segunda visão, **operacional/detalhada, item a item** (com PCP verificando estoque como primeiro passo dentro de Revenda/Fabricação, emissão de OS/OP, fluxo de Compras/Recebimento/Qualidade passo a passo) em [[Fluxo-Detalhado-Pedido-Item]] — as duas coexistem deliberadamente como modelos complementares, não uma substitui a outra. Chapas **não** é Fabricação, é beneficiamento de Revenda — ver [[Fabricacao-Chapas]].
>
> **Reconciliação formal dos dois modelos:** ver [[Modelo-Destinacao-Item]] — "Estoque" aqui não é um quarto ramo do mesmo tipo que Revenda/Fabricação; é o cruzamento "pronto em estoque" dentro de qualquer uma das duas outras categorias.
>
> **Redesenhado em 24/09/2026** com o encaixe do MES ([[Encaixe-Estoque-Revenda-no-PCP]]): o Estoque deixou de ser um ramo ao lado dos outros dois e virou a **etapa 1 de todo roteiro**; a Revenda é uma fábrica; e o item comprado, aprovado na Qualidade, **volta ao Estoque** antes de sair.

```
[Vendas: Pedido no Omie]
          │
          ▼
[Hub / Tela de Pedidos]
          │
          ▼
[PCP: Carteira de Pedidos → Ordem de Produção]
 (por rodada: itens, quantidades e fábrica; 1 OP por fábrica)
          │
          ▼
[ESTOQUE — etapa 1 de todo roteiro]
 saldo na filial do pedido ── split atendido: reserva + conclusão ──────────┐
          │ restante                                                        │
   ┌──────┴──────────────────────────┐                                      │
   ▼                                 ▼                                      │
[FÁBRICA REVENDA]              [FÁBRICA DE FABRICAÇÃO]                      │
Setor Compras (requisição)     Setores produtivos da linha                  │
OC + follow-up (CCP)           (Flanges hoje; Grade de Piso,                │
Recebimento/Quarentena          Chapa Expandida, Caldeiraria                │
Beneficiamento (corte de        etc. conforme cadastradas —                 │
 chapa, quando aplicável)       ver Rota-Fabricacao)                        │
Inspeção de Qualidade          Inspeção de Qualidade                        │
   │ aprovado                        │                                      │
   ▼                                 │                                      │
[ESTOQUE — entrada + reserva]        │                                      │
   │                                 │                                      │
   └───────────────┬─────────────────┴──────────────────────────────────────┘
                   ▼
     [Faturamento: Parcial ou Integral]
                   │
                   ▼
              [Logística]
```

## As quatro fases

1. **[[Entrada-Comercial|Entrada e Triagem Comercial]]** — vendedor cadastra no Omie, o Hub captura via API.
2. **[[PCP-Carteira|Gestão de Carteira (PCP)]]** — abertura dos itens e escolha da fábrica (linha de fabricação ou Revenda) por rodada.
3. **Roteamento e processamento** — Estoque como etapa 1 de todo roteiro ([[Rota-Estoque]]), depois o roteiro da fábrica: [[Rota-Revenda]] (que termina de novo no Estoque) ou [[Rota-Fabricacao]].
4. **[[Faturamento-Expedicao|Faturamento e Expedição]]** — parcial ou integral, depois logística.

## Observação estrutural central

A entidade central do fluxo não é "o pedido" como bloco monolítico, mas o **item do pedido dentro da carteira**: é ele quem carrega a classificação de rota e o status individual — a agregação desses status por pedido é que decide entre faturamento parcial ou integral. Essa mesma lógica de consolidação bottom-up aparece em outro contexto no [[AV-Hub-Vendas-Reconciliacao|Waterfall de dedução da Venda Líquida]].

## Ver também
- [[Encaixe-Estoque-Revenda-no-PCP]] — o encaixe do Estoque e da Revenda no roteiro do MES (24/09/2026).
- [[Modelo-Destinacao-Item]] — reconciliação formal entre este diagrama e o fluxo detalhado.
- [[Fluxo-Detalhado-Pedido-Item]] — o mesmo fluxo, no nível operacional de item.
- [[PRD-Estoque-Visao-Geral]] — cobre os ramos Estoque e Revenda deste fluxo.
- [[App-PCP-Visao-Geral]] — cobre o ramo Fabricação → Flanges.
- [[Decisoes-Chave-ERP]]
