# Personagens

Os jogadores são bonecos de desenho animado: adultos desengonçados e meio acabados, compridos e
curvados, de peito estreito e barriguinha de cerveja, braços e pernas finos e longos e tênis
grandes. A cara é de cansado: olhos pequenos de pálpebra caída e olheira, sobrancelhas finas
franzidas, nariz comprido caído, sorrisinho torto e barba por fazer no queixo. Usam moletom com
capuz (gola de ribana, capuz caído nas costas, bolso canguru), calça com a barra embolada em cima
do tênis (bico de borracha, cadarço, lingueta e listra vermelha) e luvas amarelas de borracha de
desenho, com três dedos e o polegar (na primeira pessoa aparecem as do `hands.glb`). As do
`hands.glb` vêm em peças (manga, luva, cada dedo e os curativos), para o boneco poder perder dedos
na guilhotina (ver "Mãos machucadas"). O contorno preto e o cel
shading vêm do visual do mapa (`docs/visual.md`).

Todos usam o mesmo boneco. A vaga muda a cor do moletom (`Net.PLAYER_COLORS`) e o acessório:

| Vaga | Moletom | Acessório |
|---|---|---|
| 1 | vermelho | boné virado para trás (`Acc_Cap`) |
| 2 | azul | óculos redondos de aro grosso (`Acc_Glasses`) |
| 3 | amarelo | topete (`Acc_Quiff`) |
| 4 | roxo | gorro com pompom (`Acc_Beanie`) |

## Modelo

`art_source/blender/character.py` monta o boneco e exporta `assets/models/character.glb` (e salva
`art_source/character.blend`). Não edite o `.blend` na mão.

```
blender --background --python art_source/blender/character.py -- --export
```

- **Corpo (`Char_Body`)**: uma malha só, com esqueleto. É feito de metaballs que se fundem: o
  tronco (quadril, barriga, peito e ombros, em `TORSO`) e cada braço e perna (cápsulas entre as
  juntas e bolas no ombro, cotovelo, quadril e joelho). Não tem emenda: ombro, cotovelo, quadril
  e joelho dobram como pano. A roupa sai do pedaço e da altura (calça, moletom, barra de ribana
  em `HEM`, punho), e os pesos da distância até os ossos.
- **Peças rígidas presas nos ossos**: a cabeça (`Char_Head`, com o rosto e os quatro `Acc_*`), as
  luvas (`Char_Glove_L/R`), os tênis com a barra da calça (`Char_Shoe_L/R`), os punhos das
  mangas (`Char_Cuff_L/R`), o capuz caído nas costas com a gola e os cordões (`Char_Hood`), o
  bolso canguru (`Char_Pocket`) e os bolsos de trás (`Char_BackPockets`).

Ossos: `Hips > Spine > Chest > Neck > Head`, `Chest > UpperArm.L/R > Forearm.L/R > Hand.L/R` e
`Hips > Thigh.L/R > Shin.L/R > Foot.L/R`. As juntas ficam em `SHOULDER`, `ELBOW`, `WRIST`,
`HIP_JOINT`, `KNEE` e `ANKLE` (só o lado esquerdo; o direito é o espelho).

L é o lado esquerdo do boneco. No Blender a frente é -Y; o `character_rig.gd` gira o modelo para
a frente do jogador (-Z no Godot). Os materiais `M_Hoodie` e `M_HoodieDark` são trocados no jogo
pela cor da vaga.

## Animação

`scripts/character_rig.gd` anima por código, girando os ossos em cima da pose de descanso, a
partir de quanto o boneco andou em cada quadro (serve para os bonecos dos outros, que só recebem
a posição):

- sempre um pouco curvado para frente (`SLOUCH`);
- andando: pernas e braços balançam (ao contrário), o joelho dobra quando a perna vem para
  frente, o cotovelo dobra quando o braço vai para frente, o corpo quica de leve, curva mais e
  rebola; os pés ficam sempre retos;
  andar para trás roda o passo ao contrário;
- parado: o peito respira (estica e encolhe de leve), com os cotovelos meio dobrados;
- no ar: joelhos encolhidos e braços para cima;
- a cabeça acompanha metade do olhar (para cima e para baixo);
- segurando um item: IK de dois ossos, o ombro e o cotovelo se ajustam para a mão chegar nas
  luvas do `hands.glb` que seguram o item (o cotovelo aponta para baixo, para fora e um pouco
  para trás), e as luvas do boneco somem. Longe demais, o braço estica reto na direção;
