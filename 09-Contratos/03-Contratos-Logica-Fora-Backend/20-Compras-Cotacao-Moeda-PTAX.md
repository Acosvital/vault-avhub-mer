# Contrato — Cotação de moeda automática (PTAX do Banco Central) na Ordem de Compra

**Criado em:** 23/09/2026.

**Objetivo:** quando o comprador emite uma OC em moeda estrangeira (USD ou EUR), o campo
**Cotação** vir preenchido sozinho com a cotação oficial do dia. Hoje o comprador digita à mão
(`components/Compras/FecharCompra.tsx`, campo `cotacao_moeda`, obrigatório quando
`moeda !== 'BRL'`).

**Por que importa:** a cotação decide três coisas que ficam gravadas na OC:
- `valor_total_brl` (calculado pelo banco = `valor_total × cotacao_moeda`);
- a régua de aprovação, que roda sobre `valor_total_brl`: uma cotação digitada errada pode fazer
  a OC pular a aprovação;
- os valores em R$ que vão para o Omie, que não tem campo de moeda
  (`ENVIAR - contrato-compras-omie-pedidocompra.md`, §3.3).

**Regra do projeto:** buscar cotação é integração externa, então fica no backend. O navegador só
mostra a sugestão e deixa editar.

---

## 1. A fonte: PTAX do Banco Central (API Olinda)

Pública, gratuita, **sem chave**. Testada em 23/09/2026: devolveu os boletins de USD de 18/09 a
23/09/2026 (fechamento de 18/09: compra 5,1569, venda 5,1575).

```
GET https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/
    CotacaoMoedaPeriodo(moeda=@moeda,dataInicial=@dataInicial,dataFinalCotacao=@dataFinalCotacao)
    ?@moeda='USD'&@dataInicial='09-18-2026'&@dataFinalCotacao='09-23-2026'
    &$format=json&$select=cotacaoCompra,cotacaoVenda,dataHoraCotacao,tipoBoletim
```

- Datas no formato **`MM-DD-AAAA`** (americano).
- Resposta: `value[]` com `cotacaoCompra`, `cotacaoVenda`, `dataHoraCotacao` e `tipoBoletim`.
- Cada dia útil tem vários boletins: `Abertura`, alguns `Intermediário` e o **`Fechamento`**
  (por volta das 13h). O `Fechamento` é a PTAX oficial do dia.
- **Fim de semana e feriado não têm boletim.** Vale o último fechamento anterior.
- Serve para USD, EUR e as demais moedas do Banco Central (lista em `.../odata/Moedas`).

## 2. Banco (DBA)

Tabela genérica em `core`, porque cotação não é só de compras (serve também para comissão,
dashboard ou qualquer valor em moeda estrangeira):

```sql
CREATE TABLE core.cotacoes_moeda (
  id                uuid PRIMARY KEY DEFAULT uuidv7(),
  moeda             varchar(3)    NOT NULL,   -- 'USD', 'EUR'
  data              date          NOT NULL,   -- dia da cotação
  cotacao_compra    numeric(14,6) NOT NULL,
  cotacao_venda     numeric(14,6) NOT NULL,
  data_hora_boletim timestamptz   NOT NULL,   -- dataHoraCotacao do boletim de fechamento
  fonte             varchar(20)   NOT NULL DEFAULT 'PTAX_BCB',
  created_at        timestamptz   NOT NULL DEFAULT now(),
  updated_at        timestamptz   NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_cotacoes_moeda_moeda_data
  ON core.cotacoes_moeda (moeda, data);
```

- **Só o boletim de `Fechamento`** é gravado, um por moeda por dia útil.
- Na OC, guardar **de onde veio a cotação**, para auditoria e para o bloco AV-HUB do Omie:

```sql
ALTER TABLE core_vendas_faturamento.ordens_compra
  ADD COLUMN cotacao_data   date,          -- dia da PTAX usada (null se digitada)
  ADD COLUMN cotacao_origem varchar(10);   -- 'ptax' | 'manual'; null quando moeda = BRL
```

## 3. Job (`omie-elt-pipeline`)

