"""Escada do prédio e o hall do térreo (Stairs_*), atrás da porta corta-fogo do fim do corredor.

Três andares de lances de ida e volta até o térreo. Em cada andar: o patamar na frente da porta,
o lance que desce pelo lado oeste, o patamar do meio e o lance que volta pelo lado leste até o
andar de baixo. Uma parede no meio separa os dois lances. No térreo fica o hall de entrada, com
as caixas de correio e a porta da rua (KEEP_Door_Street): é por ela que o vizinho foge
(scripts/neighbor.gd).

Os degraus (Stairs_Steps) são só aparência. Quem pisa é uma rampa invisível em cada lance
(COLLIDER_Stairs_Ramps), passando um pouco abaixo das quinas dos degraus: o jogador do Godot não
sobe degrau de 17 cm (a rampa passa nas quinas, rente aos patamares). Embaixo do primeiro lance, o maciço também tem colisão invisível.

Coordenadas do Blender (o +Y daqui vira -Z no Godot).
"""

import math

from mathutils import Matrix, Vector

import plan as P
import structure as S
from lib import Part, digits, point_light, wall

X0, X1 = P.STAIR_X
SPLIT0, SPLIT1 = P.STAIR_SPLIT
LY0, LY1 = P.STAIR_LANDING_Y
MY0, MY1 = P.STAIR_MID_Y
FH = P.STAIR_FLOOR_H
RISE = FH / 2 / P.STAIR_STEPS
TREAD = P.STAIR_TREAD
T = P.EXT_T
SLAB = 0.15
GROUND = -P.STAIR_FLOORS * FH
TOP = P.WALL_H
LOBBY_H = 2.6
# Quanto a rampa passa abaixo das quinas dos degraus. Zero: baixada, ela ficava abaixo da borda do
# patamar de cima, e o jogador subindo batia nessa quina e travava.
RAMP_DROP = 0.0
# Grossa: um corpo caído (ragdoll) começando com o pé enfiado numa rampa fina atravessava ela.
RAMP_THICK = 0.35
WEST = (X0, SPLIT0)    # lance que desce do andar para o patamar do meio
EAST = (SPLIT1, X1)    # lance que volta do meio para o andar de baixo


def floor_z(k):
    """Altura do piso do andar `k` (0 = térreo, STAIR_FLOORS = o da kitnet)."""
    return GROUND + k * FH


def build(colls):
    c = colls["structure"]
    slabs(c)
    steps(c)
    ramps(c)
    walls(c)
    doors(c)
    lobby(c)
    lights(colls["lights"])


def slabs(coll):
    p = Part()
    for k in range(1, P.STAIR_FLOORS + 1):
        z = floor_z(k)
        p.box(X0, LY0, z - SLAB, X1, LY1, z, "M_FloorHall")
        zm = z - FH / 2
        p.box(X0, MY0, zm - SLAB, X1, MY1, zm, "M_FloorHall")
    # Térreo: o patamar e o hall de entrada no mesmo piso.
    p.box(X0 - T, P.LOBBY_Y[0] - T, GROUND - SLAB, X1 + T, LY1, GROUND, "M_FloorHall")
    # Embaixo do patamar do meio do primeiro lance: maciço até o chão.
    p.box(X0, MY0, GROUND, X1, MY1, floor_z(1) - FH / 2 - SLAB, "M_Concrete")
    p.finish("Stairs_Landings", coll)

    # Colisão do maciço embaixo do lance que desce do 1º andar (os degraus não têm colisão).
    c = Part()
    c.box(X0, LY1, GROUND, SPLIT0, MY1, floor_z(1) - FH / 2 - SLAB, "M_Concrete")
    c.finish("COLLIDER_Stairs_Base", coll)


def steps(coll):
    p = Part(bevel=0.004)
    for k in range(1, P.STAIR_FLOORS + 1):
        top = floor_z(k)
        mid = top - FH / 2
        for j in range(P.STAIR_STEPS - 1):
            # Lance oeste: desce para +Y. O do 1º andar é maciço até o chão.
            z = top - RISE * (j + 1)
            y0 = LY1 + TREAD * j
            bottom = GROUND if k == 1 else z - 0.4
            p.box(WEST[0], y0, bottom, WEST[1], y0 + TREAD, z, "M_Concrete")
            p.box(WEST[0], y0, z, WEST[1], y0 + 0.035, z + 0.004, "M_Rubber", bevel=0.001)
            # Lance leste: desce para -Y.
            z = mid - RISE * (j + 1)
            y1 = MY0 - TREAD * j
            bottom = GROUND if k == 1 else z - 0.4
            p.box(EAST[0], y1 - TREAD, bottom, EAST[1], y1, z, "M_Concrete")
            p.box(EAST[0], y1 - 0.035, z, EAST[1], y1, z + 0.004, "M_Rubber", bevel=0.001)
    p.finish("Stairs_Steps", coll)


