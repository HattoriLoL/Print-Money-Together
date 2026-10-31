"""As estações da linha de produção, na ordem em que o dinheiro passa por elas:

    SUPPLY_Paper -> MACHINE_Printer (com tinta da MACHINE_InkPot) -> MACHINE_ClothesLine + MACHINE_Fan
    (secar) -> MACHINE_Guillotine (cortar) -> MACHINE_Washer (envelhecer) -> MACHINE_CashCounter
    (contar e cintar) -> esconderijos HIDE_*

Peças que mexem no jogo são objetos filhos com a origem no eixo: MACHINE_Guillotine_Arm,
MACHINE_Washer_Lid e MACHINE_Fan_Blades."""

import math

from mathutils import Matrix, Vector

import plan as P
from lib import Part, decal, digits, facing


def build(colls):
    c = colls["machines"]
    printer(c)
    computer(c)
    paper_supply(c)
    ink(c)
    guillotine(c)
    cash_counter(c)
    washer(c)
    clothesline(c)
    fan(c)


# Impressora de escritório velha em cima da escrivaninha (furniture.printer_desk).
# No vão da cortina aberta, bem para trás na mesa (a bandeja de saída passa 12 cm da borda).
PRINTER_LOC = (2.3, 4.72, 0.75)
# Alimentador de trás: borda de baixo e inclinação para trás (rad).
FEEDER_BASE = (0.0, 0.12, 0.2)
FEEDER_TILT = -0.35
# Botão de liga/desliga e os LEDs no painel de cima.
PRINTER_BUTTON = (0.19, -0.072, 0.204)
PRINTER_LEDS = {"Ready": ((0.15, -0.1, 0.204), "M_LedGreen"),
                "Attention": ((0.172, -0.1, 0.204), "M_LedAmber")}


