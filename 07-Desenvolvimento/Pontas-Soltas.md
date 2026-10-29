---
tags: [desenvolvimento, pontas-soltas, pendencias]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [Integracao-AvHub-MES, 00-Fluxo-Mestre-0b, api-pcp 579a625, api-acos-vital f322dcd, omie-elt-pipeline 0f739f0, HUB b55ac55, Registro-de-Decisoes]
---

# Pontas soltas

**Em uma frase:** esta nota lista dúvidas e decisões que ainda não têm resposta ou dono, para o time não perder nenhuma.

## Como ler esta lista

- Cada linha tem um ID `PS-nnn` (PS = ponta solta). Não é tarefa de código direta: tarefa está em [[Backlog-por-Frente]] (BL) e ameaça ao prazo em [[Riscos]] (RS).
- Colunas: **Ponta solta** (o que está em dúvida), **Dono** (quem precisa agir), **Nó** (etapa do fluxo), **Proposta** (o que se sugere fazer) e **Ref** (onde ler mais).
- Selos: ✅ fechada ou feita, 📝 decidido, 🟡 proposta sem decisão, 🔴 aberto, ❓ não conferido.
- Para achar o que é seu, procure seu nome na coluna **Dono**. As pontas já decididas estão na tabela "Resolvidas em 14/10/2026", no fim.
- Descrições longas começam com uma **frase em negrito** que resume a linha. O texto original vem logo depois, completo.
- Siglas: MES = sistema de chão de fábrica; OC = ordem de compra; BFF = camada do front que fala com a API; NF = nota fiscal.

## Resumo por tema

- **Compras e Recebimento (Robert).** Fornecedor da OC no MES (PS-001), quem marca a requisição como atendida (PS-011), teste de cancelamento (PS-012) e as perguntas da compra por destino (PS-034). Dependem em boa parte dos itens de OC no MES do [[Backlog-por-Frente]].
- **Pedido e MES (Robert).** Retentativa depois de 7 dias (PS-013), baixa no despacho do Estoque sem estimativa de esforço (PS-024) e regras do PCP antigo que o Robert desconhece (PS-027, Nathan descreve).
- **Segurança e chaves (Gustavo, Nathan).** Bearer no BFF (PS-018), valores das chaves nos ambientes (PS-019) e exposição pública do `api-pcp` (PS-029).
- **Pipeline do Omie (Gustavo).** Erros de sincronização em Mogi (PS-020), manifesto de Uberaba (PS-022), planilha de vendas (PS-023), filial padrão fixa (PS-016), comentário desatualizado (PS-017) e filtro incremental que nunca executa (PS-033).
- **Proposta, pedido e comissão.** Quem escreve o módulo na `api-acos-vital` (PS-031; desde 28/10 o Robert conduz a migração, veja o Backlog), o que é `vinculados` (PS-032), ciclo da proposta (PS-035), Carteira do PCP (PS-036), cancelar pelo Omie (PS-037) e formato do número da proposta (PS-038). As perguntas abertas estão em [[Perguntas-Proposta-Pedido-Comissao]] (PS-039).
- **Imposto.** O imposto por item na OC ainda não tem modelo (PS-014, Nathan e Gustavo).
- **Já fechadas.** PS-005 (28/10) e as sete decididas em 14/10, abaixo.

## Lista completa

Dúvidas, lacunas de decisão e pontos sem dono que **não são tarefa de código direta**. O que é trabalho a fazer está em [[Backlog-por-Frente]] (`BL-nnn`); o que ameaça o prazo está em [[Riscos]] (`RS-nnn`). Cada ponta tem proposta. Selos: [[Regras-do-Vault]]. Donos: Nathan (front e decisões), Gustavo (banco e API do av-hub), Robert (MES), Pablo (Comercial & Suprimentos).

