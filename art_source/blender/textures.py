"""Texturas dos materiais.

- Fotos CC0 do Poly Haven (PHOTOS): baixadas uma vez para art_source/textures/<asset>/ (cor,
  normal e rugosidade, com um SOURCE de crédito). As de RELIGHT viram cinza com brilho médio
  fixo, e a cor do material (lib.MATERIALS) tinge a foto: a mesma foto de reboco serve à parede
  creme da kitnet e à verde do corredor.
- Padrões gerados aqui (GENERATED): piso cerâmico, azulejos, granito, tecido, tapete e as
  manchas de mofo e infiltração. Ficam embutidos no .blend (nada em disco).

`tile(material)` diz quantos metros a textura cobre: o lib.Part usa nas UVs das caixas.
"""

import json
import os
import urllib.request

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
TEXTURES = os.path.join(os.path.dirname(HERE), "textures")

_API = "https://api.polyhaven.com"
_HEADERS = {"User-Agent": "print-money-together-art/1.0"}
# Mapa na API (minúsculas) -> arquivo. A normal é a do OpenGL (convenção do glTF e do Godot).
_MAPS = {"diffuse": "color", "nor_gl": "normal", "rough": "roughness"}

# material -> asset do Poly Haven.
PHOTOS = {
    "M_DeskWood": "fine_grained_wood",
    "M_Wall": "painted_plaster_wall",
    "M_Ceiling": "ceiling_interior",
    "M_FloorHall": "terrazzo_tiles",
    "M_WoodLight": "oak_veneer_01",
    "M_Wood": "dark_wood",
    "M_DoorWood": "wood_cabinet_worn_long",
    "M_Blanket": "denim_fabric",
    "M_Concrete": "concrete_floor_02",
}
# Materiais que usam a foto de outro (com a própria cor por cima).
SHARED = {"M_WallHall": "M_Wall", "M_WallHallLow": "M_Wall", "M_Facade": "M_Concrete",
          "M_FacadeFar": "M_Concrete"}
# Fotos refeitas em cinza: material -> (brilho médio, contraste). A cor do material tinge.
# As madeiras e o jeans também: assim a paleta do lib.MATERIALS manda na cor de tudo.
RELIGHT = {"M_Wall": (0.9, 1.4), "M_Ceiling": (0.9, 0.5), "M_Concrete": (0.85, 1.0),
           "M_FloorHall": (0.7, 1.3), "M_DeskWood": (0.75, 1.0), "M_WoodLight": (0.75, 1.0),
           "M_Wood": (0.6, 1.0), "M_DoorWood": (0.7, 1.0), "M_Blanket": (0.7, 1.0)}
# Força do relevo (normal map) quando não é 1: o grafiato do forro é forte demais na foto.
NORMAL_STRENGTH = {"M_Ceiling": 0.3}

_tiles = {}
_rng = np.random.default_rng(11)


def tile(name):
    return _tiles.get(name, 1.0)


def has_texture(name):
    return name in PHOTOS or name in SHARED or name in GENERATED


def prepare():
    """Baixa o que falta e calcula o tamanho de cada textura. Chame antes de montar."""
    _tiles.clear()
    for name, asset in PHOTOS.items():
        _tiles[name] = _fetch(asset)
    for name, other in SHARED.items():
        _tiles[name] = _tiles[other]
    for name, (_, size) in GENERATED.items():
        _tiles[name] = size


