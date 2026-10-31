# Mapa 1: kitnet 301

Primeiro mapa da progressão (kitnet → lugares maiores conforme o grupo cresce). Uma kitnet de 35 m²
num prédio velho, com a linha de produção de dinheiro improvisada dentro, para 4 jogadores.

O modelo é gerado por scripts no Blender (`art_source/blender/`, entrada `build.py`) e salvo em
`art_source/kitnet.blend`. O build exporta para `assets/models/kitnet.glb`. Não edite o `.blend`
na mão: mude os scripts e rode de novo.

```
blender --background art_source/kitnet.blend --python art_source/blender/build.py -- --export
blender --background art_source/kitnet.blend --python art_source/blender/preview.py -- <pasta> [vistas]
```

O `preview.py` renderiza a planta de cima (sem o teto) e vistas de dentro, com 4 cápsulas do
tamanho do jogador (raio 0,33 m, altura 1,75 m) nos pontos de spawn.

## Planta

Medidas em `art_source/blender/plan.py` (coordenadas do Blender; no Godot o +Y daqui vira -Z).

- Cômodo principal (x 0 a 5, y 0 a 5): cozinha na parede da frente, guarda-roupa e sofá-cama na
  parede oeste, mesa no meio, impressora e janela no fundo, TV de tubo enorme na divisória, retrato do presidente e caixas de pizza.
- Banheiro (x 5,12 a 7, y 0 a 2,2) com forro de PVC rebaixado a 2,35 m e alçapão em cima do vaso.
- Área de serviço (x 5,12 a 7, y 2,32 a 5), aberta para o cômodo por um vão sem porta: máquina de
  lavar, tanque e varal de teto.
- Corredor do prédio na frente: o 303 fica bem em frente à porta, o 302 ao lado, e a porta
  corta-fogo da escada fica no fim oeste (é por onde o fiscal chega).

Os corredores entre os móveis têm pelo menos 0,8 m, e os 4 jogadores andam juntos pelo meio do
cômodo sem travar.

## Linha de produção

| Etapa | Objeto | Onde |
|---|---|---|
| Papel | `SUPPLY_Paper` | caixas de resma ao lado da impressora |
| Tinta | `MACHINE_InkPot`, `SUPPLY_Ink` | panela fervendo no cooktop e galões na bancada (ainda decoração; por enquanto a tinta é o cartucho da impressora, comprado no PC) |
| Compras | `MACHINE_PC` | PC velho na ponta esquerda da escrivaninha da impressora: papel e cartucho pela internet (`docs/loja.md`) |
| Impressão | `MACHINE_Printer` | impressora de escritório velha na escrivaninha embaixo da janela |
| Secagem | `MACHINE_ClothesLine`, `MACHINE_Fan` | varal de teto (só as cordas e os pregadores) e ventilador no serviço |
| Corte | `MACHINE_Guillotine` | guilhotina de alavanca na mesa do meio |
| Envelhecer | `MACHINE_Washer` | máquina de lavar no serviço |
| Contar e cintar | `MACHINE_CashCounter` | contadora de cédulas na mesa |

A cortina da janela (`Curtain_Main`) fica meio aberta: dá para ver a impressora de fora.

## O que o jogo lê do modelo

