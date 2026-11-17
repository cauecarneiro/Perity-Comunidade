# Arquitetura do Perity (código: Prumo)

## Visão geral

```
                    ┌──────────────────────── iPhone ────────────────────────┐
  Apple Pay ───────▶│ Atalhos (automação "Transação")                        │
  (toque)           │      │  chama a ação "Registrar compra" (App Intent)   │
                    │      ▼                                                 │
                    │  Prumo (SwiftUI) ── SwiftData ──┐                      │
                    └─────────────────────────────────┼──────────────────────┘
                                                      │  iCloud (CloudKit, privado)
                    ┌──────────────────────── Mac ────┼──────────────────────┐
                    │  Prumo (SwiftUI + barra de menus)│                      │
                    │      │           SwiftData ◀─────┘                      │
                    │      ▼                                                  │
                    │  MotorDeSincronizacao ──▶ PluggyClient ──▶ api.pluggy.ai│
                    └─────────────────────────────────────────────────────────┘
                                                      ▲
                                  Open Finance (Meu Pluggy, em ciclos)
```

Não há servidor do Prumo. O único serviço de terceiros na rede é a Pluggy (que lê os bancos com a sua autorização) e o iCloud (sincronização entre seus aparelhos).

## Camadas

| Camada | Onde | Responsabilidade |
|---|---|---|
| **PrumoCore** (pacote Swift) | `Prumo/PrumoCore` | Modelos, cliente Pluggy, mapeamento, categorização, conciliação, análises, importador, dados de exemplo. Sem UI. Testável com `swift test`, sem simulador. |
| **App compartilhado** | `Prumo/App/Shared` | Telas SwiftUI, estado global, App Intents. |
| **Mac** | `Prumo/App/macOS` | Ícone na barra de menus; captura de telas de desenvolvimento. |
| **Projeto** | `Prumo/project.yml` | XcodeGen. O `.xcodeproj` nunca é versionado. |

## Dados (SwiftData, compatível com CloudKit)

Regras que o CloudKit impõe e o código respeita: toda propriedade tem valor padrão ou é opcional; sem `@Attribute(.unique)`; sem relacionamentos (as ligações são por texto: `contaID`, `itemID`).

| Modelo | O que guarda |
|---|---|
| `Conexao` | Uma conexão com um banco (item da Pluggy): status, última e próxima atualização, vencimento do consentimento. |
| `Conta` | Conta corrente, poupança, cartão, dinheiro. Cartão: limite, disponível, fechamento, vencimento. |
| `Lancamento` | Cada movimentação, com **valor assinado em centavos** (negativo = saiu), categoria, origem, status, parcela, `interno`, `conciliadoComID`. |
| `Fatura` | Faturas de cartão: total, mínimo, pago. |
| `Investimento` | Posição: classe, saldo, aplicado, resultado, vencimento, taxa. Pode ser manual. |
| `Emprestimo` | Saldo devedor, parcela, parcelas restantes. |
| `Orcamento`, `Meta`, `Regra`, `MapaCartao` | Suas configurações. |
| `FotoPatrimonio` | Uma foto por dia, para o gráfico de evolução. |

Dinheiro é sempre `Int` em centavos. Nunca `Double`.

## Regras de negócio que importam

