"""Texturas dos materiais, pintadas aqui como num desenho animado: cor chapada, traços simples e
quase nenhum ruído. Ficam embutidas no .blend (nada em disco).

- TINTED: desenhos em cinza (veio de madeira, papel de parede listrado, reboco, granilite,
  xadrez). A cor do material (lib.MATERIALS) tinge, então a paleta manda em tudo.
- O resto (pisos, azulejos, tecido, tapete, plástico, adesivos) já sai com a cor certa.
- Manchas e rachaduras (M_Decal*) têm transparência.

`tile(material)` diz quantos metros a textura cobre: o lib.Part usa nas UVs das caixas.
"""

import math

import bpy
import numpy as np

# Brilho do fundo dos desenhos em cinza: a cor do material é dividida por ele ao tingir.
PAINT_BASE = 0.9

_tiles = {}
_rng = np.random.default_rng(11)


def tile(name):
    return _tiles.get(name, 1.0)


def has_texture(name):
    return name in SHARED or name in GENERATED


def prepare():
    """Calcula o tamanho de cada textura. Chame antes de montar."""
    _tiles.clear()
    for name, (_, size) in GENERATED.items():
        _tiles[name] = size
    for name, other in SHARED.items():
        _tiles[name] = _tiles[other]


def wire(mat, bsdf, name):
    """Liga as imagens do material `name` no Principled. A cor base atual vira o tingimento."""
    source = SHARED.get(name, name)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    tint = tuple(bsdf.inputs["Base Color"].default_value)[:3]
    maps = _generated_maps(source)
    color = nodes.new("ShaderNodeTexImage")
    color.image = maps["color"]
    color_out = color.outputs["Color"]
    if source in TINTED:
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs["B"].default_value = (*[min(c / PAINT_BASE, 1.0) for c in tint], 1.0)
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
        links.new(normal.outputs["Color"], nmap.inputs["Color"])
        links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return "alpha" in maps


# --- Ferramentas de desenho -----------------------------------------------------------------------
# As matrizes são (linha, coluna) com a linha 0 embaixo, como o Blender guarda as imagens. Tudo
# que é repetido fecha na emenda (a textura se repete na parede).

def _grid(size):
    y, x = np.mgrid[0:size, 0:size]
    return x.astype(float), y.astype(float)


def _wrap(d, size):
    """Diferença com a volta da emenda (de -size/2 a size/2)."""
    return (d + size / 2) % size - size / 2


def _gray(value):
    return np.repeat(value[..., None], 3, axis=2)


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


def _wavy_lines(size, count, width, waves, amp):
    """Linhas horizontais onduladas (veio de madeira): máscara de 0 a 1 com borda de 1 pixel."""
    x, y = _grid(size)
    mask = np.zeros((size, size))
    for _ in range(count):
        y0 = _rng.uniform(0, size)
        k = _rng.integers(1, waves + 1)
        center = y0 + _rng.uniform(0.4, 1.0) * amp * np.sin(2 * np.pi * k * x / size + _rng.uniform(0, 2 * np.pi))
        w = _rng.uniform(0.6, 1.0) * width
        mask = np.maximum(mask, np.clip(w - np.abs(_wrap(y - center, size)), 0, 1))
    return mask


def _ellipse(size, cx, cy, rx, ry, angle=0.0):
    """Distância normalizada ao centro de uma elipse (1 = na borda), com a volta da emenda."""
    x, y = _grid(size)
    dx, dy = _wrap(x - cx, size), _wrap(y - cy, size)
    c, s = math.cos(angle), math.sin(angle)
    u, v = dx * c + dy * s, -dx * s + dy * c
    return np.sqrt((u / rx) ** 2 + (v / ry) ** 2)


def _spots(size, count, rmin, rmax, values, base):
    """Pintinhas e lascas chapadas (granilite, granito) por cima de `base` (cinza ou cor)."""
    out = base.copy()
    for _ in range(count):
        r = _rng.uniform(rmin, rmax)
        d = _ellipse(size, *_rng.uniform(0, size, 2), r, r * _rng.uniform(0.5, 1.0), _rng.uniform(0, np.pi))
        inside = np.clip((1 - d) * r, 0, 1)
        if out.ndim == 3:
            inside = inside[..., None]
        out = out * (1 - inside) + inside * np.asarray(values[_rng.integers(len(values))])
    return out


