"""Renderiza prévias da kitnet sem abrir a interface (planta de cima sem o teto e vistas de dentro).

    blender --background art_source/kitnet.blend --python art_source/blender/preview.py -- <pasta>
"""

import math
import os
import sys

import bpy
from mathutils import Vector

# nome: (posição do olho, ponto olhado, lente em mm); None = planta ortográfica.
VIEWS = {
    "plan": None,
    "room_from_entry": ((4.3, 0.5, 1.65), (1.5, 4.0, 0.9), 14),
    "room_from_sofa": ((0.9, 4.6, 1.65), (4.5, 0.8, 0.9), 14),
    "printer": ((2.3, 2.9, 1.5), (2.2, 4.6, 0.8), 18),
    "printer_close": ((2.57, 4.05, 1.22), (2.31, 4.7, 0.86), 30),
    "printer_panel": ((2.45, 4.35, 1.15), (2.35, 4.66, 0.95), 45),
    "printer_back": ((1.7, 4.35, 1.3), (2.3, 4.85, 0.9), 28),
    "desk": ((2.9, 3.4, 1.0), (2.1, 4.7, 0.45), 18),
    "table": ((3.9, 3.0, 1.6), (2.6, 2.05, 0.75), 20),
    "guillotine": ((2.62, 1.35, 1.25), (2.3, 2.05, 0.8), 32),
    "guillotine_side": ((1.75, 1.6, 1.0), (2.3, 2.05, 0.82), 30),
    "kitchen": ((2.4, 2.2, 1.6), (1.8, 0.2, 1.0), 16),
    "service": ((4.6, 3.5, 1.7), (6.3, 3.7, 1.4), 14),
    "bath": ((5.3, 0.4, 1.7), (6.4, 1.8, 0.8), 13),
    "hall": ((9.4, -0.85, 1.65), (0.0, -0.85, 1.0), 16),
    "hall_stairs": ((5.5, -0.7, 1.65), (-1.5, -1.3, 1.3), 16),
    "window": ((2.5, 3.6, 1.6), (2.5, 14.0, 0.5), 18),
    "board": ((3.4, 3.4, 1.55), (4.1, 5.0, 1.55), 20),
}


def _camera(name, ortho=False):
    cam = bpy.data.cameras.new(name)
    ob = bpy.data.objects.new(name, cam)
    bpy.context.scene.collection.objects.link(ob)
    if ortho:
        cam.type = "ORTHO"
        cam.ortho_scale = 12.5
    cam.clip_start = 0.05
    return ob


def _aim(ob, eye, target):
    ob.location = eye
    d = Vector(target) - Vector(eye)
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def render(out_dir, only=None):
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = 1280, 800
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.exposure = 0.6
    ceiling = [bpy.data.objects[n] for n in ("Ceiling", "Ceiling_BathPVC", "KEEP_BathHatch")]
    lamps = [o for o in bpy.data.objects if o.name.startswith(("LAMP_", "MACHINE_ClothesLine"))]
    dummies = _player_dummies()
    os.makedirs(out_dir, exist_ok=True)
    for name, view in VIEWS.items():
        if only and name not in only:
            continue
        top = view is None
        cam = _camera("PREVIEW_" + name, ortho=top)
        if top:
            _aim(cam, (4.2, 1.7, 20.0), (4.2, 1.7, 0.0))
            scene.render.resolution_y = 1000
        else:
            _aim(cam, *view[:2])
            cam.data.lens = view[2]
            scene.render.resolution_y = 800
        for o in ceiling + lamps:
            o.hide_render = top
        for o in dummies:
            if isinstance(o, bpy.types.Object):
                o.hide_render = not top
        scene.camera = cam
        scene.render.filepath = os.path.join(out_dir, name + ".png")
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(cam, do_unlink=True)
    for o in ceiling + lamps:
        o.hide_render = False
    bpy.data.batch_remove(dummies)


def _player_dummies():
    """Uma cápsula do tamanho do jogador (raio 0,33, altura 1,75) em cada SPAWN, só na prévia."""
    colors = [(0.9, 0.2, 0.2, 1), (0.2, 0.5, 0.95, 1), (0.95, 0.8, 0.1, 1), (0.6, 0.25, 0.85, 1)]
    out = []
    for i, sp in enumerate(o for o in bpy.data.objects if o.name.startswith("SPAWN_")):
        mat = bpy.data.materials.new(f"PREVIEW_player_{i}")
        bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = colors[i % 4]
        bpy.ops.mesh.primitive_cylinder_add(radius=0.33, depth=1.75, location=(sp.location.x, sp.location.y, 0.875))
        ob = bpy.context.active_object
        ob.name = f"PREVIEW_player_{i}"
        ob.data.materials.append(mat)
        out += [ob, mat]
    return out


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    render(args[0], only=args[1:] or None)
