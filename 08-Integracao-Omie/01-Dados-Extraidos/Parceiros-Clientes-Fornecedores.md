---
tags: [integracao-omie, dados-extraidos]
criado: 2026-09-17
atualizado: 2026-10-07
---

# Parceiros (Clientes/Fornecedores)

> **Atualização de 07/10/2026 — a tabela abaixo (de 17/09) lista só as colunas básicas; o pipeline passou a gravar também 14 campos fiscais** (66f9a2e), ver a seção "Dados fiscais (novo em 07/10)". Fonte: leitura de código (`master` d2886bf), não produção. Também: entidades HTML são decodificadas nos textos de parceiros (`decodificarEntidadesHtml`), e a coluna `codigo_empresa` hoje aceita **N filiais** (não só `mogi`/`uberaba`).

Fonte: Omie `ListarClientes` (`/geral/clientes/`), resource `parceiros.ts`. Destino: `core.parceiros`. Chave de conflito (upsert): `(codigo_empresa, codigo_parceiro_omie)`.

| Coluna | Campo/origem Omie |
|---|---|
| codigo_parceiro_omie | `cliente.codigo_cliente_omie` |
| nome_fantasia | `cliente.nome_fantasia` |
| razao_social | `cliente.razao_social` |
| cpf_cnpj | `cliente.cnpj_cpf` |
| observacao | `cliente.observacao` |
| email | `cliente.email` |
| telefone | calculado de `telefone1_ddd` + `telefone1_numero`, formatado `(ddd)numero`, truncado em 20 caracteres |
| celular | calculado de `telefone2_ddd` + `telefone2_numero` |
| homepage | `cliente.homepage` |
| logradouro | `cliente.endereco` |
| numero | `cliente.endereco_numero` |
| complemento | `cliente.complemento` |
| bairro | `cliente.bairro` |
| cidade | `cliente.cidade` |
| estado | `cliente.estado` |
| cep | `cliente.cep` |
| codigo_empresa | filial (hoje `mogi`/`uberaba` no `.env.example`; o código aceita N filiais) |
| **latitude_y, longitude_x** | **não vêm do Omie** — coluna protegida, preenchida por job de geocodificação à parte (`geocodeParceiros.ts`, Nominatim). Ver [[Colunas-Protegidas]]. |
| id, id_origem, created_at/by, updated_at/by, deleted_at/by | gerenciadas pelo banco |

## Dados fiscais (novo em 07/10)

Gravados em `core.parceiros` pelo mesmo `ListarClientes`, sem chamada nova (66f9a2e). A lista de colunas segue a do passo 1 do [[Roteiro-de-Implementacao]]; o campo Omie de cada uma está lá.

| Coluna | Campo Omie |
|---|---|
| inscricao_estadual, inscricao_municipal, inscricao_suframa | `inscricao_estadual`, `inscricao_municipal`, `inscricao_suframa` |
| optante_simples_nacional | `optante_simples_nacional` (S/N → bool) |
| contribuinte_icms | `contribuinte` (S/N → bool) |
| cnae, tipo_atividade | `cnae`, `tipo_atividade` |
| pessoa_fisica, produtor_rural | `pessoa_fisica`, `produtor_rural` (S/N → bool) |
| cidade_ibge | `cidade_ibge` |
| valor_limite_credito, bloquear_faturamento | `valor_limite_credito`, `bloquear_faturamento` |
| inativo | `inativo` (S/N → bool) |

A IE e os dados fiscais alimentam a IE do PDF da OC (contrato 30). **Seguem sem escrita**: `enderecoEntrega` (`parceiros_endereco_entrega`) e `dadosBancarios` (`parceiros_dados_bancarios`) — as tabelas existem, mas o `mapRow` não grava nelas. Nomes exatos de coluna conforme a ficha de auditoria; o nome da coluna `optante_simples_nacional` segue o roteiro (a ficha cita "Simples") `[inferido]`.

## Tags de parceiro (`core.tipos_parceiro` + `core.parceiros_tipos`)

As tags do cliente no Omie (`parceiros.tags[]`) viram automaticamente:
- **`core.tipos_parceiro`** — catálogo de tags únicas (`tipo` = nome da tag).
- **`core.parceiros_tipos`** — tabela de ligação parceiro↔tag, uma linha por tag do cliente.

Isso é o que a seção de modelagem se refere como `tipo_parceiro` "já sincronizado do Omie pelo pipeline ELT".

## Fornecedor

Não existe tabela separada — fornecedor reaproveita `core.parceiros` (mesma extração acima), decisão já confirmada na seção de modelagem ("fornecedor não tem cadastro próprio no Estoque").

## Ver também
- [[Colunas-Protegidas]]
- [[Perguntas-em-Aberto]]
