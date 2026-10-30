"""Boneco dos jogadores: um adulto de desenho animado, desengonçado e meio acabado (comprido,
curvado, peito estreito e barriguinha de cerveja, braços e pernas finos e longos, tênis grandes),
de cara cansada: olhos pequenos de pálpebra caída e olheira, nariz comprido, sorrisinho torto e
barba por fazer. Moletom com capuz e luvas amarelas de borracha. Todos usam o mesmo boneco; a vaga
muda a cor do moletom (o jogo pinta M_Hoodie e M_HoodieDark) e o acessório (Acc_*).

Exporta assets/models/character.glb com um esqueleto (Armature) e:
- Char_Body: o corpo numa malha só (moletom, mangas e calça), feita de metaballs: o tronco é
  uma peça lisa (quadril, barriga, peito e ombros fundidos) e cada braço e perna são cápsulas
  fundidas com o cotovelo e o joelho. Leva os pesos dos ossos: ombro, cotovelo, quadril e joelho
  dobram como pano, sem emendas;
- peças rígidas presas nos ossos: a cabeça (Char_Head, com o rosto e os acessórios Acc_Cap,
  Acc_Glasses, Acc_Quiff e Acc_Beanie; o jogo mostra só o da vaga), as luvas (Char_Glove_L/R),
  os tênis com a barra da calça (Char_Shoe_L/R), os punhos das mangas (Char_Cuff_L/R) e os
  detalhes do moletom (Char_Hood: capuz, gola e cordões; Char_Pocket: bolso canguru;
  Char_BackPockets: bolsos de trás da calça).

Ossos (o Godot anima por código, scripts/character_rig.gd): Hips > Spine > Chest > Neck > Head,
Chest > UpperArm.L/R > Forearm.L/R > Hand.L/R, Hips > Thigh.L/R > Shin.L/R > Foot.L/R.

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

# Juntas (no boneco em pé, pés em z = 0). Pernas compridas, olhos a 1,60 m. Só o lado esquerdo
# (+X); o direito é o espelho.
HIP = Vector((0.0, 0.0, 0.8))
NECK = Vector((0.0, 0.0, 1.36))
SHOULDER = Vector((0.18, 0.0, 1.27))
ELBOW = Vector((0.235, 0.005, 0.98))
WRIST = Vector((0.265, -0.01, 0.69))
HIP_JOINT = Vector((0.09, 0.0, 0.77))
KNEE = Vector((0.095, -0.005, 0.42))
ANKLE = Vector((0.1, 0.0, 0.1))
# Cabeça: centro (a partir do pescoço; um pouco para frente, de quem anda curvado) e raios do
# ovo, mais alto que largo.
HEAD_C = Vector((0.0, -0.03, 0.2))
HEAD_R = Vector((0.16, 0.16, 0.2))

# Ossos: nome -> (cabeça, cauda, pai). Os .L/.R saem de mirror().
BONES = {
    "Hips": ((0, 0, 0.8), (0, 0, 0.92), None),
    "Spine": ((0, 0, 0.92), (0, 0, 1.12), "Hips"),
    "Chest": ((0, 0, 1.12), (0, 0, 1.3), "Spine"),
    "Neck": ((0, 0, 1.3), tuple(NECK), "Chest"),
    "Head": (tuple(NECK), (0, -0.01, 1.58), "Neck"),
    "UpperArm.L": (tuple(SHOULDER), tuple(ELBOW), "Chest"),
    "Forearm.L": (tuple(ELBOW), tuple(WRIST), "UpperArm.L"),
    "Hand.L": (tuple(WRIST), (0.27, -0.012, 0.6), "Forearm.L"),
    "Thigh.L": (tuple(HIP_JOINT), tuple(KNEE), "Hips"),
    "Shin.L": (tuple(KNEE), tuple(ANKLE), "Thigh.L"),
    "Foot.L": (tuple(ANKLE), (0.1, -0.13, 0.03), "Shin.L"),
}
# Ossos que entram nos pesos da malha do corpo (mão, pé, pescoço e cabeça são peças rígidas).
SKIN_BONES = ("Hips", "Spine", "Chest", "UpperArm", "Forearm", "Thigh", "Shin")

# Corpo em metaballs. Medidas em semi-eixos de verdade (o código converte: uma metaball isolada
# sai com ~57% do raio pedido). Tronco: elipsoides (centro, semi-eixos); a barriga vai para frente
# (y negativo) e é mais larga que o peito: barriguinha de cerveja.
META_FIT = 1.745
TORSO = [
    ((0, 0.01, 0.8), (0.155, 0.12, 0.1)),
    ((0, -0.05, 0.95), (0.19, 0.18, 0.14)),
    ((0, 0.005, 1.11), (0.175, 0.125, 0.12)),
    ((0, 0.012, 1.23), (0.17, 0.1, 0.065)),
    ((0, 0.0, 1.32), (0.055, 0.05, 0.045)),
]
# Braço e perna (lado esquerdo): cápsulas entre as juntas (raio) e bolas nas juntas (raio).
ARM_CAPSULES = [(SHOULDER, ELBOW, 0.046), (ELBOW, WRIST + Vector((0, 0, 0.02)), 0.041)]
ARM_BALLS = [(SHOULDER, 0.05), (ELBOW, 0.04)]
LEG_CAPSULES = [(HIP_JOINT, KNEE, 0.066), (KNEE, ANKLE + Vector((0, 0, 0.04)), 0.058)]
LEG_BALLS = [(HIP_JOINT + Vector((0, 0.005, 0.01)), 0.074), (KNEE, 0.052)]
# Ossos que cada pedaço do corpo pode usar nos pesos.
PART_BONES = {
    "torso": ("Hips", "Spine", "Chest"),
    "arm": ("Chest", "UpperArm", "Forearm"),
    "leg": ("Hips", "Thigh", "Shin"),
}
# Alturas da roupa no tronco: abaixo, calça; entre as duas, a barra de ribana do moletom.
HEM = (0.83, 0.865)


def mirror(name):
    return name.replace(".L", ".R") if name.endswith(".L") else name


def flip_x(v):
    return (-v[0], v[1], v[2])


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


# --- Cabeça e acessórios --------------------------------------------------------------------------

def head(coll, parent):
    # `parent` é o esqueleto: a cabeça vai presa no osso Head.
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
    ob = _attach(p, "Char_Head", coll, parent, "Head", NECK)
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


def glove(coll, rig, s, side, wrist):
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
    _attach(g, f"Char_Glove_{side}", coll, rig, f"Hand.{side}", wrist)


# --- Esqueleto e corpo -----------------------------------------------------------------------------

def armature(coll):
    """O esqueleto, em pé (a pose de descanso é a do modelo)."""
    data = bpy.data.armatures.new("Armature")
    rig = bpy.data.objects.new("Armature", data)
    coll.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    specs = dict(BONES)
    for name, (head, tail, parent) in BONES.items():
        if name.endswith(".L"):
            specs[mirror(name)] = (flip_x(head), flip_x(tail), mirror(parent) if parent else None)
    for name, (head, tail, _parent) in specs.items():
        b = data.edit_bones.new(name)
        b.head, b.tail = head, tail
        b.roll = 0.0
    for name, (_head, _tail, parent) in specs.items():
        if parent:
            data.edit_bones[name].parent = data.edit_bones[parent]
            data.edit_bones[name].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig, specs


def _segment_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def _metaball(name, coll, elements):
    """Malha de um grupo de metaballs que se fundem. `elements`: (tipo, centro, tamanho, giro)."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = mb.render_resolution = 0.014
    mb.threshold = 0.6
    ob = bpy.data.objects.new(name, mb)
    coll.objects.link(ob)
    for kind, center, size, rot in elements:
        el = mb.elements.new(type=kind)
        el.co = center
        el.stiffness = 2.0
        if kind == "ELLIPSOID":
            el.radius = 1.0
            el.size_x, el.size_y, el.size_z = (a * META_FIT for a in size)
        elif kind == "CAPSULE":
            el.radius = size[1] * META_FIT
            el.size_x = size[0]
            el.rotation = rot
        else:
            el.radius = size * META_FIT
    bpy.context.view_layer.update()
    mesh = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(ob)
    bpy.data.metaballs.remove(mb)
    return mesh


