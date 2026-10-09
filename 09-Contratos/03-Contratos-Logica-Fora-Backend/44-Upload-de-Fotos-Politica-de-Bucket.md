---
tags: [contrato-logica, seguranca, armazenamento, upload, gambiarra-s10]
criado: 2026-10-07
atualizado: 2026-10-07
status: proposta
prioridade: baixa
---

# Contrato 44 — Upload de fotos: política no bucket (reforço da GAMBIARRA S10)

> **Status: proposta, baixa prioridade (07/10/2026).** Marcação `GAMBIARRA(` de `lib/s3/fotos.ts:19` do av-hub ("validação de upload no BFF (S10): política de bucket/varredura no backend"). Fontes: leitura de `lib/s3/fotos.ts`, `lib/s3/client.ts`, `lib/uploadConstraints.ts` e `app/api/uploads/route.ts`. Legenda: ✅ verificado no código · 🟡 inferência · 🔴 pendente com dono. Decisões gerais em [[Registro-de-Decisoes-2026-10-07]].

**Para:** infra/Gustavo (VPS 3, arquivos) · av-hub só se algo mudar na chave.

## 1. Honestidade: o que é gambiarra e o que é melhoria

- **Não é gambiarra:** a checagem dos bytes iniciais no BFF é uma defesa legítima e correta (impede um HTML enviado como "image/jpeg"). **Deve ficar** como defesa em profundidade, mesmo depois deste contrato.
- **O que é de fato limitação (🟡):** o BFF é a **única** barreira. Quem tiver a credencial S3 (`S3_ACCESS_KEY`) grava qualquer coisa no bucket, sem passar por esta validação; e outros sistemas que escrevem no mesmo bucket (o Organograma legado usa o bucket `pessoas`) não herdam a regra. A marcação `GAMBIARRA(` descreve isso, não um erro do código.
- **Melhoria, não correção:** política no armazenamento + varredura. Risco real hoje: baixo (só usuários com `pode_criar`/`pode_editar` em `funcionarios` ou `unidades` enviam; bucket privado, leitura só por URL assinada de 1 h). Por isso a prioridade é baixa.

## 2. Estado atual (✅)

Fluxo `POST /api/uploads` (`app/api/uploads/route.ts`):

1. Exige sessão (401) e permissão na tela do bucket: `pessoas` → `funcionarios`, `empresa` → `unidades`, com `pode_criar` ou `pode_editar` (403).
2. `bucket` só pode ser `pessoas` ou `empresa` (400).
3. `file.type` na lista **`image/jpeg`, `image/png`, `image/webp`** (`lib/uploadConstraints.ts`) e tamanho **máximo 5 MB**. O `file.type` vem do cliente.
4. `conteudoCombinaComMime` confere a assinatura: JPEG `FF D8 FF`; PNG os 8 bytes de assinatura; WebP `RIFF....WEBP`. Qualquer outro tipo devolve `false`.
5. `uploadFoto` grava com chave **`uploads/<uuid>.<ext>`** (extensão derivada do MIME validado, `ContentType` igual ao MIME) e devolve `/api/fotos/uploads/<uuid>.<ext>` (formato do proxy do Organograma legado).
6. Leitura sempre por URL assinada (`assinarUrlFoto`, **3600 s**); o bucket é privado.

**O que o BFF não faz:** não reencoda a imagem (o navegador reencoda no editor, mas isso não é garantia do servidor); não confere dimensões; não varre vírus; não limita quantidade/taxa de uploads por usuário.

**Usuários de `lib/s3/fotos.ts`:** `app/api/uploads/route.ts`, `app/api/funcionarios/route.ts`, `app/api/funcionarios/[id]/route.ts`, `app/api/funcionarios/[id]/equipe/route.ts` e `app/api/unidades/route.ts` (os quatro últimos só assinam URLs).

**Buckets:** o código só conhece os nomes **lógicos** `pessoas` e `empresa`; os nomes reais vêm das variáveis de ambiente **`S3_BUCKET_PESSOAS`** e **`S3_BUCKET_EMPRESA`** (endpoint em `S3_ENDPOINT`, credenciais em `S3_ACCESS_KEY`/`S3_SECRET_KEY`). **Os valores não estão no código nem no vault**; este contrato não os inventa.

## 3. Proposta (reforço no armazenamento)

