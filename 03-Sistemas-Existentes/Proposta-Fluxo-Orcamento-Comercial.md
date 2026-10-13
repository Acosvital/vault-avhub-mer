---
tags: [erp-acos-vital, av-hub, comercial, suprimentos, api-comercial, proposta]
criado: 2026-10-09
status: aguardando-decisao
atualizado: 2026-10-13
---

# Proposta — Fechar o fluxo do orçamento no Comercial & Suprimentos

> Status: proposto pelo Pablo em 09/10/2026 | **aguardando decisão do Nathan** | nada no código ainda.
> Relacionadas: [[AV-Hub-Comercial-Suprimentos]], PRD v4 (`PRD-AV-Comercial-Suprimentos-v4.md`, seções 5, 11, 12 e 13), [[Entrada-Comercial]], [[Fluxo-Compras-Completo]] (requisição de compra).
>
> **Revisado em 13/10/2026:** a tarefa 1 mudou. A proposta ganha vira **pedido de venda**, não requisição de compra. A compra continua nascendo no MES (setor Estoque sem saldo → requisição), como no [[Fluxo-Compras-Completo]]: "PCP (MES) decide que precisa comprar, Compras (av-hub) decide como comprar".

## 1. Onde o fluxo para hoje

Conferido no código em 09/10/2026 (`av-hub` `develop`, `api-acos-vital` `develop`).

```
1. Cliente pede   2. Vendedor monta     3. Sem custo?        4. Compras cota       5. Custo volta     6. Fechar ou
   orçamento  ──►   a proposta    ──►   pede a Compras ──►   os fornecedores ──►   à proposta   ──►   perder
                    ✅                  ✅                   🟡 parcial            ✅                 ✅
                                                                                                        │
                                                                                                        ▼
                                  7. Pedido de venda no Omie  ──►  Ato 1b em diante: liberação com Qualidade
                                     ❌ vendedor redigita tudo        sim/não → PCP → Estoque do MES → requisição
                                                                      → Compras do Hub (OC)
```

- **Pronto:** proposta com custo sugerido (menor custo líquido ou média de 90 dias, respeitando CRC e certificados), pedido de custo do vendedor a Compras, PDF, e-mail, fechamento total ou por itens, linha do tempo.
- **Parcial (passo 4):** o pedido de cotação manda um e-mail por fornecedor, mas a resposta não volta ao sistema. O comprador lança a oferta à mão ou importa o mapa.
- **Falta (passo 7):** fechar a proposta não prepara o pedido de venda. O vendedor redigita cliente, itens e condições no Omie.

As três tarefas abaixo estão no PRD v4. A 1 e a 2 são da fase 4.1 (o MVP fechou a paridade com os sistemas antigos); nenhuma trava a publicação do `api-comercial` (K5).

## 2. As três tarefas

### Tarefa 1 — Proposta ganha → pedido de venda preparado para o Omie · fluxo [[Entrada-Comercial]]

**Problema:** o fluxo do Comercial para no fechamento. O pedido de venda é a Fase 1 do fluxo operacional (nasce no Omie e chega ao av-hub pelo ELT), mas o vendedor redigita tudo o que já está na proposta.

**Decisão (13/10/2026):** nesta fase o av-hub **não** cria o pedido no Omie pela API. Ele **prepara** o pedido para o vendedor digitar.

**Entrega:**
- Na proposta ganha, "Preparar pedido no Omie" com:
  - conta Omie (Mogi/Uberaba);
  - cliente, condição de pagamento, frete e previsão;
  - itens com o código do produto no Omie (com aviso quando o produto não tem cadastro), quantidades e preços.

  O vendedor copia campo a campo ou baixa em .xlsx.
- Campo **acompanhamento da Qualidade (sim/não)** na proposta, para o vendedor já levar a decisão. A marcação oficial continua na liberação do pedido no av-hub (tela 1.1, contrato [[26-Vendas-Liberacao-Pedido]]).
- Campo opcional **nº do pedido no Omie**, que liga a proposta ao pedido que volta pelo ELT.
- O saldo do estoque do MES aparece só como **consulta**, se houver endpoint de leitura. Quem confere e reserva é o setor Estoque do MES (etapa 1 de todo roteiro), depois da liberação.

**Fora do escopo:**
- gerar a compra a partir da proposta, porque a compra nasce no MES;
- criar o pedido no Omie pela API (`IncluirPedido`), que fica para uma fase seguinte.

**Depende de:** nada externo.

**Estimativa (Pablo):** ~2 pd, com testes.

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
| 1 | Proposta ganha → pedido de venda preparado | Liga o Comercial à Fase 1 do fluxo | ~2 pd | — | Criar no Omie pela API numa fase seguinte? |
| 3 | Painel de margem | Gestão vê prejuízo antes de mandar | ~2 pd | — | Parâmetros e limites das letras |
| 2 | Cotação com resposta e mapa | Tira a digitação do comprador; auditoria ISO | 4 a 5 pd | — | — |

**Total:** 8 a 9 pd do Pablo.

**Ordem sugerida:** 1 (é o elo que falta), depois 3 (pequena e com valor para a gestão), depois 2.

## 4. O que preciso do Nathan

1. **Entram?** Quais das três, e se entram **antes** ou **depois** da publicação do `api-comercial` (K5). Nenhuma trava a publicação.
2. **Ordem:** a sugerida acima ou outra.
3. **Tarefa 1:** numa fase seguinte, o av-hub deve criar o pedido direto no Omie pela API (`IncluirPedido`), ou o vendedor continua digitando a partir do resumo?
4. **Tarefa 3:** os parâmetros do simulador de comissões valem para a margem da proposta? Quem define os limites das letras A–D e do status `NEGOCIAR` (Diretoria comercial)?
