import SwiftUI

// Die Lernansicht: oben ein Fortschrittsbalken, in der Mitte die Karte (Tippen dreht sie um), unten der
// Button "Antwort zeigen" und danach die vier Bewertungen mit dem Abstand bis zum nächsten Mal.
struct StudyView: View {
  let session: StudySession
  let close: () -> Void
  @Environment(AppModel.self) private var app
  @State private var burst = 0
  @State private var reward: RewardController?

  var body: some View {
    ZStack {
      Theme.background.ignoresSafeArea()
      VStack(spacing: 0) {
        header
        if let card = session.current {
          cardArea(card)
          controls
        } else {
          SessionSummary(session: session, close: close)
        }
      }
      .frame(maxWidth: 820)  // auf dem iPad bleibt die Karte gut lesbar
    }
    .onAppear {
      if app.ultraDopamine, reward == nil { reward = RewardController(sound: app.ultraSound) }
    }
  }

  // MARK: Kopf

  private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Theme.textSecondary)
        .frame(width: 36, height: 36)
        .background(Theme.field, in: Circle())
    }
    .accessibilityLabel(label)
  }

  private var header: some View {
    HStack(spacing: 12) {
      roundButton("xmark", label: "Schließen", action: close)
        .keyboardShortcut(.escape, modifiers: [])

      roundButton("arrow.uturn.backward", label: "Zurück zur letzten Karte") {
        Haptics.selection()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { session.undo() }
      }
      .keyboardShortcut("z", modifiers: .command)
      .disabled(!session.canUndo)
      .opacity(session.canUndo ? 1 : 0.35)

      ProgressBar(fraction: session.fraction)
        .frame(height: 6)
        .accessibilityLabel("Fortschritt")
        .accessibilityValue("\(session.finished) von \(session.total) Karten")

      Text("\(session.remaining) übrig")
        .font(.footnote.monospacedDigit())
        .foregroundStyle(Theme.textSecondary)
        .frame(minWidth: 52, alignment: .trailing)

      modeMenu
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }

  private var modeMenu: some View {
    Menu {
      Picker(
        "Reihenfolge",
        selection: Binding(
          get: { session.mode },
          set: { mode in withAnimation(.snappy) { session.setMode(mode) } })
      ) {
        ForEach(StudyMode.allCases) { mode in
          Label(mode.title, systemImage: mode.icon).tag(mode)
        }
      }
    } label: {
      Image(systemName: session.mode.icon)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Theme.accent)
        .frame(width: 36, height: 36)
        .background(Theme.field, in: Circle())
    }
    .accessibilityLabel("Reihenfolge: \(session.mode.title)")
  }

  // MARK: Karte

  private func cardArea(_ card: Card) -> some View {
    CardStage(
      session: session, resolver: session.imageResolver(for: card),
      front: session.currentBlocks.front, back: session.currentBlocks.back,
      reward: reward, celebrate: { burst += 1 }
    )
    .id(session.cardSerial)
    .transition(.scale(scale: 0.93).combined(with: .opacity))
    .padding(.horizontal, 16)
    .padding(.bottom, 12)
    .frame(maxHeight: .infinity)
    .overlay { SparkBurst(trigger: burst).allowsHitTesting(false) }
    .overlay { if let reward { RewardLayer(controller: reward) } }
  }

  // MARK: Bedienung

  @ViewBuilder
  private var controls: some View {
    Group {
      if session.revealed {
        HStack(spacing: 10) {
          ForEach(Rating.allCases) { rating in
            RatingButton(rating: rating, interval: session.previews[rating] ?? 0) {
              session.request(rating)
            }
          }
        }
      } else {
        Button("Antwort zeigen") {
          Haptics.flip()
          session.flip()
        }
        .buttonStyle(PrimaryButtonStyle())
        .keyboardShortcut(.space, modifiers: [])
      }
    }
    .frame(height: 64)
    .padding(.horizontal, 16)
    .padding(.bottom, 10)
  }
}

