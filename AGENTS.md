# Perity (código: Prumo) — regras para agentes e colaboradores

App de controle financeiro pessoal (SwiftUI, iPhone e Mac, SwiftData + CloudKit opcional, dados via Meu Pluggy).
O app se chama **Perity**; no código o nome antigo fica (`Prumo/`, `PrumoCore`, esquemas `Prumo`/`PrumoMac`).
**Não renomeie identificadores `Prumo*`.** Leia `README.md`, `docs/ARQUITETURA.md` e `CONTRIBUTING.md` antes de mexer.

## Idioma
- Português do Brasil, simples, sem jargão (textos do app, docs, commits). Domínio em português (`Lancamento`, `Conta`).

## Segurança (não negociável)
- **Nunca** imprimir, logar nem commitar `clientSecret`, `itemId` reais, tokens, `Configuracao.local`, `.p8`/`.p12`/`.env`.
- Segredo só no Keychain (`Cofre`), nunca em `UserDefaults`, arquivo ou iCloud.
- A integração com a Pluggy é **somente leitura**. Sem iniciação de pagamento nem escrita nos bancos.
- Sem engenharia reversa de apps de banco.
- Nenhum dado real em código, testes, fixtures, docs ou issues: só dados fictícios.
- Identificadores do usuário (prefixo de app, equipe, container, grupo) vêm de `Prumo/Configuracao.local` via `project.yml`
  e `Identidade.swift`. Não escreva valores pessoais em código ou docs.

## Dinheiro e dados
- Valores em **centavos (`Int`)**, com sinal (negativo = saiu). Nunca `Double` para guardar.
- "Interno" (transferência própria, pagamento de fatura, aporte) não é gasto nem renda.
- Data de lançamento = dia civil ao meio-dia local (`Datas.diaCivil`).
- CloudKit: propriedades com valor padrão ou opcionais; sem `@Attribute(.unique)`; sem relacionamentos; o modelo só cresce.
- O `ModelContainer` precisa ficar vivo. `#Predicate` não aceita propriedade de struct capturada: copie para uma `let`.

## Interface
- Leia `docs/DESIGN.md`. Sempre escuro, uma cor de destaque. Números por `Valor`/`NumeroHeroi`, etiquetas por `.rotulo()`,
  movimento por `Movimento`. Números calculados só em `Dados.swift`; telas não fazem `@Query` + análise.
- Respeitar Reduzir Movimento. Nunca alterar o modelo de dados por causa de visual.

## Build e testes
- Núcleo: `cd Prumo/PrumoCore && swift test` (deve ficar 100% verde).
- App: `Prumo/Scripts/configurar.sh` e depois `Prumo/Scripts/gerar-projeto.sh`; nunca versionar `.xcodeproj`.
- Checagem rápida de tipos: `swiftc -typecheck` contra o módulo `PrumoCore` compilado.

## Git
- Não commitar `.claude/`, `.agents/`, `skills-lock.json`, `Configuracao.local` nem arquivos gerados (`Info.plist`, `.entitlements`).
