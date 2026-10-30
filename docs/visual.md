# Visual

Desenho animado de party game co-op: sombra em tons duros, contorno preto grosso e uma paleta
retrô desbotada (verde musgo, mostarda, laranja queimado, azul de piscina). O jogo continua em
primeira pessoa.

## Etapas

1. **Feito:** cel shading, contorno e a paleta nova no mapa atual, sem mexer na geometria.
2. Texturas pintadas à mão (cor chapada com rachaduras e manchas em traço) e formas tortas (uma
   leve inclinação, afunilamento ou barriga aleatória por objeto no `Part.finish`).
3. Objetos novos (silver tape na impressora, jornal na janela, trancas na porta, caixas de pizza,
   retrato de um presidente inventado, lâmpada pelada) e proporções exageradas.

## Como funciona

- **Paleta:** as cores ficam em `lib.MATERIALS` (`art_source/blender/lib.py`). As fotos do Poly
  Haven entram em cinza e são tingidas por essa cor (`textures.RELIGHT`, inclusive as madeiras). As
  texturas geradas (piso, azulejos, tecido, tapete) têm as cores no próprio gerador.
- **Cel shading:** `scripts/toon.gd` troca cada StandardMaterial3D (os do `kitnet.glb` e os
  criados no código) por um shader com a luz de `shaders/toon_light.gdshaderinc`: sombra, meia-luz
  e luz cheia, com borda dura, e um brilho duro nas superfícies lisas. As texturas ficam 55% na cor
  média delas (`Toon.FLATTEN`). A folha impressa (`paper.gdshader`) usa a mesma luz.
  - O `kitnet.gd` converte toda malha que entra na cena.
  - Quem troca um material depois passa ele por `Toon.material()`. Quem muda a cor de um já
    convertido chama `Toon.sync()`. Quem troca a malha chama `Toon.apply_one()`.
- **Contorno:** `shaders/outline.gdshader`, num quadrado filho da câmera do jogador local. Ele
  marca linha onde a profundidade dá degrau ou quina e onde a normal vira. Some entre 9 e 25 m.
- **Ambiente** (`kitnet._build_environment`): a sombra é um tom arroxeado chapado (luz ambiente
  0,3). Fica só um pouco de oclusão de ambiente; a luz rebatida e a neblina saíram.

## Ajustes

| O quê | Onde |
|---|---|
| Onde começam a meia-luz e a luz cheia, e a força da meia-luz | `TOON_*` em `toon_light.gdshaderinc` |
| Quanto as texturas perdem de detalhe | `Toon.FLATTEN` |
| Grossura, cor e sensibilidade do contorno | uniforms do `outline.gdshader` |
| Cor e força do tom de sombra | `ambient_light_*` em `kitnet._build_environment` |
