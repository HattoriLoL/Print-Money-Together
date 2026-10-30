"""Deixa a kitnet torta, de desenho animado: paredes, móveis e cacarecos levemente fora de prumo.

Um campo de deslocamento suave (soma de senoides) empurra cada vértice na horizontal conforme a
posição dele no mundo. Como o campo é contínuo, peças coladas continuam coladas e o que está em
cima de um móvel vai junto com ele. A altura não muda: piso, tampos e prateleiras ficam no mesmo
nível (os itens do Godot pousam onde pousavam). Duas camadas: uma larga, que inclina paredes e
móveis grandes, e uma curta, que entorta as coisas pequenas (caneca, frascos).

Antes de entortar, as malhas são fatiadas numa grade (GRID) no mundo. Sem isso uma parede, que
só tem vértices nas pontas, entortaria em linha reta entre eles, e o azulejo colado nela, que
segue a curva, ficava atrás. Com todo mundo cortado nos mesmos planos, os vértices de quem se
encosta caem nos mesmos lugares e andam juntos. Entre dois cortes a superfície vira reta; a
curva que sobra ali fica abaixo de 1 mm.

Ficam de fora as peças que o Godot mexe ou mede (máquinas e suprimentos), a cidade lá fora e os
pisos: eles não mudam de altura, as bordas ficam embaixo das paredes, e fatiados em triângulos
miúdos o Godot deixava uma resma parada afundar no cruzamento da grade.
"""

import math
import random

import bmesh
import bpy
import numpy as np
from mathutils import Vector

# (amplitude em metros, comprimento de onda em metros, quantas senoides)
# A curta não pode ser curta demais: entre dois cortes da grade a superfície vira reta, e a curva
# que sobra (menos de 1 mm assim) não pode furar peças coladas, como o vidro de 2 mm do forno.
LAYERS = ((0.03, 2.4, 4), (0.008, 0.8, 5))
SKIP = ("MACHINE_", "SUPPLY_", "Outside_", "PREVIEW_", "Floor_")
SEED = 301
# Distância entre os planos que fatiam as malhas (metros).
GRID = 0.125


def _waves():
    rng = random.Random(SEED)
    out = []
    for amp, wavelength, count in LAYERS:
        for _ in range(count):
            # Direção da onda em 3D (o z entra: subindo a parede, ela vai para o lado).
            theta, phi = rng.uniform(0, 2 * math.pi), rng.uniform(-0.6, 0.6)
            k = np.array((math.cos(theta) * math.cos(phi), math.sin(theta) * math.cos(phi), math.sin(phi)))
            k *= 2 * math.pi / wavelength
            push = rng.uniform(0, 2 * math.pi)
            out.append((k, rng.uniform(0, 2 * math.pi), amp / math.sqrt(count),
                        np.array((math.cos(push), math.sin(push)))))
    return out


def displacement(points):
    """Deslocamento (x, y) de cada ponto (N x 3, no mundo)."""
    d = np.zeros((len(points), 2))
    for k, phase, amp, push in _waves():
        d += amp * np.sin(points @ k + phase)[:, None] * push
    return d


def apply(objects=None):
    """Entorta as malhas (todas da cena, menos SKIP). Chame depois de montar e antes de exportar.

    A luz não muda: cada canto de face guarda a normal de antes (com o Weighted Normal já
    aplicado) como normal própria. Sem isso cada fatia da grade ficava um tico inclinada para um
    lado, e o brilho duro do toon piscava de fatia em fatia, quadriculado."""
    bpy.context.view_layer.update()
    for ob in objects or bpy.data.objects:
        if ob.type != "MESH" or ob.name.startswith(SKIP) or len(ob.data.vertices) == 0:
            continue
        me = ob.data
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.transform(ob.matrix_world)
        _slice(bm)
        bm.transform(ob.matrix_world.inverted())
        bm.to_mesh(me)
        bm.free()
        me.update()
        normals = _corner_normals(ob)
        for mod in [m for m in ob.modifiers if m.type == "WEIGHTED_NORMAL"]:
            ob.modifiers.remove(mod)

        n = len(me.vertices)
        local = np.empty(n * 3)
        me.vertices.foreach_get("co", local)
        local = local.reshape(n, 3)
        mw = np.array(ob.matrix_world)
        world = local @ mw[:3, :3].T + mw[:3, 3]
        world[:, :2] += displacement(world)
        inv = np.linalg.inv(mw)
        me.vertices.foreach_set("co", (world @ inv[:3, :3].T + inv[:3, 3]).ravel())
        me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
        me.normals_split_custom_set(normals)
        me.update()


def _corner_normals(ob):
    """Normal de cada canto de face, do jeito que a malha é exportada (com os modificadores)."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = ob.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    normals = [tuple(c.vector) for c in mesh.corner_normals]
    evaluated.to_mesh_clear()
    return normals


def _slice(bm):
    """Corta a malha (já no mundo) nos planos da grade que passam por ela.

    Faces deitadas (forro, tampos, prateleiras) ficam inteiras: o campo só empurra na
    horizontal, então elas continuam planas, e a borda delas é cortada junto com as faces de pé
    que dividem as mesmas arestas. Cada plano só recebe as faces que ele cruza; as que já ficaram
    para trás saem da lista."""
    bm.normal_update()
    eps = 1e-6
    for axis in range(3):
        normal = Vector((0, 0, 0))
        normal[axis] = 1.0
        work = [f for f in bm.faces if abs(f.normal.z) < 0.999]
        if not work:
            return
        lo = min(v.co[axis] for f in work for v in f.verts)
        hi = max(v.co[axis] for f in work for v in f.verts)
        for i in range(math.floor(lo / GRID) + 1, math.ceil(hi / GRID)):
            c = i * GRID
            ahead, crossing = [], []
            for f in work:
                coords = [v.co[axis] for v in f.verts]
                if max(coords) <= c + eps:
                    continue
                if min(coords) < c - eps:
                    crossing.append(f)
                else:
                    ahead.append(f)
            work = ahead
            if not crossing:
                continue
            edges = list({e for f in crossing for e in f.edges})
            verts = list({v for f in crossing for v in f.verts})
            co = Vector((0, 0, 0))
            co[axis] = c
            res = bmesh.ops.bisect_plane(bm, geom=verts + edges + crossing, plane_co=co, plane_no=normal)
            work += [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]