def printer(coll):
    """Impressora de escritório bege dos anos 90, amarelada pelo sol, em cima da escrivaninha.
    Papel entra pelo alimentador inclinado de trás; a folha sai pela fenda da frente e cai na
    bandeja de saída (as folhas são objetos do jogo, não do modelo).

    Peças que o Godot mexe, filhas da impressora: MACHINE_Printer_Button (liga/desliga, afunda
    quando aperta), MACHINE_Printer_LedReady e _LedAttention (acendem e apagam) e
    MACHINE_Printer_Paper (a pilha no alimentador, some quando acaba o papel)."""
    beige, dark = "M_OldPlastic", "M_OldPlasticDark"
    p = Part(bevel=0.004)
    # Pés de borracha, saia escura e os dois blocos do corpo.
    for fx in (-0.19, 0.19):
        for fy in (-0.14, 0.14):
            p.cyl((fx, fy, 0.004), 0.008, 0.016, "M_Rubber", seg=12)
    p.box(-0.225, -0.175, 0.006, 0.225, 0.175, 0.024, dark, bevel=0.006)
    p.box(-0.23, -0.18, 0.02, 0.23, 0.18, 0.115, beige, bevel=0.012)
    p.box(-0.23, -0.13, 0.11, 0.23, 0.18, 0.2, beige, bevel=0.015)
    # Frente inclinada entre os dois blocos, com a fenda de saída do papel embaixo dela.
    m = Matrix.Translation((0, -0.153, 0.157)) @ Matrix.Rotation(-0.53, 4, "X")
    p.box_m((0.46, 0.03, 0.1), m, beige, bevel=0.01)
    p.box(-0.16, -0.186, 0.11, 0.16, -0.17, 0.123, "M_Void", bevel=0)
    for x in (-0.16, 0.16):
        p.box(x - 0.006, -0.188, 0.106, x + 0.006, -0.17, 0.127, dark, bevel=0.002)
    # Emenda da tampa em cima e dos lados, e o rebaixo para o dedo abrir a tampa.
    p.box(-0.226, 0.03, 0.2, 0.226, 0.034, 0.2014, dark, bevel=0)
    for x in (-0.2312, 0.2302):
        p.box(x, 0.03, 0.115, x + 0.001, 0.034, 0.198, dark, bevel=0)
    p.box(-0.06, -0.127, 0.198, 0.06, -0.112, 0.2012, dark, bevel=0.002)
    # Grade de ventilação em cima (atrás, à esquerda) e dos dois lados.
    for i in range(9):
        x = -0.205 + i * 0.016
        p.box(x, 0.06, 0.2, x + 0.008, 0.15, 0.2013, dark, bevel=0)
    for x in (-0.2312, 0.2302):
        for i in range(6):
            z = 0.035 + i * 0.012
            p.box(x, -0.12, z, x + 0.001, 0.12, z + 0.005, dark, bevel=0)
    # Gaveta de papel na frente de baixo, com rebaixo para a mão, e a plaquinha do modelo.
    p.box(-0.2, -0.184, 0.026, 0.2, -0.178, 0.064, beige, bevel=0.003)
    p.box(-0.06, -0.1852, 0.036, 0.06, -0.1838, 0.05, dark, bevel=0.002)
    p.box(-0.215, -0.1832, 0.07, -0.13, -0.18, 0.096, dark, bevel=0.002)
    digits(p, "600", -0.1725, 0.075, 0.015, -0.1832, "M_Metal", depth=0.0008)
    # Painel de comando em cima, na frente à direita: visor, três botões, LEDs e a moldura do
    # botão de liga/desliga (o botão e os LEDs são peças à parte).
    p.box(0.02, -0.125, 0.199, 0.215, -0.045, 0.204, dark, bevel=0.003)
    p.box(0.035, -0.116, 0.204, 0.13, -0.084, 0.2056, "M_PlasticBlack", bevel=0.001)
    p.box(0.04, -0.112, 0.2056, 0.125, -0.088, 0.2062, "M_Screen", bevel=0)
    for i in range(3):
        x = 0.05 + i * 0.03
        p.box(x - 0.011, -0.07, 0.204, x + 0.011, -0.057, 0.2085, "M_OldPlastic", bevel=0.002)
        p.box(x - 0.004, -0.0645, 0.2085, x + 0.004, -0.0625, 0.2088, "M_PlasticBlack", bevel=0)
    for (pos, _mat) in PRINTER_LEDS.values():
        p.cyl((pos[0], pos[1], pos[2] + 0.0005), 0.002, 0.0065, "M_PlasticBlack", seg=14)
    bx, by, bz = PRINTER_BUTTON
    p.cyl((bx, by, bz + 0.0015), 0.004, 0.018, "M_PlasticBlack", seg=24)
    # Alimentador de trás: chapa inclinada, guias do papel, haste de extensão e a fenda.
    feed = Matrix.Translation(FEEDER_BASE) @ Matrix.Rotation(FEEDER_TILT, 4, "X")
    p.box_m((0.24, 0.006, 0.26), feed @ Matrix.Translation((0, 0.004, 0.13)), dark, bevel=0.003)
    for x in (-0.112, 0.112):
        p.box_m((0.012, 0.03, 0.05), feed @ Matrix.Translation((x, -0.012, 0.04)), beige, bevel=0.003)
    for x in (-0.08, 0.08):
        p.cyl((0, 0, 0), 0.12, 0.002, "M_Metal", seg=6,
              matrix=feed @ Matrix.Translation((x, 0.002, 0.31)))
    p.cyl((0, 0, 0), 0.16, 0.002, "M_Metal", axis="X", seg=6, matrix=feed @ Matrix.Translation((0, 0.002, 0.37)))
    p.box(-0.125, 0.095, 0.2, 0.125, 0.125, 0.2013, "M_Void", bevel=0)
    # Bandeja de saída puxada para fora na frente, com trilhos e a aba de parada.
    p.box(-0.13, -0.42, 0.05, 0.13, -0.17, 0.058, dark, bevel=0.003)
    for x in (-0.13, 0.12):
        p.box(x, -0.42, 0.054, x + 0.01, -0.17, 0.07, dark, bevel=0.003)
    p.box(-0.1, -0.426, 0.054, 0.1, -0.418, 0.086, dark, bevel=0.003)
    # Atrás: conector do cabo paralelo com parafusos e a entrada da força.
    p.box(-0.12, 0.178, 0.055, -0.05, 0.19, 0.085, "M_Metal", bevel=0.002)
    for x in (-0.115, -0.055):
        p.cyl((x, 0.192, 0.07), 0.006, 0.004, "M_Metal", axis="Y", seg=8)
    p.box(0.12, 0.178, 0.05, 0.17, 0.186, 0.08, "M_PlasticBlack", bevel=0.003)
    # Adesivo de aviso, etiqueta de patrimônio, bilhete amarelo e marca de caneca na tampa.
    p.quad(((-0.205, -0.105, 0.2016), (-0.125, -0.105, 0.2016), (-0.125, -0.065, 0.2016), (-0.205, -0.065, 0.2016)),
           "M_StickerWarning", double=False)
    p.quad(((0.2316, -0.09, 0.13), (0.2316, 0.01, 0.13), (0.2316, 0.01, 0.18), (0.2316, -0.09, 0.18)),
           "M_StickerLabel", double=False)
    # Bilhete colado na frente inclinada (mesmo giro dela), um pouco torto.
    note = Matrix.Translation((-0.06, -0.153, 0.162)) @ Matrix.Rotation(-0.53, 4, "X") @ Matrix.Rotation(0.12, 4, "Y")
    p.box_m((0.06, 0.0015, 0.06), note @ Matrix.Translation((0, -0.0158, 0)), "M_Yellow", bevel=0)
    for i in range(3):
        p.box_m((0.04 - i * 0.009, 0.0005, 0.003), note @ Matrix.Translation((-0.004, -0.0168, 0.015 - i * 0.013)),
                "M_InkBlack", bevel=0)
    # Silver tape: a impressora só fecha à base de fita. Uma tira larga em volta da tampa (em cima e
    # descendo nos dois lados), duas em X na frente inclinada e uma remendando a bandeja.
    t = 0.0016
    p.box(-0.2315, -0.012, 0.2, 0.2315, 0.062, 0.2 + t, "M_SilverTape", bevel=0)
    for sx in (-1, 1):
        x0 = sx * 0.23
        p.box(min(x0, x0 + sx * t), -0.012, 0.118, max(x0, x0 + sx * t), 0.062, 0.2 + t, "M_SilverTape", bevel=0)
    for ang in (0.7, -0.7):
        m = Matrix.Translation((0.0, -0.1532, 0.157)) @ Matrix.Rotation(-0.53, 4, "X") @ Matrix.Rotation(ang, 4, "Y")
        p.box_m((0.2, 0.0035, 0.034), m @ Matrix.Translation((0, -0.0168, 0)), "M_SilverTape", bevel=0)
    m = Matrix.Translation((0.0, -0.3, 0.0598)) @ Matrix.Rotation(0.5, 4, "Z")
    p.box_m((0.22, 0.03, 0.0035), m, "M_SilverTape", bevel=0)
    # Pontas soltas e dobradas da fita da tampa.
    for sx in (-1, 1):
        m = Matrix.Translation((sx * 0.165, -0.026, 0.2 + t)) @ Matrix.Rotation(sx * 0.35, 4, "Z")
        p.box_m((0.05, 0.03, 0.0035), m, "M_SilverTape", bevel=0)
    decal(p, (0.175, 0.075, 0.2016), "+z", 0.08, 0.08, "M_DecalWater")
    base = p.finish("MACHINE_Printer", coll, loc=PRINTER_LOC, rot_z=facing("-y"))

    # Botão de liga/desliga com o símbolo de energia.
    b = Part(bevel=0.002)
    b.cyl((0, 0, 0.004), 0.008, 0.013, "M_OldPlastic", seg=24)
    b.cyl((0, 0, 0.0082), 0.0005, 0.008, "M_PlasticBlack", seg=20)
    b.cyl((0, 0, 0.0084), 0.0006, 0.0062, "M_OldPlastic", seg=20)
    b.box(-0.0012, 0.0, 0.0081, 0.0012, 0.009, 0.0091, "M_PlasticBlack", bevel=0)
    b.finish("MACHINE_Printer_Button", coll, loc=PRINTER_BUTTON, parent=base)
    for name, (pos, mat) in PRINTER_LEDS.items():
        led = Part()
        led.cyl((0, 0, 0.0025), 0.003, 0.004, mat, seg=12)
        led.finish(f"MACHINE_Printer_Led{name}", coll, loc=pos, parent=base)

    # Pilha de papel no alimentador (A4 em pé, encostada na chapa).
    s = Part(bevel=0.002)
    s.box_m((0.21, 0.02, 0.24), Matrix.Rotation(FEEDER_TILT, 4, "X") @ Matrix.Translation((0, -0.009, 0.135)), "M_Paper")
    s.finish("MACHINE_Printer_Paper", coll, loc=FEEDER_BASE, parent=base)


