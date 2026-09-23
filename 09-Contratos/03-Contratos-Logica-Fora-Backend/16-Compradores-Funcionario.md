# Contrato — Compradores (Omie) ↔ Funcionário (RH)

**Criado em:** 23/09/2026.

**Objetivo:** ter no av-hub o cadastro de compradores, no mesmo esquema do vendedor
(`docs/implementados/OK - contrato-vinculo-vendedor-funcionario.md`):
- uma linha por comprador **por conta Omie** (Mogi, Uberaba);
- cada linha ligada a um `core.funcionarios`;
- a mesma pessoa pode ser vinculada como comprador em mais de uma filial.

Isso resolve o `nCodCompr` do `IncluirPedCompra`, que hoje não tem de onde sair
(`docs/ENVIAR - contrato-compras-omie-pedidocompra.md`, §3.2).

**Hoje não existe nada:** nem tabela, nem `/compradores`, nem `/compras/compradores` (as duas
rotas dão 404 em `api-test` em 23/09), nem recurso de compradores no `omie-elt-pipeline`.

---

## 1. O que o Omie oferece (e o que não oferece)

`POST https://app.omie.com.br/api/v1/estoque/comprador/` · `ListarCompradores`
(`pagina`, `registros_por_pagina` até 50) → `cadastros[]`:

| Omie | Tipo | Significado |
|---|---|---|
| `nCodigo` | integer | código do comprador **naquela conta** |
| `cDescricao` | string70 | nome |
| `cInativo` | string1 | `S`/`N` |

**Não tem inclusão nem alteração via API.** Então:
- para vincular alguém como comprador em **outra filial**, a pessoa precisa **primeiro existir
  como comprador no Omie daquela filial**, cadastrada pela UI do Omie. O av-hub só vincula,
  não cria comprador;
- o código só é único dentro da conta. Mogi e Uberaba podem repetir o mesmo `nCodigo`,
  como já acontece com vendedor. A chave é sempre `(codigo_empresa, codigo_comprador_omie)`.

---

## 2. Banco

```sql
CREATE TABLE core_vendas_faturamento.compradores (
  id                    uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo_empresa        uuid NOT NULL REFERENCES core.unidades(id)
                          ON UPDATE CASCADE ON DELETE RESTRICT,
  codigo_comprador_omie varchar(20) NOT NULL,   -- nCodigo. Texto, igual codigo_vendedor_omie
                                                 -- (evita o estouro de INTEGER de pedidos_compras)
  nome                  varchar(70) NOT NULL,   -- cDescricao, vem do Omie
  nome_exibicao         varchar(255),           -- editado no av-hub; NULL = usar nome
  ativo                 boolean NOT NULL DEFAULT true,   -- NOT cInativo
  id_funcionario        uuid REFERENCES core.funcionarios(id)
                          ON UPDATE CASCADE ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  created_by            uuid,
  updated_at            timestamptz NOT NULL DEFAULT now(),
  updated_by            uuid,
  deleted_at            timestamptz,
  deleted_by            uuid
);

-- Chave de negócio: o código só é único dentro da conta Omie.
CREATE UNIQUE INDEX uq_compradores_empresa_codigo
  ON core_vendas_faturamento.compradores (codigo_empresa, codigo_comprador_omie)
  WHERE deleted_at IS NULL;

-- Mesma pessoa em várias filiais: permitido (sem UNIQUE só em id_funcionario).
-- Mas no MÁXIMO um comprador por pessoa DENTRO da mesma filial. Senão não dá para
-- decidir qual nCodCompr mandar na OC daquela unidade.
CREATE UNIQUE INDEX uq_compradores_funcionario_empresa
  ON core_vendas_faturamento.compradores (id_funcionario, codigo_empresa)
  WHERE id_funcionario IS NOT NULL AND deleted_at IS NULL;

CREATE INDEX idx_compradores_id_funcionario
  ON core_vendas_faturamento.compradores (id_funcionario);

CREATE TRIGGER trg_compradores_updated_at
  BEFORE UPDATE ON core_vendas_faturamento.compradores
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

**Diferenças em relação a `vendedores`, de propósito:**
- **sem `id_usuario`**. O caminho usuário → funcionário já existe (`usuarios.id_funcionario`,
  o mesmo que o Portal do Vendedor usa em `resolverVendedoresSessao`). Um segundo caminho
  direto usuário → comprador poderia divergir do primeiro;
- sem `comissao`, `ajuda_custo` e `filial`, que são específicos de vendas;
- com o índice único `(id_funcionario, codigo_empresa)`, que o vendedor não tem.

### 2.1 Ordem de compra guarda o comprador

```sql
ALTER TABLE core_vendas_faturamento.ordens_compra
  ADD COLUMN id_comprador uuid
    REFERENCES core_vendas_faturamento.compradores(id)
    ON UPDATE CASCADE ON DELETE RESTRICT;
