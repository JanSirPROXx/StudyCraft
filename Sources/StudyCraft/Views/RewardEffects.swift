import SwiftUI

// Der Ultra-Dopamin-Modus: Wischen nach rechts wird zum Aha-Moment. Beim Halten lädt sich eine Glühbirne
// immer stärker auf (Haptik, Ton und Leuchten steigern sich), bei „Einfach“ blitzt sie auf: Strahlen, Sterne,
// Häkchen und Konfetti, ein Schriftzug wie „SITZT!“ und eine Serie („3 in Folge“), die zeigt, wie gut es läuft.
// Alles ist nach etwa anderthalb Sekunden vorbei.

// Steuert Haptik, Ton und die Zeichnung; die Lernansicht meldet nur, was gerade passiert.
@MainActor @Observable
final class RewardController {
  private(set) var charge = 0.0  // 0…1 beim Halten
  private(set) var charging = false
  private(set) var burstSerial = 0
  private(set) var smallSerial = 0
  private(set) var word = "AHA!"
  private(set) var combo = 0  // richtige Antworten in Folge in dieser Sitzung

  @ObservationIgnored private let haptics = RewardHaptics()
  @ObservationIgnored private let audio = RewardAudio()
  @ObservationIgnored private let soundEnabled: Bool

  private static let words = [
    "AHA!", "SITZT!", "GEWUSST!", "GEMEISTERT!", "BRAIN-BOOST!", "KLARE SACHE!", "GENIAL!", "TREFFER!",
  ]

  init(sound: Bool) {
    soundEnabled = sound
    if sound { audio.prepare() }
  }

  // Die Glühbirne bekommt echte Impulse; ohne CoreHaptics tickt die Lernansicht wie gewohnt.
  var providesRumble: Bool { haptics.supported }

  func beginCharge(duration: TimeInterval) {
    guard !charging else { return }
    charging = true
    charge = 0
    haptics.startRumble(duration: duration)
    if soundEnabled { audio.startCharge() }
  }

  func update(_ progress: Double) {
    if charging { charge = progress }
  }

  func cancelCharge() {
    guard charging else { return }
    charging = false
    charge = 0
    haptics.stopRumble()
    if soundEnabled { audio.stopCharge() }
  }

  // „Einfach“: die Glühbirne blitzt auf.
  func burst() {
    charging = false
    charge = 0
    combo += 1
    word = Self.words.randomElement() ?? "AHA!"
    haptics.playBurst()
    if soundEnabled { audio.playBurst() }
    burstSerial += 1
  }

  // „Gut“: ein kleines Häkchen mit Sternchen.
  func smallWin() {
    charging = false
    charge = 0
    combo += 1
    haptics.playSmallWin()
    if soundEnabled { audio.playSmall() }
    smallSerial += 1
  }

  // „Schwer“ oder „Nochmal“: die Serie reißt ab, ohne dass etwas passiert.
  func breakCombo() {
    cancelCharge()
    combo = 0
  }
}

// Alle Effekte über der Karte. Die Zeichnung rechnet jede Phase aus der verstrichenen Zeit seit dem Auslöser,
// es gibt keinen Zustand pro Teilchen.
struct RewardLayer: View {
  let controller: RewardController

  @State private var burstStart: Date?
  @State private var smallStart: Date?
  @State private var pieces: [Piece] = []
  @State private var active = false
  @State private var sleepTask: Task<Void, Never>?

