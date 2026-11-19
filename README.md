# StudyCraft

Ein minimalistischer Anki-Klon für iPhone und iPad, der mit deinen eigenen Markdown-Dateien lernt.
Swift / SwiftUI, iOS 17+, Design nach NotesCraft (Classic-Palette, Hell/Dunkel, System-Schrift).

## Lernordner

Beim ersten Start wählst du einen Ordner in Dateien (zum Beispiel in iCloud Drive). Die App merkt ihn sich
über ein Security-Scoped-Bookmark; in den Einstellungen lässt er sich wechseln.

- Jeder **Unterordner** mit Karten wird ein **Deck**, verschachtelte Ordner werden Unterdecks.
  Ordner ohne Karten (zum Beispiel `bilder/`) erscheinen nicht. Karten direkt im Lernordner landen im Deck „Allgemein".
- Jede `.md`-Datei mit Kennung in der ersten Zeile liefert Karten. Dateien ohne Kennung werden ignoriert.
- Änderungen am Mac (neue, geänderte, gelöschte Dateien) erkennt die App von selbst: über `NSFilePresenter`,
  `NSMetadataQuery`, ein Neu-Einlesen alle 10 Sekunden und beim Zurückkehren in die App (Pull-to-refresh geht auch).

## Kartenformat

````markdown
@studyCraft_List

# Hauptstadt von Frankreich?
---
**Paris**
===
Was macht dieser Code?

```swift
let x = [1, 2, 3].map { $0 * 2 }
```
---
Er verdoppelt jedes Element:

- Ergebnis: `[2, 4, 6]`
````

| Element | Bedeutung |
|---|---|
| `@studyCraft` (erste Zeile) | die Datei ist **eine** Karte |
| `@studyCraft_List` (erste Zeile) | die Datei enthält **mehrere** Karten |
| `---` | trennt Vorderseite und Rückseite |
| `===` | trennt Karten innerhalb einer Datei |

