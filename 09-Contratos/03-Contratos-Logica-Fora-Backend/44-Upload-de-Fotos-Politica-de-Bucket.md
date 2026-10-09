---
tags: [contrato-logica, seguranca, armazenamento, upload, gambiarra-s10]
criado: 2026-10-07
atualizado: 2026-10-09
status: proposta
prioridade: baixa
---

# Contrato 44 — Upload de fotos: política no bucket (reforço da GAMBIARRA S10)

## (atualizado em 09/10/2026) Decisão sobre a marca, política do bucket e ordem de execução

> **(atualizado em 09/10/2026)** Conferido no av-hub (`lib/s3/client.ts`, `lib/s3/fotos.ts`, `lib/uploadConstraints.ts`, `scripts/listar-bucket-pessoas.mjs`, `proxy.ts`). Regra do Nathan: **nenhuma variável de ambiente nova para regra**; o que é regra fica fixo no código ou no storage. Fora de escopo: comissões. Legenda: ✅ verificado · 🟡 inferência · 🔴 pendente. O texto antigo abaixo foi preservado.

### A. A marca `GAMBIARRA(` em `lib/s3/fotos.ts:19`: reclassificar

- ✅ A validação do BFF (MIME na lista, 5 MB, bytes iniciais, prefixo `uploads/`, chave UUID gerada no servidor, permissão por tela) é **defesa em profundidade legítima e não é gambiarra**. Fica como está; não há mudança de lógica.
- **Recomendação:** trocar só o comentário da linha 19, tirando `GAMBIARRA(` e deixando:

  `// DEFESA EM PROFUNDIDADE: validação de upload no BFF. A política do bucket (credencial só em uploads/, 5 MB, tipos) é o reforço no storage, não a substituição desta checagem. Ver vault 09-Contratos/03-Contratos-Logica-Fora-Backend/44-Upload-de-Fotos-Politica-de-Bucket.md`

- A reclassificação é só de comentário e pode ser feita **já** (a marca descrevia a política que falta, não um erro do código). A contagem de `GAMBIARRA(` no front cai em 1 (ver [[Registro-de-Decisoes-2026-10-07]], itens 58, 77 e 79). Confirmação do Nathan: Q4.
- A política do storage **reforça** o BFF: protege contra quem tem a credencial ou outro sistema escrevendo no bucket. Ela olha o `Content-Type` declarado, que quem grava define, então **não substitui** a checagem dos bytes.

### B. MinIO ou SeaweedFS: não resolvido por evidência (🔴)

| Fonte | O que diz |
|---|---|
| `Infraestrutura-Self-Hosted.md:19`, `Decisoes-Chave-ERP.md:78`, `Diagramas-UML.md:971,1019` (vault) | VPS 3 = **MinIO**. |
| `lib/s3/client.ts:7-8` (front) | Comentário: `forcePathStyle` é necessário para S3-compatíveis "(SeaweedFS)". |
| `docs/implementados/OK - pendencia-foto-unidades.md:4` (front) | "armazenamento no SeaweedFS interno". |
| `App-PCP-Backend-Producao.md:40`, `AV-Hub-Bugs-Catalogo.md:23` (vault) | "SeaweedFS presumido" / "S3/SeaweedFS". |
| `proxy.ts:15-18` (front) | O valor de `S3_ENDPOINT` só existe como variável de produção. |

