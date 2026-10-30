"""Móveis da kitnet. Cada peça é montada no próprio referencial (base no chão, frente para -Y) e
colocada com `facing`. Os esconderijos se chamam HIDE_<coisa>.

As quinas são arredondadas (Part(bevel=...)): 3 a 5 mm na marcenaria, alguns centímetros no
estofado, na geladeira, na TV de tubo e na louça."""

import math

from mathutils import Matrix

import plan as P
from lib import Part, facing


def build(colls):
    c = colls["furniture"]
    kitchen(c)
    fridge(c)
    wardrobe(c)
    sofa_bed(c)
    table_and_chairs(c)
    printer_desk(c)
    tv_rack(c)
    entry(c)
    bathroom(c)
    service(c)
    decor(c)


# --- Peças repetidas -----------------------------------------------------------------------------

def _ybox(p, x0, ya, z0, x1, yb, z1, mat, bevel):
    p.box(x0, min(ya, yb), z0, x1, max(ya, yb), z1, mat, bevel=bevel)


def _bar_handle(p, x, y_face, z0, z1, mat="M_Metal", vertical=True, length=None, s=-1):
    """Puxador de barra com dois pés, saltando de `y_face` para o lado `s` (-1 = -Y, +1 = +Y)."""
    if vertical:
        _ybox(p, x - 0.007, y_face + s * 0.018, z0, x + 0.007, y_face + s * 0.03, z1, mat, 0.004)
        for z in (z0 + 0.015, z1 - 0.015):
            _ybox(p, x - 0.005, y_face, z - 0.005, x + 0.005, y_face + s * 0.02, z + 0.005, mat, 0)
    else:
        h = (length or 0.12) / 2
        _ybox(p, x - h, y_face + s * 0.018, z0 - 0.007, x + h, y_face + s * 0.03, z0 + 0.007, mat, 0.004)
        for xx in (x - h + 0.015, x + h - 0.015):
            _ybox(p, xx - 0.005, y_face, z0 - 0.005, xx + 0.005, y_face + s * 0.02, z0 + 0.005, mat, 0)


def _framed_door(p, x0, x1, z0, z1, y_face, mat, frame=0.055, depth=0.02, s=-1):
    """Porta de armário com moldura (estilo almofadada) presa na face `y_face` do corpo, saltando
    para o lado `s`: chapa e quatro réguas por cima. Devolve a face da frente (para o puxador)."""
    yf = y_face + s * depth
    _ybox(p, x0, y_face, z0, x1, yf, z1, mat, 0.004)
    yr = yf + s * 0.008
    _ybox(p, x0, yf, z0, x0 + frame, yr, z1, mat, 0.003)
    _ybox(p, x1 - frame, yf, z0, x1, yr, z1, mat, 0.003)
    _ybox(p, x0 + frame, yf, z0, x1 - frame, yr, z0 + frame, mat, 0.003)
    _ybox(p, x0 + frame, yf, z1 - frame, x1 - frame, yr, z1, mat, 0.003)
    return yr


def switch_plate(p, x, y, z, normal, sockets=0, switches=1):
    """Espelho 4x2 de interruptor/tomada colado na parede, virado para `normal` ('+x', '-x', '+y',
    '-y'). Até 2 módulos lado a lado (teclas ou tomadas de 3 pinos)."""
    w, h, t = 0.075, 0.12, 0.008
    modules = ["switch"] * switches + ["socket"] * sockets

    def bx(u0, v0, d0, u1, v1, d1, mat, bevel=0.002):
        # u ao longo da parede, v para cima, d saindo da parede.
        if normal in ("+x", "-x"):
            s = 1 if normal == "+x" else -1
            p.box(x + s * d0, y + u0, z + v0, x + s * d1, y + u1, z + v1, mat, bevel=bevel)
        else:
            s = 1 if normal == "+y" else -1
            p.box(x + u0, y + s * d0, z + v0, x + u1, y + s * d1, z + v1, mat, bevel=bevel)

    bx(-w / 2, -h / 2, 0, w / 2, h / 2, t, "M_PlasticWhite", bevel=0.003)
    n = len(modules)
    for i, kind in enumerate(modules):
        v = (i - (n - 1) / 2) * 0.045
        if kind == "switch":
            bx(-0.012, v - 0.018, t, 0.012, v + 0.018, t + 0.006, "M_PlasticWhite", bevel=0.002)
        else:
            bx(-0.016, v - 0.016, t, 0.016, v + 0.016, t + 0.002, "M_PlasticWhite", bevel=0.002)
            for du, dv in ((-0.006, 0.004), (0.006, 0.004), (0.0, -0.006)):
                bx(du - 0.002, v + dv - 0.002, t + 0.002, du + 0.002, v + dv + 0.002, t + 0.0025,
                   "M_PlasticBlack", bevel=0)


# --- Cozinha -------------------------------------------------------------------------------------

