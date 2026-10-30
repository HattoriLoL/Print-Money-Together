"""Coisas do dia a dia espalhadas pela kitnet (Props_<cômodo>) e as manchas nas paredes
(Decal_*). Nada aqui atrapalha a passagem: tudo fica encostado, em cima de móvel ou no canto.
Os Props_ têm colisão no Godot; os Decal_, não."""

import math

from mathutils import Matrix

import plan as P
from lib import Part, decal


def build(colls):
    c = colls["props"]
    kitchen(c)
    main_room(c)
    newspaper_window(c)
    portrait(c)
    conduit(c)
    bathroom(c)
    service(c)
    hall(c)
    decals(c)


def _can(p, x, y, z, mat, lying=False, rot=0.0):
    if lying:
        m = Matrix.Translation((x, y, z + 0.033)) @ Matrix.Rotation(rot, 4, "Z")
        p.cyl((0, 0, 0), 0.12, 0.033, mat, axis="X", seg=12, matrix=m)
    else:
        p.cyl((x, y, z + 0.06), 0.12, 0.033, mat, seg=12)
        p.cyl((x, y, z + 0.121), 0.004, 0.028, "M_Metal", seg=12)


def _bottle(p, x, y, z, h, r, body, cap):
    p.cyl((x, y, z + h * 0.4), h * 0.8, r, body, seg=12)
    p.cyl((x, y, z + h * 0.85), h * 0.1, r * 0.6, body, seg=10, radius2=r * 0.35)
    p.cyl((x, y, z + h * 0.95), h * 0.1, r * 0.35, cap, seg=8)


def kitchen(coll):
    p = Part(bevel=0.003)
    top = 0.9
    # Cafeteira na ponta direita da bancada.
    p.box(3.0, 0.1, top, 3.18, 0.32, top + 0.03, "M_PlasticBlack")
    p.box(3.0, 0.1, top, 3.18, 0.16, top + 0.32, "M_PlasticBlack")
    p.box(3.0, 0.1, top + 0.28, 3.18, 0.3, top + 0.33, "M_PlasticBlack")
    p.cyl((3.09, 0.24, top + 0.1), 0.15, 0.06, "M_Glass", seg=14)
    p.cyl((3.09, 0.24, top + 0.06), 0.06, 0.058, "M_InkBlack", seg=14)
    # Chaleira na boca de trás.
    p.cyl((2.8, 0.22, top + 0.09), 0.14, 0.08, "M_Metal", seg=16, radius2=0.06)
    p.cyl((2.8, 0.22, top + 0.17), 0.02, 0.02, "M_PlasticBlack", seg=8)
    p.box(2.79, 0.15, top + 0.15, 2.81, 0.29, top + 0.19, "M_PlasticBlack")
    m = Matrix.Translation((2.88, 0.22, top + 0.08)) @ Matrix.Rotation(0.8, 4, "Y")
    p.box_m((0.1, 0.02, 0.02), m, "M_Metal")
    # Detergente amarelo e esponja ao lado da pia.
    _bottle(p, 1.64, 0.1, top, 0.22, 0.03, "M_Yellow", "M_Red")
    p.box(1.63, 0.44, top, 1.72, 0.5, top + 0.03, "M_Yellow")
    p.box(1.63, 0.44, top + 0.03, 1.72, 0.5, top + 0.04, "M_Green")
    # Rolo de papel-toalha embaixo do armário.
    p.cyl((0.98, 0.26, 1.43), 0.25, 0.055, "M_Paper", axis="X", seg=14)
    p.box(0.84, 0.25, 1.43, 0.86, 0.27, 1.52, "M_Metal")
    p.box(1.1, 0.25, 1.43, 1.12, 0.27, 1.52, "M_Metal")
    # Lixeira de pedal no fim da bancada.
    p.cyl((3.42, 0.22, 0.2), 0.4, 0.13, "M_Metal", seg=16)
    p.cyl((3.42, 0.22, 0.41), 0.02, 0.135, "M_PlasticBlack", seg=16)
    p.box(3.38, 0.35, 0.0, 3.46, 0.42, 0.03, "M_PlasticBlack")
    # Calendário na parede entre a bancada e a porta.
    p.box(3.27, 0.0, 1.3, 3.6, 0.004, 1.75, "M_Paper")
    p.box(3.27, 0.0, 1.62, 3.6, 0.006, 1.75, "M_Red")
    for i in range(4):
        for j in range(5):
            x = 3.3 + j * 0.058
            z = 1.34 + i * 0.065
            p.box(x, 0.004, z, x + 0.045, 0.0055, z + 0.045, "M_ClothGray" if (i + j) % 7 else "M_Red")
    # Fruteira em cima da geladeira, ao lado do micro-ondas.
    p.cyl((0.6, 0.22, 1.79), 0.06, 0.1, "M_PlasticWhite", seg=14, radius2=0.08)
    for dx, dy, mat in ((-0.03, 0.0, "M_Red"), (0.03, 0.02, "M_Yellow"), (0.0, -0.04, "M_Green")):
        p.cyl((0.6 + dx, 0.22 + dy, 1.84), 0.06, 0.035, mat, seg=10)
    p.finish("Props_Kitchen", coll)


