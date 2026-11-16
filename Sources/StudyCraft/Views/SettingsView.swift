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

        Section("Lernen") {
          Stepper(value: $model.newPerDay, in: 0...500, step: 5) {
            LabeledContent("Neue Karten pro Tag", value: "\(model.newPerDay)")
          }
        }

        Section("Darstellung") {
          Picker("Erscheinungsbild", selection: $model.appearance) {
            ForEach(AppearanceMode.allCases) { mode in Text(mode.title).tag(mode) }
          }
          .pickerStyle(.segmented)
        }

        Section("Hilfe") {
          NavigationLink("Kartenformat") { FormatHelpView() }
          Button("Beispiel-Deck anlegen") { createSample() }
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
