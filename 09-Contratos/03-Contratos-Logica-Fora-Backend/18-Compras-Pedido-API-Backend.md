# Compras — pedido para a API (`api-acos-vital`)

**Data:** 23/09/2026 · **Para:** backend
**Depende de:** `01 - DBA - banco.md` (tabelas D1, D3, D4, D6).
**Contratos completos, só para referência:**
`../ENVIAR - contrato-compras-pendencias-pos-backend.md` (itens C1–C7) e
`../ENVIAR - contrato-compradores-funcionario.md`.

O av-hub já está ligado nas rotas de Compras entregues em 22/09 (PR #273). Abaixo, o que falta
nelas e as rotas novas.

---

## A0. Número da OC e da requisição: o banco gera, só o número

- **Tirar a geração `OC-`/`REQ-` com `count(...) + 1`** do `POST /compras/ordens` e do
  `POST /compras/requisicoes`. Ela duplica o número quando duas emissões chegam ao mesmo tempo.
  O número passa a vir do `DEFAULT nextval(...)` do banco (D4), e o prefixo é só da tela.
- Tirar `numero_ordem` e `numero_requisicao` da lista de campos aceitos no corpo (`CAMPOS`).
- Requisição vinda do MES: o número do MES vai em `numero_requisicao_mes`, não em
  `numero_requisicao`.
- `q` continua buscando pelo número (agora numérico, comparar como texto).

## A1. Nomes na OC (hoje só vêm códigos)

Em `GET /compras/ordens` (listagem) e `GET /compras/ordens/{id}`, devolver também:

| Campo | Origem |
|---|---|
| `nome_fornecedor`, `cpf_cnpj_fornecedor` | `core.parceiros` com `codigo_empresa` da OC + `codigo_parceiro_omie = codigo_fornecedor` |
| `nome_transportadora` | `core.parceiros` pelo `codigo_transportadora` |
| `id_comprador`, `nome_comprador` | `compradores`: `COALESCE(nome_exibicao, nome)` |
| `nome_criado_por`, `nome_aprovado_por` | usuários `created_by` e `aprovado_por` |

O JOIN **tem que usar `codigo_empresa`**: o mesmo fornecedor tem código diferente em cada
filial. Hoje a tela mostra "Fornecedor 10037044822".

## A2. OC só aceita parceiro da própria unidade

`POST /compras/ordens` → `400` se `codigo_fornecedor` ou `codigo_transportadora` não existir em
`core.parceiros` para o `codigo_empresa` da OC.

## A3. Comprador na emissão da OC (regras confirmadas)

No `POST /compras/ordens`:
1. Resolver o comprador: `created_by` (usuário) → `usuarios.id_funcionario` → o comprador com
   esse `id_funcionario`, o mesmo `codigo_empresa` da OC e `ativo = true`. Gravar em
   `id_comprador`.
2. **Não encontrou → bloquear:**
   `400 "Você não está vinculado como comprador em <unidade>. Peça ao administrador para fazer o vínculo."`
3. **Ignorar `id_comprador` no corpo.** Ninguém emite em nome de outro comprador.

⚠️ Só ligar o bloqueio do item 2 **depois** que o administrador tiver vinculado os compradores.
Antes disso, ninguém consegue emitir OC.

## A4. Rotas de compradores (novas)

```
GET  /compras/compradores?codigo_empresa=&id_funcionario=&ativo=&q=&page=&limit=
GET  /compras/compradores/{id}
PUT  /compras/compradores/{id}             body: { nome_exibicao?, id_funcionario? (uuid|null) }
GET  /compras/compradores/{id}/sugestoes   → { sugestao: { id_funcionario, nome_funcionario,
                                                           codigo_empresa_origem } | null }
```

- **Listagem:** cada linha já traz `nome_funcionario` e o nome da unidade.
- **Sem POST nem DELETE:** o comprador vem do Omie, via pipeline.
- **PUT:** só altera `nome_exibicao` e `id_funcionario`. `null` explícito limpa o vínculo;
  campo ausente não mexe.
- **Sugestões:** usa o SQL que o DBA escreveu (D2).
- **Erros:**
  - `409 "Este funcionário já é comprador nesta unidade (<nome>)"`;
  - `409 "id_funcionario não existe"`.

## A5. Busca de OC pelo nome do fornecedor

`q` em `GET /compras/ordens` também procura no nome do fornecedor (depende do A1).

## A6. Indicadores

```
GET /compras/requisicoes/resumo?codigo_empresa=  → { abertas, em_cotacao, atendidas, canceladas }
GET /compras/ordens/resumo?codigo_empresa=       → { aguardando_aprovacao,
                                                     valor_aguardando_aprovacao_brl,
                                                     aprovadas, canceladas }
```

Registrar essas rotas **antes** de `/:id`. Hoje `/compras/ordens/resumo` cai no `/:id` e
responde "id deve ser um uuid".

## A7. Limite de aprovação e catálogo de condições

```
GET /compras/parametros?codigo_empresa=              → { limite_aprovacao }
GET /compras/condicoes-pagamento?codigo_empresa=     → [{ codigo_omie, descricao,
                                                         quantidade_parcelas, lista_dias }]
```

O segundo é uma projeção da tabela D6, no mesmo formato de `/compras/fornecedores`.

## A8. Permissão e auditoria

- `aprovado_por`, `created_by` e `updated_by` hoje são aceitos do corpo do request. O av-hub
  manda os valores da sessão, mas uma chamada direta pode aprovar em nome de qualquer um.
  Validar ou tirar da identidade autenticada.
- Aprovar e reprovar passam a exigir `pode_aprovar` (D7).
- Registrar histórico de decisão (quem, quando, de → para). Ao cancelar hoje só fica o
  `motivo_reprovacao`.
