---
tags: [erp-acos-vital, av-hub, comercial, suprimentos, api-comercial, proposta]
criado: 2026-10-09
status: aguardando-decisao
atualizado: 2026-10-09
---

# Proposta — Fechar o fluxo do orçamento no Comercial & Suprimentos

> Status: proposto pelo Pablo em 09/10/2026 | **aguardando decisão do Nathan** | nada no código ainda.
> Relacionadas: [[AV-Hub-Comercial-Suprimentos]], PRD v4 (`PRD-AV-Comercial-Suprimentos-v4.md`, seções 5, 11, 12 e 13), [[Fluxo-Compras-Completo]] (requisição de compra).

## 1. Onde o fluxo para hoje

Conferido no código em 09/10/2026 (`av-hub` `develop`, `api-acos-vital` `develop`).

```
1. Cliente pede   2. Vendedor monta     3. Sem custo?        4. Compras cota       5. Custo volta     6. Fechar ou
   orçamento  ──►   a proposta    ──►   pede a Compras ──►   os fornecedores ──►   à proposta   ──►   perder
                    ✅                  ✅                   🟡 parcial            ✅                 ✅
                                                                                                        │
8. Preço pago volta ao histórico  ◄──  7. Requisição e OC no Compras do Hub  ◄──────────────────────────┘
   ✅ (liga com a chave do Omie)          ❌ nada liga a proposta fechada à compra
```

- **Pronto:** proposta com custo sugerido (menor custo líquido ou média de 90 dias, respeitando CRC e certificados), pedido de custo do vendedor a Compras, PDF, e-mail, fechamento total ou por itens, linha do tempo.
- **Parcial (passo 4):** o pedido de cotação manda um e-mail por fornecedor, mas a resposta não volta ao sistema. O comprador lança a oferta à mão ou importa o mapa.
- **Falta (passo 7):** fechar a proposta não gera nada em Compras. O comprador abre a requisição à mão.

As três tarefas abaixo estão no PRD v4. A 1 e a 2 são da fase 4.1 (o MVP fechou a paridade com os sistemas antigos); nenhuma trava a publicação do `api-comercial` (K5).

## 2. As três tarefas

### Tarefa 1 — Necessidade de compra (proposta fechada → requisição) · PRD §13.1, jornada J5

**Problema:** o fluxo para no fechamento. O comprador fica sabendo da venda por fora e digita a requisição de novo.

**Entrega:**
- Ao fechar (total ou por itens), cada item fechado vira uma **necessidade de compra**: produto, quantidade, fornecedor e oferta de referência, custo de referência, prazo e **unidade compradora** (AV → Mogi; AU → Uberaba; HRM → Mogi, decisão de Compras de 24/09 no PRD).
- Tela `Suprimentos › Necessidades de compra`: fila por unidade, com **"Gerar requisição"** (uma ou várias) e cancelar.
- Status: `PENDENTE` → `REQUISICAO_GERADA` → `OC_EMITIDA` → `ATENDIDA` / `CANCELADA`. Reabrir ou perder a proposta cancela as pendentes.
- Na proposta e na necessidade: número da requisição e da OC, com link para o Compras do Hub.

**Como liga com o Compras do Hub:** a `api-acos-vital` **já tem** `POST /compras/requisicoes` (criação manual) com `id_origem` único entre as requisições vivas. O `api-comercial` manda a necessidade com `id_origem` = id da necessidade, então uma nova tentativa não duplica. O status da OC volta lendo a requisição.

**Depende de (contrato C-01, Gustavo):** o `id_origem` hoje é "id da requisição no MES". Para não misturar as origens, pedir um campo **`origem`** (`MES` | `COMERCIAL`) na requisição, ou confirmar que dá para reaproveitar o `id_origem` como está. Estimativa do lado do Gustavo: ~0,5 pd.

**Fora do escopo:** atender pelo estoque (v4.2) e agrupamento automático de necessidades iguais.

**Estimativa (Pablo):** 3 a 4 pd, com testes unitários, de integração e de tela.

### Tarefa 2 — Cotação com resposta do fornecedor e mapa comparativo · PRD §11.2 e §11.3, jornada J2