def kitchen(coll):
    """Bancada com cuba funda, cooktop com trempes, forno, armários com porta de moldura e o
    escorredor (coordenadas do mundo)."""
    x0, x1 = 0.8, 3.2
    top = 0.9
    sink = (1.05, 1.55, 0.13, 0.48)  # buraco da cuba: x0, x1, y0, y1
    p = Part(bevel=0.003)
    # Rodapé recuado e o corpo; embaixo da cuba o corpo é mais baixo (a cuba desce até 0,7).
    p.box(x0, 0.01, 0, x1, 0.5, 0.1, "M_Baseboard", bevel=0)
    p.box(x0, 0.01, 0.1, 1.0, 0.56, 0.86, "M_WoodLight", bevel=0)
    p.box(1.0, 0.01, 0.1, 1.6, 0.56, 0.68, "M_WoodLight", bevel=0)
    p.box(1.6, 0.01, 0.1, x1, 0.56, 0.86, "M_WoodLight", bevel=0)
    # Frentes: duas portas embaixo da pia, duas no meio, o forno e uma estreita na ponta.
    for a, b in ((0.803, 1.098), (1.102, 1.397), (1.403, 1.848), (1.852, 2.297), (2.953, 3.197)):
        front = _framed_door(p, a, b, 0.12, 0.84, 0.56, "M_WoodLight", frame=0.045, s=1)
        hx = b - 0.04 if (a + b) / 2 < 2.1 else a + 0.04
        _bar_handle(p, hx, front, 0.62, 0.78, s=1)
    # Tampo de granito em quatro pedaços em volta do buraco da cuba.
    gx0, gx1, gy0, gy1, gz0 = x0 - 0.02, x1 + 0.02, 0.01, 0.62, 0.86
    sx0, sx1, sy0, sy1 = sink
    p.box(gx0, gy0, gz0, sx0, gy1, top, "M_Granite", bevel=0)
    p.box(sx1, gy0, gz0, gx1, gy1, top, "M_Granite", bevel=0)
    p.box(sx0, gy0, gz0, sx1, sy0, top, "M_Granite", bevel=0)
    p.box(sx0, sy1, gz0, sx1, gy1, top, "M_Granite", bevel=0)
    p.box(gx0, gy1 - 0.004, gz0 - 0.02, gx1, gy1, gz0, "M_Granite", bevel=0)  # saia da frente
    # Cuba de inox: aba em volta, paredes, fundo e ralo.
    r = 0.025
    p.box(sx0 - r, sy0 - r, top, sx1 + r, sy0, top + 0.004, "M_Metal", bevel=0.001)
    p.box(sx0 - r, sy1, top, sx1 + r, sy1 + r, top + 0.004, "M_Metal", bevel=0.001)
    p.box(sx0 - r, sy0, top, sx0, sy1, top + 0.004, "M_Metal", bevel=0.001)
    p.box(sx1, sy0, top, sx1 + r, sy1, top + 0.004, "M_Metal", bevel=0.001)
    t = 0.006
    p.box(sx0, sy0, 0.7, sx0 + t, sy1, top, "M_Metal", bevel=0)
    p.box(sx1 - t, sy0, 0.7, sx1, sy1, top, "M_Metal", bevel=0)
    p.box(sx0, sy0, 0.7, sx1, sy0 + t, top, "M_Metal", bevel=0)
    p.box(sx0, sy1 - t, 0.7, sx1, sy1, top, "M_Metal", bevel=0)
    p.box(sx0, sy0, 0.69, sx1, sy1, 0.7, "M_Metal", bevel=0)
    p.cyl(((sx0 + sx1) / 2, (sy0 + sy1) / 2, 0.701), 0.003, 0.035, "M_MetalDark", seg=16)
    # Torneira gourmet: base, coluna, bica curva em três gomos e a alavanca.
    fx, fy = (sx0 + sx1) / 2, sy0 - 0.06
    p.cyl((fx, fy, top + 0.012), 0.024, 0.026, "M_Metal", seg=16)
    p.cyl((fx, fy, top + 0.13), 0.22, 0.012, "M_Metal", seg=12)
    for i, ang in enumerate((0.5, 1.2, 1.9)):
        m = Matrix.Translation((fx, fy + 0.035 + i * 0.05, top + 0.25 - i * i * 0.012)) @ \
            Matrix.Rotation(-ang + 1.2, 4, "X")
        p.cyl((0, 0, 0), 0.07, 0.011, "M_Metal", axis="Y", seg=10, matrix=m)
    m = Matrix.Translation((fx + 0.03, fy, top + 0.07)) @ Matrix.Rotation(0.3, 4, "Y")
    p.box_m((0.07, 0.012, 0.01), m, "M_Metal", bevel=0.003)
    # Cooktop de vidro com 4 bocas e trempes.
    p.box(2.3, 0.1, top, 2.95, 0.52, top + 0.008, "M_PlasticBlack", bevel=0.003)
    for bx, by, rr in ((2.45, 0.22, 0.05), (2.8, 0.22, 0.06), (2.45, 0.4, 0.06), (2.8, 0.4, 0.045)):
        p.cyl((bx, by, top + 0.012), 0.008, rr, "M_MetalDark", seg=20)
        p.cyl((bx, by, top + 0.018), 0.006, rr * 0.55, "M_Rubber", seg=16)
        for a in (0.0, math.pi / 2):
            m = Matrix.Translation((bx, by, top + 0.035)) @ Matrix.Rotation(a + 0.785, 4, "Z")
            p.box_m((rr * 2.6, 0.008, 0.008), m, "M_MetalDark", bevel=0.002)
    # Forno: painel de botões em cima e porta com visor e puxador.
    p.box(2.305, 0.56, 0.74, 2.945, 0.585, 0.84, "M_PlasticBlack", bevel=0.003)
    for kx in (2.4, 2.53, 2.72, 2.85):
        p.cyl((kx, 0.59, 0.79), 0.02, 0.018, "M_Metal", axis="Y", seg=14)
        p.box(kx - 0.002, 0.598, 0.795, kx + 0.002, 0.601, 0.805, "M_PlasticBlack", bevel=0)
    p.box(2.305, 0.56, 0.14, 2.945, 0.59, 0.735, "M_PlasticBlack", bevel=0.006)
    p.box(2.36, 0.59, 0.25, 2.89, 0.592, 0.6, "M_Glass", bevel=0)
    _bar_handle(p, 2.625, 0.59, 0.68, None, vertical=False, length=0.46, s=1)
    # Armário de cima: corpo e quatro portas de moldura com puxador embaixo.
    p.box(x0, 0.01, 1.52, x1, 0.3, 2.2, "M_WoodLight", bevel=0.002)
    for i in range(4):
        a = x0 + 0.003 + i * 0.6
        front = _framed_door(p, a, a + 0.594, 1.522, 2.198, 0.3, "M_WoodLight", frame=0.05, s=1)
        _bar_handle(p, a + 0.297, front, 1.56, None, vertical=False, length=0.12, s=1)
    # Escorredor de arame com pratos e copos.
    rx0, rx1, ry0, ry1 = 0.84, 1.0, 0.12, 0.52
    p.box(rx0, ry0, top, rx1, ry1, top + 0.012, "M_PlasticWhite", bevel=0.004)
    for x in (rx0 + 0.01, rx1 - 0.01):
        for y in (ry0 + 0.01, ry1 - 0.01):
            p.cyl((x, y, top + 0.06), 0.1, 0.003, "M_Metal", seg=6)
    for z in (top + 0.06, top + 0.11):
        for x in (rx0 + 0.01, rx1 - 0.01):
            p.box(x - 0.002, ry0, z - 0.002, x + 0.002, ry1, z + 0.002, "M_Metal", bevel=0)
    for y in (0.2, 0.27, 0.34):
        p.cyl((0.92, y, top + 0.1), 0.012, 0.085, "M_Porcelain", axis="Y", seg=20)
    for y in (0.43, 0.48):
        p.cyl((0.92, y, top + 0.06), 0.09, 0.03, "M_Glass", seg=14, radius2=0.035)
    p.finish("Kitchen_Counter", coll)


