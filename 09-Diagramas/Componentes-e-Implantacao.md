---
tags: [diagramas, componentes, implantacao, infraestrutura, integracao]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [v1 Diagramas-UML (9, 10, 11, 21, 22), 01-Projeto/Infraestrutura, Integracao-AvHub-MES, Dockerfiles dos repositórios, api-pcp 579a625, api-acos-vital f322dcd, omie-elt-pipeline 0f739f0, HUB b55ac55, conferência de 29/10/2026 (api-pcp befd973, api-acos-vital f2fa237, av-hub 758d5f0, Dump Avhub de 29/10)]
---

# Componentes, implantação e dados entre sistemas

**Em uma frase:** quatro desenhos mostram quais programas existem, onde rodam, como os bancos se organizam e como a informação anda do Omie ao Estoque.

**Como ler estes diagramas**

- Cada caixa é um programa, um banco (cilindro) ou um serviço de fora, como o Omie. Uma caixa maior agrupa o que pertence ao mesmo sistema.
- Seta cheia: a conversa existe. Seta tracejada: a conversa está prevista ou incompleta.
- Os rótulos `INT-01` a `INT-09` são as conversas entre o av-hub e o MES (a `INT-08` é o legado sem consumidor e não aparece no desenho). Cada uma está explicada em [[Integracao-AvHub-MES]].
- Comece pelo diagrama 1 para ver quem fala com quem. O 4 mostra o caminho do dado de ponta a ponta.

Topologia: [[Infraestrutura]]. Responsáveis: [[Sistemas-e-Responsabilidades]]. Destino de cada diagrama do v1: [[Indice-de-Diagramas]].

## 1. Componentes e integrações

O HUB (o que o usuário vê) fala com uma API só, a do Hub (`api-acos-vital`), que também abriga o módulo comercial. A `api-comercial` do Pablo ficou só como legado de leitura e saiu do desenho. O MES (fábrica) conversa com a API do av-hub por rotas. A pipeline do Omie lê e grava no banco do av-hub e envia a OC ao Omie.

```mermaid
flowchart LR
    subgraph SYS_HUB["HUB, front Next.js"]
        HUB["HUB e BFF"]
    end
    subgraph SYS_API["api-acos-vital, Express e Sequelize"]
        API["API do av-hub"]
        JOBS["Jobs de leitura do MES a cada 90 s"]
    end
    subgraph SYS_MES["MES"]
        MESF["app-pcp, Next.js"]
        MESB["api-pcp, NestJS e Prisma"]
    end
    subgraph SYS_ELT["omie-elt-pipeline"]
        ELT["Extrator e carregador"]
        ENV["Worker de envio da OC"]
    end
    OMIE[("Omie")]
    PGA[("Postgres do av-hub")]
    PGM[("Postgres do MES")]

    HUB -->|"x-api-key mais Bearer"| API
    MESF --> MESB
    MESB -->|"INT-01 GET pedidos_liberados e POST importado"| API
    MESB -->|"INT-02 PUT compras requisicoes origem"| API
    MESB -->|"INT-03 GET compras requisicoes eventos"| API
    JOBS -->|"INT-05 GET itens status"| MESB
    JOBS -->|"INT-06 GET itens custo, rota na develop do MES"| MESB
    JOBS -.->|"INT-07 GET fluxo eventos, 404 hoje"| MESB
    MESB -->|"INT-04 GET ordens-compra referencia, job K4 na develop"| API
    MESB -->|"INT-09 GET compras requisicoes referencia, develop"| API
    ELT -->|"extrai"| OMIE
    ELT -->|"grava"| PGA
    ENV -->|"GET compras ordens fila-omie"| API
    ENV -->|"UpsertPedCompra, unica escrita no Omie"| OMIE
    API --> PGA
    MESB --> PGM
```
- ✅ Setas cheias conferidas. ✅ `INT-01` a `INT-03` e `INT-05` funcionam.
- ✅ `INT-04` (referência da OC, job K4, 15/10), `INT-06` (custo, rota de 27/10) e `INT-09` (referência das requisições, 23/10) existem na `develop` do MES; a `main` do MES parou em 08/10, então em produção o job de custo recebe 404 até o merge (BL-035).
- 🔴 `INT-07` (eventos da Torre): o hub já tem o job, mas o MES não tem o módulo `fluxo` e responde 404 (seta tracejada).

## 2. Implantação

