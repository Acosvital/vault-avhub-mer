---
tags: [erp-acos-vital, pcp-legado, mes, lacunas, escopo, migracao]
criado: 2026-10-08
atualizado: 2026-10-08
---

# PCP legado × MES — o que falta para substituir

> Status: **escopo aprovado pelo Nathan em 08/10/2026** (todos os 29 itens; 28 e 29 no av-hub; Caldeiraria como mais uma fábrica) | **estimativas em pd são minhas, não do Robert** | nada disto está no código do MES. Fonte: PDF "PCP legado × MES — o que falta para substituir" (Robert, 08/10/2026). **Não conferi o repositório `pcp-acosvital`** (o sistema atual, versão de 07/10/2026, 757 commits desde 24/06): ele não está nos repositórios desta sessão, então tudo sobre o PCP legado vem do PDF. A coluna "No vault" é minha e cruza cada lacuna com o que o vault já tem.

## Em uma frase

O MES (`api-pcp`/`app-pcp`) ainda não substitui o PCP legado no chão de fábrica. A linha **Flange** está próxima; a **Caldeiraria HRM** e as **análises gerenciais** não estão no MES nem estavam no vault. O PDF serve para o Nathan decidir o escopo (seções abaixo) e, com as mudanças que ele já pretende fazer, atualizar vault e cronograma de uma vez.

## O que o MES já cobre (comparação do Robert)

| Função | Sistema atual | MES | Situação |
|---|---|---|---|
| Abertura da OP | Lê o PDF do PV | Carteira e OP a partir do Omie, via av-hub (hoje **Triagem e Destinação do Pedido**, [[Registro-de-Decisoes-2026-10-07]] item 58) | MES melhor |
| Roteiro por item | Livre, etapa pode repetir | `RoteiroItem` por item, setor pode repetir, tipos de setor | Paridade |
| Ações na fila do setor | Receber, iniciar, pausar/retomar com motivo, mover, devolver parcial, concluir, retrabalho, reprovar, desfazer recebimento | As mesmas ações no `FilaSetor` | Paridade |
| Máquina e operador | Obrigatórios ao iniciar | Por setor (`exigeMaquinaOperador`) | Paridade |
| Parciais | Split, consolidar, devolução | Split, devolução e linhagem | Paridade |
| Embalagem e entrega | Pallets, peso, NF, canhoto | `PedidoEmbalagem`, pallets, `Entrega`, anexos | Paridade |
| Histórico do item | Log de movimentação | `HistoricoItemParcial` | Paridade |
| Pedidos excluídos | Com foto e reativação | Com foto, sem reativação | Quase |
| Divergências | Tela e fluxo | Backend pronto, sem tela (fila "Novo norte", 2.5) | Falta tela |
| Estoque | Itens, inventário por planilha, atendimento | Lote, saldo, reserva, movimento, alertas | MES melhor |
| Compras | Só registra a requisição feita no Omie | Circuito integrado ao av-hub, recebimento D6, inspeção de entrada | MES melhor |
| Acesso | Perfis + 8 flags por usuário | RBAC por tela + `PerfilSetor`, Azure AD | MES melhor |

## Lacunas da linha Flange (14)

Prioridade sugerida pelo Robert. **Decisão do Nathan (08/10): todos entram no escopo.** A estimativa em pd (ordem de grandeza, ±30%) é minha, por complexidade, e o Robert precisa validar.

