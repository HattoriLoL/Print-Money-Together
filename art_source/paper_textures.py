"""Texturas do papel: a nota (frente e verso), a folha A4 impressa com 2 x 3 notas (frente e
verso), a fibra do papel e a embalagem da resma. Saem em assets/textures/.

Roda com o Python do sistema e o Pillow (não dentro do Blender, que não tem Pillow):

    python art_source/paper_textures.py

O texto usa as fontes do Windows (Georgia, Arial, Consolas). A nota é de mentira: "Kitnet
Reserve", cem de uma moeda que não existe, com uma capivara no retrato.
"""

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "textures")
FONTS = "C:/Windows/Fonts"

# Nota: proporção da célula na folha A4 (margem de 8 mm, vão de 3 mm entre as notas).
BILL = (1240, 560)
# Folha A4 deitada: 297 x 210 mm.
SHEET = (2000, 1414)
SHEET_MARGIN = 54
SHEET_GUTTER = 20

DARK = (34, 72, 46)
MID = (70, 120, 80)
LIGHT = (150, 190, 140)
GOLD = (200, 165, 70)
RED = (150, 40, 38)

rng = random.Random(301)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def text_center(draw, xy, text, fnt, fill, stroke=0, stroke_fill=None):
    draw.text(xy, text, font=fnt, fill=fill, anchor="mm", stroke_width=stroke, stroke_fill=stroke_fill)


# --- Desenhos de cédula ---------------------------------------------------------------------------

def guilloche(draw, box, color, waves, amp, count, phase=0.0, width=1):
    """Feixe de linhas onduladas que se cruzam (o fundo "de segurança" das cédulas)."""
    x0, y0, x1, y1 = box
    for k in range(count):
        pts = []
        off = (k - count / 2) * (y1 - y0) / count * 0.9
        for x in range(x0, x1 + 1, 3):
            t = (x - x0) / max(x1 - x0, 1)
            y = (y0 + y1) / 2 + off + amp * math.sin(t * waves * 2 * math.pi + k * 0.33 + phase) \
                * math.cos(t * math.pi * 1.7 + k * 0.21)
            pts.append((x, y))
        draw.line(pts, fill=color, width=width)


def rosette(draw, cx, cy, r, color, petals=12, loops=22, width=1):
    """Roseta de linhas (como nos cantos das notas)."""
    for k in range(loops):
        rr = r * (0.45 + 0.55 * k / loops)
        pts = []
        for i in range(0, 361, 2):
            a = math.radians(i)
            rad = rr * (0.78 + 0.22 * math.cos(petals * a + k * 0.45))
            pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
        draw.line(pts, fill=color, width=width)


def capybara(draw, cx, cy, s, fill, eye):
    """Capivara de perfil virada para a direita, em formas simples (a "efígie" da nota)."""
    draw.ellipse((cx - 95 * s, cy - 15 * s, cx + 115 * s, cy + 150 * s), fill=fill)          # corpo/peito
    draw.rounded_rectangle((cx - 60 * s, cy - 120 * s, cx + 120 * s, cy + 20 * s), 60 * s, fill=fill)  # cabeça
    draw.rounded_rectangle((cx + 60 * s, cy - 95 * s, cx + 165 * s, cy + 10 * s), 45 * s, fill=fill)   # focinho
    draw.ellipse((cx - 55 * s, cy - 150 * s, cx - 5 * s, cy - 100 * s), fill=fill)            # orelha
    draw.ellipse((cx + 32 * s, cy - 78 * s, cx + 52 * s, cy - 58 * s), fill=eye)               # olho
    draw.ellipse((cx + 140 * s, cy - 70 * s, cx + 152 * s, cy - 58 * s), fill=eye)             # narina
    draw.arc((cx + 95 * s, cy - 40 * s, cx + 155 * s, cy - 5 * s), 20, 120, fill=eye, width=max(2, int(3 * s)))


def border(draw, w, h):
    draw.rectangle((10, 10, w - 11, h - 11), outline=DARK, width=8)
    draw.rectangle((26, 26, w - 27, h - 27), outline=MID, width=2)
    for cx, cy in ((26, 26), (w - 27, 26), (26, h - 27), (w - 27, h - 27)):
        rosette(draw, cx, cy, 34, DARK, petals=8, loops=10, width=2)