  var body: some View {
    TimelineView(.animation(minimumInterval: nil, paused: !active)) { timeline in
      GeometryReader { geometry in
        let now = timeline.date
        let origin = CGPoint(x: geometry.size.width / 2, y: geometry.size.height * 0.42)
        let burstTime = burstStart.map { now.timeIntervalSince($0) }
        let smallTime = smallStart.map { now.timeIntervalSince($0) }
        let clock = now.timeIntervalSinceReferenceDate

        ZStack {
          if let t = burstTime, t < 2.6 {
            Sunburst(time: t, origin: origin)
            Shockwave(time: t, origin: origin)
          }
          if controller.charging || (burstTime.map { $0 < 1.1 } ?? false) {
            AhaBulb(
              charge: controller.charging ? controller.charge : 1,
              burstTime: burstTime.flatMap { $0 < 1.1 ? $0 : nil }, clock: clock
            )
            .position(origin)
          }
          if let t = burstTime, t < 2.6 {
            Particles(pieces: pieces, time: t, origin: origin)
            RewardWord(text: controller.word, time: t)
              .position(x: origin.x, y: max(90, origin.y - 150))
            if controller.combo >= 2 {
              ComboChip(count: controller.combo, time: t)
                .position(x: origin.x, y: origin.y + 118)
            }
            Rectangle()
              .fill(Color(red: 0.85, green: 0.95, blue: 1))
              .opacity(max(0, 0.5 * exp(-t * 7)))
              .blendMode(.plusLighter)
              .ignoresSafeArea()
          }
          if let t = smallTime, t < 1.4 {
            Particles(pieces: pieces, time: t, origin: origin)
            SmallCheck(time: t)
              .position(origin)
          }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
      }
    }
    .allowsHitTesting(false)
    .onChange(of: controller.burstSerial) {
      pieces = Piece.confetti(count: 100) + Piece.stars(count: 26) + Piece.checks(count: 7)
      burstStart = Date()
      wake(for: 2.7)
    }
    .onChange(of: controller.smallSerial) {
      pieces = Piece.stars(count: 12, spread: 0.7) + Piece.checks(count: 3, spread: 0.7)
      smallStart = Date()
      wake(for: 1.5)
    }
    .onChange(of: controller.charging) { _, charging in
      if charging { wake(for: 1.5) }
    }
  }

  // Die Zeitleiste läuft nur, solange etwas zu sehen ist.
  private func wake(for seconds: Double) {
    active = true
    sleepTask?.cancel()
    sleepTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(seconds))
      guard !Task.isCancelled else { return }
      if controller.charging {
        wake(for: 0.5)
      } else {
        active = false
      }
    }
  }
}

// MARK: Teilchen

struct Piece: Identifiable {
  enum Kind { case confetti, star, check }
  let id = UUID()
  var kind: Kind
  var velocity: CGVector
  var size: CGFloat
  var color: Color
  var spin: Double
  var spinRate: Double
  var flutter: Double
  var delay: Double
  var life: Double
  var drag: Double
  var gravity: Double

  private static let confettiColors: [Color] = [
    Color(red: 0.25, green: 0.6, blue: 1), Color(red: 0.2, green: 0.85, blue: 0.95),
    Color(red: 0.2, green: 0.85, blue: 0.5), Color(red: 1, green: 0.82, blue: 0.25),
    Color(red: 0.62, green: 0.48, blue: 1), .white,
  ]

  // Konfetti aus einer Kanone, die schräg nach oben feuert.
  static func confetti(count: Int) -> [Piece] {
    (0..<count).map { _ in
      let angle = Double.random(in: -.pi * 0.95 ... -.pi * 0.05)
      let speed = Double.random(in: 380...1200)
      return Piece(
        kind: .confetti,
        velocity: CGVector(dx: cos(angle) * speed * 1.1, dy: sin(angle) * speed),
        size: CGFloat.random(in: 7...13), color: confettiColors.randomElement()!,
        spin: Double.random(in: 0...6.28), spinRate: Double.random(in: -9...9),
        flutter: Double.random(in: 6...14), delay: Double.random(in: 0...0.12),
        life: Double.random(in: 1.7...2.4), drag: 2.4, gravity: 760)
    }
  }

  // Sterne schweben langsamer und funkeln.
  static func stars(count: Int, spread: Double = 1) -> [Piece] {
    (0..<count).map { _ in
      let angle = Double.random(in: -.pi * (0.5 + 0.48 * spread) ... -.pi * (0.5 - 0.48 * spread))
      let speed = Double.random(in: 300...900)
      return Piece(
        kind: .star, velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
        size: CGFloat.random(in: 12...24),
        color: [Color(red: 1, green: 0.86, blue: 0.3), .white, Color(red: 0.55, green: 0.9, blue: 1)].randomElement()!,
        spin: Double.random(in: -0.4...0.4), spinRate: Double.random(in: -1.5...1.5),
        flutter: Double.random(in: 8...16), delay: Double.random(in: 0...0.16),
        life: Double.random(in: 1.3...2.0), drag: 1.5, gravity: 420)
    }
  }