**Problema:** o pedido de cotação sai por e-mail, mas a resposta volta para o e-mail do comprador e é digitada à mão. Não há comparação lado a lado nem registro de por que o vencedor foi escolhido (ISO 9001, 8.4).

**Entrega (versão enxuta da RFQ do PRD):**
- O pedido de cotação passa a ser **gravado** (número `RFQ-AAAA-NNNN`, itens, fornecedores convidados, prazo) e pode nascer das solicitações de custo abertas.
- **Resposta por fornecedor:** lançada na tela ou importada da planilha que foi anexada ao e-mail (o mesmo modelo). Preço, IPI, ICMS, frete, prazo, validade e lote mínimo; resposta parcial permitida.
- **Mapa comparativo:** itens × fornecedores, com o custo líquido de cada um, o menor destacado e os totais. Escolha por item; **justificativa obrigatória se não for o menor custo**.
- **Concluir:** todas as respostas viram ofertas (nova fonte `COTACAO`; as perdedoras também são preço de mercado), e as solicitações de custo ligadas ficam respondidas, com aviso ao vendedor.
- PDF do mapa para auditoria.

**Fora do escopo:** portal do fornecedor (v4.3), sugestão de convidados por IQF (v4.1, depende da homologação) e simulações "fornecedor único" e "melhor prazo".

**Depende de:** nada externo. O e-mail já existe (falta o SMTP da TI, como hoje).

**Estimativa (Pablo):** 4 a 5 pd, com testes.

### Tarefa 3 — Painel de margem na proposta · PRD §12.2 (RN-170 a RN-179)

**Problema:** o vendedor só vê a margem real no PDF de aprovação interna. A gestão não tem como ver na lista quais propostas estão no prejuízo.

**Entrega:**
- No formulário: por item e na proposta, venda líquida, custo líquido, lucro, **margem líquida %**, status `PREJUÍZO` / `NEGOCIAR` / `OK` e **letra A–D**.
- No histórico: filtro "abaixo da margem" para a gestão.
- Só para quem vê custo (mesma regra de hoje).

**Como calcula:** com os parâmetros que o Hub já usa no simulador de comissões (`core_comissionamento.simulador_parametros`: despesas fixas, PIS/COFINS, IRPJ, CSLL, ICMS de saída por UF, encargo da condição de pagamento). A `api-acos-vital` **já tem** `GET /simulador_parametros`.

**Fora do escopo:** preço sugerido pelo método `MARKUP_HUB` e comissão estimada (v4.2); fila de aprovação de margem (v4.1).

**Depende de:** confirmar que esses parâmetros valem para a margem da proposta (ou se a Diretoria quer outros), e os limites de cada letra e status.

**Estimativa (Pablo):** ~2 pd, com testes.

## 3. Resumo e ordem sugerida

| # | Tarefa | Valor | Pablo | Outros | Decisão pendente |
|---|---|---|---|---|---|
| 1 | Necessidade de compra → requisição | Fecha o fluxo de ponta a ponta | 3 a 4 pd | ~0,5 pd Gustavo (C-01) | Campo `origem` na requisição |
| 3 | Painel de margem | Gestão vê prejuízo antes de mandar | ~2 pd | — | Parâmetros e limites das letras |
| 2 | Cotação com resposta e mapa | Tira a digitação do comprador; auditoria ISO | 4 a 5 pd | — | — |

**Total:** 9 a 11 pd do Pablo + ~0,5 pd do Gustavo.

**Ordem sugerida:** 1 (é o elo que falta), depois 3 (pequena e com valor para a gestão), depois 2.

## 4. O que preciso do Nathan

1. **Entram?** Quais das três, e se entram **antes** ou **depois** da publicação do `api-comercial` (K5). Nenhuma trava a publicação.
2. **Ordem:** a sugerida acima ou outra.
3. **Tarefa 1:** ok para abrir o contrato C-01 com o Gustavo (campo `origem` na requisição de compra)?
4. **Tarefa 3:** os parâmetros do simulador de comissões valem para a margem da proposta? Quem define os limites das letras A–D e do status `NEGOCIAR` (Diretoria comercial)?
