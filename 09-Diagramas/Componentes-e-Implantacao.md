---
tags: [diagramas, componentes, implantacao, infraestrutura, integracao]
criado: 2026-10-14
atualizado: 2026-10-14
status: vigente
dono: Nathan
fontes: [v1 Diagramas-UML (9, 10, 11, 21, 22), 01-Projeto/Infraestrutura, Integracao-AvHub-MES, Dockerfiles dos repositórios, api-pcp 579a625, api-acos-vital f322dcd, omie-elt-pipeline 0f739f0, HUB b55ac55]
---

# Componentes, implantação e dados entre sistemas

Redesenhado em 14/10/2026. Topologia: [[Infraestrutura]]. Integrações com rota, chave e cursor: [[Integracao-AvHub-MES]]. Responsáveis: [[Sistemas-e-Responsabilidades]]. Destino de cada diagrama do v1: [[Indice-de-Diagramas]].

## 1. Componentes e integrações

```mermaid
flowchart LR
    subgraph SYS_HUB["HUB, front Next.js"]
        HUB["HUB e BFF"]
    end
    subgraph SYS_API["api-acos-vital, Express e Sequelize"]
        API["API do av-hub"]
        JOBS["Jobs de leitura do MES a cada 90 s"]
    end
    subgraph SYS_COM["api-comercial, Express 5 e Prisma"]
        COM["Comercial e Suprimentos"]
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
    HUB -->|"x-api-key mais Bearer"| COM
    COM -->|"produtos e parceiros"| API
    COM -->|"pedidos de compra por conta"| OMIE
    MESF --> MESB
    MESB -->|"INT-01 GET pedidos_liberados e POST importado"| API
    MESB -->|"INT-02 PUT compras requisicoes origem"| API
    MESB -->|"INT-03 GET compras requisicoes eventos"| API
    JOBS -->|"INT-05 GET itens status"| MESB
    JOBS -->|"INT-06 GET itens custo, 404 hoje"| MESB
    JOBS -->|"INT-07 GET fluxo eventos, 404 hoje"| MESB
    MESB -.->|"INT-04 GET ordens-compra referencia, sem consumidor"| API
    ELT -->|"extrai"| OMIE
    ELT -->|"grava"| PGA
    ENV -->|"GET compras ordens fila-omie"| API
    ENV -->|"UpsertPedCompra, unica escrita no Omie"| OMIE
    API --> PGA
    COM --> PGA
    MESB --> PGM
```

Selo ✅ para as setas cheias (rotas conferidas em [[Integracao-AvHub-MES]] e nos routers da `api-acos-vital`); as setas `INT-06` e `INT-07` têm o job no hub e o MES responde 404 🔴; `INT-04` existe só no hub, o MES não consome 🔴. Mudanças em relação ao v1:

- Os jobs `itens_pedido_status.job.js`, `itens_pedido_custo.job.js` e `item_estado_projetado.job.js` (Torre) agora existem no hub; no v1 o hub "ainda não consumia" o status por item.
- O MES lê **todos** os eventos do contrato 35, não só cancelada e reaberta.
- A pipeline só escreve no Omie para enviar a OC (`omie-envio-oc-worker`); o `api-comercial` lê pedidos de compra do Omie, sem escrita ✅ [[Pipeline-Omie]].
- `api-comercial` aponta para o banco do av-hub no schema `core_comercial`; cluster ❓ não confirmado.
- A chave do MES para o PUT do contrato 34 só abre essa rota (`apiKeyAuth.js:94-100`); as leituras usam a `API_KEY` do MES ✅ [[Chaves-e-Autenticacao]].

## 2. Implantação

Topologia decidida pelo Nathan (📝, 07/10); estado real dos containers ❓ não conferido.

```mermaid
flowchart TB
    subgraph VPS1["VPS1, Coolify e Traefik"]
        HUBC["HUB, node 20 alpine, porta 3000"]
        APIC["api-acos-vital, node 20 alpine, porta 3000"]
        MESBC["api-pcp, node 22 slim, porta 3000"]
        MESFC["app-pcp, node 22 slim, porta 3000"]
        PIPEC["Pipeline Omie, 6 processos PM2 mais Redis"]
        COMC["api-comercial, node 22 slim, porta 3001, sem publicacao definida"]
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
    HUBC -.-> COMC
    MESFC --> MESBC
    MESBC --> APIC
    APIC --> PGAD
    COMC -.-> PGAD
    MESBC --> PGMD
    PIPEC --> PGAD
    PIPEC --> OMIED
    APIC -.-> MINIOD
    MESBC -.-> MINIOD
```

Selo ✅ para imagens e portas (`Dockerfile` de cada repositório, linhas citadas em [[Infraestrutura]]); 📝 para VPS e Postgres; MinIO ❓: nenhuma referência a MinIO foi encontrada no código de `api-pcp` e `api-acos-vital` em 14/10, por isso as setas são tracejadas. `api-comercial` 🔴 sem ambiente de produção decidido (nada dele em `main` no vault v1; no HUB `b55ac55` a pasta existe em `api-comercial/`).

## 3. Pacotes: schemas por banco

Não há dependência de schema entre os bancos do av-hub e do MES: a ligação é só por REST. O MES usa só `public`; o av-hub divide por domínio ([[Schemas-Postgres]]).

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
        S_COMERCIAL["core_comercial, api-comercial, fora do dump"]
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
    S_COMERCIAL -.->|"lê produtos e parceiros pela API"| S_CORE
```

Selo ✅ para a lista de schemas (`CREATE SCHEMA` no Dump Avhub de 14/10: `auth`, `core`, `core_aprovacao_de_vagas`, `core_comissionamento`, `core_compras`, `core_estoque`, `core_fluxo`, `core_mapas`, `core_organograma`, `core_vendas_faturamento`, `historico`, `omie_ctl`, `omie_raw`). `core_comercial` não aparece no dump (o `api-comercial` cria o schema por Prisma) ❓. `core_estoque` não tem tabela no dump (o Estoque é do MES, decisão #21); 🟡 as dependências de FK entre schemas foram mantidas do v1 e não relidas no dump nesta rodada ❓ (`vendedores.id_funcionario`, `usuarios_unidades`). `core_compras` guarda o orçamento (`orc_*`) e as views de compras; ordens e requisições de compra vivem em `core_vendas_faturamento` ✅ (dump).

## 4. Fluxo de dados de ponta a ponta

Substitui o DFD do v1 (diagrama 22), que ainda dizia "o av-hub não consome o status por item".

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

Velocidade hoje: polling em camadas, sem webhook. Triagem e Destinação leem na hora; marcos da requisição a cada 5 min (ou sob demanda); status por item, custo e Torre a cada 90 s; extração do Omie conforme o agendador da pipeline. Tempo real continua fora do desenho 📝 (DEC-2). Ver [[Pipeline-Omie]].
