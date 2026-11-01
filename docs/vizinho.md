# O vizinho do 303, a polícia e os esconderijos

O perigo da kitnet. O barulho das máquinas incomoda o vizinho da frente. Ele vem reclamar e, se
vir o esquema, foge do prédio chamando a polícia. A polícia leva tudo que estiver à vista e cobra uma multa. O que
estiver escondido fica.

Código: `scripts/neighbor.gd`, `scripts/police.gd`, `scripts/machines/stash.gd` e a tranca em
`scripts/door.gd`. Os textos do jogo ficam em inglês.

## O vizinho

Um senhor de roupão e bobes, com bigodão. É o mesmo boneco dos jogadores (`character_rig.gd`):

- roupão no lugar do moletom (`ROBE`);
- mãos de pele no lugar das luvas amarelas;
- o acessório `Acc_Neighbor` (bobes, costeletas grisalhas e bigode), feito em
  `art_source/blender/character.py`.

Ele aparece e some pela porta do 303, que fica bem em frente à 301.

### Paciência

O host soma o barulho de tudo que está no grupo `noise_source` (cada máquina tem `noise()`, de 0
a 1).

- Acima de `QUIET` (0,18: o ventilador e a impressora ligada parada não contam), a irritação
  sobe na velocidade `ANNOY_RATE`. Só a lavadora (centrifugando sozinha) chama ele em uns 4
  ciclos; segurando o gabinete, bem menos. Impressora imprimindo sem parar: uns 2 minutos. Cada visita que ele já
  fez acelera a próxima (`VISIT_FACTOR`).
- Em silêncio, a irritação desce devagar (`CALM_RATE`).
- Antes de vir, ele avisa de longe:
  - na metade (`BANG_AT`), bate na parede ("BANG BANG BANG");
  - perto do fim (`YELL_AT`), grita: "KEEP IT DOWN!".
- Cheia, ele vem.

O HUD mostra o barulho de agora (a barra "NOISE", embaixo à direita), mas não a paciência dele.

### A visita

1. Sai do 303, para na frente da 301 e bate até `KNOCKS` vezes.
2. Depende de quem atende:
   - **Alguém abre:** ele reclama por `COMPLAIN_TIME` e olha para dentro pela porta aberta.
   - **Ninguém abre e a porta está trancada:** ameaça chamar o síndico e volta para casa.
   - **Ninguém abre e a porta está destrancada:** ele entra e olha em volta (`INSPECT_TIME`).
3. Se viu prova, grita e **foge do prédio** com o telefone na orelha. Se não viu nada, volta para
   casa resmungando.

### A fuga

Ele corre pelo corredor, abre a porta da escada, desce os três andares e sai pela porta da rua
(`SPINE`, os pontos do caminho; a escada está em `docs/kitnet.md`). O HUD avisa: "Catch the
neighbor before he gets out of the building!", com quanto da ligação já foi.

- Corre a `FLEE_SPEED` (3,4 m/s) no plano e a `STAIRS_SPEED` (2,7) nos lances. Andando (2,8) não
  dá para alcançar; correndo (4,8), dá.
- A ligação leva `CALL_TIME` (30 s): correndo e sem fôlego, ele erra os números.
- Ele perde de dois jeitos para os jogadores: **sair pela porta da rua** (de lá ele chama a
  polícia, com ou sem telefone) ou **a ligação completar** (aí ele volta para casa pelo mesmo
  caminho, devagar).
- Do 3º andar até a rua são uns 10 s correndo.

**O que conta como prova** (`_sees_evidence`), sempre na frente dele (`SIGHT_HALF_ANGLE`), a
até `SIGHT` metros e sem parede nem porta fechada no meio:

- folhas, notas e maços, mesmo na mão de alguém (dentro do saco de lixo fechado, não: parece
  lixo; aberto, ele vê pela boca; ver `docs/maquinas.md`);
- a impressora imprimindo;
- notas no funil ou na bandeja da contadora;
- folha na guilhotina.

### Parar o vizinho