1. **O que é gasto e o que é renda.** Transferência entre contas suas, pagamento de fatura e aportes/resgates são `interno` e ficam fora de gasto e renda. Sem isso o gasto apareceria em dobro (compra no cartão + pagamento da fatura).
2. **Cartão.** Entrada de dinheiro no cartão é pagamento de fatura (interno) ou estorno (reduz o gasto da categoria).
3. **Dia do lançamento.** A Pluggy manda meia-noite UTC. Em fuso −03:00 isso viraria o dia anterior; o app guarda o dia civil (meio-dia local).
4. **Conciliação.** Lançamento do Apple Pay ou manual casa com o do banco por mesmo valor, ±5 dias, mesma conta e semelhança de texto. Cada lançamento do banco é usado uma vez. A categoria que você corrigiu passa para o oficial.
5. **Categorização.** Ordem: regra sua → dicionário por peso (o banco desempata) → categoria do banco → "Outros". Corrigir uma categoria cria uma regra e reaplica nos parecidos. Detalhes no item 25.
6. **Sincronização repetida não duplica.** `externalID` único por conta; janela de 30 dias de sobreposição; pendentes que sumiram do banco são removidos.
7. **Dois aparelhos.** Só um (`dispositivoBuscaBancos`) consulta a Pluggy. `Higiene.deduplicar` limpa duplicatas caso o iCloud entregue duas cópias.
8. **Pagamento de fatura só some do gasto quando o cartão está no app.** O débito "Pagamento da fatura" na conta é pareado com o "pagamento recebido" do cartão (mesmo valor, ±3 dias, `Conciliador.parearFaturas`). Sem o cartão no app, o dinheiro realmente saiu e conta como gasto, em vez de sumir sem explicação. Conta de consumo (por exemplo, a fatura da operadora de celular) nunca é tratada como fatura de cartão.
9. **Transferência entre contas suas.** Reconhecida pelo documento do titular (inclusive mascarado) ou pelo nome, e também por par (saída numa conta, entrada igual na outra, até 2 dias). O que você marcou à mão como "interno" nunca é desfeito pela sincronização.
10. **Sincronização parcial não destrói nada.** Se o banco ainda está atualizando (`UPDATING` ou execução parcial), o app não apaga pendentes, não desativa investimentos e não grava a foto diária do patrimônio, que mostraria um valor menor que o real. A janela da busca parte do lançamento passado mais recente, nunca de uma parcela futura.
11. **Moeda estrangeira.** Vale o valor cobrado na moeda da conta (`amountInAccountCurrency`); o valor em dólar fica só na nota.
12. **Gasto do mês é "até hoje".** Parcelas e compromissos futuros do mês entram na **previsão**, não no gasto já feito. A previsão usa a fração histórica do gasto que costuma estar feita a cada dia do mês, nunca fica abaixo do que já está comprometido e não projeta aluguel no começo do mês como se fosse ritmo.
13. **Devolução abate a categoria da compra.** Estorno na conta corrente não é renda: reduz o gasto da categoria original.
14. **Conciliação mais estrita.** Sem conta definida, o texto precisa ter palavra em comum, para um Pix de R$ 50 não casar com um toque de R$ 50; o banco não lança antes do toque (tolerância de 1 dia); compra parcelada casa com a parcela; lançamentos de extrato importado também são "oficiais".
15. **Regra aprendida.** Só vira regra um texto específico (nunca "Pix enviado" ou "Compra no débito"), e casa por palavra inteira: "bar" não pega "barbearia". O padrão da regra é a **chave de loja** (`Texto.estabelecimento`, item 25); a regra casa pelo texto **ou** pela chave igual, porque a chave pode ter perdido um número do meio ("Barbearia 123 Centro" → "barbearia centro"). Na edição, "Lembrar" vem ligado e mostra quantos lançamentos parecidos vão junto.
16. **Taxas dos investimentos.** A Pluggy manda `annualRate`, `lastMonthRate` e `lastTwelveMonthsRate` em **percentual** (3,24 = 3,24%; é o único jeito de o exemplo da documentação fechar entre si). O mapeador divide por 100 e o modelo guarda **fração** (0,0324). A documentação não declara a unidade; conferir com a tela de cada instituição é o jeito de validar: o "Últimos 12 meses" do app deve bater com o que ela mostra. Se um dia aparecer 100 vezes maior ou menor, a escala está trocada em `Mapeador.investimento`.
17. **Quanto rende a carteira.** `Analise.rendimentoCarteira`: "últimos 30 dias" e "12 meses" são **estimativas** (`saldo − saldo/(1+taxa)`) com as taxas que cada instituição informa, ignorando taxas fora do plausível. Aportes e resgates distorcem. A tela mostra reais e percentual e avisa quantos investimentos entraram na conta. O "desde que aplicou" continua calculado, mas saiu da tela (confundia).
18. **Fixos (contas do mês com caixinha de pago).** Modelos `Fixo` e `MarcaFixo` (`ModelosFixos.swift`), regra em `Fixos.situacao`. Um fixo é pago quando o extrato do mês tem uma saída que casa com o "como aparece no extrato" (`padrao`, com alternativas por vírgula; vazio = o nome). Cada lançamento paga no máximo um fixo; dois fixos com o mesmo padrão ficam cada um com a cobrança de valor mais próximo. O valor mostrado é o do extrato; sem cobrança no mês, o da última cobrança (até 3 meses atrás); sem nada, o combinado. `MarcaFixo` guarda só o que foi feito à mão em um mês (pago, ou "não pago" para desfazer uma detecção errada); se a marcação fica igual ao que o extrato diz, ela é apagada. Fixo com `acumula` (mercado, gasolina) soma tudo que casa (ou a categoria inteira, sem padrão) e nunca se marca sozinho: mostra "gasto até agora" contra o combinado.
    **Complemento:** `Fixo` ganhou `contaID`, `diaTipico` e `automatico` (campos novos, opcionais/com padrão). `Fixos.situacao` recebe contas e faturas e devolve, por fixo, a conta de onde sai, o dia típico, a **previsão de débito** e o **histórico de 12 meses** (`CobrancaFixo`). Previsão: no cartão, a compra entra na fatura cuja janela (fechamento anterior, fechamento] a contém e é debitada no vencimento dela (`Faturas.dataDeDebito`; sem `Fatura` cobrindo, repete o ciclo da conta; dia 31 vira o último do mês); a pagar no cartão estima a compra no dia típico; débito/Pix/boleto usam o dia típico (mês seguinte se já passou). **Varredura automática** (`Fixos.varrer`): roda na manutenção pós-abertura e depois de sincronizar, sobre `Analise.recorrentes` de 13 meses; cria `Fixo(automatico: true)` para despesa que aparece em ≥3 meses dos últimos 5 com valor estável (±25%) ou de categoria sempre fixa (contas de casa, planos, mensalidades, assinaturas…), nunca recria o que casa com um fixo existente (ativo ou desativado), e preenche conta/dia dos fixos antigos que estavam vazios.
