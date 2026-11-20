"""Builds ../catalog.json from the deck folders in ../decks.

Every deck folder has a deck.json (title, subtitle, description, language, tags, folderName, revision,
thumbnail, order), a thumbnail and the deck content (Markdown files and images). This script lists the files,
counts the cards, checks that every image reference resolves and writes the catalog the app downloads.

Usage: python3 -I build_catalog.py
"""
import datetime
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
DECKS = os.path.join(ROOT, "decks")
ALLOWED = {".md", ".markdown", ".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic"}
SKIP = {"deck.json"}


def is_fence(line):
    return line.startswith("```") or line.startswith("~~~")


def is_rule(line, ch):
    return len(line) >= 3 and set(line) == {ch}


def count_cards(text):
    """Port of CardParser (see Sources/StudyCraft/Core/CardParser.swift)."""
    lines = text.replace("\r\n", "\n").split("\n")
    if lines[0].strip().lower() not in ("@studycraft", "@studycraft_list"):
        return 0
    chunks, fence = [[]], None
    for line in lines[1:]:
        t = line.strip()
        if is_fence(t):
            fence = None if fence == t[:3] else (fence or t[:3])
        elif fence is None and is_rule(t, "="):
            chunks.append([])
            continue
        chunks[-1].append(line)
    cards = 0
    for chunk in chunks:
        front, back, in_back, fence = [], [], False, None
        for line in chunk:
            t = line.strip()
            if is_fence(t):
                fence = None if fence == t[:3] else (fence or t[:3])
            elif fence is None and not in_back and is_rule(t, "-"):
                in_back = True
                continue
            (back if in_back else front).append(line)
        if in_back and "".join(front).strip() and "".join(back).strip():
            cards += 1
    return cards


def main():
    decks, errors = [], []
    for deck_id in sorted(os.listdir(DECKS)):
        base = os.path.join(DECKS, deck_id)
        meta_path = os.path.join(base, "deck.json")
        if not os.path.isfile(meta_path):
            continue
        meta = json.load(open(meta_path, encoding="utf-8"))
        files, size, cards = [], 0, 0
        names = set()
        for dirpath, _, filenames in os.walk(base):
            for name in sorted(filenames):
                rel = os.path.relpath(os.path.join(dirpath, name), base).replace(os.sep, "/")
                if rel in SKIP or rel == meta.get("thumbnail") or name.startswith("."):
                    continue
                if os.path.splitext(name)[1].lower() not in ALLOWED:
                    errors.append(f"{deck_id}: unsupported file {rel}")
                    continue
                files.append(rel)
                names.add(name.lower())
                size += os.path.getsize(os.path.join(base, rel))
        files.sort()
        for rel in files:
            if rel.lower().endswith((".md", ".markdown")):
                text = open(os.path.join(base, rel), encoding="utf-8").read()
                cards += count_cards(text)
                for ref in re.findall(r"!\[\[([^\]]+)\]\]", text):
                    if ref.lower() not in names:
                        errors.append(f"{deck_id}: {rel} references missing image {ref}")
        thumb = meta.get("thumbnail")
        if thumb and os.path.isfile(os.path.join(base, thumb)):
            size_thumb = os.path.getsize(os.path.join(base, thumb))
        else:
            thumb = None
            errors.append(f"{deck_id}: thumbnail missing")
        decks.append(
            dict(
                order=meta.get("order", 99),
                entry=dict(
                    id=deck_id, title=meta["title"], subtitle=meta["subtitle"],
                    description=meta["description"], language=meta["language"], tags=meta["tags"],
                    cardCount=cards, thumbnail=thumb, folderName=meta["folderName"],
                    revision=meta.get("revision", 1), size=size, files=files,
                ),
            )
        )
    decks.sort(key=lambda d: (d["order"], d["entry"]["id"]))
    catalog = dict(version=1, updated=datetime.date.today().isoformat(), decks=[d["entry"] for d in decks])
    with open(os.path.join(ROOT, "catalog.json"), "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=1)
        f.write("\n")
    for d in decks:
        e = d["entry"]
        print(f"{e['id']:28} {e['cardCount']:4} cards {len(e['files']):4} files {e['size'] / 1e6:6.2f} MB")
    for e in errors:
        print("ERROR", e)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