| No modelo | No jogo |
|---|---|
| `MACHINE_*` / `SUPPLY_*` | Estações da produção. A origem fica na base. |
| `MACHINE_Guillotine_Arm` | Alavanca da guilhotina, com a origem no pivô; gira no Y local (filha da base). |
| `MACHINE_Washer_Lid` | Tampa da máquina de lavar, gira no X local na dobradiça de trás. A máquina é oca: o cesto fica embaixo da tampa. |
| `MACHINE_Washer_Knob`, `MACHINE_Washer_Led` | Botão do timer da máquina de lavar (gira no Y local) e o LED do painel. |
| `MACHINE_PC_Screen`, `MACHINE_PC_Mouse` | Tela do monitor (UV de 0 a 1, o Godot desenha o navegador) e o mouse (anda com o cursor). |
| `MACHINE_Fan_Blades` | Pás do ventilador, giram no Y local (o `ambience.gd` gira com o ventilador ligado). |
| `HIDE_*` | Esconderijos: `HIDE_SofaBed` (vão de 12 cm embaixo), `HIDE_Wardrobe` (e a mala em cima), `HIDE_Fridge`. |
| `KEEP_BathHatch` | Tampa do alçapão do forro do banheiro (o pacote vai entre o forro e a laje). |
| `KEEP_Door_<n>` | Porta com a origem na dobradiça, folha para +X local, face de fora para -Y local: `301` (entrada, com olho mágico), `302`, `303`, `Stairs`, `Bath`. |
| `KEEP_Breaker` | Quadro de luz ao lado da entrada. |
| `LAMP_<zona>_<n>` e `M_Lamp_<zona>` | Luminária e o material que brilha com a zona ligada. Zonas: `main`, `kitchen`, `bath`, `service`, `hall`. |
| `Cord_Lamp_<zona>_<n>` | Canopla, fio e bocal da lâmpada pelada: sem colisão, mas fazem sombra (a rodela escura no teto). |
| `LIGHT_<zona>_<n>` | Luz pontual de prévia (vai no .glb e pode servir de base). |
| `SPAWN_1` a `SPAWN_4` | Onde os jogadores nascem. |
| `POINT_Knock` | Onde o fiscal para para bater na porta, e onde o entregador deixa as caixas. |
| `Glass_*`, `Curtain_*` | Vidro e pano. |
| `TV_Rack` | TV de tubo: a tela (`M_TVScreen`) mostra chuvisco (`ambience.gd`); pode virar o monitor de uma câmera do corredor. |

| `Props_<cômodo>` | Objetos do dia a dia (botijão, roupas, latinhas, quadro de cortiça "do plano", eletroduto aparente...). Têm colisão. |
| `Newspaper_Window` | Jornal (capa e classificados) e silver tape no vidro da janela principal. Sem colisão. |
| `Decal_*` | Mofo, infiltração, encardido, rachaduras e a tinta verde (respingos e pegadas), a 3 mm da superfície. Sem colisão nem sombra. |
| `Outside_*` | Lá fora: rua, postes, o prédio da frente e o da lateral com janelas acesas, e prédios ao longe. Sem colisão nem sombra. |

O jornal, a tampa da pizza e a ficha do fiscal saem do `art_source/story_textures.py` (como as notas, com Pillow).

As notas usam a textura `T_Bill`, desenhada pelo `lib.py` (sem arquivo externo) e embutida no
`.blend` e no `.glb`. Uma folha impressa tem 2 x 2 notas.

## Texturas

`art_source/blender/textures.py`:

- **Pintadas em cinza:** papel de parede, reboco, granilite, madeiras e xadrez saem em cinza e a cor do material tinge. Por isso o mesmo reboco serve ao forro e à parede verde do corredor. Ver `docs/visual.md`.
- **Geradas no script:** piso cerâmico de 45 cm, piso do banheiro, azulejo 20 x 20, pastilha da cozinha, granito preto da pia, tecido do sofá, tapete e as manchas. Ficam embutidas no `.blend`.

As caixas ganham UV em metros, divididas pelo tamanho real de cada textura. Por isso a textura repete no tamanho certo em qualquer peça.

## Acabamento das peças

`lib.Part(bevel=...)` arredonda as quinas das caixas. Cada caixa pode pedir o seu (`box(..., bevel=)`,
`rounded(...)`): 2 a 5 mm na marcenaria, 3 a 8 cm no estofado, na louça, na geladeira e na TV de
tubo. O `finish` suaviza tudo por ângulo (quinas acima de 50° ficam vivas) e põe o modificador
Weighted Normal nas peças com bevel, aplicado no export. Assim as faces grandes ficam retas e só o
arredondado faz a transição.

