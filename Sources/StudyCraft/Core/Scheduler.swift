import Foundation

enum Rating: Int, CaseIterable, Identifiable, Sendable {
  case again = 1, hard, good, easy
  var id: Int { rawValue }
  var title: String {
    switch self {
    case .again: "Nochmal"
    case .hard: "Schwer"
    case .good: "Gut"
    case .easy: "Einfach"
    }
  }
}

enum CardQueue: String, Codable, Sendable {
  case new, learning, review, relearning
}

// Der Lernstand einer Karte. `due` ist bei Lernschritten der genaue Zeitpunkt, bei Wiederholungen
// der Beginn des Lerntags, an dem die Karte fällig wird.
struct CardProgress: Codable, Equatable, Sendable {
  var queue: CardQueue
  var due: Date
  var interval: Int  // Tage
  var ease: Double
  var reps: Int
  var lapses: Int
  var step: Int
  var introducedDay: Int?  // Lerntag, an dem die Karte zum ersten Mal beantwortet wurde
  var updatedAt: Date

  init(startingEase: Double, now: Date) {
    queue = .new
    due = now
    interval = 0
    ease = startingEase
    reps = 0
    lapses = 0
    step = 0
    introducedDay = nil
    updatedAt = now
  }
}

struct SchedulerConfig: Sendable {
  var learningSteps: [TimeInterval] = [60, 600]
  var relearningSteps: [TimeInterval] = [600]
  var graduatingInterval = 1
  var easyInterval = 4
  var startingEase = 2.5
  var minimumEase = 1.3
  var easyBonus = 1.3
  var hardMultiplier = 1.2
  var intervalModifier = 1.0
  var lapseMultiplier = 0.0
  var minimumLapseInterval = 1
  var maximumInterval = 36500
}

// Die Wiederholungsplanung (eine SM-2-Variante): Lernschritte für neue und
// vergessene Karten, danach Intervalle, die mit dem Leichtigkeitsfaktor der Karte wachsen.
struct Scheduler: Sendable {
  var config = SchedulerConfig()

  func apply(_ old: CardProgress?, rating: Rating, now: Date) -> CardProgress {
    let today = StudyClock.dayIndex(for: now)
    var p = old ?? CardProgress(startingEase: config.startingEase, now: now)
    p.reps += 1
    p.updatedAt = now
    switch p.queue {
    case .new:
      p.introducedDay = today
      p.queue = .learning
      p.step = 0
      return learn(p, rating, now, today)
    case .learning, .relearning:
      return learn(p, rating, now, today)
    case .review:
      return review(p, rating, now, today)
    }
  }

  // Wann die Karte nach jeder der vier Antworten wiederkommt, in Sekunden (für die Button-Beschriftung).
  func intervals(for p: CardProgress?, now: Date) -> [Rating: TimeInterval] {
    var result: [Rating: TimeInterval] = [:]
    for rating in Rating.allCases {
      let next = apply(p, rating: rating, now: now)
      result[rating] =
        next.queue == .review
        ? Double(next.interval) * 86400 : max(0, next.due.timeIntervalSince(now))
    }
    return result
  }

  // MARK: Lernschritte

  private func learn(_ input: CardProgress, _ rating: Rating, _ now: Date, _ today: Int)
    -> CardProgress
  {
    var p = input
    let steps = p.queue == .relearning ? config.relearningSteps : config.learningSteps
    guard !steps.isEmpty else { return graduate(p, easy: rating == .easy, today) }
    p.step = min(p.step, steps.count - 1)
    switch rating {
    case .again:
      p.step = 0
      p.due = now.addingTimeInterval(steps[0])
    case .hard:
      let delay: TimeInterval =
        p.step + 1 < steps.count
        ? (steps[p.step] + steps[p.step + 1]) / 2 : min(steps[p.step] * 1.5, 86400)
      p.due = now.addingTimeInterval(delay)
    case .good:
      if p.step + 1 < steps.count {
        p.step += 1
        p.due = now.addingTimeInterval(steps[p.step])
      } else {
        return graduate(p, easy: false, today)
      }
    case .easy:
      return graduate(p, easy: true, today)
    }
    return p
  }

  private func graduate(_ input: CardProgress, easy: Bool, _ today: Int) -> CardProgress {
    var p = input
    if p.queue == .relearning {
      p.interval = easy ? p.interval + 1 : max(1, p.interval)
    } else {
      p.interval = easy ? config.easyInterval : config.graduatingInterval
    }
    p.interval = min(p.interval, config.maximumInterval)
    p.queue = .review
    p.step = 0
    p.due = StudyClock.startOfDay(today + p.interval)
    return p
  }

  // MARK: Wiederholungen

  private func review(_ input: CardProgress, _ rating: Rating, _ now: Date, _ today: Int)
    -> CardProgress
  {
    var p = input
    let overdue = max(0, today - StudyClock.dayIndex(for: p.due))
    let current = max(p.interval, 1)

    func constrained(_ value: Double, previous: Int) -> Int {
      min(max(Int(value * config.intervalModifier), previous + 1), config.maximumInterval)
    }
    let hard = constrained(Double(current + overdue / 4) * config.hardMultiplier, previous: current)
    let good = constrained(Double(current + overdue / 2) * p.ease, previous: hard)
    let easy = constrained(
      Double(current + overdue) * p.ease * config.easyBonus, previous: good)

    switch rating {
    case .again:
      p.lapses += 1
      p.ease = max(config.minimumEase, p.ease - 0.2)
      p.interval = max(
        config.minimumLapseInterval, Int(Double(current) * config.lapseMultiplier))
      if let first = config.relearningSteps.first {
        p.queue = .relearning
        p.step = 0
        p.due = now.addingTimeInterval(first)
      } else {
        p.due = StudyClock.startOfDay(today + p.interval)
      }
      return p
    case .hard:
      p.ease = max(config.minimumEase, p.ease - 0.15)
      p.interval = hard
    case .good:
      p.interval = good
    case .easy:
      p.ease += 0.15
      p.interval = easy
    }
    p.due = StudyClock.startOfDay(today + p.interval)
    return p
  }
}