19. **Navegação: macro e micro.** O Início mostra quatro números (saldo em conta, faturas, gastos do mês, fixos a pagar); o detalhe de cada um é um `Destino` (`.contas`, `.cartoes`, `.analise`) ou a aba Fixos. Contas, cartões e lançamentos deixaram de ser áreas. `Secao` tem três casos: `inicio`, `investimentos`, `fixos`. No Mac, `PainelMac` mostra o macro e o micro lado a lado, em colunas, sem barra lateral. Orçamento por categoria e metas saíram das telas (os modelos `Orcamento` e `Meta` ficam, porque o banco só cresce) e os avisos de orçamento foram desligados. *(Atualizado no item 23: o Mac agora tem páginas.)*
20. **Categorias bem divididas.** `Categorias.todas` tem ~45 categorias (gasolina, carro, estacionamento e pedágio, Uber e táxi, delivery, padaria e café, mercado, aluguel, condomínio, luz, água e gás, internet, celular, farmácia, academia, plano de saúde, streaming, apps e IA, roupas, eletrônicos, bares…), agrupadas em **áreas** (`Categorias.areas`, campo `CategoriaInfo.area`). Nenhuma chave antiga foi removida: `transporte`, `contas`, `moradia`, `saude`, `restaurantes`, `assinaturas`, `compras` e `lazer` viraram o "resto" da sua área. A ordem em `Categorizador.palavras` importa (delivery antes de restaurante; Mercado Livre antes de mercado; IPVA e licenciamento vão para Carro). A categoria do banco casa trecho; começando com "=" casa só a palavra inteira ("=rent" não pega "current"). `Recategorizador.refinar` passa uma vez pelos lançamentos antigos (versão em `Preferencias.versaoCategorias`; subir `Recategorizador.versao` quando a lista mudar) e só troca a categoria ampla pela detalhada da mesma família, ou "Outros" por qualquer uma; nunca mexe em categoria escolhida à mão, regra sua ou "interno". *(Atualizado no item 25: 14 áreas, versão 3.)*
21. **Destaques do mês.** `Analise.destaquesDoMes`: frases com número (ritmo contra o mês passado até o mesmo dia, quanto cabe por dia para fechar na média, maior gasto do dia a dia, categorias acima do normal, abaixo do normal, onde mais voltou, compras pequenas, maior compra). "Normal" é a média dos últimos 3 meses **até o mesmo dia**; só conta categoria que apareceu em 2 dos 3 meses (abaixo do normal: nos 3), para compra esporádica não virar referência. `Analise.porArea` junta as categorias por área.
22. **CDI e fechamento dos investimentos.** `CDI` busca a série 4391 (CDI acumulado no mês) na API pública do Banco Central (`api.bcb.gov.br/dados/serie/bcdata.sgs.4391`); não envia nada do usuário, guarda em `UserDefaults` e só busca de novo depois de 12 h. Sem internet usa o guardado; na demonstração sem rede, `DadosDemo.cdiDeExemplo`. `Analise.fechamentoInvestimentos` fecha o último mês: carteira e cada investimento em reais, % e **% do CDI** (mês e 12 meses), com veredito *valeu a pena* (≥ CDI; isentos LCI/LCA/CRI/CRA a partir de 85% do CDI), *abaixo do CDI*, *perdeu valor* ou *sem dados*. É calculado na hora a partir das taxas que a instituição informa (não há histórico guardado); comparação bruta, antes do imposto. Na primeira semana do mês vira um aviso no Início.
23. **Números calculados uma vez, entrada animada e Mac em páginas.** `App/Shared/Dados.swift`: três provedores na raiz (`dadosDoPerity()`), cada um com as suas consultas — mês (lançamentos e contas), agenda (faturas, empréstimos, conexões, investimentos, CDI) e fixos. As telas só leem pelo ambiente (`ComPainel`, `ComInvestimentos`, `ComFixos`); trocar de aba ou abrir um detalhe não recalcula nada (conferido com `-prumo-passeio YES`, que troca de aba sozinho e grava a contagem em `Documents/passeio.txt`). A entrada das telas fica em `Entrada.swift` (`entradaDeTela`, `entrada(i)`, `desenhaAoEntrar`, `revelado` no ambiente) e a abertura em `Abertura.swift`. O Mac (`App/macOS/PainelMac.swift` e `PaginasMac.swift`) é organizado como o Notion: barra lateral com páginas (`Pagina`, ⌘1 a ⌘7) e bases em tabela.

