import SwiftUI

// Die Lernansicht: oben ein Fortschrittsbalken, in der Mitte die Karte (Tippen dreht sie um), unten der
// Button "Antwort zeigen" und danach die vier Bewertungen mit dem Abstand bis zum nächsten Mal.
struct StudyView: View {
  let session: StudySession
  let close: () -> Void

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
    }
  }

  // MARK: Kopf

  private var header: some View {
    HStack(spacing: 14) {
      Button(action: close) {
        Image(systemName: "xmark")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Theme.textSecondary)
          .frame(width: 36, height: 36)
          .background(Theme.field, in: Circle())
      }
      .keyboardShortcut(.escape, modifiers: [])
      .accessibilityLabel("Schließen")

      ProgressBar(fraction: session.fraction)
        .frame(height: 6)
        .accessibilityLabel("Fortschritt")
        .accessibilityValue("\(session.finished) von \(session.total) Karten")

      Text("\(session.remaining) übrig")
        .font(.footnote.monospacedDigit())
        .foregroundStyle(Theme.textSecondary)
        .frame(minWidth: 56, alignment: .trailing)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }

  // MARK: Karte

  private func cardArea(_ card: Card) -> some View {
    CardStage(
      session: session, resolver: session.imageResolver(for: card),
      front: session.currentBlocks.front, back: session.currentBlocks.back
    )
    .id(session.cardSerial)
    .transition(
      .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity))
    )
    .padding(.horizontal, 16)
    .padding(.bottom, 12)
    .frame(maxHeight: .infinity)
  }

  // MARK: Bedienung

  @ViewBuilder
  private var controls: some View {
    Group {
      if session.revealed {
        HStack(spacing: 10) {
          ForEach(Rating.allCases) { rating in
            RatingButton(rating: rating, interval: session.previews[rating] ?? 0) {
              UISelectionFeedbackGenerator().selectionChanged()
              withAnimation(.snappy(duration: 0.3)) { session.rate(rating) }
            }
          }
        }
      } else {
        Button("Antwort zeigen") {
          UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

// MARK: Umdrehen

// Eine Karte samt ihrem Umdreh-Zustand. Der Zustand gehört der Ansicht selbst: beim Wechsel zur nächsten
// Karte bleibt die abgehende Karte so, wie sie war, und gleitet unverändert hinaus.
private struct CardStage: View {
  let session: StudySession
  let resolver: ImageResolver
  let front: [MDBlock]
  let back: [MDBlock]
  @State private var flipped = false

  var body: some View {
    FlipCard(
      angle: flipped ? 180 : 0,
      front: CardFace(label: "Frage", blocks: front, resolver: resolver),
      back: CardFace(label: "Antwort", blocks: back, resolver: resolver)
    )
    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: flipped)
    .contentShape(Rectangle())
    .onTapGesture {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      session.flip()
    }
    .onChange(of: session.flipTick) { flipped.toggle() }
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

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        MarkdownView(blocks: blocks, resolver: resolver)
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
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 76))
        .symbolRenderingMode(.palette)
        .foregroundStyle(.white, Theme.success)
      Text(session.answered > 0 ? "Geschafft!" : "Alles erledigt")
        .font(.largeTitle.bold())
      Text(subtitle)
        .font(.body)
        .foregroundStyle(Theme.textSecondary)
        .multilineTextAlignment(.center)
      Spacer()
      Button("Fertig", action: close)
        .buttonStyle(PrimaryButtonStyle())
        .keyboardShortcut(.return, modifiers: [])
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
    if let next = session.nextDue {
      return "In „\(session.deckName)“ ist gerade nichts fällig.\nDie nächste Karte kommt \(IntervalFormat.relative(next))."
    }
    return "In „\(session.deckName)“ ist nichts fällig."
  }
}
