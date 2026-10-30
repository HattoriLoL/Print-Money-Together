"""Casca da kitnet e do corredor: pisos, paredes, forros, janelas, portas, luzes e marcadores."""

import math

import plan as P
from lib import Part, digits, empty, point_light, wall

H = P.WALL_H
HX0, HX1 = P.HALL_X
HY0, HY1 = P.HALL_Y


def build(colls):
    floors(colls["structure"])
    walls(colls["structure"])
    ceilings(colls["structure"])
    windows(colls["structure"])
    doors(colls["structure"])
    lights(colls["lights"])
    markers(colls["markers"])


def floors(coll):
    mid = P.PART_X + P.INT_T / 2
    p = Part()
    p.box(-P.EXT_T, -P.EXT_T, -0.1, mid, P.D + P.EXT_T, 0, "M_Floor")
    p.box(mid, P.BATH_Y + P.INT_T / 2, -0.1, P.W + P.EXT_T, P.D + P.EXT_T, 0, "M_Floor")
    p.box(mid, -P.EXT_T, -0.1, P.W + P.EXT_T, P.BATH_Y + P.INT_T / 2, 0, "M_FloorBath")
    p.finish("Floor_Kitnet", coll)

    p = Part()
    p.box(HX0 - P.EXT_T, HY0 - P.EXT_T, -0.1, HX1 + P.EXT_T, -P.EXT_T, 0, "M_FloorHall")
    p.finish("Floor_Hall", coll)


def walls(coll):
    door = lambda span: (span[0], span[1], 0.0, P.DOOR_H)
    p = Part()
    # Fundo, oeste e leste.
    wall(p, "x", P.D, P.D + P.EXT_T, -P.EXT_T, P.W + P.EXT_T, "M_Wall", H,
         [P.WINDOW_MAIN, P.WINDOW_SERVICE])
    wall(p, "y", -P.EXT_T, 0, 0, P.D, "M_Wall", H)
    wall(p, "y", P.W, P.W + P.EXT_T, 0, P.D, "M_Wall", H, [P.WINDOW_BATH])
    # Frente: metade de dentro com a tinta da kitnet (e do 302 depois da divisa).
    wall(p, "x", -P.EXT_T / 2, 0, HX0 - P.EXT_T, HX1 + P.EXT_T, "M_Wall", H,
         [door(P.ENTRANCE), door(P.DOOR_302)])
    # Divisória do banheiro/serviço e a parede entre os dois.
    wall(p, "y", P.PART_X, P.PART_X + P.INT_T, 0, P.D, "M_Wall", H,
         [door(P.BATH_DOOR), door(P.SERVICE_OPENING)])
    wall(p, "x", P.BATH_Y, P.BATH_Y + P.INT_T, P.PART_X + P.INT_T, P.W, "M_Wall", H)
    p.finish("Walls_Kitnet", coll)

    # Corredor: a metade de fora da frente, o outro lado e as pontas.
    p = Part()
    wall(p, "x", -P.EXT_T, -P.EXT_T / 2, HX0 - P.EXT_T, HX1 + P.EXT_T, "M_WallHall", H,
         [door(P.ENTRANCE), door(P.DOOR_302)])
    wall(p, "x", HY0 - P.EXT_T, HY0, HX0 - P.EXT_T, HX1 + P.EXT_T, "M_WallHall", H, [door(P.DOOR_303)])
    wall(p, "y", HX0 - P.EXT_T, HX0, HY0, HY1, "M_WallHall", H, [door(P.STAIRS_DOOR)])
    wall(p, "y", HX1, HX1 + P.EXT_T, HY0, HY1, "M_WallHall", H, [(-1.1, -0.6, 1.0, 2.0)])
    # Barra pintada até 1,1 m nas duas paredes compridas.
    wall(p, "x", -P.EXT_T - 0.006, -P.EXT_T, HX0, HX1, "M_WallHallLow", 1.1,
         [door(P.ENTRANCE), door(P.DOOR_302)])
    wall(p, "x", HY0, HY0 + 0.006, HX0, HX1, "M_WallHallLow", 1.1, [door(P.DOOR_303)])
    # Atrás das portas fechadas dos vizinhos e da escada: escuro.
    p.box(P.DOOR_302[0], 0.0, 0, P.DOOR_302[1], 0.3, P.DOOR_H, "M_Void")
    p.box(P.DOOR_303[0], HY0 - P.EXT_T - 0.3, 0, P.DOOR_303[1], HY0 - P.EXT_T, P.DOOR_H, "M_Void")
    p.box(HX0 - P.EXT_T - 0.3, P.STAIRS_DOOR[0], 0, HX0 - P.EXT_T, P.STAIRS_DOOR[1], P.DOOR_H, "M_Void")
    # Extintor e o número do andar.
    p.box(HX1 - 1.2, HY0, 1.05, HX1 - 0.9, HY0 + 0.04, 1.65, "M_Red")
    p.cyl((HX1 - 1.05, HY0 + 0.15, 0.62), 0.5, 0.08, "M_Red", seg=12)
    p.cyl((HX1 - 1.05, HY0 + 0.15, 0.92), 0.08, 0.03, "M_MetalDark", seg=8)
    p.finish("Walls_Hall", coll)

    hall_details(coll)


