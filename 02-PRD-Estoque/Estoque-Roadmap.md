---
tags: [erp-acos-vital, prd-estoque, roadmap]
criado: 2026-09-16
atualizado: 2026-10-07
---

# PRD Estoque — Fases de Entrega

> Status: decidido | no código (develop) | em produção (mes-test; produção real não)

> **Decisões de 07/10/2026 que mudam este roadmap** ([[Registro-de-Decisoes-2026-10-07]]):
> - **(09/10) G1 aceita uma coluna de custo unitário opcional por lote** (não bloqueia a carga; ver [[Proposta-Custo-x-Venda-Comissao]], item 93 do Registro).
> - **G1 (carga em lote) agora é do Robert** (MES); o Pablo foi para o Comercial & Suprimentos (itens 32 e 33). A capacidade do Robert estoura e precisa ser recalculada ([[Cronograma-2-Meses]]).
> - **Carga inicial:** dupla conferência = **contador + conferente**; divergência = **terceira contagem**; o lote nasce liberado (DEC-4) (item 25).
> - **Saldo do Omie:** o Omie recebe dados só manualmente e o estoque do Omie é **ignorado**. O Passo 2 (`ListarPosEstoque`) **não será feito**; a dependência de reconciliar a carga com o saldo do Omie (G3) **cai**. O MES é a referência do saldo físico (item 28).
> - **Ciclo 2 (começa em 04/01/2027):** entram a **Fase D**, a **remessa de produtos**, **EC-02** (sobras e perdas de matéria-prima), **L-10** (sobras de chapa, perda no corte, unidade) e a transferência entre filiais (etapas 2 a 4) (item 27).
> - **Schema do Estoque:** ✅ fica em `public` (item 21).

> **Atualização de 07/10/2026 — estado das fases pelas tarefas D\*** (conferido no código, `develop` do MES, `api-pcp` `ca3346b` e `app-pcp` `a802a3e`; **a `main` dos dois repos parou em 28/08, então tudo abaixo está só em `develop`**; produção e homologação não foram conferidas, e marco de cronograma só muda com homologação). Ver [[Onde-Estamos]] e [[Cronograma-2-Meses]].
>
> | Fase | Tarefas | Estado no código (`develop`) |
> |---|---|---|
> | **Fase 0** | D1, D2, D3, D4, D5, G1 | D1 feita (`f8186cf`, 22/09); D2 módulo feito, **sem e2e**; D3 **pela metade** (material por snapshot do av-hub, `Fornecedor` sem população); **D4 cortada** (contrato 002 rejeitado em 21/09, código removido em `0ac2596`, 29/09); D5 feita (`e14ecb2`, 23/09); G1 **não** — só carga inicial um lote por vez *(07/10: G1 agora é do **Robert**; dupla conferência contador + conferente, divergência = terceira contagem; sem reconciliar com o saldo do Omie)* |
> | **Fase A** | C7 (requisição), contratos 34/35 | Requisição de compra implementada (`b8dc158`, 29/09; cancelamento e envio em `e7ce2c9`, 02/10); contrato 34 (PUT) e 35 (eventos) **ligados no MES** (`e7ce2c9`, `41bf4a6`); se há chave no ambiente real: não verificado |
> | **Fase B** | D6, D7, D8, D11 | D6/D7 em `develop` (`861c050`, `f2c01f1`, 07/10); D8 feita (`898aa54`, `815fef3`); D11 **parcial** (`2e2c18e`: etiqueta PDF Code128; sem leitor 2D nem posto de recebimento) |
> | **Fase C** | D9, D10 | D9 feita (`0fe771f`, 28/09); D10 real (só `painel-estoque` em parte, `mapa-deposito` e `qualidade/route` ainda citam mock) |
> | **Fase D** | — | Não iniciada, salvo a **transferência entre filiais, etapa 1** (saldo por filial, `861c050`, 07/10) e os alertas de estoque mínimo/RNC pendente (`bfe5882`). **Decidido em 07/10: a Fase D vai ao Ciclo 2 (04/01/2027)** |
> | **Fase E** | — | Não iniciada |