def fridge(coll):
    """Geladeira duplex de quinas redondas com o micro-ondas em cima."""
    p = Part(bevel=0.004)
    w, d = 0.33, 0.33
    p.box(-w, -d + 0.04, 0.05, w, d, 1.75, "M_PlasticWhite", bevel=0.03)
    p.box(-w + 0.004, -d, 1.262, w - 0.004, -d + 0.045, 1.748, "M_PlasticWhite", bevel=0.022)
    p.box(-w + 0.004, -d, 0.06, w - 0.004, -d + 0.045, 1.248, "M_PlasticWhite", bevel=0.022)
    p.box(-w + 0.02, -d + 0.01, 0.0, w - 0.02, d - 0.05, 0.06, "M_PlasticBlack", bevel=0.005)
    for i in range(6):
        x = -0.2 + i * 0.08
        p.box(x - 0.025, -d + 0.008, 0.015, x + 0.025, -d + 0.012, 0.045, "M_Rubber", bevel=0)
    # Puxadores verticais embutidos e o logotipo.
    for z0, z1 in ((1.3, 1.52), (0.75, 1.15)):
        p.box(0.24, -d - 0.025, z0, 0.27, -d + 0.01, z1, "M_PlasticWhite", bevel=0.012)
        p.box(0.245, -d - 0.026, z0 + 0.02, 0.265, -d - 0.02, z1 - 0.02, "M_Metal", bevel=0.003)
    p.box(-0.08, -d - 0.002, 1.66, 0.08, -d, 1.68, "M_Metal", bevel=0)
    # Ímãs, o cardápio da pizzaria e uma conta presa.
    for mx, mz, mat in ((-0.15, 1.4, "M_Red"), (-0.05, 1.47, "M_Yellow"), (-0.2, 0.95, "M_PlasticBlue")):
        p.cyl((mx, -d - 0.006, mz), 0.012, 0.022, mat, axis="Y", seg=12)
    p.box(-0.12, -d - 0.002, 1.0, 0.08, -d, 1.25, "M_Paper", bevel=0)
    p.box(-0.26, -d - 0.002, 0.82, -0.08, -d, 0.98, "M_Paper", bevel=0)
    p.box(-0.26, -d - 0.003, 0.95, -0.08, -d - 0.002, 0.98, "M_Red", bevel=0)
    # Micro-ondas: porta com visor escuro, painel de botões e puxador.
    my0, my1, mz0, mz1 = -0.2, 0.17, 1.755, 2.03
    p.box(-0.25, my0, mz0, 0.22, my1, mz1, "M_PlasticWhite", bevel=0.012)
    p.box(-0.24, my0 - 0.01, mz0 + 0.02, 0.08, my0 + 0.005, mz1 - 0.02, "M_PlasticBlack", bevel=0.008)
    p.box(-0.21, my0 - 0.012, mz0 + 0.05, 0.03, my0 - 0.01, mz1 - 0.05, "M_Glass", bevel=0)
    p.box(0.1, my0 - 0.004, mz0 + 0.02, 0.21, my0 + 0.005, mz1 - 0.02, "M_MetalDark", bevel=0.004)
    p.box(0.12, my0 - 0.006, mz1 - 0.07, 0.19, my0 - 0.004, mz1 - 0.04, "M_Screen", bevel=0)
    for row in range(3):
        for col in range(3):
            bx = 0.125 + col * 0.022
            bz = mz0 + 0.06 + row * 0.03
            p.box(bx, my0 - 0.008, bz, bx + 0.016, my0 - 0.004, bz + 0.02, "M_PlasticWhite", bevel=0.002)
    p.box(0.05, my0 - 0.03, mz0 + 0.05, 0.07, my0 - 0.008, mz1 - 0.05, "M_PlasticBlack", bevel=0.006)
    p.finish("HIDE_Fridge", coll, loc=(0.4, 0.4, 0), rot_z=facing("+y"))


def wardrobe(coll):
    """Guarda-roupa de duas portas almofadadas, com cimalha, rodapé e a mala em cima."""
    p = Part(bevel=0.003)
    hw, hd, h = 0.7, 0.29, 2.0
    p.box(-hw + 0.02, -hd + 0.03, 0, hw - 0.02, hd, 0.08, "M_Wood", bevel=0.002)
    p.box(-hw, -hd + 0.01, 0.08, hw, hd, h - 0.04, "M_Wood")
    p.box(-hw - 0.015, -hd - 0.012, h - 0.04, hw + 0.015, hd + 0.005, h, "M_Wood", bevel=0.006)
    for x0, x1 in ((-hw + 0.012, -0.003), (0.003, hw - 0.012)):
        front = _framed_door(p, x0, x1, 0.095, h - 0.055, -hd + 0.01, "M_WoodLight", frame=0.075)
    for x in (-0.045, 0.045):
        _bar_handle(p, x, front, 0.95, 1.25)
    # Mala (cabe dinheiro) e caixa de papelão com fita.
    p.box(-0.6, -0.22, h, 0.05, 0.25, h + 0.22, "M_PlasticBlue", bevel=0.03)
    p.box(-0.6, -0.225, h + 0.1, 0.05, 0.255, h + 0.115, "M_PlasticBlack", bevel=0.004)
    p.box(-0.32, -0.25, h + 0.215, -0.2, -0.23, h + 0.24, "M_PlasticBlack", bevel=0.006)
    m = Matrix.Translation((0.38, 0.0, h + 0.15)) @ Matrix.Rotation(0.1, 4, "Z")
    p.box_m((0.45, 0.42, 0.3), m, "M_Cardboard", bevel=0.004)
    p.box_m((0.08, 0.425, 0.302), m, "M_PlasticWhite", bevel=0)
    p.finish("HIDE_Wardrobe", coll, loc=(0.3, 1.8, 0), rot_z=facing("+x"))


def sofa_bed(coll):
    """Sofá-cama de almofadas fofas. Embaixo dele (vão de 12 cm) dá para enfiar pacotes."""
    p = Part(bevel=0.006)
    hl, hd = 1.0, 0.475
    for lx in (-0.92, 0.92):
        for ly in (-0.38, 0.4):
            p.cyl((lx, ly, 0.06), 0.12, 0.03, "M_Wood", seg=12, radius2=0.022)
    p.box(-hl, -hd + 0.03, 0.12, hl, hd, 0.36, "M_Wood", bevel=0.012)
    # Braços estofados, dois assentos e dois encostos um pouco inclinados.
    for x0, x1 in ((-hl, -0.83), (0.83, hl)):
        p.rounded(x0, -hd, 0.3, x1, hd, 0.68, "M_Fabric", 0.05)
    for x0, x1 in ((-0.83, -0.005), (0.005, 0.83)):
        p.rounded(x0, -hd + 0.01, 0.34, x1, 0.2, 0.53, "M_Fabric", 0.05)
        m = Matrix.Translation(((x0 + x1) / 2, 0.33, 0.7)) @ Matrix.Rotation(-0.18, 4, "X")
        p.box_m((x1 - x0, 0.2, 0.5), m, "M_Fabric", bevel=0.06)
    p.box(-0.83, 0.38, 0.36, 0.83, hd, 0.9, "M_Fabric", bevel=0.02)
    # Coberta embolada caindo pela frente, travesseiro e duas caixas de pizza.
    p.box(-0.55, -0.43, 0.53, 0.25, 0.16, 0.575, "M_Blanket", bevel=0.015)
    m = Matrix.Translation((-0.2, -0.47, 0.45)) @ Matrix.Rotation(0.25, 4, "X")
    p.box_m((0.55, 0.04, 0.2), m, "M_Blanket", bevel=0.012)
    p.box(-0.2, -0.3, 0.57, 0.1, 0.05, 0.61, "M_Blanket", bevel=0.015)
    p.rounded(-0.79, -0.18, 0.52, -0.41, 0.2, 0.65, "M_Pillow", 0.05)
    for (x, y, z, r) in ((0.58, -0.18, 0.555, 0.15), (0.56, -0.2, 0.6, -0.1)):
        m = Matrix.Translation((x, y, z)) @ Matrix.Rotation(r, 4, "Z")
        p.box_m((0.36, 0.36, 0.045), m, "M_PizzaBox", bevel=0.004)
        p.box_m((0.12, 0.12, 0.002), m @ Matrix.Translation((0.04, 0.04, 0.023)), "M_Red", bevel=0)
    p.finish("HIDE_SofaBed", coll, loc=(0.48, 3.8, 0), rot_z=facing("+x"))


