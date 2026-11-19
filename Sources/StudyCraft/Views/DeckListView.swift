import SwiftUI

// Der Startbildschirm: alle Decks als aufklappbare Liste, daneben blau die neuen und grün die
// fälligen Karten. Ein Tipp auf ein Deck startet die Lernsitzung.
struct DeckListView: View {
  @Environment(AppModel.self) private var model
  @State private var settings = false
  @State private var editingID: String?
  @State private var renaming: DeckNode?
  @State private var renameText = ""
  @State private var deleting: DeckNode?
  @State private var newDeckParent: String?  // nicht nil: der Name-Dialog für ein neues (Unter-)Deck ist offen
  @State private var newDeckName = ""
  @State private var cardSheet: CardSheet?

  private struct CardSheet: Identifiable {
    var deckID: String
    var chooseDeck = false
    var isNewDeck = false
    var id: String { "\(deckID)|\(chooseDeck)|\(isNewDeck)" }
  }
  @AppStorage("expandedDecks") private var expandedStorage = ""

  private struct Row: Identifiable {
    var node: DeckNode
    var depth: Int
    var id: String { node.id }
  }

  private var expanded: Set<String> {
    Set(expandedStorage.split(separator: "\n").map(String.init))
  }

  // Die sichtbaren Zeilen: aufgeklappte Decks zeigen ihre Unterdecks direkt darunter.
  private var rows: [Row] {
    var result: [Row] = []
    func add(_ nodes: [DeckNode], depth: Int) {
      for node in nodes {
        result.append(Row(node: node, depth: depth))
        if expanded.contains(node.id) { add(node.children, depth: depth + 1) }
      }
    }
    add(model.decks, depth: 0)
    return result
  }

  private func toggle(_ id: String) {
    var set = expanded
    if set.contains(id) { set.remove(id) } else { set.insert(id) }
    withAnimation(.snappy) { expandedStorage = set.sorted().joined(separator: "\n") }
  }

