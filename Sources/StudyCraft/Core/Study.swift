import CoreGraphics
import Foundation

// In welcher Reihenfolge ein Deck durchgegangen wird.
enum StudyMode: String, CaseIterable, Identifiable, Sendable {
  case shuffle, sorted, new
  var id: String { rawValue }
  var title: String {
    switch self {
    case .shuffle: "Mischen"
    case .sorted: "Der Reihe nach"
    case .new: "Nur neue"
    }
  }
  var icon: String {
    switch self {
    case .shuffle: "shuffle"
    case .sorted: "list.number"
    case .new: "sparkles"
    }
  }
}

extension Rating {
  var isPositive: Bool { self == .good || self == .easy }
}

// Eine Mischung, die sich zufällig anfühlt: Jede Karte kommt genau einmal dran (nach einer festen Zahl
// von Karten ist alles durch), zwei Karten, die in der Datei nebeneinander stehen, bleiben möglichst
// getrennt, und die erste Karte ist nie die, die gerade zuletzt kam.
enum SmartShuffle {
  static func order<T: Hashable>(_ items: [T], avoiding last: T? = nil) -> [T] {
    var generator = SystemRandomNumberGenerator()
    return order(items, avoiding: last, using: &generator)
  }

  static func order<T: Hashable, G: RandomNumberGenerator>(
    _ items: [T], avoiding last: T?, using generator: inout G
  ) -> [T] {
    guard items.count > 1 else { return items }
    var position: [T: Int] = [:]
    for (index, item) in items.enumerated() where position[item] == nil { position[item] = index }
    var result = items.shuffled(using: &generator)

    func neighbours(_ a: T, _ b: T) -> Bool {
      abs((position[a] ?? 0) - (position[b] ?? 0)) == 1
    }
    // Stehen Karten aus der Datei nebeneinander, bleibt es nicht bei Zufall: tauschen, wenn möglich.
    func clash(at index: Int) -> Bool {
      (index > 0 && neighbours(result[index - 1], result[index]))
        || (index + 1 < result.count && neighbours(result[index], result[index + 1]))
    }
    for i in 1..<result.count where clash(at: i) {
      for _ in 0..<8 {
        let j = Int.random(in: 0..<result.count, using: &generator)
        guard j != i else { continue }
        result.swapAt(i, j)
        if !clash(at: i) && !clash(at: j) { break }
        result.swapAt(i, j)
      }
    }
    if let last, result[0] == last {
      let j = Int.random(in: 1..<result.count, using: &generator)
      result.swapAt(0, j)
    }
    return result
  }
}

// Wie eine Wischgeste bewertet wird: nach rechts "Gut", hält man den Finger noch eine Weile, wird daraus
// "Einfach". Nach links "Schwer" und mit gehaltenem Finger "Nochmal". Ein schneller Wisch zählt als die
// erste Stufe.
enum SwipeRule {
  static let trigger: CGFloat = 72  // so weit muss die Karte gezogen werden
  static let release: CGFloat = 48  // darunter ist die Stufe wieder aufgehoben
  static let dwell: TimeInterval = 0.85  // so lange muss der Finger für die zweite Stufe bleiben
  static let flickDistance: CGFloat = 320  // vorhergesagte Strecke, ab der ein Wisch als "schnell" gilt

  // `armed`: die Karte wurde weit genug gezogen und noch nicht wieder zurück. `strong`: der Finger blieb
  // lange genug, um die zweite Stufe zu erreichen. Ein schneller Wisch zählt auch ohne weites Ziehen.
  static func rating(dx: CGFloat, armed: Bool, strong: Bool, predicted: CGFloat) -> Rating? {
    let flick = abs(predicted) >= flickDistance && abs(dx) >= 24 && (predicted > 0) == (dx > 0)
    guard armed || flick else { return nil }
    if dx > 0 { return strong ? .easy : .good }
    return strong ? .again : .hard
  }
}
