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
| `finger` | Um dedo que a guilhotina levou: a peça da luva do `hands.glb`. `data.owner` = de quem ("Tester's thumb"), `data.side` = 0 direita / 1 esquerda, `data.digit` = qual. |
| `hand` | A mão inteira que a guilhotina levou: a luva com os dedos que ela ainda tinha. `data.owner`, `data.side` e `data.lost` = os dedos que já tinham ido antes. |

A resma precisa das duas mãos (`ItemKinds.TWO_HANDED`): quem perdeu uma não pega ("Needs both hands to carry"), nem do chão nem do estoque.

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
| Folha impressa | Põe a folha encostada no esquadro, com a borda da frente na lâmina, e começa a operar. Se ainda estiver molhada, o aviso diz que vai borrar. |
| Nada, com folha na mesa | Começa a operar. |
| Nada, sem folha | A alavanca desce (0,16 s) e volta (0,4 s), à toa. |
| Outra coisa | Não entra. |

### Operando

Quem opera fica parado na frente da mesa, e só um por vez. Os outros veem "Someone is holding the sheet (pull the red lever to cut for them)".

- **Câmera:** sai da primeira pessoa e vai para cima da mesa (`VIEW_FROM`, `VIEW_AT`, `VIEW_FOV`), quase de cima, para a alavanca e os braços não taparem a linha. É outra câmera (`player._station_cam`, com o contorno), que volta para a de primeira pessoa ao sair (`STATION_CAMERA_TIME`). Ela desliza de lado para acompanhar o que está na lâmina (a folha, ou a pilha de tiras).
- **Mãos:** as luvas do boneco ficam nos lados da folha (ou da pilha), na altura `hands_z`, com os dedos para dentro e o polegar para a lâmina (`hand_transform`), e o braço vai até elas pelo IK. Os outros jogadores também veem. Elas andam livres pela mesa (ver "Mãos perto da lâmina").
- **Alavanca:** fica quase em pé enquanto alguém opera (`OPERATE_ANGLE`), para não tapar a folha.
- **Mouse:** com as mãos em cima da folha, empurra a folha junto com elas. Puxando para baixo, ela vem para quem opera e passa da lâmina (`FEED_PER_PIXEL`); dá para puxar de volta até `FEED_BACK` atrás da lâmina. Com as mãos fora da folha, o mouse anda só com elas, e quando encostam na borda de trás começam a empurrar pela ponta.
- **Botão direito:** segurado, o mouse anda só com as mãos, para qualquer lugar da mesa (`HANDS_RANGE`), e a folha fica parada. Ela passa no máximo uma peça (linha ou coluna) com a margem e uma folga (`feed_max()`, com `FEED_SLACK`), então não dá para passar duas de uma vez. Uma linha-guia vermelha em cima da folha, como o laser das guilhotinas de verdade, mostra onde a lâmina corta.
- **Shift:** ajuste fino. Segurando, a folha anda `FEED_FINE` (um quarto) do normal, para acertar a marca.
- **Clique:** desce a alavanca. O corte acontece quando a lâmina chega embaixo (`swing_down`): a tira que passou da lâmina sai e a borda do que sobrou fica na lâmina. Do clique até a alavanca voltar, a folha fica parada em todas as máquinas, e clicar de novo não faz nada.
- **Golpe:** quando a lâmina bate, toca o som do golpe (`_chop`, feito no próprio código: estalo do papel, pancada na mesa e o metal tinindo) e a câmera dá um tranco (`player.kick_camera`), forte para quem opera e mais fraco para quem está a até `CHOP_KICK_REACH` m.
- **Outro jogador na alavanca:** o pegador vermelho tem uma zona própria (`Zone_Lever`, filha da alavanca, gira junto). Com alguém operando, outro jogador aperta [E] ali e a alavanca desce com o corte onde quem opera está segurando a folha. Os dois recebem o aviso de como saiu. Sem ninguém operando, o pegador só bate a alavanca. Quem opera sozinho continua cortando com o clique.
- **[E]:** sai, e a folha e a pilha de tiras ficam na mesa. Cair (trombada) também tira da guilhotina; se for no meio da descida, o corte não acontece. Quando a folha acaba, sai sozinho.

