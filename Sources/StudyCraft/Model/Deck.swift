import CryptoKit
import Foundation

struct Card: Identifiable, Hashable, Sendable {
  let id: String
  let deckID: String  // Ordnerpfad relativ zum Lernordner; "" für lose Karten im Lernordner
  let front: String
  let back: String
  let fileURL: URL
  let filePath: String
  let order: Int  // Position in der Datei

  var directory: URL { fileURL.deletingLastPathComponent() }
}

struct DeckNode: Identifiable, Sendable {
  let id: String
  let name: String
  var cards: [Card]  // direkt in diesem Ordner
  var children: [DeckNode]

  var allCards: [Card] { cards + children.flatMap(\.allCards) }
  var cardCount: Int { cards.count + children.reduce(0) { $0 + $1.cardCount } }
}

enum DeckTree {
  static let looseID = ""
  static let looseName = "Allgemein"

  static func build(from cards: [Card]) -> [DeckNode] {
    let byDeck = Dictionary(grouping: cards, by: \.deckID)
    var ids = Set<String>()
    for id in byDeck.keys where id != looseID {
      var parts = id.split(separator: "/").map(String.init)
      while !parts.isEmpty {
        ids.insert(parts.joined(separator: "/"))
        parts.removeLast()
      }
    }

    func children(of parent: String) -> [DeckNode] {
      ids.filter { parentPath(of: $0) == parent }
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        .map { id in
          DeckNode(
            id: id, name: id.split(separator: "/").last.map(String.init) ?? id,
            cards: sorted(byDeck[id] ?? []), children: children(of: id))
        }
    }

    var nodes = children(of: "")
    if let loose = byDeck[looseID], !loose.isEmpty {
      nodes.append(DeckNode(id: looseID, name: looseName, cards: sorted(loose), children: []))
    }
    return nodes
  }

  private static func parentPath(of id: String) -> String {
    guard let slash = id.lastIndex(of: "/") else { return "" }
    return String(id[..<slash])
  }

  private static func sorted(_ cards: [Card]) -> [Card] {
    cards.sorted {
      $0.filePath == $1.filePath
        ? $0.order < $1.order : $0.filePath.localizedStandardCompare($1.filePath) == .orderedAscending
    }
  }
}

// Wie viele Karten in einem Deck (samt Unterdecks) jetzt anstehen.
struct DeckCounts: Equatable, Sendable {
  var new = 0  // neue Karten, die heute noch gelernt werden dürfen
  var due = 0  // fällige Wiederholungen und Lernkarten
  var total = 0
  var introducedToday = 0
}

enum CardIdentity {
  // Karten in `@studyCraft`-Dateien heißen wie die Datei. In Listen-Dateien identifiziert der Inhalt der
  // Vorderseite die Karte, damit der Lernstand beim Umsortieren oder Einfügen von Karten erhalten bleibt.
  static func id(file: String, card: ParsedCard, index: Int, isSingle: Bool) -> String {
    if isSingle { return file }
    let normalized = card.front.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    let digest = SHA256.hash(data: Data(normalized.utf8))
    let hex = digest.prefix(6).map { String(format: "%02x", $0) }.joined()
    return "\(file)#\(hex)"
  }
}
