"""Peças básicas do gerador: materiais, malhas montadas de caixas e cilindros, e a textura da cédula."""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

import textures

# nome: (cor, rugosidade, metálico, emissão)
MATERIALS = {
    "M_Wall": ((0.86, 0.82, 0.72), 0.9, 0.0, 0.0),
    "M_WallHall": ((0.66, 0.74, 0.64), 0.9, 0.0, 0.0),
    "M_WallHallLow": ((0.32, 0.45, 0.36), 0.6, 0.0, 0.0),
    "M_Ceiling": ((0.9, 0.9, 0.88), 0.95, 0.0, 0.0),
    "M_Floor": ((0.72, 0.6, 0.47), 0.35, 0.0, 0.0),
    "M_FloorBath": ((0.55, 0.6, 0.62), 0.3, 0.0, 0.0),
    "M_FloorHall": ((0.42, 0.42, 0.4), 0.45, 0.0, 0.0),
    "M_Baseboard": ((0.38, 0.3, 0.22), 0.6, 0.0, 0.0),
    "M_Tile": ((0.8, 0.88, 0.9), 0.15, 0.0, 0.0),
    "M_TileKitchen": ((0.72, 0.84, 0.76), 0.15, 0.0, 0.0),
    "M_PVC": ((0.93, 0.93, 0.9), 0.4, 0.0, 0.0),
    "M_Wood": ((0.36, 0.23, 0.13), 0.7, 0.0, 0.0),
    "M_WoodLight": ((0.68, 0.52, 0.34), 0.65, 0.0, 0.0),
    "M_DoorWood": ((0.52, 0.35, 0.2), 0.6, 0.0, 0.0),
    "M_DoorMetal": ((0.55, 0.12, 0.1), 0.5, 0.3, 0.0),
    "M_Metal": ((0.72, 0.72, 0.74), 0.3, 0.9, 0.0),
    "M_MetalDark": ((0.16, 0.16, 0.18), 0.45, 0.6, 0.0),
    "M_Granite": ((0.13, 0.13, 0.14), 0.25, 0.0, 0.0),
    "M_PlasticWhite": ((0.88, 0.88, 0.85), 0.35, 0.0, 0.0),
    "M_PlasticBeige": ((0.76, 0.72, 0.6), 0.45, 0.0, 0.0),
    "M_PlasticBlack": ((0.05, 0.05, 0.06), 0.4, 0.0, 0.0),
    "M_PlasticBlue": ((0.15, 0.3, 0.6), 0.4, 0.0, 0.0),
    "M_Rubber": ((0.03, 0.03, 0.03), 0.9, 0.0, 0.0),
    "M_Fabric": ((0.62, 0.38, 0.14), 1.0, 0.0, 0.0),
    "M_Blanket": ((0.25, 0.32, 0.55), 1.0, 0.0, 0.0),
    "M_Pillow": ((0.85, 0.82, 0.75), 1.0, 0.0, 0.0),
    "M_Curtain": ((0.55, 0.18, 0.16), 1.0, 0.0, 0.0),
    "M_ShowerCurtain": ((0.7, 0.85, 0.8), 0.5, 0.0, 0.0),
    "M_Rug": ((0.3, 0.42, 0.35), 1.0, 0.0, 0.0),
    "M_Doormat": ((0.32, 0.22, 0.15), 1.0, 0.0, 0.0),
    "M_Porcelain": ((0.95, 0.95, 0.94), 0.12, 0.0, 0.0),
    "M_Concrete": ((0.6, 0.6, 0.58), 0.9, 0.0, 0.0),
    # Sem reflexo de verdade ainda: um metal 100% sem nada para refletir fica preto.
    "M_Mirror": ((0.62, 0.68, 0.72), 0.08, 0.35, 0.0),
    "M_Glass": ((0.7, 0.85, 0.9), 0.05, 0.0, 0.0),
    "M_Void": ((0.01, 0.01, 0.01), 1.0, 0.0, 0.0),
    "M_Paper": ((0.96, 0.96, 0.93), 0.8, 0.0, 0.0),
    "M_Cardboard": ((0.6, 0.45, 0.28), 0.9, 0.0, 0.0),
    "M_PizzaBox": ((0.82, 0.74, 0.6), 0.9, 0.0, 0.0),
    "M_Money": ((0.5, 0.66, 0.42), 0.7, 0.0, 0.0),
    "M_MoneyBand": ((0.9, 0.75, 0.2), 0.6, 0.0, 0.0),
    "M_InkGreen": ((0.08, 0.55, 0.2), 0.2, 0.0, 0.0),
    "M_InkBlack": ((0.02, 0.03, 0.02), 0.2, 0.0, 0.0),
    "M_InkGold": ((0.85, 0.65, 0.15), 0.3, 0.6, 0.0),
    "M_Red": ((0.75, 0.08, 0.06), 0.4, 0.0, 0.0),
    "M_Green": ((0.1, 0.6, 0.15), 0.4, 0.0, 0.0),
    "M_Yellow": ((0.95, 0.75, 0.05), 0.5, 0.0, 0.0),
    "M_Plant": ((0.18, 0.4, 0.15), 0.8, 0.0, 0.0),
    "M_Terracotta": ((0.6, 0.3, 0.18), 0.9, 0.0, 0.0),
    "M_Rope": ((0.85, 0.85, 0.8), 0.9, 0.0, 0.0),
    # Brilhos: a tela das máquinas e a tinta fervendo na panela.
    "M_Screen": ((0.35, 0.9, 0.5), 0.3, 0.0, 1.0),
    "M_InkHot": ((0.15, 0.9, 0.3), 0.2, 0.0, 1.5),
    "M_LedRed": ((1.0, 0.1, 0.05), 0.3, 0.0, 4.0),
    "M_TVScreen": ((0.35, 0.5, 0.7), 0.15, 0.0, 1.2),
    "M_LaptopScreen": ((0.55, 0.75, 1.0), 0.2, 0.0, 1.5),
    # Impressora velha, escrivaninha e PC (texturas geradas em textures.py).
    "M_OldPlastic": ((0.8, 0.76, 0.66), 0.55, 0.0, 0.0),
    "M_OldPlasticDark": ((0.3, 0.3, 0.31), 0.55, 0.0, 0.0),
    "M_DeskMetal": ((0.42, 0.46, 0.43), 0.45, 0.4, 0.0),
    "M_DeskWood": ((0.6, 0.45, 0.3), 0.5, 0.0, 0.0),
    "M_StickerWarning": ((0.95, 0.78, 0.1), 0.4, 0.0, 0.0),
    "M_StickerLabel": ((0.93, 0.92, 0.88), 0.6, 0.0, 0.0),
    "M_Coffee": ((0.12, 0.06, 0.03), 0.1, 0.0, 0.0),
    "M_Cable": ((0.55, 0.55, 0.53), 0.6, 0.0, 0.0),
    # LEDs da impressora: o Godot acende e apaga.
    "M_LedGreen": ((0.25, 1.0, 0.35), 0.3, 0.0, 4.0),
    "M_LedAmber": ((1.0, 0.6, 0.1), 0.3, 0.0, 4.0),
    # Detalhes.
    "M_GlassFrosted": ((0.85, 0.9, 0.92), 0.6, 0.0, 0.0),
    "M_Gas": ((0.18, 0.33, 0.62), 0.45, 0.3, 0.0),
    "M_ClothRed": ((0.6, 0.12, 0.12), 1.0, 0.0, 0.0),
    "M_ClothGray": ((0.45, 0.45, 0.47), 1.0, 0.0, 0.0),
    "M_ClothWhite": ((0.85, 0.85, 0.82), 1.0, 0.0, 0.0),
    "M_Cork": ((0.62, 0.45, 0.28), 0.95, 0.0, 0.0),
    "M_BathMat": ((0.35, 0.55, 0.6), 1.0, 0.0, 0.0),
    "M_Can": ((0.15, 0.7, 0.3), 0.3, 0.8, 0.0),
    "M_CanBlue": ((0.1, 0.25, 0.7), 0.3, 0.8, 0.0),
    "M_TrashBag": ((0.03, 0.03, 0.035), 0.3, 0.0, 0.0),
    "M_Asphalt": ((0.06, 0.06, 0.065), 0.9, 0.0, 0.0),
    "M_Facade": ((0.55, 0.52, 0.48), 0.9, 0.0, 0.0),
    "M_FacadeFar": ((0.18, 0.19, 0.24), 0.9, 0.0, 0.0),
    # Manchas (texturas com transparência, ver textures.py).
    "M_DecalMold": ((1.0, 1.0, 1.0), 0.9, 0.0, 0.0),
    "M_DecalWater": ((1.0, 1.0, 1.0), 0.9, 0.0, 0.0),
    "M_DecalGrime": ((1.0, 1.0, 1.0), 0.9, 0.0, 0.0),
    # Lá fora: janelas dos prédios em volta e postes.
    "M_WinLit": ((1.0, 0.7, 0.4), 0.3, 0.0, 0.8),
    "M_WinCool": ((0.7, 0.8, 1.0), 0.3, 0.0, 0.6),
    "M_WinTV": ((0.3, 0.45, 1.0), 0.3, 0.0, 0.7),
    "M_WinCurtain": ((0.95, 0.4, 0.2), 0.3, 0.0, 0.6),
    "M_WinDark": ((0.05, 0.06, 0.08), 0.1, 0.0, 0.0),
    "M_StreetLamp": ((1.0, 0.7, 0.35), 0.3, 0.0, 8.0),
    # Luminárias acesas (M_Lamp_<zona>): o Godot liga e desliga por zona.
    "M_Lamp_main": ((1.0, 0.85, 0.6), 0.3, 0.0, 6.0),
    "M_Lamp_kitchen": ((0.9, 0.95, 1.0), 0.3, 0.0, 1.5),
    "M_Lamp_bath": ((1.0, 0.95, 0.85), 0.3, 0.0, 5.0),
    "M_Lamp_service": ((1.0, 0.9, 0.7), 0.3, 0.0, 5.0),
    "M_Lamp_hall": ((0.9, 1.0, 0.9), 0.3, 0.0, 5.0),
}