def _segment_dist(x, y, a, b):
    ab = b - a
    t = np.clip(((x - a[0]) * ab[0] + (y - a[1]) * ab[1]) / max(ab @ ab, 1e-9), 0, 1)
    return np.hypot(x - a[0] - t * ab[0], y - a[1] - t * ab[1])


def _dilate(mask, px):
    out = mask.copy()
    for dx in range(-px, px + 1):
        for dy in range(-px, px + 1):
            if dx * dx + dy * dy <= px * px:
                out |= np.roll(np.roll(mask, dx, 1), dy, 0)
    return out


# --- Desenhos em cinza (a cor do material tinge) --------------------------------------------------

def _paint_wood():
    """Madeira de desenho: fundo liso, uns veios ondulados e um nó."""
    size = 512
    value = np.full((size, size), PAINT_BASE)
    value -= 0.1 * _wavy_lines(size, 6, 2.2, 3, 22)
    value -= 0.05 * _wavy_lines(size, 6, 1.4, 2, 30)
    d = _ellipse(size, *_rng.uniform(0, size, 2), 16, 8)
    value -= 0.14 * np.clip(1.5 - np.abs(d - 1) * 8, 0, 1)
    value -= 0.06 * (d < 0.7)
    return _gray(value), None, np.full((size, size), 0.6)


def _paint_wallpaper():
    """Papel de parede anos 70 (a textura cobre 60 cm): listras largas alternando o tom, um fio
    entre elas e losangos na listra clara."""
    size = 512
    x, y = _grid(size)
    period = 128
    sx = x % period
    value = np.where(sx < period / 2, PAINT_BASE + 0.06, PAINT_BASE - 0.04)
    value[np.abs(sx - period / 2) < 2] = PAINT_BASE - 0.16
    value[sx < 2] = PAINT_BASE - 0.16
    cx, cy = period / 4, 32
    dx, dy = np.abs((x % period) - cx), np.abs((y % 64) - cy)
    value[(dx / 9 + dy / 13) < 1] = PAINT_BASE - 0.1
    value[(dx / 4 + dy / 6) < 1] = PAINT_BASE + 0.06
    return _gray(np.clip(value, 0, 1)), None, np.full((size, size), 0.85)


def _paint_plaster(strength=1.0):
    """Reboco pintado à mão: fundo liso com pinceladas largas um tom acima e abaixo."""
    size = 512
    value = np.full((size, size), PAINT_BASE)
    for sign in (1, -1):
        for _ in range(7):
            d = _ellipse(size, *_rng.uniform(0, size, 2), _rng.uniform(40, 110), _rng.uniform(6, 14), _rng.uniform(-0.3, 0.3))
            value += sign * 0.035 * strength * (d < 1)
    for _ in range(40):
        d = _ellipse(size, *_rng.uniform(0, size, 2), 2.5, 2.5)
        value -= 0.08 * strength * (d < 1)
    return _gray(np.clip(value, 0, 1)), None, np.full((size, size), 0.9)


def _paint_terrazzo():
    """Granilite de desenho: lascas chapadas grandes em três tons."""
    size = 512
    value = _spots(size, 170, 3, 9, (PAINT_BASE - 0.3, PAINT_BASE - 0.15, 1.0), np.full((size, size), PAINT_BASE - 0.05))
    return _gray(value), None, np.full((size, size), 0.5)


def _paint_plaid():
    """Xadrez de cobertor: faixas escuras cruzadas e fios claros."""
    size = 256
    x, y = _grid(size)
    value = np.full((size, size), PAINT_BASE)
    value -= 0.14 * ((x % 128) < 40)
    value -= 0.14 * ((y % 128) < 40)
    value[((x % 64) == 52) | ((x % 64) == 53) | ((y % 64) == 52) | ((y % 64) == 53)] = 1.0
    return _gray(np.clip(value, 0, 1)), None, np.full((size, size), 1.0)


# --- Desenhos coloridos ---------------------------------------------------------------------------