### Mãos perto da lâmina

As duas mãos ficam na mesma altura (`hands_z`, o pulso), livres pela mesa: não estão presas à folha. Ao pegar a folha (ou quando a pilha gira), elas começam `HANDS_REST` na frente da borda de trás. Depois de um corte, ficam onde estavam. Elas seguram a folha quando pelo menos `PAPER_TOUCH` da luva está por cima dela (`_on_paper`).

Com pouca folha atrás da lâmina (a última linha), empurrar com as mãos onde estão leva os dedos. O jeito é tirar as mãos da folha pelo botão direito, empurrar pela ponta de trás e, com a folha na marca, voltar as mãos para perto da lâmina sem mexer nela.

- **Firmeza:** quanto mais longe da lâmina, mais a folha treme. Com a frente da mão até `FIRM_GAP` (1,5 cm) atrás da linha, ela fica firme; a partir de `LOOSE_GAP` (12 cm), o golpe sai com um erro aleatório de até `SHAKE_MAX` (4 mm) para cada lado. Sem mão em cima da folha, ou só segurando a tira que sai (a mão toda na frente da lâmina), ela fica solta. Todo mundo vê a folha e as mãos tremendo (`_tremor`), e o tremor some no golpe.
- **Perigo:** o que passar da linha da lâmina no golpe vai embora (`_chopped`). A luva deitada de lado vai de `HAND_BACK` atrás a `HAND_FRONT` na frente do pulso, e cada dedo fica em `DIGIT_Z`. Com o polegar passando, vai ele; depois o indicador e o médio; passando o meio da mão, vai a mão inteira. Com a mão toda na frente da lâmina (segurando a tira), a lâmina desce atrás dela. As duas mãos perdem as mesmas partes. O golpe pega as mãos mesmo sem papel passando da lâmina (aí ele não corta a folha). A linha-guia pisca enquanto o golpe pegaria as mãos (`hands_in_danger`).
- **Quem puxa a alavanca** pelo pegador também corta os dedos de quem segura a folha.
- O que foi embora cai na mesa, na frente da lâmina, como item (`finger` ou `hand`), e quem opera vê "OUCH! You lost 2 fingers!" (ou "a hand", "both hands").
- **Sem dedos:** cada dedo a menos de quem opera faz a folha tremer mais `FINGER_SHAKE` (0,6 mm), mesmo segurando perto; sem uma mão, conta os 5. Fora da guilhotina, ver `docs/personagens.md`.
- Na pilha estreita, as luvas ficam pelo menos `HANDS_MIN_SPREAD` do meio, para não se encavalarem.
- Rede: quem opera manda `hands_z` junto com a posição da folha (`_remote_feed`) e com o clique (`_rpc_cut`). O host sorteia o tremor e decide o que o golpe leva (`player.injure`).

### Duas fases: linhas e colunas

A folha (2 x 3 notas) é cortada como numa gráfica. Uma folha pede **3 cortes**: 2 horizontais e 1 vertical.

1. **Linhas** (`Phase.ROWS`): os cortes horizontais soltam tiras, cada uma com uma linha de notas ainda grudadas lado a lado. Elas ainda não são notas: cada tira gira e pousa numa pilha na parte livre do tapete, à direita da folha (`STACK_X`), já virada para o corte vertical e `STACK_GAP` atrás da lâmina, para não ser cortada junto.
2. **Colunas** (`Phase.COLUMNS`): quando sai a última linha, a pilha anda até a lâmina (`PILE_SLIDE`). Um corte vertical separa as colunas de todas as tiras de uma vez, e só aí as notas vão para o montinho. A frente da pilha é a borda esquerda da folha.

As duas fases usam a mesma regra (`piece_edges`, `_out`, `_released`), só muda a direção:

- O corte certo é no meio do vão entre duas peças (3 mm; as marcas de corte na margem da folha mostram onde). Cada corte solta uma tira, da frente do que sobrou até a lâmina. Cada peça que veio na tira tem o erro somado das duas pontas dela: sobra de papel além do meio do vão, ou nota comida pelo corte. As margens da folha não contam: a frente da primeira peça e a trás da última podem sobrar.
- **A última peça sai sozinha:** o corte que deixa só ela na mesa solta também ela, numa segunda tira, porque atrás dela só tem a margem. Ela vale pelo erro da frente. Se na frente dela ainda estiver grudado um resto maior que `ruin_error` de uma peça estragada, ela espera: o corte de aparar no vão solta o retalho e ela juntos.
- Uma peça com erro maior que `ruin_error` estraga. Cortar fundo numa peça (mais de `ruin_error` de cada lado) também estraga ela, e o resto dela fica grudado na frente da próxima: para não estragar a próxima também, é preciso aparar no vão antes. Uma lasca da frente de uma peça (até `ruin_error`) fica como erro para quando ela sair.
- Errar para além da marca também atrapalha a peça de trás, que perde um pedaço da frente.
- Uma linha estragada não vai para a pilha. Uma coluna estragada perde a nota dela em todas as tiras da pilha.

Cada nota vale pelo **erro das quatro bordas**: o da linha dela mais o da coluna. Por isso o corte vertical decide a folha inteira: errar ali entorta (ou estraga) as notas de uma coluna em todas as tiras.

| Erro da nota | Resultado |
|---|---|
| Até `perfect_error` (2 mm) | Sai perfeita. |
| Até `ruin_error` (1 cm) | Sai torta (`crooked`) e vale menos: de `crooked_worth.x` (90%) a `crooked_worth.y` (30%) de uma perfeita, conforme o erro. A nota de cima do montinho mostra o pedaço da folha que ela é de verdade (`top_cut`). |
| Mais que isso | Estraga e não sai. |

- Com uma coluna só (`bills_per_row = 1`), não tem o que separar: quando sai a última linha, as tiras já viram as notas.
- As peças não guardam estado: com os cortes sempre andando para trás, `_out(peça, cut_pos)` diz se ela já saiu (ficou para trás no máximo `ruin_error` dela) ou estragou (o corte entrou mais que isso). Cada corte avalia só as peças que saem nele. Só as linhas da pilha ficam guardadas no host (`_rows`, com o erro de cada uma), para somar no corte vertical.
- Se duas peças viessem na mesma tira (o `feed_max()` não deixa), sairiam grudadas: a primeira leva a outra atrás, a segunda leva a primeira na frente, e as duas estragam.
- Cada corte avisa quem operou (e quem puxou a alavanca, se foi outro) como saiu. Nas linhas: "Clean cut!", "Crooked cut" ou "Ruined 1 row". No corte vertical, pelas notas: "Clean cut!", "Crooked cut: bills worth 79%" ou "Ruined 2 bills".

### O que aparece na mesa

- **A folha** é um retângulo só, do alto da textura até onde já foi cortada (`cut_pos`), que anda com o `feed`. Ela fica um pouco acima do tampo (`SHEET_Y`), por cima da contra-lâmina de aço, senão o aço tapa o vão bem na linha de corte.
- **A pilha de tiras** (`_stack`) mostra a tira de cima, girada. Na fase das colunas, ela é o que anda com o `feed`.
- **As tiras cortadas** (`_strips`, duas: a segunda é a última peça, que sai junto e vai `STRIP_NEXT` s depois) vão para a pilha (girando no caminho), para o montinho (`STRIP_TO_PILE`) ou, sem nota nenhuma, viram retalho: escorregam para a frente, ficam um pouco na mesa e somem (`SCRAP_*`). A pilha só mostra a tira nova quando ela pousa (`_landing`).
- Todos são o mesmo papel com um pedaço da textura da folha (`_pose_paper`). A versão toon do material guarda uma cópia da escala e do deslocamento da textura, então ela é sincronizada (`Toon.sync`) quando eles mudam.
- A alavanca é mexida por um tween só (`_tween`). A volta do golpe lê o ângulo de parada a cada quadro, então ela acerta mesmo se quem opera sair no meio (acabou a folha, caiu).