def hall_details(coll):
    """Placa do andar, campainhas, medidores de luz e quadro de avisos do corredor."""
    p = Part()
    # Placa "3" (3º andar) virada para quem sai da escada.
    p.box(HX0 + 0.3, HY0, 1.55, HX0 + 0.75, HY0 + 0.012, 2.0, "M_PlasticWhite")
    digits(p, "3", HX0 + 0.525, 1.62, 0.3, HY0 + 0.012, "M_InkBlack", depth=0.006, facing="+y")
    # Campainhas ao lado das portas da 301 e da 302.
    for x in (P.ENTRANCE[1] + 0.15, P.DOOR_302[1] + 0.15):
        p.box(x - 0.035, -P.EXT_T - 0.015, 1.35, x + 0.035, -P.EXT_T, 1.45, "M_PlasticWhite")
        p.cyl((x, -P.EXT_T - 0.02, 1.4), 0.012, 0.012, "M_InkGold", axis="Y", seg=10)
    # Quadro de medidores (relógios de luz) perto da escada, com visor de vidro.
    p.box(HX0 + 0.1, -P.EXT_T - 0.16, 1.1, HX0 + 0.9, -P.EXT_T, 1.95, "M_MetalDark")
    p.box(HX0 + 0.15, -P.EXT_T - 0.165, 1.15, HX0 + 0.85, -P.EXT_T - 0.16, 1.9, "M_Metal")
    for i in range(3):
        x = HX0 + 0.27 + i * 0.23
        p.box(x - 0.08, -P.EXT_T - 0.17, 1.45, x + 0.08, -P.EXT_T - 0.165, 1.65, "M_Glass")
    p.cyl((HX0 + 0.8, -P.EXT_T - 0.17, 1.52), 0.02, 0.015, "M_PlasticBlack", axis="Y", seg=8)
    # Quadro de avisos do condomínio com papéis presos.
    bx0, bx1 = 0.0, 0.9
    p.box(bx0, HY0, 1.2, bx1, HY0 + 0.02, 1.85, "M_Wood")
    p.box(bx0 + 0.03, HY0 + 0.02, 1.23, bx1 - 0.03, HY0 + 0.025, 1.82, "M_Cork")
    for x, z, w, h in ((0.08, 1.5, 0.21, 0.28), (0.34, 1.55, 0.21, 0.24), (0.6, 1.3, 0.15, 0.2),
                       (0.62, 1.55, 0.22, 0.22), (0.12, 1.27, 0.25, 0.18)):
        p.box(bx0 + x, HY0 + 0.025, z, bx0 + x + w, HY0 + 0.028, z + h, "M_Paper")
        p.box(bx0 + x + w / 2 - 0.01, HY0 + 0.028, z + h - 0.03, bx0 + x + w / 2 + 0.01, HY0 + 0.035,
              z + h - 0.01, "M_Red")
    p.box(bx0 + 0.36, HY0 + 0.028, 1.74, bx0 + 0.53, HY0 + 0.03, 1.79, "M_Red")
    p.finish("Hall_Details", coll)

    tiles_and_trim(coll)