Outros detalhes:

- **Cozinha:** portas almofadadas com puxador de barra, cuba de inox funda (o tampo é recortado em volta) e trempes no cooktop.
- **Sofá e sala:** almofadas fofas no sofá e moldura de gesso no teto do cômodo. O eletroduto corre escondido dentro da moldura.
- **Passagens e portas:** soleiras de granito nas passagens e almofadas, dobradiças e maçaneta de alavanca nas portas.
- **Instalações:** espelhos 4x2 de tomada e interruptor (`furniture.switch_plate`).
- **Luminárias:** as `LAMP_*` não fazem sombra no Blender. A luz fica dentro do bulbo.

A kitnet fica no 3º andar. A rua passa 8,6 m abaixo, entre o nosso prédio e o da frente.

## No Godot

`scenes/kitnet.tscn` + `scripts/kitnet.gd` carregam o `.glb` e dão vida a ele:

- Colisão do formato exato da malha em tudo, menos `LAMP_*`, `Curtain_*`, o varal, as pás do
  ventilador, `Decal_*` e `Outside_*`. Os pisos (`Floor_*`) colidem como uma caixa sólida: na
  malha de triângulos, uma resma parada às vezes afundava devagar e caía do mapa.
- Ambiente noturno de desenho animado: céu escuro com o horizonte alaranjado de cidade, sombra
  arroxeada chapada e um pouco de oclusão (SSAO). Ver `docs/visual.md`.
- O jogador local não vê o próprio boneco nem a sombra dele (com a lâmpada a meio metro da
  cabeça, a sombra cobria o cômodo). Os outros jogadores aparecem com sombra.
- `KEEP_Door_*` viram portas (`scripts/door.gd`) que abrem sempre para dentro (-Z local) com [E].
  `302`, `303` e `Stairs` estão trancadas.
- `LIGHT_<zona>_<n>` ganham alcance, energia e sombra por zona (`ZONE_LIGHT`).
- Os jogadores nascem nos `SPAWN_<vaga + 1>`.

As resmas, a impressora, o varal, a guilhotina e a máquina de lavar já funcionam (ver `docs/maquinas.md`), e o PC compra
papel e tinta (ver `docs/loja.md`). As outras máquinas, os esconderijos e o fiscal ainda não.

## Rede

`scripts/net.gd` (autoload `Net`): ENet direto por IP na porta 7777, até 4 jogadores, e quem
hospeda também joga. O menu (`scenes/main.tscn`) tem o nome, "Play solo", "Host a room" e
"Join" por IP. "Play solo" (`Net.play_solo()` ou `-- --solo`) entra sem rede nenhuma, nem
porta aberta: o peer offline do Godot já é o servidor (id 1), então o mapa roda igual.

- O host decide a lista de jogadores (`kitnet.roster`: id → nome e vaga). Quem entra só recebe
  RPCs da cena depois de avisar que carregou (`_client_ready`); por isso tudo que vai para
  "todos" usa `kitnet.rpc_roster(nó, método, args)` em vez de `rpc()`.
- Cada jogador é dono do próprio boneco: manda posição, giro, olhar e altura 30 vezes por
  segundo, e os outros seguem suavizando.
- Quem entra depois recebe a lista e as portas abertas.
- Quem cai sem avisar sai da lista em uns 15 s.

Duas janelas no mesmo PC:

```
godot --path . -- --host --name=Ana
godot --path . -- --join=127.0.0.1 --name=Bia
```

## Teste

```
godot --path . --resolution 1280x720 --script res://tools/tests/test_kitnet.gd -- --out=<pasta> [--client]
```

Hospeda uma sala e confere portas, spawns, luzes, o jogador no chão, a parede segurando e a 301
abrindo para dentro. Com `--client`, abre uma segunda janela que entra como "Bot" e confere que
ela aparece no SPAWN_2 e sai da lista quando fecha. Tira prints na pasta `--out`.