```

Preenchido **pelo backend no POST**, nunca aceito do corpo. A resolução é:
`created_by` (usuário da sessão) → `usuarios.id_funcionario` → o comprador com esse
`id_funcionario`, o mesmo `codigo_empresa` da OC e `ativo = true`.

A coluna fica **gravada na OC**. Se o vínculo mudar depois, a OC já emitida continua com o
comprador da época, e é esse que vai no `nCodCompr`.

---

## 3. Pipeline (`omie-elt-pipeline`)

Recurso novo `src/omie/resources/compradores.ts`, no molde de `vendedores.ts`:
- `endpointPath: '/estoque/comprador/'`, `listMethod: 'ListarCompradores'`,
  `listResponseKey: 'cadastros'`, 50 por página;
- é catálogo pequeno, sem janela de data: entra no `full_sync` diário (e na carga inicial);
- upsert em `(codigo_empresa, codigo_comprador_omie)`; `nome ← cDescricao`,
  `ativo ← cInativo = 'N'`;
- **colunas protegidas** (`src/db/protectedColumns.ts`): `id_funcionario`, `nome_exibicao`.
  O sync nunca sobrescreve o vínculo feito no av-hub, igual `vendedores.id_funcionario`;
- comprador que sumiu do Omie **não é apagado**: fica `ativo = false`. OCs antigas apontam
  para ele.

---

## 4. API (`api-acos-vital`)

```
GET  /compras/compradores?codigo_empresa=&id_funcionario=&ativo=&q=&page=&limit=
GET  /compras/compradores/{id}
PUT  /compras/compradores/{id}              body: { nome_exibicao?, id_funcionario? (uuid|null) }
GET  /compras/compradores/{id}/sugestoes    → { sugestao: { id_funcionario, nome_funcionario,
                                                            codigo_empresa_origem } | null }
