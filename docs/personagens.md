# Personagens

Os jogadores são bonecos de desenho animado: adultos desengonçados e meio acabados, compridos e
curvados, de peito estreito e barriguinha de cerveja, braços e pernas finos e longos e tênis
grandes. A cara é de cansado: olhos pequenos de pálpebra caída e olheira, sobrancelhas finas
franzidas, nariz comprido caído, sorrisinho torto e barba por fazer no queixo. Usam moletom com
capuz (gola de ribana, capuz caído nas costas, bolso canguru), calça com a barra embolada em cima
do tênis (bico de borracha, cadarço, lingueta e listra vermelha) e luvas amarelas de borracha de
desenho, com três dedos e o polegar (na primeira pessoa aparecem as do `hands.glb`). O contorno preto e o cel
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

São peças rígidas, cada uma com a origem no ponto onde gira (braço e perna em duas partes):

| Peça | Origem | O que é |
|---|---|---|
| `Character` | pés | raiz |
| `Char_Body` | quadril | moletom (peito e barriga), gola, capuz, cordões e o cós com os bolsos de trás |
| `Char_Head` | pescoço | cabeça, rosto (com narinas, orelha por dentro e pomo de adão) e os quatro `Acc_*` |
| `Char_Arm_L` / `_R` | ombro | braço da manga (`UPPER_ARM` = 0,3 m) |
| `Char_Forearm_L` / `_R` | cotovelo | antebraço e o punho de ribana (`FOREARM` = 0,3 m) |
| `Char_Glove_L` / `_R` | pulso | luva de desenho (três dedos e o polegar) |
| `Char_Leg_L` / `_R` | quadril | coxa (`THIGH` = 0,38 m) |
| `Char_Shin_L` / `_R` | joelho | canela, a barra embolada e o tênis |

L é o lado esquerdo do boneco. No Blender a frente é -Y; o `character_rig.gd` gira o modelo para
a frente do jogador (-Z no Godot). Os materiais `M_Hoodie` e `M_HoodieDark` são trocados no jogo
pela cor da vaga.

## Animação

`scripts/character_rig.gd` anima por código, a partir de quanto o boneco andou em cada quadro
(serve para os bonecos dos outros, que só recebem a posição):

- sempre um pouco curvado para frente (`SLOUCH`);
- andando: pernas e braços balançam (ao contrário), o joelho dobra quando a perna vem para
  frente, o cotovelo dobra quando o braço vai para frente, o corpo quica de leve, curva mais e
  rebola;
  andar para trás roda o passo ao contrário;
- parado: respira (o corpo estica e encolhe de leve), com os cotovelos meio dobrados;
- no ar: joelhos encolhidos e braços para cima;
- a cabeça acompanha metade do olhar (para cima e para baixo);
- segurando um item: IK de dois ossos, o ombro e o cotovelo se ajustam para a mão chegar nas
  luvas do `hands.glb` que seguram o item (o cotovelo aponta para baixo, para fora e um pouco
  para trás), e as luvas do boneco somem. Longe demais, o braço estica reto na direção;
- agachado: o `player.gd` achata o boneco inteiro (`_body.scale.y`).

O próprio boneco fica escondido para quem joga (só aparecem as luvas na primeira pessoa).

| Ajuste | Onde |
|---|---|
| Passos por metro, balanço das pernas e dos braços, quique, rebolado, curvatura | constantes no topo de `character_rig.gd` |
| Abertura dos braços parados (contornando a barriga) e o cotovelo dobrado | `ARM_SPLAY`, `ELBOW_REST` |
| Quanto o joelho dobra no passo | `KNEE_BEND` |
| Para onde o cotovelo aponta segurando | `pole` em `_reach` |
| Proporções, rosto e acessórios | `character.py` (`HIP`, `NECK`, `SHOULDER`, `HEAD_C`, `HEAD_R`...) |

A barba por fazer é uma casca aberta, rente à pele: com tampa, o contorno desenhava uma linha
preta atravessando o rosto.
