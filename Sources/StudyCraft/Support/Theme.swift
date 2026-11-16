import SwiftUI
import UIKit

// Die Farben der "Classic"-Palette aus NotesCraft: ein fast schwarzer Dunkelmodus, ein helles iOS-Grau
// im Hellmodus und ein einziger blauer Akzent. Alles passt sich dem Hell-/Dunkelmodus an.
extension UIColor {
  convenience init(hex: UInt32) {
    self.init(
      red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
  }
}

extension Color {
  static func adaptive(light: UInt32, dark: UInt32) -> Color {
    Color(
      UIColor { traits in
        UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
      })
  }
}

enum Theme {
  static let background = Color.adaptive(light: 0xF2F2F7, dark: 0x060606)
  static let card = Color.adaptive(light: 0xFFFFFF, dark: 0x161616)
  static let field = Color.adaptive(light: 0xE3E3E8, dark: 0x1C1C1C)
  static let raised = Color.adaptive(light: 0xE5E5EA, dark: 0x2E2E2E)
  static let separator = Color.adaptive(light: 0xD1D1D6, dark: 0x2E2E2E)

  static let textPrimary = Color.adaptive(light: 0x1C1C1E, dark: 0xFFFFFF)
  static let textSecondary = Color.adaptive(light: 0x6C6C70, dark: 0xA1A1A1)
  static let textTertiary = Color.adaptive(light: 0x8E8E93, dark: 0x737373)

  static let accent = Color.adaptive(light: 0x0A6EC4, dark: 0x057AC7)
  static let newBlue = Color.adaptive(light: 0x1B8FCF, dark: 0x32ADE6)
  static let success = Color.adaptive(light: 0x1F9D45, dark: 0x30D158)
  static let warning = Color.adaptive(light: 0xE08A00, dark: 0xFF9F0A)
  static let danger = Color.adaptive(light: 0xD93025, dark: 0xFF453A)

  static func color(for rating: Rating) -> Color {
    switch rating {
    case .again: danger
    case .hard: warning
    case .good: success
    case .easy: newBlue
    }
  }
}

struct PrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline)
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity, minHeight: 54)
      .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .opacity(configuration.isPressed ? 0.8 : 1)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

// Eine Karte im Stil der Statistik: Fläche, abgerundet, ohne Schatten im Dunkelmodus.
struct Surface: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}

extension View {
  func surface() -> some View { modifier(Surface()) }
}