def _plastic_chair(p, tilt=0.18):
    """Cadeira de plástico branca de bar: pernas que abrem, assento com borda e encosto vazado."""
    for lx in (-0.19, 0.19):
        for ly in (-0.19, 0.18):
            m = Matrix.Translation((lx * 1.04, ly * 1.04, 0.215)) @ \
                Matrix.Rotation(math.copysign(0.05, ly), 4, "X") @ Matrix.Rotation(-math.copysign(0.05, lx), 4, "Y")
            p.box_m((0.045, 0.045, 0.44), m, "M_PlasticWhite", bevel=0.012)
    p.box(-0.225, -0.225, 0.42, 0.225, 0.2, 0.45, "M_PlasticWhite", bevel=0.015)
    p.box(-0.225, -0.235, 0.39, 0.225, -0.215, 0.45, "M_PlasticWhite", bevel=0.008)
    back = Matrix.Translation((0, 0.23, 0.68)) @ Matrix.Rotation(-tilt, 4, "X")
    p.box_m((0.44, 0.03, 0.12), back @ Matrix.Translation((0, 0, 0.15)), "M_PlasticWhite", bevel=0.012)
    for x in (-0.2, 0.0, 0.2):
        p.box_m((0.04, 0.03, 0.42), back @ Matrix.Translation((x, 0, 0)), "M_PlasticWhite", bevel=0.01)
    p.box_m((0.44, 0.03, 0.06), back @ Matrix.Translation((0, 0, -0.06)), "M_PlasticWhite", bevel=0.01)


def table_and_chairs(coll):
    p = Part(bevel=0.004)
    hx, hy = 0.6, 0.4
    p.box(-0.8, -0.7, 0, 0.8, 0.7, 0.008, "M_Rug", bevel=0)
    for x in (-0.8, 0.8):
        for i in range(14):
            y = -0.65 + i * 0.1
            p.box(x - 0.03 if x < 0 else x, y - 0.006, 0, x if x < 0 else x + 0.03, y + 0.006, 0.004,
                  "M_ClothWhite", bevel=0)
    p.box(-hx, -hy, 0.72, hx, hy, 0.76, "M_WoodLight", bevel=0.008)
    p.box(-hx + 0.05, -hy + 0.05, 0.64, hx - 0.05, hy - 0.05, 0.72, "M_Wood")
    for lx in (-hx + 0.06, hx - 0.06):
        for ly in (-hy + 0.06, hy - 0.06):
            p.cyl((lx, ly, 0.36), 0.72, 0.022, "M_Wood", seg=12, radius2=0.03)
    # Maços de notas já cortadas, com a cinta amarela.
    for i, (bx, by) in enumerate(((-0.52, 0.31), (-0.39, 0.33), (-0.52, 0.31), (0.4, -0.3))):
        z = 0.76 + (0.02 if i == 2 else 0)
        p.box(bx - 0.06, by - 0.03, z, bx + 0.06, by + 0.03, z + 0.02, "M_Money", bevel=0.002)
        p.box(bx - 0.012, by - 0.031, z - 0.001, bx + 0.012, by + 0.031, z + 0.021, "M_MoneyBand", bevel=0)
    p.finish("Table", coll, loc=(2.6, 2.1, 0))

    p = Part()
    _plastic_chair(p)
    p.finish("Chair_0", coll, loc=(2.25, 2.78, 0), rot_z=facing("-y") + 0.1)
    p = Part()
    _plastic_chair(p)
    p.finish("Chair_1", coll, loc=(3.45, 1.95, 0), rot_z=facing("-x") - 0.2)


def _cable(p, a, b, r=0.004, mat="M_PlasticBlack"):
    """Cabo reto de `a` até `b` (um eixo por vez: x, y ou z), com as pontas arredondadas."""
    axis = next(i for i in range(3) if abs(a[i] - b[i]) > 1e-6)
    c = tuple((a[i] + b[i]) / 2 for i in range(3))
    p.cyl(c, abs(a[axis] - b[axis]) + r, r, mat, axis="XYZ"[axis], seg=8)