| # | Lacuna | Como funciona hoje (PCP legado) | Prioridade | No vault | Decisão e estimativa |
|---|---|---|---|---|---|
| 1 | Programação da fila | Número de sequência no card, ordenação por prazo → prioridade → tamanho, ordem manual ▲/▼ | Alta | Não existe | ✅ MES · 4 pd |
| 2 | Previsão de conclusão | Por peça e por pedido, definida no card por quem tem permissão; o atraso passa a ser medido por ela; card "Projeção de conclusão" | Alta | Não existe | ✅ MES · 4 pd |
| 3 | Prazo de finalização por setor | Prazo por item e por pedido em cada setor, refletido em dashboard, TV e kanban | Média | Não existe | ✅ MES · 3 pd |
| 4 | Planejamento da Usinagem | Fila por máquina, painel de máquinas, data de conclusão (lançamento + 7 dias), avisos e encaminhamento fixado no topo | Alta | Não existe | ✅ MES · 8 pd |
| 5 | Telão, Kanban e quiosque | TV, kanban, últimas movimentações; tablet em modo quiosque | Alta | Tela **7.4** (painel TV) do [[Fluxograma-Telas-por-Bloco]]: sem página | ✅ MES · 6 pd |
| 6 | Tempo real | Telas atualizam sozinhas (WebSocket); no MES só atualiza após a ação do próprio usuário | Alta | Não existe; a integração av-hub ↔ MES é por polling (DEC-2) | ✅ MES · 6 pd |
| 7 | Impressão | Etiqueta DYMO 98×27, impressão por departamento, pedido, OP e relatório do pedido | Alta | Só a etiqueta Code128 do lote (D11, parcial) | ✅ MES · 6 pd |
| 8 | Visualizador e croqui | OP, PV e desenho abrem dentro do sistema (PDF.js no tablet); croqui por código de material | Média | Não existe | ✅ MES · 4 pd |
| 9 | Setor Sinete | Sinete por material, opção "Sem sinete", selo no card | Baixa | Não existe | ✅ MES · 2 pd |
| 10 | Checklist e inspeção por etapa | Checklist de processo com foto e laudo por etapa | Média | Parcial: inspeção de saída é um setor do roteiro; checklist por etapa não existe | ✅ MES · 5 pd |
| 11 | Fim do fluxo | Romaneios de carga (criar, conferir, fechar, imprimir), pedidos não localizados, desfazer entrega, reativar excluído | Alta | Telas 10.2 e 10.3 (consolidação e transporte), Fase D, sem código | ✅ MES · 8 pd |
| 12 | Travessia Mogi → HRM | Conferência/carregamento item a item, "Em trânsito", recebimento na HRM | Média (liga com transferência entre filiais) | [[Proposta-Transferencia-Estoque-Filiais]]: só a etapa 1 existe; etapas 2 a 4 sem código | ✅ MES · 5 pd |
| 13 | Paradas | Máquina parada com motivo, aviso do operador ao Planejamento, pedido parado | Média | Não existe | ✅ MES · 3 pd |
| 14 | Restrição por campo | Ocultar valores (R$) por usuário, líder não vê cliente, perfil somente leitura, perfil Apontador | Média | RBAC é por tela e ação; não há restrição por campo | ✅ MES · 4 pd |

## Lacunas da Caldeiraria HRM (15 a 22)

No sistema atual a Caldeiraria virou quase um sistema à parte; o vault a citava só de passagem. **Proposta do Robert:** ela entra no MES como mais um destino de fabricação, com setores próprios.

| # | Lacuna | Como funciona hoje | Decisão e estimativa |
|---|---|---|---|
| 15 | Entrada da OP | Anexar OP com leitura automática do PDF (inclusive OCR); área da OP: Caldeiraria Leve, Pesada ou outra | ✅ MES · 5 pd |
| 16 | Conferência da OP (Alan) | Monta o roteiro por componente (produto = pai, componentes = filhos); cada estrutura vira um projeto; copiar, editar e devolver a OP | ✅ MES · 10 pd |
| 17 | Unidade Peça / Quilo / Metro | Quantidades em kg e metro, com decimais | ✅ MES · 4 pd |
| 18 | Rastreabilidade por material | Nº de rastreabilidade por material (padrão óleo e gás) e Data Book | ✅ MES · 6 pd |
| 19 | Setores e inspeções | Cerca de 50 setores próprios, inspeção repetida no roteiro, setores de passagem, *hold points* com laudo da Qualidade | ✅ MES · 8 pd |
| 20 | Ciclo do Book com o cliente | Preparação, inspeção pelo cliente, postagem no portal e aprovação | ✅ MES · 8 pd |
| 21 | Datas contratuais | Datas do contrato e rastreio do cliente no pedido | ✅ MES · 2 pd |
| 22 | Planejamento da Caldeiraria (Val) | Substituiu a planilha: painel por áreas, valores, empresa do pedido, caixa de pendências e recados, impressão por vendedor | ✅ MES · 8 pd |

**Decisões de modelo já tomadas pelo Robert (08/10):**
- **Destino:** a Caldeiraria entra como destino `FABRICACAO`, com os setores vinculados só a ela. O roteiro do MES já aceita setor repetido e o item já tem pai e filhos (`idItemPai`).
- **Origem dos itens:** a HRM migrou do Totvs para o Omie, então os itens vêm do Omie, como na Flange. **Falta confirmar se o av-hub expõe a estrutura do produto** (componentes da OP).
- **Unidade:** o banco será preparado para kg/m (hoje as quantidades são inteiros pequenos); o comportamento só muda quando a Caldeiraria entrar.

**Ainda em aberto** (dependem do escopo geral): mesmo componente repetido no pedido quando há várias estruturas; destino × filial (a Caldeiraria roda na HRM); campos próprios dos itens 18 a 20.

## Lacunas de análise, relatórios e gestão (23 a 29)

A sugestão do Robert é manter no MES só o que mede produção e levar o que é financeiro ou comercial para o av-hub, que já tem os dados do Omie.

