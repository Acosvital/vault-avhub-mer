---
tags: [visao-setores, fluxo-operacional]
criado: 2026-09-16
---

# Fabricando Produtos Próprios

Além de revender materiais comprados de fornecedores, a Aços Vital também fabrica produtos próprios, do zero, dentro de linhas de produção internas. Esse é o caminho de Fabricação — diferente do caminho de Revenda (veja [[Comprando-o-que-Falta]]) e diferente de cortar uma chapa comprada sob medida (veja [[Cortando-Chapas-sob-Medida]], que não é fabricação, é um serviço de acabamento sobre um item comprado).

## O que é uma "linha de fabricação"

Uma linha de fabricação é um produto que a empresa produz internamente, com etapas próprias de produção. Cada linha tem sua sequência de passos (chamada de roteiro) e passa por setores diferentes até ficar pronta.

Hoje a empresa tem duas linhas de fabricação mapeadas em detalhe, mas a lista não é fechada — outras linhas entram conforme forem cadastradas.

## Fabricação de Flanges

Flange é a linha de fabricação própria mais madura hoje. Ela tem um sistema próprio, dedicado, para fazer os cálculos técnicos e definir os parâmetros de cada flange antes de produzir.

O modelo de produção funciona assim:
- O pedido chega e cada item é atribuído a uma **fábrica** (uma linha de produção).
- Cada fábrica tem um **roteiro**: uma sequência ordenada de setores pelos quais o item precisa passar até ficar pronto (por exemplo: corte, usinagem, furação, acabamento).
- A fábrica também tem cadastro de máquinas e operadores envolvidos em cada setor.

Flange também é vista como uma boa candidata para testes futuros de identificação por radiofrequência (uma etiqueta eletrônica que facilita achar e rastrear a peça), por ter valor mais alto — mas isso ainda depende de testes técnicos antes de qualquer decisão de usar em maior escala.

## Fabricação de Grade de Piso

Grade de piso é a linha de fabricação mais longa e a que tem mais pontos de risco, porque depende de terceiros **duas vezes**:

1. Primeiro, é preciso comprar uma matéria-prima específica de um fornecedor (igual ao caminho de Revenda).
2. Depois de fabricada internamente, a grade é enviada para um processo externo de acabamento (galvanização) feito por outra empresa, e só volta pronta depois disso.

Isso exige um controle mais cuidadoso: a empresa precisa saber exatamente qual lote foi enviado para fora e qual lote voltou, porque não é instantâneo e passa pelas mãos de um terceiro no meio do processo.

O caminho completo é:

```mermaid
flowchart LR
    A[Compra da matéria-prima] --> B[Chegada e conferência]
    B --> C[Fabricação da grade]
    C --> D[Envio para acabamento externo]
    D --> E[Retorno e validação]
    E --> F[Segue para Qualidade e Expedição]
```

## O que as linhas de fabricação têm em comum

Mesmo sendo produtos diferentes, com riscos diferentes, todas as linhas de fabricação própria seguem o mesmo modelo de organização: fábrica, setores e roteiro. E todas são iniciadas da mesma forma, pelo PCP, quando ele decide que aquele item vem de uma linha de fabricação própria (veja [[Organizacao-do-Pedido-PCP]]).

## O que vem depois

Depois de concluída a fabricação, o item segue para a conferência da Qualidade antes de poder ser embarcado. Veja [[Qualidade-e-Conferencia]] e [[Faturamento-e-Entrega]].

## Ver também
- [[Organizacao-do-Pedido-PCP]]
- [[Comprando-o-que-Falta]]
- [[Cortando-Chapas-sob-Medida]]
- [[Qualidade-e-Conferencia]]
- [[Sistema-de-Producao-Flanges]]
- [[Sistema-de-Fabrica-MES]]
- [[Glossario]]