### Rede

O host guarda o estado (a fase, `cut_pos`, quantas peças faltam, a pilha e quem opera) e manda para todos. Quem opera mexe a folha na hora e manda a posição para os outros (`_remote_feed`); o clique trava a folha na hora e leva essa posição para o host, que desce a alavanca em todos (`_swing`, com a posição) e corta quando a lâmina chega embaixo. As tiras saem antes do estado novo (`_strip_fell`), para cada máquina saber de onde elas saíram. Durante o golpe, uma posição atrasada que chegue de antes do clique é ignorada. Quem opera e sai da sala solta a guilhotina.

### Montinho

- O montinho é um item `bills`: os cortes seguintes somam no mesmo enquanto ele estiver parado lá (até `pile_max` notas). Se alguém pegou, ou se ele encheu, nasce outro do lado.
- Folha cortada molhada dá notas borradas (`smudged`). Por enquanto elas só ficam marcadas; depois vão valer menos ou ser recusadas.
- `data.crooked` conta as tortas e `data.worth` guarda quanto o monte vale em notas perfeitas (ainda não tem economia; é para quando tiver). O nome mostra as duas marcas: "10 bills (6 smudged, 6 crooked)".
- `noise()` é o golpe da lâmina, por um instante.
- Ainda não tem: cortar várias folhas de uma vez (upgrade).

Peça do modelo que o Godot mexe: `MACHINE_Guillotine_Arm`, com a origem no pivô; a ponta sobe
girando no Z do Godot (Y local no Blender).

## Teste

`tools/tests/test_kitnet.gd` faz o caminho inteiro:

1. Pega uma resma e carrega a impressora.
2. Liga no botão, espera esquentar e imprimir quase 3 folhas, e desliga.
3. Confere que saíram 2 folhas molhadas, gastando papel e toner, e que desligada ela não imprime mais.
4. Pega uma folha da bandeja e solta no chão.
5. Confere o `PAPER OUT` sem papel.
6. Põe uma folha molhada na guilhotina e confere a câmera em cima da mesa, a linha-guia, as luvas na folha e o mouse deslizando a folha. Confere que a folha passa no máximo uma linha da lâmina e que o Shift anda um quarto. Corta na marca (conferindo que o corte espera a lâmina descer, que a folha fica parada durante o golpe, que a tira vai para a pilha e pousa lá, que a câmera dá um tranco, que o que sobrou da folha mostra só a parte certa da textura e que cortar só na horizontal não solta nota) e 5 mm fora dela: a última linha sai junto numa segunda tira, e a pilha de 3 tiras gira e vai para a lâmina, com as luvas segurando ela. O corte vertical 4 mm fora da marca solta as duas colunas: as 6 notas vão para o montinho, todas tortas e valendo menos, com a nota de cima mostrando o corte. Sai sozinho quando a folha acaba, com a alavanca voltando para o ângulo de parada. Depois uma folha seca: corta na marca (a tira vai para a pilha), corta no meio de uma linha (estraga, não vai para a pilha), sai com [E] deixando a folha e a pilha na mesa, volta, e outro jogador puxa a alavanca pelo pegador aparando no vão: sai o retalho da linha estragada e a última linha vai para a pilha. O corte vertical na marca solta 4 notas perfeitas, que somam no mesmo montinho sem borrar. Confere que a resma não entra e pega o montinho. Por fim, as mãos: pegando pela borda de trás a folha treme; o botão direito anda só com as mãos; com elas em cima o mouse empurra a folha; perto da lâmina ela fica firme e o corte sai sem susto. Na última linha, as mãos saem da folha, andam sozinhas, empurram pela ponta de trás até a marca sem perigo e voltam para perto da lâmina sem mexer nela. No corte vertical com o polegar e o indicador passando da linha, o golpe leva os dois das duas mãos (4 dedos caem na mesa como itens, a luva fica com o curativo); noutra folha, ela treme mesmo segurando perto, e o golpe sem papel passando leva as duas mãos sem cortar a folha. Sem as mãos a resma não vem e o que está na mão escorrega andando; depois as mãos voltam.
