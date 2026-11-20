import SwiftUI

@main
struct StudyCraftApp: App {
  @State private var model = AppModel()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(model)
        .preferredColorScheme(model.appearance.colorScheme)
        .tint(Theme.accent)
    }
  }
}

struct RootView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    @Bindable var model = model
    Group {
      if model.isRestoring {
        Theme.background.ignoresSafeArea()
          .overlay { ProgressView() }
      } else if model.rootURL == nil {
        WelcomeView()
      } else {
        TabView(selection: $model.selectedTab) {
          DeckListView()
            .tabItem { Label("Decks", systemImage: "rectangle.stack") }
            .tag(RootTab.decks)
          DiscoverView()
            .tabItem { Label("Entdecken", systemImage: "sparkles.rectangle.stack") }
            .tag(RootTab.discover)
          StatsView()
            .tabItem { Label("Statistik", systemImage: "chart.bar.xaxis") }
            .tag(RootTab.stats)
        }
      }
    }
    .task { await model.restore() }
    .onChange(of: scenePhase) { _, phase in model.setActive(phase == .active) }
    .fullScreenCover(item: $model.activeSession) { session in
      StudyView(session: session) { model.activeSession = nil }
        .environment(model)
    }
    .alert(
      "StudyCraft",
      isPresented: Binding(
        get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    ) {
      Button("OK") { model.errorMessage = nil }
    } message: {
      Text(model.errorMessage ?? "")
    }
  }
}

struct WelcomeView: View {
  @Environment(AppModel.self) private var model
  @State private var picking = false

  var body: some View {
    VStack(spacing: 22) {
      Spacer()
      Image(systemName: "rectangle.stack.fill")
        .font(.system(size: 64, weight: .light))
        .foregroundStyle(Theme.newBlue)
      VStack(spacing: 10) {
        Text("StudyCraft")
          .font(.system(size: 36, weight: .bold))
        Text("Lerne mit deinen eigenen\nMarkdown-Dateien.")
          .font(.title3)
          .foregroundStyle(Theme.textSecondary)
          .multilineTextAlignment(.center)
      }
      Spacer()
      VStack(spacing: 14) {
        Button("Lernordner wählen") { picking = true }
          .buttonStyle(PrimaryButtonStyle())
          .accessibilityIdentifier("chooseFolder")
        Text(
          "Wähle einen Ordner in iCloud Drive. Jeder Unterordner wird zu einem Deck, jede Markdown-Datei mit @studyCraft in der ersten Zeile zu Karten."
        )
        .font(.footnote)
        .foregroundStyle(Theme.textTertiary)
        .multilineTextAlignment(.center)
      }
    }
    .padding(28)
    .frame(maxWidth: 480)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.background)
    .foregroundStyle(Theme.textPrimary)
    .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
      switch result {
      case .success(let url): model.choose(url)
      case .failure(let error): model.errorMessage = error.localizedDescription
      }
    }
  }
}