def printer_desk(coll):
    """Escrivaninha de escritório velha embaixo da janela: tampo de madeira, pés e painel de aço
    pintado, gaveteiro de três gavetas, o gabinete de PC bege embaixo e os cabos da impressora
    (que fica em cima, ver machines.printer). Coordenadas do mundo."""
    x0, x1, y0, y1, top = 1.6, 2.8, 4.42, 4.97, 0.75
    p = Part(bevel=0.004)
    p.box(x0, y0, top - 0.03, x1, y1, top, "M_DeskWood")
    p.box(x0, y0 - 0.006, top - 0.031, x1, y0, top + 0.001, "M_OldPlasticDark", bevel=0.002)
    # Pés de tubo quadrado do lado esquerdo, travessa de baixo e painel de fundo.
    for y in (y0 + 0.03, y1 - 0.05):
        p.box(x0 + 0.02, y, 0, x0 + 0.05, y + 0.03, top - 0.03, "M_DeskMetal")
        p.box(x0 + 0.015, y - 0.005, 0, x0 + 0.055, y + 0.035, 0.012, "M_Rubber", bevel=0.002)
    p.box(x0 + 0.025, y0 + 0.06, 0.05, x0 + 0.045, y1 - 0.05, 0.075, "M_DeskMetal")
    p.box(x0 + 0.05, y1 - 0.04, 0.3, 2.38, y1 - 0.02, top - 0.03, "M_DeskMetal")
    # Gaveteiro da direita: três gavetas com puxador e porta-etiqueta.
    gx0, gx1 = 2.38, x1 - 0.02
    p.box(gx0, y0 + 0.02, 0.02, gx1, y1 - 0.02, top - 0.03, "M_DeskMetal")
    for z0, z1 in ((0.04, 0.25), (0.27, 0.48), (0.5, 0.69)):
        p.box(gx0 + 0.015, y0 + 0.008, z0, gx1 - 0.015, y0 + 0.02, z1, "M_DeskMetal", bevel=0.005)
        hx = (gx0 + gx1) / 2
        p.box(hx - 0.06, y0 - 0.012, z1 - 0.045, hx + 0.06, y0 - 0.002, z1 - 0.032, "M_Metal", bevel=0.003)
        for x in (hx - 0.05, hx + 0.05):
            p.box(x - 0.005, y0, z1 - 0.044, x + 0.005, y0 + 0.008, z1 - 0.033, "M_Metal", bevel=0)
        p.box(hx - 0.035, y0 + 0.002, z1 - 0.085, hx + 0.035, y0 + 0.008, z1 - 0.06, "M_Metal", bevel=0.001)
        p.box(hx - 0.03, y0 + 0.0015, z1 - 0.082, hx + 0.03, y0 + 0.002, z1 - 0.063, "M_Paper", bevel=0)
    for x in (gx0 + 0.03, gx1 - 0.03):
        p.cyl((x, y0 + 0.05, 0.01), 0.02, 0.012, "M_Rubber", seg=10)
    p.finish("Desk_Printer", coll)

    pc(coll)

    # Cabos: força da impressora até o benjamim atrás, paralelo grosso até o PC e a força do PC.
    p = Part()
    behind = y1 - 0.012
    _cable(p, (2.445, 4.9, top + 0.006), (2.445, behind, top + 0.006))
    _cable(p, (2.445, behind, top + 0.006), (2.445, behind, 0.37))
    _cable(p, (2.445, behind, 0.37), (2.93, behind, 0.37))
    _cable(p, (2.215, 4.91, top + 0.008), (2.215, behind, top + 0.008), r=0.007, mat="M_Cable")
    _cable(p, (2.215, behind, top + 0.008), (2.215, behind, 0.3), r=0.007, mat="M_Cable")
    _cable(p, (2.215, behind, 0.3), (1.85, behind, 0.3), r=0.007, mat="M_Cable")
    _cable(p, (1.85, behind, 0.3), (1.85, 4.925, 0.3), r=0.007, mat="M_Cable")
    _cable(p, (1.78, 4.93, 0.08), (1.78, 4.985, 0.08))
    _cable(p, (1.78, 4.985, 0.08), (1.78, 4.985, 0.006))
    _cable(p, (1.78, 4.985, 0.006), (1.05, 4.985, 0.006))
    _cable(p, (1.05, 4.985, 0.006), (1.05, 4.985, 0.33))
    p.finish("Props_DeskCables", coll)

    # Em cima da mesa: caneca de café, porta-lápis, bloquinho e a caixa do toner reserva.
    p = Part(bevel=0.003)
    mx, my = 1.82, 4.56
    p.cyl((mx, my, top + 0.048), 0.095, 0.04, "M_PlasticWhite", seg=24)
    p.cyl((mx, my, top + 0.08), 0.004, 0.036, "M_Coffee", seg=24)
    p.box(mx + 0.036, my - 0.007, top + 0.02, mx + 0.062, my + 0.007, top + 0.075, "M_PlasticWhite", bevel=0.006)
    px, py = 1.7, 4.86
    p.cyl((px, py, top + 0.05), 0.1, 0.035, "M_PlasticBlack", seg=16)
    for dx, dy, tilt, mat in ((-0.01, 0.0, 0.15, "M_PlasticBlue"), (0.012, 0.005, -0.12, "M_Red"),
                              (0.0, -0.012, 0.05, "M_InkBlack")):
        m = Matrix.Translation((px + dx, py + dy, top + 0.12)) @ Matrix.Rotation(tilt, 4, "Y")
        p.cyl((0, 0, 0), 0.14, 0.004, mat, seg=6, matrix=m)
    m = Matrix.Translation((1.92, 4.78, top + 0.01)) @ Matrix.Rotation(0.25, 4, "Z")
    p.box_m((0.076, 0.076, 0.02), m, "M_Yellow", bevel=0.001)
    p.box(2.58, 4.78, top, 2.78, 4.92, top + 0.1, "M_Cardboard", bevel=0.003)
    p.quad(((2.62, 4.7795, top + 0.03), (2.72, 4.7795, top + 0.03), (2.72, 4.7795, top + 0.08),
            (2.62, 4.7795, top + 0.08)), "M_StickerLabel", double=False)
    p.finish("Props_Desk", coll)


def pc(coll):
    """Gabinete de PC bege embaixo da escrivaninha: drive de CD, de disquete, botão, LEDs e grade."""
    x0, x1, y0, y1, h = 1.7, 1.9, 4.47, 4.92, 0.42
    p = Part(bevel=0.004)
    for x in (x0 + 0.02, x1 - 0.02):
        for y in (y0 + 0.03, y1 - 0.03):
            p.cyl((x, y, 0.006), 0.012, 0.012, "M_Rubber", seg=10)
    p.box(x0, y0, 0.012, x1, y1, h, "M_OldPlastic", bevel=0.008)
    p.box(x0 + 0.005, y0 - 0.008, 0.02, x1 - 0.005, y0 + 0.005, h - 0.008, "M_OldPlastic", bevel=0.01)
    # Drive de CD: bandeja com fenda e botão de ejetar.
    cy = y0 - 0.009
    p.box(x0 + 0.015, cy - 0.003, 0.34, x1 - 0.015, cy + 0.002, 0.383, "M_OldPlastic", bevel=0.002)
    p.box(x0 + 0.03, cy - 0.0035, 0.36, x1 - 0.03, cy - 0.003, 0.364, "M_PlasticBlack", bevel=0)
    p.box(x1 - 0.045, cy - 0.006, 0.346, x1 - 0.025, cy - 0.003, 0.353, "M_OldPlasticDark", bevel=0.001)
    # Disquete: fenda com a portinha escura e o botão.
    p.box(x0 + 0.04, cy - 0.003, 0.29, x1 - 0.04, cy + 0.002, 0.318, "M_OldPlastic", bevel=0.002)
    p.box(x0 + 0.05, cy - 0.0035, 0.304, x1 - 0.06, cy - 0.003, 0.308, "M_PlasticBlack", bevel=0)
    p.box(x1 - 0.058, cy - 0.006, 0.296, x1 - 0.048, cy - 0.003, 0.3, "M_OldPlasticDark", bevel=0.001)
    # Botão de força, reset, LEDs e a grade de baixo.
    p.cyl((x0 + 0.1, cy - 0.004, 0.22), 0.008, 0.016, "M_OldPlasticDark", axis="Y", seg=20)
    p.cyl((x0 + 0.1, cy - 0.005, 0.18), 0.006, 0.006, "M_OldPlasticDark", axis="Y", seg=12)
    p.cyl((x0 + 0.07, cy - 0.003, 0.25), 0.004, 0.003, "M_LedGreen", axis="Y", seg=8)
    p.cyl((x0 + 0.13, cy - 0.003, 0.25), 0.004, 0.003, "M_LedRed", axis="Y", seg=8)
    for i in range(7):
        z = 0.04 + i * 0.012
        p.box(x0 + 0.03, cy - 0.0035, z, x1 - 0.03, cy - 0.003, z + 0.005, "M_OldPlasticDark", bevel=0)
    # Grade lateral e as tampas de slot atrás.
    for i in range(5):
        y = y0 + 0.12 + i * 0.03
        p.box(x1 - 0.001, y, 0.1, x1 + 0.0005, y + 0.012, 0.2, "M_OldPlasticDark", bevel=0)
    for i in range(4):
        z = 0.08 + i * 0.025
        p.box(x0 + 0.03, y1, z, x1 - 0.06, y1 + 0.004, z + 0.016, "M_Metal", bevel=0.001)
    p.quad(((x0 + 0.03, y0 - 0.0095, 0.1), (x0 + 0.09, y0 - 0.0095, 0.1), (x0 + 0.09, y0 - 0.0095, 0.13),
            (x0 + 0.03, y0 - 0.0095, 0.13)), "M_StickerLabel", double=False)
    p.finish("Props_PC", coll)