  // Grüne Häkchen: „gewusst“.
  static func checks(count: Int, spread: Double = 1) -> [Piece] {
    (0..<count).map { _ in
      let angle = Double.random(in: -.pi * (0.5 + 0.4 * spread) ... -.pi * (0.5 - 0.4 * spread))
      let speed = Double.random(in: 420...800)
      return Piece(
        kind: .check, velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
        size: CGFloat.random(in: 22...30), color: Color(red: 0.2, green: 0.8, blue: 0.45),
        spin: 0, spinRate: 0, flutter: 0, delay: Double.random(in: 0...0.2),
        life: Double.random(in: 1.1...1.5), drag: 1.1, gravity: 900)
    }
  }
}

private struct Particles: View {
  let pieces: [Piece]
  let time: Double
  let origin: CGPoint

  var body: some View {
    Canvas { context, _ in
      for piece in pieces {
        let t = time - piece.delay
        guard t > 0, t < piece.life else { continue }
        let k = piece.drag
        let fall = 1 - exp(-k * t)
        let x = origin.x + piece.velocity.dx * fall / k
        let y = origin.y + (piece.gravity / k) * t + (piece.velocity.dy - piece.gravity / k) * fall / k
        let fade = min(1, (piece.life - t) * 3)
        var layer = context
        layer.opacity = fade
        layer.translateBy(x: x, y: y)
        switch piece.kind {
        case .confetti:
          layer.rotate(by: .radians(piece.spin + piece.spinRate * t))
          let flip = max(0.12, abs(cos(piece.flutter * t)))
          layer.scaleBy(x: 1, y: flip)
          let rect = CGRect(x: -piece.size / 2, y: -piece.size * 0.28, width: piece.size, height: piece.size * 0.56)
          layer.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(piece.color))
        case .star:
          layer.rotate(by: .radians(piece.spin + piece.spinRate * t))
          let twinkle = 0.75 + 0.25 * sin(piece.flutter * t)
          layer.scaleBy(x: twinkle, y: twinkle)
          layer.fill(StarShape.path(radius: piece.size / 2), with: .color(piece.color))
        case .check:
          let pop = min(1, t * 8)
          layer.scaleBy(x: pop, y: pop)
          CheckBadge.draw(in: &layer, radius: piece.size / 2, color: piece.color)
        }
      }
    }
  }
}

enum StarShape {
  // Ein vierzackiger Funkelstern.
  static func path(radius r: CGFloat) -> Path {
    var path = Path()
    let inner = r * 0.32
    for index in 0..<8 {
      let angle: Double = Double(index) * Double.pi / 4 - Double.pi / 2
      let radius: Double = Double(index % 2 == 0 ? r : inner)
      let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
      if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    path.closeSubpath()
    return path
  }
}

enum CheckBadge {
  static func draw(in context: inout GraphicsContext, radius r: CGFloat, color: Color) {
    let circle = Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r))
    context.fill(circle, with: .color(color))
    var tick = Path()
    tick.move(to: CGPoint(x: -r * 0.42, y: 0))
    tick.addLine(to: CGPoint(x: -r * 0.1, y: r * 0.32))
    tick.addLine(to: CGPoint(x: r * 0.46, y: -r * 0.34))
    context.stroke(
      tick, with: .color(.white),
      style: StrokeStyle(lineWidth: max(2, r * 0.26), lineCap: .round, lineJoin: .round))
  }
}

// MARK: Lichter

private struct Sunburst: View {
  let time: Double
  let origin: CGPoint

  var body: some View {
    Canvas { context, size in
      let rise: Double = min(1.0, time / 0.08)
      let fall: Double = max(0.0, 1.0 - max(0.0, time - 0.2) / 1.2)
      let envelope: Double = rise * fall
      guard envelope > 0 else { return }
      let reach: Double = Double(max(size.width, size.height)) * 1.1
      let rays = 16
      let step: Double = 2 * Double.pi / Double(rays)
      let color = Color(red: 0.75, green: 0.93, blue: 1).opacity(0.7 * envelope)
      for index in 0..<rays {
        let start: Double = Double(index) * step + time * 0.7
        let end: Double = start + step * 0.42
        var path = Path()
        path.move(to: origin)
        path.addLine(to: CGPoint(x: origin.x + cos(start) * reach, y: origin.y + sin(start) * reach))
        path.addLine(to: CGPoint(x: origin.x + cos(end) * reach, y: origin.y + sin(end) * reach))
        path.closeSubpath()
        let shading = GraphicsContext.Shading.radialGradient(
          Gradient(colors: [color, .clear]), center: origin, startRadius: 10, endRadius: reach * 0.7)
        context.fill(path, with: shading)
      }
    }
    .blendMode(.plusLighter)
  }
}