def wire(mat, bsdf, name):
    """Liga as imagens do material `name` no Principled. A cor base atual vira o tingimento."""
    source = SHARED.get(name, name)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    tint = tuple(bsdf.inputs["Base Color"].default_value)[:3]
    if source in GENERATED:
        maps = _generated_maps(source)
    else:
        maps = _photo_maps(source)
    color = nodes.new("ShaderNodeTexImage")
    color.image = maps["color"]
    color_out = color.outputs["Color"]
    if source in RELIGHT or name != source:
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        brightness = RELIGHT.get(source, (1.0, 1.0))[0]
        mix.inputs["B"].default_value = (*[min(c / brightness, 1.0) for c in tint], 1.0)
        links.new(color_out, mix.inputs["A"])
        color_out = mix.outputs["Result"]
    links.new(color_out, bsdf.inputs["Base Color"])
    if "alpha" in maps:
        links.new(color.outputs["Alpha"], bsdf.inputs["Alpha"])
    if "roughness" in maps:
        rough = nodes.new("ShaderNodeTexImage")
        rough.image = maps["roughness"]
        rough.image.colorspace_settings.name = "Non-Color"
        links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])
    if "normal" in maps:
        normal = nodes.new("ShaderNodeTexImage")
        normal.image = maps["normal"]
        normal.image.colorspace_settings.name = "Non-Color"
        nmap = nodes.new("ShaderNodeNormalMap")
        nmap.inputs["Strength"].default_value = NORMAL_STRENGTH.get(source, 1.0)
        links.new(normal.outputs["Color"], nmap.inputs["Color"])
        links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return "alpha" in maps


# --- Poly Haven -------------------------------------------------------------------------------

def _fetch(asset, resolution="1k"):
    """Baixa o asset se ainda não está na pasta e devolve quantos metros ele cobre."""
    folder = os.path.join(TEXTURES, asset)
    source = os.path.join(folder, "SOURCE")
    if not os.path.exists(source):
        os.makedirs(folder, exist_ok=True)
        files = {k.lower(): v for k, v in _get_json(f"{_API}/files/{asset}").items()}
        for api_name, stem in _MAPS.items():
            url = files[api_name][resolution]["jpg"]["url"]
            with urllib.request.urlopen(urllib.request.Request(url, headers=_HEADERS), timeout=60) as r:
                with open(os.path.join(folder, stem + ".jpg"), "wb") as out:
                    out.write(r.read())
        info = _get_json(f"{_API}/info/{asset}")
        size = info.get("dimensions", [2000])[0] / 1000.0
        with open(source, "w", encoding="utf-8") as out:
            out.write(f"{info.get('name', asset)} - https://polyhaven.com/a/{asset}\n"
                      f"Autores: {', '.join(info.get('authors', {}))}\n"
                      f"Licença: CC0 (Poly Haven)\n"
                      f"Tamanho real: {size} m\n")
        print("baixada:", asset)
    with open(source, encoding="utf-8") as f:
        for line in f:
            if line.startswith("Tamanho real:"):
                return float(line.split(":")[1].split()[0])
    return 2.0


def _get_json(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=_HEADERS), timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def _photo_maps(name):
    folder = os.path.join(TEXTURES, PHOTOS[name])
    maps = {}
    for stem in ("color", "normal", "roughness"):
        maps[stem] = bpy.data.images.load(os.path.join(folder, stem + ".jpg"), check_existing=True)
    if name in RELIGHT:
        maps["color"] = _relit(name, maps["color"], *RELIGHT[name])
    return maps


def _relit(name, src, brightness, contrast):
    key = f"TX_{name}_color"
    img = bpy.data.images.get(key)
    if img is not None:
        return img
    w, h = src.size
    px = np.empty(w * h * 4, dtype=np.float32)
    src.pixels.foreach_get(px)
    rgb = px.reshape(h, w, 4)[..., :3]
    luma = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    gray = np.clip(brightness + (luma - luma.mean()) * contrast, 0, 1)
    return _image(key, np.repeat(gray[..., None], 3, axis=2))


# --- Gerados --------------------------------------------------------------------------------------
# As matrizes são (linha, coluna) com a linha 0 embaixo, como o Blender guarda as imagens.

def _noise(size, scale, octaves=4):
    """Ruído suave e repetível (soma de senoides inteiras), de -scale a scale."""
    y, x = np.mgrid[0:size, 0:size] / size * 2 * np.pi
    total = np.zeros((size, size))
    for octave in range(1, octaves + 1):
        f = octave * 2
        for _ in range(3):
            kx, ky = _rng.integers(-f, f + 1, 2)
            total += np.sin(kx * x + ky * y + _rng.uniform(0, 2 * np.pi)) / octave
    return total / np.abs(total).max() * scale