Mostra em qual servidor cada programa deve rodar. A topologia é decisão do Nathan (📝, 07/10); o estado real dos containers ❓ não foi conferido.

```mermaid
flowchart TB
    subgraph VPS1["VPS1, Coolify e Traefik"]
        HUBC["HUB, node 20 alpine, porta 3000"]
        APIC["api-acos-vital, node 20 alpine, porta 3000"]
        MESBC["api-pcp, node 22 slim, porta 3000"]
        MESFC["app-pcp, node 22 slim, porta 3000"]
        PIPEC["Pipeline Omie, 6 processos PM2 mais Redis"]
    end
    subgraph VPS2["VPS2, Postgres"]
        PGAD[("Banco do av-hub, um schema por dominio")]
        PGMD[("Banco do MES, schema public")]
    end
    subgraph VPS3["VPS3, MinIO"]
        MINIOD[("Arquivos: laudos, certificados e fotos")]
    end
    OMIED["Omie SaaS"]

    HUBC --> APIC
    MESFC --> MESBC
    MESBC --> APIC
    APIC --> PGAD
    MESBC --> PGMD
    PIPEC --> PGAD
    PIPEC --> OMIED
    APIC -.-> MINIOD
    MESBC -.-> MINIOD
```
- ✅ Imagens e portas conferidas nos `Dockerfile`. 📝 Servidores (VPS) e Postgres são decisão.
- ❓ MinIO (guarda de arquivos): nenhuma referência no código em 14/10, por isso as setas são tracejadas.
- A `api-comercial` (node 22 slim, porta 3001) não tem ambiente e não será publicada: é legado de leitura (N16-117), por isso saiu do desenho.

## 3. Pacotes: schemas por banco

Um schema é uma "gaveta" dentro do banco. O av-hub separa por assunto; o MES usa uma só. Os dois bancos não se ligam por tabela: só pela API (REST).

```mermaid
flowchart TB
    subgraph BANCO_AVHUB["Banco do av-hub"]
        S_CORE["core"]
        S_AUTH["auth"]
        S_VEN["core_vendas_faturamento"]
        S_COMPRAS["core_compras"]
        S_COMISSAO["core_comissionamento"]
        S_VAGAS["core_aprovacao_de_vagas"]
        S_ORG["core_organograma"]
        S_FLUXO["core_fluxo"]
        S_MAPAS["core_mapas"]
        S_ESTOQUE["core_estoque, sem tabelas no dump"]
        S_HIST["historico"]
        S_COMERCIAL["core_comercial, propostas e cadastros do comercial"]
        S_OMIE["omie_ctl e omie_raw"]
    end
    subgraph BANCO_MES["Banco do MES"]
        S_PUBLIC["public: producao, estoque, compras, integracao, auth do MES"]
    end

    S_AUTH -->|"usuarios_unidades"| S_CORE
    S_VEN -->|"vendedores.id_funcionario"| S_CORE
    S_COMISSAO -->|"regras usam vendas"| S_VEN
    S_VAGAS -->|"solicitante e setor"| S_CORE
    S_FLUXO -.->|"projecao alimentada pelo feed do MES"| S_PUBLIC
    S_OMIE -.->|"audita"| S_VEN
    S_COMERCIAL -.->|"cadastros usados pelo comercial"| S_CORE
```
- ✅ A lista de schemas confere com o Dump Avhub de 29/10.
- 🔴 `core_comercial` aparece no dump de 29/10 com 23 tabelas (`propostas`, `clientes`, `ofertas`, `unidades_emissoras` e outras), e as rotas `/comercial/*` da API o usam. A N16-116 (27/10) disse que ele não existiria e que a proposta ficaria em `core_vendas_faturamento`; a divergência está em decisão (Nathan e Robert).
- 🟡 As ligações entre schemas vieram do v1 e não foram relidas no dump.
- `core_estoque` não tem tabela: o Estoque é do MES.

## 4. Fluxo de dados de ponta a ponta

Do Omie ao Estoque e de volta. Substitui o diagrama 22 do v1, que dizia que o av-hub não consome o status por item.

