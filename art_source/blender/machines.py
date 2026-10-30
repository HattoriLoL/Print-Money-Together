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


def guillotine(coll):
    """Guilhotina de papel na mesa. O braço gira em torno do X local (sobe a lâmina)."""
    table_z = 0.76
    p = Part(bevel=0.004)
    p.box(-0.25, -0.18, 0, 0.25, 0.18, 0.03, "M_WoodLight")
    for i in range(1, 5):
        x = -0.25 + i * 0.1
        p.box(x - 0.002, -0.17, 0.03, x + 0.002, 0.17, 0.031, "M_MetalDark")
    p.box(-0.25, 0.15, 0.03, 0.2, 0.18, 0.06, "M_Metal")       # esquadro
    p.box(0.2, -0.18, 0.03, 0.25, 0.18, 0.05, "M_MetalDark")    # trilho da lâmina
    p.box(0.2, 0.12, 0.05, 0.25, 0.18, 0.1, "M_MetalDark")      # pivô
    # Folha impressa esperando o corte.
    p.quad(((-0.23, -0.17, 0.032), (0.067, -0.17, 0.032), (0.067, 0.04, 0.032), (-0.23, 0.04, 0.032)),
           "M_MoneySheet", uvs=((0, 0), (1, 0), (1, 1), (0, 1)))
    base = p.finish("MACHINE_Guillotine", coll, loc=(2.25, 2.0, table_z), rot_z=0.15)

    arm = Part(bevel=0.003)
    m = Matrix.Translation((0, -0.25, 0))
    arm.box_m((0.035, 0.5, 0.025), m, "M_Yellow")
    arm.box_m((0.006, 0.48, 0.05), Matrix.Translation((-0.02, -0.25, -0.012)), "M_Metal")
    arm.cyl((0, -0.52, 0), 0.12, 0.022, "M_Red", axis="X", seg=10)
    ob = arm.finish("MACHINE_Guillotine_Arm", coll, loc=(0.225, 0.15, 0.08), parent=base)
    ob.rotation_euler.x = math.radians(-38)


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


def clothesline(coll):
    """Varal de teto do serviço, com folhas de notas penduradas para secar."""
    sx0, sy0, sx1, sy1 = P.SERVICE
    x0, x1, y0, y1, z = 5.35, 6.2, 2.55, 4.85, 2.22
    p = Part(bevel=0.004)
    for y in (y0, y1):
        p.cyl(((x0 + x1) / 2, y, z), x1 - x0 + 0.1, 0.015, "M_Metal", axis="X", seg=8)
        for x in (x0 + 0.05, x1 - 0.05):
            p.cyl((x, y, (z + P.WALL_H) / 2), P.WALL_H - z, 0.006, "M_Rope", seg=6)
    lines = [x0 + 0.05 + i * (x1 - x0 - 0.1) / 4 for i in range(5)]
    for x in lines:
        p.box(x - 0.003, y0, z - 0.003, x + 0.003, y1, z + 0.003, "M_Rope")
    # Folhas A4 (2 x 3 notas) presas com pregador; algumas linhas mais cheias que outras.
    sw, sh = 0.297, 0.21
    fill = [(0, (2.75, 3.15, 3.9)), (1, (2.85, 3.3, 3.7, 4.45)), (2, (3.0, 3.55, 4.2)),
            (3, (2.8, 3.25, 4.0, 4.5)), (4, (3.4, 4.3))]
    for li, ys in fill:
        x = lines[li]
        for yc in ys:
            sway = 0.012 * math.sin(yc * 7)
            a, b = yc - sw / 2, yc + sw / 2
            p.quad(((x + sway, a, z - sh), (x + sway, b, z - sh), (x, b, z - 0.004), (x, a, z - 0.004)),
                   "M_MoneySheet", uvs=((0, 0), (1, 0), (1, 1), (0, 1)))
            for pin_y in (a + 0.04, b - 0.04):
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