  var body: some View {
    NavigationStack {
      Group {
        if model.decks.isEmpty {
          emptyState
        } else {
          List {
            ForEach(rows) { row in
              DeckRow(
                node: row.node, depth: row.depth, counts: model.counts(for: row.node),
                expanded: expanded.contains(row.node.id),
                toggle: { toggle(row.node.id) },
                open: { model.startSession(row.node) }
              )
              .listRowBackground(Theme.card)
              .listRowSeparatorTint(Theme.separator)
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !row.node.id.isEmpty {
                  Button(role: .destructive) {
                    deleting = row.node
                  } label: {
                    Label("Löschen", systemImage: "trash")
                  }
                  .tint(Theme.danger)
                }
                Button {
                  editingID = row.node.id
                } label: {
                  Label("Bearbeiten", systemImage: "square.and.pencil")
                }
                .tint(Theme.accent)
              }
              .contextMenu {
                Button {
                  cardSheet = CardSheet(deckID: row.node.id)
                } label: {
                  Label("Karte hinzufügen", systemImage: "rectangle.badge.plus")
                }
                Button {
                  editingID = row.node.id
                } label: {
                  Label("Karten bearbeiten", systemImage: "square.and.pencil")
                }
                if !row.node.id.isEmpty {
                  Button {
                    newDeckName = ""
                    newDeckParent = row.node.id
                  } label: {
                    Label("Unterdeck anlegen", systemImage: "folder.badge.plus")
                  }
                  Button {
                    renameText = row.node.name
                    renaming = row.node
                  } label: {
                    Label("Umbenennen", systemImage: "pencil")
                  }
                  Button(role: .destructive) {
                    deleting = row.node
                  } label: {
                    Label("Deck löschen", systemImage: "trash")
                  }
                }
              }
            }
          }
          .listStyle(.insetGrouped)
          .scrollContentBackground(.hidden)
          .frame(maxWidth: 760)  // auf dem iPad nicht über die ganze Breite
          .frame(maxWidth: .infinity)
        }
      }
      .background(Theme.background)
      .navigationTitle("Decks")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          if model.isScanning && model.hasScanned {
            ProgressView()
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button {
              cardSheet = CardSheet(deckID: model.deckChoices.first?.id ?? "", chooseDeck: true)
            } label: {
              Label("Neue Karte", systemImage: "rectangle.badge.plus")
            }
            .disabled(model.decks.isEmpty)
            Button {
              newDeckName = ""
              newDeckParent = ""
            } label: {
              Label("Neues Deck", systemImage: "folder.badge.plus")
            }
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel("Hinzufügen")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            settings = true
          } label: {
            Image(systemName: "gearshape")
          }
          .accessibilityLabel("Einstellungen")
        }
      }
      .refreshable { await model.refresh() }
      .navigationDestination(item: $editingID) { id in DeckEditorView(deckID: id) }
    }
    .sheet(isPresented: $settings) { SettingsView() }
    .sheet(item: $cardSheet) { sheet in
      CardEditorView(deckID: sheet.deckID, card: nil, chooseDeck: sheet.chooseDeck, isNewDeck: sheet.isNewDeck)
    }
    .alert(
      newDeckParent?.isEmpty == false ? "Neues Unterdeck" : "Neues Deck",
      isPresented: Binding(get: { newDeckParent != nil }, set: { if !$0 { newDeckParent = nil } })
    ) {
      TextField("Name", text: $newDeckName)
      Button("Abbrechen", role: .cancel) {}
      Button("Weiter") {
        if let parent = newDeckParent, let id = model.newDeckID(parent: parent, name: newDeckName) {
          cardSheet = CardSheet(deckID: id, isNewDeck: true)
        }
      }
    } message: {
      Text("Als Nächstes schreibst du die erste Karte. Das Deck ist ein Ordner im Lernordner.")
    }
    .alert("Deck umbenennen", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
      TextField("Name", text: $renameText)
      Button("Abbrechen", role: .cancel) {}
      Button("Umbenennen") {
        if let node = renaming {
          let name = renameText
          Task { _ = await model.renameDeck(node, to: name) }
        }
      }
    } message: {
      Text("Der Ordner wird umbenannt, der Lernfortschritt bleibt erhalten.")
    }
    .confirmationDialog(
      deleting.map { "„\($0.name)“ löschen?" } ?? "",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
      titleVisibility: .visible
    ) {
      Button("Deck samt Ordner löschen", role: .destructive) {
        if let node = deleting { Task { await model.deleteDeck(node) } }
      }
    } message: {
      Text(
        "Der Ordner und alle \(deleting?.cardCount ?? 0) Karten darin werden von deinem Gerät und aus iCloud Drive gelöscht (dort einige Zeit in „Zuletzt gelöscht“)."
      )
    }
  }

  @ViewBuilder
  private var emptyState: some View {
    if !model.hasScanned {
      VStack(spacing: 14) {
        ProgressView()
        Text("Lernordner wird gelesen …")
          .font(.subheadline)
          .foregroundStyle(Theme.textSecondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView {
        ContentUnavailableView {
          Label("Noch keine Karten", systemImage: "rectangle.stack")
        } description: {
          Text(
            "In „\(model.rootName)“ liegen keine Markdown-Dateien mit Karten. Eine Datei ist eine Karte, wenn ihre erste Zeile @studyCraft oder @studyCraft_List lautet."
          )
        } actions: {
          Button("Neues Deck anlegen") {
            newDeckName = ""
            newDeckParent = ""
          }
          .buttonStyle(.borderedProminent)
          Button("Beispiel-Deck anlegen") { createSample() }
          Button("Kartenformat ansehen") { settings = true }
        }
        .padding(.top, 60)
      }
      .refreshable { await model.refresh() }
    }
  }

  private func createSample() {
    guard let root = model.rootURL else { return }
    do {
      try SampleDeck.write(into: root)
      Task { await model.refresh() }
    } catch {
      model.errorMessage = "Das Beispiel-Deck konnte nicht angelegt werden: \(error.localizedDescription)"
    }
  }
}

private struct DeckRow: View {
  let node: DeckNode
  let depth: Int
  let counts: DeckCounts
  let expanded: Bool
  let toggle: () -> Void
  let open: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      // Der Pfeil klappt auf, der Rest der Zeile startet das Lernen.
      Group {
        if node.children.isEmpty {
          Color.clear
        } else {
          Button(action: toggle) {
            Image(systemName: "chevron.right")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(Theme.textTertiary)
              .rotationEffect(.degrees(expanded ? 90 : 0))
              .frame(width: 44, height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(expanded ? "Zuklappen" : "Aufklappen")
        }
      }
      .frame(width: 30, height: 44)
      .padding(.leading, CGFloat(depth) * 18)

      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text(node.name)
            .font(.headline)
            .foregroundStyle(Theme.textPrimary)
          Text(counts.total == 1 ? "1 Karte" : "\(counts.total) Karten")
            .font(.footnote)
            .foregroundStyle(Theme.textTertiary)
        }
        Spacer(minLength: 8)
        HStack(spacing: 0) {
          count(counts.new, color: Theme.newBlue)
          count(counts.due, color: Theme.success)
        }
      }
      .padding(.vertical, 4)
      .contentShape(Rectangle())
      .onTapGesture(perform: open)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isButton)
      .accessibilityHint("Startet das Lernen")
      .accessibilityValue("\(counts.new) neu, \(counts.due) fällig")
    }
  }

  private func count(_ value: Int, color: Color) -> some View {
    Text("\(value)")
      .font(.system(.body, design: .rounded).weight(.semibold).monospacedDigit())
      .foregroundStyle(value == 0 ? Theme.textTertiary.opacity(0.7) : color)
      .frame(minWidth: 40, alignment: .trailing)
  }
}