| ID | Ponta solta | Dono | Nó | Proposta | Ref |
|---|---|---|---|---|---|
| PS-001 | O fornecedor da OC só chega ao MES com o job do contrato 004/007; hoje é digitado na conferência | Robert | C4, R1 | Fazer BL-001; até lá, manter a digitação | BL-001 |
| PS-002 | `GET /requisicoes-compra` (003) sem consumidor | Robert | P3 | Remover (BL-032) ou documentar como API de leitura para terceiros 🟡 | BL-032 |
| PS-005 | ✅ **Fechada (28/10/2026):** 07 arquivado e substituído pelo LOG-42; 38 §6 anotado como histórico. Original: contratos 07 (orçamento) e 38 §6 declarados "a reescrever" sem responsável | Nathan | C | Nomear quem reescreve; 38 §6 deve dizer que `SYNC_ENVIO_OC` e `ENVIO_OC_DRY_RUN` já saíram | #39, #60; [[LOG-38-Regras-Sem-Chave-de-Ambiente]] |
| PS-006 | Unidade de medida diferente entre OC e lote: no Ciclo 1 o lote nasce sem custo e sinalizado; duas perguntas a Compras sobre fator de conversão | Nathan com Compras | R4 | Perguntar a Compras antes de fechar a regra no Ciclo 2 🟡 | D2 do [[API-008-Custo-do-Lote-no-MES]], #98 |
| PS-009 | **Checklist de subida do envio da OC ao Omie.** O envio real já foi testado pelo Nathan em 14/10 e funciona em teste; produção ❓. Antes de publicar o `envio-oc-worker`: deploy da API com o contrato 36 e compradores vinculados; lembrar que os cadastros TESTE do Omie entram na pipeline e nos relatórios | Nathan e Gustavo | C4 | Rodar o checklist e conferir 1 a 2 OCs reais | N14-25, BL-045, BL-055, [[Omie-Integracao-Estado]] |
| PS-011 | Quem marca a requisição como atendida no MES: `resumirRequisicao` fecha por OC e recebimento; regra a confirmar | Robert | R0, R4 | Confirmar com o Robert e documentar em [[05-Recebimento]] | [[Integracao-AvHub-MES]] |
| PS-012 | Teste ponta a ponta do cancelamento de requisição com os marcos do 35 | Robert | P3, C1 | Roteiro de teste: cancelar sem OC, com OC (409 `REQUISICAO_COM_OC`), reaberta | INT-02, INT-03 |
| PS-013 | Retentativa do `importado` depois de 7 dias | Robert | P2 | Alerta no log e botão de reenvio na Triagem; ou estender a janela 🟡 | BL-034; `pedidos.service.ts:64-67` |
| PS-014 | **Imposto por item** não existe na OC (ICMS, IPI, ST, frete). O Ciclo 1 segue **sem imposto** 📝, mas em breve será preciso ter **todos os cenários, também com impostos**: pensar desde já em como adequar (fonte do imposto por item na OC e no `lote_custo`; cenários com e sem imposto) | Nathan e Gustavo | R4 | 🟡 Desenhar o modelo (BL-053) | N14-23, #95, A6 do 008, [[Modelo-Estoque-e-Custo-do-Lote]] |
| PS-015 | `alterado_desde` existe em `/pedidos_liberados`, mas o MES lê sempre a lista inteira da Triagem | Robert | P1 | Usar o cursor se a lista crescer; sem urgência 🟡 | INT-01 |
| PS-016 | `FAMILIA_PADRAO_POR_FILIAL` fixo para mogi e uberaba; `ARCHITECTURE.md` do pipeline diz que nova filial não muda código | Gustavo | V1 | Corrigir a doc e permitir família padrão por filial na configuração | #20, BL-039 |
| PS-017 | `protectedColumns.ts` ainda diz que o dono de `vendedores` é pendente | Gustavo | V1 | Atualizar o comentário com os donos de [[Colunas-Protegidas]] | #62, BL-039 |
| PS-018 | **Reauditoria do Bearer no BFF: só o login deixa de mandar o token; faltam duas decisões antes de ligar o modo estrito.** **Reauditoria do Bearer no BFF (14/10, HUB b55ac55):** de cerca de 200 arquivos que chamam a API, só `app/api/auth/[...nextauth]/route.ts` deixa de mandar o token, em 3 funções do login (`fetchMenu`, `fetchSlugDaTela`, `fetchInfoPerfisDoUsuario`, só `x-api-key`) ✅. As rotas do fluxo de Atividades mandam Bearer. Sobram duas decisões: (1) as chamadas a `/perfis` e `/usuarios_perfis` com Bearer cairiam em `ROTA_SEM_PERMISSAO_MAPEADA` ou 403; o Gustavo libera essas rotas como "autenticada, sem tela" ou o BFF passa a ler perfil e tela inicial de `/me/permissoes`; (2) se a sessão perde o token, `headersComIdentidade` segue só com a chave de serviço, sem 401 | Nathan e Gustavo | todos | Decidir (1) e (2) antes de ligar o modo estrito de Bearer na API | BL-042 |
| PS-019 | Valores e presença das variáveis de chave nos ambientes reais não foram conferidos | Gustavo | — | Conferir `AVHUB_MES_INTEGRACAO_KEY`, `MES_INTEGRACAO_KEYS`, `API_KEY`, `MES_API_KEY`, `MES_INTERNAL_API_KEY`, `AVHUB_API_KEY` | [[Chaves-e-Autenticacao]] |
| PS-020 | 497 erros em `exclusion_sync_curta` em Mogi (490 HTTP 500), causa não documentada | Gustavo | O2 | Ler `error_message` e `faultstring` em `omie_ctl.run_log` | #16 |
| PS-022 | Manifesto: confirmar linhas de Uberaba em `manifestos`; HRM não coberta | Gustavo | O1 | Consulta de conferência; se faltar, plano para HRM | #19 |
| PS-023 | Contrato 009: 53 registros na nota contra 311 linhas em `produto_vendas` no dump de 07/10 | Gustavo | V1 | Explicar a diferença antes de usar a planilha de vendas | #59 |
| PS-024 | Baixa no despacho do Estoque (documento de retirada) sem estimativa em pd | Robert | E6 | Dimensionar antes de fechar o Ciclo 1 | BL-007, RS-004 |
| PS-025 | Comentários do código chamam o pedido manual de "Contrato 30" | Gustavo | — | Trocar para 45 em `pedidoVendaManual.js`, `pedidos_vendas.route.js`, `notas_fiscais.route.js` | #85 |
| PS-026 | Perguntas abertas da Torre: `{id}` do item, lista fechada de `tipo`, R-08, R-13, LGPD, T.6 sem dono | Robert, Gustavo, Nathan | todos | Responder antes de 23/11 | [[Rastreabilidade-e-Torre-de-Fluxo]] |
| PS-027 | Regras dos itens 18 (rastreabilidade por material: número no padrão óleo e gás e Data Book) e 20 (ciclo do Book com o cliente: preparação, inspeção pelo cliente, postagem no portal, aprovação) do PCP legado desconhecidas pelo Robert; destino por filial da Caldeiraria como a Flange (🟡). O Robert responde as demais perguntas da Caldeiraria em 15/10 | Nathan | P2, F1 | Nathan descreve os campos; perguntas prontas em [[CON-02-Rastreabilidade-e-Book-Itens-18-e-20]] | #75, #78 |
| PS-029 | Exposição pública do `api-pcp` no Coolify | Gustavo | — | Confirmar domínio e restringir origem | #13, RS-009 |
| PS-030 | Documentos do v1 que ainda falam em "Estoque·Entrada", setor "Requisições de compras" no roteiro ou "registrar compra" manual descrevem desenho superado | Nathan | E, C | Não usar o v1 para esses temas | [[Contradicoes-Resolvidas]] |
| PS-031 | **Quem escreve o módulo Comercial & Suprimentos na `api-acos-vital`?** N14-15 diz que o Pablo migra; a API é do Gustavo (banco e API). O cronograma ainda tem CS5 "Publicar o `api-comercial`", que deixa de existir | Nathan | — | Pablo escreve o módulo num *branch*, Gustavo revisa e faz DDL, `GRANT` e linhas de permissão; reescrever CS5 como "migrar para a `api-acos-vital`" ([[Cronograma]]) | [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] Q10 e Q11, BL-062 |
| PS-032 | **O que é `vinculados` para propostas e clientes?** No `api-comercial` ele não restringe nada (igual a `todos`); no hub o escopo é por vendedor do Omie (`auth.fn_vendedores_do_usuario`) | Nathan, Pablo, Gustavo | — | Definir como "usuários dos vendedores que o usuário acompanha", com o gestor vendo o time, e o filtro por interseção (nunca sobreposição) | [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] Q3, RS-021 |
| PS-034 | **Compra por destino: seguem abertos o uso interno (confirmar com a contabilidade) e o rateio de uma OC dividida entre pedidos e estoque.** **Compra por destino (N14-28), perguntas abertas:** (1) ~~uso interno no Estoque~~ **decidido (N14-30): entrada registrada, sem lote nem saldo, custo para despesa, sem quarentena** (resta confirmar com a contabilidade o custo para despesa e se EPI tem inspeção); (2) chave do cruzamento filial + pedido + produto fica ambígua com o mesmo produto em duas linhas do pedido: basta o `id_origem` por item (BL-002)?; (3) como ratear a chegada parcial de uma OC que cobre vários pedidos e estoque, e em que ordem atende o pedido; (4) ~~quem cria a reserva do lote~~ **decidido (N14-29): só sugerido no Atendimento, sem reservar, no Ciclo 1**; (5) a Torre não pode receber evento de lote sem item de pedido; (6) o aviso de compra duplicada ao requisitar: **só avisa** (N14-29); fica aberto o uso interno (1) e o rateio da OC dividida (3) | Robert, Nathan, Gustavo | P3, C0, R0, E1 | Robert responde 1 a 4 e 6; Nathan decide 1 e 6; (5) vira regra da Torre | N14-28, BL-051, BL-064, BL-065 |
| PS-033 | **API-001 está marcado entregue, mas o filtro `alterado_desde` nunca executa** (já listado como B10 em [[Bugs-Conhecidos]]) (fica depois de `return where;` em `parceiros.route.js:96` e `produtos.route.js:51`) | Gustavo | — | Mover o bloco para antes do `return` e testar, ou rebaixar o status do contrato | [[LOG-51-Seguranca-e-Padrao-da-API-do-Hub]] S27, [[API-001-Produtos-Parceiros-Filtro-Incremental]] |
| PS-035 | **Ciclo da proposta do módulo do Pablo × desenho aprovado.** O `core_comercial` em produção (LOG-52 fase 1) e as telas do HUB usam fechamento parcial, "perdida" e "reabrir"; o desenho aprovado (N16-02, N16-03, N16-84, N16-106) troca esse ciclo | Nathan, Pablo, Gustavo | V0 | Combinar antes da fase 3 do LOG-52; o é a migração proposta | [[LOG-52-Migracao-do-Modulo-Comercial-para-a-API-do-Hub]] |
| PS-036 | **Carteira do PCP e liberação com os dados novos do Hub.** A Carteira lê a previsão do Omie e o MES lê a Qualidade da liberação; com o desenho aprovado, a Carteira passa a ler a previsão vigente do Hub e a Qualidade respondida no Hub precisa chegar à liberação | Gustavo | V2, P1, datas | `vw_pedidos_previsao_vigente` no lugar da data do Omie; gravar a liberação ao responder `V2`/`V3` | [[SQL-015-Carteira-do-PCP-Totais-por-Vendedor-e-Desvio]], [[API-017-Carteira-do-PCP-por-Periodo-e-Previsao-de-Faturamento-por-Mes]] |
| PS-037 | **Como criar o sequencial e cancelar ou excluir pelo Omie.** Não há botão claro para criar sequencial; `CancelarPedidoVenda` e `ExcluirPedido` ainda não foram testados num pedido não faturado | Nathan | O1, V0.7 | Testar no Omie depois das telas (N16-82, N16-104) | [[Mapa-IncluirPedido-Omie]], [[Estudo-Omie-API]] |
| PS-038 | **Formato do número da proposta.** Só dígitos (ano e sequência, `numero_numerico`) ou o atual com prefixo | Nathan | V0.1 | Decidir (N16-04) | |
| PS-039 | **Perguntas abertas da proposta, do Orçamento e da comissão** (OQ-xx, C-xx) | vários | V0, B, K | Ver a lista | [[Perguntas-Proposta-Pedido-Comissao]] |