| Fase | Entrega |
|---|---|
| Fase 0 | Saneamento/deduplicação do catálogo Omie → cadastro de material e localização → levantamento físico e carga inicial (marco zero) — *(atualizado em 07/10: o saneamento/deduplicação saiu do escopo em 21/09; o resto da fase é o cadastro D5 e a carga G1)* |
| Fase A | Pedido de compra (MP e revenda) — sem cadastro de fornecedor próprio, ver nota abaixo |
| Fase B | Recebimento em duas etapas (quantitativa + qualitativa), pesagem, RNC, etiquetagem código de barras |
| Fase C | Estoque (saldo, localização, movimento, reserva) — consulta interna dentro do mesmo banco do MES, sem view de integração externa |
| Fase D | Separação/expedição, devolução de cliente, contagem cíclica e ponto de pedido — **Ciclo 2 (a partir de 04/01/2027)**, junto de remessa de produtos, EC-02 e L-10 *(decidido em 07/10)* |
| Fase E (futura) | Piloto de RFID em item de maior valor |

## Status da Fase 0 (17/09/2026)

> **Atualizado em 07/10/2026:** o item "⏳ Pendente… contrato 002" abaixo **ficou sem efeito** — o contrato 002 foi **rejeitado em 21/09** (decisão do Nathan: duplicata de catálogo fica com o Omie) e a tarefa **D4 foi removida em 29/09** (o código do alias, `cca3803`, foi apagado em `0ac2596`). O texto original segue por histórico. A tela "Produtos — Prováveis Duplicatas" do av-hub continua só leitura.

Só a fatia de **saneamento/deduplicação do catálogo** é av-hub — o resto da
Fase 0 (cadastro de material com campos extras, localização, levantamento
físico, carga inicial) é 100% Estoque/MES, fora do av-hub.

- ✅ **Concluído no av-hub**: tela "Produtos — Prováveis Duplicatas"
  (`app/(protected)/cadastros/auxiliares/produtos-duplicados/`, repo
  `00 - HUB`) — agrupa o catálogo por descrição parecida, por unidade,
  só leitura. Corrigido de quebra o bug do campo `codigo_produto_omie`
  (frontend usava `id_produto_omie`, que nunca existiu na API — campo
  "ID Omie" da tela de Cadastro de Produtos nunca funcionou até agora).
- ~~⏳ **Pendente, fora do av-hub**~~ *(cancelado, ver bloco acima)*: a ação de *resolver* a duplicata
  (registrar "este código é alias daquele") depende de um endpoint que o
  Estoque/MES ainda não tem — contrato de API já escrito e endereçado ao
  time do MES, ver [[002-Material-Alias-Omie-MES]].
  Até isso ser respondido, o av-hub não tem mais trabalho de código na
  Fase 0 — o relatório fica como está, servindo de lista de candidatos pro
  comprador/PCP revisar manualmente.

A Fase A não inclui cadastro próprio de fornecedor — o Estoque reaproveita `core.parceiros` (av-hub) via projeção read-only *(atualizado em 07/10: no código o `Fornecedor` existe sem população)*. O Estoque ganha um schema Postgres próprio dentro do banco do MES, seguindo a mesma convenção de schema-por-domínio do av-hub — ver [[Perguntas-Pendentes-MES-Estoque]] e [[MES-Arquitetura-Decisoes]] *(atualizado em 07/10: conferido no código, o estoque está em `public`, sem `@@schema` — **✅ decidido em 07/10: fica em `public`**, [[Registro-de-Decisoes-2026-10-07]] item 21)*. Pedido de compra continua na Fase A, mas quem **decide** o pedido de compra é o av-hub — o Estoque só referencia quando o material chega na doca.

**Telas:** ~21 telas (mais login), organizadas em Cadastros, Compras, Recebimento, Estoque e Gestão.

O MES (`api-pcp`) usava só usuário/senha, sem Azure AD — decisão deliberada porque o público original (chão de fábrica) não tem e-mail corporativo (ver [[App-PCP-Visao-Geral]]). *(Atualizado em 07/10: login duplo conferido no código — `11e73e7`, 22/09, `POST /auth/azure` + `POST /auth/login`, NextAuth AzureAD + Credentials; tarefa C1.)* O MES passa a suportar os dois métodos de login: usuário/senha (chão de fábrica) e e-mail/Azure AD (perfis de escritório do Estoque: almoxarife, Qualidade, gestor de estoque — Comprador e Aprovador ficam no av-hub, nunca logam no MES, ver [[Fluxo-Compras-Completo]]). Ver [[Decisoes-Chave-ERP]].

**Equipe:** time de desenvolvimento disponível — [[Equipe-Projeto|Gustavo]] (banco de dados/API) e [[Equipe-Projeto|Robert]] (fullstack sênior) — com Nathan coordenando/product owner.

## Ver também
- [[Cronograma-2-Meses]] — as fases 0/A/B/C datadas para 18/09–18/11/2026 (Fase D e E ficam para o ciclo seguinte).
- [[PRD-Estoque-Visao-Geral]]
- [[Estoque-Perguntas-Abertas]]
