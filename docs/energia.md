# A luz

A kitnet tem um disjuntor só. Muita máquina ligada ao mesmo tempo derruba a luz.

Código:

- `scripts/power.gd`: o quadro de luz, o consumo e o disjuntor.
- `scripts/ambience.gd`: as luzes da kitnet tremendo e apagando.
- Cada aparelho: `power_draw()` e, se precisar, `power_lost()`.

Os textos do jogo ficam em inglês.

## O consumo

O consumo agora é `BASE_WATTS` mais o `power_draw()` de cada nó do grupo "powered":

| O que | Consumo |
|---|---|
| Base: geladeira, as quatro luzes e a TV | 400 W, sempre |
| PC (`computer.gd`, `WATTS`) | 120 W, sempre |
| Impressora (`printer_stats.gd`, `power_watts`) | 300 W imprimindo; ligada à toa, 15% disso (`IDLE_POWER`) |
| Ventilador (`fan.gd`, `WATTS`) | 80 W ligado |
| Máquina de lavar (`washer.gd`) | 500 W lavando (`WASH_WATTS`), 1150 W centrifugando (`SPIN_WATTS`) |
| Contadora (`cash_counter.gd`, `WATTS`) | 150 W contando |

O disjuntor aguenta `LIMIT_WATTS` (2000 W). A centrifugação é o que mais pesa: centrifugando com a
impressora imprimindo dá 1970 W, e com o ventilador também passa do limite. A impressora melhor,
que vem com os upgrades, gasta mais.

## O disjuntor

Acima do limite, o disjuntor esquenta (`heat`):

- as luzes da kitnet tremem (`power.light_level`);
- o quadro zumbe e a alavanca vermelha treme;
- o HUD avisa uma vez: "The lights are flickering: too much is running at once!".

Abaixo do limite, ele esfria (`COOL_RATE`). Com `TRIP_SECONDS` (3 s) de sobrecarga, ele cai, com um
estalo. Sem luz:

| O que | Sem luz | Quando a luz volta |
|---|---|---|
| Luzes da kitnet (lâmpada, cozinha, banheiro, serviço) e TV | Apagam | Acendem |
| Luzes do corredor | Ficam acesas: são do prédio | |
| Impressora | Desliga de vez e perde o aquecimento. A folha pela metade volta. Não liga sem luz. | Continua desligada: alguém tem que ligar de novo |
| Ventilador | Para, mas o botão continua ligado | Volta a girar sozinho |
| Máquina de lavar | Para no meio do ciclo, com a tampa travada | Continua de onde parou |
| Contadora | Para | Continua |
| PC | A tela apaga e quem estava usando sai | Volta |

O quadro de luz fica na parede da porta, do lado de dentro (`KEEP_Breaker` do modelo). A alavanca
vermelha do disjuntor geral é feita no código: em cima ligado, embaixo desligado.

- Desligado: [E] religa. Se a sobrecarga continuar ligada, ele cai de novo depois de 3 s; tem que
  desligar alguma coisa antes.
- Ligado: [E] desliga a luz de propósito. O prompt mostra quanto está sendo usado ("1.4 of 2.0 kW
  in use").

## Rede

O host decide tudo:

- O host calcula o consumo e a sobrecarga e manda 10 vezes por segundo (`power._meter`).
- O disjuntor caindo, religando ou sendo desligado vai na hora (`power._state`), com o aviso no HUD.
- Cada máquina consulta `kitnet.has_power()` para parar, apagar o visor e os sons.

## Teste

`_test_power` em `tools/tests/test_kitnet.gd`:

1. Cada aparelho soma no consumo.
2. Um aparelho falso passa do limite: as luzes tremem e o disjuntor cai. Apaga a kitnet e não o
   corredor, a impressora desliga e não liga, o ventilador e a máquina de lavar param.
3. Religa com o excesso: cai de novo. Sem ele: a luz volta, a máquina de lavar continua e o
   ventilador volta.
4. [E] no quadro desliga a luz, e de novo liga.

## Ainda falta

- Aluguel e conta de luz (tirados por enquanto: sem venda de notas, o dinheiro só sairia).