def gradient(w, h, left, right):
    a = np.linspace(0, 1, w)[None, :, None]
    img = np.array(left)[None, None, :] * (1 - a) + np.array(right)[None, None, :] * a
    img = np.repeat(img, h, axis=0)
    img += np.random.default_rng(7).normal(0, 3.0, img.shape)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def bill_front():
    w, h = BILL
    img = gradient(w, h, (196, 220, 176), (166, 204, 172))
    d = ImageDraw.Draw(img)
    guilloche(d, (40, 30, w - 40, 150), LIGHT, 3.5, 40, 14)
    guilloche(d, (40, h - 150, w - 40, h - 30), LIGHT, 4.0, 40, 14, phase=1.2)
    guilloche(d, (560, 170, w - 60, h - 170), (176, 206, 160), 2.0, 70, 18, phase=0.5)
    # Marca-d'água: oval claro à direita.
    d.ellipse((1030, 250, 1190, 430), fill=(208, 228, 196))
    # Retrato oval com hachura e a capivara.
    ox, oy, rx, ry = 300, 290, 165, 215
    d.ellipse((ox - rx - 10, oy - ry - 10, ox + rx + 10, oy + ry + 10), fill=MID)
    d.ellipse((ox - rx, oy - ry, ox + rx, oy + ry), fill=(206, 226, 192))
    for y in range(oy - ry, oy + ry, 6):
        d.line((ox - rx, y, ox + rx, y), fill=(184, 210, 172), width=2)
    capybara(d, ox - 40, oy + 20, 1.05, DARK, (196, 220, 176))
    # Título, valor e textos.
    text_center(d, (790, 78), "KITNET RESERVE", font("georgiab.ttf", 66), DARK)
    d.line((560, 120, 1020, 120), fill=MID, width=3)
    micro = font("arial.ttf", 13)
    line = "KITNET RESERVE 301 · " * 9
    while d.textlength(line, font=micro) > 450:
        line = line[:-1]
    d.text((560, 126), line, font=micro, fill=MID)
    text_center(d, (790, 300), "100", font("georgiab.ttf", 250), DARK, stroke=6, stroke_fill=(220, 236, 205))
    text_center(d, (790, 455), "ONE HUNDRED", font("georgia.ttf", 46), DARK)
    d.text((70, 40), "100", font=font("georgiab.ttf", 64), fill=DARK)
    d.text((w - 190, h - 112), "100", font=font("georgiab.ttf", 64), fill=DARK)
    # Selo dourado e número de série em vermelho.
    sx, sy = 1080, 170
    d.ellipse((sx - 62, sy - 62, sx + 62, sy + 62), fill=GOLD)
    rosette(d, sx, sy, 58, (150, 115, 40), petals=16, loops=8, width=2)
    star = [(sx + (40 if i % 2 == 0 else 17) * math.cos(math.radians(-90 + i * 36)),
             sy + (40 if i % 2 == 0 else 17) * math.sin(math.radians(-90 + i * 36))) for i in range(10)]
    d.polygon(star, fill=(130, 95, 30))
    serial = font("consolab.ttf", 34)
    d.text((70, h - 80), "KN 0301 1999", font=serial, fill=RED)
    d.text((600, 165), "KN 0301 1999", font=serial, fill=RED)
    d.text((560, 500), "THIS NOTE IS LEGAL TENDER IN APARTMENT 301 ONLY", font=font("arial.ttf", 16), fill=MID)
    border(d, w, h)
    return img


