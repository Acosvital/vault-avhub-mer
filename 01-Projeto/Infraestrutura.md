---
tags: [projeto, infraestrutura, deploy, vps]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Nathan
fontes: [v1 04-Arquitetura-Transversal/Infraestrutura-Self-Hosted, v1 Registro-de-Decisoes #4, Dockerfiles dos cinco repositórios, omie-elt-pipeline/docker-compose.yml e ecosystem.config.cjs, omie-elt-pipeline/src/db/pool.ts]
---

# Infraestrutura

**Em uma frase:** os sistemas rodam em três servidores próprios (VPS): um para as aplicações, um para os bancos de dados e um para os arquivos.

**Quando consultar esta nota:** quando você quiser saber onde cada sistema roda, como é publicado e o que ainda falta na infraestrutura.

Os servidores são próprios (self-hosted), não uma nuvem gerenciada. Essa topologia é decisão do Nathan 📝 (item 4 do Registro do v1). O estado real dos contêineres em produção não foi conferido nesta rodada ❓.

## Os três servidores

| VPS | Para que serve | O que roda |
|---|---|---|
| **VPS1** | Aplicações | HUB, `api-acos-vital`, MES (`api-pcp`, `app-pcp`), pipeline Omie, Backlog Ágil e blog. Tudo em contêineres Docker, gerenciados pelo Coolify e atrás do Traefik 📝. A `api-comercial` não será publicada |
| **VPS2** | Bancos Postgres | O banco do av-hub (um cluster com um schema por domínio), o banco do MES (schema `public`) e outros. O backup por WAL já está configurado e cobre schema novo automaticamente |
| **VPS3** | Arquivos (MinIO) | Laudos e certificados da Qualidade, fotos e imagens do blog |

📝 Nathan, 07/10: o pipeline e o MES ficam na VPS1; o banco do MES fica na VPS2. Diagrama de implantação em [[Componentes-e-Implantacao|Diagrama-Componentes-e-Implantacao]].

## Login

O HUB e o Backlog Ágil compartilham o mesmo App Registration do Azure AD. O `app-pcp` tem **login duplo**: usuário e senha para o chão de fábrica, e e-mail corporativo para o escritório (C1, concluída em 22/09) 📝. Detalhe em [[Chaves-e-Autenticacao]].

## Pipeline Omie

O pipeline não é um app Next.js. São processos Node que precisam de **Redis** e de um **Postgres externo**: o do cluster da VPS2, porque o compose não sobe Postgres. Roda na VPS1, em contêiner Docker junto do Coolify 📝 (Nathan, 14/10). Estado e jobs: [[Pipeline-Omie]].

## Bancos

- **av-hub:** um cluster Postgres, com schemas por domínio. A `api-acos-vital` não roda `sequelize.sync()` e não tem migrations. O DBA aplica o DDL fora do repositório ✅ (nenhum `.sql` no repo). Ver [[Banco-AvHub]] e [[Schemas-Postgres]].
- **MES:** Prisma com migrations versionadas (`api-pcp/prisma/migrations`), tudo em `public` ✅. Ver [[Banco-MES]].
- **Ambientes de teste:** `mes-test.acosvital.com.br` (MES com a `develop`) e `api-test` (API do av-hub) 📝. Ver [[Sistemas-e-Responsabilidades]].

## O que falta

| Item | Situação |
|---|---|
| Backup e restauração testada dos bancos do MES e do av-hub (B2, B7) | 🟡 Adiado: "papo para outra hora" (Nathan, 14/10), sem data |
| `api-comercial` | É uma API de teste do Pablo, que migra tudo para a `api-acos-vital`. Não há ambiente nem cluster próprio a montar 📝 Pablo |
| Exposição de rede da `api-pcp` (item #13 do Registro do v1) | 🟡 Gustavo. A `api-pcp` já está no ar (Nathan); restringir a origem não foi discutido |
| Retenção de `auth.logs` (item #53) | 🔴 Gustavo |

Pendências gerais em [[Pontas-Soltas]]; riscos em [[Riscos]].

## Detalhe técnico

### Padrão de deploy ✅

| Serviço | Imagem base | Porta |
|---|---|---|
| HUB | `node:20-alpine`, build multi-stage (`deps`, `builder`, `runner`), saída standalone do Next.js, usuário não-root | 3000 |
| `api-acos-vital` | `node:20-alpine`, 2 estágios | 3000 |
| `api-comercial` | `node:22-slim`, 2 estágios | 3001 |
| `api-pcp` | `node:22-slim`, 2 estágios | 3000 |
| `app-pcp` | `node:22-slim`, 3 estágios | 3000 |

Evidência: `FROM` e `EXPOSE` em `00 - HUB\Dockerfile` (linhas 2, 8, 15, 27), `00 - HUB\api-comercial\Dockerfile` (2, 23, 50), `api-pcp\Dockerfile` (2, 29, 49), `api-acos-vital\Dockerfile` (1, 6, 14), `app-pcp\Dockerfile` (2, 11, 26, 45). Não há Nginx: o Traefik faz esse papel.

### Pipeline Omie

| Item | Detalhe |
|---|---|
| Processos | 6 no PM2 (`ecosystem.config.cjs`): `omie-extract-worker`, `omie-load-worker`, `omie-scheduler`, `omie-scraping-worker`, `omie-envio-oc-worker`, `omie-dashboard` ✅ |
| Compose | Redis 7 alpine + os processos; imagem do scraping em `Dockerfile.scraping` (Chromium para o Playwright) ✅ |
| Dashboard | Bull Board na porta **3011** (`docker-compose.yml:129`) com basic auth ✅ |
| Filas | `omie-extract`, `omie-load`, `omie-load-realtime`, `omie-query`, `omie-envio-oc` ✅ (`src/queue/index.ts:28,101,111`) |
| Pool de conexões | `PG_POOL_MAX` (padrão 10; `src/db/pool.ts:31`); o `load-worker` exige valor alto (comentário em `docker-compose.yml:70`): dimensionar junto com o limite de conexões do Postgres |
| Saída | API do Omie, API do BCB (PTAX) e API do av-hub (`AVHUB_API_URL`, envio da OC) ✅ |
