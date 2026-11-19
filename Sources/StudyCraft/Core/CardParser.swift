import Foundation

struct ParsedCard: Equatable, Sendable {
  var front: String
  var back: String
  var chunk = 0  // wie vielte "===" -getrennte Einheit der Datei (für das Bearbeiten)
  var hidden = false  // ausgeblendet über `<!-- hidden -->`
}

struct ParsedFile: Equatable, Sendable {
  // `@studyCraft_List`: Karten werden über ihren Inhalt erkannt. `@studyCraft`: die Datei ist die Karte.
  var isList: Bool
  var cards: [ParsedCard]
}

// Das Kartenformat (siehe README):
//
//     @studyCraft_List        ← erste Zeile: Kennung (`@studyCraft` für eine einzelne Karte)
//
//     Vorderseite
//     ---                     ← trennt Vorder- und Rückseite
//     Rückseite
//     ===                     ← trennt Karten (nur in Listen-Dateien)
//     ...
//
// Trennlinien in Code-Blöcken (``` oder ~~~) zählen nicht. Dateien ohne Kennung sind keine Karten.
// Eine Zeile `<!-- hidden -->` in einer Karte blendet sie aus.
enum CardParser {
  static let singleIdentifier = "@studycraft"
  static let listIdentifier = "@studycraft_list"
  static let hiddenMarker = "<!-- hidden -->"

  // Die Datei in ihre Bausteine zerlegt: Kennzeile und die Abschnitte zwischen den "==="-Zeilen. Daraus
  // lässt sich der Text wieder zusammensetzen, ohne etwas zu verändern (außer Zeilenenden und BOM).
  struct Layout: Sendable {
    var header: String
    var isList: Bool
    var chunks: [[String]]

    var text: String {
      var lines = [header]
      for (index, chunk) in chunks.enumerated() {
        if index > 0 { lines.append("===") }
        lines += chunk
      }
      return lines.joined(separator: "\n")
    }
  }

  static func layout(_ raw: String) -> Layout? {
    var text = raw
    if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
    let lines =
      text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
      .components(separatedBy: "\n")
    guard let first = lines.first else { return nil }
    let isList: Bool
    switch first.trimmingCharacters(in: .whitespaces).lowercased() {
    case singleIdentifier: isList = false
    case listIdentifier: isList = true
    default: return nil
    }

    var chunks: [[String]] = [[]]
    var fence: String?
    for line in lines.dropFirst() {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if isFence(trimmed) {
        toggle(&fence, trimmed)
      } else if fence == nil, isRule(trimmed, of: "=") {
        chunks.append([])
        continue
      }
      chunks[chunks.count - 1].append(line)
    }
    return Layout(header: first, isList: isList, chunks: chunks)
  }

  static func parse(_ raw: String) -> ParsedFile? {
    guard let layout = layout(raw) else { return nil }
    let cards = layout.chunks.enumerated().compactMap { card(in: $1, chunk: $0) }
    return ParsedFile(isList: layout.isList, cards: cards)
  }

  // Die Karte in einem Abschnitt, falls er Vorder- und Rückseite hat.
  static func card(in lines: [String], chunk: Int) -> ParsedCard? {
    var front: [String] = []
    var back: [String] = []
    var inBack = false
    var hidden = false
    var fence: String?
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if isFence(trimmed) {
        toggle(&fence, trimmed)
      } else if fence == nil {
        if isHiddenMarker(trimmed) {
          hidden = true
          continue
        }
        if !inBack, isRule(trimmed, of: "-") {
          inBack = true
          continue
        }
      }
      if inBack { back.append(line) } else { front.append(line) }
    }
    let f = joined(front)
    let b = joined(back)
    guard inBack, !f.isEmpty, !b.isEmpty else { return nil }
    return ParsedCard(front: f, back: b, chunk: chunk, hidden: hidden)
  }

  static func isHiddenMarker(_ line: String) -> Bool {
    line.lowercased().replacingOccurrences(of: " ", with: "") == "<!--hidden-->"
  }

  // Der Text so, wie er nach dem Parsen aussieht (ohne leere Zeilen am Anfang und Ende).
  static func trimmed(_ text: String) -> String {
    joined(
      text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n"))
  }

  private static func isFence(_ trimmed: String) -> Bool {
    trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~")
  }

  private static func toggle(_ fence: inout String?, _ trimmed: String) {
    let marker = String(trimmed.prefix(3))
    if fence == nil {
      fence = marker
    } else if fence == marker {
      fence = nil
    }
  }

  private static func isRule(_ trimmed: String, of character: Character) -> Bool {
    trimmed.count >= 3 && trimmed.allSatisfy { $0 == character }
  }

  // Entfernt leere Zeilen am Anfang und Ende, lässt aber die Einrückung der ersten Zeile unberührt.
  private static func joined(_ lines: [String]) -> String {
    var slice = lines[...]
    while let first = slice.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
      slice = slice.dropFirst()
    }
    while let last = slice.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
      slice = slice.dropLast()
    }
    return slice.joined(separator: "\n")
  }
}
