import SwiftUI

// „Entdecken“: fertige Decks zum Herunterladen, mit Suche und Sprachfilter. Ein geladenes Deck ist danach
// ein ganz normaler Ordner im Lernordner und lässt sich frei bearbeiten.
struct DiscoverView: View {
  @Environment(AppModel.self) private var app
  @State private var discover: DiscoverModel?
  @State private var path: [DiscoverDeck] = []

  var body: some View {
    NavigationStack(path: $path) {
      Group {
        if let discover {
          DiscoverContent(discover: discover, path: $path)
        } else {
          Color.clear
        }
      }
      .background(Theme.background)
      .navigationTitle("Entdecken")
      .navigationDestination(for: DiscoverDeck.self) { deck in
        if let discover { DiscoverDetailView(discover: discover, deck: deck) }
      }
    }
    .task {
      if discover == nil { discover = DiscoverModel(app: app) }
      await discover?.load()
    }
  }
}

private struct DiscoverContent: View {
  @Bindable var discover: DiscoverModel
  @Binding var path: [DiscoverDeck]

  private let columns = [GridItem(.adaptive(minimum: 320, maximum: 480), spacing: 14, alignment: .top)]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        switch discover.phase {
        case .idle where discover.decks.isEmpty, .loading where discover.decks.isEmpty:
          ProgressView("Decks werden geladen …")
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
        case .failed(let message):
          ContentUnavailableView {
            Label("Keine Verbindung", systemImage: "wifi.slash")
          } description: {
            Text(message)
          } actions: {
            Button("Erneut versuchen") { Task { await discover.load(force: true) } }
              .buttonStyle(.borderedProminent)
          }
          .padding(.top, 60)
        default:
          if discover.showsCachedCatalog {
            Label("Offline: Laden ist erst mit Internet möglich.", systemImage: "wifi.slash")
              .font(.footnote)
              .foregroundStyle(Theme.textSecondary)
          }
          if discover.languages.count > 1 { LanguageChips(discover: discover) }
          let decks = discover.filtered
          if decks.isEmpty {
            ContentUnavailableView.search(text: discover.search)
              .padding(.top, 40)
          } else {
            LazyVGrid(columns: columns, spacing: 14) {
              ForEach(decks) { deck in
                DeckCard(discover: discover, deck: deck)
                  .onTapGesture { path.append(deck) }
                  .accessibilityElement(children: .contain)
                  .accessibilityAddTraits(.isButton)
                  .accessibilityIdentifier("discover-\(deck.id)")
              }
            }
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 24)
      .frame(maxWidth: 1000)
      .frame(maxWidth: .infinity)
    }
    .searchable(
      text: $discover.search, placement: .navigationBarDrawer(displayMode: .always),
      prompt: "Decks suchen")
    .refreshable { await discover.load(force: true) }
  }
}

