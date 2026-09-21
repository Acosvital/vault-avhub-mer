---
tags: [integracao-omie, dados-extraidos]
criado: 2026-09-17
---

# Parceiros (Clientes/Fornecedores)

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
| codigo_empresa | filial (`mogi`/`uberaba`) |
| **latitude_y, longitude_x** | **não vêm do Omie** — coluna protegida, preenchida por job de geocodificação à parte (`geocodeParceiros.ts`, Nominatim). Ver [[Colunas-Protegidas]]. |
| id, id_origem, created_at/by, updated_at/by, deleted_at/by | gerenciadas pelo banco |

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
