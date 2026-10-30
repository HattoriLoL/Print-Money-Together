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
        Char_Arm_L/R ombro: manga pendurada para baixo (ARM_LEN)
          Char_Glove_L/R  pulso: luva de borracha
      Char_Leg_L/R   quadril: perna da calça e o tênis

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


def ring(p, center, radius, tube, mat, seg=(24, 8)):
    """Argola (aro dos óculos) no plano XZ, olhando para -Y."""
    rows = []
    for i in range(seg[0]):
        a = i / seg[0] * math.tau
        row = []
        for j in range(seg[1]):
            b = j / seg[1] * math.tau
            r = radius + tube * math.cos(b)
            co = Vector((r * math.cos(a), tube * math.sin(b), r * math.sin(a)))
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
    cordões, capuz embolado atrás e o cós da calça."""
    p = lib.Part(bevel=0.01)
    hood = "M_Hoodie"
    blob(p, (0, 0.01, 0.36), (0.225, 0.145, 0.26), hood, seg=(28, 16))
    blob(p, (0, -0.04, 0.16), (0.21, 0.19, 0.17), hood, seg=(28, 16))
    blob(p, (0, 0, 0.02), (0.17, 0.13, 0.08), "M_Pants")
    p.cyl((0, -0.01, 0.03), 0.05, 0.175, "M_HoodieDark", seg=24, radius2=0.17)
    p.box(-0.11, -0.235, 0.07, 0.11, -0.2, 0.17, "M_HoodieDark", bevel=0.02)
    blob(p, (0, 0.06, 0.6), (0.15, 0.1, 0.06), hood)
    for x in (-0.04, 0.04):
        p.cyl((x, -0.115, 0.5), 0.12, 0.007, "M_Drawstring", seg=8)
        blob(p, (x, -0.117, 0.435), (0.01, 0.01, 0.014), "M_Drawstring", seg=(8, 6))
    return p.finish("Char_Body", coll, loc=tuple(HIP), parent=root)


def head(coll, parent):
    """Cabeça oval de adulto: barba por fazer no queixo, olhos pequenos de pálpebra caída e
    olheira, sobrancelhas finas meio franzidas, nariz comprido caído, orelhas e um sorrisinho
    torto."""
    p = lib.Part(bevel=0.004)
    p.cyl((0, -0.01, 0.03), 0.14, 0.048, "M_Skin", seg=16)
    blob(p, HEAD_C, HEAD_R, "M_Skin", seg=(32, 20))
    # Barba por fazer: a metade de baixo de um ovo um tantinho maior que a cabeça.
    half_blob(p, (HEAD_C.x, HEAD_C.y, HEAD_C.z - 0.06), (HEAD_R.x * 1.006, HEAD_R.y * 1.006, HEAD_R.z * 1.0),
              "M_Stubble", seg=(32, 12), closed=False)
    for s in (-1, 1):
        blob(p, (s * 0.158, HEAD_C.y + 0.01, 0.2), (0.022, 0.032, 0.048), "M_Skin", seg=(12, 8))
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
    blob(p, (0.0, head_front(0.0, nz) - 0.045, nz - 0.01), (0.028, 0.06, 0.032), "M_Nose", rot=m, seg=(14, 10))
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
    """Manga comprida e fina do ombro (origem) até o punho, e a luva no pulso, à parte."""
    p = lib.Part(bevel=0.005)
    blob(p, (0, 0, -0.02), (0.047, 0.047, 0.06), "M_Hoodie", seg=(14, 10))
    p.cyl((0, 0, -ARM_LEN / 2 + 0.02), ARM_LEN - 0.04, 0.045, "M_Hoodie", seg=14, radius2=0.04)
    p.cyl((0, 0, -ARM_LEN + 0.02), 0.05, 0.046, "M_HoodieDark", seg=14)
    side = "L" if s > 0 else "R"
    ob = p.finish(f"Char_Arm_{side}", coll, loc=(s * SHOULDER.x, SHOULDER.y, SHOULDER.z - HIP.z), parent=parent)

    g = lib.Part(bevel=0.005)
    g.cyl((0, 0, -0.01), 0.04, 0.042, "M_GloveCuff", seg=14)
    blob(g, (0, -0.005, -0.08), (0.045, 0.03, 0.07), "M_Glove", seg=(16, 10))
    blob(g, (-s * 0.038, -0.02, -0.06), (0.017, 0.017, 0.038), "M_Glove",
         rot=Matrix.Rotation(-s * 0.5, 4, "Y"), seg=(10, 8))
    g.finish(f"Char_Glove_{side}", coll, loc=(0, 0, -ARM_LEN), parent=ob)
    return ob


def leg(coll, parent, s):
    """Perna comprida e fina da calça e o tênis grande (bico para -Y)."""
    p = lib.Part(bevel=0.008)
    foot = -HIP.z
    p.cyl((0, 0, foot / 2 + 0.04), -foot - 0.04, 0.058, "M_Pants", seg=14, radius2=0.068)
    p.box(-0.068, -0.21, foot + 0.012, 0.068, 0.07, foot + 0.1, "M_Shoe", bevel=0.042)
    p.box(-0.07, -0.205, foot, 0.07, 0.065, foot + 0.026, "M_ShoeSole", bevel=0.011)
    p.box(-0.042, -0.12, foot + 0.085, 0.042, -0.03, foot + 0.105, "M_Shoe", bevel=0.01)
    side = "L" if s > 0 else "R"
    return p.finish(f"Char_Leg_{side}", coll, loc=(s * LEG_X, 0, HIP.z), parent=parent)


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