| # | Lacuna | Como funciona hoje | Onde sugerimos | Decisão e estimativa |
|---|---|---|---|---|
| 23 | Produção por pessoa e por máquina | Tempo por máquina, resumo por operador e por líder | MES | ✅ MES · 4 pd |
| 24 | Capacidade e ritmo | Capacidade por máquina, catálogo de flanges (peças por dia/semana/mês pelo ritmo real), funil, meta do mês | MES | ✅ MES · 6 pd |
| 25 | Fechamento e diagnóstico | Fechamento semanal automático e diagnóstico executivo ao vivo | MES | ✅ MES · 6 pd |
| 26 | Estoque de flanges por unidade | Saldo Arujá × Mogi no Planejamento | MES (Estoque) | ✅ MES · 3 pd |
| 27 | Relatório pedidos + materiais | Por mês de emissão, com impressão e Excel | MES | ✅ MES · 3 pd |
| 28 | Valores por mês e por vendedor | Flanges, Caldeiraria e combinado; Excel no modelo "Base Faturamento Fábrica" | av-hub | ✅ av-hub · 6 pd |
| 29 | Faturamento mensal | Upload do relatório do Omie e geração de Excel/PDF; saídas do estoque em R$ | av-hub | ✅ av-hub · 6 pd |

Os itens 28 e 29 hoje processam dados do faturamento oficial fora do controle da TI; trazê-los para o av-hub resolve isso.

## O que não deve ser copiado

| Sistema atual | Por que não copiar | No MES |
|---|---|---|
| Leitura do PDF do PV para abrir a OP | Fonte frágil (fonte embaralhada, OCR) | Pedido vem do Omie via av-hub |
| Requisição HRM que só registra o que foi feito no Omie | Duplica o lançamento | Circuito de compra integrado (requisição → OC → recebimento) |
| Estoque simples com inventário por planilha | Sem lote, sem rastreio | Estoque com lote, reserva e movimento |
| Permissões por login fixo no código (ex.: quem vê Valores, Paradas, Planejamento) | Não se administra pela tela e trava em pessoas | Perfis e telas no RBAC |
| Migrações automáticas no banco a cada deploy | Mudança direto em produção, sem revisão | Migrations do Prisma com ambiente de teste |
| Scripts de faturamento rodando na máquina de um colaborador | Dado oficial fora do controle da TI | Relatório no av-hub (itens 28 e 29) |
| Planilhas de acompanhamento importadas (Acompanhamento HRM) | O próprio sistema atual desligou em 30/09 | Não se aplica |

## Decisões do Nathan (08/10/2026)

- [x] **Escopo:** entram os **29 itens**, com a prioridade sugerida pelo Robert.
- [x] **Itens 28 e 29** (valores por vendedor e faturamento mensal) vão para o **av-hub**; sem dono definido.
- [x] **Caldeiraria HRM:** entra como **mais uma fábrica** (`FABRICACAO`) dentro dos "setores produtivos do roteiro" do fluxo, não como um bloco à parte. O vault passa a tratá-la assim.
- [x] **Plano:** recalculado **estendendo a data**, com a mesma equipe. Ver [[Cronograma-2-Meses]], seção 3.3.
- [ ] **Ainda em aberto:** destino × filial (a Caldeiraria roda na HRM e a ida de peças Mogi → HRM entra na transferência entre filiais?); mesmo componente repetido no pedido (por estrutura ou soma); rastreabilidade por material, laudo nos *hold points* e ciclo do Book (o escopo aprovado os inclui, mas os campos próprios dos itens 18 a 20 não estão definidos); congelar novas funcionalidades no sistema atual durante a migração (ele teve 45 commits entre 28/09 e 07/10).

**Mudanças de escopo do Nathan:** o PDF reserva um espaço, ainda vazio, para outras mudanças. Quando vierem, entram aqui e no cronograma.

## O que isto muda no vault

- **Escopo e cronograma foram alterados em 08/10/2026**, a pedido do Nathan: o MES passa a ter 141 pd novos (itens 1 a 27), mais 12 pd no av-hub (28 e 29). Com o Robert sozinho no MES a 75% de foco, a **data final do MES passa de 18/12/2026 para cerca de 08/10/2027**. A conta e as ondas de entrega estão no [[Cronograma-2-Meses]], seção 3.3. **As estimativas são minhas** e o Robert precisa validá-las.
- **Conflito com decisões anteriores:** a Caldeiraria como fábrica do MES é nova. O vault tratava a HRM só como unidade/empresa (contas Omie só de Mogi e Uberaba, manifesto sem HRM, [[Registro-de-Decisoes-2026-10-07]] item 19).
- **Coerente com o vault:** divergências sem tela (2.5), painel TV sem página (7.4), consolidação e transporte na Fase D (10.2, 10.3) e transferência entre filiais só na etapa 1. Estes itens se sobrepõem a lacunas do levantamento (5, 11, 12, 26); **não subtraí a sobreposição**, então a estimativa é conservadora nesse ponto.

## Ver também
- [[App-PCP-Visao-Geral]]
- [[Fluxograma-Telas-por-Bloco]]
- [[Cronograma-2-Meses]]
- [[Proposta-Transferencia-Estoque-Filiais]]
- [[Fabricacao-Flanges]]
