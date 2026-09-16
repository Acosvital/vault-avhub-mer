---
tags: [visao-setores, decisoes-projeto]
criado: 2026-09-16
---

# Onde os Sistemas Rodam

## Resumo

Os sistemas da Aços Vital (av-hub, o sistema de produção, e os demais) rodam em **servidores próprios da empresa**, não em serviços de terceiros na nuvem. A única exceção é o sistema fiscal e financeiro (Omie), que é um serviço externo contratado — como já é hoje.

## O que isso significa na prática

- **A empresa não depende de um provedor externo para os sistemas funcionarem no dia a dia.** Se um serviço de nuvem de terceiro tiver problema, os sistemas internos continuam de pé, porque rodam em máquinas da própria Aços Vital.
- **Os dados ficam guardados em servidores próprios**, com uma rotina de backup automático já configurada — qualquer informação nova (de qualquer sistema, incluindo os que ainda vão ser criados) já é coberta por esse backup, sem precisar de configuração extra.
- **Existe um espaço próprio para armazenamento de arquivos** (laudos e certificados de qualidade, imagens, documentos anexados) dentro dessa mesma estrutura própria — também sem depender de serviço externo.
- **O login corporativo (mesmo usuário e senha do e-mail da empresa)** é compartilhado entre os sistemas que atendem o público de escritório. A exceção é o sistema de chão de fábrica, cujo público não tem e-mail corporativo — para esse público, o login é feito só por usuário e senha próprios do sistema.

## Por que essa decisão importa para o negócio

- **Menos risco de dependência externa**: a operação da empresa não trava se um fornecedor de nuvem tiver instabilidade.
- **Reaproveitamento de estrutura já existente**: os novos sistemas do ERP (como o sistema de Estoque) não vão precisar de uma estrutura de servidores nova — vão usar a mesma que já roda o av-hub e os outros sistemas internos hoje.
- **O único ponto de dependência externa que permanece é o sistema fiscal** (Omie), porque ele é quem emite nota fiscal e cuida da parte financeira/fiscal obrigatória — isso não muda com o ERP novo.

## Ver também
- [[Home]]
- [[Sistema-de-Fabrica-MES]]
- [[av-hub]]
- [[Integracao-com-o-Omie]]
- [[Principais-Decisoes]]