```mermaid
flowchart LR
    OMIE[("Omie")]
    PIPE["Pipeline ELT"]
    PGA[("Banco do av-hub")]
    API["api-acos-vital"]
    MES["api-pcp"]
    PGM[("Banco do MES")]
    HUB["HUB"]

    OMIE -->|"V1 extrai pedidos e notas"| PIPE
    PIPE -->|"grava"| PGA
    HUB -->|"V3 libera"| API
    API --> PGA
    PGA -->|"P1 P2 pedidos liberados"| API
    API -->|"GET sob demanda"| MES
    MES --> PGM
    MES -->|"P3 PUT requisicao"| API
    API -->|"C1 a C5 eventos, polling 5 min"| MES
    API -->|"status por item, 90 s"| MES
    API -->|"OC aprovada, fila-omie"| PIPE
    PIPE -->|"C4 envia a OC"| OMIE
```
Hoje a informação anda em camadas de leitura periódica, sem aviso automático (webhook):

- Triagem e Destinação leem na hora.
- Marcos da requisição: a cada 5 minutos, ou sob demanda.
- Status por item, custo e Torre: a cada 90 segundos.
- Extração do Omie: conforme o agendador da pipeline.

Tempo real continua fora do desenho 📝 (DEC-2). Ver [[Pipeline-Omie]].

## Detalhe técnico

### 1. Componentes e integrações

Selo ✅ para as setas cheias (rotas conferidas em [[Integracao-AvHub-MES]] e nos routers da `api-acos-vital`); `INT-07` tem o job no hub e o MES responde 404 🔴; `INT-04`, `INT-06` e `INT-09` existem na `develop` do MES (conferido em 29/10). Mudanças em relação ao v1:

- Os jobs `itens_pedido_status.job.js`, `itens_pedido_custo.job.js` e `item_estado_projetado.job.js` (Torre) agora existem no hub; no v1 o hub "ainda não consumia" o status por item.
- O MES lê **todos** os eventos do contrato 35, não só cancelada e reaberta.
- A pipeline só escreve no Omie para enviar a OC (`omie-envio-oc-worker`) ✅ [[Pipeline-Omie]]. A `api-comercial`, que lia pedidos de compra do Omie, virou legado de leitura e saiu do desenho (N16-117).
- O HUB fala só com a `api-acos-vital` desde 27/10 (`3bccfce`).
- A chave do MES para o PUT do contrato 34 só abre essa rota (`apiKeyAuth.js`); as leituras usam a `API_KEY` do MES ✅ [[Chaves-e-Autenticacao]].

### 2. Implantação

Topologia decidida pelo Nathan (📝, 07/10); estado real dos containers ❓ não conferido. Selo ✅ para imagens e portas (`Dockerfile` de cada repositório, linhas citadas em [[Infraestrutura]]); 📝 para VPS e Postgres; MinIO ❓: nenhuma referência a MinIO foi encontrada no código de `api-pcp` e `api-acos-vital` em 14/10, por isso as setas são tracejadas. `api-comercial` sem ambiente: legado de leitura na pasta `api-comercial/` do HUB (N16-117).

### 3. Pacotes: schemas por banco

Não há dependência de schema entre os bancos do av-hub e do MES: a ligação é só por REST. O MES usa só `public`; o av-hub divide por domínio ([[Schemas-Postgres]]).

Selo ✅ para a lista de schemas (`CREATE SCHEMA` no Dump Avhub de 29/10: `auth`, `core`, `core_aprovacao_de_vagas`, `core_comercial`, `core_comissionamento`, `core_compras`, `core_estoque`, `core_fluxo`, `core_mapas`, `core_organograma`, `core_vendas_faturamento`, `historico`, `omie_ctl`, `omie_raw`). `core_comercial` não aparecia no dump de 14/10; no de 29/10 tem 23 tabelas (migration 052 da API; ver o aviso acima). `core_estoque` não tem tabela no dump (o Estoque é do MES, decisão #21); 🟡 as dependências de FK entre schemas foram mantidas do v1 e não relidas no dump nesta rodada ❓ (`vendedores.id_funcionario`, `usuarios_unidades`). `core_compras` guarda o orçamento (`orc_*`) e as views de compras; ordens e requisições de compra vivem em `core_vendas_faturamento` ✅ (dump).

### 4. Fluxo de dados de ponta a ponta

Velocidade hoje: polling em camadas, sem webhook. Triagem e Destinação leem na hora; marcos da requisição a cada 5 min (ou sob demanda); status por item, custo e Torre a cada 90 s; extração do Omie conforme o agendador da pipeline. Tempo real continua fora do desenho 📝 (DEC-2). Ver [[Pipeline-Omie]].
