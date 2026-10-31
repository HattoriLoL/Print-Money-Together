"""Mãos dos jogadores: luvas amarelas de borracha (de lavar louça, para não deixar digital nas
notas) e a manga do moletom, numa pose de segurar. Exporta assets/models/hands.glb com
Hand_R e Hand_L (segurando) e HandFlat_R e HandFlat_L (abertas, apertando a folha na guilhotina),
cada uma com a origem no pulso e em peças (manga, luva, cada dedo e os
curativos de quem perdeu dedo ou a mão na guilhotina).

Referencial (Blender): dedos para +Y, palma para -Z, dorso para +Z; na mão direita o polegar fica
do lado -X. A esquerda é o espelho. No Godot os dedos apontam para -Z e a palma para baixo.
O material M_Sleeve é pintado no jogo com a cor de cada jogador.

    blender --background --python art_source/blender/hands.py -- --export
"""

import math
import os
import sys

import bpy
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import lib  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
BLEND = os.path.join(ROOT, "art_source", "hands.blend")
GLB = os.path.join(ROOT, "assets", "models", "hands.glb")

lib.MATERIALS.update({
    "M_Glove": ((0.95, 0.72, 0.06), 0.32, 0.0, 0.0),
    "M_GloveCuff": ((0.88, 0.62, 0.04), 0.4, 0.0, 0.0),
    "M_Sleeve": ((0.9, 0.9, 0.9), 0.95, 0.0, 0.0),
    "M_SleeveCuff": ((0.55, 0.55, 0.55), 0.95, 0.0, 0.0),
    "M_Bandage": ((0.93, 0.9, 0.84), 0.9, 0.0, 0.0),
    "M_BandageSpot": ((0.78, 0.22, 0.2), 0.7, 0.0, 0.0),
})

# Os dedos, da frente (o lado do polegar) para trás; o jogo usa os mesmos nomes.
DIGITS = ("Thumb", "Index", "Middle", "Ring", "Pinky")

# Dedos do indicador ao mínimo: (x da base, largura, escala do comprimento, abertura em rad).
FINGERS = [(-0.027, 0.0185, 1.0, 0.05), (-0.009, 0.019, 1.08, 0.0), (0.009, 0.0185, 1.0, -0.04),
           (0.026, 0.016, 0.8, -0.1)]
SEGMENTS = (0.04, 0.027, 0.022)
# Poses: quanto cada junta dos dedos dobra para a palma, quanto eles abrem (vezes a abertura de
# FINGERS) e o giro do polegar (na base: Z e X; na ponta: X e Z).
POSES = {
    # Segurando folha ou resma (na mão): dedos dobrados, o polegar em pinça.
    "grip": {"curl": (0.35, 0.5, 0.35), "spread": 1.0, "thumb": (0.32, -0.55, -0.3, -0.15)},
    # Mão aberta apertando a folha na guilhotina: dedos quase esticados e abertos, as pontas
    # descendo até o papel, e o polegar aberto para o lado.
    "flat": {"curl": (0.14, 0.1, 0.08), "spread": 2.4, "thumb": (0.85, -0.12, -0.08, -0.1)},
}