ALPHA = {"M_Glass": 0.1, "M_GlassFrosted": 0.7}
# Materiais com uma imagem de assets/textures/ (desenhadas pelo art_source/paper_textures.py),
# aplicada em quads com UV de 0 a 1: nome -> (arquivo, rugosidade).
TEXTURED = {
    "M_MoneySheet": ("sheet_front.png", 0.75),
    "M_CuttingMat": ("cutting_mat.png", 0.6),
}
# Folhas feitas com frente e verso separados (Part.quad/sheet): sem isso as duas faces brigam.
ONE_SIDED = {"M_MoneySheet", "M_Curtain", "M_ShowerCurtain"}


def _bsdf(mat):
    return next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def material(name):
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name)
    if not mat.use_nodes:
        mat.use_nodes = True
    bsdf = _bsdf(mat)
    mat.use_backface_culling = name in ONE_SIDED
    if name in TEXTURED:
        _setup_image(mat, bsdf, *TEXTURED[name])
        return mat
    color, rough, metal, emit = MATERIALS[name]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    mat.diffuse_color = (*color, 1.0)
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit
    blended = name in ALPHA
    if blended:
        bsdf.inputs["Alpha"].default_value = ALPHA[name]
        mat.diffuse_color = (*color, ALPHA[name])
    if textures.has_texture(name):
        blended = textures.wire(mat, bsdf, name) or blended
    if blended:
        try:
            mat.surface_render_method = "BLENDED"
        except (AttributeError, TypeError):
            mat.blend_method = "BLEND"
    return mat


