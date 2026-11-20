"""Generates the deck "Famous Persons" from Wikipedia lead images with an acceptable licence.

Usage: WM_CACHE=/some/dir python3 -I gen_persons.py
Only images that Wikimedia Commons lists as public domain, CC0, CC BY or CC BY-SA are used; the credit is
written onto the answer side and into Credits.md.
"""
import io
import os
import re
import shutil
import sys
import time
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from persons_data import ART, PERSONS, POL, SCI, SPO
from wm import CACHE, clean, commons_info, fetch, get_json

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "decks", "famous-persons")
OK = re.compile(r"^(public domain|pd[- ]|cc0|cc[- ]by|attribution|no restrictions)", re.I)


def lead_image(title):
    data = get_json(
        "https://en.wikipedia.org/api/rest_v1/page/summary/" + urllib.parse.quote(title, safe=""),
        "wp-" + urllib.parse.quote(title, safe="") + ".json",
    )
    img = data.get("originalimage") or data.get("thumbnail")
    if not img:
        return None
    url = img["source"].split("?")[0]
    if "/wikipedia/commons/" not in url:  # local (often non-free) file on en.wikipedia
        return None
    parts = url.split("/")
    name = parts[-2] if "/thumb/" in url else parts[-1]
    return urllib.parse.unquote(name)


def main():
    for sub in os.listdir(OUT) if os.path.isdir(OUT) else []:
        if sub not in ("deck.json", "thumbnail.jpg"):
            p = os.path.join(OUT, sub)
            shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
    by_cat = {c: [] for c in (SCI, POL, ART, SPO)}
    credits = []
    skipped = []
    for title, name, years, cat, blurb in PERSONS:
        try:
            file = lead_image(title)
            if not file:
                skipped.append((name, "no free lead image"))
                continue
            info = commons_info(file, 500)
            lic = info["extmetadata"].get("LicenseShortName", {}).get("value", "")
            if not OK.match(lic):
                skipped.append((name, f"licence {lic!r}"))
                continue
            raw = os.path.join(CACHE, "img-" + urllib.parse.quote(file, safe="")[:150])
            fetch(info.get("thumburl") or info["url"], raw)
            time.sleep(1.2)
        except Exception as e:  # keep going; one missing portrait must not stop the deck
            skipped.append((name, f"error {e}"))
            continue
        slug = re.sub(r"[^a-z0-9]+", "-", name.lower().replace("é", "e").replace("í", "i")).strip("-")
        fn = f"person-{slug}.jpg"
        im = Image.open(raw).convert("RGB")
        im.thumbnail((560, 560), Image.LANCZOS)
        dst = os.path.join(OUT, "Bilder", fn)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        im.save(dst, "JPEG", quality=82, optimize=True, progressive=True)
        artist = clean(info["extmetadata"].get("Artist", {}).get("value", ""))
        pd = lic.lower().startswith(("public domain", "pd", "cc0"))
        credit = f"Photo: {artist + ', ' if artist and not pd else ''}{lic}, via Wikimedia Commons"
        credits.append(f"- {name}: {info['descriptionurl']} ({lic}{', ' + artist if artist else ''})")
        card = (
            f"![[{fn}]]\n\n**Who is this?**\n---\n**{name}** ({years})\n\n{blurb}\n\n_{credit}_"
        )
        by_cat[cat].append(card)
    for cat, cards in by_cat.items():
        if not cards:
            continue
        os.makedirs(os.path.join(OUT, cat), exist_ok=True)
        with open(os.path.join(OUT, cat, "Portraits.md"), "w", encoding="utf-8") as f:
            f.write("@studyCraft_List\n\n" + "\n===\n".join(cards) + "\n")
    with open(os.path.join(OUT, "Credits.md"), "w", encoding="utf-8") as f:
        f.write("Photos from Wikimedia Commons (public domain or Creative Commons licences):\n\n" + "\n".join(credits) + "\n")
    print({c: len(v) for c, v in by_cat.items()}, "skipped:", len(skipped))
    for s in skipped:
        print("  skipped", s)


if __name__ == "__main__":
    main()
