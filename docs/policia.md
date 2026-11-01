# A batida policial

Quando o vizinho do 303 completa a ligação (`docs/vizinho.md`), a polícia chega e entra na
kitnet. Ela pega o dinheiro à vista, revista os móveis e prende quem encontrar. Não tem fim de
partida: quem foi preso volta quando a batida acaba.

Código:

- `scripts/police.gd`: o relógio, a sirene, as luzes, as tarefas, a multa e quem está preso.
- `scripts/cop.gd`: cada policial.
- `scripts/hideout.gd`: os esconderijos de gente.
- `scripts/machines/stash.gd`: os esconderijos de dinheiro e a revista (`seize`).
- `scripts/player.gd`: o jogador escondido e o jogador preso.
- `scripts/kitnet.gd`: a malha de navegação e o parapeito da janela.

Os textos do jogo ficam em inglês.

## A chegada

A viatura chega `RAID_DELAY` (30 s) depois da ligação. Durante a espera, o HUD mostra a contagem
no alto. A sirene vai chegando (`SIREN_AT`), e as luzes vermelha e azul piscam pela janela e no
corredor.

Na hora da batida, a porta corta-fogo da escada abre e dois policiais entram no corredor pelo
patamar da escada (`STAIRS`). Eles abrem as portas que estiverem no caminho: a 301 (com um
estrondo, trancada ou não) e a do banheiro. O HUD avisa: "POLICE! OPEN UP! Hide or run!".

## Os policiais

São o mesmo boneco dos jogadores (`character_rig.gd`), com farda azul, mãos de pele, sem o capuz
nem o bolso do moletom, e com um cacetete preto na mão direita. O cacetete fica na direção do
antebraço: com o braço solto, cai do punho, e na cacetada vira o prolongamento do braço.

Os acessórios vêm de `art_source/blender/character.py`:

- `Acc_Police`: quepe azul-marinho de copa alargada, faixa preta, pala de verniz, distintivo
  dourado e bigodão;
- `Acc_PoliceShades`: o mesmo quepe, com óculos de aviador no lugar do bigode.

Eles andam pela malha de navegação (`kitnet._bake_navigation`). Ela é feita na hora, no host, a
partir da colisão do modelo, e cobre a kitnet, o banheiro, o serviço e o corredor. As portas ficam
de fora da malha, porque eles abrem as portas no caminho. Travou por `STUCK_TIME`, o policial pula
para o próximo ponto do caminho.

| | |
|---|---|
| Andando | `WALK_SPEED` (1,7 m/s) |
| Correndo atrás de alguém | `RUN_SPEED` (3,7 m/s). Andando, o jogador faz 2,8; correndo, 4,8, então dá para fugir. |
| Arrastando um preso | `DRAG_SPEED` (1,4 m/s) |
| Vista | até `SIGHT` (9 m), na frente (`SIGHT_HALF_ANGLE`), sem parede no meio. Mais perto que `NOTICE_RANGE`, percebe até de costas. |

### As tarefas

Cada policial recebe uma metade da kitnet (`police.search_points`, `_split_tasks`), com a ordem um
pouco embaralhada:

- **Oeste:** guarda-roupa, sofá-cama, janela e uma olhada na sala.
- **Leste:** geladeira, box, alçapão do banheiro, uma olhada no serviço e, por último, o corredor
  perto do 302.

Em cada lugar, ele para na frente, olha e revista por `SEARCH_TIME` (2,2 s), mexendo as mãos. A
revista acha de verdade com a chance do lugar:

| Lugar | Chance | Dinheiro (stash) | Gente (hideout) |
|---|---|---|---|
| Guarda-roupa | 0,7 | porta da esquerda | porta da direita |
| Geladeira | 0,6 | sim | |
| Box do banheiro | 0,6 | | sim (cabem 2) |
| Sofá-cama | 0,45 | vão embaixo | dentro (o assento levanta) |
| Corredor, perto do lixo do 302 | 0,35 | | sim (cabem 2) |
| Janela | 0,3 | | sim (o parapeito lá fora) |
| Alçapão do banheiro | 0,2 | sim | |

Achando, ele leva o dinheiro do esconderijo (`stash.seize`): folhas, notas, maços e o dinheiro de
saco de lixo aberto. O saco aberto fica, vazio. **O saco de lixo fechado passa por lixo**, e o
resto (frigideira, resma) fica. Quem estava escondido ali sai pego (`hideout.flush`): "GOTCHA!",
e ele corre atrás.

A prova à vista ele pega no caminho (`visible_evidence`): folha, notas, maço e saco aberto com
dinheiro, soltos. Viu, vai buscar logo depois do que está fazendo. Os dois não buscam a mesma.

### Pegar alguém

