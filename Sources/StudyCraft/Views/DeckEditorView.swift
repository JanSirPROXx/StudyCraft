import PhotosUI
import SwiftUI

// Die Karten eines Decks: neue hinzufügen, bearbeiten, ausblenden oder löschen. Alles wird direkt in die
// Markdown-Dateien geschrieben.
struct DeckEditorView: View {
  @Environment(AppModel.self) private var model
  let deckID: String

  private enum Target: Identifiable {
    case new
    case edit(Card)
    var id: String {
      switch self {
      case .new: "new"
      case .edit(let card): card.id
      }
    }
  }

  @State private var target: Target?
  @State private var deleting: Card?

  private var node: DeckNode? { DeckTree.find(deckID, in: model.decks) }

  var body: some View {
    Group {
      if let node {
        if node.cards.isEmpty {
          ContentUnavailableView {
            Label("Keine Karten", systemImage: "rectangle.on.rectangle.slash")
          } description: {
            Text("Dieses Deck hat selbst keine Karten. Füge eine hinzu.")
          } actions: {
            Button("Karte hinzufügen") { target = .new }
              .buttonStyle(.borderedProminent)
          }
        } else {
          List {
            ForEach(node.cards) { card in
              row(card)
                .listRowBackground(Theme.card)
                .listRowSeparatorTint(Theme.separator)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                  Button(role: .destructive) {
                    deleting = card
                  } label: {
                    Label("Löschen", systemImage: "trash")
                  }
                  .tint(Theme.danger)
                  Button {
                    Task { await model.setHidden(!card.hidden, card: card) }
                  } label: {
                    Label(
                      card.hidden ? "Einblenden" : "Ausblenden",
                      systemImage: card.hidden ? "eye" : "eye.slash")
                  }
                  .tint(Theme.warning)
                }
                .contextMenu {
                  Button {
                    target = .edit(card)
                  } label: {
                    Label("Bearbeiten", systemImage: "pencil")
                  }
                  Button {
                    Task { await model.setHidden(!card.hidden, card: card) }
                  } label: {
                    Label(
                      card.hidden ? "Einblenden" : "Ausblenden",
                      systemImage: card.hidden ? "eye" : "eye.slash")
                  }
                  Button(role: .destructive) {
                    deleting = card
                  } label: {
                    Label("Löschen", systemImage: "trash")
                  }
                }
            }
          }
          .listStyle(.insetGrouped)
          .scrollContentBackground(.hidden)
        }
      } else {
        ContentUnavailableView("Deck nicht mehr vorhanden", systemImage: "folder.badge.questionmark")
      }
    }
    .background(Theme.background)
    .navigationTitle(node?.name ?? "Deck")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          target = .new
        } label: {
          Image(systemName: "plus")
        }
        .accessibilityLabel("Karte hinzufügen")
        .disabled(node == nil)
      }
    }
    .sheet(item: $target) { target in
      switch target {
      case .new: CardEditorView(deckID: deckID, card: nil)
      case .edit(let card): CardEditorView(deckID: deckID, card: card)
      }
    }
    .confirmationDialog(
      "Karte löschen?",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
      titleVisibility: .visible
    ) {
      Button("Karte löschen", role: .destructive) {
        if let card = deleting { Task { await model.deleteCard(card) } }
      }
    } message: {
      Text(
        deleting?.isSingle == true
          ? "Die Datei „\(deleting?.fileURL.lastPathComponent ?? "")“ wird gelöscht."
          : "Die Karte wird aus „\(deleting?.fileURL.lastPathComponent ?? "")“ entfernt.")
    }
  }

  private func row(_ card: Card) -> some View {
    Button {
      target = .edit(card)
    } label: {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(Self.preview(card.front))
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(2)
          Text(Self.preview(card.back))
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
        }
        Spacer(minLength: 8)
        if card.hidden {
          Image(systemName: "eye.slash")
            .foregroundStyle(Theme.textTertiary)
            .accessibilityLabel("Ausgeblendet")
        }
      }
      .opacity(card.hidden ? 0.5 : 1)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // Die erste Zeile ohne Markdown-Zeichen, als Vorschau in der Liste.
  static func preview(_ text: String) -> String {
    let line =
      text.components(separatedBy: "\n").first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
      ?? ""
    var result = line.trimmingCharacters(in: .whitespaces)
    while let first = result.first, "#>-*+ ".contains(first) { result.removeFirst() }
    result = result.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
    if result.hasPrefix("!") { return "Bild" }
    return result.isEmpty ? "…" : result
  }
}