private struct Shockwave: View {
  let time: Double
  let origin: CGPoint

  var body: some View {
    ZStack {
      ForEach(0..<2, id: \.self) { index in
        let t = time - Double(index) * 0.1
        if t > 0 && t < 0.7 {
          Circle()
            .strokeBorder(
              Color(red: 0.7, green: 0.92, blue: 1).opacity(1 - t / 0.7),
              lineWidth: max(1, 14 * (1 - t / 0.7)))
            .frame(width: 60 + 620 * t, height: 60 + 620 * t)
            .position(origin)
        }
      }
    }
    .blendMode(.plusLighter)
  }
}

// Der kleine Gewinn: ein Häkchen springt auf, ein Ring läuft aus.
private struct SmallCheck: View {
  let time: Double

  var body: some View {
    let progress = min(1, time / 0.5)
    let appear = Self.spring(time)
    let fade = max(0, min(1, (1.0 - time) / 0.3))
    ZStack {
      Circle()
        .strokeBorder(Color(red: 0.7, green: 0.95, blue: 0.8).opacity(1 - progress), lineWidth: 5 * (1 - progress) + 1)
        .frame(width: 60 + 240 * progress, height: 60 + 240 * progress)
        .blendMode(.plusLighter)
      Canvas { context, size in
        var layer = context
        layer.translateBy(x: size.width / 2, y: size.height / 2)
        CheckBadge.draw(in: &layer, radius: 34, color: Color(red: 0.2, green: 0.8, blue: 0.45))
      }
      .frame(width: 100, height: 100)
      .scaleEffect(appear)
      .shadow(color: Color(red: 0.2, green: 0.9, blue: 0.5).opacity(0.7), radius: 16)
      .opacity(fade)
    }
  }

  private static func spring(_ t: Double) -> Double {
    t <= 0 ? 0.01 : 1 - exp(-t * 10) * cos(t * 17)
  }
}

// MARK: Schriftzug und Serie

private struct RewardWord: View {
  let text: String
  let time: Double

  var body: some View {
    let appear = max(0, time - 0.1)
    let scale = appear <= 0 ? 0.01 : Self.spring(appear)
    let opacity = min(1, appear * 12) * max(0, min(1, (1.7 - time) / 0.3))
    Text(text)
      .font(.system(size: 46, weight: .black, design: .rounded))
      .minimumScaleFactor(0.5)
      .lineLimit(1)
      .foregroundStyle(
        LinearGradient(
          colors: [.white, Color(red: 0.7, green: 0.92, blue: 1), Color(red: 0.35, green: 0.7, blue: 1)],
          startPoint: .top, endPoint: .bottom)
      )
      .shadow(color: Color(red: 0.05, green: 0.25, blue: 0.7).opacity(0.9), radius: 0, x: 0, y: 4)
      .shadow(color: Color(red: 1, green: 0.88, blue: 0.4).opacity(0.85), radius: 18)
      .rotationEffect(.degrees(-4 + 3 * sin(time * 9)))
      .scaleEffect(scale)
      .opacity(opacity)
      .padding(.horizontal, 20)
  }

  // Eine federnde Skalierung: schießt über 1 hinaus und schwingt ein.
  private static func spring(_ t: Double) -> Double {
    1 - exp(-t * 9) * cos(t * 16)
  }
}

// „3 in Folge“: wie viele Karten nacheinander gewusst wurden.
private struct ComboChip: View {
  let count: Int
  let time: Double

  var body: some View {
    let appear = max(0, time - 0.35)
    let scale = appear <= 0 ? 0.01 : 1 - exp(-appear * 10) * cos(appear * 18)
    let opacity = min(1, appear * 10) * max(0, min(1, (1.8 - time) / 0.3))
    HStack(spacing: 6) {
      Image(systemName: "flame.fill")
        .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.2))
      Text("\(count) in Folge")
    }
    .font(.system(size: 18, weight: .bold, design: .rounded))
    .foregroundStyle(.white)
    .padding(.horizontal, 16)
    .padding(.vertical, 9)
    .background(Theme.accent, in: Capsule())
    .shadow(color: Theme.accent.opacity(0.6), radius: 12, y: 2)
    .scaleEffect(scale)
    .opacity(opacity)
  }
}