private struct LanguageChips: View {
  @Bindable var discover: DiscoverModel

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        chip("Alle Sprachen", selected: discover.language == nil) { discover.language = nil }
        ForEach(discover.languages, id: \.self) { code in
          chip(
            Locale.current.localizedString(forLanguageCode: code)?.localizedCapitalized
              ?? code.uppercased(),
            selected: discover.language == code
          ) { discover.language = code }
        }
      }
      .padding(.vertical, 2)
    }
    .scrollClipDisabled()
  }

  private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button {
      withAnimation(.snappy) { action() }
      Haptics.selection()
    } label: {
      Text(title)
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .foregroundStyle(selected ? Color.white : Theme.textPrimary)
        .background(selected ? Theme.accent : Theme.card, in: Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

private struct DeckCard: View {
  let discover: DiscoverModel
  let deck: DiscoverDeck

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Thumbnail(url: discover.thumbnailURL(deck), title: deck.title)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()

      VStack(alignment: .leading, spacing: 10) {
        VStack(alignment: .leading, spacing: 3) {
          Text(deck.title)
            .font(.headline)
            .foregroundStyle(Theme.textPrimary)
            .multilineTextAlignment(.leading)
          Text(deck.subtitle)
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
        }
        HStack(spacing: 8) {
          DeckFacts(deck: deck)
          Spacer(minLength: 4)
          GetButton(discover: discover, deck: deck)
        }
      }
      .padding(14)
    }
    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}

private struct DeckFacts: View {
  let deck: DiscoverDeck

  var body: some View {
    HStack(spacing: 6) {
      Text(deck.language.uppercased())
        .font(.caption2.weight(.bold))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .foregroundStyle(Theme.accent)
      Text(deck.cardCount == 1 ? "1 Karte" : "\(deck.cardCount) Karten")
        .font(.footnote)
        .foregroundStyle(Theme.textTertiary)
    }
    .accessibilityElement(children: .combine)
  }
}

// Der Knopf zum Laden: „Laden“, dann ein Fortschrittsring, danach „Geladen“.
private struct GetButton: View {
  let discover: DiscoverModel
  let deck: DiscoverDeck
  var large = false

  var body: some View {
    let progress = discover.downloads[deck.id]
    let installed = discover.isInstalled(deck)
    Group {
      if let progress {
        HStack(spacing: 8) {
          ProgressView(value: max(progress, 0.04))
            .progressViewStyle(.circular)
            .controlSize(.small)
          if large { Text("Wird geladen …") }
        }
        .padding(.horizontal, large ? 16 : 8)
        .frame(minWidth: large ? nil : 72, minHeight: large ? 54 : 32)
        .frame(maxWidth: large ? .infinity : nil)
        .foregroundStyle(Theme.accent)
      } else if installed {
        Label(large ? "Zu deinen Decks hinzugefügt" : "Geladen", systemImage: "checkmark")
          .font(large ? .headline : .subheadline.weight(.semibold))
          .padding(.horizontal, large ? 16 : 12)
          .frame(minHeight: large ? 54 : 32)
          .frame(maxWidth: large ? .infinity : nil)
          .foregroundStyle(Theme.success)
      } else {
        Button {
          Task { await discover.install(deck) }
        } label: {
          Text(large ? "Zu meinen Decks hinzufügen" : "Laden")
            .font(large ? .headline : .subheadline.weight(.bold))
            .padding(.horizontal, large ? 16 : 18)
            .frame(minHeight: large ? 54 : 32)
            .frame(maxWidth: large ? .infinity : nil)
            .foregroundStyle(.white)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: large ? 16 : 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("get-\(deck.id)")
      }
    }
    .animation(.snappy, value: installed)
    .animation(.snappy, value: progress == nil)
  }
}

// Das Vorschaubild eines Decks. Solange es lädt oder fehlt, steht ein ruhiger Farbverlauf da.
private struct Thumbnail: View {
  let url: URL?
  let title: String

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Theme.accent.opacity(0.35), Theme.newBlue.opacity(0.18)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
      Image(systemName: "rectangle.stack")
        .font(.system(size: 34, weight: .light))
        .foregroundStyle(Theme.textTertiary)
      if let url {
        AsyncImage(url: url) { phase in
          if let image = phase.image {
            image.resizable().scaledToFill().transition(.opacity)
          }
        }
      }
    }
    .accessibilityHidden(true)
  }
}

struct DiscoverDetailView: View {
  @Bindable var discover: DiscoverModel
  let deck: DiscoverDeck
  @Environment(AppModel.self) private var app

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Thumbnail(url: discover.thumbnailURL(deck), title: deck.title)
          .aspectRatio(16.0 / 9.0, contentMode: .fit)
          .frame(maxWidth: .infinity)
          .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        VStack(alignment: .leading, spacing: 6) {
          Text(deck.title)
            .font(.system(size: 28, weight: .bold))
          Text(deck.subtitle)
            .font(.title3)
            .foregroundStyle(Theme.textSecondary)
        }

        HStack(spacing: 10) {
          fact(deck.languageName, systemImage: "globe")
          fact(deck.cardCount == 1 ? "1 Karte" : "\(deck.cardCount) Karten", systemImage: "rectangle.on.rectangle")
          fact(ByteCountFormatter.string(fromByteCount: Int64(deck.size), countStyle: .file), systemImage: "arrow.down.circle")
        }

        Text(deck.description)
          .font(.body)
          .foregroundStyle(Theme.textPrimary)

        if !deck.tags.isEmpty {
          FlowTags(tags: deck.tags)
        }

        GetButton(discover: discover, deck: deck, large: true)
          .padding(.top, 4)

        if discover.isInstalled(deck) {
          Button {
            app.selectedTab = .decks
          } label: {
            Label("Zu den Decks", systemImage: "rectangle.stack")
              .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(.bordered)
        } else {
          Text(
            "Die Karten werden in deinen Lernordner kopiert und gehören dir: Du kannst sie danach wie jedes andere Deck bearbeiten, ergänzen oder löschen."
          )
          .font(.footnote)
          .foregroundStyle(Theme.textTertiary)
        }
      }
      .padding(16)
      .frame(maxWidth: 720)
      .frame(maxWidth: .infinity)
    }
    .background(Theme.background)
    .navigationTitle(deck.title)
    .navigationBarTitleDisplayMode(.inline)
  }

  private func fact(_ text: String, systemImage: String) -> some View {
    Label(text, systemImage: systemImage)
      .font(.footnote.weight(.medium))
      .foregroundStyle(Theme.textSecondary)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Theme.card, in: Capsule())
  }
}

private struct FlowTags: View {
  let tags: [String]

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        ForEach(tags, id: \.self) { tag in
          Text(tag)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.accent.opacity(0.12), in: Capsule())
            .foregroundStyle(Theme.accent)
        }
      }
    }
  }
}