def _ramp(p, x0, x1, y_top, z_top, direction):
    """Rampa de um lance que começa na borda `y_top` do patamar de cima (altura `z_top`) e desce
    para o lado de `direction` (+1: +Y, -1: -Y)."""
    n = P.STAIR_STEPS
    run, drop = n * TREAD, n * RISE
    # O plano das quinas dos degraus (baixado RAMP_DROP): sai da borda do patamar de cima e chega
    # no de baixo um piso depois do último espelho.
    shift = RAMP_DROP * TREAD / RISE
    ys = y_top - direction * shift
    ye = y_top + direction * (run - shift)
    angle = math.atan2(drop, run)
    rot = Matrix.Rotation(-direction * angle, 4, "X")
    normal = rot @ Vector((0.0, 0.0, 1.0))
    mid = Vector(((x0 + x1) / 2, (ys + ye) / 2, z_top - drop / 2)) - normal * (RAMP_THICK / 2)
    size = Vector((x1 - x0, math.hypot(run, drop), RAMP_THICK))
    p.box_m(size, Matrix.Translation(mid) @ rot, "M_Concrete", bevel=0.0)


def ramps(coll):
    p = Part()
    for k in range(1, P.STAIR_FLOORS + 1):
        top = floor_z(k)
        _ramp(p, *WEST, LY1, top, 1)
        _ramp(p, *EAST, MY0, top - FH / 2, -1)
    p.finish("COLLIDER_Stairs_Ramps", coll)


def walls(coll):
    p = Part()
    zb = GROUND - SLAB
    # Oeste e sul, o vão inteiro.
    p.box(X0 - T, LY0 - T, zb, X0, MY1 + T, TOP, "M_WallHall")
    p.box(X0, MY1, zb, X1 + T, MY1 + T, TOP, "M_WallHall")
    # Leste: abaixo do 3º andar, inteira (as portas dos outros andares ficam fechadas, coladas
    # nela); no 3º, só o que o corredor não cobre.
    p.box(X1, LY0 - T, zb, X1 + T, MY1, 0.0, "M_WallHall")
    p.box(X1, LY0 - T, 0.0, X1 + T, LY0, TOP, "M_WallHall")
    p.box(X1, 0.0, 0.0, X1 + T, MY1, TOP, "M_WallHall")
    # Norte: em cima do hall do térreo.
    p.box(X0 - T, LY0 - T, GROUND + LOBBY_H, X1 + T, LY0, TOP, "M_WallHall")
    # Meio, entre os dois lances, do chão ao teto.
    p.box(SPLIT0, LY1, zb, SPLIT1, MY0, TOP, "M_WallHall")
    # Barra pintada até 1,1 m em cada patamar de andar.
    for k in range(0, P.STAIR_FLOORS + 1):
        z = floor_z(k)
        p.box(X0, LY0, z, X0 + 0.006, LY1, z + 1.1, "M_WallHallLow")
        if k > 0:
            p.box(X0, LY0, z, X1, LY0 + 0.006, z + 1.1, "M_WallHallLow")
    # Guarda-corpo do 3º andar: na beira do patamar, em cima do vão do lance que volta.
    p.box(SPLIT1, LY1, 0.0, X1, LY1 + 0.1, 1.0, "M_WallHall")
    p.cyl(((SPLIT1 + X1) / 2, LY1 + 0.05, 1.03), X1 - SPLIT1, 0.03, "M_Metal", axis="X", seg=10)
    # Corrimão de cano nas paredes dos lances.
    for k in range(1, P.STAIR_FLOORS + 1):
        top = floor_z(k)
        _handrail(p, X0 + 0.05, LY1, top, 1)
        _handrail(p, X1 - 0.05, MY0, top - FH / 2, -1)
    # Teto.
    p.box(X0 - T, LY0 - T, TOP, X1 + T, MY1 + T, TOP + 0.12, "M_Ceiling")
    p.finish("Stairs_Walls", coll)


def _handrail(p, x, y_top, z_top, direction):
    """Cano de corrimão a 0,9 m das quinas, ao longo de um lance."""
    run, drop = P.STAIR_STEPS * TREAD, P.STAIR_STEPS * RISE
    angle = math.atan2(drop, run)
    length = math.hypot(run, drop)
    rot = Matrix.Rotation(-direction * angle, 4, "X") @ Matrix.Rotation(math.pi / 2, 4, "X")
    mid = Vector((x, y_top + direction * run / 2, z_top - drop / 2 + 0.9))
    p.cyl((0.0, 0.0, 0.0), length, 0.02, "M_Metal", seg=8, matrix=Matrix.Translation(mid) @ rot)