- agachado: o `player.gd` achata o boneco inteiro (`_body.scale.y`).

Em primeira pessoa, quem joga vê o próprio boneco: olhando para baixo aparecem a barriga, os
braços e as luvas, e segurando um item os braços vão até as luvas do `hands.glb`. Somem só a
cabeça (a câmera fica dentro dela), a gola com o capuz e o nome em cima, e o boneco não faz
sombra (com a lâmpada a meio metro da cabeça, a sombra cobria o cômodo). Quanto mais o jogador
olha para baixo, mais o boneco recua para trás da câmera (`FIRST_PERSON_BACK` no `player.gd`), senão
ele veria o buraco da gola e os ombros. Os outros veem o boneco inteiro, com sombra.

| Ajuste | Onde |
|---|---|
| Passos por metro, balanço das pernas e dos braços, quique, rebolado, curvatura | constantes no topo de `character_rig.gd` |
| Abertura dos braços parados (além do descanso) e o cotovelo dobrado | `ARM_SPLAY`, `ELBOW_REST` |
| Quanto o joelho dobra no passo | `KNEE_BEND` |
| Para onde o cotovelo aponta segurando | `pole` em `_reach` |
| Proporções do corpo | `TORSO`, `ARM_CAPSULES`, `LEG_CAPSULES` e as juntas em `character.py` |
| Rosto e acessórios | `head()` e `accessories()` em `character.py` |

A barba por fazer é uma casca aberta, rente à pele: com tampa, o contorno desenhava uma linha
preta atravessando o rosto.

## Empurra-empurra

Os bonecos não travam um no outro como blocos: a colisão dos jogadores é só com o mundo (camada
1), e o `player.gd` faz o empurrão:

- **Encostados** (centros a menos de `PUSH_DISTANCE` = 0,62 m), uma mola afasta os dois até ficarem
  só se tocando (`PUSH_SPRING`, refeita a cada quadro: afasta firme e para sem escorregar).
- **Quem chega andando** empurra o outro junto, quase na mesma velocidade (`PUSH_TRANSFER`); esse
  empurrão vai sumindo aos poucos quando eles se soltam (`PUSH_DAMPING`). Quem empurra também é
  afastado pela mola, então anda um pouco mais devagar empurrando.
- **Rede:** cada dono calcula o empurrão do próprio boneco a partir da posição dos outros, que já
  vem pela rede (e da velocidade deles, `body_velocity`, medida pelo quanto andaram). Os dois lados
  se afastam sem mensagem nova.
- **Balanço (animação procedural):** o tronco de quem encosta ou leva o empurrão inclina para o
  lado do empurrão e volta balançando numa mola, como gelatina (`character_rig.push`, `WOBBLE_*`).
  O resto vem atrasado, cada parte com a sua mola, e o balanço desce o corpo como uma onda: o
  peito e a cabeça começam girando ao contrário do tronco e depois passam do ponto (`CHEST_*`,
  `HEAD_*`), e os braços ficam para trás e abrem para fora, chicoteando (`ARM_FLAIL*`). Cada
  máquina calcula para todos os bonecos, então todo mundo vê.
- **Trombada:** no instante em que dois bonecos se encostam vindo rápido um para o outro (acima de
  `IMPACT_MIN_SPEED`), o balanço vem de uma vez (`character_rig.impact`), o corpo achata e volta
  (squash e stretch, `SQUASH_*`) e a câmera de quem levou dá um tranco, rolando para o lado do
  empurrão (`CAMERA_KICK`).
- **Tropeço:** as pernas dão o passo para o lado em que o corpo está indo de verdade, não só para
  frente. Empurrado de lado ou de costas, o boneco tropeça para lá em vez de deslizar.