# PC velho na ponta esquerda da escrivaninha da impressora (o gabinete fica embaixo, ver
# furniture.pc): monitor CRT bege de 14", teclado e mouse. É por ele que o grupo compra papel e
# tinta pela internet (scripts/machines/computer.gd).
PC_LOC = (1.8, 4.78, 0.75)
# Tela do monitor (quadrilátero com UV 0-1, onde o Godot desenha o navegador), no referencial do
# PC: x de um lado a outro, z de baixo a cima, na face da frente (y).
PC_SCREEN = (-0.135, 0.135, 0.112, 0.3145, -0.1875)
# Mouse em cima do mouse pad (o Godot anda com ele junto com o cursor).
PC_MOUSE = (0.23, -0.29, 0.004)


def computer(coll):
    """Monitor CRT bege amarelado com base giratória, moldura funda e a "corcunda" atrás, um
    bilhete amarelo na moldura, teclado com as teclas em relevo, mouse pad e o cabo do mouse.

    Peças que o Godot usa, filhas do MACHINE_PC (a origem fica no tampo, embaixo do monitor):
    MACHINE_PC_Screen (a tela, com UV 0-1, material M_PCScreen) e MACHINE_PC_Mouse (o mouse,
    com a origem embaixo dele)."""
    beige, dark = "M_OldPlastic", "M_OldPlasticDark"
    p = Part(bevel=0.004)
    # Base giratória e o pescoço.
    p.box(-0.12, -0.13, 0.0, 0.12, 0.09, 0.02, beige, bevel=0.012)
    p.box(-0.07, -0.08, 0.018, 0.07, 0.05, 0.05, beige, bevel=0.015)
    # Caixa da frente (bem arredondada, de desenho) e a corcunda do tubo atrás.
    p.box(-0.18, -0.18, 0.045, 0.18, -0.01, 0.385, beige, bevel=0.03)
    p.box(-0.145, -0.03, 0.075, 0.145, 0.17, 0.35, beige, bevel=0.05)
    p.box(-0.09, 0.15, 0.12, 0.09, 0.19, 0.3, beige, bevel=0.03)
    # Moldura funda em volta da tela e a borda escura do vidro.
    x0, x1, z0, z1, sy = PC_SCREEN
    p.box(x0 - 0.02, -0.186, z0 - 0.02, x1 + 0.02, -0.17, z1 + 0.02, dark, bevel=0.012)
    # Grade de ventilação em cima e nos lados da corcunda.
    for i in range(8):
        x = -0.11 + i * 0.03
        p.box(x, 0.0, 0.3495, x + 0.014, 0.12, 0.3515, dark, bevel=0)
    for sx in (-1, 1):
        for i in range(5):
            z = 0.15 + i * 0.03
            p.box(sx * 0.146 - 0.001, 0.02, z, sx * 0.146 + 0.001, 0.13, z + 0.012, dark, bevel=0)
    # Botão de força com o LED e os botõezinhos de ajuste embaixo da tela, e a plaquinha da marca.
    p.cyl((0.135, -0.186, 0.072), 0.01, 0.012, dark, axis="Y", seg=20)
    p.cyl((0.105, -0.186, 0.072), 0.008, 0.004, "M_LedGreen", axis="Y", seg=10)
    for i in range(4):
        p.box(0.02 + i * 0.018, -0.187, 0.066, 0.032 + i * 0.018, -0.18, 0.078, dark, bevel=0.002)
    p.box(-0.06, -0.1865, 0.064, -0.0, -0.18, 0.08, dark, bevel=0.002)
    # Bilhete amarelo colado no canto da moldura, meio torto (a senha do Wi-Fi, claro).
    note = Matrix.Translation((-0.15, -0.1885, 0.352)) @ Matrix.Rotation(0.2, 4, "Y")
    p.box_m((0.06, 0.0015, 0.06), note, "M_Yellow", bevel=0)
    for i in range(3):
        p.box_m((0.042 - i * 0.01, 0.0005, 0.003), note @ Matrix.Translation((-0.003, -0.001, 0.014 - i * 0.012)),
                "M_InkBlack", bevel=0)

    # Teclado: corpo inclinado (mais alto atrás), as teclas em relevo e a barra de espaço.
    kx, ky = -0.02, -0.265
    kb = Matrix.Translation((kx, ky, 0.0)) @ Matrix.Rotation(0.06, 4, "X")
    p.box_m((0.33, 0.14, 0.022), kb @ Matrix.Translation((0, 0, 0.016)), beige, bevel=0.006)
    for row in range(4):
        y = -0.045 + row * 0.026
        for col in range(12):
            x = -0.143 + col * 0.026
            p.box_m((0.021, 0.021, 0.008), kb @ Matrix.Translation((x, -y, 0.03)), beige, bevel=0.003)
    p.box_m((0.13, 0.021, 0.008), kb @ Matrix.Translation((-0.01, -0.058, 0.03)), beige, bevel=0.003)
    # Fio do teclado até atrás do monitor.
    p.box(kx - 0.003, -0.195, 0.0, kx + 0.003, -0.13, 0.005, "M_Cable", bevel=0.002)
    # Mouse pad e o fio do mouse até atrás do monitor, passando do lado dele.
    mx, my, _mz = PC_MOUSE
    p.box(mx - 0.075, my - 0.065, 0.0, mx + 0.075, my + 0.065, 0.004, "M_PlasticBlue", bevel=0.003)
    p.box(mx - 0.003, my + 0.05, 0.004, mx + 0.003, my + 0.065, 0.008, "M_Cable", bevel=0.002)
    p.box(mx - 0.003, my + 0.065, 0.0, mx + 0.003, 0.15, 0.005, "M_Cable", bevel=0.002)
    base = p.finish("MACHINE_PC", coll, loc=PC_LOC, rot_z=facing("-y"))

    # A tela: um quadrilátero só, de frente (-Y), com o UV inteiro (o Godot desenha nele).
    s = Part()
    s.quad(((x0, sy, z0), (x1, sy, z0), (x1, sy, z1), (x0, sy, z1)), "M_PCScreen", double=False)
    s.finish("MACHINE_PC_Screen", coll, parent=base)

    # Mouse de bolinha: corpo arredondado, os dois botões e a emenda.
    m = Part(bevel=0.004)
    m.box(-0.03, -0.05, 0.0, 0.03, 0.05, 0.03, beige, bevel=0.014)
    m.box(-0.0015, -0.051, 0.018, 0.0015, -0.01, 0.0305, dark, bevel=0)
    m.box(-0.029, -0.012, 0.024, 0.029, -0.009, 0.0302, dark, bevel=0)
    m.finish("MACHINE_PC_Mouse", coll, loc=PC_MOUSE, parent=base)


