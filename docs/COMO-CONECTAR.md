# Como colocar o Perity para funcionar com os seus dados

> O app se chama Perity; nos comandos e no Xcode o nome antigo (`Prumo`, `PrumoMac`) continua.
> Tudo aqui é para **uso pessoal**, com as **suas** contas e as **suas** chaves. Os menus da Pluggy e da Apple mudam
> com o tempo: se um nome não bater, procure o equivalente e confira em https://docs.pluggy.ai.

Tempo estimado: 20 a 30 minutos, a maior parte aprovando acesso no app de cada banco.

## Regras de ouro (leia primeiro)

1. **Nunca** cole o Client ID, o Client Secret ou um `itemId` em arquivo do projeto, em issue, em commit, em
   print ou em conversa com IA. Eles são digitados **dentro do app**, que guarda no Keychain.
2. Se uma chave vazar (print, commit, chat), **gere outra** no dashboard da Pluggy e apague a antiga.
3. Não ative plano pago nem informe cartão de crédito na Pluggy para o uso pessoal descrito aqui.

## A. Abrir o app

1. No Terminal, dentro da pasta do projeto: `cd Prumo`.
2. `./Scripts/configurar.sh`: informe **o seu** prefixo (domínio ao contrário, ex.: `com.joaosilva`), a sua equipe
   de assinatura (pode deixar vazia e escolher no Xcode) e se quer iCloud (só com conta paga).
   Isso cria `Prumo/Configuracao.local`, que **não** vai para o git.
3. `./Scripts/gerar-projeto.sh` (precisa do XcodeGen: `brew install xcodegen`). Gera `Prumo.xcodeproj`.
4. Abra `Prumo.xcodeproj`. Em **Signing & Capabilities** de cada alvo (`Prumo` para iPhone, `PrumoMac` para Mac),
   confirme a sua equipe.
5. Se ligou o iCloud: confirme que **iCloud → CloudKit** está ativo e que o container é
   `iCloud.<seu-prefixo>.prumo` (o Xcode cria sozinho com assinatura automática).
6. Rode `PrumoMac` no Mac e `Prumo` no iPhone.

Na primeira abertura, escolha **Ver com dados de exemplo** para conhecer as telas (são dados fictícios). Para sair,
Ajustes → Exemplo.

## B. Conectar os bancos (Meu Pluggy)

O Perity usa o **Meu Pluggy**, o conector da Pluggy para pessoa física ver os próprios dados. Existe limite de
conexões e o uso é só pessoal; os limites e o plano dependem da Pluggy e podem mudar (veja [PLUGGY.md](PLUGGY.md)).

1. Crie a conta em https://meu.pluggy.ai e conecte cada banco/corretora. A autorização de cada banco é feita no fluxo do Meu Pluggy.
2. Em https://dashboard.pluggy.ai, entre com o mesmo e-mail e crie **uma** aplicação do tipo
   *Development Application*. A conta do dashboard pode começar com um período de teste de um plano comercial:
   **não ative plano nem informe cartão** sem entender o que está contratando; o conector MeuPluggy é o caminho pensado para os seus próprios dados (confira as condições atuais no site da Pluggy).
3. Na aplicação, ative o conector **MeuPluggy** (procure "Connectors" → conectores diretos/pessoais).
4. Em *Applications → sua aplicação → Demo (Connect Account)*, escolha **MeuPluggy** (não o banco) e autorize.
   Faça **uma vez por banco**. Cada banco vira um *item*.
5. Copie e guarde em um gerenciador de senhas (não em arquivo do projeto): o **Client ID**, o **Client Secret**
   (aparece uma vez só) e o **ID de cada item** (no Demo, menu de três pontos → *Copiar Item ID*, ou em *Connected
   Items*). Anote qual banco é cada item.
6. No Perity do **Mac**: Ajustes → Conectar bancos. Cole Client ID e Secret → *Salvar neste aparelho*. Cole cada ID
   de item → *Adicionar*. Ligue *Este aparelho busca os dados nos bancos* → *Testar e atualizar agora*.
7. Feche o navegador e apague de qualquer lugar temporário (área de transferência, notas) o que copiou.

Só um aparelho (o "aparelho que busca", em geral o Mac) precisa das credenciais. Com iCloud ligado, o iPhone recebe
tudo por ele. Sem iCloud, repita o processo em cada aparelho.