24. **Desempenho da abertura.** Com uma base de alguns milhares de lançamentos (quem usa o app por anos chega nisso), a etapa do mês levava ~350 ms no Mac (mais no iPhone em modo de desenvolvimento) e rodava ~14 vezes nos primeiros segundos; a abertura animada pelo SwiftUI congelava junto. Corrigido em quatro frentes: (a) `LancamentoLeve` (cópia simples, com os textos normalizados dos últimos 8 meses prontos) e análises genéricas sobre `LancamentoAnalisavel`, porque ler propriedade do SwiftData é caro; (b) `Datas.calendario` criado uma vez (antes era montado a cada uso, milhares de vezes por conta); (c) `Memoria` nos provedores: o resultado só é refeito quando o SwiftData entrega uma lista nova (`marcaDaLista`) ou o dia vira; fixos usam o conteúdo como chave; (d) manutenção (higiene, conciliação, recategorização, widgets, CDI) e a primeira busca nos bancos esperam a abertura terminar. Resultado medido no Mac: etapa do mês ~60 ms, agenda ~3 ms, e 5 cálculos nos primeiros segundos (os que restam são o iCloud entregando dados). A abertura (`Abertura.swift`) é feita em Core Animation: as animações vão de uma vez para o sistema gráfico e não travam mesmo com o app ocupado (testado com `-prumo-travar 700`, que ocupa o app por 0,7 s logo no começo). Medição: `-prumo-medir YES` escreve os tempos no terminal.
    **Complemento:** ainda havia tranco na abertura. Três causas corrigidas: a agenda não tinha `Memoria` e recalculava a cada redesenho da raiz (inclusive no quadro em que a abertura termina); o conteúdo do app ficava na mesma subárvore que reage a `aberturaNaTela`/`scenePhase` (agora é `ConteudoPrumo`, fora dela); e a saída da abertura dependia de `asyncAfter` na thread principal (agora é o fim da própria animação, por `CAAnimationDelegate`). A conferência de categorias (item 25) só é calculada quando uma tela a lê, depois do primeiro quadro.