def _ream(p, x, y, z, rot=0.0):
    m = Matrix.Translation((x, y, z + 0.026)) @ Matrix.Rotation(rot, 4, "Z")
    p.box_m((0.3, 0.21, 0.052), m, "M_Paper")
    p.box_m((0.12, 0.215, 0.054), m, "M_PlasticBlue")


def paper_supply(coll):
    """Caixas de resma ao lado da impressora."""
    p = Part(bevel=0.004)
    p.box(-0.3, -0.24, 0, 0.3, 0.24, 0.3, "M_Cardboard")
    m = Matrix.Translation((0.0, 0.0, 0.45)) @ Matrix.Rotation(0.12, 4, "Z")
    p.box_m((0.58, 0.44, 0.3), m, "M_Cardboard")
    p.box(-0.3, -0.24, 0.6, 0.3, 0.24, 0.62, "M_Cardboard")
    _ream(p, -0.1, -0.02, 0.62, 0.1)
    _ream(p, -0.08, 0.0, 0.672, -0.05)
    _ream(p, 0.12, 0.05, 0.62, 1.4)
    p.finish("SUPPLY_Paper", coll, loc=(3.68, 4.7, 0))


def _jug(p, x, y, label):
    p.box(x - 0.07, y - 0.055, 0.9, x + 0.07, y + 0.055, 1.14, "M_PlasticWhite")
    p.box(x - 0.072, y - 0.057, 0.95, x + 0.072, y + 0.057, 1.07, label)
    p.cyl((x - 0.03, y, 1.16), 0.04, 0.022, label, seg=10)
    p.box(x + 0.01, y - 0.012, 1.14, x + 0.06, y + 0.012, 1.2, "M_PlasticWhite")