// Eine Karte schreiben oder ändern, mit Vorschau und der Möglichkeit, Bilder aus den Fotos einzufügen.
struct CardEditorView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  let card: Card?
  let chooseDeck: Bool
  let isNewDeck: Bool

  @State private var deckID: String
  @State private var front: String
  @State private var back: String
  @State private var saving = false
  @State private var frontPhoto: PhotosPickerItem?
  @State private var backPhoto: PhotosPickerItem?
  @FocusState private var focus: Field?

  private enum Field { case front, back }

  // `chooseDeck`: oben lässt sich das Deck wählen. `isNewDeck`: das Deck gibt es noch nicht, die erste
  // Karte legt es an.
  init(deckID: String, card: Card?, chooseDeck: Bool = false, isNewDeck: Bool = false) {
    _deckID = State(initialValue: deckID)
    self.card = card
    self.chooseDeck = chooseDeck
    self.isNewDeck = isNewDeck
    _front = State(initialValue: card?.front ?? "")
    _back = State(initialValue: card?.back ?? "")
  }

  private var canSave: Bool {
    !CardParser.trimmed(front).isEmpty && !CardParser.trimmed(back).isEmpty && !saving
  }

  var body: some View {
    NavigationStack {
      Form {
        if chooseDeck {
          Section("Deck") {
            Picker("Deck", selection: $deckID) {
              ForEach(model.deckChoices, id: \.id) { choice in Text(choice.title).tag(choice.id) }
            }
            .listRowBackground(Theme.card)
          }
        } else if isNewDeck {
          Section("Neues Deck") {
            Label(deckID.replacingOccurrences(of: "/", with: " › "), systemImage: "folder.badge.plus")
              .listRowBackground(Theme.card)
          }
        }
        editor("Vorderseite", text: $front, field: .front, photo: $frontPhoto)
        editor("Rückseite", text: $back, field: .back, photo: $backPhoto)

        Section("Vorschau") {
          let resolver = model.imageResolver(deckID: card?.deckID ?? deckID)
          VStack(alignment: .leading, spacing: 18) {
            preview(front, resolver: resolver)
            Divider().overlay(Theme.separator)
            preview(back, resolver: resolver)
          }
          .padding(.vertical, 4)
        }
        .listRowBackground(Theme.card)
      }
      .scrollContentBackground(.hidden)
      .background(Theme.background)
      .navigationTitle(card == nil ? (isNewDeck ? "Erste Karte" : "Neue Karte") : "Karte bearbeiten")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") { save() }.disabled(!canSave)
        }
      }
      .onAppear { if card == nil { focus = .front } }
    }
  }

  @ViewBuilder
  private func preview(_ text: String, resolver: ImageResolver) -> some View {
    if CardParser.trimmed(text).isEmpty {
      Text("–").foregroundStyle(Theme.textTertiary)
    } else {
      MarkdownView(blocks: MarkdownParser.parse(CardParser.trimmed(text)), resolver: resolver, size: 17)
    }
  }

  private func editor(
    _ title: String, text: Binding<String>, field: Field, photo: Binding<PhotosPickerItem?>
  ) -> some View {
    Section {
      TextEditor(text: text)
        .focused($focus, equals: field)
        .frame(minHeight: 120)
        .font(.system(size: 16))
        .scrollContentBackground(.hidden)
        .listRowBackground(Theme.card)
      PhotosPicker(selection: photo, matching: .images) {
        Label("Bild einfügen", systemImage: "photo.badge.plus")
      }
      .listRowBackground(Theme.card)
      .onChange(of: photo.wrappedValue) { _, item in
        guard let item else { return }
        photo.wrappedValue = nil
        Task { await insert(item, into: text) }
      }
    } header: {
      Text(title)
    } footer: {
      if field == .back {
        Text(verbatim: "Markdown: **fett**, *kursiv*, „- “ für Listen, „#“ für Überschriften, drei Backticks für Code-Blöcke.")
      }
    }
  }

  private func insert(_ item: PhotosPickerItem, into text: Binding<String>) async {
    guard let data = try? await item.loadTransferable(type: Data.self),
      let name = await model.addImage(data, deckID: card?.deckID ?? deckID)
    else { return }
    let current = text.wrappedValue
    let separator = current.isEmpty ? "" : (current.hasSuffix("\n") ? "\n" : "\n\n")
    text.wrappedValue = current + separator + "![[\(name)]]"
  }

  private func save() {
    saving = true
    Task {
      let ok = await model.saveCard(card, deckID: deckID, front: front, back: back)
      saving = false
      if ok { dismiss() }
    }
  }
}