def _limb(name, coll, capsules, balls, s):
    els = []
    for a, b, r in capsules:
        a, b = Vector((s * a.x, a.y, a.z)), Vector((s * b.x, b.y, b.z))
        rot = Vector((1, 0, 0)).rotation_difference((b - a).normalized())
        els.append(("CAPSULE", (a + b) / 2, ((b - a).length / 2, r), rot))
    for c, r in balls:
        els.append(("BALL", Vector((s * c.x, c.y, c.z)), r, None))
    return _metaball(name, coll, els)


def body(coll, rig, specs):
    """O corpo numa malha só: o tronco, os dois braços e as duas pernas em metaballs, juntados. A
    roupa sai do pedaço e da altura (calça, moletom, barra e punho), e os pesos da distância até
    os ossos que cada pedaço pode usar (cada lado só pega os ossos do seu lado)."""
    pieces = [("torso", 0, _metaball("TorsoMeta", coll, [("ELLIPSOID", c, a, None) for c, a in TORSO]))]
    for s in (-1, 1):
        pieces.append(("arm", s, _limb(f"ArmMeta{s}", coll, ARM_CAPSULES, ARM_BALLS, s)))
        pieces.append(("leg", s, _limb(f"LegMeta{s}", coll, LEG_CAPSULES, LEG_BALLS, s)))
    bm = bmesh.new()
    face_part = []
    vert_part = []
    for part, s, me in pieces:
        nf, nv = len(bm.faces), len(bm.verts)
        bm.from_mesh(me)
        face_part += [(part, s)] * (len(bm.faces) - nf)
        vert_part += [(part, s)] * (len(bm.verts) - nv)
        bpy.data.meshes.remove(me)
    mesh = bpy.data.meshes.new("Char_Body")
    bm.to_mesh(mesh)
    bm.free()
    body_ob = bpy.data.objects.new("Char_Body", mesh)
    coll.objects.link(body_ob)

    mats = ["M_Hoodie", "M_HoodieDark", "M_Pants"]
    for m in mats:
        mesh.materials.append(lib.material(m))
    segs = {name: (Vector(h), Vector(t)) for name, (h, t, _p) in specs.items()}
    for poly, (part, s) in zip(mesh.polygons, face_part):
        c = poly.center
        if part == "leg":
            mat = "M_Pants"
        elif part == "arm":
            wrist = Vector((s * WRIST.x, WRIST.y, WRIST.z))
            mat = "M_HoodieDark" if (c - wrist).length < 0.06 else "M_Hoodie"
        elif c.z < HEM[0]:
            mat = "M_Pants"
        elif c.z < HEM[1]:
            mat = "M_HoodieDark"
        else:
            mat = "M_Hoodie"
        poly.material_index = mats.index(mat)
        poly.use_smooth = True

    # Pesos: inverso da distância até cada osso que o pedaço pode usar, os três mais perto.
    groups = {n: body_ob.vertex_groups.new(name=n) for n in specs if n.split(".")[0] in SKIN_BONES}
    for v, (part, s) in zip(mesh.vertices, vert_part):
        allowed = PART_BONES[part]
        ws = []
        for n in groups:
            base = n.split(".")[0]
            if base not in allowed:
                continue
            if (n.endswith(".L") and s < 0) or (n.endswith(".R") and s > 0):
                continue
            if part == "torso" and (n.endswith(".L") or n.endswith(".R")):
                continue
            d = max(_segment_dist(v.co, *segs[n]), 0.005)
            ws.append((1.0 / d ** 6, n))
        ws.sort(reverse=True)
        ws = ws[:3]
        total = sum(w for w, _ in ws)
        for w, n in ws:
            groups[n].add([v.index], w / total, "REPLACE")
    body_ob.parent = rig
    mod = body_ob.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return body_ob


