# A API da Pluggy no Perity

Este arquivo resume o que o app **usa** da Pluggy e como conferir se continua funcionando. A fonte da verdade é
sempre a documentação oficial: https://docs.pluggy.ai (índice para máquinas: https://docs.pluggy.ai/llms.txt;
especificação: https://docs.pluggy.ai/openapi/pluggy-api.json). Termos, limites e planos podem mudar sem aviso.

> O Perity é um projeto pessoal e não oficial. Não tem relação com a Pluggy.

## O que o app chama (somente leitura)

Tudo passa por `PluggyClient` (`Prumo/PrumoCore/Sources/PrumoCore/Pluggy/`), em `https://api.pluggy.ai`:

| Chamada | Para quê |
|---|---|
| `POST /auth` (Client ID + Secret) | obter a chave de API temporária (válida por cerca de 2 h; o app renova sozinho) |
| `GET /items/{id}` | status da conexão, última atualização, vencimento do consentimento |
| `GET /accounts?itemId=…` | contas e cartões, saldos, limite, fechamento e vencimento |
| `GET /v2/transactions?accountId=…` | lançamentos (paginação por cursor; há fallback para o endpoint legado) |
| `GET /bills?accountId=…` | faturas dos cartões |
| `GET /investments?itemId=…` | posições de investimento |
| `GET /loans?itemId=…` | empréstimos |

O app **não** cria, altera nem apaga nada nos bancos, e não usa iniciação de pagamento. As requisições levam a
chave no cabeçalho `X-API-KEY`.

## Limites que importam para uso pessoal

Os limites, o plano e os termos são da Pluggy e **podem mudar sem aviso**; confira no site e na documentação deles
(guia "Meu Pluggy para uso pessoal"). O que valia na última conferência (outubro de 2026):

- O conector **MeuPluggy** é para pessoa física ver os **próprios** dados: **uso pessoal, sem uso comercial**, e com
  limite de conexões (até 5 na última conferência, **sujeito a mudança**).
- **Cada pessoa usa a sua conta própria no Meu Pluggy e a sua aplicação própria no Dashboard da Pluggy.** Nunca
  compartilhe Client ID, Client Secret ou itemId com outras pessoas, nem use os de outra pessoa.
- A atualização automática acontece em ciclos (cerca de uma vez por dia na última conferência) e **não pode ser
  forçada** nesse modo. O app mostra "dados de ontem" quando é só o ciclo.
- **A autorização do MeuPluggy vence** (cerca de 1 ano na última conferência). Quando vence, as leituras podem voltar
  vazias. Para renovar, **reconecte/renove no Dashboard da Pluggy ou no Meu Pluggy** (a atualização automática e a API não renovam), e confira o ID do item: ele pode mudar depois de renovar, e então é preciso cadastrar o novo em
  Ajustes → Conectar bancos.
- Webhooks exigem um servidor: o Perity **não** usa.
- Se você quiser distribuir o app a terceiros, **este projeto não serve como está**: a Pluggy tem planos e termos
  próprios para produtos, e o Client Secret não pode ficar dentro de um app distribuído.

## Como saber se ainda está funcionando

1. **Testes do núcleo** (sem rede e sem credenciais): `cd Prumo/PrumoCore && swift test`. Eles usam respostas de
   exemplo no formato da Pluggy (`Tests/PrumoCoreTests/Fixtures`) e cobrem autenticação, paginação, renovação de
   chave, erro 429 e mapeamento. Se a Pluggy mudar um campo, são estes testes e o mapeador que precisam mudar.
2. **No app:** Ajustes → Conectar bancos → *Testar e atualizar agora*. O resumo mostra erros por conexão. Erro 401/403 costuma ser
   chave errada ou conector MeuPluggy desativado; "precisa de atenção" é o banco pedindo reconexão.
3. **Acompanhar mudanças:** leia de vez em quando o changelog e o `llms.txt` da documentação, e compare o
   `openapi/pluggy-api.json` com os modelos em `PluggyDTOs.swift`. Campos novos são ignorados pelo decodificador;
   campo removido ou com tipo diferente pode aparecer como erro de leitura.
4. **Ao abrir uma issue** sobre a API, descreva o sintoma e o endpoint. **Nunca** cole resposta real da API: ela tem
   dados financeiros seus.

## Cuidados com credenciais

- Client Secret só no Keychain, digitado no app (`Cofre`). Nunca em arquivo, variável de ambiente do projeto,
  `UserDefaults` ou iCloud.
- Em logs e mensagens, o app mascara o segredo (`PluggyCredenciais.description`, coberto por teste).
- Vazou? Gere outra aplicação/chave no dashboard da Pluggy e apague a antiga.
