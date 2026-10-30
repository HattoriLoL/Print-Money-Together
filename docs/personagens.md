# Personagens

Os jogadores são bonecos de desenho animado: adultos desengonçados e meio acabados, compridos e
curvados, de peito estreito e barriguinha de cerveja, braços e pernas finos e longos e tênis
grandes. A cara é de cansado: olhos pequenos de pálpebra caída e olheira, sobrancelhas finas
franzidas, nariz comprido caído, sorrisinho torto e barba por fazer no queixo. Usam moletom com
capuz e luvas amarelas de borracha (as mesmas da primeira pessoa). O contorno preto e o cel
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

São peças rígidas, cada uma com a origem no ponto onde gira:

| Peça | Origem | O que é |
|---|---|---|
| `Character` | pés | raiz |
| `Char_Body` | quadril | moletom (peito e barriga), calça, capuz e cordões |
| `Char_Head` | pescoço | cabeça, rosto e os quatro `Acc_*` |
| `Char_Arm_L` / `_R` | ombro | manga pendurada para baixo (`ARM_LEN` = 0,6 m) |
| `Char_Glove_L` / `_R` | pulso | luva de borracha |
| `Char_Leg_L` / `_R` | quadril | perna da calça e o tênis |

L é o lado esquerdo do boneco. No Blender a frente é -Y; o `character_rig.gd` gira o modelo para
a frente do jogador (-Z no Godot). Os materiais `M_Hoodie` e `M_HoodieDark` são trocados no jogo
pela cor da vaga.

## Animação

`scripts/character_rig.gd` anima por código, a partir de quanto o boneco andou em cada quadro
(serve para os bonecos dos outros, que só recebem a posição):

- sempre um pouco curvado para frente (`SLOUCH`);
- andando: pernas e braços balançam (ao contrário), o corpo quica de leve, curva mais e rebola;
  andar para trás roda o passo ao contrário;
- parado: respira (o corpo estica e encolhe de leve);
- no ar: pernas encolhidas e braços para cima;
- a cabeça acompanha metade do olhar (para cima e para baixo);
- segurando um item: os braços vão do ombro até as luvas do `hands.glb` que seguram o item
  (esticando ou encolhendo a manga), e as luvas do boneco somem;
- agachado: o `player.gd` achata o boneco inteiro (`_body.scale.y`).

O próprio boneco fica escondido para quem joga (só aparecem as luvas na primeira pessoa).

| Ajuste | Onde |
|---|---|
| Passos por metro, balanço das pernas e dos braços, quique, rebolado, curvatura | constantes no topo de `character_rig.gd` |
| Abertura dos braços parados (contornando a barriga) | `ARM_SPLAY` |
| Proporções, rosto e acessórios | `character.py` (`HIP`, `NECK`, `SHOULDER`, `HEAD_C`, `HEAD_R`...) |

A barba por fazer é uma casca aberta, rente à pele: com tampa, o contorno desenhava uma linha
preta atravessando o rosto.
