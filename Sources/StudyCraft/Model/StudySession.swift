import Observation
import SwiftUI

// Eine Lernsitzung für ein Deck (samt Unterdecks): erst die fälligen Wiederholungen, dann neue Karten.
// Karten, die im Lernschritt landen ("Nochmal", "10 Min"), kommen innerhalb der Sitzung wieder.
@MainActor @Observable
final class StudySession: Identifiable {
  let id = UUID()
  let deckName: String
  private(set) var total = 0
  private(set) var finished = 0
  private(set) var answered = 0
  private(set) var seconds: TimeInterval = 0
  private(set) var current: Card?
  private(set) var currentBlocks: (front: [MDBlock], back: [MDBlock]) = ([], [])
  private(set) var previews: [Rating: TimeInterval] = [:]
  private(set) var revealed = false  // die Antwort wurde schon einmal gezeigt: Bewertung ist möglich
  private(set) var flipTick = 0  // zählt Umdreh-Wünsche; die Kartenansicht dreht sich bei jedem
  private(set) var cardSerial = 0
  private(set) var nextDue: TimeInterval?  // wann wieder etwas fällig ist, wenn jetzt nichts ansteht

  private unowned let model: AppModel
  private var queue: [Card] = []
  private var learning: [(card: Card, due: Date)] = []
  private var shownAt = Date()

  var remaining: Int { max(0, total - finished) }
  var fraction: Double { total == 0 ? 1 : Double(finished) / Double(total) }
  var isFinished: Bool { current == nil }

  init(deck: DeckNode, model: AppModel) {
    self.model = model
    deckName = deck.name
    let now = Date()
    let today = StudyClock.dayIndex(for: now)

    var due: [Card] = []
    var fresh: [Card] = []
    var introducedToday = 0
    var upcoming: Date?
    for card in deck.allCards {
      guard let state = model.progress.state(for: card.id), state.queue != .new else {
        fresh.append(card)
        continue
      }
      if state.introducedDay == today { introducedToday += 1 }
      switch state.queue {
      case .learning, .relearning:
        if state.due <= now.addingTimeInterval(AppModel.learnAhead) {
          learning.append((card, state.due))
        } else {
          upcoming = min(upcoming ?? state.due, state.due)
        }
      case .review:
        if StudyClock.dayIndex(for: state.due) <= today {
          due.append(card)
        } else {
          upcoming = min(upcoming ?? state.due, state.due)
        }
      case .new: break
      }
    }
    let allowance = max(0, model.newPerDay - introducedToday)
    queue = due.shuffled() + fresh.prefix(allowance)
    learning.sort { $0.due < $1.due }
    total = queue.count + learning.count
    nextDue = upcoming.map { max(0, $0.timeIntervalSince(now)) }
    advance()
  }

  func imageResolver(for card: Card) -> ImageResolver { model.imageResolver(for: card) }

  // MARK: Ablauf

  func flip() {
    guard current != nil else { return }
    flipTick += 1
    revealed = true
  }

  func rate(_ rating: Rating) {
    guard let card = current, revealed else { return }
    let now = Date()
    let old = model.progress.state(for: card.id)
    let new = model.scheduler.apply(old, rating: rating, now: now)
    let spent = min(now.timeIntervalSince(shownAt), 60)
    seconds += spent
    answered += 1
    model.record(card: card, old: old, new: new, rating: rating, seconds: spent)

    switch new.queue {
    case .learning, .relearning:
      learning.append((card, new.due))
      learning.sort { $0.due < $1.due }
    default:
      finished += 1
    }
    advance()
  }

  // Die nächste Karte: eine fällige Lernkarte zuerst, sonst die nächste der Warteschlange. Sind nur noch
  // Lernkarten übrig, die erst in Minuten fällig werden, kommt die früheste sofort dran.
  private func advance() {
    let now = Date()
    let next: Card?
    if let first = learning.first, first.due <= now {
      next = learning.removeFirst().card
    } else if !queue.isEmpty {
      next = queue.removeFirst()
    } else if !learning.isEmpty {
      next = learning.removeFirst().card
    } else {
      next = nil
    }
    revealed = false
    current = next
    cardSerial += 1
    shownAt = now
    if let next {
      currentBlocks = (MarkdownParser.parse(next.front), MarkdownParser.parse(next.back))
      previews = model.scheduler.intervals(for: model.progress.state(for: next.id), now: now)
    } else {
      currentBlocks = ([], [])
      previews = [:]
    }
  }
}