- ✅ O código usa só API S3 padrão (`PutObject`, `GetObject`, `DeleteObject`, `ListObjectsV2` no script, URL assinada), `forcePathStyle: true` e região padrão `us-east-1`: **funciona nos dois produtos**, então o código não decide.
- ✅ Não há `.env.example` no front. O `.env.local` tem os **nomes** `S3_ENDPOINT`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_REGION`, `S3_BUCKET_PESSOAS`, `S3_BUCKET_EMPRESA`; o `S3_ENDPOINT` local não contém "minio" nem "seaweed" (valores não impressos).
- 🟡 Os comentários de SeaweedFS são de quem escreveu o código, e o vault também só "presume"; o vault do MinIO é de nota de arquitetura. **Sem prova em nenhum dos lados.**
- 🔴 **Pergunta exata ao Gustavo/infra:** "Na VPS 3, o serviço que responde em `S3_ENDPOINT` em produção é MinIO ou SeaweedFS? (tela do Coolify, `docker ps`, ou o cabeçalho `Server` de uma resposta do endpoint). Se SeaweedFS, é `weed s3` com identidades em `s3.json`?"

### C. Buckets e variáveis (somente nomes)

- `S3_BUCKET_PESSOAS` (nome lógico `pessoas`, fotos de funcionários; também lido pelo Organograma legado) e `S3_BUCKET_EMPRESA` (nome lógico `empresa`, fotos de unidades). Valores: fora do vault e do código; não inventados.
- **Nenhuma variável nova.** `S3_ACCESS_KEY` e `S3_SECRET_KEY` já existem e só recebem a credencial nova. Prefixo `uploads/`, 5 MB e os três MIME continuam **fixos no código** (`fotos.ts:47`, `uploadConstraints.ts:8`); o resto da regra vai para o storage.

### D. O que o storage precisa (e tradução por produto)

Fato do código: ✅ `deletarFoto` (`fotos.ts:90`) **não tem nenhum chamador**; o av-hub em runtime só faz `PutObject` e `GetObject` (a listagem existe só em `scripts/listar-bucket-pessoas.mjs`, manual). Logo a credencial de runtime **não precisa de exclusão nem de listagem**.

| # | Requisito | MinIO (`mc`) | SeaweedFS |
|---|---|---|---|
| R1 | Credencial dedicada ao av-hub (não a de admin) | 🟡 `mc admin user add` + `mc admin policy attach` | 🟡 nova identidade no `s3.json` com ações limitadas |
| R2 | Escrita só em `uploads/*`; leitura no bucket todo (fotos antigas `Setor/Cargo/nome.webp` e as do Organograma); sem `Delete` e sem `List` | 🟡 política JSON: `s3:PutObject` em `arn:aws:s3:::<bucket>/uploads/*` e `s3:GetObject` em `arn:aws:s3:::<bucket>/*` | 🟡 ações `Write:<bucket>/uploads/` e `Read:<bucket>` (formato `Ação:bucket/prefixo`; confirmar na versão instalada) |
| R3 | Tamanho máximo 5 MB | 🟡 política de bucket não limita tamanho de PUT; tratar como **limitação** e manter o limite do BFF | 🟡 sem limite por bucket conhecido; mesmo tratamento |
| R4 | Tipos permitidos | 🟡 `Content-Type` é declarado por quem grava; sem efeito real. **Limitação**; o BFF (bytes) é a barreira | 🟡 idem |
| R5 | CORS | ✅ **Não necessário**: o navegador não grava no storage (upload vai a `POST /api/uploads`); leitura é por `<img>` com URL assinada. Só se algum dia houver `fetch` direto | idem |
| R6 | Expiração de objetos órfãos | 🟡 regra de ciclo de vida só no prefixo `uploads/` (`mc ilm`); **não aplicar sem a lista de órfãos**, para não apagar foto em uso | 🟡 idem (TTL) |
| R7 | Varredura de vírus | 🔴 não existe no stack (E5); aceitar sem (Q3) | idem |

Resumo: **R1 e R2 são o ganho real e valem nos dois produtos**; R3 e R4 provavelmente **não se aplicam** no storage e ficam como limitação aceita, com o BFF como barreira (🟡, confirmar na documentação da versão instalada).

### E. Passo a passo (ordem)

1. **Infra responde Q1** e informa os nomes reais dos dois buckets e quem mais escreve neles (Q2).
2. Rodar `scripts/listar-bucket-pessoas.mjs` (manual) para mapear prefixos existentes e confirmar que só `uploads/` precisa de escrita do av-hub.
3. Criar a credencial dedicada (R1) e a política (R2) **em bucket de teste**. Rodar os testes F.
4. Conferir se o Organograma escreve ou apaga fora de `uploads/` (Q3): ele **mantém a credencial atual**; não trocar a dele junto.
5. Em produção: trocar `S3_ACCESS_KEY`/`S3_SECRET_KEY` do av-hub no Coolify (deploy). Sem mudança de código.
6. Testes F passando em produção: reclassificar o comentário (seção A) se ainda não feito; guardar o texto da política no vault.

### F. Testes de aceite

- **Upload válido** (JPEG, PNG, WebP até 5 MB) pelo av-hub: sucesso e a foto aparece via URL assinada.
- **Tipo trocado** (HTML com `Content-Type: image/jpeg`): o BFF devolve 400 "O conteúdo do arquivo não é uma imagem válida". Direto ao storage: aceito se R4 não se aplicar (registrar como limitação).
- **Arquivo grande** (acima de 5 MB): o BFF recusa; direto ao storage, só recusa se R3 se aplicar.
- **Fora do prefixo** (`PutObject` em `outra/arquivo.jpg` com a credencial nova): **negado (403)**.
- **Credencial sem exclusão**: `DeleteObject` e `ListObjectsV2` com a credencial do av-hub: **negados**.
- **Leitura legada**: foto antiga (`Setor/Cargo/nome.webp`) e foto do Organograma continuam servindo por URL assinada.

### G. Rollback

Recolocar a credencial anterior em `S3_ACCESS_KEY`/`S3_SECRET_KEY` e redeployar (manter a antiga **ativa** até o fim da janela de teste). A política nova pode ser desanexada sem afetar objetos. Sintoma de erro: upload devolve 500 "Erro interno" (403 do storage).

### H. Perguntas em aberto (desta atualização)

| # | Pergunta | Dono |
|---|---|---|
| Q1 | 🔴 MinIO ou SeaweedFS? Pergunta exata na seção B. | Gustavo / infra |
| Q2 | 🔴 Nomes reais (`S3_BUCKET_PESSOAS`, `S3_BUCKET_EMPRESA`) e quem além do av-hub escreve ou apaga neles. | Gustavo / infra |
| Q3 | 🔴 O Organograma legado pode seguir com a credencial atual enquanto o av-hub usa a nova? | Gustavo |
| Q4 | 🔴 Aceitar reclassificar a marca (seção A) e a limitação de R3/R4? | Nathan |
| Q6 | 🔴 Há objetos órfãos em `uploads/` (UUID sem registro no banco)? Só então decidir R6. | Gustavo |

---

## Texto original (07/10/2026), preservado

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