- **Trombada:** quem chega correndo para cima dele (mais rápido que `TACKLE_SPEED`, 3,5 m/s, a
  menos de `TACKLE_REACH`) derruba. Ele cai por `TACKLE_DOWN` (2,4 s), "OOF!", e **o telefone voa**
  para a frente e cai como um item (`phone`).
  - Caído no chão, o telefone continua chamando: o "Calling the police..." e o toque vão para
    cima dele.
  - **Pegar o telefone desliga** ("*click* You hung up on the police!").
  - Levantando, ele corre atrás do telefone (até `FETCH_TRIES` vezes, se alguém chutar para
    longe). Pega e volta a fugir ligando; se tinham desligado, liga de novo do começo.
  - Com o telefone na mão de alguém, ele grita e foge sem ele: lá fora, liga do orelhão.
  - A cada visita nova ele tem outro telefone. O que ficou com os jogadores para de chamar.
  - Ele levanta no chão embaixo de onde o corpo parou. Se o corpo atravessar o chão e cair para
    fora do mapa (`FELL_OUT_Y`), ele volta para o ponto do caminho mais perto.
- **Frigideira:** o mesmo `take_bonk` dos jogadores. Ele cai desmaiado por `KO_TIME` (20 s), com
  as estrelinhas, e a ligação cai (se o telefone estava na mão dele; caído no chão, continua
  chamando). Outra pancada recomeça o tempo.
- **Arrastar:** com ele desmaiado, [E] pega pela gola. Só um jogador por vez, de mãos vazias.
  - Quem arrasta anda devagar (`DRAG_SPEED`, sem correr), e o boneco dele estica os braços até
    a gola.
  - O corpo vem na frente: os quadris e o peito são puxados como molas, e o resto vem
    pendurado.
  - [G] ou [E] solta. Ficar longe demais (`DRAG_BREAK`) ou cair também solta.
- **Onde ele acorda:**
  - perto do capacho dele (`HOME_RADIUS`): "What a weird dream...", e volta a dormir;
  - em qualquer outro lugar: lembra de tudo e foge de novo (atrás do telefone, se ele estiver no
    chão). Na escada, ele acorda no chão de onde o corpo parou, mesmo que tenha rolado um lance.
- **Suborno:** com um maço na mão, [E] nele. Ele fica com o maço, desliga o telefone e volta
  para casa, e a próxima visita demora um pouco mais. Vale enquanto ele está incomodando (não
  desmaiado nem indo embora).

### A trava da porta

A 301 tranca por dentro: [E] na tranca de barra do meio da folha (`door.make_lockable`).

- Trancada, ninguém abre por fora.
- De dentro, [E] na porta também destranca.
- O host abre qualquer porta com `set_open`, trancada ou não: o vizinho sai pela 303 e a polícia
  entra pela 301.

## A polícia e os esconderijos

Quando a ligação completa, a polícia chega 30 s depois e entra de verdade: dois policiais revistam
os móveis com chance, pegam o dinheiro à vista e prendem quem encontrarem. Tudo isso está em
`docs/policia.md`, junto com os esconderijos de dinheiro (`stash.gd`) e os de gente
(`hideout.gd`).

Enquanto a polícia está a caminho ou dentro, a paciência do vizinho não sobe.

## Rede

O host decide tudo. 15 vezes por segundo (`_sync`), ele manda:

- a posição e o giro;
- o estado e a pose dos braços (bater, telefone, punho, mãos na cintura);
- quem está arrastando;
- a ligação;
- o barulho.

Vão como eventos (`_event`): as falas (balão em cima da cabeça), as batidas, o desmaio, o
acordar, o suborno, a trombada, o levantar, o telefone desligado e a fuga pela porta da rua. O
telefone caído é um item como os outros (`items`), com `calling` nos dados.

Os ossos de física de cada máquina caem e são arrastados sozinhos. Para isso, o nó não se mexe
enquanto ele está no chão: a zona de [E] e a cápsula da frigideira vão até os quadris.

## Teste

`_test_neighbor` em `tools/tests/test_kitnet.gd`. O resto do teste desliga o vizinho
(`enabled = false`), porque as máquinas fazem barulho de sobra.

Na fuga: ele vê as notas, foge ligando (o HUD avisa), abre a porta da escada e desce os lances. A
trombada derruba e o telefone voa chamando; pegar desliga. Ele levanta e foge sem o telefone até
a rua, de onde chama a polícia, e a porta da rua fecha. Depois, com a frigideira, ele cai no
corredor no meio da fuga e a ligação cai.

## Ainda falta

- Esconder ele desmaiado (banheiro, guarda-roupa): acordado lá dentro, ele grita abafado e faz
  barulho.
- Janela aberta e noite deixando ele mais irritado.
- Segurar a porta da escada fechada na cara dele (hoje ele abre qualquer porta do caminho).
- Os policiais subindo pela escada de verdade (hoje eles aparecem no patamar do 3º andar).
