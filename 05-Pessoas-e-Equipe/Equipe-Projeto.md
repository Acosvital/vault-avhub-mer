---
tags: [erp-acos-vital, equipe]
criado: 2026-09-16
atualizado: 2026-10-07
---

# Equipe do Projeto

> Status: decidido | no código | em produção (verificado em 07/10 pelo dump)

> **(atualizado em 07/10)** **Nomes e atribuições após as decisões de 07/10** ([[Registro-de-Decisoes-2026-10-07]], itens 32, 33 e 37). Nomes completos pelo `git log`; **o cargo formal de RH não consta no vault**.
>
> - **Robert Wilson** — **MES inteiro** (`api-pcp`, `app-pcp`), incluindo a carga inicial em lote (G1), a baixa no despacho do Estoque, a D11 (leitor 2D e posto de recebimento) e I1/J2/J5. A capacidade dele estoura e precisa ser recalculada (ver [[Cronograma-2-Meses]]).
> - **Pablo Cruz** — **Comercial & Suprimentos** (`api-comercial`, módulo no av-hub; ver [[AV-Hub-Comercial-Suprimentos]]). Deixa o MES.
> - **Gustavo M. de Farias** — banco, API e pipeline: envio de OC fixo no código, `PERMISSOES_ROTA_MODO` fixo em `exigir`, contrato 004-API, chave do MES (L6), prazo de retenção do `auth.logs` e a correção do `exclusionSync` para pedidos manuais.
> - **Nathan** — coordenação e av-hub (sem mudança).


- **Nathan** — Coordenador de TI da Aços Vital e arquiteto do ERP (confirmado com o usuário, 17/09/2026: é a mesma pessoa antes registrada neste vault como "Arquiteto Vital" — os dois registros foram consolidados num só). Gerencia o setor de tecnologia (desenvolvimento, infraestrutura, dados), atua full stack no [[AV-Hub-Visao-Geral|av-hub]], dono deste vault e das decisões de arquitetura do ERP. Também traduz decisões técnicas para a diretoria em termos de custo, risco e retorno; autor da maior parte dos contratos e changelogs documentados no repositório do Hub.
- **Gustavo** — colega, banco de dados/API dos dois lados (av-hub e MES). Time de desenvolvimento do [[PRD-Estoque-Visao-Geral|projeto de Estoque]].
- **Robert** — colega, fullstack sênior. Constrói o [[App-PCP-Visao-Geral|app-pcp]] (sistema de flanges/MES), ainda em construção. Também no time do projeto de Estoque.
- **Pablo** — colega, fullstack. ~~Também no time do MES/Estoque, ao lado do Robert~~ (histórico até 06/10; desde 07/10 atua no Comercial & Suprimentos, e o MES fica com o Robert). **(Atualização de 07/10/2026, pelo histórico do git do av-hub:)** os commits do módulo Comercial & Suprimentos e do serviço `api-comercial` (06 e 07/10) são do Pablo Cruz — ver [[AV-Hub-Comercial-Suprimentos]]. O Recebimento do MES (PR #50/#34, 07/10) é do Robert.

## Ver também
- [[Estoque-Roadmap]]
- [[AV-Hub-Visao-Geral]]
- [[App-PCP-Visao-Geral]]