def _speckle(size, amount, strength):
    return (_rng.random((size, size)) < amount) * _rng.uniform(-strength, strength, (size, size))


def _tiles_pattern(size, count, base, jitter, grout_px, grout_color, marble=0.0):
    """Ladrilhos quadrados: cor por peça, veio de mármore opcional e rejunte. Devolve cor e altura."""
    cell = size // count
    y, x = np.mgrid[0:size, 0:size]
    rgb = np.zeros((size, size, 3)) + np.array(base)
    for i in range(count):
        for j in range(count):
            rgb[i * cell:(i + 1) * cell, j * cell:(j + 1) * cell] *= _rng.uniform(1 - jitter, 1 + jitter)
    if marble:
        veins = np.abs(np.sin((x + y) / size * 6 * np.pi + _noise(size, 6.0)))
        rgb *= (1 - marble * (veins < 0.12))[..., None]
        rgb *= (1 + _noise(size, marble * 0.5))[..., None]
    gx, gy = x % cell, y % cell
    grout = (gx < grout_px) | (gy < grout_px)
    rgb[grout] = grout_color
    height = np.where(grout, 0.0, 1.0)
    # Borda levemente arredondada das peças.
    edge = (gx < grout_px + 2) | (gy < grout_px + 2) | (gx >= cell - 2) | (gy >= cell - 2)
    height[edge & ~grout] = 0.6
    return rgb, height