```

- Cada linha devolve também `nome_funcionario` (JOIN em `core.funcionarios`) e o nome da
  unidade, para a tela não precisar de uma segunda chamada.
- **Sem POST nem DELETE**: o comprador nasce e morre no Omie (§1). Criar no av-hub geraria
  um código que o Omie não conhece.
- **O PUT só altera `nome_exibicao` e `id_funcionario`.** `nome`, `ativo` e o código vêm do
  sync. `id_funcionario: null` explícito **limpa** o vínculo; campo ausente não mexe.
- **Sugestão:** o DBA escreve o SQL, no mesmo molde do vendedor: mesmo nome
  (`unaccent(lower())`) em outra unidade, já vinculado a um funcionário. É o caso da pessoa
  que compra por Mogi e por Uberaba. A sugestão não grava nada (§6.3).
- **Erros:**
  - `409 "Este funcionário já é comprador nesta unidade (<nome>)"` quando viola
    `uq_compradores_funcionario_empresa`;
  - `409 "id_funcionario não existe"` quando a FK falha.

### 4.1 OC

- `POST /compras/ordens` resolve e grava `id_comprador` (§2.1). Sem comprador vinculado,
  responde 400 (§6.1). `id_comprador` vindo no corpo é ignorado (§6.2).
- `GET /compras/ordens` e `/{id}` devolvem `id_comprador` e `nome_comprador`
  (`COALESCE(nome_exibicao, nome)`). Isso substitui o `nome_criado_por` pedido no C1 de
  `ENVIAR - contrato-compras-pendencias-pos-backend.md` para a coluna "Comprador". O
  `nome_criado_por` continua útil para auditoria.
- O envio ao Omie manda `nCodCompr = compradores.codigo_comprador_omie` do `id_comprador`.

---

## 5. av-hub (eu faço, depois do §4)

- **Tela nova `cadastros/acessos/compradores`**, espelho de `cadastros/acessos/vendedores`:
  - listagem por unidade: código Omie, nome, nome de exibição, unidade, funcionário, ativo;
  - modal de edição só com nome de exibição e **Funcionário** (Autocomplete), mais o atalho
    "usar o mesmo funcionário" quando `/sugestoes` achar alguém;
  - sem botão "Novo": o comprador vem do Omie. A tela explica isso quando a lista da unidade
    estiver vazia.
- **Formulário da OC:**
  - mostra "Comprador: <nome> (<unidade>)", resolvido para o usuário logado e a unidade
    escolhida;
  - se não houver comprador vinculado naquela unidade, mostra o aviso da §6.1 e desabilita
    "Emitir". Sem seleção de comprador (§6.2).
  - para descobrir o comprador, o BFF usa o mesmo caminho de `resolverVendedoresSessao`:
    usuário da sessão → `usuarios.id_funcionario` →
    `GET /compras/compradores?id_funcionario=&codigo_empresa=&ativo=true`. É só para mostrar o
    aviso; quem decide é o backend no POST.
- **Detalhe e listas da OC:** mostram `nome_comprador`.

**Depende do DBA (fora do av-hub):** criar a tela `compradores` na matriz de permissões
(`pode_visualizar`/`pode_editar`) e o item de menu.

---

## 6. Decisões (confirmadas em 23/09/2026)

1. **Usuário sem comprador vinculado na unidade da OC: a emissão é bloqueada.**
   `POST /compras/ordens` responde
   `400 "Você não está vinculado como comprador em <unidade>. Peça ao administrador para fazer o vínculo."`.
   Essa regra vale **no backend**, não só na tela. O formulário do av-hub mostra o mesmo aviso
   antes de o usuário preencher a OC e desabilita o botão de emitir.
2. **Só o próprio comprador emite.** Ninguém emite OC em nome de outro. O `id_comprador` é
   sempre o do usuário logado (§2.1), e o formulário não tem seleção de comprador. O backend
   **ignora** qualquer `id_comprador` que venha no corpo do POST.
3. **O vínculo é manual, feito pelo administrador** na tela `cadastros/acessos/compradores`.
   **Não há backfill automático.** Para ajudar, a tela tem **sugestão, igual à de vendedores**:
   `GET /compras/compradores/{id}/sugestoes` (§4). **O DBA escreve o SQL de compatibilidade
   desta sugestão**, no mesmo molde do vendedor (mesmo nome, `unaccent(lower())`, em outra
   unidade, já vinculado). A sugestão só **propõe**; quem grava é o administrador, pelo `PUT`.

## 7. Rollout

1. DBA: tabela da §2, `id_comprador` em `ordens_compra`, tela na matriz de permissões.
2. Pipeline: recurso `compradores` com as colunas protegidas. Rodar a carga inicial das duas
   contas.
3. Backend: rotas da §4 e a resolução de `id_comprador` no `POST /compras/ordens`.
4. av-hub: tela de compradores. O administrador vincula os compradores existentes, com a
   ajuda da sugestão.
5. **Só depois do passo 4** o bloqueio da §6.1 é ligado no `POST /compras/ordens`. Antes
   disso, ninguém conseguiria emitir OC.