def tv_rack(coll):
    """Rack com TV de tubo encostado na divisória. A TV pode virar a câmera do corredor."""
    p = Part(bevel=0.004)
    # Rack oco: tampo, base, laterais, fundo e prateleira; porta de vidro só embaixo.
    p.box(-0.4, -0.2, 0.47, 0.4, 0.2, 0.5, "M_Wood")
    p.box(-0.4, -0.2, 0.05, 0.4, 0.2, 0.08, "M_Wood")
    for x in (-0.4, 0.38):
        p.box(x, -0.2, 0.08, x + 0.02, 0.2, 0.47, "M_Wood")
    p.box(-0.38, 0.18, 0.08, 0.38, 0.2, 0.47, "M_Wood")
    p.box(-0.38, -0.19, 0.26, 0.38, 0.18, 0.28, "M_Wood")
    for x in (-0.36, 0.36):
        p.box(x - 0.03, -0.17, 0, x + 0.03, 0.17, 0.05, "M_MetalDark", bevel=0.002)
    p.box(-0.38, -0.205, 0.085, 0.38, -0.198, 0.255, "M_Glass", bevel=0)
    # Fitas e caixas de jogo na prateleira de cima.
    for i, mat in enumerate(("M_PlasticBlack", "M_ClothRed", "M_PlasticBlack", "M_PlasticBlue", "M_PlasticBlack")):
        x = -0.34 + i * 0.03
        p.box(x, -0.12, 0.28, x + 0.025, 0.08, 0.47 - 0.02 * (i % 2), mat, bevel=0.002)
    # CRT: moldura de quinas bem redondas, tela funda e a "corcunda" de trás.
    p.box(-0.33, -0.13, 0.5, 0.33, 0.12, 0.94, "M_PlasticBlack", bevel=0.035)
    p.box(-0.25, 0.08, 0.55, 0.25, 0.32, 0.88, "M_PlasticBlack", bevel=0.06)
    p.box(-0.285, -0.135, 0.55, 0.205, -0.125, 0.89, "M_MetalDark", bevel=0.02)
    p.box(-0.27, -0.14, 0.565, 0.19, -0.13, 0.875, "M_TVScreen", bevel=0.025)
    for z in (0.82, 0.76, 0.7):
        p.cyl((0.26, -0.135, z), 0.012, 0.014, "M_MetalDark", axis="Y", seg=12)
    p.cyl((0.26, -0.136, 0.58), 0.01, 0.006, "M_LedRed", axis="Y", seg=8)
    # Antena de "orelha de coelho".
    p.cyl((0.0, 0.15, 0.95), 0.03, 0.04, "M_PlasticBlack", seg=12)
    for a in (-0.5, 0.5):
        m = Matrix.Translation((0.0, 0.15, 0.96)) @ Matrix.Rotation(a, 4, "Y") @ Matrix.Translation((0, 0, 0.2))
        p.cyl((0, 0, 0), 0.4, 0.004, "M_Metal", seg=6, matrix=m)
    # DVD na prateleira de baixo.
    p.box(-0.3, -0.17, 0.09, 0.1, 0.12, 0.155, "M_PlasticBlack", bevel=0.005)
    p.box(-0.25, -0.172, 0.12, -0.05, -0.17, 0.13, "M_MetalDark", bevel=0)
    p.cyl((0.06, -0.172, 0.12), 0.004, 0.004, "M_LedRed", axis="Y", seg=6)
    p.finish("TV_Rack", coll, loc=(4.68, 2.25, 0), rot_z=facing("-x"))


def entry(coll):
    """Tapete, cabideiro com casaco, interruptores e o quadro de luz ao lado da porta."""
    p = Part(bevel=0.004)
    p.box(P.ENTRANCE[0] + 0.05, 0.05, 0, P.ENTRANCE[1] - 0.05, 0.5, 0.012, "M_Doormat")
    px = P.PART_X
    p.box(px - 0.02, 0.25, 1.6, px, 0.85, 1.68, "M_Wood")
    for y in (0.35, 0.55, 0.75):
        p.cyl((px - 0.05, y, 1.64), 0.06, 0.008, "M_Metal", axis="X", seg=8)
        p.cyl((px - 0.08, y, 1.65), 0.012, 0.012, "M_Metal", axis="X", seg=10)
    m = Matrix.Translation((px - 0.1, 0.55, 1.28)) @ Matrix.Rotation(0.06, 4, "Y")
    p.box_m((0.08, 0.32, 0.7), m, "M_Blanket", bevel=0.03)
    p.box_m((0.06, 0.12, 0.1), m @ Matrix.Translation((0.0, 0.0, 0.37)), "M_Blanket", bevel=0.02)
    switch_plate(p, px, 0.24, 1.25, "-x", switches=2)
    switch_plate(p, P.PART_X, P.BATH_DOOR[1] + 0.12, 1.2, "-x")
    switch_plate(p, P.PART_X + P.INT_T, P.SERVICE_OPENING[0] - 0.12, 1.2, "+x")
    p.finish("Entry", coll)

    # Quadro de luz com portinha: o Godot pode usar como disjuntor geral.
    p = Part(bevel=0.004)
    p.box(-0.15, -0.06, 0, 0.15, 0, 0.4, "M_PlasticWhite", bevel=0.008)
    p.box(-0.13, -0.065, 0.13, 0.13, -0.06, 0.29, "M_PlasticBlack", bevel=0)
    for i in range(5):
        x = -0.11 + i * 0.05
        p.box(x, -0.075, 0.17, x + 0.03, -0.06, 0.25, "M_PlasticWhite", bevel=0.003)
        p.box(x + 0.008, -0.085, 0.2, x + 0.022, -0.075, 0.225, "M_PlasticBlack", bevel=0.002)
    p.finish("KEEP_Breaker", coll, loc=(4.78, 0.0, 1.45), rot_z=facing("+y"))