private struct RatingButton: View {
  let rating: Rating
  let interval: TimeInterval
  let action: () -> Void

  var body: some View {
    let color = Theme.color(for: rating)
    Button(action: action) {
      VStack(spacing: 3) {
        Text(IntervalFormat.short(interval))
          .font(.caption.monospacedDigit())
          .opacity(0.8)
        Text(rating.title)
          .font(.subheadline.weight(.semibold))
      }
      .foregroundStyle(color)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
    .keyboardShortcut(KeyEquivalent(Character(String(rating.rawValue))), modifiers: [])
    .accessibilityLabel("\(rating.title), nächstes Mal \(IntervalFormat.short(interval))")
  }
}

private struct ProgressBar: View {
  let fraction: Double

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(Theme.raised)
        Capsule().fill(Theme.accent)
          .frame(width: max(6, geometry.size.width * fraction))
          .opacity(fraction > 0 ? 1 : 0)
      }
    }
    .animation(.easeOut(duration: 0.3), value: fraction)
  }
}

// MARK: Karte mit Wischgesten

private enum SwipeSide { case positive, negative }

// Eine Karte samt ihrem Zustand: umgedreht, gerade gezogen, am Hinausfliegen. Der Zustand gehört der
// Ansicht selbst, damit die abgehende Karte unverändert hinausgleitet.
//
// Ziehen nach rechts: "Gut", mit gehaltenem Finger "Einfach" (leichte Impulse, dann ein Schlag).
// Ziehen nach links: "Schwer", mit gehaltenem Finger "Nochmal" (ohne Haptik).
private struct CardStage: View {
  let session: StudySession
  let resolver: ImageResolver
  let front: [MDBlock]
  let back: [MDBlock]
  let reward: RewardController?
  let celebrate: () -> Void

  @State private var flipped = false
  @State private var offset: CGSize
  @State private var side: SwipeSide?
  @State private var dwell = 0.0
  @State private var strong = false
  @State private var leavingRating: Rating?
  @State private var tracking = false
  @State private var horizontal = false
  @State private var dwellTask: Task<Void, Never>?

  init(
    session: StudySession, resolver: ImageResolver, front: [MDBlock], back: [MDBlock],
    reward: RewardController?, celebrate: @escaping () -> Void
  ) {
    self.session = session
    self.resolver = resolver
    self.front = front
    self.back = back
    self.reward = reward
    self.celebrate = celebrate
    _offset = State(initialValue: CGSize(width: session.entryOffset, height: 0))
  }

  private var shown: Rating? {
    if let leavingRating { return leavingRating }
    if let side {
      return side == .positive ? (strong ? .easy : .good) : (strong ? .again : .hard)
    }
    if abs(offset.width) < 14 { return nil }
    return offset.width > 0 ? .good : .hard
  }

  private var pull: Double {
    leavingRating != nil ? 1 : min(1, Double(abs(offset.width)) / Double(SwipeRule.trigger))
  }

