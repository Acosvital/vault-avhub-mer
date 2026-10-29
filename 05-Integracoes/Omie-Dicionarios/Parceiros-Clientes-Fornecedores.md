---
tags: [omie, dicionario, pipeline, parceiros, fornecedores]
criado: 2026-10-14
atualizado: 2026-10-29
status: vigente
dono: Gustavo (DBA)
fontes: [v1 08-Integracao-Omie/01-Dados-Extraidos/Parceiros-Clientes-Fornecedores, omie-elt-pipeline 0f739f0 (66f9a2e)]
---

# Dicionário Omie: Parceiros (clientes e fornecedores)

**Em uma frase:** tabela de clientes e fornecedores (o Omie os chama de parceiros), com a origem de cada coluna.

**Quando consultar esta nota:** ao procurar de onde vem um dado de cadastro (endereço, dados fiscais, tags) ou ao confirmar que fornecedor e cliente ficam na mesma tabela.

Fonte: Omie `ListarClientes` (`/geral/clientes/`), resource `parceiros.ts`. Destino: `core.parceiros`. Chave de conflito (identifica a linha e evita duplicar): `(codigo_empresa, codigo_parceiro_omie)`. Códigos HTML nos textos (como `&amp;`) são convertidos em texto normal (`decodificarEntidadesHtml`). `codigo_empresa` aceita N filiais.

## Colunas básicas

| Coluna | Campo ou origem Omie |
|---|---|
| `codigo_parceiro_omie` | `cliente.codigo_cliente_omie` |
| `nome_fantasia`, `razao_social` | `cliente.nome_fantasia`, `cliente.razao_social` |
| `cpf_cnpj` | `cliente.cnpj_cpf` |
| `observacao`, `email`, `homepage` | campos de mesmo nome |
| `telefone` | `telefone1_ddd` + `telefone1_numero`, formato `(ddd)numero`, até 20 caracteres |
| `celular` | `telefone2_ddd` + `telefone2_numero` |
| `logradouro`, `numero`, `complemento` | `endereco`, `endereco_numero`, `complemento` |
| `bairro`, `cidade`, `estado`, `cep` | campos de mesmo nome |
| `codigo_empresa` | filial |
| `latitude_y`, `longitude_x` | **não vêm do Omie**: coluna protegida, preenchida por `geocodeParceiros.ts` (Nominatim, diário) ([[Colunas-Protegidas]]) |
| `id`, `id_origem`, `created_at/by`, `updated_at/by`, `deleted_at/by` | controle do banco (identificador, autoria e datas de criação, alteração e exclusão) |

## Dados fiscais (gravados desde 66f9a2e)

Mesmo `ListarClientes`, sem chamada nova.

| Coluna | Campo Omie |
|---|---|
| `inscricao_estadual`, `inscricao_municipal`, `inscricao_suframa` | mesmo nome |
| `optante_simples_nacional` | `optante_simples_nacional` (S/N para bool) |
| `contribuinte_icms` | `contribuinte` (S/N para bool) |
| `cnae`, `tipo_atividade` | mesmo nome (CNAE é o código da atividade econômica) |
| `pessoa_fisica`, `produtor_rural` | S/N para bool |
| `cidade_ibge` | `cidade_ibge` (código IBGE do município) |
| `valor_limite_credito`, `bloquear_faturamento` | mesmo nome |
| `inativo` | `inativo` (S/N para bool) |

A IE alimenta o PDF da OC ([[LOG-30-Compras-Pedido-Omie-PDF-Completo]]). Seguem **sem escrita** `enderecoEntrega` (`parceiros_endereco_entrega`) e `dadosBancarios` (`parceiros_dados_bancarios`): as tabelas existem e estão vazias; ficam fora do escopo 📝 ([[Registro-de-Decisoes]] #30).

## Tags de parceiro

`parceiros.tags[]` do Omie vira `core.tipos_parceiro` (catálogo de tags únicas) e `core.parceiros_tipos` (ligação parceiro e tag).

## Fornecedor

Não existe tabela própria: fornecedor é `core.parceiros`. O MES não tem cadastro de fornecedor; o dado comercial fica no av-hub e só o necessário viaja ao MES ([[Integracao-AvHub-MES]], INT-04).

Ver também: [[Colunas-Protegidas]], [[Omie-Integracao-Estado]].
