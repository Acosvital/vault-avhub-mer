# Contrato — chave composta (numero_pedido + codigo_empresa) em blacklist_pedidos

**Criado em:** 15/09/2026, achado num review de segurança/correção de dados.

**Objetivo:** `PUT`/`DELETE /blacklist_pedidos/:numero` usam só `numero_pedido` como chave, mas
`numero_pedido` **não é único entre empresas** — é o número sequencial do Omie, por conta. A
própria tela já avisa isso ao criar (`app/(protected)/cadastros/auxiliares/blacklist_pedidos/page.tsx`,
helper text "numero_pedido não é único entre empresas — precisa saber de qual unidade"), e por
isso `POST` já exige `codigo_empresa`. `PUT`/`DELETE` ficaram de fora dessa exigência.

## 1. O problema

Se a Empresa A e a Empresa B tiverem cada uma um pedido de número `12345` na blacklist (comum —
cada empresa numera do zero no Omie), `DELETE /blacklist_pedidos/12345` não tem como saber qual
das duas linhas apagar. Mesmo problema em `PUT`. `GET /blacklist_pedidos?numero_pedido=12345`
também não filtra por empresa (confirmado em `services/cadastros/auxiliares/blacklistPedidos.ts`).

## 2. O que peço

`PUT`/`DELETE /blacklist_pedidos/:numero` aceitarem `codigo_empresa` como parte da chave —
seja via query string (`?codigo_empresa=X`) ou no body do `PUT`, e um equivalente pro `DELETE`
(query string, já que `DELETE` normalmente não carrega body). Se `codigo_empresa` não bater com o
registro do `numero_pedido` informado, `404` (mesmo comportamento de "não encontrado" que já
existe pra número inválido). Também ajudaria `GET /blacklist_pedidos?numero_pedido=X` aceitar
`codigo_empresa` como filtro adicional, pelo mesmo motivo.

## 3. O que muda no frontend quando isso existir

- `services/cadastros/auxiliares/blacklistPedidos.ts`: `editarBlacklistPedido`/`deletarBlacklistPedido`
  passam a receber `codigo_empresa` também, repassado como query param.
- `app/api/blacklist_pedidos/[numero]/route.ts`: `PUT`/`DELETE` leem `codigo_empresa` da query e
  repassam pro backend.
- `app/(protected)/cadastros/auxiliares/blacklist_pedidos/page.tsx`: remove a checagem de
  ambiguidade adicionada como trava temporária em `abrirEdicaoModal` (chama `getBlacklistPedidos`
  de novo só pra contar colisões antes de deixar editar/excluir) — com chave composta de verdade,
  a ambiguidade deixa de existir e a chamada extra não é mais necessária.

## 4. Não bloqueia

Enquanto isso não existir, a tela bloqueia editar/excluir sempre que o mesmo `numero_pedido`
aparece em mais de uma empresa (checagem client-side, com aviso claro pro usuário) — mais lento
(1 chamada a mais por clique) e não resolve o caso ambíguo, mas evita mexer no registro errado.