  var body: some View {
    let rating = shown
    let color = rating.map(Theme.color(for:)) ?? .clear
    let celebrating = strong && side == .positive

    ZStack {
      FlipCard(
        angle: flipped ? 180 : 0,
        front: CardFace(label: "Frage", blocks: front, resolver: resolver),
        back: CardFace(label: "Antwort", blocks: back, resolver: resolver)
      )
      .animation(.spring(response: 0.5, dampingFraction: 0.85), value: flipped)
      .overlay {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .fill(color.opacity(strong ? 0.26 : 0.17 * pull))
          .allowsHitTesting(false)
      }
      .overlay {
        if strong {
          if reward != nil {
            GlowBorder()
              .allowsHitTesting(false)
              .transition(.opacity)
          } else {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
              .strokeBorder(color, lineWidth: 3)
              .shadow(color: color.opacity(0.7), radius: 16)
              .allowsHitTesting(false)
              .transition(.opacity)
          }
        }
      }
      .scaleEffect(celebrating ? 1.04 : 1)
      .animation(.spring(response: 0.3, dampingFraction: 0.5), value: celebrating)
      .animation(.easeOut(duration: 0.2), value: strong)
      .rotationEffect(.degrees(max(-14, min(14, Double(offset.width) / 22))), anchor: .bottom)
      .offset(offset)
      .contentShape(Rectangle())
      .onTapGesture {
        Haptics.flip()
        session.flip()
      }
      .simultaneousGesture(drag)
    }
    // Das Abzeichen bleibt oben in der Mitte, auch wenn die Karte zur Seite wandert.
    .overlay(alignment: .top) {
      ZStack {
        if let rating {
          SwipeBadge(
            rating: rating, dwell: dwell, armed: side != nil && leavingRating == nil, strong: strong
          )
          .id(rating)
          .transition(.scale(scale: 0.7).combined(with: .opacity))
        }
      }
      .padding(.top, 22)
      .opacity(rating == nil ? 0 : max(pull, side != nil ? 1 : 0))
      .animation(.spring(response: 0.3, dampingFraction: 0.6), value: rating)
      .allowsHitTesting(false)
    }
    .onChange(of: session.flipTick) { flipped.toggle() }
    .onChange(of: session.requestSerial) {
      if let rating = session.requestedRating { commit(rating) }
    }
    .onAppear {
      guard offset != .zero else { return }
      withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { offset = .zero }
    }
    .onDisappear {
      dwellTask?.cancel()
      reward?.cancelCharge()
    }
  }

  // MARK: Geste

  private var drag: some Gesture {
    DragGesture(minimumDistance: 14, coordinateSpace: .global)
      .onChanged { value in
        if !tracking {
          tracking = true
          horizontal = abs(value.translation.width) > abs(value.translation.height) * 1.1
          if horizontal { Haptics.prepare() }
        }
        guard horizontal, leavingRating == nil else { return }
        offset = CGSize(
          width: Self.damped(value.translation.width), height: value.translation.height * 0.2)
        updateSide(value.translation.width)
      }
      .onEnded { value in
        let wasHorizontal = horizontal
        tracking = false
        horizontal = false
        guard wasHorizontal, leavingRating == nil else { return }
        dwellTask?.cancel()
        if let rating = SwipeRule.rating(
          dx: value.translation.width, armed: side != nil, strong: strong,
          predicted: value.predictedEndTranslation.width)
        {
          commit(rating)
        } else {
          reset()
        }
      }
  }

  // Die Karte folgt dem Finger, wird aber weiter außen träger und verlässt den Bildschirm nicht.
  private static func damped(_ dx: CGFloat) -> CGFloat {
    let limit: CGFloat = 90
    let magnitude = abs(dx)
    let shown = magnitude <= limit ? magnitude : limit + (magnitude - limit) * 0.45
    return dx < 0 ? -shown : shown
  }

  // Ab einer gewissen Strecke ist die erste Stufe erreicht; ein Stück zurück hebt sie wieder auf.
  private func updateSide(_ dx: CGFloat) {
    let new: SwipeSide?
    if let side {
      let distance = side == .positive ? dx : -dx
      new = distance > SwipeRule.release ? side : nil
    } else {
      new = dx >= SwipeRule.trigger ? .positive : (dx <= -SwipeRule.trigger ? .negative : nil)
    }
    guard new != side else { return }
    if side == .positive { reward?.cancelCharge() }
    dwellTask?.cancel()
    dwell = 0
    strong = false
    side = new
    if let new {
      if new == .positive {
        Haptics.engage()
        reward?.beginCharge(duration: SwipeRule.dwell)
      }
      startDwell(new)
    }
  }