# --- Banheiro e serviço --------------------------------------------------------------------------

def bathroom(coll):
    bx0, by0, bx1, by1 = P.BATH
    p = Part(bevel=0.004)
    # Vaso com caixa acoplada: pé, bacia arredondada, assento, tampa e botão da descarga.
    tx, ty = 6.45, by1
    p.rounded(tx - 0.11, ty - 0.5, 0, tx + 0.11, ty - 0.22, 0.3, "M_Porcelain", 0.06)
    p.rounded(tx - 0.18, ty - 0.66, 0.24, tx + 0.18, ty - 0.2, 0.4, "M_Porcelain", 0.08)
    p.rounded(tx - 0.175, ty - 0.66, 0.4, tx + 0.175, ty - 0.21, 0.425, "M_PlasticWhite", 0.012)
    p.rounded(tx - 0.17, ty - 0.65, 0.425, tx + 0.17, ty - 0.21, 0.445, "M_PlasticWhite", 0.012)
    p.rounded(tx - 0.2, ty - 0.21, 0.4, tx + 0.2, ty - 0.01, 0.78, "M_Porcelain", 0.03)
    p.rounded(tx - 0.205, ty - 0.215, 0.77, tx + 0.205, ty - 0.005, 0.8, "M_Porcelain", 0.012)
    p.cyl((tx, ty - 0.11, 0.805), 0.012, 0.035, "M_Metal", seg=16)
    p.cyl((tx + 0.33, ty - 0.03, 0.72), 0.11, 0.055, "M_Paper", axis="X", seg=16)
    p.box(tx + 0.26, ty - 0.012, 0.7, tx + 0.4, ty - 0.002, 0.78, "M_Metal", bevel=0.004)
    # Pia de coluna: coluna, cuba com buraco de verdade, torneira e espelho com moldura.
    sx = 5.45
    p.rounded(sx - 0.08, by1 - 0.22, 0, sx + 0.08, by1 - 0.05, 0.74, "M_Porcelain", 0.06)
    lx0, lx1, ly0, ly1, lz = sx - 0.24, sx + 0.24, by1 - 0.44, by1 - 0.01, 0.86
    hx0, hx1, hy0, hy1 = sx - 0.17, sx + 0.17, by1 - 0.38, by1 - 0.1
    # Casco embaixo e a borda em quatro pedaços em volta do buraco: a cuba tem 10 cm de fundo.
    p.rounded(lx0, ly0, 0.7, lx1, ly1, 0.77, "M_Porcelain", 0.03)
    p.box(lx0, ly0, 0.76, hx0, ly1, lz, "M_Porcelain", bevel=0)
    p.box(hx1, ly0, 0.76, lx1, ly1, lz, "M_Porcelain", bevel=0)
    p.box(hx0, ly0, 0.76, hx1, hy0, lz, "M_Porcelain", bevel=0)
    p.box(hx0, hy1, 0.76, hx1, ly1, lz, "M_Porcelain", bevel=0)
    p.box(hx0, hy0, 0.75, hx1, hy1, 0.76, "M_Porcelain", bevel=0)
    p.cyl(((hx0 + hx1) / 2, (hy0 + hy1) / 2, 0.761), 0.002, 0.02, "M_Metal", seg=12)
    p.cyl((sx, by1 - 0.05, lz + 0.06), 0.12, 0.012, "M_Metal", seg=12)
    p.box(sx - 0.008, by1 - 0.13, lz + 0.1, sx + 0.008, by1 - 0.04, lz + 0.12, "M_Metal", bevel=0.004)
    p.cyl((sx, by1 - 0.05, lz + 0.135), 0.03, 0.018, "M_Metal", seg=12)
    p.box(sx - 0.23, by1 - 0.02, 1.11, sx + 0.23, by1 - 0.002, 1.74, "M_PlasticWhite", bevel=0.006)
    p.box(sx - 0.2, by1 - 0.024, 1.14, sx + 0.2, by1 - 0.02, 1.71, "M_Mirror", bevel=0)
    # Box do chuveiro: degrau, ralo, chuveiro elétrico e o varão em L com argolas.
    shx = 6.0
    p.box(shx, by0 + 0.01, 0, shx + 0.04, 1.0, 0.04, "M_Tile", bevel=0.008)
    p.box(shx, 0.96, 0, bx1 - 0.01, 1.0, 0.04, "M_Tile", bevel=0.008)
    p.box(6.44, 0.44, 0, 6.56, 0.56, 0.003, "M_Metal", bevel=0)
    for i in range(5):
        p.box(6.45, 0.455 + i * 0.022, 0.003, 6.55, 0.462 + i * 0.022, 0.004, "M_MetalDark", bevel=0)
    p.cyl((bx1 - 0.03, 0.5, 1.75), 0.5, 0.012, "M_PlasticWhite", seg=10)
    p.cyl((bx1 - 0.16, 0.5, 2.0), 0.26, 0.012, "M_PlasticWhite", axis="X", seg=10)
    p.rounded(bx1 - 0.36, 0.43, 1.9, bx1 - 0.22, 0.57, 2.05, "M_PlasticWhite", 0.03)
    p.cyl((bx1 - 0.29, 0.5, 1.885), 0.02, 0.07, "M_PlasticWhite", seg=18)
    p.cyl((bx1 - 0.29, 0.5, 1.874), 0.002, 0.06, "M_Metal", seg=18)
    p.cyl((bx1 - 0.03, 0.5, 2.2), 0.3, 0.007, "M_PlasticBlack", seg=6)
    p.cyl((shx + 0.5, 0.98, 2.0), 1.0, 0.01, "M_Metal", axis="X", seg=10)
    p.cyl((shx + 0.02, 0.5, 2.0), 1.0, 0.01, "M_Metal", axis="Y", seg=10)
    for i in range(8):
        p.cyl((shx + 0.04 + i * 0.07, 0.98, 2.0), 0.006, 0.018, "M_Metal", axis="X", seg=10)
    p.sheet(shx + 0.02, shx + 0.55, 0.98, 0.98, 0.15, 1.98, "M_ShowerCurtain", waves=5, amp=0.03, seg=24)
    p.sheet(shx + 0.02, shx + 0.02, 0.02, 0.32, 0.15, 1.98, "M_ShowerCurtain", waves=3.5, amp=0.025,
            axis="y", seg=16)
    # Porta-toalha com toalha dobrada e lixeirinha de pedal.
    p.cyl((bx1 - 0.04, 1.55, 1.25), 0.6, 0.008, "M_Metal", axis="Y", seg=8)
    for y in (1.27, 1.83):
        p.box(bx1 - 0.045, y - 0.008, 1.24, bx1, y + 0.008, 1.26, "M_Metal", bevel=0.003)
    p.box(bx1 - 0.065, 1.3, 0.78, bx1 - 0.02, 1.8, 1.262, "M_Blanket", bevel=0.012)
    p.cyl((bx0 + 0.13, 1.75, 0.14), 0.28, 0.1, "M_PlasticWhite", seg=16)
    p.cyl((bx0 + 0.13, 1.75, 0.285), 0.02, 0.105, "M_PlasticWhite", seg=16)
    p.finish("Bath_Fixtures", coll)


