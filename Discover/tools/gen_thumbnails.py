"""Draws the 16:9 thumbnails of the Discover decks (800x450 JPEG) with Pillow.

Usage: NE_COUNTRIES=... NE_ADMIN1=... python3 -I gen_thumbnails.py   (run after the deck generators)
"""
import glob
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mapkit
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from mapkit import View, load_polys, render

HERE = os.path.dirname(os.path.abspath(__file__))
DECKS = os.path.join(HERE, "..", "decks")
TW, TH = 800, 450
BOLD = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"
MONO = "/System/Library/Fonts/Menlo.ttc"


def font(path, size, index=0):
    return ImageFont.truetype(path, size, index=index)


def gradient(c1, c2, diagonal=True):
    img = Image.new("RGB", (TW, TH))
    px = img.load()
    for y in range(TH):
        for x in range(TW):
            t = ((x / TW) + (y / TH)) / 2 if diagonal else y / TH
            px[x, y] = tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))
    return img


def text_shadow(d, xy, text, f, fill, shadow=(0, 0, 0, 90), offset=3):
    x, y = xy
    d.text((x + offset, y + offset), text, font=f, fill=shadow)
    d.text((x, y), text, font=f, fill=fill)


def save(img, deck_id):
    img.convert("RGB").save(os.path.join(DECKS, deck_id, "thumbnail.jpg"), "JPEG", quality=84, optimize=True)


def world(polys, fills=None, targets=(), colors=None):
    mapkit.W, mapkit.H = TW, TH
    view = View(-168, 180, -56, 84, pad=1.0, min_span=1, aspect=TW / TH)
    return render(view, polys, set(targets), ring_if_small=False, fills=fills, line=0.5)


def capitals(polys):
    mapkit.SEA, mapkit.LAND = (22, 54, 96), (52, 104, 160)
    base = world(polys).convert("RGB")
    # soften the map and darken the left side for the title
    base = base.filter(ImageFilter.GaussianBlur(0.6))
    shade = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for x in range(TW):
        sd.line([(x, 0), (x, TH)], fill=(8, 22, 46, int(200 * max(0, 1 - x / 560))))
    base = Image.alpha_composite(base.convert("RGBA"), shade)
    d = ImageDraw.Draw(base)
    # capital pins
    pins = [(2.35, 48.85), (139.7, 35.7), (149.1, -35.3), (31.2, 30.0), (77.2, 28.6), (37.6, 55.75), (116.4, 39.9), (18.4, -33.9), (106.8, -6.2)]
    view = View(-168, 180, -56, 84, pad=1.0, min_span=1, aspect=TW / TH)
    for lon, lat in pins:
        x = (lon - view.cx) * view.kx * view.scale / mapkit.SS + TW / 2
        y = (view.cy - lat) * view.scale / mapkit.SS + TH / 2
        d.ellipse([x - 13, y - 13, x + 13, y + 13], fill=(255, 255, 255, 60))
        d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=(255, 196, 40, 255), outline=(255, 255, 255, 255), width=2)
    text_shadow(d, (44, 150), "Capitals", font(BOLD, 92), (255, 255, 255))
    text_shadow(d, (44, 255), "of the World", font(BOLD, 50), (255, 214, 102))
    save(base, "capitals-of-the-world")


def country_map(polys):
    mapkit.SEA, mapkit.LAND = (206, 226, 241), (234, 231, 224)
    mapkit.TARGET = (230, 83, 62)
    keys = {"BR", "AU", "EG", "IN", "CA"}
    img = world(polys, targets=keys).convert("RGBA")
    d = ImageDraw.Draw(img)
    # a big question mark badge
    r = 86
    cx, cy = 640, 112
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 235))
    f = font(BOLD, 130)
    w = d.textlength("?", font=f)
    d.text((cx - w / 2, cy - 80), "?", font=f, fill=(230, 83, 62))
    banner = Image.new("RGBA", (TW, 120), (255, 255, 255, 0))
    bd = ImageDraw.Draw(banner)
    for y in range(120):
        bd.line([(0, y), (TW, y)], fill=(20, 40, 70, int(215 * (y / 120) ** 1.4)))
    img.alpha_composite(banner, (0, TH - 120))
    d = ImageDraw.Draw(img)
    text_shadow(d, (36, TH - 92), "Countries on the Map", font(BOLD, 50), (255, 255, 255))
    save(img, "countries-on-the-map")


def switzerland(polys_admin1):
    img = gradient((213, 43, 30), (170, 22, 14))
    d = ImageDraw.Draw(img, "RGBA")
    # the cantons as white outlines
    mapkit.W, mapkit.H = TW, TH
    view = View(5.8, 10.6, 45.7, 47.9, pad=1.5, min_span=1, aspect=TW / TH)
    for p in polys_admin1:
        pts = view.project(mapkit.shifted(p, False))
        xy = [(x / mapkit.SS + 110, y / mapkit.SS - 5) for x, y in pts]
        if len(xy) > 2:
            d.polygon(xy, fill=(255, 255, 255, 38))
            d.line(xy + [xy[0]], fill=(255, 255, 255, 235), width=2)
    # Swiss cross
    cx, cy, a, b = 100, 90, 78, 24
    d.rounded_rectangle([cx - 56, cy - 56, cx + 56, cy + 56], radius=10, fill=(213, 43, 30, 255), outline=(255, 255, 255, 255), width=4)
    d.rectangle([cx - 8, cy - 32, cx + 8, cy + 32], fill=(255, 255, 255, 255))
    d.rectangle([cx - 32, cy - 8, cx + 32, cy + 8], fill=(255, 255, 255, 255))
    text_shadow(d, (44, 300), "Schweiz", font(BOLD, 84), (255, 255, 255), shadow=(80, 0, 0, 110))
    text_shadow(d, (46, 392), "Allgemeinwissen", font(BOLD, 34), (255, 232, 228), shadow=(80, 0, 0, 110), offset=2)
    save(img, "schweiz-allgemeinwissen")