def tiles_and_trim(coll):
    """Azulejo do banheiro e da cozinha, rodapé e manchas de mofo."""
    t = 0.01
    bx0, by0, bx1, by1 = P.BATH
    hz = P.BATH_CEILING_Z
    p = Part()
    wall(p, "y", bx0, bx0 + t, by0, by1, "M_Tile", hz, [(P.BATH_DOOR[0], P.BATH_DOOR[1], 0, P.DOOR_H)])
    wall(p, "y", bx1 - t, bx1, by0, by1, "M_Tile", hz, [P.WINDOW_BATH])
    wall(p, "x", by0, by0 + t, bx0 + t, bx1 - t, "M_Tile", hz)
    wall(p, "x", by1 - t, by1, bx0 + t, bx1 - t, "M_Tile", hz)
    # Faixa de azulejo atrás da pia e do tanque.
    p.box(0.75, 0, 0.9, 3.25, t, 1.5, "M_TileKitchen")
    p.box(6.3, P.D - t, 0.8, P.W, P.D, 1.5, "M_Tile")
    p.box(P.W - t, 4.3, 0.8, P.W, P.D - t, 1.5, "M_Tile")
    p.finish("Tiles", coll)

    r, bh = 0.012, 0.07
    p = Part()
    p.box(0, 0.75, 0, r, P.D, bh, "M_Baseboard")
    p.box(0, P.D - r, 0, P.PART_X, P.D, bh, "M_Baseboard")
    p.box(3.2, 0, 0, P.ENTRANCE[0], r, bh, "M_Baseboard")
    p.box(P.ENTRANCE[1], 0, 0, P.PART_X, r, bh, "M_Baseboard")
    for y0, y1 in ((0, P.BATH_DOOR[0]), (P.BATH_DOOR[1], P.SERVICE_OPENING[0]), (P.SERVICE_OPENING[1], P.D)):
        p.box(P.PART_X - r, y0, 0, P.PART_X, y1, bh, "M_Baseboard")
    sx0, sy0, sx1, sy1 = P.SERVICE
    p.box(sx0, sy0, 0, sx0 + r, P.SERVICE_OPENING[0], bh, "M_Baseboard")
    p.box(sx0, P.SERVICE_OPENING[1], 0, sx0 + r, sy1, bh, "M_Baseboard")
    p.box(sx0, sy0, 0, sx1, sy0 + r, bh, "M_Baseboard")
    p.box(sx1 - r, sy0, 0, sx1, 4.3, bh, "M_Baseboard")
    # Rodapé de granito no corredor, na frente da barra pintada.
    door = lambda span: (span[0], span[1], 0.0, P.DOOR_H)
    wall(p, "x", -P.EXT_T - 0.018, -P.EXT_T - 0.006, HX0, HX1, "M_Granite", bh,
         [door(P.ENTRANCE), door(P.DOOR_302)])
    wall(p, "x", HY0 + 0.006, HY0 + 0.018, HX0, HX1, "M_Granite", bh, [door(P.DOOR_303)])
    p.finish("Baseboard", coll)

    # Soleiras de granito nas passagens (6 mm acima do piso).
    p = Part(bevel=0.002)
    p.box(P.ENTRANCE[0], -P.EXT_T, 0, P.ENTRANCE[1], 0, 0.006, "M_Granite")
    p.box(P.PART_X, P.BATH_DOOR[0], 0, P.PART_X + P.INT_T, P.BATH_DOOR[1], 0.006, "M_Granite")
    p.box(P.PART_X, P.SERVICE_OPENING[0], 0, P.PART_X + P.INT_T, P.SERVICE_OPENING[1], 0.006, "M_Granite")
    p.finish("Thresholds", coll)

    crown_molding(coll)


def crown_molding(coll):
    """Moldura de gesso em dois degraus em volta do teto do cômodo principal. A fiação do
    eletroduto some dentro dela (ver props.conduit)."""
    a, za = 0.035, H - 0.045   # degrau de cima: sai 3,5 cm da parede
    b, zb = 0.018, H - 0.07    # degrau de baixo
    p = Part()
    for depth, z0, z1, bev in ((a, za, H, 0.012), (b, zb, za, 0.006)):
        p.box(0, 0, z0, depth, P.D, z1, "M_Ceiling", bevel=bev)
        p.box(0, P.D - depth, z0, P.PART_X, P.D, z1, "M_Ceiling", bevel=bev)
        p.box(0, 0, z0, P.PART_X, depth, z1, "M_Ceiling", bevel=bev)
        p.box(P.PART_X - depth, 0, z0, P.PART_X, P.D, z1, "M_Ceiling", bevel=bev)
    p.finish("Crown_Molding", coll)


