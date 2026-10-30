"""Lá fora, à noite (Outside_*): o prédio do outro lado da rua (visto pelas janelas do fundo),
o da lateral (visto do banheiro e do fim do corredor), a rua lá embaixo com postes e uma fileira
de prédios longe. Só aparência: o Godot não dá colisão nem sombra a nada disso.

A kitnet fica no 3º andar: o chão dela é z = 0 e a rua fica em z = STREET_Z."""

import random

import plan as P
from lib import Part

STREET_Z = -8.6
FLOOR_H = 2.9


def build(colls):
    c = colls["outside"]
    rng = random.Random(301)
    street(c)
    facade_across(c, rng)
    facade_side(c, rng)
    skyline(c, rng)
    own_facade(c, rng)


def _window_mat(rng):
    r = rng.random()
    if r < 0.42:
        return "M_WinDark"
    if r < 0.7:
        return "M_WinLit"
    if r < 0.8:
        return "M_WinCurtain"
    if r < 0.9:
        return "M_WinTV"
    return "M_WinCool"


def _facade_x(p, rng, y_face, x0, x1, z0, z1, toward, mat="M_Facade", ac=True):
    """Fachada plana ao longo de X com a face em y_face virada para `toward` (+1/-1 em Y)."""
    depth = 0.4
    yb = y_face - toward * depth
    p.box(x0, min(y_face, yb), z0, x1, max(y_face, yb), z1, mat)
    floors = int((z1 - z0 - 0.5) // FLOOR_H)
    cols = int((x1 - x0 - 1.0) // 2.4)
    for f in range(floors):
        zb = z0 + 0.9 + f * FLOOR_H
        # Laje marcada entre os andares.
        p.box(x0, min(y_face, y_face + toward * 0.08), zb - 0.95, x1, max(y_face, y_face + toward * 0.08),
              zb - 0.8, mat)
        for c in range(cols):
            xa = x0 + 0.8 + c * 2.4
            yw = y_face + toward * 0.01
            p.box(xa, min(y_face, yw), zb, xa + 1.3, max(y_face, yw), zb + 1.25, _window_mat(rng))
            p.box(xa - 0.05, min(y_face, y_face + toward * 0.12), zb - 0.08, xa + 1.35,
                  max(y_face, y_face + toward * 0.12), zb - 0.02, mat)
            if ac and rng.random() < 0.18:
                ya = y_face + toward * 0.4
                p.box(xa + 0.3, min(y_face, ya), zb - 0.5, xa + 1.0, max(y_face, ya), zb - 0.1, "M_PlasticWhite")


def _facade_y(p, rng, x_face, y0, y1, z0, z1, toward, mat="M_Facade"):
    """Igual a _facade_x, ao longo de Y com a face em x_face virada para `toward` (+1/-1 em X)."""
    depth = 0.4
    xb = x_face - toward * depth
    p.box(min(x_face, xb), y0, z0, max(x_face, xb), y1, z1, mat)
    floors = int((z1 - z0 - 0.5) // FLOOR_H)
    cols = int((y1 - y0 - 1.0) // 2.4)
    for f in range(floors):
        zb = z0 + 0.9 + f * FLOOR_H
        for c in range(cols):
            ya = y0 + 0.8 + c * 2.4
            xw = x_face + toward * 0.01
            p.box(min(x_face, xw), ya, zb, max(x_face, xw), ya + 1.3, zb + 1.25, _window_mat(rng))


def street(coll):
    p = Part()
    p.box(-30, P.D + 2.0, STREET_Z - 0.2, 40, 40, STREET_Z, "M_Asphalt")
    p.box(-30, P.D + 0.2, STREET_Z - 0.2, 40, P.D + 2.0, STREET_Z + 0.15, "M_Concrete")
    p.box(-30, 12.0, STREET_Z - 0.2, 40, 14.0, STREET_Z + 0.15, "M_Concrete")
    # Postes do lado de lá, com a luz amarela de sódio.
    for x in (-6.0, 6.0, 18.0):
        p.cyl((x, 12.6, STREET_Z + 3.5), 7.0, 0.09, "M_MetalDark", seg=8)
        p.box(x - 0.05, 11.2, STREET_Z + 6.9, x + 0.05, 12.6, STREET_Z + 7.0, "M_MetalDark")
        p.box(x - 0.2, 11.0, STREET_Z + 6.75, x + 0.2, 11.5, STREET_Z + 6.9, "M_StreetLamp")
    p.finish("Outside_Street", coll)


def facade_across(coll, rng):
    """Prédio do outro lado da rua, de frente para as janelas do fundo."""
    p = Part()
    _facade_x(p, rng, 14.0, -18.0, 26.0, STREET_Z, 14.0, -1)
    p.finish("Outside_FacadeAcross", coll)


def facade_side(coll, rng):
    """Prédio colado na lateral leste (o banheiro e o corredor olham para ele)."""
    p = Part()
    _facade_y(p, rng, 15.0, -14.0, 12.0, STREET_Z, 12.0, -1)
    p.finish("Outside_FacadeSide", coll)


def skyline(coll, rng):
    """Fileira de prédios altos lá longe: silhuetas escuras com poucas janelas acesas."""
    p = Part()
    x = -60.0
    while x < 70.0:
        w = rng.uniform(8, 18)
        h = rng.uniform(15, 55)
        y = rng.uniform(55, 75)
        p.box(x, y, STREET_Z, x + w, y + 6, STREET_Z + h, "M_FacadeFar")
        for _ in range(int(w * h / 12)):
            if rng.random() < 0.55:
                continue
            wx = rng.uniform(x + 0.5, x + w - 1.5)
            wz = rng.uniform(STREET_Z + 2, STREET_Z + h - 2)
            p.box(wx, y - 0.02, wz, wx + 1.0, y, wz + 1.0, "M_WinLit" if rng.random() < 0.8 else "M_WinCool")
        if rng.random() < 0.3:
            p.box(x + w / 2 - 0.15, y + 2.9, STREET_Z + h, x + w / 2 + 0.15, y + 3.1, STREET_Z + h + 0.3, "M_LedRed")
        x += w + rng.uniform(1, 6)
    p.finish("Outside_Skyline", coll)


def own_facade(coll, rng):
    """O lado de fora do nosso prédio em volta das janelas (aparece de relance pela grade)."""
    p = Part()
    y_face = P.D + P.EXT_T
    p.box(-6.0, y_face, STREET_Z, 13.0, y_face + 0.01, 0.0 - 0.0, "M_Facade")
    p.box(-6.0, y_face, P.WALL_H + 0.3, 13.0, y_face + 0.01, 14.0, "M_Facade")
    p.box(-6.0, y_face, 0.0, -P.EXT_T, y_face + 0.01, P.WALL_H + 0.3, "M_Facade")
    p.box(P.W + P.EXT_T, y_face, 0.0, 13.0, y_face + 0.01, P.WALL_H + 0.3, "M_Facade")
    p.box(-P.EXT_T, y_face, P.WALL_H, P.W + P.EXT_T, y_face + 0.01, P.WALL_H + 0.3, "M_Facade")
    p.finish("Outside_OwnFacade", coll)