def persons():
    files = sorted(glob.glob(os.path.join(DECKS, "famous-persons", "Bilder", "*.jpg")))
    random.Random(7).shuffle(files)
    img = gradient((53, 28, 96), (18, 12, 44))
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(40):  # confetti dots
        x, y, r = random.randint(0, TW), random.randint(0, TH), random.randint(2, 5)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, random.randint(30, 80)))
    slots = [(150, 160, 112), (330, 110, 92), (500, 175, 120), (676, 120, 96), (260, 310, 96), (430, 345, 86), (620, 320, 104), (60, 330, 70), (740, 255, 60)]
    colors = [(255, 196, 40), (255, 90, 120), (80, 200, 255), (120, 230, 150)]
    for i, (cx, cy, r) in enumerate(slots):
        if i >= len(files):
            break
        p = Image.open(files[i]).convert("RGB")
        side = min(p.size)
        top = 0  # faces are usually in the upper part
        p = p.crop(((p.width - side) // 2, top, (p.width + side) // 2, top + side)).resize((2 * r, 2 * r), Image.LANCZOS)
        mask = Image.new("L", (2 * r, 2 * r), 0)
        ImageDraw.Draw(mask).ellipse([0, 0, 2 * r - 1, 2 * r - 1], fill=255)
        d.ellipse([cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6], fill=colors[i % 4] + (255,))
        img.paste(p, (cx - r, cy - r), mask)
    banner = Image.new("RGBA", (TW, 150), (0, 0, 0, 0))
    bd = ImageDraw.Draw(banner)
    for y in range(150):
        bd.line([(0, y), (TW, y)], fill=(12, 8, 30, int(235 * (y / 150) ** 1.3)))
    img = img.convert("RGBA")
    img.alpha_composite(banner, (0, TH - 150))
    d = ImageDraw.Draw(img)
    text_shadow(d, (36, TH - 96), "Famous Persons", font(BOLD, 62), (255, 255, 255))
    save(img, "famous-persons")


def computer_science():
    img = gradient((10, 14, 28), (28, 20, 60), diagonal=True)
    d = ImageDraw.Draw(img, "RGBA")
    code = [
        [("def ", (255, 123, 114)), ("binary_search", (210, 168, 255)), ("(a, x):", (230, 237, 243))],
        [("    lo, hi = ", (230, 237, 243)), ("0", (121, 192, 255)), (", ", (230, 237, 243)), ("len", (210, 168, 255)), ("(a) - ", (230, 237, 243)), ("1", (121, 192, 255))],
        [("    ", (230, 237, 243)), ("while ", (255, 123, 114)), ("lo <= hi:", (230, 237, 243))],
        [("        mid = (lo + hi) // ", (230, 237, 243)), ("2", (121, 192, 255))],
        [("        ", (230, 237, 243)), ("if ", (255, 123, 114)), ("a[mid] == x:", (230, 237, 243))],
        [("            ", (230, 237, 243)), ("return ", (255, 123, 114)), ("mid", (230, 237, 243))],
        [("    ", (230, 237, 243)), ("return ", (255, 123, 114)), ("-1", (121, 192, 255)), ("  # O(log n)", (139, 148, 158))],
    ]
    f = font(MONO, 19)
    x0, y0 = 450, 80
    d.rounded_rectangle([x0 - 24, y0 - 24, x0 + 336, y0 + 7 * 34 + 14], radius=18, fill=(13, 17, 23, 215), outline=(255, 255, 255, 40), width=2)
    for i, c in enumerate((255, 95, 86), 0):
        pass
    for dot, col in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        d.ellipse([x0 - 8 + dot * 22, y0 - 14, x0 + 6 + dot * 22, y0], fill=col)
    for row, segments in enumerate(code):
        x = x0 - 8
        for text, col in segments:
            d.text((x, y0 + 14 + row * 34), text, font=f, fill=col)
            x += d.textlength(text, font=f)
    text_shadow(d, (36, 70), "100", font(BOLD, 150), (255, 214, 102))
    text_shadow(d, (40, 238), "Computer Science", font(BOLD, 38), (255, 255, 255))
    text_shadow(d, (40, 288), "Questions", font(BOLD, 38), (255, 255, 255))
    # difficulty bars
    for i, (label, col) in enumerate([("Easy", (48, 209, 88)), ("Medium", (255, 159, 10)), ("Hard", (255, 69, 58))]):
        x = 40 + i * 118
        d.rounded_rectangle([x, 372, x + 106, 408], radius=18, fill=col + (255,))
        f2 = font(BOLD, 20)
        w = d.textlength(label, font=f2)
        d.text((x + 53 - w / 2, 379), label, font=f2, fill=(255, 255, 255))
    save(img, "computer-science-100")


if __name__ == "__main__":
    only = set(sys.argv[1:])
    polys = None
    if not only or only & {"capitals", "map"}:
        polys = load_polys(
            os.environ["NE_COUNTRIES"], lambda p: p["ISO_A2_EH"] if p["ISO_A2_EH"] != "-99" else p["ADM0_A3"]
        )
    if not only or "capitals" in only:
        capitals(polys)
    if not only or "map" in only:
        country_map(polys)
    if not only or "ch" in only:
        cantons = [c for c in load_polys(os.environ["NE_ADMIN1"], lambda p: "CH" if p["iso_a2"] == "CH" else None) if c.key]
        switzerland(cantons)
    if not only or "persons" in only:
        persons()
    if not only or "cs" in only:
        computer_science()