def ceilings(coll):
    p = Part()
    p.box(-P.EXT_T, -P.EXT_T, H, P.W + P.EXT_T, P.D + P.EXT_T, H + 0.12, "M_Ceiling")
    p.box(HX0 - P.EXT_T, HY0 - P.EXT_T, H, HX1 + P.EXT_T, -P.EXT_T, H + 0.12, "M_Ceiling")
    p.finish("Ceiling", coll)

    # Forro de PVC do banheiro, com o buraco do alçapão (entre o forro e a laje cabe um pacote).
    bx0, by0, bx1, by1 = P.BATH
    hx0, hx1, hy0, hy1 = P.BATH_HATCH
    z0, z1 = P.BATH_CEILING_Z, P.BATH_CEILING_Z + 0.04
    p = Part()
    p.box(bx0, by0, z0, bx1, hy0, z1, "M_PVC")
    p.box(bx0, hy1, z0, bx1, by1, z1, "M_PVC")
    p.box(bx0, hy0, z0, hx0, hy1, z1, "M_PVC")
    p.box(hx1, hy0, z0, bx1, hy1, z1, "M_PVC")
    p.finish("Ceiling_BathPVC", coll)

    # A tampa do alçapão fica solta: o Godot levanta e afasta.
    p = Part()
    p.box(-0.24, -0.24, 0, 0.24, 0.24, 0.02, "M_PVC")
    p.box(-0.04, -0.01, -0.01, 0.04, 0.01, 0, "M_PlasticBlack")
    p.finish("KEEP_BathHatch", coll, loc=((hx0 + hx1) / 2, (hy0 + hy1) / 2, z0))


def _window(frame, glass, axis, t0, t1, a0, a1, bot, top, split=True, glass_mat="M_Glass"):
    """Caixilho de alumínio no meio da parede, vidro e peitoril de granito do lado de dentro."""
    tm = (t0 + t1) / 2
    fw, fd = 0.04, 0.06

    def bx(s0, s1, u0, u1, z0, z1, mat, part):
        if axis == "x":
            part.box(s0, u0, z0, s1, u1, z1, mat)
        else:
            part.box(u0, s0, z0, u1, s1, z1, mat)

    bx(a0, a1, tm - fd / 2, tm + fd / 2, bot, bot + fw, "M_Metal", frame)
    bx(a0, a1, tm - fd / 2, tm + fd / 2, top - fw, top, "M_Metal", frame)
    bx(a0, a0 + fw, tm - fd / 2, tm + fd / 2, bot, top, "M_Metal", frame)
    bx(a1 - fw, a1, tm - fd / 2, tm + fd / 2, bot, top, "M_Metal", frame)
    if split:
        mid = (a0 + a1) / 2
        bx(mid - fw / 2, mid + fw / 2, tm - fd / 2, tm + fd / 2, bot, top, "M_Metal", frame)
    else:
        # Basculante: travessa no meio da altura.
        zm = (bot + top) / 2
        bx(a0, a1, tm - fd / 2, tm + fd / 2, zm - fw / 2, zm + fw / 2, "M_Metal", frame)
    bx(a0 + fw, a1 - fw, tm - 0.004, tm + 0.004, bot + fw, top - fw, glass_mat, glass)