  // Solange der Finger an der Stelle bleibt, füllt sich der Ring. Rechts kribbelt es dabei immer
  // stärker und am Ende gibt es den Belohnungs-Schlag; links bleibt alles still.
  private func startDwell(_ side: SwipeSide) {
    dwellTask = Task { @MainActor in
      let start = Date()
      var lastTick = 0.0
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(16))
        if Task.isCancelled { return }
        let elapsed = Date().timeIntervalSince(start)
        let progress = min(1, elapsed / SwipeRule.dwell)
        dwell = progress
        if side == .positive { reward?.update(progress) }
        if progress >= 1 {
          strong = true
          if side == .positive {
            if let reward {
              reward.burst()  // die Glühbirne blitzt auf
            } else {
              Haptics.reward()
              celebrate()
            }
          }
          return
        }
        if side == .positive, reward?.providesRumble != true,
          elapsed - lastTick >= 0.17 - 0.11 * progress
        {
          lastTick = elapsed
          Haptics.tick(0.2 + 0.7 * progress)
        }
      }
    }
  }

  private func reset() {
    reward?.cancelCharge()
    side = nil
    dwell = 0
    withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) {
      offset = .zero
      strong = false
    }
  }

  // Die Karte fliegt in Wischrichtung hinaus, danach kommt die nächste.
  private func commit(_ rating: Rating) {
    guard leavingRating == nil else { return }
    dwellTask?.cancel()
    let rewarded = strong
    leavingRating = rating
    switch rating {
    case .good:
      if let reward {
        reward.smallWin()
      } else {
        Haptics.release(strong: false)
      }
    case .easy:
      if let reward {
        if !rewarded { reward.burst() }  // schneller Wisch oder Button: die Glühbirne blitzt jetzt
      } else {
        if rewarded {
          Haptics.release(strong: true)
        } else {
          Haptics.reward()
        }
        celebrate()
      }
    case .hard, .again:
      reward?.breakCombo()  // keine Haptik: schlechte Antworten sollen nichts belohnen
    }
    withAnimation(.easeIn(duration: 0.26)) {
      offset = CGSize(width: rating.isPositive ? 900 : -900, height: offset.height - 30)
    } completion: {
      withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { session.rate(rating) }
    }
  }
}

private struct SwipeBadge: View {
  let rating: Rating
  let dwell: Double
  let armed: Bool
  let strong: Bool

  private var next: Rating? {
    switch rating {
    case .good: .easy
    case .hard: .again
    default: nil
    }
  }

  private var symbol: String {
    switch rating {
    case .again: "arrow.counterclockwise"
    case .hard: "tortoise.fill"
    case .good: "checkmark"
    case .easy: "sparkles"
    }
  }

  var body: some View {
    let color = Theme.color(for: rating)
    VStack(spacing: 8) {
      HStack(spacing: 8) {
        ZStack {
          if next != nil, armed {
            Circle().stroke(.white.opacity(0.3), lineWidth: 3)
            Circle().trim(from: 0, to: dwell)
              .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
              .rotationEffect(.degrees(-90))
          }
          Image(systemName: symbol).font(.system(size: 14, weight: .bold))
        }
        .frame(width: 30, height: 30)
        Text(rating.title).font(.headline)
      }
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(color, in: Capsule())
      .shadow(color: color.opacity(strong ? 0.7 : 0.35), radius: strong ? 16 : 8, y: 2)

      if let next, armed {
        Text("Halten für \(next.title)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(Theme.color(for: next))
      }
    }
  }
}

// Funken, die beim "Einfach" aus der Karte spritzen.
private struct SparkBurst: View {
  let trigger: Int
  @State private var phase = 0.0

  private let colors: [Color] = [Theme.newBlue, Theme.success, Theme.warning, Theme.accent]

