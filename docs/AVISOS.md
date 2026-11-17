# Avisos, privacidade e LGPD

Leia antes de usar ou de contribuir. Isto **não é aconselhamento jurídico**.

## O que este projeto é (e não é)

- É um **projeto pessoal de código aberto**, para quem programa e quer um controle financeiro só seu. Você compila, usa
  as suas credenciais e conecta as suas contas.
- **Não é** um serviço, um produto pronto para o público, uma instituição financeira, nem uma consultoria. Não há
  suporte garantido, contrato nem SLA.
- É **não oficial**: não tem afiliação, patrocínio ou endosso da **Pluggy**, de bancos, corretoras ou da **Apple**.
  "Pluggy", "Meu Pluggy", "Apple", "iCloud", "Apple Pay" e nomes de bancos são marcas dos respectivos donos e aparecem
  só para descrever a compatibilidade.

## Isenção financeira

Os números, categorias, previsões, comparações com o CDI e avisos do app são **estimativas automáticas**, que podem
estar errados ou desatualizados (conciliação, categorização e taxas de investimento têm limites explicados em
`docs/ARQUITETURA.md`). **Não são recomendação de investimento, de crédito ou de qualquer decisão financeira.**
Confira sempre no app ou extrato oficial do seu banco antes de decidir algo. O software é fornecido "como está", sem
garantia de qualquer tipo (veja a [licença](../LICENSE)).

## Seus dados e a LGPD

- Quem **usa** o app compila e roda por conta própria, com os próprios dados: na prática, você é o titular e quem decide
  sobre os seus dados (LGPD, Lei 13.709/2018). Os mantenedores deste repositório **não recebem, não armazenam e não têm
  acesso** a nenhum dado financeiro de ninguém: não existe servidor do projeto, analytics nem coleta.
- Os dados ficam no banco local do aparelho (SwiftData) e, **se você ligar o iCloud**, no seu iCloud privado (CloudKit),
  sob os termos da Apple. As credenciais da Pluggy ficam só no Keychain do aparelho.
- O app consulta dois serviços de terceiros: a **Pluggy** (para ler os seus bancos, com a sua autorização via Open
  Finance; veja a política de privacidade e os termos dela) e o **Banco Central** (série pública do CDI, sem enviar
  dado seu).
- Se você **distribuir** este app a outras pessoas (loja, TestFlight, pacote), você passa a ser responsável por
  privacidade, LGPD, termos, contrato com a agregadora e regras da Apple. **Este projeto não foi feito para isso** e
  não resolve essas obrigações (por exemplo: o Client Secret não pode ir dentro de um app distribuído).
- O app abre sem senha própria; proteja o aparelho com bloqueio de tela e, no Mac, FileVault.

## Componentes de terceiros

O projeto **não inclui bibliotecas de terceiros** (o `Package.swift` não tem dependências). Usa só o SDK da Apple (SwiftUI,
SwiftData, WidgetKit, Swift Charts, App Intents), SF Symbols e as fontes do sistema, sob os termos da Apple. O
[XcodeGen](https://github.com/yonaskolb/XcodeGen) é uma ferramenta que você instala à parte e não faz parte do repositório.
Os dados de exemplo (bancos "Azul" e "Laranja", valores, CPF `123.456.789-09`, "TITULAR TESTE") são **fictícios**; os
códigos de ativos da bolsa citados nos exemplos são públicos e os valores são inventados.

## Para contribuir sem expor ninguém

- Nunca publique dados reais (extratos, saldos, nomes, CPF, `itemId`, chaves, prints do app com os seus valores).
- Para exemplos e testes, use sempre dados fictícios. Veja [CONTRIBUTING.md](../CONTRIBUTING.md) e
  [SECURITY.md](../SECURITY.md).
