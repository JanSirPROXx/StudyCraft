import Foundation

enum CardStoreError: LocalizedError {
  case invalid(String)
  case changed

  var errorDescription: String? {
    switch self {
    case .invalid(let reason): reason
    case .changed: "Die Datei wurde inzwischen geändert. Bitte versuche es noch einmal."
    }
  }
}

// Ändert Karten direkt in ihren Markdown-Dateien: hinzufügen, bearbeiten, ausblenden, löschen.
// Alles, was nicht angefasst wird, bleibt Zeichen für Zeichen erhalten.
enum CardStore {
  private static func load(_ url: URL) throws -> CardParser.Layout {
    guard let layout = CardParser.layout(try FileIO.readString(url)) else {
      throw CardStoreError.invalid("Die Datei „\(url.lastPathComponent)“ ist keine Karten-Datei.")
    }
    return layout
  }

  private static func save(_ layout: CardParser.Layout, to url: URL) throws {
    try FileIO.writeData(Data(layout.text.utf8), to: url)
  }

  private static func isBlank(_ line: String) -> Bool {
    line.trimmingCharacters(in: .whitespaces).isEmpty
  }

  private static func lines(_ text: String) -> [String] {
    text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
      .components(separatedBy: "\n")
  }

  private static func cardLines(front: String, back: String) -> [String] {
    lines(CardParser.trimmed(front)) + ["---"] + lines(CardParser.trimmed(back))
  }

  // Prüft, dass die neue Karte nach dem Schreiben wieder als genau diese Karte gelesen wird (zum Beispiel
  // nicht von einer "---"- oder "==="-Zeile im Text zerrissen wird).
  private static func verify(
    _ layout: CardParser.Layout, chunk: Int, front: String, back: String, chunkCount: Int
  ) throws {
    guard let reread = CardParser.layout(layout.text), reread.chunks.count == chunkCount,
      let card = CardParser.card(in: reread.chunks[chunk], chunk: chunk),
      card.front == CardParser.trimmed(front), card.back == CardParser.trimmed(back)
    else {
      throw CardStoreError.invalid(
        "Der Text enthält eine Zeile aus „---“ oder „===“ außerhalb eines Code-Blocks. Sie trennt Karten und Seiten und darf nicht im Text stehen.")
    }
  }

  private static func requireContent(_ front: String, _ back: String) throws {
    guard !CardParser.trimmed(front).isEmpty, !CardParser.trimmed(back).isEmpty else {
      throw CardStoreError.invalid("Vorder- und Rückseite dürfen nicht leer sein.")
    }
  }

  // MARK: Bearbeiten

  static func update(card: Card, front: String, back: String) throws {
    try requireContent(front, back)
    var layout = try load(card.fileURL)
    guard layout.chunks.indices.contains(card.chunk),
      CardParser.card(in: layout.chunks[card.chunk], chunk: card.chunk)?.front == card.front
    else { throw CardStoreError.changed }

    let old = layout.chunks[card.chunk]
    let leading = old.prefix(while: isBlank).count
    let trailing = leading == old.count ? 0 : old.reversed().prefix(while: isBlank).count
    let hidden = CardParser.card(in: old, chunk: card.chunk)?.hidden == true
    layout.chunks[card.chunk] =
      Array(repeating: "", count: leading) + (hidden ? [CardParser.hiddenMarker] : [])
      + cardLines(front: front, back: back) + Array(repeating: "", count: trailing)
    try verify(
      layout, chunk: card.chunk, front: front, back: back, chunkCount: layout.chunks.count)
    try save(layout, to: card.fileURL)
  }

  static func setHidden(_ hidden: Bool, card: Card) throws {
    var layout = try load(card.fileURL)
    guard layout.chunks.indices.contains(card.chunk),
      CardParser.card(in: layout.chunks[card.chunk], chunk: card.chunk)?.front == card.front
    else { throw CardStoreError.changed }

    var chunk = layout.chunks[card.chunk]
    chunk.removeAll { CardParser.isHiddenMarker($0.trimmingCharacters(in: .whitespaces)) }
    if hidden {
      chunk.insert(CardParser.hiddenMarker, at: chunk.firstIndex { !isBlank($0) } ?? 0)
    }
    layout.chunks[card.chunk] = chunk
    try save(layout, to: card.fileURL)
  }

  // Eine Karte in einer Listen-Datei wird aus der Datei entfernt, eine einzelne Karte ist die Datei selbst.
  static func remove(card: Card) throws {
    if card.isSingle {
      try FileIO.remove(card.fileURL)
      return
    }
    var layout = try load(card.fileURL)
    guard layout.chunks.indices.contains(card.chunk),
      CardParser.card(in: layout.chunks[card.chunk], chunk: card.chunk)?.front == card.front
    else { throw CardStoreError.changed }

    layout.chunks.remove(at: card.chunk)
    if layout.chunks.isEmpty { layout.chunks = [[""]] }
    if card.chunk == 0, let first = layout.chunks[0].first, !isBlank(first) {
      layout.chunks[0].insert("", at: 0)
    }
    try save(layout, to: card.fileURL)
  }

  // MARK: Hinzufügen

  static func append(to url: URL, front: String, back: String) throws {
    try requireContent(front, back)
    var layout = try load(url)
    let new = cardLines(front: front, back: back) + [""]
    if layout.chunks.allSatisfy({ $0.allSatisfy(isBlank) }) {
      layout.chunks = [[""] + new]
    } else if layout.chunks.last?.allSatisfy(isBlank) == true {
      layout.chunks[layout.chunks.count - 1] = new  // die Datei endet schon mit "==="
    } else {
      while let last = layout.chunks[layout.chunks.count - 1].last, isBlank(last) {
        layout.chunks[layout.chunks.count - 1].removeLast()
      }
      layout.chunks.append(new)
    }
    try verify(
      layout, chunk: layout.chunks.count - 1, front: front, back: back,
      chunkCount: layout.chunks.count)
    try save(layout, to: url)
  }

  // Legt in einem Ordner eine neue Listen-Datei an und gibt ihre Adresse zurück.
  @discardableResult
  static func createList(in folder: URL, front: String, back: String) throws -> URL {
    try requireContent(front, back)
    var url = folder.appendingPathComponent("Karten.md")
    var number = 2
    while FileManager.default.fileExists(atPath: url.path) {
      url = folder.appendingPathComponent("Karten \(number).md")
      number += 1
    }
    let layout = CardParser.Layout(
      header: "@studyCraft_List", isList: true,
      chunks: [[""] + cardLines(front: front, back: back) + [""]])
    try verify(layout, chunk: 0, front: front, back: back, chunkCount: 1)
    try save(layout, to: url)
    return url
  }
}
