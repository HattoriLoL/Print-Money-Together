# Máquinas e objetos carregáveis

A linha de produção planejada é: papel → tinta → impressora → varal → guilhotina → máquina de
lavar → contadora → esconderijo. Até agora funcionam o **papel**, a **impressora** e a
**guilhotina**. As outras máquinas ainda são só o modelo.

## Objetos carregáveis

`scripts/items/`. Cada jogador segura um objeto por vez. [E] pega e [G] solta (o objeto sai na
frente do jogador, ou rente à parede se ela estiver no caminho).

| Tipo | O que é |
|---|---|
| `ream` | Resma de papel embrulhada (marca fictícia OFFICE+). Na impressora, vira `sheets_per_ream` folhas. |
| `sheet` | Folha A4 impressa com 2 x 3 notas, frente e verso. `data.wet` = tinta ainda fresca: mais escura e brilhando. |
| `bills` | Montinho de notas cortadas. `data.count` = quantas, `data.smudged` = quantas saíram borradas, `data.top_smudged` = se a de cima está borrada (muda a textura). A altura e o peso crescem com o monte. |

### Na mão

- O item fica no ponto `Hold`, na frente da câmera (`player.HOLD_REST`), com a pose de `ItemKinds.hold_offset`. A folha fica inclinada para quem segura ver as notas; a resma, um pouco virada para mostrar a tampa.
- Ao pegar, o item **voa até a mão**. Ao virar a câmera, ele vem **um pouco atrás**. Perto da parede, o ponto `Hold` **recua** para o item não atravessar.
- Com algo na mão aparecem as **luvas amarelas de borracha** (`assets/models/hands.glb`), segurando o item:
  - A folha fica presa entre o polegar e o indicador, nos cantos de perto; a resma, apertada pelos lados (`ItemKinds.hand_offset`).
  - A manga do moletom tem a cor da vaga do jogador.
  - Os outros jogadores também veem as luvas.
- A folha usa o shader `shaders/paper.gdshader`:
  - Na mão, a borda de longe cai um pouco e a folha tremula mais quanto mais rápido quem segura anda.
  - Apoiada, as pontas levantam de leve.
  - A fibra do papel aparece na luz.

### Soltar e arremessar

- **Tocar [G]** solta o item na frente, na pose em que estava na mão. **Segurar [G]** carrega a força (uma barrinha aparece embaixo da mira, até 0,8 s); soltar a tecla arremessa a 2,5–7,5 m/s, um pouco para cima, girando mais quanto mais forte.
- **A resma** pesa 2,5 kg: cai rápido, quica pouco (bounce 0,12) e tem atrito alto. Um arremesso forte leva uns 4 m.
- **A folha** pesa 5 g e sente o ar (`item.gd`, `_paper_air`):
  - Arrasto forte contra a face e fraco pela borda: deitada ela cai a ~1 m/s, e inclinada ela plana para o lado.
  - Um torque vira a face contra o vento, passa do ponto e volta. Ela desce balançando como folha de árvore e pousa deitada.
  - Arremessada, ela perde força no ar e não passa de ~1 m.
- **Esbarrões:** os itens soltos batem nos jogadores. Uma resma arremessada acerta quem estiver no caminho, e andando dá para chutar folhas e empurrar resmas. Quem soltou fica 0,5 s sem esbarrar no próprio item.
- **Fora do mapa:** um item que cair para fora (pela janela, por exemplo) volta para o meio da kitnet.
- **Na rede:** tudo isso é simulado no host. Os outros recebem a posição 20 vezes por segundo e seguem suavizando.
- Os números ficam em `ItemKinds` (`MASS`, `PHYSICS`, `PAPER_*`) e em `player.gd` (`THROW_*`).

### De onde vêm

- **As texturas do papel**: o `art_source/paper_textures.py` desenha a nota (frente com a capivara, verso com o prédio da kitnet, e a frente borrada de quem cortou molhada), a folha A4 (6 notas, marcas de corte e barra de cores), a fibra do papel, a embalagem da resma e o tapete quadriculado da guilhotina. Ele roda com o Python do sistema e o Pillow, não no Blender. As decorações do mapa (varal, guilhotina) usam a mesma folha.

  ```
  python art_source/paper_textures.py
  ```

- **As luvas**: o `art_source/blender/hands.py` monta e exporta, com a origem no pulso. Os dedos apontam para -Z e a palma para baixo.

  ```
  blender --background --python art_source/blender/hands.py -- --export
  ```

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

## Guilhotina (`MACHINE_Guillotine`)

Guilhotina de alavanca em cima da mesa do meio: tampo com tapete de corte quadriculado (régua,
contornos do A4 e do A5 e a linha da lâmina), esquadro à esquerda, prensa do papel, protetor de
acrílico e a alavanca com a lâmina e o pegador vermelho. O modelo fica em
`art_source/blender/machines.py` (`guillotine`), com as medidas que o Godot também usa.

O código é `scripts/machines/guillotine.gd`. Os números ficam em
`data/machines/guillotine_manual.tres` (`guillotine_stats.gd`).

| Na mão | [E] |
|---|---|
| Folha impressa | Põe a folha encostada no esquadro, com a primeira linha de notas passando da lâmina. Se ainda estiver molhada, o aviso diz que vai borrar. |
| Nada | A alavanca desce (0,16 s) e volta (0,4 s). Com folha, corta uma linha: as 2 notas caem no montinho na frente da guilhotina e o resto da folha anda até a lâmina. São 3 cortes por folha. |
| Outra coisa | Não entra. |

- O montinho é um item `bills`: os cortes seguintes somam no mesmo enquanto ele estiver parado lá (até `pile_max` notas). Se alguém pegou, ou se ele encheu, nasce outro do lado.
- Folha cortada molhada dá notas borradas (`smudged`). Por enquanto elas só ficam marcadas; depois vão valer menos ou ser recusadas.
- `noise()` é o golpe da lâmina, por um instante.
- Ainda não tem: som, nem cortar várias folhas de uma vez (upgrade).

Peça do modelo que o Godot mexe: `MACHINE_Guillotine_Arm`, com a origem no pivô; a ponta sobe
girando no Z do Godot (Y local no Blender).

## Teste

`tools/tests/test_kitnet.gd` faz o caminho inteiro:

1. Pega uma resma e carrega a impressora.
2. Liga no botão, espera esquentar e imprimir quase 3 folhas, e desliga.
3. Confere que saíram 2 folhas molhadas, gastando papel e toner, e que desligada ela não imprime mais.
4. Pega uma folha da bandeja e solta no chão.
5. Confere o `PAPER OUT` sem papel.
6. Põe uma folha molhada na guilhotina, corta as 3 linhas (6 notas borradas no montinho), corta uma linha de uma folha seca (soma no mesmo montinho sem borrar), confere que a resma não entra e pega o montinho.