// MARK: Glühbirne

struct AhaBulb: View {
  let charge: Double  // 0…1, solange man hält
  let burstTime: Double?  // Sekunden seit dem Aufblitzen
  let clock: Double

  private var bursting: Bool { burstTime != nil }
  private var t: Double { burstTime ?? 0 }
  private var lit: Double { bursting ? 1 : charge }

  private func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ amount: Double) -> Color {
    Color(
      red: a.0 + (b.0 - a.0) * amount, green: a.1 + (b.1 - a.1) * amount, blue: a.2 + (b.2 - a.2) * amount)
  }

  var body: some View {
    let shakeAmount = bursting ? 0 : charge * charge
    let jitterX: Double = sin(clock * (38 + 70 * charge)) * 4.5 * shakeAmount
    let jitterY: Double = cos(clock * (31 + 60 * charge)) * 3 * shakeAmount
    let tilt: Double = sin(clock * (25 + 55 * charge)) * 5 * shakeAmount
    let pulse: Double = 1 + sin(clock * (9 + 26 * charge)) * 0.05 * charge
    let popScale: Double = 1 + 0.4 * exp(-t * 5) * sin(min(t, 0.4) * 8)
    let size: Double = bursting ? popScale : 0.55 + 0.6 * charge
    let fade: Double = bursting ? max(0, min(1, (1.05 - t) / 0.35)) : 1

    ZStack {
      glow
      bulb
    }
    .scaleEffect(size * pulse)
    .rotationEffect(.degrees(tilt))
    .offset(x: jitterX, y: jitterY)
    .opacity(fade)
  }

  private var glow: some View {
    let radial = RadialGradient(
      colors: [Color(red: 1, green: 0.95, blue: 0.6).opacity(0.9), .clear],
      center: .center, startRadius: 4, endRadius: 150)
    let glowScale: Double = bursting ? 1 + t * 2 : 0.6 + 0.4 * charge
    return Circle()
      .fill(radial)
      .frame(width: 300, height: 300)
      .opacity(0.1 + 0.9 * lit)
      .scaleEffect(glowScale)
      .blendMode(.plusLighter)
  }

  // Kurze Strahlen rund um den Glaskolben, die mit der Ladung länger werden.
  private var rays: some View {
    ZStack {
      ForEach(0..<12, id: \.self) { index in
        let wobble: Double = 0.75 + 0.25 * sin(clock * 18 + Double(index) * 1.7)
        Capsule()
          .fill(Color(red: 1, green: 0.95, blue: 0.65))
          .frame(width: 5, height: (6 + 26 * lit) * wobble)
          .offset(y: -(58 + 6 * lit))
          .rotationEffect(.degrees(Double(index) * 30))
      }
    }
    .opacity(lit > 0.12 ? min(1, lit * 1.4) : 0)
  }

  private var bulb: some View {
    let unlitTop = (0.86, 0.92, 0.98)
    let unlitEdge = (0.66, 0.75, 0.86)
    let litTop = (1.0, 1.0, 0.88)
    let litEdge = (1.0, 0.82, 0.25)
    let glass = RadialGradient(
      colors: [mix(unlitTop, litTop, lit), mix(unlitEdge, litEdge, lit)],
      center: UnitPoint(x: 0.4, y: 0.35), startRadius: 4, endRadius: 56)
    let metal = LinearGradient(
      colors: [Color(red: 0.78, green: 0.8, blue: 0.84), Color(red: 0.5, green: 0.53, blue: 0.58)],
      startPoint: .top, endPoint: .bottom)
    let filament = mix((0.55, 0.45, 0.35), (1, 0.97, 0.8), lit)
    return ZStack {
      rays
      VStack(spacing: 0) {
        ZStack {
          Circle().fill(glass).frame(width: 86, height: 86)
          Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 2).frame(width: 86, height: 86)
          // Glühfaden
          Path { path in
            path.move(to: CGPoint(x: 31, y: 78))
            path.addLine(to: CGPoint(x: 31, y: 52))
            path.addLine(to: CGPoint(x: 37, y: 44))
            path.addLine(to: CGPoint(x: 43, y: 52))
            path.addLine(to: CGPoint(x: 49, y: 44))
            path.addLine(to: CGPoint(x: 55, y: 52))
            path.addLine(to: CGPoint(x: 55, y: 78))
          }
          .stroke(filament, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
          .shadow(color: Color.white.opacity(lit), radius: 5 + 6 * lit)
          .frame(width: 86, height: 86)
          // Glanzlicht
          Capsule().fill(Color.white.opacity(0.7))
            .frame(width: 8, height: 26)
            .rotationEffect(.degrees(35))
            .offset(x: -26, y: -20)
        }
        RoundedRectangle(cornerRadius: 3).fill(glass).frame(width: 34, height: 12).offset(y: -4)
        VStack(spacing: 2) {
          RoundedRectangle(cornerRadius: 3).fill(metal).frame(width: 38, height: 8)
          RoundedRectangle(cornerRadius: 3).fill(metal).frame(width: 34, height: 8)
          RoundedRectangle(cornerRadius: 4).fill(metal).frame(width: 18, height: 8)
        }
        .offset(y: -2)
      }
      .offset(y: 8)
    }
    .frame(width: 150, height: 160)
  }
}