Trennlinien in Code-Blöcken (```` ``` ```` / `~~~`) zählen nicht. Unterstützt werden Überschriften, **fett**, *kursiv*,
`Code`, Links, Listen (auch verschachtelt und Aufgabenlisten), Zitate, Tabellen, Code-Blöcke und Bilder aus demselben
Ordner: `![Text](bild.png)` oder `![[bild.png]]` (Obsidian-Stil, auch nur über den Dateinamen).
HTML-Kommentare werden ausgeblendet.

**Wie Karten wiedererkannt werden:** In `@studyCraft`-Dateien identifiziert der Dateipfad die Karte, in
`@studyCraft_List`-Dateien der Inhalt der Vorderseite (Leerraum egal). Umsortieren, Einfügen und Ändern der Rückseite
behalten den Lernstand; wer die Vorderseite ändert oder eine Datei verschiebt, beginnt für diese Karte neu.

## Lernen

Klassischer Anki-Algorithmus (SM-2, „v2"-Scheduler): Lernschritte 1 Min und 10 Min, danach 1 Tag (Einfach: 4 Tage),
Startleichtigkeit 250 %, Schwer ×1,2 (−15 %), Gut ×Leichtigkeit, Einfach ×Leichtigkeit ×1,3 (+15 %), Vergessen führt in
den Wiederholungsschritt (10 Min) und senkt die Leichtigkeit um 20 % (mindestens 130 %). Überfällige Karten bekommen
Bonus-Tage. Ein Lerntag endet um 4 Uhr morgens.

Eine Sitzung geht das ganze Deck (samt Unterdecks) einmal durch, ohne Tageslimit. Oben rechts wählst du die Reihenfolge:

- **Mischen** (`shuffle`): jede Karte genau einmal, zufällig, aber ohne Häufungen: Karten, die in der Datei nebeneinander
  stehen, werden getrennt, und die erste Karte ist nie die zuletzt gelernte.
- **Der Reihe nach** (`list.number`): so, wie es in den Dateien steht.
- **Nur neue** (`sparkles`): nur Karten, die noch nie beantwortet wurden.

„Nochmal" bringt die Karte nach 4–7 anderen Karten noch einmal; jede andere Antwort schließt sie für die Sitzung ab.
Der Pfeil neben dem X nimmt die letzte Antwort zurück (Lernstand und Statistik inklusive).

Bewerten per Wischen: Karte nach **rechts** ziehen = Gut, Finger noch ~0,85 s halten = **Einfach** (mit sich
aufbauenden Vibrationen, einem Schlag und Funken). Nach **links** = Schwer, halten = Nochmal, ohne Vibration. Ein schneller
Wisch zählt als erste Stufe (Gut/Schwer). Die Karte fliegt in Wischrichtung hinaus. Die vier Buttons nach dem Umdrehen
(Tippen auf die Karte oder „Antwort zeigen") funktionieren weiterhin und zeigen den Abstand bis zum nächsten Mal.

- Tastatur (iPad): Leertaste = Antwort zeigen, 1–4 = Bewertung, ⌘Z = zurück, Esc = beenden.
- Auf dem Startbildschirm steht neben jedem Deck blau die Zahl neuer, grün die Zahl fälliger Karten.

## Decks und Karten bearbeiten

Auf dem Startbildschirm: nach links wischen oder lange drücken bei einem Deck → **Bearbeiten** (Kartenliste),
**Umbenennen** (der Ordner wird umbenannt, der Lernstand zieht mit) und **Löschen** (der Ordner wird gelöscht, vorher
Rückfrage). In der Kartenliste: **+** fügt eine Karte hinzu (sie wird an die erste Listen-Datei des Decks angehängt oder in
einer neuen `Karten.md` angelegt), Tippen bearbeitet, Wischen blendet aus oder löscht. Alles geschieht direkt in den
`.md`-Dateien; was nicht angefasst wird, bleibt unverändert. Ausgeblendete Karten tragen die Zeile `<!-- hidden -->`,
werden nicht gelernt und nicht gezählt. Im Karteneditor lassen sich Bilder aus den Fotos einfügen: sie werden verkleinert
im Ordner des Decks abgelegt und als `![[Bild-….jpg]]` eingebaut.

## Fortschritt und iCloud-Sync

Der Lernstand liegt **im Lernordner**, in `_StudyCraft/progress-<Geräte-ID>.json`, und wird so von iCloud Drive mit
allen Geräten synchronisiert, ohne iCloud-Entitlement. Jedes Gerät schreibt nur seine eigene Datei und liest die der
anderen; pro Karte gewinnt die jüngste Antwort, das Tagesprotokoll (für Statistik und Serie) ist die Summe aller
Geräte. So gibt es keine Schreibkonflikte. Der Ordner `_StudyCraft` ist absichtlich nicht versteckt, weil iCloud Drive
Dateien mit Punkt-Präfix nicht synchronisiert.

## Entwickeln

```bash
brew install xcodegen          # einmalig
cp Config/Local.xcconfig.example Config/Local.xcconfig   # DEVELOPMENT_TEAM eintragen
xcodegen generate
xcodebuild -project StudyCraft.xcodeproj -scheme StudyCraft \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Debug-Builds nehmen `-StudyCraftRoot /absoluter/pfad` als Lernordner, ohne den Dateien-Dialog (nützlich für Tests im
Simulator).

```
Sources/StudyCraft
  Core/     Format und Logik ohne UI: CardParser, MarkdownParser, Scheduler, Progress, StudyClock
  Model/    AppModel (Zustand), FolderScanner/-Watcher, StudySession, Deck
  Views/    Decks, Lernansicht, Statistik, Einstellungen, Markdown-Darstellung
  Support/  Theme, Beispiel-Deck
Tests/StudyCraftTests   Parser, Scheduler, Fortschritts-Zusammenführung, Scanner
```