A pipeline já tem agendamento (BullMQ) e já roda jobs diários. Recurso novo, fora do Omie:

- **Quando:** dias úteis às **13h30** e de novo às **17h** (se o fechamento atrasar). O
  segundo rodar é só uma nova tentativa: o upsert não duplica.
- **O que busca:** `CotacaoMoedaPeriodo` dos **últimos 7 dias**, para cada moeda configurada
  (`USD`, `EUR`). A janela de 7 dias cobre feriado e falha de um dia sem código extra.
- **O que grava:** só `tipoBoletim = 'Fechamento'`, upsert em `(moeda, data)`.
- **Carga inicial:** desde 01/01/2026 (uma chamada por moeda com o período inteiro).
- **Falha na API do BC:** registrar e tentar no próximo horário. Não pode derrubar os jobs do
  Omie.

## 4. API (`api-acos-vital`)

```
GET /cotacoes_moeda/atual?moeda=USD
→ 200 {
    "moeda": "USD",
    "data": "2026-09-22",
    "cotacao_compra": 5.1105,
    "cotacao_venda": 5.1111,
    "data_hora_boletim": "2026-09-22T13:04:10-03:00",
    "fonte": "PTAX_BCB"
  }
→ 404 se não houver nenhuma cotação daquela moeda
```

- "Atual" = o fechamento mais recente com `data <= hoje` (fuso de São Paulo). Antes das 13h,
  ou em fim de semana, devolve o último dia útil. **A data sempre vem na resposta**, para a
  tela mostrar de quando é.
- `GET /cotacoes_moeda?moeda=USD&data=2026-09-18`: o fechamento de um dia específico (ou do
  último dia útil antes dele). Serve para conferir uma OC antiga.
- `POST /compras/ordens` passa a aceitar `cotacao_data` e `cotacao_origem`. Se
  `cotacao_origem = 'ptax'`, validar que `cotacao_moeda` é igual à `cotacao_venda` gravada para
  aquela `moeda` e `cotacao_data` (senão, gravar como `manual`).

## 5. O que muda no av-hub

- BFF: `GET /api/compras/cotacao?moeda=USD`, repassando a rota acima.
- `FecharCompra.tsx`: ao escolher USD ou EUR, busca a cotação e **preenche** o campo, com a
  legenda "PTAX venda de 22/09/2026 (Banco Central)". O comprador **pode alterar**. Se alterar,
  a legenda vira "Cotação digitada" e a OC vai com `cotacao_origem = 'manual'`.
- Se a rota falhar ou devolver 404, o campo fica vazio e obrigatório, como hoje. Nunca bloqueia
  a emissão.
- Detalhe da OC: mostrar a origem da cotação ao lado do valor ("PTAX de 22/09/2026" ou
  "digitada").
- Bloco `[AV-HUB]` do `cObsInt` no Omie
  (`ENVIAR - contrato-compras-omie-pedidocompra.md`, §3.8): a linha de moeda passa a dizer a
  origem, ex.: `Moeda: USD | Cotação: 5,111100 (PTAX venda 22/09/2026)`.

## 6. Decisões em aberto (financeiro)

1. **Compra ou venda?** Numa compra em moeda estrangeira a empresa vai **comprar** a moeda, e a
   referência comum é a **PTAX de venda**. Este contrato assume venda. Confirmar.
2. **Cotação do dia da emissão ou do dia do pagamento?** Este contrato trata só da cotação de
   **referência na emissão** (a que calcula `valor_total_brl` e a régua). A variação cambial
   até o pagamento é assunto do financeiro, fora daqui.
3. **Quais moedas:** hoje o formulário oferece USD e EUR. Outras entram só configurando o job.

## 7. Aceite

- Escolher USD numa OC nova preenche a cotação com a PTAX de venda do último fechamento, com a
  data visível.
- Em fim de semana, vem a cotação da sexta (ou do último dia útil).
- Alterar o valor grava `cotacao_origem = 'manual'`; manter grava `'ptax'` com a `cotacao_data`.
- Com a API do Banco Central fora do ar, a OC continua podendo ser emitida com a cotação
  digitada.