def ink(coll):
    """Panela de tinta fervendo no cooktop e os galões de tinta na bancada."""
    p = Part(bevel=0.004)
    p.cyl((0, 0, 0.065), 0.13, 0.12, "M_MetalDark", seg=20)
    p.cyl((0, 0, 0.12), 0.02, 0.112, "M_InkHot", seg=20)
    p.box(0.11, -0.012, 0.1, 0.32, 0.012, 0.12, "M_PlasticBlack")
    for bx, by, r in ((0.03, 0.02, 0.018), (-0.05, -0.03, 0.012), (0.0, -0.06, 0.009), (-0.04, 0.05, 0.014)):
        p.cyl((bx, by, 0.131), 0.012, r, "M_InkHot", seg=8)
    m = Matrix.Translation((-0.02, 0.04, 0.2)) @ Matrix.Rotation(0.5, 4, "Y")
    p.box_m((0.02, 0.02, 0.3), m, "M_Wood")  # colher de pau
    p.finish("MACHINE_InkPot", coll, loc=(2.45, 0.24, 0.925))

    p = Part(bevel=0.004)
    _jug(p, 1.76, 0.3, "M_InkGreen")
    _jug(p, 1.92, 0.22, "M_InkBlack")
    _jug(p, 2.1, 0.32, "M_InkGold")
    p.cyl((1.95, 0.45, 0.94), 0.08, 0.05, "M_Red", seg=12, radius2=0.01)
    p.finish("SUPPLY_Ink", coll)