def _attach(part, name, coll, rig, bone, pivot):
    """Fecha a peça rígida `part` (geometria em volta da origem) e prende no osso `bone`, com a
    origem em `pivot` (no mundo)."""
    ob = part.finish(name, coll)
    ob.parent = rig
    ob.parent_type = "BONE"
    ob.parent_bone = bone
    bpy.context.view_layer.update()
    ob.matrix_world = Matrix.Translation(pivot)
    return ob


def clothes(coll, rig):
    """Detalhes do moletom presos nos ossos: capuz caído nas costas e gola com os cordões (no
    peito), o bolso canguru com as bocas (na barriga) e os bolsos de trás da calça (no quadril)."""
    hood = "M_Hoodie"
    p = lib.Part(bevel=0.008)
    # Gola de ribana em volta do pescoço (origem no pescoço).
    ring(p, (0, 0.0, -0.035), 0.062, 0.02, "M_HoodieDark", seg=(20, 8), plane="XY")
    # Capuz caído nas costas: um pano achatado colado no ombro, com a boca (mais escura) para
    # cima, encostada na nuca.
    tilt = Matrix.Rotation(-0.35, 4, "X")
    blob(p, (0, 0.115, -0.1), (0.13, 0.045, 0.1), hood, rot=tilt, seg=(24, 12))
    blob(p, (0, 0.1, -0.035), (0.085, 0.028, 0.03), "M_HoodieDark", rot=tilt, seg=(16, 8))
    # Cordões do capuz, deitados no peito (o alto mais para trás), com a ponta de plástico.
    for x in (-0.04, 0.04):
        m = Matrix.Translation((x, -0.105, -0.15)) @ Matrix.Rotation(-0.28, 4, "X")
        p.cyl((0, 0, 0), 0.12, 0.007, "M_Drawstring", seg=8, matrix=m)
        blob(p, (x, -0.124, -0.215), (0.01, 0.01, 0.014), "M_Drawstring", seg=(8, 6))
    _attach(p, "Char_Hood", coll, rig, "Chest", NECK)

    # Bolso canguru na frente da barriga (origem no centro da barriga), com as bocas do lado.
    center = Vector((0, -0.232, 0.93))
    p = lib.Part(bevel=0.012)
    m = Matrix.Rotation(0.1, 4, "X")
    p.box_m((0.2, 0.02, 0.1), m, "M_HoodieDark", bevel=0.012)
    for x in (-1, 1):
        mm = Matrix.Translation((x * 0.092, -0.008, 0.0)) @ m @ Matrix.Rotation(x * 0.35, 4, "Y")
        p.box_m((0.012, 0.012, 0.075), mm, "M_PantsDark", bevel=0.004)
    _attach(p, "Char_Pocket", coll, rig, "Spine", center)

    # Bolsos de trás da calça, aparecendo embaixo do moletom.
    p = lib.Part(bevel=0.01)
    for x in (-1, 1):
        mm = Matrix.Translation((x * 0.075, 0.0, 0.0)) @ Matrix.Rotation(0.25, 4, "X")
        p.box_m((0.09, 0.012, 0.075), mm, "M_PantsDark", bevel=0.01)
    _attach(p, "Char_BackPockets", coll, rig, "Hips", Vector((0, 0.138, 0.78)))