def bill_back():
    w, h = BILL
    img = gradient(w, h, (178, 206, 188), (196, 214, 176))
    d = ImageDraw.Draw(img)
    for i in range(5):
        guilloche(d, (40, 40 + i * 100, w - 40, 140 + i * 100), (190, 214, 186), 3.0 + i * 0.4, 30, 8, phase=i)
    # O prédio da kitnet, com a janela do 301 acesa.
    bx0, by0, bx1, by1 = 560, 150, 980, 470
    d.rectangle((bx0 - 30, by1, bx1 + 30, by1 + 10), fill=DARK)
    d.rectangle((bx0, by0, bx1, by1), fill=MID, outline=DARK, width=4)
    d.rectangle((bx0 - 12, by0 - 22, bx1 + 12, by0), fill=DARK)
    for row in range(5):
        for col in range(6):
            x = bx0 + 22 + col * 66
            y = by0 + 22 + row * 58
            lit = (row, col) == (2, 3)
            d.rectangle((x, y, x + 40, y + 34), fill=(235, 210, 120) if lit else (200, 222, 190), outline=DARK, width=2)
    d.rectangle((bx0 + 180, by1 - 60, bx0 + 240, by1), fill=DARK)
    text_center(d, (300, 300), "100", font("georgiab.ttf", 230), (196, 220, 196), stroke=5, stroke_fill=DARK)
    text_center(d, (770, 88), "KITNET RESERVE", font("georgiab.ttf", 50), DARK)
    d.text((w - 200, 40), "100", font=font("georgiab.ttf", 64), fill=DARK)
    d.text((70, h - 112), "100", font=font("georgiab.ttf", 64), fill=DARK)
    rosette(d, 1090, 330, 90, MID, petals=14, loops=16, width=2)
    border(d, w, h)
    return img


# --- Folha A4 --------------------------------------------------------------------------------------

