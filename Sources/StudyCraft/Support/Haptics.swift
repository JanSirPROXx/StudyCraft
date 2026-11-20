import UIKit

// Die Haptik beim Wischen. Gewusst fühlt sich gut an (ein sich aufbauendes Kribbeln, dann ein Belohnungs-
// Schlag), nicht gewusst bleibt still: schlechte Antworten sollen nichts "belohnen".
@MainActor
enum Haptics {
  private static let light = UIImpactFeedbackGenerator(style: .light)
  private static let medium = UIImpactFeedbackGenerator(style: .medium)
  private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
  private static let notify = UINotificationFeedbackGenerator()
  private static let select = UISelectionFeedbackGenerator()

  static func prepare() {
    light.prepare()
    medium.prepare()
    heavy.prepare()
    notify.prepare()
  }

  static func selection() { select.selectionChanged() }

  // Ein Deck wurde geladen.
  static func success() { notify.notificationOccurred(.success) }

  // Beim Umdrehen.
  static func flip() { light.impactOccurred(intensity: 0.7) }

  // Die Karte ist weit genug gezogen: "Gut" ist erreicht.
  static func engage() { medium.impactOccurred(intensity: 0.6) }

  // Während man hält: leichte Impulse, die schneller und kräftiger werden.
  static func tick(_ intensity: Double) {
    light.impactOccurred(intensity: CGFloat(max(0.1, min(1, intensity))))
    light.prepare()
  }

  // "Einfach" ist erreicht: ein deutlicher Erfolgs-Schlag mit Nachklang.
  static func reward() {
    notify.notificationOccurred(.success)
    Task {
      try? await Task.sleep(for: .milliseconds(90))
      heavy.impactOccurred(intensity: 0.9)
    }
  }

  // Beim Loslassen.
  static func release(strong: Bool) {
    if strong {
      heavy.impactOccurred(intensity: 1)
    } else {
      medium.impactOccurred(intensity: 0.8)
    }
  }
}