def cuffs_and_gloves(coll, rig, s):
    """Punho de ribana da manga (no antebraço) e a luva (na mão)."""
    side = "L" if s > 0 else "R"
    wrist = Vector((s * WRIST.x, WRIST.y, WRIST.z))
    p = lib.Part(bevel=0.005)
    for i, z in enumerate((0.075, 0.052)):
        p.cyl((0, 0, z), 0.018, 0.047 - i * 0.001, "M_Hoodie", seg=14)
    p.cyl((0, 0, 0.022), 0.045, 0.046, "M_HoodieDark", seg=14)
    _attach(p, f"Char_Cuff_{side}", coll, rig, f"Forearm.{side}", wrist)
    glove(coll, rig, s, side, wrist)


def shoe(coll, rig, s):
    """Barra da calça embolada e o tênis (bico para -Y), preso no pé: bico de borracha, sola,
    lingueta, cadarço, listra do lado e o reforço do calcanhar."""
    side = "L" if s > 0 else "R"
    ankle = Vector((s * ANKLE.x, ANKLE.y, ANKLE.z))
    k = lib.Part(bevel=0.008)
    foot = -ANKLE.z
    for i, z in enumerate((0.075, 0.05)):
        k.cyl((0, 0.005, z), 0.03, 0.069 + i * 0.004, "M_Pants", seg=14)
    k.box(-0.068, -0.21, foot + 0.012, 0.068, 0.07, foot + 0.1, "M_Shoe", bevel=0.042)
    k.box(-0.07, -0.205, foot, 0.07, 0.065, foot + 0.026, "M_ShoeSole", bevel=0.011)
    half_blob(k, (0, -0.15, foot + 0.03), (0.066, 0.065, 0.055), "M_ShoeToe", rot=FLIP, seg=(16, 8))
    m = Matrix.Translation((0, -0.035, foot + 0.1)) @ Matrix.Rotation(-0.3, 4, "X")
    k.box_m((0.06, 0.08, 0.016), m, "M_Shoe", bevel=0.007)
    for i in range(3):
        y = -0.1 + i * 0.026
        z = foot + 0.088 + i * 0.006
        k.box(-0.03, y - 0.005, z, 0.03, y + 0.005, z + 0.01, "M_Lace", bevel=0.004)
    for x in (-0.0705, 0.0705):
        m = Matrix.Translation((x, -0.06, foot + 0.06)) @ Matrix.Rotation(0.5, 4, "X")
        k.box_m((0.006, 0.11, 0.022), m, "M_ShoeStripe", bevel=0.003)
    k.box(-0.05, 0.06, foot + 0.03, 0.05, 0.075, foot + 0.11, "M_ShoeStripe", bevel=0.01)
    _attach(k, f"Char_Shoe_{side}", coll, rig, f"Foot.{side}", ankle)


# --- Montagem --------------------------------------------------------------------------------------

def build():
    bpy.data.batch_remove(list(bpy.data.objects) + list(bpy.data.collections))
    bpy.data.batch_remove(list(bpy.data.meshes) + list(bpy.data.materials) + list(bpy.data.armatures))
    coll = bpy.data.collections.new("Character")
    bpy.context.scene.collection.children.link(coll)
    rig, specs = armature(coll)
    body(coll, rig, specs)
    head(coll, rig)
    clothes(coll, rig)
    for s in (-1, 1):
        cuffs_and_gloves(coll, rig, s)
        shoe(coll, rig, s)
    return coll


def run(export=False):
    if os.path.exists(BLEND) and os.path.normcase(bpy.data.filepath) != os.path.normcase(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    build()
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    if export:
        bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_apply=True,
                                  export_cameras=False, export_lights=False, export_skins=True,
                                  export_animations=False)
        print("exportado:", GLB)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    run(export="--export" in args)