| # | Item | Detalhe |
|---|---|---|
| E1 | Credencial de upload dedicada ao av-hub | Usuário/chave S3 só com `PutObject`/`GetObject`/`DeleteObject` nos **dois** buckets, sem permissão de administração nem de listar outros buckets. |
| E2 | Restrição de prefixo | Escrita do av-hub só em **`uploads/`**. 🟡 O prefixo antigo (`Setor/Cargo/nome.webp`, fotos migradas, e o que o Organograma escreve) precisa continuar **legível**; só a **escrita** é restrita. Conferir antes com `scripts/listar-bucket-pessoas.mjs` (existe no av-hub). |
| E3 | Tamanho máximo | Rejeitar objeto acima de **5 MB** no storage (igual a `TAMANHO_MAXIMO_BYTES`), se o produto suportar limite por bucket/política. |
| E4 | Tipos permitidos | Aceitar só `Content-Type` `image/jpeg`, `image/png`, `image/webp` e extensões `jpg`, `png`, `webp`. 🟡 Depende de o storage permitir condição por tipo na política. |
| E5 | Varredura | Só se **já existir** no stack (antivírus/ClamAV na VPS 3). 🔴 Não achei nada disso no vault ou no código; **não propor instalar nada novo sem decisão**. |
| E6 | Manter a checagem do BFF | Sem mudança em `fotos.ts`. A marcação `GAMBIARRA(` pode virar um comentário normal ("defesa em profundidade; política do bucket em [[44-Upload-de-Fotos-Politica-de-Bucket]]") quando E1 a E4 estiverem no ar. |

## 4. Atenção: MinIO ou SeaweedFS? (🔴)

O vault diz que a VPS 3 roda **MinIO** ([[Infraestrutura-Self-Hosted]]), mas o código do av-hub (`lib/s3/client.ts`, doc de `pendencia-foto-unidades`) diz **SeaweedFS interno**; o próprio vault tem notas que presumem SeaweedFS (`App-PCP-Backend-Producao`, `AV-Hub-Bugs-Catalogo`). **Qual dos dois é o storage real muda tudo desta proposta:** a forma de política de bucket, o suporte a limite de tamanho e a restrição por tipo são diferentes em cada um. Confirmar antes de escrever qualquer política.

## 5. Passos

1. Gustavo confirma o storage real (Q1) e lista os nomes dos dois buckets e quem mais escreve neles (Organograma, outros).
2. Criar a credencial dedicada (E1) em homologação/teste, não em produção.
3. Aplicar E2 a E4 no bucket de teste e rodar os testes da §6.
4. Trocar `S3_ACCESS_KEY`/`S3_SECRET_KEY` do av-hub (e do Organograma, se escrever no mesmo bucket) em produção. Sem mudança de código no av-hub.
5. Aplicar a política nos buckets de produção; guardar o texto da política no vault (como o SQL do `fn_requisicao_mes_aplicar` ainda não está).

## 6. Testes de aceite

- Upload normal pelo av-hub (JPEG, PNG, WebP de até 5 MB) continua funcionando; a foto aparece via URL assinada.
- Escrita direta com a credencial do av-hub fora de `uploads/` → **negada**.
- Objeto acima de 5 MB, ou com `Content-Type` `text/html`, enviado direto ao storage → **recusado** (se o produto permitir E3/E4; se não, registrar como limitação).
- Fotos antigas (`Setor/Cargo/nome.webp`) e as do Organograma continuam sendo lidas.
- A checagem do BFF continua recusando um HTML com `Content-Type: image/jpeg` (400 "O conteúdo do arquivo não é uma imagem válida").
- Leitura de uma chave inexistente ou de outro prefixo pelo av-hub não vaza listagem.

## 7. Riscos

- **Quebrar o Organograma:** restringir a credencial ou o prefixo sem saber quem mais escreve em `pessoas` derruba o upload do sistema legado (🟡, o código dele não foi lido).
- **Trocar a credencial** em produção exige novo deploy/variáveis do av-hub no Coolify; erro = upload falha (401/403 do storage, o BFF devolve 500 "Erro interno").
- **Política incompatível com o storage** (ver §4): pode ser aceita e não ter efeito. Testar sempre com um upload proibido.
- **Falsa sensação de segurança:** política de tipo olha o cabeçalho `Content-Type`, que quem escreve define. Ela não substitui a checagem de bytes; por isso o BFF fica.

## 8. Perguntas em aberto

| # | Pergunta | Dono |
|---|---|---|
| Q1 | 🔴 O storage da VPS 3 é MinIO ou SeaweedFS? | Gustavo / infra |
| Q2 | 🔴 Nomes reais dos buckets (`S3_BUCKET_PESSOAS`, `S3_BUCKET_EMPRESA`) e quem além do av-hub escreve neles (Organograma, outros). | Gustavo |
| Q3 | 🔴 Existe antivírus/varredura no stack? Se não, aceitar sem (risco baixo, §1)? | Gustavo / Nathan |
| Q4 | 🔴 Aceitar a prioridade baixa e fazer só E1 a E4, mantendo o BFF como está? | Nathan |
| Q5 | 🟡 Limitar quantidade/taxa de uploads por usuário no BFF? Hoje não há. | Nathan |
