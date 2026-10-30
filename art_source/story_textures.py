"""Texturas com texto que contam a história da kitnet: o jornal colado na janela (capa e
classificados), a tampa da caixa de pizza e o dossiê do fiscal no quadro de cortiça. Saem em
assets/textures/ e o lib.TEXTURED põe cada uma num quad.

Roda com o Python do sistema e o Pillow (como o paper_textures.py):

    python art_source/story_textures.py

Estilo de desenho: cor chapada, traço preto grosso. Os textos são em inglês, como o resto do
jogo; nomes e marcas são inventados.
"""

import os
import random

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "textures")
FONTS = "C:/Windows/Fonts"

INK = (28, 26, 30)
NEWSPRINT = (228, 220, 192)
NEWS_GRAY = (120, 116, 106)
RED = (196, 44, 34)
GREEN = (70, 200, 80)

rng = random.Random(303)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def wrap(draw, text, fnt, width):
    """Quebra `text` em linhas que cabem em `width` pixels."""
    lines, line = [], ""
    for word in text.split():
        test = (line + " " + word).strip()
        if draw.textlength(test, font=fnt) <= width:
            line = test
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def paragraph(draw, xy, text, fnt, width, fill, spacing=4, max_y=None):
    """Escreve um parágrafo quebrado; devolve o y logo abaixo dele."""
    x, y = xy
    height = fnt.size + spacing
    for line in wrap(draw, text, fnt, width):
        if max_y is not None and y + height > max_y:
            break
        draw.text((x, y), line, font=fnt, fill=fill)
        y += height
    return y


def newsprint(size):
    img = Image.new("RGB", size, NEWSPRINT)
    d = ImageDraw.Draw(img)
    w, h = size
    d.rectangle((0, 0, w - 1, h - 1), outline=NEWS_GRAY, width=6)
    return img, d


FILLER = ("City officials say the situation is under control. Residents disagree. "
          "Shop owners report bills that feel slightly damp and smell of fresh ink. "
          "The mayor urged calm and asked everyone to check their change twice. "
          "Experts note the notes are almost perfect, except for the capybara. ")