def paper_base(size, tint=(247, 246, 240)):
    w, h = size
    noise = np.random.default_rng(3).normal(0, 2.2, (h, w, 1))
    img = np.array(tint)[None, None, :] + noise
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def sheet(bill, back=False):
    """Folha A4 com 2 x 3 notas, marcas de corte e a barra de cores da gráfica."""
    w, h = SHEET
    img = paper_base(SHEET)
    d = ImageDraw.Draw(img)
    m, g = SHEET_MARGIN, SHEET_GUTTER
    bw = (w - 2 * m - g) // 2
    bh = (h - 2 * m - 2 * g) // 3
    cell = bill.resize((bw, bh), Image.LANCZOS)
    xs = [m, m + bw + g]
    ys = [m, m + bh + g, m + 2 * (bh + g)]
    for x in xs:
        for y in ys:
            img.paste(cell, (x, y))
    # Marcas de corte nas margens, no prolongamento de cada borda das notas.
    mark = (60, 60, 60)
    edges_x = sorted({x for x in xs} | {x + bw for x in xs})
    edges_y = sorted({y for y in ys} | {y + bh for y in ys})
    for x in edges_x:
        d.line((x, 6, x, m - 12), fill=mark, width=2)
        d.line((x, h - m + 12, x, h - 6), fill=mark, width=2)
    for y in edges_y:
        d.line((6, y, m - 12, y), fill=mark, width=2)
        d.line((w - m + 12, y, w - 6, y), fill=mark, width=2)
    if not back:
        # Barra de cores e a identificação da prova, na margem de baixo.
        for i, c in enumerate(((0, 160, 220), (220, 0, 130), (250, 220, 0), (30, 30, 30))):
            x = w - m - 4 * 34 + i * 34
            d.rectangle((x, h - m + 14, x + 26, h - m + 40), fill=c)
        d.text((m + 6, h - m + 16), "KN-301  PROOF 07  A4 75g  CUT ALONG MARKS", font=font("consola.ttf", 20), fill=(110, 110, 110))
        d.ellipse((w // 2 - 12, 14, w // 2 + 12, 38), outline=mark, width=2)
        d.line((w // 2 - 20, 26, w // 2 + 20, 26), fill=mark, width=2)
        d.line((w // 2, 6, w // 2, 46), fill=mark, width=2)
    return img


def paper_normal(size=512, strength=2.0):
    """Fibra do papel: ruído suave com riscos alongados, repetível, como mapa de normal."""
    r = np.random.default_rng(11)
    hgt = r.random((size, size))
    for _ in range(3):
        hgt = (hgt + np.roll(hgt, 1, 0) + np.roll(hgt, -1, 0) + np.roll(hgt, 1, 1) + np.roll(hgt, -1, 1)) / 5
    fibers = np.zeros((size, size))
    for _ in range(900):
        x, y = r.integers(0, size, 2)
        ang = r.uniform(0, math.pi)
        for t in range(r.integers(8, 30)):
            fibers[int(y + math.sin(ang) * t) % size, int(x + math.cos(ang) * t) % size] += 1
    hgt = hgt + fibers * 0.08
    hgt = (hgt - hgt.min()) / (hgt.max() - hgt.min())
    dx = np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)
    dy = np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)
    n = np.stack([-dx * strength, dy * strength, np.ones_like(hgt)], axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB")


# --- Embalagem da resma ---------------------------------------------------------------------------
# Atlas 1024 x 1024 (as UVs ficam em scripts/items/item_kinds.gd):
#   tampa     (0, 0)-(1024, 716)    face de cima, 30 x 21 cm
#   lateral   (0, 716)-(1024, 892)  laterais compridas, 30 x 5,2 cm
#   ponta     (0, 892)-(528, 1024)  pontas dobradas, 21 x 5,2 cm
#   fundo     (528, 892)-(1024, 1024)

WRAP = (241, 240, 234)
BLUE = (28, 86, 168)
BLUE_DARK = (18, 52, 110)


def ream_wrapper():
    img = paper_base((1024, 1024), WRAP)
    d = ImageDraw.Draw(img)
    # Tampa: marca, faixa azul inclinada, informações e o selinho verde.
    d.polygon([(0, 430), (1024, 330), (1024, 520), (0, 620)], fill=BLUE)
    d.polygon([(0, 620), (1024, 520), (1024, 545), (0, 645)], fill=BLUE_DARK)
    d.text((60, 70), "OFFICE+", font=font("arialbd.ttf", 150), fill=BLUE_DARK)
    d.text((66, 240), "COPY PAPER", font=font("arial.ttf", 64), fill=(60, 60, 70))
    d.text((70, 455), "A4  ·  210 × 297 mm", font=font("arialbd.ttf", 52), fill=(255, 255, 255))
    d.text((70, 655), "500 SHEETS  ·  75 g/m²", font=font("arialbd.ttf", 40), fill=BLUE_DARK)
    d.ellipse((840, 70, 960, 190), fill=(70, 150, 70))
    d.polygon([(870, 160), (930, 95), (905, 165)], fill=(220, 240, 210))
    for i, label in enumerate(("LASER", "INKJET", "COPY")):
        y = 140 + i * 34
        d.rectangle((720 - 40, y - 18, 720 - 18, y + 4), outline=(60, 60, 70), width=3)
        d.line((720 - 37, y - 8, 720 - 29, y, 720 - 16, y - 22), fill=(40, 140, 60), width=4)
        d.text((720 - 8, y - 22), label, font=font("arial.ttf", 24), fill=(60, 60, 70))
    # Lateral comprida: faixa azul com o texto.
    d.rectangle((0, 716, 1024, 892), fill=BLUE)
    d.rectangle((0, 716, 1024, 728), fill=BLUE_DARK)
    d.text((512, 804), "OFFICE+  ·  500 SHEETS  ·  A4  ·  75 g/m²", font=font("arialbd.ttf", 46),
           fill=(255, 255, 255), anchor="mm")
    # Ponta: dobras do embrulho e a fita.
    d.rectangle((0, 892, 528, 1024), fill=WRAP)
    fold = (205, 204, 196)
    d.line((0, 892, 130, 958, 0, 1024), fill=fold, width=4)
    d.line((528, 892, 398, 958, 528, 1024), fill=fold, width=4)
    d.line((130, 958, 398, 958), fill=fold, width=3)
    d.rectangle((214, 892, 314, 1024), fill=(224, 222, 205))
    d.text((264, 958), "A4", font=font("arialbd.ttf", 40), fill=BLUE, anchor="mm")
    # Fundo: só o embrulho com a emenda.
    d.line((528, 958, 1024, 958), fill=fold, width=3)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    front, back = bill_front(), bill_back()
    front.save(os.path.join(OUT, "bill_front.png"))
    back.save(os.path.join(OUT, "bill_back.png"))
    sheet(front).save(os.path.join(OUT, "sheet_front.png"))
    sheet(back, back=True).save(os.path.join(OUT, "sheet_back.png"))
    paper_normal().save(os.path.join(OUT, "paper_normal.png"))
    ream_wrapper().save(os.path.join(OUT, "ream_wrapper.png"))
    print("texturas do papel em", OUT)


if __name__ == "__main__":
    main()
