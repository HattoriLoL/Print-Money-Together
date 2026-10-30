# Visual

Desenho animado de party game co-op: sombra em tons duros, contorno preto grosso e uma paleta
retrô desbotada (verde musgo, mostarda, laranja queimado, azul de piscina). O jogo continua em
primeira pessoa.

## Etapas

1. **Feito:** cel shading, contorno e a paleta nova no mapa atual, sem mexer na geometria.
2. **Feito:** texturas pintadas (cor chapada, traços simples, rachaduras e manchas de desenho),
   quinas mais gorduchas, tudo levemente torto e as notas em verde neon.
3. Objetos novos (silver tape na impressora, jornal na janela, trancas na porta, caixas de pizza,
   retrato de um presidente inventado, lâmpada pelada) e proporções exageradas.

## Como funciona

- **Paleta:** as cores ficam em `lib.MATERIALS` (`art_source/blender/lib.py`).
- **Texturas pintadas** (`art_source/blender/textures.py`), geradas no build, sem fotos:
  - Em cinza, tingidas pela cor do material (`TINTED`): papel de parede listrado com losangos,
    reboco com pinceladas, granilite, veio de madeira e xadrez do cobertor.
  - Já coloridas: pisos e azulejos lisos com rejunte grosso e um risco de brilho no canto de cada
    peça, granito de bolinhas, sofá liso, tapete listrado, plástico velho e a chapa da escrivaninha.
  - Com transparência: mofo, infiltração e encardido (bolha chapada com a borda escura) e as
    rachaduras em traço preto (`M_DecalCrack`, colocadas em `props.decals`).
- **Formas tortas** (`art_source/blender/wonky.py`, no fim do build): um campo suave empurra os
  vértices na horizontal conforme a posição no mundo. Peças coladas andam juntas e nada muda de
  altura (os tampos ficam no lugar). Para isso, as faces de pé são fatiadas numa grade de
  12,5 cm (as deitadas continuam planas e ficam inteiras). A luz usa as normais de antes de
  entortar, então só a silhueta e o contorno mudam. Ficam retos as máquinas e suprimentos (o
  Godot mede e anima peças deles) e os pisos. `lib.BEVEL_SCALE` deixa todas as quinas 1,5x mais
  arredondadas.
  - Duas peças coladas no mesmo plano brigam depois de entortar: deixe uns 2 mm entre elas (o
    visor do forno era colado na porta).
- **Notas:** `paper_textures.neon` satura o verde da nota (frente, verso e a folha A4).
- **Cel shading:** `scripts/toon.gd` troca cada StandardMaterial3D (os do `kitnet.glb` e os
  criados no código) por um shader com a luz de `shaders/toon_light.gdshaderinc`: sombra, meia-luz
  e luz cheia, com borda dura, e um brilho duro nas superfícies lisas. As texturas ficam 15% na cor
  média delas (`Toon.FLATTEN`). A folha impressa (`paper.gdshader`) usa a mesma luz.
  - O `kitnet.gd` converte toda malha que entra na cena.
  - Quem troca um material depois passa ele por `Toon.material()`. Quem muda a cor de um já
    convertido chama `Toon.sync()`. Quem troca a malha chama `Toon.apply_one()`.
- **Contorno:** `shaders/outline.gdshader`, num quadrado filho da câmera do jogador local. Ele
  marca linha onde a profundidade dá degrau ou quina e onde a normal vira. As linhas de quina
  somem entre 2 e 4 m (de longe, sulcos menores que um pixel saíam tracejados); a silhueta some
  entre 9 e 25 m.
- **Ambiente** (`kitnet._build_environment`): a sombra é um tom arroxeado chapado (luz ambiente
  0,3). Fica só um pouco de oclusão de ambiente; a luz rebatida, a neblina e as sondas de
  reflexo saíram (o espelho do banheiro é só um cinza claro).

## Ajustes

| O quê | Onde |
|---|---|
| Onde começam a meia-luz e a luz cheia, e a força da meia-luz | `TOON_*` em `toon_light.gdshaderinc` |
| Quanto as texturas perdem de detalhe no Godot | `Toon.FLATTEN` (0,15: elas já vêm pintadas) |
| Quanto e como tudo entorta | `LAYERS` e `GRID` em `wonky.py` |
| Grossura, cor e sensibilidade do contorno | uniforms do `outline.gdshader` |
| Cor e força do tom de sombra | `ambient_light_*` em `kitnet._build_environment` |