def _normal_from_height(height, strength):
    dx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    dy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    n = np.stack([-dx * strength, -dy * strength, np.ones_like(height)], axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def _gen_floor():
    # Piso cerâmico cor de telha de 45 cm, com veio de "mármore" bem leve (a textura cobre 2 x 2 peças).
    rgb, height = _tiles_pattern(512, 2, (0.76, 0.45, 0.28), 0.05, 3, (0.45, 0.3, 0.2), marble=0.035)
    rgb += _speckle(512, 0.15, 0.03)[..., None]
    return rgb, height, 0.32 + 0.4 * (1 - height)


def _gen_floor_bath():
    rgb, height = _tiles_pattern(512, 2, (0.42, 0.62, 0.66), 0.04, 3, (0.3, 0.4, 0.42))
    return rgb + _speckle(512, 0.3, 0.025)[..., None], height, 0.3 + 0.4 * (1 - height)


def _gen_wall_tile():
    # Azulejo azul de piscina clarinho 20 x 20 (2 x 2 peças), rejunte encardido.
    rgb, height = _tiles_pattern(512, 2, (0.66, 0.86, 0.88), 0.02, 4, (0.55, 0.58, 0.5))
    return rgb + _noise(512, 0.015)[..., None], height, 0.12 + 0.6 * (1 - height)


def _gen_kitchen_tile():
    # Pastilha azul de piscina 10 x 10 (4 x 4 peças).
    rgb, height = _tiles_pattern(512, 4, (0.48, 0.76, 0.78), 0.06, 4, (0.85, 0.85, 0.8))
    return rgb, height, 0.12 + 0.6 * (1 - height)


def _gen_granite():
    # Granito preto São Gabriel: fundo quase preto com grãos cinza e brancos.
    base = np.full((512, 512, 3), 0.06) + _noise(512, 0.015)[..., None]
    grains = _rng.random((512, 512))
    base[grains < 0.08] += 0.12
    base[grains < 0.015] += 0.35
    return base, None, np.full((512, 512), 0.18)


def _gen_fabric():
    # Trama de sofá: fios cruzados em laranja queimado.
    y, x = np.mgrid[0:256, 0:256]
    weave = (np.sin(x * np.pi / 2) * np.sin(y * np.pi / 2) > 0).astype(float)
    rgb = np.array((0.8, 0.4, 0.14)) * (0.85 + 0.15 * weave)[..., None]
    rgb *= (1 + _noise(256, 0.08))[..., None]
    return rgb, weave * 0.5, np.full((256, 256), 0.95)


def _gen_rug():
    # Tapete listrado verde musgo, com borda mostarda.
    y, x = np.mgrid[0:256, 0:256]
    rgb = np.where(((x // 32) % 2 == 0)[..., None], np.array((0.45, 0.5, 0.25)), np.array((0.36, 0.42, 0.2)))
    rgb[(y % 128 < 6)] = (0.85, 0.65, 0.2)
    rgb = rgb * (1 + _speckle(256, 0.6, 0.12))[..., None]
    return rgb, None, np.full((256, 256), 1.0)


def _stain(color, ring):
    """Mancha com transparência: bolha irregular, mais escura na borda quando `ring`."""
    size = 256
    y, x = (np.mgrid[0:size, 0:size] - size / 2) / (size / 2)
    r = np.sqrt(x * x + y * y)
    edge = 0.75 + _noise(size, 0.18, octaves=5)
    inside = np.clip((edge - r) / 0.25, 0, 1)
    alpha = inside * (0.55 + _noise(size, 0.25))
    if ring:
        alpha += np.clip(1 - np.abs(edge - r - 0.05) / 0.05, 0, 1) * 0.5
    alpha = np.clip(alpha, 0, 0.9)
    rgb = np.zeros((size, size, 3)) + np.array(color)
    rgb *= (1 + _noise(size, 0.2))[..., None]
    return rgb, alpha


# material -> (gerador, metros que a textura cobre)
def _gen_old_plastic(base, yellow):
    """Plástico de equipamento velho: granulado fino (textura de molde), amarelado irregular do
    sol, manchas e riscos claros. Devolve cor, altura (o granulado) e rugosidade."""
    size = 512
    stipple = _rng.random((size, size))
    for _ in range(2):  # suaviza o granulado para não virar chiado
        stipple = (stipple + np.roll(stipple, 1, 0) + np.roll(stipple, -1, 0)
                   + np.roll(stipple, 1, 1) + np.roll(stipple, -1, 1)) / 5
    stipple = (stipple - stipple.min()) / (stipple.max() - stipple.min())
    rgb = np.zeros((size, size, 3)) + np.array(base)
    rgb *= (1 + _noise(size, 0.035))[..., None]
    if yellow:
        amount = np.clip((_noise(size, 1.0, octaves=3) + 1) / 2, 0, 1)[..., None] * yellow
        rgb = rgb * (1 - amount) + np.array((0.74, 0.64, 0.42)) * amount
    rgb *= (0.96 + 0.08 * stipple)[..., None]
    rough = 0.5 + 0.2 * stipple
    # Riscos: traços finos mais claros e menos ásperos.
    for _ in range(14):
        x, y = _rng.integers(0, size, 2)
        ang = _rng.uniform(0, np.pi)
        length = _rng.integers(20, 90)
        for t in range(length):
            px = int(x + np.cos(ang) * t) % size
            py = int(y + np.sin(ang) * t) % size
            rgb[py, px] = np.minimum(rgb[py, px] * 1.12 + 0.03, 1.0)
            rough[py, px] = 0.35
    return rgb, stipple * 0.6, rough


def _gen_desk_metal():
    """Chapa de aço pintada de verde musgo, com lascas mostrando o metal escuro."""
    size = 256
    rgb = np.zeros((size, size, 3)) + np.array((0.45, 0.52, 0.3))
    rgb *= (1 + _noise(size, 0.05))[..., None]
    chips = _noise(size, 1.0, octaves=5) > 0.82
    rgb[chips] = (0.16, 0.15, 0.14)
    rough = np.where(chips, 0.7, 0.42)
    return rgb, np.where(chips, 0.0, 1.0), rough


def _gen_sticker_warning():
    """Adesivo amarelo de aviso: borda preta e triângulo com exclamação."""
    w, h = 256, 128
    y, x = np.mgrid[0:h, 0:w]
    rgb = np.zeros((h, w, 3)) + np.array((0.95, 0.78, 0.1))
    border = (x < 6) | (x >= w - 6) | (y < 6) | (y >= h - 6)
    rgb[border] = 0.05
    cx, base_y, top_y = 64, 22, 106
    half = (y - base_y) / (top_y - base_y)
    tri = (y >= base_y) & (y <= top_y) & (np.abs(x - cx) <= (1 - half) * 46)
    inner = (y >= base_y + 9) & (y <= top_y - 14) & (np.abs(x - cx) <= (1 - half) * 46 - 12)
    rgb[tri & ~inner] = 0.05
    rgb[(np.abs(x - cx) < 4) & (y > 50) & (y < 85)] = 0.05
    rgb[(np.abs(x - cx) < 4) & (y > 36) & (y < 44)] = 0.05
    for row in range(4):  # "texto" do aviso
        yy = 30 + row * 20
        rgb[(y >= yy) & (y < yy + 7) & (x > 128) & (x < 236 - row * 18)] = 0.12
    return rgb, None, np.full((h, w), 0.4)


def _gen_sticker_label():
    """Etiqueta branca de patrimônio/série: código de barras e linhas de texto."""
    w, h = 256, 128
    y, x = np.mgrid[0:h, 0:w]
    rgb = np.zeros((h, w, 3)) + np.array((0.93, 0.92, 0.88))
    bars = _rng.random(60) < 0.55
    for i, on in enumerate(bars):
        if on:
            rgb[(y > 18) & (y < 70) & (x >= 20 + i * 3) & (x < 22 + i * 3)] = 0.05
    for row, length in enumerate((200, 150, 180)):
        yy = 82 + row * 13
        rgb[(y >= yy) & (y < yy + 6) & (x > 20) & (x < 20 + length)] = 0.3
    return rgb, None, np.full((h, w), 0.6)


GENERATED = {
    "M_OldPlastic": (lambda: _gen_old_plastic((0.8, 0.76, 0.66), 0.35), 0.15),
    "M_OldPlasticDark": (lambda: _gen_old_plastic((0.3, 0.3, 0.31), 0.0), 0.15),
    "M_DeskMetal": (_gen_desk_metal, 0.5),
    "M_StickerWarning": (_gen_sticker_warning, 1.0),
    "M_StickerLabel": (_gen_sticker_label, 1.0),
    "M_Floor": (_gen_floor, 0.9),
    "M_FloorBath": (_gen_floor_bath, 0.6),
    "M_Tile": (_gen_wall_tile, 0.4),
    "M_TileKitchen": (_gen_kitchen_tile, 0.4),
    "M_Granite": (_gen_granite, 0.6),
    "M_Fabric": (_gen_fabric, 0.25),
    "M_Rug": (_gen_rug, 0.8),
    "M_DecalMold": (lambda: _stain((0.24, 0.26, 0.2), False), 1.0),
    "M_DecalWater": (lambda: _stain((0.55, 0.45, 0.3), True), 1.0),
    "M_DecalGrime": (lambda: _stain((0.2, 0.18, 0.15), False), 1.0),
}


def _generated_maps(name):
    key = f"TX_{name}_color"
    if bpy.data.images.get(key) is None:
        out = GENERATED[name][0]()
        if len(out) == 2:  # mancha: cor e transparência
            _image(key, out[0], alpha=out[1])
        else:
            rgb, height, rough = out
            _image(key, rgb)
            if height is not None:
                _image(f"TX_{name}_normal", _normal_from_height(height, 2.5))
            if rough is not None:
                _image(f"TX_{name}_roughness", np.repeat(np.clip(rough, 0, 1)[..., None], 3, axis=2))
    maps = {"color": bpy.data.images[key]}
    if bpy.data.images[key].alpha_mode != "NONE" and name.startswith("M_Decal"):
        maps["alpha"] = True
    for stem in ("normal", "roughness"):
        img = bpy.data.images.get(f"TX_{name}_{stem}")
        if img is not None:
            maps[stem] = img
    return maps


def _image(name, rgb, alpha=None):
    h, w = rgb.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=alpha is not None)
    a = np.ones((h, w, 1)) if alpha is None else alpha[..., None]
    img.pixels.foreach_set(np.concatenate([np.clip(rgb, 0, 1), a], axis=2).astype(np.float32).ravel())
    img.pack()
    return img
