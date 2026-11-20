"""Generates the deck "Schweiz – Allgemeinwissen".

Usage: NE_COUNTRIES=... NE_ADMIN1=... WM_CACHE=/some/dir python3 -I gen_switzerland.py
Coats of arms come from Wikimedia Commons (public domain, Swiss army flag regulation); they are cached in WM_CACHE.
"""
import json
import os
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mapkit import View, load_polys, render, save_png
from swiss_content import CANTONS, CATEGORIES, CITY_POPULATION, COAT_FILES

HERE = os.path.dirname(os.path.abspath(__file__))
DECK_ID = "schweiz-allgemeinwissen"
OUT = os.path.join(HERE, "..", "decks", DECK_ID)
from wm import CACHE, commons_info, fetch


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def cards_file(path, cards):
    write(path, "@studyCraft_List\n\n" + "\n===\n".join(cards) + "\n")


def main():
    os.makedirs(CACHE, exist_ok=True)
    for sub in os.listdir(OUT) if os.path.isdir(OUT) else []:
        if sub not in ("deck.json", "thumbnail.jpg"):
            p = os.path.join(OUT, sub)
            shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)

    # --- canton maps -------------------------------------------------------------------------
    neighbours = [
        p for p in load_polys(os.environ["NE_COUNTRIES"], lambda p: p["ISO_A2_EH"])
        if p.key in ("DE", "FR", "IT", "AT", "LI", "SI", "CZ", "HR", "ES", "MC", "SM", "LU", "BE", "NL", "HU")
    ]
    cantons = load_polys(
        os.environ["NE_ADMIN1"],
        lambda p: "CH:" + p["name_de"] if p["iso_a2"] == "CH" else None,
    )
    cantons = [c for c in cantons if c.key]
    assert len({c.key for c in cantons}) == 26, len({c.key for c in cantons})
    polys = neighbours + cantons
    have = {c.key for c in cantons}
    for row in CANTONS:
        assert 'CH:' + row[2] in have, row[2]
    fills = {c.key: (222, 214, 198) for c in cantons}  # Swiss cantons slightly darker than the neighbours
    view = View(5.85, 10.55, 45.78, 47.85, pad=1.12, min_span=1)
    lines = []
    for code, name, ne, capital, joined, residents, langs, note in CANTONS:
        img = render(view, polys, {"CH:" + ne}, fills=fills, ring_px=26, line=0.9)
        fn = f"canton-{code.lower()}.png"
        save_png(img, os.path.join(OUT, "Kantone auf der Karte", "Bilder", fn))
        lines.append(
            f"![[{fn}]]\n\n**Welcher Kanton ist markiert?**\n---\n**Kanton {name}** ({code})\n\n"
            f"Hauptort: {capital}\n\nSprache: {langs}\n\nEinwohner: ca. {residents}\n\nIn der Eidgenossenschaft seit {joined}."
        )
    cards_file(os.path.join(OUT, "Kantone auf der Karte", "Karten.md"), lines)

    # --- coats of arms -------------------------------------------------------------------------
    credits = []
    lines = []
    for code, name, ne, capital, joined, residents, langs, note in CANTONS:
        info = commons_info(COAT_FILES[code])
        lic = info["extmetadata"].get("LicenseShortName", {}).get("value", "?")
        assert lic in ("Public domain", "CC0", "CC0 1.0"), (code, lic)
        src = os.path.join(CACHE, f"coat-{code}.png")
        fetch(info["thumburl"], src)
        fn = f"wappen-{code.lower()}.png"
        dst = os.path.join(OUT, "Kantonswappen", "Bilder", fn)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy(src, dst)
        credits.append(f"- Kanton {name}: {info['descriptionurl']} ({lic})")
        lines.append(f"![[{fn}]]\n\n**Zu welchem Kanton gehört dieses Wappen?**\n---\n**Kanton {name}** ({code})\n\nHauptort: {capital}")
        time.sleep(1.5)
    cards_file(os.path.join(OUT, "Kantonswappen", "Karten.md"), lines)

    # --- capitals / abbreviations / population ----------------------------------------------------
    cards_file(
        os.path.join(OUT, "Hauptorte und Kürzel", "Karten.md"),
        [f"**Was ist der Hauptort des Kantons {n}?**\n---\n**{cap}**\n\nKürzel: {c}" for c, n, _, cap, *_ in CANTONS]
        + [f"**Welcher Kanton hat das Kürzel {c}?**\n---\n**Kanton {n}**\n\nHauptort: {cap}" for c, n, _, cap, *_ in CANTONS],
    )
    pop = [
        f"**Wie viele Einwohner hat der Kanton {n} ungefähr?**\n---\n**ca. {r}**\n\n{note}\n\n_Stand ca. 2023, gerundet._"
        for c, n, _, cap, j, r, l, note in CANTONS
    ]
    pop += [f"**Wie viele Einwohner hat die Stadt {n} ungefähr?**\n---\n**{r}**" for n, r in CITY_POPULATION]
    pop.append("**Wie viele Einwohner hat die Schweiz ungefähr?**\n---\n**Rund 9 Millionen**\n\n_Stand ca. 2023._")
    cards_file(os.path.join(OUT, "Einwohner", "Karten.md"), pop)
    joined = [
        f"**Seit wann gehört der Kanton {n} zur Eidgenossenschaft?**\n---\n**{j}**"
        for c, n, _, cap, j, r, l, note in CANTONS
    ]
    cards_file(os.path.join(OUT, "Beitritt der Kantone", "Karten.md"), joined)

    # --- text categories -----------------------------------------------------------------------------
    for category, qa in CATEGORIES.items():
        cards_file(os.path.join(OUT, category, "Karten.md"), [f"**{q}**\n---\n{a}" for q, a in qa])

    write(
        os.path.join(OUT, "Bildnachweise.md"),
        "Kantonswappen: Wikimedia Commons, gemeinfrei (Fahnenreglement der Schweizer Armee).\n\n"
        + "\n".join(credits)
        + "\n\nKarten: Natural Earth (gemeinfrei), https://www.naturalearthdata.com/\n",
    )
    total = sum(1 for _ in open(os.path.join(OUT, "Kantonswappen", "Karten.md")))
    print("done")


if __name__ == "__main__":
    main()