## Resolvidas em 14/10/2026

Decididas pelo Nathan em 14/10; o que sobra é trabalho e está em [[Backlog-por-Frente]].

| ID | Decisão | Nota afetada | Trabalho que sobra |
|---|---|---|---|
| PS-003 | O MES lê as OCs do hub: se a OC é vinculada a pedido de venda, o PCP vê a OC do pedido; se é de estoque, o Estoque mostra o saldo futuro. Substitui as opções (a) e (b). N14-20 | [[04-Circuito-de-Compra]], [[05-Recebimento]], [[03-Estoque-Atendimento-e-Despacho]], [[02-PCP-Triagem-e-Destinacao]], [[Integracao-AvHub-MES]] | BL-006, BL-028, BL-041, BL-049, BL-050, BL-051 |
| PS-004 | A Ordem de Produção é entidade do sistema e também documento para impressão, só do que será fabricado. N14-22 | [[02-PCP-Triagem-e-Destinacao]], [[Glossario]] | BL-036, BL-052 |
| PS-007 | Perfil CCP: será criado em breve; tarefa cadastral simples (Nathan e Gustavo), sem bloqueio de desenho. N14-24 | [[Equipe-e-Divisao]], [[RBAC-e-Permissoes]] | BL-017 (cadastral) |
| PS-008 | Vínculo de usuários à Gerência de Compras: idem, tarefa cadastral. N14-24 | [[Equipe-e-Divisao]], [[04-Circuito-de-Compra]] | cadastro (RS-015) |
| PS-010 | OC acima de R$ 30 mil: Gerente de Compras aprova; até R$ 30 mil: compradores livres; sem Diretoria. É o que o código faz ✅. Regra mais rígida depois, com Compras 🟡. N14-21 | [[04-Circuito-de-Compra]], [[00-Fluxo-Mestre-0b]], [[AV-Hub-API]], [[Estados-e-Status]] | BL-038 e BL-040 fechados; endurecer depois (🟡, sem BL) |
| PS-021 | `sql/002` e `omie_raw` obsoletos (auditoria removida no contrato 38; nada lê nem escreve). N14-27 | [[Pipeline-Omie]], [[Banco-AvHub]], [[Diferencas-Codigo-x-Banco]] | BL-054 (`DROP`, Gustavo) |
| PS-028 | Notificações com 403 eram da `api-comercial` (API de teste do Pablo, a migrar para a `api-acos-vital`); não se aplica. N14-26 | [[API-Comercial]] | — |

## Ligações rápidas

- Quem decide o quê: [[Equipe-e-Divisao]].
- Decisões já tomadas: [[Registro-de-Decisoes]].
- O que está em risco: [[Riscos]].