def service(coll):
    """Tanque de louça com esfregador, balde e rodo. A máquina e o varal ficam em machines.py."""
    sx0, sy0, sx1, sy1 = P.SERVICE
    p = Part(bevel=0.006)
    tx0, ty0 = sx1 - 0.6, sy1 - 0.58
    p.rounded(tx0 + 0.15, ty0 + 0.1, 0, sx1 - 0.15, sy1 - 0.08, 0.64, "M_Porcelain", 0.04)
    p.box(tx0, ty0, 0.6, sx1, sy1, 0.66, "M_Porcelain", bevel=0.02)
    p.box(tx0, ty0, 0.66, sx1, ty0 + 0.04, 0.86, "M_Porcelain", bevel=0.012)
    p.box(tx0, ty0, 0.66, tx0 + 0.04, sy1, 0.86, "M_Porcelain", bevel=0.012)
    p.box(sx1 - 0.04, ty0, 0.66, sx1, sy1, 0.86, "M_Porcelain", bevel=0.012)
    p.box(tx0, sy1 - 0.04, 0.66, sx1, sy1, 0.95, "M_Porcelain", bevel=0.012)
    m = Matrix.Translation((tx0 + 0.3, ty0 + 0.2, 0.76)) @ Matrix.Rotation(0.25, 4, "X")
    p.box_m((0.5, 0.25, 0.02), m, "M_Porcelain", bevel=0.006)
    for i in range(6):
        p.box_m((0.46, 0.012, 0.004), m @ Matrix.Translation((0, -0.09 + i * 0.035, 0.011)), "M_Porcelain", bevel=0)
    p.cyl((tx0 + 0.3, sy1 - 0.06, 1.08), 0.16, 0.012, "M_Metal", axis="Y", seg=10)
    p.cyl((tx0 + 0.3, sy1 - 0.14, 1.06), 0.06, 0.012, "M_Metal", seg=10)
    p.cyl((tx0 + 0.3, sy1 - 0.02, 1.08), 0.02, 0.025, "M_Metal", axis="Y", seg=12)
    # Balde e rodo no canto.
    p.cyl((sx0 + 0.25, sy1 - 0.25, 0.14), 0.28, 0.13, "M_PlasticBlue", seg=18, radius2=0.15)
    p.cyl((sx0 + 0.25, sy1 - 0.25, 0.282), 0.012, 0.155, "M_PlasticBlue", seg=18)
    m = Matrix.Translation((sx0 + 0.08, sy1 - 0.08, 0.7)) @ Matrix.Rotation(0.12, 4, "X")
    p.cyl((0, 0, 0), 1.4, 0.012, "M_Wood", seg=8, matrix=m)
    p.box(sx0 + 0.02, sy1 - 0.25, 0, sx0 + 0.06, sy1 - 0.02, 0.06, "M_Rubber", bevel=0.004)
    p.finish("Service_Fixtures", coll)


# --- Decoração -----------------------------------------------------------------------------------

def decor(coll):
    """Pôster emoldurado, relógio, planta e tomadas."""
    p = Part(bevel=0.004)
    # Pôster com moldura (um barco num pôr do sol, em blocos de cor).
    p.box(0, 3.35, 1.25, 0.02, 4.25, 1.85, "M_PlasticBlack", bevel=0.005)
    p.box(0.02, 3.38, 1.28, 0.022, 4.22, 1.82, "M_Yellow", bevel=0)
    p.box(0.022, 3.38, 1.28, 0.024, 4.22, 1.46, "M_PlasticBlue", bevel=0)
    p.cyl((0.023, 3.95, 1.62), 0.004, 0.09, "M_Red", axis="X", seg=20)
    p.box(0.024, 3.55, 1.44, 0.026, 3.9, 1.5, "M_Wood", bevel=0)
    p.box(0.024, 3.7, 1.5, 0.026, 3.71, 1.72, "M_Wood", bevel=0)
    # Relógio na divisória, entre o banheiro e o serviço.
    cx = P.PART_X - 0.02
    p.cyl((cx, 2.25, 2.1), 0.04, 0.155, "M_PlasticBlack", axis="X", seg=28)
    p.cyl((cx - 0.021, 2.25, 2.1), 0.002, 0.135, "M_PlasticWhite", axis="X", seg=28)
    for i in range(12):
        a = i * math.tau / 12
        p.box(cx - 0.024, 2.25 + 0.12 * math.cos(a) - 0.004, 2.1 + 0.12 * math.sin(a) - 0.004,
              cx - 0.022, 2.25 + 0.12 * math.cos(a) + 0.004, 2.1 + 0.12 * math.sin(a) + 0.004,
              "M_PlasticBlack", bevel=0)
    p.box(cx - 0.027, 2.245, 2.1, cx - 0.024, 2.255, 2.2, "M_PlasticBlack", bevel=0)
    p.box(cx - 0.03, 2.25, 2.095, cx - 0.027, 2.32, 2.105, "M_PlasticBlack", bevel=0)
    p.box(cx - 0.032, 2.248, 2.03, cx - 0.03, 2.252, 2.1, "M_Red", bevel=0)
    # Planta no canto ao lado do vão do serviço: vaso com borda, terra e folhas em leque.
    p.cyl((4.7, 4.72, 0.14), 0.28, 0.13, "M_Terracotta", seg=18, radius2=0.105)
    p.cyl((4.7, 4.72, 0.29), 0.04, 0.145, "M_Terracotta", seg=18)
    p.cyl((4.7, 4.72, 0.3), 0.01, 0.13, "M_Wood", seg=18)
    for i in range(9):
        a = i * math.tau / 9
        tilt = 0.25 + 0.2 * (i % 3)
        m = Matrix.Translation((4.7 + 0.05 * math.cos(a), 4.72 + 0.05 * math.sin(a), 0.62 + 0.05 * (i % 2))) @ \
            Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(tilt, 4, "Y")
        p.box_m((0.05, 0.01, 0.62), m, "M_Plant", bevel=0.004)
    # Tomadas atrás da impressora (com benjamim) e perto da cama.
    switch_plate(p, 2.95, P.D, 0.35, "-y", sockets=2, switches=0)
    p.box(2.92, P.D - 0.06, 0.31, 2.98, P.D - 0.01, 0.39, "M_PlasticWhite", bevel=0.006)
    switch_plate(p, 1.05, P.D, 0.35, "-y", sockets=1, switches=0)
    switch_plate(p, 1.9, 0.01, 1.15, "+y", sockets=2, switches=0)
    p.finish("Decor", coll)