Se um banco ficar com bolinha vermelha, reconecte-o no Meu Pluggy. O Open Finance também pede renovar o
consentimento de tempos em tempos; o Perity avisa quando estiver perto. A renovação do MeuPluggy é feita no Meu Pluggy / Dashboard
da Pluggy (veja [PLUGGY.md](PLUGGY.md)), e o ID do item pode mudar depois dela.

## C. Apple Pay em tempo real (iPhone, opcional)

1. Atalhos → **Automação** → **+** → **Transação**.
2. Escolha os cartões e marque **Executar imediatamente**.
3. Ação: **Registrar compra** (do Perity). Preencha: *Valor* = Valor da Transação; *Estabelecimento* = Comerciante;
   *Cartão* = Cartão ou Cartão da Carteira.
4. Teste: Ajustes → Apple Pay → *Registrar compra de teste*, e pague algo pequeno com o cartão.

Se a automação não disparar com algum cartão, é limitação do emissor. O Open Finance cobre, no ritmo de atualização da Pluggy.

## D. Conferir os investimentos na primeira sincronização

Depois do primeiro "Testar e atualizar agora": abra **Investimentos** e compare com o app da sua corretora/banco.

- O **saldo** de cada investimento e o **total investido** devem bater.
- Em cada item, "Últimos 12 meses" e "No último mês" devem ser parecidos com o que o banco mostra. Se vier 100
  vezes maior ou menor, a unidade da taxa está trocada: veja o item 16 de [ARQUITETURA.md](ARQUITETURA.md) e abra
  uma issue **sem números seus** (descreva só "100 vezes maior").
- "Últimos 30 dias" e "Últimos 12 meses" do total são **estimativas** pelas taxas que cada instituição informa.

## E. Widgets

No iPhone: segure a tela inicial → **+** → Perity → escolha o tamanho. No Mac: botão direito na área de trabalho →
*Editar widgets* → Perity. Os widgets se atualizam sempre que o app recebe dados novos. Valores aparecem borrados na
tela de bloqueio do iPhone.

## F. Bancos fora das suas conexões

Ajustes → **Importar extrato** (OFX ou CSV). Cadastre antes a conta em *Início → Saldo em conta → +*.

## G. Ajustar a seu gosto

- **Fixos:** aba Fixos → **+** → *Novo gasto fixo* ou *Colar uma lista*. Em cada item, "Como aparece no extrato"
  é o que faz o app marcar como pago sozinho.
- **Categorias:** toque em um lançamento, escolha a categoria e deixe "Lembrar" ligado.
- **Transferência entre suas contas:** marque "Transferência entre minhas contas" no lançamento (o Perity já detecta
  Pix para o seu próprio CPF e pagamento de fatura).
- **Investimentos fora do Open Finance** (cripto, imóvel…): Investimentos → **+**.

## Problemas comuns

| Sintoma | O que fazer |
|---|---|
| `Scripts/gerar-projeto.sh` diz que falta a Configuracao.local | Rode `Scripts/configurar.sh` antes. |
| "Troque o prefixo de exemplo pelo seu" | Use um prefixo só seu, como `com.joaosilva` (não `com.exemplo` nem `com.seunome`). |
| Erro de assinatura mencionando iCloud | Você está com `PERITY_ICLOUD=true` sem conta paga. Edite `Configuracao.local` para `false` e rode `gerar-projeto.sh`. |
| "Falta o Client ID e o Secret" | Salve as credenciais *neste aparelho* (o que busca os dados). |
| Lista de contas vazia depois de atualizar | O item não foi vinculado à aplicação pelo conector MeuPluggy (passo B.4). |
| Erro 403 / "recusou o acesso" | O conector MeuPluggy não está ativo na aplicação. |
| Dados de ontem | Normal: a atualização acontece em ciclos definidos pela Pluggy. |
| Lançamento duplicado entre Apple Pay e banco | Aguarde a confirmação do banco; se persistir, o valor ou a data diferem demais. Exclua o "ao vivo". |
| O outro aparelho não mostra o que o primeiro buscou | Verifique iCloud ligado (com conta paga) e a mesma conta Apple nos dois. |
| O app no iPhone parou de abrir depois de alguns dias | Conta Apple gratuita: o app instalado expira em poucos dias; instale de novo pelo Xcode. |