def windows(coll):
    frame, glass = Part(bevel=0.003), Part()
    d0, d1 = P.D, P.D + P.EXT_T
    x0, x1, bot, top = P.WINDOW_MAIN
    _window(frame, glass, "x", d0, d1, x0, x1, bot, top)
    frame.box(x0 - 0.05, d0 - 0.05, bot - 0.03, x1 + 0.05, d0 + 0.1, bot, "M_Granite")
    # Grade do lado de fora: barras a cada 12 cm e duas chatas atravessadas.
    gy0, gy1 = d1 + 0.02, d1 + 0.04
    n = int((x1 - x0) / 0.12)
    for i in range(n + 1):
        x = x0 + i * (x1 - x0) / n
        frame.box(x - 0.008, gy0, bot - 0.02, x + 0.008, gy1, top + 0.02, "M_MetalDark")
    for z in (bot + 0.05, (bot + top) / 2, top - 0.05):
        frame.box(x0 - 0.04, gy0 - 0.005, z - 0.02, x1 + 0.04, gy1 + 0.005, z + 0.02, "M_MetalDark")
    x0, x1, bot, top = P.WINDOW_SERVICE
    _window(frame, glass, "x", d0, d1, x0, x1, bot, top, split=False, glass_mat="M_GlassFrosted")
    frame.box(x0 - 0.03, d0 - 0.03, bot - 0.03, x1 + 0.03, d0 + 0.1, bot, "M_Granite")
    y0, y1, bot, top = P.WINDOW_BATH
    _window(frame, glass, "y", P.W, P.W + P.EXT_T, y0, y1, bot, top, split=False, glass_mat="M_GlassFrosted")
    _window(frame, glass, "y", HX1, HX1 + P.EXT_T, -1.1, -0.6, 1.0, 2.0)
    frame.finish("Window_Frames", coll)
    glass.finish("Glass_Windows", coll)

    # Cortina da janela principal, meio aberta: fechar esconde a impressora de quem olha de fora.
    x0, x1, _, top = P.WINDOW_MAIN
    p = Part()
    # Na frente do peitoril (que salta até y D - 0,05), senão a onda do pano atravessa o granito.
    cy = P.D - 0.085
    rod_z = top + 0.12
    p.cyl(((x0 + x1) / 2, cy, rod_z), x1 - x0 + 0.5, 0.012, "M_Metal", axis="X", seg=12)
    for x in (x0 - 0.25, x1 + 0.25):
        p.cyl((x, cy, rod_z), 0.04, 0.02, "M_Metal", axis="X", seg=12)
        p.box(x - 0.01, cy, rod_z - 0.01, x + 0.01, P.D, rod_z + 0.01, "M_Metal")
    for a, b in ((x0 - 0.2, x0 + 0.45), (x1 - 0.45, x1 + 0.2)):
        p.sheet(a, b, cy, cy, 0.9, top + 0.1, "M_Curtain", waves=7, amp=0.022, seg=42)
        for i in range(8):
            p.cyl((a + 0.02 + i * (b - a - 0.04) / 7, cy, rod_z), 0.012, 0.02, "M_Metal", axis="X", seg=10)
    p.finish("Curtain_Main", coll)


# Altura das molduras das almofadas das portas (as trancas da 301 nascem em cima delas).
MOLDING = 0.01


def _door_frame(p, axis, t0, t1, a0, a1, h, mat):
    """Batente dentro do vão e guarnição saltada nas duas faces."""
    gw, gp, lt = 0.06, 0.016, 0.02

    def bx(s0, s1, u0, u1, z0, z1, side=None):
        if side is None:
            if axis == "x":
                p.box(s0, u0, z0, s1, u1, z1, mat)
            else:
                p.box(u0, s0, z0, u1, s1, z1, mat)
            return
        # Guarnição: friso chanfrado virado para fora da parede.
        face = ("+" if side > 0 else "-") + ("y" if axis == "x" else "x")
        if axis == "x":
            p.trim(s0, u0, z0, s1, u1, z1, mat, face, 0.012)
        else:
            p.trim(u0, s0, z0, u1, s1, z1, mat, face, 0.012)

    bx(a0, a0 + lt, t0, t1, 0, h)
    bx(a1 - lt, a1, t0, t1, 0, h)
    bx(a0, a1, t0, t1, h - lt, h)
    for u0, u1, side in ((t0 - gp, t0, -1), (t1, t1 + gp, 1)):
        bx(a0 - gw, a0, u0, u1, 0, h + gw, side)
        bx(a1, a1 + gw, u0, u1, 0, h + gw, side)
        bx(a0 - gw, a1 + gw, u0, u1, h, h + gw, side)