# Guilhotina na mesa do meio. O Godot (scripts/machines/guillotine.gd) usa as mesmas medidas.
GUILLOTINE_LOC = (2.35, 2.08, 0.76)
GUILLOTINE_CUT_Y = -0.1                   # linha da lâmina, no y local (frente = -Y)
GUILLOTINE_HINGE = (-0.235, -0.1, 0.062)  # pivô da alavanca (gira no Y local)
GUILLOTINE_OPEN = math.radians(50)        # alavanca levantada


def guillotine(coll):
    """Guilhotina de papel de mesa, de alavanca. O papel encosta no esquadro da esquerda; a
    lâmina desce na linha de corte da frente. Peça que o Godot mexe: MACHINE_Guillotine_Arm
    (origem no pivô, a ponta sobe girando no Y local)."""
    cy = GUILLOTINE_CUT_Y
    p = Part(bevel=0.004)
    hx, hy = 0.25, 0.2
    for fx in (-0.22, 0.22):
        for fy in (-0.17, 0.17):
            p.cyl((fx, fy, 0.003), 0.006, 0.015, "M_Rubber", seg=12)
    p.box(-hx, -hy, 0.006, hx, hy, 0.03, "M_DeskMetal", bevel=0.006)
    p.quad(((-0.24, -0.19, 0.0302), (0.24, -0.19, 0.0302), (0.24, 0.19, 0.0302), (-0.24, 0.19, 0.0302)),
           "M_CuttingMat", double=False)
    # Contra-lâmina de aço na linha de corte.
    p.box(-0.245, cy - 0.006, 0.0295, 0.245, cy + 0.004, 0.0335, "M_Metal", bevel=0.001)
    # Esquadro à esquerda e régua de metal atrás, com as marcas de centímetro.
    p.box(-0.247, cy + 0.006, 0.03, -0.233, 0.19, 0.05, "M_Metal", bevel=0.002)
    p.box(-0.233, 0.172, 0.03, 0.245, 0.19, 0.045, "M_Metal", bevel=0.002)
    for i in range(48):
        x = -0.228 + i * 0.01
        length = 0.01 if i % 5 == 0 else 0.005
        p.box(x - 0.0006, 0.19 - length, 0.045, x + 0.0006, 0.19, 0.0453, "M_PlasticBlack", bevel=0)
    # Prensa do papel atrás da lâmina: barra, dois postes e o manípulo.
    p.box(-0.21, cy + 0.018, 0.036, 0.215, cy + 0.034, 0.048, "M_MetalDark", bevel=0.003)
    for x in (-0.215, 0.22):
        p.box(x - 0.008, cy + 0.014, 0.03, x + 0.008, cy + 0.038, 0.07, "M_MetalDark", bevel=0.003)
    p.cyl((0.22, cy + 0.026, 0.074), 0.012, 0.005, "M_Metal", seg=10)
    p.cyl((0.22, cy + 0.026, 0.087), 0.018, 0.018, "M_Red", seg=18)
    # Protetor de dedos de acrílico na frente da lâmina, com os suportes.
    p.box(-0.2, cy - 0.034, 0.036, 0.215, cy - 0.028, 0.075, "M_Glass", bevel=0.001)
    for x in (-0.19, 0.205):
        p.box(x - 0.006, cy - 0.04, 0.03, x + 0.006, cy - 0.022, 0.078, "M_Metal", bevel=0.002)
    # Bloco do pivô, o pino e a mola de torção enrolada atrás dele.
    hx0, _hy0, hz0 = GUILLOTINE_HINGE
    p.box(-0.25, cy - 0.02, 0.03, -0.215, cy + 0.02, 0.09, "M_MetalDark", bevel=0.004)
    p.cyl((hx0, cy, hz0), 0.06, 0.006, "M_Metal", axis="Y", seg=12)
    for i in range(8):
        p.cyl((hx0, cy + 0.024 + i * 0.0035, hz0), 0.0025, 0.013, "M_Metal", axis="Y", seg=14)
    p.box(hx0, cy + 0.03, hz0 - 0.002, hx0 + 0.04, cy + 0.034, hz0 + 0.002, "M_Metal", bevel=0)
    p.quad(((0.06, -hy - 0.0005, 0.01), (0.18, -hy - 0.0005, 0.01), (0.18, -hy - 0.0005, 0.027),
            (0.06, -hy - 0.0005, 0.027)), "M_StickerWarning", double=False)
    base = p.finish("MACHINE_Guillotine", coll, loc=GUILLOTINE_LOC)

    # Alavanca: lâmina parafusada embaixo, braço mais grosso perto do pivô e o pegador vermelho.
    length = 0.5
    a = Part(bevel=0.003)
    a.box(0.0, -0.008, -0.03, length - 0.03, -0.002, -0.004, "M_Metal", bevel=0.0015)
    a.box(0.0, -0.0085, -0.03, length - 0.03, -0.0078, -0.026, "M_MetalDark", bevel=0)
    a.box(-0.02, -0.012, -0.006, length, 0.012, 0.022, "M_MetalDark", bevel=0.006)
    a.box(-0.03, -0.016, -0.02, 0.06, 0.016, 0.03, "M_MetalDark", bevel=0.008)
    for x in (0.08, 0.2, 0.32, 0.42):
        a.cyl((x, -0.0085, -0.017), 0.003, 0.004, "M_Metal", axis="Y", seg=8)
    a.box(length - 0.01, -0.01, -0.002, length + 0.012, 0.01, 0.02, "M_Metal")
    a.cyl((length + 0.07, 0, 0.01), 0.14, 0.018, "M_Red", axis="X", seg=18)
    a.cyl((length + 0.145, 0, 0.01), 0.012, 0.021, "M_Red", axis="X", seg=18)
    a.quad(((0.18, -0.0122, -0.004), (0.3, -0.0122, -0.004), (0.3, -0.0122, 0.02), (0.18, -0.0122, 0.02)),
           "M_StickerWarning", double=False)
    ob = a.finish("MACHINE_Guillotine_Arm", coll, loc=GUILLOTINE_HINGE, parent=base)
    ob.rotation_euler.y = -GUILLOTINE_OPEN


