"""Boneco dos jogadores: um adulto de desenho animado, desengonçado e meio acabado (comprido,
curvado, peito estreito e barriguinha de cerveja, braços e pernas finos e longos, tênis grandes),
de cara cansada: olhos pequenos de pálpebra caída e olheira, nariz comprido, sorrisinho torto e
barba por fazer. Moletom com capuz e luvas amarelas de borracha. Todos usam o mesmo boneco; a vaga
muda a cor do moletom (o jogo pinta M_Hoodie e M_HoodieDark) e o acessório (Acc_*).

Exporta assets/models/character.glb. São peças rígidas, cada uma com a origem no ponto onde
gira, e o Godot anima por código (scripts/character_rig.gd):

    Character (pés no chão)
      Char_Body      quadril: moletom, barriga, calça e capuz
        Char_Head    pescoço: cabeça, rosto e os acessórios (Acc_Cap, Acc_Glasses, Acc_Quiff,
                     Acc_Beanie; o jogo mostra só o da vaga)
        Char_Arm_L/R      ombro: braço da manga (UPPER_ARM)
          Char_Forearm_L/R  cotovelo: antebraço e o punho de ribana (FOREARM)
            Char_Glove_L/R  pulso: luva de desenho (três dedos e o polegar)
      Char_Leg_L/R   quadril: coxa (THIGH)
        Char_Shin_L/R  joelho: canela, a barra embolada e o tênis (SHIN)

Referencial (Blender): frente para -Y, em cima +Z, medidas em metros. No Godot a frente fica
para +Z (o jogo gira o boneco). L é o lado esquerdo do boneco (+X).

    blender --background --python art_source/blender/character.py -- --export
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import lib  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
BLEND = os.path.join(ROOT, "art_source", "character.blend")
GLB = os.path.join(ROOT, "assets", "models", "character.glb")

lib.MATERIALS.update({
    "M_Skin": ((0.96, 0.72, 0.56), 0.6, 0.0, 0.0),
    "M_Stubble": ((0.8, 0.62, 0.54), 0.8, 0.0, 0.0),
    "M_EyeBags": ((0.82, 0.56, 0.5), 0.7, 0.0, 0.0),
    "M_Nose": ((0.95, 0.6, 0.48), 0.5, 0.0, 0.0),
    "M_EyeWhite": ((0.97, 0.96, 0.9), 0.25, 0.0, 0.0),
    "M_Pupil": ((0.03, 0.03, 0.04), 0.2, 0.0, 0.0),
    "M_Brow": ((0.22, 0.15, 0.1), 0.9, 0.0, 0.0),
    "M_MouthIn": ((0.32, 0.07, 0.08), 0.6, 0.0, 0.0),
    "M_Teeth": ((0.95, 0.92, 0.8), 0.3, 0.0, 0.0),
    "M_Hoodie": ((0.9, 0.9, 0.9), 0.95, 0.0, 0.0),
    "M_HoodieDark": ((0.55, 0.55, 0.55), 0.95, 0.0, 0.0),
    "M_Drawstring": ((0.97, 0.97, 0.95), 0.8, 0.0, 0.0),
    "M_Pants": ((0.2, 0.24, 0.34), 0.9, 0.0, 0.0),
    "M_Shoe": ((0.94, 0.93, 0.88), 0.6, 0.0, 0.0),
    "M_ShoeSole": ((0.2, 0.18, 0.2), 0.8, 0.0, 0.0),
    "M_ShoeToe": ((0.85, 0.84, 0.8), 0.5, 0.0, 0.0),
    "M_ShoeStripe": ((0.85, 0.22, 0.18), 0.6, 0.0, 0.0),
    "M_Lace": ((0.25, 0.25, 0.28), 0.8, 0.0, 0.0),
    "M_PantsDark": ((0.14, 0.17, 0.25), 0.9, 0.0, 0.0),
    "M_Nostril": ((0.45, 0.2, 0.18), 0.6, 0.0, 0.0),
    "M_EarIn": ((0.88, 0.55, 0.45), 0.6, 0.0, 0.0),
    "M_Glove": ((0.95, 0.72, 0.06), 0.32, 0.0, 0.0),
    "M_GloveCuff": ((0.88, 0.62, 0.04), 0.4, 0.0, 0.0),
    # Acessórios.
    "M_CapCrown": ((0.95, 0.94, 0.9), 0.8, 0.0, 0.0),
    "M_CapBrim": ((0.15, 0.42, 0.28), 0.8, 0.0, 0.0),
    "M_GlassesFrame": ((0.05, 0.05, 0.06), 0.3, 0.0, 0.0),
    "M_Hair": ((0.28, 0.16, 0.08), 0.7, 0.0, 0.0),
    "M_Beanie": ((0.95, 0.48, 0.1), 0.95, 0.0, 0.0),
    "M_BeanieCuff": ((0.8, 0.35, 0.06), 0.95, 0.0, 0.0),
    "M_Pompom": ((0.97, 0.96, 0.92), 1.0, 0.0, 0.0),
})

# Pontos de giro (no boneco em pé, pés em z = 0). Pernas compridas, olhos a 1,60 m.
HIP = Vector((0.0, 0.0, 0.78))
LEG_X = 0.09
NECK = Vector((0.0, 0.0, 1.36))
SHOULDER = Vector((0.19, 0.0, 1.28))
ARM_LEN = 0.6
# O braço e a perna em duas partes: cotovelo e joelho.
UPPER_ARM = 0.3
FOREARM = ARM_LEN - UPPER_ARM
THIGH = 0.38
SHIN = HIP.z - THIGH
# Cabeça: centro (a partir do pescoço; um pouco para frente, de quem anda curvado) e raios do
# ovo, mais alto que largo.
HEAD_C = Vector((0.0, -0.03, 0.2))
HEAD_R = Vector((0.16, 0.16, 0.2))


# --- Formas ----------------------------------------------------------------------------------------

def blob(p, center, radii, mat, rot=None, seg=(24, 14)):
    """Elipsoide liso (cabeça, olho, nariz, barriga)."""
    m = Matrix.Translation(center)
    if rot is not None:
        m = m @ rot
    m = m @ Matrix.Diagonal((*radii, 1.0))
    res = bmesh.ops.create_uvsphere(p.bm, u_segments=seg[0], v_segments=seg[1], radius=1.0, matrix=m)
    p._tag(res["verts"], mat, smooth=True)


def half_blob(p, center, radii, mat, rot=None, seg=(24, 12), closed=True):
    """Metade de baixo de um elipsoide (boca, barba, e virada por `rot`: pálpebra, copa do boné
    e do gorro). `closed` fecha a tampa; a barba fica aberta, uma casca rente à pele (com tampa,
    o contorno desenhava uma linha preta atravessando o rosto)."""
    res = bmesh.ops.create_uvsphere(p.bm, u_segments=seg[0], v_segments=seg[1], radius=1.0)
    verts = res["verts"]
    top = [v for v in verts if v.co.z > 1e-4]
    bmesh.ops.delete(p.bm, geom=top, context="VERTS")
    verts = [v for v in verts if v.is_valid]
    if closed:
        edges = {e for v in verts for e in v.link_edges if e.is_boundary}
        bmesh.ops.holes_fill(p.bm, edges=list(edges), sides=0)
    m = Matrix.Translation(center)
    if rot is not None:
        m = m @ rot
    m = m @ Matrix.Diagonal((*radii, 1.0))
    bmesh.ops.transform(p.bm, matrix=m, verts=verts)
    p._tag(verts, mat, smooth=True)


def ring(p, center, radius, tube, mat, seg=(24, 8), plane="XZ", scale=(1.0, 1.0, 1.0)):
    """Argola: aro dos óculos (plano XZ, olhando para -Y), gola (plano XY, em volta do pescoço).
    `scale` estica a argola nos eixos do mundo."""
    rows = []
    for i in range(seg[0]):
        a = i / seg[0] * math.tau
        row = []
        for j in range(seg[1]):
            b = j / seg[1] * math.tau
            r = radius + tube * math.cos(b)
            if plane == "XY":
                co = Vector((r * math.cos(a), r * math.sin(a), tube * math.sin(b)))
            else:
                co = Vector((r * math.cos(a), tube * math.sin(b), r * math.sin(a)))
            co = Vector((co.x * scale[0], co.y * scale[1], co.z * scale[2]))
            row.append(p.bm.verts.new(Vector(center) + co))
        rows.append(row)
    for i in range(seg[0]):
        for j in range(seg[1]):
            a, b = rows[i], rows[(i + 1) % seg[0]]
            p.bm.faces.new((a[j], b[j], b[(j + 1) % seg[1]], a[(j + 1) % seg[1]]))
    p._tag([v for row in rows for v in row], mat, smooth=True)


def head_front(x, z):
    """Onde fica a superfície da frente da cabeça (-Y), no referencial do pescoço."""
    u = (x - HEAD_C.x) / HEAD_R.x
    w = (z - HEAD_C.z) / HEAD_R.z
    return HEAD_C.y - HEAD_R.y * math.sqrt(max(0.0, 1.0 - u * u - w * w))


FLIP = Matrix.Rotation(math.pi, 4, "X")


# --- Peças -----------------------------------------------------------------------------------------

def body(coll, root):
    """Peito estreito, barriguinha de cerveja saltando no moletom, bolso canguru em cima dela,
    gola de ribana com os cordões, capuz caído nas costas e o cós da calça com os bolsos de trás."""
    p = lib.Part(bevel=0.01)
    hood = "M_Hoodie"
    blob(p, (0, 0.01, 0.36), (0.225, 0.145, 0.26), hood, seg=(28, 16))
    blob(p, (0, -0.04, 0.16), (0.21, 0.19, 0.17), hood, seg=(28, 16))
    blob(p, (0, 0.01, 0.02), (0.17, 0.14, 0.08), "M_Pants")
    p.cyl((0, -0.01, 0.03), 0.05, 0.175, "M_HoodieDark", seg=24, radius2=0.17)
    # Bolso canguru: a frente e as duas bocas (do lado, mais escuras).
    p.box(-0.11, -0.235, 0.07, 0.11, -0.2, 0.17, "M_HoodieDark", bevel=0.02)
    for x in (-1, 1):
        m = Matrix.Translation((x * 0.1, -0.232, 0.13)) @ Matrix.Rotation(x * 0.35, 4, "Y")
        p.box_m((0.012, 0.012, 0.075), m, "M_PantsDark", bevel=0.004)
    # Gola de ribana em volta do pescoço e o capuz caído nas costas, com a borda virada.
    ring(p, (0, 0.0, 0.585), 0.06, 0.022, "M_HoodieDark", seg=(20, 8), plane="XY")
    blob(p, (0, 0.13, 0.5), (0.15, 0.06, 0.13), hood, rot=Matrix.Rotation(-0.25, 4, "X"))
    ring(p, (0, 0.15, 0.52), 0.1, 0.018, "M_HoodieDark", seg=(20, 8), plane="XZ", scale=(1.25, 1.0, 1.0))
    # Cordões do capuz, com a ponta de plástico.
    for x in (-0.04, 0.04):
        p.cyl((x, -0.115, 0.5), 0.12, 0.007, "M_Drawstring", seg=8)
        blob(p, (x, -0.117, 0.435), (0.01, 0.01, 0.014), "M_Drawstring", seg=(8, 6))
    # Bolsos de trás da calça, aparecendo embaixo do moletom.
    for x in (-1, 1):
        m = Matrix.Translation((x * 0.075, 0.135, -0.01)) @ Matrix.Rotation(0.25, 4, "X")
        p.box_m((0.09, 0.012, 0.075), m, "M_PantsDark", bevel=0.01)
    return p.finish("Char_Body", coll, loc=tuple(HIP), parent=root)


def head(coll, parent):
    """Cabeça oval de adulto: barba por fazer no queixo, olhos pequenos de pálpebra caída e
    olheira, sobrancelhas finas meio franzidas, nariz comprido caído, orelhas e um sorrisinho
    torto."""
    p = lib.Part(bevel=0.004)
    p.cyl((0, -0.01, 0.03), 0.14, 0.048, "M_Skin", seg=16)
    blob(p, (0, -0.055, 0.03), (0.016, 0.014, 0.022), "M_Skin", seg=(10, 8))  # pomo de adão
    blob(p, HEAD_C, HEAD_R, "M_Skin", seg=(32, 20))
    # Barba por fazer: a metade de baixo de um ovo um tantinho maior que a cabeça.
    half_blob(p, (HEAD_C.x, HEAD_C.y, HEAD_C.z - 0.06), (HEAD_R.x * 1.006, HEAD_R.y * 1.006, HEAD_R.z * 1.0),
              "M_Stubble", seg=(32, 12), closed=False)
    for s in (-1, 1):
        blob(p, (s * 0.158, HEAD_C.y + 0.01, 0.2), (0.022, 0.032, 0.048), "M_Skin", seg=(12, 8))
        blob(p, (s * 0.172, HEAD_C.y + 0.004, 0.2), (0.01, 0.018, 0.03), "M_EarIn", seg=(10, 8))
    ez = 0.245
    for s in (-1, 1):
        ex = s * 0.058
        ey = head_front(ex, ez)
        blob(p, (ex, ey + 0.008, ez), (0.04, 0.022, 0.032), "M_EyeWhite", seg=(16, 10))
        blob(p, (ex - s * 0.006, ey - 0.012, ez - 0.008), (0.012, 0.007, 0.013), "M_Pupil", seg=(10, 8))
        # Pálpebra de cima caída até o meio do olho (cara de sono) e a olheira embaixo.
        half_blob(p, (ex, ey + 0.006, ez - 0.002), (0.044, 0.026, 0.036), "M_Skin", rot=FLIP, seg=(16, 8))
        blob(p, (ex, head_front(ex, ez - 0.036) + 0.002, ez - 0.036), (0.034, 0.01, 0.011), "M_EyeBags", seg=(12, 6))
        bz = ez + 0.052
        m = Matrix.Translation((ex, head_front(ex, bz) - 0.003, bz)) @ Matrix.Rotation(s * 0.22, 4, "Y")
        p.box_m((0.052, 0.012, 0.011), m, "M_Brow", bevel=0.005)
    # Nariz comprido, caído para baixo.
    nz = 0.18
    m = Matrix.Rotation(0.35, 4, "X")
    nose = Vector((0.0, head_front(0.0, nz) - 0.045, nz - 0.01))
    blob(p, nose, (0.028, 0.06, 0.032), "M_Nose", rot=m, seg=(14, 10))
    # Narinas embaixo da ponta do nariz.
    for s in (-1, 1):
        blob(p, nose + Vector((s * 0.012, -0.03, -0.03)), (0.007, 0.009, 0.004), "M_Nostril", seg=(8, 6))
    # Sorrisinho torto: boca pequena puxada para um lado, com os dentes de cima.
    mz = 0.1
    my = head_front(0.01, mz)
    tilt = Matrix.Rotation(0.18, 4, "Y")
    half_blob(p, (0.014, my + 0.006, mz), (0.075, 0.03, 0.04), "M_MouthIn", rot=tilt, seg=(16, 8))
    p.box_m((0.09, 0.014, 0.014), Matrix.Translation((0.014, my - 0.017, mz - 0.008)) @ tilt, "M_Teeth", bevel=0.004)
    ob = p.finish("Char_Head", coll, loc=tuple(NECK - HIP), parent=parent)
    accessories(coll, ob)
    return ob


def accessories(coll, parent):
    hr = HEAD_R
    top = HEAD_C.z + hr.z
    cy = HEAD_C.y
    # Boné virado para trás: copa em cima da cabeça e a aba saindo pela nuca.
    p = lib.Part(bevel=0.005)
    half_blob(p, (0, cy, top - 0.12), (hr.x * 1.04, hr.y * 1.04, 0.15), "M_CapCrown", rot=FLIP)
    p.cyl((0, cy, top - 0.12), 0.022, hr.x * 1.045, "M_CapBrim", seg=28, radius2=hr.x * 1.05)
    m = Matrix.Translation((0, cy + hr.y + 0.06, top - 0.125)) @ Matrix.Rotation(-0.12, 4, "X")
    p.box_m((0.15, 0.13, 0.013), m, "M_CapBrim", bevel=0.006)
    blob(p, (0, cy, top + 0.03), (0.016, 0.016, 0.01), "M_CapBrim", seg=(10, 6))
    p.finish("Acc_Cap", coll, parent=parent)

    # Óculos redondos de aro preto grosso.
    p = lib.Part()
    ez = 0.245
    for s in (-1, 1):
        ex = s * 0.062
        ring(p, (ex, head_front(ex, ez) - 0.03, ez), 0.048, 0.008, "M_GlassesFrame")
        hy0 = head_front(s * 0.11, ez) - 0.025
        x0, x1 = sorted((s * 0.108, s * 0.162))
        p.box(x0, hy0, ez - 0.006, x1, cy + 0.02, ez + 0.006, "M_GlassesFrame")
    fy = head_front(0, ez)
    p.box(-0.016, fy - 0.045, ez - 0.004, 0.016, fy - 0.028, ez + 0.008, "M_GlassesFrame")
    p.finish("Acc_Glasses", coll, parent=parent)

    # Topete com entradas: um chumaço alto jogado para trás e cabelo dos lados.
    p = lib.Part()
    for (y, z, r, tilt) in ((0.02, top - 0.02, (0.12, 0.12, 0.06), 0.2),
                            (-0.06, top + 0.02, (0.1, 0.09, 0.055), 0.5),
                            (-0.12, top + 0.01, (0.07, 0.06, 0.045), 0.9)):
        blob(p, (0, cy + y, z), r, "M_Hair", rot=Matrix.Rotation(tilt, 4, "X"), seg=(20, 12))
    for s in (-1, 1):
        blob(p, (s * 0.145, cy + 0.04, HEAD_C.z + 0.07), (0.035, 0.11, 0.08), "M_Hair", seg=(14, 10))
    p.finish("Acc_Quiff", coll, parent=parent)

    # Gorro de lã com a barra dobrada e o pompom.
    p = lib.Part(bevel=0.008)
    half_blob(p, (0, cy, top - 0.12), (hr.x * 1.05, hr.y * 1.05, 0.19), "M_Beanie", rot=FLIP)
    p.cyl((0, cy, top - 0.115), 0.06, hr.x * 1.07, "M_BeanieCuff", seg=28, radius2=hr.x * 1.06)
    blob(p, (0, cy, top + 0.08), (0.05, 0.05, 0.046), "M_Pompom", seg=(14, 10))
    p.finish("Acc_Beanie", coll, parent=parent)


def arm(coll, parent, s):
    """Braço da manga do ombro (origem) ao cotovelo, o antebraço com o punho de ribana e a luva
    no pulso, cada um à parte (o Godot dobra o cotovelo)."""
    side = "L" if s > 0 else "R"
    p = lib.Part(bevel=0.005)
    blob(p, (0, 0, -0.02), (0.047, 0.047, 0.06), "M_Hoodie", seg=(14, 10))
    p.cyl((0, 0, -UPPER_ARM / 2), UPPER_ARM, 0.045, "M_Hoodie", seg=14, radius2=0.043)
    ob = p.finish(f"Char_Arm_{side}", coll, loc=(s * SHOULDER.x, SHOULDER.y, SHOULDER.z - HIP.z), parent=parent)

    # Antebraço: a bola do cotovelo esconde a emenda quando dobra; a manga embola no punho.
    f = lib.Part(bevel=0.005)
    blob(f, (0, 0, 0), (0.045, 0.045, 0.045), "M_Hoodie", seg=(14, 10))
    f.cyl((0, 0, -FOREARM / 2 + 0.01), FOREARM - 0.02, 0.043, "M_Hoodie", seg=14, radius2=0.042)
    for i, z in enumerate((-FOREARM + 0.075, -FOREARM + 0.055)):
        f.cyl((0, 0, z), 0.018, 0.047 - i * 0.001, "M_Hoodie", seg=14)
    f.cyl((0, 0, -FOREARM + 0.022), 0.045, 0.045, "M_HoodieDark", seg=14)
    fore = f.finish(f"Char_Forearm_{side}", coll, loc=(0, 0, -UPPER_ARM), parent=ob)

    glove(coll, fore, s, side)
    return ob


def glove(coll, parent, s, side):
    """Luva de borracha de desenho animado: punho largo, palma gordinha virada para o corpo,
    três dedos grossos meio dobrados e o polegar na frente."""
    g = lib.Part(bevel=0.005)
    g.cyl((0, 0, -0.005), 0.03, 0.044, "M_GloveCuff", seg=14, radius2=0.05)
    blob(g, (0, -0.004, -0.06), (0.03, 0.045, 0.048), "M_Glove", seg=(16, 10))
    # Dedos: saem da palma para baixo, um pouco curvados para dentro (para o lado da palma).
    for y, length in ((-0.026, 0.034), (0.0, 0.038), (0.026, 0.032)):
        curl = Matrix.Rotation(s * 0.35, 4, "Y")
        tip = Vector((-s * 0.004, y, -0.1))
        blob(g, tip, (0.015, 0.015, length), "M_Glove", rot=curl, seg=(12, 8))
    # Polegar na frente da palma, apontando para frente e para baixo.
    thumb = Matrix.Rotation(-0.7, 4, "X") @ Matrix.Rotation(s * 0.3, 4, "Y")
    blob(g, (-s * 0.012, -0.048, -0.05), (0.015, 0.015, 0.032), "M_Glove", rot=thumb, seg=(12, 8))
    g.finish(f"Char_Glove_{side}", coll, loc=(0, 0, -FOREARM), parent=parent)


def leg(coll, parent, s):
    """Coxa (do quadril ao joelho) e a canela com a barra da calça embolada em cima do tênis: bico
    de borracha, sola, lingueta, cadarço, listra do lado e o reforço do calcanhar (bico para -Y)."""
    side = "L" if s > 0 else "R"
    p = lib.Part(bevel=0.008)
    p.cyl((0, 0, -THIGH / 2), THIGH, 0.066, "M_Pants", seg=14, radius2=0.07)
    ob = p.finish(f"Char_Leg_{side}", coll, loc=(s * LEG_X, 0, HIP.z), parent=parent)

    k = lib.Part(bevel=0.008)
    blob(k, (0, 0, 0), (0.064, 0.064, 0.05), "M_Pants", seg=(14, 10))
    k.cyl((0, 0, -SHIN / 2 + 0.02), SHIN - 0.04, 0.06, "M_Pants", seg=14, radius2=0.064)
    foot = -SHIN
    # Barra embolada: dois gomos mais largos logo acima do tênis.
    for i, z in enumerate((foot + 0.135, foot + 0.11)):
        k.cyl((0, 0.005, z), 0.03, 0.068 + i * 0.004, "M_Pants", seg=14)
    k.box(-0.068, -0.21, foot + 0.012, 0.068, 0.07, foot + 0.1, "M_Shoe", bevel=0.042)
    k.box(-0.07, -0.205, foot, 0.07, 0.065, foot + 0.026, "M_ShoeSole", bevel=0.011)
    # Bico de borracha, lingueta e três passadas de cadarço.
    half_blob(k, (0, -0.15, foot + 0.03), (0.066, 0.065, 0.055), "M_ShoeToe", rot=FLIP, seg=(16, 8))
    m = Matrix.Translation((0, -0.035, foot + 0.1)) @ Matrix.Rotation(-0.3, 4, "X")
    k.box_m((0.06, 0.08, 0.016), m, "M_Shoe", bevel=0.007)
    for i in range(3):
        y = -0.1 + i * 0.026
        z = foot + 0.088 + i * 0.006
        k.box(-0.03, y - 0.005, z, 0.03, y + 0.005, z + 0.01, "M_Lace", bevel=0.004)
    # Listra do lado (de fora e de dentro) e o reforço do calcanhar.
    for x in (-0.0705, 0.0705):
        m = Matrix.Translation((x, -0.06, foot + 0.06)) @ Matrix.Rotation(0.5, 4, "X")
        k.box_m((0.006, 0.11, 0.022), m, "M_ShoeStripe", bevel=0.003)
    k.box(-0.05, 0.06, foot + 0.03, 0.05, 0.075, foot + 0.11, "M_ShoeStripe", bevel=0.01)
    k.finish(f"Char_Shin_{side}", coll, loc=(0, 0, -THIGH), parent=ob)
    return ob


# --- Montagem --------------------------------------------------------------------------------------

def build():
    bpy.data.batch_remove(list(bpy.data.objects) + list(bpy.data.collections))
    bpy.data.batch_remove(list(bpy.data.meshes) + list(bpy.data.materials))
    coll = bpy.data.collections.new("Character")
    bpy.context.scene.collection.children.link(coll)
    root = lib.empty("Character", coll, (0, 0, 0))
    b = body(coll, root)
    head(coll, b)
    for s in (-1, 1):
        arm(coll, b, s)
        leg(coll, root, s)
    return coll


def run(export=False):
    if os.path.exists(BLEND) and os.path.normcase(bpy.data.filepath) != os.path.normcase(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    build()
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    if export:
        bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_apply=True,
                                  export_cameras=False, export_lights=False)
        print("exportado:", GLB)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    run(export="--export" in args)
