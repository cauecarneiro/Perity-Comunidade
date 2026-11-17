# Como contribuir

Obrigado! Este é um projeto pessoal de código aberto; contribuições pequenas e bem explicadas são bem-vindas.

## Regras que não mudam

1. **Nenhum dado real**, nunca: nem em código, testes, fixtures, docs, issues, PRs ou prints. Use dados fictícios
   (o CPF `123.456.789-09`, "Banco Teste", "TITULAR TESTE"…).
2. **Nenhum segredo**: Client ID/Secret, `itemId`, tokens, `.p8`/`.p12`, `Configuracao.local`. Eles não entram no git.
3. **Somente leitura**: não adicione iniciação de pagamento nem escrita nos bancos.
4. **Identificadores**: não escreva o seu prefixo de app, equipe ou container em código ou docs. Eles vêm de
   `Prumo/Configuracao.local` (via `project.yml`). Não renomeie os identificadores `Prumo*` (quebra Keychain e dados).
5. **Dinheiro em centavos (`Int`)**, com sinal (negativo = saiu). Nunca `Double` para guardar.
6. **Dados (CloudKit):** propriedades com valor padrão ou opcionais, sem `@Attribute(.unique)`, sem relacionamentos;
   o modelo só cresce (campo novo opcional; não renomear nem remover).

## Antes de abrir um PR

- `cd Prumo/PrumoCore && swift test` deve ficar 100% verde.
- Leia `docs/ARQUITETURA.md` (regras de negócio) e, se mexer na interface, `docs/DESIGN.md`.
- Números calculados ficam em `Prumo/App/Shared/Dados.swift`; telas não fazem `@Query` + análise por conta própria.
- Texto do app e docs em português do Brasil, simples e sem jargão.
- Rode `git status` e `git diff --cached` e confira que não há arquivo pessoal.
- Rode `Prumo/Scripts/verificar-vazamentos.sh`. **Ele é só uma rede mínima** (caminhos locais, e-mails, CPF, itemId, chaves comuns)
  e deixa passar muita coisa. Rode **também** `gitleaks` (`gitleaks detect --source . --no-banner`) e, se puder, `trufflehog`.
  Se o `gitleaks` estiver instalado, o próprio script o chama no fim.
- `.xcodeproj` nunca é versionado (gere com `Prumo/Scripts/gerar-projeto.sh`).

## Issues

Use os modelos em `.github/ISSUE_TEMPLATE`. Descreva o sintoma, os passos e a versão do Xcode/iOS/macOS.
**Não cole respostas reais da API nem prints com os seus valores.**

## Licença das contribuições

Ao contribuir, você concorda que sua contribuição é licenciada sob a [MIT](LICENSE) do projeto.