def cash_counter(coll):
    """Contadora de cédulas com o visor marcando 100."""
    p = Part(bevel=0.004)
    p.box(-0.13, -0.12, 0, 0.13, 0.12, 0.13, "M_PlasticWhite", bevel=0.012)
    p.box(-0.13, -0.12, 0, 0.13, 0.12, 0.015, "M_PlasticBlack")
    m = Matrix.Translation((0, 0.06, 0.17)) @ Matrix.Rotation(-0.6, 4, "X")
    p.box_m((0.2, 0.14, 0.01), m, "M_PlasticBlack")            # funil de cima
    p.box(-0.09, -0.2, 0.02, 0.09, -0.12, 0.03, "M_PlasticBlack")  # bandeja da frente
    p.box(-0.08, -0.18, 0.03, 0.08, -0.13, 0.05, "M_Money")
    p.box(-0.1, -0.125, 0.08, 0.03, -0.12, 0.12, "M_PlasticBlack")
    digits(p, "100", -0.035, 0.088, 0.025, -0.125, "M_Screen", depth=0.002)
    for i in range(3):
        p.box(0.05 + i * 0.025, -0.125, 0.09, 0.065 + i * 0.025, -0.115, 0.1, "M_PlasticBlue")
    p.finish("MACHINE_CashCounter", coll, loc=(2.95, 2.15, 0.76), rot_z=facing("+y") - 0.3)


def washer(coll):
    """Máquina de lavar de abertura em cima: as notas saem 'usadas'. A tampa gira no X local."""
    p = Part(bevel=0.004)
    hw, hd, h = 0.31, 0.31, 0.88
    p.box(-hw, -hd, 0.03, hw, hd, h, "M_PlasticWhite", bevel=0.025)
    p.box(-hw + 0.02, -hd + 0.02, 0, hw - 0.02, hd - 0.02, 0.03, "M_Rubber")
    p.box(-hw, -hd - 0.003, 0.05, hw, -hd, 0.1, "M_MetalDark")
    # Painel de trás com botão, visor e LED.
    p.box(-hw, hd - 0.12, h, hw, hd, h + 0.16, "M_PlasticWhite", bevel=0.015)
    p.box(-hw + 0.02, hd - 0.125, h + 0.03, hw - 0.02, hd - 0.12, h + 0.13, "M_PlasticBlue")
    p.cyl((0.16, hd - 0.14, h + 0.08), 0.04, 0.035, "M_PlasticWhite", axis="Y", seg=14)
    p.box(-0.2, hd - 0.13, h + 0.06, -0.06, hd - 0.125, h + 0.11, "M_Screen")
    p.cyl((0.02, hd - 0.13, h + 0.08), 0.01, 0.008, "M_LedRed", axis="Y", seg=8)
    p.box(-hw + 0.03, -hd + 0.03, h - 0.002, hw - 0.03, hd - 0.15, h, "M_MetalDark")
    # Mangueira para o tanque.
    p.cyl((-0.2, hd + 0.03, 0.5), 0.8, 0.015, "M_PlasticBlack", seg=8)
    base = p.finish("MACHINE_Washer", coll, loc=(P.W - 0.33, 3.88, 0), rot_z=facing("-x"))

    lid = Part(bevel=0.006)
    lid.box(-hw + 0.01, -(2 * hd - 0.14), 0, hw - 0.01, 0, 0.025, "M_PlasticWhite")
    lid.box(-0.18, -0.38, 0.02, 0.18, -0.08, 0.027, "M_Glass")
    lid.box(-0.06, -(2 * hd - 0.14) - 0.02, 0.005, 0.06, -(2 * hd - 0.14), 0.02, "M_PlasticWhite")
    lid.finish("MACHINE_Washer_Lid", coll, loc=(0, hd - 0.12, h), parent=base)


