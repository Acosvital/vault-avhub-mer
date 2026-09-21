---
tags: [erp-acos-vital, fluxo-operacional, fabricacao]
criado: 2026-09-16
---

# Fabricação — Flanges

Sub-rota da [[Rota-Fabricacao]] roteada para um sistema próprio dedicado de cálculo e parâmetros técnicos de flange: o [[App-PCP-Visao-Geral|app-pcp]] (ainda em construção, Robert).

## Modelo real (visto no código do app-pcp)

- Pedido → itens → cada item atribuído a uma **fábrica**.
- Cada fábrica tem um **roteiro**: sequência ordenada de **setores** pelos quais o item passa (routing clássico de PCP/MRP).
- Cadastros operacionais: fábricas, setores, máquinas, operadores.
- Um setor pode `exigirMaquinaOperador` (campo já existe no schema, mas ainda sem formulário — apontamento de produção ainda não implementado).

Ver [[App-PCP-Modelo-Producao]] para detalhes completos.

## Candidato a piloto de RFID

No [[PRD-Estoque-Visao-Geral|PRD do Estoque]], a flange é citada como candidata natural a um piloto de RFID (maior valor unitário) — mas com ressalva técnica: precisa de tag *on-metal*, e a taxa de leitura real precisa ser validada antes de qualquer decisão de escala. Ver [[Estoque-Riscos]].

## Ver também
- [[Rota-Fabricacao]]
- [[App-PCP-Visao-Geral]]
