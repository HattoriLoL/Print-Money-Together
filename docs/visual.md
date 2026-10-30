# Visual

Desenho animado de party game co-op: sombra em tons duros, contorno preto grosso e uma paleta
retrô desbotada (verde musgo, mostarda, laranja queimado, azul de piscina). O jogo continua em
primeira pessoa.

## Etapas

1. **Feito:** cel shading, contorno e a paleta nova no mapa atual, sem mexer na geometria.
2. **Feito:** texturas pintadas (cor chapada, traços simples, rachaduras e manchas de desenho),
   quinas mais gorduchas, tudo levemente torto e as notas em verde neon.
3. **Feito:** objetos novos e proporções exageradas:
   - silver tape na impressora (`machines.printer`, `M_SilverTape`);
   - jornal colado no vidro da janela principal, com tape nos cantos (`Newspaper_Window`, sem
     colisão, em `props.newspaper_window`);
   - trancas do lado de dentro da porta 301: dois ferrolhos, corrente, tranca de barra e chave
     tetra (`structure._door_locks`);
   - caixas de pizza: pilha de cinco perto da divisória e uma aberta, comida pela metade, no sofá
     (`props._pizza_stack` e `_pizza_open`);
   - retrato a óleo de um presidente inventado, na parede oeste (`Props_Portrait`, textura
     `M_Portrait`, pintada em `textures._gen_portrait`);
   - lâmpada pelada de bulbo gordo no fio (`structure._bare_bulb`, ainda `LAMP_main_0`);
   - geladeira gorducha (0,72 x 0,84 m, quinas de 12 cm) e TV de tubo enorme (1,1 m de largura,
     mais larga que o rack).

4. **Feito:** acabamento do que já aparecia:
   - contorno sem listras: a quina é procurada pixel a pixel no raio da linha (antes, pulando de
     2 em 2, um sulco fino virava várias listras paralelas);
   - frisos chanfrados a 45° (`Part.trim`) nas molduras das portas, almofadas dos armários e
     guarnições: de quina viva, vistos de frente, sumiam entre os pixels e o contorno saía
     pontilhado. Ainda sobra um pontilhado leve na régua que fica de costas para a câmera;
   - teto com só 25% da luz cheia (`Toon.FULL_LIGHT`): a lâmpada pelada, pertinho dele, fazia uma
     mancha clara enorme. O bocal e o fio (`Cord_Lamp_*`) fazem sombra: rodela escura no teto;
   - caixas de pizza lisas de quina redonda (com aba e frisos o contorno deixava a pilha preta);
   - geladeira mais baixa e gorda, em pezinhos, com puxadores cromados grandes e a fruteira em
     cima do micro-ondas.

5. **Feito:** vida no cenário (`scripts/ambience.gd`, só visual, nada passa pela rede):
   - o ventilador gira e o vento dele faz as folhas de notas do varal tremularem; a cortina
     balança devagar;
   - a lâmpada pelada pisca de vez em quando (a luz junto) e balança no fio quando alguém passa
     perto, levando a luz e as sombras;
   - a TV de tubo mostra chuvisco;
   - a panela de tinta solta nuvenzinhas de vapor com contorno.
   Cada máquina sorteia as próprias piscadas: dois jogadores não veem a lâmpada piscar na mesma
   hora.

6. **Feito:** detalhes que contam a história:
   - texto de verdade (em inglês) no jornal da janela, que alterna a capa ("FAKE BILLS FLOOD
     CITY") e os classificados, e na tampa da pizza da Zé's; a ficha do fiscal ("SUSPECT FILE
     #1", "NEVER open the door!!") no quadro de cortiça. Desenhados por
     `art_source/story_textures.py` (Pillow e fontes do Windows), como as notas;
   - cesto de lixo ao lado da escrivaninha transbordando de papel e notas que saíram erradas,
     com algumas no chão (`Props_Trash`);
   - respingos de tinta verde em volta da panela, na bancada, na mesa da guilhotina e embaixo da
     impressora, e uma trilha de pegadas verdes da cozinha até a impressora (`Decal_Ink`,
     `M_DecalInk` e `M_DecalFootprint`).

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
- **Vento no vértice:** o toon tem `instance uniform`s `wind` (força, topo, comprimento,
  velocidade) e `wind_dir`, por malha (`set_instance_shader_parameter`). O que fica abaixo do
  topo balança, mais quanto mais longe dele. Força 0 (o padrão) não mexe nada.
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
| Quanto da luz cheia cada material aceita (o teto) | `Toon.FULL_LIGHT` |
| Vento do varal e da cortina, giro do ventilador, piscadas e balanço da lâmpada, vapor | constantes no topo de `ambience.gd` |
| Cor e força do tom de sombra | `ambient_light_*` em `kitnet._build_environment` |
