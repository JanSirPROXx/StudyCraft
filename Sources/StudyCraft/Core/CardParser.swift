import Foundation

struct ParsedCard: Equatable, Sendable {
  var front: String
  var back: String
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
enum CardParser {
  static let singleIdentifier = "@studycraft"
  static let listIdentifier = "@studycraft_list"

  static func parse(_ raw: String) -> ParsedFile? {
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

    var cards: [ParsedCard] = []
    var front: [String] = []
    var back: [String] = []
    var inBack = false
    var fence: String?

    func finish() {
      let f = joined(front)
      let b = joined(back)
      if inBack, !f.isEmpty, !b.isEmpty { cards.append(ParsedCard(front: f, back: b)) }
      front = []
      back = []
      inBack = false
    }

    for line in lines.dropFirst() {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
        let marker = String(trimmed.prefix(3))
        if fence == nil {
          fence = marker
        } else if fence == marker {
          fence = nil
        }
      } else if fence == nil {
        if isRule(trimmed, of: "=") {
          finish()
          continue
        }
        if !inBack, isRule(trimmed, of: "-") {
          inBack = true
          continue
        }
      }
      if inBack { back.append(line) } else { front.append(line) }
    }
    finish()
    return ParsedFile(isList: isList, cards: cards)
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