def _tiles_pattern(size, count, base, jitter, grout_px, grout_color, shine=0.12):
    """Ladrilhos quadrados lisos, rejunte grosso e um risco de brilho no canto de cada peça (o
    reflexo do desenho animado). Devolve cor e altura."""
    cell = size // count
    x, y = _grid(size)
    rgb = np.zeros((size, size, 3)) + np.array(base)
    for i in range(count):
        for j in range(count):
            rgb[i * cell:(i + 1) * cell, j * cell:(j + 1) * cell] *= _rng.uniform(1 - jitter, 1 + jitter)
    gx, gy = x % cell, cell - (y % cell)  # gy a partir do alto da peça
    stroke = (np.abs(gx + gy - 0.24 * cell) < cell * 0.018) & (gx > 0.07 * cell) & (gy > 0.07 * cell)
    dot = np.hypot(gx - 0.3 * cell, gy - 0.07 * cell - 3) < cell * 0.02
    rgb[stroke | dot] += shine
    grout = (gx < grout_px) | ((y % cell) < grout_px)
    rgb[grout] = grout_color
    return np.clip(rgb, 0, 1), np.where(grout, 0.0, 1.0)


def _gen_floor():
    # Piso cerâmico cor de telha de 45 cm (a textura cobre 2 x 2 peças).
    rgb, height = _tiles_pattern(512, 2, (0.76, 0.45, 0.28), 0.04, 5, (0.42, 0.27, 0.18), shine=0.08)
    return rgb, height, 0.32 + 0.4 * (1 - height)


def _gen_floor_bath():
    rgb, height = _tiles_pattern(512, 2, (0.42, 0.62, 0.66), 0.04, 5, (0.28, 0.38, 0.4))
    return rgb, height, 0.3 + 0.4 * (1 - height)


def _gen_wall_tile():
    # Azulejo azul de piscina clarinho 20 x 20 (2 x 2 peças), rejunte encardido.
    rgb, height = _tiles_pattern(512, 2, (0.66, 0.86, 0.88), 0.03, 6, (0.55, 0.58, 0.5))
    return rgb, height, 0.12 + 0.6 * (1 - height)


def _gen_kitchen_tile():
    # Pastilha azul de piscina 10 x 10 (4 x 4 peças).
    rgb, height = _tiles_pattern(512, 4, (0.48, 0.76, 0.78), 0.06, 5, (0.88, 0.88, 0.82))
    return rgb, height, 0.12 + 0.6 * (1 - height)


def _gen_granite():
    # Granito preto de desenho: fundo quase preto com bolinhas cinza e brancas.
    base = np.full((512, 512, 3), 0.07)
    rgb = _spots(512, 110, 1.5, 3.5, ((0.3, 0.3, 0.32), (0.75, 0.75, 0.78)), base)
    return rgb, None, np.full((512, 512), 0.18)


def _gen_fabric():
    # Sofá laranja queimado: liso, com umas manchas de uso um tom abaixo.
    size = 256
    rgb = np.zeros((size, size, 3)) + np.array((0.8, 0.4, 0.14))
    for _ in range(5):
        d = _ellipse(size, *_rng.uniform(0, size, 2), _rng.uniform(20, 50), _rng.uniform(15, 35), _rng.uniform(0, np.pi))
        rgb *= np.where(d < 1, 0.92, 1.0)[..., None]
    return rgb, None, np.full((size, size), 0.95)


