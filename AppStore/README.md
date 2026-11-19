# App-Store-Material

- `Store-Texte.md` – alle Texte für App Store Connect (Deutsch), mit Zeichenlimits, plus Hinweise für die App-Prüfung
- `Datenschutz.md` – Datenschutzerklärung (vor dem Hochladen Kontakt eintragen und unter einer öffentlichen URL hosten)
- `Screenshots/iPhone` – 1320 × 2868 px (iPhone 17 Pro Max, 6,9")
- `Screenshots/iPad` – 2064 × 2752 px (iPad Pro 13")

Die Screenshots stammen aus dem Simulator mit Demo-Daten (Uhr 9:41). Neu aufnehmen:
Simulator starten, `xcrun simctl status_bar <UDID> override --time 9:41 --batteryState charged --batteryLevel 100`,
App mit `-StudyCraftRoot <Ordner mit Demo-Decks>` starten, `xcrun simctl io <UDID> screenshot <Datei>.png`.

Build hochladen: Xcode → Product → Archive → Distribute App → App Store Connect.
Version steht in `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`).
