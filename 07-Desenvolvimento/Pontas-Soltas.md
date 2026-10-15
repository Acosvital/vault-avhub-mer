---
tags: [desenvolvimento, pontas-soltas, pendencias]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [Integracao-AvHub-MES, 00-Fluxo-Mestre-0b, api-pcp 579a625, api-acos-vital f322dcd, omie-elt-pipeline 0f739f0, HUB b55ac55, Registro-de-Decisoes]
---

# Pontas soltas

Dúvidas, lacunas de decisão e pontos sem dono que **não são tarefa de código direta**. O que é trabalho a fazer está em [[Backlog-por-Frente]] (`BL-nnn`); o que ameaça o prazo está em [[Riscos]] (`RS-nnn`). Cada ponta tem proposta. Selos: [[Regras-do-Vault]]. Donos: Nathan (front e decisões), Gustavo (banco e API do av-hub), Robert (MES), Pablo (Comercial & Suprimentos).

| ID | Ponta solta | Dono | Nó | Proposta | Ref |
|---|---|---|---|---|---|
| PS-001 | O fornecedor da OC só chega ao MES com o job do contrato 004/007; hoje é digitado na conferência | Robert | C4, R1 | Fazer BL-001; até lá, manter a digitação | BL-001 |
| PS-002 | `GET /requisicoes-compra` (003) sem consumidor | Robert | P3 | Remover (BL-032) ou documentar como API de leitura para terceiros 🟡 | BL-032 |
| PS-003 | Requisição criada no HUB (origem Compras, "Nova requisição") não tem `id_origem`, não gera evento e não chega ao MES; material comprado por ela não tem caminho de entrada no MES | Nathan decide, Robert e Gustavo fazem | C0, R0 | Opção (a): o hub gera evento também sem `id_origem` e o MES cria o esperado a partir da OC; opção (b): Recebimento aceita entrada avulsa contra NF. Adotar (a) 🟡 | BL-006, BL-028; `Dump Avhub (Esqueleto).sql:8585-8587` |
| PS-004 | "Ordem de Produção" é nome reservado para a ordem emitida ao que será fabricado, entidade que ainda não existe no código (`ordemProducao` hoje é só o texto do pedido) | Robert e Nathan | P2 | Decidir se vira entidade no Ciclo 1 ou só rótulo; renomear telas (BL-036) | #74 |
| PS-005 | Contratos 07 (orçamento) e 38 §6 declarados "a reescrever" sem responsável | Nathan | C | Nomear quem reescreve; 38 §6 deve dizer que `SYNC_ENVIO_OC` e `ENVIO_OC_DRY_RUN` já saíram | #39, #60; [[LOG-38-Regras-Sem-Chave-de-Ambiente]] |
| PS-006 | Unidade de medida diferente entre OC e lote: no Ciclo 1 o lote nasce sem custo e sinalizado; duas perguntas a Compras sobre fator de conversão | Nathan com Compras | R4 | Perguntar a Compras antes de fechar a regra no Ciclo 2 🟡 | D2 do [[API-008-Custo-do-Lote-no-MES]], #98 |
| PS-007 | Perfil CCP não existe; aprovador de vagas continua sem nome | Nathan e Gustavo | C5 | Criar o perfil e vincular o Gerente de Compras (perfil existe com 0 usuários no dump de 07/10) | #48 P5, #50, #50b, BL-017 |
| PS-008 | Gerência de Compras tem 0 usuários vinculados no dump de 07/10: sem isso ninguém aprova OC | Nathan | C3 | Vincular antes da primeira OC real ❓ conferir no dump de 14/10 | #50 |
| PS-009 | Envio real de OC ao Omie depende de deploy da API com o contrato 36 e de compradores vinculados | Nathan e Gustavo | C4 | Checklist de subida antes de publicar o `envio-oc-worker` | BL-045, [[Omie-Integracao-Estado]] |
| PS-010 | **Aprovação da OC:** a regra decidida (Gerente aprova sempre; acima de R$ 30 mil a Diretoria também) não é o que o código faz (abaixo do limite não há aprovação; acima, só Gerência) | Nathan decide, Gustavo implementa | C2, C3 | Confirmar a regra como está no 0b e abrir BL-038 e BL-040 | `ordens_compra.route.js:1235`, `FecharCompra.tsx:605` |
| PS-011 | Quem marca a requisição como atendida no MES: `resumirRequisicao` fecha por OC e recebimento; regra a confirmar | Robert | R0, R4 | Confirmar com o Robert e documentar em [[05-Recebimento]] | [[Integracao-AvHub-MES]] |
| PS-012 | Teste ponta a ponta do cancelamento de requisição com os marcos do 35 | Robert | P3, C1 | Roteiro de teste: cancelar sem OC, com OC (409 `REQUISICAO_COM_OC`), reaberta | INT-02, INT-03 |
| PS-013 | Retentativa do `importado` depois de 7 dias | Robert | P2 | Alerta no log e botão de reenvio na Triagem; ou estender a janela 🟡 | BL-034; `pedidos.service.ts:64-67` |
| PS-014 | Imposto por item não existe na OC (ICMS, IPI, ST, frete): fonte a definir; custo do Ciclo 1 é sem impostos | Nathan e Gustavo | R4 | Aceitar sem impostos no Ciclo 1; Ciclo 2 define a fonte | #95, A6 do 008 |
| PS-015 | `alterado_desde` existe em `/pedidos_liberados`, mas o MES lê sempre a lista inteira da Triagem | Robert | P1 | Usar o cursor se a lista crescer; sem urgência 🟡 | INT-01 |
| PS-016 | `FAMILIA_PADRAO_POR_FILIAL` fixo para mogi e uberaba; `ARCHITECTURE.md` do pipeline diz que nova filial não muda código | Gustavo | V1 | Corrigir a doc e permitir família padrão por filial na configuração | #20, BL-039 |
| PS-017 | `protectedColumns.ts` ainda diz que o dono de `vendedores` é pendente | Gustavo | V1 | Atualizar o comentário com os donos de [[Colunas-Protegidas]] | #62, BL-039 |
| PS-018 | Nem todo caminho do BFF do HUB manda Bearer; só os helpers foram corrigidos | Nathan | todos | Reauditar e usar `headersDaApi()` em todos | BL-042 |
| PS-019 | Valores e presença das variáveis de chave nos ambientes reais não foram conferidos | Gustavo | — | Conferir `AVHUB_MES_INTEGRACAO_KEY`, `MES_INTEGRACAO_KEYS`, `API_KEY`, `MES_API_KEY`, `MES_INTERNAL_API_KEY`, `AVHUB_API_KEY` | [[Chaves-e-Autenticacao]] |
| PS-020 | 497 erros em `exclusion_sync_curta` em Mogi (490 HTTP 500), causa não documentada | Gustavo | O2 | Ler `error_message` e `faultstring` em `omie_ctl.run_log` | #16 |
| PS-021 | `omie_raw` removido do código e `sql/002` ficou como lixo | Nathan marca, Gustavo apaga | — | Marcar `sql/002` obsoleto; `DROP` das 5 tabelas vazias | #18 |
| PS-022 | Manifesto: confirmar linhas de Uberaba em `manifestos`; HRM não coberta | Gustavo | O1 | Consulta de conferência; se faltar, plano para HRM | #19 |
| PS-023 | Contrato 009: 53 registros na nota contra 311 linhas em `produto_vendas` no dump de 07/10 | Gustavo | V1 | Explicar a diferença antes de usar a planilha de vendas | #59 |
| PS-024 | Baixa no despacho do Estoque (documento de retirada) sem estimativa em pd | Robert | E6 | Dimensionar antes de fechar o Ciclo 1 | BL-007, RS-004 |
| PS-025 | Comentários do código chamam o pedido manual de "Contrato 30" | Gustavo | — | Trocar para 45 em `pedidoVendaManual.js`, `pedidos_vendas.route.js`, `notas_fiscais.route.js` | #85 |
| PS-026 | Perguntas abertas da Torre: `{id}` do item, lista fechada de `tipo`, R-08, R-13, LGPD, T.6 sem dono | Robert, Gustavo, Nathan | todos | Responder antes de 23/11 | [[Rastreabilidade-e-Torre-de-Fluxo]] |
| PS-027 | Regras dos itens 18 (rastreabilidade por material: número no padrão óleo e gás e Data Book) e 20 (ciclo do Book com o cliente: preparação, inspeção pelo cliente, postagem no portal, aprovação) do PCP legado desconhecidas pelo Robert; destino por filial da Caldeiraria como a Flange (🟡). O Robert responde as demais perguntas da Caldeiraria em 15/10 | Nathan | P2, F1 | Nathan descreve os campos | #75, #78 |
| PS-028 | Notificações do HUB com 403 num servidor local apontado para a `api-test` | Nathan | — | Investigar permissão do usuário de teste | #86 |
| PS-029 | Exposição pública do `api-pcp` no Coolify | Gustavo | — | Confirmar domínio e restringir origem | #13, RS-009 |
| PS-030 | Documentos do v1 que ainda falam em "Estoque·Entrada", setor "Requisições de compras" no roteiro ou "registrar compra" manual descrevem desenho superado | Nathan | E, C | Não usar o v1 para esses temas | [[Contradicoes-Resolvidas]] |

## Ligações rápidas

- Quem decide o quê: [[Equipe-e-Divisao]].
- Decisões já tomadas: [[Registro-de-Decisoes]].
- O que está em risco: [[Riscos]].
