# StudyCraft

Karteikarten für iPhone und iPad, die du einfach als Markdown-Dateien schreibst. StudyCraft plant die
Wiederholungen, lässt dich per Wischen bewerten und bringt fertige Decks zum Entdecken mit.
Swift / SwiftUI, iOS 17+, Hell/Dunkel, System-Schrift.

- **Deine Dateien, deine Kontrolle:** Ein Ordner in Dateien oder iCloud Drive ist dein Lernordner, jeder Unterordner ein Deck.
- **Entdecken:** fertige Decks zum Herunterladen (Hauptstädte, Länderkarten, Schweiz, berühmte Personen, Informatik).
- **Wischen statt tippen:** nach rechts Gut, halten für Einfach, nach links Schwer oder Nochmal.
- **Optional:** der Ultra-Dopamin-Modus mit Schatztruhe, Konfetti und Jackpot-Sound.
- **Kein Konto, keine Werbung, keine Tracker.** Der Lernstand synchronisiert sich über iCloud Drive.

## Entdecken

Der Tab zwischen „Decks“ und „Statistik“ zeigt fertige Decks mit Vorschaubild, Beschreibung und Kartenzahl.
Man kann nach Sprache filtern und suchen; „Laden“ kopiert das Deck in den Lernordner, danach ist es ein ganz
normales Deck, das sich bearbeiten lässt.

Die Decks liegen im öffentlichen GitHub-Repository dieser App im Ordner [`Discover/`](Discover/README.md), und die App holt sie
von dort. Neue Decks kommen per Pull Request dazu, ohne dass die App neu veröffentlicht werden muss. Wie ein
Deck aufgebaut ist und wie man den Katalog neu erzeugt, steht in [`Discover/README.md`](Discover/README.md).

| Deck | Sprache | Karten | Inhalt |
|---|---|---|---|
| Capitals of the World | Englisch | 194 | Land → Hauptstadt, nach Kontinenten |
| Countries on the Map | Englisch | 194 | Leere Karte, ein Land ist markiert: Name nennen |
| Schweiz – Allgemeinwissen | Deutsch | 344 | Kantonskarten, Wappen, Hauptorte, Einwohner, Geschichte, Politik, Geografie, Personen, Brauchtum, Essen, Rekorde |
| Famous Persons | Englisch | 78 | Foto → Name, mit Lebensdaten und Kurzbeschreibung |
| 100 Computer Science Questions | Englisch | 100 | von leicht bis schwer |

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

Die Wiederholungsplanung folgt dem bewährten SM-2-Prinzip mit Lernschritten: 1 Min und 10 Min, danach 1 Tag
(Einfach: 4 Tage), Startleichtigkeit 250 %, Schwer ×1,2 (−15 %), Gut ×Leichtigkeit, Einfach ×Leichtigkeit ×1,3 (+15 %),
Vergessen führt in den Wiederholungsschritt (10 Min) und senkt die Leichtigkeit um 20 % (mindestens 130 %).
Überfällige Karten bekommen Bonus-Tage. Ein Lerntag endet um 4 Uhr morgens.

Eine Sitzung geht das ganze Deck (samt Unterdecks) einmal durch, ohne Tageslimit. Oben rechts wählst du die Reihenfolge:

- **Mischen** (`shuffle`): jede Karte genau einmal, zufällig, aber ohne Häufungen: Karten, die in der Datei nebeneinander
  stehen, werden getrennt, und die erste Karte ist nie die zuletzt gelernte.
- **Der Reihe nach** (`list.number`): so, wie es in den Dateien steht.
- **Nur neue** (`sparkles`): nur Karten, die noch nie beantwortet wurden.

„Nochmal" bringt die Karte nach 4–7 anderen Karten noch einmal; jede andere Antwort schließt sie für die Sitzung ab.
Der Pfeil neben dem X nimmt die letzte Antwort zurück (Lernstand und Statistik inklusive).

**Die Sitzung wird gespeichert.** Wer ein Deck mittendrin schließt, macht beim nächsten Öffnen genau dort weiter:
dieselbe Reihenfolge, derselbe Fortschrittsbalken. Erst wenn alle Karten durch sind, beginnt die nächste Sitzung von vorn.
„Noch einmal durchgehen" am Ende startet das Deck sofort neu (aus „Nur neue" wird dabei „Mischen").