  var body: some View {
    ZStack {
      ForEach(0..<20, id: \.self) { index in
        let angle = Double(index) / 20 * 2 * .pi + 0.2
        let distance = 80 + Double((index * 37) % 90)
        Image(systemName: index % 3 == 0 ? "sparkle" : "circle.fill")
          .font(.system(size: index % 3 == 0 ? 18 : 8))
          .foregroundStyle(colors[index % colors.count])
          .offset(
            x: cos(angle) * distance * phase, y: sin(angle) * distance * phase - 30 * phase
          )
          .scaleEffect(1 - phase * 0.5)
          .opacity(phase == 0 ? 0 : 1 - phase)
      }
    }
    .onChange(of: trigger) {
      phase = 0
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(30))
        withAnimation(.easeOut(duration: 0.9)) { phase = 1 }
      }
    }
  }
}

// Dreht die Karte um die senkrechte Achse; bei 90° wechselt die Seite. Die Animation läuft über
// `animatableData`, damit der Wechsel genau in der Mitte der Drehung passiert.
struct FlipCard<Front: View, Back: View>: View, Animatable {
  var angle: Double
  let front: Front
  let back: Back

  var animatableData: Double {
    get { angle }
    set { angle = newValue }
  }

  var body: some View {
    ZStack {
      if angle < 90 {
        front
      } else {
        back.rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
      }
    }
    .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
  }
}

struct CardFace: View {
  let label: String
  let blocks: [MDBlock]
  let resolver: ImageResolver
  @Environment(\.horizontalSizeClass) private var sizeClass

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        MarkdownView(blocks: blocks, resolver: resolver, size: sizeClass == .regular ? 27 : 21)
          .equatable()
          .padding(.horizontal, 24)
          .padding(.top, 44)
          .padding(.bottom, 28)
          .frame(maxWidth: 720)
          .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .leading)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .overlay(alignment: .topLeading) {
      Text(label.uppercased())
        .font(.caption2.weight(.semibold))
        .tracking(1.2)
        .foregroundStyle(Theme.textTertiary)
        .padding(.leading, 24)
        .padding(.top, 20)
    }
    .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    .shadow(color: .black.opacity(0.06), radius: 14, y: 4)
  }
}

// MARK: Ende der Sitzung

private struct SessionSummary: View {
  let session: StudySession
  let close: () -> Void

  var body: some View {
    VStack(spacing: 18) {
      Spacer()
      Image(systemName: session.answered > 0 ? "checkmark.circle.fill" : "tray")
        .font(.system(size: 76))
        .symbolRenderingMode(.palette)
        .foregroundStyle(session.answered > 0 ? .white : Theme.textTertiary, Theme.success)
      Text(session.answered > 0 ? "Geschafft!" : "Nichts zu lernen")
        .font(.largeTitle.bold())
      Text(subtitle)
        .font(.body)
        .foregroundStyle(Theme.textSecondary)
        .multilineTextAlignment(.center)
      Spacer()
      VStack(spacing: 10) {
        Button("Fertig", action: close)
          .buttonStyle(PrimaryButtonStyle())
          .keyboardShortcut(.return, modifiers: [])
        Button {
          withAnimation(.snappy) { session.restart() }
        } label: {
          Label("Noch einmal durchgehen", systemImage: "arrow.clockwise")
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 44)
        }
      }
    }
    .padding(24)
    .frame(maxWidth: 520)
    .frame(maxWidth: .infinity)
  }

  private var subtitle: String {
    if session.answered > 0 {
      let minutes = Int((session.seconds / 60).rounded())
      let cards = session.answered == 1 ? "1 Antwort" : "\(session.answered) Antworten"
      return minutes >= 1 ? "\(cards) in \(minutes) Min" : cards
    }
    if session.mode == .new {
      return "In „\(session.deckName)“ gibt es keine neuen Karten mehr.\nWähle oben rechts „Mischen“ oder „Der Reihe nach“."
    }
    return "In „\(session.deckName)“ gibt es keine Karten."
  }
}
