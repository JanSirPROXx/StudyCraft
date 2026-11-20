"""Generates the decks "Capitals of the World" and "Countries on the Map".

Usage: NE_COUNTRIES=/path/ne_10m_admin_0_countries.geojson python3 -I gen_geography.py
Output goes to ../decks/<deck-id>/ (existing generated files are replaced).
"""
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mapkit
from countries_data import CONTINENTS, load
from mapkit import View, bbox_of, load_polys, render, save_png

HERE = os.path.dirname(os.path.abspath(__file__))
DECKS = os.path.join(HERE, "..", "decks")

# Hand-tuned views: (lon0, lon1, lat0, lat1, wrap-around-antimeridian, padding)
OVERRIDES = {
    "KI": (171, 215, -12, 5, True, 1.2),
    "FJ": (176.5, 182, -21, -12, True, 1.5),
    "MV": (72.5, 74, -1, 7.2, False, 1.4),
    "MH": (160, 173, 4, 15, False, 1.3),
    "FM": (138, 164, 5, 10, False, 1.3),
    "PW": (131, 135, 2, 9, False, 1.4),
    "TV": (176, 180, -10, -5, False, 1.6),
    "RU": (25, 190, 40, 78, True, 1.1),
    "US": (-125, -66, 24, 50, False, 1.15),
    "NO": (4, 31, 57.5, 71.5, False, 1.3),
    "CL": (-76, -66, -56, -17, False, 1.15),
}
# Whole island / region highlighted together (keys come from Natural Earth)
EXTRA_TARGETS = {"CY": {"CYN", "CNM"}, "SO": {"SOL"}}


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def reset(deck_id):
    out = os.path.join(DECKS, deck_id)
    for sub in os.listdir(out) if os.path.isdir(out) else []:
        if sub not in ("deck.json", "thumbnail.jpg"):
            p = os.path.join(out, sub)
            shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
    os.makedirs(out, exist_ok=True)
    return out


def capitals(rows):
    out = reset("capitals-of-the-world")
    for continent in CONTINENTS:
        cards = []
        for r in sorted((r for r in rows if r["continent"] == continent), key=lambda r: r["name"]):
            back = f"**{r['capital']}**"
            if r["note"]:
                back += f"\n\n{r['note']}"
            cards.append(f"{r['flag']} **What is the capital of {r['name']}?**\n---\n{back}")
        write(os.path.join(out, continent, "Capitals.md"), "@studyCraft_List\n\n" + "\n===\n".join(cards) + "\n")


def map_quiz(rows):
    out = reset("countries-on-the-map")
    polys = load_polys(
        os.environ["NE_COUNTRIES"],
        lambda p: p["ISO_A2_EH"] if p["ISO_A2_EH"] != "-99" else p["ADM0_A3"],
    )
    by_key = {}
    for p in polys:
        by_key.setdefault(p.key, []).append(p)
    for continent in CONTINENTS:
        cards = []
        for r in sorted((r for r in rows if r["continent"] == continent), key=lambda r: r["name"]):
            code = r["iso"]
            mine = by_key[code]
            targets = {code} | EXTRA_TARGETS.get(code, set())
            if code in OVERRIDES:
                a, b, c, d, wrap, pad = OVERRIDES[code]
                view = View(a, b, c, d, wrap=wrap, pad=pad)
            else:
                bb = bbox_of(mine + [q for t in targets - {code} for q in by_key[t]])
                view = View(bb[0], bb[2], bb[1], bb[3], min_span=6)
            img = render(view, polys, targets)
            name = f"map-{code.lower()}.png"
            save_png(img, os.path.join(out, "Maps", name))
            back = f"{r['flag']} **{r['name']}**\n\nCapital: {r['capital']}"
            cards.append(f"![[{name}]]\n\n**Which country is highlighted?**\n---\n{back}")
        write(
            os.path.join(out, continent, "Map Quiz.md"),
            "@studyCraft_List\n\n" + "\n===\n".join(cards) + "\n",
        )
        print(continent, len(cards), flush=True)


if __name__ == "__main__":
    rows = load()
    capitals(rows)
    if "--no-maps" not in sys.argv:
        map_quiz(rows)