Bewerten per Wischen: Karte nach **rechts** ziehen = Gut, Finger noch ~0,85 s halten = **Einfach** (mit sich
aufbauenden Vibrationen, einem Schlag und Funken). Nach **links** = Schwer, halten = Nochmal, ohne Vibration. Ein schneller
Wisch zählt als erste Stufe (Gut/Schwer). Die Karte fliegt in Wischrichtung hinaus. Die vier Buttons nach dem Umdrehen
(Tippen auf die Karte oder „Antwort zeigen") funktionieren weiterhin und zeigen den Abstand bis zum nächsten Mal.

- Tastatur (iPad): Leertaste = Antwort zeigen, 1–4 = Bewertung, ⌘Z = zurück, Esc = beenden.
- Auf dem Startbildschirm steht neben jedem Deck blau die Zahl neuer, grün die Zahl fälliger Karten.

### Ultra-Dopamin-Modus

In den Einstellungen unter „Belohnung" einschaltbar, standardmäßig aus. Beim Wischen nach rechts wird das Bewerten
zum Aha-Moment: Beim Halten lädt sich eine Glühbirne auf, die Haptik schwillt an, ein Ton steigt, und das Glas leuchtet
heller. Bei „Einfach" blitzt sie auf: Lichtblitz, Strahlen, Sterne, Häkchen und Konfetti, ein Schriftzug wie „SITZT!" oder
„GEMEISTERT!" und ein Zähler „3 in Folge", der zeigt, wie viele Karten nacheinander gewusst wurden. Ein normales „Gut"
gibt ein kleines Häkchen mit Sternchen, „Schwer" und „Nochmal" bleiben still und beenden die Serie. Alles dauert
rund anderthalb Sekunden. Die Klänge (Glockenspiel, Sternenstaub, ein weiches Whoomp) werden in der App aus Sinuswellen
berechnet, es gibt keine Audio-Dateien; sie folgen dem Stumm-Schalter. „Ausprobieren" in den Einstellungen spielt den
Effekt ohne Karte vor.

## Decks und Karten bearbeiten

Auf dem Startbildschirm legt **+** ein neues Deck (Name, dann die erste Karte; das Deck ist ein Ordner, der mit der
ersten Karte entsteht) oder eine neue Karte in einem wählbaren Deck an. Im Menü bei langem Drücken auf ein Deck gibt es
außerdem „Karte hinzufügen" und „Unterdeck anlegen".

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

## Datenschutz

StudyCraft sammelt keine Daten. Die einzige Netzwerkverbindung ist der Abruf der Decks im Tab „Entdecken"; die
[Datenschutzerklärung](docs/datenschutz.md) beschreibt das genau. Sie und die Support-Seite liegen in [`docs/`](docs/) und
lassen sich mit GitHub Pages veröffentlichen.

## Entwickeln

```bash
brew install xcodegen          # einmalig
cp Config/Local.xcconfig.example Config/Local.xcconfig   # DEVELOPMENT_TEAM eintragen
xcodegen generate
xcodebuild -project StudyCraft.xcodeproj -scheme StudyCraft \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Debug-Builds nehmen `-StudyCraftRoot /absoluter/pfad` als Lernordner, ohne den Dateien-Dialog (nützlich für Tests im
Simulator) und `-StudyCraftDiscoverBase <URL>` als Quelle für „Entdecken", etwa `file:///…/Discover/`, um neue Decks
vor dem Hochladen zu testen. Mit `-ultraDopamine YES` startet der Dopamin-Modus eingeschaltet.

```
Sources/StudyCraft
  Core/      Format und Logik ohne UI: CardParser, MarkdownParser, Scheduler, Progress, StudyClock
  Model/     AppModel (Zustand), FolderScanner/-Watcher, StudySession, Deck
  Discover/  Katalog, Download und Oberfläche von „Entdecken"
  Views/     Decks, Lernansicht, Statistik, Einstellungen, Markdown-Darstellung, Jackpot-Effekte
  Support/   Theme, Beispiel-Deck, Haptik und Klänge
Tests/StudyCraftTests   Parser, Scheduler, Sitzungen, Fortschritts-Zusammenführung, Scanner, Katalog
Discover/                Decks und Katalog für „Entdecken" samt Werkzeugen
docs/                    Datenschutzerklärung und Support-Seite (GitHub Pages)
AppStore/                Texte, Screenshots und Hinweise für App Store Connect
```