def _door_locks(p, w, y0):
    """Trancas do lado de dentro (+Y local) da porta de entrada, bem exageradas: dois ferrolhos que
    entram no batente, corrente, tranca de barra num par de suportes e uma chave tetra gorda.
    `y0` é a face da moldura das almofadas; tudo nasce dela."""
    metal, dark = "M_Metal", "M_MetalDark"
    # Ferrolhos grandões em cima e embaixo: a haste passa da borda da porta e vai para o batente.
    for z in (1.82, 0.32):
        p.box(w - 0.34, y0, z - 0.03, w - 0.04, y0 + 0.008, z + 0.03, dark, bevel=0.003)
        for gx in (w - 0.3, w - 0.17, w - 0.07):
            p.box(gx - 0.014, y0 + 0.008, z - 0.02, gx + 0.014, y0 + 0.03, z + 0.02, dark, bevel=0.003)
        p.cyl(((w - 0.3 + w + 0.012) / 2, y0 + 0.02, z), 0.322 + (0.0), 0.011, metal, axis="X", seg=10)
        p.box(w - 0.215, y0 + 0.03, z - 0.012, w - 0.185, y0 + 0.052, z + 0.012, "M_Red", bevel=0.005)
    # Corrente: placa, elos alternados de lado e o pino na outra placa.
    cz = 1.5
    p.box(w - 0.07, y0, cz - 0.04, w - 0.02, y0 + 0.01, cz + 0.04, dark, bevel=0.003)
    p.box(w - 0.3, y0, cz - 0.03, w - 0.24, y0 + 0.01, cz + 0.03, dark, bevel=0.003)
    for i in range(7):
        x = w - 0.065 - i * 0.032
        z = cz - 0.012 * math.sin(i / 6 * math.pi)
        if i % 2:
            p.box(x - 0.014, y0 + 0.012, z - 0.006, x + 0.014, y0 + 0.02, z + 0.006, metal, bevel=0.002)
        else:
            p.box(x - 0.014, y0 + 0.014, z - 0.01, x + 0.014, y0 + 0.018, z + 0.01, metal, bevel=0.002)
    p.cyl((w - 0.27, y0 + 0.02, cz), 0.02, 0.009, metal, axis="Y", seg=8)
    # Tranca de barra: dois suportes em U e a barra grossa no meio da porta.
    bz = 1.32
    for bx in (0.1, w - 0.1):
        p.box(bx - 0.035, y0, bz - 0.06, bx + 0.035, y0 + 0.05, bz + 0.06, dark, bevel=0.006)
        p.box(bx - 0.035, y0 + 0.05, bz - 0.06, bx + 0.035, y0 + 0.062, bz - 0.03, dark, bevel=0.003)
    p.box(0.04, y0 + 0.018, bz - 0.032, w - 0.04, y0 + 0.058, bz + 0.032, "M_Wood", bevel=0.01)
    # Chave tetra: rosetão com a lingueta de girar.
    p.cyl((w - 0.1, y0 + 0.012, 1.68), 0.024, 0.045, dark, axis="Y", seg=16)
    p.cyl((w - 0.1, y0 + 0.032, 1.68), 0.02, 0.03, metal, axis="Y", seg=14)
    p.box(w - 0.12, y0 + 0.042, 1.67, w - 0.08, y0 + 0.056, 1.75, metal, bevel=0.005)


def _leaf(name, coll, hinge, rot_z, width, mat, number=None, peephole=False, push_bar=False, locks=False):
    """Folha de porta com a origem na dobradiça; vai para +X local e a face de fora é -Y local."""
    t = 0.04
    h = P.DOOR_H - 0.02
    w = width - 0.04
    p = Part(bevel=0.003)
    p.box(0, -t / 2, 0.01, w, t / 2, h, mat)
    # Duas almofadas em cada face (porta de madeira) com moldura chanfrada saltada de 1 cm.
    if not push_bar:
        m, mh = 0.035, MOLDING
        for side in (-1, 1):
            y0, y1 = sorted((side * t / 2, side * (t / 2 + mh)))
            face = "+y" if side > 0 else "-y"
            for (px0, pz0, px1, pz1) in ((0.1, 0.15, w - 0.1, 0.98), (0.1, 1.12, w - 0.1, h - 0.12)):
                p.trim(px0, y0, pz0, px1, y1, pz0 + m, mat, face, mh)
                p.trim(px0, y0, pz1 - m, px1, y1, pz1, mat, face, mh)
                p.trim(px0, y0, pz0 + m, px0 + m, y1, pz1 - m, mat, face, mh)
                p.trim(px1 - m, y0, pz0 + m, px1, y1, pz1 - m, mat, face, mh)
    # Dobradiças do lado da origem.
    for z in (0.25, 1.05, h - 0.2):
        p.box(-0.006, -0.012, z - 0.05, 0.012, 0.012, z + 0.05, "M_Metal", bevel=0.002)
        p.cyl((-0.004, 0, z), 0.12, 0.006, "M_Metal", seg=8)
    # Maçaneta de alavanca com espelho dos dois lados e a fechadura.
    knob = "M_Metal"
    for side in (-1, 1):
        y = side * (t / 2 + 0.004)
        p.box(w - 0.1, min(y, y + side * 0.008), 0.94, w - 0.05, max(y, y + side * 0.008), 1.12, knob, bevel=0.004)
        p.cyl((w - 0.075, y + side * 0.02, 1.06), 0.03, 0.012, knob, axis="Y", seg=12)
        p.box(w - 0.19, min(y + side * 0.028, y + side * 0.042), 1.05, w - 0.07,
              max(y + side * 0.028, y + side * 0.042), 1.07, knob, bevel=0.005)
        p.cyl((w - 0.075, y + side * 0.009, 0.98), 0.004, 0.008, "M_PlasticBlack", axis="Y", seg=8)
    if peephole:
        p.cyl((w / 2, 0, 1.55), t + 0.02, 0.012, "M_Metal", axis="Y", seg=10)
    if locks:
        _door_locks(p, w, t / 2 + MOLDING)
    if push_bar:
        p.box(0.1, t / 2, 0.98, w - 0.08, t / 2 + 0.05, 1.04, "M_Metal")
        p.box(0.04, -t / 2 - 0.003, 1.3, w - 0.04, -t / 2, 1.9, "M_PlasticWhite")
    if number:
        p.box(w / 2 - 0.09, -t / 2 - 0.006, 1.68, w / 2 + 0.09, -t / 2, 1.8, "M_InkGold")
        digits(p, number, w / 2, 1.7, 0.08, -t / 2 - 0.006, "M_InkBlack")
    return p.finish(name, coll, loc=(hinge[0], hinge[1], 0), rot_z=rot_z)