def main_room(coll):
    p = Part(bevel=0.003)
    # Roupa largada na cadeira de trás da mesa.
    for (x, y, z, sx, sy, sz, rot, mat) in (
        (2.25, 2.8, 0.47, 0.4, 0.3, 0.05, 0.3, "M_Blanket"),
        (2.2, 2.75, 0.51, 0.3, 0.25, 0.05, -0.4, "M_ClothRed"),
        (2.3, 3.0, 0.75, 0.45, 0.06, 0.25, 0.1, "M_ClothGray"),
    ):
        p.box_m((sx, sy, sz), Matrix.Translation((x, y, z)) @ Matrix.Rotation(rot, 4, "Z"), mat)
    # Tênis na entrada, encostados na divisória.
    for (x, y, rot) in ((4.78, 0.42, 0.2), (4.86, 0.6, -0.1), (4.72, 0.88, 1.3)):
        m = Matrix.Translation((x, y, 0.05)) @ Matrix.Rotation(rot, 4, "Z")
        p.box_m((0.1, 0.27, 0.07), m, "M_ClothWhite")
        p.box_m((0.11, 0.28, 0.025), m @ Matrix.Translation((0, 0, -0.035)), "M_Rubber")
    # Mochila no chão entre o guarda-roupa e o sofá.
    m = Matrix.Translation((0.32, 2.64, 0.2)) @ Matrix.Rotation(0.15, 4, "X")
    p.box_m((0.3, 0.18, 0.4), m, "M_ClothGray")
    p.box_m((0.24, 0.06, 0.18), m @ Matrix.Translation((0, -0.11, -0.06)), "M_ClothRed")
    # Notebook aberto em cima da coberta do sofá.
    m = Matrix.Translation((0.55, 3.75, 0.575)) @ Matrix.Rotation(0.4, 4, "Z")
    p.box_m((0.23, 0.32, 0.015), m, "M_PlasticBlack")
    hinge = m @ Matrix.Translation((-0.115, 0, 0.0)) @ Matrix.Rotation(-1.85, 4, "Y") @ Matrix.Translation((0.11, 0, 0))
    p.box_m((0.22, 0.32, 0.008), hinge, "M_PlasticBlack")
    p.box_m((0.19, 0.29, 0.002), hinge @ Matrix.Translation((0, 0, 0.005)), "M_LaptopScreen")
    # Latinhas de energético: no chão perto do sofá e na mesa.
    _can(p, 1.08, 3.05, 0, "M_Can")
    _can(p, 1.15, 2.95, 0, "M_Can", lying=True, rot=0.6)
    _can(p, 1.02, 4.3, 0, "M_CanBlue", lying=True, rot=-0.3)
    _can(p, 3.1, 1.8, 0.76, "M_Can")
    # Quadro de cortiça "do plano" na parede do fundo, com papéis, fotos e barbante vermelho.
    bx0, bx1, bz0, bz1 = 3.6, 4.6, 1.25, 1.95
    y = P.D
    p.box(bx0, y - 0.025, bz0, bx1, y, bz1, "M_Wood")
    p.box(bx0 + 0.03, y - 0.03, bz0 + 0.03, bx1 - 0.03, y - 0.025, bz1 - 0.03, "M_Cork")
    pins = []
    for (x, z, w, h, mat) in ((3.68, 1.62, 0.2, 0.26, "M_Paper"), (3.95, 1.7, 0.16, 0.18, "M_ClothWhite"),
                              (4.2, 1.55, 0.3, 0.2, "M_Paper"), (3.75, 1.32, 0.22, 0.16, "M_Money"),
                              (4.1, 1.3, 0.14, 0.18, "M_ClothWhite"), (4.35, 1.33, 0.18, 0.14, "M_Paper")):
        p.box(x, y - 0.034, z, x + w, y - 0.03, z + h, mat)
        pins.append((x + w / 2, z + h - 0.02))
        p.box(x + w / 2 - 0.008, y - 0.04, z + h - 0.028, x + w / 2 + 0.008, y - 0.034, z + h - 0.012, "M_Red")
    for (ax, az), (bx, bz) in ((pins[0], pins[2]), (pins[1], pins[4]), (pins[3], pins[2]), (pins[4], pins[5])):
        length = math.hypot(bx - ax, bz - az)
        m = Matrix.Translation(((ax + bx) / 2, y - 0.037, (az + bz) / 2)) @ \
            Matrix.Rotation(-math.atan2(bz - az, bx - ax), 4, "Y")
        p.box_m((length, 0.002, 0.004), m, "M_Red")
    # Tomadas: atrás da TV e perto do sofá.
    for (x, yy, z, axis) in ((P.PART_X - 0.005, 2.0, 0.3, "x"), (0.005, 2.7, 0.3, "x")):
        p.box(x - 0.005, yy - 0.04, z, x + 0.005, yy + 0.04, z + 0.1, "M_PlasticWhite")
    # Caixas de pizza: pilha torta perto da divisória e uma aberta, comida pela metade, no sofá.
    _pizza_stack(p, 4.5, 4.0, 0.0, 5, 0.22)
    _pizza_open(p, 0.56, 4.35, 0.575, 1.3)
    p.finish("Props_Main", coll)


