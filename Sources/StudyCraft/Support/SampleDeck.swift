import UIKit

// Ein kleines Beispiel-Deck, das zeigt, was das Format kann – auch mit einem Bild aus demselben Ordner.
enum SampleDeck {
  static let formatExample = """
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
    - `map` gibt ein neues Array zurück
    """

  static func write(into root: URL) throws {
    let folder = root.appendingPathComponent("Beispiel", isDirectory: true)
    let sub = folder.appendingPathComponent("Programmieren", isDirectory: true)
    try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)

    try put(
      """
      @studyCraft_List

      # Willkommen bei StudyCraft
      Tippe auf die Karte, um sie umzudrehen.
      ---
      Danach bewertest du, wie gut du die Antwort wusstest:

      1. **Nochmal** – vergessen
      2. **Schwer** – mit Mühe
      3. **Gut** – richtig
      4. **Einfach** – sofort gewusst
      ===
      Wie schreibt man *kursiv*, **fett** und `Code`?
      ---
      - `*kursiv*` → *kursiv*
      - `**fett**` → **fett**
      - `` `Code` `` → `Code`
      ===
      ## Was zeigt dieses Bild?

      ![Ein Beispielbild](beispiel.png)
      ---
      Ein blauer Verlauf – Bilder aus demselben Ordner werden direkt in der Karte angezeigt.
      ===
      Welche Datei wird zu Karten?
      ---
      Jede `.md`-Datei, deren **erste Zeile** `@studyCraft` oder `@studyCraft_List` lautet.

      > Änderungen am Mac erscheinen automatisch in der App.
      """, to: folder.appendingPathComponent("Willkommen.md"))

    try put(
      """
      @studyCraft_List

      Was ist der Unterschied zwischen `let` und `var` in Swift?
      ---
      - `let` – Konstante, nach der Zuweisung unveränderlich
      - `var` – Variable, kann neu zugewiesen werden
      ===
      Was gibt dieser Ausdruck zurück?

      ```swift
      [3, 1, 2].sorted()
      ```
      ---
      `[1, 2, 3]`
      ===
      Welche Komplexität hat die binäre Suche?
      ---
      | Fall | Laufzeit |
      |------|----------|
      | Bester | O(1) |
      | Schlechtester | O(log n) |
      """, to: sub.appendingPathComponent("Swift Grundlagen.md"))

    try put(
      """
      @studyCraft

      # Was ist ein Closure?
      ---
      Ein Codeblock, der Werte aus seiner Umgebung **einfängt** und später aufgerufen werden kann.
      """, to: sub.appendingPathComponent("Closure.md"))

    let image = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 420)).image { context in
      let colors = [UIColor(red: 0.02, green: 0.48, blue: 0.78, alpha: 1).cgColor,
                    UIColor(red: 0.2, green: 0.68, blue: 0.9, alpha: 1).cgColor]
      let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
      context.cgContext.drawLinearGradient(
        gradient, start: .zero, end: CGPoint(x: 900, y: 420), options: [])
      let text = "StudyCraft" as NSString
      let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 96, weight: .bold), .foregroundColor: UIColor.white,
      ]
      let size = text.size(withAttributes: attributes)
      text.draw(at: CGPoint(x: (900 - size.width) / 2, y: (420 - size.height) / 2), withAttributes: attributes)
    }
    if let png = image.pngData() {
      try FileIO.writeData(png, to: folder.appendingPathComponent("beispiel.png"))
    }
  }

  private static func put(_ text: String, to url: URL) throws {
    try FileIO.writeData(Data(text.utf8), to: url)
  }
}