- **Caindo (ragdoll parcial):** quem leva uma trombada de alguém vindo a mais de `RAGDOLL_SPEED`
  (3,5 m/s; andando é 2,8 e correndo 4,8) cai. Andando ninguém derruba ninguém; numa trombada de
  frente correndo, os dois caem. Quem cai solta o item da mão, e o esqueleto ganha ossos de física
  (`PhysicalBone3D`, `RAGDOLL_BONES` no `character_rig.gd`: quadril, tronco, peito, cabeça, braços
  e pernas, com juntas em cone) que tombam e rolam com o tranco: o alto do corpo vai mais, os pés
  quase ficam. Os ossos de física só batem no mundo (não empurram jogadores, itens nem uns aos
  outros). Depois de `RAGDOLL_TIME` (1,6 s) ele levanta: a cápsula do jogador desliza até onde os
  quadris pararam (sem atravessar parede) e a animação sai da pose de pano aos poucos
  (`GETUP_TIME`); só então ele volta a andar. Fica `RAGDOLL_COOLDOWN` sem poder cair de novo.
  - Em primeira pessoa, a câmera vai junto com a cabeça do ragdoll e volta enquanto levanta. Ela
    vai até lá como uma bolinha (`FALL_CAMERA_RADIUS`, 0,12 m) saindo da cabeça da cápsula e para
    antes da parede: caindo de cara nela, a cabeça do ragdoll encosta e a câmera entrava.
  - Rede: quem cai é o dono que decide (pela velocidade de quem chegou, que vem pela rede) e avisa
    os outros para cair e para levantar (`_remote_fall`, `_remote_stand`). Cada máquina simula o
    próprio ragdoll, então a queda pode sair um pouco diferente em cada tela; ao levantar, todos
    voltam para a posição do dono.
  - No Godot 4.7 o ragdoll é um modificador aplicado na hora de desenhar: a pose de pano não
    aparece em `get_bone_global_pose`; para ler, use os próprios ossos de física.
- Teleporte (nascer, voltar de fora do mapa) não conta como corrida: acima de `TELEPORT_SPEED` a
  velocidade vira zero, senão quem nascesse do lado de alguém o derrubaria.
- A velocidade de cada boneco (`body_velocity`) é medida no passo de física: o quadro de desenho
  roda mais vezes que a física, e medida lá ela dava zero em metade dos quadros.

| Ajuste | Onde |
|---|---|
| Distância, mola, quanto passa da velocidade, quão rápido some, máximo | `PUSH_*` no `player.gd` |
| Quanto o tronco balança | `PUSH_WOBBLE` no `player.gd`, `WOBBLE_*` no `character_rig.gd` |
| Atraso do peito e da cabeça, chicote dos braços, achatado | `CHEST_*`, `HEAD_*`, `ARM_FLAIL*`, `SQUASH_*` no `character_rig.gd` |
| Quando vale trombada e o tranco da câmera | `IMPACT_MIN_SPEED`, `CAMERA_KICK` no `player.gd` |
| Quando derruba, quanto tempo fica caído, intervalo até poder cair de novo | `RAGDOLL_SPEED`, `RAGDOLL_TIME`, `RAGDOLL_COOLDOWN` no `player.gd` |
| Tamanho, peso e juntas dos ossos de física, tempo para levantar | `RAGDOLL_BONES`, `GETUP_TIME` no `character_rig.gd` |

## Mãos machucadas

A guilhotina pode levar dedos ou a mão inteira de quem opera (`docs/maquinas.md`, "Mãos perto da
lâmina"). O host decide (`player.injure`) e avisa todo mundo; quem entra depois recebe como as mãos
estão (`send_injury_to`). Vale até sair da partida (`heal` só numa partida nova e nos testes).

- `player.injury` = [direita, esquerda], um bit por dedo (`DIGITS`: polegar, indicador, médio,
  anelar e mínimo, da frente para trás na guilhotina) e `HAND_LOST` para a mão inteira.
- **Luvas:** as peças que foram somem, e aparece o curativo no lugar (`Hand_R_StumpThumb`...; sem a
  mão, `Hand_R_StumpWrist` na ponta da manga). Sem a mão, o boneco também perde a luva dele
  (`character_rig.glove_lost`).
- **Escorregar:** com dedo faltando, andando com algo na mão, ele às vezes escorrega e cai
  (`SLIP_PER_FINGER` por segundo, por dedo; sem uma mão conta os 5): "It slipped out of your hand!".
- **Duas mãos:** sem uma delas não dá para pegar a resma (`ItemKinds.TWO_HANDED`).
- **Guilhotina:** a folha treme mais nas mãos de quem tem dedo faltando.

O `hands.glb` sai do `art_source/blender/hands.py`: cada mão é a manga (`Hand_R`, a raiz) com a
luva (`Hand_R_Glove`), os dedos (`Hand_R_Thumb`, `_Index`, `_Middle`, `_Ring`, `_Pinky`) e os
curativos de filhos, todos com a origem no pulso.