25. **Categorias em dois níveis e motor por peso.** São **14 áreas** (macro): casa, alimentação, carro, transporte, saúde, esportes, assinaturas, compras, lazer e viagem, educação, taxas/impostos/seguros, outros, receitas, movimentações; e ~56 categorias (micro). O lançamento guarda só a chave micro; a área é derivada (`Categorias.info(chave).area`). Novas: `lanches`, `lavagem`, `carro_taxas`, `lutas`, `esportes`, `equipamento_esportivo`, `jogos`, `faculdade`, `cursos`, `livros`; `academia` mudou para a área esportes; Uber e transporte público viraram a área transporte. Nenhuma chave foi removida.
    - **Chave de loja.** `Texto.estabelecimento(descricao, estabelecimento)` limpa prefixo de adquirente (`PAG*`, `MP *`, `IFD*`, `PAGSEGURO *`, `PAYPAL *`…), parcela (`03/12`), CPF/CNPJ mascarado, datas, números soltos, "BR", UF e cidade no fim, e devolve o texto limpo e a **chave** (trecho contíguo do 1º ao 2º termo específico). É o padrão das regras, a identidade dos recorrentes, dos fixos e da conferência.
    - **Dicionário por peso.** Cada termo tem peso (frase > palavra inteira > prefixo `*`; movimentação/receita pesam mais); a categoria com maior soma vence; empate → categoria do banco; senão a ordem da lista. **Compostos** resolvem ambiguidade: "mensalidade" só vira faculdade com "uni/fac", escola com "escola", lazer com "clube"; "multa" só é carro com "trânsito" e tarifa com "atraso". A categoria do banco mapeia a **árvore completa da Pluggy** (Automotive, Wellness and fitness, Education, Sports goods, Gaming…). `ResultadoCategoria.confianca` (0–100) existe só em memória, para ordenar a conferência.
    - **Auditoria do dicionário:** `max` → "hbo max"; `extra` → "extra hiper"; `super*` saiu; marcas esportivas → equipamento esportivo; Steam/PSN → jogos; fast food → lanches; IPVA/licenciamento → `carro_taxas`; lava-rápido → `lavagem`. O teste `DetalhamentoTests` garante que cada termo cai na própria categoria.
    - **Recategorizador v3:** famílias novas em `origens`; passo de recorrência (loja em "Outros", ≥3 meses, valor ±5% → assinaturas).
    - **Conferir categorias.** `Analise.conferenciaCategorias` agrupa 12 meses por chave de loja (`LojaConferida`: nome, categoria, vezes, total, confiança), com "Outros" e as dúvidas primeiro. A tela (Gastos do mês → fim; Ajustes; Mac na página Gastos do mês) corrige com um toque e cria a regra.

## Segurança e privacidade

- Client Secret da Pluggy: Keychain do aparelho, `WhenUnlockedThisDeviceOnly`, **não** sincroniza para o iCloud.
- O app abre direto, sem Face ID nem senha própria: quem protege o acesso é o bloqueio do aparelho (e o FileVault, no Mac). Ficam o modo "ocultar valores" e a tela borrada na lista de apps recentes do iPhone.
- `PluggyCredenciais` nunca imprime o segredo (`description` mascarado, testado).
- A API é usada **somente para leitura**. O app não cria nem altera nada nos bancos.
- Nenhum segredo no repositório (`.gitignore` cobre `Secrets.xcconfig`, `.env`, `.p8`, `.p12`).

## Testes

`cd Prumo/PrumoCore && swift test` — cobre dinheiro, datas (fuso), categorização, cliente Pluggy (autenticação, paginação por cursor, renovação de chave, 429, fallback v2→legado), mapeamento de sinais, sincronização ponta a ponta com JSON no formato da Pluggy (idempotência, edição preservada), conciliação, pareamento de fatura e de transferência própria, deduplicação, análises (previsão, devoluções, recorrentes), importador, Apple Pay, e os casos da revisão independente (sincronização parcial, moeda estrangeira, empréstimos, janela da busca).

## O que depende de você (não dá para testar sem os seus aparelhos e contas)

- Assinatura: abrir no Xcode com a sua equipe (veja `Scripts/configurar.sh`). O iCloud só funciona com conta de desenvolvedor paga; sem ele, os dados ficam só no aparelho.
- Credenciais da Pluggy e o `itemId` de cada banco.
- A automação "Transação" do Atalhos com os seus cartões.

Veja `COMO-CONECTAR.md`.
