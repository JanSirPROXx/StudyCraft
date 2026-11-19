import Observation
import SwiftUI

// Eine Lernsitzung für ein Deck (samt Unterdecks): man geht das ganze Deck einmal durch, ob gemischt, der
// Reihe nach oder nur die neuen Karten. "Nochmal" bringt eine Karte nach ein paar Karten noch einmal, alle
// anderen Antworten schließen die Karte für diese Sitzung ab. Der Lernstand (Intervalle, Leichtigkeit)
// wird bei jeder Antwort wie bei Anki fortgeschrieben.
@MainActor @Observable
final class StudySession: Identifiable {
  let id = UUID()
  let deckName: String
  private(set) var mode: StudyMode
  private(set) var total = 0
  private(set) var finished = 0
  private(set) var answered = 0
  private(set) var seconds: TimeInterval = 0
  private(set) var current: Card?
  private(set) var currentBlocks: (front: [MDBlock], back: [MDBlock]) = ([], [])
  private(set) var previews: [Rating: TimeInterval] = [:]
  private(set) var revealed = false  // die Antwort wurde schon einmal gezeigt: die Buttons erscheinen
  private(set) var flipTick = 0  // zählt Umdreh-Wünsche; die Kartenansicht dreht sich bei jedem
  private(set) var cardSerial = 0
  private(set) var requestedRating: Rating?  // Wunsch der Buttons: die Karte soll mit dieser Antwort hinausfliegen
  private(set) var requestSerial = 0
  private(set) var entryOffset: CGFloat = 0  // woher eine zurückgeholte Karte hereinfliegt
  private(set) var canUndo = false

  private struct Entry {
    var card: Card
    var token: AppModel.RatingToken
    var spent: TimeInterval
    var rating: Rating
    var requeued: Bool
  }

  private unowned let model: AppModel
  private let pool: [Card]
  private var queue: [Card] = []
  private var done = Set<String>()
  private var history: [Entry] = []
  private var lastID: String?
  private var shownAt = Date()

  var remaining: Int { max(0, total - finished) }
  var fraction: Double { total == 0 ? 1 : Double(finished) / Double(total) }
  var isFinished: Bool { current == nil }

  init(deck: DeckNode, mode: StudyMode, model: AppModel) {
    self.model = model
    self.mode = mode
    deckName = deck.name
    pool = deck.allCards.filter { !$0.hidden }
    rebuild()
    advance()
  }

  func imageResolver(for card: Card) -> ImageResolver { model.imageResolver(for: card) }

  // MARK: Reihenfolge

  func setMode(_ new: StudyMode) {
    guard new != mode else { return }
    mode = new
    model.studyMode = new
    rebuild()
    advance()
  }

  // Zum Anfang zurück: alle Karten noch einmal.
  func restart() {
    done = []
    finished = 0
    history = []
    canUndo = false
    rebuild()
    advance()
  }

  private func rebuild() {
    var cards = pool.filter { !done.contains($0.id) }
    switch mode {
    case .new:
      cards = cards.filter { (model.progress.state(for: $0.id)?.queue ?? .new) == .new }
    case .sorted:
      break
    case .shuffle:
      let order = SmartShuffle.order(cards.map(\.id), avoiding: lastID)
      let byID = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
      cards = order.compactMap { byID[$0] }
    }
    queue = cards
    total = done.count + queue.count
  }

  // MARK: Ablauf

  func flip() {
    guard current != nil else { return }
    flipTick += 1
    revealed = true
  }

  // Die Buttons bitten die Karte, mit dieser Antwort hinauszufliegen; danach ruft sie `rate` auf.
  func request(_ rating: Rating) {
    guard current != nil else { return }
    requestedRating = rating
    requestSerial += 1
  }

  func rate(_ rating: Rating) {
    guard let card = current else { return }
    let now = Date()
    let old = model.progress.state(for: card.id)
    let new = model.scheduler.apply(old, rating: rating, now: now)
    let spent = min(now.timeIntervalSince(shownAt), 60)
    let token = model.record(card: card, old: old, new: new, rating: rating, seconds: spent)
    seconds += spent
    answered += 1

    var requeued = false
    if rating == .again {
      // Nicht gleich noch einmal, sondern nach ein paar anderen Karten.
      queue.insert(card, at: min(queue.count, Int.random(in: 4...7)))
      requeued = true
    } else {
      done.insert(card.id)
      finished += 1
    }
    history.append(
      Entry(card: card, token: token, spent: spent, rating: rating, requeued: requeued))
    canUndo = true
    lastID = card.id
    entryOffset = 0
    advance()
  }

  // Die letzte Antwort zurücknehmen: der Lernstand ist wie vorher, die Karte kommt noch einmal.
  func undo() {
    guard let entry = history.popLast() else { return }
    canUndo = !history.isEmpty
    model.undo(entry.token)
    answered = max(0, answered - 1)
    seconds = max(0, seconds - entry.spent)
    if entry.requeued {
      if let index = queue.firstIndex(where: { $0.id == entry.card.id }) { queue.remove(at: index) }
    } else {
      done.remove(entry.card.id)
      finished = max(0, finished - 1)
    }
    if let current, current.id != entry.card.id { queue.insert(current, at: 0) }
    entryOffset = entry.rating.isPositive ? 700 : -700
    show(entry.card)
  }

  private func advance() {
    entryOffset = 0
    show(queue.isEmpty ? nil : queue.removeFirst())
  }

  private func show(_ card: Card?) {
    let now = Date()
    revealed = false
    current = card
    cardSerial += 1
    shownAt = now
    if let card {
      currentBlocks = (MarkdownParser.parse(card.front), MarkdownParser.parse(card.back))
      previews = model.scheduler.intervals(for: model.progress.state(for: card.id), now: now)
    } else {
      currentBlocks = ([], [])
      previews = [:]
    }
  }
}