// Ein Rahmen um die Karte, der beim Aufblitzen in Lernfarben umläuft.
struct GlowBorder: View {
  var body: some View {
    TimelineView(.animation) { timeline in
      let angle = timeline.date.timeIntervalSinceReferenceDate * 200
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .strokeBorder(
          AngularGradient(
            colors: [
              Color(red: 0.25, green: 0.6, blue: 1), Color(red: 0.2, green: 0.9, blue: 0.95),
              Color(red: 0.4, green: 0.95, blue: 0.6), Color(red: 1, green: 0.88, blue: 0.4),
              Color(red: 0.2, green: 0.9, blue: 0.95), Color(red: 0.25, green: 0.6, blue: 1),
            ],
            center: .center, angle: .degrees(angle)),
          lineWidth: 5
        )
        .shadow(color: Color(red: 0.3, green: 0.8, blue: 1).opacity(0.6), radius: 14)
    }
  }
}

// MARK: Vorschau in den Einstellungen

struct RewardPreview: View {
  @Environment(AppModel.self) private var app
  @State private var controller: RewardController?
  @State private var holding = false
  @State private var task: Task<Void, Never>?

  var body: some View {
    VStack(spacing: 24) {
      ZStack {
        RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.card)
        Text("Probier es aus")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Theme.textTertiary)
        if let controller { RewardLayer(controller: controller) }
      }
      .frame(maxWidth: .infinity, minHeight: 360, maxHeight: 420)

      HStack(spacing: 12) {
        Button {
          controller?.smallWin()
        } label: {
          Label("Gut", systemImage: "checkmark")
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.bordered)
        .tint(Theme.success)

        Button {
          play()
        } label: {
          Label("Einfach", systemImage: "lightbulb.fill")
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.newBlue)
      }
      Text("Im Lernen ziehst du die Karte dazu nach rechts. Hältst du den Finger, lädt sich die Glühbirne immer stärker auf und blitzt bei „Einfach“ auf.")
        .font(.footnote)
        .foregroundStyle(Theme.textSecondary)
        .multilineTextAlignment(.center)
    }
    .padding(20)
    .frame(maxWidth: 560)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.background)
    .navigationTitle("Vorschau")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { controller = RewardController(sound: app.ultraSound) }
    .onDisappear {
      task?.cancel()
      controller?.cancelCharge()
    }
  }

  // Der Ablauf wie beim Halten: knapp eine Sekunde Aufbau, dann der Aufblitz.
  private func play() {
    guard let controller, !holding else { return }
    holding = true
    controller.beginCharge(duration: SwipeRule.dwell)
    task = Task { @MainActor in
      let start = Date()
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(16))
        let progress = min(1, Date().timeIntervalSince(start) / SwipeRule.dwell)
        controller.update(progress)
        if progress >= 1 { break }
      }
      if !Task.isCancelled { controller.burst() }
      holding = false
    }
  }
}
