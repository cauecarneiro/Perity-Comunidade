# Design do Perity — "Tinta e Marca-texto"

Este arquivo é a fonte da verdade do visual e da organização das telas: o que vale, por quê e como manter.
Leia antes de mexer na interface.

## A ideia

Quem abre o app quer três respostas em cinco segundos: **quanto eu tenho, quanto eu devo, o que falta pagar.**
O visual vem do mundo dessas respostas: o extrato impresso (tinta preta, números alinhados, etiquetas em letra
de máquina) e o marca-texto que a gente passa no que já pagou.

- **Tinta:** fundo preto, texto branco em três intensidades, etiquetas em caixa-alta na fonte de máquina
  (monoespaçada), números grandes com dígitos de largura fixa.
- **Marca-texto:** uma única cor, o limão `#D2FD59`. Ela só aparece onde algo foi feito ou merece ação: pago,
  rendeu, progresso, botão principal, aba atual, "ao vivo".
- **Assinatura:** o ponto de limão. Está no nome ("perity●"), no ícone ("p●"), nos tracinhos de "12 de 15
  pagos", na caixinha de pago e no ponto final dos gráficos.

## Princípios

1. **Macro primeiro, micro a um toque.** O Início tem quatro números. Cada um abre o seu detalhe.
2. **Um foco por tela.** O número principal é grande; o resto desce de tamanho e de brilho.
3. **Sem caixas.** Texto direto no preto, separado por espaço e por um fio (`Fio`). Superfície
   (`.cartaoPrumo()`) só em folhas e listas do sistema.
4. **Uma cor.** Limão é escasso de propósito. Âmbar e coral só quando significam atenção ou perda.
5. **Texto antes de ícone.** Ícone só em controle (barra, abas, setinha, caixinha).
6. **Movimento rápido e sempre presente.** Toda tela entra com movimento curto, sem quique e sem espera; o
   resto responde a gestos. A exceção com um toque de mola é a caixinha de pago (e o ponto da abertura).

## Fichas (tokens) — `Tema.swift`

| Item | Valor |
|---|---|
| `acento` (limão) | `#D2FD59`; texto em cima dele: preto (`sobreAcento`) |
| `fundo` | preto `#000000` |
| `superficie` / `elevada` | `#0F0F10` / `#1C1C1E` |
| `texto` / `secundario` / `terciario` | `#F4F4F1` / branco 56% / branco 34% |
| `linha` / `trilho` | branco 10% / branco 9% |
| `vermelho` / `ambar` | `#FF6B5E` / `#FFB84D` |
| Raios | cartão 20 · bloco 14 · chip 10 (sempre `.continuous`) |
| Movimento | `suave` `.smooth(0.3)` · `rapida` `.snappy(0.18)` · `entrada(i)` mola 0,38 s, +22 ms por bloco · `aparecer(i)` opacidade 0,14 s · `contagem` 0,5 s · `desenho` 0,55 s · `marca` mola leve (caixinha) |
| Número | `Font.numero(tamanho)`: fonte do sistema, dígitos fixos, espaçamento apertado nos grandes |
| Etiqueta | `.rotulo()`: 11 pt, monoespaçada, caixa-alta, espaçada, cinza |

O app é **sempre escuro** (`.preferredColorScheme(.dark)` na raiz). Não existe versão clara.

## Peças (App/Shared)

- `Visual.swift`: `NumeroHeroi`, `Fio`, `EstiloToque`, `EstiloPrincipal`/`EstiloSecundario`, `Seletor`,
  `Caixinha`, `BarraSegmentos`, `.origemZoom()`/`.destinoZoom()`.
- `Componentes.swift`: `Valor`, `TextoPrivado`, `Selo`, `BarraProgresso`, `CabecalhoSecao`, `RotuloLink`,
  `Seta`, `LinhaLancamento`, `LinhaValor`, `EstadoVazio`, `IndicadorAtualizacao`.
- `Graficos.swift`: `LinhaEvolucao`, `RitmoDoMes`, `BarrasMensais`, `LegendaDupla`, `LinhaProporcao`,
  `ListaCategorias`.
- `Dados.swift`: os números do app (`BaseDoMes`, `Agenda`, `PainelInicio`, `PainelInvestimentos`), os três
  provedores e `ComPainel`/`ComInvestimentos`. `Entrada.swift`: a entrada das telas. `Abertura.swift`: a
  abertura animada.
- `InicioView.swift`: os blocos do macro (`BlocoSaldo`, `BlocoFaturas`, `BlocoGastos`, `BlocoFixos`,
  `BlocoAviso`), as seções do micro e as telas de detalhe.
- `InvestimentosView.swift` e `FixosView.swift`: mesma divisão (dados, seções, tela do iPhone).
- `App/macOS/PainelMac.swift` (moldura, barra lateral, peças de página e de tabela) e `PaginasMac.swift` (as
  sete páginas).

## iPhone: um número por vez

Três abas: **Início · Investimentos · Fixos**.

- **Início:** saldo em conta (o maior) → faturas dos cartões → gastos do mês (com a previsão) → fixos (falta
  pagar, tracinhos) → vence em breve → últimos lançamentos → um aviso (por último). Tocar no saldo abre
  **Contas**; nas faturas, **Cartões**; nos gastos, **Gastos do mês** (categorias ou áreas, destaques, ritmo,
  entrou e saiu, conferir categorias); em "Ver todos", **Lançamentos**. No iOS 18+ o bloco cresce e vira a tela.
- **Investimentos:** total com a linha da evolução → quanto rende por mês e em 12 meses (reais, %, % do CDI,
  barras carteira × CDI) → fechamento do mês passado (valeu a pena / abaixo do CDI / perdeu valor) → como está
  distribuído → vencimentos → itens por classe.
