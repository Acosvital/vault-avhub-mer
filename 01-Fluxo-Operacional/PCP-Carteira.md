---
tags: [erp-acos-vital, fluxo-operacional, pcp]
criado: 2026-09-16
atualizado: 2026-09-24
---

# 2. Gestão de Carteira (PCP)

> ⚠️ Não confundir com [[Achado-Ambiguidade-PCP|o "Portal PCP" do av-hub]], que é outra coisa (acompanhamento comercial por diligenciadores). Este PCP é o setor de Planejamento e Controle de Produção.
>
> ~~Confirmado com o usuário (17/09/2026): esta triagem/carteira não existe em nenhum sistema hoje.~~ **Superado em 23-24/09/2026:** a **Carteira de Pedidos** e a tela **Ordem de Produção** existem no `app-pcp` (branch `develop`, rotas `/carteira` e `/ordens-producao/novo`), com backend real no `api-pcp` (`GET /pedidos/carteira`, `POST /pedidos/completo`). O encaixe do Estoque e da Revenda nessa triagem foi decidido em 24/09 — ver [[Encaixe-Estoque-Revenda-no-PCP]].

- O pedido de venda aparece na **Carteira de Pedidos**, lida do av-hub/Omie, com status de envio (não enviado, parcial, total) e de produção (aguardando, em produção, concluída).
- O PCP abre o pedido na tela **Ordem de Produção** e, por **rodada**, escolhe quais itens e quantas unidades vão agora e **para qual fábrica** — uma linha de fabricação ou a fábrica **Revenda**. Cada rodada gera **uma OP por fábrica**; o sequencial de faturamento do Omie (100/1, 100/2...) é o motivo das rodadas.
- A classificação por disponibilidade (tem em estoque ou não) **não acontece aqui**: acontece no **setor Estoque**, que o backend insere como etapa 1 de todo roteiro.

## Por que isso importa para o modelo de dados

A classificação acontece **por item**, não por pedido inteiro — um mesmo pedido pode ter parte destinada a estoque, parte a revenda e parte a fabricação. Desde 24/09/2026 a **natureza é por item e por rodada**: é o tipo da fábrica escolhida (`Pedidos.idFabrica → Fabrica.tipo`), não um atributo fixo do produto. O [[Estoque-Regras-Negocio|PRD do Estoque]] captura a mesma necessidade em `destinacao_item_pedido`.

## O que muda no código atual

Hoje a tela Ordem de Produção trata **item sem fábrica como revenda e o descarta no salvamento** ("não entra no controle de produção do PCP"). Com o encaixe, o item de revenda é enviado à fábrica Revenda como qualquer outro. Ver [[Encaixe-Estoque-Revenda-no-PCP]] seção 4.

## Ver também
- [[Entrada-Comercial]] (fase anterior)
- [[Rota-Estoque]], [[Rota-Revenda]], [[Rota-Fabricacao]] (fases seguintes)
- [[Encaixe-Estoque-Revenda-no-PCP]] — o encaixe completo.
- [[Modelo-Destinacao-Item]] — formaliza que "estoque" não é uma quarta classificação do mesmo tipo, é um eixo de disponibilidade avaliado dentro de Revenda/Fabricação.
