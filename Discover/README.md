# Discover: Decks für den Tab „Entdecken“

Alles in diesem Ordner liegt im öffentlichen Repository, und die App lädt es von dort
(`https://raw.githubusercontent.com/JanSirPROXx/StudyCraft/main/Discover/…`). Wer in der App ein Deck lädt, bekommt einen
normalen Ordner mit Markdown-Dateien und Bildern in seinem Lernordner. Ein neues Deck erscheint, sobald es auf `main` liegt;
die App muss dafür nicht neu veröffentlicht werden.

```
Discover/
  catalog.json            erzeugt von tools/build_catalog.py, das liest die App
  decks/<deck-id>/
    deck.json             Titel, Untertitel, Beschreibung, Sprache, Tags, Ordnername, Reihenfolge
    thumbnail.jpg         Vorschaubild 16:9 (800 × 450), wird nicht ins Deck kopiert
    <Unterdeck>/*.md      Karten, genau wie im Lernordner (Unterordner = Unterdecks)
    Bilder/*.png|jpg      Bilder, in den Karten als ![[datei.png]] eingebunden
  tools/                  Skripte, die die mitgelieferten Decks erzeugen
```

## Ein neues Deck hinzufügen

1. Ordner `decks/<deck-id>/` anlegen (`deck-id` nur aus a–z, 0–9 und „-“).
2. Karten als Markdown-Dateien ablegen (Format siehe [README](../README.md)). Bilder bekommen **eindeutige Dateinamen**
   (zum Beispiel `map-ch.png`), weil die App sie im Lernordner über den Dateinamen findet.
3. `deck.json` schreiben:

   ```json
   {
     "order": 6,
     "title": "Mein Deck",
     "subtitle": "Eine Zeile",
     "description": "Ein bis drei Sätze.",
     "language": "de",
     "tags": ["Thema"],
     "folderName": "Mein Deck",
     "revision": 1,
     "thumbnail": "thumbnail.jpg"
   }
   ```
4. Ein Vorschaubild `thumbnail.jpg` (16:9) in den Deck-Ordner legen.
5. Den Katalog neu erzeugen und prüfen:

   ```bash
   python3 -I Discover/tools/build_catalog.py
   ```

   Das Skript listet alle Dateien, zählt die Karten, prüft alle `![[bild]]`-Verweise und schreibt `catalog.json`.
6. Lokal in der App testen, bevor es hochgeladen wird (Debug-Build):

   ```
   -StudyCraftRoot <leerer Ordner> -StudyCraftDiscoverBase file:///…/StudyCraft/Discover/
   ```

Erlaubt sind nur Markdown-Dateien und Bilder (`png`, `jpg`, `jpeg`, `gif`, `webp`, `heic`). Die App lehnt Katalogeinträge mit
unsicheren Pfaden (`..`, absolute Pfade, versteckte Dateien) oder anderen Dateitypen ab.

## Lizenzen und Quellen

- Karten und Texte wurden für StudyCraft verfasst.
- Landkarten sind aus [Natural Earth](https://www.naturalearthdata.com/) gezeichnet (gemeinfrei).
- Kantonswappen und Porträts stammen von Wikimedia Commons. Es werden nur gemeinfreie Bilder und solche unter
  Creative-Commons-Lizenzen (CC0, CC BY, CC BY-SA) verwendet; Urheber und Lizenz stehen im Deck in `Credits.md` bzw.
  `Bildnachweise.md` und auf den Karten.

## Werkzeuge

`tools/` enthält die Skripte, die die mitgelieferten Decks erzeugt haben (Python 3 mit Pillow und numpy):

| Skript | Erzeugt |
|---|---|
| `gen_geography.py` | Capitals of the World, Countries on the Map (Karten aus Natural Earth, `ne_10m_admin_0_countries.geojson`) |
| `gen_switzerland.py` | Schweiz – Allgemeinwissen (Kantonskarten aus `ne_10m_admin_1_states_provinces.geojson`, Wappen von Wikimedia) |
| `gen_persons.py` | Famous Persons (Wikipedia-Titelbilder mit Lizenzprüfung) |
| `gen_cs.py` | 100 Computer Science Questions |
| `gen_thumbnails.py` | Vorschaubilder |
| `build_catalog.py` | `catalog.json` |

Die Natural-Earth-Dateien liegen nicht im Repository; die Skripte lesen sie über die Umgebungsvariablen `NE_COUNTRIES` und
`NE_ADMIN1`. Bilder von Wikimedia werden in `WM_CACHE` zwischengespeichert.