# --- Imagens do projeto ---------------------------------------------------------------------------

TEXTURE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                           "assets", "textures")


def _setup_image(mat, bsdf, filename, roughness):
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(TEXTURE_DIR, filename), check_existing=True)
    tex.interpolation = "Linear"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    mat.diffuse_color = (0.8, 0.82, 0.78, 1.0)


# --- Malhas ---------------------------------------------------------------------------------------

# Quinas mais fechadas que isso ficam vivas no sombreamento; as do bevel (45° ou menos), suaves.
SHARP_ANGLE = math.radians(50)


class Part:
    """Uma malha montada de caixas, cilindros e quadriláteros, cada um com seu material.

    `bevel` é o arredondamento padrão das quinas das caixas (em metros; 0 = quina viva). Cada
    caixa pode pedir o seu. O finish suaviza tudo por ângulo e põe normais ponderadas pela
    área (modificador Weighted Normal, aplicado no export): faces grandes ficam retas e só o
    bevel faz a transição, como numa peça de verdade."""

    def __init__(self, bevel=0.0):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.verify()
        # Faces com UV próprio (quad): o finish não reprojeta.
        self.fixed = self.bm.faces.layers.int.new("fixed_uv")
        self.mats = []
        self.bevel = bevel
        self._beveled = False

    def _index(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _tag(self, verts, mat, smooth=False):
        mi = self._index(mat)
        for f in {f for v in verts for f in v.link_faces}:
            f.material_index = mi
            f.smooth = smooth

    def box(self, x0, y0, z0, x1, y1, z1, mat, bevel=None):
        """Caixa alinhada aos eixos, de canto a canto."""
        size = Vector((abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)))
        center = Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
        self.box_m(size, Matrix.Translation(center), mat, bevel)

    def box_m(self, size, matrix, mat, bevel=None):
        """Caixa de tamanho `size` centrada na origem e levada por `matrix`."""
        m = matrix @ Matrix.Diagonal((*size, 1.0))
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        self._tag(res["verts"], mat)
        b = self.bevel if bevel is None else bevel
        b = min(b, min(size) * 0.45)
        if b > 0.0008:
            edges = list({e for v in res["verts"] for e in v.link_edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=b, segments=3 if b >= 0.02 else 2,
                            profile=0.5, affect="EDGES", clamp_overlap=True, material=self._index(mat))
            self._beveled = True

    def rounded(self, x0, y0, z0, x1, y1, z1, mat, radius):
        """Caixa bem arredondada (almofada, vaso sanitário, CRT)."""
        self.box(x0, y0, z0, x1, y1, z1, mat, bevel=radius)

    def cyl(self, center, length, radius, mat, axis="Z", seg=16, radius2=None, matrix=None):
        rot = {
            "Z": Matrix.Identity(4),
            "X": Matrix.Rotation(math.pi / 2, 4, "Y"),
            "Y": Matrix.Rotation(math.pi / 2, 4, "X"),
        }[axis]
        m = Matrix.Translation(center) @ rot
        if matrix is not None:
            m = matrix @ m
        res = bmesh.ops.create_cone(
            self.bm, cap_ends=True, cap_tris=False, segments=seg,
            radius1=radius, radius2=radius if radius2 is None else radius2, depth=length, matrix=m)
        self._tag(res["verts"], mat, smooth=True)

    def quad(self, corners, mat, uvs=((0, 0), (1, 0), (1, 1), (0, 1)), double=True):
        """Quadrilátero (folha, cortina, cédula) com UV próprio; `double` faz as duas faces."""
        verts = [self.bm.verts.new(c) for c in corners]
        faces = [self.bm.faces.new(verts)]
        if double:
            # O verso usa o U espelhado: a nota fica legível dos dois lados.
            faces.append(self.bm.faces.new([self.bm.verts.new(c) for c in reversed(corners)]))
            u_max = max(u for u, _ in uvs)
            uv_sets = (uvs, tuple((u_max - u, v) for u, v in reversed(uvs)))
        else:
            uv_sets = (uvs,)
        if mat not in self.mats:
            self.mats.append(mat)
        for f, uvset in zip(faces, uv_sets):
            f.material_index = self.mats.index(mat)
            f[self.fixed] = 1
            for loop, uv in zip(f.loops, uvset):
                loop[self.uv].uv = uv

    def sheet(self, x0, x1, y0, y1, z0, z1, mat, waves=0, amp=0.0, axis="x", seg=12):
        """Pano vertical ondulado (cortina): corre ao longo de `axis`, ondula na outra direção."""
        if mat not in self.mats:
            self.mats.append(mat)
        mi = self.mats.index(mat)
        a0, a1 = (x0, x1) if axis == "x" else (y0, y1)
        b = (y0 + y1) / 2 if axis == "x" else (x0 + x1) / 2
        # As duas faces têm vértices próprios (o bmesh não aceita duas faces nos mesmos vértices).
        for back in (False, True):
            rows = []
            for i in range(seg + 1):
                t = i / seg
                a = a0 + (a1 - a0) * t
                off = amp * math.sin(t * waves * 2 * math.pi)
                col = []
                for z in (z0, z1):
                    co = (a, b + off, z) if axis == "x" else (b + off, a, z)
                    col.append(self.bm.verts.new(co))
                rows.append(col)
            for i in range(seg):
                quad = [rows[i][0], rows[i + 1][0], rows[i + 1][1], rows[i][1]]
                f = self.bm.faces.new(list(reversed(quad)) if back else quad)
                f.material_index = mi
                f.smooth = True

    def _project_uvs(self):
        """UV em metros (divididos pelo tamanho da textura do material) no plano de cada face:
        a textura repete no tamanho real em qualquer caixa, sem depender de projeção no Godot."""
        tiles = [textures.tile(m) for m in self.mats]
        for face in self.bm.faces:
            if face[self.fixed]:
                continue
            t = tiles[face.material_index] if face.material_index < len(tiles) else 1.0
            n = face.normal
            axis = max(range(3), key=lambda i: abs(n[i]))
            for loop in face.loops:
                p = loop.vert.co
                if axis == 0:
                    u, v = p.y * (1 if n.x > 0 else -1), p.z
                elif axis == 1:
                    u, v = p.x * (-1 if n.y > 0 else 1), p.z
                else:
                    u, v = p.x, p.y * (1 if n.z > 0 else -1)
                loop[self.uv].uv = (u / t, v / t)

    def _smooth_by_angle(self):
        for f in self.bm.faces:
            f.smooth = True
        for e in self.bm.edges:
            if not e.is_manifold or e.calc_face_angle(math.pi) > SHARP_ANGLE:
                e.smooth = False

    def finish(self, name, coll, loc=(0, 0, 0), rot_z=0.0, parent=None):
        me = bpy.data.meshes.new(name)
        self.bm.normal_update()
        self._project_uvs()
        self._smooth_by_angle()
        self.bm.faces.layers.int.remove(self.fixed)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(material(m))
        ob = bpy.data.objects.new(name, me)
        ob.location = loc
        ob.rotation_euler.z = rot_z
        if name.startswith("LAMP_"):
            # A luz fica dentro da lâmpada: sem isso o bulbo faz sombra no cômodo todo.
            ob.visible_shadow = False
        if self._beveled:
            mod = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
            mod.mode = "FACE_AREA"
            mod.keep_sharp = True
        coll.objects.link(ob)
        if parent is not None:
            ob.parent = parent
        return ob


def facing(direction):
    """Rotação em Z que vira a frente local (-Y) para `direction`: '-y', '+y', '-x' ou '+x'."""
    return {"-y": 0.0, "+y": math.pi, "-x": -math.pi / 2, "+x": math.pi / 2}[direction]


def wall(p, axis, t0, t1, a0, a1, mat, h, openings=()):
    """Parede ao longo de `axis` ('x' ou 'y') de a0 a a1, com espessura de t0 a t1 no outro eixo.
    `openings` = [(início, fim, base, topo)]: portas (base 0) e janelas."""

    def put(s0, s1, z0, z1):
        if s1 - s0 < 1e-4 or z1 - z0 < 1e-4:
            return
        if axis == "x":
            p.box(s0, t0, z0, s1, t1, z1, mat)
        else:
            p.box(t0, s0, z0, t1, s1, z1, mat)

    cur = a0
    for o0, o1, bot, top in sorted(openings):
        put(cur, o0, 0, h)
        put(o0, o1, 0, bot)
        put(o0, o1, top, h)
        cur = o1
    put(cur, a1, 0, h)


# Display de 7 segmentos: célula de 0,6 x 1 (x, z), traço de 0,12.
_SEG_RECTS = {
    "a": (0.0, 0.88, 0.6, 1.0), "b": (0.48, 0.5, 0.6, 1.0), "c": (0.48, 0.0, 0.6, 0.5),
    "d": (0.0, 0.0, 0.6, 0.12), "e": (0.0, 0.0, 0.12, 0.5), "f": (0.0, 0.5, 0.12, 1.0),
    "g": (0.0, 0.44, 0.6, 0.56),
}
_DIGITS = {
    "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
    "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
}


def digits(p, text, cx, z0, height, y_face, mat, depth=0.004, facing="-y"):
    """Escreve números de 7 segmentos no plano x-z, saltando `depth` a partir de `y_face` para o
    lado de `facing` ('-y', a frente local das peças, ou '+y'), centrados em `cx` e com a base
    em `z0`. Virado para +Y o texto corre para -X, para quem olha ler direito."""
    s = height
    width = len(text) * 0.8 * s - 0.2 * s
    sign = 1 if facing == "-y" else -1
    y0, y1 = (y_face - depth, y_face) if facing == "-y" else (y_face, y_face + depth)
    x = -width / 2
    for ch in text:
        for seg in _DIGITS.get(ch, ""):
            a0, b0, a1, b1 = _SEG_RECTS[seg]
            xa, xb = cx + sign * (x + a0 * s), cx + sign * (x + a1 * s)
            p.box(min(xa, xb), y0, z0 + b0 * s, max(xa, xb), y1, z0 + b1 * s, mat)
        x += 0.8 * s


# Normal da face -> (tangente, bitangente) com tangente x bitangente = normal.
_DECAL_AXES = {
    "+x": ((0, 1, 0), (0, 0, 1)), "-x": ((0, -1, 0), (0, 0, 1)),
    "+y": ((-1, 0, 0), (0, 0, 1)), "-y": ((1, 0, 0), (0, 0, 1)),
    "+z": ((1, 0, 0), (0, 1, 0)), "-z": ((0, 1, 0), (1, 0, 0)),
}


def decal(p, center, normal, w, h, mat, rot=0.0):
    """Mancha plana virada para `normal` ('+x', '-z'...), de w x h, girada `rot` no plano."""
    t, b = (Vector(a) for a in _DECAL_AXES[normal])
    t, b = t * math.cos(rot) + b * math.sin(rot), b * math.cos(rot) - t * math.sin(rot)
    c = Vector(center)
    corners = [c - t * w / 2 - b * h / 2, c + t * w / 2 - b * h / 2, c + t * w / 2 + b * h / 2, c - t * w / 2 + b * h / 2]
    p.quad([tuple(v) for v in corners], mat, double=False)


def empty(name, coll, loc, size=0.3, kind="PLAIN_AXES", rot_z=0.0):
    ob = bpy.data.objects.new(name, None)
    ob.empty_display_type = kind
    ob.empty_display_size = size
    ob.location = loc
    ob.rotation_euler.z = rot_z
    coll.objects.link(ob)
    return ob


def point_light(name, coll, loc, watts, color=(1.0, 0.85, 0.65), radius=0.05):
    light = bpy.data.lights.new(name, "POINT")
    light.energy = watts
    light.color = color
    light.shadow_soft_size = radius
    ob = bpy.data.objects.new(name, light)
    ob.location = loc
    coll.objects.link(ob)
    return ob