def doors(coll):
    # Os outros andares: porta corta-fogo fechada, colada na parede, com o número do andar.
    width = P.STAIRS_DOOR[1] - P.STAIRS_DOOR[0]
    for k in range(1, P.STAIR_FLOORS):
        z = floor_z(k)
        p = Part(bevel=0.003)
        S._door_frame(p, "y", X1, X1 + T, *P.STAIRS_DOOR, P.DOOR_H, "M_MetalDark")
        p.box(-2.55, LY0, 1.5, -2.05, LY0 + 0.012, 2.0, "M_PlasticWhite")
        digits(p, str(k), -2.3, 1.57, 0.3, LY0 + 0.012, "M_InkBlack", depth=0.006, facing="+y")
        p.finish(f"Stairs_Floor_{k}", coll, loc=(0.0, 0.0, z))
        leaf = S._leaf(f"Stairs_Door_{k}", coll, (X1 - 0.03, P.STAIRS_DOOR[0] + 0.02), math.pi / 2,
                       width, "M_DoorMetal", push_bar=True)
        leaf.location.z = z
    # A placa do 3º andar do lado da escada.
    p = Part()
    p.box(-2.55, LY0, 1.5, -2.05, LY0 + 0.012, 2.0, "M_PlasticWhite")
    digits(p, str(P.STAIR_FLOORS), -2.3, 1.57, 0.3, LY0 + 0.012, "M_InkBlack", depth=0.006, facing="+y")
    p.finish("Stairs_Floor_3", coll)


def lobby(coll):
    """Hall do térreo: paredes, teto, caixas de correio, capacho e a porta da rua."""
    y0, y1 = P.LOBBY_Y
    p = Part()
    p.box(X0 - T, y0 - T, -SLAB, X0, LY0 - T, LOBBY_H, "M_WallHall")
    p.box(X1, y0 - T, -SLAB, X1 + T, LY0 - T, LOBBY_H, "M_WallHall")
    wall(p, "x", y0 - T, y0, X0 - T, X1 + T, "M_WallHall", LOBBY_H,
         [(P.STREET_DOOR[0], P.STREET_DOOR[1], 0.0, P.DOOR_H)])
    p.box(X0 - T, y0 - T, LOBBY_H, X1 + T, LY0, LOBBY_H + 0.12, "M_Ceiling")
    p.box(X0, y0, 0.0, X0 + 0.006, y1, 1.1, "M_WallHallLow")
    p.box(X1 - 0.006, y0, 0.0, X1, y1, 1.1, "M_WallHallLow")
    # Caixas de correio na parede leste: 3 x 4 portinhas.
    p.box(X1 - 0.14, -4.25, 0.95, X1, -2.55, 1.65, "M_MetalDark", bevel=0.006)
    for row in range(3):
        for col in range(4):
            ya = -4.2 + col * 0.41
            za = 1.0 + row * 0.215
            p.box(X1 - 0.145, ya, za, X1 - 0.14, ya + 0.37, za + 0.18, "M_Metal", bevel=0.002)
            p.box(X1 - 0.15, ya + 0.12, za + 0.13, X1 - 0.145, ya + 0.25, za + 0.15, "M_PlasticBlack", bevel=0)
    # Capacho e o número do prédio em cima da porta.
    p.box(P.STREET_DOOR[0] + 0.05, y0 + 0.05, 0.0, P.STREET_DOOR[1] - 0.05, y0 + 0.65, 0.012, "M_Doormat")
    p.box(-3.4, y0, 2.18, -2.9, y0 + 0.012, 2.45, "M_InkGold")
    digits(p, "301", -3.15, 2.22, 0.18, y0 + 0.012, "M_InkBlack", depth=0.005, facing="+y")
    S._door_frame(p, "x", y0 - T, y0, *P.STREET_DOOR, P.DOOR_H, "M_MetalDark")
    p.finish("Stairs_Lobby", coll, loc=(0.0, 0.0, GROUND))

    leaf = S._leaf("KEEP_Door_Street", coll, (P.STREET_DOOR[0] + 0.02, y0 - T / 2), 0.0,
                   P.STREET_DOOR[1] - P.STREET_DOOR[0], "M_DoorMetal", push_bar=True)
    leaf.location.z = GROUND
    # Lá fora da porta da rua: escuro (sem colisão, como o resto de fora).
    v = Part()
    v.box(P.STREET_DOOR[0] - 0.2, y0 - T - 0.6, -0.05, P.STREET_DOOR[1] + 0.2, y0 - T, P.DOOR_H + 0.2, "M_Void")
    v.finish("Outside_StreetDoor", coll, loc=(0.0, 0.0, GROUND))


def lights(coll):
    """Uma luminária no teto de cada patamar de andar e uma no hall do térreo (zona "stairs": a luz
    é do prédio, não apaga com o disjuntor da kitnet)."""
    spots = []
    for k in range(0, P.STAIR_FLOORS + 1):
        ceiling = floor_z(k + 1) - SLAB if k < P.STAIR_FLOORS else TOP
        spots.append((f"stairs_{k}", (-2.4, (LY0 + LY1) / 2, ceiling)))
    spots.append(("stairs_lobby", ((X0 + X1) / 2, (P.LOBBY_Y[0] + P.LOBBY_Y[1]) / 2, GROUND + LOBBY_H)))
    for name, loc in spots:
        p = Part()
        p.cyl((0, 0, -0.025), 0.05, 0.12, "M_PlasticWhite", seg=16)
        p.cyl((0, 0, -0.052), 0.004, 0.1, "M_Lamp_stairs", seg=16)
        p.finish(f"LAMP_{name}", coll, loc=loc)
        point_light(f"LIGHT_{name}", coll, (loc[0], loc[1], loc[2] - 0.15), 35, color=(1.0, 0.93, 0.78), radius=0.1)
