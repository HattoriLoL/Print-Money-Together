# Máquinas e objetos carregáveis

A linha de produção planejada é: papel → tinta → impressora → varal → guilhotina → máquina de
lavar → contadora → esconderijo. Até agora funcionam o **papel** e a **impressora**. As outras
máquinas ainda são só o modelo.

## Objetos carregáveis

`scripts/items/`. Cada jogador segura um objeto por vez, no ponto `Hold` na frente da câmera.
[E] pega e [G] solta (o objeto sai na frente do jogador, ou rente à parede se ela estiver no
caminho).

| Tipo | O que é |
|---|---|
| `ream` | Resma de papel. Na impressora, vira `sheets_per_ream` folhas. |
| `sheet` | Folha A4 impressa com 2 x 3 notas (`assets/textures/bill.png`, gerada pelo build do Blender). `data.wet` = ainda molhada da impressora. |

Na rede, o host manda em tudo:

- Ele cria os itens (`items.spawn`, `items.give`), entrega, solta e consome.
- Ele simula a física dos itens soltos e manda a posição para os outros, 20 vezes por segundo, enquanto o item se mexe.
- Os outros só pedem (`request_pickup`, `request_drop`) e seguem o resultado.
- Um item na mão de alguém segue o `Hold` desse jogador em todas as máquinas, sem física.
- Um item `resting` fica congelado onde a máquina o pôs (por exemplo, a bandeja da impressora) até alguém pegar.
- Quem entra depois recebe todos os itens. Quem sai solta o que segurava.

Camadas de colisão:

1. Mundo.
2. Jogadores.
3. Itens: batem no mundo e entre si; os jogadores passam por eles.
4. Zonas de interação.

A mira acerta mundo, itens e zonas.

## Zonas de interação

`scripts/interact_zone.gd`: uma caixa invisível um pouco maior que a peça, para ser achada antes
da colisão do modelo. A máquina preenche `prompt_fn` (o texto na tela) e `press_fn` ([E]
apertado, roda no host). Nas zonas de segurar (`is_hold`), o host lê `holders` a cada quadro. O
jogador avisa ao começar e ao parar de segurar, e o host confere a distância.

## Resmas (`SUPPLY_Paper`)

`scripts/machines/paper_supply.gd`. De mão vazia, [E] pega uma resma. São 12 por noite
(`START_STOCK`); depois isso vai vir do catálogo do fornecedor.

## Impressora (`MACHINE_Printer`)

Uma impressora de escritório bege dos anos 90, amarelada pelo sol, em cima da escrivaninha
embaixo da janela (`furniture.printer_desk`, com gaveteiro e o gabinete de PC bege embaixo). O
modelo fica em `art_source/blender/machines.py`. O plástico usa uma textura gerada no script:
granulado de molde, amarelado irregular e riscos.

O código é `scripts/machines/printer.gd`. Os números ficam em `data/machines/printer_office.tres`
(`printer_stats.gd`), e um nível de upgrade é outro `.tres` com os mesmos campos.

| Onde | O quê |
|---|---|
| Botão de liga/desliga (em cima, à direita) | [E] liga ou desliga. Ligada, esquenta 3 s e depois imprime sozinha: uma folha A4 molhada a cada 5 s. |
| Alimentador de trás | [E] com uma resma na mão carrega 5 folhas (cabem 15). |
| Bandeja de saída (frente) | As folhas saem deslizando pela fenda e ficam empilhadas aqui (cabem 8). Cada folha gasta 2% de toner. |
| Visor | Apagado quando desligada. Senão mostra `WARMING UP`, `PRINTING n%`, `READY`, `PAPER OUT`, `TRAY FULL` ou `TONER EMPTY`. |
| LEDs | Verde: ligada (pisca enquanto esquenta ou imprime). Âmbar: parada por falta de papel, de toner ou de espaço na bandeja. |

Desligar no meio de uma folha devolve o papel dela para o alimentador.

`noise()` devolve o barulho: forte imprimindo, um zumbido baixo ligada à toa. `power_watts` é
o consumo de energia, para o disjuntor usar depois.

Ainda não tem: recarga de toner (o cartucho começa cheio e dá 50 folhas) e som.

Peças do modelo que o Godot mexe, filhas de `MACHINE_Printer`:

- `MACHINE_Printer_Button`: o botão, que afunda quando alguém aperta.
- `MACHINE_Printer_LedReady` e `MACHINE_Printer_LedAttention`: os LEDs, que acendem e apagam.
- `MACHINE_Printer_Paper`: a pilha de papel no alimentador, que some quando o papel acaba.

As folhas são A4 com 2 x 3 notas (`ItemKinds`). Na mão, a folha fica inclinada para quem segura
ver as notas.

## Teste

`tools/tests/test_kitnet.gd` faz o caminho inteiro:

1. Pega uma resma e carrega a impressora.
2. Liga no botão, espera esquentar e imprimir quase 3 folhas, e desliga.
3. Confere que saíram 2 folhas molhadas, gastando papel e toner, e que desligada ela não imprime mais.
4. Pega uma folha da bandeja e solta no chão.
5. Confere o `PAPER OUT` sem papel.
