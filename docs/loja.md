# Loja: o PC, o dinheiro e as entregas

O grupo começa no amador: impressora de escritório, cartucho de jato de tinta e papel A4 comum.
O papel e a tinta se compram pela internet, no PC velho da escrivaninha, com o dinheiro do grupo.
A compra chega numa caixa que o entregador deixa na porta.

Por enquanto o dinheiro só sai: vender as notas falsas vem depois.

## Dinheiro (`scripts/wallet.gd`)

Um caixa só para o grupo (nó `Wallet` do mapa, `kitnet.wallet`). O host manda e repassa para todos.

- Começa com as economias (`START_CASH`, $150).
- O HUD mostra o saldo no canto de cima, à direita.
- `spend(valor)` paga se tiver o dinheiro; `earn(valor)` é para quando tiver venda.

## O PC (`MACHINE_PC`)

Monitor CRT bege de 14", teclado e mouse na ponta esquerda da escrivaninha da impressora (o
gabinete fica embaixo). O modelo fica em `art_source/blender/machines.py` (`computer`), com as
medidas que o Godot também usa (`PC_SCREEN`, `PC_MOUSE`).

Peças que o Godot usa, filhas de `MACHINE_PC`:

- `MACHINE_PC_Screen`: a tela, um quadrilátero com UV de 0 a 1. O Godot desenha o navegador nela.
- `MACHINE_PC_Mouse`: o mouse, que anda na mesa junto com o cursor.

O código é `scripts/machines/computer.gd`.

- **[E] de mão vazia:** usa o PC, só um por vez. Os outros veem "Ana is using the computer".
- **Câmera:** vai para a frente da tela (`VIEW_FROM`, `VIEW_FOV`), do mesmo jeito que na guilhotina
  (`player._station_cam`).
- **Mãos:** a luva esquerda fica no teclado e a direita no mouse (`hand_transform`). O braço do
  boneco vai até elas pelo IK, e os outros também veem.
- **Mouse:** anda com o cursor na tela (`CURSOR_SPEED`); o clique aperta o que estiver embaixo.
- **[E]:** sai. Cair (trombada) também tira do PC.

O `player.gd` repassa o mouse e o clique para qualquer estação com `station_input(event)`, e
`station_hint()` dá a dica de controles.

### A tela

A tela é um `SubViewport` de 640 x 480 com o navegador (`scripts/shop/browser.gd`). A textura vai
para o monitor pelo `shaders/crt.gdshader`, com vidro abaulado, linhas de varredura e cantos mais
escuros.

O navegador é o "WebSurfer 98":

- barra de título, os favoritos (as lojas e o carrinho), o saldo e o endereço;
- a página e a barra de status, que mostra os avisos e a contagem das entregas.

Os botões são desenhados à mão: retângulos com relevo, com a ação no meta `action`.
`action_at(ponto)` diz qual botão está embaixo do ponto. Um botão apagado (`enabled` falso) não
responde.

| Ação | O que faz |
|---|---|
| `go:office`, `go:ink`, `go:cart` | Abre a loja ou o carrinho. |
| `add:<produto>` | Põe um no carrinho (até `MAX_PER_PRODUCT`). |
| `inc:<produto>`, `dec:<produto>` | Mais um ou menos um, no carrinho. |
| `checkout` | Paga e faz o pedido. Apagado se o dinheiro não dá. |

### Rede

O host guarda o estado e repassa para todos: quem usa, a página, o carrinho, o aviso e os
últimos pedidos (`_sync`).

- Quem usa mexe o cursor na hora e manda a posição para os outros, 30 vezes por segundo
  (`_remote_cursor`). Todo mundo vê a mesma tela, com o cursor andando: dá para palpitar por cima
  do ombro.
- O clique vai para o host com a posição (`_rpc_click`). O host confere quem clicou e decide o
  que foi apertado.
- O estalo do clique toca para todos.

## Catálogo (`scripts/shop/catalog.gd`)

| Loja | Produto | Preço | Vira |
|---|---|---|---|
| OFFICE+ | A4 copy paper | $9 | `ream` |
| OFFICE+ | Cotton paper | esgotado | (mostra que tem coisa melhor vindo) |
| INK-O-RAMA | Compatible ink cartridge | $19 | `cartridge`, `brand: generic` |
| INK-O-RAMA | Original ink cartridge | $49 | `cartridge`, `brand: original` |

- Cada loja do pedido cobra o frete dela (`SHIPPING`, $5) e manda a sua caixa.
- O `blurb` de cada produto já vem quebrado em linhas, porque o cartão do produto é estreito.

## Entregas (`scripts/shop/deliveries.gd`)

Nó `Deliveries` do mapa (`kitnet.deliveries`).

1. O pedido chega `DELIVERY_SECONDS` (30 s) depois de pago.
2. A caixa (`parcel`) aparece no chão do corredor, na frente da 301 (`POINT_Knock`). Caixas que
   chegam juntas ficam lado a lado.
3. A campainha toca: "ding-dong", feita no próprio código. Todo mundo vê "Ding-dong! A parcel
   from OFFICE+ is at the door."
4. Alguém tem que abrir a porta e ir buscar.

O host conta o tempo. Os outros recebem a lista do que está a caminho (`on_the_way`) e contam
sozinhos, para a barra de status do navegador.

A caixa não vai para a mão (`ItemKinds.NOT_CARRIED`): [E] abre ali mesmo (`items.request_open`).
O que veio dentro sai pulando e a caixa some. Ela tem o nome da loja escrito dos dois lados e
pode ser chutada.

## Teste

O `tools/tests/test_kitnet.gd` (`_test_shop`) passa pelo caminho inteiro, com o mouse de verdade:

1. Usa o PC e confere a câmera na tela, a luva no mouse e o mouse andando.
2. Compra 2 resmas e 1 cartucho genérico, e confere o total com os dois fretes.
3. Confere que o pedido caro demais não passa.
4. Paga, e confere que as duas caixas chegam na porta com a campainha.
5. Abre as caixas, guarda uma resma no estoque e troca o cartucho.
6. Imprime com o genérico, e confere a folha e as notas com a cor errada.
7. Confere o aviso de sem cartucho.
