# Segurança

## Como reportar uma falha

Use a aba **Security → Report a vulnerability** do repositório no GitHub (relato privado). Se ela não estiver
disponível, abra uma issue **sem detalhes que permitam explorar** a falha e peça um canal privado.

**Nunca** inclua no relato: Client ID/Secret, `itemId`, chaves, tokens, extratos, saldos ou prints com dados
reais. Descreva o problema com dados fictícios.

## O que consideramos falha

- Segredo (Client Secret, chave de API) sendo gravado fora do Keychain, impresso em log ou enviado a terceiros.
- O app enviando dados financeiros para qualquer endereço além de `api.pluggy.ai` (leitura dos seus dados) e
  `api.bcb.gov.br` (CDI público). (Com `PERITY_ICLOUD=true`, os dados também vão para o **seu** iCloud privado; isso é esperado.)
- Qualquer caminho de código que **escreva** nos bancos (o app é somente leitura).
- Identificador pessoal de uma pessoa (prefixo de app, equipe, itemId, e-mail) embutido no código ou em docs.

## Como o projeto se protege

- Client ID/Secret só no Keychain (`Cofre`), `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, não sincroniza com o
  iCloud. `PluggyCredenciais` mascara o segredo ao imprimir (coberto por teste).
- Seus identificadores ficam em `Prumo/Configuracao.local` (no `.gitignore`) e entram no app pelo `project.yml`.
- Arquivos gerados que carregam o seu prefixo/equipe (`Info.plist` e `.entitlements`) também estão no `.gitignore`.
- Sem analytics, sem anúncios, sem servidor do projeto.
- O ID das conexões (`itemId`) aparece mascarado em Ajustes; o completo só é copiado por ação explícita (menu da conexão), sem
  Área de Transferência Universal.
- O app e os atalhos: "Resumo do mês" exige o aparelho desbloqueado e respeita "ocultar valores". "Registrar compra" não exige
  (a automação do Apple Pay precisa rodar com o aparelho bloqueado), mas só grava e não lê nada.

## Limites conhecidos (ditos com franqueza)

Estes pontos **não** são falhas escondidas: são escolhas ou limites da plataforma. Se isso importa para você, não use o app ou
adapte o código.

- **Widget em texto claro:** o resumo que os widgets mostram (totais do mês, saldo líquido etc.) fica **sem criptografia própria**
  no `UserDefaults` do grupo do app. Quem tiver acesso ao aparelho desbloqueado, a um backup sem criptografia ou ao grupo do app
  pode ler esses totais. Mesmo com "ocultar valores" ligado, os números **continuam gravados**: o widget só os esconde na tela.
- **Banco local sem proteção extra:** o banco de dados (SwiftData) usa só a proteção de arquivo que o sistema já dá por padrão.
  O app não define uma classe de proteção de arquivo mais forte nem criptografa o banco por conta própria. Mantenha bloqueio de
  tela, FileVault (Mac) e backups criptografados.
- **Área de Transferência Universal ao colar o Client Secret:** se você copia o Client Secret (por exemplo, do Dashboard da
  Pluggy) em um aparelho com Handoff ligado, a Área de Transferência Universal pode levá-lo a outros aparelhos da sua conta Apple, e
  gerenciadores de área de transferência podem guardá-lo. **Depois de colar o segredo no app, limpe a área de transferência**
  (copie qualquer texto sem importância por cima) e, se puder, desligue o Handoff durante o cadastro. Prefira guardar o segredo em
  um gerenciador de senhas e colar de lá.
- **Sem senha própria:** o app abre direto (ver acima); o bloqueio do aparelho é a proteção.

## O que **você** precisa fazer

- Ao fazer fork ou commit, confira `git status` e `git diff --cached` e não adicione arquivos de configuração local,
  certificados (`.p8`, `.p12`, `.mobileprovision`), `.env` ou prints.
- Se um segredo vazar, gere outro no dashboard da Pluggy e apague o antigo (apagar do git **não** basta: o
  histórico guarda).
- Mantenha o bloqueio de tela do aparelho e o FileVault no Mac: o app abre sem senha própria.
- Antes de publicar um fork público, rode `Prumo/Scripts/verificar-vazamentos.sh` **e também** `gitleaks` e, se puder,
  `trufflehog` (inclusive no histórico: `gitleaks detect`). O script do projeto é só uma rede mínima.