def newspaper_front():
    """Capa do jornal: manchete das notas falsas, foto e colunas."""
    w, h = 512, 672
    img, d = newsprint((w, h))
    m = 22
    d.text((w // 2, 52), "THE DAILY RUMOR", font=font("georgiab.ttf", 43), fill=INK, anchor="mm")
    d.line((m, 84, w - m, 84), fill=INK, width=4)
    d.text((m, 90), "VOL. 301", font=font("georgia.ttf", 15), fill=INK)
    d.text((w // 2, 98), "LATE EDITION", font=font("georgiab.ttf", 15), fill=INK, anchor="mm")
    d.text((w - m, 90), "25¢", font=font("georgia.ttf", 15), fill=INK, anchor="ra")
    d.line((m, 110, w - m, 110), fill=INK, width=2)
    d.text((w // 2, 160), "FAKE BILLS", font=font("impact.ttf", 78), fill=INK, anchor="mm")
    d.text((w // 2, 236), "FLOOD CITY", font=font("impact.ttf", 78), fill=INK, anchor="mm")
    y = paragraph(d, (m, 282), "Police baffled: \"They still smell like fresh ink\"",
                  font("georgiai.ttf", 21), w - 2 * m, INK)
    # Foto: um maço de notas em tons de cinza, com o "100" e a capivara, e a legenda.
    px0, py0, px1, py1 = m, y + 10, 300, y + 200
    d.rectangle((px0, py0, px1, py1), fill=(170, 165, 150), outline=INK, width=3)
    for i, (dx, dy) in enumerate(((0, 0), (14, -12), (28, -24))):
        bx0, by0 = px0 + 40 + dx, py0 + 70 + dy
        d.rectangle((bx0, by0, bx0 + 190, by0 + 86), fill=(205, 200, 185), outline=INK, width=3)
    d.text((bx0 + 140, by0 + 44), "100", font=font("georgiab.ttf", 34), fill=INK, anchor="mm")
    d.ellipse((bx0 + 20, by0 + 18, bx0 + 72, by0 + 68), fill=(150, 145, 130), outline=INK, width=3)
    d.ellipse((bx0 + 30, by0 + 30, bx0 + 38, by0 + 38), fill=INK)
    paragraph(d, (px0, py1 + 6), "Bills found in a laundromat on 3rd St.", font("georgiai.ttf", 14),
              px1 - px0, INK)
    # Colunas de texto ao lado da foto e embaixo.
    body = font("georgia.ttf", 14)
    paragraph(d, (316, py0), FILLER * 2, body, w - m - 316, INK, spacing=3, max_y=py1 + 30)
    y = py1 + 36
    d.line((m, y, w - m, y), fill=INK, width=2)
    d.text((m, y + 10), "INSPECTOR TO VISIT EVERY APARTMENT", font=font("georgiab.ttf", 20), fill=INK)
    col = (w - 2 * m - 16) // 2
    for i in range(2):
        paragraph(d, (m + i * (col + 16), y + 42), (FILLER if i else
                  "A building inspector will knock on every door this week. \"If you have nothing "
                  "to hide, you have nothing to fear,\" he said, holding a clipboard. ") + FILLER,
                  body, col, INK, spacing=3, max_y=h - 16)
    return img


def newspaper_classifieds():
    """Página de classificados: anúncios em caixinhas."""
    w, h = 512, 672
    img, d = newsprint((w, h))
    m = 18
    d.text((w // 2, 40), "CLASSIFIEDS", font=font("impact.ttf", 50), fill=INK, anchor="mm")
    d.line((m, 72, w - m, 72), fill=INK, width=3)
    d.text((w // 2, 86), "THE DAILY RUMOR  ·  PAGE 12", font=font("georgia.ttf", 14), fill=INK, anchor="mm")
    ads = [
        ("ROOM FOR RENT", "Cozy kitnet, 35 m². No questions asked. Cash only."),
        ("PRINTER FOR SALE", "Barely used. Smells like money. Needs tape."),
        ("LOST: CAPYBARA", "Answers to 'Benjamin'. Very calm. Reward!"),
        ("GREEN INK WANTED", "Any amount, any time. Call 555-0301."),
        ("HELP WANTED", "Night shift. Must not ask what we print."),
        ("ZÉ'S PIZZA 2x1", "Hot, fast and we don't look inside."),
        ("HOROSCOPE", "Today, do not open the door. Tomorrow neither."),
        ("FOR SALE", "Paper guillotine. Very sharp. Slightly green."),
    ]
    col = (w - 2 * m - 12) // 2
    title, body = font("arialbd.ttf", 19), font("georgia.ttf", 15)
    ys = [104, 104]
    for i, (head, text) in enumerate(ads):
        c = i % 2
        x0, y0 = m + c * (col + 12), ys[c]
        lines = wrap(d, text, body, col - 20)
        y1 = y0 + 36 + len(lines) * 19 + 8 + rng.randint(0, 24)
        d.rectangle((x0, y0, x0 + col, y1), outline=INK, width=3)
        d.text((x0 + 10, y0 + 8), head, font=title, fill=INK)
        paragraph(d, (x0 + 10, y0 + 36), text, body, col - 20, INK, spacing=4)
        ys[c] = y1 + 12
    return img


def pizza_lid():
    """Tampa da caixa de pizza da Zé's: faixa vermelha, fatia desenhada e o telefone."""
    s = 512
    img = Image.new("RGB", (s, s), (226, 192, 132))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, s - 1, s - 1), outline=(150, 110, 60), width=10)
    d.rectangle((24, 34, s - 24, 140), fill=RED, outline=INK, width=6)
    d.text((s // 2, 88), "ZÉ'S PIZZA", font=font("impact.ttf", 84), fill=(255, 245, 225), anchor="mm",
           stroke_width=4, stroke_fill=INK)
    # Fatia com borda grossa, queijo e pepperoni.
    tip, left, right = (s // 2, 430), (140, 190), (372, 190)
    d.polygon((tip, left, right), fill=(250, 196, 60), outline=INK, width=7)
    d.rounded_rectangle((126, 168, 386, 206), radius=18, fill=(200, 120, 50), outline=INK, width=6)
    for (cx, cy, r) in ((256, 250, 22), (212, 236, 16), (300, 238, 17), (240, 312, 16), (276, 360, 12)):
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(196, 50, 36), outline=INK, width=4)
    # Gotas de queijo pingando.
    for x, length in ((190, 40), (330, 30)):
        d.line((x, 210, x, 210 + length), fill=(250, 196, 60), width=12)
        d.ellipse((x - 8, 202 + length, x + 8, 218 + length), fill=(250, 196, 60))
    d.text((s // 2, 462), "HOT · FAST · NO QUESTIONS", font=font("arialbd.ttf", 26), fill=INK, anchor="mm")
    d.text((s // 2, 492), "CALL 555-0301", font=font("arialbd.ttf", 22), fill=RED, anchor="mm")
    return img


def dossier():
    """Ficha do fiscal no quadro do plano: foto com círculo vermelho e anotações à mão."""
    w, h = 512, 424
    img = Image.new("RGB", (w, h), (246, 240, 222))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w - 1, h - 1), outline=(170, 160, 140), width=6)
    d.text((24, 18), "SUSPECT FILE #1", font=font("courbd.ttf", 30), fill=INK)
    d.line((24, 56, w - 24, 56), fill=INK, width=3)
    # Foto do fiscal (polaroide): careca com topete penteado de lado, óculos quadrados, bigodinho,
    # gravata e a prancheta.
    fx0, fy0, fx1, fy1 = 24, 72, 224, 300
    d.rectangle((fx0, fy0, fx1, fy1), fill=(250, 250, 246), outline=INK, width=4)
    d.rectangle((fx0 + 12, fy0 + 12, fx1 - 12, fy1 - 44), fill=(150, 175, 190))
    cx = (fx0 + fx1) // 2
    d.rectangle((cx - 70, 210, cx + 70, fy1 - 44), fill=(110, 110, 120), outline=INK, width=4)
    d.polygon(((cx - 10, 212), (cx + 10, 212), (cx + 14, 250), (cx, 262), (cx - 14, 250)),
              fill=RED, outline=INK, width=3)
    d.ellipse((cx - 56, 100, cx + 56, 222), fill=(238, 196, 160), outline=INK, width=5)
    d.chord((cx - 56, 92, cx + 50, 150), 190, 350, fill=(80, 70, 60), outline=INK, width=4)
    for ex in (cx - 26, cx + 26):
        d.rectangle((ex - 20, 146, ex + 20, 172), fill=(220, 236, 240), outline=INK, width=5)
        d.ellipse((ex - 5, 154, ex + 5, 164), fill=INK)
    d.line((cx - 6, 158, cx + 6, 158), fill=INK, width=5)
    d.line((cx - 36, 138, cx - 12, 142), fill=INK, width=6)
    d.line((cx + 12, 142, cx + 36, 138), fill=INK, width=6)
    d.rectangle((cx - 18, 186, cx + 18, 194), fill=(60, 50, 45))
    d.arc((cx - 16, 196, cx + 16, 214), 200, 340, fill=INK, width=4)
    d.text((cx, fy1 - 22), "the inspector", font=font("segoepr.ttf", 20), fill=INK, anchor="mm")
    d.ellipse((fx0 - 6, fy0 + 4, fx1 + 6, fy1 - 30), outline=RED, width=7)
    # Anotações.
    hand = font("Inkfree.ttf", 26)
    notes = [("Knocks 3 times.", INK), ("Hates noise", INK), ("& the smell of ink.", INK),
             ("Comes on", INK), ("Thursdays??", INK)]
    y = 82
    for text, color in notes:
        d.text((246, y), text, font=hand, fill=color)
        y += 36
    d.text((246, y + 8), "NEVER", font=font("segoeprb.ttf", 40), fill=RED)
    d.text((246, y + 58), "open the door!!", font=font("segoeprb.ttf", 26), fill=RED)
    d.line((246, y + 56, 400, y + 52), fill=RED, width=5)
    # Clipe de papel no canto.
    d.rounded_rectangle((w - 70, -20, w - 40, 70), radius=14, outline=(120, 120, 130), width=6)
    d.rounded_rectangle((w - 62, -10, w - 48, 52), radius=7, outline=(120, 120, 130), width=5)
    return img


def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path)
    print("salvo:", path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save(newspaper_front(), "newspaper_front.png")
    save(newspaper_classifieds(), "newspaper_classifieds.png")
    save(pizza_lid(), "pizza_lid.png")
    save(dossier(), "dossier.png")