# Varal de teto do serviço: os dois tubos (de y0 a y1), as 5 cordas (de x0 a x1) e a altura delas.
CLOTHES = (5.35, 6.2, 2.55, 4.85, 2.22)
# Onde cada folha fica pendurada em cada corda (y do meio dela). O Godot usa os mesmos lugares
# (scripts/machines/clothesline.gd, SLOTS_Z = -y).
CLOTHES_SLOTS_Y = (2.95, 3.55, 4.15)


def clothesline(coll):
    """Varal de teto do serviço: dois tubos presos no teto por cordinhas e 5 cordas de varal, com
    os pregadores azuis já presos onde as folhas ficam (as folhas são objetos do jogo)."""
    x0, x1, y0, y1, z = CLOTHES
    p = Part(bevel=0.004)
    for y in (y0, y1):
        p.cyl(((x0 + x1) / 2, y, z), x1 - x0 + 0.1, 0.015, "M_Metal", axis="X", seg=8)
        for x in (x0 + 0.05, x1 - 0.05):
            p.cyl((x, y, (z + P.WALL_H) / 2), P.WALL_H - z, 0.006, "M_Rope", seg=6)
    lines = [x0 + 0.05 + i * (x1 - x0 - 0.1) / 4 for i in range(5)]
    for x in lines:
        p.box(x - 0.003, y0, z - 0.003, x + 0.003, y1, z + 0.003, "M_Rope")
    # Dois pregadores em cada vaga, nas pontas de cima de uma folha A4 deitada (29,7 cm).
    sw = 0.297
    for x in lines:
        for yc in CLOTHES_SLOTS_Y:
            for pin_y in (yc - sw / 2 + 0.04, yc + sw / 2 - 0.04):
                p.box(x - 0.008, pin_y - 0.006, z - 0.03, x + 0.008, pin_y + 0.006, z + 0.012, "M_PlasticBlue")
    p.finish("MACHINE_ClothesLine", coll)


def fan(coll):
    """Ventilador de coluna virado para o varal. As pás giram no Y local (eixo do motor)."""
    p = Part(bevel=0.004)
    p.cyl((0, 0, 0.02), 0.04, 0.2, "M_PlasticBlack", seg=18)
    p.cyl((0, 0, 0.6), 1.1, 0.02, "M_Metal", seg=8)
    hub = Vector((0, 0.0, 1.22))
    p.cyl(hub + Vector((0, 0.1, 0)), 0.16, 0.07, "M_PlasticBlack", axis="Y", seg=14)
    # Grade: dois aros e raios.
    ring_r, n = 0.24, 20
    for gy in (-0.05, 0.05):
        for i in range(n):
            a = i * 2 * math.pi / n
            m = Matrix.Translation(hub + Vector((ring_r * math.cos(a), gy, ring_r * math.sin(a)))) @ \
                Matrix.Rotation(-a, 4, "Y")
            p.box_m((0.012, 0.012, 2 * math.pi * ring_r / n + 0.005), m, "M_Metal")
    for i in range(8):
        a = i * math.pi / 4
        m = Matrix.Translation(hub + Vector((0.12 * math.cos(a), -0.05, 0.12 * math.sin(a)))) @ \
            Matrix.Rotation(-a, 4, "Y")
        p.box_m((0.24, 0.006, 0.006), m, "M_Metal")
    p.cyl(hub + Vector((0, -0.055, 0)), 0.01, 0.05, "M_PlasticBlue", axis="Y", seg=14)
    base = p.finish("MACHINE_Fan", coll, loc=(5.45, 2.62, 0), rot_z=facing("-y") + math.pi * 0.9)

    blades = Part(bevel=0.003)
    for i in range(3):
        a = i * 2 * math.pi / 3
        m = Matrix.Rotation(-a, 4, "Y") @ Matrix.Translation((0.11, 0, 0)) @ Matrix.Rotation(0.35, 4, "X")
        blades.box_m((0.17, 0.008, 0.09), m, "M_PlasticBlue")
    blades.cyl((0, 0, 0), 0.04, 0.035, "M_PlasticBlue", axis="Y", seg=12)
    blades.finish("MACHINE_Fan_Blades", coll, loc=tuple(hub), parent=base)