def hand(name, coll, s, pose="grip"):
    """Uma mão; s = 1 direita, -1 esquerda (espelha x e os giros em Y e Z), na pose `pose`
    (POSES).

    Em peças, todas com a origem no pulso, para o jogo esconder o que o boneco perdeu na
    guilhotina (player.gd): a manga (`name`, a raiz), a luva (`name_Glove`: palma e punho), cada
    dedo (`name_Thumb`, `_Index`, `_Middle`, `_Ring`, `_Pinky`) e os curativos que aparecem no
    lugar (`name_Stump<Dedo>` na base de cada dedo, `name_StumpWrist` na ponta da manga)."""
    g = "M_Glove"
    curl_pose = POSES[pose]["curl"]
    thumb_pose = POSES[pose]["thumb"]
    # Manga do moletom com o punho de ribana.
    p = lib.Part(bevel=0.006)
    p.box(-0.045 * s, -0.13, -0.031, 0.045 * s, -0.082, 0.031, "M_SleeveCuff", bevel=0.0139)
    p.box(-0.05 * s, -0.38, -0.038, 0.05 * s, -0.12, 0.038, "M_Sleeve", bevel=0.03)
    root = _soft(p.finish(name, coll))
    # Palma inteira (do punho às juntas), bem arredondada, o calombo das juntas e o punho da luva
    # por cima, com a borda enrolada.
    p = lib.Part(bevel=0.006)
    p.box(-0.043 * s, -0.03, -0.016, 0.043 * s, 0.096, 0.016, g, bevel=0.0144)
    p.box(-0.04 * s, 0.07, -0.013, 0.04 * s, 0.1, 0.017, g, bevel=0.012)
    p.box(-0.046 * s, -0.08, -0.021, 0.046 * s, -0.005, 0.021, g, bevel=0.0144)
    p.box(-0.05 * s, -0.09, -0.025, 0.05 * s, -0.074, 0.025, "M_GloveCuff", bevel=0.0072)
    _soft(p.finish(name + "_Glove", coll, parent=root))
    # Dedos: três falanges cada, a última com a ponta bem redonda; o curativo cobre a base.
    for digit, (bx, w, scale, spread) in zip(DIGITS[1:], FINGERS):
        spread *= POSES[pose]["spread"]
        m = Matrix.Translation((bx * s, 0.095, 0.002)) @ Matrix.Rotation(spread * s, 4, "Z")
        _stump(name + "_Stump" + digit, coll, root,
               m @ Matrix.Rotation(-curl_pose[0], 4, "X") @ Matrix.Translation((0, 0.006, 0)), (w + 0.004, 0.017, 0.02))
        p = lib.Part(bevel=0.006)
        for i, (length, curl) in enumerate(zip(SEGMENTS, curl_pose)):
            length *= scale
            m = m @ Matrix.Rotation(-curl, 4, "X")
            p.box_m((w, length + 0.008, 0.017 - i * 0.0015), m @ Matrix.Translation((0, length / 2, 0)), g,
                    bevel=0.0076 if i < 2 else 0.0084)
            m = m @ Matrix.Translation((0, length, 0))
        _soft(p.finish(name + "_" + digit, coll, parent=root))
    # Polegar: sai da base da palma, aponta para a frente e para o lado da palma (oposto aos
    # dedos, como numa pinça).
    m = Matrix.Translation((-0.034 * s, 0.008, -0.008)) @ Matrix.Rotation(thumb_pose[0] * s, 4, "Z") \
        @ Matrix.Rotation(thumb_pose[1], 4, "X")
    _stump(name + "_StumpThumb", coll, root, m @ Matrix.Translation((0, 0.012, 0)), (0.029, 0.02, 0.026))
    p = lib.Part(bevel=0.006)
    p.box_m((0.025, 0.05, 0.022), m @ Matrix.Translation((0, 0.022, 0)), g, bevel=0.0098)
    m = m @ Matrix.Translation((0, 0.044, 0)) @ Matrix.Rotation(thumb_pose[2], 4, "X") \
        @ Matrix.Rotation(thumb_pose[3] * s, 4, "Z")
    p.box_m((0.022, 0.038, 0.019), m @ Matrix.Translation((0, 0.017, 0)), g, bevel=0.0085)
    _soft(p.finish(name + "_Thumb", coll, parent=root))
    # Sem a mão: um curativo enrolado na ponta da manga, com a mancha no meio.
    p = lib.Part(bevel=0.006)
    p.box(-0.04 * s, -0.098, -0.026, 0.04 * s, -0.062, 0.026, "M_Bandage", bevel=0.012)
    p.box(-0.014 * s, -0.0625, -0.012, 0.014 * s, -0.0595, 0.012, "M_BandageSpot", bevel=0.001)
    _soft(p.finish(name + "_StumpWrist", coll, parent=root))
    return root


def _stump(name, coll, root, matrix, size):
    """Curativo enrolado no toco de um dedo (escondido no jogo até o dedo ir embora)."""
    p = lib.Part(bevel=0.006)
    p.box_m(size, matrix, "M_Bandage", bevel=0.007)
    p.box_m((size[0] * 0.5, 0.003, size[2] * 0.5), matrix @ Matrix.Translation((0, size[1] / 2, 0)),
            "M_BandageSpot", bevel=0.001)
    _soft(p.finish(name, coll, parent=root))


def _soft(ob):
    """Borracha, tecido e gaze são moles: subdivide tudo uma vez, liso, sem quinas vivas."""
    for mod in list(ob.modifiers):
        ob.modifiers.remove(mod)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    for edge in ob.data.edges:
        edge.use_edge_sharp = False
    ob.modifiers.new("Subdivision", "SUBSURF").levels = 1
    ob.modifiers["Subdivision"].render_levels = 1
    return ob


def run(export=False):
    if os.path.exists(BLEND) and os.path.normcase(bpy.data.filepath) != os.path.normcase(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    bpy.data.batch_remove(list(bpy.data.objects) + list(bpy.data.collections))
    bpy.data.batch_remove(list(bpy.data.meshes) + list(bpy.data.materials))
    coll = bpy.data.collections.new("Hands")
    bpy.context.scene.collection.children.link(coll)
    hand("Hand_R", coll, 1).location.x = 0.12
    hand("Hand_L", coll, -1).location.x = -0.12
    # A pose de mão aberta, para apertar a folha na guilhotina.
    hand("HandFlat_R", coll, 1, "flat").location = (0.12, 0.45, 0.0)
    hand("HandFlat_L", coll, -1, "flat").location = (-0.12, 0.45, 0.0)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    if export:
        for ob in coll.objects:
            if ob.parent is None:
                ob.location = (0.0, 0.0, 0.0)  # cada mão com a origem no pulso, no lugar
        bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_apply=True,
                                  export_cameras=False, export_lights=False)
        print("exportado:", GLB)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    run(export="--export" in args)