def _pizza_stack(p, x, y, z, n, rot):
    """Pilha de `n` caixas fechadas, cada uma girada um tantinho, com a tampa de cima ilustrada."""
    h = 0.06
    for i in range(n):
        m = Matrix.Translation((x, y, z + h * i + h / 2)) @ Matrix.Rotation(rot + (i % 2 - 0.5) * 0.12 * (i + 1), 4, "Z")
        p.box_m((0.36, 0.36, h), m, "M_PizzaBox", bevel=0.004)
        p.box_m((0.368, 0.368, 0.004), m @ Matrix.Translation((0, 0, 0.016)), "M_Cardboard", bevel=0.001)
    top = z + h * n
    m = Matrix.Translation((x, y, top)) @ Matrix.Rotation(rot + (((n - 1) % 2) - 0.5) * 0.12 * n, 4, "Z")
    c = [m @ Matrix.Translation((sx * 0.17, sy * 0.17, 0.0015)).translation for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    p.quad(c, "M_PizzaLid", double=False)


def _pizza_open(p, x, y, z, rot):
    """Caixa aberta: fundo com a pizza (uma fatia a menos), tampa levantada atrás e uma fatia solta."""
    base = Matrix.Translation((x, y, z)) @ Matrix.Rotation(rot, 4, "Z")
    p.box_m((0.36, 0.36, 0.04), base @ Matrix.Translation((0, 0, 0.02)), "M_PizzaBox", bevel=0.004)
    # Pizza: disco de massa, queijo e pepperoni; a fatia que falta fica como um recorte escuro.
    p.cyl((0, 0, 0), 0.012, 0.16, "M_Cardboard", seg=20, matrix=base @ Matrix.Translation((0, 0, 0.045)))
    p.cyl((0, 0, 0), 0.006, 0.145, "M_Cheese", seg=20, matrix=base @ Matrix.Translation((0, 0, 0.054)))
    for (px, py) in ((-0.06, 0.04), (0.05, 0.07), (-0.03, -0.06), (0.08, -0.04), (0.0, 0.0)):
        p.cyl((0, 0, 0), 0.004, 0.026, "M_Pepperoni", seg=10, matrix=base @ Matrix.Translation((px, py, 0.059)))
    p.box_m((0.12, 0.12, 0.008), base @ Matrix.Translation((0.1, -0.1, 0.05)) @ Matrix.Rotation(0.785, 4, "Z"),
            "M_PizzaBox", bevel=0)
    # Tampa aberta para trás (dobradiça na borda de trás), com o desenho para dentro da sala.
    hinge = base @ Matrix.Translation((0, 0.18, 0.04)) @ Matrix.Rotation(-1.9, 4, "X")
    p.box_m((0.36, 0.36, 0.012), hinge @ Matrix.Translation((0, -0.18, 0.006)), "M_PizzaBox", bevel=0.003)
    # O desenho vai na face de dentro da tampa (a que fica virada para a sala).
    c = [hinge @ Matrix.Translation((sx * 0.17, -0.18 + sy * 0.17, -0.0015)).translation
         for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    p.quad(list(reversed(c)), "M_PizzaLid", uvs=((0, 1), (1, 1), (1, 0), (0, 0)), double=False)


def newspaper_window(coll):
    """Jornal colado no vidro da janela principal (por dentro, atrás da cortina) com silver tape nos
    cantos, para ninguém de fora ver a impressora. Fica um vão no canto de cima. Sem colisão."""
    gy = P.D + 0.1 - 0.012         # na frente do vidro (que fica no meio da parede)
    p = Part()
    sheets = ((1.86, 1.33, 0.44, 0.58, 0.05), (2.28, 1.34, 0.42, 0.56, -0.07),
              (2.74, 1.31, 0.44, 0.6, -0.04), (3.16, 1.34, 0.42, 0.56, 0.1),
              (1.84, 1.89, 0.44, 0.58, -0.09), (2.27, 1.87, 0.42, 0.56, 0.06),
              (2.77, 1.9, 0.44, 0.58, 0.12))   # sem folha no canto de cima à direita
    for k, (cx, cz, w, h, rot) in enumerate(sheets):
        y = gy - 0.0015 * k
        c, s = math.cos(rot), math.sin(rot)
        corners = []
        for (u, v) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            du, dv = u * w / 2, v * h / 2
            corners.append((cx + du * c - dv * s, y, cz + du * s + dv * c))
        # De dentro da sala (olhando para +Y) o U cresce para +X e a face aponta para -Y.
        p.quad(corners, "M_Newspaper", double=True)
        # Dois pedaços de silver tape nos cantos de cima, em X.
        for sx in (-1, 1):
            tx, tz = cx + sx * (w / 2 - 0.03), cz + h / 2 - 0.02
            m = Matrix.Translation((tx, y - 0.0012, tz)) @ Matrix.Rotation(-sx * 0.8 + rot, 4, "Y")
            p.box_m((0.1, 0.0015, 0.032), m, "M_SilverTape", bevel=0)
    p.finish("Newspaper_Window", coll)


def portrait(coll):
    """Retrato a óleo do presidente (inventado) na parede do oeste, em cima do sofá-cama: moldura
    dourada gorda e torta, plaquinha e um prego. Pendurado em x = 0, olhando para +X."""
    y0, y1, z0, z1 = 2.7, 3.2, 1.36, 2.0
    t = 0.05
    fr = 0.06
    p = Part(bevel=0.008)
    p.box(0.0, y0 - fr, z0 - fr, t, y1 + fr, z0, "M_InkGold")
    p.box(0.0, y0 - fr, z1, t, y1 + fr, z1 + fr, "M_InkGold")
    p.box(0.0, y0 - fr, z0, t, y0, z1, "M_InkGold")
    p.box(0.0, y1, z0, t, y1 + fr, z1, "M_InkGold")
    p.box(0.0, y0, z0, 0.012, y1, z1, "M_Wood")
    # Enfeites nos cantos da moldura.
    for yy in (y0 - fr, y1 + fr):
        for zz in (z0 - fr, z1 + fr):
            p.cyl((t, yy, zz), 0.03, 0.04, "M_InkGold", axis="X", seg=14)
    p.quad(((0.0125, y0, z0), (0.0125, y1, z0), (0.0125, y1, z1), (0.0125, y0, z1)), "M_Portrait", double=False)
    # Fita de luto: laço vermelho no topo.
    p.cyl((t + 0.01, (y0 + y1) / 2, z1 + fr + 0.015), 0.03, 0.035, "M_Red", axis="X", seg=10)
    p.finish("Props_Portrait", coll, loc=(0.0, 0.0, 0.0))


def conduit(coll):
    """Eletroduto aparente: da lâmpada pelo teto até a moldura de gesso (o trecho ao longo da
    divisória corre escondido dentro dela) e descendo da moldura até o interruptor da entrada."""
    p = Part(bevel=0.003)
    z = P.WALL_H - 0.02
    r = 0.012
    x_in = P.PART_X - 0.03            # entra na moldura
    x_down = P.PART_X - 0.015         # desce colado na divisória
    z_out = P.WALL_H - 0.07           # sai por baixo da moldura
    p.cyl(((2.6 + x_in) / 2 + 0.02, 2.7, z), x_in - 2.6 + 0.04, r, "M_PlasticWhite", axis="X", seg=10)
    p.cyl((x_down, 0.24, (1.31 + z_out) / 2), z_out - 1.31, r, "M_PlasticWhite", seg=10)
    for x in (3.2, 4.2):
        p.box(x - 0.015, 2.7 - 0.02, z - 0.015, x + 0.015, 2.7 + 0.02, P.WALL_H, "M_Metal")
    for zz in (2.0, 1.6):
        p.box(x_down - 0.015, 0.24 - 0.02, zz - 0.015, P.PART_X, 0.24 + 0.02, zz + 0.015, "M_Metal")
    p.finish("Props_Conduit", coll)


def bathroom(coll):
    p = Part(bevel=0.003)
    # Tapete na frente do box.
    p.box(6.1, 1.05, 0, 6.65, 1.42, 0.012, "M_BathMat")
    # Xampu, condicionador e sabonete no canto do box.
    _bottle(p, 6.9, 0.1, 0.0, 0.24, 0.035, "M_PlasticBlue", "M_PlasticWhite")
    _bottle(p, 6.82, 0.08, 0.0, 0.2, 0.032, "M_ClothRed", "M_PlasticWhite")
    p.box(6.88, 0.2, 0.0, 6.96, 0.25, 0.03, "M_Green")
    # Copo de escova na pia e escova do vaso.
    p.cyl((5.66, 2.14, 0.91), 0.1, 0.028, "M_PlasticBlue", seg=12)
    p.cyl((5.66, 2.14, 1.0), 0.12, 0.004, "M_Yellow", seg=6)
    p.cyl((6.78, 2.1, 0.1), 0.2, 0.05, "M_PlasticWhite", seg=10)
    p.cyl((6.78, 2.1, 0.3), 0.25, 0.008, "M_PlasticWhite", seg=6)
    # Grelha de ventilação no alto da parede do fundo.
    p.box(5.55, P.BATH_Y - 0.012, 2.05, 5.8, P.BATH_Y - 0.002, 2.25, "M_PlasticWhite")
    for i in range(5):
        z = 2.08 + i * 0.035
        p.box(5.57, P.BATH_Y - 0.016, z, 5.78, P.BATH_Y - 0.012, z + 0.012, "M_PlasticBlack")
    p.finish("Props_Bath", coll)


def service(coll):
    sx0, sy0, sx1, sy1 = P.SERVICE
    p = Part(bevel=0.003)
    # Botijão de gás P13 com regulador e mangueira.
    bx, by = 6.08, sy1 - 0.24
    p.cyl((bx, by, 0.03), 0.06, 0.16, "M_Gas", seg=18)
    p.cyl((bx, by, 0.27), 0.42, 0.18, "M_Gas", seg=18)
    p.cyl((bx, by, 0.5), 0.06, 0.15, "M_Gas", seg=18, radius2=0.07)
    p.cyl((bx, by, 0.58), 0.1, 0.07, "M_Gas", seg=14)
    p.cyl((bx, by, 0.64), 0.04, 0.03, "M_Metal", seg=10)
    p.cyl((bx, by, 0.68), 0.03, 0.04, "M_InkGold", seg=10)
    m = Matrix.Translation((bx - 0.12, by, 0.62)) @ Matrix.Rotation(0.5, 4, "Y")
    p.box_m((0.22, 0.02, 0.02), m, "M_PlasticBlack")
    # Cesto de roupa suja com roupa saindo.
    p.cyl((5.45, 4.3, 0.22), 0.44, 0.2, "M_PlasticWhite", seg=16, radius2=0.22)
    for (x, y, z, rot, mat) in ((5.43, 4.28, 0.45, 0.3, "M_Blanket"), (5.5, 4.33, 0.47, -0.5, "M_ClothRed"),
                                (5.38, 4.35, 0.46, 1.1, "M_ClothWhite")):
        p.box_m((0.3, 0.2, 0.06), Matrix.Translation((x, y, z)) @ Matrix.Rotation(rot, 4, "Z"), mat)
    # Tábua de passar fechada, encostada na divisória.
    m = Matrix.Translation((sx0 + 0.07, 4.65, 0.62)) @ Matrix.Rotation(-0.1, 4, "Y")
    p.box_m((0.04, 0.32, 1.25), m, "M_ClothGray")
    p.box_m((0.06, 0.05, 1.2), m @ Matrix.Translation((0.03, 0.0, -0.02)), "M_Metal")
    # Sabão e amaciante em cima da máquina.
    for (x, y, h, mat) in ((6.92, 3.66, 0.2, "M_PlasticBlue"), (6.92, 3.58, 0.17, "M_Green")):
        p.box(x - 0.04, y - 0.035, 1.04, x + 0.04, y + 0.035, 1.04 + h, mat)
        p.cyl((x, y, 1.04 + h + 0.015), 0.03, 0.02, "M_PlasticWhite", seg=8)
    p.finish("Props_Service", coll)


def hall(coll):
    hy0, hy1 = P.HALL_Y
    p = Part(bevel=0.003)
    # Saco de lixo do vizinho do 302 esperando ser descido.
    p.cyl((9.35, hy1 - 0.3, 0.2), 0.4, 0.2, "M_TrashBag", seg=12, radius2=0.14)
    p.cyl((9.35, hy1 - 0.3, 0.45), 0.1, 0.06, "M_TrashBag", seg=8, radius2=0.02)
    # Sapateira na porta do 303.
    p.box(2.2, hy0, 0, 2.8, hy0 + 0.28, 0.04, "M_Wood")
    p.box(2.2, hy0, 0.2, 2.8, hy0 + 0.28, 0.23, "M_Wood")
    for x, mat in ((2.3, "M_ClothWhite"), (2.5, "M_Rubber"), (2.68, "M_ClothRed")):
        p.box(x - 0.05, hy0 + 0.02, 0.04, x + 0.05, hy0 + 0.27, 0.11, mat)
        p.box(x - 0.05, hy0 + 0.02, 0.23, x + 0.05, hy0 + 0.27, 0.29, "M_ClothGray")
    # Vaso com planta no fim do corredor.
    px, py = P.HALL_X[1] - 0.35, hy0 + 0.35
    p.cyl((px, py, 0.2), 0.4, 0.17, "M_Terracotta", seg=14, radius2=0.13)
    for i in range(7):
        a = i * math.tau / 7
        m = Matrix.Translation((px + 0.06 * math.cos(a), py + 0.06 * math.sin(a), 0.7)) @ \
            Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(0.35, 4, "Y")
        p.box_m((0.05, 0.14, 0.7), m, "M_Plant")
    p.finish("Props_Hall", coll)


def decals(coll):
    """Mofo, infiltração, encardido e rachaduras. Ficam 3 mm na frente da superfície."""
    e = 0.003
    p = Part()
    # Mofo no canto do fundo, em cima do sofá, e infiltração no teto.
    decal(p, (e, 4.6, 2.3), "+x", 0.9, 0.7, "M_DecalMold", rot=0.3)
    decal(p, (0.4, P.D - e, 2.35), "-y", 0.8, 0.5, "M_DecalMold", rot=-0.2)
    decal(p, (0.9, 4.0, P.WALL_H - e), "-z", 1.1, 0.9, "M_DecalWater", rot=0.5)
    # Escorrido embaixo do basculante do serviço e mancha no forro do banheiro.
    decal(p, (5.95, P.D - e, 1.0), "-y", 0.5, 0.6, "M_DecalWater")
    decal(p, (6.6, 0.5, P.BATH_CEILING_Z - e), "-z", 0.6, 0.5, "M_DecalMold")
    # Encardido de mão em volta do interruptor e atrás do fogão.
    decal(p, (P.PART_X - e, 0.24, 1.25), "-x", 0.3, 0.35, "M_DecalGrime")
    decal(p, (2.62, 0.01 + e, 1.2), "+y", 0.7, 0.5, "M_DecalGrime", rot=0.4)
    # Corredor: infiltração no alto e marca de sapato na parede.
    decal(p, (6.5, P.HALL_Y[0] + 0.006 + e, 2.3), "+y", 1.4, 0.6, "M_DecalWater", rot=0.1)
    decal(p, (1.0, -P.EXT_T - 0.006 - e, 0.35), "-y", 0.6, 0.3, "M_DecalGrime")
    decal(p, (5.5, P.HALL_Y[0] + 0.006 + e, 0.3), "+y", 0.5, 0.25, "M_DecalGrime", rot=0.2)
    # Rachaduras no reboco: perto da janela, no alto da parede da esquerda, embaixo no fundo e
    # no corredor.
    decal(p, (1.2, P.D - e, 1.9), "-y", 0.7, 0.45, "M_DecalCrack", rot=0.5)
    decal(p, (e, 2.2, 2.25), "+x", 0.6, 0.4, "M_DecalCrack", rot=-0.3)
    decal(p, (3.8, P.D - e, 0.6), "-y", 0.5, 0.35, "M_DecalCrack", rot=2.6)
    decal(p, (3.2, P.HALL_Y[0] + 0.006 + e, 1.7), "+y", 0.8, 0.5, "M_DecalCrack", rot=-0.2)
    p.finish("Decal_Stains", coll)