1. **Viu alguém** que não está escondido nem preso: grita "FREEZE!" e corre atrás (`CHASE`). Se
   estava indo revistar algum lugar, a revista volta para a lista.
   - Se o fugitivo entra num esconderijo na frente dele ("I saw you go in there!"), ele vai lá e
     abre, com chance 1.
   - Se perde de vista por `LOSE_TIME` (4 s), desiste e volta para as tarefas.
2. **Perto o bastante** (`STRIKE_RANGE`): dá a cacetada (`STRIKE`, "WHACK!"). O jogador cai com
   as estrelinhas, como na frigideira (`take_bonk`), e larga o que segurava.
3. **Algema** (`CUFF_TIME`): "You're under arrest!". O jogador fica caído, com algemas de aço nos
   pulsos (`player.set_arrest("cuffed")`).
4. **Arrasta pela gola** até a escada (`DRAG`). Os quadris e o peito do preso são puxados para
   trás do policial (`drag_targets`), e o resto do corpo vem pendurado. Em primeira pessoa, a
   câmera vai junto com a cabeça.
5. **Na escada** (`police.jail`), o preso fica esperando a batida acabar (`"jailed"`). O corpo
   some, não tem controle, e a câmera mostra o corredor de longe com "ARRESTED".

Só um policial pega cada jogador (`police.claimed`). O outro continua revistando.

### A frigideira no policial

Dá para bater nele (`take_bonk`, o mesmo da frigideira). Ele desmaia por `KO_TIME` (8 s), com as
estrelinhas, e larga quem estava arrastando: a algema solta e o preso levanta ("FREE!"). Ao
acordar, ele volta para as tarefas e, se vir alguém, corre atrás de novo.

## O fim

Quando os dois terminam as tarefas (ou passa `RAID_MAX`, 150 s):

1. Levam o que sobrou à vista (`seize_visible`), até na mão de quem não está escondido, e o que
   estiver na guilhotina, na máquina de lavar e na contadora (`confiscate()` de cada uma).
2. Vão embora pela escada.
3. O caixa paga `FINE` ($100) se acharam alguma prova, mais `BAIL` ($50) por preso, ou o que
   tiver no caixa.
4. Os presos voltam no corredor, na frente da 301 (`RELEASE`).
5. O HUD mostra o que levaram, quantos foram presos e o total pago.

Enquanto a polícia está a caminho ou dentro, a paciência do vizinho não sobe.

## Esconder-se

`hideout.gd`. [E] na zona entra, e [E] de novo sai pela frente. Lá dentro o jogador não anda: só
vira a cabeça um pouco (`HIDE_LOOK`), e o olho fica na fresta (`peek`).

| Esconderijo | Cabe | Fica à vista | A vista (HUD) |
|---|---|---|---|
| Guarda-roupa (porta da direita) | 1 | não | fresta vertical da porta |
| Box do banheiro (atrás da cortina) | 2 | não | cortina azulada |
| Dentro do sofá-cama | 1 | não | vão rente ao chão |
| Parapeito da janela (lá fora) | 1 | sim, em pé | a rua |
| Atrás do lixo do 302 (corredor) | 2 | sim, agachado | normal |

- Nos lugares fechados, o boneco e o nome somem para todos.
- Os expostos deixam o boneco à vista, mas os policiais só acham quem está ali se revistarem o
  lugar.
- Escondido, o corpo não tem colisão e não entra no empurra-empurra.
- O host decide quem está dentro (`occupants`) e repassa para todos.

O parapeito é uma laje de concreto do lado de fora da janela principal, embaixo do peitoril
(`kitnet._add_ledge`).

Fugir também vale. O corredor vai até o 302, e os policiais vêm da escada, do outro lado.

## Rede

O host decide tudo:

- **Policiais:** 15 vezes por segundo (`cop._sync`), o host manda a posição, o giro, o estado, a
  pose dos braços, quem cada um arrasta e quem persegue. Vão como eventos (`_event`): as falas
  (balão), o golpe, a pancada, a porta arrombada, o desmaio e o acordar.
- **Presos:** `player.set_arrest` vale em todas as máquinas. Cada máquina simula o próprio ragdoll
  do preso e puxa igual, pela posição do policial.
- **Esconderijos:** `hideout._sync` repassa a lista de quem está dentro, e cada jogador trava ou
  solta o próprio corpo.

## Teste

`_test_raid` em `tools/tests/test_kitnet.gd`. Com `police.search_chance`, toda revista usa uma
chance fixa:

- Com 0, ninguém acha quem está no guarda-roupa nem o dinheiro na geladeira, e as notas da mesa
  vão embora.
- Com 1, acham o jogador e ele é algemado e arrastado. A frigideira no policial solta o preso.
  Depois ele é preso de novo, espera na escada e volta no corredor. A geladeira perde o maço
  solto e fica com o saco fechado.

## Ainda falta

- Cada policial com um jeito diferente de procurar (um mais desconfiado, um mais preguiçoso).
- Esconder o vizinho desmaiado antes de a polícia chegar.
- Um policial de olho na porta enquanto o outro revista (hoje os dois revistam).