def doors(coll):
    p = Part(bevel=0.003)
    fy = (-P.EXT_T, 0)
    _door_frame(p, "x", *fy, *P.ENTRANCE, P.DOOR_H, "M_DoorWood")
    _door_frame(p, "x", *fy, *P.DOOR_302, P.DOOR_H, "M_DoorWood")
    _door_frame(p, "x", HY0 - P.EXT_T, HY0, *P.DOOR_303, P.DOOR_H, "M_DoorWood")
    _door_frame(p, "y", HX0 - P.EXT_T, HX0, *P.STAIRS_DOOR, P.DOOR_H, "M_MetalDark")
    _door_frame(p, "y", P.PART_X, P.PART_X + P.INT_T, *P.BATH_DOOR, P.DOOR_H, "M_DoorWood")
    _door_frame(p, "y", P.PART_X, P.PART_X + P.INT_T, *P.SERVICE_OPENING, P.DOOR_H, "M_DoorWood")
    # Tapetes do corredor.
    p.box(P.ENTRANCE[0] + 0.05, HY1 - 0.5, 0, P.ENTRANCE[1] - 0.05, HY1 - 0.05, 0.012, "M_Doormat")
    p.box(P.DOOR_303[0] + 0.05, HY0 + 0.05, 0, P.DOOR_303[1] - 0.05, HY0 + 0.45, 0.012, "M_Doormat")
    p.finish("Door_Frames", coll)

    mid = -P.EXT_T / 2
    half = P.INT_T / 2
    _leaf("KEEP_Door_301", coll, (P.ENTRANCE[0] + 0.02, mid), 0.0, P.ENTRANCE[1] - P.ENTRANCE[0],
          "M_DoorWood", number="301", peephole=True, locks=True)
    _leaf("KEEP_Door_302", coll, (P.DOOR_302[0] + 0.02, mid), 0.0, P.DOOR_302[1] - P.DOOR_302[0],
          "M_DoorWood", number="302", peephole=True)
    _leaf("KEEP_Door_303", coll, (P.DOOR_303[1] - 0.02, HY0 - P.EXT_T / 2), math.pi,
          P.DOOR_303[1] - P.DOOR_303[0], "M_DoorWood", number="303", peephole=True)
    _leaf("KEEP_Door_Stairs", coll, (HX0 - P.EXT_T / 2, P.STAIRS_DOOR[0] + 0.02), math.pi / 2,
          P.STAIRS_DOOR[1] - P.STAIRS_DOOR[0], "M_DoorMetal", push_bar=True)
    _leaf("KEEP_Door_Bath", coll, (P.PART_X + half, P.BATH_DOOR[1] - 0.02), -math.pi / 2,
          P.BATH_DOOR[1] - P.BATH_DOOR[0], "M_DoorWood")


