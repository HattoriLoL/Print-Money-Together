"""Monta a kitnet do zero no kitnet.blend aberto e exporta para assets/models/kitnet.glb.

No Blender (ou pelo MCP):
    import sys; sys.path.insert(0, r"<projeto>/art_source/blender")
    import build; build.run()           # monta
    build.run(export=True)              # monta e exporta

Sem abrir a interface:
    blender --background art_source/kitnet.blend --python art_source/blender/build.py -- --export
"""

import importlib
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
ROOT = os.path.dirname(os.path.dirname(HERE))
GLB = os.path.join(ROOT, "assets", "models", "kitnet.glb")

COLLECTIONS = {
    "structure": "Kitnet_Structure",
    "furniture": "Kitnet_Furniture",
    "machines": "Kitnet_Machines",
    "props": "Kitnet_Props",
    "outside": "Kitnet_Outside",
    "lights": "Kitnet_Lights",
    "markers": "Kitnet_Markers",
}


def _reload():
    import textures, lib, plan, structure, furniture, machines, props, exterior
    for m in (plan, textures, lib, structure, furniture, machines, props, exterior):
        importlib.reload(m)
    return textures, (structure, furniture, machines, props, exterior)


def clear():
    if not bpy.data.filepath.endswith("kitnet.blend"):
        raise RuntimeError("Abra o art_source/kitnet.blend antes de montar (o build apaga a cena).")
    # Tudo de uma vez: apagar item por item com a interface aberta derrubou o Blender.
    bpy.data.batch_remove(list(bpy.data.objects) + list(bpy.data.collections))
    bpy.data.batch_remove(list(bpy.data.meshes) + list(bpy.data.materials)
                          + list(bpy.data.lights) + list(bpy.data.images))
    bpy.context.view_layer.update()


def collections():
    scene_coll = bpy.context.scene.collection
    out = {}
    for key, name in COLLECTIONS.items():
        coll = bpy.data.collections.new(name)
        scene_coll.children.link(coll)
        out[key] = coll
    return out


def world():
    w = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = w
    if not w.use_nodes:
        w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.02, 0.025, 0.05, 1.0)  # noite lá fora
    bg.inputs["Strength"].default_value = 1.0


def run(export=False):
    textures, parts = _reload()
    clear()
    textures.prepare()
    colls = collections()
    for module in parts:
        module.build(colls)
    world()
    save_bill_texture()
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.ops.wm.save_mainfile()
    if export:
        export_glb()
    print(f"kitnet: {len(bpy.data.objects)} objetos")


def save_bill_texture():
    """A nota desenhada pelo lib.py também vai para assets/textures/bill.png: as folhas que a
    impressora solta no jogo são objetos do Godot e usam essa imagem."""
    import lib
    src = lib.money_image()
    out = bpy.data.images.new("bill_export", *src.size)
    out.pixels.foreach_set(src.pixels[:])
    out.filepath_raw = os.path.join(ROOT, "assets", "textures", "bill.png")
    out.file_format = "PNG"
    os.makedirs(os.path.dirname(out.filepath_raw), exist_ok=True)
    out.save()
    bpy.data.images.remove(out)


def export_glb(path=GLB):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_visible=False,
        export_apply=True,
        export_lights=True,
        export_cameras=False,
        export_extras=True,
        export_yup=True,
    )
    print("exportado:", path)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    run(export="--export" in args)