- **Fixos:** mês (‹ ›) → falta pagar → "A pagar" e "Pagos", cada linha com de onde sai e quando. A caixinha
  marca; o resto da linha abre o detalhe (neste mês, ver no extrato, histórico, edição). A varredura cria
  sozinha o que se repete no extrato.
- **Barra:** olho (ocultar valores **desta página**) e ajustes, só o ícone fino em cinza, sem a cápsula de
  vidro do iOS 26 (`semCapsula()`). Para atualizar, puxar o Início.

## Mac: um caderno de páginas (estilo Notion)

- **Barra lateral** (232 pt): marca, páginas agrupadas (Visão geral · Dinheiro: Contas, Cartões · Mês: Gastos
  do mês, Lançamentos, Fixos · Patrimônio: Investimentos) e, no pé, Atualizar bancos, Ocultar valores e
  Ajustes. Atalhos ⌘1 a ⌘7.
- **Página:** coluna centralizada (até 1080 pt), título grande, propriedades (rótulo cinza e valor) e blocos:
  fileira de números em colunas (`MetricaMac`), chamadas com fundo (`ChamadaMac`) e seções que recolhem
  (`SecaoMac`).
- **Bases (tabelas):** cabeçalho com ícone do tipo de cada coluna, linhas finas com realce ao passar o ponteiro,
  etiquetas (`EtiquetaMac`), "+ Novo" no fim e rodapé "CONTAGEM · SOMA". Visões em abas sublinhadas
  (`VisoesBase`). Abrir um item abre uma folha por cima (`FolhaMac`).
- **Lançamentos:** filtros em pílulas (período, categoria por área, entre contas) e busca; clicar em uma
  categoria em qualquer página abre esta página já filtrada (`estado.abrirLancamentos`).

## Animações

| Onde | O que acontece |
|---|---|
| Abertura (só ao abrir o app) | "p" aparece, o ponto de limão cai com mola, "erity" se abre entre os dois. Feita em Core Animation para não travar enquanto o app carrega os dados |
| Entrada de toda tela (aba ou detalhe) | Blocos sobem 12 pt e aparecem (o primeiro na hora, os outros 22 ms depois um do outro); voltar de um detalhe não repete |
| Números grandes | Contam do zero até o valor (dígitos rolando) |
| Barras e tracinhos | Enchem do zero; os tracinhos de "pagos" acendem um depois do outro |
| Gráficos | Se desenham da esquerda para a direita (linhas) ou de baixo para cima (barras) |
| Caixinha de pago | Enche de limão com um toque de mola, vibra de leve, e a linha desce para "Pagos" |
| Gráfico de investimentos | Ao passar o dedo, o número grande e a data acompanham o dia tocado |
| Seletor e visões | O destaque (ou o sublinhado, no Mac) desliza até a opção escolhida |
| Linhas e botões | Apagam um pouco enquanto pressionados |
| Olho (ocultar valores) | O ícone troca com transição |

Tudo respeita **Reduzir Movimento**.

## Ícone e nome

- Nome: **Perity**. Marca escrita em minúsculas com o ponto de limão: `perity●` (`Marca`).
- Ícone: "p" branco e ponto de limão sobre preto, desenhado por `Prumo/Scripts/gerar-icone.swift`
  (`swift Scripts/gerar-icone.swift <pasta>`). Para mudar, mude o roteiro e copie os PNG para
  `App/Shared/Assets.xcassets/AppIcon.appiconset`.
- O nome exibido vem de `CFBundleDisplayName`/`CFBundleName` no `project.yml`. Identificadores, pastas e
  esquemas continuam "Prumo" (nome antigo do projeto): não renomeie, para não quebrar Keychain e dados.

## Regras para manter

- Nada de `Material`, `LinearGradient`, `MeshGradient` nem `shadow`.
- Limão só em: pago, rendeu, progresso, ação principal, seleção, "ao vivo". Ícone de barra é cinza fino.
- Número em reais sempre por `Valor` / `NumeroHeroi` / `TextoPrivado` (leem `\.valoresOcultos`, que é por
  página; folha fora de uma aba precisa injetar o da página que a abriu).
- Antes de pôr algo no Início, perguntar: é macro? Se não for, vai para o detalhe.
- Seção nova entra como peça reutilizável (iPhone e Mac montam as mesmas peças de jeitos diferentes).
- Animação nova: entrada de tela (via `entrada(i)` / `entradaDeTela`) ou resposta a gesto; nada em loop e nada
  que faça esperar. Passa por `Movimento` e respeita Reduzir Movimento.
- Tela nova não faz `@Query` + análise por conta própria: lê de `Dados.swift`.
- Nenhuma mudança de visual altera o modelo de dados (CloudKit só cresce).

## Verificação

- **iPhone:** simulador, com `-prumo-demo YES -prumo-secao inicio|investimentos|fixos`. Argumentos só de
  desenvolvimento (DEBUG): `-prumo-destino contas|cartoes|analise|lancamentos|avisos`, `-prumo-rolar 0.5`,
  `-prumo-abertura fica|NO`, `-prumo-passeio YES`, `-prumo-ocultar YES`, `-prumo-medir YES`.
- **Mac:** o modo de captura (`-prumo-captura <pasta>`) grava em memória e não toca no Keychain nem nos
  widgets. Mesmo assim, **não rode a captura no app com os seus dados reais**: use uma cópia com outro
  identificador e dados de exemplo.
- Limitação: a foto do Mac (`cacheDisplay`) não inclui a barra do topo da janela. A transição de crescer, a
  mola da caixinha e a vibração só se veem no aparelho.