def _bare_bulb(coll, name, loc, cord, size, zone=None):
    """Lâmpada pelada pendurada num fio torcido: canopla no teto, fio, bocal e um bulbo gordo (a
    malha LAMP_<zona>_<n> brilha com M_Lamp_<zona>). `cord` é o comprimento do fio e `size` escala
    o bulbo."""
    zone = zone or name.split("_")[0]
    lamp = f"M_Lamp_{zone}"
    r = 0.055 * size
    top = -cord - 0.05
    # Canopla, fio e bocal ficam numa malha à parte (Cord_) que faz sombra: o bocal tapa a luz que
    # sobe e deixa uma rodela escura no teto em cima da lâmpada, como numa lâmpada pelada de
    # verdade (sem ela, o teto em volta virava uma mancha clara enorme).
    c = Part()
    c.cyl((0, 0, -0.012), 0.024, 0.045, "M_PlasticWhite", seg=20)
    c.cyl((0, 0, -cord / 2), cord, 0.004, "M_PlasticBlack", seg=6)
    c.cyl((0, 0, top + 0.012), 0.07, 0.03, "M_PlasticBlack", seg=14)
    c.cyl((0, 0, top - 0.035), 0.03, 0.026, "M_Metal", seg=14, radius2=0.03)
    c.finish(f"Cord_Lamp_{name}", coll, loc=loc)
    p = Part()
    p.cyl((0, 0, top - 0.058), 0.02, 0.026, lamp, seg=14, radius2=r * 0.7)
    p.rounded(-r, -r, top - 0.07 - 2 * r, r, r, top - 0.07, lamp, r * 0.95)
    p.finish(f"LAMP_{name}", coll, loc=loc)


def lights(coll):
    """Luminárias (malhas LAMP_<zona>_<n>) e as luzes de prévia do Blender (LIGHT_<zona>_<n>)."""
    # Lâmpada pelada no fio, no meio do cômodo (bulbo grande de desenho).
    _bare_bulb(coll, "main_0", (2.6, 2.7, H), cord=0.3, size=1.0)
    point_light("LIGHT_main_0", coll, (2.6, 2.7, H - 0.5), 120, radius=0.04)

    # Calha fluorescente embaixo do armário: corpo branco e o tubo.
    p = Part(bevel=0.003)
    p.box(-0.82, -0.03, -0.014, 0.82, 0.03, 0, "M_PlasticWhite")
    p.cyl((0, 0, -0.024), 1.5, 0.012, "M_Lamp_kitchen", axis="X", seg=12)
    for x in (-0.77, 0.77):
        p.box(x - 0.02, -0.02, -0.04, x + 0.02, 0.02, -0.014, "M_PlasticWhite")
    p.finish("LAMP_kitchen_0", coll, loc=(2.0, 0.3, 1.52))
    point_light("LIGHT_kitchen_0", coll, (2.0, 0.35, 1.42), 25, color=(0.85, 0.92, 1.0), radius=0.3)

    for name, loc, watts, color in (
        ("bath_0", (5.75, 0.9, P.BATH_CEILING_Z), 40, (1.0, 0.95, 0.85)),
        ("service_0", (5.8, 3.4, H), 40, (1.0, 0.9, 0.7)),
        ("hall_0", (1.5, (HY0 + HY1) / 2, H), 35, (0.88, 1.0, 0.9)),
        ("hall_1", (7.0, (HY0 + HY1) / 2, H), 35, (0.88, 1.0, 0.9)),
    ):
        zone = name.split("_")[0]
        p = Part()
        p.cyl((0, 0, -0.025), 0.05, 0.13, "M_PlasticWhite", seg=16)
        p.cyl((0, 0, -0.052), 0.004, 0.11, f"M_Lamp_{zone}", seg=16)
        p.finish(f"LAMP_{name}", coll, loc=loc)
        point_light(f"LIGHT_{name}", coll, (loc[0], loc[1], loc[2] - 0.15), watts, color=color, radius=0.1)


def markers(coll):
    for i, (x, y) in enumerate(P.SPAWNS, start=1):
        empty(f"SPAWN_{i}", coll, (x, y, 0), size=0.4, kind="SINGLE_ARROW")
    # Onde o fiscal para para bater na porta.
    empty("POINT_Knock", coll, ((P.ENTRANCE[0] + P.ENTRANCE[1]) / 2, HY1 - 0.7, 0), size=0.4, kind="CIRCLE")
