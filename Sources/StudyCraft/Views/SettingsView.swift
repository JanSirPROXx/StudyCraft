import SwiftUI

struct SettingsView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var picking = false

  var body: some View {
    @Bindable var model = model
    NavigationStack {
      Form {
        Section {
          LabeledContent("Aktueller Ordner", value: model.rootName)
          Button("Ordner wechseln …") { picking = true }
        } header: {
          Text("Lernordner")
        } footer: {
          Text(
            "Jeder Unterordner wird ein Deck, jede .md-Datei mit @studyCraft in der ersten Zeile liefert Karten. Der Lernfortschritt liegt im Unterordner „_StudyCraft“ und wird mit iCloud synchronisiert."
          )
        }

        Section("Darstellung") {
          Picker("Erscheinungsbild", selection: $model.appearance) {
            ForEach(AppearanceMode.allCases) { mode in Text(mode.title).tag(mode) }
          }
          .pickerStyle(.segmented)
        }

        Section {
          Toggle("Ultra-Dopamin-Modus", isOn: $model.ultraDopamine)
            .accessibilityIdentifier("ultraDopamine")
          if model.ultraDopamine {
            Toggle("Ton", isOn: $model.ultraSound)
            NavigationLink("Ausprobieren") { RewardPreview() }
          }
        } header: {
          Text("Belohnung")
        } footer: {
          Text(
            "Wischen nach rechts wird zum Aha-Moment: Beim Halten lädt sich eine Glühbirne mit Vibration, Ton und Leuchten immer stärker auf und blitzt bei „Einfach“ mit Sternen, Konfetti und einer „in Folge“-Serie auf. Der Ton folgt dem Stumm-Schalter."
          )
        }

        Section("Hilfe") {
          NavigationLink("Kartenformat") { FormatHelpView() }
          Button("Beispiel-Deck anlegen") { createSample() }
        }

        Section("Info") {
          Link("Datenschutzerklärung", destination: AppLinks.privacy)
          Link("Support und Feedback", destination: AppLinks.support)
          NavigationLink("Quellen und Lizenzen") { CreditsView() }
          LabeledContent("Version", value: AppLinks.version)
        }
      }
      .navigationTitle("Einstellungen")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
      }
      .scrollContentBackground(.hidden)
      .background(Theme.background)
      .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
        switch result {
        case .success(let url):
          model.choose(url)
          dismiss()
        case .failure(let error):
          model.errorMessage = error.localizedDescription
        }
      }
    }
  }

  private func createSample() {
    guard let root = model.rootURL else { return }
    do {
      try SampleDeck.write(into: root)
      Task { await model.refresh() }
      dismiss()
    } catch {
      model.errorMessage = "Das Beispiel-Deck konnte nicht angelegt werden: \(error.localizedDescription)"
    }
  }
}

struct FormatHelpView: View {
  private let example = SampleDeck.formatExample

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text(
          "Eine Markdown-Datei wird zur Karte, wenn ihre erste Zeile eine Kennung enthält:"
        )
        VStack(alignment: .leading, spacing: 6) {
          Text("`@studyCraft` – die Datei ist eine einzelne Karte")
          Text("`@studyCraft_List` – die Datei enthält mehrere Karten")
        }
        .font(.subheadline)

        Text(example)
          .font(.system(.footnote, design: .monospaced))
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Theme.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          .textSelection(.enabled)

        Button {
          UIPasteboard.general.string = example
        } label: {
          Label("Beispiel kopieren", systemImage: "doc.on.doc")
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("**---** trennt Vorder- und Rückseite.")
          Text("**===** trennt mehrere Karten in einer Datei.")
          Text("`<!-- hidden -->` als eigene Zeile in einer Karte blendet sie aus.")
          Text(
            "Unterstützt werden Überschriften, **fett**, *kursiv*, Listen, Code-Blöcke, Tabellen und Bilder – `![Text](bild.png)` oder `![[bild.png]]` aus demselben Ordner."
          )
        }
        .font(.subheadline)
        .foregroundStyle(Theme.textSecondary)
      }
      .padding(20)
    }
    .navigationTitle("Kartenformat")
    .navigationBarTitleDisplayMode(.inline)
    .background(Theme.background)
  }
}

enum AppLinks {
  static let privacy = URL(string: "https://jansirprox.github.io/StudyCraft/datenschutz")!
  static let support = URL(string: "https://jansirprox.github.io/StudyCraft/")!

  static var version: String {
    let info = Bundle.main.infoDictionary
    let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = info?["CFBundleVersion"] as? String ?? "1"
    return "\(short) (\(build))"
  }
}

struct CreditsView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        block(
          "Entdecken-Decks",
          "Die Decks in „Entdecken“ wurden für StudyCraft zusammengestellt. Sie werden beim Laden als normale Markdown-Dateien in deinen Lernordner kopiert, du kannst sie frei bearbeiten."
        )
        block(
          "Landkarten",
          "Die Länder- und Kantonskarten sind aus Natural Earth gezeichnet (gemeinfrei, naturalearthdata.com)."
        )
        block(
          "Kantonswappen und Porträts",
          "Wappen und Fotos stammen von Wikimedia Commons (gemeinfrei oder unter Creative-Commons-Lizenzen). Urheber und Lizenz stehen im Deck-Ordner in der Datei „Credits.md“ beziehungsweise „Bildnachweise.md“ und, wo es die Lizenz verlangt, auf der Karte selbst."
        )
        block(
          "Eigene Inhalte",
          "Fragen, Antworten und Texte der Decks wurden für StudyCraft verfasst."
        )
      }
      .padding(20)
      .frame(maxWidth: 640, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Theme.background)
    .navigationTitle("Quellen und Lizenzen")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func block(_ title: String, _ text: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.headline)
      Text(text).font(.subheadline).foregroundStyle(Theme.textSecondary)
    }
  }
}