def _gen_rug():
    # Tapete listrado verde musgo, com borda mostarda.
    x, y = _grid(256)
    rgb = np.where(((x // 32) % 2 == 0)[..., None], np.array((0.45, 0.5, 0.25)), np.array((0.36, 0.42, 0.2)))
    rgb[(y % 128 < 6)] = (0.85, 0.65, 0.2)
    return rgb, None, np.full((256, 256), 1.0)


def _stain(color, ring):
    """Mancha de desenho com transparência: bolha irregular chapada e a borda mais escura."""
    size = 256
    y, x = (np.mgrid[0:size, 0:size] - size / 2) / (size / 2)
    r = np.sqrt(x * x + y * y)
    edge = 0.75 + _noise(size, 0.16, octaves=3)
    inside = np.clip((edge - r) * 60, 0, 1)
    rim = np.clip((edge - r) * 60, 0, 1) * np.clip(1 - (edge - r - (0.06 if ring else 0.03)) * 60, 0, 1)
    alpha = np.clip(inside * 0.45 + rim * 0.4, 0, 0.85)
    rgb = np.zeros((size, size, 3)) + np.array(color)
    rgb *= (1 - 0.35 * rim)[..., None]
    return rgb, alpha


def _crack():
    """Rachadura no reboco em traço preto: um risco que anda torto e solta dois galhos."""
    size = 256
    x, y = _grid(size)
    dist = np.full((size, size), 1e9)
    branches = [(np.array((20.0, size / 2)), 0.0, 22, 3.0)]
    while branches:
        pos, angle, steps, width = branches.pop()
        for i in range(steps):
            angle += _rng.uniform(-0.5, 0.5)
            nxt = pos + np.array((math.cos(angle), math.sin(angle))) * 10
            dist = np.minimum(dist, _segment_dist(x, y, pos, nxt) - width * (1 - i / steps) * 0.8)
            pos = nxt
            if i in (6, 13) and width > 2:
                branches.append((pos.copy(), angle + _rng.choice((-1, 1)) * _rng.uniform(0.6, 1.0), 8, width * 0.6))
    alpha = np.clip(1.5 - dist, 0, 1) * 0.95
    return np.zeros((size, size, 3)) + 0.05, alpha


def _gen_old_plastic(base, yellow):
    """Plástico de equipamento velho, liso: manchas amareladas de sol com borda dura e uns riscos
    claros."""
    size = 512
    rgb = np.zeros((size, size, 3)) + np.array(base)
    if yellow:
        for _ in range(6):
            d = _ellipse(size, *_rng.uniform(0, size, 2), _rng.uniform(40, 110), _rng.uniform(30, 80), _rng.uniform(0, np.pi))
            rgb = np.where((d < 1)[..., None], rgb * (1 - yellow) + np.array((0.74, 0.64, 0.42)) * yellow, rgb)
    rough = np.full((size, size), 0.55)
    x, y = _grid(size)
    for _ in range(8):
        a = _rng.uniform(0, size, 2)
        ang = _rng.uniform(0, np.pi)
        b = a + np.array((math.cos(ang), math.sin(ang))) * _rng.uniform(25, 80)
        line = _segment_dist(x, y, a, b) < 1.0
        rgb[line] = np.minimum(rgb[line] * 1.12 + 0.03, 1.0)
    return rgb, None, rough


def _gen_desk_metal():
    """Chapa pintada de verde musgo, com lascas mostrando o metal escuro e um contorno nelas."""
    size = 256
    rgb = np.zeros((size, size, 3)) + np.array((0.45, 0.52, 0.3))
    chips = _noise(size, 1.0, octaves=5) > 0.82
    rgb[_dilate(chips, 2)] = (0.3, 0.35, 0.2)
    rgb[chips] = (0.16, 0.15, 0.14)
    rough = np.where(chips, 0.7, 0.42)
    return rgb, None, rough


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



# --- Desenhos da etapa 3 (retrato) ----------------------------------------
# Imagens soltas (UV de 0 a 1 num quad), com a linha 0 embaixo.

def _canvas(w, h, color):
    y, x = np.mgrid[0:h, 0:w]
    return np.zeros((h, w, 3)) + np.array(color), x.astype(float), y.astype(float)


def _fill(rgb, mask, color, outline=0, line=0.04):
    """Pinta `mask` de `color`; `outline` px de traço preto em volta (por fora)."""
    if outline:
        rgb[_dilate(mask, outline) & ~mask] = line
    rgb[mask] = color


def _ell(x, y, cx, cy, rx, ry):
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def _gen_portrait():
    """Retrato a óleo de um presidente inventado: cara redonda, bigodão, faixa e medalhas."""
    w, h = 256, 320
    rgb, x, y = _canvas(w, h, (0.5, 0.18, 0.15))
    rgb[(y < 150) & (x > 20) & (x < w - 20) & (np.abs(x - 128) + (150 - y) * 0.2 < 118)] = (0.58, 0.24, 0.18)
    cx = 128
    # Terno azul, camisa, faixa verde e amarela cruzada e as medalhas.
    suit = (_ell(x, y, cx, 90, 118, 100)) & (y < 190)
    _fill(rgb, suit, (0.18, 0.28, 0.52), outline=4)
    shirt = (y > 105) & (y < 188) & (np.abs(x - cx) < 20 + (y - 105) * 0.35)
    _fill(rgb, shirt, (0.95, 0.94, 0.88), outline=3)
    tie = (y > 70) & (y < 175) & (np.abs(x - cx) < 9 + (y > 150) * 8)
    _fill(rgb, tie, (0.8, 0.12, 0.1), outline=3)
    sash = (np.abs((y - 190) + (x - 40) * 0.85 - 0) < 18) & (x > 30) & (y > 8)
    sash &= suit
    _fill(rgb, sash, (0.2, 0.7, 0.28), outline=3)
    rgb[sash & (np.abs((y - 190) + (x - 40) * 0.85) < 4)] = (0.98, 0.85, 0.15)
    for i, (mx, my) in enumerate(((60, 62), (82, 54), (190, 70))):  # medalhas
        _fill(rgb, _ell(x, y, mx, my, 12, 12), (0.95, 0.78, 0.2), outline=3)
        _fill(rgb, _ell(x, y, mx, my, 5, 5), (0.85, 0.15, 0.1))
    # Cabelo grisalho dos lados, orelhas, cabeça redonda e papada.
    _fill(rgb, _ell(x, y, cx, 215, 92, 82), (0.78, 0.78, 0.8), outline=4)
    _fill(rgb, _ell(x, y, 56, 190, 14, 20), (0.92, 0.66, 0.46), outline=3)
    _fill(rgb, _ell(x, y, 200, 190, 14, 20), (0.92, 0.66, 0.46), outline=3)
    _fill(rgb, _ell(x, y, cx, 175, 76, 84), (0.95, 0.7, 0.5), outline=4)
    _fill(rgb, _ell(x, y, cx, 150, 70, 38), (0.95, 0.7, 0.5))
    rgb[_ell(x, y, 80, 160, 18, 11) | _ell(x, y, 176, 160, 18, 11)] = (0.97, 0.52, 0.42)  # bochechas
    # Testa lisa com brilho, sobrancelhas grossas, olhinhos e nariz de batata.
    rgb[_ell(x, y, 104, 230, 14, 6)] = (1.0, 0.85, 0.7)
    for sx in (-1, 1):
        ex = cx + sx * 30
        brow = (np.abs(y - (200 + (x - ex) * sx * 0.25)) < 5) & (np.abs(x - ex) < 22)
        _fill(rgb, brow, (0.25, 0.25, 0.27))
        _fill(rgb, _ell(x, y, ex, 184, 13, 9), (0.98, 0.98, 0.95), outline=2)
        _fill(rgb, _ell(x, y, ex - sx * 2, 184, 4.5, 5.5), (0.05, 0.05, 0.05))
    _fill(rgb, _ell(x, y, cx, 150, 17, 14), (0.93, 0.56, 0.42), outline=3)
    # Bigodão preto, boca pequena embaixo e queixo duplo.
    mus = _ell(x, y, cx - 27, 126, 30, 11) | _ell(x, y, cx + 27, 126, 30, 11)
    mus &= (y < 132) | (np.abs(x - cx) > 14)
    _fill(rgb, mus, (0.1, 0.1, 0.12), outline=3)
    _fill(rgb, _ell(x, y, cx, 104, 17, 6), (0.55, 0.12, 0.12), outline=2)
    rgb[(np.abs(y - (88 - ((x - cx) / 40) ** 2 * 10)) < 2.2) & (np.abs(x - cx) < 40)] = 0.12
    # Plaquinha dourada embaixo do retrato.
    rgb[(y > 6) & (y < 26) & (x > 70) & (x < 186)] = 0.04
    rgb[(y > 9) & (y < 23) & (x > 73) & (x < 183)] = (0.9, 0.72, 0.2)
    for i in range(5):
        rgb[(y > 14) & (y < 18) & (x > 82 + i * 20) & (x < 96 + i * 20)] = 0.15
    rgb[(x < 5) | (x >= w - 5) | (y < 3) | (y >= h - 5)] = 0.05
    return rgb, None, np.full((h, w), 0.6)

def _ink_splat():
    """Respingo de tinta verde neon: bolha central, gotas em volta e dois escorridos, com a borda
    mais escura (como as manchas, tem transparência)."""
    size = 256
    x, y = _grid(size)
    c = size / 2
    blob = _ellipse(size, c, c, 58, 50) - _noise(size, 0.25, octaves=3) < 1.0
    for _ in range(9):
        a = _rng.uniform(0, 2 * math.pi)
        d = _rng.uniform(70, 112)
        r = _rng.uniform(5, 13)
        blob |= _ellipse(size, c + d * math.cos(a), c + d * math.sin(a), r, r) < 1.0
    for _ in range(2):
        a = _rng.uniform(0, 2 * math.pi)
        tip = np.array((c + 105 * math.cos(a), c + 105 * math.sin(a)))
        blob |= _segment_dist(x, y, np.array((c, c)), tip) < 7
    rim = _dilate(blob, 3) & ~_dilate(~blob, 3)
    rgb = np.zeros((size, size, 3)) + np.array((0.3, 0.95, 0.35))
    rgb[rim] = (0.08, 0.4, 0.12)
    return rgb, blob.astype(float) * 0.92


def _footprint():
    """Pegada de tênis em tinta verde: sola da frente e calcanhar, com as ranhuras da sola. O bico
    aponta para +V (cima da imagem)."""
    size = 256
    x, y = _grid(size)
    front = _ellipse(size, 128, 165, 62, 84) < 1.0
    heel = _ellipse(size, 128, 48, 50, 44) < 1.0
    # Sola cheia com três ranhuras largas (finas demais, de longe a pegada virava risquinhos).
    sole = (front | heel) & ~((np.abs(y - 140) < 6) | (np.abs(y - 190) < 6) | (np.abs(y - 60) < 5))
    rim = _dilate(sole, 3) & ~sole
    rgb = np.zeros((size, size, 3)) + np.array((0.3, 0.95, 0.35))
    rgb[rim] = (0.08, 0.4, 0.12)
    return rgb, (sole | rim).astype(float) * 0.9

# material -> (gerador, metros que a textura cobre)
GENERATED = {
    "M_Wall": (_paint_wallpaper, 0.6),
    "M_Ceiling": (lambda: _paint_plaster(0.6), 1.5),
    "M_Concrete": (lambda: _paint_plaster(1.6), 2.0),
    "M_FloorHall": (_paint_terrazzo, 1.0),
    "M_Wood": (_paint_wood, 0.8),
    "M_WoodLight": (_paint_wood, 0.8),
    "M_DoorWood": (_paint_wood, 0.9),
    "M_DeskWood": (_paint_wood, 0.8),
    "M_Blanket": (_paint_plaid, 0.5),
    "M_OldPlastic": (lambda: _gen_old_plastic((0.8, 0.76, 0.66), 0.35), 0.15),
    "M_OldPlasticDark": (lambda: _gen_old_plastic((0.3, 0.3, 0.31), 0.0), 0.15),
    "M_DeskMetal": (_gen_desk_metal, 0.5),
    "M_StickerWarning": (_gen_sticker_warning, 1.0),
    "M_StickerLabel": (_gen_sticker_label, 1.0),
    "M_Portrait": (_gen_portrait, 1.0),
    "M_Floor": (_gen_floor, 0.9),
    "M_FloorBath": (_gen_floor_bath, 0.6),
    "M_Tile": (_gen_wall_tile, 0.4),
    "M_TileKitchen": (_gen_kitchen_tile, 0.4),
    "M_Granite": (_gen_granite, 0.6),
    "M_Fabric": (_gen_fabric, 0.5),
    "M_Rug": (_gen_rug, 0.8),
    "M_DecalMold": (lambda: _stain((0.3, 0.36, 0.18), False), 1.0),
    "M_DecalWater": (lambda: _stain((0.6, 0.45, 0.25), True), 1.0),
    "M_DecalGrime": (lambda: _stain((0.25, 0.2, 0.15), False), 1.0),
    "M_DecalCrack": (_crack, 1.0),
    "M_DecalInk": (_ink_splat, 1.0),
    "M_DecalFootprint": (_footprint, 1.0),
}
# Desenhos em cinza que a cor do material tinge.
TINTED = {"M_Wall", "M_Ceiling", "M_Concrete", "M_FloorHall", "M_Wood", "M_WoodLight", "M_DoorWood",
          "M_DeskWood", "M_Blanket"}
# Materiais que usam a textura de outro (com a própria cor por cima).
SHARED = {"M_WallHall": "M_Ceiling", "M_WallHallLow": "M_Ceiling", "M_Facade": "M_Concrete",
          "M_FacadeFar": "M_Concrete"}


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


def _normal_from_height(height, strength):
    dx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    dy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    n = np.stack([-dx * strength, -dy * strength, np.ones_like(height)], axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def _image(name, rgb, alpha=None):
    h, w = rgb.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=alpha is not None)
    a = np.ones((h, w, 1)) if alpha is None else alpha[..., None]
    img.pixels.foreach_set(np.concatenate([np.clip(rgb, 0, 1), a], axis=2).astype(np.float32).ravel())
    img.pack()
    return img
