---
tags: [integracao-omie, levantamento-api, lacunas]
criado: 2026-09-17
---

# Cadastros Gerais — o que a API do Omie oferece e não extraímos

Levantamento feito direto na documentação interativa da API (`developer.omie.com.br/service-list/`, páginas em `app.omie.com.br/api/v1/...`), não só no código do pipeline. Objetivo: achar tudo que existe no Omie e que pode ser necessário migrar antes do desligamento, versus o que pode ficar de fora.

## Clientes/Fornecedores (`geral/clientes/`) — lacuna fiscal crítica

Já extraímos nome, razão social, CPF/CNPJ, contato, endereço básico. **Não extraímos** (e o Omie tem):

| Campo                                                                                       | Por que importa                                                                                                  |
| ------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| inscricao_estadual, inscricao_municipal, inscricao_suframa                                  | Dados fiscais — necessários para emitir NF-e/calcular impostos sem depender do Omie                              |
| optante_simples_nacional, contribuinte, cnae, tipo_atividade, produtor_rural, pessoa_fisica | Regime tributário do parceiro — afeta cálculo de imposto na venda                                                |
| cidade_ibge                                                                                 | Código oficial IBGE — obrigatório em NF-e, hoje só temos nome da cidade em texto                                 |
| valor_limite_credito, bloquear_faturamento                                                  | Regra de negócio de crédito, já existe pronta no Omie                                                            |
| enderecoEntrega                                                                             | Endereço de entrega **separado** do endereço fiscal (relevante — entrega em obra/canteiro é comum em siderurgia) |
| dadosBancarios                                                                              | Banco, agência, conta, chave PIX do parceiro                                                                     |
| inativo                                                                                     | Hoje não sincronizamos esse status                                                                               |
| nif, documento_exterior                                                                     | Só relevante para clientes/fornecedores estrangeiros                                                             |

**Recomendação**: esse é o gap mais crítico de todo o levantamento — no dia em que o sistema próprio precisar emitir nota fiscal sem o Omie, faltam os dados fiscais básicos do parceiro. Vale estender a extração de `core.parceiros` antes do desligamento, não depois.

## Clientes - Características (`geral/clientescaract/`)

Schema livre chave-valor (`campo` + `conteudo`), sem catálogo fixo. Não extraído. **Candidato a conter dado de negócio real** (ex: tipo de aço preferido, condição especial), mas só vale a pena nativizar depois de checar o que de fato está cadastrado hoje no Omie — se for pouco usado, baixo valor; se for usado como classificação real de cliente, vale estruturar como colunas próprias no cadastro de parceiros do Estoque, não como key-value solto.

## Empresas (`geral/empresas/`) — não é para migrar, é config fiscal do próprio Omie

Cadastro da própria Aços Vital no Omie: CNPJ, IE, regime tributário, mais dezenas de campos de certificado digital/SPED/eSocial. **Não extrair como massa de dado** — é configuração operacional do emissor fiscal. Só relevante no dia em que o sistema próprio assumir emissão fiscal (aí sim, um subconjunto pequeno: CNPJ, razão social, endereço, IE, regime tributário, CNAE).

## Departamentos / Categorias (plano de contas)

Configuração contábil-financeira (centro de custo, plano de contas/DRE). Baixa relevância para o Estoque/MES hoje. Só migrar se um módulo financeiro nativo vier a existir (ver [[Financas-Lacunas]]).

## Parcelas (condições de pagamento)

Catálogo pequeno e estruturado (`nCodigo`, `cDescricao`, `nParcelas` — ex "30/60/90"). Não extraído. Relevância média: se o Estoque/MES for gerar pedidos com parcelamento, é barato nativizar como tabela de referência.

## Documentos Anexos (`geral/anexo/`)

Repositório genérico de arquivo binário vinculado a qualquer cadastro do Omie (`cTabela`+`nId`). Não é dado estruturado de negócio. **Baixa prioridade** — só extrair pontualmente se precisar de um anexo específico como arquivo morto, não como sincronização recorrente.

## Contas Correntes — cadastro (`geral/contacorrente/`)

Cadastro bancário da própria empresa (contas, boletos, PDV). Configuração financeira/tesouraria. Só relevante se um módulo financeiro nativo vier a existir.

## Ver também
- [[Compras-Estoque-Producao-Lacunas]]
- [[Sintese-Migrar-vs-Nascer-Nativo]]
- [[Parceiros-Clientes-Fornecedores]] (extração atual)
