# O vizinho do 303, a polícia e os esconderijos

O perigo da kitnet. O barulho das máquinas incomoda o vizinho da frente. Ele vem reclamar e, se
vir o esquema, chama a polícia. A polícia leva tudo que estiver à vista e cobra uma multa. O que
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
3. Se viu prova, grita e corre para o capacho dele ligando para a polícia. A ligação leva
   `CALL_TIME` (12 s). Se não viu nada, volta para casa resmungando.

**O que conta como prova** (`_sees_evidence`), sempre na frente dele (`SIGHT_HALF_ANGLE`), a
até `SIGHT` metros e sem parede nem porta fechada no meio:

- folhas, notas e maços, mesmo na mão de alguém (dentro do saco de lixo fechado, não: parece
  lixo; aberto, ele vê pela boca; ver `docs/maquinas.md`);
- a impressora imprimindo;
- notas no funil ou na bandeja da contadora;
- folha na guilhotina.

### Parar o vizinho

- **Frigideira:** o mesmo `take_bonk` dos jogadores. Ele cai desmaiado por `KO_TIME` (20 s), com
  as estrelinhas, e a ligação cai. Outra pancada recomeça o tempo.
- **Arrastar:** com ele desmaiado, [E] pega pela gola. Só um jogador por vez, de mãos vazias.
  - Quem arrasta anda devagar (`DRAG_SPEED`, sem correr), e o boneco dele estica os braços até
    a gola.
  - O corpo vem na frente: os quadris e o peito são puxados como molas, e o resto vem
    pendurado.
  - [G] ou [E] solta. Ficar longe demais (`DRAG_BREAK`) ou cair também solta.
- **Onde ele acorda:**
  - perto do capacho dele (`HOME_RADIUS`): "What a weird dream...", e volta a dormir;
  - em qualquer outro lugar: lembra de tudo e liga de novo.
- **Suborno:** com um maço na mão, [E] nele. Ele fica com o maço, desliga o telefone e volta
  para casa, e a próxima visita demora um pouco mais. Vale enquanto ele está incomodando (não
  desmaiado nem indo embora).

### A trava da porta

A 301 tranca por dentro: [E] na tranca de barra do meio da folha (`door.make_lockable`).

- Trancada, ninguém abre por fora.
- De dentro, [E] na porta também destranca.
- O host abre qualquer porta com `set_open`, trancada ou não: o vizinho sai pela 303 e a polícia
  entra pela 301.

## A polícia

`police.gd`. A viatura chega `RAID_DELAY` (30 s) depois da ligação.

- Durante a espera, o HUD mostra a contagem no alto.
- A sirene vai chegando (`SIREN_AT`), e as luzes vermelha e azul piscam pela janela e no
  corredor.

Na batida:

1. A 301 abre à força.
2. A polícia leva toda folha, nota e maço que for item (até na mão de alguém).
3. Também leva o que estiver na guilhotina, na máquina de lavar e na contadora. Cada uma tem
   `confiscate()`.
4. O caixa paga `FINE` ($100, ou o que tiver), só se acharam alguma coisa.
5. A partida continua.

Enquanto a polícia está a caminho, a paciência do vizinho não sobe.

## Esconderijos

`stash.gd`, presos nos objetos do modelo. [E] com um item na mão guarda o item lá dentro (ele
some do mapa). [E] de mão vazia tira o último que entrou.

| Esconderijo | Onde | Cabe |
|---|---|---|
| `HIDE_Wardrobe` | portas do guarda-roupa | 8 |
| `HIDE_SofaBed` | vão embaixo do sofá-cama (olhar para o chão na frente) | 5 |
| `HIDE_Fridge` | porta da geladeira | 4 |
| `KEEP_BathHatch` | alçapão do forro do banheiro, em cima do vaso | 10 |

A polícia não acha o que está escondido, e o vizinho não vê.

## Rede

O host decide tudo. 15 vezes por segundo (`_sync`), ele manda:

- a posição e o giro;
- o estado e a pose dos braços (bater, telefone, punho, mãos na cintura);
- quem está arrastando;
- a ligação;
- o barulho.

Vão como eventos (`_event`): as falas (balão em cima da cabeça), as batidas, o desmaio, o
acordar e o suborno.

Os ossos de física de cada máquina caem e são arrastados sozinhos. Para isso, o nó não se mexe
enquanto ele está no chão: a zona de [E] e a cápsula da frigideira vão até os quadris.

## Teste

`_test_neighbor` em `tools/tests/test_kitnet.gd`. O resto do teste desliga o vizinho
(`enabled = false`), porque as máquinas fazem barulho de sobra.

## Ainda falta

- Esconder ele desmaiado (banheiro, guarda-roupa): acordado lá dentro, ele grita abafado e faz
  barulho.
- Os policiais como bonecos (por enquanto, só a sirene, as luzes e a mensagem).
- Janela aberta e noite deixando ele mais irritado.
